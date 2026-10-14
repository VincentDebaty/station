#!/usr/bin/env node
// ------------------------------------------------------------------
// labyrinthe-banc — LE BANC D'ESSAI DU PROTOTYPE « LABYRINTHE D'EAU ».
//
//   node tools/labyrinthe-banc.mjs                 300 parties au hasard
//   node tools/labyrinthe-banc.mjs --parties=2000 --graine=7
//
// Le moteur (prototypes/prototype-labyrinthe.html, bloc <script id="moteur">)
// et le niveau (bloc JSON « niveau ») sont extraits du fichier et joués sans
// navigateur — jamais une copie de l'un ou de l'autre. Le banc REFUSE (code
// de sortie 1) au lieu d'avertir.
//
// LES DONNÉES — un niveau mal écrit, avant même de le jouer :
//   D1  une grille rectangulaire, des caractères connus, une boule, une
//       sortie au bord, une vanne par chiffre et un type connu par vanne
//   D2  au chargement rien ne bouge : la boule est déjà où elle se pose, et
//       aucune eau ne tient au-dessus du vide
//
// LA SOLUTION :
//   S1  le solveur trouve une solution, et elle se rejoue jusqu'à la sortie
//   S2  sa longueur est exactement le « par » écrit dans le niveau
//   S3  si « requises » : sans n'importe laquelle des vannes, le niveau est
//       impossible — fouille épuisée, pas seulement rien trouvé
//
// LES INVARIANTS — sur des parties jouées au hasard, une violation est un
// bug du moteur, pas un réglage :
//   I1  l'eau se compte : cases pleines = départ + versé − sorti − vidé
//   I2  aucune eau au-dessus du vide (l'eau tombe toujours jusqu'au bout)
//   I3  la même tape sur le même état donne le même état
//   I4  la boule reste dans une case ouverte de la grille
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
const PARTIES = +(opt("parties") || 300);
const GRAINE = +(opt("graine") || 1);
const TAPES = 80;

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
  return v;
}
function suspendue(G, e) {
  for (let i = 0; i < e.eau.length; i++) {
    if (!e.eau[i]) continue;
    const x = i % G.W, y = (i - x) / G.W;
    if (L.ouvert(G, x, y - 1) && !e.eau[L.idx(G, x, y - 1)]) return `${x},${y}`;
  }
  return null;
}
function invariants(G, e, eau0, ou) {
  const v = [];
  const n = e.eau.reduce((a, b) => a + b, 0), attendu = eau0 + e.verse - e.sorti - e.vide;
  if (n !== attendu) v.push(`I1 ${ou} : ${n} cases d'eau, attendu ${attendu}`);
  const s = suspendue(G, e);
  if (s) v.push(`I2 ${ou} : eau suspendue en ${s}`);
  if (!L.ouvert(G, e.boule.x, e.boule.y)) v.push(`I4 ${ou} : boule en ${e.boule.x},${e.boule.y}`);
  return v;
}
// Fouille complète sans la vanne k : null si impossible (épuisé), sinon une longueur.
function sansVanne(k) {
  const G = L.prep(N), e0 = L.charger(N), vus = new Set([L.cle(e0)]);
  let front = [e0], prof = 0;
  while (front.length) {
    prof++;
    const suivant = [];
    for (const e of front) for (let j = 0; j < G.vannes.length; j++) {
      if (j === k) continue;
      const r = L.taper(N, e, j);
      if (!r) continue;
      const c = L.cle(r.e);
      if (vus.has(c)) continue;
      vus.add(c);
      if (r.e.gagne) return prof;
      suivant.push(r.e);
    }
    front = suivant;
  }
  return null;
}

console.log(`Labyrinthe d'eau — « ${N.titre} », ${PARTIES} parties au hasard, graines ${GRAINE}…${GRAINE + PARTIES - 1}`);
const d = donnees();
let G = null;
if (!d.length) {
  G = L.prep(N);
  const e = L.charger(N);
  if (e.boule.x !== G.boule.x || e.boule.y !== G.boule.y) d.push(`D2 la boule bouge au chargement (${G.boule.x},${G.boule.y} → ${e.boule.x},${e.boule.y})`);
  const s = suspendue(G, e);
  if (s) d.push(`D2 eau suspendue au départ en ${s}`);
}
dire(!d.length, "D1-D2 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));
if (d.length) process.exit(1);

const t0 = Date.now(), sol = L.resoudre(N, null, 500000);
let ok = !!sol.suite;
if (ok) { let e = L.charger(N); for (const k of sol.suite) e = L.taper(N, e, k).e; ok = e.gagne; }
const nom = k => `${k + 1}·${G.vannes[k].type}`;
const compact = s => { const o = []; for (const k of s) { const d = o[o.length - 1]; if (d && d.k === k) d.n++; else o.push({ k, n: 1 }); } return o.map(d => `${nom(d.k)}×${d.n}`).join(", "); };
dire(ok, `S1 solution en ${sol.suite ? sol.suite.length : "∅"} tapes (${sol.etats} états, ${Date.now() - t0} ms)` + (sol.suite ? " : " + compact(sol.suite) : ""));
if (sol.suite) dire(sol.suite.length === N.par, `S2 par ${N.par} = meilleure solution ${sol.suite.length}`);
if (N.requises) G.vannes.forEach((v, k) => {
  const r = sansVanne(k);
  dire(r === null, `S3 sans la vanne ${nom(k)} : ` + (r === null ? "impossible" : `${r} tapes`));
});

const eau0 = L.charger(N).eau.reduce((a, b) => a + b, 0);
const viol = [];
let gagnees = 0;
for (let p = 0; p < PARTIES && viol.length < 4; p++) {
  const h = Hasard(GRAINE + p);
  let e = L.charger(N);
  for (let t = 0; t < TAPES && !e.gagne; t++) {
    const k = Math.floor(h() * G.vannes.length);
    const r = L.taper(N, e, k), r2 = L.taper(N, e, k);
    if (!r) continue;
    if (L.cle(r.e) !== L.cle(r2.e) || r.e.verse !== r2.e.verse) viol.push(`I3 partie ${GRAINE + p}, tape ${t} : deux résultats différents`);
    e = r.e;
    viol.push(...invariants(G, e, eau0, `partie ${GRAINE + p}, tape ${t} (${nom(k)})`));
    if (viol.length) break;
  }
  if (e.gagne) gagnees++;
}
dire(!viol.length, `I1-I4 invariants sur ${PARTIES} parties de ${TAPES} tapes` + (viol.length ? " :\n      " + viol.slice(0, 4).join("\n      ") : ""));
console.log(`    au hasard : ${Math.round(100 * gagnees / PARTIES)} % des parties sortent la boule`);
console.log(echecs ? `\n${echecs} échec(s).` : "\nTout est vert.");
process.exit(echecs ? 1 : 0);
