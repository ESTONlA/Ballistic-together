local R = require('shared.runtime')
local Steam = require('network.steam')
local Invites = require('network.invites')
local Metadata = require('network.metadata')
local Ranges = require('lobby.ranges')
local Weapons = require('avatars.weapons')
local Session = {}

function Session.create(config)
    assert(config.MaxPlayers == 2 and config.Port == 7777, 'This lobby preview supports two players on Steam port 7777.')
    local self = {phase = 'idle', message = 'Not connected', players = 0, transport = Steam.create(), invites = Invites.create(),
        metadata = Metadata.create(), localReady = false, playerList = {}, hooks = {}, since = 0, ranges = {}, rangeIndex = 1}
    function self:set(phase, message)
        if self.phase ~= phase or self.message ~= message then R.log(phase .. ': ' .. message) end
        self.phase, self.message = phase, message
    end
    function self:host()
        assert(self.phase == 'idle' or self.phase == 'failed', 'Leave the current lobby first.')
        self.transport:configure()
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
        if self.beforeTravel then self.beforeTravel() end
        self.transport:configure()
        self.since = os.time()
        self:set('joining', 'Connecting to the host over Steam...')
        R.player():ClientTravel(address, 0, false, {A = 0, B = 0, C = 0, D = 0})
    end
    function self:leave()
        if self.beforeTravel then self.beforeTravel() end
        self.invites:clear()
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
    end
    function self:allReady()
        if #self.playerList == 0 then return false end
        for _, row in ipairs(self.playerList) do if row.ready ~= true then return false end end
        return true
    end
    function self:cycleRange()
        assert(self:isHost(), 'Only the host can select a range.')
        if #self.ranges > 0 then self.rangeIndex = self.rangeIndex % #self.ranges + 1 end
    end
    function self:travel(destination)
        assert(self:isHost(), 'Only the host can move the lobby.')
        assert(destination and Ranges.maps[destination.id] == destination.path, 'Unsupported range destination.')
        if destination.id ~= 'Bunker_Main' then
            assert(self:allReady(), 'Every player must be ready before entering the range.')
            local unlocked = false
            for _, range in ipairs(self.ranges) do if range.id == destination.id then unlocked = true end end
            assert(unlocked, 'This range is not unlocked by the host.')
        end
        local lib = StaticFindObject('/Script/AdvancedSessions.Default__AdvancedSessionsLibrary')
        if self.beforeTravel then self.beforeTravel() end
        assert(lib:ServerTravel(R.world(), destination.path .. '?listen', true, false), 'Server travel was rejected by the game.')
        self.since, self.localReady = os.time(), false
        self:set('travelling', 'Loading ' .. destination.name .. ' for all players...')
    end
    function self:startRange() self:travel(self.ranges[self.rangeIndex]) end
    function self:returnToBunker() self:travel({id = 'Bunker_Main', path = config.LobbyMap, name = 'Bunker'}) end
    function self:kickGuest()
        assert(self:isHost(), 'Only the host can remove a player.')
        for _, row in ipairs(self.playerList) do
            if not row.isLocal and R.valid(row.controller) then
                local lib = StaticFindObject('/Script/AdvancedSessions.Default__AdvancedSessionsLibrary')
                assert(lib:KickPlayer(R.world(), row.controller, FText('Removed by the lobby host.')), 'The game rejected the kick request.')
                return
            end
        end
        error('No connected guest is available.')
    end
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
    function self:updatePlayers()
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
            for i = 1, #states do
                local state = states[i]
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
        self.metadata:tick(self, rows, ok and gear or '')
        for _, row in ipairs(rows) do
            local remote = self.metadata.remote
            row.ready = row.isLocal and self.localReady or (remote and remote.id == row.steamId and remote.ready == true) or false
            row.gear = not row.isLocal and remote and remote.id == row.steamId and remote.gear or ''
        end
        table.sort(rows, function(a, b) if a.isLocal ~= b.isLocal then return a.isLocal end return a.id < b.id end)
        self.playerList = rows
    end
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
    return self
end
return Session
