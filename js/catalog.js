"use strict";
// ------------------------------------------------------------------
// Catalogue des gares — un fichier JSON par gare, classé par pays dans
// data/stations/. index.json RÉUNIT les gares d'un pays ET fixe leur ORDRE DE
// JEU : un parcours géographiquement cohérent, démarrant sur une gare facile et
// montant globalement en difficulté (les gares proches s'enchaînent, la ligne du
// réseau ne zigzague plus). Chaque pays est une échelle indépendante : tous sont
// ouverts d'emblée, chacun se gravit pour son compte — un joueur commence par
// SON pays, pas par la Belgique.
// Chaque fiche décrit entièrement une gare : quais (impasses comprises),
// portails (côté, sens, couleur), liaisons, paires même-côté autorisées
// (rebroussements) et paramètres du générateur. Le moteur s'adapte,
// le calibrage garantit le zéro.
// ------------------------------------------------------------------
const CATALOG = [];

async function loadCatalog() {
  const base = "data/stations/";
  const index = await fetch(base + "index.json").then(r => {
    if (!r.ok) throw new Error("index.json : " + r.status);
    return r.json();
  });
  // Un pays = un bloc contigu dans CATALOG. L'ORDRE DE JEU (1→N, qui pilote le
  // déverrouillage, la numérotation sur la carte et la ligne du réseau) est
  // l'ordre CURATÉ de index.json : un parcours géographiquement cohérent qui
  // démarre par une gare facile et monte globalement en difficulté (compromis).
  // Le champ « difficulty » ne sert plus au tri — seulement aux pastilles de la
  // fiche de gare. Promise.all préserve l'ordre du tableau.
  const blocks = await Promise.all(index.map(group =>
    Promise.all(group.stations.map(id => {
      const f = base + group.country + "/" + id + ".json";
      return fetch(f).then(r => {
        if (!r.ok) throw new Error(f + " : " + r.status);
        return r.json();
      });
    }))
  ));
  CATALOG.length = 0;
  for (const cards of blocks) CATALOG.push(...cards);
}

// Progression (étoiles + record par id) : persistance dans js/store.js
// (getProgress / saveResult). Ici, seule la logique de DÉVERROUILLAGE, qui
// dépend du catalogue.
//
// DÉVERROUILLAGE PAR LE RÉSEAU, gagné service après service.
//
// Les gares les plus faciles (difficulté ≤ ENTRY_DIFFICULTY) sont les PORTES
// D'ENTRÉE : ouvertes tant que le joueur n'a RIEN décroché, partout, pour qu'il
// choisisse par où commencer. Dès son premier service réussi, les autres portes
// se referment : il s'est engagé quelque part, et le reste se gagne de proche en
// proche comme n'importe quelle gare.
//
// Ensuite, chaque service RÉUSSI donne le droit d'ouvrir UNE gare voisine, et
// le nombre d'étoiles décide de la latitude laissée au joueur :
//   ★☆☆  la plus facile des voisines encore fermées — sans choix ;
//   ★★☆  au choix parmi les voisines fermées PAS PLUS DURES que celle-ci ;
//   ★★★  au choix parmi toutes ses voisines fermées.
// Rejouer une gare redonne une ouverture : c'est ce qui garantit qu'aucune
// gare ne devient inatteignable (Anvers n'a que Gand pour voisine — il faut
// pouvoir revenir à Gand pour l'ouvrir après avoir ouvert Bruges).
//
// Une gare ouverte l'est DÉFINITIVEMENT et se mémorise (js/store.js) : ce choix
// appartient au joueur, il ne se recalcule pas.
const ENTRY_DIFFICULTY = 1;

function stationDifficulty(id) {
  const c = CATALOG.find(x => x.id === id);
  return c ? Math.max(1, Math.min(5, c.difficulty || 1)) : 1;
}
function isEarned(id, prog) {
  return (((prog || getProgress())[id] || {}).stars || 0) >= 1;
}
// Aucune gare décrochée nulle part : la partie n'a pas encore commencé.
function noStationEarned() {
  const prog = getProgress();
  return !CATALOG.some(c => ((prog[c.id] || {}).stars || 0) > 0);
}
// Une porte d'entrée doit MENER quelque part. Une gare facile sans voisine
// jouable est un piège : le joueur s'y engage, les autres portes se referment,
// et il se retrouve avec une seule gare pour toujours. Tant qu'un pays n'a pas
// de voisinage praticable (l'Allemagne attend ses lignes), il n'offre pas de
// porte — mieux vaut un pays encore fermé qu'un cul-de-sac.
function isEntryDoor(id) {
  if (stationDifficulty(id) > ENTRY_DIFFICULTY) return false;
  return typeof netLinks === "function" &&
    netLinks(id).to.some(nb => CATALOG.some(c => c.id === nb));
}
function isUnlocked(i) {
  const c = CATALOG[i];
  if (!c) return false;
  if (isEarned(c.id)) return true;   // déjà décrochée : toujours rejouable
  if (isOpened(c.id)) return true;   // ouverte par une voisine
  // Porte d'entrée : disponible seulement avant le premier service réussi.
  return noStationEarned() && isEntryDoor(c.id);
}

// Voisines encore fermées d'une gare, de la plus facile à la plus dure.
function lockedNeighbours(id) {
  if (typeof netLinks !== "function") return [];
  return netLinks(id).to
    .filter(nb => {
      const gi = CATALOG.findIndex(c => c.id === nb);
      return gi >= 0 && !isUnlocked(gi);
    })
    .sort((a, b) => stationDifficulty(a) - stationDifficulty(b));
}
// Quand TOUTES les voisines sont déjà ouvertes, la récompense porte plus loin :
// on avance de proche en proche À TRAVERS les gares déjà ouvertes, et on s'arrête
// au premier rang où l'on trouve du fermé. On ne saute jamais par-dessus une
// gare fermée — la progression reste le long des voies, elle prend juste appui
// sur le territoire déjà acquis.
// Sans ce repli, terminer une gare entourée de gares faites ne rapportait RIEN,
// ce qui punissait exactement le joueur le plus avancé.
function nearestLocked(id) {
  const seen = new Set([id]);
  let ring = [id];
  for (let depth = 0; depth < CATALOG.length && ring.length; depth++) {
    const found = [], next = [];
    for (const cur of ring) {
      for (const nb of netLinks(cur).to) {
        if (seen.has(nb)) continue;
        const gi = CATALOG.findIndex(c => c.id === nb);
        if (gi < 0) continue;
        seen.add(nb);
        (isUnlocked(gi) ? next : found).push(nb);
      }
    }
    if (found.length) return found.sort((a, b) => stationDifficulty(a) - stationDifficulty(b));
    ring = next;
  }
  return [];
}
// Vrai quand la récompense ne porte plus sur une VOISINE directe : le libellé
// de l'écran de fin doit le dire, sinon « gare voisine » devient un mensonge.
function unlockIsBeyond(id) {
  return !lockedNeighbours(id).length && !!nearestLocked(id).length;
}
// Ce qu'un service à `stars` étoiles donne le droit d'ouvrir depuis `id`.
// Liste vide = plus rien à ouvrir nulle part (tout le réseau atteignable est
// déjà acquis).
function unlockChoices(id, stars) {
  if (!(stars >= 1)) return [];
  const locked = lockedNeighbours(id).length ? lockedNeighbours(id) : nearestLocked(id);
  if (stars === 1) return locked.slice(0, 1);            // imposé : la plus facile
  if (stars === 2) {                                     // au choix, à niveau égal ou moindre
    const cap = stationDifficulty(id);
    const within = locked.filter(nb => stationDifficulty(nb) <= cap);
    // Un palier SUPÉRIEUR ne doit jamais retirer une possibilité. Sans ce
    // repli, faire mieux pouvait tout bloquer : à Namur (3), une étoile ouvrait
    // Liège (4) — « la plus facile encore fermée », sans plafond — tandis que
    // deux étoiles n'ouvraient RIEN, le plafond l'excluant. On garantit donc au
    // minimum ce qu'une étoile aurait donné.
    // (`locked` est trié par difficulté : si `within` n'est pas vide, il
    // contient forcément locked[0], le choix d'une étoile.)
    return within.length ? within : locked.slice(0, 1);
  }
  return locked;                                         // trois étoiles : tout le voisinage
}

// Gares ouvertes et jamais jouées, de la plus facile à la plus dure : c'est le
// front de progression, celui qu'on propose quand le joueur clique une gare
// encore fermée.
function openFrontier(country) {
  const prog = getProgress();
  const out = [];
  for (let i = 0; i < CATALOG.length; i++) {
    const c = CATALOG[i];
    if (country && c.country !== country) continue;
    if (isEarned(c.id, prog) || !isUnlocked(i)) continue;
    out.push(i);
  }
  return out.sort((a, b) => stationDifficulty(CATALOG[a].id) - stationDifficulty(CATALOG[b].id));
}
// Pays « terminé » = toutes ses gares décrochées (≥ 1 étoile). Sert à souligner
// l'achèvement d'un pays en fin de service.
function countryComplete(i) {
  const country = CATALOG[i] && CATALOG[i].country;
  if (!country) return false;
  const prog = getProgress();
  return CATALOG.every(c => c.country !== country || ((prog[c.id] || {}).stars || 0) >= 1);
}
