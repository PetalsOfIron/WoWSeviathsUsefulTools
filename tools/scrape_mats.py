import re, json, subprocess, os, sys, time
from concurrent.futures import ThreadPoolExecutor

SP = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(SP, "matcache")
os.makedirs(CACHE, exist_ok=True)
BASE = "https://www.wowhead.com/mop-classic/"


def get(u):
    for _ in range(3):
        r = subprocess.run(['curl', '-sL', '--max-time', '60', '-A', 'Mozilla/5.0', u], capture_output=True, text=True, encoding='utf8')
        if r.stdout and len(r.stdout) > 2000:
            return r.stdout
        time.sleep(2)
    return ""


def fixkeys(txt):
    return re.sub(r'(?<=[,{\[])([A-Za-z_]\w*):', r'"\1":', txt)


def array_after(h, marker, start=0):
    i = h.find(marker, start)
    if i < 0:
        return None
    j = h.find('[', i)
    d = 0
    for k in range(j, len(h)):
        c = h[k]
        if c == '[':
            d += 1
        elif c == ']':
            d -= 1
            if d == 0:
                return h[j:k + 1]
    return None


def list_items():
    f = os.path.join(SP, "mats_all.json")
    if os.path.exists(f) and os.path.getsize(f) > 100000:
        return {int(k): v for k, v in json.load(open(f)).items()}
    tot = {}
    pages = ['', '/cloth', '/leather', '/elemental', '/parts', '/devices', '/explosives', '/materials', '/other',
             '/enchanting', '/jewelcrafting', '/herbs', '/metal-and-stone', '/inscription', '/cooking-ingredients']
    for p in pages:
        h = get(BASE + 'items/trade-goods' + p)
        arr = array_after(h, 'var listviewitems = ')
        if not arr:
            continue
        try:
            data = json.loads(fixkeys(arr))
        except Exception as e:
            print('parse fail', p, e)
            continue
        for it in data:
            if it.get('classs') == 7:
                tot[it['id']] = {'id': it['id'], 'name': it['name'], 'q': it.get('quality', 1), 'sub': it.get('subclass', 0), 'lvl': it.get('level', 0)}
        print(p or 'default', len(data), len(tot))
    json.dump(tot, open(f, 'w'))
    return tot


def rows(h, sec):
    i = h.find("id: '%s'" % sec)
    if i < 0:
        return []
    j = h.find('data: [', i)
    if j < 0:
        return []
    seg = array_after(h, 'data: [', i)
    if not seg:
        return []
    try:
        return json.loads(fixkeys(seg))
    except Exception:
        return []


def scrape(item):
    f = os.path.join(CACHE, "%d.json" % item['id'])
    if os.path.exists(f):
        return json.load(open(f))
    h = get(BASE + 'item=%d' % item['id'])
    out = {'id': item['id']}
    if not h:
        return out
    rf = rows(h, 'reagent-for')
    out['nu'] = len(rf)
    out['u'] = [[r.get('name'), (r.get('skill') or [0])[0], r.get('cat')] for r in rf[:16]]
    g = rows(h, 'gathered-from-object')
    out['g'] = sorted({r.get('name') for r in g if r.get('name')})[:6]
    d = rows(h, 'dropped-by')
    d = sorted(d, key=lambda r: -(r.get('count') or 0))
    out['d'] = [[r.get('name'), (r.get('location') or [0])[0], round(100.0 * r['count'] / r['outof'], 1) if r.get('outof') else 0] for r in d[:4]]
    s = rows(h, 'sold-by')
    out['v'] = [[r.get('name'), (r.get('location') or [0])[0], (r.get('cost') or [0])[0] if isinstance(r.get('cost'), list) else 0] for r in s[:3]]
    for sec, key in (('milling', 'mill'), ('prospecting', 'pros'), ('created-by', 'cb'), ('skinned-from', 'skin'),
                     ('pick-pocketed-from', 'pick'), ('contained-in-object', 'cio'), ('contained-in-item', 'cii'),
                     ('disenchanted-from', 'de'), ('fished-in', 'fish')):
        rr = rows(h, sec)
        if rr:
            out[key] = [r.get('name') for r in rr[:5] if r.get('name')]
            out[key + '_n'] = len(rr)
    json.dump(out, open(f, 'w'))
    return out


if __name__ == '__main__':
    items = list_items()
    print('items', len(items))
    todo = list(items.values())
    done = 0
    with ThreadPoolExecutor(max_workers=4) as ex:
        for r in ex.map(scrape, todo):
            done += 1
            if done % 100 == 0:
                print('done', done, flush=True)
    res = {}
    for it in todo:
        r = json.load(open(os.path.join(CACHE, "%d.json" % it['id'])))
        r.update({'name': it['name'], 'q': it['q'], 'sub': it['sub'], 'lvl': it['lvl']})
        res[it['id']] = r
    json.dump(res, open(os.path.join(SP, 'mats_full.json'), 'w'))
    print('finished', len(res))
