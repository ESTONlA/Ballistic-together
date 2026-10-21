local R = require('shared.runtime')
local Ranges = {}
Ranges.maps = {Bunker_Main = '/Game/Maps/Bunker/Bunker_Main', Range_SwimmingPool = '/Game/Maps/Ranges/Range_SwimmingPool',
    Range_Tutorial_Advanced = '/Game/Maps/Ranges/Range_Tutorial_Advanced'}
function Ranges.supported(level) return Ranges.maps[level] ~= nil end
function Ranges.list()
    local result = {}
    local instance = R.gameplay():GetGameInstance(R.world())
    if not R.valid(instance) then return result end
    local unlocked, allowed = instance.UnlockedRanges, {}
    for i = 1, math.min(#unlocked, 64) do allowed[unlocked[i]:ToString()] = true end
    local data = LoadAsset('/Game/Data/Ranges/RangeData.RangeData')
    if not R.valid(data) then return result end
    local names = data:GetRowNames()
    for _, name in ipairs(names) do
        if allowed[name] then
            local row = data:FindRow(name)
            if row then
                local map = row.MapName_3_02B8F3864CDF2B67468FDD80A1766519:ToString()
                if Ranges.maps[map] and map ~= 'Bunker_Main' then
                    result[#result + 1] = {id = map, path = Ranges.maps[map], name = row.Displayname_7_3A5496184304AC387A1318B1AE6E4B3D:ToString()}
                end
            end
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end
return Ranges
