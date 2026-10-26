-- Seviath's Dungeons & Raids - Core
local ADDON, ns = SFP_Module("DungeonsRaids")

ns.VERSION = "1.12.4"
ns.CYAN = { 0.2, 0.9, 1.0 }
ns.CYAN_HEX = "33e6ff"

local defaults = {
  enabled = true,          -- master switch for list filtering
  annotate = true,         -- extra tags on listings, tooltips and applicants
  favoritesFirst = true,   -- favorites / friends / useful groups sorted to the top
  ratePrompt = true,       -- ask to rate the group after leaving it
  rateMinMinutes = 5,
  inviteSound = true,
  showPending = true,      -- pending applications panel
  useTemplates = true,
  roleOverride = "AUTO",   -- AUTO, TANK, HEALER, DAMAGER
  hideAboveMyLevel = true, -- hide activities your character is too low for
  maxAgeMinutes = 0,       -- hide groups listed longer than this (0 = off)
  scanLoot = true,         -- check dungeon/raid loot for mounts, pets, toys, appearances you lack
  dock = "BOTTOM",         -- window docks next to Premade Groups: BOTTOM, RIGHT or OFF
  autoOpen = true,         -- open docked window whenever Premade Groups opens
  minimap = { show = false, angle = 215 }, -- merged into the Farm Pack: opened from its minimap menu
  mplus = {
    enabled = true, needMyRole = true, hideSameClass = false, hideFull = true,
    requireLust = false, requireBrez = false, hideBlocked = true,
    minLeaderScore = 0, minLeaderBestLevel = 0,
    minTimedLevel = 0, maxTimedLevel = 0,   -- leader's best TIMED key in that dungeon
    picked = {}, known = {},                 -- keys (M+ dungeons) you ticked / all of them
  },
  dungeon = {
    enabled = true, diffN = true, diffH = true, diffM = true,
    needMyRole = true, hideSameClass = false, hideFull = true,
    hideAboveMyIlvl = true, hideBlocked = true, minNewLoot = 0, freshOnly = false,
    wantMount = false, wantPet = false, wantToy = false, wantTmog = false,
    picked = {}, known = {},   -- dungeons you ticked / every dungeon seen
  },
  raid = {
    enabled = true, diffN = true, diffH = true, diffM = true,
    showCurrent = true, showLegacy = true,
    needMyRole = true, freshOnly = false, hideFull = true,
    hideAboveMyIlvl = true, hideBlocked = true, highlightMyBuff = true,
    maxKilled = 99, minLootable = 0, minMembers = 0, maxMembers = 30, maxSameToken = 99,
    minNewLoot = 0,
    wantMount = false, wantPet = false, wantToy = false, wantTmog = false,
    picked = {}, known = {},   -- raids you ticked / every raid seen
  },
  delve = {
    enabled = true, hideFull = true, autoAcceptOnly = false, hideBlocked = true,
    minMembers = 0, maxMembers = 5, minTier = 0, maxTier = 0,
    picked = {}, known = {},   -- delves you ticked / every delve seen
  },
  quest = {
    enabled = true, onMyQuests = false, myZoneOnly = false, hideFull = true,
    autoAcceptOnly = false, hideBlocked = true, hideCompleted = true,
    showWQ = true, showQuests = true, showOther = true,
    picked = {}, known = {},   -- zones you ticked / every questing zone seen
  },
  custom = {
    enabled = true, needMyRole = false, hideFull = true, autoAcceptOnly = false,
    hideAboveMyIlvl = true, hideBlocked = true, minMembers = 0, maxMembers = 0,
    showPvE = true, showPvP = true, showWarModeOn = true, showWarModeOff = true,
  },
  templates = {
    mplus = "", dungeon = "", raidN = "", raidH = "", raidM = "",
    delve = "", quest = "", custom = "",
  },
  players = {},
}

local function CopyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local handlers = {}

function ns:On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    pcall(ev.RegisterEvent, ev, event) -- unknown events (renamed in a patch) are skipped
  end
  table.insert(handlers[event], fn)
end

ev:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
  end
end)

---------------------------------------------------------------------------
-- Hooks into Blizzard's group finder (it can load late, so we retry)
---------------------------------------------------------------------------
local hookRequests, hooked, readyCallbacks = {}, {}, {}

function ns:RequestHook(fname, fn)
  table.insert(hookRequests, { fname, fn })
end

-- fn returns true once it has done its job
function ns:WhenReady(fn)
  table.insert(readyCallbacks, fn)
end

function ns:TryHooks()
  for _, h in ipairs(hookRequests) do
    local fname, fn = h[1], h[2]
    if not hooked[fname] and type(_G[fname]) == "function" then
      hooksecurefunc(fname, fn)
      hooked[fname] = true
    end
  end
  for i = #readyCallbacks, 1, -1 do
    local ok, done = pcall(readyCallbacks[i])
    if ok and done then table.remove(readyCallbacks, i) end
  end
end

---------------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------------
function ns.Print(msg)
  print("|cff" .. ns.CYAN_HEX .. "Seviath's Dungeons & Raids:|r " .. tostring(msg))
end

-- Midnight "secret values" can't be compared or stored; treat them as unknown.
function ns.Safe(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

function ns.FullName(name)
  name = ns.Safe(name)
  if type(name) ~= "string" or name == "" then return nil end
  if not name:find("-", 1, true) then
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if realm and realm ~= "" then name = name .. "-" .. realm end
  end
  return name
end

function ns.ShortName(full)
  return (full and full:match("^([^-]+)")) or full or "?"
end

function ns.ClassHex(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c and c.colorStr then return c.colorStr end
  return "ffffffff"
end

function ns.MyClass()
  local _, class = UnitClass("player")
  return class
end

function ns.MyIlvl()
  local _, equipped = GetAverageItemLevel()
  return equipped or 0
end

function ns.MyRole()
  local o = ns.db and ns.db.roleOverride
  if o and o ~= "AUTO" then return o end
  local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
  local getRole = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole) or GetSpecializationRole
  local spec = getSpec and getSpec()
  local role = spec and getRole and getRole(spec)
  return role or "DAMAGER"
end

function ns.GroupUnits()
  local units = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
  else
    units[1] = "player"
    for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
  end
  return units
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
ns:On("ADDON_LOADED", function(name)
  if name == ADDON then
    SeviathsDungeonsRaidsDB = SeviathsDungeonsRaidsDB or {}
    CopyDefaults(defaults, SeviathsDungeonsRaidsDB)
    ns.db = SeviathsDungeonsRaidsDB
    -- v1.0.0 hid every legacy raid below max level; that option is gone
    ns.db.raid.currentOnly = nil
    -- v1.11.0: "legacy mount only" became the Mount box in "Only groups with new"
    if ns.db.raid.legacyMountOnly then ns.db.raid.wantMount = true end
    ns.db.raid.legacyMountOnly = nil
    -- v1.4.0: dock below by default
    if (ns.db.layoutVersion or 0) < 2 then
      ns.db.dock = "BOTTOM"
      ns.db.layoutVersion = 2
    end
  end
  if ns.db then ns:TryHooks() end
end)

ns:On("PLAYER_LOGIN", function()
  ns:TryHooks()
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_SEVIATHSDUNGEONSRAIDS1 = "/sdr"
SlashCmdList.SEVIATHSDUNGEONSRAIDS = function(msg)
  msg = strtrim(msg or "")
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    ns.UI:Toggle()
  elseif cmd == "tag" then
    local name, tag, note = rest:match("^(%S+)%s+(%S+)%s*(.-)$")
    tag = tag and tag:lower()
    if not name or not (tag == "clear" or ns.TAGS[tag]) then
      ns.Print("Usage: /sdr tag Name-Realm fav|good|bad|left|toxic|block|clear [note]")
      return
    end
    local full = ns.FullName(name)
    if tag == "clear" then
      ns:SetTag(full, nil)
      ns.Print("Cleared tag for " .. full)
    else
      ns:SetTag(full, tag, note)
      ns.Print(full .. " tagged " .. ns.TAGS[tag].label)
    end
  elseif cmd == "rate" then
    ns:ShowLastRate()
  elseif cmd == "comp" then
    ns.UI:Show("group")
  elseif cmd == "minimap" then
    ns.db.minimap.show = not ns.db.minimap.show
    ns.UI:UpdateMinimap()
  else
    ns.Print("/sdr - open window, /sdr tag Name-Realm <tag> [note], /sdr rate, /sdr comp, /sdr minimap")
  end
end
