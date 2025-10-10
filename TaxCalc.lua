local sampev = require 'samp.events'
local socket_status, socket = pcall(require, 'socket')

local Config = {
    target_message = "Уважаемые игроки, за нарушение РП процесса и несоблюдение правил Вы будете наказаны.",
    time_offset_seconds = 5,
    time_offset_milliseconds = 500,
    author = "Edward"
}

local Colors = {
    RED = "{FF0000}",
    YELLOW = "{FFFF00}",
    CYAN = "{00FFFF}",
    WHITE = "{FFFFFF}"
}

local TimeUtils = {}

function TimeUtils.getCurrentTime()
    if not socket_status then
        return os.date("*t"), 0
    end
    
    local date_table = os.date("*t")
    local timestamp = socket.gettime() * 1000
    local milliseconds = math.floor(timestamp % 1000)
    
    return date_table, milliseconds
end

function TimeUtils.subtractTime(time_table, milliseconds, seconds_offset, ms_offset)
    local result = {
        year = time_table.year,
        month = time_table.month,
        day = time_table.day,
        hour = time_table.hour,
        min = time_table.min,
        sec = time_table.sec
    }
    
    milliseconds = milliseconds - ms_offset
    if milliseconds < 0 then
        milliseconds = milliseconds + 1000
        seconds_offset = seconds_offset + 1
    end
    
    result.sec = result.sec - seconds_offset
    
    while result.sec < 0 do
        result.sec = result.sec + 60
        result.min = result.min - 1
        
        if result.min < 0 then
            result.min = result.min + 60
            result.hour = result.hour - 1
            
            if result.hour < 0 then
                result.hour = result.hour + 24
            end
        end
    end
    
    return result, milliseconds
end

function TimeUtils.formatTime(seconds, milliseconds)
    return string.format("%02d.%03d", seconds, milliseconds)
end

local MessageHandler = {}

function MessageHandler.isTargetMessage(message)
    return message == Config.target_message
end

function MessageHandler.createTimeMessage()
    local current_time, milliseconds = TimeUtils.getCurrentTime()
    local adjusted_time, adjusted_milliseconds = TimeUtils.subtractTime(
        current_time, 
        milliseconds, 
        Config.time_offset_seconds, 
        Config.time_offset_milliseconds
    )
    local formatted_time = TimeUtils.formatTime(adjusted_time.sec, adjusted_milliseconds)
    
    return string.format(
        "%s| %sВремя: %s %sBy %s%s",
        Colors.RED,
        Colors.YELLOW,
        formatted_time,
        Colors.RED,
        Colors.CYAN,
        Config.author
    )
end

function MessageHandler.processTargetMessage()
    local message = MessageHandler.createTimeMessage()
    sampAddChatMessage(message, -1)
end

function sampev.onServerMessage(color, message)
    if MessageHandler.isTargetMessage(message) then
        MessageHandler.processTargetMessage()
    end
end

if not socket_status then
    sampAddChatMessage(Colors.YELLOW .. "Предупреждение: модуль socket недоступен, миллисекунды будут равны 0", -1)
end