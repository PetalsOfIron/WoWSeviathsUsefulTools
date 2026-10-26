-- SeviathsUsefulTools - hub
-- One place for everything merged into the Farm Pack: the minimap button's menu opens the
-- farm browser, the Codex, Dungeons & Raids and the Guild Helper; /sfp codex|groups|guild
-- do the same from chat. The Codex also gets the Farm Pack's rares and world bosses.

local _, SFP = ...

local CY = "|c" .. SFP.CYAN_HEX

-- run a merged module's slash command (they were separate addons before)
function SFP:RunModule(slashKey, msg)
    local fn = SlashCmdList and SlashCmdList[slashKey]
    if fn then
        fn(msg or "")
    else
        self:Print("That part is not loaded.")
    end
end

local ENTRIES = {
    { label = function() return "Farm browser" end,
      tip = "Expansions, zones, coordinates and settings",
      fn = function() SFP:ToggleBrowser() end },
    { label = function() return "Codex" end,
      tip = "Encyclopedia: dungeons, raids, bosses, mounts, pets, quests, guides",
      fn = function() SFP:RunModule("SEVIATHSCODEX", "") end },
    { label = function() return "Dungeons & Raids" end,
      tip = "Group tools: raid buffs, tier tokens, player tags and notes",
      fn = function() SFP:RunModule("SEVIATHSDUNGEONSRAIDS", "") end },
    { label = function() return "Guild Helper" end,
      tip = "Find and invite players for your guild, charter signatures",
      fn = function() SFP:RunModule("SEVIATHSGUILDHELPER", "") end },
    { label = function() return "World map overlay: " .. (SFP.db.mapOverlay and "|cff00ff00ON|r" or "|cffff4040OFF|r") end,
      tip = "Show or hide the glowing farm spots on the world map",
      fn = function()
          SFP.db.mapOverlay = not SFP.db.mapOverlay
          SFP:Print("World map overlay " .. (SFP.db.mapOverlay and "ON" or "OFF"))
          SFP:RefreshAll()
      end },
    { label = function() return "Options / about" end,
      tip = "Version, options page and command list",
      fn = function() SFP:OpenAbout() end },
}

local menu, catcher

local function build()
    catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function() menu:Hide() end)

    menu = CreateFrame("Frame", "SeviathsUsefulToolsHubMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 5)
    menu:SetSize(190, #ENTRIES * 22 + 28)
    menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    menu:SetBackdropColor(0.03, 0.06, 0.08, 0.96)
    menu:SetBackdropBorderColor(SFP.CYAN.r, SFP.CYAN.g, SFP.CYAN.b, 0.7)
    menu:Hide()
    menu:SetScript("OnHide", function() catcher:Hide() end)
    menu:SetScript("OnShow", function() catcher:Show() end)

    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(CY .. "Seviaths|r tools")

    menu.rows = {}
    for i, e in ipairs(ENTRIES) do
        local b = CreateFrame("Button", nil, menu)
        b:SetSize(180, 20)
        b:SetPoint("TOPLEFT", 5, -22 - (i - 1) * 22)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("LEFT", 6, 0)
        b.text = t
        b:SetScript("OnClick", function()
            menu:Hide()
            e.fn()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(e.tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        menu.rows[i] = b
    end
end

function SFP:ShowHubMenu(anchor)
    if not menu then build() end
    if menu:IsShown() then menu:Hide(); return end
    for i, e in ipairs(ENTRIES) do menu.rows[i].text:SetText(e.label()) end
    menu:ClearAllPoints()
    -- open towards the middle of the screen, away from the minimap corner
    local x, y = anchor:GetCenter()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local left = (x or 0) * scale < w / 2
    local top = (y or 0) * scale > h / 2
    menu:SetPoint((top and "TOP" or "BOTTOM") .. (left and "LEFT" or "RIGHT"), anchor,
        (top and "BOTTOM" or "TOP") .. (left and "RIGHT" or "LEFT"), 0, 0)
    menu:Show()
end

---------------------------------------------------------------------------
-- Codex bridge: the Farm Pack's rares and world bosses become Codex entries
-- (called by the Codex while it indexes, "Sister addons" step)
---------------------------------------------------------------------------
function SFP.FeedCodex(cx)
    if SFP.FeedMaterials then SFP:Safe('feed materials', SFP.FeedMaterials, SFP, cx) end
    if SFP.FeedLearned then SFP:Safe('feed learned', SFP.FeedLearned, SFP, cx) end
    if SFP.FeedQuestie and SFP.HasQuestieDB and SFP:HasQuestieDB() then SFP:FeedQuestie(cx) end
    if not (cx and cx.Add and SFP.Rares and SFP.zoneByMap) then return end
    local c = cx.CYAN or ""
    local group = "Rares & world bosses (Farm Pack)"
    for mapID, list in pairs(SFP.Rares) do
        for _, sp in ipairs(list) do
            if sp.hx and sp.npc and sp.npc > 0 then
                local what = {}
                for _, id in ipairs(sp.items or {}) do
                    local name = C_Item.GetItemInfo(id)
                    what[#what + 1] = "• " .. (name or ("item " .. id))
                end
                local kind = sp.hunter and "Hunter tame" or "Rare / world boss"
                local body = c .. "Where|r\n" .. SFP:ZoneName(mapID) ..
                    ("  %.1f, %.1f"):format(sp.hx * 100, sp.hy * 100) .. "\n\n" ..
                    c .. "Type|r\n" .. kind .. (sp.note and ("\n\n" .. c .. "How|r\n" .. sp.note) or "") ..
                    (#what > 0 and ("\n\n" .. c .. "Drops|r\n" .. table.concat(what, "\n")) or "")
                cx:Add({
                    cat = "creature", id = "sfp:" .. mapID .. ":" .. sp.npc, name = sp.name, group = group,
                    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
                    sub = SFP:ZoneName(mapID) .. " - " .. kind,
                    body = body, map = { m = mapID, x = sp.hx, y = sp.hy },
                    wh = "npc=" .. sp.npc, tags = "rare world boss mount farm " .. (sp.hunter and "hunter tame" or ""),
                })
            end
        end
    end
end
