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
// CE QU'UN SERVICE RAPPORTE — des étoiles, et rien d'autre.
// ------------------------------------------------------------------
// Il y avait ici une économie entière : un tarif par difficulté, un prix
// d'achat, un plafond de recette par gare, un compteur de ponctualité, et un
// contrôle d'équilibre (tools/eco-check.mjs) pour que le tout reste soluble.
// Elle était juste, et elle a été retirée.
//
// LA RAISON : une monnaie qui n'achète qu'UNE SEULE CHOSE n'est pas une
// monnaie, c'est un compteur de déblocage déguisé. Le joueur ne ressentait pas
// la valeur de ce qu'il gagnait, parce qu'il n'avait jamais rien à en faire —
// et les vrais verrous étaient ailleurs (le mérite, puis le réseau).
//
// La ponctualité souffrait du même mal en pire : un second compteur, invisible
// partout sauf sur un badge, qui doublait ce que les étoiles disent déjà.
//
// Reste donc l'échelle des PALIERS. Elle ne paie plus, elle NOMME : quatre
// crans de retard, décrochés une fois, qui disent au joueur ce qu'il vient de
// faire et ce qui l'attend s'il revient.

function cardOf(id) { return CATALOG.find(x => x.id === id) || null; }
function stationDifficulty(id) {
  const c = cardOf(id);
  return c ? Math.max(1, Math.min(5, c.difficulty || 1)) : 1;
}

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

function stationTiersDone(id) {
  return palierOf((getProgress()[id] || {}).bestDelay) + 1;
}
// Le prochain à décrocher, ou −1 quand le palmarès est complet.
function stationNextTier(id) {
  const k = stationTiersDone(id);
  return k < PALIERS.length ? k : -1;
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
      "</div>";
  }).join("");
  return '<div class="palmares' + (owned ? "" : " sale") + '"><div class="pl-head"><span>Palmarès</span>' +
    '<span class="pl-sum">' +
      done + " / " + PALIERS.length +
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
  // LE PREMIER GESTE EST LE CHOIX D'UNE LIGNE (js/graph.js, lignesDeDepart) :
  // seules s'ouvrent les gares qui suivent immédiatement un hub. `isStartDoor`
  // ne sert plus que de filet, tant qu'aucun corridor n'est assez long pour
  // faire une ligne de départ — il ouvrait des gares faciles sans lendemain,
  // choisies pour leur difficulté et non pour ce qu'elles amorcent.
  if (networkEmpty()) {
    const dep = typeof garesDeDepart === "function" ? garesDeDepart() : null;
    return dep && dep.size ? dep.has(id) : isStartDoor(id);
  }
  if (typeof dansLeGraphe === "function" && dansLeGraphe(id))
    return garesOuvrables(tenues()).has(id);
  return typeof netLinks === "function" && netLinks(id).to.some(nb => isBought(nb));
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
// PLUS RIEN NE BLOQUE. Les crédits étaient le dernier verrou, et c'était le
// plus faible des trois : les deux autres — jouer ce qu'on possède, tenir une
// voisine à deux étoiles — faisaient déjà tout le travail, et sont tombés avec
// le lot 2. Une monnaie qui n'achète qu'une seule chose n'est pas une monnaie,
// c'est un compteur de déblocage déguisé ; on ne ressentait donc pas la valeur
// de ce qu'on gagnait.
//
// Ce qui ouvre une gare, désormais, c'est le RÉSEAU : la suivante sur sa ligne,
// et le choix d'une direction au bout d'un corridor. La fonction reste, et rend
// toujours null, parce que la carte et le relevé l'interrogent encore.
function buyBlock() { return null; }
// Achetable ET payable ET débloquée : le seul cas où le geste est possible.
function canBuy(id) { return isBuyable(id) && !buyBlock(id); }
// Achat : passe par le magasin, qui décrémente et mémorise atomiquement.
// Ouvrir une gare ne coûte plus rien : le magasin n'enregistre plus qu'un fait.
function buyStationById(id) {
  return canBuy(id) && buyStation(id, 0);
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


// LES GRADES — un titre, pas un pouvoir. Ils ne débloquent rien : ils
// enregistrent. Les seuils doublent presque à chaque cran, pour que le premier
// arrive vite (il faut sentir que le compteur sert à quelque chose) et que le
// dernier reste un horizon lointain.
// LE GRADE SE COMPTE EN ÉTOILES, plus en ponctualité. Un compteur qu'on ne
// voit nulle part ailleurs ne se ressent pas : la ponctualité montait en
// silence, et son grade avec elle. Les étoiles, elles, sont sur chaque gare de
// la carte — le joueur sait déjà où il en est, le grade ne fait que le nommer.
//
// L'échelle est celle du document : dix crans, espacés de plus en plus, pour
// que le premier arrive vite et le dernier reste un horizon. Le catalogue
// actuel plafonne à 435 étoiles (145 gares à trois) — « Légende du rail »
// suppose donc un réseau bien plus vaste, et c'est voulu.
const GRADES = [
  { at: 0,    nom: "Aiguilleur stagiaire" },
  { at: 25,   nom: "Aiguilleur" },
  { at: 75,   nom: "Chef de quai" },
  { at: 150,  nom: "Chef de gare" },
  { at: 300,  nom: "Chef de ligne" },
  { at: 600,  nom: "Régulateur" },
  { at: 1000, nom: "Inspecteur" },
  { at: 1600, nom: "Directeur régional" },
  { at: 2400, nom: "Directeur de réseau" },
  { at: 3500, nom: "Légende du rail" }
];
// Le total d'étoiles décrochées, toutes gares confondues. Rien à stocker : les
// étoiles ne redescendent jamais, la progression les porte déjà.
function etoilesTotal() {
  const prog = getProgress();
  let n = 0;
  for (const c of CATALOG) n += (prog[c.id] || {}).stars || 0;
  return n;
}
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
// LA GARE QU'ON OUVRE ENSUITE. Le nom dit encore « la moins chère » : c'est un
// vestige, il n'y a plus de prix. Ce qu'elle rend, c'est LA SUITE DU CHEMIN.
//
// Deux fois corrigée, et la seconde fois pour la même raison que la première :
// le prix, puis la géographie, décidaient de la direction à la place du graphe.
//
//   1re version — la moins chère, voisine d'abord. D'où « ouvrir Dinant » au
//      bout d'un service à Namur : Dinant est proche, et bon marché, mais elle
//      n'est pas sur la ligne de Luxembourg.
//   2e version — le corridor d'où l'on vient, puis repli géographique. Mieux,
//      mais elle proposait ENCORE Dinant dès que ce corridor était fini : plus
//      rien à ouvrir sur la ligne, donc repli — alors que Bruxelles et
//      Luxembourg, ses deux termini, ouvrent chacun trois autres lignes.
//
// L'ordre ci-dessous épuise le graphe AVANT de sortir du graphe, et c'est le
// point : on ne quitte le réseau que lorsqu'il n'a plus rien à offrir.
function cheapestBuyableNear(from) {
  if (typeof garesOuvrables === "function" && typeof parcours === "function") {
    const ouvrables = garesOuvrables(tenues());
    const prenable = g => !!g && ouvrables.has(g) && canBuy(g);
    const gareDe = h => (hubById(h) || {}).gareId;
    // Une ligne lue DEPUIS un bout donné : ses gares dans l'ordre, puis le
    // terminus opposé. C'est l'ordre dans lequel on avance dessus.
    const depuis = (l, h) => { const p = parcours(l, h); return [...p.gares, gareDe(p.vers)]; };

    // 1. LA LIGNE OÙ L'ON EST, et d'abord la gare VOISINE : sur un corridor,
    //    la suite est le maillon d'à côté, pas le premier de la liste.
    const lien = typeof corridorDeGare === "function" ? corridorDeGare(from) : null;
    if (lien) {
      const compo = [gareDe(lien.a), ...(lien.gares || []), gareDe(lien.b)].filter(Boolean);
      const i = compo.indexOf(from);
      if (i >= 0) for (const j of [i + 1, i - 1]) if (prenable(compo[j])) return compo[j];
      const reste = compo.find(prenable);
      if (reste) return reste;
    }
    // 2. LES LIGNES QUI PARTENT D'ICI — du boss où l'on se trouve, ou des deux
    //    termini de la ligne qu'on vient de finir. C'est le carrefour : on y
    //    choisit une direction, et le relevé en propose une (la carte les
    //    montre toutes).
    const carrefours = [];
    const ici = typeof hubDeGare === "function" ? hubDeGare(from) : null;
    if (ici) carrefours.push(ici.id);
    if (lien) carrefours.push(lien.a, lien.b);
    for (const h of carrefours)
      for (const l of sortiesDeHub(h)) {
        const g = depuis(l, h).find(prenable);
        if (g) return g;
      }
    // 3. N'IMPORTE OÙ DANS LE GRAPHE. Le réseau est vaste et le joueur peut
    //    tenir plusieurs lignes à la fois ; se taire ici l'enverrait hors du
    //    graphe alors qu'il lui reste des corridors entiers à ouvrir.
    for (const g of ouvrables) if (prenable(g)) return g;
  }
  // 4. HORS GRAPHE, et seulement là. Les 68 gares du catalogue qu'aucun
  //    corridor n'atteint encore attendent leurs hubs ; en attendant, elles
  //    restent jouables, voisine d'abord.
  const rank = nearFirst(from);
  const cand = CATALOG.filter(c => canBuy(c.id) &&
    !(typeof dansLeGraphe === "function" && dansLeGraphe(c.id)));
  if (!cand.length) return null;
  cand.sort((a, b) => rank(a.id) - rank(b.id));
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
  return null;
}

// La moins chère des gares achetables — d'un pays donné, ou du réseau entier.
// Sert à proposer une suite quand le joueur clique une gare hors de portée.
function cheapestBuyable(country) {
  for (let i = 0; i < CATALOG.length; i++) {
    const c = CATALOG[i];
    if (country && c.country !== country) continue;
    if (canBuy(c.id)) return i;
  }
  return -1;
}
// `countryComplete` a été retiré : « pays terminé » n'est plus un cas
// particulier mais le dernier des quatre JALONS, et il se mesure en ÉTOILES et
// non en gares décrochées. L'ancienne définition — « toutes les gares à au
// moins une étoile » — déclarait un pays fini alors qu'il pouvait lui rester
// les deux tiers de ses étoiles à prendre.
