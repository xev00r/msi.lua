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

-- Polyfill for older executors / non-Luau environments
if type(table.clone) ~= "function" then
    function table.clone(t)
        local out = {}
        for k, v in pairs(t) do
            out[k] = v
        end
        return out
    end
end

if type(table.clear) ~= "function" then
    function table.clear(t)
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

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

local function safeSpawn(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    return task.spawn(fn, ...)
end

-- Live clock (DateTime → os.date → tick fallback) so time/date always tick
local function clockParts()
    -- Prefer DateTime:ToLocalTime() numeric fields (FormatLocalTime is locale-flaky)
    local ok, parts = pcall(function()
        local t = DateTime.now():ToLocalTime()
        return {
            date = string.format("%02d.%02d.%04d", t.Day, t.Month, t.Year),
            time = string.format("%02d:%02d:%02d", t.Hour, t.Minute, t.Second),
            short = string.format("%02d:%02d", t.Hour, t.Minute),
            isoDate = string.format("%04d-%02d-%02d", t.Year, t.Month, t.Day),
        }
    end)
    if ok and parts then
        return parts
    end

    local ok2, parts2 = pcall(function()
        return {
            date = os.date("%d.%m.%Y"),
            time = os.date("%H:%M:%S"),
            short = os.date("%H:%M"),
            isoDate = os.date("%Y-%m-%d"),
        }
    end)
    if ok2 and parts2 then
        return parts2
    end

    local t = math.floor(tick() % 86400)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = t % 60
    return {
        date = "--.--.----",
        time = string.format("%02d:%02d:%02d", h, m, s),
        short = string.format("%02d:%02d", h, m),
        isoDate = "----.--.--",
    }
end

local function clockFull()
    local p = clockParts()
    return p.date .. " " .. p.short
end

local function clockFullSeconds()
    local p = clockParts()
    return p.date .. " " .. p.time
end

-- Serializable color / key helpers for config save-load
local function colorToTable(c)
    if typeof(c) ~= "Color3" then return c end
    return {
        __type = "Color3",
        R = math.floor(c.R * 255 + 0.5),
        G = math.floor(c.G * 255 + 0.5),
        B = math.floor(c.B * 255 + 0.5),
    }
end

local function tableToColor(v)
    if typeof(v) == "Color3" then return v end
    if type(v) == "table" then
        local r = v.R or v.r or v[1]
        local g = v.G or v.g or v[2]
        local b = v.B or v.b or v[3]
        if r and g and b then
            -- support both 0-1 and 0-255
            if r <= 1 and g <= 1 and b <= 1 then
                return Color3.new(r, g, b)
            end
            return Color3.fromRGB(
                math.clamp(math.floor(r + 0.5), 0, 255),
                math.clamp(math.floor(g + 0.5), 0, 255),
                math.clamp(math.floor(b + 0.5), 0, 255)
            )
        end
        if type(v.hex) == "string" then
            local h = v.hex:gsub("#", "")
            if #h == 6 then
                return Color3.fromRGB(
                    tonumber(h:sub(1, 2), 16),
                    tonumber(h:sub(3, 4), 16),
                    tonumber(h:sub(5, 6), 16)
                )
            end
        end
    elseif type(v) == "string" then
        local h = v:gsub("#", "")
        if #h == 6 then
            return Color3.fromRGB(
                tonumber(h:sub(1, 2), 16),
                tonumber(h:sub(3, 4), 16),
                tonumber(h:sub(5, 6), 16)
            )
        end
    end
    return nil
end

local function keyToString(k)
    if k == nil then return nil end
    if typeof(k) == "EnumItem" then
        return tostring(k):gsub("Enum.KeyCode.", "")
    end
    return tostring(k)
end

local function stringToKey(s)
    if s == nil or s == "" or s == "None" then return nil end
    if typeof(s) == "EnumItem" then return s end
    local ok, key = pcall(function()
        return Enum.KeyCode[tostring(s)]
    end)
    if ok and key then return key end
    return nil
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
        success = THEME.AccentLight,  -- purple family to match menu
        warning = THEME.Warning,
        error   = THEME.Error,
    })[ntype] or THEME.Accent

    -- Soft type tint for bar (still readable, still on-theme)
    local barColor = ({
        info    = THEME.Accent,
        success = Color3.fromRGB(140, 100, 255),
        warning = THEME.Warning,
        error   = THEME.Error,
    })[ntype] or THEME.Accent

    if not notifyHost then return end

    local hasBody = text and text ~= ""
    local h = hasBody and 62 or 44

    local toast = Instance.new("Frame")
    toast.Size = UDim2.fromOffset(290, h)
    toast.BackgroundColor3 = THEME.Card
    toast.BackgroundTransparency = 1
    toast.BorderSizePixel = 0
    toast.ClipsDescendants = true
    toast.ZIndex = 151
    toast.Parent = notifyHost
    corner(toast, 12)
    local toastStroke = stroke(toast, THEME.Accent, 1.2, 1)

    -- left accent bar (matches menu cards / rail)
    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, -14)
    accentBar.Position = UDim2.fromOffset(7, 7)
    accentBar.BackgroundColor3 = barColor
    accentBar.BackgroundTransparency = 1
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 152
    accentBar.Parent = toast
    corner(accentBar, 2)

    -- subtle top line like header separator
    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(1, 0, 0, 1)
    topLine.BackgroundColor3 = THEME.Accent
    topLine.BackgroundTransparency = 1
    topLine.BorderSizePixel = 0
    topLine.ZIndex = 152
    topLine.Parent = toast

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.fromOffset(18, hasBody and 11 or 13)
    titleLbl.Size = UDim2.new(1, -30, 0, 16)
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
        bodyLbl.Position = UDim2.fromOffset(18, 30)
        bodyLbl.Size = UDim2.new(1, -30, 0, 18)
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
    toast.Position = UDim2.new(0, 48, 0, 0)
    TweenService:Create(toast, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.12,
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()
    TweenService:Create(toastStroke, TweenInfo.new(0.3), {
        Transparency = 0.45,
        Color = THEME.Accent,
    }):Play()
    TweenService:Create(accentBar, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(topLine, TweenInfo.new(0.35), { BackgroundTransparency = 0.65 }):Play()
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
        TweenService:Create(topLine, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
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
            local value = comp.get()
            -- normalize Color3 / KeyCode / combo for JSON
            if typeof(value) == "Color3" then
                value = colorToTable(value)
            elseif typeof(value) == "EnumItem" then
                value = keyToString(value)
            elseif type(value) == "table" and (value.key ~= nil or value.value ~= nil) then
                value = {
                    value = value.value,
                    key = keyToString(value.key),
                }
            end
            data[id] = value
        end
    end
    return data
end

function ConfigManager.apply(data)
    if type(data) ~= "table" then return false end
    for id, value in pairs(data) do
        if id ~= "_meta" then
            local comp = ConfigManager.components[id]
            if comp and comp.set then
                pcall(function()
                    -- restore Color3 from an explicit Color3 table or numeric RGB fields
                    if type(value) == "table" then
                        local isColor = value.__type == "Color3"
                        if not isColor then
                            local rr = value.R or value.r
                            local gg = value.G or value.g
                            local bb = value.B or value.b
                            isColor = tonumber(rr) ~= nil and tonumber(gg) ~= nil and tonumber(bb) ~= nil
                        end

                        if isColor then
                            local c = tableToColor(value)
                            if c then
                                comp.set(c)
                                return
                            end
                        end
                    end
                    -- restore combo {value, key}
                    if type(value) == "table" and value.value ~= nil then
                        comp.set({
                            value = value.value,
                            key = stringToKey(value.key),
                        })
                        return
                    end
                    -- restore KeyCode from string
                    if type(value) == "string" and Enum.KeyCode[value] then
                        comp.set(stringToKey(value))
                        return
                    end
                    comp.set(value)
                end)
            end
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
-- Don't auto-fade in on create — Show()/Launch() handles the entrance tween

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
timeLabel.Text          = clockFullSeconds()
timeLabel.TextColor3    = THEME.TextMuted
timeLabel.Font          = Enum.Font.Gotham
timeLabel.TextSize      = 11
timeLabel.TextXAlignment = Enum.TextXAlignment.Right
timeLabel.ZIndex        = 2
timeLabel.Parent        = profileContainer

task.spawn(function()
    while screenGui and screenGui.Parent do
        timeLabel.Text = clockFullSeconds()
        task.wait(1)
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
bgImage.ImageTransparency = 0
bgImage.ZIndex = 2
bgImage.Visible = true
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
        t.Name = "CardTitle"
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
            safeSpawn(cb, state)
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
            safeSpawn(cb, v)
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

local function createNumberBoxRow(card, order, label, min, max, default, decimals, opts)
    opts = opts or {}
    local id = opts.id or nextId("numberbox")
    local step = tonumber(opts.step) or ((decimals and decimals > 0) and (10 ^ (-decimals)) or 1)

    local row = Instance.new("Frame")
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundTransparency = 1
    row.ZIndex = 3
    row.Parent = card

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -120, 0, 16)
    title.Text = label
    title.TextColor3 = THEME.TextPrimary
    title.Font = Enum.Font.Gotham
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 3
    title.Parent = row

    local box = Instance.new("TextBox")
    box.AnchorPoint = Vector2.new(1, 0)
    box.Position = UDim2.new(1, 0, 0, 0)
    box.Size = UDim2.fromOffset(76, 26)
    box.BackgroundColor3 = THEME.PanelAlt
    box.BackgroundTransparency = 0.05
    box.TextColor3 = THEME.TextPrimary
    box.PlaceholderColor3 = THEME.TextDim
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.ClearTextOnFocus = false
    box.ZIndex = 4
    box.Parent = row
    corner(box, 8)
    stroke(box, THEME.Accent, 1, 0.4)

    local minus = Instance.new("TextButton")
    minus.AnchorPoint = Vector2.new(1, 0)
    minus.Position = UDim2.new(1, -82, 0, 0)
    minus.Size = UDim2.fromOffset(26, 26)
    minus.BackgroundColor3 = THEME.PanelAlt
    minus.Text = "-"
    minus.TextColor3 = THEME.AccentLight
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 14
    minus.AutoButtonColor = false
    minus.ZIndex = 4
    minus.Parent = row
    corner(minus, 8)
    stroke(minus, THEME.Accent, 1, 0.5)

    local plus = Instance.new("TextButton")
    plus.AnchorPoint = Vector2.new(1, 0)
    plus.Position = UDim2.new(1, -114, 0, 0)
    plus.Size = UDim2.fromOffset(26, 26)
    plus.BackgroundColor3 = THEME.PanelAlt
    plus.Text = "+"
    plus.TextColor3 = THEME.AccentLight
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 14
    plus.AutoButtonColor = false
    plus.ZIndex = 4
    plus.Parent = row
    corner(plus, 8)
    stroke(plus, THEME.Accent, 1, 0.5)

    local value = math.clamp(tonumber(default) or min, min, max)
    local callbacks = {}

    local function format(v)
        if decimals and decimals > 0 then
            return string.format("%." .. decimals .. "f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    local function normalize(v)
        v = math.clamp(tonumber(v) or value, min, max)
        if decimals and decimals > 0 then
            local m = 10 ^ decimals
            v = math.floor(v * m + 0.5) / m
        else
            v = math.floor(v + 0.5)
        end
        return v
    end

    local function setInternal(v, fire)
        value = normalize(v)
        box.Text = format(value)
        if fire ~= false then
            for _, cb in ipairs(callbacks) do
                safeSpawn(cb, value)
            end
        end
    end

    setInternal(value, false)

    local function bump(delta)
        setInternal(value + delta, true)
    end

    minus.MouseButton1Click:Connect(function() bump(-step) end)
    plus.MouseButton1Click:Connect(function() bump(step) end)

    box.FocusLost:Connect(function()
        setInternal(box.Text, true)
    end)

    local comp = {
        id = id,
        row = row,
        get = function() return value end,
        set = function(v) setInternal(v, true) end,
        onChange = function(cb)
            if type(cb) == "function" then
                table.insert(callbacks, cb)
            end
            return comp
        end,
        destroy = function()
            ConfigManager.unregister(id)
            row:Destroy()
        end,
    }

    ConfigManager.register(id, comp)
    return comp
end

local dropdownRegistry = {}
local colorPickerRegistry = {}

local function closeAllDropdowns(except)
    for _, entry in ipairs(dropdownRegistry) do
        if entry ~= except and entry.optionsFrame.Visible then
            entry.close()
        end
    end
end

local function closeAllColorPickers(except)
    for _, entry in ipairs(colorPickerRegistry) do
        if entry ~= except and entry.isOpen and entry.isOpen() then
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
                safeSpawn(cb, option)
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

    local function rebuildOptions(newOptions, preferred)
        options = table.clone(newOptions or {})
        currentSelection = preferred

        for _, child in ipairs(optionsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        table.clear(checkLabels)
        openHeight = math.min(#options, 8) * 28 + 8

        for i, option in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.LayoutOrder = i
            optBtn.Size = UDim2.new(1, 0, 0, 28)
            optBtn.BackgroundTransparency = 1
            optBtn.Text = ""
            optBtn.ZIndex = 301
            optBtn.Parent = optionsFrame

            local optText = Instance.new("TextLabel")
            optText.Position = UDim2.fromOffset(10, 0)
            optText.Size = UDim2.new(1, -20, 1, 0)
            optText.BackgroundTransparency = 1
            optText.Text = tostring(option)
            optText.TextColor3 = THEME.TextPrimary
            optText.Font = Enum.Font.Gotham
            optText.TextSize = 13
            optText.TextXAlignment = Enum.TextXAlignment.Left
            optText.ZIndex = 302
            optText.Parent = optBtn

            local check = Instance.new("TextLabel")
            check.AnchorPoint = Vector2.new(1, 0.5)
            check.Position = UDim2.new(1, -10, 0.5, 0)
            check.Size = UDim2.fromOffset(14, 14)
            check.BackgroundTransparency = 1
            check.Text = option == currentSelection and "✓" or ""
            check.TextColor3 = THEME.Accent
            check.Font = Enum.Font.GothamBold
            check.TextSize = 12
            check.ZIndex = 302
            check.Parent = optBtn
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
                    safeSpawn(cb, option)
                end
            end)
        end

        if preferred and table.find(options, preferred) then
            selectedLabel.Text = tostring(preferred)
        elseif #options > 0 then
            currentSelection = options[1]
            selectedLabel.Text = tostring(options[1])
            if checkLabels[options[1]] then
                checkLabels[options[1]].Text = "✓"
            end
        else
            currentSelection = nil
            selectedLabel.Text = "None"
        end
    end

    local comp = {
        id = id,
        row = container,
        get = function() return currentSelection end,
        set = function(v)
            if not table.find(options, v) then return end
            for _, ck in pairs(checkLabels) do ck.Text = "" end
            if checkLabels[v] then checkLabels[v].Text = "✓" end
            selectedLabel.Text = tostring(v)
            currentSelection = v
            for _, cb in ipairs(callbacks) do
                safeSpawn(cb, v)
            end
        end,
        setOptions = function(newOptions, preferred)
            rebuildOptions(newOptions, preferred or currentSelection)
        end,
        onChange = function(cb)
            if type(cb) == "function" then
                table.insert(callbacks, cb)
            end
            return comp
        end,
        destroy = function()
            ConfigManager.unregister(id)
            container:Destroy()
        end,
    }
    ConfigManager.register(id, comp)
    return comp
end

local function createMultiDropdownRow(card, order, label, values, defaults, opts)
    opts = opts or {}
    local id = opts.id or nextId("multidropdown")
    values = table.clone(values or {})

    local container = Instance.new("Frame")
    container.LayoutOrder = order
    container.Size = UDim2.new(1, 0, 0, 56)
    container.BackgroundTransparency = 1
    container.ZIndex = 2
    container.Parent = card

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 14)
    title.Text = label
    title.TextColor3 = THEME.TextMuted
    title.Font = Enum.Font.Gotham
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 3
    title.Parent = container

    local button = Instance.new("TextButton")
    button.Position = UDim2.fromOffset(0, 20)
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = THEME.PanelAlt
    button.AutoButtonColor = false
    button.Text = ""
    button.ZIndex = 3
    button.Parent = container
    corner(button, 10)
    stroke(button, THEME.Accent, 1, 0.4)

    local selectedLabel = Instance.new("TextLabel")
    selectedLabel.Position = UDim2.fromOffset(10, 0)
    selectedLabel.Size = UDim2.new(1, -34, 1, 0)
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.TextColor3 = THEME.TextPrimary
    selectedLabel.Font = Enum.Font.Gotham
    selectedLabel.TextSize = 13
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.ZIndex = 3
    selectedLabel.Parent = button

    local chevron = Instance.new("ImageLabel")
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, -10, 0.5, 0)
    chevron.Size = UDim2.fromOffset(12, 12)
    chevron.ZIndex = 3
    chevron.Parent = button
    applyIcon(chevron, ICONS.ArrowRight, THEME.Accent)

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Position = UDim2.new(0, 0, 0, 57)
    optionsFrame.Size = UDim2.new(1, 0, 0, 0)
    optionsFrame.BackgroundColor3 = THEME.PanelAlt
    optionsFrame.BackgroundTransparency = 1
    optionsFrame.Visible = false
    optionsFrame.ClipsDescendants = true
    optionsFrame.ZIndex = 100
    optionsFrame.Parent = container
    corner(optionsFrame, 10)
    stroke(optionsFrame, THEME.Accent, 1, 0.4)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = optionsFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = optionsFrame

    local selected = {}
    for _, value in ipairs(defaults or {}) do
        selected[tostring(value)] = true
    end

    local callbacks = {}
    local originalContainerZ = container.ZIndex
    local originalCardZ = card.ZIndex

    local function selectedList()
        local out = {}
        for _, value in ipairs(values) do
            if selected[tostring(value)] then
                table.insert(out, value)
            end
        end
        return out
    end

    local function displayText()
        local list = selectedList()
        if #list == 0 then
            return "None"
        elseif #list <= 2 then
            return table.concat(list, ", ")
        else
            return tostring(#list) .. " selected"
        end
    end

    local function setLayer(open)
        if open then
            card.ZIndex = 200
            container.ZIndex = 250
            optionsFrame.ZIndex = 300
        else
            card.ZIndex = originalCardZ
            container.ZIndex = originalContainerZ
            optionsFrame.ZIndex = 100
        end
    end

    local function closeThis()
        setLayer(false)
        TweenService:Create(chevron, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Rotation = 0,
            ImageColor3 = THEME.Accent,
        }):Play()
        TweenService:Create(optionsFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.18, function()
            if optionsFrame.Parent then
                optionsFrame.Visible = false
            end
        end)
    end

    local function openThis()
        setLayer(true)
        optionsFrame.Visible = true
        local height = math.min(#values, 8) * 28 + 8
        optionsFrame.Size = UDim2.new(1, 0, 0, 0)
        TweenService:Create(chevron, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Rotation = 180,
            ImageColor3 = THEME.AccentLight,
        }):Play()
        TweenService:Create(optionsFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, height),
            BackgroundTransparency = 0,
        }):Play()
    end

    local function notifyChange()
        local snapshot = selectedList()
        selectedLabel.Text = displayText()
        for _, cb in ipairs(callbacks) do
            safeSpawn(cb, table.clone(snapshot))
        end
    end

    local function rebuildOptions(newValues, newSelected)
        values = table.clone(newValues or {})
        selected = {}
        for _, value in ipairs(newSelected or {}) do
            selected[tostring(value)] = true
        end

        for _, child in ipairs(optionsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for i, value in ipairs(values) do
            local key = tostring(value)
            local item = Instance.new("TextButton")
            item.LayoutOrder = i
            item.Size = UDim2.new(1, 0, 0, 28)
            item.BackgroundTransparency = 1
            item.Text = ""
            item.ZIndex = 301
            item.Parent = optionsFrame

            local text = Instance.new("TextLabel")
            text.Position = UDim2.fromOffset(10, 0)
            text.Size = UDim2.new(1, -36, 1, 0)
            text.BackgroundTransparency = 1
            text.Text = tostring(value)
            text.TextColor3 = THEME.TextPrimary
            text.Font = Enum.Font.Gotham
            text.TextSize = 13
            text.TextXAlignment = Enum.TextXAlignment.Left
            text.ZIndex = 302
            text.Parent = item

            local check = Instance.new("TextLabel")
            check.AnchorPoint = Vector2.new(1, 0.5)
            check.Position = UDim2.new(1, -10, 0.5, 0)
            check.Size = UDim2.fromOffset(16, 16)
            check.BackgroundTransparency = 1
            check.Text = selected[key] and "✓" or ""
            check.TextColor3 = THEME.AccentLight
            check.Font = Enum.Font.GothamBold
            check.TextSize = 13
            check.ZIndex = 302
            check.Parent = item

            item.MouseEnter:Connect(function()
                TweenService:Create(item, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                    BackgroundTransparency = 0.85,
                    BackgroundColor3 = THEME.Accent,
                }):Play()
            end)

            item.MouseLeave:Connect(function()
                TweenService:Create(item, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                    BackgroundTransparency = 1,
                }):Play()
            end)

            item.MouseButton1Click:Connect(function()
                selected[key] = not selected[key]
                check.Text = selected[key] and "✓" or ""
                notifyChange()
            end)
        end

        selectedLabel.Text = displayText()
    end

    rebuildOptions(values, defaults or {})

    button.MouseButton1Click:Connect(function()
        local opening = not optionsFrame.Visible
        closeAllDropdowns(opening and {optionsFrame = optionsFrame, close = closeThis} or nil)
        if opening then openThis() else closeThis() end
    end)

    local entry = {optionsFrame = optionsFrame, close = closeThis}
    table.insert(dropdownRegistry, entry)

    local comp = {
        id = id,
        row = container,
        get = function() return selectedList() end,
        set = function(list)
            if type(list) ~= "table" then return end
            rebuildOptions(values, list)
            notifyChange()
        end,
        setOptions = function(newValues, newSelected)
            rebuildOptions(newValues, newSelected or selectedList())
        end,
        onChange = function(cb)
            if type(cb) == "function" then
                table.insert(callbacks, cb)
            end
            return comp
        end,
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
        if onClick then safeSpawn(onClick) end
    end)

    return btn
end

local keybindRegistry = {}
local keybindListEnabled = false
local setKeybindListVisible
local keybindListening = false
local toggleKey = Enum.KeyCode.Insert
local menuKeyComponent = nil

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
        keybindListening = true
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
                keybindListening = false
                conn:Disconnect()
                for _, cb in ipairs(callbacks) do safeSpawn(cb, currentKey) end
            elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
                if options.noClear then
                    listening = false
                    keybindListening = false
                    conn:Disconnect()
                    return
                end
                currentKey = nil
                btn.Text = "None"
                btn.TextColor3 = THEME.TextMuted
                listening = false
                keybindListening = false
                conn:Disconnect()
                for _, cb in ipairs(callbacks) do safeSpawn(cb, nil) end
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
            for _, cb in ipairs(callbacks) do safeSpawn(cb, currentKey) end
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

local function createMenuKeybindRow(card, order, label, defaultKey, options)
    options = options or {}
    options.noClear = true
    local initialKey = defaultKey or toggleKey
    local comp = createKeybindRow(card, order, label or "Menu key", initialKey, options)

    menuKeyComponent = comp
    toggleKey = initialKey

    comp:onChange(function(newKey)
        if newKey then
            toggleKey = newKey
        end
    end)

    return comp
end

local function createLabelRow(card, order, textValue, options)
    options = options or {}
    local wrap = options.wrap ~= false  -- descriptions wrap by default
    local size = options.size or 12
    local height = options.height
    if not height then
        -- rough auto height for wrapped text
        local len = #(textValue or "")
        if wrap and len > 48 then
            height = math.clamp(18 + math.floor(len / 42) * 14, 22, 72)
        else
            height = 22
        end
    end

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.LayoutOrder = order
    label.Size = UDim2.new(1, 0, 0, height)
    label.BackgroundTransparency = 1
    label.Text = textValue or ""
    label.TextColor3 = options.color or THEME.TextPrimary
    label.Font = options.bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextSize = size
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = options.strokeTransparency or 0.72
    label.TextXAlignment = options.align or Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextWrapped = wrap
    label.RichText = options.rich == true
    label.ZIndex = 3
    label.Parent = card

    return {
        row = label,
        set = function(v)
            label.Text = tostring(v or "")
        end,
        get = function()
            return label.Text
        end,
        destroy = function()
            label:Destroy()
        end,
    }
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
        for _, cb in ipairs(callbacks) do safeSpawn(cb, v) end
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
        set = function(v)
            currentText = tostring(v or "")
            box.Text = currentText
            for _, cb in ipairs(callbacks) do safeSpawn(cb, currentText) end
        end,
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
            for _, cb in ipairs(callbacks) do safeSpawn(cb, currentValue, currentKey) end
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
                for _, cb in ipairs(callbacks) do safeSpawn(cb, currentValue, currentKey) end
            elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
                currentKey = nil
                keyButton.Text = "None"
                keyButton.TextColor3 = THEME.TextMuted
                listening = false
                conn:Disconnect()
                for _, cb in ipairs(callbacks) do safeSpawn(cb, currentValue, currentKey) end
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
            for _, cb in ipairs(callbacks) do safeSpawn(cb, currentValue, currentKey) end
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

    local h, s, v = defaultColor:ToHSV()
    local currentColor = defaultColor
    local callbacks = {}
    local originalCardZ = card.ZIndex
    local originalRowZ = row.ZIndex
    local popupOpen = false
    local wheelDragging = false
    local valDragging = false

    -- Popup (Dollarware-style wheel, MSI theme)
    local popup = Instance.new("Frame")
    popup.Name = "ColorPopup"
    popup.AnchorPoint = Vector2.new(1, 0)
    popup.Size = UDim2.fromOffset(236, 268)
    popup.BackgroundColor3 = THEME.PanelAlt
    popup.Visible = false
    popup.ZIndex = 500
    popup.ClipsDescendants = true
    popup.Parent = screenGui
    corner(popup, 12)
    stroke(popup, THEME.Accent, 1.2, 0.3)

    local popupTitle = Instance.new("TextLabel")
    popupTitle.BackgroundTransparency = 1
    popupTitle.Position = UDim2.fromOffset(12, 8)
    popupTitle.Size = UDim2.new(1, -24, 0, 18)
    popupTitle.Text = label
    popupTitle.TextColor3 = THEME.TextPrimary
    popupTitle.Font = Enum.Font.GothamBold
    popupTitle.TextSize = 12
    popupTitle.TextXAlignment = Enum.TextXAlignment.Left
    popupTitle.ZIndex = 501
    popupTitle.Parent = popup

    local titleLine = Instance.new("Frame")
    titleLine.Position = UDim2.fromOffset(0, 30)
    titleLine.Size = UDim2.new(1, 0, 0, 1)
    titleLine.BackgroundColor3 = THEME.Accent
    titleLine.BackgroundTransparency = 0.55
    titleLine.BorderSizePixel = 0
    titleLine.ZIndex = 501
    titleLine.Parent = popup

    -- Circular HSV wheel (Dollarware asset)
    local wheelFrame = Instance.new("Frame")
    wheelFrame.Position = UDim2.fromOffset(14, 42)
    wheelFrame.Size = UDim2.fromOffset(160, 160)
    wheelFrame.BackgroundTransparency = 1
    wheelFrame.ZIndex = 501
    wheelFrame.Parent = popup

    local wheel = Instance.new("ImageLabel")
    wheel.Name = "Wheel"
    wheel.Size = UDim2.fromScale(1, 1)
    wheel.BackgroundTransparency = 1
    wheel.Image = "rbxassetid://9801454501"
    wheel.ScaleType = Enum.ScaleType.Fit
    wheel.ZIndex = 501
    wheel.Parent = wheelFrame

    local cursor = Instance.new("Frame")
    cursor.Name = "Cursor"
    cursor.AnchorPoint = Vector2.new(0.5, 0.5)
    cursor.Size = UDim2.fromOffset(12, 12)
    cursor.BackgroundColor3 = THEME.White
    cursor.BorderSizePixel = 0
    cursor.ZIndex = 503
    cursor.Parent = wheelFrame
    corner(cursor, 6)
    stroke(cursor, Color3.fromRGB(0, 0, 0), 1.5, 0.2)

    local cursorInner = Instance.new("Frame")
    cursorInner.AnchorPoint = Vector2.new(0.5, 0.5)
    cursorInner.Position = UDim2.fromScale(0.5, 0.5)
    cursorInner.Size = UDim2.fromOffset(6, 6)
    cursorInner.BackgroundColor3 = defaultColor
    cursorInner.BorderSizePixel = 0
    cursorInner.ZIndex = 504
    cursorInner.Parent = cursor
    corner(cursorInner, 3)

    -- Value (brightness) slider on the right
    local valTrack = Instance.new("Frame")
    valTrack.Position = UDim2.fromOffset(188, 42)
    valTrack.Size = UDim2.fromOffset(16, 160)
    valTrack.BackgroundColor3 = THEME.Panel
    valTrack.BorderSizePixel = 0
    valTrack.ZIndex = 501
    valTrack.Parent = popup
    corner(valTrack, 6)
    stroke(valTrack, THEME.Accent, 1, 0.45)

    local valGradient = Instance.new("UIGradient")
    valGradient.Rotation = 90
    valGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(h, s, 1)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
    })
    valGradient.Parent = valTrack

    local valKnob = Instance.new("Frame")
    valKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    valKnob.Size = UDim2.fromOffset(18, 8)
    valKnob.BackgroundColor3 = THEME.White
    valKnob.BorderSizePixel = 0
    valKnob.ZIndex = 503
    valKnob.Parent = valTrack
    corner(valKnob, 3)
    stroke(valKnob, THEME.Accent, 1, 0.2)

    -- RGB readouts
    local infoRow = Instance.new("Frame")
    infoRow.Position = UDim2.fromOffset(12, 214)
    infoRow.Size = UDim2.new(1, -24, 0, 20)
    infoRow.BackgroundTransparency = 1
    infoRow.ZIndex = 501
    infoRow.Parent = popup

    local rgbLabel = Instance.new("TextLabel")
    rgbLabel.BackgroundTransparency = 1
    rgbLabel.Size = UDim2.new(0.55, 0, 1, 0)
    rgbLabel.Text = string.format("RGB %d, %d, %d",
        math.floor(defaultColor.R * 255 + 0.5),
        math.floor(defaultColor.G * 255 + 0.5),
        math.floor(defaultColor.B * 255 + 0.5))
    rgbLabel.TextColor3 = THEME.TextMuted
    rgbLabel.Font = Enum.Font.Gotham
    rgbLabel.TextSize = 11
    rgbLabel.TextXAlignment = Enum.TextXAlignment.Left
    rgbLabel.ZIndex = 501
    rgbLabel.Parent = infoRow

    local hexBox = Instance.new("TextLabel")
    hexBox.BackgroundTransparency = 1
    hexBox.Position = UDim2.fromScale(0.55, 0)
    hexBox.Size = UDim2.new(0.45, 0, 1, 0)
    hexBox.Text = toHex(defaultColor)
    hexBox.TextColor3 = THEME.AccentLight
    hexBox.Font = Enum.Font.GothamBold
    hexBox.TextSize = 12
    hexBox.TextXAlignment = Enum.TextXAlignment.Right
    hexBox.ZIndex = 501
    hexBox.Parent = infoRow

    -- Presets row
    local presets = {
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(255, 180, 60),
        Color3.fromRGB(255, 240, 80),
        Color3.fromRGB(80, 220, 120),
        Color3.fromRGB(80, 180, 255),
        Color3.fromRGB(160, 100, 255),
        Color3.fromRGB(255, 100, 200),
        Color3.fromRGB(240, 240, 240),
    }

    local palette = Instance.new("Frame")
    palette.BackgroundTransparency = 1
    palette.Position = UDim2.fromOffset(12, 238)
    palette.Size = UDim2.new(1, -24, 0, 22)
    palette.ZIndex = 501
    palette.Parent = popup

    local pLayout = Instance.new("UIListLayout")
    pLayout.FillDirection = Enum.FillDirection.Horizontal
    pLayout.Padding = UDim.new(0, 5)
    pLayout.Parent = palette

    local function applyVisuals(notify)
        currentColor = Color3.fromHSV(h, s, v)
        preview.BackgroundColor3 = currentColor
        cursorInner.BackgroundColor3 = currentColor
        hexLabel.Text = toHex(currentColor)
        hexBox.Text = toHex(currentColor)
        rgbLabel.Text = string.format("RGB %d, %d, %d",
            math.floor(currentColor.R * 255 + 0.5),
            math.floor(currentColor.G * 255 + 0.5),
            math.floor(currentColor.B * 255 + 0.5))
        valGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(h, s, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        })
        -- wheel cursor (polar like Dollarware)
        local theta = (h * math.pi * 2)
        local radius = 0.5 * s
        local cx = 0.5 + math.cos(theta) * radius
        local cy = 0.5 + math.sin(theta) * radius
        cursor.Position = UDim2.fromScale(cx, cy)
        valKnob.Position = UDim2.new(0.5, 0, 1 - v, 0)

        if notify then
            for _, cb in ipairs(callbacks) do
                safeSpawn(cb, currentColor)
            end
        end
    end

    local function setColor(c, notify)
        if typeof(c) == "table" and c.__type == "Color3" then
            c = Color3.fromRGB(c.R or 0, c.G or 0, c.B or 0)
        end
        if typeof(c) ~= "Color3" then return end
        h, s, v = c:ToHSV()
        applyVisuals(notify ~= false)
    end

    local function setFromWheel(pos)
        local abs = wheelFrame.AbsolutePosition
        local size = wheelFrame.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        local rx = (pos.X - abs.X) / size.X - 0.5
        local ry = (pos.Y - abs.Y) / size.Y - 0.5
        local dist = math.sqrt(rx * rx + ry * ry)
        s = math.clamp(dist * 2, 0, 1)
        h = (math.atan2(ry, rx) / (math.pi * 2)) % 1
        applyVisuals(true)
    end

    local function setFromValue(pos)
        local abs = valTrack.AbsolutePosition
        local size = valTrack.AbsoluteSize
        if size.Y <= 0 then return end
        local t = math.clamp((pos.Y - abs.Y) / size.Y, 0, 1)
        v = 1 - t
        applyVisuals(true)
    end

    local wheelHit = Instance.new("TextButton")
    wheelHit.Size = UDim2.fromScale(1, 1)
    wheelHit.BackgroundTransparency = 1
    wheelHit.Text = ""
    wheelHit.ZIndex = 502
    wheelHit.Parent = wheelFrame
    wheelHit.MouseButton1Down:Connect(function()
        wheelDragging = true
        setFromWheel(UserInputService:GetMouseLocation())
    end)

    local valHit = Instance.new("TextButton")
    valHit.Size = UDim2.fromScale(1, 1)
    valHit.BackgroundTransparency = 1
    valHit.Text = ""
    valHit.ZIndex = 502
    valHit.Parent = valTrack
    valHit.MouseButton1Down:Connect(function()
        valDragging = true
        setFromValue(UserInputService:GetMouseLocation())
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
            if wheelDragging then
                setFromWheel(inp.Position)
            elseif valDragging then
                setFromValue(inp.Position)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            wheelDragging = false
            valDragging = false
        end
    end)

    for _, c in ipairs(presets) do
        local swatch = Instance.new("TextButton")
        swatch.Size = UDim2.fromOffset(22, 22)
        swatch.BackgroundColor3 = c
        swatch.AutoButtonColor = false
        swatch.Text = ""
        swatch.ZIndex = 502
        swatch.Parent = palette
        corner(swatch, 6)
        stroke(swatch, THEME.Accent, 1, 0.55)
        swatch.MouseButton1Click:Connect(function()
            setColor(c, true)
        end)
    end

    local function positionPopup()
        local abs = preview.AbsolutePosition
        local size = preview.AbsoluteSize
        local host = screenGui.AbsolutePosition
        local px = abs.X + size.X - host.X
        local py = abs.Y + size.Y + 6 - host.Y
        local guiSize = screenGui.AbsoluteSize
        if px < 236 then px = abs.X - host.X + 236 end
        if py + 268 > guiSize.Y then
            py = abs.Y - host.Y - 268 - 6
        end
        popup.Position = UDim2.fromOffset(px, py)
    end

    local function closePopup()
        if not popupOpen then return end
        popupOpen = false
        popup.Visible = false
        card.ZIndex = originalCardZ
        row.ZIndex = originalRowZ
        wheelDragging = false
        valDragging = false
    end

    local function openPopup()
        closeAllDropdowns()
        closeAllColorPickers()
        popupOpen = true
        positionPopup()
        popup.Visible = true
        card.ZIndex = 200
        row.ZIndex = 250
        applyVisuals(false)
    end

    local entry = {
        close = closePopup,
        isOpen = function() return popupOpen end,
        popup = popup,
        preview = preview,
    }
    table.insert(colorPickerRegistry, entry)

    preview.MouseButton1Click:Connect(function()
        if popupOpen then
            closePopup()
        else
            openPopup()
        end
    end)

    -- Outside click closes
    UserInputService.InputBegan:Connect(function(inp)
        if not popupOpen then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
            and inp.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local pos = inp.Position
        local function inside(gui)
            if not gui or not gui.Visible then return false end
            local a = gui.AbsolutePosition
            local s = gui.AbsoluteSize
            return pos.X >= a.X and pos.X <= a.X + s.X
                and pos.Y >= a.Y and pos.Y <= a.Y + s.Y
        end
        if not inside(popup) and not inside(preview) then
            closePopup()
        end
    end)

    applyVisuals(false)

    local api = {
        id = id,
        type = "color",
        row = row,
        get = function() return currentColor end,
        set = function(c) setColor(c, true) end,
        onChange = function(cb)
            if type(cb) == "function" then
                table.insert(callbacks, cb)
            end
        end,
        destroy = function()
            closePopup()
            ConfigManager.unregister(id)
            popup:Destroy()
            row:Destroy()
        end,
    }
    ConfigManager.register(id, api)
    return api
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

local function sectionSearchText(section)
    local parts = {section.name or ""}

    if section._description and section._description.row then
        for _, child in ipairs(section._description.row:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                if child.Text and child.Text ~= "" then
                    table.insert(parts, child.Text)
                end
            end
        end
    end

    for _, comp in ipairs(section._components or {}) do
        if comp and comp.row and comp.row.Parent then
            for _, child in ipairs(comp.row:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                    local text = child.Text
                    if text and text ~= "" then
                        table.insert(parts, text)
                    end
                    if child:IsA("TextBox") and child.PlaceholderText then
                        table.insert(parts, child.PlaceholderText)
                    end
                end
            end
        end
    end

    return table.concat(parts, " "):lower()
end

local function searchPass(node, query)
    if query == "" then
        return true
    end

    local haystack = (node.label or "") .. " " .. (node.searchText or "")
    if haystack:lower():find(query, 1, true) then
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

    -- no bullet markers — tighter text indent
    local textOffX = depth * INDENT + (hasKids and 28 or 12)
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
            searchText = sectionSearchText(section),
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

function Library:SetMenuKeybind(key)
    if key == nil then
        return toggleKey
    end

    toggleKey = key

    if menuKeyComponent and menuKeyComponent.set then
        menuKeyComponent.set(key)
    end

    return toggleKey
end

function Library:GetMenuKeybind()
    return toggleKey
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

    -- Optional card description under the title
    local descText = options.description or options.desc
    if type(descText) == "string" and descText ~= "" then
        local desc = createLabelRow(card, 1, descText, {
            color = THEME.TextDim,
            size = 11,
            wrap = true,
        })
        section._description = desc
        section._counter = 1
    end

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

    function section:CreateMultiDropdown(label, values, defaults, opts)
        local comp = createMultiDropdownRow(
            self._card,
            self:_nextOrder(),
            label,
            values,
            defaults,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateNumberBox(label, min, max, default, decimals, opts)
        local comp = createNumberBoxRow(
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

    function section:CreateMenuKeybind(label, defaultKey, opts)
        local comp = createMenuKeybindRow(
            self._card,
            self:_nextOrder(),
            label or "Menu key",
            defaultKey,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    function section:CreateKeybindListToggle(label, default, opts)
        local comp = createToggleRow(
            self._card,
            self:_nextOrder(),
            label or "Show keybind list",
            default == true,
            opts
        )

        comp:onChange(function(value)
            if setKeybindListVisible then
                setKeybindListVisible(value)
            end
        end)

        if setKeybindListVisible then
            setKeybindListVisible(default == true)
        end

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
        opts = opts or {}
        local comp = createLabelRow(
            self._card,
            self:_nextOrder(),
            textValue,
            opts
        )
        table.insert(self._components, comp)
        return comp
    end

    -- Descriptive text for a card (muted, wraps)
    function section:CreateDescription(textValue, opts)
        opts = opts or {}
        if opts.color == nil then opts.color = THEME.TextDim end
        if opts.size == nil then opts.size = 11 end
        if opts.wrap == nil then opts.wrap = true end
        return self:CreateLabel(textValue, opts)
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

    function tab:CreateMultiDropdown(label, values, defaults, opts)
        return ensureDefaultSection(self):CreateMultiDropdown(
            label,
            values,
            defaults,
            opts
        )
    end

    function tab:CreateNumberBox(label, min, max, default, decimals, opts)
        return ensureDefaultSection(self):CreateNumberBox(
            label,
            min,
            max,
            default,
            decimals,
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

    function tab:CreateMenuKeybind(label, defaultKey, opts)
        return ensureDefaultSection(self):CreateMenuKeybind(
            label or "Menu key",
            defaultKey,
            opts
        )
    end

    function tab:CreateKeybindListToggle(label, default, opts)
        return ensureDefaultSection(self):CreateKeybindListToggle(
            label or "Show keybind list",
            default,
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

    function tab:CreateDescription(textValue, opts)
        return ensureDefaultSection(self):CreateDescription(textValue, opts)
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

        if not self._buildingSettings and name ~= "Settings" then
            task.defer(function()
                self:_relocateSettingsTab()
            end)
        end

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
local menuOpen = false

toggleMenu = function()
    menuOpen = not menuOpen
    hideTooltip()

    if menuOpen then
        window.Visible = true
        if watermark then
            watermark.Visible = true
        end

        TweenService:Create(
            window,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                Size = UDim2.fromOffset(960, 600),
                BackgroundTransparency = 0,
            }
        ):Play()
    else
        if watermark then
            watermark.Visible = false
        end

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

        -- Close color pickers only when click is outside popup + preview
        local pos = inp.Position
        local function hit(gui)
            if not gui then return false end
            local ap = gui.AbsolutePosition
            local as = gui.AbsoluteSize
            return pos.X >= ap.X and pos.X <= ap.X + as.X
                and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
        end
        for _, entry in ipairs(colorPickerRegistry) do
            if entry.isOpen and entry.isOpen() then
                if not hit(entry.popup) and not hit(entry.preview) then
                    entry.close()
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- KEYBINDS
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then
        return
    end

    if keybindListening then
        return
    end

    if UserInputService:GetFocusedTextBox() then
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
watermark.Visible = false
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
wmText.Font = Enum.Font.GothamMedium
wmText.TextSize = 12
wmText.TextXAlignment = Enum.TextXAlignment.Left
wmText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
wmText.TextStrokeTransparency = 0.7
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
                clockParts().time,
                exec
            )

            task.wait(1)
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
-- keybindListEnabled already declared earlier (shared state)

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

    keybindListHost.Visible = keybindListEnabled and #entries > 0

    if not keybindListHost.Visible then
        return
    end

    for i, item in ipairs(entries) do
        local row = Instance.new("Frame")
        row.LayoutOrder = i
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.ZIndex = 131
        row.Parent = keybindListHost

        local name = Instance.new("TextLabel")
        name.BackgroundTransparency = 1
        name.Size = UDim2.new(1, -98, 1, 0)
        name.Text = item.label
        name.TextColor3 = THEME.TextPrimary
        name.Font = Enum.Font.GothamMedium
        name.TextSize = 12
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextYAlignment = Enum.TextYAlignment.Center
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        name.TextStrokeTransparency = 0.7
        name.ZIndex = 132
        name.Parent = row

        local mode = Instance.new("TextLabel")
        mode.AnchorPoint = Vector2.new(1, 0.5)
        mode.Position = UDim2.new(1, -52, 0.5, 0)
        mode.Size = UDim2.fromOffset(44, 17)
        mode.BackgroundTransparency = 1
        mode.Text = item.mode
        mode.TextColor3 = THEME.TextMuted
        mode.Font = Enum.Font.Gotham
        mode.TextSize = 10
        mode.TextXAlignment = Enum.TextXAlignment.Right
        mode.TextYAlignment = Enum.TextYAlignment.Center
        mode.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        mode.TextStrokeTransparency = 0.7
        mode.ZIndex = 132
        mode.Parent = row

        local key = Instance.new("TextLabel")
        key.AnchorPoint = Vector2.new(1, 0.5)
        key.Position = UDim2.new(1, 0, 0.5, 0)
        key.Size = UDim2.fromOffset(46, 22)
        key.BackgroundColor3 = Color3.fromRGB(8, 5, 15)
        key.BackgroundTransparency = 0.05
        key.Text = keyName(item.key)
        key.TextColor3 = THEME.AccentLight
        key.Font = Enum.Font.GothamBold
        key.TextSize = 10
        key.TextXAlignment = Enum.TextXAlignment.Center
        key.TextYAlignment = Enum.TextYAlignment.Center
        key.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        key.TextStrokeTransparency = 0.65
        key.ZIndex = 133
        key.Parent = row
        corner(key, 7)
        stroke(key, THEME.Accent, 1, 0.28)
    end
end

keybindListHost = Instance.new("Frame")
keybindListHost.Name = "KeybindList"
keybindListHost.AnchorPoint = Vector2.new(1, 0)
keybindListHost.Position = UDim2.new(1, -12, 0, 48)
keybindListHost.Size = UDim2.fromOffset(236, 0)
keybindListHost.AutomaticSize = Enum.AutomaticSize.Y
keybindListHost.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
keybindListHost.BackgroundTransparency = 0.06
keybindListHost.Visible = false
keybindListHost.ZIndex = 130
keybindListHost.Parent = screenGui
corner(keybindListHost, 9)
stroke(keybindListHost, THEME.Accent, 1, 0.42)

local kbPad = Instance.new("UIPadding")
kbPad.PaddingTop = UDim.new(0, 7)
kbPad.PaddingBottom = UDim.new(0, 8)
kbPad.PaddingLeft = UDim.new(0, 9)
kbPad.PaddingRight = UDim.new(0, 9)
kbPad.Parent = keybindListHost

local kbLayout = Instance.new("UIListLayout")
kbLayout.SortOrder = Enum.SortOrder.LayoutOrder
kbLayout.Padding = UDim.new(0, 2)
kbLayout.Parent = keybindListHost

local kbTitle = Instance.new("Frame")
kbTitle.Name = "Title"
kbTitle.LayoutOrder = 0
kbTitle.Size = UDim2.new(1, 0, 0, 26)
kbTitle.BackgroundTransparency = 1
kbTitle.ZIndex = 131
kbTitle.Parent = keybindListHost

local kbDragon = Instance.new("ImageLabel")
kbDragon.Size = UDim2.fromOffset(20, 20)
kbDragon.Position = UDim2.fromOffset(0, 3)
kbDragon.BackgroundTransparency = 1
kbDragon.Image = "rbxassetid://78464903954782"
kbDragon.ScaleType = Enum.ScaleType.Fit
kbDragon.ZIndex = 132
kbDragon.Parent = kbTitle

local kbDivider = Instance.new("Frame")
kbDivider.Size = UDim2.fromOffset(1, 15)
kbDivider.Position = UDim2.fromOffset(26, 6)
kbDivider.BackgroundColor3 = THEME.Accent
kbDivider.BackgroundTransparency = 0.2
kbDivider.BorderSizePixel = 0
kbDivider.ZIndex = 132
kbDivider.Parent = kbTitle

local kbTitleLabel = Instance.new("TextLabel")
kbTitleLabel.Position = UDim2.fromOffset(34, 0)
kbTitleLabel.Size = UDim2.new(1, -34, 1, 0)
kbTitleLabel.BackgroundTransparency = 1
kbTitleLabel.Text = "KEYBINDS"
kbTitleLabel.TextColor3 = THEME.TextPrimary
kbTitleLabel.Font = Enum.Font.GothamBold
kbTitleLabel.TextSize = 12
kbTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
kbTitleLabel.TextYAlignment = Enum.TextYAlignment.Center
kbTitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
kbTitleLabel.TextStrokeTransparency = 0.65
kbTitleLabel.ZIndex = 132
kbTitleLabel.Parent = kbTitle

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
Library._motdRecent = Library._motdRecent or {}

function Library:CreateKeySystem(options)
    options = options or {}

    if lastKeySystem and lastKeySystem.Destroy then
        pcall(lastKeySystem.Destroy)
    end

    local validKeys = options.ValidKeys or options.Keys or {
        ["PASTE-YOUR-KEY-HERE"] = true,
    }

    local keyLink = options.KeyLink or "https://your-key-link-here.com"
    local backgroundImage = options.BackgroundImage or "rbxassetid://90077486395276"
    local kickMessage = options.KickMessage or "Invalid key. Please get a new key and try again."
    local blurSizeOnFail = options.BlurSizeOnFail or 28
    local kickDelay = options.KickDelay or 1.5
    local kickOnClose = options.KickOnClose ~= false
    local autoDestroyOnValid = options.AutoDestroyOnValid ~= false
    local maxAttempts = math.max(1, tonumber(options.MaxAttempts) or 3)
    local onSuccess = options.OnSuccess
    local onFailure = options.OnFailure

    local attemptsLeft = maxAttempts

    local blur = Instance.new("BlurEffect")
    blur.Name = "KeySystemBlur"
    blur.Size = 0
    blur.Parent = Lighting

    local screen = Instance.new("ScreenGui")
    screen.Name = options.Name or "MSIKeySystem"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = options.DisplayOrder or 1100
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Parent = playerGui

    -- Full-screen dim + purple wash (same family as menu gradient)
    local backdrop = Instance.new("Frame")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 1
    backdrop.BorderSizePixel = 0
    backdrop.Parent = screen

    local gradientOverlay = Instance.new("Frame")
    gradientOverlay.Name = "GradientOverlay"
    gradientOverlay.Size = UDim2.fromScale(1, 1)
    gradientOverlay.BackgroundColor3 = THEME.Background
    gradientOverlay.BackgroundTransparency = 1
    gradientOverlay.BorderSizePixel = 0
    gradientOverlay.ZIndex = 2
    gradientOverlay.Parent = backdrop

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(8, 5, 15)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 8, 30)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(45, 10, 80)),
    })
    gradient.Rotation = 90
    gradient.Parent = gradientOverlay

    -- Main panel — matches menu window
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(580, 300)
    panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.ZIndex = 5
    panel.Parent = backdrop
    corner(panel, WINDOW_RADIUS or 14)
    local panelStroke = stroke(panel, THEME.Accent, 1.5, 1)
    local panelImage = nil

    -- Clip layer so background art respects rounded corners
    local artClip = Instance.new("Frame")
    artClip.Name = "ArtClip"
    artClip.Size = UDim2.fromScale(1, 1)
    artClip.BackgroundTransparency = 1
    artClip.ClipsDescendants = true
    artClip.BorderSizePixel = 0
    artClip.ZIndex = 3
    artClip.Parent = panel
    corner(artClip, WINDOW_RADIUS or 14)

    -- MSI.LUA mark behind profile + key form
    local dragonImage = Instance.new("ImageLabel")
    dragonImage.Name = "BackgroundLogo"
    dragonImage.AnchorPoint = Vector2.new(0.5, 0.5)
    dragonImage.Position = UDim2.fromScale(0.5, 0.58)
    dragonImage.Size = UDim2.fromOffset(420, 140)
    dragonImage.BackgroundTransparency = 1
    dragonImage.Image = "rbxassetid://90077486395276"
    dragonImage.ImageTransparency = 1
    dragonImage.ScaleType = Enum.ScaleType.Fit
    dragonImage.ZIndex = 3
    dragonImage.Parent = artClip

    local panelTint = Instance.new("Frame")
    panelTint.Name = "PanelTint"
    panelTint.Size = UDim2.fromScale(1, 1)
    panelTint.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    panelTint.BackgroundTransparency = 1
    panelTint.BorderSizePixel = 0
    panelTint.ZIndex = 4
    panelTint.Parent = panel
    corner(panelTint, WINDOW_RADIUS or 14)

    -- Header strip
    local headerBar = Instance.new("Frame")
    headerBar.Name = "Header"
    headerBar.Size = UDim2.new(1, 0, 0, 52)
    headerBar.BackgroundTransparency = 1
    headerBar.ZIndex = 6
    headerBar.Parent = panel

    local headerLine = Instance.new("Frame")
    headerLine.Position = UDim2.new(0, 0, 1, -1)
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.BackgroundColor3 = THEME.Accent
    headerLine.BackgroundTransparency = 1
    headerLine.BorderSizePixel = 0
    headerLine.ZIndex = 7
    headerLine.Parent = headerBar

    -- Random MOTD (user supplies list via options.MOTD)
    local defaultMotds = options.MOTD or options.Motd or {
        "Welcome to MSI.LUA",
        "Stay safe out there.",
        "Config. Crush. Repeat.",
        "Purple never goes out of style.",
        "One key to rule them all.",
        "Built different.",
        "Load in. Lock in.",
        "Your move.",
        "Fresh session, fresh aim.",
        "MSI is watching... kindly.",
    }

    local function pickMotd(list, recent, maxRecent)
        if type(list) ~= "table" or #list == 0 then
            return "Welcome to MSI.LUA"
        end
        maxRecent = math.min(maxRecent or 12, math.max(0, #list - 1))
        recent = recent or {}

        local pool = {}
        for _, msg in ipairs(list) do
            local used = false
            for _, r in ipairs(recent) do
                if r == msg then used = true; break end
            end
            if not used then
                table.insert(pool, msg)
            end
        end
        if #pool == 0 then
            -- all seen recently — allow repeats, reset history
            for _, msg in ipairs(list) do
                table.insert(pool, msg)
            end
            for i = #recent, 1, -1 do recent[i] = nil end
        end

        local choice = pool[math.random(1, #pool)]
        table.insert(recent, 1, choice)
        while #recent > maxRecent do
            table.remove(recent)
        end
        return choice
    end

    Library._motdRecent = Library._motdRecent or {}
    local motdText = pickMotd(defaultMotds, Library._motdRecent, options.MotdHistory or 12)

    -- Header MOTD only: "MOTD: <message>"
    local motdLabel = Instance.new("TextLabel")
    motdLabel.Name = "MOTD"
    motdLabel.BackgroundTransparency = 1
    motdLabel.Position = UDim2.fromOffset(18, 0)
    motdLabel.Size = UDim2.new(1, -60, 1, 0)
    motdLabel.RichText = true
    motdLabel.Text = string.format(
        '<font color="#B450FF">MOTD:</font> <font color="#E8DCF8">%s</font>',
        motdText:gsub("[<>&]", "")
    )
    motdLabel.TextColor3 = THEME.TextPrimary
    motdLabel.Font = Enum.Font.Gotham
    motdLabel.TextSize = 13
    motdLabel.TextXAlignment = Enum.TextXAlignment.Left
    motdLabel.TextYAlignment = Enum.TextYAlignment.Center
    motdLabel.TextTruncate = Enum.TextTruncate.AtEnd
    motdLabel.TextTransparency = 0
    motdLabel.ZIndex = 10
    motdLabel.Parent = headerBar

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.AnchorPoint = Vector2.new(1, 0.5)
    closeButton.Position = UDim2.new(1, -14, 0.5, 0)
    closeButton.Size = UDim2.fromOffset(28, 28)
    closeButton.BackgroundColor3 = THEME.Panel
    closeButton.BackgroundTransparency = 0.3
    closeButton.Text = "×"
    closeButton.TextColor3 = THEME.TextMuted
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 18
    closeButton.AutoButtonColor = false
    closeButton.ZIndex = 8
    closeButton.Parent = headerBar
    corner(closeButton, 8)
    stroke(closeButton, THEME.Border, 1, 0.5)

    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.15), {
            BackgroundColor3 = THEME.Error,
            TextColor3 = THEME.White,
        }):Play()
    end)
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.15), {
            BackgroundColor3 = THEME.Panel,
            TextColor3 = THEME.TextMuted,
        }):Play()
    end)

    -- Body
    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Position = UDim2.fromOffset(0, 52)
    body.Size = UDim2.new(1, 0, 1, -52)
    body.BackgroundTransparency = 1
    body.ZIndex = 6
    body.Parent = panel

    -- Left profile card
    local leftCard = Instance.new("Frame")
    leftCard.Position = UDim2.fromOffset(18, 16)
    leftCard.Size = UDim2.fromOffset(200, 210)
    leftCard.BackgroundColor3 = THEME.Card
    leftCard.BackgroundTransparency = 0.25
    leftCard.BorderSizePixel = 0
    leftCard.ZIndex = 7
    leftCard.Parent = body
    corner(leftCard, 12)
    stroke(leftCard, THEME.Accent, 1, 0.55)

    local avatarFrame = Instance.new("Frame")
    avatarFrame.Position = UDim2.fromOffset(16, 16)
    avatarFrame.Size = UDim2.fromOffset(72, 72)
    avatarFrame.BackgroundColor3 = THEME.PanelAlt
    avatarFrame.ZIndex = 8
    avatarFrame.Parent = leftCard
    corner(avatarFrame, 12)
    stroke(avatarFrame, THEME.Accent, 1.5, 0.35)

    local avatarImage = Instance.new("ImageLabel")
    avatarImage.Size = UDim2.fromScale(1, 1)
    avatarImage.BackgroundTransparency = 1
    avatarImage.ScaleType = Enum.ScaleType.Fit
    avatarImage.ZIndex = 8
    avatarImage.Parent = avatarFrame
    corner(avatarImage, 12)

    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size180x180
            )
        end)
        if ok then avatarImage.Image = content end
    end)

    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Position = UDim2.fromOffset(100, 22)
    usernameLabel.Size = UDim2.fromOffset(90, 22)
    usernameLabel.Text = player.DisplayName
    usernameLabel.TextColor3 = THEME.TextPrimary
    usernameLabel.Font = Enum.Font.GothamBold
    usernameLabel.TextSize = 14
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
    usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    usernameLabel.ZIndex = 8
    usernameLabel.Parent = leftCard

    local handleLabel = Instance.new("TextLabel")
    handleLabel.BackgroundTransparency = 1
    handleLabel.Position = UDim2.fromOffset(100, 44)
    handleLabel.Size = UDim2.fromOffset(90, 16)
    handleLabel.Text = "@" .. player.Name
    handleLabel.TextColor3 = THEME.TextMuted
    handleLabel.Font = Enum.Font.Gotham
    handleLabel.TextSize = 11
    handleLabel.TextXAlignment = Enum.TextXAlignment.Left
    handleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    handleLabel.ZIndex = 8
    handleLabel.Parent = leftCard

    local function getPlatformName()
        local ok, platform = pcall(function()
            return UserInputService:GetPlatform()
        end)
        if not ok then return "Unknown" end
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

    local infoY = 104
    local function addInfoRow(label, value)
        local row = Instance.new("Frame")
        row.Position = UDim2.fromOffset(16, infoY)
        row.Size = UDim2.new(1, -32, 0, 18)
        row.BackgroundTransparency = 1
        row.ZIndex = 8
        row.Parent = leftCard

        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(0.42, 0, 1, 0)
        l.Text = label
        l.TextColor3 = THEME.TextDim
        l.Font = Enum.Font.Gotham
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 8
        l.Parent = row

        local v = Instance.new("TextLabel")
        v.BackgroundTransparency = 1
        v.Position = UDim2.fromScale(0.42, 0)
        v.Size = UDim2.new(0.58, 0, 1, 0)
        v.Text = value
        v.TextColor3 = THEME.TextMuted
        v.Font = Enum.Font.Gotham
        v.TextSize = 11
        v.TextXAlignment = Enum.TextXAlignment.Right
        v.ZIndex = 8
        v.Parent = row

        infoY = infoY + 22
        return v
    end

    addInfoRow("Platform", getPlatformName())
    local dateValue = addInfoRow("Date", clockParts().isoDate)
    local timeValue = addInfoRow("Time", clockParts().time)
    local attemptsValue = addInfoRow("Attempts", tostring(maxAttempts))

    local timeThread = true
    task.spawn(function()
        while timeThread and screen.Parent do
            local p = clockParts()
            timeValue.Text = p.time
            dateValue.Text = p.isoDate
            task.wait(1)
        end
    end)

    -- Right form card
    local rightCard = Instance.new("Frame")
    rightCard.Position = UDim2.fromOffset(232, 16)
    rightCard.Size = UDim2.fromOffset(330, 210)
    rightCard.BackgroundColor3 = THEME.Card
    rightCard.BackgroundTransparency = 0.25
    rightCard.BorderSizePixel = 0
    rightCard.ZIndex = 7
    rightCard.Parent = body
    corner(rightCard, 12)
    stroke(rightCard, THEME.Accent, 1, 0.55)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.BackgroundTransparency = 1
    statusLabel.Position = UDim2.fromOffset(16, 14)
    statusLabel.Size = UDim2.new(1, -32, 0, 18)
    statusLabel.Text = options.StatusText or string.format("Enter your key · %d attempts", maxAttempts)
    statusLabel.TextColor3 = THEME.TextMuted
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 8
    statusLabel.Parent = rightCard

    local keyInputFrame = Instance.new("Frame")
    keyInputFrame.Position = UDim2.fromOffset(16, 40)
    keyInputFrame.Size = UDim2.new(1, -32, 0, 40)
    keyInputFrame.BackgroundColor3 = THEME.Panel
    keyInputFrame.ZIndex = 8
    keyInputFrame.Parent = rightCard
    corner(keyInputFrame, 10)
    local keyInputStroke = stroke(keyInputFrame, THEME.Accent, 1, 0.4)

    local keyInput = Instance.new("TextBox")
    keyInput.Position = UDim2.fromOffset(14, 0)
    keyInput.Size = UDim2.new(1, -28, 1, 0)
    keyInput.BackgroundTransparency = 1
    keyInput.PlaceholderText = options.Placeholder or "Paste your key here..."
    keyInput.PlaceholderColor3 = THEME.TextDim
    keyInput.Text = ""
    keyInput.TextColor3 = THEME.TextPrimary
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 14
    keyInput.TextXAlignment = Enum.TextXAlignment.Left
    keyInput.ClearTextOnFocus = false
    keyInput.ZIndex = 9
    keyInput.Parent = keyInputFrame

    keyInput.Focused:Connect(function()
        TweenService:Create(keyInputFrame, TweenInfo.new(0.15), {
            BackgroundColor3 = THEME.PanelAlt,
        }):Play()
        TweenService:Create(keyInputStroke, TweenInfo.new(0.15), {
            Color = THEME.AccentLight,
            Transparency = 0.15,
        }):Play()
    end)
    keyInput.FocusLost:Connect(function()
        TweenService:Create(keyInputFrame, TweenInfo.new(0.15), {
            BackgroundColor3 = THEME.Panel,
        }):Play()
        TweenService:Create(keyInputStroke, TweenInfo.new(0.15), {
            Color = THEME.Accent,
            Transparency = 0.4,
        }):Play()
    end)

    local function makeKeyButton(name, text, position, size, fillColor)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Position = position
        button.Size = size
        button.BackgroundColor3 = fillColor
        button.Text = text
        button.TextColor3 = THEME.White
        button.Font = Enum.Font.GothamBold
        button.TextSize = 13
        button.AutoButtonColor = false
        button.ZIndex = 9
        button.Parent = rightCard
        corner(button, 10)
        stroke(button, THEME.AccentLight, 1, 0.55)

        local base = fillColor
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.12), {
                BackgroundTransparency = 0.12,
                Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset + 2),
            }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.12), {
                BackgroundTransparency = 0,
                Size = size,
                BackgroundColor3 = base,
            }):Play()
        end)
        button.MouseButton1Down:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.08), {
                Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset - 2),
                BackgroundTransparency = 0.25,
            }):Play()
        end)
        button.MouseButton1Up:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
                Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset + 2),
                BackgroundTransparency = 0.12,
            }):Play()
        end)

        return button
    end

    local getKeyButton = makeKeyButton(
        "GetKeyButton",
        "Get Key",
        UDim2.fromOffset(16, 92),
        UDim2.fromOffset(144, 36),
        THEME.PanelAlt
    )

    local verifyButton = makeKeyButton(
        "VerifyButton",
        "Verify Key",
        UDim2.fromOffset(170, 92),
        UDim2.fromOffset(144, 36),
        THEME.Accent
    )

    local hintLabel = Instance.new("TextLabel")
    hintLabel.BackgroundTransparency = 1
    hintLabel.Position = UDim2.fromOffset(16, 142)
    hintLabel.Size = UDim2.new(1, -32, 0, 52)
    hintLabel.Text = options.HintText
        or string.format("You have %d attempts. Wrong key reduces attempts — at 0 you will be kicked.", maxAttempts)
    hintLabel.TextColor3 = THEME.TextDim
    hintLabel.TextWrapped = true
    hintLabel.Font = Enum.Font.Gotham
    hintLabel.TextSize = 11
    hintLabel.TextXAlignment = Enum.TextXAlignment.Left
    hintLabel.TextYAlignment = Enum.TextYAlignment.Top
    hintLabel.ZIndex = 8
    hintLabel.Parent = rightCard

    local verifying = false
    local destroyed = false

    local function setStatus(textValue, color)
        statusLabel.Text = textValue
        statusLabel.TextColor3 = color or THEME.TextMuted
    end

    local function updateAttemptsLabel()
        attemptsValue.Text = tostring(attemptsLeft)
        if attemptsLeft <= 1 then
            attemptsValue.TextColor3 = THEME.Error
        elseif attemptsLeft <= 2 then
            attemptsValue.TextColor3 = THEME.Warning
        else
            attemptsValue.TextColor3 = THEME.TextMuted
        end
    end
    updateAttemptsLabel()

    local function shakePanel()
        local originalPosition = panel.Position
        local sequence = {
            originalPosition + UDim2.fromOffset(-12, 0),
            originalPosition + UDim2.fromOffset(12, 0),
            originalPosition + UDim2.fromOffset(-8, 0),
            originalPosition + UDim2.fromOffset(8, 0),
            originalPosition + UDim2.fromOffset(-4, 0),
            originalPosition,
        }
        for _, position in ipairs(sequence) do
            TweenService:Create(panel, TweenInfo.new(0.045), { Position = position }):Play()
            task.wait(0.045)
        end
    end

    local function destroyVisuals(afterClose)
        if destroyed then
            if afterClose then safeSpawn(afterClose) end
            return
        end
        destroyed = true
        timeThread = false

        local blurFade = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        local panelFade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

        TweenService:Create(blur, blurFade, { Size = 0 }):Play()
        TweenService:Create(backdrop, panelFade, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(gradientOverlay, panelFade, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(panel, panelFade, {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(540, 280),
            Position = UDim2.fromScale(0.5, 0.48),
        }):Play()
        TweenService:Create(panelStroke, panelFade, { Transparency = 1 }):Play()
        if panelImage then
            TweenService:Create(panelImage, panelFade, { ImageTransparency = 1 }):Play()
        end
        if dragonImage then
            TweenService:Create(dragonImage, panelFade, { ImageTransparency = 1 }):Play()
        end
        TweenService:Create(panelTint, panelFade, { BackgroundTransparency = 1 }):Play()

        for _, desc in ipairs(panel:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
                TweenService:Create(desc, panelFade, { TextTransparency = 1 }):Play()
                if desc:IsA("TextButton") or desc:IsA("TextBox") then
                    pcall(function()
                        TweenService:Create(desc, panelFade, { BackgroundTransparency = 1 }):Play()
                    end)
                end
            elseif desc:IsA("ImageLabel") and desc ~= panelImage then
                TweenService:Create(desc, panelFade, { ImageTransparency = 1 }):Play()
            elseif desc:IsA("UIStroke") and desc ~= panelStroke then
                TweenService:Create(desc, panelFade, { Transparency = 1 }):Play()
            elseif desc:IsA("Frame") and desc ~= panelTint and desc ~= headerBar and desc ~= body then
                pcall(function()
                    TweenService:Create(desc, panelFade, { BackgroundTransparency = 1 }):Play()
                end)
            end
        end

        task.wait(0.55)
        if blur.Parent then blur:Destroy() end
        if screen.Parent then screen:Destroy() end
        if afterClose then safeSpawn(afterClose) end
    end

    local function closeKeySystem(afterClose)
        if destroyed then
            if afterClose then safeSpawn(afterClose) end
            return
        end
        if options.OnClose then safeSpawn(options.OnClose) end
        task.spawn(destroyVisuals, afterClose)
    end

    local function failKeyFinal()
        setStatus("No attempts left. Kicking...", THEME.Error)
        updateAttemptsLabel()
        task.spawn(shakePanel)
        TweenService:Create(blur, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
            Size = blurSizeOnFail,
        }):Play()
        TweenService:Create(keyInputStroke, TweenInfo.new(0.3), {
            Color = THEME.Error,
            Transparency = 0.1,
        }):Play()

        if onFailure then safeSpawn(onFailure, keyInput.Text, 0) end

        task.wait(kickDelay)
        if not destroyed then
            player:Kick(kickMessage)
        end
    end

    local function failKeySoft()
        attemptsLeft = attemptsLeft - 1
        updateAttemptsLabel()
        local msg = attemptsLeft == 1
            and "Invalid key. 1 attempt left."
            or string.format("Invalid key. %d attempts left.", attemptsLeft)
        setStatus(msg, THEME.Error)
        task.spawn(shakePanel)
        TweenService:Create(keyInputStroke, TweenInfo.new(0.25), {
            Color = THEME.Error,
            Transparency = 0.15,
        }):Play()
        task.delay(0.8, function()
            if not destroyed and keyInputStroke and keyInputStroke.Parent then
                TweenService:Create(keyInputStroke, TweenInfo.new(0.3), {
                    Color = THEME.Accent,
                    Transparency = 0.4,
                }):Play()
            end
        end)
        if onFailure then safeSpawn(onFailure, keyInput.Text, attemptsLeft) end
    end

    local function verify()
        if verifying or destroyed then return end

        local submittedKey = keyInput.Text
        if submittedKey == "" then
            setStatus("Enter a key first.", THEME.Warning)
            return false
        end

        verifying = true
        setStatus("Verifying...", THEME.TextMuted)
        task.wait(options.VerifyDelay or 0.55)

        local valid = validKeys[submittedKey] == true
        if not valid and type(options.ValidateKey) == "function" then
            local ok, result = pcall(options.ValidateKey, submittedKey)
            valid = ok and result == true
        end

        if valid then
            setStatus("Key accepted. Welcome.", THEME.Success)
            TweenService:Create(keyInputStroke, TweenInfo.new(0.25), {
                Color = THEME.Success,
                Transparency = 0,
            }):Play()
            if onSuccess then safeSpawn(onSuccess, submittedKey) end
            task.wait(options.SuccessDelay or 0.5)
            if autoDestroyOnValid then
                closeKeySystem(function()
                    if options.OnSuccessComplete then
                        safeSpawn(options.OnSuccessComplete, submittedKey)
                    end
                end)
            elseif options.OnSuccessComplete then
                safeSpawn(options.OnSuccessComplete, submittedKey)
            end
            verifying = false
            return true
        end

        if attemptsLeft <= 1 then
            attemptsLeft = 0
            verifying = false
            if options.KickOnInvalid ~= false then
                failKeyFinal()
            else
                setStatus("Invalid key. No attempts left.", THEME.Error)
                if onFailure then safeSpawn(onFailure, submittedKey, 0) end
            end
            return false
        end

        failKeySoft()
        verifying = false
        return false
    end

    verifyButton.MouseButton1Click:Connect(verify)

    keyInput.FocusLost:Connect(function(enter)
        if enter then verify() end
    end)

    getKeyButton.MouseButton1Click:Connect(function()
        if setclipboard then
            local ok = pcall(setclipboard, keyLink)
            if ok then
                setStatus("Link copied — check your clipboard.", THEME.AccentLight)
                return
            end
        end
        setStatus(keyLink, THEME.AccentLight)
    end)

    closeButton.MouseButton1Click:Connect(function()
        closeKeySystem()
        if kickOnClose then
            task.wait(0.05)
            player:Kick(options.CloseKickMessage or "You closed the key system.")
        end
    end)

    -- Entrance: smaller + transparent → menu-like pop-in
    panel.Size = UDim2.fromOffset(540, 280)
    panel.BackgroundTransparency = 1

    task.spawn(function()
        local fadeIn = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local scaleIn = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        TweenService:Create(backdrop, fadeIn, { BackgroundTransparency = 0.2 }):Play()
        TweenService:Create(gradientOverlay, fadeIn, { BackgroundTransparency = 0.4 }):Play()
        TweenService:Create(panel, scaleIn, {
            BackgroundTransparency = 0,
            Size = UDim2.fromOffset(580, 300),
        }):Play()
        TweenService:Create(panelStroke, fadeIn, { Transparency = 0.3 }):Play()
        TweenService:Create(panelTint, fadeIn, { BackgroundTransparency = 0.2 }):Play()
        if dragonImage then
            TweenService:Create(dragonImage, fadeIn, { ImageTransparency = 0.75 }):Play()
        end
        TweenService:Create(headerLine, fadeIn, { BackgroundTransparency = 0.4 }):Play()
        if motdLabel then
            TweenService:Create(motdLabel, fadeIn, { TextTransparency = 0 }):Play()
        end
        TweenService:Create(blur, TweenInfo.new(0.5), { Size = 10 }):Play()
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
    -- Dragon from main UI (content / watermark)
    local dragonId = options.Image or options.BackgroundImage or "rbxassetid://78464903954782"
    local holdTime = tonumber(options.HoldTime) or 1.35
    local fadeInTime = tonumber(options.FadeInTime) or 1.0
    local fadeOutTime = tonumber(options.FadeOutTime) or 0.85

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
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(55, 0, 95)),
    })
    gradient.Rotation = 90
    gradient.Parent = glow

    local pulseRunning = true
    task.spawn(function()
        local t = 0
        while pulseRunning and background.Parent do
            t = t + RunService.RenderStepped:Wait()
            local pulse = 0.55 + math.sin(t * 0.7) * 0.18
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(0.55, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(1.0, Color3.fromRGB(55 * pulse, 0, 95 * pulse)),
            })
        end
    end)

    local titleContainer = Instance.new("Frame")
    titleContainer.Name = "TitleContainer"
    titleContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    titleContainer.Position = UDim2.fromScale(0.5, 0.5)
    titleContainer.Size = UDim2.fromScale(0.72, 0.55)
    titleContainer.BackgroundTransparency = 1
    titleContainer.Parent = background

    local titleImage = Instance.new("ImageLabel")
    titleImage.Name = "TitleImage"
    titleImage.AnchorPoint = Vector2.new(0.5, 0.5)
    titleImage.Position = UDim2.fromScale(0.5, 0.5)
    titleImage.Size = UDim2.fromScale(0.88, 0.88)
    titleImage.BackgroundTransparency = 1
    titleImage.Image = dragonId
    titleImage.ImageTransparency = 1
    titleImage.ScaleType = Enum.ScaleType.Fit
    titleImage.Parent = titleContainer

    task.spawn(function()
        task.wait(0.2)

        -- Purple glow rises, then dragon scales + fades in
        TweenService:Create(
            glow,
            TweenInfo.new(fadeInTime * 0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0}
        ):Play()

        TweenService:Create(
            titleImage,
            TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                ImageTransparency = 0,
                Size = UDim2.fromScale(1, 1),
            }
        ):Play()

        task.wait(fadeInTime + holdTime)

        pulseRunning = false

        -- Fade out dragon + glow, keep pure black so KeySystem handoff has no flash
        TweenService:Create(
            titleImage,
            TweenInfo.new(fadeOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            {
                ImageTransparency = 1,
                Size = UDim2.fromScale(1.06, 1.06),
            }
        ):Play()

        TweenService:Create(
            glow,
            TweenInfo.new(fadeOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ):Play()

        task.wait(fadeOutTime)

        if type(options.OnComplete) == "function" then
            task.spawn(options.OnComplete)
        end

        task.wait(0.12)
        if screen.Parent then
            screen:Destroy()
        end
    end)

    return screen
end

----------------------------------------------------------------
-- BUILT-IN SETTINGS TAB
----------------------------------------------------------------
function Library:_populateSettingsTab(tab)
    local general = tab:CreateSection("Menu", "left")

    general:CreateMenuKeybind("Menu keybind", toggleKey, {id = "_settings_menu_key"})

    general:CreateKeybindListToggle("Show keybind list", keybindListEnabled, {id = "_settings_kb_list"})

    general:CreateMultiDropdown("UI features", {
        "Watermark",
        "Notifications",
        "Animations",
    }, {
        "Watermark",
        "Notifications",
        "Animations",
    }, {id = "_settings_ui_features"})

    local autoToggle = general:CreateToggle("Auto save config", ConfigManager.autoSave, {id = "_settings_autosave"})
    autoToggle:onChange(function(v) ConfigManager.autoSave = v end)

    local autoSlider = general:CreateSlider("Auto save interval (s)", 10, 300, ConfigManager.autoSaveInterval, 0, {id = "_settings_autosave_interval"})
    autoSlider:onChange(function(v) ConfigManager.autoSaveInterval = v end)

    local configs = tab:CreateSection("Configs", "right")

    local function refreshList()
        local list = FileAPI.list()
        if #list == 0 then list = {ConfigManager.current} end
        return list
    end

    local nameBox = configs:CreateTextBox("Config name", "my_config", ConfigManager.current, {id = "_settings_config_name"})
    local listDropdown = configs:CreateDropdown("Saved configs", refreshList(), ConfigManager.current, {id = "_settings_config_list"})

    listDropdown:onChange(function(v)
        nameBox.set(v)
    end)

    configs:CreateButton("Save", THEME.Accent, function()
        local name = nameBox.get()
        if name == "" then return end
        ConfigManager.save(name)
        if listDropdown and listDropdown.setOptions then
            listDropdown.setOptions(refreshList(), name)
        end
    end)

    configs:CreateButton("Load", THEME.PanelAlt, function()
        local name = nameBox.get()
        if name == "" then return end
        ConfigManager.load(name)
    end)

    configs:CreateButton("Delete", THEME.Error, function()
        local name = nameBox.get()
        if name == "" then return end
        ConfigManager.delete(name)
        local list = refreshList()
        local nextName = list[1] or ConfigManager.current
        if listDropdown and listDropdown.setOptions then
            listDropdown.setOptions(list, nextName)
        end
        if nameBox.set then
            nameBox.set(nextName)
        end
    end)
end

function Library:_relocateSettingsTab()
    -- Settings is permanent: create it once and never destroy/rebuild it.
    if self._buildingSettings or self._settingsTab then
        return self._settingsTab
    end

    self._buildingSettings = true
    local tab = self:CreateTab("Settings", ICONS.Settings)
    self._buildingSettings = false
    self._settingsTab = tab
    self:_populateSettingsTab(tab)
    return tab
end


----------------------------------------------------------------
-- MAIN MENU VISIBILITY / BOOT SEQUENCE
----------------------------------------------------------------
function Library:Show()
    menuOpen = true
    hideTooltip()

    -- Start slightly smaller / transparent for a premium entrance
    window.Visible = true
    window.Size = UDim2.fromOffset(920, 560)
    window.BackgroundTransparency = 1
    window.Position = UDim2.fromScale(0.5, 0.52)

    if watermark then
        watermark.Visible = true
    end

    local openInfo = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local fadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    TweenService:Create(window, openInfo, {
        Size = UDim2.fromOffset(960, 600),
        Position = UDim2.fromScale(0.5, 0.5),
    }):Play()

    TweenService:Create(window, fadeInfo, {
        BackgroundTransparency = 0,
    }):Play()

    return self
end

function Library:Hide()
    menuOpen = false
    hideTooltip()

    if watermark then
        watermark.Visible = false
    end

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

    -- Force closed state before boot sequence
    menuOpen = false
    window.Visible = false
    window.Size = UDim2.fromOffset(920, 560)
    window.BackgroundTransparency = 1
    window.Position = UDim2.fromScale(0.5, 0.52)
    if watermark then
        watermark.Visible = false
    end

    local loadingOptions = options.LoadingScreen or {}
    local keyOptions = options.KeySystem or {}
    local useLoading = loadingOptions.Enabled ~= false
    local useKeySystem = keyOptions.Enabled ~= false

    local function finishBoot(key)
        -- Blur already gone; short beat then premium menu entrance
        task.wait(0.08)
        self:Show()
        if type(options.OnReady) == "function" then
            safeSpawn(options.OnReady, key)
        end
    end

    local function startKeySystem()
        if not useKeySystem then
            finishBoot(nil)
            return
        end

        local launchKeyOptions = table.clone(keyOptions)
        local userSuccess = launchKeyOptions.OnSuccess
        local userComplete = launchKeyOptions.OnSuccessComplete

        -- Defaults for a clean 3-attempt key flow
        if launchKeyOptions.MaxAttempts == nil then
            launchKeyOptions.MaxAttempts = 3
        end
        launchKeyOptions.AutoDestroyOnValid = true
        launchKeyOptions.OnSuccess = function(key)
            if userSuccess then
                safeSpawn(userSuccess, key)
            end
        end
        -- Fires AFTER blur + panel fully faded out
        launchKeyOptions.OnSuccessComplete = function(key)
            if userComplete then
                safeSpawn(userComplete, key)
            end
            finishBoot(key)
        end

        self:CreateKeySystem(launchKeyOptions)
    end

    if useLoading then
        loadingOptions = table.clone(loadingOptions)
        -- Dragon from main UI unless user overrides Image
        if not loadingOptions.Image and not loadingOptions.BackgroundImage then
            loadingOptions.Image = "rbxassetid://122286881817734"
        end
        loadingOptions.OnComplete = startKeySystem
        self:CreateLoadingScreen(loadingOptions)
    else
        startKeySystem()
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

Library.CreateMultiDropdown = function(section, label, values, defaults, options)
    return section:CreateMultiDropdown(label, values, defaults, options)
end

Library.CreateNumberBox = function(section, label, min, max, default, decimals, options)
    return section:CreateNumberBox(label, min, max, default, decimals, options)
end

Library.CreateColorPicker = function(section, label, defaultColor, options)
    return section:CreateColorPicker(label, defaultColor, options)
end

Library.CreateKeybind = function(section, label, defaultKey, options)
    return section:CreateKeybind(label, defaultKey, options)
end

Library.CreateMenuKeybind = function(section, label, defaultKey, options)
    return section:CreateMenuKeybind(label, defaultKey, options)
end

Library.CreateKeybindListToggle = function(section, label, default, options)
    return section:CreateKeybindListToggle(label, default, options)
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

Library.SetMenuKeybind = function(key)
    return Library:SetMenuKeybind(key)
end

Library.GetMenuKeybind = function()
    return toggleKey
end

Library.IsKeybindListVisible = function()
    return keybindListEnabled == true and keybindListHost and keybindListHost.Visible == true
end

Library.Start = function(options)
    return Library:Launch(options)
end

return Library
