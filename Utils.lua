-- utils.lua
PvPTip = PvPTip or {}
PvPTip.Utils = {}
local U = PvPTip.Utils

-------------------------------------------------------------------------------
-- spell helpers
-------------------------------------------------------------------------------

function U.GetSpellName(spellID, fallback)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name then return name end
    end
    -- Fallback to data table
    local data = PvPTipData and PvPTipData.Spells and PvPTipData.Spells[spellID]
    if data then return data.n end
    return fallback or ("Spell #" .. spellID)
end

function U.GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local icon = C_Spell.GetSpellTexture(spellID)
        if icon then return icon end
    end
    return 134400 -- default question mark icon
end

-------------------------------------------------------------------------------
-- spell ID resolution
-------------------------------------------------------------------------------

function U.ResolveSpellID(spellID)
    -- returns: spellID (or list for parents), isParent
    if not PvPTipData then return nil, false end

    -- direct hit
    if PvPTipData.Spells[spellID] then
        return spellID, false
    end

    -- parent spell > children
    if PvPTipData.SpellParents[spellID] then
        return spellID, true
    end

    -- check static spell replacement table (original | replacement)
    if PvPTipData.SpellReplacements then
        local repl = PvPTipData.SpellReplacements[spellID]
        if repl then
            if PvPTipData.Spells[repl] then return repl, false end
            if PvPTipData.SpellParents[repl] then return repl, true end
        end
    end

    -- try WoW API override/base spell resolution
    if C_Spell then
        if C_Spell.GetOverrideSpell then
            local override = C_Spell.GetOverrideSpell(spellID)
            if override and override ~= spellID then
                if PvPTipData.Spells[override] then return override, false end
                if PvPTipData.SpellParents[override] then return override, true end
            end
        end
        if C_Spell.GetBaseSpell then
            local base = C_Spell.GetBaseSpell(spellID)
            if base and base ~= spellID then
                if PvPTipData.Spells[base] then return base, false end
                if PvPTipData.SpellParents[base] then return base, true end
            end
        end
    end

    return nil, false
end

-------------------------------------------------------------------------------
-- PvP multiplier computation
-------------------------------------------------------------------------------

function U.ComputeEffectivePvpMult(spellID, baseMult)
    -- apply modifier auras from SpellModLookup
    -- formula: effective = baseMult * (1 + sum(mod_values) / 100)
    if not PvPTipData or not PvPTipData.SpellModLookup then
        return baseMult
    end

    local mods = PvPTipData.SpellModLookup[spellID]
    if not mods then return baseMult end

    local totalMod = 0
    for _, entry in ipairs(mods) do
        -- entry = {auraSpellID, modType, modValue}
        totalMod = totalMod + entry[3]
    end

    return baseMult * (1 + totalMod / 100)
end

-------------------------------------------------------------------------------
-- formatting
-------------------------------------------------------------------------------

function U.FormatPct(mult)
    -- 1.74 > "+74%", 0.7 > "-30%", 1.0 > "+0%"
    local pct = (mult - 1) * 100
    if pct >= 0 then
        return string.format("+%d%%", math.floor(pct + 0.5))
    else
        return string.format("%d%%", math.floor(pct - 0.5))
    end
end

function U.GetCoeffColor(mult, cfg)
    if mult > 1.001 then
        return cfg.colors.buff[1], cfg.colors.buff[2], cfg.colors.buff[3]
    elseif mult < 0.999 then
        return cfg.colors.nerf[1], cfg.colors.nerf[2], cfg.colors.nerf[3]
    else
        return cfg.colors.neutral[1], cfg.colors.neutral[2], cfg.colors.neutral[3]
    end
end

function U.FormatEffectCompact(eff, spellID)
    -- returns "Damage +74%" or "DoT -15%"
    local effectiveMult = U.ComputeEffectivePvpMult(spellID, eff.p)
    local pctStr = U.FormatPct(effectiveMult)
    return eff.t .. " " .. pctStr, effectiveMult
end

function U.FormatEffectVerbose(eff, spellID)
    -- returns "#0 Damage: PvP 1.275 (+27%) [Arms Warrior +20% > effective +53%]"
    local baseMult = eff.p
    local effectiveMult = U.ComputeEffectivePvpMult(spellID, baseMult)
    local basePct = U.FormatPct(baseMult)
    local effPct = U.FormatPct(effectiveMult)

    local line = string.format("#%d %s: PvP %.3f (%s)", eff.i, eff.t, baseMult, basePct)

    -- add modifier info if different from base
    if math.abs(effectiveMult - baseMult) > 0.001 then
        local mods = PvPTipData.SpellModLookup and PvPTipData.SpellModLookup[spellID]
        if mods then
            local modParts = {}
            for _, entry in ipairs(mods) do
                local auraName = "Unknown"
                local auraData = PvPTipData.PvpModAuras and PvPTipData.PvpModAuras[entry[1]]
                if auraData then auraName = auraData.n end
                local sign = entry[3] >= 0 and "+" or ""
                table.insert(modParts, auraName .. " " .. sign .. entry[3] .. "%")
            end
            line = line .. " [" .. table.concat(modParts, ", ") .. " -> " .. effPct .. "]"
        end
    end

    return line, effectiveMult
end

function U.FormatEffectMinimal(eff, spellID)
    -- returns just "+74%" or "-15%"
    local effectiveMult = U.ComputeEffectivePvpMult(spellID, eff.p)
    return U.FormatPct(effectiveMult), effectiveMult
end

-------------------------------------------------------------------------------
-- color utilities
-------------------------------------------------------------------------------

-- WoW class colors (ClassID → r,g,b)
U.CLASS_COLORS = {
    [1]  = {0.78, 0.61, 0.43}, -- Warrior
    [2]  = {0.96, 0.55, 0.73}, -- Paladin
    [3]  = {0.67, 0.83, 0.45}, -- Hunter
    [4]  = {1.00, 0.96, 0.41}, -- Rogue
    [5]  = {1.00, 1.00, 1.00}, -- Priest
    [6]  = {0.77, 0.12, 0.23}, -- Death Knight
    [7]  = {0.00, 0.44, 0.87}, -- Shaman
    [8]  = {0.25, 0.78, 0.92}, -- Mage
    [9]  = {0.53, 0.53, 0.93}, -- Warlock
    [10] = {0.00, 1.00, 0.60}, -- Monk
    [11] = {1.00, 0.49, 0.04}, -- Druid
    [12] = {0.64, 0.19, 0.79}, -- Demon Hunter
    [13] = {0.20, 0.58, 0.50}, -- Evoker
}

-- SpellClassSet > ClassID mapping
U.FAMILY_TO_CLASS = {
    [3] = 8, [4] = 1, [5] = 9, [6] = 5, [7] = 11,
    [8] = 4, [9] = 3, [10] = 2, [11] = 7, [13] = 10,
    [15] = 6, [33] = 12, [53] = 13,
}
