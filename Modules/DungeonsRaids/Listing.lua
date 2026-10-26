-- Seviath's Dungeons & Raids - reading, filtering and annotating group finder listings
-- Works for every Premade Groups section: Questing, Delves, Dungeons, Mythic+, Raids (current and legacy), Custom.
local _, ns = SFP_Module("DungeonsRaids")
local D = ns.Data

ns.cache = {}

ns.KIND_LABEL = {
  mplus = "Mythic+", dungeon = "Dungeon", raid = "Raid", delve = "Delve",
  quest = "Questing", custom = "Custom", pvp = "PvP", other = "Other",
}

---------------------------------------------------------------------------
-- Safe API helpers
---------------------------------------------------------------------------
local function Accessible(t)
  if type(t) ~= "table" then return false end
  if canaccesstable and not canaccesstable(t) then return false end
  return true
end

local ROLES = { TANK = true, HEALER = true, DAMAGER = true }

local function MemberInfo(resultID, i)
  if C_LFGList.GetSearchResultPlayerInfo then
    local ok, p = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
    if ok and Accessible(p) then
      local role = ns.Safe(p.assignedRole)
      local class = ns.Safe(p.classFilename) or ns.Safe(p.class)
      -- Field names have shifted between patches; fall back to scanning the values
      if not class or not role then
        for _, v in pairs(p) do
          v = ns.Safe(v)
          if type(v) == "string" then
            if not class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[v] then class = v end
            if not role and ROLES[v] then role = v end
          end
        end
      end
      return role, class
    end
  end
  if C_LFGList.GetSearchResultMemberInfo then
    local ok, role, class = pcall(C_LFGList.GetSearchResultMemberInfo, resultID, i)
    if ok then return ns.Safe(role), ns.Safe(class) end
  end
end

---------------------------------------------------------------------------
-- Which section a listing belongs to
---------------------------------------------------------------------------
local KNOWN_CAT = { [1] = "quest", [2] = "dungeon", [3] = "raid", [6] = "custom" }
local catKind = {}

local function KindForCategory(cat)
  if not cat then return nil end
  if catKind[cat] ~= nil then return catKind[cat] or nil end
  local kind = KNOWN_CAT[cat]
  if not kind and C_LFGList.GetLfgCategoryInfo then
    local ok, ci = pcall(C_LFGList.GetLfgCategoryInfo, cat)
    local name = ok and Accessible(ci) and ns.Safe(ci.name)
    if type(name) == "string" then
      local n = name:lower()
      if n:find("delve") then kind = "delve"
      elseif n:find("raid") then kind = "raid"
      elseif n:find("dungeon") then kind = "dungeon"
      elseif n:find("quest") then kind = "quest"
      elseif n:find("custom") then kind = "custom" end
    end
  end
  catKind[cat] = kind or false
  return kind
end
ns.KindForCategory = KindForCategory

-- The difficulty shown in the listing ("Highmaul (Heroic)") is what players go by,
-- so read the name first and only fall back to the activity flags.
local DIFF_WORDS = {
  { "M", { PLAYER_DIFFICULTY6, "Mythic" } },
  { "H", { PLAYER_DIFFICULTY2, "Heroic" } },
  { "N", { PLAYER_DIFFICULTY1, "Normal" } },
}
function ns.DetectDifficulty(act)
  local name = type(act.fullName) == "string" and act.fullName or ""
  local paren = name:match("%(([^)]*)%)%s*$") or name
  for _, d in ipairs(DIFF_WORDS) do
    for _, word in ipairs(d[2]) do
      if type(word) == "string" and word ~= "" and paren:find(word, 1, true) then return d[1] end
    end
  end
  if act.isMythicActivity then return "M" end
  if act.isHeroicActivity then return "H" end
  return "N"
end

local function MyZone()
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local info = mapID and C_Map.GetMapInfo(mapID)
  return mapID, info and info.name
end

---------------------------------------------------------------------------
-- Analyze one listing
---------------------------------------------------------------------------
function ns:Analyze(resultID)
  local info = C_LFGList.GetSearchResultInfo(resultID)
  if not Accessible(info) then return nil end
  local myClass, myRole = ns.MyClass(), ns.MyRole()
  local activityID = info.activityID or (info.activityIDs and info.activityIDs[1])
  local act = activityID and C_LFGList.GetActivityInfoTable(activityID)
  if act and not Accessible(act) then act = nil end

  local r = {
    id = resultID, info = info, act = act,
    leader = ns.FullName(info.leaderName),
    classes = {}, memberList = {}, present = {}, missing = {}, myAdds = {},
    sameToken = 0, sameArmor = 0, killedCount = 0,
    friends = (info.numBNetFriends or 0) + (info.numCharFriends or 0) + (info.numGuildMates or 0),
    needsMe = true, kind = "other",
  }
  r.age = ns.Safe(info.age)
  r.isNew = r.age and r.age < 120

  local groupName
  if act then
    local catKindHere = KindForCategory(act.categoryID)
    if act.isMythicPlusActivity then
      r.kind = "mplus"
    elseif catKindHere == "custom" then
      r.kind = "custom"
    elseif act.isPvpActivity or act.isRatedPvpActivity then
      r.kind = "pvp"
    else
      r.kind = KindForCategory(act.categoryID)
        or (((act.maxNumPlayers or 0) > 5) and "raid")
        or "other"
    end
    r.diff = ns.DetectDifficulty(act)
    r.maxPlayers = act.maxNumPlayers or 0
    r.full = r.maxPlayers > 0 and (info.numMembers or 0) >= r.maxPlayers
    if act.minLevel and act.minLevel > 0 then
      r.tooLow = UnitLevel("player") < act.minLevel
    end
    if r.kind == "raid" then r.isLegacy = act.isCurrentRaidActivity ~= true end
    groupName = act.groupFinderActivityGroupID and C_LFGList.GetActivityGroupInfo
      and ns.Safe(C_LFGList.GetActivityGroupInfo(act.groupFinderActivityGroupID))
  end
  r.isMPlus = r.kind == "mplus"
  r.isRaid = r.kind == "raid"

  -- Members
  local myToken, myArmor = D.TOKEN[myClass], D.ARMOR[myClass]
  for i = 1, (info.numMembers or 0) do
    local _, class = MemberInfo(resultID, i)
    if class then
      r.memberList[#r.memberList + 1] = class
      r.classes[class] = (r.classes[class] or 0) + 1
      if D.LUST[class] then r.hasLust = true end
      if D.BREZ[class] then r.hasBrez = true end
      for _, b in ipairs(D.BUFFS) do
        if D.Provides(b, class) then r.present[b.key] = true end
      end
      if myToken and D.TOKEN[class] == myToken then r.sameToken = r.sameToken + 1 end
      if myArmor and D.ARMOR[class] == myArmor then r.sameArmor = r.sameArmor + 1 end
    end
  end
  for _, b in ipairs(D.BUFFS) do
    if not r.present[b.key] then
      r.missing[#r.missing + 1] = b
      if D.Provides(b, myClass) then r.myAdds[#r.myAdds + 1] = b end
    end
  end

  -- Open role slots. Groups without role slots (questing, delves) never hide you.
  local counts = C_LFGList.GetSearchResultMemberCounts and C_LFGList.GetSearchResultMemberCounts(resultID)
  if Accessible(counts) then
    r.need = {
      TANK = counts.TANK_REMAINING or 0,
      HEALER = counts.HEALER_REMAINING or 0,
      DAMAGER = counts.DAMAGER_REMAINING or 0,
    }
    r.needTotal = r.need.TANK + r.need.HEALER + r.need.DAMAGER
    if r.needTotal > 0 then r.needsMe = (r.need[myRole] or 0) > 0 end
  end

  -- Leader Mythic+ info
  r.leaderScore = info.leaderOverallDungeonScore or 0
  local ds = info.leaderDungeonScoreInfo
  if Accessible(ds) then
    if ds[1] then ds = ds[1] end
    r.leaderBest = ds.bestRunLevel or 0
    r.leaderTimed = ds.finishedSuccess
  end

  -- Boss progress (raids and dungeons): which bosses this group already killed
  if r.isRaid or r.kind == "dungeon" then
    local killed = C_LFGList.GetSearchResultEncounterInfo and C_LFGList.GetSearchResultEncounterInfo(resultID)
    if not Accessible(killed) then killed = {} end
    r.killedNames = killed
    r.killedCount = #killed
  end

  -- Raid progress and loot you haven't collected
  if r.isRaid then
    local killed = r.killedNames
    local skip = {}
    for _, n in ipairs(killed) do skip[n] = true end
    local inst = ns:ResolveInstance({ act and act.fullName, groupName, act and act.shortName }, true)
    if inst then
      r.instName = inst.name
      -- The game's "current raid" flag isn't reliable; a raid from an older
      -- expansion tier in the Adventure Guide is legacy.
      local curTier = (GetServerExpansionLevel and GetServerExpansionLevel() or 0) + 1
      r.isLegacy = inst.tier < curTier
      local mine = ns:GetMyKills(inst.name, r.diff)
      for n in pairs(mine) do skip[n] = true end
      local bosses = ns:GetBosses(inst)
      if #bosses > 0 then
        local n = 0
        for _, b in ipairs(bosses) do
          if not skip[b.name] then n = n + 1 end
        end
        r.lootable, r.totalBosses = n, #bosses
        r.bossTotal = #bosses
      end
      r.collect = ns:SumCollectibles(ns:GetCollectibles(inst, r.diff), skip)
    end
  elseif r.kind == "dungeon" or r.kind == "mplus" then
    local inst = ns:ResolveInstance({ act and act.fullName, groupName, act and act.shortName }, false)
    if inst then
      r.instName = inst.name
      local bosses = ns:GetBosses(inst)
      if #bosses > 0 then r.bossTotal = #bosses end
      r.collect = ns:SumCollectibles(ns:GetCollectibles(inst, r.kind == "mplus" and "M" or r.diff))
    end
  end

  -- Which delve / dungeon / raid, and delve tier: "The Shadow Enclave (Tier 1)"
  if (r.kind == "delve" or r.kind == "dungeon" or r.kind == "raid" or r.kind == "quest" or r.kind == "mplus") and act and type(act.fullName) == "string" then
    local name, paren = act.fullName:match("^(.-)%s*%(([^)]*)%)%s*$")
    -- Adventure Guide name when we found it, so it matches the pick list
    r.placeName = r.instName or ((name and name ~= "") and name or act.fullName)
    if r.kind == "delve" and paren then r.tier = tonumber(paren:match("(%d+)")) end
    ns.db[r.kind].known[r.placeName] = true
  end

  -- Custom: PvE or PvP ("Custom PvP" / "Custom PvE"), War Mode on or off
  if r.kind == "custom" and act then
    local name = type(act.fullName) == "string" and act.fullName or ""
    r.isPvP = (act.isPvpActivity or act.isRatedPvpActivity or name:find("PvP", 1, true)) and true or false
    r.warMode = ns.Safe(info.isWarMode) == true or name:find(WAR_MODE or "War Mode", 1, true) ~= nil
  end

  -- Questing
  if r.kind == "quest" then
    local qid = ns.Safe(info.questID)
    if qid and qid > 0 then
      r.questID = qid
      local QL = C_QuestLog
      r.onQuest = QL and QL.IsOnQuest and QL.IsOnQuest(qid) or false
      r.questDone = not r.onQuest and QL and QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(qid) or false
      r.isWQ = QL and QL.IsWorldQuest and QL.IsWorldQuest(qid) or false
      if r.isWQ and C_TaskQuest and C_TaskQuest.GetQuestTimeLeftMinutes then
        r.wqLeft = C_TaskQuest.GetQuestTimeLeftMinutes(qid)
      end
    end
    local mapID, zone = MyZone()
    local name = act and act.fullName
    r.inMyZone = (zone and type(name) == "string" and name:find(zone, 1, true) ~= nil) or false
    if not r.inMyZone and r.questID and C_TaskQuest and C_TaskQuest.GetQuestZoneID then
      r.inMyZone = C_TaskQuest.GetQuestZoneID(r.questID) == mapID
    end
  end

  -- History
  if r.leader then
    local tag = ns:TagOf(r.leader)
    r.blocked = tag == "block"
    r.favorite = tag == "fav"
    r.goodLeader = tag == "good"
  end
  return r
end

---------------------------------------------------------------------------
-- Filters
-- Each option is a test. A test can be:
--   hide: ticking the box hides groups that match   ("hides 3" / "would hide 3")
--   show: unticking the box hides groups that match  (difficulty, current/legacy)
--   num:  a number box, active when set              ("hides 3")
--   sort: only reorders                               ("3 groups")
-- Every test is counted for every group, so the window can show what each option does.
---------------------------------------------------------------------------
local function T(kind, key, fail, active) return { type = kind, key = key, fail = fail, active = active } end
local GT0 = function(v) return v > 0 end
local LT99 = function(v) return v < 99 end

local GLOBAL_TESTS = {
  T("hide", "hideAboveMyLevel", function(r) return r.tooLow end),
  T("num", "maxAgeMinutes", function(r, o) return r.age and r.age > o.maxAgeMinutes * 60 end, GT0),
}

local COMMON_TESTS = {
  T("hide", "hideBlocked", function(r) return r.blocked end),
  T("hide", "hideFull", function(r) return r.full end),
  T("hide", "needMyRole", function(r) return not r.needsMe end),
  T("hide", "autoAcceptOnly", function(r) return not r.info.autoAccept end),
  T("hide", "hideAboveMyIlvl", function(r, o, c) return (r.info.requiredItemLevel or 0) > c.ilvl end),
  T("hide", "hideSameClass", function(r, o, c) return r.classes[c.class] ~= nil end),
  T("num", "minMembers", function(r, o) return (r.info.numMembers or 0) < o.minMembers end, GT0),
  T("num", "maxMembers", function(r, o) return (r.info.numMembers or 0) > o.maxMembers end, GT0),
  T("num", "minNewLoot", function(r, o) return r.collect ~= nil and r.collect.any < o.minNewLoot end, GT0),
}

-- "Only groups with something new": Mount / Pet / Toy / Transmog (any ticked one is enough)
local WANT = {
  { key = "wantMount", field = "mounts" },
  { key = "wantPet", field = "pets" },
  { key = "wantToy", field = "toys" },
  { key = "wantTmog", field = "tmog" },
}
local WANT_TESTS = {}
for _, w in ipairs(WANT) do
  WANT_TESTS[#WANT_TESTS + 1] = T("sort", w.key, function(r) return r.collect ~= nil and r.collect[w.field] > 0 end)
end

local KIND_TESTS = {
  mplus = {
    T("num", "minLeaderScore", function(r, o) return (r.leaderScore or 0) < o.minLeaderScore end, GT0),
    T("num", "minLeaderBestLevel", function(r, o) return (r.leaderBest or 0) < o.minLeaderBestLevel end, GT0),
    -- leader has TIMED this dungeon at +min or higher
    T("num", "minTimedLevel", function(r, o) return not (r.leaderTimed and (r.leaderBest or 0) >= o.minTimedLevel) end, GT0),
    -- leader's best timed key here is not above +max (skip leaders running much higher keys)
    T("num", "maxTimedLevel", function(r, o) return r.leaderTimed and (r.leaderBest or 0) > o.maxTimedLevel end, GT0),
    T("hide", "requireLust", function(r, o, c) return not (r.hasLust or D.LUST[c.class]) end),
    T("hide", "requireBrez", function(r, o, c) return not (r.hasBrez or D.BREZ[c.class]) end),
  },
  dungeon = {
    T("show", "diffN", function(r) return r.diff == "N" end),
    T("show", "diffH", function(r) return r.diff == "H" end),
    T("show", "diffM", function(r) return r.diff == "M" end),
    T("hide", "freshOnly", function(r) return r.killedCount > 0 end),
  },
  raid = {
    T("show", "diffN", function(r) return r.diff == "N" end),
    T("show", "diffH", function(r) return r.diff == "H" end),
    T("show", "diffM", function(r) return r.diff == "M" end),
    T("show", "showCurrent", function(r) return not r.isLegacy end),
    T("show", "showLegacy", function(r) return r.isLegacy == true end),
    T("hide", "freshOnly", function(r) return r.killedCount > 0 end),
    T("sort", "highlightMyBuff", function(r) return not r.isLegacy and #r.myAdds > 0 end),
    T("num", "maxKilled", function(r, o) return r.killedCount > o.maxKilled end, LT99),
    T("num", "minLootable", function(r, o) return r.lootable ~= nil and r.lootable < o.minLootable end, GT0),
    T("num", "maxSameToken", function(r, o) return not r.isLegacy and r.sameToken > o.maxSameToken end, LT99),
  },
  delve = {
    T("num", "minTier", function(r, o) return r.tier ~= nil and r.tier < o.minTier end, GT0),
    T("num", "maxTier", function(r, o) return r.tier ~= nil and r.tier > o.maxTier end, GT0),
  },
  custom = {
    T("show", "showPvE", function(r) return not r.isPvP end),
    T("show", "showPvP", function(r) return r.isPvP == true end),
    T("show", "showWarModeOn", function(r) return r.warMode == true end),
    T("show", "showWarModeOff", function(r) return not r.warMode end),
  },
  quest = {
    T("show", "showWQ", function(r) return r.isWQ == true end),
    T("show", "showQuests", function(r) return r.questID ~= nil and not r.isWQ end),
    T("show", "showOther", function(r) return r.questID == nil end),
    T("hide", "hideCompleted", function(r) return r.questDone == true end),
    T("hide", "onMyQuests", function(r) return r.questID ~= nil and not r.onQuest end),
    T("hide", "myZoneOnly", function(r) return not r.inMyZone end),
  },
}

-- key -> test, so the window knows how to describe each option
ns.TESTS = {}
for _, list in ipairs({ GLOBAL_TESTS, COMMON_TESTS, KIND_TESTS.mplus, KIND_TESTS.dungeon, KIND_TESTS.raid, KIND_TESTS.delve, KIND_TESTS.custom, KIND_TESTS.quest, WANT_TESTS }) do
  for _, t in ipairs(list) do ns.TESTS[t.key] = ns.TESTS[t.key] or t end
end

function ns.TestActive(t, o)
  local v = o[t.key]
  if t.type == "hide" then return v == true end
  if t.type == "show" then return v == false end
  if t.type == "num" then return type(v) == "number" and t.active(v) end
  return false
end

-- counts: "kind.key" -> how many groups ONE click on that option changes in the
-- visible list. An option that is on counts groups only it is hiding; an option
-- that is off counts groups that are visible now and would disappear.
function ns:Passes(r, counts)
  local db = ns.db
  local ctx = { ilvl = ns.MyIlvl(), class = ns.MyClass() }
  local matches, hiders = {}, 0
  local function run(tests, o, prefix)
    for _, t in ipairs(tests) do
      if o[t.key] ~= nil then
        local on = ns.TestActive(t, o)
        if t.type ~= "num" or on then
          local ok, matched = pcall(t.fail, r, o, ctx)
          if ok and matched then
            local hides = on and t.type ~= "sort"
            matches[#matches + 1] = { prefix .. t.key, hides }
            if hides then hiders = hiders + 1 end
          end
        end
      end
    end
  end
  run(GLOBAL_TESTS, db, "global.")
  local o = db[r.kind]
  if type(o) == "table" and o.enabled then
    run(COMMON_TESTS, o, r.kind .. ".")
    if KIND_TESTS[r.kind] then run(KIND_TESTS[r.kind], o, r.kind .. ".") end
    if o.wantMount ~= nil then
      run(WANT_TESTS, o, r.kind .. ".")
      -- any ticked type is enough; groups whose loot couldn't be read stay visible
      local anyWanted, has = false, false
      for _, w in ipairs(WANT) do
        if o[w.key] then
          anyWanted = true
          if r.collect and r.collect[w.field] > 0 then has = true end
        end
      end
      if anyWanted and r.collect and not has then hiders = hiders + 1 end
    end
    -- Delves / dungeons / raids you ticked in the list (none ticked = all)
    if o.picked and r.placeName and next(o.picked) and not o.picked[r.placeName] then hiders = hiders + 1 end
  end
  if counts then
    for _, m in ipairs(matches) do
      -- on: count it if nothing else is hiding this group; off: count it if the group is visible now
      if (m[2] and hiders == 1) or (not m[2] and hiders == 0) then
        counts[m[1]] = (counts[m[1]] or 0) + 1
      end
    end
  end
  return hiders == 0
end

function ns:Score(r)
  local s = 0
  if r.favorite then s = s + 100 end
  if r.collect and r.collect.mounts > 0 then s = s + 30 end
  if r.goodLeader then s = s + 20 end
  if r.onQuest then s = s + 15 end
  s = s + 10 * (r.friends or 0)
  if r.collect then s = s + math.min(r.collect.pets + r.collect.toys + r.collect.tmog, 10) end
  if r.inMyZone then s = s + 5 end
  if r.isRaid and not r.isLegacy and ns.db.raid.highlightMyBuff and #r.myAdds > 0 then s = s + 5 end
  if r.isNew then s = s + 2 end
  return s
end

function ns:FilterResults(results)
  ns.cache = {}
  ns.matchCounts = {}
  ns.placeCounts = { delve = {}, dungeon = {}, raid = {}, quest = {}, mplus = {} }
  local keep = {}
  for idx, id in ipairs(results) do
    local ok, r = pcall(ns.Analyze, ns, id)
    if not ok then r = nil end
    if r then
      ns.cache[id] = r
      if r.placeName and ns.placeCounts[r.kind] then
        ns.placeCounts[r.kind][r.placeName] = (ns.placeCounts[r.kind][r.placeName] or 0) + 1
      end
    end
    if not r or ns:Passes(r, ns.matchCounts) then
      keep[#keep + 1] = { id = id, idx = idx, score = r and ns:Score(r) or 0 }
    end
  end
  if ns.db.favoritesFirst then
    table.sort(keep, function(a, b)
      if a.score ~= b.score then return a.score > b.score end
      return a.idx < b.idx
    end)
  end
  local out = {}
  for i, k in ipairs(keep) do out[i] = k.id end
  ns.hiddenCount = #results - #out
  return out
end

-- Blizzard rebuilds panel.results on every search/refresh; we filter a copy and redraw.
local function FilterPanel(panel)
  if not ns.db or not panel or type(panel.results) ~= "table" then return end
  ns.originalResults = {}
  for i, id in ipairs(panel.results) do ns.originalResults[i] = id end
  ns:LoadPlaces(panel.categoryID)
  if ns.UI and ns.UI.SyncTab then ns.UI:SyncTab() end
  if not ns.db.enabled then ns.cache = {} ns.hiddenCount = 0 return end
  local filtered = ns:FilterResults(ns.originalResults)
  panel.results = filtered
  panel.totalResults = #filtered
  LFGListSearchPanel_UpdateResults(panel)
  if ns.UI and ns.UI.UpdateStatus then ns.UI:UpdateStatus() end
end

-- Every delve / dungeon the game offers in this section, so the pick list is complete
local loadedCats = {}
function ns:LoadPlaces(cat)
  local kind = cat and KindForCategory(cat)
  if not cat or loadedCats[cat] or (kind ~= "delve" and kind ~= "dungeon" and kind ~= "raid" and kind ~= "quest") then return end
  if not C_LFGList.GetAvailableActivities then return end
  local ok, ids = pcall(C_LFGList.GetAvailableActivities, cat)
  if not ok or type(ids) ~= "table" then return end
  loadedCats[cat] = true
  for _, aid in ipairs(ids) do
    local act = C_LFGList.GetActivityInfoTable(aid)
    if Accessible(act) and type(act.fullName) == "string" then
      local name = act.fullName:match("^(.-)%s*%([^)]*%)%s*$")
      name = (name and name ~= "") and name or act.fullName
      if act.isMythicPlusActivity then
        ns.db.mplus.known[name] = true
      else
        ns.db[kind].known[name] = true
      end
    end
  end
  if ns.UI and ns.UI.RefreshPickers then ns.UI:RefreshPickers() end
end

ns:RequestHook("LFGListSearchPanel_UpdateResultList", FilterPanel)

-- Re-apply filters to the current list without a new search
function ns:Refilter()
  local panel = LFGListFrame and LFGListFrame.SearchPanel
  if not panel or InCombatLockdown() then return false end
  -- Same path as Blizzard's refresh: re-read the current results, run our filter
  -- (FilterPanel hook) and redraw the list. No new server search is sent.
  if panel:IsVisible() and LFGListSearchPanel_UpdateResultList then
    LFGListSearchPanel_UpdateResultList(panel)
    if ns.UI and ns.UI.UpdateStatus then ns.UI:UpdateStatus() end
    return true
  end
  if not ns.originalResults then return false end
  local src = ns.originalResults
  local filtered = src
  if ns.db.enabled then filtered = ns:FilterResults(src) else ns.hiddenCount = 0 end
  panel.results = filtered
  panel.totalResults = #filtered
  LFGListSearchPanel_UpdateResults(panel)
  if ns.UI and ns.UI.UpdateStatus then ns.UI:UpdateStatus() end
  return true
end

---------------------------------------------------------------------------
-- Tags on each listing row
---------------------------------------------------------------------------
local function Colored(hex, text) return "|cff" .. hex .. text .. "|r" end

-- "FRESH" (no bosses dead) or "STARTED 3/9" (group already killed some)
local function ProgressTag(parts, r)
  if r.killedCount == 0 then
    parts[#parts + 1] = Colored("40ff60", "FRESH")
  else
    parts[#parts + 1] = Colored("ffb040", "STARTED " .. r.killedCount .. (r.bossTotal and ("/" .. r.bossTotal) or ""))
  end
end

local function CollectTags(parts, c)
  if not c then return end
  if c.mounts > 0 then parts[#parts + 1] = Colored("a335ee", "MOUNT") end
  if c.pets > 0 then parts[#parts + 1] = Colored("40c0ff", "PET") end
  if c.toys > 0 then parts[#parts + 1] = Colored("ffd040", "TOY") end
  if c.tmog > 0 then parts[#parts + 1] = Colored("ff80ff", c.tmog .. " tm") end
end

function ns:ShortTags(r)
  local parts = {}
  if r.leader then
    local t = ns:TagShortFor(r.leader)
    if t ~= "" then parts[#parts + 1] = t end
  end
  if r.isNew then parts[#parts + 1] = Colored("40ff60", "NEW") end
  if r.kind ~= "raid" and #r.memberList > 0 and #r.memberList <= 5 then
    local icons = {}
    for _, class in ipairs(r.memberList) do icons[#icons + 1] = D.ClassIcon(class, 12) end
    parts[#parts + 1] = table.concat(icons, "")
  end
  if r.kind == "mplus" then
    parts[#parts + 1] = Colored(r.hasLust and "40ff60" or "ff5050", "BL")
    parts[#parts + 1] = Colored(r.hasBrez and "40ff60" or "ff5050", "BR")
    CollectTags(parts, r.collect)
  elseif r.kind == "dungeon" then
    ProgressTag(parts, r)
    CollectTags(parts, r.collect)
  elseif r.kind == "raid" then
    ProgressTag(parts, r)
    if not r.isLegacy then
      for _, b in ipairs(r.myAdds) do parts[#parts + 1] = Colored("40ff60", "+" .. b.short) end
      if r.sameToken > 0 then parts[#parts + 1] = Colored("ffb040", r.sameToken .. " tok") end
    end
    CollectTags(parts, r.collect)
  elseif r.kind == "quest" then
    if r.onQuest then parts[#parts + 1] = Colored("40ff60", "ON QUEST")
    elseif r.questDone then parts[#parts + 1] = Colored("888888", "DONE") end
    if r.isWQ then parts[#parts + 1] = Colored("ffd040", "WQ") end
    if r.inMyZone then parts[#parts + 1] = Colored(ns.CYAN_HEX, "HERE") end
  end
  if r.info.autoAccept then parts[#parts + 1] = Colored("40ff60", "AUTO") end
  if r.friends > 0 then parts[#parts + 1] = Colored("80c0ff", r.friends .. " fr") end
  return table.concat(parts, " ")
end

function ns:AddProgressLines(tooltip, r)
  if r.killedCount == 0 then
    tooltip:AddLine("Fresh run - no bosses killed yet", 0.25, 1, 0.4)
  else
    tooltip:AddLine("Already started - " .. r.killedCount .. (r.bossTotal and (" of " .. r.bossTotal) or "") .. " bosses killed:", 1, 0.7, 0.25)
    for i, name in ipairs(r.killedNames or {}) do
      if i > 8 then tooltip:AddLine("   ...", 0.7, 0.7, 0.7) break end
      tooltip:AddLine("   " .. tostring(name), 0.7, 0.7, 0.7)
    end
  end
end

local function AgeText(sec)
  if not sec then return nil end
  if sec < 60 then return "just now" end
  if sec < 3600 then return math.floor(sec / 60) .. " min ago" end
  return string.format("%dh %dm ago", math.floor(sec / 3600), math.floor(sec % 3600 / 60))
end

local function AddTooltip(tooltip, resultID)
  if not ns.db or not ns.db.annotate or not tooltip or not resultID then return end
  local r = ns.cache[resultID]
  if not r then
    local ok, res = pcall(ns.Analyze, ns, resultID)
    r = ok and res or nil
  end
  if not r then return end
  local function YN(v) return v and "|cff40ff60yes|r" or "|cffff5050no|r" end
  tooltip:AddLine(" ")
  tooltip:AddLine("Seviath's Dungeons & Raids - " .. (ns.KIND_LABEL[r.kind] or ""), unpack(ns.CYAN))
  if r.leader then
    local rec = ns:GetPlayer(r.leader)
    if rec and rec.tag then
      tooltip:AddLine("Leader: " .. ns:TagLabel(rec.tag) .. ((rec.note and rec.note ~= "") and (" - " .. rec.note) or ""), 1, 1, 1, true)
    end
    if rec and (rec.runs or 0) > 0 then
      tooltip:AddLine("You've grouped with the leader " .. rec.runs .. "x", 0.8, 0.8, 0.8)
    end
  end
  if r.age then tooltip:AddLine("Listed " .. AgeText(r.age), 0.8, 0.8, 0.8) end
  if #r.memberList > 0 then
    local icons = {}
    for i, class in ipairs(r.memberList) do
      if i > 20 then icons[#icons + 1] = "..." break end
      icons[#icons + 1] = D.ClassIcon(class, 14)
    end
    tooltip:AddLine("Members: " .. table.concat(icons, ""), 1, 1, 1, true)
  end
  local usesRoles = r.kind == "dungeon" or r.kind == "mplus" or r.kind == "custom" or (r.kind == "raid" and not r.isLegacy)
  if r.kind == "delve" and r.placeName then
    tooltip:AddLine("Delve: " .. r.placeName .. (r.tier and ("  -  Tier " .. r.tier) or ""), 1, 1, 1)
  end
  if usesRoles and r.need and r.needTotal > 0 then
    tooltip:AddLine(string.format("Still needs: %d tank, %d healer, %d DPS", r.need.TANK, r.need.HEALER, r.need.DAMAGER), 1, 1, 1)
  end
  if r.kind == "mplus" then
    tooltip:AddLine("Leader rating: " .. (r.leaderScore or 0), 1, 1, 1)
    if r.leaderBest and r.leaderBest > 0 then
      tooltip:AddLine("Leader best here: +" .. r.leaderBest .. (r.leaderTimed and " (timed)" or " (not timed)"), 1, 1, 1)
    end
    tooltip:AddLine("Bloodlust: " .. YN(r.hasLust) .. "   Battle res: " .. YN(r.hasBrez), 1, 1, 1)
  elseif r.kind == "dungeon" then
    tooltip:AddLine("Difficulty: " .. (D.DIFF_LABEL[r.diff] or "?"), 1, 1, 1)
    ns:AddProgressLines(tooltip, r)
  elseif r.kind == "raid" then
    tooltip:AddLine((D.DIFF_LABEL[r.diff] or "") .. (r.isLegacy and " (legacy)" or ""), 1, 1, 1)
    ns:AddProgressLines(tooltip, r)
    if r.lootable then
      tooltip:AddLine("Bosses with loot for you: " .. r.lootable .. "/" .. r.totalBosses, unpack(ns.CYAN))
    end
    if not r.isLegacy then
      if #r.missing > 0 then
        local names = {}
        for _, b in ipairs(r.missing) do names[#names + 1] = b.short end
        tooltip:AddLine("Missing raid buffs: " .. table.concat(names, ", "), 1, 0.8, 0.3, true)
      end
      if #r.myAdds > 0 then
        local names = {}
        for _, b in ipairs(r.myAdds) do names[#names + 1] = b.name end
        tooltip:AddLine("You would bring: " .. table.concat(names, ", "), 0.25, 1, 0.4, true)
      end
      tooltip:AddLine("Same tier token as you: " .. r.sameToken .. "   Same armor: " .. r.sameArmor, 1, 1, 1)
    end
  elseif r.kind == "quest" then
    if r.questID then
      tooltip:AddLine("Quest in your log: " .. YN(r.onQuest) .. (r.questDone and "   |cff888888(already completed)|r" or ""), 1, 1, 1)
      if r.isWQ then
        tooltip:AddLine("World quest" .. (r.wqLeft and (" - " .. r.wqLeft .. " min left") or ""), 1, 0.82, 0.25)
      end
    end
    tooltip:AddLine("In your zone: " .. YN(r.inMyZone), 1, 1, 1)
  end
  local c = r.collect
  if c then
    if c.any > 0 then
      tooltip:AddLine("Not collected yet" .. (r.isRaid and " (bosses still alive for you)" or "") .. ":", 1, 0.5, 1)
      for i, n in ipairs(c.names) do
        if i > 6 then tooltip:AddLine("  ...", 1, 1, 1) break end
        tooltip:AddLine("  " .. n, 1, 1, 1)
      end
      if c.tmog > 0 then tooltip:AddLine("  |cffff80ff" .. c.tmog .. " transmog appearances|r", 1, 1, 1) end
    else
      tooltip:AddLine("Nothing new to collect here", 0.6, 0.6, 0.6)
    end
  end
  if r.info.autoAccept then tooltip:AddLine("Auto-accept: joins instantly", 0.25, 1, 0.4) end
  if r.friends > 0 then tooltip:AddLine("Friends / guild in group: " .. r.friends, 0.5, 0.75, 1) end
  if r.tooLow then tooltip:AddLine("Above your level", 1, 0.3, 0.3) end
  tooltip:Show()
end

ns:RequestHook("LFGListSearchEntry_Update", function(entry)
  if not entry then return end
  if not entry.SDRHooked then
    entry.SDRHooked = true
    entry:HookScript("OnEnter", function(self)
      if GameTooltip:IsOwned(self) then AddTooltip(GameTooltip, self.resultID) end
    end)
  end
  if not ns.db or not ns.db.annotate then
    if entry.SDRText then entry.SDRText:SetText("") end
    return
  end
  local id = entry.resultID
  if not id then return end
  local r = ns.cache[id]
  if not r then
    local ok, res = pcall(ns.Analyze, ns, id)
    r = ok and res or nil
  end
  if not entry.SDRText then
    -- Bottom line of the row, right side: free space next to the playstyle text,
    -- so the tags never cover the group or activity name
    local fs = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("BOTTOMLEFT", entry, "BOTTOMLEFT", 88, 4)
    if entry.DataDisplay then
      fs:SetPoint("RIGHT", entry.DataDisplay, "LEFT", -2, 0)
    else
      fs:SetPoint("RIGHT", entry, "RIGHT", -110, 0)
    end
    fs:SetHeight(12)
    fs:SetJustifyH("RIGHT")
    fs:SetWordWrap(false)
    entry.SDRText = fs
  end
  entry.SDRText:SetText(r and ns:ShortTags(r) or "")
end)
