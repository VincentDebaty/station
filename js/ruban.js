"use strict";
// ------------------------------------------------------------------
// LE RUBAN, VU DU JEU — où en suis-je, et quelle est la gare suivante ?
// ------------------------------------------------------------------
// Remplace js/graph.js (lot D, 25 août 2026). La carte n'est plus un graphe
// de hubs et de sorties : c'est un RUBAN — une suite ordonnée de gares, sans
// embranchement et sans choix (meta-progression §0).
//
// LA RÈGLE DE PROGRESSION TIENT EN UNE PHRASE : on avance d'une gare à la
// suivante, dans l'ordre écrit. Il n'y a rien à décider.
//
// Ce qui a disparu avec le graphe : les sorties d'un hub, le choix d'une
// ligne, l'ouverture d'un boss au terme de sa ligne, la difficulté relative à
// un boss dans les deux sens. Ce qui reste, parce que c'était mesuré et calé :
// plafondDeFlux, ENVELOPPES, PROFILS, enveloppeDe.
//
// Rien ici ne dessine et rien n'écrit : l'écran consomme ces fonctions, la
// progression aussi, et aucun des deux ne connaît la forme des données.
// ------------------------------------------------------------------

const RUBAN = { pret: false, chapitres: [], ordre: [], index: {}, chapitreDe: {} };

// Changer de carte invalide tout : le prochain lecteur reconstruit.
function resetRuban() { RUBAN.pret = false; }

function buildRuban() {
  if (RUBAN.pret) return;
  RUBAN.chapitres = []; RUBAN.ordre = []; RUBAN.index = {}; RUBAN.chapitreDe = {};
  if (typeof CARTE_COURANTE === "undefined" || !CARTE_COURANTE) return;
  const chs = CARTE_COURANTE.chapitres || [];
  chs.forEach((ch, k) => {
    const c = { id: ch.id, nom: ch.nom, zone: ch.zone, rang: k,
      gares: (ch.gares || []).slice(), plancher: ch.plancher, arrivee: ch.arrivee, saut: ch.saut || null,
      debut: RUBAN.ordre.length };
    c.fin = c.debut + c.gares.length - 1;
    RUBAN.chapitres.push(c);
    for (const g of c.gares) {
      // R6 : une fiche n'apparaît qu'une fois. Si la donnée en contient deux,
      // c'est la PREMIÈRE qui compte — le contrôle de carte, lui, refuse.
      if (RUBAN.index[g] !== undefined) continue;
      RUBAN.index[g] = RUBAN.ordre.length;
      RUBAN.chapitreDe[g] = c;
      RUBAN.ordre.push(g);
    }
  });
  RUBAN.pret = true;
}

// --- Lecture de la forme --------------------------------------------
function chapitresDuRuban() { buildRuban(); return RUBAN.chapitres; }
function ordreDuRuban() { buildRuban(); return RUBAN.ordre; }
function longueurDuRuban() { buildRuban(); return RUBAN.ordre.length; }
function indexDe(gareId) { buildRuban(); const i = RUBAN.index[gareId]; return i === undefined ? -1 : i; }
function gareAt(i) { buildRuban(); return RUBAN.ordre[i] || null; }
function chapitreDeGare(gareId) { buildRuban(); return RUBAN.chapitreDe[gareId] || null; }
function chapitreAt(i) { buildRuban(); return RUBAN.chapitreDe[RUBAN.ordre[i]] || null; }
// La gare est-elle sur le ruban de la carte courante ?
function surLeRuban(gareId) { return indexDe(gareId) >= 0; }
// La gare a-t-elle une fiche écrite ? Une gare sans fiche est « à venir » : le
// ruban la porte, le jeu ne la propose jamais.
function estEcrite(gareId) {
  return typeof cardOf === "function" ? !!cardOf(gareId) : false;
}

// --- L'état d'une gare ----------------------------------------------
// FAITE : au moins une étoile. C'est la même règle que le rang de chapitre
// (js/recompense.js) — écrite ici en clair parce que le ruban est chargé avant
// la couche récompense et ne doit rien lui devoir.
function estFaite(gareId) {
  if (!gareId || typeof getProgress !== "function") return false;
  return ((getProgress()[gareId] || {}).stars || 0) >= 1;
}
// PAYÉE : franchie par la soupape, en crédits (meta-progression §4 ter). Elle
// laisse avancer le ruban et ne rapporte rien — ni étoile, ni rang, ni jauge.
function estPassee(gareId) {
  return !!gareId && typeof getPassees === "function" && getPassees().indexOf(gareId) >= 0;
}
// FRANCHIE : faite ou payée. C'est ce qui fait avancer la position, et rien
// d'autre — surtout pas « ouverte » ou « tentée ».
function estFranchie(gareId) { return estFaite(gareId) || estPassee(gareId); }

// ------------------------------------------------------------------
// LA POSITION NE SE STOCKE PAS. Elle se déduit : c'est la première gare du
// ruban qui n'est ni faite ni payée. Un état déduit ne peut pas se
// désynchroniser d'avec les résultats, et la sauvegarde n'a rien à migrer le
// jour où l'on réordonne un chapitre.
// ------------------------------------------------------------------
function positionCourante() {
  buildRuban();
  for (let i = 0; i < RUBAN.ordre.length; i++) if (!estFranchie(RUBAN.ordre[i])) return i;
  return RUBAN.ordre.length;
}
// La première gare que le ruban porte SANS fiche écrite. Au-delà, plus rien ne
// se joue : c'est le bout de ce qui existe, pas la fin du voyage.
function premiereAVenir() {
  buildRuban();
  for (let i = 0; i < RUBAN.ordre.length; i++) if (!estEcrite(RUBAN.ordre[i])) return i;
  return RUBAN.ordre.length;
}
// LA GARE COURANTE — la seule question que l'écran d'accueil pose. Null quand
// le ruban est fini, ou quand ce qui vient n'est pas encore écrit.
function gareCourante() {
  const p = positionCourante();
  if (p >= longueurDuRuban()) return null;
  const g = gareAt(p);
  return estEcrite(g) ? g : null;
}
// Le ruban est-il arrêté faute de contenu plutôt que par sa fin ?
function auBoutDeLEcrit() {
  const p = positionCourante();
  return p < longueurDuRuban() && !estEcrite(gareAt(p));
}
// TENUE : la gare est à la position courante ou avant. C'est ce que le reste
// du jeu appelait « achetée » — sur un ruban, tenir une gare c'est simplement
// l'avoir atteinte. Une gare tenue se rejoue quand on veut.
function estTenue(gareId) {
  const i = indexDe(gareId);
  return i >= 0 && i <= positionCourante() && estEcrite(gareId);
}
// Un chapitre est TERMINÉ quand toutes ses gares sont franchies.
function chapitreTermine(ch) {
  return !!ch && ch.gares.every(estFranchie);
}
function chapitreCourant() { return chapitreAt(Math.min(positionCourante(), longueurDuRuban() - 1)); }
// « gare 3 sur 6 » — le rang dans le chapitre, à partir de 1.
function rangDansChapitre(gareId) {
  const ch = chapitreDeGare(gareId);
  return ch ? ch.gares.indexOf(gareId) + 1 : 0;
}

// ------------------------------------------------------------------
// LA DIFFICULTÉ SE DÉDUIT DE LA POSITION — mais la géométrie a le dernier mot.
// ------------------------------------------------------------------
// Le ruban a UNE courbe, en dents de scie : chaque chapitre monte de son
// plancher jusqu'à sa grande gare, et le plancher des chapitres monte par
// paliers le long du ruban (meta-progression §2.5).
//
// MAIS le flux ne peut pas tout. Mesuré (tools/AUTHORING-STATIONS.md §5 bis) :
// une gare à 3 directions et 4 quais plafonne au niveau 3 ; au-delà, le trafic
// ajouté ne devient pas de la difficulté mais de la file d'attente. On calcule
// donc la difficulté VOULUE, puis on la rabat sur ce que la gare peut porter.
// C'est le NOMBRE DE QUAIS qui commande — les directions décident de la
// richesse du casse-tête, les quais de la quantité de trafic absorbable :
//
//     3 quais (Dinant)   → 2      5 quais (Bruges) → 4
//     4 quais (Landen)   → 3      6 quais (Namur)  → 4
function plafondDeFlux(cfg) {
  if (!cfg) return 5;
  const quais = (cfg.platforms || []).length;
  return Math.max(1, Math.min(5, quais - 1));
}
// Le plancher d'un chapitre : celui qu'il déclare, sinon une rampe douce
// déduite de son rang dans le ruban (un cran tous les trois chapitres).
function plancherDeChapitre(ch) {
  if (!ch) return 1;
  if (ch.plancher) return Math.max(1, Math.min(5, ch.plancher));
  return Math.max(1, Math.min(4, 1 + Math.floor(ch.rang / 3)));
}
// La difficulté d'ARRIVÉE d'un chapitre : ce que sa grande gare peut porter.
// C'est la géométrie qui décide du sommet, pas une constante — une fin de
// chapitre sur une gare de six quais ne vaut pas une fin sur Bruxelles-Midi.
// Un chapitre peut PLAFONNER son arrivée : c'est ce qui rend R9 tenable. Le
// premier chapitre du ruban finit sur une grande gare — Bruxelles-Midi porte
// un niveau 5 — et faire arriver le tutoriel au sommet du jeu six gares après
// l'avoir ouvert serait un mur. `arrivee` dit alors ce que la fin du chapitre
// DOIT produire, pas ce que la gare peut porter.
function arriveeDeChapitre(ch) {
  if (!ch || !ch.gares.length) return 5;
  const fin = ch.gares[ch.gares.length - 1];
  const cfg = typeof cardOf === "function" ? cardOf(fin) : null;
  const haut = ch.arrivee ? Math.min(5, ch.arrivee) : Math.min(5, plafondDeFlux(cfg));
  return Math.max(plancherDeChapitre(ch) + 1, haut);
}
// `i` : rang de la gare dans le chapitre (0 = la première). `n` : longueur du
// chapitre. La rampe part du plancher et atteint l'arrivée au dernier pas.
function difficulteVoulue(i, n, plancher, arrivee) {
  if (n <= 1) return arrivee;
  return Math.round(plancher + (arrivee - plancher) * (i / (n - 1)));
}
// Ce que la gare portera vraiment.
function difficulteDeGare(gareId, cfg) {
  const ch = chapitreDeGare(gareId);
  if (!ch) return null;
  const i = ch.gares.indexOf(gareId);
  if (i < 0) return null;
  const voulue = difficulteVoulue(i, ch.gares.length, plancherDeChapitre(ch), arriveeDeChapitre(ch));
  return Math.max(1, Math.min(voulue, plafondDeFlux(cfg || (typeof cardOf === "function" ? cardOf(gareId) : null))));
}

// ------------------------------------------------------------------
// L'ENVELOPPE DE GÉNÉRATION SE DÉDUIT DU PALIER.
// ------------------------------------------------------------------
// Valeurs relevées sur les fiches du catalogue, palier par palier. Ce sont des
// MOYENNES observées, pas des chiffres inventés. La cadence varie peu d'un
// palier à l'autre (1,5 à 1,8 min entre arrivées) — c'est le NOMBRE de convois
// qui monte, de 12 à 22.
const ENVELOPPES = {
  1: { nMin: 12, nMax: 15, gapMin: 1.62, gapMax: 2.84, freightCount: 1 },
  2: { nMin: 13, nMax: 16, gapMin: 1.81, gapMax: 3.02, freightCount: 2 },
  3: { nMin: 14, nMax: 17, gapMin: 1.71, gapMax: 2.92, freightCount: 3 },
  4: { nMin: 16, nMax: 20, gapMin: 1.59, gapMax: 2.73, freightCount: 4 },
  5: { nMin: 18, nMax: 22, gapMin: 1.52, gapMax: 2.58, freightCount: 5 }
};
// Les profils d'affluence. Sur un ruban, ils ne servent plus à distinguer les
// visites d'un même hub (il n'y en a plus qu'une) : ils restent disponibles
// pour durcir une arrivée, et ne rachètent jamais un tracé déjà parcouru.
const PROFILS = [
  { nom: "heures creuses", rush: "plat",   densite: 0.85, fret: 0 },
  { nom: "pointe",         rush: "pointe", densite: 1.00, fret: 0 },
  { nom: "double pointe",  rush: "double", densite: 1.05, fret: 1 },
  { nom: "bourrasque",     rush: "rafale", densite: 1.10, fret: 1 },
  { nom: "service tendu",  rush: "pointe", densite: 1.15, fret: 2 },
  { nom: "nocturne",       rush: "plat",   densite: 0.95, fret: 3 }
];
function enveloppeDe(cfg, niveau, profil) {
  const n = Math.max(1, Math.min(5, niveau || (cfg && cfg.difficulty) || 1));
  const e = ENVELOPPES[n], p = profil || PROFILS[1];
  return {
    ...(cfg && cfg.gen),              // ce que la fiche impose reste prioritaire
    nMin: Math.round(e.nMin * p.densite),
    nMax: Math.round(e.nMax * p.densite),
    gapMin: e.gapMin, gapMax: e.gapMax,
    freightCount: Math.max(0, e.freightCount + p.fret),
    rush: p.rush
  };
}
function enveloppeDeGare(gareId, cfg) {
  const d = difficulteDeGare(gareId, cfg);
  return enveloppeDe(cfg, d == null ? (cfg && cfg.difficulty) : d, PROFILS[1]);
}

// ------------------------------------------------------------------
// LA FICHE TELLE QU'ON LA JOUE.
// ------------------------------------------------------------------
// La fiche garde sa géométrie — quais, portails, liaisons — mais son bloc
// `gen` ne se lit plus tel quel : il se recalcule depuis la POSITION de la
// gare sur le ruban, rabattu sur ce que sa géométrie peut porter. Le champ
// `difficulty` de la fiche devient DESCRIPTIF : il dit la taille de la gare,
// plus ce qu'elle doit produire.
//
// C'est ce qui rend le tutoriel possible : Arlon est une petite gare écrite
// pour ce qu'elle est, et la première gare du ruban se joue en niveau 1 sans
// qu'on ait rien à toucher au catalogue.
function ficheDeService(cfg) {
  if (!cfg) return cfg;
  const d = difficulteDeGare(cfg.id, cfg);
  if (d == null) return cfg;
  return { ...cfg, difficulty: d, gen: enveloppeDe(cfg, d, PROFILS[1]) };
}

// --- Zones ------------------------------------------------------------
function chapitresDeZone(zoneId) { return chapitresDuRuban().filter(c => c.zone === zoneId); }
// L'état d'une zone se DÉDUIT, comme tout le reste : fermée ‹ entamée ‹
// traversée. Les rangs (or, diamant) sont l'affaire de js/recompense.js.
function etatDeZone(zoneId) {
  const chs = chapitresDeZone(zoneId);
  if (!chs.length) return "fermee";
  if (chs.every(chapitreTermine)) return "traversee";
  return chs.some(c => c.gares.some(estFranchie)) ? "entamee" : "fermee";
}
