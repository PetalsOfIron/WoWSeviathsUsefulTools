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
    for id, c in pairs(drops) do
        v = v + (c / count) * (price(id))
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

-- lines for the tooltip of a monster (kind "n") or a gathering node (kind "o")
function SFP:GatherLines(kind, id)
    local rec = (kind == "o" and self.db.objects or self.db.npcs)[id]
    if not rec then return nil end
    local lines = {}
    local function add(t, r, g, b) lines[#lines + 1] = { t, r or 1, g or 1, b or 1 } end
    -- loot of a kill
    if kind == "n" and rec.d and (rec.k or 0) >= 3 then
        local v = dropValue(rec.d, rec.k)
        if v > 0 then add("|cffffd100Loot worth|r ~" .. money(v) .. " per kill  |cff808080(" .. rec.k .. " kills)|r") end
    end
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
