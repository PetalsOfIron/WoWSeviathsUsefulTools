-- Seviath's Codex — "how to do it" for achievements, mounts and pets.
-- Connects a goal to the things that make it happen: the achievement's
-- steps, the bosses to kill, the dungeons/raids involved — and prints the
-- full boss mechanics of every dungeon and raid that's part of it.

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

local function clean(s)
    if not s then return "" end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

------------------------------------------------------------------------
-- Name lookup (built lazily, rebuilt when data changes)
------------------------------------------------------------------------
local idx, idxCount = nil, -1
local function NameIndex()
    local total = 0
    for _, list in pairs(ns.byCat) do total = total + #list end
    if idx and idxCount == total then return idx end
    idx, idxCount = {}, total
    for cat, list in pairs(ns.byCat) do
        local t = {}
        for _, e in ipairs(list) do
            if not t[e.lname] then t[e.lname] = e end
        end
        idx[cat] = t
    end
    return idx
end

function ns:FindByName(cat, name)
    if not name or name == "" then return nil end
    local t = NameIndex()[cat]
    return t and t[name:lower():gsub("^%s+", ""):gsub("%s+$", "")]
end

local function FindInstance(name)
    return ns:FindByName("raid", name) or ns:FindByName("dungeon", name)
end

-- every dungeon/raid whose name appears inside a piece of text
local function InstancesInText(text, out, seen)
    if not text or text == "" then return end
    local l = text:lower()
    for _, cat in ipairs({ "raid", "dungeon" }) do
        for _, inst in ipairs(ns.byCat[cat]) do
            if #inst.lname > 5 and not seen[inst.key] and l:find(inst.lname, 1, true) then
                seen[inst.key] = true
                out[#out + 1] = inst
            end
        end
    end
end

------------------------------------------------------------------------
-- Collect what an achievement involves (recurses into sub-achievements)
------------------------------------------------------------------------
local function Collect(ach, ctx, depth)
    if not ach or ctx.visited[ach.key] or depth > 2 then return end
    ctx.visited[ach.key] = true
    InstancesInText(ach.body, ctx.instances, ctx.seen)
    InstancesInText(ach.name, ctx.instances, ctx.seen)
    local n = GetAchievementNumCriteria(ach.id) or 0
    for i = 1, n do
        local text, ctype, done, qty, req, _, _, assetID = GetAchievementCriteriaInfo(ach.id, i)
        if text and text ~= "" then
            local step
            if depth == 0 then
                step = { text = text, done = done, qty = qty, req = req }
                ctx.steps[#ctx.steps + 1] = step
            end
            local linked
            if ctype == 8 and assetID then                     -- another achievement
                linked = ns:Get("achievement:" .. assetID)
                if linked then Collect(linked, ctx, depth + 1) end
            elseif ctype == 27 and assetID then                -- a quest
                linked = ns:Get("quest:" .. assetID)
            elseif (ctype == 36 or ctype == 42) and assetID then -- an item
                linked = ns:Get("item:" .. assetID)
            elseif ctype == 0 then                             -- kill a creature
                local name = text:gsub(" [Kk]illed$", ""):gsub(" [Dd]efeated$", ""):gsub(" [Ss]lain$", ""):gsub("^%d+/%d+ ", "")
                linked = ns:FindByName("boss", name) or ns:FindByName("creature", name)
                if linked and linked.instKey and not ctx.seen[linked.instKey] then
                    local inst = ns:Get(linked.instKey)
                    if inst then ctx.seen[inst.key] = true; ctx.instances[#ctx.instances + 1] = inst end
                end
            end
            if not linked then
                linked = ns:FindByName("boss", text) or FindInstance(text)
                if linked and (linked.cat == "raid" or linked.cat == "dungeon") and not ctx.seen[linked.key] then
                    ctx.seen[linked.key] = true
                    ctx.instances[#ctx.instances + 1] = linked
                end
            end
            if not linked then
                linked = ns:FindByName("mount", text) or ns:FindByName("pet", text) or ns:FindByName("item", text)
            end
            if linked then ctx.links[#ctx.links + 1] = linked.key end
            if step then
                step.hint = ns:StepHint(ctype, text, linked)
                if linked and linked.cat == "achievement" then
                    step.goal = linked.body
                    step.tip = ns.AchievementTip and ns:AchievementTip(linked.name, linked.body)
                    step.done = step.done or linked.collected
                end
            end
        end
    end
end

-- One practical line per achievement step
function ns:StepHint(ctype, text, linked)
    local l = (text or ""):lower()
    if linked then
        if linked.cat == "achievement" then return "finish the achievement \"" .. linked.name .. "\" first (open it in Related for its own steps)" end
        if linked.cat == "quest" then return "complete this quest (open it in Related for where to go)" end
        if linked.cat == "boss" then
            local inst = linked.instKey and ns:Get(linked.instKey)
            return "kill this boss" .. (inst and (" in " .. inst.name) or "") .. " — mechanics below"
        end
        if linked.cat == "mount" or linked.cat == "pet" then
            return "collect it — " .. ((linked.sub and linked.sub ~= "") and linked.sub or "see its page in Related")
        end
        if linked.cat == "item" then
            local sold = ns.SoldBy and ns:SoldBy(linked.itemID or linked.id)
            if sold then return "buy it — " .. sold:gsub("\n.*", "") end
            return "get this item — " .. (linked.sub ~= "" and linked.sub or "see Related")
        end
        if linked.cat == "creature" then
            return "kill/find it — " .. (linked.sub or "") .. (linked.map and " (Show on map from its page in Related)" or "")
        end
        if linked.cat == "raid" or linked.cat == "dungeon" then return "complete " .. linked.name .. " — mechanics below" end
    end
    if l:find("level") and l:find("reach") then return "level up — quests, dungeons or delves" end
    if ctype == 0 then
        local name = (text or ""):gsub(" [Kk]illed$", ""):gsub(" [Dd]efeated$", ""):gsub(" [Ss]lain$", ""):gsub("^%d+/%d+ ", "")
        local cr = ns:FindByName("creature", name) or ns:FindByName("boss", name)
        if cr then return "kill " .. cr.name .. " — " .. (cr.sub or "") end
        return "kill " .. name .. " — not in the Codex yet; it's recorded with its spot once you mouse over it (beasts) or use the Wowhead link"
    end
    if ctype == 27 then return "complete this quest" end
    if ctype == 36 or ctype == 42 then return "obtain this item (drop, vendor or craft — search it in Loot & Items)" end
    if ctype == 43 then return "walk through this area until it's discovered" end
    if ctype == 46 then return "raise your reputation with this faction" end
    if l:find("toy") then return "get the toy and learn it (it then shows in Collections » Toy Box); upgradable toys are upgraded by using the item named in the toy's tooltip" end
    if l:find("level") and l:find("reach") then return "level up — quests, dungeons or delves" end
    if l:find("win") or l:find("victor") then return "win the listed battles or matches" end
    if l:find("explore") or l:find("discover") then return "walk through every part of the area" end
    if l:find("mount") then return "collect the mount (Mounts section shows where)" end
    if l:find("pet") then return "collect or battle with pets (Battle Pets section shows where)" end
    return nil
end

-- How-to by achievement category (the group path from the Achievements window)
local CATEGORY_HOW = {
    { "love is in the air", "World event, February (about 2 weeks). Talk to the event NPCs in Stormwind / Orgrimmar; the Crown Chemical Co. dailies give Love Tokens, the event currency for the vendors. Check the calendar for dates." },
    { "lunar festival", "World event, around January-February. Travel to Moonglade and honor the Elders (each Elder is a spot on the map in its zone)." },
    { "noblegarden", "World event, spring. Collect eggs in the starting-zone towns and spend the chocolate at the event vendors." },
    { "children's week", "World event, May. Take the orphan quest in a capital and do the visits with your orphan out." },
    { "midsummer", "World event, June-July. Visit the bonfires in every zone (honor your faction's, desecrate the enemy's)." },
    { "brewfest", "World event, September-October. Event grounds outside Ironforge / Orgrimmar; daily ram racing and the Coren Direbrew dungeon boss." },
    { "hallow's end", "World event, October. Candy buckets in every inn, and the Headless Horseman dungeon boss (queue in the Group Finder)." },
    { "pilgrim's bounty", "World event, November. Cooking dailies and the bountiful tables in the capitals." },
    { "winter veil", "World event, December. Dailies in Ironforge / Orgrimmar and presents under the tree on Christmas morning." },
    { "darkmoon", "Darkmoon Faire: the first week of every month. Portal from Elwynn Forest / Mulgore; daily games give tickets." },
    { "exploration", "Explore: fly over every named area of the zone. Undiscovered areas stay dark on the map (M)." },
    { "pet battle", "Pet battles: learn from a Battle Pet Trainer, then battle wild pets and tamers. See the Battle Pets guide for family strengths." },
    { "reputation", "Reputation: do that faction's quests, world quests and kills; old factions often have repeatable turn-ins or a tabard for dungeon reputation." },
    { "quests", "Quests: finish the storylines in that zone. The quest log map (M) shows all available ! icons; the Quests section here explains each one." },
    { "dungeons & raids", "Dungeons & raids: kill the bosses named in the steps. Old content can be soloed at max level." },
    { "professions", "Professions: level / craft with that profession — the Materials section shows what each material is for." },
    { "player vs. player", "PvP: queue in the PvP window (H). Battleground achievements need wins in that battleground." },
    { "collections", "Collections: every source is in the Mounts / Battle Pets / Transmog sections — dimmed ones are still missing." },
    { "delves", "Delves: see the Delves section for locations, tiers and companion setup." },
}
local function CategoryHow(group)
    local g = (group or ""):lower()
    for _, c in ipairs(CATEGORY_HOW) do
        if g:find(c[1], 1, true) then return c[2] end
    end
end

-- items sold by vendors you've visited that are named in some text
local function VendorItemsIn(text)
    local out = {}
    if not text or text == "" or not (ns.db and ns.db.vendorItems) then return out end
    local l = text:lower()
    for id in pairs(ns.db.vendorItems) do
        local n = C_Item.GetItemNameByID(id)
        if n and #n > 4 and l:find(n:lower(), 1, true) then out[#out + 1] = id end
    end
    return out
end

-- Practical tips based on what the goal says
local function Tips(text)
    local t = (text or ""):lower()
    local tips = {}
    local function add(s) tips[#tips + 1] = "• " .. s end
    if t:find("without") or t:find("while") or t:find("within") or t:find("before") or t:find("only") then
        add("This has a special condition — the goal text above is the hard part. Read the boss mechanics below to see how to set it up.")
    end
    if t:find("solo") or t:find("alone") or t:find("by yourself") then
        add("Solo: do it alone. Old content is easy at max level; current content needs good gear and a defensive plan for the biggest hits.")
    end
    if t:find("mythic") and not t:find("keystone") and not t:find("mythic%+") then
        add("Mythic difficulty: form a group (Premade Groups) — Mythic can't be queued. For old raids you can set Mythic on your own: right-click your portrait » Raid Difficulty.")
    elseif t:find("heroic") then
        add("Heroic difficulty: set it before entering — right-click your portrait » Dungeon/Raid Difficulty, or queue for Heroic in the Group Finder.")
    end
    if t:find("keystone") or t:find("mythic%+") then
        add("Mythic+: needs a keystone of the required level, finished in time.")
    end
    if t:find("delve") or t:find("tier") then
        add("Delve: choose the right tier at the delve entrance before you go in.")
    end
    if t:find("timewalking") then add("Timewalking: only during Timewalking event weeks (see the calendar).") end
    if t:find("explore") then add("Exploration: walk through every named area of the zone — undiscovered parts are dark on the map (M).") end
    if t:find("exalted") or t:find("reputation") or t:find("renown") then
        add("Reputation: raise it with that faction's quests, world quests and kills; check progress in Character » Reputation.")
    end
    if t:find("pet battle") or t:find("battle pet") then add("Pet battles: see the Battle Pets guide article for family strengths.") end
    if t:find("collect") and (t:find("mount") or t:find("pet") or t:find("toy")) then
        add("Collection: every source is listed in the Mounts / Battle Pets sections — sort by what you're missing (dimmed).")
    end
    if t:find("complete") and t:find("quests") then
        add("Quest count: do the zone's quests — the Quests section can be searched by zone or name.")
    end
    return tips
end

-- Special conditions for well-known old-content rewards (hand-written)
ns.SPECIAL_CONDITIONS = {
    ["invincible's reins"] = "Only from The Lich King on 25-player Heroic (Icecrown Citadel). Set the raid to 25 Heroic before entering.",
    ["mimiron's head"] = "Only from Yogg-Saron on 25-player when no Keepers help in the fight (the 'Alone in the Darkness' condition). Check Wowhead for the exact setup.",
    ["ashes of al'ar"] = "Kael'thas Sunstrider in Tempest Keep (The Eye). Long fight with phases — just keep killing; no special condition.",
    ["fiery warhorse's reins"] = "Attumen the Huntsman, first boss of Karazhan. No special condition — farm weekly.",
    ["reins of the blue proto-drake"] = "Skadi the Ruthless in Utgarde Pinnacle on Heroic. Skadi only lands after his harpoon phase — use the harpoons, or wait.",
    ["swift white hawkstrider"] = "Kael'thas Sunstrider in Magisters' Terrace on Heroic.",
    ["deathcharger's reins"] = "Lord Aurius Rivendare in Stratholme (service entrance side).",
    ["kor'kron juggernaut"] = "Garrosh Hellscream in Siege of Orgrimmar on Mythic only.",
}
for k, v in pairs({ ["invincible"] = "invincible's reins", ["fiery warhorse"] = "fiery warhorse's reins",
    ["blue proto-drake"] = "reins of the blue proto-drake", ["rivendare's deathcharger"] = "deathcharger's reins" }) do
    ns.SPECIAL_CONDITIONS[k] = ns.SPECIAL_CONDITIONS[v]
end

-- For OLD content only the parts that matter for getting the reward are shown
-- (boss, difficulty, special condition). Full mechanics only for current content,
-- and then only for the bosses that matter when we know them.
local function MechanicsBlock(instances, focus, condition)
    if #instances == 0 then return "" end
    focus = focus or {}
    local parts = {}
    for i, inst in ipairs(instances) do
        if i > 12 then
            parts[#parts + 1] = ("|cff888888…and %d more — open them from Related below.|r"):format(#instances - 12)
            break
        end
        local where = inst.map and ("  |cff888888(" .. ns:Coords(inst.map) .. ")|r") or ""
        local head = "|cffffd100" .. (inst.isRaid and "RAID: " or "DUNGEON: ") .. inst.name .. "|r" .. where
        -- bosses that matter in this instance
        local bosses = {}
        for _, k in ipairs(inst.refs or {}) do
            local b = ns:Get(k)
            if b and b.cat == "boss" and focus[k] then bosses[#bosses + 1] = b end
        end
        if inst.legacy then
            local lines = { "Old content: bosses die fast at max level. For achievements, follow each step's Goal / How above — those conditions are what matter." }
            for _, b in ipairs(bosses) do lines[#lines + 1] = "• Kill: |cffffffff" .. b.name .. "|r" end
            if #bosses == 0 then lines[#lines + 1] = "• Kill the bosses named above (loot is personal and drops for you)." end
            if condition then lines[#lines + 1] = "• |cffff9900Special condition:|r " .. condition end
            lines[#lines + 1] = "• Each boss gives loot once per week per difficulty — set the difficulty first (right-click your portrait)."
            parts[#parts + 1] = head .. "\n" .. table.concat(lines, "\n")
        else
            local body
            if #bosses > 0 then
                local bl = {}
                for _, b in ipairs(bosses) do
                    bl[#bl + 1] = "|cffffd100" .. b.name .. "|r\n" .. (ns:BossAbilities(b) or "No mechanics listed.")
                end
                body = table.concat(bl, "\n\n")
            else
                body = ns:InstanceMechanics(inst) or "No bosses listed."
            end
            if condition then body = "|cffff9900Special condition:|r " .. condition .. "\n\n" .. body end
            parts[#parts + 1] = head .. "\n" .. body
        end
    end
    return "\n\n" .. C .. "What to do there|r\n" .. table.concat(parts, "\n\n")
end

local function AddLinks(e, keys)
    if e._explained then return end
    e._explained = true
    e.refs = e.refs or {}
    local have = {}
    for _, k in ipairs(e.refs) do have[k] = true end
    for _, k in ipairs(keys) do
        if not have[k] and k ~= e.key then have[k] = true; e.refs[#e.refs + 1] = k end
    end
end

------------------------------------------------------------------------
-- Achievement page
------------------------------------------------------------------------
function ns:AchievementHowTo(e)
    local ctx = { visited = {}, seen = {}, instances = {}, steps = {}, links = {} }
    Collect(e, ctx, 0)
    local out = {}
    if e.collected ~= nil then
        out[#out + 1] = e.collected and "|cff40ff40Completed|r" or "|cffff7070Not completed yet|r"
    end
    out[#out + 1] = "\n\n" .. C .. "Goal|r\n" .. (e.body or "")
    if e.reward and e.reward ~= "" then out[#out + 1] = "\n\n" .. C .. "Reward|r\n" .. e.reward end

    if #ctx.steps > 0 then
        local s = {}
        for i, st in ipairs(ctx.steps) do
            local prog = (st.req and st.req > 1) and (" (%d/%d)"):format(st.qty or 0, st.req) or ""
            s[#s + 1] = ("%s%d. %s%s"):format(st.done and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " or "", i, st.text, prog)
                .. ((st.goal and st.goal ~= "") and ("\n     |cffffffffGoal:|r " .. st.goal) or "")
                .. (st.tip and ("\n     |cffff9900How:|r " .. st.tip)
                    or (st.hint and ("\n     |cffaaaaaa» " .. st.hint .. "|r") or ""))
        end
        out[#out + 1] = "\n\n" .. C .. "Steps|r\n" .. table.concat(s, "\n")
    end

    local tips = Tips((e.body or "") .. " " .. e.name)
    local own = ns.AchievementTip and ns:AchievementTip(e.name, e.body)
    if own then table.insert(tips, 1, "• |cffff9900How:|r " .. own) end
    local catHow = CategoryHow(e.group)
    if catHow then table.insert(tips, 1, "• " .. catHow) end
    for _, id in ipairs(VendorItemsIn((e.body or "") .. " " .. e.name)) do
        local sold, spot = ns:SoldBy(id)
        if sold then
            tips[#tips + 1] = "• Buy " .. (C_Item.GetItemNameByID(id) or "it") .. ":\n    " .. sold:gsub("\n", "\n    ")
            if spot and not e.map then e.map = spot end
        end
    end
    if #ctx.instances > 0 then
        tips[#tips + 1] = "• Go to: " .. (function()
            local names = {}
            for i, inst in ipairs(ctx.instances) do if i <= 6 then names[#names + 1] = inst.name end end
            return table.concat(names, ", ") .. (#ctx.instances > 6 and ", …" or "")
        end)() .. " — entrances and routes are in Related below."
    end
    if #tips == 0 then tips[1] = "• Do what the goal says; each step above opens in Related below when the Codex knows it." end
    out[#out + 1] = "\n\n" .. C .. "How to do it|r\n" .. table.concat(tips, "\n")
    local focus = {}
    for _, k in ipairs(ctx.links) do if k:find("^boss:") then focus[k] = true end end
    local body = (e.body or ""):lower()
    local cond = (body:find("without") or body:find("while") or body:find("within") or body:find("before")
        or body:find("only") or body:find("solo") or body:find("alive")) and e.body or nil
    out[#out + 1] = MechanicsBlock(ctx.instances, focus, cond)
    if e.points then out[#out + 1] = "\n\n|cff888888" .. e.points .. " achievement points|r" end

    local keys = {}
    for _, k in ipairs(ctx.links) do keys[#keys + 1] = k end
    for _, inst in ipairs(ctx.instances) do
        keys[#keys + 1] = inst.key
        local ent = ns:Get("entrance:" .. inst.instanceID)
        if ent then keys[#keys + 1] = ent.key end
    end
    AddLinks(e, keys)
    return table.concat(out)
end

------------------------------------------------------------------------
-- Mount / pet page: turn the source text into steps
------------------------------------------------------------------------
function ns:SourceHowTo(e)
    local src = clean(e.source)
    local out, keys, instances, seen = {}, {}, {}, {}
    if e.collected ~= nil then
        out[#out + 1] = e.collected and "|cff40ff40Collected|r" or "|cffff7070Not collected yet|r"
    end
    out[#out + 1] = "\n\n" .. C .. "How to get it|r\n" .. (src ~= "" and src:gsub("|n", "\n") or "Unknown")

    local extra, zones, kinds, sfocus = {}, {}, {}, {}
    local vendorsMissing
    local function addZones(value)
        for z in value:gmatch("[^,]+") do
            z = z:gsub("^%s+", ""):gsub("%s+$", "")
            if z ~= "" then zones[#zones + 1] = z end
        end
    end
    for line in (src .. "|n"):gmatch("(.-)|n") do
        local label, value = line:match("^%s*([^:]+):%s*(.-)%s*$")
        if label and value and value ~= "" then
            label = label:lower()
            kinds[label] = value
            if label:find("pet battle") then
                addZones(value)
            elseif label:find("achievement") then
                local ach = ns:FindByName("achievement", value)
                if ach then
                    keys[#keys + 1] = ach.key
                    extra[#extra + 1] = "\n\n" .. C .. "The achievement: " .. ach.name .. "|r\n" .. ns:AchievementHowTo(ach):gsub("^\n+", "")
                end
            elseif label:find("drop") or label:find("boss") then
                local boss = ns:FindByName("boss", value) or ns:FindByName("creature", value)
                if boss then
                    keys[#keys + 1] = boss.key
                    sfocus[boss.key] = true
                    local inst = boss.instKey and ns:Get(boss.instKey)
                    if inst and not seen[inst.key] then seen[inst.key] = true; instances[#instances + 1] = inst end
                    if boss.body and boss.cat == "creature" then extra[#extra + 1] = "\n\n" .. boss.body end
                end
            elseif label:find("vendor") then
                local v = ns.VendorByName and ns:VendorByName(value)
                if v then
                    extra[#extra + 1] = "\n\n" .. C .. "Vendor you've visited|r\n" .. v.n .. " — " .. ns:Coords(v)
                        .. "\n|cff888888Show on map points to this vendor.|r"
                    if not e.map then e.map = { m = v.m, x = v.x, y = v.y } end
                else
                    vendorsMissing = (vendorsMissing or "") .. (vendorsMissing and ", " or "") .. value
                end
            elseif label:find("quest") then
                local q = ns:FindByName("quest", value)
                if q then keys[#keys + 1] = q.key end
            elseif label:find("zone") or label:find("location") then
                local inst = FindInstance(value)
                if inst then
                    if not seen[inst.key] then seen[inst.key] = true; instances[#instances + 1] = inst end
                else addZones(value) end
            end
        end
    end
    InstancesInText(src, instances, seen)

    -- what the source type means, in plain words
    local what = {}
    local function has(word)
        for k in pairs(kinds) do if k:find(word, 1, true) then return true end end
        return src:lower():find(word, 1, true) ~= nil
    end
    if has("pet battle") then
        what[#what + 1] = "• Wild pet: it lives in the zones below. Turn on Find Battle Pets (minimap tracking) and look for green paw icons. Click it to start a pet battle, bring it under 35% health, then use Trap. Learn pet battles first from a Battle Pet Trainer in any city."
    end
    if has("vendor") then what[#what + 1] = "• Buy it from the vendor named above, for gold or the currency listed under Cost." end
    if has("drop") then what[#what + 1] = "• Drops from the enemy named above. Drop rates for mounts and pets are often low — farm it repeatedly (old raids: once per week per difficulty)." end
    if has("profession") then what[#what + 1] = "• Crafted with the profession named above — learn the recipe first, or buy it from a crafter or the Auction House." end
    if has("world event") or has("holiday") then what[#what + 1] = "• Only during that holiday event — check the in-game calendar for dates." end
    if has("quest") then what[#what + 1] = "• Reward from the quest named above (search it in the Quests section)." end
    if has("achievement") then what[#what + 1] = "• Reward for the achievement named above — the full how-to is below." end
    if has("renown") or has("reputation") then what[#what + 1] = "• Unlocked by raising that faction's renown / reputation, then bought from its quartermaster." end
    if has("trading post") then what[#what + 1] = "• Trading Post: the monthly rotating shop in Stormwind and Orgrimmar, bought with Trader's Tender from monthly activities." end
    if has("promotion") or has("in-game shop") or has("shop") or has("trading card") then
        what[#what + 1] = "• Not found in the world: it comes from the Blizzard shop, a promotion or the old trading card game."
    end
    if has("discovery") or has("treasure") then what[#what + 1] = "• Found in the world (treasure, object or hidden event) — use the Wowhead link for the exact spot." end
    if #what > 0 then out[#out + 1] = "\n\n" .. C .. "What that means|r\n" .. table.concat(what, "\n") end

    -- every zone it's in, with the route there
    if #zones > 0 then
        local zl = {}
        for i, zname in ipairs(zones) do
            if i > 10 then zl[#zl + 1] = "…and more"; break end
            local m = ns:ZoneByName(zname)
            if m then
                local contID, contName = ns.ContinentOf(m)
                local tip = (contID and ns.TRAVEL[contID]) or (contName and ns.TRAVEL_BYNAME[contName:lower()])
                local first
                if tip then
                    local mine = UnitFactionGroup("player") or ""
                    for l in tip:gmatch("[^\n]+") do
                        if l:match("^%d%.") then
                            if mine ~= "" and l:find(mine, 1, true) then first = l; break end
                            if not first and not l:find("Alliance") and not l:find("Horde") then first = l end
                        end
                    end
                end
                zl[#zl + 1] = "|cffffd100" .. zname .. "|r" .. (contName and (" » " .. contName) or "")
                    .. (first and ("\n    " .. first) or "")
                if not e.openMap then e.openMap = m end
            else
                zl[#zl + 1] = "|cffffd100" .. zname .. "|r"
            end
        end
        for _, zname in ipairs(zones) do
            local zl2 = zname:lower()
            if zl2 == "lunarfall" or zl2 == "frostwall" then
                zl[#zl + 1] = "|cffaaaaaaLunarfall (Alliance, Shadowmoon Valley) and Frostwall (Horde, Frostfire Ridge) are your own Draenor garrison — get there with the Garrison Hearthstone (toy box) after unlocking the garrison in Draenor. Each faction only needs its own one.|r"
                break
            end
        end
        out[#out + 1] = "\n\n" .. C .. "Where|r\n" .. table.concat(zl, "\n")
            .. "\n|cff888888Show on map opens the first zone. Full travel steps are on any entrance page of that continent.|r"
    end

    if ns.SPECIAL_CONDITIONS[e.lname] and #instances == 0 then
        out[#out + 1] = "\n\n" .. C .. "Special condition|r\n" .. ns.SPECIAL_CONDITIONS[e.lname]
    end
    if vendorsMissing then
        out[#out + 1] = "\n\n|cff888888Vendor spot: visit " .. vendorsMissing .. " once (on any character) and the Codex saves the exact spot for the map pin. Until then Show on map opens the zone.|r"
    end
    for _, x in ipairs(extra) do out[#out + 1] = x end
    if #instances > 0 then
        local wl = {}
        for _, inst in ipairs(instances) do
            local ent = ns:Get("entrance:" .. inst.instanceID)
            local cont
            if inst.map then cont = select(2, ns.ContinentOf(inst.map.m)) end
            wl[#wl + 1] = "|cffffd100" .. inst.name .. "|r (" .. (inst.isRaid and "raid" or "dungeon") .. ")"
                .. (inst.map and ("\n    Entrance: " .. ns:Coords(inst.map) .. (cont and (" » " .. cont) or "")) or "")
                .. (ent and "\n    Full route: open its Entrances page in Related below." or "")
            if inst.map and not e.map then e.map = inst.map end
        end
        out[#out + 1] = "\n\n" .. C .. "Where (instance)|r\n" .. table.concat(wl, "\n")
        out[#out + 1] = MechanicsBlock(instances, sfocus, ns.SPECIAL_CONDITIONS[e.lname])
        for _, inst in ipairs(instances) do
            keys[#keys + 1] = inst.key
            local ent = ns:Get("entrance:" .. inst.instanceID)
            if ent then keys[#keys + 1] = ent.key end
        end
    end
    AddLinks(e, keys)
    return table.concat(out)
end

------------------------------------------------------------------------
-- Transmog set page: where each piece comes from + how to get it
------------------------------------------------------------------------
local function SourceTypeName(t)
    return (t and _G["TRANSMOG_SOURCE_" .. t]) or nil
end

function ns:SetHowTo(e)
    local out, keys, instances, seen = {}, {}, {}, {}
    out[#out + 1] = e.collected and "|cff40ff40Set collected|r" or "|cffff7070Not fully collected yet|r"
    local label = (e.sub or ""):gsub("%s*%[other class%]", "")
    if label ~= "" then out[#out + 1] = "\n\n" .. C .. "Set|r\n" .. label end

    local srcIDs = (C_TransmogSets.GetAllSourceIDs and C_TransmogSets.GetAllSourceIDs(e.setID)) or {}
    local pieces, missingNames, types, doneItems, focus = {}, false, {}, {}, {}
    for _, src in ipairs(srcIDs) do
        local info = C_TransmogCollection.GetSourceInfo(src)
        if info and info.itemID and not doneItems[info.itemID] then
            doneItems[info.itemID] = true
            local name = info.name or C_Item.GetItemNameByID(info.itemID)
            if not name then
                missingNames = true
                C_Item.RequestLoadItemDataByID(info.itemID)
                name = "item " .. info.itemID .. " (loading…)"
            end
            local how = {}
            local stype = SourceTypeName(info.sourceType)
            if stype then types[stype] = true end
            if C_TransmogCollection.GetAppearanceSourceDrops then
                for _, d in ipairs(C_TransmogCollection.GetAppearanceSourceDrops(src) or {}) do
                    local diff = (d.difficulties and #d.difficulties > 0) and (" (" .. table.concat(d.difficulties, ", ") .. ")") or ""
                    how[#how + 1] = "drops from " .. (d.encounter or "?") .. " — " .. (d.instance or "?") .. diff
                    local inst = d.instance and FindInstance(d.instance)
                    if inst and not seen[inst.key] then seen[inst.key] = true; instances[#instances + 1] = inst end
                    local boss = d.encounter and ns:FindByName("boss", d.encounter)
                    if boss then keys[#keys + 1] = boss.key; focus[boss.key] = true end
                end
            end
            if #how == 0 and stype then
                if stype == SourceTypeName(3) and (label ~= "" or e.name:find("Player")) then
                    how[1] = stype .. " — usually a tier token from the raid's bosses, traded at the tier vendor"
                else
                    how[1] = stype
                end
            end
            local item = ns:Get("item:" .. info.itemID)
            if item then keys[#keys + 1] = item.key end
            pieces[#pieces + 1] = (info.isCollected and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " or "• ")
                .. name .. (#how > 0 and ("\n     |cffaaaaaa» " .. table.concat(how, "; ") .. "|r") or "")
        end
    end
    if missingNames then
        e._stries = (e._stries or 0) + 1
        if e._stries <= 4 then
            C_Timer.After(0.8, function()
                if ns.state and ns.state.selected == e.key then ns:ShowEntry(e.key, true) end
            end)
        end
    end
    if #pieces > 0 then out[#out + 1] = "\n\n" .. C .. "Pieces and where they come from|r\n" .. table.concat(pieces, "\n") end

    -- instances named in the set label or name (e.g. "Gruul's Lair")
    InstancesInText(label .. " " .. e.name, instances, seen)

    local tips = {}
    local function add(s) tips[#tips + 1] = "• " .. s end
    local all = (label .. " " .. e.name):lower()
    if all:find("gladiator") or all:find("season") or all:find("pvp") or types[TRANSMOG_SOURCE_PVP or "PvP"] then
        add("PvP set from an old PvP season. Many base PvP looks can still be bought from the legacy PvP vendors in Stormwind / Orgrimmar with Marks of Honor; elite / Gladiator versions are often no longer obtainable — check the Wowhead link.")
    end
    if all:find("timewalking") then add("Timewalking vendor set: buy the pieces with Timewarped Badges during Timewalking weeks.") end
    if #instances > 0 then add("Raid / dungeon set: kill the bosses listed for each piece. Old content can be soloed at max level; each boss gives loot once per week per difficulty. Different difficulties (Normal / Heroic / Mythic) have different colors.") end
    if types[SourceTypeName(3) or "Vendor"] then add("Pieces marked Vendor in raid sets come from tier tokens: a boss drops a token (e.g. Conqueror's / Vanquisher's / Protector's), and you trade it at that expansion's tier vendor for your class's piece. Use the Wowhead link to see which vendor.") end
    if types[SourceTypeName(6) or "Profession"] then add("Some pieces are crafted — find a crafter or the Auction House.") end
    if e.sub and e.sub:find("other class") then add("This set is for another class/armor type — collect it on a character of that class.") end
    add("Every piece you loot or equip is added to your Appearances (Collections) for your whole Warband.")
    out[#out + 1] = "\n\n" .. C .. "How to get it|r\n" .. table.concat(tips, "\n")

    if #instances > 0 then
        local wl = {}
        for _, inst in ipairs(instances) do
            local cont
            if inst.map then cont = select(2, ns.ContinentOf(inst.map.m)) end
            wl[#wl + 1] = "|cffffd100" .. inst.name .. "|r (" .. (inst.isRaid and "raid" or "dungeon") .. ")"
                .. (inst.map and ("\n    Entrance: " .. ns:Coords(inst.map) .. (cont and (" » " .. cont) or "")) or "")
            if inst.map and not e.map then e.map = inst.map end
            keys[#keys + 1] = inst.key
            local ent = ns:Get("entrance:" .. inst.instanceID)
            if ent then keys[#keys + 1] = ent.key end
        end
        out[#out + 1] = "\n\n" .. C .. "Where|r\n" .. table.concat(wl, "\n")
        out[#out + 1] = MechanicsBlock(instances, focus)
    end
    e._explained = nil
    AddLinks(e, keys)
    return table.concat(out)
end

------------------------------------------------------------------------
-- Old dungeon/raid page: what's worth getting there, not full mechanics
------------------------------------------------------------------------
function ns:LegacyInstanceText(inst)
    local bossNames = {}
    for _, k in ipairs(inst.refs or {}) do
        local b = ns:Get(k)
        if b and b.cat == "boss" then bossNames[#bossNames + 1] = { name = b.name, lname = b.lname, key = b.key, order = b.order or 0 } end
    end
    table.sort(bossNames, function(a, b) return a.order < b.order end)

    local function mentions(text)
        if not text or text == "" then return false end
        local l = text:lower()
        if l:find(inst.lname, 1, true) then return true end
        for _, b in ipairs(bossNames) do
            if #b.lname > 4 and l:find(b.lname, 1, true) then return true end
        end
        return false
    end

    local found = { mount = {}, pet = {}, achievement = {}, tset = {} }
    for cat, list in pairs(found) do
        for _, x in ipairs(ns.byCat[cat]) do
            local text = (x.source or "") .. " " .. (x.sub or "") .. " " .. (cat == "achievement" and (x.name .. " " .. (x.body or "")) or "")
            if mentions(text) then list[#list + 1] = x end
        end
    end

    local out = {}
    out[#out + 1] = C .. "Old content|r\nSolo it at max level — bosses die fast, so for loot just kill. Achievements here have their own conditions: open them (Related) for the Goal and How of each step. Loot is personal (Legacy Loot), and each boss gives loot once per week per difficulty. Set the difficulty before entering: right-click your portrait."
    local bl = {}
    for i, b in ipairs(bossNames) do bl[#bl + 1] = i .. ". " .. b.name end
    if #bl > 0 then out[#out + 1] = C .. "Bosses|r\n" .. table.concat(bl, "\n") end

    local labels = { { "mount", "Mounts" }, { "pet", "Pets" }, { "achievement", "Achievements" }, { "tset", "Transmog sets" } }
    local keys = {}
    local any = false
    for _, lb in ipairs(labels) do
        local list = found[lb[1]]
        if #list > 0 then
            any = true
            local ll = {}
            for i, x in ipairs(list) do
                if i > 25 then ll[#ll + 1] = ("…and %d more"):format(#list - 25); break end
                local mark = x.collected and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " or "• "
                local how = ""
                if lb[1] == "mount" or lb[1] == "pet" then
                    local cond = ns.SPECIAL_CONDITIONS[x.lname]
                    how = cond and ("\n     |cffff9900» " .. cond .. "|r") or (x.sub ~= "" and ("\n     |cffaaaaaa» " .. x.sub .. "|r") or "")
                elseif lb[1] == "achievement" then
                    how = "\n     |cffaaaaaa» " .. (x.body or "") .. "|r"
                end
                ll[#ll + 1] = mark .. x.name .. how
                keys[#keys + 1] = x.key
            end
            out[#out + 1] = C .. "Worth getting here: " .. lb[2] .. "|r\n" .. table.concat(ll, "\n")
        end
    end
    if not any then out[#out + 1] = "|cff888888No mounts, pets, achievements or sets found for this instance yet (some appear after the full index finishes).|r" end
    if inst.map then out[#out + 1] = C .. "Entrance|r\n" .. ns:Coords(inst.map) .. "\n|cff888888Full route: its Entrances page in Related.|r" end

    if not inst._legacyLinked then
        inst._legacyLinked = true
        inst.refs = inst.refs or {}
        local have = {}
        for _, k in ipairs(inst.refs) do have[k] = true end
        for _, k in ipairs(keys) do if not have[k] then inst.refs[#inst.refs + 1] = k end end
    end
    return table.concat(out, "\n\n")
end
