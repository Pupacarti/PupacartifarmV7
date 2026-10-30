local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local scriptActive = true
local isRightClicking = false

-- 1. ตั้งค่า RaycastParams สำหรับตรวจสอบสิ่งกีดขวาง
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- 2. ฟังก์ชันตรวจสอบว่าเป้าหมายมีกำแพงบังอยู่หรือไม่ (Wall Check)
local function isTargetVisible(targetHead)
    if not targetHead then return false end
    
    -- ไม่นำตัวละครของผู้เล่นเองมาคำนวณเป็นสิ่งกีดขวาง
    if LocalPlayer.Character then
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end

    local origin = Camera.CFrame.Position
    local direction = targetHead.Position - origin
    
    -- ยิงรังสีจากกล้องไปหาหัวเป้าหมาย
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    -- ถ้าไม่ชนอะไรเลย หรือชนตัวเป้าหมายเอง แปลว่า "มองเห็นตัว"
    if not result or result.Instance:IsDescendantOf(targetHead.Parent) then
        return true
    end
    
    return false -- มีกำแพงหรือสิ่งของบังอยู่
end

-- 3. ค้นหาซอมบี้ที่อยู่บนหน้าจอ และ "ต้องไม่มีกำแพงบัง"
local function getClosestVisibleNPC()
    local closest = nil
    local shortestDistance = math.huge

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("Head") then
            if not Players:GetPlayerFromCharacter(obj) and obj ~= LocalPlayer.Character then
                if obj.Humanoid.Health > 0 then
                    local headPos, onScreen = Camera:WorldToViewportPoint(obj.Head.Position)
                    
                    -- เช็กทั้งอยู่บนหน้าจอ (onScreen) และไม่มีกำแพงบัง (isTargetVisible)
                    if onScreen and isTargetVisible(obj.Head) then
                        local mousePos = UserInputService:GetMouseLocation()
                        local dist = (Vector2.new(headPos.X, headPos.Y) - mousePos).Magnitude
                        if dist < shortestDistance then
                            closest = obj
                            shortestDistance = dist
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- 4. ระบบ Auto Sight + Lock + Shoot (ทำงานเฉพาะเป้าหมายที่มองเห็น)
RunService.RenderStepped:Connect(function()
    if scriptActive then
        local target = getClosestVisibleNPC()
        local mousePos = UserInputService:GetMouseLocation()

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
        else
            -- ปล่อยคลิกขวาหากซอมบี้เดินเข้าหลังกำแพงหรือตาย
            if isRightClicking then
                isRightClicking = false
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, false, game, 0)
            end
        end
    end
end)

-- 5. ระบบกด E อัตโนมัติ
task.spawn(function()
    while task.wait(0.1) do
        if scriptActive then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end
end)
