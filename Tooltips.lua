-- tooltips.lua 
PvPTip = PvPTip or {}
local U = PvPTip.Utils

-------------------------------------------------------------------------------
-- tooltip deduplication
-------------------------------------------------------------------------------

local function HasPvPTipLines(tooltip)
    for i = 1, tooltip:NumLines() do
        local left = _G[tooltip:GetName() .. "TextLeft" .. i]
        if left then
            local text = left:GetText()
            if text and (text:find("PvP:") or text:find("PvP Coefficients")) then
                return true
            end
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- add PvP coefficient lines to a tooltip
-------------------------------------------------------------------------------

local function AddPvPLines(tooltip, spellID)
    if not spellID or spellID == 0 then return end
    if not PvPTipData then return end

    local cfg = PvPTip.GetConfig()
    if not cfg.enabled or not cfg.showInTooltips then return end

    -- avoid duplicate lines
    if HasPvPTipLines(tooltip) then return end

    local resolvedID, isParent = U.ResolveSpellID(spellID)
    if not resolvedID then return end

    local hr, hg, hb = cfg.colors.header[1], cfg.colors.header[2], cfg.colors.header[3]

    -- collect spellIDs to check for affected-by (may be multiple children)
    local affectedByIDs = {}

    if isParent then
        -- parent spell: show children's coefficients
        local children = PvPTipData.SpellParents[resolvedID]
        if not children then return end

        local allParts = {}
        local anyData = false

        for _, childID in ipairs(children) do
            local childData = PvPTipData.Spells[childID]
            if childData then
                for _, eff in ipairs(childData.e) do
                    if math.abs(eff.p - 1.0) > 0.001 then
                        anyData = true
                        local text, mult = FormatEffect(eff, childID, cfg)
                        local r, g, b = U.GetCoeffColor(mult, cfg)
                        table.insert(allParts, {text = text, r = r, g = g, b = b, mult = mult})
                    end
                end
                affectedByIDs[childID] = true
            end
        end

        if not anyData then return end

        -- deduplicate identical entries
        local seen = {}
        local unique = {}
        for _, part in ipairs(allParts) do
            if not seen[part.text] then
                seen[part.text] = true
                table.insert(unique, part)
            end
        end

        AddFormattedLines(tooltip, unique, cfg, hr, hg, hb, affectedByIDs)
    else
        -- direct spell
        local spellData = PvPTipData.Spells[resolvedID]
        if not spellData then return end

        local parts = {}
        for _, eff in ipairs(spellData.e) do
            if math.abs(eff.p - 1.0) > 0.001 then
                local text, mult = FormatEffect(eff, resolvedID, cfg)
                local r, g, b = U.GetCoeffColor(mult, cfg)
                table.insert(parts, {text = text, r = r, g = g, b = b, mult = mult})
            end
        end

        if #parts == 0 then return end

        affectedByIDs[resolvedID] = true
        AddFormattedLines(tooltip, parts, cfg, hr, hg, hb, affectedByIDs)
    end
end

-------------------------------------------------------------------------------
-- format a single effect based on tooltip mode
-------------------------------------------------------------------------------

function FormatEffect(eff, spellID, cfg)
    local mode = cfg.tooltipMode
    if mode == "verbose" then
        return U.FormatEffectVerbose(eff, spellID)
    elseif mode == "minimal" then
        return U.FormatEffectMinimal(eff, spellID)
    else
        return U.FormatEffectCompact(eff, spellID)
    end
end

-------------------------------------------------------------------------------
-- add formatted lines to tooltip
-------------------------------------------------------------------------------

function AddFormattedLines(tooltip, parts, cfg, hr, hg, hb, affectedByIDs)
    local mode = cfg.tooltipMode

    if mode == "verbose" then
        -- multi-line: header, then one line per effect
        tooltip:AddLine("PvP Coefficients:", hr, hg, hb)
        for _, part in ipairs(parts) do
            tooltip:AddLine("  " .. part.text, part.r, part.g, part.b)
        end
    elseif mode == "compact" then
        if #parts == 1 then
            tooltip:AddDoubleLine("PvP:", parts[1].text, hr, hg, hb, parts[1].r, parts[1].g, parts[1].b)
        else
            -- check combined text length to decide layout
            local combined = {}
            local totalLen = 0
            for _, part in ipairs(parts) do
                table.insert(combined, part.text)
                totalLen = totalLen + #part.text
            end
            -- add separators length
            totalLen = totalLen + (#parts - 1) * 3

            if #parts <= 3 and totalLen <= 55 then
                -- short enough for one line
                local mainPart = parts[1]
                for _, part in ipairs(parts) do
                    if math.abs(part.mult - 1.0) > math.abs(mainPart.mult - 1.0) then
                        mainPart = part
                    end
                end
                tooltip:AddDoubleLine("PvP:", table.concat(combined, " | "),
                    hr, hg, hb, mainPart.r, mainPart.g, mainPart.b)
            else
                -- too long or too many: header + individual lines
                tooltip:AddLine("PvP:", hr, hg, hb)
                for _, part in ipairs(parts) do
                    tooltip:AddLine("  " .. part.text, part.r, part.g, part.b)
                end
            end
        end
    else -- minimal
        if #parts == 1 then
            tooltip:AddDoubleLine("PvP:", parts[1].text, hr, hg, hb, parts[1].r, parts[1].g, parts[1].b)
        else
            local combined = {}
            local totalLen = 0
            for _, part in ipairs(parts) do
                table.insert(combined, part.text)
                totalLen = totalLen + #part.text
            end
            totalLen = totalLen + (#parts - 1) * 3

            local mainPart = parts[1]
            for _, part in ipairs(parts) do
                if math.abs(part.mult - 1.0) > math.abs(mainPart.mult - 1.0) then
                    mainPart = part
                end
            end

            if totalLen <= 55 then
                tooltip:AddDoubleLine("PvP:", table.concat(combined, " | "),
                    hr, hg, hb, mainPart.r, mainPart.g, mainPart.b)
            else
                tooltip:AddLine("PvP:", hr, hg, hb)
                for _, part in ipairs(parts) do
                    tooltip:AddLine("  " .. part.text, part.r, part.g, part.b)
                end
            end
        end
    end

    -- affected-by: show modifier auras (compact & verbose only, skip minimal)
    if mode ~= "minimal" and affectedByIDs then
        local seenMods = {}
        local modLines = {}
        for spellID in pairs(affectedByIDs) do
            local affectedBy = U.GetAffectedBy(spellID)
            if affectedBy then
                for _, mod in ipairs(affectedBy) do
                    local key = mod.auraID .. mod.type
                    if not seenMods[key] then
                        seenMods[key] = true
                        local sign = mod.value >= 0 and "+" or ""
                        local typeTag = mod.type == "label" and "label" or "mask"
                        table.insert(modLines, string.format("  %s %s%s%% (%s)",
                            mod.name, sign, mod.value, typeTag))
                    end
                end
            end
        end
        if #modLines > 0 then
            local nr, ng, nb = cfg.colors.neutral[1], cfg.colors.neutral[2], cfg.colors.neutral[3]
            tooltip:AddLine("Affected by:", nr * 0.8, ng * 0.8, nb * 0.8)
            for _, line in ipairs(modLines) do
                tooltip:AddLine(line, nr * 0.7, ng * 0.7, nb * 0.7)
            end
        end
    end

    tooltip:Show()
end

-------------------------------------------------------------------------------
-- hook helpers
-------------------------------------------------------------------------------

local function hook(tbl, fn, cb)
    if tbl and tbl[fn] then
        hooksecurefunc(tbl, fn, cb)
    end
end

local function hookScript(frame, event, cb)
    if frame and frame.HasScript and frame:HasScript(event) then
        frame:HookScript(event, cb)
    end
end

-------------------------------------------------------------------------------
-- spell tooltip hooks
-------------------------------------------------------------------------------

-- TooltipDataProcessor
if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.Spell,
        function(tooltip, data)
            if tooltip ~= GameTooltip then return end
            if not data or not data.id then return end
            AddPvPLines(tooltip, data.id)
        end
    )
end

-- SetSpellByID fallback
hook(GameTooltip, "SetSpellByID", function(tooltip, spellID)
    AddPvPLines(tooltip, spellID)
end)

-- action bar buttons
hook(GameTooltip, "SetAction", function(tooltip, slot)
    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" then
        AddPvPLines(tooltip, id)
    elseif actionType == "macro" then
        -- try to get spell from macro
        local spellID = GetMacroSpell and GetMacroSpell(id)
        if spellID then
            AddPvPLines(tooltip, spellID)
        end
    end
end)

-- pet action bar (to do)
hook(GameTooltip, "SetPetAction", function(tooltip, slot)
    -- pet spells: try to extract spellID
    if C_ActionBar and C_ActionBar.GetPetActionPetBarIndices then
        local name, texture, isToken, isActive, autoCast, spellID = GetPetActionInfo(slot)
        if spellID and spellID > 0 then
            AddPvPLines(tooltip, spellID)
        end
    end
end)

-- hyperlinks in chat
hook(GameTooltip, "SetHyperlink", function(tooltip, link)
    if not link then return end
    local spellID = link:match("spell:(%d+)")
    if spellID then
        AddPvPLines(tooltip, tonumber(spellID))
    end
end)

-------------------------------------------------------------------------------
-- talent tree tooltip hooks
-------------------------------------------------------------------------------

if TalentDisplayMixin then
    hook(TalentDisplayMixin, "SetTooltipInternal", function(btn)
        if not btn then return end
        -- get the spell ID from the talent definition
        local defID = btn.definitionID
        if defID and C_Traits and C_Traits.GetDefinitionInfo then
            local defInfo = C_Traits.GetDefinitionInfo(defID)
            if defInfo and defInfo.spellID then
                AddPvPLines(GameTooltip, defInfo.spellID)
            end
            -- also check overriddenSpellID
            if defInfo and defInfo.overriddenSpellID and defInfo.overriddenSpellID > 0 then
                AddPvPLines(GameTooltip, defInfo.overriddenSpellID)
            end
        end
    end)
end

-- PvP talent tooltips.. do they ever scale these? if they do, i cant figure out how to do this correctly
if PvPTalentSlotMixin then
    hook(PvPTalentSlotMixin, "OnEnter", function(self)
        local talentID = self.talentID
        if talentID then
            local _, name, icon, selected, available, spellID = GetPvpTalentInfoByID(talentID)
            if spellID then
                AddPvPLines(GameTooltip, spellID)
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- unit aura tooltip hooks (buffs/debuffs on unit frames)
-------------------------------------------------------------------------------

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.UnitAura,
        function(tooltip, data)
            if tooltip ~= GameTooltip then return end
            if not data or not data.id then return end
            AddPvPLines(tooltip, data.id)
        end
    )
end

-- expose 
PvPTip.AddPvPLines = AddPvPLines
