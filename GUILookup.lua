PvPTip = PvPTip or {}
local UI = PvPTip.UI
local U = PvPTip.Utils

local selectedClassID
local scrollContainer
local summaryText
local spellRows = {}

local function CollectSpellGroups(mode)
    if not selectedClassID then
        return {}
    end

    local groups = {}
    for _, group in ipairs(U.BuildSpellGroups(U.BuildClassSourceSpellIDs(selectedClassID), {
        groupByBaseSpell = false,
        resolveHierarchy = false,
    })) do
        local summary, strongestCoefficient = U.GetGroupSummary(group, mode or "compact")
        if summary then
            table.insert(groups, {
                id = group.baseSpellID,
                group = group,
                name = group.name,
                summary = summary,
                mult = strongestCoefficient or 1,
                sortName = string.lower(group.name or ""),
            })
        end
    end

    table.sort(groups, function(left, right)
        return left.sortName < right.sortName
    end)
    return groups
end

function PvPTip.BuildLookupPanel(panel)
    local padding = UI.Sizes.padding
    local yOffset = -padding

    local header = UI.CreateSectionHeader(
        panel,
        "Class Lookup",
        "Browse class-wide retained spell sources. Display rows show only direct per-ability PvP coefficients."
    )
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOffset)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -padding, yOffset)
    yOffset = yOffset - 44

    local classOptions = {}
    local sortedClasses = {}
    for classID, classData in pairs(U.GetClassDataMap()) do
        table.insert(sortedClasses, {
            id = classID,
            name = classData.name or classData.n or ("Class #" .. tostring(classID)),
        })
    end
    table.sort(sortedClasses, function(left, right)
        return left.name < right.name
    end)
    for _, entry in ipairs(sortedClasses) do
        table.insert(classOptions, {label = entry.name, value = entry.id})
    end

    if not selectedClassID or not U.GetClassDataMap()[selectedClassID] then
        selectedClassID = PvPTip.currentClassID or (sortedClasses[1] and sortedClasses[1].id) or nil
    end

    local classDropdown = UI.CreateDropdown(panel, "Class:",
        classOptions,
        function() return selectedClassID end,
        function(value)
            selectedClassID = value
            PvPTip.RefreshLookup()
        end
    )
    classDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOffset)
    classDropdown:SetWidth(400)
    yOffset = yOffset - 36

    summaryText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOffset)
    summaryText:SetTextColor(0.6, 0.6, 0.6)
    summaryText:SetText("Select a class to browse direct ability coefficients")
    yOffset = yOffset - 20

    local divider = UI.CreateDivider(panel)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, yOffset)
    yOffset = yOffset - 8

    scrollContainer = UI.CreateScrollFrame(panel)
    scrollContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOffset)
    scrollContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding, padding)
end

function PvPTip.RefreshLookup()
    if not scrollContainer then
        return
    end

    for _, row in ipairs(spellRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(spellRows)

    if not selectedClassID then
        if summaryText then
            summaryText:SetText("Select a class to begin")
        end
        scrollContainer:SetContentHeight(0)
        return
    end

    local cfg = PvPTip.GetConfig()
    local spellList = CollectSpellGroups(cfg.tooltipMode)

    if summaryText then
        local buffs = 0
        local nerfs = 0
        for _, spell in ipairs(spellList) do
            if spell.mult > 1.001 then
                buffs = buffs + 1
            elseif spell.mult < 0.999 then
                nerfs = nerfs + 1
            end
        end
        summaryText:SetText(string.format("%d direct abilities  |  %d buffs  |  %d nerfs", #spellList, buffs, nerfs))
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
