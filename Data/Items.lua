-- SeviathsUsefulTools - item data
-- Every item ID here was checked against Wowhead's item data (name + quality).
-- Grey/poor items are left out on purpose. Names and icons come from the game
-- client at runtime, so they show in your own language.
-- drop  = drop chance for BoE items, from Wowhead's drop data / comments (approximate)
-- tiers = Dragonflight crafting-quality versions (all scanned on the AH; not used in Mists of Pandaria)

local _, SFP = ...

SFP.Items = {
    ---------------------------------------------------------------- Classic
    [4306]  = { kind = "cloth" },                 -- Silk Cloth
    [4338]  = { kind = "cloth" },                 -- Mageweave Cloth
    [14047] = { kind = "cloth" },                 -- Runecloth
    [14256] = { kind = "cloth" },                 -- Felcloth
    [4304]  = { kind = "leather" },               -- Thick Leather
    [8170]  = { kind = "leather" },               -- Rugged Leather
    [15417] = { kind = "leather" },               -- Devilsaur Leather
    [17012] = { kind = "leather" },               -- Core Leather
    [15408] = { kind = "leather" },               -- Heavy Scorpid Scale
    [15416] = { kind = "leather" },               -- Black Dragonscale
    [15412] = { kind = "leather" },               -- Green Dragonscale
    [15415] = { kind = "leather" },               -- Blue Dragonscale
    [8165]  = { kind = "leather" },               -- Worn Dragonscale
    [7078]  = { kind = "element" },               -- Essence of Fire
    [7080]  = { kind = "element" },               -- Essence of Water
    [7076]  = { kind = "element" },               -- Essence of Earth
    [7082]  = { kind = "element" },               -- Essence of Air
    [12808] = { kind = "element" },               -- Essence of Undeath
    [12803] = { kind = "element" },               -- Living Essence
    [7068]  = { kind = "element" },               -- Elemental Fire
    [7067]  = { kind = "element" },               -- Elemental Earth
    [7077]  = { kind = "element" },               -- Heart of Fire
    [12811] = { kind = "element" },               -- Righteous Orb
    [17010] = { kind = "element" },               -- Fiery Core
    [17011] = { kind = "element" },               -- Lava Core
    [12207] = { kind = "meat" },                  -- Giant Egg
    [12208] = { kind = "meat" },                  -- Tender Wolf Meat
    [8494]  = { kind = "pet", drop = "~0.012%", note = "Bloodsail pirates / STV mobs" }, -- Parrot Cage (Hyacinth Macaw)
    [10822] = { kind = "pet", drop = "~0.1%",   note = "whelps" },                       -- Dark Whelpling
    [8499]  = { kind = "pet", drop = "~0.01%",  note = "any Wetlands mob" },              -- Tiny Crimson Whelpling
    [8498]  = { kind = "pet", drop = "~0.1%",   note = "whelps" },                       -- Emerald Whelpling
    [34535] = { kind = "pet", drop = "~0.01-0.04%", note = "Winterspring mobs" },        -- Azure Whelpling
    [20769] = { kind = "pet", drop = "~0.1%",   note = "oozes (Oozing Bag)" },           -- Disgusting Oozeling

    ---------------------------------------------------------------- The Burning Crusade
    [21877] = { kind = "cloth" },                 -- Netherweave Cloth
    [21887] = { kind = "leather" },               -- Knothide Leather
    [25700] = { kind = "leather" },               -- Fel Scales
    [29548] = { kind = "leather" },               -- Nether Dragonscales
    [29539] = { kind = "leather" },               -- Cobra Scales
    [29547] = { kind = "leather" },               -- Wind Scales
    [25708] = { kind = "leather" },               -- Thick Clefthoof Leather
    [21884] = { kind = "element" },               -- Primal Fire
    [21885] = { kind = "element" },               -- Primal Water
    [22451] = { kind = "element" },               -- Primal Air
    [22452] = { kind = "element" },               -- Primal Earth
    [21886] = { kind = "element" },               -- Primal Life
    [22457] = { kind = "element" },               -- Primal Mana
    [22456] = { kind = "element" },               -- Primal Shadow
    [22574] = { kind = "element" },               -- Mote of Fire
    [22578] = { kind = "element" },               -- Mote of Water
    [22572] = { kind = "element" },               -- Mote of Air
    [22573] = { kind = "element" },               -- Mote of Earth
    [22575] = { kind = "element" },               -- Mote of Life
    [22576] = { kind = "element" },               -- Mote of Mana
    [22577] = { kind = "element" },               -- Mote of Shadow
    [27678] = { kind = "meat" },                  -- Clefthoof Meat

    ---------------------------------------------------------------- Wrath of the Lich King
    [33470] = { kind = "cloth" },                 -- Frostweave Cloth
    [33568] = { kind = "leather" },               -- Borean Leather
    [44128] = { kind = "leather", note = "rare skinning find" }, -- Arctic Fur
    [38557] = { kind = "leather" },               -- Icy Dragonscale
    [38558] = { kind = "leather" },               -- Nerubian Chitin
    [38561] = { kind = "leather" },               -- Jormungar Scale
    [37702] = { kind = "element" },               -- Crystallized Fire
    [37705] = { kind = "element" },               -- Crystallized Water
    [37700] = { kind = "element" },               -- Crystallized Air
    [37701] = { kind = "element" },               -- Crystallized Earth
    [37704] = { kind = "element" },               -- Crystallized Life
    [37703] = { kind = "element" },               -- Crystallized Shadow
    [43013] = { kind = "meat" },                  -- Chilled Meat
    [43009] = { kind = "meat" },                  -- Shoveltusk Flank

    ---------------------------------------------------------------- Cataclysm
    [53010] = { kind = "cloth" },                 -- Embersilk Cloth
    [52976] = { kind = "leather" },               -- Savage Leather
    [52979] = { kind = "leather" },               -- Blackened Dragonscale
    [52982] = { kind = "leather" },               -- Deepsea Scale
    [52325] = { kind = "element" },               -- Volatile Fire
    [52326] = { kind = "element" },               -- Volatile Water
    [52327] = { kind = "element" },               -- Volatile Earth
    [52328] = { kind = "element" },               -- Volatile Air
    [52329] = { kind = "element" },               -- Volatile Life

    ---------------------------------------------------------------- Mists of Pandaria
    [72988] = { kind = "cloth" },                 -- Windwool Cloth
    [72120] = { kind = "leather" },               -- Mist-Touched Leather
    [79101] = { kind = "leather" },               -- Prismatic Scale
    [72163] = { kind = "leather", note = "rare skinning find" }, -- Magnificent Hide
    [74833] = { kind = "meat" },                  -- Raw Tiger Steak
    [74837] = { kind = "meat" },                  -- Raw Turtle Meat
    [74838] = { kind = "meat" },                  -- Raw Crab Meat
    [74839] = { kind = "meat" },                  -- Wildfowl Breast
    [75014] = { kind = "meat" },                  -- Raw Crocolisk Belly
    [74834] = { kind = "meat" },                  -- Mushan Ribs

--[===[ NEWER EXPANSIONS (Warlords of Draenor and later) - kept for when the game gets them; delete this opener and the matching closer to enable
    ---------------------------------------------------------------- Warlords of Draenor
    [111557] = { kind = "cloth" },                -- Sumptuous Fur
    [110609] = { kind = "leather" },              -- Raw Beast Hide
    [109131] = { kind = "meat" },                 -- Raw Clefthoof Meat
    [109132] = { kind = "meat" },                 -- Raw Talbuk Meat
    [109133] = { kind = "meat" },                 -- Rylak Egg
    [109134] = { kind = "meat" },                 -- Raw Elekk Meat
    [109135] = { kind = "meat" },                 -- Raw Riverbeast Meat
    [109136] = { kind = "meat" },                 -- Raw Boar Meat

    ---------------------------------------------------------------- Legion
    [124437] = { kind = "cloth" },                -- Shal'dorei Silk
    [151567] = { kind = "cloth" },                -- Lightweave Cloth
    [124113] = { kind = "leather" },              -- Stonehide Leather
    [124115] = { kind = "leather" },              -- Stormscale
    [124116] = { kind = "leather" },              -- Felhide
    [151566] = { kind = "leather" },              -- Fiendish Leather
    [124117] = { kind = "meat" },                 -- Lean Shank
    [124118] = { kind = "meat" },                 -- Fatty Bearsteak
    [124119] = { kind = "meat" },                 -- Big Gamy Ribs
    [124120] = { kind = "meat" },                 -- Leyblood
    [124121] = { kind = "meat" },                 -- Wildfowl Egg

    ---------------------------------------------------------------- Battle for Azeroth
    [152576] = { kind = "cloth" },                -- Tidespray Linen
    [152577] = { kind = "cloth" },                -- Deep Sea Satin
    [167738] = { kind = "cloth" },                -- Gilded Seaweave
    [152541] = { kind = "leather" },              -- Coarse Leather
    [154722] = { kind = "leather" },              -- Tempest Hide
    [154164] = { kind = "leather" },              -- Blood-Stained Bone
    [154165] = { kind = "leather" },              -- Calcified Bone
    [153050] = { kind = "leather" },              -- Shimmerscale
    [153051] = { kind = "leather" },              -- Mistscale
    [168649] = { kind = "leather" },              -- Dredged Leather
    [168650] = { kind = "leather" },              -- Cragscale
    [154898] = { kind = "meat" },                 -- Meaty Haunch
    [154897] = { kind = "meat" },                 -- Stringy Loins
    [154899] = { kind = "meat" },                 -- Thick Paleo Steak

    ---------------------------------------------------------------- Shadowlands
    [173202] = { kind = "cloth" },                -- Shrouded Cloth
    [173204] = { kind = "cloth" },                -- Lightless Silk
    [172089] = { kind = "leather" },              -- Desolate Leather
    [172092] = { kind = "leather" },              -- Pallid Bone
    [172094] = { kind = "leather" },              -- Callous Hide
    [172096] = { kind = "leather" },              -- Heavy Desolate Leather
    [172097] = { kind = "leather", note = "rare skinning find" }, -- Heavy Callous Hide
    [172052] = { kind = "meat" },                 -- Aethereal Meat
    [172053] = { kind = "meat" },                 -- Tenebrous Ribs
    [172054] = { kind = "meat" },                 -- Raw Seraphic Wing
    [179314] = { kind = "meat" },                 -- Creeping Crawler Meat
    [179315] = { kind = "meat" },                 -- Shadowy Shank

    ---------------------------------------------------------------- Dragonflight
    [193050] = { kind = "cloth" },                -- Tattered Wildercloth
    [193922] = { kind = "cloth" },                -- Wildercloth
    [193923] = { kind = "cloth" },                -- Decayed Wildercloth
    [193924] = { kind = "cloth" },                -- Frostbitten Wildercloth
    [193925] = { kind = "cloth" },                -- Singed Wildercloth
    [193208] = { kind = "leather", tiers = { 193210, 193211 } }, -- Resilient Leather (Q1-Q3)
    [193213] = { kind = "leather", tiers = { 193214, 193215 } }, -- Adamant Scales (Q1-Q3)
    [193216] = { kind = "leather", tiers = { 193217, 193218 }, note = "rare skinning find" }, -- Dense Hide
    [193222] = { kind = "leather", tiers = { 193223, 193224 }, note = "rare skinning find" }, -- Lustrous Scaled Hide
    [193226] = { kind = "leather", tiers = { 193227, 193228 }, note = "rare skinning find" }, -- Stonecrust Hide
    [193229] = { kind = "leather", tiers = { 193230, 193231 }, note = "rare skinning find" }, -- Mireslush Hide
    [193232] = { kind = "leather", note = "rare skinning find" }, -- Deathchill Hide
    [190315] = { kind = "element" },              -- Rousing Earth
    [190320] = { kind = "element" },              -- Rousing Fire
    [190322] = { kind = "element" },              -- Rousing Order
    [190326] = { kind = "element" },              -- Rousing Air
    [190328] = { kind = "element" },              -- Rousing Frost
    [190330] = { kind = "element" },              -- Rousing Decay
    [197741] = { kind = "meat" },                 -- Maybe Meat
    [197742] = { kind = "meat" },                 -- Ribbed Mollusk Meat
    [197743] = { kind = "meat" },                 -- Waterfowl Filet
    [197744] = { kind = "meat" },                 -- Hornswog Hunk
    [197745] = { kind = "meat" },                 -- Basilisk Eggs
    [197746] = { kind = "meat" },                 -- Bruffalon Flank
    [197747] = { kind = "meat" },                 -- Mighty Mammoth Ribs
    [197748] = { kind = "meat" },                 -- Burly Bear Haunch
    ---------------------------------------------------------------- The War Within
    [224828] = { kind = "cloth" },                                       -- Weavercloth
    [228233] = { kind = "cloth" },                                       -- Duskweave
    [212664] = { kind = "leather", tiers = { 212665, 212666 } },         -- Stormcharged Leather (Q1-Q3)
    [212667] = { kind = "leather", tiers = { 212668, 212669 } },         -- Gloom Chitin (Q1-Q3)
    [212670] = { kind = "leather", tiers = { 212672 }, note = "rare skinning find" },          -- Thunderous Hide
    [212674] = { kind = "leather", tiers = { 212675, 212676 }, note = "rare skinning find" },  -- Sunless Carapace

    ---------------------------------------------------------------- Midnight
    [236963] = { kind = "cloth" },                                       -- Bright Linen
    [237016] = { kind = "cloth", note = "needs Tailoring knowledge" },   -- Sunfire Silk
    [237017] = { kind = "cloth", note = "needs Tailoring knowledge" },   -- Arcanoweave
    [238511] = { kind = "leather", tiers = { 238512 } },                 -- Void-Tempered Leather
    [238513] = { kind = "leather", tiers = { 238514 } },                 -- Void-Tempered Scales
    [238518] = { kind = "leather", tiers = { 238519 }, note = "rare mobs / lures" },           -- Void-Tempered Hide
    [238520] = { kind = "leather", tiers = { 238521 }, note = "rare scale mobs / lures" },     -- Void-Tempered Plating
    [238525] = { kind = "leather", note = "furred beasts" },             -- Fantastic Fur
    [238522] = { kind = "leather", note = "feathered beasts" },          -- Peerless Plumage
    [238523] = { kind = "leather", note = "fanged beasts" },             -- Carving Canine
    [238528] = { kind = "leather", note = "Renowned Beasts (lures)" },   -- Majestic Claw
    [238529] = { kind = "leather", note = "Renowned Beasts (lures)" },   -- Majestic Hide
    [238530] = { kind = "leather", note = "Renowned Beasts (lures)" },   -- Majestic Fin

]===]
    ---------------------------------------------------------------- BoE gear & recipes (checked on Wowhead: binds when equipped / tradeable)
    -- drop chances are community estimates from Wowhead comments - treat them as rough
    [16252]  = { kind = "boe", drop = "~0.8%",        note = "Scarlet Archmage, Tyr's Hand" },          -- Formula: Enchant Weapon - Crusader
    [1982]   = { kind = "boe", drop = "very rare",    note = "world drop, Classic mobs" },               -- Nightblade
    [812]    = { kind = "boe", drop = "~0.02%",       note = "world drop, Sunken Temple / Blasted Lands" }, -- Glowing Brightwood Staff
    [1168]   = { kind = "boe", drop = "very rare",    note = "world drop, Classic mobs" },               -- Skullflame Shield
    [1728]   = { kind = "boe", drop = "very rare",    note = "level 31-33 elites" },                     -- Teebu's Blazing Longsword
    [31331]  = { kind = "boe", drop = "~0.07%",       note = "Outland mobs, Karazhan ghosts" },          -- The Night Blade
    [36479]  = { kind = "boe", drop = "<1%",          note = "Northrend mobs, Dragonblight" },           -- Snobold Ripper
    -- [118785] = { kind = "boe", drop = "rare",         note = "Draenor mobs" },                           -- Void Bound Knife
    -- [158180] = { kind = "boe", drop = "~0.01-0.1%",   note = "Flowing Honey / Bubbling Mead" },          -- The Glazer
    -- [190735] = { kind = "boe", drop = "~0.01-0.18%",  note = "Mawsworn in Zereth Mortis" },              -- Varruth's Guillotine
}

-- Dungeon / raid mounts (Cataclysm to Mists of Pandaria; newer ones commented out). Drop chances are the usual
-- community estimates (Wowhead comments / guides) - treat them as rough.
local function boss(id, drop, note) SFP.Items[id] = { kind = "mount", drop = drop, note = note } end
-- Classic / TBC / Wrath instance mounts
boss(21218,  "~1-2%", "trash, Temple of Ahn'Qiraj")                -- Blue Qiraji Resonating Crystal
boss(21323,  "~1-2%", "trash, Temple of Ahn'Qiraj")                -- Green Qiraji Resonating Crystal
boss(21324,  "~1-2%", "trash, Temple of Ahn'Qiraj")                -- Yellow Qiraji Resonating Crystal
boss(21321,  "<1%",   "trash, Temple of Ahn'Qiraj (rarest)")       -- Red Qiraji Resonating Crystal
boss(13335,  "~1%",   "Lord Aurius Rivendare (Baron Rivendare), Stratholme")               -- Deathcharger's Reins
boss(19872,  "~1%",   "Bloodlord Mandokir, Zul'Gurub (Classic raid)") -- Swift Razzashi Raptor
boss(19902,  "~1%",   "High Priest Thekal, Zul'Gurub (Classic raid)") -- Swift Zulian Tiger
-- Mists of Pandaria world bosses (drop chances are community estimates)
boss(89783,  "~1%",   "Galleon, Valley of the Four Winds (weekly boss)") -- Son of Galleon's Saddle
boss(94228,  "~1%",   "Oondasta, Isle of Giants (world boss)")     -- Reins of the Cobalt Primordial Direhorn
boss(87771,  "<1%",   "Sha of Anger, Kun-Lai Summit (weekly boss)") -- Reins of the Heavenly Onyx Cloud Serpent
boss(95057,  "~1%",   "Nalak, Isle of Thunder (world boss)")       -- Reins of the Thundering Cobalt Cloud Serpent
boss(49636,  "~1%",   "Onyxia, Onyxia's Lair")                     -- Reins of the Onyxian Drake
boss(30480,  "~1%",   "Attumen the Huntsman, Karazhan")            -- Fiery Warhorse's Reins
boss(32458,  "~1-2%", "Kael'thas Sunstrider, Tempest Keep")        -- Ashes of Al'ar
boss(35513,  "~3%",   "Kael'thas (Heroic), Magisters' Terrace")    -- Swift White Hawkstrider
boss(32768,  "~1-2%", "Anzu (Heroic), Sethekk Halls")              -- Reins of the Raven Lord
boss(44151,  "~1%",   "Skadi the Ruthless (Heroic), Utgarde Pinnacle") -- Reins of the Blue Proto-Drake
boss(43952,  "~4%",   "Malygos, The Eye of Eternity")              -- Reins of the Azure Drake
boss(43953,  "~1-4%", "Malygos / Ley-Guardian Eregos (Heroic, Oculus)") -- Reins of the Blue Drake
boss(43986,  "100%",  "Sartharion with 3 drakes up (10)")          -- Reins of the Black Drake
boss(43954,  "100%",  "Sartharion with 3 drakes up (25)")          -- Reins of the Twilight Drake
boss(43959,  "~1%",   "any boss, Vault of Archavon")               -- Reins of the Grand Black War Mammoth
boss(45693,  "~1%",   "Yogg-Saron with no Keepers (25), Ulduar")   -- Mimiron's Head
boss(50818,  "~1%",   "The Lich King (Heroic 25), Icecrown Citadel") -- Invincible's Reins
-- Midnight (commented, for later)
-- boss(260231, "~1-2%", "Degentrius (Mythic / Mythic+), Magisters' Terrace") -- Lucent Hawkstrider
-- boss(262914, "~1-2%", "The Restless Heart (Mythic / Mythic+), Windrunner Spire") -- Spectral Hawkstrider
-- boss(246590, "Mythic", "Midnight Falls (Mythic), March on Quel'Danas") -- Ashes of Belo'ren
boss(63043,  "~0.8%", "Slabhide, The Stonecore")                   -- Reins of the Vitreous Stone Drake
boss(63040,  "~0.8%", "Altairus, The Vortex Pinnacle")             -- Reins of the Drake of the North Wind
boss(63041,  "~1%",   "Al'Akir, Throne of the Four Winds")         -- Reins of the Drake of the South Wind
boss(68824,  "~1%",   "High Priestess Kilnara, Zul'Gurub")         -- Swift Zulian Panther
boss(68823,  "~1%",   "Bloodlord Mandokir, Zul'Gurub")             -- Armored Razzashi Raptor
boss(71665,  "~1-2%", "Alysrazor, Firelands")                      -- Flametalon of Alysrazor
boss(69224,  "~1%",   "Ragnaros, Firelands")                       -- Smoldering Egg of Millagazor
boss(78919,  "~1%",   "Ultraxion, Dragon Soul")                    -- Experiment 12-B
boss(77067,  "~1%",   "Madness of Deathwing, Dragon Soul")         -- Reins of the Blazing Drake
boss(87777,  "~1%",   "Elegon, Mogu'shan Vaults")                  -- Reins of the Astral Cloud Serpent
boss(93666,  "~1-2%", "Horridon, Throne of Thunder")               -- Spawn of Horridon
boss(95059,  "~1-2%", "Ji-Kun, Throne of Thunder")                 -- Clutch of Ji-Kun
boss(104253, "~1%",   "Garrosh (Mythic), Siege of Orgrimmar")      -- Kor'kron Juggernaut
-- boss(116660, "~1%",   "Blackhand (Mythic), Blackrock Foundry")     -- Ironhoof Destroyer
-- boss(123890, "~1%",   "Archimonde (Mythic), Hellfire Citadel")     -- Felsteel Annihilator
-- boss(142236, "~1%",   "Attumen (Mythic), Return to Karazhan")      -- Midnight's Eternal Reins
-- boss(142552, "~20%",  "Nightbane (Mythic), Return to Karazhan")    -- Smoldering Ember Wyrm
-- boss(137574, "~1%",   "Gul'dan (Mythic), The Nighthold")           -- Living Infernal Core
-- boss(137575, "~1%",   "Gul'dan, The Nighthold")                    -- Fiendish Hellfire Core
-- boss(143643, "~1%",   "Mistress Sassz'ine, Tomb of Sargeras")      -- Abyss Worm
-- boss(152789, "~1%",   "Argus (Mythic), Antorus")                   -- Shackled Ur'zul
-- boss(159842, "~0.5%", "Harlan Sweete (Mythic), Freehold")          -- Sharkbait's Favorite Crackers
-- boss(160829, "~0.5%", "Unbound Abomination (Mythic), The Underrot") -- Underrot Crawg Harness
-- boss(168826, "~1%",   "HK-8 (Mythic), Operation: Mechagon")        -- Mechagon Peacekeeper
-- boss(166518, "~1%",   "High Tinker Mekkatorque, Battle of Dazar'alor") -- G.M.O.D.
-- boss(166705, "~1%",   "Jaina (Mythic), Battle of Dazar'alor")      -- Glacial Tidestorm
-- boss(174872, "~1%",   "N'Zoth (Mythic), Ny'alotha")                -- Ny'alotha Allseer
-- boss(186638, "~1%",   "So'leah (Mythic), Tazavesh")                -- Cartel Master's Gearglider
-- boss(186656, "~1%",   "Sylvanas, Sanctum of Domination")           -- Sanctum Gloomcharger's Reins
-- boss(190768, "~1%",   "Anduin, Sepulcher of the First Ones")       -- Fractal Cypher of the Zereth Overseer
-- boss(210061, "~1%",   "Fyrakk, Amirdrassil")                       -- Reins of Anu'relos, Flame's Guidance
-- boss(224147, "~1%",   "Queen Ansurek, Nerub-ar Palace")            -- Reins of the Sureki Skyrazor
-- boss(236960, "~1%",   "Chrome King Gallywix, Liberation of Undermine") -- Prototype A.S.M.R.

--[===[ (Midnight, for later)
-- Possible BoEs, NOT confirmed: listed by guides from test-realm data as Bind on Equip
-- drops from The Venomous Abyss trash lieutenants. Live item data may differ (Blizzard can
-- change binding before release), so they are shown separately as "unconfirmed".
for _, id in ipairs({ 271638, 271445, 271444, 271440, 271441, 271436, 271438, 271435, 271434 }) do
    SFP.Items[id] = { kind = "boe", unconfirmed = true, drop = "rare",
        note = "trash lieutenants, The Venomous Abyss - may have been changed" }
end
]===]

-- Enchanting: disenchant BoE gear from that expansion (any zone)
for _, id in ipairs({ 52555, 52719, 52721,     -- Hypnotic Dust, Greater Celestial Essence, Heavenly Shard
                      74249, 74250, 74248,     -- Spirit Dust, Mysterious Essence, Sha Crystal
                      -- later expansions, for when the game gets them:
                      -- 109693, 113588,          -- Draenic Dust, Temporal Crystal
                      -- 124440, 124441, 124442,  -- Arkhana, Leylight Shard, Chaos Crystal
                      -- 152875, 152876, 152877,  -- Gloom Dust, Umbra Shard, Veiled Crystal
                      -- 172230, 172231, 172232,  -- Soul Dust, Sacred Shard, Eternal Crystal
                      -- 194123, 194124, 200113,  -- Chromatic Dust, Vibrant Shard, Resonant Crystal
                      -- 219946, 219949, 219952,  -- Storm Dust, Gleaming Shard, Refulgent Crystal
                    }) do
    SFP.Items[id] = { kind = "enchant" }
end


-- special materials: rare finds, profession-gated cloth, lure / beast-type drops.
-- Spots that drop them glow magenta instead of cyan.
for _, id in ipairs({ 44128, 72163,
                      -- later expansions, for when the game gets them:
                      -- 172097, 193216, 193222, 193226, 193229, 193232, 212670, 212674,
                      -- 237016, 237017, 238518, 238520, 238525, 238522, 238523, 238528, 238529, 238530,
                    }) do
    if SFP.Items[id] then SFP.Items[id].special = true end
end

SFP.KindOrder = { mount = -1, toy = -1, boe = 0, pet = 1, ore = 2, herb = 2, element = 3, leather = 4, cloth = 5, enchant = 6, meat = 7, mat = 8 }
SFP.KindLabel = { mount = "Mount", toy = "Toy", boe = "BoE", pet = "Pet", element = "Element", leather = "Skinning",
                  cloth = "Cloth", meat = "Meat", ore = "Mining", herb = "Herbalism", enchant = "Enchanting", mat = "Material" }
-- small icon per source, shown on every loot line (tooltips, browser)
SFP.KindIcon = {
    ore     = "Interface\\Icons\\Trade_Mining",
    herb    = "Interface\\Icons\\Trade_Herbalism",
    leather = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    cloth   = "Interface\\Icons\\Trade_Tailoring",
    element = "Interface\\Icons\\Trade_Alchemy",
    enchant = "Interface\\Icons\\Trade_Engraving",
    meat    = "Interface\\Icons\\INV_Misc_Food_15",
    boe     = "Interface\\Icons\\INV_Misc_Bag_10",
    mount   = "Interface\\Icons\\Ability_Mount_RidingHorse",
    pet     = "Interface\\Icons\\INV_Box_PetCarrier_01",
    toy     = "Interface\\Icons\\INV_Misc_Toy_10",
    mat     = "Interface\\Icons\\INV_Misc_Gear_01",
}
-- how each kind is obtained (drop chances for creature materials are not published)
SFP.KindHow = {
    ore = "mine the veins", herb = "pick the herbs", leather = "skin beasts", cloth = "humanoid kills",
    element = "elementals / motes", enchant = "disenchant BoE gear", meat = "beast kills",
}
SFP.DUNGEON_ICON = "Interface\\Minimap\\Dungeon"
SFP.RAID_ICON    = "Interface\\Minimap\\Raid"

function SFP:KindIconTag(kind, size)
    local t = self.KindIcon[kind]
    return t and ("|T" .. t .. ":" .. (size or 13) .. "|t") or ""
end
