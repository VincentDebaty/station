// ------------------------------------------------------------------
// oracle-enclenchement — LE PROTOTYPE JUGE LE JEU LUI-MÊME, pas à pas.
//
//     node tools/oracle-enclenchement.mjs darlington [autre-id ...]
//     node tools/oracle-enclenchement.mjs darlington --seeds=1,2,3 --dt=240
//     node tools/oracle-enclenchement.mjs --tous --seeds=1
//
// game.js est le jeu : la machine à états des convois, la file d'approche,
// l'enclenchement, le fret, les imprévus, le retard, la fin de service. Il
// est écrit pour un navigateur — il crée des nœuds SVG, joue des sons, pose
// des pilules. ICI IL TOURNE DANS NODE, DERRIÈRE UN DOM INERTE : un Proxy qui
// rend un objet inerte à tout accès, accepte toute écriture, et absorbe tout
// appel. Les règles s'exécutent, le rendu tombe dans le vide.
//
// Pour chaque fiche et chaque graine : schedule.js tire la journée (Math.random
// remplacé par le mulberry32 de gen-check), game.js la joue au pas dt avec un
// JOUEUR SCRIPTÉ, et jeu/enclenchement.gd fait exactement pareil via
// jeu/oracle_enclenchement.gd. Puis comparaison : chaque transition d'état
// (convoi, de, à, instant, quai, cible, qs, startS, retard au départ), chaque
// choix du joueur, et la fin de service — étoiles, retard, série.
//
// Le joueur scripté, identique des deux côtés : après chaque tick, chaque
// convoi voyageur en attente sans quai reçoit le premier quai qui dessert sa
// destination, ni promis ni fermé, de préférence libre ; à défaut le premier
// quai atteignable — donc un mauvais quai, et le refoulement est exercé.
// ------------------------------------------------------------------
import { readFileSync, writeFileSync, mkdtempSync, existsSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const lire = p => JSON.parse(readFileSync(join(RACINE, p), "utf8"));
const src = p => readFileSync(join(RACINE, p), "utf8");
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
const TOL = 1e-9;
const GODOT = process.env.GODOT || "godot";
const SEEDS = String(opt("seeds") || "1").split(",").map(Number);
const DENOM = Number(opt("dt") || 240);          // dt = 1/240 min : 60 images/s à ×1
const DT = 1 / DENOM;
const MAX_PAS = 400000;

// --- quelles fiches ---------------------------------------------------------
const index = lire("data/stations/index.json");
const paysDe = new Map();
for (const g of index) for (const id of g.stations) paysDe.set(id, g.country);
let ids = args.filter(a => !a.startsWith("--"));
if (opt("tous")) ids = [...paysDe.keys()];
if (!ids.length) { console.error("usage : node tools/oracle-enclenchement.mjs <id ...> | --tous [--seeds=1,2] [--dt=240] [--detail]"); process.exit(2); }
for (const id of ids) if (!paysDe.has(id)) { console.error(`inconnue à l'index : ${id}`); process.exit(2); }
const chemin = id => `data/stations/${paysDe.get(id)}/${id}.json`;

// --- le DOM inerte ----------------------------------------------------------
// Rend un objet inerte à tout accès, accepte toute écriture, absorbe tout
// appel et toute construction. Convertible en "" et itérable vide, pour que
// les concaténations et les `for…of` du rendu ne fassent pas d'histoires.
const inerte = new Proxy(function () {}, {
  get(_, k) {
    if (k === Symbol.toPrimitive) return () => "";
    if (k === Symbol.iterator) return function* () {};
    if (k === "then") return undefined;
    if (k === "length") return 0;
    // Un nœud inerte n'a pas d'enfants : sinon `while (el.firstChild)
    // el.removeChild(el.firstChild)` (render.js, la file d'attente en
    // réduction) ne s'arrête jamais — dix minutes à 99 % avant de comprendre.
    if (k === "firstChild" || k === "lastChild" || k === "nextSibling" || k === "previousSibling") return null;
    return inerte;
  },
  set() { return true; },
  apply() { return inerte; },
  construct() { return inerte; },
  has() { return true; }
});

function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
const mathShim = Object.create(Math);

// --- le sandbox : engine, schedule, ruban, render, game — et ce qu'ils attendent
const sandbox = {
  Math: mathShim, console, JSON,
  document: inerte,
  window: { matchMedia: () => ({ matches: false }), addEventListener() {}, removeEventListener() {},
            innerWidth: 1400, innerHeight: 760, AudioContext: inerte, webkitAudioContext: inerte },
  AudioContext: inerte, navigator: inerte, performance: { now: () => 0 },
  requestAnimationFrame: () => 0, cancelAnimationFrame() {}, getComputedStyle: () => inerte,
  setTimeout: () => 0, clearTimeout() {}, setInterval: () => 0, clearInterval() {},
  // js/store.js n'est pas chargé : le rendu et la fin de service lisent le
  // magasin, on leur rend un magasin vide et muet.
  getMuted: () => true, getOnboarded: () => true, setOnboarded() {}, networkEmpty: () => false,
  getProgress: () => ({}), saveResult() {}, markTentee() {}, pushSerie() {}, SERIE_SEUIL: 2,
  medaillesDe: () => new Set(), etatRecompenses: () => ({}), medaillesNouvelles: () => [],
  showHub() {}, preparerSuite() {}, renderCarte() {}, lancerVoyageDeChapitre() {},
  CARTE: { bilan: null, medailles: null, etoiles: null }, perfectConfetti() {},
  updatePauseIcon() {}, openWelcome() {}, icon: () => "", ICON: {}, etoilesTotal: () => 0,
  cardOf: () => null
};
createContext(sandbox);
for (const f of ["js/engine.js", "js/schedule.js", "js/ruban.js", "js/render.js", "js/game.js"])
  runInContext(src(f), sandbox, { filename: f });

// Le barème : celui de la difficulté de fiche, des deux côtés — la rampe du
// ruban est l'étape 5. Et la fin de service se contente d'enregistrer.
runInContext(`
  seuilsDeService = cfg => cfg.seuils ? { ...seuilsDeNiveau(cfg.difficulty), ...cfg.seuils } : seuilsDeNiveau(cfg.difficulty);
  __fin = null;
  endGame = function (failed) {
    ended = true;
    const d = Math.round(failed ? liveDelay() : totalDelay);
    const s = seuilsDeService(STATION);
    const stars = failed ? 0 : etoilesPour(d, s);
    const win = stars >= 1;
    __fin = { failed: !!failed, d, stars, win, perfect: win && !failed && d === 0,
              totalDelay, streak: onTimeStreak };
  };
  // Le joueur scripté — la même politique que côté Godot, mot pour mot.
  __joueur = function (n, choix) {
    for (const t of trains) {
      if (t.freight || t.target != null) continue;
      if (t.state !== "waiting" && t.state !== "approaching") continue;
      const lf = LINKS[t.from] || [];
      let cands = lf.filter(pid => paths["out:" + t.to + ":" + pid] && !platformClaimed(pid) && !platformClosed(pid));
      if (!cands.length) cands = lf.filter(pid => !platformClaimed(pid) && !platformClosed(pid));
      if (!cands.length) continue;
      const pick = cands.find(pid => !platformOccupied(pid)) ?? cands[0];
      onTrainClick(t);
      // onPlatformClick ne rend rien : on relit la conséquence pour la trace
      const avant = t.target;
      onPlatformClick(pick);
      choix.push({ n, id: t.id, quai: pick, reponse: t.target === pick ? (platformOccupied(pick) ? "différé" : "ok") : "refus" });
    }
  };
  __jouer = function (day, dt) {
    started = false; ended = false; paused = false; gameMin = 0; speed = 1;
    totalDelay = 0; selected = null; activeRoutes = {}; queueSeq = 0; onTimeStreak = 0;
    __fin = null;
    SCHEDULE = day.schedule;
    EVENTS = day.events.map(ev => ({ ...ev, revealed: false, cleared: false, el: null }));
    trains = SCHEDULE.map(s => ({
      ...s,
      cars: s.freight ? s.cars : Math.min(MAX_CARS, Math.max(1, s.cars || 1)),
      state: "scheduled", progress: 0, qs: null, platform: null, target: null,
      entryPath: null, exitPath: null, exitTo: null, refoul: false, validated: false,
      pendingEl: null, stopS: null, startS: 0, backS: 0,
      actualArr: null, queuedAt: null, el: null, carEls: null, maskEls: null,
      badgeEl: null, badgeText: null, badgeRect: null, headPos: null
    }));
    try { drawStatic(); } catch (e) { gTracks = gRoutes = gPlatforms = gPortals = gQueue = gTrains = gFx = gBadges = document; }
    const trace = { pas: [], choix: [], fin: null };
    const etats = trains.map(t => t.state);
    let n = 0;
    while (!ended && n < ${MAX_PAS}) {
      n++;
      gameMin += dt;
      tick(dt);
      for (let i = 0; i < trains.length; i++) {
        const t = trains[i];
        if (t.state !== etats[i]) {
          trace.pas.push({ n, t: gameMin, id: t.id, de: etats[i], a: t.state,
            quai: t.platform, cible: t.target, qs: t.qs, startS: t.startS || 0, depDelay: t.depDelay || 0 });
          etats[i] = t.state;
        }
      }
      if (ended) break;
      __joueur(n, trace.choix);
    }
    if (!__fin) endGame(true);
    trace.fin = { ...__fin, n, t: gameMin };
    return trace;
  };
`, sandbox);

// --- la comparaison ---------------------------------------------------------
function comparer(a, b, ou, ecarts) {
  if (a === undefined) a = null;
  if (b === undefined) b = null;
  if (typeof a === "number" && typeof b === "number") {
    if (!(Math.abs(a - b) <= TOL)) ecarts.push(`${ou} : js=${a} godot=${b}`);
    return;
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b)) { ecarts.push(`${ou} : types`); return; }
    const n = Math.min(a.length, b.length);
    for (let i = 0; i < n; i++) comparer(a[i], b[i], `${ou}[${i}]`, ecarts);
    if (a.length !== b.length) ecarts.push(`${ou} : ${a.length} contre ${b.length} éléments`);
    return;
  }
  if (a && b && typeof a === "object" && typeof b === "object") {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      if (!(k in a) && b[k] === null) continue;
      if (!(k in b) && a[k] === null) continue;
      if (!(k in a) || !(k in b)) { ecarts.push(`${ou}.${k} : ${k in a ? "absent côté Godot" : "absent côté JS"}`); continue; }
      comparer(a[k], b[k], `${ou}.${k}`, ecarts);
    }
    return;
  }
  if (a !== b) ecarts.push(`${ou} : js=${JSON.stringify(a)} godot=${JSON.stringify(b)}`);
}

// --- les journées, tirées ici, jouées des deux côtés ------------------------
const dossier = mkdtempSync(join(tmpdir(), "oracle-enclenchement-"));
const cas = [];
for (const id of ids) {
  const fiche = lire(chemin(id));
  for (const seed of SEEDS) {
    mathShim.random = mulberry32(seed);
    sandbox.__fiche = fiche;
    const day = JSON.parse(runInContext(`loadStation(__fiche); JSON.stringify(generateSchedule())`, sandbox));
    const fJour = join(dossier, `${id}-${seed}.journee.json`);
    writeFileSync(fJour, JSON.stringify(day));
    sandbox.__day = day;
    const t0 = Date.now();
    const trace = runInContext(`loadStation(__fiche); JSON.parse(JSON.stringify(__jouer(__day, ${DT})))`, sandbox);
    cas.push({ id, seed, fiche, fJour, trace, msJS: Date.now() - t0 });
  }
}

// --- côté Godot : un lancement par cas (la trace est longue, le temps court)
let ok = 0, ko = 0, msGD = 0;
const lignes = [];
for (const c of cas) {
  const fTrace = join(dossier, `${c.id}-${c.seed}.godot.json`);
  const t0 = Date.now();
  const r = spawnSync(GODOT, ["--headless", "--path", RACINE, "--script", "res://jeu/oracle_enclenchement.gd", "--",
    fTrace, join(RACINE, chemin(c.id)), c.fJour, String(DENOM)],
    { encoding: "utf8", maxBuffer: 1 << 26, timeout: 20 * 60 * 1000 });
  const ms = Date.now() - t0; msGD += ms;
  const sortie = ((r.stdout || "") + "\n" + (r.stderr || "")).trim();
  const nom = `${c.id}·${c.seed}`;
  if (r.status !== 0 || /SCRIPT ERROR|^ERROR:|Parse Error/m.test(sortie) || !existsSync(fTrace)) {
    ko++;
    lignes.push(`  ✘ ${nom.padEnd(26)} Godot a refusé (code ${r.status})`);
    for (const l of sortie.split("\n").filter(l => !/^Godot Engine|^$|^Données/.test(l)).slice(0, 8)) lignes.push(`      ${l}`);
    continue;
  }
  const gd = JSON.parse(readFileSync(fTrace, "utf8"));
  const ecarts = [];
  comparer(c.trace, gd, nom, ecarts);
  const f = c.trace.fin;
  const resume = `${c.trace.pas.length} transitions · ${c.trace.choix.length} choix · ${f.failed ? "ÉCHEC" : f.stars + "★"} +${f.d} · js ${c.msJS} ms / godot ${ms} ms`;
  if (ecarts.length) {
    ko++;
    lignes.push(`  ✘ ${nom.padEnd(26)} ${ecarts.length} écart(s) — ${resume}`);
    const max = opt("detail") ? 40 : 6;
    for (const e of ecarts.slice(0, max)) lignes.push(`      ${e}`);
    if (ecarts.length > max) lignes.push(`      … ${ecarts.length - max} de plus`);
  } else {
    ok++;
    if (!opt("tous") || opt("detail")) lignes.push(`  ✔ ${nom.padEnd(26)} ${resume}`);
  }
}
console.log(`oracle-enclenchement — ${ids.length} fiche(s) × ${SEEDS.length} graine(s), pas 1/${DENOM} min, game.js contre jeu/enclenchement.gd`);
for (const l of lignes) console.log(l);
console.log(`  ${ok} identique(s), ${ko} divergente(s) — Godot ${msGD} ms au total`);
process.exit(ko ? 1 : 0);
