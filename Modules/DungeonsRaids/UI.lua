-- Seviath's Dungeons & Raids - window, settings tabs, minimap button
local _, ns = SFP_Module("DungeonsRaids")
local D = ns.Data
local UI = {}
ns.UI = UI
local C = ns.CYAN

---------------------------------------------------------------------------
-- Widgets (Seviath cyan theme)
---------------------------------------------------------------------------
function UI.Skin(f, alpha)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(0.03, 0.05, 0.07, alpha or 0.95)
  f:SetBackdropBorderColor(C[1], C[2], C[3], 0.9)
end

function UI.Movable(f)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
end

-- Selected = solid cyan fill. Hover = brighter outline only, so it never looks selected.
function UI.Paint(b)
  if b.selected then
    b:SetBackdropColor(C[1] * 0.5, C[2] * 0.5, C[3] * 0.5, 1)
    b:SetBackdropBorderColor(C[1], C[2], C[3], 1)
  else
    b:SetBackdropColor(0.03, 0.05, 0.07, 0.9)
    b:SetBackdropBorderColor(C[1], C[2], C[3], b.hover and 1 or 0.4)
  end
end

function UI.Button(parent, text, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w or 80, h or 20)
  UI.Skin(b, 0.9)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER")
  b.text:SetText(text)
  b:SetScript("OnEnter", function(s) s.hover = true UI.Paint(s) end)
  b:SetScript("OnLeave", function(s) s.hover = false UI.Paint(s) end)
  UI.Paint(b)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function Label(parent, text, x, y, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

local function Header(parent, text, x, y)
  local fs = Label(parent, text, x, y, "GameFontNormal")
  fs:SetTextColor(C[1], C[2], C[3])
  return fs
end

local function Tip(frame, text)
  if not text then return end
  frame:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Small grey/orange text after an option: "hides 3", "would hide 5", "12 groups"
local countLabels = {}

local function KindOf(tbl)
  if tbl == ns.db then return "global" end
  for k, v in pairs(ns.db) do
    if v == tbl then return k end
  end
end

local function AddCount(owner, anchor, tbl, key)
  if not ns.TESTS or not ns.TESTS[key] then return end
  local fs = owner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
  countLabels[#countLabels + 1] = { fs = fs, tbl = tbl, key = key, kind = KindOf(tbl) }
end

function UI:UpdateCounts()
  for _, e in ipairs(countLabels) do
    local t = ns.TESTS[e.key]
    local section = e.kind ~= "global" and ns.db[e.kind]
    if not ns.matchCounts or not ns.originalResults or not e.kind
      or (section and not section.enabled) then
      e.fs:SetText("")
    else
      local n = ns.matchCounts[e.kind .. "." .. e.key] or 0
      local on = ns.TestActive(t, e.tbl)
      local text
      if t.type == "hide" then
        if on then
          text = n > 0 and ("|cffffb040hides " .. n .. "|r") or "|cff777777hides 0|r"
        else
          text = "|cff777777would hide " .. n .. "|r"
        end
      elseif t.type == "show" then
        if on then
          text = n > 0 and ("|cffffb040" .. n .. " hidden|r") or "|cff7777770 groups|r"
        else
          text = "|cff999999" .. n .. (n == 1 and " group|r" or " groups|r")
        end
      elseif t.type == "num" then
        text = on and (n > 0 and ("|cffffb040hides " .. n .. "|r") or "|cff777777hides 0|r") or ""
      else
        text = "|cff999999" .. n .. (n == 1 and " group|r" or " groups|r")
      end
      e.fs:SetText(text)
    end
  end
end

function UI.Check(parent, label, tbl, key, x, y, tip, onChange)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  fs:SetText(label)
  AddCount(cb, fs, tbl, key)
  cb:SetChecked(tbl[key] and true or false)
  cb:SetScript("OnClick", function(s)
    tbl[key] = s:GetChecked() and true or false
    if onChange then onChange(tbl[key]) end
    UI:Changed()
  end)
  Tip(cb, tip)
  return cb
end

function UI.Number(parent, label, tbl, key, x, y, tip)
  local fs = Label(parent, label, x, y - 4)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(46, 20)
  eb:SetPoint("LEFT", fs, "RIGHT", 12, 0)
  eb:SetAutoFocus(false)
  eb:SetNumeric(true)
  eb:SetMaxLetters(5)
  eb:SetText(tostring(tbl[key] or 0))
  AddCount(parent, eb, tbl, key)
  local function save(s)
    local v = tonumber(s:GetText()) or 0
    local changed = tbl[key] ~= v
    tbl[key] = v
    s:SetText(tostring(v))
    if changed then UI:Changed() end
  end
  eb:SetScript("OnEnterPressed", function(s) save(s) s:ClearFocus() end)
  eb:SetScript("OnEditFocusLost", save)
  eb:SetScript("OnEscapePressed", function(s) s:SetText(tostring(tbl[key] or 0)) s:ClearFocus() end)
  Tip(eb, tip)
  return eb
end

local function TextBox(parent, width, x, y, maxLetters)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(width, 20)
  eb:SetPoint("TOPLEFT", x, y)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(maxLetters or 120)
  eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  return eb
end

-- Settings changed: re-filter the open Premade Groups list (short delay so typing doesn't spam it)
local changeQueued = false
function UI:Changed()
  if changeQueued then return end
  changeQueued = true
  C_Timer.After(0.15, function()
    changeQueued = false
    ns:Refilter()
  end)
end

function UI.ScrollList(parent, x, y, w, h)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", x, y)
  scroll:SetSize(w - 26, h)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(w - 26, 1)
  scroll:SetScrollChild(content)
  return scroll, content
end

---------------------------------------------------------------------------
-- Tab pages
---------------------------------------------------------------------------
local pages = {}
local TABS = {
  -- row 1: one tab per Premade Groups section
  { key = "quest",     label = "Questing" },
  { key = "delve",     label = "Delves" },
  { key = "dungeon",   label = "Dungeons" },
  { key = "mplus",     label = "Mythic+" },
  { key = "raid",      label = "Raids" },
  { key = "custom",    label = "Custom" },
  -- row 2: tools
  { key = "players",   label = "Players",  row = 2 },
  { key = "templates", label = "Notes",    row = 2 },
  { key = "group",     label = "My Group", row = 2 },
  { key = "settings",  label = "Settings", row = 2 },
}

local TAB_LABEL = {}
for _, t in ipairs(TABS) do TAB_LABEL[t.key] = t.label end

-- Live status line: re-filters happen as soon as a setting changes: re-filters the list that's already open
local statusLines = {}

local function Footer(p, y)
  local status = Label(p, "", 16, y - 4, "GameFontHighlightSmall")
  statusLines[#statusLines + 1] = status
end

function UI:UpdateStatus()
  local text
  if ns.originalResults then
    local shown = #ns.originalResults - (ns.hiddenCount or 0)
    text = string.format("|cff40ff60%d groups shown|r  |cff999999- %d hidden by these filters. Changes apply instantly.|r", shown, ns.hiddenCount or 0)
  else
    text = "|cff999999Changes apply instantly to the open Premade Groups list.|r"
  end
  for _, fs in ipairs(statusLines) do fs:SetText(text) end
  UI:UpdateCounts()
  UI:RefreshPickers()
  if UI.panelStatus then
    if ns.originalResults and ns.db.enabled then
      local total = #ns.originalResults
      UI.panelStatus:SetText(string.format("|cff33e6ffFiltered:|r %d of %d shown", total - (ns.hiddenCount or 0), total))
    elseif ns.originalResults then
      UI.panelStatus:SetText("|cff999999Filters off|r")
    else
      UI.panelStatus:SetText("")
    end
  end
end

local COL2 = 300

local function DiffRow(p, o, y, mythicLabel)
  Label(p, "Difficulty:", 20, y - 6)
  UI.Check(p, "Normal", o, "diffN", 100, y)
  UI.Check(p, "Heroic", o, "diffH", 250, y)
  UI.Check(p, mythicLabel or "Mythic", o, "diffM", 400, y)
end

local function Legend(p, y, text)
  Header(p, "Listing tags", 16, y)
  Label(p, text, 20, y - 20, "GameFontHighlightSmall")
end

local COMMON_TAGS = "|cff40ff60NEW|r listed under 2 min ago     member class icons     |cff40ff60AUTO|r joins instantly\n|cff80c0ff2 fr|r friends or guildies     FAV, GOOD, TOXIC ... your tag on the leader"
local LOOT_TAGS = "|cffa335eeMOUNT|r |cff40c0ffPET|r |cffffd040TOY|r |cffff80ff5 tmog|r  drops you haven't collected yet (hover for names)"

-- "Pick delves / dungeons": one checkbox per place, with its group count.
-- Nothing ticked = show every place.
local pickers = {}

local function BuildPicker(p, kind, y, title, byExpansion)
  Header(p, title, 16, y)
  local all = UI.Button(p, "Show all", 76, 18, function()
    wipe(ns.db[kind].picked)
    UI:RefreshPickers()
    UI:Changed()
  end)
  all:SetPoint("TOPLEFT", COL2, y + 2)
  Label(p, "|cff999999Tick the ones you want - only those show. Nothing ticked = all of them.|r", 16, y - 18, "GameFontHighlightSmall")
  pickers[kind] = {
    page = p, top = y - 36, checks = {}, headers = {}, byExpansion = byExpansion,
    empty = Label(p, "", 20, y - 40, "GameFontHighlightSmall"),
  }
end

local function PickerCheck(pk, idx)
  local cb = pk.checks[idx]
  if cb then return cb end
  cb = CreateFrame("CheckButton", nil, pk.page, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb.label:SetWidth(200)
  cb.label:SetJustifyH("LEFT")
  cb.label:SetWordWrap(false)
  cb.count = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cb.count:SetPoint("RIGHT", cb.label, "RIGHT", 0, 0)
  cb:SetScript("OnClick", function(self)
    ns.db[self.kind].picked[self.place] = self:GetChecked() and true or nil
    UI:Changed()
  end)
  pk.checks[idx] = cb
  return cb
end

-- Expansion header: click to tick / untick everything in that expansion
local function PickerHeader(pk, idx)
  local h = pk.headers[idx]
  if h then return h end
  h = CreateFrame("Button", nil, pk.page)
  h:SetSize(520, 18)
  h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h.text:SetPoint("LEFT", 0, 0)
  h.text:SetJustifyH("LEFT")
  h.line = h:CreateTexture(nil, "ARTWORK")
  h.line:SetColorTexture(C[1], C[2], C[3], 0.35)
  h.line:SetHeight(1)
  h.line:SetPoint("BOTTOMLEFT", 0, 0)
  h.line:SetPoint("BOTTOMRIGHT", 0, 0)
  h:SetScript("OnEnter", function(self)
    self.text:SetTextColor(1, 1, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Click to tick or untick every " .. (self.kind == "raid" and "raid" or "dungeon") .. " in " .. self.tierName, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  h:SetScript("OnLeave", function(self)
    self.text:SetTextColor(C[1], C[2], C[3])
    GameTooltip:Hide()
  end)
  h:SetScript("OnClick", function(self)
    local picked = ns.db[self.kind].picked
    local all = true
    for _, n in ipairs(self.names) do
      if not picked[n] then all = false break end
    end
    for _, n in ipairs(self.names) do picked[n] = (not all) or nil end
    UI:RefreshPickers()
    UI:Changed()
  end)
  pk.headers[idx] = h
  return h
end

function UI:RefreshPickers()
  for kind, pk in pairs(pickers) do
    if pk.byExpansion then ns:LoadEJPlaces(kind) end
    local o = ns.db[kind]
    local counts = ns.placeCounts and ns.placeCounts[kind] or {}

    -- group names: by expansion (newest first, unknown last) or one plain group
    local groups, order = {}, {}
    for name in pairs(o.known) do
      local tier = pk.byExpansion and ns:PlaceTier(kind, name) or 0
      if not groups[tier] then
        groups[tier] = {}
        order[#order + 1] = tier
      end
      table.insert(groups[tier], name)
    end
    table.sort(order, function(a, b)
      if a == 0 then return false end
      if b == 0 then return true end
      return a > b
    end)

    local y, ci, hi, total = pk.top, 0, 0, 0
    for _, tier in ipairs(order) do
      local names = groups[tier]
      table.sort(names)
      if pk.byExpansion then
        hi = hi + 1
        local h = PickerHeader(pk, hi)
        local groupsHere, picked = 0, 0
        for _, n in ipairs(names) do
          groupsHere = groupsHere + (counts[n] or 0)
          if o.picked[n] then picked = picked + 1 end
        end
        h.kind, h.names = kind, names
        h.tierName = tier == 0 and "Other" or ns:TierName(tier)
        h.text:SetText(h.tierName
          .. (groupsHere > 0 and ("   |cff40ff60" .. groupsHere .. (groupsHere == 1 and " group" or " groups") .. "|r") or "")
          .. (picked > 0 and ("   |cffffffff" .. picked .. " ticked|r") or ""))
        h.text:SetTextColor(C[1], C[2], C[3])
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 16, y)
        h:Show()
        y = y - 24
      end
      for k, name in ipairs(names) do
        ci = ci + 1
        local cb = PickerCheck(pk, ci)
        local col, row = (k - 1) % 2, math.floor((k - 1) / 2)
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", col == 0 and 16 or COL2, y - row * 24)
        cb.kind, cb.place = kind, name
        cb.label:SetText(name)
        cb:SetChecked(o.picked[name] and true or false)
        local n = counts[name] or 0
        cb.count:SetText(n > 0 and ("|cff40ff60" .. n .. "|r") or "")
        cb:Show()
      end
      y = y - math.ceil(#names / 2) * 24 - 6
      total = total + #names
    end
    for k = ci + 1, #pk.checks do pk.checks[k]:Hide() end
    for k = hi + 1, #pk.headers do pk.headers[k]:Hide() end
    pk.empty:SetText(total == 0 and "|cff999999Open this section in Premade Groups once to load the list.|r" or "")
    pk.page.SDRHeight = -y + 16
  end
  if self.frame and self.current and pages[self.current] then
    self.frame.content:SetHeight(math.max(pages[self.current].SDRHeight or 0, 410))
  end
end

local function BuildQuest(p)
  local o = ns.db.quest
  Header(p, "Questing filters", 16, -10)
  UI.Check(p, "Enable questing filters", o, "enabled", 16, -34)
  Label(p, "Type:", 20, -66)
  UI.Check(p, "World quests", o, "showWQ", 90, -60, "World quests (WQ tag).")
  UI.Check(p, "Quests", o, "showQuests", 260, -60, "Normal quests, campaign and dailies.")
  UI.Check(p, "Other", o, "showOther", 400, -60, "Zone, event and rare groups that aren't tied to one quest.")
  UI.Check(p, "Only quests in my log", o, "onMyQuests", 16, -86,
    "Zone and world-event groups that aren't tied to one quest still show.")
  UI.Check(p, "Only my current zone", o, "myZoneOnly", COL2, -86)
  UI.Check(p, "Hide quests I've completed", o, "hideCompleted", 16, -112)
  UI.Check(p, "Hide full groups", o, "hideFull", COL2, -112)
  UI.Check(p, "Only auto-accept groups", o, "autoAcceptOnly", 16, -138)
  UI.Check(p, "Hide blocked leaders", o, "hideBlocked", COL2, -138)
  Legend(p, -176, "|cff40ff60ON QUEST|r in your log (sorted first)   |cff888888DONE|r already completed   |cffffd040WQ|r world quest\n|cff33e6ffHERE|r in your current zone\n" .. COMMON_TAGS)
  Footer(p, -276)
  BuildPicker(p, "quest", -308, "Zones")
end

local function BuildDelve(p)
  local o = ns.db.delve
  Header(p, "Delve filters", 16, -10)
  UI.Check(p, "Enable delve filters", o, "enabled", 16, -34)
  UI.Check(p, "Hide full groups", o, "hideFull", 16, -60)
  UI.Check(p, "Only auto-accept groups", o, "autoAcceptOnly", COL2, -60)
  UI.Check(p, "Hide blocked leaders", o, "hideBlocked", 16, -86)
  UI.Number(p, "Min members", o, "minMembers", 20, -120)
  UI.Number(p, "Max members", o, "maxMembers", COL2 + 4, -120, "0 = no limit")
  UI.Number(p, "Min tier", o, "minTier", 20, -148, "0 = any")
  UI.Number(p, "Max tier", o, "maxTier", COL2 + 4, -148, "0 = any")
  Footer(p, -180)
  BuildPicker(p, "delve", -212, "Delves")
end

local function BuildDungeon(p)
  local o = ns.db.dungeon
  Header(p, "Dungeon filters (Normal, Heroic, Mythic 0)", 16, -10)
  UI.Check(p, "Enable dungeon filters", o, "enabled", 16, -34)
  DiffRow(p, o, -60, "Mythic 0")
  UI.Check(p, "Only groups needing my role", o, "needMyRole", 16, -86)
  UI.Check(p, "Hide groups with my class", o, "hideSameClass", COL2, -86,
    "Less loot competition while you level and gear.")
  UI.Check(p, "Hide full groups", o, "hideFull", 16, -112)
  UI.Check(p, "Hide above my item level", o, "hideAboveMyIlvl", COL2, -112)
  UI.Check(p, "Hide blocked leaders", o, "hideBlocked", 16, -138)
  UI.Check(p, "Fresh runs only", o, "freshOnly", COL2, -138, "No bosses killed yet.")
  Label(p, "Only groups with something new:", 20, -170)
  UI.Check(p, "|cffa335eeMount|r", o, "wantMount", 230, -164, "A mount you don't have drops from a boss still alive for you.")
  UI.Check(p, "|cff40c0ffPet|r", o, "wantPet", 390, -164, "A battle pet you don't have.")
  UI.Check(p, "|cffffd040Toy|r", o, "wantToy", 230, -190, "A toy you don't have.")
  UI.Check(p, "|cffff80ffTransmog|r", o, "wantTmog", 390, -190, "An appearance you can learn and don't have yet.")
  UI.Number(p, "Min new collectibles (mounts, pets, toys, appearances)", o, "minNewLoot", 20, -224,
    "Counts loot from this dungeon you haven't collected. 0 = off.")
  Legend(p, -262, "|cff40ff60FRESH|r no bosses killed yet     |cffffb040STARTED 2/4|r group already killed some\n" .. LOOT_TAGS .. "\n" .. COMMON_TAGS)
  Footer(p, -364)
  BuildPicker(p, "dungeon", -396, "Dungeons", true)
end

local function BuildMPlus(p)
  local o = ns.db.mplus
  Header(p, "Mythic+ filters", 16, -10)
  UI.Check(p, "Enable Mythic+ filters", o, "enabled", 16, -34)
  UI.Check(p, "Only groups needing my role", o, "needMyRole", 16, -60)
  UI.Check(p, "Hide groups with my class", o, "hideSameClass", COL2, -60,
    "Less loot competition and no doubled-up utility.")
  UI.Check(p, "Need Bloodlust", o, "requireLust", 16, -86, "Group has Bloodlust, or you bring it.")
  UI.Check(p, "Need battle res", o, "requireBrez", COL2, -86, "Group has a battle res, or you bring it.")
  UI.Check(p, "Hide full groups", o, "hideFull", 16, -112)
  UI.Check(p, "Hide blocked leaders", o, "hideBlocked", COL2, -112)
  UI.Number(p, "Min leader Mythic+ rating", o, "minLeaderScore", 20, -146)
  UI.Number(p, "Leader timed this key from +", o, "minTimedLevel", 20, -174,
    "Only leaders who have TIMED this dungeon at this key level or higher. 0 = off.")
  UI.Number(p, "up to +", o, "maxTimedLevel", COL2 + 4, -174,
    "Hide leaders whose best timed key here is above this - they usually run higher keys than you want. 0 = off.")
  Label(p, "|cff999999Exact key level: type it into Blizzard's search box (\"Search key numbers...\"), e.g. 16, and press Enter.|r", 20, -202, "GameFontHighlightSmall")

  Legend(p, -228, "|cff40ff60BL|r / |cffff5050BL|r group has / lacks Bloodlust     |cff40ff60BR|r / |cffff5050BR|r battle res\n" .. LOOT_TAGS .. "\n" .. COMMON_TAGS .. "\n|cff999999Mythic+ unlocks at max level.|r")
  Footer(p, -312)
  BuildPicker(p, "mplus", -344, "Keys (this season's Mythic+ dungeons)")
end

local function BuildRaid(p)
  local o = ns.db.raid
  Header(p, "Raid filters", 16, -10)
  UI.Check(p, "Enable raid filters", o, "enabled", 16, -34)
  DiffRow(p, o, -60)
  Label(p, "Raids:", 20, -92)
  UI.Check(p, "Current", o, "showCurrent", 100, -86)
  UI.Check(p, "Legacy (old raids)", o, "showLegacy", 250, -86,
    "Below max level only legacy raids are listed.")
  UI.Check(p, "Only groups needing my role", o, "needMyRole", 16, -112)
  UI.Check(p, "Fresh runs only", o, "freshOnly", COL2, -112, "No bosses killed yet.")
  UI.Check(p, "Hide full groups", o, "hideFull", 16, -138)
  UI.Check(p, "Hide above my item level", o, "hideAboveMyIlvl", COL2, -138)
  UI.Check(p, "Hide blocked leaders", o, "hideBlocked", 16, -164)
  UI.Check(p, "Sort up: missing my buff", o, "highlightMyBuff", COL2, -164, "Current raids only: groups missing a raid buff your class brings go first.")
  Label(p, "Only groups with something new:", 20, -196)
  UI.Check(p, "|cffa335eeMount|r", o, "wantMount", 230, -190, "A mount you don't have drops from a boss still alive for you.")
  UI.Check(p, "|cff40c0ffPet|r", o, "wantPet", 390, -190, "A battle pet you don't have.")
  UI.Check(p, "|cffffd040Toy|r", o, "wantToy", 230, -216, "A toy you don't have.")
  UI.Check(p, "|cffff80ffTransmog|r", o, "wantTmog", 390, -216, "An appearance you can learn and don't have yet.")
  UI.Number(p, "Max bosses killed", o, "maxKilled", 20, -252)
  UI.Number(p, "Min bosses left for me", o, "minLootable", COL2 + 4, -252,
    "Bosses the group hasn't killed AND you haven't killed this week on that difficulty.")
  UI.Number(p, "Min members", o, "minMembers", 20, -280)
  UI.Number(p, "Max members", o, "maxMembers", COL2 + 4, -280)
  UI.Number(p, "Max same tier token", o, "maxSameToken", 20, -308,
    "Tier tokens. Conqueror: Paladin, Priest, Warlock - Protector: Warrior, Hunter, Shaman, Monk - Vanquisher: Rogue, Death Knight, Mage, Druid")
  UI.Number(p, "Min new collectibles", o, "minNewLoot", COL2 + 4, -308,
    "Mounts, pets, toys and appearances you don't have, from bosses still alive for you. 0 = off.")
  Legend(p, -342, "|cff40ff60FRESH|r no bosses killed   |cffffb040STARTED 3/9|r already started\n|cff40ff60+Stats|r buff you'd add   |cffffb0402 tok|r token competitors\n" .. LOOT_TAGS)
  Footer(p, -410)
  BuildPicker(p, "raid", -442, "Raids", true)
end

local function BuildCustom(p)
  local o = ns.db.custom
  Header(p, "Custom group filters", 16, -10)
  UI.Check(p, "Enable custom filters", o, "enabled", 16, -34)
  Label(p, "Type:", 20, -66)
  UI.Check(p, "PvE", o, "showPvE", 100, -60, "Custom PvE groups: questing, farming, rares, old content...")
  UI.Check(p, "PvP", o, "showPvP", 250, -60, "Custom PvP groups: world PvP, battleground premades, duels...")
  Label(p, "War Mode:", 20, -92)
  UI.Check(p, "On", o, "showWarModeOn", 100, -86, "Groups listed with War Mode on.")
  UI.Check(p, "Off", o, "showWarModeOff", 250, -86, "Groups listed with War Mode off.")
  UI.Check(p, "Only groups needing my role", o, "needMyRole", 16, -112,
    "Only applies to custom groups that use role slots.")
  UI.Check(p, "Hide full groups", o, "hideFull", COL2, -112)
  UI.Check(p, "Only auto-accept groups", o, "autoAcceptOnly", 16, -138)
  UI.Check(p, "Hide above my item level", o, "hideAboveMyIlvl", COL2, -138)
  UI.Check(p, "Hide blocked leaders", o, "hideBlocked", 16, -164)
  UI.Number(p, "Min members", o, "minMembers", 20, -198)
  UI.Number(p, "Max members", o, "maxMembers", COL2 + 4, -198, "0 = no limit")
  Legend(p, -234, COMMON_TAGS)
  Footer(p, -298)
end

local function BuildPlayers(p)
  Header(p, "Tag a player", 16, -10)
  Label(p, "Name-Realm", 16, -36, "GameFontHighlightSmall")
  local nameBox = TextBox(p, 170, 20, -50, 60)
  Label(p, "Note (optional)", 200, -36, "GameFontHighlightSmall")
  local noteBox = TextBox(p, 300, 204, -50, 80)
  local x = 16
  for _, key in ipairs(ns.TAG_ORDER) do
    local t = ns.TAGS[key]
    local b = UI.Button(p, "|cff" .. t.color .. t.label .. "|r", 82, 20, function()
      local full = ns.FullName(strtrim(nameBox:GetText() or ""))
      if not full then return end
      ns:SetTag(full, key, strtrim(noteBox:GetText() or ""))
      nameBox:SetText("") noteBox:SetText("")
    end)
    b:SetPoint("TOPLEFT", x, -78)
    x = x + 86
  end
  Header(p, "Tagged players", 16, -112)
  Label(p, "|cff999999Tip: right-click any player and use \"Group Finder tag\".|r", 140, -113, "GameFontHighlightSmall")
  local _, content = UI.ScrollList(p, 12, -134, 530, 300)
  p.content = content
  p.rows = {}
end

function UI:RefreshPlayers()
  local p = pages.players
  if not p or not p.content then return end
  local list = ns:ListTagged()
  for i, item in ipairs(list) do
    local row = p.rows[i]
    if not row then
      row = CreateFrame("Frame", nil, p.content)
      row:SetSize(500, 20)
      row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.name:SetPoint("LEFT", 2, 0) row.name:SetWidth(160) row.name:SetJustifyH("LEFT")
      row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.tag:SetPoint("LEFT", 166, 0) row.tag:SetWidth(80) row.tag:SetJustifyH("LEFT")
      row.note = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      row.note:SetPoint("LEFT", 250, 0) row.note:SetWidth(190) row.note:SetJustifyH("LEFT")
      row.del = UI.Button(row, "x", 20, 18, function() ns:SetTag(row.player, nil) end)
      row.del:SetPoint("RIGHT", -4, 0)
      p.rows[i] = row
    end
    row:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -(i - 1) * 22)
    row.player = item.name
    row.name:SetText(item.name)
    row.tag:SetText(ns:TagLabel(item.rec.tag))
    local extra = (item.rec.runs or 0) > 0 and ("  (" .. item.rec.runs .. " runs" .. (item.rec.where and (", " .. item.rec.where) or "") .. ")") or ""
    row.note:SetText((item.rec.note or "") .. extra)
    row:Show()
  end
  for i = #list + 1, #p.rows do p.rows[i]:Hide() end
  p.content:SetHeight(math.max(1, #list * 22))
end

local function BuildTemplates(p)
  local t = ns.db.templates
  Header(p, "Application notes", 16, -10)
  UI.Check(p, "Fill the application note automatically", ns.db, "useTemplates", 16, -32)
  Label(p, "|cff999999Only fills an empty note box. You can still edit it before applying.|r", 20, -58, "GameFontHighlightSmall")
  local rows = {
    { "quest", "Questing" }, { "delve", "Delves" }, { "dungeon", "Dungeons" }, { "mplus", "Mythic+" },
    { "raidN", "Raid - Normal" }, { "raidH", "Raid - Heroic" }, { "raidM", "Raid - Mythic" }, { "custom", "Custom" },
  }
  local y = -82
  for _, r in ipairs(rows) do
    local key = r[1]
    Label(p, r[2], 20, y)
    local eb = TextBox(p, 400, 130, y + 4, 120)
    eb:SetText(t[key] or "")
    eb:SetScript("OnEditFocusLost", function(s) t[key] = s:GetText() or "" end)
    eb:SetScript("OnEnterPressed", function(s) t[key] = s:GetText() or "" s:ClearFocus() end)
    y = y - 30
  end
  Label(p, "Examples:\n  \"Know the route, have lust, can swap to off-spec\"\n  \"Need the rare for my quest, can tank\"", 20, y - 8, "GameFontHighlightSmall")
end

local function BuildGroup(p)
  Header(p, "My group", 16, -10)
  p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  p.text:SetPoint("TOPLEFT", 20, -36)
  p.text:SetPoint("RIGHT", -20, 0)
  p.text:SetJustifyH("LEFT")
  p.text:SetJustifyV("TOP")
  p.text:SetSpacing(2)
  local b = UI.Button(p, "Refresh", 80, 20, function() UI:RefreshGroup() end)
  b:SetPoint("TOPRIGHT", -16, -8)
end

function UI:RefreshGroup()
  local p = pages.group
  if p and p.text and p:IsVisible() then p.text:SetText(ns:GroupCompText()) end
end

local function BuildSettings(p)
  local db = ns.db
  Header(p, "General", 16, -10)
  UI.Check(p, "Filter group finder listings", db, "enabled", 16, -34)
  UI.Check(p, "Show tags and tooltip info", db, "annotate", COL2, -34)
  UI.Check(p, "Sort favorites and friends first", db, "favoritesFirst", 16, -60)
  UI.Check(p, "Rate group after leaving", db, "ratePrompt", COL2, -60,
    "Only after instance groups that lasted at least 5 minutes.")
  UI.Check(p, "Sound when invited", db, "inviteSound", 16, -86)
  UI.Check(p, "Pending applications panel", db, "showPending", COL2, -86, nil,
    function() if ns.UpdatePendingPanel then ns.UpdatePendingPanel() end end)
  UI.Check(p, "Minimap button", db.minimap, "show", 16, -112, nil, function() UI:UpdateMinimap() end)
  UI.Check(p, "Hide above my level", db, "hideAboveMyLevel", COL2, -112)
  UI.Check(p, "Check loot for mounts, pets, toys, transmog", db, "scanLoot", 16, -138,
    "Reads boss loot from the Adventure Guide. Turn off if the group finder feels slow.")
  UI.Number(p, "Hide groups listed longer than (minutes, 0 = off)", db, "maxAgeMinutes", 20, -172)

  Header(p, "Window", 16, -208)
  UI.Check(p, "Open this window with Premade Groups", db, "autoOpen", 16, -230)
  Label(p, "Dock:", 20, -264)
  local dockLabel = Label(p, "", 300, -264, "GameFontHighlightSmall")
  local function RefreshDock()
    local names = { RIGHT = "right of the Group Finder", BOTTOM = "below the Group Finder", OFF = "free-floating" }
    dockLabel:SetText("|cff999999" .. (names[db.dock] or "") .. "|r")
  end
  local x = 64
  for _, d in ipairs({ { "RIGHT", "Right" }, { "BOTTOM", "Below" }, { "OFF", "Off" } }) do
    local b = UI.Button(p, d[2], 70, 20, function()
      db.dock = d[1]
      RefreshDock()
      if d[1] ~= "OFF" and PVEFrame and PVEFrame:IsShown() then UI:Dock() end
    end)
    b:SetPoint("TOPLEFT", x, -258)
    x = x + 76
  end
  RefreshDock()

  Header(p, "Role used by \"needs my role\" filters", 16, -298)
  local roleLabel = Label(p, "", 330, -324, "GameFontHighlightSmall")
  local function RefreshRole()
    roleLabel:SetText("Current: |cffffffff" .. (db.roleOverride == "AUTO" and ("Auto (" .. D.ROLE_LABEL[ns.MyRole()] .. ")") or D.ROLE_LABEL[db.roleOverride]) .. "|r")
  end
  x = 20
  for _, r in ipairs({ { "AUTO", "Auto" }, { "TANK", "Tank" }, { "HEALER", "Healer" }, { "DAMAGER", "DPS" } }) do
    local b = UI.Button(p, r[2], 70, 20, function() db.roleOverride = r[1] RefreshRole() end)
    b:SetPoint("TOPLEFT", x, -320)
    x = x + 76
  end
  p:SetScript("OnShow", RefreshRole)
  RefreshRole()
  Label(p, "|cff999999/sdr - open   /sdr tag Name-Realm good   /sdr rate   /sdr comp   /sdr minimap|r", 16, -360, "GameFontHighlightSmall")
end

local BUILDERS = {
  quest = BuildQuest, delve = BuildDelve, dungeon = BuildDungeon, mplus = BuildMPlus,
  raid = BuildRaid, custom = BuildCustom, players = BuildPlayers,
  templates = BuildTemplates, group = BuildGroup, settings = BuildSettings,
}

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------
function UI:Build()
  if self.frame then return end
  local f = CreateFrame("Frame", "SeviathsDungeonsRaidsFrame", UIParent, "BackdropTemplate")
  f:SetSize(580, 520)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  UI.Skin(f)
  UI.Movable(f)
  -- Dragging a docked window frees it for the rest of the session
  f:SetScript("OnDragStart", function(s)
    UI.docked = false
    s:StartMoving()
  end)
  tinsert(UISpecialFrames, "SeviathsDungeonsRaidsFrame")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetTextColor(C[1], C[2], C[3])
  f.title = title
  local ver = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
  ver:SetText("v" .. ns.VERSION)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(546, 410)
  scroll:SetScrollChild(content)
  f.scroll, f.content = scroll, content

  -- Make it obvious the page scrolls: a visible cyan track + handle ...
  local sb = scroll.ScrollBar
  if type(sb) == "table" and sb.CreateTexture then
    local track = sb:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(C[1], C[2], C[3], 0.18)
    track:SetWidth(6)
    track:SetPoint("TOP", sb, "TOP", 0, 2)
    track:SetPoint("BOTTOM", sb, "BOTTOM", 0, -2)
    local thumb = sb.GetThumbTexture and sb:GetThumbTexture()
    if thumb then
      thumb:SetColorTexture(C[1], C[2], C[3], 0.9)
      thumb:SetSize(8, 36)
    end
  end
  -- ... and a bar at the bottom while there is more below
  local more = CreateFrame("Button", nil, f, "BackdropTemplate")
  more:SetPoint("BOTTOMLEFT", 6, 8)
  more:SetPoint("BOTTOMRIGHT", -30, 8)
  more:SetHeight(20)
  more:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  more:SetBackdropColor(0.02, 0.12, 0.16, 0.95)
  more:SetFrameLevel(scroll:GetFrameLevel() + 20)
  more.text = more:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  more.text:SetPoint("CENTER")
  more.text:SetTextColor(C[1], C[2], C[3])
  more:SetScript("OnClick", function()
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() + 220))
  end)
  more:SetScript("OnEnter", function(s) s.text:SetTextColor(1, 1, 1) end)
  more:SetScript("OnLeave", function(s) s.text:SetTextColor(C[1], C[2], C[3]) end)
  f.more = more
  local function UpdateMore() UI:UpdateMoreHint() end
  scroll:HookScript("OnScrollRangeChanged", UpdateMore)
  scroll:HookScript("OnVerticalScroll", UpdateMore)
  scroll:HookScript("OnShow", UpdateMore)

  f.tabButtons = {}
  for _, tab in ipairs(TABS) do
    local b = UI.Button(f, tab.label, 88, 22, function() UI:Select(tab.key) end)
    b.key = tab.key
    b.row = tab.row or 1
    f.tabButtons[#f.tabButtons + 1] = b

    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints(content)
    p:Hide()
    pages[tab.key] = p
    BUILDERS[tab.key](p)
  end
  pages.group:HookScript("OnShow", function() UI:RefreshGroup() end)
  pages.players:HookScript("OnShow", function() UI:RefreshPlayers() end)
  self.frame = f
  self:Layout(nil)
  UI:Select("dungeon")
  UI:UpdateStatus()
end

-- section = nil  -> full window: all six section tabs + tool tabs (opened from /sdr or minimap)
-- section = kind -> docked: only that section's tab + tool tabs
function UI:Layout(section)
  local f = self.frame
  self.section = section
  local col = { 0, 0 }
  for _, b in ipairs(f.tabButtons) do
    b:ClearAllPoints()
    if section then
      -- one row: [current section] [Players] [Notes] [My Group] [Settings]
      local show = b.row == 2 or b.key == section or (section == "dungeon" and b.key == "mplus")
      b:SetShown(show)
      if show then
        b:SetPoint("TOPLEFT", 14 + col[1] * 92, -40)
        col[1] = col[1] + 1
      end
    else
      b:Show()
      b:SetPoint("TOPLEFT", 14 + col[b.row] * 92, b.row == 1 and -40 or -66)
      col[b.row] = col[b.row] + 1
    end
  end
  local top = section and -70 or -96
  f.scroll:ClearAllPoints()
  f.scroll:SetPoint("TOPLEFT", 4, top)
  f.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  f:SetHeight((section and 70 or 96) + 418)
  if section then
    f.title:SetText("Seviath's Dungeons & Raids |cffffffff- " .. (TAB_LABEL[section] or "") .. "|r")
  else
    f.title:SetText("Seviath's Dungeons & Raids")
  end
end

local MORE_TEXT = {
  mplus = "Key list",
  quest = "Zone list",
  raid = "Raid list",
  dungeon = "Dungeon list",
  delve = "Delve list",
}

function UI:UpdateMoreHint()
  local f = self.frame
  if not f or not f.more then return end
  local range = f.scroll:GetVerticalScrollRange() or 0
  local atEnd = f.scroll:GetVerticalScroll() >= range - 4
  if range > 4 and not atEnd then
    local what = MORE_TEXT[self.current]
    f.more.text:SetText("|TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:16:16|t  Scroll down for more"
      .. (what and ("  -  " .. what) or "") .. "  |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:16:16|t")
    f.more:Show()
  else
    f.more:Hide()
  end
end

function UI:Select(key)
  self.current = key
  if self.frame and self.frame.scroll then
    self.frame.scroll:SetVerticalScroll(0)
    local p = pages[key]
    self.frame.content:SetHeight(math.max(p and p.SDRHeight or 0, 410))
    C_Timer.After(0, function() UI:UpdateMoreHint() end)
  end
  for k, p in pairs(pages) do p:SetShown(k == key) end
  for _, b in ipairs(self.frame.tabButtons) do
    b.selected = b.key == key
    b.text:SetTextColor(1, 1, 1)
    UI.Paint(b)
  end
end

-- Premade Groups section that's open right now (Questing, Delves, ...), or nil
local function CurrentSection()
  local panel = LFGListFrame and LFGListFrame.SearchPanel
  local cat = panel and panel:IsVisible() and panel.categoryID
  local kind = cat and ns.KindForCategory and ns.KindForCategory(cat)
  return kind and pages[kind] and kind or nil
end

-- Called when you click into a section: docked window shows that section only
function UI:SyncTab()
  if not self.frame or not self.frame:IsShown() or not self.docked then return end
  local section = CurrentSection()
  if section and section ~= self.section then
    self:Layout(section)
    self:Select(section)
  end
end

-- Undocked: a normal floating window with every tab
local function Float(f)
  if UI.docked then
    f:ClearAllPoints()
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    UI.docked = false
  end
  UI:Layout(nil)
end

function UI:Dock()
  if not PVEFrame or ns.db.dock == "OFF" then return end
  self:Build() -- pages must exist before we can look up the section
  local section = CurrentSection()
  if not section then return end
  local f = self.frame
  f:ClearAllPoints()
  self:Layout(section)
  local below = PVEFrame:GetBottom()
  -- Blizzard's "Dungeons & Raids / Player vs. Player" tabs hang ~34px below the frame
  local TAB_GAP = 36
  local space = below and (below * PVEFrame:GetEffectiveScale() / f:GetEffectiveScale() - TAB_GAP - 6) or 0
  if ns.db.dock == "BOTTOM" and space >= 200 then
    f:SetPoint("TOPLEFT", PVEFrame, "BOTTOMLEFT", 0, -TAB_GAP)
    -- never taller than the room below, so it can't slide up over Sign Up / the list
    f:SetHeight(math.min(f:GetHeight(), space))
  else
    -- Sit to the right of Raider.IO's profile card when it's showing there
    local anchor = PVEFrame
    local rio = _G.RaiderIO_ProfileTooltip
    if rio and rio.IsShown and rio:IsShown() and rio:GetLeft() and PVEFrame:GetRight()
      and rio:GetLeft() >= PVEFrame:GetRight() - 10 then
      anchor = rio
    end
    f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
  end
  f:SetFrameStrata(PVEFrame:GetFrameStrata() or "HIGH")
  self.docked = true
  self:Select(section)
  f:Show()
  self:UpdateStatus()
end

function UI:Show(key)
  self:Build()
  Float(self.frame)
  self.frame:Show()
  if key then self:Select(key) end
end

function UI:Toggle()
  self:Build()
  if self.frame:IsShown() then
    self.frame:Hide()
  elseif CurrentSection() and ns.db.dock ~= "OFF" then
    self:Dock()
  else
    Float(self.frame)
    self.frame:Show()
    local section = CurrentSection()
    if section then self:Select(section) end
  end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local mmButton

local function PlaceMinimap()
  local a = math.rad(ns.db.minimap.angle or 215)
  local r = (Minimap:GetWidth() / 2) + 6
  mmButton:ClearAllPoints()
  mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function UI:UpdateMinimap()
  if not mmButton then return end
  mmButton:SetShown(ns.db.minimap.show)
end

local function CreateMinimapButton()
  mmButton = CreateFrame("Button", "SDRMinimapButton", Minimap)
  mmButton:SetSize(31, 31)
  mmButton:SetFrameStrata("MEDIUM")
  mmButton:SetFrameLevel(8)
  mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = mmButton:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
  local border = mmButton:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetVertexColor(C[1], C[2], C[3])
  mmButton:RegisterForClicks("AnyUp")
  mmButton:RegisterForDrag("LeftButton")
  mmButton:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then UI:Show("group") else UI:Toggle() end
  end)
  mmButton:SetScript("OnDragStart", function(s)
    s:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      PlaceMinimap()
    end)
  end)
  mmButton:SetScript("OnDragStop", function(s) s:SetScript("OnUpdate", nil) end)
  mmButton:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:SetText("Seviath's Dungeons & Raids", C[1], C[2], C[3])
    GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: my group", 1, 1, 1)
    GameTooltip:AddLine("Drag: move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  PlaceMinimap()
  UI:UpdateMinimap()
end

ns:On("PLAYER_LOGIN", CreateMinimapButton)

---------------------------------------------------------------------------
-- Premade Groups integration: SDR button + window that opens with the tab
---------------------------------------------------------------------------
ns:WhenReady(function()
  local panel = LFGListFrame and LFGListFrame.SearchPanel
  if not panel or not PVEFrame then return false end

  -- Small button in the panel's top-right corner, clear of the search box
  local b = UI.Button(panel, "|cff33e6ffSDR|r", 40, 18, function() UI:Toggle() end)
  b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
  -- "Filtered: 12 of 23 shown" next to the button, so you see the filters working
  local st = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  st:SetPoint("RIGHT", b, "LEFT", -6, 0)
  st:SetJustifyH("RIGHT")
  UI.panelStatus = st
  UI:UpdateStatus()
  b:SetFrameLevel(panel:GetFrameLevel() + 10)
  Tip(b, "Seviath's Dungeons & Raids filters")

  -- The search panel only appears after you CLICK a section (Questing, Raids...),
  -- so the window opens on that click, never on hover or on the category list.
  local function OnSectionOpened()
    if not ns.db.autoOpen or ns.db.dock == "OFF" then return end
    -- Short delay so the section is set and Raider.IO has placed its card
    C_Timer.After(0.05, function()
      if panel:IsVisible() then UI:Dock() end
    end)
  end
  local function CloseDocked()
    if UI.docked and UI.frame and UI.frame:IsShown() then UI.frame:Hide() end
  end

  panel:HookScript("OnShow", OnSectionOpened)
  panel:HookScript("OnHide", CloseDocked)      -- Back button
  LFGListFrame:HookScript("OnHide", CloseDocked)
  PVEFrame:HookScript("OnHide", CloseDocked)
  return true
end)
