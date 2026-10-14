#!/usr/bin/env node
// ------------------------------------------------------------------
// labyrinthe-banc — LE BANC D'ESSAI DU PROTOTYPE « LABYRINTHE D'EAU ».
//
//   node tools/labyrinthe-banc.mjs                 30 parties au hasard (≈ 1 min)
//   node tools/labyrinthe-banc.mjs --parties=100 --graine=7
//
// Le moteur (prototypes/prototype-labyrinthe.html, bloc <script id="moteur">)
// et le niveau (bloc JSON « niveau ») sont extraits du fichier et joués sans
// navigateur — jamais une copie de l'un ou de l'autre. Le banc REFUSE (code
// de sortie 1) au lieu d'avertir.
//
// L'eau est continue (une masse par petite case, 4 × 4 par case du
// labyrinthe) : on ne peut pas tout fouiller.
// Le banc joue « au repos » — chaque tape, puis on attend que l'eau et la
// boule se posent — comme le solveur de la page.
//
// LES DONNÉES — un niveau mal écrit, avant même de le jouer :
//   D1  une grille rectangulaire, des caractères connus, une boule, une
//       sortie au bord, une vanne par chiffre et un type connu par vanne
//   D2  au chargement rien ne coule et la boule ne bouge plus
//
// LA SOLUTION :
//   S1  la « solution » écrite se rejoue jusqu'à la sortie
//   S2  sa longueur est le « par », et aucune suite plus courte n'est
//       trouvée parmi celles de deux séries au plus (une série = la même
//       vanne tapée plusieurs fois d'affilée : c'est ainsi qu'on joue ;
//       trois séries coûteraient plusieurs minutes à grain fin)
//   S3  chaque suite de « pieges » NE sort PAS la boule
//
// LES INVARIANTS — à chaque pas d'eau de parties jouées au hasard, une
// violation est un bug du moteur, pas un réglage :
//   I1  l'eau se compte : dans la grille = départ + versé − sorti − vidé,
//       à 1e-9 case près
//   I2  aucune masse négative, aucun NaN
//   I3  la même suite de tapes donne le même état
//   I4  la boule reste dans une case ouverte de la grille
//   I5  l'eau se pose : chaque tape finit au repos
//
// LES MESURES — en information, pas des refus : le point de départ du plan
// d'essai sur le rendu de l'eau (reports/Animation de fluides pour jeu.md) :
//   M1  la butte : le plus grand écart de hauteur entre les surfaces libres
//       d'un même corps d'eau posée, pendant 10 unités versées en appui long
//       (après les vidanges de la solution), en cases — hors de la case du
//       robinet : c'est sa bouche, l'eau y est plus haute puisqu'elle en sort
//   M2  le tube en U : images pour que deux colonnes reliées par le fond
//       se mettent de niveau (écart < 0,05 case), l'une pleine, l'autre vide
//   M3  le repos : images entre une tape et le repos, sur la solution, et
//       le relief des nappes une fois au repos (une eau au repos est plate)
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const FICHIER = "prototypes/prototype-labyrinthe.html";
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n + "=")); return a ? a.split("=")[1] : null; };
for (const a of args) if (!/^--(parties|graine)=/.test(a)) { console.error("argument inconnu : " + a); process.exit(2); }
const PARTIES = +(opt("parties") || 30);
const GRAINE = +(opt("graine") || 1);
const TAPES = 30, SERIES = 2;

const html = readFileSync(join(RACINE, FICHIER), "utf8");
function bloc(id) {
  const m = html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'));
  if (!m) { console.error("bloc introuvable dans " + FICHIER + " : " + id); process.exit(2); }
  return m[1];
}
const N = JSON.parse(bloc("niveau"));
const ctx = createContext({ console });
runInContext(bloc("moteur") + "\n;globalThis.Labyrinthe = Labyrinthe;", ctx, { filename: "moteur.js" });
const L = ctx.Labyrinthe;

function Hasard(graine) {
  let a = (graine >>> 0) || 1;
  return () => {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
let echecs = 0;
const dire = (ok, texte) => { console.log((ok ? "  ✓ " : "  ✗ ") + texte); if (!ok) echecs++; };
const lire = s => [...s].map(c => +c - 1);
const compact = s => { const o = []; for (const k of s) { const d = o[o.length - 1]; if (d && d.k === k) d.n++; else o.push({ k, n: 1 }); } return o.map(d => `${d.k + 1}×${d.n}`).join(", "); };

function donnees() {
  const v = [], g = N.grille || [];
  if (!g.length || g.some(r => r.length !== g[0].length)) return ["grille vide ou pas rectangulaire"];
  const H = g.length, W = g[0].length;
  let boules = 0, sorties = 0;
  const chiffres = new Set();
  g.forEach((r, ry) => [...r].forEach((ch, x) => {
    if (!/[#.So~1-9]/.test(ch)) v.push(`caractère inconnu « ${ch} » en ${x},${H - 1 - ry}`);
    if (ch === "o") boules++;
    if (ch === "S") { sorties++; if (!(x === 0 || x === W - 1 || ry === 0 || ry === H - 1)) v.push(`sortie ${x},${H - 1 - ry} hors du bord`); }
    if (/[1-9]/.test(ch)) { if (chiffres.has(ch)) v.push(`vanne ${ch} en double`); chiffres.add(ch); }
  }));
  if (boules !== 1) v.push(`${boules} boule(s), il en faut une`);
  if (!sorties) v.push("aucune sortie");
  const n = (N.vannes || []).length;
  for (let k = 1; k <= n; k++) if (!chiffres.has(String(k))) v.push(`vanne ${k} absente de la grille`);
  if (chiffres.size !== n) v.push(`${chiffres.size} chiffres dans la grille pour ${n} vannes`);
  (N.vannes || []).forEach((t, k) => { if (!["robinet", "vidange"].includes(t.type)) v.push(`vanne ${k + 1} : type « ${t.type} » inconnu`); });
  if (!/^[1-9]+$/.test(N.solution || "")) v.push("« solution » manquante ou mal écrite");
  return v;
}

const G0 = { eau: null };
function invariants(G, e, ou) {
  const v = [];
  let dedans = 0;
  for (let i = 0; i < e.m.length; i++) {
    if (!Number.isFinite(e.m[i])) { v.push(`I2 ${ou} : NaN en case ${i}`); break; }
    if (e.m[i] < -1e-9) { v.push(`I2 ${ou} : masse ${e.m[i]} en case ${i}`); break; }
    dedans += e.m[i];
  }
  dedans /= G.S2;                                   // en cases du labyrinthe
  const attendu = G0.eau + e.verse - e.sorti - e.vide;
  if (Math.abs(dedans - attendu) > 1e-9) v.push(`I1 ${ou} : ${dedans.toFixed(6)} d'eau, attendu ${attendu.toFixed(6)}`);
  if (!L.ouvert(G, Math.floor(e.b.x), Math.floor(e.b.y)) && !e.gagne) v.push(`I4 ${ou} : boule en ${e.b.x.toFixed(2)},${e.b.y.toFixed(2)}`);
  return v;
}
// Une tape vérifiée pas à pas jusqu'au repos.
function tapeVerifiee(G, e, k, viol, ou) {
  const t = L.taper(N, e, k);
  if (!t) return null;
  for (let n = 0; !L.repos(t); n++) {
    if (n > 6000) { viol.push(`I5 ${ou} : pas de repos`); return null; }
    L.pas(N, t);
    if (viol.length < 4) viol.push(...invariants(G, t, ou));
  }
  return t;
}
function jouerSuite(suite) { let e = L.charger(N); for (const k of suite) { const r = L.jouer(N, e, k); if (r) e = r; if (e.gagne) break; } return e; }

console.log(`Labyrinthe d'eau — « ${N.titre} », ${PARTIES} parties au hasard, graines ${GRAINE}…${GRAINE + PARTIES - 1}`);
const d = donnees();
let G = null;
if (!d.length) {
  G = L.prep(N);
  const e = L.charger(N), x = e.b.x, y = e.b.y;
  let flux = 0;
  for (let n = 0; n < 200; n++) flux += L.pas(N, e);
  if (flux > 1e-6) d.push(`D2 l'eau coule au chargement (${flux.toExponential(2)})`);
  if (Math.hypot(e.b.x - x, e.b.y - y) > 1e-3) d.push(`D2 la boule bouge au chargement (${x.toFixed(2)},${y.toFixed(2)} → ${e.b.x.toFixed(2)},${e.b.y.toFixed(2)})`);
  G0.eau = L.charger(N).m.reduce((a, b) => a + b, 0) / G.S2;
}
dire(!d.length, "D1-D2 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));
if (d.length) process.exit(1);

const sol = lire(N.solution);
dire(jouerSuite(sol).gagne, `S1 la solution écrite sort la boule : ${compact(sol)}`);
// S2 : une fouille en profondeur, au plus SERIES séries, coupée au par
let plusCourte = null, noeuds = 0;
const t0 = Date.now();
(function dfs(e, suite, series, dernier) {
  if (suite.length >= (plusCourte ? plusCourte.length : sol.length) - 1) return;
  for (let k = 0; k < G.vannes.length; k++) {
    const nouvelle = k !== dernier;
    if (nouvelle && series >= SERIES) continue;
    const e2 = L.jouer(N, e, k); noeuds++;
    if (!e2) continue;
    const s2 = suite.concat(k);
    if (e2.gagne) { plusCourte = s2; continue; }
    dfs(e2, s2, series + (nouvelle ? 1 : 0), k);
  }
})(L.charger(N), [], 0, -1);
dire(sol.length === N.par && !plusCourte,
  `S2 par ${N.par} = solution ${sol.length}` + (plusCourte ? ` — mais ${compact(plusCourte)} gagne en ${plusCourte.length}` : `, rien de plus court en ${SERIES} séries (${noeuds} suites, ${Date.now() - t0} ms)`));
for (const p of N.pieges || []) dire(!jouerSuite(lire(p)).gagne, `S3 le piège ${compact(lire(p))} ne sort pas la boule`);

const viol = [];
let gagnees = 0;
for (let p = 0; p < PARTIES && viol.length < 4; p++) {
  const h = Hasard(GRAINE + p), suite = [];
  let e = L.charger(N);
  for (let t = 0; t < TAPES && !e.gagne; t++) {
    const k = Math.floor(h() * G.vannes.length);
    const r = tapeVerifiee(G, e, k, viol, `partie ${GRAINE + p}, tape ${t + 1} (vanne ${k + 1})`);
    if (viol.length) break;
    if (!r) continue;
    e = r; suite.push(k);
  }
  if (!viol.length && L.cle(jouerSuite(suite)) !== L.cle(e)) viol.push(`I3 partie ${GRAINE + p} : la même suite donne un autre état`);
  if (e.gagne) gagnees++;
}
dire(!viol.length, `I1-I5 invariants à chaque pas de ${PARTIES} parties de ${TAPES} tapes` + (viol.length ? " :\n      " + viol.slice(0, 4).join("\n      ") : ""));
console.log(`    au hasard : ${Math.round(100 * gagnees / PARTIES)} % des parties sortent la boule`);

// --- les mesures -------------------------------------------------------
// Le relief d'une nappe : dans chaque corps d'eau POSÉE (petites cases
// mouillées, sur un mur ou sur de l'eau pleine, reliées par un côté), l'écart
// entre sa surface libre la plus haute et la plus basse. L'eau qui tombe ne
// relie rien : une chute d'un rebord à une nappe n'est pas une butte.
function relief(M, e) {
  const g = L.prep(M), W = g.SW, m = e.m, corps = new Int32Array(m.length).fill(-1);
  const posee = i => i < W || g.fmur[i - W] || m[i - W] >= 0.95;
  const bouche = new Set(g.vannes.filter(v => v.type === "robinet").flatMap(v => v.bloc));
  let n = 0, pire = 0;
  for (let i0 = 0; i0 < m.length; i0++) {
    if (g.fmur[i0] || m[i0] <= 0.01 || corps[i0] >= 0 || !posee(i0)) continue;
    const pile = [i0]; corps[i0] = n;
    let haut = -Infinity, bas = Infinity;
    while (pile.length) {
      const i = pile.pop(), x = i % W, y = (i - x) / W;
      const air = y + 1 < g.SH && !g.fmur[i + W] && m[i + W] <= 0.01;
      if (air && !bouche.has(i)) { const h = (y + Math.min(1, m[i])) / g.S; haut = Math.max(haut, h); bas = Math.min(bas, h); }
      for (const j of [i - 1, i + 1, i - W, i + W]) {
        if (j < 0 || j >= m.length || corps[j] >= 0 || g.fmur[j] || m[j] <= 0.01 || !posee(j)) continue;
        if ((j === i - 1 && x === 0) || (j === i + 1 && x === W - 1)) continue;
        corps[j] = n; pile.push(j);
      }
    }
    if (haut > bas) pire = Math.max(pire, haut - bas);
    n++;
  }
  return pire;
}
{
  // M1 : les vidanges de la solution, puis 10 unités en appui long (une de
  // plus dès que la précédente est passée, comme la vue), puis 60 images
  let e = L.charger(N);
  const rob = G.vannes.findIndex(v => v.type === "robinet");
  for (const k of sol.slice(0, sol.indexOf(rob))) e = L.jouer(N, e, k);
  let verse = 0, butte = 0, apres = 0;
  for (let im = 0; im < 4000 && apres < 60; im++) {
    if (verse < 10 && e.attente[rob] < 0.05) { e = L.taper(N, e, rob); verse++; }
    L.pas(N, e);
    butte = Math.max(butte, relief(N, e));
    if (verse >= 10 && e.attente[rob] === 0) apres++;
  }
  console.log(`    M1 butte : relief maximal ${butte.toFixed(2)} case pendant 10 unités versées en continu`);
}
{
  const U = { titre: "tube en U", grille: ["#######", "#.###o#", "#~###.#", "#~###.#", "#~###.#", "#~###.#", "#~~~~~#", "#######"], vannes: [] };
  const e = L.charger(U), g = L.prep(U);
  // la hauteur de l'eau dans une colonne du labyrinthe : son sommet mouillé, au milieu de la colonne
  const colonne = x => {
    const fx = x * g.S + (g.S >> 1);
    for (let fy = g.SH - 1; fy >= 0; fy--) { const m = e.m[fy * g.SW + fx]; if (!g.fmur[fy * g.SW + fx] && m > 0.01) return (fy + Math.min(1, m)) / g.S; }
    return 0;
  };
  let im = 0;
  while (im < 3000 && Math.abs(colonne(1) - colonne(5)) >= 0.05) { L.pas(U, e); im++; }
  console.log(`    M2 tube en U : ${im < 3000 ? im + " images" : "pas de niveau en 3000 images"} pour se mettre de niveau (écart < 0,05 case)`);
}
{
  let e = L.charger(N);
  const durees = [];
  let plat = 0;
  for (const k of sol) { const avant = e.pas; e = L.jouer(N, e, k); durees.push(e.pas - avant); if (!e.gagne) plat = Math.max(plat, relief(N, e)); }
  const moy = durees.reduce((a, b) => a + b, 0) / durees.length;
  console.log(`    M3 repos : ${moy.toFixed(0)} images en moyenne entre une tape et le repos, ${Math.max(...durees)} au plus ; au repos, relief des nappes ${plat.toFixed(3)} case au plus`);
}
console.log(echecs ? `\n${echecs} échec(s).` : "\nTout est vert.");
process.exit(echecs ? 1 : 0);
