-- SeviathsUsefulTools - quest database (own copy)
--
-- The quest, monster, object and item data of Mists of Pandaria shipped with this addon
-- (Data/QD_*.lua, generated from the QuestieDB database - GPL-3.0, thanks to the Questie team
-- and contributors). No other addon is needed. Records are stored as strings and decoded on demand.
--
-- SFP.QDB.Quest / Npc / Item / Object / Zone / Enum offer the same calls the rest of the addon uses.

local _, SFP = ...

local QD = SFP.QD
if not (QD and QD.q) then return end

local SEP, SEC, REC = "\031", "\029", "\030"
local find, sub, tonumber = string.find, string.sub, tonumber

local function split(s, sep)
    local out, i = {}, 1
    while true do
        local a, b = find(s, sep, i, true)
        if not a then out[#out + 1] = sub(s, i); break end
        out[#out + 1] = sub(s, i, a - 1)
        i = b + 1
    end
    return out
end

local function nums(s)
    if not s or s == "" then return nil end
    local out = {}
    for n in s:gmatch("%d+") do out[#out + 1] = tonumber(n) end
    return #out > 0 and out or nil
end

local function num(s) return (s and s ~= "") and tonumber(s) or nil end

local function ids(tbl)
    local list = {}
    for k in pairs(tbl) do list[#list + 1] = k end
    table.sort(list)
    return list
end

local fields = {}   -- decoded field arrays, per table and id
local function rec(kind, id)
    local c = fields[kind]
    if not c then c = {}; fields[kind] = c end
    local r = c[id]
    if r then return r end
    local raw = QD[kind][id]
    if not raw then return nil end
    r = split(raw, SEP)
    c[id] = r
    return r
end

local DB = {}
SFP.QDB = DB

---------------------------------------------------------------------------
-- quests
---------------------------------------------------------------------------
local Quest = {}
DB.Quest = Quest
local questIds
function Quest.GetAllIds() questIds = questIds or ids(QD.q); return questIds end
function Quest.name(id) local r = rec("q", id); return r and r[1] ~= "" and r[1] or nil end
function Quest.requiredLevel(id) local r = rec("q", id); return r and num(r[2]) end
function Quest.questLevel(id) local r = rec("q", id); return r and num(r[3]) end
function Quest.requiredRaces(id) local r = rec("q", id); return r and num(r[4]) end
function Quest.requiredClasses(id) local r = rec("q", id); return r and num(r[5]) end
function Quest.requiredMaxLevel(id) local r = rec("q", id); return r and num(r[6]) end
function Quest.zoneOrSort(id) local r = rec("q", id); return r and num(r[7]) end
function Quest.nextQuestInChain(id) local r = rec("q", id); return r and num(r[8]) end
function Quest.availableUntilCompleted(id) local r = rec("q", id); return r and num(r[9]) end
function Quest.startedBy(id)
    local r = rec("q", id)
    if not r then return nil end
    return { nums(r[10]), nums(r[11]), nums(r[12]) }
end
function Quest.finishedBy(id)
    local r = rec("q", id)
    if not r then return nil end
    return { nums(r[13]), nums(r[14]) }
end
function Quest.preQuestGroup(id) local r = rec("q", id); return r and nums(r[15]) end
function Quest.preQuestSingle(id) local r = rec("q", id); return r and nums(r[16]) end
function Quest.exclusiveTo(id) local r = rec("q", id); return r and nums(r[17]) end
function Quest.requiredSkill(id)
    local r = rec("q", id)
    if not r or r[18] == "" then return nil end
    local a, b = r[18]:match("(%d+):(%d+)")
    return a and { tonumber(a), tonumber(b) } or nil
end
function Quest.objectivesText(id)
    local r = rec("q", id)
    if not r or r[19] == "" then return nil end
    return split(r[19], REC)
end
function Quest.objectives(id)
    local r = rec("q", id)
    if not r then return nil end
    local out = {}
    local secs = split(r[20] or "", SEC)
    local function entries(s, withCount)
        if not s or s == "" then return nil end
        local list = {}
        for _, e in ipairs(split(s, ";")) do
            local a = split(e, "~")
            list[#list + 1] = { tonumber(a[1]), a[2] ~= "" and a[2] or nil, num(a[3]) }
        end
        return list
    end
    out[1] = entries(secs[1])
    out[2] = entries(secs[2])
    out[3] = entries(secs[3])
    if secs[4] and secs[4] ~= "" then
        local list = {}
        for _, e in ipairs(split(secs[4], ";")) do
            local a = split(e, "~")
            list[#list + 1] = { nums(a[1]), a[2] ~= "" and a[2] or nil }
        end
        out[5] = list
    end
    return out
end

---------------------------------------------------------------------------
-- monsters and NPCs
---------------------------------------------------------------------------
local Npc = {}
DB.Npc = Npc
local npcIds
function Npc.GetAllIds() npcIds = npcIds or ids(QD.n); return npcIds end
function Npc.name(id) local r = rec("n", id); return r and r[1] or nil end
function Npc.minLevel(id) local r = rec("n", id); return r and num(r[2]) end
function Npc.maxLevel(id) local r = rec("n", id); return r and num(r[3]) end
function Npc.rank(id) local r = rec("n", id); return r and num(r[4]) end
function Npc.zoneID(id) local r = rec("n", id); return r and num(r[5]) end
function Npc.subName(id) local r = rec("n", id); return r and r[6] ~= "" and r[6] or nil end

local function parseSpawns(s)
    if not s or s == "" then return nil end
    local out = {}
    for _, part in ipairs(split(s, ";")) do
        local a, rest = part:match("^(%d+):(.*)$")
        if a then
            local pts, xs = {}, {}
            for v in rest:gmatch("[%d%.]+") do xs[#xs + 1] = tonumber(v) end
            for i = 1, #xs - 1, 2 do pts[#pts + 1] = { xs[i], xs[i + 1] } end
            out[tonumber(a)] = pts
        end
    end
    return next(out) and out or nil
end
local spawnCache = { n = {}, o = {} }
local function spawnsOf(kind, id, idx)
    local c = spawnCache[kind]
    local v = c[id]
    if v ~= nil then return v or nil end
    local r = rec(kind, id)
    v = r and parseSpawns(r[idx]) or false
    c[id] = v
    return v or nil
end
function Npc.spawns(id) return spawnsOf("n", id, 7) end

local startsBy, endsBy
local function buildQuestGivers()
    startsBy, endsBy = {}, {}
    for _, qid in ipairs(Quest.GetAllIds()) do
        local sb, fb = Quest.startedBy(qid), Quest.finishedBy(qid)
        for _, npc in ipairs(sb and sb[1] or {}) do
            local l = startsBy[npc]; if not l then l = {}; startsBy[npc] = l end
            l[#l + 1] = qid
        end
        for _, npc in ipairs(fb and fb[1] or {}) do
            local l = endsBy[npc]; if not l then l = {}; endsBy[npc] = l end
            l[#l + 1] = qid
        end
    end
end
function Npc.questStarts(id) if not startsBy then buildQuestGivers() end return startsBy[id] end
function Npc.questEnds(id) if not startsBy then buildQuestGivers() end return endsBy[id] end

---------------------------------------------------------------------------
-- objects and items
---------------------------------------------------------------------------
local Object = {}
DB.Object = Object
function Object.GetAllIds() return ids(QD.o) end
function Object.name(id) local r = rec("o", id); return r and r[1] or nil end
function Object.spawns(id) return spawnsOf("o", id, 2) end

local Item = {}
DB.Item = Item
local itemIds
function Item.GetAllIds() itemIds = itemIds or ids(QD.i); return itemIds end
function Item.name(id) local r = rec("i", id); return r and r[1] ~= "" and r[1] or nil end
function Item.npcDrops(id) local r = rec("i", id); return r and nums(r[2]) end
function Item.objectDrops(id) local r = rec("i", id); return r and nums(r[3]) end
function Item.vendors(id) local r = rec("i", id); return r and nums(r[4]) end

---------------------------------------------------------------------------
-- zones and masks
---------------------------------------------------------------------------
local Zone = { dungeons = QD.dungeons }
DB.Zone = Zone
function Zone:GetUiMapIdByAreaId(area) return QD.areaToMap and QD.areaToMap[area] end
function Zone:GetAreaIdByUiMapId(map) return QD.mapToArea and QD.mapToArea[map] end
function Zone:GetDungeons() return QD.dungeons end

DB.Enum = { raceMaskById = QD.raceMask or {}, classKeys = QD.classMask or {} }

function SFP:HasQuestData() return DB ~= nil and QD.q ~= nil end
SFP.HasQuestieDB = SFP.HasQuestData   -- older name used across the addon
