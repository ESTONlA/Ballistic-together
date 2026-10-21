local H = require('UEHelpers')
local R = {}
function R.valid(object)
    if object == nil then return false end
    local ok, result = pcall(function() return object:IsValid() end)
    return ok and result
end
function R.name(object) return R.valid(object) and object:GetFullName() or '' end
function R.world()
    local viewport = H.GetGameViewportClient()
    return R.valid(viewport) and viewport:GetWorld() or CreateInvalidObject()
end
function R.player()
    local world = R.world()
    return R.valid(world) and R.gameplay():GetPlayerController(world, 0) or CreateInvalidObject()
end
function R.engine() return H.GetEngine() end
function R.gameplay() return StaticFindObject('/Script/Engine.Default__GameplayStatics') end
function R.widgets() return StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary') end
function R.level()
    local world = R.world()
    if not R.valid(world) then return '' end
    local name = R.gameplay():GetCurrentLevelName(world, true)
    return type(name) == 'string' and name or name:ToString()
end
function R.log(message) print('[BallisticTogether] ' .. tostring(message) .. '\n') end
return R
