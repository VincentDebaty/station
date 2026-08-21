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
//   3. congestion — combien de convois attendent LE MÊME QUAI en même temps.
//      Un horaire peut être « zéro retard possible » et rester une salle
//      d'attente : le calibrage repousse simplement les départs officiels, si
//      bien qu'une file de six trains sur un quai passe les deux contrôles
//      ci-dessus sans rien signaler. C'est pourtant ce qui se ressent le plus
//      en jouant — on n'aiguille plus, on patiente. On mesure donc la
//      PRESSION : le nombre maximum de convois dont la fenêtre d'occupation du
//      quai se chevauche, sur la solution de calibrage.
//
// Usage :
//   node tools/gen-check.mjs                 # tout le catalogue, K=6
//   node tools/gen-check.mjs liege           # une gare (par id), K plus élevé
//   node tools/gen-check.mjs liege lyon 30   # gares ciblées, K=30
//   node tools/gen-check.mjs --seed=1        # journées REPRODUCTIBLES
//   node tools/gen-check.mjs --niveau=1 ottignies   # enveloppe FORCÉE
//
// --niveau=N remplace le bloc `gen` de la fiche par l'enveloppe du niveau N
// (js/graph.js, enveloppeDe) — c'est ce que fait le jeu pour la gare d'amorce
// d'une partie, qui se joue en niveau 1 quelle que soit sa fiche. Sans ce
// drapeau, le contrôle validerait une journée que le joueur ne verra jamais.
//
// --seed=N remplace Math.random par un générateur graine, réinitialisé à
// l'identique avant chaque gare : deux exécutions tirent alors exactement les
// mêmes journées. Indispensable pour comparer un AVANT/APRÈS de calibrage ou
// de géométrie — sans lui, l'écart de « retard garanti » mesure surtout le
// bruit du tirage.
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

// --- arguments : ids de gare (lettres) + K facultatif (nombre) + --seed=N ---
let SEED = null, NIVEAU = null;
const rawArgs = process.argv.slice(2).filter(a => {
  const m = /^--seed=(\d+)$/.exec(a);
  if (m) { SEED = parseInt(m[1], 10); return false; }
  const n = /^--niveau=([1-5])$/.exec(a);
  if (n) { NIVEAU = parseInt(n[1], 10); return false; }
  return true;
});
const kArg = rawArgs.find(a => /^\d+$/.test(a));
const K = kArg ? parseInt(kArg, 10) : (rawArgs.some(a => !/^\d+$/.test(a)) ? 30 : 6);
const filter = rawArgs.filter(a => !/^\d+$/.test(a));
const DELAY_MAX = 0.30; // min de jeu : marge au-dessus du seuil interne (0.15) du générateur
// Pression tolérée sur un quai. Le générateur vise 3 et se replie sur 4
// (QUEUE_MAX, js/schedule.js) ; le contrôle vérifie qu'il y arrive.
//
// MAIS IL LE VÉRIFIE EN TAUX, PAS EN MAXIMUM. Un pic isolé à 5 sur seize
// journées n'est pas ce que le joueur a signalé : ce qu'il a vécu, ce sont les
// six derniers convois du service tous sur le même quai, journée après journée.
// Refuser toute excursion reviendrait à condamner des gares parfaitement
// jouables pour un instant de pincement, et à pousser à durcir le générateur
// bien au-delà de ce qui se ressent. On tolère donc le rare, jamais le
// systématique — et jamais le grave, quelle que soit sa rareté.
const QUEUE_MAX_CHECK = 4;      // ce qu'on veut tenir
const QUEUE_HARD = 6;           // jamais, même une seule fois
const QUEUE_RATE_MAX = 0.12;    // part de journées tolérée au-dessus du seuil
// UNE JOURNÉE N'EST PAS UN MOTIF. Sur un contrôle court (K=8, celui du
// pre-commit), une seule excursion pèse déjà 12,5 % et ferait échouer une gare
// que le même contrôle en K=30 déclare saine. Le taux ne décide donc qu'à
// partir de DEUX journées — en deçà, c'est du bruit d'échantillonnage, pas un
// défaut du générateur.
const QUEUE_MIN_DAYS = 2;

// --- tirage reproductible (--seed) --------------------------------------
// mulberry32 : court, bien distribué, suffisant pour rejouer des journées.
// `reseed()` est rappelé avant chaque gare pour que le retrait d'une gare du
// filtre ne décale pas les journées des suivantes.
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
// Shim : on ne touche JAMAIS au Math du process, seulement à celui du sandbox.
const mathShim = Object.create(Math);
let reseed = () => {};
if (SEED != null) reseed = () => { mathShim.random = mulberry32(SEED); };
reseed();

// --- contexte moteur : engine.js + schedule.js sont neutres vis-à-vis du DOM ---
function makeEngine() {
  const sandbox = { Math: mathShim, console, JSON };
  sandbox.self = { onmessage: null, postMessage() {} }; // engine.js est aussi un worker
  vm.createContext(sandbox);
  vm.runInContext(read("js/engine.js"), sandbox, { filename: "engine.js" });
  vm.runInContext(read("js/schedule.js"), sandbox, { filename: "schedule.js" });
  // Le modèle de difficulté vit dans js/graph.js. Ses fonctions de lecture du
  // réseau ne servent pas ici (HUBS n'est pas chargé, buildGraphe se garde
  // tout seul) : on ne vient chercher que les enveloppes.
  vm.runInContext(read("js/graph.js"), sandbox, { filename: "graph.js" });
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

// La PRESSION sur un quai se lit dans le moteur (js/schedule.js,
// platformPressure) — le générateur s'en sert pour filtrer, ce contrôle pour
// vérifier. Une seconde copie ici aurait fini par mesurer autre chose que ce
// que le jeu applique, et le contrôle aurait certifié un horaire qu'il ne
// contrôlait plus.
const eng = makeEngine();
const rows = [];
let failed = 0;

for (const { id, country } of cards) {
  let cfg = JSON.parse(read(`data/stations/${country}/${id}.json`));
  // Enveloppe forcée : la fiche garde sa géométrie, sa journée change de
  // niveau. C'est le geste exact de ficheDeService (js/graph.js).
  if (NIVEAU != null) {
    eng.__cfg = cfg;
    const gen = vm.runInContext(`enveloppeDe(this.__cfg, ${NIVEAU}, PROFILS[1])`, eng);
    cfg = { ...cfg, difficulty: NIVEAU, gen };
  }
  const problems = [];
  reseed();   // mêmes journées pour cette gare d'une exécution à l'autre

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
  const platformPressure = vm.runInContext("platformPressure", eng);
  let worst = 0, unplaceableDays = 0, errs = 0, minN = Infinity, maxN = 0;
  // Congestion : pire pression vue, et part des journées qui dépassent le seuil.
  let queueMax = 0, queueSum = 0, queueDays = 0, days = 0;
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
      const q = platformPressure(sched, res);
      queueMax = Math.max(queueMax, q); queueSum += q; days++;
      if (q > QUEUE_MAX_CHECK) queueDays++;
    } catch (e) { errs++; if (errs <= 2) problems.push("erreur génération : " + e.message); }
  }
  if (errs) problems.push(errs + " journée(s) en erreur");
  if (unplaceableDays) problems.push(unplaceableDays + " journée(s) avec train non plaçable");
  if (worst > DELAY_MAX) problems.push("retard garanti " + worst.toFixed(2) + " > " + DELAY_MAX);
  if (queueMax >= QUEUE_HARD)
    problems.push("file de " + queueMax + " au même quai (jamais toléré)");
  else if (queueDays >= QUEUE_MIN_DAYS && days && queueDays / days > QUEUE_RATE_MAX)
    problems.push(queueDays + "/" + days + " journée(s) au-dessus de " +
      QUEUE_MAX_CHECK + " au même quai (max " + queueMax + ")");

  const ok = problems.length === 0;
  if (!ok) failed++;
  rows.push({ id, ok, trains: `${minN}-${maxN}`, delay: worst.toFixed(2),
              qMax: queueMax, qMoy: days ? (queueSum / days).toFixed(1) : "—", problems });
}

// --- rapport ---
const pad = (s, n) => String(s).padEnd(n);
console.log(`\ngen-check — ${cards.length} gare(s), K=${K} journées chacune` +
  (NIVEAU != null ? `, enveloppe forcée au niveau ${NIVEAU}` : "") +
            (SEED != null ? `, graine ${SEED} (reproductible)` : "") + "\n");
console.log(pad("gare", 18) + pad("état", 6) + pad("trains", 9) + pad("retard", 8) +
            pad("file", 6) + pad("moy", 6) + "problèmes");
console.log("-".repeat(88));
for (const r of rows)
  console.log(
    pad(r.id, 18) + pad(r.ok ? "OK" : "FAIL", 6) +
    pad(r.trains, 9) + pad(r.delay, 8) +
    pad(r.qMax, 6) + pad(r.qMoy, 6) + (r.problems.join(" ; ") || ""));
console.log("-".repeat(88));
console.log(failed ? `\n${failed} gare(s) en échec.\n` : `\nToutes les gares passent.\n`);
// Et la carte : une ligne, pour qu'un seul appel dise si l'on est livrable.
// Informatif — la carte a ses propres règles et son propre code de sortie
// (`node tools/carte-check.mjs`), on ne fait pas échouer une fiche pour elles.
try {
  const { execFileSync } = await import("node:child_process");
  const bloc = process.env.CARTE_BLOC ? ["--livrable=" + process.env.CARTE_BLOC] : [];
  console.log(execFileSync(process.execPath, [path.join(ROOT, "tools/carte-check.mjs"), "--resume", ...bloc], { encoding: "utf8" }).trim() + "\n");
} catch (e) { if (e.stdout) console.log(String(e.stdout).trim() + "\n"); }
process.exit(failed ? 1 : 0);
