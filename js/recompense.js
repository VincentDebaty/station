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
// LES RANGS DE LIGNE
// ------------------------------------------------------------------
// Quatre crans, et ils se lisent sur la couleur du tracé : c'est là tout
// l'intérêt. L'objectif du joueur devient visible sans être énoncé — une carte
// aussi dorée que possible.
//
// L'ordre compte : `null` (en cours) ‹ ouverte ‹ argent ‹ or ‹ diamant.
const RANGS = [
  { id: "ouverte", nom: "Ligne ouverte",  seuil: 1, couleur: "#2dd4bf" },
  { id: "argent",  nom: "Ligne d'argent", seuil: 2, couleur: "#c9d4e6" },
  { id: "or",      nom: "Ligne d'or",     seuil: 3, couleur: "#e8b923" },
  { id: "diamant", nom: "Ligne de diamant", seuil: 4, couleur: "#7fd4ff" }
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
function garesDeLigne(lien, depuis) {
  if (!lien || typeof parcours !== "function") return [];
  const p = parcours(lien, depuis === lien.b ? lien.b : lien.a);
  const hD = typeof hubById === "function" ? hubById(p.depuis) : null;
  const hA = typeof hubById === "function" ? hubById(p.vers) : null;
  return [hD && hD.gareId, ...p.gares, hA && hA.gareId].filter(Boolean);
}
// Le rang d'une ligne, ou null tant qu'une gare manque. On prend le MINIMUM :
// une ligne d'or est une ligne dont AUCUNE gare n'est en dessous de trois
// étoiles. La moyenne aurait laissé une gare bâclée se cacher derrière deux
// gares parfaites, et le rang aurait cessé de vouloir dire quelque chose.
//
// Le sens de lecture n'entre pas dans le calcul : `garesDeLigne` rend le même
// ensemble des deux côtés, à l'ordre près.
function rangDeLigne(lien, depuis) {
  const gares = garesDeLigne(lien, depuis);
  if (!gares.length) return null;
  let bas = 4;
  for (const g of gares) bas = Math.min(bas, niveauDeGare(g));
  if (bas < 1) return null;
  return RANGS[bas - 1];
}
// Tous les corridors du graphe, chacun lu depuis son extrémité `a` — le rang
// ne dépend pas du sens de lecture, donc n'importe lequel convient.
function toutesLesLignes() {
  if (typeof buildGraphe !== "function") return [];
  buildGraphe();
  return GRAPHE.corridors.filter(l => l.gares && l.gares.length);
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
  // Les lignes, par rang atteint. Chaque cran compte toutes les lignes AU
  // MOINS à ce rang : une ligne de diamant est aussi une ligne d'or, sans quoi
  // se perfectionner ferait perdre une médaille.
  const lignes = { ouverte: 0, argent: 0, or: 0, diamant: 0 };
  for (const l of toutesLesLignes()) {
    const r = rangDeLigne(l, l.a);
    if (!r) continue;
    for (let i = 0; i <= RANGS.indexOf(r); i++) lignes[RANGS[i].id]++;
  }
  // Les boss : ouverts (leur gare est tenue) et maîtrisés (toutes leurs
  // sorties bouclées).
  let boss = 0, bossMaitrises = 0, mer = 0;
  const tenues = new Set();
  for (const c of cat) if (typeof isBought === "function" && isBought(c.id)) tenues.add(c.id);
  const hubs = typeof HUBS !== "undefined" ? HUBS : [];
  for (const h of hubs) {
    if (!h.gareId || !tenues.has(h.gareId)) continue;
    boss++;
    if (typeof bossMaitrise === "function" && bossMaitrise(h.id, tenues)) bossMaitrises++;
  }
  // Une traversée maritime FRANCHIE : les deux rives tenues. Le graphe en
  // compte six, et c'est le seul geste du jeu qui ne suit pas un rail.
  if (typeof LIENS !== "undefined")
    for (const [a, b, t] of LIENS) {
      if (t !== "mer") continue;
      const ha = hubById(a), hb = hubById(b);
      if (ha && hb && ha.gareId && hb.gareId && tenues.has(ha.gareId) && tenues.has(hb.gareId)) mer++;
    }
  // Les constellations touchées, et celles entièrement tenues.
  const touchees = new Set(), parCst = {};
  for (const h of hubs) {
    parCst[h.c] = parCst[h.c] || { n: 0, tenus: 0 };
    if (!h.gareId) continue;
    parCst[h.c].n++;
    if (tenues.has(h.gareId)) { parCst[h.c].tenus++; touchees.add(h.c); }
  }
  let constellationsFinies = 0;
  for (const k in parCst)
    if (parCst[k].n > 0 && parCst[k].tenus === parCst[k].n) constellationsFinies++;

  const serie = typeof getSerie === "function" ? getSerie() : { n: 0, record: 0 };
  return {
    etoiles, diamants, gares, lignes, boss, bossMaitrises, mer,
    constellations: touchees.size, constellationsFinies,
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
// Les seuils sont calés sur le CATALOGUE RÉEL (145 gares, une vingtaine de
// corridors), pas sur ceux du document — qui visaient un réseau européen
// complet et donneraient ici des paliers inatteignables. Ils remonteront quand
// les gares manquantes seront écrites : les médailles étant déduites, il n'y
// aura rien à migrer.
const MEDAILLES = [
  // --- Accumulation : la trace du temps passé. --------------------
  { id: "et25",   fam: "Accumulation", nom: "Premières étoiles",   dit: "25 étoiles",            si: e => e.etoiles >= 25 },
  { id: "et50",   fam: "Accumulation", nom: "Bon élève",           dit: "50 étoiles",            si: e => e.etoiles >= 50 },
  { id: "et100",  fam: "Accumulation", nom: "Cent étoiles",        dit: "100 étoiles",           si: e => e.etoiles >= 100 },
  { id: "et250",  fam: "Accumulation", nom: "Ciel chargé",         dit: "250 étoiles",           si: e => e.etoiles >= 250 },
  { id: "et435",  fam: "Accumulation", nom: "Tout le catalogue",   dit: "435 étoiles",           si: e => e.etoiles >= 435 },
  { id: "di5",    fam: "Accumulation", nom: "Cinq diamants",       dit: "5 sans-fautes",         si: e => e.diamants >= 5 },
  { id: "di15",   fam: "Accumulation", nom: "Écrin",               dit: "15 sans-fautes",        si: e => e.diamants >= 15 },
  { id: "di40",   fam: "Accumulation", nom: "Coffre-fort",         dit: "40 sans-fautes",        si: e => e.diamants >= 40 },
  { id: "ga10",   fam: "Accumulation", nom: "Petit réseau",        dit: "10 gares",              si: e => e.gares >= 10 },
  { id: "ga30",   fam: "Accumulation", nom: "Réseau régional",     dit: "30 gares",              si: e => e.gares >= 30 },
  { id: "ga75",   fam: "Accumulation", nom: "Réseau national",     dit: "75 gares",              si: e => e.gares >= 75 },
  // --- Maîtrise : ce qu'on a fini, et bien fini. ------------------
  { id: "li1",    fam: "Maîtrise",     nom: "Bout en bout",        dit: "une ligne ouverte",     si: e => e.lignes.ouverte >= 1 },
  { id: "li5",    fam: "Maîtrise",     nom: "Cinq lignes",         dit: "5 lignes ouvertes",     si: e => e.lignes.ouverte >= 5 },
  { id: "li12",   fam: "Maîtrise",     nom: "Toile ferrée",        dit: "12 lignes ouvertes",    si: e => e.lignes.ouverte >= 12 },
  { id: "or1",    fam: "Maîtrise",     nom: "Voie royale",         dit: "une ligne d'or",        si: e => e.lignes.or >= 1 },
  { id: "or3",    fam: "Maîtrise",     nom: "Trois fois l'or",     dit: "3 lignes d'or",         si: e => e.lignes.or >= 3 },
  { id: "diam1",  fam: "Maîtrise",     nom: "Pas une minute",      dit: "une ligne de diamant",  si: e => e.lignes.diamant >= 1 },
  { id: "bm1",    fam: "Maîtrise",     nom: "Maître du carrefour", dit: "un boss maîtrisé",      si: e => e.bossMaitrises >= 1 },
  { id: "bm5",    fam: "Maîtrise",     nom: "Grand aiguilleur",    dit: "5 boss maîtrisés",      si: e => e.bossMaitrises >= 5 },
  { id: "cst1",   fam: "Maîtrise",     nom: "Région bouclée",      dit: "une constellation entière", si: e => e.constellationsFinies >= 1 },
  // --- Exploration : jusqu'où l'on est allé. ----------------------
  { id: "bo1",    fam: "Exploration",  nom: "Grande gare",         dit: "un boss ouvert",        si: e => e.boss >= 1 },
  { id: "bo5",    fam: "Exploration",  nom: "Cinq métropoles",     dit: "5 boss ouverts",        si: e => e.boss >= 5 },
  { id: "cst2",   fam: "Exploration",  nom: "Passeport",           dit: "2 constellations",      si: e => e.constellations >= 2 },
  { id: "cst4",   fam: "Exploration",  nom: "Grand tour",          dit: "4 constellations",      si: e => e.constellations >= 4 },
  { id: "mer1",   fam: "Exploration",  nom: "Par-delà la mer",     dit: "une traversée",         si: e => e.mer >= 1 },
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
