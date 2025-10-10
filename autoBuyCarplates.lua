local countres = {"rus", "ua", "kz", "by"}
local settings = {status = false, country = 1, region = "777"}

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampAddChatMessage("[Auto-Buy Plates]{ffffff} Запуск автоматической покупки номеров: {fc446e}/abp [страна (1-4)] [регион]{ffffff}.", 0xfffc446e)

    -- Регистрация команды /abp
    sampRegisterChatCommand("abp", function(arg)
        if settings.status then
            settings.status = false
            sampAddChatMessage("| {ffffff}Ловля номеров выключена.", 0xfffc446e)
            return
        end

        local country, region = arg:match("(%d+)%s(.+)")
        if (tonumber(country) == nil or tonumber(country) < 1 or tonumber(country) > 4) or region == nil then 
            sampAddChatMessage("| {ffffff}Введите: {c0c0c0}/abp [страна (1-4)] [регион]", 0xfffc446e)
            for i = 1, #countres do
                sampAddChatMessage("{c0c0c0}["..i.."] - "..countres[i]:upper(), 0xfffc446e)
            end
            return
        end

        settings.country = countres[tonumber(country)]
        settings.region = region
        settings.status = true
        sampAddChatMessage("| {ffffff}Ловим номера с регионом {fc446e}"..region.." ["..countres[tonumber(country)]:upper().."]", 0xfffc446e)
    end)

    -- Обработчик пакетов
    function onSendPacket(id, bs, priority, reliability, orderingChannel)  
        if id == 220 then
            raknetBitStreamReadInt8(bs)
            local sub_id = raknetBitStreamReadInt8(bs)
            if sub_id == 18 then
                local strlen = raknetBitStreamReadInt16(bs)
                local str = raknetBitStreamReadString(bs, strlen)
                
                if str == "onActiveViewChanged|CarNumbers" and settings.status then
                    lua_thread.create(function()
                        -- Покупка номеров
                        wait(1000)
                        sendCommand("carNumbers.purchase|"..settings.country.."|"..settings.region)
                        
                        -- Инициализация номера (если нужно)
                        
                    end)
                end
            end
        end
    end

    -- Функция отправки команд
    function sendCommand(command)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 18)
        raknetBitStreamWriteInt16(bs, string.len(command))
        raknetBitStreamWriteString(bs, command)
        raknetSendBitStream(bs)
        raknetDeleteBitStream(bs)
        print("Отправлена команда: "..command)
    end

    -- Основной цикл
    while true do
        wait(300)
        if settings.status then
            local str = "carNumbers.purchase|"..settings.country.."|"..settings.region
            local bs = raknetNewBitStream()
            raknetBitStreamWriteInt8(bs, 220)
            raknetBitStreamWriteInt8(bs, 18)
            raknetBitStreamWriteInt16(bs, string.len(str))
            raknetBitStreamWriteString(bs, str)
            raknetSendBitStream(bs)
            raknetDeleteBitStream(bs)
        end
    end
end