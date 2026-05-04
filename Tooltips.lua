PvPTip = PvPTip or {}
local U = PvPTip.Utils
local R = PvPTip.TooltipResolver

local HAS_TOOLTIP_POSTCALLS = TooltipDataProcessor and Enum and Enum.TooltipDataType

local function HasPvPTipLines(tooltip)
    local ok, result = pcall(function()
        for index = 1, tooltip:NumLines() do
            local left = _G[tooltip:GetName() .. "TextLeft" .. index]
            if left then
                local text = left:GetText()
                if text and (text:find("PvP:", 1, true) or text:find("PvP Coefficients:", 1, true)) then
                    return true
                end
            end
        end
        return false
    end)
    return ok and result
end

local function GetTooltipSpellID(tooltip)
    if not tooltip or not tooltip.GetSpell then
        return nil
    end

    local _, spellID = tooltip:GetSpell()
    local numericSpellID = U.SafeToNumber(spellID)
    if numericSpellID then
        return numericSpellID
    end
    return nil
end

local function BuildGroupDisplay(group, cfg)
    local rows, strongestCoefficient = U.GetGroupPvpRows(group, cfg.tooltipMode)
    local durationRows = {}
    local seenDurations = {}

    local function AddDurationRow(spellID)
        local text = U.FormatPvpDurationForSpell(spellID, cfg.tooltipMode)
        if not text or seenDurations[text] then
            return
        end
        seenDurations[text] = true
        table.insert(durationRows, text)
    end

    AddDurationRow(group and group.baseSpellID)
    for _, spellID in ipairs(group and group.resolvedSpellIDs or {}) do
        AddDurationRow(spellID)
    end

    if #rows == 0 and #durationRows == 0 then
        return nil
    end

    return {
        group = group,
        rows = rows,
        durationRows = durationRows,
        strongestCoefficient = strongestCoefficient,
    }
end

local function CanRenderSingleLine(display)
    if not display then
        return false
    end
    if display.durationRows and #display.durationRows > 0 then
        return false
    end
    if #display.rows ~= 1 then
        return false
    end
    return #(display.rows[1].text or "") <= 56
end

local function AddSingleLine(tooltip, display, cfg)
    local row = display.rows[1]
    local text = string.format("1# %s", row.text or "Effect")
    local coefficient = tonumber(row.coefficient) or 1

    local r, g, b = U.GetCoeffColor(coefficient, cfg)
    tooltip:AddDoubleLine("PvP:", text,
        cfg.colors.header[1], cfg.colors.header[2], cfg.colors.header[3],
        r, g, b)
end

local function AddIndentedLine(tooltip, indent, text, r, g, b)
    tooltip:AddLine(string.rep("  ", indent) .. text, r, g, b)
end

local function AddGroupBlock(tooltip, display, cfg, multipleGroups)
    local group = display.group
    local baseIndent = multipleGroups and 1 or 0

    if multipleGroups then
        AddIndentedLine(
            tooltip,
            1,
            group.name,
            cfg.colors.header[1], cfg.colors.header[2], cfg.colors.header[3]
        )
    end

    for _, durationText in ipairs(display.durationRows or {}) do
        AddIndentedLine(
            tooltip,
            baseIndent + 1,
            durationText,
            cfg.colors.neutral[1], cfg.colors.neutral[2], cfg.colors.neutral[3]
        )
    end

    for rowIndex, row in ipairs(display.rows) do
        local text = string.format("%d# %s", rowIndex, row.text or "Effect")
        local coefficient = tonumber(row.coefficient) or 1
        local r, g, b = U.GetCoeffColor(coefficient, cfg)
        AddIndentedLine(tooltip, baseIndent + 1, text, r, g, b)
    end
end

local function IsSpellDataCached(spellID)
    if not (C_Spell and C_Spell.IsSpellDataCached) then
        return true
    end

    local ok, cached = pcall(C_Spell.IsSpellDataCached, spellID)
    if not ok then
        return true
    end
    return cached and true or false
end

local function RequestSpellDataForCandidates(resolved)
    if not (C_Spell and C_Spell.RequestLoadSpellData) then
        return false
    end

    local requested = false
    local candidates = resolved and (resolved.candidateSpellIDs or resolved.spellIDs) or {}
    for _, spellID in ipairs(candidates or {}) do
        local numericSpellID = U.SafeToNumber(spellID)
        if numericSpellID and not IsSpellDataCached(numericSpellID) then
            C_Spell.RequestLoadSpellData(numericSpellID)
            requested = true
        end
    end

    return requested
end

local RenderTooltip

local function QueueRetry(tooltip, data)
    if not (C_Timer and C_Timer.After) then
        return false
    end
    if tooltip.__PvPTipDeferredRetryPending then
        return false
    end

    tooltip.__PvPTipDeferredRetryPending = true
    C_Timer.After(0, function()
        if tooltip then
            tooltip.__PvPTipDeferredRetryPending = nil
        end
        if tooltip and tooltip.IsShown and tooltip:IsShown() then
            RenderTooltip(tooltip, data, true, true)
        end
    end)
    return true
end

RenderTooltip = function(tooltip, data, forceRender, hasRetried)
    local cfg = PvPTip.GetConfig()
    if not cfg.enabled then
        return
    end
    if not forceRender and HasPvPTipLines(tooltip) then
        return
    end

    local resolved = R.ResolveTooltip(tooltip, data)
    if not resolved.primarySpellID then
        local tooltipSpellID = GetTooltipSpellID(tooltip)
        if tooltipSpellID then
            local context = tooltip and tooltip.__PvPTipContext or nil
            if context and context.spellBookItemSlotIndex then
                R.CaptureSpellBookItem(
                    tooltip,
                    context.spellBookItemSlotIndex,
                    context.spellBookItemSpellBank,
                    tooltipSpellID
                )
            elseif context and (context.contextType == "talent" or context.definitionID or context.talentID) then
                R.CaptureTalent(tooltip, {
                    talentID = context.talentID,
                    definitionID = context.definitionID,
                    nodeID = context.nodeID,
                    entryID = context.entryID,
                    rank = context.rank,
                    spellID = tooltipSpellID,
                    configID = context.configID,
                })
            else
                R.CaptureSpell(tooltip, tooltipSpellID)
            end
            resolved = R.ResolveTooltip(tooltip, data)
        end
    end

    if not resolved or not resolved.spellIDs or #resolved.spellIDs == 0 then
        return
    end

    if resolved.contextType == "talent" then
        if not cfg.showInTalents then
            return
        end
    elseif not cfg.showInTooltips then
        return
    end

    local displays = {}
    for _, group in ipairs(U.BuildSpellGroups(resolved.spellIDs, {
        groupByBaseSpell = false,
        resolveHierarchy = true,
    })) do
        local display = BuildGroupDisplay(group, cfg)
        if display then
            table.insert(displays, display)
        end
    end

    if #displays == 0 then
        if not hasRetried and RequestSpellDataForCandidates(resolved) then
            QueueRetry(tooltip, data)
        end
        return
    end

    if #displays == 1 and CanRenderSingleLine(displays[1]) then
        AddSingleLine(tooltip, displays[1], cfg)
    else
        tooltip:AddLine("PvP Coefficients:", cfg.colors.header[1], cfg.colors.header[2], cfg.colors.header[3])
        local multipleGroups = #displays > 1
        for _, display in ipairs(displays) do
            AddGroupBlock(tooltip, display, cfg, multipleGroups)
        end
    end

    tooltip:Show()
end

local function Hook(target, methodName, callback)
    if target and target[methodName] then
        hooksecurefunc(target, methodName, callback)
    end
end

local function AddPostCall(dataType)
    if HAS_TOOLTIP_POSTCALLS and dataType ~= nil then
        TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip, data)
            RenderTooltip(tooltip, data)
        end)
    end
end

AddPostCall(Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell)
AddPostCall(Enum and Enum.TooltipDataType and Enum.TooltipDataType.UnitAura)

Hook(GameTooltip, "SetSpellByID", function(tooltip, spellID)
    R.CaptureSpell(tooltip, spellID)
    if not HAS_TOOLTIP_POSTCALLS then
        RenderTooltip(tooltip)
    end
end)

Hook(GameTooltip, "SetSpellBookItem", function(tooltip, slotIndex, spellBank)
    R.CaptureSpellBookItem(tooltip, slotIndex, spellBank, GetTooltipSpellID(tooltip))
    if not HAS_TOOLTIP_POSTCALLS then
        RenderTooltip(tooltip)
    end
end)

Hook(GameTooltip, "SetHyperlink", function(tooltip, hyperlink)
    R.CaptureHyperlink(tooltip, hyperlink)
    if not HAS_TOOLTIP_POSTCALLS then
        RenderTooltip(tooltip)
    end
end)

Hook(ItemRefTooltip, "SetHyperlink", function(tooltip, hyperlink)
    R.CaptureHyperlink(tooltip, hyperlink)
    if not HAS_TOOLTIP_POSTCALLS then
        RenderTooltip(tooltip)
    end
end)

Hook(GameTooltip, "SetAction", function(tooltip, slot)
    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" then
        R.CaptureSpell(tooltip, id)
    elseif actionType == "macro" and GetMacroSpell then
        local spellID = GetMacroSpell(id)
        if spellID then
            R.CaptureSpell(tooltip, spellID)
        end
    end

    if not HAS_TOOLTIP_POSTCALLS then
        RenderTooltip(tooltip)
    end
end)

Hook(GameTooltip, "SetPetAction", function(tooltip, slot)
    local _, _, _, _, _, spellID = GetPetActionInfo(slot)
    if spellID and spellID > 0 then
        R.CaptureSpell(tooltip, spellID)
        if not HAS_TOOLTIP_POSTCALLS then
            RenderTooltip(tooltip)
        end
    end
end)

Hook(GameTooltip, "SetPvpTalent", function(tooltip, talentID)
    R.CaptureTalent(tooltip, {
        talentID = tonumber(talentID),
        spellID = GetTooltipSpellID(tooltip),
        configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() or nil,
    })
    if not HAS_TOOLTIP_POSTCALLS then
        RenderTooltip(tooltip)
    end
end)

Hook(GameTooltip, "SetTalent", function(tooltip)
    R.CaptureTalent(tooltip, {
        spellID = GetTooltipSpellID(tooltip),
        configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() or nil,
    })
    if not HAS_TOOLTIP_POSTCALLS then
        RenderTooltip(tooltip)
    end
end)

if TalentDisplayMixin then
    Hook(TalentDisplayMixin, "SetTooltipInternal", function(button)
        if not button then
            return
        end

        local entryID = button.entryID
        if not entryID and type(button.activeEntry) == "table" then
            entryID = button.activeEntry.entryID
        elseif not entryID and type(button.activeEntry) == "number" then
            entryID = button.activeEntry
        end

        local spellID
        local tooltipSpellID = GetTooltipSpellID(GameTooltip)
        if tooltipSpellID then
            spellID = tooltipSpellID
        elseif button.definitionID then
            for _, resolvedSpellID in ipairs(U.GetTraitDefinitionSpellIDs(button.definitionID)) do
                spellID = resolvedSpellID
                break
            end
        end

        R.CaptureTalent(GameTooltip, {
            talentID = button.talentID,
            definitionID = button.definitionID,
            nodeID = button.nodeID,
            entryID = entryID,
            rank = button.rank,
            spellID = spellID,
            configID = button.configID or (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() or nil),
        })
        RenderTooltip(GameTooltip)
    end)
end

PvPTip.AddPvPLines = RenderTooltip
