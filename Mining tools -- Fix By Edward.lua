script_name('Mining Tools')
script_author('JustFedot -- Fix By Edward and by dakyg')
script_version('2.2.9')
script_version_number(2)
script_description('Скрипт для упрощения майнинга на сервере.')

require("moonloader")
local sampfuncs = require("sampfuncs")
local sampev = require("samp.events")
local encoding = require("encoding")
encoding.default = 'CP1251'
u8 = encoding.UTF8
local imgui = require("mimgui")
local ffi = require('ffi')
local raknet = require('samp.raknet')
require('samp.synchronization')

if sampev.INTERFACE.INCOMING_RPCS[61][2].dialogId == "uint16" then
    sampev.INTERFACE.INCOMING_RPCS[61] = {
        "onShowDialog",
        {
            dialogId = "uint16"
        },
        {
            style = "uint8"
        },
        {
            title = "string8"
        },
        {
            button1 = "string8"
        },
        {
            button2 = "string8"
        },
        {
            text = "encodedString4096"
        },
        {
            placeholder = "string8"
        }
    }
end
local dialogIdTable = {}

local dialogIdTableArizona = {
    videoCardDialogId = 25245,       -- ID диалога управления видеокартой (Стойка/Полка)
    coolantDialogId = 25271,         -- ID диалога выбора охлаждающей жидкости
    houseDialogId = 7238,            -- ID диалога выбора дома
    houseFlashMinerDialogId = 25182, -- ID диалога выбора видеокарты в доме
    videoCardAcceptDialogId = 25246, -- ID диалога подтверждения вывода прибыли
}
local dialogIdTableRodina = {
    videoCardDialogId = 270,       -- ID диалога управления видеокартой (Стойка/Полка)
    coolantDialogId = 25271,       -- ID диалога выбора охлаждающей жидкости
    houseDialogId = 7238,          -- ID диалога выбора дома
    houseFlashMinerDialogId = 269, -- ID диалога выбора видеокарты в доме
    videoCardAcceptDialogId = 271, -- ID диалога подтверждения вывода прибыли
}

do
    Jcfg = {
        _version = 0.1,
        _author = "JustFedot",
        _telegram = "@justfedot",
        _help = [[Jcfg - модуль для сохранения и загрузки конфигурационных файлов...]]
    }

    function Jcfg.__init()
        local self = {}
        local json = require('dkjson')

        local function makeDirectory(path)
            assert(type(path) == "string" and path:find('moonloader'),
                "Path must be a string and include 'moonloader' folder")
            path = path:gsub("[\\/][^\\/]+%.json$", "")
            if not doesDirectoryExist(path) then
                if not createDirectory(path) then
                    return error("Failed to create directory: " .. path)
                end
            end
        end

        local function setupImguiConfig(table)
            assert(type(table) == "table",
                ("bad argument #1 to 'setupImgui' (table expected, got %s)"):format(type(table)))
            local function setupImguiConfigRecursive(tbl)
                local imcfg = {}
                for k, v in pairs(tbl) do
                    if type(v) == "table" then
                        imcfg[k] = setupImguiConfigRecursive(v)
                    elseif type(v) == "number" then
                        if v % 1 == 0 then
                            imcfg[k] = imgui.new.int(v)
                        else
                            imcfg[k] = imgui.new.float(v)
                        end
                    elseif type(v) == "string" then
                        imcfg[k] = imgui.new.char[256](u8(v))
                    elseif type(v) == "boolean" then
                        imcfg[k] = imgui.new.bool(v)
                    else
                        error(("Unsupported type for imguiConfig: %s"):format(type(v)))
                    end
                end
                return imcfg
            end
            return setupImguiConfigRecursive(table)
        end

        function self.save(table, path)
            assert(type(table) == "table", ("bad argument #1 to 'save' (table expected, got %s)"):format(type(table)))
            assert(path == nil or type(path) == "string", "Path must be nil or a valid file path.")
            if not path then
                assert(thisScript().name, "Script name is not defined")
                path = getWorkingDirectory() .. '\\config\\' .. thisScript().name .. '\\config.json'
            end
            makeDirectory(path)
            local file = io.open(path, "w")
            if file then
                file:write(json.encode(table, { indent = true }))
                file:close()
            else
                error("Could not open file for writing: " .. path)
            end
        end

        function self.load(path)
            if not path then
                path = getWorkingDirectory() .. '\\config\\' .. thisScript().name .. '\\config.json'
            end
            if doesFileExist(path) then
                local file = io.open(path, "r")
                if file then
                    local content = file:read("*all")
                    file:close()
                    return json.decode(content)
                else
                    return error("Could not load configuration")
                end
            end
            return {}
        end

        function self.update(table, path)
            assert(type(table) == "table", ("bad argument #1 to 'update' (table expected, got %s)"):format(type(table)))
            local loadedCfg = self.load(path)
            if loadedCfg then
                for k, v in pairs(table) do
                    if loadedCfg[k] ~= nil then
                        table[k] = loadedCfg[k]
                    end
                end
            end
            return true
        end

        function self.setupImgui(table)
            assert(imgui ~= nil, "The imgui library is not loaded.")
            return setupImguiConfig(table)
        end

        return self
    end

    setmetatable(Jcfg, {
        __call = function(self)
            return self.__init()
        end
    })
end

local jcfg = Jcfg()

local cfg = {
    isReloaded = false,
    silentMode = false,
    active = true,
    useSuperCoolant = false,
    useCoolantPercent = 50,
    economyMode = false,
    pause_duration = 120,
    count_action = 12
}

jcfg.update(cfg)
local imcfg = jcfg.setupImgui(cfg)

function save()
    jcfg.save(cfg)
end

function resetDefaultCfg()
    cfg = {
        isReloaded = true,
        silentMode = false,
        active = true,
        useSuperCoolant = false,
        useCoolantPercent = 50,
        economyMode = false,
        pause_duration = 120,
        count_action = 12
    }
    save()
    thisScript():reload()
end

local data = {
    main = imgui.new.bool(false),
    dialogData = {
        flashminer = {},
        videocards = {}
    },
    working = false,
    autoCoolant = false,
    isFlashminer = false,
    forImgui = {
        allGood = false,
        videocardCount = 0,
        earnings = { btc = 0, asc = 0 },
        attentionTime = 0,
    },
    withdraw = { btc = 0, asc = 0 },
    dFlashminerId = 0,
    flashminerSwitchId = { direction = 0, id = 0 },
    houseHasNoBasement = false,
    isRodina = false
}

local utils = (function()
    local self = {}
    local function cyrillic(text)
        local convtbl = {
            [230] = 155,
            [231] = 159,
            [247] = 164,
            [234] = 107,
            [250] = 144,
            [251] = 168,
            [254] = 171,
            [253] = 170,
            [255] = 172,
            [224] = 97,
            [240] = 112,
            [241] = 99,
            [226] = 162,
            [228] = 154,
            [225] = 151,
            [227] = 153,
            [248] = 165,
            [243] = 121,
            [184] = 101,
            [235] = 158,
            [238] = 111,
            [245] = 120,
            [233] = 157,
            [242] = 166,
            [239] = 163,
            [244] = 63,
            [237] = 174,
            [229] = 101,
            [246] = 36,
            [236] = 175,
            [232] = 156,
            [249] = 161,
            [252] = 169,
            [215] = 141,
            [202] = 75,
            [204] = 77,
            [220] = 146,
            [221] = 147,
            [222] = 148,
            [192] = 65,
            [193] = 128,
            [209] = 67,
            [194] = 139,
            [195] = 130,
            [197] = 69,
            [206] = 79,
            [213] = 88,
            [168] = 69,
            [223] = 149,
            [207] = 140,
            [203] = 135,
            [201] = 133,
            [199] = 136,
            [196] = 131,
            [208] = 80,
            [200] = 133,
            [198] = 132,
            [210] = 143,
            [211] = 89,
            [216] = 142,
            [212] = 129,
            [214] = 137,
            [205] = 72,
            [217] = 138,
            [218] = 167,
            [219] = 145
        }
        local result = {}
        for i = 1, #text do
            local c = text:byte(i)
            result[i] = string.char(convtbl[c] or c)
        end
        return table.concat(result)
    end
    function self.addChat(a)
        if cfg.silentMode then return end
        if a then
            local a_type = type(a)
            if a_type == 'number' then a = tostring(a) elseif a_type ~= 'string' then return end
        else
            return
        end
        sampAddChatMessage('{ffa500}' .. thisScript().name .. '{ffffff}: ' .. a, -1)

        --imgui.addNotification(u8(a):gsub('{%x%x%x%x%x%x}', ''))
    end

    function self.printStringNow(text, time)
        if not text then return end
        time = time or 100
        text = type(text) == "number" and tostring(text) or text
        if type(text) ~= 'string' then return end
        printStringNow(cyrillic(text), time)
    end

    function self.calculateRemainingHours(percent)
        local consumptionPerHour = 0.48
        return percent / consumptionPerHour
    end

    function self.formatTime(seconds)
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local secs = math.floor(seconds % 60)
        return string.format('%02d:%02d:%02d', hours, minutes, secs)
    end

    function self.random(min, max)
        math.randomseed(os.time())
        for _ = 1, 5 do math.random() end
        return math.random(min, max)
    end

    function self.simplifyNumber(num)
        local suffixes = { [1e9] = "kkk", [1e6] = "kk", [1e3] = "k" }
        for base, suffix in ipairs({ 1e9, 1e6, 1e3 }) do
            if num >= suffix then
                local decimals = (suffix == 1e3) and 1 or 3
                local value = round(num / suffix, decimals)
                return value .. (suffixes)[suffix]
            end
        end
        return tostring(num)
    end

    function self.formatNumber(num)
        if type(num) ~= 'number' then
            if type(num) == 'string' and tonumber(num) then
                num = tonumber(num)
            else
                return 'Error: invalid input'
            end
        end
        local formatted = string.format('%.0f', math.floor(num))
        local reversed = formatted:reverse()
        local with_dots = reversed:gsub('(%d%d%d)', '%1.'):reverse()
        if with_dots:sub(1, 1) == '.' then
            with_dots = with_dots:sub(2)
        end
        return with_dots
    end

    function samp_create_sync_data(sync_type, copy_from_player)
        copy_from_player = copy_from_player or true
        local sync_traits = {
            player = { 'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData },
            vehicle = { 'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData },
            passenger = { 'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData },
            aim = { 'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData },
            trailer = { 'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData },
            unoccupied = { 'UnoccupiedSyncData', raknet.PACKET.UNOCCUPIED_SYNC, nil },
            bullet = { 'BulletSyncData', raknet.PACKET.BULLET_SYNC, nil },
            spectator = { 'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil }
        }
        local sync_info = sync_traits[sync_type]
        if not sync_info then return end
        local data_type = 'struct ' .. sync_info[1]
        local data = ffi.new(data_type, {})
        local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))
        if copy_from_player then
            local copy_func = sync_info[3]
            if copy_func then
                local _, player_id
                if copy_from_player == true then
                    _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
                else
                    player_id = tonumber(copy_from_player)
                end
                copy_func(player_id, raw_data_ptr)
            end
        end
        local func_send = function()
            local bs = raknetNewBitStream()
            raknetBitStreamWriteInt8(bs, sync_info[2])
            raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data))
            raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
            raknetDeleteBitStream(bs)
        end
        local mt = {
            __index = function(t, index) return data[index] end,
            __newindex = function(t, index, value) data[index] = value end
        }
        return setmetatable({ send = func_send }, mt)
    end

    function self.pressButton(keysData)
        local sync = samp_create_sync_data('player')
        sync.keysData = keysData
        sync:send()
    end

    function self.sendVehiclePos(x, y, z)
        local sync = samp_create_sync_data('vehicle')
        sync.position = { x, y, z }
        sync:send()
    end

    function self.sendPlayerPos(x, y, z)
        local sync = samp_create_sync_data('player')
        sync.position = { x, y, z }
        sync:send()
    end

    function self.pressHorn()
        local keysData = samp_create_sync_data('vehicle').keysData
        keysData.keysData = bit.bor(keysData.keysData, 1)
        self.pressButton(keysData)
    end

    return self
end)()

function isArizonaServer()
    local serverName = sampGetCurrentServerName()
    local isMatch = serverName:match("^Arizona [^|]+ | ([^|]+) |") or serverName:match("^Arizona [^|]+ | ([^|]+)$")
    return isMatch ~= nil
end

function main()
    repeat wait(0) until isSampAvailable() and isSampfuncsLoaded()
    while not isSampLoaded() do wait(0) end

    data.isRodina = not isArizonaServer()
    if data.isRodina then
        dialogIdTable = dialogIdTableRodina
    else
        dialogIdTable = dialogIdTableArizona
    end

    utils.addChat('Загружен. Команда: {ffc0cb}/mnt{ffffff}.')

    sampRegisterChatCommand('mnt', function()
        cfg.active = not cfg.active
        utils.addChat(cfg.active and "Скрипт {99ff99}включен." or "Скрипт {F78181}отключен.")
        save()
    end)

    if cfg.isReloaded then
        cfg.isReloaded = false
        save()
    end

    local waitingForDialogClose = sampIsDialogActive() and
        (sampGetCurrentDialogId() == 25244 or sampGetCurrentDialogId() == dialogIdTable.houseFlashMinerDialogId)

    if sampIsDialogActive() then
        local id = sampGetCurrentDialogId()
        if id == 25244 or id == dialogIdTable.houseFlashMinerDialogId then
            waitingForDialogClose = true
        end
    end

    while true do
        wait(0)
        if cfg.active then
            local id = sampGetCurrentDialogId()
            local result = sampIsDialogActive()
            local isDialogActive = (id == 25244 or id == dialogIdTable.houseFlashMinerDialogId) and result
            if waitingForDialogClose and not isDialogActive then
                waitingForDialogClose = false
            end
            data.main[0] = cfg.active and (
                (isDialogActive and not waitingForDialogClose) or (data.main[0] and data.working)
            )
        end
    end
end

local dialogsToHideDuringTask = {
    titles = {
        "{BFBBBA}Выбор дома",
        "Вывод прибыли видеокарты",
        "Выберите тип жидкости",
        "^Полка №%d+",
        "^Стойка №%d+"
    },

    texts = {
        "Забрать прибыль",
        "Достать видеокарту",
        "Баланс Bitcoin"
    }
}

function sampev.onShowDialog(dialogId, style, title, button1, button2, text, placeholder)
    if not cfg.active then return end

    if data.working then
        sampSetCursorMode(1)
        for _, pattern in ipairs(dialogsToHideDuringTask.titles) do
            if title:find(pattern) then
                return false
            end
        end
        for _, pattern in ipairs(dialogsToHideDuringTask.texts) do
            if text:find(pattern) then
                return false
            end
        end
    end

    if title:find("{BFBBBA}Выбор дома") then
        if text:match("циклов %(%$%d+") then
            data.isFlashminer = true
            data.dFlashminerId = dialogId
            _formatHouseList(text)
            if data.flashminerSwitchId.direction ~= 0 then
                local base_index
                if data.forImgui.dTitle and data.forImgui.dTitle ~= "Неизвестно" then
                    for i, house in ipairs(data.dialogData.flashminer) do
                        if house.name:find(data.forImgui.dTitle) then
                            base_index = i
                            break
                        end
                    end
                end
                if not base_index then
                    base_index = data.flashminerSwitchId.direction == 1 and 0 or #data.dialogData.flashminer + 1
                end
                local next_index = base_index + data.flashminerSwitchId.direction
                if next_index > #data.dialogData.flashminer then next_index = 1 end
                if next_index < 1 then next_index = #data.dialogData.flashminer end

                if data.dialogData.flashminer[next_index] then
                    data.forImgui.dTitle = data.dialogData.flashminer[next_index].name:match("№(%d+)")
                    sampSendDialogResponse(dialogId, 1, next_index - 1, "")
                else
                    data.flashminerSwitchId.direction = 0
                end

                return false
            end
        else
            return
        end
        local newText = text .. "\n "
        newText = newText .. "\n{33CC33}» Включить все видеокарты"
        newText = newText .. "\n"
        newText = newText .. "\n{FFFF00}» Собрать криптовалюту со всех домов"
        newText = newText .. "\n"
        newText = newText .. "\n{FF3333}» Выключить все видеокарты"
        return { dialogId, style, title, button1, button2, newText, placeholder }
    end

    if title:find("^{......}Выберите видеокарту") or title:find("^Полка №%d+") or text:find("Баланс Bitcoin") or text:find('Обзор всех видеокарт') then
        data.flashminerSwitchId.direction = 0
        data.flashminerSwitchId.currentIndex = nil
        data.isFlashminer = title:find("%(дом №%d+%)") ~= nil
        data.dFlashminerId = dialogId
        data.forImgui = {
            dTitle = title:match("дом №(%d+)") or title:match("Полка №(%d+)") or title:match("Стойка №(%d+)") or
                "Неизвестно",
            allGood = true,
            videocardCount = 0,
            earnings = { btc = 0, asc = 0 },
            attentionTime = 101,
        }
        data.dialogData.videocards = {}
        local listbox_index = -1
        for line in text:gmatch("[^\n\r]+") do
            listbox_index = listbox_index + 1
            if line:find("{......}Работает") or line:find("{......}На паузе") then
                local card = {
                    index = listbox_index,
                    working = line:find("{......}Работает") and true or false,
                    btc = tonumber(select(1, line:match("(%d+)%.%d+ BTC"))) or 0,
                    asc = tonumber(select(1, line:match("(%d+)%.%d+ ASC"))) or 0,
                    coolant = tonumber(line:match("(%d+%.%d+)%%?%s*$")) or 0,
                    fluidType = line:find("BTC") and 1 or (line:find("ASC") and 2 or 0),
                    id = dialogId
                }
                table.insert(data.dialogData.videocards, card)
                if not card.working or card.coolant < cfg.useCoolantPercent then data.forImgui.allGood = false end
                if card.coolant < data.forImgui.attentionTime then data.forImgui.attentionTime = card.coolant end
                data.forImgui.earnings.btc = data.forImgui.earnings.btc + card.btc
                data.forImgui.earnings.asc = data.forImgui.earnings.asc + card.asc
                data.forImgui.videocardCount = data.forImgui.videocardCount + 1
            end
        end
    end
end

function sampev.onServerMessage(color, text)
    if not cfg.active then return end
    if text:find("^Вы вывели {ffffff}%d+ [BTCASC]+{ffff00}") then
        if text:find("BTC") then
            data.withdraw.btc = data.withdraw.btc + tonumber(text:match("Вы вывели {ffffff}(%d+)"))
        elseif text:find("ASC") then
            data.withdraw.asc = data.withdraw.asc + tonumber(text:match("Вы вывели {ffffff}(%d+)"))
        end
        return false
    elseif text:find("^Вам был добавлен предмет") and (text:find(":item1811:") or text:find(":item5996:") or text:find("BTC") or text:find("ASC")) then
        return false
    elseif text:find("^Добавлено в инвентарь") and text:find("BTC") then
        data.withdraw.btc = data.withdraw.btc + (tonumber(text:match('%((%d+) шт%)')) or 1)
        return false
    elseif text:find("Выводить прибыль можно только целыми частями и минимум 1 целый коин.") then
        return false
    elseif text:find("Выберите дом с майнинг фермой") then
        return false
    elseif text:find("В этом доме нет подвала с вентиляцией или он еще не достроен.") then
        if data.working then
            data.houseHasNoBasement = true
            return false
        end
        if data.flashminerSwitchId.direction ~= 0 then
            sampSendChat("/flashminer")
            return false
        end
    elseif text:find("охлаждающей жидкости в видеокарту, состояние системы охлаждения восстановлено") then
        return false
    end
end

function sampev.onSendDialogResponse(dialogId, button, listitem, input)
    local cleanInput = input:gsub("{%x%x%x%x%x%x}", "")

    local function runTaskAndReopenDialog(taskFunction, ...)
        taskFunction(...)
        lua_thread.create(function()
            while data.working do
                wait(50)
            end
            wait(200)
            sampSendChat("/flashminer")
        end)
    end
    if cleanInput:find("» Собрать криптовалюту со всех домов") and button == 1 then
        local task = buildTaskTable('collectFromAllHouses')
        runTaskAndReopenDialog(function() task:run() end)
        return false
    end
    if cleanInput:find("» Включить все видеокарты") and button == 1 then
        local task = buildTaskTable('massSwitchCards')
        runTaskAndReopenDialog(function() task:run(true) end)
        return false
    end
    if cleanInput:find("» Выключить все видеокарты") and button == 1 then
        local task = buildTaskTable('massSwitchCards')
        runTaskAndReopenDialog(function() task:run(false) end)
        return false
    end
    return true
end

function _formatHouseList(text)
    data.dialogData.flashminer = {}
    for line in text:gmatch("[^\n\r]+") do
        local id, house_num = line:match("%[(%d+)%] Дом №(%d+)")
        if id then
            table.insert(data.dialogData.flashminer, {
                index = tonumber(id),
                name = "Дом №" .. house_num,
                balance = tonumber(line:match("%$(%d+)")) or 0
            })
        end
    end
end

function navigateFlashminer(direction)
    if data.working then return end
    data.flashminerSwitchId.direction = direction
    data.flashminerSwitchId.id = data.dFlashminerId
    data.isSwitchingHouse = true
    sampSendDialogResponse(data.dFlashminerId, 0, -1, "")
end

function createProtectedTask(taskFunction, ...)
    if data.working then
        utils.addChat("{F78181}Уже выполняется другая операция.")
        return
    end
    local args = { ... }
    lua_thread.create(function()
        data.working = true
        sampSetCursorMode(1)
        local action_count = 0
        local function sendResponse(...)
            data.dialogTimer = os.clock()
            sampSendDialogResponse(...)
            action_count = action_count + 1
            if not data.isRodina and action_count > 0 and action_count % cfg.count_action == 0 then
                wait(cfg.pause_duration)
            end
        end

        local success, err = pcall(function() taskFunction(sendResponse, unpack(args)) end)

        if not success then
            utils.addChat("{F78181}Критическая ошибка: " .. tostring(err))
            if sampIsDialogActive() then
                sampCloseCurrentDialogWithButton(0)
            end
        end
        wait(150)
        data.working = false
        sampSetCursorMode(0)
    end)
end

function buildTaskTable(taskType, ...)
    local task = {
        data = {
            mainId = data.dFlashminerId,
            listBoxes = {}
        }
    }

    if taskType == 'coolant' then
        task.coolant = function(self)
            local cardsToProcess = {}
            for _, card in ipairs(self.data.listBoxes) do
                if card.coolant < cfg.useCoolantPercent then table.insert(cardsToProcess, card) end
            end

            if #cardsToProcess == 0 then return utils.addChat("Во всех видеокартах достаточно охлаждающей жидкости.") end
            createProtectedTask(function(sendResponse)
                for _, card in ipairs(cardsToProcess) do
                    local refill_count = cfg.useSuperCoolant and 1 or ((card.coolant < 50.0) and 2 or 1)
                    if not cfg.useSuperCoolant and cfg.economyMode and (card.coolant + 50) > 70 then refill_count = 1 end
                    for i = 1, refill_count do
                        sendResponse(self.data.mainId, 1, card.index - 1, "")
                        sendResponse(dialogIdTable.videoCardDialogId, 1, data.isRodina and 2 or 3, "")

                        local fluid_listitem = (card.fluidType == 1 and (cfg.useSuperCoolant and 1 or 0)) or
                            (card.fluidType == 2 and (cfg.useSuperCoolant and 1 or 3))
                        if fluid_listitem ~= nil then
                            sendResponse(dialogIdTable.coolantDialogId, 1, fluid_listitem, "")
                        else
                            utils.addChat("Ошибка: не удалось определить тип жидкости для карты.")
                        end
                    end
                    sendResponse(dialogIdTable.videoCardDialogId, 0, 0, "")
                end
            end)
        end
    elseif taskType == 'switchCards' then
        task.switchCards = function(self, enable)
            local cardsToProcess = {}
            for _, card in ipairs(self.data.listBoxes) do
                if card.working == (not enable) then table.insert(cardsToProcess, card) end
            end

            if #cardsToProcess == 0 then
                return utils.addChat("Видеокарты и так уже " ..
                    ((enable and "включены." or "выключены.")))
            end
            createProtectedTask(function(sendResponse)
                for i, card in ipairs(cardsToProcess) do
                    sendResponse(self.data.mainId, 1, card.index - 1, "")
                    sendResponse(dialogIdTable.videoCardDialogId, 1, 0, "")
                    sendResponse(dialogIdTable.videoCardDialogId, 0, 0, "")
                end
            end)
        end
    elseif taskType == 'takeCrypto' then
        task.takeCrypto = function(self)
            local cardsToProcess = {}
            for _, card in ipairs(self.data.listBoxes) do
                if card.btc >= 1 or card.asc >= 1 then table.insert(cardsToProcess, card) end
            end

            if #cardsToProcess == 0 then return utils.addChat("Нет криптовалюты для снятия.") end
            data.withdraw = { asc = 0, btc = 0 }
            createProtectedTask(function(sendResponse)
                for _, card in pairs(cardsToProcess) do
                    sendResponse(self.data.mainId, 1, card.index - 1, "")

                    if card.btc >= 1 then
                        sendResponse(dialogIdTable.videoCardDialogId, 1, 1, "")
                        sendResponse(dialogIdTable.videoCardAcceptDialogId, 1, 0, "")
                    end

                    if card.asc >= 1 then
                        sendResponse(dialogIdTable.videoCardDialogId, 1, 2, "")
                        sendResponse(dialogIdTable.videoCardAcceptDialogId, 1, 0, "")
                    end

                    if data.isRodina then
                        utils.pressButton(1024)
                        wait(1000)
                        while not (sampIsDialogActive() and sampGetCurrentDialogId() == self.data.mainId) do wait(50) end
                    else
                        sendResponse(dialogIdTable.videoCardDialogId, 0, 0, "")
                    end
                end
                wait(250)
                if data.withdraw.btc > 0 or data.withdraw.asc > 0 then
                    utils.addChat("Выведено: " ..
                        (data.withdraw.btc > 0 and ("{99ff99}%d BTC"):format(data.withdraw.btc) or "") ..
                        (data.withdraw.btc > 0 and data.withdraw.asc > 0 and "{ffffff} и " or "") ..
                        (data.withdraw.asc > 0 and ("{ffa500}%d ASC"):format(data.withdraw.asc) or "") .. "{ffffff}.")
                end
            end)
        end
    elseif taskType == 'collectFromAllHouses' then
        task.run = function(self)
            local houses = {}
            for _, h in ipairs(data.dialogData.flashminer) do table.insert(houses, h) end
            if not houses or #houses == 0 then
                utils.addChat("{F78181}Список домов не найден. Повторите попытку.")
                return false
            end
            data.withdraw = { asc = 0, btc = 0 }
            utils.addChat("Начинаю сбор криптовалюты со всех домов...")
            createProtectedTask(function(sendResponse)
                for i, house in ipairs(houses) do
                    data.houseHasNoBasement = false
                    sendResponse(dialogIdTable.houseDialogId, 1, house.index - 1, "")
                    local start_time = os.clock()
                    while os.clock() - start_time < 0.5 do
                        wait(50)
                        if data.houseHasNoBasement then
                            break
                        end
                    end
                    if data.houseHasNoBasement then
                        utils.addChat(string.format("Пропускаю %s - нет подвала с вентиляцией.", house.name))
                        sampSendChat("/flashminer")
                        wait(100)
                    else
                        local cardsInThisHouse = {}

                        for _, cardData in ipairs(data.dialogData.videocards) do
                            if cardData.btc >= 1 or cardData.asc >= 1 then
                                table.insert(cardsInThisHouse, cardData)
                            end
                        end

                        if #cardsInThisHouse > 0 then
                            for _, card in ipairs(cardsInThisHouse) do
                                sendResponse(dialogIdTable.houseFlashMinerDialogId, 1, card.index - 1, "")
                                if card.btc >= 1 then
                                    sendResponse(dialogIdTable.videoCardDialogId, 1, 1, "")
                                    sendResponse(dialogIdTable.videoCardAcceptDialogId, 1, 0, "")
                                end
                                if card.asc >= 1 then
                                    sendResponse(dialogIdTable.videoCardDialogId, 1, 2, "")
                                    sendResponse(dialogIdTable.videoCardAcceptDialogId, 1, 0, "")
                                end
                                sendResponse(dialogIdTable.videoCardDialogId, 0, 0, "")
                            end
                        end

                        wait(300)
                        sendResponse(dialogIdTable.houseFlashMinerDialogId, 0, 0, "")
                    end
                end

                wait(250)
                utils.addChat("{BEF781}Обход всех домов завершен.")
                if data.withdraw.btc > 0 or data.withdraw.asc > 0 then
                    local btc_part = data.withdraw.btc > 0 and ("{99ff99}%d BTC"):format(data.withdraw.btc) or ""
                    local asc_part = data.withdraw.asc > 0 and ("{ffa500}%d ASC"):format(data.withdraw.asc) or ""
                    local separator = (data.withdraw.btc > 0 and data.withdraw.asc > 0) and "{ffffff} и " or ""
                    utils.addChat("Всего собрано: " .. btc_part .. separator .. asc_part .. "{ffffff}.")
                else
                    utils.addChat("Не было собрано ни одной целой монеты.")
                end
            end)
        end
    elseif taskType == 'massSwitchCards' then
        task.run = function(self, enable)
            local houses = {}

            for _, h in ipairs(data.dialogData.flashminer) do table.insert(houses, h) end
            if not houses or #houses == 0 then
                utils.addChat("{F78181}Список домов не найден. Повторите попытку.")
                return false
            end

            local actionText = enable and "Включаю" or "Выключаю"

            utils.addChat(actionText .. " видеокарты во всех домах...")
            createProtectedTask(function(sendResponse, enable_arg)
                for i, house in ipairs(houses) do
                    data.houseHasNoBasement = false
                    sendResponse(dialogIdTable.houseDialogId, 1, house.index - 1, "")
                    local start_time = os.clock()
                    while os.clock() - start_time < 0.5 do
                        wait(50)
                        if data.houseHasNoBasement then
                            break
                        end
                    end

                    if data.houseHasNoBasement then
                        utils.addChat(string.format("Пропускаю %s - нет подвала с вентиляцией.", house.name))
                        sampSendChat("/flashminer")
                        wait(100)
                    else
                        local cardsToSwitch = {}

                        for _, cardData in ipairs(data.dialogData.videocards) do
                            if (enable_arg and not cardData.working) or (not enable_arg and cardData.working) then
                                table.insert(cardsToSwitch, cardData)
                            end
                        end
                        if #cardsToSwitch > 0 then
                            for _, card in ipairs(cardsToSwitch) do
                                sendResponse(dialogIdTable.houseFlashMinerDialogId, 1, card.index - 1, "")
                                sendResponse(dialogIdTable.videoCardDialogId, 1, 0, "")
                                sendResponse(dialogIdTable.videoCardDialogId, 0, 0, "")
                            end
                        end

                        wait(300)
                        sendResponse(dialogIdTable.houseFlashMinerDialogId, 0, 0, "")
                    end
                end
                wait(250)
                utils.addChat("{BEF781}Переключение видеокарт завершено.")
            end, enable)
        end
    end
    return task
end

local fa = require('fAwesome6')

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = imgui.new.ImWchar[3](fa.min_range, fa.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), 14, config, iconRanges)
    do
        imgui.SwitchContext()
        local style                       = imgui.GetStyle()
        local colors                      = style.Colors
        local Col                         = imgui.Col
        local ImVec4                      = imgui.ImVec4
        local ImVec2                      = imgui.ImVec2

        colors[Col.Text]                  = ImVec4(1, 1, 1, 1)
        colors[Col.TextDisabled]          = ImVec4(0.5, 0.5, 0.5, 1)
        colors[Col.WindowBg]              = ImVec4(0.07, 0.07, 0.07, 1)
        colors[Col.ChildBg]               = ImVec4(0.07, 0.07, 0.07, 1)
        colors[Col.PopupBg]               = ImVec4(0.07, 0.07, 0.07, 1)
        colors[Col.Border]                = ImVec4(0.25, 0.25, 0.26, 0.54)
        colors[Col.BorderShadow]          = ImVec4(0, 0, 0, 0)
        colors[Col.FrameBg]               = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.FrameBgHovered]        = ImVec4(0.25, 0.25, 0.26, 1)
        colors[Col.FrameBgActive]         = ImVec4(0.25, 0.25, 0.26, 1)
        colors[Col.TitleBg]               = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.TitleBgActive]         = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.TitleBgCollapsed]      = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.MenuBarBg]             = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.ScrollbarBg]           = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.ScrollbarGrab]         = ImVec4(0, 0, 0, 1)
        colors[Col.ScrollbarGrabHovered]  = ImVec4(0.41, 0.41, 0.41, 1)
        colors[Col.ScrollbarGrabActive]   = ImVec4(0.51, 0.51, 0.51, 1)
        colors[Col.CheckMark]             = ImVec4(1, 1, 1, 1)
        colors[Col.SliderGrab]            = ImVec4(1, 1, 1, 0.3)
        colors[Col.SliderGrabActive]      = ImVec4(1, 1, 1, 0.3)
        colors[Col.Button]                = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.ButtonHovered]         = ImVec4(0.21, 0.2, 0.2, 1)
        colors[Col.ButtonActive]          = ImVec4(0.41, 0.41, 0.41, 1)
        colors[Col.Header]                = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.HeaderHovered]         = ImVec4(0.2, 0.2, 0.2, 1)
        colors[Col.HeaderActive]          = ImVec4(0.47, 0.47, 0.47, 1)
        colors[Col.Separator]             = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.SeparatorHovered]      = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.SeparatorActive]       = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.ResizeGrip]            = ImVec4(1, 1, 1, 0.25)
        colors[Col.ResizeGripHovered]     = ImVec4(1, 1, 1, 0.67)
        colors[Col.ResizeGripActive]      = ImVec4(1, 1, 1, 0.95)
        colors[Col.Tab]                   = ImVec4(0.12, 0.12, 0.12, 1)
        colors[Col.TabHovered]            = ImVec4(0.28, 0.28, 0.28, 1)
        colors[Col.TabActive]             = ImVec4(0.3, 0.3, 0.3, 1)
        colors[Col.TabUnfocused]          = ImVec4(0.07, 0.1, 0.15, 0.97)
        colors[Col.TabUnfocusedActive]    = ImVec4(0.14, 0.26, 0.42, 1)
        colors[Col.PlotLines]             = ImVec4(0.61, 0.61, 0.61, 1)
        colors[Col.PlotLinesHovered]      = ImVec4(1, 0.43, 0.35, 1)
        colors[Col.PlotHistogram]         = ImVec4(0.9, 0.7, 0, 1)
        colors[Col.PlotHistogramHovered]  = ImVec4(1, 0.6, 0, 1)
        colors[Col.TextSelectedBg]        = ImVec4(1, 0, 0, 0.35)
        colors[Col.DragDropTarget]        = ImVec4(1, 1, 0, 0.9)
        colors[Col.NavHighlight]          = ImVec4(0.26, 0.59, 0.98, 1)
        colors[Col.NavWindowingHighlight] = ImVec4(1, 1, 1, 0.7)
        colors[Col.NavWindowingDimBg]     = ImVec4(0.8, 0.8, 0.8, 0.2)
        colors[Col.ModalWindowDimBg]      = ImVec4(0, 0, 0, 0.7)

        style.WindowPadding               = ImVec2(5, 5)
        style.FramePadding                = ImVec2(5, 5)
        style.ItemSpacing                 = ImVec2(5, 5)
        style.ItemInnerSpacing            = ImVec2(2, 2)
        style.TouchExtraPadding           = ImVec2(0, 0)
        style.IndentSpacing               = 0
        style.ScrollbarSize               = 10
        style.GrabMinSize                 = 10
        style.WindowBorderSize            = 1
        style.ChildBorderSize             = 1
        style.PopupBorderSize             = 1
        style.FrameBorderSize             = 0
        style.TabBorderSize               = 1
        style.WindowRounding              = 5
        style.ChildRounding               = 5
        style.FrameRounding               = 5
        style.PopupRounding               = 5
        style.ScrollbarRounding           = 5
        style.GrabRounding                = 5
        style.TabRounding                 = 5
        style.WindowTitleAlign            = ImVec2(0.5, 0.5)
        style.ButtonTextAlign             = ImVec2(0.5, 0.5)
        style.SelectableTextAlign         = ImVec2(0.5, 0.5)
    end
end)

local notifications = {}

imgui.OnFrame(function() return data.main[0] end, function(self)
    local w, h = getScreenResolution()
    local windowSize = imgui.ImVec2(480.0, 323.0)
    local margin_right = 0.0
    local y_percent_top = 0.40

    local posX = w - windowSize.x - margin_right
    local posY = h * y_percent_top

    posX = math.max(0, math.min(posX, w - windowSize.x))
    posY = math.max(0, math.min(posY, h - windowSize.y))

    imgui.SetNextWindowSize(windowSize, imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Always)

    if imgui.Begin("##main_windos", data.main, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar +
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar +
            imgui.WindowFlags.NoMove) then
        imgui.customTitleBar(data.main, resetDefaultCfg, imgui.GetWindowWidth())

        __i__main()
        imgui.showNotifications(2)
        imgui.End()
    end
end)

function __i__main()
    imgui.BeginChild('##top_panel_unified', imgui.ImVec2(0, 104), true, imgui.WindowFlags.NoScrollbar)
    imgui.Columns(2, "##main_columns_unified", false, imgui.WindowFlags.NoScrollbar)
    imgui.SetColumnWidth(0, 255)
    -- Левая колонка с информацией
    __i__infoPanel()
    imgui.NextColumn()
    -- Правая колонка с кнопками управления
    __i__controlPanel()

    imgui.Columns(1)
    imgui.EndChild()

    -- Нижняя панель
    __i__bottomPanel()
end

function __i__infoPanel()
    imgui.BeginChild('##info_panel_child', imgui.ImVec2(0, -1), false, imgui.WindowFlags.NoScrollbar)
    local title_text = data.forImgui.dTitle or "Ожидание..."
    imgui.TextColoredRGB('{ffffff}Дом: {ffa500}№ ' .. title_text)
    imgui.TextColoredRGB('{ffffff}Статус фермы: ' ..
        (data.forImgui.allGood and '{BEF781}Всё хорошо.' or '{F78181}Требует внимания.'))
    imgui.TextColoredRGB('{ffffff}Количество видеокарт: {99ff99}' .. data.forImgui.videocardCount)
    imgui.TextColoredRGB('{ffffff}Можно снять: {BEF781}' ..
        data.forImgui.earnings.btc .. ' BTC' ..
        (not data.isRodina and ' {ffffff}|| {ffa500}' .. data.forImgui.earnings.asc .. ' ASC' or ''))
    imgui.TextColoredRGB('{ffffff}Проработает: {ffa500}~' ..
        math.floor(utils.calculateRemainingHours(data.forImgui.attentionTime)) .. " {ffffff}часов")
    imgui.EndChild()
end

function __i__controlPanel()
    local availableWidth = imgui.GetContentRegionAvail().x
    local buttonSide = ((availableWidth - imgui.GetStyle().ItemSpacing.x) / 2) - 2
    local buttonSize = imgui.ImVec2(buttonSide, buttonSide - 5)
    if data.isFlashminer then
        if imgui.Button(fa.ARROW_LEFT .. "##left", buttonSize) then navigateFlashminer(-1) end
        imgui.Hint(u8 "Переключиться на предыдущую ферму.")
        imgui.SameLine(0, imgui.GetStyle().ItemSpacing.x + 5)
        if imgui.Button(fa.ARROW_RIGHT .. "##right", buttonSize) then navigateFlashminer(1) end
        imgui.Hint(u8 "Переключиться на следующую ферму.")
    else
        -- Неактивные кнопки
        imgui.ButtonClickable("Доступно только в Флешке Майнера.", data.isFlashminer, fa.ARROW_LEFT .. "##left_disabled",
            buttonSize)
        imgui.SameLine(0, imgui.GetStyle().ItemSpacing.x + 5)
        imgui.ButtonClickable("Доступно только в Флешке Майнера.", data.isFlashminer,
            fa.ARROW_RIGHT .. "##right_disabled", buttonSize)
    end
end

-- Рисует ВСЕ, что находится под верхним блоком
function __i__bottomPanel()
    imgui.BeginChild('##bottom_panel_child', imgui.ImVec2(0, 0), false, imgui.WindowFlags.NoScrollbar)

    local style = imgui.GetStyle()
    local textLineHeight = imgui.GetTextLineHeight()
    local sliderHeight = textLineHeight + style.FramePadding.y * 2
    local staticContentHeight = (textLineHeight * 2) + sliderHeight +
        (style.ItemSpacing.y * 2)

    local availableHeight = imgui.GetContentRegionAvail().y
    local dynamicHeight = availableHeight - staticContentHeight

    local elementHeight = (dynamicHeight - (style.ItemSpacing.y * 3)) / 4 - 1

    if elementHeight < 20 then elementHeight = 20 end

    -- Ряд 1: Кнопка "Снять криптовалюту"
    local canWithdraw = data.forImgui.earnings.btc >= 1 or data.forImgui.earnings.asc >= 1
    if imgui.ButtonClickable("Нет криптовалюты для снятия.", canWithdraw and not data.working, u8 "Снять криптовалюту", imgui.ImVec2(-1, elementHeight)) then
        local task = buildTaskTable('takeCrypto')
        task.data.listBoxes = data.dialogData.videocards
        task:takeCrypto()
    end

    -- Ряд 2: Кнопки "Включить/Выключить"
    local halfButtonWidth = (imgui.GetContentRegionAvail().x - style.ItemSpacing.x) / 2
    if imgui.ButtonClickable("В процессе...", not data.working, u8 "Включить видеокарты", imgui.ImVec2(halfButtonWidth, elementHeight)) then
        local task = buildTaskTable('switchCards')
        task.data.listBoxes = data.dialogData.videocards
        task:switchCards(true)
    end
    imgui.SameLine()
    if imgui.ButtonClickable("В процессе...", not data.working, u8 "Выключить видеокарты", imgui.ImVec2(halfButtonWidth, elementHeight)) then
        local task = buildTaskTable('switchCards')
        task.data.listBoxes = data.dialogData.videocards
        task:switchCards(false)
    end

    -- Ряд 3: Кнопка "Залить жидкость"
    local canRefill = not data.isFlashminer and not data.working
    if imgui.ButtonClickable(data.isFlashminer and "Недоступно в флешке майнера" or "В процессе...", canRefill, u8 "Залить жидкость", imgui.ImVec2(-1, elementHeight)) then
        local task = buildTaskTable('coolant')
        task.data.listBoxes = data.dialogData.videocards
        task:coolant()
    end

    -- Ряд 4: Чекбоксы.
    local cursorY_before = imgui.GetCursorPosY()
    imgui.Dummy(imgui.ImVec2(-1, elementHeight))
    local cursorY_after = imgui.GetCursorPosY()

    local checkboxHeight = textLineHeight + style.FramePadding.y * 2
    imgui.SetCursorPosY(cursorY_before + (elementHeight - checkboxHeight) / 2)

    if imgui.Checkbox(u8 "Использовать Супер Охлаждающую Жидкость", imcfg.useSuperCoolant) then
        cfg.useSuperCoolant = imcfg.useSuperCoolant[0]; save()
    end
    imgui.Hint(u8("Использовать Супер Охлаждающую Жидкость вместо обычной.\n(Для  BTC карт и Asic Miner)"))
    imgui.SameLine()
    if imgui.Checkbox(u8 "Режим Экономии##econom", imcfg.economyMode) then
        cfg.economyMode = imcfg.economyMode[0]; save()
    end
    imgui.Hint(u8 "Включает экономию охлаждающей жидкости.\nРаботает только с обычными жидкостями и вне Вайс-Сити (и не для суперохлаждающих).\nКак это работает: если посли заливки одной жидкости уровень охлаждения достигает 70% и выше, то вторая жидкость не расходуется.\nБез этого режима скрипт всегда заполняет охлаждение до 100%.")

    imgui.SetCursorPosY(cursorY_after)

    imgui.Text(u8 "Порог срабатывания заливки:")
    imgui.TextDisabled(u8 "Если процент охлаждающей жикости < настроенной ниже, то заливаем.")
    imgui.PushItemWidth(-1)
    if imgui.SliderInt("##coolantPercent", imcfg.useCoolantPercent, 1, 100) then
        cfg.useCoolantPercent = imcfg.useCoolantPercent[0]; save()
    end
    imgui.PopItemWidth()

    imgui.EndChild()
end

function imgui.customTitleBar(param, resetFunc, windowWidth)
    local imStyle = imgui.GetStyle()

    imgui.SetCursorPosY(imStyle.ItemSpacing.y + 5)
    if imgui.Link("t.me/edward_scripts", u8("Telegram канал фиксера.\nНажми чтобы перейти/скопировать")) then
        imgui.addNotification(u8 "Ссылка скопирована!")
        imgui.SetClipboardText("https://t.me/edward_scripts")
        os.execute(('explorer.exe "%s"'):format("https://t.me/edward_scripts"))
    end

    imgui.SameLine()
    imgui.SetCursorPosX((windowWidth - 170 - imStyle.ItemSpacing.x + imgui.CalcTextSize("t.me/edward_scripts").x) / 2 -
        imgui.CalcTextSize(script.this.name).x / 2)
    imgui.TextColoredRGB(script.this.name)

    imgui.SameLine()

    imgui.SetCursorPosX(windowWidth - 170 - imStyle.ItemSpacing.x)
    imgui.SetCursorPosY(imStyle.ItemSpacing.y)
    if imgui.Button(fa('MONUMENT') .. "##popup_donation_button", imgui.ImVec2(50, 25)) then
        imgui.OpenPopup("donationPopupMenu")
    end

    imgui.SameLine()

    imgui.SetCursorPosX(windowWidth - 110 - imStyle.ItemSpacing.x)
    imgui.SetCursorPosY(imStyle.ItemSpacing.y)
    if imgui.Button(fa("BARS") .. "##popup_menu_button", imgui.ImVec2(50, 25)) then
        imgui.OpenPopup("upWindowPupupMenu")
    end

    imgui.SameLine()

    imgui.SetCursorPosX(windowWidth - 50 - imStyle.ItemSpacing.x)
    imgui.SetCursorPosY(imStyle.ItemSpacing.y)
    if imgui.ButtonClickable("У тебя тут нет власти...", not data, fa("XMARK") .. "##close_button", imgui.ImVec2(50, 25)) then
        param[0] = false
    end

    if imgui.BeginPopup("upWindowPupupMenu") then
        imgui.TextColoredRGB("Доп. Функции:")
        imgui.Separator()
        if imgui.Checkbox(u8 "Тихий режим##silentMode", imcfg.silentMode) then
            cfg.silentMode = imcfg.silentMode[0]
            save()
        end
        imgui.Hint(u8("Отключает все сообщения от скрипта в чате."))

        if imgui.Selectable(u8("Перезагрузить скрипт") .. "##reloadScriptButton", false) then
            cfg.isReloaded = true
            save()
            thisScript():reload()
        end
        if imgui.Selectable(u8("Сбросить все настройки") .. "##resetSettingsButton", false) then
            resetFunc()
        end
        if not data.isRodina then
            imgui.Text(u8 "Пауза между действиями:")
            if imgui.SliderInt("##pause", imcfg.pause_duration, 70, 200, u8("%d мс")) then
                cfg.pause_duration = imcfg.pause_duration[0]
                save()
            end
            imgui.Hint(u8(
                "Чем больше задержка, тем медленее работа скрипта.\nЭто помогает избежать киков за слишком быстрые действия."))

            imgui.Text(u8 "Количество действий:")
            if imgui.SliderInt("##count", imcfg.count_action, 1, 15) then
                cfg.count_action = imcfg.count_action[0]
                save()
            end
            imgui.Hint(u8("Сколько команд (кликов) отправить серверу до срабатывания задержки."))
        end

        imgui.TextDisabled(u8("Версия: ") .. script.this.version)
        imgui.EndPopup()
    end

    if imgui.BeginPopup("donationPopupMenu") then
        imgui.Text(u8(
            "Оригинальный автор скрипта Just Fedot"
        ))
        if imgui.Link("https://www.blast.hk/threads/213948/", u8 "Ссылка на исходный скрипт") then
            os.execute(('explorer.exe "%s"'):format("https://www.blast.hk/threads/213948/"))
        end

        imgui.Text(u8(
            "А так же вы можете почтить его память в данной теме"
        ))
        if imgui.Link("https://www.blast.hk/threads/235846/", u8 "Нажмите чтобы перейти") then
            os.execute(('explorer.exe "%s"'):format("https://www.blast.hk/threads/235846/"))
        end
        imgui.EndPopup()
    end
end

function imgui.addNotification(text)
    table.insert(notifications, {
        text = text,
        startTime = os.clock()
    })
end

function imgui.showNotifications(duration)
    local currentTime = os.clock()
    local activeNotifications = #notifications

    -- Начинаем отображение подсказок, если есть активные уведомления
    if activeNotifications ~= 0 then
        imgui.BeginTooltip()
    end
    for i = #notifications, 1, -1 do
        local notification = notifications[i]
        -- Проверяем, прошло ли время показа
        if currentTime - notification.startTime < duration then
            imgui.Text(notification.text)
            activeNotifications = activeNotifications + 1
            -- Если это не последнее уведомление, добавляем разделитель
            if i > 1 then
                imgui.Separator()
            end
        else
            table.remove(notifications, i)
        end
    end

    if activeNotifications ~= 0 then
        imgui.EndTooltip()
    end
end

function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4

    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end

    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
    end

    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else
                imgui.Text(u8(w))
            end
        end
    end

    render_text(text)
end

function imgui.ButtonClickable(hint, clickable, ...)
    if clickable then
        return imgui.Button(...)
    else
        local r, g, b, a = imgui.GetStyle().Colors[imgui.Col.Button].x, imgui.GetStyle().Colors[imgui.Col.Button].y,
            imgui.GetStyle().Colors[imgui.Col.Button].z, imgui.GetStyle().Colors[imgui.Col.Button].w
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(r, g, b, a / 2))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(r, g, b, a / 2))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(r, g, b, a / 2))
        imgui.PushStyleColor(imgui.Col.Text, imgui.GetStyle().Colors[imgui.Col.TextDisabled])
        imgui.Button(...)
        imgui.PopStyleColor()
        imgui.PopStyleColor()
        imgui.PopStyleColor()
        imgui.PopStyleColor()
        if hint then
            if imgui.IsItemHovered() then
                imgui.SetTooltip(u8(hint))
            end
        end
    end
end

function imgui.Hint(text, active)
    if not active then
        active = not imgui.IsItemActive()
    end

    -- Если активен элемент или active == true, показываем подсказку
    if imgui.IsItemHovered() and active then
        imgui.SetTooltip(text)
    end
end

function imgui.Link(label, description)
    local size, p, p2 = imgui.CalcTextSize(label), imgui.GetCursorScreenPos(), imgui.GetCursorPos()
    local result = imgui.InvisibleButton(label, size)
    imgui.SetCursorPos(p2)

    if imgui.IsItemHovered() then
        if description then
            imgui.BeginTooltip()
            imgui.PushTextWrapPos(600)
            imgui.TextUnformatted(description)
            imgui.PopTextWrapPos()
            imgui.EndTooltip()
        end
        imgui.TextColored(imgui.ImVec4(0.27, 0.53, 0.87, 1.00), label)
        imgui.GetWindowDrawList():AddLine(imgui.ImVec2(p.x, p.y + size.y), imgui.ImVec2(p.x + size.x, p.y + size.y),
            imgui.GetColorU32(imgui.Col.CheckMark))
    else
        imgui.TextColored(imgui.ImVec4(0.27, 0.53, 0.87, 1.00), label)
    end

    return result
end
