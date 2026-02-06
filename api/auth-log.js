// Vercel Serverless Function for Auth Key Sharing Detection
// Endpoint: /api/auth-log

import fetch from 'node-fetch';

// Configuration - Set these in Vercel Environment Variables
const WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL || process.env.WEBHOOK_URL;
const MAX_IPS_PER_KEY = parseInt(process.env.MAX_IPS_PER_KEY || '3');
const MAX_CONCURRENT_SESSIONS = parseInt(process.env.MAX_CONCURRENT_SESSIONS || '2');
const SUSPICIOUS_DISTANCE_KM = parseInt(process.env.SUSPICIOUS_DISTANCE_KM || '500');
const IP_TRACKING_WINDOW = parseInt(process.env.IP_TRACKING_WINDOW || '3600'); // 1 hour in seconds

// In-memory storage (use Vercel KV for production persistence)
let keyData = {};

// Clean up old data
function cleanupOldData() {
    const now = Date.now();
    const cutoff = now - (IP_TRACKING_WINDOW * 1000);
    
    for (const key in keyData) {
        if (keyData[key].ipHistory) {
            keyData[key].ipHistory = keyData[key].ipHistory.filter(
                record => record.timestamp > cutoff
            );
        }
        if (keyData[key].locationHistory) {
            keyData[key].locationHistory = keyData[key].locationHistory.filter(
                record => record.timestamp > cutoff
            );
        }
    }
}

// Calculate distance between two lat/long coordinates (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in km
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

function toRad(degrees) {
    return degrees * (Math.PI / 180);
}

// Detect multiple IPs
function detectMultipleIPs(apiKey, ipAddress) {
    if (!keyData[apiKey]) {
        keyData[apiKey] = { ipHistory: [], locationHistory: [], sessions: {} };
    }
    
    const now = Date.now();
    keyData[apiKey].ipHistory.push({ ip: ipAddress, timestamp: now });
    
    // Get unique IPs
    const uniqueIPs = [...new Set(keyData[apiKey].ipHistory.map(r => r.ip))];
    
    if (uniqueIPs.length > MAX_IPS_PER_KEY) {
        return {
            detected: true,
            uniqueIPCount: uniqueIPs.length,
            ips: uniqueIPs,
            threshold: MAX_IPS_PER_KEY
        };
    }
    
    return { detected: false };
}

// Detect concurrent sessions
function detectConcurrentSessions(apiKey, sessionId) {
    if (!keyData[apiKey]) {
        keyData[apiKey] = { ipHistory: [], locationHistory: [], sessions: {} };
    }
    
    keyData[apiKey].sessions[sessionId] = { started: Date.now() };
    
    const activeCount = Object.keys(keyData[apiKey].sessions).length;
    
    if (activeCount > MAX_CONCURRENT_SESSIONS) {
        return {
            detected: true,
            concurrentSessions: activeCount,
            threshold: MAX_CONCURRENT_SESSIONS,
            sessionIds: Object.keys(keyData[apiKey].sessions)
        };
    }
    
    return { detected: false };
}

// Detect impossible travel
function detectImpossibleTravel(apiKey, currentLocation) {
    if (!keyData[apiKey]) {
        keyData[apiKey] = { ipHistory: [], locationHistory: [], sessions: {} };
    }
    
    const history = keyData[apiKey].locationHistory || [];
    
    if (history.length > 0) {
        const lastLocation = history[history.length - 1];
        const timeDiff = (Date.now() - lastLocation.timestamp) / 1000; // seconds
        
        if (timeDiff < IP_TRACKING_WINDOW) {
            const distance = calculateDistance(
                lastLocation.latitude,
                lastLocation.longitude,
                currentLocation.latitude,
                currentLocation.longitude
            );
            
            const hours = timeDiff / 3600;
            const speedKmh = distance / hours;
            
            // 800 km/h is faster than commercial flights
            if (distance > SUSPICIOUS_DISTANCE_KM && speedKmh > 800) {
                return {
                    detected: true,
                    previousLocation: lastLocation,
                    currentLocation: currentLocation,
                    distanceKm: Math.round(distance),
                    timeSeconds: Math.round(timeDiff),
                    speedKmh: Math.round(speedKmh)
                };
            }
        }
    }
    
    // Add to location history
    keyData[apiKey].locationHistory.push({
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        timestamp: Date.now(),
        ip: currentLocation.ip
    });
    
    return { detected: false };
}

// Send webhook notification
async function sendWebhook(alert, eventData, executionIP) {
    if (!WEBHOOK_URL) {
        console.log('No webhook URL configured');
        return;
    }
    
    // Add executionIP to eventData for webhook
    const webhookData = {
        ...eventData,
        executionIP: executionIP
    };
    
    const embed = createDiscordEmbed(alert, webhookData);
    
    try {
        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(embed)
        });
        
        if (!response.ok) {
            console.error('Webhook failed:', response.status);
        }
    } catch (error) {
        console.error('Webhook error:', error);
    }
}

// Create Discord embed
function createDiscordEmbed(alert, eventData) {
    const colors = {
        WARNING: 0xFFA500,   // Orange
        ALERT: 0xFF4500,     // Red-Orange
        CRITICAL: 0xFF0000   // Red
    };
    
    const embed = {
        embeds: [{
            title: `🚨 ${alert.type.replace(/_/g, ' ')} Detected`,
            color: colors[alert.severity] || 0xFFFF00,
            description: `**Username:** ${eventData.username || 'Unknown'}\n**User ID:** ${eventData.userId || 'Unknown'}`,
            fields: [
                {
                    name: '🔑 API Key',
                    value: `\`${eventData.apiKey}\``,
                    inline: false
                },
                {
                    name: '🌐 IP Address (Execution)',
                    value: `\`${eventData.executionIP || eventData.ipAddress}\``,
                    inline: true
                },
                {
                    name: '⚠️ Severity',
                    value: alert.severity,
                    inline: true
                }
            ],
            timestamp: new Date().toISOString(),
            footer: {
                text: 'Auth Security Monitor'
            }
        }]
    };
    
    // Add alert-specific fields
    if (alert.type === 'MULTIPLE_IPS') {
        embed.embeds[0].fields.push({
            name: '📊 Unique IPs Detected',
            value: `${alert.data.uniqueIPCount} / ${alert.data.threshold} max`,
            inline: false
        });
        embed.embeds[0].fields.push({
            name: '📍 All IP Addresses',
            value: '```\n' + alert.data.ips.join('\n') + '\n```',
            inline: false
        });
    } else if (alert.type === 'CONCURRENT_SESSIONS') {
        embed.embeds[0].fields.push({
            name: '🔄 Active Sessions',
            value: `${alert.data.concurrentSessions} / ${alert.data.threshold} max`,
            inline: false
        });
        embed.embeds[0].fields.push({
            name: '🎫 Session IDs',
            value: '```\n' + alert.data.sessionIds.slice(0, 5).join('\n') + (alert.data.sessionIds.length > 5 ? '\n...' : '') + '\n```',
            inline: false
        });
    } else if (alert.type === 'IMPOSSIBLE_TRAVEL') {
        embed.embeds[0].fields.push({
            name: '✈️ Impossible Travel Details',
            value: `📏 **Distance:** ${alert.data.distanceKm} km\n⏱️ **Time:** ${Math.round(alert.data.timeSeconds / 60)} minutes\n🚀 **Speed:** ${alert.data.speedKmh} km/h`,
            inline: false
        });
    }
    
    return embed;
}

// Main handler
export default async function handler(req, res) {
    // CORS headers for Roblox
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }
    
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }
    
    try {
        const eventData = req.body;
        
        // Get the real IP address from the request
        const requestIP = req.headers['x-forwarded-for'] || 
                         req.headers['x-real-ip'] || 
                         req.connection?.remoteAddress || 
                         'unknown';
        
        // Extract the first IP if there are multiple (from proxies)
        const executionIP = requestIP.split(',')[0].trim();
        
        // Validate required fields
        if (!eventData.apiKey || !eventData.sessionId) {
            return res.status(400).json({
                error: 'Missing required fields: apiKey, sessionId'
            });
        }
        
        // Use provided IP or fallback to execution IP
        const ipAddress = eventData.ipAddress || executionIP;
        
        // Build full log entry with ALL data
        const fullLogEntry = {
            timestamp: new Date().toISOString(),
            event: 'auth_attempt',
            // FULL API KEY (NOT HASHED)
            apiKey: eventData.apiKey,
            // USERNAME
            username: eventData.username || 'unknown',
            // USER ID
            userId: eventData.userId || 'unknown',
            // IP ADDRESS FROM REQUEST
            ipAddress: ipAddress,
            // EXECUTION IP (the IP that made the request to Vercel)
            executionIP: executionIP,
            // SESSION INFO
            sessionId: eventData.sessionId,
            // ADDITIONAL DATA
            userAgent: req.headers['user-agent'] || 'unknown',
            metadata: eventData.metadata || {},
            location: eventData.latitude && eventData.longitude ? {
                latitude: eventData.latitude,
                longitude: eventData.longitude
            } : null
        };
        
        // Log FULL string to Vercel logs (visible in dashboard)
        console.log('=== AUTH EVENT LOG START ===');
        console.log(JSON.stringify(fullLogEntry, null, 2));
        console.log('=== AUTH EVENT LOG END ===');
        
        // Clean up old data
        cleanupOldData();
        
        const alerts = [];
        
        // Detection 1: Multiple IPs
        const multiIPResult = detectMultipleIPs(eventData.apiKey, ipAddress);
        if (multiIPResult.detected) {
            const alert = {
                type: 'MULTIPLE_IPS',
                severity: 'WARNING',
                data: multiIPResult
            };
            alerts.push(alert);
            await sendWebhook(alert, eventData, executionIP);
        }
        
        // Detection 2: Concurrent sessions
        const concurrentResult = detectConcurrentSessions(eventData.apiKey, eventData.sessionId);
        if (concurrentResult.detected) {
            const alert = {
                type: 'CONCURRENT_SESSIONS',
                severity: 'ALERT',
                data: concurrentResult
            };
            alerts.push(alert);
            await sendWebhook(alert, eventData, executionIP);
        }
        
        // Detection 3: Impossible travel (if location provided)
        if (eventData.latitude && eventData.longitude) {
            const travelResult = detectImpossibleTravel(eventData.apiKey, {
                latitude: eventData.latitude,
                longitude: eventData.longitude,
                ip: ipAddress
            });
            
            if (travelResult.detected) {
                const alert = {
                    type: 'IMPOSSIBLE_TRAVEL',
                    severity: 'CRITICAL',
                    data: travelResult
                };
                alerts.push(alert);
                await sendWebhook(alert, eventData, executionIP);
            }
        }
        
        // Log alerts if any
        if (alerts.length > 0) {
            console.log('⚠️ ALERTS DETECTED:', JSON.stringify({
                apiKey: eventData.apiKey,
                username: eventData.username,
                alertCount: alerts.length,
                alerts: alerts
            }, null, 2));
        }
        
        // Return response
        return res.status(200).json({
            success: true,
            logged: true,
            alertCount: alerts.length,
            alerts: alerts,
            executionIP: executionIP,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('Error processing auth event:', error);
        return res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
}
