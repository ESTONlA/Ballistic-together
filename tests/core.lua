package.path = 'src/Scripts/?.lua;' .. package.path
local P, Social = require('network.protocol'), require('lobby.social')
local clock = 100
local a, b = Social.create(function() return clock end), Social.create(function() return clock end)
a:send('hello', 'You'); a:mark({X=1,Y=2,Z=3}, 'Bunker_Main')
local first = assert(P.decode(P.encode(a:fields('Range_SwimmingPool',3,''))))
assert(b:receive(first,'Friend',true,false))
assert(#b.history==1 and b.unread==1 and b.remoteMarker.untilTime==125)
assert(b.remoteRange=='Range_SwimmingPool' and b.remoteCountdown==3)
assert(not b:receive(first,'Friend',true,false))
clock=102;a:send('next','You')
local second=assert(P.decode(P.encode(a:fields('',0,''))))
assert(b:receive(second,'Friend',true,true));assert(#b.history==1)
assert(not b:receive(first,'Friend',true,false))
a:reset();assert(b:receive(assert(P.decode(P.encode(a:fields('',0,'')))),'Friend',true,false))
assert(not b:receive(second,'Friend',true,false))
for _, packet in ipairs({'','BT020\n','BT025\n99999:x',P.encode(a:fields('',0,''))..'x'}) do assert(not P.decode(packet)) end
local valid=P.encode(a:fields('',0,''))
for i=1,#valid-1 do assert(not P.decode(valid:sub(1,i))) end
assert(not pcall(function()P.encode({'a',1,'',0,0,'','0',string.rep('x',1801),''})end))
assert(utf8.len(require('shared.text').clean(string.rep('ä',100),179)))
local time=0;local c=require('lobby.countdown').create(function()return time end);local range={id='pool'}
c:start(range,2);assert(c:step(false,2,'pool')=='cancelled')
c:start(range,2);assert(c:step(true,1,'pool')=='cancelled')
c:start(range,2);assert(c:step(true,2,'other')=='cancelled')
c:start(range,2);time=3;local action,destination=c:step(true,2,'pool');assert(action=='travel' and destination==range)
print('PASS chat ordering, duplicates, mute, nonce replay, markers, framing/truncation, UTF-8 and countdown guards')
return true
