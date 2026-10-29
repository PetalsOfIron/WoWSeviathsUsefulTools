"""Keeps Data/Learned.lua up to date while you play.
The game only writes the addon's saved data when you /reload or log out; this script notices that and copies what the
addon learned (monsters, drops, items, nodes, recipes, farm spots, quest giver positions, quest monster places) into the
addon folder by running merge_learned.py.
Usage: python watch_learned.py ["path to WTF/Account"]    (leave it running; Ctrl+C stops it)"""
import glob, os, subprocess, sys, time

SP = os.path.dirname(os.path.abspath(__file__))
acc = sys.argv[1] if len(sys.argv) > 1 else os.path.join(SP, "..", "..", "..", "..", "WTF", "Account")
PATTERN = os.path.join(acc, "*", "SavedVariables", "SeviathsUsefulTools.lua")
last = {}

print("Watching", os.path.normpath(acc), "- the saved data is written when you /reload or log out.", flush=True)
while True:
    changed = False
    for f in glob.glob(PATTERN):
        t = os.path.getmtime(f)
        if last.get(f) != t:
            if f in last:
                changed = True
            last[f] = t
    if changed:
        time.sleep(3)   # let the game finish writing
        subprocess.run([sys.executable, os.path.join(SP, "merge_learned.py"), acc])
    time.sleep(30)
