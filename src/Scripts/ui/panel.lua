local R = require('shared.runtime')
local Widgets = require('ui.widgets')
local Names = require('avatars.nameplates')
local Storage = require('shared.storage')
local Ranges = require('lobby.ranges')
local Panel = {}
local settings = {{'ShowNames', 'Player names'}, {'ShowWeapons', 'Friend guns'}, {'ShowMarkers', 'Rally markers'},
    {'ShowHud', 'Session HUD'}, {'ShowDistances', 'Name distances'}, {'ChatMuted', 'Mute incoming chat'}}
local rangeNames = {Bunker_Main = 'Bunker', Range_SwimmingPool = 'Azure Swimming Pool', Range_Tutorial_Advanced = 'Training sequence'}
function Panel.create(config, session, run)
    local self = {open = false, page = 'lobby', lastClick = -1}
    function self:close()
        if R.valid(self.widget) and self.world == R.worldKey() then self.widget:SetVisibility(1) end
        self.open = false
        local pc = R.player()
        if R.valid(pc) then
            pc.bShowMouseCursor = self.oldCursor == true
            if self.oldCursor then R.widgets():SetInputMode_GameAndUIEx(pc, nil, 0, false, true)
            else R.widgets():SetInputMode_GameOnly(pc, true) end
        end
    end
    function self:build()
        if self.world == R.worldKey() and R.valid(self.widget) then self.widget:RemoveFromParent() end
        local w = Widgets.create(); self.widget, self.buttons = w.root, w.buttons
        local column = w:panel(620, 740)
        w:text(column, 'Ballistic Together', 30)
        self.status = w:text(column, '', 15, true)
        local tabs = w:row(column)
        w:button(tabs, 'Lobby', 'page_lobby', 182)
        w:button(tabs, 'Chat', 'page_chat', 182)
        w:button(tabs, 'Settings', 'page_settings', 182)
        self.detail = w:text(column, '', 14)
        self.connect = w:column(column)
        w:text(self.connect, 'Bring a friend to the bunker.', 22)
        w:text(self.connect, 'Host a session, then invite through Steam.\nAccept invitations in the overlay to join.', 16, true)
        w:button(self.connect, 'Host session', 'host')
        self.input = w:input(self.connect, 'Host SteamID64', config.HostSteamId ~= '' and config.HostSteamId or session.preferences.lastHost)
        w:button(self.connect, 'Join session', 'join')
        w:button(self.connect, 'Reconnect to last host', 'reconnect')
        self.lobby = w:column(column)
        self.rows = {}
        for i = 1, 2 do
            local fields = {name = w:text(self.lobby, '', 22)}
            local row = w:row(self.lobby)
            for _, cell in ipairs({{'role', 90}, {'ping', 100}, {'ready', 260}}) do
                local holder = w:column(); fields[cell[1]] = w:text(holder, '', 14, true); w:fixed(row, holder, cell[2], 24)
            end
            self.rows[i] = fields
        end
        local actions = w:row(self.lobby)
        w:button(actions, 'Ready', 'ready', 274); w:button(actions, 'Invite friend', 'invite', 274)
        self.range = w:text(self.lobby, '', 19)
        self.hostControls = w:column(self.lobby)
        w:button(self.hostControls, 'Change range', 'cycle')
        local travel = w:row(self.hostControls)
        w:button(travel, 'Enter range', 'travel', 274); w:button(travel, 'Cancel countdown', 'cancel', 274)
        local host = w:row(self.hostControls)
        w:button(host, 'Back to bunker', 'bunker', 274); w:button(host, 'Remove guest', 'kick', 274)
        local leave = w:row(self.lobby)
        w:button(leave, 'Away', 'away', 274); w:button(leave, 'Leave session', 'leave', 274)
        self.chat = w:column(column)
        local scroll = w:make('ScrollBox')
        self.chatScroll = scroll
        self.chatLog = w:text(scroll, 'No messages yet.', 17)
        w:fixed(self.chat, scroll, nil, 245)
        self.message = w:input(self.chat, 'Message your friend (180 characters)', '')
        w:button(self.chat, 'Send message', 'send')
        local quick = w:row(self.chat)
        w:button(quick, 'Wait for me', 'quick_wait', 182); w:button(quick, 'Need ammo', 'quick_ammo', 182); w:button(quick, 'Nice shot', 'quick_nice', 182)
        local markers = w:row(self.chat)
        w:button(markers, 'Mark my position [F7]', 'mark', 274); w:button(markers, 'Clear marker', 'unmark', 274)
        w:button(self.chat, 'Clear local chat', 'clear_chat')
        self.options = w:column(column)
        for _, setting in ipairs(settings) do w:button(self.options, setting[2], 'setting_' .. setting[1]) end
        w:button(self.options, 'Save connection report', 'report')
        self.identity = w:text(self.options, '', 14, true)
        w:button(self.options, 'Copy my Steam ID', 'copy')
        w:button(column, 'Close   [F8]', 'close')
        w:text(column, require('release').version, 12, true)
        self.widget:AddToViewport(100); self.widget:SetVisibility(1)
        self.world, self.owner = R.worldKey(), R.name(R.player())
    end
    function self:toggle(page)
        if self.open and not page then self:close(); return end
        if page then self.page = page end
        if not R.valid(self.widget) or self.world ~= R.worldKey() or self.owner ~= R.name(R.player()) then self:build() end
        local pc = R.player()
        if not self.open then self.oldCursor = pc.bShowMouseCursor end
        self.widget:SetVisibility(0); self.open = true; pc.bShowMouseCursor = true
        R.widgets():SetInputMode_UIOnlyEx(pc, nil, 0, true); self:update()
    end
    function self:update()
        if not self.open then return end
        if not R.valid(self.widget) or self.world ~= R.worldKey() then self.open = false; return end
        local active, host = session:active(), session:isHost()
        local busy = session.phase ~= 'idle' and session.phase ~= 'failed'
        if not busy and self.page == 'chat' then self.page = 'lobby' end
        self.connect:SetVisibility(self.page == 'lobby' and not busy and 0 or 1)
        self.lobby:SetVisibility(self.page == 'lobby' and busy and 0 or 1)
        self.chat:SetVisibility(self.page == 'chat' and 0 or 1)
        self.options:SetVisibility(self.page == 'settings' and 0 or 1)
        if self.page == 'chat' then session.social.unread = 0 end
        self.hostControls:SetVisibility(host and 0 or 1)
        self.buttons.invite.box:SetVisibility(host and 0 or 1)
        self.buttons.reconnect.box:SetVisibility(session.preferences.lastHost ~= '' and 0 or 1)
        self.status:SetText(FText(busy and string.format('%s   /   %d/2 players', rangeNames[R.level()] or 'Connecting', session.players) or 'Steam multiplayer'))
        local seconds = host and session.countdown:remaining() or (session.metadata.remote and session.social.remoteCountdown or 0)
        local notice = session.actionError or (self.flashUntil and os.time() <= self.flashUntil and self.flash) or (session.metadata.mismatch and session.metadata.message) or
            (session.metadata.dataDelayed and 'Connection updates delayed. Waiting for your friend...') or
            (seconds > 0 and ('Entering range in ' .. seconds .. '...')) or (busy and not active and session.message) or ''
        self.detail:SetText(FText(notice))
        for i, fields in ipairs(self.rows) do
            local row = session.playerList[i]
            fields.name:SetText(FText(row and (Names.clean(row.name) .. (row.isLocal and '  (you)' or '')) or 'Waiting for a friend...'))
            local ping = row and row.ping or 0
            fields.ping:SetText(FText(row and string.format('%.0f ms%s', ping, ping >= 150 and ' !' or '') or ''))
            fields.ready:SetText(FText(row and (row.away and 'Away' or (row.ready and 'Ready' or 'Not ready')) or ''))
            fields.role:SetText(FText(row and ((host == row.isLocal) and 'Host' or 'Guest') or ''))
        end
        for action, entry in pairs(self.buttons) do
            local enabled = true
            if action == 'host' or action == 'join' or action == 'reconnect' then enabled = not busy
            elseif action == 'page_chat' then enabled = active
            elseif action == 'ready' or action == 'away' or action == 'send' or action == 'mark' or action == 'unmark' or action:match('^quick_') then enabled = active
            elseif action == 'invite' then enabled = host and session.players < 2 and session.invites.ready
            elseif action == 'leave' then enabled = busy or session.phase == 'failed'
            elseif action == 'cycle' then enabled = host and #session.ranges > 1
            elseif action == 'travel' then enabled = host and session:allReady() and #session.ranges > 0 and not session.countdown.deadline
            elseif action == 'cancel' then enabled = host and session.countdown.deadline ~= nil
            elseif action == 'bunker' then enabled = host and R.level() ~= 'Bunker_Main'
            elseif action == 'kick' then enabled = host and session.players > 1 end
            entry.button:SetIsEnabled(enabled)
            if action:match('^page_') then entry.label:SetText(FText((self.page == action:sub(6) and '> ' or '') .. ({lobby = 'Lobby', chat = 'Chat', settings = 'Settings'})[action:sub(6)])) end
        end
        self.buttons.ready.label:SetText(FText(session.localReady and 'Cancel ready' or 'Ready'))
        self.buttons.page_chat.label:SetText(FText((self.page == 'chat' and '> ' or '') .. 'Chat' .. (session.social.unread > 0 and (' (' .. session.social.unread .. ')') or '')))
        self.buttons.away.label:SetText(FText(session.social.away and "I'm back" or 'Away'))
        self.buttons.kick.label:SetText(FText(self.confirmKick and os.time() <= self.confirmKick and 'Confirm removal' or 'Remove guest'))
        local range = host and session.ranges[session.rangeIndex]
        local rangeId = not host and session.metadata.remote and session.social.remoteRange or nil
        self.range:SetText(FText('Range: ' .. (range and range.name or rangeNames[rangeId] or 'Waiting for host') .. (host and '' or ' / Host selects')))
        local history = {}
        for i = math.max(1, #session.social.history - 19), #session.social.history do
            local entry = session.social.history[i]
            history[#history + 1] = (entry.system and '* ' or entry.name .. ': ') .. entry.text
        end
        self.chatLog:SetText(FText(#history > 0 and table.concat(history, '\n') or 'No messages yet.'))
        local lastEntry = session.social.history[#session.social.history]
        if lastEntry ~= self.lastChatEntry then self.chatScroll:ScrollToEnd(); self.lastChatEntry = lastEntry end
        for _, setting in ipairs(settings) do self.buttons['setting_' .. setting[1]].label:SetText(FText(setting[2] .. ': ' .. (session.preferences.values[setting[1]] and 'On' or 'Off'))) end
        local id = session.metadata.localId or Storage.read('identity.txt', 32)
        self.identity:SetText(FText('Your Steam ID: ' .. (id ~= '' and id or 'Launch through Steam')))
    end
    function self:dispatch(action)
        if action == 'close' then self:close(); return end
        if action:match('^page_') then self.page = action:sub(6); self:update(); return end
        local setting = action:match('^setting_(.+)$')
        if setting then session.preferences:toggle(setting); self:update(); return end
        if action == 'kick' and (not self.confirmKick or os.time() > self.confirmKick) then self.confirmKick = os.time() + 5; self:update(); return end
        local id = self.input:GetText():ToString()
        if action == 'host' or action == 'join' or action == 'reconnect' or action == 'leave' or action == 'bunker' or action == 'invite' then self:close() end
        run(function()
            if action == 'host' then session:host()
            elseif action == 'join' then session:join(id)
            elseif action == 'reconnect' then session:reconnect()
            elseif action == 'invite' then session:invite()
            elseif action == 'leave' then session:leave()
            elseif action == 'ready' then session:ready()
            elseif action == 'cycle' then session:cycleRange()
            elseif action == 'travel' then session:startRange()
            elseif action == 'cancel' then session.countdown:cancel(); session.social:add('', 'Range countdown cancelled.', true)
            elseif action == 'bunker' then session:returnToBunker()
            elseif action == 'kick' then self.confirmKick = nil; session:kickGuest()
            elseif action == 'away' then session:away()
            elseif action == 'clear_chat' then session.social.history, session.social.unread = {}, 0
            elseif action == 'mark' or action == 'unmark' then session:mark(action == 'unmark')
            elseif action == 'copy' then session:copyId()
            elseif action == 'report' then
                require('shared.diagnostics').export(session); session.social:add('', "Report saved in this mod's Native/diagnostics.txt.", true)
            elseif action == 'send' then session:chat(self.message:GetText():ToString()); self.message:SetText(FText(''))
            elseif action:match('^quick_') then session:chat(({quick_wait = 'Wait for me!', quick_ammo = 'I need ammo.', quick_nice = 'Nice shot!'})[action]) end
        end)
        if action == 'copy' or action == 'report' then
            local entry = session.social.history[#session.social.history]
            self.flash, self.flashUntil = entry and entry.text or '', os.time() + 6
        end
        self:update()
    end
    function self:click()
        if not self.open or not R.valid(self.widget) then return end
        local now = R.gameplay():GetRealTimeSeconds(R.world())
        if now >= self.lastClick and now - self.lastClick < 0.2 then return end
        for action, entry in pairs(self.buttons) do
            if entry.button:GetIsEnabled() and entry.button:IsHovered() then
                self.lastClick, session.actionError = now, nil
                self:dispatch(action); return
            end
        end
    end
    return self
end
return Panel
