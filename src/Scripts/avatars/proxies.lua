local R = require('shared.runtime')
local Names = require('avatars.nameplates')
local Avatars = {}

function Avatars.create(config)
    config = config or {}
    local self = {peers = {}, assets = nil}
    local function destroy(peer)
        for _, actor in ipairs(peer.parts) do
            if R.valid(actor) then actor:SetActorHiddenInGame(true); actor:K2_DestroyActor() end
        end
    end
    function self:clear()
        for _, peer in pairs(self.peers) do destroy(peer) end
        self.peers = {}
    end
    function self:prepare()
        if self.assets and R.valid(self.assets.mesh) and R.valid(self.assets.pose) then return end
        local mesh = LoadAsset('/Game/Geometry/Characters/Bunkerkeeper/Keeper.Keeper')
        local pose = LoadAsset('/Game/Geometry/Characters/Bunkerkeeper/Animations/Keeper_ThumbsUp.Keeper_ThumbsUp')
        assert(R.valid(mesh) and R.valid(pose), 'Lobby character assets unavailable')
        local bounds = mesh:GetBounds()
        local height = bounds.BoxExtent.Z * 2
        assert(height > 20 and height < 1000, 'Unexpected character mesh dimensions')
        self.assets = {mesh = mesh, pose = pose, scale = (config.AvatarHeight or 180) / height,
            bottom = bounds.Origin.Z - bounds.BoxExtent.Z}
    end
    function self:spawn(pawn)
        self:prepare()
        local parts = {}
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
            mesh:SetSkeletalMeshAsset(self.assets.mesh)
            mesh:PlayAnimation(self.assets.pose, false)
            mesh:SetPosition(0, false)
            mesh:SetPlayRate(0)
            local scale = self.assets.scale
            actor:SetActorScale3D({X = scale, Y = scale, Z = scale})
            parts[#parts + 1] = Names.spawn(world, config.NameplateSize or 14)
        end)
        if not ok then destroy({parts = parts}); error(err) end
        return {pawn = pawn, parts = parts}
    end
    function self:sync(roster)
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
                local halfHeight = 88
                local ok, capsule = pcall(function() return entry.pawn.CapsuleComponent end)
                if ok and R.valid(capsule) then halfHeight = capsule:GetScaledCapsuleHalfHeight() end
                local feet = p.Z - halfHeight
                peer.parts[1]:K2_SetActorLocationAndRotation(
                    {X = p.X, Y = p.Y, Z = feet - self.assets.bottom * self.assets.scale},
                    {Pitch = 0, Yaw = rotation.Yaw + (config.AvatarYawOffset or -90), Roll = 0}, false, {}, true)
                Names.update(peer.parts[2], entry.name,
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
