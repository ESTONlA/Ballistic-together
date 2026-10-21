local names={'shared.runtime','gameplay.targets','gameplay.effects','gameplay.recovery','gameplay.hooks','gameplay.engine','gameplay.audio'}
local saved={};for _,name in ipairs(names)do saved[name]=package.loaded[name]end
local function run()
 local time,world=0,'world1'
 local noop=function()end
 local R={worldKey=function()return world end,level=function()return 'Range_SwimmingPool'end,world=function()return{}end,
  valid=function()return false end,player=function()return nil end,log=noop,gameplay=function()return{GetRealTimeSeconds=function()return time end}end}
 package.loaded['shared.runtime']=R
 local damaged=0
 package.loaded['gameplay.targets']={create=function()return{order={'target'},entries={},receivedCount=0,discover=noop,clear=noop,update=noop,render=noop,motion=function()return ''end,applyMotion=noop,
  batch=function()return 'state',1 end,apply=function(self)self.receivedCount=1;return true end,
  hit=function()damaged=damaged+1;return 15 end}end}
 package.loaded['gameplay.effects']={create=function()return{clear=noop,update=noop,shot=noop,impact=noop}end}
 package.loaded['gameplay.recovery']={create=function()return{update=noop,recover=noop}end}
 package.loaded['gameplay.hooks']={install=noop};package.loaded['gameplay.engine']=nil
 package.loaded['gameplay.audio']={play=function()return true end}
 local Engine=require('gameplay.engine')
 local function session(host,nonce)
  return{isHost=function()return host end,active=function()return true end,social={nonce=nonce,add=noop},players=2,localReady=true,playerList={},metadata={remote={}},preferences={values={}}}
 end
 local hs,gs=session(true,'host'),session(false,'guest')
 local host,guest=Engine.create(hs),Engine.create(gs)
 local function exchange()
  time=time+0.1;host:tick();guest:tick()
  guest:receive(host:outgoing(),'host',true);host:receive(guest:outgoing(),'guest',true)
 end
 for _=1,20 do exchange()end
 assert(host.epoch==guest.epoch and guest:ready()and host.remoteCount==1 and host.clock:ready())
 host:start('race');guest:receive(host:outgoing(),'host',true)
 assert(guest.round.mode=='race'and guest.round.phase=='countdown')
 for _=1,31 do exchange()end
 assert(host.round.phase=='playing'and guest.round.phase=='playing')
 guest:registerShot(2,1,guest.round.id,{X=0,Y=0,Z=0},{X=100,Y=0,Z=0},time)
 guest:emit('S','1,'..guest.round.id..',0,0,0,100,0,0,'..time..',1')
 guest:emit('H','12345678,1,'..guest.round.id..',100,0,0,0,100,1000,15,'..time)
 local data=guest:outgoing();assert(host:receive(data,'guest',true))
 assert(host.round.scores[2]==15 and host.round.shots[2]==1 and damaged==1)
 host:receive(data,'guest',true);assert(host.round.scores[2]==15 and damaged==1)
 guest:receive(host:outgoing(),'host',true);assert(guest.round.scores[2]==15)
 guest:outgoing();assert(#guest.journal.pending==0)
 host:registerShot(1,1,host.round.id,{X=0,Y=0,Z=0},{X=100,Y=0,Z=0},time)
 host:score(1,1,'12345678',15,time)
 host:emit('S','1,'..host.round.id..',0,0,0,100,0,0,'..time..',2')
 host:emit('H','12345678,1,'..host.round.id..',100,0,0,0,100,1000,15,'..time)
 guest:receive(host:outgoing(),'host',true)
 assert(guest.round.scores[1]==15 and guest.round.scores[2]==15 and guest.metrics.peerHits==1)
 hs.metadata.dataDelayed=true;host:tick();assert(host.round.phase=='cancelled'and host.round.scores[2]==15)
 gs.localReady=false;hs.metadata.dataDelayed=false;exchange();assert(not pcall(function()host:rematch()end))
 gs.localReady=true;for _=1,4 do exchange()end
 host:rematch();assert(host.round.phase=='countdown'and host.round.scores[2]==0)
 hs.players=1;host:tick();assert(host.round.phase=='cancelled'and host.round.reason=='connection')
 hs.players=2;for _=1,4 do exchange()end
 host:rematch();local old=host:outgoing();world='world2';host:tick();guest:tick()
 assert(not host:receive(data,'guest',true)and host.round.scores[2]==0)
 assert(not guest:receive(old,'host',true))
 for _=1,15 do exchange()end
 assert(guest.epoch==host.epoch)
 host:start('timed');for _=1,31 do exchange()end
 local cutoff=host.round.deadline
 while time<cutoff-0.15 do exchange()end
 time=cutoff-0.05
 guest:emit('S','2,'..guest.round.id..',0,0,0,100,0,0,'..time..',2')
 guest:emit('H','12345678,2,'..guest.round.id..',100,0,0,0,100,1000,15,'..time)
 data=guest:outgoing();time=cutoff+0.3;host:tick();assert(host.round.phase=='settling')
 assert(host:receive(data,'guest',true));assert(host.round.scores[2]==15)
 time=cutoff+1;host.round:step();assert(host.round.phase=='finished'and host.round:winner()==2)
 local before=host.round.mode
 local Wire=require('gameplay.wire')
 host:receive(Wire.pack({'Range_SwimmingPool',host.epoch,0,'','9,race,finished,0,0,1,0,999,999,0,0,0,0,none,0','',0,0,'0,0,0,1,0,0,0,1',''}),'guest',true)
 assert(host.round.mode==before and host.round.scores[1]==0)
 time=time+9;host:tick();assert(next(host.shots)==nil)
 print('[BallisticTogether] Gameplay peer, interruption, rematch and delayed-hit tests passed\n')
end
local ok,err=pcall(run)
for _,name in ipairs(names)do package.loaded[name]=saved[name]end
assert(ok,err)
return true
