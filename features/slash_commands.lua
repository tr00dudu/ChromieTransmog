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
    if cmd == "" then
        if Transmog.overlayEnabled then
            Transmog:Chat("Overlay ON. /ct off = original NPC window.")
        else
            Transmog:Chat("Overlay OFF. /ct on = ChromieTransmog UI.")
        end
        return
    end
    Transmog:Chat("Unknown command. Use /ct on or /ct off.")
end

SLASH_CHROMIETRANSMOG1 = "/chromietransmog"
SLASH_CHROMIETRANSMOG2 = "/ctm"
SLASH_CHROMIETRANSMOG3 = "/ct"
SlashCmdList["CHROMIETRANSMOG"] = runCmd

local function bindSlashHash()
    if not hash_SlashCmdList then
        return
    end
    hash_SlashCmdList["/CHROMIETRANSMOG"] = runCmd
    hash_SlashCmdList["/CTM"] = runCmd
    hash_SlashCmdList["/CT"] = runCmd
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
