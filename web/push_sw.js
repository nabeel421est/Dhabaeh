// Service worker for push notifications (shows them on the phone's screen even
// when the app is closed) and for opening the app when one is tapped.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });

self.addEventListener('push', function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { body: e.data ? e.data.text() : '' }; }
  var title = d.title || 'ذبائح البحرين';
  var opts = {
    body: d.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: d.tag || undefined,
    renotify: !!d.tag,
    requireInteraction: !!d.loud,
    vibrate: d.loud ? [500, 200, 500, 200, 900] : [200],
    dir: 'rtl',
    lang: 'ar',
    data: { url: d.url || './' }
  };
  e.waitUntil(Promise.all([
    self.registration.showNotification(title, opts),
    // An open app rings its own loud alert too.
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (cs) {
      cs.forEach(function (c) { c.postMessage({ type: 'dh-push', loud: !!d.loud }); });
    })
  ]));
});

self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var url = (e.notification.data && e.notification.data.url) || './';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (cs) {
    for (var i = 0; i < cs.length; i++) { if ('focus' in cs[i]) return cs[i].focus(); }
    return self.clients.openWindow(url);
  }));
});
