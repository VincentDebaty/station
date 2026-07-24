"use strict";
// ------------------------------------------------------------------
// Persistance — SEUL fichier qui connaît le support de stockage.
//
// Le reste du jeu lit la progression en SYNCHRONE (getProgress, isUnlocked,
// getMuted) depuis un cache mémoire ; ce cache est la source de vérité en
// cours de partie. Le support réel (localStorage en navigateur, stockage
// natif Capacitor Preferences en app iOS/Android) est asynchrone : on le lit
// UNE fois au démarrage (loadStore, avant toute lecture de progression) et on
// y ré-écrit en « write-through » à chaque changement (fire-and-forget).
//
// Ainsi, passer au natif ne touche QUE makeBackend() — aucune autre ligne du
// jeu ne change. Le format sauvegardé est versionné : migrate() amène toute
// sauvegarde ancienne au schéma courant, pour ne jamais casser une partie
// après une mise à jour.
// ------------------------------------------------------------------
const SCHEMA_VERSION = 1;
const KEY_PROGRESS = "station-progress";
const KEY_MUTED = "station-muted";
const KEY_ONBOARDED = "station-onboarded"; // « le joueur a déjà appris le geste »

// --- Support de stockage : natif si Capacitor est présent, sinon
//     localStorage. Interface identique, asynchrone : read → string|null. ---
function makeBackend() {
  const cap = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Preferences;
  if (cap) {
    // @capacitor/preferences : durable (UserDefaults / SharedPreferences),
    // sauvegardé dans les backups, non purgeable par pression de stockage.
    return {
      async read(key) { const res = await cap.get({ key }); return res && res.value; },
      async write(key, str) { await cap.set({ key, value: str }); }
    };
  }
  // Repli navigateur (dev, et web pur). try/catch : mode privé Safari, etc.
  return {
    async read(key) { try { return localStorage.getItem(key); } catch (e) { return null; } },
    async write(key, str) { try { localStorage.setItem(key, str); } catch (e) { /* silencieux */ } }
  };
}
const _store = makeBackend();

// --- Caches mémoire : lus en synchrone par le jeu, hydratés par loadStore. ---
let _progress = { version: SCHEMA_VERSION, stations: {} };
let _muted = false;
let _onboarded = false;

// --- Migration : amène n'importe quel format vers le schéma courant. ---
function migrate(raw) {
  if (!raw || typeof raw !== "object") return { version: SCHEMA_VERSION, stations: {} };
  // v0 (héritage) : objet plat { id: {stars,bestDelay} }, sans champ version.
  if (raw.version == null) return { version: SCHEMA_VERSION, stations: raw };
  // Montées de version futures : enchaîner les transformations ici (v1→v2…).
  return { version: SCHEMA_VERSION, stations: raw.stations || {} };
}

// --- Chargement unique au démarrage, AVANT toute lecture de progression. ---
async function loadStore() {
  const [rawProg, rawMuted, rawOnboarded] = await Promise.all([
    _store.read(KEY_PROGRESS),
    _store.read(KEY_MUTED),
    _store.read(KEY_ONBOARDED)
  ]);
  let parsed = null;
  try { parsed = rawProg ? JSON.parse(rawProg) : null; } catch (e) { parsed = null; }
  _progress = migrate(parsed);
  _muted = rawMuted === "1";
  _onboarded = rawOnboarded === "1";
  // Si la sauvegarde n'était pas déjà au schéma courant, on la réécrit migrée.
  if (!parsed || parsed.version !== SCHEMA_VERSION) persistProgress();
}

function persistProgress() {
  _store.write(KEY_PROGRESS, JSON.stringify(_progress)); // fire-and-forget durable
}

// ------------------------------------------------------------------
// API progression — signatures inchangées pour le reste du jeu.
// getProgress() rend la table { id: {stars,bestDelay} } (comme avant).
// ------------------------------------------------------------------
function getProgress() { return _progress.stations; }
function saveResult(id, stars, delay) {
  const cur = _progress.stations[id] || { stars: 0, bestDelay: null };
  _progress.stations[id] = {
    stars: Math.max(cur.stars, stars),                                   // on ne garde que le meilleur score
    bestDelay: cur.bestDelay == null ? delay : Math.min(cur.bestDelay, delay)
  };
  persistProgress();
}

// ------------------------------------------------------------------
// API préférence « son coupé » — même support durable que la progression.
// ------------------------------------------------------------------
function getMuted() { return _muted; }
function setMuted(on) { _muted = !!on; _store.write(KEY_MUTED, _muted ? "1" : "0"); }

// ------------------------------------------------------------------
// API accueil premier service : le geste central (train → quai) n'est enseigné
// qu'une seule fois. Une fois le premier aiguillage réussi, on ne réaccueille
// plus jamais le joueur (même support durable que la progression).
// ------------------------------------------------------------------
function getOnboarded() { return _onboarded; }
function setOnboarded(on) { _onboarded = !!on; _store.write(KEY_ONBOARDED, _onboarded ? "1" : "0"); }
