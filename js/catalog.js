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
  // LE LIBELLÉ D'UN PAYS VIT UNE FOIS, DANS L'INDEX. Il était recopié dans les
  // 401 fiches (« 🇬🇧 Royaume-Uni ») et redécoupé à la ficelle partout où il
  // fallait le drapeau : `cfg.country.split(" ")[0]`. Une fiche dit désormais
  // DE QUEL pays elle est — son slug — et l'affichage se déduit ici, en un
  // seul endroit. Traduire le nom d'un pays ne touche plus qu'une ligne.
  for (const group of index) {
    const l = (group.label || "").trim(), i = l.indexOf(" ");
    PAYS[group.country] = i > 0
      ? { label: l, drapeau: l.slice(0, i), nom: l.slice(i + 1) }
      : { label: l, drapeau: "", nom: l || group.country };
  }
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

// Les pays, par slug : { label, drapeau, nom }. Rempli par loadCatalog.
const PAYS = {};
function paysDe(slug) { return PAYS[slug] || { label: "", drapeau: "", nom: slug || "" }; }

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

// ------------------------------------------------------------------
// POSSESSION ET FRONTIÈRE.
// ------------------------------------------------------------------
// On joue ce qu'on possède, on achète ce qui touche à son réseau. Tant que le
// réseau est VIDE, toutes les gares les plus faciles sont achetables, où
// qu'elles soient : c'est le choix du pays de départ. Dès la première achetée,
// la frontière géographique s'applique et les autres portes se ferment
// d'elles-mêmes — sans règle dédiée.
const START_DIFFICULTY = 1;

// Réseau encore vide : la partie n'a pas commencé.
function networkEmpty() { return !CATALOG.some(c => isBought(c.id)); }
// Une gare de départ doit MENER quelque part : une gare facile sans voisine au
// catalogue est un piège, le joueur s'y engage et n'en sort jamais.
function isStartDoor(id) {
  if (stationDifficulty(id) > START_DIFFICULTY) return false;
  return typeof netLinks === "function" &&
    netLinks(id).to.some(nb => CATALOG.some(c => c.id === nb));
}

// ------------------------------------------------------------------

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
// Le total d'étoiles décrochées, toutes gares et TOUTES CARTES confondues.
// Rien à stocker : les étoiles ne redescendent jamais, la progression les
// porte déjà. Le grade est un fait de COMPTE, pas de carte : on ne repart pas
// stagiaire en ouvrant une deuxième carte.
function etoilesTotal() {
  const tables = typeof getProgressToutesCartes === "function"
    ? getProgressToutesCartes() : [getProgress()];
  let n = 0;
  for (const prog of tables) for (const id in prog) n += (prog[id] || {}).stars || 0;
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

// LA PROGRESSION PAR PAYS A ÉTÉ RETIRÉE (lot J). Le pays n'est plus une unité
// de jeu : c'est le RUBAN qui ordonne les gares, et le chapitre qui se fête
// (js/ruban.js, js/recompense.js). Sont partis avec elle `isUnlocked`,
// `countryComplete`, les `JALONS`, l'achat de gare (`canBuy`, `isBuyable`,
// `buyStationById`, `cheapestBuyable*`) et la proposition `nextMove` — ils
// décrivaient un jeu où l'on choisissait sa gare, ce qui n'existe plus.
//
// CE QUI RESTE ICI sert encore : le chargement du catalogue, la carte d'une
// gare, les paliers et grades de compte, le total d'étoiles, et `isStartDoor`
// — cette dernière parce que `tools/net-check.mjs` la charge pour décider
// d'une porte de départ, et que la règle doit venir du jeu, jamais d'une copie.
