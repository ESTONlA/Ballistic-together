local R = require('shared.runtime')
local Invites = {}
local script = debug.getinfo(1, 'S').source:gsub('^@', ''):gsub('\\', '/')
local directory = script:match('^(.*)/Scripts/network/invites.lua$')

function Invites.create()
    local self = {ready = false, message = 'Steam invites starting...', last = 0, previous = '', advertised = false}
    local native = directory and directory .. '/Native/'
    local function read(name)
        local file = native and io.open(native .. name, 'rb')
        if not file then return '' end
        local text = file:read(1024) or ''
        file:close()
        return text
    end
    function self:status()
        self.message = read('status.txt')
        self.ready = self.message == 'ready'
        if self.message == '' then self.message = 'Steam invite bridge did not report a status.' end
    end
    function self:initialize()
        if not native or type(package.loadlib) ~= 'function' then self.message = 'Native invite loading is unavailable.'; return end
        if not self.functions then
            self.functions = {}
            for _, action in ipairs({'initialize', 'publish', 'invite', 'clear'}) do
                local fn, err = package.loadlib(native .. 'BallisticSteamInvites.dll', 'bt_' .. action)
                if not fn then self.functions = nil; self.message = 'Invite bridge could not load: ' .. tostring(err); return end
                self.functions[action] = fn
            end
        end
        self.functions.initialize()
        self:status()
    end
    function self:tick(session)
        if not self.ready and os.time() - self.last >= 10 then
            self.last = os.time()
            local ok, err = pcall(function() self:initialize() end)
            if not ok then self.message = tostring(err); self.ready = false end
            R.log('Steam invites: ' .. self.message)
        end
        if not self.ready then return end
        local advertise = session.phase == 'hosting' and session.players < 2
        if advertise ~= self.advertised then
            self.functions[advertise and 'publish' or 'clear']()
            self:status()
            self.advertised = advertise and self.ready
        end
        local request = read('accepted.txt')
        if request == '' or request == self.previous then return end
        self.previous = request
        local address = request:match('^%d+\n(steam%.7656119%d+:7777)$')
        local id = address and address:match('^steam%.(%d+):7777$')
        if not id or #id ~= 17 then R.log('Ignored malformed invite connection information.'); return end
        if session.phase ~= 'idle' and session.phase ~= 'failed' then R.log('Invite accepted while already in a lobby; leave before accepting another invite.'); return end
        R.log('Steam invite accepted; connecting to host.')
        session:join(id)
    end
    function self:open(session)
        assert(session.phase == 'hosting' and session.players < 2, 'Host a lobby with a free slot before inviting a friend.')
        self:initialize()
        assert(self.ready, self.message)
        self.functions.invite()
        self:status()
        assert(self.ready, self.message)
        R.log('Steam invite picker requested. Select a friend in the overlay.')
    end
    function self:clear()
        if self.functions then self.functions.clear() end
        self.advertised = false
    end
    return self
end
return Invites
