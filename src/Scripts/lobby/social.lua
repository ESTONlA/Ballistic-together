local Text = require('shared.text')
local Protocol = require('network.protocol')
local Social = {}
local generation = 0
function Social.create(clock)
    clock = clock or os.time
    local self = {history = {}, outgoing = {}, nextId = 0, seen = 0, sequence = 0, away = false, markerId = 0}
    function self:reset()
        generation = generation + 1
        self.nonce = tostring(clock()) .. '_' .. generation
        self.history, self.outgoing, self.nextId, self.seen, self.sequence = {}, {}, 0, 0, 0
        self.remoteNonce, self.remoteSequence, self.remoteMarker, self.remoteRange, self.remoteCountdown = nil, nil, nil, nil, 0
        self.retired = {}; self.lastSend = nil
        self.unread = 0
        self.ownGear, self.ownGearRevision, self.acknowledgedGear = nil, 0, 0
        self.lastSemantic, self.lastSnapshot = nil, nil
        self.remoteGear, self.remoteGearRevision, self.retiredOrder = '', 0, {}
        self.marker, self.markerId, self.away = nil, 0, false
    end
    function self:add(name, message, system)
        self.history[#self.history + 1] = {name = Text.clean(name, 64), text = Text.clean(message, 180), system = system == true, at = clock()}
        if #self.history > 40 then table.remove(self.history, 1) end
        local entry = self.history[#self.history]
        if self.onNotice then self.onNotice((system and '' or entry.name .. ': ') .. entry.text) end
    end
    function self:send(message, name)
        message = Text.clean(message, 180)
        assert(message ~= '', 'Type a message first.')
        assert(#self.outgoing < 8, 'Messages are waiting for your friend. Try again once the connection catches up.')
        assert(not self.lastSend or clock() - self.lastSend >= 1, 'Wait a moment before sending again.')
        self.lastSend = clock(); self.nextId = self.nextId + 1
        self.outgoing[#self.outgoing + 1] = self.nextId .. '|' .. message
        self:add(name or 'You', message)
    end
    function self:mark(position, level)
        self.markerId = self.markerId + 1
        self.marker = position and {X = position.X, Y = position.Y, Z = position.Z, level = level, untilTime = clock() + 25} or nil
    end
    function self:fields(range, countdown, gear, ready)
        gear = gear or ''
        if #gear > 20000 then gear = '' end
        if self.ownGear ~= gear then
            self.ownGear, self.ownGearRevision = gear, self.ownGearRevision + 1
        end
        local marker, body = self.marker, ''
        if marker and marker.untilTime > clock() then
            body = string.format('%s,%.1f,%.1f,%.1f,%d', marker.level, marker.X, marker.Y, marker.Z, marker.untilTime - clock())
        end
        local fields = {self.nonce, 0, range or '', countdown or 0, self.markerId, body, self.away and '1' or '0',
            table.concat(self.outgoing, '\n'), self.acknowledgedGear < self.ownGearRevision and gear or '',
            self.ownGearRevision, self.remoteGearRevision, self.seen, self.remoteNonce or '', self.acknowledgedGear < self.ownGearRevision and '1' or '0'}
        local semantic = Protocol.encode(fields) .. ':' .. tostring(ready == true)
        if semantic ~= self.lastSemantic or not self.lastSnapshot or clock() < self.lastSnapshot or clock() - self.lastSnapshot >= 1 then
            self.sequence = (self.sequence + 1) % 10000000
            self.lastSemantic, self.lastSnapshot = semantic, clock()
        end
        fields[2] = self.sequence
        return fields
    end
    function self:receive(packet, name, isHost, muted)
        if self.retired[packet.nonce] then return false end
        if packet.nonce ~= self.remoteNonce then
            if self.remoteNonce then
                self.retired[self.remoteNonce] = true; self.retiredOrder[#self.retiredOrder + 1] = self.remoteNonce
                if #self.retiredOrder > 32 then self.retired[table.remove(self.retiredOrder, 1)] = nil end
            end
            self.remoteNonce, self.seen, self.remoteSequence, self.remoteMarkerId = packet.nonce, 0, nil, nil
            self.remoteMarker, self.remoteRange = nil, nil
            self.remoteGear, self.remoteGearRevision, self.acknowledgedGear = '', 0, 0
            self.newChatStream = true
        end
        if self.remoteSequence and not Protocol.newer(packet.sequence, self.remoteSequence) then return false end
        self.remoteSequence = packet.sequence
        if packet.ackNonce == self.nonce then
            self.acknowledgedGear = math.max(self.acknowledgedGear, math.min(packet.gearAck, self.ownGearRevision))
            local pending = {}
            for _, line in ipairs(self.outgoing) do
                if tonumber(line:match('^(%d+)|')) > math.min(packet.chatAck, self.nextId) then pending[#pending + 1] = line end
            end
            self.outgoing = pending
        end
        if packet.gearIncluded and packet.gearRevision > self.remoteGearRevision then
            self.remoteGear, self.remoteGearRevision = packet.gear, packet.gearRevision
        end
        if isHost then self.remoteRange, self.remoteCountdown = packet.range, packet.countdown end
        for line in packet.chat:gmatch('[^\n]+') do
            local id, message = line:match('^(%d+)|(.+)$'); id = tonumber(id)
            if id and self.newChatStream then self.seen = id - 1; self.newChatStream = false end
            if id and id == self.seen + 1 and id <= 10000000 and #message <= 180 then
                self.seen = id
                if not muted then self:add(name, Text.clean(message, 180)); self.unread = self.unread + 1 end
            end
        end
        if packet.markerId ~= self.remoteMarkerId then
            self.remoteMarkerId, self.remoteMarker = packet.markerId, nil
            local level, x, y, z, ttl = packet.marker:match('^([%w_]+),([%d.-]+),([%d.-]+),([%d.-]+),(%d+)$')
            x, y, z, ttl = tonumber(x), tonumber(y), tonumber(z), tonumber(ttl)
            if level and x and y and z and ttl and ttl <= 25 and math.abs(x) < 10000000 and math.abs(y) < 10000000 and math.abs(z) < 10000000 then
                self.remoteMarker = {X = x, Y = y, Z = z, level = level, untilTime = clock() + ttl, name = Text.clean(name, 64)}
            end
        end
        return true
    end
    self:reset()
    return self
end
return Social
