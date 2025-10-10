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
            sampAddChatMessage("| {ffffff}����������� ����� ����� "..(data.moveStack and "������������" or "��������������")..".", 0xFFFF0000)
        end)
    while true do
        wait(0)
    end
end

function ev.onShowTextDraw(id, textdraw)
    if (decodeText(textdraw.text):find("�������") or decodeText(textdraw.text):find("��������") or decodeText(textdraw.text):find("���")) and data.moveStack then
        textdraw.text = textdraw.text:gsub("%s.*", "").." ~g~( MOVE STACK )"
        return {id, textdraw}
    end
end

function ev.onShowDialog(id, style, title, button1, button0, text)
    if text:find("������� ����������") and button1 == "�����������" and data.moveStack then
        sampSendDialogResponse(id, 1, -1, text:match("%{.+%}��%s�����%s(%d+)%s��%."))
        return false
    elseif text:find("������� ����������") and button1 == "�������" and data.moveStack then
        sampSendDialogResponse(id, 1, -1, curItemNum)
        return false
    end

    if text:find("������� ����������") and text:find("������� ������\n������� ��������") then
        local price, max = text:match("����%s��%s%d%s��%:%s%{.+%}(%d+)%s���%.%{.+%}\n\n�����%s�������%s��%s�����%:%s%{.+%}(%d+)%s��%.%s������")
        local sell = 0

        if curItemNum > tonumber(max) then sell = tonumber(max)
        else sell = curItemNum end

        local totalPrice = tonumber(price) * sell
        text = text:gsub("����� ������� �� �����: {97FC9A}(%d+) ��. ������", "����� �������: {97FC9A}"..sell.." �� %1 ��. ������\n\
{ffffff}����� � �������: {97FC9A}"..separator(totalPrice).." ���.\n{ffffff}����� � ������� (� ���������): {97FC9A}"..separator((totalPrice - (totalPrice * (4 / 100)))).." ���.")

        return {id, style, title, button1, button2, text}
    end
end

function decodeText(encodedText)
    local dictionary = {
        ['a'] = '�',
        ['A'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['e'] = '�',
        ['E'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['k'] = '�',
        ['K'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['M'] = '�',
        ['�'] = '�',
        ['H'] = '�',
        ['o'] = '�',
        ['O'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['p'] = '�',
        ['P'] = '�',
        ['c'] = '�',
        ['C'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['y'] = '�',
        ['Y'] = '�',
        ['?'] = '�',
        ['�'] = '�',
        ['x'] = '�',
        ['X'] = '�',
        ['$'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�',
        ['�'] = '�'
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