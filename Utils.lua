PvPTip = PvPTip or {}
PvPTip.Utils = PvPTip.Utils or {}
local U = PvPTip.Utils

local PLAYABLE_CLASS_IDS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}
local specDisplaySpellCache = {}
local factPvpEffectsCache = {}
local relationFromGraphCache = {}
local liveClassDataCache

local function WipeTable(target)
    if type(target) ~= "table" then
        return
    end
    for key in pairs(target) do
        target[key] = nil
    end
end

U.CLASS_COLORS = {
    [1]  = {0.78, 0.61, 0.43},
    [2]  = {0.96, 0.55, 0.73},
    [3]  = {0.67, 0.83, 0.45},
    [4]  = {1.00, 0.96, 0.41},
    [5]  = {1.00, 1.00, 1.00},
    [6]  = {0.77, 0.12, 0.23},
    [7]  = {0.00, 0.44, 0.87},
    [8]  = {0.25, 0.78, 0.92},
    [9]  = {0.53, 0.53, 0.93},
    [10] = {0.00, 1.00, 0.60},
    [11] = {1.00, 0.49, 0.04},
    [12] = {0.64, 0.19, 0.79},
    [13] = {0.20, 0.58, 0.50},
}

U.CLASS_TO_FAMILY_FALLBACK = {
    [1] = 4,
    [2] = 10,
    [3] = 9,
    [4] = 8,
    [5] = 6,
    [6] = 15,
    [7] = 11,
    [8] = 3,
    [9] = 5,
    [10] = 53,
    [11] = 7,
    [12] = 107,
    [13] = 224,
}

U.FAMILY_TO_CLASS = {
    [3] = 8, [4] = 1, [5] = 9, [6] = 5, [7] = 11,
    [8] = 4, [9] = 3, [10] = 2, [11] = 7, [15] = 6,
    [53] = 10, [107] = 12, [224] = 13,
}

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

local function GetLiveSpecializationIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end
    return nil
end

local function GetLiveSpecializationInfo(specIndex)
    local numericSpecIndex = tonumber(specIndex)
    if not numericSpecIndex or numericSpecIndex <= 0 then
        return nil
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local info = C_SpecializationInfo.GetSpecializationInfo(numericSpecIndex)
        if type(info) == "table" then
            return info.specializationID or info.specID or info.id
        end
        return info
    end

    return nil
end

function U.GetLiveCurrentSpecID()
    local specIndex = GetLiveSpecializationIndex()
    if specIndex and specIndex > 0 then
        return ToNumber(GetLiveSpecializationInfo(specIndex)) or 0
    end
    return 0
end

local function AddUniqueNumber(list, seen, value)
    local numericValue = ToNumber(value)
    if not numericValue or seen[numericValue] then
        return
    end
    seen[numericValue] = true
    table.insert(list, numericValue)
end

local function CopySortedNumbers(values)
    local result = {}
    local seen = {}

    if type(values) ~= "table" then
        return result
    end

    for _, value in ipairs(values) do
        AddUniqueNumber(result, seen, value)
    end
    table.sort(result)
    return result
end

local function CopySortedKeys(set)
    local values = {}
    for value in pairs(set or {}) do
        table.insert(values, value)
    end
    table.sort(values)
    return values
end

local function NormalizeComparableText(text)
    if type(text) ~= "string" then
        return ""
    end

    local normalized = string.lower(text)
    normalized = normalized:gsub("|c%x%x%x%x%x%x%x%x", "")
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("[%p%c]", " ")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", "")
    normalized = normalized:gsub("%s+$", "")
    return normalized
end

local function TextContainsComparableText(haystack, needle)
    local normalizedNeedle = NormalizeComparableText(needle)
    if normalizedNeedle == "" then
        return false
    end

    return string.find(NormalizeComparableText(haystack), normalizedNeedle, 1, true) ~= nil
end

local function AddSpellIDToSet(set, spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID or set[numericSpellID] then
        return false
    end
    set[numericSpellID] = true
    return true
end

local function SetIntersectsList(set, values)
    for _, value in ipairs(values or {}) do
        if set[value] then
            return true
        end
    end
    return false
end

local function CollectLiveSpellVariantIDs(spellID, specID, result, seen)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID or seen[numericSpellID] then
        return
    end

    seen[numericSpellID] = true
    table.insert(result, numericSpellID)

    if C_Spell and C_Spell.GetBaseSpell then
        local baseSpellID = ToNumber(C_Spell.GetBaseSpell(numericSpellID, specID or 0))
        if baseSpellID and baseSpellID ~= numericSpellID then
            CollectLiveSpellVariantIDs(baseSpellID, specID, result, seen)
        end
    end

    if C_Spell and C_Spell.GetOverrideSpell then
        local overrideSpellID = ToNumber(C_Spell.GetOverrideSpell(numericSpellID, specID or 0, true, 0))
        if overrideSpellID and overrideSpellID ~= numericSpellID then
            CollectLiveSpellVariantIDs(overrideSpellID, specID, result, seen)
        end
    end

    if C_SpellBook then
        local spellBookBaseSpellID = SafeCallNumber(C_SpellBook.FindBaseSpellByID, numericSpellID)
        if spellBookBaseSpellID and spellBookBaseSpellID ~= numericSpellID then
            CollectLiveSpellVariantIDs(spellBookBaseSpellID, specID, result, seen)
        end

        local spellBookOverrideSpellID = SafeCallNumber(C_SpellBook.FindSpellOverrideByID, numericSpellID)
        if spellBookOverrideSpellID and spellBookOverrideSpellID ~= numericSpellID then
            CollectLiveSpellVariantIDs(spellBookOverrideSpellID, specID, result, seen)
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
                        CollectLiveSpellVariantIDs(foundSpellID, specID, result, seen)
                    end
                    if actionID and actionID ~= numericSpellID then
                        CollectLiveSpellVariantIDs(actionID, specID, result, seen)
                    end
                end

                local info = C_SpellBook.GetSpellBookItemInfo(slotIndex, spellBank)
                if info then
                    if info.spellID and info.spellID ~= numericSpellID then
                        CollectLiveSpellVariantIDs(info.spellID, specID, result, seen)
                    end
                    if info.actionID and info.actionID ~= numericSpellID then
                        CollectLiveSpellVariantIDs(info.actionID, specID, result, seen)
                    end
                end

                if C_SpellBook.GetSpellBookItemLink then
                    local link = C_SpellBook.GetSpellBookItemLink(slotIndex, spellBank)
                    local linkedSpellID = link and tonumber(link:match("spell:(%d+)")) or nil
                    if linkedSpellID and linkedSpellID ~= numericSpellID then
                        CollectLiveSpellVariantIDs(linkedSpellID, specID, result, seen)
                    end
                end
            end
        end
    end
end

local function GetLiveSpellVariantIDs(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return {}
    end

    local result = {}
    local seen = {}
    CollectLiveSpellVariantIDs(numericSpellID, U.GetCurrentSpecID(), result, seen)
    table.sort(result)
    return result
end

local function GetCanonicalLiveVariantSpellID(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return nil
    end

    local sourceName = NormalizeComparableText(U.GetSpellName(numericSpellID, ""))
    local sourceIcon = U.GetSpellIcon(numericSpellID)
    if sourceName == "" then
        return nil
    end

    for _, candidateSpellID in ipairs(GetLiveSpellVariantIDs(numericSpellID)) do
        if candidateSpellID ~= numericSpellID
            and NormalizeComparableText(U.GetSpellName(candidateSpellID, "")) == sourceName
            and U.GetSpellIcon(candidateSpellID) == sourceIcon then
            return candidateSpellID
        end
    end

    return nil
end

function U.InvalidateCaches()
    WipeTable(specDisplaySpellCache)
    WipeTable(factPvpEffectsCache)
    WipeTable(relationFromGraphCache)
end

local function BuildLiveClassData()
    local classData = {}

    if not (C_CreatureInfo and C_CreatureInfo.GetClassInfo and C_SpecializationInfo
        and C_SpecializationInfo.GetNumSpecializationsForClassID and GetSpecializationInfoForClassID) then
        return classData
    end

    for _, classID in ipairs(PLAYABLE_CLASS_IDS) do
        local classInfo = C_CreatureInfo.GetClassInfo(classID)
        local specCount = C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
        local specs = {}

        for index = 1, specCount do
            local specID, specName = GetSpecializationInfoForClassID(classID, index)
            if ToNumber(specID) and type(specName) == "string" and specName ~= "" and specName ~= "Initial" then
                specs[specID] = specName
            end
        end

        if classInfo or next(specs) then
            classData[classID] = {
                name = (classInfo and classInfo.className) or ("Class #" .. tostring(classID)),
                specs = specs,
            }
        end
    end

    return classData
end

local function SecondsText(milliseconds)
    if not milliseconds or milliseconds <= 0 then
        return nil
    end

    local seconds = milliseconds / 1000
    if SecondsToTime then
        return SecondsToTime(seconds)
    end
    if math.floor(seconds) == seconds then
        return string.format("%ds", seconds)
    end
    return string.format("%.1fs", seconds)
end

function U.GetData()
    if type(PvPTipData) == "table" then
        return PvPTipData
    end
    return nil
end

function U.GetDataTable(key)
    local data = U.GetData()
    if type(data) ~= "table" then
        return nil
    end
    return data[key]
end

function U.GetClassDataMap()
    local classes = U.GetDataTable("Classes") or {}
    if next(classes) then
        return classes
    end

    if not liveClassDataCache then
        liveClassDataCache = BuildLiveClassData()
    end
    return liveClassDataCache or {}
end

function U.GetClassFamily(classID)
    local numericClassID = ToNumber(classID) or 0
    local families = U.GetDataTable("ClassFamilies") or {}
    return families[numericClassID] or U.CLASS_TO_FAMILY_FALLBACK[numericClassID] or 0
end

function U.GetClassName(classID, fallback)
    local classData = U.GetClassDataMap()[ToNumber(classID) or 0]
    if classData then
        return classData.name or classData.n or fallback
    end
    return fallback or ("Class #" .. tostring(classID))
end

function U.GetSpecName(specID, fallback)
    local numericSpecID = ToNumber(specID)
    if not numericSpecID then
        return fallback or ("Spec #" .. tostring(specID))
    end

    for _, classData in pairs(U.GetClassDataMap()) do
        local specs = classData.specs or classData.s or {}
        if specs[numericSpecID] then
            return specs[numericSpecID]
        end
    end

    if GetSpecializationInfoForSpecID then
        local _, name = GetSpecializationInfoForSpecID(numericSpecID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end

    return fallback or ("Spec #" .. tostring(numericSpecID))
end

function U.GetSpecClassID(specID)
    local numericSpecID = ToNumber(specID)
    if not numericSpecID then
        return 0
    end

    for classID, classData in pairs(U.GetClassDataMap()) do
        local specs = classData.specs or classData.s or {}
        if specs[numericSpecID] then
            return classID
        end
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetClassIDFromSpecID then
        return C_SpecializationInfo.GetClassIDFromSpecID(numericSpecID) or 0
    end

    return 0
end

function U.GetSpecDisplayName(specID)
    local numericSpecID = ToNumber(specID)
    if not numericSpecID then
        return "Spec #" .. tostring(specID)
    end

    local classID = U.GetSpecClassID(numericSpecID)
    if classID > 0 then
        return string.format("%s %s", U.GetSpecName(numericSpecID), U.GetClassName(classID))
    end

    return U.GetSpecName(numericSpecID)
end

function U.GetSpecDisplaySpellIDs(specID)
    local numericSpecID = ToNumber(specID)
    if not numericSpecID then
        return {}
    end

    if specDisplaySpellCache[numericSpecID] then
        return specDisplaySpellCache[numericSpecID]
    end

    local spellIDs = CopySortedNumbers((U.GetDataTable("SpecDisplaySpells") or {})[numericSpecID] or {})
    if #spellIDs == 0 and C_SpecializationInfo and C_SpecializationInfo.GetSpellsDisplay then
        spellIDs = CopySortedNumbers(C_SpecializationInfo.GetSpellsDisplay(numericSpecID) or {})
    end

    specDisplaySpellCache[numericSpecID] = spellIDs
    return spellIDs
end

function U.GetCurrentSpecID()
    local specID = PvPTip and PvPTip.currentSpecID
    if specID and specID > 0 then
        return specID
    end

    return U.GetLiveCurrentSpecID()
end

function U.GetSpellName(spellID, fallback)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return fallback or "Unknown spell"
    end

    if C_Spell and C_Spell.GetSpellName then
        local liveName = C_Spell.GetSpellName(numericSpellID)
        if liveName then
            return liveName
        end
    end

    return fallback or ("Spell #" .. tostring(numericSpellID))
end

function U.GetSpellIcon(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return 134400
    end

    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(numericSpellID)
        if texture then
            return texture
        end
    end

    return 134400
end

function U.IsSpellKnownOrInSpellBook(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return false
    end

    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook and Enum and Enum.SpellBookSpellBank then
        return C_SpellBook.IsSpellKnownOrInSpellBook(
            numericSpellID,
            Enum.SpellBookSpellBank.Player,
            true
        ) and true or false
    end

    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
        local slotIndex = C_SpellBook.FindSpellBookSlotForSpell(
            numericSpellID,
            true,
            true,
            false,
            false
        )
        if slotIndex then
            return true
        end
    end

    return false
end

function U.GetSpellRelation(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return nil
    end

    local cached = relationFromGraphCache[numericSpellID]
    if cached then
        return cached
    end

    local spellRelationsGraph = U.GetDataTable("SpellRelationsGraph")
    if spellRelationsGraph then
        local relation = {}
        local canonical = (spellRelationsGraph.canonical or spellRelationsGraph.c or {})[numericSpellID]
        local replacement = (spellRelationsGraph.replacement or spellRelationsGraph.rp or {})[numericSpellID]
        local display = (spellRelationsGraph.display or spellRelationsGraph.d or {})[numericSpellID]
        local trigger = (spellRelationsGraph.trigger or spellRelationsGraph.t or {})[numericSpellID]
        local resolved = (spellRelationsGraph.resolved or spellRelationsGraph.r or {})[numericSpellID]
        local sources = (spellRelationsGraph.sources or spellRelationsGraph.s or {})[numericSpellID]

        if canonical then
            relation.canonicalSpellID = canonical
        end
        if replacement and #replacement > 0 then
            relation.replacementSpellIDs = replacement
        end
        if display and #display > 0 then
            relation.displaySpellIDs = display
        end
        if trigger and #trigger > 0 then
            relation.triggerSpellIDs = trigger
        end
        if resolved and #resolved > 0 then
            relation.resolvedSpellIDs = resolved
        end
        if sources and #sources > 0 then
            relation.sourceSpellIDs = sources
        end

        if next(relation) then
            relationFromGraphCache[numericSpellID] = relation
            return relation
        end
    end

    local spellRelations = U.GetDataTable("SpellRelations")
    return spellRelations and spellRelations[numericSpellID] or nil
end

function U.GetSpellMeta(spellID)
    local numericSpellID = ToNumber(spellID)
    local spellMetaFacts = U.GetDataTable("SpellMetaFacts")
    if spellMetaFacts and spellMetaFacts[numericSpellID] then
        return spellMetaFacts[numericSpellID]
    end
    local spellMeta = U.GetDataTable("SpellMeta")
    return spellMeta and spellMeta[numericSpellID] or nil
end

local function BuildPvpEffectsFromFactRows(factRows)
    local result = {}

    for _, effect in ipairs(factRows or {}) do
        local difficultyID = tonumber(effect.difficultyID or effect.d) or 0
        local coefficient = tonumber(effect.pvpCoefficient or effect.p) or 1
        if difficultyID == 0 and math.abs(coefficient - 1) > 0.0001 then
            local compact = {}
            local index = tonumber(effect.index or effect.i)
            if index then
                compact.index = index
            end
            if effect.label or effect.l then
                compact.label = effect.label or effect.l
            end
            compact.pvpCoefficient = coefficient

            local triggerSpellID = tonumber(effect.triggerSpellID or effect.g)
            if triggerSpellID and triggerSpellID > 0 then
                compact.triggerSpellID = triggerSpellID
            end
            local targetPreviewName = effect.targetPreviewName or effect.n
            if type(targetPreviewName) == "string" and targetPreviewName ~= "" then
                compact.targetPreviewName = targetPreviewName
            end
            table.insert(result, compact)
        end
    end

    table.sort(result, function(left, right)
        return (tonumber(left.index) or 0) < (tonumber(right.index) or 0)
    end)
    return result
end

function U.GetPvpEffects(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return {}
    end

    local spellEffectFacts = U.GetDataTable("SpellEffectFacts")
    if spellEffectFacts and spellEffectFacts[numericSpellID] then
        if factPvpEffectsCache[numericSpellID] == nil then
            factPvpEffectsCache[numericSpellID] = BuildPvpEffectsFromFactRows(
                spellEffectFacts[numericSpellID]
            )
        end
        return factPvpEffectsCache[numericSpellID] or {}
    end

    local pvpSpellEffects = U.GetDataTable("PvpSpellEffects")
    local entry = pvpSpellEffects and pvpSpellEffects[numericSpellID] or nil
    return entry and (entry.effects or entry.e) or {}
end

function U.GetTraitDefinitionInfo(definitionID)
    local numericDefinitionID = ToNumber(definitionID)
    if not numericDefinitionID or not (C_Traits and C_Traits.GetDefinitionInfo) then
        return nil
    end
    return C_Traits.GetDefinitionInfo(numericDefinitionID)
end

function U.GetTraitDefinitionSpellIDs(definitionID)
    local result = {}
    local seen = {}
    local numericDefinitionID = ToNumber(definitionID)
    local definitionData = (U.GetDataTable("TraitDefinitions") or {})[numericDefinitionID or 0]
    local liveInfo = U.GetTraitDefinitionInfo(numericDefinitionID)

    if definitionData then
        AddUniqueNumber(result, seen, definitionData.visibleSpellID or definitionData.v)
        AddUniqueNumber(result, seen, definitionData.overridesSpellID or definitionData.o)
        for _, spellID in ipairs(definitionData.resolvedSpellIDs or definitionData.r or {}) do
            AddUniqueNumber(result, seen, spellID)
        end
    end

    if liveInfo then
        AddUniqueNumber(result, seen, liveInfo.spellID)
        AddUniqueNumber(result, seen, liveInfo.overriddenSpellID)
    end

    local expanded = {}
    local expandedSeen = {}
    for _, spellID in ipairs(result) do
        for _, candidateSpellID in ipairs(GetLiveSpellVariantIDs(spellID)) do
            AddUniqueNumber(expanded, expandedSeen, candidateSpellID)
        end
    end
    if #expanded > 0 then
        return expanded
    end

    return result
end

function U.GetResolvedSpellIDs(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return nil
    end

    local relation = U.GetSpellRelation(numericSpellID)
    local resolvedSpellIDs = relation and (relation.resolvedSpellIDs or relation.r)
    if resolvedSpellIDs and #resolvedSpellIDs > 0 then
        return resolvedSpellIDs
    end

    local liveVariants = GetLiveSpellVariantIDs(numericSpellID)
    if #liveVariants > 0 then
        local result = {}
        local seen = {}

        for _, candidateSpellID in ipairs(liveVariants) do
            local candidateRelation = U.GetSpellRelation(candidateSpellID)
            local candidateResolvedSpellIDs = candidateRelation and (candidateRelation.resolvedSpellIDs or candidateRelation.r)
            if candidateResolvedSpellIDs and #candidateResolvedSpellIDs > 0 then
                for _, resolvedSpellID in ipairs(candidateResolvedSpellIDs) do
                    AddUniqueNumber(result, seen, resolvedSpellID)
                end
            elseif #U.GetPvpEffects(candidateSpellID) > 0 or U.GetSpellMeta(candidateSpellID) then
                AddUniqueNumber(result, seen, candidateSpellID)
            end
        end

        if #result > 0 then
            return result
        end
    end

    if #U.GetPvpEffects(numericSpellID) > 0 or U.GetSpellMeta(numericSpellID) then
        return {numericSpellID}
    end

    if #liveVariants > 0 then
        return liveVariants
    end

    if C_Spell and C_Spell.DoesSpellExist and C_Spell.DoesSpellExist(numericSpellID) then
        return {numericSpellID}
    end

    return nil
end

function U.GetCanonicalSpellID(spellID)
    local numericSpellID = ToNumber(spellID)
    if not numericSpellID then
        return nil
    end

    if C_Spell and C_Spell.GetBaseSpell then
        local baseSpellID = ToNumber(C_Spell.GetBaseSpell(numericSpellID, U.GetCurrentSpecID()))
        if baseSpellID and baseSpellID ~= numericSpellID then
            return baseSpellID
        end
    end

    local liveVariantSpellID = GetCanonicalLiveVariantSpellID(numericSpellID)
    if liveVariantSpellID then
        return liveVariantSpellID
    end

    local relation = U.GetSpellRelation(numericSpellID)
    local canonicalSpellID = relation and (relation.canonicalSpellID or relation.c)
    if ToNumber(canonicalSpellID) and canonicalSpellID ~= numericSpellID then
        return canonicalSpellID
    end

    return numericSpellID
end

function U.ResolveSpellID(spellID)
    local resolvedSpellIDs = U.GetResolvedSpellIDs(spellID)
    if resolvedSpellIDs and #resolvedSpellIDs > 0 then
        return resolvedSpellIDs[1], #resolvedSpellIDs > 1
    end
    return nil, false
end

function U.GetClassSpecIDs(classID)
    local numericClassID = ToNumber(classID)
    local result = {}
    local classData = U.GetClassDataMap()[numericClassID or 0]

    for specID in pairs((classData and (classData.specs or classData.s)) or {}) do
        table.insert(result, specID)
    end

    table.sort(result)
    return result
end

function U.BuildClassSourceSpellIDs(classID)
    local numericClassID = ToNumber(classID)
    if not numericClassID then
        return {}
    end

    local classFamily = U.GetClassFamily(numericClassID)
    local classSpecIDs = U.GetClassSpecIDs(numericClassID)
    local classSpecSet = {}
    local sourceSet = {}
    local pvpSpellEffects = U.GetDataTable("PvpSpellEffects") or {}
    local spellRelations = U.GetDataTable("SpellRelations") or {}
    local traitDefinitions = U.GetDataTable("TraitDefinitions") or {}
    local pvpTalents = U.GetDataTable("PvpTalents") or {}
    local specSpells = U.GetDataTable("SpecSpells") or {}

    for _, specID in ipairs(classSpecIDs) do
        classSpecSet[specID] = true

        for _, spellID in ipairs(specSpells[specID] or {}) do
            AddSpellIDToSet(sourceSet, spellID)
        end
        for _, spellID in ipairs(U.GetSpecDisplaySpellIDs(specID)) do
            AddSpellIDToSet(sourceSet, spellID)
        end
    end

    for spellID, entry in pairs(pvpSpellEffects) do
        if classFamily > 0 and entry.classFamily == classFamily then
            AddSpellIDToSet(sourceSet, spellID)
        end
    end

    for _, talentData in pairs(pvpTalents) do
        if classSpecSet[tonumber(talentData.specID) or 0] then
            AddSpellIDToSet(sourceSet, talentData.actionBarSpellID)
            AddSpellIDToSet(sourceSet, talentData.overridesSpellID)
            for _, spellID in ipairs(talentData.resolvedSpellIDs or {}) do
                AddSpellIDToSet(sourceSet, spellID)
            end
        end
    end

    local changed = true
    while changed do
        changed = false

        for spellID, relation in pairs(spellRelations) do
            if sourceSet[spellID]
                or SetIntersectsList(sourceSet, relation.resolvedSpellIDs)
                or SetIntersectsList(sourceSet, relation.sourceSpellIDs) then
                local added = AddSpellIDToSet(sourceSet, spellID)
                for _, linkedSpellID in ipairs(relation.sourceSpellIDs or {}) do
                    added = AddSpellIDToSet(sourceSet, linkedSpellID) or added
                end
                for _, linkedSpellID in ipairs(relation.resolvedSpellIDs or {}) do
                    added = AddSpellIDToSet(sourceSet, linkedSpellID) or added
                end
                if relation.canonicalSpellID then
                    added = AddSpellIDToSet(sourceSet, relation.canonicalSpellID) or added
                end
                changed = changed or added
            end
        end

        for _, definitionData in pairs(traitDefinitions) do
            local resolvedSpellIDs = definitionData.resolvedSpellIDs or {}
            if SetIntersectsList(sourceSet, resolvedSpellIDs) then
                local added = AddSpellIDToSet(sourceSet, definitionData.visibleSpellID)
                added = AddSpellIDToSet(sourceSet, definitionData.overridesSpellID) or added
                for _, spellID in ipairs(resolvedSpellIDs) do
                    added = AddSpellIDToSet(sourceSet, spellID) or added
                end
                changed = changed or added
            elseif classFamily > 0 then
                for _, spellID in ipairs(resolvedSpellIDs) do
                    local effectEntry = pvpSpellEffects[spellID]
                    if effectEntry and effectEntry.classFamily == classFamily then
                        local added = AddSpellIDToSet(sourceSet, definitionData.visibleSpellID)
                        added = AddSpellIDToSet(sourceSet, definitionData.overridesSpellID) or added
                        for _, resolvedSpellID in ipairs(resolvedSpellIDs) do
                            added = AddSpellIDToSet(sourceSet, resolvedSpellID) or added
                        end
                        changed = changed or added
                        break
                    end
                end
            end
        end
    end

    return CopySortedKeys(sourceSet)
end

function U.BuildSpellGroups(spellIDs, options)
    local sourceSpellIDs = {}
    local sourceSeen = {}
    local sourceList = type(spellIDs) == "table" and spellIDs or {spellIDs}
    local groupByBaseSpell = not options or options.groupByBaseSpell ~= false
    local resolveHierarchy = not options or options.resolveHierarchy ~= false
    local buckets = {}

    for _, spellID in ipairs(sourceList) do
        AddUniqueNumber(sourceSpellIDs, sourceSeen, spellID)
    end

    for _, sourceSpellID in ipairs(sourceSpellIDs) do
        local resolvedSpellIDs = resolveHierarchy and (U.GetResolvedSpellIDs(sourceSpellID) or {sourceSpellID}) or {sourceSpellID}
        for _, resolvedSpellID in ipairs(resolvedSpellIDs) do
            local baseSpellID = groupByBaseSpell and (U.GetCanonicalSpellID(resolvedSpellID) or resolvedSpellID) or resolvedSpellID
            local bucket = buckets[baseSpellID]
            if not bucket then
                bucket = {
                    baseSpellID = baseSpellID,
                    sourceSet = {},
                    resolvedSet = {},
                }
                buckets[baseSpellID] = bucket
            end
            bucket.sourceSet[sourceSpellID] = true
            bucket.resolvedSet[resolvedSpellID] = true
        end
    end

    local groups = {}
    for baseSpellID, bucket in pairs(buckets) do
        table.insert(groups, {
            baseSpellID = baseSpellID,
            sourceSpellIDs = CopySortedKeys(bucket.sourceSet),
            resolvedSpellIDs = CopySortedKeys(bucket.resolvedSet),
            name = U.GetSpellName(baseSpellID, "Spell #" .. tostring(baseSpellID)),
        })
    end

    table.sort(groups, function(left, right)
        return string.lower(left.name or "") < string.lower(right.name or "")
    end)

    return groups
end

function U.CollectResolvedEffects(spellIDs)
    local queue = type(spellIDs) == "table" and spellIDs or {spellIDs}
    local effects = {}
    local affectedByIDs = {}
    local strongestCoefficient = 1
    local strongestDeviation = 0

    for _, spellID in ipairs(queue) do
        for _, resolvedSpellID in ipairs(U.GetResolvedSpellIDs(spellID) or {}) do
            local pvpEffects = U.GetPvpEffects(resolvedSpellID)
            if #pvpEffects > 0 then
                affectedByIDs[resolvedSpellID] = true
            end

            for _, effect in ipairs(pvpEffects) do
                local coefficient = tonumber(effect.pvpCoefficient) or 1
                table.insert(effects, {
                    spellID = resolvedSpellID,
                    effect = effect,
                    mult = coefficient,
                })

                local deviation = math.abs(coefficient - 1)
                if deviation > strongestDeviation then
                    strongestDeviation = deviation
                    strongestCoefficient = coefficient
                end
            end
        end
    end

    return effects, affectedByIDs, strongestCoefficient
end

function U.GetModifierByEffectID(effectID)
    local numericEffectID = ToNumber(effectID)
    local spellModLookup = U.GetDataTable("SpellModFacts") or U.GetDataTable("SpellModLookup")
    local byEffectID = spellModLookup and (spellModLookup.byEffectID or spellModLookup.e) or nil
    local entry = byEffectID and byEffectID[numericEffectID] or nil
    if entry then
        entry.effectID = entry.effectID or numericEffectID
        if entry.baseValue == nil and entry.value ~= nil then
            entry.baseValue = entry.value
        end
        if entry.targetPreviewName == nil and type(entry.scope) == "table" then
            entry.targetPreviewName = entry.scope.targetPreviewName
        end
        if entry.targetSpellIDs == nil and type(entry.scope) == "table" then
            entry.targetSpellIDs = entry.scope.targetSpellIDs
        end
    end
    return entry
end

local function GetModifierList(indexTable, spellID)
    local numericSpellID = ToNumber(spellID)
    local spellModLookup = U.GetDataTable("SpellModFacts") or U.GetDataTable("SpellModLookup")
    local resolvedIndexName = indexTable
    if indexTable == "byTarget" then
        resolvedIndexName = spellModLookup and (spellModLookup.byTarget and "byTarget" or "t") or indexTable
    elseif indexTable == "bySourceSpell" then
        resolvedIndexName = spellModLookup and (spellModLookup.bySourceSpell and "bySourceSpell" or "s") or indexTable
    end
    local effectIDs = spellModLookup and spellModLookup[resolvedIndexName] and spellModLookup[resolvedIndexName][numericSpellID] or nil
    if not effectIDs then
        return {}
    end

    local result = {}
    for _, effectID in ipairs(effectIDs) do
        local modifier = U.GetModifierByEffectID(effectID)
        if modifier then
            modifier.effectID = modifier.effectID or effectID
            table.insert(result, modifier)
        end
    end

    table.sort(result, function(left, right)
        local leftName = string.lower(U.GetSpellName(left.sourceSpellID, "") .. "|" .. (left.label or ""))
        local rightName = string.lower(U.GetSpellName(right.sourceSpellID, "") .. "|" .. (right.label or ""))
        if leftName == rightName then
            return (left.effectID or 0) < (right.effectID or 0)
        end
        return leftName < rightName
    end)

    return result
end

function U.GetModifiersByTarget(spellID)
    return GetModifierList("byTarget", spellID)
end

function U.GetModifiersBySourceSpell(spellID)
    return GetModifierList("bySourceSpell", spellID)
end

function U.GetAffectedBy(spellID)
    return U.GetModifiersByTarget(spellID)
end

function U.GetAllRetainedSpellIDs()
    local result = {}
    local seen = {}

    for spellID in pairs(U.GetDataTable("SpellRelations") or {}) do
        AddUniqueNumber(result, seen, spellID)
    end
    local relationGraph = U.GetDataTable("SpellRelationsGraph") or {}
    for _, bucketName in ipairs({"canonical", "replacement", "display", "trigger", "resolved", "sources", "affects"}) do
        local bucket = relationGraph[bucketName]
        if type(bucket) == "table" then
            for spellID, value in pairs(bucket) do
                AddUniqueNumber(result, seen, spellID)
                if type(value) == "table" then
                    for _, linkedSpellID in ipairs(value) do
                        AddUniqueNumber(result, seen, linkedSpellID)
                    end
                else
                    AddUniqueNumber(result, seen, value)
                end
            end
        end
    end
    for spellID in pairs(U.GetDataTable("PvpSpellEffects") or {}) do
        AddUniqueNumber(result, seen, spellID)
    end
    for spellID in pairs(U.GetDataTable("SpellEffectFacts") or {}) do
        AddUniqueNumber(result, seen, spellID)
    end
    for spellID in pairs(U.GetDataTable("SpellMeta") or {}) do
        AddUniqueNumber(result, seen, spellID)
    end
    for spellID in pairs(U.GetDataTable("SpellMetaFacts") or {}) do
        AddUniqueNumber(result, seen, spellID)
    end

    table.sort(result)
    return result
end

function U.FormatRawCoefficient(multiplier)
    local coefficient = tonumber(multiplier) or 1
    local text = string.format("%.3f", coefficient)
    text = text:gsub("(%..-)0+$", "%1")
    text = text:gsub("%.$", "")
    return "coeff " .. text
end

local function TrimText(text)
    if type(text) ~= "string" then
        return ""
    end
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function FormatSignedPercent(value)
    local numericValue = tonumber(value) or 0
    if math.abs(numericValue) < 0.0001 then
        numericValue = 0
    end

    local text = string.format("%.2f", numericValue)
    text = text:gsub("(%..-)0+$", "%1")
    text = text:gsub("%.$", "")
    if numericValue > 0 then
        text = "+" .. text
    end
    return text
end

function U.FormatPvpDeltaPercent(multiplier)
    local coefficient = tonumber(multiplier) or 1
    return FormatSignedPercent((coefficient - 1) * 100) .. "%"
end

local function FormatSignedValue(value)
    local numericValue = tonumber(value)
    if not numericValue or math.abs(numericValue) < 0.0001 then
        return nil
    end

    local text = string.format("%.3f", numericValue)
    text = text:gsub("(%..-)0+$", "%1")
    text = text:gsub("%.$", "")
    if numericValue > 0 then
        text = "+" .. text
    end
    return text
end

function U.GetCoeffColor(multiplier, cfg)
    if multiplier and multiplier > 1.001 then
        return cfg.colors.buff[1], cfg.colors.buff[2], cfg.colors.buff[3]
    end
    if multiplier and multiplier < 0.999 then
        return cfg.colors.nerf[1], cfg.colors.nerf[2], cfg.colors.nerf[3]
    end
    return cfg.colors.neutral[1], cfg.colors.neutral[2], cfg.colors.neutral[3]
end

function U.IsGenericEffectLabel(label)
    local text = string.lower(label or "")
    return text == ""
        or text == "dummy"
        or text == "dummy aura"
        or text == "modified effect value"
        or text == "modifier"
        or text == "modifier %"
        or text == "modifier (label)"
        or text == "modifier % (label)"
        or text == "effect"
        or text == "aura"
        or text:match("^modifier") ~= nil
        or text:match("^effect %d+ value") ~= nil
        or text:match("^modified effect value") ~= nil
        or text:match("^effect #%d+$") ~= nil
        or text:match("^aura #%d+$") ~= nil
end

function U.ResolveEffectLabel(effect)
    if type(effect) ~= "table" then
        return "Effect"
    end

    local label = effect.label or ""
    label = label ~= "" and label or effect.l or ""
    if not U.IsGenericEffectLabel(label) then
        return label
    end

    local targetPreviewName = effect.targetPreviewName or effect.n
    local triggerSpellID = effect.triggerSpellID or effect.g
    local triggerSpellName = ToNumber(triggerSpellID) and U.GetSpellName(triggerSpellID)

    if targetPreviewName then
        return targetPreviewName
    end
    if triggerSpellName then
        return triggerSpellName
    end
    if label ~= "" then
        return label
    end
    return "Effect"
end

function U.CleanEffectDisplayLabel(label)
    local cleaned = TrimText(label)
    if cleaned == "" then
        return "Effect"
    end

    local coreLabel, suffix = cleaned:match("^(.-)%s*%((.-)%)%s*$")
    if coreLabel and suffix then
        local normalizedSuffix = string.lower(suffix)
        if normalizedSuffix:find("/", 1, true)
            or normalizedSuffix:find("%+%d+ more")
            or normalizedSuffix:find("known modifier", 1, true)
            or normalizedSuffix:find("from ", 1, true) then
            cleaned = TrimText(coreLabel)
        end
    end

    if cleaned == "" then
        return "Effect"
    end
    return cleaned
end

local function FormatDurationValue(durationMS, maxDurationMS)
    local durationText = SecondsText(durationMS)
    local maxDurationText = SecondsText(maxDurationMS)
    if durationText and maxDurationText and maxDurationMS and durationMS and maxDurationMS > durationMS then
        return string.format("%s-%s", durationText, maxDurationText)
    end
    return durationText or maxDurationText
end

function U.GetSpellPvpDurationInfo(spellID)
    local meta = U.GetSpellMeta(spellID)
    if not meta then
        return nil
    end

    local durationMS = tonumber(meta.durationMS or meta.d) or 0
    local maxDurationMS = tonumber(meta.maxDurationMS or meta.m) or 0
    local pvpDurationMS = tonumber(meta.pvpDurationMS or meta.p) or 0
    local pvpMaxDurationMS = tonumber(meta.pvpMaxDurationMS or meta.pm) or 0

    if pvpDurationMS <= 0 and pvpMaxDurationMS <= 0 then
        return nil
    end
    if durationMS == pvpDurationMS and maxDurationMS == pvpMaxDurationMS then
        return nil
    end

    return {
        durationMS = durationMS,
        maxDurationMS = maxDurationMS,
        pvpDurationMS = pvpDurationMS,
        pvpMaxDurationMS = pvpMaxDurationMS,
    }
end

function U.FormatPvpDurationForSpell(spellID, mode)
    local info = U.GetSpellPvpDurationInfo(spellID)
    if not info then
        return nil
    end

    local baseText = FormatDurationValue(info.durationMS, info.maxDurationMS)
    local pvpText = FormatDurationValue(info.pvpDurationMS, info.pvpMaxDurationMS)
    if not pvpText then
        return nil
    end

    if mode == "minimal" then
        return "Duration " .. pvpText
    end
    if baseText then
        return string.format("Duration %s (base %s)", pvpText, baseText)
    end
    return "Duration " .. pvpText
end

function U.FormatEffectCompact(effect)
    if type(effect) ~= "table" then
        return "Effect", 1
    end

    local label = U.CleanEffectDisplayLabel(U.ResolveEffectLabel(effect))
    local coefficient = tonumber(effect.pvpCoefficient or effect.p) or 1
    return string.format("%s: %s in PvP", label, U.FormatPvpDeltaPercent(coefficient)), coefficient
end

local function BuildVerboseEffectText(effect, options)
    if type(effect) ~= "table" then
        return "Effect", 1
    end

    return U.FormatEffectCompact(effect, options)
end

function U.FormatEffectVerbose(effect, options)
    return BuildVerboseEffectText(effect, options)
end

function U.FormatEffectMinimal(effect)
    if type(effect) ~= "table" then
        return "Effect", 1
    end

    return U.FormatEffectCompact(effect)
end

local function GetEffectFormatter(mode)
    if mode == "verbose" then
        return U.FormatEffectVerbose
    end
    if mode == "minimal" then
        return U.FormatEffectMinimal
    end
    return U.FormatEffectCompact
end

function U.GetGroupPvpRows(group, mode)
    if type(group) ~= "table" then
        return {}, 1
    end

    local formatter = GetEffectFormatter(mode)
    local rows = {}
    local seen = {}
    local strongestCoefficient = 1
    local strongestDeviation = 0
    local preparedEffects = {}

    for _, spellID in ipairs(group.resolvedSpellIDs or {}) do
        for _, effect in ipairs(U.GetPvpEffects(spellID)) do
            table.insert(preparedEffects, {
                spellID = spellID,
                effect = effect,
                index = tonumber(effect.index or effect.i) or 999999,
            })
        end
    end

    table.sort(preparedEffects, function(left, right)
        if left.index ~= right.index then
            return left.index < right.index
        end
        return (left.spellID or 0) < (right.spellID or 0)
    end)

    for _, prepared in ipairs(preparedEffects) do
        local text, coefficient = formatter(prepared.effect)
        local label = U.CleanEffectDisplayLabel(U.ResolveEffectLabel(prepared.effect))
        local dedupeKey = table.concat({
            tostring(prepared.spellID or 0),
            tostring(prepared.index or 0),
            label,
            string.format("%.6f", tonumber(coefficient) or 1),
        }, "|")

        if text and text ~= "" and not seen[dedupeKey] then
            seen[dedupeKey] = true
            table.insert(rows, {
                text = text,
                coefficient = coefficient,
                spellID = prepared.spellID,
            })
        end

        local deviation = math.abs((tonumber(coefficient) or 1) - 1)
        if deviation > strongestDeviation then
            strongestDeviation = deviation
            strongestCoefficient = coefficient
        end
    end

    return rows, strongestCoefficient
end

function U.GroupHasPvpData(group)
    local rows = U.GetGroupPvpRows(group, "compact")
    return #rows > 0
end

local function ResolveModifierDetail(modifier)
    if type(modifier) ~= "table" then
        return nil, nil
    end

    local detail = modifier.label or modifier.l
    local targetPreviewName = modifier.targetPreviewName or modifier.n

    if U.IsGenericEffectLabel(detail) then
        detail = targetPreviewName or modifier.modifierOpName or modifier.o or detail
    elseif targetPreviewName and detail
        and not TextContainsComparableText(detail, targetPreviewName) then
        detail = string.format("%s (%s)", detail, targetPreviewName)
    end

    local parts = {}
    if detail and detail ~= "" then
        table.insert(parts, detail)
    end

    local baseValueText = FormatSignedValue(modifier.baseValue or modifier.b)
    if baseValueText then
        table.insert(parts, "base " .. baseValueText)
    end

    local coefficient = tonumber(modifier.pvpCoefficient or modifier.p) or 1
    if math.abs(coefficient - 1) > 0.0001 then
        table.insert(parts, U.FormatRawCoefficient(coefficient))
    end

    return table.concat(parts, ", "), coefficient
end

function U.FormatModifier(modifier)
    if type(modifier) ~= "table" then
        return nil
    end

    local sourceSpellID = modifier.sourceSpellID or modifier.s
    local sourceName = U.GetSpellName(sourceSpellID, sourceSpellID and ("Spell #" .. tostring(sourceSpellID)) or "Modifier")
    local detail = ResolveModifierDetail(modifier)

    if detail and detail ~= "" and detail ~= sourceName then
        return string.format("%s: %s", sourceName, detail)
    end
    return sourceName
end

local function BuildContextSpellSet(contextSpellIDs)
    local contextSet = {}

    for _, spellID in ipairs(contextSpellIDs or {}) do
        AddSpellIDToSet(contextSet, spellID)
        AddSpellIDToSet(contextSet, U.GetCanonicalSpellID(spellID))
        for _, resolvedSpellID in ipairs(U.GetResolvedSpellIDs(spellID) or {}) do
            AddSpellIDToSet(contextSet, resolvedSpellID)
            AddSpellIDToSet(contextSet, U.GetCanonicalSpellID(resolvedSpellID))
        end
    end

    return contextSet
end

local function ModifierSourceMatchesContext(sourceSpellID, contextSet)
    local numericSourceSpellID = ToNumber(sourceSpellID)
    if not numericSourceSpellID then
        return false
    end

    if contextSet[numericSourceSpellID] then
        return true
    end

    local canonicalSpellID = U.GetCanonicalSpellID(numericSourceSpellID)
    if canonicalSpellID and contextSet[canonicalSpellID] then
        return true
    end

    for _, resolvedSpellID in ipairs(U.GetResolvedSpellIDs(numericSourceSpellID) or {}) do
        if contextSet[resolvedSpellID] then
            return true
        end
        local resolvedCanonicalSpellID = U.GetCanonicalSpellID(resolvedSpellID)
        if resolvedCanonicalSpellID and contextSet[resolvedCanonicalSpellID] then
            return true
        end
    end

    return false
end

local function ShouldIncludeAffectingModifier(modifier, options)
    local sourceSpellID = modifier and (modifier.sourceSpellID or modifier.s)
    if not ToNumber(sourceSpellID) then
        return false
    end

    if options and options.contextSpellSet and ModifierSourceMatchesContext(sourceSpellID, options.contextSpellSet) then
        return true
    end

    if options and options.onlyKnownSources == false then
        return true
    end

    return U.IsSpellKnownOrInSpellBook(sourceSpellID)
end

local function ResolveModifierContribution(modifier)
    local valueType = string.lower(tostring(modifier and modifier.valueType or ""))
    local pvpCoefficient = tonumber(modifier and (modifier.pvpCoefficient or modifier.p)) or 1
    local baseValue = tonumber(modifier and (modifier.value or modifier.baseValue or modifier.b)) or 0

    if valueType == "pct" then
        local effectivePercent = baseValue * pvpCoefficient
        if math.abs(effectivePercent) <= 0.0001 then
            return {
                valueType = "pct",
                multiplier = 1,
                applied = false,
            }
        end

        local multiplier = 1 + (effectivePercent / 100)
        if multiplier <= 0 then
            return {
                valueType = "pct",
                multiplier = 1,
                applied = false,
            }
        end

        return {
            valueType = "pct",
            multiplier = multiplier,
            applied = true,
        }
    end

    if valueType == "pvp" then
        if math.abs(pvpCoefficient - 1) <= 0.0001 then
            return {
                valueType = "pvp",
                multiplier = 1,
                applied = false,
            }
        end

        return {
            valueType = "pvp",
            multiplier = pvpCoefficient,
            applied = true,
        }
    end

    return {
        valueType = (valueType ~= "" and valueType) or "flat",
        multiplier = 1,
        applied = false,
    }
end

function U.GetSpellModifierRollup(spellID, options)
    local rollup = {
        multiplier = 1,
        appliedCount = 0,
        consideredCount = 0,
        pctCount = 0,
        pvpCount = 0,
        flatCount = 0,
    }

    local contextSet = BuildContextSpellSet(options and options.contextSpellIDs or {})
    local seenEffectIDs = {}

    for _, modifier in ipairs(U.GetAffectedBy(spellID)) do
        local effectID = ToNumber(modifier and modifier.effectID)
        if not effectID or not seenEffectIDs[effectID] then
            if effectID then
                seenEffectIDs[effectID] = true
            end

            if ShouldIncludeAffectingModifier(modifier, {
                contextSpellSet = contextSet,
                onlyKnownSources = options and options.onlyKnownSources,
            }) then
                rollup.consideredCount = rollup.consideredCount + 1

                local contribution = ResolveModifierContribution(modifier)
                if contribution.valueType == "pct" then
                    rollup.pctCount = rollup.pctCount + 1
                elseif contribution.valueType == "pvp" then
                    rollup.pvpCount = rollup.pvpCount + 1
                else
                    rollup.flatCount = rollup.flatCount + 1
                end

                if contribution.applied and contribution.multiplier then
                    rollup.multiplier = rollup.multiplier * contribution.multiplier
                    rollup.appliedCount = rollup.appliedCount + 1
                end
            end
        end
    end

    rollup.hasApplied = rollup.appliedCount > 0 and math.abs(rollup.multiplier - 1) > 0.0001
    return rollup
end

local function BuildModifierRow(modifier, includeSourceName)
    if type(modifier) ~= "table" then
        return nil
    end

    local detail, coefficient = ResolveModifierDetail(modifier)
    local text = detail

    if includeSourceName ~= false then
        local sourceSpellID = modifier.sourceSpellID or modifier.s
        local sourceName = U.GetSpellName(sourceSpellID, sourceSpellID and ("Spell #" .. tostring(sourceSpellID)) or "Modifier")
        if detail and detail ~= "" and detail ~= sourceName then
            text = string.format("%s: %s", sourceName, detail)
        else
            text = sourceName
        end
    elseif not text or text == "" then
        local sourceSpellID = modifier.sourceSpellID or modifier.s
        text = U.GetSpellName(sourceSpellID, sourceSpellID and ("Spell #" .. tostring(sourceSpellID)) or "Modifier")
    end

    return {
        text = text,
        coefficient = coefficient or 1,
        spellID = modifier.sourceSpellID or modifier.s,
        isModifier = true,
    }
end

function U.GetGroupModifierRows(group, mode, options)
    local rows = {}
    local seen = {}
    local contextSet = BuildContextSpellSet(options and options.contextSpellIDs or {})

    for _, modifier in ipairs(U.GetGroupAffectedBy(group)) do
        if ShouldIncludeAffectingModifier(modifier, {
            contextSpellSet = contextSet,
            onlyKnownSources = options and options.onlyKnownSources,
        }) then
            local row = BuildModifierRow(modifier, true)
            if row and row.text and row.text ~= "" and not seen[row.text] then
                seen[row.text] = true
                table.insert(rows, row)
            end
        end
    end

    return rows
end

function U.GetGroupSourceModifierRows(group)
    local rows = {}
    local seen = {}

    for _, spellID in ipairs((group and group.sourceSpellIDs) or {}) do
        for _, modifier in ipairs(U.GetModifiersBySourceSpell(spellID)) do
            local row = BuildModifierRow(modifier, false)
            if row and row.text and row.text ~= "" and not seen[row.text] then
                seen[row.text] = true
                table.insert(rows, row)
            end
        end
    end

    return rows
end

function U.GetGroupAffectedBy(group)
    local result = {}
    local seen = {}

    for _, spellID in ipairs((group and group.resolvedSpellIDs) or {}) do
        for _, modifier in ipairs(U.GetAffectedBy(spellID)) do
            local effectID = modifier.effectID or 0
            if effectID > 0 and not seen[effectID] then
                seen[effectID] = true
                table.insert(result, modifier)
            end
        end
    end

    return result
end

function U.FormatAffectedBy(spellID)
    local parts = {}
    local seen = {}

    for _, modifier in ipairs(U.GetAffectedBy(spellID)) do
        local text = U.FormatModifier(modifier)
        if text and text ~= "" and not seen[text] then
            seen[text] = true
            table.insert(parts, text)
        end
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

function U.FormatGroupAffectedBy(group)
    local parts = {}
    local seen = {}

    for _, modifier in ipairs(U.GetGroupAffectedBy(group)) do
        local text = U.FormatModifier(modifier)
        if text and text ~= "" and not seen[text] then
            seen[text] = true
            table.insert(parts, text)
        end
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

function U.GetGroupSummary(group, mode)
    local rows, strongestCoefficient = U.GetGroupPvpRows(group, mode or "compact")
    local parts = {}

    for _, row in ipairs(rows) do
        if row.text and row.text ~= "" then
            table.insert(parts, row.text)
        end
    end

    if #parts == 0 then
        return nil, strongestCoefficient, rows
    end
    return table.concat(parts, ", "), strongestCoefficient, rows
end
