require 'moonloader'
require 'sampfuncs'
local samp = require 'samp.events'

local enabled = false

function main()
    repeat wait(100) until isSampAvailable()
    sampAddChatMessage("{FF0000}|{FFFFFF}Freeze player {c0c0c0}/freeze {FFFFFF}�������� {FF0000}By {00FFFF}Edward", 0xFFFFFF)
    sampRegisterChatCommand("freeze", toggleFreeze)
end

function toggleFreeze()
    enabled = not enabled
    freezeCharPosition(PLAYER_PED, enabled)
    if enabled then
        sampAddChatMessage("[Freeze player] {FF0000}By {00FFFF}Edward {FFFFFF} ���� ��������� ����������.", 0x00FF00)
    else
        sampAddChatMessage("[Freeze player] {FF0000}By {00FFFF}Edward {FFFFFF} ��������� ���������. �� ������ ��������.", 0xFF0000)
    end
end
