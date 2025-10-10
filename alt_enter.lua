function onWindowMessage(msg, wparam, lparam)
	if msg == 261 and wparam == 13 then consumeWindowMessage(true, true) end
end