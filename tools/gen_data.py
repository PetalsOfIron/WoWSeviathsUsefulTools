import json, os, sys

SP = os.path.dirname(os.path.abspath(__file__))
OUT = r"D:/wow/World of Warcraft/_classic_/Interface/AddOns/SeviathsUsefulTools/Data/"


def lua(v):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        s = v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")
        return '"' + s + '"'
    if isinstance(v, (list, tuple)):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            if x is None:
                continue
            key = k if isinstance(k, str) and k.isidentifier() else "[" + lua(k) + "]"
            parts.append(key + "=" + lua(x))
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(v))


def load_cache(d, key):
    f = os.path.join(SP, d, "%s.json" % key)
    if os.path.exists(f):
        try:
            return json.load(open(f))
        except Exception:
            return None
    return None


# ---------------- materials
mats = json.load(open(os.path.join(SP, "mats_db2.json")))
lines = ["-- SeviathsUsefulTools - every crafting material of Classic to Mists of Pandaria",
         "-- Items, types and recipes come from the game's own data tables (build 5.5.4.70579, wago.tools);",
         "-- sources (nodes, drops, vendors) from Wowhead's Mists of Pandaria Classic item pages.",
         "-- n name, q quality, s type, l item level, nu recipes, u {recipe, profession skill},",
         "-- g nodes, d {npc, zone, %}, v {vendor, zone, copper}, skin pick cb cio cii de fish mill pros = names",
         "local _, SFP = ...", "", "SFP.MaterialData = {"]
withsrc = 0
for k in sorted(mats, key=int):
    m = dict(mats[k])
    c = load_cache("matcache", k)
    if c and ("g" in c or "d" in c or "v" in c):
        withsrc += 1
        for a in ("g", "skin", "pick", "cb", "cio", "cii", "de", "fish", "mill", "pros"):
            if c.get(a):
                m[a] = c[a][:5]
        if c.get("d"):
            m["d"] = c["d"][:4]
        if c.get("v"):
            m["v"] = c["v"][:3]
        m["f"] = 1
    lines.append("  [%s]=%s," % (k, lua(m)))
lines.append("}")
open(OUT + "Materials.lua", "w", encoding="utf8", newline="\n").write("\n".join(lines) + "\n")
print("materials", len(mats), "with sources", withsrc)

# ---------------- mounts
mounts = json.load(open(os.path.join(SP, "mounts_db2.json")))
lines = ["-- SeviathsUsefulTools - every mount of Classic to Mists of Pandaria and how to get it",
         "-- Mounts and teaching items come from the game's data tables (build 5.5.4.70579, wago.tools);",
         "-- sources from Wowhead's Mists of Pandaria Classic item pages (f=1 when read).",
         "local _, SFP = ...", "", "SFP.MountData = {"]
fetched = 0
for mid in sorted(mounts, key=int):
    v = mounts[mid]
    e = {"item": v["item"], "name": v["name"], "mid": int(mid)}
    c = load_cache("mountcache", v["spell"]) if v["item"] else None
    if c and ("d" in c or "v" in c or "source" in c):
        fetched += 1
        e["f"] = 1
        for a in ("source", "sourcemore", "reqlevel", "tip", "d", "dn", "v", "q", "cio", "cii", "cb", "cf", "pick", "fish"):
            if c.get(a) is not None and c.get(a) != []:
                e[a] = c[a]
    lines.append("  [%d]=%s," % (v["spell"], lua(e)))
lines.append("}")
open(OUT + "Mounts.lua", "w", encoding="utf8", newline="\n").write("\n".join(lines) + "\n")
print("mounts", len(mounts), "with sources", fetched)
