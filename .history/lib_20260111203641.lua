local lib = {}

function lib.clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

function lib.sec(x)
    return 1/math.cos(x)
end

function lib.csc(x)
    return 1/math.sin(x)
end

function lib.Change360_TO_180 (angle)
    if angle > 180 then
        return angle - 360
    else
        return angle
    end
end

function lib.Change180_TO_360 (angle)
    if angle < 0 then
        return angle + 360
    else
        return angle
    end
end

function lib.Distance_2D_Calc(x1,z1, x2,z2)
    local dx = x2 - x1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dz*dz)
end

function lib.Distance_3D_Calc(x1,y1,z1, x2,y2,z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function print_lib()
    print("lib loaded")
end

return lib