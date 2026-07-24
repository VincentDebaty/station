"use strict";
// ------------------------------------------------------------------
// Moteur : constantes, géométrie des voies et chargement d'une gare.
// loadStation() transforme une fiche du catalogue en réseau jouable :
// layout vertical, chemins, zones de conflit et liaisons autorisées.
// ------------------------------------------------------------------
const SVGNS = "http://www.w3.org/2000/svg";
// Ce fichier est aussi chargé dans un Web Worker (génération d'horaire hors
// thread principal, voir js/gen-worker.js) : là, `document` n'existe pas. On
// garde donc l'accès au board optionnel — seul le rendu (main thread) l'utilise.
const board = (typeof document !== "undefined") ? document.getElementById("board") : null;

const PLAT_X1 = 560, PLAT_X2 = 840, PLAT_H = 42;

// État de la gare chargée — rempli par loadStation()
let STATION, currentIdx = 0;
let PLATFORMS, PORTALS, DEST_COLOR, DEST_ABBR, LINKS, GEN;

const TRAVEL = 1.6;             // minutes de jeu pour traverser un gril
const MIN_DWELL = 2;            // arrêt minimum en minutes de jeu (8 s réelles à x1)
const SEC_PER_GAMEMIN = 4.0;    // 1 min de jeu = 4 s réelles à x1
// Tolérance de départ : un convoi qui part « à l'heure » traîne toujours un
// dépassement d'une fraction de minute (la frame où gameMin franchit t.dep).
// Isolé c'est invisible, mais ces miettes s'accumulent sur tout le service et
// finissent par faire monter le compteur d'une minute pleine. On absorbe ce
// bruit : sous ce seuil, le retard compte pour zéro. ~0,6 s réelle à x1.
const DEPART_GRACE = 0.15;      // minutes de jeu de tolérance au départ

// Wagons : 1 à 7 par train — plus le convoi est long, plus il est lent
// (7 wagons = 240 px, la longueur utile d'un quai)
const MAX_CARS = 7;
const CAR_LEN = 30, CAR_GAP = 5, CAR_SPACING = CAR_LEN + CAR_GAP;
const EXIT_RUN = 700; // fuite après le gril : jusqu'au bord réel de l'écran, pas juste le viewBox
// Point de fuite des voies : bien AU-DELÀ du viewBox (1400×760). Le plan étant
// letterboxé (preserveAspectRatio "meet"), le bord du viewBox n'est pas le bord
// de l'écran ; on prolonge donc les voies d'arrivée/départ dans la bande de
// letterbox pour que les convois émergent et disparaissent au ras de l'écran.
const EDGE_RUN = 360;
function trainLen(t) { return t.cars * CAR_SPACING - CAR_GAP; }
function slowness(t) { return 1 + (t.cars - 1) * 0.22; } // 7 wagons ≈ 2.3× plus lent
// Fret : long mais PAS lent. Il traverse le gril à la vitesse d'un 3 wagons quelle
// que soit sa longueur, pour ne pas verrouiller entrée+sortie trop longtemps (sinon
// il asphyxie la gare). Voir movingThrough (game.js) et le calibrage (schedule.js).
const FREIGHT_SLOWNESS = 1 + (3 - 1) * 0.22;

// ------------------------------------------------------------------
// Géométrie : un chemin par liaison (portail <-> quai), direction libre
// ------------------------------------------------------------------
function cubic(p0, c1, c2, p1, t) {
  const u = 1 - t;
  return {
    x: u*u*u*p0.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*p1.x,
    y: u*u*u*p0.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*p1.y
  };
}
function samplePath(p0, c1, c2, p1, n = 60) {
  const pts = [];
  for (let i = 0; i <= n; i++) pts.push(cubic(p0, c1, c2, p1, i / n));
  return pts;
}
function pathD(pts) {
  return "M " + pts.map(p => p.x.toFixed(1) + " " + p.y.toFixed(1)).join(" L ");
}

const STOP_MARGIN = 30;
// Dégagement au portail : si une zone de conflit touche la gorge (s ≤ 0), le
// dégagement requis s'étend sur toute la zone de convergence approche/départ.
// C'est aussi la distance qu'un convoi sortant doit avoir dépassée (dernier
// wagon à s < -PORTAL_CLEAR) avant que son itinéraire soit relâché.
const PORTAL_CLEAR = 130;
let paths, meshD, APPROACH, DEPART, conflicts, PAIRS;

// Charge une fiche de gare : layout vertical automatique, réseau de voies,
// zones de conflit et liaisons autorisées. Tout le moteur en découle.
function loadStation(cfg) {
  STATION = cfg;
  GEN = cfg.gen;
  // --- layout : quais et portails répartis selon leur nombre ---
  const nQ = cfg.platforms.length;
  const stepQ = nQ > 1 ? Math.min(100, 520 / (nQ - 1)) : 0;
  const topQ = 400 - stepQ * (nQ - 1) / 2;
  PLATFORMS = cfg.platforms.map((q, i) => ({ ...q, cy: Math.round(topQ + i * stepQ) }));
  PORTALS = {}; DEST_COLOR = {}; DEST_ABBR = {};
  // Point de convergence à distance fixe des quais, terminus compris : le
  // faisceau aiguillage → quais garde la même largeur généreuse partout
  // (les gares à quais desservis d'un seul côté ne sont plus écrasées).
  for (const side of ["L", "R"]) {
    const names = Object.keys(cfg.portals).filter(k => cfg.portals[k].side === side);
    names.forEach((k, i) => {
      const c = cfg.portals[k];
      PORTALS[k] = {
        side, x: side === "L" ? 150 : 1250,
        cy: names.length === 1 ? 405 : Math.round(220 + 420 * i / (names.length - 1)),
        label: c.label || k,
        in: c.in !== false, out: c.out !== false
      };
      DEST_COLOR[k] = c.color;
      DEST_ABBR[k] = c.abbr;
    });
  }
  LINKS = cfg.links;

  // --- réseau : un chemin par liaison (portail <-> quai) et rôle autorisé ---
  paths = {};   // "in:PORTAIL:quai" / "out:PORTAIL:quai" -> {id, pts, cum, len, side, dur}
  meshD = [];   // tracés gris du maillage (béziers seuls)
  for (const [pname, p] of Object.entries(PORTALS)) {
  for (const pid of LINKS[pname]) {
    const q = PLATFORMS.find(x => x.id === pid);
    let bez, edgeX, dir; // dir +1 : la voie continue vers la droite du quai
    if (p.side === "L") {
      bez = samplePath(
        { x: p.x, y: p.cy }, { x: p.x + 190, y: p.cy },
        { x: PLAT_X1 - 190, y: q.cy }, { x: PLAT_X1, y: q.cy });
      edgeX = PLAT_X1; dir = 1;
    } else {
      bez = samplePath(
        { x: p.x, y: p.cy }, { x: p.x - 190, y: p.cy },
        { x: PLAT_X2 + 190, y: q.cy }, { x: PLAT_X2, y: q.cy });
      edgeX = PLAT_X2; dir = -1;
    }
    meshD.push({ d: pathD(bez), portal: pname });
    const run = toX => {
      const pts = [], n = 24;
      for (let i = 1; i <= n; i++) pts.push({ x: edgeX + (toX - edgeX) * i / n, y: q.cy });
      return pts;
    };
    // entrée : on tire jusqu'en tête de quai (extrémité opposée)
    const farX  = dir === 1 ? PLAT_X2 - STOP_MARGIN : PLAT_X1 + STOP_MARGIN;
    // sortie : elle démarre en tête de quai côté portail de sortie
    const nearX = dir === 1 ? PLAT_X1 + STOP_MARGIN : PLAT_X2 - STOP_MARGIN;
    for (const [role, endX] of [["in", farX], ["out", nearX]]) {
      if (role === "in" && !p.in) continue;   // portail à sens unique
      if (role === "out" && !p.out) continue;
      const id = role + ":" + pname + ":" + pid;
      const pts = bez.concat(run(endX));
      const cum = [0];
      for (let i = 1; i < pts.length; i++)
        cum.push(cum[i - 1] + Math.hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y));
      const len = cum[cum.length - 1];
      paths[id] = { id, pts, cum, len, side: p.side, dur: TRAVEL * len / 700 };
    }
  }
}

  // Deux voies par portail :
  // - voie du bas (ARRIVÉES) : droite depuis le bord puis raccord en courbe
  // - voie du haut (DÉPARTS) : prolonge le point de convergence vers le bord
  APPROACH = {}; DEPART = {};
  for (const [pname, p] of Object.entries(PORTALS)) {
  const startX = p.side === "L" ? -EDGE_RUN : 1400 + EDGE_RUN;
  const mk = pts => {
    const cum = [0];
    for (let i = 1; i < pts.length; i++)
      cum.push(cum[i - 1] + Math.hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y));
    return { pts, cum, len: cum[cum.length - 1] };
  };
  // raccord en courbe douce (tangentes horizontales), comme le gril
  const mergeX = p.x + (p.side === "L" ? -110 : 110);
  const midX = p.x + (p.side === "L" ? -55 : 55);
  APPROACH[pname] = mk([{ x: startX, y: p.cy + 36 }].concat(
    samplePath({ x: mergeX, y: p.cy + 36 }, { x: midX, y: p.cy + 36 },
               { x: midX, y: p.cy }, { x: p.x, y: p.cy }, 24)));
  DEPART[pname] = mk([{ x: p.x, y: p.cy }, { x: startX, y: p.cy }]);
}

  // Conflits : deux chemins du même gril à moins de 16 px l'un de l'autre
  conflicts = {};
  {
  const ids = Object.keys(paths);
  for (const id of ids) conflicts[id] = {};
  for (let a = 0; a < ids.length; a++) {
    for (let b = a + 1; b < ids.length; b++) {
      const ra = paths[ids[a]], rb = paths[ids[b]];
      if (ra.side !== rb.side) continue;
      // Zone de conflit : intervalle d'abscisse, sur chaque chemin, où il
      // passe à moins de 16 px de l'autre — l'aiguillage/croisement partagé
      let touching = false;
      let aLo = Infinity, aHi = -Infinity, bLo = Infinity, bHi = -Infinity;
      for (let i = 0; i < ra.pts.length; i++) for (let j = 0; j < rb.pts.length; j++) {
        const pa = ra.pts[i], pb = rb.pts[j];
        if ((pa.x - pb.x) ** 2 + (pa.y - pb.y) ** 2 < 16 * 16) {
          touching = true;
          aLo = Math.min(aLo, ra.cum[i]); aHi = Math.max(aHi, ra.cum[i]);
          bLo = Math.min(bLo, rb.cum[j]); bHi = Math.max(bHi, rb.cum[j]);
        }
      }
      if (touching) {
        // marge de sécurité : presque un wagon entier, pour que le second
        // train ne s'élance pas dans les roues du premier. Si la zone touche
        // la gorge du portail (s = 0), le dégagement requis s'étend à toute
        // la zone de raccord approche/départ : un convoi sortant doit
        // l'avoir entièrement quittée avant qu'un autre s'y engage.
        const M = 28;
        const lo = v => v - M <= 0 ? -PORTAL_CLEAR : v - M;
        conflicts[ids[a]][ids[b]] = { lo: lo(aLo), hi: aHi + M };
        conflicts[ids[b]][ids[a]] = { lo: lo(bLo), hi: bHi + M };
      }
    }
  }
  }

  // Liaisons autorisées : un quai commun requis, sens des portails
  // respecté ; paires même-côté selon la fiche ("all" = gare terminus)
  PAIRS = [];
  for (const a of Object.keys(PORTALS)) for (const b of Object.keys(PORTALS)) {
    if (a === b) continue;
    if (!PORTALS[a].in || !PORTALS[b].out) continue;
    if (!LINKS[a].some(q => LINKS[b].includes(q))) continue;
    if (PORTALS[a].side === PORTALS[b].side &&
        cfg.sameSidePairs !== "all" &&
        !(cfg.sameSidePairs || []).some(pr => pr[0] === a && pr[1] === b))
      continue;
    PAIRS.push([a, b]);
  }
}
