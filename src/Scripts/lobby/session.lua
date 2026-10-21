local R = require('shared.runtime')
local Steam = require('network.steam')
local Invites = require('network.invites')
local Session = {}

function Session.create(config)
    assert(config.MaxPlayers == 2 and config.Port == 7777, 'This lobby preview supports two players on Steam port 7777.')
    local self = {phase = 'idle', message = 'Not connected', players = 0, transport = Steam.create(), invites = Invites.create(), hooks = {}, since = 0}
    function self:set(phase, message)
        if self.phase ~= phase or self.message ~= message then R.log(phase .. ': ' .. message) end
        self.phase, self.message = phase, message
    end
    function self:host()
        assert(self.phase == 'idle' or self.phase == 'failed', 'Leave the current lobby first.')
        self.transport:configure()
        self.since = os.time()
        self:set('hosting_pending', 'Opening the bunker over Steam...')
        R.gameplay():OpenLevel(R.player(), FName(config.LobbyMap), true, 'listen')
    end
    function self:join(id)
        assert(self.phase == 'idle' or self.phase == 'failed', 'Leave the current lobby first.')
        local address = Steam.address(id, config.Port)
        self.transport:configure()
        self.since = os.time()
        self:set('joining', 'Connecting to the host over Steam...')
        R.player():ClientTravel(address, 0, false, {A = 0, B = 0, C = 0, D = 0})
    end
    function self:leave()
        self.invites:clear()
        self.transport:restore()
        self.players = 0
        self:set('idle', 'Left the lobby')
        R.gameplay():OpenLevel(R.player(), FName('/Game/Maps/BallisticMain'), true, '')
    end
    function self:active() return self.phase == 'hosting' or self.phase == 'connected' end
    function self:invite() self.invites:open(self) end
    function self:tick()
        if self.phase == 'idle' or self.phase == 'failed' then return end
        local driver = self.transport:driver()
        if R.valid(driver) then
            if not self.transport:isSteam() then
                self:set('failed', 'The connection used a non-Steam driver. Leave and restart; no IP fallback is supported.')
                return
            end
            if not R.level():find('Bunker_Main', 1, true) then
                if os.time() - self.since > 45 then self:set('failed', 'Connected outside the bunker; lobby startup did not complete.') end
                return
            end
            local server = not R.valid(driver.ServerConnection)
            self:set(server and 'hosting' or 'connected', server and 'Steam lobby open' or 'Connected to Steam host')
            local world = R.world()
            local gs = R.gameplay():GetGameState(world)
            self.players = R.valid(gs) and #gs.PlayerArray or 0
            if server then
                local mode = R.gameplay():GetGameMode(world)
                if R.valid(mode) and R.valid(mode.GameSession) then mode.GameSession.MaxPlayers = config.MaxPlayers end
            end
        elseif os.time() - self.since > 45 or self:active() then
            self:set('failed', 'Steam connection was not established. Check the log and launch through Steam.')
        end
    end
    function self:roster()
        if not self:active() then return {} end
        local gs = R.gameplay():GetGameState(R.world())
        if not R.valid(gs) then return {} end
        local states, peers = gs.PlayerArray, {}
        assert(#states <= 64, 'Unexpected lobby player count')
        for i = 1, #states do
            local state = states[i]
            if R.valid(state) then
                local pawn = state:GetPawn()
                if R.valid(pawn) and not pawn:IsLocallyControlled() then
                    local name = state:GetPlayerName()
                    peers[#peers + 1] = {id = R.name(state), pawn = pawn,
                        name = type(name) == 'string' and name or name:ToString()}
                end
            end
        end
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
