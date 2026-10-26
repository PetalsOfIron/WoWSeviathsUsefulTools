-- Seviath's Codex — vendors: who sells what, where, for how much.
-- The game has no list of vendors for addons, so the Codex records every
-- vendor you open (name, exact spot, every item and its cost). Saved for all
-- your characters. Item, material and achievement pages then show
-- "Sold by … (Show on map)".

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

local function secret(v) return issecretvalue and issecretvalue(v) end

local function CostText(i, price, hasExtended)
    local parts = {}
    if price and price > 0 then
        parts[#parts + 1] = GetCoinTextureString and GetCoinTextureString(price) or (math.floor(price / 10000) .. "g")
    end
    if hasExtended and GetMerchantItemCostInfo then
        local n = GetMerchantItemCostInfo(i) or 0
        for j = 1, n do
            local tex, value, link, currencyName = GetMerchantItemCostItem(i, j)
            local nm = currencyName or (link and link:match("%[(.-)%]")) or "?"
            if value and value > 0 then parts[#parts + 1] = value .. " " .. nm end
        end
    end
    return #parts > 0 and table.concat(parts, " + ") or "?"
end

local function RecordVendor()
    if not ns.db or InCombatLockdown() then return end
    local name = UnitName("npc")
    if not name or secret(name) then return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos or secret(pos.x) then return end
    ns.db.vendors = ns.db.vendors or {}
    ns.db.vendorItems = ns.db.vendorItems or {}
    local key = name .. "@" .. m
    local v = { n = name, m = m, x = pos.x, y = pos.y, items = {} }
    for i = 1, (GetMerchantNumItems() or 0) do
        local id = GetMerchantItemID(i)
        if id then
            local price, hasExt
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                local info = C_MerchantFrame.GetItemInfo(i)
                if info then price, hasExt = info.price, info.hasExtendedCost end
            elseif GetMerchantItemInfo then
                local _, _, p, _, _, _, _, ext = GetMerchantItemInfo(i)
                price, hasExt = p, ext
            end
            v.items[id] = CostText(i, price, hasExt)
            local list = ns.db.vendorItems[id]
            if not list then list = {}; ns.db.vendorItems[id] = list end
            local have = false
            for _, k in ipairs(list) do if k == key then have = true; break end end
            if not have then list[#list + 1] = key end
            if ns.RecordItem then ns.RecordItem(id) end
        end
    end
    local isNew = not ns.db.vendors[key]
    ns.db.vendors[key] = v
    ns:AddVendor(key, v)
    if isNew then ns:Print("vendor recorded: " .. name .. " (" .. ns:MapName(m) .. ")") end
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "MERCHANT_SHOW")
ev:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then C_Timer.After(0.5, function() pcall(RecordVendor) end) end
end)

function ns:AddVendor(key, v)
    local count = 0
    for _ in pairs(v.items) do count = count + 1 end
    local e = self:Add({
        cat = "creature", id = "vendor:" .. key, name = v.n, group = "Vendors you've visited",
        icon = "Interface\\Icons\\INV_Misc_Coin_02", sub = "Vendor — " .. self:MapName(v.m) .. " (" .. count .. " items)",
        map = { m = v.m, x = v.x, y = v.y }, vendorKey = key, tags = "vendor merchant shop",
    })
    if e then e.map = { m = v.m, x = v.x, y = v.y } end
    return e
end

function ns:IndexVendors()
    for key, v in pairs((self.db and self.db.vendors) or {}) do
        self:AddVendor(key, v)
        self:Yield()
    end
end

-- vendor page body
function ns:VendorText(e)
    local v = self.db.vendors and self.db.vendors[e.vendorKey]
    if not v then return "" end
    local lines = {}
    for id, cost in pairs(v.items) do
        local n = C_Item.GetItemNameByID(id) or ("item " .. id)
        lines[#lines + 1] = "• " .. n .. "   |cffaaaaaa" .. cost .. "|r"
    end
    table.sort(lines)
    return C .. "Where|r\n" .. self:Coords(e.map) .. "\n\n" .. C .. "Sells|r\n" .. table.concat(lines, "\n")
end

-- "Sold by" lines for an item; also returns the first vendor's map spot
function ns:SoldBy(itemID)
    local keys = itemID and self.db and self.db.vendorItems and self.db.vendorItems[itemID]
    if not keys then return nil end
    local lines, first = {}, nil
    for _, k in ipairs(keys) do
        local v = self.db.vendors[k]
        if v then
            lines[#lines + 1] = ("Sold by |cffffd100%s|r — %s %.1f, %.1f  |cffaaaaaa(%s)|r"):format(
                v.n, self:MapName(v.m), v.x * 100, v.y * 100, v.items[itemID] or "?")
            first = first or { m = v.m, x = v.x, y = v.y }
        end
    end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n"), first
end


-- a vendor you've visited, found by name (for "Vendor: <name>" sources)
function ns:VendorByName(name)
    if not name or not (self.db and self.db.vendors) then return nil end
    local l = name:lower()
    for _, v in pairs(self.db.vendors) do
        if v.n and v.n:lower() == l then return v end
    end
end
