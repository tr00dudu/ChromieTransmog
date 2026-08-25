local Transmog = _G.Transmog

-- Sends a transmog command to the server via the addon message channel.
function Transmog:aSend(data)
    if self.localCache[data] then
        twfdebug("|cff69ccf0 not send " .. data .. " data cached")
    else
        SendAddonMessage(self.prefix, data, "WHISPER", UnitName("player"))
        twfdebug("|cff69ccf0 send -> " .. data)
    end
end
