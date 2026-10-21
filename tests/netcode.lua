package.path = 'src/Scripts/?.lua;' .. package.path
local P, Social = require('network.protocol'), require('lobby.social')
local now = 100
local function clock()return now end
local a,b=Social.create(clock),Social.create(clock)
local mesh=string.rep('mesh',1200)
local function packet(who,gear,ready)return assert(P.decode(P.encode(who:fields('Range_SwimmingPool',0,gear or '',ready))))end
a:send('hello','You')
local initial=packet(a,mesh)
assert(#initial.gear>1200 and initial.gearIncluded)
assert(b:receive(initial,'Friend',true,false));assert(b.remoteGear==mesh and b.seen==1)
assert(a:receive(packet(b),'Friend',false,false));assert(#a.outgoing==0 and a.acknowledgedGear==1)
local delta=packet(a,mesh)
assert(delta.gear=='' and not delta.gearIncluded)
assert(b:receive(delta,'Friend',true,false));assert(b.remoteGear==mesh)
b:reset()
assert(b:receive(delta,'Friend',true,false));assert(b.remoteGearRevision==0)
assert(a:receive(packet(b),'Friend',false,false))
assert(b:receive(packet(a,mesh),'Friend',true,false));assert(b.remoteGear==mesh)
now=102;assert(b:receive(packet(a,''),'Friend',true,false));assert(b.remoteGear=='' and b.remoteGearRevision==2)
local pending=Social.create(clock)
for i=1,8 do now=now+1;pending:send('message '..i,'You')end
assert(not pcall(function()now=now+1;pending:send('overflow','You')end));assert(#pending.outgoing==8)
local receiver=Social.create(clock)
local latest=packet(pending)
assert(receiver:receive(latest,'Friend',true,false));assert(#receiver.history==8)
assert(not receiver:receive(latest,'Friend',true,false));assert(#receiver.history==8)
local ack=packet(receiver);ack.ackNonce='wrong_session'
pending:receive(ack,'Friend',false,false);assert(#pending.outgoing==8)
now=now+1;assert(pending:receive(packet(receiver),'Friend',false,false));assert(#pending.outgoing==0)
local paced=Social.create(clock)
local first=packet(paced)
assert(packet(paced).sequence==first.sequence)
assert(packet(paced,'',true).sequence~=first.sequence)
now=now+1;local heartbeat=packet(paced,'',true)
assert(heartbeat.sequence~=first.sequence)
assert(P.newer(0,9999999) and not P.newer(9999999,0))
local invalid=paced:fields('',0,'');invalid[2]=10000000;assert(not P.decode(P.encode(invalid)))
local Q=require('network.quality').create(3)
Q:observe(9999999,10);Q:observe(0,11);assert(Q.received==2 and Q.skipped==0)
Q:observe(0,13.9);assert(not Q:fresh(14.1))
Q:observe(1,15);assert(Q:fresh(15))
assert(not Q:fresh(1));Q:observe(2,1);assert(Q:fresh(1))
local Buffer=require('avatars.buffer')
local v={X=100,Y=0,Z=0};local buffer=Buffer.create()
buffer:push({X=0,Y=0,Z=0},179,0,1,v)
buffer:push({X=10,Y=0,Z=0},-179,0.1,2,v)
local p,y=buffer:sample(0.11);assert(math.abs(p.X-5)<0.01 and math.abs(y-180)<0.01)
p=buffer:sample(10);assert(math.abs(p.X-18)<0.01)
buffer:push({X=1000,Y=0,Z=0},0,0.2,3,v);p=buffer:sample(0.2);assert(p.X==1000 and #buffer.samples==1)
buffer:push({X=1001,Y=0,Z=0},0,0.3,3,{X=0,Y=0,Z=0});p=buffer:sample(10);assert(p.X==1001)
local jittered=Buffer.create()
for i,t in ipairs({0,0.05,0.18,0.23,0.41,0.46,0.6})do jittered:push({X=t*100,Y=0,Z=0},0,t,i,v)end
assert(jittered.delay>0.06 and jittered.delay<=0.14)
for i=1,100 do jittered:push({X=60+i,Y=0,Z=0},0,0.6+i*0.02,10+i,v)end
assert(#jittered.samples<=32)
local sender,recipient=Social.create(clock),Social.create(clock)
local delayed={}
for tick=1,80 do
    now=200+tick
    if tick<=5 then sender:send('loss test '..tick,'You')end
    local outgoing=packet(sender,mesh)
    if tick%3~=0 then delayed[#delayed+1]={due=tick+(tick%4),packet=outgoing}end
    for i=#delayed,1,-1 do
        if delayed[i].due<=tick then recipient:receive(delayed[i].packet,'Friend',true,false);table.remove(delayed,i)end
    end
    if tick%4~=0 then sender:receive(packet(recipient),'Friend',false,false)end
end
assert(#recipient.history==5 and #sender.outgoing==0 and recipient.remoteGear==mesh)
print('PASS acknowledgements, large gear deltas/reconnect, bounded chat backlog, idle pacing, sequence wrap, stale leases and jitter/loss/teleport movement')
return true
