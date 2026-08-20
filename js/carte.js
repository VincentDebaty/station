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

const CARTE = { hote: null, vue: "ligne", corridor: null, depuis: null,
  // Le voyage : la gare d'où le train doit partir, posée par le relevé de fin
  // de service (js/game.js) et consommée au rendu suivant. Une seule fois.
  voyage: null, prochaine: null };

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
  const faits = composition.filter(g => tenues.has(g)).length;

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
      <div class="c-titre">${titre}${rang
        ? `<span class="c-rang r-${rang.id}">${rang.nom}</span>`
        : `<span class="c-avance">${faits} / ${total}</span>`}</div>
      ${bourseHTML()}
    </div>
    <div class="c-ligne"${rang ? ` data-rang="${rang.id}"` : ""}>
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
    // MÊME LOGIQUE À TOUTES LES ÉCHELLES : le rang colore le trait ici comme
    // il colore le tracé de la vue ligne. C'est ce qui fait qu'on dézoome pour
    // regarder son travail, et pas seulement pour chercher son chemin.
    const lien = GRAPHE.corridors.find(l =>
      (l.a === a && l.b === b) || (l.a === b && l.b === a));
    const rg = lien && typeof rangDeLigne === "function" ? rangDeLigne(lien, lien.a) : null;
    traits += `<line x1="${X(ha.ll[0])}" y1="${Y(ha.ll[1])}" x2="${X(hb.ll[0])}" y2="${Y(hb.ll[1])}"` +
      ` class="trait${ouvert ? " ouvert" : ""}${sortant ? " sortant" : ""}${t === "mer" ? " mer" : ""}` +
      `${rg ? " r-" + rg.id : ""}"/>`;
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
  animerVoyage();

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
  train.style.top = (a.offsetTop + 22) + "px";   // la hauteur du rail (.jalon::before)
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
