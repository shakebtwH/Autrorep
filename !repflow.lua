require 'lib.moonloader'
local imgui = require 'mimgui'
local sampev = require 'lib.samp.events'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local ffi = require 'ffi'

-- Настройка кодировок
encoding.default = 'CP1251'
local function toCP1251(utf8_str)
    return encoding.UTF8:decode(utf8_str)
end
local function toUTF8(cp1251_str)
    return encoding.UTF8:encode(cp1251_str)
end

-- === НАСТРОЙКИ ОБНОВЛЕНИЯ ===
local UPDATE_URL = "https://raw.githubusercontent.com/shakebtwH/Autrorep/main/update.json"
local SCRIPT_URL = "https://raw.githubusercontent.com/shakebtwH/Autrorep/main/%21repflow.lua"
local update_found = false
local update_status = "Проверка не проводилась"
-- =============================

if not samp then samp = {} end

local IniFilename = 'RepFlowCFG.ini'
local new = imgui.new
local scriptver = "4.38 | Premium"

local scriptStartTime = os.clock()

local changelogEntries = {
    { version = "4.37 | Premium", description = "- Уменьшен размер главного окна до 680x420 для более компактного вида.\n- Увеличено информационное окно до 280 пикселей, текст теперь не выходит за границы.\n- Исправлено возможное смещение текста в окне информации (использован перенос строк).\n- Мелкие правки интерфейса для идеального выравнивания." },
    { version = "4.36 | Premium", description = "- Интерфейс полностью переработан: увеличен размер окна до 750x480, левая панель 160px.\n- Исправлены все текстовые ошибки: 'Фулдер' → 'Флудер', 'Образовать диалоги' → 'Обрабатывать диалоги', кнопка '[F] Сохранить тайм-а!' → '[F] Сохранить тайм-аут'.\n- Увеличены размеры кнопок, чекбоксов, полей ввода – текст теперь нигде не обрезается.\n- Добавлены отступы для аккуратного выравнивания." },
    { version = "4.35 | Premium", description = "- Увеличен размер интерфейса до 700x450, левая панель 150px.\n- Исправлено отображение элементов во вкладке 'Настройки'." },
    { version = "4.34 | Premium", description = "- Уменьшен размер окна, добавлен тестер Sora_Deathmarried." },
    { version = "4.33 | Premium", description = "- Автоматическая проверка обновлений при запуске скрипта." },
    { version = "4.32 | Premium", description = "- Обновлён дизайн интерфейса: более современные цвета, скругления, отступы." },
    { version = "4.31 | Premium", description = "- Исправлена работа фильтра 'Не флуди'." },
    { version = "4.30 | Premium", description = "- Оптимизация кода, исправление ошибок." },
    { version = "4.29 | Premium", description = "- Исправлена работа фильтра 'Не флуди' (теперь учитываются знаки препинания и разные окончания)." },
    { version = "4.28 | Premium", description = "- Улучшен фильтр 'Не флуди' (удаление цветовых кодов {RRGGBB} и #AARRGGBB, поиск по ключевым словам)." },
    { version = "4.27 | Premium", description = "- Улучшен фильтр 'Не флуди' (нижний регистр, удаление цветовых кодов)." },
    { version = "4.26 | Premium", description = "- Исправлена ошибка 'show_arz_notify nil'." },
    { version = "4.25 | Premium", description = "- Исправлена работа фильтра 'Не флуди'." },
    { version = "4.24 | Premium", description = "- Исправлена ошибка 'encoding.CP1251 is nil'." },
    { version = "4.23 | Premium", description = "- Исправлены кракозябры в чате." },
}

-- Функция приведения UTF-8 строки к нижнему регистру (только русские буквы)
local utf8_lower_map = {
    ['\208\144'] = '\208\176', -- А -> а
    ['\208\145'] = '\208\177', -- Б -> б
    ['\208\146'] = '\208\178', -- В -> в
    ['\208\147'] = '\208\179', -- Г -> г
    ['\208\148'] = '\208\180', -- Д -> д
    ['\208\149'] = '\208\181', -- Е -> е
    ['\208\129'] = '\209\145', -- Ё -> ё
    ['\208\150'] = '\208\182', -- Ж -> ж
    ['\208\151'] = '\208\183', -- З -> з
    ['\208\152'] = '\208\184', -- И -> и
    ['\208\153'] = '\208\185', -- Й -> й
    ['\208\154'] = '\208\186', -- К -> к
    ['\208\155'] = '\208\187', -- Л -> л
    ['\208\156'] = '\208\188', -- М -> м
    ['\208\157'] = '\208\189', -- Н -> н
    ['\208\158'] = '\208\190', -- О -> о
    ['\208\159'] = '\208\191', -- П -> п
    ['\208\160'] = '\209\128', -- Р -> р
    ['\208\161'] = '\209\129', -- С -> с
    ['\208\162'] = '\209\130', -- Т -> т
    ['\208\163'] = '\209\131', -- У -> у
    ['\208\164'] = '\209\132', -- Ф -> ф
    ['\208\165'] = '\209\133', -- Х -> х
    ['\208\166'] = '\209\134', -- Ц -> ц
    ['\208\167'] = '\209\135', -- Ч -> ч
    ['\208\168'] = '\209\136', -- Ш -> ш
    ['\208\169'] = '\209\137', -- Щ -> щ
    ['\208\170'] = '\209\138', -- Ъ -> ъ
    ['\208\171'] = '\209\139', -- Ы -> ы
    ['\208\172'] = '\209\140', -- Ь -> ь
    ['\208\173'] = '\209\141', -- Э -> э
    ['\208\174'] = '\209\142', -- Ю -> ю
    ['\208\175'] = '\209\143', -- Я -> я
}
local function utf8_lower(str)
    return str:gsub('([\208\209]..)', function(c)
        return utf8_lower_map[c] or c
    end)
end

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

local my_nick_utf8 = "Игрок"

-- Вспомогательная функция для отправки сообщений в чат
local function sendToChat(msg)
    sampAddChatMessage(toCP1251(msg), -1)
end

-- Функция уведомлений (Monet/Arz)
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
                        sendToChat(tag .. "{00FF00}Найдено обновление! Версия: " .. info.version .. " | Используйте /arep → Обновления для установки.")
                    else
                        update_status = "У вас последняя версия."
                        update_found = false
                    end
                else
                    update_status = "Ошибка при проверке"
                end
            else
                update_status = "Не удалось загрузить"
            end
        elseif status == 60 then
            update_status = "Ошибка загрузки"
        end
    end)
end

function updateScript()
    update_status = "Загрузка файла..."
    local scriptPath = thisScript().path
    downloadUrlToFile(SCRIPT_URL, scriptPath, function(id, status, p1, p2)
        if status == 58 then
            sendToChat(tag .. "{00FF00}Скрипт обновлен! Перезагрузка...")
            thisScript():reload()
        elseif status == 60 then
            update_status = "Ошибка загрузки"
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
    local name = nil
    if sampGetCurrentPlayerName then
        name = sampGetCurrentPlayerName()
    elseif samp and samp.get_current_player_name then
        name = samp.get_current_player_name()
    end
    if name and name ~= "" then
        my_nick_utf8 = toUTF8(name)
    else
        my_nick_utf8 = "Игрок"
    end
end

-- Размер окна: 680x420
local ini = inicfg.load({
    main = {
        keyBind = "0x5A", keyBindName = 'Z', otInterval = 10, useMilliseconds = false,
        theme = 0, transparency = 0.8, dialogTimeout = 600, dialogHandlerEnabled = true,
        autoStartEnabled = true, otklflud = false,
    },
    widget = { posX = 400, posY = 400, sizeX = 680, sizeY = 420 }
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

-- Цвета для тем
local colors = {}
local function applyTheme(themeIndex)
    if themeIndex == 0 then
        colors = {
            leftPanelColor = imgui.ImVec4(0.11, 0.12, 0.16, transparency[0]),
            rightPanelColor = imgui.ImVec4(0.15, 0.16, 0.20, transparency[0]),
            childPanelColor = imgui.ImVec4(0.19, 0.20, 0.24, transparency[0]),
            hoverColor = imgui.ImVec4(0.25, 0.45, 0.85, transparency[0]),
            textColor = imgui.ImVec4(1, 1, 1, 1),
        }
    else
        colors = {
            leftPanelColor = imgui.ImVec4(0.05, 0.05, 0.05, transparency[0]),
            rightPanelColor = imgui.ImVec4(0.08, 0.08, 0.08, transparency[0]),
            childPanelColor = imgui.ImVec4(0.12, 0.12, 0.12, transparency[0]),
            hoverColor = imgui.ImVec4(0.25, 0.25, 0.25, transparency[0]),
            textColor = imgui.ImVec4(1, 1, 1, 1),
        }
    end
end
applyTheme(currentTheme[0])

local lastWindowSize = nil

-- Фильтр сообщений "Не флуди"
function filterFloodMessage(text)
    if hideFloodMsg[0] then
        local utf8_text = toUTF8(text)
        local clean = utf8_text:gsub("{%x+}", ""):gsub("#%x+", "")
        clean = clean:gsub("[%p%c]", " ")
        clean = clean:gsub("%s+", " "):match("^%s*(.-)%s*$")
        clean = utf8_lower(clean)
        local banPhrases = {
            utf8_lower("не флуди"),
            utf8_lower("не флуд"),
            utf8_lower("сейчас нет вопросов в репорт")
        }
        for _, phrase in ipairs(banPhrases) do
            if clean:find(phrase, 1, true) then
                return false
            end
        end
    end
    return true
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
    sendToChat(taginf .. '{00FF00}Положение окна сохранено!')
end

function startMovingWindow()
    MoveWidget = true
    showInfoWindow()
    sampToggleCursor(true)
    main_window_state[0] = false
    sendToChat(taginf .. '{FFFF00}Режим перемещения окна активирован. Нажмите "Пробел" для подтверждения.')
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
                sendToChat(tag .. '{FFFFFF}Вы вышли из паузы. Ловля отключена из-за AFK!')
            end
        end
    end
end

function resetIO()
    for i = 0, 511 do imgui.GetIO().KeysDown[i] = false end
    for i = 0, 4 do imgui.GetIO().MouseDown[i] = false end
    imgui.GetIO().KeyCtrl = false; imgui.GetIO().KeyShift = false
    imgui.GetIO().KeyAlt = false; imgui.GetIO().KeySuper = false
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

function imgui.CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX(width/2 - calc.x/2)
    imgui.Text(text)
end

-- ВКЛАДКИ
function drawMainTab()
    imgui.Text("[G] Настройки  /  [M] Флудер")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Flooder", imgui.ImVec2(0,160), true) then
        imgui.PushItemWidth(140)
        if imgui.Checkbox("Использовать миллисекунды", useMilliseconds) then
            ini.main.useMilliseconds = useMilliseconds[0]
            inicfg.save(ini, IniFilename)
        end
        imgui.PopItemWidth()
        imgui.Text("Интервал отправки команды /ot (" .. (useMilliseconds[0] and "в миллисекундах" or "в секундах") .. "):")
        imgui.Text("Текущий интервал: " .. otInterval[0] .. (useMilliseconds[0] and " мс" or " секунд"))
        imgui.PushItemWidth(80)
        imgui.InputText("##otIntervalInput", otIntervalBuffer, ffi.sizeof(otIntervalBuffer))
        imgui.SameLine()
        if imgui.Button("[F] Сохранить интервал", imgui.ImVec2(150, 28)) then
            local newValue = tonumber(ffi.string(otIntervalBuffer))
            if newValue then
                otInterval[0] = newValue
                ini.main.otInterval = newValue
                inicfg.save(ini, IniFilename)
                sendToChat(taginf .. "Интервал сохранён: {32CD32}" .. newValue .. (useMilliseconds[0] and " мс" or " секунд"))
            else
                sendToChat(taginf .. "Некорректное значение. {32CD32}Введите число.")
            end
        end
        imgui.PopItemWidth()
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("InfoFlooder", imgui.ImVec2(0,70), true) then
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
    if imgui.BeginChild("KeyBind", imgui.ImVec2(0,70), true) then
        imgui.Text("Текущая клавиша активации:")
        imgui.SameLine()
        if imgui.Button("" .. keyBindName, imgui.ImVec2(70, 28)) then
            changingKey = true
            show_arz_notify('info', 'RepFlow', 'Нажмите новую клавишу для активации', 2000)
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("DialogOptions", imgui.ImVec2(0,160), true) then
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
    if imgui.BeginChild("AutoStartTimeout", imgui.ImVec2(0,110), true) then
        imgui.Text("Настройка тайм-аута автостарта")
        imgui.PushItemWidth(80)
        imgui.Text("Текущий тайм-аут: " .. dialogTimeout[0] .. " секунд")
        imgui.InputText("", dialogTimeoutBuffer, ffi.sizeof(dialogTimeoutBuffer))
        imgui.SameLine()
        if imgui.Button("[F] Сохранить тайм-аут", imgui.ImVec2(150, 28)) then
            local newValue = tonumber(ffi.string(dialogTimeoutBuffer))
            if newValue and newValue >= 1 and newValue <= 9999 then
                dialogTimeout[0] = newValue
                saveSettings()
                sendToChat(taginf .. "Тайм-аут сохранён: {32CD32}" .. newValue .. " секунд")
            else
                sendToChat(taginf .. "Некорректное значение. {32CD32}Введите от 1 до 9999.")
            end
        end
        imgui.PopItemWidth()
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("WindowPosition", imgui.ImVec2(0,60), true) then
        imgui.Text("Положение окна информации:")
        imgui.SameLine()
        if imgui.Button("Изменить положение", imgui.ImVec2(150, 28)) then
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
    if imgui.BeginChild("Themes", imgui.ImVec2(0,220), true) then
        imgui.Text("Выберите тему оформления:")
        local themeNames = { "Современная (синяя)", "Классическая (чёрная)" }
        for i, name in ipairs(themeNames) do
            if imgui.Button(name, imgui.ImVec2(170,42)) then
                currentTheme[0] = i-1
                applyTheme(currentTheme[0])
                ini.main.theme = currentTheme[0]
                inicfg.save(ini, IniFilename)
                sendToChat(taginf .. "Тема изменена на {32CD32}" .. name)
            end
            if i < #themeNames then imgui.SameLine() end
        end

        local themeIndex = currentTheme[0] or 0
        themeIndex = math.floor(themeIndex)
        if themeIndex < 0 or themeIndex > 1 then themeIndex = 0 end

        imgui.Text("Текущая тема: " .. themeNames[themeIndex+1])

        imgui.Separator()
        imgui.Text("Прозрачность фона:")
        if imgui.SliderFloat("##transparency", transparency, 0.3, 1.0, "%.2f") then
            applyTheme(currentTheme[0])
            ini.main.transparency = transparency[0]
            inicfg.save(ini, IniFilename)
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawUpdatesTab()
    imgui.Text("Облачное обновление")
    imgui.Separator()
    imgui.Text("Текущая версия: " .. scriptver)
    imgui.Text("Статус: " .. (update_status or "неизвестно"))
    if imgui.Button("Проверить заново", imgui.ImVec2(170, 30)) then checkUpdates() end
    if update_found then
        imgui.SameLine()
        if imgui.Button("Установить сейчас", imgui.ImVec2(170, 30)) then updateScript() end
    end
end

function drawInfoTab(panelColor)
    panelColor = panelColor or colors.childPanelColor
    imgui.Text("[I] RepFlow  /  [i] Информация")
    imgui.Separator()

    imgui.PushStyleColor(imgui.Col.ChildBg, panelColor)
    if imgui.BeginChild("Author", imgui.ImVec2(0,150), true) then
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
    if imgui.BeginChild("Info3", imgui.ImVec2(0,100), true) then
        imgui.CenterText("Благодарности:")
        imgui.Text("Тестеры: Arman_Carukjan, Sora_Deathmarried")
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

-- Основной цикл
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand("arep", cmd_arep)

    getPlayerName()
    sendToChat(tag .. 'Скрипт {00FF00}загружен.{FFFFFF} Активация меню: {00FF00}/arep')
    show_arz_notify('success', 'RepFlow', 'Скрипт загружен. Активация: /arep', 3000)

    checkUpdates()

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
                local winW, winH = 280, active and 130 or 290
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

function sampev.onServerMessage(color, text)
    if text:find('%[(%W+)%] от (%w+_%w+)%[(%d+)%]:') then
        if active then sampSendChat('/ot') end
    end
    return filterFloodMessage(text)
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 1334 then
        lastDialogTime = os.clock()
        reportAnsweredCount = reportAnsweredCount + 1
        sendToChat(tag .. '{00FF00}Репорт принят! Отвечено репорта: ' .. reportAnsweredCount)
        if active then
            active = false
            show_arz_notify('info', 'RepFlow', 'Ловля отключена из-за окна репорта!', 3000)
        end
    end
end

function cmd_arep(arg)
    main_window_state[0] = not main_window_state[0]
    imgui.Process = main_window_state[0]
end

function showInfoWindow() info_window_state[0] = true end
function showInfoWindowOff() info_window_state[0] = false end

-- Настройка imgui
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.GetIO().Fonts:AddFontDefault()
    decor()
end)

function decor()
    imgui.SwitchContext()
    local style = imgui.GetStyle()

    style.WindowPadding = imgui.ImVec2(18, 18)
    style.WindowRounding = 16.0
    style.WindowBorderSize = 0.0

    style.ChildRounding = 14.0
    style.ChildBorderSize = 0.0

    style.FramePadding = imgui.ImVec2(12, 10)
    style.FrameRounding = 10.0
    style.FrameBorderSize = 0.0

    style.ItemSpacing = imgui.ImVec2(14, 12)
    style.ItemInnerSpacing = imgui.ImVec2(12, 10)

    style.IndentSpacing = 22.0
    style.ScrollbarSize = 14.0
    style.ScrollbarRounding = 10.0
    style.GrabMinSize = 12.0
    style.GrabRounding = 8.0

    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)

    style.Colors = {
        [imgui.Col.Text] = imgui.ImVec4(1, 1, 1, 1),
        [imgui.Col.TextDisabled] = imgui.ImVec4(0.5, 0.5, 0.5, 1),
        [imgui.Col.WindowBg] = imgui.ImVec4(0.15, 0.16, 0.20, 1),
        [imgui.Col.ChildBg] = imgui.ImVec4(0.11, 0.12, 0.16, 1),
        [imgui.Col.PopupBg] = imgui.ImVec4(0.08, 0.08, 0.08, 0.94),
        [imgui.Col.Border] = imgui.ImVec4(0.3, 0.3, 0.3, 0.5),
        [imgui.Col.BorderShadow] = imgui.ImVec4(0, 0, 0, 0),
        [imgui.Col.FrameBg] = imgui.ImVec4(0.2, 0.21, 0.25, 1),
        [imgui.Col.FrameBgHovered] = imgui.ImVec4(0.25, 0.45, 0.85, 0.6),
        [imgui.Col.FrameBgActive] = imgui.ImVec4(0.25, 0.45, 0.85, 0.8),
        [imgui.Col.TitleBg] = imgui.ImVec4(0.11, 0.12, 0.16, 1),
        [imgui.Col.TitleBgActive] = imgui.ImVec4(0.25, 0.45, 0.85, 0.8),
        [imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.15, 0.15, 0.15, 1),
        [imgui.Col.MenuBarBg] = imgui.ImVec4(0.11, 0.12, 0.16, 1),
        [imgui.Col.ScrollbarBg] = imgui.ImVec4(0.05, 0.05, 0.05, 1),
        [imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.25, 0.45, 0.85, 0.5),
        [imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.25, 0.45, 0.85, 0.7),
        [imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.25, 0.45, 0.85, 0.9),
        [imgui.Col.CheckMark] = imgui.ImVec4(0.25, 0.45, 0.85, 1),
        [imgui.Col.SliderGrab] = imgui.ImVec4(0.25, 0.45, 0.85, 0.7),
        [imgui.Col.SliderGrabActive] = imgui.ImVec4(0.25, 0.45, 0.85, 1),
        [imgui.Col.Button] = imgui.ImVec4(0.2, 0.21, 0.25, 1),
        [imgui.Col.ButtonHovered] = imgui.ImVec4(0.25, 0.45, 0.85, 0.6),
        [imgui.Col.ButtonActive] = imgui.ImVec4(0.25, 0.45, 0.85, 0.8),
        [imgui.Col.Header] = imgui.ImVec4(0.2, 0.21, 0.25, 1),
        [imgui.Col.HeaderHovered] = imgui.ImVec4(0.25, 0.45, 0.85, 0.6),
        [imgui.Col.HeaderActive] = imgui.ImVec4(0.25, 0.45, 0.85, 0.8),
        [imgui.Col.Separator] = imgui.ImVec4(0.3, 0.3, 0.3, 1),
        [imgui.Col.SeparatorHovered] = imgui.ImVec4(0.25, 0.45, 0.85, 0.6),
        [imgui.Col.SeparatorActive] = imgui.ImVec4(0.25, 0.45, 0.85, 0.8),
        [imgui.Col.ResizeGrip] = imgui.ImVec4(0.25, 0.45, 0.85, 0.2),
        [imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.25, 0.45, 0.85, 0.6),
        [imgui.Col.ResizeGripActive] = imgui.ImVec4(0.25, 0.45, 0.85, 0.8),
        [imgui.Col.Tab] = imgui.ImVec4(0.11, 0.12, 0.16, 1),
        [imgui.Col.TabHovered] = imgui.ImVec4(0.25, 0.45, 0.85, 0.6),
        [imgui.Col.TabActive] = imgui.ImVec4(0.25, 0.45, 0.85, 0.8),
        [imgui.Col.TabUnfocused] = imgui.ImVec4(0.08, 0.08, 0.08, 1),
        [imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.15, 0.15, 0.15, 1),
        [imgui.Col.PlotLines] = imgui.ImVec4(0.6, 0.6, 0.6, 1),
        [imgui.Col.PlotLinesHovered] = imgui.ImVec4(1, 1, 1, 1),
        [imgui.Col.PlotHistogram] = imgui.ImVec4(0.25, 0.45, 0.85, 1),
        [imgui.Col.PlotHistogramHovered] = imgui.ImVec4(0.35, 0.55, 0.95, 1),
        [imgui.Col.TextSelectedBg] = imgui.ImVec4(0.25, 0.45, 0.85, 0.35),
        [imgui.Col.DragDropTarget] = imgui.ImVec4(1, 1, 0, 0.9),
        [imgui.Col.NavHighlight] = imgui.ImVec4(1, 1, 1, 1),
        [imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1, 1, 1, 1),
        [imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.8, 0.8, 0.8, 0.2),
        [imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.2, 0.2, 0.2, 0.35),
    }
end

imgui.OnFrame(function() return main_window_state[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(ini.widget.sizeX, ini.widget.sizeY), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5,0.5))
    imgui.PushStyleColor(imgui.Col.WindowBg, colors.rightPanelColor)

    if imgui.Begin("[R] RepFlow | Premium", main_window_state, imgui.WindowFlags.NoCollapse) then

        imgui.PushStyleColor(imgui.Col.ChildBg, colors.leftPanelColor)
        if imgui.BeginChild("left_panel", imgui.ImVec2(150,-1), false) then
            local tabNames = { "Флудер", "Настройки", "Информация", "ChangeLog", "Темы", "Обновления" }
            for i, name in ipairs(tabNames) do
                if i-1 == active_tab[0] then
                    imgui.PushStyleColor(imgui.Col.Button, colors.hoverColor)
                else
                    imgui.PushStyleColor(imgui.Col.Button, colors.leftPanelColor)
                end
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.hoverColor)
                imgui.PushStyleColor(imgui.Col.ButtonActive, colors.hoverColor)

                if imgui.Button(name, imgui.ImVec2(140,42)) then
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

-- Окно информации (увеличенное, с переносом текста)
imgui.OnFrame(function() return info_window_state[0] end, function(self)
    self.HideCursor = true
    local windowWidth = 280
    local windowHeight = active and 140 or 300
    imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(ini.widget.posX, ini.widget.posY), imgui.Cond.Always)

    imgui.Begin("[i] Информация ", info_window_state, 
                imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoInputs)

    imgui.PushTextWrapPos(260)
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
    imgui.PopTextWrapPos()

    imgui.End()
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
            sendToChat(string.format(tag .. '{FFFFFF}Новая клавиша активации ловли репорта: {00FF00}%s', keyBindName))
            return false
        end
    end
end
