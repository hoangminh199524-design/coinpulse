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
      var regs = await navigator.serviceWorker.getRegistrations();
      for (var reg of regs) {
        if (reg.active && reg.active.scriptURL.includes('sw.js')) {
          var sub = await reg.pushManager.getSubscription();
          if (sub) return true;
        }
      }
      var reg = await navigator.serviceWorker.getRegistration();
      if (!reg) return false;
      var sub = await reg.pushManager.getSubscription();
      return sub !== null;
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
      return { success: false, error: 'Thiết bị chưa hỗ trợ Web Push (yêu cầu thêm vào Màn hình chính trên iOS 16.4+).' };
    }

    var perm = await Notification.requestPermission();
    if (perm !== 'granted') {
      return { success: false, error: 'Chưa cấp quyền thông báo (' + perm + ').' };
    }

    try {
      var reg = await navigator.serviceWorker.register('sw.js?v=20261006_V1');
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
      return { success: true, count: resData.count };
    } catch (err) {
      console.error('[WebPush Error]', err);
      return { success: false, error: err.message };
    }
  },

  unsubscribe: async function() {
    if (!this.isSupported()) return { success: false };
    try {
      var regs = await navigator.serviceWorker.getRegistrations();
      for (var reg of regs) {
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
