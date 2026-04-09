-- guilookup.lua 
PvPTip = PvPTip or {}
local UI = PvPTip.UI
local U = PvPTip.Utils

-------------------------------------------------------------------------------
-- state
-------------------------------------------------------------------------------

local selectedClassID = nil
local scrollContainer
local summaryText
local spellRows = {}

-------------------------------------------------------------------------------
-- build panel
-------------------------------------------------------------------------------

function PvPTip.BuildLookupPanel(panel)
    local padding = UI.Sizes.padding
    local yOff = -padding

    -- Header
    local header = UI.CreateSectionHeader(panel, "Advanced Lookup",
        "Browse PvP coefficients for any class")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOff)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -padding, yOff)
    yOff = yOff - 44

    -- class dropdown (only playable classes)
    local classOptions = {}
    if PvPTipData and PvPTipData.Classes then
        local sorted = {}
        for cid, data in pairs(PvPTipData.Classes) do
            table.insert(sorted, {id = cid, name = data.n})
        end
        table.sort(sorted, function(a, b) return a.name < b.name end)
        for _, entry in ipairs(sorted) do
            table.insert(classOptions, {label = entry.name, value = entry.id})
        end
    end

    local classDD = UI.CreateDropdown(panel, "Class:",
        classOptions,
        function() return selectedClassID end,
        function(v)
            selectedClassID = v
            RefreshResults()
        end
    )
    classDD:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOff)
    classDD:SetWidth(400)
    yOff = yOff - 36

    -- summary bar
    summaryText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOff)
    summaryText:SetTextColor(0.6, 0.6, 0.6)
    summaryText:SetText("Select a class to begin")
    yOff = yOff - 20

    -- divider
    local divider = UI.CreateDivider(panel)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOff)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, yOff)
    yOff = yOff - 8

    -- scrollable results
    scrollContainer = UI.CreateScrollFrame(panel)
    scrollContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, yOff)
    scrollContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding, padding)
end

-------------------------------------------------------------------------------
-- collect all spells for a class (all specs combined, class-level view)
-------------------------------------------------------------------------------

local function CollectSpells()
    if not selectedClassID or not PvPTipData or not PvPTipData.Spells then
        return {}
    end

    -- get the class family for this class
    local classFamily = 0
    for family, cid in pairs(U.FAMILY_TO_CLASS) do
        if cid == selectedClassID then
            classFamily = family
            break
        end
    end

    local spellList = {}
    local seen = {}

    for spellID, spellData in pairs(PvPTipData.Spells) do
        -- strict class match: only spells belonging to this class family
        if spellData.c == classFamily and classFamily > 0 then
            -- build effect summary using raw base coefficients
            local parts = {}
            local maxDeviation = 0
            local mainMult = 1

            for _, eff in ipairs(spellData.e) do
                if math.abs(eff.p - 1.0) > 0.001 then
                    table.insert(parts, eff.t .. " " .. U.FormatPct(eff.p))
                    local dev = math.abs(eff.p - 1.0)
                    if dev > maxDeviation then
                        maxDeviation = dev
                        mainMult = eff.p
                    end
                end
            end

            if #parts > 0 and not seen[spellID] then
                seen[spellID] = true
                table.insert(spellList, {
                    id = spellID,
                    name = spellData.n,
                    summary = table.concat(parts, " | "),
                    mult = mainMult,
                    sortName = spellData.n:lower(),
                })
            end
        end
    end

    -- also include parent spells that have children in this class
    if PvPTipData.SpellParents then
        for parentID, children in pairs(PvPTipData.SpellParents) do
            if not seen[parentID] then
                local allParts = {}
                local mainMult = 1
                local maxDev = 0
                local parentMatch = false

                for _, childID in ipairs(children) do
                    local childData = PvPTipData.Spells[childID]
                    if childData and childData.c == classFamily then
                        parentMatch = true
                        for _, eff in ipairs(childData.e) do
                            if math.abs(eff.p - 1.0) > 0.001 then
                                local text = eff.t .. " " .. U.FormatPct(eff.p)
                                local dup = false
                                for _, ex in ipairs(allParts) do
                                    if ex == text then dup = true; break end
                                end
                                if not dup then table.insert(allParts, text) end
                                local dev = math.abs(eff.p - 1.0)
                                if dev > maxDev then maxDev = dev; mainMult = eff.p end
                            end
                        end
                    end
                end

                if parentMatch and #allParts > 0 then
                    local pname = U.GetSpellName(parentID, "Spell #" .. parentID)
                    table.insert(spellList, {
                        id = parentID,
                        name = pname,
                        summary = table.concat(allParts, " | "),
                        mult = mainMult,
                        sortName = pname:lower(),
                    })
                end
            end
        end
    end

    table.sort(spellList, function(a, b) return a.sortName < b.sortName end)
    return spellList
end

-------------------------------------------------------------------------------
-- refresh results list
-------------------------------------------------------------------------------

function RefreshResults()
    if not scrollContainer then return end

    -- clear old rows
    for _, row in ipairs(spellRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(spellRows)

    if not selectedClassID then
        if summaryText then summaryText:SetText("Select a class to begin") end
        scrollContainer:SetContentHeight(0)
        return
    end

    local cfg = PvPTip.GetConfig()
    local spellList = CollectSpells()

    -- update summary
    if summaryText then
        local buffs, nerfs = 0, 0
        for _, s in ipairs(spellList) do
            if s.mult > 1.001 then buffs = buffs + 1
            elseif s.mult < 0.999 then nerfs = nerfs + 1 end
        end
        summaryText:SetText(
            string.format("%d spells  |  %d buffs  |  %d nerfs",
                #spellList, buffs, nerfs)
        )
    end

    -- create spell rows
    local scrollChild = scrollContainer.scrollChild
    local yOff = 0

    for _, spell in ipairs(spellList) do
        local r, g, b = U.GetCoeffColor(spell.mult, cfg)
        local row = UI.CreateSpellRow(scrollChild, spell.id, spell.name, spell.summary, r, g, b)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOff)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOff)
        row:Show()
        table.insert(spellRows, row)
        yOff = yOff + UI.Sizes.rowH

        -- affected-by sub-row
        local affectedStr = U.FormatAffectedBy(spell.id)
        if affectedStr then
            local abRow = UI.CreateAffectedByRow(scrollChild, "Affected by: " .. affectedStr)
            abRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOff)
            abRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOff)
            abRow:Show()
            table.insert(spellRows, abRow)
            yOff = yOff + UI.Sizes.rowH - 4
        end
    end

    scrollContainer:SetContentHeight(yOff + 20)
end

PvPTip.RefreshLookup = RefreshResults
