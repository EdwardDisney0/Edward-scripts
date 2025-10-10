require 'moonloader'
require 'sampfuncs'
local samp = require 'samp.events'

local enabled = false

function main()
    repeat wait(100) until isSampAvailable()
    sampAddChatMessage("{FF0000}|{FFFFFF}Freeze player {c0c0c0}/freeze {FFFFFF}Загружен {FF0000}By {00FFFF}Edward", 0xFFFFFF)
    sampRegisterChatCommand("freeze", toggleFreeze)
end

function toggleFreeze()
    enabled = not enabled
    freezeCharPosition(PLAYER_PED, enabled)
    if enabled then
        sampAddChatMessage("[Freeze player] {FF0000}By {00FFFF}Edward {FFFFFF} Ваши персонажи заморожены.", 0x00FF00)
    else
        sampAddChatMessage("[Freeze player] {FF0000}By {00FFFF}Edward {FFFFFF} Заморозка отключена. Вы теперь свободны.", 0xFF0000)
    end
end
