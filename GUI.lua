-- gui.lua 
PvPTip = PvPTip or {}
local UI = PvPTip.UI

-------------------------------------------------------------------------------
-- main window
-------------------------------------------------------------------------------

local mainWindow
local tabController

local function CreateMainWindow()
    mainWindow = UI.CreateWindow("PvPTipMainFrame", "PvPTip", UI.Sizes.windowW, UI.Sizes.windowH)

    -- build + version in title bar
    local build = PvPTipData and PvPTipData.Build or "unknown"
    local buildText = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buildText:SetPoint("RIGHT", mainWindow.titleText, "RIGHT", 100, 0)
    if PvPTip.buildMismatch then
        buildText:SetText("|cFFFF6600v2.0.0 — build " .. build .. " (outdated)|r")
    else
        buildText:SetText("v2.0.0 — build " .. build)
    end
    buildText:SetTextColor(0.5, 0.5, 0.5)

    -- tab definitions
    local tabDefs = {
        {
            Key = "Overview",
            Title = "Overview",
            Build = function(panel)
                if PvPTip.BuildOverviewPanel then
                    PvPTip.BuildOverviewPanel(panel)
                end
            end,
        },
        {
            Key = "Settings",
            Title = "Settings",
            Build = function(panel)
                if PvPTip.BuildSettingsPanel then
                    PvPTip.BuildSettingsPanel(panel)
                end
            end,
        },
        {
            Key = "Lookup",
            Title = "Lookup",
            Build = function(panel)
                if PvPTip.BuildLookupPanel then
                    PvPTip.BuildLookupPanel(panel)
                end
            end,
        },
    }

    tabController = UI.CreateTabs(mainWindow.content, tabDefs)
    tabController:SetActive("Overview")

    mainWindow:Hide()
    return mainWindow
end

-------------------------------------------------------------------------------
-- public API
-------------------------------------------------------------------------------

function PvPTip.ToggleGUI()
    if not mainWindow then
        CreateMainWindow()
    end

    if mainWindow:IsShown() then
        mainWindow:Hide()
    else
        mainWindow:Show()
        -- refresh current tab
        if PvPTip.RefreshGUI then PvPTip.RefreshGUI() end
    end
end

function PvPTip.RefreshGUI()
    if not mainWindow or not mainWindow:IsShown() then return end

    local activeKey = tabController and tabController.activeKey
    if activeKey == "Overview" and PvPTip.RefreshOverview then
        PvPTip.RefreshOverview()
    elseif activeKey == "Lookup" and PvPTip.RefreshLookup then
        PvPTip.RefreshLookup()
    end
end

function PvPTip.ShowGUI(tabKey)
    if not mainWindow then
        CreateMainWindow()
    end
    mainWindow:Show()
    if tabKey and tabController then
        tabController:SetActive(tabKey)
    end
end
