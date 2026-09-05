--[[
    CYBORG HACK PANEL // ONE FILE EDITION
    Place as a LocalScript in StarterPlayerScripts.
    Designed for a developer-controlled Roblox FPS.
    Features: advanced aim assist, prediction, FOV, visibility checks,
    ESP highlights, tracers, names, health, distance, fly, noclip,
    speed, jump, mobile controls, PC controls, responsive UI, presets,
    diagnostics, performance throttling, and cleanup.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = {
    Enabled = true,
    PanelKey = Enum.KeyCode.RightShift,
    Theme = "Cyborg",
    UI = {
        Width = 720,
        Height = 500,
        Scale = 1,
        CompactMobile = true,
        ShowFPS = true,
        ShowStatus = true,
        Transparency = 0.08,
        AnimationSpeed = 0.18,
        CornerRadius = 10,
        MinWidth = 560,
        MaxWidth = 980,
        MinHeight = 430,
        MaxHeight = 680,
        Responsive = true,
        ShowSearch = true,
        GlassStrength = 0.18,
        TopBarHeight = 62,
        SidebarWidth = 154,
    },
    Aim = {
        Enabled = false,
        HoldToAim = true,
        ActivationKey = Enum.UserInputType.MouseButton2,
        Mode = "Hybrid",
        TargetPart = "Head",
        FOV = 180,
        MinFOV = 35,
        MaxFOV = 600,
        Smoothing = 0.055,
        InstantBlend = 0.82,
        Prediction = 0.105,
        GravityCompensation = 0.0,
        MaxDistance = 1500,
        TeamCheck = true,
        VisibleCheck = true,
        AliveCheck = true,
        KnockedCheck = true,
        WallIgnore = false,
        Priority = "Crosshair",
        SwitchDelay = 0.035,
        StickyTarget = true,
        StickyBreakDistance = 240,
        AutoLead = true,
        LeadMultiplier = 1.0,
        Deadzone = 1.0,
        FOVOpacity = 0.9,
        FOVThickness = 2,
        ShowTarget = true,
        RequireTargetOnScreen = false,
        CameraOnly = true,
        TargetRefreshRate = 120,
        Acceleration = 0.88,
        MaxAngularSpeed = 16,
        LockGrace = 0.11,
        RequireVisibleTargetPart = true,
        UseScreenCenter = true,
    },
    ESP = {
        Enabled = false,
        MaxDistance = 1500,
        UpdateRate = 0.06,
        Highlight = true,
        HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillTransparency = 0.72,
        OutlineTransparency = 0.02,
        TeamCheck = true,
        EnemyOnly = true,
        Box = true,
        BoxThickness = 1,
        Tracer = true,
        TracerThickness = 1.5,
        Name = true,
        Health = true,
        Distance = true,
        Weapon = true,
        Skeleton = false,
        OffscreenArrow = true,
        ArrowSize = 12,
        ArrowDistance = 70,
        MaxRender = 48,
        UseTeamColor = true,
        FadeWithDistance = true,
        Pulse = false,
        PulseSpeed = 2.2,
        TextSize = 13,
        BoxColorMode = "Team",
        TracerOrigin = "Bottom",
        TracerTransparency = 0.2,
        TracerZOffset = 2,
        HighlightOutline = true,
        HighlightFill = true,
        ShowOffscreenDistance = true,
        RefreshVisibleOnly = false,
        HealthBarWidth = 4,
    },
    Movement = {
        SpeedEnabled = false,
        Speed = 28,
        MinSpeed = 8,
        MaxSpeed = 100,
        FlyEnabled = false,
        FlySpeed = 60,
        FlyVertical = 48,
        FlySmoothing = 0.18,
        NoclipEnabled = false,
        JumpBoost = false,
        JumpPower = 70,
        HipHeightBoost = false,
        HipHeight = 2,
        AutoSprint = false,
        InfiniteJump = false,
        StrafeAssist = false,
        StrafeStrength = 1,
    },
    Mobile = {
        FlyButton = true,
        AimButton = true,
        SpeedButton = true,
        NoclipButton = true,
        PanelButton = true,
        ButtonScale = 1.0,
    },
    Performance = {
        ESPBudgetMs = 2.2,
        TargetScanInterval = 0.015,
        ESPScanInterval = 0.06,
        MaxTargetChecks = 80,
        MaxESPChecks = 96,
        ThrottleOnLowFPS = true,
        LowFPSThreshold = 38,
        RestoreFPSThreshold = 52,
        AdaptiveQuality = true,
        GarbagePulse = 4.0,
    },
    Colors = {
        Accent = Color3.fromRGB(65, 233, 255),
        Accent2 = Color3.fromRGB(140, 92, 255),
        Background = Color3.fromRGB(8, 10, 16),
        Panel = Color3.fromRGB(13, 16, 24),
        Panel2 = Color3.fromRGB(17, 21, 31),
        Text = Color3.fromRGB(235, 242, 255),
        Muted = Color3.fromRGB(145, 160, 182),
        Enemy = Color3.fromRGB(255, 82, 105),
        Friendly = Color3.fromRGB(70, 222, 135),
        Warning = Color3.fromRGB(255, 190, 70),
        White = Color3.fromRGB(255, 255, 255),
        Black = Color3.fromRGB(0, 0, 0),
    },
}

local State = {
    PanelOpen = true,
    AimHeld = false,
    AimTarget = nil,
    AimTargetPart = nil,
    LastAimSwitch = 0,
    LastTargetScan = 0,
    LastESPScan = 0,
    LastESPUpdate = 0,
    FPS = 60,
    FPSAccumulator = 0,
    FrameAccumulator = 0,
    LowPerformance = false,
    FlightVector = Vector3.zero,
    OriginalWalkSpeed = 16,
    OriginalJumpPower = 50,
    OriginalHipHeight = 0,
    CharacterConnections = {},
    ESPEntries = {},
    MobileButtons = {},
    NoclipCache = {},
    Dragging = false,
    DragStart = nil,
    DragOrigin = nil,
    CurrentTab = "Combat",
    Notifications = {},
    Destroyed = false,
    UIReady = false,
    IsMobile = false,
    Viewport = Vector2.zero,
    AimVelocity = Vector2.zero,
    LastVisible = true,
    ToastSerial = 0,
    SearchQuery = "",
    LastResponsiveUpdate = 0,
    OriginalAutoRotate = true,
}


local connections = {}
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local function safeDisconnect(connection)
    if connection then
        pcall(function() connection:Disconnect() end)
    end
end

local function clamp(n, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, n))
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function colorLerp(a, b, t)
    return Color3.new(
        lerp(a.R, b.R, t),
        lerp(a.G, b.G, t),
        lerp(a.B, b.B, t)
    )
end

local function isAlive(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return false end
    return humanoid.Health > 0
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function isEnemy(player)
    if player == LocalPlayer then return false end
    if not Config.ESP.TeamCheck and not Config.Aim.TeamCheck then return true end
    if LocalPlayer.Team == nil or player.Team == nil then return true end
    return player.Team ~= LocalPlayer.Team
end

local function getTargetPart(character)
    local preferred = Config.Aim.TargetPart
    local part = character and character:FindFirstChild(preferred)
    if part and part:IsA("BasePart") then return part end
    local head = character and character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return nil
end

local function getTeamColor(player)
    if player == LocalPlayer then return Config.Colors.Friendly end
    if Config.ESP.UseTeamColor and player.Team then
        local ok, color = pcall(function() return player.Team.TeamColor.Color end)
        if ok and color then return color end
    end
    return isEnemy(player) and Config.Colors.Enemy or Config.Colors.Friendly
end

local function worldToViewport(position)
    local point, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(point.X, point.Y), onScreen, point.Z
end

local function screenCenter()
    local viewport = Camera.ViewportSize
    return Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
end

local function distanceToLocal(position)
    local root = getRoot()
    if not root then return math.huge end
    return (root.Position - position).Magnitude
end

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

local function hasLineOfSight(part, character)
    if Config.Aim.WallIgnore then return true end
    if not Camera or not part or not character then return false end
    if not character:IsDescendantOf(Workspace) then return false end

    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local origin = Camera.CFrame.Position
    local point = part.Position
    local direction = point - origin
    if direction.Magnitude <= 0.01 then
        return true
    end

    local result = Workspace:Raycast(origin, direction, RayParams)
    if not result then
        return true
    end

    -- Strict mode: the exact requested aim part must be what the ray reaches.
    -- This prevents a visible torso/arm from authorizing a hidden head lock.
    if Config.Aim.RequireVisibleTargetPart then
        return result.Instance == part or result.Instance:IsDescendantOf(character) and result.Instance:IsA("BasePart") and result.Instance == part
    end

    return result.Instance:IsDescendantOf(character)
end

local function getVelocity(part)
    if not part then return Vector3.zero end
    local ok, velocity = pcall(function() return part.AssemblyLinearVelocity end)
    if ok and velocity then return velocity end
    return Vector3.zero
end

local function predictPosition(part)
    if not part then return nil end
    local position = part.Position
    if not Config.Aim.AutoLead then
        return position
    end
    local velocity = getVelocity(part)
    local lead = Config.Aim.Prediction * Config.Aim.LeadMultiplier
    local predicted = position + velocity * lead
    if Config.Aim.GravityCompensation ~= 0 then
        predicted += Vector3.new(0, 0.5 * Workspace.Gravity * Config.Aim.GravityCompensation * lead * lead, 0)
    end
    return predicted
end

local function validTarget(player)
    if not player or player == LocalPlayer then return false end
    if not player.Character then return false end
    if Config.Aim.TeamCheck and not isEnemy(player) then return false end
    if not isAlive(player.Character) then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if Config.Aim.AliveCheck and (not humanoid or humanoid.Health <= 0) then return false end
    local part = getTargetPart(player.Character)
    if not part then return false end
    local distance = distanceToLocal(part.Position)
    if distance > Config.Aim.MaxDistance then return false end
    if Config.Aim.VisibleCheck and not hasLineOfSight(part, player.Character) then return false end
    return true
end

local function angleScore(player)
    local part = getTargetPart(player.Character)
    if not part then return math.huge end
    local point, onScreen, depth = worldToViewport(part.Position)
    if depth <= 0 then return math.huge end
    if Config.Aim.RequireTargetOnScreen and not onScreen then return math.huge end
    local center = screenCenter()
    local delta = point - center
    return delta.Magnitude
end

local function distanceScore(player)
    local part = getTargetPart(player.Character)
    if not part then return math.huge end
    return distanceToLocal(part.Position)
end

local function healthScore(player)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return math.huge end
    return humanoid.Health
end

local function targetScore(player)
    if Config.Aim.Priority == "Distance" then
        return distanceScore(player)
    elseif Config.Aim.Priority == "LowestHealth" then
        return healthScore(player)
    elseif Config.Aim.Priority == "Threat" then
        local angle = angleScore(player)
        local distance = distanceScore(player)
        local health = healthScore(player)
        return angle * 0.8 + distance * 0.02 + health * 0.35
    end
    return angleScore(player)
end

local function candidateList()
    local list = {}
    local localRoot = getRoot()
    if not localRoot then return list end
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if count >= Config.Performance.MaxTargetChecks then break end
        if validTarget(player) then
            count += 1
            table.insert(list, player)
        end
    end
    return list
end

local function acquireTarget(force)
    if not Config.Aim.Enabled then return nil end
    local now = os.clock()
    if not force and now - State.LastAimSwitch < Config.Aim.SwitchDelay then
        return State.AimTarget
    end
    local current = State.AimTarget
    if Config.Aim.StickyTarget and current and validTarget(current) then
        local currentPart = getTargetPart(current.Character)
        if currentPart then
            local currentPoint, currentOnScreen = worldToViewport(currentPart.Position)
            local delta = (currentPoint - screenCenter()).Magnitude
            if currentOnScreen and delta <= Config.Aim.StickyBreakDistance then
                return current
            end
        end
    end
    local best = nil
    local bestScore = math.huge
    for _, player in ipairs(candidateList()) do
        local part = getTargetPart(player.Character)
        if part then
            local point, onScreen, depth = worldToViewport(part.Position)
            if depth > 0 and (onScreen or not Config.Aim.RequireTargetOnScreen) then
                local score = targetScore(player)
                if score <= Config.Aim.FOV and score < bestScore then
                    bestScore = score
                    best = player
                end
            end
        end
    end
    State.LastAimSwitch = now
    State.AimTarget = best
    State.AimTargetPart = best and getTargetPart(best.Character) or nil
    return best
end

local function applyAim()
    if not Config.Aim.Enabled then return end
    if Config.Aim.HoldToAim and not State.AimHeld then return end
    local target = acquireTarget(false)
    if not target or not validTarget(target) then
        State.AimTarget = nil
        State.AimTargetPart = nil
        return
    end
    local part = getTargetPart(target.Character)
    if not part then return end
    local predicted = predictPosition(part)
    if not predicted then return end
    local origin = Camera.CFrame.Position
    local direction = predicted - origin
    if direction.Magnitude <= 0.001 then return end
    local desired = CFrame.lookAt(origin, predicted, Camera.CFrame.UpVector)
    local current = Camera.CFrame
    local fovScale = clamp(direction.Magnitude / math.max(Config.Aim.MaxDistance, 1), 0.08, 1)
    local adaptiveSmoothing = clamp(Config.Aim.Smoothing + fovScale * 0.035, 0.012, 0.32)
    local blend = 1 - math.pow(adaptiveSmoothing, 1.5)
    blend = clamp(blend, Config.Aim.InstantBlend, 0.985)
    if Config.Aim.Mode == "Instant" then
        Camera.CFrame = desired
    elseif Config.Aim.Mode == "Smooth" then
        Camera.CFrame = current:Lerp(desired, 1 - math.clamp(Config.Aim.Smoothing, 0.005, 0.95))
    else
        Camera.CFrame = current:Lerp(desired, blend)
    end
end

local function resetCharacterState()
    local humanoid = getHumanoid()
    if humanoid then
        State.OriginalWalkSpeed = humanoid.WalkSpeed
        State.OriginalJumpPower = humanoid.JumpPower
        State.OriginalHipHeight = humanoid.HipHeight
    end
end

local function applyMovement()
    local humanoid = getHumanoid()
    local root = getRoot()
    if not humanoid or not root then return end
    if Config.Movement.SpeedEnabled then
        humanoid.WalkSpeed = Config.Movement.Speed
    else
        humanoid.WalkSpeed = State.OriginalWalkSpeed
    end
    if Config.Movement.JumpBoost then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Config.Movement.JumpPower
    else
        humanoid.JumpPower = State.OriginalJumpPower
    end
    if Config.Movement.HipHeightBoost then
        humanoid.HipHeight = Config.Movement.HipHeight
    else
        humanoid.HipHeight = State.OriginalHipHeight
    end
end

local function applyNoclip()
    local character = getCharacter()
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if Config.Movement.NoclipEnabled then
                if State.NoclipCache[part] == nil then
                    State.NoclipCache[part] = part.CanCollide
                end
                part.CanCollide = false
            else
                if State.NoclipCache[part] ~= nil then
                    part.CanCollide = State.NoclipCache[part]
                end
            end
        end
    end
    if not Config.Movement.NoclipEnabled then
        table.clear(State.NoclipCache)
    end
end

local function flyStep(dt)
    if not Config.Movement.FlyEnabled then return end
    local character = getCharacter()
    local humanoid = getHumanoid()
    local root = getRoot()
    if not character or not humanoid or not root then return end
    local move = humanoid.MoveDirection
    local cameraLook = Camera.CFrame.LookVector
    local cameraRight = Camera.CFrame.RightVector
    local planarForward = Vector3.new(cameraLook.X, 0, cameraLook.Z)
    local planarRight = Vector3.new(cameraRight.X, 0, cameraRight.Z)
    if planarForward.Magnitude > 0 then planarForward = planarForward.Unit end
    if planarRight.Magnitude > 0 then planarRight = planarRight.Unit end
    local desired = planarRight * move.X + planarForward * (-move.Z)
    local vertical = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical = vertical + 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = vertical - 1 end
    if UserInputService.TouchEnabled and State.MobileFlyVertical then
        vertical = State.MobileFlyVertical
    end
    desired += Vector3.new(0, vertical, 0)
    if desired.Magnitude > 1 then desired = desired.Unit end
    local targetVelocity = desired * Config.Movement.FlySpeed
    State.FlightVector = State.FlightVector:Lerp(targetVelocity, clamp(dt / math.max(Config.Movement.FlySmoothing, 0.01), 0.02, 1))
    root.AssemblyLinearVelocity = State.FlightVector
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

local function toggleFly(enabled)
    Config.Movement.FlyEnabled = enabled == nil and not Config.Movement.FlyEnabled or enabled
    if not Config.Movement.FlyEnabled then
        State.FlightVector = Vector3.zero
        local humanoid = getHumanoid()
        local root = getRoot()
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        if root then root.AssemblyLinearVelocity = Vector3.zero end
    end
end

local function toggleNoclip(enabled)
    Config.Movement.NoclipEnabled = enabled == nil and not Config.Movement.NoclipEnabled or enabled
    applyNoclip()
end

local function setSpeedEnabled(enabled)
    Config.Movement.SpeedEnabled = enabled
    applyMovement()
end

local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        pcall(function() object[key] = value end)
    end
    object.Parent = parent
    return object
end

local function addCorner(parent, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius or Config.UI.CornerRadius)}, parent)
end

local function addStroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or Config.Colors.Accent,
        Transparency = transparency or 0.35,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function addGradient(parent, rotation, a, b)
    local gradient = create("UIGradient", {
        Rotation = rotation or 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, a or Config.Colors.Panel2),
            ColorSequenceKeypoint.new(1, b or Config.Colors.Background),
        }),
    }, parent)
    return gradient
end

local function addShadow(parent, transparency, offset)
    local shadow = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = "rbxassetid://1316045217",
        ImageColor3 = Config.Colors.Black,
        ImageTransparency = transparency or 0.45,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118),
        Size = UDim2.new(1, 24, 1, 24),
        Position = UDim2.new(0, (offset or 6), 0, (offset or 6)),
        ZIndex = math.max((parent.ZIndex or 1) - 1, 0),
    }, parent.Parent or parent)
    return shadow
end

local function refreshAccentPulse()
    if not AccentLine or not AccentLine.Parent then return end
    local wave = (math.sin(os.clock() * 2.25) + 1) * 0.5
    AccentLine.BackgroundTransparency = 0.08 + wave * 0.18
end

local function tween(instance, properties, duration, style, direction)
    local info = TweenInfo.new(
        duration or Config.UI.AnimationSpeed,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(instance, info, properties)
    t:Play()
    return t
end

local ScreenGui = create("ScreenGui", {
    Name = "CyborgHackPanel",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 9999,
}, LocalPlayer:WaitForChild("PlayerGui"))

local Root = create("Frame", {
    Name = "Root",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
}, ScreenGui)

local Shadow = create("Frame", {
    Name = "Shadow",
    BackgroundColor3 = Config.Colors.Black,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    Size = UDim2.new(0, Config.UI.Width + 18, 0, Config.UI.Height + 18),
    Position = UDim2.new(0.5, -(Config.UI.Width + 18) / 2 + 4, 0.5, -(Config.UI.Height + 18) / 2 + 6),
}, Root)
addCorner(Shadow, Config.UI.CornerRadius + 3)

local Main = create("Frame", {
    Name = "Main",
    BackgroundColor3 = Config.Colors.Panel,
    BackgroundTransparency = Config.UI.Transparency,
    BorderSizePixel = 0,
    Size = UDim2.new(0, Config.UI.Width, 0, Config.UI.Height),
    Position = UDim2.new(0.5, -Config.UI.Width / 2, 0.5, -Config.UI.Height / 2),
    ClipsDescendants = true,
}, Root)
addCorner(Main, Config.UI.CornerRadius)
addStroke(Main, Config.Colors.Accent, 0.45, 1)

local TopBar = create("Frame", {
    Name = "TopBar",
    BackgroundColor3 = Config.Colors.Panel2,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, Config.UI.TopBarHeight),
}, Main)
addCorner(TopBar, Config.UI.CornerRadius)

local AccentLine = create("Frame", {
    Name = "AccentLine",
    BackgroundColor3 = Config.Colors.Accent,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 2),
    Position = UDim2.new(0, 0, 1, -2),
}, TopBar)

local Logo = create("TextLabel", {
    Name = "Logo",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 20, 0, 8),
    Size = UDim2.new(0, 250, 0, 24),
    Font = Enum.Font.GothamBlack,
    Text = "CYBORG // HACK PANEL",
    TextColor3 = Config.Colors.Text,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TopBar)

local Subtitle = create("TextLabel", {
    Name = "Subtitle",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 22, 0, 31),
    Size = UDim2.new(0, 320, 0, 17),
    Font = Enum.Font.Gotham,
    Text = "DEVELOPER CONTROL // ADAPTIVE CORE",
    TextColor3 = Config.Colors.Muted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TopBar)

local Status = create("TextLabel", {
    Name = "Status",
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -190, 0, 12),
    Size = UDim2.new(0, 170, 0, 18),
    Font = Enum.Font.GothamBold,
    Text = "● ONLINE  |  60 FPS",
    TextColor3 = Config.Colors.Friendly,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
}, TopBar)

local Close = create("TextButton", {
    Name = "Close",
    AutoButtonColor = false,
    BackgroundColor3 = Config.Colors.Enemy,
    BackgroundTransparency = 0.75,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -38, 0, 31),
    Size = UDim2.fromOffset(22, 22),
    Font = Enum.Font.GothamBold,
    Text = "×",
    TextColor3 = Config.Colors.Text,
    TextSize = 16,
}, TopBar)
addCorner(Close, 7)

local Minimize = create("TextButton", {
    Name = "Minimize",
    AutoButtonColor = false,
    BackgroundColor3 = Config.Colors.Panel,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -66, 0, 31),
    Size = UDim2.fromOffset(22, 22),
    Font = Enum.Font.GothamBold,
    Text = "—",
    TextColor3 = Config.Colors.Text,
    TextSize = 14,
    ZIndex = 5,
}, TopBar)
addCorner(Minimize, 7)
addStroke(Minimize, Config.Colors.Accent, 0.55, 1)

local CoreChip = create("TextLabel", {
    Name = "CoreChip",
    BackgroundColor3 = Config.Colors.Accent,
    BackgroundTransparency = 0.84,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -360, 0, 9),
    Size = UDim2.fromOffset(110, 20),
    Font = Enum.Font.GothamBold,
    Text = "◆ CYBORG CORE",
    TextColor3 = Config.Colors.Text,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 5,
}, TopBar)
addCorner(CoreChip, 8)

local Body = create("Frame", {
    Name = "Body",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, Config.UI.TopBarHeight),
    Size = UDim2.new(1, 0, 1, -Config.UI.TopBarHeight),
}, Main)

local Sidebar = create("Frame", {
    Name = "Sidebar",
    BackgroundColor3 = Config.Colors.Panel2,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Size = UDim2.new(0, Config.UI.SidebarWidth, 1, 0),
}, Body)

local Content = create("ScrollingFrame", {
    Name = "Content",
    Active = true,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, Config.UI.SidebarWidth, 0, 0),
    Size = UDim2.new(1, -Config.UI.SidebarWidth, 1, 0),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Config.Colors.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Body)

local ContentPadding = create("UIPadding", {
    PaddingTop = UDim.new(0, 14),
    PaddingBottom = UDim.new(0, 18),
    PaddingLeft = UDim.new(0, 16),
    PaddingRight = UDim.new(0, 16),
}, Content)

local ContentLayout = create("UIListLayout", {
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Content)

local SearchBox = create("TextBox", {
    Name = "SearchBox",
    BackgroundColor3 = Config.Colors.Panel,
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 168, 0, 70),
    Size = UDim2.fromOffset(205, 30),
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    PlaceholderText = "Search module...",
    PlaceholderColor3 = Config.Colors.Muted,
    Text = "",
    TextColor3 = Config.Colors.Text,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 40,
    Visible = false,
}, ScreenGui)
addCorner(SearchBox, 8)
addStroke(SearchBox, Config.Colors.Accent, 0.72, 1)

local TabButtons = {}
local TabPages = {}
local currentPage = nil

local function clearContent()
    for _, child in ipairs(Content:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

connect(SearchBox:GetPropertyChangedSignal("Text"), function()
    State.SearchQuery = string.lower(SearchBox.Text or "")
end)

local function setSearchVisible(visible)
    SearchBox.Visible = visible and Config.UI.ShowSearch and not State.IsMobile and State.PanelOpen
end

local function fuzzyMatch(text)
    if State.SearchQuery == "" then return true end
    return string.find(string.lower(text or ""), State.SearchQuery, 1, true) ~= nil
end

local function makeSection(title, subtitle)
    local section = create("Frame", {
        BackgroundColor3 = Config.Colors.Panel2,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 60),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #Content:GetChildren() + 1,
    }, Content)
    addCorner(section, 8)
    addStroke(section, Config.Colors.Accent2, 0.84, 1)
    local titleLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 9),
        Size = UDim2.new(1, -28, 0, 19),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = Config.Colors.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, section)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 29),
        Size = UDim2.new(1, -28, 0, 16),
        Font = Enum.Font.Gotham,
        Text = subtitle or "",
        TextColor3 = Config.Colors.Muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, section)
    local holder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 53),
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, section)
    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)
    local padding = create("UIPadding", {
        PaddingBottom = UDim.new(0, 11),
    }, holder)
    return section, holder, layout
end

local function makeToggle(parent, label, value, callback, description)
    local row = create("Frame", {
        BackgroundColor3 = Config.Colors.Background,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, description and 48 or 38),
    }, parent)
    addCorner(row, 7)
    local text = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, description and 6 or 10),
        Size = UDim2.new(1, -80, 0, 17),
        Font = Enum.Font.GothamMedium,
        Text = label,
        TextColor3 = Config.Colors.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    if description then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 24),
            Size = UDim2.new(1, -90, 0, 14),
            Font = Enum.Font.Gotham,
            Text = description,
            TextColor3 = Config.Colors.Muted,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = value and Config.Colors.Accent or Config.Colors.Panel,
        BackgroundTransparency = value and 0.2 or 0.15,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -56, 0.5, -10),
        Size = UDim2.fromOffset(42, 20),
        Font = Enum.Font.GothamBold,
        Text = value and "ON" or "OFF",
        TextColor3 = value and Config.Colors.Text or Config.Colors.Muted,
        TextSize = 9,
    }, row)
    addCorner(button, 8)
    local enabled = value
    local function refresh()
        button.BackgroundColor3 = enabled and Config.Colors.Accent or Config.Colors.Panel
        button.BackgroundTransparency = enabled and 0.15 or 0.15
        button.Text = enabled and "ON" or "OFF"
        button.TextColor3 = enabled and Config.Colors.Text or Config.Colors.Muted
    end
    connect(button.MouseButton1Click, function()
        enabled = not enabled
        refresh()
        if callback then callback(enabled) end
    end)
    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            -- Intentionally empty: row remains non-interactive outside the toggle.
        end
    end)
    return row, function(v)
        enabled = v
        refresh()
        if callback then callback(enabled) end
    end
end

local function makeSlider(parent, label, value, minimum, maximum, callback, suffix)
    local row = create("Frame", {
        BackgroundColor3 = Config.Colors.Background,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 54),
    }, parent)
    addCorner(row, 7)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(0.58, 0, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = label,
        TextColor3 = Config.Colors.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.58, 0, 0, 8),
        Size = UDim2.new(0.36, -12, 0, 16),
        Font = Enum.Font.GothamBold,
        Text = tostring(value) .. (suffix or ""),
        TextColor3 = Config.Colors.Accent,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local track = create("Frame", {
        BackgroundColor3 = Config.Colors.Panel,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 32),
        Size = UDim2.new(1, -24, 0, 6),
    }, row)
    addCorner(track, 4)
    local fill = create("Frame", {
        BackgroundColor3 = Config.Colors.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new((value - minimum) / (maximum - minimum), 0, 1, 0),
    }, track)
    addCorner(fill, 4)
    local knob = create("Frame", {
        BackgroundColor3 = Config.Colors.White,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - minimum) / (maximum - minimum), 0, 0.5, 0),
    }, track)
    addCorner(knob, 5)
    local dragging = false
    local currentValue = value
    local function setValue(v)
        currentValue = clamp(v, minimum, maximum)
        local alpha = (currentValue - minimum) / (maximum - minimum)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = string.format("%.2f", currentValue) .. (suffix or "")
        if callback then callback(currentValue) end
    end
    local function inputToValue(input)
        local x = input.Position.X
        local left = track.AbsolutePosition.X
        local alpha = clamp((x - left) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        return minimum + (maximum - minimum) * alpha
    end
    connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setValue(inputToValue(input))
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setValue(inputToValue(input))
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return row, setValue
end

local function makeButton(parent, label, callback, accent)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = accent or Config.Colors.Panel,
        BackgroundTransparency = accent and 0.22 or 0.12,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 36),
        Font = Enum.Font.GothamBold,
        Text = label,
        TextColor3 = Config.Colors.Text,
        TextSize = 10,
    }, parent)
    addCorner(button, 7)
    addStroke(button, accent or Config.Colors.Accent2, 0.75, 1)
    connect(button.MouseButton1Click, function()
        if callback then callback() end
        tween(button, {BackgroundTransparency = 0.02}, 0.06)
        task.delay(0.08, function()
            if button.Parent then tween(button, {BackgroundTransparency = accent and 0.22 or 0.12}, 0.12) end
        end)
    end)
    return button
end

local function makeInfo(parent, label, value)
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 25),
    }, parent)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.56, 0, 1, 0),
        Font = Enum.Font.Gotham,
        Text = label,
        TextColor3 = Config.Colors.Muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local v = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.56, 0, 0, 0),
        Size = UDim2.new(0.44, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = value,
        TextColor3 = Config.Colors.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    return v
end

local TabMeta = {
    {Name = "Combat", Icon = "⌖"},
    {Name = "ESP", Icon = "◈"},
    {Name = "Movement", Icon = "⇧"},
    {Name = "Mobile", Icon = "▣"},
    {Name = "System", Icon = "⚙"},
    {Name = "Presets", Icon = "✦"},
    {Name = "Stats", Icon = "◒"},
}

local function setPage(name)
    Config.CurrentTab = name
    clearContent()
    if TabPages[name] then
        TabPages[name]()
    end
    for tabName, button in pairs(TabButtons) do
        local active = tabName == name
        button.BackgroundColor3 = active and Config.Colors.Accent or Config.Colors.Panel2
        button.BackgroundTransparency = active and 0.82 or 0.35
        button.TextColor3 = active and Config.Colors.Text or Config.Colors.Muted
    end
end

local function buildSidebar()
    local header = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 14),
        Size = UDim2.new(1, -28, 0, 16),
        Font = Enum.Font.GothamBold,
        Text = "MODULES",
        TextColor3 = Config.Colors.Muted,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, Sidebar)
    local list = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 9, 0, 38),
        Size = UDim2.new(1, -18, 0, 260),
    }, Sidebar)
    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, list)
    for index, meta in ipairs(TabMeta) do
        local tab = create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Config.Colors.Panel2,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 32),
            Font = Enum.Font.GothamBold,
            Text = "  " .. meta.Icon .. "   " .. meta.Name,
            TextColor3 = Config.Colors.Muted,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = index,
        }, list)
        addCorner(tab, 7)
        TabButtons[meta.Name] = tab
        connect(tab.MouseButton1Click, function() setPage(meta.Name) end)
    end
    local footer = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 1, -54),
        Size = UDim2.new(1, -28, 0, 40),
        Font = Enum.Font.Gotham,
        Text = "CYBORG CORE\nAdaptive Quality",
        TextColor3 = Config.Colors.Muted,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Bottom,
    }, Sidebar)
end

buildSidebar()

TabPages.Combat = function()
    local section = makeSection("AIM CORE", "Hybrid targeting: near-instant acquisition with camera-stable smoothing.")
    local holder = select(2, section)
    makeToggle(holder, "Enable Advanced Aim", Config.Aim.Enabled, function(v) Config.Aim.Enabled = v end, "Target selection, prediction and adaptive blending.")
    makeToggle(holder, "Hold To Aim", Config.Aim.HoldToAim, function(v) Config.Aim.HoldToAim = v end, "PC right mouse / mobile aim button while active.")
    makeToggle(holder, "Visible Check", Config.Aim.VisibleCheck, function(v) Config.Aim.VisibleCheck = v end)
    makeToggle(holder, "Team Check", Config.Aim.TeamCheck, function(v) Config.Aim.TeamCheck = v end)
    makeToggle(holder, "Sticky Target", Config.Aim.StickyTarget, function(v) Config.Aim.StickyTarget = v end)
    makeToggle(holder, "Auto Lead", Config.Aim.AutoLead, function(v) Config.Aim.AutoLead = v end)
    makeToggle(holder, "Target Indicator", Config.Aim.ShowTarget, function(v) Config.Aim.ShowTarget = v end)
    makeSlider(holder, "FOV Radius", Config.Aim.FOV, Config.Aim.MinFOV, Config.Aim.MaxFOV, function(v) Config.Aim.FOV = v end, " px")
    makeSlider(holder, "Smoothing", Config.Aim.Smoothing, 0.01, 0.32, function(v) Config.Aim.Smoothing = v end)
    makeSlider(holder, "Instant Blend", Config.Aim.InstantBlend, 0.45, 0.99, function(v) Config.Aim.InstantBlend = v end)
    makeSlider(holder, "Prediction", Config.Aim.Prediction, 0, 0.35, function(v) Config.Aim.Prediction = v end, " s")
    makeSlider(holder, "Lead Multiplier", Config.Aim.LeadMultiplier, 0.5, 2, function(v) Config.Aim.LeadMultiplier = v end, "x")
    makeSlider(holder, "Max Distance", Config.Aim.MaxDistance, 100, 3000, function(v) Config.Aim.MaxDistance = v end, " m")
    local modeSection = makeSection("TARGET LOGIC", "Priority and target behavior.")
    local modeHolder = select(2, modeSection)
    makeButton(modeHolder, "PRIORITY: CROSSHAIR", function() Config.Aim.Priority = "Crosshair" end, Config.Colors.Accent)
    makeButton(modeHolder, "PRIORITY: DISTANCE", function() Config.Aim.Priority = "Distance" end)
    makeButton(modeHolder, "PRIORITY: LOWEST HEALTH", function() Config.Aim.Priority = "LowestHealth" end)
    makeButton(modeHolder, "PRIORITY: THREAT", function() Config.Aim.Priority = "Threat" end)
    local precisionSection = makeSection("LOCK PROFILE", "Instant acquisition with controlled camera motion.")
    local precisionHolder = select(2, precisionSection)
    makeButton(precisionHolder, "TARGET: HEAD", function() Config.Aim.TargetPart = "Head" end, Config.Colors.Accent)
    makeButton(precisionHolder, "TARGET: ROOT", function() Config.Aim.TargetPart = "HumanoidRootPart" end)
    makeButton(precisionHolder, "MODE: HYBRID", function() Config.Aim.Mode = "Hybrid" end, Config.Colors.Accent2)
    makeButton(precisionHolder, "MODE: SMOOTH", function() Config.Aim.Mode = "Smooth" end)
    makeSlider(precisionHolder, "Lock Grace", Config.Aim.LockGrace, 0.02, 0.3, function(v) Config.Aim.LockGrace = v end, " s")
    makeSlider(precisionHolder, "Max Angular Speed", Config.Aim.MaxAngularSpeed, 2, 24, function(v) Config.Aim.MaxAngularSpeed = v end, "°")

    local fovSection = makeSection("FOV DISPLAY", "Realtime targeting cone.")
    local fovHolder = select(2, fovSection)
    makeSlider(fovHolder, "FOV Opacity", Config.Aim.FOVOpacity, 0.05, 1, function(v) Config.Aim.FOVOpacity = v end)
    makeSlider(fovHolder, "FOV Thickness", Config.Aim.FOVThickness, 1, 5, function(v) Config.Aim.FOVThickness = v end)
end

TabPages.ESP = function()
    local section = makeSection("ESP CORE", "Pooled highlights and beam tracers with adaptive render budgets.")
    local holder = select(2, section)
    makeToggle(holder, "Enable ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
    makeToggle(holder, "Highlights", Config.ESP.Highlight, function(v) Config.ESP.Highlight = v end)
    makeToggle(holder, "Tracers", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)
    makeToggle(holder, "Name Tags", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    makeToggle(holder, "Health Bars", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    makeToggle(holder, "Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
    makeToggle(holder, "Weapon Label", Config.ESP.Weapon, function(v) Config.ESP.Weapon = v end)
    makeToggle(holder, "Offscreen Arrows", Config.ESP.OffscreenArrow, function(v) Config.ESP.OffscreenArrow = v end)
    makeToggle(holder, "Enemy Only", Config.ESP.EnemyOnly, function(v) Config.ESP.EnemyOnly = v end)
    makeToggle(holder, "Fade With Distance", Config.ESP.FadeWithDistance, function(v) Config.ESP.FadeWithDistance = v end)
    makeToggle(holder, "Pulse", Config.ESP.Pulse, function(v) Config.ESP.Pulse = v end)
    makeSlider(holder, "ESP Distance", Config.ESP.MaxDistance, 100, 3000, function(v) Config.ESP.MaxDistance = v end, " m")
    makeSlider(holder, "Update Rate", Config.ESP.UpdateRate, 0.02, 0.25, function(v) Config.ESP.UpdateRate = v end, " s")
    makeSlider(holder, "Max Rendered", Config.ESP.MaxRender, 8, 96, function(v) Config.ESP.MaxRender = math.floor(v) end)
    makeSlider(holder, "Fill Transparency", Config.ESP.FillTransparency, 0, 1, function(v) Config.ESP.FillTransparency = v end)
    makeSlider(holder, "Arrow Size", Config.ESP.ArrowSize, 6, 24, function(v) Config.ESP.ArrowSize = math.floor(v) end)
    local visualSection = makeSection("VISUAL TUNING", "Fine control over tracer and highlight rendering.")
    local visualHolder = select(2, visualSection)
    makeSlider(visualHolder, "Tracer Thickness", Config.ESP.TracerThickness, 0.5, 4, function(v) Config.ESP.TracerThickness = v end)
    makeSlider(visualHolder, "Tracer Transparency", Config.ESP.TracerTransparency, 0, 0.9, function(v) Config.ESP.TracerTransparency = v end)
    makeSlider(visualHolder, "Outline Transparency", Config.ESP.OutlineTransparency, 0, 1, function(v) Config.ESP.OutlineTransparency = v end)
    makeSlider(visualHolder, "Text Size", Config.ESP.TextSize, 8, 18, function(v) Config.ESP.TextSize = math.floor(v) end)
    makeButton(visualHolder, "TRACER FROM: BOTTOM", function() Config.ESP.TracerOrigin = "Bottom" end, Config.Colors.Accent)
    makeButton(visualHolder, "TRACER FROM: CENTER", function() Config.ESP.TracerOrigin = "Center" end)
    makeToggle(visualHolder, "Highlight Fill", Config.ESP.HighlightFill, function(v) Config.ESP.HighlightFill = v end)
    makeToggle(visualHolder, "Highlight Outline", Config.ESP.HighlightOutline, function(v) Config.ESP.HighlightOutline = v end)

    local styleSection = makeSection("ESP STYLE", "Color and visual tuning.")
    local styleHolder = select(2, styleSection)
    makeButton(styleHolder, "ENEMY: RED", function() Config.Colors.Enemy = Color3.fromRGB(255, 82, 105) end, Config.Colors.Enemy)
    makeButton(styleHolder, "ENEMY: CYAN", function() Config.Colors.Enemy = Color3.fromRGB(65, 233, 255) end, Config.Colors.Accent)
    makeButton(styleHolder, "ENEMY: PURPLE", function() Config.Colors.Enemy = Color3.fromRGB(180, 90, 255) end, Config.Colors.Accent2)
end

TabPages.Movement = function()
    local section = makeSection("MOVEMENT CORE", "Client-authoritative movement modules for your developer game.")
    local holder = select(2, section)
    makeToggle(holder, "Speed Hack", Config.Movement.SpeedEnabled, function(v) setSpeedEnabled(v) end, "Overrides Humanoid.WalkSpeed while enabled.")
    makeSlider(holder, "Speed", Config.Movement.Speed, Config.Movement.MinSpeed, Config.Movement.MaxSpeed, function(v) Config.Movement.Speed = v; applyMovement() end)
    makeToggle(holder, "Fly", Config.Movement.FlyEnabled, function(v) toggleFly(v) end, "Smooth camera-relative flight with vertical control.")
    makeSlider(holder, "Fly Speed", Config.Movement.FlySpeed, 10, 200, function(v) Config.Movement.FlySpeed = v end)
    makeSlider(holder, "Fly Vertical", Config.Movement.FlyVertical, 10, 120, function(v) Config.Movement.FlyVertical = v end)
    makeSlider(holder, "Fly Smoothing", Config.Movement.FlySmoothing, 0.02, 0.5, function(v) Config.Movement.FlySmoothing = v end)
    makeToggle(holder, "Noclip", Config.Movement.NoclipEnabled, function(v) toggleNoclip(v) end, "Disables CanCollide for character parts only.")
    makeToggle(holder, "Jump Boost", Config.Movement.JumpBoost, function(v) Config.Movement.JumpBoost = v; applyMovement() end)
    makeSlider(holder, "Jump Power", Config.Movement.JumpPower, 50, 150, function(v) Config.Movement.JumpPower = v; applyMovement() end)
    makeToggle(holder, "Infinite Jump", Config.Movement.InfiniteJump, function(v) Config.Movement.InfiniteJump = v end)
    makeToggle(holder, "Auto Sprint", Config.Movement.AutoSprint, function(v) Config.Movement.AutoSprint = v end)
    makeToggle(holder, "Strafe Assist", Config.Movement.StrafeAssist, function(v) Config.Movement.StrafeAssist = v end)
    makeSlider(holder, "Strafe Strength", Config.Movement.StrafeStrength, 0, 1, function(v) Config.Movement.StrafeStrength = v end)
    makeToggle(holder, "Hip Height", Config.Movement.HipHeightBoost, function(v) Config.Movement.HipHeightBoost = v; applyMovement() end)
    makeSlider(holder, "Hip Height", Config.Movement.HipHeight, 0, 8, function(v) Config.Movement.HipHeight = v; applyMovement() end)
    local bindings = makeSection("KEYBINDS", "Desktop controls.")
    local bindHolder = select(2, bindings)
    makeInfo(bindHolder, "Panel", "RightShift")
    makeInfo(bindHolder, "Aim", "Right Mouse")
    makeInfo(bindHolder, "Fly Up", "Space")
    makeInfo(bindHolder, "Fly Down", "Left Ctrl")
    makeInfo(bindHolder, "Fly Direction", "W / A / S / D")
end

TabPages.Mobile = function()
    local section = makeSection("MOBILE CORE", "Touch-ready controls with scaled hit areas for phones and tablets.")
    local holder = select(2, section)
    makeToggle(holder, "Mobile Fly Button", Config.Mobile.FlyButton, function(v) Config.Mobile.FlyButton = v end)
    makeToggle(holder, "Mobile Aim Button", Config.Mobile.AimButton, function(v) Config.Mobile.AimButton = v end)
    makeToggle(holder, "Mobile Speed Button", Config.Mobile.SpeedButton, function(v) Config.Mobile.SpeedButton = v end)
    makeToggle(holder, "Mobile Noclip Button", Config.Mobile.NoclipButton, function(v) Config.Mobile.NoclipButton = v end)
    makeToggle(holder, "Floating Panel Button", Config.Mobile.PanelButton, function(v) Config.Mobile.PanelButton = v end)
    makeSlider(holder, "Button Scale", Config.Mobile.ButtonScale, 0.7, 1.5, function(v) Config.Mobile.ButtonScale = v end, "x")
    local gesture = makeSection("TOUCH GESTURES", "Aim button uses Hold semantics for fast, predictable acquisition.")
    local gHolder = select(2, gesture)
    makeInfo(gHolder, "Aim", "Hold button")
    makeInfo(gHolder, "Fly", "Toggle button")
    makeInfo(gHolder, "Noclip", "Toggle button")
    makeInfo(gHolder, "Panel", "Tap floating button")
end

TabPages.System = function()
    local section = makeSection("SYSTEM", "Core runtime controls and cleanup.")
    local holder = select(2, section)
    makeToggle(holder, "Master Enabled", Config.Enabled, function(v) Config.Enabled = v end)
    makeToggle(holder, "Adaptive Quality", Config.Performance.AdaptiveQuality, function(v) Config.Performance.AdaptiveQuality = v end)
    makeToggle(holder, "Throttle On Low FPS", Config.Performance.ThrottleOnLowFPS, function(v) Config.Performance.ThrottleOnLowFPS = v end)
    makeToggle(holder, "FPS HUD", Config.UI.ShowFPS, function(v) Config.UI.ShowFPS = v end)
    makeToggle(holder, "Status HUD", Config.UI.ShowStatus, function(v) Config.UI.ShowStatus = v end)
    makeSlider(holder, "Aim Scan Interval", Config.Performance.TargetScanInterval, 0.005, 0.08, function(v) Config.Performance.TargetScanInterval = v end, " s")
    makeSlider(holder, "ESP Scan Interval", Config.Performance.ESPScanInterval, 0.02, 0.3, function(v) Config.Performance.ESPScanInterval = v end, " s")
    makeSlider(holder, "ESP Budget", Config.Performance.ESPBudgetMs, 0.5, 6, function(v) Config.Performance.ESPBudgetMs = v end, " ms")
    local cleanup = makeSection("CLEANUP", "Disable all systems or destroy the panel.")
    local cHolder = select(2, cleanup)
    makeButton(cHolder, "DISABLE ALL", function()
        Config.Aim.Enabled = false
        Config.ESP.Enabled = false
        setSpeedEnabled(false)
        toggleFly(false)
        toggleNoclip(false)
        Config.Movement.JumpBoost = false
        Config.Movement.InfiniteJump = false
    end, Config.Colors.Warning)
    makeButton(cHolder, "RESPAWN RESET", function()
        resetCharacterState()
        applyMovement()
        applyNoclip()
    end)
end

TabPages.Presets = function()
    local section = makeSection("PRESET PROFILES", "One-tap configurations for different play styles.")
    local holder = select(2, section)
    makeButton(holder, "RAGE // HIGH ASSIST", function()
        Config.Aim.Enabled = true
        Config.Aim.FOV = 260
        Config.Aim.Smoothing = 0.02
        Config.Aim.InstantBlend = 0.9
        Config.Aim.Prediction = 0.12
        Config.ESP.Enabled = true
        Config.ESP.Highlight = true
        Config.ESP.Tracer = true
        Config.ESP.Name = true
        Config.Movement.SpeedEnabled = true
        Config.Movement.Speed = 32
        applyMovement()
    end, Config.Colors.Enemy)
    makeButton(holder, "SILENT // PRECISION", function()
        Config.Aim.Enabled = true
        Config.Aim.FOV = 120
        Config.Aim.Smoothing = 0.045
        Config.Aim.InstantBlend = 0.78
        Config.Aim.Prediction = 0.09
        Config.ESP.Enabled = true
        Config.ESP.MaxRender = 36
        Config.Movement.SpeedEnabled = false
        applyMovement()
    end, Config.Colors.Accent)
    makeButton(holder, "CYBORG // FULL", function()
        Config.Aim.Enabled = true
        Config.Aim.FOV = 220
        Config.Aim.Smoothing = 0.035
        Config.Aim.InstantBlend = 0.86
        Config.Aim.Prediction = 0.105
        Config.ESP.Enabled = true
        Config.ESP.Highlight = true
        Config.ESP.Tracer = true
        Config.ESP.Name = true
        Config.ESP.Health = true
        Config.ESP.Distance = true
        Config.Movement.SpeedEnabled = true
        Config.Movement.Speed = 28
        applyMovement()
    end, Config.Colors.Accent2)
    makeButton(holder, "STEALTH // NO VISUAL ESP", function()
        Config.Aim.Enabled = true
        Config.Aim.FOV = 150
        Config.Aim.Smoothing = 0.06
        Config.ESP.Enabled = false
    end)
    makeButton(holder, "RESET TO DEFAULTS", function()
        Config.Aim.Enabled = false
        Config.Aim.FOV = 180
        Config.Aim.Smoothing = 0.055
        Config.Aim.InstantBlend = 0.82
        Config.Aim.Prediction = 0.105
        Config.ESP.Enabled = false
        Config.Movement.SpeedEnabled = false
        Config.Movement.FlyEnabled = false
        Config.Movement.NoclipEnabled = false
        Config.Movement.JumpBoost = false
        applyMovement()
        applyNoclip()
    end)
end

TabPages.Stats = function()
    local section = makeSection("LIVE TELEMETRY", "Realtime local diagnostics.")
    local holder = select(2, section)
    local fpsValue = makeInfo(holder, "FPS", tostring(State.FPS))
    local targetValue = makeInfo(holder, "Aim Target", "NONE")
    local distanceValue = makeInfo(holder, "Target Distance", "—")
    local pingValue = makeInfo(holder, "Ping", "—")
    local playerValue = makeInfo(holder, "Players", tostring(#Players:GetPlayers()))
    local renderValue = makeInfo(holder, "ESP Entries", "0")
    local qualityValue = makeInfo(holder, "Adaptive Quality", "NORMAL")
    local coreValue = makeInfo(holder, "Core State", "ONLINE")
    State.StatsRefs = {
        fps = fpsValue,
        target = targetValue,
        distance = distanceValue,
        ping = pingValue,
        players = playerValue,
        render = renderValue,
        quality = qualityValue,
        core = coreValue,
    }
    local about = makeSection("CORE INFO", "Runtime footprint and active modules.")
    local aHolder = select(2, about)
    makeInfo(aHolder, "Aim Module", "Predictive Hybrid")
    makeInfo(aHolder, "ESP Module", "Pooled / Adaptive")
    makeInfo(aHolder, "Renderer", "Beam + Highlight")
    makeInfo(aHolder, "Input", UserInputService.TouchEnabled and "Touch + Keyboard" or "Keyboard + Mouse")
end

setPage("Combat")

local function createFOVCircle()
    local circle = create("Frame", {
        Name = "FOVCircle",
        BackgroundColor3 = Config.Colors.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(Config.Aim.FOV * 2, Config.Aim.FOV * 2),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Visible = false,
        ZIndex = 20,
    }, ScreenGui)
    addCorner(circle, 999)
    local stroke = addStroke(circle, Config.Colors.Accent, 1 - Config.Aim.FOVOpacity, Config.Aim.FOVThickness)
    return circle, stroke
end

local FOVCircle, FOVStroke = createFOVCircle()

local TargetTag = create("Frame", {
    Name = "TargetTag",
    BackgroundColor3 = Config.Colors.Panel2,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(180, 44),
    Position = UDim2.new(0.5, 12, 0.5, 12),
    Visible = false,
    ZIndex = 30,
}, ScreenGui)
addCorner(TargetTag, 8)
addStroke(TargetTag, Config.Colors.Enemy, 0.28, 1)
local TargetName = create("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 5),
    Size = UDim2.new(1, -20, 0, 16),
    Font = Enum.Font.GothamBold,
    Text = "TARGET: NONE",
    TextColor3 = Config.Colors.Text,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TargetTag)
local TargetInfo = create("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 21),
    Size = UDim2.new(1, -20, 0, 14),
    Font = Enum.Font.Gotham,
    Text = "DISTANCE: —",
    TextColor3 = Config.Colors.Muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TargetTag)

local MobileLayer = create("Frame", {
    Name = "MobileLayer",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Visible = UserInputService.TouchEnabled,
    ZIndex = 50,
}, ScreenGui)

local function mobileButton(name, text, position, callback, hold)
    local button = create("TextButton", {
        Name = name,
        AutoButtonColor = false,
        BackgroundColor3 = Config.Colors.Panel2,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Position = position,
        Size = UDim2.fromOffset(78, 48),
        Font = Enum.Font.GothamBold,
        Text = text,
        TextColor3 = Config.Colors.Text,
        TextSize = 10,
        Active = true,
        Selectable = false,
        ZIndex = 51,
    }, MobileLayer)
    addCorner(button, 12)
    addStroke(button, Config.Colors.Accent, 0.52, 1)
    local active = false
    if hold then
        connect(button.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                active = true
                callback(true)
                tween(button, {BackgroundTransparency = 0.02}, 0.08)
            end
        end)
        connect(button.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                active = false
                callback(false)
                tween(button, {BackgroundTransparency = 0.18}, 0.1)
            end
        end)
    else
        connect(button.Activated, function()
            active = not active
            callback(active)
            tween(button, {BackgroundTransparency = active and 0.02 or 0.18}, 0.08)
        end)
    end
    State.MobileButtons[name] = button
    return button
end

if UserInputService.TouchEnabled then
    mobileButton("Aim", "AIM", UDim2.new(1, -176, 1, -134), function(v) State.AimHeld = v end, true)
    mobileButton("Fly", "FLY", UDim2.new(1, -90, 1, -134), function(v) toggleFly(v) end, false)
    mobileButton("Noclip", "NOCLIP", UDim2.new(1, -176, 1, -78), function(v) toggleNoclip(v) end, false)
    mobileButton("Speed", "SPEED", UDim2.new(1, -90, 1, -78), function(v) setSpeedEnabled(v) end, false)
    mobileButton("Panel", "MENU", UDim2.new(0, 16, 1, -78), function(v) State.PanelOpen = true; Main.Visible = true; Shadow.Visible = true end, false)
    mobileButton("FlyUp", "▲", UDim2.new(1, -262, 1, -134), function(v) State.MobileFlyVertical = v and 1 or 0 end, true)
    mobileButton("FlyDown", "▼", UDim2.new(1, -262, 1, -78), function(v) State.MobileFlyVertical = v and -1 or 0 end, true)
end

local function updateMobileVisibility()
    local touch = UserInputService.TouchEnabled
    MobileLayer.Visible = touch
    if not touch then return end
    local scale = Config.Mobile.ButtonScale
    for _, button in pairs(State.MobileButtons) do
        if button and button.Parent then
            button.Size = UDim2.fromOffset(78 * scale, 48 * scale)
        end
    end
end

local function destroyESPEntry(player)
    local entry = State.ESPEntries[player]
    if not entry then return end
    for _, object in pairs(entry.Objects or {}) do
        if object and object.Destroy then
            pcall(function() object:Destroy() end)
        end
    end
    for _, connection in pairs(entry.Connections or {}) do
        safeDisconnect(connection)
    end
    State.ESPEntries[player] = nil
end

local function makeTracerPart(entry, player)
    if entry.Tracer then return entry.Tracer end
    local attachmentFolder = entry.RootFolder
    local a0 = create("Attachment", {Name = "TracerOrigin"}, attachmentFolder)
    local a1 = create("Attachment", {Name = "TracerTarget"}, Workspace.Terrain)
    local beam = create("Beam", {
        Name = "Tracer",
        Attachment0 = a0,
        Attachment1 = a1,
        FaceCamera = true,
        LightInfluence = 0,
        Width0 = Config.ESP.TracerThickness,
        Width1 = Config.ESP.TracerThickness,
        Transparency = NumberSequence.new(0.2),
        Color = ColorSequence.new(getTeamColor(player)),
        Segments = 1,
        Enabled = true,
        ZOffset = 2,
    }, attachmentFolder)
    entry.Tracer = beam
    entry.TracerA0 = a0
    entry.TracerA1 = a1
    entry.Objects.Tracer = beam
    entry.Objects.TracerA0 = a0
    entry.Objects.TracerA1 = a1
    return beam
end

local function buildESPEntry(player)
    if State.ESPEntries[player] then return State.ESPEntries[player] end
    local folder = create("Folder", {Name = "CyborgESP_" .. tostring(player.UserId)}, Workspace)
    local entry = {
        Player = player,
        Objects = {},
        Connections = {},
        RootFolder = folder,
        Highlight = nil,
        Billboard = nil,
        NameLabel = nil,
        HealthBar = nil,
        DistanceLabel = nil,
        WeaponLabel = nil,
        Tracer = nil,
        TracerA0 = nil,
        TracerA1 = nil,
    }
    State.ESPEntries[player] = entry
    entry.Connections.CharacterAdded = connect(player.CharacterAdded, function()
        task.defer(function()
            if entry.Highlight then entry.Highlight:Destroy(); entry.Highlight = nil end
            if entry.Billboard then entry.Billboard:Destroy(); entry.Billboard = nil end
        end)
    end)
    return entry
end

local function ensureHighlight(entry, character)
    if not Config.ESP.Highlight then return end
    if not entry.Highlight or not entry.Highlight.Parent then
        local highlight = create("Highlight", {
            Name = "CyborgHighlight",
            Adornee = character,
            DepthMode = Config.ESP.HighlightDepthMode,
            FillColor = getTeamColor(entry.Player),
            FillTransparency = Config.ESP.FillTransparency,
            OutlineColor = getTeamColor(entry.Player),
            OutlineTransparency = Config.ESP.OutlineTransparency,
            Enabled = true,
        }, character)
        entry.Highlight = highlight
        entry.Objects.Highlight = highlight
    end
    entry.Highlight.Adornee = character
    entry.Highlight.FillColor = getTeamColor(entry.Player)
    entry.Highlight.OutlineColor = getTeamColor(entry.Player)
    entry.Highlight.FillTransparency = Config.ESP.FillTransparency
    entry.Highlight.OutlineTransparency = Config.ESP.OutlineTransparency
    entry.Highlight.Enabled = Config.ESP.Enabled and Config.ESP.Highlight
end

local function playerDisplayName(player)
    if not player then return "UNKNOWN" end
    return player.DisplayName ~= "" and player.DisplayName or player.Name
end

local function getHumanoidState(player)
    if not player.Character then return nil end
    return player.Character:FindFirstChildOfClass("Humanoid")
end

local function getEquippedTool(player)
    local character = player.Character
    if not character then return nil end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then return child end
    end
    return nil
end

local function ensureBillboard(entry, character)
    if not Config.ESP.Name and not Config.ESP.Health and not Config.ESP.Distance and not Config.ESP.Weapon then return end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end
    if not entry.Billboard or not entry.Billboard.Parent then
        local gui = create("BillboardGui", {
            Name = "CyborgESPBillboard",
            Adornee = head,
            AlwaysOnTop = true,
            LightInfluence = 0,
            Size = UDim2.fromOffset(180, 76),
            StudsOffset = Vector3.new(0, 3.2, 0),
            MaxDistance = Config.ESP.MaxDistance,
            ResetOnSpawn = false,
        }, head)
        local frame = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
        }, gui)
        local layout = create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 1),
        }, frame)
        local name = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Font = Enum.Font.GothamBold,
            Text = playerDisplayName(entry.Player),
            TextColor3 = getTeamColor(entry.Player),
            TextStrokeTransparency = 0.55,
            TextSize = Config.ESP.TextSize,
        }, frame)
        local health = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Font = Enum.Font.GothamMedium,
            Text = "HP: —",
            TextColor3 = Config.Colors.Text,
            TextStrokeTransparency = 0.65,
            TextSize = 10,
        }, frame)
        local distance = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Font = Enum.Font.Gotham,
            Text = "— m",
            TextColor3 = Config.Colors.Muted,
            TextStrokeTransparency = 0.7,
            TextSize = 9,
        }, frame)
        local weapon = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Font = Enum.Font.Gotham,
            Text = "",
            TextColor3 = Config.Colors.Warning,
            TextStrokeTransparency = 0.7,
            TextSize = 9,
        }, frame)
        entry.Billboard = gui
        entry.NameLabel = name
        entry.HealthBar = health
        entry.DistanceLabel = distance
        entry.WeaponLabel = weapon
        entry.Objects.Billboard = gui
        entry.Objects.BillboardFrame = frame
        entry.Objects.NameLabel = name
        entry.Objects.HealthLabel = health
        entry.Objects.DistanceLabel = distance
        entry.Objects.WeaponLabel = weapon
    end
    entry.Billboard.Adornee = head
    entry.Billboard.MaxDistance = Config.ESP.MaxDistance
end

local function updateESPEntry(entry, dt)
    local player = entry.Player
    local character = player.Character
    if not character or not isAlive(character) then
        if entry.Highlight then entry.Highlight.Enabled = false end
        if entry.Billboard then entry.Billboard.Enabled = false end
        if entry.Tracer then entry.Tracer.Enabled = false end
        return
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if not root then return end
    local distance = distanceToLocal(root.Position)
    if distance > Config.ESP.MaxDistance then
        if entry.Highlight then entry.Highlight.Enabled = false end
        if entry.Billboard then entry.Billboard.Enabled = false end
        if entry.Tracer then entry.Tracer.Enabled = false end
        return
    end
    if Config.ESP.EnemyOnly and not isEnemy(player) then
        if entry.Highlight then entry.Highlight.Enabled = false end
        if entry.Billboard then entry.Billboard.Enabled = false end
        if entry.Tracer then entry.Tracer.Enabled = false end
        return
    end
    ensureHighlight(entry, character)
    ensureBillboard(entry, character)
    if entry.Highlight then
        entry.Highlight.Enabled = Config.ESP.Enabled and Config.ESP.Highlight
        if Config.ESP.Pulse then
            local pulse = (math.sin(os.clock() * Config.ESP.PulseSpeed) + 1) * 0.5
            entry.Highlight.OutlineTransparency = clamp(Config.ESP.OutlineTransparency + pulse * 0.3, 0, 1)
        else
            entry.Highlight.OutlineTransparency = Config.ESP.OutlineTransparency
        end
    end
    if entry.Billboard then
        entry.Billboard.Enabled = Config.ESP.Enabled and (Config.ESP.Name or Config.ESP.Health or Config.ESP.Distance or Config.ESP.Weapon)
        local humanoid = getHumanoidState(player)
        local health = humanoid and humanoid.Health or 0
        local maxHealth = humanoid and humanoid.MaxHealth or 100
        if entry.NameLabel then
            entry.NameLabel.Visible = Config.ESP.Name
            entry.NameLabel.Text = playerDisplayName(player)
            entry.NameLabel.TextColor3 = getTeamColor(player)
        end
        if entry.HealthBar then
            entry.HealthBar.Visible = Config.ESP.Health
            entry.HealthBar.Text = string.format("HP: %d%%", math.floor(clamp(health / math.max(maxHealth, 1), 0, 1) * 100 + 0.5))
            entry.HealthBar.TextColor3 = colorLerp(Config.Colors.Enemy, Config.Colors.Friendly, clamp(health / math.max(maxHealth, 1), 0, 1))
        end
        if entry.DistanceLabel then
            entry.DistanceLabel.Visible = Config.ESP.Distance
            entry.DistanceLabel.Text = string.format("%d m", math.floor(distance + 0.5))
        end
        if entry.WeaponLabel then
            local tool = getEquippedTool(player)
            entry.WeaponLabel.Visible = Config.ESP.Weapon and tool ~= nil
            entry.WeaponLabel.Text = tool and ("▸ " .. tool.Name) or ""
        end
        if Config.ESP.FadeWithDistance then
            local alpha = clamp(distance / math.max(Config.ESP.MaxDistance, 1), 0, 1)
            entry.Billboard.StudsOffset = Vector3.new(0, 3.1 + alpha * 0.8, 0)
        end
    end
    if Config.ESP.Tracer then
        local beam = makeTracerPart(entry, player)
        beam.Enabled = Config.ESP.Enabled and Config.ESP.Tracer
        beam.Width0 = Config.ESP.TracerThickness
        beam.Width1 = Config.ESP.TracerThickness
        beam.Color = ColorSequence.new(getTeamColor(player))
        beam.Transparency = NumberSequence.new(clamp(Config.ESP.TracerTransparency, 0, 1))
        beam.ZOffset = Config.ESP.TracerZOffset
        if entry.TracerA0 then
            entry.TracerA0.WorldPosition = Camera.CFrame.Position
        end
        if entry.TracerA1 then
            entry.TracerA1.WorldPosition = root.Position
        end
    elseif entry.Tracer then
        entry.Tracer.Enabled = false
    end
end

local function refreshESPPlayers()
    local seen = {}
    local renderCount = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if renderCount >= Config.ESP.MaxRender then break end
        if player ~= LocalPlayer then
            renderCount += 1
            seen[player] = true
            buildESPEntry(player)
        end
    end
    for player, _ in pairs(State.ESPEntries) do
        if not seen[player] and (player.Parent ~= Players or Config.ESP.MaxRender <= 0) then
            destroyESPEntry(player)
        end
    end
end

local function clearAllESP()
    for player, _ in pairs(State.ESPEntries) do
        destroyESPEntry(player)
    end
end

local function updateESP(dt)
    if not Config.ESP.Enabled then
        for _, entry in pairs(State.ESPEntries) do
            if entry.Highlight then entry.Highlight.Enabled = false end
            if entry.Billboard then entry.Billboard.Enabled = false end
            if entry.Tracer then entry.Tracer.Enabled = false end
        end
        return
    end
    local start = os.clock()
    local processed = 0
    for _, entry in pairs(State.ESPEntries) do
        if processed >= Config.ESP.MaxRender then break end
        updateESPEntry(entry, dt)
        processed += 1
        if (os.clock() - start) * 1000 >= Config.Performance.ESPBudgetMs then break end
    end
end

local function updateFOV()
    FOVCircle.Size = UDim2.fromOffset(Config.Aim.FOV * 2, Config.Aim.FOV * 2)
    FOVCircle.Visible = Config.Aim.Enabled and State.PanelOpen
    FOVStroke.Transparency = 1 - Config.Aim.FOVOpacity
    FOVStroke.Thickness = Config.Aim.FOVThickness
    FOVStroke.Color = State.AimTarget and Config.Colors.Enemy or Config.Colors.Accent
    FOVCircle.Position = UDim2.fromOffset(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
end

local function updateTargetTag()
    local target = State.AimTarget
    local show = Config.Aim.Enabled and Config.Aim.ShowTarget and target and validTarget(target)
    TargetTag.Visible = show
    if not show then return end
    local part = getTargetPart(target.Character)
    if not part then return end
    local point, onScreen = worldToViewport(part.Position)
    if onScreen then
        TargetTag.Position = UDim2.fromOffset(point.X + 12, point.Y + 12)
    end
    TargetName.Text = "TARGET: " .. playerDisplayName(target)
    TargetInfo.Text = string.format("DISTANCE: %d m  |  LOCKED", math.floor(distanceToLocal(part.Position) + 0.5))
    TargetInfo.TextColor3 = Config.Colors.Muted
end

local function calculateFPS(dt)
    State.FPSAccumulator += dt
    State.FrameAccumulator += 1
    if State.FPSAccumulator >= 0.35 then
        State.FPS = math.floor(State.FrameAccumulator / State.FPSAccumulator + 0.5)
        State.FPSAccumulator = 0
        State.FrameAccumulator = 0
        if Config.Performance.AdaptiveQuality and Config.Performance.ThrottleOnLowFPS then
            if State.FPS <= Config.Performance.LowFPSThreshold then
                State.LowPerformance = true
            elseif State.FPS >= Config.Performance.RestoreFPSThreshold then
                State.LowPerformance = false
            end
        else
            State.LowPerformance = false
        end
    end
end

local function updateStatus()
    if not Config.UI.ShowStatus then
        Status.Visible = false
        return
    end
    Status.Visible = true
    local quality = State.LowPerformance and "LOW POWER" or "ONLINE"
    local color = State.LowPerformance and Config.Colors.Warning or Config.Colors.Friendly
    Status.Text = string.format("● %s  |  %d FPS", quality, State.FPS)
    Status.TextColor3 = color
end

local function updateStatsTab()
    local refs = State.StatsRefs
    if not refs then return end
    refs.fps.Text = tostring(State.FPS)
    refs.players.Text = tostring(#Players:GetPlayers())
    local target = State.AimTarget
    refs.target.Text = target and playerDisplayName(target) or "NONE"
    refs.distance.Text = "—"
    if target and target.Character then
        local part = getTargetPart(target.Character)
        if part then refs.distance.Text = string.format("%d m", math.floor(distanceToLocal(part.Position) + 0.5)) end
    end
    local pingText = "—"
    pcall(function()
        local network = Stats:FindFirstChild("Network")
        local serverStats = network and network:FindFirstChild("ServerStatsItem")
        local dataPing = serverStats and serverStats:FindFirstChild("Data Ping")
        if dataPing then pingText = tostring(dataPing:GetValueString()) end
    end)
    refs.ping.Text = pingText
    refs.render.Text = tostring(#State.ESPEntries)
    refs.quality.Text = State.LowPerformance and "THROTTLED" or "NORMAL"
    refs.core.Text = Config.Enabled and "ONLINE" or "PAUSED"
end

local function updateMasterVisibility()
    Main.Visible = State.PanelOpen
    Shadow.Visible = State.PanelOpen
    FOVCircle.Visible = State.PanelOpen and Config.Aim.Enabled
    TargetTag.Visible = State.PanelOpen and TargetTag.Visible
end

local function togglePanel()
    State.PanelOpen = not State.PanelOpen
    updateMasterVisibility()
    if State.PanelOpen then
        tween(Main, {Position = UDim2.new(0.5, -Config.UI.Width / 2, 0.5, -Config.UI.Height / 2)}, 0.18)
    end
end

connect(Close.MouseButton1Click, togglePanel)

connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Config.PanelKey then
        togglePanel()
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.AimHeld = true
    end
    if Config.Movement.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local humanoid = getHumanoid()
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.AimHeld = false
    end
end)

local draggingMain = false
local dragStart = nil
local startPos = nil
connect(TopBar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingMain = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
connect(UserInputService.InputChanged, function(input)
    if draggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        Shadow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X + 4, startPos.Y.Scale, startPos.Y.Offset + delta.Y + 6)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingMain = false
    end
end)

local function onCharacterAdded(character)
    task.wait(0.25)
    resetCharacterState()
    State.NoclipCache = {}
    if Config.Movement.NoclipEnabled then applyNoclip() end
    applyMovement()
end

connect(LocalPlayer.CharacterAdded, onCharacterAdded)
if LocalPlayer.Character then
    task.defer(onCharacterAdded, LocalPlayer.Character)
end

connect(Players.PlayerRemoving, function(player)
    destroyESPEntry(player)
    if State.AimTarget == player then
        State.AimTarget = nil
        State.AimTargetPart = nil
    end
end)

local function setupPlayer(player)
    if player == LocalPlayer then return end
    buildESPEntry(player)
end
for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end
connect(Players.PlayerAdded, setupPlayer)

local lastQualityUpdate = 0
local lastMovementUpdate = 0
local lastESPUpdate = 0
local lastAimUpdate = 0
local lastStatsUpdate = 0
local lastPanelScale = 0
local frameConnection

frameConnection = connect(RunService.RenderStepped, function(dt)
    if State.Destroyed then return end
    calculateFPS(dt)
    updateStatus()
    updateMobileVisibility()
    updateFOV()
    updateTargetTag()

    local now = os.clock()

    if Config.Enabled then
        if now - lastAimUpdate >= (State.LowPerformance and Config.Performance.TargetScanInterval * 2.0 or Config.Performance.TargetScanInterval) then
            lastAimUpdate = now
            if Config.Aim.Enabled and (not Config.Aim.HoldToAim or State.AimHeld) then
                acquireTarget(false)
            elseif not Config.Aim.HoldToAim then
                acquireTarget(false)
            end
        end
        applyAim()

        if now - lastMovementUpdate >= 0.05 then
            lastMovementUpdate = now
            applyMovement()
            applyNoclip()
        end

        flyStep(dt)

        if now - lastESPUpdate >= (State.LowPerformance and Config.Performance.ESPScanInterval * 2 or Config.Performance.ESPScanInterval) then
            lastESPUpdate = now
            refreshESPPlayers()
        end
        updateESP(dt)
    else
        FOVCircle.Visible = false
        TargetTag.Visible = false
    end

    if now - lastStatsUpdate >= 0.4 then
        lastStatsUpdate = now
        if Config.CurrentTab == "Stats" then updateStatsTab() end
    end

    if now - lastPanelScale >= 0.5 then
        lastPanelScale = now
        local viewport = Camera.ViewportSize
        local mobile = UserInputService.TouchEnabled
        if mobile and Config.UI.CompactMobile then
            local scaleX = viewport.X / 900
            local scaleY = viewport.Y / 620
            local scale = clamp(math.min(scaleX, scaleY), 0.72, 1)
            if viewport.X < 620 then
                local scaleObject = Main:FindFirstChildOfClass("UIScale")
                if not scaleObject then scaleObject = create("UIScale", {Scale = scale}, Main) else scaleObject.Scale = scale end
                Main.Position = UDim2.new(0.5, 0, 0.5, 0)
                Main.AnchorPoint = Vector2.new(0.5, 0.5)
                Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
                Shadow.Position = UDim2.new(0.5, 4, 0.5, 6)
            end
        end
    end
end)

-- ============================================================================
-- CYBORG POLISH PACK
-- Responsive layout, crosshair, hover treatment, mobile-safe sizing, toasts,
-- and centralized visual refresh. These systems are intentionally lightweight.
-- ============================================================================

local Crosshair = create("Frame", {
    Name = "Crosshair",
    BackgroundTransparency = 1,
    Size = UDim2.fromOffset(1, 1),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Visible = true,
    ZIndex = 18,
}, ScreenGui)

local function crossLine(name, pos, size)
    local line = create("Frame", {
        Name = name,
        BorderSizePixel = 0,
        BackgroundColor3 = Config.Colors.Text,
        BackgroundTransparency = 0,
        Position = pos,
        Size = size,
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 19,
    }, Crosshair)
    addCorner(line, 2)
    return line
end

local CrossTop = crossLine("Top", UDim2.new(0, 0, 0, -8), UDim2.fromOffset(2, 6))
local CrossBottom = crossLine("Bottom", UDim2.new(0, 0, 0, 8), UDim2.fromOffset(2, 6))
local CrossLeft = crossLine("Left", UDim2.new(0, -8, 0, 0), UDim2.fromOffset(6, 2))
local CrossRight = crossLine("Right", UDim2.new(0, 8, 0, 0), UDim2.fromOffset(6, 2))
local CrossDot = create("Frame", {
    Name = "Dot",
    BorderSizePixel = 0,
    BackgroundColor3 = Config.Colors.Accent,
    Size = UDim2.fromOffset(3, 3),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    ZIndex = 19,
}, Crosshair)
addCorner(CrossDot, 9)

local ToastHolder = create("Frame", {
    Name = "ToastHolder",
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 330, 1, -28),
    Position = UDim2.new(1, -350, 0, 14),
    ZIndex = 200,
}, ScreenGui)
local ToastLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, ToastHolder)

local function toast(title, message, accent)
    State.ToastSerial += 1
    local card = create("Frame", {
        BackgroundColor3 = Config.Colors.Panel2,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(300, 56),
        ZIndex = 201,
        LayoutOrder = State.ToastSerial,
    }, ToastHolder)
    addCorner(card, 10)
    addStroke(card, accent or Config.Colors.Accent, 0.45, 1)
    create("Frame", {
        BackgroundColor3 = accent or Config.Colors.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0),
        ZIndex = 202,
    }, card)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(13, 8),
        Size = UDim2.new(1, -26, 0, 16),
        Font = Enum.Font.GothamBold,
        Text = string.upper(title or "CYBORG"),
        TextColor3 = Config.Colors.Text,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202,
    }, card)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(13, 25),
        Size = UDim2.new(1, -26, 0, 20),
        Font = Enum.Font.Gotham,
        Text = message or "",
        TextColor3 = Config.Colors.Muted,
        TextSize = 9,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202,
    }, card)
    card.Position = UDim2.new(1, 24, 0, 0)
    tween(card, {Position = UDim2.new(1, 0, 0, 0)}, 0.22, Enum.EasingStyle.Quart)
    task.delay(2.4, function()
        if card and card.Parent then
            tween(card, {Position = UDim2.new(1, 24, 0, 0), BackgroundTransparency = 1}, 0.2)
            task.wait(0.23)
            if card then card:Destroy() end
        end
    end)
end

local PanelScale = create("UIScale", {Scale = 1}, Main)
local function updateResponsiveLayout(force)
    if not Camera then return end
    local now = os.clock()
    if not force and now - State.LastResponsiveUpdate < 0.15 then return end
    State.LastResponsiveUpdate = now

    local viewport = Camera.ViewportSize
    State.Viewport = viewport
    State.IsMobile = UserInputService.TouchEnabled and viewport.X < 900

    local baseW = Config.UI.Width
    local baseH = Config.UI.Height
    local targetW = clamp(baseW, Config.UI.MinWidth, Config.UI.MaxWidth)
    local targetH = clamp(baseH, Config.UI.MinHeight, Config.UI.MaxHeight)

    local availableW = math.max(viewport.X - 20, Config.UI.MinWidth)
    local availableH = math.max(viewport.Y - 20, Config.UI.MinHeight)
    targetW = math.min(targetW, availableW)
    targetH = math.min(targetH, availableH)

    local scaleX = viewport.X / math.max(targetW + 24, 1)
    local scaleY = viewport.Y / math.max(targetH + 24, 1)
    local scale = clamp(math.min(scaleX, scaleY), State.IsMobile and 0.68 or 0.85, 1)

    if State.IsMobile then
        scale = clamp(math.min(viewport.X / 680, viewport.Y / 500), 0.64, 0.96)
        Main.Size = UDim2.fromOffset(math.min(targetW, viewport.X - 16), math.min(targetH, viewport.Y - 16))
        Sidebar.Size = UDim2.new(0, math.min(Config.UI.SidebarWidth, 136), 1, 0)
        Content.Position = UDim2.new(0, math.min(Config.UI.SidebarWidth, 136), 0, 0)
        Content.Size = UDim2.new(1, -math.min(Config.UI.SidebarWidth, 136), 1, 0)
        setSearchVisible(false)
    else
        Main.Size = UDim2.fromOffset(targetW, targetH)
        Sidebar.Size = UDim2.new(0, Config.UI.SidebarWidth, 1, 0)
        Content.Position = UDim2.new(0, Config.UI.SidebarWidth, 0, 0)
        Content.Size = UDim2.new(1, -Config.UI.SidebarWidth, 1, 0)
        setSearchVisible(true)
    end

    PanelScale.Scale = scale
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    Shadow.Size = UDim2.new(0, Main.AbsoluteSize.X + 18, 0, Main.AbsoluteSize.Y + 18)
    Shadow.Position = UDim2.new(0.5, 4, 0.5, 6)

    local top = Config.UI.TopBarHeight
    TopBar.Size = UDim2.new(1, 0, 0, top)
    Body.Position = UDim2.new(0, 0, 0, top)
    Body.Size = UDim2.new(1, 0, 1, -top)
    SearchBox.Position = UDim2.new(0, Config.UI.SidebarWidth + 14, 0, top + 8)

    if State.IsMobile then
        Logo.TextSize = 15
        Subtitle.Text = "ADAPTIVE CYBORG CORE"
        Subtitle.TextSize = 8
        CoreChip.Visible = false
        Status.Position = UDim2.new(1, -150, 0, 10)
    else
        Logo.TextSize = 19
        Subtitle.Text = "DEVELOPER CONTROL // ADAPTIVE CORE"
        Subtitle.TextSize = 10
        CoreChip.Visible = true
        Status.Position = UDim2.new(1, -190, 0, 12)
    end
end

local function applyCrosshairTheme()
    local active = State.AimTarget ~= nil and Config.Aim.Enabled
    local c = active and Config.Colors.Enemy or Config.Colors.Text
    CrossTop.BackgroundColor3 = c
    CrossBottom.BackgroundColor3 = c
    CrossLeft.BackgroundColor3 = c
    CrossRight.BackgroundColor3 = c
    CrossDot.BackgroundColor3 = Config.Colors.Accent
    Crosshair.Visible = Config.Enabled
end

local function refreshVisibleState()
    if not State.PanelOpen then
        Main.Visible = false
        Shadow.Visible = false
    else
        Main.Visible = true
        Shadow.Visible = true
    end
    FOVCircle.Visible = Config.Enabled and Config.Aim.Enabled
    Crosshair.Visible = Config.Enabled
    setSearchVisible(State.PanelOpen)
end

connect(Minimize.MouseButton1Click, function()
    Main.Visible = false
    Shadow.Visible = false
    toast("PANEL", "Core minimized — use RightShift or MENU.", Config.Colors.Accent)
end)

connect(Close.MouseButton1Click, function()
    State.PanelOpen = false
    refreshVisibleState()
    toast("SYSTEM", "Panel hidden. RightShift reopens it.", Config.Colors.Warning)
end)

connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        State.PanelOpen = not State.PanelOpen
        refreshVisibleState()
    elseif input.KeyCode == Enum.KeyCode.F8 then
        Config.Enabled = not Config.Enabled
        toast("CORE", Config.Enabled and "Modules resumed." or "Modules paused.", Config.Enabled and Config.Colors.Friendly or Config.Colors.Warning)
        refreshVisibleState()
    end
end)

connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    Camera = Workspace.CurrentCamera
    updateResponsiveLayout(true)
end)

updateResponsiveLayout(true)
refreshVisibleState()
applyCrosshairTheme()
State.UIReady = true

toast("CYBORG ONLINE", "Responsive core initialized.", Config.Colors.Accent)

connect(RunService.RenderStepped, function()
    if State.Destroyed then return end
    refreshAccentPulse()
    updateResponsiveLayout(false)
    applyCrosshairTheme()
end)

local function cleanup()
    if State.Destroyed then return end
    State.Destroyed = true
    Config.Aim.Enabled = false
    Config.ESP.Enabled = false
    toggleFly(false)
    toggleNoclip(false)
    setSpeedEnabled(false)
    clearAllESP()
    for _, connection in ipairs(connections) do
        safeDisconnect(connection)
    end
    connections = {}
    if ScreenGui then ScreenGui:Destroy() end
end

-- Safety: expose a cleanup hook in the local environment only.
_G.CyborgHackPanelCleanup = cleanup

--[[
    CYBORG TUNING MANIFEST
    Runtime-safe metadata used by external developer tooling and preset UIs.
]]
local AdvancedRegistry = {
    {Group = "Aim", Name = "InstantHybrid", Key = "Aim.InstantBlend"},
    {Group = "Aim", Name = "VisibilityGate", Key = "Aim.VisibleCheck"},
    {Group = "Aim", Name = "Prediction", Key = "Aim.Prediction"},
    {Group = "ESP", Name = "Highlights", Key = "ESP.Highlight"},
    {Group = "ESP", Name = "Tracers", Key = "ESP.Tracer"},
    {Group = "ESP", Name = "AdaptiveBudget", Key = "Performance.ESPBudgetMs"},
    {Group = "Movement", Name = "Fly", Key = "Movement.FlyEnabled"},
    {Group = "Movement", Name = "Noclip", Key = "Movement.NoclipEnabled"},
    {Group = "Movement", Name = "Speed", Key = "Movement.SpeedEnabled"},
    {Group = "Mobile", Name = "TouchControls", Key = "Mobile.ButtonScale"},
    {Group = "UI", Name = "Responsive", Key = "UI.Responsive"},
    {Group = "Performance", Name = "AdaptiveQuality", Key = "Performance.AdaptiveQuality"},
}

for _, item in ipairs(AdvancedRegistry) do
    item.ReadOnly = true
end

-- End of single-file CYBORG build.
