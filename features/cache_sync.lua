local Transmog = _G.ChromieTransmog

function Transmog:ChromieDbg(msg)
end

function Transmog:ChromieCacheSyncMaybePrompt()
    if not ChromieTransmogFrame or not ChromieTransmogFrame:IsShown() then
        return false
    end
    if self.chromieVendorOpen or not self.overlayEnabled then
        return false
    end
    if self.ChromieHydrateFromApplied then
        self:ChromieHydrateFromApplied()
    end
    if self.cacheWarnedIncomplete then
        return false
    end
    local char = self:ChromiePersistChar()
    if not char then
        return false
    end
    local needs = false
    local active = self.ChromieActiveUnlockKeys and self:ChromieActiveUnlockKeys() or {}
    local key, entry
    for key, entry in pairs(char.unlocks or {}) do
        if active[key] and (entry.status == "needs_scan" or entry.status == "empty") then
            needs = true
            break
        end
    end
    if needs then
        self.cacheWarnedIncomplete = true
        self:Chat("ChromieTransmog: preview may look wrong until cache is complete. See the Cache tab.")
    end
    return false
end

function Transmog:ChromieCacheSyncStop()
    if self.ChromieSetCacheAbort then
        self:ChromieSetCacheAbort()
    end
end

function Transmog:ChromieCacheSyncIsBlocking()
    return self.chromieJob == "load"
end

function Transmog:ChromieCacheSyncHidePanel()
end
