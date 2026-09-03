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

    local check = CreateFrame("CheckButton", "ChromieTransmogSettingsChatDebug", f, "OptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -10)
    local label = getglobal(check:GetName() .. "Text")
    if label then
        label:SetText("Print debug messages in chat")
    end
    check:SetScript("OnClick", function()
        local on = this:GetChecked() and true or false
        Transmog:SetDebugEnabled(on)
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
