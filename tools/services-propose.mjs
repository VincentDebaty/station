// ------------------------------------------------------------------
// services-propose — DÉCOUPER LE CATALOGUE EN LIGNES DE SERVICE.
//
//     node tools/services-propose.mjs              # les 5 pays
//     node tools/services-propose.mjs belgique     # un pays
//     node tools/services-propose.mjs --seed=4     # découpage reproductible
//     node tools/services-propose.mjs --js         # sort data/services.js
//
// Une LIGNE DE SERVICE est une suite de 4 à 6 gares jouables qu'on parcourt
// dans l'ordre : on ouvre la suivante en tenant la précédente. C'est l'unité de
// progression, de lecture de la carte, et de célébration.
//
// Elle doit être vraie sur TROIS AXES À LA FOIS, et c'est là toute la
// difficulté — les trois se contredisent souvent :
//
//   1. LE RAIL. Deux gares consécutives sont voisines dans le réseau réel
//      (js/network.js, qui dérive lui-même de data/lines.js). Une ligne n'est
//      pas une liste, c'est un trajet.
//   2. LA DIFFICULTÉ. Elle monte le long de la ligne, sinon la progression
//      n'en est pas une. On tolère UNE inversion d'UN cran par ligne : exiger
//      la monotonie stricte ne laisse presque aucun découpage possible, parce
//      qu'une petite gare voisine d'un grand nœud est la géographie normale.
//   3. LA COUVERTURE. Chaque gare appartient à une ligne et une seule. Une
//      gare orpheline n'est jouable par aucun chemin ; une gare en double
//      casse la règle d'ouverture.
//
// Le problème est une COUVERTURE PAR CHEMINS sous contraintes — NP-difficile en
// général, mais 145 gares tiennent largement dans un glouton randomisé à
// redémarrages, suivi d'une passe de réparation. On garde le meilleur score sur
// quelques milliers de tirages.
//
// CE QUE CET OUTIL NE FAIT PAS : nommer les lignes. « Sillon Sambre-et-Meuse »
// ne se déduit d'aucun graphe. Il propose « Mons – Namur » et laisse le nom à
// l'auteur ; c'est le seul travail vraiment humain de l'affaire.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";

const ROOT = new URL("..", import.meta.url).pathname;
const read = f => readFileSync(ROOT + f, "utf8");

// --- arguments ---
const argv = process.argv.slice(2);
let SEED = 1, EMIT_JS = false;
// LA GARE-BOSS TIENT-ELLE DANS UNE LIGNE ? Mesuré : non. Seules 4 des 29 gares
// de niveau 4 touchent leur boss ; en France et au Royaume-Uni, aucune. Une
// ligne qui monterait jusqu'au niveau 5 n'existe donc pas — Paris-Nord ne
// touche que du 1, 2 et 3. Avec --boss-apart, le boss sort du découpage : il
// s'ouvre au GRADE (voir le lot 3), ce qui est aussi ce qu'il devait devenir.
let BOSS_APART = false;
// --trajet : LA LIGNE EST UN TRAJET, PAS UNE RAMPE. On retire la contrainte
// d'ascension à l'intérieur d'une ligne et l'on ne garde que le rail et la
// lisibilité du tracé. La difficulté est alors portée par l'ORDRE DES LIGNES —
// la première du pays est la plus douce, la dernière la plus rude — ce qui est
// la seule échelle que la géographie autorise réellement (mesure : 45 % des
// gares de niveau 2 seulement touchent un niveau 3).
let TRAJET = false;
// --spectre : LE TRAJET DESSINE, LA DIFFICULTE ORDONNE.
//
// Les deux modes precedents echouent chacun a leur facon, et pour la meme
// raison : ils supposent qu'on ouvre les gares d'une ligne DANS L'ORDRE DU
// RAIL. Or rien ne l'impose. Si la ligne est un TRAJET qu'on dessine, et qu'a
// l'interieur on ouvre toujours la gare la plus facile encore fermee, la
// difficulte monte PAR CONSTRUCTION - sans jamais contraindre le trace.
//
// Il ne reste qu'une exigence, et elle est douce : que le SPECTRE de la ligne
// soit regulier. Une ligne 1.1.1.4.4 monte bien mais fait une falaise au
// troisieme pas ; une ligne 1.2.3.4.4 se gravit. On note donc le plus grand
// ecart entre deux difficultes consecutives une fois la ligne TRIEE.
let SPECTRE = false;
const filter = [];
for (const a of argv) {
  const m = /^--seed=(\d+)$/.exec(a);
  if (m) { SEED = +m[1]; continue; }
  if (a === "--js") { EMIT_JS = true; continue; }
  if (a === "--boss-apart") { BOSS_APART = true; continue; }
  if (a === "--trajet") { TRAJET = true; continue; }
  if (a === "--spectre") { TRAJET = true; SPECTRE = true; continue; }
  filter.push(a);
}

// Tirage reproductible : deux exécutions doivent proposer le MÊME découpage,
// sinon on ne peut ni le relire, ni le comparer, ni le discuter.
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
let rnd = mulberry32(SEED);
const pick = arr => arr[Math.floor(rnd() * arr.length)];
const shuffle = arr => {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
};

// --- le réseau, chargé comme le fait tools/net-check.mjs ---
const ctx = createContext({ console });
for (const [file, names] of [
  ["js/network.js", ["NET"]],
  ["data/places.js", ["PLACES", "PLACE_ALIASES"]],
  ["data/lines.js", ["LINES", "LINE_COUNTRIES"]],
  ["js/geo.js", ["GEO"]]
]) runInContext(read(file) + "\n" + names.map(n => `globalThis.${n} = ${n};`).join(""), ctx);

const index = JSON.parse(read("data/stations/index.json"));
const CATALOG = [];
const countryOf = {}, groupOf = {};
for (const g of index)
  for (const id of g.stations) {
    CATALOG.push(JSON.parse(read(`data/stations/${g.country}/${id}.json`)));
    countryOf[id] = g.country; groupOf[id] = g;
  }
ctx.CATALOG = CATALOG;
const { netLinks, GEO } = ctx;

const card = Object.fromEntries(CATALOG.map(c => [c.id, c]));
const diff = id => Math.max(1, Math.min(5, card[id].difficulty || 1));
const nameOf = id => card[id].city || card[id].name || id;

// Coordonnées, pour départager deux découpages à mérite égal : à contraintes
// respectées, la ligne qui zigzague le moins est la meilleure — c'est celle
// qu'un joueur reconnaîtra comme un trajet.
const lonlat = {};
for (const slug in GEO.countries)
  for (const id in GEO.countries[slug].cities) lonlat[id] = GEO.countries[slug].cities[id];
function km(a, b) {
  if (!a || !b) return 0;
  const t = Math.PI / 180;
  const dx = (b[0] - a[0]) * t * Math.cos((a[1] + b[1]) / 2 * t), dy = (b[1] - a[1]) * t;
  return 6371 * Math.hypot(dx, dy);
}
// Sinuosité : longueur parcourue ÷ distance entre les deux bouts. 1 = ligne
// droite. Au-delà de ~2,5 le trajet revient sur ses pas et ne se lit plus.
function sinuosity(ids) {
  let walk = 0;
  for (let i = 0; i + 1 < ids.length; i++) walk += km(lonlat[ids[i]], lonlat[ids[i + 1]]);
  const span = km(lonlat[ids[0]], lonlat[ids[ids.length - 1]]);
  return span < 1 ? 99 : walk / span;
}

// ------------------------------------------------------------------
// LES RÈGLES D'UNE LIGNE, écrites une fois et interrogées partout.
// ------------------------------------------------------------------
const LEN_MIN = 4, LEN_MAX = 6, LEN_TARGET = 5;
// Une inversion d'un cran, une seule fois. Voir l'en-tête : la monotonie
// stricte est infaisable sur un vrai réseau.
const INV_MAX = 1, DROP_MAX = 1;
// Somme des crans sautés en trop sur toute la ligne. 1 autorise un seul saut de
// deux crans quelque part — au-delà, la ligne cesse d'être une échelle.
const JUMP_MAX = 1;

// UNE LIGNE EST UNE ÉCHELLE, PAS SEULEMENT UNE MONTÉE.
//
// Ne compter que les DESCENTES laissait passer le pire : Landen (1) › Hasselt
// (2) › Aarschot (1) › Herentals (1) › Anvers (4) n'a qu'une inversion et
// respecte le rail — mais le joueur y fait trois gares de niveau 1 puis se
// heurte à un niveau 4. Ce n'est pas une progression, c'est un mur avec une
// salle d'attente devant.
//
// On mesure donc les deux : les descentes (`n`, `worst`) et les MARCHES TROP
// HAUTES (`jump` — tout écart de plus d'un cran entre deux gares qui se
// suivent). Une ligne peut monter 1·2·3·4, jamais 1·1·1·4.
function inversions(ids) {
  let n = 0, worst = 0, jump = 0;
  for (let i = 0; i + 1 < ids.length; i++) {
    const d = diff(ids[i]) - diff(ids[i + 1]);
    if (d > 0) { n++; worst = Math.max(worst, d); }
    else jump += Math.max(0, -d - 1);   // un cran d'écart est normal, deux non
  }
  return { n, worst, jump };
}
function ascOk(ids) {
  if (TRAJET) return true;          // le rail seul décide
  const { n, worst, jump } = inversions(ids);
  return n <= INV_MAX && worst <= DROP_MAX && jump <= JUMP_MAX;
}

// ------------------------------------------------------------------
// LE GLOUTON RANDOMISÉ — une tentative de découpage.
// ------------------------------------------------------------------
// On part TOUJOURS de la gare la plus facile encore libre : une ligne se lit du
// débutant vers le boss, et commencer par le milieu produit des lignes qui
// descendent. À chaque pas on étend vers la voisine libre la moins difficile
// qui respecte encore la règle d'ascension.
//
// Le choix parmi les candidates est pondéré : on préfère celle qui a le MOINS
// de voisines libres restantes. Sans cela le glouton mange les carrefours en
// premier et laisse les culs-de-sac (Arlon, Nice, Plymouth) orphelins.
function growOnce(ids, adj) {
  const free = new Set(ids);
  const lines = [];
  while (free.size) {
    const starts = [...free].sort((a, b) => diff(a) - diff(b) || (rnd() - 0.5));
    const seed = starts[0];
    const line = [seed];
    free.delete(seed);
    const want = pick([LEN_MIN, LEN_TARGET, LEN_TARGET, LEN_TARGET, LEN_MAX]);
    while (line.length < want) {
      const u = line[line.length - 1];
      const cand = (adj[u] || []).filter(v => free.has(v) && ascOk(line.concat(v)));
      if (!cand.length) break;
      // Poids : d'abord la difficulté la plus proche (la marche la plus douce),
      // ensuite la voisine la plus « coincée ».
      const degLeft = v => (adj[v] || []).filter(w => free.has(w)).length;
      cand.sort((a, b) =>
        (diff(a) - diff(b)) || (degLeft(a) - degLeft(b)) || (rnd() - 0.5));
      // On ne prend pas systématiquement la première : un glouton déterministe
      // ne profite pas des redémarrages.
      const v = rnd() < 0.75 ? cand[0] : pick(cand);
      line.push(v);
      free.delete(v);
    }
    lines.push(line);
  }
  return lines;
}

// ------------------------------------------------------------------
// RÉPARATION — recoller les lignes trop courtes.
// ------------------------------------------------------------------
// Le glouton laisse toujours quelques bouts de 1 à 3 gares : ce sont les
// dernières gares libres, souvent en cul-de-sac. On tente, dans l'ordre :
//   • les RACCROCHER à une ligne voisine qui a encore de la place ;
//   • les FUSIONNER deux à deux quand leurs extrémités se touchent.
// Ce qui reste court est signalé, jamais caché.
function repair(lines, adj) {
  const isLine = l => l.length >= LEN_MIN;
  // UNE seule opération par appel, puis on recommence. Muter le tableau qu'on
  // parcourt est le plus court chemin vers un index qui glisse : la boucle
  // continuait sur une entrée déjà retirée.
  const joinable = (A, B) =>
    adj[A[A.length - 1]]?.includes(B[0]) &&
    A.length + B.length <= LEN_MAX &&
    ascOk(A.concat(B));
  function step() {
    for (let i = 0; i < lines.length; i++) {
      if (isLine(lines[i])) continue;         // seuls les bouts courts cherchent
      const short = lines[i];
      for (let j = 0; j < lines.length; j++) {
        if (i === j) continue;
        // On essaie les quatre appariements : chaque bout peut se lire dans les
        // deux sens tant qu'il n'est pas encore une ligne établie.
        const A = [short, [...short].reverse()];
        const B = isLine(lines[j]) ? [lines[j]] : [lines[j], [...lines[j]].reverse()];
        for (const a of A) for (const b of B) {
          if (joinable(b, a)) { lines[j] = b.concat(a); lines.splice(i, 1); return true; }
          if (joinable(a, b)) { lines[j] = a.concat(b); lines.splice(i, 1); return true; }
        }
      }
    }
    return false;
  }
  while (step()) { /* jusqu'à ce qu'il n'y ait plus rien à recoller */ }
  return lines;
}

// ------------------------------------------------------------------
// LE SCORE — ce qui fait qu'un découpage vaut mieux qu'un autre.
// ------------------------------------------------------------------
// Les poids disent l'ordre des priorités, et rien d'autre : une gare orpheline
// est bien pire qu'une ligne un peu sinueuse.
function score(lines) {
  let s = 0, orphans = 0, short = 0, inv = 0, jmp = 0, sin = 0, worstSin = 0, spec = 0;
  for (const l of lines) {
    if (l.length < LEN_MIN) { short++; orphans += (LEN_MIN - l.length); }
    const iv = inversions(l);
    inv += iv.n; jmp += iv.jump;
    // La sinuosité pèse LOURD, et de plus en plus : c'est elle qui décide si le
    // joueur lit un trajet ou une liste. Une ligne qui revient sur ses pas
    // (Deinze › Courtrai › Bruges › Gand, ×7,6) respecte pourtant le rail et la
    // difficulté — les deux premiers critères ne suffisent donc pas à faire une
    // ligne. Le carré punit l'aberration sans gêner le trajet un peu courbe,
    // qui est la normale d'un vrai réseau.
    const x = Math.max(0, sinuosity(l) - 1.4);
    sin += x * x;
    worstSin = Math.max(worstSin, sinuosity(l));
    // Le spectre : les difficultes de la ligne, TRIEES. C'est l'ordre dans
    // lequel le joueur les rencontrera, puisqu'il ouvre toujours la plus
    // facile encore fermee. Une marche de plus d'un cran y est une falaise.
    if (SPECTRE) {
      const ds = l.map(diff).sort((a, b) => a - b);
      for (let i = 0; i + 1 < ds.length; i++) spec += Math.max(0, ds[i + 1] - ds[i] - 1);
    }
  }
  s += orphans * 400 + short * 120 + sin * 30 + spec * 25 + (TRAJET ? 0 : inv * 8 + jmp * 20);
  // Une ligne se termine sur sa gare la plus dure : c'est le terminus, et c'est
  // lui qui porte la célébration. Une ligne dont le boss est au milieu se lit mal.
  if (!TRAJET) for (const l of lines)
    if (diff(l[l.length - 1]) < Math.max(...l.map(diff))) s += 25;
  return { s, orphans, short, inv, jmp, sin, worstSin, spec };
}

// ------------------------------------------------------------------
// DÉCOUPAGE D'UN PAYS : beaucoup de tirages, on garde le meilleur.
// ------------------------------------------------------------------
function solveCountry(group) {
  let ids = group.stations.slice();
  const boss = BOSS_APART ? ids.filter(id => diff(id) === 5) : [];
  if (boss.length) ids = ids.filter(id => diff(id) !== 5);
  const adj = {};
  for (const id of ids)
    adj[id] = netLinks(id).to.filter(x => countryOf[x] === group.country);
  let best = null, bestS = Infinity, bestDetail = null;
  const N = 20000;
  for (let k = 0; k < N; k++) {
    const lines = repair(growOnce(ids, adj), adj);
    const sc = score(lines);
    if (sc.s < bestS) { bestS = sc.s; best = lines; bestDetail = sc; }
    if (bestS === 0) break;
  }
  // Ordre de jeu : la ligne la plus facile d'abord (par la difficulté de sa
  // gare de départ, puis de son terminus).
  const moy = l => l.reduce((s, id) => s + diff(id), 0) / l.length;
  best.sort(TRAJET
    ? (a, b) => moy(a) - moy(b) || Math.max(...a.map(diff)) - Math.max(...b.map(diff))
    : (a, b) => diff(a[0]) - diff(b[0]) ||
                diff(a[a.length - 1]) - diff(b[b.length - 1]));
  return { lines: best, detail: bestDetail, adj, boss };
}

// ------------------------------------------------------------------
// RAPPORT
// ------------------------------------------------------------------
const groups = index.filter(g => !filter.length || filter.includes(g.country));
const all = [];
let totalOrphans = 0, totalShort = 0, totalInv = 0, totalJump = 0, totalSpec = 0;

for (const g of groups) {
  rnd = mulberry32(SEED);           // même graine pour chaque pays : reproductible
  const { lines, detail, boss } = solveCountry(g);
  totalOrphans += detail.orphans; totalShort += detail.short;
  totalInv += detail.inv; totalJump += detail.jmp; totalSpec += detail.spec;
  console.log(`\n${"═".repeat(74)}\n${g.label} — ${g.stations.length} gares, ${lines.length} lignes\n`);
  lines.forEach((l, i) => {
    const chain = l.map(id => `${nameOf(id)} (${diff(id)})`).join("  ›  ");
    const ordre = SPECTRE ? l.slice().sort((a, b) => diff(a) - diff(b))
      .map(id => nameOf(id) + " (" + diff(id) + ")").join("  →  ") : "";
    const { n, jump } = inversions(l);
    const sin = sinuosity(l);
    const flags = [];
    if (l.length < LEN_MIN) flags.push(`COURTE ${l.length}`);
    // En mode --spectre, l'ordre du TRACE ne se joue pas : le joueur ouvre
    // les gares par difficulte croissante. Signaler ses "inversions"
    // reviendrait a reprocher a une ligne de ne pas etre ce qu'elle n'est plus.
    if (!SPECTRE) {
      if (n) flags.push(`${n} inversion${n > 1 ? "s" : ""}`);
      if (jump) flags.push(`marche de ${jump + 1} crans`);
    }
    if (sin > 2.2) flags.push(`sinueuse ×${sin.toFixed(1)}`);
    if (SPECTRE) {
      const ds = l.map(diff).sort((a, b) => a - b);
      let g = 0; for (let i = 0; i + 1 < ds.length; i++) g = Math.max(g, ds[i + 1] - ds[i]);
      if (g > 1) flags.push(`falaise de ${g} crans`);
    }
    console.log(`  ${String(i + 1).padStart(2)}. ${nameOf(l[0])} – ${nameOf(l[l.length - 1])}`.padEnd(36) +
      (flags.length ? `  ⚠ ${flags.join(", ")}` : ""));
    console.log(`      ${chain}`);
    if (ordre) console.log(`      ouverture : ${ordre}`);
  });
  if (boss.length)
    console.log(`\n  ★ hors ligne, ouverte au GRADE : ${boss.map(nameOf).join(", ")}`);
  all.push({ group: g, lines, boss });
}

console.log(`\n${"═".repeat(74)}`);
const nLines = all.reduce((a, x) => a + x.lines.length, 0);
const nStations = all.reduce((a, x) => a + x.lines.flat().length, 0);
console.log(`${nLines} lignes · ${nStations} gares couvertes · ` +
  `${totalShort} ligne(s) courte(s) · ` +
  (SPECTRE ? `${totalSpec} falaise(s) de difficulte`
           : `${totalInv} inversion(s) · ${totalJump} marche(s) haute(s)`));
console.log(`graine ${SEED} — le même appel redonne exactement ce découpage.\n`);

// --- couverture : la seule erreur qui ne se discute pas ---
const seen = new Set();
let dup = 0;
for (const { lines } of all) for (const l of lines) for (const id of l) {
  if (seen.has(id)) { console.log(`⚠ EN DOUBLE : ${id}`); dup++; }
  seen.add(id);
}
for (const { boss } of all) for (const id of (boss || [])) seen.add(id);
const missing = CATALOG.filter(c => !seen.has(c.id) &&
  (!filter.length || filter.includes(countryOf[c.id])));
if (missing.length) console.log(`⚠ ORPHELINES : ${missing.map(c => c.id).join(", ")}`);
if (!dup && !missing.length) console.log("✓ couverture exacte : chaque gare dans une ligne et une seule");

// --- sortie JS, à coller dans data/services.js une fois les noms écrits ---
if (EMIT_JS) {
  console.log("\n" + "─".repeat(74) + "\nconst SERVICES = [");
  for (const { group, lines } of all) {
    console.log(`  // ---- ${group.label} ----`);
    lines.forEach((l, i) => {
      const slug = group.country + "-" + (i + 1);
      console.log(`  { id: ${JSON.stringify(slug)}, country: ${JSON.stringify(group.country)},`);
      console.log(`    name: ${JSON.stringify(nameOf(l[0]) + " – " + nameOf(l[l.length - 1]))},   // À NOMMER`);
      console.log(`    stations: ${JSON.stringify(l)} },`);
    });
  }
  console.log("];");
}
