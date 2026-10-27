# SeviathsUsefulTools - status (1.19.0-mop)

Done in 1.19: Codex load error fixed (all event registrations safe), error capture (/sfp errors),
one main menu (click the minimap button, /sut), Collector (monsters by NPC ID, drops, nodes, items,
recipes, account-wide), monster/item tooltips, Questie database bridge (quests, elite/rare monsters,
item sources), rares imported onto the world map.

## To check in game next
- /reload, then /sfp errors and BugSack: send anything listed.
- Codex tabs: Dungeons, Raids, Bosses, Entrances, Mounts, Pets, Achievements should fill after the
  background indexing (status shown at the bottom of the Codex window). Quests + Monsters come from QuestieDB.
- World map: farm spots / rares in a zone (Questie rares load ~25 s after login).
- Open a profession window once per profession so recipes are learned ("Used in" on materials).

## Still to do
- Static MoP guide texts: tactics for every boss / quest chain are only what the game journal and
  Questie provide; hand-written tactics for hard bosses and mounts are not written yet.
- Quests on the minimap are drawn by Questie (installed); this addon does not duplicate that.
- Snake minimap skin skipped on request (design notes are in memory: useful-tools-addon).

## Next session: missing quest positions (Wowhead scrape)
- Run: cd tools; python scrape_questdata.py (resumable, 3 s per request, stops on 403/429), then python export_questdata.py, /reload, commit + push.
- qcache has 1777 of about 1700 pages when this was written; Data/QD_Extra.lua is the exported part.
- Still open: head marks / hover use quest-text names for quests with no monster data; quest areas need the scraped spawns.
