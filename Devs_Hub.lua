local Xan = loadstring(game:HttpGet("https://raw.githubusercontent.com/syncgomees-commits/Devs_Hub/refs/heads/main/init.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserGui = LocalPlayer:WaitForChild("PlayerGui")

--// SUPPRESS ASSET LOAD WARNINGS
local oldWarn = warn
local oldPrint = print

warn = function(...)
    local args = {...}
    local message = table.concat(args, " ")
    if not string.find(message, "Failed to load sound") and 
       not string.find(message, "Failed to load animation") then
        oldWarn(...)
    end
end

--// ANDROID DETECTION
local IsAndroid = UserInputService.TouchEnabled

--// CONFIG
local Config = {
    Aimlock = false,
    ESP = false,
    Noclip = false,
    InfJump = false,
    JumpHack = false,
    SpeedHack = false,
    Fly = false,
    FlySpeed = 50,
    WalkSpeed = 16,
    JumpPower = 50,
    TargetPlr = nil,
    AimRange = 1000,
    HitParts = {Head = true, Chest = true},
    DebugEnabled = false,
    StealSpeed = false,
    StealMultiplier = 2,
    SavedPos1 = nil,
    SavedPos2 = nil
}

--// STORE
local Connections = {}
local Objects = {}
local TouchButtons = {}
local Window = nil

--// FLY VARIABLES
local BodyVel, BodyGyro = nil, nil
local AndroidUpPressed = false
local AndroidDownPressed = false
local IsFlying = false
local FlyControlFrame = nil
local FlySpeedLabel = nil

--// CLONE VARIABLES
local CloneConfig = {
    Enabled = false,
    CloneCount = 0
}
local CloneFloatingUI = nil
local CloneMainFrame = nil
local CloneToggleRef = nil

--// ANDROID TOUCH BUTTONS
local function CreateAndroidButtons()
    if not IsAndroid then return end
    
    local TouchFrame = Instance.new("Frame")
    TouchFrame.Name = "AndroidButtons"
    TouchFrame.Size = UDim2.new(1, 0, 1, 0)
    TouchFrame.BackgroundTransparency = 1
    TouchFrame.Parent = UserGui
    
    local buttonConfigs = {
        {Name = "FlyBtn", Pos = UDim2.new(0, 10, 0.5, -25), Color = Color3.fromRGB(0, 150, 255)},
        {Name = "SpeedBtn", Pos = UDim2.new(0, 10, 0.6, -25), Color = Color3.fromRGB(0, 200, 0)},
        {Name = "AimBtn", Pos = UDim2.new(0, 10, 0.4, -25), Color = Color3.fromRGB(255, 0, 0)},
        {Name = "EspBtn", Pos = UDim2.new(0, 10, 0.7, -25), Color = Color3.fromRGB(255, 200, 0)},
        {Name = "TeleBtn", Pos = UDim2.new(0.9, -50, 0.5, -25), Color = Color3.fromRGB(150, 0, 255)},
        {Name = "CloneBtn", Pos = UDim2.new(0.9, -50, 0.6, -25), Color = Color3.fromRGB(100, 60, 255)},
    }
    
    for _, cfg in pairs(buttonConfigs) do
        local btn = Instance.new("TextButton")
        btn.Name = cfg.Name
        local size = cfg.Size or 50
        btn.Size = UDim2.new(0, size, 0, size)
        btn.Position = cfg.Pos
        btn.BackgroundColor3 = cfg.Color
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextScaled = true
        btn.BorderSizePixel = 0
        btn.BackgroundTransparency = 0.3
        btn.Parent = TouchFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(1, 0)
        btnCorner.Parent = btn
        
        table.insert(TouchButtons, {Button = btn, Name = cfg.Name})
    end
    
    return TouchFrame
end

local AndroidButtonFrame = CreateAndroidButtons()

--------------------------------------------------------------------------------
-- FLY CONTROL UI (Compacto e Moderno)
--------------------------------------------------------------------------------

local function CreateFlyControlButtons()
    if not IsAndroid then return nil end

    if FlyControlFrame then
        pcall(function() FlyControlFrame:Destroy() end)
        FlyControlFrame = nil
    end

    local flyGui = Instance.new("ScreenGui")
    flyGui.Name = "FlyControlGui"
    flyGui.ResetOnSpawn = false
    flyGui.DisplayOrder = 100
    flyGui.Parent = UserGui

    FlyControlFrame = Instance.new("Frame")
    FlyControlFrame.Name = "FlyControls"
    FlyControlFrame.Size = UDim2.new(0, 56, 0, 120)
    FlyControlFrame.Position = UDim2.new(1, -68, 0.5, -60)
    FlyControlFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    FlyControlFrame.BackgroundTransparency = 0.08
    FlyControlFrame.BorderSizePixel = 0
    FlyControlFrame.Visible = false
    FlyControlFrame.ZIndex = 50
    FlyControlFrame.Parent = flyGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = FlyControlFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(60, 130, 220)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    mainStroke.Parent = FlyControlFrame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 20))
    })
    gradient.Rotation = 90
    gradient.Parent = FlyControlFrame

    -- Arrastar
    local dragging = false
    local dragStart, startPos

    FlyControlFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = FlyControlFrame.Position
        end
    end)

    FlyControlFrame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            FlyControlFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    FlyControlFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    local flyIcon = Instance.new("TextLabel")
    flyIcon.Size = UDim2.new(1, 0, 0, 16)
    flyIcon.Position = UDim2.new(0, 0, 0, 4)
    flyIcon.BackgroundTransparency = 1
    flyIcon.Text = "✈"
    flyIcon.TextColor3 = Color3.fromRGB(80, 170, 255)
    flyIcon.TextSize = 12
    flyIcon.Font = Enum.Font.GothamBold
    flyIcon.ZIndex = 51
    flyIcon.Parent = FlyControlFrame

    -- Botão UP
    local UpBtn = Instance.new("TextButton")
    UpBtn.Name = "FlyUp"
    UpBtn.Size = UDim2.new(0, 42, 0, 38)
    UpBtn.Position = UDim2.new(0.5, -21, 0, 22)
    UpBtn.BackgroundColor3 = Color3.fromRGB(35, 140, 75)
    UpBtn.Text = ""
    UpBtn.BorderSizePixel = 0
    UpBtn.ZIndex = 52
    UpBtn.AutoButtonColor = false
    UpBtn.Parent = FlyControlFrame

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0, 10)
    upCorner.Parent = UpBtn

    local upStroke = Instance.new("UIStroke")
    upStroke.Color = Color3.fromRGB(70, 200, 120)
    upStroke.Thickness = 1
    upStroke.Transparency = 0.5
    upStroke.Parent = UpBtn

    local upGradient = Instance.new("UIGradient")
    upGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 180, 100)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 120, 65))
    })
    upGradient.Rotation = 90
    upGradient.Parent = UpBtn

    local upArrow = Instance.new("TextLabel")
    upArrow.Size = UDim2.new(1, 0, 1, 0)
    upArrow.BackgroundTransparency = 1
    upArrow.Text = "▲"
    upArrow.TextColor3 = Color3.fromRGB(220, 255, 230)
    upArrow.TextSize = 18
    upArrow.Font = Enum.Font.GothamBold
    upArrow.ZIndex = 53
    upArrow.Parent = UpBtn

    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(0.6, 0, 0, 1)
    separator.Position = UDim2.new(0.2, 0, 0.5, -1)
    separator.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    separator.BackgroundTransparency = 0.5
    separator.BorderSizePixel = 0
    separator.ZIndex = 51
    separator.Parent = FlyControlFrame

    -- Botão DOWN
    local DownBtn = Instance.new("TextButton")
    DownBtn.Name = "FlyDown"
    DownBtn.Size = UDim2.new(0, 42, 0, 38)
    DownBtn.Position = UDim2.new(0.5, -21, 0, 64)
    DownBtn.BackgroundColor3 = Color3.fromRGB(170, 60, 35)
    DownBtn.Text = ""
    DownBtn.BorderSizePixel = 0
    DownBtn.ZIndex = 52
    DownBtn.AutoButtonColor = false
    DownBtn.Parent = FlyControlFrame

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0, 10)
    downCorner.Parent = DownBtn

    local downStroke = Instance.new("UIStroke")
    downStroke.Color = Color3.fromRGB(230, 100, 70)
    downStroke.Thickness = 1
    downStroke.Transparency = 0.5
    downStroke.Parent = DownBtn

    local downGradient = Instance.new("UIGradient")
    downGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 85, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 50, 30))
    })
    downGradient.Rotation = 90
    downGradient.Parent = DownBtn

    local downArrow = Instance.new("TextLabel")
    downArrow.Size = UDim2.new(1, 0, 1, 0)
    downArrow.BackgroundTransparency = 1
    downArrow.Text = "▼"
    downArrow.TextColor3 = Color3.fromRGB(255, 220, 210)
    downArrow.TextSize = 18
    downArrow.Font = Enum.Font.GothamBold
    downArrow.ZIndex = 53
    downArrow.Parent = DownBtn

    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "SpeedLabel"
    speedLabel.Size = UDim2.new(1, 0, 0, 14)
    speedLabel.Position = UDim2.new(0, 0, 1, -16)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = tostring(math.floor(Config.FlySpeed))
    speedLabel.TextColor3 = Color3.fromRGB(140, 140, 170)
    speedLabel.TextSize = 9
    speedLabel.Font = Enum.Font.GothamMedium
    speedLabel.ZIndex = 51
    speedLabel.Parent = FlyControlFrame

    -- Conexões UP
    UpBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidUpPressed = true
            upStroke.Color = Color3.fromRGB(120, 255, 170)
            upStroke.Transparency = 0
            upArrow.TextColor3 = Color3.fromRGB(255, 255, 255)
            upGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 220, 130)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 160, 85))
            })
        end
    end)

    UpBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidUpPressed = false
            upStroke.Color = Color3.fromRGB(70, 200, 120)
            upStroke.Transparency = 0.5
            upArrow.TextColor3 = Color3.fromRGB(220, 255, 230)
            upGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 180, 100)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 120, 65))
            })
        end
    end)

    -- Conexões DOWN
    DownBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidDownPressed = true
            downStroke.Color = Color3.fromRGB(255, 150, 100)
            downStroke.Transparency = 0
            downArrow.TextColor3 = Color3.fromRGB(255, 255, 255)
            downGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 110, 70)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 70, 45))
            })
        end
    end)

    DownBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidDownPressed = false
            downStroke.Color = Color3.fromRGB(230, 100, 70)
            downStroke.Transparency = 0.5
            downArrow.TextColor3 = Color3.fromRGB(255, 220, 210)
            downGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 85, 50)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 50, 30))
            })
        end
    end)

    return speedLabel
end

FlySpeedLabel = CreateFlyControlButtons()

--------------------------------------------------------------------------------
-- FLY SYSTEM FUNCTIONS
--------------------------------------------------------------------------------

local function StartFly()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end

    IsFlying = true

    if BodyVel then pcall(function() BodyVel:Destroy() end) end
    if BodyGyro then pcall(function() BodyGyro:Destroy() end) end

    BodyVel = Instance.new("BodyVelocity")
    BodyVel.Name = "DevsHubFlyVel"
    BodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVel.Velocity = Vector3.zero
    BodyVel.P = 1250
    BodyVel.Parent = root

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.Name = "DevsHubFlyGyro"
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = 9e4
    BodyGyro.D = 500
    BodyGyro.CFrame = Camera.CFrame
    BodyGyro.Parent = root

    hum.PlatformStand = true

    if IsAndroid and FlyControlFrame then
        FlyControlFrame.Visible = true
    end
end

local function StopFly()
    IsFlying = false

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
    end

    if BodyVel then
        pcall(function() BodyVel:Destroy() end)
        BodyVel = nil
    end
    if BodyGyro then
        pcall(function() BodyGyro:Destroy() end)
        BodyGyro = nil
    end

    AndroidUpPressed = false
    AndroidDownPressed = false

    if IsAndroid and FlyControlFrame then
        FlyControlFrame.Visible = false
    end
end

local function GetFlyVelocity()
    local cam = Camera.CFrame
    local moveDir = Vector3.zero

    if IsAndroid then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")

        if hum and hum.MoveDirection.Magnitude > 0.1 then
            local camLook = cam.LookVector
            local camRight = cam.RightVector

            local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
            if flatLook.Magnitude > 0.01 then flatLook = flatLook.Unit end
            local flatRight = Vector3.new(camRight.X, 0, camRight.Z)
            if flatRight.Magnitude > 0.01 then flatRight = flatRight.Unit end

            local md = hum.MoveDirection
            local forward = flatLook:Dot(md)
            local right = flatRight:Dot(md)

            moveDir = moveDir + cam.LookVector * forward
            moveDir = moveDir + cam.RightVector * right
        end

        if AndroidUpPressed then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if AndroidDownPressed then
            moveDir = moveDir + Vector3.new(0, -1, 0)
        end
    else
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + cam.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - cam.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - cam.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + cam.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or
           UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or
           UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir + Vector3.new(0, -1, 0)
        end
    end

    if moveDir.Magnitude > 0.01 then
        moveDir = moveDir.Unit
    else
        moveDir = Vector3.zero
    end

    return moveDir * Config.FlySpeed
end

--------------------------------------------------------------------------------
-- CLONE TOOL FLOATING UI (Android Compatible)
--------------------------------------------------------------------------------

local function GetEquippedTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, child in pairs(char:GetChildren()) do
        if child:IsA("Tool") then
            return child
        end
    end
    return nil
end

local function DeepCloneTool(originalTool)
    if not originalTool or not originalTool:IsA("Tool") then
        return nil
    end

    local clonedTool = originalTool:Clone()

    clonedTool.Name = originalTool.Name
    clonedTool.ToolTip = originalTool.ToolTip
    clonedTool.CanBeDropped = originalTool.CanBeDropped
    clonedTool.Enabled = originalTool.Enabled
    clonedTool.ManualActivationOnly = originalTool.ManualActivationOnly
    clonedTool.RequiresHandle = originalTool.RequiresHandle

    pcall(function()
        for attrName, attrValue in pairs(originalTool:GetAttributes()) do
            clonedTool:SetAttribute(attrName, attrValue)
        end
    end)

    return clonedTool
end

local function CreateCloneFloatingUI()
    if CloneFloatingUI then
        pcall(function() CloneFloatingUI:Destroy() end)
        CloneFloatingUI = nil
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CloneToolGui"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 110
    screenGui.Parent = UserGui

    CloneFloatingUI = screenGui

    -- Tamanhos adaptativos para Android
    local frameWidth = IsAndroid and 200 or 220
    local frameHeight = IsAndroid and 175 or 160
    local fontSize = IsAndroid and 11 or 13
    local smallFont = IsAndroid and 9 or 11
    local tinyFont = IsAndroid and 8 or 10
    local btnHeight = IsAndroid and 48 or 44
    local headerHeight = IsAndroid and 40 or 36

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "CloneContainer"
    mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
    mainFrame.Position = IsAndroid 
        and UDim2.new(0.5, -frameWidth/2, 0.15, 0) 
        or UDim2.new(0.5, -frameWidth/2, 0, 120)
    mainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.ZIndex = 60
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 16)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(100, 60, 255)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.3
    mainStroke.Parent = mainFrame

    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 18, 38)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 22))
    })
    bgGradient.Rotation = 90
    bgGradient.Parent = mainFrame

    -- Sombra
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.BackgroundTransparency = 1
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.Image = "rbxassetid://6014261993"
    shadow.ZIndex = 59
    shadow.Parent = mainFrame

    -- Arrastar (Touch + Mouse)
    local dragging = false
    local dragStart, startPos

    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- Header
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, headerHeight)
    headerFrame.BackgroundColor3 = Color3.fromRGB(100, 60, 255)
    headerFrame.BackgroundTransparency = 0.7
    headerFrame.BorderSizePixel = 0
    headerFrame.ZIndex = 61
    headerFrame.Parent = mainFrame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 16)
    headerCorner.Parent = headerFrame

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 16)
    headerFix.Position = UDim2.new(0, 0, 1, -16)
    headerFix.BackgroundColor3 = Color3.fromRGB(100, 60, 255)
    headerFix.BackgroundTransparency = 0.7
    headerFix.BorderSizePixel = 0
    headerFix.ZIndex = 61
    headerFix.Parent = headerFrame

    local titleIcon = Instance.new("TextLabel")
    titleIcon.Size = UDim2.new(0, 30, 1, 0)
    titleIcon.Position = UDim2.new(0, 8, 0, 0)
    titleIcon.BackgroundTransparency = 1
    titleIcon.Text = "📋"
    titleIcon.TextSize = IsAndroid and 14 or 16
    titleIcon.Font = Enum.Font.GothamBold
    titleIcon.ZIndex = 62
    titleIcon.Parent = headerFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -80, 1, 0)
    titleLabel.Position = UDim2.new(0, 36, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "CLONE TOOL"
    titleLabel.TextColor3 = Color3.fromRGB(220, 210, 255)
    titleLabel.TextSize = fontSize
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 62
    titleLabel.Parent = headerFrame

    -- Botão fechar
    local closeBtnSize = IsAndroid and 32 or 28
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, closeBtnSize, 0, closeBtnSize)
    closeBtn.Position = UDim2.new(1, -(closeBtnSize + 4), 0, (headerHeight - closeBtnSize) / 2)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BackgroundTransparency = 0.6
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    closeBtn.TextSize = IsAndroid and 16 or 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 63
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = headerFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(1, 0)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        CloneConfig.Enabled = false
        mainFrame.Visible = false
        pcall(function()
            if CloneToggleRef then
                CloneToggleRef:Set(false)
            end
        end)
    end)

    closeBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            closeBtn.BackgroundTransparency = 0.3
        end
    end)

    closeBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            closeBtn.BackgroundTransparency = 0.6
        end
    end)

    -- Label do item atual
    local itemLabel = Instance.new("TextLabel")
    itemLabel.Name = "ItemLabel"
    itemLabel.Size = UDim2.new(1, -20, 0, 20)
    itemLabel.Position = UDim2.new(0, 10, 0, headerHeight + 6)
    itemLabel.BackgroundTransparency = 1
    itemLabel.Text = "🔧 No item equipped"
    itemLabel.TextColor3 = Color3.fromRGB(160, 160, 190)
    itemLabel.TextSize = smallFont
    itemLabel.Font = Enum.Font.GothamMedium
    itemLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
    itemLabel.ZIndex = 62
    itemLabel.Parent = mainFrame

    -- Contador de clones
    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(1, -20, 0, 16)
    countLabel.Position = UDim2.new(0, 10, 0, headerHeight + 28)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "Clones: 0"
    countLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
    countLabel.TextSize = tinyFont
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.ZIndex = 62
    countLabel.Parent = mainFrame

    -- Separador
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.85, 0, 0, 1)
    sep.Position = UDim2.new(0.075, 0, 0, headerHeight + 48)
    sep.BackgroundColor3 = Color3.fromRGB(80, 60, 150)
    sep.BackgroundTransparency = 0.6
    sep.BorderSizePixel = 0
    sep.ZIndex = 61
    sep.Parent = mainFrame

    -- Botão CLONE principal (maior no Android para toque fácil)
    local cloneBtn = Instance.new("TextButton")
    cloneBtn.Name = "CloneBtn"
    cloneBtn.Size = UDim2.new(0.85, 0, 0, btnHeight)
    cloneBtn.Position = UDim2.new(0.075, 0, 0, headerHeight + 56)
    cloneBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 200)
    cloneBtn.Text = ""
    cloneBtn.BorderSizePixel = 0
    cloneBtn.ZIndex = 62
    cloneBtn.AutoButtonColor = false
    cloneBtn.Parent = mainFrame

    local cloneBtnCorner = Instance.new("UICorner")
    cloneBtnCorner.CornerRadius = UDim.new(0, 12)
    cloneBtnCorner.Parent = cloneBtn

    local cloneBtnStroke = Instance.new("UIStroke")
    cloneBtnStroke.Color = Color3.fromRGB(130, 100, 255)
    cloneBtnStroke.Thickness = 1
    cloneBtnStroke.Transparency = 0.4
    cloneBtnStroke.Parent = cloneBtn

    local cloneBtnGradient = Instance.new("UIGradient")
    cloneBtnGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 70, 230)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 50, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 35, 170))
    })
    cloneBtnGradient.Rotation = 90
    cloneBtnGradient.Parent = cloneBtn

    local cloneIcon = Instance.new("TextLabel")
    cloneIcon.Size = UDim2.new(0, 30, 1, 0)
    cloneIcon.Position = UDim2.new(0, 15, 0, 0)
    cloneIcon.BackgroundTransparency = 1
    cloneIcon.Text = "📋"
    cloneIcon.TextSize = IsAndroid and 20 or 18
    cloneIcon.ZIndex = 63
    cloneIcon.Parent = cloneBtn

    local cloneText = Instance.new("TextLabel")
    cloneText.Name = "CloneText"
    cloneText.Size = UDim2.new(1, -55, 1, 0)
    cloneText.Position = UDim2.new(0, 48, 0, 0)
    cloneText.BackgroundTransparency = 1
    cloneText.Text = "CLONE ITEM"
    cloneText.TextColor3 = Color3.fromRGB(230, 220, 255)
    cloneText.TextSize = IsAndroid and 15 or 14
    cloneText.Font = Enum.Font.GothamBold
    cloneText.TextXAlignment = Enum.TextXAlignment.Left
    cloneText.ZIndex = 63
    cloneText.Parent = cloneBtn

    -- Botão Clone All (abaixo do clone principal, só aparece no Android como extra)
    local cloneAllBtn = Instance.new("TextButton")
    cloneAllBtn.Name = "CloneAllBtn"
    cloneAllBtn.Size = UDim2.new(0.85, 0, 0, IsAndroid and 36 or 30)
    cloneAllBtn.Position = UDim2.new(0.075, 0, 0, headerHeight + 56 + btnHeight + 6)
    cloneAllBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 100)
    cloneAllBtn.Text = ""
    cloneAllBtn.BorderSizePixel = 0
    cloneAllBtn.ZIndex = 62
    cloneAllBtn.AutoButtonColor = false
    cloneAllBtn.Parent = mainFrame

    local cloneAllCorner = Instance.new("UICorner")
    cloneAllCorner.CornerRadius = UDim.new(0, 10)
    cloneAllCorner.Parent = cloneAllBtn

    local cloneAllStroke = Instance.new("UIStroke")
    cloneAllStroke.Color = Color3.fromRGB(90, 70, 180)
    cloneAllStroke.Thickness = 1
    cloneAllStroke.Transparency = 0.5
    cloneAllStroke.Parent = cloneAllBtn

    local cloneAllText = Instance.new("TextLabel")
    cloneAllText.Size = UDim2.new(1, 0, 1, 0)
    cloneAllText.BackgroundTransparency = 1
    cloneAllText.Text = "📦 CLONE ALL BACKPACK"
    cloneAllText.TextColor3 = Color3.fromRGB(170, 160, 210)
    cloneAllText.TextSize = IsAndroid and 11 or 10
    cloneAllText.Font = Enum.Font.GothamBold
    cloneAllText.ZIndex = 63
    cloneAllText.Parent = cloneAllBtn

    -- Atualizar tamanho do frame para incluir o botão extra
    local totalHeight = headerHeight + 56 + btnHeight + 6 + (IsAndroid and 36 or 30) + 12
    mainFrame.Size = UDim2.new(0, frameWidth, 0, totalHeight)

    -- Funções de efeito visual
    local function UpdateItemLabel()
        local tool = GetEquippedTool()
        if tool then
            itemLabel.Text = "🔧 " .. tool.Name
            itemLabel.TextColor3 = Color3.fromRGB(130, 255, 180)
            cloneBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 200)
            cloneText.TextColor3 = Color3.fromRGB(230, 220, 255)
        else
            itemLabel.Text = "🔧 No item equipped"
            itemLabel.TextColor3 = Color3.fromRGB(160, 160, 190)
            cloneBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
            cloneText.TextColor3 = Color3.fromRGB(130, 130, 150)
        end
        countLabel.Text = "Clones: " .. CloneConfig.CloneCount
    end

    local function PulseEffect()
        cloneBtnStroke.Color = Color3.fromRGB(180, 255, 180)
        cloneBtnStroke.Transparency = 0

        cloneBtnGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 200, 100)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 170, 80)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 140, 65))
        })

        cloneText.Text = "✓ CLONED!"
        cloneText.TextColor3 = Color3.fromRGB(180, 255, 200)

        task.delay(0.8, function()
            pcall(function()
                cloneBtnStroke.Color = Color3.fromRGB(130, 100, 255)
                cloneBtnStroke.Transparency = 0.4

                cloneBtnGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 70, 230)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 50, 200)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 35, 170))
                })

                cloneText.Text = "CLONE ITEM"
                cloneText.TextColor3 = Color3.fromRGB(230, 220, 255)
            end)
        end)
    end

    local function ErrorEffect()
        cloneBtnStroke.Color = Color3.fromRGB(255, 80, 80)
        cloneBtnStroke.Transparency = 0

        cloneBtnGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 60, 60)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 40, 40)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 30, 30))
        })

        cloneText.Text = "✕ NO ITEM!"
        cloneText.TextColor3 = Color3.fromRGB(255, 180, 180)

        task.delay(1, function()
            pcall(function()
                cloneBtnStroke.Color = Color3.fromRGB(130, 100, 255)
                cloneBtnStroke.Transparency = 0.4

                cloneBtnGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 70, 230)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 50, 200)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 35, 170))
                })

                cloneText.Text = "CLONE ITEM"
                cloneText.TextColor3 = Color3.fromRGB(230, 220, 255)
                UpdateItemLabel()
            end)
        end)
    end

    -- Touch feedback para botão clone
    cloneBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            cloneBtnStroke.Transparency = 0
            cloneBtnStroke.Color = Color3.fromRGB(180, 150, 255)
        end
    end)

    cloneBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            cloneBtnStroke.Transparency = 0.4
            cloneBtnStroke.Color = Color3.fromRGB(130, 100, 255)
        end
    end)

    -- Touch feedback para botão clone all
    cloneAllBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            cloneAllStroke.Transparency = 0
            cloneAllStroke.Color = Color3.fromRGB(140, 120, 230)
        end
    end)

    cloneAllBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            cloneAllStroke.Transparency = 0.5
            cloneAllStroke.Color = Color3.fromRGB(90, 70, 180)
        end
    end)

    -- Ação de clonar item equipado
    cloneBtn.MouseButton1Click:Connect(function()
        local equippedTool = GetEquippedTool()

        if not equippedTool then
            ErrorEffect()
            Xan.Notify({
                Title = "Clone Tool",
                Content = "No item equipped! Equip a tool first.",
                Type = "Error"
            })
            return
        end

        local success, result = pcall(function()
            local cloned = DeepCloneTool(equippedTool)
            if cloned then
                cloned.Parent = LocalPlayer.Backpack
                return cloned
            end
            return nil
        end)

        if success and result then
            CloneConfig.CloneCount = CloneConfig.CloneCount + 1
            PulseEffect()
            UpdateItemLabel()

            Xan.Notify({
                Title = "Clone Tool",
                Content = "'" .. result.Name .. "' cloned! (Total: " .. CloneConfig.CloneCount .. ")",
                Type = "Success"
            })
        else
            ErrorEffect()
            Xan.Notify({
                Title = "Clone Tool",
                Content = "Clone failed: " .. tostring(result),
                Type = "Error"
            })
        end
    end)

    -- Ação de clonar toda a mochila
    cloneAllBtn.MouseButton1Click:Connect(function()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local tools = {}

        if backpack then
            for _, item in pairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(tools, item)
                end
            end
        end

        local char = LocalPlayer.Character
        if char then
            for _, item in pairs(char:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(tools, item)
                end
            end
        end

        if #tools == 0 then
            Xan.Notify({Title = "Clone", Content = "No tools to clone!", Type = "Error"})

            cloneAllText.Text = "✕ NO TOOLS!"
            cloneAllText.TextColor3 = Color3.fromRGB(255, 150, 150)
            cloneAllStroke.Color = Color3.fromRGB(255, 80, 80)

            task.delay(1, function()
                pcall(function()
                    cloneAllText.Text = "📦 CLONE ALL BACKPACK"
                    cloneAllText.TextColor3 = Color3.fromRGB(170, 160, 210)
                    cloneAllStroke.Color = Color3.fromRGB(90, 70, 180)
                end)
            end)
            return
        end

        local clonedCount = 0
        for _, tool in pairs(tools) do
            pcall(function()
                local c = DeepCloneTool(tool)
                if c then
                    c.Parent = LocalPlayer.Backpack
                    clonedCount = clonedCount + 1
                    CloneConfig.CloneCount = CloneConfig.CloneCount + 1
                end
            end)
        end

        UpdateItemLabel()

        cloneAllText.Text = "✓ " .. clonedCount .. " CLONED!"
        cloneAllText.TextColor3 = Color3.fromRGB(150, 255, 180)
        cloneAllStroke.Color = Color3.fromRGB(80, 200, 120)

        task.delay(1, function()
            pcall(function()
                cloneAllText.Text = "📦 CLONE ALL BACKPACK"
                cloneAllText.TextColor3 = Color3.fromRGB(170, 160, 210)
                cloneAllStroke.Color = Color3.fromRGB(90, 70, 180)
            end)
        end)

        Xan.Notify({
            Title = "Clone Tool",
            Content = clonedCount .. " tools cloned! (Total: " .. CloneConfig.CloneCount .. ")",
            Type = "Success"
        })
    end)

    -- Loop para atualizar label
    task.spawn(function()
        while CloneFloatingUI and CloneFloatingUI.Parent do
            if mainFrame.Visible then
                pcall(function()
                    UpdateItemLabel()
                end)
            end
            task.wait(0.3)
        end
    end)

    return mainFrame
end

--------------------------------------------------------------------------------
-- INITIALIZE WINDOW
--------------------------------------------------------------------------------

local function InitializeWindow()
    pcall(function()
        if IsAndroid then
            Xan.Splash({
                Title = "DEVS HUB",
                Subtitle = "Inicializando...",
                Duration = 1,
                Theme = "Midnight"
            })
        else
            Xan.Splash({
                Title = "DEVS HUB",
                Subtitle = "System Initialization...",
                Duration = 2,
                Theme = "Midnight"
            })
        end
    end)

    local GameName = "Unknown Game"
    local GameIcon = Xan.Logos.Default

    task.spawn(function()
        pcall(function()
            local info = MarketplaceService:GetProductInfo(game.PlaceId)
            GameName = info.Name
        end)

        local success, response = pcall(function()
            local r = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
            if r then
                return r({
                    Url = "https://api.xan.bar/api/games/lookup?name=" .. HttpService:UrlEncode(GameName),
                    Method = "GET"
                })
            end
        end)

        if success and response and response.StatusCode == 200 then
            local data = HttpService:JSONDecode(response.Body)
            if data.success and data.game then
                GameIcon = data.game.backup_rbxasset or data.game.rbxthumb
            end
        elseif Xan.GameIcons[GameName] then
            GameIcon = Xan.GameIcons[GameName]
        end
    end)

    if IsAndroid then
        task.wait(1.5)
    else
        task.wait(2.2)
    end

    local success, err = pcall(function()
        Window = Xan:CreateWindow({
            Title = "DEVS HUB",
            Subtitle = GameName,
            Theme = "Midnight",
            Size = IsAndroid and UDim2.new(0.9, 0, 0.9, 0) or UDim2.new(0, 580, 0, 450),
            ShowActiveList = not IsAndroid,
            ShowLogo = true,
            Logo = GameIcon,
            ConfigName = "DevsHub"
        })
    end)

    if not success or not Window then
        warn("Erro ao criar janela: " .. tostring(err))
        return false
    end

    pcall(function()
        Xan.MobileToggle({Window = Window, Position = UDim2.new(0.85, 0, 0.1, 0), Visible = true})
    end)

    local Watermark = pcall(function()
        return Xan.Watermark({
            Text = "DEVS HUB | " .. os.date("%X"),
            Visible = true,
            ShowFPS = true,
            ShowPing = true,
            Theme = "Midnight"
        })
    end)

    if Watermark then
        task.spawn(function()
            while Window do
                pcall(function()
                    Watermark:SetText("DEVS HUB | " .. os.date("%X"))
                end)
                task.wait(1)
            end
        end)
    end

    return true
end

task.wait(0.5)

if not InitializeWindow() then
    warn("Falha ao inicializar a janela principal")
    return
end

--// GUI TABS
local MainTab = Window:AddTab("Main", Xan.Icons.Home)
local ConfigTab = Window:AddTab("Config", Xan.Icons.Settings)
local PlayerTab = Window:AddTab("Player", Xan.Icons.Person)
local DevsTab = Window:AddTab("Devs", Xan.Icons.Code)

--------------------------------------------------------------------------------
-- MAIN TAB: COMBAT
--------------------------------------------------------------------------------

MainTab:AddSection("Combat")

local AimToggle = MainTab:AddToggle("Aimlock", "aim_state", function(v)
    Config.Aimlock = v
end)
MainTab:AddKeybind("Aimlock Key [G]", "aim_key", Enum.KeyCode.G, function()
    AimToggle:Set(not AimToggle.Value())
end)
MainTab:AddSlider("Aim FOV", "aim_fov", {Min = 100, Max = 2000, Default = 1000}, function(v)
    Config.AimRange = v
end)

MainTab:AddCharacterPreview({
    Name = "Hitbox Targeting",
    HitboxParts = {"Head", "Chest", "Arms", "Legs"},
    Default = {Head = true, Chest = true},
    Callback = function(val)
        Config.HitParts = val
    end
})

--------------------------------------------------------------------------------
-- MAIN TAB: VISUALS
--------------------------------------------------------------------------------

MainTab:AddSection("Visuals")

local EspToggle = MainTab:AddToggle("X-Ray (Chams)", "esp_state", function(v)
    Config.ESP = v
    if not v then
        for _, o in pairs(Objects) do
            if o.Name == "HLCache" then
                pcall(function() o:Destroy() end)
            end
        end
        return
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not p.Character:FindFirstChild("HLCache") then
            pcall(function()
                local hl = Instance.new("Highlight")
                hl.Name = "HLCache"
                hl.FillColor = Color3.fromRGB(255, 0, 0)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.5
                hl.Parent = p.Character
                table.insert(Objects, hl)
            end)
        end
    end
end)
MainTab:AddKeybind("X-Ray Key [H]", "esp_key", Enum.KeyCode.H, function()
    EspToggle:Set(not EspToggle.Value())
end)
MainTab:AddCrosshair("Crosshair", {Enabled = false})

--------------------------------------------------------------------------------
-- MAIN TAB: MOVEMENT
--------------------------------------------------------------------------------

MainTab:AddSection("Movement")

local FlightTog = MainTab:AddToggle("Fly Hack", "fly_hack", function(v)
    Config.Fly = v
    if v then
        if IsAndroid then
            Xan.Notify({
                Title = "Flight",
                Content = "Joystick para mover + ▲/▼ subir/descer",
                Type = "Success"
            })
        else
            Xan.Notify({
                Title = "Flight",
                Content = "WASD mover, E/Space subir, Q/Shift descer",
                Type = "Success"
            })
        end
    end
end)
MainTab:AddKeybind("Fly Key [F]", "fly_key", Enum.KeyCode.F, function()
    FlightTog:Set(not FlightTog.Value())
end)
MainTab:AddSlider("Fly Speed", "fly_val", {Min = 10, Max = 700, Default = 50}, function(v)
    Config.FlySpeed = v
end)

local SpeedTog = MainTab:AddToggle("Speed Hack", "speed_hack", function(v)
    Config.SpeedHack = v
    if not v and LocalPlayer.Character then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
    end
end)
MainTab:AddKeybind("Speed Key [J]", "speed_key", Enum.KeyCode.J, function()
    SpeedTog:Set(not SpeedTog.Value())
end)
MainTab:AddSlider("Walk Speed", "speed_val", {Min = 16, Max = 300, Default = 16}, function(v)
    Config.WalkSpeed = v
end)

local JumpTog = MainTab:AddToggle("Jump Hack", "jump_hack", function(v)
    Config.JumpHack = v
    if not v and LocalPlayer.Character then
        LocalPlayer.Character.Humanoid.JumpPower = 50
    end
end)
MainTab:AddKeybind("Jump Key [K]", "jump_key", Enum.KeyCode.K, function()
    JumpTog:Set(not JumpTog.Value())
end)
MainTab:AddSlider("Jump Power", "jump_val", {Min = 50, Max = 500, Default = 50}, function(v)
    Config.JumpPower = v
end)

local NoclipTog = MainTab:AddToggle("No Clip", "noclip_hack", function(v)
    Config.Noclip = v
end)
MainTab:AddKeybind("No Clip Key [N]", "noclip_key", Enum.KeyCode.N, function()
    NoclipTog:Set(not NoclipTog.Value())
end)

local InfJumpTog = MainTab:AddToggle("Inf Jump", "inf_jump", function(v)
    Config.InfJump = v
end)
MainTab:AddKeybind("Inf Jump Key [L]", "inf_jump_key", Enum.KeyCode.L, function()
    InfJumpTog:Set(not InfJumpTog.Value())
end)

--------------------------------------------------------------------------------
-- MAIN TAB: TELEPORT
--------------------------------------------------------------------------------

MainTab:AddSection("Teleport")

local function GetPlayerNames()
    local names = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    table.sort(names)
    if #names == 0 then
        table.insert(names, "No Other Players")
    end
    return names
end

local TpDropdown = MainTab:AddDropdown("Select Player", "tp_target", GetPlayerNames(), function(v)
    Config.TargetPlr = Players:FindFirstChild(v)
end)

Connections["PlrAdded"] = Players.PlayerAdded:Connect(function()
    TpDropdown:SetOptions(GetPlayerNames())
end)
Connections["PlrRemoved"] = Players.PlayerRemoving:Connect(function()
    TpDropdown:SetOptions(GetPlayerNames())
end)

MainTab:AddButton("Refresh Dropdown", function()
    TpDropdown:SetOptions(GetPlayerNames())
end)

MainTab:AddButton("Teleport [U]", function()
    if Config.TargetPlr and Config.TargetPlr.Character then
        LocalPlayer.Character:SetPrimaryPartCFrame(
            Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
        )
        Xan.Notify({Title = "Teleport", Content = "Teleported to " .. Config.TargetPlr.Name})
    else
        Xan.Notify({Title = "Error", Content = "Invalid target.", Type = "Error"})
    end
end)

MainTab:AddSpeedometer("HUD Speed", {Min = 0, Max = 200, AutoTrack = true})

--------------------------------------------------------------------------------
-- PLAYER TAB: CHARACTER
--------------------------------------------------------------------------------

PlayerTab:AddSection("Character")

PlayerTab:AddButton("Reset Speed", function()
    if LocalPlayer.Character then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
        Xan.Notify({Title = "Character", Content = "Walk speed reset to 16"})
    end
end)

PlayerTab:AddButton("Reset Jump", function()
    if LocalPlayer.Character then
        LocalPlayer.Character.Humanoid.JumpPower = 50
        Xan.Notify({Title = "Character", Content = "Jump power reset to 50"})
    end
end)

PlayerTab:AddButton("Reset All", function()
    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then
            h.WalkSpeed = 16
            h.JumpPower = 50
            h.PlatformStand = false
            Xan.Notify({Title = "Character", Content = "All stats reset"})
        end
    end
end)

--------------------------------------------------------------------------------
-- PLAYER TAB: EQUIPMENT
--------------------------------------------------------------------------------

PlayerTab:AddSection("Equipment")

PlayerTab:AddButton("Remove All Tools", function()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                tool:Destroy()
            end
        end
    end
    if LocalPlayer.Character then
        for _, tool in pairs(LocalPlayer.Character:GetChildren()) do
            if tool:IsA("Tool") then
                tool:Destroy()
            end
        end
    end
    Xan.Notify({Title = "Equipment", Content = "All tools removed"})
end)

PlayerTab:AddButton("Drop All Tools", function()
    if LocalPlayer.Backpack then
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                tool.Parent = workspace
            end
        end
        Xan.Notify({Title = "Equipment", Content = "All tools dropped"})
    end
end)

--------------------------------------------------------------------------------
-- PLAYER TAB: HEALTH
--------------------------------------------------------------------------------

PlayerTab:AddSection("Health")

PlayerTab:AddButton("Heal", function()
    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then
            h.Health = h.MaxHealth
            Xan.Notify({Title = "Health", Content = "Healed to full health"})
        end
    end
end)

local HealthSlider = PlayerTab:AddSlider("Health Value", "health_val", {Min = 1, Max = 100, Default = 100}, function(v)
    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then
            h.Health = (h.MaxHealth / 100) * v
        end
    end
end)

--------------------------------------------------------------------------------
-- PLAYER TAB: THEFT
--------------------------------------------------------------------------------

PlayerTab:AddSection("Theft")

local StealToggle = PlayerTab:AddToggle("Steal Speed Hack", "steal_hack", function(v)
    Config.StealSpeed = v
    if v then
        Xan.Notify({Title = "Theft", Content = "Steal Speed enabled! Stealing " .. Config.StealMultiplier .. "x faster"})
    else
        Xan.Notify({Title = "Theft", Content = "Steal Speed disabled."})
    end
end)

PlayerTab:AddSlider("Steal Multiplier", "steal_mult", {Min = 1, Max = 10, Default = 2}, function(v)
    Config.StealMultiplier = v
end)

--------------------------------------------------------------------------------
-- PLAYER TAB: CLONE TOOL
--------------------------------------------------------------------------------

PlayerTab:AddSection("Clone Tool")

-- Criar a UI flutuante do clone
CloneMainFrame = CreateCloneFloatingUI()

CloneToggleRef = PlayerTab:AddToggle("Clone Tool Mode", "clone_tool_mode", function(v)
    CloneConfig.Enabled = v

    if not CloneMainFrame or not CloneMainFrame.Parent then
        CloneMainFrame = CreateCloneFloatingUI()
    end

    CloneMainFrame.Visible = v

    if v then
        Xan.Notify({
            Title = "Clone Tool",
            Content = IsAndroid 
                and "Equipe um item e toque CLONE ITEM!" 
                or "Equip a tool and press CLONE ITEM!",
            Type = "Success"
        })
    else
        Xan.Notify({
            Title = "Clone Tool",
            Content = "Clone mode disabled.",
            Type = "Info"
        })
    end
end)

if not IsAndroid then
    PlayerTab:AddKeybind("Clone Key [C]", "clone_key", Enum.KeyCode.C, function()
        CloneToggleRef:Set(not CloneConfig.Enabled)
    end)
end

PlayerTab:AddButton("Quick Clone (Equipped)", function()
    local tool = GetEquippedTool()

    if not tool then
        Xan.Notify({Title = "Clone", Content = "No tool equipped!", Type = "Error"})
        return
    end

    local success, cloned = pcall(function()
        local c = DeepCloneTool(tool)
        if c then
            c.Parent = LocalPlayer.Backpack
            return c
        end
        return nil
    end)

    if success and cloned then
        CloneConfig.CloneCount = CloneConfig.CloneCount + 1
        Xan.Notify({
            Title = "Clone Tool",
            Content = "'" .. cloned.Name .. "' cloned! (Total: " .. CloneConfig.CloneCount .. ")",
            Type = "Success"
        })
    else
        Xan.Notify({
            Title = "Clone Tool",
            Content = "Clone failed: " .. tostring(cloned),
            Type = "Error"
        })
    end
end)

PlayerTab:AddButton("Clone All Backpack", function()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local tools = {}

    if backpack then
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(tools, item)
            end
        end
    end

    local char = LocalPlayer.Character
    if char then
        for _, item in pairs(char:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(tools, item)
            end
        end
    end

    if #tools == 0 then
        Xan.Notify({Title = "Clone", Content = "No tools to clone!", Type = "Error"})
        return
    end

    local clonedCount = 0
    for _, tool in pairs(tools) do
        pcall(function()
            local c = DeepCloneTool(tool)
            if c then
                c.Parent = LocalPlayer.Backpack
                clonedCount = clonedCount + 1
                CloneConfig.CloneCount = CloneConfig.CloneCount + 1
            end
        end)
    end

    Xan.Notify({
        Title = "Clone Tool",
        Content = clonedCount .. " tools cloned! (Total: " .. CloneConfig.CloneCount .. ")",
        Type = "Success"
    })
end)

--------------------------------------------------------------------------------
-- PLAYER TAB: POSITION TELEPORT
--------------------------------------------------------------------------------

PlayerTab:AddSection("Position Teleport")

PlayerTab:AddButton("Save Position 1", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        Config.SavedPos1 = LocalPlayer.Character.HumanoidRootPart.CFrame
        Xan.Notify({Title = "Position", Content = "Position 1 saved!", Type = "Success"})
    else
        Xan.Notify({Title = "Position", Content = "Character not found!", Type = "Error"})
    end
end)

PlayerTab:AddButton("Save Position 2", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        Config.SavedPos2 = LocalPlayer.Character.HumanoidRootPart.CFrame
        Xan.Notify({Title = "Position", Content = "Position 2 saved!", Type = "Success"})
    else
        Xan.Notify({Title = "Position", Content = "Character not found!", Type = "Error"})
    end
end)

PlayerTab:AddButton("Teleport to Position 1", function()
    if Config.SavedPos1 and LocalPlayer.Character then
        LocalPlayer.Character:SetPrimaryPartCFrame(Config.SavedPos1)
        Xan.Notify({Title = "Teleport", Content = "Teleported to Position 1", Type = "Success"})
    else
        Xan.Notify({Title = "Teleport", Content = "Position 1 not saved!", Type = "Error"})
    end
end)

PlayerTab:AddButton("Teleport to Position 2", function()
    if Config.SavedPos2 and LocalPlayer.Character then
        LocalPlayer.Character:SetPrimaryPartCFrame(Config.SavedPos2)
        Xan.Notify({Title = "Teleport", Content = "Teleported to Position 2", Type = "Success"})
    else
        Xan.Notify({Title = "Teleport", Content = "Position 2 not saved!", Type = "Error"})
    end
end)

--------------------------------------------------------------------------------
-- DEVS TAB
--------------------------------------------------------------------------------

DevsTab:AddSection("Credits")

DevsTab:AddLabel("DEVS HUB")
DevsTab:AddLabel("Version: 1.1")
DevsTab:AddDivider()
DevsTab:AddLabel("Created by:")
DevsTab:AddLabel("mecharena1")
DevsTab:AddDivider()

DevsTab:AddSection("Information")

DevsTab:AddLabel("Library: Xan Hub")
DevsTab:AddLabel("Exploit: Multi-Compatible")
DevsTab:AddLabel("Platform: Roblox")
DevsTab:AddDivider()

DevsTab:AddButton("Check Updates", function()
    Xan.Notify({Title = "Updates", Content = "You are running the latest version!", Type = "Success"})
end)

DevsTab:AddSection("Debug Functions")

local DebugToggle = DevsTab:AddToggle("Debug Action Logger", "debug_action", function(v)
    Config.DebugEnabled = v
    if v then
        Xan.Notify({Title = "Debug", Content = "Debug Action Logger enabled! Press E to log actions.", Type = "Success"})
    else
        Xan.Notify({Title = "Debug", Content = "Debug Action Logger disabled."})
    end
end)

DevsTab:AddLabel("Logs actions when E is pressed")

--------------------------------------------------------------------------------
-- CONFIG TAB
--------------------------------------------------------------------------------

ConfigTab:AddInput("Config Name", {Flag = "cfg_name", Default = "default"})
ConfigTab:AddButton("Save Config", function()
    Xan:SaveConfig(Xan.Flags["cfg_name"] or "default")
end)
ConfigTab:AddButton("Load Config", function()
    Xan:LoadConfig(Xan.Flags["cfg_name"] or "default")
end)
ConfigTab:AddDivider()
ConfigTab:AddButton("Unload & Cleanup", function()
    StopFly()

    for _, c in pairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, o in pairs(Objects) do
        pcall(function() o:Destroy() end)
    end

    if FlyControlFrame then
        pcall(function()
            FlyControlFrame.Parent:Destroy()
        end)
    end

    if CloneFloatingUI then
        pcall(function()
            CloneFloatingUI:Destroy()
        end)
    end

    if AndroidButtonFrame then
        pcall(function()
            AndroidButtonFrame:Destroy()
        end)
    end

    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then
            h.PlatformStand = false
            h.WalkSpeed = 16
            h.JumpPower = 50
        end
    end

    if Window then
        pcall(function()
            Xan:Unload()
        end)
    end
end)

--------------------------------------------------------------------------------
-- LOOPS & LOGIC
--------------------------------------------------------------------------------

Connections["Loop"] = RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    if not hum or not root then return end

    -- NOCLIP
    if Config.Noclip then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end

    -- SPEED HACK
    if Config.SpeedHack then
        hum.WalkSpeed = Config.WalkSpeed
    end

    -- JUMP HACK
    if Config.JumpHack then
        hum.UseJumpPower = true
        hum.JumpPower = Config.JumpPower
    end

    -- FLY HACK
    if Config.Fly then
        if not IsFlying then
            StartFly()
        end

        if not BodyVel or not BodyVel.Parent or not BodyGyro or not BodyGyro.Parent then
            StopFly()
            StartFly()
        end

        if BodyVel and BodyGyro then
            BodyGyro.CFrame = Camera.CFrame
            BodyVel.Velocity = GetFlyVelocity()

            if FlySpeedLabel then
                pcall(function()
                    FlySpeedLabel.Text = tostring(math.floor(Config.FlySpeed))
                end)
            end
        end
    else
        if IsFlying then
            StopFly()
        end
    end

    -- STEAL SPEED HACK
    if Config.StealSpeed then
        pcall(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
                if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    local remoteName = remote.Name:lower()
                    if string.find(remoteName, "steal") or 
                       string.find(remoteName, "rob") or 
                       string.find(remoteName, "grab") or 
                       string.find(remoteName, "take") or 
                       string.find(remoteName, "action") then
                        if remote:IsA("RemoteEvent") then
                            for i = 1, Config.StealMultiplier do
                                remote:FireServer()
                                task.wait(0.05)
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- AIMLOCK
Connections["Aim"] = RunService.RenderStepped:Connect(function()
    if not Config.Aimlock then
        return
    end
    
    pcall(function()
        local mouse = UserInputService:GetMouseLocation()
        local best, bestDist = nil, Config.AimRange

        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and
                p.Character.Humanoid.Health > 0 then
                local part = nil
                if Config.HitParts.Head then
                    part = p.Character:FindFirstChild("Head")
                end
                if not part and Config.HitParts.Chest then
                    part = p.Character:FindFirstChild("HumanoidRootPart")
                end
                if not part then
                    part = p.Character:FindFirstChild("Head")
                end

                if part then
                    local pos, vis = Camera:WorldToViewportPoint(part.Position)
                    if vis then
                        local dist = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            best = part
                        end
                    end
                end
            end
        end

        if best then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, best.Position)
        end
    end)
end)

-- INFINITE JUMP
Connections["InfJump"] = UserInputService.JumpRequest:Connect(function()
    if Config.InfJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    if IsAndroid and Config.Fly and IsFlying then
        AndroidUpPressed = true
        task.delay(0.3, function()
            AndroidUpPressed = false
        end)
    end
end)

-- INPUT HANDLER
Connections["Inputs"] = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- DEBUG ACTION LOGGER
    if input.KeyCode == Enum.KeyCode.E and Config.DebugEnabled then
        pcall(function()
            local camera = workspace.CurrentCamera
            local rayOrigin = camera.CFrame.Position
            local rayDirection = camera.CFrame.LookVector * 1000
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
            
            if result then
                local targetPart = result.Instance
                local targetObject = targetPart.Parent
                local targetPosition = result.Position
                
                local debugMessage = string.format(
                    "[DEVS HUB DEBUG] Action: RayCast | Target: %s | Position: %.2f, %.2f, %.2f",
                    targetObject.Name,
                    targetPosition.X,
                    targetPosition.Y,
                    targetPosition.Z
                )
                
                oldWarn(debugMessage)
                Xan.Notify({Title = "Debug", Content = "Action logged to F9", Type = "Info"})
            else
                oldWarn("[DEVS HUB DEBUG] No object hit by raycast")
            end
        end)
    end

    -- TELEPORT HOTKEY
    if input.KeyCode == Enum.KeyCode.U and Config.TargetPlr and Config.TargetPlr.Character then
        pcall(function()
            LocalPlayer.Character:SetPrimaryPartCFrame(
                Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
            )
            Xan.Notify({Title = "Teleport", Content = "To: " .. Config.TargetPlr.Name})
        end)
    end

    -- CLONE QUICK KEY (PC only)
    if not IsAndroid and input.KeyCode == Enum.KeyCode.C and not CloneConfig.Enabled then
        -- C key handled by keybind toggle
    end
end)

--------------------------------------------------------------------------------
-- ANDROID BUTTON CONNECTIONS
--------------------------------------------------------------------------------

if IsAndroid and AndroidButtonFrame then
    for _, btn_data in pairs(TouchButtons) do
        local btn = btn_data.Button
        local name = btn_data.Name
        
        if name == "FlyBtn" then
            btn.Text = "FLY"
            btn.MouseButton1Click:Connect(function()
                FlightTog:Set(not Config.Fly)
            end)
        elseif name == "SpeedBtn" then
            btn.Text = "SPD"
            btn.MouseButton1Click:Connect(function()
                SpeedTog:Set(not Config.SpeedHack)
            end)
        elseif name == "AimBtn" then
            btn.Text = "AIM"
            btn.MouseButton1Click:Connect(function()
                AimToggle:Set(not Config.Aimlock)
            end)
        elseif name == "EspBtn" then
            btn.Text = "ESP"
            btn.MouseButton1Click:Connect(function()
                EspToggle:Set(not Config.ESP)
            end)
        elseif name == "TeleBtn" then
            btn.Text = "TELE"
            btn.MouseButton1Click:Connect(function()
                if Config.TargetPlr and Config.TargetPlr.Character then
                    LocalPlayer.Character:SetPrimaryPartCFrame(
                        Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
                    )
                    Xan.Notify({Title = "Teleport", Content = "To: " .. Config.TargetPlr.Name})
                else
                    Xan.Notify({Title = "Teleport", Content = "No target selected!", Type = "Error"})
                end
            end)
        elseif name == "CloneBtn" then
            btn.Text = "CLN"
            btn.MouseButton1Click:Connect(function()
                CloneToggleRef:Set(not CloneConfig.Enabled)
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- RESPAWN HANDLER
--------------------------------------------------------------------------------

Connections["CharAdded"] = LocalPlayer.CharacterAdded:Connect(function(newChar)
    if IsFlying then
        StopFly()
        task.wait(0.5)
        if Config.Fly then
            StartFly()
        end
    end

    -- Fechar clone UI ao morrer (opcional, manter toggle state)
    if CloneConfig.Enabled and CloneMainFrame then
        task.wait(1)
        pcall(function()
            CloneMainFrame.Visible = true
        end)
    end
end)

Xan.Notify({Title = "DEVS HUB", Content = "Loaded successfully!", Type = "Success"})
