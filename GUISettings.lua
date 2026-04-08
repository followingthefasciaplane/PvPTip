-- guisettings.lua 
PvPTip = PvPTip or {}
local UI = PvPTip.UI

-------------------------------------------------------------------------------
-- build panel
-------------------------------------------------------------------------------

function PvPTip.BuildSettingsPanel(panel)
    local padding = UI.Sizes.padding
    local spacing = 32
    local yOff = -padding

    -- helper: position a component
    local function Place(widget, width)
        widget:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOff)
        if width then
            widget:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -padding, yOff)
        else
            widget:SetWidth(400)
        end
        yOff = yOff - spacing
        return widget
    end

    -- section: General
    local generalHeader = UI.CreateSectionHeader(panel, "General")
    Place(generalHeader, true)

    -- enable PvPTip
    local enableCb = UI.CreateCheckbox(panel, "Enable PvPTip",
        function() return PvPTip.GetConfig().enabled end,
        function(v) PvPTip.GetConfig().enabled = v end
    )
    Place(enableCb, true)

    -- show in spell tooltips
    local tooltipCb = UI.CreateCheckbox(panel, "Show PvP data in spell tooltips",
        function() return PvPTip.GetConfig().showInTooltips end,
        function(v) PvPTip.GetConfig().showInTooltips = v end
    )
    Place(tooltipCb, true)

    -- show in talent tooltips (to-do)
    local talentCb = UI.CreateCheckbox(panel, "Show PvP data in talent tooltips (coming soon)",
        function() return PvPTip.GetConfig().showInTalents end,
        function(v) PvPTip.GetConfig().showInTalents = v end
    )
    Place(talentCb, true)

    -- show on items (disabled)
    local itemCb = UI.CreateCheckbox(panel, "Show PvP data on items (coming soon)",
        function() return PvPTip.GetConfig().showOnItems end,
        function(v) PvPTip.GetConfig().showOnItems = v end
    )
    Place(itemCb, true)
    itemCb.btn:Disable()
    itemCb.label:SetTextColor(0.4, 0.4, 0.4)

    -- show minimap icon
    local minimapCb = UI.CreateCheckbox(panel, "Show minimap icon",
        function() return PvPTip.GetConfig().showMinimapIcon end,
        function(v)
            PvPTip.GetConfig().showMinimapIcon = v
            PvPTip.SetMinimapVisible(v)
        end
    )
    Place(minimapCb, true)

    -- section: tooltip mode
    yOff = yOff - 8
    local modeDiv = UI.CreateDivider(panel, "Tooltip Display")
    Place(modeDiv, true)

    local modeDropdown = UI.CreateDropdown(panel, "Tooltip mode:",
        {
            {label = "Compact (Damage +74%)", value = "compact"},
            {label = "Verbose (full details)", value = "verbose"},
            {label = "Minimal (+74%)", value = "minimal"},
        },
        function() return PvPTip.GetConfig().tooltipMode end,
        function(v) PvPTip.GetConfig().tooltipMode = v end
    )
    Place(modeDropdown, true)

    -- section: colors
    yOff = yOff - 8
    local colorDiv = UI.CreateDivider(panel, "Colors")
    Place(colorDiv, true)

    local headerColor = UI.CreateColorPicker(panel, "Header color",
        function() return PvPTip.GetConfig().colors.header end,
        function(v) PvPTip.GetConfig().colors.header = v end
    )
    Place(headerColor, true)

    local buffColor = UI.CreateColorPicker(panel, "Buff color",
        function() return PvPTip.GetConfig().colors.buff end,
        function(v) PvPTip.GetConfig().colors.buff = v end
    )
    Place(buffColor, true)

    local nerfColor = UI.CreateColorPicker(panel, "Nerf color",
        function() return PvPTip.GetConfig().colors.nerf end,
        function(v) PvPTip.GetConfig().colors.nerf = v end
    )
    Place(nerfColor, true)

    -- section: info
    yOff = yOff - 8
    local infoDiv = UI.CreateDivider(panel, "Info")
    Place(infoDiv, true)

    local infoFrame = CreateFrame("Frame", nil, panel)
    infoFrame:SetHeight(60)
    Place(infoFrame, true)

    local build = PvPTipData and PvPTipData.Build or "unknown"
    local spellCount = 0
    local auraCount = 0
    if PvPTipData then
        if PvPTipData.Spells then
            for _ in pairs(PvPTipData.Spells) do spellCount = spellCount + 1 end
        end
        if PvPTipData.PvpModAuras then
            for _ in pairs(PvPTipData.PvpModAuras) do auraCount = auraCount + 1 end
        end
    end

    local buildLabel = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buildLabel:SetPoint("TOPLEFT", infoFrame, "TOPLEFT", 0, 0)
    if PvPTip.buildMismatch then
        buildLabel:SetText(string.format("|cFFFF6600Data build: %s (client: %s — check for update!)|r",
            build, PvPTip.clientBuild or "unknown"))
    else
        buildLabel:SetText(string.format("Build: %s", build))
    end
    buildLabel:SetTextColor(0.6, 0.6, 0.6)

    local dataLabel = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dataLabel:SetPoint("TOPLEFT", buildLabel, "BOTTOMLEFT", 0, -4)
    dataLabel:SetText(string.format("Data: %d spells, %d modifier auras", spellCount, auraCount))
    dataLabel:SetTextColor(0.6, 0.6, 0.6)

    local versionLabel = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionLabel:SetPoint("TOPLEFT", dataLabel, "BOTTOMLEFT", 0, -4)
    versionLabel:SetText("PvPTip v2.0.0")
    versionLabel:SetTextColor(0.4, 0.4, 0.4)
end
