const express = require('express');
const WebSocket = require('ws');
const https = require('https');
const http = require('http');

const app = express();
const PORT = process.env.PORT || 3000;

// Configuration
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '8696394019:AAEN_9-u1gIly8O39WmTMJ9wuV_uBO7VfKg';
let CHAT_ID = process.env.TELEGRAM_CHAT_ID || '-5544970151'; // Group: Minh và Đạt
let THRESHOLDS = (process.env.THRESHOLDS || '10, 15, 20')
  .split(',')
  .map(s => parseFloat(s.trim()))
  .filter(n => !isNaN(n))
  .sort((a, b) => a - b);
let MIN_VOLUME = parseFloat(process.env.MIN_VOLUME || '5000000'); // 5M USDT

const BLACKLIST = new Set([
  'USDC', 'FDUSD', 'TUSD', 'DAI', 'USDP', 'USDE', 'USD1', 'USDS',
  'PYUSD', 'AEUR', 'BFUSD', 'XUSD', 'EUR', 'BUSD'
]);

// Memory state
const triggeredThresholds = new Map(); // symbol -> Set<number>
const recentAlerts = [];
let ws = null;
let reconnectTimer = null;
let lastWsMessageTime = Date.now();
let lastUpdateId = 0;
const startTime = Date.now();

// Warm-up flag: Khởi động 8 giây đầu tiên để đồng bộ các coin đã tăng sẵn trước đó mà KHÔNG spam telegram
let isWarmedUp = false;
setTimeout(() => {
  isWarmedUp = true;
  console.log(`[Warm-up] Initial market snapshot complete. Live alerting active!`);
  enqueueTelegramMessage(`🟢 *CoinPulse Bot 24/7 đã khởi động!*\n\n• Mốc cảnh báo: *${THRESHOLDS.map(t => `+${t}%`).join(', ')}*\n• Volume tối thiểu: *$${(MIN_VOLUME / 1e6).toFixed(1)}M USDT*\n• Hệ thống sẵn sàng theo dõi và bắn tín hiệu realtime.`);
}, 8000);

console.log(`[CoinPulse Cloud Bot] Initializing...`);
console.log(`[Config] Chat ID: ${CHAT_ID}`);
console.log(`[Config] Milestones: ${THRESHOLDS.map(t => `+${t}%`).join(', ')}`);
console.log(`[Config] Min Volume: $${(MIN_VOLUME / 1e6).toFixed(1)}M`);

// Telegram Message Queue to prevent 429 rate limit (Max 1 message per 1.2s)
const messageQueue = [];
let isQueueProcessing = false;

function enqueueTelegramMessage(text, targetChatId = null) {
  messageQueue.push({ text, targetChatId: targetChatId || CHAT_ID });
  processMessageQueue();
}

function processMessageQueue() {
  if (isQueueProcessing || messageQueue.length === 0) return;
  isQueueProcessing = true;

  const item = messageQueue.shift();
  sendTelegramHttpRequest(item.text, item.targetChatId, () => {
    // Delay 1.2 seconds before next message
    setTimeout(() => {
      isQueueProcessing = false;
      processMessageQueue();
    }, 1200);
  });
}

function sendTelegramHttpRequest(text, targetChatId, callback) {
  const data = JSON.stringify({
    chat_id: targetChatId,
    text: text,
    parse_mode: 'Markdown',
    disable_web_page_preview: false
  });

  const options = {
    hostname: 'api.telegram.org',
    port: 443,
    path: `/bot${BOT_TOKEN}/sendMessage`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data)
    }
  };

  const req = https.request(options, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
      if (res.statusCode !== 200) {
        console.error(`[Telegram Error] Status: ${res.statusCode}, Body: ${body}`);
      } else {
        console.log(`[Telegram] Sent successfully to ${targetChatId}`);
      }
      if (callback) callback();
    });
  });

  req.on('error', (e) => {
    console.error(`[Telegram Request Error]`, e.message);
    if (callback) callback();
  });

  req.write(data);
  req.end();
}

// Format numbers
function formatPrice(val) {
  if (val >= 1) return val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 4 });
  return val.toFixed(6);
}

function formatVolume(val) {
  if (val >= 1e9) return `$${(val / 1e9).toFixed(2)}B`;
  if (val >= 1e6) return `$${(val / 1e6).toFixed(2)}M`;
  return `$${(val / 1e3).toFixed(1)}K`;
}

function formatUptime(seconds) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (d > 0) return `${d} ngày ${h} giờ ${m} phút`;
  if (h > 0) return `${h} giờ ${m} phút ${s} giây`;
  return `${m} phút ${s} giây`;
}

// Evaluate ticker from Binance
function evaluateTicker(ticker) {
  const symbol = ticker.s; // e.g. BTCUSDT
  if (!symbol || !symbol.endsWith('USDT')) return;

  const baseAsset = symbol.slice(0, -4);
  if (BLACKLIST.has(baseAsset)) return;

  const openPrice = parseFloat(ticker.o);
  const currentPrice = parseFloat(ticker.c);
  const quoteVolume = parseFloat(ticker.q);

  if (openPrice <= 0 || quoteVolume < MIN_VOLUME) return;

  const percent = ((currentPrice - openPrice) / openPrice) * 100;

  if (!triggeredThresholds.has(symbol)) {
    triggeredThresholds.set(symbol, new Set());
  }
  const triggered = triggeredThresholds.get(symbol);

  for (const milestone of THRESHOLDS) {
    if (percent >= milestone) {
      if (!triggered.has(milestone)) {
        triggered.add(milestone);

        // Chỉ gửi cảnh báo sau khi warm-up xong (tránh spam 30 coin đã tăng từ trước)
        if (isWarmedUp) {
          const alertText = 
            `🚀 *${baseAsset}/USDT* chạm mốc *+${milestone.toFixed(0)}%*!\n\n` +
            `📈 Biến động 24H: *+${percent.toFixed(2)}%*\n` +
            `💰 Giá hiện tại: *$${formatPrice(currentPrice)}*\n` +
            `📊 Volume 24H: *${formatVolume(quoteVolume)}*\n\n` +
            `👉 [Mở biểu đồ CoinPulse](https://hoangminh199524-design.github.io/coinpulse/)`;

          console.log(`[ALERT] ${baseAsset}/USDT crossed +${milestone}% (+${percent.toFixed(2)}%)`);
          enqueueTelegramMessage(alertText);

          recentAlerts.unshift({
            symbol: baseAsset,
            milestone,
            percent: percent.toFixed(2),
            time: new Date().toISOString()
          });
          if (recentAlerts.length > 50) recentAlerts.pop();
        }
      }
    } else if (percent < milestone - 2.0 || percent < milestone * 0.9) {
      // Pullback reset: cho phép kích hoạt lại nếu giá hồi rồi tăng trở lại
      triggered.delete(milestone);
    }
  }
}

// Connect Binance miniTicker WebSocket
const WS_ENDPOINTS = [
  'wss://stream.binance.com/ws/!miniTicker@arr',
  'wss://data-stream.binance.vision/ws/!miniTicker@arr',
  'wss://stream.binance.com:9443/ws/!miniTicker@arr'
];
let wsIndex = 0;

function connectBinanceWs() {
  if (ws) {
    try { ws.terminate(); } catch (_) {}
    ws = null;
  }

  const endpoint = WS_ENDPOINTS[wsIndex];
  console.log(`[WebSocket] Connecting to ${endpoint}...`);

  ws = new WebSocket(endpoint);

  ws.on('open', () => {
    console.log(`[WebSocket] Connected to Binance Spot miniTicker stream! (${endpoint})`);
    lastWsMessageTime = Date.now();
  });

  ws.on('message', (data) => {
    lastWsMessageTime = Date.now();
    try {
      const tickers = JSON.parse(data);
      if (Array.isArray(tickers)) {
        for (const t of tickers) {
          evaluateTicker(t);
        }
      }
    } catch (err) {
      console.error(`[Parse Error]`, err.message);
    }
  });

  ws.on('error', (err) => {
    console.error(`[WebSocket Error] ${endpoint}:`, err.message);
  });

  ws.on('close', () => {
    console.log(`[WebSocket] Closed. Rotating host and reconnecting in 3s...`);
    wsIndex = (wsIndex + 1) % WS_ENDPOINTS.length;
    scheduleReconnect();
  });
}

function scheduleReconnect() {
  if (reconnectTimer) clearTimeout(reconnectTimer);
  reconnectTimer = setTimeout(connectBinanceWs, 3000);
}

// Watchdog: reconnect if no message received in 25s
setInterval(() => {
  if (Date.now() - lastWsMessageTime > 25000) {
    console.warn(`[Watchdog] No WS messages for 25s. Forcing reconnect...`);
    connectBinanceWs();
  }
}, 10000);

// Telegram Long Polling to receive commands directly from chat
function pollTelegramUpdates() {
  const url = `https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${lastUpdateId + 1}&timeout=20`;
  
  https.get(url, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
      try {
        const json = JSON.parse(body);
        if (json.ok && Array.isArray(json.result)) {
          for (const upd of json.result) {
            lastUpdateId = upd.update_id;
            handleTelegramUpdate(upd);
          }
        }
      } catch (e) {
        // ignore parse error
      }
      setTimeout(pollTelegramUpdates, 1000);
    });
  }).on('error', (err) => {
    setTimeout(pollTelegramUpdates, 5000);
  });
}

// Handle incoming Telegram commands
function handleTelegramUpdate(upd) {
  const msg = upd.message;
  if (!msg || !msg.text) return;

  const text = msg.text.trim();
  const chatId = msg.chat.id;

  // Lệnh /start hoặc /help
  if (text.startsWith('/start') || text.startsWith('/help')) {
    const helpMsg = 
      `👋 *Chào bạn! Đây là CoinPulse 24/7 Cloud Bot* 🤖\n\n` +
      `Bot tự động quét toàn bộ coin Spot Binance và bắn cảnh báo khi có coin pump!\n\n` +
      `📋 *Các lệnh điều khiển nhanh:*\n` +
      `• \`/status\` : Xem trạng thái hoạt động & cài đặt hiện tại\n` +
      `• \`/set 10, 15, 20\` : Đổi mốc % cảnh báo (ví dụ: 10, 15, 20%)\n` +
      `• \`/set 20\` : Chỉ cảnh báo mốc 20%\n` +
      `• \`/volume 5\` : Đổi Volume 24h tối thiểu (ví dụ: 5 = $5M USDT)\n` +
      `• \`/test\` : Bắn tin nhắn thử nghiệm kiểm tra kết nối\n\n` +
      `🌐 Web App: [CoinPulse Web](https://hoangminh199524-design.github.io/coinpulse/)`;
    enqueueTelegramMessage(helpMsg, chatId);
    return;
  }

  // Lệnh /status
  if (text.startsWith('/status')) {
    const uptimeSec = Math.floor((Date.now() - startTime) / 1000);
    const wsStatus = (ws && ws.readyState === WebSocket.OPEN) ? '🟢 Đang kết nối Realtime' : '🟡 Đang kết nối lại';
    const statusMsg =
      `📊 *TRẠNG THÁI COINPULSE BOT 24/7*\n\n` +
      `• *Hệ thống*: 🟢 Online trên Cloud\n` +
      `• *Binance WebSocket*: ${wsStatus}\n` +
      `• *Mốc cảnh báo*: *${THRESHOLDS.map(t => `+${t}%`).join(', ')}*\n` +
      `• *Volume tối thiểu*: *$${(MIN_VOLUME / 1e6).toFixed(1)}M USDT*\n` +
      `• *Thời gian chạy*: ${formatUptime(uptimeSec)}\n` +
      `• *Số coin đã cảnh báo*: ${recentAlerts.length} lần\n\n` +
      `💡 Gõ \`/set 10, 15, 20\` để đổi mốc cảnh báo bất cứ lúc nào!`;
    enqueueTelegramMessage(statusMsg, chatId);
    return;
  }

  // Lệnh /set hoặc /thresholds (VD: /set 10, 15, 20 hoặc /set 20)
  if (text.startsWith('/set') || text.startsWith('/thresholds')) {
    const rawArgs = text.replace(/^\/(set|thresholds)(@\w+)?/i, '').trim();
    if (!rawArgs) {
      enqueueTelegramMessage(`⚠️ Vui lòng nhập mốc %, ví dụ: \`/set 10, 15, 20\` hoặc \`/set 20\``, chatId);
      return;
    }
    const parts = rawArgs.replace(/,/g, ' ').split(/\s+/).map(s => parseFloat(s)).filter(n => !isNaN(n) && n > 0);
    if (parts.length === 0) {
      enqueueTelegramMessage(`❌ Mốc % không hợp lệ. Ví dụ đúng: \`/set 10, 15, 20\``, chatId);
      return;
    }
    parts.sort((a, b) => a - b);
    THRESHOLDS = parts;
    // Reset trigger map so new thresholds take immediate effect
    triggeredThresholds.clear();
    
    enqueueTelegramMessage(
      `✅ *Đã cập nhật mốc cảnh báo thành công!*\n\n` +
      `🎯 Các mốc mới: *${THRESHOLDS.map(t => `+${t}%`).join(', ')}*\n` +
      `Bot sẽ lập tức quét và bắn tín hiệu theo các mốc này.`,
      chatId
    );
    console.log(`[Config Update] THRESHOLDS changed to:`, THRESHOLDS);
    return;
  }

  // Lệnh /volume (VD: /volume 3 hoặc /volume 5)
  if (text.startsWith('/volume')) {
    const rawArgs = text.replace(/^\/volume(@\w+)?/i, '').trim();
    const val = parseFloat(rawArgs);
    if (isNaN(val) || val < 0) {
      enqueueTelegramMessage(`⚠️ Vui lòng nhập số triệu USDT, ví dụ: \`/volume 5\` (nghĩa là 5M USDT)`, chatId);
      return;
    }
    MIN_VOLUME = val * 1e6;
    enqueueTelegramMessage(
      `✅ *Đã cập nhật Volume tối thiểu: $${val.toFixed(1)}M USDT*`,
      chatId
    );
    console.log(`[Config Update] MIN_VOLUME changed to: $${val}M`);
    return;
  }

  // Lệnh /test
  if (text.startsWith('/test')) {
    enqueueTelegramMessage(
      `🔔 *Kiểm tra kết nối CoinPulse Bot thành công!*\n\n` +
      `• Mốc cảnh báo hiện tại: *${THRESHOLDS.map(t => `+${t}%`).join(', ')}*\n` +
      `• Volume tối thiểu: *$${(MIN_VOLUME / 1e6).toFixed(1)}M USDT*\n` +
      `• Cloud Server: Hoạt động bình thường 24/7.`,
      chatId
    );
    return;
  }
}

// Self-ping to prevent Free tier cloud hosts (Render/Koyeb) from sleeping
const selfUrl = process.env.SELF_URL || process.env.RENDER_EXTERNAL_URL;
if (selfUrl) {
  setInterval(() => {
    try {
      const client = selfUrl.startsWith('https') ? https : http;
      client.get(selfUrl, (res) => {
        // keep-alive ping success
      }).on('error', () => {});
    } catch (_) {}
  }, 10 * 60 * 1000); // 10 minutes
}

// Web Health check endpoint
app.get('/', (req, res) => {
  const uptimeSec = Math.floor((Date.now() - startTime) / 1000);
  res.json({
    status: 'online',
    service: 'CoinPulse 24/7 Cloud Monitor',
    trackedThresholds: THRESHOLDS.map(t => `+${t}%`),
    minVolume: `$${(MIN_VOLUME / 1e6).toFixed(1)}M`,
    telegramChatId: CHAT_ID,
    wsConnected: ws && ws.readyState === WebSocket.OPEN,
    uptime: formatUptime(uptimeSec),
    uptimeSeconds: uptimeSec,
    recentAlerts: recentAlerts.slice(0, 15)
  });
});

app.listen(PORT, () => {
  console.log(`[HTTP Server] Listening on port ${PORT}`);
  connectBinanceWs();
  pollTelegramUpdates();
});
