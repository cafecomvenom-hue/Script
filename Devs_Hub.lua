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
    SavedPos2 = nil,
    TouchInspector = false
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
local ThreatAlertLabel2 = nil
local NeutralizedParts = {}

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

--// TOUCH INSPECTOR VARIABLES
local TouchInspectorActive = false
local TouchInspectorConnection = nil
local InspectorHighlights = {}
local InspectorLabels = {}
local InspectorPanelGui = nil
local InspectorInfoPanel = nil
local InspectorContentFrame = nil
local InspectorTouchIndicator = nil

--// MOBILE CONSOLE VARIABLES
local MobileConsoleGui = nil
local MobileConsoleFrame = nil
local MobileConsoleScroll = nil
local MobileConsoleVisible = false
local ConsoleLogEntries = {}
local MAX_CONSOLE_ENTRIES = 100

--// COLLISION GROUP
local FLY_NOCLIP_GROUP = "DevsHubFlyNoclip"

local function SetupCollisionGroup()
    if FlyNoclipGroupCreated then return true end
    local success = pcall(function()
        PhysicsService:RegisterCollisionGroup(FLY_NOCLIP_GROUP)
    end)
    if success then
        pcall(function()
            for _, g in pairs(PhysicsService:GetRegisteredCollisionGroups()) do
                pcall(function() PhysicsService:CollisionGroupSetCollidable(FLY_NOCLIP_GROUP, g.name or g, false) end)
            end
            pcall(function() PhysicsService:CollisionGroupSetCollidable(FLY_NOCLIP_GROUP, "Default", false) end)
        end)
        FlyNoclipGroupCreated = true
    end
    return success
end

local function AssignCharToNoclipGroup(char)
    if not char then return end
    if not FlyNoclipGroupCreated then SetupCollisionGroup() end
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                if not OriginalCollisionGroups[p] then OriginalCollisionGroups[p] = p.CollisionGroup end
                p.CollisionGroup = FLY_NOCLIP_GROUP
            end)
        end
    end
end

local function RestoreCharCollisionGroup(char)
    if not char then return end
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.CollisionGroup = OriginalCollisionGroups[p] or "Default"
                OriginalCollisionGroups[p] = nil
            end)
        end
    end
    OriginalCollisionGroups = {}
end

--------------------------------------------------------------------------------
-- MOBILE CONSOLE (Log visível no Android)
--------------------------------------------------------------------------------

local function CreateMobileConsole()
    if MobileConsoleGui then pcall(function() MobileConsoleGui:Destroy() end) end

    MobileConsoleGui = Instance.new("ScreenGui")
    MobileConsoleGui.Name = "MobileConsoleGui"
    MobileConsoleGui.ResetOnSpawn = false
    MobileConsoleGui.DisplayOrder = 500
    MobileConsoleGui.Parent = UserGui

    -- Botão toggle do console
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ConsoleToggle"
    toggleBtn.Size = UDim2.new(0, 40, 0, 40)
    toggleBtn.Position = UDim2.new(0, 10, 0.85, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    toggleBtn.Text = "📋"
    toggleBtn.TextSize = 18
    toggleBtn.BorderSizePixel = 0
    toggleBtn.ZIndex = 510
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = MobileConsoleGui
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)
    local toggleStroke = Instance.new("UIStroke", toggleBtn)
    toggleStroke.Color = Color3.fromRGB(0, 200, 150)
    toggleStroke.Thickness = 1.5

    -- Frame principal do console
    MobileConsoleFrame = Instance.new("Frame")
    MobileConsoleFrame.Name = "ConsoleFrame"
    MobileConsoleFrame.Size = UDim2.new(0.92, 0, 0, 300)
    MobileConsoleFrame.Position = UDim2.new(0.04, 0, 0.5, -150)
    MobileConsoleFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
    MobileConsoleFrame.BackgroundTransparency = 0.03
    MobileConsoleFrame.BorderSizePixel = 0
    MobileConsoleFrame.Visible = false
    MobileConsoleFrame.ZIndex = 500
    MobileConsoleFrame.Parent = MobileConsoleGui

    Instance.new("UICorner", MobileConsoleFrame).CornerRadius = UDim.new(0, 14)
    local frameStroke = Instance.new("UIStroke", MobileConsoleFrame)
    frameStroke.Color = Color3.fromRGB(0, 180, 130)
    frameStroke.Thickness = 2
    frameStroke.Transparency = 0.2

    -- Arrastar
    local dragging, dragStart, startPos = false, nil, nil
    MobileConsoleFrame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = MobileConsoleFrame.Position
        end
    end)
    MobileConsoleFrame.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = i.Position - dragStart
            MobileConsoleFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    MobileConsoleFrame.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- Header
    local header = Instance.new("Frame", MobileConsoleFrame)
    header.Size = UDim2.new(1, 0, 0, 34)
    header.BackgroundColor3 = Color3.fromRGB(0, 120, 90)
    header.BackgroundTransparency = 0.2
    header.BorderSizePixel = 0
    header.ZIndex = 501
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)
    local headerFix = Instance.new("Frame", header)
    headerFix.Size = UDim2.new(1, 0, 0, 14); headerFix.Position = UDim2.new(0, 0, 1, -14)
    headerFix.BackgroundColor3 = Color3.fromRGB(0, 120, 90); headerFix.BackgroundTransparency = 0.2
    headerFix.BorderSizePixel = 0; headerFix.ZIndex = 501

    local headerTitle = Instance.new("TextLabel", header)
    headerTitle.Size = UDim2.new(1, -90, 1, 0); headerTitle.Position = UDim2.new(0, 10, 0, 0)
    headerTitle.BackgroundTransparency = 1; headerTitle.Text = "📋 DEVS CONSOLE"
    headerTitle.TextColor3 = Color3.fromRGB(220, 255, 240); headerTitle.TextSize = 13
    headerTitle.Font = Enum.Font.GothamBold; headerTitle.TextXAlignment = Enum.TextXAlignment.Left; headerTitle.ZIndex = 502

    -- Botão limpar
    local clearBtn = Instance.new("TextButton", header)
    clearBtn.Size = UDim2.new(0, 50, 0, 24); clearBtn.Position = UDim2.new(1, -95, 0.5, -12)
    clearBtn.BackgroundColor3 = Color3.fromRGB(180, 120, 0); clearBtn.Text = "Clear"
    clearBtn.TextColor3 = Color3.new(1, 1, 1); clearBtn.TextSize = 10; clearBtn.Font = Enum.Font.GothamBold
    clearBtn.BorderSizePixel = 0; clearBtn.ZIndex = 503; clearBtn.AutoButtonColor = false
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 6)

    -- Botão fechar
    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 28, 0, 28); closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.TextSize = 14; closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0; closeBtn.ZIndex = 503; closeBtn.AutoButtonColor = false
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

    -- ScrollingFrame para logs
    MobileConsoleScroll = Instance.new("ScrollingFrame", MobileConsoleFrame)
    MobileConsoleScroll.Name = "LogScroll"
    MobileConsoleScroll.Size = UDim2.new(1, -12, 1, -42)
    MobileConsoleScroll.Position = UDim2.new(0, 6, 0, 38)
    MobileConsoleScroll.BackgroundTransparency = 1
    MobileConsoleScroll.BorderSizePixel = 0
    MobileConsoleScroll.ScrollBarThickness = 4
    MobileConsoleScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 150)
    MobileConsoleScroll.ZIndex = 501
    MobileConsoleScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    MobileConsoleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local logLayout = Instance.new("UIListLayout", MobileConsoleScroll)
    logLayout.SortOrder = Enum.SortOrder.LayoutOrder
    logLayout.Padding = UDim.new(0, 1)

    -- Conexões
    toggleBtn.MouseButton1Click:Connect(function()
        MobileConsoleVisible = not MobileConsoleVisible
        MobileConsoleFrame.Visible = MobileConsoleVisible
        toggleStroke.Color = MobileConsoleVisible and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(0, 200, 150)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        MobileConsoleVisible = false
        MobileConsoleFrame.Visible = false
        toggleStroke.Color = Color3.fromRGB(0, 200, 150)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        for _, entry in pairs(ConsoleLogEntries) do
            pcall(function() entry:Destroy() end)
        end
        ConsoleLogEntries = {}
    end)
end

-- Adicionar uma entrada ao console mobile
local function ConsoleLog(logType, title, message)
    if not MobileConsoleScroll then return end

    local colors = {
        INFO = Color3.fromRGB(100, 200, 255),
        SUCCESS = Color3.fromRGB(0, 255, 150),
        WARNING = Color3.fromRGB(255, 200, 0),
        ERROR = Color3.fromRGB(255, 80, 80),
        INSPECT = Color3.fromRGB(0, 255, 200),
        DEBUG = Color3.fromRGB(200, 150, 255),
        THREAT = Color3.fromRGB(255, 100, 50)
    }

    local icons = {
        INFO = "ℹ️",
        SUCCESS = "✅",
        WARNING = "⚠️",
        ERROR = "❌",
        INSPECT = "🔍",
        DEBUG = "🐛",
        THREAT = "🛡️"
    }

    local entryFrame = Instance.new("Frame")
    entryFrame.Size = UDim2.new(1, -4, 0, 0)
    entryFrame.AutomaticSize = Enum.AutomaticSize.Y
    entryFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
    entryFrame.BackgroundTransparency = 0.3
    entryFrame.BorderSizePixel = 0
    entryFrame.ZIndex = 502
    entryFrame.LayoutOrder = #ConsoleLogEntries + 1
    entryFrame.Parent = MobileConsoleScroll

    Instance.new("UICorner", entryFrame).CornerRadius = UDim.new(0, 6)

    local entryPadding = Instance.new("UIPadding", entryFrame)
    entryPadding.PaddingLeft = UDim.new(0, 6)
    entryPadding.PaddingRight = UDim.new(0, 6)
    entryPadding.PaddingTop = UDim.new(0, 3)
    entryPadding.PaddingBottom = UDim.new(0, 3)

    -- Indicador de cor lateral
    local colorBar = Instance.new("Frame", entryFrame)
    colorBar.Size = UDim2.new(0, 3, 1, -6)
    colorBar.Position = UDim2.new(0, -3, 0, 3)
    colorBar.BackgroundColor3 = colors[logType] or Color3.fromRGB(150, 150, 150)
    colorBar.BorderSizePixel = 0
    colorBar.ZIndex = 503

    -- Timestamp + tipo
    local headerLabel = Instance.new("TextLabel", entryFrame)
    headerLabel.Size = UDim2.new(1, 0, 0, 14)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Text = (icons[logType] or "•") .. " " .. os.date("%H:%M:%S") .. " [" .. (logType or "LOG") .. "] " .. (title or "")
    headerLabel.TextColor3 = colors[logType] or Color3.fromRGB(180, 180, 180)
    headerLabel.TextSize = 10
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.TextWrapped = true
    headerLabel.ZIndex = 503

    -- Mensagem
    if message and message ~= "" then
        local msgLabel = Instance.new("TextLabel", entryFrame)
        msgLabel.Size = UDim2.new(1, 0, 0, 0)
        msgLabel.Position = UDim2.new(0, 0, 0, 16)
        msgLabel.AutomaticSize = Enum.AutomaticSize.Y
        msgLabel.BackgroundTransparency = 1
        msgLabel.Text = tostring(message)
        msgLabel.TextColor3 = Color3.fromRGB(200, 210, 220)
        msgLabel.TextSize = 9
        msgLabel.Font = Enum.Font.Gotham
        msgLabel.TextXAlignment = Enum.TextXAlignment.Left
        msgLabel.TextWrapped = true
        msgLabel.ZIndex = 503
    end

    table.insert(ConsoleLogEntries, entryFrame)

    -- Limitar entradas
    if #ConsoleLogEntries > MAX_CONSOLE_ENTRIES then
        local oldest = table.remove(ConsoleLogEntries, 1)
        pcall(function() oldest:Destroy() end)
    end

    -- Auto-scroll para o final
    task.defer(function()
        if MobileConsoleScroll then
            MobileConsoleScroll.CanvasPosition = Vector2.new(0, MobileConsoleScroll.AbsoluteCanvasSize.Y)
        end
    end)

    -- Também enviar para console real (F9)
    pcall(function()
        oldWarn("[DEVS HUB] [" .. (logType or "LOG") .. "] " .. (title or "") .. ": " .. (message or ""))
    end)
end

CreateMobileConsole()

--------------------------------------------------------------------------------
-- ANDROID TOUCH BUTTONS
--------------------------------------------------------------------------------

local function CreateAndroidButtons()
    if not IsAndroid then return end
    local TouchFrame = Instance.new("Frame")
    TouchFrame.Name = "AndroidButtons"; TouchFrame.Size = UDim2.new(1, 0, 1, 0)
    TouchFrame.BackgroundTransparency = 1; TouchFrame.Parent = UserGui

    local cfgs = {
        {Name="FlyBtn",Pos=UDim2.new(0,10,0.5,-25),Color=Color3.fromRGB(0,150,255)},
        {Name="SpeedBtn",Pos=UDim2.new(0,10,0.6,-25),Color=Color3.fromRGB(0,200,0)},
        {Name="AimBtn",Pos=UDim2.new(0,10,0.4,-25),Color=Color3.fromRGB(255,0,0)},
        {Name="EspBtn",Pos=UDim2.new(0,10,0.7,-25),Color=Color3.fromRGB(255,200,0)},
        {Name="TeleBtn",Pos=UDim2.new(0.9,-50,0.5,-25),Color=Color3.fromRGB(150,0,255)},
    }
    for _, c in pairs(cfgs) do
        local b = Instance.new("TextButton"); b.Name=c.Name; b.Size=UDim2.new(0,50,0,50); b.Position=c.Pos
        b.BackgroundColor3=c.Color; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.TextScaled=true
        b.BorderSizePixel=0; b.BackgroundTransparency=0.3; b.Parent=TouchFrame
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        table.insert(TouchButtons, {Button=b, Name=c.Name})
    end
    return TouchFrame
end

local AndroidButtonFrame = CreateAndroidButtons()

--------------------------------------------------------------------------------
-- FLY CONTROL UI
--------------------------------------------------------------------------------

local function CreateFlyControlButtons()
    if not IsAndroid then return nil end
    if FlyControlFrame then pcall(function() FlyControlFrame:Destroy() end); FlyControlFrame = nil end
    local g = Instance.new("ScreenGui"); g.Name="FlyControlGui"; g.ResetOnSpawn=false; g.DisplayOrder=100; g.Parent=UserGui
    FlyControlFrame = Instance.new("Frame",g); FlyControlFrame.Name="FlyControls"
    FlyControlFrame.Size=UDim2.new(0,56,0,120); FlyControlFrame.Position=UDim2.new(1,-68,0.5,-60)
    FlyControlFrame.BackgroundColor3=Color3.fromRGB(18,18,28); FlyControlFrame.BackgroundTransparency=0.08
    FlyControlFrame.BorderSizePixel=0; FlyControlFrame.Visible=false; FlyControlFrame.ZIndex=50
    Instance.new("UICorner",FlyControlFrame).CornerRadius=UDim.new(0,14)
    local ms=Instance.new("UIStroke",FlyControlFrame); ms.Color=Color3.fromRGB(60,130,220); ms.Thickness=1.5; ms.Transparency=0.4

    local dr,ds2,sp = false,nil,nil
    FlyControlFrame.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true;ds2=i.Position;sp=FlyControlFrame.Position end end)
    FlyControlFrame.InputChanged:Connect(function(i) if dr and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then local d=i.Position-ds2; FlyControlFrame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
    FlyControlFrame.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end end)

    local fi=Instance.new("TextLabel",FlyControlFrame); fi.Size=UDim2.new(1,0,0,16); fi.Position=UDim2.new(0,0,0,4); fi.BackgroundTransparency=1; fi.Text="✈"; fi.TextColor3=Color3.fromRGB(80,170,255); fi.TextSize=12; fi.Font=Enum.Font.GothamBold; fi.ZIndex=51

    local UB=Instance.new("TextButton",FlyControlFrame); UB.Name="FlyUp"; UB.Size=UDim2.new(0,42,0,38); UB.Position=UDim2.new(0.5,-21,0,22); UB.BackgroundColor3=Color3.fromRGB(35,140,75); UB.Text=""; UB.BorderSizePixel=0; UB.ZIndex=52; UB.AutoButtonColor=false
    Instance.new("UICorner",UB).CornerRadius=UDim.new(0,10)
    local us=Instance.new("UIStroke",UB); us.Color=Color3.fromRGB(70,200,120); us.Thickness=1; us.Transparency=0.5
    local ua=Instance.new("TextLabel",UB); ua.Size=UDim2.new(1,0,1,0); ua.BackgroundTransparency=1; ua.Text="▲"; ua.TextColor3=Color3.fromRGB(220,255,230); ua.TextSize=18; ua.Font=Enum.Font.GothamBold; ua.ZIndex=53

    local sep=Instance.new("Frame",FlyControlFrame); sep.Size=UDim2.new(0.6,0,0,1); sep.Position=UDim2.new(0.2,0,0.5,-1); sep.BackgroundColor3=Color3.fromRGB(60,60,90); sep.BackgroundTransparency=0.5; sep.BorderSizePixel=0; sep.ZIndex=51

    local DB=Instance.new("TextButton",FlyControlFrame); DB.Name="FlyDown"; DB.Size=UDim2.new(0,42,0,38); DB.Position=UDim2.new(0.5,-21,0,64); DB.BackgroundColor3=Color3.fromRGB(170,60,35); DB.Text=""; DB.BorderSizePixel=0; DB.ZIndex=52; DB.AutoButtonColor=false
    Instance.new("UICorner",DB).CornerRadius=UDim.new(0,10)
    local dss=Instance.new("UIStroke",DB); dss.Color=Color3.fromRGB(230,100,70); dss.Thickness=1; dss.Transparency=0.5
    local da=Instance.new("TextLabel",DB); da.Size=UDim2.new(1,0,1,0); da.BackgroundTransparency=1; da.Text="▼"; da.TextColor3=Color3.fromRGB(255,220,210); da.TextSize=18; da.Font=Enum.Font.GothamBold; da.ZIndex=53

    local sl=Instance.new("TextLabel",FlyControlFrame); sl.Name="SpeedLabel"; sl.Size=UDim2.new(1,0,0,14); sl.Position=UDim2.new(0,0,1,-16); sl.BackgroundTransparency=1; sl.Text=tostring(math.floor(Config.FlySpeed)); sl.TextColor3=Color3.fromRGB(140,140,170); sl.TextSize=9; sl.Font=Enum.Font.GothamMedium; sl.ZIndex=51

    UB.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then AndroidUpPressed=true; us.Color=Color3.fromRGB(120,255,170); us.Transparency=0 end end)
    UB.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then AndroidUpPressed=false; us.Color=Color3.fromRGB(70,200,120); us.Transparency=0.5 end end)
    DB.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then AndroidDownPressed=true; dss.Color=Color3.fromRGB(255,150,100); dss.Transparency=0 end end)
    DB.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then AndroidDownPressed=false; dss.Color=Color3.fromRGB(230,100,70); dss.Transparency=0.5 end end)
    return sl
end

FlySpeedLabel = CreateFlyControlButtons()

--------------------------------------------------------------------------------
-- TOUCH INSPECTOR SYSTEM
--------------------------------------------------------------------------------

local function CreateInspectorPanel()
    if InspectorPanelGui then pcall(function() InspectorPanelGui:Destroy() end) end

    InspectorPanelGui = Instance.new("ScreenGui")
    InspectorPanelGui.Name = "InspectorPanelGui"; InspectorPanelGui.ResetOnSpawn = false
    InspectorPanelGui.DisplayOrder = 300; InspectorPanelGui.Parent = UserGui

    local panel = Instance.new("Frame", InspectorPanelGui)
    panel.Name = "InfoPanel"; panel.Size = UDim2.new(0, 300, 0, 220)
    panel.Position = UDim2.new(0.5, -150, 1, -235)
    panel.BackgroundColor3 = Color3.fromRGB(12, 12, 22); panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0; panel.Visible = false; panel.ZIndex = 300
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    local ps = Instance.new("UIStroke", panel); ps.Color = Color3.fromRGB(0, 200, 150); ps.Thickness = 2; ps.Transparency = 0.2

    -- Arrastar painel
    local pDrag, pDS, pSP = false, nil, nil
    panel.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then pDrag=true;pDS=i.Position;pSP=panel.Position end end)
    panel.InputChanged:Connect(function(i) if pDrag and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then local d=i.Position-pDS; panel.Position=UDim2.new(pSP.X.Scale,pSP.X.Offset+d.X,pSP.Y.Scale,pSP.Y.Offset+d.Y) end end)
    panel.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then pDrag=false end end)

    local hdr = Instance.new("Frame", panel); hdr.Size = UDim2.new(1, 0, 0, 30)
    hdr.BackgroundColor3 = Color3.fromRGB(0, 150, 120); hdr.BackgroundTransparency = 0.3
    hdr.BorderSizePixel = 0; hdr.ZIndex = 301
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 12)
    local hf = Instance.new("Frame", hdr); hf.Size = UDim2.new(1,0,0,12); hf.Position = UDim2.new(0,0,1,-12)
    hf.BackgroundColor3 = Color3.fromRGB(0,150,120); hf.BackgroundTransparency = 0.3; hf.BorderSizePixel = 0; hf.ZIndex = 301

    local ht = Instance.new("TextLabel", hdr); ht.Size = UDim2.new(1,-40,1,0); ht.Position = UDim2.new(0,10,0,0)
    ht.BackgroundTransparency = 1; ht.Text = "🔍 TOUCH INSPECTOR"; ht.TextColor3 = Color3.new(1,1,1)
    ht.TextSize = 12; ht.Font = Enum.Font.GothamBold; ht.TextXAlignment = Enum.TextXAlignment.Left; ht.ZIndex = 302

    local cb = Instance.new("TextButton", hdr); cb.Size = UDim2.new(0,24,0,24); cb.Position = UDim2.new(1,-28,0.5,-12)
    cb.BackgroundColor3 = Color3.fromRGB(200,50,50); cb.Text = "✕"; cb.TextColor3 = Color3.new(1,1,1)
    cb.TextSize = 12; cb.Font = Enum.Font.GothamBold; cb.BorderSizePixel = 0; cb.ZIndex = 303; cb.AutoButtonColor = false
    Instance.new("UICorner", cb).CornerRadius = UDim.new(1, 0)
    cb.MouseButton1Click:Connect(function() panel.Visible = false end)

    local sf = Instance.new("ScrollingFrame", panel); sf.Name = "Content"
    sf.Size = UDim2.new(1, -12, 1, -38); sf.Position = UDim2.new(0, 6, 0, 34)
    sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0; sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 150); sf.ZIndex = 301
    sf.CanvasSize = UDim2.new(0, 0, 0, 0); sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UIListLayout", sf).SortOrder = Enum.SortOrder.LayoutOrder

    -- Touch indicator
    local ti = Instance.new("Frame", InspectorPanelGui); ti.Name = "TouchInd"
    ti.Size = UDim2.new(0, 40, 0, 40); ti.Position = UDim2.new(0.5, -20, 0.5, -20)
    ti.BackgroundTransparency = 1; ti.Visible = false; ti.ZIndex = 305
    local ch = Instance.new("Frame", ti); ch.Size = UDim2.new(1,0,0,2); ch.Position = UDim2.new(0,0,0.5,-1)
    ch.BackgroundColor3 = Color3.fromRGB(0,255,200); ch.BackgroundTransparency = 0.3; ch.BorderSizePixel = 0; ch.ZIndex = 306
    local cv = Instance.new("Frame", ti); cv.Size = UDim2.new(0,2,1,0); cv.Position = UDim2.new(0.5,-1,0,0)
    cv.BackgroundColor3 = Color3.fromRGB(0,255,200); cv.BackgroundTransparency = 0.3; cv.BorderSizePixel = 0; cv.ZIndex = 306
    local cc = Instance.new("Frame", ti); cc.Size = UDim2.new(0,20,0,20); cc.Position = UDim2.new(0.5,-10,0.5,-10)
    cc.BackgroundTransparency = 1; cc.ZIndex = 306
    local cs = Instance.new("UIStroke", cc); cs.Color = Color3.fromRGB(0,255,200); cs.Thickness = 1.5; cs.Transparency = 0.3
    Instance.new("UICorner", cc).CornerRadius = UDim.new(1, 0)

    InspectorInfoPanel = panel
    InspectorContentFrame = sf
    InspectorTouchIndicator = ti
end

CreateInspectorPanel()

local function CreateInfoLine(parent, label, value, color, order)
    local l = Instance.new("Frame", parent); l.Size = UDim2.new(1, 0, 0, 16); l.BackgroundTransparency = 1; l.ZIndex = 302; l.LayoutOrder = order or 0
    local lt = Instance.new("TextLabel", l); lt.Size = UDim2.new(0, 75, 1, 0); lt.BackgroundTransparency = 1
    lt.Text = label; lt.TextColor3 = Color3.fromRGB(140, 160, 180); lt.TextSize = 9; lt.Font = Enum.Font.GothamMedium; lt.TextXAlignment = Enum.TextXAlignment.Left; lt.ZIndex = 302
    local vt = Instance.new("TextLabel", l); vt.Size = UDim2.new(1, -78, 1, 0); vt.Position = UDim2.new(0, 78, 0, 0); vt.BackgroundTransparency = 1
    vt.Text = tostring(value); vt.TextColor3 = color or Color3.fromRGB(220, 240, 255); vt.TextSize = 9; vt.Font = Enum.Font.GothamBold; vt.TextXAlignment = Enum.TextXAlignment.Left; vt.TextWrapped = true; vt.ZIndex = 302
end

local function ClearInspectorPanel()
    if InspectorContentFrame then for _, c in pairs(InspectorContentFrame:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end end
end

local function ClearInspectorHighlights()
    for _, h in pairs(InspectorHighlights) do pcall(function() h:Destroy() end) end; InspectorHighlights = {}
    for _, l in pairs(InspectorLabels) do pcall(function() l:Destroy() end) end; InspectorLabels = {}
end

local function GetObjectInfo(part)
    local info = {}
    pcall(function()
        info.Name = part.Name; info.ClassName = part.ClassName; info.FullName = part:GetFullName()
        local chain = {}; local cur = part.Parent; local d = 0
        while cur and cur ~= workspace and d < 5 do table.insert(chain, cur.Name.." ["..cur.ClassName.."]"); cur = cur.Parent; d = d + 1 end
        info.ParentChain = table.concat(chain, " → ")
        if part:IsA("BasePart") then
            info.Position = string.format("%.1f, %.1f, %.1f", part.Position.X, part.Position.Y, part.Position.Z)
            info.Size = string.format("%.1f, %.1f, %.1f", part.Size.X, part.Size.Y, part.Size.Z)
            info.Material = tostring(part.Material)
            info.Color = string.format("R:%d G:%d B:%d", math.floor(part.Color.R*255), math.floor(part.Color.G*255), math.floor(part.Color.B*255))
            info.Transparency = string.format("%.2f", part.Transparency)
            info.Anchored = tostring(part.Anchored)
            info.CanCollide = tostring(part.CanCollide)
            info.Mass = string.format("%.1f", part:GetMass())
            local v = Vector3.zero; pcall(function() v = part.AssemblyLinearVelocity or Vector3.zero end)
            if v.Magnitude > 0.1 then info.Velocity = string.format("%.1f studs/s", v.Magnitude) end
        end
        if part:IsA("MeshPart") then info.MeshId = part.MeshId ~= "" and part.MeshId or nil end
        info.ChildCount = tostring(#part:GetChildren())
        local ct = {}; for _, c in pairs(part:GetChildren()) do ct[c.ClassName] = (ct[c.ClassName] or 0) + 1 end
        local cts = {}; for t, n in pairs(ct) do table.insert(cts, t.."("..n..")") end
        if #cts > 0 then info.ChildTypes = table.concat(cts, ", ") end
        local hs = false; for _, desc in pairs(part:GetDescendants()) do if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then hs = true; break end end
        info.HasScripts = tostring(hs)
        local vals = {}; for _, c in pairs(part:GetChildren()) do if c:IsA("ValueBase") then table.insert(vals, c.Name.." = "..tostring(c.Value)) end end
        if #vals > 0 then info.Values = table.concat(vals, ", ") end
        local model = part.Parent
        if model and model:IsA("Model") then
            info.ModelName = model.Name; info.ModelParts = tostring(#model:GetDescendants())
            if model:FindFirstChild("Humanoid") then local h = model.Humanoid; info.IsNPC = "HP: "..math.floor(h.Health).."/"..math.floor(h.MaxHealth) end
        end
        local cd = part:FindFirstChildOfClass("ClickDetector"); if cd then info.Interact = "ClickDetector" end
        local pp = part:FindFirstChildOfClass("ProximityPrompt"); if pp then info.Interact = "Prompt: "..pp.ActionText end
    end)
    return info
end

local function ShowObjectInfo(part, screenPos)
    if not part or not InspectorInfoPanel or not InspectorContentFrame then return end
    ClearInspectorPanel(); ClearInspectorHighlights()
    local info = GetObjectInfo(part)

    -- Highlight
    pcall(function()
        local target = part.Parent and part.Parent:IsA("Model") and part.Parent or part
        local hl = Instance.new("Highlight"); hl.Name = "InspectorHL"
        hl.FillColor = Color3.fromRGB(0,255,180); hl.OutlineColor = Color3.new(1,1,1)
        hl.FillTransparency = 0.7; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = target; hl.Parent = target
        table.insert(InspectorHighlights, hl)

        local bb = Instance.new("BillboardGui"); bb.Name = "InspectorLabel"
        bb.Size = UDim2.new(0, 180, 0, 40); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true
        bb.Adornee = part:IsA("BasePart") and part or target:FindFirstChildWhichIsA("BasePart")
        bb.Parent = target
        local bf = Instance.new("Frame", bb); bf.Size = UDim2.new(1,0,1,0)
        bf.BackgroundColor3 = Color3.fromRGB(0,30,25); bf.BackgroundTransparency = 0.2; bf.BorderSizePixel = 0
        Instance.new("UICorner", bf).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", bf).Color = Color3.fromRGB(0,255,180)
        local bn = Instance.new("TextLabel", bf); bn.Size = UDim2.new(1,-6,0.5,0); bn.Position = UDim2.new(0,3,0,2)
        bn.BackgroundTransparency = 1; bn.Text = "🔍 "..(info.Name or "?"); bn.TextColor3 = Color3.fromRGB(0,255,200)
        bn.TextSize = 12; bn.Font = Enum.Font.GothamBold; bn.TextScaled = true
        local bc = Instance.new("TextLabel", bf); bc.Size = UDim2.new(1,-6,0.4,0); bc.Position = UDim2.new(0,3,0.5,0)
        bc.BackgroundTransparency = 1; bc.Text = info.ClassName or ""; bc.TextColor3 = Color3.fromRGB(180,200,220)
        bc.TextSize = 9; bc.Font = Enum.Font.Gotham; bc.TextScaled = true
        table.insert(InspectorLabels, bb)
        task.delay(10, function() ClearInspectorHighlights() end)
    end)

    -- Painel
    local o = 0
    local function AL(l, v, c) if v and v ~= "" then o=o+1; CreateInfoLine(InspectorContentFrame, l, v, c, o) end end
    local function AddSep() o=o+1; local s=Instance.new("Frame",InspectorContentFrame); s.Size=UDim2.new(1,-10,0,1); s.BackgroundColor3=Color3.fromRGB(50,60,80); s.BorderSizePixel=0; s.ZIndex=302; s.LayoutOrder=o end

    AL("Name:", info.Name, Color3.fromRGB(0,255,200))
    AL("Class:", info.ClassName, Color3.fromRGB(100,200,255))
    AL("Path:", info.ParentChain, Color3.fromRGB(180,180,200))
    AL("Model:", info.ModelName, Color3.fromRGB(255,200,100))
    AL("NPC:", info.IsNPC, Color3.fromRGB(255,100,100))
    AddSep()
    AL("Pos:", info.Position, Color3.fromRGB(200,220,255))
    AL("Size:", info.Size, Color3.fromRGB(200,220,255))
    AL("Material:", info.Material, Color3.fromRGB(180,200,220))
    AL("Color:", info.Color, Color3.fromRGB(180,200,220))
    AL("Transp:", info.Transparency, Color3.fromRGB(180,200,220))
    AL("Anchored:", info.Anchored, info.Anchored=="true" and Color3.fromRGB(0,200,100) or Color3.fromRGB(255,150,50))
    AL("Collide:", info.CanCollide, info.CanCollide=="true" and Color3.fromRGB(0,200,100) or Color3.fromRGB(255,150,50))
    AL("Mass:", info.Mass, Color3.fromRGB(180,200,220))
    AL("Velocity:", info.Velocity, Color3.fromRGB(255,200,100))
    AL("MeshId:", info.MeshId, Color3.fromRGB(150,170,200))
    AddSep()
    AL("Children:", info.ChildCount, Color3.fromRGB(180,200,220))
    AL("Types:", info.ChildTypes, Color3.fromRGB(150,170,200))
    AL("Scripts:", info.HasScripts, info.HasScripts=="true" and Color3.fromRGB(255,100,100) or Color3.fromRGB(100,200,100))
    AL("Values:", info.Values, Color3.fromRGB(255,220,100))
    AL("Interact:", info.Interact, Color3.fromRGB(0,255,200))
    AddSep()
    AL("FullPath:", info.FullName, Color3.fromRGB(120,140,160))

    InspectorInfoPanel.Visible = true

    -- Log no console mobile
    local logMsg = "Name: "..(info.Name or "?").." | Class: "..(info.ClassName or "?").."\nPath: "..(info.FullName or "?")
    if info.Position then logMsg = logMsg.."\nPos: "..info.Position end
    if info.Size then logMsg = logMsg.." | Size: "..info.Size end
    if info.Material then logMsg = logMsg.."\nMat: "..info.Material end
    if info.CanCollide then logMsg = logMsg.." | Col: "..info.CanCollide end
    if info.HasScripts then logMsg = logMsg.." | Scripts: "..info.HasScripts end
    if info.Values then logMsg = logMsg.."\nValues: "..info.Values end
    if info.Interact then logMsg = logMsg.."\nInteract: "..info.Interact end
    if info.IsNPC then logMsg = logMsg.."\nNPC: "..info.IsNPC end

    ConsoleLog("INSPECT", info.Name or "Object", logMsg)
end

local function ProcessInspectorInput(screenPosition)
    if not Config.TouchInspector then return end
    pcall(function()
        local ray = Camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
        local params = RaycastParams.new(); params.FilterDescendantsInstances = {LocalPlayer.Character}; params.FilterType = Enum.RaycastFilterType.Exclude
        local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
        if result and result.Instance then
            ShowObjectInfo(result.Instance, screenPosition)
        else
            ClearInspectorPanel(); ClearInspectorHighlights()
            ConsoleLog("INFO", "Inspector", "No object at touch point")
        end
    end)
end

local function StartTouchInspector()
    if TouchInspectorActive then return end; TouchInspectorActive = true
    if InspectorTouchIndicator then InspectorTouchIndicator.Visible = true end
    if TouchInspectorConnection then pcall(function() TouchInspectorConnection:Disconnect() end) end
    TouchInspectorConnection = UserInputService.InputEnded:Connect(function(input, gpe)
        if not Config.TouchInspector or gpe then return end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local pos = input.Position
            ProcessInspectorInput(pos)
            if InspectorTouchIndicator then
                InspectorTouchIndicator.Position = UDim2.new(0, pos.X - 20, 0, pos.Y - 20)
                InspectorTouchIndicator.Visible = true
                task.spawn(function()
                    for i = 1, 3 do
                        if not InspectorTouchIndicator then break end
                        InspectorTouchIndicator.Size = UDim2.new(0, 50, 0, 50)
                        InspectorTouchIndicator.Position = UDim2.new(0, pos.X - 25, 0, pos.Y - 25)
                        task.wait(0.08)
                        InspectorTouchIndicator.Size = UDim2.new(0, 40, 0, 40)
                        InspectorTouchIndicator.Position = UDim2.new(0, pos.X - 20, 0, pos.Y - 20)
                        task.wait(0.08)
                    end
                end)
            end
        end
    end)
    ConsoleLog("SUCCESS", "Inspector", "Touch Inspector activated! Tap objects to inspect.")
    Xan.Notify({Title="Touch Inspector", Content="Tap anywhere to inspect!", Type="Success"})
end

local function StopTouchInspector()
    TouchInspectorActive = false
    if TouchInspectorConnection then pcall(function() TouchInspectorConnection:Disconnect() end); TouchInspectorConnection = nil end
    ClearInspectorHighlights(); ClearInspectorPanel()
    if InspectorInfoPanel then InspectorInfoPanel.Visible = false end
    if InspectorTouchIndicator then InspectorTouchIndicator.Visible = false end
    ConsoleLog("INFO", "Inspector", "Touch Inspector deactivated.")
end

--------------------------------------------------------------------------------
-- XRAY, THREAT AI, GOD MODE, FLY (Compactados)
--------------------------------------------------------------------------------

local function CreateXrayIndicator()
    if XrayIndicatorGui then pcall(function() XrayIndicatorGui:Destroy() end) end
    XrayIndicatorGui = Instance.new("ScreenGui"); XrayIndicatorGui.Name="XrayGui"; XrayIndicatorGui.ResetOnSpawn=false; XrayIndicatorGui.DisplayOrder=190; XrayIndicatorGui.Parent=UserGui
    local f=Instance.new("Frame",XrayIndicatorGui); f.Name="XF"; f.Size=UDim2.new(0,180,0,32); f.Position=UDim2.new(0.5,-90,0,55); f.BackgroundColor3=Color3.fromRGB(0,80,180); f.BackgroundTransparency=0.2; f.BorderSizePixel=0; f.Visible=false; f.ZIndex=190
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    Instance.new("UIStroke",f).Color=Color3.fromRGB(0,160,255)
    local ic=Instance.new("TextLabel",f); ic.Size=UDim2.new(0,28,1,0); ic.Position=UDim2.new(0,4,0,0); ic.BackgroundTransparency=1; ic.Text="👁"; ic.TextSize=16; ic.ZIndex=191
    XrayIndicatorLabel=Instance.new("TextLabel",f); XrayIndicatorLabel.Size=UDim2.new(1,-34,1,0); XrayIndicatorLabel.Position=UDim2.new(0,32,0,0); XrayIndicatorLabel.BackgroundTransparency=1; XrayIndicatorLabel.Text="XRAY"; XrayIndicatorLabel.TextColor3=Color3.fromRGB(200,230,255); XrayIndicatorLabel.TextSize=11; XrayIndicatorLabel.Font=Enum.Font.GothamBold; XrayIndicatorLabel.TextXAlignment=Enum.TextXAlignment.Left; XrayIndicatorLabel.ZIndex=191
    return f
end
local XrayIndicatorFrame = CreateXrayIndicator()

local function CheckIfUnderground()
    local c=LocalPlayer.Character; if not c then return false,0 end; local r=c:FindFirstChild("HumanoidRootPart"); if not r then return false,0 end
    local p=RaycastParams.new(); p.FilterDescendantsInstances={c}; p.FilterType=Enum.RaycastFilterType.Exclude
    local u=workspace:Raycast(r.Position,Vector3.new(0,500,0),p)
    if u and u.Instance then local h=u.Instance; local isF=false
        if h:IsA("Terrain") then isF=true elseif h:IsA("BasePart") then if (h.Size.X>10 and h.Size.Z>10) or h.Size.Magnitude>30 then isF=true end; local ln=h.Name:lower(); if ln:find("floor") or ln:find("ground") or ln:find("terrain") or ln:find("base") or ln:find("part") then isF=true end end
        if isF and (u.Position-r.Position).Magnitude>2 then return true,u.Position.Y end
    end; return false,0
end

local function RestoreAllTransparency() for p in pairs(TransparentParts) do pcall(function() if p and p.Parent and OriginalTransparency[p] then p.Transparency=OriginalTransparency[p] end end) end; TransparentParts={}; OriginalTransparency={} end

local function StartUndergroundXray()
    if UndergroundXrayActive then return end; UndergroundXrayActive=true; XrayFrameCounter=0
    if XrayConnection then pcall(function() XrayConnection:Disconnect() end) end
    XrayConnection=RunService.Heartbeat:Connect(function()
        if not UndergroundXrayActive then return end; XrayFrameCounter=XrayFrameCounter+1; if XrayFrameCounter%XRAY_CHECK_INTERVAL~=0 then return end
        local c=LocalPlayer.Character; if not c then return end; local root=c:FindFirstChild("HumanoidRootPart"); if not root then return end
        local ug,sY=CheckIfUnderground()
        if ug and not IsUnderground then IsUnderground=true; if XrayIndicatorFrame then XrayIndicatorFrame.Visible=true end
        elseif not ug and IsUnderground then IsUnderground=false; RestoreAllTransparency(); if XrayIndicatorFrame then XrayIndicatorFrame.Visible=false end end
        if not IsUnderground then return end
        local pPos,pY=root.Position,root.Position.Y
        pcall(function() for _,obj in pairs(workspace:GetDescendants()) do if not obj:IsA("BasePart") then continue end
            local dist=(obj.Position-pPos).Magnitude; if dist>XRAY_RADIUS then if TransparentParts[obj] then pcall(function() if OriginalTransparency[obj] then obj.Transparency=OriginalTransparency[obj] end end); TransparentParts[obj]=nil; OriginalTransparency[obj]=nil end; continue end
            local ch=LocalPlayer.Character; if ch and obj:IsDescendantOf(ch) then continue end; local isB=false
            local pB=obj.Position.Y-(obj.Size.Y/2); if pB>pY and pB<sY+50 then if (obj.Size.X>3 and obj.Size.Z>3) or obj.Size.Magnitude>15 then isB=true end end
            if isB then if not TransparentParts[obj] then pcall(function() if not OriginalTransparency[obj] then OriginalTransparency[obj]=obj.Transparency end; if obj.Transparency<XRAY_TRANSPARENCY then obj.Transparency=XRAY_TRANSPARENCY; TransparentParts[obj]=true end end) end
            else if TransparentParts[obj] then pcall(function() if OriginalTransparency[obj] then obj.Transparency=OriginalTransparency[obj] end end); TransparentParts[obj]=nil; OriginalTransparency[obj]=nil end end
        end end)
        if XrayIndicatorLabel then local cnt=0; for _ in pairs(TransparentParts) do cnt=cnt+1 end; pcall(function() XrayIndicatorLabel.Text="XRAY: "..cnt.." | Depth: "..math.floor(sY-pY).."m" end) end
    end)
end
local function StopUndergroundXray() UndergroundXrayActive=false; IsUnderground=false; if XrayConnection then pcall(function() XrayConnection:Disconnect() end); XrayConnection=nil end; RestoreAllTransparency(); if XrayIndicatorFrame then XrayIndicatorFrame.Visible=false end end

-- Threat AI
local TP={Critical={"tsunami","megawave","giantwave","tidal","superwave","deathwave","killwave","nuke","apocalypse"},High={"wave","flood","lava","fire","explosion","bomb","missile","laser","beam","blast","meteor","tornado","storm","earthquake","volcano","surge","tide","onda","tempestade"},Medium={"projectile","bullet","arrow","spike","trap","hazard","poison","acid","boulder","debris","attack","damage","kill","death","burn"},Low={"water","rain","splash","wind","dust","smoke","fog"}}
local TB={HV=30,LS=40,MS=150,NR=500}

local function CTN(n) local l=n:lower(); for _,p in pairs(TP.Critical) do if l:find(p) then return 4 end end; for _,p in pairs(TP.High) do if l:find(p) then return 3 end end; for _,p in pairs(TP.Medium) do if l:find(p) then return 2 end end; for _,p in pairs(TP.Low) do if l:find(p) then return 1 end end; return 0 end

local function NT(p) if not p or NeutralizedParts[p] then return end; NeutralizedParts[p]=true; pcall(function() p.CanCollide=false; p.CanTouch=false; if FlyNoclipGroupCreated then p.CollisionGroup=FLY_NOCLIP_GROUP end end)
    if p.Parent and p.Parent:IsA("Model") then pcall(function() for _,s in pairs(p.Parent:GetDescendants()) do if s:IsA("BasePart") and not NeutralizedParts[s] then NeutralizedParts[s]=true; s.CanCollide=false; s.CanTouch=false end end end) end
end

local function StartThreatAI()
    if ThreatAIActive then return end; ThreatAIActive=true
    if ThreatAIConnection then pcall(function() ThreatAIConnection:Disconnect() end) end
    local fc=0; ThreatAIConnection=RunService.Heartbeat:Connect(function()
        if not ThreatAIActive then return end; fc=fc+1; if fc%5~=0 then return end
        local ch=LocalPlayer.Character; if not ch then return end; local rt=ch:FindFirstChild("HumanoidRootPart"); if not rt then return end; local pp=rt.Position
        pcall(function() for _,o in pairs(workspace:GetDescendants()) do if not o:IsA("BasePart") or o:IsDescendantOf(ch) then continue end
            local d=(o.Position-pp).Magnitude; if d>TB.NR then continue end
            local ts=CTN(o.Name)+(o.Parent and CTN(o.Parent.Name) or 0)
            local v=Vector3.zero; pcall(function() v=o.AssemblyLinearVelocity or Vector3.zero end)
            if v.Magnitude>TB.HV then ts=ts+2 end; if o.Size.Magnitude>TB.MS then ts=ts+3 elseif o.Size.Magnitude>TB.LS then ts=ts+1 end
            if v.Magnitude>5 then local dir=(pp-o.Position); if dir.Magnitude>0.01 and dir.Unit:Dot(v.Unit)>0.3 then ts=ts+2; if d/v.Magnitude<3 then ts=ts+3 end end end
            if o.Size.Magnitude>30 and v.Magnitude>3 and d<200 then ts=math.max(ts,4) end
            if ts>=2 then NT(o) end
        end end)
    end)
    if WorldNoclipConnection then pcall(function() WorldNoclipConnection:Disconnect() end) end
    WorldNoclipConnection=workspace.DescendantAdded:Connect(function(o)
        if not ThreatAIActive then return end; task.defer(function()
            if not o or not o:IsA("BasePart") then return end; local ch=LocalPlayer.Character; if not ch or o:IsDescendantOf(ch) then return end
            if CTN(o.Name)+(o.Parent and CTN(o.Parent.Name) or 0)>=1 then NT(o); return end
            task.delay(0.5,function() if not o or not o.Parent then return end; pcall(function() local v=o.AssemblyLinearVelocity or Vector3.zero; if v.Magnitude>TB.HV or o.Size.Magnitude>TB.LS then NT(o) end end) end)
            pcall(function() local cn=o.Touched:Connect(function(h) if not ThreatAIActive then return end; if h and ch and h:IsDescendantOf(ch) then NT(o); local hm=ch:FindFirstChild("Humanoid"); if hm then hm.Health=hm.MaxHealth end end end); table.insert(TouchedConnections,cn) end)
        end)
    end)
end
local function StopThreatAI() ThreatAIActive=false; if ThreatAIConnection then pcall(function() ThreatAIConnection:Disconnect() end); ThreatAIConnection=nil end; if WorldNoclipConnection then pcall(function() WorldNoclipConnection:Disconnect() end); WorldNoclipConnection=nil end; for _,c in pairs(TouchedConnections) do pcall(function() c:Disconnect() end) end; TouchedConnections={}; NeutralizedParts={} end

-- God Mode
local function FNC() local c=LocalPlayer.Character; if not c then return end; for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
local function FGM() local c=LocalPlayer.Character; if not c then return end; local h=c:FindFirstChild("Humanoid"); if h and h.Health~=h.MaxHealth then h.Health=h.MaxHealth end end

local function EnableFlyGodMode()
    if FlyGodModeActive then return end; FlyGodModeActive=true
    local ch=LocalPlayer.Character; if not ch then return end; local hum=ch:FindFirstChild("Humanoid"); if not hum then return end
    hum.Health=hum.MaxHealth
    if HealthConnection then pcall(function() HealthConnection:Disconnect() end) end
    HealthConnection=hum.HealthChanged:Connect(function() if FlyGodModeActive and hum then hum.Health=hum.MaxHealth end end)
    pcall(function() if not ch:FindFirstChild("FlyForceField") then ForceFieldInstance=Instance.new("ForceField"); ForceFieldInstance.Name="FlyForceField"; ForceFieldInstance.Visible=false; ForceFieldInstance.Parent=ch end end)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead,false); hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false); hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false); hum:SetStateEnabled(Enum.HumanoidStateType.Physics,false) end)
    pcall(function() AssignCharToNoclipGroup(ch) end)
    if GodModeSteppedConnection then pcall(function() GodModeSteppedConnection:Disconnect() end) end
    GodModeSteppedConnection=RunService.Stepped:Connect(function() if not FlyGodModeActive then return end; FNC(); FGM() end)
    if GodModeRenderConnection then pcall(function() GodModeRenderConnection:Disconnect() end) end
    GodModeRenderConnection=RunService.RenderStepped:Connect(function() if not FlyGodModeActive then return end; FNC() end)
    if GodModeHeartbeatConnection then pcall(function() GodModeHeartbeatConnection:Disconnect() end) end
    GodModeHeartbeatConnection=RunService.Heartbeat:Connect(function() if not FlyGodModeActive then return end; FNC(); FGM()
        local r=ch:FindFirstChild("HumanoidRootPart"); if r and BodyVel then r.AssemblyLinearVelocity=BodyVel.Velocity; r.AssemblyAngularVelocity=Vector3.zero end
        local h=ch:FindFirstChild("Humanoid"); if h then local s=h:GetState(); if s==Enum.HumanoidStateType.Dead or s==Enum.HumanoidStateType.FallingDown or s==Enum.HumanoidStateType.Ragdoll or s==Enum.HumanoidStateType.Physics then h:ChangeState(Enum.HumanoidStateType.Running) end end end)
    local cc=ch.DescendantAdded:Connect(function(o) if not FlyGodModeActive then return end; if o:IsA("BasePart") then task.defer(function() pcall(function() o.CanCollide=false; if FlyNoclipGroupCreated then o.CollisionGroup=FLY_NOCLIP_GROUP end end) end) end end)
    table.insert(ChildAddedConnections,cc)
    StartThreatAI(); StartUndergroundXray()
    ConsoleLog("SUCCESS","God Mode","All protection systems activated")
end

local function DisableFlyGodMode()
    if not FlyGodModeActive then return end; FlyGodModeActive=false
    StopThreatAI(); StopUndergroundXray()
    if HealthConnection then pcall(function() HealthConnection:Disconnect() end); HealthConnection=nil end
    if GodModeSteppedConnection then pcall(function() GodModeSteppedConnection:Disconnect() end); GodModeSteppedConnection=nil end
    if GodModeRenderConnection then pcall(function() GodModeRenderConnection:Disconnect() end); GodModeRenderConnection=nil end
    if GodModeHeartbeatConnection then pcall(function() GodModeHeartbeatConnection:Disconnect() end); GodModeHeartbeatConnection=nil end
    for _,c in pairs(ChildAddedConnections) do pcall(function() c:Disconnect() end) end; ChildAddedConnections={}
    if ForceFieldInstance then pcall(function() ForceFieldInstance:Destroy() end); ForceFieldInstance=nil end
    local ch=LocalPlayer.Character; if ch then
        pcall(function() local ff=ch:FindFirstChild("FlyForceField"); if ff then ff:Destroy() end end)
        RestoreCharCollisionGroup(ch)
        for _,p in pairs(ch:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=true end) end end
        local h=ch:FindFirstChild("Humanoid"); if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead,true); h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,true); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,true); h:SetStateEnabled(Enum.HumanoidStateType.Physics,true) end) end
    end
    ConsoleLog("INFO","God Mode","All protection systems deactivated")
end

-- Fly
local function StartFly()
    local ch=LocalPlayer.Character; if not ch then return end; local r=ch:FindFirstChild("HumanoidRootPart"); local h=ch:FindFirstChild("Humanoid"); if not r or not h then return end
    IsFlying=true; if BodyVel then pcall(function() BodyVel:Destroy() end) end; if BodyGyro then pcall(function() BodyGyro:Destroy() end) end
    BodyVel=Instance.new("BodyVelocity"); BodyVel.Name="DHFlyVel"; BodyVel.MaxForce=Vector3.new(math.huge,math.huge,math.huge); BodyVel.Velocity=Vector3.zero; BodyVel.P=1250; BodyVel.Parent=r
    BodyGyro=Instance.new("BodyGyro"); BodyGyro.Name="DHFlyGyro"; BodyGyro.MaxTorque=Vector3.new(math.huge,math.huge,math.huge); BodyGyro.P=9e4; BodyGyro.D=500; BodyGyro.CFrame=Camera.CFrame; BodyGyro.Parent=r
    h.PlatformStand=true; EnableFlyGodMode()
    if IsAndroid and FlyControlFrame then FlyControlFrame.Visible=true end
    ConsoleLog("SUCCESS","Fly","Flight activated with all protections")
end

local function StopFly()
    IsFlying=false; DisableFlyGodMode()
    local ch=LocalPlayer.Character; if ch then local h=ch:FindFirstChild("Humanoid"); if h then h.PlatformStand=false end end
    if BodyVel then pcall(function() BodyVel:Destroy() end); BodyVel=nil end; if BodyGyro then pcall(function() BodyGyro:Destroy() end); BodyGyro=nil end
    AndroidUpPressed=false; AndroidDownPressed=false
    if IsAndroid and FlyControlFrame then FlyControlFrame.Visible=false end
end

local function GetFlyVelocity()
    local cam=Camera.CFrame; local md=Vector3.zero
    if IsAndroid then
        local ch=LocalPlayer.Character; local h=ch and ch:FindFirstChild("Humanoid")
        if h and h.MoveDirection.Magnitude>0.1 then
            local cL,cR=cam.LookVector,cam.RightVector
            local fL=Vector3.new(cL.X,0,cL.Z); if fL.Magnitude>0.01 then fL=fL.Unit end
            local fR=Vector3.new(cR.X,0,cR.Z); if fR.Magnitude>0.01 then fR=fR.Unit end
            md=md+cam.LookVector*fL:Dot(h.MoveDirection)+cam.RightVector*fR:Dot(h.MoveDirection)
        end
        if AndroidUpPressed then md=md+Vector3.new(0,1,0) end; if AndroidDownPressed then md=md+Vector3.new(0,-1,0) end
    else
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md=md+cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md=md-cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md=md-cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md=md+cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then md=md+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md=md+Vector3.new(0,-1,0) end
    end
    if md.Magnitude>0.01 then md=md.Unit else md=Vector3.zero end; return md*Config.FlySpeed
end

--------------------------------------------------------------------------------
-- WINDOW
--------------------------------------------------------------------------------

local function InitializeWindow()
    pcall(function() Xan.Splash({Title="DEVS HUB",Subtitle=IsAndroid and "Inicializando..." or "System Initialization...",Duration=IsAndroid and 1 or 2,Theme="Midnight"}) end)
    local GN="Unknown Game"; local GI=Xan.Logos.Default
    task.spawn(function() pcall(function() GN=MarketplaceService:GetProductInfo(game.PlaceId).Name end)
        local s,r=pcall(function() local req=(syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request; if req then return req({Url="https://api.xan.bar/api/games/lookup?name="..HttpService:UrlEncode(GN),Method="GET"}) end end)
        if s and r and r.StatusCode==200 then local d=HttpService:JSONDecode(r.Body); if d.success and d.game then GI=d.game.backup_rbxasset or d.game.rbxthumb end elseif Xan.GameIcons[GN] then GI=Xan.GameIcons[GN] end
    end)
    task.wait(IsAndroid and 1.5 or 2.2)
    local s,e=pcall(function() Window=Xan:CreateWindow({Title="DEVS HUB",Subtitle=GN,Theme="Midnight",Size=IsAndroid and UDim2.new(0.9,0,0.9,0) or UDim2.new(0,580,0,450),ShowActiveList=not IsAndroid,ShowLogo=true,Logo=GI,ConfigName="DevsHub"}) end)
    if not s or not Window then return false end
    pcall(function() Xan.MobileToggle({Window=Window,Position=UDim2.new(0.85,0,0.1,0),Visible=true}) end)
    return true
end

task.wait(0.5); if not InitializeWindow() then return end

--------------------------------------------------------------------------------
-- TABS
--------------------------------------------------------------------------------

local MainTab=Window:AddTab("Main",Xan.Icons.Home)
local ConfigTab=Window:AddTab("Config",Xan.Icons.Settings)
local PlayerTab=Window:AddTab("Player",Xan.Icons.Person)
local DevsTab=Window:AddTab("Devs",Xan.Icons.Code)

-- COMBAT
MainTab:AddSection("Combat")
local AimToggle=MainTab:AddToggle("Aimlock","aim_state",function(v) Config.Aimlock=v end)
MainTab:AddKeybind("Aimlock [G]","aim_key",Enum.KeyCode.G,function() AimToggle:Set(not AimToggle.Value()) end)
MainTab:AddSlider("Aim FOV","aim_fov",{Min=100,Max=2000,Default=1000},function(v) Config.AimRange=v end)
MainTab:AddCharacterPreview({Name="Hitbox",HitboxParts={"Head","Chest","Arms","Legs"},Default={Head=true,Chest=true},Callback=function(v) Config.HitParts=v end})

-- VISUALS
MainTab:AddSection("Visuals")
local EspToggle=MainTab:AddToggle("X-Ray (Chams)","esp_state",function(v) Config.ESP=v; if not v then for _,o in pairs(Objects) do if o.Name=="HLCache" then pcall(function() o:Destroy() end) end end; return end; for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character and not p.Character:FindFirstChild("HLCache") then pcall(function() local h=Instance.new("Highlight"); h.Name="HLCache"; h.FillColor=Color3.fromRGB(255,0,0); h.OutlineColor=Color3.new(1,1,1); h.FillTransparency=0.5; h.Parent=p.Character; table.insert(Objects,h) end) end end end)
MainTab:AddKeybind("X-Ray [H]","esp_key",Enum.KeyCode.H,function() EspToggle:Set(not EspToggle.Value()) end)
MainTab:AddCrosshair("Crosshair",{Enabled=false})

-- MOVEMENT
MainTab:AddSection("Movement")
local FlightTog=MainTab:AddToggle("Fly Hack","fly_hack",function(v) Config.Fly=v; if v then Xan.Notify({Title="Flight",Content="ALL SYSTEMS ON!",Type="Success"}) else Xan.Notify({Title="Flight",Content="All OFF",Type="Info"}) end end)
MainTab:AddKeybind("Fly [F]","fly_key",Enum.KeyCode.F,function() FlightTog:Set(not FlightTog.Value()) end)
MainTab:AddSlider("Fly Speed","fly_val",{Min=10,Max=700,Default=50},function(v) Config.FlySpeed=v end)
local SpeedTog=MainTab:AddToggle("Speed Hack","speed_hack",function(v) Config.SpeedHack=v; if not v and LocalPlayer.Character then pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed=16 end) end end)
MainTab:AddKeybind("Speed [J]","speed_key",Enum.KeyCode.J,function() SpeedTog:Set(not SpeedTog.Value()) end)
MainTab:AddSlider("Walk Speed","speed_val",{Min=16,Max=300,Default=16},function(v) Config.WalkSpeed=v end)
local JumpTog=MainTab:AddToggle("Jump Hack","jump_hack",function(v) Config.JumpHack=v; if not v and LocalPlayer.Character then pcall(function() LocalPlayer.Character.Humanoid.JumpPower=50 end) end end)
MainTab:AddKeybind("Jump [K]","jump_key",Enum.KeyCode.K,function() JumpTog:Set(not JumpTog.Value()) end)
MainTab:AddSlider("Jump Power","jump_val",{Min=50,Max=500,Default=50},function(v) Config.JumpPower=v end)
local NoclipTog=MainTab:AddToggle("No Clip","noclip_hack",function(v) Config.Noclip=v end)
MainTab:AddKeybind("Noclip [N]","noclip_key",Enum.KeyCode.N,function() NoclipTog:Set(not NoclipTog.Value()) end)
local InfJumpTog=MainTab:AddToggle("Inf Jump","inf_jump",function(v) Config.InfJump=v end)
MainTab:AddKeybind("InfJump [L]","inf_jump_key",Enum.KeyCode.L,function() InfJumpTog:Set(not InfJumpTog.Value()) end)

-- TELEPORT
MainTab:AddSection("Teleport")
local function GPN() local n={}; for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer then table.insert(n,p.Name) end end; table.sort(n); if #n==0 then table.insert(n,"None") end; return n end
local TpDrop=MainTab:AddDropdown("Player","tp_target",GPN(),function(v) Config.TargetPlr=Players:FindFirstChild(v) end)
Connections["PA"]=Players.PlayerAdded:Connect(function() TpDrop:SetOptions(GPN()) end)
Connections["PR"]=Players.PlayerRemoving:Connect(function() TpDrop:SetOptions(GPN()) end)
MainTab:AddButton("Refresh",function() TpDrop:SetOptions(GPN()) end)
MainTab:AddButton("Teleport [U]",function() if Config.TargetPlr and Config.TargetPlr.Character then LocalPlayer.Character:SetPrimaryPartCFrame(Config.TargetPlr.Character.HumanoidRootPart.CFrame*CFrame.new(0,0,4)); Xan.Notify({Title="TP",Content="To "..Config.TargetPlr.Name}) end end)
MainTab:AddSpeedometer("HUD Speed",{Min=0,Max=200,AutoTrack=true})

-- PLAYER
PlayerTab:AddSection("Character")
PlayerTab:AddButton("Reset Speed",function() if LocalPlayer.Character then pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed=16 end) end end)
PlayerTab:AddButton("Reset Jump",function() if LocalPlayer.Character then pcall(function() LocalPlayer.Character.Humanoid.JumpPower=50 end) end end)
PlayerTab:AddButton("Reset All",function() if LocalPlayer.Character then local h=LocalPlayer.Character:FindFirstChild("Humanoid"); if h then h.WalkSpeed=16;h.JumpPower=50;h.PlatformStand=false end end end)
PlayerTab:AddSection("Equipment")
PlayerTab:AddButton("Remove Tools",function() if LocalPlayer.Backpack then for _,t in pairs(LocalPlayer.Backpack:GetChildren()) do if t:IsA("Tool") then t:Destroy() end end end end)
PlayerTab:AddButton("Drop Tools",function() if LocalPlayer.Backpack then for _,t in pairs(LocalPlayer.Backpack:GetChildren()) do if t:IsA("Tool") then t.Parent=workspace end end end end)
PlayerTab:AddSection("Health")
PlayerTab:AddButton("Heal",function() if LocalPlayer.Character then local h=LocalPlayer.Character:FindFirstChild("Humanoid"); if h then h.Health=h.MaxHealth end end end)
PlayerTab:AddSlider("Health %","health_val",{Min=1,Max=100,Default=100},function(v) if LocalPlayer.Character and not FlyGodModeActive then local h=LocalPlayer.Character:FindFirstChild("Humanoid"); if h then h.Health=(h.MaxHealth/100)*v end end end)
PlayerTab:AddSection("Theft")
PlayerTab:AddToggle("Steal Speed","steal_hack",function(v) Config.StealSpeed=v end)
PlayerTab:AddSlider("Steal Multi","steal_mult",{Min=1,Max=10,Default=2},function(v) Config.StealMultiplier=v end)
PlayerTab:AddSection("Positions")
PlayerTab:AddButton("Save Pos 1",function() if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then Config.SavedPos1=LocalPlayer.Character.HumanoidRootPart.CFrame; ConsoleLog("SUCCESS","Position","Pos 1 saved") end end)
PlayerTab:AddButton("Save Pos 2",function() if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then Config.SavedPos2=LocalPlayer.Character.HumanoidRootPart.CFrame; ConsoleLog("SUCCESS","Position","Pos 2 saved") end end)
PlayerTab:AddButton("TP Pos 1",function() if Config.SavedPos1 and LocalPlayer.Character then LocalPlayer.Character:SetPrimaryPartCFrame(Config.SavedPos1) end end)
PlayerTab:AddButton("TP Pos 2",function() if Config.SavedPos2 and LocalPlayer.Character then LocalPlayer.Character:SetPrimaryPartCFrame(Config.SavedPos2) end end)

-- DEVS TAB
DevsTab:AddSection("Credits")
DevsTab:AddLabel("DEVS HUB v1.5"); DevsTab:AddLabel("by mecharena1"); DevsTab:AddDivider()
DevsTab:AddSection("Systems")
DevsTab:AddLabel("AI: Threat Detection v1.0")
DevsTab:AddLabel("XRay: Underground Vision v1.0")
DevsTab:AddLabel("Inspector: Touch v1.0")
DevsTab:AddLabel("Console: Mobile Log v1.0")
DevsTab:AddDivider()

DevsTab:AddSection("Touch Inspector")
DevsTab:AddToggle("Touch Inspector","touch_insp",function(v) Config.TouchInspector=v; if v then StartTouchInspector() else StopTouchInspector() end end)
DevsTab:AddLabel("Tap objects to see full info")
DevsTab:AddLabel("Info: Name, Class, Position, Size")
DevsTab:AddLabel("Material, Color, Scripts, Values")
DevsTab:AddButton("Clear Inspector",function() ClearInspectorHighlights(); ClearInspectorPanel(); if InspectorInfoPanel then InspectorInfoPanel.Visible=false end; ConsoleLog("INFO","Inspector","Cleared") end)
DevsTab:AddDivider()

DevsTab:AddSection("Mobile Console")
DevsTab:AddLabel("📋 Tap the clipboard icon to open")
DevsTab:AddLabel("All logs appear in console")
DevsTab:AddButton("Test Log",function() ConsoleLog("INFO","Test","This is a test log entry!") end)
DevsTab:AddButton("Clear Console",function() for _,e in pairs(ConsoleLogEntries) do pcall(function() e:Destroy() end) end; ConsoleLogEntries={} end)
DevsTab:AddDivider()

DevsTab:AddSection("Debug")
DevsTab:AddToggle("Debug Logger","debug_action",function(v) Config.DebugEnabled=v; ConsoleLog(v and "SUCCESS" or "INFO","Debug",v and "Press E to log raycast" or "Disabled") end)
DevsTab:AddLabel("Press E to log target info")

-- CONFIG
ConfigTab:AddInput("Config Name",{Flag="cfg_name",Default="default"})
ConfigTab:AddButton("Save",function() Xan:SaveConfig(Xan.Flags["cfg_name"] or "default") end)
ConfigTab:AddButton("Load",function() Xan:LoadConfig(Xan.Flags["cfg_name"] or "default") end)
ConfigTab:AddDivider()
ConfigTab:AddButton("Unload",function()
    StopFly(); StopThreatAI(); StopUndergroundXray(); StopTouchInspector()
    for _,c in pairs(Connections) do pcall(function() c:Disconnect() end) end
    for _,o in pairs(Objects) do pcall(function() o:Destroy() end) end
    if FlyControlFrame then pcall(function() FlyControlFrame.Parent:Destroy() end) end
    if AndroidButtonFrame then pcall(function() AndroidButtonFrame:Destroy() end) end
    if ThreatAlertGui then pcall(function() ThreatAlertGui:Destroy() end) end
    if XrayIndicatorGui then pcall(function() XrayIndicatorGui:Destroy() end) end
    if InspectorPanelGui then pcall(function() InspectorPanelGui:Destroy() end) end
    if MobileConsoleGui then pcall(function() MobileConsoleGui:Destroy() end) end
    if LocalPlayer.Character then local h=LocalPlayer.Character:FindFirstChild("Humanoid"); if h then h.PlatformStand=false;h.WalkSpeed=16;h.JumpPower=50 end end
    pcall(function() Xan:Unload() end)
end)

--------------------------------------------------------------------------------
-- LOOPS
--------------------------------------------------------------------------------

Connections["Loop"]=RunService.Stepped:Connect(function()
    local ch=LocalPlayer.Character; if not ch then return end; local hum=ch:FindFirstChild("Humanoid"); local root=ch:FindFirstChild("HumanoidRootPart"); if not hum or not root then return end
    if Config.Noclip and not Config.Fly then for _,p in pairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    if Config.SpeedHack and not Config.Fly then hum.WalkSpeed=Config.WalkSpeed end
    if Config.JumpHack then hum.UseJumpPower=true; hum.JumpPower=Config.JumpPower end
    if Config.Fly then
        if not IsFlying then StartFly() end
        if not BodyVel or not BodyVel.Parent or not BodyGyro or not BodyGyro.Parent then StopFly(); StartFly() end
        if BodyVel and BodyGyro then BodyGyro.CFrame=Camera.CFrame; BodyVel.Velocity=GetFlyVelocity(); if FlySpeedLabel then pcall(function() FlySpeedLabel.Text=tostring(math.floor(Config.FlySpeed)) end) end end
    else if IsFlying then StopFly() end end
    if Config.StealSpeed then pcall(function() for _,r in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do if r:IsA("RemoteEvent") then local rn=r.Name:lower(); if rn:find("steal") or rn:find("rob") or rn:find("grab") or rn:find("take") or rn:find("action") then for i=1,Config.StealMultiplier do r:FireServer(); task.wait(0.05) end end end end end) end
end)

Connections["Aim"]=RunService.RenderStepped:Connect(function()
    if not Config.Aimlock then return end
    pcall(function()
        local m=UserInputService:GetMouseLocation(); local best,bd=nil,Config.AimRange
        for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health>0 then
            local pt=(Config.HitParts.Head and p.Character:FindFirstChild("Head")) or (Config.HitParts.Chest and p.Character:FindFirstChild("HumanoidRootPart")) or p.Character:FindFirstChild("Head")
            if pt then local pos,vis=Camera:WorldToViewportPoint(pt.Position); if vis then local d=(Vector2.new(pos.X,pos.Y)-m).Magnitude; if d<bd then bd=d;best=pt end end end
        end end
        if best then Camera.CFrame=CFrame.new(Camera.CFrame.Position,best.Position) end
    end)
end)

Connections["InfJump"]=UserInputService.JumpRequest:Connect(function()
    if Config.InfJump and LocalPlayer.Character then local h=LocalPlayer.Character:FindFirstChild("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
    if IsAndroid and Config.Fly and IsFlying then AndroidUpPressed=true; task.delay(0.3,function() AndroidUpPressed=false end) end
end)

Connections["Inputs"]=UserInputService.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.KeyCode==Enum.KeyCode.E and Config.DebugEnabled then
        pcall(function()
            local p=RaycastParams.new(); p.FilterDescendantsInstances={LocalPlayer.Character}; p.FilterType=Enum.RaycastFilterType.Exclude
            local r=workspace:Raycast(Camera.CFrame.Position,Camera.CFrame.LookVector*1000,p)
            if r then
                local pos=r.Position; local info=GetObjectInfo(r.Instance)
                local msg=string.format("Name: %s | Class: %s\nPos: %.1f, %.1f, %.1f\nPath: %s",info.Name or "?",info.ClassName or "?",pos.X,pos.Y,pos.Z,info.FullName or "?")
                if info.CanCollide then msg=msg.."\nCollide: "..info.CanCollide end
                if info.HasScripts then msg=msg.." | Scripts: "..info.HasScripts end
                ConsoleLog("DEBUG","Raycast Hit",msg)
                Xan.Notify({Title="Debug",Content="Logged: "..(info.Name or "?"),Type="Info"})
            else ConsoleLog("DEBUG","Raycast","No hit") end
        end)
    end
    if input.KeyCode==Enum.KeyCode.U and Config.TargetPlr and Config.TargetPlr.Character then
        pcall(function() LocalPlayer.Character:SetPrimaryPartCFrame(Config.TargetPlr.Character.HumanoidRootPart.CFrame*CFrame.new(0,0,4)); ConsoleLog("SUCCESS","Teleport","To: "..Config.TargetPlr.Name) end)
    end
end)

-- ANDROID BUTTONS
if IsAndroid and AndroidButtonFrame then
    for _,bd in pairs(TouchButtons) do local btn,name=bd.Button,bd.Name
        if name=="FlyBtn" then btn.Text="FLY"; btn.MouseButton1Click:Connect(function() FlightTog:Set(not Config.Fly) end)
        elseif name=="SpeedBtn" then btn.Text="SPD"; btn.MouseButton1Click:Connect(function() SpeedTog:Set(not Config.SpeedHack) end)
        elseif name=="AimBtn" then btn.Text="AIM"; btn.MouseButton1Click:Connect(function() AimToggle:Set(not Config.Aimlock) end)
        elseif name=="EspBtn" then btn.Text="ESP"; btn.MouseButton1Click:Connect(function() EspToggle:Set(not Config.ESP) end)
        elseif name=="TeleBtn" then btn.Text="TP"; btn.MouseButton1Click:Connect(function()
            if Config.TargetPlr and Config.TargetPlr.Character then LocalPlayer.Character:SetPrimaryPartCFrame(Config.TargetPlr.Character.HumanoidRootPart.CFrame*CFrame.new(0,0,4)) end
        end) end
    end
end

-- RESPAWN
Connections["CharAdded"]=LocalPlayer.CharacterAdded:Connect(function()
    FlyGodModeActive=false
    if HealthConnection then pcall(function() HealthConnection:Disconnect() end); HealthConnection=nil end
    if GodModeSteppedConnection then pcall(function() GodModeSteppedConnection:Disconnect() end); GodModeSteppedConnection=nil end
    if GodModeRenderConnection then pcall(function() GodModeRenderConnection:Disconnect() end); GodModeRenderConnection=nil end
    if GodModeHeartbeatConnection then pcall(function() GodModeHeartbeatConnection:Disconnect() end); GodModeHeartbeatConnection=nil end
    ForceFieldInstance=nil; OriginalCollisionGroups={}; NeutralizedParts={}
    StopThreatAI(); StopUndergroundXray(); ClearInspectorHighlights()
    if IsFlying then IsFlying=false; if BodyVel then pcall(function() BodyVel:Destroy() end); BodyVel=nil end; if BodyGyro then pcall(function() BodyGyro:Destroy() end); BodyGyro=nil end
        task.wait(1); if Config.Fly then StartFly() end
    end
    ConsoleLog("WARNING","Respawn","Character respawned")
end)

ConsoleLog("SUCCESS","DEVS HUB","All systems loaded successfully!")
Xan.Notify({Title="DEVS HUB",Content="Loaded with Console + Inspector!",Type="Success"})
