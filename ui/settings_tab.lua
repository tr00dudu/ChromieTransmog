local Transmog = _G.ChromieTransmog

function Transmog:ChromieSettingsTabEnsure()
    if self.settingsTabFrame then
        return self.settingsTabFrame
    end
    local f = CreateFrame("Frame", "ChromieTransmogSettingsTab", ChromieTransmogFrame)
    f:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 255, -88)
    f:SetPoint("BOTTOMRIGHT", ChromieTransmogFrame, "BOTTOMRIGHT", -20, 40)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -4)
    title:SetText("Settings")

    local uncollected = CreateFrame("CheckButton", "ChromieTransmogSettingsUncollected", f, "OptionsCheckButtonTemplate")
    uncollected:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -10)
    local ulabel = getglobal(uncollected:GetName() .. "Text")
    if ulabel then
        ulabel:SetText("Show not collected in tooltips")
    end
    uncollected:SetScript("OnClick", function()
        Transmog:ChromieAccountSetFlag("showUncollectedTip", this:GetChecked() and true or false)
        Transmog:ChromieSettingsTabSync()
    end)
    f.uncollectedCheck = uncollected

    local function makeUncollectedCheck(name, text, anchor, dx, flag)
        local cb = CreateFrame("CheckButton", name, f, "OptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", dx, 2)
        local label = getglobal(cb:GetName() .. "Text")
        if label then
            label:SetText(text)
        end
        cb:SetScript("OnClick", function()
            Transmog:ChromieAccountSetFlag(flag, this:GetChecked() and true or false)
            Transmog:ChromieSettingsTabSync()
        end)
        return cb
    end

    f.uncollectedPoorCheck = makeUncollectedCheck("ChromieTransmogSettingsUncollectedPoor", "Include Common Items", uncollected, 16, "showUncollectedPoor")
    f.uncollectedLowerCheck = makeUncollectedCheck("ChromieTransmogSettingsUncollectedLower", "Include lower armor proficiencies", f.uncollectedPoorCheck, 0, "showUncollectedLower")
    f.uncollectedHigherCheck = makeUncollectedCheck("ChromieTransmogSettingsUncollectedHigher", "Include higher armor and non-proficient weapons", f.uncollectedLowerCheck, 0, "showUncollectedHigher")
    f.uncollectedHigherBoeCheck = makeUncollectedCheck("ChromieTransmogSettingsUncollectedHigherBoe", "BoE", f.uncollectedHigherCheck, 16, "showUncollectedHigherBoe")
    f.uncollectedHigherBopCheck = makeUncollectedCheck("ChromieTransmogSettingsUncollectedHigherBop", "BoP", f.uncollectedHigherBoeCheck, 0, "showUncollectedHigherBop")

    local note = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", f.uncollectedHigherBopCheck, "BOTTOMLEFT", -32, -8)
    note:SetWidth(360)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.7, 0.7, 0.7)
    note:SetText("Until you cache appearances at a Warpweaver, the not-collected status in tooltips will be inaccurate for types you have not scanned.")
    f.uncollectedNote = note

    local debugTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugTitle:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -14)
    debugTitle:SetText("Debug")
    f.debugTitle = debugTitle

    local check = CreateFrame("CheckButton", "ChromieTransmogSettingsChatDebug", f, "OptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", debugTitle, "BOTTOMLEFT", -2, -8)
    local label = getglobal(check:GetName() .. "Text")
    if label then
        label:SetText("Print debug messages in chat")
    end
    check:SetScript("OnClick", function()
        local on = this:GetChecked() and true or false
        Transmog:SetDebugEnabled(on)
        Transmog:ChromieSettingsTabSync()
    end)
    f.debugCheck = check

    local verbose = CreateFrame("CheckButton", "ChromieTransmogSettingsChatVerbose", f, "OptionsCheckButtonTemplate")
    verbose:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 16, 2)
    local vlabel = getglobal(verbose:GetName() .. "Text")
    if vlabel then
        vlabel:SetText("Verbose debugging (gossip dumps)")
    end
    verbose:SetScript("OnClick", function()
        local on = this:GetChecked() and true or false
        Transmog:SetVerboseEnabled(on)
    end)
    f.verboseCheck = verbose

    local window = CreateFrame("CheckButton", "ChromieTransmogSettingsChatWindow", f, "OptionsCheckButtonTemplate")
    window:SetPoint("TOPLEFT", verbose, "BOTTOMLEFT", 0, 2)
    local wlabel = getglobal(window:GetName() .. "Text")
    if wlabel then
        wlabel:SetText("Print in copyable window")
    end
    window:SetScript("OnClick", function()
        local on = this:GetChecked() and true or false
        Transmog:SetLogWindowEnabled(on)
    end)
    f.windowCheck = window

    self.settingsTabFrame = f
    return f
end

function Transmog:ChromieSettingsTabSync()
    local f = self.settingsTabFrame
    if not f or not f.debugCheck then
        return
    end
    if f.uncollectedCheck and Transmog.ChromieAccountFlag then
        local tipOn = Transmog:ChromieAccountFlag("showUncollectedTip")
        f.uncollectedCheck:SetChecked(tipOn and 1 or nil)
        local function syncChild(cb, enabled, flag)
            if not cb then
                return
            end
            if enabled then
                cb:Enable()
            else
                cb:Disable()
            end
            cb:SetChecked(Transmog:ChromieAccountFlag(flag) and 1 or nil)
        end
        syncChild(f.uncollectedPoorCheck, tipOn, "showUncollectedPoor")
        syncChild(f.uncollectedLowerCheck, tipOn, "showUncollectedLower")
        syncChild(f.uncollectedHigherCheck, tipOn, "showUncollectedHigher")
        local higherOn = tipOn and Transmog:ChromieAccountFlag("showUncollectedHigher")
        syncChild(f.uncollectedHigherBoeCheck, higherOn, "showUncollectedHigherBoe")
        syncChild(f.uncollectedHigherBopCheck, higherOn, "showUncollectedHigherBop")
    end
    f.debugCheck:SetChecked(self.CHAT_PRINTS == 1)
    local nestedOn = self.CHAT_PRINTS == 1
    if f.verboseCheck then
        if nestedOn then
            f.verboseCheck:Enable()
            f.verboseCheck:SetChecked(self.CHAT_VERBOSE == 1)
        else
            f.verboseCheck:SetChecked(nil)
            f.verboseCheck:Disable()
        end
    end
    if f.windowCheck then
        if nestedOn then
            f.windowCheck:Enable()
            f.windowCheck:SetChecked(self.CHAT_TO_WINDOW == 1)
        else
            f.windowCheck:SetChecked(nil)
            f.windowCheck:Disable()
        end
    end
end

function Transmog:ChromieSettingsTabShow()
    local f = self:ChromieSettingsTabEnsure()
    self:ChromieSettingsTabSync()
    f:Show()
end

function Transmog:ChromieSettingsTabHide()
    if self.settingsTabFrame then
        self.settingsTabFrame:Hide()
    end
end
