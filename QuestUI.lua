-- SeviathsUsefulTools - quest tracker and quest log
--
-- Tracker: a movable panel (drag the title, Ctrl+mouse wheel on the title resizes) listing the quests of
-- your log by zone with their objectives and a map pin button for each. Click a quest to open it in
-- the quest log, Shift-click to hide it from the tracker.
-- Quest log: a window (/sfp log, the L key) with zones, details, objectives, "Pin on map", waypoint,
-- track / untrack, abandon and a link to the Codex guide page.
-- A "pin" is a big cyan marker drawn on the world map and minimap (and a Blizzard / TomTom waypoint
-- when the game allows one).

local ADDON, SFP = ...
local UI = {}
SFP.QuestUI = UI
local CY = SFP.CYAN
local CYHEX = "|c" .. SFP.CYAN_HEX
local min, max = math.min, math.max

local function QM() return SFP.QuestMarkers end
local function safe(fn, ...)
    if not fn then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

local function backdrop(f, r, g, b, a, br, bg_, bb, ba)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(br, bg_, bb, ba)
end

local function levelColor(level)
    local c = GetQuestDifficultyColor and level and level > 0 and GetQuestDifficultyColor(level)
    if c then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

local function objectives(qid)
    if C_QuestLog and C_QuestLog.GetQuestObjectives then return safe(C_QuestLog.GetQuestObjectives, qid) or {} end
    return {}
end

---------------------------------------------------------------------------
-- pin a quest on the map
---------------------------------------------------------------------------
function UI:PinQuest(qid, openMap)
    local q = QM()
    local loc = q and q:Locate(qid)
    if not loc then
        SFP:Print("No position known for this quest yet.")
        return
    end
    q:SetPin(loc.m, loc.x, loc.y, loc.text, qid)
    if C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(loc.m) then
        pcall(function()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(loc.m, loc.x, loc.y))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        end)
    end
    if _G.TomTom and TomTom.AddWaypoint then pcall(TomTom.AddWaypoint, TomTom, loc.m, loc.x, loc.y, { title = loc.text }) end
    SFP:Print(("Pinned: %s - %s %.1f, %.1f"):format(loc.text or "quest", SFP:ZoneName(loc.m), loc.x * 100, loc.y * 100))
    if openMap and SFP.OpenMapTo then SFP:OpenMapTo(loc.m) end
end

---------------------------------------------------------------------------
-- tracker
---------------------------------------------------------------------------
local tracker, lines = nil, {}

local function trackerLine(i)
    local l = lines[i]
    if l then return l end
    l = CreateFrame("Button", nil, tracker.body)
    l:SetHeight(14)
    l.text = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.text:SetPoint("LEFT", 0, 0)
    l.text:SetJustifyH("LEFT")
    l.pin = CreateFrame("Button", nil, l)
    l.pin:SetSize(14, 14)
    l.pin:SetPoint("RIGHT", 0, 0)
    l.pin.tex = l.pin:CreateTexture(nil, "ARTWORK")
    l.pin.tex:SetAllPoints()
    l.pin.tex:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    l.pin.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    l.pin:SetScript("OnClick", function(self) UI:PinQuest(self.qid) end)
    l.pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Pin this quest on the map")
        GameTooltip:Show()
    end)
    l.pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    l:RegisterForClicks("LeftButtonUp")
    l:SetScript("OnClick", function(self)
        if not self.qid then return end
        if IsShiftKeyDown() then
            SFP.db.questHidden = SFP.db.questHidden or {}
            SFP.db.questHidden[self.qid] = true
            UI:UpdateTracker()
        else
            UI:ShowQuest(self.qid)
        end
    end)
    lines[i] = l
    return l
end

function UI:UpdateTracker()
    if not tracker then return end
    local db = SFP.db
    if db.questTracker == false or not QM() or not QM().enabled then tracker:Hide(); return end
    tracker:Show()
    local list = QM():LogList()
    local hidden = db.questHidden or {}
    local n, y = 0, 0
    local width = tracker:GetWidth() - 16
    local shown = 0
    local function add(text, r, g, b, indent, qid, pin)
        n = n + 1
        local l = trackerLine(n)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", tracker.body, "TOPLEFT", indent or 0, -y)
        l:SetWidth(width - (indent or 0))
        l.text:SetWidth(width - (indent or 0) - (pin and 16 or 0))
        l.text:SetText(text)
        l.text:SetTextColor(r or 1, g or 1, b or 1)
        l.qid = qid
        l.pin.qid = qid
        l.pin:SetShown(pin and true or false)
        l:Show()
        local h = max(14, l.text:GetStringHeight() + 2)
        l:SetHeight(h)
        y = y + h + 1
    end
    if not db.trackerCollapsed then
        local zone
        for _, e in ipairs(list) do
            if not hidden[e.q] and n < 60 then
                shown = shown + 1
                if e.z ~= zone then
                    zone = e.z
                    add(zone, CY.r, CY.g, CY.b, 0)
                    y = y + 1
                end
                local r, g, b = levelColor(e.l)
                add("[" .. (e.l or "?") .. "] " .. e.t, r, g, b, 6, e.q, true)
                if e.c then
                    add("Ready to turn in", 0.3, 1, 0.3, 14, e.q)
                else
                    for _, o in ipairs(objectives(e.q)) do
                        if o.text and o.text ~= "" then
                            if o.finished then add(o.text, 0.35, 0.9, 0.35, 14, e.q) else add(o.text, 0.9, 0.9, 0.9, 14, e.q) end
                        end
                    end
                end
                y = y + 3
            end
        end
    end
    for i = n + 1, #lines do lines[i]:Hide() end
    tracker.count:SetText(#list .. "/25")
    tracker.body:SetHeight(max(1, y))
    tracker:SetHeight(24 + (db.trackerCollapsed and 0 or (y + 6)))
    tracker.toggle:SetText(db.trackerCollapsed and "+" or "-")
end

local function buildTracker()
    local db = SFP.db
    tracker = CreateFrame("Frame", "SeviathsUsefulToolsTracker", UIParent, "BackdropTemplate")
    tracker:SetSize(270, 60)
    tracker:SetMovable(true)
    tracker:SetClampedToScreen(true)
    tracker:SetFrameStrata("MEDIUM")
    backdrop(tracker, 0.03, 0.06, 0.08, 0.72, CY.r, CY.g, CY.b, 0.45)
    local pos = db.trackerPos
    tracker:ClearAllPoints()
    if pos then tracker:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -260) end
    tracker:SetScale(db.trackerScale or 1)

    local title = CreateFrame("Frame", nil, tracker)
    title:SetPoint("TOPLEFT"); title:SetPoint("TOPRIGHT", -22, 0); title:SetHeight(22)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() if not db.trackerLocked then tracker:StartMoving() end end)
    title:SetScript("OnDragStop", function()
        tracker:StopMovingOrSizing()
        local p, _, rp, x, y = tracker:GetPoint()
        db.trackerPos = { p, rp, x, y }
    end)
    title:EnableMouseWheel(true)
    title:SetScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown() then
            db.trackerScale = max(0.6, min(1.8, (db.trackerScale or 1) + delta * 0.05))
            tracker:SetScale(db.trackerScale)
        end
    end)
    title:SetScript("OnMouseUp", function(_, btn) if btn == "RightButton" then UI:ToggleLog() end end)
    title:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Quests")
        GameTooltip:AddLine("Drag: move   Ctrl+wheel: size", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: quest log", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Click a quest: open it   Shift-click: hide it", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    title:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tracker.title = title
    local t = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", 8, 0)
    t:SetText(CYHEX .. "Quests|r")
    tracker.count = title:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tracker.count:SetPoint("LEFT", t, "RIGHT", 6, 0)
    tracker.toggle = CreateFrame("Button", nil, tracker)
    tracker.toggle:SetSize(20, 20)
    tracker.toggle:SetPoint("TOPRIGHT", -2, -1)
    local tg = tracker.toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tg:SetPoint("CENTER")
    tracker.toggle.SetText = function(_, txt) tg:SetText(txt) end
    tracker.toggle:SetScript("OnClick", function()
        db.trackerCollapsed = not db.trackerCollapsed
        UI:UpdateTracker()
    end)
    tracker.body = CreateFrame("Frame", nil, tracker)
    tracker.body:SetPoint("TOPLEFT", 8, -26)
    tracker.body:SetPoint("TOPRIGHT", -8, -26)
    tracker.body:SetHeight(10)
end

-- the Blizzard and Questie trackers give way to this one
function UI:ApplyReplace()
    local on = SFP.db.questTracker ~= false and QM() and QM().enabled
    for _, name in ipairs({ "ObjectiveTrackerFrame", "WatchFrame", "QuestWatchFrame" }) do
        local f = _G[name]
        if f and f.SetAlpha then
            f:SetAlpha(on and 0 or 1)
            if f.EnableMouse then pcall(f.EnableMouse, f, not on) end
        end
    end
    if on and _G.Questie and Questie.db and Questie.db.profile and Questie.db.profile.trackerEnabled then
        local loader = _G.QuestieLoader
        local tr = loader and loader.ImportModule and safe(function() return loader:ImportModule("QuestieTracker") end)
        Questie.db.profile.trackerEnabled = false
        if tr and tr.Disable then pcall(tr.Disable, tr) end
        SFP:Print("Questie's tracker is off: this addon shows the quest tracker now.")
    end
end

function UI:Command(arg)
    local a = (arg or ""):lower()
    if a == "lock" then
        SFP.db.trackerLocked = not SFP.db.trackerLocked
        SFP:Print("Tracker " .. (SFP.db.trackerLocked and "locked" or "unlocked"))
    elseif a == "reset" then
        SFP.db.trackerPos, SFP.db.trackerScale, SFP.db.questHidden = nil, 1, {}
        if tracker then
            tracker:ClearAllPoints(); tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -260); tracker:SetScale(1)
        end
        self:UpdateTracker()
        SFP:Print("Tracker position and size reset.")
    elseif a == "off" or a == "on" then
        SFP.db.questTracker = (a == "on")
        self:ApplyReplace(); self:UpdateTracker()
    else
        SFP:Print("/sfp tracker lock | reset | off | on")
    end
end

---------------------------------------------------------------------------
-- quest log window
---------------------------------------------------------------------------
local log, rows = nil, {}
local selected
local flat = {}
local ROWS = 21
local offset = 0
local abandonArmed = 0

local function buildFlat()
    wipe(flat)
    local collapsed = SFP.db.logCollapsed or {}
    local zone
    for _, e in ipairs(QM():LogList()) do
        if e.z ~= zone then
            zone = e.z
            flat[#flat + 1] = { header = true, z = zone }
        end
        if not collapsed[e.z] then flat[#flat + 1] = e end
    end
end

local function detailFor(e)
    local QD = _G.QuestDB
    local t = {}
    local r, g, b = levelColor(e.l)
    t[#t + 1] = string.format("|cff%02x%02x%02x[%s] %s|r", r * 255, g * 255, b * 255, e.l or "?", e.t)
    t[#t + 1] = "|cff909090" .. (e.z or "") .. "|r"
    t[#t + 1] = e.c and "|cff40ff40Ready to turn in|r" or "|cffffd24aIn progress|r"
    local desc, obj
    if SelectQuestLogEntry and GetQuestLogQuestText and e.i then
        pcall(SelectQuestLogEntry, e.i)
        local ok, d, o = pcall(GetQuestLogQuestText)
        if ok then desc, obj = d, o end
    end
    t[#t + 1] = "\n" .. CYHEX .. "Objectives|r"
    local any = false
    for _, o in ipairs(objectives(e.q)) do
        if o.text and o.text ~= "" then
            any = true
            t[#t + 1] = (o.finished and "|cff59e659" or "|cffffffff") .. o.text .. "|r"
        end
    end
    if not any then
        local ot = QD and safe(QD.objectivesText, e.q)
        if ot and #ot > 0 then t[#t + 1] = table.concat(ot, "\n") elseif obj and obj ~= "" then t[#t + 1] = obj end
    end
    local loc = QM():Locate(e.q)
    if loc then
        t[#t + 1] = "\n" .. CYHEX .. (e.c and "Where to turn in" or "Where to go") .. "|r"
        t[#t + 1] = (loc.text or "") .. "\n" .. SFP:ZoneName(loc.m) .. (" %.1f, %.1f"):format(loc.x * 100, loc.y * 100)
    end
    if desc and desc ~= "" then
        t[#t + 1] = "\n" .. CYHEX .. "Story|r"
        t[#t + 1] = "|cffc8c8c8" .. desc .. "|r"
    end
    return table.concat(t, "\n")
end

function UI:RefreshLog()
    if not log or not log:IsShown() then return end
    buildFlat()
    local maxOff = max(0, #flat - ROWS)
    offset = min(offset, maxOff)
    for i = 1, ROWS do
        local row, e = rows[i], flat[offset + i]
        if e then
            row.e = e
            if e.header then
                row.text:SetText(CYHEX .. ((SFP.db.logCollapsed or {})[e.z] and "+ " or "- ") .. "|r" .. e.z)
                row.hl:Hide()
            else
                local r, g, b = levelColor(e.l)
                row.text:SetText("   [" .. (e.l or "?") .. "] " .. e.t .. (e.c and "  |cff40ff40*|r" or ""))
                row.text:SetTextColor(r, g, b)
                row.hl:SetShown(selected == e.q)
            end
            if e.header then row.text:SetTextColor(1, 1, 1) end
            row:Show()
        else
            row:Hide()
        end
    end
    local e
    for _, x in ipairs(QM():LogList()) do if x.q == selected then e = x end end
    if e then
        log.detail:SetText(detailFor(e))
        log.btnTrack.text:SetText((SFP.db.questHidden or {})[e.q] and "Track" or "Untrack")
        for _, b in ipairs(log.buttons) do b:Show() end
    else
        log.detail:SetText("|cff808080Pick a quest on the left.|r")
        for _, b in ipairs(log.buttons) do b:Hide() end
    end
    log.count:SetText(#QM():LogList() .. "/25 quests")
end

function UI:ShowQuest(qid)
    selected = qid
    if not log then self:BuildLog() end
    log:Show()
    for _, e in ipairs(QM():LogList()) do
        if e.q == qid then SFP.db.logCollapsed = SFP.db.logCollapsed or {}; SFP.db.logCollapsed[e.z] = nil end
    end
    self:RefreshLog()
end

local function button(parent, text, w, fn)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 22)
    backdrop(b, 0.06, 0.18, 0.22, 0.95, CY.r, CY.g, CY.b, 0.6)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.1, 0.35, 0.42, 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.06, 0.18, 0.22, 0.95) end)
    return b
end

function UI:BuildLog()
    log = CreateFrame("Frame", "SeviathsUsefulToolsQuestLog", UIParent, "BackdropTemplate")
    log:SetSize(700, 470)
    log:SetPoint("CENTER")
    log:SetFrameStrata("DIALOG")
    log:SetToplevel(true)
    log:SetMovable(true)
    log:SetClampedToScreen(true)
    log:EnableMouse(true)
    backdrop(log, 0.03, 0.06, 0.08, 0.97, CY.r, CY.g, CY.b, 0.6)
    tinsert(UISpecialFrames, "SeviathsUsefulToolsQuestLog")
    local bar = CreateFrame("Frame", nil, log)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT", -34, 0); bar:SetHeight(28)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() log:StartMoving() end)
    bar:SetScript("OnDragStop", function() log:StopMovingOrSizing() end)
    local tt = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tt:SetPoint("LEFT", 12, 0)
    tt:SetText(CYHEX .. "Seviaths|r Quest log")
    log.count = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    log.count:SetPoint("LEFT", tt, "RIGHT", 10, 0)
    local close = CreateFrame("Button", nil, log, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetFrameLevel(log:GetFrameLevel() + 30)
    close:SetScript("OnClick", function() log:Hide() end)

    local list = CreateFrame("Frame", nil, log)
    list:SetPoint("TOPLEFT", 10, -36)
    list:SetSize(250, ROWS * 20)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, d) offset = max(0, offset - d * 3); UI:RefreshLog() end)
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(250, 20)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints(); row.hl:SetColorTexture(CY.r, CY.g, CY.b, 0.22); row.hl:Hide()
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 2, 0); row.text:SetWidth(244); row.text:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            local e = self.e
            if not e then return end
            if e.header then
                SFP.db.logCollapsed = SFP.db.logCollapsed or {}
                SFP.db.logCollapsed[e.z] = not SFP.db.logCollapsed[e.z] or nil
            else
                selected = e.q
            end
            UI:RefreshLog()
        end)
        rows[i] = row
    end
    log.detail = log:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    log.detail:SetPoint("TOPLEFT", 276, -40)
    log.detail:SetWidth(408)
    log.detail:SetJustifyH("LEFT"); log.detail:SetJustifyV("TOP")

    log.buttons = {}
    local function qEntry()
        for _, x in ipairs(QM():LogList()) do if x.q == selected then return x end end
    end
    local specs = {
        { "Pin on map", 100, function() if selected then UI:PinQuest(selected, true) end end },
        { "Waypoint", 80, function() if selected then UI:PinQuest(selected, false) end end },
        { "Untrack", 70, function()
            if not selected then return end
            SFP.db.questHidden = SFP.db.questHidden or {}
            SFP.db.questHidden[selected] = not SFP.db.questHidden[selected] or nil
            UI:UpdateTracker(); UI:RefreshLog()
        end },
        { "Guide", 60, function()
            local cx = _G.SeviathsCodex
            if cx and selected then
                cx:StartIndexing(); cx:Open()
                local key = "quest:" .. selected
                if cx:Get(key) then cx:ShowEntry(key) else cx:Toggle(QM() and (qEntry() or {}).t or "") end
            end
        end },
        { "Abandon", 70, function(self)
            local e = qEntry()
            if not e then return end
            if GetTime() - abandonArmed > 4 then
                abandonArmed = GetTime()
                self.text:SetText("Sure?")
                C_Timer.After(4, function() self.text:SetText("Abandon") end)
                return
            end
            abandonArmed = 0
            self.text:SetText("Abandon")
            if C_QuestLog and C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest then
                pcall(C_QuestLog.SetSelectedQuest, e.q); pcall(C_QuestLog.SetAbandonQuest); pcall(C_QuestLog.AbandonQuest)
            elseif SelectQuestLogEntry and SetAbandonQuest then
                pcall(SelectQuestLogEntry, e.i); pcall(SetAbandonQuest); pcall(AbandonQuest)
            end
        end },
    }
    local x = 276
    for _, s in ipairs(specs) do
        local b = button(log, s[1], s[2], s[3])
        b:SetPoint("BOTTOMLEFT", x, 12)
        x = x + s[2] + 6
        log.buttons[#log.buttons + 1] = b
        if s[1] == "Untrack" then log.btnTrack = b end
    end
    log:SetScript("OnShow", function() UI:RefreshLog() end)
    log:Hide()
end

function UI:ToggleLog()
    if not log then self:BuildLog() end
    if log:IsShown() then log:Hide() else log:Show() end
end

---------------------------------------------------------------------------
-- start
---------------------------------------------------------------------------
SFP:OnLogin(function()
    if SFP.db.questTracker == nil then SFP.db.questTracker = true end
    if SFP.db.questLogReplace == nil then SFP.db.questLogReplace = true end
    buildTracker()
    C_Timer.After(12, function()
        UI:ApplyReplace()
        UI:UpdateTracker()
    end)
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "UNIT_QUEST_LOG_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    local pend
    ev:SetScript("OnEvent", function()
        if pend then return end
        pend = true
        C_Timer.After(0.8, function()
            pend = false
            UI:UpdateTracker(); UI:RefreshLog()
        end)
    end)
    -- the L key / Blizzard quest log opens ours instead
    if _G.ToggleQuestLog then
        hooksecurefunc("ToggleQuestLog", function()
            if SFP.db.questLogReplace == false or not (QM() and QM().enabled) then return end
            local f = _G.QuestLogFrame
            if f and f:IsShown() then pcall(HideUIPanel, f) end
            UI:ToggleLog()
        end)
    end
end)
