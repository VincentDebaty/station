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

// --- PROGRESSION. Le joueur choisit UNE porte d'entrée ; dès son premier
// service réussi les autres se referment. Tout ce qu'il atteindra ensuite passe
// donc par le réseau, depuis ce seul point. On simule le joueur le plus MODESTE
// (une étoile à chaque fois, donc la voisine fermée la plus facile, et il peut
// rejouer autant qu'il veut) DEPUIS CHAQUE PORTE : si même lui couvre tout,
// personne ne peut rester bloqué. Une porte qui n'ouvre presque rien est un
// piège — le joueur s'y engage sans savoir qu'il s'enferme.
const ENTRY_DIFFICULTY = 1;
const diffOf = id => {
  const c = CATALOG.find(x => x.id === id);
  return c ? Math.max(1, Math.min(5, c.difficulty || 1)) : 1;
};
// Une porte doit mener quelque part : une gare facile sans voisine jouable
// n'est pas une porte mais un piège (voir isEntryDoor dans js/catalog.js).
const allEasy = CATALOG.filter(c => diffOf(c.id) <= ENTRY_DIFFICULTY).map(c => c.id);
const entries = allEasy.filter(id => netLinks(id).to.some(nb => CATALOG.some(c => c.id === nb)));
const rejected = allEasy.filter(id => entries.indexOf(id) < 0);
function reachFrom(start) {
  const open = new Set([start]);
  for (let pass = 0; pass < CATALOG.length * 2; pass++) {
    let grew = false;
    for (const id of [...open]) {
      // Même règle que le jeu : les voisines directes fermées d'abord, sinon on
      // avance à travers les gares ouvertes jusqu'au premier rang fermé.
      let locked = netLinks(id).to
        .filter(nb => CATALOG.some(c => c.id === nb) && !open.has(nb));
      if (!locked.length) {
        const seen = new Set([id]); let ring = [id];
        for (let d = 0; d < CATALOG.length && ring.length && !locked.length; d++) {
          const next = [];
          for (const cur of ring)
            for (const nb of netLinks(cur).to) {
              if (seen.has(nb) || !CATALOG.some(c => c.id === nb)) continue;
              seen.add(nb);
              (open.has(nb) ? next : locked).push(nb);
            }
          ring = next;
        }
      }
      locked.sort((a, b) => diffOf(a) - diffOf(b));
      if (locked.length) { open.add(locked[0]); grew = true; }
    }
    if (!grew) break;
  }
  return open;
}
const reach = entries.map(e => ({ e, n: reachFrom(e).size }));
const worst = reach.reduce((a, b) => (b.n < a.n ? b : a));
const best = reach.reduce((a, b) => (b.n > a.n ? b : a));
const stuck = CATALOG.filter(c => !reachFrom(best.e).has(c.id));
const stuckByCountry = {};
for (const c of stuck) (stuckByCountry[c.country] = stuckByCountry[c.country] || []).push(`${c.id}(${diffOf(c.id)})`);

// --- MONOTONIE DE LA RÉCOMPENSE : mieux jouer ne doit JAMAIS ouvrir moins.
// On charge la vraie règle (js/catalog.js) avec un état de progression simulé,
// et on éprouve TOUTES les combinaisons de voisines fermées de chaque gare —
// elles sont peu nombreuses (6 au plus), donc l'exhaustif est gratuit.
// Bug attrapé le 11 août 2026 : à Namur (3), une étoile ouvrait Liège (4) mais
// deux n'ouvraient rien, le plafond de difficulté l'excluant.
let _openedSim = new Set();
ctx.getProgress = () => ({});
ctx.isOpened = id => _openedSim.has(id);
// `js/catalog.js` déclare `const CATALOG = []` : chargé tel quel, il MASQUE le
// catalogue déjà en place et toutes les règles travaillent sur du vide — le
// contrôle passait alors sans rien voir. On retire cette seule déclaration.
runInContext(
  read("js/catalog.js").replace("const CATALOG = [];", "") +
  "\nglobalThis.unlockChoices = unlockChoices;", ctx);
const { unlockChoices } = ctx;

const monotony = [];
for (const card of CATALOG) {
  const nb = netLinks(card.id).to.filter(id => CATALOG.some(c => c.id === id));
  if (!nb.length) continue;
  // mask 0 = toutes les voisines directes déjà ouvertes : c'est le cas qui
  // déclenche le repli « on ouvre plus loin ».
  for (let mask = 0; mask < (1 << nb.length); mask++) {
    // Les voisines HORS masque sont réputées déjà ouvertes.
    _openedSim = new Set(nb.filter((_, i) => !(mask & (1 << i))));
    const c1 = unlockChoices(card.id, 1), c2 = unlockChoices(card.id, 2), c3 = unlockChoices(card.id, 3);
    const sub = (a, b) => a.every(x => b.includes(x));
    if (!sub(c1, c2) || !sub(c2, c3))
      monotony.push(`${card.id} · fermées [${nb.filter((_, i) => mask & (1 << i)).join(", ")}] :` +
        ` 1★ [${c1}] → 2★ [${c2}] → 3★ [${c3}]`);
  }
}
errors.push(...monotony.slice(0, 8).map(m => "récompense non monotone — " + m));
if (monotony.length > 8) errors.push(`… et ${monotony.length - 8} autres cas non monotones`);

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

console.log(`\nPROGRESSION — ${entries.length} portes d'entrée (difficulté ≤ ${ENTRY_DIFFICULTY}) · une ouverture par service réussi`);
if (rejected.length) console.log(`  écartées (aucune voisine jouable) : ${rejected.join(", ")}`);
console.log("  atteignable depuis chaque porte :");
for (const r of reach.sort((a, b) => b.n - a.n))
  console.log(`      ${r.e.padEnd(18)} ${r.n} / ${CATALOG.length}${r.n === CATALOG.length ? "  ✓" : r.n < 5 ? "   ✗ PIÈGE" : ""}`);
if (stuck.length) {
  console.log(`  ✗ jamais atteignables, même depuis la meilleure porte (${best.e}) :`);
  for (const country in stuckByCountry) console.log(`      ${country} : ${stuckByCountry[country].join(", ")}`);
} else console.log("  ✓ toutes les gares sont atteignables depuis la meilleure porte");

process.exit(errors.length ? 1 : 0);
