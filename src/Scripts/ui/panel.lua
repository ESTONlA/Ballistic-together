local R = require('shared.runtime')
local Panel = {}

function Panel.create(config, session, run)
    local self = {widget = nil, open = false, buttons = {}, world = ''}
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
        local template = LoadAsset('/Game/UI/Common/TheRangeButton.TheRangeButton_C')
        local widget = R.widgets():Create(pc, template, pc)
        assert(R.valid(widget), 'Could not create lobby panel')
        local tree = widget.WidgetTree
        local function construct(class) return StaticConstructObject(StaticFindObject('/Script/UMG.' .. class), tree) end
        local canvas, border, column = construct('CanvasPanel'), construct('Border'), construct('VerticalBox')
        tree.RootWidget = canvas
        border:SetBrushColor({R = 0.035, G = 0.035, B = 0.035, A = 1})
        border:SetContent(column)
        local slot = canvas:AddChildToCanvas(border)
        slot:SetAnchors({Minimum = {X = 0.5, Y = 0.5}, Maximum = {X = 0.5, Y = 0.5}})
        slot:SetAlignment({X = 0.5, Y = 0.5})
        slot:SetPosition({X = 0, Y = 0})
        slot:SetSize({X = 430, Y = 405})
        local function text(value)
            local label = construct('TextBlock')
            label:SetText(FText(value))
            column:AddChildToVerticalBox(label)
            return label
        end
        text('Ballistic Together / Steam')
        self.status = text('Two-player bunker lobby prototype')
        self.status:SetAutoWrapText(true)
        self.detail = text('F8: close | Ctrl+F10: diagnostics')
        self.detail:SetAutoWrapText(true)
        self.inviteStatus = text('Steam invites starting...')
        self.inviteStatus:SetAutoWrapText(true)
        self.input = construct('EditableTextBox')
        self.input:SetHintText(FText('Host SteamID64 (17 digits)'))
        self.input:SetForegroundColor({R = 0.03, G = 0.03, B = 0.03, A = 1})
        self.input:SetText(FText(config.HostSteamId or ''))
        column:AddChildToVerticalBox(self.input)
        self.buttons = {}
        for _, entry in ipairs({{'Host lobby', 'host'}, {'Join by ID (fallback)', 'join'}, {'Leave lobby', 'leave'}, {'Invite friends (Steam)', 'invite'}, {'Close', 'close'}}) do
            local button, label = construct('Button'), construct('TextBlock')
            button:SetBackgroundColor({R = 0.12, G = 0.12, B = 0.12, A = 1})
            label:SetText(FText(entry[1]))
            button:AddChild(label)
            column:AddChildToVerticalBox(button)
            self.buttons[#self.buttons + 1] = {button = button, action = entry[2]}
        end
        widget:AddToViewport(100)
        widget:SetVisibility(1)
        self.widget, self.world, self.owner = widget, R.name(R.world()), R.name(pc)
    end
    function self:toggle()
        if self.open then self:close(); return end
        if not R.valid(self.widget) or self.world ~= R.name(R.world()) or self.owner ~= R.name(R.player()) then self:build() end
        local pc = R.player()
        self.oldCursor = pc.bShowMouseCursor
        self.widget:SetVisibility(0)
        self.open = true
        pc.bShowMouseCursor = true
        R.widgets():SetInputMode_UIOnlyEx(pc, self.input, 0, true)
        self:update()
    end
    function self:update()
        if not self.open then return end
        if not R.valid(self.widget) or self.world ~= R.name(R.world()) then self.open = false; return end
        self.status:SetText(FText(string.format('%s | %d/2 players', session.phase, session.players)))
        self.detail:SetText(FText(session.message))
        self.inviteStatus:SetText(FText(session.invites.ready and 'Steam invites ready' or session.invites.message))
        local busy = session.phase ~= 'idle' and session.phase ~= 'failed'
        self.buttons[1].button:SetIsEnabled(not busy)
        self.buttons[2].button:SetIsEnabled(not busy)
        self.buttons[3].button:SetIsEnabled(busy or session.phase == 'failed')
        self.buttons[4].button:SetIsEnabled(session.phase == 'hosting' and session.players < 2 and session.invites.ready)
    end
    function self:click()
        if not self.open or not R.valid(self.widget) then return end
        for _, entry in ipairs(self.buttons) do
            if entry.button:GetIsEnabled() and entry.button:IsHovered() then
                if entry.action == 'close' then self:close(); return end
                local id = self.input:GetText():ToString()
                self:close()
                run(function()
                    if entry.action == 'host' then session:host()
                    elseif entry.action == 'join' then session:join(id)
                    elseif entry.action == 'invite' then session:invite()
                    elseif entry.action == 'leave' then session:leave() end
                end)
                return
            end
        end
    end
    return self
end
return Panel
