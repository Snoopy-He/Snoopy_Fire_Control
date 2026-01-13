local Motor={peripheral.find("Create_RotationSpeedController")}
local Pit=Motor[1]
local Yaw=Motor[2]
local SCR=peripheral.find("monitor")
local cannon = peripheral.find("cbc_cannon_mount")

local Parameters ={
    Cannon_Type={},   --AutoCannon or BigCannon
    Target_Type={}    --Player or Monster
    Gimbal={
        Yaw_TarAng = 0,
        Pitch_TarAng = 0,
        Yaw_CurAng = 0,
        Pitch_LastAng = 0,
        Yaw_LastAng = 0,
        Pitch_CurAng = 0,
    },
    Location ={
        Distance_3D,Distance_2D = 0,0,
        Flying_Time = 0,
        Distance_Max = 400,
        Distance_Min = 10,
        Target ={       --当前目标,卡尔曼滤波预测
            X,Y,Z = 0,0,0
        },
        Target_Ready ={},  --备用目标,线性预测
        Cannon ={
            X,Y,Z = 0,0,0
        },
        Cannon_Offset={
            X = -0.5,
            Y = 2.5,
            Z = 0.5
        },
        Player_Targets = {},
        Monster_Targets = {}
    },
    Pitch ={
        kp = 16,
        ki = 0,
        kd = 0,
        error = 0,
        last_err = 0,
        err_all = 0,
        speed_max = 1000,
        angle_max = 80,
        angle_min = -30,
        speed = 0
    },
    Yaw ={
        kp = 16,
        ki = 0,
        kd = 0,
        error = 0,
        last_err = 0,
        err_all = 0,
        errall_max = 1000,
        speed_max = 250,
        speed = 0
    },
    AutoCannon ={
        n = 6, --药包数量
        m = 40, --每个药包速度
        d = 0.019, --阻力系数
        T = 0.05, --时间间隔
        k = 0.0255, --重力分量
        l = 6    --身管长度
    },
    BigCannon ={
        n = 6, --药包数量
        m = 40, --每个药包速度
        d = 0.01, --阻力系数
        T = 0.05, --时间间隔
        k = 0.05, --重力分量
        l = 6    --身管长度
    }
}

local Angle_Speed = 26.666667/2

function Init(parameter,cannontype,targettype,enable)
    Yaw.setTargetSpeed(0)
    Pitch.setTargetSpeed(0)
    redstone.setOutput(enable, false)
    sleep(2)
    redstone.setOutput(enable, true)
    Yaw.setTargetSpeed(0)
    parameter.Cannon_Type = cannontype
    parameter.Target_Type = targettype
end

function Cannon_Position_Update(parameter)
    selfPos = coordinate.getAbsoluteCoordinates()
    parameter.Location.Cannon.X = selfPos.x + parameter.Location.Cannon_Offset.X
    parameter.Location.Cannon.Y = selfPos.y + parameter.Location.Cannon_Offset.Y
    parameter.Location.Cannon.Z = selfPos.z + parameter.Location.Cannon_Offset.Z
end

function print(text)
    SCR.clear()
    SCR.setCursorPos(1, 1)
    SCR.write(text)
end

function math.Distance_3D_Calc(x1,y1,z1, x2,y2,z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function math.clamp(value,min,max)
    if value<min then
        return min
    end
    if value>max then
        return max
    end
    return value
end

function math.Distance_2D_Calc(x1,z1, x2,z2)
    local dx = x2 - x1
    local dz = z2 - z1
    return math.sqrt(dx*dx + dz*dz)
end

function math.sec(x)
    if math.cos(x) == 0 then
        return math.huge
    end
    return 1/math.cos(x)
end

function math.csc(x)
    if math.cos(x) == 0 then
        return math,huge
    end
    return 1/math.sin(x)
end

function math.atan_in_circle(x,y)
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

function math.circle_limit(angle)
    if angle > 360 then
        return angle - 360
    end
    if angle < 0 then
        return angle + 360
    end
    return angle
end

function math.nan_Check(value,result)
    if value~=value then
        return result
    else
        return value
    end
end

---------------------------------------------------target part---------------------------------------------------------------------

function Player_Target_Update(target,cannon,dist_min,dist_max,old_target)
    local length = #old_target
    local i = 0
    local last_x,last_y,last_z = 0,0,0
    for i = 1,length do
        if target.uuid == old_target[i].uuid then
            last_x = old_target[i].X
            last_y = old_target[i].Y
            last_z = old_target[i].Z
            break
        end
    end
    return {
        X = target.x,
        Y = target.y,
        Z = target.z,
        Distance = math.clamp(math.Distance_3D_Calc(target.x,target.y,target.z,cannon.X,cannon.Y,cannon.Z),dist_min,dist_max),
        Viewx = target.viewVector.x,
        Viewy = target.viewVector.y,
        Viewz = target.viewVector.z,
        Eyeheight = target.eyeHeight,
        Last_X = last_x,
        Last_Y = last_y,
        Last_Z = last_z,
        uuid = target.uuid,
        Name = target.name
    }
end

function Monster_Target_Update(target,cannon,dist_min,dist_max,old_target)
    local length = #old_target
    local i = 0
    local last_x,last_y,last_z = 0,0,0
    for i = 1,length do
        if target.uuid == old_target[i].uuid then
            last_x = old_target[i].X
            last_y = old_target[i].Y
            last_z = old_target[i].Z
            break
        end
    end
    return {
        X = target.x,
        Y = target.y,
        Z = target.z,
        Last_X = last_x,
        Last_Y = last_y,
        Last_Z = last_z,
        Distance = math.clamp(math.Distance_3D_Calc(target.x,target.y,target.z,cannon.X,cannon.Y,cannon.Z),dist_min,dist_max),
        uuid = target.uuid,
        Name = target.name
    }
end

function Targets_Oder(targets)   --对目标根据距离进行冒泡排序
    local length = #targets
    local swapped = false
    for i = 1, length do
        swapped = false
        for j = 1, length - i do
            if targets[j].Distance > targets[j+1].Distance then
                targets[j], targets[j + 1] = targets[j + 1], targets[j]
                swapped = true
            end
        end
        if not swapped then --如果这一轮没有发生交换，说明已经有序，提前结束
            break
        end
    end
    return targets
end

-------------------------------------------------predictor part-------------------------------------------------

function LinearPredictor_Calc(target, flying_time)
    local target_vx, target_vy, target_vz = 0,0,0

    target_vx = target.X - target.Last_X
    target_vy = target.Y - target.Last_X
    target_vz = target.Z - target.Last_X

    local total_v = math.sqrt(target_vx*target_vx + target_vy*target_vy + target_vz*target_vz)
    if total_v < 0.01 then
        total_v = 10000
    end

    return {
        X = target.X + target_vx * flying_time * (0.6 + 1/total_v / 2),  ---后面为经验系数,由测试得到
        Y = target.Y + target_vy * flying_time * (0.6 + 1/total_v / 2),
        Z = target.Z + target_vz * flying_time * (0.6 + 1/total_v / 2),
    }
end

function KalmanPredictor_Calc(target, flying_time)

end

function Predictor_Calc(parameter)
    LinearPredictor_Calc(targets,flying_time)
end

function Target_Update(parameter)
    local players = coordinate.getPlayers(dist_max)
    local monsters = coordinate.getMonster(dist_max)
    local i=1
    for k, v in pairs(players) do
        parameter.Location.Player_Targets[i] = Player_Target_Update(v,parameter.Location.Cannon,parameter.Location.Distance_Min,parameter.Location.Distance_Max,parameter.Location.Player_Targets)
        i=i+1
    end
    i = 1
    for k, v in pairs(monsters) do
        parameter.Location.Monster_Targets[i] = Monster_Target_Update(v,parameter.Location.Cannon,parameter.Location.Distance_Min,parameter.Location.Distance_Max,parameter.Location.Monster_Targets)
        i = i+1
    end
    parameter.Location.Player_Targets = Targets_Oder(parameter.Location.Player_Targets)
    parameter.Location.Monster_Targets = Targets_Oder(parameter.Location.Monster_Targets)
    Predictor_Calc(parameter)
end

function PID_Calc(current,target,para)
    para.error = target-current
    para.err_all = math.clamp(pid_errall + error,-para.errall_max,para.errall_max)
    local result = error * para.kp + pid_errall * para.ki + (error - last_err) * para.kd
    para.last_err = para.error
    result = math.clamp(result,-para.speed_max,para.speed_max)
    return result
end

function Motor_Calc(parameter)
    parameter.Gimbal.Yaw_TarAng = math.circle_limit(parameter.Gimbal.Yaw_TarAng)
    parameter.Gimbal.Pitch_TarAng = math.clamp(parameter.Gimbal.Pitch_TarAng, -30,80)

    parameter.Gimbal.Yaw_TarAng = math.nan_Check(parameter.Gimbal.Yaw_TarAng,parameter.Gimbal.Yaw_LastAng)
    parameter.Gimbal.Pitch_TarAng = math.nan_Check(parameter.Gimbal.Yaw_TarAng,parameter.Gimbal.Pitch_LastAng)

    if math.abs(parameter.Gimbal.Yaw_TarAng - parameter.Gimbal.Yaw_CurAng) > 180 then   --过零点检测
        if parameter.Gimbal.Yaw_TarAng > parameter.Gimbal.Yaw_CurAng then
            parameter.Gimbal.Yaw_TarAng = parameter.Gimbal.Yaw_TarAng - 360
        else
            parameter.Gimbal.Yaw_TarAng = parameter.Gimbal.Yaw_TarAng + 360
        end
    end

    parameter.Yaw.speed = PID_Calc(parameter.Gimbal.Yaw_CurAng,parameter.Gimbal.Yaw_TarAng,parameter)
    parameter.Pitch.speed = PID_Calc(parameter.Gimbal.Pitch_CurAng,parameter.Gimbal.Pitch_TarAng,parameter)

    Yaw.setTargetSpeed(math.floor(parameter.Yaw.speed))
    Pit.setTargetSpeed(math.floor(parameter.Pitch.speed))

    parameter.Gimbal.Yaw_LastAng = parameter.Gimbal.Yaw_TarAng
    parameter.Gimbal.Pitch_LastAng = parameter.Gimbal.Pitch_TarAng

    parameter.Gimbal.Yaw_CurAng = parameter.Gimbal.Yaw_CurAng + math.floor(parameter.Yaw.speed)/Angle_Speed
    parameter.Gimbal.Pitch_CurAng = parameter.Gimbal.Pitch_CurAng + math.floor(parameter.Pitch.speed)/Angle_Speed

    parameter.Gimbal.Yaw_CurAng = math.circle_limit(parameter.Gimbal.Yaw_CurAng)
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
        local f = Fx(p1,p2,p3,p4,p5,a,x)
        local f_derivative = Fx_derivative(p1,p2,p3,p4,a,x)
        if f_derivative == 0 then
            break
        end
        local x_new = x - f / f_derivative
        x = math.nan_check(x,0)
        if math.abs(x_new - x) < 1e-6 then
            return x_new
        end
        x = x_new
    end
    x = math.nan_check(x,0)
    return x
end

function Track_Calc(parameter)   --弹道计算
    if parameter == "AutoCannon" then
        local n = parameter.AutoCannon.n
        local m = parameter.AutoCannon.m
        local d = parameter.AutoCannon.d
        local T = parameter.AutoCannon.T
        local k = parameter.AutoCannon.k
        local l = parameter.AutoCannon.l
    else
        local n = parameter.BigCannon.n
        local m = parameter.BigCannon.m
        local d = parameter.BigCannon.d
        local T = parameter.BigCannon.T
        local k = parameter.BigCannon.k
        local l = parameter.BigCannon.l
    end

    local w = Distance_2D_Calc(parameter.Location.Cannon.X,parameter.Location.Cannon.Z, parameter.Location.Target.X,parameter.Location.Target.Z)
    local h = parameter.Location.Target.Y - parameter.Location.Cannon.Y
    local a = k*m*T/d/d
    local a1 = k*w/d/n
    local a2 = w
    local a3 = m*n*T+d*l
    local a4 = d*w
    local a5 = -k*l/d/n+2-a*math.log(m*n*T)-h
    local pitch1=Newton_Raphson(a1,a2,a3,a4,a5,a,-1,5)
    local pitch2=Newton_Raphson(a1,a2,a3,a4,a5,a,1.5,5)
    --print("Pitch1:"..math.deg(pitch1).." Pitch2:"..math.deg(pitch2).."Fx:"..Fx(a1,a2,a3,a4,a5,a,pitch1))
    --print("a1:"..a1.." a2:"..a2.." a3:"..a3.." a4:"..a4)
    parameter.Gimbal.Yaw_TarAng = math.deg(math.atan_in_circle(parameter.Location.Target.X - parameter.Location.Cannon.X, parameter.Location.Target.Z - parameter.Location.Cannon.Z)) + 90
    parameter.Gimbal.Pitch_TarAng = math.deg(math.min(pitch1, pitch2))
    parameter.Location.Distance_3D = Distance_3D_Calc(parameter.Location.Cannon.X, parameter.Location.Cannon.Y, parameter.Location.Cannon.Z, parameter.Location.Target.X, parameter.Location.Target.Y, parameter.Location.Target.Z)
    parameter.Location.Distance_2D = w
    parameter.Location.Target.Flying_Time = Flying_Time_Calc(parameter.Gimbal.Pitch_TarAng, parameter.Location.Target.Distance_2D)
end

function Flying_Time_Calc(pitch,distance,parameter)
    if parameter == "AutoCannon" then
        local n = parameter.AutoCannon.n
        local m = parameter.AutoCannon.m
        local d = parameter.AutoCannon.d
        local T = parameter.AutoCannon.T
        local k = parameter.AutoCannon.k
        local l = parameter.AutoCannon.l
    else
        local n = parameter.BigCannon.n
        local m = parameter.BigCannon.m
        local d = parameter.BigCannon.d
        local T = parameter.BigCannon.T
        local k = parameter.BigCannon.k
        local l = parameter.BigCannon.l
    end

    local result = -math.log(1-(distance-l*math.cos(pitch))*d/(m*n*T*math.cos(pitch)))/d
    return result
end

-------------------------------------------------------------------主函数--------------------------------------------------------------

Deinit()
Init()
Cannon_Pos = Cannon_Position_Update()
while true do
    Target_pos = Target_Update()
    Target_pos = LinearPredictor_Calc(Target_pos, Direction.Flying_Time)
    --Target_pos = Position_Update(-100,-20,200)
    Direction = Track_Calc(Cannon_Pos.X, Cannon_Pos.Y, Cannon_Pos.Z, Target_pos.X, Target_pos.Y, Target_pos.Z)
    --Direction = Binary_Method_Track_Calc(Cannon_Pos.X, Cannon_Pos.Y, Cannon_Pos.Z, Target_pos.X, Target_pos.Y, Target_pos.Z)
    Motor_Calc()
    --print(Direction.Pitch_Angle)
    --print("Flying_Time:"..string.format("%.2f",Direction.Flying_Time))
    --print("Yaw Target: "..math.floor(Direction.Yaw_Angle).."Yaw Current: "..math.floor(Yaw_Angle).." Pitch Target: "..math.floor(Direction.Pitch_Angle).." Pitch Current: "..math.floor(Pitch_Angle))
end
