require 'lib.moonloader'
local imgui = require 'mimgui'
local sampev = require 'lib.samp.events'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local ffi = require 'ffi'

-- ИСПРАВЛЕНИЕ ОШИБКИ u8: Инициализируем кодировку до её использования
encoding.default = 'CP1251'
u8 = encoding.UTF8

-- === НАСТРОЙКИ ОБНОВЛЕНИЯ (ВСТАВЬ СВОИ RAW ССЫЛКИ) ===
local UPDATE_URL = "https://raw.githubusercontent.com/shakebtwH/Autrorep/main/update.json"
local SCRIPT_URL = "https://raw.githubusercontent.com/shakebtwH/Autrorep/main/!repflow.lua"
local update_found = false
local update_status = u8"Проверка не проводилась"
-- ====================================================

if not samp then samp = {} end

local IniFilename = 'RepFlowCFG.ini'
local new = imgui.new
local scriptver = "4.13 | Premium"

local scriptStartTime = os.clock()

local changelogEntries = {
    { version = "4.12 | Premium", description = u8"- Добавлена функция автообновления через Github. теперь все обновления будут автоматические." },
    { version = "4.11 | Premium", description = u8"- Убраны строки 'Время работы' и 'Ваш ник' во вкладке 'Информация'." },
    { version = "4.10 | Premium", description = u8"- Убрана полоса прокрутки в окне информации, увеличен размер окна." },
    { version = "4.9 | Premium", description = u8"- В окне информации при включённой ловле теперь показывается только статус, время работы текущей сессии и счётчик отвеченных репортов." },
    { version = "4.8 | Premium", description = u8"- Исправлена ошибка с корутинами (добавлены защитные проверки)." },
    { version = "4.7 | Premium", description = u8"- Финальная стабильная версия без фона и лишних зависимостей." },
    { version = "4.6 | Premium", description = u8"- Добавлена возможность установить своё изображение на задний фон главного окна." },
    { version = "4.5 | Premium", description = u8"- Исправлен краш при открытии меню (убрана загрузка внешнего шрифта)." },
    { version = "4.4 | Premium", description = u8"- Добавлена поддержка локального шрифта с эмодзи (NotoColorEmoji.ttf)." },
    { version = "4.3 | Premium", description = u8"- Добавлена поддержка эмодзи через системные шрифты." },
    { version = "4.2 | Premium", description = u8"- Удалена вкладка 'Статистика', скрипт приведён к минималистичному виду." },
    { version = "4.1 | Premium", description = u8"- Удалены статические темы, оставлены только 'Прозрачная' и 'Кастомная'.\n- Исправлена ошибка с PlotHistogram." },
    { version = "4.0 | Premium", description = u8"- Удалено приветствие.\n- Добавлена вкладка 'Статистика'." },
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
local my_nick_utf8 = u8"Игрок"

-- ФУНКЦИИ ОБНОВЛЕНИЯ
function checkUpdates()
    update_status = u8"Проверка наличия обновлений..."
    local path = getWorkingDirectory() .. '\\repflow_upd.json'
    downloadUrlToFile(UPDATE_URL, path, function(id, status, p1, p2)
        if status == 58 then -- STATUS_ENDDOWNLOADDATA
            local f = io.open(path, 'r')
            if f then
                local content = f:read('*a')
                f:close()
                os.remove(path)
                local ok, info = pcall(decodeJson, content)
                if ok and info and info.version then
                    if info.version ~= scriptver then
                        update_status = u8("Доступна версия: " .. info.version)
                        update_found = true
                        sampAddChatMessage(tag .. "{00FF00}Найдено обновление! Версия: " .. info.version, -1)
                    else
                        update_status = u8"У вас последняя версия."
                        update_found = false
                    end
                end
            end
        end
    end)
end

function updateScript()
    update_status = u8"Загрузка файла..."
    local scriptPath = thisScript().path
    downloadUrlToFile(SCRIPT_URL, scriptPath, function(id, status, p1, p2)
        if status == 58 then
            sampAddChatMessage(tag .. "{00FF00}Скрипт обновлен! Перезагрузка...", -1)
            thisScript():reload()
        end
    end)
end

-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
local function emoji(name) return "" end

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function getPlayerName()
    local name = samp.get_current_player_name and samp.get_current_player_name()
    if name and name ~= "" then my_nick_utf8 = u8(name) end
end

-- КОНФИГ И ЦВЕТА
local ini = inicfg.load({
    main = {
        keyBind = "0x5A", keyBindName = 'Z', otInterval = 10, useMilliseconds = false,
        theme = 0, transparency = 0.8, dialogTimeout = 600, dialogHandlerEnabled = true,
        autoStartEnabled = true, otklflud = false,
        customLeftR = 27/255, customLeftG = 20/255, customLeftB = 30/255, customLeftA = 1,
        customRightR = 24/255, customRightG = 18/255, customRightB = 28/255, customRightA = 1,
        customChildR = 18/255, customChildG = 13/255, customChildB = 22/255, customChildA = 1,
        customHoverR = 63/255, customHoverG = 59/255, customHoverB = 66/255, customHoverA = 1,
    },
    widget = { posX = 400, posY = 400, sizeX = 800, sizeY = 500 }
}, IniFilename)

local MoveWidget = false
keyBind = tonumber(ini.main.keyBind)
keyBindName = ini.main.keyBindName
otInterval[0] = tonumber(ini.main.otInterval)
useMilliseconds[0] = ini.main.useMilliseconds
dialogTimeout[0] = tonumber(ini.main.dialogTimeout)
dialogHandlerEnabled[0] = ini.main.dialogHandlerEnabled
autoStartEnabled[0] = ini.main.autoStartEnabled
hideFloodMsg[0] = ini.main.otklflud
local transparency = new.float(ini.main.transparency or 0.8)
local currentTheme = new.int(tonumber(ini.main.theme) or 0)

local customLeft = new.float[4](ini.main.customLeftR, ini.main.customLeftG, ini.main.customLeftB, ini.main.customLeftA)
local customRight = new.float[4](ini.main.customRightR, ini.main.customRightG, ini.main.customRightB, ini.main.customRightA)
local customChild = new.float[4](ini.main.customChildR, ini.main.customChildG, ini.main.customChildB, ini.main.customChildA)
local customHover = new.float[4](ini.main.customHoverR, ini.main.customHoverG, ini.main.customHoverB, ini.main.customHoverA)

local colors = {}
function applyTheme(themeIndex)
    if themeIndex == 0 then
        colors = {
            leftPanelColor = imgui.ImVec4(27/255,20/255,30/255,transparency[0]),
            rightPanelColor = imgui.ImVec4(24/255,18/255,28/255,transparency[0]),
            childPanelColor = imgui.ImVec4(18/255,13/255,22/255,transparency[0]),
            hoverColor = imgui.ImVec4(63/255,59/255,66/255,transparency[0]),
        }
    else
        colors = {
            leftPanelColor = imgui.ImVec4(customLeft[0], customLeft[1], customLeft[2], customLeft[3]),
            rightPanelColor = imgui.ImVec4(customRight[0], customRight[1], customRight[2], customRight[3]),
            childPanelColor = imgui.ImVec4(customChild[0], customChild[1], customChild[2], customChild[3]),
            hoverColor = imgui.ImVec4(customHover[0], customHover[1], customHover[2], customHover[3]),
        }
    end
end
applyTheme(currentTheme[0])

-- ОСНОВНАЯ ЛОГИКА
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    sampRegisterChatCommand("arep", function() main_window_state[0] = not main_window_state[0] end)
    getPlayerName()
    checkUpdates() -- Проверка обновлений при запуске

    sampAddChatMessage(tag .. 'Скрипт {00FF00}загружен.{FFFFFF} Меню: {00FF00}/arep', -1)

    while true do
        wait(0)
        
        if isPauseMenuActive() then
            if not gameMinimized then
                wasActiveBeforePause = active
                active = false
                gameMinimized = true
            end
        elseif gameMinimized then
            gameMinimized = false
        end

        if autoStartEnabled[0] and not active and not gameMinimized then
            if (os.clock() - lastDialogTime) > dialogTimeout[0] then
                active = true
            end
        end

        if main_window_state[0] then
            imgui.Process = true
            sampToggleCursor(true)
        else
            imgui.Process = false
        end

        if not changingKey and isKeyJustPressed(keyBind) and not sampIsChatInputActive() and not sampIsDialogActive() then
            active = not active
            show_arz_notify('info', 'RepFlow', active and 'Ловля ВКЛ' or 'Ловля ВЫКЛ', 2000)
        end

        if active then
            local currentTime = os.clock() * 1000
            local interval = useMilliseconds[0] and otInterval[0] or otInterval[0] * 1000
            if currentTime - lastOtTime >= interval then
                sampSendChat('/ot')
                lastOtTime = currentTime
            end
            info_window_state[0] = true
        else
            info_window_state[0] = false
        end
    end
end

-- ОБРАБОТКА СОБЫТИЙ
function sampev.onServerMessage(color, text)
    if text:find('%[(%W+)%] от (%w+_%w+)%[(%d+)%]:') then
        if active then sampSendChat('/ot') end
    end
    if hideFloodMsg[0] and (text:find("Сейчас нет вопросов") or text:find("Не флуди!")) then return false end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 1334 then
        lastDialogTime = os.clock()
        reportAnsweredCount = reportAnsweredCount + 1
        if active then active = false end
    end
end

-- ИНТЕРФЕЙС
function drawMainTab()
    imgui.Text(u8"Настройки флудера")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Flooder", imgui.ImVec2(0,140), true) then
        imgui.Checkbox(u8'Использовать миллисекунды', useMilliseconds)
        imgui.Text(u8'Интервал: ' .. otInterval[0])
        imgui.InputText(u8'##otInt', otIntervalBuffer, 5)
        if imgui.Button(u8"Сохранить") then
            local v = tonumber(ffi.string(otIntervalBuffer))
            if v then otInterval[0] = v; ini.main.otInterval = v; inicfg.save(ini, IniFilename) end
        end
    end
    imgui.EndChild(); imgui.PopStyleColor()
end

function drawSettingsTab()
    imgui.Text(u8"Основные настройки")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Settings", imgui.ImVec2(0,220), true) then
        imgui.Text(u8'Клавиша: ' .. keyBindName)
        if imgui.Button(u8'Сменить клавишу') then changingKey = true end
        imgui.Checkbox(u8'Обработка диалогов', dialogHandlerEnabled)
        imgui.Checkbox(u8'Автостарт ловли', autoStartEnabled)
        imgui.Checkbox(u8'Скрыть "Не флуди"', hideFloodMsg)
        if imgui.Button(u8"Сменить положение инфо-окна") then
            MoveWidget = true
            sampToggleCursor(true)
            main_window_state[0] = false
        end
    end
    imgui.EndChild(); imgui.PopStyleColor()
end

function drawUpdatesTab()
    imgui.Text(u8"Облачное обновление")
    imgui.Separator()
    imgui.Text(u8"Текущая версия: " .. scriptver)
    imgui.Text(u8"Статус: " .. update_status)
    if imgui.Button(u8"Проверить заново", imgui.ImVec2(160, 30)) then checkUpdates() end
    if update_found then
        imgui.SameLine()
        if imgui.Button(u8"Установить сейчас", imgui.ImVec2(160, 30)) then updateScript() end
    end
end

function drawInfoTab()
    imgui.Text(u8"Информация")
    imgui.Separator()
    imgui.Text(u8"Автор: Balenciaga_Collins")
    imgui.Text(u8"Версия: " .. scriptver)
    if imgui.Button(u8"Telegram") then os.execute('explorer https://t.me/Repflowarizona') end
end

function drawChangeLogTab()
    imgui.Text(u8"История обновлений")
    imgui.Separator()
    for _, entry in ipairs(changelogEntries) do
        if imgui.CollapsingHeader(u8("Версия ") .. entry.version) then
            imgui.TextWrapped(entry.description)
        end
    end
end

function drawThemesTab()
    imgui.Text(u8"Настройка внешнего вида")
    imgui.Separator()
    if imgui.Button(u8"Прозрачная") then currentTheme[0] = 0; applyTheme(0); ini.main.theme = 0; inicfg.save(ini, IniFilename) end
    imgui.SameLine()
    if imgui.Button(u8"Кастомная") then currentTheme[0] = 1; applyTheme(1); ini.main.theme = 1; inicfg.save(ini, IniFilename) end
    if currentTheme[0] == 0 then
        imgui.SliderFloat(u8"Прозрачность", transparency, 0.3, 1.0)
        if imgui.IsItemDeactivated() then applyTheme(0); ini.main.transparency = transparency[0]; inicfg.save(ini, IniFilename) end
    end
end

-- ГЛАВНЫЙ РЕНДЕР
imgui.OnFrame(function() return main_window_state[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(ini.widget.sizeX, ini.widget.sizeY), imgui.Cond.FirstUseEver)
    imgui.PushStyleColor(imgui.Col.WindowBg, colors.rightPanelColor)
    if imgui.Begin(u8'RepFlow | Premium', main_window_state, imgui.WindowFlags.NoCollapse) then
        imgui.PushStyleColor(imgui.Col.ChildBg, colors.leftPanelColor)
        if imgui.BeginChild("left", imgui.ImVec2(130,-1), true) then
            local tabs = {u8"Флудер", u8"Настройки", u8"Инфо", u8"Лог", u8"Темы", u8"Обновы"}
            for i, name in ipairs(tabs) do
                if imgui.Button(name, imgui.ImVec2(115, 35)) then active_tab[0] = i-1 end
            end
        end
        imgui.EndChild(); imgui.PopStyleColor(); imgui.SameLine()
        
        if imgui.BeginChild("right", imgui.ImVec2(-1,-1), false) then
            if active_tab[0] == 0 then drawMainTab()
            elseif active_tab[0] == 1 then drawSettingsTab()
            elseif active_tab[0] == 2 then drawInfoTab()
            elseif active_tab[0] == 3 then drawChangeLogTab()
            elseif active_tab[0] == 4 then drawThemesTab()
            elseif active_tab[0] == 5 then drawUpdatesTab() end
        end
        imgui.EndChild()
    end
    imgui.End(); imgui.PopStyleColor()
end)

-- ОКНО ВИДЖЕТА
imgui.OnFrame(function() return info_window_state[0] or MoveWidget end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(240, active and 100 or 180), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(ini.widget.posX, ini.widget.posY), imgui.Cond.Always)
    
    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize
    if not MoveWidget then flags = flags + imgui.WindowFlags.NoInputs end
    
    imgui.Begin("InfoPanel", nil, flags)
    imgui.Text(u8"Статус: " .. (active and u8"ВКЛ" or u8"ВЫКЛ"))
    imgui.Text(u8"Репортов: " .. reportAnsweredCount)
    if not active then
        imgui.Text(u8"Ник: " .. my_nick_utf8)
        imgui.Text(u8"Сессия: " .. formatTime(os.clock() - scriptStartTime))
        if MoveWidget then
            imgui.Separator()
            imgui.Text(u8"ПЕРЕМЕЩАЙТЕ МЫШКОЙ")
            if imgui.Button(u8"Сохранить позицию", imgui.ImVec2(-1, 25)) then
                MoveWidget = false
                sampToggleCursor(false)
                inicfg.save(ini, IniFilename)
            end
        end
    end
    
    if MoveWidget and imgui.IsWindowHovered() and imgui.IsMouseDragging(0) then
        local delta = imgui.GetIO().MouseDelta
        ini.widget.posX = ini.widget.posX + delta.x
        ini.widget.posY = ini.widget.posY + delta.y
    end
    imgui.End()
end)

-- УВЕДОМЛЕНИЯ
function show_arz_notify(type, title, text, time)
    local str = ('window.executeEvent(\'event.notify.initialize\', \'["%s", "%s", "%s", "%s"]\');'):format(type,title,text,time)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs,17)
    raknetBitStreamWriteInt32(bs,0)
    raknetBitStreamWriteInt32(bs,#str)
    raknetBitStreamWriteString(bs,str)
    raknetEmulPacketReceiveBitStream(220,bs)
    raknetDeleteBitStream(bs)
end

function onWindowMessage(msg, wparam, lparam)
    if changingKey and (msg == 0x100 or msg == 0x101) then
        keyBind = wparam
        keyBindName = vkeys.id_to_name(keyBind)
        ini.main.keyBind = tostring(keyBind); ini.main.keyBindName = keyBindName
        inicfg.save(ini, IniFilename); changingKey = false
        return false
    end
end

