-- Seviath's Dungeons & Raids - player history, tags, rating after a group
local _, ns = SFP_Module("DungeonsRaids")

ns.TAGS = {
  fav   = { label = "Favorite",   short = "FAV",   color = "33e6ff" },
  good  = { label = "Good run",   short = "GOOD",  color = "40ff60" },
  bad   = { label = "Failed run", short = "FAIL",  color = "ffd040" },
  left  = { label = "Left early", short = "LEFT",  color = "ff9040" },
  toxic = { label = "Toxic",      short = "TOXIC", color = "ff4040" },
  block = { label = "Blocked",    short = "BLOCK", color = "ff2020" },
}
ns.TAG_ORDER = { "fav", "good", "bad", "left", "toxic", "block" }

---------------------------------------------------------------------------
-- Player records
---------------------------------------------------------------------------
function ns:GetPlayer(full)
  if not full or not ns.db then return nil end
  return ns.db.players[full]
end

function ns:SetTag(full, tag, note)
  if not full then return end
  local rec = ns.db.players[full] or { runs = 0 }
  rec.tag = tag
  if note ~= nil and note ~= "" then rec.note = note end
  if not tag then rec.note = nil end
  ns.db.players[full] = rec
  if ns.UI and ns.UI.RefreshPlayers then ns.UI:RefreshPlayers() end
end

function ns:TagOf(full)
  local rec = ns:GetPlayer(full)
  return rec and rec.tag
end

function ns:IsBlocked(full) return ns:TagOf(full) == "block" end
function ns:IsFavorite(full) return ns:TagOf(full) == "fav" end

function ns:TagShortFor(full)
  local tag = ns:TagOf(full)
  local t = tag and ns.TAGS[tag]
  if not t then return "" end
  return "|cff" .. t.color .. t.short .. "|r"
end

function ns:TagLabel(tag)
  local t = ns.TAGS[tag]
  if not t then return "" end
  return "|cff" .. t.color .. t.label .. "|r"
end

function ns:ListTagged()
  local list = {}
  for name, rec in pairs(ns.db.players) do
    if rec.tag then list[#list + 1] = { name = name, rec = rec } end
  end
  table.sort(list, function(a, b)
    if a.rec.tag ~= b.rec.tag then return a.rec.tag < b.rec.tag end
    return a.name < b.name
  end)
  return list
end

---------------------------------------------------------------------------
-- Track who you grouped with
---------------------------------------------------------------------------
local group = { members = {}, start = nil, context = nil }
local lastGroup = nil

local function MyFullName()
  local name, realm = UnitFullName("player")
  name, realm = ns.Safe(name), ns.Safe(realm)
  if not name then return nil end
  if not realm or realm == "" then return ns.FullName(name) end
  return name .. "-" .. realm
end

local function Snapshot()
  if not IsInGroup() then return end
  group.start = group.start or GetTime()
  local me = MyFullName()
  for _, unit in ipairs(ns.GroupUnits()) do
    if UnitExists(unit) then
      local name, realm = UnitFullName(unit)
      name, realm = ns.Safe(name), ns.Safe(realm)
      if name and name ~= UNKNOWNOBJECT then
        local full = (realm and realm ~= "") and (name .. "-" .. realm) or ns.FullName(name)
        if full and full ~= me then
          local _, class = UnitClass(unit)
          group.members[full] = ns.Safe(class) or group.members[full] or "PRIEST"
        end
      end
    end
  end
  local inInstance, itype = IsInInstance()
  if inInstance and (itype == "party" or itype == "raid") then
    group.context = ns.Safe((GetInstanceInfo())) or group.context
  end
end

local function FinishGroup()
  local duration = group.start and (GetTime() - group.start) or 0
  local members = group.members
  if next(members) then
    local now = time()
    for full in pairs(members) do
      local rec = ns.db.players[full] or { runs = 0 }
      rec.runs = (rec.runs or 0) + 1
      rec.last = now
      rec.where = group.context or rec.where
      ns.db.players[full] = rec
    end
    lastGroup = { members = members, context = group.context }
    if ns.db.ratePrompt and group.context and duration >= (ns.db.rateMinMinutes or 5) * 60 then
      ns:ShowRateWindow(members, group.context)
    end
  end
  group = { members = {}, start = nil, context = nil }
end

ns:On("GROUP_ROSTER_UPDATE", Snapshot)
ns:On("PLAYER_ENTERING_WORLD", Snapshot)
ns:On("GROUP_LEFT", FinishGroup)

-- Forget untagged players not seen for 60 days
ns:On("PLAYER_LOGIN", function()
  local cutoff = time() - 60 * 86400
  for name, rec in pairs(ns.db.players) do
    if not rec.tag and (rec.last or 0) < cutoff then ns.db.players[name] = nil end
  end
end)

function ns:ShowLastRate()
  if lastGroup then
    ns:ShowRateWindow(lastGroup.members, lastGroup.context)
  else
    ns.Print("No finished group to rate this session.")
  end
end

---------------------------------------------------------------------------
-- Rate window
---------------------------------------------------------------------------
local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(400, 22)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("LEFT", 2, 0)
  row.name:SetWidth(150)
  row.name:SetJustifyH("LEFT")
  row.buttons = {}
  local x = 156
  for _, key in ipairs(ns.TAG_ORDER) do
    local t = ns.TAGS[key]
    local b = ns.UI.Button(row, t.short, 38, 18, function()
      if ns:TagOf(row.player) == key then ns:SetTag(row.player, nil) else ns:SetTag(row.player, key) end
      row:Refresh()
    end)
    b:SetPoint("LEFT", x, 0)
    b.key = key
    row.buttons[#row.buttons + 1] = b
    x = x + 40
  end
  function row:Refresh()
    local cur = ns:TagOf(self.player)
    for _, b in ipairs(self.buttons) do
      local t = ns.TAGS[b.key]
      b.selected = cur == b.key
      b.text:SetText(b.selected and ("|cff" .. t.color .. t.short .. "|r") or ("|cff888888" .. t.short .. "|r"))
      ns.UI.Paint(b)
    end
  end
  return row
end

function ns:ShowRateWindow(members, context)
  if not members or not next(members) then return end
  local f = ns.rateFrame
  if not f then
    f = CreateFrame("Frame", "SDRRateFrame", UIParent, "BackdropTemplate")
    f:SetSize(440, 380)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    ns.UI.Skin(f)
    ns.UI.Movable(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -12)
    f.title:SetTextColor(unpack(ns.CYAN))
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
    hint:SetText("Tags show up next time you see these players in the group finder.")
    local scroll, content = ns.UI.ScrollList(f, 12, -52, 410, 280)
    f.content = content
    f.rows = {}
    local done = ns.UI.Button(f, "Done", 90, 22, function() f:Hide() end)
    done:SetPoint("BOTTOM", 0, 12)
    ns.rateFrame = f
  end
  f.title:SetText("Rate your group" .. (context and (" - " .. context) or ""))

  local names = {}
  for full in pairs(members) do names[#names + 1] = full end
  table.sort(names)
  for i, full in ipairs(names) do
    local row = f.rows[i]
    if not row then
      row = CreateRow(f.content)
      f.rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * 24)
    row.player = full
    row.name:SetText("|c" .. ns.ClassHex(members[full]) .. ns.ShortName(full) .. "|r")
    row:Refresh()
    row:Show()
  end
  for i = #names + 1, #f.rows do f.rows[i]:Hide() end
  f.content:SetHeight(math.max(1, #names * 24))
  f:Show()
end

---------------------------------------------------------------------------
-- Right-click menu: tag a player
---------------------------------------------------------------------------
local function AddMenu(menuTag)
  Menu.ModifyMenu(menuTag, function(_, root, contextData)
    if not contextData or not ns.db then return end
    local name = ns.Safe(contextData.name)
    if type(name) ~= "string" then return end
    local server = ns.Safe(contextData.server)
    local full = (server and server ~= "") and (name .. "-" .. server) or ns.FullName(name)
    if not full then return end
    root:CreateDivider()
    local sub = root:CreateButton("|cff" .. ns.CYAN_HEX .. "Group Finder tag|r")
    for _, key in ipairs(ns.TAG_ORDER) do
      local t = ns.TAGS[key]
      sub:CreateButton("|cff" .. t.color .. t.label .. "|r", function()
        ns:SetTag(full, key)
        ns.Print(full .. " tagged " .. t.label)
      end)
    end
    sub:CreateButton("Clear tag", function() ns:SetTag(full, nil) end)
  end)
end

if Menu and Menu.ModifyMenu then
  for _, t in ipairs({ "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_ENEMY_PLAYER" }) do
    pcall(AddMenu, t)
  end
end
