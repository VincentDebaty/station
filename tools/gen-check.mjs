// ------------------------------------------------------------------
// gen-check — validation headless des fiches de gare, sans navigateur.
//
// Charge le VRAI moteur (js/engine.js) et le VRAI générateur (js/schedule.js)
// dans un contexte Node, puis pour chaque gare du catalogue :
//   1. connectivité — aucun portail mort, aucun quai mort. Un train ne
//      circule qu'entre deux directions reliées par un quai commun (côtés
//      opposés, ou paire même-côté autorisée) ; une direction que le moteur
//      n'inscrit dans AUCUNE paire ne sera jamais desservie (invisible à
//      l'œil, révélé ici).
//   2. génération — K journées tirées ; on vérifie 0 erreur, aucun train non
//      plaçable, et le retard total garanti par le calibrage sous le seuil.
//
// Usage :
//   node tools/gen-check.mjs                 # tout le catalogue, K=6
//   node tools/gen-check.mjs liege           # une gare (par id), K plus élevé
//   node tools/gen-check.mjs liege lyon 30   # gares ciblées, K=30
//
// Sortie : un tableau par gare + un verdict global. Code de sortie ≠ 0 si un
// contrôle échoue (utilisable en pre-commit / CI).
// ------------------------------------------------------------------
import fs from "fs";
import path from "path";
import vm from "vm";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = f => fs.readFileSync(path.join(ROOT, f), "utf8");

// --- arguments : ids de gare (lettres) + K facultatif (nombre) ---
const rawArgs = process.argv.slice(2);
const kArg = rawArgs.find(a => /^\d+$/.test(a));
const K = kArg ? parseInt(kArg, 10) : (rawArgs.some(a => !/^\d+$/.test(a)) ? 30 : 6);
const filter = rawArgs.filter(a => !/^\d+$/.test(a));
const DELAY_MAX = 0.30; // min de jeu : marge au-dessus du seuil interne (0.15) du générateur

// --- contexte moteur : engine.js + schedule.js sont neutres vis-à-vis du DOM ---
function makeEngine() {
  const sandbox = { Math, console, JSON };
  sandbox.self = { onmessage: null, postMessage() {} }; // engine.js est aussi un worker
  vm.createContext(sandbox);
  vm.runInContext(read("js/engine.js"), sandbox, { filename: "engine.js" });
  vm.runInContext(read("js/schedule.js"), sandbox, { filename: "schedule.js" });
  return sandbox;
}

// --- catalogue ---
const index = JSON.parse(read("data/stations/index.json"));
let cards = [];
for (const group of index)
  for (const id of group.stations)
    cards.push({ id, country: group.country });
if (filter.length) cards = cards.filter(c => filter.includes(c.id));
if (!cards.length) { console.error("Aucune gare ne correspond à :", filter.join(", ")); process.exit(2); }

const eng = makeEngine();
const rows = [];
let failed = 0;

for (const { id, country } of cards) {
  const cfg = JSON.parse(read(`data/stations/${country}/${id}.json`));
  const problems = [];

  // 1) connectivité : on interroge les PAIRS que le moteur a réellement construites
  vm.runInContext("loadStation(" + JSON.stringify(cfg) + ")", eng);
  const PAIRS = vm.runInContext("PAIRS", eng);              // [[from,to], ...]
  const LINKS = cfg.links;
  const portalNames = Object.keys(cfg.portals);
  const platIds = cfg.platforms.map(p => p.id);

  const livePortals = new Set(PAIRS.flat());
  const deadPortals = portalNames.filter(p => !livePortals.has(p));
  if (deadPortals.length)
    problems.push("portail mort : " + deadPortals.join(", "));

  const livePlats = new Set();
  for (const [a, b] of PAIRS)
    for (const q of LINKS[a]) if (LINKS[b].includes(q)) livePlats.add(q);
  const deadPlats = platIds.filter(q => !livePlats.has(q));
  if (deadPlats.length)
    problems.push("quai mort : " + deadPlats.join(", "));

  // 2) génération : K journées, on mesure le pire retard garanti et les non-plaçables
  const simulateDay = vm.runInContext("simulateDay", eng);
  let worst = 0, unplaceableDays = 0, errs = 0, minN = Infinity, maxN = 0;
  for (let k = 0; k < K; k++) {
    try {
      const day = vm.runInContext("generateSchedule()", eng);
      const sched = day.schedule, ev = day.events;
      const nPax = sched.filter(s => !s.freight).length;
      minN = Math.min(minN, nPax); maxN = Math.max(maxN, nPax);
      const assign = sched.map(s => s.hint);
      const res = simulateDay(sched, assign, 0.01, ev);
      let tot = 0, unplaced = 0;
      for (let i = 0; i < sched.length; i++) {
        if (sched[i].freight) continue;
        if (res[i].depReal == null) { unplaced++; continue; }
        tot += Math.max(0, res[i].depReal - sched[i].dep);
      }
      worst = Math.max(worst, tot);
      if (unplaced) unplaceableDays++;
    } catch (e) { errs++; if (errs <= 2) problems.push("erreur génération : " + e.message); }
  }
  if (errs) problems.push(errs + " journée(s) en erreur");
  if (unplaceableDays) problems.push(unplaceableDays + " journée(s) avec train non plaçable");
  if (worst > DELAY_MAX) problems.push("retard garanti " + worst.toFixed(2) + " > " + DELAY_MAX);

  const ok = problems.length === 0;
  if (!ok) failed++;
  rows.push({ id, ok, trains: `${minN}-${maxN}`, delay: worst.toFixed(2), problems });
}

// --- rapport ---
const pad = (s, n) => String(s).padEnd(n);
console.log(`\ngen-check — ${cards.length} gare(s), K=${K} journées chacune\n`);
console.log(pad("gare", 18) + pad("état", 6) + pad("trains", 9) + pad("retard", 8) + "problèmes");
console.log("-".repeat(72));
for (const r of rows)
  console.log(
    pad(r.id, 18) + pad(r.ok ? "OK" : "FAIL", 6) +
    pad(r.trains, 9) + pad(r.delay, 8) + (r.problems.join(" ; ") || ""));
console.log("-".repeat(72));
console.log(failed ? `\n${failed} gare(s) en échec.\n` : `\nToutes les gares passent.\n`);
process.exit(failed ? 1 : 0);
