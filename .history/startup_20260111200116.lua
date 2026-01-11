local Motor={peripheral.find("Create_RotationSpeedController")}
local Pit=Motor[1]
local Yaw=Motor[2]
local SCR=peripheral.find("monitor")
local cannon = peripheral.find("cbc_cannon_mount")

local Angle_Speed = 26.666667/2

local Offset_X = -0.5
local Offset_Y = 2.5
local Offset_Z = 0.5

local Direction={
    Yaw_Angle = 0,
    Pitch_Angle = 0,
    Distance = 0,
    Flying_Time = 0
}

function NewPosition(x,y,z)
    return {
        X = x,
        Y = y,
        Z = z,
        name = ""
    }
end

Cannon_Pos = NewPosition(0, 0, 0, "")
Target_pos = NewPosition(0, 0, 0, "")

function Init()
    redstone.setOutput("front", true)
    Yaw.setTargetSpeed(0)
end

function Deinit()
    redstone.setOutput("front", false)
    Yaw.setTargetSpeed(0)
    sleep(2)
    
end

function Cannon_Position_Update()
    selfPos = coordinate.getAbsoluteCoordinates()
    return {
        X = selfPos.x + Offset_X,
        Y = selfPos.y + Offset_Y,
        Z = selfPos.z + Offset_Z
    }
end

function print(text)
    SCR.clear()
    SCR.setCursorPos(1, 1)
    SCR.write(text)
end

function Position_Update(x,y,z)
    return {
        X = x,
        Y = y,
        Z = z
    }
end

function Distance_3D_Calc(x1,y1,z1, x2,y2,z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local tx,ty,tz,tname = 0,0,0,""

function Target_Update()
    local players = coordinate.getPlayers(300)
    local monsters = coordinate.getMonster(300)
    local Distance = 400
    for k, v in pairs(players) do
        --print("x="..v.x)
        --print("y="..v.y)
        --print("z="..v.z)
        --print("name="..v.name)
        --print("uuid="..v.uuid)
        --print("viewVector.x="..v.viewVector.x)
        --print("viewVector.y="..v.viewVector.y)
        --print("viewVector.z="..v.viewVector.z)
        --print("eyeHeight="..v.eyeHeight)
        --print("pose="..v.pose)
        --print("x="..v.x.." y="..v.y.." z="..v.z.." name="..v.name)
        --print("x="..v.x.." y="..v.y.." z="..v.z)
        --tx = v.x
        --ty = v.y+v.eyeHeight
        --tz = v.z
        --tname = v.name
    end

    for k, v in pairs(monsters) do
    --print("x="..v.x)
    --print("y="..v.y)
    --print("z="..v.z)
    --print("name="..v.name)
    --print("uuid="..v.uuid)
    --print("displayName="..v.displayName)
    --print("health="..v.health)
    --print("maxHealth="..v.maxHealth)
    --print("viewVector.z="..v.viewVector.z)
    --print("armor="..v.armor)
    local dist = Distance_3D_Calc(Cannon_Pos.X, Cannon_Pos.Y, Cannon_Pos.Z, v.x, v.y, v.z)
    if dist>300 then
        dist = 300
    end
    if dist < Distance and dist > 9 then
        Distance = dist
        tx = v.x
        ty = v.y+0.5
        tz = v.z
        tname = v.name
    end
end
    return {
        X = tx,
        Y = ty,
        Z = tz,
        name = tname
    }
end

function Target_Fliter()
    
end

function Direction_Calc(x1,y1,z1,x2,y2,z2)
    return {
        Yaw_Angle = math.deg(math.atan2(z2 - z1, x2 - x1)) + 90,
        Distance = Distance_3D_Calc(x1, y1, z1, x2, y2, z2),
        Pitch_Angle = math.deg(math.asin((y2 - y1) / Distance_3D_Calc(x1, y1, z1, x2, y2, z2))),
    }
end


local Yaw_Angle = 0
local Pitch_Angle = 0

local kp_yaw = 16.0
local kp_pitch = 16.0

function Clamp(value, min, max)
    if value < min then
        return min
    end
    if value > max then
        return max
    end
    return value
end

function circle_limit(angle)
    if angle > 360 then
        return angle - 360
    end
    if angle < 0 then
        return angle + 360
    end
    return angle
end

local last_yaw = 0
local last_pitch = 0

function Motor_Calc()
    Direction.Yaw_Angle = circle_limit(Direction.Yaw_Angle)
    Direction.Pitch_Angle = Clamp(Direction.Pitch_Angle, -30,80)
    if Direction.Yaw_Angle ~= Direction.Yaw_Angle then
        --print("Yaw NAN")
        Direction.Yaw_Angle = last_yaw
        return
    end

    if Direction.Pitch_Angle ~= Direction.Pitch_Angle then
        --print("Pitch NAN")
        Direction.Pitch_Angle = last_pitch
        return
    end

    if math.abs(Direction.Yaw_Angle - Yaw_Angle) > 180 then
        if Direction.Yaw_Angle > Yaw_Angle then
            Yaw_Value = (Direction.Yaw_Angle - 360 - Yaw_Angle)*kp_yaw
        else
            Yaw_Value = (Direction.Yaw_Angle + 360 - Yaw_Angle)*kp_yaw
        end
    else
        Yaw_Value = (Direction.Yaw_Angle - Yaw_Angle)*kp_yaw
    end

    if math.abs(Yaw_Value/kp_yaw) < 0.001 then
        Yaw_Value = 0
    end
    Yaw_Value = Clamp(Yaw_Value, -250, 250)

    Pitch_Value = (Direction.Pitch_Angle - Pitch_Angle)*kp_pitch
    if math.abs(Pitch_Value/kp_pitch)<0.001 then
        Pitch_Value = 0
    end
    Pitch_Value = Clamp(Pitch_Value, -250, 250)

    Yaw.setTargetSpeed(math.floor(Yaw_Value))
    Pit.setTargetSpeed(math.floor(Pitch_Value))
    last_yaw = Direction.Yaw_Angle
    last_pitch = Direction.Pitch_Angle
    Yaw_Angle= Yaw_Angle + math.floor(Yaw_Value)/Angle_Speed
    Pitch_Angle= Pitch_Angle + math.floor(Pitch_Value)/Angle_Speed
    if Yaw_Angle>360 then
        Yaw_Angle=Yaw_Angle-360
    end
    if Yaw_Angle<0 then
        Yaw_Angle=Yaw_Angle+360
    end
    --Yaw.setTargetSpeed(0)
    --print(Pit)
    end

function Distance_2D_Calc(x1,z1, x2,z2)
    local dx = x2 - x1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dz*dz)
end

function sec(x)
    return 1/math.cos(x)
end

function csc(x)
    return 1/math.sin(x)
end

function atan_in_circle(x,y)
    if x>0 and y>=0 then
        return math.atan(y/x)
    elseif x<0 and y>=0 then
        return math.pi+math.atan(y/x)
    elseif x<0 and y<0 then
        return -math.pi+math.atan(y/x)
    elseif x>0 and y<0 then
        return 2*math.pi+math.atan(y/x)
    elseif x==0 and y>0 then
        return math.pi/2
    elseif x==0 and y<0 then
        return 3*math.pi/2
    else
        return 0
    end
end

function fx(p1,p2,p3,p4,x) 
    return p1*sec(x)+p2*math.tan(x)+math.log(p3-p1*sec(x))+p4 
end

function Fx(p1,p2,p3,p4,p5,a,x) 
    return p1*sec(x)+p2*math.tan(x)+a*math.log(p3-p4*sec(x))+p5 
end

function fx_derivative(p1,p2,p3,x)
    return sec(x)*(p1*math.tan(x)*(1+1/(p1*sec(x)-p3))+p2*sec(x))
end

function Fx_derivative(p1,p2,p3,p4,a,x)
    return sec(x)*(math.tan(x)*(p1-a*p4/(p3-p4*sec(x)))+p2*sec(x))
end


function Newton_Raphson(p1,p2,p3,p4,p5,a,x0,n)
    local x = x0
    for i=1,n do
        --local f = Fx(p1,p2,p3,p4,x)
        --local f_derivative = Fx_derivative(p1,p2,p3,x)
        local f = Fx(p1,p2,p3,p4,p5,a,x)
        local f_derivative = Fx_derivative(p1,p2,p3,p4,a,x)
        if f_derivative == 0 then
            break
        end
        local x_new = x - f / f_derivative
        if x~=x then
            return 100
        end
        if math.abs(x_new - x) < 1e-6 then
            return x_new
        end
        if x~=x then
            return 100
        end
        x = x_new
    end
    return x
end

function Track_Calc(x1,y1,z1,x2,y2,z2)   --弹道计算
    local n = 6 --药包数量
    local m = 40 --每个药包速度
    local d = 0.019 --阻力系数（机炮参数（尝试中））
    --local d = 0.01 --阻力系数
    local T = 0.05 --时间间隔
    --local k = 0.05 --重力分量
    local k = 0.0255 --重力分量
    local l = 6    --身管长度
    local velocity  --初速度
    local w = Distance_2D_Calc(x1,z1, x2,z2)
    local h = y2 - y1
    local a = k*m*T/d/d
    local a1=k*w/d/n
    local a2=w
    local a3=m*n*T+d*l
    local a4=d*w
    local a5=-k*l/d/n+2-a*math.log(m*n*T)-h
    local pitch1=Newton_Raphson(a1,a2,a3,a4,a5,a,-1,5)
    local pitch2=Newton_Raphson(a1,a2,a3,a4,a5,a,1.5,5)
    --print("Distance 2D:"..w.." Height Difference:"..h)
    --print("Pitch1:"..math.deg(pitch1).." Pitch2:"..math.deg(pitch2).."Fx:"..Fx(a1,a2,a3,a4,a5,a,pitch1))
    --print("a1:"..a1.." a2:"..a2.." a3:"..a3.." a4:"..a4)
    return {
        Yaw_Angle = math.deg(atan_in_circle(x2 - x1, z2 - z1))+90,
        Distance = Distance_3D_Calc(x1, y1, z1, x2, y2, z2),
        Pitch_Angle = math.deg(math.min(pitch1, pitch2)),
        Flying_Time = Flying_Time_Calc(math.min(pitch1, pitch2), Distance_2D_Calc(x1, z1, x2, z2))
    }
end


function Flying_Time_Calc(pitch,distance)
    local n = 6 --药包数量
    local m = 40 --每个药包速度
    local d = 0.019 --阻力系数（机炮参数（尝试中））
    --local d = 0.01 --阻力系数
    local T = 0.05 --时间间隔
    --local k = 0.05 --重力分量
    local k = 0.0255 --重力分量
    local l = 6    --身管长度

    local result = -math.log(1-(distance-l*math.cos(pitch))*d/(m*n*T*math.cos(pitch)))/d
    if result~=result then
        return 0
    end
    return result
end

local Last_Pos = NewPosition(0,0,0)

function LinearPredictor_Calc(target_pos, flying_time,cannon_pos)
    local target_vx, target_vy, target_vz = 0,0,0

    target_vx = target_pos.X - Last_Pos.X
    target_vy = target_pos.Y - Last_Pos.Y
    target_vz = target_pos.Z - Last_Pos.Z

    Last_Pos = target_pos

    return {
        X = target_pos.X + target_vx * flying_time * (0.85 +(target_pos.Y-cannon_pos.Y)/20),
        Y = target_pos.Y + target_vy * flying_time * (0.85 +(target_pos.Y-cannon_pos.Y)/20),
        Z = target_pos.Z + target_vz * flying_time * (0.85 +(target_pos.Y-cannon_pos.Y)/20),
    }
end

function KalmanPredictor_Calc(target_pos, flying_time)
end


Deinit()
Init()
Cannon_Pos = Cannon_Position_Update()
--print(package.path)
while true do
    Target_pos = Target_Update()
    Target_pos = LinearPredictor_Calc(Target_pos, Direction.Flying_Time, Cannon_Pos)
    --Target_pos = Position_Update(-100,-20,200)
    Direction = Track_Calc(Cannon_Pos.X, Cannon_Pos.Y, Cannon_Pos.Z, Target_pos.X, Target_pos.Y, Target_pos.Z)
    --Direction = Binary_Method_Track_Calc(Cannon_Pos.X, Cannon_Pos.Y, Cannon_Pos.Z, Target_pos.X, Target_pos.Y, Target_pos.Z)
    Motor_Calc()
    --print(Direction.Pitch_Angle)
    print("Flying_Time:"..string.format("%.2f",Direction.Flying_Time))
    --print("Yaw Target: "..math.floor(Direction.Yaw_Angle).."Yaw Current: "..math.floor(Yaw_Angle).." Pitch Target: "..math.floor(Direction.Pitch_Angle).." Pitch Current: "..math.floor(Pitch_Angle))

end
