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
    if self.CHAT_PRINTS ~= 1 then
        return
    end
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
    return self.chromieJob == "load" or self.chromieJob == "apply" or self.chromieJob == "open" or self:ChromieIsSetJob()
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

    if not self.chromieWrappedPopupShow and StaticPopup_Show then
        self.chromieWrappedPopupShow = true
        local orig = StaticPopup_Show
        StaticPopup_Show = function(which, text_arg1, text_arg2, data)
            local popup = orig(which, text_arg1, text_arg2, data)
            if Transmog.chromieJob == "sets-price"
                and not Transmog.chromieSetPriceCaptured
                and (which == "GOSSIP_CONFIRM" or which == "GOSSIP_CONFIRM_MONEY" or which == "GOSSIP_ENTER_CODE") then
                Transmog:ChromieDimGossipConfirm()
                Transmog:ChromieScheduleSetPriceCapture()
            end
            return popup
        end
    end

    if not self.chromiePatchedMoneyFrame and MoneyFrame_Update then
        self.chromiePatchedMoneyFrame = true
        hooksecurefunc("MoneyFrame_Update", function(frame, money)
            if Transmog.chromieJob ~= "sets-price" or Transmog.chromieSetPriceCaptured then
                return
            end
            local name = frame
            if type(frame) == "table" and frame.GetName then
                name = frame:GetName()
            end
            if type(name) ~= "string" or not string.find(name, "StaticPopup", 1, true) then
                return
            end
            local copper = tonumber(money)
            -- The popup money frame first paints bag gold; the NPC cost comes after.
            if copper and copper ~= GetMoney() then
                Transmog.chromieSetSaveCopper = copper
            end
            Transmog:ChromieDimGossipConfirm()
            Transmog:ChromieScheduleSetPriceCapture()
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
    return self.chromieJob == "apply" or self.chromieJob == "load" or self.chromieJob == "open" or self:ChromieIsSetJob()
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

function Transmog:ChromieParseGossipItemId(text, stripped)
    if not text or text == "" then
        return nil
    end
    local id = tonumber(string.match(text, "|Hitem:(%d+)"))
    if not id then
        id = tonumber(string.match(text, "item:(%d+)"))
    end
    if id and id > 1 then
        return id
    end
    return nil
end

-- ChromieCraft azerothcore/mod-transmog gossip via GetGossipOptions() (3.3.5):
-- Pairs of (text, optionType). Type is usually "banker". Text often has |Tpath:30:30:-18:0|t
-- before the label; chat/copy may strip |T so a log line looks like "Head" only.
--
-- Main menu slot row: |T<icon>|tHead (etc). No |Hitem:id|.
--   paperdoll icon => not mogged; Interface/ICONS/WoWUnknownItem01 => hidden;
--   any other icon => mogged, but the current mog item id is NOT sent.
-- Appearance page: |T<icon>|t|Hitem:id|h[Name]|h|r, plus Hide Slot / Next Page / Back...
-- Set list: set names (may have |T), Save set, Back...
-- Set view: literal "(Hidden)", or [Name] with item id, plus Use this set / Delete set / Back...
-- TryOn needs a real appearance item id. That only exists on appearance rows and set-view item rows.
function Transmog:ChromieGetOptions()
    local raw = { GetGossipOptions() }
    local list = {}
    local i = 1
    local n = 0
    while raw[i] do
        n = n + 1
        local text = raw[i] or ""
        local stripped = self:ChromieStrip(text)
        list[n] = {
            index = n,
            text = text,
            stripped = stripped,
            kind = raw[i + 1],
            itemId = self:ChromieParseGossipItemId(text, stripped),
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
    if string.find(t, "save set", 1, true) then
        flags.saveSet = true
    end
    if string.find(t, "use this set", 1, true) or t == "use set" then
        flags.useSet = true
    end
    if string.find(t, "delete set", 1, true) then
        flags.deleteSet = true
    end
    if string.find(t, "how sets", 1, true) then
        flags.howSets = true
        flags.nav = true
    end
    if string.find(t, "how does", 1, true) or string.find(t, "update menu", 1, true) or string.find(t, "manage", 1, true) then
        flags.nav = true
        if string.find(t, "set", 1, true) then
            flags.manageSets = true
        end
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

function Transmog:ChromieTextureFromGossipText(text)
    if not text or text == "" then
        return nil
    end
    text = string.gsub(text, "||T", "|T")
    text = string.gsub(text, "||t", "|t")
    text = string.gsub(text, "\124T", "|T")
    text = string.gsub(text, "\124t", "|t")
    local inner = string.match(text, "|T(.-)|t")
    if inner then
        return string.match(inner, "^([^:]+)") or inner
    end
    return string.match(text, "|T([^:]+)")
end

function Transmog:ChromieParseSlotTexture(text)
    local path = self:ChromieTextureFromGossipText(text)
    if not path then
        return nil, "missing"
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
-- Main-menu |T is the only signal for "this slot is mogged/hidden/empty".
-- kind empty = paperdoll icon; hidden = WoWUnknownItem01; mog = other icon (id still unknown).
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
                if self.ChromieAppliedSet then
                    self:ChromieAppliedSet(slot, self.HIDDEN_ITEM_ID)
                end
            elseif kind == "mog" then
                detected = self.UNKNOWN_MOG_ID
                self.transmogGossipIcon[slot] = self:ChromieGossipTextureToFile(path)
                local applied = self.ChromiePersistGetApplied and self:ChromiePersistGetApplied(slot)
                if applied and applied > 1 then
                    detected = applied
                    if not self.applied then
                        self.applied = {}
                    end
                    self.applied[slot] = applied
                elseif applied == self.HIDDEN_ITEM_ID then
                    detected = self.HIDDEN_ITEM_ID
                else
                    local prev = self.transmogStatusFromServer[slot]
                    if prev and prev > self.HIDDEN_ITEM_ID then
                        detected = prev
                    end
                end
            elseif kind == "empty" then
                self.transmogGossipIcon[slot] = nil
                -- Paperdoll icon: Warpweaver says this slot is not mogged.
                -- Do not keep session fromServer / owned[] from a previous set.
                detected = 0
                if self.ChromieAppliedSet then
                    self:ChromieAppliedSet(slot, 0)
                end
            else
                -- Missing |T: keep previous applied ids; do not treat as unmogged.
            end

            if kind ~= "missing" then
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
                summary = summary .. " " .. slot .. "=" .. tostring(kind)
            else
                summary = summary .. " " .. slot .. "=missing"
            end
        end
        i = i + 1
    end
    if self.ChromieLog and summary ~= "" then
        self:ChromieLog("Main-menu status" .. summary)
    end
    if overlayOpen and self.PreviewCacheInit then
        if self.ChromieHydrateFromApplied then
            self:ChromieHydrateFromApplied()
        end
        self:PreviewCacheInit()
    end
    if changed or not overlayOpen then
        if not overlayOpen or not self:ChromieHasPending() then
            self:transmogStatus()
        end
    end
    if self.ChromieUpdateCanSaveSet then
        self:ChromieUpdateCanSaveSet(options)
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
    self.chromieRemoveAll = nil
    self.chromieRemoveAllSlots = nil
    self.chromiePendingSet = nil
    self.chromieSetSaveName = nil
    self.chromieSetViewName = nil
    if self.ChromieHideSetCreate then
        self:ChromieHideSetCreate()
    end
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

function Transmog:ChromieAddCached(slot, itemId, iconPath)
    if not slot or not itemId or itemId == 0 then
        return
    end
    if not self.chromieCache[slot] then
        self.chromieCache[slot] = {}
    end
    if iconPath then
        if not self.chromieCacheIcon then
            self.chromieCacheIcon = {}
        end
        if not self.chromieCacheIcon[slot] then
            self.chromieCacheIcon[slot] = {}
        end
        self.chromieCacheIcon[slot][itemId] = iconPath
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
    if self:ChromieIsSetMenu(options) then
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
    if self.chromieSetBackSent then
        return true
    end
    local idx = self:ChromieFindFlagIndex(self:ChromieGetOptions(), "back")
    if not idx then
        return false
    end
    if self.ChromieLog then
        self:ChromieLog("SelectGossipOption(" .. idx .. ") Back... (" .. tostring(reason) .. ")")
    end
    self.chromieSetBackSent = true
    SelectGossipOption(idx)
    return true
end

function Transmog:ChromieFinishLoad()
    local slot = self.chromieLoadSlot
    local n = slot and self:tableSize(self.chromieCache[slot] or {}) or 0
    if slot and self.ChromieFinishSlotScan then
        self:ChromieFinishSlotScan(slot)
    end
    local setCachePending = self.ChromieSetCacheOnLoadDone and self:ChromieSetCacheOnLoadDone(slot)
    if slot then
        self:ChromiePublish(slot)
    end
    self.chromieJob = "open"
    self.chromieLoadEnteredSlot = nil
    self.chromieLoadSlot = nil
    ChromieTransmogFrameNoTransmogs:Hide()
    -- Wait for main-menu GOSSIP_SHOW before the next queued scan. Starting the
    -- next load in this frame still sees the previous appearance page and
    -- finishes with 0 items.
    if not setCachePending and self.setCacheJob and self.setCacheJob.pendingNext then
        self.chromieScanQueuePending = true
    elseif not setCachePending and self.chromieScanQueue and self.chromieScanQueue[1] then
        self.chromieScanQueuePending = true
    elseif not setCachePending and self.chromieEmptyCacheScan and not self.chromieScanRescanDone then
        -- Same as clicking Scan all again: mogged slots can go OK once cache is filled.
        self.chromieScanRescanDone = true
        if self.ChromieQueueUnscannedSessionSlots then
            self:ChromieQueueUnscannedSessionSlots(true)
        end
        if self.chromieScanQueue and self.chromieScanQueue[1] then
            self.chromieScanQueuePending = true
        end
    end
    if not self:ChromieClickBack("load-done") then
        if setCachePending and self.setCacheJob and self.setCacheJob.pendingNext and self.ChromieDeferSetCacheScanNext then
            self.setCacheJob.pendingNext = nil
            self:ChromieDeferSetCacheScanNext()
        elseif self.chromieScanQueuePending and self.ChromieProcessScanQueue then
            self.chromieScanQueuePending = nil
            self:ChromieProcessScanQueue()
        end
    end
end

-- Appearance gossip page: each look is |Hitem:id| (and usually |T). Hide/nav rows have no id.
function Transmog:ChromieIngestAppearancePage(wantSlot, options)
    local added = 0
    local nextIndex = nil
    local i = 1
    while options[i] do
        local opt = options[i]
        local flags = self:ChromieOptionFlags(opt)
        if opt.itemId then
            local path = self:ChromieTextureFromGossipText(opt.text)
            local before = self:tableSize(self.chromieCache[wantSlot] or {})
            self:ChromieAddCached(wantSlot, opt.itemId, path)
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

    if self:ChromieIsSetMenu(options) then
        self:ChromieClickBack("load-from-set")
        return
    end

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
    StaticPopup_Hide("GOSSIP_ENTER_CODE")
end

function Transmog:ChromieAutoConfirmGossipPopup(which)
    if which ~= "GOSSIP_CONFIRM" and which ~= "GOSSIP_CONFIRM_MONEY" and which ~= "GOSSIP_ENTER_CODE" then
        return
    end
    -- Vanilla Warpweaver confirms (hide / paid mog) must stay when overlay is off.
    if not self.overlayEnabled or self.probeActive then
        return
    end
    if self.chromieJob == "sets-price" then
        self:ChromieDimGossipConfirm()
        self:ChromieScheduleSetPriceCapture()
        return
    end
    local setJob = self:ChromieIsSetJob()
    if (self.chromieJob ~= "apply" and not setJob) or not self.chromieApplyClicked then
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
            if not name then
                name = StaticPopup_Visible("GOSSIP_ENTER_CODE")
            end
            if name then
                if Transmog.chromieSetSaveName then
                    local box = getglobal(name .. "EditBox")
                    if box then
                        box:SetText(Transmog.chromieSetSaveName)
                    end
                end
                local btn = getglobal(name .. "Button1")
                if btn then
                    btn:Click()
                end
            end
            if Transmog.chromieJob == "sets-use" then
                Transmog.chromieSetUseApplied = true
                if Transmog.ChromieSetCacheDbg then
                    Transmog:ChromieSetCacheDbg("confirm apply set=\"" .. tostring(Transmog.chromieSetViewName) .. "\"")
                end
                Transmog:ChromieKickSetReturn()
            elseif Transmog.chromieJob == "sets-delete" then
                Transmog:ChromieKickSetReturn()
            end
        end)
        self.gossipConfirmClicker = f
    end
    self.gossipConfirmClicker:Show()
end

function Transmog:ChromieDimGossipConfirm()
    local i = 1
    while i <= 4 do
        local f = getglobal("StaticPopup" .. i)
        if f and f:IsShown() then
            local which = f.which
            if which == "GOSSIP_CONFIRM" or which == "GOSSIP_CONFIRM_MONEY" or which == "GOSSIP_ENTER_CODE" then
                f:SetAlpha(0)
                if f.EnableMouse then
                    f:EnableMouse(false)
                end
            end
        end
        i = i + 1
    end
end

function Transmog:ChromieCloakGossipConfirm()
    self:ChromieDimGossipConfirm()
    self:ChromieHideGossipConfirm()
    local i = 1
    while i <= 4 do
        local f = getglobal("StaticPopup" .. i)
        if f then
            f:SetAlpha(1)
            if f.EnableMouse then
                f:EnableMouse(true)
            end
        end
        i = i + 1
    end
end

function Transmog:ChromieOnGossipConfirm(index, text, money)
    if self.chromieJob ~= "sets-price" or self.chromieSetPriceCaptured then
        return
    end
    local copper = tonumber(money)
    if copper and copper ~= GetMoney() then
        self.chromieSetSaveCopper = copper
    end
    self:ChromieScheduleSetPriceCapture()
end

function Transmog:ChromieReadPopupCopper(frameName)
    if not frameName then
        return nil
    end
    local goldBtn = getglobal(frameName .. "MoneyFrameGoldButton")
    local silverBtn = getglobal(frameName .. "MoneyFrameSilverButton")
    local copperBtn = getglobal(frameName .. "MoneyFrameCopperButton")
    if goldBtn or silverBtn or copperBtn then
        local function digits(btn)
            if not btn then
                return 0
            end
            local raw = btn:GetText() or ""
            raw = string.gsub(raw, "[^0-9]", "")
            return tonumber(raw) or 0
        end
        return digits(goldBtn) * 10000 + digits(silverBtn) * 100 + digits(copperBtn)
    end
    local popup = getglobal(frameName)
    local mf = popup and getglobal(frameName .. "MoneyFrame")
    if mf and type(mf.staticMoney) == "number" then
        return mf.staticMoney
    end
    return nil
end

function Transmog:ChromieScheduleSetPriceCapture()
    if self.chromieSetPriceCaptured or self.chromieJob ~= "sets-price" then
        return
    end
    if not self.setSaveCostCapture then
        local f = CreateFrame("Frame")
        f:Hide()
        f:SetScript("OnUpdate", function()
            this.n = (this.n or 0) + 1
            Transmog:ChromieDimGossipConfirm()
            if this.n < 2 then
                return
            end
            local vis = StaticPopup_Visible("GOSSIP_CONFIRM")
            if not vis then
                vis = StaticPopup_Visible("GOSSIP_CONFIRM_MONEY")
            end
            local scraped = vis and Transmog:ChromieReadPopupCopper(vis)
            if scraped and scraped == GetMoney() and (not Transmog.chromieSetSaveCopper or Transmog.chromieSetSaveCopper == GetMoney()) and this.n < 5 then
                return
            end
            this:Hide()
            this.n = 0
            Transmog:ChromieCaptureSetPrice()
        end)
        self.setSaveCostCapture = f
    end
    if not self.setSaveCostCapture:IsShown() then
        self.setSaveCostCapture.n = 0
        self.setSaveCostCapture:Show()
    end
end

function Transmog:ChromieCaptureSetPrice()
    if self.chromieSetPriceCaptured or self.chromieJob ~= "sets-price" then
        return
    end
    local vis = StaticPopup_Visible("GOSSIP_CONFIRM")
    if not vis then
        vis = StaticPopup_Visible("GOSSIP_CONFIRM_MONEY")
    end
    if not vis then
        vis = StaticPopup_Visible("GOSSIP_ENTER_CODE")
    end
    local scraped = vis and self:ChromieReadPopupCopper(vis)
    if scraped and scraped ~= GetMoney() then
        self.chromieSetSaveCopper = scraped
    elseif scraped and self.chromieSetSaveCopper == nil then
        self.chromieSetSaveCopper = scraped
    end
    if not vis and self.chromieSetSaveCopper == nil then
        return
    end
    self.chromieSetPriceCaptured = true
    self.chromieSetSaveCopper = self.chromieSetSaveCopper or 0
    self:ChromieCloakGossipConfirm()
    if self.ChromieUpdateManageSetPrice then
        self:ChromieUpdateManageSetPrice()
    end
    self.chromieSetViewPhase = "returning"
    self:ChromieClickBack("sets-price-done")
    self:ChromieKickSetReturn()
end

function Transmog:ChromieHandleApplyGossip()
    local options = self:ChromieGetOptions()
    self:ChromieDumpOptions("apply")
    local wantSlot = self.chromieApplySlot
    local wantItem = self.chromieApplyItem

    if self:ChromieIsSetMenu(options) then
        self:ChromieClickBack("apply-from-set")
        return
    end

    if self.chromieRemoveAll then
        if self:ChromieCountSlots(options) >= 3 then
            local idx = self:ChromieFindFlagIndex(options, "remove")
            if idx then
                self.chromieApplyClicked = true
                self.chromieGossipConfirmed = nil
                if self.ChromieLog then
                    self:ChromieLog("SelectGossipOption(" .. idx .. ") Remove all transmogrifications")
                end
                SelectGossipOption(idx)
                return
            end
            self:Chat("Remove all transmogrifications was not on the menu.")
            self.chromieRemoveAll = nil
            self.chromieJob = "open"
            self:calculateCost()
            if self.ChromiePromptFinish then
                self:ChromiePromptFinish()
            end
            return
        end
        if self:ChromieClickBack("remove-all-need-main") then
            return
        end
        self:Chat("Apply failed: could not reach the main transmog menu.")
        self.chromieRemoveAll = nil
        self.chromieJob = "open"
        self:calculateCost()
        if self.ChromiePromptFinish then
            self:ChromiePromptFinish()
        end
        return
    end

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

function Transmog:ChromieIsSetJob()
    local job = self.chromieJob
    return job == "sets-list" or job == "sets-view" or job == "sets-save" or job == "sets-use" or job == "sets-delete" or job == "sets-price"
end

function Transmog:ChromieIsSetNameOption(opt)
    if not opt then
        return false
    end
    local flags = self:ChromieOptionFlags(opt)
    if flags.nav or flags.saveSet or flags.useSet or flags.deleteSet
        or flags.hide or flags.remove or flags.search or flags.manageSets then
        return false
    end
    local lower = string.lower(opt.text or "")
    return string.find(lower, "statue_02", 1, true) and true or false
end

function Transmog:ChromieGossipKind()
    local options = self.chromieLastOptions or self:ChromieGetOptions()
    if self:ChromieCountSlots(options) >= 3 then
        return "main"
    end
    if self:ChromieFindFlagIndex(options, "useSet") or self:ChromieFindFlagIndex(options, "deleteSet") then
        return "set-view"
    end
    local hasSave = self:ChromieFindFlagIndex(options, "saveSet")
    local hasItems = false
    local hasSetName = false
    local i = 1
    while options[i] do
        if options[i].itemId then
            hasItems = true
        elseif self:ChromieIsSetNameOption(options[i]) then
            hasSetName = true
        end
        i = i + 1
    end
    if hasSave and hasItems then
        return "set-save"
    end
    if hasSave or self:ChromieFindFlagIndex(options, "howSets") or hasSetName then
        return "set-list"
    end
    return "other"
end

function Transmog:ChromieIsSetMenu(options)
    options = options or self.chromieLastOptions
    if not options then
        return false
    end
    if self:ChromieCountSlots(options) >= 3 then
        return false
    end
    if self:ChromieFindFlagIndex(options, "useSet") or self:ChromieFindFlagIndex(options, "deleteSet") then
        return true
    end
    if self:ChromieFindFlagIndex(options, "saveSet") or self:ChromieFindFlagIndex(options, "howSets") then
        return true
    end
    local i = 1
    while options[i] do
        if self:ChromieIsSetNameOption(options[i]) then
            return true
        end
        i = i + 1
    end
    return false
end

function Transmog:ChromieKickSetReturn()
    if not self.setReturnKicker then
        local f = CreateFrame("Frame")
        f:Hide()
        f:SetScript("OnUpdate", function()
            this.elapsed = (this.elapsed or 0) + arg1
            if this.elapsed < 0.2 then
                return
            end
            this.elapsed = 0
            this.ticks = (this.ticks or 0) + 1
            if this.ticks > 12 then
                this:Hide()
                return
            end
            local job = Transmog.chromieJob
            if job == "sets-use" then
                Transmog:ChromieHandleSetsUseGossip()
            elseif job == "sets-delete" then
                Transmog:ChromieHandleSetsDeleteGossip()
            elseif job == "sets-view" then
                Transmog:ChromieHandleSetsViewGossip()
            elseif job == "sets-price" then
                Transmog:ChromieHandleSetsPriceGossip()
            elseif job == "sets-save" then
                Transmog:ChromieHandleSetsSaveGossip()
            else
                this:Hide()
            end
        end)
        self.setReturnKicker = f
    end
    self.setReturnKicker.elapsed = 0
    self.setReturnKicker.ticks = 0
    self.setReturnKicker:Hide()
    self.setReturnKicker:Show()
end

function Transmog:ChromieGossipReady()
    local options = self:ChromieGetOptions()
    if self:tableSize(options) > 0 then
        return true
    end
    -- Use this set leaves the same view open; a Back... can be in flight
    -- with empty GetGossipOptions until the next page arrives.
    if self.chromieSetBackSent or self.chromieSetUseApplied or self.chromieSetViewPhase == "returning" then
        return false
    end
    self:Chat("Talk to Warpweaver to continue.")
    self.chromieWaitingForNpc = true
    self.chromieJob = "open"
    self.chromieApplyClicked = nil
    if self.calculateCost then
        self:calculateCost()
    end
    return false
end

function Transmog:ChromieFindSetNameIndex(options, name)
    local i = 1
    while options[i] do
        if self:ChromieIsSetNameOption(options[i]) and options[i].stripped == name then
            return options[i].index
        end
        i = i + 1
    end
    return nil
end

function Transmog:ChromieGuessSlotForItem(itemId, used)
    if not itemId or itemId == self.HIDDEN_ITEM_ID then
        return nil
    end
    self:cacheItem(itemId)
    local _, _, _, _, _, _, _, _, invType = GetItemInfo(itemId)
    if not invType then
        return nil
    end
    if invType == "INVTYPE_WEAPON" then
        if not used[16] then
            return 16
        end
        if not used[17] then
            return 17
        end
        return 16
    end
    local frame = self:frameFromInvType(invType)
    if frame then
        return self.inventorySlots[frame:GetName()]
    end
    return nil
end

-- Set-view scrape: rows are "(Hidden)" or [Item Name] with itemId. No slot labels;
-- slot is guessed from item equip location. Hidden rows cannot be mapped to a slot here.
function Transmog:ChromieParseSetItems(options)
    local items = {}
    local used = {}
    local i = 1
    while options[i] do
        local id = options[i].itemId
        if id then
            local slot = self:ChromieGuessSlotForItem(id, used)
            if slot then
                items[slot] = id
                used[slot] = true
            elseif id > 1 then
                items["id" .. id] = id
            end
        end
        i = i + 1
    end
    return items
end

function Transmog:ChromieScrapeSetNames()
    local options = self.chromieLastOptions or self:ChromieGetOptions()
    local scraped = {}
    local i = 1
    while options[i] do
        if self:ChromieIsSetNameOption(options[i]) then
            table.insert(scraped, options[i].stripped)
        end
        i = i + 1
    end
    if not scraped[1] then
        return
    end
    self.chromieSets = scraped
    if self.ChromiePersistSetNames then
        self:ChromiePersistSetNames(self.chromieSets)
    end
end

function Transmog:ChromieStoreSetItems(name, items)
    if not name then
        return
    end
    -- Set-view scrape can be empty after reload (GetItemInfo cold). Never
    -- replace a cached slot map with that scrape.
    if self.ChromieSetIsCached and self:ChromieSetIsCached(name) then
        return
    end
    if not self.chromieSetItems then
        self.chromieSetItems = {}
    end
    self.chromieSetItems[name] = items
    if self.chromiePendingSet and self.chromiePendingSet.name == name then
        self.chromiePendingSet.items = items
    end
end

function Transmog:ChromieFinishSetJob()
    local wantUse = self.chromieWantSetUse
    self.chromieWantSetUse = nil
    local wantPrice = self.chromieWantSetPrice and self.manageSetsOpen
    self.chromieWantSetPrice = nil
    self.chromieJob = "open"
    self.chromieApplyClicked = nil
    self.chromieSetViewPhase = nil
    self.chromieSetsGotList = nil
    self.chromieSetSaveName = nil
    self.chromieSetSaveAccepted = nil
    self.chromieSetSavePrompted = nil
    self.chromieSetSaveIndex = nil
    self.chromieSetSaveCancelling = nil
    self.chromieSetPriceCaptured = nil
    self.chromieSetPriceClicked = nil
    self.chromieSetUseApplied = nil
    self.chromieSetBackSent = nil
    if self.setReturnKicker then
        self.setReturnKicker:Hide()
    end
    if self.ChromieRefreshSetsDropdown then
        self:ChromieRefreshSetsDropdown()
    end
    if self.ChromieRefreshManageSets then
        self:ChromieRefreshManageSets()
    end
    if self.ChromieUpdateCanSaveSet then
        self:ChromieUpdateCanSaveSet()
    end
    if self.ChromieUpdateManageSetPrice then
        self:ChromieUpdateManageSetPrice()
    end
    if wantUse then
        self:ChromieStartSetUse(wantUse)
        return
    end
    if wantPrice then
        self:ChromieStartSetPrice()
        return
    end
    local queued = self.chromieQueuedSlot
    self.chromieQueuedSlot = nil
    if queued then
        self:ChromieEnsureSlot(queued)
        return
    end
    if self.chromieScanQueue and self.chromieScanQueue[1] then
        if self.ChromieDeferProcessScanQueue then
            self:ChromieDeferProcessScanQueue()
        elseif self.ChromieProcessScanQueue then
            self:ChromieProcessScanQueue()
        end
        return
    end
    if self.ChromieTryCacheUnknownSets and self:ChromieTryCacheUnknownSets() then
        return
    end
    if self.ChromieCacheSyncMaybePrompt then
        self:ChromieCacheSyncMaybePrompt()
    end
end

function Transmog:ChromieApplySetItemsLocally(name)
    local items = self.ChromieSetItemsForName and self:ChromieSetItemsForName(name)
    if not items then
        items = self.chromieSetItems and self.chromieSetItems[name]
    end
    if items then
        local slot, itemId
        for slot, itemId in pairs(items) do
            slot = tonumber(slot)
            itemId = tonumber(itemId)
            if slot and itemId and (itemId > 1 or itemId == self.HIDDEN_ITEM_ID) then
                -- Cached set maps can include slots from a previous snapshot.
                -- Only stamp slots gossip/live still report as mogged.
                local have = self.transmogStatusFromServer and self.transmogStatusFromServer[slot]
                local gossip = self.transmogGossipIcon and self.transmogGossipIcon[slot]
                local liveMog = self.ChromieSlotTextureIsMogged and self:ChromieSlotTextureIsMogged(slot)
                local liveHidden = self.ChromieSlotTextureIsHidden and self:ChromieSlotTextureIsHidden(slot)
                if have == self.HIDDEN_ITEM_ID or have == self.UNKNOWN_MOG_ID
                    or (have and have > 1) or gossip or liveMog or liveHidden then
                    self.transmogStatusFromServer[slot] = itemId
                    self.transmogStatusToServer[slot] = itemId
                    if itemId > 1 and self.cacheItem then
                        self:cacheItem(itemId)
                    end
                end
            end
        end
    end
    if self.ChromieAppliedCopyFromSet then
        self:ChromieAppliedCopyFromSet(name)
    end
    if self.transmogStatus then
        self:transmogStatus()
    end
end

function Transmog:ChromieRefreshUiAfterSetUse(name)
    if self.ChromieHideManageSets then
        self:ChromieHideManageSets()
    end
    selectTransmogSlot(-1)
    ChromieTransmogFrameNoTransmogs:Hide()
    ChromieTransmogFrameCollectedText:Hide()

    local items = self.ChromieSetItemsForName and self:ChromieSetItemsForName(name)
    if not items then
        items = self.chromieSetItems and self.chromieSetItems[name]
    end
    if items then
        self.itemAnimation:Hide()
        self.itemAnimationFrames = {}
        local slot, itemId
        for slot, itemId in pairs(items) do
            slot = tonumber(slot)
            itemId = tonumber(itemId)
            if slot and itemId and (itemId > 1 or itemId == self.HIDDEN_ITEM_ID) then
                local link = GetInventoryItemLink("player", slot)
                if itemId == self.HIDDEN_ITEM_ID then
                    self:addTransmogAnim(slot, nil, true)
                    if self.ChromieRememberMog then
                        self:ChromieRememberMog(link, true)
                    end
                else
                    if self.cacheItem then
                        self:cacheItem(itemId)
                    end
                    self:addTransmogAnim(slot, nil, true)
                    if self.ChromieRememberMog then
                        self:ChromieRememberMog(link, false)
                    end
                end
            end
        end
        if self.ChromieStartItemAnim then
            self:ChromieStartItemAnim()
        end
    end

    if self.transmogStatus then
        self:transmogStatus()
    end
    if self.RefreshPendingGlows then
        self:RefreshPendingGlows()
    end
    if self.PreviewCacheInit then
        self:PreviewCacheInit()
    end
    -- Unit appearance packet lags; SetUnit only if some mog id is still unknown.
    self:PreviewRedress(10)
end

function Transmog:ChromieHandleSetsListGossip()
    if not self:ChromieGossipReady() then
        return
    end
    local kind = self:ChromieGossipKind()
    if kind == "main" then
        if self.chromieSetsGotList then
            self.chromieSetsGotList = nil
            self:ChromieFinishSetJob()
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "manageSets")
        if not idx then
            self.chromieSets = self.chromieSets or {}
            self:ChromieFinishSetJob()
            return
        end
        SelectGossipOption(idx)
        return
    end
    if kind == "set-list" then
        self:ChromieScrapeSetNames()
        self.chromieSetsGotList = true
        if self:ChromieClickBack("sets-list-done") then
            return
        end
        self:ChromieFinishSetJob()
        return
    end
    if self:ChromieClickBack("sets-list-wrong") then
        return
    end
    self:ChromieFinishSetJob()
end

function Transmog:ChromieHandleSetsViewGossip()
    if not self:ChromieGossipReady() then
        return
    end
    local name = self.chromieSetViewName
    local kind = self:ChromieGossipKind()
    if kind == "main" then
        if self.chromieSetViewPhase == "returning" then
            self.chromieSetViewPhase = nil
            self:PreviewRedress(0)
            self:calculateCost()
            self:ChromieFinishSetJob()
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "manageSets")
        if idx then
            SelectGossipOption(idx)
            return
        end
        self:Chat("Manage sets was not on the menu.")
        self:ChromieFinishSetJob()
        return
    end
    if kind == "set-list" then
        if self.chromieSetViewPhase == "returning" then
            self:ChromieClickBack("sets-view-home")
            return
        end
        local idx = self:ChromieFindSetNameIndex(self.chromieLastOptions, name)
        if idx then
            SelectGossipOption(idx)
            return
        end
        self:Chat("Set \"" .. tostring(name) .. "\" was not in the list.")
        self:ChromieClickBack("sets-view-missing")
        self.chromieSetViewPhase = "returning"
        return
    end
    if kind == "set-view" then
        self:ChromieStoreSetItems(name, self:ChromieParseSetItems(self.chromieLastOptions))
        self.chromieSetViewPhase = "returning"
        if self:ChromieClickBack("sets-view-done") then
            return
        end
    end
    if self:ChromieClickBack("sets-view-wrong") then
        return
    end
    self:ChromieFinishSetJob()
end

function Transmog:ChromieHandleSetsUseGossip()
    if not self:ChromieGossipReady() then
        if self.ChromieSetCacheDbg then
            self:ChromieSetCacheDbg("HandleSetsUse: gossip not ready name=\""
                .. tostring(self.chromieSetViewName) .. "\" waitingNpc=" .. tostring(self.chromieWaitingForNpc))
        end
        return
    end
    local name = self.chromieSetViewName
    local kind = self:ChromieGossipKind()
    if self.ChromieSetCacheDbg then
        self:ChromieSetCacheDbg("HandleSetsUse kind=" .. tostring(kind) .. " name=\"" .. tostring(name) .. "\""
            .. " applied=" .. tostring(self.chromieSetUseApplied) .. " returning=" .. tostring(self.chromieSetViewPhase))
    end

    -- Use this set does not close gossip and stays on the set view.
    -- First page is two Back... clicks away: view -> list -> main.
    if kind == "main" then
        if self.chromieSetUseApplied or self.chromieSetViewPhase == "returning" then
            local cacheSetName = self.chromieSetUseApplied and name or nil
            if cacheSetName then
                self:Chat("Set \"" .. tostring(name) .. "\" applied.")
            elseif self.chromieSetViewPhase == "returning" then
                self:Chat("Set apply cancelled or failed for \"" .. tostring(name) .. "\".")
            end
            -- Ingest first so empty gossip clears slots this set did not touch.
            -- Then stamp known ids onto slots that are still mogged.
            if self.chromieLastOptions then
                self:ChromieIngestMainMenuStatus(self.chromieLastOptions)
            end
            self:ChromieApplySetItemsLocally(name)
            self:ChromieRefreshUiAfterSetUse(name)
            self.chromiePendingSet = nil
            self.chromieSetUseApplied = nil
            self.chromieSetViewPhase = nil
            PlaySoundFile("Interface\\AddOns\\ChromieTransmog\\assets\\ui_transmogrify_apply.ogg", "Dialog")
            self:ChromieFinishSetJob()
            self:calculateCost()
            if cacheSetName then
                self.chromieQuickApplySetName = nil
                if self.ChromieDeferSetCacheApply then
                    self:ChromieDeferSetCacheApply(cacheSetName)
                elseif self.ChromieScheduleCacheSetOnApply then
                    self:ChromieScheduleCacheSetOnApply(cacheSetName)
                end
            end
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "manageSets")
        if idx then
            SelectGossipOption(idx)
            return
        end
        self:ChromieFinishSetJob()
        return
    end

    if self.chromieSetUseApplied or self.chromieSetViewPhase == "returning" then
        self:ChromieClickBack("sets-use-back")
        return
    end

    if kind == "set-list" then
        local idx = self:ChromieFindSetNameIndex(self.chromieLastOptions, name)
        if idx then
            SelectGossipOption(idx)
            return
        end
        self:Chat("Set \"" .. tostring(name) .. "\" was not in the list.")
        self.chromieSetViewPhase = "returning"
        self:ChromieClickBack("sets-use-missing")
        return
    end

    if kind == "set-view" then
        if self.chromieApplyClicked then
            -- Confirm accepted; menu is still this set view.
            self.chromieSetUseApplied = true
            if self.ChromieSetCacheDbg then
                self:ChromieSetCacheDbg("set-view apply confirmed name=\"" .. tostring(name) .. "\"")
            end
            self:ChromieStoreSetItems(name, self:ChromieParseSetItems(self.chromieLastOptions))
            self:ChromieClickBack("sets-use-applied")
            self:ChromieKickSetReturn()
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "useSet")
        if idx then
            self.chromieApplyClicked = true
            self.chromieGossipConfirmed = nil
            SelectGossipOption(idx)
            return
        end
        self:Chat("Use this set was not on the menu.")
        self.chromieSetViewPhase = "returning"
        self:ChromieClickBack("sets-use-no-button")
        return
    end

    self:ChromieClickBack("sets-use-wrong")
end

function Transmog:ChromieHandleSetsDeleteGossip()
    if not self:ChromieGossipReady() then
        return
    end
    local name = self.chromieSetViewName
    local kind = self:ChromieGossipKind()
    if kind == "main" then
        if self.chromieSetViewPhase == "returning" then
            self:ChromieRemoveSetName(name)
            if self.currentOutfit == name then
                self.currentOutfit = nil
                self.chromiePendingSet = nil
                UIDropDownMenu_SetText(ChromieTransmogFrameOutfits, self:ChromieSetsDropdownLabel())
                self:PreviewRedress(0)
            end
            self.chromieSetViewPhase = nil
            self:ChromieFinishSetJob()
            self:calculateCost()
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "manageSets")
        if idx then
            SelectGossipOption(idx)
            return
        end
        self:ChromieFinishSetJob()
        return
    end
    if kind == "set-list" then
        if self.chromieApplyClicked or self.chromieSetViewPhase == "returning" then
            self.chromieApplyClicked = nil
            self:ChromieScrapeSetNames()
            self.chromieSetViewPhase = "returning"
            self:ChromieClickBack("sets-delete-home")
            return
        end
        local idx = self:ChromieFindSetNameIndex(self.chromieLastOptions, name)
        if idx then
            SelectGossipOption(idx)
            return
        end
        self.chromieSetViewPhase = "returning"
        self:ChromieClickBack("sets-delete-missing")
        return
    end
    if kind == "set-view" then
        if self.chromieApplyClicked then
            self:ChromieClickBack("sets-delete-applied")
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "deleteSet")
        if idx then
            self.chromieApplyClicked = true
            self.chromieGossipConfirmed = nil
            SelectGossipOption(idx)
            return
        end
        self.chromieSetViewPhase = "returning"
        self:ChromieClickBack("sets-delete-no-button")
        return
    end
    if self:ChromieClickBack("sets-delete-wrong") then
        return
    end
    self:ChromieFinishSetJob()
end

function Transmog:ChromieHandleSetsSaveGossip()
    if not self:ChromieGossipReady() then
        return
    end
    local kind = self:ChromieGossipKind()
    if kind == "main" then
        if self.chromieSetViewPhase == "returning" then
            self:ChromieFinishSetJob()
            self:calculateCost()
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "manageSets")
        if idx then
            SelectGossipOption(idx)
            return
        end
        self:Chat("Manage sets was not on the menu.")
        self:ChromieFinishSetJob()
        return
    end
    if kind == "set-list" then
        if self.chromieSetViewPhase == "returning" then
            self:ChromieClickBack("sets-save-home")
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "saveSet")
        if idx then
            SelectGossipOption(idx)
            return
        end
        self:Chat("Cannot save another set (limit reached).")
        self.chromieSetViewPhase = "returning"
        self:ChromieClickBack("sets-save-full")
        return
    end
    if kind == "set-save" then
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "saveSet")
        if not idx then
            self:Chat("Nothing to save. Transmogrify at least one item first.")
            self.chromieSetViewPhase = "returning"
            self:ChromieClickBack("sets-save-empty")
            return
        end
        self.chromieApplyClicked = true
        self.chromieGossipConfirmed = nil
        local ok = pcall(SelectGossipOption, idx, self.chromieSetSaveName, true)
        if not ok then
            SelectGossipOption(idx)
        end
        return
    end
    if self.chromieSetViewPhase == "returning" then
        if kind == "set-list" then
            self:ChromieClickBack("sets-save-abort")
            return
        end
        if kind == "main" then
            self:ChromieFinishSetJob()
            return
        end
    end
    if self:ChromieClickBack("sets-save-wrong") then
        return
    end
    self:ChromieFinishSetJob()
end

function Transmog:ChromieFinishSetSave()
    local name = self.chromieSetSaveName
    if name then
        self:ChromieAddSetName(name)
        if self.ChromiePersistEnsureSetName then
            self:ChromiePersistEnsureSetName(name)
        end
        if self.ChromieHideSetCreate then
            self:ChromieHideSetCreate()
        end
        if self.ChromieRefreshManageSets then
            self:ChromieRefreshManageSets()
        end
        if self.ChromieCacheSetFromWorn then
            self:ChromieCacheSetFromWorn(name)
        end
    end
    self.chromiePendingSet = nil
    self.chromieSetSaveName = nil
    self.chromieSetSaveIndex = nil
    self.chromieApplyClicked = nil
    self.chromieWaitingForNpc = true
    self.chromieJob = "open"
    if self.ChromieRefreshSetsDropdown then
        self:ChromieRefreshSetsDropdown()
    end
    if self.ChromieRefreshManageSets then
        self:ChromieRefreshManageSets()
    end
    if self.ChromieUpdateCanSaveSet then
        self:ChromieUpdateCanSaveSet()
    end
    self:Chat("Set saved. Talk to Warpweaver if gossip closed.")
    self:calculateCost()
end

function Transmog:ChromieHandleSetsPriceGossip()
    if not self:ChromieGossipReady() then
        return
    end
    local kind = self:ChromieGossipKind()
    if kind == "main" then
        if self.chromieSetViewPhase == "returning" then
            self:ChromieFinishSetJob()
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "manageSets")
        if idx then
            SelectGossipOption(idx)
            return
        end
        self:ChromieFinishSetJob()
        return
    end
    if kind == "set-list" then
        if self.chromieSetViewPhase == "returning" then
            self:ChromieClickBack("sets-price-home")
            return
        end
        self:ChromieScrapeSetNames()
        if self.ChromieUpdateCanSaveSet then
            self:ChromieUpdateCanSaveSet(self.chromieLastOptions)
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "saveSet")
        if idx then
            SelectGossipOption(idx)
            return
        end
        self.chromieSetViewPhase = "returning"
        self:ChromieClickBack("sets-price-no-save")
        return
    end
    if kind == "set-save" then
        if self.chromieSetPriceCaptured then
            self.chromieSetViewPhase = "returning"
            self:ChromieClickBack("sets-price-back")
            return
        end
        if self.chromieSetPriceClicked then
            return
        end
        local idx = self:ChromieFindFlagIndex(self.chromieLastOptions, "saveSet")
        if not idx then
            self.chromieSetViewPhase = "returning"
            self:ChromieClickBack("sets-price-empty")
            return
        end
        self.chromieSetPriceClicked = true
        SelectGossipOption(idx)
        return
    end
    if self.chromieSetViewPhase == "returning" then
        if self:ChromieClickBack("sets-price-return") then
            return
        end
        self:ChromieFinishSetJob()
        return
    end
    if self:ChromieClickBack("sets-price-wrong") then
        return
    end
    self:ChromieFinishSetJob()
end

function Transmog:ChromieStartSetPrice()
    if self.chromieJob == "sets-price" then
        return
    end
    if self:ChromieIsSetJob() or self.chromieJob == "load" or self.chromieJob == "apply" then
        self.chromieWantSetPrice = true
        if self.ChromieUpdateManageSetPrice then
            self:ChromieUpdateManageSetPrice()
        end
        if self.ChromieRefreshManageSetList then
            self:ChromieRefreshManageSetList()
        end
        return
    end
    self.chromieWantSetPrice = nil
    if self.chromieWaitingForNpc then
        if self.ChromieUpdateManageSetPrice then
            self:ChromieUpdateManageSetPrice()
        end
        return
    end
    if not self:ChromieHasAnyMog() or self:tableSize(self.chromieSets or {}) >= self.CHROMIE_MAX_SETS then
        self.chromieSetSaveCopper = nil
        if self.ChromieUpdateManageSetPrice then
            self:ChromieUpdateManageSetPrice()
        end
        return
    end
    self.chromieJob = "sets-price"
    self.chromieSetViewPhase = nil
    self.chromieSetPriceCaptured = nil
    self.chromieSetPriceClicked = nil
    self.chromieSetSaveCopper = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = nil
    if self.ChromieUpdateManageSetPrice then
        self:ChromieUpdateManageSetPrice()
    end
    if self.ChromieRefreshManageSetList then
        self:ChromieRefreshManageSetList()
    end
    self:ChromieHandleSetsPriceGossip()
end

function Transmog:ChromieStartSetView(name)
    if not name or self:ChromieIsSetJob() then
        return
    end
    self.chromieJob = "sets-view"
    self.chromieSetViewName = name
    self.chromieSetViewPhase = nil
    self.chromieApplyClicked = nil
    self:ChromieHandleSetsViewGossip()
end

function Transmog:ChromieStartSetUse(name)
    name = name or (self.chromiePendingSet and self.chromiePendingSet.name)
    if not name then
        self:Chat("[SetCache] StartSetUse: no set name.")
        return
    end
    if self.chromieJob == "sets-use" and self.chromieSetViewName == name then
        if self.ChromieSetCacheDbg then
            self:ChromieSetCacheDbg("StartSetUse: already applying \"" .. tostring(name) .. "\"")
        end
        return
    end
    if self:ChromieIsSetJob() or self.chromieJob == "load" or self.chromieJob == "apply" then
        self.chromieWantSetUse = name
        self:Chat("Queued set \"" .. tostring(name) .. "\" (Warpweaver busy: " .. tostring(self.chromieJob) .. ").")
        return
    end
    if self.chromieWaitingForNpc then
        self.chromieWantSetUse = name
        self:Chat("Queued set \"" .. tostring(name) .. "\". Talk to Warpweaver to apply.")
        return
    end
    if self.ChromieSetCacheDbg then
        self:ChromieSetCacheDbg("StartSetUse \"" .. tostring(name) .. "\" job=" .. tostring(self.chromieJob))
    end
    self.chromieWantSetUse = nil
    self.chromieJob = "sets-use"
    self.chromieSetViewName = name
    self.chromieSetViewPhase = nil
    self.chromieSetUseApplied = nil
    self.chromieSetBackSent = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = nil
    ChromieTransmogFrameApplyButton:Disable()
    self:ChromieHandleSetsUseGossip()
end

function Transmog:ChromieStartSetDelete(name)
    if not name or self:ChromieIsSetJob() then
        return
    end
    self.chromieJob = "sets-delete"
    self.chromieSetViewName = name
    self.chromieSetViewPhase = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = nil
    self:ChromieHandleSetsDeleteGossip()
end

function Transmog:ChromieStartSetSave(name)
    if not name or self:ChromieIsSetJob() then
        return
    end
    self.chromieJob = "sets-save"
    self.chromieSetSaveName = name
    self.chromieSetViewPhase = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = nil
    if self.setCreateFrame and self.setCreateFrame.ok then
        self.setCreateFrame.ok:Disable()
    end
    if self.manageSetsFrame and self.manageSetsFrame.save then
        self.manageSetsFrame.save:Disable()
    end
    self:ChromieHandleSetsSaveGossip()
end

function Transmog:ChromieStartSetsList()
    if self:ChromieIsSetJob() or self.chromieJob == "load" or self.chromieJob == "apply" then
        return
    end
    self.chromieJob = "sets-list"
    self.chromieSetsGotList = nil
    self:ChromieHandleSetsListGossip()
end

function Transmog:ChromieOnGossipShow()
    if not self:ChromieShouldIntercept() then
        return
    end

    -- A new hello is in progress. Clear this before HideBlizzard or the
    -- waiting flag lets GossipFrame_OnHide CloseGossip and the click is wasted.
    self.chromieWaitingForNpc = nil
    self.chromieSetBackSent = nil

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

    if justOpened and not onMainMenu and self.chromieJob ~= "apply" and self.chromieJob ~= "load" and not self:ChromieIsSetJob() then
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
            if self.chromieRemoveAll then
                self:ChromieFinishRemoveAll()
            else
                self:ChromieFinishApply(true)
            end
            return
        end
        self:ChromieHandleApplyGossip()
    elseif self.chromieJob == "sets-list" then
        self:ChromieHandleSetsListGossip()
    elseif self.chromieJob == "sets-view" then
        self:ChromieHandleSetsViewGossip()
    elseif self.chromieJob == "sets-save" then
        self:ChromieHandleSetsSaveGossip()
    elseif self.chromieJob == "sets-price" then
        self:ChromieHandleSetsPriceGossip()
    elseif self.chromieJob == "sets-use" then
        self:ChromieHandleSetsUseGossip()
    elseif self.chromieJob == "sets-delete" then
        self:ChromieHandleSetsDeleteGossip()
    else
        if self.ChromieSetCacheResumeIfPending and self:ChromieSetCacheResumeIfPending(onMainMenu) then
            return
        end
        if justOpened and onMainMenu then
            if self.ChromieCacheSyncMaybePrompt and self:ChromieCacheSyncMaybePrompt() then
                return
            end
            self:ChromieStartSetsList()
            return
        end
        if onMainMenu and (self.chromieJob == "open" or not self.chromieJob) then
            if self.setCacheJob and self.setCacheJob.pendingNext and self.ChromieDeferSetCacheScanNext then
                self.setCacheJob.pendingNext = nil
                self:ChromieDeferSetCacheScanNext()
                return
            end
            if self.chromieScanQueuePending or (self.chromieScanQueue and self.chromieScanQueue[1]) then
                self.chromieScanQueuePending = nil
                if self.ChromieProcessScanQueue then
                    self:ChromieProcessScanQueue()
                end
                return
            end
            if self.ChromieTryCacheUnknownSets and self:ChromieTryCacheUnknownSets() then
                return
            end
            if self.ChromieCacheSyncMaybePrompt and self:ChromieCacheSyncMaybePrompt() then
                return
            end
        end
        if self.chromieWantSetUse then
            local name = self.chromieWantSetUse
            self.chromieWantSetUse = nil
            self:Chat("Starting queued set \"" .. tostring(name) .. "\"...")
            self:ChromieStartSetUse(name)
            return
        end
        self:ChromieDumpOptions("idle")
    end
end

function Transmog:ChromieSendInterfaceOff()
    local box = ChatFrame1EditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
    if not box or not ChatEdit_SendText then
        self:Chat("Type .t i off in chat, then talk to Warpweaver again.")
        return
    end
    local old = box:GetText() or ""
    box:SetText(".t i off")
    ChatEdit_SendText(box, 0)
    box:SetText(old)
    self:Chat("Sent .t i off. Talk to Warpweaver again, then pick a slot.")
end

function Transmog:ChromieNotifyVendorMode()
    if self.chromieVendorPopupShown then
        return
    end
    self.chromieVendorPopupShown = true
    StaticPopup_Show("CHROMIE_TRANSMOG_VENDOR_MODE")
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

    -- Slot appearances as a fake vendor (.t i on / UseVendorInterface). Overlay
    -- scrape/apply is gossip-list based; warn instead of half-loading one page.
    if self.chromieJob == "load" or self.chromieJob == "open" or self.chromieJob == "apply" or self:ChromieIsSetJob() then
        if self.ChromieLog then
            self:ChromieLog("Vendor item list detected job=" .. tostring(self.chromieJob))
        end
        if self.chromieJob == "load" or self:ChromieIsSetJob() then
            if self.setCacheJob and self.ChromieSetCacheAbort then
                self:ChromieSetCacheAbort()
            end
            self.chromieJob = "open"
            self.chromieLoadEnteredSlot = nil
            ChromieTransmogFrameNoTransmogs:SetText("Vendor item list is on (.t i on).\nSwitch to .t i off, then select a slot again.")
            ChromieTransmogFrameNoTransmogs:Show()
        end
        self:ChromieNotifyVendorMode()
        return
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
            if self.chromieRemoveAll then
                self:ChromieFinishRemoveAll()
            else
                self:ChromieFinishApply(true)
            end
        end
        return
    end
    if self.chromieJob == "sets-save" and self.chromieApplyClicked then
        self:ChromieFinishSetSave()
        return
    end
    if self.chromieJob == "sets-price" then
        if self.ChromieLog then
            self:ChromieLog("GOSSIP_CLOSED ignored job=sets-price")
        end
        return
    end
    -- Hiding GossipFrame used to CloseGossip and collapse the overlay mid-scrape.
    if self.chromieJob == "load" or self.chromieJob == "probe" or self:ChromieIsSetJob() then
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
    if self.ChromieHydrateFromApplied then
        self:ChromieHydrateFromApplied()
    end
    if self.chromieJob ~= "probe" and self.chromieJob ~= "apply" and self.chromieJob ~= "load" and not self:ChromieIsSetJob() then
        self.chromieJob = "open"
    end
    ChromieTransmogFrame:Show()
    if self.ChromieLog then
        self:ChromieLog("UI opened")
    end
end

-- Single entry for gossip appearance scrape. Sets load job state and drives gossip unless deferred.
function Transmog:ChromieScanSlot(slot, opts)
    opts = opts or {}
    if not slot or not self:ChromieSlotSupportsTransmog(slot) then
        return false
    end
    if self.probeActive then
        return false
    end
    if self.chromieJob == "load" then
        return false
    end
    if self:ChromieIsSetJob() then
        if opts.force and (self.chromieJob == "sets-list" or self.chromieJob == "sets-view") then
            self.chromieJob = "open"
        else
            self.chromieQueuedSlot = slot
            return false
        end
    end
    if self.chromieVendorOpen then
        return false
    end
    if opts.announce ~= nil then
        self.chromieScanAnnounce = opts.announce
    end
    if opts.purpose then
        self.chromieScanPurpose = opts.purpose
    end
    ChromieTransmogFrameNoTransmogs:SetText("Loading appearances from the transmog NPC...")
    ChromieTransmogFrameNoTransmogs:Show()
    self.chromieJob = "load"
    self.chromieLoadSlot = slot
    self.chromieLoadEnteredSlot = nil
    self.chromiePages = 0
    self.chromieCache[slot] = {}
    self:ChromieHandleLoadGossip()
    return true
end

function Transmog:ChromieEnsureSlot(slot, forceScan)
    if self.probeActive then
        return
    end
    if not self:ChromieSlotSupportsTransmog(slot) then
        return
    end
    if not forceScan and self.ChromiePublishFromPersist and self:ChromiePublishFromPersist(slot) then
        self:ChromiePublish(slot)
        ChromieTransmogFrameNoTransmogs:Hide()
        return
    end
    if not forceScan and self.chromieCache[slot] and self.chromieCache[slot][1] then
        self:ChromiePublish(slot)
        ChromieTransmogFrameNoTransmogs:Hide()
        return
    end
    self:ChromieScanSlot(slot, { force = forceScan and true or false })
end

function Transmog:ChromieStartRemoveAll()
    local slots = {}
    local _, slot
    for _, slot in pairs(self.inventorySlots) do
        if self:ChromieSlotNeedsApply(slot) and self.transmogStatusToServer[slot] == 0 then
            table.insert(slots, slot)
        end
    end
    if not slots[1] then
        if self.ChromiePromptFinish then
            self:ChromiePromptFinish()
        end
        return
    end
    self.chromieRemoveAll = true
    self.chromieRemoveAllSlots = slots
    self.chromieJob = "apply"
    self.chromieApplySlot = nil
    self.chromieApplyItem = 0
    self.chromieApplyPages = 0
    self.chromieApplyEnteredSlot = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = nil
    self.chromieWaitingForNpc = nil
    ChromieTransmogFrameApplyButton:Disable()
    if self.ChromieLog then
        self:ChromieLog("Remove all transmogrifications slots=" .. self:tableSize(slots))
    end
    if self.chromieVendorOpen then
        self:Chat("Vendor item list is on. Switch to gossip (.t i off) to remove all at once.")
        self.chromieRemoveAll = nil
        self.chromieJob = "open"
        self:calculateCost()
        if self.ChromiePromptFinish then
            self:ChromiePromptFinish()
        end
        return
    end
    self:ChromieHandleApplyGossip()
end

function Transmog:ChromieFinishRemoveAll()
    local slots = self.chromieRemoveAllSlots or {}
    self.chromieRemoveAll = nil
    self.chromieRemoveAllSlots = nil
    self.chromieVendorOpen = nil
    self.chromieApplyClicked = nil
    self.chromieGossipConfirmed = true
    self:ChromieHideGossipConfirm()
    local i = 1
    while slots[i] do
        local slot = slots[i]
        self.transmogStatusFromServer[slot] = 0
        self.transmogStatusToServer[slot] = 0
        if self.ChromieAppliedSet then
            self:ChromieAppliedSet(slot, 0)
        end
        self:addTransmogAnim(slot, "reset")
        if self.ChromieForgetMog then
            self:ChromieForgetMog(GetInventoryItemLink("player", slot))
        end
        i = i + 1
    end
    self.chromieJob = "open"
    PlaySoundFile("Interface\\AddOns\\ChromieTransmog\\assets\\ui_transmogrify_apply.ogg", "Dialog")
    if self.PreviewCacheInit then
        self:PreviewCacheInit()
    end
    -- Do not SetUnit("player"): the unit appearance packet still has the old
    -- mogs for a few frames. Rebuild from equipped (want=0) like pending undo.
    if self.PreviewRebuild then
        self:PreviewRebuild()
    end
    self:transmogStatus()
    if self.RefreshPendingGlows then
        self:RefreshPendingGlows()
    end
    self:calculateCost()
    if self.ChromieAbortMultiApply then
        self:ChromieAbortMultiApply()
    end
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
        if self.ChromieAppliedSet then
            self:ChromieAppliedSet(slot, itemId)
        end
        if self.PreviewCacheCommit then
            self:PreviewCacheCommit(slot, itemId)
        end
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
    if self.ChromieUpdateCanSaveSet then
        self:ChromieUpdateCanSaveSet()
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
