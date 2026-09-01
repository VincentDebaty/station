"use strict";
// ------------------------------------------------------------------
// LA RÉCOMPENSE — ce que le jeu rend au joueur, et rien d'autre.
// ------------------------------------------------------------------
// Le reproche qui a ouvert ce chantier tenait en une phrase : « les
// récompenses ne sont pas assez célébrées ». Le jeu enregistrait bien —
// étoiles, records, gares ouvertes — mais il ne DISAIT rien. Un service à dix
// minutes de retard sur une journée entière s'achevait comme un service raté :
// un chiffre, un bouton.
//
// Ce fichier tient les trois choses qui manquaient, et il les tient ENSEMBLE
// parce qu'elles répondent à la même question à trois échéances différentes :
//
//   LA SÉRIE        maintenant. Ce que j'ai en jeu à l'instant.
//   LE RANG DE LIGNE cette semaine. Ce que je peux finir.
//   LES MÉDAILLES   depuis toujours. Ce que j'ai fait.
//
// ------------------------------------------------------------------
// PRESQUE RIEN N'EST STOCKÉ, ET C'EST LA DÉCISION STRUCTURANTE
// ------------------------------------------------------------------
// Un seul fait est écrit dans la sauvegarde : la série (js/store.js), parce
// qu'elle dépend de l'ORDRE des services et qu'aucun état final ne permet de
// la retrouver. Tout le reste — rangs de ligne, médailles, diamants — se
// DÉDUIT de la progression : `{ étoiles, meilleur retard }` par gare, et le
// graphe.
//
// Ce n'est pas de l'économie de place, c'est une garantie. Une liste de
// médailles décrochées, stockée, se désynchronise au premier seuil qu'on
// retouche : le joueur garde une médaille qui n'existe plus, ou n'obtient
// jamais celle dont on vient de baisser la barre. Déduite, elle est vraie par
// construction — et l'on peut réécrire toute l'échelle sans migration.
//
// Le prix à payer est connu et assumé : à la première partie qui suit
// l'arrivée des médailles, un joueur avancé en décroche plusieurs d'un coup.
// C'est le bon sens du rattrapage, et le relevé sait le dire sans se noyer.
// ------------------------------------------------------------------

// Le seuil de la série : TROIS ÉTOILES, c'est-à-dire moins de dix minutes de
// retard. Volontairement le même repère que le palier — deux barres voisines
// mais distinctes (« sous 10 min » ici, « sous 12 » là) obligeraient le joueur
// à tenir deux règles en tête pour un seul geste.
const SERIE_SEUIL = 3;

// ------------------------------------------------------------------
// LES RANGS DE CHAPITRE
// ------------------------------------------------------------------
// Quatre crans, et ils se lisent sur la couleur du tracé : c'est là tout
// l'intérêt. L'objectif du joueur devient visible sans être énoncé — une carte
// aussi dorée que possible.
//
// L'ordre compte : `null` (en cours) ‹ ouverte ‹ argent ‹ or ‹ diamant.
const RANGS = [
  { id: "ouverte", nom: "Chapitre fait",     seuil: 1, couleur: "#2dd4bf" },
  { id: "argent",  nom: "Chapitre d'argent", seuil: 2, couleur: "#c9d4e6" },
  { id: "or",      nom: "Chapitre d'or",     seuil: 3, couleur: "#e8b923" },
  { id: "diamant", nom: "Chapitre de diamant", seuil: 4, couleur: "#7fd4ff" }
];
// Le « niveau » d'une gare sur l'échelle des rangs : 0 si elle n'est pas
// tenue, sinon son nombre d'étoiles, et 4 pour un sans-faute. Le diamant vaut
// donc un cran de plus que trois étoiles — il s'empile, comme au palmarès.
function niveauDeGare(id) {
  if (typeof isBought !== "function" || !isBought(id)) return 0;
  const r = (getProgress()[id] || {});
  if (r.bestDelay === 0) return 4;
  return r.stars || 0;
}
// COMBIEN DE GARES SONT FAITES sur une composition donnée. Une seule fonction,
// parce que DEUX écrans affichent ce compte à côté d'un rang : la vue ligne
// (« 3 / 7 ») et le panneau de carrefour. Comptés séparément, ils ont
// effectivement divergé — le panneau annonçait « 7 / 7 » à côté d'une ligne
// sans rang, ce qui envoie chercher une gare manquante qui n'existe pas.
//
// FAITE, PAS PAYÉE : le rang exige au moins une étoile partout, le compte doit
// exiger la même chose. Une gare achetée puis jamais réussie n'est pas faite.
function garesFaites(composition) {
  return (composition || []).filter(g => niveauDeGare(g) >= 1).length;
}
// LES GARES QUI COMPOSENT UNE LIGNE — les intermédiaires ET SES DEUX BOUTS.
//
// Les deux, et c'est le point délicat. La première version ne comptait que le
// boss d'ARRIVÉE, parce qu'une ligne se lit depuis le bout qu'on tient déjà.
// Le résultat tenait de la farce : Bruxelles – Cologne était une ligne d'or
// lue depuis Bruxelles, et une ligne SANS RANG lue depuis Cologne — puisque
// Bruxelles-Midi devenait alors l'arrivée, et qu'elle n'était pas tenue. Le
// même trajet, deux verdicts, selon le côté d'où l'on regardait.
//
// Une ligne est un objet du monde, pas une vue : elle a deux termini, et l'on
// n'a pas fait Bruxelles – Cologne tant qu'on n'a pas travaillé les deux
// gares. Qu'un boss non tenu prive de leur rang les quatre lignes qui s'y
// rejoignent n'est pas un effet de bord : c'est ce que « ligne terminée » veut
// dire.
//
// `depuis` ne décide donc plus QUOI, seulement DANS QUEL ORDRE — la vue ligne
// s'en sert pour afficher de gauche à droite.
function garesDeChapitre(ch) { return ch && ch.gares ? ch.gares.slice() : []; }
// Le rang d'un chapitre, ou null tant qu'une gare manque. On prend le
// MINIMUM : un chapitre d'or est un chapitre dont AUCUNE gare n'est en dessous
// de trois étoiles. La moyenne aurait laissé une gare bâclée se cacher
// derrière deux gares parfaites, et le rang aurait cessé de vouloir dire
// quelque chose.
//
// Sur un ruban, le piège du sens de lecture disparaît : un chapitre n'a qu'un
// bout d'arrivée, et sa composition ne dépend d'aucun point de vue.
function rangDeChapitre(ch) {
  const gares = garesDeChapitre(ch);
  if (!gares.length) return null;
  let bas = 4;
  for (const g of gares) bas = Math.min(bas, niveauDeGare(g));
  if (bas < 1) return null;
  return RANGS[bas - 1];
}
// Tous les chapitres du ruban de la carte courante.
function tousLesChapitres() {
  return typeof chapitresDuRuban === "function" ? chapitresDuRuban() : [];
}

// ------------------------------------------------------------------
// L'ÉTAT DU JOUEUR, EN CHIFFRES
// ------------------------------------------------------------------
// Un instantané, calculé d'un bloc. Les médailles s'y adossent toutes : c'est
// ce qui permet de les comparer avant/après un service sans rejouer la partie.
function etatRecompenses() {
  const prog = typeof getProgress === "function" ? getProgress() : {};
  const cat = typeof CATALOG !== "undefined" ? CATALOG : [];
  let etoiles = 0, diamants = 0, gares = 0;
  for (const c of cat) {
    const r = prog[c.id];
    if (typeof isBought === "function" && isBought(c.id)) gares++;
    if (!r) continue;
    etoiles += r.stars || 0;
    if (r.bestDelay === 0) diamants++;
  }
  // Les chapitres, par rang atteint. Chaque cran compte tous les chapitres AU
  // MOINS à ce rang : un chapitre de diamant est aussi un chapitre d'or, sans
  // quoi se perfectionner ferait perdre une médaille.
  const chapitres = { ouverte: 0, argent: 0, or: 0, diamant: 0 };
  let chapitresFinis = 0;
  const chs = tousLesChapitres();
  for (const ch of chs) {
    if (typeof chapitreTermine === "function" && chapitreTermine(ch)) chapitresFinis++;
    const r = rangDeChapitre(ch);
    if (!r) continue;
    for (let k = 0; k <= RANGS.indexOf(r); k++) chapitres[RANGS[k].id]++;
  }
  // Un SAUT FRANCHI : le chapitre qui le porte est entamé. C'est le seul geste
  // du jeu qui ne suive pas un rail, et il mérite d'être compté.
  let sauts = 0;
  for (const ch of chs)
    if (ch.saut && ch.gares.some(g => niveauDeGare(g) >= 1)) sauts++;
  // Les zones : touchées, et entièrement traversées.
  const touchees = new Set();
  let zonesFinies = 0;
  const zones = typeof zonesDeCarte === "function" ? zonesDeCarte() : [];
  for (const z of zones) {
    const dans = chs.filter(c => c.zone === z.id);
    if (!dans.length) continue;
    if (dans.some(c => c.gares.some(g => niveauDeGare(g) >= 1))) touchees.add(z.id);
    if (dans.every(c => typeof chapitreTermine === "function" && chapitreTermine(c))) zonesFinies++;
  }
  const serie = typeof getSerie === "function" ? getSerie() : { n: 0, record: 0 };
  // LES PLAFONDS DU RUBAN COURANT. Sans eux, les médailles de fin se calent sur
  // des nombres écrits à la main, qui vieillissent mal : celles d'avant visaient
  // un catalogue de 145 gares alors que le ruban v1 n'en expose que 63, et
  // quatre médailles étaient devenues INATTEIGNABLES — 250 et 435 étoiles pour
  // un plafond de 189, 75 gares pour 63, 12 chapitres pour 11. Déduits, ils
  // suivent le ruban quand le lot F l'allonge, et il n'y a rien à migrer.
  const nGares = chs.reduce((t, c) => t + c.gares.length, 0);
  const max = { etoiles: nGares * 3, gares: nGares, chapitres: chs.length, zones: zones.length };
  return {
    etoiles, diamants, gares, chapitres, chapitresFinis, sauts,
    zones: touchees.size, zonesFinies, max,
    serie: serie.n, serieRecord: serie.record
  };
}

// ------------------------------------------------------------------
// LES MÉDAILLES
// ------------------------------------------------------------------
// Cinq familles au document, quatre ici. La cinquième — la RÉGULARITÉ, les
// jours de jeu consécutifs — est volontairement absente : elle demande une
// horloge, donc des fuseaux, des changements d'heure et une sauvegarde datée,
// et elle récompense le fait d'ouvrir l'application plutôt que celui de bien
// jouer. Elle mérite sa propre décision, pas d'être glissée dans un lot.
//
// Les seuils bas sont ABSOLUS (25, 50, 100 étoiles) : ils balisent le début de
// partie, où le ruban est vaste quelle que soit sa longueur. Les seuils de FIN
// sont RELATIFS au ruban courant (`e.max`), parce qu'un nombre écrit à la main
// y vieillit mal — calés sur un catalogue de 145 gares, ils étaient devenus
// inatteignables sur un ruban v1 qui n'en expose que 63.
//
// `sa1` reste au tableau bien que le ruban v1 ne déclare AUCUN saut : les huit
// sauts sont au tracé (`ruban-europe.md`) et arriveront avec le lot F. Une
// médaille déduite qui attend son contenu ne coûte rien ; la retirer puis la
// réécrire coûterait deux fois.
const MEDAILLES = [
  // --- Accumulation : la trace du temps passé. --------------------
  { id: "et25",   fam: "Accumulation", nom: "Premières étoiles",   dit: "25 étoiles",            si: e => e.etoiles >= 25 },
  { id: "et50",   fam: "Accumulation", nom: "Bon élève",           dit: "50 étoiles",            si: e => e.etoiles >= 50 },
  { id: "et100",  fam: "Accumulation", nom: "Cent étoiles",        dit: "100 étoiles",           si: e => e.etoiles >= 100 },
  { id: "etmoit", fam: "Accumulation", nom: "Ciel chargé",         dit: "la moitié du ruban",    si: e => e.max && e.max.etoiles > 0 && e.etoiles >= e.max.etoiles / 2 },
  { id: "ettout", fam: "Accumulation", nom: "Tout le ruban",       dit: "toutes les étoiles",    si: e => e.max && e.max.etoiles > 0 && e.etoiles >= e.max.etoiles },
  { id: "di5",    fam: "Accumulation", nom: "Cinq diamants",       dit: "5 sans-fautes",         si: e => e.diamants >= 5 },
  { id: "di15",   fam: "Accumulation", nom: "Écrin",               dit: "15 sans-fautes",        si: e => e.diamants >= 15 },
  { id: "di40",   fam: "Accumulation", nom: "Coffre-fort",         dit: "40 sans-fautes",        si: e => e.diamants >= 40 },
  { id: "ga10",   fam: "Accumulation", nom: "Petit réseau",        dit: "10 gares",              si: e => e.gares >= 10 },
  { id: "ga30",   fam: "Accumulation", nom: "Réseau régional",     dit: "30 gares",              si: e => e.gares >= 30 },
  { id: "gatout", fam: "Accumulation", nom: "Réseau national",     dit: "toutes les gares",      si: e => e.max && e.max.gares > 0 && e.gares >= e.max.gares },
  // --- Maîtrise : ce qu'on a fini, et bien fini. ------------------
  { id: "ch1",    fam: "Maîtrise",     nom: "Bout en bout",        dit: "un chapitre fini",      si: e => e.chapitres.ouverte >= 1 },
  { id: "ch5",    fam: "Maîtrise",     nom: "Cinq chapitres",      dit: "5 chapitres finis",     si: e => e.chapitres.ouverte >= 5 },
  { id: "chtout", fam: "Maîtrise",     nom: "Toile ferrée",        dit: "tous les chapitres",    si: e => e.max && e.max.chapitres > 0 && e.chapitres.ouverte >= e.max.chapitres },
  { id: "or1",    fam: "Maîtrise",     nom: "Voie royale",         dit: "un chapitre d'or",      si: e => e.chapitres.or >= 1 },
  { id: "or3",    fam: "Maîtrise",     nom: "Trois fois l'or",     dit: "3 chapitres d'or",      si: e => e.chapitres.or >= 3 },
  { id: "diam1",  fam: "Maîtrise",     nom: "Pas une minute",      dit: "un chapitre de diamant", si: e => e.chapitres.diamant >= 1 },
  { id: "zo1",    fam: "Maîtrise",     nom: "Région traversée",    dit: "une zone entière",      si: e => e.zonesFinies >= 1 },
  // --- Exploration : jusqu'où l'on est allé. ----------------------
  { id: "av1",    fam: "Exploration",  nom: "En route",            dit: "un chapitre entamé",    si: e => e.chapitresFinis >= 1 },
  { id: "av5",    fam: "Exploration",  nom: "Cinq étapes",         dit: "5 chapitres franchis",  si: e => e.chapitresFinis >= 5 },
  { id: "zo2",    fam: "Exploration",  nom: "Passeport",           dit: "2 zones touchées",      si: e => e.zones >= 2 },
  { id: "sa1",    fam: "Exploration",  nom: "Par-delà la mer",     dit: "un saut franchi",       si: e => e.sauts >= 1 },
  // --- Style : la manière. ----------------------------------------
  { id: "sf1",    fam: "Style",        nom: "Sans faute",          dit: "un service parfait",    si: e => e.diamants >= 1 },
  { id: "se3",    fam: "Style",        nom: "Trois d'affilée",     dit: "série de 3",            si: e => e.serieRecord >= 3 },
  { id: "se6",    fam: "Style",        nom: "Ponctualité suisse",  dit: "série de 6",            si: e => e.serieRecord >= 6 },
  { id: "se12",   fam: "Style",        nom: "Horloge de gare",     dit: "série de 12",           si: e => e.serieRecord >= 12 }
];
// Les médailles décrochées dans un état donné. Un Set : on ne s'en sert que
// pour comparer deux instants.
function medaillesDe(etat) {
  const s = new Set();
  for (const m of MEDAILLES) { try { if (m.si(etat)) s.add(m.id); } catch (e) { /* état partiel */ } }
  return s;
}
// Ce qui vient d'être décroché, dans l'ordre de la liste — donc de la plus
// commune à la plus rare, ce qui est le bon ordre pour en montrer deux et
// taire le reste.
function medaillesNouvelles(avant, apres) {
  return MEDAILLES.filter(m => apres.has(m.id) && !avant.has(m.id));
}

// ------------------------------------------------------------------
// LES CRÉDITS — gagnés en jouant, dépensés pour passer (§7 du document).
// ------------------------------------------------------------------
// Deux usages, et deux seulement : acheter une carte, et PAYER LE PASSAGE
// d'une gare sur laquelle on bloque (§4 ter). Rien n'est stocké : le solde se
// déduit comme tout le reste.
//
// La dépense en passages ne compte que les gares payées ENCORE à zéro étoile.
// C'est ce qui REND LA MISE au joueur qui revient gagner la gare plus tard —
// sans qu'une ligne de sauvegarde ait bougé.
const CREDIT_PAR_ETOILE = 1, CREDIT_PAR_DIAMANT = 5, CREDIT_PAR_CHAPITRE_DOR = 20,
      CREDIT_PAR_ZONE = 100, CREDIT_PAR_CARTE = 500;
const SEUIL_OR = (RANGS.find(r => r.id === "or") || { seuil: 3 }).seuil;

// LE SOLDE EST UN FAIT DE COMPTE, PAS DE CARTE (lot G, point 4 — 1er septembre
// 2026). `creditsGagnes` ne comptait que la carte COURANTE : invisible tant
// qu'il n'y en avait qu'une, et faux dès la deuxième, où le joueur perdait tout
// ce qu'il avait gagné sur la première en changeant de monde. Le terme « carte
// terminée » manquait par-dessus le marché.
//
// D'où cette fonction : ce qu'UNE carte rapporte, calculé sans qu'elle soit la
// carte courante. On ne lui donne que sa définition (js/cartes.js la garde en
// mémoire pour toutes les cartes) et la progression enregistrée pour elle. Rien
// n'est stocké de plus — le solde reste entièrement déduit.
function creditsDUneCarte(def, stations, passees) {
  const st = stations || {}, paye = passees || [];
  let etoiles = 0, diamants = 0;
  for (const id in st) {
    const r = st[id] || {};
    etoiles += r.stars || 0;
    if (r.bestDelay === 0) diamants++;
  }
  // Mêmes crans que niveauDeGare, mais lus dans la table qu'on nous donne.
  // Une gare PAYÉE reste à zéro : elle est franchie, pas tenue, et le rang de
  // chapitre exige une étoile partout — c'est ce qui empêche d'acheter un
  // chapitre d'or.
  const niv = id => { const r = st[id]; if (!r) return 0; return r.bestDelay === 0 ? 4 : (r.stars || 0); };
  const franchie = id => niv(id) >= 1 || paye.indexOf(id) >= 0;
  const chs = (def && def.chapitres) || [];
  let or = 0, finis = 0;
  for (const ch of chs) {
    const g = ch.gares || [];
    if (!g.length) continue;
    let bas = 4;
    for (const x of g) bas = Math.min(bas, niv(x));
    if (bas >= SEUIL_OR) or++;
    if (g.every(franchie)) finis++;
  }
  let zones = 0;
  for (const z of (def && def.zones) || []) {
    const dans = chs.filter(c => c.zone === z.id);
    if (dans.length && dans.every(c => (c.gares || []).every(franchie))) zones++;
  }
  const carteFinie = chs.length && finis === chs.length ? 1 : 0;
  return etoiles * CREDIT_PAR_ETOILE + diamants * CREDIT_PAR_DIAMANT +
    or * CREDIT_PAR_CHAPITRE_DOR + zones * CREDIT_PAR_ZONE + carteFinie * CREDIT_PAR_CARTE;
}
// La somme sur TOUTES les cartes jouées. Une carte dont la définition n'a pas
// pu être lue ne rapporte que ses étoiles et ses diamants : on préfère un solde
// un peu bas à un plantage, et `precargerCartes` rend le cas improbable.
function creditsGagnes() {
  const cartes = typeof getCartesEnregistrees === "function" ? getCartesEnregistrees() : [];
  if (!cartes.length) {
    const def = typeof carteCourante === "function" ? carteCourante() : null;
    return creditsDUneCarte(def, typeof getProgress === "function" ? getProgress() : {},
      typeof getPassees === "function" ? getPassees() : []);
  }
  let t = 0;
  for (const c of cartes) {
    const def = typeof defDeCarte === "function" ? defDeCarte(c.id) : null;
    t += creditsDUneCarte(def, c.stations, c.passees);
  }
  return t;
}
// LE PRIX D'UN PASSAGE SUIT LA POSITION DANS LE RUBAN. Petit au début — pour
// que le débutant bloqué puisse se le payer en rejouant deux ou trois gares —
// et cher en fin de carte, pour qu'on n'achète pas la fin du voyage.
// Ordre de grandeur voulu : trois à cinq gares bien jouées.
function prixDePassageDans(def, gareId) {
  const chs = (def && def.chapitres) || [];
  for (let i = 0; i < chs.length; i++)
    if ((chs[i].gares || []).indexOf(gareId) >= 0) return 5 + i * 3;
  return 5;
}
function prixDePassage(gareId) {
  const ch = typeof chapitreDeGare === "function" ? chapitreDeGare(gareId) : null;
  if (ch) return 5 + ch.rang * 3;
  return prixDePassageDans(typeof carteCourante === "function" ? carteCourante() : null, gareId);
}
// La dépense, elle aussi sur toutes les cartes : les passages payés dont la
// gare est ENCORE à zéro étoile (gagner la gare plus tard rend la mise), plus
// le prix des cartes acquises EN CRÉDITS — une carte reçue gratuitement ou
// payée en argent réel ne coûte rien à la bourse.
function creditsDepenses() {
  let d = 0;
  const cartes = typeof getCartesEnregistrees === "function" ? getCartesEnregistrees() : [];
  const liste = cartes.length ? cartes : [{
    id: typeof getCarteCourante === "function" ? getCarteCourante() : null,
    stations: typeof getProgress === "function" ? getProgress() : {},
    passees: typeof getPassees === "function" ? getPassees() : []
  }];
  for (const c of liste) {
    const def = typeof defDeCarte === "function" ? defDeCarte(c.id) : null;
    for (const g of c.passees || [])
      if (!((((c.stations || {})[g]) || {}).stars >= 1)) d += prixDePassageDans(def, g);
  }
  const poss = typeof cartesPossedees === "function" ? cartesPossedees() : {};
  for (const id in poss)
    if (poss[id] === "credits" && typeof prixDeCarte === "function") d += prixDeCarte(id);
  return d;
}
function soldeCredits() { return Math.max(0, creditsGagnes() - creditsDepenses()); }
