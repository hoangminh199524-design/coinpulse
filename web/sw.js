'use strict';

self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function(event) {
  let payload = {
    title: '⚡ CoinPulse',
    body: 'Biến động thị trường Binance Spot mới!',
    url: './'
  };

  if (event.data) {
    try {
      payload = event.data.json();
    } catch (_) {
      payload.body = event.data.text();
    }
  }

  const title = payload.title || '⚡ CoinPulse';
  const options = {
    body: payload.body || 'Coin bùng nổ tăng trưởng!',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    vibrate: [200, 100, 200, 100, 200],
    data: {
      url: payload.url || './'
    },
    tag: 'alert_' + Date.now(),
    renotify: true,
    silent: false,
    requireInteraction: false
  };

  event.waitUntil(
    self.registration.showNotification(title, options).then(function() {
      if ('setAppBadge' in navigator) {
        return navigator.setAppBadge();
      }
    }).catch(function(err) {
      console.error('[SW showNotification error]', err);
    })
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  if ('clearAppBadge' in navigator) {
    navigator.clearAppBadge().catch(function() {});
  }
  const targetUrl = (event.notification.data && event.notification.data.url)
    ? event.notification.data.url
    : './';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (let client of clientList) {
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
