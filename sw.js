/* PdBN — Service Worker (PWA installable + shell hors-ligne) */
const CACHE = 'pdbn-v1';
const SHELL = [
  './',
  'index.html',
  'membre.html',
  'reservation.html',
  'inscriptions.html',
  'paiement.html',
  'favicon.ico',
  'favicon-192.png',
  'icon-512.png',
  'apple-touch-icon.png',
  'manifest.json'
];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL).catch(()=>{})).then(()=>self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;                 // laisse passer POST/PATCH (Supabase)
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;  // Supabase / CDN : réseau direct
  // App shell : réseau d'abord, cache en secours (toujours la dernière version si en ligne)
  e.respondWith(
    fetch(req).then(res => {
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(req, copy)).catch(()=>{});
      return res;
    }).catch(() => caches.match(req).then(r => r || caches.match('index.html')))
  );
});
