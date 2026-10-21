local R = require('shared.runtime')
local Widgets = require('ui.widgets')
local Hud = {}
function Hud.create(session)
    local self = {notice = '', untilTime = 0}
    function self:notify(message)
        self.notice, self.untilTime = message, os.time() + 6
    end
    function self:update()
        if self.world ~= R.worldKey() then self.widget = nil; self.world = R.worldKey() end
        if (not session:active() and os.time() >= self.untilTime) or not session.preferences.values.ShowHud then
            if R.valid(self.widget) then self.widget:SetVisibility(1) end
            return
        end
        if not R.valid(self.widget) then
            local w = Widgets.create(); self.widget = w.root
            local column = w:panel(430, 260, 'hud')
            self.title = w:text(column, '', 18)
            self.body = w:text(column, '', 15)
            self.alert = w:text(column, '', 15)
            w:text(column, 'F8  Lobby    F7  Rally marker', 12, true)
            self.widget:AddToViewport(90)
        end
        self.widget:SetVisibility(3)
        self.title:SetText(FText(session:active() and ('Together   ' .. session.players .. '/2') or 'Ballistic Together'))
        local lines = {}
        for _, row in ipairs(session.playerList) do
            if not row.isLocal then lines[#lines + 1] = string.format('%s  /  %.0f ms  /  %s', row.name, row.ping or 0, row.away and 'Away' or (row.ready and 'Ready' or 'Not ready')) end
        end
        local seconds = session:isHost() and session.countdown:remaining() or (session.metadata.remote and session.social.remoteCountdown or 0)
        if seconds > 0 then lines[#lines + 1] = 'Entering range in ' .. seconds .. '...' end
        if session.metadata.mismatch then lines[#lines + 1] = 'Update the mod on both PCs.' end
        if session.metadata.dataDelayed then lines[#lines + 1] = 'Connection updates delayed.' end
        if session.gameplay and session.gameplay:available() then lines[#lines + 1] = session.gameplay:summary() end
        self.body:SetText(FText(table.concat(lines, '\n')))
        self.alert:SetText(FText(os.time() < self.untilTime and self.notice or ''))
    end
    return self
end
return Hud
