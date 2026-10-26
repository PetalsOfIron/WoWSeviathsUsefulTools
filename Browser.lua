-- SeviathsUsefulTools - farm browser + settings (opened from the minimap button or /sfp)
-- Lists every expansion's farm zones and old instances with items, AH value,
-- drop chance for BoEs, entrance coordinates and Wowhead links.

local _, SFP = ...

local frame, scroll, content, rows, expButtons, checks, statusText, minBox
local ROW_H = 18
local WIDTH, HEIGHT = 560, 540

---------------------------------------------------------------------------
-- Row pool
---------------------------------------------------------------------------
local function getRow(i)
    local row = rows[i]
    if row then row:Show(); return row end
    row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetJustifyH("LEFT")
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetJustifyH("RIGHT")
    row.extra = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.extra:SetJustifyH("LEFT")
    row.wh = CreateFrame("Button", nil, row)
    row.wh:SetSize(54, ROW_H - 2)
    row.wh:SetPoint("RIGHT", -2, 0)
    row.wh.text = row.wh:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.wh.text:SetPoint("CENTER")
    row.wh:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")
    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")

    row:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:AddLine("Shift-click: link in chat   Right-click: Wowhead link", 0, 0.9, 1)
            GameTooltip:Show()
        elseif self.hint then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.hint, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if self.itemID then
            if button == "RightButton" then
                SFP:ShowWowhead(self.itemID)
            elseif IsModifiedClick("CHATLINK") then
                local _, link = C_Item.GetItemInfo(self.itemID)
                if link then ChatEdit_InsertLink(link) end
            end
        elseif self.onClick then
            self.onClick(button)
        end
    end)
    rows[i] = row
    return row
end

local function resetRow(row, y, indent)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    row.itemID, row.onClick, row.hint = nil, nil, nil
    row.bg:SetColorTexture(0, 0, 0, 0)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", indent, 0)
    row.left:ClearAllPoints()
    row.right:ClearAllPoints()
    row.extra:ClearAllPoints()
    row.extra:SetText("")
    row.wh:Hide()
end

---------------------------------------------------------------------------
-- List building
---------------------------------------------------------------------------
local function sortedItems(list)
    local copy = {}
    for i, id in ipairs(list) do copy[i] = id end
    table.sort(copy, function(a, b)
        local pa, pb = SFP:GetPrice(a) or -1, SFP:GetPrice(b) or -1
        if pa ~= pb then return pa > pb end
        local ka = SFP.KindOrder[(SFP.Items[a] or {}).kind] or 9
        local kb = SFP.KindOrder[(SFP.Items[b] or {}).kind] or 9
        if ka ~= kb then return ka < kb end
        return a < b
    end)
    return copy
end

local function render()
    if not frame or not frame:IsShown() then return end
    local exp = SFP.Expansions[SFP.db.browser.exp] or SFP.Expansions[1]
    local n, y = 0, 0

    local function header(text, right, color, onClick, hint)
        n = n + 1
        local row = getRow(n)
        resetRow(row, y, 4)
        row.bg:SetColorTexture(color[1], color[2], color[3], color[4] or 0.18)
        row.icon:Hide()
        row.left:SetPoint("LEFT", 6, 0)
        row.left:SetText(text)
        row.right:SetPoint("RIGHT", -8, 0)
        row.right:SetText(right or "")
        row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
        row.onClick, row.hint = onClick, hint
        y = y - ROW_H - 2
    end

    local function item(id)
        n = n + 1
        local row = getRow(n)
        resetRow(row, y, 22)
        row.itemID = id
        row.icon:Show()
        row.icon:SetTexture(SFP:ItemIcon(id))
        row.left:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
        row.left:SetText(SFP:ItemName(id))
        row.right:SetPoint("RIGHT", row.wh, "LEFT", -6, 0)
        local price = SFP:GetPrice(id)
        local kinfo = SFP.Items[id]
        if not price and kinfo and (kinfo.kind == "mount" or kinfo.kind == "toy") then
            row.right:SetText("|cffa335ee" .. SFP.KindLabel[kinfo.kind] .. "|r")
        else
            row.right:SetText(SFP:FormatPrice(price))
        end
        local extra = SFP:ItemExtra(id)
        if extra then
            row.extra:SetPoint("LEFT", row.left, "RIGHT", 8, 0)
            row.extra:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
            row.extra:SetText(extra)
        end
        row.left:SetWidth(math.min(row.left:GetUnboundedStringWidth() + 2, 230))
        row.wh:Show()
        row.wh.text:SetText("|c" .. SFP.CYAN_HEX .. "Wowhead|r")
        row.wh:SetScript("OnClick", function() SFP:ShowWowhead(id) end)
        y = y - ROW_H
    end

    -- zones, optionally best-value first
    local zones = {}
    for i, z in ipairs(exp.zones) do zones[i] = z end
    if SFP.db.browser.sortByValue then
        table.sort(zones, function(a, b) return SFP:ZoneValue(a) > SFP:ZoneValue(b) end)
    end

    for _, zone in ipairs(zones) do
        local lit = SFP:IsValuableZone(zone.map)
        local name = (lit and ("|c" .. SFP.CYAN_HEX) or "|cff9d9d9d") .. SFP:ZoneName(zone.map) .. "|r"
        local v = SFP:ZoneValue(zone)
        local right = (v > 0 and ("best " .. SFP:FormatPrice(v) .. "  ") or "") .. "|cffffd100[map]|r"
        header(name, right, lit and { 0, 0.9, 1, 0.16 } or { 0.4, 0.4, 0.4, 0.12 },
            function() SFP:OpenMapTo(zone.map) end, "Click: open this zone on the world map")
        for _, id in ipairs(sortedItems(zone.items)) do item(id) end
        if not zone.rareOnly then -- general line for random green/blue BoE world drops
            local boeText, boeWhere = SFP:RandomBoeText(zone.map)
            n = n + 1
            local row = getRow(n)
            resetRow(row, y, 22)
            row.icon:Show()
            row.icon:SetTexture("Interface\\Icons\\INV_Chest_Chain") -- generic armor icon
            row.left:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
            row.left:SetText(boeText)
            row.right:SetPoint("RIGHT", -8, 0)
            row.right:SetText("|cffaaaaaa" .. boeWhere .. "|r")
            row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
            row.hint = "Random green and blue BoE gear can drop from any mob in this zone. Sell it on the AH (transmog) or disenchant it."
            y = y - ROW_H
        end
        for _, s in ipairs(zone.spawns or {}) do
            local names = {}
            for i, id in ipairs(s.items) do names[i] = SFP:ItemName(id) end
            if #names == 0 and s.note and not s.hunter then names[1] = s.note end
            if s.gather then
                local ore = s.gather == "ore"
                header(SFP:KindIconTag(s.gather, 14) .. " " .. (ore and "|cffffb366Mining: " or "|cff4dff8cHerbalism: ") .. s.name ..
                    "|r  |cff40ff40best zone for " .. SFP:ItemName(s.items[1]) .. "|r",
                    string.format("|cffffd100%.1f, %.1f|r  [waypoint]", s.hx * 100, s.hy * 100),
                    ore and { 1, 0.7, 0.35, 0.07 } or { 0.3, 1, 0.55, 0.07 },
                    function() SFP:SetWaypoint(zone.map, s.hx, s.hy, s.name) end,
                    (s.nodes or "?") .. " recorded nodes here - the most of any zone.\n\nClick: waypoint (the node area glows on the zone map)")
            elseif s.hunter then
                header(SFP.HUNTER_ICON .. " |c" .. SFP.HUNTER_HEX .. "Hunter tame: " .. s.name .. "|r  |cffaaaaaa" ..
                    (s.hunter == "spirit" and "spirit beast (Beast Mastery)" or "unique-looking pet") .. "|r",
                    string.format("|cffffd100%.1f, %.1f|r  [waypoint]", s.hx * 100, s.hy * 100), { 0.55, 0.85, 0.25, 0.07 },
                    function() SFP:SetWaypoint(zone.map, s.hx, s.hy, s.name) end,
                    (SFP.HUNTER_TYPE[s.hunter] or "Hunter tame") .. "\n\n" .. (s.note or "") ..
                    "\n\nClick: waypoint (its spawn points glow green on the zone map)")
            elseif s.rare then
                header((s.grind and (SFP.STAR .. " ") or "") .. "|cffff9933Rare: " .. s.name .. "|r  |cffaaaaaa" .. table.concat(names, ", ") .. "|r",
                    string.format("|cffffd100%.1f, %.1f|r  [waypoint]", s.hx * 100, s.hy * 100), { 1, 0.5, 0, 0.07 },
                    function() SFP:SetWaypoint(zone.map, s.hx, s.hy, s.name) end,
                    "Click: waypoint to this rare (its spawn points glow orange on the zone map)")
            else
                local bestTxt = ""
                if s.bestFor then
                    local bn = {}
                    for i, id in ipairs(s.bestFor) do bn[i] = SFP:ItemName(id) end
                    bestTxt = "  |cff40ff40best spot: " .. table.concat(bn, ", ") .. "|r"
                end
                header((s.grind and (SFP.STAR .. " ") or "") .. "|c" .. SFP.CYAN_HEX .. "Farm spot: " .. s.name .. "|r  |cffaaaaaa" .. table.concat(names, ", ") .. "|r" .. bestTxt,
                    string.format("|cffffd100%.1f, %.1f|r  [waypoint]", s.hx * 100, s.hy * 100), { 0, 0.9, 1, 0.05 },
                    function() SFP:SetWaypoint(zone.map, s.hx, s.hy, s.name) end,
                    "Click: waypoint to this farm spot (all spawn points glow cyan on the zone map)")
            end
        end
        for _, inst in ipairs(zone.instances or {}) do
          if #inst.items > 0 then
            local e = SFP:FindEntrance(inst)
            local coords = e and string.format("|cffffd100%.1f, %.1f|r  [waypoint]", e.x * 100, e.y * 100) or "|cff808080entrance on map|r"
            header("|T" .. (inst.kind == "raid" and SFP.RAID_ICON or SFP.DUNGEON_ICON) .. ":14|t |cffff8000" .. (inst.kind == "raid" and "Raid: " or "Dungeon: ") .. inst.name .. "|r", coords, { 1, 0.5, 0, 0.12 },
                function()
                    if e then SFP:SetWaypoint(e.map, e.x, e.y, inst.name) else SFP:OpenMapTo(inst.map) end
                end, e and "Click: set a waypoint to the entrance" or "Click: open the zone map")
            for _, id in ipairs(sortedItems(inst.items)) do item(id) end
          end
        end
        y = y - 6
    end

    -- instances in zones that aren't farm zones themselves (e.g. Karazhan)
    for _, inst in ipairs(exp.instances or {}) do
        if not SFP.zoneByMap[inst.map] then
            local e = SFP:FindEntrance(inst)
            local coords = e and string.format("|cffffd100%s %.1f, %.1f|r  [waypoint]", SFP:ZoneName(e.map), e.x * 100, e.y * 100)
                or SFP:ZoneName(inst.map)
            header("|cffff8000" .. (inst.kind == "raid" and "Raid: " or "Dungeon: ") .. inst.name .. "|r", coords, { 1, 0.5, 0, 0.12 },
                function()
                    if e then SFP:SetWaypoint(e.map, e.x, e.y, inst.name) else SFP:OpenMapTo(inst.map) end
                end, "Click: waypoint / open map")
            for _, id in ipairs(sortedItems(inst.items)) do item(id) end
            y = y - 6
        end
    end

    if exp.anywhere and #exp.anywhere > 0 then
        header("|cffffffffAnywhere in " .. exp.name .. "|r", "", { 1, 1, 1, 0.08 })
        for _, id in ipairs(sortedItems(exp.anywhere)) do item(id) end
    end

    for i = n + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(-y + 10, 10))

    -- expansion tabs + status
    for i, b in ipairs(expButtons) do
        if i == SFP.db.browser.exp then b:LockHighlight(); b.sel:Show() else b:UnlockHighlight(); b.sel:Hide() end
    end
    local scanning, done, total = SFP:IsScanning()
    if scanning then
        statusText:SetText(string.format("Scanning AH... %d/%d", done, total))
    elseif (SFP.db.lastScan or 0) > 0 then
        local mins = math.floor((time() - SFP.db.lastScan) / 60)
        statusText:SetText(mins < 120 and ("AH prices: " .. mins .. " min old") or ("AH prices: " .. math.floor(mins / 60) .. " h old"))
    else
        statusText:SetText("AH prices load the first time you open the auction house")
    end
    for _, cb in ipairs(checks) do cb:SetChecked(cb.get()) end
    if not minBox:HasFocus() then minBox:SetText(tostring(math.floor((SFP.db.minValue or 0) / 10000))) end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function makeCheck(parent, label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", x, y)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    fs:SetText(label)
    cb.get = get
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); SFP:RefreshAll() end)
    checks[#checks + 1] = cb
    return cb
end

local function build()
    rows, expButtons, checks = {}, {}, {}
    local c = SFP.CYAN

    frame = CreateFrame("Frame", "SeviathsUsefulToolsBrowser", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(0.02, 0.04, 0.06, 0.95)
    frame:SetBackdropBorderColor(c.r, c.g, c.b, 0.9)
    tinsert(UISpecialFrames, "SeviathsUsefulToolsBrowser")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("|c" .. SFP.CYAN_HEX .. "Seviaths|rFarmPack  |cff808080v" .. SFP.VERSION .. "|r")
    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("LEFT", title, "RIGHT", 8, -1)
    sub:SetText("farm spots + rares, Classic to Mists of Pandaria · data from wowhead.com")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- expansion tabs: 2 rows of 5
    for i, exp in ipairs(SFP.Expansions) do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(86, 20)
        local col, line = (i - 1) % 6, math.floor((i - 1) / 6)
        b:SetPoint("TOPLEFT", 12 + col * 90, -36 - line * 22)
        b:SetText(exp.short)
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetColorTexture(c.r, c.g, c.b, 1)
        b.sel:SetHeight(2)
        b.sel:SetPoint("BOTTOMLEFT", 3, 1)
        b.sel:SetPoint("BOTTOMRIGHT", -3, 1)
        b:SetScript("OnClick", function()
            SFP.db.browser.exp = i
            scroll:SetVerticalScroll(0)
            render()
        end)
        expButtons[i] = b
    end

    -- settings
    local db = SFP.db
    local sy = -84
    makeCheck(frame, "World map overlay", 10, sy, function() return db.mapOverlay end, function(v) db.mapOverlay = v end)
    makeCheck(frame, "Farm spots (glow)", 140, sy, function() return db.showSpawns end, function(v) db.showSpawns = v end)
    makeCheck(frame, "Whole-zone glow", 270, sy, function() return db.zoneFill end, function(v) db.zoneFill = v end)
    makeCheck(frame, "Zone item panel", 400, sy, function() return db.zonePanel end, function(v) db.zonePanel = v end)
    sy = sy - 22
    makeCheck(frame, "Minimap button", 10, sy, function() return not db.minimap.hide end, function(v) db.minimap.hide = not v end)
    makeCheck(frame, "Minimap glow", 140, sy, function() return db.minimapGlow end, function(v) db.minimapGlow = v end)
    makeCheck(frame, "Tooltip lines", 270, sy, function() return db.tooltip end, function(v) db.tooltip = v end)
    makeCheck(frame, "Best zones first", 400, sy, function() return db.browser.sortByValue end, function(v) db.browser.sortByValue = v end)
    sy = sy - 22

    makeCheck(frame, "Rare spots", 270, sy, function() return db.showRares end, function(v) db.showRares = v end)
    makeCheck(frame, "Hunter tames", 400, sy, function() return db.showHunter end, function(v) db.showHunter = v end)
    makeCheck(frame, "Mining", 10, sy - 22, function() return db.showMining end, function(v) db.showMining = v end)
    makeCheck(frame, "Herbalism", 140, sy - 22, function() return db.showHerbs end, function(v) db.showHerbs = v end)
    makeCheck(frame, "Dungeons", 270, sy - 22, function() return db.showDungeons end, function(v) db.showDungeons = v end)
    makeCheck(frame, "Raids", 400, sy - 22, function() return db.showRaids end, function(v) db.showRaids = v end)
    local minLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minLabel:SetPoint("TOPLEFT", 14, sy - 5)
    minLabel:SetText("Min zone value")
    minBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    minBox:SetSize(46, 18)
    minBox:SetPoint("LEFT", minLabel, "RIGHT", 8, 0)
    minBox:SetAutoFocus(false)
    minBox:SetNumeric(true)
    local g = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g:SetPoint("LEFT", minBox, "RIGHT", 3, 0)
    g:SetText("g")
    minBox:SetScript("OnEnterPressed", function(self)
        db.minValue = (tonumber(self:GetText()) or 0) * 10000
        self:ClearFocus()
        SFP:RefreshAll()
    end)
    minBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- AH status + scan
    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", 12, 12)
    local scan = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scan:SetSize(130, 20)
    scan:SetPoint("BOTTOMRIGHT", -12, 8)
    scan:SetText("Rescan AH prices")
    scan:SetScript("OnClick", function() SFP:StartScan(true) end)

    -- list
    scroll = CreateFrame("ScrollFrame", "SeviathsUsefulToolsBrowserScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -178)
    scroll:SetPoint("BOTTOMRIGHT", -30, 36)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 44, 10)
    scroll:SetScrollChild(content)

    frame:SetScript("OnShow", render)
    frame:Hide()
end

function SFP:ToggleBrowser()
    if not frame then build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

SFP:OnLogin(function() SFP:OnRefresh(render) end)
