// ------------------------------------------------------------------
// graph-propose — LE GRAPHE EUROPÉEN : boss, corridors, antennes.
//
//     node tools/graph-propose.mjs                 # tout le réseau
//     node tools/graph-propose.mjs --seed=4        # découpage reproductible
//     node tools/graph-propose.mjs --quais=8       # seuil de boss
//     node tools/graph-propose.mjs --md            # sortie Markdown
//
// Le jeu se structure en trois briques (document de méta-progression) :
//
//   BOSS      grande gare, plusieurs SORTIES. Battre un boss ouvre une de ses
//             lignes, au choix du joueur.
//   CORRIDOR  une suite de gares entre DEUX boss. C'est la ligne qu'on parcourt.
//   ANTENNE   une branche partant d'un seul boss et finissant sur un terminus
//             de prestige (Nice, Plymouth, Aberdeen). Hors du chemin principal.
//
// ------------------------------------------------------------------
// CE QUE LA MESURE A IMPOSÉ À CET OUTIL
// ------------------------------------------------------------------
// Première idée, naturelle : retirer les boss du graphe et regarder ce qui
// reste. Chaque morceau serait un corridor. Mesuré : FAUX. À 29 boss, le
// reste ne se coupe pas en chaînes mais en BLOCS — 28 gares d'un tenant
// touchant cinq boss, 16 en touchant neuf. Il faudrait 110 boss sur 145 pour
// que des corridors apparaissent d'eux-mêmes.
//
// La raison est structurelle : le catalogue ne contient QUE DES NŒUDS, parce
// que c'est le critère qui a servi à le bâtir (au moins 3 directions). Or un
// réseau de nœuds est un maillage, pas un faisceau.
//
// D'où la méthode retenue : on ne cherche pas les morceaux, on DÉCOUPE chaque
// bloc en chemins disjoints allant d'un boss à un boss. C'est une couverture
// par chemins à extrémités contraintes — glouton randomisé à redémarrages,
// puis réparation, comme pour le lot 1.
//
// ------------------------------------------------------------------
// LA GARE DE CORRIDOR, POUR LES FICHES À VENIR
// ------------------------------------------------------------------
// Une gare de corridor n'est PAS une gare pauvre : c'est une gare à 3-6
// directions dont DEUX SEULEMENT mènent à une autre gare jouable — les autres
// sont des culs-de-sac (Ostende, Genk, Turnhout), qui vivent sur le gril sans
// exister sur la carte. Elle est pleinement jouable et n'ajoute aucune maille
// au réseau. Il en existe déjà 30, avec 4,3 directions et 5,5 quais en moyenne.
// C'est le gabarit à suivre pour écrire les corridors du document.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";

const ROOT = new URL("..", import.meta.url).pathname;
const read = f => readFileSync(ROOT + f, "utf8");

// --- arguments ---
let SEED = 1, MIN_QUAIS = 8, MIN_SORTIES = 3, MD = false;
for (const a of process.argv.slice(2)) {
  let m;
  if ((m = /^--seed=(\d+)$/.exec(a))) { SEED = +m[1]; continue; }
  if ((m = /^--quais=(\d+)$/.exec(a))) { MIN_QUAIS = +m[1]; continue; }
  if ((m = /^--sorties=(\d+)$/.exec(a))) { MIN_SORTIES = +m[1]; continue; }
  if (a === "--md") { MD = true; continue; }
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

// --- catalogue et réseau ---
const ctx = createContext({ console });
for (const [file, names] of [
  ["js/network.js", ["NET"]],
  ["data/places.js", ["PLACES", "PLACE_ALIASES"]],
  ["data/lines.js", ["LINES", "LINE_COUNTRIES"]],
  ["js/geo.js", ["GEO"]]
]) runInContext(read(file) + "\n" + names.map(n => `globalThis.${n} = ${n};`).join(""), ctx);

const index = JSON.parse(read("data/stations/index.json"));
const CATALOG = [], countryOf = {}, labelOf = {};
for (const g of index)
  for (const id of g.stations) {
    CATALOG.push(JSON.parse(read(`data/stations/${g.country}/${id}.json`)));
    countryOf[id] = g.country; labelOf[id] = g.label;
  }
ctx.CATALOG = CATALOG;
const { netLinks, GEO, LINES, netKey } = ctx;

const card = Object.fromEntries(CATALOG.map(c => [c.id, c]));
const nameOf = id => (card[id] ? (card[id].city || card[id].name) : null) || id || "?";
const dirOf = id => Object.keys(card[id].portals).length;
const quaisOf = id => card[id].platforms.length;
const adj = id => netLinks(id).to;
const FLAG = { belgique: "BE", france: "FR", allemagne: "DE", luxembourg: "LU", "royaume-uni": "UK" };

// Quelle ligne réelle relie deux gares voisines ? Sert à nommer les corridors.
const REAL = {};
const k2 = (a, b) => a < b ? a + "|" + b : b + "|" + a;
for (const L of LINES) {
  const raw = (L.nodes || []).map(n => card[n] ? n : (card[netKey(n)] ? netKey(n) : null)).filter(Boolean);
  const seq = raw.filter((x, i) => raw.indexOf(x) === i);
  for (let i = 0; i + 1 < seq.length; i++) {
    const k = k2(seq[i], seq[i + 1]);
    (REAL[k] = REAL[k] || []).push(L.id);
  }
}
// Les lignes réelles d'un trajet, sans répétition consécutive.
function realLines(path) {
  const out = [];
  for (let i = 0; i + 1 < path.length; i++) {
    const c = REAL[k2(path[i], path[i + 1])] || [];
    const keep = out.length && c.includes(out[out.length - 1]) ? out[out.length - 1] : c[0];
    if (keep && keep !== out[out.length - 1]) out.push(keep);
  }
  return out;
}

// Coordonnées, pour départager deux découpages également valides.
const lonlat = {};
for (const slug in GEO.countries)
  for (const id in GEO.countries[slug].cities) lonlat[id] = GEO.countries[slug].cities[id];
function km(a, b) {
  if (!a || !b) return 0;
  const t = Math.PI / 180;
  const dx = (b[0] - a[0]) * t * Math.cos((a[1] + b[1]) / 2 * t), dy = (b[1] - a[1]) * t;
  return 6371 * Math.hypot(dx, dy);
}
function sinuosity(ids) {
  let walk = 0;
  for (let i = 0; i + 1 < ids.length; i++) walk += km(lonlat[ids[i]], lonlat[ids[i + 1]]);
  const span = km(lonlat[ids[0]], lonlat[ids[ids.length - 1]]);
  return span < 1 ? 99 : walk / span;
}

// ------------------------------------------------------------------
// 1. LES BOSS
// ------------------------------------------------------------------
const BOSS = new Set(CATALOG
  .filter(c => adj(c.id).length >= MIN_SORTIES && quaisOf(c.id) >= MIN_QUAIS)
  .map(c => c.id));
const INTER = CATALOG.map(c => c.id).filter(id => !BOSS.has(id));

// ------------------------------------------------------------------
// 2. LES BLOCS — ce qui reste quand on retire les boss.
// ------------------------------------------------------------------
function blocs() {
  const vus = new Set(), out = [];
  for (const s of INTER) {
    if (vus.has(s)) continue;
    const pile = [s], c = []; vus.add(s);
    while (pile.length) {
      const u = pile.pop(); c.push(u);
      for (const v of adj(u)) { if (BOSS.has(v) || vus.has(v)) continue; vus.add(v); pile.push(v); }
    }
    out.push(c);
  }
  return out;
}

// ------------------------------------------------------------------
// 3. DÉCOUPER UN BLOC EN CHEMINS BOSS → BOSS
// ------------------------------------------------------------------
// Un chemin part d'une gare touchant un boss, traverse des gares libres du
// bloc, et s'arrête dès qu'il en touche un autre. On préfère TOUJOURS partir
// des gares les plus coincées : une fois les carrefours consommés, un
// cul-de-sac ne se raccroche plus à rien.
const LEN_MAX = 10;
// Au-delà, une branche sans second boss cesse d'être lisible comme une ligne.
const LEN_ANTENNE = 6;

function bossVoisins(id, libre) {
  return adj(id).filter(v => BOSS.has(v));
}
function decoupeBloc(bloc) {
  const libre = new Set(bloc);
  const degLibre = v => adj(v).filter(w => libre.has(w)).length;
  const chemins = [];
  while (libre.size) {
    // Départ : une gare libre touchant un boss, la plus coincée d'abord.
    const cands = [...libre].filter(v => bossVoisins(v).length);
    const depart = cands.length
      ? (rnd() < .75 ? cands.sort((a, b) => degLibre(a) - degLibre(b) || rnd() - .5)[0] : pick(cands))
      : [...libre].sort((a, b) => degLibre(a) - degLibre(b) || rnd() - .5)[0];
    const bIn = bossVoisins(depart)[0] || null;
    const path = [depart]; libre.delete(depart);
    let bOut = null;
    const plafond = bIn ? LEN_MAX : LEN_ANTENNE;
    while (path.length < plafond) {
      const u = path[path.length - 1];
      // Si l'on touche un boss AUTRE que celui d'entrée, on peut clore ici.
      const sortie = bossVoisins(u).find(b => b !== bIn);
      if (sortie && (path.length >= 3 || rnd() < .4)) { bOut = sortie; break; }
      // Une branche qui n'a qu'un boss ne doit pas s'étirer sans fin.
      if (!bOut && path.length >= LEN_ANTENNE && !sortie) break;
      const suite = adj(u).filter(v => libre.has(v));
      if (!suite.length) { bOut = bossVoisins(u).find(b => b !== bIn) || null; break; }
      suite.sort((a, b) => degLibre(a) - degLibre(b) || rnd() - .5);
      const v = rnd() < .75 ? suite[0] : pick(suite);
      path.push(v); libre.delete(v);
    }
    if (!bOut) bOut = bossVoisins(path[path.length - 1]).find(b => b !== bIn) || null;
    chemins.push({ entree: bIn, gares: path, sortie: bOut });
  }
  return chemins;
}

// Un découpage vaut ce que valent ses chemins : on veut des corridors (deux
// boss) plutôt que des antennes, de 2 à 8 gares, peu sinueux et restant autant
// que possible sur une même ligne réelle.
function note(chemins) {
  let s = 0;
  for (const c of chemins) {
    const n = c.gares.length;
    if (!c.entree && !c.sortie) s += 300;        // rattaché à rien : le pire
    else if (!c.sortie) s += 40;                 // antenne
    if (n > 8) s += (n - 8) * 15;
    if (n < 2) s += 12;
    const sin = sinuosity(c.gares);
    if (sin > 2) s += (sin - 2) * 12;
    s += Math.max(0, realLines(c.gares).length - 1) * 5;
  }
  return s;
}

function resoudre() {
  const B = blocs();
  let best = null, bestS = Infinity;
  for (let k = 0; k < 4000; k++) {
    const ch = B.flatMap(decoupeBloc);
    const s = note(ch);
    if (s < bestS) { bestS = s; best = ch; }
    if (bestS === 0) break;
  }
  return best;
}

rnd = mulberry32(SEED);
const chemins = resoudre();
const corridors = chemins.filter(c => c.entree && c.sortie);
const antennes = chemins.filter(c => !c.entree || !c.sortie);

// ------------------------------------------------------------------
// RAPPORT
// ------------------------------------------------------------------
const couv = new Set(chemins.flatMap(c => c.gares));
const nom = c => `${nameOf(c.entree || c.sortie)} – ${nameOf(c.sortie || c.gares[c.gares.length - 1])}`;
const ligne = c => {
  const rl = realLines(c.gares);
  const bout = c.sortie ? nameOf(c.sortie) : "terminus";
  return { rl, txt: `${nameOf(c.entree || "?")} › ${c.gares.map(nameOf).join(" › ")} › ${bout}` };
};

if (MD) {
  console.log(`# Le réseau — ${BOSS.size} boss, ${corridors.length} corridors, ${antennes.length} antennes\n`);
  console.log(`Seuil de boss : ${MIN_SORTIES} sorties et ${MIN_QUAIS} quais. Graine ${SEED}.\n`);
  console.log(`## Les boss\n`);
  console.log(`| gare | pays | sorties | quais | directions |`);
  console.log(`|---|---|---|---|---|`);
  for (const b of [...BOSS].sort((a, b) => adj(b).length - adj(a).length))
    console.log(`| ${nameOf(b)} | ${FLAG[countryOf[b]]} | ${adj(b).length} | ${quaisOf(b)} | ${dirOf(b)} |`);
  console.log(`\n## Les corridors\n`);
  for (const c of corridors) {
    const L = ligne(c);
    console.log(`- **${nom(c)}** ${L.rl.length ? "(" + L.rl.join(" · ") + ")" : ""} — ${c.gares.length} gares`);
    console.log(`  ${L.txt}`);
  }
  console.log(`\n## Les antennes\n`);
  for (const c of antennes) {
    const L = ligne(c);
    console.log(`- **${nameOf(c.entree || c.sortie)} → ${nameOf(c.gares[c.gares.length - 1])}** — ${c.gares.length} gares`);
    console.log(`  ${L.txt}`);
  }
} else {
  console.log(`\n${BOSS.size} boss · ${INTER.length} gares intermédiaires`);
  console.log(`${corridors.length} corridors · ${antennes.length} antennes\n`);
  console.log("CORRIDORS");
  for (const c of corridors.sort((a, b) => b.gares.length - a.gares.length)) {
    const L = ligne(c);
    console.log(`  ${String(c.gares.length).padStart(2)} gares  ${L.rl.join("·").padEnd(16)} ${L.txt}`);
  }
  console.log("\nANTENNES");
  for (const c of antennes.sort((a, b) => b.gares.length - a.gares.length)) {
    const L = ligne(c);
    console.log(`  ${String(c.gares.length).padStart(2)} gares  ${L.rl.join("·").padEnd(16)} ${L.txt}`);
  }
  const h = {};
  for (const c of chemins) h[Math.min(c.gares.length, 10)] = (h[Math.min(c.gares.length, 10)] || 0) + 1;
  console.log("\nlongueurs :", Object.keys(h).map(Number).sort((a, b) => a - b)
    .map(k => `${k}${k === 10 ? "+" : ""}→${h[k]}`).join("  "));
  console.log(`couverture : ${couv.size}/${INTER.length}` +
    (couv.size === INTER.length ? "  (exacte)" : "  ⚠ INCOMPLÈTE"));
  const dup = chemins.flatMap(c => c.gares).length - couv.size;
  if (dup) console.log(`⚠ ${dup} gare(s) en double`);
  console.log(`graine ${SEED} — le même appel redonne exactement ce découpage.\n`);
}
