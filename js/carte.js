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
// `zone` : la zone choisie depuis la vue Europe ; nulle, la vue zone s'ancre
// sur la ligne en cours (ou la première zone, au tout premier écran).
const CARTE = { hote: null, vue: "ligne", corridor: null, depuis: null, bilan: null, zone: null,
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
// ------------------------------------------------------------------
// LE SENS DE LECTURE — on avance de la gauche vers la droite, toujours.
// ------------------------------------------------------------------
// La ligne s'est d'abord lue depuis le bout qu'on tenait, puis — pour qu'elle
// ne change pas de sens selon l'état du joueur — TOUJOURS depuis son origine
// écrite (`de` → `vers` dans data/cartes). C'était compter sans le fait qu'un
// corridor se prend par n'importe lequel de ses deux bouts : Lille –
// Bruxelles, prise à Bruxelles, s'affichait avec le joueur tout à droite et
// sa progression qui remontait vers la gauche. Un jeu se parcourt dans le
// sens de la lecture, et c'est plus fort que la fidélité au sens d'écriture.
//
// On lit donc DEPUIS LE BOUT QU'ON TIENT. Les deux bouts tenus, la ligne est
// finie : on revient au sens d'écriture — sauf si le service qui vient de
// s'achever est justement l'un des deux, auquel cas il reste là où le joueur
// vient de le voir, à droite, plutôt que de traverser l'écran sous sa bulle.
function sensDeLecture(lien, prefere) {
  if (!lien) return null;
  const gare = h => (hubById(h) || {}).gareId;
  const tenu = h => { const g = gare(h); return !!g && isBought(g); };
  const ta = tenu(lien.a), tb = tenu(lien.b);
  // Le hub d'où l'on vient de partir gagne : c'est le geste le plus récent.
  if (prefere && (prefere === lien.a || prefere === lien.b) && tenu(prefere)) return prefere;
  if (tb && !ta) return lien.b;
  if (ta && !tb) return lien.a;
  if (ta && tb && CARTE.bilan && CARTE.bilan.gare === gare(lien.a)) return lien.b;
  return lien.a;
}

// Le corridor à montrer. On préfère celui de la dernière gare jouée : c'est là
// que le joueur a laissé son attention.
function corridorCourant() {
  const tenues = carteTenues();
  const candidates = [];
  if (typeof lastPlayedId === "string" && lastPlayedId) candidates.push(lastPlayedId);
  for (const c of CATALOG) if (isBought(c.id)) candidates.push(c.id);

  for (const gareId of candidates) {
    const lien = corridorDeGare(gareId);
    if (lien) return { lien, depuis: sensDeLecture(lien) };
    const hub = hubDeGare(gareId);
    if (hub) {
      // Sur un boss : on montre la sortie la plus avancée, à défaut la première.
      const sorties = sortiesDeHub(hub.id).filter(l => l.gares && l.gares.length);
      if (!sorties.length) continue;
      // À égalité, la ligne de départ du hub (celle qui en part, niveau 1 en
      // tête) : c'est elle qu'on montre à qui vient de choisir sa métropole.
      const dep = sorties.find(l => l.a === hub.id && typeof lignesDeDepart === "function" &&
        lignesDeDepart().includes(l));
      let best = dep || sorties[0], bestN = -1;
      for (const l of sorties) {
        const n = parcours(l, l.a).gares.filter(g => tenues.has(g)).length;
        if (n > bestN) { bestN = n; best = l; }
      }
      // Sur un hub, on part DE LUI : c'est le bout qu'on tient.
      return { lien: best, depuis: sensDeLecture(best, hub.id) };
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
  // UN SEUL BOUTON D'APPEL, DEUX PLACES. Celui de la ligne portait une puce
  // « ▸ » et sa propre taille : deux boutons différents pour le même geste,
  // selon qu'un service venait de finir ou non. Même flèche, même mesure —
  // seule la place change (voir .c-suite, css/station.css).
  const fleche = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
    'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<path d="M5 12h13M12 6l6 6-6 6"/></svg>';
  const suite = prochaine ? `<button class="c-suite" data-gare="${prochaine}">${
    isBought(prochaine) ? "Reprendre" : "Ouvrir"} ${nomDe(prochaine)}${fleche}</button>` : "";
  // Dans la bulle, le bouton dit « Suivante » et rien d'autre : le nom de la
  // gare est déjà sur la ligne, à côté, et « Ouvrir Aix-la-Chapelle » ferait
  // une bulle large comme la ligne. Une largeur fixe, quel que soit le nom.
  // UN HUB BATTU OUVRE UN CHOIX, pas une gare. Finir une ligne sur sa
  // métropole, c'est se retrouver à un carrefour : la suite est l'une de ses
  // sorties, et c'est au joueur de la choisir (meta-progression §2). La bulle
  // l'envoie donc au panneau du hub plutôt que de lui désigner — comme avant —
  // la seule gare ouvrable restée sur CETTE ligne, qui était le hub d'où il
  // venait : « tu viens de battre Bruxelles, retourne à Lille ».
  const hubBilan = CARTE.bilan && CARTE.bilan.win && typeof hubDeGare === "function"
    ? hubDeGare(CARTE.bilan.gare) : null;
  // OBJECTIF MANQUÉ : ON NE PASSE PAS. Zéro étoile, c'est le même service à
  // refaire — et la bulle proposait quand même « Suivante », ce qui revenait
  // à dire que rater n'empêche rien. Elle ne propose donc plus qu'une chose :
  // la gare qu'on vient de manquer. La ligne reste cliquable autour, mais ce
  // n'est plus le jeu qui pousse.
  const boucle = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" ' +
    'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<path d="M20 11.5A8 8 0 1 1 17.4 6L20 8.5"/><path d="M20 4v5h-5"/></svg>';
  const rate = !!(CARTE.bilan && !CARTE.bilan.win);
  const suiteBulle = rate
    ? `<button class="c-suite cb-suite cb-rejouer" data-gare="${CARTE.bilan.gare}" title="${nomDe(CARTE.bilan.gare)}">Recommencer${boucle}</button>`
    : hubBilan
    ? `<button class="c-suite cb-suite" data-carrefour="${hubBilan.id}">Choisir la direction${fleche}</button>`
    : prochaine
    ? `<button class="c-suite cb-suite" data-gare="${prochaine}" title="${nomDe(prochaine)}">Suivante${fleche}</button>` : "";
  const jalon = (id, role) => {
    const etat = id ? etatDeGare(id) : "fermee";
    const cl = ["jalon", "j-" + etat, role ? "j-" + role : ""].filter(Boolean).join(" ");
    const st = id ? etoilesDe(id) : 0;
    const bilan = id && CARTE.bilan && CARTE.bilan.gare === id;
    // UNE GARE FERMÉE NE SE CLIQUE PAS. Elle se voyait éteinte, et le doigt
    // partait quand même dessus : le clic ne faisait rien, sans le dire. Le
    // bouton est désormais désactivé — le geste n'est plus offert du tout.
    return `<button class="${cl}${bilan ? " j-bilan" : ""}" data-gare="${id || ""}" ${id && etat !== "fermee" ? "" : "disabled"}` +
      `${id && (rate ? id === CARTE.bilan.gare : surLaLigne.includes(id)) ? ' data-suivante="1"' : ""}>` +
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
    <div class="c-groupe">
      <div class="c-ligne${CARTE.bilan ? " avec-bilan" : ""}"${rang ? ` data-rang="${rang.id}"` : ""}>
        ${jalon(hDep && hDep.gareId, "boss")}
        ${p.gares.map(g => jalon(g)).join("")}
        ${jalon(hArr && hArr.gareId, "boss")}
        ${bilanHTML(suiteBulle)}
      </div>
      ${CARTE.bilan ? "" : suite}
    </div>`;
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
  // La bulle part SOUS la rangée des petites étoiles, avec 6 px d'air : posée
  // plus haut, elle cachait les étoiles des gares voisines.
  const haut = (et ? et.offsetTop + et.offsetHeight : jalon.offsetHeight) + 6;
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

// Aucune gare tenue : le tout premier écran est LA CARTE DE LA ZONE, et l'on
// y touche son hub de départ (vueConstellation, mode départ). Une liste de
// cartes a été essayée : treize pavés de texte pour dire « choisissez une
// ville », là où la carte le montre. Ici, seul le repli quand rien n'est écrit.
function vueDepart() {
  return `
    <div class="c-tete"><div class="c-titre">Aucune ligne n'est encore écrite</div></div>`;
}
// Le hub choisi est OFFERT, et la ligne qui en part s'affiche aussitôt.
function choisirHubDeDepart(hubId) {
  const d = (typeof hubsDeDepart === "function" ? hubsDeDepart() : []).find(x => x.hub.id === hubId);
  if (!d) return;
  if (typeof buyStation === "function") buyStation(d.hub.gareId);
  CARTE.corridor = d.lignes[0];
  CARTE.depuis = hubId;
  CARTE.panneau = null; CARTE.zone = null;
  CARTE.vue = "ligne";
  renderCarte();
}
// LES SAUVEGARDES D'AVANT : le joueur avait pris une ligne par sa première
// gare, et son hub d'origine ne lui appartenait pas. On le lui offre, en tête
// des acquisitions — là où la règle le lit — la première fois que la carte se
// dessine. Sans effet ensuite.
function reparerDepart() {
  if (typeof getBought !== "function" || typeof corridorDeGare !== "function") return;
  const b = getBought();
  if (!b.length || hubDeGare(b[0])) return;
  const lien = corridorDeGare(b[0]);
  if (!lien || lien.gares[0] !== b[0]) return;        // pas une première gare de ligne
  const h = hubById(lien.a);
  if (!h || !h.gareId || b.includes(h.gareId)) return;
  b.unshift(h.gareId);
  if (typeof persistProgress === "function") persistProgress();
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
  // Au tout premier écran, la zone du premier hub de départ dans l'ordre du
  // catalogue (celui des pays d'index.json) : la première zone du fichier
  // était les Îles britanniques, et le joueur belge cherchait Bruxelles.
  const zoneDeDepart = () => {
    const deps = typeof hubsDeDepart === "function" ? hubsDeDepart() : [];
    const rang = g => { const i = CATALOG.findIndex(c => c.id === g); return i < 0 ? 1e9 : i; };
    deps.sort((x, y) => rang(x.hub.gareId) - rang(y.hub.gareId));
    return deps.length ? deps[0].hub.zone : (zones[0] || {}).id;
  };
  const cid = CARTE.zone || (ancre ? ancre.zone : zoneDeDepart());
  const cst = zoneById(cid) || zones[0];
  const hubs = hubsDeZone(cid);
  if (!hubs.length || !cst) return vueLigne();

  const tenues = carteTenues();
  // MODE DÉPART : rien n'est tenu, la carte sert à choisir son hub. Les hubs
  // de départ sont les seuls « jouables » (garesOuvrables), ils battent ; on
  // en touche un et il est offert (choisirHubDeDepart). Pas de panneau, pas
  // de « Ma ligne » : il n'y en a pas encore.
  const depart = !tenues.size;
  // LE HUB CHOISI : la carte zoome sur lui (renderCarte anime la transition)
  // et ses sorties portent leurs bulles.
  const zoomHub = !depart && CARTE.panneau ? hubById(CARTE.panneau) : null;
  const K = 3.2;
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
    // Zoomé, le point garde à peu près sa taille d'écran (×1,3) : c'est la
    // carte qu'on rapproche, pas les symboles qu'on gonfle.
    const f = zoomHub ? 1.3 / K : 1;
    const r = (h.rang === 1 ? 2.6 : 1.9) * f;
    // Le carrefour ouvert se marque : sans quoi le panneau flotte, et l'on ne
    // sait plus de quel point il parle.
    return `<g class="hub${tenu ? " tenu" : ""}${jouable ? " jouable" : ""}${depart && jouable ? " depart" : ""}${maitrise ? " maitrise" : ""}` +
      `${h.gareId ? "" : " absent"}${CARTE.panneau === h.id ? " choisi" : ""}"` +
      ` data-hub="${h.id}"${h.gareId ? ` data-gare="${h.gareId}"` : ""}>` +
      `<circle class="cerne" cx="${X(h.ll[0])}" cy="${Y(h.ll[1])}" r="${(r + 2.2 * f).toFixed(2)}"/>` +
      `<circle cx="${X(h.ll[0])}" cy="${Y(h.ll[1])}" r="${r}"/>` +
      `<text x="${X(h.ll[0])}" y="${Y(h.ll[1]) - 4}">${h.nom}</text></g>`;
  }).join("");

  const tete = depart
    ? `<button class="c-zoom" data-vue="europe">${nomDeCarte()} ›</button>
      <div class="c-titre">Choisissez votre gare de départ</div>
      <span class="c-zone" style="color:${cst.couleur}">${cst.nom}</span>`
    : `<button class="c-zoom" data-vue="europe">${nomDeCarte()} ›</button>
      <div class="c-titre" style="color:${cst.couleur}">${cst.nom}</div>
      <button class="c-retour" data-vue="ligne">‹ Ma ligne</button>`;
  CARTE.zoomCible = zoomHub ? { x: X(zoomHub.ll[0]), y: Y(zoomHub.ll[1]), k: K } : null;
  const bulles = zoomHub ? bullesDeHub(zoomHub, X, Y, K, tenues) : "";
  return `
    <div class="c-tete">${tete}</div>
    <svg class="c-graphe${depart ? " depart" : ""}${zoomHub ? " zoom" : ""}" style="--k:${zoomHub ? K : 1}" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet">
      <g class="monde"><g class="traits">${traits}</g>${points}${bulles}</g>
    </svg>`;
}

// ------------------------------------------------------------------
// LE CARREFOUR, VU DE PRÈS. Toucher un hub ZOOME la carte sur lui, et chaque
// sortie porte sa bulle : la destination, les étoiles gagnées sur la ligne
// (x / y), les diamants, la part du chemin faite. On choisit sa ligne en
// touchant sa bulle ou son trait. Un panneau en liste a précédé ceci : il
// cachait la carte qu'il commentait.
// ------------------------------------------------------------------
function bullesDeHub(hub, X, Y, K, tenues) {
  const hx = X(hub.ll[0]), hy = Y(hub.ll[1]);
  // ------------------------------------------------------------------
  // CHAQUE BULLE SE POSE SUR SON PROPRE TRAIT.
  // ------------------------------------------------------------------
  // Elles se sont d'abord réparties en ronde autour du hub, à distance fixe,
  // en se repoussant à l'angle. Deux sorties séparées de quelques degrés se
  // chassaient alors l'une l'autre tout autour du cadran, et la bulle finissait
  // le long d'un trait qui n'était pas le sien : « Luxembourg » se lisait au
  // bout de la ligne de Paris. Une étiquette qui désigne la mauvaise ligne est
  // pire qu'une étiquette absente.
  //
  // Une bulle ne quitte donc plus son trait. Quand deux se gênent, elles
  // GLISSENT LE LONG DE LEUR LIGNE, en s'éloignant du hub — et le trait, qui
  // passe derrière elle et ressort de l'autre côté, dit sans un mot de quelle
  // ligne elle parle. Le décalage perpendiculaire (une demi-hauteur, la ligne
  // vient alors lécher son bord) reste pour les cas serrés : deux lignes
  // presque parallèles ne se séparent pas en s'allongeant.
  //
  // Tout se calcule en UNITÉS ÉCRAN — le monde est agrandi ×K, la bulle rendue
  // à 1/K : un déplacement de 30 unités écran vaut 30/K dans le monde. La
  // fenêtre visible fait 100 unités, le hub en son centre.
  //
  // La bulle ne porte PAS le nom de la ville : il est déjà sur la carte, au
  // bout du trait. Elle ne dit que ce que la carte ne montre pas — étoiles,
  // diamants, avancée — et tient donc sur une ligne et une jauge. Une ligne
  // pas encore écrite n'a que « à écrire » à dire : sa bulle est plus étroite,
  // et c'est autant de place rendue aux autres.
  const DEMI_H = 5.6, ECART = 5.8;          // demi-hauteur (garde comprise) et décalage de bord
  const RAYONS = [29, 33, 37, 41, 45];      // les crans de glissement, du plus proche au plus loin
  const COTES = [0, 1, -1];                 // sur le trait, puis d'un bord, puis de l'autre
  const BORD = 48;                          // le carré toujours visible, hub au centre
  const sorties = sortiesDeHub(hub.id).map(lien => {
    const vers = lien.a === hub.id ? lien.b : lien.a;
    const hv = hubById(vers);
    if (!hv) return null;
    const ecrite = !!(lien.gares && lien.gares.length);
    return { lien, hv, ecrite, demiL: ecrite ? 13.4 : 9.4,
      ligne: Math.atan2(Y(hv.ll[1]) - hy, X(hv.ll[0]) - hx) };
  }).filter(Boolean);
  // On pose dans le sens du cadran : l'ordre n'a pas d'importance de fond, il
  // rend seulement le résultat le même d'un rendu à l'autre.
  sorties.sort((u, v) => u.ligne - v.ligne);

  // On pose une première fois dans l'ordre, puis on repasse : une bulle posée
  // tôt a choisi sa place sans connaître celles qui la suivaient, et c'est la
  // dernière servie qui payait tout. Deux relectures suffisent à démêler les
  // carrefours à cinq sorties.
  const place = so => {
    const ux = Math.cos(so.ligne), uy = Math.sin(so.ligne);
    let best = null;
    RAYONS.forEach((rho, i) => COTES.forEach(cote => {
      // Le décalage de bord est perpendiculaire à la ligne, d'exactement une
      // demi-hauteur : le trait vient lécher le bord de la bulle au lieu de la
      // traverser. Elle lui reste attachée, c'est tout ce qui compte.
      const d = cote * ECART;
      const px = ux * rho - uy * d, py = uy * rho + ux * d;
      if (Math.abs(px) + so.demiL > BORD || Math.abs(py) + DEMI_H > BORD) return;
      // Ce qu'il en coûte : s'éloigner coûte un cran, se décaler en coûte deux
      // et demi — mieux vaut une bulle plus loin sur sa ligne qu'à côté.
      let note = i + (cote ? 2.5 : 0);
      for (const autre of sorties) {
        const p = autre.pos;
        if (autre === so || !p) continue;
        note += 100 * Math.max(0, so.demiL + p.demiL - Math.abs(px - p.x)) *
                      Math.max(0, 2 * DEMI_H - Math.abs(py - p.y));
      }
      if (!best || note < best.note) best = { x: px, y: py, demiL: so.demiL, note };
    }));
    // Aucun cran ne tient à l'écran : on revient au premier, sur le trait.
    so.pos = best || { x: ux * RAYONS[0], y: uy * RAYONS[0], demiL: so.demiL };
  };
  for (let tour = 0; tour < 3; tour++) for (const so of sorties) place(so);

  let out = "";
  for (const so of sorties) {
    const { lien, hv, ecrite } = so;
    const px = hx + so.pos.x / K, py = hy + so.pos.y / K;
    let corps;
    if (!ecrite) corps = `<text class="bl-prog" x="0" y="1">à écrire</text>`;
    else {
      const compo = typeof garesDeLigne === "function" ? garesDeLigne(lien, hub.id) : lien.gares;
      const etoiles = compo.reduce((n, g) => n + etoilesDe(g), 0);
      const diamants = compo.filter(g => (getProgress()[g] || {}).bestDelay === 0).length;
      const faits = typeof garesFaites === "function" ? garesFaites(compo) : 0;
      const rang = typeof rangDeLigne === "function" ? rangDeLigne(lien, hub.id) : null;
      corps = `<text class="bl-prog" x="0" y="0.4">★ ${etoiles} / ${compo.length * 3}` +
        `<tspan class="bl-dia" dx="2.2">◆ ${diamants}</tspan></text>` +
        `<rect class="bl-piste" x="-10.4" y="2.3" width="20.8" height=".9" rx=".45"/>` +
        `<rect class="bl-fait${rang ? " r-" + rang.id : ""}" x="-10.4" y="2.3" width="${(20.8 * faits / compo.length).toFixed(2)}" height=".9" rx=".45"/>`;
    }
    out += `<g class="bl${ecrite ? "" : " absente"}" transform="translate(${px.toFixed(2)} ${py.toFixed(2)}) scale(${(1 / K).toFixed(4)})"` +
      `${ecrite ? ` data-lien="${cleDeLien(lien)}"` : ""}>` +
      `<rect class="bl-fond" x="${(-so.demiL + 1).toFixed(1)}" y="-4.1" width="${(2 * so.demiL - 2).toFixed(1)}" height="8.2" rx="2.4"/>${corps}</g>`;
  }
  // Pas de bouton « Jouer » pour le hub : il se joue depuis chacune de ses
  // lignes, où il est un jalon comme les autres.
  return out;
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
// `prefere` : le hub d'où le joueur ouvre la ligne (le panneau de carrefour
// déplié). C'est de là qu'il part, donc c'est de là qu'elle se lit.
function ouvrirLigne(cle, prefere) {
  const lien = lienDeCle(cle);
  if (!lien || !lien.gares || !lien.gares.length) return;
  CARTE.corridor = lien;
  CARTE.depuis = sensDeLecture(lien, prefere);
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
      ${tenues.size ? `<button class="c-retour" data-vue="ligne">‹ Ma ligne</button>` : ""}
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
  reparerDepart();
  // Rien de tenu : on commence sur la carte de la zone, pas sur une ligne.
  if (CARTE.vue === "ligne" && !carteTenues().size && zonesDeCarte().length) CARTE.vue = "constellation";
  hote.className = "carte v-" + CARTE.vue;
  hote.innerHTML = CARTE.vue === "constellation" ? vueConstellation()
                 : CARTE.vue === "europe" ? vueEurope() : vueLigne();
  // Le relevé de fin anime le solde : il lui faut l'élément, refait à chaque rendu.
  CARTE.etoiles = hote.querySelector(".c-etoiles");
  // LE ZOOM SE JOUE, il ne se pose pas. Le SVG est refait à chaque rendu :
  // pour que la transition existe, le monde repart de sa transformation
  // d'avant, puis reçoit la nouvelle — c'est le CSS qui fait le trajet.
  const monde = hote.querySelector(".monde");
  if (monde) {
    const z = CARTE.vue === "constellation" ? CARTE.zoomCible : null;
    const cible = z ? `translate(${(50 - z.k * z.x).toFixed(2)}px, ${(50 - z.k * z.y).toFixed(2)}px) scale(${z.k})`
                    : "translate(0px, 0px) scale(1)";
    if (CARTE.zoomAvant && CARTE.zoomAvant !== cible) {
      monde.style.transform = CARTE.zoomAvant;
      monde.getBoundingClientRect();               // le point de départ est posé
    }
    monde.style.transform = cible;
    CARTE.zoomAvant = cible;
  } else CARTE.zoomAvant = null;
  poserBilan();    // avant le voyage : lui lit CARTE.voyage, et le consomme
  animerVoyage();

  // Un seul écouteur, posé sur l'hôte : le contenu se refait à chaque rendu,
  // et des écouteurs par élément fuiraient à chaque changement de vue.
  hote.onclick = ev => {
    const vue = ev.target.closest("[data-vue]");
    if (vue) {
      CARTE.vue = vue.dataset.vue; CARTE.corridor = null; CARTE.panneau = null; CARTE.zone = null;
      renderCarte(); return;
    }
    // Une zone touchée depuis la vue Europe : c'est ELLE qu'on montre — la
    // vue zone s'ancrait sur la ligne en cours quel que soit le bouton pressé.
    const cst = ev.target.closest("[data-const]");
    if (cst) { CARTE.vue = "constellation"; CARTE.zone = cst.dataset.const; CARTE.panneau = null; renderCarte(); return; }
    if (ev.target.closest("[data-fermer]")) { CARTE.panneau = null; renderCarte(); return; }
    // UNE LIGNE SE PREND EN LA TOUCHANT. Le trait du plan et la ligne du
    // panneau portent la même marque et font la même chose : ouvrir la vue
    // ligne. C'est le seul geste qui descende d'une échelle.
    const lien = ev.target.closest("[data-lien]");
    if (lien) { ouvrirLigne(lien.dataset.lien, CARTE.panneau); return; }
    // LE CARREFOUR POSE SA QUESTION AVANT DE LANCER SA GARE. Le point porte
    // aussi `data-gare` — on le teste donc en premier, sans quoi le clic
    // partirait en jeu et le choix de direction n'aurait jamais lieu.
    const hub = ev.target.closest("[data-hub]");
    // MODE DÉPART : toucher un hub de départ, c'est le choisir — il est offert.
    // Les autres hubs n'ont rien à dire encore.
    if (hub && !carteTenues().size) {
      if (hub.classList.contains("depart")) choisirHubDeDepart(hub.dataset.hub);
      return;
    }
    if (hub) {
      CARTE.panneau = CARTE.panneau === hub.dataset.hub ? null : hub.dataset.hub;
      renderCarte(); return;
    }
    const g = ev.target.closest("[data-gare]");
    if (g && g.dataset.gare) { jouerOuOuvrir(g.dataset.gare); return; }
    // « Choisir la direction » : la zone, le panneau du hub déplié. Le résultat
    // a été lu — on le range, sinon il reviendrait sous ce hub sur chacune des
    // lignes qu'on ouvrira depuis lui.
    const cf = ev.target.closest("[data-carrefour]");
    if (cf) { CARTE.bilan = null; CARTE.vue = "constellation"; CARTE.panneau = cf.dataset.carrefour; renderCarte(); return; }
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
