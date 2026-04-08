-- core.lua 
PvPTip = PvPTip or {}
local U = PvPTip.Utils

-------------------------------------------------------------------------------
-- default config
-------------------------------------------------------------------------------

local DEFAULTS = {
    enabled = true,
    showInTooltips = true,
    showInTalents = true, -- to do
    showOnItems = false, -- to do
    tooltipMode = "compact", -- "compact", "verbose", "minimal"
    showMinimapIcon = true,
    minimapPos = 220,
    colors = {
        header  = {1, 0.82, 0},
        buff    = {0.2, 1.0, 0.2},
        nerf    = {1.0, 0.3, 0.3},
        neutral = {0.7, 0.7, 0.7},
    },
}

-------------------------------------------------------------------------------
-- state
-------------------------------------------------------------------------------

PvPTip.isPvPActive = false
PvPTip.currentSpecID = 0
PvPTip.currentClassID = 0
PvPTip.clientBuild = nil  -- set on login from GetBuildInfo()
PvPTip.buildMismatch = false

local PVP_RULES_SPELL = 134735 -- see also: 1216883, 272950, 244983

-------------------------------------------------------------------------------
-- config helpers
-------------------------------------------------------------------------------

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function MergeDefaults(saved, defaults)
    if type(saved) ~= "table" then return DeepCopy(defaults) end
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            saved[k] = DeepCopy(v)
        elseif type(v) == "table" and type(saved[k]) == "table" then
            MergeDefaults(saved[k], v)
        end
    end
    return saved
end

function PvPTip.GetConfig()
    return PvPTipDB or DEFAULTS
end

-------------------------------------------------------------------------------
-- PvP detection - TO DO
-------------------------------------------------------------------------------

local function UpdatePvPState()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        PvPTip.isPvPActive = C_UnitAuras.GetPlayerAuraBySpellID(PVP_RULES_SPELL) ~= nil
    else
        PvPTip.isPvPActive = false
    end
end

-------------------------------------------------------------------------------
-- spec detection
-------------------------------------------------------------------------------

local function UpdateSpecInfo()
    local specIndex = GetSpecialization and GetSpecialization() or 0
    if specIndex and specIndex > 0 then
        local specID = GetSpecializationInfo and GetSpecializationInfo(specIndex)
        if specID then
            PvPTip.currentSpecID = specID
        end
    end

    -- get class ID
    local _, _, classID = UnitClass("player")
    if classID then
        PvPTip.currentClassID = classID
    end
end

-------------------------------------------------------------------------------
-- welcome message
-------------------------------------------------------------------------------

local function PrintWelcome()
    local cfg = PvPTip.GetConfig()
    if not cfg.enabled then return end

    local build = PvPTipData and PvPTipData.Build or "unknown"
    local count = 0
    if PvPTipData and PvPTipData.Spells then
        for _ in pairs(PvPTipData.Spells) do count = count + 1 end
    end

    local r, g, b = cfg.colors.header[1], cfg.colors.header[2], cfg.colors.header[3]
    DEFAULT_CHAT_FRAME:AddMessage(
        string.format("|cff%02x%02x%02xPvPTip v2.0.0|r loaded — %d spells, build %s. Type /pvptip for options.",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
            count, build),
        1, 1, 1
    )

    if PvPTip.buildMismatch then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cFFFF6600PvPTip:|r Data is from build %s but client is %s. "
                .. "PvP coefficients may be outdated — check for an update!",
                build, PvPTip.clientBuild),
            1, 0.8, 0.2
        )
    end
end

-------------------------------------------------------------------------------
-- slash commands
-------------------------------------------------------------------------------

local function HandleSlashCommand(msg)
    msg = (msg or ""):lower():trim()

    if msg == "help" then
        print("|cFFFFD100PvPTip Commands:|r")
        print("  /pvptip — Toggle the PvPTip window")
        print("  /pvptip help — Show this help")
        print("  /pvptip tooltip — Toggle tooltip display")
        print("  /pvptip mode [compact|verbose|minimal] — Set tooltip mode")
        print("  /pvptip status — Show current status")
    elseif msg == "tooltip" then
        local cfg = PvPTip.GetConfig()
        cfg.showInTooltips = not cfg.showInTooltips
        print("|cFFFFD100PvPTip:|r Tooltip display " .. (cfg.showInTooltips and "enabled" or "disabled"))
    elseif msg:sub(1, 4) == "mode" then
        local mode = msg:sub(6):trim()
        if mode == "compact" or mode == "verbose" or mode == "minimal" then
            PvPTip.GetConfig().tooltipMode = mode
            print("|cFFFFD100PvPTip:|r Tooltip mode set to " .. mode)
        else
            print("|cFFFFD100PvPTip:|r Valid modes: compact, verbose, minimal")
        end
    elseif msg == "status" then
        local cfg = PvPTip.GetConfig()
        local build = PvPTipData and PvPTipData.Build or "unknown"
        print("|cFFFFD100PvPTip Status:|r")
        print("  Build: " .. build)
        print("  Mode: " .. cfg.tooltipMode)
        print("  Tooltips: " .. (cfg.showInTooltips and "on" or "off"))
        print("  PvP Active: " .. (PvPTip.isPvPActive and "yes" or "no"))
    else
        -- Toggle GUI
        if PvPTip.ToggleGUI then
            PvPTip.ToggleGUI()
        else
            print("|cFFFFD100PvPTip:|r GUI not yet loaded. Type /pvptip help for commands.")
        end
    end
end

-------------------------------------------------------------------------------
-- event handler
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == "PvPTip" then
        -- initialize saved variables
        PvPTipDB = MergeDefaults(PvPTipDB, DEFAULTS)

        -- register slash commands
        SLASH_PVPTIP1 = "/pvptip"
        SLASH_PVPTIP2 = "/pt"
        SlashCmdList["PVPTIP"] = HandleSlashCommand

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        UpdateSpecInfo()
        UpdatePvPState()

        -- detect client build for mismatch warning
        if GetBuildInfo then
            local version, build = GetBuildInfo()
            if version and build then
                PvPTip.clientBuild = version .. "." .. build
            end
        end

        -- check build mismatch
        local dataBuild = PvPTipData and PvPTipData.Build or "unknown"
        if PvPTip.clientBuild and dataBuild ~= "unknown" and dataBuild ~= PvPTip.clientBuild then
            PvPTip.buildMismatch = true
        end

        PrintWelcome()

        -- initialize minimap
        if PvPTip.InitMinimap then
            PvPTip.InitMinimap()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdatePvPState()

    elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        UpdateSpecInfo()
        -- refresh GUI if open
        if PvPTip.RefreshGUI then PvPTip.RefreshGUI() end

    elseif event == "TRAIT_CONFIG_UPDATED" then
        -- talent loadout changed
        if PvPTip.RefreshGUI then PvPTip.RefreshGUI() end

    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            UpdatePvPState()
        end
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("UNIT_AURA")
