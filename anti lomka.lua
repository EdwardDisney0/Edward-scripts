	local sp = require("lib.samp.events")
	
function main()
    repeat wait(100) until isSampAvailable()
    sampAddChatMessage("{FF0000}|{FFFFFF}Anti ����� �������� {FF0000}By {00FFFF}Edward", 0xFFFFFF)
end

	function sp.onServerMessage(color, text)
		-- ���������, �������� �� ��������� �������� ����� "�����" � "~~~~~~~"
		if text:find("�����") and text:find("~~~~~~~") then
			-- ���� ������� ���������, ���������� ������� � ���
			sampSendChat("/usedrugs 3")
		end
	end
