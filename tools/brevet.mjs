#!/usr/bin/env node
// ------------------------------------------------------------------
// brevet — certifie chaque fiche UNE FOIS POUR TOUTES, à chaque niveau.
// ------------------------------------------------------------------
// Le constat du 27 août 2026 : étendre une carte déplace la rampe de TOUTES
// les gares, et chaque extension imposait de re-balayer le ruban entier au
// tirage aléatoire — des minutes de calcul, des verdicts qui changent d'une
// exécution à l'autre, et des défauts qui sortent un par un (Colmar, servie
// 14-17 par sa nouvelle position, ressortait une file de 6 qu'aucun balayage
// de la veille n'avait vue).
//
// Le brevet retourne le problème : une gare du ruban ne joue jamais que les
// enveloppes de ses niveaux (ENVELOPPES 1..5, rabattues par plafondDeFlux) et
// le régime boss en fin de chapitre. Ces régimes sont en NOMBRE FINI et ne
// dépendent PAS de la carte. On peut donc mesurer chaque fiche sur chacun
// d'eux, une fois, sur une batterie de graines fixes — et inscrire le
// résultat. Ensuite, recomposer ou étendre une carte ne coûte plus aucune
// simulation : carte-check (R10) vérifie en millisecondes que la rampe ne
// demande à personne plus que son brevet.
//
//   node tools/brevet.mjs                  # les fiches SANS brevet valable
//   node tools/brevet.mjs colmar aarau     # des fiches ciblées
//   node tools/brevet.mjs --tout           # tout recertifier
//   node tools/brevet.mjs --graines=1,2,3 --k=30    # la batterie (défauts)
//
// Le brevet d'une fiche est INVALIDÉ par tout changement de ce qui se joue :
// géométrie (quais, portails, links, sameSidePairs) ou `gen` écrit (le boss
// s'y fond, et une gare hors ruban le joue tel quel). L'empreinte de ces
// champs est inscrite avec le brevet ; l'outil recertifie ce qui a changé et
// ne retouche pas le reste. Sortie : data/stations/brevets.json.
//
// LA BATTERIE REMPLACE LES TIRAGES LIBRES. Trois graines fixes à K=30, c'est
// 90 journées par régime — l'équivalent de la mesure exhaustive du 23 août —
// et le verdict est REPRODUCTIBLE : deux exécutions rendent le même brevet, un
// échec se rejoue à l'identique. Le tirage libre reste l'outil de gen-check
// pour explorer une gare qu'on soupçonne ; il n'est plus le péage de chaque
// modification de carte.
//
// Les seuils sont CEUX de gen-check (mêmes maxima, même test binomial) : un
// brevet ne certifie pas autre chose que ce que le contrôle refuse.
// ------------------------------------------------------------------
import fs from "fs";
import os from "os";
import path from "path";
import vm from "vm";
import { spawn } from "child_process";
import { fileURLToPath } from "url";
import { empreinte } from "./empreinte.mjs";

const SCRIPT = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(SCRIPT), "..");
const read = f => fs.readFileSync(path.join(ROOT, f), "utf8");
const SORTIE = "data/stations/brevets.json";

// --- seuils : identiques à gen-check ------------------------------------
const DELAY_MAX = 0.30;
const QUEUE_MAX_CHECK = 4, QUEUE_HARD = 6, QUEUE_RATE_MAX = 0.12;
const QUEUE_MIN_DAYS = 2, QUEUE_ALPHA = 0.05;
function tailBinomiale(k, n, p) {
  if (k <= 0) return 1;
  if (k > n) return 0;
  let coef = 1, tot = 0;
  for (let i = 0; i <= n; i++) {
    if (i >= k) tot += coef * Math.pow(p, i) * Math.pow(1 - p, n - i);
    coef = coef * (n - i) / (i + 1);
  }
  return Math.min(1, tot);
}

// --- arguments -----------------------------------------------------------
let TOUT = false, ENFANT = false, GRAINES = [1, 2, 3], K = 30;
const cibles = process.argv.slice(2).filter(a => {
  if (a === "--tout") { TOUT = true; return false; }
  if (a === "--enfant") { ENFANT = true; return false; }
  const g = /^--graines=([\d,]+)$/.exec(a);
  if (g) { GRAINES = g[1].split(",").map(Number); return false; }
  const k = /^--k=(\d+)$/.exec(a);
  if (k) { K = parseInt(k[1], 10); return false; }
  if (a.startsWith("--")) { console.error("option inconnue : " + a); process.exit(2); }
  return true;
});

// --- catalogue -----------------------------------------------------------
const index = JSON.parse(read("data/stations/index.json"));
const PAYS = new Map();
for (const group of index) for (const id of group.stations) PAYS.set(id, group.country);
const ficheDe = id => JSON.parse(read(`data/stations/${PAYS.get(id)}/${id}.json`));

// --- tirage reproductible (le mulberry32 de gen-check) -------------------
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

// ========================================================================
// L'ENFANT : mesure une liste de gares, imprime le résultat en JSON.
// ========================================================================
if (ENFANT) {
  const mathShim = Object.create(Math);
  const sandbox = { Math: mathShim, console: { log() {}, warn() {}, error() {} }, JSON };
  sandbox.self = { onmessage: null, postMessage() {} };
  vm.createContext(sandbox);
  vm.runInContext(read("js/engine.js"), sandbox, { filename: "engine.js" });
  vm.runInContext(read("js/schedule.js"), sandbox, { filename: "schedule.js" });
  vm.runInContext(read("js/ruban.js"), sandbox, { filename: "ruban.js" });
  const simulateDay = vm.runInContext("simulateDay", sandbox);
  const platformPressure = vm.runInContext("platformPressure", sandbox);
  const bossEnv = vm.runInContext("ENVELOPPE_BOSS", sandbox);

  // K journées sous une enveloppe donnée, sur toute la batterie de graines.
  // Rend null si tout va bien, sinon la raison du refus.
  function mesurer(cfg) {
    vm.runInContext("loadStation(" + JSON.stringify(cfg) + ")", sandbox);
    let worst = 0, unplaceable = 0, errs = 0, queueMax = 0, queueDays = 0, days = 0;
    for (const graine of GRAINES) {
      mathShim.random = mulberry32(graine);
      for (let k = 0; k < K; k++) {
        try {
          const day = vm.runInContext("generateSchedule()", sandbox);
          const sched = day.schedule, assign = sched.map(s => s.hint);
          const res = simulateDay(sched, assign, 0.01, day.events);
          let tot = 0;
          for (let i = 0; i < sched.length; i++) {
            if (sched[i].freight) continue;
            if (res[i].depReal == null) { unplaceable++; continue; }
            tot += Math.max(0, res[i].depReal - sched[i].dep);
          }
          worst = Math.max(worst, tot);
          const q = platformPressure(sched, res);
          queueMax = Math.max(queueMax, q); days++;
          if (q > QUEUE_MAX_CHECK) queueDays++;
        } catch (e) { errs++; }
      }
    }
    if (errs) return errs + " journée(s) en erreur";
    if (unplaceable) return unplaceable + " train(s) non plaçable(s)";
    if (worst > DELAY_MAX) return "retard garanti " + worst.toFixed(2) + " > " + DELAY_MAX;
    if (queueMax >= QUEUE_HARD) return "file de " + queueMax + " au même quai";
    if (queueDays >= QUEUE_MIN_DAYS && queueDays / days > QUEUE_RATE_MAX &&
        tailBinomiale(queueDays, days, QUEUE_RATE_MAX) < QUEUE_ALPHA)
      return queueDays + "/" + days + " journées au-dessus de " + QUEUE_MAX_CHECK;
    return null;
  }

  const resultats = [];
  for (const id of cibles) {
    const cfg = ficheDe(id);
    const entry = { geometrie: empreinte(cfg), date: new Date().toISOString().slice(0, 10),
                    graines: GRAINES, K, niveau: 0, detail: {}, boss: null };

    // Connectivité d'abord : un portail ou un quai mort ne se brevette pas.
    vm.runInContext("loadStation(" + JSON.stringify(cfg) + ")", sandbox);
    const PAIRS = vm.runInContext("PAIRS", sandbox);
    const vivants = new Set(PAIRS.flat());
    const portailsMorts = Object.keys(cfg.portals).filter(p => !vivants.has(p));
    const quaisVivants = new Set();
    for (const [a, b] of PAIRS) for (const q of cfg.links[a]) if (cfg.links[b].includes(q)) quaisVivants.add(q);
    const quaisMorts = cfg.platforms.map(p => p.id).filter(q => !quaisVivants.has(q));
    if (portailsMorts.length || quaisMorts.length) {
      entry.detail.connectivite = [
        portailsMorts.length ? "portail mort : " + portailsMorts.join(", ") : "",
        quaisMorts.length ? "quai mort : " + quaisMorts.join(", ") : "",
      ].filter(Boolean).join(" ; ");
      resultats.push({ id, entry });
      continue;
    }

    // Les niveaux, du plancher au plafond de la géométrie. On s'arrête au
    // premier refus : les régimes au-dessus servent plus de trafic encore.
    sandbox.__cfg = cfg;
    const plafond = vm.runInContext("plafondDeFlux(this.__cfg)", sandbox);
    for (let n = 1; n <= plafond; n++) {
      const gen = vm.runInContext(`enveloppeDe(this.__cfg, ${n}, PROFILS[1])`, sandbox);
      const refus = mesurer({ ...cfg, difficulty: n, gen });
      entry.detail[n] = refus || "OK";
      if (refus) break;
      entry.niveau = n;
    }

    // Le régime boss (fin de chapitre) : l'enveloppe boss FONDUE au gen écrit,
    // le geste exact de ficheDeService.
    const refusBoss = mesurer({ ...cfg, difficulty: 5, gen: { ...cfg.gen, ...bossEnv } });
    entry.boss = refusBoss || "OK";

    resultats.push({ id, entry });
  }
  process.stdout.write("BREVET:" + JSON.stringify(resultats) + "\n");
  process.exit(0);
}

// ========================================================================
// LE PARENT : choisit les cibles, répartit sur les cœurs, fusionne, écrit.
// ========================================================================
let brevets = {};
try { brevets = JSON.parse(read(SORTIE)); } catch (e) { /* premier passage */ }

let aFaire;
if (cibles.length) aFaire = cibles.filter(id => PAYS.has(id));
else aFaire = [...PAYS.keys()].filter(id => {
  if (TOUT) return true;
  const b = brevets[id];
  return !b || b.geometrie !== empreinte(ficheDe(id));   // nouveau, ou modifié
});
const inconnues = cibles.filter(id => !PAYS.has(id));
if (inconnues.length) { console.error("gare(s) inconnue(s) : " + inconnues.join(", ")); process.exit(2); }
if (!aFaire.length) {
  console.log("brevet — rien à certifier : " + Object.keys(brevets).filter(k => !k.startsWith("_")).length +
              " brevet(s) à jour pour " + PAYS.size + " fiches.");
  process.exit(0);
}

const NPROC = Math.max(1, Math.min(8, (os.availableParallelism ? os.availableParallelism() : 4) - 1, aFaire.length));
console.log(`brevet — ${aFaire.length} fiche(s) à certifier, graines [${GRAINES.join(", ")}] × K=${K}, ${NPROC} processus.`);

// Répartition en tourniquet : les gros gabarits d'un même pays se suivent
// dans l'index, un découpage contigu chargerait un enfant de tous les boss.
const tranches = Array.from({ length: NPROC }, () => []);
aFaire.forEach((id, i) => tranches[i % NPROC].push(id));

const t0 = Date.now();
let faits = 0;
const fusion = await Promise.all(tranches.map(ids => new Promise((resolve, reject) => {
  const p = spawn(process.execPath, [SCRIPT, "--enfant", `--graines=${GRAINES.join(",")}`, `--k=${K}`, ...ids],
                  { cwd: ROOT, stdio: ["ignore", "pipe", "inherit"] });
  let out = "";
  p.stdout.on("data", d => { out += d; });
  p.on("close", code => {
    const ligne = out.split("\n").find(l => l.startsWith("BREVET:"));
    if (code !== 0 || !ligne) return reject(new Error("enfant en échec (" + ids.join(", ") + ")"));
    const res = JSON.parse(ligne.slice(7));
    faits += res.length;
    console.log(`  … ${faits}/${aFaire.length} (${Math.round((Date.now() - t0) / 1000)} s)`);
    resolve(res);
  });
})));

for (const { id, entry } of fusion.flat()) brevets[id] = entry;
brevets._doc = "Généré par tools/brevet.mjs — le niveau maximal certifié par fiche, mesuré " +
  "sur une batterie de graines fixes. Ne s'édite pas à la main : relancer l'outil " +
  "quand une géométrie ou un gen change (l'empreinte l'impose). Lu par carte-check (R10).";
const ordonne = {};
for (const k of Object.keys(brevets).sort()) ordonne[k] = brevets[k];
fs.writeFileSync(path.join(ROOT, SORTIE), JSON.stringify(ordonne, null, 1) + "\n");

// --- rapport -------------------------------------------------------------
const pad = (s, n) => String(s).padEnd(n);
console.log("\n" + pad("gare", 18) + pad("brevet", 8) + pad("boss", 6) + "détail");
console.log("-".repeat(70));
let echecs = 0;
for (const { id, entry } of fusion.flat().sort((a, b) => a.id.localeCompare(b.id))) {
  const souci = Object.entries(entry.detail).filter(([, v]) => v !== "OK").map(([n, v]) => n + " : " + v);
  if (entry.boss && entry.boss !== "OK") souci.push("boss : " + entry.boss);
  if (!entry.niveau) echecs++;
  console.log(pad(id, 18) + pad(entry.niveau || "—", 8) + pad(entry.boss === "OK" ? "✔" : "✘", 6) + souci.join(" ; "));
}
console.log("-".repeat(70));
console.log(echecs
  ? `\n${echecs} fiche(s) ne tiennent même pas le niveau 1 — à corriger avant toute carte.\n`
  : `\n${fusion.flat().length} brevet(s) écrits dans ${SORTIE}.\n`);
process.exit(echecs ? 1 : 0);
