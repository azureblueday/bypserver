--[[
    Auth Logger Loadstring Loader
    
    For scripts hosted in a "files-2" folder on GitHub
    
    Usage in executor:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO/main/files-2/AuthLoader.lua"))()
]]

local HttpService = game:GetService("HttpService")

-- ========================================
-- CONFIGURATION
-- ========================================

local CONFIG = {
    -- Your GitHub repository details
    GITHUB_USERNAME = "azureblueday",
    GITHUB_REPO = "bypserver",
    GITHUB_BRANCH = "main",
    FOLDER_PATH = "files-2",
    
    -- Your Vercel API endpoint
    VERCEL_ENDPOINT = "https://bypserver.vercel.app",
    
    -- Your API key
    API_KEY = "your-api-key-here",
    
    -- Settings
    DEBUG = true,
    AUTO_LOG = true
}

-- ========================================
-- GITHUB RAW URL BUILDER
-- ========================================

local function buildGitHubURL(filename)
    return string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/%s/%s",
        CONFIG.GITHUB_USERNAME,
        CONFIG.GITHUB_REPO,
        CONFIG.GITHUB_BRANCH,
        CONFIG.FOLDER_PATH,
        filename
    )
end

-- ========================================
-- LOAD AUTH LOGGER FROM GITHUB
-- ========================================

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔄 Loading Auth Logger...")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

local authLoggerURL = buildGitHubURL("ClientAuthLogger.lua")

if CONFIG.DEBUG then
    print("📂 Loading from:", authLoggerURL)
end

local success, authLoggerModule = pcall(function()
    return loadstring(game:HttpGet(authLoggerURL))()
end)

if not success then
    warn("❌ Failed to load Auth Logger:", authLoggerModule)
    return
end

print("✅ Auth Logger loaded successfully!")

-- ========================================
-- CONFIGURE AUTH LOGGER
-- ========================================

if authLoggerModule and type(authLoggerModule) == "table" then
    -- If it's the full module, configure it
    if authLoggerModule.SetAPIEndpoint then
        authLoggerModule.SetAPIEndpoint(CONFIG.VERCEL_ENDPOINT)
    end
    
    if authLoggerModule.SetDebug then
        authLoggerModule.SetDebug(CONFIG.DEBUG)
    end
    
    -- Make it globally accessible
    getgenv().AuthLogger = authLoggerModule
    
    if CONFIG.DEBUG then
        print("🔧 Auth Logger configured")
        print("📡 Endpoint:", CONFIG.VERCEL_ENDPOINT)
    end
end

-- ========================================
-- AUTO-AUTHENTICATE
-- ========================================

if CONFIG.AUTO_LOG then
    task.spawn(function()
        wait(2) -- Wait for player to fully load
        
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        
        if not LocalPlayer then
            warn("⚠️ LocalPlayer not found!")
            return
        end
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔐 Authenticating...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if getgenv().AuthLogger and getgenv().AuthLogger.LogAuth then
            local success, response = getgenv().AuthLogger.LogAuth({
                ApiKey = CONFIG.API_KEY,
                UserId = LocalPlayer.UserId,
                Username = LocalPlayer.Name,
                Player = LocalPlayer,
                Metadata = {
                    executor = true,
                    loadedFrom = "files-2",
                    timestamp = os.time()
                }
            })
            
            if success then
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("✅ AUTHENTICATION SUCCESS")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("👤 User:", LocalPlayer.Name)
                print("🆔 ID:", LocalPlayer.UserId)
                if response and response.executionIP then
                    print("🌐 IP:", response.executionIP)
                end
                if response and response.alertCount then
                    print("⚠️  Alerts:", response.alertCount)
                end
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            else
                warn("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                warn("❌ AUTHENTICATION FAILED")
                warn("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            end
        end
    end)
end

print("✅ Auth system ready!")

return getgenv().AuthLogger
