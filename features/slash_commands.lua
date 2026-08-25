local Transmog = _G.Transmog

-- Shows the transmog new-appearance alert anchor window.
SLASH_TRANSMOG1 = "/transmog"
SlashCmdList["TRANSMOG"] = function(cmd)
    if cmd then
        Transmog.newTransmogAlert:ShowAnchor()
    end
end

-- Toggles debug mode on/off.
SLASH_TRANSMOGDEBUG1 = "/transmogdebug"
SlashCmdList["TRANSMOGDEBUG"] = function(cmd)
    if cmd then
        if Transmog.debug then
            Transmog.debug = false
            twfprint("Transmog debug off")
        else
            Transmog.debug = true
            twfprint("Transmog debug on")
        end
    end
end

-- Registers TransmogFrame for ESC key handling (we hide GossipFrame and
-- replace it with our own frame, so Blizzard's default ESC logic needs this).
if not UISpecialFrames then
    UISpecialFrames = {}
end
tinsert(UISpecialFrames, "TransmogFrame")
