// ------------------------------------------------------------------
// oracle-geometrie — LE PROTOTYPE JUGE LE PORTAGE, point par point.
//
//     node tools/oracle-geometrie.mjs darlington [autre-id ...]
//     node tools/oracle-geometrie.mjs --tous
//     node tools/oracle-geometrie.mjs --tous --detail
//
// Pour chaque fiche, deux calculs de la même géométrie : celui de js/engine.js
// (loadStation, évalué dans un node:vm comme le fait net-check) et celui de
// jeu/geometrie.gd (via jeu/oracle_geometrie.gd, Godot sans fenêtre). Puis une
// comparaison récursive : quais, portails, chemins point par point, abscisses
// cumulées, longueurs, durées, voies d'approche et de départ, zones de
// conflit, liaisons autorisées.
//
// C'est l'idée qui rend ce portage sûr (PORTAGE-GODOT.md §8) : le prototype
// est une implémentation de référence, déterministe, qui tourne à côté. Une
// géométrie « qui a l'air bonne » ne vaut rien ; une géométrie qui rend les
// mêmes 17 chiffres qu'engine.js sur 401 fiches, si.
//
// Tolérance : 1e-6 en absolu. Les deux côtés calculent en double avec le même
// ordre d'opérations ; la seule différence connue est Math.hypot contre
// sqrt(dx²+dy²), qui diffèrent au dernier bit. Un écart au-delà de 1e-6 est
// une divergence de FORMULE, jamais d'arrondi — et il refuse.
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
const opt = n => args.includes("--" + n);
const TOL = 1e-6;
const GODOT = process.env.GODOT || "godot";

// --- quelles fiches ---------------------------------------------------------
const index = lire("data/stations/index.json");
const paysDe = new Map();
for (const g of index) for (const id of g.stations) paysDe.set(id, g.country);
let ids = args.filter(a => !a.startsWith("--"));
if (opt("tous")) ids = [...paysDe.keys()];
if (!ids.length) { console.error("usage : node tools/oracle-geometrie.mjs <id ...> | --tous [--detail]"); process.exit(2); }
for (const id of ids) if (!paysDe.has(id)) { console.error(`inconnue à l'index : ${id}`); process.exit(2); }
const chemin = id => `data/stations/${paysDe.get(id)}/${id}.json`;

// --- côté prototype : engine.js dans un vm ---------------------------------
const ctx = createContext({ console });
runInContext(readFileSync(join(RACINE, "js/engine.js"), "utf8"), ctx, { filename: "js/engine.js" });
function geometrieJS(fiche) {
  ctx.__fiche = fiche;
  return runInContext(`loadStation(__fiche);
    ({ PLATFORMS, PORTALS, DEST_COLOR, DEST_ABBR, LINKS, paths, APPROACH, DEPART, conflicts, PAIRS })`, ctx);
}

// --- côté Godot : un seul démarrage pour toutes les fiches ------------------
const sortie = mkdtempSync(join(tmpdir(), "oracle-geometrie-"));
const t0 = Date.now();
const r = spawnSync(GODOT, ["--headless", "--path", RACINE, "--script", "res://jeu/oracle_geometrie.gd", "--",
  sortie, ...ids.map(id => join(RACINE, chemin(id)))], { encoding: "utf8", maxBuffer: 1 << 26 });
// GODOT REND 0 SUR UNE ERREUR DE SCRIPT en mode --script (constaté le 3
// septembre 2026 : un `class_name` non résolu, « Parse Error », exit 0, aucun
// fichier écrit). Le code de sortie ne suffit donc pas : on lit la sortie.
const sortieGodot = ((r.stdout || "") + "\n" + (r.stderr || "")).trim();
const erreurGodot = r.status !== 0 || /SCRIPT ERROR|^ERROR:|Parse Error/m.test(sortieGodot);
if (erreurGodot) {
  console.error("Godot a refusé (code " + r.status + ") :\n" +
    sortieGodot.split("\n").filter(l => !/^Godot Engine|^$/.test(l)).join("\n"));
  process.exit(1);
}
const dureeGodot = Date.now() - t0;

// --- la comparaison ---------------------------------------------------------
// Rend la liste des écarts ; [] = identiques à la tolérance près.
function comparer(a, b, ou, ecarts, max) {
  if (a === undefined) a = null;
  if (b === undefined) b = null;
  if (typeof a === "number" && typeof b === "number") {
    const d = Math.abs(a - b);
    if (d > max.v) max.v = d;
    if (d > TOL || Number.isNaN(d)) ecarts.push(`${ou} : js=${a} godot=${b}`);
    return;
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b)) { ecarts.push(`${ou} : types`); return; }
    if (a.length !== b.length) { ecarts.push(`${ou} : ${a.length} contre ${b.length} éléments`); return; }
    a.forEach((x, i) => comparer(x, b[i], `${ou}[${i}]`, ecarts, max));
    return;
  }
  if (a && b && typeof a === "object" && typeof b === "object") {
    const ka = Object.keys(a).sort(), kb = Object.keys(b).sort();
    for (const k of new Set([...ka, ...kb])) {
      if (!(k in a) && b[k] === null) continue;      // undefined côté JS, null côté Godot
      if (!(k in b) && a[k] === null) continue;
      if (!(k in a) || !(k in b)) { ecarts.push(`${ou}.${k} : ${k in a ? "absent côté Godot" : "absent côté JS"}`); continue; }
      comparer(a[k], b[k], `${ou}.${k}`, ecarts, max);
    }
    return;
  }
  if (a !== b) ecarts.push(`${ou} : js=${JSON.stringify(a)} godot=${JSON.stringify(b)}`);
}
// PAIRS est une liste ordonnée par l'itération des portails ; on la juge
// comme un ensemble — l'ordre n'a pas de sens de jeu.
const enEnsemble = pairs => [...pairs].map(p => p.join(">")).sort();

let ok = 0, ko = 0, pire = 0;
const lignes = [];
for (const id of ids) {
  const js = geometrieJS(lire(chemin(id)));
  js.PAIRS = enEnsemble(js.PAIRS);
  const f = join(sortie, id + ".json");
  if (!existsSync(f)) { ko++; lignes.push(`  ✘ ${id.padEnd(22)} Godot n'a rien écrit`); continue; }
  const gd = JSON.parse(readFileSync(f, "utf8"));
  gd.PAIRS = enEnsemble(gd.PAIRS);
  const ecarts = [], max = { v: 0 };
  comparer(js, gd, id, ecarts, max);
  pire = Math.max(pire, max.v);
  const nPts = Object.values(js.paths).reduce((n, p) => n + p.pts.length, 0);
  if (ecarts.length) {
    ko++;
    lignes.push(`  ✘ ${id.padEnd(22)} ${ecarts.length} écart(s) — max ${max.v.toExponential(2)}`);
    if (opt("detail")) for (const e of ecarts.slice(0, 12)) lignes.push(`      ${e}`);
    if (opt("detail") && ecarts.length > 12) lignes.push(`      … ${ecarts.length - 12} de plus`);
  } else {
    ok++;
    if (!opt("tous") || opt("detail"))
      lignes.push(`  ✔ ${id.padEnd(22)} ${Object.keys(js.paths).length} chemins · ${nPts} points · max Δ ${max.v.toExponential(1)}`);
  }
}
console.log(`oracle-geometrie — ${ids.length} fiche(s), engine.js contre jeu/geometrie.gd (Godot en ${dureeGodot} ms)`);
for (const l of lignes) console.log(l);
console.log(`  ${ok} identique(s) à ${TOL} près, ${ko} divergente(s) — pire écart ${pire.toExponential(2)}`);
process.exit(ko ? 1 : 0);
