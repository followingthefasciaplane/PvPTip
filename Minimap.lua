-- minimap.lua 
PvPTip = PvPTip or {}

local ICON_TEXTURE = "Interface\\ICONS\\Ability_pvp_gladiatormedallion"
local BUTTON_SIZE = 31
local BORDER_SIZE = 54

-------------------------------------------------------------------------------
-- minimap button
-------------------------------------------------------------------------------

local button

local function GetRadius()
    return (Minimap:GetWidth() / 2) + 5
end

local function UpdatePosition(angle)
    if not button then return end
    local rads = math.rad(angle)
    local radius = GetRadius()
    local x = math.cos(rads) * radius
    local y = math.sin(rads) * radius
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    -- parent to MinimapCluster (not Minimap) to avoid circular clipping
    local parent = MinimapCluster or Minimap:GetParent() or Minimap
    button = CreateFrame("Button", "PvPTipMinimapButton", parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(9)

    -- icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(17, 17)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    -- circular mask so icon appears round
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(17, 17)
    mask:SetPoint("CENTER", 0, 0)
    icon:AddMaskTexture(mask)

    -- border ring (standard minimap button chrome)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(BORDER_SIZE, BORDER_SIZE)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.border = border

    -- dragging
    local isDragging = false
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        isDragging = true
    end)
    button:SetScript("OnDragStop", function()
        isDragging = false
    end)

    button:SetScript("OnUpdate", function(self)
        if not isDragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        local cfg = PvPTip.GetConfig()
        cfg.minimapPos = angle
        UpdatePosition(angle)
    end)

    -- click handling
    button:SetScript("OnClick", function(self, btn)
        if isDragging then return end
        if btn == "LeftButton" then
            if IsShiftKeyDown() then
                local cfg = PvPTip.GetConfig()
                cfg.showInTooltips = not cfg.showInTooltips
                print("|cFFFFD100PvPTip:|r Tooltip display " ..
                    (cfg.showInTooltips and "enabled" or "disabled"))
            else
                if PvPTip.ToggleGUI then
                    PvPTip.ToggleGUI()
                end
            end
        elseif btn == "RightButton" then
            local cfg = PvPTip.GetConfig()
            local modes = {"compact", "verbose", "minimal"}
            local current = cfg.tooltipMode
            for i, mode in ipairs(modes) do
                if mode == current then
                    cfg.tooltipMode = modes[(i % #modes) + 1]
                    print("|cFFFFD100PvPTip:|r Mode: " .. cfg.tooltipMode)
                    break
                end
            end
        end
    end)

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("PvPTip", 1, 0.82, 0)
        local build = PvPTipData and PvPTipData.Build or "unknown"
        if PvPTip.buildMismatch then
            GameTooltip:AddLine("Build: " .. build .. " (outdated!)", 1, 0.5, 0.1)
            GameTooltip:AddLine("Client: " .. (PvPTip.clientBuild or "?") .. " — check for update", 1, 0.4, 0.1)
        else
            GameTooltip:AddLine("Build: " .. build, 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFFFFFLeft-click:|r Toggle window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFFFFFFFFShift-click:|r Toggle tooltips", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFFFFFFFFRight-click:|r Cycle mode", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

-------------------------------------------------------------------------------
-- public 
-------------------------------------------------------------------------------

function PvPTip.InitMinimap()
    local cfg = PvPTip.GetConfig()
    if not cfg.showMinimapIcon then return end

    if not button then
        CreateMinimapButton()
    end

    UpdatePosition(cfg.minimapPos or 220)
    button:Show()
end

function PvPTip.SetMinimapVisible(visible)
    if not button and visible then
        PvPTip.InitMinimap()
        return
    end
    if button then
        if visible then
            button:Show()
        else
            button:Hide()
        end
    end
end
