-- SeviathsUsefulTools - Core
-- Shared helpers, saved settings, price lookups, Wowhead links, slash commands.

local ADDON, SFP = ...
_G.SeviathsUsefulTools = SFP

-- Mists of Pandaria Classic: make sure the C_Item helpers exist whatever the client build
C_Item = C_Item or {}
C_Item.GetItemInfo = C_Item.GetItemInfo or GetItemInfo
C_Item.GetItemIconByID = C_Item.GetItemIconByID or GetItemIcon
C_Item.RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID or function(id) GetItemInfo(id) end

-- Merged modules (Codex, Dungeons & Raids, Guild Helper) each get their own private
-- table; ADDON is the Farm Pack's name so their ADDON_LOADED checks still match.
local modules = {}
function SFP_Module(name)
    modules[name] = modules[name] or {}
    return ADDON, modules[name]
end

-- Every internal error is kept (and shown once through the normal error handler, so BugSack
-- sees it): /sfp errors prints them.
SFP.errors = {}
local seenErr = {}
function SFP:CatchError(where, err)
    local msg = where .. ": " .. tostring(err)
    if seenErr[msg] then return end
    seenErr[msg] = true
    self.errors[#self.errors + 1] = msg
    local h = geterrorhandler and geterrorhandler()
    if h then h(msg) end
end
function SFP:Safe(where, fn, ...)
    local n, args = select("#", ...), { ... }
    local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, function(e)
        return tostring(e) .. (debugstack and ("\n" .. debugstack(2, 8, 0)) or "")
    end)
    if not ok then self:CatchError(where, err) end
    return ok
end

local function meta(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, field) or nil
end
SFP.NAME    = "SeviathsUsefulTools"
SFP.VERSION = meta("Version") or "dev"
SFP.AUTHOR  = meta("Author") or "Seviath"

SFP.CYAN = { r = 0.0, g = 0.9, b = 1.0 }
SFP.CYAN_HEX = "ff00e5ff"
SFP.WOWHEAD_ITEM = "https://www.wowhead.com/item=%d"

local defaults = {
    mapOverlay   = true,   -- cyan zones on the world map
    zonePanel    = false,  -- optional item panel when viewing a farm zone
    zoneFill     = false,  -- optional: light whole zones instead of just the farm spots
    showSpawns   = true,   -- cyan glowing monster spawn spots with coordinates
    showRares    = true,   -- orange glowing rare spawns (mounts, pets, toys)
    showHunter   = true,   -- green hunter tames (spirit beasts, unique-look pets)
    showMining   = true,   -- best zone for each ore (amber glow)
    showHerbs    = true,   -- best zone for each herb (mint glow)
    showDungeons = true,   -- dungeon entrance icons with their loot
    showRaids    = true,   -- raid entrance icons with their loot
    showLabels   = false,  -- name / coordinate text next to the markers (off: info only on hover)
    showSpecial  = true,   -- magenta spots for special materials (rare hides, lures, special cloth)
    showGatherList = true, -- side list on zone maps: the expansion's ores/herbs + their best zone
    showUnconfirmed = true, -- possible BoEs from guides that may have changed (listed separately)
    learn        = true,   -- remember where you loot farm materials / BoEs and show those spots
    continentSpots = false, -- spots on continent / world maps (off: only on zone maps)
    exactSpots   = true,   -- one exact marker per spawn point instead of merged areas
    minimapSpots = true,   -- farm spots / rares / nodes on the minimap too
    npcs         = {},     -- [npcID] = learned monster (Collector.lua)
    knownItems   = {},     -- [itemID] = learned item
    objects      = {},     -- [objectID] = learned gathering node
    recipes      = {},     -- ["Profession|Recipe"] = crafting recipe with its reagents
    learned      = {},     -- [uiMapID][npcID] = { name, kills, items = {[itemID]=count}, pts = {{x,y}} }
    mapMenu      = { open = false },
    minimap      = { hide = false, angle = 215 },
    minimapGlow  = true,   -- button pulses cyan inside a farm zone
    tooltip      = true,   -- add farm info + Wowhead link line to item tooltips
    minValue     = 0,      -- copper; only light zones whose best item is worth at least this
    rescanHours  = 12,     -- refresh AH prices when older than this
    prices       = {},     -- [itemID] = { p = copper per unit, t = time() }
    lastScan     = 0,
    browser      = { exp = 1, sortByValue = false },
}

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function SFP:Print(msg)
    print("|c" .. self.CYAN_HEX .. "SeviathsUsefulTools|r: " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Indexes built from the shipped data
---------------------------------------------------------------------------
function SFP:BuildIndex()
    self.zoneByMap   = {}   -- [uiMapID] = zone entry
    self.zoneExp     = {}   -- [uiMapID] = expansion entry
    self.itemSources = {}   -- [itemID] = { "Zone/Instance label", ... }
    self.trackedIDs  = {}   -- [itemID] = true (incl. crafting tiers)

    local function addSource(itemID, label)
        local list = self.itemSources[itemID]
        if not list then list = {}; self.itemSources[itemID] = list end
        for _, l in ipairs(list) do if l == label then return end end
        list[#list + 1] = label
    end

    local function track(itemID)
        self.trackedIDs[itemID] = true
        local info = self.Items[itemID]
        if info and info.tiers then
            for _, t in ipairs(info.tiers) do self.trackedIDs[t] = true end
        end
    end

    for _, exp in ipairs(self.Expansions) do
        for _, zone in ipairs(exp.zones) do
            self.zoneByMap[zone.map] = zone
            self.zoneExp[zone.map] = exp
            zone.instances = zone.instances or {}
            for _, id in ipairs(zone.items) do
                track(id)
                addSource(id, self:ZoneName(zone.map))
            end
        end
        for _, inst in ipairs(exp.instances or {}) do
            local zone = self.zoneByMap[inst.map]
            if not zone then -- instance in a zone with no other farm: list the zone anyway
                zone = { map = inst.map, items = {}, instances = {}, rareOnly = true }
                table.insert(exp.zones, zone)
                self.zoneByMap[inst.map] = zone
                self.zoneExp[inst.map] = exp
            end
            table.insert(zone.instances, inst)
            inst.exp = exp
            for _, id in ipairs(inst.items) do
                track(id)
                addSource(id, inst.name)
            end
        end
        for _, id in ipairs(exp.anywhere or {}) do
            track(id)
            addSource(id, exp.name .. " (any zone)")
        end
    end

    -- parse "x,y;x,y" spawn strings and find the busiest spot for the label
    local function parsePoints(sp)
        local pts = {}
        for x, y in sp.pts:gmatch("([%d%.]+),([%d%.]+)") do
            pts[#pts + 1] = { tonumber(x) / 100, tonumber(y) / 100 }
        end
        if #pts == 0 then return false end
        local best, bestN = pts[1], -1
        for _, a in ipairs(pts) do
            local n = 0
            for _, b in ipairs(pts) do
                local dx, dy = a[1] - b[1], a[2] - b[2]
                if dx * dx + dy * dy < 0.0016 then n = n + 1 end -- within 4 map units
            end
            if n > bestN then best, bestN = a, n end
        end
        sp.points, sp.hx, sp.hy = pts, best[1], best[2]
        return true
    end

    -- monster spawn points (Data/Spawns.lua): add their items to the zone
    for mapID, list in pairs(self.Spawns or {}) do
        local zone = self.zoneByMap[mapID]
        if zone and not zone.spawns then
            zone.spawns = {}
            for _, sp in ipairs(list) do
                if parsePoints(sp) then
                    for _, id in ipairs(sp.items) do
                        local info = self.Items[id]
                        if info and info.kind == "boe" then sp.grind = true end
                        if info and info.special then sp.special = true end
                    end
                    zone.spawns[#zone.spawns + 1] = sp
                    for _, id in ipairs(sp.items) do
                        local have = false
                        for _, z in ipairs(zone.items) do if z == id then have = true; break end end
                        if not have then table.insert(zone.items, id) end
                        track(id)
                        addSource(id, self:ZoneName(mapID))
                    end
                end
            end
        end
    end

    -- best farm spot per creature material = the mob with the most spawn points
    local bestN, bestSp = {}, {}
    for _, zone in pairs(self.zoneByMap) do
        for _, sp in ipairs(zone.spawns or {}) do
            for _, id in ipairs(sp.items) do
                if #sp.points > (bestN[id] or 0) then bestN[id], bestSp[id] = #sp.points, sp end
            end
        end
    end
    for id, sp in pairs(bestSp) do
        sp.bestFor = sp.bestFor or {}
        table.insert(sp.bestFor, id)
    end

    -- mining / herbalism (Data/Gathering.lua): one spot per ore/herb in its best zone
    local expByKey = {}
    for _, exp in ipairs(self.Expansions) do expByKey[exp.key] = exp end
    self.gatherByExp = {}
    for _, g in ipairs(self.Gather or {}) do
        local list = self.gatherByExp[g.exp]
        if not list then list = {}; self.gatherByExp[g.exp] = list end
        list[#list + 1] = g
        track(g.item)
    end
    for _, g in ipairs(self.Gather or {}) do
      if not g.listOnly then
        local zone = self.zoneByMap[g.map]
        local exp = expByKey[g.exp]
        if not zone and exp then
            zone = { map = g.map, items = {}, instances = {}, rareOnly = true }
            table.insert(exp.zones, zone)
            self.zoneByMap[g.map] = zone
            self.zoneExp[g.map] = exp
        end
        if zone and not g.done then
            g.done = true
            local sp = { name = g.name, items = { g.item }, pts = g.pts, gather = g.kind, nodes = g.nodes, bestFor = { g.item } }
            if parsePoints(sp) then
                zone.spawns = zone.spawns or {}
                zone.spawns[#zone.spawns + 1] = sp
                local have = false
                for _, z in ipairs(zone.items) do if z == g.item then have = true; break end end
                if not have then table.insert(zone.items, g.item) end
                track(g.item)
                addSource(g.item, self:ZoneName(g.map) .. " (best zone)")
            end
        end
      end
    end

    -- notable rares (Data/Rares.lua): shown as orange spots; zones that only
    -- have rares are added to their expansion so they light up too
    for mapID, list in pairs(self.Rares or {}) do
        local zone = self.zoneByMap[mapID]
        local exp = expByKey[list.exp]
        if not zone and exp then
            zone = { map = mapID, items = {}, instances = {}, rareOnly = true }
            table.insert(exp.zones, zone)
            self.zoneByMap[mapID] = zone
            self.zoneExp[mapID] = exp
        end
        if zone and not zone.rareDone then
            zone.rareDone = true
            zone.spawns = zone.spawns or {}
            for _, sp in ipairs(list) do
                if parsePoints(sp) then
                    -- hunter tames get their own symbol/colour instead of the rare look
                    sp.rare = not sp.hunter
                    -- worth grinding = drops something collectible or sellable
                    for _, id in ipairs(sp.items) do
                        local info = self.Items[id]
                        if info and (info.kind == "mount" or info.kind == "pet" or info.kind == "toy" or info.kind == "boe") then
                            sp.grind = true
                        end
                    end
                    zone.spawns[#zone.spawns + 1] = sp
                    for _, id in ipairs(sp.items) do addSource(id, sp.name) end
                end
            end
        end
    end
end

-- which expansion a map belongs to, for any zone (also ones with no farm data):
-- known zones first, then the continent it sits on. Cataclysm / TBC / Midnight
-- zones placed on the old continents are listed explicitly.
local CONTINENT_EXP = {
    [12] = "classic", [13] = "classic", [101] = "tbc", [113] = "wrath", [948] = "cata", [424] = "mop",
    -- newer continents, for when the game gets them:
    -- [572] = "wod", [619] = "legion", [905] = "legion", [875] = "bfa", [876] = "bfa", [1550] = "sl",
    -- [1978] = "df", [2274] = "tww",
}
local ZONE_EXP = {
    -- Cataclysm zones on the old continents
    [198] = "cata", [201] = "cata", [203] = "cata", [204] = "cata", [205] = "cata", [207] = "cata",
    [241] = "cata", [244] = "cata", [245] = "cata", [249] = "cata", [174] = "cata", [194] = "cata", [217] = "cata",
    -- Burning Crusade blood elf / draenei zones
    [94] = "tbc", [95] = "tbc", [97] = "tbc", [103] = "tbc", [106] = "tbc", [110] = "tbc", [122] = "tbc",
    -- Midnight (for when the game gets it)
    -- [2393] = "midnight", [2395] = "midnight", [2405] = "midnight", [2413] = "midnight", [2424] = "midnight", [2437] = "midnight",
}
function SFP:ExpansionForMap(mapID)
    if self.zoneExp and self.zoneExp[mapID] then return self.zoneExp[mapID] end
    local byKey = {}
    for _, exp in ipairs(self.Expansions) do byKey[exp.key] = exp end
    if ZONE_EXP[mapID] then return byKey[ZONE_EXP[mapID]] end
    -- maps added with Midnight (e.g. The Coiled Isle) sit under the old continents:
    -- every map ID from Midnight's range on belongs to Midnight
    -- (Midnight, for when the game gets it:)
    -- if mapID >= 2393 then return byKey.midnight end
    local m, guard = mapID, 0
    while m and guard < 6 do
        if CONTINENT_EXP[m] then return byKey[CONTINENT_EXP[m]] end
        local info = C_Map.GetMapInfo(m)
        m = info and info.parentMapID
        guard = guard + 1
    end
    return nil
end

function SFP:AddItemSource(itemID, label)
    local list = self.itemSources[itemID]
    if not list then list = {}; self.itemSources[itemID] = list end
    for _, l in ipairs(list) do if l == label then return end end
    list[#list + 1] = label
end

function SFP:ZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("Map " .. mapID)
end

-- Random green/blue BoE gear: any mob can drop it, so it is shown as one
-- general line per zone. Level range comes from the game (zones scale).
SFP.RANDOM_BOE_COLOR = "|cff1eff00"
function SFP:RandomBoeText(mapID)
    local text = "|cff1eff00Random green|r & |cff0070ddblue|r BoE gear"
    local lo, hi
    if C_Map.GetMapLevels then lo, hi = C_Map.GetMapLevels(mapID) end
    if lo and hi and hi > 0 then
        if lo == hi then return text, "any mob, lvl " .. lo end
        return text, "any mob, lvl " .. lo .. "-" .. hi
    end
    return text, "any mob in this zone"
end

---------------------------------------------------------------------------
-- Prices
---------------------------------------------------------------------------
-- Returns copper per unit (cheapest crafting tier for Dragonflight reagents)
function SFP:GetPrice(itemID)
    local best
    local function consider(id)
        local rec = self.db.prices[id]
        local p = rec and rec.p
        if not p and Auctionator and Auctionator.API and Auctionator.API.v1 then
            local ok, v = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON, id)
            if ok and type(v) == "number" then p = v end
        end
        if p and (not best or p < best) then best = p end
    end
    consider(itemID)
    local info = self.Items[itemID]
    if info and info.tiers then
        for _, t in ipairs(info.tiers) do consider(t) end
    end
    return best
end

function SFP:FormatPrice(copper)
    if not copper then return "|cff808080no AH data|r" end
    if GetMoneyString then return GetMoneyString(copper, true) end
    return string.format("%dg", math.floor(copper / 10000))
end

-- Best single-item value in a list of itemIDs
function SFP:ListValue(items)
    local best = 0
    for _, id in ipairs(items) do
        local p = self:GetPrice(id)
        if p and p > best then best = p end
    end
    return best
end

function SFP:ZoneValue(zone)
    local v = self:ListValue(zone.items)
    for _, inst in ipairs(zone.instances or {}) do
        v = math.max(v, self:ListValue(inst.items))
    end
    return v
end

-- A zone glows cyan if it is in the data and passes the value filter
function SFP:IsValuableZone(mapID)
    local zone = self.zoneByMap and self.zoneByMap[mapID]
    if not zone then return false end
    local minV = self.db.minValue or 0
    if minV <= 0 then return true end
    return self:ZoneValue(zone) >= minV
end

---------------------------------------------------------------------------
-- Item display helpers
---------------------------------------------------------------------------
function SFP:ItemName(itemID)
    local name, _, quality = C_Item.GetItemInfo(itemID)
    if not name then
        C_Item.RequestLoadItemDataByID(itemID)
        return "|cff808080item " .. itemID .. "|r", nil
    end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    local hex = color and color.hex or "|cffffffff"
    return hex .. name .. "|r", quality
end

function SFP:ItemIcon(itemID)
    return C_Item.GetItemIconByID(itemID) or 134400
end

function SFP:ItemExtra(itemID)
    local info = self.Items[itemID]
    if not info then return nil end
    local parts = {}
    local icon = self.KindIconTag and self:KindIconTag(info.kind, 12) or ""
    if icon ~= "" then parts[#parts + 1] = icon .. " |cff9d9d9d" .. (self.KindLabel[info.kind] or "") .. "|r" end
    if info.drop then parts[#parts + 1] = "|cffffd100drop " .. info.drop .. "|r" end
    if info.note then parts[#parts + 1] = "|cffaaaaaa" .. info.note .. "|r"
    elseif self.KindHow and self.KindHow[info.kind] then parts[#parts + 1] = "|cff808080" .. self.KindHow[info.kind] .. "|r" end
    if #parts == 0 then return nil end
    return table.concat(parts, "  ")
end

---------------------------------------------------------------------------
-- Waypoints
---------------------------------------------------------------------------
function SFP:SetWaypoint(mapID, x, y, label)
    if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID)) then
        self:Print("Can't place a waypoint on that map.")
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    self:Print(string.format("Waypoint set: %s %.1f, %.1f", label or self:ZoneName(mapID), x * 100, y * 100))
end

function SFP:OpenMapTo(mapID)
    if not WorldMapFrame:IsShown() then
        if ToggleWorldMap then ToggleWorldMap() else WorldMapFrame:Show() end
    end
    WorldMapFrame:SetMapID(mapID)
end

-- Instance entrances are read from the game's own Encounter Journal data,
-- so the coordinates are always the live ones.
function SFP:FindEntrance(inst)
    if inst._entrance ~= nil then return inst._entrance or nil end
    inst._entrance = false
    local function fromDatabase()
        local q = self.QuestieEntrance and (self:QuestieEntrance(inst.name) or (inst.alias and self:QuestieEntrance(inst.alias)))
        if q then inst._entrance = { map = q.map, x = q.x, y = q.y }; return inst._entrance end
        return nil
    end
    if not (C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then return fromDatabase() end
    local want = { [inst.name:lower()] = true }
    if inst.alias then want[inst.alias:lower()] = true end
    local maps = { inst.map }
    if inst.entranceMap then table.insert(maps, 1, inst.entranceMap) end
    for _, m in ipairs(maps) do
        local list = C_EncounterJournal.GetDungeonEntrancesForMap(m)
        for _, e in ipairs(list or {}) do
            if e.name and want[e.name:lower()] and e.position then
                local x, y = e.position:GetXY()
                inst._entrance = { map = m, x = x, y = y }
                return inst._entrance
            end
        end
    end
    return fromDatabase()
end

---------------------------------------------------------------------------
-- Wowhead link popup
---------------------------------------------------------------------------
StaticPopupDialogs["SEVIATHSUSEFULTOOLS_WOWHEAD"] = {
    text = "Wowhead link for %s\nPress Ctrl+C to copy:",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 320,
    OnShow = function(self, data)
        local eb = (self.GetEditBox and self:GetEditBox()) or self.editBox or self.EditBox
        if eb then
            eb:SetText(data or "")
            eb:SetFocus()
            eb:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(eb) eb:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function SFP:ShowWowhead(itemID)
    local name = C_Item.GetItemInfo(itemID) or ("item " .. itemID)
    StaticPopup_Show("SEVIATHSUSEFULTOOLS_WOWHEAD", name, nil, string.format(self.WOWHEAD_ITEM, itemID))
end

---------------------------------------------------------------------------
-- Item tooltip line
---------------------------------------------------------------------------
local function OnItemTooltip(tooltip, data)
    if not SFP.db or not SFP.db.tooltip then return end
    local itemID = data and data.id
    if not itemID or not SFP.trackedIDs or not SFP.trackedIDs[itemID] then return end
    local base = itemID
    if not SFP.itemSources[itemID] then
        for id, info in pairs(SFP.Items) do
            if info.tiers then
                for _, t in ipairs(info.tiers) do if t == itemID then base = id end end
            end
        end
    end
    local sources = SFP.itemSources[base]
    tooltip:AddLine(" ")
    tooltip:AddLine("|c" .. SFP.CYAN_HEX .. "SeviathsUsefulTools|r")
    if sources then
        local shown = {}
        for i = 1, math.min(4, #sources) do shown[i] = sources[i] end
        local more = #sources > 4 and (" +" .. (#sources - 4) .. " more") or ""
        tooltip:AddLine("Farm: " .. table.concat(shown, ", ") .. more, 0.8, 0.8, 0.8, true)
    end
    local rec = SFP.db.prices[itemID]
    if rec and rec.p then
        tooltip:AddDoubleLine("AH (unit):", SFP:FormatPrice(rec.p), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    local extra = SFP:ItemExtra(base)
    if extra then tooltip:AddLine(extra, 1, 1, 1, true) end
    tooltip:AddLine("wowhead.com/item=" .. itemID, 0.5, 0.5, 0.5)
end

---------------------------------------------------------------------------
-- Current zone (for the minimap signal)
---------------------------------------------------------------------------
function SFP:PlayerFarmZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and guard < 6 do
        if self.zoneByMap[mapID] then return mapID end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        guard = guard + 1
    end
    return nil
end

---------------------------------------------------------------------------
-- Refresh hub: anything showing prices or cyan zones re-reads here
---------------------------------------------------------------------------
SFP.listeners = {}
function SFP:OnRefresh(fn) table.insert(self.listeners, fn) end
function SFP:RefreshAll()
    for i, fn in ipairs(self.listeners) do self:Safe("refresh #" .. i, fn) end
end

---------------------------------------------------------------------------
-- Events & slash commands
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
SFP.events = events
pcall(events.RegisterEvent, events, "ADDON_LOADED")
pcall(events.RegisterEvent, events, "PLAYER_LOGIN")
pcall(events.RegisterEvent, events, "ZONE_CHANGED_NEW_AREA")
pcall(events.RegisterEvent, events, "GET_ITEM_INFO_RECEIVED")

local itemInfoPending = false
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        SeviathsUsefulToolsDB = SeviathsUsefulToolsDB or {}
        copyDefaults(defaults, SeviathsUsefulToolsDB)
        SFP.db = SeviathsUsefulToolsDB
        -- 1.3: the map now shows small farm spots; panel + whole-zone glow become opt-in
        if (SFP.db.schema or 1) < 2 then
            SFP.db.zonePanel = false
            SFP.db.zoneFill = false
            SFP.db.showSpawns = true
            SFP.db.schema = 2
        end
        -- 1.11: map text only on hover - labels off for everyone once
        if (SFP.db.schema or 2) < 3 then
            SFP.db.showLabels = false
            SFP.db.schema = 3
        end
        -- 1.7 combined toggles were split in 1.8
        if SFP.db.showGather == false then SFP.db.showMining, SFP.db.showHerbs = false, false end
        if SFP.db.showInstances == false then SFP.db.showDungeons, SFP.db.showRaids = false, false end
        SFP.db.showGather, SFP.db.showInstances = nil, nil
    elseif event == "PLAYER_LOGIN" then
        SFP:Safe("BuildIndex", SFP.BuildIndex, SFP)
        if TooltipDataProcessor and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
        end
        for i, fn in ipairs(SFP.loginHandlers or {}) do SFP:Safe("login #" .. i, fn) end
        SFP:RefreshAll()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        SFP:RefreshAll()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- names/icons arrive async; batch one refresh
        if not itemInfoPending then
            itemInfoPending = true
            C_Timer.After(0.5, function() itemInfoPending = false; SFP:RefreshAll() end)
        end
    end
end)

function SFP:OnLogin(fn)
    self.loginHandlers = self.loginHandlers or {}
    table.insert(self.loginHandlers, fn)
end

SLASH_SEVIATHSUSEFULTOOLS1 = "/sfp"
SLASH_SEVIATHSUSEFULTOOLS2 = "/farmpack"
SLASH_SEVIATHSUSEFULTOOLS3 = "/sut"
SlashCmdList["SEVIATHSUSEFULTOOLS"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.*)$")
    if cmd == "" or cmd == "show" then
        if SFP.ToggleMenu then SFP:ToggleMenu() else SFP:ToggleBrowser() end
    elseif cmd == "browser" or cmd == "farm" then
        SFP:ToggleBrowser()
    elseif cmd == "version" or cmd == "about" then
        SFP:Print("version " .. SFP.VERSION .. " by " .. SFP.AUTHOR .. " - Classic to Mists of Pandaria, data from wowhead.com")
        if SFP.OpenAbout then SFP:OpenAbout() end
    elseif cmd == "map" then
        SFP.db.mapOverlay = not SFP.db.mapOverlay
        SFP:Print("World map overlay " .. (SFP.db.mapOverlay and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "spawns" then
        SFP.db.showSpawns = not SFP.db.showSpawns
        SFP:Print("Monster spawn glows " .. (SFP.db.showSpawns and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "rares" then
        SFP.db.showRares = not SFP.db.showRares
        SFP:Print("Rare spots " .. (SFP.db.showRares and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "hunter" then
        SFP.db.showHunter = not SFP.db.showHunter
        SFP:Print("Hunter tame spots " .. (SFP.db.showHunter and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "gather" then
        local on = not (SFP.db.showMining or SFP.db.showHerbs)
        SFP.db.showMining, SFP.db.showHerbs = on, on
        SFP:Print("Mining & herbalism spots " .. (on and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "dungeons" then
        local on = not (SFP.db.showDungeons or SFP.db.showRaids)
        SFP.db.showDungeons, SFP.db.showRaids = on, on
        SFP:Print("Dungeon/raid icons " .. (on and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "mapbutton" then
        SFP.db.mapMenu.hide = not SFP.db.mapMenu.hide
        SFP:Print("World map layer button " .. (SFP.db.mapMenu.hide and "hidden" or "shown"))
        SFP:RefreshAll()
    elseif cmd == "learn" then
        local arg = (rest or ""):lower()
        if arg == "reset" then
            SFP:ResetLearned()
            SFP:Print("Learned farm spots cleared.")
        else
            SFP.db.learn = not SFP.db.learn
            SFP:Print("Learning farm spots from your loot " .. (SFP.db.learn and "ON" or "OFF"))
        end
    elseif cmd == "loot" then
        SFP:Print("Re-reading dungeon and raid loot from the Adventure Guide...")
        SFP:ScanInstanceLoot(true)
    elseif cmd == "minimap" then
        SFP.db.minimap.hide = not SFP.db.minimap.hide
        SFP:Print("Minimap button " .. (SFP.db.minimap.hide and "hidden" or "shown"))
        SFP:RefreshAll()
    elseif cmd == "scan" then
        SFP:StartScan(true)
    elseif cmd == "min" then
        local g = tonumber(rest)
        if g then
            SFP.db.minValue = math.floor(g * 10000)
            SFP:Print("Zones light up when their best item is worth at least " .. SFP:FormatPrice(SFP.db.minValue))
            SFP:RefreshAll()
        else
            SFP:Print("Usage: /sfp min <gold>   (0 = light every farm zone)")
        end
    elseif cmd == "scanitems" then
        if SFP.ScanProgress then
            local pct, mats = SFP:ScanProgress()
            SFP:Print(("Item scan: %d%% of the item IDs asked, %d crafting materials known."):format(pct, mats))
        end
    elseif cmd == "questie" then
        if SFP.QuestieOwnIcons then SFP:QuestieOwnIcons() end
    elseif cmd == "tipdebug" then
        SFP.tipDebug = not SFP.tipDebug
        SFP:Print("Tooltip debug " .. (SFP.tipDebug and "ON - hover a monster" or "OFF"))
    elseif cmd == "menu" then
        if SFP.ToggleMenu then SFP:ToggleMenu() end
    elseif cmd == "errors" then
        if #SFP.errors == 0 then SFP:Print("No internal errors recorded.") end
        for i, e in ipairs(SFP.errors) do SFP:Print(i .. ": " .. e) end
    elseif cmd == "know" then
        if SFP.ToggleMenu then SFP:ToggleMenu("know") end
    elseif cmd == "codex" then
        SFP:RunModule("SEVIATHSCODEX", rest)
    elseif cmd == "groups" or cmd == "sdr" then
        SFP:RunModule("SEVIATHSDUNGEONSRAIDS", rest)
    elseif cmd == "guild" or cmd == "gi" then
        SFP:RunModule("SEVIATHSGUILDHELPER", rest)
    elseif cmd == "tooltip" then
        SFP.db.tooltip = not SFP.db.tooltip
        SFP:Print("Item tooltip lines " .. (SFP.db.tooltip and "ON" or "OFF"))
    else
        SFP:Print("version " .. SFP.VERSION)
        SFP:Print("/sfp - open the farm browser")
        SFP:Print("/sfp version - version info + options page")
        SFP:Print("/sfp map - toggle the cyan world map overlay")
        SFP:Print("/sfp spawns - toggle the glowing monster spawn spots")
        SFP:Print("/sfp rares - toggle the orange rare spots")
        SFP:Print("/sfp hunter - toggle the green hunter tame spots")
        SFP:Print("/sfp gather - toggle mining & herbalism best-zone spots")
        SFP:Print("/sfp dungeons - toggle dungeon/raid entrance icons")
        SFP:Print("/sfp mapbutton - show/hide the layer button on the world map")
        SFP:Print("/sfp loot - re-read dungeon/raid mounts and BoEs from the Adventure Guide")
        SFP:Print("/sfp learn - learning farm spots from your loot on/off (/sfp learn reset clears them)")
        SFP:Print("/sfp minimap - show/hide the minimap button")
        SFP:Print("/sfp scan - rescan AH prices (auction house must be open)")
        SFP:Print("/sfp min <gold> - only light zones worth at least this much")
        SFP:Print("/sfp tooltip - toggle the item tooltip lines")
        SFP:Print("/sfp questie - make Questie draw quests on the map and minimap")
        SFP:Print("/sfp menu - the main menu with everything")
        SFP:Print("/sfp know - everything the addon has learned (monsters, items, recipes)")
        SFP:Print("/sfp errors - show internal errors")
        SFP:Print("/sfp codex [search] - encyclopedia (also /codex)")
        SFP:Print("/sfp groups - Dungeons & Raids group tools (also /sdr)")
        SFP:Print("/sfp guild - Guild Helper (also /gi)")
    end
end
