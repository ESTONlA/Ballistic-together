local R = require('shared.runtime')
local config = require('config')
local session = require('lobby.session').create(config)
local avatars = require('avatars.proxies').create(config)
local version = '0.2.0-beta'
local queued, stopped, lastTick, lastRoster = false, false, 0, 0
local roster = {}
local worldKey = ''
session.beforeTravel = function() avatars:clear(); roster = {} end
local function run(action)
    local ok, err = pcall(action)
    if not ok then session.actionError = tostring(err); R.log('Action failed: ' .. tostring(err)) end
    return ok
end
local ui = require('ui.panel').create(config, session, run)
run(function() session:installHooks() end)

LoopAsync(config.AvatarRefreshMs or 100, function()
    if queued or stopped then return end
    queued = true
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            if not R.valid(R.world()) then return end
            local currentWorld = R.worldKey()
            if currentWorld ~= worldKey then worldKey, roster, lastRoster = currentWorld, {}, -1 end
            local now = os.time()
            if now ~= lastTick then
                lastTick = now
                session:tick()
                session.invites:tick(session)
                ui:update()
            end
            local clock = R.gameplay():GetRealTimeSeconds(R.world())
            if clock < lastRoster or clock - lastRoster >= 0.25 then
                lastRoster = clock
                session:updatePlayers()
                roster = session:roster()
            end
            if session:active() then
                avatars:sync(roster)
            else
                avatars:clear()
                roster = {}
            end
        end)
        queued = false
        if not ok then
            stopped = true
            R.log('Lobby updates stopped after an error: ' .. tostring(err))
            run(function() avatars:clear() end)
        end
    end)
end)

RegisterKeyBind(Key.F8, function() ExecuteInGameThread(function() run(function() ui:toggle() end) end) end)
RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, function() ExecuteInGameThread(function() run(function() ui:click() end) end) end)
RegisterKeyBind(Key.F10, {ModifierKey.CONTROL}, function()
    ExecuteInGameThread(function()
        run(function()
            R.log(string.format('v%s | %s | players=%d | world=%s | driver=%s | %s',
                version, session.phase, session.players, R.level(), R.name(session.transport:driver()), session.message))
            R.log('Steam invites: ' .. session.invites.message)
            R.log('Lobby metadata: ' .. session.metadata.message .. ' | local ready=' .. tostring(session.localReady))
        end)
    end)
end)
R.log('v' .. version .. ' loaded. F8 opens the two-player Steam lobby panel; Ctrl+F10 logs status.')
