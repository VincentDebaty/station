"use strict";
// ------------------------------------------------------------------
// LA CARTE — trois échelles, une seule question à la fois.
// ------------------------------------------------------------------
// Elle remplace la carte géographique zoomable (js/map.js). Le changement
// n'est pas cosmétique : une carte du monde répond à « OÙ », et répondait mal
// à « QUOI ENSUITE » — au point qu'il avait fallu lui adjoindre un carnet de
// service pour poser la question autrement.
//
// Ici chaque échelle pose UNE question et n'en pose qu'une :
//
//   LA LIGNE          où j'en suis, et quelle gare vient après. C'est la vue
//                     par défaut, celle qu'on voit en ouvrant le jeu : la
//                     prochaine gare y est la seule action visible.
//   LA CONSTELLATION  quel corridor prendre au prochain carrefour. Le graphe
//                     des boss, en plan de métro — la lisibilité prime sur la
//                     géographie, comme dans tous les plans de réseau.
//   L'EUROPE          ce qu'il reste du continent. Les constellations colorées
//                     par leur complétion.
//
// On ne se perd pas entre elles : le dézoom est un geste unique et réversible,
// et il n'y a rien à mémoriser.
//
// Ce fichier ne connaît ni la génération ni le score : il lit le graphe
// (js/graph.js), la progression (js/store.js) et le catalogue, et il appelle
// startStation. Rien d'autre.
// ------------------------------------------------------------------

// `bilan` : le résultat du dernier service, posé en bulle sous sa gare sur la
// vue ligne (js/game.js, endGame). Il tient jusqu'au service suivant.
const CARTE = { hote: null, vue: "ligne", corridor: null, depuis: null, bilan: null,
  // Le voyage : la gare d'où le train doit partir, posée par le relevé de fin
  // de service (js/game.js) et consommée au rendu suivant. Une seule fois.
  voyage: null, prochaine: null,
  // Le carrefour ouvert sur la constellation : l'id du hub dont on regarde les
  // sorties, ou null. Un carrefour est une QUESTION — « par où ? » — et le
  // panneau est l'endroit où elle se pose.
  panneau: null };

// ------------------------------------------------------------------
// OÙ EN EST LE JOUEUR ?
// ------------------------------------------------------------------
// Les gares tenues, au format qu'attend le graphe.
function carteTenues() {
  const t = new Set();
  for (const c of CATALOG) if (isBought(c.id)) t.add(c.id);
  return t;
}
// Le corridor à montrer. On préfère celui de la dernière gare jouée : c'est là
// que le joueur a laissé son attention.
//
// UNE LIGNE SE LIT TOUJOURS DEPUIS SON ORIGINE, jamais depuis le bout qu'on
// tient. La première version faisait l'inverse — commencer par une gare
// possédée semblait aimable — et la ligne changeait donc de sens selon l'état
// du joueur : Bruxelles – Luxembourg s'affichait tantôt de Bruxelles vers
// Luxembourg, tantôt à l'envers. Or c'est la même ligne, et un habitué la
// reconnaît à son ordre. L'origine est celle qu'écrit data/graph.js (`de` →
// `vers`, contrôlée alignée sur LIENS), c'est-à-dire celle du monde réel.
function corridorCourant() {
  const tenues = carteTenues();
  const candidates = [];
  if (typeof lastPlayedId === "string" && lastPlayedId) candidates.push(lastPlayedId);
  for (const c of CATALOG) if (isBought(c.id)) candidates.push(c.id);

  for (const gareId of candidates) {
    const lien = corridorDeGare(gareId);
    if (lien) return { lien, depuis: lien.a };
    const hub = hubDeGare(gareId);
    if (hub) {
      // Sur un boss : on montre la sortie la plus avancée, à défaut la première.
      const sorties = sortiesDeHub(hub.id).filter(l => l.gares && l.gares.length);
      if (!sorties.length) continue;
      let best = sorties[0], bestN = -1;
      for (const l of sorties) {
        const n = parcours(l, l.a).gares.filter(g => tenues.has(g)).length;
        if (n > bestN) { bestN = n; best = l; }
      }
      return { lien: best, depuis: best.a };
    }
  }
  return null;
}

// ------------------------------------------------------------------
// L'ÉTAT D'UNE GARE, tel que la carte le montre.
// ------------------------------------------------------------------
// Quatre états, et ils s'excluent : tenue, ouvrable (le pas suivant),
// verrouillée, ou hors d'atteinte. On ne montre jamais un prix sur une gare
// qu'on ne peut pas ouvrir — un blocage muet vaut mieux qu'un faux espoir.
function etatDeGare(id) {
  if (isBought(id)) return "tenue";
  if (typeof isBuyable === "function" && isBuyable(id))
    return (typeof canBuy === "function" && canBuy(id)) ? "ouvrable" : "chere";
  return "fermee";
}
function etoilesDe(id) { return ((getProgress()[id] || {}).stars) || 0; }
function nomDe(id) {
  const c = cardOf(id);
  return c ? (c.city || c.name) : id;
}

// ------------------------------------------------------------------
// LA VUE LIGNE — l'écran d'accueil.
// ------------------------------------------------------------------
function vueLigne() {
  const cc = CARTE.corridor && CARTE.depuis
    ? { lien: CARTE.corridor, depuis: CARTE.depuis } : corridorCourant();
  if (!cc) return vueDepart();

  const tenues = carteTenues();
  const p = parcours(cc.lien, cc.depuis);
  const hDep = hubById(p.depuis), hArr = hubById(p.vers);
  // CE QUI EST OUVRABLE, PAS CE QUI EST PREMIER. `prochaineGare` rend la
  // première gare non tenue en partant du hub — ce qui désigne Ottignies quand
  // le joueur tient Landen au milieu du corridor, et qu'il ne peut ouvrir que
  // Hasselt ou Liège. On demande donc au graphe ce qui est réellement à portée.
  //
  // Il peut y en avoir DEUX : tenir une gare au milieu d'une ligne, c'est
  // pouvoir aller des deux côtés. On les marque toutes, et le bouton d'appel
  // ne s'affiche que s'il n'y a pas d'ambiguïté — proposer « la » suite quand
  // il y en a deux, ce serait choisir à la place du joueur.
  const ouvrables = typeof garesOuvrables === "function"
    ? garesOuvrables(tenues) : new Set();
  const surLaLigne = [...p.gares, hArr && hArr.gareId, hDep && hDep.gareId]
    .filter(g => g && ouvrables.has(g));
  const prochaine = surLaLigne.length === 1 ? surLaLigne[0] : null;
  // Le voyage a besoin d'une destination, et c'est ICI qu'elle se calcule.
  // Deux gares ouvrables : pas de trajet — on ne choisit pas pour le joueur.
  CARTE.prochaine = prochaine;

  // LE RANG DE LA LIGNE, en couleur sur le tracé. Une ligne toute tenue n'est
  // pas une ligne finie : c'est là que commence le vrai jeu, celui de la
  // repasser jusqu'à l'or. Le rang le dit sans rien exiger — il se voit, il ne
  // s'annonce pas.
  const rang = typeof rangDeLigne === "function" ? rangDeLigne(cc.lien, cc.depuis) : null;

  // Le nom de la ligne : ses deux bouts. Les vrais noms — « le sillon
  // Sambre-et-Meuse » — s'écriront dans data/graph.js, ils ne se déduisent pas.
  const titre = `${hDep ? hDep.nom : "?"} – ${hArr ? hArr.nom : "?"}`;
  // LA JAUGE COMPTE EXACTEMENT L'ENSEMBLE QUE LE RANG JUGE. Elle le comptait
  // à part — les intermédiaires plus le boss d'arrivée — et le rang, lui, a
  // fini par inclure les deux bouts : « 5 / 5 » se serait affiché à côté d'une
  // ligne sans rang, et le joueur aurait cherché longtemps la gare manquante.
  // Une seule source, comme pour le palmarès.
  const composition = typeof garesDeLigne === "function"
    ? garesDeLigne(cc.lien, cc.depuis)
    : p.gares.concat(hArr && hArr.gareId ? [hArr.gareId] : []);
  const total = composition.length;
  const faits = typeof garesFaites === "function"
    ? garesFaites(composition) : composition.filter(g => tenues.has(g)).length;

  // LE BOUTON D'APPEL : sous la ligne d'ordinaire ; DANS LA BULLE du résultat
  // quand il y en a une — le service fini, la suite se lit au même endroit
  // que le résultat, et le regard n'a pas à descendre au bas de l'écran.
  const suite = prochaine ? `<button class="c-suite" data-gare="${prochaine}">▸ ${
    isBought(prochaine) ? "Reprendre" : "Ouvrir"} ${nomDe(prochaine)}</button>` : "";
  // Dans la bulle, le bouton dit « Suivante » et rien d'autre : le nom de la
  // gare est déjà sur la ligne, à côté, et « Ouvrir Aix-la-Chapelle » ferait
  // une bulle large comme la ligne. Une largeur fixe, quel que soit le nom.
  // Une vraie flèche, à droite — c'est un bouton qui emmène, pas une puce.
  const fleche = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
    'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<path d="M5 12h13M12 6l6 6-6 6"/></svg>';
  const suiteBulle = prochaine
    ? `<button class="c-suite cb-suite" data-gare="${prochaine}" title="${nomDe(prochaine)}">Suivante${fleche}</button>` : "";
  const jalon = (id, role) => {
    const etat = id ? etatDeGare(id) : "fermee";
    const cl = ["jalon", "j-" + etat, role ? "j-" + role : ""].filter(Boolean).join(" ");
    const st = id ? etoilesDe(id) : 0;
    const bilan = id && CARTE.bilan && CARTE.bilan.gare === id;
    return `<button class="${cl}${bilan ? " j-bilan" : ""}" data-gare="${id || ""}" ${id ? "" : "disabled"}` +
      `${id && surLaLigne.includes(id) ? ' data-suivante="1"' : ""}>` +
      `<span class="pastille"></span>` +
      `<span class="nom">${id ? nomDe(id) : "?"}</span>` +
      `<span class="etoiles">${st ? "★".repeat(st) : ""}</span>` +
      `</button>`;
  };

  return `
    <div class="c-tete">
      <button class="c-zoom" data-vue="constellation">${hDep && zoneById(hDep.zone) ? zoneById(hDep.zone).nom : "Le réseau"} ›</button>
      <div class="c-titre"><span class="c-nom">${titre}</span>${rang
        ? `<span class="c-rang r-${rang.id}">${rang.nom}</span>`
        : `<span class="c-avance">${faits} / ${total}</span>`}</div>
      ${bourseHTML()}
    </div>
    <div class="c-ligne${CARTE.bilan ? " avec-bilan" : ""}"${rang ? ` data-rang="${rang.id}"` : ""}>
      ${jalon(hDep && hDep.gareId, "boss")}
      ${p.gares.map(g => jalon(g)).join("")}
      ${jalon(hArr && hArr.gareId, "boss")}
      ${bilanHTML(suiteBulle)}
    </div>
    ${CARTE.bilan ? "" : suite}`;
}

// ------------------------------------------------------------------
// LA BULLE DU RÉSULTAT — sous la gare qu'on vient de tenir.
// ------------------------------------------------------------------
// Le relevé de fin a été une fiche, puis une bande : un écran de plus entre
// le service et la carte, qui disait beaucoup et ne montrait rien. Ici le
// résultat s'inscrit LÀ OÙ IL COMPTE — sous le jalon de la gare, dont il
// reprend les étoiles en grand — et il ne dit que ce que les étoiles ne
// disent pas : le retard, et ce qu'il vaut face au record. Pas de bouton :
// la gare suivante est à un doigt sur la ligne, la gare jouée aussi.
function bilanHTML(suite) {
  const b = CARTE.bilan;
  if (!b) return "";
  const cl = "c-bilan" + (b.perfect ? " parfait" : "") + (b.win ? "" : " rate");
  const etoiles = typeof etoilesHTML === "function" ? etoilesHTML(b.stars, b.prevStars) : "";
  const retard = b.failed
    ? `<div class="cb-retard"><b>${b.d}</b> min — plafond dépassé</div>`
    : `<div class="cb-retard"><b>${b.d}</b> min de retard</div>`;
  // Le record : battu (de combien), égalé, ou celui qui tient toujours. Un
  // premier service n'a rien à battre ; un échec n'a rien à comparer.
  let rec = "";
  if (b.failed) rec = "";
  else if (!b.win) rec = `<div class="cb-record loin">objectif manqué</div>`;
  else if (b.prevBest == null) rec = `<div class="cb-record neuf">premier service</div>`;
  else if (b.d < b.prevBest) rec = `<div class="cb-record bat">record battu · −${b.prevBest - b.d} min</div>`;
  else if (b.d === b.prevBest) rec = `<div class="cb-record egal">record égalé</div>`;
  else rec = `<div class="cb-record loin">record : ${b.prevBest} min</div>`;
  return `<div class="${cl}" role="status"><div class="cb-etoiles">${etoiles}</div>${retard}${rec}${suite || ""}</div>`;
}
// La bulle se pose APRÈS le rendu, parce qu'elle se mesure : centrée sous le
// jalon, à la hauteur de ses petites étoiles (qu'elle remplace). Enfant de la
// piste et non de la carte, elle défile avec la ligne.
function poserBilan() {
  if (!CARTE.hote) return;
  const bulle = CARTE.hote.querySelector(".c-bilan");
  const jalon = CARTE.hote.querySelector(".jalon.j-bilan");
  if (!bulle || !jalon) { if (bulle) bulle.remove(); return; }
  const et = jalon.querySelector(".etoiles");
  const piste = jalon.parentElement;
  const haut = (et ? et.offsetTop : jalon.offsetHeight) - 6;   // la bulle part d'ici, dans le jalon
  // LE GROUPE SE CENTRE — jalons ET bulle. La piste centre ses jalons dans sa
  // hauteur ; on lui retire en bas ce que la bulle dépasse du jalon, et le
  // centre des jalons remonte d'autant : c'est l'ensemble qui se retrouve au
  // milieu. Posé AVANT de mesurer le jalon, puisque cela le déplace.
  const depasse = bulle.offsetHeight - (jalon.offsetHeight - haut);
  piste.style.paddingBottom = Math.max(0, depasse) + "px";
  bulle.style.left = (jalon.offsetLeft + jalon.offsetWidth / 2) + "px";
  bulle.style.top = (jalon.offsetTop + haut) + "px";
  // Ligne longue : la gare jouée doit être à l'écran. Le voyage (animerVoyage)
  // fait déjà défiler vers la suivante, qui est voisine — sinon on cadre ici.
  if (!CARTE.voyage && piste.scrollWidth > piste.clientWidth) {
    const cx = jalon.offsetLeft + jalon.offsetWidth / 2;
    piste.scrollTo({ left: Math.max(0, cx - piste.clientWidth / 2) });
  }
}
window.addEventListener("resize", () => { if (CARTE.bilan) poserBilan(); });

// Aucune gare tenue : le tout premier écran. ON Y CHOISIT UNE LIGNE, pas une
// gare.
//
// Il proposait les gares faciles reliées au réseau : Landen, Herentals,
// Deinze — des noms sans lendemain, posés au milieu de nulle part. Le joueur
// choisissait un POINT là où tout le reste du jeu lui fait choisir une
// DIRECTION, et se retrouvait, son premier service fini, sur une ligne dont
// il n'avait rien décidé.
//
// Une ligne, donc, avec ses deux bouts et sa longueur ; le premier service se
// joue sur la gare qui suit le hub de départ, et l'on remonte le corridor
// jusqu'au boss d'en face. Le pays se choisit du même geste — c'est bien le
// drapeau qu'on regarde en premier, et un joueur commence par CHEZ LUI.
function vueDepart() {
  const lignes = typeof lignesDeDepart === "function" ? lignesDeDepart() : [];
  if (!lignes.length) return `
    <div class="c-tete"><div class="c-titre">Aucune ligne n'est encore écrite</div></div>`;
  // L'ordre du catalogue, c'est-à-dire l'ordre des pays d'index.json : le
  // joueur trouve le sien sans le chercher.
  const rang = g => { const i = CATALOG.findIndex(c => c.id === g); return i < 0 ? 1e9 : i; };
  lignes.sort((x, y) => rang(x.gares[0]) - rang(y.gares[0]));

  const porte = lien => {
    const hA = hubById(lien.a), hB = hubById(lien.b);
    const premiere = cardOf(lien.gares[0]);
    const drapeau = ((premiere && premiere.country) || "").trim().split(" ")[0];
    return `<button class="porte" data-lien="${cleDeLien(lien)}">
      <span class="pays">${drapeau}</span>
      <span class="nom">${hA ? hA.nom : lien.a} <i>→</i> ${hB ? hB.nom : lien.b}</span>
      <span class="detail">${lien.gares.length} gares · on démarre à ${nomDe(lien.gares[0])}</span>
    </button>`;
  };
  return `
    <div class="c-tete"><div class="c-titre">Choisissez votre première ligne</div></div>
    <div class="c-portes">${lignes.map(porte).join("")}</div>`;
}

// ------------------------------------------------------------------
// LA VUE CONSTELLATION — le graphe des boss, en plan de métro.
// ------------------------------------------------------------------
// La géographie exacte n'est pas requise et nuirait : un plan de réseau se lit
// parce qu'il redresse. On garde seulement l'orientation relative des villes,
// en projetant leurs coordonnées puis en étirant pour occuper l'écran.
function vueConstellation() {
  const cc = corridorCourant();
  const ancre = cc ? hubById(cc.depuis) : null;
  const zones = zonesDeCarte();
  const cid = ancre ? ancre.zone : (zones[0] || {}).id;
  const cst = zoneById(cid) || zones[0];
  const hubs = hubsDeZone(cid);
  if (!hubs.length || !cst) return vueLigne();

  const tenues = carteTenues();
  const lons = hubs.map(h => h.ll[0]), lats = hubs.map(h => h.ll[1]);
  const x0 = Math.min(...lons), x1 = Math.max(...lons);
  const y0 = Math.min(...lats), y1 = Math.max(...lats);
  const X = l => 8 + (x1 === x0 ? 46 : (l - x0) / (x1 - x0) * 84);
  const Y = l => 92 - (y1 === y0 ? 46 : (l - y0) / (y1 - y0) * 84);

  // Les liens internes à la constellation, plus ceux qui en sortent (ils
  // disent où l'on pourra aller ensuite).
  const dedans = new Set(hubs.map(h => h.id));
  let traits = "";
  for (const lien of tousLesLiens()) {
    const a = lien.a, b = lien.b, t = lien.type;
    if (!dedans.has(a) && !dedans.has(b)) continue;
    const ha = hubById(a), hb = hubById(b);
    if (!ha || !hb) continue;
    const sortant = !dedans.has(a) || !dedans.has(b);
    const ouvert = (ha.gareId && tenues.has(ha.gareId)) || (hb.gareId && tenues.has(hb.gareId));
    // MÊME LOGIQUE À TOUTES LES ÉCHELLES : le rang colore le trait ici comme
    // il colore le tracé de la vue ligne. C'est ce qui fait qu'on dézoome pour
    // regarder son travail, et pas seulement pour chercher son chemin.
    const rg = lien && typeof rangDeLigne === "function" ? rangDeLigne(lien, lien.a) : null;
    const geo = `x1="${X(ha.ll[0])}" y1="${Y(ha.ll[1])}" x2="${X(hb.ll[0])}" y2="${Y(hb.ll[1])}"`;
    const trace = `<line ${geo} class="trait${ouvert ? " ouvert" : ""}` +
      `${sortant ? " sortant" : ""}${t === "mer" ? " mer" : ""}${rg ? " r-" + rg.id : ""}"/>`;
    // LE TRAIT EST UNE LIGNE, DONC ON DOIT POUVOIR LA PRENDRE. Un trait de
    // 0,7 unité dans un carré de 100 ne s'attrape pas au doigt : on lui adosse
    // une cible transparente bien plus large, invisible et seule cliquable.
    // Une ligne pas encore écrite (`gares` vide) n'en reçoit pas — on ne rend
    // pas cliquable ce qui n'ouvrirait rien.
    traits += (lien && lien.gares && lien.gares.length)
      ? `<g class="lien" data-lien="${cleDeLien(lien)}"><line ${geo} class="cible"/>${trace}</g>`
      : trace;
  }
  const points = hubs.map(h => {
    const tenu = h.gareId && tenues.has(h.gareId);
    const jouable = h.gareId && isBuyable(h.gareId);
    const maitrise = tenu && bossMaitrise(h.id, tenues);
    const r = h.rang === 1 ? 2.6 : 1.9;
    // Le carrefour ouvert se marque : sans quoi le panneau flotte, et l'on ne
    // sait plus de quel point il parle.
    return `<g class="hub${tenu ? " tenu" : ""}${jouable ? " jouable" : ""}${maitrise ? " maitrise" : ""}` +
      `${h.gareId ? "" : " absent"}${CARTE.panneau === h.id ? " choisi" : ""}"` +
      ` data-hub="${h.id}"${h.gareId ? ` data-gare="${h.gareId}"` : ""}>` +
      `<circle class="cerne" cx="${X(h.ll[0])}" cy="${Y(h.ll[1])}" r="${r + 2.2}"/>` +
      `<circle cx="${X(h.ll[0])}" cy="${Y(h.ll[1])}" r="${r}"/>` +
      `<text x="${X(h.ll[0])}" y="${Y(h.ll[1]) - 4}">${h.nom}</text></g>`;
  }).join("");

  return `
    <div class="c-tete">
      <button class="c-zoom" data-vue="europe">${nomDeCarte()} ›</button>
      <div class="c-titre" style="color:${cst.couleur}">${cst.nom}</div>
      <button class="c-retour" data-vue="ligne">‹ Ma ligne</button>
    </div>
    <svg class="c-graphe" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet">
      <g class="traits">${traits}</g>${points}
    </svg>
    ${CARTE.panneau ? panneauDeHub(CARTE.panneau, tenues) : ""}`;
}

// ------------------------------------------------------------------
// LE PANNEAU D'UN CARREFOUR — « par où ? », et rien d'autre.
// ------------------------------------------------------------------
// Un boss n'est pas une gare de plus sur la carte : c'est l'endroit où le
// joueur CHOISIT sa direction, et ce choix est le cœur de la progression. Le
// clic sur le point ouvrait la gare directement — il sautait donc par-dessus
// la seule décision que la vue constellation existe pour poser.
//
// Ici, le point ouvre la liste de ses sorties. Chacune dit ce qu'elle vaut :
// son rang quand elle est faite, sa jauge quand elle est en cours, « à écrire »
// quand le corridor n'existe pas encore. La gare du boss reste jouable, en
// tête de liste, parce qu'elle est une étape de la ligne et non son résumé.
function panneauDeHub(hubId, tenues) {
  const h = hubById(hubId);
  if (!h) return "";
  const sorties = sortiesDeHub(hubId);
  const maitrise = h.gareId && tenues.has(h.gareId) && bossMaitrise(hubId, tenues);

  const rangs = sorties.map(lien => {
    const vers = lien.a === hubId ? lien.b : lien.a;
    const hv = hubById(vers);
    const ecrite = !!(lien.gares && lien.gares.length);
    if (!ecrite)
      return `<div class="p-ligne p-absente"><span class="p-vers">${hv ? hv.nom : vers}</span>` +
        `<span class="p-note">à écrire</span></div>`;
    const rang = typeof rangDeLigne === "function" ? rangDeLigne(lien, hubId) : null;
    const composition = typeof garesDeLigne === "function"
      ? garesDeLigne(lien, hubId) : lien.gares;
    const total = composition.length;
    // Le MÊME compte que la vue ligne (js/recompense.js) : « 7 / 7 » s'affichait
    // ici à côté d'une ligne sans rang, parce qu'on comptait les gares payées
    // là où le rang exige des gares faites.
    const faits = typeof garesFaites === "function"
      ? garesFaites(composition) : composition.filter(g => tenues.has(g)).length;
    return `<button class="p-ligne${faits ? " p-entamee" : ""}" data-lien="${cleDeLien(lien)}">` +
      `<span class="p-vers">${hv ? hv.nom : vers}</span>` +
      `<span class="p-jauge"><i style="width:${Math.round(100 * faits / total)}%"></i></span>` +
      (rang ? `<span class="c-rang r-${rang.id}">${rang.nom}</span>`
            : `<span class="p-note">${faits} / ${total}</span>`) +
      `</button>`;
  }).join("");

  const etat = h.gareId ? etatDeGare(h.gareId) : null;
  const st = h.gareId ? etoilesDe(h.gareId) : 0;
  const gare = (etat === "tenue" || etat === "ouvrable")
    ? `<button class="p-gare j-${etat}" data-gare="${h.gareId}">` +
      `<span class="p-vers">${etat === "tenue" ? "▸ Jouer" : "▸ Ouvrir"} ${nomDe(h.gareId)}</span>` +
      `<span class="p-note">${st ? "★".repeat(st) : ""}</span></button>`
    : "";

  return `<div class="c-panneau"${maitrise ? ' data-maitrise="1"' : ""}>
      <div class="p-tete">
        <span class="p-nom">${h.nom}</span>
        <span class="p-sous">${maitrise ? "Gare maîtrisée" :
          sorties.length + (sorties.length > 1 ? " lignes" : " ligne")}</span>
        <button class="p-fermer" data-fermer="1" aria-label="Fermer">✕</button>
      </div>
      ${gare}
      <div class="p-lignes">${rangs}</div>
    </div>`;
}

// La clé d'un lien dans le DOM, et son retour. Le graphe n'attribue pas d'id
// aux corridors : ses deux bouts en tiennent lieu, et l'ordre est celui du
// graphe — jamais celui de la lecture.
function cleDeLien(lien) { return lien.a + "~" + lien.b; }
function lienDeCle(cle) {
  buildGraphe();
  const [a, b] = String(cle || "").split("~");
  return GRAPHE.corridors.find(l =>
    (l.a === a && l.b === b) || (l.a === b && l.b === a)) || null;
}
// Ouvrir une ligne, c'est descendre d'une échelle en gardant la question.
//
// TOUJOURS DEPUIS SON ORIGINE, jamais depuis le bout par lequel on l'a prise :
// c'est la règle de `corridorCourant`, et elle vaut ici pour la même raison.
// Bruxelles – Luxembourg ouverte depuis le panneau de Luxembourg s'afficherait
// sinon à l'envers de la même ligne ouverte depuis celui de Bruxelles, et le
// joueur ne reconnaîtrait plus une ligne qu'il connaît. La destination
// annoncée par la rangée du panneau, elle, reste juste : elle dit où l'on VA,
// pas dans quel sens le tracé se dessine.
function ouvrirLigne(cle) {
  const lien = lienDeCle(cle);
  if (!lien || !lien.gares || !lien.gares.length) return;
  CARTE.corridor = lien;
  CARTE.depuis = lien.a;
  CARTE.panneau = null;
  CARTE.vue = "ligne";
  renderCarte();
}

// ------------------------------------------------------------------
// LA VUE CARTE — ce qu'il reste du territoire, zone par zone.
// ------------------------------------------------------------------
// L'identifiant de vue reste « europe » (classes CSS .v-europe, .c-europe) :
// c'est le dézoom maximal d'UNE carte, quel que soit son nom.
function vueEurope() {
  const tenues = carteTenues();
  const cartes = zonesDeCarte().map(c => {
    const hubs = hubsDeZone(c.id);
    const jouables = hubs.filter(h => h.gareId);
    const tenus = jouables.filter(h => tenues.has(h.gareId));
    const part = jouables.length ? Math.round(100 * tenus.length / jouables.length) : 0;
    return `<button class="cst" data-const="${c.id}" style="--col:${c.couleur}">
      <span class="cst-nom">${c.nom}</span>
      <span class="cst-jauge"><i style="width:${part}%"></i></span>
      <span class="cst-chiffre">${jouables.length ? `${tenus.length} / ${jouables.length}`
        : `${hubs.length} gares à écrire`}</span>
    </button>`;
  }).join("");
  return `
    <div class="c-tete">
      <div class="c-titre">${nomDeCarte()}</div>
      <button class="c-retour" data-vue="ligne">‹ Ma ligne</button>
    </div>
    <div class="c-europe">${cartes}</div>`;
}

// ------------------------------------------------------------------
// RENDU ET GESTES
// ------------------------------------------------------------------
// Le grade, les étoiles et la série, en tête d'écran. Les crédits vivaient là ;
// ils sont partis, et le grade a pris toute la place.
//
// LA SÉRIE NE S'AFFICHE QU'À PARTIR DE DEUX. En dessous il n'y a pas d'élan à
// entretenir, seulement un « 1 » permanent de plus à côté des étoiles — et un
// compteur qu'on voit toujours cesse d'être vu.
function bourseHTML() {
  if (typeof gradeOf !== "function" || typeof etoilesTotal !== "function") return "";
  const n = etoilesTotal(), g = gradeOf(n);
  const s = typeof getSerie === "function" ? getSerie() : { n: 0 };
  return `<div class="c-compteurs">` +
    // « » » et non « ▸ » : la flèche simple veut déjà dire « le pas suivant »
    // dans le palmarès et sur le bouton de suite. La reprendre ici pour dire
    // « d'affilée » ferait porter deux sens au même signe.
    (s.n >= 2 ? `<span class="c-serie" title="${s.n} services d'affilée sous dix minutes">` +
      `\u00BB ${s.n}</span>` : "") +
    `<span class="c-grade" title="${g.nom}">` +
      `<span class="g-nom">${g.nom}</span>` +
      `<span class="g-jauge"><i style="width:${Math.round(g.part * 100)}%"></i></span></span>` +
    `<span class="c-etoiles">\u2605 ${n}</span></div>`;
}

function renderCarte() {
  const hote = document.getElementById("hub-map");
  if (!hote) return;
  CARTE.hote = hote;
  hote.className = "carte v-" + CARTE.vue;
  hote.innerHTML = CARTE.vue === "constellation" ? vueConstellation()
                 : CARTE.vue === "europe" ? vueEurope() : vueLigne();
  // Le relevé de fin anime le solde : il lui faut l'élément, refait à chaque rendu.
  CARTE.etoiles = hote.querySelector(".c-etoiles");
  poserBilan();    // avant le voyage : lui lit CARTE.voyage, et le consomme
  animerVoyage();

  // Un seul écouteur, posé sur l'hôte : le contenu se refait à chaque rendu,
  // et des écouteurs par élément fuiraient à chaque changement de vue.
  hote.onclick = ev => {
    const vue = ev.target.closest("[data-vue]");
    if (vue) {
      CARTE.vue = vue.dataset.vue; CARTE.corridor = null; CARTE.panneau = null;
      renderCarte(); return;
    }
    const cst = ev.target.closest("[data-const]");
    if (cst) { CARTE.vue = "constellation"; CARTE.panneau = null; renderCarte(); return; }
    if (ev.target.closest("[data-fermer]")) { CARTE.panneau = null; renderCarte(); return; }
    // UNE LIGNE SE PREND EN LA TOUCHANT. Le trait du plan et la ligne du
    // panneau portent la même marque et font la même chose : ouvrir la vue
    // ligne. C'est le seul geste qui descende d'une échelle.
    const lien = ev.target.closest("[data-lien]");
    if (lien) { ouvrirLigne(lien.dataset.lien); return; }
    // LE CARREFOUR POSE SA QUESTION AVANT DE LANCER SA GARE. Le point porte
    // aussi `data-gare` — on le teste donc en premier, sans quoi le clic
    // partirait en jeu et le choix de direction n'aurait jamais lieu.
    const hub = ev.target.closest("[data-hub]");
    if (hub) {
      CARTE.panneau = CARTE.panneau === hub.dataset.hub ? null : hub.dataset.hub;
      renderCarte(); return;
    }
    const g = ev.target.closest("[data-gare]");
    if (g && g.dataset.gare) { jouerOuOuvrir(g.dataset.gare); return; }
    // Cliquer à côté referme le panneau : c'est le geste qu'on essaie d'abord.
    if (CARTE.panneau) { CARTE.panneau = null; renderCarte(); }
  };
}

// Un seul geste sur une gare, et il fait ce qu'il faut : jouer si elle est
// tenue, l'ouvrir si elle est à portée, ne rien faire sinon. Demander au
// joueur de distinguer les deux serait lui faire porter notre modèle.
function jouerOuOuvrir(gareId) {
  const i = CATALOG.findIndex(c => c.id === gareId);
  if (i < 0) return;
  if (isBought(gareId)) { startStation(i); return; }
  if (typeof canBuy === "function" && canBuy(gareId) && buyStationById(gareId)) {
    renderCarte();
    startStation(i);
    return;
  }
  renderCarte();   // rien n'a bougé : on rafraîchit l'état affiché
}

// ------------------------------------------------------------------
// LE VOYAGE — un train qui roule jusqu'à la gare suivante.
// ------------------------------------------------------------------
// Ce n'est pas un ornement. Le relevé de fin de service désigne une gare par
// son NOM, dans un bouton ; la carte la marque d'un halo. Entre les deux, le
// joueur doit faire lui-même le lien entre un mot et un point — et sur une
// ligne de sept gares, ce lien se fait mal.
//
// Le train le fait à sa place : il part de la gare qu'on vient de quitter et
// s'arrête sur celle qui vient. Le trajet EST la phrase, et il n'y a plus rien
// à lire.
//
// Il ne se déclenche que sur la vue ligne, une seule fois, et seulement quand
// la destination est SANS AMBIGUÏTÉ (`CARTE.prochaine`, qui reste nul quand
// deux gares sont ouvrables des deux côtés). Un train qui part au hasard vers
// l'une des deux mentirait.
function animerVoyage() {
  const de = CARTE.voyage;
  CARTE.voyage = null;                    // consommé : on ne rejoue pas au rendu suivant
  if (!de || CARTE.vue !== "ligne" || !CARTE.hote) return;
  const vers = CARTE.prochaine;
  if (!vers || vers === de) return;
  const piste = CARTE.hote.querySelector(".c-ligne");
  if (!piste) return;
  const a = piste.querySelector('[data-gare="' + de + '"]');
  const b = piste.querySelector('[data-gare="' + vers + '"]');
  if (!a || !b) return;                   // la gare jouée n'est pas sur cette ligne
  // Les animations coûtent leur poids en confort : qui les a désactivées au
  // niveau du système ne veut pas d'un train qui traverse son écran.
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  const centre = el => el.offsetLeft + el.offsetWidth / 2;
  const x0 = centre(a), x1 = centre(b);
  const train = document.createElement("div");
  train.className = "c-train";
  train.textContent = x1 >= x0 ? "\u25B8" : "\u25C2";
  train.style.top = (a.offsetTop + 21) + "px";   // l'axe du rail (.jalon::before)
  piste.appendChild(train);

  // La durée suit la DISTANCE, avec un plancher et un plafond : deux gares
  // voisines ne méritent pas une seconde entière, et huit gares d'écart ne
  // doivent pas faire attendre.
  const duree = Math.max(420, Math.min(1100, Math.abs(x1 - x0) * 3.2));
  const anim = train.animate(
    [{ transform: "translateX(" + x0 + "px)", opacity: 0 },
     { transform: "translateX(" + x0 + "px)", opacity: 1, offset: 0.12 },
     { transform: "translateX(" + x1 + "px)", opacity: 1 }],
    { duration: duree, easing: "cubic-bezier(.4,0,.25,1)", fill: "forwards" });
  // La piste défile AVEC le train : sur une ligne longue, la destination est
  // hors écran, et une animation qu'on ne voit pas n'a pas eu lieu.
  if (piste.scrollWidth > piste.clientWidth)
    piste.scrollTo({ left: Math.max(0, x1 - piste.clientWidth / 2), behavior: "smooth" });
  anim.onfinish = () => {
    train.remove();
    b.classList.add("arrivee");           // la pastille accuse réception
    setTimeout(() => b.classList.remove("arrivee"), 900);
  };
}
