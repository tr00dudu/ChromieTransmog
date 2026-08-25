local Transmog = _G.ChromieTransmog

Transmog.chromieCache = {}
Transmog.chromieJob = nil
Transmog.chromieLastOptions = {}

local VENDOR_SKIP = {
    [9172] = true,
    [1049] = true,
    [57575] = true,
    [57576] = true,
}

function Transmog:Chat(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[ChromieTransmog]|r " .. tostring(msg))
end

function Transmog:ChromieInitStatus()
    local _, slotId
    for _, slotId in pairs(self.inventorySlots) do
        if self.transmogStatusFromServer[slotId] == nil then
            self.transmogStatusFromServer[slotId] = 0
        end
        if self.transmogStatusToServer[slotId] == nil then
            self.transmogStatusToServer[slotId] = self.transmogStatusFromServer[slotId]
        end
    end
end

-- Block CloseGossip while the overlay is using the NPC session.
-- GossipFrame_OnHide calls CloseGossip; hiding that frame must not end gossip.
function Transmog:ChromieKeepGossipAlive()
    if self.allowGossipClose then
        return false
    end
    -- After each applied slot the player must right-click Warpweaver again.
    -- Blocking CloseGossip here leaves the client "in gossip" so that click does nothing.
    if self.chromieWaitingForNpc then
        return false
    end
    if not self.overlayEnabled or self.probeActive then
        return false
    end
    if ChromieTransmogFrame and ChromieTransmogFrame:IsShown() then
        return true
    end
    return self.chromieJob == "load" or self.chromieJob == "apply" or self.chromieJob == "open"
end

function Transmog:ChromieForceCloseGossip()
    self.allowGossipClose = true
    if self.origCloseGossip then
        self.origCloseGossip()
    end
    self.allowGossipClose = nil
end

function Transmog:ChromieRestoreFrame(frame)
    if not frame then
        return
    end
    frame:SetAlpha(1)
    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
end

function Transmog:ChromiePatchBlizzardClose()
    if self.chromiePatchedBlizzard then
        return
    end
    self.chromiePatchedBlizzard = true

    if not self.origCloseGossip then
        self.origCloseGossip = CloseGossip
        CloseGossip = function()
            if Transmog:ChromieKeepGossipAlive() then
                return
            end
            Transmog.origCloseGossip()
        end
    end

    if GossipFrame then
        local orig = GossipFrame:GetScript("OnHide")
        GossipFrame:SetScript("OnHide", function()
            if Transmog:ChromieKeepGossipAlive() then
                return
            end
            if orig then
                orig()
            else
                Transmog.origCloseGossip()
            end
        end)
    end

    if MerchantFrame then
        local orig = MerchantFrame:GetScript("OnHide")
        MerchantFrame:SetScript("OnHide", function()
            if Transmog:ChromieKeepGossipAlive() then
                return
            end
            if orig then
                orig()
            end
        end)
    end

    if not self.chromiePatchedGossipConfirm and StaticPopup_Show then
        self.chromiePatchedGossipConfirm = true
        hooksecurefunc("StaticPopup_Show", function(which)
            Transmog:ChromieAutoConfirmGossipPopup(which)
        end)
    end

    self:ChromiePatchNpcFeedback()
end

-- Warpweaver uses the same area-trigger string for one slot and for remove-all.
function Transmog:ChromieShouldSuppressNpcFeedback()
    if self.probeActive or not self.overlayEnabled then
        return false
    end
    if ChromieTransmogFrame and ChromieTransmogFrame:IsShown() then
        return true
    end
    return self.chromieJob == "apply" or self.chromieJob == "load" or self.chromieJob == "open"
end

function Transmog:ChromieIsNpcFeedbackText(msg)
    if not msg then
        return false
    end
    local t = string.lower(tostring(msg))
    t = string.gsub(t, "|c%x%x%x%x%x%x%x%x", "")
    t = string.gsub(t, "|r", "")
    t = string.gsub(t, "|T.-|t", "")
    return string.find(t, "transmog", 1, true) ~= nil
end

function Transmog:ChromiePatchNpcFeedback()
    if self.chromiePatchedNpcFeedback then
        return
    end
    self.chromiePatchedNpcFeedback = true
    if not UIErrorsFrame or not UIErrorsFrame.AddMessage then
        return
    end
    local orig = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(frame, message, a1, a2, a3, a4, a5)
        if Transmog:ChromieShouldSuppressNpcFeedback() and Transmog:ChromieIsNpcFeedbackText(message) then
            if Transmog.ChromieLog then
                Transmog:ChromieLog("suppressed: " .. tostring(message))
            end
            return
        end
        return orig(frame, message, a1, a2, a3, a4, a5)
    end
end

function Transmog:ChromieHideBlizzard()
    if self.probeActive then
        return
    end
    self:ChromiePatchBlizzardClose()
    if GossipFrame then
        HideUIPanel(GossipFrame)
        GossipFrame:Hide()
    end
    if MerchantFrame then
        HideUIPanel(MerchantFrame)
        MerchantFrame:Hide()
    end
end

function Transmog:ChromieNpcId()
    local guid = UnitGUID("npc") or UnitGUID("target")
    if not guid then
        return nil, nil
    end
    local idA = tonumber(string.sub(guid, 8, 12), 16)
    local idB = tonumber(string.sub(guid, 7, 10), 16)
    local idC = tonumber(string.sub(guid, 9, 12), 16)
    return idA, guid, idB, idC
end

function Transmog:ChromieStrip(text)
    if not text then
        return ""
    end
    text = string.gsub(text, "|T.-|t", "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

function Transmog:ChromieGetOptions()
    local raw = { GetGossipOptions() }
    local list = {}
    local i = 1
    local n = 0
    while raw[i] do
        n = n + 1
        local text = raw[i] or ""
        list[n] = {
            index = n,
            text = text,
            stripped = self:ChromieStrip(text),
            kind = raw[i + 1],
            itemId = tonumber(string.match(text, "item:(%d+)")),
        }
        i = i + 2
    end
    self.chromieLastOptions = list
    return list
end

function Transmog:ChromieOptionFlags(opt)
    local flags = {}
    if not opt then
        return flags
    end
    local t = string.lower(opt.stripped or "")
    if opt.itemId then
        flags.item = true
        return flags
    end
    if string.find(t, "next page", 1, true) then
        flags.next = true
        flags.nav = true
    end
    if string.find(t, "previous page", 1, true) then
        flags.prev = true
        flags.nav = true
    end
    -- Submenu return is "Back...". Exact "Back" on the main menu is the cloak slot.
    if string.find(t, "back...", 1, true) then
        flags.back = true
        flags.nav = true
    end
    if t == "search" or string.find(t, "search...", 1, true) == 1 then
        flags.search = true
        flags.nav = true
    end
    if t == "hide slot" or string.find(t, "hide slot", 1, true) == 1 then
        flags.hide = true
    end
    if string.find(t, "remove all", 1, true) then
        flags.remove = true
        flags.nav = true
    end
    if string.find(t, "how does", 1, true) or string.find(t, "update menu", 1, true) or string.find(t, "manage", 1, true) then
        flags.nav = true
    end
    if string.find(t, "main hand", 1, true) then
        flags.slot = 16
    elseif string.find(t, "off hand", 1, true) then
        flags.slot = 17
    elseif string.find(t, "ranged", 1, true) then
        flags.slot = 18
    elseif t == "head" then
        flags.slot = 1
    elseif string.find(t, "shoulder", 1, true) then
        flags.slot = 3
    elseif t == "shirt" then
        flags.slot = 4
    elseif t == "chest" then
        flags.slot = 5
    elseif t == "waist" then
        flags.slot = 6
    elseif t == "legs" or t == "leg" then
        flags.slot = 7
    elseif t == "feet" or t == "foot" then
        flags.slot = 8
    elseif string.find(t, "wrist", 1, true) then
        flags.slot = 9
    elseif t == "hands" or t == "hand" then
        flags.slot = 10
    elseif t == "back" then
        flags.slot = 15
    elseif t == "cloak" then
        flags.slot = 15
    elseif t == "tabard" then
        flags.slot = 19
    end
    return flags
end

function Transmog:ChromieParseSlotTexture(text)
    local path = string.match(text or "", "|T([^:]+)")
    if not path then
        return nil, "empty"
    end
    local lower = string.lower(path)
    if string.find(lower, "paperdoll", 1, true) then
        return path, "empty"
    end
    -- mod-transmog uses WoWUnknownItem01 when the fake entry is HIDDEN_ITEM_ID.
    if string.find(lower, "wowunknownitem", 1, true) then
        return path, "hidden"
    end
    return path, "mog"
end

function Transmog:ChromieGossipTextureToFile(path)
    if not path then
        return nil
    end
    path = string.gsub(path, "/", "\\")
    return path
end

-- Main menu prefixes each slot with the current fake appearance icon (mod-transmog).
-- Gossip is the source of truth for fromServer. Stale pending from a previous
-- overlay visit must not freeze a slot as hidden/mogged.
function Transmog:ChromieIngestMainMenuStatus(options)
    if not options then
        return
    end
    if not self.transmogGossipIcon then
        self.transmogGossipIcon = {}
    end
    -- Frame is hidden on a fresh talk-to-NPC open; trust gossip fully then.
    local overlayOpen = ChromieTransmogFrame and ChromieTransmogFrame:IsShown()
    local i = 1
    local changed = false
    local summary = ""
    while options[i] do
        local flags = self:ChromieOptionFlags(options[i])
        local slot = flags.slot
        if slot and not flags.item and not flags.nav then
            local path, kind = self:ChromieParseSlotTexture(options[i].text)
            local detected = 0
            if kind == "hidden" then
                detected = self.HIDDEN_ITEM_ID
                self.transmogGossipIcon[slot] = nil
            elseif kind == "mog" then
                detected = self.UNKNOWN_MOG_ID
                self.transmogGossipIcon[slot] = self:ChromieGossipTextureToFile(path)
                -- While the overlay stays open, keep a real id we applied this visit.
                if overlayOpen then
                    local prev = self.transmogStatusFromServer[slot]
                    if prev and prev > self.HIDDEN_ITEM_ID then
                        detected = prev
                    end
                end
            else
                self.transmogGossipIcon[slot] = nil
            end

            local haveBefore = self.transmogStatusFromServer[slot]
            local want = self.transmogStatusToServer[slot]
            if haveBefore ~= detected then
                self.transmogStatusFromServer[slot] = detected
                changed = true
            end
            local userPending = overlayOpen and want ~= nil and haveBefore ~= nil and want ~= haveBefore
            if not userPending then
                self.transmogStatusToServer[slot] = detected
            elseif want == detected then
                self.transmogStatusToServer[slot] = detected
            end
            summary = summary .. " " .. slot .. "=" .. kind
        end
        i = i + 1
    end
    if self.ChromieLog and summary ~= "" then
        self:ChromieLog("Main-menu status" .. summary)
    end
    if changed or not overlayOpen then
        if not overlayOpen or not self:ChromieHasPending() then
            self:transmogStatus()
        end
    end
end

function Transmog:ChromieHasPending()
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        local have = self.transmogStatusFromServer[slot]
        local want = self.transmogStatusToServer[slot]
        if have ~= want and want ~= self.UNKNOWN_MOG_ID then
            return true
        end
    end
    return false
end

function Transmog:ChromieCountSlots(options)
    local count = 0
    local i = 1
    while options[i] do
        local flags = self:ChromieOptionFlags(options[i])
        if flags.slot and not flags.item then
            count = count + 1
        end
        i = i + 1
    end
    return count
end

function Transmog:ChromieFindSlotOption(options, slot)
    local i = 1
    while options[i] do
        local flags = self:ChromieOptionFlags(options[i])
        if flags.slot == slot and not flags.item then
            return options[i].index
        end
        i = i + 1
    end
    return nil
end

function Transmog:ChromieDumpOptions(reason)
    local options = self.chromieLastOptions
    if not options then
        options = self:ChromieGetOptions()
    end
    local n = self:tableSize(options)
    twfdebug("Chromie dump " .. tostring(reason) .. " options=" .. n)
    local i = 1
    while options[i] and i <= 12 do
        local opt = options[i]
        twfdebug("  [" .. opt.index .. "] item=" .. tostring(opt.itemId) .. " " .. opt.stripped)
        i = i + 1
    end
    if n > 12 then
        twfdebug("  ... " .. (n - 12) .. " more")
    end
end

function Transmog:ChromieIsKnownNpc()
    local idA, guid, idB, idC = self:ChromieNpcId()
    local ids = self.CHROMIE_NPC_IDS
    if ids then
        if idA and ids[idA] then
            return true, idA, guid
        end
        if idB and ids[idB] then
            return true, idB, guid
        end
        if idC and ids[idC] then
            return true, idC, guid
        end
    end
    local name = UnitName("npc") or UnitName("target") or ""
    local lower = string.lower(name)
    if string.find(lower, "warpweaver", 1, true) or string.find(lower, "transmogrifier", 1, true) then
        return true, idA, guid
    end
    return false, idA, guid
end

function Transmog:ChromieLooksLikeTransmogGossip()
    local options = self:ChromieGetOptions()
    if self:ChromieCountSlots(options) >= 3 then
        return true
    end
    local i = 1
    local items = 0
    local nav = 0
    while options[i] do
        local flags = self:ChromieOptionFlags(options[i])
        if flags.item then
            items = items + 1
        end
        if flags.next or flags.prev or flags.search or flags.hide then
            nav = nav + 1
        end
        i = i + 1
    end
    if items > 0 or nav > 0 then
        return true
    end
    return false
end

function Transmog:ChromieShouldIntercept()
    if self.probeActive then
        return true
    end
    if not self.overlayEnabled then
        return false
    end
    if ChromieTransmogFrame and ChromieTransmogFrame:IsShown() then
        return true
    end
    if self.chromieJob then
        return true
    end
    local known = self:ChromieIsKnownNpc()
    if known then
        return true
    end
    return self:ChromieLooksLikeTransmogGossip()
end

function Transmog:SetOverlayEnabled(enabled)
    enabled = not not enabled
    self.overlayEnabled = enabled
    if enabled then
        self:Chat("Overlay on. Talk to the transmog NPC to use ChromieTransmog.")
        return
    end

    self.chromieJob = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = nil
    self.chromieWaitingForNpc = nil
    self.chromieApplySlot = nil
    self.chromieApplyItem = nil
    if self.gossipConfirmClicker then
        self.gossipConfirmClicker:Hide()
    end
    if self.ChromieAbortMultiApply then
        self:ChromieAbortMultiApply()
    end
    if ChromieTransmogFrame and ChromieTransmogFrame:IsShown() then
        self.skipCloseOnHide = true
        ChromieTransmogFrame:Hide()
        self.skipCloseOnHide = nil
        self:ChromieRestoreFrame(GossipFrame)
        self:ChromieRestoreFrame(MerchantFrame)
        if GossipFrame then
            ShowUIPanel(GossipFrame)
            GossipFrame:Show()
        end
        if self.chromieVendorOpen and MerchantFrame then
            ShowUIPanel(MerchantFrame)
            MerchantFrame:Show()
        end
    end
    self:Chat("Overlay off. Original NPC window will be used. /ct on to restore.")
end

function Transmog:ChromieAddCached(slot, itemId)
    if not slot or not itemId or itemId == 0 then
        return
    end
    if not self.chromieCache[slot] then
        self.chromieCache[slot] = {}
    end
    local i = 1
    while self.chromieCache[slot][i] do
        if self.chromieCache[slot][i] == itemId then
            return
        end
        i = i + 1
    end
    table.insert(self.chromieCache[slot], itemId)
    self:cacheItem(itemId)
end

function Transmog:ChromiePublish(slot)
    local itemClass = self.currentTransmogItemClass
    if not itemClass then
        local link = GetInventoryItemLink("player", slot)
        if link then
            local _, _, eq = string.find(link, "(item:%d+:%d+:%d+:%d+)")
            local _, _, _, _, _, itemClassStr, itemSubclass = GetItemInfo(eq or link)
            if itemClassStr and itemSubclass then
                itemClass = self:ItemClassStrToNum(itemClassStr) + self:ItemSubclassStrToNum(itemSubclass)
                self.currentTransmogItemClass = itemClass
            end
        end
    end
    if not itemClass then
        itemClass = 0
    end
    local ids = self.chromieCache[slot] or {}
    if not self.transmogDataFromServer[slot] then
        self.transmogDataFromServer[slot] = {}
    end
    self.transmogDataFromServer[slot][itemClass] = ids
    if not self.numTransmogs[slot] then
        self.numTransmogs[slot] = {}
    end
    self.numTransmogs[slot][itemClass] = self:tableSize(ids)
    self:prepareAvailableTransmogs(slot, itemClass)
    if self.currentTransmogSlot == slot then
        self:renderAvailableTransmogs(slot, itemClass)
    end
    if self.ChromieLog then
        self:ChromieLog("Cached " .. self:tableSize(ids) .. " appearances for slot " .. slot)
    end
end

function Transmog:ChromieFindFlagIndex(options, flagName)
    local i = 1
    while options[i] do
        local flags = self:ChromieOptionFlags(options[i])
        if flags[flagName] then
            return options[i].index
        end
        i = i + 1
    end
    return nil
end

function Transmog:ChromieIsAppearanceMenu(options)
    if self:ChromieCountSlots(options) >= 3 then
        return false
    end
    local i = 1
    while options[i] do
        local flags = self:ChromieOptionFlags(options[i])
        -- Ranged-style page: items + Next Page. Tabard empty: only Back...
        if flags.item or flags.hide or flags.search or flags.next or flags.back then
            return true
        end
        i = i + 1
    end
    return false
end

function Transmog:ChromieClickBack(reason)
    local idx = self:ChromieFindFlagIndex(self:ChromieGetOptions(), "back")
    if not idx then
        return false
    end
    if self.ChromieLog then
        self:ChromieLog("SelectGossipOption(" .. idx .. ") Back... (" .. tostring(reason) .. ")")
    end
    SelectGossipOption(idx)
    return true
end

function Transmog:ChromieFinishLoad()
    local slot = self.chromieLoadSlot
    local n = slot and self:tableSize(self.chromieCache[slot] or {}) or 0
    if slot then
        self:ChromiePublish(slot)
    end
    self.chromieJob = "open"
    self.chromieLoadEnteredSlot = nil
    if self.ChromieLog then
        self:ChromieLog("load done slot=" .. tostring(slot) .. " appearances=" .. n)
    end
    self:ChromieClickBack("load-done")
end

function Transmog:ChromieIngestAppearancePage(wantSlot, options)
    local added = 0
    local nextIndex = nil
    local i = 1
    while options[i] do
        local opt = options[i]
        local flags = self:ChromieOptionFlags(opt)
        if opt.itemId then
            local before = self:tableSize(self.chromieCache[wantSlot] or {})
            self:ChromieAddCached(wantSlot, opt.itemId)
            if self:tableSize(self.chromieCache[wantSlot] or {}) > before then
                added = added + 1
            end
        elseif flags.next then
            nextIndex = opt.index
        end
        i = i + 1
    end
    return added, nextIndex
end

function Transmog:ChromieHandleLoadGossip()
    local options = self:ChromieGetOptions()
    self:ChromieDumpOptions("load")
    local wantSlot = self.chromieLoadSlot

    if self:ChromieCountSlots(options) >= 3 then
        local idx = self:ChromieFindSlotOption(options, wantSlot)
        if idx then
            self.chromieLoadEnteredSlot = true
            if self.ChromieLog then
                self:ChromieLog("SelectGossipOption(" .. idx .. ") for slot " .. wantSlot .. " (waiting for submenu GOSSIP_SHOW)")
            end
            SelectGossipOption(idx)
            return
        end
        self:Chat("No gossip option for slot " .. tostring(wantSlot) .. ". Equip that slot and try again.")
        self.chromieJob = "open"
        ChromieTransmogFrameNoTransmogs:SetText("This slot has no gossip option. Equip an item first.")
        ChromieTransmogFrameNoTransmogs:Show()
        return
    end

    if self:ChromieIsAppearanceMenu(options) and not self.chromieLoadEnteredSlot then
        if self.ChromieLog then
            self:ChromieLog("load leftover submenu; returning to main")
        end
        if self:ChromieClickBack("load-wrong-menu") then
            return
        end
    end

    self.chromieLoadEnteredSlot = true
    local added, nextIndex = self:ChromieIngestAppearancePage(wantSlot, options)
    local total = self:tableSize(self.chromieCache[wantSlot] or {})
    if self.ChromieLog then
        self:ChromieLog("load page +" .. added .. " cached=" .. total .. " next=" .. tostring(nextIndex))
    end

    if nextIndex then
        self.chromiePages = (self.chromiePages or 0) + 1
        if self.chromiePages < 40 then
            if self.ChromieLog then
                self:ChromieLog("SelectGossipOption(" .. nextIndex .. ") Next Page")
            end
            SelectGossipOption(nextIndex)
            return
        end
        self:Chat("Stopped after 40 gossip pages")
    end

    self:ChromieFinishLoad()
end

function Transmog:ChromieHideGossipConfirm()
    StaticPopup_Hide("GOSSIP_CONFIRM")
    StaticPopup_Hide("GOSSIP_CONFIRM_MONEY")
end

function Transmog:ChromieAutoConfirmGossipPopup(which)
    if which ~= "GOSSIP_CONFIRM" and which ~= "GOSSIP_CONFIRM_MONEY" then
        return
    end
    -- Vanilla Warpweaver confirms (hide / paid mog) must stay when overlay is off.
    if not self.overlayEnabled or self.probeActive then
        return
    end
    if self.chromieJob ~= "apply" or not self.chromieApplyClicked then
        return
    end
    if self.chromieGossipConfirmed then
        self:ChromieHideGossipConfirm()
        return
    end
    self.chromieGossipConfirmed = true
    if not self.gossipConfirmClicker then
        local f = CreateFrame("Frame")
        f:Hide()
        f:SetScript("OnUpdate", function()
            this:Hide()
            local name = StaticPopup_Visible("GOSSIP_CONFIRM")
            if not name then
                name = StaticPopup_Visible("GOSSIP_CONFIRM_MONEY")
            end
            if name then
                local btn = getglobal(name .. "Button1")
                if btn then
                    btn:Click()
                end
            end
        end)
        self.gossipConfirmClicker = f
    end
    self.gossipConfirmClicker:Show()
end

function Transmog:ChromieHandleApplyGossip()
    local options = self:ChromieGetOptions()
    self:ChromieDumpOptions("apply")
    local wantSlot = self.chromieApplySlot
    local wantItem = self.chromieApplyItem

    if self:ChromieCountSlots(options) >= 3 then
        local idx = self:ChromieFindSlotOption(options, wantSlot)
        if idx then
            self.chromieApplyEnteredSlot = true
            SelectGossipOption(idx)
            return
        end
        self:Chat("Apply failed: slot option not found")
        self.chromieJob = "open"
        if self.ChromieAbortMultiApply then
            self:ChromieAbortMultiApply()
        end
        self:calculateCost()
        return
    end

    if self:ChromieIsAppearanceMenu(options) and not self.chromieApplyEnteredSlot then
        if self:ChromieClickBack("apply-wrong-menu") then
            return
        end
    end
    self.chromieApplyEnteredSlot = true

    local i = 1
    local nextIndex = nil
    local removeIndex = nil
    while options[i] do
        local flags = self:ChromieOptionFlags(options[i])
        if wantItem == self.HIDDEN_ITEM_ID and flags.hide then
            self.chromieApplyClicked = true
            SelectGossipOption(options[i].index)
            return
        end
        -- Slot submenu "Remove all transmogrifications" clears this slot's mog.
        -- Do not use the main-menu copy (CountSlots >= 3 already entered a slot).
        if wantItem == 0 and flags.remove then
            removeIndex = options[i].index
        elseif wantItem and wantItem ~= 0 and options[i].itemId == wantItem then
            self.chromieApplyClicked = true
            SelectGossipOption(options[i].index)
            return
        end
        if flags.next then
            nextIndex = options[i].index
        end
        i = i + 1
    end

    if wantItem == 0 and removeIndex then
        self.chromieApplyClicked = true
        SelectGossipOption(removeIndex)
        return
    end

    if nextIndex then
        self.chromieApplyPages = (self.chromieApplyPages or 0) + 1
        if self.chromieApplyPages < 40 then
            SelectGossipOption(nextIndex)
            return
        end
    end

    self:Chat("Apply failed: appearance " .. tostring(wantItem) .. " was not in the gossip list")
    self.chromieJob = "open"
    if self.ChromieAbortMultiApply then
        self:ChromieAbortMultiApply()
    end
    self:calculateCost()
end

function Transmog:ChromieHandleApplyMerchant()
    local wantItem = self.chromieApplyItem
    local n = GetMerchantNumItems() or 0
    local i = 1
    while i <= n do
        local link = GetMerchantItemLink(i)
        local id = link and tonumber(string.match(link, "item:(%d+)"))
        if wantItem == self.HIDDEN_ITEM_ID and (id == 57575 or id == 9172) then
            self.chromieApplyClicked = true
            BuyMerchantItem(i)
            return
        end
        if wantItem == 0 and (id == 57576 or id == 1049) then
            self.chromieApplyClicked = true
            BuyMerchantItem(i)
            return
        end
        if id == wantItem then
            self.chromieApplyClicked = true
            BuyMerchantItem(i)
            return
        end
        i = i + 1
    end
    self:Chat("Apply failed: appearance not on the vendor page")
    self.chromieJob = "open"
    if self.ChromieAbortMultiApply then
        self:ChromieAbortMultiApply()
    end
    self:calculateCost()
end

function Transmog:ChromieOnGossipShow()
    if not self:ChromieShouldIntercept() then
        return
    end

    -- A new hello is in progress. Clear this before HideBlizzard or the
    -- waiting flag lets GossipFrame_OnHide CloseGossip and the click is wasted.
    self.chromieWaitingForNpc = nil

    local known, npcId, guid = self:ChromieIsKnownNpc()
    self:ChromieGetOptions()
    if self.ChromieLogSnapshot then
        self:ChromieLog("EVENT GOSSIP_SHOW known=" .. tostring(known) .. " id=" .. tostring(npcId) .. " guid=" .. tostring(guid))
        self:ChromieLogSnapshot("GOSSIP_SHOW")
    end

    if self.probeActive then
        if self.ChromieProbeGotEvent then
            if self.probeWaiting then
                self:ChromieProbeGotEvent("gossip")
            elseif not self.probeClicked then
                self:ChromieProbeTick()
            end
        end
        return
    end

    local options = self.chromieLastOptions
    local onMainMenu = options and self:ChromieCountSlots(options) >= 3
    if onMainMenu then
        self:ChromieIngestMainMenuStatus(options)
    end

    local justOpened = false
    if not ChromieTransmogFrame:IsShown() then
        self:ChromieOpenUI()
        justOpened = true
    end
    -- Overlay must be shown before Hide(), or GossipFrame_OnHide CloseGossip kills the session.
    self:ChromieHideBlizzard()

    if justOpened and not onMainMenu and self.chromieJob ~= "apply" and self.chromieJob ~= "load" then
        if self:ChromieClickBack("open-need-main") then
            self.chromieJob = "open"
            return
        end
    end

    if self.chromieJob == "load" then
        self:ChromieHandleLoadGossip()
    elseif self.chromieJob == "apply" then
        if self.chromieApplyClicked then
            -- Slot menu refresh after a confirmed hide/remove/apply.
            -- Selecting "Remove" again reopens the popup and errors "no transmog found".
            self.chromieApplyClicked = nil
            self:ChromieHideGossipConfirm()
            self:ChromieFinishApply(true)
            return
        end
        self:ChromieHandleApplyGossip()
    else
        self:ChromieDumpOptions("idle")
    end
end

function Transmog:ChromieOnMerchantShow()
    if not self:ChromieShouldIntercept() then
        return
    end
    self.chromieVendorOpen = true
    self.chromieWaitingForNpc = nil
    if self.ChromieLogSnapshot then
        self:ChromieLog("EVENT MERCHANT_SHOW")
        self:ChromieLogSnapshot("MERCHANT_SHOW")
    end

    if self.probeActive then
        if self.ChromieProbeGotEvent and self.probeWaiting then
            self:ChromieProbeGotEvent("merchant")
        end
        return
    end

    self:ChromieHideBlizzard()

    if self.chromieJob == "load" then
        local n = GetMerchantNumItems() or 0
        if self.ChromieLog then
            self:ChromieLog("Vendor interface with " .. n .. " items")
        end
        local i = 1
        while i <= n do
            local link = GetMerchantItemLink(i)
            local id = link and tonumber(string.match(link, "item:(%d+)"))
            if id and not VENDOR_SKIP[id] then
                self:ChromieAddCached(self.chromieLoadSlot, id)
            end
            i = i + 1
        end
        self:ChromiePublish(self.chromieLoadSlot)
        self.chromieJob = "open"
    elseif self.chromieJob == "apply" then
        self:ChromieHandleApplyMerchant()
    end
end

function Transmog:ChromieOnGossipClosed()
    if self.ChromieLogSnapshot then
        self:ChromieLog("EVENT GOSSIP_CLOSED")
        self:ChromieLogSnapshot("GOSSIP_CLOSED")
    end
    if self.probeActive and self.ChromieProbeGotEvent and self.probeWaiting then
        self:ChromieProbeGotEvent("closed")
        return
    end
    if self.chromieJob == "apply" then
        if self.chromieApplyClicked then
            self.chromieApplyClicked = nil
            self:ChromieFinishApply(true)
        end
        return
    end
    -- Hiding GossipFrame used to CloseGossip and collapse the overlay mid-scrape.
    if self.chromieJob == "load" or self.chromieJob == "probe" then
        if self.ChromieLog then
            self:ChromieLog("GOSSIP_CLOSED ignored job=" .. tostring(self.chromieJob))
        end
        return
    end
    if ChromieTransmogFrame:IsShown() and not UnitExists("npc") then
        ChromieTransmogFrame:Hide()
    end
end

function Transmog:ChromieOpenUI()
    self:ChromieInitStatus()
    if self.chromieJob ~= "probe" and self.chromieJob ~= "apply" and self.chromieJob ~= "load" then
        self.chromieJob = "open"
    end
    ChromieTransmogFrame:Show()
    if self.ChromieLog then
        self:ChromieLog("UI opened")
    end
end

function Transmog:ChromieEnsureSlot(slot)
    if self.probeActive then
        if self.ChromieLog then
            self:ChromieLog("EnsureSlot " .. tostring(slot) .. " skipped (probe mode)")
        end
        return
    end
    if self.chromieCache[slot] and self.chromieCache[slot][1] then
        self:ChromiePublish(slot)
        return
    end
    if self.chromieJob == "load" then
        return
    end
    ChromieTransmogFrameNoTransmogs:SetText("Loading appearances from the transmog NPC...")
    ChromieTransmogFrameNoTransmogs:Show()
    self.chromieJob = "load"
    self.chromieLoadSlot = slot
    self.chromieLoadEnteredSlot = nil
    self.chromiePages = 0
    self.chromieCache[slot] = {}
    if self.ChromieLog then
        self:ChromieLog("EnsureSlot " .. tostring(slot) .. " starting gossip/vendor load")
    end
    self:ChromieHandleLoadGossip()
end

function Transmog:ChromieStartApply(slot, itemId)
    if itemId == self.UNKNOWN_MOG_ID then
        return
    end
    self.chromieJob = "apply"
    self.chromieApplySlot = slot
    self.chromieApplyItem = itemId
    self.chromieApplyPages = 0
    self.chromieApplyEnteredSlot = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = nil
    self.chromieWaitingForNpc = nil
    ChromieTransmogFrameApplyButton:Disable()
    if self.ChromieLog then
        self:ChromieLog("Applying item " .. tostring(itemId) .. " to slot " .. tostring(slot))
    end
    if self.chromieMultiActive and self.ChromieUpdateApplyProgress then
        self:ChromieUpdateApplyProgress(true)
    end
    if self.chromieVendorOpen then
        self:ChromieHandleApplyMerchant()
        return
    end
    self:ChromieHandleApplyGossip()
end

function Transmog:ChromieFinishApply(ok)
    local slot = self.chromieApplySlot
    local itemId = self.chromieApplyItem
    self.chromieVendorOpen = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = true
    self:ChromieHideGossipConfirm()
    if ok and slot then
        self.transmogStatusFromServer[slot] = itemId
        self.transmogStatusToServer[slot] = itemId
        if self.RefreshPendingGlows then
            self:RefreshPendingGlows()
        end
        if itemId == 0 then
            self:addTransmogAnim(slot, "reset")
            if self.ChromieForgetMog then
                self:ChromieForgetMog(GetInventoryItemLink("player", slot))
            end
        else
            self:addTransmogAnim(slot)
            if self.ChromieRememberMog then
                self:ChromieRememberMog(GetInventoryItemLink("player", slot), itemId == self.HIDDEN_ITEM_ID)
            end
        end
        if self.chromieMultiActive then
            self.chromieMultiDone = (self.chromieMultiDone or 0) + 1
        end
    end

    local nextSlot, nextItem = self:ChromieNextPendingApply()
    if nextSlot then
        self.chromieJob = "apply"
        self.chromieApplySlot = nextSlot
        self.chromieApplyItem = nextItem
        self.chromieApplyPages = 0
        self.chromieApplyEnteredSlot = nil
        self.chromieApplyClicked = nil
        self.chromieGossipConfirmed = nil
        ChromieTransmogFrameApplyButton:Disable()
        ChromieTransmogFrameApplyButton:SetText("Talk to Warpweaver")
        if self.ChromieUpdateApplyProgress then
            self:ChromieUpdateApplyProgress(false)
        else
            local pending = select(1, self:ChromiePendingCost())
            self:Chat("Talk to Warpweaver to apply the next slot (" .. tostring(pending) .. " remaining).")
        end
        self:calculateCost()
        ChromieTransmogFrameApplyButton:Disable()
        ChromieTransmogFrameApplyButton:SetText("Talk to Warpweaver")
        self.chromieWaitingForNpc = true
        self:ChromieForceCloseGossip()
        return
    end

    self.chromieJob = "open"
    PlaySoundFile("Interface\\AddOns\\ChromieTransmog\\assets\\ui_transmogrify_apply.ogg", "Dialog")
    self:transmogStatus()
    if self.RefreshPendingGlows then
        self:RefreshPendingGlows()
    end
    if self.chromieMultiActive and self.ChromieUpdateApplyProgress then
        self:ChromieUpdateApplyProgress(false)
        self.chromieMultiActive = nil
        if self.applyProgressFrame then
            self.applyProgressFrame.text:SetText("All queued transmogs applied.")
        end
        if not self.applyProgressHider then
            local hide = CreateFrame("Frame")
            hide:Hide()
            hide:SetScript("OnUpdate", function()
                if GetTime() >= (Transmog.applyProgressHideAt or 0) then
                    this:Hide()
                    Transmog:ChromieAbortMultiApply()
                end
            end)
            self.applyProgressHider = hide
        end
        self.applyProgressHideAt = GetTime() + 1.6
        self.applyProgressHider:Show()
    end
    self:calculateCost()
end

Transmog:ChromiePatchBlizzardClose()

if GossipFrame and GossipFrame.HookScript then
    GossipFrame:HookScript("OnShow", function()
        if Transmog:ChromieKeepGossipAlive() then
            Transmog.chromieWaitingForNpc = nil
            Transmog:ChromieHideBlizzard()
        end
    end)
end

if MerchantFrame and MerchantFrame.HookScript then
    MerchantFrame:HookScript("OnShow", function()
        if Transmog:ChromieKeepGossipAlive() then
            Transmog.chromieWaitingForNpc = nil
            Transmog:ChromieHideBlizzard()
        end
    end)
end
