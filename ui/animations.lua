local Transmog = _G.ChromieTransmog
Transmog.slotGlowFrames = {}

-- Returns the native glow frame associated with an equipment slot.
function Transmog:GetSlotGlowFrame(slotName)
    local glow = self.slotGlowFrames[slotName]
    if glow then
        return glow
    end

    local anchor = getglobal(slotName)
    if not anchor then
        return nil
    end

    glow = CreateFrame("Frame", "Transmog" .. slotName .. "SlotGlow", anchor, "AutoCastShineTemplate")
    glow:SetFrameStrata("HIGH")
    glow:SetWidth(30)
    glow:SetHeight(30)
    glow:SetPoint("CENTER", anchor, "CENTER", -3, 2)
    glow:Hide()

    self.slotGlowFrames[slotName] = glow
    return glow
end

-- Shows the gold native glow for an active or modified equipment slot.
function Transmog:ShowSlotGlow(slotName)
    local glow = self:GetSlotGlowFrame(slotName)
    if glow then
        AutoCastShine_AutoCastStart(glow, 1, 0.82, 0.1)
        glow:Show()
    end
end

-- Hides the native glow for one equipment slot.
function Transmog:HideSlotGlow(slotName)
    local glow = self.slotGlowFrames[slotName]
    if glow then
        AutoCastShine_AutoCastStop(glow)
        glow:Hide()
    end
end

-- Updates the native glow from the local/server transmog state.
function Transmog:UpdateSlotGlow(slotName, slotId)
    local serverItem = self.transmogStatusFromServer[slotId]
    local localItem = self.transmogStatusToServer[slotId]
    if serverItem ~= nil and localItem ~= nil and serverItem ~= localItem then
        self:ShowSlotGlow(slotName)
    else
        self:HideSlotGlow(slotName)
    end
end

-- Reconciles all equipment-slot glows with pending transmog changes.
function Transmog:RefreshPendingGlows()
    for slotName, slotId in pairs(self.inventorySlots) do
        self:UpdateSlotGlow(slotName, slotId)
    end
end


-- Queues a slot for the apply/reset animation sequence.
function Transmog:ChromieInitItemAnimFrame(entry)
    if not entry then
        return
    end
    if entry.autocast then
        entry.autocast:Hide()
    end
    if entry.reset then
        entry.borderFull:Show()
        entry.borderFull:SetAlpha(.9)
        entry.borderHi:Show()
        entry.borderHi:SetWidth(48)
        entry.borderHi:SetHeight(48)
    else
        entry.borderFull:Show()
        entry.borderFull:SetAlpha(.2)
        entry.borderHi:Show()
        entry.borderHi:SetWidth(32)
        entry.borderHi:SetHeight(32)
    end
end

function Transmog:addTransmogAnim(id, reset, hold)
	twfdebug("addTransmogAnim id: "..id)

    for slotName, InventorySlotId in pairs(self.inventorySlots) do
        if id == InventorySlotId then
            local frame = getglobal(slotName)
            if frame then
                local entry = {
                    ['frame'] = frame,
                    ['borderHi'] = getglobal(frame:GetName() .. "BorderHi"),
                    ['borderFull'] = getglobal(frame:GetName() .. "BorderFull"),
                    ['autocast'] = getglobal(frame:GetName() .. "AutoCast"),
                    ['reset'] = reset,
                    ['dir'] = 1
                }
                table.insert(self.itemAnimationFrames, entry)
                if not hold then
                    self:ChromieInitItemAnimFrame(entry)
                end
                break
            end
        end
    end

    if not hold then
        self.itemAnimation:Show()
    end
end

function Transmog:ChromieStartItemAnim()
    local i = 1
    while self.itemAnimationFrames[i] do
        self:ChromieInitItemAnimFrame(self.itemAnimationFrames[i])
        i = i + 1
    end
    if self.itemAnimationFrames[1] then
        self.itemAnimation:Show()
    end
end

-- Hides autocast animation overlays on all equipment slots.
function Transmog:HidePlayerItemsAnimation()
    HeadSlotAutoCast:Hide()
    ShoulderSlotAutoCast:Hide()
    BackSlotAutoCast:Hide()
    ChestSlotAutoCast:Hide()
    WristSlotAutoCast:Hide()
    HandsSlotAutoCast:Hide()
    WaistSlotAutoCast:Hide()
    LegsSlotAutoCast:Hide()
    FeetSlotAutoCast:Hide()
    MainHandSlotAutoCast:Hide()
    SecondaryHandSlotAutoCast:Hide()
    RangedSlotAutoCast:Hide()
    self:RefreshPendingGlows()
end

-- Hides selection borders while retaining state-based pending glows.
function Transmog:hidePlayerItemsBorders()
    HeadSlotBorderSelected:Hide()
    ShoulderSlotBorderSelected:Hide()
    BackSlotBorderSelected:Hide()
    ChestSlotBorderSelected:Hide()
    WristSlotBorderSelected:Hide()
    HandsSlotBorderSelected:Hide()
    WaistSlotBorderSelected:Hide()
    LegsSlotBorderSelected:Hide()
    FeetSlotBorderSelected:Hide()
    MainHandSlotBorderSelected:Hide()
    SecondaryHandSlotBorderSelected:Hide()
    RangedSlotBorderSelected:Hide()
    self:RefreshPendingGlows()
end

-- Disables and desaturates all player equipment slots during gear changes.
function Transmog:LockPlayerItems()
    for slot, _ in pairs(Transmog.inventorySlots) do
        getglobal(slot):Disable()
        SetDesaturation(getglobal(slot .. 'ItemIcon'), 1);
    end
end

Transmog.itemAnimation = CreateFrame("Frame")
Transmog.itemAnimation:Hide()

Transmog.itemAnimation:SetScript("OnShow", function()
    this.startTime = GetTime()
    local i = 1
    while Transmog.itemAnimationFrames[i] do
        Transmog:ChromieInitItemAnimFrame(Transmog.itemAnimationFrames[i])
        i = i + 1
    end
end)
Transmog.itemAnimation:SetScript("OnHide", function()
    Transmog:calculateCost()
end)

Transmog.itemAnimationFrames = {}

Transmog.itemAnimation:SetScript("OnUpdate", function()
    local plus = 0.01
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then

        local i = 1
        while Transmog.itemAnimationFrames[i] do
            local frame = Transmog.itemAnimationFrames[i]
            if frame.reset then
                frame.borderFull:SetAlpha(frame.borderFull:GetAlpha() - 0.05)
                if frame.borderHi:GetWidth() > 32 then
                    frame.borderHi:SetWidth(frame.borderHi:GetWidth() - 0.5)
                    frame.borderHi:SetHeight(frame.borderHi:GetHeight() - 0.5)
                end
            else
                frame.borderFull:SetAlpha(frame.borderFull:GetAlpha() + 0.05 * frame.dir)
                if frame.borderHi:GetWidth() < 48 then
                    frame.borderHi:SetWidth(frame.borderHi:GetWidth() + 0.5)
                    frame.borderHi:SetHeight(frame.borderHi:GetHeight() + 0.5)
                end
            end
            if frame.borderFull:GetAlpha() >= 1 then
                frame.dir = -1
            end
            if frame.borderFull:GetAlpha() <= 0.1 then
                frame.borderHi:SetWidth(48)
                frame.borderHi:SetHeight(48)
                if frame.reset then
                    frame.borderHi:Hide()
                else
                    frame.borderHi:Show()
                end
                table.remove(Transmog.itemAnimationFrames, i)
            else
                i = i + 1
            end
        end

        if not Transmog.itemAnimationFrames[1] then
            Transmog.itemAnimation:Hide()
            if Transmog.transmogStatus then
                Transmog:transmogStatus()
            end
        end

        this.startTime = GetTime()

    end
end)

Transmog.delayedLoad = CreateFrame("Frame")
Transmog.delayedLoad:Hide()

Transmog.delayedLoad:SetScript("OnShow", function()
    twfdebug("delayedLoad show")
    this.startTime = GetTime()
end)
Transmog.delayedLoad:SetScript("OnHide", function()
    Transmog:LoadOnce()
    Transmog:Reset(true)
end)

Transmog.delayedLoad:SetScript("OnUpdate", function()
    local gt = GetTime() * 1000
    local st = (this.startTime + 1) * 1000
    if gt >= st then
        Transmog.delayedLoad:Hide()
    end
end)

Transmog.gearChangedDelay = CreateFrame("Frame")
Transmog.gearChangedDelay:Hide()
Transmog.gearChangedDelay.delay = 1

Transmog.gearChangedDelay:SetScript("OnShow", function()
    this.startTime = GetTime()
end)
Transmog.gearChangedDelay:SetScript("OnUpdate", function()
    local gt = GetTime() * 1000
    local st = (this.startTime + Transmog.gearChangedDelay.delay) * 1000
    if gt >= st then

        selectTransmogSlot(-1)
        Transmog_revert()
        if Transmog.ChromieOwnedOnGearChanged then
            Transmog:ChromieOwnedOnGearChanged()
        end
        Transmog.gearChangedDelay:Hide()
    end
end)
