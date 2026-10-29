-- SeviathsUsefulTools - Collector
--
-- Learns from your play and keeps it in the addon's saved variables (account-wide, so every new
-- character starts with everything already known):
--   * monsters: by NPC ID (never overwritten by another name), level, type, family, where seen,
--     kills and everything they dropped (green items included), skinning separately
--   * gathering nodes (herbs, ore, ...) by object ID with where they are and what they gave
--   * every item you loot: quality, type, level, price - tradeskill materials become farm items
--   * recipes of the professions you open: what they make and which reagents they need, so every
--     material can say what it is used for
-- Tooltips use it: monsters show what they drop, items show if they are junk, a crafting material
-- (and what it makes), or gear (and how it compares with what you wear).

local ADDON, SFP = ...

local floor, min, max = math.floor, math.min, math.max

local function guidInfo(guid)
    if not guid then return end
    local t, _, _, _, _, id = strsplit("-", guid)
    id = tonumber(id)
    if not id then return end
    if t == "Creature" or t == "Vehicle" then return "npc", id end
    if t == "GameObject" then return "obj", id end
end

local function playerPos()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not map then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not x or x <= 0 or y <= 0 then return end
    return map, x, y
end

local function addPoint(rec, map, x, y)
    rec.m = rec.m or {}
    local list = rec.m[map]
    if not list then list = {}; rec.m[map] = list end
    for _, p in ipairs(list) do
        if math.abs(p[1] - x) < 0.012 and math.abs(p[2] - y) < 0.012 then return end
    end
    if #list < 15 then list[#list + 1] = { floor(x * 10000) / 10000, floor(y * 10000) / 10000 } end
end

---------------------------------------------------------------------------
-- Spells that tell us what a loot window comes from
---------------------------------------------------------------------------
local GATHER_SPELLS = { 2366, 2575, 8613, 13262, 31252, 51005, 1804, 3365, 921 }
local gatherNames, skinNames = {}, {}
local lastCast = { name = nil, target = nil, t = 0 }

local function initSpellNames()
    for _, id in ipairs(GATHER_SPELLS) do
        local n = GetSpellInfo and GetSpellInfo(id)
        if n then gatherNames[n] = id end
    end
    for _, id in ipairs({ 8613, 8617, 8618, 10768, 32678, 50305, 74522, 102216 }) do
        local n = GetSpellInfo and GetSpellInfo(id)
        if n then skinNames[n] = true end
    end
end

function SFP:RecentCastTarget()
    if lastCast.target and lastCast.target ~= "" and GetTime() - lastCast.t < 8 then return lastCast.target end
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
local KIND_BY_SUBCLASS = { [5] = "cloth", [6] = "leather", [7] = "ore", [8] = "meat", [9] = "herb", [10] = "element", [12] = "enchant" }
local pendingItems = {}

-- tradeskill materials become farm items (shown in the browser, tooltips and learned spots)
function SFP:ClassifyItem(id)
    local info = self.Items[id]
    if info then return info.kind end
    local it = self.db and self.db.knownItems[id]
    if not it or it.c ~= 7 then return nil end
    local kind = KIND_BY_SUBCLASS[it.s] or "mat"
    self.Items[id] = { kind = kind, learned = true, note = "learned from your play" }
    self.trackedIDs[id] = true
    return kind
end

local function recordItem(id)
    if not id or not SFP.db then return end
    local name, _, q, ilvl, minLvl, itype, subtype, _, equip, _, price, classID, subID, bind = C_Item.GetItemInfo(id)
    if not name then
        pendingItems[id] = true
        C_Item.RequestLoadItemDataByID(id)
        return
    end
    pendingItems[id] = nil
    local it = SFP.db.knownItems[id] or {}
    it.n, it.q, it.i, it.r = name, q, ilvl, minLvl
    it.t, it.st, it.e, it.p, it.c, it.s, it.b = itype, subtype, equip, price, classID, subID, bind
    SFP.db.knownItems[id] = it
    SFP:ClassifyItem(id)
end
SFP.RecordItem = recordItem

---------------------------------------------------------------------------
-- Monsters
---------------------------------------------------------------------------
local function ensureNpc(id, name)
    local rec = SFP.db.npcs[id]
    if not rec then
        rec = { n = name or ("NPC " .. id), k = 0 }
        SFP.db.npcs[id] = rec
    elseif name and rec.n ~= name and not (rec.n or ""):find("^NPC %d+$") then
        -- a stored name is never overwritten: other spellings are kept as aliases
        rec.a = rec.a or {}
        rec.a[name] = true
    elseif name and (rec.n or ""):find("^NPC %d+$") then
        rec.n = name
    end
    return rec
end

local function recordUnit(unit)
    if not SFP.db or not UnitExists(unit) then return end
    if UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return end
    local kind, id = guidInfo(UnitGUID(unit))
    if kind ~= "npc" then return end
    local name = UnitName(unit)
    if not name or name == "" or name == UNKNOWN then return end
    local rec = ensureNpc(id, name)
    local lvl = UnitLevel(unit)
    if lvl and lvl > 0 then
        rec.lmin = min(rec.lmin or lvl, lvl)
        rec.lmax = max(rec.lmax or lvl, lvl)
    elseif lvl == -1 then
        rec.boss = true
    end
    rec.t = rec.t or UnitCreatureType(unit)
    rec.f = rec.f or UnitCreatureFamily(unit)
    local cls = UnitClassification(unit)
    if cls and cls ~= "normal" then rec.c = cls end
    local map, x, y = playerPos()
    if map then addPoint(rec, map, x, y) end
end

local seenGuid = {}
local function onLoot()
    if not SFP.db then return end
    local map, px, py = playerPos()
    local skin = lastCast.name and skinNames[lastCast.name] and GetTime() - lastCast.t < 8
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID then recordItem(itemID) end
        local sources = { GetLootSourceInfo(slot) }
        for i = 1, #sources, 2 do
            local guid, qty = sources[i], sources[i + 1] or 1
            local kind, id = guidInfo(guid)
            if kind == "npc" then
                local name = (UnitGUID("target") == guid) and UnitName("target") or nil
                local rec = ensureNpc(id, name)
                if not seenGuid[guid .. (skin and "s" or "")] then
                    seenGuid[guid .. (skin and "s" or "")] = true
                    if skin then rec.sk = (rec.sk or 0) + 1 else rec.k = (rec.k or 0) + 1 end
                    if map then addPoint(rec, map, px, py) end
                end
                if itemID then
                    local tbl
                    if skin then rec.s = rec.s or {}; tbl = rec.s else rec.d = rec.d or {}; tbl = rec.d end
                    tbl[itemID] = (tbl[itemID] or 0) + (qty or 1)
                end
            elseif kind == "obj" then
                local rec = SFP.db.objects[id]
                if not rec then rec = { n = SFP:RecentCastTarget() or ("Object " .. id), k = 0 }; SFP.db.objects[id] = rec end
                local nm = SFP:RecentCastTarget()
                if nm and (rec.n or ""):find("^Object %d+$") then rec.n = nm end
                if not seenGuid[guid] then
                    seenGuid[guid] = true
                    rec.k = (rec.k or 0) + 1
                    if map then addPoint(rec, map, px, py) end
                end
                if itemID then
                    rec.d = rec.d or {}
                    rec.d[itemID] = (rec.d[itemID] or 0) + (qty or 1)
                end
            end
        end
    end
    SFP.dropIndex = nil
end

---------------------------------------------------------------------------
-- Recipes (professions you open)
---------------------------------------------------------------------------
local function itemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function scanRecipes()
    if not SFP.db then return end
    local count = 0
    -- legacy trade skill window
    if GetNumTradeSkills and GetTradeSkillInfo then
        local prof = GetTradeSkillLine and GetTradeSkillLine() or "Profession"
        if prof == "UNKNOWN" then return end
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if name and kind ~= "header" then
                local out = GetTradeSkillItemLink and itemIDFromLink(GetTradeSkillItemLink(i))
                local reag = {}
                for r = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0) do
                    local rid = GetTradeSkillReagentItemLink and itemIDFromLink(GetTradeSkillReagentItemLink(i, r))
                    local _, _, cnt = GetTradeSkillReagentInfo(i, r)
                    if rid then reag[#reag + 1] = { rid, cnt or 1 } end
                end
                SFP.db.recipes[prof .. "|" .. name] = { n = name, p = prof, o = out, r = reag }
                count = count + 1
            end
        end
    -- modern trade skill API
    elseif C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
        local prof = base and base.professionName or "Profession"
        for _, rid in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
            local info = C_TradeSkillUI.GetRecipeInfo(rid)
            local schem = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(rid, false)
            if info and info.name and schem then
                local reag = {}
                for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
                    for _, rg in ipairs(slot.reagents or {}) do
                        if rg.itemID then reag[#reag + 1] = { rg.itemID, slot.quantityRequired or 1 }; break end
                    end
                end
                SFP.db.recipes[prof .. "|" .. info.name] = { n = info.name, p = prof, o = schem.outputItemID, r = reag }
                count = count + 1
            end
        end
    end
    if count > 0 then
        SFP.usedIn, SFP.madeBy = nil, nil
        SFP:Print(("Learned %d recipes of this profession."):format(count))
    end
end

local function buildRecipeIndex()
    SFP.usedIn, SFP.madeBy = {}, {}
    for key, r in pairs(SFP.db.recipes) do
        for _, rg in ipairs(r.r or {}) do
            local list = SFP.usedIn[rg[1]]
            if not list then list = {}; SFP.usedIn[rg[1]] = list end
            list[#list + 1] = key
        end
        if r.o then
            local list = SFP.madeBy[r.o]
            if not list then list = {}; SFP.madeBy[r.o] = list end
            list[#list + 1] = key
        end
    end
end

function SFP:RecipeIndex()
    if not self.usedIn then buildRecipeIndex() end
    return self.usedIn, self.madeBy
end

-- what a drop table looks like for items: itemID -> { {npcID, count}, ... }
function SFP:DropIndex()
    if self.dropIndex then return self.dropIndex end
    local idx = {}
    for npcID, rec in pairs(self.db.npcs) do
        for itemID, c in pairs(rec.d or {}) do
            local l = idx[itemID]; if not l then l = {}; idx[itemID] = l end
            l[#l + 1] = { npcID, c, "n" }
        end
        for itemID, c in pairs(rec.s or {}) do
            local l = idx[itemID]; if not l then l = {}; idx[itemID] = l end
            l[#l + 1] = { npcID, c, "s" }
        end
    end
    for objID, rec in pairs(self.db.objects) do
        for itemID, c in pairs(rec.d or {}) do
            local l = idx[itemID]; if not l then l = {}; idx[itemID] = l end
            l[#l + 1] = { objID, c, "o" }
        end
    end
    for _, l in pairs(idx) do table.sort(l, function(a, b) return a[2] > b[2] end) end
    self.dropIndex = idx
    return idx
end

---------------------------------------------------------------------------
-- Facts that are not in the game data
---------------------------------------------------------------------------
-- herbs that also give another herb when picked (Wowhead drop data)
SFP.AlsoGives = {
    [2450] = { 2452, "~39%" },   -- Briarthorn -> Swiftthistle
    [785]  = { 2452, "~20%" },   -- Mageroyal -> Swiftthistle
    [36901] = { 37921, "~32%" }, [36904] = { 37921, "~32%" }, [36907] = { 37921, "~31%" }, [36908] = { 37921, "~27%" }, -- -> Deadnettle
}

local GENERAL_USE = {
    herb = "Alchemy (potions, flasks) and Inscription (milled into pigments)",
    ore = "Blacksmithing, Engineering and Jewelcrafting (prospecting gems)",
    cloth = "Tailoring (cloth armor, bags)",
    leather = "Leatherworking and armor kits",
    meat = "Cooking",
    element = "many crafting professions",
    enchant = "Enchanting",
    mat = "crafting",
}

local SLOT_BY_EQUIP = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}

local function equippedLevel(slots)
    local best
    for _, s in ipairs(slots) do
        local link = GetInventoryItemLink("player", s)
        if not link then return 0 end -- an empty slot: anything is an upgrade
        local lvl = select(4, C_Item.GetItemInfo(link))
        if lvl then best = best and min(best, lvl) or lvl end
    end
    return best
end

local function money(c)
    if not c or c <= 0 then return "" end
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return floor(c / 10000) .. "g"
end

local function itemName(id)
    return SFP:ItemName(id)
end

local function recipeTexts(keys, limit)
    local out = {}
    for i = 1, min(limit, #keys) do
        local r = SFP.db.recipes[keys[i]]
        if r then out[#out + 1] = r.n .. " |cff808080(" .. (r.p or "?") .. ")|r" end
    end
    if #keys > limit then out[#out + 1] = "+" .. (#keys - limit) .. " more" end
    return table.concat(out, ", ")
end

-- the lines our addon adds to an item tooltip
function SFP:ItemTipLines(id)
    local lines = {}
    local name, _, q, ilvl, minLvl, itype, subtype, _, equip, _, price, classID = C_Item.GetItemInfo(id)
    if not name then return lines end
    local usedIn, madeBy = self:RecipeIndex()

    if q == 0 then
        lines[#lines + 1] = { "|cff9d9d9dVendor junk|r" .. (price and price > 0 and ("  sells for " .. money(price)) or "") }
    elseif classID == 7 then
        local kind = KIND_BY_SUBCLASS[select(13, C_Item.GetItemInfo(id)) or 0] or "mat"
        lines[#lines + 1] = { "|cff40d0ffCrafting material|r  " .. (subtype or "") }
        if usedIn[id] then
            lines[#lines + 1] = { "Used in: " .. recipeTexts(usedIn[id], 6), 0.85, 0.85, 0.85, true }
        else
            lines[#lines + 1] = { "Used for: " .. (GENERAL_USE[kind] or "crafting") .. "  |cff808080(open a profession window to learn exact recipes)|r", 0.85, 0.85, 0.85, true }
        end
    elseif (classID == 2 or classID == 4) and equip and equip ~= "" and SLOT_BY_EQUIP[equip] then
        local mine = equippedLevel(SLOT_BY_EQUIP[equip])
        local txt, r, g, b
        if mine == 0 then txt, r, g, b = "slot is empty - wear it", 0.3, 1, 0.3
        elseif mine and ilvl then
            local d = ilvl - mine
            if d >= 15 then txt, r, g, b = ("big upgrade (+%d item levels)"):format(d), 0.2, 1, 0.2
            elseif d >= 5 then txt, r, g, b = ("upgrade (+%d)"):format(d), 0.5, 1, 0.3
            elseif d > -5 then txt, r, g, b = "about the same as what you wear", 1, 0.85, 0.2
            else txt, r, g, b = ("below your gear (%d)"):format(d), 1, 0.4, 0.3 end
        end
        local need = (minLvl and minLvl > UnitLevel("player")) and ("  |cffff5050needs level " .. minLvl .. "|r") or ""
        lines[#lines + 1] = { "|cffb0b0ffGear|r  item level " .. (ilvl or "?") .. need }
        if txt then lines[#lines + 1] = { "Compared with your equipped: " .. txt, r, g, b } end
    end
    if madeBy[id] then
        lines[#lines + 1] = { "Craftable: " .. recipeTexts(madeBy[id], 3), 0.85, 0.85, 0.85, true }
    end
    local also = self.AlsoGives[id]
    if also then
        lines[#lines + 1] = { "Also gives: " .. itemName(also[1]) .. " " .. also[2], 0.6, 1, 0.6 }
    end
    local drops = self:DropIndex()[id]
    if drops then
        local out = {}
        for i = 1, min(3, #drops) do
            local d = drops[i]
            local nm
            if d[3] == "o" then nm = (self.db.objects[d[1]] or {}).n else nm = (self.db.npcs[d[1]] or {}).n end
            out[#out + 1] = (nm or "?") .. (d[3] == "s" and " (skinning)" or "") .. " x" .. d[2]
        end
        lines[#lines + 1] = { "Seen from: " .. table.concat(out, ", "), 0.7, 0.7, 0.7, true }
    end
    if not drops and self.QuestieItemSources then
        local src = self:QuestieItemSources(id)
        for _, line in ipairs(src or {}) do lines[#lines + 1] = { line, 0.7, 0.7, 0.7, true } end
    end
    local craft = SFP.CraftProfitLines and SFP:CraftProfitLines(id)
    for _, l in ipairs(craft or {}) do lines[#lines + 1] = l end
    return lines
end

-- farm mobs known from the shipped data: npcID -> items
local function buildSeeds()
    SFP.farmNpc = {}
    for _, list in pairs(SFP.Spawns or {}) do
        for _, sp in ipairs(list) do if sp.npc and sp.npc > 0 then SFP.farmNpc[sp.npc] = sp.items end end
    end
    for _, list in pairs(SFP.Rares or {}) do
        for _, sp in ipairs(list) do if sp.npc and sp.npc > 0 and sp.items and #sp.items > 0 then SFP.farmNpc[sp.npc] = sp.items end end
    end
end

-- true when our lines are already in this tooltip (hooks can fire more than once)
local function hasOurLines(tt)
    local n = tonumber(tt.NumLines and tt:NumLines()) or 0
    for i = n, 1, -1 do
        local fs = _G[(tt:GetName() or "GameTooltip") .. "TextLeft" .. i]
        local t = fs and fs.GetText and fs:GetText()
        if type(t) == "string" and t:find("Seviaths", 1, true) then return true end
    end
    return false
end

local function unitTip(tt, data)
    local function dbg(msg) if SFP.tipDebug then SFP:Print("unit tooltip: " .. msg) end end
    if not SFP.db or not SFP.db.tooltip then return dbg("tooltip lines are switched off") end
    local guid = data and data.guid
    local unit
    if not guid then
        local _, u = tt:GetUnit()
        unit = u
        guid = unit and UnitGUID(unit)
    end
    if not guid then return dbg("no unit in the tooltip") end
    local kind, id = guidInfo(guid)
    if kind ~= "npc" then return dbg("not a monster") end
    if unit and (UnitIsPlayer(unit) or UnitPlayerControlled(unit)) then return dbg("player or pet") end
    if hasOurLines(tt) then return end
    dbg("npc " .. id)
    local rec = SFP.db.npcs[id]
    local seed = SFP.farmNpc and SFP.farmNpc[id]
    tt:AddLine(" ")
    do
        local ql = SFP.QuestObjectiveNpc and SFP:QuestObjectiveNpc(id)
        local byName = not ql and unit and SFP.QuestsByMonsterName and SFP:QuestsByMonsterName(UnitName(unit))
        if byName then
            for i = 1, min(3, #byName) do tt:AddLine("|cffffd100! Quest:|r " .. byName[i], 1, 1, 1, true) end
        elseif not ql and unit and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest and select(2, pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)) then
            tt:AddLine("|cffffd100! Needed for one of your quests|r")
        end
    end
    tt:AddLine("|c" .. SFP.CYAN_HEX .. "Seviaths|r  |cff808080NPC " .. id .. "|r" ..
        (rec and rec.k and rec.k > 0 and ("  |cff808080" .. rec.k .. " kills seen|r") or ""))
    local list = {}
    for itemID, c in pairs(rec and rec.d or {}) do list[#list + 1] = { itemID, c } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local kills = max(1, rec and rec.k or 1)
    for i = 1, min(8, #list) do
        local e = list[i]
        tt:AddDoubleLine("|T" .. SFP:ItemIcon(e[1]) .. ":12|t " .. SFP:ItemName(e[1]),
            string.format("%d%%", min(100, floor(e[2] * 100 / kills + 0.5))), 1, 1, 1, 0.7, 0.7, 0.7)
    end
    if rec and rec.s then
        local sk = {}
        for itemID, c in pairs(rec.s) do sk[#sk + 1] = { itemID, c } end
        table.sort(sk, function(a, b) return a[2] > b[2] end)
        for i = 1, min(3, #sk) do
            tt:AddDoubleLine("|T" .. SFP:ItemIcon(sk[i][1]) .. ":12|t " .. SFP:ItemName(sk[i][1]), "skinning", 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end
    local shown = #list > 0
    if not shown and seed then
        for i = 1, min(6, #seed) do
            tt:AddLine("|T" .. SFP:ItemIcon(seed[i]) .. ":12|t " .. SFP:ItemName(seed[i]) .. "  |cff808080(farm target)|r")
        end
        shown = true
    end
    if not shown and SFP.QuestieDropsOf then
        local known = SFP:QuestieDropsOf(id)
        for i = 1, min(6, known and #known or 0) do
            tt:AddLine("|T" .. SFP:ItemIcon(known[i]) .. ":12|t " .. SFP:ItemName(known[i]) .. "  |cff808080(database)|r")
            shown = true
        end
    end
    -- quests it gives or takes (Questie database)
    local Q, N = SFP.QDB and SFP.QDB.Quest, SFP.QDB and SFP.QDB.Npc
    if Q and N and not (SFP.QuestMarkers and SFP.QuestMarkers.enabled == false) then
        local ok, starts = pcall(N.questStarts, id)
        if ok and starts and #starts > 0 then
            local names = {}
            for i = 1, #starts do
                local qm = SFP.QuestMarkers
                if #names < 3 and (not qm or qm:IsAvailable(starts[i])) then
                    local okn, nm = pcall(Q.name, starts[i])
                    names[#names + 1] = okn and nm or ("quest " .. starts[i])
                end
            end
            if #names > 0 then tt:AddLine("Starts: " .. table.concat(names, ", "), 0.6, 1, 0.6, true) end
        end
    end
    local worth = SFP.GatherLines and (function()
        local u = unit or ((guid and UnitGUID("mouseover") == guid) and "mouseover") or "target"
        return SFP:GatherLines("n", id, UnitCreatureType(u), UnitLevel(u), UnitName(u))
    end)()
    if worth then
        for _, l in ipairs(worth) do tt:AddLine(l[1], l[2], l[3], l[4], true) end
    end
    local objq = SFP.QuestObjectiveNpc and SFP:QuestObjectiveNpc(id)
    if objq then
        for i = 1, min(4, #objq) do tt:AddLine("|cffffd24aQuest|r " .. objq[i], 1, 0.9, 0.5, true) end
    end
    if not shown then
        tt:AddLine("No drops learned yet - kill it and loot to record them", 0.5, 0.5, 0.5, true)
    end
    tt:Show()
end

local function itemTip(tt, data)
    if not SFP.db or not SFP.db.tooltip then return end
    local id = data and data.id
    if not id then
        local _, link = tt:GetItem()
        id = itemIDFromLink(link)
    end
    if not id then return end
    local lines = SFP:ItemTipLines(id)
    if #lines == 0 then return end
    tt:AddLine(" ")
    tt:AddLine("|c" .. SFP.CYAN_HEX .. "Seviaths|r")
    for _, l in ipairs(lines) do
        tt:AddLine(l[1], l[2] or 1, l[3] or 1, l[4] or 1, l[5] and true or false)
    end
    tt:Show()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "LOOT_READY", "UNIT_SPELLCAST_SENT",
    "GET_ITEM_INFO_RECEIVED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "BAG_UPDATE_DELAYED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
local recipeTimer
ev:SetScript("OnEvent", function(_, event, a, b, c, d)
    -- "Learn everything constantly" off: nothing new is recorded (tooltips keep working)
    if SFP.db and SFP.db.learnAll == false and (event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_TARGET_CHANGED"
        or event == "LOOT_READY" or event == "BAG_UPDATE_DELAYED" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE") then
        return
    end
    if not SFP.db then return end
    if event == "UPDATE_MOUSEOVER_UNIT" then
        SFP:Safe("record mouseover", recordUnit, "mouseover")
        C_Timer.After(0.05, function()
            if GameTooltip:IsShown() and UnitExists("mouseover") then SFP:Safe("monster tooltip", unitTip, GameTooltip) end
        end)
    elseif event == "PLAYER_TARGET_CHANGED" then
        SFP:Safe("record target", recordUnit, "target")
    elseif event == "LOOT_READY" then
        SFP:Safe("record loot", onLoot)
    elseif event == "UNIT_SPELLCAST_SENT" then
        if a == "player" then
            local spellID = d or c
            local nm = type(spellID) == "number" and GetSpellInfo and GetSpellInfo(spellID)
            if nm and (gatherNames[nm] or skinNames[nm]) then
                lastCast.name, lastCast.target, lastCast.t = nm, b, GetTime()
            end
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if a and pendingItems[a] then recordItem(a) end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- items that arrived another way (mail, quests, vendors) are learned too
        SFP:Safe("record bags", function()
            for bag = 0, 4 do
                local n = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
                    or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
                for slot = 1, n do
                    local link = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
                        or (GetContainerItemLink and GetContainerItemLink(bag, slot))
                    local id = itemIDFromLink(link)
                    if id and not SFP.db.knownItems[id] then recordItem(id) end
                end
            end
        end)
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        if not recipeTimer then
            recipeTimer = true
            C_Timer.After(1.5, function() recipeTimer = nil; SFP:Safe("scan recipes", scanRecipes) end)
        end
    end
end)

SFP:OnLogin(function()
    initSpellNames()
    buildSeeds()
    -- items we already know that are materials join the farm list straight away
    for id in pairs(SFP.db.knownItems) do SFP:ClassifyItem(id) end
    local TT = Enum and Enum.TooltipDataType
    local okUnit, okItem = false, false
    if TooltipDataProcessor and TT and TT.Unit then
        okUnit = pcall(TooltipDataProcessor.AddTooltipPostCall, TT.Unit, function(tt, data) if tt == GameTooltip then unitTip(tt, data) end end)
    end
    if TooltipDataProcessor and TT and TT.Item then
        okItem = pcall(TooltipDataProcessor.AddTooltipPostCall, TT.Item, function(tt, data) if tt == GameTooltip then itemTip(tt, data) end end)
    end
    -- both hooks may fire: once per tooltip is enough
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) unitTip(tt) end)
    if not okItem then pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", itemTip) end
end)

---------------------------------------------------------------------------
-- Codex bridge: what you met becomes Codex pages (called while the Codex indexes)
---------------------------------------------------------------------------
function SFP:FeedLearned(cx)
    if not (cx and cx.Add and self.db) then return end
    local c = cx.CYAN or ""
    local function dropText(tbl, kills)
        local list = {}
        for itemID, n in pairs(tbl or {}) do list[#list + 1] = { itemID, n } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        local out = {}
        for i = 1, min(12, #list) do
            out[#out + 1] = "• " .. self:ItemName(list[i][1]) .. ("  %d%%"):format(min(100, floor(list[i][2] * 100 / max(1, kills) + 0.5)))
        end
        return table.concat(out, "\n")
    end
    for id, rec in pairs(self.db.npcs) do
        local where = {}
        local mapFirst
        for map, pts in pairs(rec.m or {}) do
            where[#where + 1] = self:ZoneName(map)
            mapFirst = mapFirst or { map, pts[1] }
        end
        local lvl = rec.lmin and (rec.lmin == rec.lmax and tostring(rec.lmin) or (rec.lmin .. "-" .. rec.lmax)) or "?"
        local body = c .. "Monster|r  ID " .. id .. "\n" ..
            "Level " .. lvl .. (rec.t and ("  " .. rec.t) or "") .. (rec.f and ("  " .. rec.f) or "") ..
            (rec.c and ("  " .. rec.c) or "") ..
            (#where > 0 and ("\n\n" .. c .. "Seen in|r\n" .. table.concat(where, ", ")) or "") ..
            ((rec.d and next(rec.d)) and ("\n\n" .. c .. "Drops (" .. (rec.k or 0) .. " kills)|r\n" .. dropText(rec.d, rec.k)) or "") ..
            ((rec.s and next(rec.s)) and ("\n\n" .. c .. "Skinning|r\n" .. dropText(rec.s, rec.sk)) or "")
        cx:Add({
            cat = "creature", id = "sut:npc:" .. id, name = rec.n,
            group = "Monsters you have met (" .. (where[1] or "unknown") .. ")",
            icon = "Interface\\Icons\\Ability_Warrior_Revenge",
            sub = lvl .. (rec.t and (" " .. rec.t) or ""), body = body,
            map = mapFirst and { m = mapFirst[1], x = mapFirst[2][1], y = mapFirst[2][2] } or nil,
            wh = "npc=" .. id, tags = "monster npc " .. (rec.t or "") .. " " .. (rec.f or ""),
        })
    end
    local usedIn = self:RecipeIndex()
    for itemID, keys in pairs(usedIn) do
        local name = C_Item.GetItemInfo(itemID)
        if name then
            cx:Add({
                cat = "material", id = "sut:mat:" .. itemID, name = name, group = "What it is used for",
                icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom", itemID = itemID,
                sub = #keys .. " recipes", body = c .. "Used in|r\n" .. recipeTexts(keys, 40):gsub(", ", "\n"),
                wh = "item=" .. itemID, tags = "material reagent mats",
            })
        end
    end
end
