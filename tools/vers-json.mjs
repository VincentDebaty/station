// ------------------------------------------------------------------
// vers-json — DÉRIVER EN JSON les données déclarées en JavaScript.
//
//     node tools/vers-json.mjs
//
// Quatre fichiers du jeu déclarent leurs données en `const` dans un script
// classique : js/geo.js (GEO), data/lines.js (LINES, LINE_COUNTRIES),
// data/places.js (PLACES, PLACE_ALIASES) et data/worldmap.js (WORLDMAP).
// Le navigateur les lit tels quels ; Godot, non.
//
// POURQUOI DÉRIVER PLUTÔT QUE CONVERTIR. Convertir une fois, ce serait créer
// une DEUXIÈME source qui dérive de la première au premier changement — le
// risque que ce projet évite depuis six mois en ne gardant qu'une copie de
// chaque donnée. Ici le JS reste la source, le JSON en découle, et le
// prototype n'est pas touché. Relancer l'outil suffit.
//
// La lecture se fait en `node:vm`, exactement comme tools/net-check.mjs — les
// fichiers déclarent en `const`, donc invisible sans contexte d'exécution.
// ------------------------------------------------------------------
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const SORTIE = join(RACINE, "data/derive");

const SOURCES = [
  ["js/geo.js",         { GEO: "geo" }],
  ["data/lines.js",     { LINES: "lines", LINE_COUNTRIES: "line-countries" }],
  ["data/places.js",    { PLACES: "places", PLACE_ALIASES: "place-aliases" }],
  ["data/worldmap.js",  { WORLDMAP: "worldmap" }]
];

mkdirSync(SORTIE, { recursive: true });
const ctx = createContext({ console, window: {} });
const ecrits = [];

for (const [fichier, globales] of SOURCES) {
  let src;
  try { src = readFileSync(join(RACINE, fichier), "utf8"); }
  catch { console.error(`introuvable : ${fichier}`); process.exit(1); }
  runInContext(src, ctx, { filename: fichier });
  for (const [globale, nom] of Object.entries(globales)) {
    const v = runInContext(`typeof ${globale} !== "undefined" ? ${globale} : null`, ctx);
    if (v === null) { console.error(`${fichier} : ${globale} non défini`); process.exit(1); }
    const cible = join(SORTIE, nom + ".json");
    writeFileSync(cible, JSON.stringify(v));
    const taille = JSON.stringify(v).length;
    ecrits.push([nom + ".json", taille, Array.isArray(v) ? v.length + " entrées" : Object.keys(v).length + " clés"]);
  }
}

// Un manifeste, pour que le côté Godot sache ce qu'il peut charger sans
// deviner — et pour qu'un fichier oublié se voie.
writeFileSync(join(SORTIE, "index.json"),
  JSON.stringify({ derive_le: new Date().toISOString().slice(0, 10),
                   depuis: SOURCES.map(([f]) => f),
                   fichiers: ecrits.map(([n]) => n) }, null, 1));

console.log(`dérivé dans data/derive/ :`);
for (const [n, t, c] of ecrits) console.log(`  ${n.padEnd(20)} ${String(Math.round(t/1024)).padStart(5)} Ko   ${c}`);
console.log(`  index.json           (manifeste)`);
