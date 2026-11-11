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
