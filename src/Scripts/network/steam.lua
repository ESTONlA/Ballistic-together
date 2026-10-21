local R = require('shared.runtime')
local Steam = {}
Steam.Driver = '/Script/SteamSockets.SteamSocketsNetDriver'
function Steam.validId(id)
    if type(id) ~= 'string' or #id ~= 17 or not id:match('^%d+$') then return false end
    local value = tonumber(id)
    return value and value > 76561197960265728 and value <= 76561202255233023 or false
end

function Steam.address(id, port)
    id = tostring(id or ''):match('^%s*(.-)%s*$')
    assert(Steam.validId(id), 'Enter the host public-account SteamID64 (17 digits).')
    port = tonumber(port)
    assert(port and port % 1 == 0 and port >= 1 and port <= 65535, 'Invalid Steam port')
    return 'steam.' .. id .. ':' .. tostring(port)
end

function Steam.create()
    local self = {original = nil}
    function self:configure()
        assert(R.valid(StaticFindObject(Steam.Driver)), 'This game build does not expose SteamSocketsNetDriver.')
        local definitions = R.engine().NetDriverDefinitions
        assert(#definitions <= 32, 'Unexpected net driver definition count')
        for i = 1, #definitions do
            local row = definitions[i]
            if row.DefName:ToString() == 'GameNetDriver' then
                self.original = self.original or {driver = row.DriverClassName:ToString(), fallback = row.DriverClassNameFallback:ToString()}
                row.DriverClassName = FName(Steam.Driver)
                row.DriverClassNameFallback = FName(Steam.Driver)
                assert(definitions[i].DriverClassName:ToString() == Steam.Driver, 'Steam driver configuration did not persist')
                return
            end
        end
        error('GameNetDriver definition was not found; no networking settings were changed.')
    end
    function self:restore()
        if not self.original then return end
        local definitions = R.engine().NetDriverDefinitions
        for i = 1, math.min(#definitions, 32) do
            local row = definitions[i]
            if row.DefName:ToString() == 'GameNetDriver' then
                row.DriverClassName = FName(self.original.driver)
                row.DriverClassNameFallback = FName(self.original.fallback)
            end
        end
        self.original = nil
    end
    function self:driver()
        local world = R.world()
        return R.valid(world) and world.NetDriver or nil
    end
    function self:isSteam()
        return R.name(self:driver()):find('SteamSocketsNetDriver', 1, true) ~= nil
    end
    return self
end
return Steam
