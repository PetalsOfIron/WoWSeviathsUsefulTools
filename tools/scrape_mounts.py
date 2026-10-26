import re, json, os, sys, html
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scrape_mats import get, array_after, fixkeys, rows, SP

CACHE = os.path.join(SP, "mountcache")
os.makedirs(CACHE, exist_ok=True)
BASE = "https://www.wowhead.com/mop-classic/"


def tooltip_lines(h, item_id):
    m = re.search(r'g_items\[%d\]\.tooltip_enus = "(.*?)";\s*\n' % item_id, h, re.S)
    if not m:
        return []
    t = m.group(1).encode().decode('unicode_escape', errors='ignore')
    t = re.sub(r'<br ?/?>|</tr>|</td>|</div>|<tr>', '\n', t)
    t = re.sub(r'<[^>]+>', '', t)
    t = html.unescape(t)
    return [l.strip() for l in t.split('\n') if l.strip()][:14]


def scrape(m):
    spell, name, item = m['id'], m['name'], m.get('item')
    f = os.path.join(CACHE, "%d.json" % spell)
    if os.path.exists(f):
        return json.load(open(f))
    out = {'spell': spell, 'name': name, 'item': item}
    if not item:
        json.dump(out, open(f, 'w'))
        return out
    h = get(BASE + 'item=%d' % item)
    if not h:
        return out
    mm = re.search(r'\$\.extend\(g_items\[%d\], (\{.*?\})\);' % item, h, re.S)
    if mm:
        try:
            jd = json.loads(fixkeys(mm.group(1)))
            out['source'] = jd.get('source')
            out['sourcemore'] = jd.get('sourcemore')
            out['reqlevel'] = jd.get('reqlevel')
        except Exception:
            pass
    out['tip'] = tooltip_lines(h, item)
    d = sorted(rows(h, 'dropped-by'), key=lambda r: -(r.get('count') or 0))
    out['d'] = [[r.get('name'), r.get('id'), (r.get('location') or [0])[0],
                 round(100.0 * r['count'] / r['outof'], 2) if r.get('outof') else 0] for r in d[:5]]
    out['dn'] = len(d)
    s = rows(h, 'sold-by')
    out['v'] = [[r.get('name'), r.get('id'), (r.get('location') or [0])[0], r.get('cost')] for r in s[:4]]
    for sec, key in (('reward-from-q', 'q'), ('contained-in-object', 'cio'), ('contained-in-item', 'cii'),
                     ('created-by', 'cb'), ('currency-for', 'cf'), ('pick-pocketed-from', 'pick'), ('fished-in', 'fish')):
        rr = rows(h, sec)
        if rr:
            out[key] = [[r.get('name'), r.get('id'), (r.get('location') or [0])[0] if isinstance(r.get('location'), list) and r.get('location') else 0] for r in rr[:4]]
    json.dump(out, open(f, 'w'))
    return out


if __name__ == '__main__':
    data = json.load(open(os.path.join(SP, 'mounts_list.json')))
    mounts = []
    for d in data:
        item = None
        for rg in (d.get('reagents') or []):
            item = rg[0]
            break
        mounts.append({'id': d['id'], 'name': d['name'], 'item': item})
    done = 0
    with ThreadPoolExecutor(max_workers=3) as ex:
        res = []
        for r in ex.map(scrape, mounts):
            res.append(r)
            done += 1
            if done % 50 == 0:
                print('done', done, flush=True)
    json.dump(res, open(os.path.join(SP, 'mounts_full.json'), 'w'))
    print('finished', len(res))
