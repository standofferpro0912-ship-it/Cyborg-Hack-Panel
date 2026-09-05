--[[
    CYBORG HACK PANEL // REWRITTEN CLEAN EDITION
    Single LocalScript for a developer-controlled Roblox FPS.

    Place in: StarterPlayer > StarterPlayerScripts

    Design goals:
    - Simple, clean and responsive UI.
    - Every control lives inside the menu.
    - Hide/minimize leaves only a draggable MENU button.
    - PC + mobile input.
    - Strict line-of-sight target validation.
    - Fast target acquisition with configurable smoothing.
    - ESP highlights, tracers, name/health/distance labels.
    - Movement modules: Speed, Fly, Noclip, Jump.
    - Aggressive cleanup and low-overhead update scheduling.

    Default aim smoothing is 0.04 as requested.
    The implementation is for a game you control; connect weapon validation to your
    own server-side combat code rather than trusting client aim data for damage.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

local Config = {
    Master = true,
    MenuKey = Enum.KeyCode.RightShift,

    UI = {
        Width = 560,
        Height = 430,
        MobileWidth = 390,
        MobileHeight = 500,
        Accent = Color3.fromRGB(75, 224, 255),
        AccentDark = Color3.fromRGB(39, 135, 166),
        Panel = Color3.fromRGB(13, 17, 24),
        Panel2 = Color3.fromRGB(18, 23, 32),
        Surface = Color3.fromRGB(23, 29, 39),
        Text = Color3.fromRGB(238, 244, 255),
        Muted = Color3.fromRGB(150, 162, 180),
        Danger = Color3.fromRGB(255, 95, 112),
        Success = Color3.fromRGB(75, 230, 145),
        Warning = Color3.fromRGB(255, 191, 76),
        Radius = 10,
        Anim = 0.16,
    },

    Aim = {
        Enabled = false,
        Hold = true,
        VisibleCheck = true,
        TeamCheck = true,
        AliveCheck = true,
        TargetPart = "Head",
        Priority = "Crosshair",
        FOV = 180,
        Smoothing = 0.04,
        MaxDistance = 1200,
        Prediction = 0.075,
        Lead = true,
        Sticky = true,
        StickyBreakFOV = 250,
        RequireOnScreen = true,
        TargetRefresh = 0.018,
        MaxCandidates = 60,
        FOVVisible = true,
    },

    ESP = {
        Enabled = false,
        TeamCheck = true,
        Highlights = true,
        Tracers = true,
        Names = true,
        Health = true,
        Distance = true,
        Weapon = true,
        MaxDistance = 1200,
        UpdateRate = 0.08,
        MaxRendered = 40,
        FillTransparency = 0.78,
        OutlineTransparency = 0.1,
        TracerThickness = 1.5,
        EnemyColor = Color3.fromRGB(255, 88, 106),
        FriendColor = Color3.fromRGB(75, 230, 145),
    },

    Movement = {
        Speed = false,
        SpeedValue = 28,
        Fly = false,
        FlySpeed = 65,
        Noclip = false,
        JumpBoost = false,
        JumpPower = 70,
        InfiniteJump = false,
    },

    Mobile = {
        Enabled = true,
        ButtonScale = 1,
    },
}

local State = {
    Destroyed = false,
    MenuOpen = true,
    Mobile = UserInputService.TouchEnabled,
    MenuButtonDragging = false,
    MenuButtonDragInput = nil,
    MenuButtonDragStart = nil,
    MenuButtonStartPos = nil,
    AimHeld = false,
    AimTarget = nil,
    AimTargetPart = nil,
    LastAimScan = 0,
    LastESPUpdate = 0,
    LastResponsive = 0,
    FPS = 60,
    FPSTime = 0,
    FPSFrames = 0,
    Original = {
        WalkSpeed = 16,
        JumpPower = 50,
        HipHeight = 0,
    },
    ESP = {},
    Connections = {},
    CharacterConnections = {},
    ActiveTab = "Combat",
}

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(State.Connections, c)
    return c
end

local function disconnect(c)
    if c then
        pcall(function()
            c:Disconnect()
        end)
    end
end

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

local function lerpNumber(a, b, t)
    return a + (b - a) * t
end

local function alive(character)
    if not character then
        return false
    end
    local hum = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    return hum ~= nil and root ~= nil and hum.Health > 0
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local c = getCharacter()
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function getRoot()
    local c = getCharacter()
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function isEnemy(player)
    if player == LocalPlayer then
        return false
    end
    if not Config.Aim.TeamCheck and not Config.ESP.TeamCheck then
        return true
    end
    if LocalPlayer.Team == nil or player.Team == nil then
        return true
    end
    return player.Team ~= LocalPlayer.Team
end

local function teamColor(player)
    if player == LocalPlayer then
        return Config.ESP.FriendColor
    end
    if player.Team then
        local ok, color = pcall(function()
            return player.Team.TeamColor.Color
        end)
        if ok and color then
            return color
        end
    end
    return isEnemy(player) and Config.ESP.EnemyColor or Config.ESP.FriendColor
end

local function targetPart(character)
    if not character then
        return nil
    end
    local preferred = character:FindFirstChild(Config.Aim.TargetPart)
    if preferred and preferred:IsA("BasePart") then
        return preferred
    end
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    return nil
end

local function screenPoint(position)
    local point, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(point.X, point.Y), onScreen, point.Z
end

local function centerPoint()
    local view = Camera.ViewportSize
    return Vector2.new(view.X * 0.5, view.Y * 0.5)
end

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

local function visibleTarget(part, character)
    if not Config.Aim.VisibleCheck then
        return true
    end
    if not part or not character or not Camera then
        return false
    end
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local origin = Camera.CFrame.Position
    local direction = part.Position - origin
    if direction.Magnitude <= 0.001 then
        return true
    end
    local hit = Workspace:Raycast(origin, direction, RayParams)
    if not hit then
        return true
    end
    if Config.Aim.VisibleCheck then
        return hit.Instance == part
    end
    return hit.Instance:IsDescendantOf(character)
end

local function validAimTarget(player)
    if not Config.Aim.Enabled then
        return false
    end
    if not player or player == LocalPlayer then
        return false
    end
    local character = player.Character
    if not character or not alive(character) then
        return false
    end
    if Config.Aim.TeamCheck and not isEnemy(player) then
        return false
    end
    local part = targetPart(character)
    if not part then
        return false
    end
    local root = getRoot()
    if not root then
        return false
    end
    local distance = (root.Position - part.Position).Magnitude
    if distance > Config.Aim.MaxDistance then
        return false
    end
    local point, onScreen, depth = screenPoint(part.Position)
    if depth <= 0 then
        return false
    end
    if Config.Aim.RequireOnScreen and not onScreen then
        return false
    end
    local offset = (point - centerPoint()).Magnitude
    if offset > Config.Aim.FOV then
        return false
    end
    if Config.Aim.VisibleCheck and not visibleTarget(part, character) then
        return false
    end
    return true
end

local function candidateScore(player)
    local part = targetPart(player.Character)
    if not part then
        return math.huge
    end
    local point, _, depth = screenPoint(part.Position)
    if depth <= 0 then
        return math.huge
    end
    local offset = (point - centerPoint()).Magnitude
    if Config.Aim.Priority == "Distance" then
        local root = getRoot()
        return root and (root.Position - part.Position).Magnitude or math.huge
    elseif Config.Aim.Priority == "Health" then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health or math.huge
    end
    return offset
end

local function acquireTarget(force)
    if not Config.Aim.Enabled then
        State.AimTarget = nil
        State.AimTargetPart = nil
        return nil
    end

    local now = os.clock()
    if not force and now - State.LastAimScan < Config.Aim.TargetRefresh then
        return State.AimTarget
    end
    State.LastAimScan = now

    if Config.Aim.Sticky and State.AimTarget and validAimTarget(State.AimTarget) then
        local p = targetPart(State.AimTarget.Character)
        if p then
            local point, onScreen, depth = screenPoint(p.Position)
            local offset = (point - centerPoint()).Magnitude
            if depth > 0 and onScreen and offset <= Config.Aim.StickyBreakFOV then
                State.AimTargetPart = p
                return State.AimTarget
            end
        end
    end

    local best = nil
    local bestScore = math.huge
    local checked = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if checked >= Config.Aim.MaxCandidates then
            break
        end
        if validAimTarget(player) then
            checked += 1
            local score = candidateScore(player)
            if score < bestScore then
                bestScore = score
                best = player
            end
        end
    end

    State.AimTarget = best
    State.AimTargetPart = best and targetPart(best.Character) or nil
    return best
end

local function predictedPoint(part)
    if not part then
        return nil
    end
    local position = part.Position
    if not Config.Aim.Lead then
        return position
    end
    local velocity = part.AssemblyLinearVelocity
    return position + velocity * Config.Aim.Prediction
end

local function aimStep()
    if not Config.Master or not Config.Aim.Enabled then
        return
    end
    if Config.Aim.Hold and not State.AimHeld then
        return
    end

    local target = acquireTarget(false)
    if not target or not validAimTarget(target) then
        State.AimTarget = nil
        State.AimTargetPart = nil
        return
    end

    local part = targetPart(target.Character)
    if not part then
        return
    end

    -- Re-check the actual target point immediately before camera motion.
    if Config.Aim.VisibleCheck and not visibleTarget(part, target.Character) then
        State.AimTarget = nil
        State.AimTargetPart = nil
        return
    end

    local point = predictedPoint(part)
    if not point then
        return
    end

    local origin = Camera.CFrame.Position
    local delta = point - origin
    if delta.Magnitude <= 0.001 then
        return
    end

    local desired = CFrame.lookAt(origin, point, Camera.CFrame.UpVector)
    local current = Camera.CFrame

    -- Requested fast default: 0.04. A smaller value approaches the desired rotation
    -- more aggressively because alpha is derived as 1 - smoothing.
    local smoothing = clamp(Config.Aim.Smoothing, 0, 1)
    local alpha
    if smoothing <= 0 then
        alpha = 1
    else
        alpha = clamp(1 - smoothing, 0, 1)
    end

    Camera.CFrame = current:Lerp(desired, alpha)
end

local function saveCharacterState()
    local hum = getHumanoid()
    if hum then
        State.Original.WalkSpeed = hum.WalkSpeed
        State.Original.JumpPower = hum.JumpPower
        State.Original.HipHeight = hum.HipHeight
    end
end

local function applyMovement()
    local hum = getHumanoid()
    if not hum then
        return
    end
    if Config.Movement.Speed then
        hum.WalkSpeed = Config.Movement.SpeedValue
    else
        hum.WalkSpeed = State.Original.WalkSpeed
    end
    hum.UseJumpPower = true
    if Config.Movement.JumpBoost then
        hum.JumpPower = Config.Movement.JumpPower
    else
        hum.JumpPower = State.Original.JumpPower
    end
end

local function applyNoclip()
    local character = getCharacter()
    if not character then
        return
    end
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CanCollide = not Config.Movement.Noclip
        end
    end
end

local function flyStep()
    if not Config.Master or not Config.Movement.Fly then
        return
    end
    local hum = getHumanoid()
    local root = getRoot()
    if not hum or not root then
        return
    end

    local move = hum.MoveDirection
    local look = Camera.CFrame.LookVector
    local right = Camera.CFrame.RightVector
    local forward = Vector3.new(look.X, 0, look.Z)
    local side = Vector3.new(right.X, 0, right.Z)
    if forward.Magnitude > 0 then
        forward = forward.Unit
    end
    if side.Magnitude > 0 then
        side = side.Unit
    end

    local direction = side * move.X + forward * (-move.Z)
    local vertical = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        vertical += 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        vertical -= 1
    end

    if State.MobileFlyVertical then
        vertical = State.MobileFlyVertical
    end

    direction += Vector3.new(0, vertical, 0)
    if direction.Magnitude > 1 then
        direction = direction.Unit
    end

    root.AssemblyLinearVelocity = direction * Config.Movement.FlySpeed
    hum:ChangeState(Enum.HumanoidStateType.Physics)
end

local function setFly(v)
    Config.Movement.Fly = v
    if not v then
        local hum = getHumanoid()
        local root = getRoot()
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
        end
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end

local function setNoclip(v)
    Config.Movement.Noclip = v
    applyNoclip()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CyborgHackPanel"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 1000
ScreenGui.Parent = PlayerGui

local function new(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function corner(parent, radius)
    return new("UICorner", {
        CornerRadius = UDim.new(0, radius or Config.UI.Radius),
    }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return new("UIStroke", {
        Color = color,
        Transparency = transparency or 0.5,
        Thickness = thickness or 1,
    }, parent)
end

local function tween(obj, props, duration)
    local t = TweenService:Create(obj, TweenInfo.new(duration or Config.UI.Anim, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local Root = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
}, ScreenGui)

local MenuButton = new("TextButton", {
    Name = "MenuButton",
    AutoButtonColor = false,
    BackgroundColor3 = Config.UI.Panel2,
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(92, 42),
    Position = UDim2.new(0, 18, 1, -60),
    Font = Enum.Font.GothamBold,
    Text = "MENU",
    TextColor3 = Config.UI.Text,
    TextSize = 11,
    Visible = false,
    Active = true,
    ZIndex = 200,
}, Root)
corner(MenuButton, 12)
stroke(MenuButton, Config.UI.Accent, 0.35, 1)

local MenuShadow = new("Frame", {
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(92, 42),
    Position = UDim2.new(0, 22, 1, -56),
    Visible = false,
    ZIndex = 199,
}, Root)
corner(MenuShadow, 12)

local Main = new("Frame", {
    Name = "Main",
    BackgroundColor3 = Config.UI.Panel,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(Config.UI.Width, Config.UI.Height),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    ClipsDescendants = true,
    ZIndex = 20,
}, Root)
corner(Main, Config.UI.Radius)
stroke(Main, Config.UI.Accent, 0.45, 1)

local MainScale = new("UIScale", {Scale = 1}, Main)

local Header = new("Frame", {
    BackgroundColor3 = Config.UI.Panel2,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 58),
    ZIndex = 21,
}, Main)
corner(Header, Config.UI.Radius)

local Title = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(16, 8),
    Size = UDim2.new(1, -150, 0, 20),
    Font = Enum.Font.GothamBlack,
    Text = "CYBORG",
    TextColor3 = Config.UI.Text,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 22,
}, Header)

local Subtitle = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(17, 29),
    Size = UDim2.new(1, -180, 0, 15),
    Font = Enum.Font.Gotham,
    Text = "HACK PANEL  //  ONLINE",
    TextColor3 = Config.UI.Muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 22,
}, Header)

local FPSLabel = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -145, 0, 11),
    Size = UDim2.fromOffset(80, 16),
    Font = Enum.Font.GothamBold,
    Text = "60 FPS",
    TextColor3 = Config.UI.Success,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 22,
}, Header)

local HideButton = new("TextButton", {
    AutoButtonColor = false,
    BackgroundColor3 = Config.UI.Surface,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -43, 0, 11),
    Size = UDim2.fromOffset(26, 26),
    Font = Enum.Font.GothamBold,
    Text = "−",
    TextColor3 = Config.UI.Text,
    TextSize = 16,
    ZIndex = 24,
}, Header)
corner(HideButton, 8)

local Sidebar = new("Frame", {
    BackgroundColor3 = Config.UI.Panel2,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 58),
    Size = UDim2.new(0, 124, 1, -58),
    ZIndex = 21,
}, Main)

local Content = new("ScrollingFrame", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 124, 0, 58),
    Size = UDim2.new(1, -124, 1, -58),
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Config.UI.Accent,
    Active = true,
    ZIndex = 22,
}, Main)

new("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingBottom = UDim.new(0, 16),
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
}, Content)

local ContentLayout = new("UIListLayout", {
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Content)

local TabButtons = {}
local Pages = {}

local function createTab(name, icon)
    local button = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Config.UI.Panel2,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -16, 0, 34),
        Position = UDim2.fromOffset(8, 0),
        Font = Enum.Font.GothamBold,
        Text = icon .. "  " .. name,
        TextColor3 = Config.UI.Muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
    }, Sidebar)
    corner(button, 8)
    TabButtons[name] = button
    connect(button.Activated, function()
        if State.ActiveTab == name then
            return
        end
        State.ActiveTab = name
        for tabName, tab in pairs(TabButtons) do
            tab.BackgroundColor3 = tabName == name and Config.UI.Accent or Config.UI.Panel2
            tab.BackgroundTransparency = tabName == name and 0.78 or 0.3
            tab.TextColor3 = tabName == name and Config.UI.Text or Config.UI.Muted
        end
        for pageName, page in pairs(Pages) do
            page.Visible = pageName == name
        end
        Content.CanvasPosition = Vector2.new(0, 0)
    end)
    return button
end

createTab("Combat", "⌖")
createTab("ESP", "◈")
createTab("Move", "⇧")
createTab("System", "⚙")

local function page(name)
    local p = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = name == "Combat",
        ZIndex = 22,
    }, Content)
    new("UIListLayout", {
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, p)
    Pages[name] = p
    return p
end

local CombatPage = page("Combat")
local ESPPage = page("ESP")
local MovePage = page("Move")
local SystemPage = page("System")

local function section(parent, title, subtitle)
    local box = new("Frame", {
        BackgroundColor3 = Config.UI.Panel2,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 23,
    }, parent)
    corner(box, 9)
    stroke(box, Config.UI.Accent, 0.86, 1)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 9),
        Size = UDim2.new(1, -24, 0, 17),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = Config.UI.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 24,
    }, box)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 26),
        Size = UDim2.new(1, -24, 0, 14),
        Font = Enum.Font.Gotham,
        Text = subtitle or "",
        TextColor3 = Config.UI.Muted,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 24,
    }, box)
    local holder = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(9, 47),
        Size = UDim2.new(1, -18, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 24,
    }, box)
    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)
    new("UIPadding", {
        PaddingBottom = UDim.new(0, 10),
    }, holder)
    return holder
end

local function toggle(parent, label, stateValue, callback, note)
    local row = new("Frame", {
        BackgroundColor3 = Config.UI.Surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, note and 48 or 36),
        ZIndex = 24,
    }, parent)
    corner(row, 7)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(11, note and 6 or 9),
        Size = UDim2.new(1, -85, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = label,
        TextColor3 = Config.UI.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 25,
    }, row)

    if note then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(11, 24),
            Size = UDim2.new(1, -90, 0, 13),
            Font = Enum.Font.Gotham,
            Text = note,
            TextColor3 = Config.UI.Muted,
            TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 25,
        }, row)
    end

    local button = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = stateValue and Config.UI.Success or Config.UI.Panel,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -61, 0.5, -10),
        Size = UDim2.fromOffset(49, 20),
        Font = Enum.Font.GothamBold,
        Text = stateValue and "ON" or "OFF",
        TextColor3 = stateValue and Color3.new(1, 1, 1) or Config.UI.Muted,
        TextSize = 8,
        ZIndex = 26,
    }, row)
    corner(button, 8)

    local current = stateValue
    local function render()
        button.BackgroundColor3 = current and Config.UI.Success or Config.UI.Panel
        button.TextColor3 = current and Color3.new(1, 1, 1) or Config.UI.Muted
        button.Text = current and "ON" or "OFF"
    end

    connect(button.Activated, function()
        current = not current
        render()
        if callback then
            callback(current)
        end
    end)

    return row, function(v)
        current = v
        render()
    end
end

local function slider(parent, label, value, minValue, maxValue, callback, digits)
    local row = new("Frame", {
        BackgroundColor3 = Config.UI.Surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 52),
        ZIndex = 24,
    }, parent)
    corner(row, 7)

    local title = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(11, 7),
        Size = UDim2.new(0.55, 0, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = label,
        TextColor3 = Config.UI.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 25,
    }, row)

    local valueLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.55, 0, 0, 7),
        Size = UDim2.new(0.42, -10, 0, 16),
        Font = Enum.Font.GothamBold,
        TextColor3 = Config.UI.Accent,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 25,
    }, row)
    valueLabel.Text = string.format(digits == 0 and "%.0f" or "%.2f", value)

    local track = new("Frame", {
        BackgroundColor3 = Config.UI.Panel,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(11, 32),
        Size = UDim2.new(1, -22, 0, 6),
        ZIndex = 25,
    }, row)
    corner(track, 4)

    local fill = new("Frame", {
        BackgroundColor3 = Config.UI.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new((value - minValue) / (maxValue - minValue), 0, 1, 0),
        ZIndex = 26,
    }, track)
    corner(fill, 4)

    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - minValue) / (maxValue - minValue), 0, 0.5, 0),
        Size = UDim2.fromOffset(10, 10),
        ZIndex = 27,
    }, track)
    corner(knob, 6)

    local dragging = false

    local function setValue(v)
        local next = clamp(v, minValue, maxValue)
        local alpha = (next - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = string.format(digits == 0 and "%.0f" or "%.2f", next)
        if callback then
            callback(next)
        end
    end

    local function inputValue(input)
        local x = input.Position.X
        local left = track.AbsolutePosition.X
        local width = math.max(track.AbsoluteSize.X, 1)
        local alpha = clamp((x - left) / width, 0, 1)
        return lerpNumber(minValue, maxValue, alpha)
    end

    connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setValue(inputValue(input))
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setValue(inputValue(input))
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return row, setValue
end

local function action(parent, text, callback)
    local button = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Config.UI.Surface,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 34),
        Font = Enum.Font.GothamBold,
        Text = text,
        TextColor3 = Config.UI.Text,
        TextSize = 9,
        ZIndex = 24,
    }, parent)
    corner(button, 7)
    stroke(button, Config.UI.AccentDark, 0.7, 1)
    connect(button.Activated, function()
        tween(button, {BackgroundTransparency = 0}, 0.06)
        task.delay(0.07, function()
            if button.Parent then
                tween(button, {BackgroundTransparency = 0.08}, 0.1)
            end
        end)
        if callback then
            callback()
        end
    end)
    return button
end

local aimSection = section(CombatPage, "AIM CORE", "Fast acquisition + strict target visibility")
toggle(aimSection, "Aimbot", Config.Aim.Enabled, function(v)
    Config.Aim.Enabled = v
    if not v then
        State.AimTarget = nil
        State.AimTargetPart = nil
    end
end, "Only locks targets whose selected aim point is visible")
toggle(aimSection, "Hold To Aim", Config.Aim.Hold, function(v)
    Config.Aim.Hold = v
end, "Right mouse on PC / AIM button on mobile")
toggle(aimSection, "Visibility Check", Config.Aim.VisibleCheck, function(v)
    Config.Aim.VisibleCheck = v
end, "Blocks targets behind walls and map geometry")
toggle(aimSection, "Team Check", Config.Aim.TeamCheck, function(v)
    Config.Aim.TeamCheck = v
end)
toggle(aimSection, "Sticky Target", Config.Aim.Sticky, function(v)
    Config.Aim.Sticky = v
end)
slider(aimSection, "FOV", Config.Aim.FOV, 20, 500, function(v)
    Config.Aim.FOV = v
end, 0)
slider(aimSection, "Smoothness", Config.Aim.Smoothing, 0, 0.25, function(v)
    Config.Aim.Smoothing = v
end, 2)
slider(aimSection, "Prediction", Config.Aim.Prediction, 0, 0.2, function(v)
    Config.Aim.Prediction = v
end, 3)
slider(aimSection, "Max Distance", Config.Aim.MaxDistance, 100, 2500, function(v)
    Config.Aim.MaxDistance = v
end, 0)

local targetSection = section(CombatPage, "TARGET LOGIC", "Choose the lock behavior")
action(targetSection, "PRIORITY  •  CROSSHAIR", function()
    Config.Aim.Priority = "Crosshair"
end)
action(targetSection, "PRIORITY  •  DISTANCE", function()
    Config.Aim.Priority = "Distance"
end)
action(targetSection, "PRIORITY  •  LOWEST HEALTH", function()
    Config.Aim.Priority = "Health"
end)
action(targetSection, "TARGET PART  •  HEAD", function()
    Config.Aim.TargetPart = "Head"
end)
action(targetSection, "TARGET PART  •  ROOT", function()
    Config.Aim.TargetPart = "HumanoidRootPart"
end)

local espSection = section(ESPPage, "ESP CORE", "Highlights, tracers and readable combat intel")
toggle(espSection, "ESP", Config.ESP.Enabled, function(v)
    Config.ESP.Enabled = v
end)
toggle(espSection, "Highlights", Config.ESP.Highlights, function(v)
    Config.ESP.Highlights = v
end)
toggle(espSection, "Tracers", Config.ESP.Tracers, function(v)
    Config.ESP.Tracers = v
end)
toggle(espSection, "Names", Config.ESP.Names, function(v)
    Config.ESP.Names = v
end)
toggle(espSection, "Health", Config.ESP.Health, function(v)
    Config.ESP.Health = v
end)
toggle(espSection, "Distance", Config.ESP.Distance, function(v)
    Config.ESP.Distance = v
end)
toggle(espSection, "Weapon", Config.ESP.Weapon, function(v)
    Config.ESP.Weapon = v
end)
toggle(espSection, "Team Check", Config.ESP.TeamCheck, function(v)
    Config.ESP.TeamCheck = v
end)
slider(espSection, "ESP Distance", Config.ESP.MaxDistance, 100, 2500, function(v)
    Config.ESP.MaxDistance = v
end, 0)
slider(espSection, "Fill Transparency", Config.ESP.FillTransparency, 0.1, 1, function(v)
    Config.ESP.FillTransparency = v
end, 2)
slider(espSection, "Outline Transparency", Config.ESP.OutlineTransparency, 0, 1, function(v)
    Config.ESP.OutlineTransparency = v
end, 2)
slider(espSection, "Tracer Thickness", Config.ESP.TracerThickness, 0.5, 4, function(v)
    Config.ESP.TracerThickness = v
end, 2)

local moveSection = section(MovePage, "MOVEMENT", "Local movement controls")
toggle(moveSection, "Speed", Config.Movement.Speed, function(v)
    Config.Movement.Speed = v
    applyMovement()
end)
slider(moveSection, "WalkSpeed", Config.Movement.SpeedValue, 16, 100, function(v)
    Config.Movement.SpeedValue = v
    applyMovement()
end, 0)
toggle(moveSection, "Fly", Config.Movement.Fly, function(v)
    setFly(v)
end)
slider(moveSection, "Fly Speed", Config.Movement.FlySpeed, 15, 180, function(v)
    Config.Movement.FlySpeed = v
end, 0)
toggle(moveSection, "Noclip", Config.Movement.Noclip, function(v)
    setNoclip(v)
end)
toggle(moveSection, "Jump Boost", Config.Movement.JumpBoost, function(v)
    Config.Movement.JumpBoost = v
    applyMovement()
end)
slider(moveSection, "Jump Power", Config.Movement.JumpPower, 50, 150, function(v)
    Config.Movement.JumpPower = v
    applyMovement()
end, 0)
toggle(moveSection, "Infinite Jump", Config.Movement.InfiniteJump, function(v)
    Config.Movement.InfiniteJump = v
end)

action(MovePage, "RESET MOVEMENT", function()
    Config.Movement.Speed = false
    Config.Movement.Fly = false
    Config.Movement.Noclip = false
    Config.Movement.JumpBoost = false
    Config.Movement.InfiniteJump = false
    applyMovement()
    applyNoclip()
end)

local systemSection = section(SystemPage, "SYSTEM", "Core state and controls")
toggle(systemSection, "Master", Config.Master, function(v)
    Config.Master = v
end)
toggle(systemSection, "FOV Circle", Config.Aim.FOVVisible, function(v)
    Config.Aim.FOVVisible = v
end)
action(systemSection, "RESET AIM", function()
    Config.Aim.Enabled = false
    Config.Aim.Smoothing = 0.04
    Config.Aim.FOV = 180
    Config.Aim.Prediction = 0.075
    Config.Aim.TargetPart = "Head"
    Config.Aim.Priority = "Crosshair"
    State.AimTarget = nil
    State.AimTargetPart = nil
end)
action(systemSection, "DISABLE ALL", function()
    Config.Aim.Enabled = false
    Config.ESP.Enabled = false
    Config.Movement.Speed = false
    Config.Movement.Fly = false
    Config.Movement.Noclip = false
    Config.Movement.JumpBoost = false
    Config.Movement.InfiniteJump = false
    State.AimTarget = nil
    State.AimTargetPart = nil
    applyMovement()
    applyNoclip()
end)

-- FOV display
local FOV = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromOffset(Config.Aim.FOV * 2, Config.Aim.FOV * 2),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Visible = false,
    ZIndex = 10,
}, Root)
corner(FOV, 999)
stroke(FOV, Config.UI.Accent, 0.25, 1)

local TargetIndicator = new("TextLabel", {
    BackgroundColor3 = Config.UI.Panel2,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(180, 30),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 18),
    Font = Enum.Font.GothamBold,
    Text = "TARGET: NONE",
    TextColor3 = Config.UI.Text,
    TextSize = 9,
    Visible = false,
    ZIndex = 80,
}, Root)
corner(TargetIndicator, 8)
stroke(TargetIndicator, Config.UI.Accent, 0.5, 1)

local MobileLayer = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Visible = State.Mobile,
    ZIndex = 100,
}, Root)

local MobileAim
local MobileMenu
local MobileFly
local MobileNoclip
local MobileSpeed
local FlyUp
local FlyDown

local function mobileButton(name, text, pos)
    local button = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Config.UI.Panel2,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(76, 44),
        Position = pos,
        Font = Enum.Font.GothamBold,
        Text = text,
        TextColor3 = Config.UI.Text,
        TextSize = 9,
        Active = true,
        Selectable = false,
        ZIndex = 101,
    }, MobileLayer)
    corner(button, 11)
    stroke(button, Config.UI.Accent, 0.5, 1)
    return button
end

if State.Mobile then
    MobileAim = mobileButton("Aim", "AIM", UDim2.new(1, -178, 1, -135))
    MobileFly = mobileButton("Fly", "FLY", UDim2.new(1, -92, 1, -135))
    MobileNoclip = mobileButton("Noclip", "NOCLIP", UDim2.new(1, -178, 1, -80))
    MobileSpeed = mobileButton("Speed", "SPEED", UDim2.new(1, -92, 1, -80))
    FlyUp = mobileButton("FlyUp", "▲", UDim2.new(1, -264, 1, -135))
    FlyDown = mobileButton("FlyDown", "▼", UDim2.new(1, -264, 1, -80))
    MobileMenu = mobileButton("Menu", "MENU", UDim2.new(0, 16, 1, -80))

    connect(MobileAim.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            State.AimHeld = true
        end
    end)
    connect(MobileAim.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            State.AimHeld = false
        end
    end)

    connect(MobileFly.Activated, function()
        setFly(not Config.Movement.Fly)
    end)
    connect(MobileNoclip.Activated, function()
        setNoclip(not Config.Movement.Noclip)
    end)
    connect(MobileSpeed.Activated, function()
        Config.Movement.Speed = not Config.Movement.Speed
        applyMovement()
    end)
    connect(FlyUp.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            State.MobileFlyVertical = 1
        end
    end)
    connect(FlyUp.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            State.MobileFlyVertical = 0
        end
    end)
    connect(FlyDown.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            State.MobileFlyVertical = -1
        end
    end)
    connect(FlyDown.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            State.MobileFlyVertical = 0
        end
    end)
    connect(MobileMenu.Activated, function()
        State.MenuOpen = not State.MenuOpen
        Main.Visible = State.MenuOpen
        MenuButton.Visible = not State.MenuOpen
        MenuShadow.Visible = not State.MenuOpen
    end)
end

local function updateMobileVisuals()
    if not State.Mobile then
        return
    end
    local scale = clamp(Config.Mobile.ButtonScale, 0.8, 1.35)
    for _, button in ipairs({MobileAim, MobileFly, MobileNoclip, MobileSpeed, FlyUp, FlyDown, MobileMenu}) do
        if button then
            button.Size = UDim2.fromOffset(76 * scale, 44 * scale)
        end
    end
end

-- Menu drag on desktop/mobile.
local dragging = false
local dragInput = nil
local dragStart = nil
local startPosition = nil

connect(Header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

connect(Header.InputChanged, function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

connect(UserInputService.InputChanged, function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

local function hideMenu()
    State.MenuOpen = false
    Main.Visible = false
    FOV.Visible = false
    TargetIndicator.Visible = false
    if MobileLayer then
        MobileLayer.Visible = false
    end
    MenuButton.Visible = true
    MenuShadow.Visible = true
end

local function showMenu()
    State.MenuOpen = true
    Main.Visible = true
    if MobileLayer then
        MobileLayer.Visible = State.Mobile
    end
    MenuButton.Visible = false
    MenuShadow.Visible = false
end

connect(HideButton.Activated, hideMenu)
connect(MenuButton.Activated, showMenu)

-- Draggable MENU button when menu is hidden.
local menuDragging = false
local menuDragStart
local menuStartPos
local menuDragInput

connect(MenuButton.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        menuDragging = true
        menuDragStart = input.Position
        menuStartPos = MenuButton.Position
    end
end)

connect(MenuButton.InputChanged, function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        menuDragInput = input
    end
end)

connect(UserInputService.InputChanged, function(input)
    if menuDragging and input == menuDragInput then
        local delta = input.Position - menuDragStart
        local pos = UDim2.new(
            menuStartPos.X.Scale,
            menuStartPos.X.Offset + delta.X,
            menuStartPos.Y.Scale,
            menuStartPos.Y.Offset + delta.Y
        )
        MenuButton.Position = pos
        MenuShadow.Position = UDim2.new(pos.X.Scale, pos.X.Offset + 4, pos.Y.Scale, pos.Y.Offset + 2)
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        menuDragging = false
    end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if processed then
        return
    end
    if input.KeyCode == Config.MenuKey then
        if State.MenuOpen then
            hideMenu()
        else
            showMenu()
        end
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.AimHeld = true
    end
    if Config.Movement.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.AimHeld = false
    end
end)

local function responsive()
    if not Camera then
        return
    end
    local now = os.clock()
    if now - State.LastResponsive < 0.2 then
        return
    end
    State.LastResponsive = now

    local view = Camera.ViewportSize
    State.Mobile = UserInputService.TouchEnabled and view.X < 850

    local width
    local height
    if State.Mobile then
        width = math.min(Config.UI.MobileWidth, math.max(view.X - 14, 300))
        height = math.min(Config.UI.MobileHeight, math.max(view.Y - 14, 360))
        Main.Size = UDim2.fromOffset(width, height)
        MainScale.Scale = clamp(math.min(view.X / 410, view.Y / 525), 0.74, 1)
        Sidebar.Size = UDim2.new(0, 108, 1, -58)
        Content.Position = UDim2.new(0, 108, 0, 58)
        Content.Size = UDim2.new(1, -108, 1, -58)
        Title.TextSize = 16
        Subtitle.Text = "MOBILE // CYBORG CORE"
    else
        Main.Size = UDim2.fromOffset(Config.UI.Width, Config.UI.Height)
        MainScale.Scale = clamp(math.min(view.X / 850, view.Y / 620), 0.86, 1)
        Sidebar.Size = UDim2.new(0, 124, 1, -58)
        Content.Position = UDim2.new(0, 124, 0, 58)
        Content.Size = UDim2.new(1, -124, 1, -58)
        Title.TextSize = 18
        Subtitle.Text = "HACK PANEL  //  ONLINE"
    end

    updateMobileVisuals()
end

local function updateFOV()
    if not Camera then
        return
    end
    FOV.Size = UDim2.fromOffset(Config.Aim.FOV * 2, Config.Aim.FOV * 2)
    FOV.Position = UDim2.fromOffset(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    FOV.Visible = State.MenuOpen and Config.Master and Config.Aim.Enabled and Config.Aim.FOVVisible
end

local function updateTargetIndicator()
    local target = State.AimTarget
    local show = State.MenuOpen and Config.Master and Config.Aim.Enabled and target ~= nil and validAimTarget(target)
    TargetIndicator.Visible = show
    if not show then
        return
    end
    TargetIndicator.Text = "TARGET: " .. (target.DisplayName ~= "" and target.DisplayName or target.Name)
    TargetIndicator.TextColor3 = teamColor(target)
end

local function weaponName(player)
    local char = player.Character
    if not char then
        return nil
    end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            return child.Name
        end
    end
    return nil
end

local function createESP(player)
    if State.ESP[player] then
        return State.ESP[player]
    end
    local folder = new("Folder", {Name = "CyborgESP_" .. tostring(player.UserId)}, ScreenGui)

    local highlight
    if Config.ESP.Highlights then
        highlight = new("Highlight", {
            Enabled = false,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency = Config.ESP.FillTransparency,
            OutlineTransparency = Config.ESP.OutlineTransparency,
        }, folder)
    end

    local billboard = new("BillboardGui", {
        Enabled = false,
        Size = UDim2.fromOffset(165, 72),
        AlwaysOnTop = true,
        LightInfluence = 0,
        StudsOffset = Vector3.new(0, 3.25, 0),
    }, folder)

    local stack = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }, billboard)
    new("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    }, stack)

    local nameLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 17),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextStrokeTransparency = 0.5,
        TextColor3 = Config.UI.Text,
        Text = "",
    }, stack)

    local hpLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 15),
        Font = Enum.Font.GothamMedium,
        TextSize = 9,
        TextStrokeTransparency = 0.6,
        TextColor3 = Config.UI.Text,
        Text = "",
    }, stack)

    local distanceLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 15),
        Font = Enum.Font.Gotham,
        TextSize = 8,
        TextStrokeTransparency = 0.7,
        TextColor3 = Config.UI.Muted,
        Text = "",
    }, stack)

    local weaponLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 15),
        Font = Enum.Font.Gotham,
        TextSize = 8,
        TextStrokeTransparency = 0.7,
        TextColor3 = Config.UI.Warning,
        Text = "",
    }, stack)

    local a0 = new("Attachment", {}, Workspace.Terrain)
    local a1 = new("Attachment", {}, Workspace.Terrain)
    local beam = new("Beam", {
        Enabled = false,
        Attachment0 = a0,
        Attachment1 = a1,
        FaceCamera = true,
        LightInfluence = 0,
        Segments = 1,
        Width0 = Config.ESP.TracerThickness,
        Width1 = Config.ESP.TracerThickness,
        Transparency = NumberSequence.new(0.2),
    }, folder)

    local entry = {
        Player = player,
        Folder = folder,
        Highlight = highlight,
        Billboard = billboard,
        Name = nameLabel,
        HP = hpLabel,
        Distance = distanceLabel,
        Weapon = weaponLabel,
        A0 = a0,
        A1 = a1,
        Beam = beam,
    }
    State.ESP[player] = entry
    return entry
end

local function destroyESP(player)
    local entry = State.ESP[player]
    if not entry then
        return
    end
    State.ESP[player] = nil
    if entry.Folder then
        pcall(function()
            entry.Folder:Destroy()
        end)
    end
    if entry.A0 then
        pcall(function()
            entry.A0:Destroy()
        end)
    end
    if entry.A1 then
        pcall(function()
            entry.A1:Destroy()
        end)
    end
end

local function updateESPEntry(entry)
    local player = entry.Player
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and (char:FindFirstChild("Head") or root)

    local hidden = not Config.ESP.Enabled
    if not char or not root or not alive(char) then
        hidden = true
    end
    if Config.ESP.TeamCheck and not isEnemy(player) then
        hidden = true
    end

    if hidden then
        if entry.Highlight then
            entry.Highlight.Enabled = false
        end
        entry.Billboard.Enabled = false
        entry.Beam.Enabled = false
        return
    end

    local localRoot = getRoot()
    if not localRoot then
        return
    end

    local distance = (localRoot.Position - root.Position).Magnitude
    if distance > Config.ESP.MaxDistance then
        if entry.Highlight then
            entry.Highlight.Enabled = false
        end
        entry.Billboard.Enabled = false
        entry.Beam.Enabled = false
        return
    end

    local color = teamColor(player)

    if entry.Highlight then
        entry.Highlight.Adornee = char
        entry.Highlight.Enabled = Config.ESP.Highlights
        entry.Highlight.FillColor = color
        entry.Highlight.OutlineColor = color
        entry.Highlight.FillTransparency = Config.ESP.FillTransparency
        entry.Highlight.OutlineTransparency = Config.ESP.OutlineTransparency
    end

    if head then
        entry.Billboard.Adornee = head
        entry.Billboard.Enabled = Config.ESP.Names or Config.ESP.Health or Config.ESP.Distance or Config.ESP.Weapon

        entry.Name.Visible = Config.ESP.Names
        entry.Name.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
        entry.Name.TextColor3 = color

        local hum = char:FindFirstChildOfClass("Humanoid")
        local hp = hum and hum.Health or 0
        local maxHp = hum and hum.MaxHealth or 100
        local percent = math.floor(clamp(hp / math.max(maxHp, 1), 0, 1) * 100 + 0.5)

        entry.HP.Visible = Config.ESP.Health
        entry.HP.Text = "HP: " .. tostring(percent) .. "%"
        entry.HP.TextColor3 = Color3.new(1 - percent / 100, percent / 100, 0.4)

        entry.Distance.Visible = Config.ESP.Distance
        entry.Distance.Text = string.format("%d m", math.floor(distance + 0.5))

        local weapon = weaponName(player)
        entry.Weapon.Visible = Config.ESP.Weapon and weapon ~= nil
        entry.Weapon.Text = weapon and ("▸ " .. weapon) or ""
    end

    if Config.ESP.Tracers then
        entry.A0.WorldPosition = Camera.CFrame.Position
        entry.A1.WorldPosition = root.Position
        entry.Beam.Color = ColorSequence.new(color)
        entry.Beam.Width0 = Config.ESP.TracerThickness
        entry.Beam.Width1 = Config.ESP.TracerThickness
        entry.Beam.Transparency = NumberSequence.new(0.2)
        entry.Beam.Enabled = true
    else
        entry.Beam.Enabled = false
    end
end

local function updateESP()
    if not Config.ESP.Enabled then
        for _, entry in pairs(State.ESP) do
            if entry.Highlight then
                entry.Highlight.Enabled = false
            end
            entry.Billboard.Enabled = false
            entry.Beam.Enabled = false
        end
        return
    end

    local entries = {}
    local localRoot = getRoot()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local distance = localRoot and root and (localRoot.Position - root.Position).Magnitude or math.huge
            if distance <= Config.ESP.MaxDistance and (not Config.ESP.TeamCheck or isEnemy(player)) then
                table.insert(entries, {Player = player, Distance = distance})
            end
        end
    end

    table.sort(entries, function(a, b)
        return a.Distance < b.Distance
    end)

    local allowed = math.min(#entries, Config.ESP.MaxRendered)
    local visibleSet = {}
    for index = 1, allowed do
        local player = entries[index].Player
        visibleSet[player] = true
        updateESPEntry(createESP(player))
    end

    for player, _ in pairs(State.ESP) do
        if not visibleSet[player] then
            local entry = State.ESP[player]
            if entry.Highlight then
                entry.Highlight.Enabled = false
            end
            entry.Billboard.Enabled = false
            entry.Beam.Enabled = false
            if player.Parent ~= Players then
                destroyESP(player)
            end
        end
    end
end

connect(Players.PlayerRemoving, destroyESP)
connect(Players.PlayerAdded, function(player)
    if Config.ESP.Enabled then
        createESP(player)
    end
end)

local function onCharacterAdded()
    task.wait(0.2)
    saveCharacterState()
    applyMovement()
    applyNoclip()
    State.AimTarget = nil
    State.AimTargetPart = nil
end

connect(LocalPlayer.CharacterAdded, onCharacterAdded)
if LocalPlayer.Character then
    task.defer(onCharacterAdded, LocalPlayer.Character)
end

-- One consolidated render loop.
connect(RunService.RenderStepped, function(dt)
    if State.Destroyed then
        return
    end

    State.FPSTime += dt
    State.FPSFrames += 1
    if State.FPSTime >= 0.5 then
        State.FPS = math.floor(State.FPSFrames / State.FPSTime + 0.5)
        State.FPSTime = 0
        State.FPSFrames = 0
        FPSLabel.Text = tostring(State.FPS) .. " FPS"
        FPSLabel.TextColor3 = State.FPS < 40 and Config.UI.Warning or Config.UI.Success
    end

    responsive()

    if Config.Master then
        aimStep()
        flyStep()
    end

    local now = os.clock()
    if Config.Master and now - State.LastESPUpdate >= Config.ESP.UpdateRate then
        State.LastESPUpdate = now
        updateESP()
    end

    updateFOV()
    updateTargetIndicator()
end)

-- Initial state.
for tabName, button in pairs(TabButtons) do
    button.BackgroundColor3 = tabName == State.ActiveTab and Config.UI.Accent or Config.UI.Panel2
    button.BackgroundTransparency = tabName == State.ActiveTab and 0.78 or 0.3
    button.TextColor3 = tabName == State.ActiveTab and Config.UI.Text or Config.UI.Muted
end

responsive()
Main.Visible = true
MenuButton.Visible = false
MenuShadow.Visible = false

-- Public cleanup helper for your own testing tools.
_G.CyborgHackPanelCleanup = function()
    if State.Destroyed then
        return
    end
    State.Destroyed = true
    Config.Aim.Enabled = false
    Config.ESP.Enabled = false
    Config.Movement.Fly = false
    Config.Movement.Noclip = false
    Config.Movement.Speed = false
    Config.Movement.JumpBoost = false
    Config.Movement.InfiniteJump = false
    applyMovement()
    applyNoclip()
    for player, _ in pairs(State.ESP) do
        destroyESP(player)
    end
    for _, c in ipairs(State.Connections) do
        disconnect(c)
    end
    State.Connections = {}
    if ScreenGui then
        ScreenGui:Destroy()
    end
end
