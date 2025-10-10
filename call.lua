---@diagnostic disable: lowercase-global

script_name("CALL")
script_author("sVor fix By Edward")

local ev = require("samp.events")

local callData = {
    calling = false,
    getNumberStep = 0,
    nick = nil,
    number = 0
}

local sideBar = false
local cancelCall = false
local acceptCall = false
local callInProcess = false

local incomingCalling = false

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    systemMessage("Для звонка используйте: {c0c0c0}/call [id/number] Fix {FF0000}By {00FFFF}Edward ")
    
    sampRegisterChatCommand("call", function(arg)
        if tonumber(arg) == nil or #arg == 0 then return systemMessage("Введите: {c0c0c0}/call [id/number] {FF0000}By {00FFFF}Edward ") end
        if callData.calling then return systemMessage("Происходит набор номера. Пожалуйста, подождите..") end

        callData.calling = true

        if #arg > 4 then
            callData.number = arg
            if sideBar then call(arg, "Не определен")
            else sampSendChat("/phone") end
        else
            callData.getNumberStep = 0
            sampSendChat("/id "..arg)
        end
    end)

    sampRegisterChatCommand("h", function()
        if callData.calling then
            if sideBar then
                stopCalling()
                sendCef("callApp.callFinished")
                sendCef("sidebar.close")
                systemMessage("Вы завершили звонок.")
            else
                cancelCall = true
                sampSendChat("/phone")
            end
        elseif incomingCalling then
            incomingCalling = false
            if sideBar then
                sendCef("callApp.callFinished")
                sendCef("sidebar.close")
            else
                sampSendChat("/phone")
            end
            systemMessage("Вы отклонили входящий звонок.")
        elseif callInProcess then
            callInProcess = false
            stopCalling()
            if sideBar then
                sendCef("callApp.callFinished")
                sendCef("sidebar.close")
            else
                sampSendChat("/phone")
            end
            systemMessage("Вы повесили трубку.")
        else
            systemMessage("Нет активного звонка для завершения.")
        end
    end)

    sampRegisterChatCommand("p", function()
        if incomingCalling then
            incomingCalling = false
            callData.calling = true
            callInProcess = true
            if sideBar then
                sendCef("callApp.callStarted")
            else
                acceptCall = true
                sampSendChat("/phone")
            end
            systemMessage("Вы приняли звонок.")
        else
            systemMessage("Нет входящего звонка для принятия.")
        end
    end)
    
    while true do
       wait(0)
    end
end

function ev.onServerMessage(color, text)
    if text:find("ID:") and callData.calling and callData.getNumberStep == 0 then
        callData.getNumberStep = callData.getNumberStep + 1
        callData.nick = text:match("(%w+_%w+)")
        if sideBar then sendCef("messengerApp.search|"..callData.nick)
        else sampSendChat("/phone") end
        return false
    end

    if (text:find("Неверный id") or text:find("Ничего не найдено!")) and callData.calling and callData.getNumberStep == 0 then
        systemMessage("Данного игрока не существует!")
        stopCalling()
        return false
    end

    if text:find("Звонок от") or text:find("входящий звонок") then
        local nick = text:match("Звонок от%s+(%S+)")
        systemMessage("Входящий вызов от {ff3636}"..(nick or "Неизвестный"))
        systemMessage("Для принятия звонка используйте - {00ff00}/p")
        incomingCalling = true
        return false
    end
end

function onReceivePacket(id, bs)
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        if (raknetBitStreamReadInt8(bs) == 17) then
            raknetBitStreamIgnoreBits(bs, 32)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            local str = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)

            if str:find("event.sideBar.selectMenuItemId") and str:find("phone") and (callData.calling or acceptCall) then
                if callData.getNumberStep == 1 and not cancelCall and not callInProcess then
                    sendCef("messengerApp.search|"..callData.nick)
                elseif cancelCall then
                    cancelCall = false
                    stopCalling()
                    sendCef("callApp.callFinished")
                    sendCef("sidebar.close")
                    systemMessage("Звонок был принудительно завершен.")
                elseif acceptCall then
                    acceptCall = false
                    incomingCalling = false
                    sendCef("callApp.callStarted")
                    systemMessage("Вы приняли звонок.")
                else
                    if not callInProcess then
                        sendCef("phone.launchApp|call")
                    end
                end
                return false, nil, nil
            end

            if ((str:find("event.phone.selectApp") and str:find("call")) or (str:find("event.callApp.changeScreen") and (str:find("history") or str:find("ringing")))) and callData.calling then
                return false, nil, nil
            end

            if str:find("event.messengerApp.initializeSearchResults") and callData.calling then
                callData.number = str:match("%,\"phone\":\"(%d+)\"%,")
                if tonumber(callData.number) ~= 0 and tonumber(callData.number) ~= 1 and callData.number ~= nil then
                    sendCef("phone.launchApp|call")
                else
                    sendCef("sidebar.close")
                    systemMessage("У данного игрока нет телефона!")
                    stopCalling()
                end
            end

            if str:find("event.callApp.initializeBalance") and callData.calling then
                if tonumber(str:match("%[(%d+)%]")) > 0 then
                    call(callData.number, (callData.nick ~= nil) and callData.nick:gsub("_", " ") or "Не определен")
                else
                    sendCef("sidebar.close")
                    systemMessage("У Вас на счету недостаточно средств!")
                    stopCalling()
                end
            end

            if str:find("event.sideBar.updateVisibility") then
                if str:find("true") then
                    sideBar = true
                    if callData.calling then return false, nil, nil end
                elseif str:find("false") then
                    sideBar = false
                end
            end

            if str:find("cef.addNotification") and (callData.calling) then
                sendCef("sidebar.close")
                if str:find("Абонент не в сети!") then
                    systemMessage("Данного игрока нет в сети!")
                elseif str:find("Абонент не ответил на Ваш звонок") then
                    systemMessage("Игрок не ответил на Ваш звонок!")
                elseif str:find("Подождите...") then
                    systemMessage("Ошибка вызова! Попробуйте ещё раз.")
                elseif str:find("Собеседник сбросил звонок") then
                    systemMessage("Звонок был сброшен собеседником!")
                elseif str:find("Абонент занят или разговаривает по другой линии") then
                    systemMessage("Игрок уже с кем-то разговаривает!")
                end
                stopCalling()
                return false, nil, nil
            end
        end
    end
end

function onSendPacket(id, bs, priority, reliability, orderingChannel) 
    if id == 220 then
        local id = raknetBitStreamReadInt8(bs)
        local packettype = raknetBitStreamReadInt8(bs)
        local strlen = raknetBitStreamReadInt8(bs)
        raknetBitStreamIgnoreBits(bs, 8)
        local str = raknetBitStreamReadString(bs, strlen)

        if str:find("callApp.callFinished") and (callData.calling or incomingCalling or callInProcess) then
            incomingCalling = false
            stopCalling()
        
        elseif str:find("callApp.loadHistory") and callData.calling then
            return false, nil, nil
        
        elseif str:find("callApp.callStarted") then
            callInProcess = true
            incomingCalling = false
            callData.calling = true
        end
    end
end

function call(number, nick)
    systemMessage("Набор номера: {ff3636}"..formatPhoneNumber(number, 3).." {fa6464}["..nick.."]")
    systemMessage("Принудительное завершение звонка: {ff3636}/h")
    sendCef("callApp.call|"..number)
    callInProcess = true
end

function stopCalling()
    callInProcess = false
    callData.calling = false
    callData.getNumberStep = 0
    callData.number = 0
    callData.nick = nil
end

function formatPhoneNumber(number, chunk)
    number = number:gsub("%D", "")
    local chunks = {}
    for i = 1, #number, chunk do
        table.insert(chunks, number:sub(i, i + chunk - 1))
    end
    local formated = table.concat(chunks, "-")
    return formated
end

function sendCef(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)              
    raknetBitStreamWriteInt8(bs, 18)               
    raknetBitStreamWriteInt16(bs, string.len(str)) 
    raknetBitStreamWriteString(bs, str)            
    raknetSendBitStreamEx(bs, 2, 9, 6)
end

function onScriptTerminate(script, quit)
    if script == thisScript() then
        systemMessage("Скрипт \""..thisScript().name.."\" экстренно завершил свою работу!")
    end
end

function systemMessage(text) return sampAddChatMessage("» CALL « {ffffff}"..text, 0xFFff3636) end