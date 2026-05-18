script_name('Box Opener')
script_author('Edward')
script_version('4.0')

local imgui    = require 'mimgui'
local ffi      = require 'ffi'
local encoding = require 'encoding'
local sampev   = require 'lib.samp.events'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local renderWindow     = imgui.new.bool(false)
local showDatesWindow  = imgui.new.bool(false)
local showFilterWindow = imgui.new.bool(false)
local resX, resY       = getScreenResolution()

local mainWinPos = {x = resX/2, y = resY/2}

local CHEST_ITEMS = {
    [1]    = "Рандомный ларец",
    [195]  = "Ларец почтальона",
    [202]  = "Летний ларец",
    [982]  = "Ящик Marvel",
    [983]  = "Ящик Американских звезд",
    [984]  = "Авто ящик",
    [985]  = "Мото ящик",
    [986]  = "Ящик Джентльмена",
    [1211] = "Ларец с премией",
    [1230] = "Ларец легендарных авто",
    [2704] = "Ларец олигарха",
    [3033] = "Ларец авто среднего класса",
    [4048] = "Ларец водителя автобуса",
    [4049] = "Ларец дальнобойщика",
    [4175] = "Ящик с оружием",
    [4187] = "Ящик с пт",
    [4351] = "Ларец рыболова",
    [4964] = "Ларец звездных войн",
    [5051] = "Ларец ужаса",
    [5052] = "Ларец 8-летия",
    [5516] = "Ларец инкассатора",
    [5712] = "Ларец ОБТ Mobile",
    [5820] = "Ларец дрифта",
    [5826] = "Ларец фортнайт",
    [6412] = "Ларец пожарного",
    [6547] = "Ларец соседа",
    [7002] = "Семейный ларец",
    [7227] = "Фракционный ларец",
    [7842] = "2к26 Монетный Ларец",
    [8025] = "Ларец FORBES",
    [4882] = "Админский кейс"
}

-- ============================================================
-- КИРИЛЛИЦА: таблица замен для toLower без C runtime
-- ============================================================
-- CP1251: А=0xC0..Я=0xDF -> а=0xE0..я=0xFF, Ё=0xA8->ё=0xB8
local function cyrLower(s)
    return (s:gsub('.', function(c)
        local b = c:byte()
        if b >= 0xC0 and b <= 0xDF then
            return string.char(b + 0x20)
        elseif b == 0xA8 then   -- Ё
            return string.char(0xB8)
        end
        return c:lower()        -- ASCII и прочее
    end))
end

-- Получить строку из imgui char-буфера и привести к нижнему регистру (CP1251)
local function getBufLower(buf)
    local s = ffi.string(buf)
    return cyrLower(s)
end

-- Поиск: haystack и needle — обе строки в CP1251
local function strContains(haystack, needle)
    if needle == '' then return true end
    local h = cyrLower(haystack)
    local n = cyrLower(needle)
    return h:find(n, 1, true) ~= nil
end

local function normalizeStr(s)
    return s:gsub('^%s+',''):gsub('%s+$','')
end

-- ============================================================
-- LOG SAVE/LOAD (JSON-файл рядом со скриптом)
-- Папку создаём через Lua (без os.execute > нет вспышки консоли)
-- ============================================================
local LOG_FILE = getWorkingDirectory()..'/config/BoxOpener_log.json'

local function ensureDir(path)
    local dir = path:match('^(.+)[\\/][^\\/]+$')
    if not dir then return end
    -- Пробуем открыть папку как файл; если не получается — создаём через lfs
    local ok, lfs = pcall(require, 'lfs')
    if ok then
        lfs.mkdir(dir)
    else
        -- Запасной вариант: тихий вызов через io (не создаёт окно)
        local attr = io.open(dir .. '/.keep', 'r')
        if not attr then
            -- Используем ffi для CreateDirectoryA (Windows, без консоли)
            pcall(function()
                ffi.cdef[[ int __stdcall CreateDirectoryA(const char* path, void* attrs); ]]
                ffi.C.CreateDirectoryA(dir, nil)
            end)
        else
            attr:close()
        end
    end
end

local function saveLog(log)
    ensureDir(LOG_FILE)
    local f = io.open(LOG_FILE, 'w')
    if not f then return end
    f:write('[\n')
    for i, e in ipairs(log) do
        f:write(string.format(
            '  {"ts":%d,"date":"%s","time":"%s","chestName":"%s","prize":"%s"}%s\n',
            e.ts,
            e.date:gsub('"','\\"'),
            e.time:gsub('"','\\"'),
            e.chestName:gsub('"','\\"'),
            e.prize:gsub('"','\\"'),
            (i < #log) and ',' or ''
        ))
    end
    f:write(']\n')
    f:close()
end

local function loadLog()
    local f = io.open(LOG_FILE, 'r')
    if not f then return {} end
    local raw = f:read('*a')
    f:close()
    if not raw or raw == '' then return {} end
    local result = {}
    for block in raw:gmatch('%b{}') do
        local ts        = tonumber(block:match('"ts":(%d+)'))
        local date      = block:match('"date":"([^"]*)"')
        local time_     = block:match('"time":"([^"]*)"')
        local chestName = block:match('"chestName":"([^"]*)"')
        local prize     = block:match('"prize":"([^"]*)"')
        if ts and date and time_ and chestName and prize then
            table.insert(result, {
                ts        = ts,
                date      = date,
                time      = time_,
                chestName = chestName,
                prize     = prize,
            })
        end
    end
    return result
end

-- ============================================================

local actionQueue = {}
local function queueAction(fn) table.insert(actionQueue, fn) end

local foundChests            = {}
local checkedChests          = {}
local isScanning             = false
local scanDone               = false
local collectingInventory    = false
local collectTimer           = 0
local COLLECT_TIMEOUT        = 2.5
local inventoryPacketsBuffer = {}

local isOpening          = false
local openQueue          = {}
local currentOpen        = nil
local openState          = 0
local openResponseTimer  = 0
local totalOpened        = 0
local gotOpenResponse    = false
local openResponseAmount = nil

local needInventRetry    = false

local openLog       = {}
local lastChestName = nil

local function setupDialogHandler()
    sampev.onShowDialog = function(id, dialogType, title, btn1, btn2, text)
        if not text then return end
        if not text:find('97FC9A') then return end

        local prize = text:match('%{97FC9A%}(.-)%{%x%x%x%x%x%x%}')
                   or text:match('%{97FC9A%}(.-)$')
        if prize then
            prize = prize:gsub('%s+$',''):gsub('^%s+','')
        else
            prize = 'Неизвестный приз'
        end

        local chest = lastChestName or 'Неизвестный ларец'
        local ts    = os.time()
        table.insert(openLog, {
            ts        = ts,
            date      = os.date('%Y-%m-%d', ts),
            time      = os.date('%H:%M:%S', ts),
            chestName = chest,
            prize     = prize,
        })
        if #openLog > 10000 then table.remove(openLog, 1) end

        saveLog(openLog)

        if isOpening then
            lua_thread.create(function()
                wait(30)
                sampCloseCurrentDialogWithButton(0)
            end)
        end
        return false
    end
end

function onReceivePacket(id, bs)
    if id ~= 220 then return end
    raknetBitStreamResetReadPointer(bs)
    raknetBitStreamReadInt8(bs)
    if raknetBitStreamReadInt8(bs) ~= 17 then return end
    raknetBitStreamIgnoreBits(bs, 32)
    local length    = raknetBitStreamReadInt16(bs)
    local isEncoded = raknetBitStreamReadInt8(bs)
    local str
    if isEncoded ~= 0 then
        str = raknetBitStreamDecodeString(bs, length + 1)
    else
        str = raknetBitStreamReadString(bs, length)
    end
    if not str then return end

    if collectingInventory then
        if str:find("event%.inventory%.playerInventory") and str:find('"action":2') then
            table.insert(inventoryPacketsBuffer, str)
            collectTimer = os.clock()
        end
    end

    if openState == 1 and currentOpen then
        if str:find("event%.inventory%.playerInventory") and str:find('"action":2') then
            local pat = '"slot":'..currentOpen.slot..',"available":1,"item":'..currentOpen.itemID..',"amount":(%d+)'
            local amt = str:match(pat)
            gotOpenResponse    = true
            openResponseAmount = amt and tonumber(amt) or 0
        end
    end
end

local function sendCEFCommand(cmd)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #cmd)
    raknetBitStreamWriteString(bs, cmd)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

local function parseInventory(packets)
    local items = {}
    for _, str in ipairs(packets) do
        for slot, itemID, amount in str:gmatch('"slot":(%d+),"available":1,"item":(%d+),"amount":(%d+)') do
            local s = tonumber(slot)
            if not items[s] then items[s] = {itemID=tonumber(itemID), amount=tonumber(amount)} end
        end
        for slot, itemID in str:gmatch('"slot":(%d+),"available":1,"item":(%d+),"blackout"') do
            local s = tonumber(slot)
            if not items[s] then items[s] = {itemID=tonumber(itemID), amount=1} end
        end
    end
    return items
end

local logSearchBuf  = imgui.new.char[256]('')
local logFilterDate = imgui.new.char[64]('')
local comboChestIdx = imgui.new.int(0)

local function getUniqueChestNames()
    local seen, list = {}, {'Все ларцы'}
    for _, e in ipairs(openLog) do
        if not seen[e.chestName] then seen[e.chestName]=true; table.insert(list, e.chestName) end
    end
    return list
end

local function getFilteredLog()
    local names      = getUniqueChestNames()
    local selChest   = names[comboChestIdx[0]+1] or 'Все ларцы'
    local dateFilter = ffi.string(logFilterDate):gsub('%s','')
    -- Поиск: берём raw CP1251 строку из буфера и нормализуем
    local srch       = normalizeStr(ffi.string(logSearchBuf))
    local result = {}
    for i = #openLog, 1, -1 do
        local e = openLog[i]
        if selChest == 'Все ларцы' or e.chestName == selChest then
            if dateFilter == '' or e.date == dateFilter then
                if srch == '' or
                   strContains(e.chestName, srch) or
                   strContains(e.prize, srch) then
                    table.insert(result, e)
                end
            end
        end
    end
    return result
end

local searchBuf  = imgui.new.char[256]('')
local currentTab = 0
local TAB_MAIN = 0
local TAB_LOG  = 1

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.DarkTheme()
    local defGlyph = imgui.GetIO().Fonts.ConfigData.Data[0].GlyphRanges
    imgui.GetIO().Fonts:Clear()
    local cfg = imgui.ImFontConfig()
    cfg.SizePixels = 14.0
    cfg.GlyphExtraSpacing.x = 0.1
    imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14)..'\\arialbd.ttf', cfg.SizePixels, cfg, defGlyph)
end)

imgui.OnFrame(
    function() return renderWindow[0] and not isPauseMenuActive() and not sampIsScoreboardOpen() end,
    function(player)
        player.HideCursor = imgui.IsMouseDown(1)

        imgui.SetNextWindowPos(imgui.ImVec2(resX/2, resY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(580, 500), imgui.Cond.FirstUseEver)
        imgui.Begin(u8('Box Opener'), renderWindow,
            imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)

        local wp = imgui.GetWindowPos()
        local ws = imgui.GetWindowSize()
        mainWinPos.x = wp.x
        mainWinPos.y = wp.y
        mainWinPos.w = ws.x
        mainWinPos.h = ws.y

        if currentTab == TAB_MAIN then
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.55,0.45,0.05,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.65,0.55,0.10,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.70,0.60,0.15,1))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00,0.90,0.20,1))
        else
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.15,0.15,0.15,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25,0.25,0.25,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.35,0.35,0.35,1))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.75,0.75,0.75,1))
        end
        if imgui.Button(u8('Ларцы'), imgui.ImVec2(130, 28)) then
            currentTab = TAB_MAIN
        end
        imgui.PopStyleColor(4)

        imgui.SameLine()

        if currentTab == TAB_LOG then
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.45,0.05,0.05,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.55,0.10,0.10,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.60,0.15,0.15,1))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00,0.35,0.35,1))
        else
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.15,0.15,0.15,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25,0.25,0.25,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.35,0.35,0.35,1))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.75,0.75,0.75,1))
        end
        if imgui.Button(u8('Лог ('..#openLog..')'), imgui.ImVec2(160, 28)) then
            currentTab = TAB_LOG
        end
        imgui.PopStyleColor(4)

        imgui.Separator()

        if currentTab == TAB_MAIN then
            if isOpening then
                imgui.TextColored(imgui.ImVec4(1,0.8,0,1), u8('Открытие...'))
                if currentOpen then
                    imgui.SameLine()
                    imgui.TextColored(imgui.ImVec4(1,0.9,0.4,1),
                        u8(currentOpen.name..' (ост. '..currentOpen.remaining..')'))
                end
            elseif isScanning then
                imgui.TextColored(imgui.ImVec4(0,0.8,1,1), u8('Сканирование...'))
            elseif scanDone then
                imgui.TextColored(imgui.ImVec4(0,1,0,1), u8('Найдено: '..#foundChests))
            else
                imgui.TextColored(imgui.ImVec4(0.5,0.5,0.5,1), u8('Ожидание'))
            end

            imgui.Separator()

            local busy = isScanning or isOpening

            if busy then imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.4) end
            if imgui.Button(u8('Обновить список'), imgui.ImVec2(150,26)) and not busy then
                queueAction(doStartScan)
            end
            if busy then imgui.PopStyleVar() end
            imgui.SameLine()

            if isOpening then
                if imgui.Button(u8('Стоп'), imgui.ImVec2(80,26)) then
                    queueAction(function()
                        isOpening=false; openQueue={}; openState=0; currentOpen=nil
                        needInventRetry=false
                        sms('Остановлено!')
                    end)
                end
            else
                if busy then imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.4) end
                if imgui.Button(u8('Открыть все'), imgui.ImVec2(110,26)) and not busy then
                    queueAction(function() doStartOpening(false) end)
                end
                imgui.SameLine()
                if imgui.Button(u8('Открыть отмеченные'), imgui.ImVec2(155,26)) and not busy then
                    queueAction(function() doStartOpening(true) end)
                end
                if busy then imgui.PopStyleVar() end
            end

            imgui.Separator()



            -- Поиск по главному списку ларцов (CP1251 aware)
            local srch = normalizeStr(ffi.string(searchBuf))
            if #foundChests == 0 then
                imgui.TextDisabled(u8(scanDone and '  Ларцы не найдены.' or '  Нажмите "Обновить список".'))
            else
                imgui.Text(u8('Найденные ларцы:'))
                imgui.BeginChild('chests_list', imgui.ImVec2(-1, -38), true)
                for i, chest in ipairs(foundChests) do
                    if srch == '' or strContains(chest.name, srch) then
                        local cb = imgui.new.bool(checkedChests[i] or false)
                        if imgui.Checkbox('##cb'..i, cb) then checkedChests[i]=cb[0] end
                        imgui.SameLine()
                        if isOpening and currentOpen and currentOpen.slot == chest.slot then
                            imgui.TextColored(imgui.ImVec4(1,0.8,0,1),
                                u8('>> ['..chest.slot..'] '..chest.name))
                        else
                            imgui.Text(u8('   ['..chest.slot..'] '..chest.name))
                        end
                    end
                end
                imgui.EndChild()
            end
        end

        if currentTab == TAB_LOG then
            if imgui.Button(u8('Даты'), imgui.ImVec2(70,26)) then
                showDatesWindow[0]  = not showDatesWindow[0]
                showFilterWindow[0] = false
            end
            imgui.SameLine()
            if imgui.Button(u8('Фильтры'), imgui.ImVec2(75,26)) then
                showFilterWindow[0] = not showFilterWindow[0]
                showDatesWindow[0]  = false
            end
            imgui.SameLine()
            imgui.TextDisabled(u8('Всего: '..#openLog))
            imgui.SameLine()
            if imgui.Button(u8('Очистить'), imgui.ImVec2(75,26)) then
                queueAction(function()
                    openLog={}
                    saveLog(openLog)
                    sms('Лог очищен.')
                end)
            end

            imgui.Separator()



            local names    = getUniqueChestNames()
            local selChest = names[comboChestIdx[0]+1] or 'Все ларцы'
            local dateStr  = ffi.string(logFilterDate):gsub('%s','')
            local finfo    = 'Фильтр: '..selChest
            if dateStr ~= '' then finfo = finfo..'  |  Дата: '..dateStr end
            imgui.TextColored(imgui.ImVec4(0.5,0.8,1,1), u8(finfo))
            imgui.Separator()

            local filtered = getFilteredLog()
            imgui.BeginChild('log_table', imgui.ImVec2(-1,-38), true)
            if #filtered == 0 then
                imgui.TextDisabled(u8('  Нет записей.'))
            else
                imgui.TextColored(imgui.ImVec4(0.55,0.55,0.55,1),
                    u8(string.format('%-19s  %-26s  %s', 'Дата и время', 'Ларец', 'Приз')))
                imgui.Separator()

                for _, e in ipairs(filtered) do
                    local r,g,b = 0.72,0.95,0.72
                    local pl    = cyrLower(e.prize)
                    if     pl:find('\xe2\xe0\xeb\xfe\xf2', 1, true) then r,g,b=0.98,0.88,0.30  -- валют
                    elseif pl:find('\xe0\xe2\xf2\xee',     1, true) then r,g,b=0.35,0.82,1.00  -- авто
                    elseif pl:find('\xec\xee\xf2\xee',     1, true) then r,g,b=0.85,0.50,1.00  -- мото
                    elseif pl:find('\xee\xf0\xf3\xe6\xe8', 1, true) then r,g,b=1.00,0.50,0.40  -- оружи
                    elseif e.prize=='(нет ответа)' then r,g,b=0.45,0.45,0.45
                    end

                    imgui.TextColored(imgui.ImVec4(r,g,b,1),
                        u8(string.format('%-19s  %-26s  %s',
                            e.date..' '..e.time,
                            e.chestName:sub(1,26),
                            e.prize)))
                end
            end
            imgui.EndChild()
        end

        local winW = imgui.GetWindowWidth()
        local winH = imgui.GetWindowHeight()
        imgui.SetCursorPos(imgui.ImVec2(0, winH - 28))
        imgui.Separator()

        local footerText = 'Box Opener  By  Edward'
        local textW = imgui.CalcTextSize(footerText).x + 8
        imgui.SetCursorPosX(winW - textW - 8)

        imgui.TextColored(imgui.ImVec4(1,1,1,1), u8('Box Opener'))
        imgui.SameLine(0, 0)
        imgui.TextColored(imgui.ImVec4(1,0,0,1), u8(' By'))
        imgui.SameLine(0, 0)
        imgui.TextColored(imgui.ImVec4(0,1,1,1), u8(' Edward'))

        imgui.End()

        if showDatesWindow[0] then
            local subX = mainWinPos.x + mainWinPos.w + 6
            local subY = mainWinPos.y
            imgui.SetNextWindowPos(imgui.ImVec2(subX, subY), imgui.Cond.Always)
            imgui.SetNextWindowSize(imgui.ImVec2(265, 270), imgui.Cond.Always)
            imgui.Begin(u8('Фильтр по дате'), showDatesWindow,
                imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize)

            imgui.Text(u8('Дата (ГГГГ-ММ-ДД):'))
            imgui.SetNextItemWidth(-1)
            imgui.InputText('##logdate', logFilterDate, ffi.sizeof(logFilterDate)-1)

            imgui.Spacing()
            if imgui.Button(u8('Сегодня'), imgui.ImVec2(82,24)) then
                ffi.copy(logFilterDate, os.date('%Y-%m-%d'))
            end
            imgui.SameLine()
            if imgui.Button(u8('Вчера'), imgui.ImVec2(70,24)) then
                ffi.copy(logFilterDate, os.date('%Y-%m-%d', os.time()-86400))
            end
            imgui.SameLine()
            if imgui.Button(u8('Сброс'), imgui.ImVec2(62,24)) then
                ffi.copy(logFilterDate, '')
            end

            imgui.Separator()
            imgui.Text(u8('Дни с открытиями:'))

            local dateCounts, dateOrder = {}, {}
            for _, e in ipairs(openLog) do
                if not dateCounts[e.date] then
                    dateCounts[e.date] = 0
                    table.insert(dateOrder, e.date)
                end
                dateCounts[e.date] = dateCounts[e.date]+1
            end
            table.sort(dateOrder, function(a,b) return a>b end)

            imgui.BeginChild('date_list', imgui.ImVec2(-1,-1), true)
            if #dateOrder == 0 then
                imgui.TextDisabled(u8('  Нет данных.'))
            end
            for _, d in ipairs(dateOrder) do
                local active = (ffi.string(logFilterDate):gsub('%s','') == d)
                if imgui.Selectable(u8(d..'     x'..dateCounts[d]), active) then
                    ffi.copy(logFilterDate, d)
                end
            end
            imgui.EndChild()
            imgui.End()
        end

        if showFilterWindow[0] then
            local subX = mainWinPos.x + mainWinPos.w + 6
            local subY = mainWinPos.y
            imgui.SetNextWindowPos(imgui.ImVec2(subX, subY), imgui.Cond.Always)
            imgui.SetNextWindowSize(imgui.ImVec2(310, 340), imgui.Cond.Always)
            imgui.Begin(u8('Фильтры'), showFilterWindow,
                imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize)

            imgui.Text(u8('Фильтр по ларцу:'))
            local names  = getUniqueChestNames()
            local lbl    = names[comboChestIdx[0]+1] or 'Все ларцы'
            imgui.SetNextItemWidth(-1)
            if imgui.BeginCombo('##chestcombo', u8(lbl)) then
                for idx, name in ipairs(names) do
                    local isSel = (comboChestIdx[0] == idx-1)
                    if imgui.Selectable(u8(name), isSel) then comboChestIdx[0]=idx-1 end
                    if isSel then imgui.SetItemDefaultFocus() end
                end
                imgui.EndCombo()
            end

            imgui.Spacing()
            if imgui.Button(u8('Сбросить все фильтры'), imgui.ImVec2(-1,26)) then
                comboChestIdx[0]=0
                ffi.copy(logFilterDate,'')
                ffi.copy(logSearchBuf,'')
            end

            imgui.Separator()
            local filtered = getFilteredLog()
            imgui.TextColored(imgui.ImVec4(0.5,1,0.5,1), u8('Найдено записей: '..#filtered))

            if #filtered > 0 then
                imgui.Spacing()
                imgui.Text(u8('Топ-10 призов:'))
                local prizeCount = {}
                for _, e in ipairs(filtered) do
                    prizeCount[e.prize] = (prizeCount[e.prize] or 0)+1
                end
                local prizeList = {}
                for prize, cnt in pairs(prizeCount) do
                    table.insert(prizeList, {prize=prize, cnt=cnt})
                end
                table.sort(prizeList, function(a,b) return a.cnt>b.cnt end)
                imgui.BeginChild('prize_stats', imgui.ImVec2(-1,-1), true)
                for i = 1, math.min(#prizeList,10) do
                    local p   = prizeList[i]
                    local pct = math.floor(p.cnt/#filtered*100)
                    imgui.Text(u8(string.format('x%-4d (%2d%%)  %s', p.cnt, pct, p.prize)))
                end
                imgui.EndChild()
            end
            imgui.End()
        end
    end
)

function doStartScan()
    isScanning             = true
    scanDone               = false
    inventoryPacketsBuffer = {}
    foundChests            = {}
    checkedChests          = {}
    collectingInventory    = true
    collectTimer           = os.clock()
    sampSendChat('/invent')
    sms('Открываю инвентарь...')
end

function doFinishScan()
    collectingInventory = false
    isScanning          = false
    scanDone            = true
    local items         = parseInventory(inventoryPacketsBuffer)
    foundChests         = {}
    checkedChests       = {}
    for slot, data in pairs(items) do
        if CHEST_ITEMS[data.itemID] then
            table.insert(foundChests, {
                slot=slot, itemID=data.itemID,
                name=CHEST_ITEMS[data.itemID], amount=data.amount,
            })
        end
    end
    table.sort(foundChests, function(a,b) return a.slot<b.slot end)
    for i=1,#foundChests do checkedChests[i]=false end
    if #foundChests == 0 then
        sms('Ларцы не найдены!')
    else
        sms('Найдено ларцов: {C0C0C0}'..#foundChests)
    end
end

function doStartOpening(onlyChecked)
    if #foundChests==0 then sms('Сначала обновите список!'); return end
    openQueue={}; totalOpened=0
    for i, chest in ipairs(foundChests) do
        if not onlyChecked or checkedChests[i] then
            table.insert(openQueue, {
                slot=chest.slot, itemID=chest.itemID,
                name=chest.name, amount=chest.amount, remaining=chest.amount,
            })
        end
    end
    if #openQueue==0 then sms('Нет ларцов! Отметьте хотя бы один.'); return end
    isOpening=true; openState=0; currentOpen=nil
    needInventRetry=false
    sms('Начинаю открытие {C0C0C0}'..#openQueue..' {FFFFFF}видов ларцов...')
end

function main()
    while not isSampAvailable() do wait(0) end

    openLog = loadLog()
    sms('Загружено записей из лога: {C0C0C0}'..#openLog)

    sampAddChatMessage('{FF0000}| {FFFFFF}Box Opener {FFFFFF}загружен {C0C0C0}/chests {FF0000}By {00FFFF}Edward', 0xFFFFFF)
    setupDialogHandler()

    sampRegisterChatCommand('box', function()
        renderWindow[0] = not renderWindow[0]
    end)

    while true do
        wait(0)

        if #actionQueue > 0 then
            local fn = table.remove(actionQueue,1); fn()
        end

        if collectingInventory and os.clock()-collectTimer > COLLECT_TIMEOUT then
            doFinishScan()
        end

        if isOpening then

            if openState == 0 then
                if #openQueue == 0 then
                    isOpening=false; currentOpen=nil
                    needInventRetry=false
                    sms('Готово! Всего открыто: {C0C0C0}'..totalOpened)
                else
                    currentOpen        = table.remove(openQueue,1)
                    lastChestName      = currentOpen.name
                    gotOpenResponse    = false
                    openResponseAmount = nil
                    needInventRetry    = false
                    sendCEFCommand('inventory.moveItemForce|{"slot": '..currentOpen.slot..', "type": 1, "amount": 1}')
                    openResponseTimer  = os.clock()
                    openState = 1
                end

            elseif openState == 1 then
                local elapsed  = os.clock() - openResponseTimer
                local timedOut = elapsed > 1.5

                if gotOpenResponse then
                    totalOpened = totalOpened + 1
                    local remaining = openResponseAmount or 0

                    if remaining > 0 then
                        currentOpen.remaining = remaining
                        gotOpenResponse    = false
                        openResponseAmount = nil
                        needInventRetry    = false
                        wait(1)
                        sendCEFCommand('inventory.moveItemForce|{"slot": '..currentOpen.slot..', "type": 1, "amount": 1}')
                        openResponseTimer = os.clock()
                    else
                        wait(1)
                        openState=0; currentOpen=nil
                        needInventRetry=false
                    end

                elseif timedOut then
                    if not needInventRetry then
                        needInventRetry = true
                        sms('Нет ответа, жду...')
                        sampSendChat('/invent')
                        openResponseTimer = os.clock()
                    else
                        needInventRetry = false
                        sms('Пропускаю: {C0C0C0}'..currentOpen.name)
                        openState=0; currentOpen=nil
                    end
                end
            end
        end
    end
end

function onWindowMessage(msg, wparam, lparam)
    if (msg==0x100 or msg==0x101) and wparam==0x1B
    and (renderWindow[0] or showDatesWindow[0] or showFilterWindow[0])
    and not isPauseMenuActive()
    and not sampIsChatInputActive()
    and not sampIsScoreboardOpen() then
        consumeWindowMessage(true, false)
        if msg==0x101 then
            renderWindow[0]=false
            showDatesWindow[0]=false
            showFilterWindow[0]=false
        end
    end
end

function sms(text)
    sampAddChatMessage('{FF0000}| {FFFFFF}Box Opener {C0C0C0}'..text, 0xFFFFFF)
end

function imgui.DarkTheme()
    imgui.SwitchContext()
    imgui.GetStyle().WindowPadding    = imgui.ImVec2(8,8)
    imgui.GetStyle().FramePadding     = imgui.ImVec2(5,5)
    imgui.GetStyle().ItemSpacing      = imgui.ImVec2(5,5)
    imgui.GetStyle().WindowBorderSize = 0
    imgui.GetStyle().ChildBorderSize  = 1
    imgui.GetStyle().FrameBorderSize  = 1
    imgui.GetStyle().WindowRounding   = 6
    imgui.GetStyle().ChildRounding    = 5
    imgui.GetStyle().FrameRounding    = 5
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5,0.5)
    local c = imgui.GetStyle().Colors
    c[imgui.Col.Text]                 = imgui.ImVec4(1,1,1,1)
    c[imgui.Col.WindowBg]             = imgui.ImVec4(0.07,0.07,0.07,1)
    c[imgui.Col.ChildBg]              = imgui.ImVec4(0.09,0.09,0.09,1)
    c[imgui.Col.FrameBg]              = imgui.ImVec4(0.12,0.12,0.12,1)
    c[imgui.Col.FrameBgHovered]       = imgui.ImVec4(0.22,0.22,0.22,1)
    c[imgui.Col.FrameBgActive]        = imgui.ImVec4(0.28,0.28,0.28,1)
    c[imgui.Col.TitleBg]              = imgui.ImVec4(0.10,0.10,0.10,1)
    c[imgui.Col.TitleBgActive]        = imgui.ImVec4(0.14,0.14,0.14,1)
    c[imgui.Col.Button]               = imgui.ImVec4(0.15,0.15,0.15,1)
    c[imgui.Col.ButtonHovered]        = imgui.ImVec4(0.25,0.25,0.25,1)
    c[imgui.Col.ButtonActive]         = imgui.ImVec4(0.40,0.40,0.40,1)
    c[imgui.Col.CheckMark]            = imgui.ImVec4(0.4,0.9,0.4,1)
    c[imgui.Col.Border]               = imgui.ImVec4(0.25,0.25,0.26,0.54)
    c[imgui.Col.ScrollbarBg]          = imgui.ImVec4(0.10,0.10,0.10,1)
    c[imgui.Col.ScrollbarGrab]        = imgui.ImVec4(0.22,0.22,0.22,1)
    c[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.30,0.30,0.30,1)
    c[imgui.Col.Separator]            = imgui.ImVec4(0.20,0.20,0.20,1)
    c[imgui.Col.Header]               = imgui.ImVec4(0.15,0.15,0.15,1)
    c[imgui.Col.HeaderHovered]        = imgui.ImVec4(0.22,0.22,0.22,1)
end