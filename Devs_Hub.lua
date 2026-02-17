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

--// FLY GOD MODE VARIABLES
local FlyGodModeActive = false
local OriginalHealth = nil
local HealthConnection = nil
local ForceFieldInstance = nil

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

    -- UP connections
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

    -- DOWN connections
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
-- FLY GOD MODE SYSTEM (Imortalidade + Sem Colisão durante Fly)
--------------------------------------------------------------------------------

local function EnableFlyGodMode()
    if FlyGodModeActive then return end
    FlyGodModeActive = true

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end

    -- Salvar vida original
    OriginalHealth = hum.Health

    -- Forçar vida máxima constantemente
    if HealthConnection then
        pcall(function() HealthConnection:Disconnect() end)
    end

    HealthConnection = hum.HealthChanged:Connect(function(newHealth)
        if FlyGodModeActive and hum then
            -- Se a vida diminuiu, restaurar imediatamente
            if newHealth < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end
    end)

    -- Setar vida máxima
    hum.Health = hum.MaxHealth

    -- Criar ForceField invisível para proteção extra
    if not char:FindFirstChild("FlyForceField") then
        ForceFieldInstance = Instance.new("ForceField")
        ForceFieldInstance.Name = "FlyForceField"
        ForceFieldInstance.Visible = false -- Invisível para não atrapalhar visualmente
        ForceFieldInstance.Parent = char
    end

    -- Desabilitar colisão em todas as partes do personagem
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function DisableFlyGodMode()
    if not FlyGodModeActive then return end
    FlyGodModeActive = false

    -- Desconectar listener de vida
    if HealthConnection then
        pcall(function() HealthConnection:Disconnect() end)
        HealthConnection = nil
    end

    -- Remover ForceField
    if ForceFieldInstance then
        pcall(function() ForceFieldInstance:Destroy() end)
        ForceFieldInstance = nil
    end

    local char = LocalPlayer.Character
    if char then
        -- Remover ForceField por nome caso tenha sobrado
        local ff = char:FindFirstChild("FlyForceField")
        if ff then
            pcall(function() ff:Destroy() end)
        end

        -- Restaurar colisão
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end

        -- Restaurar HumanoidRootPart como não colidível (padrão do Roblox)
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CanCollide = true
        end
    end
end

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

    -- Ativar God Mode ao voar
    EnableFlyGodMode()

    if IsAndroid and FlyControlFrame then
        FlyControlFrame.Visible = true
    end
end

local function StopFly()
    IsFlying = false

    -- Desativar God Mode ao parar de voar
    DisableFlyGodMode()

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

--// INITIALIZE WINDOW
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

--// MAIN: COMBAT
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

--// MAIN: VISUALS
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

--// MAIN: MOVEMENT
MainTab:AddSection("Movement")

local FlightTog = MainTab:AddToggle("Fly Hack", "fly_hack", function(v)
    Config.Fly = v
    if v then
        if IsAndroid then
            Xan.Notify({
                Title = "Flight",
                Content = "Joystick mover + ▲/▼ subir/descer | God Mode ON",
                Type = "Success"
            })
        else
            Xan.Notify({
                Title = "Flight",
                Content = "WASD mover, E/Space subir, Q/Shift descer | God Mode ON",
                Type = "Success"
            })
        end
    else
        Xan.Notify({
            Title = "Flight",
            Content = "Fly desativado | God Mode OFF",
            Type = "Info"
        })
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

--// MAIN: TELEPORT
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

--// PLAYER TAB
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

PlayerTab:AddSection("Equipment")

PlayerTab:AddButton("Remove All Tools", function()
    if LocalPlayer.Character then
        for _, tool in pairs(LocalPlayer.Character:FindFirstChild("Backpack") and LocalPlayer.Character.Backpack:GetChildren() or {}) do
            if tool:IsA("Tool") then
                tool:Destroy()
            end
        end
        Xan.Notify({Title = "Equipment", Content = "All tools removed"})
    end
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

--// DEVS TAB
DevsTab:AddSection("Credits")

DevsTab:AddLabel("DEVS HUB")
DevsTab:AddLabel("Version: 1.0")
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

--// CONFIG TAB
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

    --// NOCLIP
    if Config.Noclip then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end

    --// SPEED HACK
    if Config.SpeedHack then
        hum.WalkSpeed = Config.WalkSpeed
    end

    --// JUMP HACK
    if Config.JumpHack then
        hum.UseJumpPower = true
        hum.JumpPower = Config.JumpPower
    end

    --// FLY HACK
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

        -- God Mode contínuo: forçar vida máxima + sem colisão a cada frame
        if hum and hum.Health > 0 then
            hum.Health = hum.MaxHealth
        end

        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end

        -- Garantir ForceField existe
        if not char:FindFirstChild("FlyForceField") then
            pcall(function()
                local ff = Instance.new("ForceField")
                ff.Name = "FlyForceField"
                ff.Visible = false
                ff.Parent = char
                ForceFieldInstance = ff
            end)
        end

        -- Anular qualquer estado de morte
        if hum:GetState() == Enum.HumanoidStateType.Dead then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        -- Impedir ragdoll / flinch
        if hum:GetState() == Enum.HumanoidStateType.FallingDown or
           hum:GetState() == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    else
        if IsFlying then
            StopFly()
        end
    end

    --// STEAL SPEED HACK
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

--// AIMLOCK
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

--// INFINITE JUMP
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

--// INPUT HANDLER
Connections["Inputs"] = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    --// DEBUG ACTION LOGGER
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
                
                warn(debugMessage)
                Xan.Notify({Title = "Debug", Content = "Action logged to F9", Type = "Info"})
            else
                warn("[DEVS HUB DEBUG] No object hit by raycast")
            end
        end)
    end

    --// TELEPORT HOTKEY
    if input.KeyCode == Enum.KeyCode.U and Config.TargetPlr and Config.TargetPlr.Character then
        pcall(function()
            LocalPlayer.Character:SetPrimaryPartCFrame(
                Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
            )
            Xan.Notify({Title = "Teleport", Content = "To: " .. Config.TargetPlr.Name})
        end)
    end
end)

--// ANDROID BUTTON CONNECTIONS
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
        end
    end
end

--// RESPAWN HANDLER
Connections["CharAdded"] = LocalPlayer.CharacterAdded:Connect(function(newChar)
    -- Resetar god mode ao respawnar
    FlyGodModeActive = false
    if HealthConnection then
        pcall(function() HealthConnection:Disconnect() end)
        HealthConnection = nil
    end
    ForceFieldInstance = nil

    if IsFlying then
        StopFly()
        task.wait(0.5)
        if Config.Fly then
            StartFly()
        end
    end
end)

Xan.Notify({Title = "DEVS HUB", Content = "Loaded successfully!", Type = "Success"})
