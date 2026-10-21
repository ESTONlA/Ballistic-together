local Protocol = {}
local magic = require('release').protocol .. '\n'
local limits = {64, 8, 64, 2, 32, 160, 2, 1800, 13000, 8, 8, 8, 64, 1, 7000}
local defaults = {[10] = '0', [11] = '0', [12] = '0', [14] = '1'}
function Protocol.encode(fields)
    local out = {magic}
    for i, limit in ipairs(limits) do
        local value = tostring(fields[i] or defaults[i] or '')
        assert(#value <= limit and not value:find('\0', 1, true), 'Lobby field exceeds its limit')
        out[#out + 1] = #value .. ':' .. value
    end
    return table.concat(out)
end
function Protocol.decode(payload)
    if type(payload) ~= 'string' or #payload > 23000 or payload:sub(1, #magic) ~= magic or payload:find('\0', 1, true) then return nil end
    local fields, offset = {}, #magic + 1
    for i, limit in ipairs(limits) do
        local colon = payload:find(':', offset, true)
        if not colon or colon - offset > 5 then return nil end
        local size = payload:sub(offset, colon - 1)
        if not size:match('^%d+$') then return nil end
        local count = tonumber(size)
        if count > limit or colon + count > #payload then return nil end
        fields[i] = payload:sub(colon + 1, colon + count); offset = colon + count + 1
    end
    if offset ~= #payload + 1 then return nil end
    if not fields[1]:match('^[%w_-]+$') or not fields[2]:match('^%d+$') or
        not fields[3]:match('^[%w_]*$') or not fields[4]:match('^%d*$') or
        not fields[5]:match('^%d*$') or not fields[7]:match('^[01]$') or
        not fields[10]:match('^%d+$') or not fields[11]:match('^%d+$') or not fields[12]:match('^%d+$') or
        not fields[13]:match('^[%w_-]*$') or not fields[14]:match('^[01]$') then return nil end
    if tonumber(fields[4] ~= '' and fields[4] or '0') > 10 then return nil end
    if tonumber(fields[2]) >= 10000000 then return nil end
    return {nonce = fields[1], sequence = tonumber(fields[2]), range = fields[3], countdown = tonumber(fields[4]) or 0,
        markerId = tonumber(fields[5]) or 0, marker = fields[6], away = fields[7] == '1', chat = fields[8], gear = fields[9],
        gearRevision = tonumber(fields[10]), gearAck = tonumber(fields[11]), chatAck = tonumber(fields[12]), ackNonce = fields[13], gearIncluded = fields[14] == '1', gameplay = fields[15]}
end
function Protocol.newer(sequence, previous)
    local distance = (sequence - previous) % 10000000
    return distance > 0 and distance < 5000000
end
return Protocol
