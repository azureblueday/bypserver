# Client-Side Auth Logger - Complete Guide

A client-side Roblox authentication system that logs to Vercel and captures **real player IP addresses**.

## 🎯 Why Client-Side?

### Server-Side vs Client-Side

| Feature | Server-Side | Client-Side |
|---------|------------|-------------|
| IP Logged | Roblox Server IP (always same) | **Real Player IP** ✅ |
| Location Detection | ❌ Not possible | ✅ Accurate |
| Impossible Travel | ❌ Can't detect | ✅ Works perfectly |
| IP-based Alerts | ❌ Useless | ✅ Effective |
| API Key Security | ✅ Hidden from client | ⚠️ Visible to client |

**Client-side is REQUIRED** for proper IP-based detection and location tracking.

## 🚀 How It Works

```
1. Player opens your Roblox game
   ↓
2. LocalScript runs on player's computer
   ↓
3. Script sends auth data to your Vercel API
   ↓
4. Vercel captures the REAL player IP from HTTP headers
   ↓
5. Vercel logs everything (IP, username, API key)
   ↓
6. Vercel checks for suspicious patterns
   ↓
7. If alert: Sends webhook to Discord
   ↓
8. Returns response to Roblox client
```

## 📋 What Gets Logged

Every authentication event logs:

```json
{
  "timestamp": "2026-02-05T15:30:45.123Z",
  "event": "auth_attempt",
  "apiKey": "sk_prod_abc123xyz789",         ← Full API key
  "username": "CoolPlayer123",               ← Roblox username
  "userId": "987654321",                     ← Roblox UserId
  "executionIP": "203.0.113.45",            ← REAL PLAYER IP!
  "sessionId": "client_abc_987654321_...",
  "metadata": {
    "placeId": 123456789,
    "displayName": "Cool Player",
    "accountAge": 150,
    "locale": "en-us"
  }
}
```

## 📦 Files You Need

### For Vercel (Backend):
- `api/auth-log.js` - Main logging endpoint
- `api/end-session.js` - Session cleanup endpoint
- `package.json` - Dependencies
- `vercel.json` - Vercel configuration
- `.env` - Environment variables (webhook URL)

### For Roblox (Client):
- `ClientAuthLogger.lua` - Simple auto-login version
- `ClientAuthSystem.lua` - Advanced version with GUI

## 🔧 Implementation Methods

### Method 1: Simple Auto-Login

**Use Case:** All players use the same API key, you just want to track who's playing.

**File:** `ClientAuthLogger.lua`

**Setup:**
1. Place in `StarterPlayer` → `StarterPlayerScripts`
2. Must be a **LocalScript**
3. Update these variables:
```lua
local VERCEL_ENDPOINT = "https://your-app.vercel.app"
local YOUR_API_KEY = "your-api-key-here"
```

**What happens:**
- Script runs automatically when player joins
- Logs to Vercel immediately
- Player's real IP is captured
- Alerts shown in Output window if detected

**Code:**
```lua
-- Automatically authenticates on join
local success, response = AuthLogger.Log(YOUR_API_KEY, {
    clientSide = true,
    placeId = game.PlaceId
})
```

---

### Method 2: GUI-Based Login

**Use Case:** Each player has their own API key, or you want players to authenticate manually.

**File:** `ClientAuthSystem.lua`

**Setup:**
1. Place in `StarterPlayer` → `StarterPlayerScripts`
2. Must be a **LocalScript**
3. Update Vercel endpoint:
```lua
local VERCEL_ENDPOINT = "https://your-app.vercel.app"
```

4. Choose activation method at the bottom:
```lua
-- For auto-login with preset key:
autoLogin()

-- OR for GUI where player enters key:
setupLoginGUI()
```

**What happens:**
- Shows GUI on player join
- Player enters their API key
- Validates with Vercel
- Captures real IP during validation
- Shows success/error messages

**Features:**
- ✅ Custom login GUI
- ✅ Error handling and feedback
- ✅ Session management
- ✅ Alert notifications to player

---

## 🔐 Security Considerations

### API Key Exposure

⚠️ **IMPORTANT:** Client-side scripts can be read by players!

**Risk:** Players can extract the API key from your LocalScript.

**Solutions:**

1. **Per-Player API Keys** (Most Secure)
   - Each player gets their own unique API key
   - Keys can be revoked individually
   - Use Method 2 (GUI-based login)

2. **Game-Wide Key with Server Validation** (Moderate Security)
   - Use Method 1 (auto-login)
   - Accept that key may be extracted
   - Implement rate limiting on Vercel
   - Monitor for abuse via alerts

3. **Hybrid Approach** (Recommended)
   - Store key on your own backend server
   - Client requests key from your server first
   - Your server validates player before giving key
   - Client then uses key to authenticate with Vercel

**Example Hybrid Code:**
```lua
-- Client requests key from YOUR backend
local function getApiKey()
    local response = HttpService:RequestAsync({
        Url = "https://your-backend.com/get-key",
        Method = "POST",
        Body = HttpService:JSONEncode({
            userId = LocalPlayer.UserId,
            username = LocalPlayer.Name
        })
    })
    
    local data = HttpService:JSONDecode(response.Body)
    return data.apiKey
end

-- Use the fetched key
local apiKey = getApiKey()
AuthLogger.Log(apiKey)
```

---

## 📊 Detection Examples

### Example 1: Multiple IPs (Account Sharing)

Player logs in from:
1. IP: `203.0.113.45` (Los Angeles)
2. IP: `198.51.100.89` (New York)
3. IP: `192.0.2.100` (London)
4. IP: `172.16.0.1` (Tokyo)

**Result:** 
- Alert triggered (4 IPs > 3 threshold)
- Discord notification sent
- Logged in Vercel

### Example 2: Impossible Travel

1. Login from Los Angeles (34.05°N, 118.24°W) at 10:00 AM
2. Login from Tokyo (35.68°N, 139.69°W) at 10:15 AM

**Calculation:**
- Distance: 8,800 km
- Time: 15 minutes
- Speed: 35,200 km/h (impossible!)

**Result:**
- CRITICAL alert triggered
- Immediate Discord notification
- Could auto-kick player

### Example 3: Concurrent Sessions

Same API key used simultaneously:
- Session 1: Active in Game Server #1
- Session 2: Active in Game Server #2
- Session 3: Active in Game Server #3

**Result:**
- Alert triggered (3 sessions > 2 threshold)
- All session IDs logged
- Suggests account sharing

---

## 🎨 Customization

### Add Custom Metadata

```lua
AuthLogger.Log(YOUR_API_KEY, {
    -- Built-in metadata
    placeId = game.PlaceId,
    displayName = LocalPlayer.DisplayName,
    
    -- Your custom data
    premiumStatus = LocalPlayer.MembershipType == Enum.MembershipType.Premium,
    teamName = LocalPlayer.Team and LocalPlayer.Team.Name or "None",
    gameVersion = "v2.3.1",
    customField = "any value you want"
})
```

This metadata will appear in Vercel logs!

### Periodic Re-Authentication

Track ongoing sessions by re-authenticating periodically:

```lua
-- In ClientAuthLogger.lua, uncomment this:
spawn(function()
    while task.wait(300) do -- Every 5 minutes
        AuthLogger.Log(YOUR_API_KEY, {
            periodic = true,
            timestamp = os.time()
        })
    end
end)
```

**Use cases:**
- Detect mid-session IP changes
- Ensure continuous session validity
- Track long play sessions

### Custom Alert Handling

Show alerts to the player in-game:

```lua
-- After authentication
local success, response = AuthLogger.Log(YOUR_API_KEY)

if success and response.alertCount > 0 then
    for _, alert in ipairs(response.alerts) do
        if alert.severity == "CRITICAL" then
            -- Show warning GUI to player
            showWarningGUI("Security Alert", "Suspicious activity detected on your account!")
            
            -- Or kick them
            LocalPlayer:Kick("Account security alert. Contact support.")
        end
    end
end
```

---

## 🧪 Testing

### Test 1: Normal Login
```lua
-- Run from command bar in Studio
local AuthLogger = require(game.StarterPlayer.StarterPlayerScripts.ClientAuthLogger)
AuthLogger.Log("test_key_123")
```

**Expected:**
- ✅ Success message in Output
- ✅ Log appears in Vercel
- ✅ Your studio/home IP captured

### Test 2: Multiple Players
1. Join with Account #1
2. Leave
3. Join with Account #2
4. Join with Account #3
5. Join with Account #4

**Expected:**
- Discord alert after 4th account (MULTIPLE_IPS)
- All usernames logged separately

### Test 3: Concurrent Sessions
1. Open 3 Roblox Studio windows
2. Use same API key in all 3
3. Click Play in all 3

**Expected:**
- Discord alert (CONCURRENT_SESSIONS)
- 3 session IDs listed

---

## 🐛 Troubleshooting

### "HttpService is not allowed to access ROBLOX resources"
**Fix:** You're trying to access Roblox APIs. Only use external URLs (Vercel).

### "HTTP requests are not enabled"
**Fix:** 
1. Game Settings → Security
2. ✅ Enable "Allow HTTP Requests"

### "Script doesn't run"
**Fix:** Make sure it's a **LocalScript** in one of these locations:
- `StarterPlayer.StarterPlayerScripts`
- `StarterGui`
- `StarterPack`

### "Same IP for all players"
**Fix:** You're running server-side. Client-side scripts capture each player's real IP.

### "API key is undefined"
**Fix:** Update the `YOUR_API_KEY` variable at the top of the script.

### No logs in Vercel
**Checklist:**
- [ ] LocalScript is in correct location
- [ ] HTTP requests enabled in game settings
- [ ] Vercel endpoint URL is correct
- [ ] Check Roblox Output window for errors
- [ ] Verify Vercel is deployed and running

---

## 📈 Advanced Features

### Rate Limiting Protection

Prevent abuse by limiting requests:

```lua
local lastAuthTime = 0
local AUTH_COOLDOWN = 60 -- seconds

function AuthLogger.Log(apiKey, metadata)
    local now = os.time()
    if now - lastAuthTime < AUTH_COOLDOWN then
        warn("[AuthLogger] Rate limited. Wait", AUTH_COOLDOWN - (now - lastAuthTime), "seconds")
        return false
    end
    
    lastAuthTime = now
    -- ... rest of auth code
end
```

### Offline Queueing

Queue requests if player has poor connection:

```lua
local requestQueue = {}

function AuthLogger.Log(apiKey, metadata)
    -- Try to send
    local success, response = pcall(function()
        return HttpService:RequestAsync({...})
    end)
    
    if not success then
        -- Queue for later
        table.insert(requestQueue, {
            apiKey = apiKey,
            metadata = metadata,
            timestamp = os.time()
        })
        
        -- Retry later
        task.delay(30, function()
            processQueue()
        end)
    end
end
```

### Location-Based Services

If you implement GPS/location detection:

```lua
-- Assuming you have a location API
local location = getPlayerLocation(LocalPlayer)

AuthLogger.Log(YOUR_API_KEY, {
    latitude = location.lat,
    longitude = location.lon
})
```

---

## 📝 Best Practices

1. **Always use LocalScript** - Never regular Script
2. **Enable Debug Mode** during development
3. **Disable Debug Mode** in production
4. **Monitor Vercel logs** regularly
5. **Set up Discord notifications** for critical alerts
6. **Test with multiple accounts** before release
7. **Consider API key security** based on your use case
8. **Implement rate limiting** to prevent abuse
9. **Handle errors gracefully** - don't crash the game
10. **Document your API keys** and keep them secure

---

## 🔗 Related Documentation

- `CLIENT_QUICKSTART.md` - Quick setup guide
- `LOGGING_EXAMPLE.md` - See what gets logged
- `DEPLOYMENT_README.md` - Vercel deployment guide
- `api/auth-log.js` - Backend code

---

## 📄 License

MIT License - Use freely in your projects!
