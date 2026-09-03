local Transmog = _G.ChromieTransmog

Transmog.LOOK_PREVIEW_STEP = 0.2

local function round1(n)
    n = tonumber(n) or 0
    if n >= 0 then
        return math.floor(n * 10 + 0.5) / 10
    end
    return math.ceil(n * 10 - 0.5) / 10
end

local function fmt1(n)
    return string.format("%.1f", round1(n))
end

function Transmog:ChromieLookPreviewSlot()
    return tonumber(self.currentTransmogSlot)
end

function Transmog:ChromieLookPreviewRace()
    return self.race or "human"
end

-- Old account-wide lookPreview[slot] = {z,x,y} → lookPreview[race][slot].
function Transmog:ChromieLookPreviewMigrate(db)
    if not db then
        return
    end
    local old = {}
    local key, val
    for key, val in pairs(db) do
        local slot = tonumber(key)
        if slot and type(val) == "table" and val.z ~= nil then
            old[slot] = val
        end
    end
    local slot
    local moved = false
    for slot in pairs(old) do
        moved = true
        break
    end
    if not moved then
        return
    end
    local race = self:ChromieLookPreviewRace()
    if type(db[race]) ~= "table" then
        db[race] = {}
    end
    for slot, val in pairs(old) do
        if not db[race][slot] then
            db[race][slot] = val
        end
        db[slot] = nil
    end
end

function Transmog:ChromieLookPreviewTweak(slot)
    slot = tonumber(slot) or self:ChromieLookPreviewSlot()
    self:ChromieEnsurePersistDB()
    local db = ChromieTransmogDB.lookPreview
    if not db or type(db.z) == "number" then
        ChromieTransmogDB.lookPreview = {}
        db = ChromieTransmogDB.lookPreview
    end
    self:ChromieLookPreviewMigrate(db)
    if not slot then
        return { z = 0, x = 0, y = 0 }
    end
    local race = self:ChromieLookPreviewRace()
    if not db[race] then
        db[race] = {}
    end
    if not db[race][slot] then
        db[race][slot] = { z = 0, x = 0, y = 0 }
    end
    local p = db[race][slot]
    p.z = round1(p.z)
    p.x = round1(p.x)
    p.y = round1(p.y)
    return p
end

-- Default race/slot camera plus saved offsets. Stores the untweaked camera
-- on the model so +/- can update live without re-dressing.
function Transmog:ChromieLookSetPosition(model, z, x, y)
    if not model then
        return
    end
    local slot = self:ChromieLookPreviewSlot()
    model.chromieLookCam = { z = z, x = x, y = y, slot = slot }
    local t = self:ChromieLookPreviewTweak(slot)
    model:SetPosition(z + t.z, x + t.x, y + t.y)
end

function Transmog:ChromieLookPreviewApplyVisible()
    local slot = self:ChromieLookPreviewSlot()
    local t = self:ChromieLookPreviewTweak(slot)
    local i = 1
    while self.ItemButtons and self.ItemButtons[i] do
        local btn = self.ItemButtons[i]
        if btn:IsShown() then
            local model = getglobal("TransmogLook" .. i .. "ItemModel")
            local cam = model and model.chromieLookCam
            if cam then
                model:SetPosition(cam.z + t.z, cam.x + t.x, cam.y + t.y)
            end
        end
        i = i + 1
    end
end

function Transmog:ChromieLookPreviewNudge(axis, delta)
    local slot = self:ChromieLookPreviewSlot()
    if not slot then
        return
    end
    local p = self:ChromieLookPreviewTweak(slot)
    p[axis] = round1((tonumber(p[axis]) or 0) + delta)
    self:ChromieLookPreviewApplyVisible()
    self:ChromieLookPreviewRefreshPanel()
end

function Transmog:ChromieLookPreviewReset()
    local slot = self:ChromieLookPreviewSlot()
    if not slot then
        return
    end
    local p = self:ChromieLookPreviewTweak(slot)
    p.z = 0
    p.x = 0
    p.y = 0
    self:ChromieLookPreviewApplyVisible()
    self:ChromieLookPreviewRefreshPanel()
end

local function makeStepper(parent, label, axis, yOff)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(220)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOff)

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", 0, 0)
    name:SetWidth(72)
    name:SetJustifyH("LEFT")
    name:SetText(label)

    local minus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    minus:SetWidth(24)
    minus:SetHeight(22)
    minus:SetPoint("LEFT", name, "RIGHT", 4, 0)
    minus:SetText("-")
    minus:SetScript("OnClick", function()
        Transmog:ChromieLookPreviewNudge(axis, -Transmog.LOOK_PREVIEW_STEP)
    end)

    local val = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    val:SetWidth(40)
    val:SetJustifyH("CENTER")
    row.value = val

    local plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    plus:SetWidth(24)
    plus:SetHeight(22)
    plus:SetPoint("LEFT", val, "RIGHT", 6, 0)
    plus:SetText("+")
    plus:SetScript("OnClick", function()
        Transmog:ChromieLookPreviewNudge(axis, Transmog.LOOK_PREVIEW_STEP)
    end)

    return row
end

local function attachOpenButton(f)
    if f.openBtn then
        return
    end
    local cam = CreateFrame("Button", "ChromieTransmogLookCameraButton", ChromieTransmogFrame, "UIPanelButtonTemplate")
    cam:SetWidth(48)
    cam:SetHeight(20)
    cam:SetPoint("BOTTOMRIGHT", ChromieTransmogFrame, "BOTTOMRIGHT", -30, 12)
    cam:SetFrameLevel((ChromieTransmogFrame:GetFrameLevel() or 1) + 6)
    cam:SetText("Adjust")
    cam:SetScript("OnClick", function()
        Transmog:ChromieLookPreviewToggle()
    end)
    if AddButtonOnEnterTextTooltip then
        AddButtonOnEnterTextTooltip(cam, "Adjust camera", "Tweak 3D look zoom if your resolution crops helm/boots.")
    end
    cam:Hide()
    f.openBtn = cam
end

function Transmog:ChromieLookPreviewEnsure()
    if self.lookPreviewFrame then
        attachOpenButton(self.lookPreviewFrame)
        return self.lookPreviewFrame
    end

    local f = CreateFrame("Frame", "ChromieTransmogLookPreview", UIParent)
    f:SetWidth(260)
    f:SetHeight(204)
    f:SetPoint("CENTER", UIParent, "CENTER", 280, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Adjust camera")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -32)
    hint:SetWidth(228)
    hint:SetJustifyH("LEFT")
    hint:SetNonSpaceWrap(true)
    hint:SetText("Saved for this race for individual slots. Click on different slots do adjust them.")

    f.slotLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.slotLabel:SetPoint("TOPLEFT", 16, -58)
    f.slotLabel:SetWidth(228)
    f.slotLabel:SetJustifyH("LEFT")

    f.rowZ = makeStepper(f, "Zoom", "z", -80)
    f.rowX = makeStepper(f, "Left/Right", "x", -108)
    f.rowY = makeStepper(f, "Up/Down", "y", -136)

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetWidth(120)
    reset:SetHeight(22)
    reset:SetPoint("BOTTOMLEFT", 16, 16)
    reset:SetText("Reset slot")
    reset:SetScript("OnClick", function()
        Transmog:ChromieLookPreviewReset()
    end)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    self.lookPreviewFrame = f
    attachOpenButton(f)
    return f
end

function Transmog:ChromieLookPreviewRefreshPanel()
    local f = self.lookPreviewFrame
    if not f then
        return
    end
    local slot = self:ChromieLookPreviewSlot()
    if f.slotLabel then
        if slot then
            local name = self.ChromieSlotLabelShort and self:ChromieSlotLabelShort(slot) or tostring(slot)
            f.slotLabel:SetText(self:ChromieLookPreviewRace() .. " · " .. name)
        else
            f.slotLabel:SetText(self:ChromieLookPreviewRace() .. " · (click a paperdoll slot)")
        end
    end
    local p = self:ChromieLookPreviewTweak(slot)
    if f.rowZ and f.rowZ.value then
        f.rowZ.value:SetText(fmt1(p.z))
    end
    if f.rowX and f.rowX.value then
        f.rowX.value:SetText(fmt1(p.x))
    end
    if f.rowY and f.rowY.value then
        f.rowY.value:SetText(fmt1(p.y))
    end
end

function Transmog:ChromieLookPreviewButtonShow()
    local f = self:ChromieLookPreviewEnsure()
    if f.openBtn then
        f.openBtn:Show()
    end
end

function Transmog:ChromieLookPreviewButtonHide()
    if self.lookPreviewFrame and self.lookPreviewFrame.openBtn then
        self.lookPreviewFrame.openBtn:Hide()
    end
end

function Transmog:ChromieLookPreviewShow()
    local f = self:ChromieLookPreviewEnsure()
    self:ChromieLookPreviewRefreshPanel()
    f:Show()
end

function Transmog:ChromieLookPreviewHide()
    if self.lookPreviewFrame then
        self.lookPreviewFrame:Hide()
    end
end

function Transmog:ChromieLookPreviewToggle()
    self:ChromieLookPreviewEnsure()
    if self.lookPreviewFrame:IsShown() then
        self:ChromieLookPreviewHide()
    else
        self:ChromieLookPreviewShow()
    end
end
