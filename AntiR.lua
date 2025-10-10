function onReceivePacket(id, bs)
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        if raknetBitStreamReadInt8(bs) == 17 then
            raknetBitStreamIgnoreBits(bs, 32)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            local text = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
            
            if text:find("event.setActiveView") and text:find("InteractionMenu") then
                local str = "radialMenu.closeMenu"
                local bs = raknetNewBitStream()
                raknetBitStreamWriteInt8(bs, 220)
                raknetBitStreamWriteInt8(bs, 18)
                raknetBitStreamWriteInt8(bs, string.len(str))
                raknetBitStreamWriteInt8(bs, 0)
                raknetBitStreamWriteString(bs, str)
                raknetBitStreamWriteInt8(bs, 1)
                raknetBitStreamWriteInt8(bs, 0)
                raknetBitStreamWriteInt8(bs, 0)
                raknetBitStreamWriteInt8(bs, 0)
                raknetSendBitStreamEx(bs, 2, 9, 6)
                return false, nil, nil
            end
        end
    end
end
