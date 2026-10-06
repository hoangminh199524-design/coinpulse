'use strict';

window.CoinPulsePush = {
  SERVER_URL: 'https://coinpulse-bot.onrender.com',

  isSupported: function() {
    return ('serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window);
  },

  getPermission: function() {
    if (!('Notification' in window)) return 'unsupported';
    return Notification.permission;
  },

  isSubscribed: async function() {
    if (!this.isSupported()) return false;
    try {
      if (Notification.permission !== 'granted') {
        localStorage.removeItem('coinpulse_push_subscribed');
        return false;
      }
      var regs = await navigator.serviceWorker.getRegistrations();
      for (var reg of regs) {
        if (reg.pushManager) {
          var sub = await reg.pushManager.getSubscription();
          if (sub) {
            localStorage.setItem('coinpulse_push_subscribed', 'true');
            return true;
          }
        }
      }
      return localStorage.getItem('coinpulse_push_subscribed') === 'true';
    } catch (_) {
      return false;
    }
  },

  urlB64ToUint8Array: function(base64String) {
    var padding = '='.repeat((4 - base64String.length % 4) % 4);
    var base64 = (base64String + padding).replace(/\-/g, '+').replace(/_/g, '/');
    var rawData = window.atob(base64);
    var outputArray = new Uint8Array(rawData.length);
    for (var i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  },

  subscribe: async function() {
    if (!this.isSupported()) {
      return { success: false, error: 'Thiết bị chưa hỗ trợ Web Push. Vui lòng mở bằng Safari và chọn "Thêm vào MH chính" (Add to Home Screen) trên iOS 16.4+.' };
    }

    var perm = await Notification.requestPermission();
    if (perm !== 'granted') {
      localStorage.removeItem('coinpulse_push_subscribed');
      return { success: false, error: 'Chưa cấp quyền thông báo. Vui lòng vào Cài đặt iPhone > Thông báo > CoinPulse để Cho phép thông báo.' };
    }

    try {
      var reg = await navigator.serviceWorker.register('sw.js?v=20261006_V2');
      await navigator.serviceWorker.ready;

      var keyRes = await fetch(this.SERVER_URL + '/api/vapid-public-key');
      var keyData = await keyRes.json();
      var applicationServerKey = this.urlB64ToUint8Array(keyData.publicKey);

      var subscription = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: applicationServerKey
      });

      var subRes = await fetch(this.SERVER_URL + '/api/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(subscription)
      });
      var resData = await subRes.json();
      localStorage.setItem('coinpulse_push_subscribed', 'true');
      return { success: true, count: resData.count };
    } catch (err) {
      console.error('[WebPush Error]', err);
      return { success: false, error: err.message };
    }
  },

  unsubscribe: async function() {
    if (!this.isSupported()) return { success: false };
    try {
      localStorage.removeItem('coinpulse_push_subscribed');
      var regs = await navigator.serviceWorker.getRegistrations();
      for (var reg of regs) {
        if (reg.pushManager) {
          var sub = await reg.pushManager.getSubscription();
          if (sub) {
            try {
              await fetch(this.SERVER_URL + '/api/unsubscribe', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ endpoint: sub.endpoint })
              });
            } catch (_) {}
            await sub.unsubscribe();
          }
        }
      }
      return { success: true };
    } catch (err) {
      return { success: false, error: err.message };
    }
  },

  testPush: async function() {
    try {
      var res = await fetch(this.SERVER_URL + '/api/test-push', { method: 'POST' });
      return await res.json();
    } catch (err) {
      return { success: false, error: err.message };
    }
  }
};
