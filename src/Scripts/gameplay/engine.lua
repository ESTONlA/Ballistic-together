local R=require('shared.runtime')
local Wire=require('gameplay.wire')
local Engine={}
local generation=0
local function now()return R.gameplay():GetRealTimeSeconds(R.world())end
local function vector(n,i)return{X=n[i],Y=n[i+1],Z=n[i+2]}end
local function coordinates(p)return string.format('%.1f,%.1f,%.1f',p.X,p.Y,p.Z)end
function Engine.create(session)
    local self={session=session,epoch='',world='',remotePose={},retiredEpochs={},retiredOrder={}}
    self.effects=require('gameplay.effects').create()
    self.recovery=require('gameplay.recovery').create(session)
    function self:hostNow()return session:isHost()and now()or(self.clock and self.clock:remoteNow(now())or now())end
    function self:visual(callback)
        local ok,message=pcall(callback)
        if not ok and not self.visualError then self.visualError=true;R.log('Shot effect: '..tostring(message))end
    end
    function self:resetStream(epoch)
        local values={}
        if self.targets and self.targets.world==R.worldKey()then for key,entry in pairs(self.targets.entries)do values[key]=entry.sessionValue end end
        if self.epoch~=''and self.epoch~=(epoch or'')then
            self.retiredEpochs[self.epoch]=true;self.retiredOrder[#self.retiredOrder+1]=self.epoch
            if #self.retiredOrder>32 then self.retiredEpochs[table.remove(self.retiredOrder,1)]=nil end
        end
        if self.targets then self.targets:clear()end
        self.epoch=epoch or '';self.journal=require('gameplay.journal').create()
        self.targets=require('gameplay.targets').create();self.targets:discover()
        for key,value in pairs(values)do if self.targets.entries[key]then self.targets.entries[key].sessionValue=value end end
        self.peerAck,self.batchAck,self.remoteBatch=0,0,0
        self.shots,self.bullets,self.hitDedupe={}, {}, {};self.shotId=0;self.lastShot=nil
        self.remotePose={};self.remoteCount=0;self.localReload=0
        self.clock=require('gameplay.clock').create();self.peerAt=nil;self.remoteReady=false
        self.baselineReady=false
        self.metrics={localShots=0,localHits=0,peerShots=0,peerHits=0,rejectedTime=0,audio=0}
    end
    function self:clear()
        if self.epoch~=''then self.retiredEpochs[self.epoch]=true;self.retiredOrder[#self.retiredOrder+1]=self.epoch;if #self.retiredOrder>32 then self.retiredEpochs[table.remove(self.retiredOrder,1)]=nil end end
        if self.targets then self.targets:clear()end
        self.effects:clear();self.world='';self.epoch='';self.peerNonce=nil
        self.remotePose={};self.round=nil
    end
    function self:available()
        return session:active()and require('lobby.ranges').maps[R.level()]~=nil and R.level()~='Bunker_Main'
    end
    function self:role()return session:isHost()and 1 or 2 end
    function self:ready()return self:available()and self.epoch~=''and(session:isHost()or self.peerAt~=nil and self.baselineReady)end
    function self:health()
        if session.players~=2 or not session.metadata.remote or session.metadata.dataDelayed then return 'connection'end
        if not self.peerAt or now()-self.peerAt>1.5 or not self.clock:ready(now())or(not self.round:active()and self.remoteCount<#self.targets.order)then return 'sync'end
        if not session.localReady or not self.remoteReady or session.social.away then return 'unready'end
    end
    function self:emit(kind,body)
        local id,message=self.journal:push(kind,body)
        if not id and (not self.warned or os.time()-self.warned>=5)then self.warned=os.time();session.social:add('',message,true)end
        return id
    end
    function self:tick()
        if not self:available()then if self.world~=''then self:clear()end;return end
        if self.world~=R.worldKey()then
            self.world=R.worldKey();generation=generation+1
            self.round=require('gameplay.round').create(function()return self:hostNow()end)
            self:resetStream(session:isHost()and(session.social.nonce..'_'..generation)or'')
            self.discoverAt=0
        end
        local time=now()
        if time>=self.discoverAt then self.targets:discover();self.discoverAt=time+3 end
        if session:isHost()then
            self.targets:update()
            if self.round:active()then
                local reason=self:health()
                if reason and self.round:cancel(reason)then session.social:add('','Round cancelled: '..({connection='player disconnected or connection delayed.',sync='waiting for player synchronization.',unready='a player is no longer ready.'})[reason],true)end
            end
            self.round:step()
        end
        local state=self.round.id..':'..self.round.phase
        if self.roundNotice~=state then
            self.roundNotice=state
            if self.round.phase=='finished'or self.round.phase=='cancelled'then session.social:add('',self:summary():match('^[^\n]+'),true)end
        end
        self.recovery:update()
        require('gameplay.hooks').install(self)
        for _,entry in pairs(self.targets.entries)do
            if entry.pendingHit and time-entry.pendingHit.time>0.1 then self:finishHit(entry,self.lastShot)end
        end
        for key,shot in pairs(self.shots)do if time-shot.time>8 then self.shots[key]=nil end end
        for key,shot in pairs(self.bullets)do if time-shot.time>8 then self.bullets[key]=nil end end
        for key,timeHit in pairs(self.hitDedupe)do if time-timeHit>8 then self.hitDedupe[key]=nil end end
    end
    function self:updateEffects()self.effects:update();if self.targets and not session:isHost()then self.targets:render()end end
    function self:outgoing()
        if not self:available()or not self.journal then return ''end
        local pc=R.player();local pawn=R.valid(pc)and pc:K2_GetPawn()or nil
        local aim,pitch=0,0
        if R.valid(pawn)then local ok,a=pcall(function()return pawn.Aiming end);aim=ok and a and 1 or 0;pitch=pc:GetControlRotation().Pitch;if pitch>180 then pitch=pitch-360 end end
        local batch,id='',0
        if session:isHost()then batch,id=self.targets:batch(self.batchAck)end
        local pose=string.format('%d,%.1f,%.2f,%d,%s,%d',aim,math.max(-85,math.min(85,pitch)),math.max(0,self.localReload-now()),session:isHost()and #self.targets.order or self.targets.receivedCount,self.clock:fields(now()),session.localReady and 1 or 0)
        return Wire.pack({R.level(),self.epoch,self.journal.seen,self.journal:out(self.peerAck),session:isHost()and self.round:encode()or'',batch,id,self.remoteBatch,pose,session:isHost()and self.targets:motion()or''})
    end
    function self:receive(data,nonce,acknowledged)
        if not self:available()or not self.journal then return false end
        local packet=Wire.unpack(data)
        if not packet or packet.level~=R.level()or self.retiredEpochs[packet.epoch]then return false end
        if self.peerNonce~=nonce then
            self.peerNonce=nonce
            if session:isHost()then
                if self.round:cancel('reconnect')then session.social:add('','Round cancelled because the guest reconnected. Ready up for a rematch.',true)end
                generation=generation+1;self:resetStream(session.social.nonce..'_'..generation)
            end
        end
        if not session:isHost()and packet.epoch~=''and packet.epoch~=self.epoch then self:resetStream(packet.epoch)end
        if packet.epoch==''or packet.epoch~=self.epoch then return false end
        if acknowledged then self.peerAck=packet.ack;self.batchAck=packet.batchAck end
        local pose=Wire.numbers(packet.pose,8,10000000)
        if pose then
            self.peerAt=now();self.remoteReady=pose[8]==1
            self.clock:observe(pose[5],pose[6],pose[7],now())
            self.remotePose.aim=pose[1]==1;self.remotePose.pitch=math.max(-85,math.min(85,pose[2]))
            self.remotePose.reloadUntil=now()+math.max(0,math.min(2,pose[3]))
            self.remoteCount=math.floor(math.max(0,pose[4]))
        end
        if not session:isHost()then
            if not self.round:apply(packet.round)then return false end
            if self.targets:apply(packet.targets,self.remoteCount)then self.remoteBatch=packet.batch end
            if self.targets.receivedCount>=self.remoteCount then self.baselineReady=true end
            self.targets:applyMotion(packet.motion)
        end
        return self.journal:receive(packet.events,nonce,function(kind,body)return self:apply(kind,body,3-self:role())end)
    end
    function self:registerShot(role,id,roundId,start,finish,at,sound)
        local key=role..':'..id
        if self.shots[key]then return false end
        local eligible=roundId==self.round.id and (not session:isHost()or self.round:shot(role,at))
        self.shots[key]={time=now(),roundId=roundId,eligible=eligible,start=start,hits={},at=at or self:hostNow()}
        if role~=self:role()then
            self.metrics.peerShots=self.metrics.peerShots+1
            self:visual(function()self.effects:shot(key,start,finish);self:playAudio('shot',sound,start)end);self.remotePose.firedAt=now()
        end
        return true
    end
    function self:score(role,id,key,points,at)
        local shot=self.shots[role..':'..id]
        if not shot or shot.hits[key]or shot.roundId~=self.round.id then return false end
        shot.hits[key]=true
        return self.round:hit(role,points,shot.eligible,at)
    end
    function self:playAudio(kind,id,point)
        if not session.preferences or session.preferences.values.RemoteAudio~=false then
            if require('gameplay.audio').play(kind,id,point)then self.metrics.audio=self.metrics.audio+1 end
        end
    end
    function self:apply(kind,body,role)
        if kind=='S'then
            local n=Wire.numbers(body,10);if not n or n[1]<1 or n[1]%1~=0 then return true end
            local at=session:isHost()and self.clock:toLocal(n[9],now())or n[9]
            if not at then self.metrics.rejectedTime=self.metrics.rejectedTime+1;return true end
            self:registerShot(role,n[1],n[2],vector(n,3),vector(n,6),at,n[10])
        elseif kind=='I'then
            local n=Wire.numbers(body,4);if n and self.shots[role..':'..n[1]]then self:visual(function()self.effects:impact(role..':'..n[1],vector(n,2))end)end
        elseif kind=='H'then
            local key,rest=body:match('^(%x+),(.+)$');local n=rest and Wire.numbers(rest,10)
            if not n or #key~=8 then return true end
            local shot=self.shots[role..':'..n[1]]
            if not shot or shot.roundId~=n[2]or shot.hits[key]then return true end
            local point=vector(n,3)
            local at=session:isHost()and self.clock:toLocal(n[10],now())or n[10]
            if not at or at<shot.at-0.1 then self.metrics.rejectedTime=self.metrics.rejectedTime+1;return true end
            if session:isHost()then
                local points=self.targets:hit(key,point,n[6]==1,math.max(0,math.min(1000000,n[7])),math.max(0,math.min(1000000,n[8])),shot.start)
                if points then self:score(role,n[1],key,points,at);self.metrics.peerHits=self.metrics.peerHits+1 end
            else shot.hits[key]=true;self.metrics.peerHits=self.metrics.peerHits+1 end
            self:visual(function()self.effects:impact(role..':'..n[1],point)end)
        elseif kind=='R'then
            local n=Wire.numbers(body,5)
            if n then self.remotePose.reloadUntil=now()+(n[1]==1 and 1.5 or 0.2);self:visual(function()self:playAudio('handling',n[2],vector(n,3))end)end
        elseif kind=='Q'and session:isHost()then
            if not self.lastRecovery or now()-self.lastRecovery>=5 then
                self.lastRecovery=now()
                if body=='resync'then self:resync()elseif body=='1'then pcall(function()self.recovery:recover(2)end)end
            end
        end
        return true
    end
    function self:localShot(weapon,barrel,bullets,cartridge)
        if not self:ready()then return end
        local pc=R.player();local pawn=R.valid(pc)and pc:K2_GetPawn()or nil
        if not R.valid(pawn)or R.name(require('avatars.weapons').equipped(pawn))~=R.name(weapon)then return end
        local camera=R.gameplay():GetPlayerCameraManager(R.world(),0)
        local raw=R.valid(barrel)and R.valid(barrel.Muzzle)and barrel.Muzzle:K2_GetComponentLocation()or camera:GetCameraLocation()
        local start={X=raw.X,Y=raw.Y,Z=raw.Z}
        local direction=StaticFindObject('/Script/Engine.Default__KismetMathLibrary'):GetForwardVector(camera:GetCameraRotation())
        local finish={X=start.X+direction.X*30000,Y=start.Y+direction.Y*30000,Z=start.Z+direction.Z*30000}
        self.shotId=self.shotId+1;local id=self.shotId
        local sound=require('gameplay.audio').capture(weapon,cartridge)
        if not self:emit('S',id..','..self.round.id..','..coordinates(start)..','..coordinates(finish)..','..string.format('%.3f',now())..','..sound)then self.lastShot=nil;return end
        self:registerShot(self:role(),id,self.round.id,start,finish,self:hostNow());self.lastShot=id;self.metrics.localShots=self.metrics.localShots+1
        if bullets then for i=1,math.min(#bullets,64)do local bullet=R.object(bullets[i]);if bullet then self.bullets[tostring(bullet:GetAddress())]={id=id,time=now()}end end end
    end
    function self:localImpact(bullet,info)
        if not self:ready()then return end
        local shot=self.bullets[tostring(bullet:GetAddress())]
        if shot then self:emit('I',shot.id..','..coordinates(info.ImpactPoint))end
    end
    function self:localHit(actor,player,info,energy,velocity,breaking)
        if not self:ready()or R.name(player)~=R.name(R.player():K2_GetPawn())or not self.lastShot then return end
        local entry=self.targets:entry(actor);if not entry then return end
        local point=info.ImpactPoint
        local points=self.targets:points(entry)
        entry.pendingHit={point={X=point.X,Y=point.Y,Z=point.Z},points=points,energy=energy,velocity=velocity,breaking=breaking,time=now()}
    end
    function self:finishHit(entry,id)
        local hit=entry.pendingHit;entry.pendingHit=nil
        if not hit or not id then return end
        local shot=self.shots[self:role()..':'..id]
        if not shot or now()-shot.time>8 then return end
        local key=id..':'..entry.key
        if self.hitDedupe[key]then return end
        self.hitDedupe[key]=now()
        if session:isHost()then self:score(1,id,entry.key,hit.points,hit.time);entry.priority=os.time()+4 end
        self.metrics.localHits=self.metrics.localHits+1
        self:emit('H',entry.key..','..id..','..shot.roundId..','..coordinates(hit.point)..','..(hit.breaking and 1 or 0)..','..math.floor(math.min(1000000,hit.energy))..','..math.floor(math.min(1000000,hit.velocity))..','..math.floor(math.max(0,math.min(100000,hit.points)))..','..string.format('%.3f',hit.time))
    end
    function self:trackHit(actor,player,bullet)
        if not self:ready()or not R.valid(bullet)or R.name(player)~=R.name(R.player():K2_GetPawn())then return end
        local entry=self.targets:entry(actor);local shot=self.bullets[tostring(bullet:GetAddress())]
        if entry and shot then self:finishHit(entry,shot.id)end
    end
    function self:reload(weapon,insert)
        if not self:ready()then return end
        if R.name(require('avatars.weapons').equipped(R.player():K2_GetPawn()))==R.name(weapon)then
            self.localReload=now()+(insert and 0.2 or 1.5)
            self:emit('R',(insert and 2 or 1)..','..require('gameplay.audio').handlingId(weapon,insert)..','..coordinates(weapon:K2_GetActorLocation()))
        end
    end
    function self:start(mode)
        assert(session:isHost()and self:ready(),'The host must enter a range first.')
        local reason=self:health()
        assert(not reason,({connection='Wait for both players to connect.',sync='Wait for targets and clocks to finish syncing.',unready='Both players must press Ready [F9].'})[reason])
        assert(not self.round:active(),'Finish or cancel the current round first.')
        self.round:start(mode);session.social:add('',({timed='60-second round',race='First to 1000 points',turns='Five shots per turn'})[mode]..' starts in 3 seconds.',true)
    end
    function self:rematch()assert(self.round and self.round.lastMode,'Choose a challenge first.');self:start(self.round.lastMode)end
    function self:resync()
        assert(self:available()and self.journal,'Enter a range first.')
        if not session:isHost()then assert(self:emit('Q','resync'),'Connection is catching up.');return end
        self.round:cancel('sync');generation=generation+1;self:resetStream(session.social.nonce..'_'..generation)
        session.social:add('','Resynchronizing targets and player clocks. Ready up again when synchronization finishes.',true)
        session.localReady=false
    end
    function self:recover()
        assert(self:available(),'Enter a range first.')
        if session:isHost()then self.recovery:recover(1)else assert(self:emit('Q','1'),'Connection is catching up.')end
    end
    function self:summary()
        if not self.round or not self:available()then return 'Enter a range to shoot together.'end
        local round=self.round;local remaining=math.ceil(round:remaining(self:hostNow()))
        local label=({practice='Practice',timed='60-second round',race='First to 1000',turns='Five shots per turn'})[round.mode]
        if round.phase=='countdown'then label='Starting in '..remaining..'...'
        elseif round.phase=='settling'then label='Finishing round...'
        elseif round.phase=='cancelled'then label='Round cancelled / '..({connection='Connection interrupted',sync='Player still syncing',unready='Player not ready',reconnect='Player reconnected',none='Stopped'})[round.reason]
        elseif round.phase=='finished'then
            local winner=round:winner();label=winner==0 and 'Draw!'or(winner==self:role()and 'You win!'or'Your friend wins!')
        elseif round.mode=='timed'then label=label..' / '..remaining..'s'
        elseif round.mode=='turns'then label=(round.turn==self:role()and 'YOUR TURN'or"FRIEND'S TURN")..' / '..(5-round.turnShots)..' shots left'end
        return label..string.format('\nHost %d   /   Guest %d',round.scores[1],round.scores[2])
    end
    return self
end
return Engine
