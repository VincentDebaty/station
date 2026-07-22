"use strict";
// ------------------------------------------------------------------
// Carte du monde zoomable — sélection des gares (remplace le hub linéaire).
//
// 3 niveaux dans UN SEUL SVG en coordonnées géographiques : monde → continent →
// pays. Zoom = animation du viewBox (preserveAspectRatio "meet" → pas de
// distorsion). Frontières RÉELLES (WORLDMAP / Natural Earth), rendues LISSÉES
// (Catmull-Rom → Bézier) pour un trait doux, légèrement courbé.
//
//  - SVG : formes des pays (fond), réseau décoratif d'un pays, courbes+trains.
//  - Overlay HTML (#map-labels) : chips continent, pastilles pays (avec anti-
//    chevauchement), pastilles-villes. Placés en pixels après chaque zoom.
//
// Contrats réutilisés inchangés : startStation, isUnlocked, getProgress, CATALOG,
// GEO/geoProject/countryProgress (geo.js), WORLDMAP (worldmap.js), icon/ICON.
// ------------------------------------------------------------------

const MAP = {
  built: false, svg: null, gLand: null, gDeco: null,
  labels: null, backBtn: null, host: null, modal: null, rndBtn: null,
  level: "world", contId: null, countrySlug: null, raf: null, animating: false,
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
  bg.addEventListener("click", () => zoomOut());
  svg.appendChild(bg);

  // Formes des pays (une fois, lissées). Style/état pilotés par CSS + classes.
  const gLand = document.createElementNS(SVGNS, "g");
  gLand.setAttribute("class", "lyr-land");
  MAP.gLand = gLand;
  for (const country of WORLDMAP.countries) {
    if (MAP_EXCLUDE.has(country.iso)) continue; // Islande, Féroé, Malte, Andorre…
    const p = document.createElementNS(SVGNS, "path");
    const slug = slugOfIso(country.iso);
    const playable = !!(slug && countryStationIds(slug).length);
    p.setAttribute("class", "country-land" + (playable ? " playable" : ""));
    p.setAttribute("d", countryPathD(country));
    p.dataset.cont = country.cont;
    p.dataset.iso = country.iso;
    p.addEventListener("click", ev => {
      ev.stopPropagation();
      if (MAP.level === "world") focusContinent(country.cont);
      else if (MAP.level === "continent" && country.cont === MAP.contId) {
        if (playable) focusCountry(slug);
      }
    });
    gLand.appendChild(p);
  }
  svg.appendChild(gLand);

  // Courbes + trains décoratifs (niveau monde).
  const gDeco = document.createElementNS(SVGNS, "g");
  gDeco.setAttribute("class", "lyr-deco");
  MAP.gDeco = gDeco;
  buildDecoRoutes(gDeco);
  svg.appendChild(gDeco);

  host.appendChild(svg);

  const labels = document.createElement("div");
  labels.id = "map-labels";
  MAP.labels = labels;
  host.appendChild(labels);

  // Modale « fiche de gare » (ouverte au clic d'une ville). Clic sur le voile = fermer.
  const modal = document.createElement("div");
  modal.id = "map-modal"; modal.className = "hidden";
  modal.addEventListener("click", e => { if (e.target === modal) closeModal(); });
  MAP.modal = modal;
  host.appendChild(modal);

  // Bouton flottant unique : affiche la zone courante (« ‹ Belgique ») et revient
  // en arrière d'un niveau. Masqué au niveau monde (rien au-dessus).
  const back = document.createElement("button");
  back.className = "map-back";
  back.setAttribute("aria-label", "Revenir en arrière");
  back.addEventListener("click", () => zoomOut());
  MAP.backBtn = back;
  host.appendChild(back);

  // Bouton « Gare aléatoire » (carte du monde) : lance une gare débloquée au hasard.
  const rnd = document.createElement("button");
  rnd.className = "map-random";
  rnd.innerHTML =
    '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true">' +
    '<path d="M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.34l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.2z"/></svg>' +
    "<span>Gare aléatoire</span>";
  // Monde → toutes gares ; continent → gares du continent focalisé seulement.
  rnd.addEventListener("click", () => {
    const i = randomAvailableIndex(MAP.level === "continent" ? MAP.contId : null);
    if (i >= 0) startStation(i);
  });
  MAP.rndBtn = rnd;
  host.appendChild(rnd);

  window.addEventListener("resize", () => { if (!MAP.animating) layoutOverlay(); });
  document.addEventListener("keydown", e => {
    if (e.key !== "Escape" || document.getElementById("hub").classList.contains("hidden")) return;
    if (MAP.modal && !MAP.modal.classList.contains("hidden")) closeModal(); // modale d'abord
    else zoomOut();
  });

  MAP.built = true;
}

// Lignes ferroviaires décoratives entre continents + petits trains (offset-path).
function buildDecoRoutes(g) {
  const routes = [
    ["europe", "am-nord"], ["europe", "asie"], ["am-nord", "am-sud"],
    ["asie", "sea-oceanie"], ["afrique", "europe"], ["am-nord", "asie"]
  ];
  const palette = ["#2dd4bf", "#f5b23c", "#4ade80", "#60a5fa", "#f2588f", "#a78bfa"];
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
    const train = document.createElementNS(SVGNS, "rect");
    train.setAttribute("class", "deco-train");
    train.setAttribute("width", 22); train.setAttribute("height", 9); train.setAttribute("rx", 4);
    train.setAttribute("x", -11); train.setAttribute("y", -4.5);
    train.setAttribute("fill", palette[i % palette.length]);
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
    if (e < 1) { MAP.raf = requestAnimationFrame(step); }
    else { MAP.raf = null; MAP.animating = false; MAP.host.classList.remove("tweening"); onDone && onDone(); }
  }
  MAP.raf = requestAnimationFrame(step);
}

// Projection géo → pixels écran (placement de l'overlay), selon le viewBox courant.
function screenPos(lon, lat) {
  const vb = readVB();
  const cw = MAP.svg.clientWidth, ch = MAP.svg.clientHeight;
  const scale = Math.min(cw / vb[2], ch / vb[3]);
  const ox = (cw - vb[2] * scale) / 2, oy = (ch - vb[3] * scale) / 2;
  const u = geoProject(lon, lat);
  return { x: ox + (u.x - vb[0]) * scale, y: oy + (u.y - vb[1]) * scale };
}

// ------------------------------------------------------------------
// Overlay HTML : reconstruit à chaque arrivée de zoom.
// ------------------------------------------------------------------
function chip(x, y, cls) {
  const d = document.createElement("div");
  d.className = "map-chip " + cls;
  d.style.left = x + "px"; d.style.top = y + "px";
  MAP.labels.appendChild(d);
  return d;
}
function starStr(n) { return "★".repeat(n) + "☆".repeat(3 - n); }
// AABB : deux boîtes {x,y,w,h} se chevauchent-elles ?
function overlaps(a, b) {
  return Math.abs(a.x - b.x) * 2 < (a.w + b.w) && Math.abs(a.y - b.y) * 2 < (a.h + b.h);
}
// Anti-agglutination des pastilles-villes : répulsion pour qu'aucune paire ne se
// chevauche, + léger rappel vers la vraie position géo (`bx,by`) → réparties mais
// restant proches de leur emplacement réel. Nodes mutés en place ({x,y,bx,by}).
function dodgeCities(nodes, minDist, iters, spring, bnd) {
  // Déloge d'abord les points quasi confondus (ex. 2 gares d'une même ville).
  nodes.forEach((n, i) => { n.x += Math.cos(i * 2.4) * 0.6; n.y += Math.sin(i * 2.4) * 0.6; });
  for (let it = 0; it < iters; it++) {
    for (let i = 0; i < nodes.length; i++)
      for (let j = i + 1; j < nodes.length; j++) {
        const a = nodes[i], b = nodes[j];
        let dx = b.x - a.x, dy = b.y - a.y;
        let d = Math.hypot(dx, dy) || 0.001;
        if (d < minDist) {
          const push = (minDist - d) / 2, ux = dx / d, uy = dy / d;
          a.x -= ux * push; a.y -= uy * push;
          b.x += ux * push; b.y += uy * push;
        }
      }
    for (const n of nodes) {
      n.x += (n.bx - n.x) * spring; n.y += (n.by - n.y) * spring;
      // Bords « durs » DANS la simulation : une gare bloquée contre un bord
      // repousse les autres au lieu de venir se superposer après coup.
      if (bnd) {
        n.x = Math.max(bnd.x0, Math.min(bnd.x1, n.x));
        n.y = Math.max(bnd.y0, Math.min(bnd.y1, n.y));
      }
    }
  }
}

function layoutOverlay() {
  if (!MAP.labels) return;
  const cw = MAP.svg.clientWidth, ch = MAP.svg.clientHeight;
  if (!cw || !ch) return; // carte masquée (largeur nulle) : ne pas repositionner
  MAP.labels.innerHTML = "";
  const inView = (p) => p.x > -40 && p.x < cw + 40 && p.y > -40 && p.y < ch + 40;

  if (MAP.level === "world") {
    for (const c of GEO.continents) {
      const ctr = continentCentroid(c.id);
      const p = screenPos(ctr[0], ctr[1]);
      const prog = continentProgress(c.id);
      const el = chip(p.x, p.y, "continent-chip");
      el.innerHTML = '<div class="nm">' + c.name + "</div>" +
        (prog.max ? '<div class="pg">' + prog.earned + "★ / " + prog.max + "</div>" : "");
      el.addEventListener("click", () => focusContinent(c.id));
    }

  } else if (MAP.level === "continent") {
    // Pays JOUABLES seulement : bulle drapeau + barre de progression (étoiles
    // gagnées / total). Les autres pays restent de simples formes (non marqués).
    const list = (MAP.byCont[MAP.contId] || [])
      .map(country => ({ country, slug: slugOfIso(country.iso), p: screenPos(country.lx, country.ly) }))
      .filter(o => o.slug && countryStationIds(o.slug).length && inView(o.p));
    const R = 19, C = 2 * Math.PI * R; // anneau de progression autour du drapeau
    for (const o of list) {
      const prog = countryProgress(o.slug);
      const g = GEO.countries[o.slug];
      const frac = prog.max ? prog.earned / prog.max : 0;
      const el = chip(o.p.x, o.p.y, "country-chip");
      el.innerHTML =
        '<svg class="cring" viewBox="0 0 44 44">' +
          '<circle class="track" cx="22" cy="22" r="' + R + '"/>' +
          (frac > 0 ? '<circle class="prog" cx="22" cy="22" r="' + R +
            '" stroke-dasharray="' + (frac * C).toFixed(1) + " " + C.toFixed(1) + '"/>' : "") +
        "</svg>" +
        '<span class="cflag">' + g.flag + "</span>";
      el.addEventListener("click", () => focusCountry(o.slug));
    }

  } else if (MAP.level === "country") {
    const c = GEO.countries[MAP.countrySlug];
    const prog = (typeof getProgress === "function") ? getProgress() : {};
    // Villes en ORDRE DE JEU (difficulté) : sert au réseau ET rend l'ordre lisible.
    const ids = Object.keys(c.cities || {}).sort((a, b) => {
      const ia = catalogIndexOf(a), ib = catalogIndexOf(b);
      return (ia < 0 ? 1e9 : ia) - (ib < 0 ? 1e9 : ib);
    });
    // Position de départ = vraie position géo, puis anti-agglutination (répulsion
    // + rappel) pour dégrouper le cluster (ex. Bruxelles) sans trop s'en éloigner.
    // num = ordre de jeu (1 = plus facile) — les ids sont déjà triés par difficulté.
    const nodes = ids.map((id, i) => {
      const p = screenPos(c.cities[id][0], c.cities[id][1]);
      return { id, num: i + 1, x: p.x, y: p.y, bx: p.x, by: p.y };
    });
    dodgeCities(nodes, 70, 320, 0.028, { x0: 56, x1: cw - 56, y0: 64, y1: ch - 74 });

    // Réseau décoratif reliant les villes (ordre de jeu), sur les positions
    // ajustées, dans un SVG écran posé SOUS les pastilles.
    if (nodes.length > 1) {
      const net = document.createElementNS(SVGNS, "svg");
      net.setAttribute("class", "city-net");
      net.setAttribute("width", cw); net.setAttribute("height", ch);
      const path = document.createElementNS(SVGNS, "path");
      path.setAttribute("class", "map-network");
      path.setAttribute("d", nodes.map((n, i) =>
        (i ? "L" : "M") + n.x.toFixed(1) + "," + n.y.toFixed(1)).join(" "));
      net.appendChild(path);
      MAP.labels.appendChild(net);
    }

    // Villes = petit point-gare (teal jouable / gris verrouillé) + libellé léger,
    // posé dessous OU dessus selon la place libre. Plus de grosse pastille ronde.
    const curGi = currentIndex(MAP.countrySlug); // prochaine gare à réaliser (anneau pulsé)
    const placed = [];
    const CAPW = 130, CAPH = 44, DY = 19 + CAPH / 2;
    for (const n of nodes) {
      const dotBox = { x: n.x, y: n.y, w: 24, h: 24 };
      const down = { x: n.x, y: n.y + DY, w: CAPW, h: CAPH };
      const up = { x: n.x, y: n.y - DY, w: CAPW, h: CAPH };
      const downHit = placed.some(b => overlaps(down, b));
      const upHit = placed.some(b => overlaps(up, b));
      const upFits = n.y - DY - CAPH / 2 > 4;         // le cartouche ne sort pas en haut
      const downFits = n.y + DY + CAPH / 2 < ch - 4;  //          ni en bas
      // On préfère le côté libre ; à égalité, les gares du haut portent leur
      // cartouche au-dessus (place ouverte sous la bordure) pour ne pas chevaucher
      // la gare juste en dessous.
      let capUp;
      if (downHit && !upHit && upFits) capUp = true;
      else if (upHit && !downHit && downFits) capUp = false;
      else if (!downHit && !upHit) capUp = n.y < ch * 0.42 && upFits;
      else capUp = !downFits && upFits;
      placed.push(dotBox, capUp ? up : down);

      const gi = catalogIndexOf(n.id);
      const cfg = gi >= 0 ? CATALOG[gi] : null;
      const unlocked = gi >= 0 && typeof isUnlocked === "function" && isUnlocked(gi);
      const stars = (prog[n.id] || {}).stars || 0;
      const best = (prog[n.id] || {}).bestDelay;
      const el = chip(n.x, n.y, "city-chip" + (unlocked ? "" : " locked") +
        (gi === curGi ? " current" : "") + (capUp ? " cap-up" : ""));
      el.innerHTML =
        '<span class="dot">' + n.num + "</span>" +
        '<div class="cap"><div class="nm">' + (cfg ? cfg.name : n.id) + "</div>" +
        '<div class="st">' + starStr(stars) +
          (best != null ? '<span class="dl">+' + best + "</span>" : "") + "</div></div>";
      // Toute ville ouvre sa fiche (verrouillée comprise) ; le lancement se fait
      // depuis la modale.
      if (gi >= 0) el.addEventListener("click", () => openStationModal(gi));
    }
  }
}

// ------------------------------------------------------------------
// Navigation.
// ------------------------------------------------------------------
function setFocusClasses() {
  // Met en évidence le continent focalisé et le pays courant sur les formes.
  const curIso = MAP.level === "country" && GEO.countries[MAP.countrySlug]
    ? GEO.countries[MAP.countrySlug].iso : null;
  const raise = [];
  for (const path of [...MAP.gLand.children]) {
    const inFocus = (MAP.level === "continent" || MAP.level === "country") &&
      path.dataset.cont === MAP.contId;
    const isCurrent = path.dataset.iso === curIso;
    path.classList.toggle("in-focus", inFocus);
    path.classList.toggle("is-current", isCurrent);
    // Le SVG n'a pas de z-index : l'ordre de peinture = l'ordre dans le DOM. On
    // remonte les pays mis en évidence en fin de groupe (le courant tout à la fin,
    // au-dessus) pour que leur liseré ne soit pas recouvert par les voisins.
    if (inFocus || isCurrent) raise.push({ path, isCurrent });
  }
  raise.sort((a, b) => (a.isCurrent ? 1 : 0) - (b.isCurrent ? 1 : 0));
  for (const r of raise) MAP.gLand.appendChild(r.path);
}
function updateChrome() {
  MAP.host.dataset.level = MAP.level;
  // Le bouton flottant porte le nom de la zone COURANTE et revient en arrière.
  const label = MAP.level === "country"
      ? ((GEO.countries[MAP.countrySlug] || {}).name || "")
    : MAP.level === "continent"
      ? ((GEO.continents.find(c => c.id === MAP.contId) || {}).name || "")
    : "";
  MAP.backBtn.classList.toggle("hidden", MAP.level === "world");
  MAP.backBtn.innerHTML = '<span class="arw">‹</span><span class="lbl">' + label + "</span>";
  // Bouton « Gare aléatoire » : au monde (toutes gares) et au continent (si ce
  // continent a au moins une gare débloquée) ; masqué au niveau pays.
  const canRandom = MAP.level === "world"
    || (MAP.level === "continent" && availableIndices(MAP.contId).length > 0);
  MAP.rndBtn.classList.toggle("hidden", !canRandom);
}
function goTo(vb, instant) {
  updateChrome(); setFocusClasses();
  if (instant) { setVB(vb); layoutOverlay(); }
  else { tweenTo(vb, 560, layoutOverlay); }
}
function focusWorld(instant) {
  MAP.level = "world"; MAP.contId = null; MAP.countrySlug = null;
  goTo(GEO.world.viewBox.slice(), instant);
}
function focusContinent(id, instant) {
  const cont = GEO.continents.find(c => c.id === id);
  if (!cont) return;
  MAP.level = "continent"; MAP.contId = id; MAP.countrySlug = null;
  goTo(targetVB(cont.bbox, 0.06), instant);
}
function focusCountry(slug, instant) {
  const g = GEO.countries[slug];
  const country = g && MAP.byIso[g.iso];
  if (!country) return;
  MAP.level = "country"; MAP.countrySlug = slug; MAP.contId = g.continent;
  goTo(targetVB(countryGeoBbox(country), 0.05), instant);
}
function zoomOut() {
  if (MAP.animating) return;
  if (MAP.level === "country") focusContinent(MAP.contId);
  else if (MAP.level === "continent") focusWorld();
}

// ------------------------------------------------------------------
// Fiche de gare (modale) — ouverte au clic d'une ville.
// ------------------------------------------------------------------
// Gare « disponible » d'un pays = la plus avancée encore débloquée (le front de
// progression), à proposer quand on clique une gare verrouillée.
function recommendedIndex(slug) {
  const c = GEO.countries[slug];
  if (!c) return -1;
  let best = -1;
  for (const id of Object.keys(c.cities || {})) {
    const gi = catalogIndexOf(id);
    if (gi >= 0 && typeof isUnlocked === "function" && isUnlocked(gi) && gi > best) best = gi;
  }
  return best;
}
// Gare « courante » = la prochaine à réaliser : la 1re débloquée encore jamais
// jouée (0 étoile) — c'est elle qui, réussie, débloque la suivante.
function currentIndex(slug) {
  const c = GEO.countries[slug];
  if (!c) return -1;
  const prog = (typeof getProgress === "function") ? getProgress() : {};
  const gis = Object.keys(c.cities || {}).map(catalogIndexOf).filter(gi => gi >= 0).sort((a, b) => a - b);
  for (const gi of gis)
    if (typeof isUnlocked === "function" && isUnlocked(gi) && !((prog[CATALOG[gi].id] || {}).stars))
      return gi;
  return -1;
}
// Gares débloquées disponibles, éventuellement restreintes à un continent
// (bouton « Gare aléatoire »). Sans contId : toutes gares, tous pays.
function availableIndices(contId) {
  if (typeof CATALOG === "undefined") return [];
  const out = [];
  if (contId) {
    for (const slug in GEO.countries) {
      if (GEO.countries[slug].continent !== contId) continue;
      for (const id of Object.keys(GEO.countries[slug].cities || {})) {
        const gi = catalogIndexOf(id);
        if (gi >= 0 && typeof isUnlocked === "function" && isUnlocked(gi)) out.push(gi);
      }
    }
  } else {
    for (let i = 0; i < CATALOG.length; i++)
      if (typeof isUnlocked === "function" && isUnlocked(i)) out.push(i);
  }
  return out;
}
function randomAvailableIndex(contId) {
  const pool = availableIndices(contId);
  return pool.length ? pool[Math.floor(Math.random() * pool.length)] : -1;
}
function closeModal() { if (MAP.modal) MAP.modal.classList.add("hidden"); }
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

  let actions;
  if (unlocked) {
    actions = '<button class="btn mm-play" data-gi="' + gi + '">Prendre le service</button>';
  } else {
    const frontier = recommendedIndex(MAP.countrySlug);
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
      '<div class="mm-actions">' + actions + "</div>" +
    "</div>";
  MAP.modal.querySelector(".mm-close").addEventListener("click", closeModal);
  const play = MAP.modal.querySelector(".mm-play");
  if (play) play.addEventListener("click", () => { const g = +play.dataset.gi; closeModal(); startStation(g); });
  MAP.modal.classList.remove("hidden");
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
  closeModal();
  cancelTween(); MAP.animating = false; MAP.host.classList.remove("tweening");
  if (MAP.level === "country" && MAP.countrySlug) focusCountry(MAP.countrySlug, true);
  else if (MAP.level === "continent" && MAP.contId) focusContinent(MAP.contId, true);
  else focusWorld(true);
}
