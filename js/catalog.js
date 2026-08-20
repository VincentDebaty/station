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
// encaisser 81 % du tarif en moyenne pour que le réseau continue de croître.
// Avec les paliers géométriques, cela veut dire TROIS ÉTOILES : à ★★★ partout
// une gare en finance 1,25, à ★★ seulement 0,63, à ★ à peine 0,31. C'est voulu,
// et c'est plus exigeant qu'avant (où ★★ suffisait presque) — mais c'est la
// contrepartie d'une échelle qui récompense vraiment la ponctualité.
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

// ------------------------------------------------------------------
// LE PALMARÈS — quatre paliers, et l'argent est posé dessus.
// ------------------------------------------------------------------
// EXACTEMENT les mêmes chiffres qu'avant, lus dans l'autre sens.
//
// L'économie disait vrai mais parlait comptable : un plafond, un
// « encaissé 45 / 120 », un « Complet ». Un service à ★★★ — moins de dix
// minutes de retard sur une journée entière — pouvait donc s'achever sur un
// « +0 » gris et une jauge pleine. Le joueur ne lisait pas « cette gare a déjà
// payé ce niveau », il lisait « bien jouer ne rapporte rien ».
//
// Or la règle du plafond EST une échelle de paliers : le gain ne dépend que du
// retard, et le retard ne franchit que quatre seuils. Chacun se décroche une
// fois, verse son montant, et reste acquis. C'est le même calcul — un palier
// vaut le tarif cumulé de son cran moins celui du cran précédent, et leur
// somme fait le plafond au crédit près — mais il se lit comme une liste de
// choses à aller chercher plutôt que comme un compte qui se solde.
//
// Un « +0 » cesse d'être une punition : il dit qu'aucune ligne neuve n'a été
// cochée, et la ligne suivante est là, avec son prix.
//
// `under` est un seuil STRICT, en minutes entières (le retard est arrondi
// avant d'arriver ici) : « moins de 1 » est donc exactement « aucun retard ».
// CHAQUE PALIER DOUBLE CE QUE LA GARE A VERSÉ. C'est toute la règle, et elle
// tient dans la colonne des montants : 80, 80, 160, 320.
//
// Les multiplicateurs d'origine (0,5 · 0,75 · 1 · 2) faisaient une BOSSE et non
// une échelle. Mis en paliers, ils donnaient 160 · 80 · 80 · 320 : le cran le
// plus facile — finir la journée — payait le double des deux crans plus durs
// qui le suivaient. Un joueur qui s'améliore voyait sa récompense DIMINUER en
// montant, ce qui est exactement l'inverse de ce que le jeu promet.
//
// La progression géométrique n'a pas ce défaut, et elle a mieux : elle
// s'énonce. Ce que le joueur lit dans le palmarès, il peut le retenir sans
// l'apprendre — le pas suivant vaut toujours tout ce qui précède.
const PALIERS = [
  { under: 30, mult: 0.25, stars: 1, nom: "Service assuré", seuil: "moins de 30 min" },
  { under: 20, mult: 0.5,  stars: 2, nom: "Deux étoiles",   seuil: "moins de 20 min" },
  { under: 10, mult: 1,    stars: 3, nom: "Trois étoiles",  seuil: "moins de 10 min" },
  { under: 1,  mult: 2,    stars: 3, nom: "Sans faute",     seuil: "aucun retard", parfait: true }
];
// Le plus haut palier qu'un service à ce retard décroche — et donc tous ceux
// d'en dessous. −1 : rien, la journée ne compte pas.
function palierOf(delay) {
  if (delay == null) return -1;
  let k = -1;
  for (let i = 0; i < PALIERS.length; i++) if (delay < PALIERS[i].under) k = i;
  return k;
}
// CE QUE LA GARE A VERSÉ UNE FOIS LE PALIER k DÉCROCHÉ — le total cumulé, et
// la SEULE source de vérité : le montant d'un palier en est la différence, et
// la recette d'un service en est la valeur. Deux calculs séparés, et l'échelle
// affichée cesserait un jour de correspondre à l'argent versé.
//
// ARRONDI VERS LE BAS, ET C'EST ESSENTIEL. À l'arrondi au plus proche, un tarif
// de 50 donnait 13 · 12 · 25 · 50 : `Math.round(12,5)` monte à 13 et le premier
// palier volait un crédit au second, donc l'échelle REDESCENDAIT d'un cran
// entre une et deux étoiles. Un centime de travers suffit à démentir la règle
// que le palmarès affiche.
//
// Vers le bas, la monotonie est garantie et non plus espérée : les tarifs sont
// des multiples de 10 (round10), donc le premier palier vaut plancher(t/4) et
// le deuxième plafond(t/4) — le second est toujours ≥ au premier, quel que
// soit le tarif. Et la somme reste le plafond exact, puisque plancher(2t) = 2t.
function palierCumul(id, k) { return Math.floor(stationTarif(id) * PALIERS[k].mult); }
// Ce que verse le palier i, à lui seul.
function palierAmount(id, i) {
  return palierCumul(id, i) - (i ? palierCumul(id, i - 1) : 0);
}
// Le multiplicateur se DÉDUIT des paliers, il ne se redit pas : deux barèmes
// côte à côte finissent toujours par diverger, et celui qui paie ne serait pas
// forcément celui qui s'affiche.
function payoutMult(delay) {
  const k = palierOf(delay);
  return k < 0 ? 0 : PALIERS[k].mult;
}
// Ce qu'un service à ce retard vaut sur cette gare, plafond compris. C'est le
// CUMUL du palier atteint — pas un produit calculé à part, qui se serait mis à
// différer du palmarès d'un crédit dès le premier arrondi.
function stationPayout(id, delay) {
  const k = palierOf(delay);
  return k < 0 ? 0 : palierCumul(id, k);
}
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
// Combien de paliers cette gare a déjà rendus — 0 à 4. Rien à stocker : le
// record les résume tous, puisqu'ils sont emboîtés.
function stationTiersDone(id) {
  return palierOf((getProgress()[id] || {}).bestDelay) + 1;
}
// Le prochain à décrocher, ou −1 quand le palmarès est complet.
function stationNextTier(id) {
  const k = stationTiersDone(id);
  return k < PALIERS.length ? k : -1;
}
// CE QUE VAUT LE PROCHAIN PAS, et rien d'autre. C'est le chiffre que porte la
// carte sous une gare acquise, et le bouton « Rejouer ». Il remplace un
// « reste à encaisser jusqu'au plein tarif » qui se taisait sur les gares déjà
// à ★★★ — alors qu'il leur reste le sans-faute, c'est-à-dire le plus gros
// palier de tous.
function stationNextAmount(id) {
  const k = stationNextTier(id);
  return k < 0 ? 0 : palierAmount(id, k);
}

// ------------------------------------------------------------------
// LE PALMARÈS À L'ÉCRAN — écrit ICI, à côté des paliers qu'il montre.
// ------------------------------------------------------------------
// La fiche de gare et le relevé de fin de service montrent le même palmarès.
// Dessiné deux fois, il aurait divergé au premier réglage — c'est déjà arrivé
// à la jauge d'encaissement, qui se remplissait au tarif d'un côté et au
// plafond de l'autre.
//
// La colonne d'étoiles n'est pas un ornement : c'est le barème du jeu, celui
// qu'affiche le bandeau de fin de service. Le palmarès l'enseigne en montrant
// ce qu'il paie.
// L'échelle d'étoiles, en texte. Elle vivait dans la carte, qui n'existe plus
// sous cette forme — mais le palmarès, lui, reste. On la ramène auprès de ce
// qui s'en sert.
function starStr(n) { return "\u2605".repeat(n) + "\u2606".repeat(3 - n); }
// L'étoile creusée dans la pastille d'or : la marque du sans-faute, la même
// que portait la carte pour les gares parfaites.
const STAR_SVG = '<svg class="pf" viewBox="0 0 100 100" aria-hidden="true">' +
  '<polygon fill="currentColor" points="50,2 61,36 98,36 68,58 79,92 50,71 21,92 32,58 2,36 39,36"/></svg>';

function palierStarsHTML(p) {
  // Le sans-faute porte la marque de la CARTE — l'étoile creusée dans la
  // pastille d'or — et non un quatrième caractère ★, qui se lirait comme un
  // quatrième cran d'une échelle qui n'en compte que trois.
  if (p.parfait)
    return '<span class="map-chip city-chip perfect chip-inline pl-perf" style="--d:15px">' +
      '<span class="dot">' + (typeof STAR_SVG === "string" ? STAR_SVG : "") + "</span></span>";
  return '<span class="pl-st">' +
    (typeof starStr === "function" ? starStr(p.stars) : "") + "</span>";
}
// `owned` : une gare qu'on ne possède pas n'a rien décroché ni rien « en
// cours » — son palmarès est un argument de vente, pas un état.
function palmaresHTML(id, owned) {
  const done = owned ? stationTiersDone(id) : 0;
  const rows = PALIERS.map((p, i) => {
    const state = i < done ? "done" : (owned && i === done) ? "next" : "todo";
    return '<div class="pl-row ' + state + '">' +
      '<span class="pl-mk"></span>' + palierStarsHTML(p) +
      '<span class="pl-th">' + p.seuil + "</span>" +
      '<span class="pl-am">' + creditsHTML(palierAmount(id, i)) + "</span></div>";
  }).join("");
  return '<div class="palmares' + (owned ? "" : " sale") + '"><div class="pl-head"><span>Palmarès</span>' +
    '<span class="pl-sum">' +
      (owned ? done + " / " + PALIERS.length
             : "jusqu'à " + creditsHTML(stationCap(id))) +
    "</span></div>" + rows + "</div>";
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
// L'ensemble des gares acquises, sous la forme qu'attend le graphe.
function tenues() {
  const t = new Set();
  for (const c of CATALOG) if (isBought(c.id)) t.add(c.id);
  return t;
}
// DEUX SOURCES, DANS CET ORDRE DE PRÉSÉANCE — le même partage que js/network.js
// entre les lignes réelles et la déduction par portails.
//
// 1. LE GRAPHE (data/graph.js). Il dit qui s'ouvre depuis où : la gare suivante
//    du corridor qu'on parcourt, ou le choix d'une nouvelle sortie au bout.
//    Dès qu'il connaît une gare, il décide seul de son sort.
//
// 2. LA FRONTIÈRE GÉOGRAPHIQUE — transitoire. Le graphe ne couvre encore que
//    102 des 145 gares : les 43 autres attendent qu'un hub soit écrit. Les
//    laisser au graphe les rendrait injouables, ce qui serait une régression
//    pour rien. Elles gardent donc l'ancienne règle — s'ouvre ce qui touche
//    le réseau — jusqu'à ce que leur corridor existe.
function isBuyable(id) {
  if (!cardOf(id) || isBought(id)) return false;
  if (networkEmpty()) return isStartDoor(id);
  if (typeof dansLeGraphe === "function" && dansLeGraphe(id))
    return garesOuvrables(tenues()).has(id);
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
// N'existe plus comme verrou (voir buyBlock) : le jeu n'attend plus qu'une
// gare ait servi pour en ouvrir une autre. La fonction reste, et rend
// toujours null, parce que la carte et le relevé l'interrogent encore — elle
// disparaîtra avec eux au lot suivant.
function idleStation() { return null; }
// Les gares acquises qui touchent celle-ci — c'est de là qu'on peut s'étendre.
function ownedNeighbours(id) {
  if (typeof netLinks !== "function") return [];
  return netLinks(id).to.filter(nb => isBought(nb));
}
// En tient-on au moins une à ★★ ? Au tout début, le réseau est vide et la
// question ne se pose pas : les portes de départ n'ont aucune voisine acquise.
// Même sort : le mérite d'une voisine ne conditionne plus rien.
function openedFromMastered() { return true; }
// Ce qui empêche d'acheter cette gare MAINTENANT — dans l'ordre où le joueur
// peut y remédier. Rend null quand rien ne s'y oppose.
// LES PORTES DURES SONT TOMBÉES. « Réussir est facile, exceller est le vrai
// jeu » : plus rien n'oblige à rejouer une gare pour avancer. Les deux
// conditions de mérite — avoir fait tourner chaque gare acquise, tenir une
// voisine à deux étoiles — demandaient au joueur de revenir en arrière pour
// aller de l'avant. C'était le contraire de la promesse.
//
// Ce qui les remplace n'est pas rien : le GRAPHE. On ne s'ouvre plus n'importe
// quelle voisine, mais la suivante sur sa ligne — et l'on choisit sa direction
// au bout. La contrainte est devenue une lecture du réseau plutôt qu'une
// épreuve à repasser.
function buyBlock(id) {
  if (!isBuyable(id)) return null;
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

// ------------------------------------------------------------------
// LES JALONS D'UN PAYS — un horizon qu'on peut atteindre.
// ------------------------------------------------------------------
// Le seul repère de pays était « toutes les gares décrochées ». Sur la Belgique
// cela fait vingt-neuf gares, sur l'Allemagne trente-sept : un objectif si
// lointain qu'il ne se voit pas, et qui ne dit rien tant qu'il n'est pas
// atteint. Un joueur à la moitié d'un pays n'avait aucun moyen de le savoir,
// ni rien à fêter.
//
// Quatre jalons, en ÉTOILES et non en gares : le quart, la moitié, les trois
// quarts, le tout. En étoiles, parce que c'est la mesure fine — décrocher une
// gare de plus et améliorer une gare déjà tenue font toutes deux avancer le
// pays, ce qui est exactement ce qu'on veut encourager.
//
// AUCUN ÉTAT À STOCKER : les étoiles ne redescendent jamais, donc un jalon se
// franchit une fois et une seule. On le détecte en comparant le pays avant et
// après l'enregistrement du service — le même procédé que pour les paliers.
const JALONS = [
  { part: 0.25, nom: "Un quart du pays" },
  { part: 0.5,  nom: "La moitié du pays" },
  { part: 0.75, nom: "Trois quarts du pays" },
  { part: 1,    nom: "Pays terminé" }
];
// Étoiles décrochées / possibles sur un pays, et le nombre de gares tenues.
function countryStars(country) {
  const prog = getProgress();
  let earned = 0, total = 0, done = 0, n = 0;
  for (const c of CATALOG) {
    if (c.country !== country) continue;
    const s = (prog[c.id] || {}).stars || 0;
    n++; total += 3; earned += s; if (s >= 1) done++;
  }
  return { earned, total, done, n, part: total ? earned / total : 0 };
}
// Le plus haut jalon franchi, ou −1.
function jalonOf(part) {
  let k = -1;
  for (let i = 0; i < JALONS.length; i++) if (part >= JALONS[i].part - 1e-9) k = i;
  return k;
}
// LA PRIME D'UN JALON SE PAIE EN PONCTUALITÉ, JAMAIS EN CRÉDITS. La masse
// monétaire du jeu est finie, connue et vérifiée (tools/eco-check.mjs) ; y
// verser des primes la rendrait fausse, et surtout cela reviendrait à financer
// l'expansion par autre chose que le mérite d'une gare. Un jalon est un fait
// d'armes : il se consigne, il ne s'encaisse pas.
function jalonBonus(country) {
  let tarif = 0;
  for (const c of CATALOG) if (c.country === country) tarif += stationTarif(c.id);
  return Math.round(tarif * 0.1);
}

// ------------------------------------------------------------------
// LA PONCTUALITÉ — ce qui récompense CHAQUE minute, sur CHAQUE service.
// ------------------------------------------------------------------
// Les crédits sont un escalier : quatre paliers, décrochés une fois, et une
// gare finie ne verse plus rien. C'est ce qui empêche le farming, et il faut le
// garder. Mais cela laisse un trou : sur une gare au palmarès complet, un
// service impeccable ne vaut pas mieux qu'un service médiocre — les deux
// rapportent zéro. Or c'est précisément la promesse du jeu qui s'y perd.
//
// D'où un SECOND compteur, qui n'achète rien et ne se dépense pas :
//
//   ponctualité = tarif × (1 − retard / 30)
//
// Continu, donc chaque minute gagnée se voit ; proportionnel au tarif, donc
// tenir une grande gare vaut plus que tenir une petite ; nul à trente minutes,
// comme les étoiles. Et versé à CHAQUE service, sans plafond ni record à
// battre.
//
// POURQUOI CELA NE ROUVRE PAS LE FARMING : ces points n'achètent aucune gare.
// Les répéter ne fait avancer que le grade, c'est-à-dire un titre. Et comme le
// barème suit le tarif, s'acharner sur une gare de difficulté 1 rapporte huit
// fois moins que de bien tenir une difficulté 5 — le raccourci est plus long
// que le chemin.
function pointsFor(id, delay) {
  if (delay == null || delay >= 30) return 0;
  return Math.round(stationTarif(id) * (1 - Math.max(0, delay) / 30));
}
// Reconstitution pour une sauvegarde d'avant la ponctualité : ce que le joueur
// aurait accumulé si le compteur avait toujours existé — un service par gare,
// à son meilleur retard. Sous-estime forcément (il a joué plus d'une fois),
// et c'est le bon sens de l'erreur : on ne crédite que ce qui est prouvé.
function reconstructPoints() {
  const prog = getProgress();
  let total = 0;
  for (const c of CATALOG) total += pointsFor(c.id, (prog[c.id] || {}).bestDelay);
  return total;
}
// Appelé une fois, après que le magasin ET le catalogue sont chargés.
function ensurePoints() {
  if (typeof pointsPending === "function" && pointsPending()) setPoints(reconstructPoints());
}

// LES GRADES — un titre, pas un pouvoir. Ils ne débloquent rien : ils
// enregistrent. Les seuils doublent presque à chaque cran, pour que le premier
// arrive vite (il faut sentir que le compteur sert à quelque chose) et que le
// dernier reste un horizon lointain.
const GRADES = [
  { at: 0,     nom: "Aiguilleur stagiaire" },
  { at: 1200,  nom: "Aiguilleur" },
  { at: 3500,  nom: "Chef de poste" },
  { at: 9000,  nom: "Chef de district" },
  { at: 20000, nom: "Régulateur" },
  { at: 45000, nom: "Inspecteur général" }
];
// Le grade courant, et ce qu'il reste avant le suivant. `next` vaut null au
// dernier : il n'y a alors plus de barre à remplir, et c'est une distinction.
function gradeOf(points) {
  let i = 0;
  for (let k = 0; k < GRADES.length; k++) if (points >= GRADES[k].at) i = k;
  const next = GRADES[i + 1] || null;
  return {
    i, nom: GRADES[i].nom, from: GRADES[i].at, next,
    // Part du chemin parcouru vers le grade suivant, de 0 à 1.
    part: next ? (points - GRADES[i].at) / (next.at - GRADES[i].at) : 1
  };
}

// ------------------------------------------------------------------
// LE PAS SUIVANT — les trois gestes qui font avancer, et rien d'autre.
// ------------------------------------------------------------------
// Le relevé de fin de service désigne une action et une seule (js/game.js) ;
// la carte doit désigner LA MÊME, sinon le jeu se contredit d'un écran à
// l'autre. Les briques vivent donc ici, avec la progression qu'elles lisent,
// et chaque écran les compose selon ce qu'il sait de son contexte — le relevé
// peut proposer « rejouer ici », la carte n'a pas d'« ici ».
//
// `from` : la gare d'où l'on regarde, s'il y en a une. Elle ne restreint pas le
// choix, elle l'ORDONNE : à mérite égal, on ne renvoie pas le joueur à l'autre
// bout de l'Europe.
function nearFirst(from) {
  const near = (from && typeof netLinks === "function") ? netLinks(from).to : [];
  return id => (near.indexOf(id) >= 0 ? 0 : 1);
}
// La gare la moins chère qu'on puisse ouvrir MAINTENANT — voisine d'abord.
function cheapestBuyableNear(from) {
  const rank = nearFirst(from);
  const cand = CATALOG.filter(c => canBuy(c.id));
  if (!cand.length) return null;
  cand.sort((a, b) => rank(a.id) - rank(b.id) || stationPrice(a.id) - stationPrice(b.id));
  return cand[0].id;
}
// Une gare à soi qui a encore un palier à décrocher — voisine d'abord, facile
// d'abord : le joueur vient chercher un palier, pas une épreuve.
function bestOwnedWithTier(from) {
  const rank = nearFirst(from);
  const cand = CATALOG.filter(c =>
    c.id !== from && isBought(c.id) && stationNextAmount(c.id) > 0);
  if (!cand.length) return null;
  cand.sort((a, b) => rank(a.id) - rank(b.id) || stationDifficulty(a.id) - stationDifficulty(b.id));
  return cand[0].id;
}
// Ce que la CARTE propose : les trois mêmes cas que le relevé, moins « rejouer
// ici » — sur la carte, il n'y a pas d'ici. Rend null quand il n'y a plus rien
// à proposer : mieux vaut se taire que d'inventer un geste.
function nextMove(from) {
  const idle = idleStation();
  if (idle && idle !== from) return { kind: "service", id: idle };
  const buy = cheapestBuyableNear(from);
  if (buy) return { kind: "open", id: buy };
  const go = bestOwnedWithTier(from);
  if (go) return { kind: "go", id: go };
  return null;
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
// `countryComplete` a été retiré : « pays terminé » n'est plus un cas
// particulier mais le dernier des quatre JALONS, et il se mesure en ÉTOILES et
// non en gares décrochées. L'ancienne définition — « toutes les gares à au
// moins une étoile » — déclarait un pays fini alors qu'il pouvait lui rester
// les deux tiers de ses étoiles à prendre.
