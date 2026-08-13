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

// ------------------------------------------------------------------
// ÉCONOMIE — le tarif, le prix, et le seuil qui tient tout.
// ------------------------------------------------------------------
// Une gare RAPPORTE quand on la joue et COÛTE quand on l'ouvre. Les deux
// dérivent d'une SEULE valeur de gare : s'ils suivaient deux formules
// distinctes, l'équilibre se perdrait à la première gare ajoutée au catalogue
// et plus personne ne pourrait le vérifier.
//
// Le prix vaut 80 % du tarif — juste sous le gain d'un service à trois étoiles,
// pour qu'un sans-faute reste toujours payant. Il en découle un SEUIL : il faut
// encaisser 81 % du tarif en moyenne pour que le réseau continue de croître,
// soit un peu mieux que deux étoiles. À une étoile partout, chaque gare ne
// finance que 0,6 gare : on s'arrête. C'est voulu — s'étendre exige de bien
// jouer.
//
// S'arrêter n'est pas être coincé : une gare possédée peut encore rapporter
// jusqu'à deux fois son tarif (voir stationGain), soit 2,5 fois son propre
// prix. Il suffit d'aller s'améliorer sur une gare déjà acquise pour repartir.
//
// PRIX_RATIO est LE réglage sensible du jeu : il décide si le jeu est exigeant
// ou décourageant. Il vit ici, seul, changeable d'un caractère.
const PRIX_RATIO = 0.8;
const CREDITS_START = 150;          // dotation : la 1ʳᵉ gare (50) + la 2ᵉ (100)
// Tarif de base par difficulté = ce que paie un service à TROIS étoiles.
// Les écarts croissent (60, 80, 100, 120) : une gare de difficulté 5 n'est pas
// cinq fois une gare de difficulté 1, elle est bien plus que cela.
const TARIF = { 1: 60, 2: 120, 3: 200, 4: 300, 5: 420 };
const round10 = n => Math.max(10, Math.round(n / 10) * 10);

// Le crédit a un VISAGE, pas un nom : le mot ne sert qu'à l'accueil et au
// premier achat, partout ailleurs c'est ce jeton qui précède le nombre. Un
// hexagone, et non une pièce ronde : sur la carte, tout ce qui est rond est une
// gare — une pièce y serait une gare de plus. Plein, sans trou : à 12 px un
// évidement se referme et le jeton devient une tache.
const CREDIT_PICTO =
  '<svg class="cr" viewBox="0 0 12 12" aria-hidden="true">' +
  '<polygon points="11,6 8.5,10.33 3.5,10.33 1,6 3.5,1.67 8.5,1.67"/></svg>';
// Un montant s'écrit toujours pareil : le jeton, collé au nombre, signe compris.
function creditsHTML(n, signed) {
  n = Math.round(n || 0);
  return '<span class="cr-amt">' + CREDIT_PICTO + (signed && n >= 0 ? "+" : "") + n + "</span>";
}

function cardOf(id) { return CATALOG.find(x => x.id === id) || null; }
function stationDifficulty(id) {
  const c = cardOf(id);
  return c ? Math.max(1, Math.min(5, c.difficulty || 1)) : 1;
}
// Flux : cadence moyenne des arrivées, en 5 crans (1 = calme, 5 = tendu). Pris
// à la source du générateur pour que la fiche de gare, la carte et l'économie
// ne puissent jamais se contredire.
function stationFlux(id) {
  const gen = (cardOf(id) || {}).gen || {};
  if (gen.gapMin == null) return 3;
  const scale = (typeof ARRIVAL_GAP_SCALE === "number") ? ARRIVAL_GAP_SCALE : 1;
  const cadence = (gen.gapMin + gen.gapMax) / 2 * scale;
  return cadence <= 1.65 ? 5 : cadence <= 1.78 ? 4 : cadence <= 1.92 ? 3 : cadence <= 2.05 ? 2 : 1;
}
// Le flux ajuste le tarif de ±10 % — un réglage fin sur l'axe principal qu'est
// la difficulté, jamais un second axe.
function stationTarif(id) {
  return round10(TARIF[stationDifficulty(id)] * (1 + 0.05 * (stationFlux(id) - 3)));
}
function stationPrice(id) { return round10(stationTarif(id) * PRIX_RATIO); }
// Plafond : ce qu'une gare peut rapporter en tout, sur toute une vie de joueur.
// La masse monétaire du jeu est donc finie et connue — le farming est impossible.
function stationCap(id) { return stationTarif(id) * 2; }

// Multiplicateur de gain, en quarts de tarif. Ce sont EXACTEMENT les paliers
// d'étoiles (10 / 20 / 30 min) : aucun barème nouveau à apprendre, et le
// bandeau de service enseigne l'un en montrant l'autre.
//   parfait ×2 · ★★★ ×1 · ★★☆ ×0,75 · ★☆☆ ×0,5 · échec ×0
function payoutMult(delay) {
  if (delay == null || delay >= 30) return 0;
  if (delay <= 0) return 2;
  return delay < 10 ? 1 : delay < 20 ? 0.75 : 0.5;
}
// Ce qu'un service à ce retard vaut sur cette gare, plafond compris.
function stationPayout(id, delay) { return Math.round(stationTarif(id) * payoutMult(delay)); }
// Ce que la gare a DÉJÀ versé. Aucun champ à stocker : le meilleur encaissement
// se déduit du meilleur record, puisque le gain ne dépend que du retard.
function stationBanked(id) {
  const rec = (getProgress()[id] || {});
  return rec.bestDelay == null ? 0 : stationPayout(id, rec.bestDelay);
}
// LA RÈGLE DU PLAFOND : une gare ne paie que la PROGRESSION. Rejouer ne
// rapporte que si l'on joue mieux qu'avant — c'est ce qui rend le grind
// inutile et le retour sur une gare connue payant.
function stationGain(id, delay) {
  return Math.max(0, stationPayout(id, delay) - stationBanked(id));
}

// ------------------------------------------------------------------
// POSSESSION ET FRONTIÈRE.
// ------------------------------------------------------------------
// On joue ce qu'on possède, on achète ce qui touche à son réseau. Tant que le
// réseau est VIDE, toutes les gares les plus faciles sont achetables, où
// qu'elles soient : c'est le choix du pays de départ. Dès la première achetée,
// la frontière géographique s'applique et les autres portes se ferment
// d'elles-mêmes — sans règle dédiée.
const START_DIFFICULTY = 1;

function isUnlocked(i) {
  const c = CATALOG[i];
  return !!c && isBought(c.id);
}
// Réseau encore vide : la partie n'a pas commencé.
function networkEmpty() { return !CATALOG.some(c => isBought(c.id)); }
// Une gare de départ doit MENER quelque part : une gare facile sans voisine au
// catalogue est un piège, le joueur s'y engage et n'en sort jamais.
function isStartDoor(id) {
  if (stationDifficulty(id) > START_DIFFICULTY) return false;
  return typeof netLinks === "function" &&
    netLinks(id).to.some(nb => CATALOG.some(c => c.id === nb));
}
// Achetable = pas encore acquise, et reliée au réseau déjà acquis. C'est la
// FRONTIÈRE GÉOGRAPHIQUE, et elle seule : ce qui empêche de payer aujourd'hui
// (l'argent, une gare en souffrance, le niveau) se dit à part — voir buyBlock.
function isBuyable(id) {
  if (!cardOf(id) || isBought(id)) return false;
  if (networkEmpty()) return isStartDoor(id);
  return typeof netLinks === "function" && netLinks(id).to.some(nb => isBought(nb));
}
function canAfford(id) { return getCredits() >= stationPrice(id); }

// ------------------------------------------------------------------
// DEUX CONDITIONS QUI NE S'ACHÈTENT PAS.
// ------------------------------------------------------------------
// L'argent seul faisait une progression sans mérite : une gare maîtrisée en
// finance DEUX ET DEMIE (plafond 2 × tarif contre un prix de 0,8 × tarif), donc
// le réseau grossissait plus vite qu'on ne l'apprenait. On pouvait mettre
// quatre gares en réserve sans en jouer une seule, et s'offrir Bruxelles-Midi
// avec les recettes de Dinant — les neuf gares de difficulté 1 de Belgique
// coûtent 430 et rapportent 1 040 une fois maîtrisées.
//
// D'où deux verrous qui ne se paient pas :
//
//   1. LE RÉSEAU DOIT TOURNER. Tant qu'une gare acquise n'a pas assuré un
//      service entier, on n'en achète pas d'autre. Acheter, jouer, acheter :
//      un réseau n'est pas une collection.
//   2. ON N'OUVRE UNE GARE QUE DEPUIS UNE VOISINE BIEN TENUE. Il faut ★★ sur
//      au moins une des gares déjà acquises qui la touchent. L'argent gagné
//      ailleurs n'ouvre plus rien tout seul : il faut tenir l'endroit d'où l'on
//      s'étend.
//
//      Formulée en PALIERS DE DIFFICULTÉ (« niveau d exige ★★ au niveau d−1 »),
//      la règle enfermait le joueur : 11 des 32 portes de départ n'ont que des
//      voisines de niveau 3 à 5 — Lokeren touche Gand, Termonde et Anvers,
//      Regensburg touche Nürnberg et München. Une petite gare à côté d'un grand
//      nœud, c'est la géographie normale, et aucune règle de progression n'a le
//      droit de la déclarer sans issue. La version locale n'a pas ce défaut :
//      elle ne demande jamais que de bien tenir une gare qu'on possède DÉJÀ,
//      donc elle est toujours satisfaisable.
//
// Aucune des deux ne se contourne avec un solde plus gros. Toutes deux se
// disent en clair sur la fiche de gare : un blocage muet serait pire que pas
// de blocage du tout.
const OPEN_STARS = 2;

// Une gare a « assuré un service » dès qu'une journée y a été menée à son
// terme — même sans étoile. C'est le service qui compte, pas le résultat :
// exiger une étoile enfermerait le joueur qui a acheté trop dur pour lui.
function stationInService(id) {
  return (getProgress()[id] || {}).bestDelay != null;
}
// La première gare acquise qui n'a jamais servi, s'il y en a une.
function idleStation() {
  for (const c of CATALOG) if (isBought(c.id) && !stationInService(c.id)) return c.id;
  return null;
}
// Les gares acquises qui touchent celle-ci — c'est de là qu'on peut s'étendre.
function ownedNeighbours(id) {
  if (typeof netLinks !== "function") return [];
  return netLinks(id).to.filter(nb => isBought(nb));
}
// En tient-on au moins une à ★★ ? Au tout début, le réseau est vide et la
// question ne se pose pas : les portes de départ n'ont aucune voisine acquise.
function openedFromMastered(id) {
  if (networkEmpty()) return true;
  const prog = getProgress();
  return ownedNeighbours(id).some(nb => (prog[nb] || {}).stars >= OPEN_STARS);
}
// Ce qui empêche d'acheter cette gare MAINTENANT — dans l'ordre où le joueur
// peut y remédier. Rend null quand rien ne s'y oppose.
function buyBlock(id) {
  if (!isBuyable(id)) return null;
  const idle = idleStation();
  if (idle) return { kind: "service", id: idle };
  if (!openedFromMastered(id)) return { kind: "maitrise", from: ownedNeighbours(id) };
  const short = stationPrice(id) - getCredits();
  if (short > 0) return { kind: "argent", short };
  return null;
}
// Achetable ET payable ET débloquée : le seul cas où le geste est possible.
function canBuy(id) { return isBuyable(id) && !buyBlock(id); }
// Achat : passe par le magasin, qui décrémente et mémorise atomiquement.
function buyStationById(id) {
  return canBuy(id) && buyStation(id, stationPrice(id));
}

// La moins chère des gares achetables — d'un pays donné, ou du réseau entier.
// Sert à proposer une suite quand le joueur clique une gare hors de portée.
function cheapestBuyable(country) {
  let best = -1, bestP = Infinity;
  for (let i = 0; i < CATALOG.length; i++) {
    const c = CATALOG[i];
    if (country && c.country !== country) continue;
    if (!canBuy(c.id)) continue;
    const p = stationPrice(c.id);
    if (p < bestP) { bestP = p; best = i; }
  }
  return best;
}
// Pays « terminé » = toutes ses gares décrochées (≥ 1 étoile). Sert à souligner
// l'achèvement d'un pays en fin de service.
function countryComplete(i) {
  const country = CATALOG[i] && CATALOG[i].country;
  if (!country) return false;
  const prog = getProgress();
  return CATALOG.every(c => c.country !== country || ((prog[c.id] || {}).stars || 0) >= 1);
}
