local Round={}
local modes={practice=true,timed=true,race=true,turns=true}
local phases={practice=true,countdown=true,playing=true,settling=true,finished=true,cancelled=true}
local reasons={none=true,connection=true,sync=true,unready=true,reconnect=true}
function Round.create(clock)
    clock=clock or os.time
    local self={id=0,phase='practice',mode='practice',scores={0,0},hits={0,0},shots={0,0},turn=1,turnShots=0,reason='none',grace=1}
    function self:start(mode)
        assert(mode=='timed'or mode=='race'or mode=='turns','Unknown challenge')
        self.id=self.id+1;self.phase,self.mode='countdown',mode;self.lastMode=mode
        self.scores,self.hits,self.shots,self.turn,self.turnShots={0,0},{0,0},{0,0},1,0
        self.startsAt=clock()+3;self.deadline=mode=='timed'and self.startsAt+60 or nil
        self.endAt,self.settleUntil,self.reason,self.thresholdAt=nil,nil,'none',{}
    end
    function self:active()return self.phase=='countdown'or self.phase=='playing'or self.phase=='settling'end
    function self:finish()self.phase='finished';self.deadline=nil;self.settleUntil=nil end
    function self:cancel(reason)
        if not self:active()then return false end
        self.phase='cancelled';self.reason=reasons[reason]and reason or'connection';self.deadline=nil;self.settleUntil=nil
        return true
    end
    function self:reset()
        self.id=self.id+1;self.phase,self.mode='practice','practice';self.scores,self.hits,self.shots={0,0},{0,0},{0,0}
        self.startsAt,self.deadline,self.endAt,self.settleUntil=nil,nil,nil,nil;self.turn,self.turnShots,self.reason=1,0,'none';self.thresholdAt={}
    end
    function self:step()
        local now=clock()
        if self.phase=='countdown'and now>=self.startsAt then self.phase='playing'end
        if self.phase=='playing'and self.deadline and now>=self.deadline then
            self.phase='settling';self.endAt=self.deadline;self.settleUntil=self.deadline+self.grace
        end
        if self.phase=='settling'and now>=self.settleUntil then self:finish()end
    end
    function self:shot(role,at)
        self:step();at=at or clock()
        if role~=1 and role~=2 then return false end
        if self.phase~='practice'and self.phase~='playing'and self.phase~='settling'then return false end
        if self.mode~='practice'and(at<(self.startsAt or 0)or at>(self.endAt or self.deadline or math.huge))then return false end
        if self.mode=='turns'and role~=self.turn then return false end
        self.shots[role]=self.shots[role]+1
        if self.mode=='turns'then self.turnShots=self.turnShots+1;if self.turnShots>=5 then self.turn=3-self.turn;self.turnShots=0 end end
        return true
    end
    function self:hit(role,points,eligible,at)
        self:step();at=at or clock()
        if eligible==false or role~=1 and role~=2 then return false end
        if self.phase~='practice'and self.phase~='playing'and self.phase~='settling'then return false end
        if self.mode~='practice'and(at<(self.startsAt or 0)or at>(self.endAt or self.deadline or math.huge))then return false end
        points=math.max(0,math.min(100000,math.floor(points)))
        self.scores[role]=math.min(99999999,self.scores[role]+points);self.hits[role]=self.hits[role]+1
        if self.mode=='race'and self.scores[role]>=1000 and not self.thresholdAt[role]then
            self.thresholdAt[role]=at;self.endAt=math.min(self.endAt or math.huge,at)
            if self.phase~='settling'then self.phase='settling';self.settleUntil=clock()+self.grace end
        end
        return true
    end
    function self:winner()
        if self.phase~='finished'then return nil end
        if self.mode=='race'and self.thresholdAt then
            local a,b=self.thresholdAt[1],self.thresholdAt[2]
            if a and b then if math.abs(a-b)<0.025 then return 0 else return a<b and 1 or 2 end end
            if a or b then return a and 1 or 2 end
        end
        if self.result~=nil then return self.result end
        return self.scores[1]==self.scores[2]and 0 or(self.scores[1]>self.scores[2]and 1 or 2)
    end
    function self:remaining(now)
        now=now or clock()
        if self.phase=='countdown'then return math.max(0,(self.startsAt or now)-now)end
        return self.deadline and math.max(0,self.deadline-now)or 0
    end
    function self:encode()
        return table.concat({self.id,self.mode,self.phase,string.format('%.3f',self.startsAt or 0),string.format('%.3f',self.deadline or 0),self.turn,self.turnShots,
            self.scores[1],self.scores[2],self.hits[1],self.hits[2],self.shots[1],self.shots[2],self.reason,self:winner()or -1},',')
    end
    function self:apply(data)
        local id,mode,phase,start,deadline,turn,turnShots,a,b,ha,hb,sa,sb,reason,winner=data:match('^(%d+),(%a+),(%a+),([^,]+),([^,]+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%a+),([%-0-9]+)$')
        if not id or not modes[mode]or not phases[phase]or not reasons[reason]then return false end
        local n=require('gameplay.wire').numbers(table.concat({start,deadline,turn,turnShots,a,b,ha,hb,sa,sb,winner},','),11,99999999)
        if not n or n[3]~=1 and n[3]~=2 or n[4]>4 or n[11]< -1 or n[11]>2 then return false end
        for i,value in ipairs(n)do if i<11 and value<0 or i>=3 and value%1~=0 then return false end end
        self.id,self.mode,self.phase=tonumber(id),mode,phase
        self.startsAt,self.deadline=n[1],n[2]>0 and n[2]or nil
        self.turn,self.turnShots,self.scores,self.hits,self.shots=n[3],n[4],{n[5],n[6]},{n[7],n[8]},{n[9],n[10]}
        self.reason,self.result,self.lastMode=reason,n[11]>=0 and n[11]or nil,mode~='practice'and mode or self.lastMode
        return true
    end
    return self
end
return Round
