local R = require('shared.runtime')
local Ranges = require('lobby.ranges')
local Travel = {}
function Travel.install(self, config)
    function self:cycleRange()
        assert(self:isHost(), 'Only the host can select a range.')
        if #self.ranges > 1 then
            self.rangeIndex = self.rangeIndex % #self.ranges + 1
            self.localReady = false; self.countdown:cancel()
            for _, row in ipairs(self.playerList) do if row.isLocal then row.ready = false end end
            self.social:add('', 'Range selected: ' .. self.ranges[self.rangeIndex].name, true)
        end
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
    function self:startRange()
        assert(self:isHost(), 'Only the host can start the countdown.')
        assert(self:allReady(), 'Every player must be ready.')
        self.countdown:start(self.ranges[self.rangeIndex], self.players)
        self.social:add('', 'Range starts in 3 seconds.', true)
    end
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
end
return Travel
