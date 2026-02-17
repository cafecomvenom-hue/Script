local Xan = loadstring(game:HttpGet("https://raw.githubusercontent.com/syncgomees-commits/Devs_Hub/refs/heads/main/init.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
    CloneCount = 0,
    Method = "Server Replicate", -- Método padrão
    ProtectClones = true,
    AutoRestore = true,
    TrackedRemotes = {},
    CapturedEvents = {},
    ClonedItems = {},
    LastGiveArgs = nil,
    LastGiveRemote = nil
}
local CloneFloatingUI = nil
local CloneMainFrame = nil
local CloneToggleRef = nil

--------------------------------------------------------------------------------
-- REMOTE INTERCEPTOR SYSTEM (Captura como o servidor dá itens)
--------------------------------------------------------------------------------

local RemoteInterceptor = {
    CapturedGiveRemotes = {},
    CapturedDropRemotes = {},
    CapturedUseRemotes = {},
    AllRemotes = {},
    IsScanning = false,
    HookedRemotes = {},
    OriginalNamecall = nil
}

-- Palavras-chave para identificar remotes de dar/equipar itens
local GIVE_KEYWORDS = {
    "give", "add", "grant", "reward", "obtain", "collect", "pickup",
    "equip", "unbox", "open", "claim", "receive", "loot", "drop",
    "spawn", "create", "buy", "purchase", "get", "acquire", "item",
    "tool", "weapon", "inventory", "backpack", "additem", "giveitem",
    "addtool", "givetool", "spawnitem", "spawntool", "crate", "box",
    "chest", "pack", "roll", "gacha", "summon", "hatch"
}

local TRADE_KEYWORDS = {
    "trade", "swap", "exchange", "transfer", "send", "give",
    "offer", "accept", "confirm", "trocar", "troca"
}

local USE_KEYWORDS = {
    "use", "activate", "open", "interact", "action", "click",
    "consume", "apply", "usar", "abrir", "ativar"
}

-- Escanear todos os remotes do jogo
local function ScanAllRemotes()
    RemoteInterceptor.AllRemotes = {}
    
    local function scanContainer(container)
        pcall(function()
            for _, obj in pairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    table.insert(RemoteInterceptor.AllRemotes, {
                        Remote = obj,
                        Name = obj.Name,
                        Path = obj:GetFullName(),
                        Type = obj.ClassName
                    })
                    
                    local nameLower = obj.Name:lower()
                    
                    for _, keyword in pairs(GIVE_KEYWORDS) do
                        if string.find(nameLower, keyword) then
                            RemoteInterceptor.CapturedGiveRemotes[obj.Name] = obj
                            break
                        end
                    end
                    
                    for _, keyword in pairs(TRADE_KEYWORDS) do
                        if string.find(nameLower, keyword) then
                            RemoteInterceptor.CapturedDropRemotes[obj.Name] = obj
                            break
                        end
                    end
                    
                    for _, keyword in pairs(USE_KEYWORDS) do
                        if string.find(nameLower, keyword) then
                            RemoteInterceptor.CapturedUseRemotes[obj.Name] = obj
                            break
                        end
                    end
                end
            end
        end)
    end
    
    scanContainer(ReplicatedStorage)
    
    pcall(function()
        local common = game:GetService("ReplicatedFirst")
        scanContainer(common)
    end)
    
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerScripts") then
            scanContainer(LocalPlayer.PlayerScripts)
        end
    end)
    
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerGui") then
            scanContainer(LocalPlayer.PlayerGui)
        end
    end)
    
    return #RemoteInterceptor.AllRemotes
end

--------------------------------------------------------------------------------
-- ADVANCED CLONE SYSTEM (Server-Side Replication)
--------------------------------------------------------------------------------

local AdvancedClone = {}

-- Método 1: Interceptar e re-disparar o remote que deu o item original
function AdvancedClone.CaptureItemGiveEvent(tool)
    if not tool then return end
    
    -- Monitorar quando um novo tool aparece no character ou backpack
    local captured = {
        ToolName = tool.Name,
        ToolClass = tool.ClassName,
        RemoteFired = nil,
        Args = nil,
        Timestamp = tick()
    }
    
    table.insert(CloneConfig.CapturedEvents, captured)
    return captured
end

-- Método 2: Hook no __namecall para capturar FireServer calls
function AdvancedClone.SetupNamecallHook()
    if RemoteInterceptor.OriginalNamecall then return end
    
    local hookFunction = hookmetamethod or hookfunction
    local getNamecallMethod = getnamecallmethod
    local checkcaller = checkcaller
    
    if not hookFunction or not getNamecallMethod then
        oldWarn("[DEVS HUB] Executor não suporta hookmetamethod - usando método alternativo")
        return false
    end
    
    pcall(function()
        RemoteInterceptor.OriginalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getNamecallMethod()
            local args = {...}
            
            if method == "FireServer" and self:IsA("RemoteEvent") then
                -- Capturar todas as chamadas FireServer
                local remoteName = self.Name:lower()
                
                -- Verificar se é um remote de dar item
                for _, keyword in pairs(GIVE_KEYWORDS) do
                    if string.find(remoteName, keyword) then
                        CloneConfig.LastGiveRemote = self
                        CloneConfig.LastGiveArgs = args
                        
                        RemoteInterceptor.HookedRemotes[self.Name] = {
                            Remote = self,
                            Args = args,
                            Timestamp = tick()
                        }
                        break
                    end
                end
            elseif method == "InvokeServer" and self:IsA("RemoteFunction") then
                local remoteName = self.Name:lower()
                
                for _, keyword in pairs(GIVE_KEYWORDS) do
                    if string.find(remoteName, keyword) then
                        CloneConfig.LastGiveRemote = self
                        CloneConfig.LastGiveArgs = args
                        
                        RemoteInterceptor.HookedRemotes[self.Name] = {
                            Remote = self,
                            Args = args,
                            Timestamp = tick()
                        }
                        break
                    end
                end
            end
            
            return RemoteInterceptor.OriginalNamecall(self, ...)
        end)
    end)
    
    return true
end

-- Método 3: Forçar persistência do clone no client
function AdvancedClone.ProtectClone(clonedTool)
    if not clonedTool then return end
    
    local toolName = clonedTool.Name
    local toolParent = clonedTool.Parent
    
    -- Monitorar remoção do tool
    local protectConnection
    protectConnection = clonedTool.AncestryChanged:Connect(function(_, newParent)
        if newParent == nil and CloneConfig.ProtectClones then
            -- Tool foi removido (provavelmente pelo servidor)
            task.delay(0.1, function()
                pcall(function()
                    -- Tentar re-clonar
                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                    local character = LocalPlayer.Character
                    
                    -- Procurar o tool original
                    local originalTool = nil
                    
                    if backpack then
                        for _, item in pairs(backpack:GetChildren()) do
                            if item:IsA("Tool") and item.Name == toolName then
                                originalTool = item
                                break
                            end
                        end
                    end
                    
                    if not originalTool and character then
                        for _, item in pairs(character:GetChildren()) do
                            if item:IsA("Tool") and item.Name == toolName then
                                originalTool = item
                                break
                            end
                        end
                    end
                    
                    if originalTool and CloneConfig.AutoRestore then
                        local restored = originalTool:Clone()
                        
                        pcall(function()
                            for attrName, attrValue in pairs(originalTool:GetAttributes()) do
                                restored:SetAttribute(attrName, attrValue)
                            end
                        end)
                        
                        restored.Parent = backpack or character
                        AdvancedClone.ProtectClone(restored)
                        
                        -- Tentar replicar no servidor
                        AdvancedClone.TryServerReplicate(restored)
                    end
                end)
            end)
        end
    end)
    
    -- Guardar referência
    table.insert(CloneConfig.ClonedItems, {
        Tool = clonedTool,
        Connection = protectConnection,
        Name = toolName,
        Protected = true
    })
    
    return protectConnection
end

-- Método 4: Tentar replicar no servidor usando remotes capturados
function AdvancedClone.TryServerReplicate(tool)
    if not tool then return false end
    
    local replicated = false
    
    -- Tentar usar o último remote capturado
    if CloneConfig.LastGiveRemote and CloneConfig.LastGiveArgs then
        pcall(function()
            local remote = CloneConfig.LastGiveRemote
            local args = CloneConfig.LastGiveArgs
            
            if remote:IsA("RemoteEvent") then
                remote:FireServer(unpack(args))
                replicated = true
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(unpack(args))
                replicated = true
            end
        end)
    end
    
    -- Tentar usar remotes de give capturados
    if not replicated then
        for name, remote in pairs(RemoteInterceptor.CapturedGiveRemotes) do
            pcall(function()
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(tool.Name)
                    replicated = true
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(tool.Name)
                    replicated = true
                end
            end)
            
            if replicated then break end
        end
    end
    
    -- Tentar remotes do hook
    if not replicated then
        for name, data in pairs(RemoteInterceptor.HookedRemotes) do
            if tick() - data.Timestamp < 300 then -- Últimos 5 minutos
                pcall(function()
                    if data.Remote:IsA("RemoteEvent") then
                        data.Remote:FireServer(unpack(data.Args))
                        replicated = true
                    elseif data.Remote:IsA("RemoteFunction") then
                        data.Remote:InvokeServer(unpack(data.Args))
                        replicated = true
                    end
                end)
            end
            
            if replicated then break end
        end
    end
    
    return replicated
end

-- Método 5: Simular uso de item (para caixas/itens que precisam ser "usados")
function AdvancedClone.SimulateUse(tool)
    if not tool then return false end
    
    local used = false
    local toolName = tool.Name:lower()
    
    -- Procurar remotes de uso
    for name, remote in pairs(RemoteInterceptor.CapturedUseRemotes) do
        pcall(function()
            if remote:IsA("RemoteEvent") then
                -- Tentar vários formatos de argumentos
                remote:FireServer(tool.Name)
                task.wait(0.1)
                remote:FireServer(tool)
                task.wait(0.1)
                remote:FireServer({Item = tool.Name})
                task.wait(0.1)
                remote:FireServer({Name = tool.Name, Action = "use"})
                used = true
            elseif remote:IsA("RemoteFunction") then
                pcall(function() remote:InvokeServer(tool.Name) end)
                task.wait(0.1)
                pcall(function() remote:InvokeServer(tool) end)
                task.wait(0.1)
                pcall(function() remote:InvokeServer({Item = tool.Name}) end)
                used = true
            end
        end)
    end
    
    -- Tentar ativar o tool diretamente
    if not used then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    -- Equipar
                    hum:EquipTool(tool)
                    task.wait(0.2)
                    -- Ativar
                    tool:Activate()
                    used = true
                end
            end
        end)
    end
    
    return used
end

-- Método 6: Deep clone com preservação total
function AdvancedClone.DeepCloneTool(originalTool)
    if not originalTool or not originalTool:IsA("Tool") then
        return nil
    end

    local clonedTool = originalTool:Clone()

    -- Preservar propriedades
    pcall(function()
        clonedTool.Name = originalTool.Name
        clonedTool.ToolTip = originalTool.ToolTip
        clonedTool.CanBeDropped = originalTool.CanBeDropped
        clonedTool.Enabled = originalTool.Enabled
        clonedTool.ManualActivationOnly = originalTool.ManualActivationOnly
        clonedTool.RequiresHandle = originalTool.RequiresHandle
    end)

    -- Copiar atributos
    pcall(function()
        for attrName, attrValue in pairs(originalTool:GetAttributes()) do
            clonedTool:SetAttribute(attrName, attrValue)
        end
    end)

    -- Copiar tags
    pcall(function()
        local CollectionService = game:GetService("CollectionService")
        for _, tag in pairs(CollectionService:GetTags(originalTool)) do
            CollectionService:AddTag(clonedTool, tag)
        end
    end)

    -- Preservar valores internos (IntValue, StringValue, etc)
    pcall(function()
        for _, child in pairs(originalTool:GetDescendants()) do
            if child:IsA("ValueBase") then
                local clonedChild = clonedTool:FindFirstChild(child.Name, true)
                if clonedChild and clonedChild:IsA("ValueBase") then
                    clonedChild.Value = child.Value
                end
            end
        end
    end)

    -- Preservar Handle properties
    pcall(function()
        local origHandle = originalTool:FindFirstChild("Handle")
        local cloneHandle = clonedTool:FindFirstChild("Handle")
        if origHandle and cloneHandle then
            cloneHandle.CanCollide = origHandle.CanCollide
            cloneHandle.Anchored = origHandle.Anchored
            cloneHandle.Transparency = origHandle.Transparency
            cloneHandle.CFrame = origHandle.CFrame
        end
    end)

    return clonedTool
end

-- Método 7: Clone completo com replicação
function AdvancedClone.FullClone(originalTool)
    if not originalTool then return nil, "No tool provided" end
    
    local clonedTool = AdvancedClone.DeepCloneTool(originalTool)
    if not clonedTool then return nil, "Clone failed" end
    
    -- Colocar no backpack
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        clonedTool.Parent = backpack
    else
        clonedTool.Parent = LocalPlayer.Character
    end
    
    -- Proteger contra remoção do servidor
    if CloneConfig.ProtectClones then
        AdvancedClone.ProtectClone(clonedTool)
    end
    
    -- Tentar replicar no servidor
    local serverReplicated = AdvancedClone.TryServerReplicate(clonedTool)
    
    return clonedTool, serverReplicated
end

--------------------------------------------------------------------------------
-- ITEM MONITOR (Captura automaticamente como itens são dados)
--------------------------------------------------------------------------------

local ItemMonitor = {}

function ItemMonitor.Start()
    -- Monitorar novos tools no Backpack
    local backpack = LocalPlayer:WaitForChild("Backpack", 10)
    if backpack then
        Connections["BackpackMonitor"] = backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                AdvancedClone.CaptureItemGiveEvent(child)
            end
        end)
    end
    
    -- Monitorar novos tools no Character
    local function watchCharacter(char)
        if not char then return end
        
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                AdvancedClone.CaptureItemGiveEvent(child)
            end
        end)
    end
    
    if LocalPlayer.Character then
        watchCharacter(LocalPlayer.Character)
    end
    
    LocalPlayer.CharacterAdded:Connect(function(char)
        watchCharacter(char)
    end)
end

--------------------------------------------------------------------------------
-- ANDROID TOUCH BUTTONS
--------------------------------------------------------------------------------

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

    UpBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidUpPressed = true
            upStroke.Color = Color3.fromRGB(120, 255, 170)
            upStroke.Transparency = 0
        end
    end)

    UpBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidUpPressed = false
            upStroke.Color = Color3.fromRGB(70, 200, 120)
            upStroke.Transparency = 0.5
        end
    end)

    DownBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidDownPressed = true
            downStroke.Color = Color3.fromRGB(255, 150, 100)
            downStroke.Transparency = 0
        end
    end)

    DownBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            AndroidDownPressed = false
            downStroke.Color = Color3.fromRGB(230, 100, 70)
            downStroke.Transparency = 0.5
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
        if hum then hum.PlatformStand = false end
    end

    if BodyVel then pcall(function() BodyVel:Destroy() end) BodyVel = nil end
    if BodyGyro then pcall(function() BodyGyro:Destroy() end) BodyGyro = nil end

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
-- CLONE TOOL FLOATING UI (Android Compatible + Advanced Clone)
--------------------------------------------------------------------------------

local function GetEquippedTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, child in pairs(char:GetChildren()) do
        if child:IsA("Tool") then return child end
    end
    return nil
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

    local frameWidth = IsAndroid and 210 or 230
    local frameHeight = IsAndroid and 290 or 280
    local fontSize = IsAndroid and 11 or 13
    local smallFont = IsAndroid and 9 or 11
    local tinyFont = IsAndroid and 8 or 10
    local btnHeight = IsAndroid and 48 or 44
    local headerHeight = IsAndroid and 40 or 36

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "CloneContainer"
    mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
    mainFrame.Position = IsAndroid 
        and UDim2.new(0.5, -frameWidth/2, 0.12, 0) 
        or UDim2.new(0.5, -frameWidth/2, 0, 100)
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

    -- Drag
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

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "📋 ADVANCED CLONE"
    titleLabel.TextColor3 = Color3.fromRGB(220, 210, 255)
    titleLabel.TextSize = fontSize
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 62
    titleLabel.Parent = headerFrame

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
            if CloneToggleRef then CloneToggleRef:Set(false) end
        end)
    end)

    -- Item label
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

    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -20, 0, 16)
    statusLabel.Position = UDim2.new(0, 10, 0, headerHeight + 26)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🔴 Remotes: scanning..."
    statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
    statusLabel.TextSize = tinyFont
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 62
    statusLabel.Parent = mainFrame

    -- Count label
    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(1, -20, 0, 16)
    countLabel.Position = UDim2.new(0, 10, 0, headerHeight + 42)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "Clones: 0 | Protected: ✓"
    countLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
    countLabel.TextSize = tinyFont
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.ZIndex = 62
    countLabel.Parent = mainFrame

    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.85, 0, 0, 1)
    sep.Position = UDim2.new(0.075, 0, 0, headerHeight + 62)
    sep.BackgroundColor3 = Color3.fromRGB(80, 60, 150)
    sep.BackgroundTransparency = 0.6
    sep.BorderSizePixel = 0
    sep.ZIndex = 61
    sep.Parent = mainFrame

    local yOffset = headerHeight + 70

    -- CLONE BUTTON
    local cloneBtn = Instance.new("TextButton")
    cloneBtn.Name = "CloneBtn"
    cloneBtn.Size = UDim2.new(0.85, 0, 0, btnHeight)
    cloneBtn.Position = UDim2.new(0.075, 0, 0, yOffset)
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

    local cloneText = Instance.new("TextLabel")
    cloneText.Name = "CloneText"
    cloneText.Size = UDim2.new(1, 0, 1, 0)
    cloneText.BackgroundTransparency = 1
    cloneText.Text = "📋 CLONE + REPLICATE"
    cloneText.TextColor3 = Color3.fromRGB(230, 220, 255)
    cloneText.TextSize = IsAndroid and 14 or 13
    cloneText.Font = Enum.Font.GothamBold
    cloneText.ZIndex = 63
    cloneText.Parent = cloneBtn

    yOffset = yOffset + btnHeight + 6

    -- USE/OPEN BUTTON
    local useBtn = Instance.new("TextButton")
    useBtn.Name = "UseBtn"
    useBtn.Size = UDim2.new(0.85, 0, 0, IsAndroid and 40 or 36)
    useBtn.Position = UDim2.new(0.075, 0, 0, yOffset)
    useBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
    useBtn.Text = ""
    useBtn.BorderSizePixel = 0
    useBtn.ZIndex = 62
    useBtn.AutoButtonColor = false
    useBtn.Parent = mainFrame

    local useBtnCorner = Instance.new("UICorner")
    useBtnCorner.CornerRadius = UDim.new(0, 10)
    useBtnCorner.Parent = useBtn

    local useBtnStroke = Instance.new("UIStroke")
    useBtnStroke.Color = Color3.fromRGB(80, 200, 120)
    useBtnStroke.Thickness = 1
    useBtnStroke.Transparency = 0.5
    useBtnStroke.Parent = useBtn

    local useText = Instance.new("TextLabel")
    useText.Size = UDim2.new(1, 0, 1, 0)
    useText.BackgroundTransparency = 1
    useText.Text = "📦 OPEN / USE ITEM"
    useText.TextColor3 = Color3.fromRGB(200, 255, 220)
    useText.TextSize = IsAndroid and 12 or 11
    useText.Font = Enum.Font.GothamBold
    useText.ZIndex = 63
    useText.Parent = useBtn

    yOffset = yOffset + (IsAndroid and 40 or 36) + 6

    -- CLONE ALL BUTTON
    local cloneAllBtn = Instance.new("TextButton")
    cloneAllBtn.Name = "CloneAllBtn"
    cloneAllBtn.Size = UDim2.new(0.85, 0, 0, IsAndroid and 36 or 32)
    cloneAllBtn.Position = UDim2.new(0.075, 0, 0, yOffset)
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

    yOffset = yOffset + (IsAndroid and 36 or 32) + 12

    -- Atualizar tamanho real
    mainFrame.Size = UDim2.new(0, frameWidth, 0, yOffset)

    -- Funções de atualização
    local function UpdateItemLabel()
        local tool = GetEquippedTool()
        if tool then
            itemLabel.Text = "🔧 " .. tool.Name
            itemLabel.TextColor3 = Color3.fromRGB(130, 255, 180)
        else
            itemLabel.Text = "🔧 No item equipped"
            itemLabel.TextColor3 = Color3.fromRGB(160, 160, 190)
        end
        
        countLabel.Text = "Clones: " .. CloneConfig.CloneCount .. " | Protected: " .. 
            (CloneConfig.ProtectClones and "✓" or "✕")
        
        local remoteCount = 0
        for _ in pairs(RemoteInterceptor.CapturedGiveRemotes) do remoteCount = remoteCount + 1 end
        local hookedCount = 0
        for _ in pairs(RemoteInterceptor.HookedRemotes) do hookedCount = hookedCount + 1 end
        
        statusLabel.Text = "🟢 Remotes: " .. remoteCount .. " | Hooked: " .. hookedCount
        statusLabel.TextColor3 = remoteCount > 0 and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 180, 80)
    end

    local function SetButtonFeedback(btn, stroke, text, successMsg, errorMsg, isSuccess)
        if isSuccess then
            stroke.Color = Color3.fromRGB(100, 255, 150)
            stroke.Transparency = 0
            text.Text = "✓ " .. successMsg
            text.TextColor3 = Color3.fromRGB(180, 255, 200)
        else
            stroke.Color = Color3.fromRGB(255, 80, 80)
            stroke.Transparency = 0
            text.Text = "✕ " .. errorMsg
            text.TextColor3 = Color3.fromRGB(255, 180, 180)
        end
        
        task.delay(1, function()
            pcall(function()
                stroke.Transparency = 0.4
                stroke.Color = Color3.fromRGB(130, 100, 255)
                UpdateItemLabel()
            end)
        end)
    end

    -- Touch feedback
    for _, btn in pairs({cloneBtn, useBtn, cloneAllBtn}) do
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or
               input.UserInputType == Enum.UserInputType.MouseButton1 then
                btn.BackgroundTransparency = 0.3
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or
               input.UserInputType == Enum.UserInputType.MouseButton1 then
                btn.BackgroundTransparency = 0
            end
        end)
    end

    -- CLONE ACTION
    cloneBtn.MouseButton1Click:Connect(function()
        local equippedTool = GetEquippedTool()

        if not equippedTool then
            SetButtonFeedback(cloneBtn, cloneBtnStroke, cloneText, "", "NO ITEM!", false)
            Xan.Notify({Title = "Clone", Content = "No item equipped!", Type = "Error"})
            return
        end

        local clonedTool, serverReplicated = AdvancedClone.FullClone(equippedTool)

        if clonedTool then
            CloneConfig.CloneCount = CloneConfig.CloneCount + 1
            
            local replicateMsg = serverReplicated and " (Server ✓)" or " (Client)"
            SetButtonFeedback(cloneBtn, cloneBtnStroke, cloneText, "CLONED!" .. replicateMsg, "", true)
            
            cloneText.Text = "📋 CLONE + REPLICATE"
            
            UpdateItemLabel()

            Xan.Notify({
                Title = "Clone Tool",
                Content = "'" .. clonedTool.Name .. "' cloned!" .. replicateMsg .. " (Total: " .. CloneConfig.CloneCount .. ")",
                Type = "Success"
            })
        else
            SetButtonFeedback(cloneBtn, cloneBtnStroke, cloneText, "", "FAILED!", false)
            cloneText.Text = "📋 CLONE + REPLICATE"
            
            Xan.Notify({
                Title = "Clone Tool",
                Content = "Clone failed: " .. tostring(serverReplicated),
                Type = "Error"
            })
        end
    end)

    -- USE/OPEN ACTION
    useBtn.MouseButton1Click:Connect(function()
        local equippedTool = GetEquippedTool()

        if not equippedTool then
            SetButtonFeedback(useBtn, useBtnStroke, useText, "", "NO ITEM!", false)
            useText.Text = "📦 OPEN / USE ITEM"
            Xan.Notify({Title = "Use Item", Content = "No item equipped!", Type = "Error"})
            return
        end

        local used = AdvancedClone.SimulateUse(equippedTool)
        
        if used then
            SetButtonFeedback(useBtn, useBtnStroke, useText, "ACTIVATED!", "", true)
            Xan.Notify({
                Title = "Use Item",
                Content = "'" .. equippedTool.Name .. "' activated via server!",
                Type = "Success"
            })
        else
            SetButtonFeedback(useBtn, useBtnStroke, useText, "", "NO REMOTE!", false)
            Xan.Notify({
                Title = "Use Item",
                Content = "Could not find use remote for this item.",
                Type = "Error"
            })
        end
        
        task.delay(1.2, function()
            pcall(function()
                useText.Text = "📦 OPEN / USE ITEM"
                useText.TextColor3 = Color3.fromRGB(200, 255, 220)
            end)
        end)
    end)

    -- CLONE ALL ACTION
    cloneAllBtn.MouseButton1Click:Connect(function()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local tools = {}

        if backpack then
            for _, item in pairs(backpack:GetChildren()) do
                if item:IsA("Tool") then table.insert(tools, item) end
            end
        end

        local char = LocalPlayer.Character
        if char then
            for _, item in pairs(char:GetChildren()) do
                if item:IsA("Tool") then table.insert(tools, item) end
            end
        end

        if #tools == 0 then
            SetButtonFeedback(cloneAllBtn, cloneAllStroke, cloneAllText, "", "NO TOOLS!", false)
            task.delay(1, function()
                pcall(function()
                    cloneAllText.Text = "📦 CLONE ALL BACKPACK"
                    cloneAllText.TextColor3 = Color3.fromRGB(170, 160, 210)
                end)
            end)
            Xan.Notify({Title = "Clone", Content = "No tools to clone!", Type = "Error"})
            return
        end

        local clonedCount = 0
        for _, tool in pairs(tools) do
            pcall(function()
                local cloned, _ = AdvancedClone.FullClone(tool)
                if cloned then
                    clonedCount = clonedCount + 1
                    CloneConfig.CloneCount = CloneConfig.CloneCount + 1
                end
            end)
        end

        SetButtonFeedback(cloneAllBtn, cloneAllStroke, cloneAllText, clonedCount .. " CLONED!", "", true)
        
        task.delay(1, function()
            pcall(function()
                cloneAllText.Text = "📦 CLONE ALL BACKPACK"
                cloneAllText.TextColor3 = Color3.fromRGB(170, 160, 210)
            end)
        end)

        UpdateItemLabel()

        Xan.Notify({
            Title = "Clone Tool",
            Content = clonedCount .. " tools cloned! (Total: " .. CloneConfig.CloneCount .. ")",
            Type = "Success"
        })
    end)

    -- Update loop
    task.spawn(function()
        while CloneFloatingUI and CloneFloatingUI.Parent do
            if mainFrame.Visible then
                pcall(function() UpdateItemLabel() end)
            end
            task.wait(0.5)
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
            Xan.Splash({Title = "DEVS HUB", Subtitle = "Inicializando...", Duration = 1, Theme = "Midnight"})
        else
            Xan.Splash({Title = "DEVS HUB", Subtitle = "System Initialization...", Duration = 2, Theme = "Midnight"})
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

-- Inicializar sistemas avançados
task.spawn(function()
    local remoteCount = ScanAllRemotes()
    oldWarn("[DEVS HUB] Scanned " .. remoteCount .. " remotes")
    
    local hookSuccess = AdvancedClone.SetupNamecallHook()
    oldWarn("[DEVS HUB] Namecall hook: " .. (hookSuccess and "SUCCESS" or "FALLBACK MODE"))
    
    ItemMonitor.Start()
    oldWarn("[DEVS HUB] Item monitor started")
end)

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
    Callback = function(val) Config.HitParts = val end
})

--------------------------------------------------------------------------------
-- MAIN TAB: VISUALS
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- MAIN TAB: MOVEMENT
--------------------------------------------------------------------------------

MainTab:AddSection("Movement")

local FlightTog = MainTab:AddToggle("Fly Hack", "fly_hack", function(v)
    Config.Fly = v
    if v then
        Xan.Notify({
            Title = "Flight",
            Content = IsAndroid and "Joystick + ▲/▼ subir/descer" or "WASD mover, E/Space subir, Q/Shift descer",
            Type = "Success"
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

--------------------------------------------------------------------------------
-- MAIN TAB: TELEPORT
--------------------------------------------------------------------------------

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
            if tool:IsA("Tool") then tool:Destroy() end
        end
    end
    if LocalPlayer.Character then
        for _, tool in pairs(LocalPlayer.Character:GetChildren()) do
            if tool:IsA("Tool") then tool:Destroy() end
        end
    end
    Xan.Notify({Title = "Equipment", Content = "All tools removed"})
end)

PlayerTab:AddButton("Drop All Tools", function()
    if LocalPlayer.Backpack then
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then tool.Parent = workspace end
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

PlayerTab:AddSlider("Health Value", "health_val", {Min = 1, Max = 100, Default = 100}, function(v)
    if LocalPlayer.Character then
        local h = LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then h.Health = (h.MaxHealth / 100) * v end
    end
end)

--------------------------------------------------------------------------------
-- PLAYER TAB: THEFT
--------------------------------------------------------------------------------

PlayerTab:AddSection("Theft")

local StealToggle = PlayerTab:AddToggle("Steal Speed Hack", "steal_hack", function(v)
    Config.StealSpeed = v
    if v then
        Xan.Notify({Title = "Theft", Content = "Steal Speed enabled! " .. Config.StealMultiplier .. "x faster"})
    else
        Xan.Notify({Title = "Theft", Content = "Steal Speed disabled."})
    end
end)

PlayerTab:AddSlider("Steal Multiplier", "steal_mult", {Min = 1, Max = 10, Default = 2}, function(v)
    Config.StealMultiplier = v
end)

--------------------------------------------------------------------------------
-- PLAYER TAB: ADVANCED CLONE TOOL
--------------------------------------------------------------------------------

PlayerTab:AddSection("Advanced Clone Tool")

CloneMainFrame = CreateCloneFloatingUI()

CloneToggleRef = PlayerTab:AddToggle("Clone Tool Mode", "clone_tool_mode", function(v)
    CloneConfig.Enabled = v

    if not CloneMainFrame or not CloneMainFrame.Parent then
        CloneMainFrame = CreateCloneFloatingUI()
    end

    CloneMainFrame.Visible = v

    if v then
        -- Re-scan remotes ao ativar
        task.spawn(function()
            ScanAllRemotes()
        end)
        
        Xan.Notify({
            Title = "Advanced Clone",
            Content = IsAndroid 
                and "Equipe um item e toque CLONE + REPLICATE!" 
                or "Equip a tool and press CLONE + REPLICATE!",
            Type = "Success"
        })
    else
        Xan.Notify({Title = "Clone Tool", Content = "Clone mode disabled.", Type = "Info"})
    end
end)

if not IsAndroid then
    PlayerTab:AddKeybind("Clone Key [C]", "clone_key", Enum.KeyCode.C, function()
        CloneToggleRef:Set(not CloneConfig.Enabled)
    end)
end

PlayerTab:AddToggle("Protect Clones", "protect_clones", function(v)
    CloneConfig.ProtectClones = v
    Xan.Notify({
        Title = "Clone Protection",
        Content = v and "Clones will be auto-restored if removed!" or "Clone protection disabled.",
        Type = v and "Success" or "Info"
    })
end)

PlayerTab:AddToggle("Auto Restore", "auto_restore", function(v)
    CloneConfig.AutoRestore = v
end)

PlayerTab:AddButton("Quick Clone (Equipped)", function()
    local tool = GetEquippedTool()
    if not tool then
        Xan.Notify({Title = "Clone", Content = "No tool equipped!", Type = "Error"})
        return
    end

    local cloned, serverReplicated = AdvancedClone.FullClone(tool)

    if cloned then
        CloneConfig.CloneCount = CloneConfig.CloneCount + 1
        local msg = serverReplicated and " (Server ✓)" or " (Client)"
        Xan.Notify({
            Title = "Clone Tool",
            Content = "'" .. cloned.Name .. "' cloned!" .. msg,
            Type = "Success"
        })
    else
        Xan.Notify({Title = "Clone", Content = "Clone failed!", Type = "Error"})
    end
end)

PlayerTab:AddButton("Re-Scan Remotes", function()
    local count = ScanAllRemotes()
    local giveCount = 0
    for _ in pairs(RemoteInterceptor.CapturedGiveRemotes) do giveCount = giveCount + 1 end
    
    Xan.Notify({
        Title = "Remote Scanner",
        Content = "Found " .. count .. " remotes, " .. giveCount .. " give-related",
        Type = "Success"
    })
end)

PlayerTab:AddButton("Force Equip + Activate", function()
    local tool = GetEquippedTool()
    if not tool then
        -- Tentar pegar do backpack
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, item in pairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    tool = item
                    break
                end
            end
        end
    end
    
    if tool then
        AdvancedClone.SimulateUse(tool)
        Xan.Notify({Title = "Activate", Content = "Activated: " .. tool.Name, Type = "Success"})
    else
        Xan.Notify({Title = "Activate", Content = "No tool found!", Type = "Error"})
    end
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
DevsTab:AddLabel("Version: 2.0 (Advanced Clone)")
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
        Xan.Notify({Title = "Debug", Content = "Debug enabled! Press E to log.", Type = "Success"})
    else
        Xan.Notify({Title = "Debug", Content = "Debug disabled."})
    end
end)

DevsTab:AddLabel("Logs actions when E is pressed")

DevsTab:AddButton("Show Captured Remotes", function()
    local msg = "Give Remotes:\n"
    local count = 0
    for name, _ in pairs(RemoteInterceptor.CapturedGiveRemotes) do
        msg = msg .. "• " .. name .. "\n"
        count = count + 1
        if count > 10 then
            msg = msg .. "... and more\n"
            break
        end
    end
    
    msg = msg .. "\nHooked Remotes:\n"
    count = 0
    for name, data in pairs(RemoteInterceptor.HookedRemotes) do
        msg = msg .. "• " .. name .. " (" .. math.floor(tick() - data.Timestamp) .. "s ago)\n"
        count = count + 1
        if count > 10 then
            msg = msg .. "... and more\n"
            break
        end
    end
    
    oldWarn("[DEVS HUB DEBUG] " .. msg)
    Xan.Notify({Title = "Debug", Content = "Remote list logged to F9 console", Type = "Info"})
end)

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

    -- Limpar proteções de clones
    for _, data in pairs(CloneConfig.ClonedItems) do
        pcall(function()
            if data.Connection then data.Connection:Disconnect() end
        end)
    end

    -- Restaurar namecall hook
    if RemoteInterceptor.OriginalNamecall then
        pcall(function()
            hookmetamethod(game, "__namecall", RemoteInterceptor.OriginalNamecall)
        end)
    end

    for _, c in pairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, o in pairs(Objects) do
        pcall(function() o:Destroy() end)
    end

    if FlyControlFrame then
        pcall(function() FlyControlFrame.Parent:Destroy() end)
    end
    if CloneFloatingUI then
        pcall(function() CloneFloatingUI:Destroy() end)
    end
    if AndroidButtonFrame then
        pcall(function() AndroidButtonFrame:Destroy() end)
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
        pcall(function() Xan:Unload() end)
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

    if Config.Noclip then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end

    if Config.SpeedHack then hum.WalkSpeed = Config.WalkSpeed end

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
            if FlySpeedLabel then
                pcall(function() FlySpeedLabel.Text = tostring(math.floor(Config.FlySpeed)) end)
            end
        end
    else
        if IsFlying then StopFly() end
    end

    if Config.StealSpeed then
        pcall(function()
            for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
                if remote:IsA("RemoteEvent") then
                    local rn = remote.Name:lower()
                    if string.find(rn, "steal") or string.find(rn, "rob") or
                       string.find(rn, "grab") or string.find(rn, "take") or
                       string.find(rn, "action") then
                        for i = 1, Config.StealMultiplier do
                            remote:FireServer()
                            task.wait(0.05)
                        end
                    end
                end
            end
        end)
    end
end)

Connections["Aim"] = RunService.RenderStepped:Connect(function()
    if not Config.Aimlock then return end
    pcall(function()
        local mouse = UserInputService:GetMouseLocation()
        local best, bestDist = nil, Config.AimRange
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and
                p.Character.Humanoid.Health > 0 then
                local part = nil
                if Config.HitParts.Head then part = p.Character:FindFirstChild("Head") end
                if not part and Config.HitParts.Chest then part = p.Character:FindFirstChild("HumanoidRootPart") end
                if not part then part = p.Character:FindFirstChild("Head") end
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

Connections["Inputs"] = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

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
                oldWarn(string.format(
                    "[DEVS HUB DEBUG] Target: %s | Pos: %.2f, %.2f, %.2f",
                    result.Instance.Parent.Name, result.Position.X, result.Position.Y, result.Position.Z
                ))
                Xan.Notify({Title = "Debug", Content = "Logged to F9", Type = "Info"})
            end
        end)
    end

    if input.KeyCode == Enum.KeyCode.U and Config.TargetPlr and Config.TargetPlr.Character then
        pcall(function()
            LocalPlayer.Character:SetPrimaryPartCFrame(
                Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
            )
            Xan.Notify({Title = "Teleport", Content = "To: " .. Config.TargetPlr.Name})
        end)
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
                    LocalPlayer.Character:SetPrimaryPartCFrame(
                        Config.TargetPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
                    )
                    Xan.Notify({Title = "Teleport", Content = "To: " .. Config.TargetPlr.Name})
                else
                    Xan.Notify({Title = "Teleport", Content = "No target!", Type = "Error"})
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
        if Config.Fly then StartFly() end
    end

    if CloneConfig.Enabled and CloneMainFrame then
        task.wait(1)
        pcall(function() CloneMainFrame.Visible = true end)
    end
    
    -- Re-scan remotes após respawn
    task.spawn(function()
        task.wait(2)
        ScanAllRemotes()
    end)
end)

Xan.Notify({Title = "DEVS HUB", Content = "v2.0 Loaded! Advanced Clone System Active.", Type = "Success"})
