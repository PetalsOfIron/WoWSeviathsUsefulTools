"""Writes Data/QD_Extra.lua from the qcache/ files of scrape_questdata.py."""
import glob, json, os

SP = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(SP, "..", "Data", "QD_Extra.lua")


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")


def spawn_str(sp):
    parts = []
    for area, pts in sp.items():
        if not area.isdigit() or not pts:
            continue
        parts.append(area + ":" + ",".join("%g,%g" % (p[0], p[1]) for p in pts))
    return ";".join(parts)


xn, xo, xi = {}, {}, {}
for f in sorted(glob.glob(os.path.join(SP, "qcache", "*.json"))):
    r = json.load(open(f))
    k = os.path.basename(f)[0]
    if k in "no":
        s = spawn_str(r.get("spawns") or {})
        if s:
            (xn if k == "n" else xo)[r["id"]] = r.get("name", "") + "\031" + s
    elif k == "i":
        n = ",".join(str(x[0]) for x in r.get("npcs", []))
        o = ",".join(str(x[0]) for x in r.get("objs", []))
        if n or o:
            xi[r["id"]] = n + "|" + o
lines = ["-- SeviathsUsefulTools - positions the quest database lacks (Wowhead, Mists of Pandaria data)",
         "local _, SFP = ...", "SFP.QD = SFP.QD or {}"]
for name, d in (("xn", xn), ("xo", xo), ("xi", xi)):
    lines.append("SFP.QD.%s = {" % name)
    for i in sorted(d):
        lines.append('[%d]="%s",' % (i, esc(d[i]).replace("\\031", "\031")))
    lines.append("}")
open(OUT, "w", encoding="utf8").write("\n".join(lines) + "\n")
print("npcs", len(xn), "objects", len(xo), "items", len(xi))
