local R = require('shared.runtime')
local Widgets = {}
function Widgets.create()
    local pc = R.player()
    assert(R.valid(pc), 'Player controller is not ready')
    local class = LoadAsset('/Game/UI/Common/TheRangeButton.TheRangeButton_C')
    local root = R.widgets():Create(pc, class, pc)
    assert(R.valid(root), 'Could not create multiplayer menu')
    local self = {root = root, buttons = {}}
    function self:make(name) return StaticConstructObject(StaticFindObject('/Script/UMG.' .. name), root.WidgetTree) end
    function self:add(parent, child, padding)
        local slot = parent:AddChild(child)
        if padding then slot:SetPadding({Left = padding, Top = padding, Right = padding, Bottom = padding}) end
        return child
    end
    function self:column(parent) local child = self:make('VerticalBox'); if parent then self:add(parent, child) end; return child end
    function self:row(parent) return self:add(parent, self:make('HorizontalBox')) end
    function self:fixed(parent, child, width, height)
        local box = self:make('SizeBox')
        if width then box:SetWidthOverride(width) end
        if height then box:SetHeightOverride(height) end
        box:AddChild(child); self:add(parent, box, 3)
        return box
    end
    function self:text(parent, value, size, muted)
        local label = self:make('TextBlock')
        label:SetText(FText(value)); label:SetAutoWrapText(true)
        local font = root.NavText.Font; font.Size = size or 16; label:SetFont(font)
        if muted then label:SetRenderOpacity(0.6) end
        self:add(parent, label, 3)
        return label
    end
    function self:button(parent, title, action, width)
        local widget = R.widgets():Create(pc, class, pc)
        widget.Text = FText(title); widget.NavText:SetText(FText(title))
        widget.LeftIcon:SetVisibility(1); widget.RightIcon:SetVisibility(1)
        local font = widget.NavText.Font; font.Size = 17; widget.NavText:SetFont(font)
        local box = self:fixed(parent, widget, width, 38)
        self.buttons[action] = {widget = widget, box = box, button = widget.NavButton, label = widget.NavText}
        return widget
    end
    function self:input(parent, hint, value)
        local input = self:make('EditableTextBox')
        input:SetHintText(FText(hint)); input:SetText(FText(value or ''))
        input:SetForegroundColor({R = 0.03, G = 0.03, B = 0.03, A = 1})
        local font = root.NavText.Font; font.Size = 17; input.WidgetStyle.TextStyle.Font = font
        self:fixed(parent, input, nil, 36)
        return input
    end
    function self:panel(width, height, side)
        local canvas, border, column = self:make('CanvasPanel'), self:make('Border'), self:column()
        root.WidgetTree.RootWidget = canvas
        border:SetBrushColor({R = 0.005, G = 0.005, B = 0.005, A = 0.95})
        border:SetPadding({Left = 24, Top = 18, Right = 24, Bottom = 16})
        border:SetContent(column)
        local slot = canvas:AddChildToCanvas(border)
        if side == 'hud' then
            slot:SetAnchors({Minimum = {X = 1, Y = 0}, Maximum = {X = 1, Y = 0}})
            slot:SetAlignment({X = 1, Y = 0}); slot:SetPosition({X = -30, Y = 30})
        else
            slot:SetAnchors({Minimum = {X = 0, Y = 0.5}, Maximum = {X = 0, Y = 0.5}})
            slot:SetAlignment({X = 0, Y = 0.5}); slot:SetPosition({X = 40, Y = 0})
        end
        slot:SetSize({X = width, Y = height})
        return column
    end
    return self
end
return Widgets
