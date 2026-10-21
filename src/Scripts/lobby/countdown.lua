local Countdown = {}
function Countdown.create(clock)
    clock = clock or os.time
    local self = {}
    function self:start(destination, players)
        assert(destination, 'Choose a range first.')
        self.destination, self.players, self.deadline = destination, players, clock() + 3
    end
    function self:cancel() self.destination, self.deadline = nil, nil end
    function self:remaining() return self.deadline and math.max(0, self.deadline - clock()) or 0 end
    function self:step(ready, players, rangeId)
        if not self.deadline then return end
        if not ready or players ~= self.players or self.destination.id ~= rangeId then self:cancel(); return 'cancelled' end
        if clock() >= self.deadline then local destination = self.destination; self:cancel(); return 'travel', destination end
    end
    return self
end
return Countdown
