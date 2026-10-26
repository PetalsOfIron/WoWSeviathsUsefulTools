-- SeviathsUsefulTools - layer switches on the world map
-- A small button in the top-left corner of the map opens a panel where every
-- layer can be turned on/off separately: farm spots, rares, hunter tames,
-- mining, herbalism, dungeons, raids, labels and the whole-zone glow.

local _, SFP = ...

local GLOW = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- key, label, icon texture or colour {r,g,b}, tooltip
local LAYERS = {
    { "mapOverlay",   "Show SeviathsUsefulTools", "Interface\\Icons\\INV_Misc_Map_01", "Master switch for everything below" },
    { "showSpawns",   "Farm spots",    { 0.0, 0.9, 1.0 },  "Cyan markers: mobs that drop cloth, leather, elements, meat, BoEs (one marker per area)" },
    { "showRares",    "Rares",         { 1.0, 0.5, 0.0 },  "Orange markers: rares with mounts, pets and toys" },
    { "showSpecial",  "Special materials", { 1.0, 0.25, 0.85 }, "Magenta markers: rare hides, lure beasts, special cloth (Sunfire Silk, Arcanoweave)" },
    { "showHunter",   "Hunter tames",  "Interface\\Icons\\ClassIcon_Hunter", "Spirit beasts and unique-looking pets" },
    { "showMining",   "Mining",        "Interface\\Icons\\Trade_Mining",     "Pick symbols in the best zone of each ore - hover for every ore around it" },
    { "showHerbs",    "Herbalism",     "Interface\\Icons\\Trade_Herbalism",  "Flower symbols in the best zone of each herb - hover for every herb around it" },
    { "showGatherList", "Gathering list", "Interface\\Icons\\INV_Misc_Bag_10", "Side list on zone maps: this expansion's ores and herbs and the best zone for each" },
    { "showDungeons", "Dungeons",      "Interface\\Minimap\\Dungeon",        "Dungeon entrances - hover for loot" },
    { "showRaids",    "Raids",         "Interface\\Minimap\\Raid",           "Raid entrances - hover for loot" },
    { "learn",        "Learn from my loot", "Interface\\Icons\\INV_Misc_Book_09", "Remember where you loot cloth, leather, meat, special materials and BoEs, and show those places as farm spots with your own drop rates" },
    { "showUnconfirmed", "Unconfirmed BoEs", "Interface\\Icons\\INV_Misc_QuestionMark", "Possible BoEs from guides that may have been changed before release - shown greyed out at the bottom of dungeon/raid tooltips" },
    { "showLabels",   "Labels",        "Interface\\Icons\\INV_Misc_Note_01", "Names, coordinates and 'Best spot' text next to the glows" },
    { "zoneFill",     "Whole-zone glow", { 0.0, 0.6, 0.7 }, "Light up entire farm zones (and zone hover tooltips)" },
}

local button, panel
local checks = {}

local function syncChecks()
    if not panel then return end
    for _, cb in ipairs(checks) do
        cb:SetChecked(SFP.db[cb.key] and true or false)
        local on = SFP.db.mapOverlay or cb.key == "mapOverlay"
        cb.text:SetAlpha(on and 1 or 0.45)
        cb.swatch:SetAlpha(on and 1 or 0.45)
    end
    if button then button.glow:SetShown(SFP.db.mapOverlay and true or false) end
end

local function setAll(v)
    for _, l in ipairs(LAYERS) do
        if l[1] ~= "mapOverlay" and l[1] ~= "zoneFill" then SFP.db[l[1]] = v end
    end
    SFP.db.mapOverlay = true
    SFP:RefreshAll()
end

local function buildPanel(sc)
    panel = CreateFrame("Frame", "SeviathsUsefulToolsMapMenu", sc, "BackdropTemplate")
    panel:SetFrameStrata("HIGH")
    panel:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
    panel:SetWidth(186)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    panel:SetBackdropColor(0, 0.04, 0.07, 0.92)
    panel:SetBackdropBorderColor(SFP.CYAN.r, SFP.CYAN.g, SFP.CYAN.b, 0.9)
    panel:EnableMouse(true) -- clicks on the panel don't fall through to the map

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 8, -7)
    title:SetText("|c" .. SFP.CYAN_HEX .. "Seviaths|rFarmPack layers")

    local y = -24
    for i, l in ipairs(LAYERS) do
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", 6, y)
        cb.key = l[1]

        cb.swatch = cb:CreateTexture(nil, "OVERLAY")
        cb.swatch:SetSize(14, 14)
        cb.swatch:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        if type(l[3]) == "table" then
            cb.swatch:SetTexture(GLOW)
            cb.swatch:SetVertexColor(l[3][1], l[3][2], l[3][3], 1)
        else
            cb.swatch:SetTexture(l[3])
            cb.swatch:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        cb.text = cb:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontHighlight" or "GameFontHighlightSmall")
        cb.text:SetPoint("LEFT", cb.swatch, "RIGHT", 5, 0)
        cb.text:SetText(l[2])
        cb:SetHitRectInsets(0, -140, 0, 0) -- the label is clickable too

        cb:SetScript("OnClick", function(self)
            SFP.db[self.key] = self:GetChecked() and true or false
            SFP:RefreshAll()
        end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(l[2], 1, 1, 1)
            GameTooltip:AddLine(l[4], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        checks[#checks + 1] = cb
        y = y - (i == 1 and 24 or 20)
    end

    local function smallButton(text, x, onClick)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(52, 18)
        b:SetPoint("TOPLEFT", x, y - 4)
        b:SetText(text)
        b:SetNormalFontObject("GameFontHighlightSmall")
        b:SetScript("OnClick", onClick)
        return b
    end
    smallButton("All", 8, function() setAll(true) end)
    smallButton("None", 64, function() setAll(false) end)
    smallButton("More", 120, function() SFP:ToggleBrowser() end)

    panel:SetHeight(-y + 30)
    panel:SetShown(SFP.db.mapMenu.open and true or false)
end

SFP:OnLogin(function()
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    local sc = WorldMapFrame.ScrollContainer

    button = CreateFrame("Button", "SeviathsUsefulToolsMapButton", sc)
    button:SetSize(28, 28)
    button:SetPoint("TOPLEFT", sc, "TOPLEFT", 6, -6)
    button:SetFrameStrata("HIGH")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.04, 0.07, 0.85)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetPoint("TOPLEFT", -6, 6)
    button.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.glow:SetBlendMode("ADD")
    button.glow:SetVertexColor(SFP.CYAN.r, SFP.CYAN.g, SFP.CYAN.b, 0.9)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            SFP.db.mapOverlay = not SFP.db.mapOverlay
            SFP:RefreshAll()
            return
        end
        if not panel then buildPanel(sc) end
        panel:SetShown(not panel:IsShown())
        SFP.db.mapMenu.open = panel:IsShown()
        syncChecks()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|c" .. SFP.CYAN_HEX .. "SeviathsUsefulTools|r layers")
        GameTooltip:AddLine("Left-click: choose what shows on the map", 1, 1, 1)
        GameTooltip:AddLine("Right-click: everything on/off", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if SFP.db.mapMenu.open then buildPanel(sc) end
    button:SetShown(not SFP.db.mapMenu.hide)
    syncChecks()

    SFP:OnRefresh(function()
        if button then button:SetShown(not SFP.db.mapMenu.hide) end
        syncChecks()
    end)
end)
