local R = require('shared.runtime')
local Storage = require('shared.storage')
local Diagnostics = {}
function Diagnostics.export(session)
    local lines = {'Ballistic Together ' .. require('release').version, os.date('!%Y-%m-%d %H:%M:%S UTC'),
        'State: ' .. session.phase, 'Map: ' .. R.level(), 'Players: ' .. session.players,
        'Steam driver: ' .. R.name(session.transport:driver()), 'Invites: ' .. session.invites.message,
        'Lobby data: ' .. session.metadata.message, 'Status: ' .. session.message,
        'Last error: ' .. tostring(session.actionError or 'none')}
    local quality = session.metadata.quality
    if quality then
        lines[#lines + 1] = string.format('Peer data age: %.2fs | accepted=%d | skipped app revisions=%d',
            quality:age(R.gameplay():GetRealTimeSeconds(R.world())), quality.received, quality.skipped)
    end
    lines[#lines + 1] = 'Auxiliary Steam channel counters (not gameplay transport):\n' .. Storage.read('lobby-network.txt', 1024)
    for i, row in ipairs(session.playerList) do
        lines[#lines + 1] = string.format('Player %d: local=%s ping=%.0f ready=%s', i, tostring(row.isLocal), row.ping or 0, tostring(row.ready))
    end
    Storage.write('diagnostics.txt', table.concat(lines, '\n') .. '\n')
    return Storage.directory .. 'diagnostics.txt'
end
return Diagnostics
