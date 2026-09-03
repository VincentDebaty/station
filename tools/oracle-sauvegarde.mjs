// ------------------------------------------------------------------
// oracle-sauvegarde — LE PROTOTYPE JUGE LA SAUVEGARDE DE GODOT.
//
//     node tools/oracle-sauvegarde.mjs [--detail] [--fixture=<fichier.json> ...]
//
// js/store.js est évalué dans un node:vm avec un localStorage en mémoire ;
// jeu/sauvegarde.gd écrit dans un dossier de travail. Pour chaque sauvegarde
// de départ — une par schéma, de v0 (objet plat) à v7, plus les cas tordus :
// vide, null, JSON invalide, un nombre, une version en chaîne, une version
// future — les deux côtés :
//   1. migrent la sauvegarde (migrate / migrer) ;
//   2. la chargent (loadStore / charger), ce qui la réécrit si elle n'est
//      pas au schéma courant ;
//   3. jouent LA MÊME suite d'écritures (tentée, résultat, série, passage,
//      changement de carte, acquisition, préférences), en notant chaque
//      valeur rendue ;
//   4. relèvent l'état lu par le jeu, le FICHIER écrit, puis rechargent
//      depuis ce fichier et relèvent à nouveau.
// Tout est comparé. « --fixture » ajoute une vraie sauvegarde (par exemple
// la chaîne `station-progress` du localStorage d'un navigateur).
// ------------------------------------------------------------------
import { readFileSync, writeFileSync, mkdtempSync, existsSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
const TOL = 1e-9;
const GODOT = process.env.GODOT || "godot";

// --- les sauvegardes de départ : une par schéma, et les cas tordus --------------
const st = (s, b) => ({ stars: s, bestDelay: b });
const FIXTURES = [
  { nom: "absente", brut: null },
  { nom: "vide", brut: "" },
  { nom: "null", brut: "null" },
  { nom: "objet-vide", brut: "{}" },
  { nom: "json-invalide", brut: "{version:7" },
  { nom: "un-nombre", brut: "5" },
  { nom: "v0-plat", brut: JSON.stringify({ arlon: st(2, 7), namur: st(0, null), liege: st(3, 0) }) },
  { nom: "v2", brut: JSON.stringify({ version: 2, stations: { arlon: st(1, 25), namur: st(3, 0) }, opened: ["namur", "liege"] }) },
  { nom: "v3", brut: JSON.stringify({ version: 3, stations: { arlon: st(2, 9) }, bought: ["arlon", "namur"], credits: 40 }) },
  { nom: "v4", brut: JSON.stringify({ version: 4, stations: { arlon: st(2, 9), dinant: st(1, 28) }, bought: ["arlon"], credits: 12, ponctualite: 300, serie: { n: 2, record: 5 } }) },
  { nom: "v5", brut: JSON.stringify({ version: 5, stations: { arlon: st(3, 0), namur: st(2, 11), york: st(1, 22) }, bought: ["arlon", "namur", "york"], serie: { n: "3", record: 4.7 } }) },
  { nom: "v5-serie-tordue", brut: JSON.stringify({ version: 5, stations: {}, serie: { n: -2, record: "abc" } }) },
  { nom: "v6", brut: JSON.stringify({ version: 6, carteCourante: "europe", cartes: {
    europe: { stations: { darlington: st(3, 0), york: st(2, 14) }, bought: ["darlington", "york", "leeds"], serie: { n: 1, record: 1 } },
    germanie: null }, possedees: {} }) },
  { nom: "v7", brut: JSON.stringify({ version: 7, carteCourante: "germanie", cartes: {
    europe: { stations: { darlington: st(3, 0), middlesbrough: st(1, 27) }, passees: ["northallerton"], serie: { n: 0, record: 3 } },
    germanie: { stations: { mons: st(2, 12) }, passees: [], serie: { n: 1, record: 1 } } },
    possedees: { europe: "gratuite", germanie: "credits" } }) },
  { nom: "v7-lacunaire", brut: JSON.stringify({ version: 7, carteCourante: "", cartes: { germanie: { stations: { mons: st(2, 12) } } }, possedees: { germanie: "achat" } }) },
  { nom: "version-en-chaine", brut: JSON.stringify({ version: "7", stations: { arlon: st(2, 9) }, cartes: { europe: { stations: { york: st(3, 0) } } } }) },
  { nom: "version-future", brut: JSON.stringify({ version: 8, stations: { arlon: st(2, 9) }, cartes: { europe: { stations: { york: st(3, 0) } } }, serie: { n: 4, record: 4 } }) },
  { nom: "cartes-en-tableau", brut: JSON.stringify({ version: 7, cartes: [{ stations: { york: st(2, 5) } }] }) }
];
for (const f of args.filter(a => a.startsWith("--fixture=")).map(a => a.slice(10)))
  FIXTURES.push({ nom: "fixture:" + f.split("/").pop(), brut: readFileSync(f, "utf8") });

// LA MÊME SUITE D'ÉCRITURES POUR TOUS — elle passe par chaque chemin : une gare
// tentée puis gagnée, un record amélioré puis non, une série qui monte, bat
// son record et casse, un passage payé deux fois, un changement de carte
// (puis le même, puis vide), une acquisition (puis la même), les préférences.
const OPS = [
  ["markTentee", "darlington"], ["markTentee", "darlington"], ["markTentee", ""],
  ["saveResult", "darlington", 2, 12], ["saveResult", "darlington", 1, 30], ["saveResult", "darlington", 3, 0],
  ["saveResult", "york", 1, 25],
  ["pushSerie", true], ["pushSerie", true], ["pushSerie", false], ["pushSerie", true],
  ["payerPassage", "leeds"], ["payerPassage", "leeds"], ["payerPassage", ""],
  ["setCarteCourante", "germanie"], ["setCarteCourante", "germanie"], ["setCarteCourante", ""],
  ["markTentee", "mons"], ["saveResult", "mons", 2, 8], ["pushSerie", false], ["payerPassage", "aachen"],
  ["acquerirCarte", "germanie", "credits"], ["acquerirCarte", "germanie", "achat"], ["acquerirCarte", "", "achat"],
  ["setCarteCourante", "europe"], ["saveResult", "darlington", 3, 4],
  ["setMuted", true], ["setOnboarded", true], ["setMuted", false]
];

// --- côté prototype : localStorage en mémoire, window sans Capacitor -----------
const memoire = new Map();
const sandbox = {
  console, JSON, Math, Promise,
  window: {},
  localStorage: {
    getItem: k => memoire.has(k) ? memoire.get(k) : null,
    setItem: (k, v) => { memoire.set(k, String(v)); }
  }
};
createContext(sandbox);
runInContext(readFileSync(join(RACINE, "js/store.js"), "utf8"), sandbox, { filename: "store.js" });
runInContext(`
async function __jouer(brut, ops) {
  let parsed = null;
  try { parsed = brut ? JSON.parse(brut) : null; } catch (e) { parsed = null; }
  const migre = JSON.parse(JSON.stringify(migrate(parsed)));
  await loadStore();
  const rets = [];
  for (const [f, ...a] of ops) { const r = globalThis[f](...a); rets.push(r === undefined ? null : r); }
  const etat = () => JSON.parse(JSON.stringify({ progression: getProgress(), passees: getPassees(), serie: getSerie(),
    carte: getCarteCourante(), possedees: cartesPossedees(), cartes: getCartesEnregistrees(),
    muet: getMuted(), accueilli: getOnboarded() }));
  const e1 = etat();
  const fichier = JSON.parse(localStorage.getItem("station-progress"));
  await loadStore();
  return { migre, ops: rets, etat: e1, fichier, rechargement: etat(),
    muetEcrit: localStorage.getItem("station-muted"), accueilliEcrit: localStorage.getItem("station-onboarded") };
}`, sandbox, { filename: "jouer.js" });
async function jouerJS(fx) {
  memoire.clear();
  if (fx.brut !== null) memoire.set("station-progress", fx.brut);
  sandbox.__brut = fx.brut; sandbox.__ops = OPS;
  return JSON.parse(JSON.stringify(await runInContext("__jouer(__brut, __ops)", sandbox)));
}

// --- côté Godot : un seul démarrage ----------------------------------------------
const sortie = mkdtempSync(join(tmpdir(), "oracle-sauvegarde-"));
const fichierCas = join(sortie, "cas.json");
writeFileSync(fichierCas, JSON.stringify({ fixtures: FIXTURES, ops: OPS }));
const t0 = Date.now();
const r = spawnSync(GODOT, ["--headless", "--path", RACINE, "--script", "res://jeu/oracle_sauvegarde.gd", "--", sortie, fichierCas],
  { encoding: "utf8", maxBuffer: 1 << 26, timeout: 5 * 60 * 1000 });
const sortieGodot = ((r.stdout || "") + "\n" + (r.stderr || "")).trim();
if (r.status !== 0 || /SCRIPT ERROR|^ERROR:|Parse Error/m.test(sortieGodot)) {
  console.error("Godot a refusé (code " + r.status + ") :\n" +
    sortieGodot.split("\n").filter(l => !/^Godot Engine|^$/.test(l)).join("\n"));
  process.exit(1);
}
const dureeGodot = Date.now() - t0;

// --- la comparaison ---------------------------------------------------------------
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
      if (!(k in a) && b[k] === null) continue;
      if (!(k in b) && a[k] === null) continue;
      if (!(k in a) || !(k in b)) { ecarts.push(`${ou}.${k} : ${k in a ? "absent côté Godot" : "absent côté JS"}`); continue; }
      comparer(a[k], b[k], `${ou}.${k}`, ecarts);
    }
    return;
  }
  if (a !== b) ecarts.push(`${ou} : js=${JSON.stringify(a)} godot=${JSON.stringify(b)}`);
}

let ok = 0, ko = 0;
const lignes = [];
for (let i = 0; i < FIXTURES.length; i++) {
  const fx = FIXTURES[i];
  const js = await jouerJS(fx);
  const f = join(sortie, `cas-${i}.json`);
  if (!existsSync(f)) { ko++; lignes.push(`  ✘ ${fx.nom.padEnd(20)} Godot n'a rien écrit`); continue; }
  const gd = JSON.parse(readFileSync(f, "utf8"));
  const ecarts = [];
  comparer(js, gd, fx.nom, ecarts);
  const nStations = Object.keys(js.migre.cartes.europe ? js.migre.cartes.europe.stations : {}).length;
  const resume = `migrée : ${Object.keys(js.migre.cartes).length} carte(s), ${nStations} gare(s) en Europe · après ${OPS.length} écritures : série ${js.etat.serie.n}/${js.etat.serie.record}, carte ${js.etat.carte}`;
  if (ecarts.length) {
    ko++;
    const n = opt("detail") ? 60 : 6;
    lignes.push(`  ✘ ${fx.nom.padEnd(20)} ${ecarts.length} écart(s) — ${resume}`);
    for (const e of ecarts.slice(0, n)) lignes.push(`      ${e}`);
    if (ecarts.length > n) lignes.push(`      … ${ecarts.length - n} de plus`);
  } else { ok++; lignes.push(`  ✔ ${fx.nom.padEnd(20)} ${resume}`); }
}
console.log(`oracle-sauvegarde — ${FIXTURES.length} sauvegardes de départ × ${OPS.length} écritures, store.js contre jeu/sauvegarde.gd (Godot en ${dureeGodot} ms)`);
for (const l of lignes) console.log(l);
console.log(`  ${ok} identique(s), ${ko} divergente(s)`);
process.exit(ko ? 1 : 0);
