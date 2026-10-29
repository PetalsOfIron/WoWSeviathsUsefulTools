"""Copies what the addon learned while you played (monsters, drops, items, nodes, recipes, farm spots, quest giver
positions, quest monster places) from the account's SavedVariables into Data/Learned.lua, which ships with the addon.
Copy the addon folder to another account / PC and it starts with everything learned here.
Usage: python merge_learned.py ["path to WTF/Account"]   (re-run any time; nothing is lost, the file only grows)"""
import glob, os, sys
from lupa import LuaRuntime

SP = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(SP, "..", "Data", "Learned.lua")
KEYS = ["npcs", "knownItems", "objects", "recipes", "learned", "npcPos", "questSeen", "npcSpots"]
acc = sys.argv[1] if len(sys.argv) > 1 else os.path.join(SP, "..", "..", "..", "..", "WTF", "Account")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("SFP_SEED = nil; function load_sv(path) local env = {}; local f = loadfile(path, 'bt', env); if f then f() end; return env end")
merged = {k: {} for k in KEYS}


def plain(t):
    """Lua table -> python dict/list/scalars."""
    if lua.eval("function(x) return type(x) == 'table' end")(t):
        return {plain(k): plain(v) for k, v in t.items()}
    if isinstance(t, bytes):
        return t.decode("utf8", "replace")
    return t


def merge(dst, src):
    for k, v in src.items():
        if k not in dst:
            dst[k] = v
        elif isinstance(dst[k], dict) and isinstance(v, dict):
            merge(dst[k], v)
        elif isinstance(dst[k], (int, float)) and isinstance(v, (int, float)) and not isinstance(v, bool):
            dst[k] = max(dst[k], v)


# what Data/Learned.lua already holds
if os.path.exists(OUT):
    env = lua.eval("(function(path) local env = {SFP = {}}; local f = loadfile(path, 'bt', setmetatable(env, {__index = _G})); local _, SFP = nil, env.SFP; f(nil, SFP); return SFP.Seed end)")(OUT)
    if env:
        old = plain(env)
        for k in KEYS:
            if isinstance(old.get(k), dict):
                merge(merged[k], old[k])
files = glob.glob(os.path.join(acc, "*", "SavedVariables", "SeviathsUsefulTools.lua"))
for f in files:
    env = lua.eval("load_sv")(f)
    db = env.SeviathsUsefulToolsDB
    if not db:
        continue
    for k in KEYS:
        if db[k]:
            merge(merged[k], plain(db[k]))


def lit(v):
    if isinstance(v, dict):
        items = []
        for k in sorted(v, key=lambda x: (isinstance(x, str), x)):
            key = "[%d]" % k if isinstance(k, (int, float)) and k == int(k) else "[%s]" % lit(k)
            items.append(key + "=" + lit(v[k]))
        return "{" + ",".join(items) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(int(v)) if v == int(v) else ("%.6g" % v)
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\n") + '"'


lines = ["-- SeviathsUsefulTools - what the addon learned while playing (written by tools/merge_learned.py)",
         "-- Merged into a new account's saved data at first login; the account's own data always wins.",
         "local _, SFP = ...", "SFP.Seed = {"]
for k in KEYS:
    lines.append("%s=%s," % (k, lit(merged[k])))
lines.append("stamp=%d," % int(__import__("time").time()))
lines.append("}")
open(OUT, "w", encoding="utf8").write("\n".join(lines) + "\n")
print("accounts", len(files), {k: len(merged[k]) for k in KEYS}, os.path.getsize(OUT) // 1024, "KB")
