local R = require('shared.runtime')
local Names = {}
function Names.clean(value)
    local name = tostring(value or ''):gsub('[%c<>]', ' '):match('^%s*(.-)%s*$')
    return name ~= '' and #name <= 256 and name or 'Player'
end
function Names.spawn(world, size)
    local actor = world:SpawnActor(StaticFindObject('/Script/Engine.TextRenderActor'),
        {X = 0, Y = 0, Z = -10000}, {Pitch = 0, Yaw = 0, Roll = 0})
    assert(R.valid(actor), 'Could not create player nameplate')
    local ok, err = pcall(function()
        actor:SetReplicates(false)
        actor:SetActorEnableCollision(false)
        actor.TextRender:SetMobility(2)
        actor.TextRender:SetHorizontalAlignment(1)
        actor.TextRender:SetVerticalAlignment(1)
        actor.TextRender:SetWorldSize(size or 14)
        actor.TextRender:SetTextRenderColor({R = 175, G = 230, B = 255, A = 255})
    end)
    if not ok then actor:K2_DestroyActor(); error(err) end
    return actor
end
function Names.update(actor, name, position, camera)
    if not R.valid(actor) then return end
    actor.TextRender:SetText(FText(Names.clean(name)))
    local rotation = {Pitch = 0, Yaw = 0, Roll = 0}
    if camera then rotation = StaticFindObject('/Script/Engine.Default__KismetMathLibrary'):FindLookAtRotation(position, camera) end
    actor:K2_SetActorLocationAndRotation(position, rotation, false, {}, true)
end
return Names
