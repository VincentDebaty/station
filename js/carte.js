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

const CARTE = { hote: null, vue: "ligne", corridor: null, depuis: null };

// ------------------------------------------------------------------
// OÙ EN EST LE JOUEUR ?
// ------------------------------------------------------------------
// Les gares tenues, au format qu'attend le graphe.
function carteTenues() {
  const t = new Set();
  for (const c of CATALOG) if (isBought(c.id)) t.add(c.id);
  return t;
}
// Le corridor à montrer, et depuis quel bout le lire. On préfère celui de la
// dernière gare jouée : c'est là que le joueur a laissé son attention.
function corridorCourant() {
  const tenues = carteTenues();
  const candidates = [];
  if (typeof lastPlayedId === "string" && lastPlayedId) candidates.push(lastPlayedId);
  for (const c of CATALOG) if (isBought(c.id)) candidates.push(c.id);

  for (const gareId of candidates) {
    const lien = corridorDeGare(gareId);
    if (lien) {
      // On le lit depuis le bout déjà tenu, pour que la progression aille
      // de la gauche vers la droite.
      const hA = hubById(lien.a), hB = hubById(lien.b);
      const depuis = (hA && hA.gareId && tenues.has(hA.gareId)) ? lien.a
                   : (hB && hB.gareId && tenues.has(hB.gareId)) ? lien.b : lien.a;
      return { lien, depuis };
    }
    const hub = hubDeGare(gareId);
    if (hub) {
      // Sur un boss : on montre la sortie la plus avancée, à défaut la première.
      const sorties = sortiesDeHub(hub.id).filter(l => l.gares && l.gares.length);
      if (!sorties.length) continue;
      let best = sorties[0], bestN = -1;
      for (const l of sorties) {
        const p = parcours(l, hub.id);
        const n = p.gares.filter(g => tenues.has(g)).length;
        if (n > bestN) { bestN = n; best = l; }
      }
      return { lien: best, depuis: hub.id };
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

  // Le nom de la ligne : ses deux bouts. Les vrais noms — « le sillon
  // Sambre-et-Meuse » — s'écriront dans data/graph.js, ils ne se déduisent pas.
  const titre = `${hDep ? hDep.nom : "?"} – ${hArr ? hArr.nom : "?"}`;
  const total = p.gares.length + (hArr && hArr.gareId ? 1 : 0);
  const faits = p.gares.filter(g => tenues.has(g)).length +
                (hArr && hArr.gareId && tenues.has(hArr.gareId) ? 1 : 0);

  const jalon = (id, role) => {
    const etat = id ? etatDeGare(id) : "fermee";
    const cl = ["jalon", "j-" + etat, role ? "j-" + role : ""].filter(Boolean).join(" ");
    const st = id ? etoilesDe(id) : 0;
    return `<button class="${cl}" data-gare="${id || ""}" ${id ? "" : "disabled"}` +
      `${id && surLaLigne.includes(id) ? ' data-suivante="1"' : ""}>` +
      `<span class="pastille"></span>` +
      `<span class="nom">${id ? nomDe(id) : "?"}</span>` +
      `<span class="etoiles">${st ? "★".repeat(st) : ""}</span>` +
      `</button>`;
  };

  return `
    <div class="c-tete">
      <button class="c-zoom" data-vue="constellation">${hDep && CONSTELLATIONS.find(c => c.id === hDep.c) ? CONSTELLATIONS.find(c => c.id === hDep.c).nom : "Le réseau"} ›</button>
      <div class="c-titre">${titre}<span class="c-avance">${faits} / ${total}</span></div>
      ${bourseHTML()}
    </div>
    <div class="c-ligne">
      ${jalon(hDep && hDep.gareId, "boss")}
      ${p.gares.map(g => jalon(g)).join("")}
      ${jalon(hArr && hArr.gareId, "boss")}
    </div>
    ${prochaine ? `<button class="c-suite" data-gare="${prochaine}">▸ ${
      isBought(prochaine) ? "Reprendre" : "Ouvrir"} ${nomDe(prochaine)}</button>` : ""}`;
}

// Aucune gare tenue : le tout premier écran. On propose les portes de départ,
// et rien d'autre — le choix du pays se fait en choisissant sa ligne.
function vueDepart() {
  const portes = CATALOG.filter(c => isBuyable(c.id)).slice(0, 8);
  return `
    <div class="c-tete"><div class="c-titre">Choisissez votre première gare</div></div>
    <div class="c-portes">
      ${portes.map(c => `<button class="porte" data-gare="${c.id}">
        <span class="nom">${c.city || c.name}</span>
        <span class="pays">${(c.country || "").trim().split(" ")[0]}</span>
      </button>`).join("")}
    </div>`;
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
  const cid = ancre ? ancre.c : (CONSTELLATIONS[0] || {}).id;
  const cst = CONSTELLATIONS.find(c => c.id === cid) || CONSTELLATIONS[0];
  const hubs = HUBS.filter(h => h.c === cid);
  if (!hubs.length) return vueLigne();

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
  for (const [a, b, t] of LIENS) {
    if (!dedans.has(a) && !dedans.has(b)) continue;
    const ha = hubById(a), hb = hubById(b);
    if (!ha || !hb) continue;
    const sortant = !dedans.has(a) || !dedans.has(b);
    const ouvert = (ha.gareId && tenues.has(ha.gareId)) || (hb.gareId && tenues.has(hb.gareId));
    traits += `<line x1="${X(ha.ll[0])}" y1="${Y(ha.ll[1])}" x2="${X(hb.ll[0])}" y2="${Y(hb.ll[1])}"` +
      ` class="trait${ouvert ? " ouvert" : ""}${sortant ? " sortant" : ""}${t === "mer" ? " mer" : ""}"/>`;
  }
  const points = hubs.map(h => {
    const tenu = h.gareId && tenues.has(h.gareId);
    const jouable = h.gareId && isBuyable(h.gareId);
    const maitrise = tenu && bossMaitrise(h.id, tenues);
    return `<g class="hub${tenu ? " tenu" : ""}${jouable ? " jouable" : ""}${maitrise ? " maitrise" : ""}` +
      `${h.gareId ? "" : " absent"}" data-hub="${h.id}"${h.gareId ? ` data-gare="${h.gareId}"` : ""}>` +
      `<circle cx="${X(h.ll[0])}" cy="${Y(h.ll[1])}" r="${h.rang === 1 ? 2.6 : 1.9}"/>` +
      `<text x="${X(h.ll[0])}" y="${Y(h.ll[1]) - 4}">${h.nom}</text></g>`;
  }).join("");

  return `
    <div class="c-tete">
      <button class="c-zoom" data-vue="europe">L'Europe ›</button>
      <div class="c-titre" style="color:${cst.couleur}">${cst.nom}</div>
      <button class="c-retour" data-vue="ligne">‹ Ma ligne</button>
    </div>
    <svg class="c-graphe" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet">
      <g class="traits">${traits}</g>${points}
    </svg>`;
}

// ------------------------------------------------------------------
// LA VUE EUROPE — ce qu'il reste du continent.
// ------------------------------------------------------------------
function vueEurope() {
  const tenues = carteTenues();
  const cartes = CONSTELLATIONS.map(c => {
    const hubs = HUBS.filter(h => h.c === c.id);
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
      <div class="c-titre">L'Europe</div>
      <button class="c-retour" data-vue="ligne">‹ Ma ligne</button>
    </div>
    <div class="c-europe">${cartes}</div>`;
}

// ------------------------------------------------------------------
// RENDU ET GESTES
// ------------------------------------------------------------------
// Le solde, en tête d'écran. Il disparaîtra avec les crédits au lot suivant ;
// d'ici là il reste visible, au même endroit qu'avant.
function bourseHTML() {
  return typeof creditsHTML === "function"
    ? `<div class="c-bourse">${creditsHTML(getCredits())}</div>` : "";
}

function renderCarte() {
  const hote = document.getElementById("hub-map");
  if (!hote) return;
  CARTE.hote = hote;
  hote.className = "carte v-" + CARTE.vue;
  hote.innerHTML = CARTE.vue === "constellation" ? vueConstellation()
                 : CARTE.vue === "europe" ? vueEurope() : vueLigne();
  // Le relevé de fin anime le solde : il lui faut l'élément, refait à chaque rendu.
  CARTE.bourse = hote.querySelector(".c-bourse");

  // Un seul écouteur, posé sur l'hôte : le contenu se refait à chaque rendu,
  // et des écouteurs par élément fuiraient à chaque changement de vue.
  hote.onclick = ev => {
    const vue = ev.target.closest("[data-vue]");
    if (vue) { CARTE.vue = vue.dataset.vue; CARTE.corridor = null; renderCarte(); return; }
    const cst = ev.target.closest("[data-const]");
    if (cst) { CARTE.vue = "constellation"; renderCarte(); return; }
    const g = ev.target.closest("[data-gare]");
    if (!g || !g.dataset.gare) return;
    jouerOuOuvrir(g.dataset.gare);
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
