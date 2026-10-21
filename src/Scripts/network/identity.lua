local R = require('shared.runtime')
local Steam = require('network.steam')
local Metadata = {}
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
return Metadata
