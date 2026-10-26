# tools

Scripts that build Data/Materials.lua and Data/Mounts.lua.

1. build_db2.py - reads the game's data tables (CSV from wago.tools, build 5.5.4.70579) into mats_db2.json / mounts_db2.json
2. scrape_slow.py - fetches Wowhead item pages for sources. ONE request every 3 s, single thread, resumable
   (matcache/, mountcache/). Wowhead blocks faster use (403) - never run it with more threads.
3. gen_data.py - writes the two Lua data files from the JSON and the caches (edit OUT to your AddOns path)
