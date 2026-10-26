-- Seviath's Codex — hand-written new-player guide articles (Mists of Pandaria Classic)
-- Written for this addon (CC BY-NC 3.0). Kept evergreen on purpose: numbers
-- and names that change live in the journals of the game itself, not here.

local ADDON, ns = SFP_Module("Codex")
local C = "|cff33e6ff"   -- cyan headings
local R = "|r"

ns.GUIDE = {
------------------------------------------------------------------------
-- Start here
------------------------------------------------------------------------
{ id = "codex", group = "1. Start Here", title = "How to use the Codex", icon = "INV_Misc_Book_09",
  tags = "help search waypoint",
  body = [[
Type anything in the search box at the top — a boss, a dungeon, an item, a mount, a pet, an achievement, a title — and the Codex searches every section at once. Click a section on the left to browse it by expansion or type.

]]..C.."Buttons on a page"..R..[[

• Show on map — puts an arrow on your map and minimap (uses TomTom if you have it).
• Dungeon Journal / Collections — opens the matching Blizzard window.
• Wowhead link — a link you can copy (Ctrl+C) for full comments and guides.

]]..C.."Where the data comes from"..R..[[

Dungeons, raids, bosses, abilities, loot, entrances, mounts, pets, achievements and quests are read straight from your game client, so they match the game you are playing. The first time you log in it takes a minute or two to read most of it in the background.

Quests are the big one: the Codex asks the server about every quest once (the first time it reads in the background, pauses in combat and continues next login). After that they load instantly. Each quest page shows only what to do — the objectives — not the story text.

Slash commands: /codex, /codex <search>, /codex minimap, /codex reindex]] },

{ id = "first-steps", group = "1. Start Here", title = "Your first hours: what to do", icon = "Achievement_Quests_Completed_01",
  tags = "new player leveling start beginner",
  body = [[
1. Finish your starting area and the introduction quests — they teach movement, combat and your class.
2. At level 10 pick a ]]..C.."specialization"..R..[[ (Talents window, N) — it decides your role: tank, healer or damage.
3. Level by questing, running dungeons (the Dungeon Finder queues you automatically) or both. Every old zone from Classic to Cataclysm levels you; Pandaria is for level 85-90.
4. Learn your profession(s) from the trainers in the capital cities.
5. At level 90 the endgame opens up: daily quests in Pandaria, reputations, Challenge Modes, Scenarios, Heroic dungeons, raids and the Timeless Isle.

Tip: set your Hearthstone at an inn in a city you visit often. It's your free teleport home.]] },

{ id = "roles", group = "1. Start Here", title = "Classes, specs and roles", icon = "ClassIcon_Warrior",
  tags = "tank healer dps damage class spec talents monk",
  body = [[
There are 11 classes in Mists of Pandaria (the Monk joined with Pandaria). Every class has 2–4 specializations; each spec has one role:

]]..C.."Tank"..R..[[ — holds the enemies' attention and takes the hits. Leads the pace in dungeons.
]]..C.."Healer"..R..[[ — keeps the group alive.
]]..C.."Damage (DPS)"..R..[[ — kills things, avoids standing in bad stuff.

You can change spec any time out of combat. Talents are chosen every 15 levels from level 15 to 90.

Damage roles have the longest queue in the Dungeon Finder; tanks and healers get in fastest.]] },

{ id = "gear", group = "1. Start Here", title = "Gear, reforging and upgrades", icon = "INV_Chest_Plate16",
  tags = "ilvl item level gear upgrade reforge valor stats gems",
  body = [[
]]..C.."Item level (ilvl)"..R..[[ is the main number that says how strong a piece is. Your average ilvl shows in the character window (C).

Where gear comes from, from easiest to hardest: quest rewards and leveling » normal/heroic dungeons » Scenarios and the Timeless Isle » Raid Finder, Normal and Heroic raids.

• ]]..C.."Reforging"..R..[[ — at the Reforger NPC you move 40% of one secondary stat into another (Haste, Crit, Mastery, Hit, Expertise, Spirit, Dodge, Parry). Use it to reach the hit/expertise caps your spec needs.
• ]]..C.."Gems and enchants"..R..[[ — socket gems and enchant every slot you can; it is the cheapest power in the game.
• ]]..C.."Currencies"..R..[[ — Justice Points and Valor Points (weekly cap) buy and upgrade gear at the vendors in Pandaria. Valor comes from Heroic dungeons, Scenarios and raids.

Stats: your main stat (Strength, Agility or Intellect) matters most; secondary stats depend on your spec — check a class guide for priorities.]] },

------------------------------------------------------------------------
-- Group content
------------------------------------------------------------------------
{ id = "dungeons", group = "2. Dungeons, Raids & Scenarios", title = "Dungeons and their difficulties", icon = "INV_Misc_Key_14",
  tags = "dungeon normal heroic challenge mode group finder",
  body = [[
A dungeon is a 5-player instance: 1 tank, 1 healer, 3 damage.

]]..C.."Normal"..R..[[ — leveling. Queue with the Dungeon Finder (I).
]]..C.."Heroic"..R..[[ — level 85+ (Pandaria heroics at 90), better loot, still queueable.
]]..C.."Challenge Mode"..R..[[ — a timed run in set gear. Beat the Bronze, Silver or Gold timer for rewards (a transmog set for each, and more for gold on all dungeons).

Find any dungeon's entrance in the Entrances section of this Codex, and each boss's abilities and loot under Bosses.]] },

{ id = "scenarios", group = "2. Dungeons, Raids & Scenarios", title = "Scenarios", icon = "Achievement_Dungeon_ClassicDungeonMaster",
  tags = "scenario 3 player lfg valor",
  body = [[
]]..C.."Scenarios"..R..[[ are short 3-player instances introduced in Mists of Pandaria with no tank/healer/damage roles — queue from the Dungeon Finder. Normal and Heroic Scenarios give Valor Points and are a quick way to cap them.]] },

{ id = "raids", group = "2. Dungeons, Raids & Scenarios", title = "Raids and difficulties", icon = "Achievement_Boss_Ragnaros",
  tags = "raid lfr normal heroic 10 25 flex lockout",
  body = [[
Raids are big instances for 10 or more players.

]]..C.."Raid Finder (LFR)"..R..[[ — queue and go, easiest, split into wings.
]]..C.."Normal / Heroic"..R..[[ — 10 or 25 players (flexible sizes in the newest raids), group with friends or a guild.

Each difficulty has a weekly ]]..C.."lockout"..R..[[: each boss gives loot once per week per difficulty. The reset is weekly (Wednesday in Europe, Tuesday in the Americas). The raid tier of Mists: Mogu'shan Vaults, Heart of Fear, Terrace of Endless Spring, Throne of Thunder, Siege of Orgrimmar.]] },

{ id = "timeless", group = "2. Dungeons, Raids & Scenarios", title = "Timeless Isle", icon = "Achievement_Zone_TimelessIsle",
  tags = "timeless isle coins rare huolon zandalari",
  body = [[
The ]]..C.."Timeless Isle"..R..[[ is an open-world zone with many rares, treasures and Timeless Coins that buy gear. Rares drop gear and mounts; Huolon, the cloud serpent above the isle, is the rare mount boss. Good gear for level 90 characters who skip raids.]] },

{ id = "legacy", group = "2. Dungeons, Raids & Scenarios", title = "Soloing old raids for mounts & transmog", icon = "Achievement_Boss_LichKing",
  tags = "legacy solo old raid mount transmog farm lockout",
  body = [[
At level 90 you can solo most raids from older expansions. They keep their weekly lockouts, so you run them once a week.

Easy classic mount farms (weekly lockouts):
• ]]..C.."Invincible"..R..[[ — The Lich King, Icecrown Citadel (25 Heroic).
• ]]..C.."Ashes of Al'ar"..R..[[ — Kael'thas, Tempest Keep (The Eye).
• ]]..C.."Mimiron's Head"..R..[[ — Yogg-Saron with no keepers helping, Ulduar.
• ]]..C.."Fiery Warhorse"..R..[[ — Attumen the Huntsman, Karazhan.
• ]]..C.."Blue Proto-Drake"..R..[[ — Skadi the Ruthless, Utgarde Pinnacle (Heroic).
• ]]..C.."Swift White Hawkstrider"..R..[[ — Kael'thas, Magisters' Terrace (Heroic).
• ]]..C.."Deathcharger's Reins"..R..[[ — Lord Aurius Rivendare, Stratholme.
• ]]..C.."Swift Razzashi Raptor / Swift Zulian Tiger"..R..[[ — Bloodlord Mandokir / High Priest Thekal, Zul'Gurub (the Classic raid).

Search any of these names in the Codex to see the boss, the instance and the entrance with a map arrow. Drop rates are low — farm a few every week.]] },

{ id = "groupfinder", group = "2. Dungeons, Raids & Scenarios", title = "Finding a group", icon = "INV_Misc_GroupNeedMore",
  tags = "group finder premade lfg guild",
  body = [[
]]..C.."Group Finder"..R..[[ (I) queues you automatically for Dungeons, Scenarios and the Raid Finder. For everything else — normal and heroic raids, challenge modes — ask in chat, in your guild, or in the Looking For Group channel.

]]..C.."Seviath's Dungeons & Raids"..R..[[ (built into this addon, /sdr) keeps notes and tags on the players you meet, shows your group's raid buffs and tier tokens, and filters lists when the game offers Premade Groups. ]]..C.."Seviath's Guild Helper"..R..[[ (/gi) finds and invites guild members.]] },

------------------------------------------------------------------------
-- The world
------------------------------------------------------------------------
{ id = "travel", group = "3. World & Travel", title = "Getting around: hearth, portals, flying", icon = "Spell_Arcane_PortalStormwind",
  tags = "travel portal room hearthstone flying flight path taxi pandaria",
  body = [[
]]..C.."Hearthstone"..R..[[ — teleports you to the inn you bound it to.
]]..C.."Flight masters"..R..[[ — talk to them to fly between discovered points.
]]..C.."Portals"..R..[[ — mages teleport/portal you to the capitals; Stormwind and Orgrimmar have portal rooms to the other continents and the Pandaria hubs.
]]..C.."Flying"..R..[[ — learn Flight Master's License (level 60) and Cold Weather Flying for Northrend; Pandaria's flying (Wisdom of the Four Winds) opens at level 90.

Each Entrances page in this Codex says where the entrance is and how to reach it.]] },

{ id = "oldworld", group = "3. World & Travel", title = "Famous old places and how to enter", icon = "INV_Misc_Map_01",
  tags = "entrance old raid caverns of time blackrock karazhan black temple icecrown pandaria",
  body = [[
Some places new players often can't find:

• ]]..C.."Blackrock Mountain"..R..[[ — between Searing Gorge and Burning Steppes. Inside: Blackrock Depths, Blackwing Lair, Molten Core and more.
• ]]..C.."Caverns of Time"..R..[[ — Tanaris (Kalimdor). Many dungeons and raids from history, including Dragon Soul.
• ]]..C.."Karazhan"..R..[[ — Deadwind Pass (Eastern Kingdoms).
• ]]..C.."Black Temple"..R..[[ — Shadowmoon Valley (Outland).
• ]]..C.."Icecrown Citadel"..R..[[ — Icecrown (Northrend).
• ]]..C.."Ulduar"..R..[[ — The Storm Peaks (Northrend).
• ]]..C.."Mogu'shan Vaults"..R..[[ — Kun-Lai Summit (Pandaria); ]]..C.."Siege of Orgrimmar"..R..[[ — Vale of Eternal Blossoms; ]]..C.."Throne of Thunder"..R..[[ — Isle of Thunder.

Open the ]]..C.."Entrances"..R..[[ section and press Show on map — every dungeon and raid entrance the game knows is listed with exact coordinates.]] },

{ id = "quests", group = "3. World & Travel", title = "How quests work", icon = "INV_Misc_Note_01",
  tags = "quest daily weekly campaign elite group objectives",
  body = [[
]]..C.."Yellow !"..R..[[ — a quest you can pick up. ]]..C.."Blue !"..R..[[ — a repeatable one (daily/weekly). ]]..C.."?"..R..[[ — ready to hand in.

Quest types you'll see:
• Normal — do the objectives once, hand in, done.
• Daily — repeatable once a day after the daily reset; Pandaria is full of them and they are the main way to earn reputation.
• Elite / Group — tougher enemies; bring a friend or a group.
• Dungeon / Raid — objectives inside an instance.

Your quest log (L) holds a limited number of quests; abandon old ones you don't need. Use the map (M) — objective areas are highlighted and the tracker on the right shows progress.

The Quests section lists every quest with only its objectives (what to do), its type, expansion and whether this character has done it.]] },

{ id = "reputation", group = "3. World & Travel", title = "Daily quests and reputations", icon = "Achievement_Reputation_01",
  tags = "daily reputation faction golden lotus klaxxi tillers august celestials shado-pan lorewalkers anglers",
  body = [[
Pandaria's endgame is built on ]]..C.."daily quests"..R..[[ and ]]..C.."reputations"..R..[[ (Friendly » Exalted): The Golden Lotus, Order of the Cloud Serpent, The August Celestials, Shado-Pan, The Klaxxi, The Lorewalkers, The Anglers, The Tillers and more.

Reaching higher standing unlocks gear, mounts (cloud serpents, riding turtles), pets and recipes. Track progress in the reputation panel (Character window » Reputation).]] },

{ id = "rares", group = "3. World & Travel", title = "Rares and treasures", icon = "Achievement_Boss_Archaedas",
  tags = "rare elite treasure skull silver dragon",
  body = [[
]]..C.."Rares"..R..[[ are special enemies with a silver dragon around their portrait. They respawn on timers and can drop mounts, pets and gear. Many show as skull icons on the map when up.

]]..C.."Treasures"..R..[[ are chests hidden around zones, often with achievements for finding them all.

Every rare that shows up on your minimap is saved to the Bosses section (Rares groups) with its exact spot, for all your characters.]] },

------------------------------------------------------------------------
-- Collections
------------------------------------------------------------------------
{ id = "mounts", group = "4. Collections", title = "Getting mounts", icon = "Ability_Mount_RidingHorse",
  tags = "mount collect riding drop vendor reputation",
  body = [[
Mounts come from: drops (bosses, rares), vendors (gold or currencies), reputation, achievements, quests, professions, events and the shop.

The ]]..C.."Mounts"..R..[[ section here lists every mount in the game grouped by how you get it, with the exact source text from the game (boss, zone, cost). Uncollected ones are shown dimmed.

Search a boss name to see if it drops a mount, or search "drop" + a zone name.]] },

{ id = "pets", group = "4. Collections", title = "Battle pets and pet battles", icon = "INV_Box_PetCarrier_01",
  tags = "pet battle wild family strong weak trainer",
  body = [[
Pet battles started in Mists of Pandaria. Learn them from a Battle Pet Trainer, then click wild pets (paw icons in zones) to fight and capture them.

]]..C.."Family strengths"..R..[[ (attacker deals extra damage to):
Humanoid » Dragonkin · Dragonkin » Magic · Magic » Flying · Flying » Aquatic · Aquatic » Elemental · Elemental » Mechanical · Mechanical » Beast · Beast » Critter · Critter » Undead · Undead » Humanoid

Rarity: Poor < Common < Uncommon < Rare. Stones from pet battles upgrade rarity.

The Battle Pets section lists every obtainable species grouped by family, with where to find it.]] },

{ id = "transmog", group = "4. Collections", title = "Transmogrification", icon = "INV_Chest_Cloth_17",
  tags = "transmog appearance void storage look",
  body = [[
At a Transmogrifier NPC in any major city you can change the look of an item to the look of another item you own — it costs gold and the item you use must be in your bags (or Void Storage). Transmogrified items stay as they look until you change them.

Farm old raids (see "Soloing old raids") to collect armor sets. Void Storage (at the Void Storage NPC) keeps spare items safely.]] },

{ id = "achievements", group = "4. Collections", title = "Achievements and titles", icon = "Achievement_Quests_Completed_08",
  tags = "achievement title points reward",
  body = [[
Achievements (Y) track goals: exploration, quests, dungeons, raids, PvP, collections and more. Many give rewards: ]]..C.."titles"..R..[[, mounts, pets.

Search "title" in the Codex to find achievements that reward a title, or "reward" to see everything that gives something. Each achievement page shows your criteria progress.]] },

------------------------------------------------------------------------
-- Professions
------------------------------------------------------------------------
{ id = "professions", group = "5. Professions", title = "Professions: the basics", icon = "Trade_BlackSmithing",
  tags = "profession gathering crafting trainer cooking fishing archaeology",
  body = [[
You can learn ]]..C.."two primary professions"..R..[[ plus the secondary ones (Archaeology, Cooking, Fishing).

]]..C.."Gathering"..R..[[: Herbalism, Mining, Skinning — collect materials from nodes and corpses. Easy gold and good for beginners.
]]..C.."Crafting"..R..[[: Alchemy, Blacksmithing, Enchanting, Engineering, Inscription, Jewelcrafting, Leatherworking, Tailoring — turn materials into gear, potions and more.

Skill goes from 1 to 600 and you learn each tier from a trainer. A classic pair: one gathering + one crafting that uses it (Mining + Blacksmithing, Herbalism + Alchemy, Skinning + Leatherworking).]] },

{ id = "mats", group = "5. Professions", title = "Finding materials (mats & reagents)", icon = "INV_Misc_Herb_Felblossom",
  tags = "mats reagents materials farm cloth leather ore herb",
  body = [[
• ]]..C.."Herbs and ore"..R..[[ — nodes in the open world (track them from the minimap's tracking menu).
• ]]..C.."Leather"..R..[[ — skin beasts after killing them (Skinning).
• ]]..C.."Cloth"..R..[[ — drops from humanoid enemies; no profession needed.
• ]]..C.."Enchanting dust"..R..[[ — disenchant green-or-better gear.
• ]]..C.."Meat and fish"..R..[[ — beasts and fishing pools, for Cooking.

The ]]..C.."Gold Farming"..R..[[ section lists good places to make gold. The open-world farm spots, rares and gathering routes per expansion are on your world map from the Farm Pack layer button.]] },

------------------------------------------------------------------------
-- Economy
------------------------------------------------------------------------
{ id = "auction", group = "6. Gold & Trading", title = "The Auction House", icon = "INV_Misc_Coin_02",
  tags = "auction house ah sell buy deposit gold",
  body = [[
Auction Houses are in every capital. Your faction's house takes a small cut of every sale and a deposit up front (returned if it sells); the neutral Goblin houses (Gadgetzan, Booty Bay, Everlook, Ratchet) take a bigger cut but let both factions trade.

Check prices before listing, and don't undercut by a lot — you only lose gold. Use Auctionator (the Farm Pack reads its prices) and /sfp scan to load farm prices.]] },

{ id = "binding", group = "6. Gold & Trading", title = "Soulbound, BoE and heirlooms", icon = "INV_Misc_Key_03",
  tags = "soulbound boe bind on equip account heirloom trade",
  body = [[
]]..C.."Soulbound"..R..[[ — yours forever; can't be traded.
]]..C.."Binds when equipped (BoE)"..R..[[ — tradeable and sellable until someone wears it. Often worth gold!
]]..C.."Bound to account"..R..[[ — heirlooms and some rewards can be sent between your own characters.]] },

{ id = "gold", group = "6. Gold & Trading", title = "Simple ways to make gold", icon = "INV_Misc_Coin_01",
  tags = "gold money farm sell",
  body = [[
• Gather: herbs, ore, leather and cloth always sell.
• Sell BoE gear and recipes from old raids on the Auction House.
• Do daily quests with gold rewards.
• Craft and sell what your profession makes.
• Old content farming — the Farm Pack shows the best open-world spots per expansion with auction values.

Never buy gold from outside the game — it gets accounts banned.]] },
}

-- Register the articles as Codex entries
function ns:LoadGuide()
    for i, a in ipairs(self.GUIDE) do
        self:Add({
            cat = "guide", id = a.id, name = a.title, group = a.group,
            icon = "Interface\\Icons\\" .. (a.icon or "INV_Misc_Book_09"),
            sub = a.tags, tags = a.tags, body = a.body, order = i,
        })
    end
end
