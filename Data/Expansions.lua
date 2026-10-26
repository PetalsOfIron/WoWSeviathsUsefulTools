-- SeviathsUsefulTools - farm zones and old instances per expansion
-- map = uiMapID (the game supplies the localized zone name).
-- Only zones that drop in-demand creature loot are listed, so every listed zone
-- glows cyan (you can raise the bar with /sfp min <gold>).
-- Instance entrance coordinates are read in-game from the Encounter Journal.

local _, SFP = ...

SFP.Expansions = {
    -------------------------------------------------------------------------
    {
        key = "classic", name = "Classic", short = "Classic",
        zones = {
            { map = 83,  items = { 14047, 8170, 34535, 20769 } },                       -- Winterspring
            { map = 23,  items = { 14047, 12808, 8170, 20769, 16252 } },                       -- Eastern Plaguelands
            { map = 22,  items = { 14047, 12808, 20769 } },                             -- Western Plaguelands
            { map = 77,  items = { 14256, 14047, 12803, 8170, 20769 } },                -- Felwood
            { map = 78,  items = { 15417, 8170, 7078, 20769 } },                        -- Un'Goro Crater
            { map = 81,  items = { 14047, 15408, 7076, 7082, 7080, 7078, 20769 } },     -- Silithus
            { map = 36,  items = { 15416, 7078, 7077, 10822, 14047 } },                 -- Burning Steppes
            { map = 32,  items = { 7077, 7068, 7078 } },                                -- Searing Gorge
            { map = 15,  items = { 10822, 4304, 7067 } },                               -- Badlands
            { map = 56,  items = { 8499, 10822 } },                                     -- Wetlands
            { map = 51,  items = { 8498, 15412, 8165 } },                               -- Swamp of Sorrows
            { map = 69,  items = { 8498, 8170, 4304, 12207 } },                         -- Feralas
            { map = 70,  items = { 10822, 4338, 4304, 8165 } },                         -- Dustwallow Marsh
            { map = 76,  items = { 15415, 14047 } },                                    -- Azshara
            { map = 210, items = { 8494, 4338, 4306 } },                                -- The Cape of Stranglethorn
            { map = 50,  items = { 8494, 4338, 4306 } },                                -- Northern Stranglethorn
        },
        instances = {
            { name = "Molten Core",          map = 36, kind = "raid",    alias = "Blackrock Mountain", items = { 17010, 17011, 17012, 7078 } },
            { name = "Blackwing Lair",       map = 36, kind = "raid",    alias = "Blackrock Mountain", items = { 15416, 14047 } },
            { name = "Blackrock Depths",     map = 36, kind = "dungeon", alias = "Blackrock Mountain", items = { 7078, 7077, 14047 }, note = "Huge pulls: vendor gold and BoE items. Long but rewarding clear. Dark Iron Ore drops from its golems." },
            { name = "Lower Blackrock Spire", map = 36, kind = "dungeon", alias = "Blackrock Mountain", items = { 14047, 15416 } },
            { name = "Stratholme",           map = 23, kind = "dungeon", items = { 13335, 12811, 14047, 12808 }, note = "Lord Aurius Rivendare (Baron Rivendare in Classic) drops Deathcharger's Reins (~1%). Easy solo run at level 90 - the Live (Rivendare) side is the quick one." },
            { name = "Onyxia's Lair",        map = 70, kind = "raid",    items = { 49636 } },
            { name = "Temple of Ahn'Qiraj",  map = 81, entranceMap = 327, kind = "raid", items = { 21218, 21323, 21324, 21321 } },
            { name = "Scholomance",          map = 22, kind = "dungeon", items = { 14047, 12808 } },
            { name = "Dire Maul",            map = 69, kind = "dungeon", items = { 14047, 14256 } },
            { name = "Maraudon",             map = 66, kind = "dungeon", items = { },
              note = "Very dense mobs, transmog drops and herbs inside - a good loop for BoEs and gathering." },
            { name = "Uldaman",              map = 15, kind = "dungeon", items = { },
              note = "Known for rare, valuable transmog appearances - a lottery farm." },
            { name = "Razorfen Kraul",       map = 199, kind = "dungeon", items = { },
              note = "Short and fast to clear - good to chain many runs for BoE drops." },
            { name = "Zul'Gurub",            map = 50, kind = "raid",    items = { 19872, 19902 } },
        },
        anywhere = { 12208, 1982, 812, 1168, 1728 },
    },
    -------------------------------------------------------------------------
    {
        key = "tbc", name = "The Burning Crusade", short = "TBC",
        zones = {
            { map = 100, items = { 21877, 21887, 25700, 22574 } },                      -- Hellfire Peninsula
            { map = 102, items = { 22578, 22575, 21887, 21877 } },                      -- Zangarmarsh
            { map = 108, items = { 21877, 21887 } },                                    -- Terokkar Forest
            { map = 107, items = { 25708, 22572, 22573, 22574, 27678, 21887 } },        -- Nagrand
            { map = 105, items = { 21877, 21887, 22573, 29547 } },                      -- Blade's Edge Mountains
            { map = 109, items = { 22576, 21877 } },                                    -- Netherstorm
            { map = 104, items = { 22574, 22577, 29548, 21877, 25700, 29539 } },        -- Shadowmoon Valley
            { map = 122, items = { 31331, 21877 } },                                    -- Isle of Quel'Danas
        },
        instances = {
            { name = "Karazhan",              map = 42,  kind = "raid",    items = { 30480, 21877, 22456, 31331 }, note = "Attumen the Huntsman drops the Fiery Warhorse's Reins. Easy solo farm at level 90 - weekly lockout." },
            { name = "Black Temple",          map = 104, kind = "raid",    items = { 21877, 22456, 21884 } },
            { name = "Serpentshrine Cavern",  map = 102, kind = "raid",    alias = "Coilfang Reservoir", items = { 21885, 21877 } },
            { name = "The Underbog",          map = 102, kind = "dungeon", alias = "Coilfang Reservoir", items = { 21886, 22575 } },
            { name = "Mana-Tombs",            map = 108, kind = "dungeon", alias = "Auchindoun", items = { 22457, 21877 } },
            { name = "Sethekk Halls",         map = 108, kind = "dungeon", alias = "Auchindoun", items = { 32768 } },
            { name = "Tempest Keep",          map = 109, kind = "raid",    items = { 32458 }, note = "Kael'thas Sunstrider (The Eye) drops Ashes of Al'ar. Easy solo mount farm at level 90 - weekly lockout, low drop chance: farm it once a week on every max-level character." },
            { name = "Magisters' Terrace",    map = 122, kind = "dungeon", items = { 35513 }, note = "Kael'thas (Heroic) drops the Swift White Hawkstrider (~3%). Short Heroic dungeon - farm it every day." },
        },
        anywhere = { 22451, 22452, 31331 },
    },
    -------------------------------------------------------------------------
    {
        key = "wrath", name = "Wrath of the Lich King", short = "Wrath",
        zones = {
            { map = 114, items = { 33470, 33568, 38561, 43013 } },                      -- Borean Tundra
            { map = 115, items = { 38557, 33470, 33568, 38561, 43013, 36479 } },               -- Dragonblight
            { map = 116, items = { 33568, 33470, 43013, 44128, 36479 } },                      -- Grizzly Hills
            { map = 117, items = { 33470, 33568, 43009 } },                             -- Howling Fjord
            { map = 118, items = { 33470, 37703, 43013 } },                             -- Icecrown
            { map = 119, items = { 37704, 37705, 33470, 33568, 36479 } },                      -- Sholazar Basin
            { map = 120, items = { 33470, 44128, 38557, 37701, 37700, 43013 } },        -- The Storm Peaks
            { map = 121, items = { 33470, 33568, 37703, 36479 } },                             -- Zul'Drak
            { map = 123, items = { 37702, 37701, 33470 } },                             -- Wintergrasp
        },
        instances = {
            { name = "Naxxramas",                 map = 115, kind = "raid",    items = { 33470, 37703 } },
            { name = "Ulduar",                    map = 120, kind = "raid",    items = { 45693, 33470, 37701 }, note = "Yogg-Saron with no Keepers helping (25-player) drops Mimiron's Head. Easy solo mount farm at level 90 - weekly lockout, low drop chance: farm it once a week on every max-level character." },
            { name = "Icecrown Citadel",          map = 118, kind = "raid",    items = { 50818, 33470, 37703 }, note = "The Lich King (25-player Heroic) drops Invincible's Reins. Easy solo mount farm at level 90 - weekly lockout, low drop chance: farm it once a week on every max-level character." },
            { name = "Azjol-Nerub",               map = 115, kind = "dungeon", items = { 38558, 33470 } },
            { name = "Ahn'kahet: The Old Kingdom", map = 115, kind = "dungeon", items = { 38558, 33470 } },
            { name = "The Obsidian Sanctum",      map = 115, kind = "raid",    items = { 43986, 43954 } },
            { name = "The Eye of Eternity",       map = 114, kind = "raid",    items = { 43952, 43953 } },
            { name = "The Oculus",                map = 114, kind = "dungeon", items = { 43953 } },
            { name = "Utgarde Pinnacle",          map = 117, kind = "dungeon", items = { 44151 }, note = "Skadi the Ruthless (Heroic) drops the Reins of the Blue Proto-Drake. Short Heroic dungeon - farm it every day." },
            { name = "Vault of Archavon",         map = 123, kind = "raid",    items = { 43959 } },
        },
        anywhere = { 44128, 36479 },
    },
    -------------------------------------------------------------------------
    {
        key = "cata", name = "Cataclysm", short = "Cata",
        zones = {
            { map = 198, items = { 53010, 52976, 52325 } },                             -- Mount Hyjal
            { map = 201, items = { 53010, 52982, 52326 } },                             -- Kelp'thar Forest
            { map = 205, items = { 53010, 52982, 52326, 52976 } },                      -- Shimmering Expanse
            { map = 204, items = { 53010, 52982, 52326 } },                             -- Abyssal Depths
            { map = 207, items = { 52327, 52976 } },                                    -- Deepholm
            { map = 249, items = { 52328, 53010, 52976, 52329 } },                      -- Uldum
            { map = 241, items = { 53010, 52976, 52979, 52328, 52325 } },               -- Twilight Highlands
        },
        instances = {
            { name = "Firelands",              map = 198, kind = "raid", items = { 71665, 69224, 52325, 53010 } },
            { name = "The Bastion of Twilight", map = 241, kind = "raid", items = { 53010, 52979 } },
            { name = "Dragon Soul",            map = 71,  kind = "raid", alias = "Caverns of Time", items = { 78919, 77067, 53010 } },
            { name = "Throne of the Four Winds", map = 249, kind = "raid", items = { 63041 } },
            { name = "The Stonecore",          map = 207, kind = "dungeon", items = { 63043 } },
            { name = "The Vortex Pinnacle",    map = 249, kind = "dungeon", items = { 63040 } },
            { name = "Zul'Gurub",              map = 50,  kind = "dungeon", items = { 68824, 68823 } },
        },
        anywhere = { 52555, 52719, 52721 },
    },
    -------------------------------------------------------------------------
    {
        key = "mop", name = "Mists of Pandaria", short = "MoP",
        zones = {
            { map = 371, items = { 72988, 72120, 74837 } },                             -- The Jade Forest
            { map = 376, items = { 72988, 72120, 74839, 74834, 74838, 89783 } },        -- Valley of the Four Winds (+ Galleon mount)
            { map = 507, items = { 94228 } },                                           -- Isle of Giants (Oondasta mount)
            { map = 418, items = { 72988, 72120, 74838, 74837 } },                      -- Krasarang Wilds
            { map = 379, items = { 72988, 72120, 74834, 87771 } },                             -- Kun-Lai Summit
            { map = 388, items = { 72988, 72120, 79101, 72163, 74833 } },               -- Townlong Steppes
            { map = 422, items = { 72988, 72120, 79101, 72163, 75014 } },               -- Dread Wastes
            { map = 390, items = { 72988, 72120 } },                                    -- Vale of Eternal Blossoms
        },
        instances = {
            { name = "Siege of Orgrimmar", map = 390, kind = "raid", items = { 104253, 72988 } },
            { name = "Throne of Thunder",  map = 504, kind = "raid", items = { 93666, 95059, 95057, 72988 } },
            { name = "Mogu'shan Vaults",   map = 379, kind = "raid", items = { 87777 } },
        },
        anywhere = { 72163, 74249, 74250, 74248 },
    },
--[===[ NEWER EXPANSIONS (Warlords of Draenor and later) - kept for when the game gets them; delete this opener and the matching closer to enable
    -------------------------------------------------------------------------
    {
        key = "wod", name = "Warlords of Draenor", short = "WoD",
        zones = {
            { map = 525, items = { 111557, 110609, 109131 } },                          -- Frostfire Ridge
            { map = 543, items = { 111557, 110609, 109133 } },                          -- Gorgrond
            { map = 535, items = { 111557, 110609, 109134, 109135 } },                  -- Talador
            { map = 542, items = { 111557, 110609, 109133 } },                          -- Spires of Arak
            { map = 550, items = { 111557, 110609, 109131, 109132, 118785 } },                  -- Nagrand
            { map = 539, items = { 111557, 110609, 109134, 109136 } },                  -- Shadowmoon Valley
            { map = 534, items = { 111557, 110609, 109133, 109136 } },                  -- Tanaan Jungle
        },
        instances = {
            { name = "Blackrock Foundry",  map = 543, kind = "raid", items = { 116660 } },
            { name = "Hellfire Citadel",   map = 534, kind = "raid", items = { 123890 } },
        },
        anywhere = { 118785, 109693, 113588 },
    },
    -------------------------------------------------------------------------
    {
        key = "legion", name = "Legion", short = "Legion",
        zones = {
            { map = 630, items = { 124437, 124113, 124115, 124117, 124121 } },          -- Azsuna
            { map = 641, items = { 124437, 124113, 124118 } },                          -- Val'sharah
            { map = 650, items = { 124437, 124113, 124115, 124119, 124118 } },          -- Highmountain
            { map = 634, items = { 124437, 124113, 124115, 124117, 124119 } },          -- Stormheim
            { map = 680, items = { 124437, 124113, 124116, 124120 } },                  -- Suramar
            { map = 646, items = { 124437, 124116 } },                                  -- Broken Shore
            { map = 830, items = { 151567, 151566 } },                                  -- Krokuun
            { map = 885, items = { 151567, 151566 } },                                  -- Antoran Wastes
            { map = 882, items = { 151567, 151566 } },                                  -- Eredath
        },
        instances = {
            { name = "Return to Karazhan",          map = 42,  kind = "dungeon", alias = "Karazhan", items = { 142236, 142552 } },
            { name = "The Nighthold",               map = 680, kind = "raid", items = { 137574, 137575 } },
            { name = "Tomb of Sargeras",            map = 646, kind = "raid", items = { 143643 } },
            { name = "Antorus, the Burning Throne", map = 885, kind = "raid", items = { 152789 } },
        },
        anywhere = { 124440, 124441, 124442 },
    },
    -------------------------------------------------------------------------
    {
        key = "bfa", name = "Battle for Azeroth", short = "BfA",
        zones = {
            { map = 895,  items = { 152576, 152577, 152541, 154722, 154898, 154897 } }, -- Tiragarde Sound
            { map = 896,  items = { 152576, 152541, 154164, 154898 } },                 -- Drustvar
            { map = 942,  items = { 152576, 152541, 154722, 154897, 158180 } },                 -- Stormsong Valley
            { map = 862,  items = { 152576, 152577, 152541, 153050, 154899 } },         -- Zuldazar
            { map = 863,  items = { 152576, 152541, 154164, 154165, 153050 } },         -- Nazmir
            { map = 864,  items = { 152576, 152541, 153050, 153051 } },                 -- Vol'dun
            { map = 1355, items = { 167738, 168649, 168650 } },                         -- Nazjatar
            { map = 1462, items = { 167738, 168649 } },                                 -- Mechagon Island
        },
        instances = {
            { name = "Freehold",                  map = 895,  kind = "dungeon", items = { 159842 } },
            { name = "The Underrot",              map = 863,  kind = "dungeon", items = { 160829 } },
            { name = "Operation: Mechagon",       map = 1462, kind = "dungeon", items = { 168826 } },
            { name = "Battle of Dazar'alor",      map = 862,  kind = "raid", items = { 166518, 166705 } },
            { name = "Ny'alotha, the Waking City", map = 1530, kind = "raid", items = { 174872 } },
        },
        anywhere = { 152875, 152876, 152877 },
    },
    -------------------------------------------------------------------------
    {
        key = "sl", name = "Shadowlands", short = "SL",
        zones = {
            { map = 1533, items = { 173202, 173204, 172089, 172094, 172054 } },         -- Bastion
            { map = 1536, items = { 173202, 172089, 172092, 172053 } },                 -- Maldraxxus
            { map = 1565, items = { 173202, 172089, 172094, 179314 } },                 -- Ardenweald
            { map = 1525, items = { 173202, 173204, 172089, 172096, 179315 } },         -- Revendreth
            { map = 1543, items = { 173202, 172096, 172097 } },                         -- The Maw
            { map = 1961, items = { 173202, 172097 } },                                 -- Korthia
            { map = 1970, items = { 173202, 172097, 172096, 190735 } },                         -- Zereth Mortis
        },
        instances = {
            { name = "Tazavesh, the Veiled Market",     map = 1670, kind = "dungeon", items = { 186638 } },
            { name = "Sanctum of Domination",           map = 1543, kind = "raid", items = { 186656 } },
            { name = "Sepulcher of the First Ones",     map = 1970, kind = "raid", items = { 190768 } },
        },
        anywhere = { 172097, 172052, 172230, 172231, 172232 },
    },
    -------------------------------------------------------------------------
    {
        key = "df", name = "Dragonflight", short = "DF",
        zones = {
            { map = 2022, items = { 193922, 193925, 193050, 193208, 193213, 190320, 190315, 197743, 197745 } }, -- The Waking Shores
            { map = 2023, items = { 193922, 193050, 193208, 190326, 197741, 197746 } },                         -- Ohn'ahran Plains
            { map = 2024, items = { 193922, 193924, 193050, 193208, 193213, 190328, 197744, 197747, 197748 } }, -- The Azure Span
            { map = 2025, items = { 193922, 193923, 193050, 193208, 190322, 190330, 190326, 197742 } },         -- Thaldraszus
            { map = 2151, items = { 193922, 193208, 193213 } },                                                 -- The Forbidden Reach
            { map = 2133, items = { 193922, 193208, 193213, 190315 } },                                         -- Zaralek Cavern
            { map = 2200, items = { 193922, 193208, 190320 } },                                                 -- Emerald Dream
        },
        instances = {
            { name = "Vault of the Incarnates",            map = 2025, kind = "raid", items = { 193922, 190328, 190320 } },
            { name = "Aberrus, the Shadowed Crucible",     map = 2133, kind = "raid", items = { 193922 } },
            { name = "Amirdrassil, the Dream's Hope",      map = 2200, kind = "raid", items = { 210061, 193922 } },
        },
        -- rare hides drop from skinning across the Dragon Isles
        anywhere = { 193216, 193222, 193226, 193229, 193232, 194123, 194124, 200113 },
    },
    -------------------------------------------------------------------------
    {
        key = "tww", name = "The War Within", short = "TWW",
        zones = {
            { map = 2248, items = { 224828, 228233, 212664, 212670 } },                 -- Isle of Dorn
            { map = 2214, items = { 224828, 228233, 212664, 212667 } },                 -- The Ringing Deeps
            { map = 2215, items = { 224828, 228233, 212664, 212670 } },                 -- Hallowfall
            { map = 2255, items = { 224828, 228233, 212667, 212674 } },                 -- Azj-Kahet
            { map = 2346, items = { 224828, 228233, 212664 } },                         -- Undermine
            { map = 2369, items = { 224828, 228233, 212664 } },                         -- Siren Isle
            { map = 2371, items = { 224828, 228233, 212664 } },                         -- K'aresh
        },
        instances = {
            { name = "Nerub-ar Palace",           map = 2255, kind = "raid", items = { 224147 } },
            { name = "Liberation of Undermine",   map = 2346, kind = "raid", items = { 236960 } },
        },
        anywhere = { 212670, 212674, 219946, 219949, 219952 },
    },
    -------------------------------------------------------------------------
    {
        key = "midnight", name = "Midnight", short = "Midnight",
        zones = {
            { map = 2395, items = { 236963, 237016, 237017, 238511, 238513, 238522, 238525 } }, -- Eversong Woods
            { map = 2437, items = { 236963, 237016, 237017, 238511, 238523, 238525 } },         -- Zul'Aman
            { map = 2413, items = { 236963, 237016, 237017, 238511, 238522, 238523 } },         -- Harandar
            { map = 2405, items = { 236963, 237016, 237017, 238511, 238513, 238523 } },         -- Voidstorm
        },
        instances = {
            { name = "Magisters' Terrace", map = 2424, kind = "dungeon", items = { 260231 } },
            { name = "Windrunner Spire",   map = 2395, kind = "dungeon", items = { 262914 } },
            { name = "March on Quel'Danas", map = 2424, kind = "raid",   items = { 246590 },
              note = "Trash at the start of the raid can drop Myth-track BoEs (one per character per week)." },
            { name = "The Venomous Abyss",  map = 2512, kind = "raid",   items = { 271638, 271445, 271444, 271440, 271441, 271436, 271438, 271435, 271434 } },
        },
        anywhere = { 238518, 238520, 238528, 238529, 238530 },
    },
]===]
}

