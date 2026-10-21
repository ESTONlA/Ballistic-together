local R = require('shared.runtime')
local Names = require('avatars.nameplates')
local Markers = {}
function Markers.create(session)
    local self = {actors = {}}
    function self:clear()
        if self.world == R.worldKey() then
            for _, actor in pairs(self.actors) do if R.valid(actor) then actor:K2_DestroyActor() end end
        end
        self.actors = {}
    end
    function self:update()
        if self.world ~= R.worldKey() then self:clear(); self.world = R.worldKey() end
        if not session:active() or not session.preferences.values.ShowMarkers then self:clear(); return end
        local camera = R.gameplay():GetPlayerCameraManager(R.world(), 0)
        if not R.valid(camera) then return end
        local position = camera:GetCameraLocation()
        local markers = {session.social.marker or false, session.metadata.remote and session.social.remoteMarker or false}
        for i = 1, 2 do
            local marker = markers[i]
            if marker and marker.level == R.level() and marker.untilTime > os.time() then
                if not R.valid(self.actors[i]) then self.actors[i] = Names.spawn(R.world(), 20) end
                local dx, dy, dz = marker.X - position.X, marker.Y - position.Y, marker.Z - position.Z
                self.actors[i]:SetActorHiddenInGame(dx*dx + dy*dy + dz*dz < 250*250)
                local label = (i == 1 and 'Your rally point' or (marker.name or 'Friend') .. "'s rally point") .. string.format(' [%.0fm]', math.sqrt(dx*dx + dy*dy + dz*dz) / 100)
                Names.update(self.actors[i], label, {X = marker.X, Y = marker.Y, Z = marker.Z + 90}, position)
            elseif R.valid(self.actors[i]) then self.actors[i]:K2_DestroyActor(); self.actors[i] = nil end
        end
    end
    return self
end
return Markers
