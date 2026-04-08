-- guioverview.lua
PvPTip = PvPTip or {}
local UI = PvPTip.UI
local U = PvPTip.Utils

-------------------------------------------------------------------------------
-- state
-------------------------------------------------------------------------------

local scrollContainer
local spellRows = {}

-------------------------------------------------------------------------------
-- player spell enumeration (spellbook + talents)
-------------------------------------------------------------------------------

local function EnumeratePlayerKnownSpells()
    local known = {}

    -- Spellbook
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local numLines = C_SpellBook.GetNumSpellBookSkillLines()
        for lineIdx = 1, numLines do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIdx)
            if lineInfo then
                local start = lineInfo.itemIndexOffset + 1
                for slot = start, start + lineInfo.numSpellBookItems - 1 do
                    local itemInfo = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                    if itemInfo then
                        local sid = itemInfo.spellID or itemInfo.actionID
                        if sid and sid > 0 then known[sid] = true end
                    end
                end
            end
        end
    end

    -- talent tree spells
    if C_ClassTalents and C_Traits then
        local configID = C_ClassTalents.GetActiveConfigID()
        local specID = PvPTip.currentSpecID
        if configID and specID and specID > 0 then
            local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
            if treeID then
                local nodeIDs = C_Traits.GetTreeNodes(treeID)
                if nodeIDs then
                    for _, nodeID in ipairs(nodeIDs) do
                        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                        if nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID then
                            local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
                            if entryInfo and entryInfo.definitionID then
                                local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                                if defInfo and defInfo.spellID then
                                    known[defInfo.spellID] = true
                                end
                                if defInfo and defInfo.overriddenSpellID and defInfo.overriddenSpellID > 0 then
                                    known[defInfo.overriddenSpellID] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- PvP talents (is this actually needed? just incase they change these)
    if C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs then
        local pvpTalentIDs = C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
        if pvpTalentIDs then
            for _, talentID in ipairs(pvpTalentIDs) do
                if C_SpecializationInfo.GetPvpTalentInfo then
                    local info = C_SpecializationInfo.GetPvpTalentInfo(talentID)
                    if info and info.spellID then
                        known[info.spellID] = true
                    end
                end
            end
        end
    end

    return known
end

-------------------------------------------------------------------------------
-- build panel
-------------------------------------------------------------------------------

function PvPTip.BuildOverviewPanel(panel)
    local padding = UI.Sizes.padding

    -- header area (fixed, above scroll)
    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(60)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, -padding)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -padding, -padding)

    -- spec name + class color
    local specText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    specText:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    specText:SetText("Loading...")
    specText:SetTextColor(1, 1, 1)
    panel.specText = specText

    -- PvP status indicator (to do)
    local pvpIndicator = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pvpIndicator:SetPoint("LEFT", specText, "RIGHT", 12, 0)
    panel.pvpIndicator = pvpIndicator

    -- build info
    local buildInfo = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buildInfo:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    local build = PvPTipData and PvPTipData.Build or "unknown"
    buildInfo:SetText("Build: " .. build)
    buildInfo:SetTextColor(0.5, 0.5, 0.5)
    panel.buildInfo = buildInfo

    -- summary stats
    local summaryText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summaryText:SetPoint("TOPLEFT", specText, "BOTTOMLEFT", 0, -4)
    summaryText:SetTextColor(0.6, 0.6, 0.6)
    panel.summaryText = summaryText

    -- divider below header
    local divider = UI.CreateDivider(panel, "Active Tooltips")
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -padding, -4)
    divider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", padding, -4)

    -- info note
    local infoNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoNote:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", padding + 4, -2)
    infoNote:SetPoint("RIGHT", panel, "RIGHT", -padding - 4, 0)
    infoNote:SetJustifyH("LEFT")
    infoNote:SetWordWrap(true)
    infoNote:SetText("PvP coefficients are deeply hidden in spell data and some may be missing here. "
        .. "Use the |cFFFFD100Lookup|r tab for a complete list of all PvP modifiers for your class.")
    infoNote:SetTextColor(0.45, 0.45, 0.45)

    -- scrollable content area
    scrollContainer = UI.CreateScrollFrame(panel)
    scrollContainer:SetPoint("TOPLEFT", infoNote, "BOTTOMLEFT", -4, -4)
    scrollContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding, padding)

    panel.scrollContainer = scrollContainer
end

-------------------------------------------------------------------------------
-- refresh content
-------------------------------------------------------------------------------

function PvPTip.RefreshOverview()
    if not scrollContainer then return end
    local panel = scrollContainer:GetParent()
    local cfg = PvPTip.GetConfig()

    -- clear old rows
    for _, row in ipairs(spellRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(spellRows)

    -- get current spec info
    local specID = PvPTip.currentSpecID or 0
    local classID = PvPTip.currentClassID or 0
    local specName = "Unknown"
    local className = "Unknown"

    if PvPTipData and PvPTipData.Classes then
        local classData = PvPTipData.Classes[classID]
        if classData then
            className = classData.n
            if classData.s[specID] then
                specName = classData.s[specID]
            end
        end
    end

    -- update header
    if panel.specText then
        panel.specText:SetText(specName .. " " .. className)
        local classColor = U.CLASS_COLORS[classID]
        if classColor then
            panel.specText:SetTextColor(classColor[1], classColor[2], classColor[3])
        end
    end

    -- TO DO
    if panel.pvpIndicator then
        if PvPTip.isPvPActive then
            panel.pvpIndicator:SetText("|cFF00FF00Detected Tooltips|r")
        else
            panel.pvpIndicator:SetText("|cFF666666Detected Tooltips|r")
        end
    end

    -- build mismatch warning
    if panel.buildInfo then
        local dataBuild = PvPTipData and PvPTipData.Build or "unknown"
        local clientBuild = PvPTip.clientBuild or "unknown"
        if dataBuild ~= "unknown" and clientBuild ~= "unknown" and dataBuild ~= clientBuild then
            panel.buildInfo:SetText("|cFFFF6600Build: " .. dataBuild .. " (client: " .. clientBuild .. ")|r")
        else
            panel.buildInfo:SetText("Build: " .. dataBuild)
        end
    end

    -- enumerate players known spells via runtime API
    local playerKnown = EnumeratePlayerKnownSpells()

    -- get class family
    local classFamily = 0
    for family, cid in pairs(U.FAMILY_TO_CLASS) do
        if cid == classID then
            classFamily = family
            break
        end
    end

    -- gather spells: only those the player actually knows or has active
    local spellList = {}
    if PvPTipData and PvPTipData.Spells then
        for spellID, spellData in pairs(PvPTipData.Spells) do
            -- must be player's class family (or c=0 if player knows it)
            local relevant = false
            if spellData.c == classFamily and classFamily > 0 then
                -- class match: include if player knows it, or if it's in their spec spells
                if playerKnown[spellID] then
                    relevant = true
                else
                    -- check spec spells
                    local specSpells = PvPTipData.SpecSpells and PvPTipData.SpecSpells[specID]
                    if specSpells then
                        for _, sid in ipairs(specSpells) do
                            if sid == spellID then relevant = true; break end
                        end
                    end
                    -- also check via override resolution
                    if not relevant and C_Spell and C_Spell.GetOverrideSpell then
                        for knownID in pairs(playerKnown) do
                            local override = C_Spell.GetOverrideSpell(knownID)
                            if override == spellID then relevant = true; break end
                        end
                    end
                end
            elseif spellData.c == 0 and playerKnown[spellID] then
                relevant = true
            end

            if relevant then
                -- build effect summary
                local parts = {}
                local maxDeviation = 0
                local mainMult = 1

                for _, eff in ipairs(spellData.e) do
                    local effectiveMult = U.ComputeEffectivePvpMult(spellID, eff.p)
                    if math.abs(effectiveMult - 1.0) > 0.001 then
                        table.insert(parts, eff.t .. " " .. U.FormatPct(effectiveMult))
                        local dev = math.abs(effectiveMult - 1.0)
                        if dev > maxDeviation then
                            maxDeviation = dev
                            mainMult = effectiveMult
                        end
                    end
                end

                if #parts > 0 then
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

        -- also include parent spells the player knows
        if PvPTipData.SpellParents then
            local seen = {}
            for _, s in ipairs(spellList) do seen[s.id] = true end

            for parentID, children in pairs(PvPTipData.SpellParents) do
                if not seen[parentID] and playerKnown[parentID] then
                    local allParts = {}
                    local mainMult = 1
                    local maxDev = 0

                    for _, childID in ipairs(children) do
                        local childData = PvPTipData.Spells[childID]
                        if childData then
                            for _, eff in ipairs(childData.e) do
                                local effectiveMult = U.ComputeEffectivePvpMult(childID, eff.p)
                                if math.abs(effectiveMult - 1.0) > 0.001 then
                                    local text = eff.t .. " " .. U.FormatPct(effectiveMult)
                                    local dup = false
                                    for _, ex in ipairs(allParts) do
                                        if ex == text then dup = true; break end
                                    end
                                    if not dup then table.insert(allParts, text) end
                                    local dev = math.abs(effectiveMult - 1.0)
                                    if dev > maxDev then maxDev = dev; mainMult = effectiveMult end
                                end
                            end
                        end
                    end

                    if #allParts > 0 then
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
    end

    -- sort alphabetically
    table.sort(spellList, function(a, b) return a.sortName < b.sortName end)

    -- update summary
    if panel.summaryText then
        local buffs = 0
        local nerfs = 0
        for _, s in ipairs(spellList) do
            if s.mult > 1.001 then buffs = buffs + 1
            elseif s.mult < 0.999 then nerfs = nerfs + 1 end
        end
        panel.summaryText:SetText(
            string.format("%d spells modified  |  %d buffs  |  %d nerfs",
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
    end

    scrollContainer:SetContentHeight(yOff + 20)
end
