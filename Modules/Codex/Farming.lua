-- Seviath's Codex — Farming: good places to make gold in Mists of Pandaria Classic
-- Spots and node counts come from the Farm Pack's own data (Wowhead node and
-- spawn data); the tips are written for this addon. No reliable gold-per-hour
-- numbers exist — prices differ per realm — so each spot shows LIVE auction
-- prices when Auctionator is installed.

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

local Z = { JADE = 371, VALLEY = 376, KRASARANG = 418, KUNLAI = 379, TOWNLONG = 388, DREAD = 422, VALE = 390, TIMELESS = 554 }

ns.FARMS = {
------------------------------------------------------------------------
{ group = "1. Pandaria — Herbs & Ore", name = "The Jade Forest (best for Ghost Iron and herbs)", zone = "The Jade Forest", zid = Z.JADE,
  tier = "Easy · steady", mats = { "Ghost Iron Ore", "Green Tea Leaf", "Golden Lotus", "Rain Poppy" },
  body = "The most recorded Ghost Iron nodes of any zone (over a thousand) and the best zone for Green Tea Leaf, Golden Lotus and Rain Poppy. Open terrain and a level 85-86 zone, so it is easy to loop.\n\nHow: fly or ride one loop through the valleys, take every node you pass. Works for mining, herbalism or both." },
{ group = "1. Pandaria — Herbs & Ore", name = "Dread Wastes (Trillium, Kyparite, Fool's Cap)", zone = "Dread Wastes", zid = Z.DREAD,
  tier = "Medium · higher value ores", mats = { "Trillium Ore", "Kyparite", "Fool's Cap" },
  body = "The best zone for Trillium Veins, Kyparite Deposits and Fool's Cap. Mantid mobs are everywhere, so gathering is slower than in the Jade Forest, but Trillium and Kyparite sell for more.\n\nHow: loop the zone clockwise and kill the mantids that interrupt you — they also drop Windwool Cloth." },
{ group = "1. Pandaria — Herbs & Ore", name = "Valley of the Four Winds (Silkweed and farm)", zone = "Valley of the Four Winds", zid = Z.VALLEY,
  tier = "Easy · quick", mats = { "Silkweed", "Ghost Iron Ore" },
  body = "Silkweed grows densest here. The farm and the pools also give meat and fish for Cooking. Galleon, the weekly world boss, walks the Silken Fields." },
{ group = "1. Pandaria — Herbs & Ore", name = "Kun-Lai Summit (Snow Lily and Trillium)", zone = "Kun-Lai Summit", zid = Z.KUNLAI,
  tier = "Medium · cold zone", mats = { "Snow Lily", "Trillium Ore", "Ghost Iron Ore" },
  body = "Snow Lily only grows in the snow of Kun-Lai. Sha of Anger, the weekly world boss, also roams here (mount drop)." },
{ group = "1. Pandaria — Herbs & Ore", name = "Sha-Touched Herb (rare herb)", zone = "Dread Wastes", zid = Z.DREAD,
  tier = "Rare find", mats = { "Desecrated Herb" },
  body = "A rarer herb node that spawns mostly in the Dread Wastes (and a few in Kun-Lai, Valley and Jade Forest). It gives Desecrated Herb, used in high-end Alchemy and Inscription." },
{ group = "1. Pandaria — Herbs & Ore", name = "Gathering tips (more gold per node)",
  tier = "Tips", body = "• Track Herbs or Minerals from the minimap's tracking menu while you ride.\n• Take Herbalism + Alchemy or Mining + Jewelcrafting/Blacksmithing so you use or sell the high-value nodes.\n• Sell early in the week; prices drop as more players gather.\n• Skinning gives Mist-Touched Leather; rare finds like Magnificent Hide sell for much more." },

------------------------------------------------------------------------
{ group = "2. Pandaria — Cloth, Leather & Meat", name = "Windwool Cloth (humanoids)", tier = "Steady · any zone",
  mats = { "Windwool Cloth" },
  body = "Windwool Cloth drops from humanoid enemies. The Farm Pack marks good spots: Mischievous Snow Sprites in Kun-Lai Summit and Ik'thik Warriors in the Dread Wastes. Kill them in a loop; mobs respawn behind you." },
{ group = "2. Pandaria — Cloth, Leather & Meat", name = "Mist-Touched Leather (beasts)", tier = "Steady · skinning",
  mats = { "Mist-Touched Leather", "Prismatic Scale" },
  body = "Skin beasts — Stout Shaghorn in the Valley of the Four Winds, Longshadow Mushan in Townlong Steppes and Ruby Venomtails in the Dread Wastes are marked on the map by the Farm Pack." },
{ group = "2. Pandaria — Cloth, Leather & Meat", name = "Timeless Isle rares and treasures", zid = Z.TIMELESS,
  tier = "High · open world",
  body = "The Timeless Isle is full of rares that drop gear, mounts and Timeless Coins (Huolon is the rare cloud serpent mount). Treasures are chests around the island worth a few coins and sellable items." },
{ group = "2. Pandaria — Cloth, Leather & Meat", name = "BoE gear from any Pandaria mob",
  tier = "Lottery · good with AoE", body = "Almost any enemy in Pandaria can drop Bind-on-Equip green and blue gear, worth gold on the Auction House or for disenchanting. Pick a dense spot and kill in a loop so mobs respawn behind you. AoE-heavy classes (Mage, Hunter, Warlock, Death Knight) do best." },

------------------------------------------------------------------------
{ group = "3. Old content — mounts, transmog, BoEs", name = "How old-content gold works",
  tier = "Read first", body = "Old dungeon and raid mobs pay a small amount of gold per kill. The money comes from:\n• BoE gear and rare transmog appearances to sell.\n• Recipes, pets and mounts (sell or keep).\n• Vendor trash and disenchanting.\nHigh-value items can take a while to sell — list a few at a time." },
{ group = "3. Old content — mounts, transmog, BoEs", name = "Blackrock Depths", inst = "Blackrock Depths",
  tier = "Raw gold + BoEs", body = "Huge pulls and lots of mobs: vendor gold and BoE items. The golems drop Dark Iron Ore. Long but rewarding clear." },
{ group = "3. Old content — mounts, transmog, BoEs", name = "Maraudon", inst = "Maraudon",
  tier = "Transmog + herbs", body = "Very dense mobs, transmog drops and herbs inside." },
{ group = "3. Old content — mounts, transmog, BoEs", name = "Uldaman", inst = "Uldaman",
  tier = "Rare transmog lottery", body = "Known for rare, valuable transmog appearances — a lottery farm." },
{ group = "3. Old content — mounts, transmog, BoEs", name = "Razorfen Kraul", inst = "Razorfen Kraul",
  tier = "Fast resets", body = "Short and fast to clear — good to chain many runs." },
{ group = "3. Old content — mounts, transmog, BoEs", name = "Weekly raid lockouts (Burning Crusade, Wrath, Cataclysm)",
  tier = "Weekly · low effort", body = "At level 90 you can solo most older raids. Weekly lockouts, but they give gold from bosses and trash, sellable transmog, low-chance mounts and lots to disenchant. See the guide article 'Soloing old raids for mounts & transmog' for the best mount runs." },

------------------------------------------------------------------------
{ group = "4. Weekly & passive income", name = "Weekly routine", tier = "Steady",
  body = "• World bosses (Galleon, Sha of Anger, Nalak, Oondasta): one kill per week each, mount drops are rare but free.\n• Daily quests with gold rewards.\n• Rares and treasures on the Timeless Isle.\n• Cooking dailies and the Tillers for farm produce." },
{ group = "4. Weekly & passive income", name = "The Auction House", tier = "Best gold per time for crafters",
  body = "• Buy herbs/ore in the evening when gatherers flood the market, sell mid-week.\n• Stock consumables and gems before a new raid tier.\n• Watch for underpriced mounts, recipes and transmog. A price addon (Auctionator / TSM) helps a lot." },
}

-- live price from Auctionator, if installed (copper -> text)
function ns:LivePrice(itemName)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemName) then return nil end
    local ok, copper = pcall(api.GetAuctionPriceByItemName, "SeviathsCodex", itemName)
    if ok and copper and copper > 0 then
        return GetCoinTextureString and GetCoinTextureString(copper) or (math.floor(copper / 10000) .. "g")
    end
end

function ns:FarmText(e)
    local f = e.farm
    local out = {}
    if f.tier then out[#out + 1] = C .. "Rating|r\n" .. f.tier end
    if f.zid then
        local where = ns:MapName(f.zid)
        if where == "?" then where = f.zone or "?" end
        if f.x then where = where .. ("  %.1f, %.1f"):format(f.x * 100, f.y * 100) end
        local cont = ns.ContinentOf and select(2, ns.ContinentOf(f.zid))
        out[#out + 1] = C .. "Where|r\n" .. where .. (cont and (" » " .. cont) or "")
    end
    out[#out + 1] = C .. "How|r\n" .. (f.body or "")
    if f.mats then
        local lines, anyPrice = {}, false
        for _, m in ipairs(f.mats) do
            local p = ns:LivePrice(m)
            if p then anyPrice = true end
            lines[#lines + 1] = "• " .. m .. (p and ("   " .. p) or "")
        end
        out[#out + 1] = C .. "What you get|r\n" .. table.concat(lines, "\n")
        out[#out + 1] = anyPrice and "|cff888888Prices: live from Auctionator on your realm.|r"
            or "|cff888888Gold per hour depends on your realm's prices. Install Auctionator (scan the AH once) and live prices appear here.|r"
    end
    if f.inst then
        local inst = ns:FindByName("dungeon", f.inst) or ns:FindByName("raid", f.inst)
        if inst and inst.map then
            out[#out + 1] = C .. "Entrance|r\n" .. ns:Coords(inst.map) .. "\n|cff888888Full route and boss mechanics: Related below.|r"
        end
    end
    return table.concat(out, "\n\n")
end

function ns:LoadFarms()
    for i, f in ipairs(self.FARMS) do
        local e = self:Add({
            cat = "mats", id = "farm" .. i, name = f.name, group = f.group,
            icon = "Interface\\Icons\\" .. (f.mats and "INV_Misc_Herb_Felblossom" or (f.inst and "INV_Misc_Key_14") or "INV_Misc_Coin_01"),
            sub = (f.tier or "") .. " " .. table.concat(f.mats or {}, " "), farm = f, order = i,
            map = (f.zid and f.x) and { m = f.zid, x = f.x, y = f.y } or nil,
            openMap = f.zid, tags = "farm gold " .. (f.zone or ""),
        })
        if e and f.inst then
            local inst = self:FindByName("dungeon", f.inst) or self:FindByName("raid", f.inst)
            if inst then
                self:Link(e, inst)
                if inst.map then e.map = inst.map end
            end
        end
    end
end
