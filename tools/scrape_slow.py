"""Polite, single-threaded, resumable fetch of Wowhead item sources (mounts first, then materials).
One request every 3 seconds; stops at the first 403/429 instead of retrying."""
import json, os, re, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scrape_mats as sm
import scrape_mounts as smo

SP = sm.SP
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
        return ''
    return body if len(body) > 2000 else ''


# use the polite getter everywhere
sm.get = polite_get
smo.get = polite_get

mounts = json.load(open(os.path.join(SP, 'mounts_db2.json')))
todo_m = [{'id': v['spell'], 'name': v['name'], 'item': v['item']} for v in mounts.values() if v['item']]
mats = json.load(open(os.path.join(SP, 'mats_db2.json')))
todo_i = [{'id': int(k), 'name': v['n'], 'q': v['q'], 'sub': v['s'], 'lvl': v['l']} for k, v in mats.items()]

n = 0
for m in todo_m:
    if blocked:
        break
    smo.scrape(m)
    n += 1
    if n % 25 == 0:
        print('mounts', n, '/', len(todo_m), flush=True)
print('mounts finished' if not blocked else 'BLOCKED - stopped', flush=True)
n = 0
for it in todo_i:
    if blocked:
        break
    sm.scrape(it)
    n += 1
    if n % 50 == 0:
        print('materials', n, '/', len(todo_i), flush=True)
print('all finished' if not blocked else 'BLOCKED - stopped', flush=True)
