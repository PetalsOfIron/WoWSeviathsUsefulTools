-- Seviath's Dungeons & Raids - Encounter Journal lookups: bosses, and loot you haven't collected
-- (mounts, pets, toys, transmog appearances) for dungeons and raids, current and legacy.
local _, ns = SFP_Module("DungeonsRaids")
local D = ns.Data

local function EJReady()
  return EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetEncounterInfoByIndex
end

-- Never touch the journal's selection while the player has it open
local function EJBusy()
  return EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown()
end

local function Strip(name)
  if type(name) ~= "string" then return nil end
  return (name:gsub("%s*%b()%s*$", ""))
end

---------------------------------------------------------------------------
-- Find a dungeon / raid in the Encounter Journal by name
---------------------------------------------------------------------------
local instCache = {}

local function SearchEJ(name, isRaid)
  local prev = EJ_GetCurrentTier and EJ_GetCurrentTier()
  local found
  for tier = EJ_GetNumTiers(), 1, -1 do
    EJ_SelectTier(tier)
    local i = 1
    while true do
      local instID, iname = EJ_GetInstanceByIndex(i, isRaid)
      if not instID then break end
      if iname == name then
        found = { id = instID, tier = tier, name = iname }
        break
      end
      i = i + 1
    end
    if found then break end
  end
  if prev then EJ_SelectTier(prev) end
  return found
end

-- names: candidate names (activity name, activity group name); returns {id, tier, name}
function ns:ResolveInstance(names, isRaid)
  if not EJReady() then return nil end
  for _, n in ipairs(names) do
    n = Strip(ns.Safe(n))
    if n and n ~= "" then
      local key = (isRaid and "R:" or "D:") .. n
      local hit = instCache[key]
      if hit == nil then
        if EJBusy() then return nil end
        hit = SearchEJ(n, isRaid) or false
        instCache[key] = hit
      end
      if hit then return hit end
    end
  end
  return nil
end

local bossCache = {}
function ns:GetBosses(inst)
  if not inst then return {} end
  if bossCache[inst.id] then return bossCache[inst.id] end
  local list, j = {}, 1
  while true do
    local bname, _, encID = EJ_GetEncounterInfoByIndex(j, inst.id)
    if not bname then break end
    list[#list + 1] = { name = bname, id = encID }
    j = j + 1
  end
  if #list > 0 then bossCache[inst.id] = list end
  return list
end

---------------------------------------------------------------------------
-- Every dungeon / raid in the Adventure Guide, Classic through the current
-- expansion, with the expansion (tier) it belongs to - for the pick lists
---------------------------------------------------------------------------
local placeTier = { dungeon = {}, raid = {} }
local ejLoaded = {}

function ns:LoadEJPlaces(kind)
  if ejLoaded[kind] or not placeTier[kind] or not EJReady() or EJBusy() then return end
  local isRaid = kind == "raid"
  local prev = EJ_GetCurrentTier and EJ_GetCurrentTier()
  -- tiers after the current expansion are "Current Season" lists; skip those
  local last = EJ_GetNumTiers()
  if GetServerExpansionLevel then last = math.min(last, GetServerExpansionLevel() + 1) end
  for tier = 1, last do
    EJ_SelectTier(tier)
    local i = 1
    while true do
      local instID, name = EJ_GetInstanceByIndex(i, isRaid)
      if not instID then break end
      if type(name) == "string" and name ~= "" then
        ns.db[kind].known[name] = true
        placeTier[kind][name] = tier
      end
      i = i + 1
    end
  end
  if prev then EJ_SelectTier(prev) end
  ejLoaded[kind] = true
end

function ns:PlaceTier(kind, name)
  return placeTier[kind] and placeTier[kind][name]
end

local tierNames = {}
function ns:TierName(tier)
  if not tierNames[tier] then
    local name = EJ_GetTierInfo and EJ_GetTierInfo(tier)
    tierNames[tier] = (type(name) == "string" and name ~= "") and name or ("Expansion " .. tier)
  end
  return tierNames[tier]
end

---------------------------------------------------------------------------
-- Your saved lockout for a raid (any matching difficulty, old 10/25 too)
---------------------------------------------------------------------------
function ns:GetMyKills(raidName, diff)
  local kills = {}
  local ids = D.DIFF_IDS[diff]
  if not raidName or not ids then return kills end
  local want = {}
  for _, id in ipairs(ids) do want[id] = true end
  for i = 1, GetNumSavedInstances() do
    local name, _, _, difficultyID, locked, _, _, isRaid, _, _, numEncounters = GetSavedInstanceInfo(i)
    if isRaid and locked and name == raidName and want[difficultyID] then
      for j = 1, (numEncounters or 0) do
        local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, j)
        if isKilled and bossName then kills[bossName] = true end
      end
    end
  end
  return kills
end

---------------------------------------------------------------------------
-- Loot scan
---------------------------------------------------------------------------
local lootCache = {}
local pendingRefresh, refreshQueued = false, false

local function NumLoot()
  if C_EncounterJournal and C_EncounterJournal.GetNumLoot then return C_EncounterJournal.GetNumLoot() or 0 end
  if EJ_GetNumLoot then return EJ_GetNumLoot() or 0 end
  return 0
end

local function GetLoot(k)
  if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
    local li = C_EncounterJournal.GetLootInfoByIndex(k)
    if type(li) == "table" then return li.itemID, li.link end
    return nil
  end
  if EJ_GetLootInfoByIndex then
    local _, _, _, _, itemID, link = EJ_GetLootInfoByIndex(k)
    return itemID, link
  end
end

local function Classify(itemID, link, b, bossName)
  -- Mount
  if C_MountJournal and C_MountJournal.GetMountFromItem then
    local mountID = C_MountJournal.GetMountFromItem(itemID)
    if mountID then
      local name, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
      if not isCollected then
        b.mounts = b.mounts + 1
        b.names[#b.names + 1] = "|cffa335ee" .. (name or "Mount") .. "|r (" .. bossName .. ")"
      end
      return
    end
  end
  -- Battle pet
  if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if speciesID then
      local owned = C_PetJournal.GetNumCollectedInfo(speciesID)
      if (owned or 0) == 0 then
        local pname = C_PetJournal.GetPetInfoByItemID(itemID)
        b.pets = b.pets + 1
        b.names[#b.names + 1] = "|cff40c0ff" .. (pname or "Pet") .. "|r (" .. bossName .. ")"
      end
      return
    end
  end
  -- Toy
  if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID) then
    if not PlayerHasToy(itemID) then
      b.toys = b.toys + 1
      local tname = C_ToyBox.GetToyInfo(itemID)
      b.names[#b.names + 1] = "|cffffd040" .. (tname or "Toy") .. "|r (" .. bossName .. ")"
    end
    return
  end
  -- Transmog appearance you can learn and don't have yet
  if C_TransmogCollection and link then
    local _, sourceID = C_TransmogCollection.GetItemInfo(link)
    if sourceID then
      local _, canCollect = C_TransmogCollection.PlayerCanCollectSource(sourceID)
      if canCollect then
        local have
        local info = C_TransmogCollection.GetAppearanceInfoBySource and C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
        if type(info) == "table" then
          have = info.appearanceIsCollected
        else
          have = C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID)
        end
        if not have then b.tmog = b.tmog + 1 end
      end
    end
  end
end

local function Scan(inst, diff)
  local res = { bosses = {}, complete = true, time = GetTime() }
  EJ_SelectTier(inst.tier)
  EJ_SelectInstance(inst.id)
  if diff and EJ_SetDifficulty and EJ_IsValidInstanceDifficulty then
    for _, d in ipairs(D.DIFF_IDS[diff] or {}) do
      if EJ_IsValidInstanceDifficulty(d) then EJ_SetDifficulty(d) break end
    end
  end
  if EJ_ResetLootFilter then EJ_ResetLootFilter() end
  for _, boss in ipairs(ns:GetBosses(inst)) do
    EJ_SelectEncounter(boss.id)
    local b = { mounts = 0, pets = 0, toys = 0, tmog = 0, names = {} }
    for k = 1, NumLoot() do
      local itemID, link = GetLoot(k)
      if itemID then
        if not link then res.complete = false end
        Classify(itemID, link, b, boss.name)
      end
    end
    res.bosses[boss.name] = b
  end
  return res
end

function ns:GetCollectibles(inst, diff)
  if not inst or not ns.db.scanLoot or not EJ_SelectInstance or not EJ_SelectEncounter then return nil end
  local key = inst.id .. ":" .. (diff or "")
  local c = lootCache[key]
  if c and (c.complete or GetTime() - c.time < 3) then return c end
  if EJBusy() then return c end
  local prevTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
  local prevDiff = EJ_GetDifficulty and EJ_GetDifficulty()
  local prevClass, prevSpec
  if EJ_GetLootFilter then prevClass, prevSpec = EJ_GetLootFilter() end
  local ok, res = pcall(Scan, inst, diff)
  if prevClass and EJ_SetLootFilter then pcall(EJ_SetLootFilter, prevClass, prevSpec) end
  if prevDiff and EJ_SetDifficulty then pcall(EJ_SetDifficulty, prevDiff) end
  if prevTier then pcall(EJ_SelectTier, prevTier) end
  if ok and res then
    lootCache[key] = res
    if not res.complete then pendingRefresh = true end
    return res
  end
  return c
end

-- Totals for the bosses still alive for you (skip = set of boss names to leave out)
function ns:SumCollectibles(c, skip)
  if not c then return nil end
  local t = { mounts = 0, pets = 0, toys = 0, tmog = 0, names = {} }
  for name, b in pairs(c.bosses) do
    if not (skip and skip[name]) then
      t.mounts = t.mounts + b.mounts
      t.pets = t.pets + b.pets
      t.toys = t.toys + b.toys
      t.tmog = t.tmog + b.tmog
      for _, n in ipairs(b.names) do t.names[#t.names + 1] = n end
    end
  end
  t.any = t.mounts + t.pets + t.toys + t.tmog
  return t
end

-- Item data arrives a moment later; refresh the open list once it does
ns:On("EJ_LOOT_DATA_RECIEVED", function()
  if not pendingRefresh or refreshQueued then return end
  refreshQueued = true
  C_Timer.After(1.5, function()
    refreshQueued = false
    pendingRefresh = false
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if panel and panel:IsVisible() then ns:Refilter() end
  end)
end)

-- Collecting something changes what's "new"
local function ClearLoot() wipe(lootCache) end
ns:On("NEW_MOUNT_ADDED", ClearLoot)
ns:On("NEW_PET_ADDED", ClearLoot)
ns:On("NEW_TOY_ADDED", ClearLoot)
ns:On("TRANSMOG_COLLECTION_SOURCE_ADDED", ClearLoot)
