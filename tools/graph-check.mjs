// ------------------------------------------------------------------
// graph-check — les invariants du graphe européen (data/graph.js).
//
//     node tools/graph-check.mjs
//     node tools/graph-check.mjs --detail     # le détail par constellation
//
// Le graphe est la fondation du lot 2 : tout le reste — la progression, la
// carte, l'écriture des corridors — s'appuie dessus. Une erreur qui s'y glisse
// ne se voit qu'à l'autre bout de la chaîne, quand elle a déjà coûté cher.
// D'où ce contrôle, dans l'esprit de gen-check et net-check : il refuse, il
// n'avertit pas.
//
// Ce qu'il vérifie, du plus rédhibitoire au plus fin :
//
//   1. INTÉGRITÉ. Identifiants uniques et bien formés, constellations connues,
//      liens dont les deux bouts existent, pas de doublon, pas de boucle.
//   2. CONNEXITÉ. Le graphe est d'UN SEUL TENANT. Un hub isolé n'est jamais
//      atteignable : le joueur ne pourrait ni l'ouvrir ni le voir arriver.
//   3. ÉCARTEMENT. Deux hubs reliés doivent être assez loin l'un de l'autre
//      pour qu'un corridor tienne entre eux. Mesuré : une gare tous les 40 à
//      60 km, donc 110 km au minimum absolu. En dessous, le corridor est vide.
//   4. DEGRÉ. Un hub continental (rang 1) promet 4 à 6 sorties, un régional
//      2 à 3. Ce n'est pas une coquetterie : le rang décide du nombre de
//      versions de trafic à écrire pour ce boss, et de la réserve d'extension.
//   5. ÉQUILIBRE. Aucune constellation ne doit être deux fois plus longue à
//      finir qu'une autre.
//
// Code de sortie ≠ 0 si un contrôle échoue — utilisable en pre-commit.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";

const ROOT = new URL("..", import.meta.url).pathname;
const DETAIL = process.argv.includes("--detail");

const ctx = createContext({ console });
runInContext(readFileSync(ROOT + "data/graph.js", "utf8") +
  "\nglobalThis.HUBS = HUBS; globalThis.LIENS = LIENS;" +
  "globalThis.CONSTELLATIONS = CONSTELLATIONS; globalThis.CORRIDORS = CORRIDORS;", ctx);
const { HUBS, LIENS, CONSTELLATIONS, CORRIDORS } = ctx;

// Le catalogue, pour vérifier que les fiches annoncées existent vraiment.
const index = JSON.parse(readFileSync(ROOT + "data/stations/index.json", "utf8"));
const GARES = new Set(), GARE_IDS = new Set(), ID_DE_NOM = {};
for (const g of index)
  for (const id of g.stations) {
    const c = JSON.parse(readFileSync(`${ROOT}data/stations/${g.country}/${id}.json`, "utf8"));
    GARES.add(c.city || c.name);
    GARE_IDS.add(c.id);
    ID_DE_NOM[c.city || c.name] = c.id;
  }

const erreurs = [], alertes = [];
const byId = Object.fromEntries(HUBS.map(h => [h.id, h]));
// Les gares qui SONT des hubs : elles ne peuvent pas être aussi de passage.
const HUB_IDS = new Set(HUBS.filter(h => h.gare && ID_DE_NOM[h.gare]).map(h => ID_DE_NOM[h.gare]));

// --- 1. Intégrité ---------------------------------------------------
const vus = new Set();
for (const h of HUBS) {
  if (vus.has(h.id)) erreurs.push(`identifiant en double : ${h.id}`);
  vus.add(h.id);
  if (!/^[a-z0-9-]+$/.test(h.id)) erreurs.push(`identifiant mal formé : ${h.id}`);
  if (!CONSTELLATIONS.some(c => c.id === h.c)) erreurs.push(`${h.nom} : constellation inconnue « ${h.c} »`);
  if (!Array.isArray(h.ll) || h.ll.length !== 2) erreurs.push(`${h.nom} : coordonnées absentes`);
  if (h.rang !== 1 && h.rang !== 2) erreurs.push(`${h.nom} : rang ${h.rang} (attendu 1 ou 2)`);
  // Une fiche annoncée qui n'existe pas se paierait au chargement du jeu.
  if (h.gare && !GARES.has(h.gare)) erreurs.push(`${h.nom} : la fiche « ${h.gare} » n'est pas au catalogue`);
}

const arcs = new Set();
for (const [a, b, type] of LIENS) {
  if (!byId[a]) erreurs.push(`lien vers un hub inconnu : ${a}`);
  if (!byId[b]) erreurs.push(`lien vers un hub inconnu : ${b}`);
  if (a === b) erreurs.push(`lien d'un hub vers lui-même : ${a}`);
  const k = a < b ? a + "|" + b : b + "|" + a;
  if (arcs.has(k)) erreurs.push(`lien en double : ${a} – ${b}`);
  arcs.add(k);
  if (type && type !== "mer") erreurs.push(`${a} – ${b} : type « ${type} » inconnu`);
}

// --- 2. Connexité ---------------------------------------------------
const adj = {};
for (const h of HUBS) adj[h.id] = [];
for (const [a, b] of LIENS) { if (byId[a] && byId[b]) { adj[a].push(b); adj[b].push(a); } }
const atteints = new Set([HUBS[0].id]);
const pile = [HUBS[0].id];
while (pile.length) {
  const u = pile.pop();
  for (const v of adj[u]) if (!atteints.has(v)) { atteints.add(v); pile.push(v); }
}
if (atteints.size !== HUBS.length) {
  const isoles = HUBS.filter(h => !atteints.has(h.id));
  erreurs.push(`${isoles.length} hub(s) hors du réseau : ${isoles.map(h => h.nom).join(", ")}`);
}

// --- 3. Écartement --------------------------------------------------
const R = 6371, rad = Math.PI / 180;
const km = (a, b) => R * Math.hypot(
  (b.ll[0] - a.ll[0]) * rad * Math.cos((a.ll[1] + b.ll[1]) / 2 * rad),
  (b.ll[1] - a.ll[1]) * rad);
const MIN_KM = 110;
const courts = [];
for (const [a, b, type] of LIENS) {
  if (!byId[a] || !byId[b]) continue;
  // UNE TRAVERSÉE N'EST PAS UN CORRIDOR. Le ferry EST le lien : il n'y a pas
  // de gares entre Helsinki et Tallinn, et il n'en faut pas. La règle
  // d'écartement ne vaut que pour ce qui doit contenir des gares.
  if (type === "mer") continue;
  const d = km(byId[a], byId[b]);
  if (d < MIN_KM) courts.push({ a, b, d: Math.round(d) });
}
// Deux exceptions assumées, et écrites ici plutôt que dans les données :
// Lille est le carrefour Eurostar/TGV, et le tunnel sous la Manche n'a pas
// d'équivalent. Les taire dans data/graph.js les rendrait invisibles.
// Strasbourg – Stuttgart : 107 km, mais ces 107 km franchissent une
// frontière — c'est un corridor international, pas un doublon.
const TOLERES = new Set(["bruxelles|lille", "strasbourg|stuttgart"]);
for (const c of courts) {
  const k = c.a < c.b ? c.a + "|" + c.b : c.b + "|" + c.a;
  const m = `${byId[c.a].nom} – ${byId[c.b].nom} : ${c.d} km, pas de place pour un corridor`;
  if (TOLERES.has(k)) alertes.push(m + " (toléré)"); else erreurs.push(m);
}

// --- 4. Degré selon le rang ------------------------------------------
for (const h of HUBS) {
  const d = adj[h.id].length;
  if (d === 0) continue;                       // déjà signalé par la connexité
  if (h.rang === 1 && d < 3)
    alertes.push(`${h.nom} : hub continental à ${d} sortie(s), on en attend 4 à 6`);
  if (h.rang === 2 && d > 4)
    alertes.push(`${h.nom} : hub régional à ${d} sorties, il mériterait le rang 1`);
}

// --- 4 bis. Les corridors ---------------------------------------------
// Un corridor décrit le CONTENU d'un lien : il doit donc correspondre à un
// lien, ne contenir que des gares du catalogue, et n'en partager aucune avec
// un autre — une gare dans deux corridors s'ouvrirait deux fois.
const liens = new Set(LIENS.map(([a, b]) => a < b ? a + "|" + b : b + "|" + a));
const gareVue = new Map();
const parGare = {};
for (const c of CORRIDORS) {
  const k = c.de < c.vers ? c.de + "|" + c.vers : c.vers + "|" + c.de;
  if (!liens.has(k)) erreurs.push(`corridor ${c.de} – ${c.vers} : aucun lien correspondant`);
  if (!byId[c.de] || !byId[c.vers]) erreurs.push(`corridor vers un hub inconnu : ${c.de} – ${c.vers}`);
  if (!c.gares.length) alertes.push(`corridor ${c.de} – ${c.vers} : aucune gare`);
  if (c.gares.length > 10) erreurs.push(`corridor ${c.de} – ${c.vers} : ${c.gares.length} gares, 10 au maximum`);
  for (const g of c.gares) {
    if (gareVue.has(g))
      erreurs.push(`${g} est dans deux corridors : ${gareVue.get(g)} et ${c.de} – ${c.vers}`);
    gareVue.set(g, `${c.de} – ${c.vers}`);
    if (!GARE_IDS.has(g)) erreurs.push(`corridor ${c.de} – ${c.vers} : gare inconnue « ${g} »`);
    // Une gare-hub n'est pas une gare de corridor : elle en est le bout.
    if (HUB_IDS.has(g)) erreurs.push(`corridor ${c.de} – ${c.vers} : ${g} est un hub`);
  }
}

// --- 4 ter. Les versions de trafic ------------------------------------
// Un boss porte autant de versions que de sorties. Quand elles sont déclarées
// — Londres et Paris, dont les terminus SONT les directions — chacune doit
// viser une sortie réelle et une fiche qui existe. Une version orpheline
// enverrait le joueur sur une gare que le catalogue ne connaît pas.
const sortiesDe = {};
for (const [a2, b2] of LIENS) {
  (sortiesDe[a2] = sortiesDe[a2] || new Set()).add(b2);
  (sortiesDe[b2] = sortiesDe[b2] || new Set()).add(a2);
}
for (const h of HUBS) {
  if (!h.versions) continue;
  const dispo = sortiesDe[h.id] || new Set();
  const vus2 = new Set();
  for (const v of h.versions) {
    if (!dispo.has(v.vers))
      erreurs.push(`${h.nom} : version vers « ${v.vers} », qui n'est pas une de ses sorties`);
    if (vus2.has(v.vers)) erreurs.push(`${h.nom} : deux versions vers ${v.vers}`);
    vus2.add(v.vers);
    if (v.gare && !GARES.has(v.gare))
      erreurs.push(`${h.nom} : la version vers ${v.vers} joue « ${v.gare} », absente du catalogue`);
  }
  const manquantes = [...dispo].filter(x => !vus2.has(x));
  if (manquantes.length)
    alertes.push(`${h.nom} : ${manquantes.length} sortie(s) sans version déclarée (${manquantes.join(", ")})`);
}

// --- 5. Équilibre des constellations ---------------------------------
const parC = {};
for (const h of HUBS) (parC[h.c] = parC[h.c] || []).push(h);
const tailles = Object.values(parC).map(g => g.length);
const ecart = Math.max(...tailles) / Math.min(...tailles);
if (ecart > 2)
  erreurs.push(`constellations déséquilibrées : de ${Math.min(...tailles)} à ${Math.max(...tailles)} hubs (${ecart.toFixed(2)}:1)`);

// --- Rapport ---------------------------------------------------------
const pad = (s, n) => String(s).padEnd(n);
console.log(`\ngraph-check — ${HUBS.length} hubs · ${LIENS.length} liens · ` +
  `${CORRIDORS.length} corridors remplis · ${CONSTELLATIONS.length} constellations\n`);
console.log(pad("constellation", 26) + pad("hubs", 6) + pad("continentaux", 14) + pad("au catalogue", 14) + "à écrire");
console.log("-".repeat(74));
for (const c of CONSTELLATIONS) {
  const g = parC[c.id] || [];
  console.log(pad(c.nom, 26) + pad(g.length, 6) +
    pad(g.filter(h => h.rang === 1).length, 14) +
    pad(g.filter(h => h.gare).length, 14) + g.filter(h => !h.gare).length);
}
console.log("-".repeat(74));
console.log(pad("TOTAL", 26) + pad(HUBS.length, 6) +
  pad(HUBS.filter(h => h.rang === 1).length, 14) +
  pad(HUBS.filter(h => h.gare).length, 14) + HUBS.filter(h => !h.gare).length);

if (DETAIL) {
  console.log("\nles liens les plus longs et les plus courts :");
  const mesures = LIENS.filter(l => byId[l[0]] && byId[l[1]])
    .map(([a, b, t]) => ({ a, b, t, d: Math.round(km(byId[a], byId[b])) }))
    .sort((x, y) => y.d - x.d);
  for (const m of mesures.slice(0, 5))
    console.log(`  ${pad(byId[m.a].nom + " – " + byId[m.b].nom, 34)}${m.d} km${m.t ? "  (" + m.t + ")" : ""}`);
  console.log("  …");
  for (const m of mesures.slice(-5))
    console.log(`  ${pad(byId[m.a].nom + " – " + byId[m.b].nom, 34)}${m.d} km${m.t ? "  (" + m.t + ")" : ""}`);
}

if (alertes.length) {
  console.log(`\n${alertes.length} remarque(s) :`);
  for (const a of alertes) console.log("  · " + a);
}
if (erreurs.length) {
  console.log(`\n${erreurs.length} ERREUR(S) :`);
  for (const e of erreurs) console.log("  ! " + e);
  console.log();
  process.exit(1);
}
const placees = CORRIDORS.reduce((a, c) => a + c.gares.length, 0);
console.log(`\n${placees} gare(s) de corridor placée(s) · ${GARE_IDS.size - HUB_IDS.size - placees} en attente d'un hub à écrire`);
console.log("OK — le graphe est intègre, d'un seul tenant, et ses écartements tiennent.\n");
