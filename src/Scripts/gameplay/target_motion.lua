local Motion={}
local rotations={[4]=true,[5]=true,[6]=true,[10]=true,[11]=true,[12]=true}
function Motion.create()
    local self={samples={}}
    function self:push(values,now)
        local last=self.samples[#self.samples]
        if last and now<=last.time then self.samples={};last=nil end
        local dx=last and values[7]-last.values[7]or 0
        local dy=last and values[8]-last.values[8]or 0
        local dz=last and values[9]-last.values[9]or 0
        if dx*dx+dy*dy+dz*dz>1000*1000 then self.samples={}end
        self.samples[#self.samples+1]={time=now,values=values}
        while #self.samples>8 do table.remove(self.samples,1)end
    end
    function self:sample(now)
        local samples=self.samples;local last=samples[#samples]
        if not last then return nil end
        local at=now-0.12
        local a,b=samples[1],last
        for i=2,#samples do if samples[i].time>=at then a,b=samples[i-1],samples[i];break end end
        local t=b.time>a.time and math.max(0,math.min(1,(at-a.time)/(b.time-a.time)))or 1
        local result={}
        for i=1,12 do
            local delta=b.values[i]-a.values[i]
            if rotations[i]then delta=(delta+180)%360-180 end
            result[i]=a.values[i]+delta*t
        end
        return result,now>=last.time+0.12
    end
    return self
end
return Motion
