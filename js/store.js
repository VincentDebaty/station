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
const SCHEMA_VERSION = 5;
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
let _progress = { version: SCHEMA_VERSION, stations: {}, bought: [] };
let _muted = false;
let _onboarded = false;

// Dotation de départ : elle appartient à l'économie (js/catalog.js), pas au
// stockage. Lue au moment de la migration, donc après le chargement de tous les
// scripts — le repli ne sert qu'à ne jamais rendre une partie injouable.

// --- Migration : amène n'importe quel format vers le schéma courant. ---
function migrate(raw) {
  // Étape 1 : ramener toute sauvegarde ancienne à la forme v2
  // { stations, opened }, qui est le plus petit dénominateur commun.
  let stations = {}, opened = [];
  if (raw && typeof raw === "object") {
    // v0 (héritage) : objet plat { id: {stars,bestDelay} }, sans champ version.
    if (raw.version == null) stations = raw;
    else { stations = raw.stations || {}; opened = raw.opened || []; }
  }
  // Déjà en v5 : rien à déduire, on reprend tel quel.
  if (raw && raw.version === 5)
    return { version: 5, stations, bought: raw.bought || [] };
  // v4 → v5 : LES CRÉDITS ET LA PONCTUALITÉ DISPARAISSENT, et le joueur ne perd
  // rien. Ce qu'il avait acquis, ce sont ses GARES et ses RECORDS — les deux
  // sont conservés tels quels. Le solde ne servait qu'à ouvrir des gares, et
  // l'on n'en a plus besoin ; le compteur de ponctualité doublait ce que les
  // étoiles disent déjà, et le grade se relit désormais sur elles.
  //
  // Une gare payée reste ouverte : `bought` passe intact. C'est la seule chose
  // qui compte, et c'est ce qui rend la migration sans risque.
  if (raw && raw.version === 4)
    return { version: 5, stations, bought: raw.bought || [] };
  if (raw && raw.version === 3)
    return { version: 5, stations, bought: raw.bought || [] };

  // Étape 2 : v2 → v3. Le joueur ne perd RIEN et ne reçoit RIEN d'immérité.
  //
  // Les gares POSSÉDÉES sont celles qu'il avait ouvertes, plus toutes celles
  // qu'il a déjà jouées : avant la monnaie, les gares faciles étaient des
  // portes d'entrée jouables sans figurer dans « opened ». Sans cette union,
  // une gare décrochée se serait retrouvée à racheter.
  //
  // Le solde repart à zéro : son réseau est déjà payé. Ce qu'il a encaissé sur
  // chaque gare n'a pas à être mémorisé — il se déduit de son record
  // (stationBanked, js/catalog.js), donc rejouer au même niveau ne rapportera
  // rien, exactement comme s'il avait toujours joué avec la monnaie.
  const bought = opened.slice();
  for (const id in stations)
    if (((stations[id] || {}).stars || 0) >= 1 && bought.indexOf(id) < 0) bought.push(id);
  // Partie neuve (ou sauvegarde vide) : la dotation de départ, sans quoi il n'y
  // aurait pas de quoi ouvrir la première gare.
  return {
    version: 5,
    // Sauvegarde antérieure à la monnaie : elle a des records, donc de la
    // ponctualité à reconstituer. Partie neuve : rien à reconstituer, zéro.
    stations, bought
  };
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
// ------------------------------------------------------------------
// Gares ACHETÉES par le joueur — un fait, pas une déduction.
// ------------------------------------------------------------------
// Une gare s'ouvre en la payant, sur la carte, quand le joueur le décide. Ce
// choix ne se recalcule pas : il doit être mémorisé, sans quoi une gare payée
// se refermerait au rechargement.
function getBought() { return _progress.bought || (_progress.bought = []); }
function isBought(id) { return getBought().indexOf(id) >= 0; }

// ------------------------------------------------------------------
// Solde. Une seule bourse pour tout le réseau, tous pays confondus.
// ------------------------------------------------------------------
// Le solde ne descend JAMAIS en dessous de zéro et ne se retire jamais : un
// service raté rapporte zéro, il ne coûte rien. Toute écriture passe par ici.
// Achat : atomique. Rend false et ne touche à rien si le solde ne suffit pas ou
// si la gare est déjà acquise — l'appelant n'a aucune vérification à refaire.
// Ouvrir une gare n'a plus de prix : le magasin n'enregistre qu'un fait. Le
// second argument reste accepté et ignoré, pour ne pas casser les appels.
function buyStation(id) {
  if (!id || isBought(id)) return false;
  getBought().push(id);
  persistProgress();
  return true;
}
// ------------------------------------------------------------------
// PONCTUALITÉ — le compteur qui ne redescend jamais.
// ------------------------------------------------------------------
// Il n'achète RIEN. C'est un journal de travail, pas une bourse : le solde
// monte et descend au gré des achats, si bien que le geste le plus progressif
// du jeu — ouvrir une gare — faisait baisser le seul chiffre visible. La
// ponctualité, elle, ne fait que croître, et elle croît d'autant plus vite
// qu'on est à l'heure.
//
// `null` = pas encore reconstituée depuis les records (voir migrate).

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
