local Transmog = _G.ChromieTransmog
local PREFIX = "|cff69ccf0[ChromieTransmog]|r "

function Transmog:ChatAlways(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

-- kind: "always" (chat regardless of debug), "debug", "verbose", "error"
function Transmog:Print(msg, kind)
    kind = kind or "debug"
    if kind == "always" then
        self:ChatAlways(msg)
        return
    end
    if self.CHAT_PRINTS ~= 1 then
        return
    end
    if kind == "verbose" and self.CHAT_VERBOSE ~= 1 then
        return
    end
    if msg == nil then
        msg = "nil"
        kind = "error"
    end
    local text
    if kind == "verbose" then
        text = "[DEBUG] " .. tostring(msg)
    elseif kind == "error" then
        text = "[ChromieTransmog] " .. tostring(msg) .. ". Please report."
    else
        text = "[ChromieTransmog] " .. tostring(msg)
    end
    if self.CHAT_TO_WINDOW == 1 then
        if self.ChromieLogShow then
            self:ChromieLogShow()
        end
        if self.ChromieLog then
            self:ChromieLog(text, true)
        end
        return
    end
    if kind == "verbose" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[DEBUG]|cffffffff " .. tostring(msg))
    elseif kind == "error" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[ChromieTransmog]|cffffffff " .. tostring(msg) .. ". Please report.")
    else
        self:ChatAlways(msg)
    end
end

function Transmog:Chat(msg)
    self:Print(msg, "debug")
end

function Transmog:SetDebugEnabled(enabled)
    enabled = not not enabled
    self.CHAT_PRINTS = enabled and 1 or 0
    self.debug = enabled
    if not enabled then
        self.CHAT_VERBOSE = 0
        self.debugVerbose = false
        self.CHAT_TO_WINDOW = 0
        self.debugToWindow = false
    end
    self:ChatAlways(enabled and "Debug ON." or "Debug OFF.")
    if self.ChromieSettingsTabSync then
        self:ChromieSettingsTabSync()
    end
end

function Transmog:SetVerboseEnabled(enabled)
    enabled = not not enabled
    if enabled and self.CHAT_PRINTS ~= 1 then
        enabled = false
    end
    self.CHAT_VERBOSE = enabled and 1 or 0
    self.debugVerbose = enabled
    if self.ChromieSettingsTabSync then
        self:ChromieSettingsTabSync()
    end
end

function Transmog:SetLogWindowEnabled(enabled)
    enabled = not not enabled
    if enabled and self.CHAT_PRINTS ~= 1 then
        enabled = false
    end
    self.CHAT_TO_WINDOW = enabled and 1 or 0
    self.debugToWindow = enabled
    if enabled and self.ChromieLogShow then
        self:ChromieLogShow()
    end
    if self.ChromieSettingsTabSync then
        self:ChromieSettingsTabSync()
    end
end

function twferror(a)
    Transmog:Print(a, "error")
end

function twfprint(a)
    Transmog:Print(a, "debug")
    return true
end

function twfdebug(a)
    if type(a) == "boolean" then
        Transmog:Print(a and "true" or "false", "verbose")
        return true
    end
    Transmog:Print(a, "verbose")
end
