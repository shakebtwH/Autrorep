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
local scriptver = "4.39 | Premium"

local scriptStartTime = os.clock()

local changelogEntries = {
    { version = "4.39 | Premium", description = "Скрипт временно закрыт. Ожидайте новостей от разработчика в Telegram." },
    { version = "4.38 | Premium", description = "- Исправлено отображение текста и кнопок во вкладке 'Флудер': добавлен перенос строк, увеличена ширина поля ввода, кнопка теперь не обрезается.\n- Улучшено выравнивание элементов во всех вкладках." },
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

-- Заглушка: все функции отключены
local function sendToChat(msg)
    sampAddChatMessage(toCP1251(msg), -1)
end

function show_arz_notify(type, title, text, time)
    -- Заглушка: ничего не делаем
end

-- ФУНКЦИИ ОБНОВЛЕНИЯ (оставляем для возможности будущих обновлений)
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

-- ОСНОВНОЙ ЦИКЛ (только информационное сообщение)
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    -- Приветственное сообщение о временном закрытии
    sendToChat("{1E90FF} [RepFlow]: {FFFF00}Скрипт временно закрыт. Ожидайте новостей от разработчика в Telegram.")
    sendToChat("{1E90FF} [RepFlow]: {FFFFFF}https://t.me/Repflowarizona")

    -- Автоматическая проверка обновлений (оставляем)
    checkUpdates()

    -- Регистрируем команду, которая будет показывать то же сообщение
    sampRegisterChatCommand("arep", function()
        sendToChat("{1E90FF} [RepFlow]: {FFFF00}Скрипт временно закрыт. Ожидайте новостей от разработчика в Telegram.")
        sendToChat("{1E90FF} [RepFlow]: {FFFFFF}https://t.me/Repflowarizona")
    end)

    -- Бесконечный цикл без активной ловли
    while true do
        wait(1000)
    end
end

-- Все обработчики событий SAMP отключены (возвращаем true, чтобы сообщения проходили)
function sampev.onServerMessage(color, text)
    return true
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    -- Ничего не делаем
end

-- Функция для окон imgui не используется, но оставим пустые обработчики, чтобы не было ошибок
imgui.OnInitialize(function() end)

imgui.OnFrame(function() return false end, function() end)
