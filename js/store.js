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
// v6 (21 août 2026) : LA PROGRESSION EST PAR CARTE. Une carte est une mission
// indépendante ; ses gares, ses records et sa série ne se mélangent pas à ceux
// d'une autre. La sauvegarde porte donc `cartes[id] = { stations, bought,
// serie }`, la carte courante, et les cartes possédées (avec leur mode
// d'acquisition : gratuite, crédits, achat). Tout le reste — grade, crédits,
// rangs, médailles — se déduit.
const SCHEMA_VERSION = 6;
// La carte de tout joueur d'avant les cartes : l'Europe, et elle est gratuite.
const CARTE_PAR_DEFAUT = "europe";
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
function carteVierge() { return { stations: {}, bought: [], serie: { n: 0, record: 0 } }; }
function sauvegardeVierge() {
  return { version: SCHEMA_VERSION, carteCourante: CARTE_PAR_DEFAUT,
    cartes: { [CARTE_PAR_DEFAUT]: carteVierge() },
    possedees: { [CARTE_PAR_DEFAUT]: "gratuite" } };
}
let _progress = sauvegardeVierge();
// La progression de la carte COURANTE — c'est elle que lisent tous les
// accesseurs historiques. Créée à la demande : ouvrir une carte pour la
// première fois ne demande aucune écriture préalable.
function _carte() {
  const id = _progress.carteCourante || CARTE_PAR_DEFAUT;
  return _progress.cartes[id] || (_progress.cartes[id] = carteVierge());
}
let _muted = false;
let _onboarded = false;

// Dotation de départ : elle appartient à l'économie (js/catalog.js), pas au
// stockage. Lue au moment de la migration, donc après le chargement de tous les
// scripts — le repli ne sert qu'à ne jamais rendre une partie injouable.

// --- Migration : amène n'importe quel format vers le schéma courant. ---
function migrate(raw) {
  // v6 : déjà par carte. On relit avec des défauts, sans rien déduire.
  if (raw && raw.version === 6 && raw.cartes && typeof raw.cartes === "object") {
    const cartes = {};
    for (const id in raw.cartes) {
      const c = raw.cartes[id] || {};
      cartes[id] = { stations: c.stations || {}, bought: c.bought || [], serie: lireSerie(c) };
    }
    const possedees = raw.possedees && typeof raw.possedees === "object" ? raw.possedees : {};
    if (!possedees[CARTE_PAR_DEFAUT]) possedees[CARTE_PAR_DEFAUT] = "gratuite";
    return { version: 6, carteCourante: raw.carteCourante || CARTE_PAR_DEFAUT, cartes, possedees };
  }
  // v5 et avant : UNE seule progression, et c'était l'Europe. Elle devient la
  // progression de la carte « europe », intacte — le joueur retrouve ses gares,
  // ses records et sa série exactement où il les avait laissés.
  const v5 = migrerVersV5(raw);
  return { version: 6, carteCourante: CARTE_PAR_DEFAUT,
    cartes: { [CARTE_PAR_DEFAUT]: { stations: v5.stations, bought: v5.bought, serie: v5.serie } },
    possedees: { [CARTE_PAR_DEFAUT]: "gratuite" } };
}
// La série se lit avec un défaut : « aucune série en cours » n'a pas besoin
// d'être écrit pour être vrai.
function lireSerie(r) {
  const v = r && r.serie;
  return { n: Math.max(0, (v && v.n) | 0), record: Math.max(0, (v && v.record) | 0) };
}
function migrerVersV5(raw) {
  // Étape 1 : ramener toute sauvegarde ancienne à la forme v2
  // { stations, opened }, qui est le plus petit dénominateur commun.
  let stations = {}, opened = [];
  if (raw && typeof raw === "object") {
    // v0 (héritage) : objet plat { id: {stars,bestDelay} }, sans champ version.
    if (raw.version == null) stations = raw;
    else { stations = raw.stations || {}; opened = raw.opened || []; }
  }
  // LA SÉRIE SE LIT AVEC UN DÉFAUT, ELLE NE MIGRE PAS. C'est un champ AJOUTÉ,
  // et un champ ajouté dont l'absence a un sens évident (« aucune série en
  // cours ») ne justifie pas un cran de schéma : monter en v6 forcerait une
  // réécriture de toutes les sauvegardes pour y inscrire un zéro. Le numéro de
  // schéma sert aux changements qui CASSENT une lecture — les crédits en
  // étaient un, celui-ci n'en est pas.
  // Déjà en v5 : rien à déduire, on reprend tel quel.
  if (raw && raw.version === 5)
    return { version: 5, stations, bought: raw.bought || [], serie: lireSerie(raw) };
  // v4 → v5 : LES CRÉDITS ET LA PONCTUALITÉ DISPARAISSENT, et le joueur ne perd
  // rien. Ce qu'il avait acquis, ce sont ses GARES et ses RECORDS — les deux
  // sont conservés tels quels. Le solde ne servait qu'à ouvrir des gares, et
  // l'on n'en a plus besoin ; le compteur de ponctualité doublait ce que les
  // étoiles disent déjà, et le grade se relit désormais sur elles.
  //
  // Une gare payée reste ouverte : `bought` passe intact. C'est la seule chose
  // qui compte, et c'est ce qui rend la migration sans risque.
  if (raw && raw.version === 4)
    return { version: 5, stations, bought: raw.bought || [], serie: lireSerie(raw) };
  if (raw && raw.version === 3)
    return { version: 5, stations, bought: raw.bought || [], serie: lireSerie(raw) };

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
    stations, bought, serie: lireSerie(raw)
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

// APERÇU SANS TRACE. L'aperçu du relevé de fin (station.html?fin=…, js/main.js)
// joue une fin de service pour de faux : il achète la gare, enregistre un
// record, pousse la série — tout ce que fait une vraie fin, pour que le relevé
// montre les vraies tuiles. Mais rien ne doit survivre au rechargement : la
// progression reste en mémoire et n'est plus écrite tant que ce drapeau est levé.
let APERCU_SANS_TRACE = false;
function persistProgress() {
  if (APERCU_SANS_TRACE) return;
  _store.write(KEY_PROGRESS, JSON.stringify(_progress)); // fire-and-forget durable
}

// ------------------------------------------------------------------
// API progression — signatures inchangées pour le reste du jeu.
// getProgress() rend la table { id: {stars,bestDelay} } (comme avant).
// ------------------------------------------------------------------
function getProgress() { return _carte().stations; }
// Les tables de TOUTES les cartes — pour ce qui est un fait de compte et non
// de carte : le grade, les crédits. Lecture seule.
function getProgressToutesCartes() {
  const out = [];
  for (const id in _progress.cartes) out.push((_progress.cartes[id] || {}).stations || {});
  return out;
}

// ------------------------------------------------------------------
// LES CARTES — laquelle on joue, lesquelles on possède.
// ------------------------------------------------------------------
function getCarteCourante() { return _progress.carteCourante || CARTE_PAR_DEFAUT; }
// Changer de carte n'efface rien : chaque carte garde sa progression, et l'on
// y revient où on l'avait laissée. (Le graphe, lui, se recharge : js/cartes.js.)
function setCarteCourante(id) {
  if (!id || id === _progress.carteCourante) return;
  _progress.carteCourante = id;
  _carte();                       // la progression de cette carte existe désormais
  persistProgress();
}
function cartesPossedees() { return _progress.possedees || (_progress.possedees = {}); }
function possedeCarte(id) { return !!cartesPossedees()[id]; }
// Acquérir une carte : `mode` dit comment (« gratuite », « credits », « achat »).
// C'est un FAIT — le seul que l'économie des cartes écrive. Le solde de
// crédits, lui, se déduit : gagnés par la progression, moins le prix des
// cartes acquises en crédits.
function acquerirCarte(id, mode) {
  if (!id || possedeCarte(id)) return false;
  cartesPossedees()[id] = mode || "achat";
  persistProgress();
  return true;
}
// ------------------------------------------------------------------
// Gares ACHETÉES par le joueur — un fait, pas une déduction.
// ------------------------------------------------------------------
// Une gare s'ouvre en la payant, sur la carte, quand le joueur le décide. Ce
// choix ne se recalcule pas : il doit être mémorisé, sans quoi une gare payée
// se refermerait au rechargement.
function getBought() { const c = _carte(); return c.bought || (c.bought = []); }
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
  const stations = _carte().stations;
  const cur = stations[id] || { stars: 0, bestDelay: null };
  stations[id] = {
    stars: Math.max(cur.stars, stars),                                   // on ne garde que le meilleur score
    bestDelay: cur.bestDelay == null ? delay : Math.min(cur.bestDelay, delay)
  };
  persistProgress();
}

// ------------------------------------------------------------------
// LA SÉRIE — le seul compteur qui puisse REDESCENDRE, et c'est exprès.
// ------------------------------------------------------------------
// Tout le reste de la progression est un cliquet : les étoiles ne retombent
// pas, une gare ouverte le reste, un record ne s'abîme pas. C'est ce qui rend
// le jeu paisible — mais c'est aussi ce qui fait qu'un bon service se ressent
// comme le précédent, puisque rien n'est jamais en jeu.
//
// La série est la contrepartie exacte : elle compte les services d'affilée à
// trois étoiles, et un service en dessous la ramène à zéro. Elle ne coûte
// rien — aucune gare ne se referme, aucune étoile ne se perd — donc la casser
// n'est pas une punition, c'est la fin d'un élan. Et son RECORD, lui, est un
// cliquet comme les autres : ce qu'on a réussi une fois reste acquis.
//
// Elle vit dans la progression, pas dans la session : une série qui
// s'évaporerait en fermant l'application ne vaudrait pas la peine d'être
// tenue.
function getSerie() {
  const c = _carte(), s = c.serie || (c.serie = { n: 0, record: 0 });
  return { n: s.n, record: s.record };
}
// Enregistre un service. `tenu` : a-t-il atteint le seuil de la série ?
// Rend l'état AVANT et APRÈS, pour que le relevé sache quoi raconter — une
// série qui monte et une série qui casse ne se disent pas de la même façon.
function pushSerie(tenu) {
  const c = _carte(), s = c.serie || (c.serie = { n: 0, record: 0 });
  const avant = s.n;
  s.n = tenu ? s.n + 1 : 0;
  const battu = s.n > s.record;
  if (battu) s.record = s.n;
  persistProgress();
  return { avant, n: s.n, record: s.record, casse: !tenu && avant > 0, battu };
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
