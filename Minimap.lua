-- Minimap.lua: a round button on the minimap's edge. Left-click: settings. Right-click: apply.
local _, ns = ...
local L = ns.L

local button
local RADIUS = 80

local function Place()
    local angle = math.rad(ns.db.minimapAngle or 200)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

local function Drag()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    ns.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    Place()
end

local function Tooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("SmartCast Forever")
    local converted, todo = ns.Counts()
    GameTooltip:AddLine((L["Converted: %d   Pending: %d   Character macros: %d / %d"]):format(
        converted, todo, ns.CharacterMacroCount(), ns.MaxCharacterMacros()), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Left-click: settings"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Right-click: apply"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Shift + right-click: undo all"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Drag: move this button"], 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function ns.CreateMinimapButton()
    if button or not Minimap then return end
    button = CreateFrame("Button", "SmartCastForeverMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\Ability_Marksmanship")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            if IsShiftKeyDown() then ns.Undo() else ns.Apply() end
        else
            ns.ToggleWindow()
        end
    end)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", Drag) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
    button:SetShown(not ns.db.minimapHidden)
end

function ns.RefreshMinimap()
    if button and button:IsMouseOver() and GameTooltip:GetOwner() == button then Tooltip(button) end
end
