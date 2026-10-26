-- SeviathsUsefulTools - minimap button
-- Left-click: farm browser (expansions, zones, coordinates, settings)
-- Right-click: menu with the Codex, Dungeons & Raids, Guild Helper and the map overlay switch
-- Drag: move around the minimap. Pulses cyan while you stand in a farm zone.

local _, SFP = ...

local btn

local function placeButton()
    local angle = math.rad(SFP.db.minimap.angle or 215)
    local radius = (Minimap:GetWidth() / 2) + 6
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function updateButton()
    if not btn then return end
    if SFP.db.minimap.hide then btn:Hide(); return end
    btn:Show()
    local zone = SFP:PlayerFarmZone()
    local inFarm = zone and SFP:IsValuableZone(zone)
    if inFarm and SFP.db.minimapGlow then
        btn.glow:Show()
        if not btn.pulse:IsPlaying() then btn.pulse:Play() end
    else
        btn.pulse:Stop()
        btn.glow:Hide()
    end
    btn.inFarm = inFarm and zone or nil
end
SFP.UpdateMinimapButton = updateButton

SFP:OnLogin(function()
    btn = CreateFrame("Button", "SeviathsUsefulToolsMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local c = SFP.CYAN
    btn.glow = btn:CreateTexture(nil, "ARTWORK")
    btn.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    btn.glow:SetBlendMode("ADD")
    btn.glow:SetVertexColor(c.r, c.g, c.b, 1)
    btn.glow:SetSize(52, 52)
    btn.glow:SetPoint("CENTER", 0, 1)
    btn.glow:Hide()

    btn.pulse = btn.glow:CreateAnimationGroup()
    btn.pulse:SetLooping("BOUNCE")
    local a = btn.pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0.25); a:SetDuration(0.9)

    btn:SetScript("OnClick", function(_, button)
        SFP:ToggleMenu()
    end)

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            SFP.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
            placeButton()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddDoubleLine("|c" .. SFP.CYAN_HEX .. "SeviathsUsefulTools|r", "|cff808080v" .. SFP.VERSION .. "|r")
        if self.inFarm then
            GameTooltip:AddLine("You're in a farm zone: " .. SFP:ZoneName(self.inFarm), 0, 0.9, 1)
            local zone = SFP.zoneByMap[self.inFarm]
            for _, id in ipairs(zone.items) do
                GameTooltip:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":14|t " .. SFP:ItemName(id),
                    SFP:FormatPrice(SFP:GetPrice(id)), 1, 1, 1, 1, 1, 1)
            end
            GameTooltip:AddLine(" ")
        end
        GameTooltip:AddLine("Click: open the main menu (everything in one place)", 1, 1, 1)
        GameTooltip:AddLine("Drag: move button", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    placeButton()
    updateButton()
    SFP:OnRefresh(updateButton)
end)
