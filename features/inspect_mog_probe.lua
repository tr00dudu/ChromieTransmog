-- Isolated mog-id probe. No Transmog persist or paperdoll.
-- FIRST NotifyInspect after a GUID change = appearance. 0.2s later / same GUID
-- again = worn. Last 10 people (current target sticky). Inspect slot tooltips
-- show the appearance name; chat stays quiet.

local SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 18 }
local SETTLE = 0.2
local MAX_PEOPLE = 10
local MOG_R, MOG_G, MOG_B = 1, 0.5, 1

local people = {}
local order = {}
local lastGuid
local inspectHooked
local tipHooked

local function itemId(link)
	if not link then
		return nil
	end
	return tonumber(string.match(link, "item:(%d+)"))
end

local function snapshot(unit)
	local t = {}
	local i = 1
	while SLOTS[i] do
		local slot = SLOTS[i]
		t[slot] = itemId(GetInventoryItemLink(unit, slot))
		i = i + 1
	end
	return t
end

local function touch(guid)
	local i = 1
	while order[i] do
		if order[i] == guid then
			table.remove(order, i)
			break
		end
		i = i + 1
	end
	order[#order + 1] = guid
end

local function evict()
	local sticky = UnitGUID("target")
	while #order > MAX_PEOPLE do
		local drop
		local i = 1
		while order[i] do
			if order[i] ~= sticky then
				drop = i
				break
			end
			i = i + 1
		end
		if not drop then
			break
		end
		local g = table.remove(order, drop)
		people[g] = nil
	end
end

local function remember(guid, name)
	local rec = people[guid]
	if not rec then
		rec = { guid = guid, name = name, first = nil, mog = {} }
		people[guid] = rec
	else
		rec.name = name or rec.name
	end
	touch(guid)
	evict()
	return rec
end

local function diffMog(rec, now)
	if not rec or not rec.first or not now then
		return
	end
	rec.mog = {}
	local i = 1
	while SLOTS[i] do
		local slot = SLOTS[i]
		local a = rec.first[slot]
		local b = now[slot]
		if a and b and a ~= b then
			rec.mog[slot] = { appearance = a, worn = b }
		end
		i = i + 1
	end
end

local function mogPair(unit, slot)
	if not unit or not slot then
		return nil
	end
	local guid = UnitGUID(unit)
	local rec = guid and people[guid]
	if not rec then
		return nil
	end
	if rec.mog and rec.mog[slot] then
		return rec.mog[slot]
	end
	local firstId = rec.first and rec.first[slot]
	local nowId = itemId(GetInventoryItemLink(unit, slot))
	if firstId and nowId and firstId ~= nowId then
		return { appearance = firstId, worn = nowId }
	end
	return nil
end

local function mogLabel(pair)
	if not pair then
		return nil
	end
	if pair.appearance == 1 then
		return "Transmogrified - Hidden"
	end
	local name = GetItemInfo(pair.appearance)
	if name then
		return "Transmogrified: " .. name
	end
	return "Transmogrified"
end

-- Wrap extra lines (AddLine's 5th arg). SetText on TextLeftN does not wrap and
-- will paint past the tooltip edge; Show() after wrap fixes height.
local function applyInspectTip(tip, unit, slot)
	if not tip or not unit or not slot then
		return
	end
	if not InspectFrame or not InspectFrame:IsShown() then
		return
	end
	if InspectFrame.unit and unit ~= InspectFrame.unit and unit ~= "target" then
		return
	end
	local label = mogLabel(mogPair(unit, slot))
	if not label then
		return
	end
	local tipName = tip:GetName()
	local i = 1
	local fs = _G[tipName .. "TextLeft" .. i]
	while fs do
		local t = fs:GetText()
		if t and string.find(t, "Transmogrified", 1, true) then
			fs:SetText(label)
			fs:SetTextColor(MOG_R, MOG_G, MOG_B)
			if fs.SetNonSpaceWrap then
				fs:SetNonSpaceWrap(1)
			end
			local w = tip:GetWidth()
			if w and w > 40 then
				fs:SetWidth(w - 20)
			end
			tip:Show()
			return
		end
		i = i + 1
		fs = _G[tipName .. "TextLeft" .. i]
	end
	if tip.AddLine then
		tip:AddLine(label, MOG_R, MOG_G, MOG_B, 1)
		tip:Show()
	end
end

local settle = CreateFrame("Frame")
settle:Hide()
settle.elapsed = 0
settle:SetScript("OnUpdate", function()
	settle.elapsed = settle.elapsed + (arg1 or 0)
	if settle.elapsed < SETTLE then
		return
	end
	settle:Hide()
	local unit = settle.unit
	local guid = settle.guid
	local rec = guid and people[guid]
	if not rec or not rec.first then
		return
	end
	if unit and UnitExists(unit) and UnitGUID(unit) == guid then
		diffMog(rec, snapshot(unit))
	end
end)

local function armSettle(unit, guid)
	settle.unit = unit
	settle.guid = guid
	settle.elapsed = 0
	settle:Show()
end

local function afterNotify(unit)
	unit = unit or arg1
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end
	local guid = UnitGUID(unit)
	if not guid then
		return
	end
	local rec = remember(guid, UnitName(unit))
	if guid ~= lastGuid then
		lastGuid = guid
		rec.first = snapshot(unit)
		rec.mog = {}
		armSettle(unit, guid)
	else
		diffMog(rec, snapshot(unit))
	end
end

if NotifyInspect then
	local orig = NotifyInspect
	NotifyInspect = function(unit)
		unit = unit or arg1
		orig(unit)
		afterNotify(unit)
	end
end

local function hookTooltip()
	if tipHooked or not GameTooltip or not GameTooltip.SetInventoryItem then
		return
	end
	tipHooked = true
	hooksecurefunc(GameTooltip, "SetInventoryItem", function(tip, unit, slot)
		tip = tip or this
		unit = unit or arg1
		slot = slot or arg2
		applyInspectTip(tip, unit, slot)
	end)
end

local function hookInspectFrame()
	if inspectHooked or not InspectFrame then
		return
	end
	inspectHooked = true
	if InspectPaperDollItemSlotButton_OnEnter then
		hooksecurefunc("InspectPaperDollItemSlotButton_OnEnter", function()
			local button = this
			local unit = InspectFrame and InspectFrame.unit
			local slot = button and button:GetID()
			if GameTooltip and unit and slot then
				applyInspectTip(GameTooltip, unit, slot)
			end
		end)
	end
end

hookInspectFrame()

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:SetScript("OnEvent", function()
	if event == "PLAYER_LOGIN" then
		hookTooltip()
		hookInspectFrame()
	elseif event == "ADDON_LOADED" and arg1 == "Blizzard_InspectUI" then
		hookInspectFrame()
	elseif event == "PLAYER_TARGET_CHANGED" then
		evict()
	end
end)
