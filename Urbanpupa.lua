local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local scriptActive = true
local isRightClicking = false

-- ตั้งจำนวนซอมบี้ที่ต้องการเห็นก่อนยิง (ปรับเปลี่ยนตัวเลขตรงนี้ได้ เช่น 5 หรือ 6)
local requiredZombieCount = 5 

-- 1. ตั้งค่า RaycastParams สำหรับตรวจสอบสิ่งกีดขวาง
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- 2. ฟังก์ชันตรวจสอบว่าซอมบี้ถูกกำแพงบังหรือไม่
local function isTargetVisible(targetHead)
    if not targetHead then return false end
    
    if LocalPlayer.Character then
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end

    local origin = Camera.CFrame.Position
    local direction = targetHead.Position - origin
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if not result or result.Instance:IsDescendantOf(targetHead.Parent) then
        return true
    end
    
    return false
end

-- 3. รวบรวมซอมบี้ทั้งหมดที่ "มองเห็นได้ในจอขณะนั้น" ใส่ไว้ใน Table
local function getVisibleNPCs()
    local visibleList = {}

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("Head") then
            if not Players:GetPlayerFromCharacter(obj) and obj ~= LocalPlayer.Character then
                if obj.Humanoid.Health > 0 then
                    local headPos, onScreen = Camera:WorldToViewportPoint(obj.Head.Position)
                    
                    -- ต้องอยู่บนหน้าจอ และไม่มีกำแพงบัง
                    if onScreen and isTargetVisible(obj.Head) then
                        table.insert(visibleList, obj)
                    end
                end
            end
        end
    end
    return visibleList
end

-- 4. ระบบเช็กจำนวนซอมบี้ก่อนเปิดฉากยิง
RunService.RenderStepped:Connect(function()
    if scriptActive then
        local visibleZombies = getVisibleNPCs()
        local mousePos = UserInputService:GetMouseLocation()

        -- เงื่อนไข: จำนวนซอมบี้ที่มองเห็นต้อง >= 5 ตัวขึ้นไป
        if #visibleZombies >= requiredZombieCount then
            -- ค้นหาตัวที่อยู่ใกล้เป้าเมาส์ที่สุดจากซอมบี้ที่มองเห็น
            local target = nil
            local shortestDistance = math.huge

            for _, zombie in pairs(visibleZombies) do
                local headPos = Camera:WorldToViewportPoint(zombie.Head.Position)
                local dist = (Vector2.new(headPos.X, headPos.Y) - mousePos).Magnitude
                if dist < shortestDistance then
                    target = zombie
                    shortestDistance = dist
                end
            end

            if target and target:FindFirstChild("Head") then
                -- หันกล้องไปที่หัวซอมบี้
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Head.Position)

                -- กดคลิกขวาเล็ง
                if not isRightClicking then
                    isRightClicking = true
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, true, game, 0)
                end

                -- กดคลิกซ้ายยิง
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 0)
                task.wait(0.03)
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 0)
            end
        else
            -- ถ้าซอมบี้ยังเห็นไม่ถึงจำนวนที่ตั้งไว้ ให้ปล่อยคลิกขวาและไม่ทำอะไร
            if isRightClicking then
                isRightClicking = false
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, false, game, 0)
            end
        end
    end
end)

-- 5. ระบบกด E อัตโนมัติวนลูป
task.spawn(function()
    while task.wait(0.1) do
        if scriptActive then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end
end)
