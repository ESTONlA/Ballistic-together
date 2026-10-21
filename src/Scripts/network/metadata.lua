local R = require('shared.runtime')
local Steam = require('network.steam')
local Metadata = {}
local source = debug.getinfo(1, 'S').source:gsub('^@', ''):gsub('\\', '/')
local directory = assert(source:match('^(.*)/Scripts/network/metadata.lua$')) .. '/Native/'
local function read(name)
    local f = io.open(directory .. name, 'rb')
    if not f then return '' end
    local result = f:read(24576) or ''; f:close(); return result
end
local function write(name, value)
    local f = assert(io.open(directory .. name .. '.tmp', 'wb'))
    f:write(value); f:close()
    os.remove(directory .. name)
    assert(os.rename(directory .. name .. '.tmp', directory .. name))
end
function Metadata.id(state)
    local lib = StaticFindObject('/Script/AdvancedSessions.Default__AdvancedSessionsLibrary')
    Metadata.ids = Metadata.ids or {}
    if not Metadata.hooks then
        Metadata.hooks = {RegisterHook('/Script/AdvancedSessions.AdvancedSessionsLibrary:GetUniqueNetIDFromPlayerState', function() end,
            function(_, playerState, uniqueId)
                local ok, err = pcall(function()
                    if not Metadata.observed then Metadata.observed = true; R.log('Player Steam ID callback type: ' .. type(uniqueId:get())) end
                    local result = {}
                    lib:UniqueNetIdToString(uniqueId:get(), result)
                    local value = result.String
                    value = type(value) == 'string' and value or value:ToString()
                    if Steam.validId(value) then Metadata.ids[R.name(playerState:get())] = value end
                end)
                if not ok and not Metadata.reported then Metadata.reported = true; R.log('Player Steam ID lookup: ' .. tostring(err)) end
            end)}
    end
    local key = R.name(state)
    if not Metadata.ids[key] then lib:GetUniqueNetIDFromPlayerState(state, {}) end
    return Metadata.ids[key]
end
function Metadata.create()
    local self = {remote = nil, message = 'Waiting for a Steam session', localId = nil}
    function self:tick(session, players, gear)
        if not session:active() and not self.enabled then self.remote = nil; return end
        self.enabled = session:active()
        local identity = read('identity.txt')
        self.localId = Steam.validId(identity) and identity or nil
        if not self.pump then
            self.pump = package.loadlib(directory .. 'BallisticSteamInvites.dll', 'bt_lobby')
            if not self.pump then self.message = 'Install the matching 0.2.1-beta native bridge on both PCs.'; return end
        end
        local host = session:isHost() and self.localId or session.hostId
        local peer
        for _, row in ipairs(players) do if not row.isLocal then peer = row.steamId end end
        if not session:active() or not host then host, peer = '0', '0' end
        local command = string.format('%s %s %d\n%s', host, peer or '0', session.localReady and 1 or 0, gear or '')
        if command ~= self.lastCommand then write('lobby-out.txt', command); self.lastCommand = command end
        self.pump()
        self.message = read('lobby-status.txt')
        self.remote = nil
        local input = read('lobby-in.txt')
        local id, ready, payload = input:match('^(%d+)\n([01])\n(.*)$')
        if Steam.validId(id) and id == peer then self.remote = {id = id, ready = ready == '1', gear = payload} end
        if self.message == 'ready' and session.players > 1 and not peer then self.message = 'Waiting for the other player Steam identity.' end
    end
    return self
end
return Metadata
