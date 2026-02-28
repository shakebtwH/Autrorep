require 'lib.moonloader'
local imgui = require 'mimgui'
local sampev = require 'lib.samp.events'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local ffi = require 'ffi'

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

local IniFilename = 'RepFlowCFG.ini'   -- сохранение совместимости
local new = imgui.new
local scriptver = "1.0 | Premium"

local changelogEntries = {
    { version = "1.0", description = "Полностью переработан: чистый флудер /ot, добавлена анимация появления окон, вкладка обновлений, сохранены автообновление и смена тем." },
    { version = "0.9", description = "Предыдущая версия с репорт-системой." },
}

-- Нижний регистр для UTF‑8 (для фильтра)
local utf8_lower_map = {
    ['\208\144'] = '\208\176', ['\208\145'] = '\208\177', ['\208\146'] = '\208\178',
    ['\208\147'] = '\208\179', ['\208\148'] = '\208\180', ['\208\149'] = '\208\181',
    ['\208\129'] = '\209\145', ['\208\150'] = '\208\182', ['\208\151'] = '\208\183',
    ['\208\152'] = '\208\184', ['\208\153'] = '\208\185', ['\208\154'] = '\208\186',
    ['\208\155'] = '\208\187', ['\208\156'] = '\208\188', ['\208\157'] = '\208\189',
    ['\208\158'] = '\208\190', ['\208\159'] = '\208\191', ['\208\160'] = '\209\128',
    ['\208\161'] = '\209\129', ['\208\162'] = '\209\130', ['\208\163'] = '\209\131',
    ['\208\164'] = '\209\132', ['\208\165'] = '\209\133', ['\208\166'] = '\209\134',
    ['\208\167'] = '\209\135', ['\208\168'] = '\209\136', ['\208\169'] = '\209\137',
    ['\208\170'] = '\209\138', ['\208\171'] = '\209\139', ['\208\172'] = '\209\140',
    ['\208\173'] = '\209\141', ['\208\174'] = '\209\142', ['\208\175'] = '\209\143',
}
local function utf8_lower(str)
    return str:gsub('([\208\209]..)', function(c) return utf8_lower_map[c] or c end)
end

-- Переменные флудера
local keyBind = 0x5A
local keyBindName = 'Z'
local lastOtTime = 0
local active = false
local otInterval = new.int(1000)          -- миллисекунды
local otIntervalBuffer = imgui.new.char[5](tostring(otInterval[0]))
local startTime = os.clock()

local main_window_state = new.bool(false)
local active_tab = new.int(0)
local sw, sh = getScreenResolution()

local hideFloodMsg = new.bool(true)
local autoStartEnabled = new.bool(false)
local afkExitTime = 0
local afkCooldown = 30

local my_nick_utf8 = "Игрок"

local changingKey = false

-- Загрузка INI
local ini = inicfg.load({
    main = {
        keyBind = "0x5A", keyBindName = 'Z', otInterval = 1000,
        theme = 0, transparency = 0.9, autoStartEnabled = false, otklflud = true,
    },
    window = { posX = 400, posY = 400, sizeX = 500, sizeY = 350 }
}, IniFilename)

keyBind = tonumber(ini.main.keyBind)
keyBindName = ini.main.keyBindName
otInterval[0] = tonumber(ini.main.otInterval)
autoStartEnabled[0] = ini.main.autoStartEnabled
hideFloodMsg[0] = ini.main.otklflud

local themeValue = tonumber(ini.main.theme) or 0
local currentTheme = new.int(themeValue)
local transparency = new.float(ini.main.transparency or 0.9)

-- Цвета для тем
local colors = {}
local function applyTheme(themeIndex)
    if themeIndex == 0 then
        colors = {
            leftPanelColor = imgui.ImVec4(0.11, 0.12, 0.16, transparency[0]),
            rightPanelColor = imgui.ImVec4(0.15, 0.16, 0.20, transparency[0]),
            childPanelColor = imgui.ImVec4(0.19, 0.20, 0.24, transparency[0]),
            hoverColor = imgui.ImVec4(0.25, 0.45, 0.85, transparency[0]),
            textColor = imgui.ImVec4(1,1,1,1),
        }
    else
        colors = {
            leftPanelColor = imgui.ImVec4(0.05,0.05,0.05, transparency[0]),
            rightPanelColor = imgui.ImVec4(0.08,0.08,0.08, transparency[0]),
            childPanelColor = imgui.ImVec4(0.12,0.12,0.12, transparency[0]),
            hoverColor = imgui.ImVec4(0.25,0.25,0.25, transparency[0]),
            textColor = imgui.ImVec4(1,1,1,1),
        }
    end
end
applyTheme(currentTheme[0])

local function sendToChat(msg) sampAddChatMessage(toCP1251(msg), -1) end

-- Автообновление
function checkUpdates()
    update_status = "Проверка..."
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
                        update_status = "Доступна: " .. info.version
                        update_found = true
                        sendToChat("{1E90FF} [!repflow]: {00FF00}Найдено обновление! Версия " .. info.version)
                    else
                        update_status = "У вас последняя версия."
                        update_found = false
                    end
                else update_status = "Ошибка" end
            else update_status = "Не удалось загрузить" end
        elseif status == 60 then update_status = "Ошибка загрузки" end
    end)
end

function updateScript()
    update_status = "Загрузка..."
    local scriptPath = thisScript().path
    downloadUrlToFile(SCRIPT_URL, scriptPath, function(id, status, p1, p2)
        if status == 58 then
            sendToChat("{1E90FF} [!repflow]: {00FF00}Скрипт обновлен! Перезагрузка...")
            thisScript():reload()
        elseif status == 60 then update_status = "Ошибка загрузки" end
    end)
end

-- Фильтр "Не флуди"
function filterFloodMessage(text)
    if hideFloodMsg[0] then
        local utf8_text = toUTF8(text)
        local clean = utf8_text:gsub("{%x+}", ""):gsub("#%x+", "")
        clean = clean:gsub("[%p%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
        clean = utf8_lower(clean)
        local ban = { utf8_lower("не флуди"), utf8_lower("не флуд") }
        for _, phrase in ipairs(ban) do
            if clean:find(phrase, 1, true) then return false end
        end
    end
    return true
end

function onToggleActive()
    active = not active
    if active then startTime = os.clock() else afkExitTime = os.clock() end
    sendToChat("{1E90FF} [!repflow]: {FFFFFF}Флудер " .. (active and "{00FF00}включен" or "{FF0000}выключен"))
end

function saveSettings()
    ini.main.otInterval = otInterval[0]
    ini.main.autoStartEnabled = autoStartEnabled[0]
    ini.main.otklflud = hideFloodMsg[0]
    ini.main.keyBind = string.format("0x%X", keyBind)
    ini.main.keyBindName = keyBindName
    ini.main.theme = currentTheme[0]
    ini.main.transparency = transparency[0]
    inicfg.save(ini, IniFilename)
end

-- Вкладки
function drawMainTab()
    imgui.Text("[G] Настройки флудера")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Flooder", imgui.ImVec2(0,150), true) then
        imgui.Text("Статус: " .. (active and "{00FF00}Активен" or "{FF0000}Неактивен"))
        if imgui.Button(active and "Выключить" or "Включить", imgui.ImVec2(120,30)) then onToggleActive() end
        imgui.Dummy(imgui.ImVec2(0,5))
        imgui.Text("Интервал (мс):")
        imgui.PushItemWidth(100)
        imgui.InputText("##interval", otIntervalBuffer, ffi.sizeof(otIntervalBuffer))
        imgui.SameLine()
        if imgui.Button("Сохранить", imgui.ImVec2(100,28)) then
            local newVal = tonumber(ffi.string(otIntervalBuffer))
            if newVal and newVal > 0 then
                otInterval[0] = newVal
                saveSettings()
                sendToChat("{1E90FF} [!repflow]: {00FF00}Интервал сохранён: " .. newVal .. " мс")
            else sendToChat("{1E90FF} [!repflow]: {FF0000}Некорректное значение") end
        end
        imgui.PopItemWidth()
        imgui.Text("Текущий: " .. otInterval[0] .. " мс")
        imgui.Dummy(imgui.ImVec2(0,5))
        imgui.Text("Время работы: " .. string.format("%.1f сек", os.clock() - startTime))
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawSettingsTab()
    imgui.Text("[S] Основные настройки")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Settings", imgui.ImVec2(0,200), true) then
        imgui.Text("Клавиша активации:")
        imgui.SameLine()
        if imgui.Button(keyBindName, imgui.ImVec2(50,25)) then
            changingKey = true
            sendToChat("{1E90FF} [!repflow]: Нажмите новую клавишу...")
        end
        imgui.Checkbox("Автостарт по бездействию", autoStartEnabled)
        imgui.Checkbox("Скрывать 'Не флуди'", hideFloodMsg)
        imgui.Dummy(imgui.ImVec2(0,5))
        imgui.Text("Тема:")
        if imgui.Button("Светлая", imgui.ImVec2(80,25)) then currentTheme[0] = 0; applyTheme(0); saveSettings() end
        imgui.SameLine()
        if imgui.Button("Тёмная", imgui.ImVec2(80,25)) then currentTheme[0] = 1; applyTheme(1); saveSettings() end
        imgui.SliderFloat("Прозрачность", transparency, 0.3, 1.0, "%.2f")
        if imgui.IsItemDeactivatedAfterEdit() then applyTheme(currentTheme[0]); saveSettings() end
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawInfoTab()
    imgui.Text("[I] Информация")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Info", imgui.ImVec2(0,150), true) then
        imgui.Text("Автор: Ваше имя")
        imgui.Text("Версия: " .. scriptver)
        imgui.Text("Telegram: @yourchannel")
        imgui.Dummy(imgui.ImVec2(0,5))
        imgui.Text("Обновления:")
        imgui.Text(update_status)
        if imgui.Button("Проверить", imgui.ImVec2(120,25)) then checkUpdates() end
        if update_found then
            imgui.SameLine()
            if imgui.Button("Установить", imgui.ImVec2(100,25)) then updateScript() end
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

function drawChangelogTab()
    imgui.Text("[C] История обновлений")
    imgui.Separator()
    imgui.PushStyleColor(imgui.Col.ChildBg, colors.childPanelColor)
    if imgui.BeginChild("Changelog", imgui.ImVec2(0,200), true) then
        for _, entry in ipairs(changelogEntries) do
            if imgui.CollapsingHeader("Версия " .. entry.version) then
                imgui.PushTextWrapPos(0)
                imgui.Text(entry.description)
                imgui.PopTextWrapPos()
            end
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

-- Анимация появления (плавное изменение прозрачности)
local windowAlpha = new.float(0.0)
local function animateWindow(state)
    local targetAlpha = state and 1.0 or 0.0
    windowAlpha[0] = windowAlpha[0] + (targetAlpha - windowAlpha[0]) * 0.1
    if math.abs(targetAlpha - windowAlpha[0]) < 0.01 then
        windowAlpha[0] = targetAlpha
    end
    return windowAlpha[0]
end

-- Основной поток
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("cho", function()
        main_window_state[0] = not main_window_state[0]
        if main_window_state[0] then sampToggleCursor(true) else sampToggleCursor(false) end
    end)

    sendToChat("{1E90FF} [!repflow]: {FFFFFF}Скрипт загружен. Меню: {00FF00}/cho")
    checkUpdates()

    local prev_main_state = false

    while true do
        wait(0)

        if autoStartEnabled[0] and not active and (os.clock() - afkExitTime > afkCooldown) then
            active = true
            startTime = os.clock()
            sendToChat("{1E90FF} [!repflow]: Автостарт")
        end

        if main_window_state[0] and not isPauseMenuActive() then
            imgui.Process = true
        else
            imgui.Process = false
        end

        if main_window_state[0] ~= prev_main_state then
            if main_window_state[0] then sampToggleCursor(true) else sampToggleCursor(false) end
            prev_main_state = main_window_state[0]
        end

        if not changingKey and isKeyJustPressed(keyBind) and not sampIsChatInputActive() and not sampIsDialogActive() then
            onToggleActive()
        end

        if active then
            local current = os.clock() * 1000
            if current - lastOtTime >= otInterval[0] then
                sampSendChat('/ot')
                lastOtTime = current
            end
        end
    end
end

-- Фильтр сообщений (опционально)
function sampev.onServerMessage(color, text)
    return filterFloodMessage(text)
end

-- ImGui инициализация
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.GetIO().Fonts:AddFontDefault()
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(16,16)
    style.WindowRounding = 14.0
    style.WindowBorderSize = 0.0
    style.ChildRounding = 12.0
    style.FramePadding = imgui.ImVec2(10,8)
    style.FrameRounding = 8.0
    style.ItemSpacing = imgui.ImVec2(12,10)
    style.ButtonTextAlign = imgui.ImVec2(0.5,0.5)
    style.WindowTitleAlign = imgui.ImVec2(0.5,0.5)
    style.Alpha = 1.0
end)

-- Главное окно
local lastWindowSize = nil
imgui.OnFrame(function() return main_window_state[0] end, function()
    local alpha = animateWindow(main_window_state[0])
    if alpha < 0.01 then return end

    imgui.PushStyleVar(imgui.StyleVar.Alpha, alpha)
    imgui.SetNextWindowSize(imgui.ImVec2(ini.window.sizeX, ini.window.sizeY), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5,0.5))
    imgui.PushStyleColor(imgui.Col.WindowBg, colors.rightPanelColor)

    if imgui.Begin("!repflow", main_window_state, imgui.WindowFlags.NoCollapse) then
        -- Левая панель с вкладками
        imgui.PushStyleColor(imgui.Col.ChildBg, colors.leftPanelColor)
        if imgui.BeginChild("left_panel", imgui.ImVec2(120,-1), false) then
            local tabs = { "Флудер", "Настройки", "Информация", "Обновления" }
            for i,name in ipairs(tabs) do
                if i-1 == active_tab[0] then
                    imgui.PushStyleColor(imgui.Col.Button, colors.hoverColor)
                else
                    imgui.PushStyleColor(imgui.Col.Button, colors.leftPanelColor)
                end
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.hoverColor)
                imgui.PushStyleColor(imgui.Col.ButtonActive, colors.hoverColor)
                if imgui.Button(name, imgui.ImVec2(110,40)) then active_tab[0] = i-1 end
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
            elseif active_tab[0] == 2 then drawInfoTab()
            elseif active_tab[0] == 3 then drawChangelogTab() end
        end
        imgui.EndChild()
        imgui.PopStyleColor()

        local winSize = imgui.GetWindowSize()
        if lastWindowSize and (lastWindowSize.x ~= winSize.x or lastWindowSize.y ~= winSize.y) then
            ini.window.sizeX = winSize.x; ini.window.sizeY = winSize.y
            inicfg.save(ini, IniFilename)
        end
        lastWindowSize = imgui.ImVec2(winSize.x, winSize.y)
    end
    imgui.End()
    imgui.PopStyleColor()
    imgui.PopStyleVar()
end)

-- Смена клавиши
function onWindowMessage(msg, wparam, lparam)
    if changingKey then
        if msg == 0x100 or msg == 0x101 then
            keyBind = wparam
            keyBindName = vkeys.id_to_name(keyBind)
            changingKey = false
            saveSettings()
            sendToChat("{1E90FF} [!repflow]: Новая клавиша: " .. keyBindName)
            return false
        end
    end
end
