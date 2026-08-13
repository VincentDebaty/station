// ------------------------------------------------------------------
// Vérification du RÉSEAU (js/network.js + data/places.js).
//
//     node tools/net-check.mjs
//
// Le réseau de la carte ne montre que les gares JOUABLES, reliées par les
// lignes de data/lines.js (ou, pour les pays pas encore décrits, déduites des
// portails). Un portail qui ne désigne aucune gare est un cul-de-sac : il vit
// sur le gril, pas sur la carte, et ce contrôle le laisse passer.
//
// Il signale ce qui est LOUCHE sans être faux :
//   - un lieu très loin de la gare qui le dessert (coordonnée probablement
//     erronée, ou desserte invraisemblable) ;
//   - une arête déclarée d'un seul côté (le graphe se lit en union, donc elle
//     compte quand même — mais c'est souvent l'indice qu'une fiche nomme un
//     terminus au lieu d'une ville) ;
//   - un lieu secondaire défini mais que plus personne ne cite.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";

const root = new URL("..", import.meta.url).pathname;
const read = f => readFileSync(root + f, "utf8");

// Les fichiers du jeu déclarent leurs données en `const` : dans un contexte vm,
// ces liaisons ne remontent pas sur l'objet global. On les y republie.
const ctx = createContext({ console });
for (const [file, names] of [
  ["js/network.js", ["NET"]],
  ["data/places.js", ["PLACES", "PLACE_ALIASES"]],
  ["data/lines.js", ["LINES", "LINE_COUNTRIES"]],
  ["js/geo.js", ["GEO"]]
]) {
  runInContext(read(file) + "\n" + names.map(n => `globalThis.${n} = ${n};`).join(""), ctx);
}

const index = JSON.parse(read("data/stations/index.json"));
const CATALOG = [];
for (const g of index)
  for (const id of g.stations) CATALOG.push(JSON.parse(read(`data/stations/${g.country}/${id}.json`)));
ctx.CATALOG = CATALOG;
const { PLACES, PLACE_ALIASES, LINES, LINE_COUNTRIES, GEO, netKey, netLinks, netEdges } = ctx;

// Coordonnées d'une gare jouable (geo.js), par id.
const cityOf = {};
for (const slug in GEO.countries)
  for (const id in GEO.countries[slug].cities) cityOf[id] = GEO.countries[slug].cities[id];

// Distance approchée en km (équirectangulaire — largement assez pour un contrôle).
function km(a, b) {
  const t = Math.PI / 180;
  const dx = (b[0] - a[0]) * t * Math.cos((a[1] + b[1]) / 2 * t), dy = (b[1] - a[1]) * t;
  return 6371 * Math.hypot(dx, dy);
}

const errors = [], warns = [];
const used = new Set();

for (const card of CATALOG) {
  const src = cityOf[card.id];
  if (!src) { errors.push(`${card.id} : aucune coordonnée dans geo.js`); continue; }
  // Un portail qui ne désigne aucune gare jouable n'est PAS une erreur : c'est
  // un cul-de-sac (Ostende, Genk, Turnhout…), gardé sur le gril et absent de la
  // carte — voir tools/AUTHORING-STATIONS.md §0. On ne vérifie donc que la
  // vraisemblance des lieux qui, eux, ont des coordonnées.
  for (const name in card.portals || {}) {
    const key = netKey(name);
    if (PLACE_ALIASES[key]) continue;
    if (CATALOG.some(c => c.id !== card.id && (netKey(c.id) === key || netKey(c.city) === key))) continue;
    const p = PLACES[key];
    if (!p) continue;                        // cul-de-sac : rien à situer
    used.add(key);
    const d = km(src, p);
    if (d > 400) warns.push(`${card.id} → ${name} : ${Math.round(d)} km`);
  }
}

// Arêtes déclarées d'un seul côté : le graphe les garde (union), mais c'est
// souvent le signe qu'une fiche nomme un terminus au lieu d'une ville.
const declares = {};
for (const card of CATALOG) {
  declares[card.id] = new Set();
  for (const name in card.portals || {}) {
    const key = netKey(name);
    const target = PLACE_ALIASES[key] || (CATALOG.find(c => netKey(c.id) === key || netKey(c.city) === key) || {}).id;
    if (target && target !== card.id) declares[card.id].add(target);
  }
}
// Ne concerne QUE les gares encore régies par la déduction par portails :
// celles décrites par une ligne tiennent leur topologie de data/lines.js.
const byLine = new Set(CATALOG.filter(c => LINE_COUNTRIES.includes(c.country)).map(c => c.id));
const oneWay = [];
for (const a in declares) {
  if (byLine.has(a)) continue;
  for (const b of declares[a])
    if (!byLine.has(b) && (!declares[b] || !declares[b].has(a))) oneWay.push(`${a} → ${b}`);
}

// Les LIGNES : chaque nœud doit exister (gare jouable, alias, ou lieu situé),
// sinon la ligne se casse en silence au milieu de son tracé.
const lineErrors = [];
const stationKeys = new Set(CATALOG.flatMap(c => [netKey(c.id), netKey(c.city)].filter(Boolean)));
for (const line of LINES) {
  if (!line.nodes || line.nodes.length < 2) { lineErrors.push(`${line.id} : moins de deux nœuds`); continue; }
  for (const n of line.nodes) {
    const k = netKey(n);
    if (stationKeys.has(k) || PLACE_ALIASES[k] || PLACES[k]) { used.add(k); continue; }
    lineErrors.push(`${line.id} « ${line.name} » → nœud inconnu : ${n}`);
  }
  // Un tronçon anormalement long trahit un intermédiaire oublié.
  for (let i = 0; i + 1 < line.nodes.length; i++) {
    const at = n => { const k = netKey(n); return cityOf[k] || cityOf[PLACE_ALIASES[k]] ||
      cityOf[(CATALOG.find(c => netKey(c.id) === k || netKey(c.city) === k) || {}).id] || PLACES[k]; };
    const a = at(line.nodes[i]), b = at(line.nodes[i + 1]);
    if (a && b && km(a, b) > 180) warns.push(`${line.id} : ${line.nodes[i]} – ${line.nodes[i + 1]} = ${Math.round(km(a, b))} km`);
  }
}
errors.push(...lineErrors);

// --- PROGRESSION. Le joueur ouvre UNE porte de départ, puis n'achète que de
// PROCHE EN PROCHE : tout ce qu'il atteindra ensuite passe par le réseau,
// depuis ce seul point. On propage donc depuis chaque porte, sans se soucier du
// prix — les crédits sont fongibles et s'accumulent, seule la géographie
// contraint. Une porte qui n'ouvre presque rien est un piège : le joueur s'y
// engage sans savoir qu'il s'enferme.
//
// La règle du départ vient du JEU (isStartDoor, js/catalog.js), jamais d'une
// copie : c'est elle qui décide, ici comme à l'écran.
ctx.getProgress = () => ({});
ctx.isBought = () => false;
ctx.getCredits = () => 0;
// `js/catalog.js` déclare `const CATALOG = []` : chargé tel quel, il MASQUE le
// catalogue déjà en place et toutes les règles travaillent sur du vide — le
// contrôle passait alors sans rien voir. On retire cette seule déclaration.
runInContext(
  read("js/catalog.js").replace("const CATALOG = [];", "") +
  "\nglobalThis.isStartDoor = isStartDoor;" +
  "\nglobalThis.START_DIFFICULTY = START_DIFFICULTY;", ctx);
const { isStartDoor, START_DIFFICULTY } = ctx;

const diffOf = id => {
  const c = CATALOG.find(x => x.id === id);
  return c ? Math.max(1, Math.min(5, c.difficulty || 1)) : 1;
};
const allEasy = CATALOG.filter(c => diffOf(c.id) <= START_DIFFICULTY).map(c => c.id);
const entries = allEasy.filter(isStartDoor);

const rejected = allEasy.filter(id => entries.indexOf(id) < 0);
// Propagation : la frontière d'achat, exactement comme isBuyable la définit —
// toute voisine d'une gare déjà acquise.
function reachFrom(start) {
  const open = new Set([start]), stack = [start];
  while (stack.length) {
    for (const nb of netLinks(stack.pop()).to) {
      if (open.has(nb) || !CATALOG.some(c => c.id === nb)) continue;
      open.add(nb); stack.push(nb);
    }
  }
  return open;
}
// LES DEUX VERROUS DE PROGRESSION NE PEUVENT PAS ENFERMER — c'est vérifié ici,
// parce que rien à l'écriture d'un pays ne le signalerait.
//
// « Le réseau doit tourner » ne bloque que tant qu'une gare acquise n'a pas
// servi : jouer une journée suffit, il n'y a rien à prouver.
//
// « On n'ouvre que depuis une voisine tenue à ★★ » ne demande jamais que de
// bien jouer une gare qu'on POSSÈDE déjà. La frontière imposant de toute façon
// une voisine acquise, la condition porte toujours sur une gare accessible : la
// couverture est donc exactement celle de la propagation géographique, déjà
// contrôlée ci-dessus.
//
// La version en PALIERS DE DIFFICULTÉ (« niveau d exige ★★ au niveau d−1 »),
// elle, enfermait : ces portes n'ont que des voisines trop hautes pour leur
// palier, et le joueur qui s'y engageait ne pouvait plus rien acheter. On les
// liste — si un jour la règle repasse par les paliers, la sanction est là.
const trapDoors = entries.filter(id =>
  !netLinks(id).to.some(nb => CATALOG.some(c => c.id === nb) && diffOf(nb) <= START_DIFFICULTY + 1));

const reach = entries.map(e => ({ e, n: reachFrom(e).size }));
const worst = reach.reduce((a, b) => (b.n < a.n ? b : a));
const best = reach.reduce((a, b) => (b.n > a.n ? b : a));
const stuck = CATALOG.filter(c => !reachFrom(best.e).has(c.id));
const stuckByCountry = {};
for (const c of stuck) (stuckByCountry[c.country] = stuckByCountry[c.country] || []).push(`${c.id}(${diffOf(c.id)})`);
for (const c of stuck) errors.push(`gare jamais atteignable, même depuis la meilleure porte : ${c.id}`);

const orphans = Object.keys(PLACES).filter(k => !used.has(k));

const bad = Object.entries(PLACES).filter(([, p]) =>
  !(p[0] >= -12 && p[0] <= 32 && p[1] >= 40 && p[1] <= 62));
for (const [k, p] of bad) errors.push(`PLACES.${k} = [${p}] hors de l'emprise européenne attendue`);

console.log(`gares : ${CATALOG.length} · lieux : ${Object.keys(PLACES).length} · alias : ${Object.keys(PLACE_ALIASES).length}` +
  ` · lignes : ${LINES.length} · arêtes du réseau : ${netEdges().length}`);
console.log(`\nERREURS (${errors.length})`);
errors.forEach(e => console.log("  ✗ " + e));
console.log(`\nDISTANCES SUSPECTES (${warns.length}) — une desserte de plus de 400 km`);
warns.forEach(w => console.log("  ? " + w));
console.log(`\nARÊTES À SENS UNIQUE (${oneWay.length}) — gares encore sans lignes réelles`);
oneWay.forEach(w => console.log("  · " + w));
console.log(`\nLIEUX DÉFINIS MAIS JAMAIS CITÉS (${orphans.length})`);
orphans.forEach(o => console.log("  · " + o));

console.log(`\nPROGRESSION — ${entries.length} portes de départ (difficulté ≤ ${START_DIFFICULTY}) · achat de proche en proche`);
if (rejected.length) console.log(`  écartées (aucune voisine jouable) : ${rejected.join(", ")}`);
console.log("  portes sans voisine d'un palier proche (fatales à une règle de paliers) : " +
  (trapDoors.join(", ") || "aucune"));
console.log("  atteignable depuis chaque porte :");
for (const r of reach.sort((a, b) => b.n - a.n))
  console.log(`      ${r.e.padEnd(18)} ${r.n} / ${CATALOG.length}${r.n === CATALOG.length ? "  ✓" : r.n < 5 ? "   ✗ PIÈGE" : ""}`);
if (stuck.length) {
  console.log(`  ✗ jamais atteignables, même depuis la meilleure porte (${best.e}) :`);
  for (const country in stuckByCountry) console.log(`      ${country} : ${stuckByCountry[country].join(", ")}`);
} else console.log("  ✓ toutes les gares sont atteignables depuis la meilleure porte");

process.exit(errors.length ? 1 : 0);
