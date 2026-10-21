local R = require('shared.runtime')
local Metadata = require('network.metadata')
local Weapons = require('avatars.weapons')
local Players = {}
function Players.update(self, skipMetadata)
    if not self:active() then
        self.playerList = {}
        self.metadata:tick(self, {}, '')
        return
    end
    local gs = R.gameplay():GetGameState(R.world())
    local rows, states = {}, R.valid(gs) and gs.PlayerArray or nil
    if states then
        assert(#states <= 64, 'Unexpected lobby player count')
        local pc = R.player()
        local objects = {}
        for i = 1, #states do
            local state = R.object(states[i]); if state then objects[#objects + 1] = state end
        end
        for _, state in ipairs(objects) do
            if R.valid(state) then
                local pawn = state:GetPawn()
                local isLocal = R.valid(pc) and R.name(pc.PlayerState) == R.name(state)
                local name = state:GetPlayerName()
                local ok, id = pcall(Metadata.id, state)
                rows[#rows + 1] = {state = state, id = R.name(state), pawn = pawn, isLocal = isLocal,
                    controller = state:GetPlayerController(), steamId = ok and id or nil,
                    name = type(name) == 'string' and name or name:ToString(), ping = state:GetPingInMilliseconds()}
            end
        end
    end
    local pc = R.player()
    local pawn = R.valid(pc) and pc.Pawn or nil
    local ok, gear = pcall(Weapons.capture, Weapons.equipped(pawn))
    self.currentGear = ok and gear or ''
    if not skipMetadata then self.metadata:tick(self, rows, self.currentGear) end
    for _, row in ipairs(rows) do
        local remote = self.metadata.remote
        row.ready = row.isLocal and self.localReady or (remote and remote.id == row.steamId and remote.ready == true) or false
        row.gear = not row.isLocal and remote and remote.id == row.steamId and remote.gear or ''
        row.away = row.isLocal and self.social.away or (not row.isLocal and remote and remote.away) or false
        if row.away then row.ready = false end
    end
    table.sort(rows, function(a, b) if a.isLocal ~= b.isLocal then return a.isLocal end return a.id < b.id end)
    self.playerList = rows
    local members = {}
    for _, row in ipairs(rows) do
        members[row.id] = row.name
        if not row.isLocal and self.members and not self.members[row.id] then self.social:add('', row.name .. ' joined.', true); self.localReady = false end
    end
    for id, name in pairs(self.members or {}) do if not members[id] then self.social:add('', name .. ' left.', true); self.localReady = false; self.countdown:cancel() end end
    self.members = members
end
return Players
