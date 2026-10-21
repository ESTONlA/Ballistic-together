local R = require('shared.runtime')
local Storage = require('shared.storage')
local Diagnostics = {}
function Diagnostics.export(session)
    local lines = {'Ballistic Together ' .. require('release').version .. ' build ' .. (require('release').build or 1), os.date('!%Y-%m-%d %H:%M:%S UTC'),
        'State: ' .. session.phase, 'Map: ' .. R.level(), 'Players: ' .. session.players,
        'Steam driver: ' .. R.name(session.transport:driver()), 'Invites: ' .. session.invites.message,
        'Lobby data: ' .. session.metadata.message, 'Status: ' .. session.message,
        'Last error: ' .. tostring(session.actionError or 'none')}
    local quality = session.metadata.quality
    if quality then
        lines[#lines + 1] = string.format('Peer data age: %.2fs | accepted=%d | skipped app revisions=%d',
            quality:age(R.gameplay():GetRealTimeSeconds(R.world())), quality.received, quality.skipped)
    end
    lines[#lines + 1] = 'Auxiliary Steam channel counters (separate from native player movement):\n' .. Storage.read('lobby-network.txt', 1024)
    local g=session.gameplay
    if g and g.round then
        lines[#lines+1]=g:summary()
        lines[#lines+1]=string.format('Range stream: epoch=%s queued=%d received=%d targetAck=%d targets=%d peerTargets=%d',g.epoch,#g.journal.pending,g.journal.seen,g.batchAck,#g.targets.order,g.remoteCount)
        lines[#lines+1]=string.format('Clock samples=%d rtt=%.3f offset=%.3f | round phase=%s reason=%s',g.clock.samples,g.clock.rtt or 0,g.clock.offset,g.round.phase,g.round.reason)
        lines[#lines+1]=string.format('Live events: local shots=%d local hits=%d peer shots=%d peer hits=%d timing rejected=%d audio=%d',g.metrics.localShots,g.metrics.localHits,g.metrics.peerShots,g.metrics.peerHits,g.metrics.rejectedTime,g.metrics.audio)
    end
    for i, row in ipairs(session.playerList) do
        lines[#lines + 1] = string.format('Player %d: local=%s ping=%.0f ready=%s', i, tostring(row.isLocal), row.ping or 0, tostring(row.ready))
    end
    Storage.write('diagnostics.txt', table.concat(lines, '\n') .. '\n')
    return Storage.directory .. 'diagnostics.txt'
end
return Diagnostics
