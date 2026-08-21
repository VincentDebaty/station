"use strict";
// ------------------------------------------------------------------
// LE GRAPHE, VU DU JEU — où suis-je, et où puis-je aller ?
// ------------------------------------------------------------------
// La carte courante (data/cartes/<id>.json, chargée par js/cartes.js) décrit
// le réseau ; ce fichier répond aux questions que le jeu lui pose. Rien ici ne dessine et rien n'écrit : la carte consomme ces
// fonctions, la progression aussi, et aucune des deux ne connaît la forme des
// données.
//
// LA RÈGLE DE PROGRESSION TIENT EN UNE PHRASE : battre un boss ouvre une de
// ses sorties, au choix du joueur ; on parcourt alors le corridor jusqu'au
// boss suivant, qui rouvre le choix. Un boss déjà connu se rejoue dans une
// VERSION DE TRAFIC différente — c'est la seule répétition du jeu, et elle est
// espacée d'un corridor entier par construction.
//
// Ce qui N'EST PAS ici, et c'est voulu : aucune porte dure. « Réussir est
// facile, exceller est le vrai jeu » — on n'exige jamais de rejouer une gare
// pour avancer. La performance (étoiles, diamants) est la chasse optionnelle.
// ------------------------------------------------------------------

const GRAPHE = { pret: false, hubs: {}, liste: [], gares: {}, sorties: {}, corridors: [] };

// Changer de carte invalide tout : le prochain lecteur reconstruit.
function resetGraphe() { GRAPHE.pret = false; }

function buildGraphe() {
  if (GRAPHE.pret) return;
  GRAPHE.hubs = {}; GRAPHE.liste = []; GRAPHE.gares = {}; GRAPHE.sorties = {}; GRAPHE.corridors = [];
  if (typeof CARTE_COURANTE === "undefined" || !CARTE_COURANTE) return;
  const HUBS = CARTE_COURANTE.hubs || [], LIGNES = CARTE_COURANTE.lignes || [];

  for (const h of HUBS) {
    // `gareId` est recalculé à chaque construction : une carte rechargée ne
    // doit pas hériter d'une correspondance faite pour une autre.
    h.gareId = undefined;
    GRAPHE.hubs[h.id] = h; GRAPHE.sorties[h.id] = []; GRAPHE.liste.push(h);
  }

  // Le nom d'une fiche du catalogue → l'id du hub qui la joue. Le graphe
  // désigne ses hubs par le NOM de la gare (« Bruxelles ») ; le jeu les
  // connaît par leur id (« bruxelles-midi »). La table se construit une fois.
  if (typeof CATALOG !== "undefined")
    for (const c of CATALOG) {
      const h = HUBS.find(x => x.gare === (c.city || c.name));
      if (h) { GRAPHE.gares[c.id] = { role: "hub", hub: h.id }; h.gareId = c.id; }
    }

  // Chaque ligne devient une SORTIE de ses deux extrémités : une ligne se
  // parcourt dans les deux sens, il n'y a pas de sens privilégié. `a` est
  // l'origine réelle (`de`), et c'est depuis elle qu'une ligne se lit.
  // `gares` vaut null tant que la ligne n'est pas écrite.
  for (const l of LIGNES) {
    const a = l.de, b = l.vers;
    const lien = { a, b, type: l.type || "rail",
      gares: l.gares && l.gares.length ? l.gares : null, note: l.note };
    GRAPHE.corridors.push(lien);
    if (GRAPHE.sorties[a]) GRAPHE.sorties[a].push(lien);
    if (GRAPHE.sorties[b]) GRAPHE.sorties[b].push(lien);
    for (const g of (lien.gares || [])) GRAPHE.gares[g] = { role: "corridor", lien };
  }
  GRAPHE.pret = true;
}

// --- Lecture --------------------------------------------------------
function hubById(id) { buildGraphe(); return GRAPHE.hubs[id] || null; }
// Tous les hubs de la carte courante, et toutes ses lignes (écrites ou non).
function tousLesHubs() { buildGraphe(); return GRAPHE.liste; }
function tousLesLiens() { buildGraphe(); return GRAPHE.corridors; }
// Le lien entre deux hubs, quel que soit l'ordre.
function lienEntre(a, b) {
  buildGraphe();
  return GRAPHE.corridors.find(l => (l.a === a && l.b === b) || (l.a === b && l.b === a)) || null;
}
// Le hub joué par cette gare, ou null si c'est une gare de corridor.
function hubDeGare(gareId) {
  buildGraphe();
  const e = GRAPHE.gares[gareId];
  return e && e.role === "hub" ? GRAPHE.hubs[e.hub] : null;
}
// Le corridor auquel appartient cette gare, ou null.
function corridorDeGare(gareId) {
  buildGraphe();
  const e = GRAPHE.gares[gareId];
  return e && e.role === "corridor" ? e.lien : null;
}
// Les sorties d'un hub — c'est sa « réserve d'extension », et le nombre de
// versions de trafic qu'il devra porter.
function sortiesDeHub(hubId) { buildGraphe(); return GRAPHE.sorties[hubId] || []; }
// Un corridor lu DEPUIS un hub donné : ses gares dans l'ordre du parcours,
// et le hub d'en face. C'est la seule façon dont le jeu doit le lire — un
// corridor n'a pas de sens propre, seulement un sens de lecture.
function parcours(lien, depuis) {
  const versLaFin = lien.a === depuis;
  return {
    depuis, vers: versLaFin ? lien.b : lien.a,
    gares: lien.gares ? (versLaFin ? lien.gares.slice() : lien.gares.slice().reverse()) : [],
    type: lien.type
  };
}

// ------------------------------------------------------------------
// LA DIFFICULTÉ SE DÉDUIT DE LA POSITION — mais la géométrie a le dernier mot.
// ------------------------------------------------------------------
// Le principe : le trafic se densifie à l'approche des métropoles, donc la
// difficulté d'une gare de corridor est fonction de sa distance au boss visé.
// La même donnée sert les deux sens de parcours, puisqu'on la calcule à chaque
// fois par rapport au boss d'ARRIVÉE.
//
// MAIS le flux ne peut pas tout. Mesuré (voir tools/AUTHORING-STATIONS.md
// §5 bis) : une gare à 3 directions et 4 quais plafonne au niveau 3 ; au-delà,
// le trafic ajouté ne devient pas de la difficulté mais de la file d'attente.
// On calcule donc la difficulté VOULUE, puis on la rabat sur ce que la gare
// peut porter. Un corridor qui monte doit être écrit avec des gares qui
// grossissent — c'est d'ailleurs la réalité du rail.
// Calé sur la mesure, et c'est le NOMBRE DE QUAIS qui commande — les
// directions décident de la richesse du casse-tête, les quais de la quantité
// de trafic absorbable avant que la file ne s'installe :
//
//     3 quais (Dinant)   → 2      5 quais (Bruges) → 4
//     4 quais (Landen)   → 3      6 quais (Namur)  → 4
//
// C'est une ESTIMATION, à un palier près, et elle sert à l'écriture — pas à
// l'exécution. L'autorité reste `gen-check`, qui mesure la file réelle gare
// par gare. Une fiche qui dépasse son plafond ne casse pas : elle devient une
// salle d'attente, ce qui est pire parce que ça ne se voit pas d'un contrôle.
function plafondDeFlux(cfg) {
  if (!cfg) return 5;
  const quais = (cfg.platforms || []).length;
  return Math.max(1, Math.min(5, quais - 1));
}
// `i` : rang de la gare dans le parcours (0 = juste après le hub de départ).
// `n` : nombre de gares du corridor. `dBoss` : difficulté du boss d'arrivée.
function difficulteVoulue(i, n, dBoss) {
  if (n <= 1) return Math.max(1, dBoss - 1);
  // Une rampe qui part deux crans sous le boss et le rejoint au dernier pas.
  const bas = Math.max(1, dBoss - 3);
  return Math.round(bas + (dBoss - 1 - bas) * (i / (n - 1)));
}
// Ce que la gare portera vraiment.
function difficulteDeGare(gareId, versHub, cfg) {
  const lien = corridorDeGare(gareId);
  if (!lien || !lien.gares) return null;
  const p = parcours(lien, lien.a === versHub ? lien.b : lien.a);
  const i = p.gares.indexOf(gareId);
  if (i < 0) return null;
  const boss = hubById(p.vers);
  const dBoss = boss && boss.rang === 1 ? 5 : 4;
  return Math.min(difficulteVoulue(i, p.gares.length, dBoss), plafondDeFlux(cfg));
}

// ------------------------------------------------------------------
// LE PAS SUIVANT — la seule question que l'écran d'accueil pose.
// ------------------------------------------------------------------
// `tenues` : l'ensemble des ids de gares déjà assurées au moins une fois.
// On rend la première gare non tenue du corridor en cours ; à défaut, les
// sorties encore fermées du dernier boss battu.
function prochaineGare(lien, depuis, tenues) {
  const p = parcours(lien, depuis);
  for (const g of p.gares) if (!tenues.has(g)) return { gare: g, corridor: p };
  // LA MÊME PORTE QU'EN BAS, et il en faut deux parce qu'un boss a deux
  // approches : par la ligne qu'on remonte (ici, depuis le hub d'en face) et
  // par la gare de bout dont il est voisin. Ne la poser qu'à un endroit, c'est
  // la laisser se contourner par l'autre.
  if (!p.gares.every(estFaite)) return null;
  const h = hubById(p.vers);
  return h && h.gareId && !tenues.has(h.gareId)
    ? { gare: h.gareId, corridor: p, boss: h } : null;
}
// Un corridor est TERMINÉ quand toutes ses gares et son boss d'arrivée sont
// tenus. C'est ce qui déclenche la célébration de fin de ligne.
function corridorTermine(lien, depuis, tenues) {
  const p = parcours(lien, depuis);
  if (!p.gares.every(g => tenues.has(g))) return false;
  const h = hubById(p.vers);
  return !h || !h.gareId || tenues.has(h.gareId);
}
// Un boss est MAÎTRISÉ quand toutes ses sorties ont été parcourues jusqu'au
// bout. C'est la récompense majeure du document, et le statut doré sur la carte.
function bossMaitrise(hubId, tenues) {
  const s = sortiesDeHub(hubId);
  return s.length > 0 && s.every(l => corridorTermine(l, hubId, tenues));
}

// ------------------------------------------------------------------
// L'ENVELOPPE DE GÉNÉRATION SE DÉDUIT DU PALIER.
// ------------------------------------------------------------------
// Valeurs relevées sur les 145 fiches du catalogue, palier par palier. Ce sont
// des MOYENNES observées, pas des chiffres inventés : elles décrivent ce que
// les gares écrites à la main font déjà, et servent de gabarit à celles qui
// restent à écrire.
//
// La cadence varie peu d'un palier à l'autre (1,5 à 1,8 min entre arrivées) —
// c'est le NOMBRE de convois qui monte, de 12 à 22. La difficulté d'une
// journée tient donc à la quantité de trafic, pas à sa nervosité.
const ENVELOPPES = {
  1: { nMin: 12, nMax: 15, gapMin: 1.62, gapMax: 2.84, freightCount: 1 },
  2: { nMin: 13, nMax: 16, gapMin: 1.81, gapMax: 3.02, freightCount: 2 },
  3: { nMin: 14, nMax: 17, gapMin: 1.71, gapMax: 2.92, freightCount: 3 },
  4: { nMin: 16, nMax: 20, gapMin: 1.59, gapMax: 2.73, freightCount: 4 },
  5: { nMin: 18, nMax: 22, gapMin: 1.52, gapMax: 2.58, freightCount: 5 }
};

// ------------------------------------------------------------------
// LES VERSIONS DE TRAFIC — la seule répétition du jeu, et elle est méritée.
// ------------------------------------------------------------------
// Revenir à un boss déjà battu par une autre ligne le rejoue dans une version
// différente, plus dure. Deux visites du même boss sont donc séparées d'un
// corridor entier : la répétition ne se sent pas comme du remplissage.
//
// Un boss porte autant de versions que de sorties. La plupart n'ont qu'une
// fiche : leurs versions se distinguent alors par le PROFIL D'AFFLUENCE, que
// le moteur sait déjà produire (js/schedule.js, RUSH). Londres et Paris n'en
// ont pas besoin — leurs terminus sont déjà des directions, et le catalogue
// les a écrits séparément.
const PROFILS = [
  { nom: "heures creuses", rush: "plat",   densite: 0.85, fret: 0 },
  { nom: "pointe",         rush: "pointe", densite: 1.00, fret: 0 },
  { nom: "double pointe",  rush: "double", densite: 1.05, fret: 1 },
  { nom: "bourrasque",     rush: "rafale", densite: 1.10, fret: 1 },
  { nom: "service tendu",  rush: "pointe", densite: 1.15, fret: 2 },
  { nom: "nocturne",       rush: "plat",   densite: 0.95, fret: 3 }
];

// Les versions d'un boss, une par sortie, de la plus douce à la plus rude.
// L'ordre compte : c'est celui dans lequel le joueur les rencontrera.
function versionsDeHub(hubId) {
  buildGraphe();
  const h = GRAPHE.hubs[hubId];
  if (!h) return [];
  const sorties = sortiesDeHub(hubId);
  // Versions déclarées : on les range dans l'ordre des sorties du graphe, et
  // l'on complète au profil si une sortie n'en a pas.
  return sorties.map((lien, i) => {
    const vers = lien.a === hubId ? lien.b : lien.a;
    const dec = (h.versions || []).find(v => v.vers === vers);
    return {
      vers,
      gare: (dec && dec.gare) || h.gare,
      nom: (dec && dec.nom) || PROFILS[Math.min(i, PROFILS.length - 1)].nom,
      profil: PROFILS[Math.min(i, PROFILS.length - 1)]
    };
  });
}

// ------------------------------------------------------------------
// CE QU'ON DONNE AU GÉNÉRATEUR.
// ------------------------------------------------------------------
// La fiche d'une gare garde sa géométrie — quais, portails, liaisons — mais son
// bloc `gen` n'est plus lu tel quel : il se recalcule depuis la POSITION de la
// gare sur son corridor, rabattu sur ce que sa géométrie peut porter.
//
// Le champ `difficulty` de la fiche devient DESCRIPTIF : il dit la taille de la
// gare, plus ce qu'elle doit produire. C'est le renversement du lot 2, et il
// tient dans cette fonction.
function enveloppeDe(cfg, niveau, profil) {
  const n = Math.max(1, Math.min(5, niveau || cfg.difficulty || 1));
  const e = ENVELOPPES[n], p = profil || PROFILS[1];
  return {
    ...cfg.gen,                       // ce que la fiche impose reste prioritaire
    nMin: Math.round(e.nMin * p.densite),
    nMax: Math.round(e.nMax * p.densite),
    gapMin: e.gapMin, gapMax: e.gapMax,
    freightCount: Math.max(0, e.freightCount + p.fret),
    rush: p.rush
  };
}

// ------------------------------------------------------------------
// LA GARE D'AMORCE SE JOUE EN NIVEAU 1.
// ------------------------------------------------------------------
// La toute première gare d'une partie doit être la plus facile du jeu, et
// aucune tête de ligne ne l'est : le catalogue place en sortie de hub des
// gares de niveau 2 à 4 (Ottignies 2, Trèves 3, Louvain 4), parce qu'une gare
// est écrite pour sa taille réelle, pas pour la place qu'elle occupe sur un
// corridor. Filtrer les lignes de départ sur la difficulté de leur fiche ne
// laissait qu'une ligne sur sept — et donc plus aucun choix de pays.
//
// C'est donc l'ENVELOPPE qui plie, pas le catalogue : la gare garde sa
// géométrie — ses quais, ses directions, son plan — et ne reçoit qu'une
// journée de niveau 1. C'est exactement le renversement du lot 2 : la fiche
// dit ce que la gare EST, la position dit ce qu'elle DOIT PRODUIRE.
//
// Une seule gare est concernée, et pour toute la partie : celle par laquelle
// le joueur est entré dans le réseau. Elle reste sa gare facile, y compris
// quand il y revient pour ses étoiles — une gare qui durcirait derrière lui
// serait un piège.
function estGareDamorce(gareId) {
  if (!gareId || typeof getBought !== "function") return false;
  const b = getBought();
  return b.length > 0 && b[0] === gareId && garesDeDepart().has(gareId);
}
// La fiche telle qu'on la JOUE. `difficulty` suit l'enveloppe : les pastilles
// du cartouche annoncent le service qui vient, pas la taille du bâtiment.
function ficheDeService(cfg) {
  if (!cfg || !estGareDamorce(cfg.id)) return cfg;
  return { ...cfg, difficulty: 1, gen: enveloppeDe(cfg, 1, PROFILS[1]) };
}

// L'enveloppe d'une gare de corridor : sa position décide, sa géométrie limite.
// `versHub` est le boss vers lequel on voyage — la même gare est plus dure
// quand on monte vers la métropole que quand on s'en éloigne, et c'est le
// trafic réel.
function enveloppeDeGare(gareId, versHub, cfg) {
  const d = difficulteDeGare(gareId, versHub, cfg);
  return enveloppeDe(cfg, d == null ? cfg.difficulty : d, PROFILS[1]);
}

// ------------------------------------------------------------------
// LES LIGNES DE DÉPART — on ne commence pas par une gare, on commence par
// une LIGNE.
// ------------------------------------------------------------------
// Le tout premier écran proposait les gares faciles reliées au réseau : des
// noms sans lendemain (Landen, Herentals, Deinze…) posés au milieu de nulle
// part. Le joueur choisissait donc un POINT, alors que tout le reste du jeu
// lui fait choisir une DIRECTION — et il tombait, au premier service fini,
// sur une ligne dont il n'avait pas décidé et dont il ne tenait pas un bout.
//
// Une ligne de départ est un corridor écrit, pris depuis son origine : sa
// première gare est celle qui suit immédiatement le hub, et la suite se
// parcourt gare après gare jusqu'au boss d'en face. C'est exactement la
// boucle du jeu, dès le premier geste.
//
// TROIS GARES AU MOINS. En dessous, ce n'est pas une ligne : c'est un boss
// derrière un portillon, et la promesse — « parcourir un corridor » — ne
// serait pas tenue. Le seuil montera si le catalogue s'étoffe.
const DEPART_MIN = 3;
function lignesDeDepart() {
  buildGraphe();
  return GRAPHE.corridors.filter(l =>
    l.gares && l.gares.length >= DEPART_MIN &&
    GRAPHE.hubs[l.a] && GRAPHE.hubs[l.b] &&
    typeof cardOf === "function" && cardOf(l.gares[0]));
}
// Les gares par lesquelles une partie peut commencer : la première de chaque
// ligne de départ, et rien d'autre. Le SENS est celui du graphe (`de` → `vers`)
// — la même règle qu'ailleurs : une ligne se lit toujours depuis son origine.
function garesDeDepart() {
  const out = new Set();
  for (const l of lignesDeDepart()) out.add(l.gares[0]);
  return out;
}

// UNE GARE FAITE, c'est une gare qui a rendu au moins une étoile. C'est la
// même règle que le rang de ligne (js/recompense.js, niveauDeGare) : écrite
// ici en clair plutôt qu'importée, parce que le graphe ne doit rien devoir à
// la couche récompense — il est chargé avant elle.
function estFaite(gareId) {
  if (!gareId || typeof getProgress !== "function") return false;
  return ((getProgress()[gareId] || {}).stars || 0) >= 1;
}

// ------------------------------------------------------------------
// CE QUI EST OUVRABLE MAINTENANT.
// ------------------------------------------------------------------
// La question que pose la carte, et la seule. `tenues` est l'ensemble des ids
// de gares déjà acquises.
//
// Depuis une gare tenue, on peut ouvrir SA VOISINE le long du réseau : la
// suivante sur son corridor, ou le boss au bout. Depuis un hub tenu, la
// première gare non tenue de chacune de ses sorties — c'est le CHOIX de
// direction que le document place au cœur de la progression.
function garesOuvrables(tenues) {
  buildGraphe();
  // RIEN DE TENU : le réseau ne commence pas par une gare, il commence par une
  // ligne. Les seules ouvrables sont donc les premières des lignes de départ.
  if (!tenues || !tenues.size) return garesDeDepart();
  const out = new Set();
  const ajoute = g => { if (g && !tenues.has(g)) out.add(g); };

  for (const id in GRAPHE.hubs) {
    const h = GRAPHE.hubs[id];
    if (!h.gareId || !tenues.has(h.gareId)) continue;
    for (const lien of sortiesDeHub(id)) {
      const p = prochaineGare(lien, id, tenues);
      if (p) ajoute(p.gare);
    }
  }
  // Les gares de corridor ouvrent leurs deux voisines immédiates : on peut
  // avoir pris un corridor par son autre bout.
  for (const gareId of tenues) {
    const e = GRAPHE.gares[gareId];
    if (!e || e.role !== "corridor") continue;
    const g = e.lien.gares, i = g.indexOf(gareId);
    if (i < 0) continue;
    if (i > 0) ajoute(g[i - 1]);
    if (i < g.length - 1) ajoute(g[i + 1]);

    // UN BOSS S'ATTEINT AU TERME DE SA LIGNE, PAS EN SE TENANT À CÔTÉ.
    //
    // La voisine d'une gare de bout, c'est un hub — et l'ouvrir comme une
    // voisine ordinaire mettait le boss à un pas de la première gare venue.
    // Sur la ligne de départ, cela se voyait tout de suite : le joueur ouvrait
    // Ottignies, et Bruxelles — cinq gares de difficulté plus loin sur le
    // papier — s'allumait au service suivant. Il n'y avait plus de ligne à
    // parcourir, seulement un raccourci et deux halos entre lesquels choisir.
    //
    // Le bout ne s'ouvre donc qu'une fois toutes les gares du corridor
    // TERMINÉES — et terminées, pas seulement acquises. La nuance a l'air
    // mince : depuis la disparition des crédits, ouvrir une gare c'est la
    // jouer dans la foulée, donc « tenue » vaut presque toujours « faite ».
    // Presque : un service RATÉ laisse la gare acquise et sans étoile. Le
    // boss s'ouvrait alors au bout d'une ligne que le joueur n'avait pas
    // réussie — ce qui vide de son sens la seule porte du jeu.
    //
    // L'échec ne bloque que le boss, jamais la progression : les voisines
    // immédiates (au-dessus) restent ouvertes sur les gares acquises. On peut
    // donc continuer sa route après un revers, et il faudra repasser prendre
    // son étoile avant d'attaquer la métropole.
    if (!g.every(estFaite)) continue;
    const hA = GRAPHE.hubs[e.lien.a] || {}, hB = GRAPHE.hubs[e.lien.b] || {};
    const tA = hA.gareId && tenues.has(hA.gareId);
    const tB = hB.gareId && tenues.has(hB.gareId);
    // On tient déjà un bout : c'est de là qu'on est parti, l'autre s'ouvre.
    // (`ajoute` ignore les gares tenues, le premier appel est donc sans effet.)
    if (tA || tB) { ajoute(hA.gareId); ajoute(hB.gareId); }
    // Aucun bout tenu : c'est la LIGNE DE DÉPART, prise à sa première gare,
    // donc parcourue depuis `a`. Seul le boss d'arrivée s'ouvre — le hub
    // d'origine, resté dans le dos du joueur, attend que celui-ci soit battu.
    // Il s'ouvrira alors de lui-même, par la boucle des hubs tenus ci-dessus.
    else ajoute(hB.gareId);
  }
  return out;
}

// Le graphe connaît-il cette gare ? Tant qu'il ne couvre pas tout le
// catalogue, c'est ce qui décide s'il a autorité sur elle — voir la règle de
// préséance dans js/catalog.js.
function dansLeGraphe(gareId) {
  buildGraphe();
  return !!GRAPHE.gares[gareId];
}
