--[[
    Roblox Auth Logger - CLIENT SIDE
    
    This runs on the CLIENT and sends auth data directly to your Vercel API.
    The Vercel server will capture the REAL player IP address.
    
    Usage:
        1. Place this LocalScript in StarterPlayer > StarterPlayerScripts
        2. Configure your Vercel endpoint below
        3. The script will automatically log when the player joins
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ========================================
-- CONFIGURATION
-- ========================================

local VERCEL_ENDPOINT = "https://your-app.vercel.app" -- CHANGE THIS to your Vercel URL
local YOUR_API_KEY = "your-api-key-here" -- CHANGE THIS to your actual API key

local DEBUG_MODE = true -- Set to false in production

-- ========================================
-- AUTH LOGGER MODULE
-- ========================================

local AuthLogger = {}

function AuthLogger.Log(apiKey, metadata)
    local player = LocalPlayer
    
    -- Build payload
    local payload = {
        apiKey = apiKey,
        userId = tostring(player.UserId),
        username = player.Name,
        sessionId = "client_" .. game.JobId .. "_" .. player.UserId .. "_" .. os.time(),
        -- IP will be automatically captured by Vercel server
        timestamp = os.time(),
        metadata = metadata or {}
    }
    
    if DEBUG_MODE then
        print("[AuthLogger] Sending auth data to Vercel...")
        print("  Username:", payload.username)
        print("  User ID:", payload.userId)
        print("  API Key:", payload.apiKey)
    end
    
    -- Send to Vercel (this runs from CLIENT so Vercel captures the real IP)
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
    
    if success then
        if response.Success and response.StatusCode == 200 then
            local responseData = HttpService:JSONDecode(response.Body)
            
            if DEBUG_MODE then
                print("[AuthLogger] ✅ Logged successfully!")
                print("  Your IP:", responseData.executionIP)
                print("  Alerts:", responseData.alertCount)
            end
            
            -- Check for alerts
            if responseData.alertCount and responseData.alertCount > 0 then
                warn("[AuthLogger] ⚠️ Suspicious activity detected on your account!")
                
                -- You could display a UI warning to the player here
                for _, alert in ipairs(responseData.alerts) do
                    warn("  Alert:", alert.type, "-", alert.severity)
                end
            end
            
            return true, responseData
        else
            warn("[AuthLogger] ❌ Failed:", response.StatusCode)
            if DEBUG_MODE then
                warn("  Response:", response.Body)
            end
            return false, response
        end
    else
        warn("[AuthLogger] ❌ Error:", response)
        return false, response
    end
end

function AuthLogger.EndSession(apiKey, sessionId)
    local payload = {
        apiKey = apiKey,
        sessionId = sessionId
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
    
    if DEBUG_MODE then
        print("[AuthLogger] Session ended")
    end
end

-- ========================================
-- AUTO-RUN ON PLAYER JOIN
-- ========================================

-- Wait for player to fully load
repeat task.wait() until LocalPlayer

-- Log authentication automatically
local success, response = AuthLogger.Log(YOUR_API_KEY, {
    clientSide = true,
    placeId = game.PlaceId,
    gameId = game.GameId
})

if success then
    print("[AuthLogger] Authentication logged successfully!")
    
    -- Store session ID for cleanup
    local sessionId = "client_" .. game.JobId .. "_" .. LocalPlayer.UserId .. "_" .. os.time()
    
    -- End session when player leaves (optional)
    game:BindToClose(function()
        AuthLogger.EndSession(YOUR_API_KEY, sessionId)
    end)
else
    warn("[AuthLogger] Failed to log authentication!")
end

-- ========================================
-- OPTIONAL: Periodic Re-authentication
-- ========================================

-- Uncomment this to log every 5 minutes (helps detect session sharing)
--[[
spawn(function()
    while task.wait(300) do -- 300 seconds = 5 minutes
        AuthLogger.Log(YOUR_API_KEY, {
            periodic = true,
            timestamp = os.time()
        })
    end
end)
]]--

return AuthLogger
