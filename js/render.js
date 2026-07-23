"use strict";
// ------------------------------------------------------------------
// Rendu : plan de voies statique, frise chronologique, convois animés,
// badges, sons et toasts.
// ------------------------------------------------------------------
let gTracks, gRoutes, gPlatforms, gPortals, gQueue, gTrains, gFx, gBadges;
let portalUI = {}; // repères de sortie par portail (nom + géométrie) pour l'effet « validé »

// Sur écran tactile, le plan (viewBox 1400×760) est fortement réduit pour
// tenir en paysage : textes et convois deviennent minuscules. On grossit donc
// d'un même facteur les éléments-clés — noms de villes, badges d'heure,
// abréviations sur les trains et hauteur des wagons — sans toucher à
// l'espacement horizontal (CAR_SPACING), qui régit la physique du gril.
const UIK = (window.matchMedia && window.matchMedia("(pointer: coarse)").matches) ? 1.5 : 1;

function el(tag, attrs, parent) {
  const e = document.createElementNS(SVGNS, tag);
  for (const [k, v] of Object.entries(attrs || {})) e.setAttribute(k, v);
  if (parent) parent.appendChild(e);
  return e;
}

function drawStatic() {
  board.innerHTML = "";
  // Gare terminus : tous les portails du même côté, le réseau n'occupe qu'un
  // flanc. On cadre le viewBox au plus près du contenu réel (portails, quais,
  // voie d'approche) pour agrandir le faisceau et occuper toute la place ;
  // "meet" recentre dans le cadre. Aucune coordonnée du réseau n'est touchée —
  // seul le zoom d'affichage change, donc la difficulté reste identique.
  const sides = new Set(Object.values(PORTALS).map(p => p.side));
  const only = sides.size === 1 ? [...sides][0] : null;
  const cys = [...PLATFORMS.map(q => q.cy), ...Object.values(PORTALS).map(p => p.cy)];
  const yBot = Math.max(...cys) + 58;     // marge basse : voie d'approche (cy+36) + wagon
  if (only) {
    const yTop = Math.min(...cys) - 85;   // marge : badges d'heure (×1.5 sur mobile) + noms
    const xL = only === "L" ? 8 : PLAT_X1 - 55;
    const xR = only === "L" ? PLAT_X2 + 55 : 1392;
    board.setAttribute("viewBox", `${xL} ${yTop} ${xR - xL} ${yBot - yTop}`);
  } else {
    // Gare traversante : réseau des deux côtés → on garde la pleine largeur et
    // la marge haute (le HUD flotte au-dessus du centre : l'horloge ne doit pas
    // recouvrir le badge du quai du haut), mais on rogne la bande noire du bas.
    board.setAttribute("viewBox", `0 0 1400 ${yBot}`);
  }
  const defs = el("defs", {}, board);
  const pat = el("pattern", {
    id: "hatch", width: 8, height: 8,
    patternUnits: "userSpaceOnUse", patternTransform: "rotate(45)"
  }, defs);
  el("rect", { width: 8, height: 8, fill: "rgba(239,68,68,.08)" }, pat);
  el("line", { x1: 0, y1: 0, x2: 0, y2: 8, stroke: "var(--red)", "stroke-width": 2, opacity: 0.5 }, pat);
  // Léger dégradé vertical sur les quais : reflet en haut, ombre en bas — donne
  // du relief à la pilule sans changer sa couleur perçue (quai libre au repos).
  const pg2 = el("linearGradient", { id: "platGrad", x1: 0, y1: 0, x2: 0, y2: 1 }, defs);
  el("stop", { offset: 0, "stop-color": "#243049" }, pg2);
  el("stop", { offset: 1, "stop-color": "#161f30" }, pg2);
  // Les trains entrent et sortent par les bords de la carte : le viewBox
  // les découpe naturellement, wagon par wagon
  gTracks    = el("g", {}, board);
  gPlatforms = el("g", {}, board);
  gRoutes    = el("g", {}, board);
  gQueue     = el("g", {}, board); // voie d'approche
  gTrains    = el("g", {}, board);
  gPortals   = el("g", {}, board);
  gFx        = el("g", {}, board);
  // Calque tout en haut : les badges d'heure flottent au-dessus de tout,
  // libellés de portail compris (ils se positionnent en coordonnées absolues).
  gBadges    = el("g", {}, board);

  // Maillage teinté : chaque voie porte discrètement la couleur de sa ville
  // — on distingue d'un coup d'œil à quel portail appartient chaque courbe
  for (const m of meshD) {
    const t = el("path", { d: m.d, class: "track" }, gTracks);
    t.style.stroke = DEST_COLOR[m.portal];
    t.style.opacity = "0.38";
  }

  // Quais — groupés par quai pour pouvoir assombrir d'un bloc les quais non
  // valides pendant une sélection
  for (const q of PLATFORMS) {
    const pg = el("g", { class: "plat", id: "plat-" + q.id }, gPlatforms);
    const rect = el("rect", {
      x: PLAT_X1, y: q.cy - PLAT_H / 2, width: PLAT_X2 - PLAT_X1, height: PLAT_H,
      rx: 10, class: "platform", "data-platform": q.id
    }, pg);
    rect.addEventListener("click", () => onPlatformClick(q.id));
    el("text", { x: (PLAT_X1 + PLAT_X2) / 2, y: q.cy, class: "platform-label" }, pg)
      .textContent = q.id;

    // heurtoir du quai en impasse
    if (q.deadEnd)
      el("rect", { x: PLAT_X2 + 4, y: q.cy - 13, width: 7, height: 26, rx: 2, class: "buffer-stop" }, pg);
  }

  // Portails (terminus compris) : les voies filent jusqu'au BORD RÉEL de
  // l'écran (au-delà du viewBox, EDGE_RUN dans la bande de letterbox) — les
  // convois émergent et disparaissent au ras de l'écran, sans bandeau qui les
  // arrête. Le nom de la destination, en trait léger, se pose juste au-dessus
  // de la voie ; le train qui sort glisse dessous.
  portalUI = {};
  for (const [name, p] of Object.entries(PORTALS)) {
    const c = DEST_COLOR[name];
    const edge = p.side === "L" ? -EDGE_RUN : 1400 + EDGE_RUN;   // point de fuite = bord écran
    const lnOut = el("line", { x1: edge, y1: p.cy, x2: p.x, y2: p.cy, class: "track" }, gTracks);
    lnOut.style.stroke = c; lnOut.style.opacity = "0.38";
    const lnIn = el("path", { d: pathD(APPROACH[name].pts), class: "track" }, gTracks);
    lnIn.style.stroke = c; lnIn.style.opacity = "0.38";
    // point de convergence marqué à la couleur de la ville
    const cvg = el("circle", { cx: p.x, cy: p.cy, r: 5, "pointer-events": "none" }, gTracks);
    cvg.style.fill = c; cvg.style.opacity = "0.85";
    const grp = el("g", { style: "cursor:pointer" }, gPortals);
    // nom au ras du bord, juste au-dessus de la voie, là où le convoi
    // disparaît — il glisse dessous en sortant.
    const tw = (22 + p.label.length * 10) * UIK;
    const nameY = p.cy - 34 * UIK;
    const nameCx = p.side === "L" ? 12 + tw / 2 : 1388 - tw / 2;
    // zone de clic généreuse (sélectionne le 1er train en file du portail)
    el("rect", {
      x: p.side === "L" ? 0 : 1340,
      y: nameY - 30, width: 96, height: 88,
      fill: "transparent"
    }, grp);
    const tt = el("text", { x: nameCx, y: nameY, class: "portal-name" }, grp);
    tt.textContent = p.label;
    tt.style.fill = c; tt.style.color = c; // color : currentColor du halo de validation
    tt.style.fontSize = (15 * UIK) + "px";
    grp.addEventListener("click", ev => {
      ev.stopPropagation();
      const here = o => (o.state === "waiting" || o.state === "approaching") &&
                        o.from === name && !o.freight;
      const q = trains.filter(here).sort((a, b) => a.queuedAt - b.queuedAt);
      const t = q.find(o => !o.target) || q[0];
      if (t) onTrainClick(t);
      else toast("Aucun train en attente à " + p.label);
    });
    // repère de sortie pour l'effet « validé » : nom + géométrie de la voie
    portalUI[name] = { text: tt, cy: p.cy, side: p.side, px: p.x, edge, nameX: nameCx };
  }
}

// « Validé » : quand un convoi sort et glisse sous le nom de sa destination,
// le nom s'allume à pleine couleur et un fin liséré file le long de la voie
// vers le bord, puis s'estompe.
function validatePortal(name) {
  const u = portalUI && portalUI[name];
  if (!u) return;
  u.text.classList.add("valid");
  clearTimeout(u._t); u._t = setTimeout(() => u.text.classList.remove("valid"), 900);
  const c = DEST_COLOR[name];
  const seg = 64, dir = u.side === "L" ? -1 : 1;
  const ln = el("line", {
    x1: u.px, y1: u.cy, x2: u.px + dir * seg, y2: u.cy, class: "portal-sweep"
  }, gFx);
  ln.style.stroke = c; ln.style.strokeWidth = 4; ln.style.strokeLinecap = "round";
  ln.style.filter = "drop-shadow(0 0 6px " + c + ")";
  // reflow puis animation : le liséré file vers le bord en s'effaçant
  ln.getBoundingClientRect();
  ln.style.transform = "translateX(" + ((u.edge - u.px) + "px") + ")";
  ln.style.opacity = "0";
  setTimeout(() => ln.remove(), 650);
}

// Frise glissante : fenêtre de -4 à +19 minutes autour de l'heure courante.
// Les pastilles défilent de droite à gauche et sortent par la gauche.
const TL_PAST = 4, TL_SPAN = 23;
function buildTimeline() {
  const tl = document.getElementById("timeline");
  if (!tl) return; // frise supprimée du HUD : plus rien à construire
  tl.innerHTML = "";
  const now = document.createElement("div");
  now.className = "tl-now";
  now.style.left = (3 + TL_PAST / TL_SPAN * 92) + "%";
  tl.appendChild(now);
  trains.forEach((t, i) => {
    const c = t.freight ? "#8f98a8" : DEST_COLOR[t.to];
    const d = document.createElement("div");
    d.className = "tl-train" + (i % 2 ? " alt" : ""); // deux rangées en quinconce
    d.id = "tl-" + t.id;
    d.style.setProperty("--c", c);
    d.innerHTML = '<div class="tl-dot" style="background:' + c + '"></div><span class="tl-time">' + fmt(t.arr) + '</span>';
    tl.appendChild(d);
  });
  updateTimeline();
}
function updateTimeline() {
  for (const t of trains) {
    const d = document.getElementById("tl-" + t.id);
    if (!d) continue;
    const rel = t.arr - gameMin;
    if (rel < -TL_PAST || rel > TL_SPAN - TL_PAST) { d.style.display = "none"; continue; }
    d.style.display = "";
    d.style.left = (3 + (rel + TL_PAST) / TL_SPAN * 92) + "%";
  }
}

// ------------------------------------------------------------------
// Sons : petites signatures synthétisées (WebAudio), aucun fichier.
// Volume bas — ambiance de poste d'aiguillage, pas de fanfare.
// ------------------------------------------------------------------
let audioCtx = null;
let muted = getMuted(); // hydraté au démarrage depuis store.js (loadStore)
function ensureAudio() {
  if (audioCtx) { if (audioCtx.state === "suspended") audioCtx.resume(); return; }
  try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); }
  catch (e) { audioCtx = null; }
}
function playTone(freq, t0, dur, type, vol) {
  if (muted || !audioCtx) return;
  const o = audioCtx.createOscillator(), g = audioCtx.createGain();
  o.type = type || "sine"; o.frequency.value = freq;
  const at = audioCtx.currentTime + t0;
  g.gain.setValueAtTime(0.0001, at);
  g.gain.linearRampToValueAtTime(vol || 0.05, at + 0.02);
  g.gain.exponentialRampToValueAtTime(0.0001, at + dur);
  o.connect(g); g.connect(audioCtx.destination);
  o.start(at); o.stop(at + dur + 0.05);
}
const SND = {
  announce() { playTone(830, 0, 0.12); playTone(1108, 0.13, 0.2); },
  freight()  { playTone(98, 0, 0.55, "sawtooth", 0.045); playTone(147, 0, 0.55, "sawtooth", 0.03); },
  depart()   { playTone(1244, 0, 0.08, "triangle"); playTone(1661, 0.09, 0.13, "triangle"); },
  incident() { playTone(622, 0, 0.16, "square", 0.03); playTone(466, 0.18, 0.24, "square", 0.03); },
  end()      { playTone(659, 0, 0.12); playTone(830, 0.13, 0.12); playTone(988, 0.26, 0.3); }
};

// Jeu 100 % visuel : plus de bande d'info ni de message texte. toast() est
// conservé (encore appelé un peu partout) mais ne fait plus rien — l'action se
// lit sur le plan : quai barré pour une fermeture, convoi qui refoule, etc.
function toast(_msg, _ms) { /* désactivé — feedback purement visuel */ }
function flashAt(pt) {
  const c = el("circle", { cx: pt.x, cy: pt.y, r: 6, class: "conflict-ring" }, gFx);
  setTimeout(() => c.remove(), 900);
}

function fmt(min) {
  const m = Math.max(0, Math.floor(min));
  const h = 7 + Math.floor(m / 60);
  return String(h).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
}
function trainNode(t) {
  const g = el("g", { class: "train" }, gQueue);
  const c = t.freight ? "#8f98a8" : DEST_COLOR[t.to];
  t.carEls = [];
  t.maskEls = []; // masques « vide » : largeur pilotée par l'embarquement à quai
  for (let i = 0; i < t.cars; i++) {
    const car = el("g", {}, g);
    // zone de clic généreuse (invisible) : indispensable au doigt
    el("rect", { x: -CAR_SPACING / 2 - 4, y: -26, width: CAR_SPACING + 8, height: 52, fill: "transparent" }, car);
    // hauteur (verticale) grossie sur mobile ; la longueur CAR_LEN reste fixe
    // pour ne pas empiéter sur l'espacement (physique du gril)
    const bh = (i === 0 ? 20 : 16) * UIK;
    const body = el("rect", {
      x: -CAR_LEN / 2, y: -bh / 2,
      width: CAR_LEN, height: bh, rx: (i === 0 ? 8 : 5) * UIK,
      class: "train-body"
    }, car);
    body.style.fill = c; body.style.color = c;
    if (i > 0) body.style.opacity = "0.72";
    // Masque « vide » posé PAR-DESSUS la caisse, ancré au bord queue (-x).
    // Largeur 0 par défaut (wagon plein) ; l'embarquement la fait varier.
    const mask = el("rect", {
      x: -CAR_LEN / 2, y: -bh / 2, width: 0, height: bh,
      rx: (i === 0 ? 8 : 5) * UIK, class: "board-mask"
    }, car);
    t.maskEls.push(mask);
    if (i === 0) {
      const lbl = el("text", { x: 0, y: 0.5, class: "train-label" }, car);
      lbl.textContent = t.freight ? "F" : DEST_ABBR[t.to];
      lbl.style.fontSize = (12 * UIK) + "px";
    }
    t.carEls.push(car);
  }
  // Badge au-dessus de la loco : heure de départ, puis retard qui file en rouge.
  // Placé dans le calque du dessus (gBadges) pour toujours passer au-dessus des
  // libellés de portail ; il suit le train par transform en coordonnées absolues.
  const badge = el("g", { class: "badge", visibility: "hidden" }, gBadges);
  t.badgeRect = el("rect", { x: -36 * UIK, y: -11 * UIK, width: 72 * UIK, height: 20 * UIK, rx: 6 * UIK }, badge);
  t.badgeRect.style.fill = "rgba(14,20,32,.88)";
  t.badgeText = el("text", { y: 0.5 * UIK }, badge);
  t.badgeText.style.fontSize = (12 * UIK) + "px";
  t.badgeEl = badge;
  g.addEventListener("click", ev => { ev.stopPropagation(); onTrainClick(t); });
  return g;
}
// Point à l'abscisse curviligne s (extrapole avant 0 et après len : indispensable
// pour faire entrer/sortir les wagons proprement par les portails)
function pathPoint(path, s) {
  const pts = path.pts, cum = path.cum, L = path.len;
  const sc = Math.min(Math.max(s, 0), L);
  let i = 0;
  while (i < cum.length - 2 && cum[i + 1] < sc) i++;
  const segLen = cum[i + 1] - cum[i] || 1;
  const f = (sc - cum[i]) / segLen;
  const dx = (pts[i + 1].x - pts[i].x) / segLen;
  const dy = (pts[i + 1].y - pts[i].y) / segLen;
  const over = s - sc;
  const x = pts[i].x + (pts[i + 1].x - pts[i].x) * f + dx * over;
  const y = pts[i].y + (pts[i + 1].y - pts[i].y) * f + dy * over;
  let ang = Math.atan2(dy, dx) * 180 / Math.PI;
  if (ang > 90) ang -= 180; if (ang < -90) ang += 180;
  return { x, y, ang };
}
// Profil de vitesse trapézoïdal : démarrage et freinage progressifs.
// u : fraction du temps écoulé ; ta/td : durées (fractions) d'accélération
// et de freinage. Retourne la fraction du chemin parcourue.
function easeRun(u, ta, td) {
  u = Math.min(Math.max(u, 0), 1);
  const v = 1 / (1 - ta / 2 - td / 2);
  if (u < ta) return v * u * u / (2 * ta);
  if (u > 1 - td) return 1 - v * (1 - u) * (1 - u) / (2 * td);
  return v * (ta / 2 + (u - ta));
}
// Portion de chemin entre deux abscisses (pour dessiner la route restante)
function slicePts(path, sFrom, sTo) {
  const a = Math.max(0, Math.min(sFrom, path.len));
  const b = Math.max(a, Math.min(sTo, path.len));
  const pts = [pathPoint(path, a)];
  for (let i = 0; i < path.pts.length; i++)
    if (path.cum[i] > a && path.cum[i] < b) pts.push(path.pts[i]);
  pts.push(pathPoint(path, b));
  return pts;
}
function setRouteD(pathId, pts) {
  const p = document.getElementById("route-" + pathId.replace(":", "-"));
  if (p) p.setAttribute("d", pathD(pts));
}
// headS : abscisse de la loco ; tailDir : +1/-1 selon le côté où traînent les wagons
function placeTrain(t, pathId, headS, tailDir) {
  const path = paths[pathId];
  for (let i = 0; i < t.cars; i++) {
    const p = pathPoint(path, headS + tailDir * i * CAR_SPACING);
    if (i === 0) t.headPos = { x: p.x, y: p.y };
    t.carEls[i].setAttribute("transform",
      "translate(" + p.x.toFixed(1) + " " + p.y.toFixed(1) + ") rotate(" + p.ang.toFixed(1) + ")");
  }
}
// File d'attente sur la voie d'approche : le convoi apparaît au bord de la
// carte, suit le tracé (droite puis biais) et décélère jusqu'à son point
// d'arrêt juste avant la jonction. Les suivants patientent derrière,
// hors carte s'il le faut. t.qs = abscisse curviligne de la loco.
function placeQueue(t, dtMin) {
  const queue = trains.filter(o =>
    (o.state === "waiting" || o.state === "approaching") && o.from === t.from)
    .sort((a, b) => a.queuedAt - b.queuedAt);
  const idx = queue.indexOf(t);
  const ap = APPROACH[t.from];
  // la loco se poste dans l'amorce de la courbe de raccordement : bien
  // visible sur la carte, mais encore nettement sous la voie des départs
  let sTarget = ap.len - 85;
  for (let k = 0; k < idx; k++) sTarget -= trainLen(queue[k]) + 14;
  // jamais plus loin que la queue du convoi qui précède : le suiveur
  // freine derrière lui et avance en accordéon
  const ahead = queue[idx - 1];
  if (ahead && ahead.qs != null)
    sTarget = Math.min(sTarget, ahead.qs - trainLen(ahead) - 14);
  // idem derrière un train du même portail qui vient d'obtenir sa voie :
  // tant que sa queue traîne sur la voie d'approche, on reste derrière
  for (const o of trains) {
    if (o === t || o.from !== t.from) continue;
    if (o.state !== "movingIn" && o.state !== "movingThrough") continue;
    const occ = occupiedSpan(o, o.entryPath);
    if (occ) sTarget = Math.min(sTarget, ap.len + occ.lo - 44);
  }
  t.badgeLift = idx % 2 ? 24 * UIK : 0; // badges en quinconce dans la file
  if (t.qs == null) {
    t.qs = Math.min(-20, sTarget - 40); // caché hors carte
    t.settled = false;
  }
  const dist = sTarget - t.qs;
  const cap = 300 * dtMin; // vitesse d'approche (px / min de jeu)
  // freinage court : pleine vitesse jusqu'à 50 px de la cible
  const step = Math.min(Math.abs(dist),
    Math.max(cap * 0.3, cap * Math.min(1, Math.abs(dist) / 50)));
  t.qs += Math.sign(dist) * step;
  if (Math.abs(sTarget - t.qs) < 3) t.settled = true; // à l'arrêt : badge visible
  for (let i = 0; i < t.cars; i++) {
    const pos = pathPoint(ap, t.qs - i * CAR_SPACING);
    if (i === 0) t.headPos = { x: pos.x, y: pos.y };
    t.carEls[i].setAttribute("transform",
      "translate(" + pos.x.toFixed(1) + " " + pos.y.toFixed(1) + ") rotate(" + pos.ang.toFixed(1) + ")");
  }
}
// Sortie de gare : au-delà du portail, le convoi file wagon par wagon
// sur la voie de départ (celle du haut) vers le bord de la carte
function placeExit(t, pathId, headS) {
  const path = paths[pathId];
  const dep = DEPART[t.exitTo ?? t.to];
  for (let i = 0; i < t.cars; i++) {
    const s = headS + i * CAR_SPACING;
    const pos = s >= 0 ? pathPoint(path, s) : pathPoint(dep, -s);
    if (i === 0) t.headPos = { x: pos.x, y: pos.y };
    t.carEls[i].setAttribute("transform",
      "translate(" + pos.x.toFixed(1) + " " + pos.y.toFixed(1) + ") rotate(" + pos.ang.toFixed(1) + ")");
  }
}
// Entrée en gare : en amont du point de convergence (abscisse négative),
// les wagons suivent la voie d'approche (celle du bas), raccord compris
function placeEntry(t, pathId, headS) {
  const path = paths[pathId];
  const ap = APPROACH[t.from];
  for (let i = 0; i < t.cars; i++) {
    const s = headS - i * CAR_SPACING;
    const pos = s >= 0 ? pathPoint(path, s) : pathPoint(ap, ap.len + s);
    if (i === 0) t.headPos = { x: pos.x, y: pos.y };
    t.carEls[i].setAttribute("transform",
      "translate(" + pos.x.toFixed(1) + " " + pos.y.toFixed(1) + ") rotate(" + pos.ang.toFixed(1) + ")");
  }
}
function updateBadge(t) {
  // le badge apparaît dès que le train s'est immobilisé à son point d'attente
  if (t.freight || !t.badgeEl || !t.headPos ||
      (t.state === "approaching" && !t.settled) ||
      t.state === "movingOut" || t.state === "done") {
    if (t.badgeEl) t.badgeEl.setAttribute("visibility", "hidden");
    return;
  }
  const late = gameMin - t.dep;
  let txt, color;
  // le retard ne s'affiche qu'une fois la minute entière écoulée
  if (late >= 1) { txt = "+" + Math.floor(late) + " min"; color = "var(--red)"; }
  else if (late > -3) { txt = "dép " + fmt(t.dep); color = "#f5b23c"; }
  else { txt = "dép " + fmt(t.dep); color = "var(--green)"; }
  t.badgeEl.classList.toggle("late", late >= 1);
  t.badgeText.textContent = txt;
  t.badgeText.style.fill = color;
  t.badgeRect.style.stroke = color;
  t.badgeEl.setAttribute("visibility", "visible");
  t.badgeEl.setAttribute("transform",
    "translate(" + t.headPos.x.toFixed(1) + " " +
    (t.headPos.y - 30 * UIK - (t.badgeLift || 0)).toFixed(1) + ")");
}
// Embarquement à quai : pendant l'arrêt (dwell), le convoi se « remplit » comme
// une jauge de batterie horizontale — la partie pleine (couleur vive) avance de
// la loco vers le dernier wagon, la partie vide (masque sombre) recule, à mesure
// qu'on approche de l'heure de départ. Plein = prêt à repartir. Hors arrêt, le
// masque disparaît (wagons pleins, aspect normal).
function updateBoarding(t) {
  if (t.freight || !t.maskEls) return;
  if (t.state !== "dwell") {
    for (const m of t.maskEls) m.setAttribute("width", 0);
    return;
  }
  // fin d'arrêt = départ prévu si une sortie existe, sinon simple arrêt minimum
  const hasOut = !!paths["out:" + t.to + ":" + t.platform];
  const end = hasOut ? Math.max(t.dep, t.actualArr + MIN_DWELL)
                     : t.actualArr + MIN_DWELL;
  const denom = end - t.actualArr;
  const p = denom > 0 ? Math.min(1, Math.max(0, (gameMin - t.actualArr) / denom)) : 1;
  const n = t.maskEls.length;
  // Sens de la tête à l'écran : les caisses gardent leur x local orienté vers la
  // droite (rotation bridée à l'endroit), mais selon le portail d'origine la tête
  // du convoi est à droite (s croissant vers la droite) ou à gauche. On lit le
  // signe du tangent au point d'arrêt pour placer le masque « vide » côté queue.
  const pth = paths[t.entryPath];
  let headRight = true;
  if (pth) {
    const s1 = Math.min(t.stopS, pth.len), s0 = Math.max(0, s1 - 2);
    headRight = pathPoint(pth, s1).x - pathPoint(pth, s0).x >= 0;
  }
  // p balaie tout le convoi : n·p wagons pleins ; le wagon courant se remplit
  // partiellement, du côté tête vers le côté queue, en continuité avec le voisin.
  for (let i = 0; i < n; i++) {
    const frac = Math.min(1, Math.max(0, p * n - i)); // la tête se remplit d'abord
    const w = (1 - frac) * CAR_LEN;                    // portion « vide » (côté queue)
    const m = t.maskEls[i];
    // vide côté queue : à gauche (-x) si la tête est à droite, sinon à droite (+x)
    m.setAttribute("x", (headRight ? -CAR_LEN / 2 : CAR_LEN / 2 - w).toFixed(2));
    m.setAttribute("width", w.toFixed(2));
  }
}
