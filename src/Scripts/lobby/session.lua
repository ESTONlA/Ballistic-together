local R = require('shared.runtime')
local Steam = require('network.steam')
local Invites = require('network.invites')
local Metadata = require('network.metadata')
local Ranges = require('lobby.ranges')
local Social = require('lobby.social')
local Countdown = require('lobby.countdown')
local Preferences = require('shared.preferences')
local Session = {}

function Session.create(config)
    assert(config.MaxPlayers == 2 and config.Port == 7777, 'This lobby preview supports two players on Steam port 7777.')
    local self = {phase = 'idle', message = 'Not connected', players = 0, transport = Steam.create(), invites = Invites.create(),
        metadata = Metadata.create(), social = Social.create(), countdown = Countdown.create(), preferences = Preferences.create(config),
        localReady = false, playerList = {}, hooks = {}, since = 0, ranges = {}, rangeIndex = 1}
    function self:set(phase, message)
        if self.phase ~= phase or self.message ~= message then R.log(phase .. ': ' .. message); self.social:add('', message, true) end
        self.phase, self.message = phase, message
    end
    function self:host()
        assert(self.phase == 'idle' or self.phase == 'failed', 'Leave the current lobby first.')
        self.transport:configure()
        self.social:reset(); self.countdown:cancel(); self.members = nil
        self.localReady, self.hostId = false, nil
        if self.beforeTravel then self.beforeTravel() end
        self.since = os.time()
        self:set('hosting_pending', 'Opening the bunker over Steam...')
        R.gameplay():OpenLevel(R.player(), FName(config.LobbyMap), true, 'listen')
    end
    function self:join(id)
        assert(self.phase == 'idle' or self.phase == 'failed', 'Leave the current lobby first.')
        local address = Steam.address(id, config.Port)
        self.hostId, self.localReady = address:match('^steam%.(%d+):'), false
        self.preferences:remember(self.hostId)
        self.social:reset(); self.countdown:cancel(); self.members = nil
        if self.beforeTravel then self.beforeTravel() end
        self.transport:configure()
        self.since = os.time()
        self:set('joining', 'Connecting to the host over Steam...')
        R.player():ClientTravel(address, 0, false, {A = 0, B = 0, C = 0, D = 0})
    end
    function self:leave()
        if self.beforeTravel then self.beforeTravel() end
        self.invites:clear()
        self.countdown:cancel(); self.social:mark(nil); self.members = nil
        self.transport:restore()
        self.players = 0
        self.playerList, self.localReady, self.hostId = {}, false, nil
        self:set('idle', 'Left the lobby')
        R.gameplay():OpenLevel(R.player(), FName('/Game/Maps/BallisticMain'), true, '')
    end
    function self:active() return self.phase == 'hosting' or self.phase == 'connected' end
    function self:isHost() return self.phase == 'hosting' end
    function self:invite() self.invites:open(self) end
    function self:ready()
        assert(self:active(), 'Connect before changing ready status.')
        self.localReady = not self.localReady
        if self.localReady then self.social.away = false else self.countdown:cancel() end
        for _, row in ipairs(self.playerList) do if row.isLocal then row.ready, row.away = self.localReady, self.social.away end end
        self.social:add('', self.localReady and 'You are ready.' or 'You are not ready.', true)
    end
    function self:allReady()
        if not self.localReady then return false end
        if #self.playerList == 0 then return false end
        if #self.playerList ~= self.players then return false end
        if self.players > 1 and (not self.metadata.remote or self.metadata.mismatch) then return false end
        for _, row in ipairs(self.playerList) do if row.ready ~= true then return false end end
        return true
    end
    require('lobby.travel').install(self, config)
    function self:tick()
        if self.phase == 'idle' or self.phase == 'failed' then return end
        local driver = self.transport:driver()
        if R.valid(driver) then
            if not self.transport:isSteam() then
                self:set('failed', 'The connection used a non-Steam driver. Leave and restart; no IP fallback is supported.')
                return
            end
            if not Ranges.supported(R.level()) then
                if os.time() - self.since > 90 then self:set('failed', 'Connected outside a supported multiplayer map.') end
                return
            end
            local server = not R.valid(driver.ServerConnection)
            self:set(server and 'hosting' or 'connected', server and 'Steam lobby open' or 'Connected to Steam host')
            local world = R.world()
            if self.lastWorld ~= R.worldKey() then
                self.lastWorld, self.localReady = R.worldKey(), false
                self.ranges = Ranges.list()
                self.rangeIndex = math.min(self.rangeIndex, math.max(1, #self.ranges))
            end
            local gs = R.gameplay():GetGameState(world)
            self.players = R.valid(gs) and #gs.PlayerArray or 0
            if server then
                local mode = R.gameplay():GetGameMode(world)
                if R.valid(mode) and R.valid(mode.GameSession) then mode.GameSession.MaxPlayers = config.MaxPlayers end
            end
        elseif self:active() then
            self.since = os.time()
            self:set('travelling', 'Waiting for the Steam connection after travel...')
        elseif os.time() - self.since > 90 then
            self:set('failed', 'Steam connection was not established. Check the log and launch through Steam.')
        end
    end
    function self:updatePlayers(skipMetadata) require('lobby.players').update(self, skipMetadata) end
    function self:roster()
        if not self:active() then return {} end
        local peers = {}
        for _, row in ipairs(self.playerList) do if not row.isLocal and R.valid(row.pawn) then peers[#peers + 1] = row end end
        return peers
    end
    function self:installHooks()
        for _, event in ipairs({'HandleNetworkError', 'HandleTravelError'}) do
            local path = '/Script/Engine.GameInstance:' .. event
            local pre, post = RegisterHook(path, function(_, failure)
                if self.phase ~= 'idle' then self:set('failed', event .. ' (' .. tostring(failure:get()) .. '). See UE4SS.log.') end
            end)
            self.hooks[event] = {pre, post}
        end
    end
    function self:reconnect()
        assert(self.phase == 'idle' or self.phase == 'failed', 'Leave the current session first.')
        assert(Steam.validId(self.preferences.lastHost), 'No previous host saved yet.')
        self:join(self.preferences.lastHost)
    end
    function self:chat(message)
        assert(self:active(), 'Join a session before chatting.')
        self.social:send(message, 'You')
    end
    function self:away()
        assert(self:active(), 'Join a session first.')
        self.social.away = not self.social.away
        self.localReady = false; self.countdown:cancel()
        for _, row in ipairs(self.playerList) do if row.isLocal then row.ready, row.away = false, self.social.away end end
        self.social:add('', self.social.away and 'You are away.' or 'You are back.', true)
    end
    function self:mark(clear)
        assert(self:active(), 'Join a session before placing a marker.')
        local pawn = R.player().Pawn
        assert(clear or R.valid(pawn), 'Your player is not ready.')
        self.social:mark(not clear and pawn:K2_GetActorLocation() or nil, R.level())
        self.social:add('', clear and 'Rally marker cleared.' or 'Rally marker placed for 25 seconds.', true)
    end
    function self:featuresTick()
        if not self:active() then self.countdown:cancel(); return end
        if not self:isHost() and self.metadata.remote then
            local range = self.social.remoteRange
            if self.selectedByHost and self.selectedByHost ~= range then
                self.localReady = false
                self.social:add('', 'The host changed the range. Ready up again.', true)
            end
            self.selectedByHost = range
        end
        if self:isHost() then
            local range = self.ranges[self.rangeIndex]
            local action, destination = self.countdown:step(self:allReady(), self.players, range and range.id)
            if action == 'travel' then self:travel(destination)
            elseif action == 'cancelled' then self.social:add('', 'Range countdown cancelled.', true) end
        end
    end
    function self:copyId()
        self.invites:initialize()
        local storage = require('shared.storage')
        local copy = assert(package.loadlib(storage.directory .. 'BallisticSteamInvites.dll', 'bt_copyid'), 'Update the native bridge.')
        copy()
        self.social:add('', storage.read('clipboard-status.txt'), true)
    end
    return self
end
return Session
