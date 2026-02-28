```lua
require 'lib.moonloader'
local imgui = require 'mimgui'
local encoding = require 'encoding'
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

local scriptver = "4.45 | Premium"

-- Список изменений (только для истории)
local changelogEntries = {
    { version = "4.45 | Premium", description = "Скрипт в стадии бета теста." },
    { version = "4.44 | Premium", description = "Полная переработка кода: минималистичное информационное окно." },
}

-- Вспомогательная функция для отправки сообщений в чат
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
                        sendToChat("{1E90FF} [RepFlow]: {00FF00}Найдено обновление! Версия: " .. info.version)
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
            sendToChat("{1E90FF} [RepFlow]: {00FF00}Скрипт обновлен! Перезагрузка...")
            thisScript():reload()
        elseif status == 60 then
            update_status = "Ошибка загрузки"
        end
    end)
end

-- Переменные для окна
local main_window_state = imgui.new.bool(false)
local sw, sh = getScreenResolution()

-- Цвета
local colors = {
    bgColor = imgui.ImVec4(0.11, 0.12, 0.16, 1.0),
}

-- Отрисовка окна
function drawWindow()
    imgui.Text("Скрипт временно закрыт.")
    imgui.Text("Ожидайте новостей от разработчика в Telegram.")
    imgui.Dummy(imgui.ImVec2(0, 5))

    -- Ссылка
    local link = "https://t.me/Repflowarizona"
    local text = "Открыть Telegram канал"
    local tSize = imgui.CalcTextSize(text)
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()

    if imgui.InvisibleButton("##tg", tSize) then
        os.execute('start ' .. link)
    end

    local color = imgui.IsItemHovered() and 0xFFFFAA00 or 0xFF3F73D9
    dl:AddText(p, color, text)
    dl:AddLine(imgui.ImVec2(p.x, p.y + tSize.y), imgui.ImVec2(p.x + tSize.x, p.y + tSize.y), color)

    imgui.Dummy(imgui.ImVec2(0, 10))
    imgui.Text("Текущая версия: " .. scriptver)
    imgui.Text("Статус обновления: " .. update_status)

    if imgui.Button("Проверить обновления", imgui.ImVec2(200, 30)) then
        checkUpdates()
    end

    if update_found then
        imgui.SameLine()
        if imgui.Button("Установить", imgui.ImVec2(100, 30)) then
            updateScript()
        end
    end

    imgui.Dummy(imgui.ImVec2(0, 5))
    if imgui.Button("Закрыть", imgui.ImVec2(200, 30)) then
        main_window_state[0] = false
        sampToggleCursor(false)
    end
end

-- Основной цикл
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("arep", function()
        main_window_state[0] = not main_window_state[0]
        if main_window_state[0] then
            sampToggleCursor(true)
        else
            sampToggleCursor(false)
        end
    end)

    sendToChat("{1E90FF} [RepFlow]: {FFFF00}Скрипт временно закрыт. Меню: /arep")
    checkUpdates()

    while true do
        wait(0)
        if main_window_state[0] and not isPauseMenuActive() then
            imgui.Process = true
        else
            imgui.Process = false
        end
    end
end

-- Настройка imgui
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.GetIO().Fonts:AddFontDefault()
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(18, 18)
    style.WindowRounding = 12.0
    style.WindowBorderSize = 0.0
    style.FramePadding = imgui.ImVec2(10, 8)
    style.FrameRounding = 8.0
    style.ItemSpacing = imgui.ImVec2(12, 10)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
end)

imgui.OnFrame(function() return main_window_state[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(300, 230), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.PushStyleColor(imgui.Col.WindowBg, colors.bgColor)

    if imgui.Begin("RepFlow | Premium", main_window_state, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
        drawWindow()
    end
    imgui.End()
    imgui.PopStyleColor()
end)

function onWindowMessage() return false end
```
