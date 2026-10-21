local R=require('shared.runtime')
local Recovery={}
function Recovery.create(session)
    local self={starts={}}
    function self:update()
        if self.world~=R.worldKey()then self.starts={};self.world=R.worldKey()end
        if not session:isHost()then return end
        for _,row in ipairs(session.playerList)do
            local role=row.isLocal and 1 or 2
            if R.valid(row.pawn)and(not self.starts[role]or self.starts[role].pawn~=R.name(row.pawn))then
                local p,r=row.pawn:K2_GetActorLocation(),row.pawn:K2_GetActorRotation()
                self.starts[role]={pawn=R.name(row.pawn),position={X=p.X,Y=p.Y,Z=p.Z+10},rotation={Pitch=0,Yaw=r.Yaw,Roll=0}}
            end
        end
    end
    function self:recover(role)
        assert(session:isHost(),'Only the host can move a player.')
        local start=self.starts[role];assert(start,'Player spawn is not ready.')
        for _,row in ipairs(session.playerList)do
            if (row.isLocal and role==1 or not row.isLocal and role==2)and R.valid(row.pawn)then
                local movement=row.pawn.CharacterMovement
                if R.valid(movement)then movement:StopMovementImmediately()end
                assert(row.pawn:K2_TeleportTo(start.position,start.rotation),'Spawn is obstructed. Restart the range instead.')
                row.pawn:ForceNetUpdate()
                session.social:add('',role==1 and 'Host returned to spawn.'or 'Guest returned to spawn.',true)
                return true
            end
        end
        error('That player is not in the range.')
    end
    function self:restart()
        assert(session:isHost(),'Only the host can restart the range.')
        local path=require('lobby.ranges').maps[R.level()]
        assert(path and R.level()~='Bunker_Main','Enter a range first.')
        if session.beforeTravel then session.beforeTravel()end
        assert(StaticFindObject('/Script/AdvancedSessions.Default__AdvancedSessionsLibrary'):ServerTravel(R.world(),path..'?listen',true,false),'The game rejected range restart.')
        session.localReady=false;session.since=os.time();session:set('travelling','Restarting the range...')
    end
    return self
end
return Recovery
