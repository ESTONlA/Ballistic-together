local R = require('shared.runtime')
local Names = require('avatars.nameplates')
local Panel = {}
local colors = {panel = {R = 0.025, G = 0.03, B = 0.035, A = 0.98},
    row = {R = 0.055, G = 0.065, B = 0.075, A = 1}, accent = {R = 0.20, G = 0.55, B = 0.40, A = 1}}
function Panel.create(config, session, run)
    local self = {widget = nil, open = false, buttons = {}, world = '', lastClick = -1}
    function self:close()
        if R.valid(self.widget) then self.widget:SetVisibility(1) end
        self.open = false
        local pc = R.player()
        if R.valid(pc) then
            pc.bShowMouseCursor = self.oldCursor == true
            if self.oldCursor then R.widgets():SetInputMode_GameAndUIEx(pc, nil, 0, false, true)
            else R.widgets():SetInputMode_GameOnly(pc, true) end
        end
    end
    function self:build()
        local pc = R.player()
        assert(R.valid(pc), 'Player controller is not ready')
        if R.valid(self.widget) then self.widget:RemoveFromParent() end
        local template = LoadAsset('/Game/UI/Common/TheRangeButton.TheRangeButton_C')
        local widget = R.widgets():Create(pc, template, pc)
        assert(R.valid(widget), 'Could not create multiplayer panel')
        local tree = widget.WidgetTree
        local function make(class) return StaticConstructObject(StaticFindObject('/Script/UMG.' .. class), tree) end
        local function add(parent, child, padding)
            local slot = parent:AddChild(child)
            if padding then slot:SetPadding({Left = padding, Top = padding, Right = padding, Bottom = padding}) end
            return child
        end
        local function text(parent, value, size)
            local label = make('TextBlock')
            label:SetText(FText(value)); label:SetAutoWrapText(true)
            local font = label.Font; font.Size = size or 16; label:SetFont(font)
            add(parent, label, 3)
            return label
        end
        local function fixed(parent, child, width, height)
            local box = make('SizeBox')
            if width then box:SetWidthOverride(width) end
            if height then box:SetHeightOverride(height) end
            box:AddChild(child); add(parent, box, 3)
        end
        self.buttons = {}
        local function button(parent, title, action, width, accent)
            local button, label = make('Button'), make('TextBlock')
            button:SetBackgroundColor(accent and colors.accent or colors.row)
            label:SetText(FText(title))
            local font = label.Font; font.Size = 15; label:SetFont(font)
            button:AddChild(label); fixed(parent, button, width, 36)
            self.buttons[action] = {button = button, label = label, action = action}
        end
        local canvas, border, column = make('CanvasPanel'), make('Border'), make('VerticalBox')
        tree.RootWidget = canvas
        border:SetBrushColor(colors.panel)
        border:SetPadding({Left = 18, Top = 14, Right = 18, Bottom = 14})
        border:SetContent(column)
        local slot = canvas:AddChildToCanvas(border)
        slot:SetAnchors({Minimum = {X = 0.5, Y = 0.5}, Maximum = {X = 0.5, Y = 0.5}})
        slot:SetAlignment({X = 0.5, Y = 0.5}); slot:SetPosition({X = 0, Y = 0}); slot:SetSize({X = 700, Y = 620})
        text(column, 'BALLISTIC TOGETHER', 28)
        text(column, '0.2.0-beta   /   STEAM MULTIPLAYER', 12)
        self.status = text(column, 'Not connected', 18)
        self.detail = text(column, 'Host a session or join a friend through Steam.', 14)
        local header = make('HorizontalBox'); add(column, header, 3)
        for _, cell in ipairs({{'PLAYER', 285}, {'PING', 85}, {'STATUS', 130}, {'ROLE', 100}}) do
            local holder = make('VerticalBox'); text(holder, cell[1], 12); fixed(header, holder, cell[2], 25)
        end
        self.rows = {}
        for i = 1, 2 do
            local background, row = make('Border'), make('HorizontalBox')
            background:SetBrushColor(colors.row); background:SetContent(row); add(column, background, 3)
            local fields = {}
            for _, cell in ipairs({{'name', 285}, {'ping', 85}, {'ready', 130}, {'role', 100}}) do
                local holder = make('VerticalBox'); fields[cell[1]] = text(holder, '-', 15); fixed(row, holder, cell[2], 34)
            end
            self.rows[i] = fields
        end
        local actions = make('HorizontalBox'); add(column, actions)
        button(actions, 'Ready', 'ready', 145, true)
        button(actions, 'Invite friends', 'invite', 160)
        button(actions, 'Leave session', 'leave', 155)
        button(actions, 'Close', 'close', 160)
        text(column, 'HOST CONTROLS', 12)
        self.range = text(column, 'Range: waiting for a host', 17)
        local travel = make('HorizontalBox'); add(column, travel)
        button(travel, 'Change range', 'cycle', 145)
        button(travel, 'Enter range', 'travel', 160, true)
        button(travel, 'Back to bunker', 'bunker', 155)
        button(travel, 'Remove guest', 'kick', 160)
        text(column, 'CONNECT / HOST STEAMID64 (OPTIONAL)', 12)
        self.input = make('EditableTextBox')
        self.input:SetHintText(FText(''))
        self.input:SetForegroundColor({R = 0.03, G = 0.03, B = 0.03, A = 1})
        self.input:SetText(FText(config.HostSteamId or '')); fixed(column, self.input, nil, 32)
        local connect = make('HorizontalBox'); add(column, connect)
        button(connect, 'Host session', 'host', 315, true)
        button(connect, 'Join by ID', 'join', 315)
        self.inviteStatus = text(column, 'Steam invites starting...', 12)
        text(column, 'F8  Close panel     |     Ctrl+F10  Connection log', 12)
        widget:AddToViewport(100); widget:SetVisibility(1)
        self.widget, self.world, self.owner = widget, R.worldKey(), R.name(pc)
    end
    function self:toggle()
        if self.open then self:close(); return end
        if not R.valid(self.widget) or self.world ~= R.worldKey() or self.owner ~= R.name(R.player()) then self:build() end
        local pc = R.player()
        self.oldCursor = pc.bShowMouseCursor; self.widget:SetVisibility(0); self.open = true; pc.bShowMouseCursor = true
        R.widgets():SetInputMode_UIOnlyEx(pc, self.input, 0, true); self:update()
    end
    function self:update()
        if not self.open then return end
        if not R.valid(self.widget) or self.world ~= R.worldKey() then self.open = false; return end
        self.status:SetText(FText(string.format('%s   /   %d of 2 players   /   %s', session.phase:upper(), session.players, R.level())))
        self.detail:SetText(FText(session.actionError or session.message))
        local metadataStatus = session.metadata.message
        if metadataStatus == 'ready' then metadataStatus = session.metadata.remote and 'Steam connected / peer data received' or 'Steam connected / waiting for peer data' end
        self.inviteStatus:SetText(FText(metadataStatus))
        for i, fields in ipairs(self.rows) do
            local row = session.playerList[i]
            fields.name:SetText(FText(row and (Names.clean(row.name) .. (row.isLocal and '  (you)' or '')) or 'Waiting for player...'))
            fields.ping:SetText(FText(row and string.format('%.0f ms', math.max(0, row.ping or 0)) or '-'))
            fields.ready:SetText(FText(row and (row.ready and 'READY' or 'NOT READY') or '-'))
            fields.role:SetText(FText(row and ((session:isHost() == row.isLocal) and 'HOST' or 'GUEST') or '-'))
        end
        local active, host = session:active(), session:isHost()
        local busy = session.phase ~= 'idle' and session.phase ~= 'failed'
        for action, entry in pairs(self.buttons) do
            local enabled = true
            if action == 'host' or action == 'join' then enabled = not busy
            elseif action == 'ready' then enabled = active
            elseif action == 'invite' then enabled = host and session.players < 2 and session.invites.ready
            elseif action == 'leave' then enabled = busy or session.phase == 'failed'
            elseif action == 'cycle' then enabled = host and #session.ranges > 1
            elseif action == 'travel' then enabled = host and session:allReady() and #session.ranges > 0
            elseif action == 'bunker' then enabled = host and R.level() ~= 'Bunker_Main'
            elseif action == 'kick' then enabled = host and session.players > 1 end
            entry.button:SetIsEnabled(enabled)
        end
        self.buttons.ready.label:SetText(FText(session.localReady and 'Not ready' or 'Ready'))
        local range = session.ranges[session.rangeIndex]
        self.range:SetText(FText('Range: ' .. (range and range.name or 'No supported range unlocked') .. (host and '' or '  /  Host selects')))
    end
    function self:click()
        if not self.open or not R.valid(self.widget) then return end
        local now = R.gameplay():GetRealTimeSeconds(R.world())
        if now >= self.lastClick and now - self.lastClick < 0.2 then return end
        for action, entry in pairs(self.buttons) do
            if entry.button:GetIsEnabled() and entry.button:IsHovered() then
                self.lastClick, session.actionError = now, nil
                if action == 'close' then self:close(); return end
                local id = self.input:GetText():ToString()
                if action == 'host' or action == 'join' or action == 'leave' or action == 'travel' or action == 'bunker' or action == 'invite' then self:close() end
                run(function()
                    if action == 'host' then session:host()
                    elseif action == 'join' then session:join(id)
                    elseif action == 'invite' then session:invite()
                    elseif action == 'leave' then session:leave()
                    elseif action == 'ready' then session:ready()
                    elseif action == 'cycle' then session:cycleRange()
                    elseif action == 'travel' then session:startRange()
                    elseif action == 'bunker' then session:returnToBunker()
                    elseif action == 'kick' then session:kickGuest() end
                end)
                self:update(); return
            end
        end
    end
    return self
end
return Panel
