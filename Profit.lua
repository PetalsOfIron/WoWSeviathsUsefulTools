-- SeviathsUsefulTools - what gathering and crafting is worth, from auction house prices
-- * hover a plant / ore / animal: value per gather, and whether another one is worth more
-- * hover a crafted item: cost of its reagents against what it sells for
-- * /sfp craft: the most profitable recipes you know
local _, SFP = ...

local floor, min = math.floor, math.min
local AH_CUT = 0.05

local function money(c)
    c = floor((c or 0) + 0.5)
    local neg = c < 0
    if neg then c = -c end
    local s
    if GetCoinTextureString then s = GetCoinTextureString(c) else s = floor(c / 10000) .. "g" end
    return (neg and "-" or "") .. s
end

-- copper for one item: auction house price, else what a vendor pays
local function price(id)
    local p = SFP:GetPrice(id)
    if p and p > 0 then return p, true end
    local sell = select(11, GetItemInfo(id))
    return sell or 0, false
end

---------------------------------------------------------------------------
-- gathering
---------------------------------------------------------------------------
local function dropValue(drops, count)
    local v = 0
    if not drops or not count or count <= 0 then return 0 end
    -- few kills: do not trust "dropped every time" (1 of 1 kills counts as 50%)
    local n = count < 5 and count + 1 or count
    for id, c in pairs(drops) do
        v = v + (c / n) * (price(id))
    end
    return v
end

local GROUP_BY_SUBCLASS = { [9] = "herb", [7] = "ore" }

local function groupOf(rec, isObject)
    if not isObject then return "skin" end
    local best, bestc = nil, 0
    for id, c in pairs(rec.d or {}) do
        local sub = select(13, GetItemInfo(id))
        local g = GROUP_BY_SUBCLASS[sub]
        if g and c > bestc then best, bestc = g, c end
    end
    return best or "node"
end

local GROUP_NAME = { herb = "herbs", ore = "ore veins", skin = "animals to skin", node = "nodes" }

-- value of one gather of every record you know, per group
local cache, cacheT
local function rankings()
    if cache and cacheT and GetTime() - cacheT < 20 then return cache end
    local groups = { herb = {}, ore = {}, skin = {}, node = {} }
    for id, rec in pairs(SFP.db.objects or {}) do
        if (rec.k or 0) >= 3 then
            local v = dropValue(rec.d, rec.k)
            if v > 0 then
                table.insert(groups[groupOf(rec, true)], { kind = "o", id = id, name = rec.n or ("Object " .. id), v = v, k = rec.k })
            end
        end
    end
    for id, rec in pairs(SFP.db.npcs or {}) do
        local n = rec.sk or (rec.s and rec.k) or 0
        if rec.s and n >= 3 then
            local v = dropValue(rec.s, n)
            if v > 0 then table.insert(groups.skin, { kind = "n", id = id, name = rec.n or ("NPC " .. id), v = v, k = n }) end
        end
    end
    for _, l in pairs(groups) do table.sort(l, function(a, b) return a.v > b.v end) end
    cache, cacheT = groups, GetTime()
    return groups
end

-- what the monsters of a creature type usually drop in this zone, from the zone's farm items (Data/Expansions)
-- group of items per creature type, and a typical drop rate per kill (an estimate, not a measurement)
local TYPE_GROUP = { Humanoid = "cloth", Undead = "cloth", Beast = "leather", Dragonkin = "leather", Elemental = "element" }
local GROUP_LABEL = { cloth = "cloth", leather = "leather / scales", element = "elemental motes" }
local GROUP_RATE = { cloth = 0.5, leather = 0.9, element = 0.4 }
local GROUP_OWNER = { cloth = "humanoids and undead", leather = "beasts and dragonkin", element = "elementals" }

local function zoneGroups()
    local zone = SFP.PlayerFarmZone and SFP:PlayerFarmZone()
    local z = zone and SFP.zoneByMap and SFP.zoneByMap[zone]
    if not (z and z.items) then return nil end
    local out = {}
    for id in pairs(z.items) do
        local info = SFP.Items[id]
        local g = info and (info.kind == "meat" and "leather" or info.kind)
        if g and GROUP_RATE[g] then
            SFP.trackedIDs[id] = true
            local p = price(id)
            if p > 0 and (not out[g] or p > out[g].p) then out[g] = { id = id, p = p } end
        end
    end
    return out
end

local function typicalLines(typeName, add)
    local g = typeName and TYPE_GROUP[typeName]
    local groups = zoneGroups()
    if not (g and groups) then return false end
    local mine = groups[g]
    if not mine then return false end
    local value = mine.p * GROUP_RATE[g]
    add("|cffffd100Typical drop here|r  " .. SFP:ItemName(mine.id) .. " " .. money(mine.p) .. "  =>  ~" .. money(value) .. " per kill  |cff808080(estimate)|r")
    local bestG, bestV
    for k, e in pairs(groups) do
        local v = e.p * GROUP_RATE[k]
        if not bestV or v > bestV then bestG, bestV = k, v end
    end
    if bestG == g then
        add("Best mob drop of this zone: worth grinding " .. GROUP_OWNER[g], 0.3, 1, 0.3)
    elseif value >= bestV * 0.6 then
        add("Fine - close to the best (" .. GROUP_OWNER[bestG] .. ", ~" .. money(bestV) .. " per kill)", 0.3, 1, 0.3)
    else
        add("Better here: " .. GROUP_OWNER[bestG] .. " (~" .. money(bestV) .. " per kill)", 1, 0.9, 0.3)
    end
    return true, value
end

-- items the addon lists for a monster (farm data and the quest database), with auction house prices
local function listedDrops(npcID)
    local set, list = {}, {}
    local function add(id)
        if id and not set[id] then set[id] = true; list[#list + 1] = id end
    end
    for _, id in ipairs(SFP.farmNpc and SFP.farmNpc[npcID] or {}) do add(id) end
    for _, id in ipairs(SFP.QuestieDropsOf and SFP:QuestieDropsOf(npcID) or {}) do add(id) end
    local rows = {}
    for _, id in ipairs(list) do
        SFP.trackedIDs[id] = true   -- the next auction scan covers it
        local p, ah = price(id)
        rows[#rows + 1] = { id = id, p = p, ah = ah }
    end
    table.sort(rows, function(a, b) return a.p > b.p end)
    return rows
end

-- every monster the addon has drop data for (Data/Materials: item -> monsters with drop chance), valued at auction prices
local nameLevel, nameLevelState = {}, 0
local function ensureNameLevels()
    if nameLevelState ~= 0 then return end
    local N = SFP.QDB and SFP.QDB.Npc
    local ids = N and N.GetAllIds and N.GetAllIds()
    if not ids then nameLevelState = -1; return end
    nameLevelState = 1
    local i, total = 1, #ids
    local function step()
        for _ = 1, 500 do
            local id = ids[i]
            if not id then break end
            local nm = N.name(id)
            if nm and not nameLevel[nm] then
                local lo, hi = N.minLevel(id), N.maxLevel(id)
                if lo and lo > 0 then nameLevel[nm] = { lo, hi or lo, N.zoneID(id) } end
            end
            i = i + 1
        end
        if i <= total then C_Timer.After(0.03, step) else nameLevelState = 2 end
    end
    C_Timer.After(3, step)
end

-- item subtype (Data/Materials "s") dropped by each creature type
local TYPE_SUBS = { Humanoid = { [5] = true }, Undead = { [5] = true }, Beast = { [8] = true, [6] = true },
    Dragonkin = { [6] = true }, Elemental = { [10] = true }, Mechanical = { [1] = true, [3] = true } }

local mobCache, mobCacheT
local function materialMobs()
    if mobCache and GetTime() - mobCacheT < 30 then return mobCache end
    local mobs = {}   -- name -> { v = {sub -> value per kill}, zone }
    for itemID, m in pairs(SFP.MaterialData or {}) do
        if m.d and m.s and (m.q or 1) >= 0 then
            local p = price(itemID)
            if p > 0 then
                SFP.trackedIDs[itemID] = true
                for _, e in ipairs(m.d) do
                    local nm, zone, pct = e[1], e[2], e[3]
                    if nm and pct and pct > 0 and not nm:find("^%[") then
                        local t = mobs[nm]
                        if not t then t = { v = {}, zone = zone }; mobs[nm] = t end
                        t.v[m.s] = (t.v[m.s] or 0) + p * pct / 100
                    end
                end
            end
        end
    end
    mobCache, mobCacheT = mobs, GetTime()
    return mobs
end

local function knownMobs(typeName, lvl, excludeName)
    local subs = TYPE_SUBS[typeName]
    local out = {}
    if not (subs and lvl) then return out end
    ensureNameLevels()
    if nameLevelState ~= 2 then return out end
    for nm, t in pairs(materialMobs()) do
        local lv = nameLevel[nm]
        if lv and nm ~= excludeName and lv[1] <= lvl + 4 and lv[2] >= lvl - 4 then
            local v = 0
            for sub in pairs(subs) do v = v + (t.v[sub] or 0) end
            if v > 0 then
                local map = SFP.QD and SFP.QD.areaToMap and SFP.QD.areaToMap[lv[3] or t.zone]
                out[#out + 1] = { name = nm, v = v, lvl = lv[2], zone = map and SFP:ZoneName(map) or nil }
            end
        end
    end
    return out
end

-- all monsters of the SAME creature type around your level (learned loot + the addon's drop data), best first
local function sameTypeAdvice(typeName, lvl, ownV, excludeId, add, ownName)
    if not typeName then return false end
    local byName = {}
    for oid, o in pairs(SFP.db.npcs) do
        local ol = o.lmax or o.lmin
        if oid ~= excludeId and o.t == typeName and o.d and (o.k or 0) >= 1 and (not lvl or not ol or math.abs(ol - lvl) <= 4) then
            local nm = o.n or ("NPC " .. oid)
            local map = o.m and next(o.m)
            byName[nm] = { name = nm, v = dropValue(o.d, o.k), lvl = ol, zone = map and SFP:ZoneName(map) or nil, mine = true }
        end
    end
    for _, e in ipairs(knownMobs(typeName, lvl, ownName)) do
        local c = byName[e.name]
        if not c then byName[e.name] = e
        elseif e.v > c.v then e.mine = c.mine; byName[e.name] = e end
    end
    local list = {}
    for _, e in pairs(byName) do list[#list + 1] = e end
    list[#list + 1] = { name = ownName or "this monster", v = ownV, lvl = lvl, self = true }
    table.sort(list, function(a, b) return a.v > b.v end)
    local others = #list - 1
    if others == 0 then
        add("No other " .. typeName:lower() .. " of your level known yet - kill and loot some to compare", 0.6, 0.6, 0.6)
        return true
    end
    add("|cffffd100" .. (typeName == "Undead" and typeName or typeName .. "s") .. " around level " .. ((lvl or 0) - 4) .. "-" .. ((lvl or 0) + 4) .. "|r (auction prices, " .. others .. " compared):", 0.9, 0.9, 0.9)
    local shown, topOther = 0, nil
    for rank, e in ipairs(list) do
        if not e.self and not topOther then topOther = e.v end
        if shown < 5 or e.self then
            shown = shown + 1
            local where = (e.zone and (e.zone .. ", ") or "") .. (e.lvl and ("lvl " .. e.lvl) or "")
            local label = rank .. ". " .. e.name .. (e.self and "  |cff40ff40<- this one|r" or "") .. (where ~= "" and ("  |cff808080(" .. where .. ")|r") or "") .. "  ~" .. money(e.v)
            if e.self then add(label, 0.6, 1, 0.6) else add(label, 0.85, 0.85, 0.85) end
        end
    end
    return true, topOther
end

-- one clear answer: is it worth grinding?
local function verdict(own, bestOther)
    if not own then return { "|cffffd100Worth grinding:|r unknown - open the auction house for prices", 0.7, 0.7, 0.7 } end
    if bestOther and bestOther > 0 then
        local r = own / bestOther
        if r >= 0.85 then return { "|cffffd100Worth grinding:|r |cff40ff40YES|r - as good as the best you know (~" .. money(own) .. " per kill)", 0.8, 1, 0.8 } end
        if r >= 0.5 then return { "|cffffd100Worth grinding:|r |cffffd040MAYBE|r - ~" .. money(own) .. " per kill, better ones exist", 1, 0.95, 0.7 } end
        return { "|cffffd100Worth grinding:|r |cffff6040NO|r - ~" .. money(own) .. " per kill, much better ones exist", 1, 0.75, 0.7 }
    end
    -- nothing to compare with yet: judge the amount itself
    if own >= 5000 then return { "|cffffd100Worth grinding:|r |cff40ff40YES|r - ~" .. money(own) .. " per kill  |cff808080(no comparison yet)|r", 0.8, 1, 0.8 } end
    if own >= 1500 then return { "|cffffd100Worth grinding:|r |cffffd040MAYBE|r - ~" .. money(own) .. " per kill  |cff808080(no comparison yet)|r", 1, 0.95, 0.7 } end
    return { "|cffffd100Worth grinding:|r |cffff6040NO|r - only ~" .. money(own) .. " per kill  |cff808080(no comparison yet)|r", 1, 0.75, 0.7 }
end

-- lines for the tooltip of a monster (kind "n") or a gathering node (kind "o")
function SFP:GatherLines(kind, id, creatureType, unitLevel, unitName)
    local rec = (kind == "o" and self.db.objects or self.db.npcs)[id]
    if not rec then
        if kind ~= "n" then return nil end
        rec = {}   -- never seen it die: the listed items still say something
    end
    local lines = {}
    local function add(t, r, g, b) lines[#lines + 1] = { t, r or 1, g or 1, b or 1 } end
    local ownV, cmpV   -- value per kill of this monster and of the best other one of its type
    -- loot of a kill
    if kind == "n" and rec.d and (rec.k or 0) >= 1 then
        local v = dropValue(rec.d, rec.k)
        ownV = v
        add("|cffffd100Loot worth|r ~" .. money(v) .. " per kill  |cff808080(" .. rec.k .. " kill" .. (rec.k == 1 and "" or "s") ..
            (rec.k < 5 and ", few samples" or "") .. ")|r")
        -- is it worth farming? compare with the monsters of about the same level you know
        local lvl = rec.lmax or rec.lmin or unitLevel
        local typeName = creatureType or rec.t
        local sameOk
        if typeName then sameOk, cmpV = sameTypeAdvice(typeName, lvl, v, id, add, rec.n) end
        if sameOk then
            -- same creature type compared (humanoid with humanoids, beast with beasts ...)
        elseif lvl then
            local best, count, better = nil, 0, 0
            for oid, o in pairs(SFP.db.npcs) do
                local ol = o.lmax or o.lmin
                if oid ~= id and o.d and (o.k or 0) >= 2 and ol and math.abs(ol - lvl) <= 3 then
                    local ov = dropValue(o.d, o.k)
                    count = count + 1
                    if ov > v then better = better + 1 end
                    if not best or ov > best.v then best = { name = o.n or ("NPC " .. oid), v = ov, lvl = ol } end
                end
            end
            if count >= 2 then
                if better == 0 then
                    add("Best of the " .. (count + 1) .. " level " .. (lvl - 3) .. "-" .. (lvl + 3) .. " monsters you know - worth farming", 0.3, 1, 0.3)
                elseif v >= best.v * 0.7 then
                    add("Good: close to the best nearby (" .. best.name .. " ~" .. money(best.v) .. ")", 0.3, 1, 0.3)
                elseif v >= best.v * 0.4 then
                    add("Average - better: " .. best.name .. " ~" .. money(best.v) .. " per kill", 1, 0.9, 0.3)
                else
                    add("Not worth farming - go for " .. best.name .. " ~" .. money(best.v) .. " per kill", 1, 0.4, 0.3)
                end
            elseif v <= 0 then
                add("Drops nothing of value", 1, 0.4, 0.3)
            end
        end
    end
    -- no loot learned yet: judge it by the items the addon lists for it, at auction house prices
    local learnedLoot = kind == "n" and rec.d and next(rec.d) and (rec.k or 0) >= 1
    if kind == "n" and not learnedLoot then
        local rows = listedDrops(id)
        local typical, tval = typicalLines(creatureType or rec.t, add)
        ownV = tval
        if (creatureType or rec.t) then
            local _, bv = sameTypeAdvice(creatureType or rec.t, rec.lmax or rec.lmin or unitLevel, tval or 0, id, add, rec.n or unitName)
            cmpV = bv
        end
        if #rows > 0 then
            local total = 0
            for _, r in ipairs(rows) do total = total + r.p end
            add("|cffffd100Listed drops|r (auction prices, drop chance unknown):")
            for i = 1, math.min(4, #rows) do
                local r = rows[i]
                add("  " .. SFP:ItemName(r.id) .. "  " .. (r.p > 0 and money(r.p) or "no price") .. (r.ah and "" or (r.p > 0 and "  |cff808080(vendor)|r" or "")))
            end
            if #rows > 4 then add("  +" .. (#rows - 4) .. " more", 0.6, 0.6, 0.6) end
            local best = rows[1]
            if not ownV and best.p > 0 then ownV = best.p * 0.25 end   -- listed items: drop chance unknown, rough guess
            if best.p <= 0 then
                add("No price known yet - open the auction house once", 0.6, 0.6, 0.6)
            elseif best.p < 50000 then
                add("Cheap drops: probably not worth farming for gold", 1, 0.5, 0.3)
            else
                add("Best drop " .. SFP:ItemName(best.id) .. " sells for " .. money(best.p) .. " - worth a look", 0.3, 1, 0.3)
            end
        elseif not typical then
            add("No drops known for it yet - kill it and loot to learn them", 0.6, 0.6, 0.6)
        end
    end
    if kind == "n" then table.insert(lines, 1, verdict(ownV, cmpV)) end
    local groups = rankings()
    local group, own, samples
    if kind == "o" then
        if (rec.k or 0) < 1 then return #lines > 0 and lines or nil end
        group, samples = groupOf(rec, true), rec.k
        own = dropValue(rec.d, rec.k)
    else
        local n = rec.sk or (rec.s and rec.k) or 0
        if not (rec.s and n > 0) then return #lines > 0 and lines or nil end
        group, samples = "skin", n
        own = dropValue(rec.s, n)
    end
    local verb = kind == "o" and "per gather" or "per skin"
    local list = groups[group] or {}
    add("|cffffd100Worth|r ~" .. money(own) .. " " .. verb .. (samples < 5 and "  |cff808080(few samples)|r" or ""))
    local best = list[1]
    if best and #list >= 2 then
        local rank
        for i, e in ipairs(list) do if e.kind == kind and e.id == id then rank = i; break end end
        local vr = own / math.max(best.v, 1)
        table.insert(lines, 1, { "|cffffd100" .. (kind == "o" and "Worth gathering:" or "Worth skinning:") .. "|r " .. (vr >= 0.85 and "|cff40ff40YES|r" or vr >= 0.5 and "|cffffd040MAYBE|r" or "|cffff6040NO|r") ..
            " - ~" .. money(own) .. " " .. verb, 0.9, 0.95, 0.8 })
        if best.kind == kind and best.id == id then
            add("Best of the " .. #list .. " " .. GROUP_NAME[group] .. " you know - worth grinding", 0.3, 1, 0.3)
        elseif own >= best.v * 0.8 then
            add("Close to the best (" .. best.name .. " ~" .. money(best.v) .. ") - fine to grind", 0.3, 1, 0.3)
        elseif own >= best.v * 0.5 then
            add("Better: " .. best.name .. " ~" .. money(best.v) .. " " .. verb, 1, 0.9, 0.3)
        else
            add("Not worth grinding - go for " .. best.name .. " ~" .. money(best.v) .. " " .. verb, 1, 0.4, 0.3)
        end
        if rank then add("Rank " .. rank .. " of " .. #list, 0.6, 0.6, 0.6) end
    end
    return lines
end

---------------------------------------------------------------------------
-- crafting
---------------------------------------------------------------------------
-- best recipe that makes this item: { cost, missing, sell, profit, recipe }
function SFP:CraftProfit(itemID)
    local _, madeBy = self:RecipeIndex()
    local keys = madeBy and madeBy[itemID]
    if not keys then return nil end
    local sell = price(itemID)
    local best
    for _, key in ipairs(keys) do
        local r = self.db.recipes[key]
        if r and r.r and #r.r > 0 then
            local cost, missing = 0, 0
            for _, rg in ipairs(r.r) do
                local p = price(rg[1])
                if p <= 0 then missing = missing + 1 end
                cost = cost + p * (rg[2] or 1)
            end
            local profit = sell * (1 - AH_CUT) - cost
            if not best or profit > best.profit then
                best = { cost = cost, missing = missing, sell = sell, profit = profit, recipe = r }
            end
        end
    end
    return best
end

function SFP:CraftProfitLines(itemID)
    local c = self:CraftProfit(itemID)
    if not c then return nil end
    local lines = {}
    lines[#lines + 1] = { "|cffffd100Crafting|r  materials cost " .. money(c.cost) .. (c.missing > 0 and ("  |cff808080(" .. c.missing .. " price unknown)|r") or "") }
    if c.sell > 0 then
        local r, g, b = 0.3, 1, 0.3
        if c.profit < 0 then r, g, b = 1, 0.4, 0.3 end
        lines[#lines + 1] = { "Sells for " .. money(c.sell) .. " (after the 5% cut " .. money(c.sell * (1 - AH_CUT)) .. ")  =>  " ..
            (c.profit >= 0 and "gain " or "loss ") .. money(math.abs(c.profit)), r, g, b }
    else
        lines[#lines + 1] = { "No auction house price for the item yet", 0.6, 0.6, 0.6 }
    end
    return lines
end

-- the most profitable recipes you know
function SFP:PrintCraftProfit()
    local rows = {}
    for _, r in pairs(self.db.recipes or {}) do
        if r.o and r.r and #r.r > 0 then
            local c = self:CraftProfit(r.o)
            if c and c.sell > 0 and c.missing == 0 then rows[#rows + 1] = { name = r.n, prof = r.p, c = c } end
        end
    end
    table.sort(rows, function(a, b) return a.c.profit > b.c.profit end)
    if #rows == 0 then
        self:Print("No recipe with known prices yet: open your professions and scan the auction house first.")
        return
    end
    self:Print("Most profitable crafts (materials from the auction house, 5% cut):")
    for i = 1, min(10, #rows) do
        local e = rows[i]
        self:Print(("%d. %s (%s): cost %s, sells %s, %s %s"):format(i, e.name, e.prof or "?", money(e.c.cost), money(e.c.sell),
            e.c.profit >= 0 and "gain" or "loss", money(math.abs(e.c.profit))))
    end
    local worst = rows[#rows]
    if worst.c.profit < 0 then self:Print(("Worst: %s loses %s each."):format(worst.name, money(-worst.c.profit))) end
end

---------------------------------------------------------------------------
-- make the AH scan cover what is needed here, and hover on gathering nodes
---------------------------------------------------------------------------
local function track()
    for _, rec in pairs(SFP.db.objects or {}) do for id in pairs(rec.d or {}) do SFP.trackedIDs[id] = true end end
    for _, rec in pairs(SFP.db.npcs or {}) do for id in pairs(rec.s or {}) do SFP.trackedIDs[id] = true end end
    for _, r in pairs(SFP.db.recipes or {}) do
        if r.o then SFP.trackedIDs[r.o] = true end
        for _, rg in ipairs(r.r or {}) do SFP.trackedIDs[rg[1]] = true end
    end
end

SFP:OnLogin(function()
    SFP:Safe("profit track", track)
    C_Timer.After(8, function() SFP:Safe("monster levels", ensureNameLevels) end)
    if TooltipDataProcessor and Enum.TooltipDataType and Enum.TooltipDataType.Object then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Object, function(tt, data)
            if tt ~= GameTooltip or not SFP.db or not SFP.db.tooltip then return end
            SFP:Safe("gather tooltip", function()
                local guid = data and data.guid
                local t, _, _, _, _, id = strsplit("-", guid or "")
                if t ~= "GameObject" then return end
                local lines = SFP:GatherLines("o", tonumber(id))
                if lines then
                    tt:AddLine(" ")
                    for _, l in ipairs(lines) do tt:AddLine(l[1], l[2], l[3], l[4], true) end
                    tt:Show()
                end
            end)
        end)
    end
    -- learned something new: refresh what the scan covers and the cached ranking
    C_Timer.NewTicker(60, function() cache = nil; SFP:Safe("profit track", track) end)
end)
