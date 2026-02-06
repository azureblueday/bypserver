# ⚡ Client-Side Setup Guide

Get your client-side auth logger running in 10 minutes! The **client makes the request directly to Vercel**, so Vercel captures the **real player IP address**.

## How It Works

```
Player's Computer (Client)
    ↓ (makes HTTP request)
Vercel Server
    ↓ (captures real IP: 203.0.113.45)
Logs IP + Username + API Key
    ↓
Sends alert to Discord
```

## Step-by-Step Setup

### 1️⃣ Create Discord Webhook (2 min)

1. Open Discord → Your Server → Server Settings
2. Integrations → Webhooks → New Webhook
3. Copy the webhook URL
4. **Save it** - you'll need this!

### 2️⃣ Deploy to Vercel (3 min)

1. Create new GitHub repo
2. Upload these files:
   - `api/auth-log.js`
   - `api/end-session.js`
   - `package.json`
   - `vercel.json`
   - `.gitignore`

3. Go to [vercel.com](https://vercel.com)
4. Click "Add New Project"
5. Import your GitHub repo
6. Add this environment variable:
   ```
   DISCORD_WEBHOOK_URL = paste-your-webhook-url-here
   ```
7. Click "Deploy"
8. **Copy your Vercel URL** (looks like `https://your-app.vercel.app`)

### 3️⃣ Setup Roblox Game (3 min)

1. **Roblox Game Settings → Security**
2. ✅ Enable "Allow HTTP Requests"
3. ✅ Enable "Enable Studio Access to API Services"

### 4️⃣ Add Client Script (2 min)

**Option A: Simple Auto-Login**

1. In Roblox Studio: `StarterPlayer` → `StarterPlayerScripts`
2. Create a new **LocalScript** (NOT Script)
3. Paste the contents of `ClientAuthLogger.lua`
4. Update these lines:
   ```lua
   local VERCEL_ENDPOINT = "https://your-app.vercel.app" -- Your Vercel URL
   local YOUR_API_KEY = "your-api-key-here" -- Your API key
   ```

**Option B: GUI-Based Login**

1. In Roblox Studio: `StarterPlayer` → `StarterPlayerScripts`
2. Create a new **LocalScript**
3. Paste the contents of `ClientAuthSystem.lua`
4. Update the Vercel endpoint:
   ```lua
   local VERCEL_ENDPOINT = "https://your-app.vercel.app"
   ```
5. At the bottom, choose which method to use:
   ```lua
   -- For auto-login:
   autoLogin()
   
   -- OR for GUI login:
   setupLoginGUI()
   ```

### 5️⃣ Test It! (2 min)

1. Click "Play" in Roblox Studio
2. Check the Output window (View → Output)
3. You should see:
   ```
   [AuthLogger] ✅ Logged successfully!
     Your IP: 203.0.113.45
   ```
4. Check Discord - you should see the log!
5. Check Vercel dashboard → Functions → View logs

---

## That's It! 🎉

Your game now logs auth events from the **client side** and captures **real player IPs**!

### What Gets Logged:

✅ **Real Player IP** - Captured automatically by Vercel  
✅ **Username** - Player's Roblox username  
✅ **User ID** - Roblox UserId  
✅ **Full API Key** - Complete string (unhashed)  
✅ **Timestamp** - Exact time of authentication  

### Example Vercel Log:
```json
{
  "timestamp": "2026-02-05T15:30:45.123Z",
  "apiKey": "sk_prod_abc123xyz789",
  "username": "CoolPlayer123",
  "userId": "987654321",
  "executionIP": "203.0.113.45",  ← REAL PLAYER IP!
  "sessionId": "client_abc_987654321_1738771845"
}
```

### Example Discord Alert:
```
🚨 MULTIPLE IPS Detected

Username: CoolPlayer123
User ID: 987654321

🔑 API Key
sk_prod_abc123xyz789

🌐 IP Address (Execution)
203.0.113.45  ← REAL PLAYER IP!
```

---

## Common Issues

**"HTTP 403 (Forbidden)"**
- Make sure "Allow HTTP Requests" is enabled in Game Settings → Security

**"API endpoint not set"**
- Check that you updated `VERCEL_ENDPOINT` in the script

**"No logs in Vercel"**
- Make sure the LocalScript is in `StarterPlayerScripts` (not ServerScriptStorage)
- Check the Output window in Roblox Studio for errors

**"Script runs on server instead of client"**
- Use **LocalScript**, NOT regular Script
- LocalScripts only run in:
  - StarterPlayerScripts
  - StarterCharacterScripts
  - StarterGui
  - Player's Backpack
  - Player's Character

---

## Why Client-Side?

**Server-Side Request:**
- IP captured = Roblox server IP (always the same)
- Can't detect real player locations
- Can't track individual players properly

**Client-Side Request:**
- IP captured = Real player's IP address
- Can detect impossible travel
- Can track actual player locations
- Better security detection

---

## Next Steps

✅ Test with multiple accounts to trigger alerts  
✅ Customize the detection thresholds in Vercel  
✅ Add custom metadata to track additional info  
✅ Set up periodic re-authentication (optional)  
✅ Build a custom login GUI for your game  

**Need help?** Check `CLIENT_SIDE_README.md` for full documentation!
