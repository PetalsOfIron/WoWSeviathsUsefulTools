"""Polite, single-threaded, resumable fetch of the positions the quest database lacks (Wowhead, Mists of Pandaria).
qworklist.json lists monsters / objects without spawn points and quest items without a known source.
One request every 3 seconds; stops at the first 403/429 instead of retrying. Results go to qcache/."""
import json, os, re, subprocess, sys, time

SP = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SP)
import scrape_mats as sm

CACHE = os.path.join(SP, "qcache")
os.makedirs(CACHE, exist_ok=True)
BASE = "https://www.wowhead.com/mop-classic/"
DELAY = 3.0
blocked = False


def polite_get(u):
    global blocked
    time.sleep(DELAY)
    r = subprocess.run(['curl', '-sL', '--max-time', '60', '-A', 'Mozilla/5.0', '-w', '\n%{http_code}', u],
                       capture_output=True, text=True, encoding='utf8')
    body, _, code = r.stdout.rpartition('\n')
    if code in ('403', '429'):
        blocked = True
        return None
    return body if len(body) > 2000 else ''


def mapper(h):
    i = h.find('g_mapperData = ')
    if i < 0:
        return {}
    j = i + len('g_mapperData = ')
    d = 0
    for k in range(j, len(h)):
        if h[k] == '{':
            d += 1
        elif h[k] == '}':
            d -= 1
            if d == 0:
                try:
                    return json.loads(h[j:k + 1])
                except Exception:
                    return {}
    return {}


def fetch(kind, id):
    f = os.path.join(CACHE, "%s%d.json" % (kind, id))
    if os.path.exists(f):
        return json.load(open(f))
    h = polite_get(BASE + "%s=%d" % ({"n": "npc", "o": "object", "i": "item"}[kind], id))
    if h is None:
        return None
    out = {"id": id}
    if h:
        t = re.search(r"<title>([^<]*?)(?: - [^<]*)?</title>", h)
        out["name"] = t.group(1).strip() if t else ""
        if kind in "no":
            sp = {}
            for k, vs in mapper(h).items():
                if isinstance(vs, dict):
                    vs = [vs]
                if not isinstance(vs, list):
                    continue
                sp[k] = [c for v in vs if isinstance(v, dict) for c in v.get("coords", [])][:60]
            out["spawns"] = sp
        else:
            d = sorted(sm.rows(h, 'dropped-by'), key=lambda r: -(r.get('count') or 0))
            out["npcs"] = [[r.get('id'), r.get('name')] for r in d[:8] if r.get('id')]
            g = sm.rows(h, 'contained-in-object') + sm.rows(h, 'gathered-from-object')
            out["objs"] = [[r.get('id'), r.get('name')] for r in g[:4] if r.get('id')]
    json.dump(out, open(f, "w"))
    return out


work = json.load(open(os.path.join(SP, "qworklist.json")))
n = 0
for kind, ids in (("n", work["npcs"]), ("o", work["objs"]), ("i", work["items"])):
    for id in ids:
        if blocked:
            break
        fetch(kind, id)
        n += 1
        if n % 50 == 0:
            print(kind, n, flush=True)
# monsters and objects that drop the quest items
extra = set()
for id in work["items"]:
    f = os.path.join(CACHE, "i%d.json" % id)
    if os.path.exists(f):
        r = json.load(open(f))
        extra.update(("n", x[0]) for x in r.get("npcs", []))
        extra.update(("o", x[0]) for x in r.get("objs", []))
for kind, id in sorted(extra):
    if blocked:
        break
    fetch(kind, id)
    n += 1
    if n % 50 == 0:
        print("drop", n, flush=True)
print("finished" if not blocked else "BLOCKED - stopped", flush=True)
