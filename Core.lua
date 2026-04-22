-- core.lua 
PvPTip = PvPTip or {}
PvPTip.version = "3.0.0"
local U = PvPTip.Utils

-------------------------------------------------------------------------------
-- default config
-------------------------------------------------------------------------------

local DEFAULTS = {
    enabled = true,
    showInTooltips = true,
    showInTalents = true,
    showOnItems = false,
    tooltipMode = "compact", -- "compact", "verbose", "minimal"
    overviewScope = "class", -- "class", "spec"
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
    local specID = U and U.GetLiveCurrentSpecID and U.GetLiveCurrentSpecID() or 0
    PvPTip.currentSpecID = specID or 0

    -- get class ID
    local _, _, classID = UnitClass("player")
    if classID then
        PvPTip.currentClassID = classID
    end
end

local function InvalidateRuntimeCaches()
    if U and U.InvalidateCaches then
        U.InvalidateCaches()
    end
    if PvPTip.TooltipResolver and PvPTip.TooltipResolver.InvalidateCaches then
        PvPTip.TooltipResolver.InvalidateCaches()
    end
end

-------------------------------------------------------------------------------
-- welcome message
-------------------------------------------------------------------------------

local function PrintWelcome()
    local cfg = PvPTip.GetConfig()
    if not cfg.enabled then return end

    local build = PvPTipData and PvPTipData.Build or "unknown"
    local addonVersion = PvPTip.version or "3.0.0"
    local count = 0
    if PvPTipData and PvPTipData.PvpSpellEffects then
        for _ in pairs(PvPTipData.PvpSpellEffects) do
            count = count + 1
        end
    end

    local r, g, b = cfg.colors.header[1], cfg.colors.header[2], cfg.colors.header[3]
    DEFAULT_CHAT_FRAME:AddMessage(
        string.format("|cff%02x%02x%02xPvPTip v%s|r loaded — %d spells, build %s. Type /pvptip for options.",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
            addonVersion, count, build),
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

local function EnsureDebugDB()
    if type(PvPTipDebugDB) ~= "table" then
        PvPTipDebugDB = {}
    end
    if type(PvPTipDebugDB.exports) ~= "table" then
        PvPTipDebugDB.exports = {}
    end
    return PvPTipDebugDB
end

local function BuildTimestamp()
    if date then
        return date("!%Y-%m-%dT%H:%M:%SZ")
    end
    if time then
        return tostring(time())
    end
    return "unknown"
end

local function SaveDebugExport(kind, payload)
    local db = EnsureDebugDB()
    local entry = {
        kind = kind,
        timestamp = BuildTimestamp(),
        payload = payload,
    }

    table.insert(db.exports, 1, entry)
    local maxExports = 20
    while #db.exports > maxExports do
        table.remove(db.exports)
    end
    db.lastExport = entry
    return entry
end

local function HandleExportCommand(args)
    local resolver = PvPTip.TooltipResolver
    if not resolver or not resolver.BuildDebugSnapshot then
        print("|cFFFFD100PvPTip:|r Export unavailable (resolver not loaded).")
        return true
    end

    local trimmed = (args or ""):trim()
    if trimmed == "" or trimmed == "spellbook" then
        SaveDebugExport("spellbook", resolver.BuildDebugSnapshot({mode = "spellbook"}))
        print("|cFFFFD100PvPTip:|r Exported spellbook diagnostics to PvPTipDebugDB.lastExport.")
        return true
    end

    local spellID = tonumber(trimmed:match("^spell%s+(%d+)$"))
    if spellID and spellID > 0 then
        SaveDebugExport("spell", resolver.BuildDebugSnapshot({
            mode = "spell",
            spellID = spellID,
        }))
        print(string.format("|cFFFFD100PvPTip:|r Exported spell %d diagnostics to PvPTipDebugDB.lastExport.", spellID))
        return true
    end

    print("|cFFFFD100PvPTip:|r Export usage: /pvptip export spellbook  or  /pvptip export spell <id>")
    return true
end

local function HandleSlashCommand(msg)
    msg = (msg or ""):lower():trim()

    if msg == "help" then
        print("|cFFFFD100PvPTip Commands:|r")
        print("  /pvptip — Toggle the PvPTip window")
        print("  /pvptip help — Show this help")
        print("  /pvptip tooltip — Toggle tooltip display")
        print("  /pvptip mode [compact|verbose|minimal] — Set tooltip mode")
        print("  /pvptip status — Show current status")
        print("  /pvptip export spellbook — Export resolver diagnostics to SavedVariables")
        print("  /pvptip export spell <id> — Export one spell diagnostic snapshot")
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
        print("  Overview scope: " .. (cfg.overviewScope or "class"))
        print("  Tooltips: " .. (cfg.showInTooltips and "on" or "off"))
        print("  PvP Active: " .. (PvPTip.isPvPActive and "yes" or "no"))
    elseif msg:sub(1, 6) == "export" then
        local args = msg:sub(8)
        HandleExportCommand(args)
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
        EnsureDebugDB()

        -- register slash commands
        SLASH_PVPTIP1 = "/pvptip"
        SLASH_PVPTIP2 = "/pt"
        SlashCmdList["PVPTIP"] = HandleSlashCommand

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        UpdateSpecInfo()
        UpdatePvPState()
        InvalidateRuntimeCaches()

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
        InvalidateRuntimeCaches()

    elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        UpdateSpecInfo()
        InvalidateRuntimeCaches()
        -- refresh GUI if open
        if PvPTip.RefreshGUI then PvPTip.RefreshGUI() end

    elseif event == "TRAIT_CONFIG_UPDATED" then
        InvalidateRuntimeCaches()
        -- talent loadout changed
        if PvPTip.RefreshGUI then PvPTip.RefreshGUI() end

    elseif event == "TRAIT_NODE_CHANGED" or event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
        InvalidateRuntimeCaches()

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
eventFrame:RegisterEvent("TRAIT_NODE_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
eventFrame:RegisterEvent("UNIT_AURA")
