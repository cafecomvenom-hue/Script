local Xan = loadstring(game:HttpGet("https://raw.githubusercontent.com/syncgomees-commits/Devs_Hub/refs/heads/main/init.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local PhysicsService = game:GetService("PhysicsService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserGui = LocalPlayer:WaitForChild("PlayerGui")

--// SUPPRESS ASSET LOAD WARNINGS
local oldWarn = warn
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

--// FLY GOD MODE VARIABLES
local FlyGodModeActive = false
local HealthConnection = nil
local ForceFieldInstance = nil
local WorldNoclipConnection = nil
local ChildAddedConnections = {}
local TouchedConnections = {}
local OriginalCollisionGroups = {}
local FlyNoclipGroupCreated = false
local GodModeRenderConnection = nil
local GodModeSteppedConnection = nil
local GodModeHeartbeatConnection = nil

--// THREAT AI VARIABLES
local ThreatAIActive = false
local ThreatAIConnection = nil
local ThreatDatabase = {}
local ThreatAlertGui = nil
local ThreatAlertLabel = nil
local NeutralizedParts = {}
local ThreatScanRadius = 500
local ThreatPredictionTime = 3

--// UNDERGROUND XRAY VARIABLES
local UndergroundXrayActive = false
local XrayConnection = nil
local TransparentParts = {}
local OriginalTransparency = {}
local XrayIndicatorGui = nil
local XrayIndicatorLabel = nil
local IsUnderground = false
local XRAY_CHECK_INTERVAL = 3
local XRAY_RADIUS = 250
local XRAY_TRANSPARENCY = 0.85
local XrayFrameCounter = 0

--// COLLISION GROUP SETUP
local FLY_NOCLIP_GROUP = "DevsHubFlyNoclip"

local function SetupCollisionGroup()
    if FlyNoclipGroupCreated then return true end
    local success = pcall(function()
        PhysicsService:RegisterCollisionGroup(FLY_NOCLIP_GROUP)
    end)
    if success then
        pcall(function()
            for _, groupName in pairs(PhysicsService:GetRegisteredCollisionGroups()) do
                pcall(function()
                    PhysicsService:CollisionGroupSetCollidable(FLY_NOCLIP_GROUP, groupName.name or groupName, false)
                end)
            end
            pcall(function()
                PhysicsService:CollisionGroupSetCollidable(FLY_NOCLIP_GROUP, FLY_NOCLIP_GROUP, false)
            end)
            pcall(function()
                PhysicsService:CollisionGroupSetCollidable(FLY_NOCLIP_GROUP, "Default", false)
            end)
        end)
        FlyNoclipGroupCreated = true
    end
    return success
end

local function AssignCharToNoclipGroup(char)
    if not char then return end
    if not FlyNoclipGroupCreated then
        SetupCollisionGroup()
    end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                if not OriginalCollisionGroups[part] then
                    OriginalCollisionGroups[part] = part.CollisionGroup
                end
                part.CollisionGroup = FLY_NOCLIP_GROUP
            end)
        end
    end
end

local function RestoreCharCollisionGroup(char)
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                if OriginalCollisionGroups[part] then
                    part.CollisionGroup = OriginalCollisionGroups[part]
                    OriginalCollisionGroups[part] = nil
                else
                    part.CollisionGroup = "Default"
                end
            end)
        end
    end
    OriginalCollisionGroups = {}
end

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
-- FLY CONTROL UI
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

    Instance.new("UICorner", UpBtn).CornerRadius = UDim.new(0, 10)

    local upStroke = Instance.new("UIStroke")
    upStroke.Color = Color3.fromRGB(70, 200, 120)
    upStroke.Thickness = 1
    upStroke.Transparency = 0.5
    upStroke.Parent = UpBtn

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

    Instance.new("UICorner", DownBtn).CornerRadius = UDim.new(0, 10)

    local downStroke = Instance.new("UIStroke")
    downStroke.Color = Color3.fromRGB(230, 100, 70)
    downStroke.Thickness = 1
    downStroke.Transparency = 0.5
    downStroke.Parent = DownBtn

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

    UpBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidUpPressed = true
            upStroke.Color = Color3.fromRGB(120, 255, 170)
            upStroke.Transparency = 0
            upArrow.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)

    UpBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidUpPressed = false
            upStroke.Color = Color3.fromRGB(70, 200, 120)
            upStroke.Transparency = 0.5
            upArrow.TextColor3 = Color3.fromRGB(220, 255, 230)
        end
    end)

    DownBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidDownPressed = true
            downStroke.Color = Color3.fromRGB(255, 150, 100)
            downStroke.Transparency = 0
            downArrow.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)

    DownBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidDownPressed = false
            downStroke.Color = Color3.fromRGB(230, 100, 70)
            downStroke.Transparency = 0.5
            downArrow.TextColor3 = Color3.fromRGB(255, 220, 210)
        end
    end)

    return speedLabel
end

FlySpeedLabel = CreateFlyControlButtons()

--------------------------------------------------------------------------------
-- UNDERGROUND XRAY SYSTEM
--------------------------------------------------------------------------------

local function CreateXrayIndicator()
    if XrayIndicatorGui then
        pcall(function() XrayIndicatorGui:Destroy() end)
    end

    XrayIndicatorGui = Instance.new("ScreenGui")
    XrayIndicatorGui.Name = "XrayIndicatorGui"
    XrayIndicatorGui.ResetOnSpawn = false
    XrayIndicatorGui.DisplayOrder = 190
    XrayIndicatorGui.Parent = UserGui

    local indicatorFrame = Instance.new("Frame")
    indicatorFrame.Name = "XrayFrame"
    indicatorFrame.Size = UDim2.new(0, 180, 0, 32)
    indicatorFrame.Position = UDim2.new(0.5, -90, 0, 55)
    indicatorFrame.BackgroundColor3 = Color3.fromRGB(0, 80, 180)
    indicatorFrame.BackgroundTransparency = 0.2
    indicatorFrame.BorderSizePixel = 0
    indicatorFrame.Visible = false
    indicatorFrame.ZIndex = 190
    indicatorFrame.Parent = XrayIndicatorGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = indicatorFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 160, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = indicatorFrame

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 28, 1, 0)
    iconLabel.Position = UDim2.new(0, 4, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "👁"
    iconLabel.TextSize = 16
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.ZIndex = 191
    iconLabel.Parent = indicatorFrame

    XrayIndicatorLabel = Instance.new("TextLabel")
    XrayIndicatorLabel.Name = "XrayText"
    XrayIndicatorLabel.Size = UDim2.new(1, -34, 1, 0)
    XrayIndicatorLabel.Position = UDim2.new(0, 32, 0, 0)
    XrayIndicatorLabel.BackgroundTransparency = 1
    XrayIndicatorLabel.Text = "XRAY: Underground"
    XrayIndicatorLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
    XrayIndicatorLabel.TextSize = 11
    XrayIndicatorLabel.Font = Enum.Font.GothamBold
    XrayIndicatorLabel.TextXAlignment = Enum.TextXAlignment.Left
    XrayIndicatorLabel.ZIndex = 191
    XrayIndicatorLabel.Parent = indicatorFrame

    return indicatorFrame
end

local XrayIndicatorFrame = CreateXrayIndicator()

-- Detectar se o jogador está abaixo do chão
local function CheckIfUnderground()
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local playerPos = root.Position

    -- Raycast para CIMA a partir do jogador
    local upParams = RaycastParams.new()
    upParams.FilterDescendantsInstances = {char}
    upParams.FilterType = Enum.RaycastFilterType.Exclude

    local upRay = workspace:Raycast(playerPos, Vector3.new(0, 500, 0), upParams)

    -- Raycast para BAIXO a partir do jogador
    local downRay = workspace:Raycast(playerPos, Vector3.new(0, -500, 0), upParams)

    if upRay and upRay.Instance then
        -- Tem algo ACIMA do jogador
        local hitPart = upRay.Instance
        local hitPos = upRay.Position

        -- Verificar se é terreno ou parte sólida grande (chão/teto)
        local isFloor = false

        if hitPart:IsA("Terrain") then
            isFloor = true
        elseif hitPart:IsA("BasePart") then
            -- Partes grandes e planas são provavelmente chão
            local size = hitPart.Size
            if (size.X > 10 and size.Z > 10) or size.Magnitude > 30 then
                isFloor = true
            end
            -- Verificar nome
            local lowerName = string.lower(hitPart.Name)
            if string.find(lowerName, "floor") or string.find(lowerName, "ground") or
               string.find(lowerName, "terrain") or string.find(lowerName, "base") or
               string.find(lowerName, "platform") or string.find(lowerName, "surface") or
               string.find(lowerName, "land") or string.find(lowerName, "chao") or
               string.find(lowerName, "piso") or string.find(lowerName, "map") or
               string.find(lowerName, "part") or string.find(lowerName, "baseplate") then
                isFloor = true
            end
            -- Verificar pai
            if hitPart.Parent then
                local parentName = string.lower(hitPart.Parent.Name)
                if string.find(parentName, "map") or string.find(parentName, "terrain") or
                   string.find(parentName, "world") or string.find(parentName, "ground") or
                   string.find(parentName, "environment") then
                    isFloor = true
                end
            end
        end

        if isFloor then
            -- Confirmar: a distância até o chão acima é razoável
            local distUp = (hitPos - playerPos).Magnitude
            if distUp > 2 then
                return true, hitPos.Y
            end
        end
    end

    -- Método alternativo: verificar se a câmera está abaixo do terreno
    local camPos = Camera.CFrame.Position
    local camUpRay = workspace:Raycast(camPos, Vector3.new(0, 500, 0), upParams)
    if camUpRay then
        local camDownRay = workspace:Raycast(camPos, Vector3.new(0, -10, 0), upParams)
        if camUpRay and not camDownRay then
            -- Câmera tem algo acima mas nada embaixo próximo = provavelmente underground
            return true, camUpRay.Position.Y
        end
    end

    return false, 0
end

-- Identificar quais partes são "chão" que bloqueiam a visão
local function IsBlockingPart(part, playerY, surfaceY)
    if not part or not part:IsA("BasePart") then return false end
    
    -- Ignorar partes do personagem
    local char = LocalPlayer.Character
    if char and part:IsDescendantOf(char) then return false end

    -- Ignorar partes de outros jogadores
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and part:IsDescendantOf(player.Character) then
            return false
        end
    end

    local partBottom = part.Position.Y - (part.Size.Y / 2)
    local partTop = part.Position.Y + (part.Size.Y / 2)

    -- A parte está ACIMA do jogador e bloqueia visão
    if partBottom > playerY and partBottom < surfaceY + 50 then
        -- Verificar se é grande o suficiente para bloquear visão
        if part.Size.X > 3 and part.Size.Z > 3 then
            return true
        end
        if part.Size.Magnitude > 15 then
            return true
        end
        -- Verificar por nome
        local lowerName = string.lower(part.Name)
        if string.find(lowerName, "floor") or string.find(lowerName, "ground") or
           string.find(lowerName, "terrain") or string.find(lowerName, "base") or
           string.find(lowerName, "platform") or string.find(lowerName, "ceiling") or
           string.find(lowerName, "roof") or string.find(lowerName, "wall") or
           string.find(lowerName, "part") or string.find(lowerName, "baseplate") then
            return true
        end
    end

    -- Partes que envolvem o jogador (paredes ao redor underground)
    if part.Size.Y > 5 then
        local char2 = LocalPlayer.Character
        if char2 then
            local root = char2:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (Vector3.new(part.Position.X, 0, part.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
                local partHalfWidth = math.max(part.Size.X, part.Size.Z) / 2
                if dist < partHalfWidth + 20 and partTop > playerY then
                    return true
                end
            end
        end
    end

    return false
end

-- Tornar partes transparentes
local function MakePartTransparent(part)
    if not part or TransparentParts[part] then return end
    
    pcall(function()
        -- Salvar transparência original
        if not OriginalTransparency[part] then
            OriginalTransparency[part] = part.Transparency
        end
        
        -- Só tornar transparente se não for já transparente
        if part.Transparency < XRAY_TRANSPARENCY then
            part.Transparency = XRAY_TRANSPARENCY
            TransparentParts[part] = true
        end
    end)
end

-- Restaurar transparência original
local function RestorePartTransparency(part)
    if not part or not TransparentParts[part] then return end
    
    pcall(function()
        if OriginalTransparency[part] ~= nil then
            part.Transparency = OriginalTransparency[part]
            OriginalTransparency[part] = nil
        end
        TransparentParts[part] = nil
    end)
end

-- Restaurar TODAS as partes transparentes
local function RestoreAllTransparency()
    for part, _ in pairs(TransparentParts) do
        pcall(function()
            if part and part.Parent then
                if OriginalTransparency[part] ~= nil then
                    part.Transparency = OriginalTransparency[part]
                end
            end
        end)
    end
    TransparentParts = {}
    OriginalTransparency = {}
end

-- Scan e aplicar Xray
local function XrayScan()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local underground, surfaceY = CheckIfUnderground()

    if underground and not IsUnderground then
        -- Acabou de entrar no underground
        IsUnderground = true
        if XrayIndicatorFrame then
            XrayIndicatorFrame.Visible = true
        end
        if XrayIndicatorLabel then
            XrayIndicatorLabel.Text = "XRAY: Underground Mode"
        end
    elseif not underground and IsUnderground then
        -- Acabou de sair do underground
        IsUnderground = false
        RestoreAllTransparency()
        if XrayIndicatorFrame then
            XrayIndicatorFrame.Visible = false
        end
    end

    if not IsUnderground then return end

    local playerPos = root.Position
    local playerY = playerPos.Y
    local partsToTransparent = {}
    local partsToRestore = {}

    -- Escanear partes no raio
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if not obj:IsA("BasePart") then continue end
            
            local dist = (obj.Position - playerPos).Magnitude
            if dist > XRAY_RADIUS then
                -- Fora do raio: restaurar se estava transparente
                if TransparentParts[obj] then
                    table.insert(partsToRestore, obj)
                end
                continue
            end

            if IsBlockingPart(obj, playerY, surfaceY) then
                table.insert(partsToTransparent, obj)
            else
                if TransparentParts[obj] then
                    table.insert(partsToRestore, obj)
                end
            end
        end
    end)

    -- Aplicar transparência
    for _, part in pairs(partsToTransparent) do
        MakePartTransparent(part)
    end

    -- Restaurar partes que não bloqueiam mais
    for _, part in pairs(partsToRestore) do
        RestorePartTransparency(part)
    end

    -- Atualizar indicador
    if XrayIndicatorLabel then
        local count = 0
        for _ in pairs(TransparentParts) do count = count + 1 end
        pcall(function()
            XrayIndicatorLabel.Text = "XRAY: " .. count .. " parts | Depth: " .. math.floor(surfaceY - playerY) .. "m"
        end)
    end
end

-- Terrain Xray: tornar terreno transparente usando raycasts
local function XrayTerrain()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if not IsUnderground then return end

    -- Tornar terreno acima semi-transparente
    pcall(function()
        local terrain = workspace.Terrain
        if terrain then
            -- Usar FillBlock para criar uma região de ar acima do jogador
            -- (alternativa: setar WaterTransparency)
            terrain.WaterTransparency = 1
        end
    end)
end

-- Iniciar Underground Xray
local function StartUndergroundXray()
    if UndergroundXrayActive then return end
    UndergroundXrayActive = true
    XrayFrameCounter = 0

    if XrayConnection then
        pcall(function() XrayConnection:Disconnect() end)
    end

    XrayConnection = RunService.Heartbeat:Connect(function()
        if not UndergroundXrayActive then return end
        XrayFrameCounter = XrayFrameCounter + 1

        -- Scan completo a cada N frames para performance
        if XrayFrameCounter % XRAY_CHECK_INTERVAL == 0 then
            XrayScan()
            XrayTerrain()
        end
    end)
end

-- Parar Underground Xray
local function StopUndergroundXray()
    UndergroundXrayActive = false
    IsUnderground = false

    if XrayConnection then
        pcall(function() XrayConnection:Disconnect() end)
        XrayConnection = nil
    end

    -- Restaurar todas as partes
    RestoreAllTransparency()

    -- Restaurar terreno
    pcall(function()
        local terrain = workspace.Terrain
        if terrain then
            terrain.WaterTransparency = 0
        end
    end)

    -- Esconder indicador
    if XrayIndicatorFrame then
        XrayIndicatorFrame.Visible = false
    end
end

--------------------------------------------------------------------------------
-- THREAT AI SYSTEM
--------------------------------------------------------------------------------

local ThreatPatterns = {
    Critical = {
        "tsunami", "megawave", "mega_wave", "giantwave", "giant_wave",
        "tidal", "tidalwave", "tidal_wave", "superwave", "super_wave",
        "deathwave", "death_wave", "killwave", "kill_wave", "nuke",
        "nuclear", "apocalypse", "extinction", "worldender"
    },
    High = {
        "wave", "flood", "lava", "fire", "explosion", "bomb",
        "missile", "laser", "beam", "blast", "meteor", "asteroid",
        "tornado", "hurricane", "storm", "lightning", "thunder",
        "earthquake", "quake", "volcano", "eruption", "avalanche",
        "surge", "tide", "current", "whirlpool", "vortex",
        "onda", "mar", "oceano", "tempestade", "destrui", "inunda"
    },
    Medium = {
        "projectile", "bullet", "arrow", "spike", "trap",
        "hazard", "danger", "poison", "acid", "toxic",
        "boulder", "rock", "debris", "falling", "crush",
        "smash", "hit", "attack", "damage", "hurt",
        "kill", "death", "harm", "pain", "burn"
    },
    Low = {
        "water", "rain", "splash", "drip", "flow",
        "wind", "gust", "breeze", "dust", "sand",
        "smoke", "fog", "mist", "cloud", "particle"
    }
}

local ThreatBehaviors = {
    HighVelocity = 30,
    LargeSize = 40,
    MassiveSize = 150,
    DangerRadius = 300,
    NeutralizeRadius = 500,
}

local ThreatAlertFrame = nil

local function CreateThreatAlertUI()
    if ThreatAlertGui then
        pcall(function() ThreatAlertGui:Destroy() end)
    end

    ThreatAlertGui = Instance.new("ScreenGui")
    ThreatAlertGui.Name = "ThreatAlertGui"
    ThreatAlertGui.ResetOnSpawn = false
    ThreatAlertGui.DisplayOrder = 200
    ThreatAlertGui.Parent = UserGui

    local alertFrame = Instance.new("Frame")
    alertFrame.Name = "AlertFrame"
    alertFrame.Size = UDim2.new(0, 280, 0, 40)
    alertFrame.Position = UDim2.new(0.5, -140, 0, 10)
    alertFrame.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    alertFrame.BackgroundTransparency = 0.15
    alertFrame.BorderSizePixel = 0
    alertFrame.Visible = false
    alertFrame.ZIndex = 200
    alertFrame.Parent = ThreatAlertGui

    Instance.new("UICorner", alertFrame).CornerRadius = UDim.new(0, 10)

    local alertStroke = Instance.new("UIStroke")
    alertStroke.Color = Color3.fromRGB(255, 60, 60)
    alertStroke.Thickness = 2
    alertStroke.Parent = alertFrame

    local alertIcon = Instance.new("TextLabel")
    alertIcon.Size = UDim2.new(0, 30, 1, 0)
    alertIcon.Position = UDim2.new(0, 5, 0, 0)
    alertIcon.BackgroundTransparency = 1
    alertIcon.Text = "⚠"
    alertIcon.TextColor3 = Color3.fromRGB(255, 255, 0)
    alertIcon.TextSize = 20
    alertIcon.Font = Enum.Font.GothamBold
    alertIcon.ZIndex = 201
    alertIcon.Parent = alertFrame

    ThreatAlertLabel = Instance.new("TextLabel")
    ThreatAlertLabel.Size = UDim2.new(1, -40, 1, 0)
    ThreatAlertLabel.Position = UDim2.new(0, 35, 0, 0)
    ThreatAlertLabel.BackgroundTransparency = 1
    ThreatAlertLabel.Text = "THREAT DETECTED"
    ThreatAlertLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ThreatAlertLabel.TextSize = 12
    ThreatAlertLabel.Font = Enum.Font.GothamBold
    ThreatAlertLabel.TextXAlignment = Enum.TextXAlignment.Left
    ThreatAlertLabel.TextWrapped = true
    ThreatAlertLabel.ZIndex = 201
    ThreatAlertLabel.Parent = alertFrame

    ThreatAlertFrame = alertFrame
    return alertFrame
end

CreateThreatAlertUI()

local function ClassifyThreatByName(name)
    local lowerName = string.lower(name)
    for _, p in pairs(ThreatPatterns.Critical) do
        if string.find(lowerName, p) then return "CRITICAL", 4 end
    end
    for _, p in pairs(ThreatPatterns.High) do
        if string.find(lowerName, p) then return "HIGH", 3 end
    end
    for _, p in pairs(ThreatPatterns.Medium) do
        if string.find(lowerName, p) then return "MEDIUM", 2 end
    end
    for _, p in pairs(ThreatPatterns.Low) do
        if string.find(lowerName, p) then return "LOW", 1 end
    end
    return nil, 0
end

local function NeutralizeThreat(part)
    if not part or NeutralizedParts[part] then return end
    NeutralizedParts[part] = true
    pcall(function()
        part.CanCollide = false
        part.CanTouch = false
        if FlyNoclipGroupCreated then
            part.CollisionGroup = FLY_NOCLIP_GROUP
        end
    end)
    if part.Parent and part.Parent:IsA("Model") then
        pcall(function()
            for _, sibling in pairs(part.Parent:GetDescendants()) do
                if sibling:IsA("BasePart") and not NeutralizedParts[sibling] then
                    NeutralizedParts[sibling] = true
                    sibling.CanCollide = false
                    sibling.CanTouch = false
                    if FlyNoclipGroupCreated then
                        sibling.CollisionGroup = FLY_NOCLIP_GROUP
                    end
                end
            end
        end)
    end
end

local function ShowThreatAlert(level, name, eta, direction)
    if not ThreatAlertFrame or not ThreatAlertLabel then return end
    local dirText = ""
    if direction then
        local dot_r = Camera.CFrame.RightVector:Dot(direction)
        local dot_f = Camera.CFrame.LookVector:Dot(direction)
        if math.abs(dot_f) > math.abs(dot_r) then
            dirText = dot_f > 0 and " → FRONT" or " → BEHIND"
        else
            dirText = dot_r > 0 and " → RIGHT" or " → LEFT"
        end
    end
    local etaText = eta and string.format(" | ETA: %.1fs", eta) or ""
    local colors = {
        CRITICAL = Color3.fromRGB(255, 0, 0),
        HIGH = Color3.fromRGB(255, 80, 0),
        MEDIUM = Color3.fromRGB(255, 180, 0),
        LOW = Color3.fromRGB(200, 200, 0)
    }
    ThreatAlertFrame.BackgroundColor3 = colors[level] or Color3.fromRGB(180, 30, 30)
    ThreatAlertLabel.Text = "⚠ " .. level .. ": " .. tostring(name) .. dirText .. etaText .. " [NEUTRALIZED]"
    ThreatAlertFrame.Visible = true
    task.delay(2, function()
        if ThreatAlertFrame then ThreatAlertFrame.Visible = false end
    end)
end

local function ThreatAIScan()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local playerPos = root.Position
    local highestThreat = nil
    local highestScore = 0

    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if not obj:IsA("BasePart") then continue end
            if obj:IsDescendantOf(char) then continue end
            local distance = (obj.Position - playerPos).Magnitude
            if distance > ThreatBehaviors.NeutralizeRadius then continue end

            local _, nameScore = ClassifyThreatByName(obj.Name)
            local _, parentScore = 0, 0
            if obj.Parent then _, parentScore = ClassifyThreatByName(obj.Parent.Name) end

            local totalScore = (nameScore or 0) + (parentScore or 0)
            local vel = Vector3.zero
            pcall(function() vel = obj.AssemblyLinearVelocity or Vector3.zero end)

            if vel.Magnitude > ThreatBehaviors.HighVelocity then totalScore = totalScore + 2 end
            if obj.Size.Magnitude > ThreatBehaviors.MassiveSize then totalScore = totalScore + 3
            elseif obj.Size.Magnitude > ThreatBehaviors.LargeSize then totalScore = totalScore + 1 end

            if vel.Magnitude > 5 then
                local dirToPlayer = (playerPos - obj.Position)
                if dirToPlayer.Magnitude > 0.01 then
                    local dot = dirToPlayer.Unit:Dot(vel.Unit)
                    if dot > 0.3 then
                        totalScore = totalScore + 2
                        local eta = distance / vel.Magnitude
                        if eta < 3 then totalScore = totalScore + 3 end
                    end
                end
            end

            if obj.Size.Magnitude > 30 and vel.Magnitude > 3 and distance < 200 then
                totalScore = math.max(totalScore, 4)
            end

            if totalScore >= 2 then
                NeutralizeThreat(obj)
                if totalScore > highestScore then
                    highestScore = totalScore
                    highestThreat = {
                        Part = obj,
                        Level = totalScore >= 8 and "CRITICAL" or totalScore >= 5 and "HIGH" or totalScore >= 3 and "MEDIUM" or "LOW",
                        Name = obj.Parent and obj.Parent:IsA("Model") and obj.Parent.Name or obj.Name,
                        Distance = distance,
                        Velocity = vel
                    }
                end
            end
        end
    end)

    if highestThreat and highestScore >= 4 then
        local dir = highestThreat.Velocity.Magnitude > 1 and highestThreat.Velocity.Unit or
            ((playerPos - highestThreat.Part.Position).Magnitude > 0.01 and (playerPos - highestThreat.Part.Position).Unit or nil)
        local eta = highestThreat.Velocity.Magnitude > 1 and highestThreat.Distance / highestThreat.Velocity.Magnitude or nil
        ShowThreatAlert(highestThreat.Level, highestThreat.Name, eta, dir)
    end

    local ct = tick()
    for part, data in pairs(ThreatDatabase) do
        if not part or not part.Parent then
            ThreatDatabase[part] = nil
            NeutralizedParts[part] = nil
        elseif ct - (data.Tick or 0) > 30 then
            ThreatDatabase[part] = nil
        end
    end
end

local function StartThreatAI()
    if ThreatAIActive then return end
    ThreatAIActive = true
    if ThreatAIConnection then pcall(function() ThreatAIConnection:Disconnect() end) end

    local fc = 0
    ThreatAIConnection = RunService.Heartbeat:Connect(function()
        if not ThreatAIActive then return end
        fc = fc + 1
        if fc % 5 == 0 then ThreatAIScan() end
    end)

    if WorldNoclipConnection then pcall(function() WorldNoclipConnection:Disconnect() end) end
    WorldNoclipConnection = workspace.DescendantAdded:Connect(function(obj)
        if not ThreatAIActive then return end
        task.defer(function()
            if not obj or not obj:IsA("BasePart") then return end
            local char = LocalPlayer.Character
            if not char then return end
            if obj:IsDescendantOf(char) then return end

            local _, ns = ClassifyThreatByName(obj.Name)
            local _, ps = 0, 0
            if obj.Parent then _, ps = ClassifyThreatByName(obj.Parent.Name) end
            if (ns or 0) + (ps or 0) >= 1 then NeutralizeThreat(obj) return end

            task.delay(0.5, function()
                if not obj or not obj.Parent then return end
                pcall(function()
                    local vel = obj.AssemblyLinearVelocity or Vector3.zero
                    if vel.Magnitude > ThreatBehaviors.HighVelocity or obj.Size.Magnitude > ThreatBehaviors.LargeSize then
                        NeutralizeThreat(obj)
                    end
                end)
            end)

            pcall(function()
                local conn = obj.Touched:Connect(function(hit)
                    if not ThreatAIActive then return end
                    if hit and char and hit:IsDescendantOf(char) then
                        NeutralizeThreat(obj)
                        local hum = char:FindFirstChild("Humanoid")
                        if hum then hum.Health = hum.MaxHealth end
                    end
                end)
                table.insert(TouchedConnections, conn)
            end)
        end)
    end)
end

local function StopThreatAI()
    ThreatAIActive = false
    if ThreatAIConnection then pcall(function() ThreatAIConnection:Disconnect() end) ThreatAIConnection = nil end
    if WorldNoclipConnection then pcall(function() WorldNoclipConnection:Disconnect() end) WorldNoclipConnection = nil end
    for _, c in pairs(TouchedConnections) do pcall(function() c:Disconnect() end) end
    TouchedConnections = {}
    ThreatDatabase = {}
    NeutralizedParts = {}
    if ThreatAlertFrame then ThreatAlertFrame.Visible = false end
end

--------------------------------------------------------------------------------
-- GOD MODE + NOCLIP
--------------------------------------------------------------------------------

local function ForceNoclipCharacter()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

local function ForceGodMode()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum and hum.Health ~= hum.MaxHealth then hum.Health = hum.MaxHealth end
end

local function EnableFlyGodMode()
    if FlyGodModeActive then return end
    FlyGodModeActive = true
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end

    hum.Health = hum.MaxHealth
    if HealthConnection then pcall(function() HealthConnection:Disconnect() end) end
    HealthConnection = hum.HealthChanged:Connect(function()
        if FlyGodModeActive and hum then hum.Health = hum.MaxHealth end
    end)

    pcall(function()
        if not char:FindFirstChild("FlyForceField") then
            ForceFieldInstance = Instance.new("ForceField")
            ForceFieldInstance.Name = "FlyForceField"
            ForceFieldInstance.Visible = false
            ForceFieldInstance.Parent = char
        end
    end)

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end)

    pcall(function() AssignCharToNoclipGroup(char) end)

    if GodModeSteppedConnection then pcall(function() GodModeSteppedConnection:Disconnect() end) end
    GodModeSteppedConnection = RunService.Stepped:Connect(function()
        if not FlyGodModeActive then return end
        ForceNoclipCharacter()
        ForceGodMode()
    end)

    if GodModeRenderConnection then pcall(function() GodModeRenderConnection:Disconnect() end) end
    GodModeRenderConnection = RunService.RenderStepped:Connect(function()
        if not FlyGodModeActive then return end
        ForceNoclipCharacter()
    end)

    if GodModeHeartbeatConnection then pcall(function() GodModeHeartbeatConnection:Disconnect() end) end
    GodModeHeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not FlyGodModeActive then return end
        ForceNoclipCharacter()
        ForceGodMode()
        local root = char:FindFirstChild("HumanoidRootPart")
        if root and BodyVel then
            root.AssemblyLinearVelocity = BodyVel.Velocity
            root.AssemblyAngularVelocity = Vector3.zero
        end
        local h = char:FindFirstChild("Humanoid")
        if h then
            local state = h:GetState()
            if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.FallingDown or
               state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics then
                h:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end)

    local charConn = char.DescendantAdded:Connect(function(obj)
        if not FlyGodModeActive then return end
        if obj:IsA("BasePart") then
            task.defer(function()
                pcall(function()
                    obj.CanCollide = false
                    if FlyNoclipGroupCreated then obj.CollisionGroup = FLY_NOCLIP_GROUP end
                end)
            end)
        end
    end)
    table.insert(ChildAddedConnections, charConn)

    StartThreatAI()
    StartUndergroundXray()
end

local function DisableFlyGodMode()
    if not FlyGodModeActive then return end
    FlyGodModeActive = false

    StopThreatAI()
    StopUndergroundXray()

    if HealthConnection then pcall(function() HealthConnection:Disconnect() end) HealthConnection = nil end
    if GodModeSteppedConnection then pcall(function() GodModeSteppedConnection:Disconnect() end) GodModeSteppedConnection = nil end
    if GodModeRenderConnection then pcall(function() GodModeRenderConnection:Disconnect() end) GodModeRenderConnection = nil end
    if GodModeHeartbeatConnection then pcall(function() GodModeHeartbeatConnection:Disconnect() end) GodModeHeartbeatConnection = nil end
    for _, c in pairs(ChildAddedConnections) do pcall(function() c:Disconnect() end) end
    ChildAddedConnections = {}

    if ForceFieldInstance then pcall(function() ForceFieldInstance:Destroy() end) ForceFieldInstance = nil end

    local char = LocalPlayer.Character
    if char then
        local ff = char:FindFirstChild("FlyForceField")
        if ff then pcall(function() ff:Destroy() end) end
        RestoreCharCollisionGroup(char)
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then pcall(function() part.CanCollide = true end) end
        end
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- FLY SYSTEM
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
    EnableFlyGodMode()
    if IsAndroid and FlyControlFrame then FlyControlFrame.Visible = true end
end

local function StopFly()
    IsFlying = false
    DisableFlyGodMode()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    if BodyVel then pcall(function() BodyVel:Destroy() end) BodyVel = nil end
    if BodyGyro then pcall(function() BodyGyro:Destroy() end) BodyGyro = nil end
    AndroidUpPressed = false
    AndroidDownPressed = false
    if IsAndroid and FlyControlFrame then FlyControlFrame.Visible = false end
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
            moveDir = moveDir + cam.LookVector * flatLook:Dot(md)
            moveDir = moveDir + cam.RightVector * flatRight:Dot(md)
        end
        if AndroidUpPressed then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if AndroidDownPressed then moveDir = moveDir + Vector3.new(0, -1, 0) end
    else
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir + Vector3.new(0, -1, 0)
        end
    end

    if moveDir.Magnitude > 0.01 then moveDir = moveDir.Unit else moveDir = Vector3.zero end
    return moveDir * Config.FlySpeed
end

--------------------------------------------------------------------------------
-- INITIALIZE WINDOW
--------------------------------------------------------------------------------

local function InitializeWindow()
    pcall(function()
        Xan.Splash({
            Title = "DEVS HUB",
            Subtitle = IsAndroid and "Inicializando..." or "System Initialization...",
            Duration = IsAndroid and 1 or 2,
            Theme = "Midnight"
        })
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

    task.wait(IsAndroid and 1.5 or 2.2)

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
            Visible = true, ShowFPS = true, ShowPing = true, Theme = "Midnight"
        })
    end)

    if Watermark then
        task.spawn(function()
            while Window do
                pcall(function() Watermark:SetText("DEVS HUB | " .. os.date("%X")) end)
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

--------------------------------------------------------------------------------
-- GUI TABS
--------------------------------------------------------------------------------

local MainTab = Window:AddTab("Main", Xan.Icons.Home)
local ConfigTab = Window:AddTab("Config", Xan.Icons.Settings)
local PlayerTab = Window:AddTab("Player", Xan.Icons.Person)
local DevsTab = Window:AddTab("Devs", Xan.Icons.Code)

-- COMBAT
MainTab:AddSection("Combat")

local AimToggle = MainTab:AddToggle("Aimlock", "aim_state", function(v) Config.Aimlock = v end)
MainTab:AddKeybind("Aimlock Key [G]", "aim_key", Enum.KeyCode.G, function()
    AimToggle:Set(not AimToggle.Value())
end)
MainTab:AddSlider("Aim FOV", "aim_fov", {Min = 100, Max = 2000, Default = 1000}, function(v) Config.AimRange = v end)

MainTab:AddCharacterPreview({
    Name = "Hitbox Targeting",
    HitboxParts = {"Head", "Chest", "Arms", "Legs"},
    Default = {Head = true, Chest = true},
    Callback = function(val) Config.HitParts = val end
})

-- VISUALS
MainTab:AddSection("Visuals")

local EspToggle = MainTab:AddToggle("X-Ray (Chams)", "esp_state", function(v)
    Config.ESP = v
    if not v then
        for _, o in pairs(Objects) do
            if o.Name == "HLCache" then pcall(function() o:Destroy() end) end
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

-- MOVEMENT
MainTab:AddSection("Movement")

local FlightTog = MainTab:AddToggle("Fly Hack", "fly_hack", function(v)
    Config.Fly = v
    if v then
        Xan.Notify({
            Title = "Flight + AI + XRay",
            Content = IsAndroid and "GOD + AI + XRAY ON! Joystick + ▲/▼" or "GOD + AI + XRAY ON! WASD + E/Q",
            Type = "Success"
        })
    else
        Xan.Notify({Title = "Flight", Content = "All systems OFF", Type = "Info"})
    end
end)
MainTab:AddKeybind("Fly Key [F]", "fly_key", Enum.KeyCode.F, function()
    FlightTog:Set(not FlightTog.Value())
end)
MainTab:AddSlider("Fly Speed", "fly_val", {Min = 10, Max = 700, Default = 50}, function(v) Config.FlySpeed = v end)

local SpeedTog = MainTab:AddToggle("Speed Hack", "speed_hack", function(v)
    Config.SpeedHack = v
    if not v and LocalPlayer.Character then
        pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed = 16 end)
    end
end)
MainTab:AddKeybind("Speed Key [J]", "speed_key", Enum.KeyCode.J, function()
    SpeedTog:Set(not SpeedTog.Value())
end)
MainTab:AddSlider("Walk Speed", "speed_val", {Min = 16, Max = 300, Default = 16}, function(v) Config.WalkSpeed = v end)

local JumpTog = MainTab:AddToggle("Jump Hack", "jump_hack", function(v)
    Config.JumpHack = v
    if not v and LocalPlayer.Character then
        pcall(function() LocalPlayer.Character.Humanoid.JumpPower = 50 end)
    end
end)
MainTab:AddKeybind("Jump Key [K]", "jump_key", Enum.KeyCode.K, function()
    JumpTog:Set(not JumpTog.Value())
end)
MainTab:AddSlider("Jump Power", "jump_val", {Min = 50, Max = 500, Default = 50}, function(v) Config.JumpPower = v end)

local NoclipTog = MainTab:AddToggle("No Clip", "noclip_hack", function(v) Config.Noclip = v end)
MainTab:AddKeybind("No Clip Key [N]", "noclip_key", Enum.KeyCode.N, function()
    NoclipTog:Set(not NoclipTog.Value())
end)

local InfJumpTog = MainTab:AddToggle("Inf Jump", "inf_jump", function(v) Config.InfJump = v end)
MainTab:AddKeybind("Inf Jump Key [L]", "inf_jump_key", Enum.KeyCode.L, function()
    InfJumpTog:Set(not InfJumpTog.Value())
end)

-- TELEPORT
MainTab:AddSection("Teleport")

local function GetPlayerNames()
    local names = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    table.sort(names)
    if #names == 0 then table.insert(names, "No Other Players") end
    return names
end

local TpDropdown = MainTab:AddDropdown("Select Player", "tp_target", GetPlayerNames(), function(v)
    Config.TargetPlr = Players:FindFirstChild(v)
end)

Connections["PlrAdded"] = Players.PlayerAdded:Connect(function() TpDropdown:SetOptions(GetPlayerNames()) end)
Connections["PlrRemoved"] = Players.PlayerRemoving:Connect(function() TpDropdown:SetOptions(GetPlayerNames()) end)

MainTab:AddButton("Refresh Dropdown", function() TpDropdown:SetOptions(GetPlayerNames()) end)

MainTab:AddButton("Teleport [U]", function()
    if Config.TargetPlr and Config.TargetPlr.Character then
        LocalPlayer.Character:SetPrimaryPartCFrame(Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4))
        Xan.Notify({Title = "Teleport", Content = "Teleported to " .. Config.TargetPlr.Name})
    else
        Xan.Notify({Title = "Error", Content = "Invalid target.", Type = "Error"})
    end
end)

MainTab:AddSpeedometer("HUD Speed", {Min = 0, Max = 200, AutoTrack = true})

-- PLAYER TAB
PlayerTab:AddSection("Character")
PlayerTab:AddButton("Reset Speed", function()
    if LocalPlayer.Character then pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed = 16 end) end
    Xan.Notify({Title = "Character", Content = "Speed reset"})
end)
PlayerTab:AddButton("Reset Jump", function()
    if LocalPlayer.Character then pcall(function() LocalPlayer.Character.Humanoid.JumpPower = 50 end) end
    Xan.Notify({Title = "Character", Content = "Jump reset"})
end)
PlayerTab:AddButton("Reset All", function()
    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then h.WalkSpeed = 16; h.JumpPower = 50; h.PlatformStand = false end
    end
    Xan.Notify({Title = "Character", Content = "All reset"})
end)

PlayerTab:AddSection("Equipment")
PlayerTab:AddButton("Remove All Tools", function()
    if LocalPlayer.Backpack then for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do if t:IsA("Tool") then t:Destroy() end end end
    if LocalPlayer.Character then for _, t in pairs(LocalPlayer.Character:GetChildren()) do if t:IsA("Tool") then t:Destroy() end end end
    Xan.Notify({Title = "Equipment", Content = "Tools removed"})
end)
PlayerTab:AddButton("Drop All Tools", function()
    if LocalPlayer.Backpack then for _, t in pairs(LocalPlayer.Backpack:GetChildren()) do if t:IsA("Tool") then t.Parent = workspace end end end
    Xan.Notify({Title = "Equipment", Content = "Tools dropped"})
end)

PlayerTab:AddSection("Health")
PlayerTab:AddButton("Heal", function()
    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then h.Health = h.MaxHealth end
    end
    Xan.Notify({Title = "Health", Content = "Healed"})
end)
PlayerTab:AddSlider("Health Value", "health_val", {Min = 1, Max = 100, Default = 100}, function(v)
    if LocalPlayer.Character and not FlyGodModeActive then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then h.Health = (h.MaxHealth / 100) * v end
    end
end)

PlayerTab:AddSection("Theft")
PlayerTab:AddToggle("Steal Speed Hack", "steal_hack", function(v)
    Config.StealSpeed = v
    Xan.Notify({Title = "Theft", Content = v and "Enabled " .. Config.StealMultiplier .. "x" or "Disabled"})
end)
PlayerTab:AddSlider("Steal Multiplier", "steal_mult", {Min = 1, Max = 10, Default = 2}, function(v) Config.StealMultiplier = v end)

PlayerTab:AddSection("Position Teleport")
PlayerTab:AddButton("Save Position 1", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        Config.SavedPos1 = LocalPlayer.Character.HumanoidRootPart.CFrame
        Xan.Notify({Title = "Position", Content = "Pos 1 saved!", Type = "Success"})
    end
end)
PlayerTab:AddButton("Save Position 2", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        Config.SavedPos2 = LocalPlayer.Character.HumanoidRootPart.CFrame
        Xan.Notify({Title = "Position", Content = "Pos 2 saved!", Type = "Success"})
    end
end)
PlayerTab:AddButton("Teleport to Position 1", function()
    if Config.SavedPos1 and LocalPlayer.Character then
        LocalPlayer.Character:SetPrimaryPartCFrame(Config.SavedPos1)
        Xan.Notify({Title = "Teleport", Content = "To Pos 1", Type = "Success"})
    end
end)
PlayerTab:AddButton("Teleport to Position 2", function()
    if Config.SavedPos2 and LocalPlayer.Character then
        LocalPlayer.Character:SetPrimaryPartCFrame(Config.SavedPos2)
        Xan.Notify({Title = "Teleport", Content = "To Pos 2", Type = "Success"})
    end
end)

-- DEVS TAB
DevsTab:AddSection("Credits")
DevsTab:AddLabel("DEVS HUB")
DevsTab:AddLabel("Version: 1.3 - AI + XRay")
DevsTab:AddDivider()
DevsTab:AddLabel("Created by: mecharena1")
DevsTab:AddDivider()

DevsTab:AddSection("Information")
DevsTab:AddLabel("Library: Xan Hub")
DevsTab:AddLabel("AI: Threat Detection v1.0")
DevsTab:AddLabel("XRay: Underground Vision v1.0")
DevsTab:AddDivider()

DevsTab:AddButton("Check Updates", function()
    Xan.Notify({Title = "Updates", Content = "Latest version!", Type = "Success"})
end)

DevsTab:AddSection("Debug")
DevsTab:AddToggle("Debug Logger", "debug_action", function(v)
    Config.DebugEnabled = v
    Xan.Notify({Title = "Debug", Content = v and "Press E to log" or "Disabled"})
end)
DevsTab:AddLabel("Logs actions when E is pressed")

-- CONFIG TAB
ConfigTab:AddInput("Config Name", {Flag = "cfg_name", Default = "default"})
ConfigTab:AddButton("Save Config", function() Xan:SaveConfig(Xan.Flags["cfg_name"] or "default") end)
ConfigTab:AddButton("Load Config", function() Xan:LoadConfig(Xan.Flags["cfg_name"] or "default") end)
ConfigTab:AddDivider()
ConfigTab:AddButton("Unload & Cleanup", function()
    StopFly()
    StopThreatAI()
    StopUndergroundXray()
    for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
    for _, o in pairs(Objects) do pcall(function() o:Destroy() end) end
    if FlyControlFrame then pcall(function() FlyControlFrame.Parent:Destroy() end) end
    if AndroidButtonFrame then pcall(function() AndroidButtonFrame:Destroy() end) end
    if ThreatAlertGui then pcall(function() ThreatAlertGui:Destroy() end) end
    if XrayIndicatorGui then pcall(function() XrayIndicatorGui:Destroy() end) end
    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then h.PlatformStand = false; h.WalkSpeed = 16; h.JumpPower = 50 end
    end
    pcall(function() Xan:Unload() end)
end)

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

Connections["Loop"] = RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    if Config.Noclip and not Config.Fly then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end

    if Config.SpeedHack and not Config.Fly then hum.WalkSpeed = Config.WalkSpeed end

    if Config.JumpHack then
        hum.UseJumpPower = true
        hum.JumpPower = Config.JumpPower
    end

    if Config.Fly then
        if not IsFlying then StartFly() end
        if not BodyVel or not BodyVel.Parent or not BodyGyro or not BodyGyro.Parent then
            StopFly()
            StartFly()
        end
        if BodyVel and BodyGyro then
            BodyGyro.CFrame = Camera.CFrame
            BodyVel.Velocity = GetFlyVelocity()
            if FlySpeedLabel then pcall(function() FlySpeedLabel.Text = tostring(math.floor(Config.FlySpeed)) end) end
        end
    else
        if IsFlying then StopFly() end
    end

    if Config.StealSpeed then
        pcall(function()
            for _, remote in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                if remote:IsA("RemoteEvent") then
                    local rn = remote.Name:lower()
                    if string.find(rn, "steal") or string.find(rn, "rob") or
                       string.find(rn, "grab") or string.find(rn, "take") or string.find(rn, "action") then
                        for i = 1, Config.StealMultiplier do remote:FireServer(); task.wait(0.05) end
                    end
                end
            end
        end)
    end
end)

-- AIMLOCK
Connections["Aim"] = RunService.RenderStepped:Connect(function()
    if not Config.Aimlock then return end
    pcall(function()
        local mouse = UserInputService:GetMouseLocation()
        local best, bestDist = nil, Config.AimRange
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                local part = (Config.HitParts.Head and p.Character:FindFirstChild("Head")) or
                             (Config.HitParts.Chest and p.Character:FindFirstChild("HumanoidRootPart")) or
                             p.Character:FindFirstChild("Head")
                if part then
                    local pos, vis = Camera:WorldToViewportPoint(part.Position)
                    if vis then
                        local dist = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                        if dist < bestDist then bestDist = dist; best = part end
                    end
                end
            end
        end
        if best then Camera.CFrame = CFrame.new(Camera.CFrame.Position, best.Position) end
    end)
end)

-- INFINITE JUMP
Connections["InfJump"] = UserInputService.JumpRequest:Connect(function()
    if Config.InfJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
    if IsAndroid and Config.Fly and IsFlying then
        AndroidUpPressed = true
        task.delay(0.3, function() AndroidUpPressed = false end)
    end
end)

-- INPUT
Connections["Inputs"] = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.E and Config.DebugEnabled then
        pcall(function()
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {LocalPlayer.Character}
            params.FilterType = Enum.RaycastFilterType.Exclude
            local result = workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 1000, params)
            if result then
                local pos = result.Position
                warn(string.format("[DEBUG] %s | %.1f, %.1f, %.1f", result.Instance.Parent.Name, pos.X, pos.Y, pos.Z))
                Xan.Notify({Title = "Debug", Content = "Logged to F9", Type = "Info"})
            end
        end)
    end
    if input.KeyCode == Enum.KeyCode.U and Config.TargetPlr and Config.TargetPlr.Character then
        pcall(function()
            LocalPlayer.Character:SetPrimaryPartCFrame(Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4))
            Xan.Notify({Title = "Teleport", Content = "To: " .. Config.TargetPlr.Name})
        end)
    end
end)

-- ANDROID BUTTONS
if IsAndroid and AndroidButtonFrame then
    for _, bd in pairs(TouchButtons) do
        local btn, name = bd.Button, bd.Name
        if name == "FlyBtn" then
            btn.Text = "FLY"
            btn.MouseButton1Click:Connect(function() FlightTog:Set(not Config.Fly) end)
        elseif name == "SpeedBtn" then
            btn.Text = "SPD"
            btn.MouseButton1Click:Connect(function() SpeedTog:Set(not Config.SpeedHack) end)
        elseif name == "AimBtn" then
            btn.Text = "AIM"
            btn.MouseButton1Click:Connect(function() AimToggle:Set(not Config.Aimlock) end)
        elseif name == "EspBtn" then
            btn.Text = "ESP"
            btn.MouseButton1Click:Connect(function() EspToggle:Set(not Config.ESP) end)
        elseif name == "TeleBtn" then
            btn.Text = "TELE"
            btn.MouseButton1Click:Connect(function()
                if Config.TargetPlr and Config.TargetPlr.Character then
                    LocalPlayer.Character:SetPrimaryPartCFrame(Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4))
                    Xan.Notify({Title = "Teleport", Content = "To: " .. Config.TargetPlr.Name})
                else
                    Xan.Notify({Title = "Teleport", Content = "No target!", Type = "Error"})
                end
            end)
        end
    end
end

-- RESPAWN
Connections["CharAdded"] = LocalPlayer.CharacterAdded:Connect(function()
    FlyGodModeActive = false
    if HealthConnection then pcall(function() HealthConnection:Disconnect() end) HealthConnection = nil end
    if GodModeSteppedConnection then pcall(function() GodModeSteppedConnection:Disconnect() end) GodModeSteppedConnection = nil end
    if GodModeRenderConnection then pcall(function() GodModeRenderConnection:Disconnect() end) GodModeRenderConnection = nil end
    if GodModeHeartbeatConnection then pcall(function() GodModeHeartbeatConnection:Disconnect() end) GodModeHeartbeatConnection = nil end
    ForceFieldInstance = nil
    OriginalCollisionGroups = {}
    ThreatDatabase = {}
    NeutralizedParts = {}
    StopThreatAI()
    StopUndergroundXray()

    if IsFlying then
        IsFlying = false
        if BodyVel then pcall(function() BodyVel:Destroy() end) BodyVel = nil end
        if BodyGyro then pcall(function() BodyGyro:Destroy() end) BodyGyro = nil end
        task.wait(1)
        if Config.Fly then StartFly() end
    end
end)

Xan.Notify({Title = "DEVS HUB", Content = "Loaded with AI + XRay!", Type = "Success"})
