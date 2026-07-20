"use strict";
// ------------------------------------------------------------------
// Service worker — rend le jeu installable et jouable HORS-LIGNE.
//
// Stratégie « stale-while-revalidate » sur toutes les requêtes GET de même
// origine : on répond immédiatement depuis le cache (donc hors-ligne et
// instantané), tout en rafraîchissant le cache en arrière-plan depuis le
// réseau. Conséquence : une mise à jour du jeu apparaît au CHARGEMENT SUIVANT.
//
// Pour forcer un renouvellement complet (nouvelle version publiée), il suffit
// d'incrémenter CACHE_VERSION : l'ancien cache est purgé à l'activation.
// ------------------------------------------------------------------
const CACHE_VERSION = "station-v1";

// Coquille de l'app préchargée à l'installation : tout le nécessaire pour un
// premier lancement hors-ligne. Les fiches de gares non listées ici sont mises
// en cache à la volée dès leur premier chargement (voir le handler fetch).
const PRECACHE = [
  "station.html",
  "manifest.json",
  "css/station.css",
  "js/store.js",
  "js/catalog.js",
  "js/engine.js",
  "js/schedule.js",
  "js/render.js",
  "js/game.js",
  "js/hub.js",
  "js/main.js",
  "icons/icon-192.png",
  "icons/icon-512.png",
  "icons/apple-touch-icon.png",
  "data/stations/index.json"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then(cache => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE_VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const req = event.request;
  // On ne gère que la lecture de même origine (GET) : le reste passe au réseau.
  if (req.method !== "GET" || new URL(req.url).origin !== self.location.origin) return;

  event.respondWith(
    caches.open(CACHE_VERSION).then(cache =>
      cache.match(req).then(cached => {
        const network = fetch(req)
          .then(res => {
            if (res && res.ok) cache.put(req, res.clone()); // rafraîchit en fond
            return res;
          })
          .catch(() => cached ||
            // Hors-ligne et non caché : pour une navigation, on sert la page.
            (req.mode === "navigate" ? cache.match("station.html") : undefined));
        return cached || network; // cache d'abord, réseau en repli
      })
    )
  );
});
