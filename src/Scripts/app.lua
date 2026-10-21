local R = require('shared.runtime')
local App = {}
function App.create(config)
    local self = {session = require('lobby.session').create(config), failures = {}, roster = {}, queued = false, world = '', lastRoster = -1, lastTick = -1}
    local session = self.session
    self.avatars = require('avatars.proxies').create(config)
    self.avatars.preferences = session.preferences.values
    self.markers = require('avatars.markers').create(session)
    self.hud = require('ui.hud').create(session)
    session.social.onNotice = function(message) self.hud:notify(message) end
    function self:action(fn)
        local ok, err = pcall(fn)
        if not ok then session.actionError = tostring(err); self.hud:notify(tostring(err)); R.log('Action: ' .. tostring(err)) end
        return ok
    end
    self.ui = require('ui.panel').create(config, session, function(fn) return self:action(fn) end)
    session.beforeTravel = function()
        self.avatars:clear(); self.markers:clear(); self.roster = {}
        if self.ui.open then self.ui:close() end
    end
    function self:guard(name, fn)
        local failure = self.failures[name]
        if failure and os.time() < failure.retry then return end
        local ok, err = pcall(fn)
        if ok then self.failures[name] = nil; return true end
        local message = tostring(err)
        if not failure or failure.message ~= message then
            R.log(name .. ': ' .. message)
            self.hud:notify(name .. ' needs attention. Use Ctrl+F10 for details.')
        end
        self.failures[name] = {retry = os.time() + 5, message = message}
        if name == 'Player visuals' then pcall(function() self.avatars:clear() end) end
    end
    function self:step()
        if not R.valid(R.world()) then return end
        local world = R.worldKey()
        if world ~= self.world then self.world, self.roster, self.lastRoster, self.failures = world, {}, -1, {} end
        local now = os.time()
        if now ~= self.lastTick then
            self.lastTick = now
            self:guard('Steam session', function() session:tick(); session.invites:tick(session) end)
        end
        local clock = R.gameplay():GetRealTimeSeconds(R.world())
        if clock < self.lastRoster or clock - self.lastRoster >= 0.25 then
            self.lastRoster = clock
            self:guard('Lobby data', function() session:updatePlayers(); session:featuresTick(); self.roster = session:roster() end)
            self:guard('Lobby menu', function() self.ui:update(); self.hud:update() end)
            self:guard('Rally markers', function() self.markers:update() end)
        end
        self:guard('Player visuals', function()
            if session:active() then self.avatars:sync(self.roster) else self.avatars:clear(); self.roster = {} end
        end)
    end
    function self:diagnostics()
        local path = require('shared.diagnostics').export(session)
        R.log('v' .. require('release').version .. ' | ' .. session.phase .. ' | ' .. R.level() .. ' | players=' .. session.players)
        R.log('Invites: ' .. session.invites.message .. ' | Lobby data: ' .. session.metadata.message)
        for name, failure in pairs(self.failures) do R.log(name .. ': ' .. failure.message) end
        R.log('Saved report: ' .. path)
        self.hud:notify('Connection report saved.')
    end
    function self:start()
        self:action(function() session:installHooks() end)
        LoopAsync(config.AvatarRefreshMs or 16, function()
            if self.queued then return end
            self.queued = true
            ExecuteInGameThread(function()
                self:guard('Update loop', function() self:step() end)
                self.queued = false
            end)
        end)
        local function bind(key, modifiers, fn)
            local callback = function() ExecuteInGameThread(function() self:action(fn) end) end
            if modifiers then RegisterKeyBind(key, modifiers, callback) else RegisterKeyBind(key, callback) end
        end
        bind(Key.F8, nil, function() self.ui:toggle() end)
        bind(Key.F8, {ModifierKey.SHIFT}, function() if session:active() then self.ui:toggle('chat') end end)
        bind(Key.F9, nil, function() session:ready(); self.hud:notify(session.localReady and 'You are ready.' or 'You are not ready.') end)
        bind(Key.F7, nil, function() session:mark(false) end)
        bind(Key.F7, {ModifierKey.SHIFT}, function() session:mark(true) end)
        bind(Key.LEFT_MOUSE_BUTTON, nil, function() self.ui:click() end)
        bind(Key.F10, {ModifierKey.CONTROL}, function() self:diagnostics() end)
        R.log('v' .. require('release').version .. ' loaded. F8 lobby / Shift+F8 chat / F9 ready / F7 rally marker.')
    end
    return self
end
return App
