local Clock={}
function Clock.create()
    local self={sent={},order={},samples=0,best=math.huge,offset=0}
    function self:fields(now)
        local stamp=tonumber(string.format('%.3f',now))
        local key=string.format('%.3f',stamp)
        if not self.sent[key]then self.order[#self.order+1]=key end
        self.sent[key]=now
        while #self.order>64 do self.sent[table.remove(self.order,1)]=nil end
        return string.format('%.3f,%.3f,%.3f',stamp,self.remoteStamp or 0,self.receivedAt and math.max(0,now-self.receivedAt)or 0)
    end
    function self:observe(remote,echo,held,now)
        self.remoteStamp,self.receivedAt=remote,now
        local sent=self.sent[string.format('%.3f',echo)]
        if not sent or held<0 or held>5 then return false end
        local rtt=now-sent-held
        if rtt< -0.01 or rtt>2 then return false end
        rtt=math.max(0,rtt)
        local offset=remote+rtt/2-now
        if self.samples==0 or rtt<=self.best+0.03 or now-(self.estimateAt or 0)>10 then self.offset=offset;self.best=rtt;self.estimateAt=now end
        self.samples=self.samples+1;self.rtt=rtt;self.validAt=now
        return true
    end
    function self:ready(now)return self.samples>=3 and(not now or self.validAt and now-self.validAt<=1.5)end
    function self:remoteNow(now)return now+self.offset end
    function self:toLocal(stamp,now)
        if not self:ready(now)then return nil end
        local converted=stamp-self.offset
        if converted>now+0.10 or converted<now-1.25 then return nil end
        return math.min(converted,now)
    end
    return self
end
return Clock
