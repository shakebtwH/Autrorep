require 'lib.moonloader'
local imgui = require 'mimgui'
local sampev = require 'lib.samp.events'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local ffi = require 'ffi'

local IniFilename = 'RepFlowCFG.ini'
local new = imgui.new
local scriptver = "3.12 | Premium"

-- Настройки GitHub (ЗАМЕНИТЕ НА ВАШИ)
local GITHUB_USER = "MatthewMcLaren"
local GITHUB_REPO = "repflow"
local GITHUB_BRANCH = "main" -- или master
local GITHUB_RAW = string.format("https://raw.githubusercontent.com/shakebtwH/Autrorep/refs/heads/main/update.ini", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH)

-- Имена файлов в репозитории
local VERSION_FILE = "version.txt"       -- файл, содержащий версию (например, "3.12 | Premium")
local SCRIPT_FILE = "repflow.lua"        -- файл скрипта (должен называться так же, как в репозитории)

-- Флаг наличия HTTPS библиотеки
local has_https = pcall(require, 'ssl.https')

-- Информация об обновлениях
local updateInfo = {
    available = false,
    latestVersion = "",
    description = "",
    error = nil
}
local checkingUpdates = false
local downloading = false

local changelogEntries = {
    { version = "3.12 | Premium", description = "- Упрощено автообновление через GitHub (без JSON, используется raw)." },
    { version = "3.11 | Premium", description = "- Добавлено автообновление через GitHub (проверка и установка последнего релиза).\n- Требуется библиотека json/dkjson и ssl.https." },
    { version = "3.10 | Premium", description = "- Вкладка 'Обновления' теперь временно неактивна (в разработке).\n- Исправлено отображение текущей темы при некорректном значении в конфиге." },
    { version = "3.9 | Premium", description = "- Добавлена вкладка 'Обновления' с автоматической проверкой и установкой новой версии.\n- Исправлено отображение текущей темы на вкладке 'Темы'." },
    { version = "3.8 | Premium", description = "- Добавлена вкладка 'Темы' с тремя цветовыми схемами: Чёрная, Белая, Красная." },
    { version = "3.7 | Premium", description = "- Исправлена совместимость со старыми версиями mimgui (убраны флаги фокуса)." },
    { version = "3.6 | Premium", description = "- Исправлено перемещение и изменение размера главного окна (убран лишний сброс ввода)." },
    { version = "3.5 | Premium", description = "- Исправлено перемещение и изменение размера главного окна (перенесён resetIO)." },
    { version = "3.4 | Premium", description = "- Добавлена возможность изменять размер главного окна (перетаскиванием за края). Размер сохраняется в конфиг." },
    { version = "3.3 | Premium", description = "- Исправлено: при нажатии клавиши активации больше не появляется курсор (окно информации теперь не перехватывает ввод)." },
    { version = "3.2 | Premium", description = "- Исправлена ошибка с иконками (убрана зависимость от fAwesome6).\n- Исправлено: при закрытии окна крестиком курсор больше не остаётся на экране." },
    { version = "3.1 | Premium", description = "- Новый стиль меню.\n- ChangeLog теперь разделён на две версии.\n\nHF-1.0: Исправлены грамматические ошибки\n\nHF-1.1: Налажен цвет плиток\n- Исправлены грамматические ошибки." },
}

local keyBind = 0x5A
local keyBindName = 'Z'

local lastDialogId = nil
local reportActive = false
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

encoding.default = 'CP1251'
u8 = encoding.UTF8

local lastDialogTime = os.clock()
local dialogTimeoutBuffer = imgui.new.char[5](tostring(dialogTimeout[0]))
local manualDisable = false
local autoStartEnabled = new.bool(true)
local dialogHandlerEnabled = new.bool(true)
local hideFloodMsg = new.bool(true)

-- Загрузка конфигурации
local ini = inicfg.load({
    main = {
        keyBind = string.format("0x%X", keyBind),
        keyBindName = keyBindName,
        otInterval = 10,
        useMilliseconds = false,
        theme = 0,
        dialogTimeout = 600,
        dialogHandlerEnabled = true,
        autoStartEnabled = true,
        otklflud = false,
    },
    widget = {
        posX = 400,
        posY = 400,
        sizeX = 800,
        sizeY = 500,
    }
}, IniFilename)
local MoveWidget = false

-- Применение загруженной конфигурации
keyBind = tonumber(ini.main.keyBind)
keyBindName = ini.main.keyBindName
otInterval[0] = tonumber(ini.main.otInterval)
useMilliseconds[0] = ini.main.useMilliseconds
dialogTimeout[0] = tonumber(ini.main.dialogTimeout)
dialogHandlerEnabled[0] = ini.main.dialogHandlerEnabled
autoStartEnabled[0] = ini.main.autoStartEnabled or false
hideFloodMsg[0] = ini.main.otklflud

-- Текущая тема
local currentTheme = new.int(ini.main.theme or 0)
if currentTheme[0] < 0 or currentTheme[0] > 2 then
    currentTheme[0] = 0
    ini.main.theme = 0
    inicfg.save(ini, IniFilename)
end

-- Цвета темы
local colors = {}
function applyTheme(themeIndex)
    if themeIndex == 0 then -- Чёрная
        colors = {
            leftPanelColor = imgui.ImVec4(27/255,20/255,30/255,1),
            rightPanelColor = imgui.ImVec4(24/255,18/255,28/255,1),
            childPanelColor = imgui.ImVec4(18/255,13/255,22/255,1),
            hoverColor = imgui.ImVec4(63/255,59/255,66/255,1),
            textColor = imgui.ImVec4(1,1,1,1),
        }
    elseif themeIndex == 1 then -- Белая
        colors = {
            leftPanelColor = imgui.ImVec4(240/255,240/255,240/255,1),
            rightPanelColor = imgui.ImVec4(255/255,255/255,255/255,1),
            childPanelColor = imgui.ImVec4(230/255,230/255,230/255,1),
            hoverColor = imgui.ImVec4(200/255,200/255,200/255,1),
            textColor = imgui.ImVec4(0,0,0,1),
        }
    elseif themeIndex == 2 then -- Красная
        colors = {
            leftPanelColor = imgui.ImVec4(80/255,20/255,20/255,1),
            rightPanelColor = imgui.ImVec4(100/255,25/255,25/255,1),
            childPanelColor = imgui.ImVec4(120/255,30/255,30/255,1),
            hoverColor = imgui.ImVec4(150/255,40/255,40/255,1),
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

    sampAddChatMessage(tag .. 'Скрипт {00FF00}загружен.{FFFFFF} Активация меню: {00FF00}/arep', -1)
    show_arz_notify('success', 'RepFlow', 'Успешная загрузка. Активация: /arep', 9000)

    local prev_main_state = false

    while true do
        wait(0)

        checkPauseAndDisableAutoStart()
        checkAutoStart()

        imgui.Process = main_window_state[0] and not isGameMinimized

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

        if active then
            local currentTime = os.clock() * 1000
            if useMilliseconds[0] then
                if currentTime - lastOtTime >= otInterval[0] then
                    sampSendChat('/ot')
                    lastOtTime = currentTime
                end
            else
                if (currentTime - lastOtTime) >= (otInterval[0] * 1000) then
                    sampSendChat('/ot')
                    lastOtTime = currentTime
                end
            end
        else
            startTime = os.clock()
        end
    end
end

function resetIO()
    for i = 0, 511 do imgui.GetIO().KeysDown[i] = false end
    for i = 0, 4 do imgui.GetIO().MouseDown[i] = false end
    imgui.GetIO().KeyCtrl = false
    imgui.GetIO().KeyShift = false
    imgui.GetIO().KeyAlt = false
    imgui.GetIO().KeySuper = false
end

function startMovingWindow()
    MoveWidget = true
    showInfoWindow()
    sampToggleCursor(true)
    main_window_state[0] = false
    sampAddChatMessage(taginf .. '{FFFF00}Режим перемещения окна активирован. Нажмите "Пробел" для подтверждения.', -1)
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.GetIO().Fonts:AddFontDefault()
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

function saveSettings()
    ini.main.dialogTimeout = dialogTimeout[0]
    inicfg.save(ini, IniFilename)
end

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

local function icon(name) return "" end

function drawMainTab()
    imgui.Text(icon('gear') .. u8" Настройки  /  " .. icon('message') .. u8" Флудер")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Flooder", imgui.ImVec2(0,150), true) then
        imgui.PushItemWidth(100)
        if imgui.Checkbox(u8'Использовать миллисекунды', useMilliseconds) then
            ini.main.useMilliseconds = useMilliseconds[0]
            inicfg.save(ini, IniFilename)
        end
        imgui.PopItemWidth()
        imgui.Text(u8'Интервал отправки команды /ot (' .. (useMilliseconds[0] and u8'в миллисекундах' or u8'в секундах') .. '):')
        imgui.Text(u8'Текущий интервал: ' .. otInterval[0] .. (useMilliseconds[0] and u8' мс' or u8' секунд'))
        imgui.PushItemWidth(45)
        imgui.InputText(u8'##otIntervalInput', otIntervalBuffer, ffi.sizeof(otIntervalBuffer))
        imgui.SameLine()
        if imgui.Button(icon('floppy_disk') .. u8" Сохранить интервал") then
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
        imgui.Text(u8'Скрипт также ищет надпись в чате [Репорт] от Имя_Фамилия.')
        imgui.Text(u8'Флудер нужен для дополнительного способа ловли репорта.')
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawSettingsTab()
    imgui.Text(icon('gear') .. u8" Настройки  /  " .. icon('sliders') .. u8" Основные настройки")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("KeyBind", imgui.ImVec2(0,60), true) then
        imgui.Text(u8'Текущая клавиша активации:')
        imgui.SameLine()
        if imgui.Button(u8'' .. keyBindName) then
            changingKey = true
            show_arz_notify('info', 'RepFlow', 'Нажмите новую клавишу для активации', 2000)
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("DialogOptions", imgui.ImVec2(0,150), true) then
        imgui.Text(u8"Обработка диалогов")
        if imgui.Checkbox(u8'Обрабатывать диалоги', dialogHandlerEnabled) then
            ini.main.dialogHandlerEnabled = dialogHandlerEnabled[0]
            inicfg.save(ini, IniFilename)
        end
        if imgui.Checkbox(u8'Автостарт ловли по большому активу', autoStartEnabled) then
            ini.main.autoStartEnabled = autoStartEnabled[0]
            inicfg.save(ini, IniFilename)
        end
        if imgui.Checkbox(u8'Отключить сообщение "Не флуди"', hideFloodMsg) then
            ini.main.otklflud = hideFloodMsg[0]
            inicfg.save(ini, IniFilename)
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("AutoStartTimeout", imgui.ImVec2(0,100), true) then
        imgui.Text(u8'Настройка тайм-аута автостарта')
        imgui.PushItemWidth(45)
        imgui.Text(u8'Текущий тайм-аут: ' .. dialogTimeout[0] .. u8' секунд')
        imgui.InputText(u8'', dialogTimeoutBuffer, ffi.sizeof(dialogTimeoutBuffer))
        imgui.SameLine()
        if imgui.Button(icon('floppy_disk') .. u8" Сохранить тайм-аут") then
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
        imgui.Text(u8'Положение окна информации:')
        imgui.SameLine()
        if imgui.Button(u8'Изменить положение') then
            startMovingWindow()
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawThemesTab()
    imgui.Text(icon('palette') .. u8" Темы")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Themes", imgui.ImVec2(0,150), true) then
        imgui.Text(u8"Выберите тему оформления:")
        local themeNames = { "Черная", "Белая", "Красная" }
        for i, name in ipairs(themeNames) do
            if imgui.Button(u8(name), imgui.ImVec2(120,40)) then
                currentTheme[0] = i-1
                applyTheme(currentTheme[0])
                ini.main.theme = currentTheme[0]
                inicfg.save(ini, IniFilename)
                sampAddChatMessage(taginf .. "Тема изменена на {32CD32}" .. name, -1)
            end
            if i < #themeNames then imgui.SameLine() end
        end
        local idx = currentTheme[0]
        if idx < 0 or idx > 2 then idx = 0 end
        imgui.Text(u8"Текущая тема: " .. themeNames[idx+1])
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

-- Упрощённые функции обновления
function checkForUpdates()
    if checkingUpdates then return end
    if not has_https then
        updateInfo.error = "Библиотека ssl.https не найдена. Установите lua-ssl."
        return
    end

    checkingUpdates = true
    updateInfo.available = false
    updateInfo.error = nil

    local https = require 'ssl.https'
    local versionUrl = GITHUB_RAW .. VERSION_FILE
    local response = {}
    local res, code = https.request{
        url = versionUrl,
        sink = ltn12.sink.table(response)
    }

    if code ~= 200 then
        updateInfo.error = "Ошибка HTTP при загрузке версии: " .. tostring(code)
        checkingUpdates = false
        return
    end

    local versionData = table.concat(response):gsub("^%s+", ""):gsub("%s+$", "") -- обрезаем пробелы
    if versionData == "" then
        updateInfo.error = "Пустой ответ от сервера версий"
        checkingUpdates = false
        return
    end

    -- Сравниваем с текущей версией (простое строковое сравнение)
    if versionData ~= scriptver then
        updateInfo.available = true
        updateInfo.latestVersion = versionData
        -- Загружаем описание из отдельного файла? Можно не загружать, оставить пустым
        updateInfo.description = "Обновление доступно"
    else
        updateInfo.available = false
    end
    checkingUpdates = false
end

function installUpdate()
    if not updateInfo.available or downloading then return end
    if not has_https then
        updateInfo.error = "Нет библиотеки https"
        return
    end

    downloading = true
    local https = require 'ssl.https'
    local currentPath = thisScript().path
    local backupPath = currentPath:gsub("%.lua$", "_backup.lua")
    local tempPath = currentPath:gsub("%.lua$", "_new.lua")
    local scriptUrl = GITHUB_RAW .. SCRIPT_FILE

    -- Скачиваем новый файл
    local file = io.open(tempPath, "wb")
    if not file then
        updateInfo.error = "Не удалось создать временный файл"
        downloading = false
        return
    end

    local res, code = https.request{
        url = scriptUrl,
        sink = ltn12.sink.file(file)
    }
    file:close()

    if code ~= 200 then
        updateInfo.error = "Ошибка загрузки скрипта: " .. tostring(code)
        os.remove(tempPath)
        downloading = false
        return
    end

    -- Создаём бэкап
    os.rename(currentPath, backupPath)

    -- Заменяем
    local ok = os.rename(tempPath, currentPath)
    if not ok then
        -- Восстанавливаем из бэкапа
        os.rename(backupPath, currentPath)
        updateInfo.error = "Не удалось заменить файл"
        downloading = false
        return
    end

    -- Удаляем бэкап
    os.remove(backupPath)

    sampAddChatMessage(tag .. "{00FF00}Обновление установлено! Перезапустите скрипт командой /lua reload " .. thisScript().name, -1)
    show_arz_notify('success', 'RepFlow', 'Обновление установлено! Перезапустите скрипт.', 5000)

    updateInfo.available = false
    downloading = false
end

function drawUpdatesTab()
    imgui.Text(icon('cloud-arrow-up') .. u8" Обновления")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Updates", imgui.ImVec2(0,200), true) then
        imgui.Text(u8"Текущая версия: " .. scriptver)
        imgui.Separator()

        if not has_https then
            imgui.TextColored(imgui.ImVec4(1,0,0,1), u8"Ошибка: не установлена библиотека ssl.https")
        else
            if checkingUpdates then
                imgui.Text(u8"Проверка обновлений...")
            else
                if imgui.Button(u8"Проверить обновления", imgui.ImVec2(200,30)) then
                    lua_thread.create(checkForUpdates)
                end

                if updateInfo.error then
                    imgui.TextColored(imgui.ImVec4(1,0,0,1), u8"Ошибка: " .. updateInfo.error)
                elseif updateInfo.available then
                    imgui.TextColored(imgui.ImVec4(0,1,0,1), u8"Доступно обновление!")
                    imgui.Text(u8"Новая версия: " .. updateInfo.latestVersion)
                    imgui.TextWrapped(u8"Описание: " .. updateInfo.description)
                    if not downloading then
                        if imgui.Button(u8"Установить обновление", imgui.ImVec2(200,30)) then
                            lua_thread.create(installUpdate)
                        end
                    else
                        imgui.Text(u8"Загрузка...")
                    end
                elseif updateInfo.latestVersion then
                    imgui.Text(u8"У вас актуальная версия.")
                end
            end
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function filterFloodMessage(text)
    if hideFloodMsg[0] then
        if text:find("%[Ошибка%] {FFFFFF}Сейчас нет вопросов в репорт!") or text:find("%[Ошибка%] {FFFFFF}Не флуди!") then
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
    imgui.Text(icon('star') .. u8" RepFlow  /  " .. icon('circle_info') .. u8" Информация")
    imgui.Separator()

    imgui.PushStyleColor(imgui.Col.ChildBg, panelColor)
    if imgui.BeginChild("Author", imgui.ImVec2(0,100), true) then
        imgui.Text(u8'Автор: Matthew_McLaren[18]')
        imgui.Text(u8'Версия: ' .. scriptver)
        imgui.Text(u8'Связь с разработчиком:')
        imgui.SameLine()
        imgui.Link('https://t.me/Zorahm', 'Telegram')
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, panelColor)
    if imgui.BeginChild("Info2", imgui.ImVec2(0,100), true) then
        imgui.Text(u8'Скрипт автоматически отправляет команду /ot.')
        imgui.Text(u8'Через определенные интервалы времени.')
        imgui.Text(u8'А также выслеживает определенные надписи.')
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, panelColor)
    if imgui.BeginChild("Info3", imgui.ImVec2(0,110), true) then
        imgui.CenterText(u8'А также спасибо:')
        imgui.Text(u8'Тестер: Carl_Mort[18].')
        imgui.Text(u8'Тестер: Sweet_Lemonte[18].')
        imgui.Text(u8'Тестер: Balenciaga_Collins[18].')
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawChangeLogTab()
    imgui.Text(icon('star') .. u8" RepFlow  /  " .. icon('bolt') .. u8" ChangeLog")
    imgui.Separator()

    for _, entry in ipairs(changelogEntries) do
        if imgui.CollapsingHeader(u8("Версия ") .. entry.version) then
            imgui.Text(u8(entry.description))
        end
    end
end

imgui.OnFrame(function() return main_window_state[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(ini.widget.sizeX, ini.widget.sizeY), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5,0.5))
    imgui.PushStyleColor(imgui.Col.WindowBg, colors.rightPanelColor)

    if imgui.Begin(icon('bolt') .. u8' RepFlow | Premium', main_window_state, imgui.WindowFlags.NoCollapse) then

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

                if imgui.Button(u8(name), imgui.ImVec2(125,40)) then
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

imgui.OnFrame(function() return info_window_state[0] end, function(self)
    self.HideCursor = true
    imgui.SetNextWindowSize(imgui.ImVec2(220,175), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(ini.widget.posX, ini.widget.posY), imgui.Cond.Always)
    imgui.Begin(icon('star') .. u8" | Информация ", info_window_state, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoInputs)
    imgui.CenterText(u8'Статус Ловли: Включена')
    local elapsedTime = os.clock() - startTime
    imgui.CenterText(string.format(u8'Время работы: %.2f сек', elapsedTime))
    imgui.CenterText(string.format(u8'Отвечено репорта: %d', reportAnsweredCount))
    imgui.Separator()
    imgui.Text(u8'Обработка диалогов:')
    imgui.SameLine()
    imgui.Text(dialogHandlerEnabled[0] and u8'Включена' or u8'Выкл.')
    imgui.Text(u8'Автостарт:')
    imgui.SameLine()
    imgui.Text(autoStartEnabled[0] and u8'Включен' or u8'Выключен')
    imgui.End()
end)

function showInfoWindow() info_window_state[0] = true end
function showInfoWindowOff() info_window_state[0] = false end