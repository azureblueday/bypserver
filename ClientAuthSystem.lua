--[[
    CLIENT-SIDE Auth with Custom API Key System
    
    This example shows how to implement a custom API key system where:
    1. Player enters their API key in a GUI
    2. Client validates with your Vercel server
    3. Real IP is logged on the Vercel server
    
    Place in StarterPlayer > StarterPlayerScripts
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ========================================
-- CONFIGURATION
-- ========================================

local VERCEL_ENDPOINT = "https://your-app.vercel.app"
local DEBUG_MODE = true

-- ========================================
-- AUTH SYSTEM
-- ========================================

local AuthSystem = {}
AuthSystem.IsAuthenticated = false
AuthSystem.CurrentApiKey = nil
AuthSystem.SessionId = nil

-- Send auth request to Vercel
function AuthSystem.Authenticate(apiKey)
    if not apiKey or apiKey == "" then
        warn("[Auth] No API key provided")
        return false, "No API key"
    end
    
    local player = LocalPlayer
    
    -- Generate session ID
    local sessionId = string.format("client_%s_%d_%d", 
        game.JobId, 
        player.UserId, 
        os.time()
    )
    
    -- Build payload
    local payload = {
        apiKey = apiKey,
        userId = tostring(player.UserId),
        username = player.Name,
        sessionId = sessionId,
        -- Vercel will capture the REAL IP from the HTTP request
        timestamp = os.time(),
        metadata = {
            placeId = game.PlaceId,
            displayName = player.DisplayName,
            accountAge = player.AccountAge,
            locale = player.LocaleId
        }
    }
    
    if DEBUG_MODE then
        print("[Auth] Authenticating...")
        print("  Username:", payload.username)
        print("  User ID:", payload.userId)
        print("  API Key:", string.sub(apiKey, 1, 10) .. "...")
    end
    
    -- Send to Vercel API
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = VERCEL_ENDPOINT .. "/api/auth-log",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    if success and response.Success and response.StatusCode == 200 then
        local responseData = HttpService:JSONDecode(response.Body)
        
        AuthSystem.IsAuthenticated = true
        AuthSystem.CurrentApiKey = apiKey
        AuthSystem.SessionId = sessionId
        
        if DEBUG_MODE then
            print("[Auth] ✅ Authentication successful!")
            print("  Your IP:", responseData.executionIP)
            print("  Alerts:", responseData.alertCount or 0)
        end
        
        -- Handle alerts
        if responseData.alertCount and responseData.alertCount > 0 then
            warn("[Auth] ⚠️ SECURITY ALERT!")
            for _, alert in ipairs(responseData.alerts) do
                warn(string.format("  [%s] %s", alert.severity, alert.type))
                
                -- If critical, you might want to block access
                if alert.severity == "CRITICAL" then
                    warn("  Critical security issue detected!")
                    -- Could kick player or disable features here
                end
            end
        end
        
        return true, responseData
    else
        local errorMsg = "Authentication failed"
        if success then
            errorMsg = errorMsg .. " (Status: " .. tostring(response.StatusCode) .. ")"
        else
            errorMsg = errorMsg .. " (" .. tostring(response) .. ")"
        end
        
        warn("[Auth] ❌", errorMsg)
        AuthSystem.IsAuthenticated = false
        return false, errorMsg
    end
end

-- End session
function AuthSystem.Logout()
    if not AuthSystem.IsAuthenticated then
        return
    end
    
    if DEBUG_MODE then
        print("[Auth] Logging out...")
    end
    
    local payload = {
        apiKey = AuthSystem.CurrentApiKey,
        sessionId = AuthSystem.SessionId
    }
    
    pcall(function()
        HttpService:RequestAsync({
            Url = VERCEL_ENDPOINT .. "/api/end-session",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    AuthSystem.IsAuthenticated = false
    AuthSystem.CurrentApiKey = nil
    AuthSystem.SessionId = nil
    
    if DEBUG_MODE then
        print("[Auth] Logged out")
    end
end

-- ========================================
-- EXAMPLE 1: Simple Auto-Login
-- ========================================

-- For games where you have a pre-defined API key
local function autoLogin()
    local PRESET_API_KEY = "your-preset-key-here"
    
    -- Wait for player
    repeat task.wait() until LocalPlayer
    
    -- Authenticate
    local success, result = AuthSystem.Authenticate(PRESET_API_KEY)
    
    if success then
        print("✅ Ready to play!")
    else
        warn("❌ Authentication failed:", result)
        -- Could kick player or show error UI
    end
    
    -- Cleanup on leave
    game:BindToClose(function()
        AuthSystem.Logout()
    end)
end

-- ========================================
-- EXAMPLE 2: GUI-Based API Key Entry
-- ========================================

-- For games where players enter their own API keys
local function setupLoginGUI()
    repeat task.wait() until LocalPlayer
    
    -- Create simple GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AuthGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 200)
    frame.Position = UDim2.new(0.5, -200, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "Enter API Key"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -40, 0, 40)
    textBox.Position = UDim2.new(0, 20, 0, 60)
    textBox.PlaceholderText = "sk_prod_..."
    textBox.Text = ""
    textBox.TextSize = 16
    textBox.Font = Enum.Font.Gotham
    textBox.Parent = frame
    
    local loginButton = Instance.new("TextButton")
    loginButton.Size = UDim2.new(0, 150, 0, 40)
    loginButton.Position = UDim2.new(0.5, -75, 0, 120)
    loginButton.Text = "Login"
    loginButton.TextSize = 18
    loginButton.Font = Enum.Font.GothamBold
    loginButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    loginButton.TextColor3 = Color3.new(1, 1, 1)
    loginButton.Parent = frame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 20)
    statusLabel.Position = UDim2.new(0, 10, 0, 170)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = frame
    
    -- Login button click
    loginButton.MouseButton1Click:Connect(function()
        local apiKey = textBox.Text
        
        if apiKey == "" then
            statusLabel.Text = "Please enter an API key"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        statusLabel.Text = "Authenticating..."
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        loginButton.Text = "Loading..."
        loginButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        -- Attempt authentication
        local success, result = AuthSystem.Authenticate(apiKey)
        
        if success then
            statusLabel.Text = "✅ Authentication successful!"
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            -- Hide GUI after 1 second
            task.wait(1)
            screenGui:Destroy()
            
            print("🎮 Player authenticated and ready to play!")
        else
            statusLabel.Text = "❌ " .. tostring(result)
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            loginButton.Text = "Login"
            loginButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        end
    end)
    
    -- Cleanup on leave
    game:BindToClose(function()
        AuthSystem.Logout()
    end)
end

-- ========================================
-- CHOOSE YOUR METHOD
-- ========================================

-- Method 1: Auto-login (uncomment to use)
-- autoLogin()

-- Method 2: GUI-based login (uncomment to use)
setupLoginGUI()

return AuthSystem
