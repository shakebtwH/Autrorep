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
local scriptver = "4.25 | Premium"

local scriptStartTime = os.clock()

local changelogEntries = {
    { version = "4.25 | Premium", description = "- Исправлена работа фильтра 'Не флуди' (удаляются цветовые коды перед поиском)." },
    { version = "4.24 | Premium", description = "- Исправлена ошибка 'encoding.CP1251 is nil'." },
    { version = "4.23 | Premium", description = "- Исправлены кракозябры в чате." },
    { version = "4.22 | Premium", description = "- Возвращена библиотека encoding." },
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

local my_nick_utf8 = "Игрок"

-- Функция отправки в чат
local function sendToChat(msg)
    sampAddChatMessage(toCP1251(msg), -1)
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
                        sendToChat(tag .. "{00FF00}Найдено обновление! Версия: " .. info.version)
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
    sendToChat(tag .. 'Скрипт {00FF00}загружен.{FFFFFF} Активация меню: {00FF00}/arep')
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
    sendToChat(taginf .. '{FFFF00}Режим перемещения окна активирован. Нажмите "Пробел" для подтверждения.')
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

-- Фильтр сообщений (удаляем цветовые коды)
function filterFloodMessage(text)
    if hideFloodMsg[0] then
        local clean = text:gsub("{%x+}", "")  -- удаляем {RRGGBB}
        if clean:find("Сейчас нет вопросов в репорт!", 1, true) or clean:find("Не флуди!", 1, true) then
            return false
        end
    end
    return true
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
    sendToChat(taginf .. '{00FF00}Положение окна сохранено!')
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

-- Остальные функции вкладок (drawMainTab, drawSettingsTab и т.д.) остаются без изменений
-- (они были в предыдущих версиях и здесь не повторяются для краткости, но в полном коде они присутствуют)

-- ... (полный код с вкладками из предыдущего сообщения, они не менялись)
