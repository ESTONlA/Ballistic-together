local R=require('shared.runtime')
local W=require('gameplay.wire')
local Targets={}
local function now()return R.gameplay():GetRealTimeSeconds(R.world())end
local function classPath(actor)return R.name(actor:GetClass()):match('%s(/Game/BlueprintLogic/Targets/[%w_/%.-]+)$')end
local function objectName(actor)return R.name(actor):match('%.([^%.: ]+)$')end
local function position(value)return{X=value.X,Y=value.Y,Z=value.Z}end
local function rotation(value)return{Pitch=value.Pitch,Yaw=value.Yaw,Roll=value.Roll}end
local function finite(value)return type(value)=='number'and value==value and math.abs(value)<10000000 end
local function validPosition(value)return value and finite(value.X)and finite(value.Y)and finite(value.Z)end
local function validRotation(value)return value and finite(value.Pitch)and finite(value.Yaw)and finite(value.Roll)end
local function body(actor)
    local meshes=actor:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.PrimitiveComponent'))
    local objects={}
    for i=1,math.min(#meshes,64)do
        local mesh=R.object(meshes[i]);if mesh then objects[#objects+1]=mesh end
    end
    for _,mesh in ipairs(objects)do
        if mesh:IsA(StaticFindObject('/Script/Engine.StaticMeshComponent'))or mesh:IsA(StaticFindObject('/Script/Engine.SkeletalMeshComponent'))then return mesh end
    end
end
function Targets.create()
    local self={entries={},order={},byActor={},acknowledged={},batches={},nextBatch=0,cursor=1,received={},receivedCount=0,world=R.worldKey(),rendering={},time=now()}
    function self:clear()
        if self.world~=R.worldKey()then return end
        for _,entry in pairs(self.entries)do
            if R.valid(entry.actor)then
                if entry.spawned then entry.actor:K2_DestroyActor()
                elseif entry.client then
                    entry.actor:SetActorTickEnabled(entry.wasTicking)
                    entry.actor:SetActorHiddenInGame(entry.wasHidden);entry.actor:SetActorEnableCollision(entry.wasCollision)
                    if R.valid(entry.body)then entry.body:SetSimulatePhysics(entry.wasPhysics)end
                end
            end
        end
    end
    function self:discover()
        local actors={}
        local class=LoadAsset('/Game/BlueprintLogic/Targets/TargetBase.TargetBase_C')
        if not R.valid(class)then return end
        R.gameplay():GetAllActorsOfClass(R.world(),class,actors)
        local objects={}
        for i=1,math.min(#actors,2000)do
            local actor=R.object(actors[i]);if actor then objects[#objects+1]=actor end
        end
        for _,actor in ipairs(objects)do
            if not R.name(actor):find('Default__',1,true)then
                local address=tostring(actor:GetAddress())
                if not self.byActor[address]then
                    local path,name=classPath(actor),objectName(actor)
                    if path and name and #path<=160 and #name<=80 then
                        local key=W.hash(path..':'..name)
                        if not self.entries[key]then
                            local entry={key=key,actor=actor,path=path,name=name,body=body(actor),revision=0,lastSent=0,sessionValue=math.max(0,math.min(100000,math.floor(actor.HitValue)))}
                            self.entries[key]=entry;self.order[#self.order+1]=key;self.byActor[address]=entry
                        end
                    end
                end
            end
        end
        table.sort(self.order)
    end
    function self:entry(actor)
        return actor and self.byActor[tostring(actor:GetAddress())]or nil
    end
    function self:points(entry)return entry.sessionValue or 0 end
    function self:capture(entry)
        entry.sampledAt=self.time
        local actor=entry.actor
        local data='0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0'
        if R.valid(actor)then
            local p=position(actor:K2_GetActorLocation())
            local r=rotation(actor:K2_GetActorRotation())
            local bp,br=p,r
            if R.valid(entry.body)then bp=position(entry.body:K2_GetComponentLocation());br=rotation(entry.body:K2_GetComponentRotation())end
            if not validPosition(p)or not validRotation(r)or not validPosition(bp)or not validRotation(br)then
                entry.body=body(actor)
                if not entry.poseWarning then entry.poseWarning=true;R.log('Skipping incomplete target pose: '..entry.name)end
                return
            end
            data=string.format('1,%d,%d,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f',
                actor.HasBeenHit and 1 or 0,actor.bHidden and 1 or 0,math.max(0,math.min(100000,actor.HitValue)),
                p.X,p.Y,p.Z,r.Pitch,r.Yaw,r.Roll,bp.X,bp.Y,bp.Z,br.Pitch,br.Yaw,br.Roll)
        end
        if data~=entry.data then
            if entry.data then entry.activeUntil=self.time+1.5 end
            entry.revision=entry.revision+1;entry.data=data
            local values=W.numbers(data,16);entry.motionPose={table.unpack(values,5,16)}
        end
    end
    function self:sample(entry)
        local ok,message=pcall(self.capture,self,entry)
        if not ok then
            if not entry.poseWarning then entry.poseWarning=true;R.log('Target pose read deferred: '..entry.name..' '..tostring(message))end
            if R.valid(entry.actor)then entry.body=body(entry.actor)end
        end
    end
    function self:update()
        self.time=now()
        if #self.order==0 then return end
        local captured={}
        for _=1,math.min(32,#self.order)do
            local entry=self.entries[self.order[self.cursor]];self:sample(entry);captured[entry.key]=true
            self.cursor=self.cursor%#self.order+1
        end
        local time=self.time;local active={}
        for _,entry in pairs(self.entries)do
            local moving=R.valid(entry.actor)and entry.actor.isMoving
            if not captured[entry.key]and(moving or(entry.activeUntil or 0)>=time or(entry.priority or 0)>=os.time())then active[#active+1]=entry end
        end
        table.sort(active,function(a,b)if(a.sampledAt or -1)~=(b.sampledAt or -1)then return(a.sampledAt or -1)<(b.sampledAt or -1)end;return a.key<b.key end)
        for i=1,math.min(32,#active)do self:sample(active[i])end
    end
    function self:batch(ack)
        if self.batches[ack]then
            for key,version in pairs(self.batches[ack])do self.acknowledged[key]=math.max(self.acknowledged[key]or 0,version)end
            self.batches[ack]=nil
        end
        local pending={}
        for _,entry in pairs(self.entries)do if entry.data and entry.revision>(self.acknowledged[entry.key]or 0)then pending[#pending+1]=entry end end
        table.sort(pending,function(a,b)
            local ap,bp=(self.acknowledged[a.key]or 0)==0 and math.huge or(a.priority or 0),(self.acknowledged[b.key]or 0)==0 and math.huge or(b.priority or 0)
            if ap~=bp then return ap>bp end
            if a.lastSent~=b.lastSent then return a.lastSent<b.lastSent end
            return a.key<b.key
        end)
        local lines,versions,size={},{},0
        self.nextBatch=self.nextBatch+1
        for _,entry in ipairs(pending)do
            local line=table.concat({entry.key,entry.revision,entry.path,entry.name,entry.data},'|')
            if size+#line+1<=2200 and #lines<6 then
                lines[#lines+1]=line;size=size+#line+1;versions[entry.key]=entry.revision;entry.lastSent=self.nextBatch
            end
        end
        self.batches[self.nextBatch]=versions;self.batches[self.nextBatch-64]=nil
        return table.concat(lines,'\n'),self.nextBatch
    end
    function self:motion()
        local candidates={};local time=self.time
        for _,entry in pairs(self.entries)do
            if entry.motionPose and R.valid(entry.actor)and(entry.actor.isMoving or(entry.activeUntil or 0)>=time)then candidates[#candidates+1]=entry end
        end
        table.sort(candidates,function(a,b)return(a.motionSent or -1)<(b.motionSent or -1)end)
        local lines,size={},0
        for _,entry in ipairs(candidates)do
            local values={};for i,value in ipairs(entry.motionPose)do values[i]=string.format('%.1f',value)end
            local line=entry.key..'|'..entry.revision..'|'..table.concat(values,',')
            if size+#line+1<=1800 then lines[#lines+1]=line;size=size+#line+1;entry.motionSent=time end
        end
        return table.concat(lines,'\n')
    end
    function self:pose(entry,values)
        entry.actor:K2_SetActorLocationAndRotation({X=values[1],Y=values[2],Z=values[3]},{Pitch=values[4],Yaw=values[5],Roll=values[6]},false,{},true)
        if R.valid(entry.body)then entry.body:K2_SetWorldLocationAndRotation({X=values[7],Y=values[8],Z=values[9]},{Pitch=values[10],Yaw=values[11],Roll=values[12]},false,{},true)end
    end
    function self:queuePose(entry,revision,values)
        if revision<=(entry.poseRevision or 0)then return end
        entry.poseRevision=revision
        if not entry.motionBuffer then entry.motionBuffer=require('gameplay.target_motion').create();self:pose(entry,values)end
        entry.motionBuffer:push(values,now());self.rendering[entry.key]=entry
    end
    function self:applyMotion(data)
        if #data>1800 then return false end
        for line in data:gmatch('[^\n]+')do
            local key,revision,rest=line:match('^(%x+)|(%d+)|(.+)$')
            local values=rest and W.numbers(rest,12)
            if not values or #key~=8 or #revision>8 then return false end
            local entry=self.entries[key]
            if entry and entry.client and self.received[key]and R.valid(entry.actor)and not entry.actor.bHidden then self:queuePose(entry,tonumber(revision),values)end
        end
        return true
    end
    function self:render()
        for key,entry in pairs(self.rendering)do
            if R.valid(entry.actor)and not entry.actor.bHidden then
                local values,done=entry.motionBuffer:sample(now())
                if values then self:pose(entry,values)end
                if done then self.rendering[key]=nil end
            else self.rendering[key]=nil end
        end
    end
    function self:apply(data,total)
        local complete=true
        for line in data:gmatch('[^\n]+')do
            local key,revision,path,name,state=line:match('^(%x+)|(%d+)|([^|]+)|([^|]+)|([^|]+)$')
            local values=state and W.numbers(state,16)
            if not values or #key~=8 or #revision>8 or #path>160 or #name>80 or not path:match('^/Game/BlueprintLogic/Targets/[%w_/%.-]+_C$')or not name:match('^[%w_]+$')then return false end
            if (values[1]~=0 and values[1]~=1)or(values[2]~=0 and values[2]~=1)or(values[3]~=0 and values[3]~=1)or values[4]<0 or values[4]>100000 then return false end
            revision=tonumber(revision)
            local entry=self.entries[key]
            if (not entry or not R.valid(entry.actor))and values[1]==1 then
                local class=LoadAsset(path)
                if R.valid(class)then
                    local actor=R.world():SpawnActor(class,{X=values[5],Y=values[6],Z=values[7]},{Pitch=values[8],Yaw=values[9],Roll=values[10]})
                    if R.valid(actor)then
                        actor:SetReplicates(false)
                        entry={key=key,actor=actor,path=path,name=name,body=body(actor),revision=0,spawned=true}
                        self.entries[key]=entry;self.byActor[tostring(actor:GetAddress())]=entry
                    end
                end
            end
            if entry and revision>(self.received[key]or 0)then
                local actor=entry.actor
                if R.valid(actor)then
                    if not entry.client then
                        entry.wasTicking=actor:IsActorTickEnabled();entry.wasHidden=actor.bHidden;entry.wasCollision=actor:GetActorEnableCollision()
                        entry.wasPhysics=R.valid(entry.body)and entry.body:IsSimulatingPhysics(FName('None'))or false;entry.client=true
                    end
                    actor:SetActorTickEnabled(false)
                    local visible=values[1]==1 and values[3]==0
                    actor:SetActorHiddenInGame(not visible);actor:SetActorEnableCollision(visible)
                    actor.HasBeenHit=values[2]==1;actor.HitValue=values[4]
                    if R.valid(entry.body)then
                        entry.body:SetSimulatePhysics(false)
                    end
                    if visible then self:queuePose(entry,revision,{table.unpack(values,5,16)})end
                end
            elseif not entry and values[1]==1 then complete=false end
            if entry or values[1]==0 then
                if not self.received[key]then self.receivedCount=self.receivedCount+1 end
                self.received[key]=math.max(self.received[key]or 0,revision)
            end
        end
        if total and total>0 and self.receivedCount>=total then
            for key,entry in pairs(self.entries)do if not self.received[key]and R.valid(entry.actor)then
                if not entry.client then entry.wasTicking=entry.actor:IsActorTickEnabled();entry.wasHidden=entry.actor.bHidden;entry.wasCollision=entry.actor:GetActorEnableCollision();entry.wasPhysics=R.valid(entry.body)and entry.body:IsSimulatingPhysics(FName('None'))or false;entry.client=true end
                entry.actor:SetActorHiddenInGame(true);entry.actor:SetActorEnableCollision(false);entry.actor:SetActorTickEnabled(false)
            end end
        end
        return complete
    end
    function self:hit(key,point,breaking,energy,velocity,source)
        local entry=self.entries[key]
        if not entry or not R.valid(entry.actor)or entry.actor.bHidden then return nil end
        local actor=entry.actor
        if actor.ValidForOneHitOnly and actor.HasBeenHit then return nil end
        local center=R.valid(entry.body)and entry.body:K2_GetComponentLocation()or actor:K2_GetActorLocation()
        local dx,dy,dz=point.X-center.X,point.Y-center.Y,point.Z-center.Z
        if dx*dx+dy*dy+dz*dz>500*500 then return nil end
        local points=self:points(entry)
        actor.HasBeenHit=true
        actor.HitValue=math.max(actor.MinHitValue,actor.HitValue*actor.HitValueMultOnHit)
        local normal={X=0,Y=0,Z=1}
        local info=R.gameplay():MakeHitResult(true,false,1,0,point,point,normal,normal,nil,actor,entry.body or actor.RootComponent,FName('None'),FName('None'),-1,0,-1,point,point)
        actor:CosmeticOnHit(info,energy,velocity or 10000)
        if breaking and actor.Breakable and energy>=actor.BreakEnergyThreshold then actor:SetActorHiddenInGame(true);actor:SetActorEnableCollision(false)
        elseif R.valid(entry.body)and entry.body:IsSimulatingPhysics(FName('None'))then
            source=source or{X=point.X,Y=point.Y-100,Z=point.Z}
            local x,y,z=point.X-source.X,point.Y-source.Y,point.Z-source.Z
            local length=math.max(1,math.sqrt(x*x+y*y+z*z));local impulse=math.min(20000,energy*5)
            entry.body:AddImpulseAtLocation({X=x/length*impulse,Y=y/length*impulse,Z=z/length*impulse},point,FName('None'))
        end
        entry.priority=os.time()+4;self:capture(entry)
        return math.max(0,math.min(100000,points))
    end
    return self
end
return Targets
