-- SeviathsUsefulTools - main menu
-- One window for everything. Left and right click on the minimap button open it, so does /sut.
-- Sections: Home, Farm & Map, Guides (Codex), Groups, Guild, Learned data, Settings.

local ADDON, SFP = ...
local CY = SFP.CYAN
local CYHEX = "|c" .. SFP.CYAN_HEX

local frame
local navButtons, panes, current = {}, {}, nil

local SECTIONS = {
    { key = "home",     label = "Home" },
    { key = "farm",     label = "Farm & Map" },
    { key = "guides",   label = "Guides (Codex)" },
    { key = "groups",   label = "Groups" },
    { key = "guild",    label = "Guild" },
    { key = "know",     label = "Learned data" },
    { key = "settings", label = "Settings" },
}

local function backdrop(f, r, g, b, a, br, bg_, bb, ba)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(br, bg_, bb, ba)
end

local function mkButton(parent, text, w, fn, tip)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 22)
    backdrop(b, 0.06, 0.18, 0.22, 0.95, CY.r, CY.g, CY.b, 0.6)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnClick", function(self) fn(self) end)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.1, 0.35, 0.42, 1)
        if tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.06, 0.18, 0.22, 0.95); GameTooltip:Hide() end)
    return b
end

local function mkText(parent, text, x, y, w, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    if w then fs:SetWidth(w) end
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function mkCheck(parent, label, getter, setter, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    t:SetText(label)
    cb:SetHitRectInsets(0, -(t:GetStringWidth() + 6), 0, 0)   -- the label can be clicked too
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    cb.refresh = function() cb:SetChecked(getter() and true or false) end
    return cb
end

local function codex() return _G.SeviathsCodex end

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------
local function countKeys(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

local function buildHome(pane)
    mkText(pane, CYHEX .. "SeviathsUsefulTools|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "Everything in one place. Pick a section on the left:", 12, -36, 500)
    local list = {
        { "Farm & Map", "farm", "Glowing farm spots, rares and gathering routes on the world map, prices, layers." },
        { "Guides (Codex)", "guides", "How to do things: dungeons, raids, bosses, quests, mounts, pets, entrances, materials, gold." },
        { "Groups", "groups", "Raid buffs, tier tokens, player tags and notes for dungeons and raids." },
        { "Guild", "guild", "Find and invite players for your guild, charter signatures." },
        { "Learned data", "know", "Every monster, item, node and recipe the addon has learned from your play." },
        { "Settings", "settings", "Switches for the map, tooltips and learning." },
    }
    for i, e in ipairs(list) do
        local y = -64 - (i - 1) * 44
        mkButton(pane, e[1], 130, function() SFP:ShowMenuSection(e[2]) end):SetPoint("TOPLEFT", 12, y)
        mkText(pane, e[3], 152, y - 2, 360, "GameFontHighlightSmall"):SetTextColor(0.8, 0.8, 0.8)
    end
    pane.stats = mkText(pane, "", 12, -340, 500, "GameFontHighlightSmall")
    pane.refresh = function()
        local db = SFP.db
        pane.stats:SetText(("|cff808080Learned so far: %d monsters, %d items, %d gathering nodes, %d recipes. Saved for all your characters.|r")
            :format(countKeys(db.npcs), countKeys(db.knownItems), countKeys(db.objects), countKeys(db.recipes)))
    end
end

local function buildFarm(pane)
    mkText(pane, CYHEX .. "Farm & Map|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "Farm spots, rares, hunter tames and best gathering zones on the world map.", 12, -34, 500, "GameFontHighlightSmall")
    mkButton(pane, "Farm browser", 130, function() SFP:ToggleBrowser() end, "Expansions, zones, items with auction prices, coordinates"):SetPoint("TOPLEFT", 12, -58)
    mkButton(pane, "Open world map", 130, function() SFP:OpenMapTo(C_Map.GetBestMapForUnit("player") or 1) end):SetPoint("TOPLEFT", 150, -58)
    mkButton(pane, "Scan auction prices", 150, function() SFP:StartScan(true) end, "The auction house must be open"):SetPoint("TOPLEFT", 288, -58)
    mkText(pane, "Layers on the world map:", 12, -92, 400)
    local checks = {
        { "mapOverlay", "Show farm layer" }, { "showSpawns", "Monster farm spots" }, { "showRares", "Rares (mounts, pets)" },
        { "showHunter", "Hunter tames" }, { "showMining", "Mining zones" }, { "showHerbs", "Herb zones" },
        { "showDungeons", "Dungeon entrances" }, { "showRaids", "Raid entrances" }, { "showSpecial", "Special materials" },
        { "showGatherList", "Gathering list" }, { "showLabels", "Names on the map" }, { "learn", "Learn farm spots from my loot" },
        { "exactSpots", "Exact spot markers (not areas)" }, { "continentSpots", "Also on continent maps (crowded)" }, { "minimapSpots", "Also show spots on the minimap" },
    }
    pane.checks = {}
    for i, c in ipairs(checks) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local cb = mkCheck(pane, c[2], function() return SFP.db[c[1]] end, function(v) SFP.db[c[1]] = v; SFP:RefreshAll() end,
            12 + col * 250, -116 - row * 26)
        pane.checks[#pane.checks + 1] = cb
    end
    pane.refresh = function() for _, cb in ipairs(pane.checks) do cb.refresh() end end
end

local GUIDE_CATS = {
    { "guide", "New Player Guide", "Start here: classes, gear, professions, travel, gold" },
    { "dungeon", "Dungeons", "Every dungeon: how to enter, bosses, loot" },
    { "raid", "Raids", "Every raid: bosses, tactics, loot" },
    { "boss", "Bosses", "Boss abilities and how to beat them" },
    { "creature", "Monsters & Creatures", "Monsters, rares, tames, world bosses and their drops" },
    { "item", "Loot & Items", "Gear and items and how to get them" },
    { "entrance", "Entrances (How to Enter)", "Where and how to enter every dungeon and raid" },
    { "quest", "Quests (what to do)", "How to do the quests" },
    { "mount", "Mounts", "How to get every mount" },
    { "pet", "Battle Pets", "Where to find the pets" },
    { "achievement", "Achievements & Titles", "How to earn them" },
    { "material", "Materials (what for)", "What every material is used for" },
    { "mats", "Gold Farming", "How to make gold in Mists of Pandaria" },
}
local function buildGuides(pane)
    mkText(pane, CYHEX .. "Guides (Codex)|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "A guide to doing things: each part opens the Codex on that page.", 12, -34, 500, "GameFontHighlightSmall")
    local box = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    box:SetSize(260, 20)
    box:SetPoint("TOPLEFT", 18, -60)
    box:SetAutoFocus(false)
    box:SetScript("OnEnterPressed", function(self)
        local cx = codex()
        if cx then cx:StartIndexing(); cx:Toggle(self:GetText()) end
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    mkText(pane, "|cff808080search everything, press Enter|r", 290, -64, 220, "GameFontHighlightSmall")
    for i, c in ipairs(GUIDE_CATS) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        mkButton(pane, c[2], 245, function()
            local cx = codex()
            if cx then cx:StartIndexing(); cx:OpenCategory(c[1]) else SFP:Print("The Codex is not loaded.") end
        end, c[3]):SetPoint("TOPLEFT", 12 + col * 255, -92 - row * 30)
    end
end

local function buildGroups(pane)
    mkText(pane, CYHEX .. "Groups|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "Tools for dungeon and raid groups: your group's raid buffs and tier tokens, tags and notes on players you met, filters for Premade Groups when the game offers them.", 12, -34, 500, "GameFontHighlightSmall")
    mkButton(pane, "Open Dungeons & Raids", 190, function() SFP:RunModule("SEVIATHSDUNGEONSRAIDS", "") end):SetPoint("TOPLEFT", 12, -90)
    mkButton(pane, "My group's makeup", 190, function() SFP:RunModule("SEVIATHSDUNGEONSRAIDS", "comp") end, "Roles, Bloodlust, battle res, missing raid buffs, tier tokens"):SetPoint("TOPLEFT", 12, -120)
    mkButton(pane, "Rate my last group", 190, function() SFP:RunModule("SEVIATHSDUNGEONSRAIDS", "rate") end):SetPoint("TOPLEFT", 12, -150)
    mkText(pane, "Tag a player: /sdr tag Name-Realm good|bad|fav|block", 12, -190, 500, "GameFontHighlightSmall"):SetTextColor(0.7, 0.7, 0.7)
end

local function buildGuild(pane)
    mkText(pane, CYHEX .. "Guild|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "Find players with /who by level and class, whisper them your pitch and invite them when they say yes. Not in a guild? It helps you collect charter signatures.", 12, -34, 500, "GameFontHighlightSmall")
    mkButton(pane, "Open Guild Helper", 190, function() SFP:RunModule("SEVIATHSGUILDHELPER", "") end):SetPoint("TOPLEFT", 12, -90)
    mkButton(pane, "Scan next level range", 190, function() SFP:RunModule("SEVIATHSGUILDHELPER", "scan") end):SetPoint("TOPLEFT", 12, -120)
end

local function buildSettings(pane)
    mkText(pane, CYHEX .. "Settings|r", 12, -10, 480, "GameFontNormalLarge")
    pane.checks = {
        -- left column
        mkCheck(pane, "Item and monster tooltip lines", function() return SFP.db.tooltip end, function(v) SFP.db.tooltip = v end, 12, -40),
        mkCheck(pane, "Learn farm spots from my loot", function() return SFP.db.learn end, function(v) SFP.db.learn = v end, 12, -66),
        mkCheck(pane, "Learn everything constantly", function() return SFP.db.learnAll ~= false end,
            function(v) SFP.db.learnAll = v end, 12, -92),
        mkCheck(pane, "Show the minimap button", function() return not SFP.db.minimap.hide end,
            function(v) SFP.db.minimap.hide = not v; SFP:RefreshAll() end, 12, -118),
        mkCheck(pane, "Minimap button glows in farm zones", function() return SFP.db.minimapGlow end, function(v) SFP.db.minimapGlow = v; SFP:RefreshAll() end, 12, -144),
        -- right column
        mkCheck(pane, "Quest info on monsters and NPCs", function() return SFP.db.questMarkers ~= false end,
            function(v) if SFP.QuestMarkers then SFP.QuestMarkers:SetEnabled(v) end end, 260, -40),
        mkCheck(pane, "Quest icons over monster heads", function() return SFP.db.questHeads ~= false end,
            function(v) SFP.db.questHeads = v; if SFP.QuestMarkers then SFP.QuestMarkers:Refresh() end end, 260, -66),
        mkCheck(pane, "Quest areas on the minimap", function() return SFP.db.questMinimap ~= false end,
            function(v) SFP.db.questMinimap = v; if SFP.QuestMarkers then SFP.QuestMarkers:Refresh() end end, 260, -92),
        mkCheck(pane, "Chat message when an auction sells", function() return SFP.db.auctionSold ~= false end,
            function(v) SFP.db.auctionSold = v end, 260, -118),
        mkCheck(pane, "Chat message: mailbox / vendor gold", function() return SFP.db.incomeMessages ~= false end,
            function(v) SFP.db.incomeMessages = v end, 260, -144),
    }
    mkButton(pane, "Show internal errors", 160, function() SFP:Print("see /sfp errors"); SFP:RunModule("SEVIATHSUSEFULTOOLS", "errors") end):SetPoint("TOPLEFT", 12, -185)
    mkButton(pane, "Reload UI", 160, function() ReloadUI() end):SetPoint("TOPLEFT", 12, -215)
    mkButton(pane, "About / options page", 160, function() SFP:OpenAbout() end):SetPoint("TOPLEFT", 12, -245)
    pane.refresh = function() for _, cb in ipairs(pane.checks) do cb.refresh() end end
end

---------------------------------------------------------------------------
-- Learned data browser
---------------------------------------------------------------------------
local know = { mode = "npc", offset = 0, list = {}, sel = nil }
local ROWS = 16

local function zoneNames(rec)
    local out = {}
    for map in pairs(rec.m or {}) do out[#out + 1] = SFP:ZoneName(map) end
    table.sort(out)
    return table.concat(out, ", ")
end

local function dropLines(tbl, kills)
    local list = {}
    for id, n in pairs(tbl or {}) do list[#list + 1] = { id, n } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(14, #list) do
        local pct = kills and kills > 0 and (" " .. math.min(100, math.floor(list[i][2] * 100 / kills + 0.5)) .. "%") or (" x" .. list[i][2])
        out[#out + 1] = "  " .. SFP:ItemName(list[i][1]) .. "|cff909090" .. pct .. "|r"
    end
    if #list > 14 then out[#out + 1] = "  |cff808080+" .. (#list - 14) .. " more|r" end
    return table.concat(out, "\n")
end

local function detailText(mode, key)
    local db = SFP.db
    if mode == "npc" then
        local r = db.npcs[key]
        if not r then return "" end
        local lvl = r.lmin and (r.lmin == r.lmax and tostring(r.lmin) or (r.lmin .. "-" .. r.lmax)) or "?"
        local t = CYHEX .. r.n .. "|r  |cff808080NPC ID " .. key .. "|r\n"
        t = t .. "Level " .. lvl .. (r.t and ("  " .. r.t) or "") .. (r.f and ("  " .. r.f) or "") .. (r.c and ("  " .. r.c) or "") .. "\n"
        local z = zoneNames(r)
        if z ~= "" then t = t .. "Seen in: " .. z .. "\n" end
        if r.a then
            local al = {}
            for n in pairs(r.a) do al[#al + 1] = n end
            t = t .. "|cff808080Also seen as: " .. table.concat(al, ", ") .. "|r\n"
        end
        t = t .. "\n" .. (r.k or 0) .. " kills seen"
        if r.d and next(r.d) then t = t .. "\n\nDrops:\n" .. dropLines(r.d, r.k) end
        if r.s and next(r.s) then t = t .. "\n\nSkinning:\n" .. dropLines(r.s, r.sk) end
        return t
    elseif mode == "obj" then
        local r = db.objects[key]
        if not r then return "" end
        local t = CYHEX .. r.n .. "|r  |cff808080object ID " .. key .. "|r\n"
        local z = zoneNames(r)
        if z ~= "" then t = t .. "Seen in: " .. z .. "\n" end
        t = t .. "\n" .. (r.k or 0) .. " times gathered"
        if r.d and next(r.d) then t = t .. "\n\nGave:\n" .. dropLines(r.d, r.k) end
        return t
    elseif mode == "item" then
        local r = db.knownItems[key]
        if not r then return "" end
        local t = SFP:ItemName(key) .. "  |cff808080item ID " .. key .. "|r\n"
        t = t .. (r.t or "") .. (r.st and (" - " .. r.st) or "") .. (r.i and r.i > 0 and ("  item level " .. r.i) or "") .. "\n"
        for _, l in ipairs(SFP:ItemTipLines(key)) do t = t .. "\n" .. l[1] end
        return t
    elseif mode == "recipe" then
        local r = db.recipes[key]
        if not r then return "" end
        local t = CYHEX .. r.n .. "|r  |cff808080" .. (r.p or "") .. "|r\n"
        if r.o then t = t .. "Makes: " .. SFP:ItemName(r.o) .. "\n" end
        t = t .. "\nReagents:\n"
        for _, rg in ipairs(r.r or {}) do t = t .. "  " .. rg[2] .. "x " .. SFP:ItemName(rg[1]) .. "\n" end
        return t
    end
    return ""
end

local function knowRebuild(pane)
    local db = SFP.db
    local q = (pane.search:GetText() or ""):lower()
    local list = {}
    local src, nameOf
    if know.mode == "npc" then src = db.npcs
    elseif know.mode == "obj" then src = db.objects
    elseif know.mode == "item" then src = db.knownItems
    else src = db.recipes end
    for key, r in pairs(src) do
        local name = r.n or ""
        if q == "" or name:lower():find(q, 1, true) or tostring(key):find(q, 1, true) then
            list[#list + 1] = { key = key, name = name }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    know.list = list
    know.offset = 0
    pane.count:SetText(#list .. " found")
end

local function knowRefresh(pane)
    for i = 1, ROWS do
        local row = pane.rows[i]
        local e = know.list[know.offset + i]
        if e then
            row.key = e.key
            row.text:SetText(e.name)
            row.hl:SetShown(know.sel == e.key)
            row:Show()
        else
            row:Hide()
        end
    end
    pane.detail:SetText(know.sel and detailText(know.mode, know.sel) or "|cff808080Pick an entry on the left. Everything here was learned while you played, and is saved for all your characters.|r")
end

local function buildKnow(pane)
    mkText(pane, CYHEX .. "Learned data|r", 12, -10, 400, "GameFontNormalLarge")
    pane.rows = {}
    local modes = { { "npc", "Monsters" }, { "obj", "Nodes" }, { "item", "Items" }, { "recipe", "Recipes" } }
    pane.tabs = {}
    for i, m in ipairs(modes) do
        local b = mkButton(pane, m[2], 70, function()
            know.mode, know.sel = m[1], nil
            knowRebuild(pane); knowRefresh(pane)
            for _, t in ipairs(pane.tabs) do t:SetBackdropBorderColor(CY.r, CY.g, CY.b, t.mode == m[1] and 1 or 0.4) end
        end)
        b.mode = m[1]
        b:SetPoint("TOPLEFT", 12 + (i - 1) * 74, -36)
        pane.tabs[i] = b
    end
    pane.search = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    pane.search:SetSize(190, 20)
    pane.search:SetPoint("TOPLEFT", 18, -68)
    pane.search:SetAutoFocus(false)
    pane.search:SetScript("OnTextChanged", function() knowRebuild(pane); knowRefresh(pane) end)
    pane.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pane.count = mkText(pane, "", 220, -72, 100, "GameFontHighlightSmall")
    local listFrame = CreateFrame("Frame", nil, pane)
    listFrame:SetPoint("TOPLEFT", 12, -92)
    listFrame:SetSize(230, ROWS * 18)
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        local maxOff = math.max(0, #know.list - ROWS)
        know.offset = math.max(0, math.min(maxOff, know.offset - delta * 3))
        knowRefresh(pane)
    end)
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, listFrame)
        row:SetSize(230, 18)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 18)
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints(); row.hl:SetColorTexture(CY.r, CY.g, CY.b, 0.25); row.hl:Hide()
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 4, 0); row.text:SetWidth(222); row.text:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self) know.sel = self.key; knowRefresh(pane) end)
        pane.rows[i] = row
    end
    pane.detail = mkText(pane, "", 252, -40, 262, "GameFontHighlightSmall")
    pane.detail:SetWidth(262)
    pane.detail:SetJustifyV("TOP")
    pane.refresh = function() knowRebuild(pane); knowRefresh(pane) end
end

local BUILDERS = {
    home = buildHome, farm = buildFarm, guides = buildGuides, groups = buildGroups,
    guild = buildGuild, know = buildKnow, settings = buildSettings,
}

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function SFP:ShowMenuSection(key)
    if not frame then return end
    current = key
    for _, s in ipairs(SECTIONS) do
        local b = navButtons[s.key]
        b:SetBackdropColor(s.key == key and 0.1 or 0.03, s.key == key and 0.35 or 0.1, s.key == key and 0.42 or 0.13, 0.95)
        if panes[s.key] then panes[s.key]:Hide() end
    end
    local pane = panes[key]
    if not pane then
        pane = CreateFrame("Frame", nil, frame.content)
        pane:SetAllPoints()
        panes[key] = pane
        SFP:Safe("build " .. key, BUILDERS[key], pane)
    end
    pane:Show()
    if pane.refresh then SFP:Safe("refresh " .. key, pane.refresh) end
end

local function build()
    frame = CreateFrame("Frame", "SeviathsUsefulToolsMenu", UIParent, "BackdropTemplate")
    frame:SetSize(710, 470)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    backdrop(frame, 0.03, 0.06, 0.08, 0.97, CY.r, CY.g, CY.b, 0.6)
    tinsert(UISpecialFrames, "SeviathsUsefulToolsMenu")

    local title = CreateFrame("Frame", nil, frame)
    title:SetPoint("TOPLEFT"); title:SetPoint("TOPRIGHT", -34, 0); title:SetHeight(28)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() frame:StartMoving() end)
    title:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local tt = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tt:SetPoint("LEFT", 12, 0)
    tt:SetText(CYHEX .. "Seviaths|r UsefulTools  |cff808080v" .. SFP.VERSION .. "|r")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetFrameLevel(frame:GetFrameLevel() + 30)
    close:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.close = close

    for i, s in ipairs(SECTIONS) do
        local b = mkButton(frame, s.label, 138, function() SFP:ShowMenuSection(s.key) end)
        b:SetHeight(28)
        b:SetPoint("TOPLEFT", 10, -36 - (i - 1) * 32)
        navButtons[s.key] = b
    end
    frame.content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.content:SetPoint("TOPLEFT", 156, -34)
    frame.content:SetPoint("BOTTOMRIGHT", -8, 8)
    backdrop(frame.content, 0.02, 0.04, 0.06, 0.6, CY.r, CY.g, CY.b, 0.25)
end

function SFP:ToggleMenu(section)
    if not frame then build() end
    if frame:IsShown() and not section then frame:Hide(); return end
    frame:Show()
    self:ShowMenuSection(section or current or "home")
end

-- the minimap button's old menu now opens the main menu
SFP.ShowHubMenu = function() SFP:ToggleMenu() end

-- one minimap button for everything: hide the merged addons' own buttons
SFP:OnLogin(function()
    if not SFP.db.mergedButtonsHidden then
        SFP.db.mergedButtonsHidden = true
        if SeviathsCodexDB and SeviathsCodexDB.minimap then SeviathsCodexDB.minimap.hide = true end
        if SeviathsDungeonsRaidsDB and SeviathsDungeonsRaidsDB.minimap then SeviathsDungeonsRaidsDB.minimap.show = false end
        if SeviathsGuildHelperDB and SeviathsGuildHelperDB.settings and SeviathsGuildHelperDB.settings.minimap then
            SeviathsGuildHelperDB.settings.minimap.hide = true
        end
    end
    for _, name in ipairs({ "SeviathsCodexMinimapButton", "SDRMinimapButton", "SeviathsGuildHelperMinimapButton" }) do
        local f = _G[name]
        if f and f.Hide then f:Hide() end
    end
end)
