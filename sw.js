// Bridge Waters service worker.
// Keeps the app shell (pages, logo, icons) so the portal opens instantly and
// still shows its screen when the connection drops. Business data is NEVER cached
// here: calls to Supabase always go straight to the network.
const CACHE = 'bw-shell-v2';
const SHELL = [
  './', './index.html', './events.html', './manifest.webmanifest',
  './assets/logo.png', './assets/logo-white.png', './assets/icon-192.png', './assets/icon-512.png'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;          // fonts/CDN/Supabase: browser handles it

  // Pages: network first so a new deploy shows up straight away; cache if offline
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
        return res;
      }).catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
    );
    return;
  }

  // Images/manifest: cache first, refresh in the background
  e.respondWith(
    caches.match(req).then(hit => {
      const net = fetch(req).then(res => {
        if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
        return res;
      }).catch(() => hit);
      return hit || net;
    })
  );
});
