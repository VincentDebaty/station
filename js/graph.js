"use strict";
// ------------------------------------------------------------------
// LE GRAPHE, VU DU JEU — où suis-je, et où puis-je aller ?
// ------------------------------------------------------------------
// data/graph.js décrit le réseau ; ce fichier répond aux questions que le jeu
// lui pose. Rien ici ne dessine et rien n'écrit : la carte consomme ces
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

const GRAPHE = { pret: false, hubs: {}, gares: {}, sorties: {}, corridors: [] };

function buildGraphe() {
  if (GRAPHE.pret) return;
  GRAPHE.hubs = {}; GRAPHE.gares = {}; GRAPHE.sorties = {}; GRAPHE.corridors = [];
  if (typeof HUBS === "undefined") return;

  for (const h of HUBS) { GRAPHE.hubs[h.id] = h; GRAPHE.sorties[h.id] = []; }

  // Le nom d'une fiche du catalogue → l'id du hub qui la joue. Le graphe
  // désigne ses hubs par le NOM de la gare (« Bruxelles ») ; le jeu les
  // connaît par leur id (« bruxelles-midi »). La table se construit une fois.
  if (typeof CATALOG !== "undefined")
    for (const c of CATALOG) {
      const h = HUBS.find(x => x.gare === (c.city || c.name));
      if (h) { GRAPHE.gares[c.id] = { role: "hub", hub: h.id }; h.gareId = c.id; }
    }

  // Chaque lien devient une SORTIE de ses deux extrémités : une ligne se
  // parcourt dans les deux sens, il n'y a pas de sens privilégié.
  for (const [a, b, type] of LIENS) {
    const corr = CORRIDORS.find(c =>
      (c.de === a && c.vers === b) || (c.de === b && c.vers === a));
    const lien = { a, b, type: type || "rail", gares: corr ? corr.gares : null };
    GRAPHE.corridors.push(lien);
    if (GRAPHE.sorties[a]) GRAPHE.sorties[a].push(lien);
    if (GRAPHE.sorties[b]) GRAPHE.sorties[b].push(lien);
    for (const g of (lien.gares || [])) GRAPHE.gares[g] = { role: "corridor", lien };
  }
  GRAPHE.pret = true;
}

// --- Lecture --------------------------------------------------------
function hubById(id) { buildGraphe(); return GRAPHE.hubs[id] || null; }
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
