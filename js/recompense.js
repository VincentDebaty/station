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
//
// CHAQUE MÉDAILLE PORTE SA BOURSE (10 septembre 2026, economie-du-jeu.md §3) :
// 50 pièces pour une médaille commune, 150 pour une rare, 500 pour une
// « toutes / ultime ». Les vingt-six valent ≈ 5 000 pièces, un cinquième du
// revenu de la carte, réparti sur des moments qui étaient DÉJÀ fêtés — et
// comme la médaille se déduit, sa bourse se déduit avec elle.
const MEDAILLES = [
  // --- Accumulation : la trace du temps passé. --------------------
  { id: "et25",   fam: "Accumulation", nom: "Premières étoiles",   dit: "25 étoiles",            bourse: 50, si: e => e.etoiles >= 25 },
  { id: "et50",   fam: "Accumulation", nom: "Bon élève",           dit: "50 étoiles",            bourse: 50, si: e => e.etoiles >= 50 },
  { id: "et100",  fam: "Accumulation", nom: "Cent étoiles",        dit: "100 étoiles",           bourse: 150, si: e => e.etoiles >= 100 },
  { id: "etmoit", fam: "Accumulation", nom: "Ciel chargé",         dit: "la moitié du ruban",    bourse: 150, si: e => e.max && e.max.etoiles > 0 && e.etoiles >= e.max.etoiles / 2 },
  { id: "ettout", fam: "Accumulation", nom: "Tout le ruban",       dit: "toutes les étoiles",    bourse: 500, si: e => e.max && e.max.etoiles > 0 && e.etoiles >= e.max.etoiles },
  { id: "di5",    fam: "Accumulation", nom: "Cinq diamants",       dit: "5 sans-fautes",         bourse: 50, si: e => e.diamants >= 5 },
  { id: "di15",   fam: "Accumulation", nom: "Écrin",               dit: "15 sans-fautes",        bourse: 150, si: e => e.diamants >= 15 },
  { id: "di40",   fam: "Accumulation", nom: "Coffre-fort",         dit: "40 sans-fautes",        bourse: 500, si: e => e.diamants >= 40 },
  { id: "ga10",   fam: "Accumulation", nom: "Petit réseau",        dit: "10 gares",              bourse: 50, si: e => e.gares >= 10 },
  { id: "ga30",   fam: "Accumulation", nom: "Réseau régional",     dit: "30 gares",              bourse: 150, si: e => e.gares >= 30 },
  { id: "gatout", fam: "Accumulation", nom: "Réseau national",     dit: "toutes les gares",      bourse: 500, si: e => e.max && e.max.gares > 0 && e.gares >= e.max.gares },
  // --- Maîtrise : ce qu'on a fini, et bien fini. ------------------
  { id: "ch1",    fam: "Maîtrise",     nom: "Bout en bout",        dit: "un chapitre fini",      bourse: 50, si: e => e.chapitres.ouverte >= 1 },
  { id: "ch5",    fam: "Maîtrise",     nom: "Cinq chapitres",      dit: "5 chapitres finis",     bourse: 150, si: e => e.chapitres.ouverte >= 5 },
  { id: "chtout", fam: "Maîtrise",     nom: "Toile ferrée",        dit: "tous les chapitres",    bourse: 500, si: e => e.max && e.max.chapitres > 0 && e.chapitres.ouverte >= e.max.chapitres },
  { id: "or1",    fam: "Maîtrise",     nom: "Voie royale",         dit: "un chapitre d'or",      bourse: 150, si: e => e.chapitres.or >= 1 },
  { id: "or3",    fam: "Maîtrise",     nom: "Trois fois l'or",     dit: "3 chapitres d'or",      bourse: 150, si: e => e.chapitres.or >= 3 },
  { id: "diam1",  fam: "Maîtrise",     nom: "Pas une minute",      dit: "un chapitre de diamant", bourse: 500, si: e => e.chapitres.diamant >= 1 },
  { id: "zo1",    fam: "Maîtrise",     nom: "Région traversée",    dit: "une zone entière",      bourse: 150, si: e => e.zonesFinies >= 1 },
  // --- Exploration : jusqu'où l'on est allé. ----------------------
  { id: "av1",    fam: "Exploration",  nom: "En route",            dit: "un chapitre entamé",    bourse: 50, si: e => e.chapitresFinis >= 1 },
  { id: "av5",    fam: "Exploration",  nom: "Cinq étapes",         dit: "5 chapitres franchis",  bourse: 150, si: e => e.chapitresFinis >= 5 },
  { id: "zo2",    fam: "Exploration",  nom: "Passeport",           dit: "2 zones touchées",      bourse: 50, si: e => e.zones >= 2 },
  { id: "sa1",    fam: "Exploration",  nom: "Par-delà la mer",     dit: "un saut franchi",       bourse: 150, si: e => e.sauts >= 1 },
  // --- Style : la manière. ----------------------------------------
  { id: "sf1",    fam: "Style",        nom: "Sans faute",          dit: "un service parfait",    bourse: 50, si: e => e.diamants >= 1 },
  { id: "se3",    fam: "Style",        nom: "Trois d'affilée",     dit: "série de 3",            bourse: 50, si: e => e.serieRecord >= 3 },
  { id: "se6",    fam: "Style",        nom: "Ponctualité suisse",  dit: "série de 6",            bourse: 150, si: e => e.serieRecord >= 6 },
  { id: "se12",   fam: "Style",        nom: "Horloge de gare",     dit: "série de 12",           bourse: 500, si: e => e.serieRecord >= 12 }
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
// LES PIÈCES — gagnées en jouant, dépensées pour passer (§7 du document).
// ------------------------------------------------------------------
// Deux usages, et deux seulement : acheter une carte, et PAYER LE PASSAGE
// d'une gare sur laquelle on bloque (§4 ter). Rien n'est stocké : le solde se
// déduit comme tout le reste.
//
// LE CRÉDIT EST DEVENU UNE PIÈCE (10 septembre 2026, economie-du-jeu.md).
// « On ne se rend pas compte qu'on en gagne » (Vincent) : un service rendait
// 1, 2 ou 3 crédits, un chiffre qui ne se lit pas comme un revenu, et 69 % de
// l'argent tombait en trois sommes silencieuses. L'unité est multipliée par
// DIX — tous les rapports mesurés sont gardés (un passage ≈ trois à cinq gares
// bien jouées, finir l'Europe paie la deuxième carte) — et deux revenus qui
// manquaient s'ajoutent, déduits comme le reste :
//
//   LA PRÉCISION : une pièce par minute sous le seuil des trois étoiles, lue
//   dans `bestDelay`. C'est ce qui donne un prix au « record battu · −3 min »,
//   c'est-à-dire au REJEU, la boucle que la soupape suppose et que rien ne
//   payait. Plafond 12 par gare.
//
//   LES MÉDAILLES : chacune porte sa bourse (MEDAILLES[].bourse).
//
// La dépense en passages ne compte que les gares payées ENCORE à zéro étoile.
// C'est ce qui REND LA MISE au joueur qui revient gagner la gare plus tard —
// sans qu'une ligne de sauvegarde ait bougé.
const PIECES_PAR_ETOILE = 10, PIECES_PAR_MINUTE = 1,
      PIECES_PAR_CHAPITRE_DOR = 200, PIECES_PAR_ZONE = 1000, PIECES_PAR_CARTE = 5000;
const PASSAGE_BASE = 50, PASSAGE_PAR_CHAPITRE = 30;
// LA PIERRE (lot 2, 10 septembre 2026, economie-du-jeu.md §4). Le sans-faute
// ne rend plus de pièces : il produit une PIERRE, que l'on garde ou que l'on
// dépense — un passage vaut `prix en pièces / 50` pierres, arrondi au-dessus.
// Le TROPHÉE, lui, ne bouge pas : le sceau sur la carte, le rang de diamant,
// les médailles se déduisent toujours de `bestDelay`, et ne s'achètent
// jamais. Seul le stock en poche se dépense.
const PIERRE_PAR_SANS_FAUTE = 1, PIERRES_PAR_CHAPITRE_DIAMANT = 3, PIERRE_VAUT = 50;
const SEUIL_OR = (RANGS.find(r => r.id === "or") || { seuil: 3 }).seuil;
const SEUIL_DIAMANT = (RANGS.find(r => r.id === "diamant") || { seuil: 4 }).seuil;

// UN RUBAN ÉPHÉMÈRE POUR UNE CARTE QUI N'EST PAS LA COURANTE. js/ruban.js ne
// connaît que CARTE_COURANTE ; le solde, lui, est un fait de compte et somme
// toutes les cartes. On rebâtit donc la forme du ruban — l'ordre, l'index,
// les chapitres avec leur rang — exactement comme `buildRuban`, sur la
// définition qu'on nous donne. Rien d'autre n'est réimplémenté : la rampe, le
// plafond et le barème sont les fonctions PURES de ruban.js.
function rubanDe(def) {
  const rb = { chapitres: [], ordre: [], index: {}, chapitreDe: {} };
  ((def && def.chapitres) || []).forEach((ch, k) => {
    const c = { id: ch.id, zone: ch.zone, rang: k, gares: (ch.gares || []).slice(),
      plancher: ch.plancher, arrivee: ch.arrivee, saut: ch.saut || null };
    rb.chapitres.push(c);
    for (const g of c.gares) {
      if (rb.index[g] !== undefined) continue;
      rb.index[g] = rb.ordre.length;
      rb.chapitreDe[g] = c;
      rb.ordre.push(g);
    }
  });
  return rb;
}
// Le barème d'une gare telle qu'on la JOUE sur ce ruban-là — la même règle
// que `seuilsDeService`, sans passer par la carte courante.
function seuilsDansRuban(rb, gareId, cfg) {
  if (cfg && cfg.seuils) return { ...seuilsDeNiveau(cfg.difficulty), ...cfg.seuils };
  const ch = rb.chapitreDe[gareId];
  let d = null;
  if (ch) {
    const i = ch.gares.indexOf(gareId);
    const voulue = difficulteVoulue(i, ch.gares.length, plancherDeChapitre(ch), arriveeDeChapitre(ch));
    d = Math.max(1, Math.min(voulue, plafondDeFlux(cfg)));
  }
  return seuilsDeNiveau(d ?? (cfg ? cfg.difficulty : null));
}
// CE QU'UNE GARE RAPPORTE, et ce qu'elle peut rapporter au plus. Les deux se
// lisent ensemble : la différence est le manque à gagner, ce que « rejouer
// Doncaster » peut encore rendre.
function avanceDe(r, seuils) {
  const bd = r ? r.bestDelay : null;
  if (typeof bd !== "number" || !(r.stars >= 1)) return 0;
  return Math.max(0, Math.floor(seuils.trois - bd));
}
function piecesDeGare(r, seuils) {
  if (!r) return 0;
  return (r.stars || 0) * PIECES_PAR_ETOILE + avanceDe(r, seuils) * PIECES_PAR_MINUTE;
}
function plafondDeGare(seuils) {
  return 3 * PIECES_PAR_ETOILE + seuils.trois * PIECES_PAR_MINUTE;
}
function manqueAGagner(r, seuils) { return plafondDeGare(seuils) - piecesDeGare(r, seuils); }

// L'ÉTAT D'UNE CARTE QUI N'EST PAS LA COURANTE — le même instantané que
// `etatRecompenses`, calculé sur un ruban éphémère. C'est ce qui permet de
// déduire la bourse des médailles de CHAQUE carte, et donc un solde qui ne
// change pas quand on change de monde.
function etatDUneCarte(def, stations, passees, serie) {
  const rb = rubanDe(def), st = stations || {}, paye = passees || [];
  const faite = id => ((st[id] || {}).stars || 0) >= 1;
  const franchie = id => faite(id) || paye.indexOf(id) >= 0;
  let position = rb.ordre.length;
  for (let i = 0; i < rb.ordre.length; i++) if (!franchie(rb.ordre[i])) { position = i; break; }
  const ecrite = id => typeof cardOf === "function" && !!cardOf(id);
  const tenue = id => { const i = rb.index[id]; return i !== undefined && i <= position && ecrite(id); };
  const niv = id => { if (!tenue(id)) return 0; const r = st[id] || {}; return r.bestDelay === 0 ? 4 : (r.stars || 0); };
  let etoiles = 0, diamants = 0, gares = 0;
  for (const id of rb.ordre) if (tenue(id)) gares++;
  for (const id in st) {
    if (!ecrite(id)) continue;
    const r = st[id] || {};
    etoiles += r.stars || 0;
    if (r.bestDelay === 0) diamants++;
  }
  const chapitres = { ouverte: 0, argent: 0, or: 0, diamant: 0 };
  let chapitresFinis = 0, sauts = 0;
  for (const ch of rb.chapitres) {
    if (ch.gares.length && ch.gares.every(franchie)) chapitresFinis++;
    if (ch.saut && ch.gares.some(g => niv(g) >= 1)) sauts++;
    if (!ch.gares.length) continue;
    let bas = 4;
    for (const g of ch.gares) bas = Math.min(bas, niv(g));
    if (bas < 1) continue;
    for (let k = 0; k < bas; k++) chapitres[RANGS[k].id]++;
  }
  const touchees = new Set();
  let zonesFinies = 0;
  const zones = (def && def.zones) || [];
  for (const z of zones) {
    const dans = rb.chapitres.filter(c => c.zone === z.id);
    if (!dans.length) continue;
    if (dans.some(c => c.gares.some(g => niv(g) >= 1))) touchees.add(z.id);
    if (dans.every(c => c.gares.every(franchie))) zonesFinies++;
  }
  const nGares = rb.chapitres.reduce((t, c) => t + c.gares.length, 0);
  const s = serie || { n: 0, record: 0 };
  return {
    etoiles, diamants, gares, chapitres, chapitresFinis, sauts,
    zones: touchees.size, zonesFinies,
    max: { etoiles: nGares * 3, gares: nGares, chapitres: rb.chapitres.length, zones: zones.length },
    serie: s.n || 0, serieRecord: s.record || 0
  };
}
function bourseDesMedailles(etat) {
  const tenues = medaillesDe(etat);
  let b = 0;
  for (const m of MEDAILLES) if (tenues.has(m.id)) b += m.bourse || 0;
  return b;
}

// LE SOLDE EST UN FAIT DE COMPTE, PAS DE CARTE (lot G, point 4 — 1er septembre
// 2026). `creditsGagnes` ne comptait que la carte COURANTE : invisible tant
// qu'il n'y en avait qu'une, et faux dès la deuxième, où le joueur perdait tout
// ce qu'il avait gagné sur la première en changeant de monde. Le terme « carte
// terminée » manquait par-dessus le marché.
//
// D'où cette fonction : ce qu'UNE carte rapporte, calculé sans qu'elle soit la
// carte courante, POSTE PAR POSTE. On ne lui donne que sa définition
// (js/cartes.js la garde en mémoire pour toutes les cartes), la progression
// enregistrée pour elle, et sa série. Rien n'est stocké de plus — le solde
// reste entièrement déduit. Le détail sert au relevé : c'est en recevant les
// pièces poste par poste que le joueur apprend le barème.
const POSTES = ["etoiles", "avance", "or", "zones", "carte", "medailles"];
function detailPiecesDUneCarte(def, stations, passees, serie, passeesEnPierres) {
  const st = stations || {}, paye = (passees || []).concat(passeesEnPierres || []);
  const rb = rubanDe(def);
  const d = { etoiles: 0, avance: 0, or: 0, zones: 0, carte: 0, medailles: 0, total: 0 };
  for (const id in st) {
    const r = st[id] || {};
    d.etoiles += (r.stars || 0) * PIECES_PAR_ETOILE;
    // la précision ne se lit que sur une gare dont on connaît la fiche : le
    // barème dépend de sa géométrie
    const cfg = typeof cardOf === "function" ? cardOf(id) : null;
    if (cfg) d.avance += avanceDe(r, seuilsDansRuban(rb, id, cfg)) * PIECES_PAR_MINUTE;
  }
  // Mêmes crans que niveauDeGare, mais lus dans la table qu'on nous donne.
  // Une gare PAYÉE reste à zéro : elle est franchie, pas tenue, et le rang de
  // chapitre exige une étoile partout — c'est ce qui empêche d'acheter un
  // chapitre d'or.
  const niv = id => { const r = st[id]; if (!r) return 0; return r.bestDelay === 0 ? 4 : (r.stars || 0); };
  const franchie = id => niv(id) >= 1 || paye.indexOf(id) >= 0;
  const chs = (def && def.chapitres) || [];
  let finis = 0;
  for (const ch of chs) {
    const g = ch.gares || [];
    if (!g.length) continue;
    let bas = 4;
    for (const x of g) bas = Math.min(bas, niv(x));
    if (bas >= SEUIL_OR) d.or += PIECES_PAR_CHAPITRE_DOR;
    if (g.every(franchie)) finis++;
  }
  for (const z of (def && def.zones) || []) {
    const dans = chs.filter(c => c.zone === z.id);
    if (dans.length && dans.every(c => (c.gares || []).every(franchie))) d.zones += PIECES_PAR_ZONE;
  }
  if (chs.length && finis === chs.length) d.carte += PIECES_PAR_CARTE;
  d.medailles = bourseDesMedailles(etatDUneCarte(def, st, paye, serie));
  for (const k of POSTES) d.total += d[k];
  return d;
}
function piecesDUneCarte(def, stations, passees, serie, passeesEnPierres) {
  return detailPiecesDUneCarte(def, stations, passees, serie, passeesEnPierres).total;
}
// CE QU'UNE CARTE RAPPORTE EN PIERRES : une par sans-faute, trois par chapitre
// de diamant. Déduit de `bestDelay`, comme le trophée — mais c'est le stock.
function detailPierresDUneCarte(def, stations) {
  const st = stations || {};
  const d = { sansFaute: 0, diamant: 0, total: 0 };
  for (const id in st) if ((st[id] || {}).bestDelay === 0) d.sansFaute += PIERRE_PAR_SANS_FAUTE;
  const niv = id => { const r = st[id]; if (!r) return 0; return r.bestDelay === 0 ? 4 : (r.stars || 0); };
  for (const ch of (def && def.chapitres) || []) {
    const g = ch.gares || [];
    if (!g.length) continue;
    let bas = 4;
    for (const x of g) bas = Math.min(bas, niv(x));
    if (bas >= SEUIL_DIAMANT) d.diamant += PIERRES_PAR_CHAPITRE_DIAMANT;
  }
  d.total = d.sansFaute + d.diamant;
  return d;
}
// La liste des cartes du compte : celles qu'on a enregistrées, à défaut la
// courante seule. Une carte dont la définition n'a pas pu être lue ne
// rapporte que ses étoiles et ses diamants : on préfère un solde un peu bas à
// un plantage, et `precargerCartes` rend le cas improbable.
function cartesDuCompte() {
  const cartes = typeof getCartesEnregistrees === "function" ? getCartesEnregistrees() : [];
  if (cartes.length) return cartes;
  return [{
    id: typeof getCarteCourante === "function" ? getCarteCourante() : null,
    stations: typeof getProgress === "function" ? getProgress() : {},
    passees: typeof getPassees === "function" ? getPassees() : [],
    passeesEnPierres: typeof getPasseesEnPierres === "function" ? getPasseesEnPierres() : [],
    serie: typeof getSerie === "function" ? getSerie() : { n: 0, record: 0 }
  }];
}
// La somme sur TOUTES les cartes jouées, poste par poste.
function detailPiecesGagnees() {
  const t = { etoiles: 0, avance: 0, or: 0, zones: 0, carte: 0, medailles: 0, total: 0 };
  for (const c of cartesDuCompte()) {
    const def = typeof defDeCarte === "function" ? defDeCarte(c.id) : null;
    const d = detailPiecesDUneCarte(def, c.stations, c.passees, c.serie, c.passeesEnPierres);
    for (const k in t) t[k] += d[k];
  }
  return t;
}
function piecesGagnees() { return detailPiecesGagnees().total; }
// Les pierres, sur toutes les cartes — plus celles qu'on a achetées.
function detailPierresGagnees() {
  const t = { sansFaute: 0, diamant: 0, achetees: 0, total: 0 };
  for (const c of cartesDuCompte()) {
    const def = typeof defDeCarte === "function" ? defDeCarte(c.id) : null;
    const d = detailPierresDUneCarte(def, c.stations);
    t.sansFaute += d.sansFaute; t.diamant += d.diamant;
  }
  t.achetees = typeof getAchats === "function" ? ((getAchats().diamants) | 0) : 0;
  t.total = t.sansFaute + t.diamant + t.achetees;
  return t;
}
function pierresGagnees() { return detailPierresGagnees().total; }
// LE PRIX D'UN PASSAGE SUIT LA POSITION DANS LE RUBAN. Petit au début — pour
// que le débutant bloqué puisse se le payer en rejouant deux ou trois gares —
// et cher en fin de carte, pour qu'on n'achète pas la fin du voyage.
// Ordre de grandeur voulu : trois à cinq gares bien jouées. Au chapitre 1,
// cinq gares à une étoile font 50 pièces, le passage en coûte 50 : le même
// rapport qu'avant le passage à la pièce (5 pour 5).
function prixDePassageDans(def, gareId) {
  const chs = (def && def.chapitres) || [];
  for (let i = 0; i < chs.length; i++)
    if ((chs[i].gares || []).indexOf(gareId) >= 0) return PASSAGE_BASE + i * PASSAGE_PAR_CHAPITRE;
  return PASSAGE_BASE;
}
function prixDePassage(gareId) {
  const ch = typeof chapitreDeGare === "function" ? chapitreDeGare(gareId) : null;
  if (ch) return PASSAGE_BASE + ch.rang * PASSAGE_PAR_CHAPITRE;
  return prixDePassageDans(typeof carteCourante === "function" ? carteCourante() : null, gareId);
}
// Le même passage, en pierres : une au premier chapitre, sept au dixième,
// trente au dernier. La fin du ruban reste hors de prix.
function prixDePassageEnPierresDans(def, gareId) { return Math.ceil(prixDePassageDans(def, gareId) / PIERRE_VAUT); }
function prixDePassageEnPierres(gareId) { return Math.ceil(prixDePassage(gareId) / PIERRE_VAUT); }
// La dépense, elle aussi sur toutes les cartes : les passages payés dont la
// gare est ENCORE à zéro étoile (gagner la gare plus tard rend la mise), plus
// le prix des cartes acquises EN PIÈCES — une carte reçue gratuitement ou
// payée en argent réel ne coûte rien à la bourse.
function piecesDepensees() {
  let d = 0;
  for (const c of cartesDuCompte()) {
    const def = typeof defDeCarte === "function" ? defDeCarte(c.id) : null;
    for (const g of c.passees || [])
      if (!((((c.stations || {})[g]) || {}).stars >= 1)) d += prixDePassageDans(def, g);
  }
  const poss = typeof cartesPossedees === "function" ? cartesPossedees() : {};
  for (const id in poss)
    if (poss[id] === "credits" && typeof prixDeCarte === "function") d += prixDeCarte(id);
  return d;
}
function soldePieces() { return Math.max(0, piecesGagnees() - piecesDepensees()); }
// La dépense en pierres : les passages payés en pierres dont la gare est
// ENCORE à zéro étoile — la mise se rend, comme pour les pièces.
function pierresDepensees() {
  let d = 0;
  for (const c of cartesDuCompte()) {
    const def = typeof defDeCarte === "function" ? defDeCarte(c.id) : null;
    for (const g of c.passeesEnPierres || [])
      if (!((((c.stations || {})[g]) || {}).stars >= 1)) d += prixDePassageEnPierresDans(def, g);
  }
  return d;
}
function stockPierres() { return Math.max(0, pierresGagnees() - pierresDepensees()); }
