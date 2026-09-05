local Transmog = _G.ChromieTransmog

Transmog.ABOUT_TAB_BODY = "The addon can not directly read what the equipped items are transmogrified as. Gossip only lists other looks, and omits the original item and the transmogrify item.\n\n"
    .. "This overlay needs item ids to dress the 3D dummy, name transmogs in tooltips, and preview your last used sets. The Cache tab fills that in by scanning each equipped slot: an unmogged scan stores every unlocked look, a mogged scan infers the missing (worn) id.\n\n"
    .. "Set previews on Home are a snapshot of those ids after you apply a set. The sets cache on first apply. If previews look wrong, use the Cache tab to scan or drop cache - Warpweaver sets on the server are not deleted by dropping cache.\n\n"
    .. "Item tooltips can show You haven't collected this appearance when that look is missing from the account collection (Settings). The line is only accurate for armor and weapon types you have already scanned at a Warpweaver.\n\n"
    .. "If the addon behaves weird, try closing and reopening the window. If that doesnt help, try /reload-ing. If that doesnt help, drop cache and rescan. If you can recreate a specific issue, report it on https://github.com/tr00dudu/ChromieTransmog."

function Transmog:ChromieAboutTabEnsure()
    if self.aboutTabFrame then
        return self.aboutTabFrame
    end
    local f = CreateFrame("Frame", "ChromieTransmogAboutTab", ChromieTransmogFrame)
    f:SetPoint("TOPLEFT", ChromieTransmogFrame, "TOPLEFT", 255, -88)
    f:SetPoint("BOTTOMRIGHT", ChromieTransmogFrame, "BOTTOMRIGHT", -20, 40)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -4)
    title:SetText("About")

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    body:SetWidth(430)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetNonSpaceWrap(true)
    body:SetText(self.ABOUT_TAB_BODY)
    f.body = body

    self.aboutTabFrame = f
    return f
end

function Transmog:ChromieAboutTabShow()
    local f = self:ChromieAboutTabEnsure()
    f:Show()
end

function Transmog:ChromieAboutTabHide()
    if self.aboutTabFrame then
        self.aboutTabFrame:Hide()
    end
end
