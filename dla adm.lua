local lock_control = false
local sampev = require('lib.samp.events')
local cursor_status = false

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if sampIsLocalPlayerSpawned() then
        local data = {
            [1] = 'dialog',
            [2] = {
                primaryButton = button1,
                header = title,
                id = dialogId,
                type = style,
                body = text,
                mode = 0,
                secondaryButton = button2,
            },
        }
        evalcef(("window.executeEvent('cef.modals.showModal', `%s`);"):format(encodeJson(data)))
        cursor(true)
        if lock_control then lockPlayerControl(true) end
        return false
    end
end

function onReceivePacket(id, bs)
    if id == 220 then
        raknetBitStreamReadInt8(bs);
        if raknetBitStreamReadInt8(bs) == 25 then
            raknetBitStreamReadInt32(bs)
            cursor_status = raknetBitStreamReadInt8(bs) == 128
        end
    end
end

function onSendPacket(id, bs, priority, reliability, orderingChannel)
    if id == 220 then
        raknetBitStreamReadInt8(bs)
        if raknetBitStreamReadInt8(bs) == 18 then
            local strlen = raknetBitStreamReadInt16(bs)
            local str = raknetBitStreamReadString(bs, strlen)
            if str:find("sendResponse|%d+|%d+|%d+|.*") then
                local d_id, d_list, d_button, d_str = str:match("sendResponse|(%d+)|(%d+)|(%d+)|(.*)")
                evalcef("window.executeEvent('cef.modals.closeModal', `[\"dialog\"]`);")
                sampSendDialogResponse(tonumber(d_id), tonumber(d_button), tonumber(d_list), d_str)
                if not cursor_status then cursor(false) end
                lockPlayerControl(false)
            end
        end
    end
end

function evalcef(code, encoded)
    encoded = encoded or 0
    local bs = raknetNewBitStream();
    raknetBitStreamWriteInt8(bs, 17);
    raknetBitStreamWriteInt32(bs, 0);
    raknetBitStreamWriteInt16(bs, #code);
    raknetBitStreamWriteInt8(bs, encoded);
    raknetBitStreamWriteString(bs, code);
    raknetEmulPacketReceiveBitStream(220, bs);
    raknetDeleteBitStream(bs);
end

function cursor(toggle)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 25)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt8(bs, toggle and 128 or 0)
    raknetBitStreamWriteInt16(bs, 0)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end