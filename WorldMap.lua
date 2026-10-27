-- SeviathsUsefulTools - world map overlay
--
-- Zone map: every spawn point of the farm mobs is a soft cyan glow, so the
--   exact farm spots show up as small glowing cyan areas. Each mob gets its
--   name + coordinates at its busiest spot. Hover a glowing spot to see what
--   drops there and the AH value; Ctrl+Click (Blizzard's own) for a waypoint.
--   Spots never take the mouse, so clicking the map works as normal.
-- Continent map (e.g. Broken Isles): zoomed out = one spot per farm mob,
--   zoomed in = the real spawn areas with labels. Nothing covers the map.
-- The spot layer sits at a high frame level: the zone's explored-area art
--   (and other map addons) are drawn as pins above low levels and hid it.
-- Optional (off by default): whole-zone glow + item panel.

local _, SFP = ...

local overlay, spawnLayer, pool, labels, panel, edges, tip
local poolUsed, labelUsed = 0, 0
local pins, pinLabels = {}, {}
local pinUsed, pinLabelUsed = 0, 0
local lastHover
local GLOW = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function C() return SFP.CYAN end

local function sortedItems(list)
    local copy = {}
    for i, id in ipairs(list) do copy[i] = id end
    table.sort(copy, function(a, b)
        local pa, pb = SFP:GetPrice(a) or -1, SFP:GetPrice(b) or -1
        if pa ~= pb then return pa > pb end
        return a < b
    end)
    return copy
end

-- true when zoneID sits somewhere under mapID (continent -> zone)
local function isUnder(zoneID, mapID)
    local info = C_Map.GetMapInfo(zoneID)
    local p, guard = info and info.parentMapID, 0
    while p and guard < 4 do
        if p == mapID then return true end
        local pi = C_Map.GetMapInfo(p)
        p = pi and pi.parentMapID
        guard = guard + 1
    end
    return false
end

---------------------------------------------------------------------------
-- Spawn spots
---------------------------------------------------------------------------
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14|t"
SFP.STAR = STAR
-- hunter class crest: marks creatures hunters can tame (never the grind star)
local HUNTER_ICON = "|TInterface\\Icons\\ClassIcon_Hunter:14:14:0:0:64:64:5:59:5:59|t"
SFP.HUNTER_ICON = HUNTER_ICON
SFP.HUNTER_HEX = "ffabd473"
local HUNTER_TYPE = {
    spirit = "Spirit beast - only Beast Mastery hunters can tame it",
    unique = "Unique-looking pet - any hunter can tame it",
}
SFP.HUNTER_TYPE = HUNTER_TYPE
local COLLECTIBLE = { mount = true, pet = true, toy = true }

-- one loot line: item icon + name (+ drop chance) | source icon + price
local function lootLine(id, bestHere, spot)
    local name = SFP:ItemName(id)
    local info = SFP.Items[id]
    if spot and spot.learned and spot.counts and spot.kills and spot.kills > 0 then
        -- measured from your own kills
        local pct = 100 * (spot.counts[id] or 0) / spot.kills
        name = name .. string.format(" |cffffd100%s%%|r", pct >= 10 and string.format("%.0f", pct) or string.format("%.1f", pct))
    elseif info and info.drop then name = name .. " |cffffd100" .. info.drop .. "|r" end
    if bestHere then name = name .. " |cff40ff40(best spot)|r" end
    local right = SFP:FormatPrice(SFP:GetPrice(id))
    if info and COLLECTIBLE[info.kind] and not SFP:GetPrice(id) then
        right = "|cffa335ee" .. (SFP.KindLabel[info.kind] or "collectible") .. "|r"
    end
    right = SFP:KindIconTag(info and info.kind) .. " " .. right
    tip:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":14|t " .. name, right, 1, 1, 1, 1, 1, 1)
end
SFP.MapLootLine = lootLine

local function showInstanceTip(h)
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    for i, inst in ipairs(h.instances) do
        if i > 1 then tip:AddLine(" ") end
        local raid = inst.kind == "raid"
        tip:AddLine("|T" .. (raid and SFP.RAID_ICON or SFP.DUNGEON_ICON) .. ":16|t " .. inst.name ..
            "  |cffaaaaaa" .. (raid and "Raid" or "Dungeon") .. "|r", 1, 0.5, 0)
        -- mounts first, then sellable BoEs (best price first), then materials
        local mounts, boes, mats, maybe = {}, {}, {}, {}
        for _, id in ipairs(sortedItems(inst.items)) do
            local k = SFP.Items[id] and SFP.Items[id].kind
            if SFP.Items[id] and SFP.Items[id].unconfirmed then
                if SFP.db.showUnconfirmed then maybe[#maybe + 1] = id end
            elseif k == "mount" or k == "pet" or k == "toy" then mounts[#mounts + 1] = id
            elseif k == "boe" then boes[#boes + 1] = id
            else mats[#mats + 1] = id end
        end
        if #mounts > 0 then
            tip:AddLine("Mounts", 0.64, 0.21, 0.93)
            for _, id in ipairs(mounts) do lootLine(id) end
        end
        if #boes > 0 then
            tip:AddLine("BoE gear - sell on the auction house", 0.12, 1, 0)
            for i, id in ipairs(boes) do
                if i > 8 then tip:AddLine("  +" .. (#boes - 8) .. " more BoEs - see the farm browser", 0.6, 0.6, 0.6); break end
                lootLine(id)
            end
        end
        if #mats > 0 then
            tip:AddLine("Materials", 0.6, 0.6, 0.6)
            for _, id in ipairs(mats) do lootLine(id) end
        end
        if inst.note then tip:AddLine(inst.note, 0.8, 0.8, 0.8, true) end
        if #maybe > 0 then
            tip:AddLine("Possible BoEs - unconfirmed, may have been changed", 0.6, 0.6, 0.6)
            for _, id in ipairs(maybe) do
                local price = SFP:GetPrice(id)
                tip:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":14|t |cff9d9d9d" .. SFP:ItemName(id):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r",
                    price and SFP:FormatPrice(price) or "|cff808080?|r", 1, 1, 1, 1, 1, 1)
            end
        end

    end
    tip:AddLine(string.format("Entrance  %.1f, %.1f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    local anyDrop = false
    for _, inst in ipairs(h.instances) do
        for _, id in ipairs(inst.items) do if SFP.Items[id] and SFP.Items[id].drop then anyDrop = true end end
    end
    if anyDrop then tip:AddLine("Drop chances are rough community estimates", 0.5, 0.5, 0.5) end
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

local function showGatherTip(h)
    local s = h.spawn
    local id = s.items[1]
    local ore = s.gather == "ore"
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    if h.continent then tip:AddLine(SFP:ZoneName(h.zoneID), 1, 1, 1) end
    local c = ore and { r = 1, g = 0.75, b = 0.45 } or { r = 0.35, g = 1, b = 0.6 }
    tip:AddLine(SFP:KindIconTag(s.gather, 16) .. " " .. s.name .. "  |cffaaaaaa" .. (ore and "Mining" or "Herbalism") .. "|r", c.r, c.g, c.b)
    tip:AddLine(string.format("%.1f, %.1f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    tip:AddLine("|cff40ff40Best zone for " .. SFP:ItemName(id) .. "|r", 1, 1, 1)
    tip:AddLine((s.nodes or "?") .. " recorded nodes in " .. SFP:ZoneName(h.zoneID) .. " - more than any other zone", 0.8, 0.8, 0.8, true)
    tip:AddLine("Gathered", 0.6, 0.6, 0.6)
    lootLine(id)
    if not SFP:GetPrice(id) then tip:AddLine("Prices appear after you open the auction house once", 0.5, 0.5, 0.5) end
    tip:AddLine("Glow = where the nodes spawn (sample of the node positions)", 0.6, 0.6, 0.6, true)
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

local function showClusterTip(h)
    local c = h.cluster
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    if h.continent then tip:AddLine(SFP:ZoneName(h.zoneID), 1, 1, 1) end
    tip:AddLine(SFP:KindIconTag("ore", 16) .. SFP:KindIconTag("herb", 16) .. " Gathering around here", 1, 0.82, 0.5)
    tip:AddLine(string.format("approx. %.0f, %.0f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    local ids = {}
    for id in pairs(c.items) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local ka, kb = SFP.Items[a].kind, SFP.Items[b].kind
        if ka ~= kb then return ka == "ore" end
        return c.items[a] > c.items[b]
    end)
    for _, id in ipairs(ids) do
        local info = SFP.Items[id]
        local price = SFP:GetPrice(id)
        tip:AddDoubleLine(SFP:KindIconTag(info.kind) .. " |T" .. SFP:ItemIcon(id) .. ":14|t " .. SFP:ItemName(id),
            (price and SFP:FormatPrice(price) or "") , 1, 1, 1, 1, 1, 1)
    end
    tip:AddLine("|cff40ff40" .. SFP:ZoneName(h.zoneID) .. " is the best zone for all of these|r", 1, 1, 1, true)
    tip:AddLine("Nodes spawn in the area around this symbol", 0.6, 0.6, 0.6, true)
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

-- several mobs share one marker: list each with what it drops
local function showMultiTip(h)
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    if h.continent then tip:AddLine(SFP:ZoneName(h.zoneID), 1, 1, 1) end
    tip:AddLine(#h.spawns .. " farm spots in this area", 0.6, 0.6, 0.6)
    tip:AddLine(string.format("approx. %.1f, %.1f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    for i, s in ipairs(h.spawns) do
        if i > 6 then tip:AddLine("+" .. (#h.spawns - 6) .. " more - zoom in to see them", 0.6, 0.6, 0.6); break end
        local col = s.hunter and { 0.67, 0.83, 0.45 } or s.rare and { 1, 0.6, 0.2 } or s.special and { 1, 0.3, 0.85 } or { 0, 0.9, 1 }
        local title = s.name
        if s.hunter then title = SFP.HUNTER_ICON .. " " .. title .. "  |c" .. SFP.HUNTER_HEX .. "(Hunter tame)|r" end
        if s.rare then title = title .. "  |cffff8000(Rare)|r" end
        if s.grind then title = STAR .. " " .. title end
        tip:AddLine(" ")
        tip:AddLine(title, col[1], col[2], col[3])
        if s.hunter then
            tip:AddLine(SFP.HUNTER_TYPE[s.hunter] or "Hunter tame", 0.8, 0.8, 0.8, true)
        else
            local best = {}
            for _, id in ipairs(s.bestFor or {}) do best[id] = true end
            if s.learned then tip:AddLine("learned from your loot, " .. (s.kills or 0) .. " kills", 0.4, 0.8, 1) end
            for _, id in ipairs(sortedItems(s.items)) do lootLine(id, best[id], s) end
        end
    end
    local zone = SFP.zoneByMap[h.zoneID]
    if zone and not zone.rareOnly then
        tip:AddLine(" ")
        local boeText, boeWhere = SFP:RandomBoeText(h.zoneID)
        tip:AddDoubleLine(boeText, boeWhere, 1, 1, 1, 0.7, 0.7, 0.7)
    end
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

local function showSpotTip(h)
    if h.cluster then return showClusterTip(h) end
    if h.spawns and #h.spawns > 1 then return showMultiTip(h) end
    if h.instances then return showInstanceTip(h) end
    if h.spawn.gather then return showGatherTip(h) end
    local s = h.spawn
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    if h.continent then tip:AddLine(SFP:ZoneName(h.zoneID), 1, 1, 1) end
    local col = s.hunter and { r = 0.67, g = 0.83, b = 0.45 } or s.rare and { r = 1, g = 0.6, b = 0.2 }
        or s.special and { r = 1, g = 0.3, b = 0.85 } or C()
    local title = s.name
    if s.rare then title = title .. "  |cffff8000(Rare)|r" end
    if s.hunter then title = HUNTER_ICON .. " " .. title .. "  |c" .. SFP.HUNTER_HEX .. "(Hunter tame)|r" end
    if s.grind then title = STAR .. " " .. title end
    tip:AddLine(title, col.r, col.g, col.b)
    tip:AddLine(string.format("%.1f, %.1f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    if s.grind then tip:AddLine(STAR .. " worth grinding", 1, 0.82, 0) end
    if s.special and not s.rare then tip:AddLine("|cffff4dd9Special material spot|r", 1, 1, 1) end
    if s.hunter then
        tip:AddLine(HUNTER_ICON .. " " .. (HUNTER_TYPE[s.hunter] or "Hunter tame"), 0.67, 0.83, 0.45, true)
    end
    if s.note and s.note ~= "" then
        if s.hunter then tip:AddLine("How to tame:", 0.6, 0.6, 0.6) end
        tip:AddLine(s.note, 0.8, 0.8, 0.8, true)
    end

    local best = {}
    for _, id in ipairs(s.bestFor or {}) do best[id] = true end
    local function line(id) lootLine(id, best[id], s) end
    if s.learned then
        tip:AddLine("Learned from your own loot - " .. (s.kills or 0) .. " kills here", 0.4, 0.8, 1, true)
    end
    if s.bestFor and not s.rare then
        local names = {}
        for i, id in ipairs(s.bestFor) do names[i] = SFP:ItemName(id) end
        tip:AddLine("|cff40ff40Best spot for " .. table.concat(names, ", ") .. "|r", 1, 1, 1, true)
    end

    if s.hunter then
        tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
        tip:Show()
        return
    end

    -- what this mob / rare drops
    local shown = {}
    if #s.items > 0 then
        tip:AddLine(s.rare and "Drops" or "Farmed here", 0.6, 0.6, 0.6)
        for _, id in ipairs(sortedItems(s.items)) do line(id); shown[id] = true end
    end

    -- everything else worth farming in this zone (other mobs, zone-wide drops, etc.)
    local zone = SFP.zoneByMap[h.zoneID]
    local rest = {}
    local function mobLoot(id) -- ores, herbs and enchanting mats live in the gathering list, not on mob spots
        local info = SFP.Items[id]
        return not (info and (info.kind == "ore" or info.kind == "herb" or info.kind == "enchant"))
    end
    for _, id in ipairs(zone and zone.items or {}) do
        if not shown[id] and mobLoot(id) then rest[#rest + 1] = id; shown[id] = true end
    end
    local exp = SFP.zoneExp[h.zoneID]
    for _, id in ipairs(exp and exp.anywhere or {}) do
        if not shown[id] and mobLoot(id) then rest[#rest + 1] = id; shown[id] = true end
    end
    if #rest > 0 then
        tip:AddLine("Also in " .. SFP:ZoneName(h.zoneID), 0.6, 0.6, 0.6)
        for _, id in ipairs(sortedItems(rest)) do line(id) end
    end

    if zone and not zone.rareOnly then
        local boeText, boeWhere = SFP:RandomBoeText(h.zoneID)
        tip:AddDoubleLine(boeText, boeWhere, 1, 1, 1, 0.7, 0.7, 0.7)
    end
    local hows, seenHow = {}, {}
    for _, id in ipairs(s.items) do
        local info = SFP.Items[id]
        local how = info and SFP.KindHow[info.kind]
        if how and not seenHow[how] then seenHow[how] = true; hows[#hows + 1] = SFP:KindIconTag(info.kind) .. " " .. how end
    end
    if #hows > 0 then tip:AddLine("Source: " .. table.concat(hows, ",  "), 0.7, 0.7, 0.7, true) end
    local hasPrice = false
    for id in pairs(shown) do if SFP:GetPrice(id) then hasPrice = true; break end end
    if not hasPrice then
        tip:AddLine("Prices appear after you open the auction house once", 0.5, 0.5, 0.5)
    end
    if s.rare then tip:AddLine("Rare spawn - respawn timer varies", 0.6, 0.6, 0.6) end
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

local hoverList = {}   -- spots on the current map, for hover detection

local function getPin()
    pinUsed = pinUsed + 1
    local p = pins[pinUsed]
    if not p then
        p = CreateFrame("Frame", nil, spawnLayer)
        p:EnableMouse(false) -- never steal clicks: the map still opens zones normally
        p.outer = p:CreateTexture(nil, "BACKGROUND")
        p.outer:SetTexture(GLOW)
        p.outer:SetBlendMode("ADD")
        p.outer:SetPoint("CENTER")
        p.inner = p:CreateTexture(nil, "ARTWORK")
        p.inner:SetTexture(GLOW)
        p.inner:SetBlendMode("ADD")
        p.inner:SetPoint("CENTER")
        pins[pinUsed] = p
    end
    if p.icon then p.icon:Hide() end
    if p.icon2 then p.icon2:Hide() end
    p:Show()
    return p
end

local function getPinLabel()
    pinLabelUsed = pinLabelUsed + 1
    local fs = pinLabels[pinLabelUsed]
    if not fs then
        fs = spawnLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetFont(fs:GetFont(), 12, "OUTLINE")
        fs:SetJustifyH("CENTER")
        pinLabels[pinLabelUsed] = fs
    end
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local function clearSpawns()
    for i = 1, #pins do pins[i]:Hide() end
    for i = 1, #pinLabels do pinLabels[i]:Hide() end
    pinUsed, pinLabelUsed = 0, 0
    wipe(hoverList)
end

local function canvasScale()
    local sc = WorldMapFrame.ScrollContainer
    return (sc.GetCanvasScale and sc:GetCanvasScale()) or 1
end

local RARE = { r = 1.0, g = 0.5, b = 0.0 }
local HUNTER = { r = 0.55, g = 0.85, b = 0.25 }
local ORE  = { r = 1.0, g = 0.7, b = 0.35 }
local SPECIAL = { r = 1.0, g = 0.25, b = 0.85 }
local HERB = { r = 0.3, g = 1.0, b = 0.55 }
local function spotColor(sp)
    if sp.gather then return sp.gather == "ore" and ORE or HERB end
    return sp.hunter and HUNTER or sp.rare and RARE or sp.special and SPECIAL or C()
end
local function showSpot(sp)
    if sp.gather then return sp.gather == "ore" and SFP.db.showMining or sp.gather == "herb" and SFP.db.showHerbs or false end
    if sp.hunter then return SFP.db.showHunter end
    if sp.rare then return SFP.db.showRares end
    if sp.special then return SFP.db.showSpecial end
    return SFP.db.showSpawns
end

SFP.ShowSpot, SFP.SpotColor = showSpot, spotColor

local function placePin(p, x, y, outer, outerAlpha, inner, h)
    local c = spotColor(h.spawn)
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    local minPx = 7 / canvasScale() -- never smaller than ~7 screen pixels
    outer, inner = math.max(outer, minPx * 2), math.max(inner, minPx * 0.6)
    p:SetSize(outer, outer)
    p.outer:SetSize(outer, outer)
    p.outer:SetVertexColor(c.r, c.g, c.b, outerAlpha)
    p.inner:SetSize(inner, inner)
    p.inner:SetVertexColor(c.r, c.g, c.b, 0.95)
    p:ClearAllPoints()
    p:SetPoint("CENTER", spawnLayer, "TOPLEFT", x * w, -y * hh)
    h.mx, h.my = x, y
    hoverList[#hoverList + 1] = h
end

local function label(x, y, text, lift, shift)
    local w, h = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    local fs = getPinLabel()
    fs:SetFont(fs:GetFont(), math.max(9, 12 / canvasScale()), "OUTLINE")
    fs:SetPoint("BOTTOM", spawnLayer, "TOPLEFT", x * w, -y * h + lift - shift * (28 / canvasScale()))
    fs:SetText(text)
end

local function spotText(s, px, py, more)
    -- BoE farm mobs get a purple "BoE" tag so they stand out on the map
    local tag, hex = "", SFP.CYAN_HEX
    if s.rare then tag, hex = " |cffff8000[Rare]|r", "ffff9933"
    elseif s.special then tag, hex = " |cffff4dd9[Special]|r", "ffff66e0" end
    if s.gather then
        local hx2 = s.gather == "ore" and "ffffb366" or "ff4dff8c"
        return string.format("%s |c%s%s|r\n|cff40ff40Best zone: %s|r\n|cffffd100%.1f, %.1f|r",
            SFP:KindIconTag(s.gather, 14), hx2, s.name, SFP:ItemName(s.items[1]), (px or s.hx) * 100, (py or s.hy) * 100)
    end
    if s.hunter then
        return string.format("%s |c%s%s|r |c%s[Hunter]|r\n|cffffd100%.1f, %.1f|r",
            HUNTER_ICON, SFP.HUNTER_HEX, s.name, SFP.HUNTER_HEX, (px or s.hx) * 100, (py or s.hy) * 100)
    end
    local star = s.grind and (STAR .. " ") or ""
    for _, id in ipairs(s.items) do
        local info = SFP.Items[id]
        if info and info.kind == "boe" then tag = tag .. " |cffa335ee[BoE]|r"; break end
        if info and info.kind == "mount" then tag = tag .. " |cffffd100[Mount]|r"; break end
        if info and (info.kind == "pet" or info.kind == "toy") then tag = tag .. " |cffffd100[" .. SFP.KindLabel[info.kind] .. "]|r"; break end
    end
    local bestLine = ""
    if s.bestFor and not s.rare then
        local names = {}
        for i, id in ipairs(s.bestFor) do
            local info = SFP.Items[id]
            names[i] = SFP:KindIconTag(info and info.kind, 12) .. SFP:ItemName(id)
        end
        bestLine = "\n|cff40ff40Best spot: " .. table.concat(names, ", ") .. "|r"
    end
    return string.format("%s|c%s%s|r%s%s%s\n|cffffd100%.1f, %.1f|r", star, hex, s.name, tag, more or "", bestLine, (px or s.hx) * 100, (py or s.hy) * 100)
end

-- draw all spawn points of a zone's farm mobs, mapped into the viewed map
-- (rect = zone position on that map; nil when viewing the zone itself)
-- Spawn points are grouped into areas: one small marker per area instead of a
-- glow per spawn point. Mobs of the same kind (farm / rare / special / hunter)
-- whose areas overlap share one marker; hover it to see all of them.
local AREA_R = 0.07
local function spotCat(s)
    return s.hunter and "hunter" or s.rare and "rare" or s.special and "special" or "farm"
end
local function spawnClusters(zone)
    local exact = SFP.db.exactSpots
    local key = (SFP.db.showSpawns and "f" or "") .. (SFP.db.showRares and "r" or "") ..
        (SFP.db.showSpecial and "s" or "") .. (SFP.db.showHunter and "h" or "") .. (exact and "x" or "")
    local radius = exact and 0.0035 or AREA_R
    zone._areas = zone._areas or {}
    if zone._areas[key] then return zone._areas[key] end
    local list = {}
    for _, s in ipairs(zone.spawns or {}) do
        if not s.gather and showSpot(s) then
            local cat = spotCat(s)
            for _, pt in ipairs(s.points) do
                local best, bd
                for _, c in ipairs(list) do
                    if c.cat == cat then
                        local dx, dy = c.x - pt[1], c.y - pt[2]
                        local d = dx * dx + dy * dy
                        if d < radius * radius and (not bd or d < bd) then best, bd = c, d end
                    end
                end
                if not best then
                    best = { x = pt[1], y = pt[2], n = 0, cat = cat, count = {}, order = {} }
                    list[#list + 1] = best
                end
                best.x = (best.x * best.n + pt[1]) / (best.n + 1)
                best.y = (best.y * best.n + pt[2]) / (best.n + 1)
                best.n = best.n + 1
                if not best.count[s] then best.order[#best.order + 1] = s end
                best.count[s] = (best.count[s] or 0) + 1
            end
        end
    end
    for _, c in ipairs(list) do
        table.sort(c.order, function(a, b) return c.count[a] > c.count[b] end)
    end
    zone._areas[key] = list
    return list
end

-- symbol on top of a marker, always visible (no text needed):
-- gold star = rare / BoE spot worth grinding, hunter crest = hunter tame
local STAR_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local HUNTER_TEX = "Interface\\Icons\\ClassIcon_Hunter"
local function markSymbol(p, spawns, sc)
    local tex
    for _, s in ipairs(spawns) do
        if s.hunter then tex = tex or HUNTER_TEX end
        if s.grind then tex = STAR_TEX end
    end
    if not tex then return end
    if not p.icon then p.icon = p:CreateTexture(nil, "OVERLAY") end
    local size = 14 / sc
    p.icon:ClearAllPoints()
    p.icon:SetPoint("CENTER")
    p.icon:SetSize(size, size)
    p.icon:SetTexture(tex)
    if tex == HUNTER_TEX then p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else p.icon:SetTexCoord(0, 1, 0, 1) end
    p.icon:Show()
end

local function drawAreas(zoneID, rect, unit, withLabels)
    local zone = SFP.zoneByMap[zoneID]
    local l, r, t, b = 0, 1, 0, 1
    if rect then l, r, t, b = rect[1], rect[2], rect[3], rect[4] end
    local sc = canvasScale()
    local placed = {}
    for _, c in ipairs(spawnClusters(zone)) do
        local main = c.order[1]
        local x, y = l + c.x * (r - l), t + c.y * (b - t)
        -- small marker, fixed size on screen; a little bigger for busy areas
        local big = math.min(1 + (c.n - 1) * 0.04, 1.6)
        if SFP.db.exactSpots then big = 1 end
        local p = getPin()
        placePin(p, x, y, (SFP.db.exactSpots and 12 or 16 * big) / sc, 0.55, (SFP.db.exactSpots and 5 or 6 * big) / sc,
            { spawn = main, spawns = c.order, zoneID = zoneID, zx = c.x, zy = c.y, continent = rect ~= nil })
        markSymbol(p, c.order, sc)
        if withLabels and SFP.db.showLabels then
            local shift = 0
            for _, q in ipairs(placed) do
                if math.abs(q[1] - x) < 0.06 * (r - l) and math.abs(q[2] - y) < 0.04 * (b - t) then shift = shift + 1 end
            end
            placed[#placed + 1] = { x, y }
            local more = #c.order > 1 and (" |cffaaaaaa+" .. (#c.order - 1) .. " more|r") or nil
            label(x, y, spotText(main, c.x, c.y, more), 10 / sc + 4, shift)
        end
    end
end

-- Zone map: every spawn point glows; overlapping glows form a cyan area
local function drawZoneSpawns(zoneID)
    local zone = SFP.zoneByMap[zoneID]
    if not zone or not zone.spawns then return end
    local w = spawnLayer:GetWidth()
    if w <= 0 then return end
    drawAreas(zoneID, nil, w / 100, true)
end

-- Continent map: zoomed out = one bright spot per farm mob;
-- zoomed in = the real spawn areas + name/coordinate labels, like the zone map
local function drawContinentSpots(mapID)
    local w = spawnLayer:GetWidth()
    if w <= 0 then return end
    local unit = w / 100
    local sc = WorldMapFrame.ScrollContainer
    local zoomed = sc.IsZoomedIn and sc:IsZoomedIn()
    for zoneID, zone in pairs(SFP.zoneByMap) do
        if zone.spawns and SFP:IsValuableZone(zoneID) and isUnder(zoneID, mapID) then
            local l, r, t, b = C_Map.GetMapRectOnMap(zoneID, mapID)
            if l and r > l and b > t then
                if zoomed then
                    drawAreas(zoneID, { l, r, t, b }, unit, true)
                else
                    for _, s in ipairs(zone.spawns) do
                        if showSpot(s) and not s.gather then
                            local cx, cy = l + s.hx * (r - l), t + s.hy * (b - t)
                            local p = getPin()
                            placePin(p, cx, cy, unit * 1.8, 0.6, unit * 0.45,
                                { spawn = s, zoneID = zoneID, zx = s.hx, zy = s.hy, continent = true })
                            markSymbol(p, { s }, canvasScale())
                        end
                    end
                end
            end
        end
    end
end

-- Mining / herbalism: a few small symbols per zone instead of glows. Node
-- positions of all ores/herbs whose best zone this is are grouped into
-- areas; each area gets one symbol listing every material found around it.
local CLUSTER_R = 0.12
local function gatherClusters(zone)
    local key = (SFP.db.showMining and "o" or "") .. (SFP.db.showHerbs and "h" or "")
    zone._clusters = zone._clusters or {}
    if zone._clusters[key] then return zone._clusters[key] end
    local list = {}
    for _, s in ipairs(zone.spawns or {}) do
        if s.gather and showSpot(s) then
            local id = s.items[1]
            for _, pt in ipairs(s.points) do
                local best, bd
                for _, c in ipairs(list) do
                    local dx, dy = c.x - pt[1], c.y - pt[2]
                    local d = dx * dx + dy * dy
                    if d < CLUSTER_R * CLUSTER_R and (not bd or d < bd) then best, bd = c, d end
                end
                if not best then
                    best = { x = pt[1], y = pt[2], n = 0, items = {}, kinds = {} }
                    list[#list + 1] = best
                end
                best.x = (best.x * best.n + pt[1]) / (best.n + 1)
                best.y = (best.y * best.n + pt[2]) / (best.n + 1)
                best.n = best.n + 1
                best.items[id] = (best.items[id] or 0) + 1
                best.kinds[s.gather] = true
            end
        end
    end
    zone._clusters[key] = list
    return list
end

local function placeSymbol(x, y, c, zoneID, continent, w, hh)
    local p = getPin()
    local size = 15 / canvasScale()
    p:SetSize(size * 1.6, size * 1.6)
    p.outer:SetSize(1, 1); p.outer:SetVertexColor(0, 0, 0, 0)
    p.inner:SetSize(1, 1); p.inner:SetVertexColor(0, 0, 0, 0)
    if not p.icon then p.icon = p:CreateTexture(nil, "OVERLAY") end
    if not p.icon2 then p.icon2 = p:CreateTexture(nil, "OVERLAY") end
    local both = c.kinds.ore and c.kinds.herb
    p.icon:ClearAllPoints()
    p.icon:SetPoint("CENTER", both and -size * 0.3 or 0, 0)
    p.icon:SetSize(size, size)
    p.icon:SetTexture(SFP.KindIcon[c.kinds.ore and "ore" or "herb"])
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.icon:Show()
    if both then
        p.icon2:ClearAllPoints()
        p.icon2:SetPoint("CENTER", size * 0.35, -size * 0.25)
        p.icon2:SetSize(size * 0.8, size * 0.8)
        p.icon2:SetTexture(SFP.KindIcon.herb)
        p.icon2:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        p.icon2:Show()
    else
        p.icon2:Hide()
    end
    p:ClearAllPoints()
    p:SetPoint("CENTER", spawnLayer, "TOPLEFT", x * w, -y * hh)
    hoverList[#hoverList + 1] = { cluster = c, zoneID = zoneID, mx = x, my = y, zx = c.x, zy = c.y, continent = continent }
end

local function drawGatherSymbols(zoneID, rect)
    local zone = SFP.zoneByMap[zoneID]
    if not zone or not zone.spawns then return end
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    if w <= 0 then return end
    local l, r, t, b = 0, 1, 0, 1
    if rect then l, r, t, b = rect[1], rect[2], rect[3], rect[4] end
    for _, c in ipairs(gatherClusters(zone)) do
        placeSymbol(l + c.x * (r - l), t + c.y * (b - t), c, zoneID, rect ~= nil, w, hh)
    end
end

local function drawGatherContinent(mapID)
    local sc = WorldMapFrame.ScrollContainer
    local zoomed = sc.IsZoomedIn and sc:IsZoomedIn()
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    for zoneID, zone in pairs(SFP.zoneByMap) do
        if zone.spawns and isUnder(zoneID, mapID) then
            local l, r, t, b = C_Map.GetMapRectOnMap(zoneID, mapID)
            if l and r > l and b > t then
                if zoomed then
                    drawGatherSymbols(zoneID, { l, r, t, b })
                else -- zoomed out: one symbol per zone holding all its materials
                    local all = { x = 0, y = 0, n = 0, items = {}, kinds = {} }
                    for _, c in ipairs(gatherClusters(zone)) do
                        all.x, all.y, all.n = all.x + c.x * c.n, all.y + c.y * c.n, all.n + c.n
                        for id, k in pairs(c.items) do all.items[id] = (all.items[id] or 0) + k end
                        for k in pairs(c.kinds) do all.kinds[k] = true end
                    end
                    if all.n > 0 then
                        all.x, all.y = all.x / all.n, all.y / all.n
                        placeSymbol(l + all.x * (r - l), t + all.y * (b - t), all, zoneID, true, w, hh)
                    end
                end
            end
        end
    end
end

-- Dungeon / raid entrances on the viewed map (icon + loot on hover)
local function drawInstances(mapID)
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    if w <= 0 then return end
    local groups = {}
    for _, exp in ipairs(SFP.Expansions) do
        for _, inst in ipairs(exp.instances or {}) do
            local e = SFP:FindEntrance(inst)
            local want = (inst.kind == "raid") and SFP.db.showRaids or (inst.kind ~= "raid" and SFP.db.showDungeons)
            if want and #inst.items > 0 and e and e.map == mapID then
                local key = string.format("%.3f:%.3f", e.x, e.y)
                local g = groups[key]
                if not g then g = { x = e.x, y = e.y, list = {} }; groups[key] = g end
                table.insert(g.list, inst)
            end
        end
    end
    local size = 22 / canvasScale()
    for _, g in pairs(groups) do
        local p = getPin()
        local raid = false
        for _, inst in ipairs(g.list) do if inst.kind == "raid" then raid = true end end
        p:SetSize(size * 1.8, size * 1.8)
        p.outer:SetSize(size * 1.8, size * 1.8)
        p.outer:SetVertexColor(1, 0.5, 0, 0.35)
        p.inner:SetSize(1, 1)
        p.inner:SetVertexColor(0, 0, 0, 0)
        if not p.icon then p.icon = p:CreateTexture(nil, "OVERLAY") end
        p.icon:ClearAllPoints(); p.icon:SetPoint("CENTER"); p.icon:SetTexCoord(0, 1, 0, 1)
        p.icon:SetTexture(raid and SFP.RAID_ICON or SFP.DUNGEON_ICON)
        p.icon:SetSize(size, size)
        p.icon:Show()
        p:ClearAllPoints()
        p:SetPoint("CENTER", spawnLayer, "TOPLEFT", g.x * w, -g.y * hh)
        hoverList[#hoverList + 1] = { instances = g.list, mx = g.x, my = g.y, zx = g.x, zy = g.y }
    end
end

---------------------------------------------------------------------------
-- Optional whole-zone glow (off by default)
---------------------------------------------------------------------------
local function getTexture()
    poolUsed = poolUsed + 1
    local t = pool[poolUsed]
    if not t then
        t = overlay:CreateTexture(nil, "OVERLAY")
        t:SetBlendMode("ADD")
        pool[poolUsed] = t
    end
    t:ClearAllPoints()
    t:SetTexCoord(0, 1, 0, 1)
    t:Show()
    return t
end

local function releaseAll()
    for i = 1, #pool do pool[i]:Hide() end
    poolUsed = 0
end

local function pointInZone(parentMap, zoneID, l, r, t, b)
    local function hit(x, y)
        local info = C_Map.GetMapInfoAtPosition(parentMap, x, y)
        return info and info.mapID == zoneID
    end
    local cx, cy = (l + r) / 2, (t + b) / 2
    if hit(cx, cy) then return cx, cy end
    for i = 1, 5 do
        for j = 1, 5 do
            local x, y = l + (r - l) * (i / 6), t + (b - t) * (j / 6)
            if hit(x, y) then return x, y end
        end
    end
end

SFP.IsUnderMap = function(z, m) return isUnder(z, m) end

local function drawZoneFill(parentMap, zoneID, cr, cg, cb, ca)
    local l, r, t, b = C_Map.GetMapRectOnMap(zoneID, parentMap)
    if not l or r <= l or b <= t then return end
    local w, h = overlay:GetWidth(), overlay:GetHeight()
    local c = C()
    local px, py = pointInZone(parentMap, zoneID, l, r, t, b)
    if not px then return end
    local fileDataID, atlasID, texPctX, texPctY, texX, texY, scrollX, scrollY =
        C_Map.GetMapHighlightInfoAtPosition(parentMap, px, py)
    if not ((fileDataID and fileDataID > 0) or atlasID) then return end
    local tex = getTexture()
    if atlasID then
        tex:SetAtlas(atlasID, true, "TRILINEAR")
        tex:SetPoint("CENTER", overlay, "CENTER", ((scrollX + 0.5 * texX) - 0.5) * w, -((scrollY + 0.5 * texY) - 0.5) * h)
    else
        tex:SetTexture(fileDataID, nil, nil, "LINEAR")
        tex:SetTexCoord(0, texPctX, 0, texPctY)
        tex:SetSize(texX * w, texY * h)
        tex:SetPoint("TOPLEFT", overlay, "TOPLEFT", scrollX * w, -scrollY * h)
    end
    tex:SetVertexColor(cr or c.r, cg or c.g, cb or c.b, ca or 0.45)
end
SFP.DrawZoneFill = drawZoneFill

---------------------------------------------------------------------------
-- Optional item panel (off by default; turn on in the browser)
---------------------------------------------------------------------------
local ROW_H = 16
local function panelRow(i)
    panel.rows = panel.rows or {}
    local row = panel.rows[i]
    if row then row:Show(); return row end
    row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetPoint("LEFT")
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.left:SetJustifyH("LEFT")
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT")
    row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:AddLine("Right-click: Wowhead link", 0, 0.9, 1)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if self.itemID and button == "RightButton" then SFP:ShowWowhead(self.itemID)
        elseif self.waypoint then
            local wp = self.waypoint
            SFP:SetWaypoint(wp.map, wp.x, wp.y, wp.label)
        end
    end)
    panel.rows[i] = row
    return row
end

local function fillPanel(zoneID)
    local zone = SFP.zoneByMap[zoneID]
    local n = 0
    local function add()
        n = n + 1
        local r = panelRow(n)
        local y = -26 - (n - 1) * ROW_H
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
        r:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y)
        return r
    end
    panel.title:SetText("|c" .. SFP.CYAN_HEX .. SFP:ZoneName(zoneID) .. "|r")
    for _, id in ipairs(sortedItems(zone.items)) do
        local r = add()
        r.itemID, r.waypoint = id, nil
        r.icon:SetTexture(SFP:ItemIcon(id)); r.icon:Show()
        r.left:SetText(SFP:ItemName(id))
        r.right:SetText(SFP:FormatPrice(SFP:GetPrice(id)))
    end
    for _, s in ipairs(zone.spawns or {}) do
        local r = add()
        r.itemID, r.waypoint = nil, { map = zoneID, x = s.hx, y = s.hy, label = s.name }
        r.icon:Hide()
        r.left:SetText("|c" .. SFP.CYAN_HEX .. s.name .. "|r")
        r.right:SetText(string.format("%.1f, %.1f", s.hx * 100, s.hy * 100))
    end
    if panel.rows then for i = n + 1, #panel.rows do panel.rows[i]:Hide() end end
    panel:SetHeight(34 + n * ROW_H)
end

---------------------------------------------------------------------------
-- Gathering list (side of the zone map): the expansion's ores and herbs and
-- the best zone for each. Click a row to open that zone.
---------------------------------------------------------------------------
local gatherPanel
local GROW_H = 18

local function buildGatherPanel()
    local sc = WorldMapFrame.ScrollContainer
    local f = CreateFrame("Frame", "SeviathsUsefulToolsGatherList", sc, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetWidth(262)
    f:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -8, 8)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.04, 0.02, 0.88)
    f:SetBackdropBorderColor(1, 0.7, 0.35, 0.8)
    f:EnableMouse(true)

    f.head = CreateFrame("Button", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(20)
    f.title = f.head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", 7, 0)
    f.toggle = f.head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.toggle:SetPoint("RIGHT", -7, 0)
    f.head:SetScript("OnClick", function()
        SFP.db.gatherCollapsed = not SFP.db.gatherCollapsed
        SFP.RefreshWorldMap()
    end)
    f.rows = {}
    return f
end

local function gatherRow(i)
    local r = gatherPanel.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, gatherPanel)
    r:SetHeight(GROW_H)
    r:SetPoint("LEFT", 4, 0)
    r:SetPoint("RIGHT", -4, 0)
    r.kind = r:CreateTexture(nil, "ARTWORK")
    r.kind:SetSize(13, 13)
    r.kind:SetPoint("LEFT", 2, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(15, 15)
    r.icon:SetPoint("LEFT", r.kind, "RIGHT", 3, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.name:SetJustifyH("LEFT")
    r.best = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.best:SetPoint("RIGHT", -2, 0)
    r.best:SetJustifyH("RIGHT")
    r:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    r:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(self.item)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.bestText, 0.25, 1, 0.25, true)
        if self.target then GameTooltip:AddLine("Click: open that zone", 0, 0.9, 1) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if self.target and self.target ~= WorldMapFrame:GetMapID() then WorldMapFrame:SetMapID(self.target) end
    end)
    gatherPanel.rows[i] = r
    return r
end

-- what spawns in this zone: every ore/herb (any expansion) with recorded
-- nodes here, most common first, plus the best zone for each
local function gatherHere(mapID)
    local rows, seen = {}, {}
    local exp = SFP:ExpansionForMap(mapID)
    for _, g in ipairs(SFP.Gather or {}) do
        if not seen[g.item] then
            local counts = SFP.GatherZones and SFP.GatherZones[g.item]
            local here, bestMap, bestN
            if counts then
                here = counts[mapID]
                for m, c in pairs(counts) do if not bestN or c > bestN then bestMap, bestN = m, c end end
            elseif g.listOnly then
                -- not a node of its own (bonus loot, dungeon-only node, mob drop): list it in
                -- the zones named in g.zones, or across the expansion when none are given
                if g.zones then
                    for _, zm in ipairs(g.zones) do if zm == mapID then here = 0 end end
                elseif exp and exp.key == g.exp then here = 0 end
                bestMap = g.zones and nil or g.map
            elseif g.map == mapID then
                here, bestMap, bestN = g.nodes or 0, g.map, g.nodes
            end
            if here then
                seen[g.item] = true
                rows[#rows + 1] = { item = g.item, kind = g.kind, here = here, best = bestMap, bestN = bestN, exp = g.exp, how = g.how }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.kind ~= b.kind then return a.kind == "ore" end
        if a.here ~= b.here then return a.here > b.here end
        return a.item < b.item
    end)
    return rows
end
SFP.GatherHere = gatherHere

local function drawGatherList(mapID)
    local rows = gatherHere(mapID)
    gatherPanel = gatherPanel or buildGatherPanel()
    gatherPanel.title:SetText("|cffffb366Mining|r & |cff4dff8cHerbalism|r  |cffaaaaaa" .. SFP:ZoneName(mapID) .. "|r")
    gatherPanel.toggle:SetText(SFP.db.gatherCollapsed and "[+]" or "[-]")
    local n = 0
    if not SFP.db.gatherCollapsed then
        if #rows == 0 then
            n = 1
            local r = gatherRow(1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 4, -20); r:SetPoint("TOPRIGHT", -4, -20)
            r.item, r.target = nil, nil
            r.kind:SetTexture(nil); r.icon:SetTexture(nil)
            r.name:SetText("|cff808080No node data for this zone in the addon yet|r")
            r.best:SetText("")
            r:Show()
        end
        for _, g in ipairs(rows) do
            n = n + 1
            local r = gatherRow(n)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 4, -20 - (n - 1) * GROW_H)
            r:SetPoint("TOPRIGHT", -4, -20 - (n - 1) * GROW_H)
            r.item, r.target = g.item, g.best
            r.kind:SetTexture(SFP.KindIcon[g.kind])
            r.icon:SetTexture(SFP:ItemIcon(g.item))
            local count = g.here > 0 and (" |cff808080(" .. g.here .. ")|r") or ""
            r.name:SetText(SFP:ItemName(g.item) .. count)
            if g.best == mapID then
                r.best:SetText("|cff40ff40best zone: here|r")
                r.bestText = "This is the best zone for it" .. (g.bestN and (" - " .. g.bestN .. " recorded nodes") or "")
            elseif g.best then
                local zoneName = SFP:ZoneName(g.best)
                r.best:SetText("|cffaaaaaabest:|r |cffffd100" .. zoneName .. "|r")
                r.bestText = (g.here > 0 and (g.here .. " recorded nodes here. ") or "") ..
                    "Best zone: " .. zoneName .. (g.bestN and (" (" .. g.bestN .. " nodes)") or "")
            else
                r.best:SetText("|cffaaaaaaevery zone|r")
                r.bestText = "Spawns in every zone of this expansion"
            end
            if g.how then
                r.best:SetText("|cffffd100how to get it|r")
                r.bestText = g.how
            end
            r.name:SetPoint("RIGHT", r.best, "LEFT", -4, 0)
            r:Show()
        end
    end
    for i = n + 1, #gatherPanel.rows do gatherPanel.rows[i]:Hide() end
    gatherPanel:SetHeight(24 + n * GROW_H)
    gatherPanel:Show()
end

---------------------------------------------------------------------------
-- Whole-zone hover tooltip (only with the whole-zone glow option)
---------------------------------------------------------------------------
local lastSpot, lastScale, lastZoomed
local refresh -- forward

local function onUpdate(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.05 then return end
    self.t = 0
    if not WorldMapFrame:IsShown() then return end

    -- redraw when the map zooms in/out so spots switch between overview and areas
    local sc = WorldMapFrame.ScrollContainer
    local scale = (sc.GetCanvasScale and sc:GetCanvasScale()) or 1
    local zoomed = sc.IsZoomedIn and sc:IsZoomedIn() or false
    if lastScale and (math.abs(scale - lastScale) > 0.01 or zoomed ~= lastZoomed) then
        lastScale, lastZoomed = scale, zoomed
        refresh()
        return
    end
    lastScale, lastZoomed = scale, zoomed

    if not (SFP.db and SFP.db.mapOverlay) or not sc:IsMouseOver() then
        if lastSpot or lastHover then tip:Hide(); lastSpot, lastHover = nil, nil end
        return
    end

    -- nearest glowing spot under the cursor (frames don't take the mouse)
    local x, y = WorldMapFrame:GetNormalizedCursorPosition()
    if not x then return end
    local cw, ch = spawnLayer:GetWidth() * scale, spawnLayer:GetHeight() * scale
    local best, bestD = nil, 14 * 14 -- within ~14 screen pixels
    for _, h in ipairs(hoverList) do
        local dx, dy = (h.mx - x) * cw, (h.my - y) * ch
        local d = dx * dx + dy * dy
        if d < bestD then best, bestD = h, d end
    end
    if best then
        if best ~= lastSpot then lastSpot = best; lastHover = nil; showSpotTip(best) end
        return
    elseif lastSpot then
        tip:Hide(); lastSpot = nil
    end

    -- optional whole-zone hover tooltip
    if not SFP.db.zoneFill then return end
    local mapID = WorldMapFrame:GetMapID()
    local info = C_Map.GetMapInfoAtPosition(mapID, x, y)
    local zoneID = info and info.mapID
    if zoneID and zoneID ~= mapID and SFP:IsValuableZone(zoneID) then
        if zoneID ~= lastHover then
            lastHover = zoneID
            tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
            tip:ClearLines()
            tip:AddLine(SFP:ZoneName(zoneID), C().r, C().g, C().b)
            for _, id in ipairs(sortedItems(SFP.zoneByMap[zoneID].items)) do
                local info = SFP.Items[id]
                if not (info and (info.kind == "ore" or info.kind == "herb")) then tip:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":14|t " .. SFP:ItemName(id),
                    SFP:FormatPrice(SFP:GetPrice(id)), 1, 1, 1, 1, 1, 1) end
            end
            local boeText, boeWhere = SFP:RandomBoeText(zoneID)
            tip:AddDoubleLine(boeText, boeWhere, 1, 1, 1, 0.7, 0.7, 0.7)
            tip:Show()
        end
    elseif lastHover then
        tip:Hide(); lastHover = nil
    end
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
refresh = function()
    if not overlay or not SFP.db or not SFP.zoneByMap then return end
    releaseAll()
    clearSpawns()
    panel:Hide()
    if gatherPanel then gatherPanel:Hide() end
    for _, e in ipairs(edges) do e:Hide() end
    if WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() and SFP.QuestMarkers then
        SFP:Safe("quest zones", SFP.QuestMarkers.DrawZones, SFP.QuestMarkers, WorldMapFrame:GetMapID())
    end
    if not SFP.db.mapOverlay or not WorldMapFrame:IsShown() then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    if SFP.db.showDungeons or SFP.db.showRaids then drawInstances(mapID) end
    if SFP.db.showGatherList then
        local info = C_Map.GetMapInfo(mapID)
        local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
        if SFP.zoneByMap[mapID] or (info and info.mapType == zoneType) then drawGatherList(mapID) end
    end

    if SFP.zoneByMap[mapID] then
        -- inside a farm zone
        if SFP:IsValuableZone(mapID) then
            if SFP.db.showSpawns or SFP.db.showRares or SFP.db.showHunter or SFP.db.showSpecial then drawZoneSpawns(mapID) end
            if SFP.db.showMining or SFP.db.showHerbs then drawGatherSymbols(mapID) end
            if SFP.db.zoneFill then for _, e in ipairs(edges) do e:Show() end end
            if SFP.db.zonePanel then fillPanel(mapID); panel:Show() end
        end
    else
        -- continent / bigger map: small spots at the farm locations
        -- spots only on the zone maps (close view); the continent / world view stays clean
        if SFP.db.continentSpots then
            if SFP.db.showSpawns or SFP.db.showRares or SFP.db.showHunter or SFP.db.showSpecial then drawContinentSpots(mapID) end
            if SFP.db.showMining or SFP.db.showHerbs then drawGatherContinent(mapID) end
        end
        if SFP.db.zoneFill then
            for zoneID in pairs(SFP.zoneByMap) do
                if SFP:IsValuableZone(zoneID) and isUnder(zoneID, mapID) then drawZoneFill(mapID, zoneID) end
            end
        end
    end
end
SFP.RefreshWorldMap = refresh

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
SFP:OnLogin(function()
    local canvas = WorldMapFrame:GetCanvas()
    local c = C()

    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay:SetFrameLevel(canvas:GetFrameLevel() + 10)
    pool, labels = {}, {}

    spawnLayer = CreateFrame("Frame", nil, canvas)
    spawnLayer:SetAllPoints(canvas)
    -- high frame level: stay above other map addons' overlays
    spawnLayer:SetFrameLevel(math.min(canvas:GetFrameLevel() + 3000, 9000))
    -- gentle pulse so the spots read as glowing
    local sg = spawnLayer:CreateAnimationGroup()
    sg:SetLooping("BOUNCE")
    local sa = sg:CreateAnimation("Alpha")
    sa:SetFromAlpha(1); sa:SetToAlpha(0.6); sa:SetDuration(1.1); sa:SetSmoothing("IN_OUT")
    sg:Play()

    local sc = WorldMapFrame.ScrollContainer
    edges = {}
    local function edge(p1, p2, horiz)
        local t = sc:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(c.r, c.g, c.b, 0.8)
        t:SetPoint(p1); t:SetPoint(p2)
        if horiz then t:SetHeight(3) else t:SetWidth(3) end
        t:Hide()
        edges[#edges + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)

    panel = CreateFrame("Frame", "SeviathsUsefulToolsZonePanel", sc, "BackdropTemplate")
    panel:SetWidth(240)
    panel:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -10, -10)
    panel:SetFrameStrata("HIGH")
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    panel:SetBackdropColor(0, 0.05, 0.08, 0.85)
    panel:SetBackdropBorderColor(c.r, c.g, c.b, 0.9)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 8, -7)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() panel:Hide() end)
    panel:Hide()

    tip = CreateFrame("GameTooltip", "SeviathsUsefulToolsMapTip", UIParent, "GameTooltipTemplate")
    tip:SetFrameStrata("TOOLTIP")

    local watcher = CreateFrame("Frame", nil, WorldMapFrame)
    watcher:SetScript("OnUpdate", onUpdate)

    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", refresh) end
    WorldMapFrame:HookScript("OnShow", function() C_Timer.After(0, refresh) end)
    WorldMapFrame:HookScript("OnHide", function() if tip then tip:Hide() end; lastHover, lastSpot = nil, nil end)
    canvas:HookScript("OnSizeChanged", refresh)

    SFP:OnRefresh(refresh)
end)
