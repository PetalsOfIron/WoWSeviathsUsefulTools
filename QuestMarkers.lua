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

local function dbs() return _G.QuestDB, _G.NpcDB, _G.ItemDB, _G.ObjectDB end
local function safe(fn, ...)
    if not fn then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

local Q = {}
SFP.QuestMarkers = Q

local version = 0                    -- bumped whenever the quest state changes
local state = { inLog = {}, complete = {}, done = {}, level = 1, raceMask = nil, classMask = nil }
local startIdx, finishIdx = {}, {}   -- [areaID] = flat { questID, entityID, kind, ... } (kind 1 npc, 2 object)
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
    local lib = _G.LibQuestieDB
    local _, classFile = UnitClass("player")
    local raceID = select(3, UnitRace("player"))
    if lib and lib.Enum then
        state.raceMask = lib.Enum.raceMaskById and lib.Enum.raceMaskById[raceID]
        state.classMask = lib.Enum.classKeys and lib.Enum.classKeys[classFile]
    end
    -- quest log
    wipe(state.inLog); wipe(state.complete)
    local modern = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo
    local n = modern and C_QuestLog.GetNumQuestLogEntries() or (GetNumQuestLogEntries and (GetNumQuestLogEntries())) or 0
    for i = 1, n do
        local qid, header, isComplete
        if modern then
            local info = C_QuestLog.GetInfo(i)
            if info then qid, header = info.questID, info.isHeader end
            if qid and C_QuestLog.IsComplete then isComplete = C_QuestLog.IsComplete(qid) end
        elseif GetQuestLogTitle then
            local _, _, _, isHeader, _, comp, _, questID = GetQuestLogTitle(i)
            qid, header, isComplete = questID, isHeader, (comp == 1)
        end
        if qid and not header then
            state.inLog[qid] = true
            if isComplete then state.complete[qid] = true end
        end
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

-- quests whose objectives involve this monster (for its tooltip)
function SFP:QuestObjectiveNpc(npcID)
    if not Q.enabled then return nil end
    for qid in pairs(state.inLog) do if not state.complete[qid] then targetsOf(qid) end end
    return objNpc[npcID]
end

---------------------------------------------------------------------------
-- collecting what to draw on one map
---------------------------------------------------------------------------
local function coordsOf(kind, ent, area, limit)
    local _, N, _, O = dbs()
    local sp = kind == 1 and safe(N.spawns, ent) or (O and safe(O.spawns, ent))
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

local function entName(kind, ent)
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
    local QD = dbs()
    local res = { avail = {}, turnin = {}, obj = {}, area = area }
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
            for _, t in ipairs(targetsOf(qid)) do
                for _, c in ipairs(coordsOf(t.kind, t.ent, area, 10)) do
                    local cell = floor(c[1] * 120) .. ":" .. floor(c[2] * 120) .. ":" .. qid .. t.k
                    if not seen[cell] and n < 60 then
                        seen[cell] = true; n = n + 1
                        res.obj[#res.obj + 1] = { q = qid, k = t.k, ent = t.ent, kind = t.kind, x = c[1], y = c[2], text = t.text }
                    end
                end
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
    avail  = { ring = { 1.0, 0.82, 0.2 }, glyph = "!", gcolor = { 1.0, 0.9, 0.4 } },
    gray   = { ring = { 0.6, 0.6, 0.6 }, glyph = "!", gcolor = { 0.8, 0.8, 0.8 } },
    turnin = { ring = { 0.1, 0.9, 1.0 }, glyph = "?", gcolor = { 0.6, 1.0, 1.0 } },
    kill   = { tex = RAID .. "8", ring = { 1.0, 0.3, 0.3 } },
    loot   = { tex = RAID .. "3", ring = { 0.4, 1.0, 0.5 } },
    obj    = { tex = RAID .. "6", ring = { 0.4, 0.7, 1.0 } },
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

local function style(f, m)
    local st
    if m.type == "avail" then st = m.trivial and STYLE.gray or STYLE.avail
    elseif m.type == "turnin" then st = STYLE.turnin
    else st = STYLE[m.k] or STYLE.kill end
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
        if IsControlKeyDown() and self.m and self.mapID and SFP.SetWaypoint then
            SFP:SetWaypoint(self.mapID, self.m.x, self.m.y, questName(self.m.q))
        end
    end)
end

local function markersOf(res)
    local out = {}
    for _, m in ipairs(res.avail) do m.type = "avail"; out[#out + 1] = m end
    for _, m in ipairs(res.turnin) do m.type = "turnin"; out[#out + 1] = m end
    for _, m in ipairs(res.obj) do m.type = "obj"; out[#out + 1] = m end
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

function Q:DrawWorldMap()
    if not layer then return end
    for i = 1, #wpool do wpool[i]:Hide() end
    wused = 0
    if not Q.enabled or not WorldMapFrame:IsShown() then return end
    local mapID = WorldMapFrame:GetMapID()
    local res = self:Collect(mapID)
    if not res then return end
    local w, h = layer:GetWidth(), layer:GetHeight()
    if w <= 0 then return end
    local size = max(14, 20 / canvasScale())
    for _, m in ipairs(markersOf(res)) do
        wused = wused + 1
        local f = wpool[wused]
        if not f then f = newIcon(layer); wire(f); wpool[wused] = f end
        f.mapID = mapID
        style(f, m)
        local s = (m.type == "obj") and size * 0.8 or size
        f:SetSize(s, s)
        f.core:SetSize(s - 4, s - 4)
        f.pic:SetSize(s - 6, s - 6)
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
            style(f, m)
            f:SetSize(15, 15); f.core:SetSize(11, 11); f.pic:SetSize(9, 9)
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
        SFP:Safe("quest world map", function() Q:DrawWorldMap() end)
        SFP:Safe("quest minimap", mupdate)
    end)
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
    if SFP.db.questAvail == nil then SFP.db.questAvail = false end -- only quests you have picked up
    Q.enabled = SFP.db.questMarkers and SFP:HasQuestieDB() and true or false
    if not SFP:HasQuestieDB() then return end

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
