local Motion = {}
function Motion.copy(p) return {X = p.X, Y = p.Y, Z = p.Z} end
function Motion.yaw(a, b, alpha) return a + ((b - a + 180) % 360 - 180) * alpha end
function Motion.step(position, yaw, target, targetYaw, dt, rate, snapDistance)
    local dx, dy, dz = target.X - position.X, target.Y - position.Y, target.Z - position.Z
    if dx * dx + dy * dy + dz * dz > (snapDistance or 500) ^ 2 then return Motion.copy(target), targetYaw, 0 end
    dt = math.max(0, math.min(dt, 0.1))
    local alpha = 1 - math.exp(-(rate or 14) * dt)
    return {X = position.X + dx * alpha, Y = position.Y + dy * alpha, Z = position.Z + dz * alpha},
        Motion.yaw(yaw, targetYaw, alpha), math.sqrt(dx * dx + dy * dy) * alpha / math.max(dt, 0.001)
end
return Motion
