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

function json(filePath)
    local filePath = getWorkingDirectory()..'\\config\\'..(filePath:find('(.+).json') and filePath or filePath..'.json')
    local class = {}
    if not doesDirectoryExist(getWorkingDirectory()..'\\config') then
        createDirectory(getWorkingDirectory()..'\\config')
    end

    function class:Save(tbl)
        if tbl then
            local F = io.open(filePath, 'w')
            F:write(encodeJson(tbl) or {})
            F:close()
            return true, 'ok'
        end
        return false, 'table = nil'
    end

    function class:Load(defaultTable)
        if not doesFileExist(filePath) then
            class:Save(defaultTable or {})
        end
        local F = io.open(filePath, 'r+')
        local TABLE = decodeJson(F:read() or {})
        F:close()
        for def_k, def_v in next, defaultTable do
            if TABLE[def_k] == nil then
                TABLE[def_k] = def_v
            end
        end
        return TABLE
    end

    return class
end

local data = json('itemsMover.json'):Load({
    moveStack = false
})

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
        sampRegisterChatCommand("stak", function()
            data.moveStack = not data.moveStack
            sampAddChatMessage("| {ffffff}Перемещение всего стака "..(data.moveStack and "активировано" or "деактивировано")..".", 0xFFFF0000)
        end)
    while true do
        wait(0)
    end
end

function ev.onShowTextDraw(id, textdraw)
    if (decodeText(textdraw.text):find("Мусорка") or decodeText(textdraw.text):find("Багажник") or decodeText(textdraw.text):find("Шка")) and data.moveStack then
        textdraw.text = textdraw.text:gsub("%s.*", "").." ~g~( MOVE STACK )"
        return {id, textdraw}
    end
end

function ev.onShowDialog(id, style, title, button1, button0, text)
    if text:find("Введите количество") and button1 == "Переместить" and data.moveStack then
        sampSendDialogResponse(id, 1, -1, text:match("%{.+%}Не%sболее%s(%d+)%sед%."))
        return false
    elseif text:find("Введите количество") and button1 == "Забрать" and data.moveStack then
        sampSendDialogResponse(id, 1, -1, curItemNum)
        return false
    end

    if text:find("Введите количество") and text:find("которое хотите\nпродать скупщику") then
        local price, max = text:match("Цена%sза%s%d%sшт%:%s%{.+%}(%d+)%sруб%.%{.+%}\n\nМожно%sпродать%sне%sболее%:%s%{.+%}(%d+)%sед%.%sтовара")
        local sell = 0

        if curItemNum > tonumber(max) then sell = tonumber(max)
        else sell = curItemNum end

        local totalPrice = tonumber(price) * sell
        text = text:gsub("Можно продать не более: {97FC9A}(%d+) ед. товара", "Можно продать: {97FC9A}"..sell.." из %1 ед. товара\n\
{ffffff}Доход с продажи: {97FC9A}"..separator(totalPrice).." руб.\n{ffffff}Доход с продажи (с комиссией): {97FC9A}"..separator((totalPrice - (totalPrice * (4 / 100)))).." руб.")

        return {id, style, title, button1, button2, text}
    end
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
        if dictionary[char] then
            decodedText = decodedText .. dictionary[char]
        else
            decodedText = decodedText .. char
        end

        i = i + 1
    end

    return decodedText
end

function ev.onSendClickTextDraw(id)
    local _, _, sizeX, sizeY = sampTextdrawGetBoxEnabledColorAndSize(id)
    local minDistObj = {x = 0.972 * sizeX, y = 0.676 * sizeY}
    local num = 1
    local model = select(1, sampTextdrawGetModelRotationZoomVehColor(id))
    if model ~= 1649 and model ~= 0 then
        local objX, objY = sampTextdrawGetPos(id)
        for td = 0, 4096 do
            if sampTextdrawIsExists(td) and sampTextdrawGetString(td):find("^%d+$") then
                local x, y = sampTextdrawGetPos(td)
                if x > objX and y > objY then
                    local distX = x - objX
                    local distY = y - objY
                    if distY < minDistObj.y and distX < minDistObj.x then
                        num = sampTextdrawGetString(td)
                        break
                    else
                        num = 1
                    end
                end
            end
        end
        curItemNum = tonumber(num)
    end
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

math.round = function(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

function onScriptTerminate(script, quit) if script == thisScript() then json('itemsMover.json'):Save(data) end end