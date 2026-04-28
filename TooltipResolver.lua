PvPTip = PvPTip or {}
PvPTip.TooltipResolver = PvPTip.TooltipResolver or {}

local R = PvPTip.TooltipResolver
local U = PvPTip.Utils

local spellCacheByState = {}
local spellBookCacheByState = {}
local talentCacheByState = {}
local knownSpellIndexByState = {}

local function WipeTable(target)
    if type(target) ~= "table" then
        return
    end
    for key in pairs(target) do
        target[key] = nil
    end
end

local function ToNumber(value)
    local numericValue = tonumber(value)
    if not numericValue or numericValue <= 0 then
        return nil
    end
    return numericValue
end

local function SafeCallNumber(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result = pcall(func, ...)
    if not ok then
        return nil
    end
    return ToNumber(result)
end

local function AddSpellID(result, spellID)
    local numericSpellID = ToNumber(spellID)
    if numericSpellID then
        result[numericSpellID] = true
    end
end

local function AddOrderedSpellID(list, seen, spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID or seen[numericSpellID] then
        return
    end

    seen[numericSpellID] = true
    table.insert(list, numericSpellID)
end

local function CopySpellIDs(spellSet)
    local spellIDs = {}
    for spellID in pairs(spellSet or {}) do
        table.insert(spellIDs, spellID)
    end
    table.sort(spellIDs)
    return spellIDs
end

local function GetActiveConfigID()
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        return ToNumber(C_ClassTalents.GetActiveConfigID())
    end
    return nil
end

local function GetStateKey()
    return table.concat({
        tostring(U.GetCurrentSpecID() or 0),
        tostring(GetActiveConfigID() or 0),
    }, ":")
end

local function GetStateCache(root)
    local stateKey = GetStateKey()
    local cache = root[stateKey]
    if not cache then
        cache = {}
        root[stateKey] = cache
    end
    return cache
end

local function SetTooltipContext(tooltip, context)
    if not tooltip or type(context) ~= "table" then
        return
    end

    tooltip.__PvPTipContext = context
    if tooltip.HookScript and not tooltip.__PvPTipContextHooked then
        tooltip.__PvPTipContextHooked = true
        tooltip:HookScript("OnHide", function(frame)
            frame.__PvPTipContext = nil
        end)
    end
end

local function GetTooltipDataType(data)
    if type(data) ~= "table" then
        return nil
    end
    return data.dataType or data.type or data.tooltipDataType
end

local function ExpandLiveSpellIDs(result, spellID, seen)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID or seen[numericSpellID] then
        return
    end

    seen[numericSpellID] = true
    AddSpellID(result, numericSpellID)

    local specID = U.GetCurrentSpecID()
    if C_Spell and C_Spell.GetBaseSpell then
        local baseSpellID = ToNumber(C_Spell.GetBaseSpell(numericSpellID, specID))
        if baseSpellID and baseSpellID ~= numericSpellID then
            ExpandLiveSpellIDs(result, baseSpellID, seen)
        end
    end

    if C_Spell and C_Spell.GetOverrideSpell then
        local overrideSpellID = ToNumber(C_Spell.GetOverrideSpell(numericSpellID, specID, true, 0))
        if overrideSpellID and overrideSpellID ~= numericSpellID then
            ExpandLiveSpellIDs(result, overrideSpellID, seen)
        end
    end

    if C_SpellBook then
        local spellBookBaseSpellID = SafeCallNumber(C_SpellBook.FindBaseSpellByID, numericSpellID)
        if spellBookBaseSpellID and spellBookBaseSpellID ~= numericSpellID then
            ExpandLiveSpellIDs(result, spellBookBaseSpellID, seen)
        end

        local spellBookOverrideSpellID = SafeCallNumber(C_SpellBook.FindSpellOverrideByID, numericSpellID)
        if spellBookOverrideSpellID and spellBookOverrideSpellID ~= numericSpellID then
            ExpandLiveSpellIDs(result, spellBookOverrideSpellID, seen)
        end
    end

    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell and C_SpellBook.GetSpellBookItemInfo
        and Enum and Enum.SpellBookSpellBank then
        local isKnownOrInSpellBook = true
        if C_SpellBook.IsSpellKnownOrInSpellBook then
            isKnownOrInSpellBook = C_SpellBook.IsSpellKnownOrInSpellBook(
                numericSpellID,
                Enum.SpellBookSpellBank.Player,
                true
            )
        end

        if isKnownOrInSpellBook then
            local slotIndex, spellBank = C_SpellBook.FindSpellBookSlotForSpell(
                numericSpellID,
                true,
                true,
                false,
                false
            )
            if slotIndex then
                spellBank = spellBank or Enum.SpellBookSpellBank.Player

                if C_SpellBook.GetSpellBookItemType then
                    local _, actionID, foundSpellID = C_SpellBook.GetSpellBookItemType(slotIndex, spellBank)
                    if foundSpellID and foundSpellID ~= numericSpellID then
                        ExpandLiveSpellIDs(result, foundSpellID, seen)
                    end
                    if actionID and actionID ~= numericSpellID then
                        ExpandLiveSpellIDs(result, actionID, seen)
                    end
                end

                local info = C_SpellBook.GetSpellBookItemInfo(slotIndex, spellBank)
                if info then
                    if info.spellID and info.spellID ~= numericSpellID then
                        ExpandLiveSpellIDs(result, info.spellID, seen)
                    end
                    if info.actionID and info.actionID ~= numericSpellID then
                        ExpandLiveSpellIDs(result, info.actionID, seen)
                    end
                end

                if C_SpellBook.GetSpellBookItemLink then
                    local link = C_SpellBook.GetSpellBookItemLink(slotIndex, spellBank)
                    local linkedSpellID = link and tonumber(link:match("spell:(%d+)")) or nil
                    if linkedSpellID and linkedSpellID ~= numericSpellID then
                        ExpandLiveSpellIDs(result, linkedSpellID, seen)
                    end
                end
            end
        end
    end

    local relation = U.GetSpellRelation(numericSpellID)
    if relation then
        local canonicalSpellID = ToNumber(relation.canonicalSpellID or relation.c)
        if canonicalSpellID and canonicalSpellID ~= numericSpellID then
            ExpandLiveSpellIDs(result, canonicalSpellID, seen)
        end

        for _, bucket in ipairs({
            relation.resolvedSpellIDs or relation.r,
            relation.sourceSpellIDs or relation.s,
            relation.replacementSpellIDs or relation.rp,
            relation.displaySpellIDs or relation.d,
            relation.triggerSpellIDs or relation.t,
        }) do
            for _, relatedSpellID in ipairs(bucket or {}) do
                if relatedSpellID ~= numericSpellID then
                    ExpandLiveSpellIDs(result, relatedSpellID, seen)
                end
            end
        end
    end
end

local function GetExpandedSpellIDs(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return {}
    end

    local cache = GetStateCache(spellCacheByState)
    local cacheKey = tostring(numericSpellID)
    if cache[cacheKey] then
        return cache[cacheKey]
    end

    local spellSet = {}
    ExpandLiveSpellIDs(spellSet, numericSpellID, {})
    local spellIDs = CopySpellIDs(spellSet)
    cache[cacheKey] = spellIDs
    return spellIDs
end

local function AddExpandedSpellIDs(result, spellID)
    for _, candidateSpellID in ipairs(GetExpandedSpellIDs(spellID)) do
        AddSpellID(result, candidateSpellID)
    end
end

local function AddSpellBookBridgeIDs(spellSet, spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return
    end

    if C_SpellBook then
        AddExpandedSpellIDs(spellSet, SafeCallNumber(C_SpellBook.FindBaseSpellByID, numericSpellID))
        AddExpandedSpellIDs(spellSet, SafeCallNumber(C_SpellBook.FindSpellOverrideByID, numericSpellID))
    end
end

local function BuildSpellBookSpellIDs(slotIndex, spellBank)
    local spellSet = {}
    local numericSlotIndex = ToNumber(slotIndex)
    local numericSpellBank = tonumber(spellBank)

    if not numericSlotIndex or numericSpellBank == nil then
        return {}
    end

    if C_SpellBook and C_SpellBook.GetSpellBookItemType then
        local _, actionID, spellID = C_SpellBook.GetSpellBookItemType(numericSlotIndex, numericSpellBank)
        AddExpandedSpellIDs(spellSet, spellID)
        AddExpandedSpellIDs(spellSet, actionID)
        AddSpellBookBridgeIDs(spellSet, spellID)
        AddSpellBookBridgeIDs(spellSet, actionID)
    end

    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local info = C_SpellBook.GetSpellBookItemInfo(numericSlotIndex, numericSpellBank)
        if info then
            AddExpandedSpellIDs(spellSet, info.spellID)
            AddExpandedSpellIDs(spellSet, info.actionID)
            AddSpellBookBridgeIDs(spellSet, info.spellID)
            AddSpellBookBridgeIDs(spellSet, info.actionID)
        end
    end

    if C_SpellBook and C_SpellBook.GetSpellBookItemLink then
        local link = C_SpellBook.GetSpellBookItemLink(numericSlotIndex, numericSpellBank)
        local linkedSpellID = link and tonumber(link:match("spell:(%d+)")) or nil
        AddExpandedSpellIDs(spellSet, linkedSpellID)
    end

    return CopySpellIDs(spellSet)
end

local function AddSpellBookSpellIDs(result, context)
    local numericSlotIndex = ToNumber(context.spellBookItemSlotIndex)
    local numericSpellBank = tonumber(context.spellBookItemSpellBank)
    if not numericSlotIndex or numericSpellBank == nil then
        return
    end

    local cache = GetStateCache(spellBookCacheByState)
    local cacheKey = table.concat({
        tostring(numericSlotIndex),
        tostring(numericSpellBank),
    }, ":")

    local spellIDs = cache[cacheKey]
    if not spellIDs then
        spellIDs = BuildSpellBookSpellIDs(numericSlotIndex, numericSpellBank)
        cache[cacheKey] = spellIDs
    end

    for _, spellID in ipairs(spellIDs) do
        AddSpellID(result, spellID)
    end
end

local function AddTraitDefinitionSpellIDs(result, definitionID)
    for _, spellID in ipairs(U.GetTraitDefinitionSpellIDs(definitionID) or {}) do
        AddExpandedSpellIDs(result, spellID)
    end
end

local function BuildTalentSpellIDs(context)
    local spellSet = {}
    local pvpTalents = U.GetDataTable("PvpTalents") or {}
    local configID = ToNumber(context.configID) or GetActiveConfigID()

    AddExpandedSpellIDs(spellSet, context.spellID)

    if context.definitionID then
        AddTraitDefinitionSpellIDs(spellSet, context.definitionID)
    end

    if configID and context.entryID and C_Traits and C_Traits.GetEntryInfo then
        local entryInfo = C_Traits.GetEntryInfo(configID, context.entryID)
        if entryInfo and entryInfo.definitionID then
            AddTraitDefinitionSpellIDs(spellSet, entryInfo.definitionID)
        end
    end

    if configID and context.nodeID and C_Traits and C_Traits.GetNodeInfo then
        local nodeInfo = C_Traits.GetNodeInfo(configID, context.nodeID)
        local activeEntry = nodeInfo and nodeInfo.activeEntry
        local activeEntryID = type(activeEntry) == "table" and activeEntry.entryID or activeEntry
        if activeEntryID and C_Traits.GetEntryInfo then
            local entryInfo = C_Traits.GetEntryInfo(configID, activeEntryID)
            if entryInfo and entryInfo.definitionID then
                AddTraitDefinitionSpellIDs(spellSet, entryInfo.definitionID)
            end
        end
    end

    if context.talentID and pvpTalents[context.talentID] then
        local talentData = pvpTalents[context.talentID]
        AddExpandedSpellIDs(spellSet, talentData.actionBarSpellID)
        AddExpandedSpellIDs(spellSet, talentData.overridesSpellID)
        for _, spellID in ipairs(talentData.resolvedSpellIDs or {}) do
            AddExpandedSpellIDs(spellSet, spellID)
        end
    end

    local liveTalentInfo = U.GetLivePvpTalentInfo(context.talentID)
    if liveTalentInfo then
        AddExpandedSpellIDs(spellSet, liveTalentInfo.spellID)
        AddExpandedSpellIDs(spellSet, liveTalentInfo.overridesSpellID)
    end

    return CopySpellIDs(spellSet)
end

local function AddTalentSpellIDs(result, context)
    local cache = GetStateCache(talentCacheByState)
    local cacheKey = table.concat({
        tostring(context.talentID or 0),
        tostring(context.definitionID or 0),
        tostring(context.nodeID or 0),
        tostring(context.entryID or 0),
        tostring(context.rank or 0),
        tostring(context.spellID or 0),
        tostring(context.configID or 0),
    }, ":")
    local spellIDs = cache[cacheKey]
    if not spellIDs then
        spellIDs = BuildTalentSpellIDs(context)
        cache[cacheKey] = spellIDs
    end

    for _, spellID in ipairs(spellIDs) do
        AddSpellID(result, spellID)
    end
end

local function CollectActiveTraitLinks(configID)
    local links = {}
    if not configID or not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then
        return links
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or type(configInfo.treeIDs) ~= "table" then
        return links
    end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodeIDs = C_Traits.GetTreeNodes(treeID) or {}
        for _, nodeID in ipairs(nodeIDs) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            local entryIDs = {}

            for _, entryID in ipairs(nodeInfo and nodeInfo.entryIDsWithCommittedRanks or {}) do
                local numericEntryID = ToNumber(entryID)
                if numericEntryID then
                    table.insert(entryIDs, numericEntryID)
                end
            end

            if #entryIDs == 0 then
                local activeEntry = nodeInfo and nodeInfo.activeEntry
                local activeEntryID = type(activeEntry) == "table" and activeEntry.entryID or activeEntry
                activeEntryID = ToNumber(activeEntryID)
                if activeEntryID then
                    table.insert(entryIDs, activeEntryID)
                end
            end

            for _, entryID in ipairs(entryIDs) do
                local entryInfo = C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, entryID) or nil
                local definitionID = ToNumber(entryInfo and entryInfo.definitionID)
                local definitionInfo = definitionID and C_Traits.GetDefinitionInfo and C_Traits.GetDefinitionInfo(definitionID) or nil
                local resolvedSpellSet = {}
                for _, spellID in ipairs(U.GetTraitDefinitionSpellIDs(definitionID) or {}) do
                    AddSpellID(resolvedSpellSet, spellID)
                end

                table.insert(links, {
                    treeID = ToNumber(treeID),
                    nodeID = ToNumber(nodeID),
                    entryID = entryID,
                    definitionID = definitionID,
                    spellID = ToNumber(definitionInfo and definitionInfo.spellID),
                    overriddenSpellID = ToNumber(definitionInfo and definitionInfo.overriddenSpellID),
                    resolvedSpellIDs = CopySpellIDs(resolvedSpellSet),
                })
            end
        end
    end

    return links
end

local function CollectSelectedPvpTalentLinks()
    local links = {}
    if not (C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs) then
        return links
    end

    local retainedTalents = U.GetDataTable("PvpTalents") or {}
    for _, talentID in ipairs(C_SpecializationInfo.GetAllSelectedPvpTalentIDs() or {}) do
        local numericTalentID = ToNumber(talentID)
        local retained = retainedTalents[numericTalentID or 0]
        local liveInfo = U.GetLivePvpTalentInfo(numericTalentID)
        local resolvedSpellSet = {}

        if retained then
            AddSpellID(resolvedSpellSet, retained.actionBarSpellID)
            AddSpellID(resolvedSpellSet, retained.overridesSpellID)
            for _, spellID in ipairs(retained.resolvedSpellIDs or {}) do
                AddSpellID(resolvedSpellSet, spellID)
            end
        end
        if liveInfo then
            AddSpellID(resolvedSpellSet, liveInfo.spellID)
            AddSpellID(resolvedSpellSet, liveInfo.overridesSpellID)
        end

        table.insert(links, {
            talentID = numericTalentID,
            spellID = ToNumber((liveInfo and liveInfo.spellID) or (retained and retained.actionBarSpellID)),
            overriddenSpellID = ToNumber((liveInfo and liveInfo.overridesSpellID) or (retained and retained.overridesSpellID)),
            resolvedSpellIDs = CopySpellIDs(resolvedSpellSet),
        })
    end

    return links
end

local function MakeSlotKey(slotIndex, spellBank)
    return tostring(ToNumber(slotIndex) or 0) .. ":" .. tostring(tonumber(spellBank) or 0)
end

local function MergeFamilySetWithKnown(familySet, familyBySpellID)
    local merged = true
    while merged do
        merged = false
        for member in pairs(familySet) do
            local existing = familyBySpellID[member]
            if existing then
                for _, existingSpellID in ipairs(existing) do
                    if not familySet[existingSpellID] then
                        familySet[existingSpellID] = true
                        merged = true
                    end
                end
            end
        end
    end
end

local function BuildKnownSpellIndex()
    local index = {
        stateKey = GetStateKey(),
        specID = U.GetCurrentSpecID(),
        configID = GetActiveConfigID(),
        spellbookSlots = {},
        traitLinks = {},
        pvpTalentLinks = {},
        knownSpellIDs = {},
        familyBySpellID = {},
        slotCandidates = {},
    }

    local seedSet = {}
    local spellBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or nil

    if spellBank and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo then
        local lineCount = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for lineIndex = 1, lineCount do
            local lineInfo = U.GetLiveSpellBookSkillLineInfo(lineIndex)
            local startIndex = lineInfo and (tonumber(lineInfo.itemIndexOffset) or 0) + 1 or nil
            local numItems = lineInfo and (tonumber(lineInfo.numSpellBookItems) or 0) or 0
            if startIndex then
                for slotIndex = startIndex, startIndex + numItems - 1 do
                    local itemType
                    local actionID
                    local spellID
                    local itemInfo

                    if C_SpellBook.GetSpellBookItemType then
                        itemType, actionID, spellID = C_SpellBook.GetSpellBookItemType(slotIndex, spellBank)
                    end
                    if C_SpellBook.GetSpellBookItemInfo then
                        itemInfo = C_SpellBook.GetSpellBookItemInfo(slotIndex, spellBank)
                    end

                    actionID = ToNumber(actionID) or ToNumber(itemInfo and itemInfo.actionID)
                    spellID = ToNumber(spellID) or ToNumber(itemInfo and itemInfo.spellID)

                    local entry = {
                        lineIndex = lineIndex,
                        skillLineID = ToNumber(lineInfo and lineInfo.skillLineID),
                        slot = slotIndex,
                        bank = spellBank,
                        itemType = itemType,
                        actionID = actionID,
                        spellID = spellID,
                    }

                    AddSpellID(seedSet, actionID)
                    AddSpellID(seedSet, spellID)
                    AddSpellID(seedSet, SafeCallNumber(C_SpellBook.FindBaseSpellByID, actionID))
                    AddSpellID(seedSet, SafeCallNumber(C_SpellBook.FindSpellOverrideByID, actionID))
                    AddSpellID(seedSet, SafeCallNumber(C_SpellBook.FindBaseSpellByID, spellID))
                    AddSpellID(seedSet, SafeCallNumber(C_SpellBook.FindSpellOverrideByID, spellID))

                    table.insert(index.spellbookSlots, entry)
                end
            end
        end
    end

    index.traitLinks = CollectActiveTraitLinks(index.configID)
    for _, link in ipairs(index.traitLinks) do
        AddSpellID(seedSet, link.spellID)
        AddSpellID(seedSet, link.overriddenSpellID)
        for _, spellID in ipairs(link.resolvedSpellIDs or {}) do
            AddSpellID(seedSet, spellID)
        end
    end

    index.pvpTalentLinks = CollectSelectedPvpTalentLinks()
    for _, link in ipairs(index.pvpTalentLinks) do
        AddSpellID(seedSet, link.spellID)
        AddSpellID(seedSet, link.overriddenSpellID)
        for _, spellID in ipairs(link.resolvedSpellIDs or {}) do
            AddSpellID(seedSet, spellID)
        end
    end

    for seedSpellID in pairs(seedSet) do
        local familySet = {}
        local expandedSpellIDs = GetExpandedSpellIDs(seedSpellID)
        if #expandedSpellIDs == 0 then
            familySet[seedSpellID] = true
        else
            for _, spellID in ipairs(expandedSpellIDs) do
                familySet[spellID] = true
            end
        end

        MergeFamilySetWithKnown(familySet, index.familyBySpellID)

        local familyList = CopySpellIDs(familySet)
        for _, spellID in ipairs(familyList) do
            index.familyBySpellID[spellID] = familyList
        end
    end

    for _, slot in ipairs(index.spellbookSlots) do
        local candidates = {}
        local seenCandidates = {}

        local function AddCandidateFamily(seedSpellID)
            local numericSeedSpellID = ToNumber(seedSpellID)
            if not numericSeedSpellID then
                return
            end

            AddOrderedSpellID(candidates, seenCandidates, numericSeedSpellID)

            local family = index.familyBySpellID[numericSeedSpellID]
            if family and #family > 0 then
                for _, spellID in ipairs(family) do
                    AddOrderedSpellID(candidates, seenCandidates, spellID)
                end
                return
            end

            for _, spellID in ipairs(GetExpandedSpellIDs(numericSeedSpellID)) do
                AddOrderedSpellID(candidates, seenCandidates, spellID)
            end
        end

        local seeds = {
            slot.spellID,
            slot.actionID,
            SafeCallNumber(C_SpellBook and C_SpellBook.FindBaseSpellByID or nil, slot.spellID),
            SafeCallNumber(C_SpellBook and C_SpellBook.FindSpellOverrideByID or nil, slot.spellID),
            SafeCallNumber(C_SpellBook and C_SpellBook.FindBaseSpellByID or nil, slot.actionID),
            SafeCallNumber(C_SpellBook and C_SpellBook.FindSpellOverrideByID or nil, slot.actionID),
        }

        for _, seedSpellID in ipairs(seeds) do
            AddCandidateFamily(seedSpellID)
        end

        if #candidates == 0 then
            for _, spellID in ipairs(BuildSpellBookSpellIDs(slot.slot, slot.bank)) do
                AddOrderedSpellID(candidates, seenCandidates, spellID)
            end
        end

        slot.candidateSpellIDs = candidates
        index.slotCandidates[MakeSlotKey(slot.slot, slot.bank)] = candidates
    end

    local knownSet = {}
    for seedSpellID in pairs(seedSet) do
        knownSet[seedSpellID] = true
    end
    for spellID in pairs(index.familyBySpellID) do
        knownSet[spellID] = true
    end
    index.knownSpellIDs = CopySpellIDs(knownSet)

    return index
end

local function GetKnownSpellIndex()
    local stateKey = GetStateKey()
    local cached = knownSpellIndexByState[stateKey]
    if cached then
        return cached
    end

    local index = BuildKnownSpellIndex()
    knownSpellIndexByState[stateKey] = index
    return index
end

local function AddFamilyCandidates(result, seen, knownIndex, spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return
    end

    AddOrderedSpellID(result, seen, numericSpellID)

    local family = knownIndex and knownIndex.familyBySpellID[numericSpellID] or nil
    if family and #family > 0 then
        for _, familySpellID in ipairs(family) do
            AddOrderedSpellID(result, seen, familySpellID)
        end
        return
    end

    local expanded = GetExpandedSpellIDs(numericSpellID)
    if #expanded > 0 then
        for _, candidateSpellID in ipairs(expanded) do
            AddOrderedSpellID(result, seen, candidateSpellID)
        end
        return
    end

end

local function CollectTooltipHintSpellIDs(tooltip, data, context)
    local hints = {}
    local seen = {}
    local tooltipEnum = Enum and Enum.TooltipDataType or nil
    local dataType = GetTooltipDataType(data)

    local function AddHint(value)
        AddOrderedSpellID(hints, seen, value)
    end

    if tooltipEnum and (dataType == tooltipEnum.Spell or dataType == tooltipEnum.UnitAura) then
        AddHint(data and (data.id or data.spellID))
    end
    AddHint(data and data.spellID)
    AddHint(context and context.spellID)

    if context and context.sourceLink then
        AddHint(context.sourceLink:match("spell:(%d+)"))
    end

    if tooltip and tooltip.GetSpell then
        local _, spellID = tooltip:GetSpell()
        AddHint(spellID)
    end

    return hints
end

local function CollectTalentContextSpellIDs(context)
    local spellSet = {}
    if context and (context.contextType == "talent" or context.definitionID or context.talentID) then
        AddTalentSpellIDs(spellSet, context)
    end
    return CopySpellIDs(spellSet)
end

local function BuildCandidateSpellIDs(tooltip, data, context, knownIndex)
    local candidates = {}
    local seen = {}

    if context and context.spellBookItemSlotIndex then
        local slotKey = MakeSlotKey(context.spellBookItemSlotIndex, context.spellBookItemSpellBank)
        for _, spellID in ipairs((knownIndex and knownIndex.slotCandidates[slotKey]) or {}) do
            AddOrderedSpellID(candidates, seen, spellID)
        end
        if #candidates == 0 then
            for _, spellID in ipairs(BuildSpellBookSpellIDs(context.spellBookItemSlotIndex, context.spellBookItemSpellBank)) do
                AddOrderedSpellID(candidates, seen, spellID)
            end
        end
    end

    for _, spellID in ipairs(CollectTalentContextSpellIDs(context)) do
        AddFamilyCandidates(candidates, seen, knownIndex, spellID)
    end

    for _, spellID in ipairs(CollectTooltipHintSpellIDs(tooltip, data, context)) do
        AddFamilyCandidates(candidates, seen, knownIndex, spellID)
    end

    if #candidates == 0 then
        AddFamilyCandidates(candidates, seen, knownIndex, context and context.spellID)
    end

    return candidates
end

local function SpellHasRenderablePvpData(spellID)
    local resolvedSpellIDs = U.GetResolvedSpellIDs(spellID) or {spellID}

    for _, resolvedSpellID in ipairs(resolvedSpellIDs) do
        if #U.GetPvpEffects(resolvedSpellID) > 0 or U.GetSpellPvpDurationInfo(resolvedSpellID) then
            return true
        end
    end

    return false
end

local function SelectPrimarySpellID(candidateSpellIDs)
    for _, spellID in ipairs(candidateSpellIDs or {}) do
        if SpellHasRenderablePvpData(spellID) then
            return spellID
        end
    end
    return candidateSpellIDs and candidateSpellIDs[1] or nil
end

local function IsSameSpellFamily(leftSpellID, rightSpellID)
    local leftID = ToNumber(leftSpellID)
    local rightID = ToNumber(rightSpellID)
    if not leftID or not rightID then
        return false
    end
    if leftID == rightID then
        return true
    end

    for _, candidateSpellID in ipairs(GetExpandedSpellIDs(leftID)) do
        if candidateSpellID == rightID then
            return true
        end
    end
    return false
end

function R.InvalidateCaches()
    WipeTable(spellCacheByState)
    WipeTable(spellBookCacheByState)
    WipeTable(talentCacheByState)
    WipeTable(knownSpellIndexByState)
end

function R.ResolveTooltip(tooltip, data)
    local context = (tooltip and tooltip.__PvPTipContext) or {}
    local knownIndex = GetKnownSpellIndex()
    local candidateSpellIDs = BuildCandidateSpellIDs(tooltip, data, context, knownIndex)
    local primarySpellID = SelectPrimarySpellID(candidateSpellIDs)
    local spellIDs = {}

    if primarySpellID then
        spellIDs[1] = primarySpellID
    end

    local contextType = context.contextType or "unknown"
    if contextType == "unknown" or contextType == "hyperlink" then
        if #spellIDs > 0 then
            contextType = "spell"
        end
    end

    return {
        contextType = contextType,
        tooltipDataType = GetTooltipDataType(data),
        spellIDs = spellIDs,
        candidateSpellIDs = candidateSpellIDs,
        primarySpellID = primarySpellID,
        definitionID = context.definitionID,
        talentID = context.talentID,
        nodeID = context.nodeID,
        entryID = context.entryID,
        rank = context.rank,
        configID = context.configID,
        sourceLink = context.sourceLink,
        spellBookItemSlotIndex = context.spellBookItemSlotIndex,
        spellBookItemSpellBank = context.spellBookItemSpellBank,
    }
end

function R.CaptureSpell(tooltip, spellID, extraContext)
    local context = {
        contextType = "spell",
        spellID = ToNumber(spellID),
    }

    local existingContext = tooltip and tooltip.__PvPTipContext
    if type(existingContext) == "table"
        and existingContext.spellBookItemSlotIndex
        and (not context.spellID or not existingContext.spellID
            or IsSameSpellFamily(existingContext.spellID, context.spellID)) then
        context.contextType = "spellbook"
        context.spellBookItemSlotIndex = ToNumber(existingContext.spellBookItemSlotIndex)
        context.spellBookItemSpellBank = tonumber(existingContext.spellBookItemSpellBank)
    end

    if type(extraContext) == "table" then
        for key, value in pairs(extraContext) do
            context[key] = value
        end
    end

    SetTooltipContext(tooltip, context)
end

function R.CaptureSpellBookItem(tooltip, slotIndex, spellBank, spellID)
    SetTooltipContext(tooltip, {
        contextType = "spellbook",
        spellID = ToNumber(spellID),
        spellBookItemSlotIndex = ToNumber(slotIndex),
        spellBookItemSpellBank = tonumber(spellBank),
    })
end

function R.CaptureHyperlink(tooltip, hyperlink)
    SetTooltipContext(tooltip, {
        contextType = "hyperlink",
        sourceLink = hyperlink,
        spellID = hyperlink and tonumber(hyperlink:match("spell:(%d+)")) or nil,
    })
end

function R.CaptureTalent(tooltip, info)
    SetTooltipContext(tooltip, {
        contextType = "talent",
        talentID = info and info.talentID or nil,
        definitionID = info and info.definitionID or nil,
        nodeID = info and info.nodeID or nil,
        entryID = info and info.entryID or nil,
        rank = info and info.rank or nil,
        spellID = info and info.spellID or nil,
        configID = info and info.configID or nil,
    })
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, nestedValue in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(nestedValue, seen)
    end
    return copy
end

local function BuildResolverSamples(index)
    local samples = {}
    for _, slot in ipairs(index.spellbookSlots or {}) do
        local context = {
            contextType = "spellbook",
            spellBookItemSlotIndex = slot.slot,
            spellBookItemSpellBank = slot.bank,
            spellID = slot.spellID or slot.actionID,
        }

        table.insert(samples, {
            slot = slot.slot,
            bank = slot.bank,
            itemType = slot.itemType,
            actionID = slot.actionID,
            spellID = slot.spellID,
            candidateSpellIDs = BuildCandidateSpellIDs(nil, nil, context, index),
        })
    end

    return samples
end

function R.BuildDebugSnapshot(options)
    local index = GetKnownSpellIndex()
    local requestedSpellID = options and ToNumber(options.spellID) or nil
    local requestedContext = requestedSpellID and {
        contextType = "spell",
        spellID = requestedSpellID,
    } or nil

    local snapshot = {
        generatedAt = time and time() or nil,
        generatedAtText = date and date("!%Y-%m-%dT%H:%M:%SZ") or nil,
        build = PvPTipData and PvPTipData.Build or nil,
        clientBuild = PvPTip and PvPTip.clientBuild or nil,
        classID = PvPTip and PvPTip.currentClassID or nil,
        specID = U.GetCurrentSpecID(),
        configID = GetActiveConfigID(),
        spellbookSlots = index.spellbookSlots,
        slotCandidates = index.slotCandidates,
        knownSpellIDs = index.knownSpellIDs,
        familyBySpellID = index.familyBySpellID,
        traitLinks = index.traitLinks,
        pvpTalentLinks = index.pvpTalentLinks,
        resolverSamples = BuildResolverSamples(index),
    }

    if requestedSpellID then
        snapshot.requestedSpellID = requestedSpellID
        snapshot.familyClosure = GetExpandedSpellIDs(requestedSpellID)
        snapshot.knownFamilyClosure = index.familyBySpellID[requestedSpellID]
        snapshot.resolverCandidates = BuildCandidateSpellIDs(nil, nil, requestedContext, index)
    end

    return DeepCopy(snapshot)
end
