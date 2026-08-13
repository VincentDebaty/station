// ------------------------------------------------------------------
// eco-check — contrôle du SEUIL D'ÉQUILIBRE de l'économie, sans navigateur.
//
// Charge le VRAI barème (js/catalog.js) dans un contexte Node — jamais une
// copie des formules, qui dériverait au premier réglage — puis vérifie, pour
// le catalogue entier :
//
//   1. par gare   : prix < tarif. Un service à trois étoiles doit toujours
//                   rembourser la gare, sinon la maîtrise ne paie plus.
//   2. par gare   : prix < plafond. Sans quoi une gare ne pourrait jamais se
//                   financer, même jouée à la perfection.
//   3. par pays   : coût total < recette totale à trois étoiles. Un pays qu'on
//                   ne peut pas s'offrir en le maîtrisant est un cul-de-sac.
//   4. global     : le MULTIPLICATEUR MOYEN REQUIS (coût ÷ recette à ★★★).
//                   C'est le vrai visage du réglage : 0,81 aujourd'hui, soit
//                   un peu mieux que deux étoiles. Au-delà de 1, il faudrait
//                   des services parfaits pour finir — le jeu deviendrait
//                   décourageant sans que rien ne « casse ».
//
// Usage :  node tools/eco-check.mjs
//
// Sortie : un tableau par pays + le seuil global. Code de sortie ≠ 0 si un
// contrôle échoue (utilisable en pre-commit / CI, comme gen-check).
// ------------------------------------------------------------------
import fs from "fs";
import path from "path";
import vm from "vm";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = f => fs.readFileSync(path.join(ROOT, f), "utf8");

// --- Catalogue : les fiches, dans l'ordre de jeu de index.json. ---
const index = JSON.parse(read("data/stations/index.json"));
const CATALOG = [];
for (const group of index)
  for (const id of group.stations)
    CATALOG.push(JSON.parse(read(`data/stations/${group.country}/${id}.json`)));

// --- Le resserrement des arrivées vit dans le générateur ; le barème s'en
//     sert pour le flux. On le prend à la source plutôt que de le recopier. ---
const m = /const ARRIVAL_GAP_SCALE\s*=\s*([\d.]+)/.exec(read("js/schedule.js"));
if (!m) { console.error("ARRIVAL_GAP_SCALE introuvable dans js/schedule.js"); process.exit(2); }

// --- Le vrai barème, chargé tel quel. Les fonctions de progression sont
//     bouchonnées : ici on mesure le catalogue, pas une partie en cours. ---
const sandbox = {
  __cards: CATALOG,
  ARRIVAL_GAP_SCALE: parseFloat(m[1]),
  getProgress: () => ({}),
  isBought: () => false,
  getCredits: () => 0,
  buyStation: () => false,
  netLinks: () => ({ to: [], places: [] }),
  fetch: () => { throw new Error("eco-check ne charge pas le catalogue par le réseau"); },
  console
};
vm.createContext(sandbox);
vm.runInContext(read("js/catalog.js"), sandbox, { filename: "catalog.js" });
// catalog.js déclare son propre CATALOG (vide, rempli par fetch dans le
// navigateur) : on le remplit ici à la main, sans quoi le barème ne verrait
// aucune gare et rendrait la difficulté 1 pour tout le monde.
vm.runInContext("CATALOG.push(...__cards)", sandbox);
// `const` de haut niveau : ces déclarations n'apparaissent pas sur l'objet du
// bac à sable, il faut les lire dans le contexte.
const get = expr => vm.runInContext(expr, sandbox);
const stationTarif = get("stationTarif"), stationPrice = get("stationPrice"),
      stationCap = get("stationCap"),
      PRIX_RATIO = get("PRIX_RATIO"), CREDITS_START = get("CREDITS_START");

// ------------------------------------------------------------------
const fmt = n => String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
const pad = (s, n) => String(s).padEnd(n);
const padL = (s, n) => String(s).padStart(n);

let fails = 0;
const fail = msg => { fails++; console.log("  ✗ " + msg); };

// --- 1 et 2 : contrôles par gare. ---
for (const c of CATALOG) {
  const t = stationTarif(c.id), p = stationPrice(c.id), cap = stationCap(c.id);
  if (p >= t) fail(`${c.id} : prix ${p} ≥ tarif ${t} — un ★★★ ne rembourse pas la gare`);
  if (p >= cap) fail(`${c.id} : prix ${p} ≥ plafond ${cap} — gare impossible à financer`);
}

// --- 3 et 4 : agrégats par pays. ---
const by = new Map();
for (const c of CATALOG) {
  const k = c.country || "?";
  if (!by.has(k)) by.set(k, { n: 0, cost: 0, tarif: 0 });
  const g = by.get(k);
  g.n++; g.cost += stationPrice(c.id); g.tarif += stationTarif(c.id);
}

console.log("");
console.log(pad("PAYS", 16) + padL("GARES", 6) + padL("COÛT", 9) +
            padL("★", 9) + padL("★★", 9) + padL("★★★", 9) + padL("SEUIL", 8));
console.log("─".repeat(66));
let N = 0, COST = 0, TARIF = 0;
for (const [k, g] of by) {
  N += g.n; COST += g.cost; TARIF += g.tarif;
  if (g.cost >= g.tarif) fail(`${k} : coût ${g.cost} ≥ recette à ★★★ ${g.tarif} — pays incomplétable`);
  console.log(pad(k, 16) + padL(g.n, 6) + padL(fmt(g.cost), 9) +
    padL(fmt(g.tarif * 0.5), 9) + padL(fmt(g.tarif * 0.75), 9) + padL(fmt(g.tarif), 9) +
    padL((g.cost / g.tarif).toFixed(2), 8));
}
console.log("─".repeat(66));
console.log(pad("TOTAL", 16) + padL(N, 6) + padL(fmt(COST), 9) +
  padL(fmt(TARIF * 0.5), 9) + padL(fmt(TARIF * 0.75), 9) + padL(fmt(TARIF), 9) +
  padL((COST / TARIF).toFixed(2), 8));

// --- Le seuil, en clair. ---
const seuil = COST / TARIF;
const palier = seuil <= 0.5 ? "une étoile suffit"
  : seuil <= 0.75 ? "entre une et deux étoiles"
  : seuil <= 1 ? "entre deux et trois étoiles"
  : "PLUS que trois étoiles — le jeu exige des services parfaits";
console.log("");
console.log(`Prix = ${Math.round(PRIX_RATIO * 100)} % du tarif · dotation de départ ${CREDITS_START}`);
console.log(`Seuil d'équilibre : ${(seuil * 100).toFixed(0)} % du tarif en moyenne — ${palier}.`);
console.log(`Masse monétaire maximale : ${fmt(TARIF * 2)} · dépenses obligatoires : ${fmt(COST)}.`);
if (seuil > 1) fail("le seuil dépasse 100 % : le réseau ne peut pas être complété");

console.log("");
console.log(fails ? `✗ ${fails} contrôle(s) en échec` : "✓ économie cohérente");
process.exit(fails ? 1 : 0);
