-- SeviathsUsefulTools - spots on the minimap
--
-- The same farm spots, rares, hunter tames, special materials and gathering nodes as on the world
-- map, drawn on the minimap around you. It uses HereBeDragons-Pins (the library Questie, RareScanner
-- and others share), so it follows rotation, zoom and any minimap shape set by Leatrix, BasicMinimap
-- and similar addons. Only the spots near you are drawn.
--
-- Also here: one button to make Questie draw its quests on the minimap in Mists of Pandaria.

local ADDON, SFP = ...

local RANGE = 0.12          -- map units around the player (about the minimap view)
local MAXPINS = 90
local TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local HBD
local pool, shown = {}, {}
local currentMap

local function safe(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

local function getHBD()
    if HBD then return HBD end
    if LibStub then HBD = LibStub("HereBeDragons-Pins-2.0", true) end
    return HBD
end

local function color(s)
    if SFP.SpotColor then return SFP.SpotColor(s) end
    return SFP.CYAN
end

local function acquire()
    local f = table.remove(pool)
    if f then return f end
    f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(12, 12)
    f.outer = f:CreateTexture(nil, "BACKGROUND")
    f.outer:SetAllPoints()
    f.outer:SetTexture(TEX)
    f.outer:SetBlendMode("ADD")
    f.inner = f:CreateTexture(nil, "ARTWORK")
    f.inner:SetSize(5, 5)
    f.inner:SetPoint("CENTER")
    f.inner:SetTexture(TEX)
    f.inner:SetBlendMode("ADD")
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        local s = self.spot
        if not s then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(s.name or "?", color(s).r, color(s).g, color(s).b)
        local tag = s.gather and ("best zone for " .. (s.gather == "ore" and "ore" or "herbs"))
            or (s.hunter and "hunter tame") or (s.rare and "rare") or (s.special and "special material") or "farm spot"
        GameTooltip:AddLine(tag, 0.8, 0.8, 0.8)
        for i, id in ipairs(s.items or {}) do
            if i > 5 then break end
            GameTooltip:AddLine("|T" .. SFP:ItemIcon(id) .. ":12|t " .. SFP:ItemName(id))
        end
        if s.note and s.note ~= "" then GameTooltip:AddLine(s.note, 0.6, 0.6, 0.6, true) end
        GameTooltip:AddLine(string.format("%.1f, %.1f", self.px * 100, self.py * 100), 1, 0.82, 0)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

local function release(key)
    local f = shown[key]
    if not f then return end
    local h = getHBD()
    if h then pcall(h.RemoveMinimapIcon, h, SFP, f) end
    f:Hide()
    f.spot = nil
    pool[#pool + 1] = f
    shown[key] = nil
end

local function clearAll()
    for key in pairs(shown) do release(key) end
end

local function update()
    local h = getHBD()
    if not h or not SFP.db or not SFP.db.minimapSpots or not SFP.db.mapOverlay or not SFP.zoneByMap then
        clearAll()
        return
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py
    if pos and pos.GetXY then px, py = pos:GetXY() end
    local zone = mapID and SFP.zoneByMap[mapID]
    if not zone or not px or px <= 0 or not zone.spawns then
        clearAll()
        return
    end
    if currentMap ~= mapID then clearAll(); currentMap = mapID end

    local wanted, n = {}, 0
    for si, s in ipairs(zone.spawns) do
        if s.points and SFP.ShowSpot and SFP.ShowSpot(s) then
            for pi, p in ipairs(s.points) do
                local dx, dy = p[1] - px, p[2] - py
                if dx * dx + dy * dy < RANGE * RANGE then
                    n = n + 1
                    if n > MAXPINS then break end
                    wanted[si .. ":" .. pi] = { s, p }
                end
            end
        end
        if n > MAXPINS then break end
    end
    for key in pairs(shown) do
        if not wanted[key] then release(key) end
    end
    for key, e in pairs(wanted) do
        if not shown[key] then
            local s, p = e[1], e[2]
            local f = acquire()
            local c = color(s)
            f.spot, f.px, f.py = s, p[1], p[2]
            f.outer:SetVertexColor(c.r, c.g, c.b, 0.75)
            f.inner:SetVertexColor(1, 1, 1, 0.95)
            f:Show()
            local ok = pcall(h.AddMinimapIconMap, h, SFP, f, mapID, p[1], p[2], false, false)
            if ok then shown[key] = f else f:Hide(); pool[#pool + 1] = f end
        end
    end
end

local ticker
SFP:OnLogin(function()
    local f = CreateFrame("Frame")
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 1 then return end
        acc = 0
        SFP:Safe("minimap spots", update)
    end)
    SFP:OnRefresh(function() currentMap = nil end)
    if not getHBD() then
        C_Timer.After(5, function()
            if not getHBD() then SFP.minimapSpotsMissingLib = true end
        end)
    end
end)

---------------------------------------------------------------------------
-- Questie: draw quests on the minimap and the map with its own icons
---------------------------------------------------------------------------
function SFP:QuestieOwnIcons(silent)
    local Q, loader = _G.Questie, _G.QuestieLoader
    if not (Q and Q.db and Q.db.profile and loader and loader.ImportModule) then
        if not silent then self:Print("Questie is not loaded.") end
        return false
    end
    local utils = safe(function() return loader:ImportModule("QuestieOptionsUtils") end)
    local quest = safe(function() return loader:ImportModule("QuestieQuest") end)
    local p = Q.db.profile
    if utils and utils.ExecuteTheme then pcall(utils.ExecuteTheme, nil, "questie") end
    p.enabled = true
    p.enableMapIcons = true
    p.enableMiniMapIcons = true
    p.enableObjectives = true
    if quest then
        pcall(quest.ToggleNotes, quest, true)
        pcall(quest.SmoothReset, quest)
    end
    if not silent then self:Print("Questie now draws its quest icons on the map and the minimap.") end
    return true
end

function SFP:QuestieMinimapOn()
    local Q = _G.Questie
    return Q and Q.db and Q.db.profile and Q.db.profile.enableMiniMapIcons and Q.db.profile.enableObjectives and true or false
end

-- once: the Questie profile of this account used the "Blizzard" icon theme, which switches
-- Questie's own minimap icons and objectives off
SFP:OnLogin(function()
    C_Timer.After(12, function()
        local Q = _G.Questie
        if not (Q and Q.db and Q.db.profile) or SFP.db.questieFixed then return end
        SFP.db.questieFixed = true
        if not SFP:QuestieMinimapOn() then
            SFP:QuestieOwnIcons(true)
            SFP:Print("Questie's minimap icons were off - I switched them on (Questie icon theme). /sfp questie toggles this again.")
        end
    end)
end)
