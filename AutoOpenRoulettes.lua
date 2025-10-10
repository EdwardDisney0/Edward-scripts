script_name('Auto Open Roulette')
script_author('sVor Fix Edward')

local ev = require 'samp.events'
local act = false
local prizes = {}
local opened = 0
local nameRoulette = "�������"
local earnedCash = 0
local curMoney = 0
local time = os.clock()

function onReceivePacket(id, bs)
    if id == 220 then
        raknetBitStreamReadInt8(bs)
        local packetType = raknetBitStreamReadInt8(bs)
        if packetType == 17 then -- GET
            raknetBitStreamReadInt32(bs)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            if length > 0 then
                local text = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
                
                if text:find("event.crate.roulette.initialize") then
                    nameRoulette = text:match("\"name\":\"(.+)\",\"sysName\"") or "�������"
                end
            end
        end
    end
end

function onSendPacket(id, bs, priority, reliability, orderingChannel)  
    if id == 220 then
        raknetBitStreamReadInt8(bs)
        local sub_id = raknetBitStreamReadInt8(bs)
        if sub_id == 18 then
            local strlen = raknetBitStreamReadInt16(bs)
            local str = raknetBitStreamReadString(bs, strlen)
            
            if str == "onActiveViewChanged|CrateRoulette" and act then
                lua_thread.create(function()
                    -- ��������� �������
                    wait(100) -- �������� 1 �������
                    sendRouletteCommand("crate.roulette.open")
                    
                    -- ����� ����
                    wait(500) -- �������� 3 �������
                    sendRouletteCommand("crate.roulette.takePrize")
                    
                    -- �������
                    wait(250) -- �������� 1 �������
                    sendRouletteCommand("crate.roulette.exit")
                end)
            end
        end
    end
end

function sendRouletteCommand(command)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, string.len(command))
    raknetBitStreamWriteString(bs, command)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
    
    
    -- ���� ��������� ������� �������� �������, ��������� ������ ����
    if command == "crate.roulette.open" and act then
        lua_thread.create(function()
            -- ����� ����
            wait(500) -- �������� 3 �������
            sendRouletteCommandSimple("crate.roulette.takePrize")
            
            -- �������
            wait(200) -- �������� 1 �������
            sendRouletteCommandSimple("crate.roulette.exit")
        end)
    end
end

function sendRouletteCommandSimple(command)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, string.len(command))
    raknetBitStreamWriteString(bs, command)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function ev.onGivePlayerMoney(money)
    if act then
        earnedCash = earnedCash + (money - curMoney)
    end
end

function ev.onSendStatsUpdate(money, drunk)
    curMoney = money
end

function showPrizes()
    lua_thread.create(function()
        wait(200)
        local string = "{ffffff}����� ������� "..nameRoulette..": {fc446e}"..opened.." ����\n{ffffff}�������� ��������: {fc446e}"..separator(earnedCash).." ������\n\n"

        table.sort(prizes, function(a, b)
            return a.num > b.num
        end)

        local totalCount = 0
        for i = 1, #prizes do
            totalCount = totalCount + prizes[i].count
        end

        for i = 1, #prizes do
            local percentage = (prizes[i].count / totalCount) * 100
            string = string.."{ffffff}� "..tostring(prizes[i].name).." - {fc446e}"..tostring(prizes[i].num).." ���� {ffffff}| {fc446e}"..string.format("%.1f%%", percentage).."\n"
        end

        string = string.."\n{ffffff}��������� �������: {fc446e}"..convertTime(math.round(os.clock() - time))
        time = 0
        sampShowDialog(2324, "{fc446e}Auto Open Roulettes by sVor - Fix By Edward {ffffff}| ����������", string, "����", "�����", 0)
    end)
end

function ev.onServerMessage(color, text)
    if text:find("��������� � ���������") and act then
        local prize = "����������"
        local num = 1
        local find = false

        if text:find("��") then
            prize, num = text:match("��������� � ���������:%s(.+)%s%((%d+)%s��%)%.%s")
        else
            prize = text:match("��������� � ���������:%s(.+)%.%s")
        end

        num = num and tonumber(num) or 1

        for i = 1, #prizes do
            if prizes[i].name == prize then
                find = true
                prizes[i].num = prizes[i].num + num
                prizes[i].count = prizes[i].count + 1
                break
            end
        end

        if not find then
            table.insert(prizes, {name = prize, num = num, count = 1})
        end

        opened = opened + 1
    end
end

function separator(text)
    local result = text
    for S in string.gmatch(text, "%d+") do
        local replace = comma_value(S)
        result = string.gsub(result, S, replace)
    end
    return result
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

function convertTime(sec)
    if sec < 60 then
        return sec .. " ������"
    else
        local minutes = math.floor(sec / 60)
        local remainingSeconds = sec % 60
        return minutes .. " ����� " .. remainingSeconds .. " ������"
    end
end

function ev.onShowDialog(id, style, title, button1, button2, text)
    if act and text:find('����������� � ����������:') then
        sampSendDialogResponse(id, 1)
        return false
    end
end

function onWindowMessage(message, wparam, lparam)
    if message == 0x100 then
        if wparam == 0x71 then -- F2 key
            act = not act
            printStringNow(string.format('~G~%s ~W~- %s', thisScript().name, (act and '~G~On' or '~R~Off')), 2500)
            consumeWindowMessage(true, false)
            if act then
                time = os.clock()
                opened = 0
                earnedCash = 0
                prizes = {}
                sendRouletteCommand("crate.roulette.open")
            else
                showPrizes()
            end
        elseif wparam == 0x1B and act then -- ESC key
            act = false
            showPrizes()
            printStringNow(string.format('~G~%s ~W~- ~R~Off', thisScript().name), 2500)
            consumeWindowMessage(true, false)
        end
    end
    return false
end

function main()
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand("roulette", function()
        act = not act
        sampAddChatMessage(string.format('%s - %s', thisScript().name, (act and '{00FF00}On' or '{FF0000}Off')), -1)
        if act then
            time = os.clock()
            opened = 0
            earnedCash = 0
            prizes = {}
            sendRouletteCommand("crate.roulette.open")
        else
            showPrizes()
        end
    end)
    wait(-1)
end