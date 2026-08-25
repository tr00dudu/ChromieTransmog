local Transmog = _G.ChromieTransmog

local function runCmd(cmd)
    cmd = string.lower(string.gsub(cmd or "", "^%s+", ""))
    cmd = string.gsub(cmd, "%s+$", "")
    if cmd == "on" then
        Transmog:SetOverlayEnabled(true)
        return
    end
    if cmd == "off" then
        Transmog:SetOverlayEnabled(false)
        return
    end
    if cmd == "debug" then
        Transmog.debug = not Transmog.debug
        if Transmog.debug then
            twfprint("ChromieTransmog debug on")
        else
            twfprint("ChromieTransmog debug off")
        end
        return
    end
    if cmd == "probe" then
        Transmog:Chat("slash: probe")
        Transmog:ChromieProbeStart()
        return
    end
    if cmd == "log" then
        Transmog.logEnabled = true
        Transmog:ChromieLogShow()
        Transmog:ChromieLogSnapshot("manual")
        Transmog:Chat("Probe log on. /ctm logoff to disable. /ctm clear to wipe.")
        return
    end
    if cmd == "logoff" then
        Transmog.logEnabled = false
        if Transmog.logFrame then
            Transmog.logFrame:Hide()
        end
        Transmog:Chat("Probe log off.")
        return
    end
    if cmd == "clear" or cmd == "logclear" then
        Transmog:ChromieLogShow()
        Transmog:ChromieLogClear()
        return
    end
    if cmd == "dump" then
        local options = Transmog.chromieLastOptions or {}
        Transmog:Chat("Last gossip options: " .. Transmog:tableSize(options))
        local i = 1
        while options[i] do
            Transmog:Chat("[" .. options[i].index .. "] item=" .. tostring(options[i].itemId) .. " " .. options[i].stripped)
            i = i + 1
        end
        local idA, guid, idB, idC = Transmog:ChromieNpcId()
        Transmog:Chat("NPC guid=" .. tostring(guid) .. " ids=" .. tostring(idA) .. "/" .. tostring(idB) .. "/" .. tostring(idC))
        Transmog:Chat("job=" .. tostring(Transmog.chromieJob) .. " vendor=" .. tostring(Transmog.chromieVendorOpen))
        return
    end
    if cmd == "" then
        if Transmog.overlayEnabled then
            Transmog:Chat("Overlay ON. /ctm off = original NPC window.")
        else
            Transmog:Chat("Overlay OFF. /ctm on = ChromieTransmog UI.")
        end
        return
    end
        Transmog:Chat("Unknown /ctm command '" .. cmd .. "'. Use on, off, probe, log, logoff, clear, dump, debug")
end

SLASH_CHROMIETRANSMOG1 = "/chromietransmog"
SLASH_CHROMIETRANSMOG2 = "/ctm"
SLASH_CHROMIETRANSMOG3 = "/ct"
SlashCmdList["CHROMIETRANSMOG"] = runCmd

SLASH_CTPROBE1 = "/ctprobe"
SLASH_CTPROBE2 = "/ctp"
SlashCmdList["CTPROBE"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[ChromieTransmog]|r /ctprobe received")
    if Transmog.ChromieProbeStart then
        Transmog:ChromieProbeStart()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[ChromieTransmog]|r probe function missing (addon load error)")
    end
end

SLASH_TRANSMOGDEBUG1 = "/transmogdebug"
SLASH_TRANSMOGDEBUG2 = "/chromietransmogdebug"
SlashCmdList["TRANSMOGDEBUG"] = function()
    runCmd("debug")
end

local function bindSlashHash()
    if not hash_SlashCmdList then
        return
    end
    hash_SlashCmdList["/CHROMIETRANSMOG"] = runCmd
    hash_SlashCmdList["/CTM"] = runCmd
    hash_SlashCmdList["/CT"] = runCmd
    hash_SlashCmdList["/CTPROBE"] = SlashCmdList["CTPROBE"]
    hash_SlashCmdList["/CTP"] = SlashCmdList["CTPROBE"]
end

bindSlashHash()
if ChatFrame_ImportAllListsToHash then
    ChatFrame_ImportAllListsToHash()
end

local slashFix = CreateFrame("Frame")
slashFix:RegisterEvent("PLAYER_ENTERING_WORLD")
slashFix:SetScript("OnEvent", function()
    bindSlashHash()
    if ChatFrame_ImportAllListsToHash then
        ChatFrame_ImportAllListsToHash()
    end
end)

if not UISpecialFrames then
    UISpecialFrames = {}
end
tinsert(UISpecialFrames, "ChromieTransmogFrame")
