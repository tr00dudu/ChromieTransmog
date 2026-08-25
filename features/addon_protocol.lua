local Transmog = _G.ChromieTransmog

-- ChromieCraft has no plus addon protocol. Keep this as a no-op so leftover callers do not whisper the live realm.
function Transmog:aSend(data)
    twfdebug("aSend skipped (ChromieCraft): " .. tostring(data))
end
