"use strict";
// ------------------------------------------------------------------
// Carte du monde zoomable — sélection des gares (remplace le hub linéaire).
//
// UN SEUL SVG en coordonnées géographiques, avec un ZOOM LIBRE : molette,
// pincement et glissement agissent directement sur le viewBox
// (preserveAspectRatio "meet", viewBox toujours ramené au rapport de l'écran →
// échelle = cw / largeur du viewBox). Frontières RÉELLES (WORLDMAP / Natural
// Earth), rendues LISSÉES (Catmull-Rom → Bézier).
//
// Il n'y a PLUS de niveaux « monde / continent / pays ». La carte se comporte
// comme une carte en ligne : une seule vue, un zoom continu, et le détail qui
// vient avec l'échelle (js/mapnet.js). Aucun état de navigation à tenir, donc
// aucun moyen de s'y perdre.
//
// Elle s'ouvre CHEZ L'UTILISATEUR (userCountrySlug, geo.js), à défaut sur
// l'Europe. Cliquer un pays le cadre — un raccourci, pas un changement d'état.
//
//  - SVG : formes des pays (fond), arêtes du réseau (js/mapnet.js), trains déco.
//  - Overlay #map-net : les villes, gérées par js/mapnet.js — il SURVIT aux
//    vols de caméra et n'est jamais reconstruit pendant un geste.
//
// Contrats réutilisés inchangés : startStation, isUnlocked, getProgress, CATALOG,
// GEO/geoProject/countryProgress (geo.js), WORLDMAP (worldmap.js), icon/ICON.
// ------------------------------------------------------------------

const MAP = {
  built: false, svg: null, gLand: null, gDeco: null,
  homeBtn: null, host: null, modal: null,
  raf: null, animating: false, far: null, framed: false,
  homeSlug: null, lastFramed: null,
  byCont: {}, byIso: {}, isoToSlug: {}
};

// Pays/territoires exclus de la carte (non jouables, encombrent la vue) : Islande,
// îles Féroé, Malte, Andorre. — code ADM0_A3.
const MAP_EXCLUDE = new Set(["ISL", "FRO", "MLT", "AND"]);

// ---- Index WORLDMAP + lien jeu ↔ géométrie (ISO A3). ----
function buildIndexes() {
  MAP.byCont = {}; MAP.byIso = {};
  for (const c of WORLDMAP.countries) {
    if (MAP_EXCLUDE.has(c.iso)) continue;
    (MAP.byCont[c.cont] = MAP.byCont[c.cont] || []).push(c);
    MAP.byIso[c.iso] = c;
  }
  MAP.isoToSlug = {};
  for (const slug in GEO.countries) MAP.isoToSlug[GEO.countries[slug].iso] = slug;
}
function slugOfIso(iso) { return MAP.isoToSlug[iso] || null; }
function catalogIndexOf(id) {
  return (typeof CATALOG !== "undefined") ? CATALOG.findIndex(c => c.id === id) : -1;
}

// ---- Géométrie : anneau plat [lon,lat,...] → points projetés. ----
function ringToPts(flat) {
  const pts = [];
  for (let i = 0; i < flat.length; i += 2) {
    const u = geoProject(flat[i], flat[i + 1]);
    pts.push([u.x, u.y]);
  }
  return pts;
}
// Chemin fermé LISSÉ (Catmull-Rom → cubiques) : adoucit l'angulosité du 110m.
function smoothClosedPath(pts) {
  const n = pts.length;
  if (n < 3) return "M" + pts.map(p => p[0].toFixed(1) + "," + p[1].toFixed(1)).join("L") + "Z";
  let d = "M" + pts[0][0].toFixed(1) + "," + pts[0][1].toFixed(1);
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    const c1x = p1[0] + (p2[0] - p0[0]) / 6, c1y = p1[1] + (p2[1] - p0[1]) / 6;
    const c2x = p2[0] - (p3[0] - p1[0]) / 6, c2y = p2[1] - (p3[1] - p1[1]) / 6;
    d += "C" + c1x.toFixed(1) + "," + c1y.toFixed(1) + " " +
         c2x.toFixed(1) + "," + c2y.toFixed(1) + " " +
         p2[0].toFixed(1) + "," + p2[1].toFixed(1);
  }
  return d + "Z";
}
function countryPathD(country) {
  return country.r.map(flat => smoothClosedPath(ringToPts(flat))).join(" ");
}
// bbox géo d'un pays pour cadrer le zoom — en IGNORANT les territoires lointains
// (DOM-TOM, îles éloignées) : on ne garde que l'amas d'anneaux proche du plus
// grand (la métropole). Sinon la France, avec la Guyane, se cadrerait de
// l'Amérique du Sud à l'Europe.
function countryGeoBbox(country) {
  const rings = country.r.map(flat => {
    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (let i = 0; i < flat.length; i += 2) {
      const x = flat[i], y = flat[i + 1];
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
    return { x0, y0, x1, y1, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, span: Math.max(x1 - x0, y1 - y0) };
  });
  const main = rings.reduce((a, b) => (b.span > a.span ? b : a));
  const thr = Math.max(8, main.span * 1.3);   // rayon d'inclusion autour de la métropole
  let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  for (const r of rings) {
    if (Math.hypot(r.cx - main.cx, r.cy - main.cy) > thr) continue; // territoire lointain ignoré
    if (r.x0 < x0) x0 = r.x0; if (r.y0 < y0) y0 = r.y0;
    if (r.x1 > x1) x1 = r.x1; if (r.y1 > y1) y1 = r.y1;
  }
  return [x0, y0, x1, y1];
}
function continentCentroid(contId) {
  const c = GEO.continents.find(x => x.id === contId);
  return [(c.bbox[0] + c.bbox[2]) / 2, (c.bbox[1] + c.bbox[3]) / 2];
}

// ------------------------------------------------------------------
// Construction unique du DOM.
// ------------------------------------------------------------------
function buildMap() {
  buildIndexes();
  const host = document.getElementById("hub-map");
  host.innerHTML = "";
  MAP.host = host;

  const svg = document.createElementNS(SVGNS, "svg");
  svg.setAttribute("id", "worldmap");
  svg.setAttribute("viewBox", GEO.world.viewBox.join(" "));
  svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
  MAP.svg = svg;

  const bg = document.createElementNS(SVGNS, "rect");
  bg.setAttribute("class", "map-bg");
  bg.setAttribute("x", 0); bg.setAttribute("y", 0);
  bg.setAttribute("width", GEO.world.W); bg.setAttribute("height", GEO.world.H);
  // Le fond ne fait rien : sur une carte, cliquer le vide ne dézoome pas.
  svg.appendChild(bg);

  // Formes des pays (une fois, lissées). Style/état pilotés par CSS + classes.
  const gLand = document.createElementNS(SVGNS, "g");
  gLand.setAttribute("class", "lyr-land");
  MAP.gLand = gLand;
  const playablePaths = []; // redessinés en dernier (voir plus bas)
  for (const country of WORLDMAP.countries) {
    if (MAP_EXCLUDE.has(country.iso)) continue; // Islande, Féroé, Malte, Andorre…
    const p = document.createElementNS(SVGNS, "path");
    const slug = slugOfIso(country.iso);
    const playable = !!(slug && countryStationIds(slug).length);
    p.setAttribute("class", "country-land" + (playable ? " playable" : ""));
    p.setAttribute("d", countryPathD(country));
    p.dataset.cont = country.cont;
    p.dataset.iso = country.iso;
    // Cliquer un pays jouable le cadre. C'est un raccourci de caméra : on peut
    // aussi bien y arriver au pincement, et rien n'est mémorisé.
    p.addEventListener("click", ev => {
      ev.stopPropagation();
      if (playable) frameCountry(slug);
    });
    gLand.appendChild(p);
    if (playable) playablePaths.push(p);
  }
  // Les pays jouables sont redessinés en dernier : leur bordure surlignée passe
  // ainsi AU-DESSUS des voisins tracés après eux (sinon le remplissage d'un
  // voisin recouvre la bordure — ex. l'Allemagne, masquée par France/NL/Pologne).
  for (const p of playablePaths) gLand.appendChild(p);
  svg.appendChild(gLand);

  // Courbes + trains décoratifs (niveau monde).
  const gDeco = document.createElementNS(SVGNS, "g");
  gDeco.setAttribute("class", "lyr-deco");
  MAP.gDeco = gDeco;
  buildDecoRoutes(gDeco);
  svg.appendChild(gDeco);

  host.appendChild(svg);

  // Modale « fiche de gare » (ouverte au clic d'une ville). Clic sur le voile = fermer.
  const modal = document.createElement("div");
  modal.id = "map-modal"; modal.className = "hidden";
  modal.addEventListener("click", e => { if (e.target === modal) closeModal(); });
  MAP.modal = modal;
  host.appendChild(modal);

  // Il n'y a plus de « retour » — plus de niveau à remonter. À la place, un
  // bouton qui RECADRE le pays sous la vue et le nomme : c'est le seul repère
  // dont on ait besoin quand on s'est perdu à pincer.
  const home = document.createElement("button");
  home.className = "map-home hidden";
  home.setAttribute("aria-label", "Recadrer ce pays");
  home.addEventListener("click", () => { if (MAP.homeSlug) frameCountry(MAP.homeSlug); });
  MAP.homeBtn = home;
  host.appendChild(home);

  // ------------------------------------------------------------------
  // LA LÉGENDE. Repliée sous un bouton : la carte se lit sans elle, mais rien
  // n'explique une convention à qui ne l'a pas devinée.
  //
  // Elle est bâtie avec LES MÊMES CLASSES que les pastilles de la carte
  // (.city-chip, .pr, l'étiquette de prix, l'étoile du parfait) : une légende
  // dessinée à part finit toujours par décrire un état que le jeu n'a plus.
  // Ici, changer la couleur d'une pastille change la légende du même geste.
  // ------------------------------------------------------------------
  const legend = document.createElement("div");
  legend.className = "map-legend hidden";
  // La vignette reprend la STRUCTURE du DOM de la carte (pastille > cap > prix),
  // pas seulement ses classes : c'est le sélecteur `.city-chip .pr` qui donne à
  // l'étiquette son fond doré. Recopier l'apparence sans la structure, c'est
  // rouvrir la porte à une légende qui diverge.
  const chip = (cls, inner, tag, d) =>
    '<span class="map-chip city-chip chip-inline ' + cls + '" style="--d:' + (d || 19) + 'px">' +
      '<span class="dot">' + (inner || "") + "</span>" +
      (tag ? '<span class="cap">' + tag + "</span>" : "") + "</span>";
  const row = (art, title, txt) =>
    '<li><span class="lg-art">' + art + "</span>" +
      "<span><b>" + title + "</b> " + txt + "</span></li>";
  legend.innerHTML =
    '<div class="lg-head">Lire la carte</div><ul>' +
    row(chip("s2", '<span class="fill"></span>',
             '<span class="pr earn">' + creditsHTML(120, true) + "</span>"),
        "Gare à vous",
        "elle a servi. Le chiffre est ce qu'elle peut <em>encore</em> rapporter.") +
    row(chip("s1 entry", '<span class="fill"></span>'),
        "Un service vous attend",
        "acquise, jamais tournée. Rien ne s'achète tant qu'elle n'a pas tourné.") +
    row(chip("perfect", STAR_SVG),
        "Sans faute",
        "pas une minute de retard. Elle a tout donné.") +
    row(chip("locked buyable ready", "",
             '<span class="pr">' + creditsHTML(50) + "</span>"),
        "À ouvrir",
        "à portée de bourse. L'étiquette est son prix.") +
    row(chip("locked buyable", "",
             '<span class="pr">' + creditsHTML(260) + "</span>"),
        "Pas encore",
        "le prix y est, mais il manque des crédits, un service, ou <b>★★</b> sur la voisine d'où vous partiriez.") +
    row(chip("locked", "", "", 16),
        "Hors de votre réseau",
        "aucune gare acquise ne la touche.") +
    "</ul>";
  const legendBtn = document.createElement("button");
  legendBtn.className = "map-legend-btn";
  legendBtn.setAttribute("aria-label", "Lire la carte");
  legendBtn.innerHTML = icon(ICON.help, 18);
  legendBtn.addEventListener("click", ev => {
    ev.stopPropagation();
    const open = legend.classList.toggle("hidden");
    legendBtn.classList.toggle("open", !open);
  });
  // UN TAP AILLEURS REFERME CE QUI EST OUVERT — la légende comme le relevé de
  // fin de service. Les deux sont des panneaux posés sur la carte : on en sort
  // en touchant la carte, sans chercher le bouton qui va bien.
  //
  // EN CAPTURE, et c'est tout l'enjeu : les formes de pays et les pastilles
  // arrêtent la propagation (elles cadrent, elles ouvrent une fiche), donc un
  // écouteur classique sur l'hôte ne voyait JAMAIS le clic — c'est-à-dire
  // presque partout, puisque la terre couvre la carte. Ranger un panneau est
  // une affaire d'écran, pas de cible : cela se décide avant tout le reste.
  host.addEventListener("click", ev => {
    // Sauf sur les panneaux eux-mêmes : les lire ne les referme pas.
    const t = ev.target;
    if (t.closest && t.closest(".map-legend, .map-legend-btn")) return;
    legend.classList.add("hidden"); legendBtn.classList.remove("open");
    // Recadrer le pays quand on range le relevé — mais pas quand on vient de
    // toucher une gare : déplacer la carte sous le doigt qui ouvre une fiche
    // serait gratuit.
    if (typeof endLeaveMap === "function")
      endLeaveMap(!(t.closest && t.closest(".city-chip")));
  }, true);
  MAP.legend = legend;
  host.appendChild(legend);
  host.appendChild(legendBtn);

  // Le solde, en permanence. C'est le seul chiffre qui compte pour décider où
  // aller : il doit être visible en même temps que les prix, sans un geste.
  const purse = document.createElement("div");
  purse.className = "map-purse";
  MAP.purse = purse;
  host.appendChild(purse);
  updateCreditsBadge();

  bindCamera(host); // molette, pincement, glisser
  window.addEventListener("resize", () => { if (!MAP.animating) mapnetPosition(); });
  document.addEventListener("keydown", e => {
    if (e.key !== "Escape" || document.getElementById("hub").classList.contains("hidden")) return;
    if (MAP.modal && !MAP.modal.classList.contains("hidden")) closeModal(); // modale d'abord
    else if (MAP.homeSlug) frameCountry(MAP.homeSlug);
  });

  MAP.built = true;
}

// Lignes ferroviaires décoratives entre continents + petits trains « comètes »
// (offset-path). La tête est pleine, la traînée s'estompe derrière (dégradé) et
// pointe dans le sens de la marche → lecture « convoi qui roule », pas « tache ».
function buildDecoRoutes(g) {
  const routes = [
    ["europe", "am-nord"], ["europe", "asie"], ["am-nord", "am-sud"],
    ["asie", "sea-oceanie"], ["afrique", "europe"], ["am-nord", "asie"]
  ];
  const palette = ["#2dd4bf", "#f5b23c", "#4ade80", "#60a5fa", "#f2588f", "#a78bfa"];
  const defs = document.createElementNS(SVGNS, "defs");
  g.appendChild(defs);
  routes.forEach((r, i) => {
    const a = continentCentroid(r[0]), b = continentCentroid(r[1]);
    const pa = geoProject(a[0], a[1]), pb = geoProject(b[0], b[1]);
    const mx = (pa.x + pb.x) / 2, my = (pa.y + pb.y) / 2;
    const dx = pb.x - pa.x, dy = pb.y - pa.y, len = Math.hypot(dx, dy) || 1;
    const off = 0.22 * len * (i % 2 ? 1 : -1);
    const cx = mx + (-dy / len) * off, cy = my + (dx / len) * off;
    const d = "M" + pa.x.toFixed(1) + "," + pa.y.toFixed(1) +
              " Q" + cx.toFixed(1) + "," + cy.toFixed(1) +
              " " + pb.x.toFixed(1) + "," + pb.y.toFixed(1);
    const path = document.createElementNS(SVGNS, "path");
    path.setAttribute("class", "deco-route"); path.setAttribute("d", d);
    g.appendChild(path);
    const color = palette[i % palette.length];
    // Dégradé de traînée : transparent en queue (x=0) → plein en tête (x=1). Le
    // rect étant orienté par offset-rotate, la tête (+x) mène toujours.
    const grad = document.createElementNS(SVGNS, "linearGradient");
    grad.setAttribute("id", "deco-grad-" + i); // objectBoundingBox par défaut → suit le rect
    const s0 = document.createElementNS(SVGNS, "stop");
    s0.setAttribute("offset", "0"); s0.setAttribute("stop-color", color); s0.setAttribute("stop-opacity", "0");
    const s1 = document.createElementNS(SVGNS, "stop");
    s1.setAttribute("offset", "1"); s1.setAttribute("stop-color", color); s1.setAttribute("stop-opacity", "1");
    grad.appendChild(s0); grad.appendChild(s1);
    defs.appendChild(grad);
    const train = document.createElementNS(SVGNS, "rect");
    train.setAttribute("class", "deco-train");
    train.setAttribute("width", 30); train.setAttribute("height", 7); train.setAttribute("rx", 3.5);
    train.setAttribute("x", -25); train.setAttribute("y", -3.5); // tête à +5, traînée jusqu'à -25
    train.setAttribute("fill", "url(#deco-grad-" + i + ")");
    train.style.color = color; // currentColor du halo (drop-shadow)
    train.style.offsetPath = 'path("' + d + '")';
    train.style.offsetRotate = "auto";
    train.style.animationDelay = (-i * 2.3) + "s";
    g.appendChild(train);
  });
}

// ------------------------------------------------------------------
// Caméra : viewBox + tween animé.
// ------------------------------------------------------------------
function readVB() {
  return (MAP.svg.getAttribute("viewBox") || GEO.world.viewBox.join(" "))
    .split(/[\s,]+/).map(Number);
}
function setVB(vb) { MAP.svg.setAttribute("viewBox", vb.map(n => n.toFixed(1)).join(" ")); }
function targetVB(bbox, pad) {
  const r = geoBoxToRect(bbox);
  const px = r.w * pad, py = r.h * pad;
  return [r.x - px, r.y - py, r.w + 2 * px, r.h + 2 * py];
}
function cancelTween() { if (MAP.raf) { cancelAnimationFrame(MAP.raf); MAP.raf = null; } }
function tweenTo(t, ms, onDone) {
  cancelTween();
  MAP.animating = true; MAP.host.classList.add("tweening");
  const s = readVB();
  const sCx = s[0] + s[2] / 2, sCy = s[1] + s[3] / 2, sLw = Math.log(s[2]), sLh = Math.log(s[3]);
  const tCx = t[0] + t[2] / 2, tCy = t[1] + t[3] / 2, tLw = Math.log(t[2]), tLh = Math.log(t[3]);
  let start = null;
  function step(ts) {
    if (start === null) start = ts;
    const e = Math.min(1, (ts - start) / ms);
    const k = e < 0.5 ? 4 * e * e * e : 1 - Math.pow(-2 * e + 2, 3) / 2;
    const w = Math.exp(sLw + (tLw - sLw) * k), h = Math.exp(sLh + (tLh - sLh) * k);
    const cx = sCx + (tCx - sCx) * k, cy = sCy + (tCy - sCy) * k;
    setVB([cx - w / 2, cy - h / 2, w, h]);
    mapnetPosition(); // le réseau reste vivant pendant le vol, il ne clignote pas
    if (e < 1) { MAP.raf = requestAnimationFrame(step); }
    else { MAP.raf = null; MAP.animating = false; MAP.host.classList.remove("tweening"); onDone && onDone(); }
  }
  MAP.raf = requestAnimationFrame(step);
}

// Unités SVG internes → pixels écran, selon le viewBox courant.
function uToScreen(ux, uy) {
  const vb = readVB();
  const cw = MAP.svg.clientWidth, ch = MAP.svg.clientHeight;
  const scale = Math.min(cw / vb[2], ch / vb[3]);
  const ox = (cw - vb[2] * scale) / 2, oy = (ch - vb[3] * scale) / 2;
  return { x: ox + (ux - vb[0]) * scale, y: oy + (uy - vb[1]) * scale };
}
// Projection géo → pixels écran (placement de l'overlay), selon le viewBox courant.
function screenPos(lon, lat) {
  const u = geoProject(lon, lat);
  return uToScreen(u.x, u.y);
}

function starStr(n) { return "★".repeat(n) + "☆".repeat(3 - n); }
// Variante « pleines seulement » : sur la carte-pays, on n'affiche pas les
// étoiles vides (2 étoiles → « ★★ », pas « ★★☆ ») — plus lisible.
function starStrFull(n) { return "★".repeat(n); }


// Les formes de pays ne changent plus d'état : plus de continent « focalisé »,
// plus de pays « courant ». Un pays jouable est teinté, les autres restent en
// fond. C'est posé une fois pour toutes à la construction (buildMap).
// L'habillage se réduit à deux boutons, tous deux permanents.
// Pays SOUS LA VUE : la gare jouable la plus proche du centre décide. Sans
// niveaux de navigation, c'est la seule définition qui reste vraie quel que
// soit le geste — et c'est celle que le joueur lit à l'écran.
function countryAtCenter() {
  const vb = readVB();
  const cx = vb[0] + vb[2] / 2, cy = vb[1] + vb[3] / 2;
  const inView = ll => {
    const u = geoProject(ll[0], ll[1]);
    return u.x >= vb[0] && u.x <= vb[0] + vb[2] && u.y >= vb[1] && u.y <= vb[1] + vb[3];
  };
  // Deux critères, dans cet ordre :
  //  1. l'emprise du pays contient le CENTRE de la vue — c'est ce qu'on regarde ;
  //  2. parmi ceux-là, celui qui a le plus de gares dans le cadre.
  // La seule surface ne suffit pas : cadrée sur la Belgique, la vue est plus
  // large qu'elle, et l'emprise de la France — bien plus vaste — la couvrait
  // davantage. Le seul comptage de gares ne suffit pas non plus : la Belgique en
  // a vingt-neuf dans un mouchoir de poche et gagnerait partout.
  let best = null, bestN = -1, bestArea = Infinity, fallback = null, fbArea = 0;
  for (const slug in GEO.countries) {
    const g = GEO.countries[slug];
    const country = MAP.byIso[g.iso];
    if (!country) continue;
    const r = geoBoxToRect(countryGeoBbox(country));
    const iw = Math.min(r.x + r.w, vb[0] + vb[2]) - Math.max(r.x, vb[0]);
    const ih = Math.min(r.y + r.h, vb[1] + vb[3]) - Math.max(r.y, vb[1]);
    const overlap = (iw > 0 && ih > 0) ? iw * ih : 0;
    if (overlap > fbArea) { fbArea = overlap; fallback = slug; }
    if (cx < r.x || cx > r.x + r.w || cy < r.y || cy > r.y + r.h) continue;
    let n = 0;
    for (const id in g.cities) if (inView(g.cities[id])) n++;
    const area = r.w * r.h;
    if (n > bestN || (n === bestN && area < bestArea)) { best = slug; bestN = n; bestArea = area; }
  }
  return best || fallback;
}
// Cadrage que prendrait `frameCountry(slug)` — calculé sans bouger la caméra,
// pour savoir si le bouton a quelque chose à faire.
function countryVB(slug) {
  const g = GEO.countries[slug];
  const country = g && MAP.byIso[g.iso];
  if (!country) return null;
  return fitVB(targetVB(g.frame || countryGeoBbox(country), 0.05));
}
// A-t-on dérivé loin d'un cadrage donné ? Tolérance large : un demi-écran de
// déplacement ou 15 % de zoom ne comptent pas — sinon le bouton clignoterait au
// moindre geste.
function awayFrom(ref) {
  if (!ref) return false;
  const vb = readVB();
  const zoom = vb[2] / ref[2];
  if (zoom > 1.15 || zoom < 0.87) return true;
  const dx = (vb[0] + vb[2] / 2) - (ref[0] + ref[2] / 2);
  const dy = (vb[1] + vb[3] / 2) - (ref[1] + ref[3] / 2);
  return Math.hypot(dx, dy) > ref[2] * 0.5;
}
function updateChrome() {
  // Les routes décoratives entre continents n'ont de sens que de très loin :
  // de près, ce sont des traits gigantesques en travers de la carte.
  const far = viewScale() < 1.3;
  if (far !== MAP.far) { MAP.far = far; MAP.host.classList.toggle("far", far); }
  // Le bouton RECADRE le pays qu'on est en train de regarder, et le nomme. Il
  // n'apparaît que s'il a un effet : déjà bien cadré, il ne ferait rien, et un
  // bouton sans effet passe pour cassé.
  if (MAP.homeBtn) {
    const slug = countryAtCenter();
    const ref = slug ? countryVB(slug) : null;
    const away = !!ref && awayFrom(ref);
    MAP.homeBtn.classList.toggle("hidden", !away);
    MAP.homeSlug = slug;
    const nm = away ? (GEO.countries[slug] || {}).name || "" : "";
    if (away && MAP.homeBtn.dataset.nm !== nm) {
      MAP.homeBtn.dataset.nm = nm;
      MAP.homeBtn.innerHTML =
        // Réticule de recentrage (Material « my_location »), le repère que les
        // cartes en ligne emploient pour « remets-moi au bon cadrage ». Une
        // maison disait « accueil », ce que ce bouton ne fait plus.
        '<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true">' +
        '<path d="M12 8c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4zm8.94 3c-.46-4.17-3.77-7.48-7.94-7.94V1h-2v2.06C6.83 3.52 3.52 6.83 3.06 11H1v2h2.06c.46 4.17 3.77 7.48 7.94 7.94V23h2v-2.06c4.17-.46 7.48-3.77 7.94-7.94H23v-2h-2.06zM12 19c-3.87 0-7-3.13-7-7s3.13-7 7-7 7 3.13 7 7-3.13 7-7 7z"/></svg>' +
        '<span class="lbl">' + nm + "</span>";
    }
  }
}

// ------------------------------------------------------------------
// Caméra : zoom LIBRE (molette, pincement) et déplacement (glisser).
// ------------------------------------------------------------------
// Le viewBox est toujours ramené au RAPPORT DE L'ÉCRAN. Avec
// preserveAspectRatio="meet", un viewBox d'un autre rapport se retrouve
// centré avec des bandes, et l'échelle réelle cesse d'être cw/vb[2] — tout le
// calcul de LOD et de position s'en trouverait faussé. En le forçant, on a
// exactement `échelle = cw / largeur du viewBox`.
function fitVB(vb) {
  const cw = MAP.svg.clientWidth || 1, ch = MAP.svg.clientHeight || 1;
  const cx = vb[0] + vb[2] / 2, cy = vb[1] + vb[3] / 2;
  let w = vb[2], h = vb[3];
  if (w / h > cw / ch) h = w * ch / cw; else w = h * cw / ch;
  return [cx - w / 2, cy - h / 2, w, h];
}
// Échelle courante, en pixels par unité de projection (2000 unités = tour du monde).
function viewScale() {
  const vb = readVB();
  return (MAP.svg.clientWidth || 1) / vb[2];
}
// Bornes de zoom. En bas : le monde entier. En haut : de quoi lire une desserte
// de banlieue sans que la carte devienne un plan de rue.
const CAM = { minW: 14, dragging: false, moved: false, pts: new Map(), pinch: null };

// Applique un cadrage : borne, pose, replace le réseau. Aucun état de
// navigation n'est tenu — le cadrage EST l'état.
function applyView(vb) {
  const world = GEO.world;
  let [x, y, w, h] = fitVB(vb);
  const maxW = world.viewBox[2];
  if (w > maxW) { const k = maxW / w; w *= k; h *= k; }
  if (w < CAM.minW) { const k = CAM.minW / w; w *= k; h *= k; }
  // Le centre reste dans le monde : on ne dérive pas dans le vide.
  const cx = Math.max(0, Math.min(world.W, x + w / 2));
  const cy = Math.max(world.viewBox[1], Math.min(world.viewBox[1] + world.viewBox[3], y + h / 2));
  setVB([cx - w / 2, cy - h / 2, w, h]);
  updateChrome();
  mapnetPosition();
}
// Zoom autour d'un point de l'écran : ce point garde sa position géographique
// sous le doigt (c'est ce qui rend un pincement crédible).
function camZoomAt(px, py, factor) {
  const vb = readVB();
  const s = (MAP.svg.clientWidth || 1) / vb[2];
  const ux = vb[0] + px / s, uy = vb[1] + py / s;
  const w = vb[2] / factor, h = vb[3] / factor;
  const s2 = (MAP.svg.clientWidth || 1) / w;
  applyView([ux - px / s2, uy - py / s2, w, h]);
}
function camPan(dxPx, dyPx) {
  const vb = readVB();
  const s = (MAP.svg.clientWidth || 1) / vb[2];
  applyView([vb[0] - dxPx / s, vb[1] - dyPx / s, vb[2], vb[3]]);
}
function bindCamera(host) {
  host.addEventListener("wheel", ev => {
    ev.preventDefault();
    if (MAP.animating) cancelTween();
    const r = host.getBoundingClientRect();
    // Molette crantée ou pavé tactile : on borne le pas pour que le zoom reste
    // continu au lieu de sauter d'un continent à l'autre d'un coup.
    const step = Math.max(-120, Math.min(120, ev.deltaY));
    camZoomAt(ev.clientX - r.left, ev.clientY - r.top, Math.exp(-step * 0.0022));
  }, { passive: false });

  host.addEventListener("pointerdown", ev => {
    if (ev.pointerType === "mouse" && ev.button !== 0) return;
    // PAS de setPointerCapture ici : capturer dès l'appui redirige le `click`
    // vers le fond de carte, et toucher une gare n'ouvrirait plus sa fiche. On
    // ne capture qu'une fois le doigt VRAIMENT parti (voir onMove).
    CAM.pts.set(ev.pointerId, { x: ev.clientX, y: ev.clientY });
    if (CAM.pts.size === 1) { CAM.dragging = true; CAM.moved = false; if (MAP.animating) cancelTween(); }
    if (CAM.pts.size === 2) {
      const [a, b] = [...CAM.pts.values()];
      CAM.pinch = Math.hypot(a.x - b.x, a.y - b.y) || 1;
    }
  });
  const onMove = ev => {
    const prev = CAM.pts.get(ev.pointerId);
    if (!prev) return;
    const cur = { x: ev.clientX, y: ev.clientY };
    CAM.pts.set(ev.pointerId, cur);
    if (CAM.pts.size >= 2) {
      const [a, b] = [...CAM.pts.values()];
      const d = Math.hypot(a.x - b.x, a.y - b.y) || 1;
      const r = host.getBoundingClientRect();
      camZoomAt((a.x + b.x) / 2 - r.left, (a.y + b.y) / 2 - r.top, d / (CAM.pinch || d));
      CAM.pinch = d;
      if (!CAM.moved) { CAM.moved = true; try { host.setPointerCapture(ev.pointerId); } catch (e) { /* ignoré */ } }
      return;
    }
    if (!CAM.dragging) return;
    const dx = cur.x - prev.x, dy = cur.y - prev.y;
    if (!CAM.moved && Math.abs(dx) + Math.abs(dy) > 3) {
      CAM.moved = true;
      // Au-delà du seuil c'est un déplacement, plus un tap : on capture pour
      // que le glissement survive à la sortie du curseur hors de la carte.
      try { host.setPointerCapture(ev.pointerId); } catch (e) { /* pointeur déjà perdu */ }
    }
    if (CAM.moved) camPan(dx, dy);
  };
  host.addEventListener("pointermove", onMove);
  const onUp = ev => {
    CAM.pts.delete(ev.pointerId);
    if (CAM.pts.size < 2) CAM.pinch = null;
    if (CAM.pts.size === 0) CAM.dragging = false;
  };
  host.addEventListener("pointerup", onUp);
  host.addEventListener("pointercancel", onUp);
  // Un glisser ne doit pas déclencher le clic qui suit (dézoom sur le fond,
  // ouverture d'une fiche) : on l'avale en phase de capture.
  host.addEventListener("click", ev => {
    if (CAM.moved) { ev.stopPropagation(); ev.preventDefault(); CAM.moved = false; }
  }, true);
}

// ------------------------------------------------------------------
// Cadrages : de simples mouvements de caméra, sans état de navigation.

// Cadrage d'OUVERTURE seulement : chez l'utilisateur (fuseau horaire, puis
// langue — voir userCountrySlug dans geo.js), à défaut l'Europe. Ensuite c'est
// le pays sous la vue qui fait référence, pas celui-ci.
function frameHome(instant) {
  const slug = (typeof userCountrySlug === "function") ? userCountrySlug() : null;
  if (slug && frameCountry(slug, instant)) return;
  const europe = GEO.continents.find(c => c.id === "europe");
  goTo(targetVB(europe.bbox, 0.06), instant);
}

// ------------------------------------------------------------------
// Renvoie le cadrage RÉELLEMENT visé (ajusté au rapport de l'écran). Le lire
// après coup avec readVB() donnerait le cadrage de DÉPART tant que le vol n'est
// pas terminé — c'est ainsi que le bouton « maison » a mémorisé la mauvaise
// référence et a cessé d'apparaître.
function goTo(vb, instant) {
  const fitted = fitVB(vb);
  if (instant) { setVB(fitted); updateChrome(); mapnetPosition(); }
  else { tweenTo(fitted, 560, updateChrome); }
  return fitted;
}
function frameCountry(slug, instant) {
  const g = GEO.countries[slug];
  const country = g && MAP.byIso[g.iso];
  if (!country) return false;
  // Emprise auto de la métropole, SAUF si le pays fournit un `frame` géo
  // explicite [lonMin,latMin,lonMax,latMax] — utile quand les gares n'occupent
  // qu'une partie du territoire (Royaume-Uni : rien au nord de l'Écosse centrale).
  MAP.lastFramed = goTo(targetVB(g.frame || countryGeoBbox(country), 0.05), instant);
  return true;
}

// Cadre un pays dans la partie LIBRE de l'écran, quand une interface en occupe
// un bord (le relevé de fin de service, posé sur le côté). Sans cela, le
// cadrage centre le pays sur tout l'écran et la moitié du réseau se retrouve
// sous le panneau — c'est-à-dire sous ce qu'on demande au joueur de regarder.
// `reserved` = { left, bottom } en pixels.
function frameCountryBeside(slug, reserved) {
  const g = GEO.countries[slug];
  const country = g && MAP.byIso[g.iso];
  if (!country) return;
  frameBoxBeside(g.frame || countryGeoBbox(country), reserved, 0.05);
}
// Position géographique d'une gare, quel que soit son pays.
function stationLonLat(id) {
  for (const slug in GEO.countries) {
    const c = GEO.countries[slug];
    if (c.cities && c.cities[id]) return c.cities[id];
  }
  return null;
}
// Emprise géo [lonMin, latMin, lonMax, latMax] qui contient toutes ces gares,
// avec une taille MINIMALE : à deux gares voisines, une emprise nue ferait un
// zoom de rue, et la carte n'apprendrait plus rien sur l'endroit.
const MIN_SPAN_LON = 1.6, MIN_SPAN_LAT = 1.0;
function stationsBbox(ids) {
  const pts = ids.map(stationLonLat).filter(Boolean);
  if (!pts.length) return null;
  let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  for (const [lon, lat] of pts) {
    if (lon < x0) x0 = lon; if (lon > x1) x1 = lon;
    if (lat < y0) y0 = lat; if (lat > y1) y1 = lat;
  }
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  const w = Math.max(x1 - x0, MIN_SPAN_LON), h = Math.max(y1 - y0, MIN_SPAN_LAT);
  return [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2];
}
// Cadre une EMPRISE dans la partie LIBRE de l'écran, quand une interface en
// occupe un bord.
function frameBoxBeside(bbox, reserved, pad) {
  if (!bbox) return;
  const cw = MAP.svg.clientWidth || 1, ch = MAP.svg.clientHeight || 1;
  const left = Math.max(0, (reserved && reserved.left) || 0);
  const bottom = Math.max(0, (reserved && reserved.bottom) || 0);
  const freeW = Math.max(80, cw - left), freeH = Math.max(80, ch - bottom);
  // On CALCULE l'échelle qui fait tenir le pays dans la bande libre, puis on
  // recentre la vue sur le milieu de cette bande.
  //
  // Un facteur d'agrandissement appliqué au cadrage plein écran ne marche
  // QUE si la bande est étroite en largeur. Réservez les deux tiers de la
  // HAUTEUR — le relevé en bas d'un téléphone — et le même facteur s'applique
  // aussi à la largeur : la Belgique se retrouvait dézoomée de Leicester à
  // Hanovre pour tenir dans un bandeau de 240 px.
  const box = targetVB(bbox, pad == null ? 0.18 : pad);            // [x, y, w, h] en unités
  const s = Math.min(freeW / box[2], freeH / box[3]);             // px par unité
  const bcx = box[0] + box[2] / 2, bcy = box[1] + box[3] / 2;
  applyView([bcx - (left + freeW / 2) / s, bcy - (freeH / 2) / s, cw / s, ch / s]);
}

// ------------------------------------------------------------------
// Fiche de gare (modale) — ouverte au clic d'une ville.
// ------------------------------------------------------------------
// Gare à proposer quand on clique une gare hors de portée : la moins chère de
// celles qu'on peut acheter — d'abord dans le pays regardé, à défaut n'importe
// où sur le réseau (le joueur peut être en train de lorgner un autre pays).
function recommendedIndex(slug) {
  if (typeof cheapestBuyable !== "function") return -1;
  const c = GEO.countries[slug];
  const country = c ? (CATALOG[catalogIndexOf(Object.keys(c.cities || {})[0])] || {}).country : null;
  const here = country ? cheapestBuyable(country) : -1;
  return here >= 0 ? here : cheapestBuyable(null);
}
// Le solde affiché sur la carte. Redessiné à chaque retour de service et après
// chaque achat ; l'incrément se signale par une pulsation brève, pour que le
// joueur voie sa recette arriver au lieu de la découvrir en la cherchant.
function updateCreditsBadge(bump) {
  if (!MAP.purse || typeof creditsHTML !== "function") return;
  MAP.purse.innerHTML = creditsHTML(getCredits());
  if (bump) {
    MAP.purse.classList.remove("bump");
    void MAP.purse.offsetWidth;
    MAP.purse.classList.add("bump");
  }
}
// Instant jusqu'auquel un tap sur « Prendre le service » est ignoré : voir le
// gestionnaire d'achat, juste en dessous.
let _buyGuardUntil = 0;
function closeModal() {
  if (MAP.modal) MAP.modal.classList.add("hidden");
  // Fiche refermée sans prendre le service : le tutoriel revient à son étape
  // « choisis ta première gare » sur la carte.
  if (typeof maybeStartMapOnboarding === "function") maybeStartMapOnboarding();
}
function openStationModal(gi) {
  if (gi < 0 || typeof CATALOG === "undefined" || !CATALOG[gi] || !MAP.modal) return;
  // Le relevé de fin de service laisse la carte cliquable à côté de lui.
  // Toucher une gare, c'est en avoir fini avec le relevé : il s'efface, sinon
  // il resterait posé en travers de la fiche qu'on vient d'ouvrir.
  if (typeof endLeaveMap === "function") endLeaveMap();
  const card = CATALOG[gi];
  const unlocked = typeof isUnlocked === "function" && isUnlocked(gi);
  const diff = Math.max(1, Math.min(5, card.difficulty || 1));
  const nQuais = (card.platforms || []).length;
  const nDead = (card.platforms || []).filter(p => p.deadEnd).length;
  const nDir = Object.keys(card.portals || {}).length;
  const rec = (typeof getProgress === "function" ? getProgress() : {})[card.id] || {};
  const stars = rec.stars || 0, best = rec.bestDelay;

  // ---- La fiche tient en trois regards : TROIS chiffres, TROIS lignes, UN
  // bouton. Tout le reste a été coupé (gares reliées, dessertes, description,
  // barème, nom de la difficulté) : la carte montre déjà le réseau, et un
  // paragraphe de plus n'aide personne à choisir sa prochaine gare. Ce qui
  // reste tient en un coup d'œil, sans une phrase à lire.
  const gen = card.gen || {};
  const trains = gen.nMin ? (gen.nMax > gen.nMin ? gen.nMin + "–" + gen.nMax : String(gen.nMin)) : null;
  // Cadence moyenne des arrivées, en minutes de jeu : le calcul du générateur
  // lui-même (écart moyen × le resserrement qu'il applique), pris à la source
  // pour que la fiche ne mente jamais si le calibrage bouge.
  const scale = (typeof ARRIVAL_GAP_SCALE === "number") ? ARRIVAL_GAP_SCALE : 1;
  const cadence = gen.gapMin != null ? (gen.gapMin + gen.gapMax) / 2 * scale : null;
  const num = x => x.toFixed(1).replace(".", ",");

  const tile = (v, k) => '<div class="mm-stat"><b>' + v + "</b><span>" + k + "</span></div>";
  const stats =
    tile(nQuais, "quais") +
    tile(nDir, nDir > 1 ? "directions" : "direction") +
    (trains ? tile(trains, "trains") : "");

  // Le flux ne se chiffre pas : cinq barres suffisent à dire « ça arrive vite ».
  // Les seuils sont en minutes de jeu entre deux arrivées — un écart absolu,
  // pas un rang dans le catalogue : ajouter une gare ne déplace pas l'échelle.
  const fluxLevel = cadence == null ? 0 :
    cadence <= 1.65 ? 5 : cadence <= 1.78 ? 4 : cadence <= 1.92 ? 3 : cadence <= 2.05 ? 2 : 1;
  // UNE seule jauge dans la fiche, sur cinq crans : difficulté et flux se lisent
  // du même geste. Seule la couleur les sépare (ambre / teal), pas la forme.
  const bars = n => Array.from({ length: 5 }, (_, i) =>
    '<span class="b' + (i < n ? " on" : "") + '"></span>').join("");

  // Ce que la gare a déjà versé sur ce qu'elle peut verser en tout : une gare
  // acquise garde un objectif visible même toutes étoiles décrochées, et ce
  // qui reste à prendre se lit sans calcul.
  // La jauge se remplit au TARIF (trois étoiles) : c'est là que la gare est
  // faite. Ce qu'un sans-faute ajoute par-dessus se lit ailleurs — sur la carte
  // et sur le bouton « Rejouer », qui disent ce qu'il reste à prendre.
  const cap = typeof stationValue === "function" ? stationValue(card.id) : 0;
  const got = Math.min(cap, typeof stationBanked === "function" ? stationBanked(card.id) : 0);
  // LA PRIME DU SANS-FAUTE : ce que le service parfait ajoute PAR-DESSUS le
  // plein tarif. Une constante, pas un reste — elle vaut la même chose qu'on
  // ait déjà encaissé le quart ou la totalité du tarif, et c'est bien ainsi
  // qu'on l'annonce : « le sans-faute rapporte 320 de plus ». Nulle une fois
  // décroché, puisqu'il n'y a plus rien à en tirer.
  const prime = (unlocked && typeof stationCap === "function" &&
                 stationBanked(card.id) < stationCap(card.id))
    ? stationCap(card.id) - stationValue(card.id) : 0;

  // Trois lignes, aucune phrase : les jauges et les étoiles disent tout — seul
  // le retard garde son chiffre, c'est un record. Et c'est ICI qu'il vit
  // désormais : la carte ne l'affiche plus sous chaque gare (js/mapnet.js), elle
  // n'en garde que la couleur du point. Un record de 0 minute ne s'écrit pas
  // « +0 min » — c'est un service PARFAIT, et il se dit avec l'étoile qu'on
  // retrouve à la place du point sur la carte.
  const rows =
    '<div class="mm-row"><span class="k">Difficulté</span>' +
      '<span class="gauge diff">' + bars(diff) + "</span></div>" +
    (fluxLevel ? '<div class="mm-row"><span class="k">Flux</span>' +
      '<span class="gauge">' + bars(fluxLevel) + "</span></div>" : "") +
    '<div class="mm-row"><span class="k">Record</span>' +
      '<span class="v"><span class="s">' + starStr(stars) + "</span>" +
      // Pas d'étoile de plus ici : les trois du record sont juste à côté, une
      // quatrième se lisait comme un quatrième cran. L'or du mot suffit.
      (best === 0 ? '<span class="d perfect">Parfait</span>'
       : best != null ? '<span class="d">+' + best + " min</span>"
                      : '<span class="d none">jamais jouée</span>') +
      "</span></div>" +
    // LA LIGNE D'ARGENT, présente dans TOUS les cas — et elle ne dit pas la même
    // chose des deux côtés de l'achat :
    //   • gare acquise   → « Encaissé 45 / 120 », ce qu'il reste à aller chercher ;
    //   • gare à acheter → « Rapporte jusqu'à 240 », l'argument d'achat lui-même.
    // C'est l'information qui manquait pour décider : une gare à 100 qui peut en
    // verser 240 ne se juge pas sur son prix seul. Et la fiche garde exactement
    // la même hauteur avant et après l'achat — sans quoi « Prendre le service »
    // remonterait de quarante pixels sous le doigt qui vient d'appuyer.
    (cap ?
      '<div class="mm-row"><span class="k">' + (unlocked ? "Encaissé" : "Rapporte") + "</span>" +
        '<span class="v"><span class="gauge money"><span class="fill" style="width:' +
          Math.round(got / cap * 100) + '%"></span></span>' +
        '<span class="d' + (unlocked && got >= cap ? " full" : "") + '">' +
          (!unlocked ? "jusqu'à " + cap : got >= cap ? "Complet" : got + " / " + cap) +
        "</span></span></div>" : "") +
    // CE QUE L'ÉTOILE RAPPORTE, dit avec l'étoile elle-même. Sans cette ligne,
    // « Complet » se lirait comme « il n'y a plus rien ici », et rien ne dirait
    // D'OÙ viennent les crédits d'un sans-faute. Elle disparaît une fois
    // l'étoile décrochée — il n'y a alors plus rien à en tirer.
    (unlocked && prime > 0 ?
      '<div class="mm-row"><span class="k">Sans faute</span>' +
        // L'étoile de la CARTE, pas un caractère ★ : celui-ci se confondait avec
        // les trois étoiles du record, juste au-dessus. Celle-ci est la marque
        // que porte une gare parfaite sur la carte — le joueur reconnaît la
        // récompense avant de lire la ligne.
        '<span class="v"><span class="map-chip city-chip perfect chip-inline" style="--d:20px">' +
          '<span class="dot">' + (typeof STAR_SVG === "string" ? STAR_SVG : "") + "</span></span>" +
        '<span class="d">' + creditsHTML(prime, true) + "</span></span></div>" : "");

  // Drapeau seul : le pays se reconnaît sans le lire, et la carte le dit déjà.
  const flag = (card.country || "").split(" ")[0];

  // UNE SEULE FICHE, DEUX BOUTONS, TOUJOURS LES MÊMES À LA MÊME PLACE.
  //
  // Acheter puis jouer sont deux temps d'un seul geste. Ils se faisaient dans
  // deux fiches successives d'aspect identique : on cliquait « Ouvrir », la
  // fiche se redessinait, et il fallait cliquer à nouveau sur ce qui semblait
  // le même écran. Les deux actions vivent désormais côte à côte, et l'achat ne
  // fait qu'ALLUMER la seconde.
  //
  // L'ORDRE N'EST PAS COSMÉTIQUE : « Prendre le service » est AU-DESSUS, et
  // l'achat en dessous. Une gare acquise n'a plus de bouton d'achat du tout —
  // il ne dirait rien que la fiche ne dise déjà. Sa disparition raccourcit donc
  // la fiche PAR LE BAS, et le bouton de service ne bouge pas d'un pixel : le
  // doigt qui vient d'acheter ne retombe pas sur « prendre le service » et ne
  // lance pas un service qu'on n'a pas demandé.
  // (Rangés dans l'autre sens, avec un « Acquise » éteint pour tenir la place,
  // il fallait garder à l'écran un bouton mort pour toujours.)
  const price = typeof stationPrice === "function" ? stationPrice(card.id) : 0;
  const buyable = !unlocked && typeof isBuyable === "function" && isBuyable(card.id);
  // Ce qui s'oppose à l'achat, en toutes lettres. Un bouton éteint sans raison
  // se lit comme une panne ; avec sa raison, il devient un objectif.
  const block = buyable && typeof buyBlock === "function" ? buyBlock(card.id) : null;
  const nameOfId = id => { const c = cardOf(id); return c ? (c.city || c.name) : id; };
  let buyBtn = "";
  if (unlocked) buyBtn = "";
  else if (buyable)
    buyBtn = '<button class="btn mm-buy"' +
      (block ? " disabled" : ' data-id="' + card.id + '" data-gi="' + gi + '"') +
      ">Acheter — " + creditsHTML(price) + "</button>" +
      (!block ? "" : '<div class="mm-short">' + (
        block.kind === "service"
          ? "Mettez d'abord <b>" + nameOfId(block.id) + "</b> en service"
        : block.kind === "maitrise"
          ? "Demande <b>★★</b> sur " +
            (block.from.length === 1 ? "<b>" + nameOfId(block.from[0]) + "</b>"
              : block.from.slice(0, 2).map(nameOfId).join(" ou "))
          : "Il vous manque " + creditsHTML(block.short)) + "</div>");
  else
    buyBtn = '<button class="btn mm-buy" disabled>' + icon(ICON.lock, 15) + "Hors de votre réseau</button>";

  const actions =
    '<button class="btn mm-play"' + (unlocked ? ' data-gi="' + gi + '"' : " disabled") +
      ">Prendre le service</button>" + buyBtn;

  // Une seule colonne, courte : le bouton reste au centre, sous les chiffres,
  // à tous les formats — c'est le geste qu'on vient chercher.
  MAP.modal.innerHTML =
    '<div class="mm-card' + (unlocked ? "" : " is-locked") + '">' +
      '<button class="mm-close" aria-label="Fermer">' + icon(ICON.close, 20) + "</button>" +
      '<h2 class="mm-name"><span class="fl">' + flag + "</span>" + card.name + "</h2>" +
      '<div class="mm-stats">' + stats + "</div>" +
      '<div class="mm-rows">' + rows + "</div>" +
      '<div class="mm-actions">' + actions + "</div>" +
    "</div>";
  MAP.modal.querySelector(".mm-close").addEventListener("click", closeModal);
  const play = MAP.modal.querySelector(".mm-play");
  if (play) play.addEventListener("click", () => {
    // Un achat vient de raccourcir la fiche : « Prendre le service » s'est
    // déplacé vers l'endroit que le doigt occupait. On ignore un second tap
    // immédiat, sinon un joueur pressé lance un service qu'il n'a pas demandé.
    if (Date.now() < _buyGuardUntil) return;
    const g = +play.dataset.gi; closeModal(); startStation(g);
  });
  // Achat : la gare bascule sous les yeux du joueur — la fiche se redessine sur
  // « Prendre le service », la pastille devient pleine, le solde retombe.
  const buy = MAP.modal.querySelector(".mm-buy[data-id]");
  if (buy) buy.addEventListener("click", () => {
    if (!buyStationById(buy.dataset.id)) return;
    _buyGuardUntil = Date.now() + 450;
    if (typeof SND === "object" && SND.buy) SND.buy();
    mapnetBuild(); mapnetPosition();
    updateCreditsBadge();
    openStationModal(+buy.dataset.gi);
  });
  MAP.modal.classList.remove("hidden");
  // Le tutoriel SUIT le joueur au lieu de rester sur la carte : sans cela, la
  // bulle « choisis ta première gare » restait affichée par-dessus la fiche —
  // périmée, et posée juste sur le bouton qu'il fallait presser.
  // Le repère du tutoriel suit le geste à faire ICI : jouer si la gare est
  // acquise, l'acheter si elle est à portée.
  if (typeof onboardingStationCard === "function")
    onboardingStationCard(MAP.modal.querySelector(".mm-play, .mm-buy[data-id]"), unlocked);
}

// ------------------------------------------------------------------
// Animation « voyage » vers la gare suivante.
// ------------------------------------------------------------------
// Pays (slug) qui contient une gare du catalogue (index gi).
function stationCountrySlug(gi) {
  const id = (typeof CATALOG !== "undefined" && CATALOG[gi]) ? CATALOG[gi].id : null;
  if (!id) return null;
  for (const slug in GEO.countries) {
    const c = GEO.countries[slug];
    if (c.cities && c.cities[id]) return slug;
  }
  return null;
}
// À l'enchaînement « gare suivante », on montre la carte du pays et un convoi file
// le long de la ligne, de la gare terminée jusqu'à la suivante qui s'illumine,
// puis on lance la partie (onDone). Un clic passe l'animation. Respecte
// prefers-reduced-motion (bascule directe, sans carte).
function mapJourneyToNext(fromGi, toGi, onDone) {
  let done = false;
  const finish = () => { if (!done) { done = true; onDone(); } };
  const slug = stationCountrySlug(toGi);
  const reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!slug || reduce) { finish(); return; }
  if (!MAP.built) buildMap();
  document.getElementById("hub").classList.remove("hidden");
  if (typeof started !== "undefined") started = false;
  mapnetBuild();
  frameCountry(slug, true); // instantané → positions du réseau à jour

  // Positions écran prises sur la couche réseau : c'est elle qui fait foi
  // depuis qu'il n'y a plus qu'une seule voie de rendu pour les villes.
  const at = gi => {
    const id = CATALOG[gi] && CATALOG[gi].id;
    const n = MAPNET.nodes.find(m => m.kind === "station" && m.key === id);
    return n && n.sx != null ? { x: n.sx, y: n.sy } : null;
  };
  const p1 = at(fromGi), p2 = at(toGi);
  const cw = MAP.svg.clientWidth, ch = MAP.svg.clientHeight;
  if (!p1 || !p2 || !cw || !ch) { finish(); return; }

  // Le convoi file le long du segment qui relie les deux gares — le même que
  // celui du réseau quand elles sont voisines.
  const bez = t => ({ x: p1.x + (p2.x - p1.x) * t, y: p1.y + (p2.y - p1.y) * t });
  const dSeg = "M" + p1.x.toFixed(1) + "," + p1.y.toFixed(1) +
               " L" + p2.x.toFixed(1) + "," + p2.y.toFixed(1);

  const mk = (tag, attrs) => {
    const e = document.createElementNS(SVGNS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    return e;
  };
  const svg = mk("svg", { class: "map-journey", width: cw, height: ch, viewBox: "0 0 " + cw + " " + ch });
  const line = mk("path", { class: "mj-line", d: dSeg });
  const ring = mk("circle", { class: "mj-ring", cx: p2.x.toFixed(1), cy: p2.y.toFixed(1), r: 16 });
  const dot = mk("circle", { class: "mj-dot", cx: p1.x.toFixed(1), cy: p1.y.toFixed(1), r: 6 });
  svg.appendChild(line); svg.appendChild(ring); svg.appendChild(dot);
  MAP.host.appendChild(svg);
  const len = line.getTotalLength();
  line.style.strokeDasharray = len; line.style.strokeDashoffset = len;

  let raf = null, t0 = null, endT = null;
  const cleanup = () => { if (raf) cancelAnimationFrame(raf); if (endT) clearTimeout(endT); if (svg.parentNode) svg.remove(); };
  svg.addEventListener("click", () => { cleanup(); finish(); });
  const DUR = 1150;
  function step(ts) {
    if (t0 === null) t0 = ts;
    const e = Math.min(1, (ts - t0) / DUR);
    const k = e < 0.5 ? 2 * e * e : 1 - Math.pow(-2 * e + 2, 2) / 2; // easeInOutQuad
    line.style.strokeDashoffset = len * (1 - k);
    const q = bez(k);
    dot.setAttribute("cx", q.x.toFixed(1)); dot.setAttribute("cy", q.y.toFixed(1));
    if (e < 1) { raf = requestAnimationFrame(step); }
    else { ring.classList.add("pulse"); endT = setTimeout(() => { cleanup(); finish(); }, 480); }
  }
  raf = requestAnimationFrame(step);
}

// ------------------------------------------------------------------
// Point d'entrée appelé par renderHub()/showHub() (hub.js).
// ------------------------------------------------------------------
function renderMap() {
  if (typeof CATALOG !== "undefined") {
    const missing = CATALOG.filter(c => catalogIndexOf(c.id) >= 0 &&
      !Object.values(GEO.countries).some(co => co.cities && co.cities[c.id]));
    if (missing.length) console.assert(false,
      "geo.js : villes manquantes pour " + missing.map(c => c.id).join(", "));
  }
  if (!MAP.built) buildMap();
  MAP.host.classList.remove("end-open"); // plus de relevé posé dessus
  mapnetBuild(); // le réseau dépend de la progression : on le rebâtit à chaque retour
  updateCreditsBadge(true); // on revient d'un service : la recette vient de tomber
  closeModal();
  cancelTween(); MAP.animating = false; MAP.host.classList.remove("tweening");
  // Première ouverture : on cadre la région de l'utilisateur. Retours suivants :
  // on laisse le cadrage tel qu'il était — revenir d'une partie ne doit pas
  // rejeter le joueur à l'autre bout de la carte.
  if (!MAP.framed) { MAP.framed = true; frameHome(true); }
  else { updateChrome(); mapnetPosition(); }
  // Étape 0 du tutoriel : « choisis ta première gare ». Réévaluée à chaque
  // retour sur la carte — elle disparaît dès qu'une gare est décrochée.
  if (typeof maybeStartMapOnboarding === "function") maybeStartMapOnboarding();
}
