PvPTip = PvPTip or {}
local UI = PvPTip.UI
local U = PvPTip.Utils

local scrollContainer
local spellRows = {}
local OVERVIEW_SCOPE_OPTIONS = {
    {label = "Class", value = "class"},
    {label = "Spec", value = "spec"},
}

local function AddSpellID(list, seen, spellID)
    local numericSpellID = tonumber(spellID)
    if not numericSpellID or numericSpellID <= 0 or seen[numericSpellID] then
        return
    end
    seen[numericSpellID] = true
    table.insert(list, numericSpellID)
end

local function EnumeratePlayerKnownSpells()
    local knownSpellIDs = {}
    local seen = {}
    local specID = PvPTip.currentSpecID or 0

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local numLines = C_SpellBook.GetNumSpellBookSkillLines()
        for lineIndex = 1, numLines do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
            if lineInfo then
                local startIndex = lineInfo.itemIndexOffset + 1
                for slot = startIndex, startIndex + lineInfo.numSpellBookItems - 1 do
                    local itemInfo = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                    if itemInfo then
                        AddSpellID(knownSpellIDs, seen, itemInfo.spellID or itemInfo.actionID)
                    end
                end
            end
        end
    end

    for _, spellID in ipairs((U.GetDataTable("SpecSpells") or {})[specID] or {}) do
        AddSpellID(knownSpellIDs, seen, spellID)
    end
    for _, spellID in ipairs(U.GetSpecDisplaySpellIDs(specID)) do
        AddSpellID(knownSpellIDs, seen, spellID)
    end

    if C_ClassTalents and C_Traits then
        local configID = C_ClassTalents.GetActiveConfigID()
        local treeID = specID > 0 and C_ClassTalents.GetTraitTreeForSpec(specID) or nil
        local nodeIDs = treeID and C_Traits.GetTreeNodes(treeID) or nil
        if configID and nodeIDs then
            for _, nodeID in ipairs(nodeIDs) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                local activeEntry = nodeInfo and nodeInfo.activeEntry
                local entryID = type(activeEntry) == "table" and activeEntry.entryID or activeEntry
                local entryInfo = entryID and C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, entryID) or nil
                local definitionID = entryInfo and entryInfo.definitionID

                if definitionID then
                    for _, spellID in ipairs(U.GetTraitDefinitionSpellIDs(definitionID)) do
                        AddSpellID(knownSpellIDs, seen, spellID)
                    end
                end
            end
        end
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs then
        for _, talentID in ipairs(C_SpecializationInfo.GetAllSelectedPvpTalentIDs() or {}) do
            local talentData = (U.GetDataTable("PvpTalents") or {})[talentID]
            if talentData then
                AddSpellID(knownSpellIDs, seen, talentData.actionBarSpellID)
                AddSpellID(knownSpellIDs, seen, talentData.overridesSpellID)
                for _, spellID in ipairs(talentData.resolvedSpellIDs or {}) do
                    AddSpellID(knownSpellIDs, seen, spellID)
                end
            end

            if C_SpecializationInfo.GetPvpTalentInfo then
                local talentInfo = C_SpecializationInfo.GetPvpTalentInfo(talentID)
                if talentInfo then
                    AddSpellID(knownSpellIDs, seen, talentInfo.spellID)
                end
            end
        end
    end

    table.sort(knownSpellIDs)
    return knownSpellIDs
end

local function GetOverviewScope()
    local scope = PvPTip.GetConfig().overviewScope
    if scope == "spec" then
        return "spec"
    end
    return "class"
end

local function GetOverviewScopeLabel(scope)
    if scope == "spec" then
        return "Spec"
    end
    return "Class"
end

local function GetOverviewInfoNote(scope, className)
    if scope == "spec" then
        return "This list is built from your live spellbook, selected talents, and selected PvP talents."
    end
    return string.format(
        "This list pulls retained %s spell sources from class abilities, specs, talents, and PvP talents. Rows show only direct per-ability PvP coefficients.",
        className or "class"
    )
end

local function GetOverviewSourceSpellIDs(scope, classID)
    if scope == "spec" then
        return EnumeratePlayerKnownSpells()
    end
    return U.BuildClassSourceSpellIDs(classID)
end

function PvPTip.BuildOverviewPanel(panel)
    local padding = UI.Sizes.padding

    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(82)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, -padding)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -padding, -padding)

    local specText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    specText:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    specText:SetText("Loading...")
    specText:SetTextColor(1, 1, 1)
    panel.specText = specText

    local pvpIndicator = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pvpIndicator:SetPoint("LEFT", specText, "RIGHT", 12, 0)
    panel.pvpIndicator = pvpIndicator

    local buildInfo = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buildInfo:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    buildInfo:SetTextColor(0.5, 0.5, 0.5)
    panel.buildInfo = buildInfo

    local scopeDropdown = UI.CreateDropdown(
        header,
        "Scope:",
        OVERVIEW_SCOPE_OPTIONS,
        function()
            return GetOverviewScope()
        end,
        function(value)
            PvPTip.GetConfig().overviewScope = value
            PvPTip.RefreshOverview()
        end
    )
    scopeDropdown:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -24)
    scopeDropdown:SetWidth(260)
    scopeDropdown.btn:SetWidth(120)
    scopeDropdown.menu:SetWidth(120)
    panel.scopeDropdown = scopeDropdown

    local summaryText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("TOPLEFT", specText, "BOTTOMLEFT", 0, -4)
    summaryText:SetTextColor(0.6, 0.6, 0.6)
    panel.summaryText = summaryText

    local divider = UI.CreateDivider(panel, "Active Tooltips")
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -padding, -4)
    divider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", padding, -4)

    local infoNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoNote:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", padding + 4, -2)
    infoNote:SetPoint("RIGHT", panel, "RIGHT", -padding - 4, 0)
    infoNote:SetJustifyH("LEFT")
    infoNote:SetWordWrap(true)
    infoNote:SetTextColor(0.45, 0.45, 0.45)
    panel.infoNote = infoNote

    scrollContainer = UI.CreateScrollFrame(panel)
    scrollContainer:SetPoint("TOPLEFT", infoNote, "BOTTOMLEFT", -4, -4)
    scrollContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding, padding)

    panel.scrollContainer = scrollContainer
end

function PvPTip.RefreshOverview()
    if not scrollContainer then
        return
    end

    local panel = scrollContainer:GetParent()
    local cfg = PvPTip.GetConfig()

    for _, row in ipairs(spellRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(spellRows)

    local specID = PvPTip.currentSpecID or 0
    local classID = PvPTip.currentClassID or 0
    local specName = U.GetSpecName(specID, "Unknown")
    local className = U.GetClassName(classID, "Unknown")
    local scope = GetOverviewScope()
    local scopeLabel = GetOverviewScopeLabel(scope)

    if panel.scopeDropdown and panel.scopeDropdown.Update then
        panel.scopeDropdown.Update()
    end

    if panel.specText then
        panel.specText:SetText(specName .. " " .. className)
        local classColor = U.CLASS_COLORS[classID]
        if classColor then
            panel.specText:SetTextColor(classColor[1], classColor[2], classColor[3])
        end
    end

    if panel.pvpIndicator then
        if PvPTip.isPvPActive then
            panel.pvpIndicator:SetText("|cFF00FF00PvP rules active|r")
        else
            panel.pvpIndicator:SetText("|cFF666666PvP rules inactive|r")
        end
    end

    if panel.buildInfo then
        local dataBuild = PvPTipData and PvPTipData.Build or "unknown"
        local clientBuild = PvPTip.clientBuild or "unknown"
        if dataBuild ~= "unknown" and clientBuild ~= "unknown" and dataBuild ~= clientBuild then
            panel.buildInfo:SetText("|cFFFF6600Build: " .. dataBuild .. " (client: " .. clientBuild .. ")|r")
        else
            panel.buildInfo:SetText("Build: " .. dataBuild)
        end
    end

    if panel.infoNote then
        panel.infoNote:SetText(GetOverviewInfoNote(scope, className))
    end

    local spellList = {}
    for _, group in ipairs(U.BuildSpellGroups(GetOverviewSourceSpellIDs(scope, classID), {
        groupByBaseSpell = false,
        resolveHierarchy = false,
    })) do
        local summary, strongestCoefficient = U.GetGroupSummary(group, cfg.tooltipMode)
        if summary then
            table.insert(spellList, {
                id = group.baseSpellID,
                group = group,
                name = group.name,
                summary = summary,
                mult = strongestCoefficient or 1,
                sortName = string.lower(group.name or ""),
            })
        end
    end

    table.sort(spellList, function(left, right)
        return left.sortName < right.sortName
    end)

    if panel.summaryText then
        local buffs = 0
        local nerfs = 0
        for _, spell in ipairs(spellList) do
            if spell.mult > 1.001 then
                buffs = buffs + 1
            elseif spell.mult < 0.999 then
                nerfs = nerfs + 1
            end
        end
        panel.summaryText:SetText(string.format(
            "%s scope  |  %d direct abilities  |  %d buffs  |  %d nerfs",
            scopeLabel,
            #spellList,
            buffs,
            nerfs
        ))
    end

    local scrollChild = scrollContainer.scrollChild
    local yOffset = 0

    for _, spell in ipairs(spellList) do
        local r, g, b = U.GetCoeffColor(spell.mult, cfg)
        local row = UI.CreateSpellRow(scrollChild, spell.id, spell.name, spell.summary, r, g, b)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
        row:Show()
        table.insert(spellRows, row)
        yOffset = yOffset + UI.Sizes.rowH
    end

    scrollContainer:SetContentHeight(yOffset + 20)
end
