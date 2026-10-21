local R = require('shared.runtime')
local Names = require('avatars.nameplates')
local Motion = require('avatars.motion')
local Weapons = require('avatars.weapons')
local Buffer = require('avatars.buffer')
local Avatars = {}

function Avatars.create(config)
    config = config or {}
    local self = {peers = {}, assets = nil}
    local function destroy(peer)
        Weapons.clear(peer)
        for _, actor in ipairs(peer.parts) do
            if R.valid(actor) then actor:SetActorHiddenInGame(true); actor:K2_DestroyActor() end
        end
    end
    function self:clear()
        if next(self.peers) == nil then return end
        if self.world == R.worldKey() then for _, peer in pairs(self.peers) do destroy(peer) end end
        self.peers = {}
    end
    function self:prepare()
        local animated = config.AvatarModel ~= 'Keeper'
        local meshPath = animated and '/Game/Geometry/Targets/Humanoid_02/Knight.Knight' or '/Game/Geometry/Characters/Bunkerkeeper/Keeper.Keeper'
        local idlePath = animated and '/Game/Geometry/Targets/Humanoid_02/Animation/Humanoid_IdleKnight.Humanoid_IdleKnight' or '/Game/Geometry/Characters/Bunkerkeeper/Animations/Keeper_ThumbsUp.Keeper_ThumbsUp'
        local walkPath = animated and '/Game/Geometry/Targets/Humanoid_02/Animation/Humanoid_WalkKnight.Humanoid_WalkKnight' or nil
        local mesh, pose = LoadAsset(meshPath), LoadAsset(idlePath)
        local walk = walkPath and LoadAsset(walkPath) or nil
        assert(R.valid(mesh) and R.valid(pose), 'Lobby character assets unavailable')
        assert(R.name(mesh.Skeleton) == R.name(pose.Skeleton), 'Player animation skeleton mismatch')
        if animated then assert(R.valid(walk) and R.name(walk.Skeleton) == R.name(mesh.Skeleton), 'Walking animation skeleton mismatch') end
        local bounds = mesh:GetBounds()
        local height = bounds.BoxExtent.Z * 2
        assert(height > 20 and height < 1000, 'Unexpected character mesh dimensions')
        self.assets = {idlePath = idlePath, walkPath = walkPath, animated = animated, scale = (config.AvatarHeight or 180) / height,
            bottom = bounds.Origin.Z - bounds.BoxExtent.Z}
        return mesh, pose
    end
    function self:spawn(pawn)
        local meshAsset, idleAsset = self:prepare()
        local parts, handBone = {}, nil
        local ok, err = pcall(function()
            local world = R.world()
            local actor = world:SpawnActor(StaticFindObject('/Script/Engine.SkeletalMeshActor'),
                {X = 0, Y = 0, Z = -10000}, {Pitch = 0, Yaw = 0, Roll = 0})
            assert(R.valid(actor), 'Could not spawn lobby character')
            parts[#parts + 1] = actor
            actor:SetReplicates(false)
            actor:SetActorEnableCollision(false)
            local mesh = actor.SkeletalMeshComponent
            mesh:SetMobility(2)
            mesh:SetCollisionEnabled(0)
            mesh:SetSkeletalMeshAsset(meshAsset)
            mesh:PlayAnimation(idleAsset, self.assets.animated)
            mesh:SetPosition(0, false)
            mesh:SetPlayRate(self.assets.animated and 1 or 0)
            for _, name in ipairs({'hand_r', 'DEF-hand_R', 'mixamorig:RightHand', 'RightHand'}) do
                if mesh:GetBoneIndex(FName(name)) >= 0 then handBone = FName(name); break end
            end
            local scale = self.assets.scale
            actor:SetActorScale3D({X = scale, Y = scale, Z = scale})
            parts[#parts + 1] = Names.spawn(world, config.NameplateSize or 14)
        end)
        if not ok then destroy({parts = parts}); error(err) end
        local p, r = pawn:K2_GetActorLocation(), pawn:K2_GetActorRotation()
        return {pawn = pawn, parts = parts, position = Motion.copy(p), yaw = r.Yaw, walking = false, handBone = handBone, buffer = Buffer.create(config)}
    end
    function self:sync(roster)
        local world = R.worldKey()
        if self.world ~= world then self:clear(); self.world, self.lastTime = world, nil end
        local now = R.gameplay():GetRealTimeSeconds(R.world())
        local dt = self.lastTime and now > self.lastTime and math.min(now - self.lastTime, 0.1) or 0.016
        self.lastTime = now
        local seen = {}
        local camera = R.gameplay():GetPlayerCameraManager(R.world(), 0)
        local cameraPosition = R.valid(camera) and camera:GetCameraLocation() or nil
        for _, entry in ipairs(roster) do
            if R.valid(entry.pawn) then
                seen[entry.id] = true
                local peer = self.peers[entry.id]
                if not peer or R.name(peer.pawn) ~= R.name(entry.pawn) then
                    if peer then destroy(peer) end
                    peer = self:spawn(entry.pawn)
                    self.peers[entry.id] = peer
                end
                local p, rotation = entry.pawn:K2_GetActorLocation(), entry.pawn:K2_GetActorRotation()
                local stamp
                local stamped, value = pcall(function() return entry.pawn.ReplicatedServerLastTransformUpdateTimeStamp end)
                if stamped and type(value) == 'number' and value > 0 then stamp = value end
                local moved, velocity = pcall(function() return entry.pawn:GetVelocity() end)
                peer.buffer:push(p, rotation.Yaw, now, stamp, moved and velocity or nil)
                local target, targetYaw = peer.buffer:sample(now)
                local speed
                peer.position, peer.yaw, speed = Motion.step(peer.position, peer.yaw, target, targetYaw, dt,
                    config.SmoothingSpeed or 14, config.TeleportSnapDistance or 500)
                p = peer.position
                if self.assets.animated then
                    local walking = speed > (peer.walking and 8 or 18)
                    local mesh = peer.parts[1].SkeletalMeshComponent
                    if walking ~= peer.walking then
                        -- Lua userdata does not retain an Unreal asset across engine garbage collection.
                        -- Resolve immediately before use; the animation instance then owns the active asset.
                        local animation = LoadAsset(walking and self.assets.walkPath or self.assets.idlePath)
                        assert(R.valid(animation), 'Player animation unavailable')
                        mesh:PlayAnimation(animation, true)
                        peer.walking = walking
                    end
                    mesh:SetPlayRate(walking and math.max(0.6, math.min(speed / 140, 1.8)) or 1)
                end
                local halfHeight = 88
                local ok, capsule = pcall(function() return entry.pawn.CapsuleComponent end)
                if ok and R.valid(capsule) then halfHeight = capsule:GetScaledCapsuleHalfHeight() end
                local feet = p.Z - halfHeight
                peer.parts[1]:K2_SetActorLocationAndRotation(
                    {X = p.X, Y = p.Y, Z = feet - self.assets.bottom * self.assets.scale},
                    {Pitch = 0, Yaw = peer.yaw + (config.AvatarYawOffset or -90), Roll = 0}, false, {}, true)
                local feetPosition = {X = p.X, Y = p.Y, Z = feet}
                local grip = peer.handBone and peer.parts[1].SkeletalMeshComponent:GetSocketLocation(peer.handBone) or nil
                if not self.preferences or self.preferences.ShowWeapons then Weapons.sync(peer, entry.gear or '', feetPosition, peer.yaw, grip, entry.handling)
                elseif peer.gear then Weapons.clear(peer) end
                peer.parts[2]:SetActorHiddenInGame(self.preferences and not self.preferences.ShowNames or false)
                local label = entry.name .. (entry.away and ' [Away]' or (entry.ready and ' [Ready]' or ''))
                if cameraPosition and (not self.preferences or self.preferences.ShowDistances) then
                    local dx, dy, dz = p.X-cameraPosition.X, p.Y-cameraPosition.Y, p.Z-cameraPosition.Z
                    label = label .. string.format(' %.0fm', math.sqrt(dx*dx+dy*dy+dz*dz)/100)
                end
                Names.update(peer.parts[2], label,
                    {X = p.X, Y = p.Y, Z = feet + (config.AvatarHeight or 180) + (config.NameplateHeight or 24)}, cameraPosition)
            end
        end
        for id, peer in pairs(self.peers) do
            if not seen[id] then destroy(peer); self.peers[id] = nil end
        end
    end
    return self
end
return Avatars
