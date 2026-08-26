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
  // LES DIRECTIONS COMPTENT AUTANT QUE LES QUAIS. Le plafond ne regardait que
  // les quais, ce qui contredisait la règle qu'il est censé appliquer : le §5
  // bis de tools/AUTHORING-STATIONS.md mesure que « la difficulté d'une gare
  // vient d'abord de sa géométrie — combien de DIRECTIONS à aiguiller, combien
  // de quais pour les recevoir », et que « une gare de fin de corridor à trois
  // directions restera facile quoi qu'on fasse de son trafic ».
  //
  // Sans ce terme, Roth — six quais mais TROIS directions — montait au niveau 5
  // et recevait 18 à 22 convois : 4,0 de pression moyenne, mesuré le 26 août
  // 2026. Il n'y avait pas de quoi aiguiller, seulement de quoi faire la file.
  //
  // Le terme est calé sur la table mesurée du §5 bis : Dinant 3 dir/3 quais → 2,
  // Landen 3/4 → 3, Bruges 5/5 → 4, Liège 6/9 → 5. Les quatre sont retrouvées.
  const directions = Object.keys(cfg.portals || {}).length;
  // LE PALIER DE QUAIS, et non « un quai = un cran ». `quais - 1` laissait une
  // gare de six quais monter au niveau 5, où l'enveloppe sert 18 à 22 convois
  // — un régime que le §5 dimensionne pour HUIT à dix quais. Mesuré le 26 août
  // 2026 sur le ruban joué : Wittenberg (6 quais) et Treuchtlingen (5) sortent
  // au-dessus de 4 de pression, et passent toutes deux d'un cran plus bas.
  //
  // CINQ QUAIS PLAFONNENT À 3, et c'est le seul écart assumé avec la table du
  // §5 bis, qui valide Bruges (5 quais) au niveau 4. La table a été mesurée sur
  // les enveloppes ÉCRITES des fiches ; celle-ci s'applique à l'enveloppe
  // JOUÉE, qui vient de `ENVELOPPES` et sert 16 à 20 convois au niveau 4 sans
  // regarder la taille de la gare. Mesuré le 26 août : Treuchtlingen, cinq
  // quais, tient 3,4 à 3,8 de pression moyenne à ce régime même après
  // ouverture de sa paire morte, et rentre à 3,0 un cran plus bas. L'écart va
  // vers le PLUS FACILE, jamais vers le plus dur.
  const parQuais = quais >= 8 ? 5 : quais >= 6 ? 4 : quais >= 5 ? 3 : Math.max(1, quais - 1);
  return Math.max(1, Math.min(5, parQuais, directions));
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
// ------------------------------------------------------------------
// LE BARÈME D'ÉTOILES SUIT LA DIFFICULTÉ (25 août 2026).
// ------------------------------------------------------------------
// Deuxième cadran de difficulté, à côté du trafic — et il ne joue pas la même
// musique : le TRAFIC récompense le débit, une TOLÉRANCE SERRÉE récompense la
// précision. Un petit nœud à trois quais qui exige de la justesse ne se joue
// pas comme un terminus qui exige du volume, et c'est ce qui donne du
// caractère à des gares que le même barème rendait interchangeables.
//
// CE QUI REND LA CHOSE SÛRE : `gen-check` ne mesure pas seulement la file, il
// mesure le RETARD GARANTI — celui qui subsiste en jouant le placement idéal —
// et refuse toute fiche au-dessus de 0,30 min. Sur chaque gare du catalogue,
// une journée à zéro retard est donc DÉMONTRÉE possible. Resserrer le seuil de
// trois étoiles ne demande jamais l'impossible : seulement plus de précision.
//
// DEUX RÈGLES QU'ON NE TOUCHE PAS :
//   · UNE ÉTOILE RESTE À 30 MINUTES, partout et pour toujours. C'est le
//     plancher qui rend le ruban praticable — sur un fil linéaire, un plancher
//     resserré est un mur. C'est le pendant structurel de la soupape.
//   · LE DIAMANT RESTE ABSOLU. Zéro, c'est zéro. C'est la seule mesure
//     comparable d'un bout à l'autre du jeu, et la vraie chasse de fin de partie.
//
// La courbe est DOUCE exprès (12 → 8, pas 15 → 4) : deux cadrans qui disent
// tous les deux « difficulté » se composent, et un niveau 5 déjà à 22 convois
// avec quatre minutes de marge serait un mur déguisé.
const SEUILS = {
  1: { trois: 12, deux: 20, une: 30 },
  2: { trois: 11, deux: 20, une: 30 },
  3: { trois: 10, deux: 20, une: 30 },
  4: { trois:  9, deux: 20, une: 30 },
  5: { trois:  8, deux: 20, une: 30 }
};
function seuilsDeNiveau(niveau) {
  return SEUILS[Math.max(1, Math.min(5, niveau || 3))] || SEUILS[3];
}
// Le barème d'une gare telle qu'on la JOUE. Une fiche peut imposer les siens
// (`seuils` dans le JSON) — la porte reste ouverte pour un cas particulier,
// mais rien ne s'en sert : le barème se déduit, comme tout le reste.
function seuilsDeService(cfg) {
  if (cfg && cfg.seuils) return { ...seuilsDeNiveau(cfg.difficulty), ...cfg.seuils };
  const d = cfg ? (difficulteDeGare(cfg.id, cfg) ?? cfg.difficulty) : null;
  return seuilsDeNiveau(d);
}
// Les étoiles d'un service : le retard face au barème de la gare.
function etoilesPour(retard, seuils) {
  const s = seuils || seuilsDeNiveau(3);
  return retard < s.trois ? 3 : retard < s.deux ? 2 : retard < s.une ? 1 : 0;
}

// ------------------------------------------------------------------
// L'ENVELOPPE DE BOSS — la grande gare qui ferme un chapitre.
// ------------------------------------------------------------------
// MESURÉ AVANT D'ÊTRE POSÉ (25 août 2026, sept gares de fin de chapitre,
// K=14 journées, graine fixe). La question de départ était « et si un boss
// portait 35 convois ? ». Réponse : non, et le mur tombe entre 28 et 34.
//
//   n=22 (actuel)  retard 0,11–0,17 · file 3 · 0,6 à 2 s la journée
//   n=28           retard 0,19–0,26 · file 4 · 3 à 4 s
//   n=34           Cologne à 0,31 — AU-DESSUS du 0,30 que gen-check refuse
//   n=40           file 5 sur Hambourg, 5 à 6 s la journée
//
// Deux murs, et ils tombent ensemble. Le premier est fatal : au-delà de ~30
// convois le générateur ne garantit plus qu'une journée à ZÉRO RETARD soit
// possible — or c'est la promesse sur laquelle reposent le barème des étoiles
// ET le diamant. Le second est du confort : la génération tourne dans un
// worker avant le service, donc c'est le joueur qui attend.
//
// Ce qui sature n'est d'ailleurs pas les quais — la file reste à 3-4 partout —
// c'est la combinatoire de l'aiguillage. Le NOMBRE n'est donc pas le bon
// cadran : on prend à peine plus de trafic, et surtout une COURBE D'AFFLUENCE
// marquée et du fret en plus.
//
// LE PIÈGE DU BALAYAGE GRAÎNÉ, ATTRAPÉ EN CHEMIN. n24-28 passait les neuf boss
// à graine 7 — Leipzig à 0,30 pile, sur le seuil. Deux tirages LIBRES ont
// aussitôt sorti Leipzig à 0,31 et 0,34, et Stuttgart à 0,36 et 0,39 : refusé.
// C'est exactement ce que dit tools/AUTHORING-STATIONS.md §6, et une gare posée
// sur le seuil n'est pas une gare qui passe, c'est une gare qui a eu de la
// chance. On est donc redescendu à :
//
//   n20-24 · rafale · fret 6   retard 0,18–0,27 · file 3-4 · trois balayages
//                              verts (graine 7 + deux tirages libres)
//
// Soit DEUX convois de plus que le niveau 5 ordinaire, et c'est très bien
// ainsi : le caractère d'un boss vient désormais de sa COURBE et de son FRET,
// pas de son volume. « Rafale » (js/schedule.js) est un long calme puis une
// bourrasque finale — la journée monte vers son orage, et le chapitre finit
// dessus. La gare la plus tendue est Stuttgart : huit quais mais seulement
// CINQ destinations, donc le moins de façons de placer un convoi. Un boss se
// calibre sur elle, pas sur Bruxelles-Midi et ses huit directions.
const ENVELOPPE_BOSS = { nMin: 20, nMax: 24, gapMin: 1.50, gapMax: 2.50, freightCount: 6, rush: "rafale" };
// La dernière gare d'un chapitre — celle qui le ferme.
function estGrandeGare(gareId) {
  const ch = chapitreDeGare(gareId);
  return !!ch && ch.gares.length > 0 && ch.gares[ch.gares.length - 1] === gareId;
}
// UN BOSS N'EST UN BOSS QU'À PLEINE DIFFICULTÉ. La grande gare des premiers
// chapitres est plafonnée par la rampe (Bruxelles-Midi ouvre à 3, §2.5) : lui
// donner l'enveloppe de boss ferait exploser le tutoriel. Elle ne s'applique
// donc qu'au niveau 5 — ce qui la lie à la rampe comme tout le reste, et fait
// que les boss arrivent d'eux-mêmes quand le ruban est assez avancé.
function estBoss(gareId, cfg) {
  return estGrandeGare(gareId) && difficulteDeGare(gareId, cfg) === 5;
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
  const gen = estBoss(cfg.id, cfg)
    ? { ...cfg.gen, ...ENVELOPPE_BOSS }        // ce que la fiche impose reste prioritaire… sauf le boss
    : enveloppeDe(cfg, d, PROFILS[1]);
  return { ...cfg, difficulty: d, gen };
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
