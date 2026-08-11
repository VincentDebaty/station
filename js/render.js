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
// Facteur de la file miniature : elle se loge entre le nom de la ville et le
// bord de carte, une largeur FIXE et étroite. On la grossit donc moins que le
// reste sur tactile — sinon deux convois symboliques n'y tiendraient plus.
const QK = Math.min(UIK, 1.25);
// Bords du cadrage courant (renseignés par drawStatic) : la file miniature s'y
// borne, pour rester dans le champ quel que soit le gabarit de la gare.
let VIEW_X1 = 0, VIEW_X2 = 1400;

function el(tag, attrs, parent) {
  const e = document.createElementNS(SVGNS, tag);
  for (const [k, v] of Object.entries(attrs || {})) e.setAttribute(k, v);
  if (parent) parent.appendChild(e);
  return e;
}

function drawStatic() {
  board.innerHTML = "";
  // Cadrage : on encadre la bande réellement dessinée avec DEUX marges nommées,
  // les mêmes pour toutes les gares. En haut, CLOCK_ROOM réserve la place du
  // cadre horloge, qui flotte au centre et ne doit jamais recouvrir le badge
  // d'heure du quai du haut ; auparavant le cadrage partait toujours de y = 0,
  // donc cette réserve variait du simple au double selon la hauteur du gril
  // (trop rase sur une grande gare, gâchée sur une petite). En bas, BOTTOM_ROOM
  // ajoute une vraie respiration SOUS la voie d'approche de la ville la plus
  // basse, qui frôlait le bord. On rogne aussi, en gare terminus (tous les
  // portails du même côté), le flanc vide côté butoirs : sans ce rognage le
  // réseau se tasserait sur une moitié de l'écran, l'autre restant noire.
  // Aucune coordonnée du réseau n'est touchée — seul le cadrage change, donc la
  // difficulté reste identique.
  const CLOCK_ROOM = 140, BOTTOM_ROOM = 30;
  const sides = new Set(Object.values(PORTALS).map(p => p.side));
  const only = sides.size === 1 ? [...sides][0] : null;
  const cys = [...PLATFORMS.map(q => q.cy), ...Object.values(PORTALS).map(p => p.cy)];
  // haut : badge d'heure posé au-dessus d'un convoi (30 + hauteur/2, ×UIK)
  const yTop = Math.min(...cys) - 44 * UIK - CLOCK_ROOM;
  // bas : voie d'approche (cy + 36) + demi-caisse de wagon
  const yBot = Math.max(...cys) + 36 + 14 * UIK + BOTTOM_ROOM;
  const xL = only === "R" ? PLAT_X1 - 55 : 0;
  const xR = only === "L" ? PLAT_X2 + 55 : 1400;
  board.setAttribute("viewBox", `${xL} ${yTop} ${xR - xL} ${yBot - yTop}`);
  VIEW_X1 = xL; VIEW_X2 = xR;
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
    const t = el("path", { d: m.d, class: "track mesh", "data-beam": m.portal }, gTracks);
    t.style.stroke = DEST_COLOR[m.portal];
    t.style.opacity = "0.5";
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
    // Liseré « promis » : un convoi encore dehors a déjà choisi ce quai. Il lui
    // faut son PROPRE tracé — un rect n'a qu'un seul liseré, or un quai peut
    // être occupé PAR un convoi et promis À un autre, et les deux doivent se
    // lire en même temps. Posé en retrait, à la couleur du convoi attendu.
    el("rect", {
      x: PLAT_X1 + 5, y: q.cy - PLAT_H / 2 + 5,
      width: PLAT_X2 - PLAT_X1 - 10, height: PLAT_H - 10,
      rx: 6, class: "claim", "pointer-events": "none"
    }, pg);
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
  // écart vertical entre villes voisines d'un même côté : sert à borner l'offset
  // du libellé pour qu'il reste TOUJOURS collé à SA ligne (jamais à celle du
  // dessus), même sur tactile (UIK=1.5) ou quand les villes sont nombreuses.
  const sideCys = {};
  for (const q of Object.values(PORTALS)) (sideCys[q.side] = sideCys[q.side] || []).push(q.cy);
  for (const [name, p] of Object.entries(PORTALS)) {
    const c = DEST_COLOR[name];
    const edge = p.side === "L" ? -EDGE_RUN : 1400 + EDGE_RUN;   // point de fuite = bord écran
    const lnOut = el("line", { x1: edge, y1: p.cy, x2: p.x, y2: p.cy, class: "track", "data-beam": name }, gTracks);
    lnOut.style.stroke = c; lnOut.style.opacity = "0.38";
    const lnIn = el("path", { d: pathD(APPROACH[name].pts), class: "track", "data-beam": name }, gTracks);
    lnIn.style.stroke = c; lnIn.style.opacity = "0.38";
    // point de convergence marqué à la couleur de la ville
    const cvg = el("circle", { cx: p.x, cy: p.cy, r: 5, "pointer-events": "none", "data-beam": name }, gTracks);
    cvg.style.fill = c; cvg.style.opacity = "0.85";
    const grp = el("g", { style: "cursor:pointer" }, gPortals);
    // nom centré au-dessus de l'AIGUILLAGE (point de convergence), juste au-dessus
    // de la voie — le convoi qui part glisse dessous en quittant le faisceau.
    const tw = (22 + p.label.length * 10) * UIK;
    // offset au-dessus de la voie : borné à 40 % de l'écart à la ville voisine
    // (< 50 % ⇒ le nom penche toujours vers SA ligne), plafonné au confort
    // tactile. L'écart se lit sur la géométrie réelle : il dépend désormais de
    // la hauteur du gril, pas d'un écartement fixe.
    const near = sideCys[p.side].filter(y => y !== p.cy).map(y => Math.abs(y - p.cy));
    const gap = near.length ? Math.min(...near) : Infinity;
    const nameY = p.cy - Math.min(34 * UIK, gap * 0.40);
    const nameCx = p.x;
    // zone de clic du nom (sélectionne le 1er train en file du portail). Elle
    // reste STRICTEMENT au-dessus de la voie : le nom est posé au ras de
    // l'aiguillage, or les convois y stationnent — une zone qui descendrait sur
    // la voie volerait les clics destinés aux trains (il fallait « s'y reprendre »).
    el("rect", {
      x: nameCx - Math.max(50, tw / 2), y: nameY - 20 * UIK,
      width: Math.max(100, tw), height: 34 * UIK,
      fill: "transparent"
    }, grp);
    const tt = el("text", { x: nameCx, y: nameY, class: "portal-name", "data-beam": name }, grp);
    tt.textContent = p.label;
    tt.style.fill = c; tt.style.color = c; // color : currentColor du halo de validation
    tt.style.fontSize = (15 * UIK) + "px";
    grp.addEventListener("click", ev => {
      ev.stopPropagation();
      selectNextAtPortal(name);
    });
    // File d'attente en réduction (cf. updateQueueUI), posée dans le couloir
    // vide entre la voie des départs et celle des arrivées. Dans gBadges : elle
    // survole le maillage, comme les badges d'heure.
    const strip = el("g", { class: "qstrip", style: "cursor:pointer" }, gBadges);
    strip.addEventListener("click", ev => {
      ev.stopPropagation();
      selectNextAtPortal(name);
    });
    // repère de sortie pour l'effet « validé » : nom + géométrie de la voie
    portalUI[name] = {
      text: tt, cy: p.cy, side: p.side, px: p.x, edge, nameX: nameCx,
      nameY, nameW: tw, strip, stripSig: null
    };
  }
}

// Prochain convoi en attente à un portail : celui qui n'a pas encore de quai,
// à défaut le premier de la file. Partagé par le nom de la ville et par la file
// miniature — deux cibles pour un même geste, sur un plan où la file elle-même
// est en grande partie hors champ.
function selectNextAtPortal(name) {
  // Le fret est exclu du CHOIX (il s'aiguille seul) mais reste dans la file
  // affichée : le tap sur la ville désigne le prochain convoi à décider.
  const q = trains
    .filter(o => (o.state === "waiting" || o.state === "approaching") &&
                 o.from === name && !o.freight)
    .sort((a, b) => a.queuedAt - b.queuedAt);
  const t = q.find(o => !o.target) || q[0];
  if (t) { onTrainClick(t); return; }
  // Personne en attente : le tap n'est pas mort pour autant — il l'annonce.
  const u = portalUI[name];
  if (u) flashLabel({ x: u.nameX, y: u.nameY }, "Aucun train en attente", "info");
}

// ------------------------------------------------------------------
// File d'attente en réduction
// ------------------------------------------------------------------
// La voie d'approche ne mesure qu'environ 150 px À L'INTÉRIEUR du cadrage (du
// bord au point de convergence), alors qu'un convoi de 7 wagons en fait 240 :
// le premier train n'entre dans le champ que par le nez, et le DEUXIÈME
// stationne entièrement hors carte. Le joueur ne pouvait donc savoir ni combien
// de convois patientaient, ni pour quelles villes — or c'est exactement ce dont
// dépend la seule vraie décision du jeu : garder un quai libre ou non.
// On dessine donc la file en réduction : un convoi symbolique par train en
// attente, à la couleur de sa destination et à sa vraie longueur (un bloc par
// wagon, motrice tournée vers la gare), rangés du plus proche de la gorge au
// plus lointain — même sens que la vraie file, qui s'étire vers le bord.
// Un convoi DÉJÀ aiguillé s'estompe : reste en pleine lumière ce qui demande
// encore une décision. Un convoi dont le retard court porte un cerne rouge.
//
// PLACEMENT : sur la ligne du NOM de la ville, entre lui et le bord de carte.
// C'est la seule bande dont le plan garantisse qu'elle reste dégagée (nameY est
// borné à 40 % de l'écart au portail voisin, justement pour que le nom ne
// touche jamais la voie du dessus). Le couloir entre la voie des départs et
// celle des arrivées, lui, ne fait que 16 px — 6 px sur tactile, où les caisses
// sont grossies : la file s'y superposait au convoi de tête.
// La largeur, elle, est comptée : on ne pose que ce qui tient avant le nom, le
// reste passe en « +N ».
const Q_CAR = 3, Q_GAP = 1.2, Q_SEP = 7, Q_MAX = 4; // unités ×QK
function updateQueueUI() {
  if (!portalUI || !trains) return;
  for (const [name, u] of Object.entries(portalUI)) {
    if (!u.strip) continue;
    const q = trains
      .filter(o => o.from === name &&
                   (o.state === "waiting" || o.state === "approaching"))
      .sort((a, b) => a.queuedAt - b.queuedAt);
    // Un seul convoi : sa tête et son badge d'heure sont à l'écran, la
    // miniature ferait doublon. Elle n'apparaît que lorsque la file déborde.
    const show = q.length >= 2;
    // Reconstruction seulement quand le CONTENU change (la file est stable des
    // minutes durant) : sinon on redessinerait tout le calque à chaque frame.
    const sig = show ? q.map(t => t.id + ((t.target || t.freight) ? "+" : "-") +
                                  (lateness(t, gameMin) >= 1 ? "!" : "")).join(",") : "";
    if (sig === u.stripSig) continue;
    u.stripSig = sig;
    while (u.strip.firstChild) u.strip.removeChild(u.strip.firstChild);
    if (!show) continue;

    const car = Q_CAR * QK, gap = Q_GAP * QK, sep = Q_SEP * QK;
    const moreW = 16 * QK;                    // largeur réservée au « +N »
    // Place disponible entre le bord de carte et le nom de la ville.
    const room = u.side === "L"
      ? (u.nameX - u.nameW / 2 - 6) - (VIEW_X1 + 6)
      : (VIEW_X2 - 6) - (u.nameX + u.nameW / 2 + 6);
    if (room < moreW + 4) continue;           // nom trop large : pas la place, on renonce
    // On empile tant que ça tient, en gardant de quoi écrire le « +N » s'il
    // reste des convois à annoncer — mieux vaut deux convois lisibles et un
    // compte juste que quatre blocs illisibles.
    const cells = [];
    let W = 0;
    for (const t of q) {
      const w = t.cars * (car + gap) - gap;
      const need = W + (cells.length ? sep : 0) + w;
      const rest = q.length - cells.length - 1;      // convois encore non posés
      if (cells.length >= Q_MAX || need + (rest > 0 ? sep + moreW : 0) > room) break;
      W = need;
      cells.push({ t, w });
    }
    const extra = q.length - cells.length;
    if (extra > 0) { W += (cells.length ? sep : 0) + moreW; cells.push({ t: null, w: moreW }); }
    // accrochée au nom de la ville, la file s'étirant vers le bord de carte
    const left = u.side === "L" ? u.nameX - u.nameW / 2 - 6 - W : u.nameX + u.nameW / 2 + 6;
    const yc = u.nameY;
    const hLoco = 9 * QK, hCar = 6.5 * QK;
    // Plaque de fond : détache les blocs du maillage teinté qu'ils peuvent
    // survoler, et fait lire la file comme UN objet plutôt que comme des points.
    el("rect", {
      x: left - 7, y: yc - hLoco / 2 - 5, width: W + 14, height: hLoco + 10,
      rx: (hLoco + 10) / 2, class: "qstrip-plate"
    }, u.strip);

    let s = 0;
    for (const c of cells) {
      // index croissant = plus loin de la gare : vers le bord GAUCHE pour un
      // portail de gauche, vers le bord droit pour un portail de droite.
      const x = u.side === "L" ? left + W - s - c.w : left + s;
      s += c.w + sep;
      if (!c.t) {
        const tx = el("text", { x: x + c.w / 2, y: yc, class: "qstrip-more" }, u.strip);
        tx.style.fontSize = (11 * QK) + "px";
        tx.textContent = "+" + extra;
        continue;
      }
      // estompé = plus rien à décider : déjà aiguillé, ou fret (jamais à aiguiller)
      const g = el("g", { class: "qtrain" + ((c.t.target || c.t.freight) ? " routed" : "") }, u.strip);
      const col = DEST_COLOR[c.t.to];
      for (let i = 0; i < c.t.cars; i++) {
        // la motrice regarde la gare : dernier bloc côté gorge
        const loco = u.side === "L" ? i === c.t.cars - 1 : i === 0;
        const h = loco ? hLoco : hCar;
        const r = el("rect", {
          x: x + i * (car + gap), y: yc - h / 2,
          width: car, height: h, rx: Math.min(1.6 * QK, car / 2)
        }, g);
        // même code qu'en grand : un fret est gris, cerclé de la couleur de sa
        // destination — à cette taille le liseré ne tient que sur la motrice,
        // les wagons restent des blocs gris pleins
        r.style.fill = c.t.freight ? FREIGHT_COLOR : col;
        if (c.t.freight && loco) { r.style.stroke = col; r.style.strokeWidth = 1.1 * QK; }
      }
      if (lateness(c.t, gameMin) >= 1)
        el("rect", {
          x: x - 3, y: yc - hLoco / 2 - 3, width: c.w + 6, height: hLoco + 6,
          rx: 4, class: "qtrain-late"
        }, g);
    }
    // Cible de clic : toute la bande, même geste que le nom de la ville. Elle
    // reste dans la hauteur du nom — débordante vers le bas, elle volerait les
    // clics destinés aux convois de la voie des départs.
    el("rect", {
      x: left - 10, y: yc - 15 * QK, width: W + 20, height: 30 * QK,
      fill: "transparent", class: "qhit"
    }, u.strip);
  }
}

// Mise en avant du faisceau sélectionné : la ville d'origine du train choisi
// ressort un peu (les AUTRES liaisons restent pleinement visibles — on ne cache
// rien). name=null → repos.
function focusPortal(name) {
  const on = name != null;
  board.querySelectorAll("[data-beam]").forEach(elm => {
    const mine = elm.getAttribute("data-beam") === name;
    elm.classList.toggle("beam-lit", on && mine);
  });
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
    const c = DEST_COLOR[t.to];
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
  // Départ À L'HEURE : carillon ascendant qui MONTE avec la série (plafonné) —
  // plus la série est longue, plus la récompense sonore grimpe.
  onTime(n)  { const k = Math.min((n || 1) - 1, 7), base = 720 + k * 66;
               playTone(base, 0, 0.08, "triangle", 0.05);
               playTone(base * 1.5, 0.07, 0.14, "triangle", 0.045); },
  incident() { playTone(622, 0, 0.16, "square", 0.03); playTone(466, 0.18, 0.24, "square", 0.03); },
  end()      { playTone(659, 0, 0.12); playTone(830, 0.13, 0.12); playTone(988, 0.26, 0.3); },
  // Service PARFAIT : petite fanfare montante, plus riche que end().
  perfect()  { [523, 659, 784, 1047, 1319].forEach((f, i) => playTone(f, i * 0.10, 0.24, "triangle", 0.05)); }
};

// Jeu 100 % visuel : plus de bande d'info ni de message texte. toast() est
// conservé (encore appelé un peu partout) mais ne fait plus rien — l'action se
// lit sur le plan : quai barré pour une fermeture, convoi qui refoule, etc.
function toast(_msg, _ms) { /* désactivé — feedback purement visuel */ }
function flashAt(pt) {
  const c = el("circle", { cx: pt.x, cy: pt.y, r: 6, class: "conflict-ring" }, gFx);
  setTimeout(() => c.remove(), 900);
}
// Pilule-éclair : un court message posé sur le plan (même langage visuel que les
// badges et la pastille de fermeture), qui monte et s'efface. Sert à rendre
// lisibles les retours autrefois muets — tap sur un fret, quai refusé, refoulement.
// kind : "warn" (rouge) pour une erreur/sanction, "info" (teal) pour un simple rappel.
function flashLabel(pt, text, kind) {
  if (!gFx || !pt) return;
  const cls = kind === "warn" ? "warn" : kind === "ok" ? "ok" : kind === "wait" ? "wait" : "info";
  const g = el("g", { class: "flash-label " + cls }, gFx);
  const rect = el("rect", { rx: 7 * UIK }, g);           // posé d'abord : sous le texte
  const txt = el("text", { x: pt.x, y: pt.y }, g);
  txt.style.fontSize = (13 * UIK) + "px";
  txt.textContent = text;
  let w; try { w = txt.getBBox().width; } catch (e) { w = text.length * 7 * UIK; }
  const padX = 11 * UIK, h = 23 * UIK;
  rect.setAttribute("x", pt.x - w / 2 - padX);
  rect.setAttribute("y", pt.y - h / 2);
  rect.setAttribute("width", w + 2 * padX);
  rect.setAttribute("height", h);
  setTimeout(() => g.remove(), 1100);
}

// Départ À L'HEURE : plutôt qu'un libellé, un petit éclat vert posé sur la tête
// du convoi — un anneau qui s'ouvre + une coche qui se dessine. Au-delà du 1er
// de la série, des étincelles fusent et s'intensifient avec le combo (écho
// visuel du carillon montant SND.onTime).
function flashOnTime(pt, streak) {
  if (!gFx || !pt) return;
  const n = Math.min(streak || 1, 6);
  const g = el("g", { class: "ontime" }, gFx);
  el("circle", { cx: pt.x, cy: pt.y, r: 6, class: "ontime-ring" }, g);
  // Coche centrée sur la tête ; pathLength=1 pour la faire « s'écrire » via le dash
  const s = 9 * UIK * (1 + (n - 1) * 0.08);   // grandit un peu avec la série
  el("path", {
    d: "M " + (pt.x - s) + " " + pt.y +
       " l " + (s * 0.72).toFixed(1) + " " + (s * 0.72).toFixed(1) +
       " l " + (s * 1.35).toFixed(1) + " " + (-s * 1.5).toFixed(1),
    pathLength: 1, class: "ontime-check"
  }, g);
  // Étincelles en couronne à partir de la 2e série (nombre croissant, plafonné)
  if (n >= 2) {
    const sparks = Math.min(n + 1, 7);
    for (let i = 0; i < sparks; i++) {
      const a = (i / sparks) * Math.PI * 2;
      const sp = el("circle", { cx: pt.x, cy: pt.y, r: 2.2 * UIK, class: "ontime-spark" }, g);
      sp.style.setProperty("--dx", (Math.cos(a) * 24 * UIK).toFixed(1) + "px");
      sp.style.setProperty("--dy", (Math.sin(a) * 24 * UIK).toFixed(1) + "px");
    }
  }
  setTimeout(() => g.remove(), 950);
}

function fmt(min) {
  const m = Math.max(0, Math.floor(min));
  const h = 7 + Math.floor(m / 60);
  return String(h).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
}
function trainNode(t) {
  const g = el("g", { class: "train" + (t.freight ? " freight" : "") }, gQueue);
  // Deux silhouettes franchement distinctes :
  //  · voyageurs — caisses PLEINES de la couleur de leur destination ;
  //  · fret      — caisses GRISES d'un bout à l'autre, CERCLÉES de cette même
  //    couleur (bordure épaisse + halo). Le convoi se lit donc « gris = fret »
  //    de loin, et sa destination se lit quand même au liseré.
  const c = DEST_COLOR[t.to];
  const carColor = () => t.freight ? FREIGHT_COLOR : c;
  t.carEls = [];
  t.maskEls = []; // masques « vide » : largeur pilotée par l'embarquement à quai
  for (let i = 0; i < t.cars; i++) {
    const car = el("g", {}, g);
    // hauteur (verticale) grossie sur mobile ; la longueur CAR_LEN reste fixe
    // pour ne pas empiéter sur l'espacement (physique du gril)
    const bh = (i === 0 ? CAR_H : CAR_H - 4) * UIK;
    // Halo d'état (sélection / voie occupée), dessiné EN PREMIER donc SOUS la
    // caisse : seule sa moitié extérieure se voit, d'où un dégradé qui rayonne
    // au lieu d'un cadre. Il est fait de traits concentriques de plus en plus
    // larges et transparents plutôt que d'un `filter: drop-shadow` : sur
    // iOS/Safari les halos filtrés d'un élément SVG ne s'affichent pas de façon
    // fiable (rien n'était visible sur iPhone). Seule l'opacité du groupe est
    // animée — c'est rendu partout. Épaisseurs ×UIK pour rester lisibles au doigt.
    const glow = el("g", { class: "state-ring" }, car);
    for (const [w, o] of [[16, 0.10], [10, 0.18], [5.5, 0.34], [2.5, 0.75]]) {
      const lay = el("rect", {
        x: -CAR_LEN / 2, y: -bh / 2, width: CAR_LEN, height: bh,
        rx: (i === 0 ? 8 : 5) * UIK
      }, glow);
      lay.style.strokeWidth = (w * UIK) + "px";
      lay.style.opacity = o;
    }
    // zone de clic généreuse (invisible) : indispensable au doigt. Hauteur
    // grossie sur tactile (×UIK) pour une cible confortable même sur petit écran.
    const hitH = 52 * UIK;
    el("rect", { x: -CAR_SPACING / 2 - 6, y: -hitH / 2, width: CAR_SPACING + 12, height: hitH, fill: "transparent" }, car);
    const body = el("rect", {
      x: -CAR_LEN / 2, y: -bh / 2,
      width: CAR_LEN, height: bh, rx: (i === 0 ? 8 : 5) * UIK,
      class: "train-body"
    }, car);
    const cc = carColor(i);
    // fill = la caisse ; color = le halo (currentColor) — toujours à la couleur
    // de la destination, y compris pour un fret dont la caisse est grise
    body.style.fill = cc; body.style.color = c;
    if (i > 0) body.style.opacity = "0.72";
    // Masque « vide » posé PAR-DESSUS la caisse, ancré au bord queue (-x).
    // Largeur 0 par défaut (wagon plein) ; l'embarquement la fait varier.
    const mask = el("rect", {
      x: -CAR_LEN / 2, y: -bh / 2, width: 0, height: bh,
      rx: (i === 0 ? 8 : 5) * UIK, class: "board-mask"
    }, car);
    t.maskEls.push(mask);
    // Contour persistant, posé PAR-DESSUS le masque : un wagon vide reste
    // visible (sa silhouette) même quand le masque l'assombrit entièrement.
    const outline = el("rect", {
      x: -CAR_LEN / 2, y: -bh / 2, width: CAR_LEN, height: bh,
      rx: (i === 0 ? 8 : 5) * UIK, class: "train-outline"
    }, car);
    outline.style.stroke = c;   // le liseré porte la destination, caisse grise comprise
    if (i === 0) {
      const lbl = el("text", { x: 0, y: 0.5, class: "train-label" }, car);
      // Même marquage pour tous, fret compris : la loco porte l'initiale de sa
      // destination. Ce qui distingue un fret, ce sont ses wagons gris et
      // l'absence d'heure de départ.
      lbl.textContent = DEST_ABBR[t.to];
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
  // Le badge d'heure, posé AU-DESSUS du convoi, est une cible naturelle : on le
  // rend cliquable et il sélectionne le train (les enfants tapent l'heure).
  badge.style.pointerEvents = "auto";
  badge.style.cursor = "pointer";
  badge.addEventListener("click", ev => { ev.stopPropagation(); onTrainClick(t); });
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
  // Le fret fait partie de la file comme n'importe quel convoi : il s'y range,
  // s'y fait doubler par personne, et retient ceux qui le suivent.
  const queue = trains.filter(o =>
    (o.state === "waiting" || o.state === "approaching") && o.from === t.from)
    .sort((a, b) => a.queuedAt - b.queuedAt);
  const idx = queue.indexOf(t);
  const ap = APPROACH[t.from];
  // Changement de gare : le réseau (APPROACH) est reconstruit avant que les
  // convois de la gare précédente aient disparu. Une frame peut donc arriver ici
  // avec un portail qui n'existe plus — on laisse simplement passer.
  if (!ap) return;
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
  // le badge apparaît dès que le train s'est immobilisé à son point d'attente.
  // Un fret n'en a jamais : il ne stationne pas, donc pas d'heure de départ —
  // et rien à tenir. Son seul enjeu est de dégager le gril.
  if (t.freight || !t.badgeEl || !t.headPos ||
      (t.state === "approaching" && !t.settled) ||
      t.wrongPlatform || // mauvais quai : le badge « dép HH:MM » serait trompeur
      t.state === "movingOut" || t.state === "done") {
    if (t.badgeEl) t.badgeEl.setAttribute("visibility", "hidden");
    return;
  }
  const late = lateness(t, gameMin);
  let txt, color;
  // le retard ne s'affiche qu'une fois la minute entière écoulée
  if (late >= 1) { txt = "+" + Math.floor(late) + " min"; color = "var(--red)"; }
  else if (late > -3) { txt = "dép " + fmt(t.dep); color = "#f5b23c"; }
  else { txt = "dép " + fmt(t.dep); color = "var(--green)"; }
  t.badgeEl.classList.toggle("late", late >= 1);
  // Retard qui court sur un convoi encore NON DÉMARRÉ (à l'arrêt sur la voie
  // d'approche, pas encore aiguillé vers un quai) : c'est le seul cas où le
  // joueur peut le régler à l'instant. Son retard clignote pour l'appeler à
  // l'œil, là où un train déjà en gare garde un badge rouge fixe.
  // Dès qu'il est SÉLECTIONNÉ, le clignotement s'arrête : l'appel a été
  // entendu, et deux pulsations désynchronisées (le cerne de sélection bat à
  // 1,1 s, le badge à 0,9 s) donneraient un scintillement brouillon.
  t.badgeEl.classList.toggle("late-idle",
    late >= 1 && selected !== t &&
    (t.state === "waiting" || t.state === "approaching"));
  t.badgeText.textContent = txt;
  t.badgeText.style.fill = color;
  t.badgeRect.style.stroke = color;
  t.badgeEl.setAttribute("visibility", "visible");
  t.badgeEl.setAttribute("transform",
    "translate(" + t.headPos.x.toFixed(1) + " " +
    (t.headPos.y - 30 * UIK - (t.badgeLift || 0)).toFixed(1) + ")");
}
// ------------------------------------------------------------------
// Signal d'arrêt : le petit feu rouge posé devant un convoi retenu
// ------------------------------------------------------------------
// Un train prêt à repartir dont la voie de sortie est prise ne doit pas rester
// muet — sinon son immobilité se lit comme un bug. Plutôt qu'une mention de
// texte (qui passe et qu'il faut lire), on plante un VRAI signal ferroviaire
// devant sa motrice, au bord du quai : mât, cible à deux feux, le rouge allumé
// et pulsé. Il reste tant que le convoi est retenu, et s'efface dès qu'il part.
function signalNode() {
  const g = el("g", { class: "hold-signal", "pointer-events": "none" }, gBadges);
  const k = UIK;
  el("rect", { x: -1.3 * k, y: -2 * k, width: 2.6 * k, height: 16 * k, rx: 1.3 * k,
    class: "sig-mast" }, g);                                  // mât planté au sol
  el("rect", { x: -7 * k, y: -22 * k, width: 14 * k, height: 21 * k, rx: 4 * k,
    class: "sig-head" }, g);                                  // cible
  el("circle", { cx: 0, cy: -16 * k, r: 3.6 * k, class: "sig-lamp sig-red" }, g);
  el("circle", { cx: 0, cy: -6.5 * k, r: 3.6 * k, class: "sig-lamp sig-green" }, g);
  return g;
}
// Voie libre : le signal ne s'éteint pas d'un coup — il PASSE AU VERT, le temps
// qu'on voie le convoi s'ébranler, puis s'efface dans la seconde. C'est ce qui
// transforme une disparition en explication : « c'est passé au vert, il part ».
function releaseSignal(g) {
  g.classList.add("clear");
  // On retire le nœud sur la FIN de l'animation (horloge d'animation du
  // navigateur) plutôt que sur un minuteur seul : un onglet en arrière-plan
  // bride setTimeout, et les signaux éteints s'accumulaient alors dans le DOM.
  // Le minuteur reste en filet, au cas où l'animation ne jouerait pas.
  g.addEventListener("animationend", e => { if (e.target === g) g.remove(); }, { once: true });
  setTimeout(() => g.remove(), 1200);
}
// DEUX immobilités à expliquer, un seul signal, toujours planté devant la
// motrice (côté nez) :
//  · à quai — prêt à repartir, mais la voie de sortie est prise ;
//  · sur la voie d'approche — un convoi qui ne peut pas encore s'engager :
//    itinéraire d'entrée occupé, quai pas encore dégagé, ou un train du même
//    portail devant lui (FIFO). Un convoi SANS quai attribué n'est pas
//    « bloqué » : il attend une décision du joueur, et c'est sa pulsation
//    « ready » qui le dit. Un FRET, lui, ne demande rien à personne : s'il est
//    encore en file, c'est qu'il est retenu — il a donc son feu.
// Le sens du nez se lit sur la tangente de la voie qu'il occupe.
function updateHoldSignal(t) {
  const atPlatform = !!t.holding && t.state === "dwell";
  const onApproach = t.state === "waiting" && !!t.settled &&
                     (t.target != null || t.freight);
  const on = (atPlatform || onApproach) && !!t.headPos;
  if (!on) {
    // le signal reste planté où il était (c'est du mobilier de voie, pas un
    // badge qui suit le train) : il vire au vert et s'efface tout seul
    if (t.signalEl) { releaseSignal(t.signalEl); t.signalEl = null; }
    return;
  }
  if (!t.signalEl) t.signalEl = signalNode();
  // abscisse du nez sur la voie occupée : point d'arrêt à quai, ou position
  // dans la file sur la voie d'approche
  const pth = atPlatform ? paths[t.entryPath] : APPROACH[t.from];
  const sHead = atPlatform ? Math.min(t.stopS ?? 0, pth ? pth.len : 0) : (t.qs ?? 0);
  let headRight = true;
  if (pth) {
    const s1 = sHead, s0 = s1 - 2;
    headRight = pathPoint(pth, s1).x - pathPoint(pth, s0).x >= 0;
  }
  // 22 px du centre de la loco : le mât tient PILE dans l'espace libre devant
  // son nez (demi-caisse 15 → il occupe 15..29), donc ni sur la caisse, ni sur
  // la queue du convoi qui précède dans la file (écart de 14 px, cf. placeQueue).
  // À quai, il tombe au ras du bord (STOP_MARGIN = 26).
  const dx = (headRight ? 1 : -1) * 22 * UIK;
  t.signalEl.setAttribute("transform",
    "translate(" + (t.headPos.x + dx).toFixed(1) + " " +
    (t.headPos.y + 11 * UIK).toFixed(1) + ")");
}
// Embarquement à quai : pendant l'arrêt (dwell), le convoi se « remplit » comme
// une jauge de batterie horizontale — la partie pleine (couleur vive) avance de
// la loco vers le dernier wagon, la partie vide (masque sombre) recule, à mesure
// qu'on approche de l'heure de départ. Plein = prêt à repartir. Hors arrêt, le
// masque disparaît (wagons pleins, aspect normal).
function updateBoarding(t) {
  if (t.freight || !t.maskEls) return;
  // Jauge d'embarquement seulement à l'arrêt sur un BON quai. Hors arrêt, ou sur
  // un mauvais quai (aucune sortie vers la destination → le convoi rebrousse
  // plein, sans débarquer), les wagons restent pleins (masque nul).
  const hasOut = t.state === "dwell" && !!paths["out:" + t.to + ":" + t.platform];
  if (!hasOut) {
    for (const m of t.maskEls) m.setAttribute("width", 0);
    return;
  }
  const end = Math.max(t.dep, t.actualArr + MIN_DWELL);
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
