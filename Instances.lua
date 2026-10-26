-- SeviathsUsefulTools - every dungeon and raid, from the game's Adventure Guide
--
-- A little after login (once per game patch) the addon walks the whole
-- Encounter Journal - every expansion, every dungeon and raid - and keeps:
--   * mounts (any item that teaches a mount), on every difficulty
--   * gear and other items that Bind on Equip (uncommon or better) - sellable
-- Entrances are found through the game's own dungeon-entrance map data.
-- Instances with nothing worth farming are not shown. Hand-checked mounts
-- and drop chances from Data/Expansions.lua are kept and merged in.
-- Trash-only BoEs are not in the Adventure Guide and are not covered here.

local _, SFP = ...

local BIND_ON_EQUIP = (Enum and Enum.ItemBind and Enum.ItemBind.OnEquip) or 2
local CACHE_VERSION = 3
local DIFFS = { 1, 2, 23, 3, 4, 5, 6, 14, 15, 16, 17, 9 }
local scanning = false

---------------------------------------------------------------------------
-- merge journal instances into the addon's data
---------------------------------------------------------------------------
local function findStatic(exp, name)
    local lname = name:lower()
    for _, inst in ipairs(exp.instances or {}) do
        if inst.name:lower() == lname then return inst end
    end
end

local function ensureZone(exp, map)
    local zone = SFP.zoneByMap[map]
    if not zone then
        zone = { map = map, items = {}, instances = {}, rareOnly = true }
        table.insert(exp.zones, zone)
        SFP.zoneByMap[map] = zone
        SFP.zoneExp[map] = exp
    end
    zone.instances = zone.instances or {}
    return zone
end

local function addItem(inst, id, kind, boss)
    SFP.Items[id] = SFP.Items[id] or {
        kind = kind,
        note = (kind == "boe" and "Bind on Equip - " or "") .. (boss and (boss .. ", ") or "") .. inst.name,
        fromJournal = true,
    }
    for _, have in ipairs(inst.items) do if have == id then return end end
    table.insert(inst.items, id)
    SFP.trackedIDs[id] = true
    SFP:AddItemSource(id, inst.name)
end

local function applyCache()
    local cache = SFP.db.ejCache
    if not cache or cache.v ~= CACHE_VERSION or not cache.list then return end
    for _, rec in ipairs(cache.list) do
        local exp = SFP.Expansions[rec.exp]
        if exp then
            local inst = findStatic(exp, rec.name)
            if not inst and #rec.items > 0 and rec.map then
                inst = { name = rec.name, map = rec.map, kind = rec.raid and "raid" or "dungeon", items = {}, fromJournal = true }
                exp.instances = exp.instances or {}
                table.insert(exp.instances, inst)
                table.insert(ensureZone(exp, rec.map).instances, inst)
                inst.exp = exp
            end
            if inst then
                if rec.map and rec.x and not inst._entrance then
                    inst._entrance = { map = rec.map, x = rec.x, y = rec.y }
                end
                for _, e in ipairs(rec.items) do addItem(inst, e[1], e[2], e[3]) end
            end
        end
    end
end

---------------------------------------------------------------------------
-- reading the journal
---------------------------------------------------------------------------
-- journalInstanceID -> entrance { map, x, y } from every zone map's entrance pins
local function entranceIndex()
    local idx = {}
    if not (C_Map.GetMapChildrenInfo and C_EncounterJournal.GetDungeonEntrancesForMap) then return idx end
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    local maps = C_Map.GetMapChildrenInfo(946, zoneType, true) or {} -- 946 = whole world
    for _, m in ipairs(maps) do
        local list = C_EncounterJournal.GetDungeonEntrancesForMap(m.mapID)
        for _, e in ipairs(list or {}) do
            if e.journalInstanceID and e.position and not idx[e.journalInstanceID] then
                local x, y = e.position:GetXY()
                idx[e.journalInstanceID] = { map = m.mapID, x = x, y = y }
            end
        end
    end
    return idx
end

-- every journal instance: { jid, name, exp (index), raid }
local function journalInstances()
    local list, seen = {}, {}
    local expByName = {}
    for i, exp in ipairs(SFP.Expansions) do expByName[exp.name:lower()] = i end
    for tier = 1, EJ_GetNumTiers() do
        EJ_SelectTier(tier)
        local tierName = EJ_GetTierInfo and EJ_GetTierInfo(tier)
        local expIndex = (tierName and expByName[tierName:lower()]) or (tier <= #SFP.Expansions and tier or nil)
        if expIndex then
            for _, isRaid in ipairs({ false, true }) do
                local i = 1
                while true do
                    local id, name = EJ_GetInstanceByIndex(i, isRaid)
                    if not id then break end
                    if not seen[id] then
                        seen[id] = true
                        list[#list + 1] = { jid = id, name = name, exp = expIndex, raid = isRaid }
                    end
                    i = i + 1
                end
            end
        end
    end
    return list
end

-- read one instance's loot on every valid difficulty; true when complete
local function readInstance(q)
    EJ_SelectInstance(q.jid)
    local diffs = {}
    if EJ_IsValidInstanceDifficulty and EJ_SetDifficulty then
        for _, d in ipairs(DIFFS) do if EJ_IsValidInstanceDifficulty(d) then diffs[#diffs + 1] = d end end
    end
    if #diffs == 0 then diffs = { false } end
    local complete, total = true, 0
    for _, d in ipairs(diffs) do
        if d then EJ_SetDifficulty(d) end
        if EJ_ResetLootFilter then EJ_ResetLootFilter() elseif EJ_SetLootFilter then EJ_SetLootFilter(0, 0) end
        if C_EncounterJournal.ResetSlotFilter then C_EncounterJournal.ResetSlotFilter() end
        local n = EJ_GetNumLoot and EJ_GetNumLoot() or 0
        total = total + n
        for i = 1, n do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            local id = info and info.itemID
            if id and not q.seen[id] then
                local boss = info.encounterID and EJ_GetEncounterInfo and EJ_GetEncounterInfo(info.encounterID) or nil
                if C_MountJournal and C_MountJournal.GetMountFromItem and C_MountJournal.GetMountFromItem(id) then
                    q.seen[id] = true
                    q.items[#q.items + 1] = { id, "mount", boss }
                else
                    local name, _, quality, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(id)
                    if not name then
                        complete = false
                        C_Item.RequestLoadItemDataByID(id)
                    else
                        q.seen[id] = true
                        if bindType == BIND_ON_EQUIP and (quality or 0) >= 2 then q.items[#q.items + 1] = { id, "boe", boss } end
                    end
                end
            elseif not id then
                complete = false
            end
        end
    end
    return complete and total > 0
end

function SFP:ScanInstanceLoot(force)
    if scanning or not (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex and EJ_SelectInstance and EJ_GetNumTiers) then return end
    local build = select(2, GetBuildInfo())
    local c = self.db.ejCache
    if not force and c and c.build == build and c.done and c.v == CACHE_VERSION then return end
    if C_AddOns and C_AddOns.LoadAddOn and not (C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal")) then
        pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    end
    -- don't fight the player for the Adventure Guide
    if EncounterJournal and EncounterJournal:IsShown() then
        C_Timer.After(30, function() SFP:ScanInstanceLoot(force) end)
        return
    end
    scanning = true
    local entrances = entranceIndex()
    local queue = journalInstances()
    for _, q in ipairs(queue) do q.items, q.seen, q.tries = {}, {}, 0 end
    if force then self:Print("Reading " .. #queue .. " dungeons and raids from the Adventure Guide...") end

    local i = 0
    local function nextOne()
        if EncounterJournal and EncounterJournal:IsShown() then
            C_Timer.After(10, nextOne) -- pause while the player has the guide open
            return
        end
        i = i + 1
        local q = queue[i]
        if not q then
            local list = {}
            for _, r in ipairs(queue) do
                local e = entrances[r.jid]
                list[#list + 1] = { name = r.name, exp = r.exp, raid = r.raid, items = r.items,
                                    map = e and e.map, x = e and e.x, y = e and e.y }
            end
            SFP.db.ejCache = { v = CACHE_VERSION, build = build, done = true, list = list }
            scanning = false
            applyCache()
            SFP:RefreshAll()
            if force then SFP:Print("Dungeon and raid loot updated.") end
            return
        end
        local ok = readInstance(q)
        if not ok and q.tries < 6 then
            q.tries = q.tries + 1 -- item data still loading from the server
            i = i - 1
            C_Timer.After(1, nextOne)
            return
        end
        C_Timer.After(0.15, nextOne)
    end
    nextOne()
end

SFP:OnLogin(function()
    applyCache()
    -- pcall: a client without the full Adventure Guide API must not throw errors at login
    C_Timer.After(8, function() pcall(SFP.ScanInstanceLoot, SFP, false) end)
end)
