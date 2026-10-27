-- SeviathsUsefulTools - quest markers (replaces Questie's map and minimap icons)
--
-- Data: the QuestieDB addon (quests, monsters, objects, items with their spawn points). Everything
-- on screen is drawn by this addon with its own design:
--   gold badge "!"      a quest you can pick up (level, race, class, prerequisites checked)
--   cyan badge "?"      a finished quest, where to turn it in
--   skull / diamond / square   kill targets / items to collect / objects to use for your active quests
-- On the zone map of the world map and on the minimap (HereBeDragons-Pins, so it works with any
-- minimap addon). Hover for the quest, giver and objectives. Ctrl-click sets a waypoint.

local ADDON, SFP = ...

local floor, min, max = math.floor, math.min, math.max
local band = bit and bit.band

local function dbs()
    local d = SFP.QDB
    if not d then return nil end
    return d.Quest, d.Npc, d.Item, d.Object
end
local function safe(fn, ...)
    if not fn then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

local Q = {}
SFP.QuestMarkers = Q

local questZones                     -- forward declaration
local rebuildSets                    -- forward declaration
local entName                       -- forward declaration (defined with the tooltip helpers)
local version = 0                    -- bumped whenever the quest state changes
local state = { inLog = {}, complete = {}, done = {}, level = 1, raceMask = nil, classMask = nil }
local startIdx, finishIdx = {}, {}   -- [areaID] = flat { questID, entityID, kind, ... } (kind 1 npc, 2 object)
local starters = {}                  -- npcID -> { questIDs } of quests this npc starts
local indexed, indexing = false, false
local cache = {}                     -- ["map:version"] = collected markers
local elig = {}                      -- questID -> true / false (per version)
local targetsCache = {}              -- questID -> objective targets (per version)
local objNpc = {}                    -- npcID -> { quest titles }  (for the monster tooltip)

local function zoneDB() return SFP.GetZoneDB and SFP.GetZoneDB() end

---------------------------------------------------------------------------
-- player and quest state
---------------------------------------------------------------------------
local function questName(id)
    local QD = dbs()
    return QD and safe(QD.name, id) or ("quest " .. id)
end

local function refreshState()
    version = version + 1
    wipe(cache); wipe(elig); wipe(targetsCache); wipe(objNpc)
    state.level = UnitLevel("player") or 1
    local lib = SFP.QDB
    local _, classFile = UnitClass("player")
    local raceID = select(3, UnitRace("player"))
    if lib and lib.Enum then
        state.raceMask = lib.Enum.raceMaskById and lib.Enum.raceMaskById[raceID]
        state.classMask = lib.Enum.classKeys and lib.Enum.classKeys[classFile]
    end
    -- quest log (quests under a collapsed zone header are hidden by the game: expand them all once)
    local function scan()
        wipe(state.inLog); wipe(state.complete)
        state.list = {}
        local modern = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo
        local n, numQuests
        if modern then n, numQuests = C_QuestLog.GetNumQuestLogEntries()
        elseif GetNumQuestLogEntries then n, numQuests = GetNumQuestLogEntries() end
        n = n or 0
        state.gameCount = numQuests
        local zone = "Quests"
        for i = 1, n do
            local qid, header, isComplete, title, level
            if modern then
                local info = C_QuestLog.GetInfo(i)
                if info then qid, header, title, level = info.questID, info.isHeader, info.title, info.level end
                if qid and C_QuestLog.IsComplete then isComplete = C_QuestLog.IsComplete(qid) end
            elseif GetQuestLogTitle then
                local t, l, _, isHeader, _, comp, _, questID = GetQuestLogTitle(i)
                qid, header, isComplete, title, level = questID, isHeader, (comp == 1), t, l
            end
            if header then
                zone = title or zone
            elseif qid then
                state.inLog[qid] = true
                if isComplete then state.complete[qid] = true end
                state.list[#state.list + 1] = { q = qid, t = title or questName(qid), l = level or 0, z = zone, c = isComplete and true or false, i = i }
            end
        end
    end
    scan()
    if state.gameCount and #state.list < state.gameCount then
        if C_QuestLog and C_QuestLog.ExpandQuestHeader then pcall(C_QuestLog.ExpandQuestHeader, 0, true) end
        if ExpandQuestHeader then pcall(ExpandQuestHeader, 0) end
        scan()
    end
    -- finished quests
    wipe(state.done)
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local list = safe(C_QuestLog.GetAllCompletedQuestIDs)
        for _, id in ipairs(list or {}) do state.done[id] = true end
    end
end

local function isDone(qid)
    if state.done[qid] then return true end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and not (C_QuestLog.GetAllCompletedQuestIDs) then
        return C_QuestLog.IsQuestFlaggedCompleted(qid) and true or false
    end
    return false
end

-- can the player pick this quest up right now?
local function eligible(qid, trivialOk)
    local c = elig[qid]
    if c ~= nil then return c end
    local QD = dbs()
    local ok = true
    if state.inLog[qid] or isDone(qid) then ok = false end
    if ok then
        local rl = safe(QD.requiredLevel, qid) or 0
        local ql = safe(QD.questLevel, qid) or rl
        local maxl = safe(QD.requiredMaxLevel, qid)
        if rl > state.level then ok = false end
        if maxl and maxl > 0 and state.level > maxl then ok = false end
        if ok and not trivialOk and ql > 0 and ql < state.level - (GetQuestGreenRange and GetQuestGreenRange() or 6) then ok = false end
    end
    if ok and band then
        local races = safe(QD.requiredRaces, qid)
        if races and races > 0 and state.raceMask and band(state.raceMask, races) == 0 then ok = false end
        local classes = safe(QD.requiredClasses, qid)
        if classes and classes > 0 and state.classMask and band(state.classMask, classes) == 0 then ok = false end
    end
    if ok then
        local group = safe(QD.preQuestGroup, qid)
        if group and #group > 0 then
            for _, p in ipairs(group) do if not isDone(p) then ok = false; break end end
        end
    end
    if ok then
        local single = safe(QD.preQuestSingle, qid)
        if single and #single > 0 then
            local any = false
            for _, p in ipairs(single) do if isDone(p) then any = true; break end end
            if not any then ok = false end
        end
    end
    if ok then
        local excl = safe(QD.exclusiveTo, qid)
        for _, x in ipairs(excl or {}) do if isDone(x) or state.inLog[x] then ok = false; break end end
    end
    if ok then
        local untilDone = safe(QD.availableUntilCompleted, qid)
        if untilDone and untilDone > 0 and isDone(untilDone) then ok = false end
    end
    elig[qid] = ok
    return ok
end

---------------------------------------------------------------------------
-- index: which quests start / end in which area (built slowly in the background)
---------------------------------------------------------------------------
local function addIdx(idx, area, qid, ent, kind)
    local l = idx[area]
    if not l then l = {}; idx[area] = l end
    l[#l + 1] = qid; l[#l + 1] = ent; l[#l + 1] = kind
end

local function buildIndex()
    if indexed or indexing then return end
    local QD, N, _, O = dbs()
    if not (QD and N and QD.GetAllIds) then return end
    local ids = safe(QD.GetAllIds)
    if not ids then return end
    indexing = true
    local i, total = 0, #ids
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        if InCombatLockdown() then return end
        for _ = 1, 120 do
            i = i + 1
            if i > total then
                self:Hide(); indexing = false; indexed = true
                Q:Refresh()
                return
            end
            local qid = ids[i]
            local sb = safe(QD.startedBy, qid)
            if sb then
                for _, npc in ipairs(sb[1] or {}) do
                    local s = starters[npc]
                    if not s then s = {}; starters[npc] = s end
                    s[#s + 1] = qid
                    local sp = safe(N.spawns, npc)
                    if type(sp) == "table" then for area in pairs(sp) do addIdx(startIdx, area, qid, npc, 1) end end
                end
                for _, obj in ipairs(sb[2] or {}) do
                    local sp = O and safe(O.spawns, obj)
                    if type(sp) == "table" then for area in pairs(sp) do addIdx(startIdx, area, qid, obj, 2) end end
                end
            end
            local fb = safe(QD.finishedBy, qid)
            if fb then
                for _, npc in ipairs(fb[1] or {}) do
                    local sp = safe(N.spawns, npc)
                    if type(sp) == "table" then for area in pairs(sp) do addIdx(finishIdx, area, qid, npc, 1) end end
                end
                for _, obj in ipairs(fb[2] or {}) do
                    local sp = O and safe(O.spawns, obj)
                    if type(sp) == "table" then for area in pairs(sp) do addIdx(finishIdx, area, qid, obj, 2) end end
                end
            end
        end
    end)
end

---------------------------------------------------------------------------
-- objectives of the active quests
---------------------------------------------------------------------------
local function blizzObjectives(qid)
    if C_QuestLog and C_QuestLog.GetQuestObjectives then return safe(C_QuestLog.GetQuestObjectives, qid) or {} end
    return {}
end

local function objectiveDone(objs, name)
    if not name or name == "" then return false end
    local l = name:lower()
    for _, o in ipairs(objs) do
        local t = (o.text or ""):lower()
        if t:find(l, 1, true) then return o.finished and true or false end
    end
    return false
end

-- { {k = "kill"|"loot"|"obj", ent, kind (1 npc / 2 object), text} } for one active quest
local function targetsOf(qid)
    local c = targetsCache[qid]
    if c then return c end
    local QD, N, I, O = dbs()
    local out = {}
    local ob = QD and safe(QD.objectives, qid)
    if ob then
        local bl = blizzObjectives(qid)
        for _, o in ipairs(ob[1] or {}) do
            local nm = (o[2] and o[2] ~= "") and o[2] or safe(N.name, o[1])
            if not objectiveDone(bl, nm) then out[#out + 1] = { k = "kill", ent = o[1], kind = 1, text = "Kill " .. (nm or "monster") } end
        end
        for _, o in ipairs(ob[5] or {}) do
            local ids = o[1]
            if type(ids) == "table" then
                for _, npc in ipairs(ids) do out[#out + 1] = { k = "kill", ent = npc, kind = 1, text = "Kill " .. (o[2] or safe(N.name, npc) or "monster") } end
            end
        end
        for _, o in ipairs(ob[2] or {}) do
            local nm = (o[2] and o[2] ~= "") and o[2] or (O and safe(O.name, o[1]))
            if not objectiveDone(bl, nm) then out[#out + 1] = { k = "obj", ent = o[1], kind = 2, text = "Use " .. (nm or "the object") } end
        end
        for _, o in ipairs(ob[3] or {}) do
            local nm = (o[2] and o[2] ~= "") and o[2] or (I and safe(I.name, o[1])) or ("item " .. o[1])
            if not objectiveDone(bl, nm) then
                local npcs = I and safe(I.npcDrops, o[1])
                for j = 1, min(8, npcs and #npcs or 0) do
                    out[#out + 1] = { k = "loot", ent = npcs[j], kind = 1, text = "Collect " .. nm }
                end
                local objs = I and safe(I.objectDrops, o[1])
                for j = 1, min(4, objs and #objs or 0) do
                    out[#out + 1] = { k = "loot", ent = objs[j], kind = 2, text = "Collect " .. nm }
                end
            end
        end
    end
    for _, st in ipairs(QD and safe(QD.spots, qid) or {}) do
        out[#out + 1] = { k = "obj", kind = 3, ent = 0, sp = st.sp, text = (st.text ~= "" and st.text or "Go to the marked area") }
    end
    targetsCache[qid] = out
    local title = questName(qid)
    for _, t in ipairs(out) do
        if t.kind == 1 then
            local l = objNpc[t.ent]
            if not l then l = {}; objNpc[t.ent] = l end
            l[#l + 1] = title .. ": " .. t.text
        end
    end
    return out
end

function Q:LogList() return state.list or {} end
function Q:GameCount() return state.gameCount end

-- bring everything up to date right now (used when a window opens)
function Q:RefreshNow()
    if not Q.enabled then return end
    SFP:Safe("quest state", refreshState)
    SFP:Safe("quest sets", function() rebuildSets() end)
end

function Q:SetPin(m, x, y, text, qid)
    SFP.db.questPin = { m = m, x = x, y = y, text = text, q = qid }
    wipe(cache)
    Q:DrawWorldMap()
end

function Q:ClearPin()
    SFP.db.questPin = nil
    wipe(cache)
    Q:DrawWorldMap()
end
function Q:IsComplete(qid) return state.complete[qid] and true or false end
function Q:Version() return version end

-- where to go for this quest: { m = uiMapID, x, y, text } (turn-in when finished, else the nearest objective)
function Q:Locate(qid)
    local QD, N, _, O = dbs()
    local Z = zoneDB()
    local function spot(kind, ent, own)
        local sp = own or (kind == 1 and safe(N.spawns, ent)) or (O and kind == 2 and safe(O.spawns, ent))
        if type(sp) ~= "table" or not (Z and Z.GetUiMapIdByAreaId) then return nil end
        local px, py
        local here = C_Map.GetBestMapForUnit("player")
        local pos = here and C_Map.GetPlayerMapPosition(here, "player")
        if pos and pos.GetXY then px, py = pos:GetXY() end
        local best, bd
        for area, coords in pairs(sp) do
            local m = safe(function() return Z:GetUiMapIdByAreaId(area) end)
            local c = type(coords) == "table" and coords[1]
            if m and c and c[1] and c[1] > 0 then
                local d = (m == here and px) and ((c[1] / 100 - px) ^ 2 + (c[2] / 100 - py) ^ 2) or 10
                if not bd or d < bd then best, bd = { m = m, x = c[1] / 100, y = c[2] / 100 }, d end
            end
        end
        return best
    end
    if not state.complete[qid] then
        for _, t in ipairs(targetsOf(qid)) do
            local p = spot(t.kind, t.ent, t.sp)
            if p then p.text = t.text .. (entName(t.kind, t.ent) ~= "" and (" - " .. entName(t.kind, t.ent)) or ""); return p end
        end
    end
    -- finished quests and "report to ..." quests: where it is handed in
    local fb = QD and safe(QD.finishedBy, qid)
    for kind = 1, 2 do
        for _, ent in ipairs(fb and fb[kind] or {}) do
            local p = spot(kind, ent)
            if p then p.text = (state.complete[qid] and "Turn in: " or "Report to: ") .. entName(kind, ent); return p end
        end
    end
    if C_QuestLog and C_QuestLog.GetNextWaypoint then
        local wm, wx, wy = safe(C_QuestLog.GetNextWaypoint, qid)
        if wm and wx then return { m = wm, x = wx, y = wy, text = "Quest position (from the game)" } end
    end
    local sb = QD and safe(QD.startedBy, qid)
    for kind = 1, 2 do
        for _, ent in ipairs(sb and sb[kind] or {}) do
            local p = spot(kind, ent)
            if p then p.text = "Exact spot not known - quest giver: " .. entName(kind, ent); return p end
        end
    end
    return nil
end

-- quests whose objectives involve this monster (for its tooltip)
function SFP:QuestObjectiveNpc(npcID)
    if not Q.enabled then return nil end
    for qid in pairs(state.inLog) do if not state.complete[qid] then targetsOf(qid) end end
    return objNpc[npcID]
end

---------------------------------------------------------------------------
-- collecting what to draw on one map
---------------------------------------------------------------------------
local function coordsOf(kind, ent, area, limit, own)
    local _, N, _, O = dbs()
    local sp = own or (kind == 1 and safe(N.spawns, ent)) or (O and kind == 2 and safe(O.spawns, ent))
    local list = type(sp) == "table" and sp[area]
    local out = {}
    if list then
        for i = 1, min(limit or 3, #list) do
            local c = list[i]
            if c and c[1] and c[1] > 0 then out[#out + 1] = { c[1] / 100, c[2] / 100 } end
        end
    end
    return out
end

entName = function(kind, ent)
    if not kind or kind == 0 or kind == 3 then return "" end
    local _, N, _, O = dbs()
    return (kind == 1 and safe(N.name, ent)) or (O and safe(O.name, ent)) or "?"
end

function Q:Collect(mapID)
    if not (mapID and Q.enabled) then return nil end
    local key = mapID .. ":" .. version
    if cache[key] ~= nil then return cache[key] or nil end
    local Z = zoneDB()
    local area = Z and Z.GetAreaIdByUiMapId and safe(function() return Z:GetAreaIdByUiMapId(mapID) end)
    if not area or area == 0 then cache[key] = false; return nil end
    local QD, N, _, O = dbs()
    local res = { avail = {}, turnin = {}, obj = {}, area = area, mapID = mapID }
    local trivialOk = SFP.db.questTrivial

    -- quests to pick up
    local l = SFP.db.questAvail and startIdx[area]
    if l then
        local seen = {}
        for i = 1, #l, 3 do
            local qid, ent, kind = l[i], l[i + 1], l[i + 2]
            if not seen[qid .. ":" .. ent] and eligible(qid, trivialOk) then
                seen[qid .. ":" .. ent] = true
                local ql = safe(QD.questLevel, qid) or 0
                for _, c in ipairs(coordsOf(kind, ent, area, 2)) do
                    res.avail[#res.avail + 1] = { q = qid, ent = ent, kind = kind, x = c[1], y = c[2], lvl = ql,
                        trivial = ql > 0 and ql < state.level - (GetQuestGreenRange and GetQuestGreenRange() or 6) }
                end
            end
        end
    end
    -- finished quests: where to hand them in
    for qid in pairs(state.complete) do
        local fb = safe(QD.finishedBy, qid)
        for kind = 1, 2 do
            for _, ent in ipairs(fb and fb[kind] or {}) do
                for _, c in ipairs(coordsOf(kind, ent, area, 2)) do
                    res.turnin[#res.turnin + 1] = { q = qid, ent = ent, kind = kind, x = c[1], y = c[2] }
                end
            end
        end
    end
    -- objectives of the open quests
    for qid in pairs(state.inLog) do
        if not state.complete[qid] then
            local n = 0
            local seen = {}
            local tg = targetsOf(qid)
            local obq = safe(QD.objectives, qid)
            local hasObj = obq and (#(obq[1] or {}) + #(obq[2] or {}) + #(obq[3] or {}) + #(obq[5] or {})) > 0
            if #tg == 0 and not hasObj then
                -- nothing to kill or collect: talk to the finisher ("Report to ...")
                local fb = safe(QD.finishedBy, qid)
                for kind = 1, 2 do
                    for _, ent in ipairs(fb and fb[kind] or {}) do
                        for _, c in ipairs(coordsOf(kind, ent, area, 2)) do
                            res.turnin[#res.turnin + 1] = { q = qid, ent = ent, kind = kind, x = c[1], y = c[2] }
                        end
                    end
                end
            end
            for _, t in ipairs(tg) do
                for _, c in ipairs(coordsOf(t.kind, t.ent, area, 10, t.sp)) do
                    local cell = floor(c[1] * 120) .. ":" .. floor(c[2] * 120) .. ":" .. qid .. t.k
                    if not seen[cell] and n < 60 then
                        seen[cell] = true; n = n + 1
                        res.obj[#res.obj + 1] = { q = qid, k = t.k, ent = t.ent, kind = t.kind, x = c[1], y = c[2], text = t.text }
                    end
                end
            end
            -- places where you met the monsters named in the quest text
            for _, p in ipairs(SFP.db.questSeen and SFP.db.questSeen[qid] or {}) do
                if p.m == mapID and n < 60 then
                    n = n + 1
                    res.obj[#res.obj + 1] = { q = qid, k = "kill", ent = 0, kind = 3, x = p.x, y = p.y, text = "Monsters of this quest were here" }
                end
            end
            -- no target of this quest has a known position anywhere: mark the area around its giver / hand-in
            if (#tg > 0 or hasObj) and n == 0 then
                local known = false
                for _, t in ipairs(tg) do
                    local sp = t.sp or (t.kind == 1 and safe(N.spawns, t.ent)) or (t.kind == 2 and O and safe(O.spawns, t.ent))
                    if type(sp) == "table" and next(sp) then known = true; break end
                end
                if not known then
                    local fb2, sb2 = safe(QD.finishedBy, qid), safe(QD.startedBy, qid)
                    for _, set in ipairs({ fb2, sb2 }) do
                        for kind = 1, 2 do
                            for _, ent in ipairs(set and set[kind] or {}) do
                                for _, c in ipairs(coordsOf(kind, ent, area, 1)) do
                                    if n == 0 then
                                        n = 1
                                        res.obj[#res.obj + 1] = { q = qid, k = "obj", ent = ent, kind = kind, x = c[1], y = c[2], big = true,
                                            text = "Exact spot not known - around " .. entName(kind, ent) }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- quests in your log with no marker here: ask the game where it wants you (quest area / waypoint)
    local placed = {}
    for _, m in ipairs(res.turnin) do placed[m.q] = true end
    for _, m in ipairs(res.obj) do placed[m.q] = true end
    local onMap = C_QuestLog and C_QuestLog.GetQuestsOnMap and safe(C_QuestLog.GetQuestsOnMap, mapID)
    local byQuest = {}
    for _, e in ipairs(onMap or {}) do if e.questID then byQuest[e.questID] = e end end
    for qid in pairs(state.inLog) do
        if not placed[qid] then
            local x, y
            local wp = C_QuestLog and C_QuestLog.GetNextWaypoint
            if wp then
                local wm, wx, wy = safe(wp, qid)
                if wm == mapID and wx then x, y = wx, wy end
            end
            if not x and byQuest[qid] then x, y = byQuest[qid].x, byQuest[qid].y end
            if x then
                local done = state.complete[qid]
                local m = { q = qid, k = "obj", ent = 0, kind = 0, x = x, y = y, text = done and "Ready to turn in (position from the game)" or "Quest area (position from the game)" }
                if done then res.turnin[#res.turnin + 1] = m else res.obj[#res.obj + 1] = m end
            end
        end
    end
    cache[key] = res
    return res
end

---------------------------------------------------------------------------
-- look of the markers
---------------------------------------------------------------------------
local RAID = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local STYLE = {
    avail  = { bare = "Interface\\GossipFrame\\AvailableQuestIcon" },
    gray   = { bare = "Interface\\GossipFrame\\AvailableQuestIcon", gray = true },
    turnin = { ring = { 0.1, 0.9, 1.0 }, glyph = "?", gcolor = { 0.6, 1.0, 1.0 } },
    kill   = { tex = RAID .. "8", ring = { 1.0, 0.3, 0.3 } },
    loot   = { tex = RAID .. "3", ring = { 0.4, 1.0, 0.5 } },
    obj    = { tex = RAID .. "6", ring = { 0.4, 0.7, 1.0 } },
    pin    = { tex = RAID .. "1", ring = { 0.2, 1.0, 1.0 } },
}
local DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function newIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(18, 18)
    f.ring = f:CreateTexture(nil, "BACKGROUND")
    f.ring:SetAllPoints()
    f.ring:SetTexture(DISC)
    f.core = f:CreateTexture(nil, "BORDER")
    f.core:SetPoint("CENTER")
    f.core:SetSize(14, 14)
    f.core:SetTexture(DISC)
    f.core:SetVertexColor(0.04, 0.07, 0.1, 0.95)
    f.pic = f:CreateTexture(nil, "ARTWORK")
    f.pic:SetPoint("CENTER")
    f.pic:SetSize(12, 12)
    f.glyph = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.glyph:SetPoint("CENTER", 0, 0)
    f:EnableMouse(true)
    return f
end

local function fit(f, s)
    if f.blob then f:SetSize(s, s); return end
    f:SetSize(s, s)
    f.core:SetSize(s - 4, s - 4)
    local p = f.bare and s or (s - 6)
    f.pic:SetSize(p, p)
end

local function style(f, m)
    if m.blob then
        -- quest area: a soft translucent disc over the places where the targets are (retail style)
        f.blob, f.bare = true, false
        f.ring:Show(); f.core:Hide(); f.pic:Hide(); f.glyph:Hide()
        local c = m.zoneKind == "turn" and { 0.3, 0.85, 1.0 } or { 1.0, 0.85, 0.2 }
        f.ring:SetVertexColor(c[1], c[2], c[3], m.alpha or 0.26)
        f.m = m
        return
    end
    f.blob = false
    f.core:Show()
    local st
    if m.type == "avail" then st = m.trivial and STYLE.gray or STYLE.avail
    elseif m.type == "turnin" then st = STYLE.turnin
    elseif m.type == "pin" then st = STYLE.pin
    elseif m.type == "zone" then st = (m.k == "turn") and STYLE.turnin or STYLE.kill
    else st = STYLE[m.k] or STYLE.kill end
    f.bare = st.bare and true or false
    f.ring:SetShown(not st.bare); f.core:SetShown(not st.bare)
    if st.bare then
        f.pic:SetTexture(st.bare); f.pic:Show(); f.glyph:Hide()
        f.pic:SetVertexColor(st.gray and 0.65 or 1, st.gray and 0.65 or 1, st.gray and 0.65 or 1, 1)
        f.m = m
        return
    end
    f.pic:SetVertexColor(1, 1, 1, 1)
    f.ring:SetVertexColor(st.ring[1], st.ring[2], st.ring[3], 1)
    if st.tex then
        f.pic:SetTexture(st.tex); f.pic:Show(); f.glyph:Hide()
    else
        f.pic:Hide(); f.glyph:SetText(st.glyph); f.glyph:SetTextColor(unpack(st.gcolor)); f.glyph:Show()
    end
    f.m = m
end

local function tooltip(f)
    local m = f.m
    if not m then return end
    local QD = dbs()
    GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
    local title = questName(m.q)
    if m.type == "zone" then
        GameTooltip:AddLine(SFP:ZoneName(m.zone), 1, 0.82, 0)
        GameTooltip:AddLine(m.k == "turn" and "Hand in here" or "Quest work here", 0.8, 0.8, 0.8)
        for i, q in ipairs(m.quests or {}) do
            if i > 8 then GameTooltip:AddLine("...", 0.6, 0.6, 0.6); break end
            GameTooltip:AddLine("- " .. questName(q), 1, 1, 1)
        end
        GameTooltip:AddLine("Click: open this zone", 0.5, 0.5, 0.5)
        GameTooltip:Show()
        return
    end
    if m.type == "pin" then
        GameTooltip:AddLine("Pinned", 0.2, 1, 1)
        GameTooltip:AddLine(m.text or "", 1, 1, 1, true)
        GameTooltip:AddLine("Right-click: remove the pin", 0.5, 0.5, 0.5)
        GameTooltip:Show()
        return
    end
    if m.type == "avail" then
        local c = GetQuestDifficultyColor and GetQuestDifficultyColor(m.lvl or state.level) or { r = 1, g = 0.82, b = 0 }
        GameTooltip:AddLine("[" .. (m.lvl or "?") .. "] " .. title, c.r, c.g, c.b)
        GameTooltip:AddLine("Quest available" .. (m.trivial and " (low level)" or ""), 1, 0.9, 0.4)
        GameTooltip:AddLine("From: " .. entName(m.kind, m.ent), 0.9, 0.9, 0.9)
        for _, t in ipairs(safe(QD.objectivesText, m.q) or {}) do GameTooltip:AddLine(t, 0.8, 0.8, 0.8, true) end
    elseif m.type == "turnin" then
        GameTooltip:AddLine(title, 0.4, 1, 1)
        GameTooltip:AddLine("Ready to turn in: " .. entName(m.kind, m.ent), 0.9, 0.9, 0.9)
    else
        GameTooltip:AddLine(title, 1, 0.82, 0)
        GameTooltip:AddLine(m.text or "", 1, 1, 1)
        GameTooltip:AddLine(entName(m.kind, m.ent), 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(string.format("%.1f, %.1f", m.x * 100, m.y * 100), 1, 0.82, 0)
    GameTooltip:AddLine("Ctrl-click: waypoint", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function wire(f)
    f:SetScript("OnEnter", tooltip)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnMouseUp", function(self, btn)
        if btn == "RightButton" and self.m and self.m.type == "pin" then Q:ClearPin(); return end
        if btn == "LeftButton" and self.m and self.m.type == "zone" and WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(self.m.zone); return end
        if IsControlKeyDown() and self.m and self.mapID and SFP.SetWaypoint and self.m.type ~= "pin" then
            SFP:SetWaypoint(self.mapID, self.m.x, self.m.y, questName(self.m.q))
        end
    end)
end

local function markersOf(res, skipObj)
    local out = {}
    for _, m in ipairs(res.avail) do m.type = "avail"; out[#out + 1] = m end
    for _, m in ipairs(res.turnin) do m.type = "turnin"; out[#out + 1] = m end
    for _, m in ipairs(res.obj) do m.type = "obj"; if not skipObj then out[#out + 1] = m end end
    local p = SFP.db and SFP.db.questPin
    if p and p.m == res.mapID then
        out[#out + 1] = { type = "pin", k = "pin", q = p.q or 0, ent = 0, kind = 0, x = p.x, y = p.y, text = p.text }
    end
    return out
end

---------------------------------------------------------------------------
-- world map
---------------------------------------------------------------------------
local layer
local wpool, wused = {}, 0

local function canvasScale()
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    return (sc and sc.GetCanvasScale and sc:GetCanvasScale()) or 1
end

-- continent / world map: one icon in the middle of every zone that holds quest work
function Q:DrawContinent(mapID, w, h)
    if SFP.db.questZones == false or not SFP.IsUnderMap then return end
    local sets = questZones()
    local k = SFP.db.questIconScale or 0.7
    local size = max(11 * k, 22 / canvasScale() * k)
    local function place(zone, qids, kind)
        if not SFP.IsUnderMap(zone, mapID) then return end
        local l, r, t, b = C_Map.GetMapRectOnMap(zone, mapID)
        if not l or r <= l or b <= t then return end
        wused = wused + 1
        local f = wpool[wused]
        if not f then f = newIcon(layer); wire(f); wpool[wused] = f end
        f.mapID = mapID
        style(f, { type = "zone", k = kind, zone = zone, quests = qids, blob = (kind == "kill"), zoneKind = kind, alpha = 0.3 })
        fit(f, kind == "kill" and size * 1.8 or size)
        f:ClearAllPoints()
        f:SetPoint("CENTER", layer, "TOPLEFT", ((l + r) / 2) * w, -((t + b) / 2) * h)
        f:SetFrameLevel(layer:GetFrameLevel() + 2)
        f:Show()
    end
    for zone, qids in pairs(sets.obj) do place(zone, qids, "kill") end
    for zone, qids in pairs(sets.turn) do
        if not sets.obj[zone] then place(zone, qids, "turn") end
    end
end

function Q:DrawWorldMap()
    if not layer then return end
    for i = 1, #wpool do wpool[i]:Hide() end
    wused = 0
    if not Q.enabled or not WorldMapFrame:IsShown() then return end
    local mapID = WorldMapFrame:GetMapID()
    local res = self:Collect(mapID)
    local w, h = layer:GetWidth(), layer:GetHeight()
    if w <= 0 then return end
    if not res then self:DrawContinent(mapID, w, h); return end
    local k = SFP.db.questIconScale or 0.7
    local size = max(10 * k, 20 / canvasScale() * k)
    -- kill / collect targets: one translucent area per cluster instead of an icon per spawn point
    local blobs = {}
    for _, m in ipairs(res.obj) do
        local hit
        for _, b in ipairs(blobs) do
            if b.q == m.q and (b.sx / b.n - m.x) ^ 2 + (b.sy / b.n - m.y) ^ 2 < 0.07 ^ 2 then hit = b; break end
        end
        if hit then
            hit.n = hit.n + 1; hit.sx = hit.sx + m.x; hit.sy = hit.sy + m.y
            if #hit.texts < 4 and m.text then hit.texts[#hit.texts + 1] = m.text end
        else
            blobs[#blobs + 1] = { q = m.q, n = 1, sx = m.x, sy = m.y, k = m.k, ent = m.ent, kind = m.kind, texts = { m.text }, big = m.big }
        end
    end
    for _, b in ipairs(blobs) do
        wused = wused + 1
        local f = wpool[wused]
        if not f then f = newIcon(layer); wire(f); wpool[wused] = f end
        f.mapID = mapID
        local m = { type = "obj", blob = true, q = b.q, k = b.k, ent = b.ent, kind = b.kind, x = b.sx / b.n, y = b.sy / b.n,
            text = table.concat(b.texts, ", "), alpha = 0.26 }
        style(f, m)
        local r = b.big and 0.085 or min(0.09, 0.028 + 0.012 * math.sqrt(b.n))
        f:SetSize(r * 2 * w, r * 2 * w)
        f:ClearAllPoints()
        f:SetPoint("CENTER", layer, "TOPLEFT", m.x * w, -m.y * h)
        f:SetFrameLevel(layer:GetFrameLevel() + 1)
        f:Show()
    end
    for _, m in ipairs(markersOf(res, true)) do
        wused = wused + 1
        local f = wpool[wused]
        if not f then f = newIcon(layer); wire(f); wpool[wused] = f end
        f.mapID = mapID
        style(f, m)
        local s = (m.type == "obj") and size * 0.8 or (m.type == "pin" and size * 1.5 or size)
        fit(f, s)
        f:ClearAllPoints()
        f:SetPoint("CENTER", layer, "TOPLEFT", m.x * w, -m.y * h)
        f:SetFrameLevel(layer:GetFrameLevel() + (m.type == "obj" and 1 or 3))
        f:Show()
    end
end

---------------------------------------------------------------------------
-- minimap (HereBeDragons-Pins)
---------------------------------------------------------------------------
local HBD
local mpool, mshown = {}, {}
local RANGE = 0.1
local currentMap

local function getHBD()
    if HBD then return HBD end
    if LibStub then HBD = LibStub("HereBeDragons-Pins-2.0", true) end
    return HBD
end

local function mclear()
    local h = getHBD()
    for key, f in pairs(mshown) do
        if h then pcall(h.RemoveMinimapIcon, h, Q, f) end
        f:Hide(); f.m = nil
        mpool[#mpool + 1] = f
        mshown[key] = nil
    end
end

local function mupdate()
    local h = getHBD()
    if not h or not Q.enabled or not SFP.db.questMinimap then mclear(); return end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py
    if pos and pos.GetXY then px, py = pos:GetXY() end
    if not px or px <= 0 then mclear(); return end
    local res = Q:Collect(mapID)
    if not res then mclear(); return end
    if currentMap ~= mapID then mclear(); currentMap = mapID end
    local wanted, n = {}, 0
    for _, m in ipairs(markersOf(res)) do
        local dx, dy = m.x - px, m.y - py
        if dx * dx + dy * dy < RANGE * RANGE then
            n = n + 1
            if n > 70 then break end
            wanted[m.type .. m.q .. ":" .. m.ent .. ":" .. floor(m.x * 1000) .. ":" .. floor(m.y * 1000)] = m
        end
    end
    for key, f in pairs(mshown) do
        if not wanted[key] then
            pcall(h.RemoveMinimapIcon, h, Q, f)
            f:Hide(); f.m = nil
            mpool[#mpool + 1] = f
            mshown[key] = nil
        end
    end
    for key, m in pairs(wanted) do
        if not mshown[key] then
            local f = table.remove(mpool)
            if not f then f = newIcon(UIParent); wire(f) end
            f.mapID = mapID
            if m.type == "obj" then m.blob = true; m.alpha = 0.3 end
            style(f, m)
            fit(f, (m.type == "obj" and 34 or (m.type == "avail" and 17 or 15)) * (SFP.db.questIconScale or 0.7))
            f:Show()
            if pcall(h.AddMinimapIconMap, h, Q, f, mapID, m.x, m.y, false, false) then
                mshown[key] = f
            else
                f:Hide(); mpool[#mpool + 1] = f
            end
        end
    end
end

---------------------------------------------------------------------------
-- icons over the heads of quest monsters (nameplates)
---------------------------------------------------------------------------
local finishSet, objSet = {}, {}
local textQuests = {}      -- quests matched by monster names in their text
local plateIcons = {}     -- unit token -> icon frame

rebuildSets = function()
    wipe(finishSet); wipe(objSet); wipe(textQuests)
    local QD = dbs()
    if not QD then return end
    for qid in pairs(state.complete) do
        local fb = safe(QD.finishedBy, qid)
        for _, npc in ipairs(fb and fb[1] or {}) do finishSet[npc] = true end
    end
    for qid in pairs(state.inLog) do
        if not state.complete[qid] then
            local tg = targetsOf(qid)
            for _, t in ipairs(tg) do if t.kind == 1 then objSet[t.ent] = true end end
            local hasKill = false
            for _, t in ipairs(tg) do if t.kind == 1 then hasKill = true; break end end
            if not hasKill then
                -- the database knows no monster for this quest: match monsters by the names in the quest text
                local tl = safe(QD.objectivesText, qid)
                local txt = (type(tl) == "table" and table.concat(tl, " ") or tl or ""):lower()
                if txt ~= "" then textQuests[#textQuests + 1] = { qid = qid, title = questName(qid), text = txt } end
            end
            if #tg == 0 then
                local fb = safe(QD.finishedBy, qid)
                for _, npc in ipairs(fb and fb[1] or {}) do finishSet[npc] = true end
            end
        end
    end
end

local function startsAvailable(npc)
    local l = starters[npc]
    if not l then return false end
    for i = 1, min(#l, 12) do
        if eligible(l[i], SFP.db.questTrivial) then return true end
    end
    return false
end

local function nameQuests(name)
    if not name or #name < 5 or #textQuests == 0 then return nil end
    local l = name:lower()
    local out, qids
    for _, e in ipairs(textQuests) do
        local from = e.text:find(l, 1, true)
        if from and (from == 1 or not e.text:sub(from - 1, from - 1):match("%a")) then
            out = out or {}
            out[#out + 1] = e.title
            qids = qids or {}
            qids[#qids + 1] = e.qid
        end
    end
    return out, qids
end
-- where you met monsters of a quest whose spawn points the database lacks: remembered account-wide
local function rememberSeen(qids)
    if not (qids and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not x or x == 0 then return end
    SFP.db.questSeen = SFP.db.questSeen or {}
    local changed
    for _, qid in ipairs(qids) do
        local l = SFP.db.questSeen[qid]
        if not l then l = {}; SFP.db.questSeen[qid] = l end
        local dup
        for _, p in ipairs(l) do
            if p.m == m and (p.x - x) ^ 2 + (p.y - y) ^ 2 < 0.012 ^ 2 then dup = true; break end
        end
        if not dup and #l < 30 then l[#l + 1] = { m = m, x = x, y = y }; changed = true end
    end
    if changed then wipe(cache); if Q.Refresh then Q:Refresh() end end
end
function Q:SeenMonster(unit)
    if not (Q.enabled and unit and UnitExists(unit) and not UnitIsPlayer(unit)) then return end
    local _, qids = nameQuests(UnitName(unit))
    rememberSeen(qids)
end
function SFP:QuestsByMonsterName(name)
    if not Q.enabled then return nil end
    return nameQuests(name)
end

local function headIcon(npc)
    if finishSet[npc] then return "turnin" end
    if SFP.db.questHeads ~= false and startsAvailable(npc) then return "avail" end
    if objSet[npc] then return "kill" end
    return nil
end

local function updatePlate(unit)
    local f = plateIcons[unit]
    local guid = unit and UnitGUID(unit)
    local npc
    if guid then
        local t, _, _, _, _, id = strsplit("-", guid)
        if t == "Creature" or t == "Vehicle" then npc = tonumber(id) end
    end
    local what = Q.enabled and npc and not UnitIsPlayer(unit) and headIcon(npc) or nil
    if Q.enabled and not what and unit and not UnitIsPlayer(unit) and SFP.db.questHeads ~= false and nameQuests(UnitName(unit)) then
        what = "kill"
        if UnitIsDead and not UnitIsDead(unit) then Q:SeenMonster(unit) end
    end
    if Q.enabled and not what and npc and not UnitIsPlayer(unit) and SFP.db.questHeads ~= false
        and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        -- the game itself knows this monster belongs to one of your quests (data gaps)
        local ok, rel = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok and rel then what = "kill" end
    end
    if not what then
        if f then f:Hide() end
        return
    end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    if not f then
        f = newIcon(UIParent)
        f:EnableMouse(false)
        plateIcons[unit] = f
    end
    -- some nameplate addons hide or move the stock plate: use the visible health bar / unit frame when there is one
    local anchor = plate.UnitFrame and plate.UnitFrame.healthBar or plate.UnitFrame or plate
    f:SetParent(plate)
    f:SetFrameStrata("HIGH")
    f:SetIgnoreParentAlpha(true)
    f:SetIgnoreParentScale(true)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", anchor, "TOP", 0, 18)
    if what == "kill" then
        -- kill / collect target: the yellow "!" the game uses for quests
        style(f, { type = "avail", trivial = false })
    else
        style(f, { type = what, k = "kill", trivial = false })
    end
    f.m = nil
    fit(f, 30)
    f:Show()
end

function Q:PlateDebug()
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    local tokens = 0
    for i = 1, 40 do if UnitExists("nameplate" .. i) then tokens = tokens + 1 end end
    local cv = function(n) local ok, v = pcall(GetCVar, n); return ok and tostring(v) or "?" end
    SFP:Print("nameplates: " .. #plates .. ", nameplate units: " .. tokens .. ", enemy plates cvar " ..
        cv("nameplateShowEnemies") .. ", quests matched by text: " .. #textQuests)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            local nm = UnitName(unit)
            local f = plateIcons[unit]
            SFP:Print(unit .. " " .. tostring(nm) .. " match=" .. tostring(nameQuests(nm) ~= nil) ..
                " icon=" .. tostring(f and f:IsShown()) .. (f and (" vis=" .. tostring(f:IsVisible())) or ""))
        end
    end
    plates = {}
    for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        local nm = unit and UnitName(unit)
        local f = unit and plateIcons[unit]
        SFP:Print(tostring(unit) .. " " .. tostring(nm) .. " match=" .. tostring(nameQuests(nm) ~= nil) ..
            " icon=" .. tostring(f and f:IsShown()) .. (f and (" w=" .. floor(f:GetWidth()) .. " vis=" .. tostring(f:IsVisible())) or ""))
    end
end

function Q:UpdatePlates()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    -- by token: works whatever the plate list returns (and with nameplate addons)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then updatePlate(unit) end
    end
end

---------------------------------------------------------------------------
-- translucent highlight of the zones that hold your quests (continent / world maps)
---------------------------------------------------------------------------
local zoneSets = { v = -1 }
questZones = function()
    if zoneSets.v == version then return zoneSets end
    zoneSets = { v = version, obj = {}, turn = {} }
    local Z = zoneDB()
    local QD, N, _, O = dbs()
    if not (Z and Z.GetUiMapIdByAreaId and QD) then return zoneSets end
    local function mark(set, qid, kind, ent, own)
        local sp = own or (kind == 1 and safe(N.spawns, ent)) or (O and kind == 2 and safe(O.spawns, ent))
        if type(sp) == "table" then
            for area in pairs(sp) do
                local m = safe(function() return Z:GetUiMapIdByAreaId(area) end)
                if m then
                    local l = set[m]
                    if not l then l = {}; set[m] = l end
                    local have = false
                    for _, q in ipairs(l) do if q == qid then have = true; break end end
                    if not have then l[#l + 1] = qid end
                end
            end
        end
    end
    for qid in pairs(state.inLog) do
        if state.complete[qid] then
            local fb = safe(QD.finishedBy, qid)
            for kind = 1, 2 do for _, ent in ipairs(fb and fb[kind] or {}) do mark(zoneSets.turn, qid, kind, ent) end end
        else
            local tg = targetsOf(qid)
            for _, t in ipairs(tg) do mark(zoneSets.obj, qid, t.kind, t.ent, t.sp) end
            if #tg == 0 then
                local fb = safe(QD.finishedBy, qid)
                for kind = 1, 2 do for _, ent in ipairs(fb and fb[kind] or {}) do mark(zoneSets.turn, qid, kind, ent) end end
            end
        end
    end
    return zoneSets
end

-- called from the world map overlay: tints every zone under the shown map that holds quest work
function Q:DrawZones(mapID)
    if not (Q.enabled and SFP.db.questZones ~= false and SFP.DrawZoneFill and SFP.IsUnderMap) then return end
    local sets = questZones()
    local info = C_Map.GetMapInfo(mapID)
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    if info and info.mapType == zoneType then return end   -- a zone map shows the markers instead
    for zone in pairs(sets.obj) do
        if SFP.IsUnderMap(zone, mapID) then SFP.DrawZoneFill(mapID, zone, 1.0, 0.6, 0.15, 0.17) end
    end
    for zone in pairs(sets.turn) do
        if not sets.obj[zone] and SFP.IsUnderMap(zone, mapID) then SFP.DrawZoneFill(mapID, zone, 0.2, 0.9, 1.0, 0.17) end
    end
end

---------------------------------------------------------------------------
-- control
---------------------------------------------------------------------------
local pending
function Q:Refresh()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        if not Q.enabled then return end
        SFP:Safe("quest state", refreshState)
        SFP:Safe("quest sets", rebuildSets)
        SFP:Safe("quest heads", function() Q:UpdatePlates() end)
        if SFP.RefreshWorldMap then SFP:Safe("quest zones", SFP.RefreshWorldMap) end
        SFP:Safe("quest world map", function() Q:DrawWorldMap() end)
        SFP:Safe("quest minimap", mupdate)
    end)
end

function Q:Debug()
    local QD, N = dbs()
    SFP:Print("Quest markers: enabled=" .. tostring(Q.enabled) .. ", indexed=" .. tostring(indexed) .. ", database=" .. tostring(SFP:HasQuestieDB()))
    local mapID = WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() or C_Map.GetBestMapForUnit("player")
    local Z = zoneDB()
    local area = Z and Z.GetAreaIdByUiMapId and safe(function() return Z:GetAreaIdByUiMapId(mapID) end)
    SFP:Print("map " .. tostring(mapID) .. " -> area " .. tostring(area))
    local n = 0
    for qid in pairs(state.inLog) do
        n = n + 1
        local fb = QD and safe(QD.finishedBy, qid)
        local ob = QD and safe(QD.objectives, qid)
        local nf = (fb and #(fb[1] or {}) or 0) + (fb and #(fb[2] or {}) or 0)
        local no = 0
        for k = 1, 6 do no = no + #((ob and ob[k]) or {}) end
        SFP:Print(("%d %s: %s, finishers %d, objectives %d"):format(qid, questName(qid), state.complete[qid] and "complete" or "open", nf, no))
    end
    SFP:Print(n .. " quests in the log")
    local res = Q:Collect(mapID)
    if res then SFP:Print(("here: %d turn-in, %d objective markers"):format(#res.turnin, #res.obj)) else SFP:Print("here: no markers (not a zone map or no data)") end
end

function Q:SetEnabled(on)
    SFP.db.questMarkers = on and true or false
    Q.enabled = SFP.db.questMarkers and SFP:HasQuestieDB() and true or false
    if Q.enabled then
        buildIndex()
        Q:Refresh()
    else
        Q:DrawWorldMap(); mclear()
    end
end

-- when this addon draws the quests, Questie's own icons are switched off so nothing is drawn twice
function SFP:QuestieIconsOff(silent)
    local Qs, loader = _G.Questie, _G.QuestieLoader
    if not (Qs and Qs.db and Qs.db.profile) then return false end
    local p = Qs.db.profile
    p.enableMapIcons, p.enableMiniMapIcons = false, false
    local quest = loader and loader.ImportModule and safe(function() return loader:ImportModule("QuestieQuest") end)
    if quest then
        pcall(quest.ToggleNotes, quest, false)
    end
    if not silent then self:Print("Questie's map and minimap icons are off: this addon draws the quests now.") end
    return true
end

SFP:OnLogin(function()
    if SFP.db.questMarkers == nil then SFP.db.questMarkers = true end
    if SFP.db.questMinimap == nil then SFP.db.questMinimap = true end
    if SFP.db.questTrivial == nil then SFP.db.questTrivial = false end
    if SFP.db.questHeads == nil then SFP.db.questHeads = true end
    if SFP.db.questZones == nil then SFP.db.questZones = true end
    if SFP.db.questAvailV2 == nil then SFP.db.questAvailV2 = true; SFP.db.questAvail = true end -- untaken quests show again, with Blizzard's own "!"
    Q.enabled = SFP.db.questMarkers and SFP:HasQuestieDB() and true or false
    if not SFP:HasQuestieDB() then
        C_Timer.After(8, function()
            if not SFP:HasQuestieDB() then
                SFP:Print("The quest data did not load (Data/QD_*.lua missing?). Reinstall the addon.")
            end
        end)
        return
    end

    -- world map layer on the map canvas
    if WorldMapFrame and WorldMapFrame.GetCanvas then
        local canvas = WorldMapFrame:GetCanvas()
        layer = CreateFrame("Frame", nil, canvas)
        layer:SetAllPoints(canvas)
        layer:SetFrameLevel(min(canvas:GetFrameLevel() + 3500, 9000))
        if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Q:DrawWorldMap() end) end
        WorldMapFrame:HookScript("OnShow", function() C_Timer.After(0, function() Q:DrawWorldMap() end) end)
        canvas:HookScript("OnSizeChanged", function() Q:DrawWorldMap() end)
    end

    -- friendly monsters only get a nameplate (and so an icon) when the game shows friendly NPC plates
    if SFP.db.questHeads ~= false and not SFP.db.platesSet then
        SFP.db.platesSet = true
        pcall(SetCVar, "nameplateShowFriendlyNPCs", 1)
    end
    local pev = CreateFrame("Frame")
    pcall(pev.RegisterEvent, pev, "NAME_PLATE_UNIT_ADDED")
    pcall(pev.RegisterEvent, pev, "NAME_PLATE_UNIT_REMOVED")
    pcall(pev.RegisterEvent, pev, "UPDATE_MOUSEOVER_UNIT")
    pcall(pev.RegisterEvent, pev, "PLAYER_TARGET_CHANGED")
    pev:SetScript("OnEvent", function(_, event, unit)
        if event == "UPDATE_MOUSEOVER_UNIT" then return SFP:Safe("seen mouseover", function() Q:SeenMonster("mouseover") end) end
        if event == "PLAYER_TARGET_CHANGED" then return SFP:Safe("seen target", function() Q:SeenMonster("target") end) end
        if not Q.enabled or not unit then return end
        if event == "NAME_PLATE_UNIT_ADDED" then updatePlate(unit)
        elseif plateIcons[unit] then plateIcons[unit]:Hide() end
    end)

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_COMPLETE",
        "PLAYER_LEVEL_UP", "UNIT_QUEST_LOG_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function() Q:Refresh() end)

    local acc = 0
    local tick = CreateFrame("Frame")
    tick:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 1 then return end
        acc = 0
        if Q.enabled then SFP:Safe("quest minimap", mupdate) end
    end)

    if Q.enabled then
        C_Timer.After(10, function() buildIndex() end)
        if not SFP.db.questieIconsOffDone then
            SFP.db.questieIconsOffDone = true
            C_Timer.After(14, function() SFP:QuestieIconsOff(false) end)
        end
    end
end)
