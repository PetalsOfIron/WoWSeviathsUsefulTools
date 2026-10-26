-- Seviath's Codex — Materials: what every crafting material is used for
--
-- Two sources, both from your own game:
--  • the material type (Herb, Cloth, Metal & Stone…) → which professions use it
--  • your professions: whenever you open a profession window, the Codex reads
--    every recipe and remembers exactly which recipes use which material.
--    Saved account-wide, so opening professions on your alts fills it in more.

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

local TYPE_INFO = {
    ["Herb"]              = { use = "Alchemy (potions, flasks, phials) and Inscription (milled into pigments, then inks).", from = "Herbalism nodes in the open world; some drop from plant-type enemies." },
    ["Metal & Stone"]     = { use = "Blacksmithing (plate, weapons), Engineering (parts, gadgets) and Jewelcrafting (prospected into gems).", from = "Mining nodes and seams in the open world." },
    ["Cloth"]             = { use = "Tailoring (cloth armor, bags) and bandages in older content.", from = "Drops from humanoid enemies — no profession needed." },
    ["Leather"]           = { use = "Leatherworking (leather and mail armor, armor kits, drums).", from = "Skinning beasts and dragonkin after you kill them." },
    ["Cooking"]           = { use = "Cooking — food that gives stat buffs.", from = "Meat and parts from beasts, and fishing." },
    ["Enchanting"]        = { use = "Enchanting — enchants for gear, plus some crafting recipes.", from = "Disenchanting uncommon (green) or better gear." },
    ["Elemental"]         = { use = "Used by many crafting professions as an extra ingredient.", from = "Elemental enemies, gathering nodes and special nodes." },
    ["Jewelcrafting"]     = { use = "Jewelcrafting — cut into gems, set into rings and necklaces.", from = "Prospecting ore (Jewelcrafting) or rare finds while mining." },
    ["Inscription"]       = { use = "Inscription — inks for scrolls, contracts, glyphs and off-hands.", from = "Milling herbs (Inscription)." },
    ["Parts"]             = { use = "Engineering — gadgets, scopes, goggles and devices.", from = "Crafted by engineers or salvaged from mechanical enemies." },
    ["Optional Reagents"] = { use = "Added while crafting to change the result (extra stats, effects or item level).", from = "Crafted or bought from crafters / the Auction House." },
    ["Finishing Reagents"]= { use = "Added at the end of a craft to improve quality or success.", from = "Crafted or bought from crafters / the Auction House." },
    ["Other"]             = { use = "Used by various professions — see the recipe list below.", from = "Various." },
}

local SEED_TYPES = {
    ["Argentleaf"] = "Herb", ["Tranquility Bloom"] = "Herb", ["Sanguithorn"] = "Herb", ["Azeroot"] = "Herb",
    ["Mana Lily"] = "Herb", ["Nocturnal Lotus"] = "Herb",
    ["Refulgent Copper Ore"] = "Metal & Stone", ["Dazzling Thorium"] = "Metal & Stone",
    ["Majestic Hide"] = "Leather", ["Majestic Claw"] = "Leather", ["Majestic Fin"] = "Leather",
}

local function MatKey(name) return "material:" .. name:lower() end

local function AddMaterial(name, itemID, subType)
    if not name or name == "" then return end
    local e = ns:Get(MatKey(name))
    if e then
        if itemID and not e.itemID then e.itemID = itemID; e.icon = C_Item.GetItemIconByID(itemID) or e.icon end
        if subType and e.group == "Other" then e.subType = subType end
        return e
    end
    return ns:Add({
        cat = "material", id = name:lower(), name = name,
        group = subType or "Other", subType = subType or "Other", itemID = itemID,
        icon = (itemID and C_Item.GetItemIconByID(itemID)) or "Interface\\Icons\\INV_Misc_Herb_Felblossom",
        sub = subType or "", wh = itemID and ("item=" .. itemID) or ("search?q=" .. name:gsub(" ", "%%20")),
        tags = "material reagent mats " .. (subType or ""),
    })
end

-- called for every item the Codex learns about
function ns:MaybeMaterial(itemID, name)
    if not itemID then return end
    local _, _, subType, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= 7 then return end
    name = name or C_Item.GetItemNameByID(itemID)
    if name then AddMaterial(name, itemID, subType) end
end

------------------------------------------------------------------------
-- Profession recipe scan → exact uses
------------------------------------------------------------------------
local function ScanProfession()
    if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs) then return end
    local prof = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    local profName = prof and prof.professionName
    if not profName or profName == "" then return end
    ns.db.matUses = ns.db.matUses or {}
    local uses = ns.db.matUses
    local ids = C_TradeSkillUI.GetAllRecipeIDs() or {}
    for i, recipeID in ipairs(ids) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        local schem = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
        if info and info.name and schem and schem.reagentSlotSchematics then
            for _, slot in ipairs(schem.reagentSlotSchematics) do
                for _, r in ipairs(slot.reagents or {}) do
                    local id = r.itemID
                    if id then
                        uses[id] = uses[id] or {}
                        local list = uses[id][profName]
                        if not list then list = {}; uses[id][profName] = list end
                        if #list < 30 then
                            local dup = false
                            for _, n in ipairs(list) do if n == info.name then dup = true; break end end
                            if not dup then list[#list + 1] = info.name end
                        end
                        local n = C_Item.GetItemNameByID(id)
                        if n then
                            local _, _, subType = C_Item.GetItemInfoInstant(id)
                            AddMaterial(n, id, subType)
                        else
                            C_Item.RequestLoadItemDataByID(id)
                        end
                    end
                end
            end
        end
        if i % 20 == 0 then ns:Yield() end
    end
    ns:Print("learned which materials " .. profName .. " uses (" .. #ids .. " recipes).")
end

local pev = CreateFrame("Frame")
pcall(pev.RegisterEvent, pev, "TRADE_SKILL_SHOW")
pev:SetScript("OnEvent", function()
    if not ns.db then return end
    C_Timer.After(1.5, function()
        local prof = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
        ns:RunJob("Reading " .. ((prof and prof.professionName) or "profession") .. " recipes", ScanProfession)
    end)
end)

------------------------------------------------------------------------
-- Indexer: materials from everything known so far
------------------------------------------------------------------------
function ns:IndexMaterials()
    -- materials named in the Gold Farming spots
    for _, f in ipairs(self.FARMS or {}) do
        for _, m in ipairs(f.mats or {}) do AddMaterial(m, nil, SEED_TYPES[m]) end
    end
    -- every item already known (loot + seen items)
    for _, e in ipairs(self.byCat.item) do
        if e.itemID then self:MaybeMaterial(e.itemID, e.name) end
        self:Yield()
    end
    -- everything recorded from profession scans
    for id in pairs((self.db and self.db.matUses) or {}) do
        local n = C_Item.GetItemNameByID(id)
        if n then
            local _, _, subType = C_Item.GetItemInfoInstant(id)
            AddMaterial(n, id, subType)
        end
        self:Yield()
    end
end

------------------------------------------------------------------------
-- Detail page
------------------------------------------------------------------------
function ns:MaterialText(e)
    local out = {}
    local info = TYPE_INFO[e.subType or "Other"] or TYPE_INFO.Other
    out[#out + 1] = C .. "Type|r\n" .. (e.subType or "Crafting material")
    out[#out + 1] = C .. "What it's used for|r\n" .. info.use

    local uses = e.itemID and ns.db and ns.db.matUses and ns.db.matUses[e.itemID]
    if uses and next(uses) then
        local lines = {}
        for prof, list in pairs(uses) do
            lines[#lines + 1] = "|cffffd100" .. prof .. "|r: " .. table.concat(list, ", ")
                .. (#list >= 30 and ", …" or "")
        end
        table.sort(lines)
        out[#out + 1] = C .. "Recipes that use it|r\n" .. table.concat(lines, "\n")
    else
        out[#out + 1] = "|cff888888Exact recipes appear here after you open a profession window that uses it (on any of your characters).|r"
    end

    out[#out + 1] = C .. "Where to get it|r\n" .. info.from
    out[#out + 1] = ns:BestPlace(e, e.itemID)

    local price = ns.LivePrice and ns:LivePrice(e.name)
    if price then out[#out + 1] = C .. "Auction price (Auctionator)|r\n" .. price end

    -- link farm spots + the item page
    if not e._linked then
        e._linked = true
        for i, f in ipairs(ns.FARMS or {}) do
            for _, m in ipairs(f.mats or {}) do
                if m:lower() == e.lname then
                    local fe = ns:Get("mats:farm" .. i)
                    if fe then ns:Link(e, fe) end
                end
            end
        end
        if e.itemID then
            local it = ns:Get("item:" .. e.itemID)
            if it then ns:Link(e, it) end
        end
    end
    return table.concat(out, "\n\n")
end


------------------------------------------------------------------------
-- Where you actually got things: recorded every time you loot
-- (kills, herbs, ore, skinning, chests). Saved for all characters.
------------------------------------------------------------------------
local function RecordLoot()
    if not ns.db then return end
    local m = C_Map.GetBestMapForUnit("player")
    if not m then return end
    local pos = C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return end
    if issecretvalue and issecretvalue(pos.x) then return end
    ns.db.lootZones = ns.db.lootZones or {}
    for i = 1, (GetNumLootItems() or 0) do
        local link = GetLootSlotLink(i)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then
            local z = ns.db.lootZones[id]
            if not z then z = {}; ns.db.lootZones[id] = z end
            local r = z[m]
            if not r then r = { c = 0 }; z[m] = r end
            r.c = r.c + 1
            r.x, r.y = pos.x, pos.y          -- last spot you got it in that zone
            if ns.MaybeMaterial then pcall(ns.MaybeMaterial, ns, id) end
        end
    end
end

local lev = CreateFrame("Frame")
pcall(lev.RegisterEvent, lev, "LOOT_READY")
lev:SetScript("OnEvent", function(_, event) if event == "LOOT_READY" then pcall(RecordLoot) end end)

-- "Best place to get it" for an item or material. Also sets Show on map.
function ns:BestPlace(e, itemID)
    local lines, target = {}, nil

    -- 0) vendors you've visited that sell it
    if self.SoldBy then
        local sold, spot = self:SoldBy(itemID)
        if sold then lines[#lines + 1] = sold; target = spot end
    end

    -- 1) zones where you've looted it, most first
    local z = itemID and self.db and self.db.lootZones and self.db.lootZones[itemID]
    if z then
        local list = {}
        for m, r in pairs(z) do list[#list + 1] = { m = m, c = r.c, x = r.x, y = r.y } end
        table.sort(list, function(a, b) return a.c > b.c end)
        for i, r in ipairs(list) do
            if i > 3 then break end
            local _, cont = self.ContinentOf(r.m)
            lines[#lines + 1] = ("%s|cffffd100%s|r%s — you got it here %d×  (%.1f, %.1f)"):format(
                i == 1 and "|cff40ff40Best:|r " or "", self:MapName(r.m), cont and (" » " .. cont) or "", r.c, r.x * 100, r.y * 100)
            if i == 1 then target = { m = r.m, x = r.x, y = r.y } end
        end
    end

    -- 2) bosses that drop it
    local refs = {}
    for _, k in ipairs(e.refs or {}) do refs[#refs + 1] = k end
    local itemEntry = itemID and e.cat ~= "item" and self:Get("item:" .. itemID)
    if itemEntry then for _, k in ipairs(itemEntry.refs or {}) do refs[#refs + 1] = k end end
    local seenB = {}
    for _, k in ipairs(refs) do
        local b = self:Get(k)
        if b and b.cat == "boss" and b.instKey and not seenB[k] then
            seenB[k] = true
            local inst = self:Get(b.instKey)
            if inst then
                lines[#lines + 1] = "Drops from |cffffd100" .. b.name .. "|r in " .. inst.name
                    .. (inst.map and ("\n    Entrance: " .. self:Coords(inst.map)) or "")
                if not target and inst.map then target = inst.map end
            end
        end
    end

    -- 3) gold-farm spots that list it
    local lname = e.lname or (e.name or ""):lower()
    for _, f in ipairs(self.FARMS or {}) do
        for _, m in ipairs(f.mats or {}) do
            if m:lower() == lname then
                local where = f.zid and self:MapName(f.zid) or ""
                if where == "?" then where = f.zone or "" end
                lines[#lines + 1] = "Farm spot: |cffffd100" .. f.name .. "|r" .. (where ~= "" and (" — " .. where) or "")
                if not target then
                    if f.x then target = { m = f.zid, x = f.x, y = f.y }
                    elseif f.zid then e.openMap = e.openMap or f.zid end
                end
            end
        end
    end

    if target then e.map = target end
    if #lines == 0 then
        return C .. "Best place to get it|r\n|cff888888Not known yet. The Codex remembers every zone you loot it in (kills, herbs, ore, skinning, chests) — after you get it once, the best zone shows here.|r"
    end
    return C .. "Best place to get it|r\n" .. table.concat(lines, "\n") .. "\n|cff888888Show on map points to the best spot.|r"
end
