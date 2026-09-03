local Transmog = _G.ChromieTransmog

local MAX_LOG = 50000
local PROBE_TIMEOUT = 1.5

function Transmog:ChromieLogActive()
    if self.CHAT_TO_WINDOW == 1 then
        return true
    end
    return self.probeActive or self.logEnabled
end

function Transmog:ChromieLogShow()
    if not self.logFrame then
        self:ChromieLogCreate()
    end
    self.logFrame:Show()
end

function Transmog:ChromieLogCreate()
    local f = CreateFrame("Frame", "ChromieTransmogLogFrame", UIParent)
    f:SetWidth(430)
    f:SetHeight(420)
    f:SetPoint("LEFT", UIParent, "CENTER", 280, 0)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
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
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -14)
    title:SetText("ChromieTransmog log")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -4)
    hint:SetText("Clear first. Click text, Ctrl+A, Ctrl+C. Don't delete in the box.")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local clear = CreateFrame("Button", "ChromieTransmogLogClear", f, "UIPanelButtonTemplate")
    clear:SetWidth(70)
    clear:SetHeight(20)
    clear:SetPoint("TOPLEFT", 14, -14)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function()
        Transmog:ChromieLogClear()
    end)

    local scroll = CreateFrame("ScrollFrame", "ChromieTransmogLogScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -58)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)

    local edit = CreateFrame("EditBox", "ChromieTransmogLogEdit", scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetWidth(360)
    edit:SetMaxLetters(MAX_LOG)
    edit:SetText("")
    edit:EnableKeyboard(false)
    edit:SetScript("OnEscapePressed", function()
        this:ClearFocus()
        this:EnableKeyboard(false)
    end)
    edit:SetScript("OnEnterPressed", function()
        this:ClearFocus()
        this:EnableKeyboard(false)
    end)
    edit:SetScript("OnMouseDown", function()
        this:EnableKeyboard(true)
        this:SetFocus()
        this:HighlightText()
    end)
    edit:SetScript("OnEditFocusLost", function()
        this:EnableKeyboard(false)
        this:HighlightText(0, 0)
    end)
    edit:SetScript("OnTextChanged", function()
        local scrollFrame = ChromieTransmogLogScroll
        if scrollFrame then
            scrollFrame:UpdateScrollChildRect()
        end
    end)
    scroll:SetScrollChild(edit)

    self.logFrame = f
    self.logEdit = edit
    self.logText = self.logText or ""
    if self.logText ~= "" then
        edit:SetText(self.logText)
    end
end

function Transmog:ChromieLogClear()
    self.logText = ""
    if self.logEdit then
        self.logEdit:SetText("")
    end
    local scroll = ChromieTransmogLogScroll
    if scroll then
        if scroll.SetVerticalScroll then
            scroll:SetVerticalScroll(0)
        end
        if scroll.UpdateScrollChildRect then
            scroll:UpdateScrollChildRect()
        end
    end
    self:ChromieLog("log cleared")
end

function Transmog:ChromieLog(line, force)
    if not force and not self:ChromieLogActive() then
        return
    end
    if not self.logEdit then
        self:ChromieLogCreate()
    end
    local stamp = string.format("%.2f", GetTime())
    local row = "[" .. stamp .. "] " .. tostring(line)
    self.logText = (self.logText or "") .. row .. "\n"
    if string.len(self.logText) > MAX_LOG then
        self.logText = string.sub(self.logText, string.len(self.logText) - MAX_LOG + 1)
    end
    self.logEdit:SetText(self.logText)
    local scroll = ChromieTransmogLogScroll
    if scroll and scroll.SetVerticalScroll then
        local max = 0
        if scroll.GetVerticalScrollRange then
            max = scroll:GetVerticalScrollRange() or 0
        end
        scroll:SetVerticalScroll(max)
    end
end

function Transmog:ChromieSafe(fn, fallback)
    local ok, a, b, c, d, e = pcall(fn)
    if not ok then
        return fallback, "err:" .. tostring(a)
    end
    return a, b, c, d, e
end

function Transmog:ChromieLogSnapshot(reason)
    if self.chromieJob == "cache-sync" and not self.probeActive then
        return
    end
    if not self.probeActive and not self.logEnabled then
        return
    end
    self:ChromieLog("--- " .. tostring(reason) .. " ---")
    self:ChromieLog("job=" .. tostring(self.chromieJob) .. " probe=" .. tostring(self.probeActive) .. " overlay=" .. tostring(self.overlayEnabled))
    self:ChromieLog("npc=" .. tostring(UnitName("npc") or UnitName("target")) .. " existsNpc=" .. tostring(UnitExists("npc")))
    local idA, guid, idB, idC = self:ChromieNpcId()
    self:ChromieLog("guid=" .. tostring(guid) .. " id=" .. tostring(idA) .. "/" .. tostring(idB) .. "/" .. tostring(idC))
    self:ChromieLog("GossipFrame=" .. tostring(GossipFrame and GossipFrame:IsShown()) .. " MerchantFrame=" .. tostring(MerchantFrame and MerchantFrame:IsShown()))

    local gossipText = self:ChromieSafe(function()
        return GetGossipText()
    end, "")
    if gossipText and gossipText ~= "" then
        gossipText = string.gsub(gossipText, "\n", " ")
        if string.len(gossipText) > 180 then
            gossipText = string.sub(gossipText, 1, 180) .. "..."
        end
        self:ChromieLog("gossipText=" .. gossipText)
    end

    local nAvail = 0
    local nActive = 0
    if GetNumGossipAvailableQuests then
        nAvail = GetNumGossipAvailableQuests() or 0
    end
    if GetNumGossipActiveQuests then
        nActive = GetNumGossipActiveQuests() or 0
    end
    self:ChromieLog("quests available=" .. nAvail .. " active=" .. nActive)

    local options = self:ChromieGetOptions()
    self:ChromieLog("gossipOptions=" .. self:tableSize(options) .. " slotCount=" .. self:ChromieCountSlots(options))
    local i = 1
    while options[i] do
        local opt = options[i]
        local flags = self:ChromieOptionFlags(opt)
        local flagStr = ""
        if flags.slot then
            flagStr = flagStr .. " slot=" .. flags.slot
        end
        if flags.item then
            flagStr = flagStr .. " ITEM"
        end
        if flags.next then
            flagStr = flagStr .. " NEXT"
        end
        if flags.prev then
            flagStr = flagStr .. " PREV"
        end
        if flags.back then
            flagStr = flagStr .. " BACK"
        end
        if flags.search then
            flagStr = flagStr .. " SEARCH"
        end
        if flags.hide then
            flagStr = flagStr .. " HIDE"
        end
        if flags.remove then
            flagStr = flagStr .. " REMOVE"
        end
        if flags.manageSets then
            flagStr = flagStr .. " MANAGESETS"
        end
        if flags.saveSet then
            flagStr = flagStr .. " SAVESET"
        end
        if flags.useSet then
            flagStr = flagStr .. " USESET"
        end
        if flags.deleteSet then
            flagStr = flagStr .. " DELETESET"
        end
        if flags.howSets then
            flagStr = flagStr .. " HOWSETS"
        end
        if flags.nav then
            flagStr = flagStr .. " NAV"
        end
        local raw = opt.text or ""
        if string.len(raw) > 160 then
            raw = string.sub(raw, 1, 160) .. "..."
        end
        self:ChromieLog("  opt[" .. opt.index .. "] kind=" .. tostring(opt.kind) .. " itemId=" .. tostring(opt.itemId) .. flagStr)
        self:ChromieLog("    stripped=" .. tostring(opt.stripped))
        self:ChromieLog("    raw=" .. raw)
        i = i + 1
    end

    local merchantN = self:ChromieSafe(function()
        return GetMerchantNumItems() or 0
    end, 0)
    self:ChromieLog("merchantItems=" .. tostring(merchantN) .. " vendorOpen=" .. tostring(self.chromieVendorOpen))
    i = 1
    while type(merchantN) == "number" and i <= merchantN and i <= 25 do
        local link = self:ChromieSafe(function()
            return GetMerchantItemLink(i)
        end, nil)
        local name, price, isUsable
        local ok, a, b, c, d, e, f = pcall(GetMerchantItemInfo, i)
        if ok then
            name, price, isUsable = a, c, f
        else
            name = "err:" .. tostring(a)
        end
        local id = link and tonumber(string.match(link, "item:(%d+)"))
        self:ChromieLog("  merch[" .. i .. "] id=" .. tostring(id) .. " price=" .. tostring(price) .. " usable=" .. tostring(isUsable) .. " name=" .. tostring(name) .. " link=" .. tostring(link))
        i = i + 1
    end
    if type(merchantN) == "number" and merchantN > 25 then
        self:ChromieLog("  ... " .. (merchantN - 25) .. " more merchant items")
    end

    if StaticPopup1 and StaticPopup1:IsShown() then
        self:ChromieLog("StaticPopup1 which=" .. tostring(StaticPopup1.which) .. " text=" .. tostring(StaticPopup1.text and StaticPopup1.text:GetText()))
    end
end

function Transmog:ChromieProbeSkip(opt)
    if not opt then
        return true, "nil"
    end
    local flags = self:ChromieOptionFlags(opt)
    if flags.item then
        return true, "item-hyperlink (would APPLY transmog)"
    end
    if flags.search then
        return true, "search popup"
    end
    if flags.remove then
        return true, "remove (destructive)"
    end
    if flags.hide then
        return true, "hide (would APPLY)"
    end
    return false
end

function Transmog:ChromieProbeStop(reason)
    self.probeActive = false
    self.probeWaiting = nil
    self.probeWaitKind = nil
    if self.probeTimer then
        self.probeTimer:Hide()
    end
    if self.chromieJob == "probe" then
        self.chromieJob = "open"
    end
    self:ChromieLog("=== PROBE STOP: " .. tostring(reason) .. " ===")
    self:Chat("Probe stopped: " .. tostring(reason))
end

function Transmog:ChromieProbeEnsureTimer()
    if self.probeTimer then
        return
    end
    local t = CreateFrame("Frame")
    t:Hide()
    t:SetScript("OnUpdate", function()
        local owner = Transmog
        if not owner.probeWaiting then
            this:Hide()
            return
        end
        if GetTime() >= (owner.probeDeadline or 0) then
            owner.probeWaiting = nil
            this:Hide()
            owner:ChromieLog("TIMEOUT waiting for " .. tostring(owner.probeWaitKind))
            owner:ChromieLogSnapshot("timeout-poll")
            owner:ChromieProbeAfterResult("timeout")
        end
    end)
    self.probeTimer = t
end

function Transmog:ChromieProbeWait(kind)
    self.probeWaiting = true
    self.probeWaitKind = kind
    self.probeDeadline = GetTime() + PROBE_TIMEOUT
    self:ChromieProbeEnsureTimer()
    self.probeTimer:Show()
end

function Transmog:ChromieProbeGotEvent(kind)
    if not self.probeActive then
        return
    end
    if not self.probeWaiting then
        self:ChromieLog("event " .. tostring(kind) .. " while probe not waiting")
        return
    end
    self.probeWaiting = nil
    if self.probeTimer then
        self.probeTimer:Hide()
    end
    self:ChromieProbeAfterResult(kind)
end

function Transmog:ChromieProbeClickBack()
    local options = self:ChromieGetOptions()
    local i = 1
    while options[i] do
        local flags = self:ChromieOptionFlags(options[i])
        if flags.back then
            self:ChromieLog("probe clicking BACK option " .. options[i].index)
            self:ChromieProbeWait("back")
            SelectGossipOption(options[i].index)
            return true
        end
        i = i + 1
    end
    return false
end

function Transmog:ChromieProbeAfterResult(kind)
    self:ChromieLog("probe result=" .. tostring(kind) .. " afterClick=" .. tostring(self.probeClicked))
    self:ChromieLogSnapshot("after-" .. tostring(kind))

    if kind == "merchant" or kind == "closed" then
        local merchantN = GetMerchantNumItems and (GetMerchantNumItems() or 0) or 0
        if kind == "merchant" or merchantN > 0 or (MerchantFrame and MerchantFrame:IsShown()) then
            self:ChromieLog("vendor session detected; not buying. Closing merchant to try returning to gossip.")
            if CloseMerchant then
                CloseMerchant()
            end
            self.probePhase = "after-vendor"
            self:ChromieProbeWait("after-vendor")
            return
        end
        if kind == "closed" then
            self:ChromieProbeStop("gossip closed after click (session ended)")
            return
        end
    end

    local options = self:ChromieGetOptions()
    local slots = self:ChromieCountSlots(options)
    if slots >= 3 then
        self.probeIndex = (self.probeClicked or self.probeIndex or 1) + 1
        self.probePhase = "main"
        self:ChromieProbeTick()
        return
    end

    if self:ChromieProbeClickBack() then
        self.probePhase = "back"
        return
    end

    self:ChromieLog("no BACK option and not on main menu; advancing index anyway")
    self.probeIndex = (self.probeClicked or self.probeIndex or 1) + 1
    self:ChromieProbeTick()
end

function Transmog:ChromieProbeTick()
    if not self.probeActive then
        return
    end
    if not UnitExists("npc") then
        self:ChromieProbeStop("NPC conversation ended — click the Warpweaver again, then /ct probe")
        return
    end

    local options = self:ChromieGetOptions()
    local n = self:tableSize(options)
    self:ChromieLog("probe tick index=" .. tostring(self.probeIndex) .. " options=" .. n)

    if n == 0 then
        self:ChromieLogSnapshot("probe-empty-options")
        self:ChromieProbeStop("no gossip options (maybe vendor-only page)")
        return
    end

    while self.probeIndex and self.probeIndex <= n do
        local opt = options[self.probeIndex]
        local skip, why = self:ChromieProbeSkip(opt)
        if skip then
            self:ChromieLog("skip opt[" .. self.probeIndex .. "] " .. tostring(opt and opt.stripped) .. " reason=" .. tostring(why))
            self.probeIndex = self.probeIndex + 1
        else
            self.probeClicked = self.probeIndex
            self:ChromieLog("CLICK opt[" .. self.probeIndex .. "] " .. tostring(opt.stripped))
            self:ChromieProbeWait("click")
            SelectGossipOption(self.probeIndex)
            return
        end
    end

    self:ChromieProbeStop("all gossip options walked")
end

function Transmog:ChromieProbeStart()
    self:ChromieLogShow()
    self:Chat("Probe: overlay left as-is. Talk to Warpweaver first, then /ctprobe. Use Clear, then copy with Ctrl+A / Ctrl+C.")
    local ok, err = pcall(function()
        Transmog.probeActive = true
        Transmog.probeIndex = 1
        Transmog.probeClicked = nil
        Transmog.probePhase = "main"
        Transmog.chromieJob = "probe"
        Transmog:ChromieLog("=== PROBE START ===")
        Transmog:ChromieLog("overlay=" .. tostring(Transmog.overlayEnabled) .. " npc=" .. tostring(UnitExists("npc")))
        Transmog:ChromieLog("Will click each non-item gossip option, wait " .. PROBE_TIMEOUT .. "s, dump gossip/vendor, then Back. Will NOT buy/apply appearances.")
        Transmog:ChromieLogSnapshot("probe-start")
        if UnitExists("npc") then
            Transmog:ChromieProbeTick()
        else
            Transmog:Chat("Gossip is not open. Click Warpweaver so the NPC window appears, then type /ctprobe again.")
            Transmog:ChromieLog("waiting: no NPC gossip yet")
        end
    end)
    if not ok then
        self:Chat("Probe error: " .. tostring(err))
    end
end
