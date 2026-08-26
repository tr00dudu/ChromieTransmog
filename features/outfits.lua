local Transmog = _G.ChromieTransmog

Transmog.CHROMIE_MAX_SETS = 10
Transmog.CHROMIE_MANAGE_SET_ROW_H = 24
Transmog.CHROMIE_MANAGE_SET_ROW_GAP = 2
-- Max row widgets; visible count is measured from the scroll frame height.
Transmog.CHROMIE_MANAGE_SET_ROWS = 12
Transmog.CHROMIE_SETS_DROPDOWN_LABEL = "Quick apply sets"

function Transmog:ChromieManageSetsVisibleRows()
    local f = self.manageSetsFrame
    local step = (self.CHROMIE_MANAGE_SET_ROW_H or 24) + (self.CHROMIE_MANAGE_SET_ROW_GAP or 0)
    local maxRows = self.CHROMIE_MANAGE_SET_ROWS or 12
    local n = 4
    if f and f.scroll then
        local h = f.scroll:GetHeight()
        if h and h > 0 then
            n = math.floor((h + (self.CHROMIE_MANAGE_SET_ROW_GAP or 0)) / step)
        end
    end
    if n < 1 then
        n = 1
    end
    if n > maxRows then
        n = maxRows
    end
    return n
end

-- Populates the sets dropdown from ChromieCraft server presets.
function OutfitsDropDown_Initialize()
    local names = Transmog.chromieSets or {}
    local i = 1
    while names[i] do
        local name = names[i]
        local info = {}
        info.text = name
        info.value = 1
        info.arg1 = name
        info.checked = nil
        info.func = Transmog_LoadOutfit
        info.tooltipTitle = name
        info.tooltipText = "Apply this set immediately. Applying a saved set is free."
        UIDropDownMenu_AddButton(info)
        i = i + 1
    end
end

function Transmog:ChromieSetsDropdownLabel()
    return self.CHROMIE_SETS_DROPDOWN_LABEL or "Quick apply sets"
end

function Transmog:ChromieRefreshSetsDropdown()
    if not ChromieTransmogFrameOutfits then
        return
    end
    UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, self:ChromieSetsDropdownLabel())
end

function Transmog:ChromieHideSetCreate()
    if self.setCreateFrame then
        self.setCreateFrame:Hide()
        if self.setCreateFrame.edit then
            self.setCreateFrame.edit:ClearFocus()
            self.setCreateFrame.edit:SetText("")
        end
    end
    if self.manageSetsFrame and self.manageSetsFrame.edit then
        self.manageSetsFrame.edit:ClearFocus()
        self.manageSetsFrame.edit:SetText("")
    end
end

function Transmog:ChromieClearPendingSet()
    self.chromiePendingSet = nil
end

function Transmog:ChromieDeselectSet()
    self.chromiePendingSet = nil
    self.currentOutfit = nil
    ChromieTransmogFrameSaveOutfit:Hide()
    ChromieTransmogFrameSaveOutfit:Disable()
    if ChromieTransmogFrameOutfits then
        UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, self:ChromieSetsDropdownLabel())
    end
end

function Transmog:ChromieHasSetName(name)
    local names = self.chromieSets or {}
    local i = 1
    while names[i] do
        if names[i] == name then
            return true
        end
        i = i + 1
    end
    return false
end

function Transmog:ChromieAddSetName(name)
    if not name or name == "" or self:ChromieHasSetName(name) then
        return
    end
    if not self.chromieSets then
        self.chromieSets = {}
    end
    table.insert(self.chromieSets, name)
end

function Transmog:ChromieRemoveSetName(name)
    local names = self.chromieSets or {}
    local i = 1
    while names[i] do
        if names[i] == name then
            table.remove(names, i)
            return
        end
        i = i + 1
    end
end

function Transmog:ChromieHasAnyMog()
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        local have = self.transmogStatusFromServer[slot]
        if have and have ~= 0 then
            return true
        end
    end
    return false
end

function Transmog:ChromieHideManageSets()
    self.manageSetsOpen = nil
    self.chromieWantSetPrice = nil
    if self.manageSetsFrame then
        self.manageSetsFrame:Hide()
        if self.manageSetsFrame.edit then
            self.manageSetsFrame.edit:ClearFocus()
        end
    end
end

function Transmog:ChromieEnsureManageSetsFrame()
    if self.manageSetsFrame then
        return self.manageSetsFrame
    end

    local f = CreateFrame("Frame", "ChromieTransmogManageSets", ChromieTransmogFrame)
    f:SetWidth(455)
    f:SetHeight(370)
    f:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 255, -88)
    f:SetFrameLevel(ChromieTransmogFrame:GetFrameLevel() + 6)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -4)
    title:SetText("Manage Sets")

    local how = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    how:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    how:SetWidth(430)
    how:SetJustifyH("LEFT")
    how:SetText("A set stores the transmogs currently applied to your gear (It does not store the pending preview changes). Pick a set from the dropdown to quick apply it. Applying already saved sets from the dropdown is free. Saving or updating a set costs gold.")

    local addLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -14)
    addLabel:SetText("Save current transmogs as a new set")

    local edit = CreateFrame("EditBox", "ChromieTransmogManageSetName", f, "InputBoxTemplate")
    edit:SetWidth(220)
    edit:SetHeight(20)
    edit:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 6, -8)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(50)
    edit:SetScript("OnEnterPressed", function()
        Transmog_ConfirmNewSet()
    end)
    edit:SetScript("OnEscapePressed", function()
        this:ClearFocus()
        this:SetText("")
    end)
    f.edit = edit

    local save = CreateFrame("Button", "ChromieTransmogManageSetSave", f, "UIPanelButtonTemplate")
    save:SetWidth(80)
    save:SetHeight(22)
    save:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    save:SetText("Save")
    save:SetScript("OnClick", function()
        Transmog_ConfirmNewSet()
    end)
    f.save = save

    local cost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cost:SetPoint("LEFT", save, "RIGHT", 8, 0)
    cost:SetText("")
    f.cost = cost

    local listLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -6, -14)
    listLabel:SetText("Saved sets")

    local ROW_H = self.CHROMIE_MANAGE_SET_ROW_H or 24
    local ROW_GAP = self.CHROMIE_MANAGE_SET_ROW_GAP or 0
    local function manageSetsWheel(delta)
        local bar = getglobal("ChromieTransmogManageSetScrollScrollBar")
        if not bar then
            return
        end
        delta = tonumber(delta) or arg1 or 0
        local minV, maxV = bar:GetMinMaxValues()
        local v = bar:GetValue() - (delta * ROW_H)
        if v < minV then
            v = minV
        end
        if v > maxV then
            v = maxV
        end
        bar:SetValue(v)
    end

    local scroll = CreateFrame("ScrollFrame", "ChromieTransmogManageSetScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        local frame = this
        local value = arg1
        if type(self) == "table" and type(offset) == "number" then
            frame = self
            value = offset
        end
        frame.offset = math.floor(((tonumber(value) or 0) / ROW_H) + 0.5)
        Transmog:ChromieRefreshManageSetList()
    end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        manageSetsWheel(delta or arg1)
    end)
    f.scroll = scroll

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        manageSetsWheel(delta or arg1)
    end)
    f:SetScript("OnShow", function()
        this:SetScript("OnUpdate", function()
            this:SetScript("OnUpdate", nil)
            Transmog:ChromieRefreshManageSetList()
        end)
    end)

    f.rows = {}
    local i = 1
    while i <= self.CHROMIE_MANAGE_SET_ROWS do
        local row = CreateFrame("Frame", "ChromieTransmogManageSetRow" .. i, f)
        row:SetWidth(400)
        row:SetHeight(ROW_H)
        if i == 1 then
            row:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
        else
            row:SetPoint("TOPLEFT", f.rows[i - 1], "BOTTOMLEFT", 0, -ROW_GAP)
        end

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("LEFT", 4, 0)
        nameText:SetWidth(300)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        local del = CreateFrame("Button", "ChromieTransmogManageSetRow" .. i .. "Delete", row, "UIPanelButtonTemplate")
        del:SetWidth(65)
        del:SetHeight(20)
        del:SetPoint("RIGHT", 18, 0)
        del:SetText("Delete")
        del:SetScript("OnClick", function()
            local setName = this:GetParent().setName
            if setName then
                Transmog.chromieDeleteSetName = setName
                StaticPopup_Show("CONFIRM_DELETE_OUTFIT", setName)
            end
        end)
        del:EnableMouseWheel(true)
        del:SetScript("OnMouseWheel", function(self, delta)
            manageSetsWheel(delta or arg1)
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(self, delta)
            manageSetsWheel(delta or arg1)
        end)
        row.del = del
        row:Hide()
        f.rows[i] = row
        i = i + 1
    end

    local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 4, -16)
    empty:SetText("No saved sets yet.")
    f.empty = empty

    self.manageSetsFrame = f
    return f
end

function Transmog:ChromieRefreshManageSetList()
    local f = self.manageSetsFrame
    if not f or not f:IsShown() then
        return
    end
    local names = self.chromieSets or {}
    local n = self:tableSize(names)
    local vis = self:ChromieManageSetsVisibleRows()
    local maxRows = self.CHROMIE_MANAGE_SET_ROWS or 12
    FauxScrollFrame_Update(f.scroll, n, vis, self.CHROMIE_MANAGE_SET_ROW_H or 24)
    local offset = FauxScrollFrame_GetOffset(f.scroll) or 0
    if n == 0 then
        f.empty:Show()
    else
        f.empty:Hide()
    end
    local i = 1
    while i <= maxRows do
        local row = f.rows[i]
        local name = nil
        if i <= vis then
            name = names[offset + i]
        end
        if name then
            row.setName = name
            row.nameText:SetText(name)
            row.del:Enable()
            row:Show()
        else
            row.setName = nil
            row:Hide()
        end
        i = i + 1
    end
    if n >= self.CHROMIE_MAX_SETS or self.chromieJob == "sets-save" or self.chromieJob == "sets-price" or self.chromieWantSetPrice then
        f.save:Disable()
    elseif self.chromieSetSaveCopper and GetMoney() < self.chromieSetSaveCopper then
        f.save:Disable()
    else
        f.save:Enable()
    end
    self:ChromieUpdateManageSetPrice()
end

function Transmog:ChromieUpdateManageSetPrice()
    local f = self.manageSetsFrame
    if not f or not f.cost then
        return
    end
    if (self.chromieJob == "sets-price" and not self.chromieSetPriceCaptured) or self.chromieWantSetPrice then
        f.cost:SetText("...")
        return
    end
    if self.chromieSetSaveCopper then
        f.cost:SetText(self:ChromieCoinText(self.chromieSetSaveCopper))
        return
    end
    f.cost:SetText("")
end

function Transmog:ChromieRefreshManageSets()
    if self.manageSetsOpen then
        self:ChromieRefreshManageSetList()
    end
end

function Transmog:ChromieShowManageSets()
    self:hideItems(true)
    self:hidePagination()
    ChromieTransmogFrameSplash:Hide()
    ChromieTransmogFrameInstructions:Hide()
    ChromieTransmogFrameNoTransmogs:Hide()
    ChromieTransmogFrameCollected:Hide()
    self:ChromieHideSetCreate()
    local f = self:ChromieEnsureManageSetsFrame()
    self.manageSetsOpen = true
    f:Show()
    self:ChromieRefreshManageSetList()
    if self.ChromieStartSetPrice then
        self:ChromieStartSetPrice()
    end
end

function Transmog:ChromieCanApplySet()
    if not self.chromiePendingSet or not self.chromiePendingSet.name or not self.chromiePendingSet.items then
        return false
    end
    if self:ChromieHasPending() then
        return false
    end
    return true
end

-- Applies a server set immediately through Warpweaver. No confirm popup.
function Transmog_LoadOutfit(self, outfit)
    if not outfit then
        return
    end
    Transmog:ChromieHideSetCreate()
    selectTransmogSlot(-1)
    UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, Transmog:ChromieSetsDropdownLabel())
    ChromieTransmogFrameSaveOutfit:Hide()
    Transmog:hideItemBorders()
    Transmog.chromiePendingSet = {
        name = outfit,
        items = Transmog.chromieSetItems and Transmog.chromieSetItems[outfit] or nil,
    }
    if Transmog.ChromieStartSetUse then
        Transmog:ChromieStartSetUse(outfit)
    end
end

function Transmog_SaveOutfit()
    ChromieTransmogFrameSaveOutfit:Hide()
    ChromieTransmogFrameSaveOutfit:Disable()
end

function Transmog:EnableOutfitSaveButton()
    ChromieTransmogFrameSaveOutfit:Hide()
    ChromieTransmogFrameSaveOutfit:Disable()
    if self.chromieJob == "sets-use" then
        return
    end
    if (self.currentOutfit or self.chromiePendingSet) and self:ChromieHasPending() then
        self:ChromieDeselectSet()
    end
end

function Transmog_ShowManageSets()
    Transmog:ChromieShowManageSets()
end

function Transmog_deleteOutfit()
    local name = Transmog.chromieDeleteSetName or Transmog.currentOutfit
    Transmog.chromieDeleteSetName = nil
    if not name then
        return
    end
    if Transmog.ChromieStartSetDelete then
        Transmog:ChromieStartSetDelete(name)
        return
    end
    Transmog:ChromieRemoveSetName(name)
    if Transmog.currentOutfit == name then
        Transmog:ChromieDeselectSet()
        Transmog:PreviewRedress(0)
        Transmog:calculateCost()
    end
    Transmog:ChromieRefreshManageSets()
end

StaticPopupDialogs["CONFIRM_DELETE_OUTFIT"] = {
    text = "Delete set \"%s\"?",
    button1 = TEXT(YES),
    button2 = TEXT(NO),
    OnAccept = function()
        Transmog_deleteOutfit()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function Transmog_NewOutfitPopup()
    Transmog:ChromieShowManageSets()
end

function Transmog_CancelNewSet()
    Transmog:ChromieHideSetCreate()
end

function Transmog_ConfirmNewSet()
    local f = Transmog.manageSetsFrame
    if not f or not f:IsShown() then
        return
    end
    local name = f.edit:GetText() or ""
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" or string.find(name, '"', 1, true) or string.find(name, "\\", 1, true) then
        Transmog:Chat("Enter a valid set name (no quotes or backslashes).")
        return
    end
    if Transmog:ChromieHasSetName(name) then
        Transmog:Chat("A set with that name already exists.")
        return
    end
    if Transmog:tableSize(Transmog.chromieSets or {}) >= Transmog.CHROMIE_MAX_SETS then
        Transmog:Chat("Set limit reached.")
        return
    end
    if not Transmog:ChromieHasAnyMog() then
        Transmog:Chat("Nothing to save. Transmogrify at least one item first.")
        return
    end
    if Transmog.ChromieStartSetSave then
        Transmog:ChromieStartSetSave(name)
    end
end
