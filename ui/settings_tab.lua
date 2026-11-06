local Transmog = _G.ChromieTransmog

Transmog.UI_SCALES = { 1, 1.2, 1.5, 2 }

function Transmog:ChromieMatchUiScale(scale)
    scale = tonumber(scale)
    local scales = self.UI_SCALES
    local i = 1
    while scales[i] do
        if scale and math.abs(scale - scales[i]) < 0.01 then
            return scales[i]
        end
        i = i + 1
    end
    return nil
end

function Transmog:ChromieUiScale()
    if self.ChromieEnsurePersistDB then
        self:ChromieEnsurePersistDB()
    end
    local s = ChromieTransmogDB and self:ChromieMatchUiScale(ChromieTransmogDB.uiScale)
    return s or 1
end

function Transmog:ChromieUiScaleLabel(scale)
    scale = self:ChromieMatchUiScale(scale) or self:ChromieUiScale()
    if scale == math.floor(scale) then
        return tostring(math.floor(scale)) .. "x"
    end
    return string.format("%.1f", scale) .. "x"
end

function Transmog:ChromieApplyUiScale()
    if ChromieTransmogFrame then
        ChromieTransmogFrame:SetScale(self:ChromieUiScale())
    end
end

function Transmog:ChromieSetUiScale(scale)
    scale = self:ChromieMatchUiScale(scale) or 1
    if self.ChromieEnsurePersistDB then
        self:ChromieEnsurePersistDB()
    end
    ChromieTransmogDB.uiScale = scale
    self:ChromieApplyUiScale()
    self:ChromieSettingsTabSync()
end

function ChromieTransmogSettingsScale_Init()
    local scales = Transmog.UI_SCALES
    local current = Transmog:ChromieUiScale()
    local i = 1
    while scales[i] do
        local s = scales[i]
        local info = {}
        info.text = Transmog:ChromieUiScaleLabel(s)
        info.arg1 = s
        info.checked = math.abs(current - s) < 0.01
        info.func = function(a, b)
            Transmog:ChromieSetUiScale(tonumber(b) or tonumber(a))
        end
        UIDropDownMenu_AddButton(info)
        i = i + 1
    end
end

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

    local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    scaleLabel:SetText("Window scale")
    f.scaleLabel = scaleLabel

    local scaleDrop = CreateFrame("Frame", "ChromieTransmogSettingsScale", f, "UIDropDownMenuTemplate")
    scaleDrop:SetPoint("LEFT", scaleLabel, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(scaleDrop, 70)
    UIDropDownMenu_Initialize(scaleDrop, ChromieTransmogSettingsScale_Init)
    UIDropDownMenu_SetText(scaleDrop, self:ChromieUiScaleLabel())
    f.scaleDrop = scaleDrop

    local uncollected = CreateFrame("CheckButton", "ChromieTransmogSettingsUncollected", f, "OptionsCheckButtonTemplate")
    uncollected:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", -2, -18)
    local ulabel = getglobal(uncollected:GetName() .. "Text")
    if ulabel then
        ulabel:SetText("Show not collected in tooltips")
    end
    uncollected:SetScript("OnClick", function()
        Transmog:ChromieAccountSetFlag("showUncollectedTip", this:GetChecked() and true or false)
        Transmog:ChromieSettingsTabSync()
    end)
    f.uncollectedCheck = uncollected

    local colorLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorLabel:SetText("( Color:")
    if ulabel then
        colorLabel:SetPoint("LEFT", ulabel, "RIGHT", 20, -1)
    else
        colorLabel:SetPoint("LEFT", uncollected, "RIGHT", 220, 0)
    end
    f.uncollectedColorLabel = colorLabel

    local swatch = CreateFrame("Button", "ChromieTransmogSettingsUncollectedColor", f)
    swatch:SetWidth(16)
    swatch:SetHeight(16)
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 4, 0)
    local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
    swatchTex:SetAllPoints()
    swatchTex:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
    swatch.tex = swatchTex
    swatch:SetScript("OnClick", function()
        local r, g, b = Transmog:ChromieAccountUncollectedTipColor()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            Transmog:ChromieAccountSetUncollectedTipColor(nr, ng, nb)
            Transmog:ChromieSettingsTabSync()
        end
        ColorPickerFrame.cancelFunc = function(prev)
            local pr, pg, pb = r, g, b
            if type(prev) == "table" then
                pr = prev.r or prev[1] or r
                pg = prev.g or prev[2] or g
                pb = prev.b or prev[3] or b
            end
            Transmog:ChromieAccountSetUncollectedTipColor(pr, pg, pb)
            Transmog:ChromieSettingsTabSync()
        end
        ColorPickerFrame.previousValues = { r = r, g = g, b = b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ShowUIPanel(ColorPickerFrame)
    end)
    f.uncollectedColor = swatch

    local reset = CreateFrame("Button", "ChromieTransmogSettingsUncollectedColorReset", f)
    reset:SetWidth(32)
    reset:SetHeight(14)
    reset:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
    local resetText = reset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER")
    resetText:SetText("Reset")
    reset:SetFontString(resetText)
    reset:SetHighlightFontObject("GameFontHighlightSmall")
    reset:SetScript("OnClick", function()
        Transmog:ChromieAccountResetUncollectedTipColor()
        if ColorPickerFrame:IsShown() then
            HideUIPanel(ColorPickerFrame)
        end
        Transmog:ChromieSettingsTabSync()
    end)
    f.uncollectedColorReset = reset

    local colorClose = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorClose:SetText(")")
    colorClose:SetPoint("LEFT", reset, "RIGHT", 2, 0)
    f.uncollectedColorClose = colorClose

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
        if f.uncollectedColor and f.uncollectedColor.tex then
            local r, g, b = Transmog:ChromieAccountUncollectedTipColor()
            f.uncollectedColor.tex:SetVertexColor(r, g, b)
        end
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
    if f.scaleDrop then
        UIDropDownMenu_SetText(f.scaleDrop, self:ChromieUiScaleLabel())
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
