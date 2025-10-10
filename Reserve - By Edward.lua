script_name("Deposit Withdraw")
script_author("Edward")
script_version("1.3")

require "lib.moonloader"
local sampev = require "lib.samp.events"

local withdrawing = false
local total_amount = 0
local remaining_amount = 0
local current_balance = 0
local MAX_WITHDRAW = 50000000 
local dialog_step = 0
local alt_thread = nil

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    sampRegisterChatCommand("res", cmd_withdraw)
    sampAddChatMessage("{FF0000}|{FFFFFF} Reserve  загружен {FFFFFF}Используйте {c0c0c0}/res [сумма] {FFFFFF}для снятия. {FF0000}By {00FFFF}Edward", 0x00AA00)
    
    wait(-1)
end

function cmd_withdraw(amount)
    amount = tonumber(amount)
    
    if withdrawing then
        sampAddChatMessage(" {FF0000}|{FFFFFF} Ошибка: {FF6347}Снятие уже выполняется!", 0xFFFFFF)
        return
    end
    
    if not amount then
        sampAddChatMessage(" {FF0000}|{FFFFFF} Использование: /res [сумма]", 0xFFFFFF)
        return
    end
    
    if amount < 1000 then
        sampAddChatMessage(" {FF0000}|{FFFFFF} Минимальная сумма — {FF6347}1000 руб.", 0xFFFFFF)
        return
    end
    
    if amount > 2000000000 then
        sampAddChatMessage(" {FF0000}|{FFFFFF} Максимальная сумма — {FF6347}2 000 000 000 руб.", 0xFFFFFF)
        return
    end
    
    if amount % 1000 ~= 0 then
        sampAddChatMessage(" {FF0000}|{FFFFFF} Сумма должна быть кратна {FF6347}1000!", 0xFFFFFF)
        return
    end
    
    total_amount = amount
    remaining_amount = amount
    withdrawing = true
    dialog_step = 0
    
    local operations = math.ceil(amount / MAX_WITHDRAW)
    sampAddChatMessage(string.format(" {00FF00}|{FFFFFF} Начинаю снятие {00FF00}%s{FFFFFF} руб. ({00FF00}%d{FFFFFF} операций)", 
        formatMoney(amount), operations), 0xFFFFFF)
    
    startAltThread()
end

function startAltThread()
    alt_thread = lua_thread.create(function()
        while withdrawing and dialog_step == 0 do
            wait(200)
            setVirtualKeyDown(0x12, true)
            wait(30)
            setVirtualKeyDown(0x12, false)
            wait(200)
        end
    end)
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if not withdrawing then return end
    
    if id == 704 and dialog_step == 0 then
        dialog_step = 1
        lua_thread.create(function()
            wait(50)
            
            local items_count = sampGetListboxItemsCount()
            local found_index = -1
            
            for i = 0, items_count - 1 do
                local item_text = sampGetListboxItemText(i)
                if item_text:find("Снять с резервного счета") then
                    found_index = i
                    break
                end
            end
            
            if found_index ~= -1 then
                sampSendDialogResponse(704, 1, found_index, nil)
            else
                sampAddChatMessage(" {FF0000}|{FFFFFF} Ошибка: {FF6347}на резервном счете нет средств для снятия!", 0xFFFFFF)
                withdrawing = false
                dialog_step = 0
                sampSendDialogResponse(704, 0, 0, nil)
            end
        end)
        return false
    end
    
    if id == 216 and dialog_step == 1 then
        dialog_step = 2
        
        local balance = text:match("На Вашем резервном счету (%d+) руб")
        if balance then
            current_balance = tonumber(balance)
        else
            sampAddChatMessage(" {FF0000}|{FFFFFF} Ошибка: не удалось определить баланс!", 0xFFFFFF)
            withdrawing = false
            dialog_step = 0
            lua_thread.create(function()
                wait(50)
                sampSendDialogResponse(216, 0, 0, nil)
            end)
            return false
        end
        
        if current_balance < remaining_amount then
            sampAddChatMessage(string.format(" {FF0000}|{FFFFFF} Ошибка: {FF6347}Недостаточно средств на резервном счете!", 0xFFFFFF))
            sampAddChatMessage(string.format(" {FF0000}|{FFFFFF} Запрошено: {FF6347}%s{FFFFFF} руб. | Доступно: {00FF00}%s{FFFFFF} руб.", 
                formatMoney(remaining_amount), formatMoney(current_balance)), 0xFFFFFF)
            withdrawing = false
            dialog_step = 0
            
            lua_thread.create(function()
                wait(50)
                sampSendDialogResponse(216, 0, 0, nil)
            end)
            return false
        end
        
        local withdraw_now = math.min(remaining_amount, MAX_WITHDRAW)
        
        lua_thread.create(function()
            wait(50)
            sampSendDialogResponse(216, 1, 0, tostring(withdraw_now))
            dialog_step = 3 
        end)
        
        return false
    end
end

function onReceivePacket(id, bs)
    if not withdrawing then return end
    
    if id == 220 then
        raknetBitStreamReadInt8(bs)
        if raknetBitStreamReadInt8(bs) == 17 then
            raknetBitStreamReadInt32(bs)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            
            if length > 0 then
                local text = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
                
                if text:find("cef%.addNotification") and text:find('"type":"succeeded"') then
                    if text:find("Вы успешно сняли деньги") or text:find("успешно сняли") then
                        if dialog_step == 3 then
                            local withdraw_amount = math.min(remaining_amount, MAX_WITHDRAW)
                            remaining_amount = remaining_amount - withdraw_amount
                            current_balance = current_balance - withdraw_amount 
                            
                            sampAddChatMessage(string.format(" {00FF00}|{FFFFFF} Снято: {00FF00}%s{FFFFFF} руб. | Осталось: {FFFF00}%s{FFFFFF} руб.", 
                                formatMoney(withdraw_amount), formatMoney(remaining_amount)), 0xFFFFFF)
                            
                            lua_thread.create(function()
                                wait(200)
                                
                                if remaining_amount > 0 then
                                    dialog_step = 0
                                    startAltThread()
                                else
                                    sampAddChatMessage(string.format(" {00FF00}|{FFFFFF} Успешно снято {00FF00}%s{FFFFFF} руб. с резервного счёта!", 
                                        formatMoney(total_amount)), 0xFFFFFF)
                                    sampAddChatMessage(string.format(" {00FF00}|{FFFFFF} Остаток на резервном счете: {00FF00}%s{FFFFFF} руб.", 
                                        formatMoney(current_balance)), 0xFFFFFF)
                                    withdrawing = false
                                    dialog_step = 0
                                end
                            end)
                        end
                    end
                end
                
                if text:find("cef%.addNotification") and text:find('"type":"error"') then
                    if text:find("У Вас нет столько денег") or text:find("нет столько денег") then
                        sampAddChatMessage(" {FF0000}|{FFFFFF} Ошибка: недостаточно средств на резервном счете!", 0xFFFFFF)
                        withdrawing = false
                        dialog_step = 0
                    elseif text:find("На руках нельзя иметь такую сумму") or text:find("нельзя иметь такую сумму") then
                        local withdraw_amount = math.min(remaining_amount, MAX_WITHDRAW)
                        sampAddChatMessage(string.format(" {FF0000}|{FFFFFF} Ошибка: {FF6347}превышен лимит наличных!", 0xFFFFFF))
                        sampAddChatMessage(string.format(" {FF0000}|{FFFFFF} Не удалось снять {FF6347}%s{FFFFFF} руб. из-за лимита наличных на руках!", 
                            formatMoney(withdraw_amount)), 0xFFFFFF)
                        withdrawing = false
                        dialog_step = 0
                    end
                end
            end
        end
    end
end

function sampev.onServerMessage(color, text)
    if withdrawing then
        if text:find("Недостаточно средств") or text:find("нет столько денег") then
            sampAddChatMessage(" {FF0000}|{FFFFFF} Ошибка: недостаточно средств!", 0xFFFFFF)
            withdrawing = false
            dialog_step = 0
        elseif text:find("На руках нельзя иметь") or text:find("нельзя иметь такую сумму") then
            local withdraw_amount = math.min(remaining_amount, MAX_WITHDRAW)
            sampAddChatMessage(string.format(" {FF0000}|{FFFFFF} Не удалось снять {FF6347}%s{FFFFFF} руб. - превышен лимит наличных!", 
                formatMoney(withdraw_amount)), 0xFFFFFF)
            withdrawing = false
            dialog_step = 0
        end
    end
end

function formatMoney(amount)
    local formatted = tostring(amount)
    local k
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
        if k == 0 then break end
    end
    return formatted
end