// ------------------------------------------------------------------
// oracle-journee — LE PROTOTYPE JUGE LA JOURNÉE TIRÉE PAR GODOT.
//
//     node tools/oracle-journee.mjs darlington [autre-id ...]
//     node tools/oracle-journee.mjs darlington --seeds=1,2,3
//     node tools/oracle-journee.mjs --tous --seeds=1
//
// Pour chaque fiche et chaque graine, la même journée est tirée deux fois :
// par js/schedule.js (évalué dans un node:vm, Math.random remplacé par le
// mulberry32 de gen-check — le sandbox de gen-check, à l'identique) et par
// jeu/journee.gd (via jeu/oracle_journee.gd, Godot sans fenêtre, toutes les
// fiches en un démarrage). Puis comparaison convoi par convoi : id, origine,
// destination, wagons, arrivée, départ officiel, quai de calibrage, retard
// effectif, fret — et les événements.
//
// UNE JOURNÉE N'EST PAS « PROCHE » : elle est la même ou elle ne l'est pas.
// Le premier tirage qui diverge entraîne tous les suivants, donc un écart
// est presque toujours massif. La tolérance de 1e-9 sur les flottants ne
// sert qu'à absorber le dernier bit de exp() — V8 a sa propre bibliothèque
// mathématique, Godot celle du système — sans jamais masquer une divergence
// de formule ou d'ordre de tirage.
// ------------------------------------------------------------------
import { readFileSync, mkdtempSync, existsSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const lire = p => JSON.parse(readFileSync(join(RACINE, p), "utf8"));
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
const TOL = 1e-9;
const GODOT = process.env.GODOT || "godot";
const SEEDS = String(opt("seeds") || "1").split(",").map(Number);

// --- quelles fiches ---------------------------------------------------------
const index = lire("data/stations/index.json");
const paysDe = new Map();
for (const g of index) for (const id of g.stations) paysDe.set(id, g.country);
let ids = args.filter(a => !a.startsWith("--"));
if (opt("tous")) ids = [...paysDe.keys()];
if (!ids.length) { console.error("usage : node tools/oracle-journee.mjs <id ...> | --tous [--seeds=1,2] [--detail]"); process.exit(2); }
for (const id of ids) if (!paysDe.has(id)) { console.error(`inconnue à l'index : ${id}`); process.exit(2); }
const chemin = id => `data/stations/${paysDe.get(id)}/${id}.json`;

// --- côté prototype : le sandbox de gen-check, à l'identique ----------------
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
const mathShim = Object.create(Math);
const sandbox = { Math: mathShim, console, JSON };
createContext(sandbox);
runInContext(readFileSync(join(RACINE, "js/engine.js"), "utf8"), sandbox, { filename: "engine.js" });
runInContext(readFileSync(join(RACINE, "js/schedule.js"), "utf8"), sandbox, { filename: "schedule.js" });
function journeeJS(fiche, seed) {
  mathShim.random = mulberry32(seed);
  sandbox.__fiche = fiche;
  const t0 = Date.now();
  const day = JSON.parse(runInContext(`loadStation(__fiche); JSON.stringify(generateSchedule())`, sandbox));
  day._duree_ms = Date.now() - t0;
  return day;
}

// --- côté Godot : un seul démarrage ----------------------------------------
const sortie = mkdtempSync(join(tmpdir(), "oracle-journee-"));
const t0 = Date.now();
const r = spawnSync(GODOT, ["--headless", "--path", RACINE, "--script", "res://jeu/oracle_journee.gd", "--",
  sortie, SEEDS.join(","), ...ids.map(id => join(RACINE, chemin(id)))],
  { encoding: "utf8", maxBuffer: 1 << 26, timeout: 60 * 60 * 1000 });
const sortieGodot = ((r.stdout || "") + "\n" + (r.stderr || "")).trim();
if (r.status !== 0 || /SCRIPT ERROR|^ERROR:|Parse Error/m.test(sortieGodot)) {
  console.error("Godot a refusé (code " + r.status + ") :\n" +
    sortieGodot.split("\n").filter(l => !/^Godot Engine|^$/.test(l)).join("\n"));
  process.exit(1);
}
const dureeGodot = Date.now() - t0;

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
    if (a.length !== b.length) { ecarts.push(`${ou} : ${a.length} contre ${b.length} éléments`); return; }
    a.forEach((x, i) => comparer(x, b[i], `${ou}[${i}]`, ecarts));
    return;
  }
  if (a && b && typeof a === "object" && typeof b === "object") {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      if (k.startsWith("_")) continue;
      if (!(k in a) && b[k] === null) continue;
      if (!(k in b) && a[k] === null) continue;
      if (!(k in a) || !(k in b)) { ecarts.push(`${ou}.${k} : ${k in a ? "absent côté Godot" : "absent côté JS"}`); continue; }
      comparer(a[k], b[k], `${ou}.${k}`, ecarts);
    }
    return;
  }
  if (a !== b) ecarts.push(`${ou} : js=${JSON.stringify(a)} godot=${JSON.stringify(b)}`);
}

let ok = 0, ko = 0, msJS = 0, msGD = 0;
const lignes = [];
for (const id of ids) {
  const fiche = lire(chemin(id));
  for (const seed of SEEDS) {
    const js = journeeJS(fiche, seed);
    msJS += js._duree_ms;
    const f = join(sortie, `${id}-${seed}.json`);
    if (!existsSync(f)) { ko++; lignes.push(`  ✘ ${id}·${seed}`.padEnd(30) + "Godot n'a rien écrit"); continue; }
    const gd = JSON.parse(readFileSync(f, "utf8"));
    msGD += gd._duree_ms || 0;
    const ecarts = [];
    comparer(js, gd, `${id}·${seed}`, ecarts);
    const resume = `${js.schedule.length} convois · ${js.events.length} évén. · js ${js._duree_ms} ms / godot ${gd._duree_ms} ms`;
    if (ecarts.length) {
      ko++;
      lignes.push(`  ✘ ${(id + "·" + seed).padEnd(26)} ${ecarts.length} écart(s) — ${resume}`);
      for (const e of ecarts.slice(0, opt("detail") ? 40 : 5)) lignes.push(`      ${e}`);
      if (ecarts.length > (opt("detail") ? 40 : 5)) lignes.push(`      … ${ecarts.length - (opt("detail") ? 40 : 5)} de plus`);
    } else {
      ok++;
      if (!opt("tous") || opt("detail")) lignes.push(`  ✔ ${(id + "·" + seed).padEnd(26)} ${resume}`);
    }
  }
}
console.log(`oracle-journee — ${ids.length} fiche(s) × ${SEEDS.length} graine(s), schedule.js contre jeu/journee.gd (Godot en ${dureeGodot} ms)`);
for (const l of lignes) console.log(l);
console.log(`  ${ok} identique(s), ${ko} divergente(s) — génération : js ${msJS} ms, godot ${msGD} ms`);
process.exit(ko ? 1 : 0);
