-- TooltipEngine GeneratedData/Init.lua — AUTO-GENERATED, DO NOT EDIT
-- Build: 12.0.5.67314

TooltipEngine = TooltipEngine or {}
local T = TooltipEngine
TooltipEngineData = TooltipEngineData or {}
PvPTipData = TooltipEngineData

local function MergeTables(destination, source)
  if type(source) ~= "table" then
    return destination
  end
  destination = destination or {}
  for key, value in pairs(source) do
    if type(value) == "table" and type(destination[key]) == "table" then
      MergeTables(destination[key], value)
    else
      destination[key] = value
    end
  end
  return destination
end

function T.RegisterCompactData(name, payload)
  TooltipEngineData[name] = payload
end

function T.MergeCompactData(name, payload)
  local current = TooltipEngineData[name]
  if type(current) ~= "table" then
    current = {}
    TooltipEngineData[name] = current
  end
  MergeTables(current, payload)
end

TooltipEngineData.Build = "12.0.5.67314"
