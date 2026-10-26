-- Seviath's Codex — indexers
-- Everything here is read live from the game client's own journals, so it is
-- always current for the patch you're playing and needs no shipped database.

local ADDON, ns = SFP_Module("Codex")

local tinsert = table.insert

local function strip(s)
    if not s then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " "):gsub("|T.-|t", "")
    return s
end
ns.strip = strip

local function expName(id)
    return (id and _G["EXPANSION_NAME" .. id]) or "Other"
end

------------------------------------------------------------------------
-- Zone list (used by entrances)
------------------------------------------------------------------------
local zoneCache
local function GetZones()
    if zoneCache then return zoneCache end
    zoneCache = {}
    local all = C_Map.GetMapChildrenInfo(946, nil, true) or {}   -- 946 = Cosmic
    for _, info in ipairs(all) do
        local t = info.mapType
        if t == Enum.UIMapType.Zone or t == Enum.UIMapType.Continent
            or t == Enum.UIMapType.Micro or t == Enum.UIMapType.Dungeon then
            zoneCache[#zoneCache + 1] = info
        end
    end
    return zoneCache
end

-- zone name -> uiMapID (zones preferred)
local zoneByName
function ns:ZoneByName(name)
    if not name then return nil end
    if not zoneByName then
        zoneByName = {}
        for _, z in ipairs(GetZones()) do
            local k = z.name:lower()
            local cur = zoneByName[k]
            if not cur or (z.mapType == Enum.UIMapType.Zone and cur.mapType ~= Enum.UIMapType.Zone) then
                zoneByName[k] = z
            end
        end
    end
    local key = name:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local z = zoneByName[key]
    if z then return z.mapID end
    -- not in the world tree (garrisons, class halls, cities, phased maps):
    -- scan every map id once and remember all names
    if not ns._allMapsScanned then
        ns._allMapsScanned = true
        for id = 1, 3500 do
            local info = C_Map.GetMapInfo(id)
            if info and info.name and info.name ~= "" then
                local k = info.name:lower()
                if not zoneByName[k] then zoneByName[k] = { mapID = id, mapType = info.mapType, name = info.name } end
            end
        end
        z = zoneByName[key]
        if z then return z.mapID end
    end
    return nil
end

local function ContinentOf(m)
    local guard = 0
    while m and guard < 10 do
        local info = C_Map.GetMapInfo(m)
        if not info then return nil end
        if info.mapType == Enum.UIMapType.Continent then return m, info.name end
        m = info.parentMapID
        guard = guard + 1
    end
end
ns.ContinentOf = ContinentOf

------------------------------------------------------------------------
-- 1) Encounter Journal: dungeons, raids, bosses, boss creatures
------------------------------------------------------------------------
local function IndexJournal()
    local nTiers = EJ_GetNumTiers()
    local tiers, seasonal = {}, {}
    for t = 1, nTiers do
        local name = EJ_GetTierInfo(t)
        if name then
            if name:lower():find("season", 1, true) then
                seasonal[#seasonal + 1] = { t = t, name = name }
            else
                tiers[#tiers + 1] = { t = t, name = name }
            end
        end
    end
    ns.currentTier = tiers[#tiers] and tiers[#tiers].name
    for _, s in ipairs(seasonal) do s.seasonal = true; tiers[#tiers + 1] = s end

    for _, tier in ipairs(tiers) do
        EJ_SelectTier(tier.t)
        for _, isRaid in ipairs({ false, true }) do
            local i = 1
            while true do
                local instanceID, name, description, _, buttonImage, loreImage, _, _, link =
                    EJ_GetInstanceByIndex(i, isRaid)
                if not instanceID then break end
                local cat = isRaid and "raid" or "dungeon"
                local key = cat .. ":" .. instanceID
                if tier.seasonal then
                    local e = ns:Get(key)
                    if e then
                        e.seasonal = tier.name
                        e.tags = (e.tags or "") .. " season current"
                    end
                else
                    local inst = ns:Add({
                        cat = cat, id = instanceID, name = name, group = tier.name,
                        icon = "Interface\\Icons\\" .. (isRaid and "Achievement_Boss_Ragnaros" or "INV_Misc_Key_14"),
                        image = buttonImage, lore = loreImage,
                        sub = (isRaid and "Raid" or "Dungeon") .. " — " .. tier.name,
                        body = description, link = link,
                        instanceID = instanceID, isRaid = isRaid, tier = tier.name,
                        legacy = tier.name ~= ns.currentTier,
                    })
                    -- bosses
                    -- the journal only lists bosses for the selected instance
                    EJ_SelectInstance(instanceID)
                    local b = 1
                    while true do
                        local bname, bdesc, encounterID, rootSectionID, blink = EJ_GetEncounterInfoByIndex(b)
                        if not encounterID then
                            bname, bdesc, encounterID, rootSectionID, blink = EJ_GetEncounterInfoByIndex(b, instanceID)
                        end
                        if not encounterID then break end
                        local _, _, _, _, portrait = EJ_GetCreatureInfo(1, encounterID)
                        local boss = ns:Add({
                            cat = "boss", id = encounterID, name = bname, group = tier.name,
                            icon = portrait or "Interface\\Icons\\Achievement_Boss_Ragnaros",
                            sub = name .. (isRaid and " (raid)" or " (dungeon)"),
                            body = bdesc, link = blink, encounterID = encounterID,
                            instanceID = instanceID, rootSectionID = rootSectionID,
                            instKey = inst and inst.key, order = b,
                        })
                        ns:Link(inst, boss)
                        -- every creature in the encounter (adds, councils, mounts)
                        local c = 1
                        while true do
                            local cid, cname, cdesc, _, cicon = EJ_GetCreatureInfo(c, encounterID)
                            if not cid then break end
                            local cr = ns:Add({
                                cat = "creature", id = "ej" .. cid, name = cname, group = tier.name,
                                icon = cicon, sub = bname .. " — " .. name, body = cdesc,
                            })
                            ns:Link(boss, cr)
                            c = c + 1
                        end
                        b = b + 1
                        ns:Yield()
                    end
                end
                i = i + 1
                ns:Yield()
            end
        end
    end
end

------------------------------------------------------------------------
-- 2) Instance entrances (real map pins from the game)
------------------------------------------------------------------------
local function IndexEntrances()
    if not C_EncounterJournal.GetDungeonEntrancesForMap then return end
    local best = {}
    for _, z in ipairs(GetZones()) do
        local list = C_EncounterJournal.GetDungeonEntrancesForMap(z.mapID)
        if list then
            for _, d in ipairs(list) do
                local cur = best[d.journalInstanceID]
                -- prefer a zone map, then a sub-zone/cave map (e.g. Caverns of Time), then continent
                local rank = (z.mapType == Enum.UIMapType.Zone and 3)
                    or ((z.mapType == Enum.UIMapType.Micro or z.mapType == Enum.UIMapType.Dungeon) and 2) or 1
                if not cur or rank > cur.rank then
                    best[d.journalInstanceID] = {
                        m = z.mapID, x = d.position.x, y = d.position.y,
                        rank = rank, zone = z.name, name = d.name,
                    }
                end
            end
        end
        ns:Yield()
    end
    for jid, p in pairs(best) do
        local inst = ns:Get("dungeon:" .. jid) or ns:Get("raid:" .. jid)
        local map = { m = p.m, x = p.x, y = p.y }
        local _, contName = ContinentOf(p.m)
        local contID = ContinentOf(p.m)
        if inst then inst.map = map end
        local ent = ns:Add({
            cat = "entrance", id = jid, name = inst and inst.name or p.name,
            group = contName or p.zone,
            icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran",
            sub = ("%s — %s (%.1f, %.1f)"):format(inst and (inst.isRaid and "Raid" or "Dungeon") or "Instance",
                p.zone, p.x * 100, p.y * 100),
            map = map, continentID = contID, zone = p.zone, inCave = p.rank == 2,
            isRaid = inst and inst.isRaid, tags = (inst and inst.tier or "") .. " " .. (contName or ""),
        })
        if inst then ns:Link(inst, ent) end
        ns:Yield()
    end
    -- instances the game gives no map pin for still get a page
    for _, cat in ipairs({ "dungeon", "raid" }) do
        for _, inst in ipairs(ns.byCat[cat]) do
            if not inst.map then
                local ent = ns:Add({
                    cat = "entrance", id = inst.instanceID, name = inst.name,
                    group = "No map pin in the game",
                    icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran",
                    sub = (inst.isRaid and "Raid" or "Dungeon") .. " — " .. (inst.tier or ""),
                    noPin = true, isRaid = inst.isRaid, tags = inst.tier or "",
                })
                ns:Link(inst, ent)
            end
            ns:Yield()
        end
    end
end

------------------------------------------------------------------------
-- 3) Mounts
------------------------------------------------------------------------
local function IndexMounts()
    for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local name, spellID, icon, _, _, sourceType, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if name then
            local _, description, source = C_MountJournal.GetMountInfoExtraByID(mountID)
            ns:Add({
                cat = "mount", id = mountID, name = name, icon = icon,
                group = _G["BATTLE_PET_SOURCE_" .. (sourceType or 0)] or "Other",
                sub = strip(source), source = source, body = description,
                collected = isCollected, spellID = spellID, wh = spellID and ("spell=" .. spellID),
            })
        end
        ns:Yield()
    end
end

------------------------------------------------------------------------
-- 4) Battle pets (every obtainable species)
------------------------------------------------------------------------
local function IndexPets()
    local misses = 0
    for speciesID = 1, 8000 do
        local name, icon, petType, companionID, source, description, isWild, canBattle, isTradeable, _, obtainable =
            C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        if name and name ~= "" then
            misses = 0
            if obtainable then
                local owned = C_PetJournal.GetNumCollectedInfo(speciesID)
                ns:Add({
                    cat = "pet", id = speciesID, name = name, icon = icon,
                    group = _G["BATTLE_PET_NAME_" .. (petType or 0)] or "Other",
                    sub = strip(source), source = source, body = description,
                    collected = (owned or 0) > 0, wild = isWild, canBattle = canBattle,
                    tradeable = isTradeable, wh = companionID and companionID > 0 and ("npc=" .. companionID) or nil,
                    tags = isWild and "wild battle" or "",
                })
            end
        else
            misses = misses + 1
            if misses > 1500 and speciesID > 4000 then break end
        end
        ns:Yield()
    end
end

------------------------------------------------------------------------
-- 5) Achievements (+ titles via reward text)
------------------------------------------------------------------------
local function AddAchievement(id, group)
    local aid, name, points, completed, _, _, _, description, _, icon, rewardText, isGuild = GetAchievementInfo(id)
    if not aid or ns:Get("achievement:" .. aid) then return end
    ns:Add({
        cat = "achievement", id = aid, name = name, icon = icon, group = group,
        sub = (rewardText and rewardText ~= "" and (rewardText .. " — ") or "") .. (description or ""),
        body = description, reward = rewardText, points = points, collected = completed,
        guild = isGuild, wh = "achievement=" .. aid,
        tags = (rewardText and rewardText ~= "") and "reward" or "",
    })
end

local function IndexAchievements()
    for _, catID in ipairs(GetCategoryList() or {}) do
        local title, parentID = GetCategoryInfo(catID)
        local group = title
        if parentID and parentID > 0 then
            local ptitle = GetCategoryInfo(parentID)
            if ptitle then group = ptitle .. " > " .. title end
        end
        local n = GetCategoryNumAchievements(catID, true) or 0
        for i = 1, n do
            local id = GetAchievementInfo(catID, i)
            if id then
                AddAchievement(id, group)
                -- walk achievement chains (Blizzard only lists the current step)
                local prev = GetPreviousAchievement(id)
                while prev and not ns:Get("achievement:" .. prev) do
                    AddAchievement(prev, group); prev = GetPreviousAchievement(prev)
                end
                local nxt = GetNextAchievement(id)
                while nxt and not ns:Get("achievement:" .. nxt) do
                    AddAchievement(nxt, group); nxt = GetNextAchievement(nxt)
                end
            end
            ns:Yield()
        end
    end
end

------------------------------------------------------------------------
-- 6) Transmog sets
------------------------------------------------------------------------
local function IndexTransmogSets()
    if not (C_TransmogSets and C_TransmogSets.GetAllSets) then return end
    for _, s in ipairs(C_TransmogSets.GetAllSets() or {}) do
        local label = s.label and s.label ~= "" and s.label or nil
        ns:Add({
            cat = "tset", id = s.setID, name = s.name .. (s.description and s.description ~= "" and (" (" .. s.description .. ")") or ""),
            group = expName(s.expansionID),
            icon = "Interface\\Icons\\INV_Chest_Cloth_17",
            sub = (label or "") .. (s.validForCharacter and "" or "  [other class]"),
            collected = s.collected, setID = s.setID, wh = "transmog-set=" .. s.setID,
        })
        ns:Yield()
    end
end

------------------------------------------------------------------------
-- 7) Every quest: title + objectives only (what to do, no story text)
-- The client has no "list all quests" call, so we ask the server about every
-- quest ID once, slowly, and save the answers account-wide. The first full
-- scan runs in the background (pauses in combat) and resumes next login.
------------------------------------------------------------------------
local QUEST_MAX = 120000   -- scan stops early once 4000 IDs in a row past 90000 are empty
local BATCH = 25
local JUNK = { "tracking", "[dnt]", "[ph]", "unused", "deprecated", "zzold", "hidden quest", "[hidden]", "(hidden)", "do not translate" }

local answered = {}
local qev = CreateFrame("Frame")
pcall(qev.RegisterEvent, qev, "QUEST_DATA_LOAD_RESULT")
qev:SetScript("OnEvent", function(_, _, questID, success)
    if questID then answered[questID] = success and true or false end
end)

local function isJunk(title)
    local l = title:lower()
    for _, w in ipairs(JUNK) do
        if l:find(w, 1, true) then return true end
    end
    return false
end

local function ReadQuest(id)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if not title or title == "" or isJunk(title) then return nil end
    local obj = {}
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "quest:" .. id)
        if ok and tip and tip.lines then
            for i = 2, #tip.lines do
                local t = tip.lines[i].leftText
                if t and t:find("%S") then obj[#obj + 1] = t end
            end
        end
    end
    local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(id)
    local exp = GetQuestExpansion and GetQuestExpansion(id)
    local lvl = C_QuestLog.GetQuestDifficultyLevel and C_QuestLog.GetQuestDifficultyLevel(id)
    return {
        t = title, o = table.concat(obj, "\n"),
        g = tag and tag.tagName or nil, w = (tag and tag.worldQuestType) and true or nil,
        x = exp, l = (lvl and lvl > 0) and lvl or nil,
    }
end

ns.ReadQuestRaw = function(id) return ReadQuest(id) end

local function AddQuest(id, q)
    local done = C_QuestLog.IsQuestFlaggedCompleted(id)
    local objLine = (q.o or ""):gsub("\n", " · ")
    ns:Add({
        cat = "quest", id = id, name = q.t,
        group = (q.x and _G["EXPANSION_NAME" .. q.x]) or "Other",
        icon = q.w and "Interface\\Icons\\INV_Misc_Map02" or "Interface\\Icons\\INV_Misc_Note_01",
        sub = (q.g and (q.g .. " — ") or "") .. objLine,
        objectives = q.o, tag = q.g, level = q.l, worldQuest = q.w,
        collected = done or nil, questID = id, wh = "quest=" .. id,
        tags = (q.g or "") .. (q.w and " world quest" or ""),
    })
end

ns.AddQuestEntry = function(id, q) AddQuest(id, q) end

local function LoadQuests()
    local db = ns.db
    db.quests = db.quests or {}
    -- everything already scanned shows up immediately
    for id, q in pairs(db.quests) do
        AddQuest(id, q)
        ns:Yield()
    end
end

local function IndexQuests()
    local db = ns.db
    db.quests = db.quests or {}
    local build = select(4, GetBuildInfo())
    if db.questBuild ~= build then
        -- new patch: scan the top of the range again for brand-new quests
        if db.questDone then db.questCursor = math.max(1, (db.questMaxFound or 0) - 3000) end
        db.questDone = false
        db.questBuild = build
    end
    if db.questDone then return end

    local id = db.questCursor or 1
    local misses = 0
    while id <= QUEST_MAX do
        local last = math.min(id + BATCH - 1, QUEST_MAX)
        local asked = {}
        for q = id, last do
            if not db.quests[q] and not C_QuestLog.GetTitleForQuestID(q) then
                answered[q] = nil
                C_QuestLog.RequestLoadQuestByID(q)
                asked[#asked + 1] = q
            end
        end
        -- wait for the server (max 3 s), never faster than 0.5 s per batch
        local start = GetTime()
        while true do
            local elapsed = GetTime() - start
            if elapsed >= 3 then break end
            if elapsed >= 0.5 then
                local all = true
                for _, q in ipairs(asked) do
                    if answered[q] == nil then all = false; break end
                end
                if all then break end
            end
            coroutine.yield()
        end
        for q = id, last do
            answered[q] = nil
            if db.quests[q] then
                misses = 0
            else
                local rec = ReadQuest(q)
                if rec then
                    db.quests[q] = rec
                    AddQuest(q, rec)
                    misses = 0
                    if q > (db.questMaxFound or 0) then db.questMaxFound = q end
                else
                    misses = misses + 1
                end
            end
        end
        id = last + 1
        db.questCursor = id
        ns.progress = ("quest IDs %d / %d"):format(id, QUEST_MAX)
        if id > 90000 and misses > 4000 then break end
    end
    db.questDone = true
    ns.progress = nil
end


------------------------------------------------------------------------
-- 8) Loot (slow crawl; resolves item names in the background)
------------------------------------------------------------------------
local pendingNames = {}

local function JournalOpen()
    return EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown()
end

local function IndexLoot()
    local db = ns.db
    local build = select(4, GetBuildInfo())
    -- same patch as last time: load the saved loot list instantly
    if db.loot and db.lootBuild == build then
        for id, r in pairs(db.loot) do
            local item = ns:Add({
                cat = "item", id = id, name = r.n, icon = r.i, group = r.g, sub = r.s,
                link = r.l, itemID = id, wh = "item=" .. id, tags = r.t,
            })
            if item then
                for _, bk in ipairs(r.b or {}) do ns:Link(ns:Get(bk), item) end
            end
            ns:Yield()
        end
        return
    end
    db.loot = {}
    EJ_SetLootFilter(0, 0)                 -- all classes / specs
    local bosses = ns.byCat.boss
    for idx = 1, #bosses do
        while JournalOpen() do coroutine.yield() end   -- don't fight the Adventure Guide
        local boss = bosses[idx]
        if boss.encounterID then
        EJ_SelectInstance(boss.instanceID)
        EJ_SelectEncounter(boss.encounterID)
        local inst = boss.instKey and ns:Get(boss.instKey)
        for i = 1, EJ_GetNumLoot() or 0 do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID then
                local name = info.name
                if not name or name == "" then
                    name = C_Item.GetItemNameByID(info.itemID)
                end
                local item = ns:Add({
                    cat = "item", id = info.itemID, name = name or ("item " .. info.itemID),
                    icon = info.icon or C_Item.GetItemIconByID(info.itemID),
                    group = boss.group,
                    sub = ("%s%s — %s, %s"):format(info.slot or "", (info.armorType and info.armorType ~= "") and (" " .. info.armorType) or "",
                        boss.name, inst and inst.name or "?"),
                    link = info.link, itemID = info.itemID, wh = "item=" .. info.itemID,
                    tags = (inst and inst.isRaid) and "raid" or "dungeon",
                })
                if item then
                    ns:Link(boss, item)
                    if not name then pendingNames[#pendingNames + 1] = item end
                    local r = db.loot[info.itemID]
                    if not r then
                        r = { n = item.name, i = item.icon, g = item.group, s = item.sub, l = item.link, t = item.tags, b = {} }
                        db.loot[info.itemID] = r
                    end
                    r.b[#r.b + 1] = boss.key
                end
            end
        end
        end -- encounterID (rares have no journal loot)
        ns:Yield()
    end
    EJ_ResetLootFilter()
    -- fill in names that weren't cached yet
    for i = 1, #pendingNames, 40 do
        for j = i, math.min(i + 39, #pendingNames) do
            C_Item.RequestLoadItemDataByID(pendingNames[j].id)
        end
        ns:Wait(0.5)
        for j = i, math.min(i + 39, #pendingNames) do
            local e = pendingNames[j]
            local n = C_Item.GetItemNameByID(e.id)
            if n then
                e.name = n; e.lname = n:lower(); ns.dirty = true
                if db.loot[e.id] then db.loot[e.id].n = n end
            end
        end
    end
    wipe(pendingNames)
    db.lootBuild = build
end

------------------------------------------------------------------------
-- 9) Bridge for sister addons (SeviathsUsefulTools etc.)
------------------------------------------------------------------------
-- Any addon can push entries:  SeviathsCodex:AddExternal({cat="mats", id=..., name=..., ...})
function ns:AddExternal(e)
    if type(e) ~= "table" then return end
    if not self.CATBYKEY[e.cat] then e.cat = "mats" end
    return self:Add(e)
end

local function IndexBridges()
    -- Sister addons may expose a function that feeds the Codex.
    if SeviathsUsefulTools and type(SeviathsUsefulTools.FeedCodex) == "function" then
        SeviathsUsefulTools.FeedCodex(ns)
    end
end

------------------------------------------------------------------------
-- 10) Rares — the game has no list of rares, so the Codex records every rare
-- you (or your alts) come across on the minimap: name, zone and exact spot.
------------------------------------------------------------------------
local function AddRare(key, r)
    local _, contName = ContinentOf(r.m)
    ns:Add({
        cat = "boss", id = "rare:" .. key, name = r.n,
        group = "Rares — " .. (contName or "Other"),
        icon = "Interface\\Icons\\Achievement_Boss_Archaedas",
        sub = ("Rare — %s"):format(ns:MapName(r.m)),
        map = { m = r.m, x = r.x, y = r.y }, rare = true,
        tags = "rare elite world",
    })
end

local function ScanVignettes()
    if InCombatLockdown() or not (C_VignetteInfo and C_VignetteInfo.GetVignettes) or not ns.db then return end
    local m = C_Map.GetBestMapForUnit("player")
    if not m then return end
    ns.db.rares = ns.db.rares or {}
    for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do
        local ok, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
        if ok and info and info.name and info.atlasName and info.atlasName:find("VignetteKill", 1, true) then
            local key = info.name .. "@" .. m
            if not ns.db.rares[key] then
                local pos = C_VignetteInfo.GetVignettePosition(guid, m)
                if pos then
                    local r = { n = info.name, m = m, x = pos.x, y = pos.y }
                    ns.db.rares[key] = r
                    AddRare(key, r)
                    ns:Print("new rare recorded: " .. info.name .. " (" .. ns:MapName(m) .. ")")
                end
            end
        end
    end
end

local vev = CreateFrame("Frame")
pcall(vev.RegisterEvent, vev, "VIGNETTES_UPDATED")
pcall(vev.RegisterEvent, vev, "VIGNETTE_MINIMAP_UPDATED")
local vpending = false
vev:SetScript("OnEvent", function()
    if vpending then return end
    vpending = true
    C_Timer.After(1, function() vpending = false; pcall(ScanVignettes) end)
end)

local function IndexRares()
    for key, r in pairs((ns.db and ns.db.rares) or {}) do
        AddRare(key, r)
        ns:Yield()
    end
    -- sister addons (Farm Pack) can add their rares through SeviathsCodex:AddExternal
end

------------------------------------------------------------------------
-- 11) Every other item: recorded when you see it (bags, bank, tooltips,
-- vendors, Auction House) so any item you hover becomes searchable.
------------------------------------------------------------------------
local function AddSeenItem(id, rec)
    if ns:Get("item:" .. id) then return end
    ns:Add({
        cat = "item", id = id, name = rec.n,
        group = "Seen items — " .. (rec.t or "Other"),
        icon = C_Item.GetItemIconByID(id),
        sub = rec.t or "", itemID = id, wh = "item=" .. id,
    })
end

local function RecordItem(id)
    if not id or not ns.db then return end
    ns.db.items = ns.db.items or {}
    if ns:Get("item:" .. id) then return end
    if ns.db.items[id] then AddSeenItem(id, ns.db.items[id]); return end
    local name = C_Item.GetItemNameByID(id)
    if not name or (issecretvalue and issecretvalue(name)) then return end
    local _, itemType = C_Item.GetItemInfoInstant(id)
    local rec = { n = name, t = itemType }
    ns.db.items[id] = rec
    AddSeenItem(id, rec)
    if ns.MaybeMaterial then ns:MaybeMaterial(id, name) end
end

ns.RecordItem = function(id) pcall(RecordItem, id) end

-- bank / warband bank: record contents when you open it
local bev = CreateFrame("Frame")
pcall(bev.RegisterEvent, bev, "BANKFRAME_OPENED")
pcall(bev.RegisterEvent, bev, "PLAYER_EQUIPMENT_CHANGED")
bev:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    C_Timer.After(1, function()
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            for slot = 1, 19 do
                local id = GetInventoryItemID("player", slot)
                if id then pcall(RecordItem, id) end
            end
            return
        end
        if not C_Container then return end
        for bag = -3, 20 do
            local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
            if ok and n then
                for slot = 1, n do
                    local id = C_Container.GetContainerItemID(bag, slot)
                    if id then pcall(RecordItem, id) end
                end
            end
        end
    end)
end)

if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(_, data)
        if data and data.id and not InCombatLockdown() then pcall(RecordItem, data.id) end
    end)
end

local function IndexSeenItems()
    for id, rec in pairs((ns.db and ns.db.items) or {}) do
        AddSeenItem(id, rec)
        ns:Yield()
    end
    -- everything you're wearing
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id then pcall(RecordItem, id) end
    end
    -- everything in your bags right now
    if C_Container then
        for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
            for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
                local id = C_Container.GetContainerItemID(bag, slot)
                if id then pcall(RecordItem, id) end
            end
            ns:Yield()
        end
    end
end

ns.INDEXERS = {
    { name = "Reading the Adventure Guide",   fn = IndexJournal },
    { name = "Finding instance entrances",    fn = function() if C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap then (IndexEntrances)() end end },
    { name = "Loading rares",                 fn = function() if C_VignetteInfo and C_VignetteInfo.GetVignettes then (IndexRares)() end end },
    { name = "Loading vendors",               fn = function() if ns.IndexVendors then ns:IndexVendors() end end },
    { name = "Finding delves",                fn = function() if ns.IndexDelves then ns:IndexDelves() end end },
    { name = "Loading gold farms",            fn = function() if ns.LoadFarms then ns:LoadFarms() end end },
    { name = "Loading hunter pets",           fn = function() if ns.LoadBeasts then ns:LoadBeasts() end end },
    { name = "Loading monsters",              fn = function() if ns.LoadMonsters then ns:LoadMonsters() end end },
    { name = "Reading your items",            fn = IndexSeenItems },
    { name = "Reading materials",             fn = function() if ns.IndexMaterials then ns:IndexMaterials() end end },
    { name = "Loading saved quests",          fn = LoadQuests },
    { name = "Reading the mount journal",     fn = IndexMounts },
    { name = "Reading the pet journal",       fn = IndexPets },
    { name = "Reading achievements",          fn = IndexAchievements },
    { name = "Reading transmog sets",         fn = function() if C_TransmogSets and C_TransmogSets.GetAllSets then (IndexTransmogSets)() end end },
    { name = "Sister addons",                 fn = IndexBridges },
    { name = "Reading boss loot",             fn = IndexLoot },
    { name = "Finding materials in loot",     fn = function() if ns.IndexMaterials then ns:IndexMaterials() end end },
    { name = "Reading quests",                fn = function() if C_QuestLog and C_QuestLog.RequestLoadQuestByID then (IndexQuests)() end end },
}

------------------------------------------------------------------------
-- On-demand detail helpers (used by the UI)
------------------------------------------------------------------------

-- Ability flags shown in the Adventure Guide (index = flag id)
local FLAGS = {
    [0] = "|cff8fb3ffTank|r", [1] = "|cffff8080DPS|r", [2] = "|cff80ff80Healer|r",
    [3] = "|cffffc000Heroic|r", [4] = "|cffff3030DEADLY|r", [5] = "|cffff9900Important|r",
    [6] = "|cff33e6ffInterrupt|r", [7] = "|cff7aa8ffMagic|r", [8] = "|cffc080ffCurse|r",
    [9] = "|cff60c060Poison|r", [10] = "|cffb08040Disease|r", [11] = "|cffff6040Enrage|r",
    [12] = "|cffff40ffMythic|r", [13] = "|cffcc2020Bleed|r",
}

local function FlagText(sectionID)
    if not C_EncounterJournal.GetSectionIconFlags then return "" end
    local ok, flags = pcall(C_EncounterJournal.GetSectionIconFlags, sectionID)
    if not ok or type(flags) ~= "table" or #flags == 0 then return "" end
    local out = {}
    for _, f in ipairs(flags) do
        if FLAGS[f] then out[#out + 1] = FLAGS[f] end
    end
    return #out > 0 and ("  [" .. table.concat(out, ", ") .. "]") or ""
end

-- Boss mechanics: every ability / phase from the Adventure Guide, with role
-- and danger tags. Lore is left out on purpose.
function ns:BossAbilities(boss)
    if not boss.rootSectionID then return nil end
    if boss.abilities then return boss.abilities end
    local lines = {}
    local function walk(sectionID, depth)
        local guard = 0
        while sectionID and guard < 300 do
            guard = guard + 1
            local s = C_EncounterJournal.GetSectionInfo(sectionID)
            if not s then break end
            if s.title and s.title ~= "" then
                local icon = (s.abilityIcon and s.abilityIcon ~= 0) and ("|T" .. s.abilityIcon .. ":14|t ") or ""
                local head = string.rep("    ", depth) .. icon .. ns.CYAN .. s.title .. "|r" .. FlagText(sectionID)
                lines[#lines + 1] = head
                if s.description and s.description ~= "" then
                    local desc = s.description:gsub("%$bullet;", "\n" .. string.rep("    ", depth + 1) .. "• ")
                    lines[#lines + 1] = string.rep("    ", depth + 1) .. desc
                end
            end
            if s.firstChildSectionID and depth < 6 then walk(s.firstChildSectionID, depth + 1) end
            sectionID = s.siblingSectionID
        end
    end
    walk(boss.rootSectionID, 0)
    boss.abilities = table.concat(lines, "\n")
    return boss.abilities
end

-- All bosses of a dungeon/raid in order, each with its mechanics
function ns:InstanceMechanics(inst)
    local bosses = {}
    for _, k in ipairs(inst.refs or {}) do
        local b = self:Get(k)
        if b and b.cat == "boss" then bosses[#bosses + 1] = b end
    end
    table.sort(bosses, function(x, y) return (x.order or 0) < (y.order or 0) end)
    if #bosses == 0 then return nil end
    local parts = {}
    for i, b in ipairs(bosses) do
        parts[#parts + 1] = ("|cffffd100%d. %s|r\n%s"):format(i, b.name, self:BossAbilities(b) or "No mechanics listed.")
    end
    return table.concat(parts, "\n\n")
end

-- What an item is, what it does, and what it's for (no lore / flavor text)
local PURPOSE = {
    [0]  = "Consumable — use it from your bags (potions, food, flasks, scrolls, drums). Effects are temporary.",
    [1]  = "Bag — equip it in a bag slot for more inventory space.",
    [2]  = "Weapon — equip it for item level, stats and weapon damage. Also adds its look to your transmog collection.",
    [3]  = "Gem — put it into a socket on your gear for extra stats.",
    [4]  = "Armor — equip it for item level and stats. Also adds its look to your transmog collection.",
    [5]  = "Reagent — used up by a spell or ability.",
    [7]  = "Crafting material — used by professions to craft things. Can usually be sold on the Auction House.",
    [8]  = "Item enhancement — apply it to gear (enchants, armor kits, weapon oils, upgrades).",
    [9]  = "Recipe — use it to teach your profession a new recipe.",
    [12] = "Quest item — needed for a quest; usually can't be sold.",
    [13] = "Key — opens a door, chest or area.",
    [15] = "Miscellaneous — often a mount, pet, toy, cosmetic, container or junk. Check 'What it does'.",
    [16] = "Glyph — changes how one of your class spells looks or works.",
    [17] = "Battle pet — learn it to add the pet to your collection.",
    [19] = "Profession equipment — tools and gear that boost your profession stats.",
}
local MAT_USE = {
    ["Cloth"] = "Tailoring (bags, cloth armor) and First Aid/bandages in older content.",
    ["Leather"] = "Leatherworking (leather/mail armor, armor kits).",
    ["Metal & Stone"] = "Blacksmithing, Engineering and Jewelcrafting.",
    ["Herb"] = "Alchemy (potions, flasks) and Inscription (inks, via milling).",
    ["Cooking"] = "Cooking — turn it into food buffs.",
    ["Enchanting"] = "Enchanting — enchants for gear.",
    ["Elemental"] = "Many crafting professions as a secondary material.",
    ["Jewelcrafting"] = "Jewelcrafting — cut into gems.",
    ["Inscription"] = "Inscription — inks and scrolls.",
    ["Parts"] = "Engineering.",
    ["Optional Reagents"] = "Added while crafting to change the result (stats, quality, effects).",
    ["Finishing Reagents"] = "Added while crafting to improve the result.",
}

function ns:ItemExplain(e)
    local id = e.itemID or e.id
    local _, itemType, itemSubType, equipLoc, _, classID = C_Item.GetItemInfoInstant(id)
    local parts = {}
    local what = itemType and (itemType .. ((itemSubType and itemSubType ~= itemType) and (" — " .. itemSubType) or "")) or nil
    if equipLoc and equipLoc ~= "" and _G[equipLoc] then what = (what and (what .. ", ") or "") .. _G[equipLoc] end
    if what then parts[#parts + 1] = "\n\n" .. ns.CYAN .. "What it is|r\n" .. what end

    -- the in-game tooltip, minus the name and flavor (quoted) text
    local lines = {}
    local tip = C_TooltipInfo and C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(id)
    if tip and tip.lines then
        for i = 2, #tip.lines do
            local l = tip.lines[i]
            local t = l.leftText
            if t and t:find("%S") and not t:find('^"') and not (issecretvalue and issecretvalue(t)) then
                if l.rightText and l.rightText ~= "" then t = t .. "   " .. l.rightText end
                lines[#lines + 1] = t
            end
        end
    else
        C_Item.RequestLoadItemDataByID(id)
        e._tries = (e._tries or 0) + 1
        if e._tries <= 3 then C_Timer.After(0.6, function()
            if ns.state and ns.state.selected == e.key then ns:ShowEntry(e.key, true) end
        end) end
        lines[1] = "|cff888888Loading item data…|r"
    end
    if #lines > 0 then parts[#parts + 1] = "\n\n" .. ns.CYAN .. "What it does|r\n" .. table.concat(lines, "\n") end

    local purpose = classID and PURPOSE[classID]
    if classID == 7 and itemSubType and MAT_USE[itemSubType] then
        purpose = purpose .. "\nUsed by: " .. MAT_USE[itemSubType]
    end
    if purpose then parts[#parts + 1] = "\n\n" .. ns.CYAN .. "What it's for|r\n" .. purpose end
    return table.concat(parts)
end

function ns:AchievementCriteria(e)
    local n = GetAchievementNumCriteria(e.id) or 0
    if n == 0 then return nil end
    local lines = {}
    for i = 1, n do
        local text, _, done, qty, req = GetAchievementCriteriaInfo(e.id, i)
        if text and text ~= "" then
            local prog = (req and req > 1) and (" (%d/%d)"):format(qty or 0, req) or ""
            lines[#lines + 1] = (done and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " or "|cff888888•|r ") .. text .. prog
        end
    end
    return table.concat(lines, "\n")
end

function ns:SetItems(e)
    if not (C_TransmogSets.GetAllSourceIDs and C_TransmogCollection.GetSourceInfo) then return nil end
    local lines = {}
    for _, src in ipairs(C_TransmogSets.GetAllSourceIDs(e.setID) or {}) do
        local info = C_TransmogCollection.GetSourceInfo(src)
        if info and info.itemID then
            local name = info.name or C_Item.GetItemNameByID(info.itemID) or ("item " .. info.itemID)
            lines[#lines + 1] = (info.isCollected and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " or "|cff888888•|r ") .. name
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or nil
end

-- How to travel to a continent (used on entrance pages)
ns.PORTAL_ROOMS = "Portal rooms: in Stormwind it's the Wizard's Sanctum in the Mage Quarter; in Orgrimmar it's the Pathfinder's Den. Open the city map — portal rooms show a swirling portal icon — and each portal is labelled with where it goes."

ns.TRAVEL = {
    [13]   = "Eastern Kingdoms\n1. Alliance: you start here — Stormwind is the hub.\n2. Horde: use the zeppelin towers outside Orgrimmar or a Mage portal.\n3. Then use flight masters (take every flight point you pass) or fly.",
    [12]   = "Kalimdor\n1. Horde: you start here — Orgrimmar is the hub.\n2. Alliance: use the Exodar portal in the Stormwind portal room, or the boat from Stormwind Harbor.\n3. Then use flight masters or fly.",
    [101]  = "Outland\n1. Take the Blasted Lands portal in the Stormwind / Orgrimmar portal room.\n2. In Blasted Lands walk through the Dark Portal — you arrive in Hellfire Peninsula.\n3. Shattrath City (Terokkar Forest) is the hub; its portals lead back to the capitals.",
    [113]  = "Northrend\n1. Alliance: boat from Stormwind Harbor to Valiance Keep (Borean Tundra).\n2. Horde: zeppelin from outside Orgrimmar to Warsong Hold (Borean Tundra).\n3. Dalaran (Crystalsong Forest) is the old hub.",
    [424]  = "Pandaria\n1. Take the Jade Forest portal in the Stormwind / Orgrimmar portal room.\n2. You arrive in The Jade Forest; Vale of Eternal Blossoms is the center of the continent.",
    [572]  = "Draenor\n1. Take the Stormshield (Alliance) / Warspear (Horde) portal in your capital's portal room — both are in Ashran.\n2. From Ashran fly or take the flight paths to the zone.",
    [619]  = "Broken Isles\n1. Take the Azsuna portal in your capital's portal room.\n2. Dalaran floats above the Broken Isles and is the hub; flight masters connect every zone.",
    [905]  = "Argus\n1. Get to Dalaran (Broken Isles) first.\n2. At Krasus' Landing board the Vindicaar (unlocked by the Argus campaign).\n3. From the Vindicaar teleport down to Krokuun, Antoran Wastes or Eredath.",
    [875]  = "Zandalar\n1. Horde: take the Zuldazar portal in the Orgrimmar portal room.\n2. Alliance: go to Boralus (Kul Tiras) and take the boat from the harbor.",
    [876]  = "Kul Tiras\n1. Alliance: take the Boralus portal in the Stormwind portal room.\n2. Horde: go to Zuldazar (Zandalar) and take the boat from the harbor.",
    [1550] = "Shadowlands\n1. Take the Oribos portal in your capital's portal room.\n2. Oribos is the hub; its flight master (and the Shadowlands campaign) take you to each zone.",
    [1978] = "Dragon Isles\n1. Take the Valdrakken portal in your capital's portal room.\n2. Valdrakken (Thaldraszus) is the hub; skyride to the other zones.",
    [2274] = "Khaz Algar\n1. Take the Dornogal portal in your capital's portal room.\n2. Dornogal (Isle of Dorn) is the hub; the other zones are reached by flying or the underground paths.",
}
ns.TRAVEL_BYNAME = {
    ["quel'thalas"] = "Quel'Thalas (Midnight)\n1. Take the Silvermoon City portal in your capital's portal room.\n2. Silvermoon City is the hub of the expansion; flight masters and skyriding take you to the other zones.",
}
ns.TRAVEL_DEFAULT = "1. Use your capital city's portal room to reach that expansion's hub.\n2. From the hub fly or use flight masters to the zone.\n3. Press Show on map for an arrow to the exact entrance."

local function factionOK(node)
    local f = node.faction
    if not f or not Enum.FlightPathFaction then return true end
    local mine = UnitFactionGroup("player")
    if f == Enum.FlightPathFaction.Neutral then return true end
    if f == Enum.FlightPathFaction.Horde then return mine == "Horde" end
    if f == Enum.FlightPathFaction.Alliance then return mine == "Alliance" end
    return true
end

-- Detailed route for an entrance page
function ns:EntranceRoute(e)
    if e.noPin then
        return "The game has no map pin for this one. Usually that means:\n• It's entered from inside another instance or a phased area, or\n• It's an old/retired instance you reach through the Group Finder (Dungeon Finder / Raid Finder / Timewalking).\n\nCheck the Wowhead link for the exact way in."
    end
    local lines = {}
    -- where it is: entrance -> zone -> continent
    local chain, m, guard = {}, e.map.m, 0
    while m and guard < 6 do
        local info = C_Map.GetMapInfo(m)
        if not info or info.mapType < Enum.UIMapType.Continent then break end
        chain[#chain + 1] = info.name
        m = info.parentMapID
        guard = guard + 1
    end
    lines[#lines + 1] = ns.CYAN .. "Where|r\n" .. e.name .. " » " .. table.concat(chain, " » ")
        .. ("\nEntrance at %.1f, %.1f"):format(e.map.x * 100, e.map.y * 100)
    if e.inCave then
        lines[#lines + 1] = "The entrance is inside " .. (chain[1] or "a cave/building") .. ". Walk into it from " .. (chain[2] or "the zone") .. " — Show on map points to the portal."
    end

    -- nearest flight master on the zone map
    local zoneMap = e.map.m
    if e.inCave then
        local info = C_Map.GetMapInfo(zoneMap)
        if info and info.parentMapID then zoneMap = info.parentMapID end
    end
    if C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
        local ex, ey = e.map.x, e.map.y
        if zoneMap ~= e.map.m then
            local ok, contID, wpos = pcall(C_Map.GetWorldPosFromMapPos, e.map.m, CreateVector2D(ex, ey))
            if ok and contID and wpos then
                local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, contID, wpos, zoneMap)
                if ok2 and pos then ex, ey = pos.x, pos.y end
            end
        end
        local best, bestD
        for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(zoneMap) or {}) do
            if node.position and node.name and factionOK(node) then
                local d = (node.position.x - ex) ^ 2 + (node.position.y - ey) ^ 2
                if not bestD or d < bestD then best, bestD = node, d end
            end
        end
        if best then
            lines[#lines + 1] = ns.CYAN .. "Nearest flight point|r\n" .. best.name
        end
    end

    -- getting to the continent
    local tip = e.continentID and ns.TRAVEL[e.continentID]
    if not tip then
        local _, cname = ContinentOf(e.map.m)
        tip = cname and ns.TRAVEL_BYNAME[cname:lower()]
    end
    lines[#lines + 1] = ns.CYAN .. "How to get to this continent|r\n" .. (tip or ns.TRAVEL_DEFAULT)
    lines[#lines + 1] = ns.CYAN .. "Where the portals are|r\n" .. ns.PORTAL_ROOMS
    if e.isRaid then
        lines[#lines + 1] = ns.CYAN .. "Raid tip|r\nYou can also skip the travel: queue for its Raid Finder wings in the Group Finder (I) if the raid is current or still has LFR."
    end
    return table.concat(lines, "\n\n")
end

