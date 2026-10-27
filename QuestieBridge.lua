-- SeviathsUsefulTools - Questie database bridge
--
-- If the QuestieDB addon is installed (Questie needs it), its Mists of Pandaria database feeds the
-- guide: every quest (objectives, where to start, where to kill / collect, turn in, chain), every
-- elite / rare / boss monster (level, zone, spot, quest items they drop) and which monsters, nodes
-- and vendors give an item. Nothing is copied into the saved variables: it is read on demand.
-- Questie itself keeps drawing quests on the minimap and map; this only adds guide pages.

local ADDON, SFP = ...

local function dbs() return _G.QuestDB, _G.NpcDB, _G.ItemDB, _G.ObjectDB end
function SFP:HasQuestieDB() return _G.NpcDB ~= nil and _G.QuestDB ~= nil end

local function safe(fn, ...)
    if not fn then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

---------------------------------------------------------------------------
-- names and places
---------------------------------------------------------------------------
local areaCache, areaRev = {}, nil
local function areaName(id)
    if not id then return nil end
    if id < 0 then return "Profession / class / special quests" end
    local c = areaCache[id]
    if c then return c end
    local n
    if C_Map and C_Map.GetAreaInfo then n = safe(C_Map.GetAreaInfo, id) end
    if not n and _G.LibQuestieDB and LibQuestieDB.Enum and LibQuestieDB.Enum.zoneIDs then
        if not areaRev then
            areaRev = {}
            for name, zid in pairs(LibQuestieDB.Enum.zoneIDs) do areaRev[zid] = (name:gsub("_", " "):gsub("(%a)(%u)", "%1 %2")) end
        end
        n = areaRev[id]
    end
    n = n or ("Zone " .. id)
    areaCache[id] = n
    return n
end

SFP.AreaName = areaName

local function npcName(id)
    local _, N = dbs()
    return N and safe(N.name, id) or ("NPC " .. id)
end

local zoneDBCache
local function getZoneDB()
    if zoneDBCache ~= nil then return zoneDBCache or nil end
    local loader = _G.QuestieLoader
    zoneDBCache = (loader and loader.ImportModule and safe(function() return loader:ImportModule("ZoneDB") end)) or false
    return zoneDBCache or nil
end

SFP.GetZoneDB = getZoneDB

-- { m = uiMapID, x, y } (0-1) of the first spawn, for "Show on map"
local function uiSpot(spawns)
    local Z = getZoneDB()
    if not (Z and Z.GetUiMapIdByAreaId and type(spawns) == "table") then return nil end
    for area, coords in pairs(spawns) do
        local c = type(coords) == "table" and coords[1]
        if c and c[1] and c[1] > 0 then
            local m = safe(function() return Z:GetUiMapIdByAreaId(area) end)
            if m then return { m = m, x = c[1] / 100, y = c[2] / 100 } end
        end
    end
end

-- { m, x, y } of an npc, preferring the given area
function SFP:NpcPin(npcID, areaID)
    local _, N = dbs()
    local sp = N and npcID and safe(N.spawns, npcID)
    if type(sp) ~= "table" then return nil end
    return uiSpot((areaID and sp[areaID]) and { [areaID] = sp[areaID] } or sp)
end

function SFP:QuestPin(questID)
    local Q = dbs()
    local sb = Q and safe(Q.startedBy, questID)
    local npc = sb and sb[1] and sb[1][1]
    return npc and self:NpcPin(npc) or nil
end

local function firstSpot(spawns)
    if type(spawns) ~= "table" then return nil end
    for area, coords in pairs(spawns) do
        if type(coords) == "table" and coords[1] and coords[1][1] then
            return area, coords[1][1], coords[1][2]
        end
    end
end

local function placeText(spawns)
    local area, x, y = firstSpot(spawns)
    if not area then return "" end
    if x and x > 0 then return (" |cff9aa0a6(%s %.0f, %.0f)|r"):format(areaName(area) or "?", x, y) end
    return " |cff9aa0a6(" .. (areaName(area) or "?") .. ")|r"
end

local function npcLine(id)
    local _, N = dbs()
    return npcName(id) .. (N and placeText(safe(N.spawns, id)) or "")
end

local function objectLine(id)
    local _, _, _, O = dbs()
    local name = O and safe(O.name, id) or ("Object " .. id)
    return name .. (O and placeText(safe(O.spawns, id)) or "")
end

local function itemNameOf(id)
    local _, _, I = dbs()
    local n = I and safe(I.name, id)
    if n then return n end
    return (C_Item.GetItemInfo(id)) or ("item " .. id)
end

local function joinNames(list, fn, limit)
    local out = {}
    for i = 1, math.min(limit, #list) do out[#out + 1] = fn(list[i]) end
    if #list > limit then out[#out + 1] = "+" .. (#list - limit) .. " more" end
    return table.concat(out, ", ")
end

---------------------------------------------------------------------------
-- who drops / sells an item (live from the database)
---------------------------------------------------------------------------
function SFP:QuestieItemSources(itemID)
    local _, N, I, O = dbs()
    if not I then return nil end
    local out = {}
    local npcs = safe(I.npcDrops, itemID)
    if npcs and #npcs > 0 then out[#out + 1] = "Dropped by: " .. joinNames(npcs, npcName, 4) end
    local objs = safe(I.objectDrops, itemID)
    if objs and #objs > 0 then out[#out + 1] = "Found in: " .. joinNames(objs, function(id) return O and safe(O.name, id) or ("object " .. id) end, 3) end
    local vend = safe(I.vendors, itemID)
    if vend and #vend > 0 then out[#out + 1] = "Sold by: " .. joinNames(vend, npcName, 3) end
    return #out > 0 and out or nil
end

-- npc -> items it drops, built in the background from the item side (the database only
-- stores item -> npc)
local qdrops, qdropsState = nil, nil
function SFP:QuestieDropsOf(npcID)
    return qdrops and qdrops[npcID]
end

local function startDropIndex()
    local _, N, I = dbs()
    if qdropsState or not I or not I.GetAllIds then return end
    qdropsState = "running"
    local ids = safe(I.GetAllIds)
    if not ids then qdropsState = "failed"; return end
    qdrops = {}
    local i, total = 0, #ids
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        if InCombatLockdown() then return end
        for _ = 1, 250 do
            i = i + 1
            if i > total then self:Hide(); qdropsState = "done"; return end
            local itemID = ids[i]
            local npcs = safe(I.npcDrops, itemID)
            if npcs then
                for _, npc in ipairs(npcs) do
                    local l = qdrops[npc]
                    if not l then l = {}; qdrops[npc] = l end
                    if #l < 12 then l[#l + 1] = itemID end
                end
            end
        end
    end)
end

---------------------------------------------------------------------------
-- Codex pages
---------------------------------------------------------------------------
local CYAN = "|cff33e6ff"
local RANK = { [1] = "Elite", [2] = "Rare elite", [3] = "Boss", [4] = "Rare" }

local function questBody(e)
    local Q, N, I, O = dbs()
    local id = e.qid
    local t = {}
    local function add(title, text) if text and text ~= "" then t[#t + 1] = CYAN .. title .. "|r\n" .. text end end
    local ql, rl = safe(Q.questLevel, id), safe(Q.requiredLevel, id)
    local z = safe(Q.zoneOrSort, id)
    add("Quest", "Level " .. (ql or "?") .. (rl and rl > 0 and ("  (needs level " .. rl .. ")") or "") .. (z and ("  -  " .. (areaName(z) or "")) or ""))

    local sb = safe(Q.startedBy, id)
    if sb then
        local parts = {}
        if sb[1] and #sb[1] > 0 then parts[#parts + 1] = joinNames(sb[1], npcLine, 3) end
        if sb[2] and #sb[2] > 0 then parts[#parts + 1] = joinNames(sb[2], objectLine, 2) end
        if sb[3] and #sb[3] > 0 then parts[#parts + 1] = "from the item " .. joinNames(sb[3], itemNameOf, 2) end
        add("Where to start", table.concat(parts, "; "))
    end

    local ot = safe(Q.objectivesText, id)
    if ot and #ot > 0 then add("What to do", table.concat(ot, "\n")) end

    local ob = safe(Q.objectives, id)
    if ob then
        local how = {}
        for _, o in ipairs(ob[1] or {}) do
            how[#how + 1] = "Kill " .. (o[2] and o[2] ~= "" and o[2] or npcName(o[1])) .. (o[3] and (" x" .. o[3]) or "") .. " - " .. npcLine(o[1])
        end
        for _, o in ipairs(ob[2] or {}) do
            how[#how + 1] = "Use " .. (o[2] and o[2] ~= "" and o[2] or "the object") .. " - " .. objectLine(o[1])
        end
        for _, o in ipairs(ob[3] or {}) do
            local src = SFP:QuestieItemSources(o[1])
            how[#how + 1] = "Collect " .. (o[2] and o[2] ~= "" and o[2] or itemNameOf(o[1])) .. (o[3] and (" x" .. o[3]) or "") ..
                (src and ("\n    " .. table.concat(src, "\n    ")) or "")
        end
        add("How to do it", table.concat(how, "\n"))
    end

    local fb = safe(Q.finishedBy, id)
    if fb then
        local parts = {}
        if fb[1] and #fb[1] > 0 then parts[#parts + 1] = joinNames(fb[1], npcLine, 3) end
        if fb[2] and #fb[2] > 0 then parts[#parts + 1] = joinNames(fb[2], objectLine, 2) end
        add("Where to turn in", table.concat(parts, "; "))
    end

    local function qnames(list) return joinNames(list, function(q) return safe(Q.name, q) or ("quest " .. q) end, 4) end
    local pre = safe(Q.preQuestGroup, id)
    if pre and #pre > 0 then add("Do these first (all)", qnames(pre)) end
    local pre1 = safe(Q.preQuestSingle, id)
    if pre1 and #pre1 > 0 then add("Do one of these first", qnames(pre1)) end
    local nxt = safe(Q.nextQuestInChain, id)
    if nxt and nxt > 0 then add("Next in the chain", safe(Q.name, nxt) or ("quest " .. nxt)) end
    local skill = safe(Q.requiredSkill, id)
    if skill and skill[1] then add("Needs", "profession skill " .. skill[1] .. " at " .. (skill[2] or "?")) end
    return table.concat(t, "\n\n")
end

local function npcBody(e)
    local Q, N = dbs()
    local id = e.npcid
    local t = {}
    local function add(title, text) if text and text ~= "" then t[#t + 1] = CYAN .. title .. "|r\n" .. text end end
    local lo, hi = safe(N.minLevel, id), safe(N.maxLevel, id)
    local rank = safe(N.rank, id)
    add((RANK[rank] or "Monster") .. "  |cff808080NPC ID " .. id .. "|r",
        "Level " .. (lo and (lo == hi and lo or (lo .. "-" .. tostring(hi))) or "?") .. (safe(N.subName, id) and ("  <" .. safe(N.subName, id) .. ">") or ""))
    local sp = safe(N.spawns, id)
    if sp then
        local places = {}
        for area, coords in pairs(sp) do
            local c = coords and coords[1]
            places[#places + 1] = (areaName(area) or "?") .. ((c and c[1] and c[1] > 0) and (" %.0f, %.0f"):format(c[1], c[2]) or "")
            if #places >= 5 then break end
        end
        add("Where", table.concat(places, "\n"))
    end
    local qs = safe(N.questStarts, id)
    if qs and #qs > 0 and Q then add("Starts quests", joinNames(qs, function(q) return safe(Q.name, q) or ("quest " .. q) end, 6)) end
    local qe = safe(N.questEnds, id)
    if qe and #qe > 0 and Q then add("Turn in quests", joinNames(qe, function(q) return safe(Q.name, q) or ("quest " .. q) end, 6)) end
    local rec = SFP.db and SFP.db.npcs[id]
    local drops = {}
    if rec and rec.d then
        local list = {}
        for itemID, n in pairs(rec.d) do list[#list + 1] = { itemID, n } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for i = 1, math.min(12, #list) do
            drops[#drops + 1] = "• " .. SFP:ItemName(list[i][1]) .. ("  %d%%"):format(math.min(100, math.floor(list[i][2] * 100 / math.max(1, rec.k or 1) + 0.5)))
        end
        add("Drops you have seen (" .. (rec.k or 0) .. " kills)", table.concat(drops, "\n"))
    end
    local known = SFP:QuestieDropsOf(id)
    if known then
        local out = {}
        for _, itemID in ipairs(known) do out[#out + 1] = "• " .. itemNameOf(itemID) end
        add("Known drops (database)", table.concat(out, "\n"))
    end
    return table.concat(t, "\n\n")
end

---------------------------------------------------------------------------
-- Dungeon and raid entrances (Questie knows where every entrance is)
---------------------------------------------------------------------------
local dungeonIndex, byArea
local function buildDungeonIndex()
    local idx = {}
    byArea = {}
    local Z = getZoneDB()
    if not Z then return idx end
    local d = (Z.GetDungeons and safe(Z.GetDungeons, Z)) or Z.dungeons
    if type(d) ~= "table" then return idx end
    for areaId, e in pairs(d) do
        local name, loc = e[1], e[4] and e[4][1]
        if name and type(loc) == "table" and loc[1] then
            local m = safe(function() return Z:GetUiMapIdByAreaId(loc[1]) end)
            if m then
                local entry = { map = m, x = loc[2] / 100, y = loc[3] / 100, name = name, area = areaId }
                idx[name:lower()] = entry
                byArea[areaId] = entry
                for _, alt in ipairs(e[2] or {}) do byArea[alt] = entry end
            end
        end
    end
    return idx
end

-- { map, x, y, name } of a dungeon or raid entrance by name
function SFP:QuestieEntrance(name)
    if not (name and self:HasQuestieDB()) then return nil end
    dungeonIndex = dungeonIndex or buildDungeonIndex()
    return dungeonIndex[name:lower()]
end

function SFP:InstanceEntranceByArea(areaId)
    if not self:HasQuestieDB() then return nil end
    dungeonIndex = dungeonIndex or buildDungeonIndex()
    return byArea and byArea[areaId]
end

function SFP:FeedDungeons(cx)
    dungeonIndex = dungeonIndex or buildDungeonIndex()
    for _, d in pairs(dungeonIndex) do
        local pin = { m = d.map, x = d.x, y = d.y }
        local e = (cx.FindByName and (cx:FindByName("dungeon", d.name) or cx:FindByName("raid", d.name))) or nil
        if e and not e.map then e.map = pin end
        cx:Add({
            cat = "entrance", id = "q" .. d.area, name = d.name, group = "Dungeon and raid entrances",
            icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran", sub = self:ZoneName(d.map),
            map = pin, tags = "entrance dungeon raid how to enter",
            body = (cx.CYAN or "") .. "How to enter|r\nGo to " .. self:ZoneName(d.map) .. (" at %.1f, %.1f"):format(d.x * 100, d.y * 100) ..
                " and walk into the entrance. Use Show on map for an arrow.",
        })
    end
    -- bosses point to the entrance of their instance
    for _, b in ipairs((cx.byCat and cx.byCat.boss) or {}) do
        if not b.map and b.instKey then
            local inst = cx:Get(b.instKey)
            if inst and inst.map then b.map = inst.map end
        end
    end
end

function SFP:FeedQuestie(cx)
    if self.FeedDungeons then self:FeedDungeons(cx) end
    local Q, N = dbs()
    if not (cx and cx.Add and Q and N) then return end
    local qids = safe(Q.GetAllIds)
    if qids then
        for i = 1, #qids do
            local id = qids[i]
            local name = safe(Q.name, id)
            if name and name ~= "" and not name:find("^%[") then
                local z = safe(Q.zoneOrSort, id)
                local ql = safe(Q.questLevel, id)
                cx:Add({
                    cat = "quest", id = id, name = name, group = areaName(z) or "Other quests",
                    icon = "Interface\\Icons\\INV_Misc_Note_01", sub = "level " .. (ql or "?"),
                    map = (function()
                        local sb = safe(Q.startedBy, id)
                        local npc = sb and sb[1] and sb[1][1]
                        if npc then return uiSpot(safe(N.spawns, npc)) end
                        local obj = sb and sb[2] and sb[2][1]
                        local _, _, _, O = dbs()
                        if obj and O then return uiSpot(safe(O.spawns, obj)) end
                    end)(),
                    qid = id, collected = safe(C_QuestLog.IsQuestFlaggedCompleted, id) and true or false, bodyFn = questBody, wh = "quest=" .. id, tags = "quest",
                })
            end
            if i % 60 == 0 then cx:Yield() end
        end
    end
    local nids = safe(N.GetAllIds)
    if nids then
        local added = 0
        for i = 1, #nids do
            local id = nids[i]
            local rank = safe(N.rank, id)
            if rank and rank >= 1 then
                local name = safe(N.name, id)
                if name and name ~= "" then
                    local lo, hi = safe(N.minLevel, id), safe(N.maxLevel, id)
                    local z = safe(N.zoneID, id)
                    cx:Add({
                        cat = "creature", id = "q" .. id, name = name,
                        group = (RANK[rank] or "Monster") .. "s - " .. (areaName(z) or "other"),
                        icon = "Interface\\Icons\\Ability_Warrior_Revenge",
                        sub = "level " .. (lo or "?") .. " " .. (RANK[rank] or ""),
                        map = uiSpot(safe(N.spawns, id)),
                        npcid = id, bodyFn = npcBody, wh = "npc=" .. id, tags = "monster npc " .. (RANK[rank] or ""),
                    })
                    added = added + 1
                end
            end
            if i % 80 == 0 then cx:Yield() end
        end
    end
end

---------------------------------------------------------------------------
-- Rares from the database become orange spots on the world map (Classic to Mists)
---------------------------------------------------------------------------
function SFP:AddRareSpot(mapID, sp)
    local exp = self:ExpansionForMap(mapID)
    if not exp then return false end
    local pts = {}
    for x, y in sp.pts:gmatch("([%d%.]+),([%d%.]+)") do
        pts[#pts + 1] = { tonumber(x) / 100, tonumber(y) / 100 }
    end
    if #pts == 0 then return false end
    local zone = self.zoneByMap[mapID]
    if not zone then
        zone = { map = mapID, items = {}, instances = {}, rareOnly = true }
        table.insert(exp.zones, zone)
        self.zoneByMap[mapID] = zone
        self.zoneExp[mapID] = exp
    end
    local sx, sy = 0, 0
    for _, p in ipairs(pts) do sx, sy = sx + p[1], sy + p[2] end
    sp.points, sp.hx, sp.hy = pts, sx / #pts, sy / #pts
    sp.rare, sp.imported = true, true
    zone.spawns = zone.spawns or {}
    zone.spawns[#zone.spawns + 1] = sp
    zone._areas = nil
    return true
end

local function importRares()
    local _, N = dbs()
    local loader = _G.QuestieLoader
    local ZoneDB = loader and loader.ImportModule and safe(function() return loader:ImportModule("ZoneDB") end)
    if not (N and ZoneDB and ZoneDB.GetUiMapIdByAreaId) then return end
    local known = {}
    for _, list in pairs(SFP.Rares or {}) do
        for _, sp in ipairs(list) do if sp.npc then known[sp.npc] = true end end
    end
    local ids = safe(N.GetAllIds)
    if not ids then return end
    local i, total, added = 0, #ids, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        if InCombatLockdown() then return end
        for _ = 1, 300 do
            i = i + 1
            if i > total then
                self:Hide()
                SFP.importedRares = added
                if added > 0 then SFP:RefreshAll() end
                return
            end
            local id = ids[i]
            local rank = safe(N.rank, id)
            if (rank == 2 or rank == 4) and not known[id] then
                local name = safe(N.name, id)
                local spawns = safe(N.spawns, id)
                if name and name ~= "" and type(spawns) == "table" then
                    for area, coords in pairs(spawns) do
                        local mapID = safe(function() return ZoneDB:GetUiMapIdByAreaId(area) end)
                        if mapID and type(coords) == "table" and #coords > 0 then
                            local parts = {}
                            for k = 1, math.min(8, #coords) do
                                local c = coords[k]
                                if c and c[1] and c[1] > 0 then parts[#parts + 1] = string.format("%.1f,%.1f", c[1], c[2]) end
                            end
                            if #parts > 0 then
                                local lo, hi = safe(N.minLevel, id), safe(N.maxLevel, id)
                                local sp = { npc = id, name = name, items = {},
                                    note = "Rare" .. (lo and (" - level " .. lo .. ((hi and hi ~= lo) and ("-" .. hi) or "")) or "") ..
                                        ". From the Questie database; drops you see are learned as you kill it.",
                                    pts = table.concat(parts, ";") }
                                if SFP:AddRareSpot(mapID, sp) then added = added + 1; break end
                            end
                        end
                    end
                end
            end
        end
    end)
end

SFP:OnLogin(function()
    if SFP:HasQuestieDB() then
        C_Timer.After(15, startDropIndex)
        C_Timer.After(25, importRares)
    end
end)
