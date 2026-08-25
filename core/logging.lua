local Transmog = _G.Transmog
local GAME_YELLOW = "|cffffd200"

-- Prints a formatted error message to the default chat frame.
function twferror(a)
    DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[TWFError]:|cffffffff ' .. a .. '. Please report.')
end

-- Prints a formatted message to the default chat frame.
function twfprint(a)
    if a == nil then
        twferror('Attempt to print a nil value.')
        return false
    end
    DEFAULT_CHAT_FRAME:AddMessage(GAME_YELLOW .. a)
end

-- Prints a debug message when Transmog.debug is enabled.
function twfdebug(a)
    if not Transmog.debug then
        return
    end
    if type(a) == 'boolean' then
        if a then
            twfprint('|cff0070de[DEBUG]|cffffffff[true]')
        else
            twfprint('|cff0070de[DEBUG]|cffffffff[false]')
        end
        return true
    end
    twfprint('|cff0070de[DEBUG:' .. GetTime() .. ']|cffffffff[' .. a .. ']')
end
