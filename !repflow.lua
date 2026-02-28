require 'lib.moonloader'
local imgui = require 'mimgui'
local sampev = require 'lib.samp.events'
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
local scriptver = "4.41 | Premium"

local scriptStartTime = os.clock()

local changelogEntries = {
    { version = "4.41 | Premium", description = "Скрипт временно закрыт. Информация теперь отображается в меню /arep." },
}

-- Вспомогательная функция для отправки сообщений в чат (только для уведомлений об обновлении)
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

-- Переменные для управления окном
local main_window_state = new.bool(false)
local sw, sh = getScreenResolution()

-- Цвета для окна (простая тёмная тема)
local colors = {
    bgColor = imgui.ImVec4(0.11, 0.12, 0.16, 1.0),
    textColor = imgui.ImVec4(1, 1, 1, 1),
    linkColor = imgui.ImVec4(0.25, 0.45, 0.85, 1.0),
}

-- Функция для рисования информационного окна
function drawInfoWindow()
    imgui.Text("Скрипт временно закрыт.")
    imgui.Text("Ожидайте новостей от разработчика в Telegram.")
    imgui.Separator()
    
    -- Кликабельная ссылка
    local link = "https://t.me/Repflowarizona"
    local text = "Открыть Telegram канал"
    local tSize = imgui.CalcTextSize(text)
    local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    
    if imgui.InvisibleButton("##telegram_link", tSize) then
        os.execute('start ' .. link)  -- открыть ссылку в браузере
    end
    
    local color = imgui.IsItemHovered() and 0xFFFFAA00 or 0xFF3F73D9
    DL:AddText(p, color, text)
    DL:AddLine(imgui.ImVec2(p.x, p.y + tSize.y), imgui.ImVec2(p.x + tSize.x, p.y + tSize.y), color)
    
    imgui.Dummy(imgui.ImVec2(0, 10)) -- отступ
    if imgui.Button("Закрыть", imgui.ImVec2(200, 30)) then
        main_window_state[0] = false
        sampToggleCursor(false)
    end
end

-- Основной цикл
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    -- Регистрация команды /arep
    sampRegisterChatCommand("arep", function()
        main_window_state[0] = not main_window_state[0]
        if main_window_state[0] then
            sampToggleCursor(true)
        else
            sampToggleCursor(false)
        end
    end)

    -- Приветственное сообщение в чат (один раз)
    sendToChat("{1E90FF} [RepFlow]: {FFFF00}Скрипт временно закрыт. Меню: /arep")
    checkUpdates()

    -- Основной цикл
    while true do
        wait(0)

        -- Управление отрисовкой imgui: окно рисуется только когда оно открыто и игра не на паузе
        if main_window_state[0] and not isPauseMenuActive() then
            imgui.Process = true
        else
            imgui.Process = false
        end
    end
end

-- Обработчики SAMP отключены (возвращаем true, чтобы сообщения проходили)
function sampev.onServerMessage(color, text)
    return true
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    -- ничего не делаем
end

-- Настройка imgui
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.GetIO().Fonts:AddFontDefault()
    decor()
end)

function decor()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(20, 20)
    style.WindowRounding = 12.0
    style.WindowBorderSize = 0.0
    style.FramePadding = imgui.ImVec2(10, 8)
    style.FrameRounding = 8.0
    style.ItemSpacing = imgui.ImVec2(12, 12)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
end

imgui.OnFrame(function() return main_window_state[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(350, 200), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5,0.5))
    imgui.PushStyleColor(imgui.Col.WindowBg, colors.bgColor)

    if imgui.Begin("RepFlow | Premium", main_window_state, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
        drawInfoWindow()
    end
    imgui.End()
    imgui.PopStyleColor()
end)

-- Обработчик оконных сообщений (не используется, но оставлен для совместимости)
function onWindowMessage(msg, wparam, lparam)
    return false
end
