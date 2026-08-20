// ------------------------------------------------------------------
// corridors-propose — REMPLIR LES CORRIDORS avec les gares du catalogue.
//
//     node tools/corridors-propose.mjs            # tous les corridors jouables
//     node tools/corridors-propose.mjs --seed=4   # découpage reproductible
//     node tools/corridors-propose.mjs --reste    # ce qui ne trouve pas de place
//
// data/graph.js dit QUELS hubs se font face au bout d'un corridor. Il ne dit
// pas encore quelles gares le composent. Cet outil répond à la question pour
// les corridors dont LES DEUX BOUTS sont déjà jouables — c'est là que les
// 116 gares intermédiaires du catalogue doivent trouver leur place.
//
// ------------------------------------------------------------------
// POURQUOI CE N'EST PAS UN SIMPLE PLUS COURT CHEMIN
// ------------------------------------------------------------------
// Deux hubs sont souvent reliés par plusieurs routes réelles — Mons à Gand par
// la Dendre ou par la Lys, Cologne à Hanovre par la Ruhr ou par Münster. Le
// plus court chemin en choisirait une et laisserait l'autre sans gares.
//
// Or la contrainte qui compte n'est pas la longueur : c'est la COUVERTURE.
// Chaque gare du catalogue doit appartenir à un corridor et à un seul, sans
// quoi elle est injouable ou jouable deux fois. On cherche donc une
// affectation globale — un glouton randomisé à redémarrages, comme pour le
// lot 1 — et non un chemin optimal corridor par corridor.
//
// Ce qui ne trouve pas de place est SIGNALÉ, jamais caché : ce sont les gares
// qui appelleront un corridor de plus, ou un hub de plus.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";

const ROOT = new URL("..", import.meta.url).pathname;
const read = f => readFileSync(ROOT + f, "utf8");

let SEED = 1, RESTE = false;
for (const a of process.argv.slice(2)) {
  const m = /^--seed=(\d+)$/.exec(a);
  if (m) { SEED = +m[1]; continue; }
  if (a === "--reste") RESTE = true;
}
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
let rnd = mulberry32(SEED);
const pick = a => a[Math.floor(rnd() * a.length)];

// --- le réseau et le graphe ---
const ctx = createContext({ console });
for (const [f, n] of [
  ["js/network.js", ["NET"]],
  ["data/places.js", ["PLACES", "PLACE_ALIASES"]],
  ["data/lines.js", ["LINES", "LINE_COUNTRIES"]],
  ["data/graph.js", ["HUBS", "LIENS", "CONSTELLATIONS"]],
  ["js/geo.js", ["GEO"]]
]) runInContext(read(f) + "\n" + n.map(x => `globalThis.${x} = ${x};`).join(""), ctx);

const index = JSON.parse(read("data/stations/index.json"));
const CATALOG = [];
for (const g of index)
  for (const id of g.stations) CATALOG.push(JSON.parse(read(`data/stations/${g.country}/${id}.json`)));
ctx.CATALOG = CATALOG;
const { netLinks, HUBS, LIENS, GEO } = ctx;

const card = Object.fromEntries(CATALOG.map(c => [c.id, c]));
const nameOf = id => card[id].city || card[id].name || id;
// Le graphe nomme ses hubs par le NOM de la fiche ; le réseau les connaît par
// leur id. Une seule table, pour que la traduction ne se fasse pas à deux
// endroits et ne diverge pas.
const idOfName = {};
for (const c of CATALOG) idOfName[c.city || c.name] = c.id;

const hubById = Object.fromEntries(HUBS.map(h => [h.id, h]));
// Les hubs déjà jouables, et leur gare.
const HUB_GARE = {};
for (const h of HUBS) if (h.gare && idOfName[h.gare]) HUB_GARE[h.id] = idOfName[h.gare];
const estHub = new Set(Object.values(HUB_GARE));

// Les corridors dont LES DEUX BOUTS sont jouables : les seuls qu'on peut
// remplir aujourd'hui.
const CORRIDORS = LIENS
  .filter(([a, b, t]) => t !== "mer" && HUB_GARE[a] && HUB_GARE[b])
  .map(([a, b]) => ({ a, b, ga: HUB_GARE[a], gb: HUB_GARE[b] }));

// Les gares intermédiaires : tout ce qui n'est pas un hub.
const INTER = CATALOG.map(c => c.id).filter(id => !estHub.has(id));
const adj = id => netLinks(id).to;

// ------------------------------------------------------------------
// LA SINUOSITÉ — ce qui distingue un corridor d'un serpent.
// ------------------------------------------------------------------
// Chercher le chemin le plus LONG place beaucoup de gares, et produit des
// trajets absurdes : Montpellier – Toulouse en passant par Paris, Londres –
// Bristol par Liverpool. Le rail les autorise ; aucun voyageur ne les
// reconnaîtrait.
//
// On mesure donc le rapport entre la distance PARCOURUE et la distance à vol
// d'oiseau entre les deux hubs. 1 = ligne droite. Un vrai corridor contourne
// des reliefs et dessert des villes : 1,4 est large. Au-delà de 1,6, le trajet
// revient sur ses pas.
const lonlat = {};
for (const slug in GEO.countries)
  for (const id in GEO.countries[slug].cities) lonlat[id] = GEO.countries[slug].cities[id];
const R = 6371, rad = Math.PI / 180;
function km(a, b) {
  const A = lonlat[a], B = lonlat[b];
  if (!A || !B) return 0;
  return R * Math.hypot((B[0] - A[0]) * rad * Math.cos((A[1] + B[1]) / 2 * rad), (B[1] - A[1]) * rad);
}
const SIN_MAX = 1.5;
function sinuosite(ga, gb, milieu) {
  const suite = [ga, ...milieu, gb];
  let parcouru = 0;
  for (let i = 0; i + 1 < suite.length; i++) parcouru += km(suite[i], suite[i + 1]);
  const direct = km(ga, gb);
  return direct < 1 ? 99 : parcouru / direct;
}

// ------------------------------------------------------------------
// UN CHEMIN POUR UN CORRIDOR — parcours en largeur entre les deux gares-hubs,
// sans traverser un autre hub (sinon ce serait deux corridors) ni une gare
// déjà prise.
// ------------------------------------------------------------------
const LEN_MAX = 8;
function cheminer(ga, gb, libre) {
  // ATTENTION : pas de marquage GLOBAL des nœuds vus. Un parcours en largeur
  // ordinaire marque chaque nœud une fois et ne trouve donc qu'UN chemin ;
  // ici on les veut tous, puisqu'on cherchera ensuite le plus long. Le seul
  // interdit est de repasser par une gare du chemin courant.
  const file = [[ga]];
  const trouves = [];
  let explores = 0;
  while (file.length && explores < 40000) {
    const p = file.shift();
    const u = p[p.length - 1];
    if (p.length - 1 > LEN_MAX) continue;
    for (const v of adj(u)) {
      if (v === gb) { trouves.push(p.slice(1)); continue; }
      if (estHub.has(v) || !libre.has(v) || p.includes(v)) continue;
      explores++;
      file.push([...p, v]);
    }
    if (trouves.length > 200) break;
  }
  return trouves;
}

// ------------------------------------------------------------------
// UNE TENTATIVE — on sert les corridors dans un ordre au hasard, chacun
// prenant le plus long chemin encore libre. Les corridors traités tôt ont
// le choix ; c'est le redémarrage qui corrige l'injustice.
// ------------------------------------------------------------------
function essai() {
  const libre = new Set(INTER);
  const ordre = CORRIDORS.slice();
  for (let i = ordre.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [ordre[i], ordre[j]] = [ordre[j], ordre[i]];
  }
  const out = new Map();
  for (const c of ordre) {
    const bruts = cheminer(c.ga, c.gb, libre);
    // On écarte d'abord les trajets qui ne se lisent pas comme un voyage,
    // ENSUITE seulement on cherche le plus long parmi ceux qui restent.
    // L'ordre compte : filtrer après avoir choisi ne sert à rien.
    const cands = bruts.filter(p => sinuosite(c.ga, c.gb, p) <= SIN_MAX);
    if (!cands.length) { out.set(c, []); continue; }
    const max = Math.max(...cands.map(p => p.length));
    const p = pick(cands.filter(x => x.length === max));
    for (const g of p) libre.delete(g);
    out.set(c, p);
  }
  return { out, libre };
}

let best = null, bestReste = Infinity;
for (let k = 0; k < 3000; k++) {
  const r = essai();
  const vides = [...r.out.values()].filter(p => !p.length).length;
  const score = r.libre.size * 10 + vides;
  if (score < bestReste) { bestReste = score; best = r; }
  if (r.libre.size === 0 && vides === 0) break;
}

// ------------------------------------------------------------------
// RAPPORT
// ------------------------------------------------------------------
const pad = (s, n) => String(s).padEnd(n);
const rangs = [...best.out.entries()].sort((x, y) => y[1].length - x[1].length);
console.log(`\n${CORRIDORS.length} corridors entre hubs déjà jouables · ${INTER.length} gares intermédiaires\n`);
for (const [c, p] of rangs) {
  const nom = `${hubById[c.a].nom} – ${hubById[c.b].nom}`;
  const sin = p.length ? sinuosite(c.ga, c.gb, p) : 0;
  console.log(pad(String(p.length), 3) + pad(nom, 30) +
    pad(p.length ? "×" + sin.toFixed(2) : "", 7) +
    (p.length ? p.map(nameOf).join(" · ") : "— aucun trajet lisible"));
}
const h = {};
for (const [, p] of best.out) h[p.length] = (h[p.length] || 0) + 1;
console.log("\nlongueurs : " + Object.keys(h).map(Number).sort((a, b) => a - b)
  .map(k => `${k}→${h[k]}`).join("  "));
const places = INTER.length - best.libre.size;
console.log(`gares placées : ${places}/${INTER.length}` +
  (best.libre.size ? `  — ${best.libre.size} sans corridor` : "  (toutes)"));

if (RESTE && best.libre.size) {
  console.log("\nCE QUI NE TROUVE PAS DE PLACE — et pourquoi :");
  for (const id of best.libre) {
    const vois = adj(id);
    const hubs = vois.filter(v => estHub.has(v)).map(nameOf);
    console.log(`  ${pad(nameOf(id), 20)} voisines : ${vois.map(nameOf).join(", ")}` +
      (hubs.length ? `   (touche ${hubs.join(", ")})` : "   (aucun hub à portée)"));
  }
}
console.log(`\ngraine ${SEED} — le même appel redonne exactement ce découpage.\n`);
