-- SeviathsUsefulTools - guide pages: every crafting material and every mount
--
-- Data/Materials.lua  (every trade goods item of Classic to Mists: what it is used for, where to get it)
-- Data/Mounts.lua     (every mount: the item, who drops or sells it, quest / achievement sources)
-- both collected from Wowhead's Mists of Pandaria Classic pages. This file turns them into Codex
-- pages with plain steps, and merges what you learned yourself (recipes of your professions).

local ADDON, SFP = ...

local SKILL = {
    [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering", [773] = "Inscription",
    [755] = "Jewelcrafting", [165] = "Leatherworking", [197] = "Tailoring", [185] = "Cooking", [129] = "First Aid",
    [186] = "Mining", [182] = "Herbalism", [393] = "Skinning", [356] = "Fishing", [794] = "Archaeology",
}
local SUB = {
    [0] = "Trade goods", [1] = "Parts", [2] = "Explosives", [3] = "Devices", [4] = "Jewelcrafting materials",
    [5] = "Cloth", [6] = "Leather", [7] = "Metal & stone", [8] = "Cooking ingredients", [9] = "Herbs",
    [10] = "Elemental", [11] = "Other materials", [12] = "Enchanting materials", [13] = "Materials",
    [14] = "Item enchantments", [15] = "Weapon enchantments", [16] = "Inscription materials",
}
local SOURCE = {
    [1] = "crafted", [2] = "drop", [3] = "PvP", [4] = "quest", [5] = "vendor", [6] = "trainer", [7] = "world discovery",
    [8] = "redemption code", [9] = "gift", [10] = "talent", [11] = "starter", [12] = "event", [13] = "achievement",
}

local function safe(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

local function area(id)
    if not id or id == 0 then return nil end
    if SFP.AreaName then return SFP.AreaName(id) end
    return "zone " .. id
end

local function money(c)
    if not c or c <= 0 then return nil end
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return math.floor(c / 10000) .. "g"
end

local function cap(s) return (s:gsub("^%l", string.upper)) end

---------------------------------------------------------------------------
-- Materials
---------------------------------------------------------------------------
local function usedBy(data, id)
    local byProf, order = {}, {}
    local function add(prof, name)
        if not byProf[prof] then byProf[prof] = {}; order[#order + 1] = prof end
        local l = byProf[prof]
        for _, n in ipairs(l) do if n == name then return end end
        l[#l + 1] = name
    end
    for _, u in ipairs(data and data.u or {}) do add(SKILL[u[2]] or "Crafting", u[1]) end
    -- recipes learned from your own profession windows
    local usedIn = SFP:RecipeIndex()
    for _, key in ipairs(usedIn[id] or {}) do
        local r = SFP.db.recipes[key]
        if r then add(r.p or "Crafting", r.n) end
    end
    return byProf, order
end

local function materialBody(e)
    local id = e.itemID
    local d = SFP.MaterialData and SFP.MaterialData[id] or {}
    local c = "|cff33e6ff"
    local t = {}
    local function add(title, text) if text and text ~= "" then t[#t + 1] = c .. title .. "|r\n" .. text end end

    add("What it is", (SUB[d.s or 0] or "Material") .. (d.l and d.l > 0 and ("  -  item level " .. d.l) or ""))

    local byProf, order = usedBy(d, id)
    local lines = {}
    for _, prof in ipairs(order) do
        local l = byProf[prof]
        local shown = {}
        for i = 1, math.min(8, #l) do shown[i] = l[i] end
        lines[#lines + 1] = "|cffffd24a" .. prof .. "|r: " .. table.concat(shown, ", ") .. (#l > 8 and (" +" .. (#l - 8) .. " more") or "")
    end
    local total = d.nu or 0
    if #lines > 0 then
        add("What it is used for", table.concat(lines, "\n") .. (total > 14 and ("\n|cff808080" .. total .. " recipes use it in total.|r") or ""))
    else
        add("What it is used for", "No profession recipe uses it. It is sold to vendors, used in a quest, or kept as a collectible.")
    end

    local get = {}
    if d.g and #d.g > 0 then get[#get + 1] = "Gather it from: " .. table.concat(d.g, ", ") end
    if d.d and #d.d > 0 then
        local p = {}
        for _, x in ipairs(d.d) do p[#p + 1] = x[1] .. (area(x[2]) and (" (" .. area(x[2]) .. ")") or "") .. ((x[3] or 0) > 0 and (" ~" .. x[3] .. "%") or "") end
        get[#get + 1] = "Dropped by: " .. table.concat(p, ", ")
    end
    if d.skin and #d.skin > 0 then get[#get + 1] = "Skin it from: " .. table.concat(d.skin, ", ") end
    if d.pick and #d.pick > 0 then get[#get + 1] = "Pickpocket it from: " .. table.concat(d.pick, ", ") end
    if d.v and #d.v > 0 then
        local p = {}
        for _, x in ipairs(d.v) do p[#p + 1] = x[1] .. (area(x[2]) and (" (" .. area(x[2]) .. ")") or "") .. (money(x[3]) and (" for " .. money(x[3])) or "") end
        get[#get + 1] = "Bought from: " .. table.concat(p, ", ")
    end
    if d.cb and #d.cb > 0 then get[#get + 1] = "Made by crafting: " .. table.concat(d.cb, ", ") end
    if d.cio and #d.cio > 0 then get[#get + 1] = "Found in: " .. table.concat(d.cio, ", ") end
    if d.cii and #d.cii > 0 then get[#get + 1] = "Looted from: " .. table.concat(d.cii, ", ") end
    if d.de and #d.de > 0 then get[#get + 1] = "Disenchanted from: " .. table.concat(d.de, ", ") end
    if d.fish and #d.fish > 0 then get[#get + 1] = "Fished in: " .. table.concat(d.fish, ", ") end
    if d.mill and #d.mill > 0 then get[#get + 1] = "Milling it gives: " .. table.concat(d.mill, ", ") end
    if d.pros and #d.pros > 0 then get[#get + 1] = "Prospecting it gives: " .. table.concat(d.pros, ", ") end
    local drops = SFP:DropIndex()[id]
    if drops then
        local out = {}
        for i = 1, math.min(3, #drops) do
            local x = drops[i]
            local rec = (x[3] == "o") and SFP.db.objects[x[1]] or SFP.db.npcs[x[1]]
            out[#out + 1] = ((rec and rec.n) or "?") .. " (x" .. x[2] .. ")"
        end
        get[#get + 1] = "You got it from: " .. table.concat(out, ", ")
    end
    if SFP.QuestieItemSources then
        for _, s in ipairs(SFP:QuestieItemSources(id) or {}) do get[#get + 1] = s end
    end
    if #get == 0 then get[#get + 1] = "Buy it on the auction house, or look at the Wowhead link for every source." end
    add("Where to get it", table.concat(get, "\n"))

    local p = SFP:GetPrice(id)
    if p then add("Auction price", SFP:FormatPrice(p)) end
    return table.concat(t, "\n\n")
end

function SFP:FeedMaterials(cx)
    if not (cx and cx.Add and SFP.MaterialData) then return end
    local n = 0
    for id, d in pairs(SFP.MaterialData) do
        if d.n then
            cx:Add({
                cat = "material", id = d.n:lower(), name = d.n, group = SUB[d.s or 0] or "Other materials",
                icon = C_Item.GetItemIconByID(id) or 134400, itemID = id, sub = d.nu and d.nu > 0 and (d.nu .. " recipes") or "",
                bodyFn = materialBody, wh = "item=" .. id, tags = "material reagent mats crafting " .. (SUB[d.s or 0] or ""),
            })
            n = n + 1
            if n % 100 == 0 and cx.Yield then cx:Yield() end
        end
    end
end

---------------------------------------------------------------------------
-- Mounts
---------------------------------------------------------------------------
local function npcWhere(npcID, areaID)
    local N = _G.NpcDB
    local sp = N and safe(N.spawns, npcID)
    if type(sp) ~= "table" then return area(areaID) or "" end
    local list = areaID and sp[areaID]
    local ar, c = areaID, list and list[1]
    if not c then
        for a, l in pairs(sp) do ar, c = a, l and l[1]; if c then break end end
    end
    if c and c[1] and c[1] > 0 then return (area(ar) or "?") .. (" %.0f, %.0f"):format(c[1], c[2]) end
    return area(ar) or ""
end

local function costText(cost)
    if type(cost) ~= "table" then return nil end
    local parts = {}
    if money(cost[1]) then parts[#parts + 1] = money(cost[1]) end
    for _, cu in ipairs(cost[2] or {}) do
        local name
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local i = safe(C_CurrencyInfo.GetCurrencyInfo, cu[1]); name = i and i.name
        elseif GetCurrencyInfo then name = safe(GetCurrencyInfo, cu[1]) end
        parts[#parts + 1] = cu[2] .. " " .. (name or ("currency " .. cu[1]))
    end
    for _, it in ipairs(cost[3] or {}) do parts[#parts + 1] = it[2] .. " " .. SFP:ItemName(it[1]) end
    return #parts > 0 and table.concat(parts, " + ") or nil
end

local function mountHowTo(cx, e)
    local d = SFP.MountData and SFP.MountData[e.spellID]
    if not d then return nil end
    local c = cx.CYAN or "|cff33e6ff"
    local steps = {}
    local function step(text) steps[#steps + 1] = #steps + 1 .. ". " .. text end
    local out = {}
    if e.collected ~= nil then out[#out + 1] = e.collected and "|cff40ff40You have this mount|r" or "|cffff7070You do not have this mount yet|r" end

    local srcName = {}
    for _, code in ipairs(d.source or {}) do srcName[#srcName + 1] = SOURCE[code] or tostring(code) end
    out[#out + 1] = "\n" .. c .. "How to get it|r  |cff808080(" .. (#srcName > 0 and table.concat(srcName, ", ") or "see the steps") .. ")|r"

    local req = {}
    for _, l in ipairs(d.tip or {}) do
        if l:find("^Requires") or l:find("Riding") then req[#req + 1] = l end
    end

    -- drops
    if d.d and #d.d > 0 then
        local top = d.d[1]
        local ent = SFP.InstanceEntranceByArea and SFP:InstanceEntranceByArea(top[3])
        local zone = area(top[3])
        if ent then
            step("Go to the entrance of |cffffd24a" .. ent.name .. "|r: " .. SFP:ZoneName(ent.map) .. (" %.1f, %.1f"):format(ent.x * 100, ent.y * 100) .. ".")
            step("Enter the instance (the Dungeon Journal shows its bosses and which difficulty drops the mount).")
        elseif zone then
            step("Travel to |cffffd24a" .. zone .. "|r.")
        end
        local who = {}
        for i, x in ipairs(d.d) do who[#who + 1] = x[1] .. ((x[4] or 0) > 0 and (" (about " .. x[4] .. "%)") or "") end
        step("Kill " .. table.concat(who, " or ") .. (top[2] and (" - " .. npcWhere(top[2], top[3])) or "") .. " and loot the " .. e.name .. ".")
        step(ent and "Drop chances are low: repeat after the lockout resets (weekly for raids, daily for heroic dungeons)." or "It is a rare chance: keep killing it whenever it respawns.")
    end
    -- vendors
    if d.v and #d.v > 0 then
        for _, x in ipairs(d.v) do
            step("Go to |cffffd24a" .. x[1] .. "|r - " .. npcWhere(x[2], x[3]) .. ".")
            local cost = costText(x[4])
            step("Buy the mount" .. (cost and (" for " .. cost) or "") .. ".")
            break
        end
        if #d.v > 1 then
            local other = {}
            for i = 2, #d.v do other[#other + 1] = d.v[i][1] end
            step("Also sold by: " .. table.concat(other, ", ") .. ".")
        end
    end
    -- quests
    if d.q and #d.q > 0 then
        local q = d.q[1]
        step("Complete the quest |cffffd24a" .. q[1] .. "|r" .. (q[3] and q[3] > 0 and (" (" .. (area(q[3]) or "") .. ")") or "") .. ". The mount is its reward.")
        step("Search the quest in the Quests section of the Codex for where to pick it up and how to do it.")
    end
    -- containers
    for _, key in ipairs({ "cio", "cii" }) do
        if d[key] and #d[key] > 0 then
            local names = {}
            for i, x in ipairs(d[key]) do names[#names + 1] = x[1] end
            step("Open " .. table.concat(names, " or ") .. " - the mount can be inside.")
        end
    end
    if d.cb and #d.cb > 0 then step("Craft it: " .. d.cb[1][1] .. " (learn the profession recipe first).") end
    if d.pick and #d.pick > 0 then step("Pickpocket " .. d.pick[1][1] .. " (rogues only).") end
    if d.fish and #d.fish > 0 then step("Fish in " .. d.fish[1][1] .. " and hope for the mount.") end

    -- achievements
    for _, sm in ipairs(d.sourcemore or {}) do
        if sm.ti and (sm.n or sm.t == 4) then
            local name = sm.n or (GetAchievementInfo and select(2, GetAchievementInfo(sm.ti)))
            step("Earn the achievement |cffffd24a" .. (name or ("#" .. sm.ti)) .. "|r. The mount is its reward.")
            local ach = name and cx.FindByName and cx:FindByName("achievement", name)
            if ach and cx.AchievementHowTo then
                steps[#steps + 1] = (cx:AchievementHowTo(ach):gsub("^\n+", ""))
            end
        elseif sm.z and (not d.d or #d.d == 0) then
            step("Look in " .. (area(sm.z) or ("zone " .. sm.z)) .. ".")
        end
    end
    -- anything left
    if #steps == 0 then
        local code = d.source and d.source[1]
        if code == 3 then step("Earned in PvP: spend honor / conquest or win rated play - see the item's vendor with the Wowhead link below.")
        elseif code == 12 then step("Only during the holiday event - check the in-game calendar for the dates, then do the event's activities.")
        elseif code == 8 or code == 9 then step("Not obtainable in game: it came from a promotion, gift or code.")
        elseif code == 7 then step("Found in the world: use the Wowhead link below for the exact spot.")
        else step("Wowhead lists no drop or vendor for it. Use the link below for comments and guides.") end
    end
    out[#out + 1] = table.concat(steps, "\n")
    if #req > 0 then out[#out + 1] = "\n" .. c .. "Requirements|r\n" .. table.concat(req, "\n") end
    if d.item then out[#out + 1] = "\n|cff808080Item: " .. SFP:ItemName(d.item) .. "|r" end
    return table.concat(out, "\n")
end

local mountItemByID
local function staticMountHowTo(cx, e)
    if not mountItemByID then
        mountItemByID = {}
        for itemID, info in pairs(SFP.Items or {}) do
            if info.kind == "mount" and C_MountJournal and C_MountJournal.GetMountFromItem then
                local mid = safe(C_MountJournal.GetMountFromItem, itemID)
                if mid then mountItemByID[mid] = itemID end
            end
        end
    end
    local itemID = mountItemByID[e.id]
    if not itemID then return nil end
    local info = SFP.Items[itemID] or {}
    local c = cx.CYAN or "|cff33e6ff"
    local out, steps = {}, {}
    local function step(text) steps[#steps + 1] = #steps + 1 .. ". " .. text end
    if e.collected ~= nil then out[#out + 1] = e.collected and "|cff40ff40You have this mount|r" or "|cffff7070You do not have this mount yet|r" end
    out[#out + 1] = "\n" .. c .. "How to get it|r"
    for _, exp in ipairs(SFP.Expansions or {}) do
        for _, inst in ipairs(exp.instances or {}) do
            for _, id in ipairs(inst.items or {}) do
                if id == itemID then
                    local ent = SFP:FindEntrance(inst)
                    step("Go to the entrance of |cffffd24a" .. inst.name .. "|r" .. (ent and (": " .. SFP:ZoneName(ent.map) .. (" %.1f, %.1f"):format(ent.x * 100, ent.y * 100)) or (" in " .. SFP:ZoneName(inst.map))) .. ".")
                    step("Kill " .. (info.note or "the boss") .. (info.drop and (" - drop chance " .. info.drop) or "") .. " and loot the " .. e.name .. ".")
                    step(inst.kind == "raid" and "Raids lock you out for a week: repeat each week." or "Heroic dungeons reset daily: repeat for another chance.")
                    if inst.note then step(inst.note) end
                end
            end
        end
    end
    for mapID, list in pairs(SFP.Rares or {}) do
        for _, sp in ipairs(list) do
            for _, id in ipairs(sp.items or {}) do
                if id == itemID and sp.hx then
                    step("Go to |cffffd24a" .. SFP:ZoneName(mapID) .. "|r " .. ("%.1f, %.1f"):format(sp.hx * 100, sp.hy * 100) .. " and find |cffffd24a" .. sp.name .. "|r.")
                    if sp.note then step(sp.note) end
                    step("Kill it and loot the " .. e.name .. (info.drop and (" (drop chance " .. info.drop .. ")") or "") .. ".")
                end
            end
        end
    end
    if #steps == 0 then
        if info.note then step(info.note .. (info.drop and (" - drop chance " .. info.drop) or "")) else return nil end
    end
    out[#out + 1] = table.concat(steps, "\n")
    return table.concat(out, "\n")
end

local function hook()
    local cx = _G.SeviathsCodex
    if not cx then return end
    cx.MountHowTo = function(self, e) return mountHowTo(self, e) or staticMountHowTo(self, e) end
end
SFP:OnLogin(hook)
hook()
