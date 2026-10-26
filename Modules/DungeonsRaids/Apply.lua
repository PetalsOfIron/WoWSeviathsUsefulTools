-- Seviath's Dungeons & Raids - application templates, pending applications, invite alert
local _, ns = SFP_Module("DungeonsRaids")

---------------------------------------------------------------------------
-- Prefill the application note from a template
---------------------------------------------------------------------------
local function FillTemplate(dialog)
  local resultID = dialog and dialog.resultID
  if not ns.db or not ns.db.useTemplates or not resultID then return end
  local ok, r = pcall(ns.Analyze, ns, resultID)
  if not ok or not r then return end
  local key = (r.kind == "raid" and r.diff and ("raid" .. r.diff)) or r.kind
  local tpl = ns.db.templates[key]
  if not tpl or tpl == "" then return end
  local box = dialog.Description and (dialog.Description.EditBox or dialog.Description)
  if box and box.GetText and box.SetText and (box:GetText() or "") == "" then
    box:SetText(tpl)
  end
end

-- The apply dialog is a normal frame; filling it when it opens works across patches
ns:WhenReady(function()
  local dialog = LFGListApplicationDialog
  if not dialog then return false end
  dialog:HookScript("OnShow", function(self)
    C_Timer.After(0, function() FillTemplate(self) end)
  end)
  return true
end)

---------------------------------------------------------------------------
-- Pending applications panel
---------------------------------------------------------------------------
local panel
local appliedAt = {}

local function ListingName(id)
  local info = C_LFGList.GetSearchResultInfo(id)
  if not info then return "?", nil end
  local aid = info.activityID or (info.activityIDs and info.activityIDs[1])
  local act = aid and C_LFGList.GetActivityInfoTable(aid)
  return (act and (act.fullName or act.shortName)) or "?", ns.FullName(info.leaderName)
end

local function UpdatePanel()
  if not panel then return end
  if not ns.db.showPending or not C_LFGList.GetApplications then panel:Hide() return end
  local lines = {}
  for _, id in ipairs(C_LFGList.GetApplications() or {}) do
    local _, status = C_LFGList.GetApplicationInfo(id)
    if status == "applied" or status == "invited" then
      local actName, leader = ListingName(id)
      local t = appliedAt[id] and (GetTime() - appliedAt[id])
      local tStr = t and string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60)) or "--:--"
      local st = status == "invited" and "|cff40ff60INVITED|r" or "|cff999999waiting|r"
      local tag = leader and ns:TagShortFor(leader) or ""
      lines[#lines + 1] = string.format("|cff%s%s|r  %s  |cffcccccc%s|r %s  %s",
        ns.CYAN_HEX, tStr, actName, leader and ns.ShortName(leader) or "", tag, st)
    end
  end
  if #lines == 0 then panel:Hide() return end
  panel.text:SetText(table.concat(lines, "\n"))
  panel:SetHeight(34 + #lines * 14)
  panel:Show()
end
ns.UpdatePendingPanel = UpdatePanel

ns:On("PLAYER_LOGIN", function()
  panel = CreateFrame("Frame", "SDRPendingPanel", UIParent, "BackdropTemplate")
  panel:SetSize(360, 60)
  panel:SetPoint("TOP", 0, -140)
  panel:SetFrameStrata("HIGH")
  ns.UI.Skin(panel, 0.9)
  ns.UI.Movable(panel)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", 8, -6)
  title:SetText("Pending applications")
  title:SetTextColor(unpack(ns.CYAN))
  panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.text:SetPoint("TOPLEFT", 8, -22)
  panel.text:SetPoint("RIGHT", -8, 0)
  panel.text:SetJustifyH("LEFT")
  local elapsed = 0
  panel:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= 1 then elapsed = 0 UpdatePanel() end
  end)
  panel:Hide()
end)

ns:On("LFG_LIST_APPLICATION_STATUS_UPDATED", function(id, newStatus)
  if newStatus == "applied" then
    appliedAt[id] = GetTime()
  elseif newStatus == "invited" then
    if ns.db.inviteSound then
      PlaySound(SOUNDKIT.READY_CHECK, "Master")
      if FlashClientIcon then FlashClientIcon() end
    end
    local actName = ListingName(id)
    ns.Print("|cff40ff60Invited|r to " .. actName)
  elseif newStatus ~= "invited" then
    appliedAt[id] = nil
  end
  UpdatePanel()
end)
