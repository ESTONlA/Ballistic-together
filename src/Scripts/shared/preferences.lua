local Storage = require('shared.storage')
local Steam = require('network.steam')
local Preferences = {}
local defaults = {ShowNames = true, ShowWeapons = true, ShowMarkers = true, ShowHud = true, ShowDistances = true, ChatMuted = false, RemoteAudio = true}
function Preferences.create(config)
    local self = {values = {}, lastHost = ''}
    for key, value in pairs(defaults) do
        if type(config[key]) == 'boolean' then self.values[key] = config[key] else self.values[key] = value end
    end
    for key, value in Storage.read('preferences.cfg', 2048):gmatch('([%w]+)=([^\r\n]*)') do
        if defaults[key] ~= nil and (value == '0' or value == '1') then self.values[key] = value == '1'
        elseif key == 'LastHost' and Steam.validId(value) then self.lastHost = value end
    end
    function self:save()
        local lines = {'LastHost=' .. self.lastHost}
        for key in pairs(defaults) do lines[#lines + 1] = key .. '=' .. (self.values[key] and '1' or '0') end
        table.sort(lines); Storage.write('preferences.cfg', table.concat(lines, '\n'))
    end
    function self:toggle(key)
        assert(defaults[key] ~= nil, 'Unknown preference')
        self.values[key] = not self.values[key]; self:save()
    end
    function self:remember(id) assert(Steam.validId(id)); self.lastHost = id; self:save() end
    return self
end
return Preferences
