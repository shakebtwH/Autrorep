require 'lib.moonloader'
local imgui = require 'mimgui'
local sampev = require 'lib.samp.events'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local ffi = require 'ffi'

-- Настройка кодировок: для входящих данных из игры (CP1251 -> UTF-8)
encoding.default = 'CP1251'
u8 = encoding.UTF8

-- === НАСТРОЙКИ ОБНОВЛЕНИЯ ===
local UPDATE_URL = "https://raw.githubusercontent.com/shakebtwH/Autrorep/main/update.json"
local SCRIPT_URL = "https://raw.githubusercontent.com/shakebtwH/Autrorep/main/%21repflow.lua"
local update_found = false
local update_status = "Проверка не проводилась"
-- =============================

if not samp then samp = {} end

local IniFilename = 'RepFlowCFG.ini'
local new = imgui.new
local scriptver = "4.17 | Premium"   -- версия без FontAwesome

local scriptStartTime = os.clock()

local changelogEntries = {
    { version = "4.17 | Premium", description = "- Полностью удалена поддержка FontAwesome для избежания проблем со шрифтами." },
    { version = "4.16 | Premium", description = "- Исправлено отображение текста при сохранении файла в UTF-8 (убрана лишняя обёртка u8())." },
    { version = "4.15 | Premium", description = "- Исправлена ошибка 'invalid escape sequence' при использовании FontAwesome." },
    { version = "4.14 | Premium", description = "- Добавлена поддержка FontAwesome 6 (иконки в меню).\n- Требуется файл 'fa-solid-900.ttf' в папке со скриптом." },
    { version = "4.13 | Premium", description = "- Удалена кастомная тема, добавлена чёрная тема.\n- Уменьшен размер главного окна до 600x400." },
    { version = "4.12 | Premium", description = "- Добавлена функция автообновления скрипта." },
    { version = "4.11 | Premium", description = "- Убраны строки 'Время работы' и 'Ваш ник' во вкладке 'Информация'." },
    { version = "4.10 | Premium", description = "- Убрана полоса прокрутки в окне информации, увеличен размер окна." },
    { version = "4.9 | Premium", description = "- В окне информации при включённой ловле показывается статус, время работы текущей сессии и счётчик отвеченных репортов." },
    { version = "4.8 | Premium", description = "- Исправлена ошибка с корутинами (добавлены защитные проверки)." },
    { version = "4.7 | Premium", description = "- Финальная стабильная версия без фона и лишних зависимостей." },
    { version = "4.6 | Premium", description = "- Добавлена возможность установить своё изображение на задний фон главного окна." },
    { version = "4.5 | Premium", description = "- Исправлен краш при открытии меню (убрана загрузка внешнего шрифта)." },
    { version = "4.4 | Premium", description = "- Добавлена поддержка локального шрифта с эмодзи (NotoColorEmoji.ttf)." },
    { version = "4.3 | Premium", description = "- Добавлена поддержка эмодзи через системные шрифты." },
    { version = "4.2 | Premium", description = "- Удалена вкладка 'Статистика', скрипт приведён к минималистичному виду." },
    { version = "4.1 | Premium", description = "- Удалены статические темы, оставлены только 'Прозрачная' и 'Кастомная'.\n- Исправлена ошибка с PlotHistogram." },
    { version = "4.0 | Premium", description = "- Удалено приветствие.\n- Добавлена вкладка 'Статистика'." },
}

local keyBind = 0x5A
local keyBindName = 'Z'
local lastOtTime = 0
local active = false
local otInterval = new.int(10)
local dialogTimeout = new.int(600)
local otIntervalBuffer = imgui.new.char[5](tostring(otInterval[0]))
local useMilliseconds = new.bool(false)
local reportAnsweredCount = 0

local main_window_state = new.bool(false)
local info_window_state = new.bool(false)
local active_tab = new.int(0)
local sw, sh = getScreenResolution()
local tag = "{1E90FF} [RepFlow]: {FFFFFF}"
local taginf = "{1E90FF} [Информация]: {FFFFFF}"

local startTime = 0
local gameMinimized = false
local wasActiveBeforePause = false
local afkExitTime = 0
local afkCooldown = 30
local disableAutoStartOnToggle = false
local changingKey = false

local isDraggingInfo = false
local dragOffsetX, dragOffsetY = 0, 0

local lastDialogTime = os.clock()
local dialogTimeoutBuffer = imgui.new.char[5](tostring(dialogTimeout[0]))
local manualDisable = false
local autoStartEnabled = new.bool(true)
local dialogHandlerEnabled = new.bool(true)
local hideFloodMsg = new.bool(true)

local my_nick_utf8 = "Игрок"   -- здесь будет имя в UTF-8 после преобразования

-- ФУНКЦИИ ОБНОВЛЕНИЯ
function checkUpdates()
    update_status = "Проверка наличия обновлений..."
    local path = getWorkingDirectory() .. '\\repflow_upd.json'
    downloadUrlToFile(UPDATE_URL, path, function(id, status, p1, p2)
        if status == 58 then
            local f = io.open(path, 'r')
            if f then
                local content = f:read('*a')
                f:close()
                os.remove(path)
                local ok, info = pcall(decodeJson, content)
                if ok and info and info.version then
                    if info.version ~= scriptver then
                        update_status = "Доступна версия: " .. info.version
                        update_found = true
                        sampAddChatMessage(tag .. "{00FF00}Найдено обновление! Версия: " .. info.version, -1)
                    else
                        update_status = "У вас последняя версия."
                        update_found = false
                    end
                end
            end
        end
    end)
end

function updateScript()
    update_status = "Загрузка файла..."
    local scriptPath = thisScript().path
    downloadUrlToFile(SCRIPT_URL, scriptPath, function(id, status, p1, p2)
        if status == 58 then
            sampAddChatMessage(tag .. "{00FF00}Скрипт обновлен! Перезагрузка...", -1)
            thisScript():reload()
        end
    end)
end

-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function getPlayerName()
    local name = samp.get_current_player_name and samp.get_current_player_name()
    if name and name ~= "" then
        my_nick_utf8 = u8(name)   -- преобразуем из CP1251 в UTF-8
    end
end

local ini = inicfg.load({
    main = {
        keyBind = "0x5A", keyBindName = 'Z', otInterval = 10, useMilliseconds = false,
        theme = 0, transparency = 0.8, dialogTimeout = 600, dialogHandlerEnabled = true,
        autoStartEnabled = true, otklflud = false,
    },
    widget = { posX = 400, posY = 400, sizeX = 600, sizeY = 400 }
}, IniFilename)

local MoveWidget = false
keyBind = tonumber(ini.main.keyBind)
keyBindName = ini.main.keyBindName
otInterval[0] = tonumber(ini.main.otInterval)
useMilliseconds[0] = ini.main.useMilliseconds
dialogTimeout[0] = tonumber(ini.main.dialogTimeout)
dialogHandlerEnabled[0] = ini.main.dialogHandlerEnabled
autoStartEnabled[0] = ini.main.autoStartEnabled or false
hideFloodMsg[0] = ini.main.otklflud

local themeValue = tonumber(ini.main.theme)
if themeValue == nil or themeValue < 0 or themeValue > 1 then
    themeValue = 0
    ini.main.theme = 0
    inicfg.save(ini, IniFilename)
end
local currentTheme = new.int(themeValue)

local transparency = new.float(ini.main.transparency or 0.8)

local colors = {}
local function applyTheme(themeIndex)
    if themeIndex == 0 then
        colors = {
            leftPanelColor = imgui.ImVec4(27/255,20/255,30/255,transparency[0]),
            rightPanelColor = imgui.ImVec4(24/255,18/255,28/255,transparency[0]),
            childPanelColor = imgui.ImVec4(18/255,13/255,22/255,transparency[0]),
            hoverColor = imgui.ImVec4(63/255,59/255,66/255,transparency[0]),
            textColor = imgui.ImVec4(1,1,1,1),
        }
    else
        colors = {
            leftPanelColor = imgui.ImVec4(0,0,0,transparency[0]),
            rightPanelColor = imgui.ImVec4(0,0,0,transparency[0]),
            childPanelColor = imgui.ImVec4(0.05,0.05,0.05,transparency[0]),
            hoverColor = imgui.ImVec4(0.2,0.2,0.2,transparency[0]),
            textColor = imgui.ImVec4(1,1,1,1),
        }
    end
end
applyTheme(currentTheme[0])

local lastWindowSize = nil

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand("arep", cmd_arep)

    getPlayerName()
    sampAddChatMessage(tag .. 'Скрипт {00FF00}загружен.{FFFFFF} Активация меню: {00FF00}/arep', -1)
    show_arz_notify('success', 'RepFlow', 'Скрипт загружен. Активация: /arep', 3000)

    local prev_main_state = false

    while true do
        wait(0)

        checkPauseAndDisableAutoStart()
        checkAutoStart()

        if main_window_state[0] and not isGameMinimized then
            imgui.Process = true
        else
            imgui.Process = false
        end

        if main_window_state[0] ~= prev_main_state then
            if main_window_state[0] then
                sampToggleCursor(true)
            else
                sampToggleCursor(false)
                resetIO()
            end
            prev_main_state = main_window_state[0]
        end

        if MoveWidget then
            local cursorX, cursorY = getCursorPos()
            ini.widget.posX = cursorX
            ini.widget.posY = cursorY
            if isKeyJustPressed(0x20) then
                MoveWidget = false
                sampToggleCursor(false)
                saveWindowSettings()
            end
        end

        if active or MoveWidget then
            showInfoWindow()
        else
            showInfoWindowOff()
        end

        if not changingKey and isKeyJustPressed(keyBind) and not isSampfuncsConsoleActive() and not sampIsChatInputActive() and not sampIsDialogActive() and not isPauseMenuActive() then
            onToggleActive()
        end

        if info_window_state[0] and not MoveWidget then
            local altPressed = isKeyDown(vkeys.VK_MENU)
            local mousePressed = imgui.GetIO().MouseDown[0]
            local mouseX, mouseY = getCursorPos()

            if altPressed and mousePressed and not isDraggingInfo then
                local winX, winY = ini.widget.posX, ini.widget.posY
                local winW, winH = 240, active and 120 or 280
                if mouseX >= winX and mouseX <= winX + winW and mouseY >= winY and mouseY <= winY + 30 then
                    isDraggingInfo = true
                    dragOffsetX = mouseX - winX
                    dragOffsetY = mouseY - winY
                end
            end

            if isDraggingInfo then
                if mousePressed then
                    ini.widget.posX = mouseX - dragOffsetX
                    ini.widget.posY = mouseY - dragOffsetY
                else
                    isDraggingInfo = false
                    inicfg.save(ini, IniFilename)
                end
            end
        else
            isDraggingInfo = false
        end

        if active then
            local currentTime = os.clock() * 1000
            local interval = useMilliseconds[0] and otInterval[0] or otInterval[0] * 1000
            if currentTime - lastOtTime >= interval then
                sampSendChat('/ot')
                lastOtTime = currentTime
            end
        else
            startTime = os.clock()
        end
    end
end

function resetIO()
    for i = 0, 511 do imgui.GetIO().KeysDown[i] = false end
    for i = 0, 4 do imgui.GetIO().MouseDown[i] = false end
    imgui.GetIO().KeyCtrl = false; imgui.GetIO().KeyShift = false
    imgui.GetIO().KeyAlt = false; imgui.GetIO().KeySuper = false
end

function startMovingWindow()
    MoveWidget = true
    showInfoWindow()
    sampToggleCursor(true)
    main_window_state[0] = false
    sampAddChatMessage(taginf .. '{FFFF00}Режим перемещения окна активирован. Нажмите "Пробел" для подтверждения.', -1)
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    io.IniFilename = nil
    io.Fonts:AddFontDefault()
    decor()
end)

function decor()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(12,12)
    style.WindowRounding = 12
    style.ChildRounding = 10
    style.FramePadding = imgui.ImVec2(8,6)
    style.FrameRounding = 10
    style.ItemSpacing = imgui.ImVec2(10,10)
    style.ItemInnerSpacing = imgui.ImVec2(10,10)
    style.ScrollbarSize = 12
    style.ScrollbarRounding = 10
    style.GrabRounding = 10
    style.PopupRounding = 10
    style.WindowTitleAlign = imgui.ImVec2(0.5,0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5,0.5)
end

function sampev.onServerMessage(color, text)
    if text:find('%[(%W+)%] от (%w+_%w+)%[(%d+)%]:') then
        if active then sampSendChat('/ot') end
    end
    return filterFloodMessage(text)
end

function onToggleActive()
    active = not active
    manualDisable = not active
    disableAutoStartOnToggle = not active
    local statusArz = active and 'включена' or 'выключена'
    show_arz_notify('info', 'RepFlow', 'Ловля ' .. statusArz .. '!', 2000)
end

function saveWindowSettings()
    ini.widget.posX = ini.widget.posX or 400
    ini.widget.posY = ini.widget.posY or 400
    inicfg.save(ini, IniFilename)
    sampAddChatMessage(taginf .. '{00FF00}Положение окна сохранено!', -1)
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 1334 then
        lastDialogTime = os.clock()
        reportAnsweredCount = reportAnsweredCount + 1
        sampAddChatMessage(tag .. '{00FF00}Репорт принят! Отвечено репорта: ' .. reportAnsweredCount, -1)
        if active then
            active = false
            show_arz_notify('info', 'RepFlow', 'Ловля отключена из-за окна репорта!', 3000)
        end
    end
end

function checkAutoStart()
    local currentTime = os.clock()
    if autoStartEnabled[0] and not active and not gameMinimized and (afkExitTime == 0 or currentTime - afkExitTime >= afkCooldown) then
        if not disableAutoStartOnToggle and (currentTime - lastDialogTime) > dialogTimeout[0] then
            active = true
            show_arz_notify('info', 'RepFlow', 'Ловля включена по таймауту', 3000)
        end
    end
end

function saveSettings() ini.main.dialogTimeout = dialogTimeout[0]; inicfg.save(ini, IniFilename) end

function imgui.Link(link, text)
    text = text or link
    local tSize = imgui.CalcTextSize(text)
    local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local col = { 0xFFFF7700, 0xFFFF9900 }
    if imgui.InvisibleButton('##' .. link, tSize) then os.execute('explorer ' .. link) end
    local color = imgui.IsItemHovered() and col[1] or col[2]
    DL:AddText(p, color, text)
    DL:AddLine(imgui.ImVec2(p.x, p.y + tSize.y), imgui.ImVec2(p.x + tSize.x, p.y + tSize.y), color)
end

function cmd_arep(arg)
    main_window_state[0] = not main_window_state[0]
    imgui.Process = main_window_state[0]
end

-- Функции отрисовки вкладок (без иконок, только текст)
function drawMainTab()
    imgui.Text("[G] Настройки  /  [M] Флудер")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Flooder", imgui.ImVec2(0,150), true) then
        imgui.PushItemWidth(100)
        if imgui.Checkbox("Использовать миллисекунды", useMilliseconds) then
            ini.main.useMilliseconds = useMilliseconds[0]
            inicfg.save(ini, IniFilename)
        end
        imgui.PopItemWidth()
        imgui.Text("Интервал отправки команды /ot (" .. (useMilliseconds[0] and "в миллисекундах" or "в секундах") .. "):")
        imgui.Text("Текущий интервал: " .. otInterval[0] .. (useMilliseconds[0] and " мс" or " секунд"))
        imgui.PushItemWidth(45)
        imgui.InputText("##otIntervalInput", otIntervalBuffer, ffi.sizeof(otIntervalBuffer))
        imgui.SameLine()
        if imgui.Button("[F] Сохранить интервал") then
            local newValue = tonumber(ffi.string(otIntervalBuffer))
            if newValue then
                otInterval[0] = newValue
                ini.main.otInterval = newValue
                inicfg.save(ini, IniFilename)
                sampAddChatMessage(taginf .. "Интервал сохранён: {32CD32}" .. newValue .. (useMilliseconds[0] and " мс" or " секунд"), -1)
            else
                sampAddChatMessage(taginf .. "Некорректное значение. {32CD32}Введите число.", -1)
            end
        end
        imgui.PopItemWidth()
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("InfoFlooder", imgui.ImVec2(0,65), true) then
        imgui.Text("Скрипт также ищет надпись в чате [Репорт] от Имя_Фамилия.")
        imgui.Text("Флудер нужен для дополнительного способа ловли репорта.")
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawSettingsTab()
    imgui.Text("[G] Настройки  /  [S] Основные настройки")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("KeyBind", imgui.ImVec2(0,60), true) then
        imgui.Text("Текущая клавиша активации:")
        imgui.SameLine()
        if imgui.Button("" .. keyBindName) then
            changingKey = true
            show_arz_notify('info', 'RepFlow', 'Нажмите новую клавишу для активации', 2000)
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("DialogOptions", imgui.ImVec2(0,150), true) then
        imgui.Text("Обработка диалогов")
        if imgui.Checkbox("Обрабатывать диалоги", dialogHandlerEnabled) then
            ini.main.dialogHandlerEnabled = dialogHandlerEnabled[0]
            inicfg.save(ini, IniFilename)
        end
        if imgui.Checkbox("Автостарт ловли по большому активу", autoStartEnabled) then
            ini.main.autoStartEnabled = autoStartEnabled[0]
            inicfg.save(ini, IniFilename)
        end
        if imgui.Checkbox("Отключить сообщение \"Не флуди\"", hideFloodMsg) then
            ini.main.otklflud = hideFloodMsg[0]
            inicfg.save(ini, IniFilename)
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("AutoStartTimeout", imgui.ImVec2(0,100), true) then
        imgui.Text("Настройка тайм-аута автостарта")
        imgui.PushItemWidth(45)
        imgui.Text("Текущий тайм-аут: " .. dialogTimeout[0] .. " секунд")
        imgui.InputText("", dialogTimeoutBuffer, ffi.sizeof(dialogTimeoutBuffer))
        imgui.SameLine()
        if imgui.Button("[F] Сохранить тайм-аут") then
            local newValue = tonumber(ffi.string(dialogTimeoutBuffer))
            if newValue and newValue >= 1 and newValue <= 9999 then
                dialogTimeout[0] = newValue
                saveSettings()
                sampAddChatMessage(taginf .. "Тайм-аут сохранён: {32CD32}" .. newValue .. " секунд", -1)
            else
                sampAddChatMessage(taginf .. "Некорректное значение. {32CD32}Введите от 1 до 9999.", -1)
            end
        end
        imgui.PopItemWidth()
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("WindowPosition", imgui.ImVec2(0,50), true) then
        imgui.Text("Положение окна информации:")
        imgui.SameLine()
        if imgui.Button("Изменить положение") then
            startMovingWindow()
        end
        imgui.TextDisabled("(Alt + ЛКМ по заголовку для перемещения)")
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawThemesTab()
    imgui.Text("[P] Темы")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Themes", imgui.ImVec2(0,250), true) then
        imgui.Text("Выберите тему оформления:")
        local themeNames = { "Прозрачная", "Чёрная" }
        for i, name in ipairs(themeNames) do
            if imgui.Button(name, imgui.ImVec2(120,40)) then
                currentTheme[0] = i-1
                applyTheme(currentTheme[0])
                ini.main.theme = currentTheme[0]
                inicfg.save(ini, IniFilename)
                sampAddChatMessage(taginf .. "Тема изменена на {32CD32}" .. name, -1)
            end
            if i < #themeNames then imgui.SameLine() end
        end

        local themeIndex = currentTheme[0] or 0
        themeIndex = math.floor(themeIndex)
        if themeIndex < 0 or themeIndex > 1 then themeIndex = 0 end

        imgui.Text("Текущая тема: " .. themeNames[themeIndex+1])

        imgui.Separator()
        imgui.Text("Прозрачность фона (для обеих тем):")
        if imgui.SliderFloat("##transparency", transparency, 0.3, 1.0, "%.2f") then
            applyTheme(currentTheme[0])
            ini.main.transparency = transparency[0]
            inicfg.save(ini, IniFilename)
        end
        imgui.TextDisabled("1.0 - непрозрачный, 0.3 - сильно прозрачный")
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawUpdatesTab()
    imgui.Text("Облачное обновление")
    imgui.Separator()
    imgui.Text("Текущая версия: " .. scriptver)
    imgui.Text("Статус: " .. update_status)
    if imgui.Button("Проверить заново", imgui.ImVec2(160, 30)) then checkUpdates() end
    if update_found then
        imgui.SameLine()
        if imgui.Button("Установить сейчас", imgui.ImVec2(160, 30)) then updateScript() end
    end
end

function filterFloodMessage(text)
    if hideFloodMsg[0] then
        if text:find("Сейчас нет вопросов в репорт!", 1, true) or text:find("Не флуди!", 1, true) then
            return false
        end
    end
    return true
end

function checkPauseAndDisableAutoStart()
    if isPauseMenuActive() then
        if not gameMinimized then
            wasActiveBeforePause = active
            if active then active = false end
            gameMinimized = true
        end
    else
        if gameMinimized then
            gameMinimized = false
            if wasActiveBeforePause then
                sampAddChatMessage(tag .. '{FFFFFF}Вы вышли из паузы. Ловля отключена из-за AFK!!', -1)
            end
        end
    end
end

function drawInfoTab(panelColor)
    panelColor = panelColor or colors.childPanelColor
    imgui.Text("[I] RepFlow  /  [i] Информация")
    imgui.Separator()

    imgui.PushStyleColor(imgui.Col.ChildBg, panelColor)
    if imgui.BeginChild("Author", imgui.ImVec2(0,130), true) then
        imgui.Text("Автор: Balenciaga_Collins[18]")
        imgui.Text("Версия: " .. scriptver)
        imgui.Text("Связь с разработчиком:")
        imgui.SameLine()
        imgui.Link('https://t.me/Repflowarizona', 'Telegram')
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, panelColor)
    if imgui.BeginChild("Info2", imgui.ImVec2(0,100), true) then
        imgui.Text("Скрипт автоматически отправляет команду /ot.")
        imgui.Text("Через определенные интервалы времени.")
        imgui.Text("А также выслеживает определенные надписи.")
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, panelColor)
    if imgui.BeginChild("Info3", imgui.ImVec2(0,110), true) then
        imgui.CenterText("Благодарности:")
        imgui.Text("Тестер: Arman_Carukjan")
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawChangeLogTab()
    imgui.Text("[C] ChangeLog")
    imgui.Separator()

    for _, entry in ipairs(changelogEntries) do
        if imgui.CollapsingHeader("Версия " .. entry.version) then
            imgui.Text(entry.description)
        end
    end
end

imgui.OnFrame(function() return main_window_state[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(ini.widget.sizeX, ini.widget.sizeY), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5,0.5))
    imgui.PushStyleColor(imgui.Col.WindowBg, colors.rightPanelColor)

    if imgui.Begin("[R] RepFlow | Premium", main_window_state, imgui.WindowFlags.NoCollapse) then

        imgui.PushStyleColor(imgui.Col.ChildBg, colors.leftPanelColor)
        if imgui.BeginChild("left_panel", imgui.ImVec2(130,-1), false) then
            local tabNames = { "Флудер", "Настройки", "Информация", "ChangeLog", "Темы", "Обновления" }
            for i, name in ipairs(tabNames) do
                if i-1 == active_tab[0] then
                    imgui.PushStyleColor(imgui.Col.Button, colors.hoverColor)
                else
                    imgui.PushStyleColor(imgui.Col.Button, colors.leftPanelColor)
                end
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.hoverColor)
                imgui.PushStyleColor(imgui.Col.ButtonActive, colors.hoverColor)

                if imgui.Button(name, imgui.ImVec2(125,40)) then
                    active_tab[0] = i-1
                end
                imgui.PopStyleColor(3)
            end
        end
        imgui.EndChild()
        imgui.PopStyleColor()

        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.ChildBg, colors.rightPanelColor)
        if imgui.BeginChild("right_panel", imgui.ImVec2(-1,0), false) then
            if active_tab[0] == 0 then drawMainTab()
            elseif active_tab[0] == 1 then drawSettingsTab()
            elseif active_tab[0] == 2 then drawInfoTab(colors.rightPanelColor)
            elseif active_tab[0] == 3 then drawChangeLogTab()
            elseif active_tab[0] == 4 then drawThemesTab()
            elseif active_tab[0] == 5 then drawUpdatesTab() end
        end
        imgui.EndChild()
        imgui.PopStyleColor()

        local winSize = imgui.GetWindowSize()
        if lastWindowSize == nil then
            lastWindowSize = imgui.ImVec2(winSize.x, winSize.y)
        elseif lastWindowSize.x ~= winSize.x or lastWindowSize.y ~= winSize.y then
            lastWindowSize = imgui.ImVec2(winSize.x, winSize.y)
            ini.widget.sizeX = winSize.x
            ini.widget.sizeY = winSize.y
            inicfg.save(ini, IniFilename)
        end
    end
    imgui.End()
    imgui.PopStyleColor()
end)

function onWindowMessage(msg, wparam, lparam)
    if changingKey then
        if msg == 0x100 or msg == 0x101 then
            keyBind = wparam
            keyBindName = vkeys.id_to_name(keyBind)
            changingKey = false
            ini.main.keyBind = string.format("0x%X", keyBind)
            ini.main.keyBindName = keyBindName
            inicfg.save(ini, IniFilename)
            sampAddChatMessage(string.format(tag .. '{FFFFFF}Новая клавиша активации ловли репорта: {00FF00}%s', keyBindName), -1)
            return false
        end
    end
end

function imgui.CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX(width/2 - calc.x/2)
    imgui.Text(text)
end

function show_arz_notify(type, title, text, time)
    if MONET_VERSION then
        if type == 'info' then type = 3 elseif type == 'error' then type = 2 elseif type == 'success' then type = 1 end
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs,62)
        raknetBitStreamWriteInt8(bs,6)
        raknetBitStreamWriteBool(bs,true)
        raknetEmulPacketReceiveBitStream(220,bs)
        raknetDeleteBitStream(bs)
        local json = encodeJson({styleInt=type,title=title,text=text,duration=time})
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs,84)
        raknetBitStreamWriteInt8(bs,6)
        raknetBitStreamWriteInt8(bs,0)
        raknetBitStreamWriteInt32(bs,#json)
        raknetBitStreamWriteString(bs,json)
        raknetEmulPacketReceiveBitStream(220,bs)
        raknetDeleteBitStream(bs)
    else
        local str = ('window.executeEvent(\'event.notify.initialize\', \'["%s", "%s", "%s", "%s"]\');'):format(type,title,text,time)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs,17)
        raknetBitStreamWriteInt32(bs,0)
        raknetBitStreamWriteInt32(bs,#str)
        raknetBitStreamWriteString(bs,str)
        raknetEmulPacketReceiveBitStream(220,bs)
        raknetDeleteBitStream(bs)
    end
end

-- Окно информации
imgui.OnFrame(function() return info_window_state[0] end, function(self)
    self.HideCursor = true
    local windowWidth = 240
    local windowHeight = active and 120 or 280
    imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(ini.widget.posX, ini.widget.posY), imgui.Cond.Always)

    imgui.Begin("[i] Информация ", info_window_state, 
                imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoInputs)

    imgui.CenterText("Статус Ловли: " .. (active and "Включена" or "Выключена"))
    local elapsedTime = os.clock() - startTime
    imgui.CenterText(string.format("Время работы: %.2f сек", elapsedTime))
    imgui.CenterText(string.format("Отвечено репорта: %d", reportAnsweredCount))

    if not active then
        imgui.Separator()
        imgui.Text("Обработка диалогов:")
        imgui.SameLine()
        imgui.Text(dialogHandlerEnabled[0] and "Включена" or "Выкл.")
        imgui.Text("Автостарт:")
        imgui.SameLine()
        imgui.Text(autoStartEnabled[0] and "Включен" or "Выключен")
        imgui.Separator()
        imgui.TextDisabled("Перемещение: Alt + ЛКМ по заголовку")
        imgui.Text("Скрипт активен: " .. formatTime(os.clock() - scriptStartTime))
        imgui.Text("Ваш ник: " .. my_nick_utf8)
    end

    imgui.End()
end)

function showInfoWindow() info_window_state[0] = true end
function showInfoWindowOff() info_window_state[0] = false end
