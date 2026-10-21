local Steam = require('network.steam')
local Storage = require('shared.storage')
local Protocol = require('network.protocol')
local Quality = require('network.quality')
local R = require('shared.runtime')
local Metadata = {id = require('network.identity').id}
function Metadata.create()
    local self = {remote = nil, message = 'Waiting for a Steam session', localId = nil, quality = Quality.create(3)}
    function self:tick(session, players, gear)
        if not session:active() and not self.enabled then self.remote = nil; return end
        self.enabled = session:active()
        local identity = Storage.read('identity.txt')
        self.localId = Steam.validId(identity) and identity or nil
        if not self.pump then
            self.pump = package.loadlib(Storage.directory .. 'BallisticSteamInvites.dll', 'bt_lobby')
            if not self.pump then self.message = 'Install the complete mod on both PCs.'; return end
        end
        local host = session:isHost() and self.localId or session.hostId
        local peer, name
        for _, row in ipairs(players) do if not row.isLocal then peer, name = row.steamId, row.name end end
        if not session:active() or not host then host, peer = '0', '0' end
        local peerKey = host .. ':' .. (peer or '0')
        if self.peerKey ~= peerKey then self.peerKey, self.accepted = peerKey, nil; self.quality:reset() end
        local now = R.gameplay():GetRealTimeSeconds(R.world())
        local range = session:isHost() and session.ranges[session.rangeIndex] or nil
        local payload = Protocol.encode(session.social:fields(range and range.id, session.countdown:remaining(), gear or '', session.localReady))
        local command = string.format('%s %s %d\n%s', host, peer or '0', session.localReady and 1 or 0, payload)
        if command ~= self.lastCommand then Storage.write('lobby-out.txt', command); self.lastCommand = command end
        self.pump(); self.message = Storage.read('lobby-status.txt')
        self.remote, self.mismatch = nil, false
        local input = Storage.read('lobby-in.txt')
        local id, ready, body = input:match('^(%d+)\n([01])\n(.*)$')
        if Steam.validId(id) and id == peer then
            local packet = Protocol.decode(body)
            if packet then
                local accepted = session.social:receive(packet, name or 'Friend', not session:isHost(), session.preferences.values.ChatMuted)
                if accepted then
                    if self.acceptedNonce ~= packet.nonce then self.acceptedNonce = packet.nonce; self.quality:reset() end
                    self.quality:observe(packet.sequence, now)
                    self.accepted = {id = id, ready = ready == '1' and packet.ackNonce == session.social.nonce,
                        gear = session.social.remoteGear, away = packet.away}
                end
                if self.quality:fresh(now) then self.remote = self.accepted end
            else self.mismatch = true; self.message = 'Different mod versions. Install ' .. require('release').version .. ' on both PCs.' end
        else self.accepted = nil end
        if self.message == 'ready' and session.players > 1 and not peer then self.message = 'Waiting for the other player Steam identity.' end
        self.dataDelayed = session:active() and session.players > 1 and self.quality.received > 0 and not self.quality:fresh(now)
    end
    return self
end
return Metadata
