local R = require('shared.runtime')
local Names = require('avatars.nameplates')
local Panel = {}
local colors = {panel = {R = 0.005, G = 0.005, B = 0.005, A = 0.96},
    row = {R = 0.16, G = 0.16, B = 0.16, A = 1}}
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
            local font = widget.NavText.Font; font.Size = size or 16; label:SetFont(font)
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
        local function button(parent, title, action, width)
            local native = R.widgets():Create(pc, template, pc)
            native.Text = FText(title); native.NavText:SetText(FText(title))
            native.LeftIcon:SetVisibility(1); native.RightIcon:SetVisibility(1)
            local font = native.NavText.Font; font.Size = 17; native.NavText:SetFont(font)
            fixed(parent, native, width, 38)
            self.buttons[action] = {widget = native, button = native.NavButton, label = native.NavText, action = action}
        end
        local canvas, border, column = make('CanvasPanel'), make('Border'), make('VerticalBox')
        tree.RootWidget = canvas
        border:SetBrushColor(colors.panel)
        border:SetPadding({Left = 24, Top = 18, Right = 24, Bottom = 16})
        border:SetContent(column)
        local slot = canvas:AddChildToCanvas(border)
        slot:SetAnchors({Minimum = {X = 0, Y = 0.5}, Maximum = {X = 0, Y = 0.5}})
        slot:SetAlignment({X = 0, Y = 0.5}); slot:SetPosition({X = 40, Y = 0}); slot:SetSize({X = 620, Y = 640})
        text(column, 'Ballistic Together', 30)
        self.status = text(column, 'Steam multiplayer', 15)
        self.detail = text(column, '', 14)
        self.connect = add(column, make('VerticalBox'))
        text(self.connect, 'Bring a friend to the bunker.', 22)
        text(self.connect, 'Host a session, then invite them through Steam.\nAccept invitations in the Steam overlay to join.', 16)
        button(self.connect, 'Host session', 'host')
        text(self.connect, 'Join by Steam ID', 18)
        self.input = make('EditableTextBox')
        self.input:SetHintText(FText('Host SteamID64'))
        self.input:SetForegroundColor({R = 0.03, G = 0.03, B = 0.03, A = 1})
        self.input:SetText(FText(config.HostSteamId or '')); fixed(self.connect, self.input, nil, 36)
        button(self.connect, 'Join session', 'join')
        self.lobby = add(column, make('VerticalBox'))
        self.rows = {}
        for i = 1, 2 do
            local fields = {name = text(self.lobby, 'Waiting for a friend...', 22)}
            local row = make('HorizontalBox'); add(self.lobby, row, 3)
            for _, cell in ipairs({{'role', 90}, {'ping', 100}, {'ready', 260}}) do
                local holder = make('VerticalBox'); fields[cell[1]] = text(holder, '', 14); fixed(row, holder, cell[2], 25)
            end
            self.rows[i] = fields
        end
        local actions = make('HorizontalBox'); add(self.lobby, actions)
        button(actions, 'Ready', 'ready', 274)
        button(actions, 'Invite friend', 'invite', 274)
        self.range = text(self.lobby, '', 19)
        self.hostControls = add(self.lobby, make('VerticalBox'))
        button(self.hostControls, 'Change range', 'cycle')
        local travel = make('HorizontalBox'); add(self.hostControls, travel)
        button(travel, 'Enter range', 'travel', 274)
        button(travel, 'Back to bunker', 'bunker', 274)
        local leave = make('HorizontalBox'); add(self.lobby, leave)
        button(leave, 'Remove guest', 'kick', 274)
        button(leave, 'Leave session', 'leave', 274)
        button(column, 'Close   [F8]', 'close')
        text(column, '0.2.1-beta', 12)
        widget:AddToViewport(100); widget:SetVisibility(1)
        self.widget, self.world, self.owner = widget, R.worldKey(), R.name(pc)
    end
    function self:toggle()
        if self.open then self:close(); return end
        if not R.valid(self.widget) or self.world ~= R.worldKey() or self.owner ~= R.name(R.player()) then self:build() end
        local pc = R.player()
        self.oldCursor = pc.bShowMouseCursor; self.widget:SetVisibility(0); self.open = true; pc.bShowMouseCursor = true
        R.widgets():SetInputMode_UIOnlyEx(pc, nil, 0, true); self:update()
    end
    function self:update()
        if not self.open then return end
        if not R.valid(self.widget) or self.world ~= R.worldKey() then self.open = false; return end
        local active, host = session:active(), session:isHost()
        local busy = session.phase ~= 'idle' and session.phase ~= 'failed'
        self.connect:SetVisibility(busy and 1 or 0)
        self.lobby:SetVisibility(busy and 0 or 1)
        self.hostControls:SetVisibility(host and 0 or 1)
        self.buttons.kick.widget:SetVisibility(host and 0 or 1)
        self.buttons.invite.widget:SetVisibility(host and 0 or 1)
        local location = ({Bunker_Main = 'Bunker', Range_SwimmingPool = 'Azure Swimming Pool', Range_Tutorial_Advanced = 'Training range'})[R.level()] or 'Connecting'
        self.status:SetText(FText(busy and string.format('%s   /   %d/2 players', location, session.players) or 'Steam multiplayer'))
        self.detail:SetText(FText(session.actionError or (session.phase == 'failed' and session.message) or (busy and not active and session.message) or ''))
        for i, fields in ipairs(self.rows) do
            local row = session.playerList[i]
            fields.name:SetText(FText(row and (Names.clean(row.name) .. (row.isLocal and '  (you)' or '')) or 'Waiting for player...'))
            fields.ping:SetText(FText(row and string.format('%.0f ms', math.max(0, row.ping or 0)) or ''))
            fields.ready:SetText(FText(row and (row.ready and 'Ready' or 'Not ready') or ''))
            fields.role:SetText(FText(row and ((host == row.isLocal) and 'Host' or 'Guest') or ''))
        end
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
        self.buttons.ready.label:SetText(FText(session.localReady and 'Cancel ready' or 'Ready'))
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
