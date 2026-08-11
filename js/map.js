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
  homeVB: null, homeName: "", lastFramed: null,
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
  // bouton qui REVIENT CHEZ SOI : le cadrage d'ouverture. Il ne s'affiche QUE
  // lorsqu'on s'en est éloigné : au lancement on y est déjà, et un bouton qui
  // ne fait rien quand on le presse passe pour cassé.
  const home = document.createElement("button");
  home.className = "map-home hidden";
  home.setAttribute("aria-label", "Revenir à ma région");
  home.addEventListener("click", () => frameHome());
  MAP.homeBtn = home;
  host.appendChild(home);

  bindCamera(host); // molette, pincement, glisser
  window.addEventListener("resize", () => { if (!MAP.animating) mapnetPosition(); });
  document.addEventListener("keydown", e => {
    if (e.key !== "Escape" || document.getElementById("hub").classList.contains("hidden")) return;
    if (MAP.modal && !MAP.modal.classList.contains("hidden")) closeModal(); // modale d'abord
    else frameHome();
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
// A-t-on dérivé loin du cadrage d'ouverture ? Tolérance large : un demi-écran de
// déplacement ou 15 % de zoom ne comptent pas — sinon le bouton clignoterait au
// moindre geste.
function awayFromHome() {
  if (!MAP.homeVB) return false;
  const vb = readVB(), h = MAP.homeVB;
  const zoom = vb[2] / h[2];
  if (zoom > 1.15 || zoom < 0.87) return true;
  const dx = (vb[0] + vb[2] / 2) - (h[0] + h[2] / 2);
  const dy = (vb[1] + vb[3] / 2) - (h[1] + h[3] / 2);
  return Math.hypot(dx, dy) > h[2] * 0.5;
}
function updateChrome() {
  // Les routes décoratives entre continents n'ont de sens que de très loin :
  // de près, ce sont des traits gigantesques en travers de la carte.
  const far = viewScale() < 1.3;
  if (far !== MAP.far) { MAP.far = far; MAP.host.classList.toggle("far", far); }
  // Le bouton « maison » n'existe que s'il a un effet, et il annonce où il mène.
  if (MAP.homeBtn) {
    const away = awayFromHome();
    MAP.homeBtn.classList.toggle("hidden", !away);
    if (away && MAP.homeBtn.dataset.nm !== MAP.homeName) {
      MAP.homeBtn.dataset.nm = MAP.homeName;
      MAP.homeBtn.innerHTML =
        '<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true">' +
        '<path d="M12 5.69l5 4.5V18h-2v-6H9v6H7v-7.81l5-4.5M12 3L2 12h3v8h6v-6h2v6h6v-8h3L12 3z"/></svg>' +
        '<span class="lbl">' + MAP.homeName + "</span>";
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
// un bord (la fiche de fin de service pendant un choix). Sans cela, le cadrage
// centre le pays sur tout l'écran et la moitié du réseau se retrouve sous le
// panneau — c'est ce qui rendait le choix illisible.
// `reserved` = { left, bottom } en pixels.
function frameCountryBeside(slug, reserved) {
  if (!frameCountry(slug, true)) return;
  const cw = MAP.svg.clientWidth || 1, ch = MAP.svg.clientHeight || 1;
  const left = Math.max(0, (reserved && reserved.left) || 0);
  const bottom = Math.max(0, (reserved && reserved.bottom) || 0);
  const freeW = Math.max(80, cw - left), freeH = Math.max(80, ch - bottom);
  const vb = readVB();
  const cx = vb[0] + vb[2] / 2, cy = vb[1] + vb[3] / 2;
  // On élargit la vue du rapport de place perdue, pour que le pays tienne
  // ENTIER dans la bande libre, puis on recentre sur le milieu de cette bande.
  const k = Math.max(cw / freeW, ch / freeH);
  const w = vb[2] * k, h = vb[3] * k;
  const scale = cw / w;
  applyView([cx - (left + freeW / 2) / scale, cy - (freeH / 2) / scale, w, h]);
}

// Cadrage d'ouverture : CHEZ L'UTILISATEUR (fuseau horaire, puis langue — voir
// userCountrySlug dans geo.js), à défaut l'Europe. C'est aussi ce que rejoint le
// bouton « maison » et la touche Échap.
function frameHome(instant) {
  const slug = (typeof userCountrySlug === "function") ? userCountrySlug() : null;
  if (slug && frameCountry(slug, instant)) {
    MAP.homeName = (GEO.countries[slug] || {}).name || "";
    MAP.homeVB = MAP.lastFramed;
  } else {
    const europe = GEO.continents.find(c => c.id === "europe");
    MAP.homeName = europe.name;
    MAP.homeVB = goTo(targetVB(europe.bbox, 0.06), instant);
  }
}

// ------------------------------------------------------------------
// Fiche de gare (modale) — ouverte au clic d'une ville.
// ------------------------------------------------------------------
// Gare à proposer quand on clique une gare encore fermée : la plus FACILE des
// gares ouvertes et jamais jouées du même pays (le front de progression).
function recommendedIndex(slug) {
  const c = GEO.countries[slug];
  if (!c || typeof openFrontier !== "function") return -1;
  const country = (CATALOG[catalogIndexOf(Object.keys(c.cities || {})[0])] || {}).country;
  const front = openFrontier(country);
  return front.length ? front[0] : -1;
}
function closeModal() {
  if (MAP.modal) MAP.modal.classList.add("hidden");
  // Fiche refermée sans prendre le service : le tutoriel revient à son étape
  // « choisis ta première gare » sur la carte.
  if (typeof maybeStartMapOnboarding === "function") maybeStartMapOnboarding();
}
function openStationModal(gi) {
  if (gi < 0 || typeof CATALOG === "undefined" || !CATALOG[gi] || !MAP.modal) return;
  const card = CATALOG[gi];
  const unlocked = typeof isUnlocked === "function" && isUnlocked(gi);
  const diff = Math.max(1, Math.min(5, card.difficulty || 1));
  const nQuais = (card.platforms || []).length;
  const nDead = (card.platforms || []).filter(p => p.deadEnd).length;
  const nDir = Object.keys(card.portals || {}).length;
  const rec = (typeof getProgress === "function" ? getProgress() : {})[card.id] || {};
  const stars = rec.stars || 0, best = rec.bestDelay;
  const pips = '<span class="on">' + "●".repeat(diff) + "</span>" + "○".repeat(5 - diff);
  let spec = nQuais + " quais · " + nDir + " destinations";
  if (nDead) spec += " · " + nDead + " impasse" + (nDead > 1 ? "s" : "");

  // Où mènent ces directions : les gares reliées (le réseau de la carte)
  // d'abord, les antennes ensuite. La carte montre les traits, la fiche les
  // nomme. Attention : « N destinations » compte les portails du PLAN, alors
  // que les gares reliées viennent du graphe en union — Namur affiche 6
  // directions mais touche 5 gares, parce qu'Ottignies la nomme sans qu'elle
  // nomme Ottignies. Deux comptes différents, deux libellés différents.
  const links = (typeof netLinks === "function") ? netLinks(card.id) : { to: [], places: [] };
  const byName = (a, b) => a.localeCompare(b, "fr");
  const corr = links.to.map(id => {
    const g = catalogIndexOf(id);
    return g >= 0 ? (CATALOG[g].city || CATALOG[g].name) : id;
  }).sort(byName);
  const pts = (typeof netPlaces === "function") ? netPlaces() : {};
  const near = links.places.map(k => (pts[k] || {}).label || k).sort(byName);
  const dests =
    (corr.length ? '<div class="mm-dline"><span class="k">Gares reliées</span>' +
      corr.map(s => '<span class="d on">' + s + "</span>").join("") + "</div>" : "") +
    (near.length ? '<div class="mm-dline"><span class="k">Dessertes</span>' +
      near.map(s => '<span class="d">' + s + "</span>").join("") + "</div>" : "");

  let actions;
  if (unlocked) {
    actions = '<button class="btn mm-play" data-gi="' + gi + '">Prendre le service</button>';
  } else {
    const frontier = recommendedIndex(stationCountrySlug(gi));
    const fname = frontier >= 0 ? CATALOG[frontier].name : null;
    actions =
      '<div class="mm-lock">' + icon(ICON.lock, 15) + "<span>Gare verrouillée</span></div>" +
      (fname ? '<button class="btn mm-play" data-gi="' + frontier + '">Jouer ' + fname + " →</button>" : "");
  }

  MAP.modal.innerHTML =
    '<div class="mm-card' + (unlocked ? "" : " is-locked") + '">' +
      '<button class="mm-close" aria-label="Fermer">' + icon(ICON.close, 20) + "</button>" +
      '<div class="mm-diff">Difficulté <span class="pips">' + pips + "</span></div>" +
      '<h2 class="mm-name">' + card.name + "</h2>" +
      '<div class="mm-spec">' + spec + "</div>" +
      '<div class="mm-stars">' + starStr(stars) + "</div>" +
      (best != null ? '<div class="mm-delay">record : +' + best + " min</div>" : "") +
      '<p class="mm-desc">' + (card.tagline || card.desc || "") + "</p>" +
      (dests ? '<div class="mm-dests">' + dests + "</div>" : "") +
      '<div class="mm-actions">' + actions + "</div>" +
    "</div>";
  MAP.modal.querySelector(".mm-close").addEventListener("click", closeModal);
  const play = MAP.modal.querySelector(".mm-play");
  if (play) play.addEventListener("click", () => { const g = +play.dataset.gi; closeModal(); startStation(g); });
  MAP.modal.classList.remove("hidden");
  // Le tutoriel SUIT le joueur au lieu de rester sur la carte : sans cela, la
  // bulle « choisis ta première gare » restait affichée par-dessus la fiche —
  // périmée, et posée juste sur le bouton qu'il fallait presser.
  if (typeof onboardingStationCard === "function")
    onboardingStationCard(MAP.modal.querySelector(".mm-play"), unlocked);
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
  mapnetBuild(); // le réseau dépend de la progression : on le rebâtit à chaque retour
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
