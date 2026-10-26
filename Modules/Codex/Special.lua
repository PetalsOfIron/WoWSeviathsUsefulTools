-- Seviath's Codex — hunter pets + world monsters with special mechanics
-- Hand-written (CC BY-NC 3.0). Only well-known, long-standing facts; zone
-- names only, no guessed coordinates — use the Wowhead link for spawn maps.

local ADDON, ns = SFP_Module("Codex")
local C, R = "|cff33e6ff", "|r"

local function wh(name)
    return "search?q=" .. name:gsub(" ", "%%20"):gsub("'", "%%27")
end

------------------------------------------------------------------------
-- World monsters that give something, and how they work
------------------------------------------------------------------------
ns.SPECIAL_MONSTERS = {
    { name = "Time-Lost Proto-Drake", zone = "The Storm Peaks (Northrend)", gives = "Reins of the Time-Lost Proto-Drake (mount)",
      how = "Flies a long loop around The Storm Peaks. Shares its spawn with Vyragosa, so most spawns are Vyragosa instead. Respawn is many hours; players camp it or check on alts and other realm shards." },
    { name = "Aeonaxx", zone = "Deepholm", gives = "Reins of the Phosphorescent Stone Drake (mount)",
      how = "A flying rare that patrols Deepholm. He is friendly until you climb on him: kill the Young Stone Drakes he summons, then Aeonaxx himself. Random spawn at six points, shared timer with Blood Seeker." },
    { name = "Poseidus", zone = "Vashj'ir", gives = "Reins of Poseidus (underwater mount)",
      how = "Rare sea horse that swims a patrol path through Vashj'ir. Long and random respawn — check it when passing through." },
    -- (Draenor, for later) { name = "Nok-Karosh", zone = "Frostfire Ridge (Draenor)", gives = "Garn Nighthowl (mount, guaranteed)",
    -- how = "Rare wolf that patrols Frostfire Ridge. Kill it and the mount always drops — the challenge is catching the spawn." },
    { name = "Huolon", zone = "Timeless Isle (Pandaria)", gives = "Reins of the Thundering Onyx Cloud Serpent (mount)",
      how = "Rare cloud serpent flying above Timeless Isle. Long respawn timer, often shared with other hunters of it." },
    { name = "Galleon", zone = "Valley of the Four Winds (Pandaria)", gives = "Reins of the Son of Galleon (mount)",
      how = "Pandaria world boss. Easily soloable at max level; loot once per week per character." },
    { name = "Sha of Anger", zone = "Kun-Lai Summit (Pandaria)", gives = "Reins of the Heavenly Onyx Cloud Serpent (mount)",
      how = "Pandaria world boss. Soloable; weekly loot lockout per character." },
    { name = "Nalak", zone = "Isle of Thunder (Pandaria)", gives = "Reins of the Thundering Cobalt Cloud Serpent (mount)",
      how = "Pandaria world boss on the Isle of Thunder. Soloable; weekly lockout." },
    { name = "Oondasta", zone = "Isle of Giants (Pandaria)", gives = "Reins of the Cobalt Primordial Direhorn (mount)",
      how = "Pandaria world boss on the Isle of Giants. Soloable; weekly lockout." },
    -- (Draenor, for later) { name = "Rukhmar", zone = "Spires of Arak (Draenor)", gives = "Solar Spirehawk (mount)",
    -- how = "Draenor world boss flying over the Spires of Arak. Soloable; weekly lockout. Very low drop rate — farm every week on every max-level alt." },
}

------------------------------------------------------------------------
-- Rare hunter tames
------------------------------------------------------------------------
ns.SPECIAL_TAMES = {
    { name = "Loque'nahak", zone = "Sholazar Basin (Northrend)", family = "Spirit Beast",
      how = "Rare spirit-beast cat. Spirit Beasts are exotic: you need the Beast Mastery specialization to tame it. Long respawn." },
    { name = "Gondria", zone = "Zul'Drak (Northrend)", family = "Spirit Beast",
      how = "Rare spirit-beast cat. Beast Mastery required to tame. Long respawn." },
    { name = "Skoll", zone = "The Storm Peaks (Northrend)", family = "Spirit Beast",
      how = "Rare spirit-beast wolf. Beast Mastery required to tame. Long respawn." },
    { name = "Arcturis", zone = "Grizzly Hills (Northrend)", family = "Spirit Beast",
      how = "Rare spirit-beast bear. Beast Mastery required to tame. Long respawn." },
}

------------------------------------------------------------------------
-- Guide articles that go with them
------------------------------------------------------------------------
local extraGuide = {
{ id = "hunterpets", group = "4. Collections", title = "Hunter pets: families and taming", icon = "Ability_Hunter_BeastTaming",
  tags = "hunter pet tame stable family exotic spirit beast ferocity tenacity cunning",
  body = [[
Hunters use ]]..C.."Tame Beast"..R..[[ on a beast to make it a pet. Every beast belongs to a ]]..C.."family"..R..[[ (Wolf, Cat, Bear, Raptor…) and each family gives one special ability.

Every pet can use one of three ]]..C.."specializations"..R..[[ (change it at the Stable Master or the pet's talent tab):
• Ferocity — more damage, a leech heal. Good default for solo play.
• Tenacity — tanky, for soloing hard content.
• Cunning — utility and mobility.

]]..C.."Exotic families"..R..[[ (for example Core Hounds, Devilsaurs, Worms and Spirit Beasts) can only be tamed and used by ]]..C.."Beast Mastery"..R..[[ hunters.

Some families need a special unlock (an item or quest) before you can tame them — check the family on Wowhead before you travel.

The Monsters & Creatures section lists:
• Rare tames (like the Northrend spirit beasts) with how they work.
• Every tameable beast you mouse over, grouped by family, with where you saw it — saved for all your characters.]] },

{ id = "worldmounts", group = "3. World & Travel", title = "World monsters that drop mounts", icon = "Ability_Mount_Drake_Proto",
  tags = "rare world boss mount drop farm",
  body = [[
Some open-world monsters drop mounts. Two kinds:

]]..C.."World bosses"..R..[[ — big bosses with a weekly loot lockout. Old ones (Pandaria: Galleon, Sha of Anger, Nalak, Oondasta) are easy to solo. Kill them every week on every max-level character.

]]..C.."Rare spawns"..R..[[ — single monsters on long, random timers (Time-Lost Proto-Drake, Aeonaxx, Poseidus, Huolon). Some have special rules — Aeonaxx must be ridden first, the Proto-Drake shares its spawn with another rare.

Every one of them is in Monsters & Creatures » "World monsters that give something" with its zone, reward and how to get it.]] },
}

function ns:LoadSpecial()
    for i, a in ipairs(extraGuide) do
        self:Add({
            cat = "guide", id = a.id, name = a.title, group = a.group,
            icon = "Interface\\Icons\\" .. a.icon, sub = a.tags, tags = a.tags, body = a.body,
            order = 500 + i,
        })
    end
    for _, m in ipairs(self.SPECIAL_MONSTERS) do
        self:Add({
            cat = "creature", id = "special:" .. m.name, name = m.name,
            group = "World monsters that give something",
            icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
            sub = m.zone .. " — " .. m.gives,
            body = C .. "Where|r\n" .. m.zone .. "\n\n" .. C .. "Gives|r\n" .. m.gives .. "\n\n" .. C .. "Mechanics|r\n" .. m.how,
            wh = wh(m.name), tags = "mount rare world boss", zoneText = m.zone,
        })
    end
    for _, t in ipairs(self.SPECIAL_TAMES) do
        self:Add({
            cat = "creature", id = "tame:" .. t.name, name = t.name,
            group = "Hunter pets — rare tames",
            icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
            sub = t.family .. " — " .. t.zone,
            body = C .. "Family|r\n" .. t.family .. "\n\n" .. C .. "Where|r\n" .. t.zone .. "\n\n" .. C .. "How to tame|r\n" .. t.how,
            wh = wh(t.name), tags = "hunter pet tame " .. t.family:lower(), zoneText = t.zone,
        })
    end
end

------------------------------------------------------------------------
-- Tameable beasts you see: recorded on mouseover (out of combat)
------------------------------------------------------------------------
local function secret(v)
    return issecretvalue and issecretvalue(v)
end

local function AddBeast(key, b)
    ns:Add({
        cat = "creature", id = "beast:" .. key, name = b.n,
        group = "Hunter pets — " .. b.f,
        icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
        sub = ("%s — %s%s"):format(b.f, ns:MapName(b.m), b.r and (" (" .. b.r .. ")") or ""),
        body = C .. "Family|r\n" .. b.f .. "\n\n" .. C .. "Seen at|r\n" .. ns:Coords({ m = b.m, x = b.x, y = b.y })
            .. (b.l and ("\n\n" .. C .. "Level|r\n" .. b.l) or "")
            .. "\n\n|cff888888Recorded when you moused over it. Exotic families need Beast Mastery.|r",
        map = { m = b.m, x = b.x, y = b.y },
        wh = wh(b.n), tags = "hunter pet tame beast " .. b.f:lower() .. (b.r and " rare" or ""),
    })
end

local function AddMonster(key, b)
    local cls = b.r and (" (" .. b.r .. ")") or ""
    ns:Add({
        cat = "creature", id = "npc:" .. key, name = b.n,
        group = "Monsters you've seen — " .. ns:MapName(b.m),
        icon = "Interface\\Icons\\Ability_Warrior_Revenge",
        sub = ns:MapName(b.m) .. cls .. (b.l and (" · level " .. b.l) or ""),
        body = C .. "Seen at|r\n" .. ns:Coords({ m = b.m, x = b.x, y = b.y })
            .. (b.l and ("\n\n" .. C .. "Level|r\n" .. b.l) or "")
            .. (b.r and ("\n\n" .. C .. "Type|r\n" .. b.r) or "")
            .. "\n\n|cff888888Recorded when you moused over it. Show on map points to where you saw it.|r",
        map = { m = b.m, x = b.x, y = b.y }, tags = "monster npc enemy " .. (b.r or ""),
    })
end

local function RecordMonster(name)
    if not UnitCanAttack("player", "mouseover") then return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos or secret(pos.x) then return end
    ns.db.npcs = ns.db.npcs or {}
    local key = name .. "@" .. m
    if ns.db.npcs[key] then return end
    local cls = UnitClassification("mouseover")
    local lvl = UnitLevel("mouseover")
    local b = {
        n = name, m = m, x = pos.x, y = pos.y,
        l = (lvl and not secret(lvl) and lvl > 0) and lvl or nil,
        r = (cls == "rare" and "rare") or (cls == "rareelite" and "rare elite") or (cls == "elite" and "elite") or (cls == "worldboss" and "world boss") or nil,
    }
    ns.db.npcs[key] = b
    AddMonster(key, b)
end

function ns:LoadMonsters()
    for key, b in pairs((self.db and self.db.npcs) or {}) do AddMonster(key, b) end
end

local function RecordMouseover()
    if InCombatLockdown() or not ns.db or not UnitExists("mouseover") then return end
    if UnitPlayerControlled("mouseover") then return end
    local family = UnitCreatureFamily("mouseover")
    local name = UnitName("mouseover")
    if not name or secret(name) then return end
    if not family or secret(family) then RecordMonster(name); return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return end
    ns.db.beasts = ns.db.beasts or {}
    local key = name .. "@" .. m
    if ns.db.beasts[key] then return end
    local cls = UnitClassification("mouseover")
    local b = {
        n = name, f = family, m = m, x = pos.x, y = pos.y,
        l = UnitLevel("mouseover"),
        r = (cls == "rare" or cls == "rareelite") and "rare" or nil,
    }
    if b.l and (secret(b.l) or b.l < 1) then b.l = nil end
    ns.db.beasts[key] = b
    AddBeast(key, b)
end

local mev = CreateFrame("Frame")
pcall(mev.RegisterEvent, mev, "UPDATE_MOUSEOVER_UNIT")
mev:SetScript("OnEvent", function() pcall(RecordMouseover) end)

function ns:LoadBeasts()
    for key, b in pairs((self.db and self.db.beasts) or {}) do AddBeast(key, b) end
end
