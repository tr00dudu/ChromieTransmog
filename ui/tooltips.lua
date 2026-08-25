local Transmog = _G.ChromieTransmog
local ChromieTransmogFrame_Find = string.find
local ChromieTransmogFrame_ToNumber = tonumber
local EquipTransmogTooltip = CreateFrame("Frame", "EquipTransmogTooltip", GameTooltip)

-- Shows a text-only tooltip when hovering over a frame.
function AddButtonOnEnterTextTooltip(frame, text, ext, error, anchor, x, y)
    frame:SetScript("OnEnter", function(self)
        if anchor and x and y then
            FashionTooltip:SetOwner(this, anchor, x, y)
        else
            FashionTooltip:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4) + 15, -(this:GetHeight() / 4) + 20)
        end

        if error then
            FashionTooltip:AddLine(FONT_COLOR_CODE_CLOSE .. text)
            FashionTooltip:AddLine("|cffff2020" .. ext)
        else
            FashionTooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE .. text)
            if ext then
                FashionTooltip:AddLine(FONT_COLOR_CODE_CLOSE .. ext)
            end
        end
        FashionTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        FashionTooltip:Hide()
    end)
end

local function fashionMogLine(transmogText, revert)
    if not transmogText then
        return nil
    end
    local hidden = transmogText == "(Hidden)" or transmogText == "Hidden"
        or (type(transmogText) == "string" and string.find(transmogText, "Hidden", 1, true))
    local line = hidden and "|cffff80ffTransmogrified - Hidden|r" or "|cffff80ffTransmogrified|r"
    if revert then
        line = line .. "\n|cffffd200Right-Click to revert"
    end
    return line
end

local function applyFashionMogLabel(transmogText, revert)
    local tLabel = getglobal(FashionTooltip:GetName() .. "TextLeft2")
    local line = fashionMogLine(transmogText, revert)
    if not tLabel or not line then
        return
    end
    local existing = tLabel:GetText() or ""
    if existing == "" then
        tLabel:SetText(line)
    else
        tLabel:SetText(line .. "\n|cffffffff" .. existing)
    end
end

-- Shows an item tooltip with optional transmog status text on hover.
function AddButtonOnEnterTooltipFashion(frame, itemLink, TransmogText, revert)

    if ChromieTransmogFrame_Find(itemLink, "|", 1, true) then
        local ex = ChromieTransmogFrame_Explode(itemLink, "|")

        if not ex[2] or not ex[3] then
            twferror('bad addButtonOnEnterTooltip itemLink syntax')
            twferror(itemLink)
            return false
        end

        frame:SetScript("OnEnter", function(self)
            FashionTooltip:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4) + 10, -(this:GetHeight() / 4));
            FashionTooltip:SetHyperlink(string.sub(ex[3], 2, string.len(ex[3])));
            applyFashionMogLabel(TransmogText, revert)
            FashionTooltip:AddLine("");
            FashionTooltip:Show();
        end)
    else
        frame:SetScript("OnEnter", function(self)
            FashionTooltip:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4) + 10, -(this:GetHeight() / 4));
            FashionTooltip:SetHyperlink(itemLink);
            applyFashionMogLabel(TransmogText, revert)
            FashionTooltip:Show();
        end)
    end
    frame:SetScript("OnLeave", function(self)
        FashionTooltip:Hide();
    end)
end

local characterPaperDollFrames = {
    CharacterHeadSlot,
    CharacterShoulderSlot,
    CharacterBackSlot,
    CharacterChestSlot,
    CharacterWristSlot,
    CharacterHandsSlot,
    CharacterWaistSlot,
    CharacterLegsSlot,
    CharacterFeetSlot,
    CharacterMainHandSlot,
    CharacterSecondaryHandSlot,
    CharacterRangedSlot,
}

EquipTransmogTooltip:SetScript("OnShow", function()
    if GameTooltip.itemLink then

        if not PaperDollFrame:IsVisible() then
            return
        end

        local _, _, itemLink = ChromieTransmogFrame_Find(GameTooltip.itemLink, "(item:%d+:%d+:%d+:%d+)");

        if not itemLink then
            return
        end

        for _, frame in ipairs(characterPaperDollFrames) do
            if GameTooltip:IsOwned(frame) == 1 then

                local itemName = GetItemInfo(itemLink)

                if Transmog.equippedTransmogs[itemName] then

                    local tLabel = getglobal(GameTooltip:GetName() .. "TextLeft2")

                    if tLabel then
                    end

                    GameTooltip:Show()
                end

            end

        end

    end
end)

EquipTransmogTooltip:SetScript("OnHide", function()
    GameTooltip.itemLink = nil
end)
