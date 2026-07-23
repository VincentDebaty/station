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
      // au niveau monde : on ne zoome que sur un continent qui a du contenu
      // (cohérent avec le chip « Bientôt » — pas de plongée dans le vide)
      if (MAP.level === "world") {
        if (continentProgress(country.cont).max > 0) focusContinent(country.cont);
      } else if (MAP.level === "continent" && country.cont === MAP.contId) {
        if (playable) focusCountry(slug);
      } else if (MAP.level === "country" && country.cont === MAP.contId) {
        // au niveau pays : cliquer un pays voisin JOUABLE y voyage directement.
        if (playable && slug !== MAP.countrySlug) focusCountry(slug);
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

  // Bouton « Partie rapide » (carte du monde) : lance une gare débloquée au hasard.
  const rnd = document.createElement("button");
  rnd.className = "map-random";
  rnd.innerHTML =
    '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true">' +
    '<path d="M8 5v14l11-7z"/></svg>' +
    "<span>Partie rapide</span>";
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
      const playable = prog.max > 0; // au moins une gare disponible dans le jeu
      const el = chip(p.x, p.y, "continent-chip " + (playable ? "playable" : "soon"));
      const frac = playable ? Math.round((prog.earned / prog.max) * 100) : 0;
      el.innerHTML = '<div class="nm">' + c.name + "</div>" +
        (playable ? '<div class="cbar"><span style="width:' + frac + '%"></span></div>' +
                    '<div class="pg">' + prog.earned + " / " + prog.max + " ★</div>"
                  : '<div class="soon-tag">Bientôt</div>');
      // Continent « à venir » : pas de gares → on ne zoome pas dans le vide.
      if (playable) el.addEventListener("click", () => focusContinent(c.id));
    }

  } else if (MAP.level === "continent") {
    // Pays JOUABLES seulement : bulle drapeau + NOM + anneau de progression
    // (étoiles gagnées / total). Les autres pays restent de simples formes.
    const list = (MAP.byCont[MAP.contId] || [])
      .map(country => ({ country, slug: slugOfIso(country.iso), p: screenPos(country.lx, country.ly) }))
      .filter(o => o.slug && countryStationIds(o.slug).length && inView(o.p));
    // anti-chevauchement des pastilles-pays (comme les villes) : répulsion +
    // rappel vers la vraie position géo → évite l'agglutination (Benelux, etc.)
    const nodes = list.map(o => ({ o, x: o.p.x, y: o.p.y, bx: o.p.x, by: o.p.y }));
    dodgeCities(nodes, 76, 260, 0.03, { x0: 48, x1: cw - 48, y0: 46, y1: ch - 58 });
    const curSlug = currentCountrySlug(MAP.contId); // pays « à continuer » (anneau pulsé)
    const R = 19, C = 2 * Math.PI * R; // anneau de progression autour du drapeau
    for (const n of nodes) {
      const o = n.o;
      const prog = countryProgress(o.slug);
      const g = GEO.countries[o.slug];
      const frac = prog.max ? prog.earned / prog.max : 0;
      const el = chip(n.x, n.y, "country-chip" + (o.slug === curSlug ? " current" : ""));
      el.innerHTML =
        '<svg class="cring" viewBox="0 0 44 44">' +
          '<circle class="track" cx="22" cy="22" r="' + R + '"/>' +
          (frac > 0 ? '<circle class="prog" cx="22" cy="22" r="' + R +
            '" stroke-dasharray="' + (frac * C).toFixed(1) + " " + C.toFixed(1) + '"/>' : "") +
        "</svg>" +
        '<span class="cflag">' + g.flag + "</span>" +
        '<div class="cnm">' + g.name + "</div>";
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
    dodgeCities(nodes, 104, 420, 0.028, { x0: 56, x1: cw - 56, y0: 64, y1: ch - 74 });

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
    // Cadenas (gare verrouillée) + horloge (retard record) — signifiants clairs,
    // pour lever l'ambiguïté « verrouillé / non-joué » et « +N = quoi ? ».
    const lockSvg = '<svg class="lock" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1s3.1 1.39 3.1 3.1v2z"/></svg>';
    const clockSvg = '<svg viewBox="0 0 24 24" width="10" height="10" fill="currentColor" aria-hidden="true"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/></svg>';
    const CAPH = 40, DY = 18 + CAPH / 2;
    // Recouvrement (aire) de deux boîtes AABB — 0 si disjointes. Sert à noter
    // finement une position de cartouche (« chevauche un peu » ≠ « chevauche tout »).
    const overlapArea = (a, b) => {
      const ox = Math.min(a.x + a.w / 2, b.x + b.w / 2) - Math.max(a.x - a.w / 2, b.x - b.w / 2);
      const oy = Math.min(a.y + a.h / 2, b.y + b.h / 2) - Math.max(a.y - a.h / 2, b.y - b.h / 2);
      return ox > 0 && oy > 0 ? ox * oy : 0;
    };
    // Métadonnées par ville, puis on ENSEMENCE d'abord toutes les pastilles :
    // ainsi un cartouche posé tôt évite AUSSI les points posés après lui.
    const metas = nodes.map(n => {
      const gi = catalogIndexOf(n.id);
      const cfg = gi >= 0 ? CATALOG[gi] : null;
      const label = cfg ? cfg.name : n.id;
      // Largeur RÉELLE estimée du cartouche (nom sur UNE ligne, cf. .nm nowrap) :
      // les noms courts (Namur) n'écartent plus inutilement, les longs
      // (Bruxelles-Midi, Gand-Saint-Pierre) réservent la place qu'il faut.
      const capW = Math.min(172, Math.max(60, label.length * 7.4 + 26));
      const isCur = gi === curGi;
      return {
        n, gi, label, capW, isCur,
        unlocked: gi >= 0 && typeof isUnlocked === "function" && isUnlocked(gi),
        stars: (prog[n.id] || {}).stars || 0,
        best: (prog[n.id] || {}).bestDelay
      };
    });
    // La gare courante porte un halo pulsé plus large → footprint agrandi.
    const placed = metas.map(m => ({ x: m.n.x, y: m.n.y, w: m.isCur ? 34 : 24, h: m.isCur ? 34 : 24 }));
    // Placement en ORDRE SPATIAL (haut→bas, gauche→droite) : les voisins sont
    // traités à la suite, donc l'alternance dessous/dessus se fait proprement au
    // lieu de dépendre de l'ordre de difficulté.
    for (const m of metas.slice().sort((a, b) => a.n.y - b.n.y || a.n.x - b.n.x)) {
      const { n, label, capW } = m;
      // Positions candidates : dessous/dessus × décalage horizontal (centré, puis
      // décalé à droite/gauche). On retient celle qui recouvre le MOINS d'aire.
      const shift = Math.min(56, capW * 0.4);
      const preferUp = n.y < ch * 0.42;
      const cands = [];
      for (const useUp of (preferUp ? [true, false] : [false, true]))
        for (const dx of [0, shift, -shift, 2 * shift, -2 * shift])
          cands.push({ useUp, dx });
      let bestC = cands[0], bestPen = Infinity;
      for (const c of cands) {
        const cy = c.useUp ? n.y - DY : n.y + DY;
        const box = { x: n.x + c.dx, y: cy, w: capW, h: CAPH };
        let pen = placed.reduce((s, b) => s + overlapArea(box, b), 0);
        if (c.useUp ? cy - CAPH / 2 < 4 : cy + CAPH / 2 > ch - 4) pen += 4000; // hors écran (haut/bas)
        if (box.x - capW / 2 < 4) pen += (4 - (box.x - capW / 2)) * 30;        //           (gauche)
        if (box.x + capW / 2 > cw - 4) pen += (box.x + capW / 2 - (cw - 4)) * 30; //         (droite)
        pen += Math.abs(c.dx) * 4; // à recouvrement égal : cartouche le plus centré sous le point
        if (pen < bestPen) { bestPen = pen; bestC = c; if (pen === 0) break; }
      }
      const capUp = bestC.useUp;
      placed.push({ x: n.x + bestC.dx, y: capUp ? n.y - DY : n.y + DY, w: capW, h: CAPH });

      const el = chip(n.x, n.y, "city-chip" + (m.unlocked ? "" : " locked") +
        (m.isCur ? " current" : "") + (capUp ? " cap-up" : ""));
      el.innerHTML =
        '<span class="dot">' + n.num + (m.unlocked ? "" : lockSvg) + "</span>" +
        '<div class="cap" style="width:' + capW.toFixed(0) + "px;transform:translateX(calc(-50% + " + bestC.dx.toFixed(0) + 'px))">' +
        '<div class="nm">' + label + "</div>" +
        '<div class="st">' + starStr(m.stars) +
          (m.best != null ? '<span class="dl">' + clockSvg + m.best + "′</span>" : "") + "</div></div>";
      // Toute ville ouvre sa fiche (verrouillée comprise) ; le lancement se fait
      // depuis la modale.
      if (m.gi >= 0) el.addEventListener("click", () => openStationModal(m.gi));
    }

    // Pays voisins JOUABLES (même continent) présents dans le cadre : affichés
    // dans LEUR zone, au MÊME format qu'au niveau continent (drapeau + anneau de
    // progression + nom) → cohérence visuelle, et on sait où mène le clic (la forme
    // voisine comme ce chip y voyagent). Ancré au centre du pays, rabattu sur le
    // bord de la vue, puis glissé le long de ce bord pour éviter les gares posées.
    const vb = readVB();
    const vx0 = vb[0], vy0 = vb[1], vx1 = vb[0] + vb[2], vy1 = vb[1] + vb[3];
    const R = 19, C = 2 * Math.PI * R;
    for (const slug in GEO.countries) {
      const g = GEO.countries[slug];
      if (slug === MAP.countrySlug || g.continent !== MAP.contId) continue;
      if (!countryStationIds(slug).length) continue;
      const country = MAP.byIso[g.iso];
      if (!country) continue;
      const rr = geoBoxToRect(countryGeoBbox(country)); // emprise en unités SVG
      const iw = Math.min(rr.x + rr.w, vx1) - Math.max(rr.x, vx0);
      const ih = Math.min(rr.y + rr.h, vy1) - Math.max(rr.y, vy0);
      if (iw <= 0 || ih <= 0) continue; // hors champ
      // Part du cadre occupée par le voisin. Zoom RAPPROCHÉ sur un grand pays → le
      // voisin n'est qu'un liseré (ex. Belgique en haut de la France) : on ne
      // l'affiche pas. Zoom sur un petit pays → le voisin remplit une bonne part
      // de l'écran (France sous la Belgique) : on l'affiche. (Projection iso →
      // les aires en unités SVG sont proportionnelles aux aires géo.)
      if ((iw * ih) / (vb[2] * vb[3]) < 0.14) continue;
      const raw = screenPos(country.lx, country.ly);
      const cx = Math.max(64, Math.min(cw - 64, raw.x));
      const cy = Math.max(52, Math.min(ch - 66, raw.y));
      // Axe libre = le bord sur lequel on est rabattu (haut/bas → glisse en x ;
      // gauche/droite → glisse en y). On n'autorise qu'un PETIT décalage local
      // (±~60 px) fortement pénalisé : dégager une gare, oui ; dériver sur un autre
      // pays (Belgique au-dessus de l'Allemagne), non — la précision géo prime.
      const slideX = Math.abs(cy - raw.y) >= Math.abs(cx - raw.x);
      const W = Math.max(72, g.name.length * 7 + 24), H = 66;
      let bx = cx, by = cy, bestPen = Infinity;
      for (let k = 0; k <= 2 && bestPen > 0; k++)
        for (const s of (k === 0 ? [0] : [k, -k])) {
          const x = slideX ? Math.max(64, Math.min(cw - 64, cx + s * 30)) : cx;
          const y = slideX ? cy : Math.max(52, Math.min(ch - 66, cy + s * 28));
          const box = { x, y: y + 12, w: W, h: H };
          const pen = placed.reduce((sum, b) => sum + overlapArea(box, b), 0) + Math.abs(s) * 900;
          if (pen < bestPen) { bestPen = pen; bx = x; by = y; }
        }
      const cp = countryProgress(slug);
      const frac = cp.max ? cp.earned / cp.max : 0;
      const el = chip(bx, by, "country-chip neighbor");
      el.innerHTML =
        '<svg class="cring" viewBox="0 0 44 44">' +
          '<circle class="track" cx="22" cy="22" r="' + R + '"/>' +
          (frac > 0 ? '<circle class="prog" cx="22" cy="22" r="' + R +
            '" stroke-dasharray="' + (frac * C).toFixed(1) + " " + C.toFixed(1) + '"/>' : "") +
        "</svg>" +
        '<span class="cflag">' + g.flag + "</span>" +
        '<div class="cnm">' + g.name + "</div>";
      el.addEventListener("click", () => focusCountry(slug));
      placed.push({ x: bx, y: by + 12, w: W, h: H });
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
  // Bouton « Partie rapide » : au monde (toutes gares) et au continent (si ce
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
// Pays « courant » d'un continent = celui qui porte la prochaine gare à réaliser
// (la frontière de progression : plus petit index catalogue encore à faire). Sert
// à mettre en évidence, au niveau continent, où le joueur doit reprendre.
function currentCountrySlug(contId) {
  let best = -1, bestSlug = null;
  for (const slug in GEO.countries) {
    if (GEO.countries[slug].continent !== contId) continue;
    const gi = currentIndex(slug);
    if (gi >= 0 && (best < 0 || gi < best)) { best = gi; bestSlug = slug; }
  }
  return bestSlug;
}
// Gares débloquées disponibles, éventuellement restreintes à un continent
// (bouton « Partie rapide »). Sans contId : toutes gares, tous pays.
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
