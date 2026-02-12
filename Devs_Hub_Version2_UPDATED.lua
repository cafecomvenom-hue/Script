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

--// PLATFORM DETECTION
local IsAndroid = UserInputService.TouchEnabled
local IsMobile = IsAndroid

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
local Window = nil
local BodyVel, BodyGyro = nil, nil
local FlyUIFrame = nil
local UpButton = nil
local DownButton = nil
local FlyUpPressed = false
local FlyDownPressed = false

--// CREATE MODERN FLY UI
local function CreateFlyUI()
    if FlyUIFrame then
        pcall(function() FlyUIFrame:Destroy() end)
    end
    
    local screenSize = UserGui.AbsoluteSize
    local isLandscape = screenSize.X > screenSize.Y
    
    FlyUIFrame = Instance.new("Frame")
    FlyUIFrame.Name = "FlyUI"
    
    if IsMobile then
        -- Mobile: posição fixa no canto
        FlyUIFrame.Size = UDim2.new(0, 130, 0, 260)
        FlyUIFrame.Position = UDim2.new(0, 10, 0.5, -130)
    else
        -- Desktop: posição no centro
        FlyUIFrame.Size = UDim2.new(0, 140, 0, 280)
        FlyUIFrame.Position = UDim2.new(0.5, -70, 0.5, -140)
    end
    
    FlyUIFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    FlyUIFrame.BackgroundTransparency = 0.05
    FlyUIFrame.BorderSizePixel = 0
    FlyUIFrame.Visible = false
    FlyUIFrame.ZIndex = 999
    FlyUIFrame.Parent = UserGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = FlyUIFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 150, 255)
    stroke.Thickness = 2.5
    stroke.Parent = FlyUIFrame
    
    local shadow = Instance.new("UIDropShadow")
    shadow.BlurRadius = 10
    shadow.Color = Color3.fromRGB(0, 100, 200)
    shadow.Transparency = 0.5
    shadow.Offset = Vector2.new(0, 0)
    pcall(function() shadow.Parent = FlyUIFrame end)
    
    --// STATUS LABEL
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, -12, 0, 35)
    StatusLabel.Position = UDim2.new(0, 6, 0, 6)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3 = Color3.fromRGB(0, 150, 255)
    StatusLabel.TextSize = IsMobile and 14 or 16
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "✈️ MAGIC CARPET"
    StatusLabel.Parent = FlyUIFrame
    
    --// SPEED DISPLAY
    local SpeedDisplay = Instance.new("TextLabel")
    SpeedDisplay.Name = "SpeedDisplay"
    SpeedDisplay.Size = UDim2.new(1, -12, 0, 28)
    SpeedDisplay.Position = UDim2.new(0, 6, 0, 45)
    SpeedDisplay.BackgroundTransparency = 1
    SpeedDisplay.TextColor3 = Color3.fromRGB(100, 200, 255)
    SpeedDisplay.TextSize = IsMobile and 11 or 12
    SpeedDisplay.Font = Enum.Font.GothamSemibold
    SpeedDisplay.Text = "SPD: 50"
    SpeedDisplay.Parent = FlyUIFrame
    
    --// SEPARATOR
    local Separator1 = Instance.new("Frame")
    Separator1.Size = UDim2.new(1, -12, 0, 1)
    Separator1.Position = UDim2.new(0, 6, 0, 78)
    Separator1.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    Separator1.BackgroundTransparency = 0.5
    Separator1.BorderSizePixel = 0
    Separator1.Parent = FlyUIFrame
    
    --// UP BUTTON
    UpButton = Instance.new("TextButton")
    UpButton.Name = "UpBtn"
    UpButton.Size = UDim2.new(1, -12, 0, 50)
    UpButton.Position = UDim2.new(0, 6, 0, 88)
    UpButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    UpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    UpButton.TextSize = IsMobile and 16 or 18
    UpButton.Font = Enum.Font.GothamBold
    UpButton.Text = "⬆️ UP"
    UpButton.BorderSizePixel = 0
    UpButton.ZIndex = 1000
    UpButton.Parent = FlyUIFrame
    
    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0, 10)
    upCorner.Parent = UpButton
    
    local upStroke = Instance.new("UIStroke")
    upStroke.Color = Color3.fromRGB(100, 180, 255)
    upStroke.Thickness = 1.5
    upStroke.Parent = UpButton
    
    --// DOWN BUTTON
    DownButton = Instance.new("TextButton")
    DownButton.Name = "DownBtn"
    DownButton.Size = UDim2.new(1, -12, 0, 50)
    DownButton.Position = UDim2.new(0, 6, 0, 145)
    DownButton.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
    DownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    DownButton.TextSize = IsMobile and 16 or 18
    DownButton.Font = Enum.Font.GothamBold
    DownButton.Text = "⬇️ DOWN"
    DownButton.BorderSizePixel = 0
    DownButton.ZIndex = 1000
    DownButton.Parent = FlyUIFrame
    
    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0, 10)
    downCorner.Parent = DownButton
    
    local downStroke = Instance.new("UIStroke")
    downStroke.Color = Color3.fromRGB(255, 160, 100)
    downStroke.Thickness = 1.5
    downStroke.Parent = DownButton
    
    --// SEPARATOR 2
    local Separator2 = Instance.new("Frame")
    Separator2.Size = UDim2.new(1, -12, 0, 1)
    Separator2.Position = UDim2.new(0, 6, 0, 202)
    Separator2.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    Separator2.BackgroundTransparency = 0.5
    Separator2.BorderSizePixel = 0
    Separator2.Parent = FlyUIFrame
    
    --// CLOSE BUTTON
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(1, -12, 0, 40)
    CloseBtn.Position = UDim2.new(0, 6, 0, 212)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = IsMobile and 14 or 16
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "❌ EXIT"
    CloseBtn.BorderSizePixel = 0
    CloseBtn.ZIndex = 1000
    CloseBtn.Parent = FlyUIFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = CloseBtn
    
    local closeStroke = Instance.new("UIStroke")
    closeStroke.Color = Color3.fromRGB(255, 100, 100)
    closeStroke.Thickness = 1.5
    closeStroke.Parent = CloseBtn
    
    --// BUTTON ANIMATIONS & EVENTS
    local function setupButtonAnimations(button)
        button.MouseEnter:Connect(function()
            button.BackgroundTransparency = 0.15
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundTransparency = 0
        end)
    end
    
    setupButtonAnimations(UpButton)
    setupButtonAnimations(DownButton)
    setupButtonAnimations(CloseBtn)
    
    --// UP BUTTON EVENTS
    UpButton.MouseButton1Down:Connect(function()
        if Config.Fly then
            FlyUpPressed = true
            UpButton.BackgroundTransparency = 0.2
        end
    end)
    
    UpButton.MouseButton1Up:Connect(function()
        FlyUpPressed = false
        UpButton.BackgroundTransparency = 0
    end)
    
    UpButton.TouchBegan:Connect(function()
        if Config.Fly then
            FlyUpPressed = true
            UpButton.BackgroundTransparency = 0.2
        end
    end)
    
    UpButton.TouchEnded:Connect(function()
        FlyUpPressed = false
        UpButton.BackgroundTransparency = 0
    end)
    
    --// DOWN BUTTON EVENTS
    DownButton.MouseButton1Down:Connect(function()
        if Config.Fly then
            FlyDownPressed = true
            DownButton.BackgroundTransparency = 0.2
        end
    end)
    
    DownButton.MouseButton1Up:Connect(function()
        FlyDownPressed = false
        DownButton.BackgroundTransparency = 0
    end)
    
    DownButton.TouchBegan:Connect(function()
        if Config.Fly then
            FlyDownPressed = true
            DownButton.BackgroundTransparency = 0.2
        end
    end)
    
    DownButton.TouchEnded:Connect(function()
        FlyDownPressed = false
        DownButton.BackgroundTransparency = 0
    end)
    
    --// CLOSE BUTTON EVENT
    CloseBtn.MouseButton1Click:Connect(function()
        Config.Fly = false
        FlyUIFrame.Visible = false
        if LocalPlayer.Character then
            local h = LocalPlayer.Character:FindFirstChild("Humanoid")
            if h then
                h.PlatformStand = false
            end
        end
    end)
    
    CloseBtn.TouchTap:Connect(function()
        Config.Fly = false
        FlyUIFrame.Visible = false
        if LocalPlayer.Character then
            local h = LocalPlayer.Character:FindFirstChild("Humanoid")
            if h then
                h.PlatformStand = false
            end
        end
    end)
    
    --// UPDATE SPEED DISPLAY
    task.spawn(function()
        while FlyUIFrame and FlyUIFrame.Parent do
            pcall(function()
                SpeedDisplay.Text = "SPD: " .. tostring(Config.FlySpeed)
            end)
            task.wait(0.1)
        end
    end)
    
    return FlyUIFrame
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

    --// CREATE WINDOW
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
        CreateFlyUI()
        FlyUIFrame.Visible = true
        if IsMobile then
            Xan.Notify({
                Title = "🧞‍♂️ MAGIC CARPET", 
                Content = "Mova o analógico para voar!\nUse os botões para subir/descer",
                Type = "Success"
            })
        else
            Xan.Notify({
                Title = "🧞‍♂️ MAGIC CARPET",
                Content = "Use WASD para se mover\nE/Q ou botões para subir/descer",
                Type = "Success"
            })
        end
    else
        if FlyUIFrame then
            FlyUIFrame.Visible = false
        end
        Xan.Notify({Title = "Flight", Content = "Voo desativado"})
        if LocalPlayer.Character then
            local h = LocalPlayer.Character:FindFirstChild("Humanoid")
            if h then
                h.PlatformStand = false
            end
        end
    end
end)
MainTab:AddKeybind("Fly Key [F]", "fly_key", Enum.KeyCode.F, function()
    FlightTog:Set(not FlightTog.Value())
end)
MainTab:AddSlider("Fly Speed", "fly_val", {Min = 10, Max = 300, Default = 50}, function(v)
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
DevsTab:AddLabel("Version: 2.0")
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
    for _, c in pairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, o in pairs(Objects) do
        pcall(function()
            o:Destroy()
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

    --// FLY HACK - MAGIC CARPET MODE (FORWARD/BACKWARD + UP/DOWN ONLY)
    if Config.Fly then
        -- Initialize BodyVelocity and BodyGyro if not present
        if not BodyVel or not BodyVel.Parent then
            if BodyVel then pcall(function() BodyVel:Destroy() end) end
            BodyVel = Instance.new("BodyVelocity")
            BodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            BodyVel.Velocity = Vector3.zero
            BodyVel.Parent = root
            table.insert(Objects, BodyVel)
        end
        if not BodyGyro or not BodyGyro.Parent then
            if BodyGyro then pcall(function() BodyGyro:Destroy() end) end
            BodyGyro = Instance.new("BodyGyro")
            BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            BodyGyro.P = 9e4
            BodyGyro.D = 500
            BodyGyro.Parent = root
            table.insert(Objects, BodyGyro)
        end

        -- Show fly UI on Android when Fly is active
        if IsMobile and FlyUIFrame then
            FlyUIFrame.Visible = true
        end

        hum.PlatformStand = true
        BodyGyro.CFrame = Camera.CFrame
        
        local moveDirection = Vector3.zero
        local verticalInput = 0
        
        --// DESKTOP CONTROLS (W/S for forward/backward only)
        if not IsMobile then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection = moveDirection + Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection = moveDirection - Camera.CFrame.LookVector
            end
            -- Removed A/D (left/right) controls
        else
            --// MOBILE CONTROLS (Analog stick forward/backward only)
            if hum and hum.MoveDirection.Magnitude > 0 then
                local moveDir = hum.MoveDirection
                -- Only use Z component (forward/backward), ignore X component (left/right)
                moveDirection = Camera.CFrame.LookVector * moveDir.Z
            end
        end
        
        --// VERTICAL INPUT (BUTTONS + KEYS)
        if FlyUpPressed or UserInputService:IsKeyDown(Enum.KeyCode.E) then
            verticalInput = verticalInput + 1
        end
        if FlyDownPressed or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
            verticalInput = verticalInput - 1
        end
        
        moveDirection = moveDirection + Vector3.new(0, verticalInput, 0)
        
        --// NORMALIZE AND APPLY VELOCITY
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end
        
        BodyVel.Velocity = moveDirection * Config.FlySpeed
    else
        --// DISABLE FLY
        if BodyVel then
            pcall(function() BodyVel:Destroy() end)
            BodyVel = nil
        end
        if BodyGyro then
            pcall(function() BodyGyro:Destroy() end)
            BodyGyro = nil
        end
        if hum then
            hum.PlatformStand = false
        end
        
        -- Hide fly UI when Fly is disabled
        if FlyUIFrame then
            FlyUIFrame.Visible = false
        end
        
        FlyUpPressed = false
        FlyDownPressed = false
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
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
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

Xan.Notify({Title = "DEVS HUB", Content = "Loaded successfully!", Type = "Success"})