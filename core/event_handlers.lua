local Transmog = _G.ChromieTransmog
local ChromieTransmogFrame_Find = string.find
local ChromieTransmogFrame_ToNumber = tonumber

Transmog:RegisterEvent("GOSSIP_SHOW")
Transmog:RegisterEvent("GOSSIP_CLOSED")
Transmog:RegisterEvent("GOSSIP_CONFIRM")
Transmog:RegisterEvent("GOSSIP_CONFIRM_CANCEL")
Transmog:RegisterEvent("MERCHANT_SHOW")
Transmog:RegisterEvent("MERCHANT_CLOSED")
Transmog:RegisterEvent("UNIT_INVENTORY_CHANGED")
Transmog:RegisterEvent("CHAT_MSG_ADDON")
Transmog:RegisterEvent("CVAR_UPDATE")

Transmog:SetScript("OnEvent", function()

    if event then
        if event == "GOSSIP_SHOW" then
            Transmog:ChromieOnGossipShow()
            return
        end
        if event == "GOSSIP_CLOSED" then
            Transmog:ChromieOnGossipClosed()
            return
        end
        if event == "GOSSIP_CONFIRM" or event == "GOSSIP_CONFIRM_CANCEL" then
            if Transmog.ChromieLog then
                Transmog:ChromieLog("EVENT " .. event .. " arg1=" .. tostring(arg1))
            end
            if event == "GOSSIP_CONFIRM_CANCEL" then
                if Transmog.overlayEnabled then
                    Transmog:ChromieHideGossipConfirm()
                end
            end
            return
        end
        if event == "MERCHANT_SHOW" then
            Transmog:ChromieOnMerchantShow()
            return
        end
        if event == "MERCHANT_CLOSED" then
            if Transmog.ChromieLog then
                Transmog:ChromieLog("EVENT MERCHANT_CLOSED")
            end
            Transmog.chromieVendorOpen = nil
            if Transmog.chromieJob == "apply" and Transmog.chromieApplyClicked then
                Transmog.chromieApplyClicked = nil
                Transmog:ChromieFinishApply(true)
            end
            return
        end
        if event == "CVAR_UPDATE" then
            local name = string.lower(tostring(arg1 or ""))
            if (string.find(name, "helm", 1, true) or string.find(name, "cloak", 1, true))
                and ChromieTransmogFrame and ChromieTransmogFrame:IsShown() then
                Transmog:RefreshPreviewModel()
            end
            return
        end
        if event == "UNIT_INVENTORY_CHANGED" then

            twfdebug(event)

            -- Visible-item updates from hide/remove must not revert overlay state.
            if Transmog.chromieJob == "apply" or Transmog.chromieJob == "load" or Transmog.chromieApplyClicked then
                return
            end

            if Transmog:EquippedItemsChanged() then

                twfdebug("equipped items changed")

                if ChromieTransmogFrame:IsVisible() then
                    twfdebug("visible")
                    Transmog.gearChangedDelay.delay = 1
                else
                    twfdebug("not visible")
                    Transmog.gearChangedDelay.delay = 2
                end
                Transmog:LockPlayerItems()
                Transmog.gearChangedDelay:Show()

            else
                twfdebug("equipped items not changed")
            end

            return
        end
        if event == 'CHAT_MSG_ADDON' then

            if arg1 == "TW_CHAT_MSG_WHISPER" then
                local message = arg2
                local from = arg4
                if string.find(message, 'INSShowTransmogs', 1, true) then
                    SendAddonMessage("TW_CHAT_MSG_WHISPER<" .. from .. ">", "INSTransmogs:start", "GUILD")
                    for InventorySlotId, itemID in pairs(Transmog.transmogStatusFromServer) do
                        if itemID ~= 0 then

                            local TransmogItemName = GetItemInfo(itemID)

                            if TransmogItemName then
                                -- check if we actually have an item equipped
                                if GetInventoryItemLink('player', InventorySlotId) then
                                    local _, _, eqItemLink = ChromieTransmogFrame_Find(GetInventoryItemLink('player', InventorySlotId), "(item:%d+:%d+:%d+:%d+)");
                                    local eName = GetItemInfo(eqItemLink)
                                    SendAddonMessage("TW_CHAT_MSG_WHISPER<" .. from .. ">", "INSTransmogs:" .. eName .. ":" .. TransmogItemName, "GUILD")
                                end
                            end
                        end
                    end
                    SendAddonMessage("TW_CHAT_MSG_WHISPER<" .. from .. ">", "INSTransmogs:end", "GUILD")
                end
                return
            end

			if ChromieTransmogFrame_Find(arg1, Transmog.prefix, 1, true) then

				twfdebug("CHAT_MSG_ADDON " .. arg2)
				local message = arg2

				if ChromieTransmogFrame_Find(message, "Open", 1, true) then
					-- Server requests the transmog UI to open.
					Transmog.serverRequestsOverlay = true
					return
				end

				if ChromieTransmogFrame_Find(message, "AvailableTransmogs", 1, true) then

					-- Format: AvailableTransmogs:slot:class+subclass:amount:start|id1:id2:...|end

					local ex = ChromieTransmogFrame_Explode(message, ":")

					local slot = ChromieTransmogFrame_ToNumber(ex[2])+1
					local itemClass = ChromieTransmogFrame_ToNumber(ex[3])
					local amount = ChromieTransmogFrame_ToNumber(ex[4])

					if not Transmog.numTransmogs[slot] then
						Transmog.numTransmogs[slot] = {}
					end

					Transmog.numTransmogs[slot][itemClass] = amount

					if ChromieTransmogFrame_Find(ex[5], "start", 1, true) then
						if not Transmog.transmogDataFromServer[slot] then
							Transmog.transmogDataFromServer[slot] = {}
						end
						Transmog.transmogDataFromServer[slot][itemClass] = {}
					elseif ChromieTransmogFrame_Find(ex[5], "end", 1, true) then
						Transmog:prepareAvailableTransmogs(slot, itemClass)
					else
						for i, itemID in ipairs(ex) do
							if i > 4 then
								itemID = ChromieTransmogFrame_ToNumber(itemID)
								if itemID ~= 0 then
									Transmog:cacheItem(itemID)

									table.insert(Transmog.transmogDataFromServer[slot][itemClass], itemID)
								end
							end
						end
					end
					return
				end
				if ChromieTransmogFrame_Find(message, "TransmogStatus", 1, true) then

					-- Format: TransmogStatus:amount:slot1,itemID1:slot2,itemID2:...

					local dataEx = ChromieTransmogFrame_Explode(message, ":")
					if dataEx[2] then
						Transmog.transmogStatusFromServer = {}
						Transmog.transmogStatusToServer = {}

						for _, InventorySlotId in pairs(Transmog.inventorySlots) do
							Transmog.transmogStatusFromServer[InventorySlotId] = 0
							Transmog.transmogStatusToServer[InventorySlotId] = 0
						end

						local amount = ChromieTransmogFrame_ToNumber(dataEx[2])
						if amount > 0 then
							for i, d in ipairs(dataEx) do
								if i > 2 then
									local slotStatus = ChromieTransmogFrame_Explode(d, ",")
									local InventorySlotId = ChromieTransmogFrame_ToNumber(slotStatus[1])+1
									local itemID = ChromieTransmogFrame_ToNumber(slotStatus[2])
									Transmog.transmogStatusFromServer[InventorySlotId] = itemID
									Transmog.transmogStatusToServer[InventorySlotId] = itemID
									if ChromieTransmogFrame_ToNumber(itemID) ~= 0 then
										Transmog:cacheItem(itemID)
									end
								end
							end
						end
                        Transmog:RefreshPendingGlows()
                        Transmog:transmogStatus()
					end
					return
				end
				if ChromieTransmogFrame_Find(message, "NewTransmog", 1, true) then
					-- Format: NewTransmog:itemID
					local dataEx = ChromieTransmogFrame_Explode(message, "NewTransmog:")
					twfdebug("NewaTransmog " .. dataEx[2])
					if string.find(message, "|r") then
						twfdebug("1message: [" .. message .. "] contains r")
					end
					if string.find(message, "|r", 1, true) then
						twfdebug("2message: [" .. message .. "] contains r")
					end
					if dataEx[2] and ChromieTransmogFrame_ToNumber(dataEx[2]) then
						twfdebug("new transmog " .. dataEx[2])
						Transmog:addWonItem(ChromieTransmogFrame_ToNumber(dataEx[2]))
					else
						twfdebug("new transmog not number :[" .. dataEx[2] .. "]")
					end
					return
				end
				if ChromieTransmogFrame_Find(message, "TransmogCost", 1, true) then

					-- Format: TransmogCost:cost:canPurchase
					local dataEx = ChromieTransmogFrame_Explode(message, ":")
					if dataEx[2] and dataEx[3] then
						local cost = ChromieTransmogFrame_ToNumber(dataEx[2])
						local canPurchase = ChromieTransmogFrame_ToNumber(dataEx[3])
						Transmog:updateCost(cost, canPurchase)
					end
					return
				end
				if ChromieTransmogFrame_Find(message, "ApplyTransmogResult", 1, true) then

					-- Format: ApplyTransmogResult:success:slot1,itemID1:slot2,itemID2:...

					local dataEx = ChromieTransmogFrame_Explode(message, ":")
					if dataEx[2] then
						local success = ChromieTransmogFrame_ToNumber(dataEx[2])
						local data = {}
						if dataEx[3] then
							for i, str in ipairs(dataEx) do
								if i > 2 then
									local ex = ChromieTransmogFrame_Explode(str, ",")
									if ex[1] and ex[2] then
										local slot = ChromieTransmogFrame_ToNumber(ex[1])+1
										local itemID = ChromieTransmogFrame_ToNumber(ex[2])
										table.insert(data, {slot, itemID})
									end
								end
							end
						end

						Transmog:ApplyTransmogResult(success, data)
					end
					return
				end
				return
			end
        end
    end
end)
