--[[
    MSI.LUA - Config Menu
]]

local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- THEME - PURPLE/NEON
----------------------------------------------------------------
local THEME = {
    Background  = Color3.fromRGB(8, 5, 15),
    Panel       = Color3.fromRGB(15, 10, 30),
    PanelAlt    = Color3.fromRGB(25, 15, 45),
    Card        = Color3.fromRGB(20, 12, 35),
    Accent      = Color3.fromRGB(138, 43, 226),
    AccentDim   = Color3.fromRGB(100, 30, 180),
    AccentLight = Color3.fromRGB(180, 80, 255),
    Border      = Color3.fromRGB(60, 30, 90),
    TextPrimary = Color3.fromRGB(240, 230, 255),
    TextMuted   = Color3.fromRGB(180, 160, 200),
    TextDim     = Color3.fromRGB(100, 80, 130),
    ToggleOff   = Color3.fromRGB(50, 35, 80),
    White       = Color3.fromRGB(250, 245, 255),
    Success     = Color3.fromRGB(100, 220, 150),
    Warning     = Color3.fromRGB(255, 200, 80),
    Error       = Color3.fromRGB(255, 100, 120),
}

----------------------------------------------------------------
-- ICON ASSETS
----------------------------------------------------------------
local ICONS = {
    -- Rail Tabs
    Player     = "rbxassetid://119458470506233", -- User
    Visuals    = "rbxassetid://93378016140831",  -- Visuals
    Combat     = "rbxassetid://109963815197771", -- Miecz / Sword
    Movement   = "rbxassetid://78448098168568",  -- Bolt
    Misc       = "rbxassetid://78102496134558",  -- Gamepad
    Configs    = "rbxassetid://72796864087159",  -- Folder
    Settings   = "rbxassetid://75588823925922",  -- Settings
    Info       = "rbxassetid://96500516193754",  -- Info

    -- Header Buttons
    Save       = "rbxassetid://134737358151223", -- Upload
    Load       = "rbxassetid://122447194663309", -- Download
    Minimize   = "rbxassetid://123215247499660", -- Minimize
    Close      = "rbxassetid://76266647768647",  -- Close

    -- Tree
    ArrowRight = "rbxassetid://115516631702152", -- Expand/collapse (bazowo wskazuje w dol)
}

-- Apply icon safely so ImageTransparency is never left at default-hide
local function applyIcon(img, assetId, color)
    if not img then return end
    img.BackgroundTransparency = 1
    img.ImageTransparency = 0
    img.ScaleType = Enum.ScaleType.Fit
    if assetId and assetId ~= "" then
        img.Image = assetId
    end
    if color then
        img.ImageColor3 = color
    end
end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Border
    s.Thickness = thickness or 1
    s.Transparency = (transparency == nil) and 0.6 or transparency
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function toHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
end


-- Safe file API
local FileAPI = {}
do
    local hasFS = (typeof(writefile) == "function")
    FileAPI.available = hasFS
    FileAPI.folder = "MSI_Configs"

    if hasFS then
        pcall(function()
            if not isfolder(FileAPI.folder) then makefolder(FileAPI.folder) end
        end)
    end

    function FileAPI.path(name)
        return FileAPI.folder .. "/" .. name .. ".json"
    end

    function FileAPI.save(name, data)
        if not hasFS then return false, "no fs" end
        local ok, err = pcall(function()
            writefile(FileAPI.path(name), game:GetService("HttpService"):JSONEncode(data))
        end)
        return ok, err
    end

    function FileAPI.load(name)
        if not hasFS then return nil, "no fs" end
        local ok, data = pcall(function()
            if not isfile(FileAPI.path(name)) then return nil end
            local raw = readfile(FileAPI.path(name))
            return game:GetService("HttpService"):JSONDecode(raw)
        end)
        if ok then return data end
        return nil, data
    end

    function FileAPI.delete(name)
        if not hasFS then return false end
        local ok = pcall(function()
            if isfile(FileAPI.path(name)) then delfile(FileAPI.path(name)) end
        end)
        return ok
    end

    function FileAPI.list()
        if not hasFS then return {} end
        local ok, files = pcall(function()
            local all = listfiles(FileAPI.folder)
            local out = {}
            for _, f in ipairs(all) do
                local n = f:match("([^/\\]+)%.json$")
                if n then table.insert(out, n) end
            end
            table.sort(out)
            return out
        end)
        return ok and files or {}
    end

    function FileAPI.exists(name)
        if not hasFS then return false end
        local ok, e = pcall(function() return isfile(FileAPI.path(name)) end)
        return ok and e or false
    end

end

----------------------------------------------------------------
-- NOTIFICATION SYSTEM (UI theme matched)
----------------------------------------------------------------
local notifyHost
local watermark

local function notify(title, text, ntype, duration)
    ntype = ntype or "info"
    duration = duration or 3.5
    local color = ({
        info    = THEME.Accent,
        success = THEME.Success,
        warning = THEME.Warning,
        error   = THEME.Error,
    })[ntype] or THEME.Accent

    if not notifyHost then return end

    local hasBody = text and text ~= ""
    local h = hasBody and 58 or 42

    local toast = Instance.new("Frame")
    toast.Size = UDim2.fromOffset(280, h)
    toast.BackgroundColor3 = THEME.Card
    toast.BackgroundTransparency = 1
    toast.BorderSizePixel = 0
    toast.ClipsDescendants = true
    toast.ZIndex = 151
    toast.Parent = notifyHost
    corner(toast, 12)
    local toastStroke = stroke(toast, color, 1.5, 1)

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, -12)
    accentBar.Position = UDim2.fromOffset(6, 6)
    accentBar.BackgroundColor3 = color
    accentBar.BackgroundTransparency = 1
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 152
    accentBar.Parent = toast
    corner(accentBar, 2)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.fromOffset(16, hasBody and 10 or 12)
    titleLbl.Size = UDim2.new(1, -28, 0, 16)
    titleLbl.Text = title
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.ZIndex = 152
    titleLbl.Parent = toast

    local bodyLbl
    if hasBody then
        bodyLbl = Instance.new("TextLabel")
        bodyLbl.BackgroundTransparency = 1
        bodyLbl.Position = UDim2.fromOffset(16, 28)
        bodyLbl.Size = UDim2.new(1, -28, 0, 18)
        bodyLbl.Text = text
        bodyLbl.TextColor3 = THEME.TextMuted
        bodyLbl.TextTransparency = 1
        bodyLbl.Font = Enum.Font.Gotham
        bodyLbl.TextSize = 11
        bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
        bodyLbl.TextTruncate = Enum.TextTruncate.AtEnd
        bodyLbl.ZIndex = 152
        bodyLbl.Parent = toast
    end

    -- slide in from right
    toast.Position = UDim2.new(0, 40, 0, 0)
    TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.15,
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()
    TweenService:Create(toastStroke, TweenInfo.new(0.3), { Transparency = 0.35 }):Play()
    TweenService:Create(accentBar, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(titleLbl, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
    if bodyLbl then
        TweenService:Create(bodyLbl, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
    end

    task.delay(duration, function()
        if not toast.Parent then return end
        TweenService:Create(toast, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 50, 0, 0),
        }):Play()
        TweenService:Create(toastStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
        TweenService:Create(accentBar, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(titleLbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
        if bodyLbl then
            TweenService:Create(bodyLbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
        end
        task.wait(0.3)
        toast:Destroy()
    end)

    return toast
end

----------------------------------------------------------------
-- CONFIG SYSTEM
----------------------------------------------------------------
local ConfigManager = {
    current = "default",
    components = {},
    autoSave = false,
    autoSaveInterval = 60,
}

function ConfigManager.register(id, component)
    ConfigManager.components[id] = component
end

function ConfigManager.unregister(id)
    ConfigManager.components[id] = nil
end

function ConfigManager.capture()
    local data = {}
    for id, comp in pairs(ConfigManager.components) do
        if comp.get then
            data[id] = comp.get()
        end
    end
    return data
end

function ConfigManager.apply(data)
    if type(data) ~= "table" then return false end
    for id, value in pairs(data) do
        local comp = ConfigManager.components[id]
        if comp and comp.set then
            pcall(function() comp.set(value) end)
        end
    end
    return true
end

function ConfigManager.save(name)
    name = name or ConfigManager.current
    local data = ConfigManager.capture()
    data._meta = {
        name = name,
        savedAt = os.time(),
        version = 1,
    }
    local ok, err = FileAPI.save(name, data)
    if ok then
        ConfigManager.current = name
        notify("Config saved", '"' .. name .. '" saved successfully', "success")
    else
        notify("Save failed", tostring(err), "error")
    end
    return ok
end

function ConfigManager.load(name)
    name = name or ConfigManager.current
    local data, err = FileAPI.load(name)
    if not data then
        notify("Load failed", err or "not found", "error")
        return false
    end
    ConfigManager.apply(data)
    ConfigManager.current = name
    notify("Config loaded", '"' .. name .. '" loaded', "success")
    return true
end

function ConfigManager.delete(name)
    local ok = FileAPI.delete(name)
    if ok then
        notify("Config deleted", '"' .. name .. '" removed', "warning")
    end
    return ok
end

function ConfigManager.list()
    return FileAPI.list()
end


task.spawn(function()
    while true do
        task.wait(ConfigManager.autoSaveInterval)
        if ConfigManager.autoSave and next(ConfigManager.components) then
            ConfigManager.save(ConfigManager.current)
        end
    end
end)

----------------------------------------------------------------
-- UI DIMENSIONS
----------------------------------------------------------------
local HEADER_H      = 64
local RAIL_W        = 56
local SIDEBAR_W     = 210
local WINDOW_RADIUS = 14

----------------------------------------------------------------
-- ROOT GUI
----------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ConfigMenu"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder   = 100
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

----------------------------------------------------------------
-- GLOBAL TOOLTIP SYSTEM (pozycja liczona wzgledem hosta)
----------------------------------------------------------------
local tooltipHost = Instance.new("Frame")
tooltipHost.Name = "TooltipHost"
tooltipHost.Size = UDim2.fromScale(1, 1)
tooltipHost.BackgroundTransparency = 1
tooltipHost.Active = false
tooltipHost.ZIndex = 999
tooltipHost.Parent = screenGui

local tooltipLabel = Instance.new("TextLabel")
tooltipLabel.AutomaticSize = Enum.AutomaticSize.X
tooltipLabel.Size = UDim2.fromOffset(0, 22)
tooltipLabel.BackgroundColor3 = THEME.PanelAlt
tooltipLabel.TextColor3 = THEME.TextPrimary
tooltipLabel.Font = Enum.Font.Gotham
tooltipLabel.TextSize = 11
tooltipLabel.ZIndex = 1000
tooltipLabel.Visible = false
tooltipLabel.Parent = tooltipHost
corner(tooltipLabel, 8)
stroke(tooltipLabel, THEME.Accent, 1, 0.4)

local tooltipPad = Instance.new("UIPadding")
tooltipPad.PaddingLeft = UDim.new(0, 8)
tooltipPad.PaddingRight = UDim.new(0, 8)
tooltipPad.Parent = tooltipLabel

local TOOLTIP_GAP = 4

local function showTooltip(text, target, side)
    tooltipLabel.Text = text
    tooltipLabel.Visible = true

    local pos  = target.AbsolutePosition - tooltipHost.AbsolutePosition
    local size = target.AbsoluteSize

    if side == "top" then
        tooltipLabel.AnchorPoint = Vector2.new(0.5, 1)
        tooltipLabel.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y - TOOLTIP_GAP)
    elseif side == "bottom" then
        tooltipLabel.AnchorPoint = Vector2.new(0.5, 0)
        tooltipLabel.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y + size.Y + TOOLTIP_GAP)
    else -- "right"
        tooltipLabel.AnchorPoint = Vector2.new(0, 0.5)
        tooltipLabel.Position = UDim2.fromOffset(pos.X + size.X + TOOLTIP_GAP, pos.Y + size.Y / 2)
    end
end

local function hideTooltip()
    tooltipLabel.Visible = false
end

local window = Instance.new("Frame")
window.Name             = "Window"
window.AnchorPoint      = Vector2.new(0.5, 0.5)
window.Position         = UDim2.fromScale(0.5, 0.5)
window.Size             = UDim2.fromOffset(960, 600)
window.BackgroundColor3 = THEME.Background
window.BorderSizePixel  = 0
window.ClipsDescendants = true
window.ZIndex           = 1
window.Parent           = screenGui
window.Visible          = false
corner(window, WINDOW_RADIUS)
stroke(window, THEME.Accent, 1.5, 0.3)

local windowGradient = Instance.new("UIGradient")
windowGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(10, 5, 20)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 8, 30)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(20, 10, 40)),
})
windowGradient.Rotation = 90
windowGradient.Parent = window

window.BackgroundTransparency = 1
TweenService:Create(window, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()

----------------------------------------------------------------
-- HEADER
----------------------------------------------------------------
local header = Instance.new("Frame")
header.Name               = "Header"
header.Size               = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundTransparency = 1
header.ZIndex             = 5
header.Parent             = window

local headerLine = Instance.new("Frame")
headerLine.Position         = UDim2.new(0, 0, 1, -1)
headerLine.Size             = UDim2.new(1, 0, 0, 1)
headerLine.BackgroundColor3 = THEME.Accent
headerLine.BackgroundTransparency = 0.4
headerLine.BorderSizePixel  = 0
headerLine.ZIndex           = 2
headerLine.Parent           = header

local logo = Instance.new("ImageLabel")
logo.Position         = UDim2.fromOffset(15, -10)
logo.Size             = UDim2.fromOffset(150, 90)
logo.BackgroundTransparency = 1
logo.Image            = "rbxassetid://108628695793377"
logo.ScaleType        = Enum.ScaleType.Fit
logo.ZIndex           = 3
logo.Parent           = header
corner(logo, 10)

local msiLuaLogo = Instance.new("ImageLabel")
msiLuaLogo.Position         = UDim2.fromOffset(62, 16)
msiLuaLogo.Size             = UDim2.fromOffset(140, 36)
msiLuaLogo.BackgroundTransparency = 1
msiLuaLogo.Image            = "rbxassetid://118298605561190"
msiLuaLogo.ScaleType        = Enum.ScaleType.Fit
msiLuaLogo.ZIndex           = 3
msiLuaLogo.Parent           = header

local searchContainer = Instance.new("Frame")
searchContainer.Position        = UDim2.fromOffset(198, 12)
searchContainer.Size            = UDim2.fromOffset(180, 40)
searchContainer.BackgroundColor3 = THEME.Panel
searchContainer.ZIndex          = 2
searchContainer.Parent          = header
corner(searchContainer, 10)
stroke(searchContainer, THEME.Accent, 1, 0.4)

local searchBox = Instance.new("TextBox")
searchBox.BackgroundTransparency = 1
searchBox.Position           = UDim2.fromOffset(12, 0)
searchBox.Size               = UDim2.fromOffset(130, 40)
searchBox.PlaceholderText    = "Search"
searchBox.PlaceholderColor3  = THEME.TextDim
searchBox.Text               = ""
searchBox.TextColor3         = THEME.TextPrimary
searchBox.Font               = Enum.Font.Gotham
searchBox.TextSize           = 13
searchBox.TextXAlignment     = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus   = false
searchBox.ZIndex             = 2
searchBox.Parent             = searchContainer

local searchStroke = searchContainer:FindFirstChildOfClass("UIStroke")
searchBox.Focused:Connect(function()
    TweenService:Create(searchContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        BackgroundColor3 = THEME.PanelAlt,
    }):Play()
    if searchStroke then
        TweenService:Create(searchStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Transparency = 0.15,
            Color = THEME.AccentLight,
        }):Play()
    end
end)
searchBox.FocusLost:Connect(function()
    TweenService:Create(searchContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        BackgroundColor3 = THEME.Panel,
    }):Play()
    if searchStroke then
        TweenService:Create(searchStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Transparency = 0.4,
            Color = THEME.Accent,
        }):Play()
    end
end)

local collapseButton = Instance.new("TextButton")
collapseButton.AnchorPoint        = Vector2.new(1, 0.5)
collapseButton.Position           = UDim2.new(1, -8, 0.5, 0)
collapseButton.Size               = UDim2.fromOffset(20, 20)
collapseButton.BackgroundTransparency = 1
collapseButton.Text               = ""
collapseButton.AutoButtonColor    = false
collapseButton.ZIndex             = 2
collapseButton.Parent             = searchContainer

local collapseArrow = Instance.new("ImageLabel")
collapseArrow.AnchorPoint = Vector2.new(0.5, 0.5)
collapseArrow.Position = UDim2.fromScale(0.5, 0.5)
collapseArrow.Size = UDim2.fromOffset(12, 12)
collapseArrow.Rotation = 90
collapseArrow.ZIndex = 3
collapseArrow.Parent = collapseButton
applyIcon(collapseArrow, ICONS.ArrowRight, THEME.TextMuted)

local breadcrumbLabel = Instance.new("TextLabel")
breadcrumbLabel.BackgroundTransparency = 1
breadcrumbLabel.Position        = UDim2.fromOffset(390, 0)
breadcrumbLabel.Size            = UDim2.new(1, -560, 0, HEADER_H)
breadcrumbLabel.RichText        = true
breadcrumbLabel.Text            = ""
breadcrumbLabel.Font            = Enum.Font.Gotham
breadcrumbLabel.TextSize        = 13
breadcrumbLabel.TextXAlignment  = Enum.TextXAlignment.Left
breadcrumbLabel.TextYAlignment  = Enum.TextYAlignment.Center
breadcrumbLabel.TextTruncate    = Enum.TextTruncate.AtEnd
breadcrumbLabel.ZIndex          = 2
breadcrumbLabel.Parent          = header

-- Profile furthest right
local profileContainer = Instance.new("Frame")
profileContainer.AnchorPoint   = Vector2.new(1, 0.5)
profileContainer.Position      = UDim2.new(1, -10, 0.5, 0)
profileContainer.Size          = UDim2.fromOffset(168, 40)
profileContainer.BackgroundTransparency = 1
profileContainer.ZIndex        = 2
profileContainer.Parent        = header

-- Header buttons further right (just left of profile)
local headerActions = Instance.new("Frame")
headerActions.AnchorPoint = Vector2.new(1, 0.5)
headerActions.Position = UDim2.new(1, -176, 0.5, 0)
headerActions.Size = UDim2.fromOffset(148, 40)
headerActions.BackgroundTransparency = 1
headerActions.ZIndex = 2
headerActions.Parent = header

-- Header button z ikona + animacje
local function makeHeaderButton(parent, order, iconId, tooltipText)
    local btn = Instance.new("TextButton")
    btn.LayoutOrder = order
    btn.Size = UDim2.fromOffset(32, 32)
    btn.BackgroundColor3 = THEME.Panel
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.ZIndex = 3
    btn.Parent = parent
    corner(btn, 8)

    local icon = Instance.new("ImageLabel")
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.Size = UDim2.fromOffset(18, 18)
    icon.ZIndex = 4
    icon.Parent = btn
    applyIcon(icon, iconId, THEME.Accent)

    btn.MouseEnter:Connect(function()
        showTooltip(tooltipText, btn, "bottom")
        TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
            ImageColor3 = THEME.AccentLight,
            Size = UDim2.fromOffset(20, 20),
        }):Play()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0.5,
            Size = UDim2.fromOffset(34, 34),
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        hideTooltip()
        TweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            ImageColor3 = THEME.Accent,
            Size = UDim2.fromOffset(18, 18),
        }):Play()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(32, 32),
        }):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
            Size = UDim2.fromOffset(30, 30),
        }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
            Size = UDim2.fromOffset(34, 34),
        }):Play()
    end)

    return btn
end

local headerLayout = Instance.new("UIListLayout")
headerLayout.FillDirection = Enum.FillDirection.Horizontal
headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
headerLayout.Padding = UDim.new(0, 6)
headerLayout.Parent = headerActions

local saveBtn   = makeHeaderButton(headerActions, 1, ICONS.Save, "Save config")
local loadBtn   = makeHeaderButton(headerActions, 2, ICONS.Load, "Load config")
local minBtn    = makeHeaderButton(headerActions, 3, ICONS.Minimize, "Minimize")
local closeBtn  = makeHeaderButton(headerActions, 4, ICONS.Close, "Close")

local avatarFrame = Instance.new("Frame")
avatarFrame.AnchorPoint    = Vector2.new(1, 0.5)
avatarFrame.Position       = UDim2.new(1, 0, 0.5, 0)
avatarFrame.Size           = UDim2.fromOffset(36, 36)
avatarFrame.BackgroundColor3 = THEME.PanelAlt
avatarFrame.ZIndex         = 2
avatarFrame.Parent         = profileContainer
corner(avatarFrame, 18)
stroke(avatarFrame, THEME.Accent, 1.5, 0.4)

local avatarImage = Instance.new("ImageLabel")
avatarImage.Size                = UDim2.fromScale(1, 1)
avatarImage.BackgroundTransparency = 1
avatarImage.ScaleType           = Enum.ScaleType.Fit
avatarImage.ZIndex              = 2
avatarImage.Parent              = avatarFrame
corner(avatarImage, 18)

task.spawn(function()
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(
            player.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size180x180)
    end)
    if ok then avatarImage.Image = img end
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.AnchorPoint   = Vector2.new(1, 0)
nameLabel.Position      = UDim2.new(1, -44, 0.5, -17)
nameLabel.Size          = UDim2.fromOffset(126, 17)
nameLabel.BackgroundTransparency = 1
nameLabel.Text          = player.DisplayName
nameLabel.TextColor3    = THEME.TextPrimary
nameLabel.Font          = Enum.Font.GothamBold
nameLabel.TextSize      = 13
nameLabel.TextXAlignment = Enum.TextXAlignment.Right
nameLabel.ZIndex        = 2
nameLabel.Parent        = profileContainer

local timeLabel = Instance.new("TextLabel")
timeLabel.AnchorPoint   = Vector2.new(1, 0)
timeLabel.Position      = UDim2.new(1, -44, 0.5, 1)
timeLabel.Size          = UDim2.fromOffset(126, 14)
timeLabel.BackgroundTransparency = 1
timeLabel.Text          = os.date("%d.%m.%Y %H:%M")
timeLabel.TextColor3    = THEME.TextMuted
timeLabel.Font          = Enum.Font.Gotham
timeLabel.TextSize      = 11
timeLabel.TextXAlignment = Enum.TextXAlignment.Right
timeLabel.ZIndex        = 2
timeLabel.Parent        = profileContainer

task.spawn(function()
    while screenGui.Parent do
        timeLabel.Text = os.date("%d.%m.%Y %H:%M")
        task.wait(30)
    end
end)

----------------------------------------------------------------
-- BODY
----------------------------------------------------------------
local body = Instance.new("Frame")
body.Name               = "Body"
body.Position           = UDim2.fromOffset(0, 0)
body.Size               = UDim2.fromScale(1, 1)
body.BackgroundTransparency = 1
body.BorderSizePixel       = 0
body.ClipsDescendants       = true
body.ZIndex             = 2
body.Parent             = window

----------------------------------------------------------------
-- RAIL (square body + small rounded bottom-left cap)
----------------------------------------------------------------
local RAIL_CAP_H = WINDOW_RADIUS * 2

local rail = Instance.new("Frame")
rail.Name             = "Rail"
rail.Position         = UDim2.fromOffset(0, HEADER_H)
rail.Size             = UDim2.new(0, RAIL_W, 1, -(HEADER_H + WINDOW_RADIUS))
rail.BackgroundColor3 = THEME.Panel
rail.BackgroundTransparency = 0
rail.BorderSizePixel  = 0
rail.ClipsDescendants = true
rail.ZIndex           = 3
rail.Parent           = body

local railBorder = Instance.new("Frame")
railBorder.Name              = "Border"
railBorder.AnchorPoint       = Vector2.new(1, 0)
railBorder.Position          = UDim2.new(1, 0, 0, 0)
railBorder.Size              = UDim2.new(0, 1, 1, 0)
railBorder.BackgroundColor3  = THEME.Accent
railBorder.BackgroundTransparency = 0.4
railBorder.BorderSizePixel   = 0
railBorder.ZIndex            = 4
railBorder.Parent            = rail

local railCap = Instance.new("Frame")
railCap.Name                   = "RailCornerCap"
railCap.AnchorPoint            = Vector2.new(0, 1)
railCap.Position               = UDim2.new(0, 0, 1, 0)
railCap.Size                   = UDim2.fromOffset(RAIL_W, RAIL_CAP_H)
railCap.BackgroundColor3       = THEME.Panel
railCap.BackgroundTransparency = 0
railCap.BorderSizePixel        = 0
railCap.ZIndex                 = 2
railCap.Parent                 = body
corner(railCap, WINDOW_RADIUS)

local railCapBorder = Instance.new("Frame")
railCapBorder.Name                     = "Border"
railCapBorder.AnchorPoint              = Vector2.new(1, 0)
railCapBorder.Position                 = UDim2.new(1, 0, 0, 0)
railCapBorder.Size                     = UDim2.new(0, 1, 1, 0)
railCapBorder.BackgroundColor3         = THEME.Accent
railCapBorder.BackgroundTransparency   = 0.4
railCapBorder.BorderSizePixel          = 0
railCapBorder.ZIndex                   = 4
railCapBorder.Parent                   = railCap

----------------------------------------------------------------
-- SIDEBAR
----------------------------------------------------------------
local sidebar = Instance.new("Frame")
sidebar.Name             = "Sidebar"
sidebar.Position         = UDim2.fromOffset(RAIL_W, HEADER_H)
sidebar.Size             = UDim2.new(0, SIDEBAR_W, 1, -HEADER_H)
sidebar.BackgroundColor3 = THEME.Panel
sidebar.BackgroundTransparency = 0.5
sidebar.BorderSizePixel  = 0
sidebar.ClipsDescendants = true
sidebar.ZIndex           = 2
sidebar.Parent           = body

local sidebarBorder = Instance.new("Frame")
sidebarBorder.Name              = "Border"
sidebarBorder.AnchorPoint       = Vector2.new(1, 0)
sidebarBorder.Position          = UDim2.new(1, 0, 0, 0)
sidebarBorder.Size              = UDim2.new(0, 1, 1, 0)
sidebarBorder.BackgroundColor3  = THEME.Accent
sidebarBorder.BackgroundTransparency = 0.4
sidebarBorder.BorderSizePixel   = 0
sidebarBorder.ZIndex            = 3
sidebarBorder.Parent            = sidebar

local treeScroll = Instance.new("ScrollingFrame")
treeScroll.Size                = UDim2.new(1, -8, 1, -16)
treeScroll.Position            = UDim2.fromOffset(6, 8)
treeScroll.BackgroundTransparency = 1
treeScroll.BorderSizePixel     = 0
treeScroll.ScrollBarThickness  = 3
treeScroll.ScrollBarImageColor3 = THEME.Accent
treeScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
treeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
treeScroll.ScrollingDirection  = Enum.ScrollingDirection.Y
treeScroll.ZIndex              = 2
treeScroll.Parent              = sidebar

local treeList = Instance.new("UIListLayout")
treeList.SortOrder = Enum.SortOrder.LayoutOrder
treeList.Padding   = UDim.new(0, 0)
treeList.Parent    = treeScroll

----------------------------------------------------------------
-- CONTENT HOST
----------------------------------------------------------------
local contentHost = Instance.new("Frame")
contentHost.Name             = "ContentHost"
contentHost.Position         = UDim2.fromOffset(RAIL_W + SIDEBAR_W, HEADER_H)
contentHost.Size             = UDim2.new(1, -(RAIL_W + SIDEBAR_W), 1, -HEADER_H)
contentHost.BackgroundTransparency = 1
contentHost.BorderSizePixel  = 0
contentHost.ClipsDescendants = true
contentHost.ZIndex           = 2
contentHost.Parent           = body

local bgImage = Instance.new("ImageLabel")
bgImage.Size = UDim2.fromScale(0.65, 1)
bgImage.Position = UDim2.fromScale(0.5, 0.5)
bgImage.AnchorPoint = Vector2.new(0.5, 0.5)
bgImage.BackgroundTransparency = 1
bgImage.Image = "rbxassetid://78464903954782"
bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.ImageTransparency = 0.05
bgImage.ZIndex = 1
bgImage.Parent = contentHost

local railPages = {}
local function makeContentPage()
    local page = Instance.new("ScrollingFrame")
    page.Size                = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel     = 0
    page.ScrollBarThickness  = 4
    page.ScrollBarImageColor3 = THEME.Accent
    page.CanvasSize          = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollingEnabled    = true
    page.ScrollingDirection  = Enum.ScrollingDirection.Y
    page.ScrollBarThickness  = 5
    page.ScrollBarImageTransparency = 0.1
    page.Visible             = false
    page.ZIndex              = 2
    page.Parent              = contentHost
    return page
end

for i = 1, 8 do
    railPages[i] = makeContentPage()
end
railPages[1].Visible = true

----------------------------------------------------------------
-- NOTIFICATION HOST
----------------------------------------------------------------
notifyHost = Instance.new("Frame")
notifyHost.Name = "NotifyHost"
notifyHost.AnchorPoint = Vector2.new(1, 1)
notifyHost.Position = UDim2.new(1, -16, 1, -16)
notifyHost.Size = UDim2.fromOffset(280, 0)
notifyHost.AutomaticSize = Enum.AutomaticSize.Y
notifyHost.BackgroundTransparency = 1
notifyHost.BorderSizePixel = 0
notifyHost.ZIndex = 150
notifyHost.Parent = screenGui

local notifyLayout = Instance.new("UIListLayout")
notifyLayout.Padding = UDim.new(0, 8)
notifyLayout.FillDirection = Enum.FillDirection.Vertical
notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifyLayout.Parent = notifyHost

----------------------------------------------------------------
-- COMPONENT BUILDERS
----------------------------------------------------------------
local componentCounter = 0
local function nextId(prefix)
    componentCounter = componentCounter + 1
    return (prefix or "comp") .. "_" .. componentCounter
end

local function createCard(parent, title, order)
    local card = Instance.new("Frame")
    card.LayoutOrder      = order or 1
    card.Size             = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize    = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.Card
    card.BackgroundTransparency = 1
    card.ClipsDescendants = false
    card.ZIndex           = 3
    card.Parent           = parent
    corner(card, 12)
    local cardStroke = stroke(card, THEME.Accent, 1, 1)

    -- Entrance animation
    local delay = ((order or 1) - 1) * 0.05
    task.delay(delay, function()
        if not card.Parent then return end
        TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.4,
        }):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
            Transparency = 0.4,
        }):Play()
    end)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft   = UDim.new(0, 14)
    pad.PaddingRight  = UDim.new(0, 14)
    pad.Parent        = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, 12)
    layout.Parent    = card

    if title then
        local t = Instance.new("TextLabel")
        t.LayoutOrder           = 0
        t.BackgroundTransparency = 1
        t.Size                  = UDim2.new(1, 0, 0, 16)
        t.Text                  = title
        t.TextColor3            = THEME.Accent
        t.Font                  = Enum.Font.GothamBold
        t.TextSize              = 14
        t.TextXAlignment        = Enum.TextXAlignment.Left
        t.ZIndex                = 3
        t.Parent                = card
    end

    return card
end

local function createToggleRow(card, order, label, default, options)
    options = options or {}
    local disabled     = options.disabled
    local withGear     = options.gear
    local id           = options.id or nextId("toggle")
    local rightReserve = withGear and 72 or 46

    local row = Instance.new("Frame")
    row.LayoutOrder           = order
    row.Size                  = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.ZIndex                = 3
    row.Parent                = card

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size           = UDim2.new(1, -rightReserve, 1, 0)
    text.Text           = label
    text.TextColor3     = disabled and THEME.TextDim or THEME.TextPrimary
    text.Font           = Enum.Font.Gotham
    text.TextSize       = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.ZIndex         = 3
    text.Parent         = row

    if withGear then
        local gear = Instance.new("TextButton")
        gear.AnchorPoint        = Vector2.new(1, 0.5)
        gear.Position           = UDim2.new(1, -46, 0.5, 0)
        gear.Size               = UDim2.fromOffset(18, 18)
        gear.BackgroundTransparency = 1
        gear.Text               = "⚙"
        gear.TextColor3         = disabled and THEME.TextDim or THEME.Accent
        gear.TextSize           = 13
        gear.Font               = Enum.Font.Gotham
        gear.ZIndex             = 3
        gear.Parent             = row
    end

    local track = Instance.new("TextButton")
    track.AnchorPoint           = Vector2.new(1, 0.5)
    track.Position              = UDim2.new(1, 0, 0.5, 0)
    track.Size                  = UDim2.fromOffset(36, 18)
    track.BackgroundColor3      = (default and not disabled) and THEME.Accent or THEME.ToggleOff
    track.BackgroundTransparency = disabled and 0.5 or 0
    track.AutoButtonColor       = false
    track.Text                  = ""
    track.Active                = not disabled
    track.ZIndex                = 3
    track.Parent                = row
    corner(track, 9)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.fromOffset(14, 14)
    knob.Position         = default
        and UDim2.new(1, -16, 0.5, -7)
        or  UDim2.new(0, 2,   0.5, -7)
    knob.BackgroundColor3 = THEME.White
    knob.ZIndex           = 3
    knob.Parent           = track
    corner(knob, 7)

    local state = default
    local callbacks = {}

    local function setInternal(v, animate)
        v = (v == true)
        if v == state then return end
        state = v
        if animate ~= false then
            TweenService:Create(track, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                BackgroundColor3 = state and THEME.Accent or THEME.ToggleOff,
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = state
                    and UDim2.new(1, -16, 0.5, -7)
                    or  UDim2.new(0, 2,   0.5, -7),
                Size = UDim2.fromOffset(16, 16),
            }):Play()
            task.delay(0.12, function()
                TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                    Size = UDim2.fromOffset(14, 14),
                    Position = state
                        and UDim2.new(1, -16, 0.5, -7)
                        or  UDim2.new(0, 2, 0.5, -7),
                }):Play()
            end)
        else
            track.BackgroundColor3 = state and THEME.Accent or THEME.ToggleOff
            knob.Position = state
                and UDim2.new(1, -16, 0.5, -7)
                or  UDim2.new(0, 2,   0.5, -7)
            knob.Size = UDim2.fromOffset(14, 14)
        end
        for _, cb in ipairs(callbacks) do
            task.spawn(cb, state)
        end
    end

    if not disabled then
        track.MouseEnter:Connect(function()
            TweenService:Create(track, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                Size = UDim2.fromOffset(38, 20),
            }):Play()
        end)
        track.MouseLeave:Connect(function()
            TweenService:Create(track, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                Size = UDim2.fromOffset(36, 18),
            }):Play()
        end)
        track.MouseButton1Click:Connect(function() setInternal(not state) end)
    end

    local comp = {
        id = id,
        row = row,
        get = function() return state end,
        set = function(v) setInternal(v) end,
        onChange = function(cb) table.insert(callbacks, cb) end,
        destroy = function()
            ConfigManager.unregister(id)
            row:Destroy()
        end,
    }
    ConfigManager.register(id, comp)
    return comp
end

local function createSliderRow(card, order, label, min, max, default, decimals, options)
    options = options or {}
    local id = options.id or nextId("slider")

    local container = Instance.new("Frame")
    container.LayoutOrder           = order
    container.Size                  = UDim2.new(1, 0, 0, 42)
    container.BackgroundTransparency = 1
    container.ZIndex                = 3
    container.Parent                = card

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size           = UDim2.new(1, -70, 0, 16)
    text.Text           = label
    text.TextColor3     = THEME.TextPrimary
    text.Font           = Enum.Font.Gotham
    text.TextSize       = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.ZIndex         = 3
    text.Parent         = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.AnchorPoint   = Vector2.new(1, 0)
    valueLabel.Position      = UDim2.new(1, 0, 0, 0)
    valueLabel.Size          = UDim2.fromOffset(70, 16)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3    = THEME.Accent
    valueLabel.Font          = Enum.Font.Gotham
    valueLabel.TextSize      = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex        = 3
    valueLabel.Parent        = container

    local trackBg = Instance.new("Frame")
    trackBg.Position         = UDim2.new(0, 0, 0, 28)
    trackBg.Size             = UDim2.new(1, 0, 0, 4)
    trackBg.BackgroundColor3 = THEME.ToggleOff
    trackBg.ZIndex           = 3
    trackBg.Parent           = container
    corner(trackBg, 2)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = THEME.Accent
    fill.ZIndex           = 3
    fill.Parent           = trackBg
    corner(fill, 2)

    local knob = Instance.new("TextButton")
    knob.AnchorPoint      = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = THEME.White
    knob.AutoButtonColor  = false
    knob.Text             = ""
    knob.ZIndex           = 4
    knob.Size             = UDim2.fromOffset(12, 12)
    knob.Parent           = trackBg
    corner(knob, 6)

    local currentValue = default
    local callbacks = {}

    local function format(v)
        if decimals and decimals > 0 then
            return string.format("%." .. decimals .. "f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    local function setInternal(v, animate)
        v = math.clamp(v, min, max)
        if decimals and decimals > 0 then
            local m = 10 ^ decimals
            v = math.floor(v * m + 0.5) / m
        else
            v = math.floor(v + 0.5)
        end
        currentValue = v
        local a = (max > min) and ((v - min) / (max - min)) or 0
        if animate ~= false then
            TweenService:Create(fill, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                Size = UDim2.new(a, 0, 1, 0),
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                Position = UDim2.new(a, 0, 0.5, 0),
            }):Play()
        else
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
        end
        valueLabel.Text = format(v)
        for _, cb in ipairs(callbacks) do
            task.spawn(cb, v)
        end
    end

    setInternal(default, false)

    local dragging = false
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            TweenService:Create(knob, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
                Size = UDim2.fromOffset(16, 16),
            }):Play()
        end
    end)
    trackBg.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            local a = (inp.Position.X - trackBg.AbsolutePosition.X) / math.max(trackBg.AbsoluteSize.X, 1)
            setInternal(min + (max - min) * a, true)
            dragging = true
            TweenService:Create(knob, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
                Size = UDim2.fromOffset(16, 16),
            }):Play()
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local a = (inp.Position.X - trackBg.AbsolutePosition.X) / math.max(trackBg.AbsoluteSize.X, 1)
            setInternal(min + (max - min) * a, false)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
                    Size = UDim2.fromOffset(12, 12),
                }):Play()
            end
            dragging = false
        end
    end)

    knob.MouseEnter:Connect(function()
        if not dragging then
            TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                Size = UDim2.fromOffset(14, 14),
            }):Play()
        end
    end)
    knob.MouseLeave:Connect(function()
        if not dragging then
            TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                Size = UDim2.fromOffset(12, 12),
            }):Play()
        end
    end)

    local comp = {
        id = id,
        row = container,
        get = function() return currentValue end,
        set = function(v) setInternal(v) end,
        onChange = function(cb) table.insert(callbacks, cb) end,
        destroy = function()
            ConfigManager.unregister(id)
            container:Destroy()
        end,
    }
    ConfigManager.register(id, comp)
    return comp
end

local dropdownRegistry = {}

local function closeAllDropdowns(except)
    for _, entry in ipairs(dropdownRegistry) do
        if entry ~= except and entry.optionsFrame.Visible then
            entry.close()
        end
    end
end

local function createDropdownRow(card, order, label, options, default, opts)
    opts = opts or {}
    local id = opts.id or nextId("dropdown")

    local container = Instance.new("Frame")
    container.LayoutOrder           = order
    container.Size                  = UDim2.new(1, 0, 0, 56)
    container.BackgroundTransparency = 1
    container.ZIndex                = 2
    container.Parent                = card

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size           = UDim2.new(1, 0, 0, 14)
    text.Text           = label
    text.TextColor3     = THEME.TextMuted
    text.Font           = Enum.Font.Gotham
    text.TextSize       = 11
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.ZIndex         = 3
    text.Parent         = container

    local button = Instance.new("TextButton")
    button.Position         = UDim2.new(0, 0, 0, 20)
    button.Size             = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = THEME.PanelAlt
    button.AutoButtonColor  = false
    button.Text             = ""
    button.ZIndex           = 3
    button.Parent           = container
    corner(button, 10)
    stroke(button, THEME.Accent, 1, 0.4)

    local selectedLabel = Instance.new("TextLabel")
    selectedLabel.Position       = UDim2.fromOffset(10, 0)
    selectedLabel.Size           = UDim2.new(1, -34, 1, 0)
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Text           = default
    selectedLabel.TextColor3     = THEME.TextPrimary
    selectedLabel.Font           = Enum.Font.Gotham
    selectedLabel.TextSize       = 13
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.ZIndex         = 3
    selectedLabel.Parent         = button

    local chevron = Instance.new("ImageLabel")
    chevron.Name                 = "Chevron"
    chevron.AnchorPoint          = Vector2.new(1, 0.5)
    chevron.Position             = UDim2.new(1, -10, 0.5, 0)
    chevron.Size                 = UDim2.fromOffset(12, 12)
    chevron.Rotation             = 0
    chevron.ZIndex               = 3
    chevron.Parent               = button
    applyIcon(chevron, ICONS.ArrowRight, THEME.Accent)

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Position         = UDim2.new(0, 0, 0, 57)
    optionsFrame.Size             = UDim2.new(1, 0, 0, 0)
    optionsFrame.BackgroundColor3 = THEME.PanelAlt
    optionsFrame.BackgroundTransparency = 1
    optionsFrame.Visible          = false
    optionsFrame.ZIndex           = 100
    optionsFrame.ClipsDescendants = true
    optionsFrame.Parent           = container
    corner(optionsFrame, 10)
    stroke(optionsFrame, THEME.Accent, 1, 0.4)

    local optPad = Instance.new("UIPadding")
    optPad.PaddingTop    = UDim.new(0, 4)
    optPad.PaddingBottom = UDim.new(0, 4)
    optPad.Parent        = optionsFrame

    local optLayout = Instance.new("UIListLayout")
    optLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optLayout.Parent    = optionsFrame

    local currentSelection = default
    local callbacks = {}
    local openHeight = math.min(#options, 8) * 28 + 8

    -- Keep an opened dropdown above every other row/card in the page.
    -- The card is temporarily lifted so its dropdown descendants render
    -- over labels/toggles belonging to following rows.
    local originalContainerZ = container.ZIndex
    local originalCardZ = card.ZIndex

    local function setDropdownLayer(open)
        if open then
            card.ZIndex = 200
            container.ZIndex = 250
            optionsFrame.ZIndex = 300
        else
            container.ZIndex = originalContainerZ
            card.ZIndex = originalCardZ
            optionsFrame.ZIndex = 100
        end
    end

    local function closeThis()
        setDropdownLayer(false)
        TweenService:Create(chevron, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Rotation = 0,
            ImageColor3 = THEME.Accent,
        }):Play()
        TweenService:Create(optionsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.2, function()
            optionsFrame.Visible = false
        end)
    end

    local function openThis()
        setDropdownLayer(true)
        optionsFrame.Visible = true
        optionsFrame.Size = UDim2.new(1, 0, 0, 0)
        optionsFrame.BackgroundTransparency = 1
        TweenService:Create(chevron, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Rotation = 180,
            ImageColor3 = THEME.AccentLight,
        }):Play()
        TweenService:Create(optionsFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, openHeight),
            BackgroundTransparency = 0,
        }):Play()
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
            BackgroundColor3 = THEME.Card,
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
            BackgroundColor3 = THEME.PanelAlt,
        }):Play()
    end)

    local checkLabels = {}

    for i, option in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.LayoutOrder           = i
        optBtn.Size                  = UDim2.new(1, 0, 0, 28)
        optBtn.BackgroundTransparency = 1
        optBtn.Text                  = ""
        optBtn.ZIndex                = 301
        optBtn.Parent                = optionsFrame

        local optText = Instance.new("TextLabel")
        optText.Position        = UDim2.fromOffset(10, 0)
        optText.Size            = UDim2.new(1, -20, 1, 0)
        optText.BackgroundTransparency = 1
        optText.Text            = option
        optText.TextColor3      = THEME.TextPrimary
        optText.Font            = Enum.Font.Gotham
        optText.TextSize        = 13
        optText.TextXAlignment  = Enum.TextXAlignment.Left
        optText.ZIndex          = 302
        optText.Parent          = optBtn

        local check = Instance.new("TextLabel")
        check.AnchorPoint   = Vector2.new(1, 0.5)
        check.Position      = UDim2.new(1, -10, 0.5, 0)
        check.Size          = UDim2.fromOffset(14, 14)
        check.BackgroundTransparency = 1
        check.Text          = option == default and "✓" or ""
        check.TextColor3    = THEME.Accent
        check.Font          = Enum.Font.GothamBold
        check.TextSize      = 12
        check.ZIndex        = 302
        check.Parent        = optBtn
        checkLabels[option] = check

        optBtn.MouseEnter:Connect(function()
            TweenService:Create(optBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 0.85,
                BackgroundColor3 = THEME.Accent,
            }):Play()
        end)
        optBtn.MouseLeave:Connect(function()
            TweenService:Create(optBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 1,
            }):Play()
        end)
        optBtn.MouseButton1Click:Connect(function()
            for _, ck in pairs(checkLabels) do ck.Text = "" end
            check.Text = "✓"
            selectedLabel.Text = option
            currentSelection = option
            closeThis()
            for _, cb in ipairs(callbacks) do
                task.spawn(cb, option)
            end
        end)
    end

    button.MouseButton1Click:Connect(function()
        local willOpen = not optionsFrame.Visible
        closeAllDropdowns(willOpen and {optionsFrame=optionsFrame, close=closeThis} or nil)
        if willOpen then openThis() else closeThis() end
    end)

    local entry = {optionsFrame = optionsFrame, close = closeThis}
    table.insert(dropdownRegistry, entry)

    local comp = {
        id = id,
        row = container,
        get = function() return currentSelection end,
        set = function(v)
            if not table.find(options, v) then return end
            for _, ck in pairs(checkLabels) do ck.Text = "" end
            if checkLabels[v] then checkLabels[v].Text = "✓" end
            selectedLabel.Text = v
            currentSelection = v
        end,
        onChange = function(cb) table.insert(callbacks, cb) end,
        destroy = function()
            ConfigManager.unregister(id)
            container:Destroy()
        end,
    }
    ConfigManager.register(id, comp)
    return comp
end

local function createButtonRow(card, order, label, color, onClick)
    local btn = Instance.new("TextButton")
    btn.LayoutOrder = order
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = color or THEME.Accent
    btn.AutoButtonColor = false
    btn.Text = label
    btn.TextColor3 = THEME.White
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.ZIndex = 3
    btn.Parent = card
    corner(btn, 10)
    stroke(btn, THEME.AccentLight, 1, 0.6)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0.15,
            Size = UDim2.new(1, 0, 0, 34),
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0,
            Size = UDim2.new(1, 0, 0, 32),
        }):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 0.3,
        }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 0.15,
        }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if onClick then task.spawn(onClick) end
    end)

    return btn
end

local keybindRegistry = {}
local keybindListEnabled = false
local setKeybindListVisible
local toggleKey = Enum.KeyCode.Insert

local function keyName(key)
    if not key then return "None" end
    return tostring(key):gsub("Enum.KeyCode.", "")
end

local function createKeybindRow(card, order, label, defaultKey, options)
    options = options or {}
    local id = options.id or nextId("keybind")

    local row = Instance.new("Frame")
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.ZIndex = 3
    row.Parent = card

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, -90, 1, 0)
    text.Text = label
    text.TextColor3 = THEME.TextPrimary
    text.Font = Enum.Font.Gotham
    text.TextSize = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.ZIndex = 3
    text.Parent = row

    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.fromOffset(80, 24)
    btn.BackgroundColor3 = THEME.PanelAlt
    btn.AutoButtonColor = false
    btn.Text = defaultKey and tostring(defaultKey):gsub("Enum.KeyCode.","") or "None"
    btn.TextColor3 = THEME.TextPrimary
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.ZIndex = 3
    btn.Parent = row
    corner(btn, 8)
    stroke(btn, THEME.Accent, 1, 0.4)

    local currentKey = defaultKey
    local listening = false
    local callbacks = {}

    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        btn.Text = "..."
        btn.TextColor3 = THEME.Accent

        local conn
        conn = UserInputService.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                currentKey = inp.KeyCode
                btn.Text = tostring(inp.KeyCode):gsub("Enum.KeyCode.","")
                btn.TextColor3 = THEME.TextPrimary
                listening = false
                conn:Disconnect()
                for _, cb in ipairs(callbacks) do task.spawn(cb, currentKey) end
            elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
                currentKey = nil
                btn.Text = "None"
                btn.TextColor3 = THEME.TextMuted
                listening = false
                conn:Disconnect()
                for _, cb in ipairs(callbacks) do task.spawn(cb, nil) end
            end
        end)
    end)

    local comp = {
        id = id,
        row = row,
        get = function() return currentKey end,
        set = function(k)
            currentKey = k
            if k then
                btn.Text = tostring(k):gsub("Enum.KeyCode.","")
                btn.TextColor3 = THEME.TextPrimary
            else
                btn.Text = "None"
                btn.TextColor3 = THEME.TextMuted
            end
        end,
        onChange = function(cb) table.insert(callbacks, cb) end,
        destroy = function()
            ConfigManager.unregister(id)
            row:Destroy()
        end,
    }
    ConfigManager.register(id, comp)
    keybindRegistry[id] = {
        id = id, label = label, row = row,
        get = function() return currentKey end,
        getMode = function() return options.mode or "Toggle" end,
    }
    return comp
end

local function createLabelRow(card, order, textValue, options)
    options = options or {}
    local label = Instance.new("TextLabel")
    label.LayoutOrder = order
    label.Size = UDim2.new(1, 0, 0, options.height or 22)
    label.BackgroundTransparency = 1
    label.Text = textValue or ""
    label.TextColor3 = options.color or THEME.TextMuted
    label.Font = options.bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextSize = options.size or 12
    label.TextXAlignment = options.align or Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = options.wrap or false
    label.ZIndex = 3
    label.Parent = card
    return label
end

local function createTextBoxRow(card, order, labelText, placeholder, defaultText, options)
    options = options or {}
    local id = options.id or nextId("textbox")
    local row = Instance.new("Frame")
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, options.height or 34)
    row.BackgroundTransparency = 1
    row.ZIndex = 3
    row.Parent = card

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(0.36, -6, 1, 0)
    text.Text = labelText
    text.TextColor3 = THEME.TextPrimary
    text.Font = Enum.Font.Gotham
    text.TextSize = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextYAlignment = Enum.TextYAlignment.Center
    text.ZIndex = 3
    text.Parent = row

    local box = Instance.new("TextBox")
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    box.Size = UDim2.new(0.62, 0, 0, 30)
    box.BackgroundColor3 = THEME.PanelAlt
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Text = defaultText or ""
    box.PlaceholderText = placeholder or "Enter text..."
    box.PlaceholderColor3 = THEME.TextDim
    box.TextColor3 = THEME.TextPrimary
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ZIndex = 4
    box.Parent = row
    corner(box, 8)
    local boxStroke = stroke(box, THEME.Accent, 1, 0.5)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 9)
    pad.PaddingRight = UDim.new(0, 9)
    pad.Parent = box

    local currentText = box.Text
    local callbacks = {}
    local function fire(v)
        currentText = v
        for _, cb in ipairs(callbacks) do task.spawn(cb, v) end
    end
    box.Focused:Connect(function()
        TweenService:Create(box, TweenInfo.new(0.15), {BackgroundColor3 = THEME.Panel}):Play()
        TweenService:Create(boxStroke, TweenInfo.new(0.15), {Transparency = 0.15, Color = THEME.AccentLight}):Play()
    end)
    box.FocusLost:Connect(function()
        currentText = box.Text
        TweenService:Create(box, TweenInfo.new(0.15), {BackgroundColor3 = THEME.PanelAlt}):Play()
        TweenService:Create(boxStroke, TweenInfo.new(0.15), {Transparency = 0.5, Color = THEME.Accent}):Play()
        fire(currentText)
    end)
    if options.live then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            currentText = box.Text
            fire(currentText)
        end)
    end
    local comp = {
        id = id, row = row,
        get = function() return currentText end,
        set = function(v) currentText = tostring(v or ""); box.Text = currentText end,
        onChange = function(cb) table.insert(callbacks, cb) end,
        destroy = function() ConfigManager.unregister(id); row:Destroy() end,
    }
    ConfigManager.register(id, comp)
    return comp
end

local function createComboRow(card, order, labelText, comboOptions, defaultValue, defaultKey, options)
    options = options or {}
    local id = options.id or nextId("combo")
    local row = Instance.new("Frame")
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundTransparency = 1
    row.ZIndex = 40
    row.Parent = card

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.30, -6, 1, 0)
    label.Text = labelText
    label.TextColor3 = THEME.TextPrimary
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 41
    label.Parent = row

    local keyButton = Instance.new("TextButton")
    keyButton.AnchorPoint = Vector2.new(1, 0.5)
    keyButton.Position = UDim2.new(1, 0, 0.5, 0)
    keyButton.Size = UDim2.fromOffset(68, 28)
    keyButton.BackgroundColor3 = THEME.PanelAlt
    keyButton.AutoButtonColor = false
    keyButton.Text = keyName(defaultKey)
    keyButton.TextColor3 = THEME.TextPrimary
    keyButton.Font = Enum.Font.Gotham
    keyButton.TextSize = 11
    keyButton.ZIndex = 43
    keyButton.Parent = row
    corner(keyButton, 8)
    stroke(keyButton, THEME.Accent, 1, 0.45)

    local dropButton = Instance.new("TextButton")
    dropButton.AnchorPoint = Vector2.new(1, 0.5)
    dropButton.Position = UDim2.new(1, -74, 0.5, 0)
    dropButton.Size = UDim2.fromOffset(112, 28)
    dropButton.BackgroundColor3 = THEME.PanelAlt
    dropButton.AutoButtonColor = false
    dropButton.Text = ""
    dropButton.ZIndex = 43
    dropButton.Parent = row
    corner(dropButton, 8)
    stroke(dropButton, THEME.Accent, 1, 0.45)

    local selected = Instance.new("TextLabel")
    selected.BackgroundTransparency = 1
    selected.Position = UDim2.fromOffset(8, 0)
    selected.Size = UDim2.new(1, -24, 1, 0)
    selected.Text = defaultValue or comboOptions[1] or "None"
    selected.TextColor3 = THEME.TextPrimary
    selected.Font = Enum.Font.Gotham
    selected.TextSize = 11
    selected.TextXAlignment = Enum.TextXAlignment.Left
    selected.ZIndex = 44
    selected.Parent = dropButton

    local chev = Instance.new("ImageLabel")
    chev.AnchorPoint = Vector2.new(1, 0.5)
    chev.Position = UDim2.new(1, -7, 0.5, 0)
    chev.Size = UDim2.fromOffset(10, 10)
    chev.ZIndex = 44
    chev.Parent = dropButton
    applyIcon(chev, ICONS.ArrowRight, THEME.Accent)

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Name = "ComboOptions"
    optionsFrame.Position = UDim2.new(0, 0, 1, 5)
    optionsFrame.Size = UDim2.fromOffset(112, 0)
    optionsFrame.BackgroundColor3 = THEME.PanelAlt
    optionsFrame.BackgroundTransparency = 1
    optionsFrame.Visible = false
    optionsFrame.ZIndex = 300
    optionsFrame.ClipsDescendants = true
    optionsFrame.Parent = dropButton
    corner(optionsFrame, 8)
    stroke(optionsFrame, THEME.Accent, 1, 0.35)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = optionsFrame
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = optionsFrame

    local currentValue = defaultValue or comboOptions[1]
    local currentKey = defaultKey
    local callbacks = {}
    local openHeight = math.min(#comboOptions, 6) * 26 + 8

    for i, option in ipairs(comboOptions) do
        local opt = Instance.new("TextButton")
        opt.LayoutOrder = i
        opt.Size = UDim2.new(1, 0, 0, 26)
        opt.BackgroundTransparency = 1
        opt.Text = option
        opt.TextColor3 = THEME.TextPrimary
        opt.Font = Enum.Font.Gotham
        opt.TextSize = 11
        opt.TextXAlignment = Enum.TextXAlignment.Left
        opt.AutoButtonColor = false
        opt.ZIndex = 301
        opt.Parent = optionsFrame
        local opad = Instance.new("UIPadding")
        opad.PaddingLeft = UDim.new(0, 8)
        opad.Parent = opt
        opt.MouseEnter:Connect(function() TweenService:Create(opt, TweenInfo.new(0.1), {BackgroundTransparency = 0.85, BackgroundColor3 = THEME.Accent}):Play() end)
        opt.MouseLeave:Connect(function() TweenService:Create(opt, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play() end)
        opt.MouseButton1Click:Connect(function()
            currentValue = option
            selected.Text = option
            for _, cb in ipairs(callbacks) do task.spawn(cb, currentValue, currentKey) end
            TweenService:Create(optionsFrame, TweenInfo.new(0.15), {Size = UDim2.fromOffset(112, 0), BackgroundTransparency = 1}):Play()
            TweenService:Create(chev, TweenInfo.new(0.15), {Rotation = 0, ImageColor3 = THEME.Accent}):Play()
            task.delay(0.15, function() if optionsFrame.Parent then optionsFrame.Visible = false end end)
        end)
    end

    local entry
    local function closeThis()
        TweenService:Create(optionsFrame, TweenInfo.new(0.15), {Size = UDim2.fromOffset(112, 0), BackgroundTransparency = 1}):Play()
        TweenService:Create(chev, TweenInfo.new(0.15), {Rotation = 0, ImageColor3 = THEME.Accent}):Play()
        task.delay(0.15, function() if optionsFrame.Parent then optionsFrame.Visible = false end end)
    end
    local function openThis()
        closeAllDropdowns(entry)
        optionsFrame.Visible = true
        optionsFrame.Size = UDim2.fromOffset(112, 0)
        optionsFrame.BackgroundTransparency = 1
        TweenService:Create(optionsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(112, openHeight), BackgroundTransparency = 0}):Play()
        TweenService:Create(chev, TweenInfo.new(0.2), {Rotation = 180, ImageColor3 = THEME.AccentLight}):Play()
    end
    entry = {optionsFrame = optionsFrame, close = closeThis}
    table.insert(dropdownRegistry, entry)
    dropButton.MouseButton1Click:Connect(function() if optionsFrame.Visible then closeThis() else openThis() end end)

    local listening = false
    keyButton.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keyButton.Text = "..."
        keyButton.TextColor3 = THEME.Accent
        local conn
        conn = UserInputService.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                currentKey = inp.KeyCode
                keyButton.Text = keyName(currentKey)
                keyButton.TextColor3 = THEME.TextPrimary
                listening = false
                conn:Disconnect()
                for _, cb in ipairs(callbacks) do task.spawn(cb, currentValue, currentKey) end
            elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
                currentKey = nil
                keyButton.Text = "None"
                keyButton.TextColor3 = THEME.TextMuted
                listening = false
                conn:Disconnect()
                for _, cb in ipairs(callbacks) do task.spawn(cb, currentValue, currentKey) end
            end
        end)
    end)

    local comp = {
        id = id,
        row = row,
        get = function() return {value = currentValue, key = currentKey} end,
        set = function(v)
            if type(v) ~= "table" then return end
            if v.value and table.find(comboOptions, v.value) then currentValue = v.value; selected.Text = v.value end
            currentKey = v.key
            keyButton.Text = keyName(currentKey)
        end,
        onChange = function(cb) table.insert(callbacks, cb) end,
        destroy = function()
            ConfigManager.unregister(id)
            for i, e in ipairs(dropdownRegistry) do
                if e == entry then
                    table.remove(dropdownRegistry, i)
                    break
                end
            end
            row:Destroy()
        end,
    }
    ConfigManager.register(id, comp)
    return comp
end

local function createColorPickerRow(card, order, label, defaultColor, options)
    options = options or {}
    local id = options.id or nextId("color")

    local row = Instance.new("Frame")
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.ZIndex = 3
    row.Parent = card

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, -96, 1, 0)
    text.Text = label
    text.TextColor3 = THEME.TextPrimary
    text.Font = Enum.Font.Gotham
    text.TextSize = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.ZIndex = 3
    text.Parent = row

    local preview = Instance.new("TextButton")
    preview.AnchorPoint = Vector2.new(1, 0.5)
    preview.Position = UDim2.new(1, 0, 0.5, 0)
    preview.Size = UDim2.fromOffset(86, 22)
    preview.BackgroundColor3 = defaultColor
    preview.AutoButtonColor = false
    preview.Text = ""
    preview.ZIndex = 3
    preview.Parent = row
    corner(preview, 8)
    stroke(preview, THEME.Accent, 1, 0.4)

    local hexLabel = Instance.new("TextLabel")
    hexLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    hexLabel.Position = UDim2.fromScale(0.5, 0.5)
    hexLabel.Size = UDim2.new(1, -8, 1, 0)
    hexLabel.BackgroundTransparency = 1
    hexLabel.Text = toHex(defaultColor)
    hexLabel.TextColor3 = THEME.White
    hexLabel.Font = Enum.Font.Gotham
    hexLabel.TextSize = 10
    hexLabel.ZIndex = 4
    hexLabel.Parent = preview

    local currentColor = defaultColor
    local callbacks = {}

    local popup = Instance.new("Frame")
    popup.Name = "ColorPopup"
    popup.AnchorPoint = Vector2.new(1, 0)
    popup.Position = UDim2.new(1, 0, 0, 30)
    popup.Size = UDim2.fromOffset(250, 300)
    popup.BackgroundColor3 = THEME.PanelAlt
    popup.Visible = false
    popup.ZIndex = 200
    popup.Parent = row
    popup.ClipsDescendants = false
    corner(popup, 10)
    stroke(popup, THEME.Accent, 1, 0.35)

    local popupTitle = Instance.new("TextLabel")
    popupTitle.BackgroundTransparency = 1
    popupTitle.Position = UDim2.fromOffset(10, 7)
    popupTitle.Size = UDim2.new(1, -20, 0, 18)
    popupTitle.Text = "Color picker"
    popupTitle.TextColor3 = THEME.TextPrimary
    popupTitle.Font = Enum.Font.GothamBold
    popupTitle.TextSize = 12
    popupTitle.TextXAlignment = Enum.TextXAlignment.Left
    popupTitle.ZIndex = 201
    popupTitle.Parent = popup

    -- Large live preview.
    local livePreview = Instance.new("Frame")
    livePreview.Position = UDim2.fromOffset(10, 30)
    livePreview.Size = UDim2.new(1, -20, 0, 54)
    livePreview.BackgroundColor3 = currentColor
    livePreview.ZIndex = 201
    livePreview.Parent = popup
    corner(livePreview, 8)
    stroke(livePreview, THEME.AccentLight, 1, 0.35)

    local liveHex = Instance.new("TextLabel")
    liveHex.BackgroundTransparency = 1
    liveHex.AnchorPoint = Vector2.new(0.5, 0.5)
    liveHex.Position = UDim2.fromScale(0.5, 0.5)
    liveHex.Size = UDim2.new(1, -12, 1, 0)
    liveHex.Text = toHex(currentColor)
    liveHex.TextColor3 = THEME.White
    liveHex.Font = Enum.Font.GothamBold
    liveHex.TextSize = 12
    liveHex.ZIndex = 202
    liveHex.Parent = livePreview

    local function fireColorChanged()
        for _, cb in ipairs(callbacks) do
            task.spawn(cb, currentColor)
        end
    end

    local function setColor(c, fire)
        currentColor = c
        preview.BackgroundColor3 = c
        hexLabel.Text = toHex(c)
        livePreview.BackgroundColor3 = c
        liveHex.Text = toHex(c)
        if fire then
            fireColorChanged()
        end
    end

    local function channelValue(c, channel)
        if channel == "R" then return math.floor(c.R * 255 + 0.5) end
        if channel == "G" then return math.floor(c.G * 255 + 0.5) end
        return math.floor(c.B * 255 + 0.5)
    end

    local channelData = {
        {name = "R", color = "red",   y = 98},
        {name = "G", color = "green", y = 139},
        {name = "B", color = "blue",  y = 180},
    }

    local function composeColor(channel, value)
        local r = math.floor(currentColor.R * 255 + 0.5)
        local g = math.floor(currentColor.G * 255 + 0.5)
        local b = math.floor(currentColor.B * 255 + 0.5)
        if channel == "R" then r = value end
        if channel == "G" then g = value end
        if channel == "B" then b = value end
        return Color3.fromRGB(r, g, b)
    end

    local sliderRefs = {}

    local function updateTrackGradient(ref)
        local c = currentColor
        local other = ref.name == "R" and Color3.new(0, c.G, c.B)
            or ref.name == "G" and Color3.new(c.R, 0, c.B)
            or Color3.new(c.R, c.G, 0)
        local full = ref.name == "R" and Color3.new(1, c.G, c.B)
            or ref.name == "G" and Color3.new(c.R, 1, c.B)
            or Color3.new(c.R, c.G, 1)
        ref.gradient.Color = ColorSequence.new(other, full)
    end

    local function setSliderValue(ref, value, fire)
        value = math.clamp(math.floor(value + 0.5), 0, 255)
        local alpha = value / 255
        ref.valueLabel.Text = tostring(value)
        ref.fill.Size = UDim2.new(alpha, 0, 1, 0)
        ref.knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        if fire then
            setColor(composeColor(ref.name, value), true)
            for _, other in ipairs(sliderRefs) do
                if other ~= ref then
                    local v = channelValue(currentColor, other.name)
                    setSliderValue(other, v, false)
                end
            end
            for _, other in ipairs(sliderRefs) do
                updateTrackGradient(other)
            end
        end
    end

    for _, info in ipairs(channelData) do
        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.fromOffset(10, info.y)
        nameLabel.Size = UDim2.fromOffset(16, 16)
        nameLabel.Text = info.name
        nameLabel.TextColor3 = THEME.TextPrimary
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 201
        nameLabel.Parent = popup

        local valueLabel = Instance.new("TextLabel")
        valueLabel.AnchorPoint = Vector2.new(1, 0)
        valueLabel.Position = UDim2.new(1, -10, 0, info.y)
        valueLabel.Size = UDim2.fromOffset(32, 16)
        valueLabel.BackgroundTransparency = 1
        valueLabel.TextColor3 = THEME.AccentLight
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 11
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.ZIndex = 201
        valueLabel.Parent = popup

        local track = Instance.new("Frame")
        track.Position = UDim2.fromOffset(28, info.y + 4)
        track.Size = UDim2.new(1, -78, 0, 8)
        track.BackgroundColor3 = THEME.Panel
        track.BorderSizePixel = 0
        track.ZIndex = 201
        track.Parent = popup
        corner(track, 4)

        local gradient = Instance.new("UIGradient")
        gradient.Parent = track

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = THEME.Accent
        fill.BackgroundTransparency = 0.1
        fill.BorderSizePixel = 0
        fill.ZIndex = 202
        fill.Parent = track
        corner(fill, 4)

        local knob = Instance.new("TextButton")
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Size = UDim2.fromOffset(14, 14)
        knob.BackgroundColor3 = THEME.White
        knob.AutoButtonColor = false
        knob.Text = ""
        knob.ZIndex = 203
        knob.Parent = track
        corner(knob, 7)
        stroke(knob, THEME.Accent, 1, 0.3)

        local ref = {
            name = info.name,
            track = track,
            gradient = gradient,
            fill = fill,
            knob = knob,
            valueLabel = valueLabel,
        }
        table.insert(sliderRefs, ref)

        local dragging = false
        local function updateFromInput(x)
            local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            setSliderValue(ref, alpha * 255, true)
        end

        knob.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                TweenService:Create(knob, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
                    Size = UDim2.fromOffset(18, 18),
                }):Play()
            end
        end)

        track.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                updateFromInput(inp.Position.X)
                dragging = true
                TweenService:Create(knob, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
                    Size = UDim2.fromOffset(18, 18),
                }):Play()
            end
        end)

        UserInputService.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                or inp.UserInputType == Enum.UserInputType.Touch) then
                updateFromInput(inp.Position.X)
            end
        end)

        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                        Size = UDim2.fromOffset(14, 14),
                    }):Play()
                end
                dragging = false
            end
        end)

        knob.MouseEnter:Connect(function()
            TweenService:Create(knob, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                Size = UDim2.fromOffset(16, 16),
            }):Play()
        end)
        knob.MouseLeave:Connect(function()
            if not dragging then
                TweenService:Create(knob, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                    Size = UDim2.fromOffset(14, 14),
                }):Play()
            end
        end)
    end

    -- Presets stay available at the bottom.
    local presetsLabel = Instance.new("TextLabel")
    presetsLabel.BackgroundTransparency = 1
    presetsLabel.Position = UDim2.fromOffset(10, 219)
    presetsLabel.Size = UDim2.new(1, -20, 0, 16)
    presetsLabel.Text = "Presets"
    presetsLabel.TextColor3 = THEME.TextMuted
    presetsLabel.Font = Enum.Font.Gotham
    presetsLabel.TextSize = 10
    presetsLabel.TextXAlignment = Enum.TextXAlignment.Left
    presetsLabel.ZIndex = 201
    presetsLabel.Parent = popup

    local presets = {
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(255, 180, 60),
        Color3.fromRGB(255, 240, 80),
        Color3.fromRGB(80, 220, 120),
        Color3.fromRGB(80, 180, 255),
        Color3.fromRGB(160, 100, 255),
        Color3.fromRGB(255, 100, 200),
        Color3.fromRGB(240, 240, 240),
        Color3.fromRGB(100, 100, 100),
        Color3.fromRGB(30, 30, 30),
    }

    local palette = Instance.new("Frame")
    palette.BackgroundTransparency = 1
    palette.Position = UDim2.fromOffset(10, 238)
    palette.Size = UDim2.new(1, -20, 0, 50)
    palette.ZIndex = 201
    palette.Parent = popup

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(34, 22)
    grid.CellPadding = UDim2.fromOffset(5, 5)
    grid.Parent = palette

    for _, c in ipairs(presets) do
        local swatch = Instance.new("TextButton")
        swatch.BackgroundColor3 = c
        swatch.AutoButtonColor = false
        swatch.Text = ""
        swatch.ZIndex = 202
        swatch.Parent = palette
        corner(swatch, 6)
        swatch.MouseButton1Click:Connect(function()
            setColor(c, true)
            for _, ref in ipairs(sliderRefs) do
                setSliderValue(ref, channelValue(currentColor, ref.name), false)
                updateTrackGradient(ref)
            end
        end)
    end

    -- Initialize slider state and gradients.
    for _, ref in ipairs(sliderRefs) do
        setSliderValue(ref, channelValue(currentColor, ref.name), false)
    end
    for _, ref in ipairs(sliderRefs) do
        updateTrackGradient(ref)
    end

    preview.MouseButton1Click:Connect(function()
        popup.Visible = not popup.Visible
        if popup.Visible then
            for _, ref in ipairs(sliderRefs) do
                setSliderValue(ref, channelValue(currentColor, ref.name), false)
                updateTrackGradient(ref)
            end
            popup.ZIndex = 200
        end
    end)

    local comp = {
        id = id,
        row = row,
        get = function() return currentColor end,
        set = function(c)
            if typeof(c) == "Color3" then
                setColor(c, false)
                for _, ref in ipairs(sliderRefs) do
                    setSliderValue(ref, channelValue(currentColor, ref.name), false)
                    updateTrackGradient(ref)
                end
            end
        end,
        onChange = function(cb) table.insert(callbacks, cb) end,
        destroy = function()
            ConfigManager.unregister(id)
            row:Destroy()
        end,
    }
    ConfigManager.register(id, comp)
    return comp
end

local function createStaticRow(card, order, label, value, muted)
    local row = Instance.new("Frame")
    row.LayoutOrder           = order
    row.Size                  = UDim2.new(1, 0, 0, 20)
    row.BackgroundTransparency = 1
    row.ZIndex                = 3
    row.Parent                = card

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size           = UDim2.new(1, -60, 1, 0)
    text.Text           = label
    text.TextColor3     = muted and THEME.TextDim or THEME.TextPrimary
    text.Font           = Enum.Font.Gotham
    text.TextSize       = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.ZIndex         = 3
    text.Parent         = row

    local valLabel = Instance.new("TextLabel")
    valLabel.AnchorPoint   = Vector2.new(1, 0)
    valLabel.Position      = UDim2.new(1, 0, 0, 0)
    valLabel.Size          = UDim2.fromOffset(60, 20)
    valLabel.BackgroundTransparency = 1
    valLabel.Text          = value
    valLabel.TextColor3    = muted and THEME.TextDim or THEME.Accent
    valLabel.Font          = Enum.Font.Gotham
    valLabel.TextSize      = 13
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.ZIndex        = 3
    valLabel.Parent        = row

    return row
end

local function makeColumns(page)
    local wrapper = Instance.new("Frame")
    wrapper.Name             = "ColWrapper"
    wrapper.Size             = UDim2.new(1, -28, 0, 0)
    wrapper.AutomaticSize    = Enum.AutomaticSize.Y
    wrapper.BackgroundTransparency = 1
    wrapper.ZIndex           = 3
    wrapper.Parent           = page

    local GAP = 12

    local L = Instance.new("Frame")
    L.Size            = UDim2.new(0.5, -GAP/2, 0, 0)
    L.AutomaticSize   = Enum.AutomaticSize.Y
    L.BackgroundTransparency = 1
    L.ZIndex          = 3
    L.Parent          = wrapper
    local LL = Instance.new("UIListLayout")
    LL.Padding = UDim.new(0, 12)
    LL.Parent  = L

    local R = Instance.new("Frame")
    R.Position        = UDim2.new(0.5, GAP/2, 0, 0)
    R.Size            = UDim2.new(0.5, -GAP/2, 0, 0)
    R.AutomaticSize   = Enum.AutomaticSize.Y
    R.BackgroundTransparency = 1
    R.ZIndex          = 3
    R.Parent          = wrapper
    local RL = Instance.new("UIListLayout")
    RL.Padding = UDim.new(0, 12)
    RL.Parent  = R

    local existingPad = page:FindFirstChildOfClass("UIPadding")
    if not existingPad then
        local pad = Instance.new("UIPadding")
        pad.PaddingTop    = UDim.new(0, 14)
        pad.PaddingLeft   = UDim.new(0, 14)
        pad.PaddingRight  = UDim.new(0, 14)
        pad.PaddingBottom = UDim.new(0, 14)
        pad.Parent        = page
    end

    return L, R
end

local function makePlaceholderPage(page, label)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, -28, 0, 100)
    f.BackgroundColor3 = THEME.Card
    f.BackgroundTransparency = 0.4
    f.ZIndex           = 3
    f.Parent           = page
    corner(f, 12)
    stroke(f, THEME.Accent, 1, 0.5)
    local t = Instance.new("TextLabel")
    t.Size             = UDim2.fromScale(1, 1)
    t.BackgroundTransparency = 1
    t.Text             = label
    t.TextColor3       = THEME.TextDim
    t.Font             = Enum.Font.Gotham
    t.TextSize         = 13
    t.ZIndex           = 3
    t.Parent           = f
end


----------------------------------------------------------------
-- MSI.LUA LIBRARY API
-- Usage:
-- local Library = loadstring(SOURCE)()
-- local Tab = Library:CreateTab("Player", Library.Icons.Player)
-- local Section = Tab:CreateSection("Character", "left")
-- Section:CreateSlider("Walk speed", 16, 200, 16, 0, {id = "walk_speed"})
----------------------------------------------------------------

local Library = {}
Library.Theme = THEME
Library.Icons = ICONS
Library.Config = ConfigManager
Library.Components = {}

local activeRailIndex = 0
local selectedNode = nil
local allNodes = {}
local layoutOrder = 0
local currentQuery = ""
local expandedSnapshot = nil
local rootNode = nil
local railButtons = {}
local tabs = {}
local tabByName = {}

local function normalizeIcon(icon)
    if icon == nil then
        return ICONS.Info
    end
    if typeof(icon) == "number" then
        return "rbxassetid://" .. tostring(icon)
    end
    return tostring(icon)
end

local function setRowHighlight(node, on)
    if not node or not node.row or not node.row.Parent then
        return
    end

    TweenService:Create(node.row, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
        BackgroundTransparency = on and 0.85 or 1,
        BackgroundColor3 = on and THEME.Accent or THEME.Background,
    }):Play()

    if node.indicator then
        TweenService:Create(node.indicator, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundTransparency = on and 0 or 1,
        }):Play()
    end
end

local function markerFor(kind)
    if kind == "root" then
        return "○"
    end
    return ""
end

local function markerColor(kind)
    if kind == "root" then
        return THEME.Accent
    elseif kind == "branch" then
        return THEME.AccentDim
    end
    return THEME.TextDim
end

local function updateBreadcrumb(node)
    if not node then
        breadcrumbLabel.Text = ""
        return
    end

    local chain = {}
    local current = node
    while current do
        table.insert(chain, 1, current)
        current = current.parent
    end

    local segs = {}
    for i, seg in ipairs(chain) do
        local col = (i == #chain) and THEME.TextPrimary or THEME.TextMuted
        local marker = markerFor(seg.kind)
        local prefix = marker ~= "" and (marker .. " ") or ""

        table.insert(segs, string.format(
            '<font color="%s">%s%s</font>',
            toHex(col),
            prefix,
            seg.label
        ))
    end

    breadcrumbLabel.Text = table.concat(
        segs,
        string.format('  <font color="%s">›</font>  ', toHex(THEME.Accent))
    )
end

local function ancestorsExpanded(node)
    local p = node.parent
    while p do
        if not p.expanded then
            return false
        end
        p = p.parent
    end
    return true
end

local function searchPass(node, query)
    if query == "" then
        return true
    end

    if node.label:lower():find(query, 1, true) then
        return true
    end

    for _, child in ipairs(node.children or {}) do
        if searchPass(child, query) then
            return true
        end
    end

    return false
end

local function refreshVisibility()
    for _, node in ipairs(allNodes) do
        if node.row and node.row.Parent then
            node.row.Visible =
                ancestorsExpanded(node)
                and searchPass(node, currentQuery)
        end
    end
end

local function setExpanded(node, expanded)
    node.expanded = expanded

    if node.arrow then
        TweenService:Create(node.arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Rotation = expanded and 0 or -90,
        }):Play()
    end

    refreshVisibility()
end

local function scrollToSection(section)
    if not section or not section._tab then
        return
    end

    local page = section._tab.page
    local card = section._card

    if not page or not card or not card.Parent then
        return
    end

    if activeRailIndex ~= section._tab.index then
        return
    end

    task.defer(function()
        if not page.Parent or not card.Parent then
            return
        end

        local relativeY =
            card.AbsolutePosition.Y
            - page.AbsolutePosition.Y
            + page.CanvasPosition.Y
            - 14

        page.CanvasPosition = Vector2.new(0, math.max(0, relativeY))
    end)
end

local function selectNode(node)
    if not node then
        return
    end

    if selectedNode then
        setRowHighlight(selectedNode, false)
    end

    selectedNode = node
    setRowHighlight(node, true)
    updateBreadcrumb(node)

    if node.section then
        node.section._tab._selectedSection = node.section
        scrollToSection(node.section)
    end
end

local function clearTree()
    if selectedNode and selectedNode.row and selectedNode.row.Parent then
        setRowHighlight(selectedNode, false)
    end

    selectedNode = nil
    rootNode = nil
    allNodes = {}
    layoutOrder = 0

    for _, child in ipairs(treeScroll:GetChildren()) do
        if child:IsA("TextButton")
            or child:IsA("Frame")
            or child:IsA("TextLabel")
            or child:IsA("ImageLabel") then
            child:Destroy()
        end
    end
end

local function buildNode(data, parent, depth)
    local node = {
        label = data.label,
        kind = data.kind,
        depth = depth,
        parent = parent,
        children = {},
        expanded = data.expanded ~= false,
        section = data.section,
    }

    layoutOrder = layoutOrder + 1

    local hasKids = data.children ~= nil and #data.children > 0
    local ROW_H = 30
    local INDENT = 16

    local row = Instance.new("TextButton")
    row.Name = "Row_" .. data.label:gsub("%s+", "")
    row.LayoutOrder = layoutOrder
    row.Size = UDim2.new(1, 0, 0, ROW_H)
    row.BackgroundColor3 = THEME.Accent
    row.BackgroundTransparency = 1
    row.AutoButtonColor = false
    row.Text = ""
    row.ZIndex = 3
    row.Parent = treeScroll
    corner(row, 8)
    node.row = row

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.fromOffset(2, 16)
    indicator.Position = UDim2.new(0, 0, 0.5, -8)
    indicator.BackgroundColor3 = THEME.Accent
    indicator.BackgroundTransparency = 1
    indicator.BorderSizePixel = 0
    indicator.ZIndex = 3
    indicator.Parent = row
    corner(indicator, 1)
    node.indicator = indicator

    if hasKids then
        local arrow = Instance.new("ImageLabel")
        arrow.Position = UDim2.fromOffset(depth * INDENT + 8, 8)
        arrow.Size = UDim2.fromOffset(14, 14)
        arrow.Rotation = node.expanded and 0 or -90
        arrow.ZIndex = 3
        arrow.Parent = row
        applyIcon(arrow, ICONS.ArrowRight, THEME.Accent)
        node.arrow = arrow
    end

    local markerLabel = Instance.new("TextLabel")
    markerLabel.BackgroundTransparency = 1
    markerLabel.Position = UDim2.fromOffset(
        depth * INDENT + (hasKids and 26 or 12), 0
    )
    markerLabel.Size = UDim2.fromOffset(14, ROW_H)
    markerLabel.Text = markerFor(data.kind)
    markerLabel.TextColor3 = markerColor(data.kind)
    markerLabel.Font = Enum.Font.Gotham
    markerLabel.TextSize = 11
    markerLabel.ZIndex = 3
    markerLabel.Parent = row

    local textOffX = depth * INDENT + (hasKids and 40 or 26)
    local textLabel = Instance.new("TextLabel")
    textLabel.BackgroundTransparency = 1
    textLabel.Position = UDim2.fromOffset(textOffX, 0)
    textLabel.Size = UDim2.new(1, -textOffX - 8, 1, 0)
    textLabel.Text = data.label
    textLabel.TextColor3 =
        (data.kind == "leaf")
        and THEME.TextMuted
        or THEME.TextPrimary
    textLabel.Font =
        (data.kind == "root")
        and Enum.Font.GothamBold
        or Enum.Font.Gotham
    textLabel.TextSize = 13
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.ZIndex = 3
    textLabel.Parent = row

    row.MouseEnter:Connect(function()
        if selectedNode ~= node then
            TweenService:Create(row, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 0.95,
            }):Play()
        end
    end)

    row.MouseLeave:Connect(function()
        if selectedNode ~= node then
            TweenService:Create(row, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 1,
            }):Play()
        end
    end)

    row.MouseButton1Click:Connect(function()
        if hasKids then
            setExpanded(node, not node.expanded)
        end

        if node.section then
            selectNode(node)
        end
    end)

    table.insert(allNodes, node)

    for _, childData in ipairs(data.children or {}) do
        table.insert(node.children, buildNode(childData, node, depth + 1))
    end

    return node
end

local function rebuildTree(tab)
    clearTree()

    local children = {}

    for _, section in ipairs(tab.sections) do
        table.insert(children, {
            label = section.name,
            kind = "leaf",
            section = section,
        })
    end

    rootNode = buildNode({
        label = tab.name,
        kind = "root",
        expanded = true,
        children = children,
    }, nil, 0)

    refreshVisibility()
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = searchBox.Text:lower()

    if query ~= "" and not expandedSnapshot then
        expandedSnapshot = {}

        for _, node in ipairs(allNodes) do
            expandedSnapshot[node] = node.expanded
        end
    elseif query == "" and expandedSnapshot then
        for node, was in pairs(expandedSnapshot) do
            node.expanded = was
            if node.arrow then
                node.arrow.Rotation = was and 0 or -90
            end
        end

        expandedSnapshot = nil
    end

    currentQuery = query

    if query ~= "" then
        for _, node in ipairs(allNodes) do
            if node.label:lower():find(query, 1, true) then
                local p = node.parent

                while p do
                    p.expanded = true
                    if p.arrow then
                        p.arrow.Rotation = 0
                    end
                    p = p.parent
                end
            end
        end
    end

    refreshVisibility()
end)

local function ensurePage(index)
    if railPages[index] then
        return railPages[index]
    end

    railPages[index] = makeContentPage()
    return railPages[index]
end

local function refreshRailButtonPositions()
    for i, btn in ipairs(railButtons) do
        if btn and btn.Parent then
            local active = i == activeRailIndex
            btn.Position = UDim2.fromOffset(
                active and 9 or 10,
                10 + (i - 1) * 60
            )
            btn.Size = UDim2.fromOffset(36, 36)
        end
    end
end

local function activateRail(index, targetSection)
    local tab = tabs[index]
    if not tab then
        return
    end

    activeRailIndex = index

    for i, page in ipairs(railPages) do
        if page then
            page.Visible = (i == index)
        end
    end

    for i, button in ipairs(railButtons) do
        local icon = button:FindFirstChild("Icon")
        local active = i == index

        TweenService:Create(button, TweenInfo.new(
            0.25,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        ), {
            BackgroundColor3 = active and THEME.Accent or THEME.PanelAlt,
            BackgroundTransparency = active and 0 or 0.55,
            Size = UDim2.fromOffset(36, 36),
            Position = UDim2.fromOffset(10, 10 + (i - 1) * 60),
        }):Play()

        if icon then
            icon.ImageColor3 =
                active
                and Color3.fromRGB(0, 0, 0)
                or THEME.Accent

            TweenService:Create(icon, TweenInfo.new(
                0.3,
                Enum.EasingStyle.Back,
                Enum.EasingDirection.Out
            ), {
                Rotation = active and 360 or 0,
                Size = UDim2.fromOffset(20, 20),
            }):Play()
        end
    end

    currentQuery = ""
    expandedSnapshot = nil
    searchBox.Text = ""

    rebuildTree(tab)

    local firstSection = targetSection
    if not firstSection then
        firstSection = tab.sections[1]
    end

    if firstSection then
        for _, node in ipairs(allNodes) do
            if node.section == firstSection then
                selectNode(node)
                break
            end
        end
    else
        updateBreadcrumb({
            label = tab.name,
            kind = "root",
            children = {},
        })
    end

    local page = tab.page
    if page then
        page.CanvasPosition = Vector2.new(0, 0)
    end
end

local function buildRailButton(tab)
    local index = tab.index

    local btn = Instance.new("TextButton")
    btn.Name = "RailBtn" .. index
    btn.Position = UDim2.fromOffset(10, 10 + (index - 1) * 60)
    btn.Size = UDim2.fromOffset(36, 36)
    btn.BackgroundColor3 =
        (index == 1)
        and THEME.Accent
        or THEME.PanelAlt
    btn.BackgroundTransparency =
        (index == 1)
        and 0
        or 0.55
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.ZIndex = 3
    btn.Parent = rail
    corner(btn, 10)

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.Size = UDim2.fromOffset(20, 20)
    icon.ZIndex = 4
    icon.Parent = btn

    applyIcon(
        icon,
        tab.icon,
        (index == 1)
        and Color3.fromRGB(0, 0, 0)
        or THEME.Accent
    )

    btn.MouseEnter:Connect(function()
        showTooltip(tab.name, btn, "right")

        if activeRailIndex ~= index then
            TweenService:Create(icon, TweenInfo.new(
                0.18,
                Enum.EasingStyle.Back
            ), {
                Size = UDim2.fromOffset(22, 22),
            }):Play()

            TweenService:Create(btn, TweenInfo.new(
                0.15,
                Enum.EasingStyle.Quad
            ), {
                BackgroundTransparency = 0.35,
                BackgroundColor3 = THEME.AccentDim,
                Size = UDim2.fromOffset(40, 40),
                Position = UDim2.fromOffset(
                    8,
                    8 + (index - 1) * 60
                ),
            }):Play()
        end
    end)

    btn.MouseLeave:Connect(function()
        hideTooltip()

        if activeRailIndex ~= index then
            TweenService:Create(icon, TweenInfo.new(
                0.15,
                Enum.EasingStyle.Quad
            ), {
                Size = UDim2.fromOffset(20, 20),
            }):Play()

            icon.ImageColor3 = THEME.Accent

            TweenService:Create(btn, TweenInfo.new(
                0.15,
                Enum.EasingStyle.Quad
            ), {
                BackgroundTransparency = 0.55,
                BackgroundColor3 = THEME.PanelAlt,
                Size = UDim2.fromOffset(36, 36),
                Position = UDim2.fromOffset(
                    10,
                    10 + (index - 1) * 60
                ),
            }):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        activateRail(index)
    end)

    railButtons[index] = btn
end

function Library:CreateTab(name, icon)
    assert(type(name) == "string" and name ~= "", "CreateTab: name is required")

    local tab = {
        name = name,
        icon = normalizeIcon(icon),
        index = #tabs + 1,
        sections = {},
        page = ensurePage(#tabs + 1),
        _columnsReady = false,
        _left = nil,
        _right = nil,
    }

    if tabByName[name] then
        error("CreateTab: tab already exists: " .. name)
    end

    tabByName[name] = tab
    table.insert(tabs, tab)

    local left, right = makeColumns(tab.page)
    tab._left = left
    tab._right = right
    tab._columnsReady = true

    buildRailButton(tab)
    refreshRailButtonPositions()

    if #tabs == 1 then
        activateRail(tab.index)
    end

    return tab
end

function Library:GetTab(name)
    return tabByName[name]
end

function Library:SelectTab(tabOrName)
    local tab = tabOrName

    if type(tabOrName) == "string" then
        tab = tabByName[tabOrName]
    end

    if not tab then
        return
    end

    activateRail(tab.index)
end

local function ensureDefaultSection(tab)
    if tab._defaultSection then
        return tab._defaultSection
    end

    tab._defaultSection = tab:CreateSection("Main", "left")
    return tab._defaultSection
end

local toggleMenu

function Library:SetKeybindListVisible(value)
    if setKeybindListVisible then
        setKeybindListVisible(value)
    end
end

function Library:Notify(title, text, ntype, duration)
    return notify(title, text, ntype, duration)
end

function Library:Toggle()
    return toggleMenu()
end

function Library:SaveConfig(name)
    return ConfigManager.save(name)
end

function Library:LoadConfig(name)
    return ConfigManager.load(name)
end

function Library:Destroy()
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
end

function Library:_refreshTabTree(tab)
    if activeRailIndex == tab.index then
        rebuildTree(tab)

        local section = tab._selectedSection or tab.sections[1]
        if section then
            for _, node in ipairs(allNodes) do
                if node.section == section then
                    selectNode(node)
                    break
                end
            end
        end
    end
end

function Library:_createSection(tab, name, side, options)
    assert(type(name) == "string" and name ~= "", "CreateSection: name is required")

    options = options or {}

    local selectedSide = side
    if type(side) == "table" then
        options = side
        selectedSide = options.side
    end

    local sideName = selectedSide
    if sideName ~= "left" and sideName ~= "right" then
        sideName = (#tab.sections % 2 == 0) and "left" or "right"
    end

    local target = sideName == "right" and tab._right or tab._left
    local order = 1

    for _, section in ipairs(tab.sections) do
        if section.side == sideName then
            order = order + 1
        end
    end

    local card = createCard(target, name, order)

    local section = {
        name = name,
        side = sideName,
        order = order,
        _tab = tab,
        _card = card,
        _components = {},
        _counter = 0,
    }

    function section:_nextOrder()
        self._counter = self._counter + 1
        return self._counter
    end

    function section:CreateToggle(label, default, opts)
        local comp = createToggleRow(
            self._card,
            self:_nextOrder(),
            label,
            default,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateSlider(label, min, max, default, decimals, opts)
        local comp = createSliderRow(
            self._card,
            self:_nextOrder(),
            label,
            min,
            max,
            default,
            decimals,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateDropdown(label, values, default, opts)
        local comp = createDropdownRow(
            self._card,
            self:_nextOrder(),
            label,
            values,
            default,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateColorPicker(label, defaultColor, opts)
        local comp = createColorPickerRow(
            self._card,
            self:_nextOrder(),
            label,
            defaultColor,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateKeybind(label, defaultKey, opts)
        local comp = createKeybindRow(
            self._card,
            self:_nextOrder(),
            label,
            defaultKey,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateKeybindCombo(
        label,
        values,
        defaultValue,
        defaultKey,
        opts
    )
        local comp = createComboRow(
            self._card,
            self:_nextOrder(),
            label,
            values,
            defaultValue,
            defaultKey,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateTextBox(
        label,
        placeholder,
        defaultText,
        opts
    )
        local comp = createTextBoxRow(
            self._card,
            self:_nextOrder(),
            label,
            placeholder,
            defaultText,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateLabel(textValue, opts)
        return createLabelRow(
            self._card,
            self:_nextOrder(),
            textValue,
            opts
        )
    end

    function section:CreateButton(label, color, callback)
        return createButtonRow(
            self._card,
            self:_nextOrder(),
            label,
            color,
            callback
        )
    end

    function section:CreateStatic(label, value, muted)
        return createStaticRow(
            self._card,
            self:_nextOrder(),
            label,
            value,
            muted
        )
    end

    function section:Destroy()
        for id, comp in pairs(ConfigManager.components) do
            if comp
                and comp.row
                and comp.row:IsDescendantOf(self._card) then
                ConfigManager.unregister(id)
            end
        end

        for id, entry in pairs(keybindRegistry) do
            if entry
                and entry.row
                and entry.row:IsDescendantOf(self._card) then
                keybindRegistry[id] = nil
            end
        end

        for i, value in ipairs(tab.sections) do
            if value == self then
                table.remove(tab.sections, i)
                break
            end
        end

        if tab._selectedSection == self then
            tab._selectedSection = tab.sections[1]
        end

        self._card:Destroy()
        Library:_refreshTabTree(tab)
    end

    table.insert(tab.sections, section)

    Library:_refreshTabTree(tab)

    if not tab._selectedSection then
        tab._selectedSection = section
    end

    return section
end

function Library:_installTabMethods(tab)
    function tab:CreateSection(name, side, options)
        return Library:_createSection(self, name, side, options)
    end

    function tab:SelectSection(sectionOrName)
        local section = sectionOrName

        if type(sectionOrName) == "string" then
            for _, item in ipairs(self.sections) do
                if item.name == sectionOrName then
                    section = item
                    break
                end
            end
        end

        if not section then
            return
        end

        self._selectedSection = section

        if activeRailIndex ~= self.index then
            activateRail(self.index, section)
            return
        end

        for _, node in ipairs(allNodes) do
            if node.section == section then
                selectNode(node)
                break
            end
        end
    end

    function tab:CreateToggle(label, default, opts)
        return ensureDefaultSection(self):CreateToggle(label, default, opts)
    end

    function tab:CreateSlider(label, min, max, default, decimals, opts)
        return ensureDefaultSection(self):CreateSlider(
            label,
            min,
            max,
            default,
            decimals,
            opts
        )
    end

    function tab:CreateDropdown(label, values, default, opts)
        return ensureDefaultSection(self):CreateDropdown(
            label,
            values,
            default,
            opts
        )
    end

    function tab:CreateColorPicker(label, defaultColor, opts)
        return ensureDefaultSection(self):CreateColorPicker(
            label,
            defaultColor,
            opts
        )
    end

    function tab:CreateKeybind(label, defaultKey, opts)
        return ensureDefaultSection(self):CreateKeybind(
            label,
            defaultKey,
            opts
        )
    end

    function tab:CreateKeybindCombo(label, values, defaultValue, defaultKey, opts)
        return ensureDefaultSection(self):CreateKeybindCombo(
            label,
            values,
            defaultValue,
            defaultKey,
            opts
        )
    end

    function tab:CreateTextBox(label, placeholder, defaultText, opts)
        return ensureDefaultSection(self):CreateTextBox(
            label,
            placeholder,
            defaultText,
            opts
        )
    end

    function tab:CreateLabel(textValue, opts)
        return ensureDefaultSection(self):CreateLabel(textValue, opts)
    end

    function tab:CreateButton(label, color, callback)
        return ensureDefaultSection(self):CreateButton(label, color, callback)
    end

    function tab:CreateStatic(label, value, muted)
        return ensureDefaultSection(self):CreateStatic(label, value, muted)
    end

    function tab:Destroy()
        for id, comp in pairs(ConfigManager.components) do
            if comp
                and comp.row
                and comp.row:IsDescendantOf(self.page) then
                ConfigManager.unregister(id)
            end
        end

        for id, entry in pairs(keybindRegistry) do
            if entry
                and entry.row
                and entry.row:IsDescendantOf(self.page) then
                keybindRegistry[id] = nil
            end
        end

        if railButtons[self.index] then
            railButtons[self.index]:Destroy()
            table.remove(railButtons, self.index)
        end

        if self.page then
            self.page:Destroy()
        end

        tabByName[self.name] = nil

        for i, item in ipairs(tabs) do
            if item == self then
                table.remove(tabs, i)
                break
            end
        end

        for i, item in ipairs(tabs) do
            item.index = i
        end

        if #tabs == 0 then
            activeRailIndex = 0
            breadcrumbLabel.Text = ""
            clearTree()
            return
        end

        refreshRailButtonPositions()

        if activeRailIndex > #tabs then
            activeRailIndex = #tabs
        end

        activateRail(activeRailIndex)
    end

    return tab
end

-- Wrap CreateTab so every returned tab receives its API methods.
do
    local rawCreateTab = Library.CreateTab

    function Library:CreateTab(name, icon)
        local tab = rawCreateTab(self, name, icon)
        self:_installTabMethods(tab)
        return tab
    end
end

----------------------------------------------------------------
-- SIDEBAR COLLAPSE
----------------------------------------------------------------
local sidebarCollapsed = false

collapseButton.MouseButton1Click:Connect(function()
    sidebarCollapsed = not sidebarCollapsed

    local targetW = sidebarCollapsed and 0 or SIDEBAR_W
    local targetCX = RAIL_W + targetW

    TweenService:Create(
        sidebar,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {
            Size = UDim2.new(0, targetW, 1, -HEADER_H),
        }
    ):Play()

    TweenService:Create(
        sidebarBorder,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {
            BackgroundTransparency = sidebarCollapsed and 1 or 0.4,
        }
    ):Play()

    TweenService:Create(
        contentHost,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {
            Position = UDim2.fromOffset(targetCX, HEADER_H),
            Size = UDim2.new(1, -targetCX, 1, -HEADER_H),
        }
    ):Play()

    TweenService:Create(
        collapseArrow,
        TweenInfo.new(0.2, Enum.EasingStyle.Back),
        {
            Rotation = sidebarCollapsed and 270 or 90,
            ImageColor3 =
                sidebarCollapsed
                and THEME.AccentLight
                or THEME.TextMuted,
        }
    ):Play()
end)

----------------------------------------------------------------
-- WINDOW DRAG
----------------------------------------------------------------
local wDragging = false
local wDragStart, wStartPos

header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then

        wDragging = true
        wDragStart = inp.Position
        wStartPos = window.Position
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if wDragging
        and (
            inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch
        ) then

        local delta = inp.Position - wDragStart

        window.Position = UDim2.new(
            wStartPos.X.Scale,
            wStartPos.X.Offset + delta.X,
            wStartPos.Y.Scale,
            wStartPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        wDragging = false
    end
end)

----------------------------------------------------------------
-- HEADER BUTTONS
----------------------------------------------------------------
local menuOpen = true

toggleMenu = function()
    menuOpen = not menuOpen
    hideTooltip()

    if menuOpen then
        window.Visible = true

        TweenService:Create(
            window,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                Size = UDim2.fromOffset(960, 600),
                BackgroundTransparency = 0,
            }
        ):Play()
    else
        TweenService:Create(
            window,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad),
            {
                Size = UDim2.fromOffset(960, 0),
                BackgroundTransparency = 1,
            }
        ):Play()

        task.delay(0.25, function()
            if not menuOpen then
                window.Visible = false
            end
        end)
    end
end

closeBtn.MouseButton1Click:Connect(function()
    hideTooltip()

    TweenService:Create(
        window,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(960, 0),
        }
    ):Play()

    task.wait(0.3)

    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
end)

minBtn.MouseButton1Click:Connect(function()
    toggleMenu()
end)

saveBtn.MouseButton1Click:Connect(function()
    ConfigManager.save(ConfigManager.current)
end)

loadBtn.MouseButton1Click:Connect(function()
    ConfigManager.load(ConfigManager.current)
end)

----------------------------------------------------------------
-- CLOSE DROPDOWNS ON OUTSIDE CLICK
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then
        return
    end

    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        closeAllDropdowns()
    end
end)

----------------------------------------------------------------
-- KEYBINDS
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then
        return
    end

    if inp.UserInputType == Enum.UserInputType.Keyboard
        and inp.KeyCode == toggleKey then
        toggleMenu()
    end
end)

----------------------------------------------------------------
-- WATERMARK
----------------------------------------------------------------
local function getExecutorName()
    local ok, name = pcall(function()
        if identifyexecutor then
            return identifyexecutor()
        end

        if getexecutorname then
            return getexecutorname()
        end

        return "Unknown"
    end)

    return ok and tostring(name) or "Unknown"
end

watermark = Instance.new("Frame")
watermark.Name = "Watermark"
watermark.AnchorPoint = Vector2.new(1, 0)
watermark.Position = UDim2.new(1, -12, 0, 12)
watermark.Size = UDim2.fromOffset(0, 28)
watermark.AutomaticSize = Enum.AutomaticSize.X
watermark.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
watermark.BackgroundTransparency = 0
watermark.BorderSizePixel = 0
watermark.ZIndex = 120
watermark.Parent = screenGui
corner(watermark, 8)
stroke(watermark, THEME.Accent, 1, 0.45)

local wmPad = Instance.new("UIPadding")
wmPad.PaddingLeft = UDim.new(0, 8)
wmPad.PaddingRight = UDim.new(0, 8)
wmPad.Parent = watermark

local wmLayout = Instance.new("UIListLayout")
wmLayout.FillDirection = Enum.FillDirection.Horizontal
wmLayout.VerticalAlignment = Enum.VerticalAlignment.Center
wmLayout.Padding = UDim.new(0, 6)
wmLayout.Parent = watermark

local wmDragon = Instance.new("ImageLabel")
wmDragon.Size = UDim2.fromOffset(22, 22)
wmDragon.BackgroundTransparency = 1
wmDragon.Image = "rbxassetid://78464903954782"
wmDragon.ScaleType = Enum.ScaleType.Fit
wmDragon.ZIndex = 121
wmDragon.Parent = watermark

local wmDivider = Instance.new("Frame")
wmDivider.Size = UDim2.fromOffset(1, 16)
wmDivider.BackgroundColor3 = THEME.Accent
wmDivider.BackgroundTransparency = 0.25
wmDivider.BorderSizePixel = 0
wmDivider.ZIndex = 121
wmDivider.Parent = watermark

local wmText = Instance.new("TextLabel")
wmText.Size = UDim2.fromOffset(0, 20)
wmText.AutomaticSize = Enum.AutomaticSize.X
wmText.BackgroundTransparency = 1
wmText.TextColor3 = THEME.TextPrimary
wmText.Font = Enum.Font.Gotham
wmText.TextSize = 11
wmText.TextXAlignment = Enum.TextXAlignment.Left
wmText.ZIndex = 121
wmText.Parent = watermark

do
    local frames, last, fps = 0, tick(), 0

    RunService.RenderStepped:Connect(function()
        frames = frames + 1

        local now = tick()
        if now - last >= 1 then
            fps = math.floor(frames / (now - last) + 0.5)
            frames = 0
            last = now
        end
    end)

    task.spawn(function()
        local exec = getExecutorName()

        while watermark.Parent do
            local ping = 0

            pcall(function()
                ping = math.floor(
                    (player:GetNetworkPing() or 0) * 1000 + 0.5
                )
            end)

            wmText.Text = string.format(
                "%s  ·  %d FPS  ·  %d ms  ·  %s  ·  %s",
                player.DisplayName,
                fps,
                ping,
                os.date("%H:%M"),
                exec
            )

            task.wait(0.5)
        end
    end)
end

do
    local dragging = false
    local dragStart
    local startPos

    watermark.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = inp.Position
            startPos = watermark.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if dragging
            and (
                inp.UserInputType == Enum.UserInputType.MouseMovement
                or inp.UserInputType == Enum.UserInputType.Touch
            ) then

            local delta = inp.Position - dragStart

            watermark.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

----------------------------------------------------------------
-- KEYBIND LIST
----------------------------------------------------------------
local keybindListHost = nil
local keybindListEnabled = false

local function rebuildKeybindList()
    if not keybindListHost then
        return
    end

    for _, child in ipairs(keybindListHost:GetChildren()) do
        if child.Name ~= "Title"
            and not child:IsA("UIListLayout")
            and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    local entries = {}

    for _, entry in pairs(keybindRegistry) do
        local key = entry.get and entry.get() or nil

        if entry.row and entry.row.Parent and key then
            table.insert(entries, {
                label = entry.label,
                key = key,
                mode = entry.getMode and entry.getMode() or "Toggle",
            })
        end
    end

    table.sort(entries, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    keybindListHost.Visible =
        keybindListEnabled
        and #entries > 0

    if not keybindListHost.Visible then
        return
    end

    for i, item in ipairs(entries) do
        local row = Instance.new("Frame")
        row.LayoutOrder = i
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundTransparency = 1
        row.ZIndex = 131
        row.Parent = keybindListHost

        local name = Instance.new("TextLabel")
        name.BackgroundTransparency = 1
        name.Size = UDim2.new(1, -88, 1, 0)
        name.Text = item.label
        name.TextColor3 = THEME.TextPrimary
        name.Font = Enum.Font.Gotham
        name.TextSize = 11
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.ZIndex = 132
        name.Parent = row

        local mode = Instance.new("TextLabel")
        mode.AnchorPoint = Vector2.new(1, 0.5)
        mode.Position = UDim2.new(1, -48, 0.5, 0)
        mode.Size = UDim2.fromOffset(40, 16)
        mode.BackgroundTransparency = 1
        mode.Text = item.mode
        mode.TextColor3 = THEME.TextDim
        mode.Font = Enum.Font.Gotham
        mode.TextSize = 9
        mode.TextXAlignment = Enum.TextXAlignment.Right
        mode.ZIndex = 132
        mode.Parent = row

        local key = Instance.new("TextLabel")
        key.AnchorPoint = Vector2.new(1, 0.5)
        key.Position = UDim2.new(1, 0, 0.5, 0)
        key.Size = UDim2.fromOffset(42, 20)
        key.BackgroundColor3 = THEME.PanelAlt
        key.Text = keyName(item.key)
        key.TextColor3 = THEME.AccentLight
        key.Font = Enum.Font.GothamBold
        key.TextSize = 10
        key.TextXAlignment = Enum.TextXAlignment.Center
        key.ZIndex = 133
        key.Parent = row
        corner(key, 6)
        stroke(key, THEME.Accent, 1, 0.45)
    end
end

keybindListHost = Instance.new("Frame")
keybindListHost.Name = "KeybindList"
keybindListHost.AnchorPoint = Vector2.new(1, 0)
keybindListHost.Position = UDim2.new(1, -12, 0, 48)
keybindListHost.Size = UDim2.fromOffset(220, 0)
keybindListHost.AutomaticSize = Enum.AutomaticSize.Y
keybindListHost.BackgroundColor3 = THEME.Card
keybindListHost.BackgroundTransparency = 0.12
keybindListHost.Visible = false
keybindListHost.ZIndex = 130
keybindListHost.Parent = screenGui
corner(keybindListHost, 10)
stroke(keybindListHost, THEME.Accent, 1, 0.35)

local kbTitle = Instance.new("TextLabel")
kbTitle.Name = "Title"
kbTitle.Size = UDim2.new(1, 0, 0, 24)
kbTitle.BackgroundTransparency = 1
kbTitle.Text = "KEYBINDS"
kbTitle.TextColor3 = THEME.Accent
kbTitle.Font = Enum.Font.GothamBold
kbTitle.TextSize = 11
kbTitle.TextXAlignment = Enum.TextXAlignment.Left
kbTitle.ZIndex = 131
kbTitle.Parent = keybindListHost

local kbPad = Instance.new("UIPadding")
kbPad.PaddingTop = UDim.new(0, 7)
kbPad.PaddingBottom = UDim.new(0, 7)
kbPad.PaddingLeft = UDim.new(0, 10)
kbPad.PaddingRight = UDim.new(0, 10)
kbPad.Parent = keybindListHost

local kbLayout = Instance.new("UIListLayout")
kbLayout.SortOrder = Enum.SortOrder.LayoutOrder
kbLayout.Padding = UDim.new(0, 2)
kbLayout.Parent = keybindListHost

setKeybindListVisible = function(value)
    keybindListEnabled = value == true

    if not keybindListEnabled then
        keybindListHost.Visible = false
    else
        rebuildKeybindList()
    end
end

task.spawn(function()
    while screenGui.Parent do
        if keybindListEnabled then
            rebuildKeybindList()
        end
        task.wait(0.2)
    end
end)



----------------------------------------------------------------
-- KEY SYSTEM API
-- Usage:
-- local KeySystem = Library:CreateKeySystem({
--     ValidKeys = { ["MY-KEY"] = true },
--     KeyLink = "https://example.com/getkey",
-- })
----------------------------------------------------------------

local lastKeySystem = nil

function Library:CreateKeySystem(options)
    options = options or {}

    if lastKeySystem and lastKeySystem.Destroy then
        pcall(lastKeySystem.Destroy)
    end

    local validKeys = options.ValidKeys or options.Keys or {
        ["PASTE-YOUR-KEY-HERE"] = true,
    }

    local keyLink = options.KeyLink or "https://your-key-link-here.com"
    local backgroundImage = options.BackgroundImage or "rbxassetid://122286881817734"
    local kickMessage = options.KickMessage or "Invalid key. Please get a new key and try again."
    local blurSizeOnFail = options.BlurSizeOnFail or 24
    local kickDelay = options.KickDelay or 1.4
    local kickOnClose = options.KickOnClose ~= false
    local autoDestroyOnValid = options.AutoDestroyOnValid ~= false
    local onSuccess = options.OnSuccess
    local onFailure = options.OnFailure

    local blur = Instance.new("BlurEffect")
    blur.Name = "KeySystemBlur"
    blur.Size = 0
    blur.Parent = Lighting

    local screen = Instance.new("ScreenGui")
    screen.Name = options.Name or "MSIKeySystem"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = options.DisplayOrder or 1100
    screen.Parent = playerGui

    local backdrop = Instance.new("Frame")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.15
    backdrop.BorderSizePixel = 0
    backdrop.Parent = screen

    local gradientOverlay = Instance.new("Frame")
    gradientOverlay.Name = "GradientOverlay"
    gradientOverlay.Size = UDim2.fromScale(1, 1)
    gradientOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    gradientOverlay.BackgroundTransparency = 0.35
    gradientOverlay.BorderSizePixel = 0
    gradientOverlay.ZIndex = 2
    gradientOverlay.Parent = backdrop

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(10, 0, 20)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(45, 0, 80)),
    })
    gradient.Rotation = 90
    gradient.Parent = gradientOverlay

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(560, 260)
    panel.BackgroundColor3 = Color3.fromRGB(12, 8, 18)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.ZIndex = 5
    panel.Parent = backdrop
    corner(panel, 14)

    local panelStroke = stroke(panel, Color3.fromRGB(120, 60, 190), 1.5, 0.3)

    local panelImage = Instance.new("ImageLabel")
    panelImage.Name = "PanelBackgroundImage"
    panelImage.Size = UDim2.fromScale(1, 1)
    panelImage.BackgroundTransparency = 1
    panelImage.Image = backgroundImage
    panelImage.ImageTransparency = 0
    panelImage.ScaleType = Enum.ScaleType.Crop
    panelImage.ZIndex = 3
    panelImage.Parent = panel

    local panelTint = Instance.new("Frame")
    panelTint.Name = "PanelTint"
    panelTint.Size = UDim2.fromScale(1, 1)
    panelTint.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    panelTint.BackgroundTransparency = 0.15
    panelTint.BorderSizePixel = 0
    panelTint.ZIndex = 4
    panelTint.Parent = panel

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.AnchorPoint = Vector2.new(1, 0)
    closeButton.Position = UDim2.new(1, -12, 0, 12)
    closeButton.Size = UDim2.fromOffset(28, 28)
    closeButton.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(220, 200, 235)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 14
    closeButton.AutoButtonColor = false
    closeButton.ZIndex = 6
    closeButton.Parent = panel
    corner(closeButton, 14)

    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(160, 40, 60),
        }):Play()
    end)

    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(30, 20, 40),
        }):Play()
    end)

    local leftContainer = Instance.new("Frame")
    leftContainer.Name = "LeftContainer"
    leftContainer.Position = UDim2.fromOffset(24, 24)
    leftContainer.Size = UDim2.fromOffset(200, 212)
    leftContainer.BackgroundTransparency = 1
    leftContainer.ZIndex = 6
    leftContainer.Parent = panel

    local avatarFrame = Instance.new("Frame")
    avatarFrame.Name = "AvatarFrame"
    avatarFrame.Size = UDim2.fromOffset(84, 84)
    avatarFrame.BackgroundColor3 = Color3.fromRGB(25, 16, 35)
    avatarFrame.ZIndex = 6
    avatarFrame.Parent = leftContainer
    corner(avatarFrame, 10)
    stroke(avatarFrame, Color3.fromRGB(150, 90, 220), 1.5, 0)

    local avatarImage = Instance.new("ImageLabel")
    avatarImage.Name = "AvatarImage"
    avatarImage.Size = UDim2.fromScale(1, 1)
    avatarImage.BackgroundTransparency = 1
    avatarImage.ScaleType = Enum.ScaleType.Fit
    avatarImage.ZIndex = 6
    avatarImage.Parent = avatarFrame
    corner(avatarImage, 10)

    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size180x180
            )
        end)
        if ok then
            avatarImage.Image = content
        end
    end)

    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "UsernameLabel"
    usernameLabel.Position = UDim2.fromOffset(0, 92)
    usernameLabel.Size = UDim2.fromOffset(200, 22)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = player.DisplayName
    usernameLabel.TextColor3 = Color3.fromRGB(230, 220, 240)
    usernameLabel.Font = Enum.Font.GothamBold
    usernameLabel.TextSize = 18
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
    usernameLabel.ZIndex = 6
    usernameLabel.Parent = leftContainer

    local handleLabel = Instance.new("TextLabel")
    handleLabel.Name = "HandleLabel"
    handleLabel.Position = UDim2.fromOffset(0, 114)
    handleLabel.Size = UDim2.fromOffset(200, 16)
    handleLabel.BackgroundTransparency = 1
    handleLabel.Text = "@" .. player.Name
    handleLabel.TextColor3 = Color3.fromRGB(160, 140, 190)
    handleLabel.Font = Enum.Font.Gotham
    handleLabel.TextSize = 13
    handleLabel.TextXAlignment = Enum.TextXAlignment.Left
    handleLabel.ZIndex = 6
    handleLabel.Parent = leftContainer

    local function getPlatformName()
        local ok, platform = pcall(function()
            return UserInputService:GetPlatform()
        end)
        if not ok then
            return "Unknown"
        end
        local map = {
            [Enum.Platform.Windows] = "Windows",
            [Enum.Platform.OSX] = "macOS",
            [Enum.Platform.IOS] = "iOS",
            [Enum.Platform.Android] = "Android",
            [Enum.Platform.XBoxOne] = "Xbox",
            [Enum.Platform.PS4] = "PlayStation",
            [Enum.Platform.PS5] = "PlayStation",
        }
        return map[platform] or "Unknown"
    end

    local platformLabel = Instance.new("TextLabel")
    platformLabel.Name = "PlatformLabel"
    platformLabel.Position = UDim2.fromOffset(0, 140)
    platformLabel.Size = UDim2.fromOffset(200, 16)
    platformLabel.BackgroundTransparency = 1
    platformLabel.Text = "Platform: " .. getPlatformName()
    platformLabel.TextColor3 = Color3.fromRGB(180, 160, 210)
    platformLabel.Font = Enum.Font.Gotham
    platformLabel.TextSize = 13
    platformLabel.TextXAlignment = Enum.TextXAlignment.Left
    platformLabel.ZIndex = 6
    platformLabel.Parent = leftContainer

    local dateLabel = Instance.new("TextLabel")
    dateLabel.Name = "DateLabel"
    dateLabel.Position = UDim2.fromOffset(0, 162)
    dateLabel.Size = UDim2.fromOffset(200, 16)
    dateLabel.BackgroundTransparency = 1
    dateLabel.Text = os.date("%Y-%m-%d")
    dateLabel.TextColor3 = Color3.fromRGB(180, 160, 210)
    dateLabel.Font = Enum.Font.Gotham
    dateLabel.TextSize = 13
    dateLabel.TextXAlignment = Enum.TextXAlignment.Left
    dateLabel.ZIndex = 6
    dateLabel.Parent = leftContainer

    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "TimeLabel"
    timeLabel.Position = UDim2.fromOffset(0, 184)
    timeLabel.Size = UDim2.fromOffset(200, 16)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = os.date("%H:%M:%S")
    timeLabel.TextColor3 = Color3.fromRGB(180, 160, 210)
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextSize = 13
    timeLabel.TextXAlignment = Enum.TextXAlignment.Left
    timeLabel.ZIndex = 6
    timeLabel.Parent = leftContainer

    local timeThread = true
    task.spawn(function()
        while timeThread and screen.Parent do
            timeLabel.Text = os.date("%H:%M:%S")
            dateLabel.Text = os.date("%Y-%m-%d")
            task.wait(1)
        end
    end)

    local rightContainer = Instance.new("Frame")
    rightContainer.Name = "RightContainer"
    rightContainer.Position = UDim2.fromOffset(248, 24)
    rightContainer.Size = UDim2.fromOffset(288, 212)
    rightContainer.BackgroundTransparency = 1
    rightContainer.ZIndex = 6
    rightContainer.Parent = panel

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.fromOffset(288, 18)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = options.StatusText or "Enter your key to continue"
    statusLabel.TextColor3 = Color3.fromRGB(190, 170, 220)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 13
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 6
    statusLabel.Parent = rightContainer

    local keyInputFrame = Instance.new("Frame")
    keyInputFrame.Name = "KeyInputFrame"
    keyInputFrame.Position = UDim2.fromOffset(0, 26)
    keyInputFrame.Size = UDim2.fromOffset(288, 42)
    keyInputFrame.BackgroundColor3 = Color3.fromRGB(20, 14, 28)
    keyInputFrame.ZIndex = 6
    keyInputFrame.Parent = rightContainer
    corner(keyInputFrame, 8)
    local keyInputStroke = stroke(keyInputFrame, Color3.fromRGB(110, 70, 170), 1.2, 0.2)

    local keyInput = Instance.new("TextBox")
    keyInput.Name = "KeyInput"
    keyInput.Position = UDim2.fromOffset(12, 0)
    keyInput.Size = UDim2.fromOffset(264, 42)
    keyInput.BackgroundTransparency = 1
    keyInput.PlaceholderText = options.Placeholder or "Paste your key here..."
    keyInput.PlaceholderColor3 = Color3.fromRGB(120, 100, 145)
    keyInput.Text = ""
    keyInput.TextColor3 = Color3.fromRGB(230, 220, 240)
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 14
    keyInput.TextXAlignment = Enum.TextXAlignment.Left
    keyInput.ClearTextOnFocus = false
    keyInput.ZIndex = 6
    keyInput.Parent = keyInputFrame

    keyInput.Focused:Connect(function()
        TweenService:Create(keyInputStroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(180, 80, 255),
            Transparency = 0,
        }):Play()
    end)

    keyInput.FocusLost:Connect(function()
        TweenService:Create(keyInputStroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(110, 70, 170),
            Transparency = 0.2,
        }):Play()
    end)

    local function makeKeyButton(name, text, position, size, color)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Position = position
        button.Size = size
        button.BackgroundColor3 = color
        button.Text = text
        button.TextColor3 = Color3.fromRGB(240, 235, 245)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 15
        button.AutoButtonColor = false
        button.ZIndex = 6
        button.Parent = rightContainer
        corner(button, 8)

        local baseColor = color
        local hoverColor = Color3.new(
            math.min(baseColor.R + 0.12, 1),
            math.min(baseColor.G + 0.12, 1),
            math.min(baseColor.B + 0.12, 1)
        )

        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.15), {
                BackgroundColor3 = hoverColor,
            }):Play()
        end)

        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.15), {
                BackgroundColor3 = baseColor,
            }):Play()
        end)

        return button
    end

    local getKeyButton = makeKeyButton(
        "GetKeyButton",
        "Get Key",
        UDim2.fromOffset(0, 80),
        UDim2.fromOffset(138, 40),
        Color3.fromRGB(45, 32, 65)
    )

    local verifyButton = makeKeyButton(
        "VerifyButton",
        "Verify Key",
        UDim2.fromOffset(150, 80),
        UDim2.fromOffset(138, 40),
        Color3.fromRGB(95, 45, 160)
    )

    local hintLabel = Instance.new("TextLabel")
    hintLabel.Name = "HintLabel"
    hintLabel.Position = UDim2.fromOffset(0, 134)
    hintLabel.Size = UDim2.fromOffset(288, 60)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Text = options.HintText or "Keys are free and take under a minute to grab. Wrong keys will remove you from the game."
    hintLabel.TextColor3 = Color3.fromRGB(140, 120, 165)
    hintLabel.TextWrapped = true
    hintLabel.Font = Enum.Font.Gotham
    hintLabel.TextSize = 12
    hintLabel.TextXAlignment = Enum.TextXAlignment.Left
    hintLabel.TextYAlignment = Enum.TextYAlignment.Top
    hintLabel.ZIndex = 6
    hintLabel.Parent = rightContainer

    local verifying = false
    local destroyed = false

    local function setStatus(textValue, color)
        statusLabel.Text = textValue
        statusLabel.TextColor3 = color
    end

    local function shakePanel()
        local originalPosition = panel.Position
        local sequence = {
            originalPosition + UDim2.fromOffset(-10, 0),
            originalPosition + UDim2.fromOffset(10, 0),
            originalPosition + UDim2.fromOffset(-6, 0),
            originalPosition + UDim2.fromOffset(6, 0),
            originalPosition,
        }
        for _, position in ipairs(sequence) do
            TweenService:Create(panel, TweenInfo.new(0.05), {
                Position = position,
            }):Play()
            task.wait(0.05)
        end
    end

    local function destroyVisuals(afterClose)
        if destroyed then
            if afterClose then
                task.spawn(afterClose)
            end
            return
        end
        destroyed = true
        timeThread = false
        TweenService:Create(blur, TweenInfo.new(0.4), {Size = 0}):Play()
        TweenService:Create(backdrop, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        TweenService:Create(panel, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        TweenService:Create(panelImage, TweenInfo.new(0.4), {ImageTransparency = 1}):Play()
        TweenService:Create(panelTint, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        task.wait(0.45)
        if blur.Parent then
            blur:Destroy()
        end
        if screen.Parent then
            screen:Destroy()
        end
        if afterClose then
            task.spawn(afterClose)
        end
    end

    local function closeKeySystem(afterClose)
        if destroyed then
            if afterClose then
                task.spawn(afterClose)
            end
            return
        end
        if options.OnClose then
            task.spawn(options.OnClose)
        end
        task.spawn(destroyVisuals, afterClose)
    end

    local function failKey()
        setStatus("Invalid key. Kicking...", Color3.fromRGB(230, 90, 100))
        task.spawn(shakePanel)
        TweenService:Create(blur, TweenInfo.new(0.5), {
            Size = blurSizeOnFail,
        }):Play()
        TweenService:Create(keyInputStroke, TweenInfo.new(0.3), {
            Color = Color3.fromRGB(220, 70, 80),
        }):Play()

        if onFailure then
            task.spawn(onFailure, keyInput.Text)
        end

        task.wait(kickDelay)
        if not destroyed then
            player:Kick(kickMessage)
        end
    end

    local function verify()
        if verifying or destroyed then
            return
        end

        local submittedKey = keyInput.Text
        if submittedKey == "" then
            setStatus("Enter a key first.", Color3.fromRGB(230, 170, 90))
            return false
        end

        verifying = true
        setStatus("Verifying...", Color3.fromRGB(190, 170, 220))
        task.wait(options.VerifyDelay or 0.6)

        local valid = validKeys[submittedKey] == true
        if not valid and type(options.ValidateKey) == "function" then
            local ok, result = pcall(options.ValidateKey, submittedKey)
            valid = ok and result == true
        end

        if valid then
            setStatus("Key accepted.", Color3.fromRGB(120, 220, 150))
            if onSuccess then
                task.spawn(onSuccess, submittedKey)
            end
            task.wait(options.SuccessDelay or 0.4)
            if autoDestroyOnValid then
                closeKeySystem(function()
                    if options.OnSuccessComplete then
                        task.spawn(options.OnSuccessComplete, submittedKey)
                    end
                end)
            elseif options.OnSuccessComplete then
                task.spawn(options.OnSuccessComplete, submittedKey)
            end
            verifying = false
            return true
        end

        verifying = false
        if options.KickOnInvalid ~= false then
            failKey()
        else
            setStatus("Invalid key.", Color3.fromRGB(230, 90, 100))
            if onFailure then
                task.spawn(onFailure, submittedKey)
            end
        end
        return false
    end

    verifyButton.MouseButton1Click:Connect(verify)

    getKeyButton.MouseButton1Click:Connect(function()
        if setclipboard then
            local ok = pcall(setclipboard, keyLink)
            if ok then
                setStatus("Link copied — check your clipboard.", Color3.fromRGB(190, 170, 220))
                return
            end
        end
        setStatus(keyLink, Color3.fromRGB(190, 170, 220))
    end)

    closeButton.MouseButton1Click:Connect(function()
        closeKeySystem()
        if kickOnClose then
            task.wait(0.05)
            player:Kick(options.CloseKickMessage or "You closed the key system.")
        end
    end)

    task.spawn(function()
        TweenService:Create(backdrop, TweenInfo.new(0.35), {
            BackgroundTransparency = 0.15,
        }):Play()
        TweenService:Create(panel, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
        }):Play()
    end)

    local api = {
        ScreenGui = screen,
        Panel = panel,
        Input = keyInput,
        StatusLabel = statusLabel,
        VerifyButton = verifyButton,
        GetKeyButton = getKeyButton,
        KeyLink = keyLink,
        ValidKeys = validKeys,
        Verify = verify,
        SetStatus = setStatus,
        Close = closeKeySystem,
        Destroy = closeKeySystem,
    }

    lastKeySystem = api
    Library.KeySystem = api
    return api
end

function Library:GetKeySystem()
    return lastKeySystem
end


----------------------------------------------------------------
-- LOADING SCREEN API
----------------------------------------------------------------
function Library:CreateLoadingScreen(options)
    options = options or {}
    local screen = Instance.new("ScreenGui")
    screen.Name = "MSILoadingScreen"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 1000
    screen.Parent = playerGui

    local background = Instance.new("Frame")
    background.Name = "Background"
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BorderSizePixel = 0
    background.Parent = screen

    local glow = Instance.new("Frame")
    glow.Name = "Glow"
    glow.Size = UDim2.fromScale(1, 1)
    glow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    glow.BackgroundTransparency = 1
    glow.BorderSizePixel = 0
    glow.Parent = background

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(45, 0, 80)),
    })
    gradient.Rotation = 90
    gradient.Parent = glow

    local pulseRunning = true
    task.spawn(function()
        local t = 0
        while pulseRunning and background.Parent do
            t += RunService.RenderStepped:Wait()
            local pulse = 0.55 + math.sin(t * 0.6) * 0.15
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(1.0, Color3.fromRGB(45 * pulse, 0, 80 * pulse)),
            })
        end
    end)

    local titleContainer = Instance.new("Frame")
    titleContainer.Name = "TitleContainer"
    titleContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    titleContainer.Position = UDim2.fromScale(0.5, 0.5)
    titleContainer.Size = UDim2.fromScale(0.95, 0.4)
    titleContainer.BackgroundTransparency = 1
    titleContainer.Parent = background

    local titleImage = Instance.new("ImageLabel")
    titleImage.Name = "TitleImage"
    titleImage.AnchorPoint = Vector2.new(0.5, 0.5)
    titleImage.Position = UDim2.fromScale(0.5, 0.5)
    titleImage.Size = UDim2.fromScale(1, 1)
    titleImage.BackgroundTransparency = 1
    titleImage.Image = "rbxassetid://122286881817734"
    titleImage.ImageTransparency = 1
    titleImage.ScaleType = Enum.ScaleType.Fit
    titleImage.Parent = titleContainer

    task.spawn(function()
        task.wait(0.25)

        -- subtle purple glow fades in first, then the dragon.
        TweenService:Create(
            glow,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0}
        ):Play()

        local fadeIn = TweenService:Create(
            titleImage,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {ImageTransparency = 0}
        )
        fadeIn:Play()
        fadeIn.Completed:Wait()

        task.wait(1.1)

        local fadeOutTime = 0.8
        pulseRunning = false

        TweenService:Create(
            titleImage,
            TweenInfo.new(fadeOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            {ImageTransparency = 1}
        ):Play()

        TweenService:Create(
            glow,
            TweenInfo.new(fadeOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ):Play()

        task.wait(fadeOutTime + 0.1)
        if screen.Parent then
            screen:Destroy()
        end
        if type(options.OnComplete) == "function" then
            task.spawn(options.OnComplete)
        end
    end)

    return screen
end

----------------------------------------------------------------
-- MAIN MENU VISIBILITY / BOOT SEQUENCE
----------------------------------------------------------------
function Library:Show()
    menuOpen = true
    window.Visible = true
    hideTooltip()

    TweenService:Create(
        window,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Size = UDim2.fromOffset(960, 600),
            BackgroundTransparency = 0,
        }
    ):Play()

    return self
end

function Library:Hide()
    menuOpen = false
    hideTooltip()

    TweenService:Create(
        window,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad),
        {
            Size = UDim2.fromOffset(960, 0),
            BackgroundTransparency = 1,
        }
    ):Play()

    task.delay(0.25, function()
        if not menuOpen and window.Parent then
            window.Visible = false
        end
    end)

    return self
end

function Library:Launch(options)
    options = options or {}

    self:Hide()

    local loadingOptions = options.LoadingScreen or {}
    local keyOptions = options.KeySystem or {}

    if loadingOptions.Enabled ~= false then
        loadingOptions = table.clone(loadingOptions)
        loadingOptions.OnComplete = function()
            local launchKeyOptions = table.clone(keyOptions)
            local userSuccess = launchKeyOptions.OnSuccess
            local userComplete = launchKeyOptions.OnSuccessComplete

            launchKeyOptions.AutoDestroyOnValid = true
            launchKeyOptions.OnSuccess = function(key)
                if userSuccess then
                    task.spawn(userSuccess, key)
                end
            end
            launchKeyOptions.OnSuccessComplete = function(key)
                if userComplete then
                    task.spawn(userComplete, key)
                end
                self:Show()
                if type(options.OnReady) == "function" then
                    task.spawn(options.OnReady, key)
                end
            end

            self:CreateKeySystem(launchKeyOptions)
        end

        self:CreateLoadingScreen(loadingOptions)
    else
        local launchKeyOptions = table.clone(keyOptions)
        local userComplete = launchKeyOptions.OnSuccessComplete
        launchKeyOptions.AutoDestroyOnValid = true
        launchKeyOptions.OnSuccessComplete = function(key)
            if userComplete then
                task.spawn(userComplete, key)
            end
            self:Show()
            if type(options.OnReady) == "function" then
                task.spawn(options.OnReady, key)
            end
        end
        self:CreateKeySystem(launchKeyOptions)
    end

    return self
end

----------------------------------------------------------------
-- PUBLIC COMPONENT HELPERS
----------------------------------------------------------------
Library.CreateToggle = function(section, label, default, options)
    return section:CreateToggle(label, default, options)
end

Library.CreateSlider = function(section, label, min, max, default, decimals, options)
    return section:CreateSlider(label, min, max, default, decimals, options)
end

Library.CreateDropdown = function(section, label, values, default, options)
    return section:CreateDropdown(label, values, default, options)
end

Library.CreateColorPicker = function(section, label, defaultColor, options)
    return section:CreateColorPicker(label, defaultColor, options)
end

Library.CreateKeybind = function(section, label, defaultKey, options)
    return section:CreateKeybind(label, defaultKey, options)
end

Library.CreateKeybindCombo = function(
    section,
    label,
    values,
    defaultValue,
    defaultKey,
    options
)
    return section:CreateKeybindCombo(
        label,
        values,
        defaultValue,
        defaultKey,
        options
    )
end

Library.CreateTextBox = function(
    section,
    label,
    placeholder,
    defaultText,
    options
)
    return section:CreateTextBox(
        label,
        placeholder,
        defaultText,
        options
    )
end

Library.CreateLabel = function(section, textValue, options)
    return section:CreateLabel(textValue, options)
end

Library.CreateButton = function(section, label, color, callback)
    return section:CreateButton(label, color, callback)
end

Library.CreateStatic = function(section, label, value, muted)
    return section:CreateStatic(label, value, muted)
end

----------------------------------------------------------------
-- INITIAL LOAD
----------------------------------------------------------------
if FileAPI.available then
    notify(
        "MSI Library",
        "Library ready",
        "success",
        3
    )
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------
Library.Window = Library
Library.GetWindow = function()
    return Library
end

Library.GetScreenGui = function()
    return screenGui
end

Library.GetKeybindList = function()
    return keybindListHost
end

Library.Start = function(options)
    return Library:Launch(options)
end

return Library
