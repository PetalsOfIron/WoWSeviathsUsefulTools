-- SeviathsUsefulTools - farm spots learned from your own loot
--
-- Every time you loot a creature, items the addon cares about (cloth, leather,
-- elements, meat, special materials and any Bind on Equip gear) are recorded
-- together with the mob and where you stood. After a few kills of the same
-- mob in a zone it becomes a farm spot on the map, with drop rates measured
-- from your own kills. Saved per account in SeviathsUsefulToolsDB.learned.

local _, SFP = ...

local MIN_KILLS   = 3     -- kills of a mob before its spot is shown
local MAX_POINTS  = 40    -- positions kept per mob per zone
local NEAR        = 0.012 -- positions closer than this (map units) count as the same spot
local WANT_KINDS  = { cloth = true, leather = true, element = true, meat = true, boe = true, ore = true, herb = true, enchant = true, mat = true }
local BIND_ON_EQUIP = (Enum and Enum.ItemBind and Enum.ItemBind.OnEquip) or 2

local function npcFromGUID(guid)
    if not guid then return end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then return tonumber(npcID) end
    if unitType == "GameObject" and tonumber(npcID) then return "o" .. npcID end -- herb / ore nodes
end

local function wanted(itemID)
    if SFP.RecordItem then SFP.RecordItem(itemID) end
    if SFP.ClassifyItem then SFP:ClassifyItem(itemID) end
    local info = SFP.Items[itemID]
    if info and (WANT_KINDS[info.kind] or info.special or info.learned) and not info.unconfirmed then return true end
    local _, _, quality, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(itemID)
    if bindType == BIND_ON_EQUIP and (quality or 0) >= 2 then
        SFP.Items[itemID] = SFP.Items[itemID] or { kind = "boe", note = "Bind on Equip - seen in your own loot" }
        return true
    end
end

local function playerPos()
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not x or x <= 0 or y <= 0 then return end
    return map, x, y
end

---------------------------------------------------------------------------
-- turn learned records into map spots
---------------------------------------------------------------------------
local function spotFor(map, npcID, rec)
    local zone = SFP.zoneByMap[map]
    if not zone then
        local exp = SFP:ExpansionForMap(map)
        if not exp then return end
        zone = { map = map, items = {}, instances = {}, rareOnly = true }
        table.insert(exp.zones, zone)
        SFP.zoneByMap[map] = zone
        SFP.zoneExp[map] = exp
    end
    zone.spawns = zone.spawns or {}
    rec.sp = rec.sp or nil
    for _, s in ipairs(zone.spawns) do
        if s.learnedNpc == npcID then return s, zone end
    end
    local s = { name = rec.name or ("NPC " .. npcID), learned = true, learnedNpc = npcID, items = {}, points = {} }
    table.insert(zone.spawns, s)
    return s, zone
end

local function updateSpot(map, npcID, rec)
    if (rec.kills or 0) < MIN_KILLS then return end
    local s, zone = spotFor(map, npcID, rec)
    if not s then return end
    s.name = rec.name or s.name
    s.kills = rec.kills
    s.counts = rec.items
    wipe(s.items)
    s.special, s.grind = nil, nil
    for id in pairs(rec.items) do
        table.insert(s.items, id)
        local info = SFP.Items[id]
        if info and info.special then s.special = true end
        if info and info.kind == "boe" then s.grind = true end
        SFP.trackedIDs[id] = true
    end
    wipe(s.points)
    local sx, sy = 0, 0
    for _, p in ipairs(rec.pts) do
        s.points[#s.points + 1] = { p[1], p[2] }
        sx, sy = sx + p[1], sy + p[2]
    end
    s.hx, s.hy = sx / #rec.pts, sy / #rec.pts
    zone._areas = nil -- marker cache
end

function SFP:ApplyLearned()
    for map, mobs in pairs(self.db.learned or {}) do
        for npcID, rec in pairs(mobs) do updateSpot(map, npcID, rec) end
    end
end

---------------------------------------------------------------------------
-- recording
---------------------------------------------------------------------------
local function onLoot()
    if not SFP.db or SFP.db.learn == false then return end
    if IsInInstance and IsInInstance() then return end -- world farm spots only
    local map, x, y = playerPos()
    if not map then return end
    local seenMob = {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        local sources = { GetLootSourceInfo(slot) }
        for i = 1, #sources, 2 do
            local npcID = npcFromGUID(sources[i])
            if npcID then
                SFP.db.learned = SFP.db.learned or {}
                SFP.db.learned[map] = SFP.db.learned[map] or {}
                local rec = SFP.db.learned[map][npcID]
                if not rec then
                    rec = { kills = 0, items = {}, pts = {} }
                    SFP.db.learned[map][npcID] = rec
                end
                if UnitGUID("target") == sources[i] then rec.name = UnitName("target") end
                if not rec.name and type(npcID) == "string" and SFP.RecentCastTarget then rec.name = SFP:RecentCastTarget() end
                if not seenMob[sources[i]] then
                    seenMob[sources[i]] = true
                    rec.kills = rec.kills + 1
                    local near = false
                    for _, p in ipairs(rec.pts) do
                        if math.abs(p[1] - x) < NEAR and math.abs(p[2] - y) < NEAR then near = true; break end
                    end
                    if not near and #rec.pts < MAX_POINTS then rec.pts[#rec.pts + 1] = { x, y } end
                end
                if itemID and wanted(itemID) then
                    rec.items[itemID] = (rec.items[itemID] or 0) + 1
                end
            end
        end
    end
    -- forget mobs that never dropped anything worth farming after many kills
    for npcID, rec in pairs(SFP.db.learned and SFP.db.learned[map] or {}) do
        if rec.kills >= 25 and next(rec.items) == nil then SFP.db.learned[map][npcID] = nil end
    end
    for npcID, rec in pairs(SFP.db.learned and SFP.db.learned[map] or {}) do
        if next(rec.items) then updateSpot(map, npcID, rec) end
    end
end

local f = CreateFrame("Frame")
pcall(f.RegisterEvent, f, "LOOT_READY")
f:SetScript("OnEvent", function()
    local ok = pcall(onLoot)
    if ok and WorldMapFrame and WorldMapFrame:IsShown() then SFP:RefreshAll() end
end)

SFP:OnLogin(function()
    SFP:ApplyLearned()
end)

function SFP:ResetLearned()
    self.db.learned = {}
    for _, zone in pairs(self.zoneByMap) do
        if zone.spawns then
            for i = #zone.spawns, 1, -1 do
                if zone.spawns[i].learned then table.remove(zone.spawns, i) end
            end
            zone._areas = nil
        end
    end
    self:RefreshAll()
end
