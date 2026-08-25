"use strict";
// ------------------------------------------------------------------
// Service worker — rend le jeu installable et jouable HORS-LIGNE.
//
// Stratégie « réseau d'abord » (network-first) sur toutes les requêtes GET de
// même origine : en ligne, on sert TOUJOURS la version fraîche du réseau (et on
// la remet en cache) ; hors-ligne (ou réseau en échec), on sert le cache. Une
// mise à jour du jeu apparaît donc IMMÉDIATEMENT au rechargement, sans passer par
// une version périmée — indispensable en développement actif.
//
// La coquille est toujours préchargée à l'installation pour un premier lancement
// hors-ligne. Incrémenter CACHE_VERSION purge l'ancien cache à l'activation.
// ------------------------------------------------------------------
const CACHE_VERSION = "station-v98";

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
  "js/gen-worker.js",
  "js/render.js",
  "js/game.js",
  "data/places.js",
  "data/lines.js",
  "data/worldmap.js",
  "data/cartes/index.json",
  "data/cartes/europe.json",
  "js/cartes.js",
  "js/geo.js",
  "js/ruban.js",
  "js/network.js",
  "js/recompense.js",
  "js/parcours.js",
  "js/hub.js",
  "js/main.js",
  "icons/icon-192.png",
  "icons/icon-512.png",
  "icons/apple-touch-icon.png",
  "data/stations/index.json"
];

// UN FICHIER MANQUANT NE DOIT PLUS COÛTER TOUT LE CACHE. `cache.addAll` est
// atomique : une seule URL en 404 rejette la promesse entière, l'installation
// échoue, et le jeu perd le hors-ligne SANS LE MOINDRE SIGNE — la page marche
// très bien en ligne. C'est exactement ce qui venait d'arriver : la liste
// nommait encore js/map.js et js/mapnet.js, supprimés avec l'ancienne carte.
//
// On met donc chaque fichier en cache SÉPARÉMENT, et l'on n'échoue plus sur un
// absent : la coquille est préchargée au mieux, et le handler fetch rattrapera
// le reste au premier passage en ligne. La liste reste à tenir à jour — mais
// l'oublier ne casse plus rien de silencieux.
self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then(cache => Promise.all(PRECACHE.map(url =>
        cache.add(url).catch(() => { /* absent ou hors-ligne : tant pis, pas fatal */ }))))
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

  // « Réseau d'abord » ne suffit pas : `fetch()` passe par le cache HTTP du
  // navigateur, qui peut resservir un fichier périmé sans même revalider (pas
  // d'en-tête Cache-Control sur un serveur de développement ⇒ fraîcheur
  // heuristique). On s'est ainsi retrouvé avec un engine.js d'hier face à un
  // game.js du jour : « Can't find variable: FREIGHT_COLOR », plan vide sur
  // iPhone. `cache: "no-cache"` force la revalidation (304 si rien n'a bougé,
  // donc quasi gratuit). Le mode "navigate" est exclu : un Request de
  // navigation ne peut pas être reconstruit (TypeError).
  let netReq = req;
  if (req.mode !== "navigate") {
    try { netReq = new Request(req, { cache: "no-cache" }); } catch (e) { netReq = req; }
  }

  event.respondWith(
    caches.open(CACHE_VERSION).then(cache =>
      fetch(netReq)
        .then(res => {
          if (res && res.ok) cache.put(req, res.clone()); // met à jour le cache
          return res;
        })
        // Réseau indisponible : on retombe sur le cache (jeu jouable hors-ligne).
        // On renvoie TOUJOURS une Response — jamais undefined, sinon le navigateur
        // lève « Failed to convert value to 'Response' » (ex. favicon.ico absent).
        .catch(async () => {
          const cached = await cache.match(req);
          if (cached) return cached;
          if (req.mode === "navigate") {
            const shell = await cache.match("station.html");
            if (shell) return shell;
          }
          return new Response("", { status: 504, statusText: "Ressource indisponible hors-ligne" });
        })
    )
  );
});
