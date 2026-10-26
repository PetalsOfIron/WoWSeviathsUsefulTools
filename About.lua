-- SeviathsUsefulTools - About page (Esc > Options > AddOns > SeviathsUsefulTools)
-- and the Addon Compartment entry (the addons button by the minimap).

local _, SFP = ...

local category

local function buildPanel()
    local f = CreateFrame("Frame")
    f.name = SFP.NAME

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|c" .. SFP.CYAN_HEX .. "Seviaths|rFarmPack")

    local ver = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    ver:SetText("Version " .. SFP.VERSION .. "   |cff808080by " .. SFP.AUTHOR .. "|r")

    local desc = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -14)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(3)
    desc:SetText(
        "Shows where to farm in-demand creature loot - cloth, leather, elements, meat and BoE pets - " ..
        "from Classic to Mists of Pandaria, plus rare spawns that drop mounts.\n\n" ..
        "|c" .. SFP.CYAN_HEX .. "Zone map:|r the exact farm spots glow cyan, with mob name and coordinates. " ..
        "Hover a spot for its drops and auction house value; Ctrl+Click for a waypoint.\n" ..
        "|cffff8000Rares:|r orange spots for rare spawns that drop mounts, pets and toys, with spawn tips.\n" ..
        "|cffffb366Mining|r & |cff4dff8cherbalism:|r the best zone for every ore and herb, Classic to Mists of Pandaria - small symbols list what spawns around them.\n" ..
        "|c" .. SFP.CYAN_HEX .. "Map layers:|r the button in the top-left corner of the world map turns each layer on/off.\n" ..
        "|cffff4dd9Special materials:|r magenta spots for lure beasts, special cloth and rare hides.\n" ..
        "|cffffb366Gathering list:|r bottom-right of each zone map - the expansion's ores and herbs and their best zone.\n" ..
        "|cffff8000Dungeons & raids:|r entrance icons on the map; hover for the mounts they drop and drop chances.\n" ..
        "Loot lines show a small icon for the source: mining, herbalism, skinning, cloth, enchanting, mounts.\n" ..
        "|cffabd473Hunter tames:|r green spots with the hunter crest for spirit beasts and unique-looking pets, with how to tame them.\n" ..
        "|c" .. SFP.CYAN_HEX .. "Continent map:|r one spot per farm mob; zoom in to see the full spawn areas.\n" ..
        "|c" .. SFP.CYAN_HEX .. "Minimap button:|r pulses cyan inside a farm zone; opens the farm browser.\n" ..
        "|c" .. SFP.CYAN_HEX .. "Auction house:|r prices load the first time you open it (Auctionator used as fallback).\n\n" ..
        "Item data and spawn positions: wowhead.com. Drop chances are approximate.")

    local open = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    open:SetSize(180, 24)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    open:SetText("Open farm browser")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        SFP:ToggleBrowser()
    end)

    local cmds = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    cmds:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -16)
    cmds:SetJustifyH("LEFT")
    cmds:SetSpacing(2)
    cmds:SetText(
        "/sfp  -  farm browser + settings\n" ..
        "/sfp spawns  -  farm spot glows on/off\n" ..
        "/sfp rares  -  rare spots on/off\n" ..
        "/sfp hunter  -  hunter tame spots on/off\n" ..
        "/sfp gather  -  mining & herbalism spots on/off\n" ..
        "/sfp dungeons  -  dungeon/raid icons on/off\n" ..
        "/sfp mapbutton  -  show/hide the layer button on the world map\n" ..
        "/sfp loot  -  re-read dungeon/raid mounts and BoEs\n" ..
        "/sfp learn  -  learn farm spots from your loot on/off (/sfp learn reset)\n" ..
        "/sfp map  -  world map overlay on/off\n" ..
        "/sfp minimap  -  minimap button on/off\n" ..
        "/sfp scan  -  rescan AH prices (auction house open)\n" ..
        "/sfp min <gold>  -  only show zones worth at least this\n" ..
        "/sfp version  -  version info")

    return f
end

function SFP:OpenAbout()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    end
end

SFP:OnLogin(function()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local ok = pcall(function()
            category = Settings.RegisterCanvasLayoutCategory(buildPanel(), SFP.NAME)
            Settings.RegisterAddOnCategory(category)
        end)
        if not ok then category = nil end
    end
end)

-- Addon Compartment (TOC: AddonCompartmentFunc / OnEnter / OnLeave)
function SeviathsUsefulTools_OnCompartmentClick(_, button)
    if button == "RightButton" then SFP:OpenAbout() else SFP:ToggleMenu() end
end

function SeviathsUsefulTools_OnCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("|c" .. SFP.CYAN_HEX .. "SeviathsUsefulTools|r", "|cff808080v" .. SFP.VERSION .. "|r")
    GameTooltip:AddLine("Left-click: farm browser", 1, 1, 1)
    GameTooltip:AddLine("Right-click: about / options", 1, 1, 1)
    GameTooltip:Show()
end

function SeviathsUsefulTools_OnCompartmentLeave()
    GameTooltip:Hide()
end
