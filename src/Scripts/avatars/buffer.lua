local Motion = require('avatars.motion')
local Buffer = {}
local function distance(a, b)
    local x,y,z=a.X-b.X,a.Y-b.Y,a.Z-b.Z
    return math.sqrt(x*x+y*y+z*z)
end
function Buffer.create(config)
    config = config or {}
    local self = {samples = {}, delay = (config.InterpolationDelayMs or 60)/1000, jitter = 0}
    local base = self.delay
    local maximum = math.max(base, (config.MaxInterpolationDelayMs or 140)/1000)
    local extrapolation = math.max(0, math.min(0.15, (config.MaxExtrapolationMs or 80)/1000))
    function self:push(position, yaw, now, stamp, velocity)
        local samples, previous = self.samples, self.samples[#self.samples]
        local restarted = previous and (now < previous.time or (stamp and previous.stamp and stamp < previous.stamp))
        if restarted or (previous and distance(previous.position, position) > (config.TeleportSnapDistance or 500)) then
            self.samples, self.interval, self.jitter, self.delay = {}, nil, 0, base
            samples, previous = self.samples, nil
        end
        if previous then
            if (not stamp or stamp == previous.stamp) and distance(previous.position,position)<0.01 and math.abs((yaw-previous.yaw+180)%360-180)<0.1 then return false end
            local interval=now-previous.time
            if interval<=0 then return false end
            if interval<0.5 then
                if self.interval then self.jitter=self.jitter*0.9+math.abs(interval-self.interval)*0.1 end
                self.interval=self.interval and self.interval*0.9+interval*0.1 or interval
                local desired=math.min(maximum,base+self.jitter*2)
                self.delay=self.delay+(desired-self.delay)*(desired>self.delay and 0.5 or 0.05)
            end
        end
        local v = velocity and Motion.copy(velocity) or {X=0,Y=0,Z=0}
        if not velocity and previous then
            local dt=now-previous.time
            v={X=(position.X-previous.position.X)/dt,Y=(position.Y-previous.position.Y)/dt,Z=(position.Z-previous.position.Z)/dt}
        end
        local speed=math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)
        if speed>1200 then local scale=1200/speed;v={X=v.X*scale,Y=v.Y*scale,Z=v.Z*scale}end
        samples[#samples+1]={position=Motion.copy(position),yaw=yaw,time=now,stamp=stamp,velocity=v}
        if #samples>32 then table.remove(samples,1)end
        return true
    end
    function self:sample(now)
        local samples=self.samples
        if #samples==0 then return nil end
        local target=now-self.delay
        for i=2,#samples do
            local a,b=samples[i-1],samples[i]
            if target<=b.time then
                local alpha=math.max(0,math.min(1,(target-a.time)/(b.time-a.time)))
                return {X=a.position.X+(b.position.X-a.position.X)*alpha,Y=a.position.Y+(b.position.Y-a.position.Y)*alpha,
                    Z=a.position.Z+(b.position.Z-a.position.Z)*alpha},Motion.yaw(a.yaw,b.yaw,alpha)
            end
        end
        local last=samples[#samples]
        local dt=math.max(0,math.min(extrapolation,target-last.time))
        return {X=last.position.X+last.velocity.X*dt,Y=last.position.Y+last.velocity.Y*dt,Z=last.position.Z+last.velocity.Z*dt},last.yaw
    end
    return self
end
return Buffer
