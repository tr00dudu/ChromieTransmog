local Transmog = _G.ChromieTransmog

Transmog.HOME_TAB_CARDS = 4
Transmog.HOME_CARD_W = 108
Transmog.HOME_CARD_GAP = 8
Transmog.HOME_MODEL_W = 80
Transmog.HOME_MODEL_H = 161
Transmog.HOME_MODEL_TOP = 34

function Transmog:ChromieHomeTabEnsure()
    if self.homeTabFrame and (not self.homeTabFrame.nestedModels or not self.homeTabFrame.layoutNameAbove) then
        self.homeTabFrame:SetScript("OnUpdate", nil)
        self.homeTabFrame:Hide()
        self.homeTabFrame = nil
    end
    if self.homeTabFrame then
        return self.homeTabFrame
    end
    local f = CreateFrame("Frame", "ChromieTransmogHomeTab", ChromieTransmogFrame)
    f:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 255, -88)
    f:SetPoint("BOTTOMRIGHT", ChromieTransmogFrame, "BOTTOMRIGHT", -20, 40)
    f:Hide()
    f.nestedModels = true
    f.layoutNameAbove = true

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -4)
    title:SetText("Last used sets")
    f.title = title

    f.cards = {}
    local cardW = self.HOME_CARD_W or 108
    local gap = self.HOME_CARD_GAP or 8
    local modelW = self.HOME_MODEL_W or 80
    local modelH = self.HOME_MODEL_H or 161
    -- Factory so each Apply Set closure captures its own card (Lua 5.1 loop locals).
    local function makeCard(index)
        local cardName = "ChromieTransmogHomeCard" .. index
        local card = CreateFrame("Frame", cardName, f, "ChromieTransmogHomeCardTemplate")
        local modelTop = self.HOME_MODEL_TOP or 34
        card:SetWidth(cardW)
        card:SetHeight(modelTop + modelH + 26)
        card:SetPoint("TOPLEFT", title, "BOTTOMLEFT", (index - 1) * (cardW + gap) - 10, -6)

        local model = getglobal(cardName .. "ItemModel")
        model:ClearAllPoints()
        model:SetWidth(modelW)
        model:SetHeight(modelH)
        model:SetPoint("TOP", card, "TOP", 0, -modelTop)
        card.model = model

        local nameFS = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFS:SetPoint("BOTTOM", model, "TOP", (128 / 2 - 20) - (modelW / 2), 2)
        nameFS:SetWidth(cardW)
        nameFS:SetJustifyH("CENTER")
        if nameFS.SetJustifyV then
            nameFS:SetJustifyV("BOTTOM")
        end
        card.name = nameFS

        local bg = card:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\AddOns\\ChromieTransmog\\assets\\item_bg_normal")
        bg:SetWidth(128)
        bg:SetHeight(180)
        bg:SetPoint("TOPLEFT", model, "TOPLEFT", -20, 0)
        card.bg = bg

        local apply = CreateFrame("Button", "ChromieTransmogHomeApply" .. index, card, "UIPanelButtonTemplate")
        apply:SetWidth(cardW - 30)
        apply:SetHeight(22)
        -- Preview art is 128px, anchored -20 from the 80px model (20 left / 28 right).
        apply:SetPoint("TOP", model, "BOTTOM", (128 / 2 - 20) - (modelW / 2), -10)
        apply:SetText("Apply Set")
        apply:SetScript("OnClick", function()
            if card.setName then
                Transmog_LoadOutfit(nil, card.setName)
            end
        end)
        card.apply = apply
        return card
    end
    local i = 1
    while i <= (self.HOME_TAB_CARDS or 4) do
        f.cards[i] = makeCard(i)
        i = i + 1
    end

    local cacheTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cacheTitle:SetPoint("BOTTOMLEFT", 8, 36)
    cacheTitle:SetText("Cache status")
    f.cacheTitle = cacheTitle

    local cacheStatus = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cacheStatus:SetPoint("TOPLEFT", cacheTitle, "BOTTOMLEFT", 0, -4)
    cacheStatus:SetJustifyH("LEFT")
    f.cacheStatus = cacheStatus

    local cacheBtn = CreateFrame("Button", "ChromieTransmogHomeCacheButton", f, "UIPanelButtonTemplate")
    cacheBtn:SetWidth(70)
    cacheBtn:SetHeight(22)
    cacheBtn:SetPoint("LEFT", cacheStatus, "RIGHT", 8, 0)
    cacheBtn:SetText("Cache")
    cacheBtn:SetScript("OnClick", function()
        Transmog_switchTab("cache")
    end)
    cacheBtn:SetFrameLevel(f:GetFrameLevel() + 4)
    cacheBtn:Hide()
    f.cacheBtn = cacheBtn

    self.homeTabFrame = f
    return f
end

function Transmog:ChromieHomeTabShow()
    local f = self:ChromieHomeTabEnsure()
    f:Show()
    self:ChromieHomeTabPark(false)
    self:ChromieHomeTabRefresh()
end

function Transmog:ChromieHomeTabHide()
    self:ChromieHomeTabPark(true)
end

-- Main window closed: stop dress ticks and actually hide models (parent hide is
-- not enough to clear dressedName; next open would skip a needed rebuild).
function Transmog:ChromieHomeTabShutdown()
    local f = self.homeTabFrame
    if not f then
        return
    end
    f:SetScript("OnUpdate", nil)
    f.homeParked = nil
    local i = 1
    while f.cards and f.cards[i] do
        f.cards[i].dressedName = nil
        i = i + 1
    end
    f:Hide()
end

-- DressUpModel resets on :Hide(). Park off-screen instead so previews stay dressed.
function Transmog:ChromieHomeTabPark(park)
    local f = self.homeTabFrame
    if not f then
        return
    end
    f:ClearAllPoints()
    if park then
        f.homeParked = true
        f:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 4000, 0)
        f:SetPoint("BOTTOMRIGHT", ChromieTransmogFrame, "BOTTOMRIGHT", 4000, 0)
    else
        f.homeParked = nil
        f:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 255, -88)
        f:SetPoint("BOTTOMRIGHT", ChromieTransmogFrame, "BOTTOMRIGHT", -20, 40)
    end
    f:Show()
end

function Transmog:ChromieHomeTabPlaceCard(card, index)
    local f = self.homeTabFrame
    if not f or not card then
        return
    end
    local cardW = self.HOME_CARD_W or 108
    local gap = self.HOME_CARD_GAP or 8
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", (index - 1) * (cardW + gap) - 10, -10)
end

function Transmog:ChromieHomeTabInvalidate(name)
    local f = self.homeTabFrame
    if not f or not f.cards then
        return
    end
    local i = 1
    while f.cards[i] do
        local card = f.cards[i]
        if not name or card.setName == name or card.dressedName == name then
            card.dressedName = nil
        end
        i = i + 1
    end
    if ChromieTransmogFrame and ChromieTransmogFrame:IsShown() then
        self:ChromieHomeTabQueueDress()
    end
end

-- SavedVariables may store slot keys as strings; PreviewRebuild indexes by number.
function Transmog:ChromieHomeTabSetItems(name)
    if not name then
        return nil
    end
    local src = self.chromieSetItems and self.chromieSetItems[name]
    if not src then
        local char = self.ChromiePersistChar and self:ChromiePersistChar()
        src = char and char.sets and char.sets.items and char.sets.items[name]
    end
    if not src then
        return nil
    end
    local items = {}
    local k, v
    for k, v in pairs(src) do
        local slot = tonumber(k)
        local id = tonumber(v)
        if slot then
            items[slot] = id
        end
    end
    return items
end

function Transmog:ChromieHomeTabSlotId(setItems, slot)
    if slot == 1 and self.PreviewShowsHelm and not self:PreviewShowsHelm() then
        return nil
    end
    if slot == 15 and self.PreviewShowsCloak and not self:PreviewShowsCloak() then
        return nil
    end
    local raw = setItems and setItems[slot]
    local id = raw and tonumber(raw)
    if id and id > 1 then
        return id
    end
    return nil
end

function Transmog:ChromieHomeTabQueueDress()
    local f = self.homeTabFrame
    if not f then
        return
    end
    -- SetUnit+Undress now so Show() does not paint current gear for a frame.
    local i = 1
    while f.cards and f.cards[i] do
        local card = f.cards[i]
        if card.model and card.setName and card.dressedName ~= card.setName then
            card.model:SetUnit("player")
            card.model:SetRotation(0.61)
            card.model:Undress()
            local cached = card.setName and self.ChromieSetIsCached and self:ChromieSetIsCached(card.setName)
            card.dressedCached = cached
            if not cached then
                card.dressedName = card.setName
            end
        end
        i = i + 1
    end
    f.homeDressI = 1
    f.homeDressPhase = 1
    f.homeSlotI = 1
    f:SetScript("OnUpdate", function()
        Transmog:ChromieHomeTabDressOnUpdate()
    end)
end

-- One card at a time, one slot per frame (same pacing idea as the item grid).
-- Slot order: shirt/tabard, armor, MH, OH, MH again, ranged.
Transmog.HOME_DRESS_SLOTS = { 4, 19, 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 16, 18 }

function Transmog:ChromieHomeTabNextCard()
    local f = self.homeTabFrame
    if not f then
        return
    end
    f.homeDressI = (f.homeDressI or 1) + 1
    f.homeDressPhase = 1
    f.homeSlotI = 1
end

function Transmog:ChromieHomeTabDressOnUpdate()
    local f = self.homeTabFrame
    if not f or not f.cards then
        return
    end
    local card = f.cards[f.homeDressI]
    while card do
        if not card:IsShown() or not card.setName then
            self:ChromieHomeTabNextCard()
        elseif card.dressedName == card.setName then
            self:ChromieHomeTabNextCard()
        else
            break
        end
        card = f.cards[f.homeDressI]
    end
    if not card then
        f:SetScript("OnUpdate", nil)
        return
    end
    local model = card.model
    if not model then
        self:ChromieHomeTabNextCard()
        return
    end
    -- 0: SetUnit + Undress, 1: one TryOn per frame.
    if f.homeDressPhase == 0 then
        model:SetUnit("player")
        model:SetRotation(0.61)
        local cached = card.setName and self.ChromieSetIsCached and self:ChromieSetIsCached(card.setName)
        model:Undress()
        card.dressedCached = cached
        if not cached then
            card.dressedName = card.setName
            self:ChromieHomeTabNextCard()
            return
        end
        f.homeDressPhase = 1
        f.homeSlotI = 1
    end
    local slots = self.HOME_DRESS_SLOTS or { 4, 19, 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 16, 18 }
    local slot = slots[f.homeSlotI]
    if not slot then
        card.dressedName = card.setName
        self:ChromieHomeTabNextCard()
        return
    end
    f.homeSlotI = (f.homeSlotI or 1) + 1
    local id = self:ChromieHomeTabSlotId(card.dressMap, slot)
    if not id or id <= 1 then
        return
    end
    if self.cacheItem then
        self:cacheItem(id)
    end
    if self.PreviewTryOn then
        self:PreviewTryOn(id, slot, model)
    else
        pcall(function()
            model:TryOn(id)
        end)
        pcall(function()
            model:TryOn("item:" .. id)
        end)
    end
end

function Transmog:ChromieHomeTabRefresh(force)
    local f = self.homeTabFrame
    if not f then
        return
    end
    if self.ChromieCacheTabNeedsAttention and self:ChromieCacheTabNeedsAttention() then
        f.cacheStatus:SetText("NOT OK")
        f.cacheBtn:Show()
    else
        f.cacheStatus:SetText("|cff00ff00Cache OK|r")
        f.cacheBtn:Hide()
    end
    local names = self.ChromieLastUsedList and self:ChromieLastUsedList() or {}
    local max = self.HOME_TAB_CARDS or 4
    local want = {}
    local i = 1
    while i <= max do
        if names[i] then
            want[names[i]] = true
        end
        i = i + 1
    end
    local old = f.cards
    local claimed = {}
    local function claimExact(name)
        local j = 1
        while j <= max do
            local c = old[j]
            if c and not claimed[c] and c.dressedName == name then
                claimed[c] = true
                return c
            end
            j = j + 1
        end
        return nil
    end
    local function claimFree()
        local j = 1
        while j <= max do
            local c = old[j]
            if c and not claimed[c] then
                if not (c.dressedName and want[c.dressedName]) then
                    claimed[c] = true
                    return c
                end
            end
            j = j + 1
        end
        j = 1
        while j <= max do
            local c = old[j]
            if c and not claimed[c] then
                claimed[c] = true
                return c
            end
            j = j + 1
        end
        return nil
    end
    local assigned = {}
    i = 1
    while i <= max do
        local name = names[i]
        if name then
            assigned[i] = claimExact(name)
        end
        i = i + 1
    end
    local needDress = false
    local newCards = {}
    i = 1
    while i <= max do
        local name = names[i]
        local card = assigned[i] or claimFree()
        newCards[i] = card
        if card then
            self:ChromieHomeTabPlaceCard(card, i)
            if name then
                local cached = self.ChromieSetIsCached and self:ChromieSetIsCached(name) and true or false
                if force or card.dressedName ~= name or card.dressedCached ~= cached then
                    card.dressedName = nil
                    needDress = true
                end
                card.setName = name
                card.dressedCached = cached
                card.dressMap = self:ChromieHomeTabSetItems(name)
                card.name:SetText(name)
                card:Show()
            else
                card.setName = nil
                card.dressedName = nil
                card.dressedCached = nil
                card.dressMap = nil
                card.name:SetText("")
                card:Hide()
            end
        end
        i = i + 1
    end
    f.cards = newCards
    if needDress then
        self:ChromieHomeTabQueueDress()
    end
end
