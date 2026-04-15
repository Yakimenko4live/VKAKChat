// Service Worker для PWA уведомлений
const CACHE_NAME = 'vkak-chat-v1';

self.addEventListener('install', (event) => {
  console.log('Service Worker installed');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('Service Worker activated');
  event.waitUntil(clients.claim());
});

// Обработка push-уведомлений
self.addEventListener('push', (event) => {
  console.log('Push received:', event);
  
  let data = {};
  try {
    data = event.data.json();
  } catch (e) {
    data = {
      title: 'Новое сообщение',
      body: 'У вас новое сообщение',
      icon: '/icons/icon-192.png',
      badge: '/icons/icon-192.png',
      data: {
        url: '/',
        chat_id: null
      }
    };
  }
  
  const options = {
    body: data.body || 'У вас новое сообщение',
    icon: data.icon || '/icons/icon-192.png',
    badge: data.badge || '/icons/icon-192.png',
    vibrate: [200, 100, 200],
    data: {
      url: data.data?.url || '/',
      chat_id: data.data?.chat_id || null
    },
    actions: [
      {
        action: 'open',
        title: 'Открыть'
      }
    ]
  };
  
  event.waitUntil(
    self.registration.showNotification(data.title || 'VKAK Chat', options)
  );
});

// Обработка клика по уведомлению
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  const urlToOpen = event.notification.data?.url || '/';
  const chatId = event.notification.data?.chat_id;
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Если уже есть открытое окно, переключаемся на него
        for (const client of clientList) {
          if (client.url.includes(window.location.origin) && 'focus' in client) {
            client.postMessage({
              type: 'notification_click',
              chat_id: chatId
            });
            return client.focus();
          }
        }
        // Иначе открываем новое окно
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});