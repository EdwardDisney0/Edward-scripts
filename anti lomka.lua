	local sp = require("lib.samp.events")
	
function main()
    repeat wait(100) until isSampAvailable()
    sampAddChatMessage("{FF0000}|{FFFFFF}Anti Ломка Загружен {FF0000}By {00FFFF}Edward", 0xFFFFFF)
end

	function sp.onServerMessage(color, text)
		-- Проверяем, содержит ли сообщение ключевые слова "ломка" и "~~~~~~~"
		if text:find("ломка") and text:find("~~~~~~~") then
			-- Если условия выполнены, отправляем команду в чат
			sampSendChat("/usedrugs 3")
		end
	end
