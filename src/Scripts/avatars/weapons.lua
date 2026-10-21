local R = require('shared.runtime')
local Weapons = {}
local function path(mesh) return R.name(mesh):match('^StaticMesh (/Game/Geometry/Weapons/[%w_/%.-]+)$') end
local function validPath(value) return #value < 240 and value:match('^/Game/Geometry/Weapons/[%w_/%.-]+$') ~= nil end
local mathlib = function() return StaticFindObject('/Script/Engine.Default__KismetMathLibrary') end
function Weapons.equipped(pawn)
    if not R.valid(pawn) then return nil end
    local ok, weapon = pcall(function() return pawn.EquippedWeapon end)
    return ok and R.valid(weapon) and weapon or nil
end
function Weapons.capture(weapon)
    if not R.valid(weapon) then return '' end
    local actors, lines = {weapon}, {}
    local children = {}; weapon:GetAllChildActors(children, true)
    for i = 1, math.min(#children, 64) do actors[#actors + 1] = children[i] end
    local root = weapon:GetTransform()
    local seen = {}
    for _, actor in ipairs(actors) do
        local components = actor:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.StaticMeshComponent'))
        local candidates = {}
        for _, field in ipairs({'WeaponBody', 'StaticMeshComponent', 'RootComponent'}) do
            local ok, component = pcall(function() return actor[field] end)
            if ok and R.valid(component) then candidates[#candidates + 1] = component end
        end
        for i = 1, math.min(#components, 64) do candidates[#candidates + 1] = components[i] end
        for _, component in ipairs(candidates) do
            local ok, mesh = pcall(function() return component.StaticMesh end)
            local asset = ok and path(mesh) or nil
            if asset and not seen[R.name(component)] and #lines < 32 then
                seen[R.name(component)] = true
                local p = mathlib():InverseTransformLocation(root, component:K2_GetComponentLocation())
                local r = mathlib():InverseTransformRotation(root, component:K2_GetComponentRotation())
                local s = component:K2_GetComponentScale()
                lines[#lines + 1] = string.format('%s|%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f',
                    asset, p.X, p.Y, p.Z, r.Pitch, r.Yaw, r.Roll, s.X, s.Y, s.Z)
            end
        end
    end
    return table.concat(lines, '\n')
end
function Weapons.decode(payload)
    if #payload > 23000 then return nil end
    local parts = {}
    for line in payload:gmatch('[^\n]+') do
        local asset, values = line:match('^([^|]+)|(.+)$')
        if not asset or not validPath(asset) or #parts >= 32 then return nil end
        local numbers = {}
        for value in values:gmatch('[^,]+') do
            local number = tonumber(value)
            if not number or number ~= number or math.abs(number) > 1000 then return nil end
            numbers[#numbers + 1] = number
        end
        if #numbers ~= 9 then return nil end
        if numbers[7] <= 0 or numbers[8] <= 0 or numbers[9] <= 0 or numbers[7] > 10 or numbers[8] > 10 or numbers[9] > 10 then return nil end
        parts[#parts + 1] = {path = asset, p = {X = numbers[1], Y = numbers[2], Z = numbers[3]},
            r = {Pitch = numbers[4], Yaw = numbers[5], Roll = numbers[6]}, s = {X = numbers[7], Y = numbers[8], Z = numbers[9]}}
    end
    return parts
end
function Weapons.clear(peer)
    for _, part in ipairs(peer.weaponParts or {}) do if R.valid(part.actor) then part.actor:SetActorHiddenInGame(true); part.actor:K2_DestroyActor() end end
    peer.weaponParts, peer.gear = {}, nil
end
function Weapons.sync(peer, payload, position, yaw, grip)
    payload = payload or ''
    if peer.gear ~= payload then
        Weapons.clear(peer)
        peer.gear = payload
        local parts = Weapons.decode(payload)
        if parts then
            for _, part in ipairs(parts) do
                local mesh = LoadAsset(part.path)
                if R.valid(mesh) and R.name(mesh:GetClass()) == 'Class /Script/Engine.StaticMesh' then
                    local actor = R.world():SpawnActor(StaticFindObject('/Script/Engine.StaticMeshActor'),
                        {X = 0, Y = 0, Z = -10000}, {Pitch = 0, Yaw = 0, Roll = 0})
                    if R.valid(actor) then
                        part.actor = actor
                        peer.weaponParts[#peer.weaponParts + 1] = part
                        actor:SetReplicates(false); actor:SetActorEnableCollision(false); actor:SetMobility(2)
                        actor.StaticMeshComponent:SetCollisionEnabled(0); actor.StaticMeshComponent:SetStaticMesh(mesh)
                        actor:SetActorScale3D(part.s)
                    end
                end
            end
        end
    end
    local angle = math.rad(yaw)
    for _, part in ipairs(peer.weaponParts or {}) do
        local x, y = part.p.X + (grip and 8 or 28), part.p.Y + (grip and 0 or 10)
        local origin = grip or position
        local p = {X = origin.X + x * math.cos(angle) - y * math.sin(angle),
            Y = origin.Y + x * math.sin(angle) + y * math.cos(angle), Z = origin.Z + (grip and 0 or 124) + part.p.Z}
        local r = mathlib():ComposeRotators(part.r, {Pitch = 0, Yaw = yaw, Roll = 0})
        part.actor:K2_SetActorLocationAndRotation(p, r, false, {}, true)
    end
end
return Weapons
