---------------------------------------------------------------
-- SeviathsGuildHelper v1.6.0
-- Guild recruitment helper: /who scans, class-coloured list,
-- whisper pitch with <GUILD>/<INFO>/<NAME>, auto-invite on "yes"
-- within 10 minutes, zones & cities only, paused in combat,
-- officer history + message sync.
---------------------------------------------------------------
local ADDON_NAME = "SeviathsUsefulTools" -- merged into the Farm Pack
local VERSION = "1.7.1"
local CY = "|cff00e5ff"
local function P(msg) print(CY .. "SGH:|r " .. tostring(msg)) end

---------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------
local MSG_COOLDOWN    = 15552000  -- 6 months before the same player is contacted again
local PENDING_TIMEOUT = 600       -- 10 minutes to answer "yes" and get auto-invited
local SEND_DELAY      = 1.5       -- seconds between whispers
local WHO_COOLDOWN    = 5         -- seconds between /who queries
local MAX_WHISPER     = 250       -- WoW limit is 255
local MAX_TEMPLATE    = 200
local VISIBLE_ROWS    = 12
local ROW_H           = 20
local DEFAULT_MESSAGE = "Hi <NAME>! Would you like to join <GUILD>? <INFO> Reply \"yes\" and I'll send you an invite!"
local DEFAULT_CHARTER = "Hi <NAME>! I'm founding a new guild, <GUILD>, and need a few signatures on my charter. It's free, takes 5 seconds and you can leave right after. Reply \"yes\" and I'll send a group invite - I'm in <ZONE>."
local CHARTER_THANKS  = "Thank you! Group invite sent. I'm in <ZONE> at <COORDS> - come say hi and I'll send the charter to sign :)"
local CHARTER_ITEM    = 5863      -- Guild Charter
local CHARTER_ASK_CD  = 86400     -- don't ask the same player to sign again for 1 day

local BRACKETS = { "1-10", "11-20", "21-30", "31-40", "41-50", "51-60", "61-70", "71-80", "81-90" }

-- Phrases that count as YES. Matched at the start of the reply,
-- or anywhere for the multi-word ones. Repeated letters are
-- collapsed first, so "yesss", "okk", "yeees" all match.
local AGREED_WORDS = {
    "yes", "y", "ye", "yea", "yeah", "yeh", "yep", "yup", "ya", "yah", "yas", "yis", "yess",
    "ok", "okay", "okey", "oki", "okie", "k", "kk", "sure", "surely", "of course", "ofc",
    "invite", "inv", "invite me", "inv me", "inv pls", "inv plz", "invite pls", "invite plz",
    "send invite", "send inv", "send it", "send me an invite", "send me invite",
    "pls", "plz", "please", "yes please", "yes pls", "sure thing", "why not", "ok why not",
    "definitely", "absolutely", "certainly", "totally", "for sure", "alright", "all right",
    "aight", "fine", "cool", "deal", "great", "nice", "sounds good", "sounds great",
    "sounds fun", "go", "go ahead", "lets go", "let's go", "lets do it", "count me in",
    "im in", "i'm in", "i am in", "im interested", "i'm interested", "interested",
    "i would like that", "id like that", "i'd like that", "would love to", "id love to",
    "i'd love to", "love to", "i want to", "i wanna", "i want in", "happy to", "gladly",
    "ja", "jā", "jaa", "gerne", "oui", "si", "sí", "sim", "tak", "da", "да", "Да", "ДА",
    "конечно", "joo", "jo", "labi", "protams", "jasa", "+", "+1", "<3",
}

local DECLINED_WORDS = {
    "no", "n", "nope", "nah", "naw", "no thanks", "no thank you", "no ty", "no thx",
    "not interested", "pass", "decline",
    "already in a guild", "in a guild", "i have a guild", "have a guild", "got a guild",
    "already have a guild", "im good", "i'm good", "im fine", "i'm fine", "stop",
    "leave me alone", "dont", "don't", "never", "нет", "nē", "nein", "non",
}

-- If any of these words appear, the reply is never treated as YES
-- ("not sure", "no idea", "i don't know"...).
local NEGATIONS = { "not", "no", "dont", "don't", "cant", "can't", "never", "nah", "nope", "maybe", "later", "idk", "hmm", "busy" }

-- Positive phrases that contain a "negative" word; turned into "yes" first.
local POSITIVE_PHRASES = { "why not", "no problem", "no prob", "no probs", "no worries", "not a problem",
    "cant wait", "can't wait", "dont mind", "don't mind", "i dont mind", "i don't mind" }

---------------------------------------------------------------
-- STATE
---------------------------------------------------------------
local DB                       -- account-wide saved table (shared by your characters)
local scanned, scannedIdx = {}, {}
local pending = {}             -- [plainName] = { t = time(), target = "Name-Realm" }
local selected                 -- currently selected entry
local selectedClass            -- { name = "Mage", token = "MAGE" } or nil
local showReadyOnly = false
local nextBracket = 1
local lastWhoAt = -100
local expectingWho, friendsWasShown = false, false
local lastScanText = "Not scanned yet."
local UI                       -- main window (created below)
local Refresh, RenderRows, BroadcastRecord, ToggleUI, UpdatePreview, UpdateStatus

---------------------------------------------------------------
-- SAVED VARIABLES
---------------------------------------------------------------
local function InitDB()
    if not SeviathsGuildHelperDB and GuildInviterDB then SeviathsGuildHelperDB = GuildInviterDB end
    SeviathsGuildHelperDB = SeviathsGuildHelperDB or {}
    SeviathsGuildHelperCharDB = SeviathsGuildHelperCharDB or {}
    DB = SeviathsGuildHelperDB
    DB.settings = DB.settings or {}
    local s = DB.settings
    -- your own message is never replaced; the default is only used when there is none
    if not s.message or s.message == "" then
        s.message = DEFAULT_MESSAGE
        s.messageTS = 0
    end
    s.messageTS = s.messageTS or 0
    s.messageBy = s.messageBy or ""
    s.messageEdited = s.messageEdited or 0
    -- officers' messages are never applied automatically unless you turn it on (reset once for older versions)
    if not s.syncOptIn then s.syncMessage = false; s.syncOptIn = true end
    if s.autoInvite == nil then s.autoInvite = true end
    s.minimap = s.minimap or { angle = 200, hide = true } -- merged into the Farm Pack: opened from its minimap menu
    s.charterMessage = s.charterMessage or DEFAULT_CHARTER
    DB.records = DB.records or {}
    -- migrate v1.5 tables (messaged / declined)
    if DB.messaged then
        for n, t in pairs(DB.messaged) do
            if not DB.records[n] then DB.records[n] = { s = "M", t = t, by = "" } end
        end
        DB.messaged = nil
    end
    if DB.declined then
        for n, t in pairs(DB.declined) do DB.records[n] = { s = "D", t = t, by = "" } end
        DB.declined = nil
    end
    DB.lastOnline = DB.lastOnline or 0
end

---------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------
local function StripRealm(name)
    if not name then return "" end
    return (name:gsub("%-.*$", ""))
end

local function FullName(name)
    if not name or name == "" then return name end
    if name:find("%-") then return name end
    return name .. "-" .. (GetNormalizedRealmName() or GetRealmName() or "")
end

local function Me() return UnitName("player") or "" end

local function InCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function TimeAgo(ts)
    local d = time() - (ts or 0)
    if d < 60 then return "just now" end
    if d < 3600 then return math.floor(d / 60) .. "m ago" end
    if d < 86400 then return math.floor(d / 3600) .. "h ago" end
    return math.floor(d / 86400) .. "d ago"
end

local function CanInviteNow()
    if not IsInGuild() then return false, "You are not in a guild — inviting is disabled." end
    if CanGuildInvite and not CanGuildInvite() then return false, "Your guild rank can't invite players." end
    return true
end

---------------------------------------------------------------
-- GUILD CHARTER MODE (not in a guild yet -> collect signatures)
---------------------------------------------------------------
local petitionOpen = false

local function CharterMode() return not IsInGuild() end

local function HasCharterItem()
    local n = 0
    if C_Item and C_Item.GetItemCount then n = C_Item.GetItemCount(CHARTER_ITEM) or 0
    elseif GetItemCount then n = GetItemCount(CHARTER_ITEM) or 0 end
    return n > 0
end

local function Charter()
    SeviathsGuildHelperCharDB = SeviathsGuildHelperCharDB or {}
    local c = SeviathsGuildHelperCharDB.charter
    if not c then
        c = { title = "", sigs = {}, min = 4, done = false }
        SeviathsGuildHelperCharDB.charter = c
    end
    return c
end

local function CharterSigned(name)
    local key = StripRealm(name)
    for _, n in ipairs(Charter().sigs) do if StripRealm(n) == key then return true end end
    return false
end

-- may we whisper people right now?
local function CanContactNow()
    if CharterMode() then
        if not HasCharterItem() then
            return false, "You are not in a guild and have no Guild Charter. Buy one from a Guild Master NPC in a capital city."
        end
        return true
    end
    return CanInviteNow()
end

local function MyZone()
    local z = (GetZoneText and GetZoneText()) or ""
    local sub = (GetSubZoneText and GetSubZoneText()) or ""
    if sub ~= "" and sub ~= z then z = z .. " (" .. sub .. ")" end
    return z ~= "" and z or "town"
end

local function MyCoords()
    local ok, txt = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        local pos = map and C_Map.GetPlayerMapPosition(map, "player")
        if not pos then return "" end
        local x, y = pos:GetXY()
        return ("%.1f, %.1f"):format(x * 100, y * 100)
    end)
    return ok and txt or ""
end

---------------------------------------------------------------
-- CLASS COLOURS
---------------------------------------------------------------
local CLASS_LIST = {}        -- { {name, token}, ... }
local CLASS_BY_NAME = {}     -- localized name -> token

local function BuildClassList()
    wipe(CLASS_LIST); wipe(CLASS_BY_NAME)
    for id = 1, 13 do
        local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo and C_CreatureInfo.GetClassInfo(id)
        if info and info.className and info.classFile then
            CLASS_LIST[#CLASS_LIST + 1] = { name = info.className, token = info.classFile }
        end
    end
    if #CLASS_LIST == 0 and LOCALIZED_CLASS_NAMES_MALE then
        for _, t in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
            "MAGE", "WARLOCK", "MONK", "DRUID" }) do
            if LOCALIZED_CLASS_NAMES_MALE[t] then
                CLASS_LIST[#CLASS_LIST + 1] = { name = LOCALIZED_CLASS_NAMES_MALE[t], token = t }
            end
        end
    end
    for _, c in ipairs(CLASS_LIST) do CLASS_BY_NAME[c.name] = c.token end
    for _, tbl in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
        for token, name in pairs(tbl) do CLASS_BY_NAME[name] = token end
    end
end

local function ClassHex(token)
    if token and C_ClassColor and C_ClassColor.GetClassColor then
        local c = C_ClassColor.GetClassColor(token)
        if c and c.GenerateHexColor then return c:GenerateHexColor() end
    end
    local rc = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if rc and rc.colorStr then return rc.colorStr end
    return "ffffffff"
end

local function ClassText(text, token) return "|c" .. ClassHex(token) .. (text or "") .. "|r" end

---------------------------------------------------------------
-- ZONES & CITIES ONLY (instances, delves, BGs, arenas skipped)
---------------------------------------------------------------
local openWorld, instanceNames, zonesBuilt = {}, {}, false
local KNOWN_PVP = {
    "Warsong Gulch", "Arathi Basin", "Alterac Valley", "Eye of the Storm", "Strand of the Ancients",
    "Isle of Conquest", "Twin Peaks", "Battle for Gilneas", "Silvershard Mines", "Temple of Kotmogu",
    "Deepwind Gorge", "Seething Shore", "Ashran", "Wintergrasp", "Tol Barad", "Deephaul Ravine",
    "Nagrand Arena", "Blade's Edge Arena", "Dalaran Arena", "Ruins of Lordaeron", "Tol'viron Arena",
    "Tiger's Peak", "Black Rook Hold Arena", "Ashamane's Fall", "Mugambala", "Hook Point",
    "The Robodrome", "Empyrean Domain", "Enigma Crucible", "Maldraxxus Coliseum",
    "Nokhudon Proving Grounds", "Cage of Carnage",
}

local function BuildZones()
    zonesBuilt = true
    wipe(openWorld); wipe(instanceNames)
    local ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    local DUNGEON = Enum and Enum.UIMapType and Enum.UIMapType.Dungeon or 4
    if C_Map and C_Map.GetMapInfo then
        for id = 1, 4000 do
            local mi = C_Map.GetMapInfo(id)
            if mi and mi.name and mi.name ~= "" then
                if mi.mapType == ZONE then openWorld[mi.name] = true
                elseif mi.mapType == DUNGEON then instanceNames[mi.name] = true end
            end
        end
    end
    -- dungeons & raids from the Encounter Journal
    pcall(function()
        local prev = EJ_GetCurrentTier and EJ_GetCurrentTier()
        for tier = 1, EJ_GetNumTiers() do
            EJ_SelectTier(tier)
            for _, raid in ipairs({ false, true }) do
                local i = 1
                while true do
                    local id, name = EJ_GetInstanceByIndex(i, raid)
                    if not id then break end
                    instanceNames[name] = true
                    i = i + 1
                end
            end
        end
        if prev then EJ_SelectTier(prev) end
    end)
    pcall(function()
        for i = 1, GetNumBattlegroundTypes() do
            local name = GetBattlegroundInfo(i)
            if name then instanceNames[name] = true end
        end
    end)
    for _, n in ipairs(KNOWN_PVP) do instanceNames[n] = true end
    -- an instance name beats a zone with the same name
    for n in pairs(instanceNames) do openWorld[n] = nil end
end

local function NoteMyZone()
    local z = GetRealZoneText and GetRealZoneText()
    if not z or z == "" then return end
    if IsInInstance() then instanceNames[z] = true; openWorld[z] = nil
    else openWorld[z] = true; instanceNames[z] = nil end
end

local function IsOpenWorld(area)
    if not area or area == "" then return false end
    if not zonesBuilt then BuildZones() end
    if instanceNames[area] then return false end
    if openWorld[area] then return true end
    -- unknown name: if the zone table failed to build, allow it; otherwise skip
    return next(openWorld) == nil
end

---------------------------------------------------------------
-- RECORDS (shared between officers)
-- s = "M" messaged, "I" invited, "D" declined (permanent)
---------------------------------------------------------------
local function GetRecord(name) return DB and DB.records[StripRealm(name)] end

local function SetRecord(name, state, ts, by, fromSync)
    local key = StripRealm(name)
    if key == "" then return false end
    ts = tonumber(ts) or time()
    local r = DB.records[key]
    if r then
        local accept = (state == "D" and r.s ~= "D") or (r.s ~= "D" and ts > (r.t or 0))
        if not accept then return false end
    end
    DB.records[key] = { s = state, t = ts, by = by or "" }
    if not fromSync and BroadcastRecord then BroadcastRecord(key) end
    return true
end

local function IsGuilded(e) return e.guild and e.guild ~= "" end

local STATUS = {
    ready     = { order = 1, label = "Ready",          color = "ff00e5ff", tip = "Can be whispered now." },
    pending   = { order = 2, label = "Waiting reply",  color = "ffffd200", tip = "Whispered. If they answer yes within 10 minutes they are invited automatically." },
    invited   = { order = 3, label = "Invited",        color = "ff40ff80", tip = "Guild invite (or group invite in charter mode) was sent." },
    signed    = { order = 3, label = "Signed charter", color = "ff40ff80", tip = "Signed your guild charter." },
    contacted = { order = 4, label = "Contacted",      color = "ff8a9aa0", tip = "Already contacted in the last 6 months (by you or another officer)." },
    instance  = { order = 5, label = "In instance",    color = "ffff9933", tip = "In a dungeon, raid, delve, battleground or arena — skipped. Only zones and cities are invited." },
    guilded   = { order = 6, label = "Has a guild",    color = "ff6c7a80", tip = "Already in a guild — skipped." },
    declined  = { order = 7, label = "Declined",       color = "ffff4040", tip = "Said no (or marked Skip forever) — never contacted again." },
}

local function GetStatus(e)
    local key = StripRealm(e.name)
    local p = pending[key]
    if p and time() - p.t <= PENDING_TIMEOUT then return "pending" end
    if CharterMode() and CharterSigned(e.name) then return "signed" end
    local r = GetRecord(e.name)
    if r and r.s == "D" then return "declined" end
    if r and (r.s == "C" or r.s == "G") then
        -- charter request / group invite: only blocks for one day
        if time() - (r.t or 0) < CHARTER_ASK_CD then return r.s == "G" and "invited" or "contacted" end
    elseif r and time() - (r.t or 0) < MSG_COOLDOWN then
        return r.s == "I" and "invited" or "contacted"
    end
    if IsGuilded(e) then return "guilded" end
    if not IsOpenWorld(e.area) then return "instance" end
    return "ready"
end

---------------------------------------------------------------
-- MESSAGE BUILDING  (<GUILD>  <INFO>  <NAME>)
---------------------------------------------------------------
local function CaseInsensitive(s)
    return (s:gsub("%a", function(c) return "[" .. c:upper() .. c:lower() .. "]" end))
end
local PAT_GUILD = CaseInsensitive("<GUILD>")
local PAT_OLD   = CaseInsensitive("<OUR GUILD>")
local PAT_INFO  = CaseInsensitive("<INFO>")
local PAT_NAME  = CaseInsensitive("<NAME>")
local PAT_ZONE  = CaseInsensitive("<ZONE>")
local PAT_COORD = CaseInsensitive("<COORDS>")

local function TemplateKey() return CharterMode() and "charterMessage" or "message" end
local function DefaultTemplate() return CharterMode() and DEFAULT_CHARTER or DEFAULT_MESSAGE end

local function GuildInfoText()
    local info = (GetGuildInfoText and GetGuildInfoText()) or ""
    if IsSecret(info) then return "" end
    info = info:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    info = info:gsub("%c", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return info
end

local function BuildMessage(target, template)
    local guild, info
    if CharterMode() then
        guild = Charter().title ~= "" and Charter().title or "my new guild"
        info = ""
    else
        guild = GetGuildInfo("player") or "our guild"
        info = GuildInfoText()
    end
    local who = (target and target ~= "") and StripRealm(target) or "there"
    local msg = template or (DB and DB.settings[TemplateKey()]) or DefaultTemplate()
    msg = msg:gsub(PAT_ZONE, function() return MyZone() end)
    msg = msg:gsub(PAT_COORD, function() return MyCoords() end)
    msg = msg:gsub(PAT_OLD, "<GUILD>")
    msg = msg:gsub(PAT_GUILD, function() return guild end)
    msg = msg:gsub(PAT_INFO, function() return info end)
    msg = msg:gsub(PAT_NAME, function() return who end)
    msg = msg:gsub("[\r\n]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return msg
end

-- split into whispers of <= 250 bytes, at spaces, max 3 parts
local function SplitMessage(msg)
    local parts, rest = {}, msg
    while #rest > MAX_WHISPER and #parts < 2 do
        local cut = rest:sub(1, MAX_WHISPER)
        local sp = cut:match("^.*()%s")
        if not sp or sp < 80 then
            sp = MAX_WHISPER
            while sp > 1 and rest:byte(sp + 1) and rest:byte(sp + 1) >= 128 and rest:byte(sp + 1) < 192 do sp = sp - 1 end
        end
        parts[#parts + 1] = (rest:sub(1, sp):gsub("%s+$", ""))
        rest = (rest:sub(sp + 1):gsub("^%s+", ""))
    end
    if #rest > MAX_WHISPER then
        local sp = MAX_WHISPER - 3
        while sp > 1 and rest:byte(sp + 1) and rest:byte(sp + 1) >= 128 and rest:byte(sp + 1) < 192 do sp = sp - 1 end
        rest = rest:sub(1, sp) .. "..."
    end
    if rest ~= "" then parts[#parts + 1] = rest end
    return parts
end

---------------------------------------------------------------
-- REPLY DETECTION
---------------------------------------------------------------
local function Normalize(t)
    t = t:lower()
    t = t:gsub("[%.,!%?;:%-_%*~\"%(%)%[%]]", " ")
    local n                             -- yesss -> yes, okk -> ok
    repeat t, n = t:gsub("(.)%1", "%1") until n == 0
    t = t:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return t
end

local function Prepare(list)
    local out = {}
    for _, w in ipairs(list) do out[#out + 1] = Normalize(w) end
    return out
end
local AGREED   = Prepare(AGREED_WORDS)
local DECLINED = Prepare(DECLINED_WORDS)
local NEGATE   = Prepare(NEGATIONS)

local function Matches(text, list, anywhere)
    local t = " " .. text .. " "
    for _, w in ipairs(list) do
        if w ~= "" then
            local pw = " " .. w .. " "
            if t == pw or t:sub(1, #pw) == pw then return true end
            if anywhere and w:find(" ") and t:find(pw, 1, true) then return true end
        end
    end
    return false
end

local POSITIVE = Prepare(POSITIVE_PHRASES)
table.sort(POSITIVE, function(x, y) return #x > #y end)

local function ClassifyReply(raw)
    local t = Normalize(raw)
    if t == "" then
        if raw:find("%+") then return "yes" end
        return nil
    end
    t = " " .. t .. " "
    for _, ph in ipairs(POSITIVE) do
        local pat = " " .. ph:gsub("%p", "%%%0") .. " "
        t = t:gsub(pat, " yes ")
    end
    t = t:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if Matches(t, DECLINED, true) then return "no" end
    for _, n in ipairs(NEGATE) do
        if (" " .. t .. " "):find(" " .. n .. " ", 1, true) then return nil end
    end
    if Matches(t, AGREED, true) then return "yes" end
    return nil
end

---------------------------------------------------------------
-- SEND QUEUE (whispers + invites, paused while you are in combat)
---------------------------------------------------------------
local queue, queueRunning = {}, false

local function ProcessQueue()
    if #queue == 0 then queueRunning = false; if UpdateStatus then UpdateStatus() end; return end
    if InCombat() then queueRunning = false; if UpdateStatus then UpdateStatus() end; return end
    local item = table.remove(queue, 1)
    local ok, err = pcall(item.run)
    if not ok then P("|cffff4040Error:|r " .. tostring(err)) end
    if UpdateStatus then UpdateStatus() end
    C_Timer.After(item.delay or SEND_DELAY, ProcessQueue)
end

local function Enqueue(run, delay)
    queue[#queue + 1] = { run = run, delay = delay }
    if not queueRunning then
        queueRunning = true
        ProcessQueue()
    end
end

local function ResumeQueue()
    if #queue > 0 and not queueRunning then
        queueRunning = true
        C_Timer.After(1, ProcessQueue)
        P("Combat over — sending " .. #queue .. " queued action(s).")
    end
end

local function SendWhisperRaw(target, text)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(text, "WHISPER", nil, target)
    else
        SendChatMessage(text, "WHISPER", nil, target)
    end
end

---------------------------------------------------------------
-- CORE ACTIONS
---------------------------------------------------------------
local function InvitePlayer(target, reason)
    local ok, err = CanInviteNow()
    if not ok then P(err) return end
    local full = FullName(target)
    local plain = StripRealm(target)
    if InCombat() then P("In combat — invite for " .. plain .. " will be sent when combat ends.") end
    Enqueue(function()
        if not CanInviteNow() then return end
        if C_GuildInfo and C_GuildInfo.Invite then C_GuildInfo.Invite(full) else GuildInvite(full) end
        pending[plain] = nil
        SetRecord(plain, "I", time(), Me())
        P("Guild invite sent to " .. CY .. plain .. "|r" .. (reason and (" (" .. reason .. ")") or "") .. ".")
        if Refresh then Refresh() end
    end, 0.5)
end

-- charter mode: a "yes" gets a group invite + where to find you
local function GroupInvite(target, reason)
    local full = FullName(target)
    local plain = StripRealm(target)
    if InCombat() then P("In combat — group invite for " .. plain .. " will be sent when combat ends.") end
    Enqueue(function()
        if IsInGroup() and not IsInRaid() and GetNumGroupMembers() >= 5 and C_PartyInfo and C_PartyInfo.ConvertToRaid then
            C_PartyInfo.ConvertToRaid()
        end
        if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(full) else InviteUnit(full) end
        pending[plain] = nil
        SetRecord(plain, "G", time(), Me())
        P("Group invite sent to " .. CY .. plain .. "|r" .. (reason and (" (" .. reason .. ")") or "") .. ". Target them when they arrive and click |cff00e5ffAsk target to sign|r.")
        if Refresh then Refresh() end
    end, 0.5)
    Enqueue(function() SendWhisperRaw(full, BuildMessage(full, CHARTER_THANKS)) end)
end

local function SendPitch(e)
    local ok, err = CanContactNow()
    if not ok then P(err) return false end
    local st = GetStatus(e)
    if st ~= "ready" then
        P(StripRealm(e.name) .. " skipped: " .. STATUS[st].label .. ".")
        return false
    end
    local plain = StripRealm(e.name)
    local target = FullName(e.name)
    local parts = SplitMessage(BuildMessage(e.name))
    pending[plain] = { t = time(), target = target }
    if InCombat() then P("In combat — whisper to " .. plain .. " queued until combat ends.") end
    for i, part in ipairs(parts) do
        Enqueue(function()
            SendWhisperRaw(target, part)
            if i == #parts then
                pending[plain] = { t = time(), target = target }   -- 10 min window starts when sent
                SetRecord(plain, CharterMode() and "C" or "M", time(), Me())
                if Refresh then Refresh() end
            end
        end, i < #parts and 0.7 or SEND_DELAY)
    end
    return true
end

local function HandleWhisper(text, sender)
    if not text or not sender or IsSecret(text) or IsSecret(sender) then return end
    local plain = StripRealm(sender)
    local p = pending[plain]
    if not p then return end
    if time() - p.t > PENDING_TIMEOUT then pending[plain] = nil return end
    local answer = ClassifyReply(text)
    if answer == "yes" and CharterMode() then
        if DB.settings.autoInvite then
            GroupInvite(sender, "they agreed to sign")
        else
            P(CY .. plain .. "|r agreed to sign — select them and click Group invite.")
        end
    elseif answer == "yes" then
        if DB.settings.autoInvite then
            InvitePlayer(sender, "they said yes")
        else
            P(CY .. plain .. "|r said yes — select them and click Invite.")
        end
    elseif answer == "no" then
        pending[plain] = nil
        SetRecord(plain, "D", time(), Me())
        P(plain .. " declined — they won't be contacted again.")
        if Refresh then Refresh() end
    end
end

C_Timer.NewTicker(30, function()
    local now, changed = time(), false
    for k, p in pairs(pending) do
        if now - p.t > PENDING_TIMEOUT then pending[k] = nil; changed = true end
    end
    if changed and Refresh then Refresh() end
end)

---------------------------------------------------------------
-- /WHO SCAN  (one bracket per click — Blizzard requires a click)
---------------------------------------------------------------
local function DoWho(bracket)
    local wait = lastWhoAt + WHO_COOLDOWN - GetTime()
    if wait > 0 then
        local m = ("|cffff9933Please wait %ds before the next scan (Blizzard /who limit).|r"):format(math.ceil(wait))
        if UI and UI.scanInfo then UI.scanInfo:SetText(m) else P(m) end
        return false
    end
    lastWhoAt = GetTime()
    local q = bracket
    if selectedClass then q = 'c-"' .. selectedClass.name .. '" ' .. bracket end
    if C_FriendList and C_FriendList.SetWhoToUi then C_FriendList.SetWhoToUi(true) end
    friendsWasShown = FriendsFrame and FriendsFrame:IsShown() or false
    expectingWho = true
    lastScanText = "Scanning " .. (selectedClass and ClassText(selectedClass.name, selectedClass.token) or "all classes") .. " level " .. bracket .. "..."
    if C_FriendList and C_FriendList.SendWho then C_FriendList.SendWho(q) else SendWho(q) end
    if UI and UI.scanInfo then UI.scanInfo:SetText(lastScanText) end
    return bracket
end

local function UpdateBracketButtons()
    if not (UI and UI.bracketBtns) then return end
    for i, btn in ipairs(UI.bracketBtns) do btn:SetActive(i == nextBracket) end
    if UI.scanBtn then UI.scanBtn:SetLabel("Scan " .. BRACKETS[nextBracket]) end
end

local function SelectBracket(i)
    nextBracket = i
    UpdateBracketButtons()
end

-- scans the selected level range, then moves the selection to the next range
local function ScanNext()
    if DoWho(BRACKETS[nextBracket]) then
        SelectBracket(nextBracket % #BRACKETS + 1)
    end
end

local function OnWhoResults()
    local num, total = C_FriendList.GetNumWhoResults()
    num = num or 0
    local added, me = 0, Me()
    for i = 1, num do
        local info = C_FriendList.GetWhoInfo(i)
        local name = info and (info.fullName or info.name)
        if name and name ~= "" and StripRealm(name) ~= me then
            local e = scannedIdx[name]
            if not e then
                e = { name = name }
                scanned[#scanned + 1] = e
                scannedIdx[name] = e
                added = added + 1
            end
            e.level = info.level or 0
            e.class = info.classStr or info.classString or ""
            e.token = info.filename or CLASS_BY_NAME[e.class]
            e.area  = info.area or ""
            e.guild = info.fullGuildName or info.guild or ""
        end
    end
    if expectingWho then
        expectingWho = false
        if not friendsWasShown and FriendsFrame and FriendsFrame:IsShown() then HideUIPanel(FriendsFrame) end
    end
    lastScanText = ("Found %d (%d new)."):format(num, added)
    if (total or 0) > num then
        lastScanText = lastScanText .. " |cffff9933List capped at " .. num .. " of " .. total .. " — pick a class to see more.|r"
    end
    if Refresh then Refresh() end
end

---------------------------------------------------------------
-- UI HELPERS (flat Seviath cyan theme)
---------------------------------------------------------------
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

local function Skin(f, r, g, b, a, br, bg, bb, ba)
    f:SetBackdrop(FLAT)
    f:SetBackdropColor(r or 0.02, g or 0.05, b or 0.07, a or 0.95)
    f:SetBackdropBorderColor(br or 0, bg or 0.9, bb or 1, ba or 0.8)
end

local function ShowTip(owner, title, body)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:AddLine(title, 0, 0.9, 1)
    if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function MakeButton(parent, text, w, h, tip, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    Skin(b, 0, 0.22, 0.27, 0.75, 0, 0.9, 1, 0.7)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b.label = text
    function b:SetLabel(t) self.label = t; self.text:SetText(t) end
    function b:Paint()
        if self.active then
            self:SetBackdropColor(0, 0.75, 0.85, 0.95)
            self:SetBackdropBorderColor(0.6, 1, 1, 1)
        else
            self:SetBackdropColor(0, 0.22, 0.27, 0.75)
            self:SetBackdropBorderColor(0, 0.9, 1, 0.7)
        end
    end
    function b:SetActive(v) self.active = v and true or false; self:Paint() end
    b:SetScript("OnEnter", function(self)
        if not self.active then self:SetBackdropColor(0, 0.45, 0.55, 0.9) end
        if tip then ShowTip(self, self.label, tip) end
    end)
    b:SetScript("OnLeave", function(self)
        self:Paint()
        GameTooltip:Hide()
    end)
    b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function MakeCheck(parent, text, tip, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    b.box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.box:SetAllPoints()
    Skin(b.box, 0, 0.1, 0.12, 0.9, 0, 0.9, 1, 0.8)
    -- solid cyan fill when ON (always visible, no texture file needed)
    b.fill = b.box:CreateTexture(nil, "ARTWORK")
    b.fill:SetPoint("TOPLEFT", 3, -3)
    b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    b.fill:SetColorTexture(0, 0.9, 1, 1)
    b.check = b.box:CreateTexture(nil, "OVERLAY")
    b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    b.check:SetPoint("CENTER")
    b.check:SetSize(20, 20)
    b.check:SetVertexColor(1, 1, 1)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", b, "RIGHT", 5, 0)
    b.text:SetText(text .. "  |cff40ff80ON|r")
    b:SetHitRectInsets(0, -(b.text:GetStringWidth() + 12), 0, 0)
    function b:Update()
        local on = get() and true or false
        self.fill:SetShown(on)
        self.check:SetShown(on)
        self.box:SetBackdropBorderColor(0, 0.9, 1, on and 1 or 0.5)
        self.text:SetText(text .. "  " .. (on and "|cff40ff80ON|r" or "|cffff4040OFF|r"))
    end
    b:SetScript("OnClick", function(self)
        set(not get())
        self:Update()
        P(text .. ": " .. (get() and "|cff40ff80ON|r" or "|cffff4040OFF|r"))
    end)
    b:SetScript("OnEnter", function(self) ShowTip(self, text, tip) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function Header(parent, num, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 12, y)
    fs:SetText(CY .. num .. "|r  |cffffffff" .. text .. "|r")
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0, 0.9, 1, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y - 16)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y - 16)
    return fs
end

---------------------------------------------------------------
-- MAIN WINDOW
---------------------------------------------------------------
UI = CreateFrame("Frame", "SeviathsGuildHelperUI", UIParent, "BackdropTemplate")
UI:SetSize(640, 590)
UI:SetPoint("CENTER")
Skin(UI, 0.015, 0.035, 0.05, 0.96, 0, 0.9, 1, 0.9)
UI:SetMovable(true)
UI:SetClampedToScreen(true)
UI:EnableMouse(true)
UI:RegisterForDrag("LeftButton")
UI:SetScript("OnDragStart", UI.StartMoving)
UI:SetScript("OnDragStop", UI.StopMovingOrSizing)
UI:SetFrameStrata("HIGH")
UI:Hide()
tinsert(UISpecialFrames, "SeviathsGuildHelperUI")  -- ESC closes

-- title bar
UI.titleBg = UI:CreateTexture(nil, "ARTWORK")
UI.titleBg:SetPoint("TOPLEFT", 1, -1)
UI.titleBg:SetPoint("TOPRIGHT", -1, -1)
UI.titleBg:SetHeight(28)
UI.titleBg:SetColorTexture(0, 0.9, 1, 0.12)

UI.title = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
UI.title:SetPoint("TOPLEFT", 12, -7)
UI.title:SetText(CY .. "Seviaths|r|cffffffffGuildHelper|r  |cff5f8f99v" .. VERSION .. "|r")

UI.guildText = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.guildText:SetPoint("TOPRIGHT", -62, -10)

UI.closeBtn = MakeButton(UI, "X", 20, 20, nil, function() UI:Hide() end)
UI.closeBtn:SetPoint("TOPRIGHT", -5, -5)

UI.helpBtn = MakeButton(UI, "?", 20, 20, nil, nil)
UI.helpBtn:SetPoint("RIGHT", UI.closeBtn, "LEFT", -4, 0)
UI.helpBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0, 0.45, 0.55, 0.9)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine("How it works", 0, 0.9, 1)
    GameTooltip:AddLine("1. Write your message. <GUILD> becomes your guild name, <INFO> your Guild Info tab text, <NAME> the player's name.", 1, 1, 1, true)
    GameTooltip:AddLine("2. Pick a level range (and class if you want), then click Scan. Each click scans one range and selects the next one (Blizzard requires a click for every /who).", 1, 1, 1, true)
    GameTooltip:AddLine("3. Select a player and click Whisper + Next. If they answer any kind of yes within 10 minutes they get a guild invite automatically.", 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Not in a guild yet? Buy a Guild Charter from a Guild Master NPC. The window switches to Charter mode: whisper unguilded players, who says yes gets a group invite, then target them and click Ask target to sign.", 0.4, 1, 0.6, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Only players in zones and cities can be contacted. Dungeons, raids, delves, battlegrounds and arenas are skipped.", 0.7, 0.85, 0.9, true)
    GameTooltip:AddLine("Whispers and invites wait while you are in combat.", 0.7, 0.85, 0.9, true)
    GameTooltip:AddLine("Who was contacted / declined is shared with every officer using the addon.", 0.7, 0.85, 0.9, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("/gi  open   ·   /gi scan   ·   /gi sync   ·   /gi minimap   ·   /gi help", 0.5, 0.7, 0.75, true)
    GameTooltip:Show()
end)
UI.helpBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0.22, 0.27, 0.75); GameTooltip:Hide() end)

---------------------------------------------------------------
-- 1  MESSAGE
---------------------------------------------------------------
UI.h1 = Header(UI, "1", "Recruitment message", -38)

UI.msgBg = CreateFrame("Frame", nil, UI, "BackdropTemplate")
UI.msgBg:SetPoint("TOPLEFT", 12, -58)
UI.msgBg:SetPoint("TOPRIGHT", -12, -58)
UI.msgBg:SetHeight(50)
Skin(UI.msgBg, 0, 0, 0, 0.55, 0.2, 0.4, 0.45, 1)
UI.msgBg:EnableMouse(true)

UI.msgBox = CreateFrame("EditBox", nil, UI.msgBg)
UI.msgBox:SetPoint("TOPLEFT", 8, -6)
UI.msgBox:SetPoint("BOTTOMRIGHT", -8, 6)
UI.msgBox:SetWidth(600)
UI.msgBox:SetMultiLine(true)
UI.msgBox:SetMaxLetters(MAX_TEMPLATE)
UI.msgBox:SetFontObject("GameFontHighlight")
UI.msgBox:SetAutoFocus(false)
UI.msgBg:SetScript("OnMouseDown", function() UI.msgBox:SetFocus() end)
UI.msgBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
UI.msgBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
UI.msgBox:SetScript("OnEditFocusGained", function() UI.msgBg:SetBackdropBorderColor(0, 0.9, 1, 1) end)
UI.msgBox:SetScript("OnEditFocusLost", function() UI.msgBg:SetBackdropBorderColor(0.2, 0.4, 0.45, 1) end)
UI.msgBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput and DB then
        DB.settings[TemplateKey()] = (self:GetText() or ""):gsub("[\r\n]+", " ")
        if TemplateKey() == "message" then DB.settings.messageEdited = time() end
    end
    if UpdatePreview then UpdatePreview() end
end)

UI.placeholders = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.placeholders:SetPoint("TOPLEFT", UI.msgBg, "BOTTOMLEFT", 2, -6)
UI.placeholders:SetText(CY .. "<GUILD>|r guild name   " .. CY .. "<INFO>|r guild info tab   " .. CY .. "<NAME>|r their name")

UI.shareBtn = MakeButton(UI, "Share with officers", 130, 20,
    "Sends this message to every officer running the addon, so the whole guild uses the same pitch.",
    function()
        if not DB then return end
        if not IsInGuild() then P("You are not in a guild yet — sharing works once the guild exists.") return end
        DB.settings.messageTS = time()
        DB.settings.messageBy = Me()
        if BroadcastRecord then BroadcastRecord(nil, true) end
        P("Message shared with officers.")
        if UpdatePreview then UpdatePreview() end
    end)
UI.shareBtn:SetPoint("TOPRIGHT", UI.msgBg, "BOTTOMRIGHT", 0, -4)

UI.defaultBtn = MakeButton(UI, "Default text", 90, 20,
    "Restores the default message (recruiting or charter text, depending on the mode).",
    function()
        DB.settings[TemplateKey()] = DefaultTemplate()
        if TemplateKey() == "message" then DB.settings.messageEdited = time() end
        UI.msgBox:SetText(DefaultTemplate())
        UpdatePreview()
    end)
UI.defaultBtn:SetPoint("RIGHT", UI.shareBtn, "LEFT", -6, 0)

function UI.UseShared(auto)
    local st = DB and DB.settings
    local inc = st and st.incoming
    if not inc then return end
    st.message = inc.text
    st.messageTS = inc.ts
    st.messageBy = inc.by
    st.messageEdited = 0
    st.incoming = nil
    P((auto and "Recruitment message updated" or "Now using the message") .. " shared by officer " .. inc.by .. ".")
    if UI:IsShown() and not CharterMode() then UI.msgBox:SetText(st.message) end
    if UpdatePreview then UpdatePreview() end
end

UI.useSharedBtn = MakeButton(UI, "Use shared", 80, 20,
    "Another officer shared their message. Click to replace YOUR message with theirs. Nothing changes unless you click.",
    function() UI.UseShared(false) end)
UI.useSharedBtn:SetPoint("RIGHT", UI.defaultBtn, "LEFT", -6, 0)
UI.useSharedBtn:Hide()

UI.preview = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.preview:SetPoint("TOPLEFT", UI.msgBg, "BOTTOMLEFT", 2, -30)
UI.preview:SetPoint("TOPRIGHT", UI.msgBg, "BOTTOMRIGHT", -2, -30)
UI.preview:SetJustifyH("LEFT")
UI.preview:SetJustifyV("TOP")
UI.preview:SetWordWrap(true)
if UI.preview.SetMaxLines then UI.preview:SetMaxLines(3) end
UI.preview:SetHeight(36)

UpdatePreview = function()
    if not DB then return end
    local msg = BuildMessage(selected and selected.name or "Player")
    local parts = SplitMessage(msg)
    local extra = #parts > 1 and ("  |cffff9933(sent as " .. #parts .. " whispers)|r") or ""
    local by = ""
    local inc = DB.settings.incoming
    UI.useSharedBtn:SetShown(inc and not CharterMode() and inc.text ~= DB.settings.message or false)
    if inc and not CharterMode() and inc.text ~= DB.settings.message then
        by = "  |cffffd200" .. inc.by .. " shared a new message (Use shared)|r"
    elseif not CharterMode() and DB.settings.messageBy ~= "" and DB.settings.messageTS > 0 then
        by = "  |cff5f8f99shared by " .. DB.settings.messageBy .. " " .. TimeAgo(DB.settings.messageTS) .. "|r"
    end
    UI.preview:SetText("|cff5f8f99Preview (" .. #msg .. " chars):|r |cffd8f8ff" .. msg .. "|r" .. extra .. by)
end

---------------------------------------------------------------
-- 2  FIND PLAYERS
---------------------------------------------------------------
Header(UI, "2", "Find players", -176)

UI.classBtn = MakeButton(UI, "Class: Any", 120, 22,
    "Only search one class. Useful when a level range has more than 50 players.", nil)
UI.classBtn:SetPoint("TOPLEFT", 12, -196)

UI.bracketBtns = {}
for i, br in ipairs(BRACKETS) do
    local b = MakeButton(UI, br, 40, 22, "Select levels " .. br .. ", then press Scan.", function() SelectBracket(i) end)
    b:SetPoint("LEFT", UI.classBtn, "RIGHT", 6 + (i - 1) * 42, 0)
    UI.bracketBtns[i] = b
end

UI.scanBtn = MakeButton(UI, "Scan 1-10", 98, 22,
    "Searches players in the selected level range (and class). After the scan the next range is selected, so you can keep clicking Scan to go through all levels. 5s cooldown between scans.",
    function() ScanNext() end)
UI.scanBtn:SetPoint("LEFT", UI.bracketBtns[#BRACKETS], "RIGHT", 6, 0)
UI.scanBtn.text:SetFontObject("GameFontHighlight")
UpdateBracketButtons()

UI.scanInfo = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.scanInfo:SetPoint("TOPLEFT", 14, -224)
UI.scanInfo:SetPoint("TOPRIGHT", -14, -224)
UI.scanInfo:SetJustifyH("LEFT")
UI.scanInfo:SetText(lastScanText)

-- class dropdown
UI.classMenu = CreateFrame("Frame", nil, UI, "BackdropTemplate")
UI.classMenu:SetPoint("TOPLEFT", UI.classBtn, "BOTTOMLEFT", 0, -2)
UI.classMenu:SetFrameStrata("DIALOG")
Skin(UI.classMenu, 0.02, 0.05, 0.07, 0.98, 0, 0.9, 1, 0.9)
UI.classMenu:Hide()

local function SetClassFilter(c)
    selectedClass = c
    UI.classBtn:SetLabel(c and ("Class: " .. ClassText(c.name, c.token)) or "Class: Any")
    UI.classMenu:Hide()
end

local function BuildClassMenu()
    if UI.classMenu.built then return end
    UI.classMenu.built = true
    local entries = { { label = "Any class", value = nil } }
    for _, c in ipairs(CLASS_LIST) do entries[#entries + 1] = { label = ClassText(c.name, c.token), value = c } end
    for i, en in ipairs(entries) do
        local row = CreateFrame("Button", nil, UI.classMenu)
        row:SetSize(140, 18)
        row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 18)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0, 0.9, 1, 0.18)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetText(en.label)
        row:SetScript("OnClick", function() SetClassFilter(en.value) end)
    end
    UI.classMenu:SetSize(150, #entries * 18 + 10)
end

UI.classBtn:SetScript("OnClick", function()
    BuildClassMenu()
    UI.classMenu:SetShown(not UI.classMenu:IsShown())
end)

---------------------------------------------------------------
-- 3  PLAYER LIST
---------------------------------------------------------------
Header(UI, "3", "Contact players", -246)

UI.filterBtn = MakeButton(UI, "Show: All", 90, 18,
    "Toggle between every scanned player and only players you can contact now.",
    function()
        showReadyOnly = not showReadyOnly
        UI.filterBtn:SetLabel(showReadyOnly and "Show: Ready" or "Show: All")
        UI.offset = 0
        Refresh()
    end)
UI.filterBtn:SetPoint("TOPRIGHT", -12, -241)

UI.counts = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.counts:SetPoint("RIGHT", UI.filterBtn, "LEFT", -10, 0)

local COLUMNS = {
    { title = "Name",   x = 8,   w = 150 },
    { title = "Lvl",    x = 162, w = 30  },
    { title = "Class",  x = 196, w = 100 },
    { title = "Zone",   x = 300, w = 186 },
    { title = "Status", x = 490, w = 106 },
}

UI.listBg = CreateFrame("Frame", nil, UI, "BackdropTemplate")
UI.listBg:SetPoint("TOPLEFT", 12, -268)
UI.listBg:SetPoint("TOPRIGHT", -12, -268)
UI.listBg:SetHeight(ROW_H * VISIBLE_ROWS + 22)
Skin(UI.listBg, 0, 0, 0, 0.45, 0.2, 0.4, 0.45, 1)

for _, col in ipairs(COLUMNS) do
    local h = UI.listBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetPoint("TOPLEFT", col.x, -5)
    h:SetText(CY .. col.title .. "|r")
end
local headLine = UI.listBg:CreateTexture(nil, "ARTWORK")
headLine:SetColorTexture(0, 0.9, 1, 0.3)
headLine:SetHeight(1)
headLine:SetPoint("TOPLEFT", 1, -20)
headLine:SetPoint("TOPRIGHT", -1, -20)

UI.listFrame = CreateFrame("Frame", nil, UI.listBg)
UI.listFrame:SetPoint("TOPLEFT", 1, -21)
UI.listFrame:SetPoint("BOTTOMRIGHT", -14, 1)
UI.listFrame:EnableMouseWheel(true)

UI.hint = UI.listFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.hint:SetPoint("CENTER")
UI.hint:SetWidth(520)
UI.hint:SetJustifyH("CENTER")
UI.hint:SetText(CY .. "No players yet.|r\n\nPick a " .. CY .. "level range|r and click " .. CY .. "Scan|r.\nKeep clicking Scan to go through the next ranges.\nPick a " .. CY .. "Class|r first if you want one class only.")

UI.slider = CreateFrame("Slider", nil, UI.listBg)
UI.slider:SetOrientation("VERTICAL")
UI.slider:SetPoint("TOPRIGHT", -3, -23)
UI.slider:SetPoint("BOTTOMRIGHT", -3, 3)
UI.slider:SetWidth(8)
UI.slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
UI.slider:GetThumbTexture():SetVertexColor(0, 0.9, 1, 0.8)
UI.slider:GetThumbTexture():SetSize(8, 28)
UI.slider:SetMinMaxValues(0, 0)
UI.slider:SetValueStep(1)
UI.slider:SetValue(0)
UI.slider:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v + 0.5)
    if v ~= UI.offset then UI.offset = v; RenderRows() end
end)
UI.listFrame:SetScript("OnMouseWheel", function(_, delta)
    local _, max = UI.slider:GetMinMaxValues()
    local v = math.max(0, math.min(max, (UI.offset or 0) - delta * 3))
    UI.slider:SetValue(v)
end)

UI.offset = 0
UI.view = {}
UI.rows = {}

local function RowTooltip(row)
    local e = row.entry
    if not e then return end
    local st = GetStatus(e)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ClassText(e.name, e.token))
    GameTooltip:AddLine(("Level %s %s"):format(e.level or "?", e.class or ""), 1, 1, 1)
    GameTooltip:AddLine("Zone: " .. (e.area ~= "" and e.area or "?"), 0.8, 0.8, 0.8)
    if IsGuilded(e) then GameTooltip:AddLine("Guild: <" .. e.guild .. ">", 0.6, 0.6, 0.6) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|c" .. STATUS[st].color .. STATUS[st].label .. "|r")
    GameTooltip:AddLine(STATUS[st].tip, 0.8, 0.9, 0.95, true)
    local r = GetRecord(e.name)
    if r then
        local what = r.s == "D" and "Declined" or (r.s == "I" and "Invited" or "Whispered")
        GameTooltip:AddLine(what .. " " .. TimeAgo(r.t) .. (r.by ~= "" and (" by " .. r.by) or ""), 0.6, 0.75, 0.8)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: select   ·   Right-click: whisper", 0.5, 0.7, 0.75)
    GameTooltip:Show()
end

local WhisperSelected  -- defined with the action buttons

for i = 1, VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, UI.listFrame)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    row.sel = row:CreateTexture(nil, "BORDER")
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(0, 0.9, 1, 0.2)
    row.sel:Hide()
    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT")
    row.accent:SetPoint("BOTTOMLEFT")
    row.accent:SetWidth(3)
    row.accent:SetColorTexture(0, 0.9, 1, 1)
    row.accent:Hide()
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0, 0.9, 1, 0.08)
    row.cols = {}
    for c, col in ipairs(COLUMNS) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", col.x, 0)
        fs:SetWidth(col.w)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.cols[c] = fs
    end
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if not self.entry then return end
        selected = self.entry
        RenderRows()
        UpdatePreview()
        if button == "RightButton" then WhisperSelected() end
    end)
    row:SetScript("OnEnter", RowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.rows[i] = row
end

RenderRows = function()
    local view = UI.view
    for i, row in ipairs(UI.rows) do
        local e = view[(UI.offset or 0) + i]
        row.entry = e
        if e then
            local st = STATUS[e._st] or STATUS.ready
            local dim = e._st ~= "ready" and e._st ~= "pending"
            row.cols[1]:SetText(ClassText(StripRealm(e.name), e.token) .. (e.name:find("%-") and "|cff5f8f99*|r" or ""))
            row.cols[2]:SetText((dim and "|cff8a9aa0" or "|cffffffff") .. tostring(e.level or "?") .. "|r")
            row.cols[3]:SetText(ClassText(e.class, e.token))
            row.cols[4]:SetText((dim and "|cff8a9aa0" or "|cffd8f8ff") .. (e.area ~= "" and e.area or "?") .. "|r")
            row.cols[5]:SetText("|c" .. st.color .. st.label .. "|r")
            row:SetAlpha(dim and 0.65 or 1)
            local isSel = (e == selected)
            row.sel:SetShown(isSel)
            row.accent:SetShown(isSel)
            row:Show()
        else
            row:Hide()
        end
    end
end

Refresh = function()
    if not UI:IsShown() or not DB then return end
    local view = wipe(UI.view)
    local counts = { ready = 0, pending = 0, contacted = 0, invited = 0, declined = 0, guilded = 0, instance = 0, signed = 0 }
    for _, e in ipairs(scanned) do
        e._st = GetStatus(e)
        counts[e._st] = counts[e._st] + 1
        if not showReadyOnly or e._st == "ready" or e._st == "pending" then view[#view + 1] = e end
    end
    table.sort(view, function(a, b)
        local oa, ob = STATUS[a._st].order, STATUS[b._st].order
        if oa ~= ob then return oa < ob end
        local la, lb = tonumber(a.level) or 0, tonumber(b.level) or 0
        if la ~= lb then return la > lb end
        return a.name < b.name
    end)
    local max = math.max(0, #view - VISIBLE_ROWS)
    if UI.offset > max then UI.offset = max end
    UI.slider:SetMinMaxValues(0, max)
    UI.slider:SetShown(max > 0)
    UI.slider:SetValue(UI.offset)
    UI.hint:SetShown(#scanned == 0)
    UI.counts:SetText(("|cff00e5ff%d ready|r  ·  |cffffd200%d waiting|r  ·  |cff40ff80%d invited|r  ·  |cff8a9aa0%d skipped|r"):format(
        counts.ready, counts.pending, counts.invited + counts.signed,
        counts.contacted + counts.declined + counts.guilded + counts.instance))
    UI.scanInfo:SetText(lastScanText)
    RenderRows()
    UpdateStatus()
end

---------------------------------------------------------------
-- ACTION BAR
---------------------------------------------------------------
local function SelectNextReady(fromStart)
    local view = UI.view
    local startIdx = 0
    if selected and not fromStart then
        for i, e in ipairs(view) do if e == selected then startIdx = i break end end
    end
    for pass = 1, 2 do
        local a, b = (pass == 1) and startIdx + 1 or 1, (pass == 1) and #view or startIdx
        for i = a, b do
            if GetStatus(view[i]) == "ready" then
                selected = view[i]
                if i <= UI.offset then UI.offset = i - 1
                elseif i > UI.offset + VISIBLE_ROWS then UI.offset = i - VISIBLE_ROWS end
                UI.slider:SetValue(UI.offset)
                RenderRows()
                UpdatePreview()
                return true
            end
        end
    end
    return false
end

WhisperSelected = function()
    if not selected then
        if not SelectNextReady(true) then P("No players to whisper. Scan first.") return end
    end
    if SendPitch(selected) then
        P("Whisper sent to " .. ClassText(StripRealm(selected.name), selected.token) .. " — waiting 10 min for a yes.")
        Refresh()
        SelectNextReady()
    end
end

local barY = -268 - (ROW_H * VISIBLE_ROWS + 22) - 10

UI.whisperBtn = MakeButton(UI, "Whisper + Next", 130, 26,
    "Whispers the selected player your message and jumps to the next ready player. If they reply yes within 10 minutes they are invited automatically.",
    function() WhisperSelected() end)
UI.whisperBtn:SetPoint("TOPLEFT", 12, barY)
UI.whisperBtn.text:SetFontObject("GameFontHighlight")

UI.nextBtn = MakeButton(UI, "Select next ready", 120, 26,
    "Jumps to the next player you can contact.",
    function() if not SelectNextReady() then P("No ready players. Scan another level range.") end end)
UI.nextBtn:SetPoint("LEFT", UI.whisperBtn, "RIGHT", 6, 0)

UI.inviteBtn = MakeButton(UI, "Invite now", 90, 26,
    "Sends a guild invite to the selected player straight away, without a whisper.",
    function()
        if not selected then P("Select a player first.") return end
        if IsGuilded(selected) then P(StripRealm(selected.name) .. " is already in a guild.") return end
        if CharterMode() then GroupInvite(selected.name, "manual") else InvitePlayer(selected.name, "manual") end
    end)
UI.inviteBtn:SetPoint("LEFT", UI.nextBtn, "RIGHT", 6, 0)

UI.skipBtn = MakeButton(UI, "Skip forever", 90, 26,
    "Marks the selected player as declined. Nobody in the guild will contact them again.",
    function()
        if not selected then P("Select a player first.") return end
        SetRecord(selected.name, "D", time(), Me())
        pending[StripRealm(selected.name)] = nil
        P(StripRealm(selected.name) .. " will not be contacted again.")
        Refresh()
        SelectNextReady()
    end)
UI.skipBtn:SetPoint("LEFT", UI.inviteBtn, "RIGHT", 6, 0)

UI.autoCheck = MakeCheck(UI, "Auto-invite on yes",
    "When a whispered player answers yes, ok, sure, inv pls... within 10 minutes, the guild invite is sent automatically.",
    function() return DB and DB.settings.autoInvite end,
    function(v) DB.settings.autoInvite = v end)
UI.autoCheck:SetPoint("TOPLEFT", UI.skipBtn, "TOPRIGHT", 14, -1)

UI.syncCheck = MakeCheck(UI, "Auto-use officers' msg",
    "OFF: your message is never changed — a shared message only waits behind the Use shared button.\nON: a shared message replaces yours, but only if you haven't edited your own since.",
    function() return DB and DB.settings.syncMessage end,
    function(v) DB.settings.syncMessage = v end)
UI.syncCheck:SetPoint("TOPLEFT", UI.autoCheck, "BOTTOMLEFT", 0, -3)

---------------------------------------------------------------
-- CHARTER PANEL (only while you are not in a guild)
---------------------------------------------------------------
local NORMAL_H, CHARTER_H = 590, 664

UI.charter = CreateFrame("Frame", nil, UI, "BackdropTemplate")
UI.charter:SetPoint("TOPLEFT", 12, barY - 46)
UI.charter:SetPoint("TOPRIGHT", -12, barY - 46)
UI.charter:SetHeight(50)
Skin(UI.charter, 0, 0.12, 0.15, 0.85, 0, 0.9, 1, 0.9)
UI.charter:Hide()

UI.charter.icon = UI.charter:CreateTexture(nil, "ARTWORK")
UI.charter.icon:SetSize(34, 34)
UI.charter.icon:SetPoint("LEFT", 8, 0)
UI.charter.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
UI.charter.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

UI.charter.title = UI.charter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.charter.title:SetPoint("TOPLEFT", UI.charter.icon, "TOPRIGHT", 8, -1)
UI.charter.title:SetJustifyH("LEFT")

UI.charter.info = UI.charter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.charter.info:SetPoint("TOPLEFT", UI.charter.title, "BOTTOMLEFT", 0, -4)
UI.charter.info:SetWidth(360)
UI.charter.info:SetJustifyH("LEFT")
UI.charter.info:SetWordWrap(false)

UI.charter.pips = {}
for i = 1, 9 do
    local pip = CreateFrame("Frame", nil, UI.charter, "BackdropTemplate")
    pip:SetSize(12, 12)
    Skin(pip, 0, 0.1, 0.12, 0.9, 0, 0.9, 1, 0.8)
    pip.fill = pip:CreateTexture(nil, "ARTWORK")
    pip.fill:SetPoint("TOPLEFT", 2, -2)
    pip.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    pip.fill:SetColorTexture(0.25, 1, 0.5, 1)
    UI.charter.pips[i] = pip
end

UI.charter.askBtn = MakeButton(UI.charter, "Ask target to sign", 130, 24,
    "Target the player, open your Guild Charter (right-click it in your bags), then click this. They get a pop-up to sign.",
    function()
        if not HasCharterItem() then P("You have no Guild Charter. Buy one from a Guild Master NPC in a capital city.") return end
        if not UnitExists("target") or not UnitIsPlayer("target") then P("Target the player who should sign first.") return end
        local tname = UnitName("target")
        if GetGuildInfo("target") then P(tname .. " is in a guild — only players without a guild can sign.") return end
        if not petitionOpen then
            P("Open your charter first: |cff00e5ffright-click the Guild Charter in your bags|r, then click this button again.")
            return
        end
        if OfferPetition then
            OfferPetition()
            P("Signature request sent to " .. CY .. tname .. "|r.")
        end
    end)
UI.charter.askBtn:SetPoint("RIGHT", -8, 0)

local function UpdateCharter()
    if not CharterMode() then return end
    local c = Charter()
    local have = HasCharterItem()
    local n, need = #c.sigs, math.max(1, math.min(9, c.min or 4))
    for i, pip in ipairs(UI.charter.pips) do
        if i <= need then
            pip:ClearAllPoints()
            pip:SetPoint("TOPRIGHT", UI.charter.askBtn, "TOPLEFT", -12 - (need - i) * 15, -6)
            pip.fill:SetShown(i <= n)
            pip:Show()
        else
            pip:Hide()
        end
    end
    UI.charter.askBtn:SetShown(have and n < need)
    if not have then
        UI.charter.title:SetText("|cffff9933No Guild Charter in your bags|r")
        UI.charter.info:SetText("Buy one from a |cff00e5ffGuild Master|r NPC in any capital city (10 silver), name your guild, then come back here.")
        for _, pip in ipairs(UI.charter.pips) do pip:Hide() end
    elseif n >= need then
        UI.charter.title:SetText(CY .. "Guild Charter:|r |cffffffff" .. (c.title ~= "" and c.title or "your guild") .. "|r  |cff40ff80" .. n .. "/" .. need .. " — complete!|r")
        UI.charter.info:SetText("|cff40ff80Bring the charter to a Guild Master NPC in a city and turn it in to create the guild.|r")
    else
        UI.charter.title:SetText(CY .. "Guild Charter:|r |cffffffff" .. (c.title ~= "" and c.title or "(right-click it once so I can read its name)") .. "|r  " .. n .. "/" .. need .. " signatures")
        local names = {}
        for _, sname in ipairs(c.sigs) do names[#names + 1] = StripRealm(sname) end
        UI.charter.info:SetText(#names > 0 and ("|cff40ff80Signed:|r " .. table.concat(names, ", ") .. "  |cff8fb8c0— need " .. (need - n) .. " more|r")
            or "|cff8fb8c0Whisper players without a guild. Who says yes gets a group invite, then target them and click Ask target to sign.|r")
    end
end

local lastMode
local function ApplyMode(force)
    local cm = CharterMode()
    if cm ~= lastMode or force then
        lastMode = cm
        if not InCombatLockdown() then UI:SetHeight(cm and CHARTER_H or NORMAL_H) end
        UI.charter:SetShown(cm)
        UI.h1:SetText(CY .. "1|r  |cffffffff" .. (cm and "Charter message  |cff8fb8c0(asks unguilded players to sign)|r" or "Recruitment message") .. "|r")
        UI.placeholders:SetText(cm
            and (CY .. "<GUILD>|r charter name   " .. CY .. "<ZONE>|r your zone   " .. CY .. "<NAME>|r their name")
            or  (CY .. "<GUILD>|r guild name   " .. CY .. "<INFO>|r guild info tab   " .. CY .. "<NAME>|r their name"))
        UI.shareBtn:SetShown(not cm)
        UI.inviteBtn:SetLabel(cm and "Group invite" or "Invite now")
        if DB and UI:IsShown() then UI.msgBox:SetText(DB.settings[TemplateKey()] or DefaultTemplate()) end
    end
    UpdateCharter()
end
UI.ApplyMode = ApplyMode

UI.statusBar = UI:CreateTexture(nil, "ARTWORK")
UI.statusBar:SetPoint("BOTTOMLEFT", 1, 1)
UI.statusBar:SetPoint("BOTTOMRIGHT", -1, 1)
UI.statusBar:SetHeight(22)
UI.statusBar:SetColorTexture(0, 0.9, 1, 0.08)

UI.status = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.status:SetPoint("BOTTOMLEFT", 12, 6)
UI.status:SetPoint("BOTTOMRIGHT", -12, 6)
UI.status:SetJustifyH("LEFT")

UpdateStatus = function()
    if not UI or not UI.status then return end
    local guild = GetGuildInfo("player")
    if CharterMode() then
        UI.guildText:SetText(HasCharterItem() and (CY .. "Charter mode|r") or "|cffff4040Not in a guild|r")
    elseif not IsInGuild() or not guild then
        UI.guildText:SetText("|cffff4040Not in a guild|r")
    elseif CanGuildInvite and not CanGuildInvite() then
        UI.guildText:SetText(CY .. "<" .. guild .. ">|r |cffff9933no invite rights|r")
    else
        UI.guildText:SetText(CY .. "<" .. guild .. ">|r")
    end
    local ok, err = CanContactNow()
    local text
    if not ok then
        text = "|cffff4040" .. err .. "|r"
    elseif InCombat() then
        text = "|cffff9933In combat — whispers and invites are paused" .. (#queue > 0 and (" (" .. #queue .. " waiting)") or "") .. ". They continue when combat ends.|r"
    elseif #queue > 0 then
        text = CY .. "Sending... " .. #queue .. " queued.|r"
    else
        local np = 0
        for _ in pairs(pending) do np = np + 1 end
        text = "|cff8fb8c0Ready.|r " .. (np > 0 and ("|cffffd200" .. np .. " player(s) have 10 min to answer.|r ") or "")
            .. "|cff5f8f99Only players in zones & cities are contacted.|r"
    end
    UI.status:SetText(text)
end

UI:SetScript("OnShow", function()
    ApplyMode(true)
    if DB then UI.msgBox:SetText(DB.settings[TemplateKey()] or DefaultTemplate()) end
    UI.autoCheck:Update()
    UI.syncCheck:Update()
    NoteMyZone()
    UpdatePreview()
    Refresh()
end)
UI:SetScript("OnHide", function() UI.classMenu:Hide() end)

ToggleUI = function()
    if not DB then return end
    if UI:IsShown() then UI:Hide() else UI:Show() end
end

-- Addon Compartment (the addon list button under the minimap)
function SeviathsGuildHelper_OnCompartmentClick() ToggleUI() end
function SeviathsGuildHelper_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine(CY .. "Seviaths|rGuildHelper")
    GameTooltip:AddLine("Click to open", 1, 1, 1)
    GameTooltip:Show()
end
function SeviathsGuildHelper_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------
-- MINIMAP BUTTON
---------------------------------------------------------------
local miniBtn = CreateFrame("Button", "SeviathsGuildHelperMinimapButton", Minimap)
miniBtn:SetSize(31, 31)
miniBtn:SetFrameStrata("MEDIUM")
miniBtn:SetFrameLevel(8)
miniBtn:RegisterForClicks("AnyUp")
miniBtn:RegisterForDrag("LeftButton")
miniBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local miniBack = miniBtn:CreateTexture(nil, "BACKGROUND")
miniBack:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
miniBack:SetSize(20, 20)
miniBack:SetPoint("TOPLEFT", 7, -5)

local miniIcon = miniBtn:CreateTexture(nil, "ARTWORK")
miniIcon:SetTexture("Interface\\Icons\\INV_Shirt_GuildTabard_01")
miniIcon:SetSize(18, 18)
miniIcon:SetPoint("TOPLEFT", 7, -6)
miniIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local miniBorder = miniBtn:CreateTexture(nil, "OVERLAY")
miniBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
miniBorder:SetSize(50, 50)
miniBorder:SetPoint("TOPLEFT")
miniBorder:SetVertexColor(0.55, 1, 1)

local function UpdateMiniPos()
    local angle = math.rad(DB and DB.settings.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    miniBtn:ClearAllPoints()
    miniBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

miniBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        DB.settings.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
        UpdateMiniPos()
    end)
end)
miniBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    DB.settings.minimap.moved = true
end)
miniBtn:SetScript("OnClick", function() ToggleUI() end)
miniBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(CY .. "Seviaths|rGuildHelper")
    GameTooltip:AddLine("Click: open / close", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("/gi minimap: hide / show", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)
miniBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
miniBtn:Hide()

-- Never sit on top of another addon's minimap button (e.g. SeviathsUsefulTools).
-- Until you drag it yourself, the button rotates to the first free spot.
local function OverlapsOtherButton()
    local mx, my = miniBtn:GetCenter()
    if not mx then return false end
    for _, child in ipairs({ Minimap:GetChildren() }) do
        if child ~= miniBtn and child:IsShown() and child.GetCenter then
            local w, h = child:GetWidth() or 0, child:GetHeight() or 0
            if w > 10 and w < 50 and h > 10 and h < 50 then
                local cx, cy = child:GetCenter()
                if cx and math.abs(cx - mx) < 22 and math.abs(cy - my) < 22 then return true end
            end
        end
    end
    return false
end

local function FindFreeSpot()
    local mm = DB.settings.minimap
    if mm.moved then return end
    for _ = 1, 24 do
        UpdateMiniPos()
        if not OverlapsOtherButton() then return end
        mm.angle = (mm.angle + 15) % 360
    end
end

local function ApplyMinimap()
    if DB.settings.minimap.hide then miniBtn:Hide() return end
    UpdateMiniPos()
    miniBtn:Show()
    FindFreeSpot()
end

---------------------------------------------------------------
-- SETTINGS PANEL (Esc > Options > AddOns)
---------------------------------------------------------------
if Settings and Settings.RegisterCanvasLayoutCategory then
    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(panel, "SeviathsGuildHelper")
    Settings.RegisterAddOnCategory(category)
    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 20, -20)
    t:SetText(CY .. "Seviaths|rGuildHelper v" .. VERSION)
    local open = MakeButton(panel, "Open window", 140, 24, nil, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if not UI:IsShown() then ToggleUI() end
    end)
    open:SetPoint("TOPLEFT", 20, -52)
    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 20, -90)
    info:SetJustifyH("LEFT")
    info:SetText("/gi or the minimap button opens the window.\n\n" ..
        "Players who say yes within 10 minutes are invited automatically.\n" ..
        "Only players in zones and cities are contacted (no dungeons, raids, delves, PvP).\n" ..
        "Whispers and invites wait while you are in combat.\n" ..
        "A player is contacted at most once per 6 months; declines are permanent.\n" ..
        "History and the shared message sync between officers using the addon.")
end

---------------------------------------------------------------
-- OFFICER SYNC (guild addon messages)
---------------------------------------------------------------
local PREFIX = "SGHv2"
local addonQueue, addonBusy = {}, false
local lastReplyTo = {}

local function PumpAddon()
    if #addonQueue == 0 then addonBusy = false return end
    local m = table.remove(addonQueue, 1)
    if IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, m[1], m[2], m[3])
    end
    C_Timer.After(1.0, PumpAddon)
end

local function QueueAddon(msg, channel, target)
    addonQueue[#addonQueue + 1] = { msg, channel, target }
    if not addonBusy then addonBusy = true; PumpAddon() end
end

local function EncodeRecord(name, r)
    return r.s .. "," .. name .. "," .. (r.t or 0) .. "," .. (r.by or "")
end

local function TemplatePayload()
    local s = DB.settings
    return "T" .. s.messageTS .. "," .. (s.messageBy or "") .. "," .. (s.message or "")
end

-- BroadcastRecord(name)        -> one record to the guild
-- BroadcastRecord(nil, true)   -> the shared message
BroadcastRecord = function(name, template)
    if not DB or not IsInGuild() then return end
    if template then QueueAddon(TemplatePayload(), "GUILD") return end
    local r = DB.records[name]
    if r then QueueAddon("R" .. EncodeRecord(name, r), "GUILD") end
end

local function SendRecordsTo(target, since)
    local chunks, cur = {}, ""
    for name, r in pairs(DB.records) do
        if (r.t or 0) >= since then
            local enc = EncodeRecord(name, r)
            if #cur + #enc + 1 > 240 then chunks[#chunks + 1] = cur; cur = "" end
            cur = (cur == "") and enc or (cur .. ";" .. enc)
        end
    end
    if cur ~= "" then chunks[#chunks + 1] = cur end
    for _, c in ipairs(chunks) do QueueAddon("P" .. c, "WHISPER", target) end
    if DB.settings.messageTS > 0 then QueueAddon(TemplatePayload(), "WHISPER", target) end
end

local function MergeOne(enc)
    local s, name, ts, by = enc:match("^(%a),([^,]+),(%d+),([^,]*)$")
    if s and (s == "M" or s == "I" or s == "D") then
        return SetRecord(name, s, tonumber(ts), by, true)
    end
    return false
end

local function RequestSync(full)
    if not IsInGuild() then return end
    local since = full and 0 or math.max(0, (DB.lastOnline or 0) - 86400)
    QueueAddon("Q" .. since, "GUILD")
end

local function HandleAddon(prefix, msg, channel, sender)
    if prefix ~= PREFIX or not msg or not sender then return end
    if IsSecret(msg) or IsSecret(sender) then return end
    if StripRealm(sender) == Me() then return end
    local cmd, rest = msg:sub(1, 1), msg:sub(2)
    if cmd == "Q" then
        local now = GetTime()
        if lastReplyTo[sender] and now - lastReplyTo[sender] < 60 then return end
        lastReplyTo[sender] = now
        local since = tonumber(rest) or 0
        C_Timer.After(2 + math.random() * 4, function() SendRecordsTo(sender, since) end)
    elseif cmd == "P" then
        local n = 0
        for enc in rest:gmatch("[^;]+") do if MergeOne(enc) then n = n + 1 end end
        if n > 0 then
            P("Synced " .. n .. " record(s) from " .. StripRealm(sender) .. ".")
            Refresh()
        end
    elseif cmd == "R" then
        if MergeOne(rest) then Refresh() end
    elseif cmd == "T" then
        local ts, by, text = rest:match("^(%d+),([^,]*),(.*)$")
        ts = tonumber(ts)
        local st = DB.settings
        if ts and text and text ~= "" and ts > st.messageTS and text ~= st.message then
            local who = (by ~= "" and by) or StripRealm(sender)
            local seen = st.incoming and st.incoming.ts == ts
            st.incoming = { text = text:sub(1, MAX_TEMPLATE), ts = ts, by = who }
            if st.syncMessage and (st.messageEdited or 0) <= st.messageTS then
                UI.UseShared(true)
            elseif not seen then
                P("Officer " .. who .. " shared a new message. Yours is kept — click |cff00e5ffUse shared|r in the window if you want theirs.")
            end
            if UI:IsShown() then UpdatePreview() end
        end
    end
end

---------------------------------------------------------------
-- SLASH COMMANDS
---------------------------------------------------------------
SLASH_SEVIATHSGUILDHELPER1 = "/gi"
SLASH_SEVIATHSGUILDHELPER2 = "/sgh"
SLASH_SEVIATHSGUILDHELPER3 = "/guildhelper"
SlashCmdList["SEVIATHSGUILDHELPER"] = function(msg)
    if not DB then P("Still loading, try again in a second.") return end
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "show" or cmd == "open" then
        ToggleUI()
    elseif cmd == "scan" then
        if not UI:IsShown() then UI:Show() end
        ScanNext()
    elseif cmd == "sync" then
        RequestSync(true)
        P("Asked online officers for the full history.")
    elseif cmd == "minimap" then
        DB.settings.minimap.hide = not DB.settings.minimap.hide
        ApplyMinimap()
        P("Minimap button " .. (DB.settings.minimap.hide and "hidden" or "shown") .. ".")
    elseif cmd == "reset" then
        UI:ClearAllPoints(); UI:SetPoint("CENTER")
        DB.settings.minimap.angle = 200; DB.settings.minimap.hide = false; DB.settings.minimap.moved = false
        ApplyMinimap()
        P("Window and minimap button position reset.")
    elseif cmd == "forget" and arg ~= "" then
        DB.records[StripRealm(arg)] = nil
        P("Forgot " .. arg .. " (on this account only).")
        Refresh()
    else
        P("Commands:")
        print("  " .. CY .. "/gi|r — open / close the window")
        print("  " .. CY .. "/gi scan|r — scan the next level range")
        print("  " .. CY .. "/gi sync|r — get the full history from online officers")
        print("  " .. CY .. "/gi minimap|r — hide / show the minimap button")
        print("  " .. CY .. "/gi reset|r — reset window and minimap button position")
        print("  " .. CY .. "/gi forget Name|r — remove a player from your history")
    end
end

---------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------
local SIGNED_PATTERNS = {}
for _, gs in ipairs({ _G.ERR_PETITION_SIGNED_S, _G.PETITION_SIGNED, _G.ERR_PETITION_SIGNED }) do
    if type(gs) == "string" and gs:find("%%s") then
        local esc = gs:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        local pat = "^" .. esc:gsub("%%s", "(.+)") .. "$"
        SIGNED_PATTERNS[#SIGNED_PATTERNS + 1] = pat
    end
end
SIGNED_PATTERNS[#SIGNED_PATTERNS + 1] = "^(.-) has signed your"

local function ReadPetition()
    if not GetPetitionInfo then return end
    local ptype, title, _, maxSigs, _, isOriginator, minSigs = GetPetitionInfo()
    if ptype ~= "guild" or not isOriginator then return end
    local c = Charter()
    c.title = title or c.title
    c.min = tonumber(minSigs) or c.min or 4
    c.max = maxSigs
    wipe(c.sigs)
    for i = 1, (GetNumPetitionNames() or 0) do
        local n = GetPetitionNameInfo(i)
        if n then c.sigs[#c.sigs + 1] = n end
    end
end

local function OnCharterSigned(name)
    if not name or CharterSigned(name) then return end
    local c = Charter()
    c.sigs[#c.sigs + 1] = name
    P(CY .. StripRealm(name) .. "|r signed your charter! (" .. #c.sigs .. "/" .. (c.min or 4) .. ")")
    if #c.sigs >= (c.min or 4) then
        P("|cff40ff80Charter complete!|r Bring it to a Guild Master NPC in a capital city and turn it in to create your guild.")
    end
    if Refresh then Refresh() end
    if UI.ApplyMode then UI.ApplyMode() end
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "ADDON_LOADED")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
pcall(ev.RegisterEvent, ev, "ZONE_CHANGED_NEW_AREA")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGOUT")
pcall(ev.RegisterEvent, ev, "CHAT_MSG_WHISPER")
pcall(ev.RegisterEvent, ev, "CHAT_MSG_ADDON")
pcall(ev.RegisterEvent, ev, "WHO_LIST_UPDATE")
pcall(ev.RegisterEvent, ev, "PLAYER_GUILD_UPDATE")
pcall(ev.RegisterEvent, ev, "GUILD_ROSTER_UPDATE")
pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_DISABLED")
pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
pcall(ev.RegisterEvent, ev, "PETITION_SHOW")
pcall(ev.RegisterEvent, ev, "PETITION_CLOSED")
pcall(ev.RegisterEvent, ev, "CHAT_MSG_SYSTEM")
pcall(ev.RegisterEvent, ev, "BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then InitDB() end
    elseif event == "PLAYER_LOGIN" then
        if not DB then InitDB() end
        BuildClassList()
        ApplyMinimap()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        -- print(CY .. "SeviathsGuildHelper|r v" .. VERSION .. " loaded — type " .. CY .. "/gi|r or click the minimap button.")
        if not IsInGuild() then
            C_Timer.After(3, function()
                if IsInGuild() then return end
                if HasCharterItem() then
                    P("You have a Guild Charter — /gi opens |cff00e5ffCharter mode|r to collect signatures.")
                else
                    P("You are not in a guild. Buy a Guild Charter from a Guild Master NPC and /gi will help you collect signatures.")
                end
            end)
        end
        C_Timer.After(8, function() RequestSync(false) end)
        C_Timer.NewTicker(300, function() DB.lastOnline = time() end)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(2, function()
            if not zonesBuilt then BuildZones() end
            NoteMyZone()
            ApplyMinimap()
        end)
    elseif event == "PLAYER_LOGOUT" then
        if DB then DB.lastOnline = time() end
    elseif event == "CHAT_MSG_WHISPER" then
        local text, sender = ...
        HandleWhisper(text, sender)
    elseif event == "CHAT_MSG_ADDON" then
        HandleAddon(...)
    elseif event == "WHO_LIST_UPDATE" then
        OnWhoResults()
    elseif event == "PLAYER_REGEN_DISABLED" then
        UpdateStatus()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ResumeQueue()
        UpdateStatus()
    elseif event == "PETITION_SHOW" then
        petitionOpen = true
        ReadPetition()
        if UI:IsShown() then UI.ApplyMode(); Refresh() end
    elseif event == "PETITION_CLOSED" then
        petitionOpen = false
    elseif event == "CHAT_MSG_SYSTEM" then
        local text = ...
        if CharterMode() and type(text) == "string" and not IsSecret(text) then
            for _, pat in ipairs(SIGNED_PATTERNS) do
                local who = text:match(pat)
                if who then OnCharterSigned(who) break end
            end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if UI:IsShown() and CharterMode() then UI.ApplyMode(); UpdateStatus() end
    elseif event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
        if IsInGuild() and SeviathsGuildHelperCharDB and SeviathsGuildHelperCharDB.charter
            and #SeviathsGuildHelperCharDB.charter.sigs > 0 and event == "PLAYER_GUILD_UPDATE" then
            SeviathsGuildHelperCharDB.charter = nil
            P("|cff40ff80Guild created — congratulations!|r Switched to recruiting mode.")
        end
        if UI:IsShown() then UI.ApplyMode(); UpdateStatus(); UpdatePreview() end
    end
end)
