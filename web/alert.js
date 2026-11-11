// Loud new-order alert: looping sound, vibration and a system notification.
// Browsers only allow sound after the user has touched the page once, so the
// audio is unlocked on the first tap.
window.dhAlert = (function () {
  var audio = null, unlocked = false;
  function ensure() {
    if (!audio) {
      audio = new Audio('sounds/alert.wav');
      audio.preload = 'auto';
      audio.loop = true;
      audio.volume = 1;
    }
    return audio;
  }
  function unlock() {
    if (unlocked) return;
    var a = ensure();
    a.muted = true;
    var p = a.play();
    if (p && p.then) {
      p.then(function () { a.pause(); a.currentTime = 0; a.muted = false; unlocked = true; })
       .catch(function () { a.muted = false; });
    }
  }
  document.addEventListener('pointerdown', unlock, true);
  document.addEventListener('keydown', unlock, true);

  // Push notifications (phone screen, even with the app closed).
  var swReady = null;
  if ('serviceWorker' in navigator) {
    swReady = navigator.serviceWorker.register('push_sw.js').then(function () {
      return navigator.serviceWorker.ready;
    }).catch(function () { return null; });
  }
  function b64ToBytes(b64) {
    var pad = '='.repeat((4 - b64.length % 4) % 4);
    var raw = atob((b64 + pad).replace(/-/g, '+').replace(/_/g, '/'));
    var out = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out;
  }
  function isIOS() { return /iphone|ipad|ipod/i.test(navigator.userAgent); }
  function standalone() {
    return window.navigator.standalone === true ||
      (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
  }
  function pushSupported() {
    return !!(swReady && 'PushManager' in window && 'Notification' in window);
  }
  return {
    play: function () {
      var a = ensure();
      a.muted = false; a.currentTime = 0;
      try { var p = a.play(); if (p && p.catch) p.catch(function () {}); } catch (e) {}
      try { if (navigator.vibrate) navigator.vibrate([500, 200, 500, 200, 900]); } catch (e) {}
    },
    stop: function () {
      if (audio) { audio.pause(); audio.currentTime = 0; }
      try { if (navigator.vibrate) navigator.vibrate(0); } catch (e) {}
    },
    permission: function () {
      return ('Notification' in window) ? Notification.permission : 'unsupported';
    },
    ask: function () {
      unlock();
      if ('Notification' in window && Notification.permission === 'default') {
        try { Notification.requestPermission(); } catch (e) {}
      }
    },
    // 'subscribed' | 'default' | 'granted' | 'denied' | 'ios-browser' | 'unsupported'
    pushStatus: function () {
      if (isIOS() && !standalone()) return Promise.resolve('ios-browser');
      if (!pushSupported()) return Promise.resolve('unsupported');
      if (Notification.permission === 'denied') return Promise.resolve('denied');
      return swReady.then(function (r) {
        if (!r) return 'unsupported';
        return r.pushManager.getSubscription().then(function (s) {
          return s ? 'subscribed' : Notification.permission;
        });
      }).catch(function () { return 'unsupported'; });
    },
    // Current subscription as JSON ('' when none).
    pushCurrent: function () {
      if (!pushSupported()) return Promise.resolve('');
      return swReady.then(function (r) {
        return r ? r.pushManager.getSubscription() : null;
      }).then(function (s) { return s ? JSON.stringify(s) : ''; }).catch(function () { return ''; });
    },
    // Must run straight from a tap: asks permission, then subscribes. Returns JSON or 'error:…'.
    pushSubscribe: function (key) {
      if (!pushSupported()) return Promise.resolve('error:unsupported');
      unlock();
      var ask = Notification.permission === 'granted'
        ? Promise.resolve('granted') : Notification.requestPermission();
      return ask.then(function (p) {
        if (p !== 'granted') return 'error:' + p;
        return swReady.then(function (r) {
          return r.pushManager.getSubscription().then(function (s) {
            return s || r.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ToBytes(key) });
          });
        }).then(function (s) { return JSON.stringify(s); });
      }).catch(function (e) { return 'error:' + (e && e.message ? e.message : e); });
    },
    notify: function (title, body) {
      if (!('Notification' in window) || Notification.permission !== 'granted') return;
      var opts = { body: body, icon: 'icons/Icon-192.png', badge: 'icons/Icon-192.png',
        tag: 'dhabaeh-order', renotify: true, requireInteraction: true,
        vibrate: [500, 200, 500, 200, 900] };
      try {
        if (navigator.serviceWorker && navigator.serviceWorker.getRegistration) {
          navigator.serviceWorker.getRegistration().then(function (r) {
            if (r) r.showNotification(title, opts); else new Notification(title, opts);
          }).catch(function () { try { new Notification(title, opts); } catch (e) {} });
        } else { new Notification(title, opts); }
      } catch (e) {}
    }
  };
})();
