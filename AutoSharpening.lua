local ev = require("samp.events")

-- _______________/\\\________/\\\_____________________________        
--  ______________\/\\\_______\/\\\_____________________________       
--   ______________\//\\\______/\\\______________________________      
--    __/\\\\\\\\\\__\//\\\____/\\\_______/\\\\\_____/\\/\\\\\\\__     
--     _\/\\\//////____\//\\\__/\\\______/\\\///\\\__\/\\\/////\\\_    
--      _\/\\\\\\\\\\____\//\\\/\\\______/\\\__\//\\\_\/\\\___\///__   
--       _\////////\\\_____\//\\\\\______\//\\\__/\\\__\/\\\_________  
--        __/\\\\\\\\\\______\//\\\________\///\\\\\/___\/\\\_________ 
--         _\//////////________\///___________\/////_____\///__________
--
-- vk.com/rodina_helper
-- t.me/vorrobey

local status = false
local lvlInfo = {}
local sharpTD = -1

local stats = {firstLVL = -1, needLVL = -1, steps = 0, success = 0, lose = 0, curPrice = 0}

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    systemMessage("Auto-Sharpening успешно подгружен! Взаимодействие: {c0c0c0}/sharp [заточка (1-13)]")

    sampRegisterChatCommand("sharp", function(arg)
        if status then status = false showStats() sampSendClickTextdraw(sharpTD) return systemMessage("Автоматическая заточка отключена.") end
        stats.firstLVL = -1
        stats.needLVL = -1
        stats.steps = 0
        stats.success = 0
        stats.lose = 0
        stats.curPrice = 0
        while #lvlInfo > 0 do table.remove(lvlInfo, 1) end
        if type(tonumber(arg)) == "number" then
            if tonumber(arg) >= 1 and tonumber(arg) <= 13 then
                local isTD = false
                local isReady = false
                local firstLVLID = 99999
                for td = 1, 4096 do
                    if sampTextdrawIsExists(td) then
                        local textTD = decodeText(sampTextdrawGetString(td))
                        if textTD == "Заточить" then
                            isTD = true
                            if isReady then
                                for i = 1, #lvlInfo do
                                    if lvlInfo[i].id < firstLVLID then
                                        firstLVLID = lvlInfo[i].id
                                        lvlInfo[i].id, lvlInfo[1].id = lvlInfo[1].id, lvlInfo[i].id
                                    end
                                end

                                if tonumber(arg) <= lvlInfo[1].lvl then return systemMessage("Уровень желаемой заточки должен быть от "..(lvlInfo[1].lvl+1).." до 13!") end
                                systemMessage("Заточка выбранного предмета c {ff0000}+"..lvlInfo[1].lvl.."{ffffff} до {ff0000}+"..arg.."{ffffff} начата!")
                                sampSendClickTextdraw(td-1)

                                status = true
                                stats.firstLVL = lvlInfo[1].lvl
                                stats.needLVL = tonumber(arg)
                                sharpTD = td-1
                                break
                            end
                        end

                        if textTD:find("руб.") then
                            stats.curPrice = tonumber(textTD:match("(%d+)"))
                        end

                        if textTD:find("+%s%d") then
                            table.insert(lvlInfo, {id = td, lvl = tonumber(textTD:match("%+%s(%d+)"))})
                            if #lvlInfo >= 2 then
                                isReady = true
                            end
                        end
                    end
                end

                if not isTD then return systemMessage("Для начала заточки необходимо открыть меню ателье!") end
                if not isReady then return systemMessage("Перед запуском необходимо выбрать предмет для заточки и точильные камни!") end
            else systemMessage("Уровень желаемой заточки должен быть от 1 до 13!") end
        else systemMessage("Используйте: {c0c0c0}/sharp [заточка (1-13)]") end
    end)

    sampRegisterChatCommand("statss", function() -- 7458 точилки

    end)
end

function ev.onDisplayGameText(style, time, text)
    local decText = decodeText(text)
    if decText:find("успех") or decText:find("неудача") and status then
        if #lvlInfo > 0 then
            stats.steps = stats.steps + 1
            if decText:find("неудача") then
                stats.lose = stats.lose + 1
            elseif decText:find("успех") then
                stats.success = stats.success + 1
            end

            if decodeText(sampTextdrawGetString(lvlInfo[1].id)) ~= "_" then
                if tonumber(decodeText(sampTextdrawGetString(lvlInfo[1].id)):match("%+%s(%d+)")) < stats.needLVL then
                    sampSendClickTextdraw(sharpTD)
                else
                    status = false
                    systemMessage("Предмет был успешно заточен до {ff0000}+"..stats.needLVL.."{ffffff}!")
                    showStats()
                end
            else
                local find = false
                for td = 1, 4096 do
                    local model = select(1, sampTextdrawGetModelRotationZoomVehColor(td))
                    if model == 7458 then
                        sampSendClickTextdraw(td)
                        find = true
                        break
                    end
                end

                if not find then
                    status = false
                    showStats()
                    systemMessage("В инвентаре (на первой странице) не найдено точильных камней. Процесс прерван.")
                    return
                end

                lua_thread.create(function()
                    wait(300)
                    if decodeText(sampTextdrawGetString(lvlInfo[1].id)) == "_" then
                        systemMessage("Предмет был заточен до максимального уровня! Продолжение невозможно.")
                        showStats()
                        status = false
                    else
                        systemMessage("Взяли точильные камни из инвентаря. Продолжаем заточку предмета..")
                        sampSendClickTextdraw(sharpTD)
                    end
                end)
            end
        end
    end
end

function showStats()
    local str = string.format("{ffffff}Заточка предмета с {ff0000}+%d{ffffff} до {ff0000}+%d{ffffff}:\n\
Всего попыток: {ff0000}%d{ffffff}\
Удачных попыток: {ff0000}%d{ffffff}\
Неудачных попыток: {ff0000}%d{ffffff}\n\
Стоимость одной попытки: {ff0000}%s руб.{ffffff}\
Потрачено валюты: {ff0000}%s руб.{ffffff}\
Потрачено точильных камней: {ff0000}%d шт.{ffffff}", stats.firstLVL, stats.firstLVL+stats.success, stats.steps, stats.success, stats.lose, separator(stats.curPrice), separator(stats.curPrice*stats.steps), stats.steps)
    return sampShowDialog(5656, "{ff0000}Заточка предмета by sVor |{ffffff} Статистика", str, "Отлично", "Ужасно", 0)
end

function systemMessage(text)
    return sampAddChatMessage("| {ffffff}"..tostring(text), 0xFFFF0000)
end

function separator(text)
	for S in string.gmatch(text, "%d+") do
		local replace = comma_value(S)
		text = string.gsub(text, S, replace)
	end
	for S in string.gmatch(text, "%d+") do
		S = string.sub(S, 0, #S-1)
		local replace = comma_value(S)
		text = string.gsub(text, S, replace)
	end
    return text
end

function comma_value(n)
    local left, num, right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	if num == nil then return n end
    return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

function decodeText(encodedText)
    local dictionary = {
        ['a'] = 'а',
        ['A'] = 'А',
        ['—'] = 'б',
        ['Ђ'] = 'Б',
        ['ў'] = 'в',
        ['‹'] = 'В',
        ['™'] = 'г',
        ['‚'] = 'Г',
        ['љ'] = 'д',
        ['ѓ'] = 'Д',
        ['e'] = 'е',
        ['E'] = 'Е',
        ['›'] = 'ж',
        ['„'] = 'Ж',
        ['џ'] = 'з',
        ['€'] = 'З',
        ['њ'] = 'и',
        ['…'] = 'И',
        ['ќ'] = 'й',
        ['k'] = 'к',
        ['K'] = 'К',
        ['ћ'] = 'л',
        ['‡'] = 'Л',
        ['Ї'] = 'м',
        ['M'] = 'М',
        ['®'] = 'н',
        ['H'] = 'Н',
        ['o'] = 'о',
        ['O'] = 'О',
        ['Ј'] = 'п',
        ['Њ'] = 'П',
        ['p'] = 'р',
        ['P'] = 'Р',
        ['c'] = 'с',
        ['C'] = 'С',
        ['¦'] = 'т',
        ['Џ'] = 'Т',
        ['y'] = 'у',
        ['Y'] = 'У',
        ['?'] = 'ф',
        ['Ѓ'] = 'Ф',
        ['x'] = 'х',
        ['X'] = 'Х',
        ['$'] = 'ц',
        ['‰'] = 'Ц',
        ['¤'] = 'ч',
        ['Ќ'] = 'Ч',
        ['Ґ'] = 'ш',
        ['Ћ'] = 'Ш',
        ['Ў'] = 'щ',
        ['Љ'] = 'Щ',
        ['©'] = 'ь',
        ['’'] = 'Ь',
        ['ђ'] = 'ъ',
        ['§'] = 'Ъ',
        ['Ё'] = 'ы',
        ['‘'] = 'Ы',
        ['Є'] = 'э',
        ['“'] = 'Э',
        ['«'] = 'ю',
        ['”'] = 'Ю',
        ['¬'] = 'я',
        ['•'] = 'Я'
    }

    local decodedText = ""
    local i = 1
    while i <= #encodedText do
        local char = encodedText:sub(i, i)

        -- Проверяем, существует ли текущий символ в словаре
        if dictionary[char] then
            decodedText = decodedText .. dictionary[char]
        else
            -- Если символ не найден в словаре, оставляем его без изменений
            decodedText = decodedText .. char
        end

        i = i + 1
    end

    return decodedText
end