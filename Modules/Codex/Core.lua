-- Seviath's Codex — core: data store, search, background jobs, helpers
-- License: CC BY-NC 3.0 (Petalsofiron)

local ADDON, ns = SFP_Module("Codex")
SeviathsCodex = ns

ns.COLOR = { r = 0.2, g = 0.9, b = 1.0 }          -- Seviath cyan
ns.CYAN  = "|cff33e6ff"

------------------------------------------------------------------------
-- Categories (order = order in the sidebar)
------------------------------------------------------------------------
ns.CATEGORIES = {
    { key = "guide",      name = "New Player Guide",        icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "dungeon",    name = "Dungeons",                icon = "Interface\\Icons\\INV_Misc_Key_14" },
    { key = "raid",       name = "Raids",                   icon = "Interface\\Icons\\Achievement_Boss_Ragnaros" },
    { key = "boss",       name = "Bosses",                  icon = "Interface\\Icons\\Achievement_Dungeon_ClassicDungeonMaster" },
    { key = "creature",   name = "Monsters & Creatures",    icon = "Interface\\Icons\\Ability_Hunter_BeastTaming" },
    { key = "item",       name = "Loot & Items",            icon = "Interface\\Icons\\INV_Chest_Plate16" },
    -- { key = "delve",      name = "Delves",                  icon = "Interface\\Icons\\INV_Misc_Lantern_01" }, -- retail only
    { key = "entrance",   name = "Entrances (How to Enter)", icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran" },
    { key = "quest",      name = "Quests (what to do)",     icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { key = "mount",      name = "Mounts",                  icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    { key = "pet",        name = "Battle Pets",             icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { key = "achievement",name = "Achievements & Titles",   icon = "Interface\\Icons\\Achievement_Quests_Completed_08" },
    { key = "tset",       name = "Transmog Sets",           icon = "Interface\\Icons\\INV_Chest_Cloth_17" },
    { key = "material",   name = "Materials (what for)",   icon = "Interface\\Icons\\INV_Fabric_Linen_01" },
    { key = "mats",       name = "Gold Farming",            icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom" },
}
-- Mists of Pandaria has no transmog sets window: leave that section out
if not (C_TransmogSets and C_TransmogSets.GetAllSets) then
    for i = #ns.CATEGORIES, 1, -1 do
        if ns.CATEGORIES[i].key == "tset" then table.remove(ns.CATEGORIES, i) end
    end
end
ns.CATBYKEY = {}
for _, c in ipairs(ns.CATEGORIES) do ns.CATBYKEY[c.key] = c end

------------------------------------------------------------------------
-- Data store
------------------------------------------------------------------------
ns.entries  = {}   -- key -> entry
ns.byCat    = {}   -- cat -> array of entries
ns.groups   = {}   -- cat -> ordered array of group names
local groupSeen = {}

for _, c in ipairs(ns.CATEGORIES) do
    ns.byCat[c.key] = {}
    ns.groups[c.key] = {}
    groupSeen[c.key] = {}
end

-- Add (or merge into) an entry. Returns the stored entry.
-- Required: cat, id, name. Optional: group, icon, sub, body, map={m,x,y},
-- wh="item=123", refs={keys}, plus any type-specific fields.
function ns:Add(e)
    if not e or not e.cat or not e.id or not e.name or e.name == "" then return end
    local key = e.cat .. ":" .. tostring(e.id)
    local old = self.entries[key]
    if old then
        for k, v in pairs(e) do
            if old[k] == nil then old[k] = v end
        end
        return old
    end
    e.key = key
    e.group = e.group or "Other"
    e.lname = e.name:lower()
    self.entries[key] = e
    local list = self.byCat[e.cat]
    list[#list + 1] = e
    if not groupSeen[e.cat][e.group] then
        groupSeen[e.cat][e.group] = true
        local g = self.groups[e.cat]
        g[#g + 1] = e.group
    end
    self.dirty = true
    if self.PrepareSearch then self.PrepareSearch(e) end
    return e
end

function ns:Get(key) return self.entries[key] end

-- Link two entries both ways (e.g. boss <-> item)
function ns:Link(a, b)
    if not a or not b then return end
    a.refs = a.refs or {}
    b.refs = b.refs or {}
    a.refs[#a.refs + 1] = b.key
    b.refs[#b.refs + 1] = a.key
end

function ns:Count(cat)
    return #self.byCat[cat]
end

------------------------------------------------------------------------
-- Search
------------------------------------------------------------------------
-- Smart search:
--  • any word order, partial words ("kael ash" finds Ash of Kael'thas…)
--  • ignores apostrophes, dashes and punctuation ("kaelthas" = "Kael'thas")
--  • searches names first, then type, source, zone, goal and objective text
--  • plurals ("drakes" finds Drake), short names (icc, bwl, kara…), initials
--  • small typos ("icecrwn") when there are few exact hits
--  • if not every word matches, the best partial matches are still shown

ns.ALIASES = {
    icc = "icecrown citadel", toc = "trial of the crusader", naxx = "naxxramas", bwl = "blackwing lair",
    mc = "molten core", aq = "ahn'qiraj", aq40 = "temple of ahn'qiraj", aq20 = "ruins of ahn'qiraj",
    kara = "karazhan", ssc = "serpentshrine cavern", tk = "tempest keep", bt = "black temple",
    swp = "sunwell plateau", voa = "vault of archavon", eoe = "eye of eternity", rs = "ruby sanctum", bwd = "blackwing descent", bot = "bastion of twilight",
    fl = "firelands", ds = "dragon soul", msv = "mogu'shan vaults", hof = "heart of fear",
    toes = "terrace of endless spring", tot = "throne of thunder", soo = "siege of orgrimmar",
    hm = "highmaul", brf = "blackrock foundry", hfc = "hellfire citadel", tov = "trial of valor", nh = "nighthold", tos = "tomb of sargeras", abt = "antorus",
    bod = "battle of dazar'alor", cos = "crucible of storms", ep = "eternal palace", nya = "ny'alotha",
    cn = "castle nathria", sod = "sanctum of domination", sfo = "sepulcher of the first ones",
    voti = "vault of the incarnates", nerub = "nerub-ar palace",
    lou = "liberation of undermine", brd = "blackrock depths", lbrs = "lower blackrock spire",
    ubrs = "upper blackrock spire", strat = "stratholme", scholo = "scholomance", dm = "deadmines",
    sfk = "shadowfang keep", wc = "wailing caverns", rfc = "ragefire chasm", zg = "zul'gurub", za = "zul'aman",
    mgt = "magisters' terrace", hol = "halls of lightning", hor = "halls of reflection",
    wq = "world quest", bfa = "battle for azeroth", sl = "shadowlands", df = "dragonflight", tww = "the war within",
    wotlk = "wrath of the lich king", tbc = "burning crusade", mop = "mists of pandaria", wod = "warlords of draenor",
    cata = "cataclysm", ah = "auction house", tmog = "transmog", xmog = "transmog",
}

local function norm(s)
    s = (s or ""):lower()
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " "):gsub("|T.-|t", "")
    s = s:gsub("\226\128\153", ""):gsub("['`]", ""):gsub("[%-%.,:;!%?%(%)%[%]\"/]", " "):gsub("%s+", " ")
    return (s:gsub("^ ", ""):gsub(" $", ""))
end
ns.norm = norm

local function prepare(e)
    if not e.name then return end
    if e._normFor == e.name then return end
    e._normFor = e.name
    e.nname = norm(e.name)
    local words, init = {}, {}
    for w in e.nname:gmatch("%S+") do
        words[#words + 1] = w
        init[#init + 1] = w:sub(1, 1)
    end
    e.nwords = words
    e.ninit = table.concat(init)
    local extra = (e.sub or "") .. " " .. (e.group or "") .. " " .. (e.tags or "") .. " "
        .. (e.source or "") .. " " .. (e.zone or "") .. " " .. ((e.cat == "achievement" or e.cat == "quest") and (e.body or e.objectives or "") or "")
    e.nall = norm(extra):sub(1, 400)
end

-- edit distance <= 1 (one typo: insert, delete or change a letter)
ns.PrepareSearch = prepare

local function oneTypo(a, b)
    local la, lb = #a, #b
    if math.abs(la - lb) > 1 then return false end
    local i, j, edits = 1, 1, 0
    while i <= la and j <= lb do
        if a:sub(i, i) ~= b:sub(j, j) then
            edits = edits + 1
            if edits > 1 then return false end
            if la > lb then i = i + 1
            elseif lb > la then j = j + 1
            else i = i + 1; j = j + 1 end
        else
            i = i + 1; j = j + 1
        end
    end
    return edits + (la - i + 1) + (lb - j + 1) <= 1
end

local function stem(w)
    if #w > 4 and w:sub(-3) == "ies" then return w:sub(1, -4) .. "y" end
    if #w > 4 and w:sub(-2) == "es" then return w:sub(1, -3) end
    if #w > 3 and w:sub(-1) == "s" then return w:sub(1, -2) end
    return w
end

-- Returns array of entries. cat = nil for all categories.
function ns:Search(query, cat, limit)
    limit = limit or 400
    local raw = norm(query)
    local out = {}
    if raw == "" then return out end
    local num = tonumber(raw)
    if num then
        for _, ck in ipairs({ "item", "quest", "achievement", "mount", "pet", "material" }) do
            local e = self:Get(ck .. ":" .. num)
            if e then e._score = 1000; out[#out + 1] = e end
        end
        for _, e in ipairs(self.byCat.material) do
            if e.itemID == num then e._score = 900; out[#out + 1] = e end
        end
        if #out > 0 then return out end
    end

    local words = {}
    for w in raw:gmatch("%S+") do
        local alias = self.ALIASES[w]
        if alias then
            for aw in norm(alias):gmatch("%S+") do words[#words + 1] = aw end
        else
            words[#words + 1] = w
        end
    end
    local need = math.max(1, math.ceil(#words * 0.6))   -- most words must match
    local allowTypos = false

    local function scoreWord(e, w)
        local p = e.nname:find(w, 1, true)
        if p == 1 then return 30 end
        if p then
            -- start of a word inside the name counts more than mid-word
            if e.nname:sub(p - 1, p - 1) == " " then return 24 end
            return 14
        end
        local sw = stem(w)
        if sw ~= w and e.nname:find(sw, 1, true) then return 20 end
        if e.nall:find(w, 1, true) then return 5 end
        if allowTypos and #w >= 4 and (#words == 1 or e._exactHit) then
            for _, nw in ipairs(e.nwords) do
                if oneTypo(w, nw) or (#nw > #w and oneTypo(w, nw:sub(1, #w))) then return 10 end
            end
        end
        return 0
    end

    local function score(e)
        prepare(e)
        local total, hit = 0, 0
        if allowTypos and #words > 1 then
            -- cheap pre-check: typos are only tried when some word already matches
            e._exactHit = false
            for _, w in ipairs(words) do
                if e.nname:find(w, 1, true) or e.nall:find(w, 1, true) then e._exactHit = true; break end
            end
            if not e._exactHit then return nil end
        end
        for _, w in ipairs(words) do
            local s = scoreWord(e, w)
            if s > 0 then hit = hit + 1; total = total + s end
        end
        -- initials: "icc" -> Icecrown Citadel… (only for short queries)
        if #words == 1 and #raw >= 2 and #raw <= 5 and e.ninit == raw then
            total = total + 60; hit = math.max(hit, 1)
        end
        if hit < need then return nil end
        if hit == #words then total = total + 40 end
        if e.nname == raw then total = total + 120
        elseif e.nname:find(raw, 1, true) == 1 then total = total + 50
        elseif e.nname:find(raw, 1, true) then total = total + 25 end
        -- prefer main content over side entries
        if e.cat == "guide" then total = total + 3 end
        return total
    end

    local cats = cat and { cat } or nil
    if not cats then
        cats = {}
        for _, c in ipairs(self.CATEGORIES) do cats[#cats + 1] = c.key end
    end
    local function run()
        for _, ck in ipairs(cats) do
            for _, e in ipairs(self.byCat[ck]) do
                local s = score(e)
                if s then
                    e._score = s
                    out[#out + 1] = e
                end
            end
        end
    end
    run()
    if #out < 8 then           -- few hits: try again allowing one typo per word
        allowTypos = true
        out = {}
        run()
    end
    table.sort(out, function(a, b)
        if a._score ~= b._score then return a._score > b._score end
        return a.name < b.name
    end)
    if #out > limit then
        for i = #out, limit + 1, -1 do out[i] = nil end
    end
    return out
end

------------------------------------------------------------------------
-- Background jobs (coroutines, time-sliced, paused in combat)
------------------------------------------------------------------------
ns.jobs = {}
ns.status = ""
local BUDGET_MS = 6
local driver = CreateFrame("Frame")
local sliceStart = 0

function ns:Yield()
    if debugprofilestop() - sliceStart > BUDGET_MS then
        coroutine.yield()
    end
end

function ns:Wait(seconds)
    local t = GetTime() + seconds
    while GetTime() < t do coroutine.yield() end
end

function ns:RunJob(name, fn)
    for _, j in ipairs(self.jobs) do
        if j.name == name then return end
    end
    -- no pcall here: Lua 5.1 can't yield through pcall. coroutine.resume
    -- already catches errors, and the driver reports them.
    local co = coroutine.create(fn)
    self.jobs[#self.jobs + 1] = { name = name, co = co }
    driver:Show()
end

driver:Hide()
driver:SetScript("OnUpdate", function(self)
    if InCombatLockdown() then return end
    local job = ns.jobs[1]
    if not job then
        self:Hide()
        ns.status = ""
        if ns.OnJobsDone then ns:OnJobsDone() end
        return
    end
    ns.status = job.name
    sliceStart = debugprofilestop()
    local ok, err = coroutine.resume(job.co)
    if not ok then ns:Print("error in " .. job.name .. ": " .. tostring(err)) end
    if coroutine.status(job.co) == "dead" then
        table.remove(ns.jobs, 1)
    end
    if ns.dirty and ns.OnDataChanged then
        ns.dirty = false
        ns:OnDataChanged()
    end
end)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
function ns:Print(msg)
    print(ns.CYAN .. "Seviath's Codex|r: " .. tostring(msg))
end

-- Wowhead URL for an entry (just a link the player can copy)
function ns:WowheadURL(e)
    if not e or not e.wh then return nil end
    return "https://www.wowhead.com/" .. e.wh
end

-- Map pins: one Codex pin at a time (Blizzard pin + TomTom arrow if installed).
-- ns.pin = { key, title, m, x, y, tt = TomTom uid }
function ns:Waypoint(m, x, y, title, key)
    if not (m and x and y) then return false end
    self:ClearPin(true)
    local tt
    if TomTom and TomTom.AddWaypoint then
        tt = TomTom:AddWaypoint(m, x, y, { title = title, persistent = false, minimap = true, world = true })
    end
    if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(m) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end
    self.pin = { key = key, title = title, m = m, x = x, y = y, tt = tt }
    if not InCombatLockdown() and OpenWorldMap then OpenWorldMap(m) end
    local info = C_Map.GetMapInfo(m)
    self:Print(("Pin: %s — %s %.1f, %.1f"):format(title or "?", info and info.name or "?", x * 100, y * 100))
    if self.OnPinChanged then self:OnPinChanged() end
    return true
end

function ns:ClearPin(silent)
    if self.pin and self.pin.tt and TomTom and TomTom.RemoveWaypoint then
        pcall(TomTom.RemoveWaypoint, TomTom, self.pin.tt)
    end
    if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end
    local had = self.pin ~= nil
    self.pin = nil
    if not silent then
        if had then self:Print("pin removed.") end
        if self.OnPinChanged then self:OnPinChanged() end
    end
end

function ns:MapName(m)
    local info = m and C_Map.GetMapInfo(m)
    return info and info.name or "?"
end

function ns:Coords(map)
    if not map then return nil end
    return ("%s  %.1f, %.1f"):format(self:MapName(map.m), map.x * 100, map.y * 100)
end

------------------------------------------------------------------------
-- Startup
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "ADDON_LOADED")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        SeviathsCodexDB = SeviathsCodexDB or {}
        local db = SeviathsCodexDB
        db.minimap = db.minimap or { angle = 200, hide = true } -- merged: use the Farm Pack minimap menu
        ns.db = db
        if ns.LoadGuide then ns:LoadGuide() end
        if ns.LoadSpecial then ns:LoadSpecial() end
    elseif event == "PLAYER_LOGIN" then
        if ns.CreateMinimapButton then ns:CreateMinimapButton() end
        -- Index lazily: start a few seconds after login so it never slows loading.
        C_Timer.After(8, function() ns:StartIndexing() end)
    end
end)

function ns:StartIndexing()
    if self.indexStarted then return end
    self.indexStarted = true
    for _, step in ipairs(self.INDEXERS or {}) do
        self:RunJob(step.name, step.fn)
    end
end

SLASH_SEVIATHSCODEX1 = "/codex"
SLASH_SEVIATHSCODEX2 = "/scodex"
SlashCmdList.SEVIATHSCODEX = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        if ns.UpdateMinimapButton then ns:UpdateMinimapButton() end
        ns:Print("minimap button " .. (ns.db.minimap.hide and "hidden" or "shown"))
        return
    elseif msg == "clear" or msg == "pin" then
        ns:ClearPin()
        return
    elseif msg == "reindex" then
        ns.indexStarted = false
        ns:StartIndexing()
        return
    end
    ns:StartIndexing()
    ns:Toggle(msg ~= "" and msg or nil)
end
