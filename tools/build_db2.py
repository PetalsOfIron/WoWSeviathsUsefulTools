import csv, json, os, sys, collections

D = os.path.join(os.environ["TEMP"], "db2")
SP = os.path.dirname(os.path.abspath(__file__))
csv.field_size_limit(10 ** 9)


def rows(name):
    with open(os.path.join(D, name + ".csv"), encoding="utf8", newline="") as f:
        for r in csv.DictReader(f):
            yield r


# ---- items: class / subclass / level, names and quality
item_cls = {}
for r in rows("Item"):
    item_cls[int(r["ID"])] = (int(r["ClassID"]), int(r["SubclassID"]), int(r["RequiredLevel"] or 0))
print("items", len(item_cls))

sparse = {}
for r in rows("ItemSparse"):
    i = int(r["ID"])
    name = r.get("Display_lang") or ""
    sparse[i] = (name, int(r.get("OverallQualityID") or 1), int(r.get("ItemLevel") or 0))
print("sparse", len(sparse), list(sparse.items())[:2])

# ---- recipe data
spell_name = {}
for r in rows("SpellName"):
    spell_name[int(r["ID"])] = r["Name_lang"]
skill_name = {int(r["ID"]): r["DisplayName_lang"] for r in rows("SkillLine")}
PROF = {171, 164, 333, 202, 773, 755, 165, 197, 185, 129, 186, 182, 393, 794, 356}
recipe_skill = {}
for r in rows("SkillLineAbility"):
    sk = int(r["SkillLine"])
    if sk in PROF:
        recipe_skill.setdefault(int(r["Spell"]), sk)
print("profession recipes", len(recipe_skill))

# recipe -> created item
created = {}
for r in rows("SpellEffect"):
    if int(r["Effect"]) == 24 and int(r["EffectItemType"] or 0):
        created.setdefault(int(r["SpellID"]), int(r["EffectItemType"]))

used_in = collections.defaultdict(list)     # reagent item -> [(recipe name, skill, count)]
for r in rows("SpellReagents"):
    sp = int(r["SpellID"])
    if sp not in recipe_skill:
        continue
    for k in range(8):
        it = int(r["Reagent_%d" % k] or 0)
        if it > 0:
            cnt = int(r["ReagentCount_%d" % k] or 1)
            out = created.get(sp)
            nm = spell_name.get(sp) or ""
            if out and out in sparse and sparse[out][0]:
                nm = sparse[out][0]
            used_in[it].append((nm, recipe_skill[sp], cnt))

# ---- materials = class 7 items that exist in this client with a name
mats = {}
for i, (c, s, lvl) in item_cls.items():
    if c == 7 and i in sparse and sparse[i][0] and i < 112000:
        mats[i] = {"n": sparse[i][0], "q": sparse[i][1], "s": s, "l": sparse[i][2] or lvl}
print("materials", len(mats))
for i, m in mats.items():
    u = used_in.get(i, [])
    seen, uu = set(), []
    for nm, sk, cnt in u:
        if (nm, sk) in seen or not nm:
            continue
        seen.add((nm, sk))
        uu.append([nm, sk])
    m["nu"] = len(uu)
    m["u"] = uu[:24]
json.dump(mats, open(os.path.join(SP, "mats_db2.json"), "w"))
print(collections.Counter(m["s"] for m in mats.values()))

# ---- mounts
effect_item = {}
for r in rows("ItemEffect"):
    sp = int(r["SpellID"])
    parent = int(r["ParentItemID"] or 0)
    if parent:
        effect_item.setdefault(sp, []).append(parent)
mounts = {}
for r in rows("Mount"):
    sp = int(r["SourceSpellID"])
    mid = int(r["ID"])
    items = [i for i in effect_item.get(sp, []) if i in sparse and sparse[i][0]]
    mounts[mid] = {"spell": sp, "name": r["Name_lang"], "item": items[0] if items else None, "stype": int(r["SourceTypeEnum"])}
print("mounts", len(mounts), "with item", sum(1 for m in mounts.values() if m["item"]))
json.dump(mounts, open(os.path.join(SP, "mounts_db2.json"), "w"))
