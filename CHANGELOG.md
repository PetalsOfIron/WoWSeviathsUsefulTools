# SeviathsUsefulTools changelog (formerly SeviathsFarmPack)

## 1.34.0-mop
- Hover a plant, ore vein or animal: what one gather / skin / kill is worth at auction prices, and whether a better one is worth grinding instead (compared with the ones you have gathered)
- Hover a crafted item: materials cost against the selling price (5% cut) = gain or loss; /sfp craft lists your most profitable recipes
- The auction scan now also covers gathering drops and recipe materials

## 1.33.0-mop
- Chat message (yellow) with the gold you take from the mailbox and the gold you get from selling to a vendor; /sfp income switches it off and on

## 1.32.0-mop
- Auction House: a yellow chat message when one of your auctions sells (and what the buyer paid when you open the mail); /sfp sold switches it off and on

## 1.31.0-mop
- Removed the broken quest parts: map, minimap and zone markers, our tracker and quest log window (Blizzard's are used). Kept: quest objectives in the monster tooltip, quest marks over the heads of monsters and NPCs (from the Questie database), and everything that is not about quests

## 1.30.1-mop
- Positions for the quest givers and hand-in NPCs the database had no position for

## 1.30.0-mop
- /sfp questcompare: checks your finished quests and quest log against the quest data (missing quests, different levels or names)

## 1.29.1-mop
- Level up: quests unlock right away (the new level comes from the level-up event) and the chat lists the quests of the zone that the new level opened

## 1.29.0-mop
- Data/Learned.lua: tools/merge_learned.py copies everything learned (monsters, drops, items, nodes, recipes, farm spots, quest giver positions) from the saved data into the addon folder; a copy of the addon on another account / PC starts with all of it

## 1.28.1-mop
- Quest givers / hand-in NPCs: the spot where you really talked to them is remembered (account-wide) and replaces the database position, so marks end up exactly on the NPC

## 1.28.0-mop
- Quest availability now follows Questie's IsDoable: reputation limits, required spells, parent quests, breadcrumbs, disabling quests, "available starting with", exclusive pre-quests (new data fields)

## 1.27.9-mop
- Quests you can pick up show on the map and minimap again (Blizzard's tracker and quest log stay)

## 1.27.8-mop
- Back to Blizzard's own quest tracker, quest log and "!" marks for quests you can pick up (our tracker / log / available marks are off by default; they can be switched on in the menu). Kept: quest areas, quest monster marks, turn-in marks

## 1.27.7-mop
- Pet battle quests are hidden until pet battles are unlocked for the character

## 1.27.6-mop
- Quests you already finished no longer show as available on the minimap / map: the game is asked directly, and a quest is hidden when a later quest of its chain is taken or done

## 1.27.5-mop
- Quest data refresh waits while a quest giver window is open (so it can never get in the way of accepting a quest)

## 1.27.4-mop
- NPC tooltip "Starts:" lists only quests you can take now (not taken, not done, level and requirements fit)

## 1.27.3-mop
- The addon no longer forces friendly NPC nameplates (they could hide the game's own "!" over quest givers; set back to default once) and no longer draws its own "!" over quest givers

## 1.27.2-mop
- Tracker: the quest item you have to use gets its button next to the quest (click to use, tooltip, stack count)
- Profession / skill quests are only shown when you have the skill

## 1.27.1-mop
- Scrape finished: positions for 460 monsters, 47 objects and the sources of 279 quest items; Demoniac Vessel parts now come from the Tainted bears, nightstalkers and screechers

## 1.27.0-mop
- Positions the quest database lacks (monsters, objects, drop sources of quest items) are fetched from Wowhead into Data/QD_Extra.lua (tools/scrape_questdata.py + export_questdata.py); first batch included

## 1.26.10-mop
- Enemy nameplates are switched on once when quest head marks are on (they were off, so no mark could be shown)

## 1.26.9-mop
- Head marks look up nameplates by unit token; /sfp plates shows the enemy nameplate setting

## 1.26.8-mop
- Quest monsters get the yellow "!" over their heads (bigger)

## 1.26.7-mop
- Quests with an unknown objective spot: no more false "turn in" marker; the places where you met the quest monsters are remembered and marked on the map
- /sfp plates: shows what the head marks see

## 1.26.6-mop
- Head marks sit above the health bar of the nameplate, on a higher layer, ignoring plate alpha

## 1.26.5-mop
- Fix: random monsters from the name search hid the quest-text matching, so quest monsters got no head mark or tooltip line

## 1.26.4-mop
- Head marks and tooltip line for monsters named in the quest text, even when the monster is not in the database

## 1.26.3-mop
- Fix error on the minimap quest areas

## 1.26.2-mop
- Fix error in quest sets (monster names from quest text)

## 1.26.1-mop
- Quests whose collect item has no known source now mark the monsters named in the quest text (e.g. Tainted Black Bears for Demoniac Vessel): head marks, tooltip line, map areas

## 1.26.0-mop
- Quests without a known kill / collect position (item objectives with no source, exploration and special
  objectives) now show an area: the exploration areas and special objective areas of the database were
  added, and when nothing is known the area around the quest giver / hand-in NPC is marked
- Tracker: every quest line is clickable (click: quest log, Ctrl-click: pin + map, Shift-click: hide)

## 1.25.2-mop
- Kill / collect targets of your quests are drawn as translucent quest areas like the retail map (no skull icons); on the minimap they form areas too

## 1.25.1-mop
- Quest icons on the map and minimap are smaller (/sfp questscale 0.7, 0.3 to 2)

## 1.25.0-mop
- Quests you can still pick up show again on the zone map, minimap and over their givers, with Blizzard's own yellow "!" icon (no custom marker); low-level ones are greyed

## 1.24.5-mop
- Fixed an error when the world map switched to a continent view (a helper was used before it was defined)

## 1.24.4-mop
- Quests hidden under a collapsed zone header of the game's quest log are found now (the log expands the headers once)

## 1.24.3-mop
- Clicking a quest's pin button (tracker or quest log) pins it and opens the map at the exact place

## 1.24.2-mop
- The quest log window refreshes when it opens and shows the game's own quest count next to ours, so a missing quest is visible

## 1.24.1-mop
- "Report to ..." quests (nothing to kill or collect) get their marker, pin and zone tint at the NPC you have to talk to; "Pin on map" now finds them

## 1.24.0-mop
- Fully self-contained: the quest, monster, object and item data of Mists of Pandaria is now part of this
  addon (Data/QD_*.lua, about 7 MB, generated from the QuestieDB database, GPL-3.0). Neither Questie nor
  QuestieDB has to be installed or enabled

## 1.23.2-mop
- Works without the Questie addon: only the QuestieDB data addon is needed (zone tables are read from it); a chat line says so when it is missing or disabled

## 1.23.1-mop
- Continent and world maps: one icon in every zone that holds quest work (skull = kill / collect, cyan ? = hand in) with the quest names on hover, click opens the zone

## 1.23.0-mop
- Quest tracker and quest log replaced: a movable tracker (drag its title, Ctrl+mouse wheel resizes)
  with objectives and a map pin button per quest, and a quest log window (/sfp log, the L key) with
  zones, objectives, "Pin on map", waypoint, track / untrack, abandon, and a link to the Codex guide

## 1.22.0-mop
- Quest icons over monster heads (nameplates): gold "!" for monsters / NPCs that give a quest you can take,
  cyan "?" for the ones you hand a finished quest in to, a skull for monsters you have to kill
- Continent and world maps tint every zone that holds your quest work, transparently (orange: kill / collect
  zones, cyan: turn-in zones), so you can see through it
- Settings: "Quest icons over monster heads", "Tint zones that hold my quests"

## 1.21.2-mop
- Quests of your log that the database cannot place on a map (cross-zone turn-ins, missing spawns) are placed with the game's own quest position; /sfp questdebug explains what the markers see

## 1.21.1-mop
- Quest markers show only for quests you have picked up (kill / collect targets and turn-in) in their zone; the gold "!" for quests you could still pick up is off by default (Settings: "Show quests I can pick up")

## 1.21.0-mop
- Quest markers: the addon now draws quests itself (data: QuestieDB) with its own design - gold "!"
  for quests you can pick up (level, race, class, prerequisites checked), cyan "?" to turn in, skull /
  diamond / square for kill / collect / use targets of your open quests - on the zone map and on the
  minimap. Hover for details, Ctrl-click for a waypoint. Monster tooltips list the quests they belong to.
  Questie's own map icons are switched off once so nothing is drawn twice (/sfp quests, /sfp questie)

## 1.20.4-mop
- Fixed ADDON_ACTION_FORBIDDEN when right-clicking bag items: the addon no longer writes to the game's C_Item table when it already exists

## 1.20.3-mop
- Monster tooltips: every monster shows its NPC ID, drops (learned, farm data, database) or a hint; works with all tooltip hooks; /sfp tipdebug explains when nothing shows

## 1.20.2-mop
- Mount pages: "Show on map" pins the vendor, boss, quest giver or instance entrance

## 1.20.1-mop
- Spots show only on zone maps (close view); the continent and world view stays clean (setting "Also on continent maps")

## 1.20.0-mop
- Spots: exact markers for every spawn point (setting "Exact spot markers"); the same spots on the
  minimap through HereBeDragons (works with Leatrix, BasicMinimap, Questie)
- Questie: its minimap icons and objectives were switched off by the Blizzard icon theme; the addon
  switches them on once (/sfp questie does it again, also a button in Settings)
- Codex: every monster, quest starter, dungeon and raid has a "Show on map" pin; dungeon entrances
  come from Questie's database when the Adventure Guide has none
- Materials: all 1,242 crafting materials of the game with what they are used for (recipes from the
  game's data tables, build 5.5.4.70579) and where to get them (Wowhead Mists of Pandaria Classic)
- Mounts: all 527 mounts with the teaching item; numbered "how to get it" steps (instance entrance,
  boss and drop chance, vendor and cost, quest, achievement, container, crafting)
- Item scanner: the addon slowly asks the game about every item ID in the background and keeps every
  tradeskill material it finds (/sfp scanitems)
- Fixed the main menu close button

## 1.19.0-mop
- Fixed: the Codex stayed empty because an unknown event (QUEST_DATA_LOAD_RESULT) stopped its
  indexer file from loading; all event registrations are now safe. Errors anywhere in the addon are
  caught, shown once through the normal error handler and listed with /sfp errors
- One main menu (/sut, /sfp, left or right click on the minimap button) with Home, Farm & Map,
  Guides (Codex), Groups, Guild, Learned data, Settings
- Collector: learns monsters (by NPC ID, names are never overwritten), what they drop (green items
  too), skinning, gathering nodes, every item you loot, and the recipes of the professions you open.
  Saved account-wide, so new characters start with it. Materials you loot join the farm list
- Tooltips: monsters show what they drop; items show vendor junk / crafting material (what it is used
  for and what it makes) / gear (compared with what you wear); Briarthorn and Mageroyal list
  Swiftthistle, the Northrend herbs list Deadnettle
- Questie database bridge (QuestieDB): every quest with how to do it, every elite / rare monster, who
  drops or sells an item; rares from the database appear as orange spots on the world map

## 1.18.0-mop
- Renamed to SeviathsUsefulTools (the folder is now AddOns/SeviathsUsefulTools; /sfp, /farmpack and the new /sut all work)
- Everything in one addon: Seviath's Codex, Seviath's Dungeons & Raids and Seviath's Guild Helper
  are now part of the Farm Pack (Modules/ folder). One minimap button: left-click the farm browser,
  right-click a menu with the Codex, Dungeons & Raids, Guild Helper and the map overlay switch.
  /sfp codex, /sfp groups and /sfp guild open them too (/codex, /sdr and /gi still work)
- Codex: guide rewritten for Mists of Pandaria (no delves, Great Vault, Warband, housing...), gold
  farms for Pandaria, Draenor monsters commented out, the Farm Pack's rares and world bosses now
  appear in the Codex with map pins
- Dungeons & Raids: Mists raid buffs (Stats, Stamina, Attack Power, Spell Power, Haste, Crit,
  Mastery), Conqueror / Protector / Vanquisher tokens, Mists classes, battle res and Bloodlust
- Guild Helper: Mists classes only, falls back to old APIs where the new ones are missing
- Old features that don't exist in Mists (delves, transmog sets window, Mythic+) are left out

## 1.17.0-mop
- Mists of Pandaria Classic edition (Interface 50504): data for Warlords of Draenor and newer is
  commented out (look for "NEWER EXPANSIONS" in Data/*.lua and Core.lua) so it can be enabled later
- Added Classic Zul'Gurub raid mounts (Swift Razzashi Raptor, Swift Zulian Tiger) and the MoP world
  boss mounts (Galleon, Oondasta, Nalak, Sha of Anger) with spawn spots
- Corrected the Sorrowmoss herb name to Plaguebloom (item 13466)
- Gathering list now also shows Swiftthistle, Deadnettle, Ancient Lichen and Dark Iron Ore with a "how to get it" tooltip (bonus loot / dungeon nodes / golem drops, rates from Wowhead)
- From Seviath's Codex: farm notes for the old-raid mount runs (Karazhan, Tempest Keep, Ulduar, Icecrown, Stratholme, Utgarde Pinnacle, Magisters' Terrace) and the farm dungeons Blackrock Depths, Maraudon, Uldaman and Razorfen Kraul
- Added herbs missing from the gathering data: Stranglekelp, Wintersbite, Arthas' Tears, Firethorn, Sha-Touched Herb

## 1.17.0
- The War Within rares: all repeatable rares of Isle of Dorn, The Ringing Deeps, Hallowfall,
  Azj-Kahet (and City of Threads), Undermine and Siren Isle - 96 more rares with spawn tips
  (Keyflame rares, Croakit, Deathtide, Parasidious, Trungal, cartel event rares, Siren Isle
  invasion and excavation rares)
- Beledar's Spawn (Hallowfall) with all its spawn points and the Beledar's Spawn mount (~5-6%)
- Tka'ktath (Azj-Kahet) with the Siesbarg mount quest chain

## 1.16.0
- Farm spots learned from your own loot: when you loot cloth, leather, elements, meat, special
  materials or any Bind on Equip item from a mob in the open world, the addon remembers the mob and
  where you were. After 3 kills it becomes a farm spot on the map - in every zone, including Midnight
  zones and future patches. The tooltip shows drop rates measured from your own kills
- New map layer switch "Learn from my loot"; /sfp learn turns it on/off, /sfp learn reset clears it

## 1.15.1
- The Venomous Abyss: 9 possible BoE drops from its trash lieutenants, listed greyed out at the
  bottom of the raid tooltip as "unconfirmed, may have been changed" (guide data from the test realm)
- March on Quel'Danas: note about the Myth-track BoEs from trash at the start of the raid
- New map layer switch "Unconfirmed BoEs" to hide those

## 1.15.0
- Midnight rares: all 59 rares of Eversong Woods, Zul'Aman, Harandar and Voidstorm, each marked with
  the gold star and listing its zone's two mounts (Cerulean Hawkstrider / Cobalt Dragonhawk, Amani
  Sharptalon / Escaped Witherbark Pango, Rootstalker Grimlynx / Vibrant Petalwing, Augmented Stormray /
  Sanguine Harrower), plus spawn tips (patrols, caves, how to spawn Waverly and Queen o' War)
- The Coiled Isle: all 12 rares with the Ruby Writhe and Topaz Skyfang mounts and how to reach the
  tricky ones (Farthik, Nar'zira, Szarith)

## 1.14.1
- Fixed: new Midnight zones on the old continents (like The Coiled Isle) were treated as Classic
  zones, so the gathering list said they had no nodes. They now list the Midnight ores and herbs
- Zones without node data now say "No node data for this zone in the addon yet" instead of
  claiming there are no nodes

## 1.14.0
- The gathering list now shows only the ores and herbs that really spawn in the zone you are
  looking at, most common first, with the number of recorded nodes and the best zone for each
  (from Wowhead's per-zone node data). Classic to Battle for Azeroth fully covered; Shadowlands,
  Dragonflight and The War Within materials show in their best zone for now
- The list header shows the zone name; zones without nodes say so

## 1.13.1
- Classic dungeons and raids: Temple of Ahn'Qiraj added with the Blue, Green, Yellow and Red Qiraji
  Resonating Crystal mounts (trash drops, so the Adventure Guide doesn't list them). All other Classic
  dungeons and raids (Deadmines, Wailing Caverns, Shadowfang Keep, Zul'Farrak, Uldaman, Maraudon,
  Sunken Temple, Ruins of Ahn'Qiraj...) show their sellable BoE drops from the Adventure Guide
- The gathering list now shows on every zone map, also zones with no farm spots (all Classic zones)

## 1.13.0
- Every dungeon and raid of every expansion, Classic to Midnight, is now read from the game's
  Adventure Guide (once per patch, in the background): all mounts on every difficulty and all
  sellable Bind on Equip items, with the entrance placed on the map automatically
- Midnight dungeons and raids added, with Lucent Hawkstrider (Magisters' Terrace, Mythic),
  Spectral Hawkstrider (Windrunner Spire, Mythic) and Ashes of Belo'ren (March on Quel'Danas, Mythic)
- Instances that drop nothing sellable (only soulbound gear) stay hidden

## 1.12.2
- Rares worth killing are marked again: a gold star sits on their marker on the map, always visible
  (it was only in the map text, which is now hover-only). BoE farm spots worth grinding get the star too
- Hunter tames show the hunter crest on their marker

## 1.12.1
- Fixed: dungeons/raids showing "Reading loot from the Adventure Guide" with nothing listed.
  The Adventure Guide is now loaded before it is read, every difficulty is read (heroic/mythic and
  10/25-player mounts), and items still loading from the server are retried
- Every dungeon and raid now has verified mounts built in, Classic to The War Within: Deathcharger,
  Onyxian Drake, Fiery Warhorse, Ashes of Al'ar, Swift White Hawkstrider, Raven Lord, Blue Proto-Drake,
  Azure / Blue / Black / Twilight Drake, Grand Black War Mammoth, Mimiron's Head, Invincible
- Instances with nothing to list are hidden from the map and the farm browser

## 1.12.0
- Dungeons and raids now list every mount and every sellable Bind on Equip item they drop, for all
  expansions. The loot is read from the game's Adventure Guide in the background after login (once
  per patch), so it always matches the current game; the boss is shown for each item
- BoE gear is added to the auction house price scan, so the tooltips show what it sells for
- Dungeon/raid tooltip is grouped: Mounts, BoE gear (best price first), Materials
- New instances for their mounts: Onyxia's Lair, Sethekk Halls, Tempest Keep, Magisters' Terrace,
  The Obsidian Sanctum, The Eye of Eternity, The Oculus, Utgarde Pinnacle, Vault of Archavon
- /sfp loot re-reads the Adventure Guide (trash-only BoEs are not in the guide, so they are not listed)

## 1.11.0
- No text written on the world map anymore: names, coordinates, "Best spot" and tags show only
  when you hover a marker. The "Labels" switch in the map layer panel brings the text back

## 1.10.0
- Much cleaner map: no more piles of circles. Farm spots, rares, special materials and hunter tames
  now show one small marker per area; mobs whose areas overlap share a marker and its tooltip lists
  all of them with their drops ("+2 more" on the label)
- Mining and herbalism use small pick / flower symbols instead of glows: a few per zone, each one
  lists every ore and herb that spawns around it
- Mining and herbalism now cover Classic, The Burning Crusade and Wrath of the Lich King too
  (54 more ores and herbs, each in its best zone) - all expansions are now included

## 1.9.0
- Ores and herbs are no longer listed inside creature spot tooltips
- New gathering list at the bottom-right of every zone map: that expansion's ores and herbs, each
  with its best zone ("best zone: here" in green when you are looking at it). Click a row to open
  the best zone; click the header to collapse. Midnight included (herbs: Harandar, ores: every zone)
- Special materials get their own magenta circles and a [Special] tag: Majestic lure beasts,
  Sunfire Silk / Arcanoweave delves, rare hides (Heavy Callous Hide and others)
- New map layer switches: "Special materials" and "Gathering list"

## 1.8.0
- Layer button on the world map (top-left corner): a panel to turn each layer on or off separately -
  farm spots, rares, hunter tames, mining, herbalism, dungeons, raids, labels, whole-zone glow,
  plus All / None. Right-click the button to hide or show everything
- Mining and herbalism, and dungeons and raids, are now separate options (also in the farm browser)
- /sfp mapbutton hides or shows the map button

## 1.7.0
- Mining and herbalism: the single best zone for every ore and herb from Cataclysm to The War Within
  (69 materials), picked by the most recorded nodes on Wowhead. The node area glows (ore = amber,
  herb = mint) with a "Best zone" label; Midnight ores/herbs are listed per zone (Harandar for herbs)
- Dungeons and raids worth farming, Cataclysm to The War Within: 33 mounts with drop chances
  (Stonecore, Vortex Pinnacle, Zul'Gurub, Firelands, Dragon Soul, Throne of Thunder, Karazhan,
  Nighthold, Antorus, Freehold, Underrot, Mechagon, Ny'alotha, Sanctum, Sepulcher, Amirdrassil,
  Nerub-ar Palace, Undermine and more). Entrance icons on the map, loot on hover
- Every loot line now has a small source icon: mining, herbalism, skinning, cloth, elements,
  enchanting, cooking, BoE, mount, pet, toy
- "Best spot for ..." - each creature material is marked on the mob with the most spawns
- Enchanting materials (dust, essence, shards, crystals) for every expansion
- New options "Mining & herbs" and "Dungeon/raid icons", /sfp gather and /sfp dungeons

## 1.6.0
- Hunter tames: 21 spirit beasts and unique-looking pets, shown with the hunter crest in
  hunter green (separate from the orange rares) and tagged [Hunter]
- Their tooltip says what they are (spirit beast = Beast Mastery only, or unique pet = any hunter)
  and how to tame them: phasing quests, armor removal, kiting, hidden spawns, quest chains
- New tames: Ban'thalos, Ankha, Magria (Hyjal), Karoma, Ghostcrawler, Lightning Paw, Lost Spectral
  Gryphon (Stormwind), Gon (Orgrimmar), Pogeyan, Spirit of Atha, Degu, Gumi, Hutia, Gara,
  Bulvinkel, Myonix, Pashya
- Rares now have short descriptions and spawn tactics in their tooltip
- "Hunter tames" option and /sfp hunter

## 1.5.1
- Rare tooltips now list what the rare drops (mounts, pets, toys) plus everything else
  farmable in the zone with AH prices, the same as farm spots
- Gold star symbol marks rares and BoE spots that are worth grinding (map, tooltip, browser)
- Rares also show their pet and toy drops

## 1.5.0
- New expansions: The War Within (7 zones) and Midnight (4 zones) with cloth, leather,
  scales, hides and Renowned Beast reagents
- Rare spawns: 75 rares that drop mounts (plus Wrath hunter spirit beasts) shown as
  orange glowing spots tagged [Rare] / [Mount], with coordinates - from Wrath to The War Within
- New farm spots: Weavercloth nerubians and Stormcharged Leather packs (Isle of Dorn, Hallowfall),
  Midnight scale mobs (Eversong), cloth delves (Harandar, Voidstorm), Renowned Beast lures
- Rare-only zones added where needed (Arathi and Darkshore warfronts, Timeless Isle)
- "Rare spots" option and /sfp rares

## 1.4.2
- Every farm zone now shows a line for random green & blue BoE gear (any mob, with the zone's level range)

## 1.4.1
- BoE gear and recipes added, with drop chances: Formula: Enchant Weapon - Crusader, Nightblade,
  Glowing Brightwood Staff, Skullflame Shield, Teebu's Blazing Longsword, The Night Blade,
  Snobold Ripper, Void Bound Knife, The Glazer, Varruth's Guillotine
- BoE farm spots on the map, tagged [BoE]: Scarlet Archmage (Eastern Plaguelands), Flowing Honey
  (Stormsong Valley), Mawsworn Striker + Fettered Warden (Zereth Mortis), Onslaught Footman
  (Dragonblight), Dawnblade Summoner (Isle of Quel'Danas - new farm zone)
- 138 farm mobs in 64 zones, 169 items

## 1.4.0 - first public release
- About page in Esc > Options > AddOns > SeviathsFarmPack (version, features, commands)
- Addon Compartment entry (left-click: farm browser, right-click: about)
- Version shown in the farm browser, minimap tooltip and `/sfp version`
- Farm spot tooltips list the mob's own drops plus everything else farmable in that zone

## 1.3.1
- Farm spots now draw above the zone's explored-area art and other map addons
- Spots no longer catch mouse clicks - clicking the map opens zones as normal
- Zooming into a continent map shows the full spawn areas with labels
- Waypoints use Blizzard's Ctrl+Click

## 1.3.0
- Exact farm spots glow as small cyan areas instead of whole zones
- Info shows only when hovering a spot; whole-zone glow and item panel are optional
- 132 farm mobs in 61 zones

## 1.2.0
- Monster spawn points from Wowhead with name + coordinate labels

## 1.1.0
- Dragonflight added; item data checked against Wowhead; Wowhead links on items
