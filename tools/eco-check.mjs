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
      stationCap = get("stationCap"), PALIERS = get("PALIERS"),
      palierAmount = get("palierAmount"), palierOf = get("palierOf"),
      stationPayout = get("stationPayout"),
      PRIX_RATIO = get("PRIX_RATIO"), CREDITS_START = get("CREDITS_START");
// LES COLONNES SORTENT DES PALIERS, elles ne les redisent pas. Écrits en dur,
// les multiplicateurs 0,5 / 0,75 ont survécu au passage aux paliers
// géométriques : le tableau aurait annoncé une recette que le jeu ne verse
// plus. Un vérificateur qui a sa propre copie du barème ne vérifie rien.
const M1 = PALIERS[0].mult, M2 = PALIERS[1].mult, M3 = PALIERS[2].mult;

// ------------------------------------------------------------------
const fmt = n => String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
const pad = (s, n) => String(s).padEnd(n);
const padL = (s, n) => String(s).padStart(n);

let fails = 0;
const fail = msg => { fails++; console.log("  ✗ " + msg); };

// --- 1 à 6 : contrôles par gare. ---
//
// LES QUATRE DERNIERS PORTENT SUR LE PALMARÈS, et ils ne sont pas décoratifs :
// c'est un arrondi d'un seul crédit qui a fait redescendre l'échelle de Dinant
// entre une et deux étoiles (13 puis 12). Un barème ne se relit pas à l'œil sur
// 145 gares — il se vérifie.
for (const c of CATALOG) {
  const t = stationTarif(c.id), p = stationPrice(c.id), cap = stationCap(c.id);
  if (p >= t) fail(`${c.id} : prix ${p} ≥ tarif ${t} — un ★★★ ne rembourse pas la gare`);
  if (p >= cap) fail(`${c.id} : prix ${p} ≥ plafond ${cap} — gare impossible à financer`);

  const pal = PALIERS.map((_, i) => palierAmount(c.id, i));
  // a) l'échelle ne redescend JAMAIS : mieux jouer ne peut pas rapporter moins.
  for (let i = 1; i < pal.length; i++)
    if (pal[i] < pal[i - 1])
      fail(`${c.id} (tarif ${t}) : palier ${i + 1} (${pal[i]}) < palier ${i} (${pal[i - 1]}) — l'échelle redescend`);
  // b) aucun palier gratuit : une ligne à 0 se lirait comme une promesse vide.
  if (pal.some(x => x <= 0)) fail(`${c.id} : un palier ne rapporte rien — ${pal.join(" · ")}`);
  // c) la somme des paliers EST le plafond : pas un crédit perdu en arrondi.
  const somme = pal.reduce((a, b) => a + b, 0);
  if (somme !== cap) fail(`${c.id} : somme des paliers ${somme} ≠ plafond ${cap}`);
  // d) ce que le palmarès promet est ce que la recette verse, à tout retard.
  for (const d of [null, 0, 4, 9, 12, 19, 25, 29, 33]) {
    const k = palierOf(d);
    const cumul = pal.slice(0, k + 1).reduce((a, b) => a + b, 0);
    if (cumul !== stationPayout(c.id, d))
      fail(`${c.id} : à +${d} min le palmarès promet ${cumul}, la recette verse ${stationPayout(c.id, d)}`);
  }
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
    padL(fmt(g.tarif * M1), 9) + padL(fmt(g.tarif * M2), 9) + padL(fmt(g.tarif * M3), 9) +
    padL((g.cost / g.tarif).toFixed(2), 8));
}
console.log("─".repeat(66));
console.log(pad("TOTAL", 16) + padL(N, 6) + padL(fmt(COST), 9) +
  padL(fmt(TARIF * M1), 9) + padL(fmt(TARIF * M2), 9) + padL(fmt(TARIF * M3), 9) +
  padL((COST / TARIF).toFixed(2), 8));

// --- Le seuil, en clair. ---
const seuil = COST / TARIF;
const palier = seuil <= M1 ? "une étoile suffit"
  : seuil <= M2 ? "entre une et deux étoiles"
  : seuil <= M3 ? "entre deux et trois étoiles"
  : "PLUS que trois étoiles — le jeu exige des services parfaits";
console.log("");
console.log(`Prix = ${Math.round(PRIX_RATIO * 100)} % du tarif · dotation de départ ${CREDITS_START}`);
console.log(`Seuil d'équilibre : ${(seuil * 100).toFixed(0)} % du tarif en moyenne — ${palier}.`);
console.log(`Masse monétaire maximale : ${fmt(TARIF * PALIERS[PALIERS.length - 1].mult)} · dépenses obligatoires : ${fmt(COST)}.`);
console.log("Paliers (en tarif) : " + PALIERS.map((x, i) =>
  x.nom + " +" + ((x.mult - (i ? PALIERS[i-1].mult : 0)) * 100).toFixed(0) + " %").join(" · "));
if (seuil > 1) fail("le seuil dépasse 100 % : le réseau ne peut pas être complété");

console.log("");
console.log(fails ? `✗ ${fails} contrôle(s) en échec` : "✓ économie cohérente");
process.exit(fails ? 1 : 0);
