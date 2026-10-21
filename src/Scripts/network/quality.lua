local Quality = {}
function Quality.create(timeout)
    local self = {received = 0, skipped = 0, repeats = 0, timeout = timeout or 3}
    function self:reset() self.last, self.sequence, self.received, self.skipped, self.repeats = nil, nil, 0, 0, 0 end
    function self:observe(sequence, now)
        if self.last and now < self.last then self:reset() end
        if self.sequence then
            local gap = (sequence - self.sequence) % 10000000
            if gap == 0 or gap >= 5000000 then self.repeats = self.repeats + 1; return end
            self.skipped = self.skipped + gap - 1
        end
        self.sequence, self.last, self.received = sequence, now, self.received + 1
    end
    function self:age(now)
        if self.last and now < self.last then self:reset() end
        return self.last and now - self.last or math.huge
    end
    function self:fresh(now) return self:age(now) < self.timeout end
    return self
end
return Quality
