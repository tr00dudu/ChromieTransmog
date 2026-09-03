local Transmog = _G.ChromieTransmog

Transmog:RegisterEvent("GOSSIP_SHOW")
Transmog:RegisterEvent("GOSSIP_CLOSED")
Transmog:RegisterEvent("GOSSIP_CONFIRM")
Transmog:RegisterEvent("GOSSIP_CONFIRM_CANCEL")
Transmog:RegisterEvent("MERCHANT_SHOW")
Transmog:RegisterEvent("MERCHANT_CLOSED")
Transmog:RegisterEvent("UNIT_INVENTORY_CHANGED")
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
                Transmog:ChromieLog("EVENT " .. event .. " arg1=" .. tostring(arg1) .. " arg2=" .. tostring(arg2) .. " arg3=" .. tostring(arg3))
            end
            if event == "GOSSIP_CONFIRM" and Transmog.ChromieOnGossipConfirm then
                Transmog:ChromieOnGossipConfirm(arg1, arg2, arg3)
            end
            if event == "GOSSIP_CONFIRM_CANCEL" then
                if Transmog.overlayEnabled and Transmog.chromieJob ~= "sets-price" then
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
            Transmog:ChromieCompleteApplyClick()
            return
        end
        if event == "CVAR_UPDATE" then
            local name = string.lower(tostring(arg1 or ""))
            if (string.find(name, "helm", 1, true) or string.find(name, "cloak", 1, true))
                and ChromieTransmogFrame and ChromieTransmogFrame:IsShown() then
                if Transmog.PreviewHasHidden and Transmog:PreviewHasHidden() then
                    Transmog:PreviewRebuild()
                else
                    Transmog:PreviewShowPlayer(0)
                end
            end
            return
        end
        if event == "UNIT_INVENTORY_CHANGED" then
            if arg1 and arg1 ~= "player" then
                return
            end

            twfdebug(event)

            -- Cache tab: watch bag equips (right-click in bags), not paperdoll clicks.
            if Transmog.ChromieDeferCacheTabEquipWatch and Transmog.ChromieCacheTabIsActive
                and Transmog:ChromieCacheTabIsActive() and ChromieTransmogFrame:IsVisible() then
                if Transmog.chromieJob ~= "apply" and not Transmog.chromieApplyClicked
                    and not (Transmog.ChromieIsSetJob and Transmog:ChromieIsSetJob()) then
                    Transmog:ChromieDeferCacheTabEquipWatch()
                end
                return
            end

            -- Visible-item updates from hide/remove must not revert overlay state.
            if Transmog.chromieJob == "apply" or Transmog.chromieJob == "load" or Transmog.chromieApplyClicked or (Transmog.ChromieIsSetJob and Transmog:ChromieIsSetJob()) then
                return
            end

            -- Overlay-only: sync slot state after equips. Never run while closed.
            if not ChromieTransmogFrame or not ChromieTransmogFrame:IsVisible() then
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
    end
end)
