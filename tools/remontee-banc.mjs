#!/usr/bin/env node
// ------------------------------------------------------------------
// remontee-banc — LE BANC D'ESSAI DU PROTOTYPE « LA REMONTÉE ».
//
//   node tools/remontee-banc.mjs                 tous les niveaux, 300 parties au hasard
//   node tools/remontee-banc.mjs --graine=500    une autre batterie de parties au hasard
//   node tools/remontee-banc.mjs --niveau=3
//
// L'idée de Vincent (20 octobre 2026) : des balles de couleur flottent dans
// un réseau de tuyaux ; des vannes font monter l'eau, des purges la
// vident ; chaque balle doit entrer dans le trou de sa couleur, qui se
// ferme derrière elle. Le moteur (bloc <script id="moteur"> de
// prototypes/prototype-remontee.html) et les niveaux (bloc JSON
// « niveaux ») sont extraits du fichier et joués sans navigateur — jamais
// une copie. Le banc REFUSE (code de sortie 1) au lieu d'avertir.
//
// Le banc RÉSOUT chaque niveau exhaustivement : toutes les suites de
// gouttes, une goutte à la fois, de n'importe quelle vanne. Un geste, c'est
// ouvrir une vanne : verser encore de la même vanne ne coûte rien.
//
// LES DONNÉES
//   D1  la grille est rectangulaire ; deux cases voisines ne se touchent que
//       par des bouts qui se font face (sinon le tuyau est mal dessiné) ;
//       trous, balles, eau et vannes sont sur des tuyaux ; un trou est au
//       plafond d'une case fermée en haut ; chaque balle a un trou de sa
//       couleur, et réciproquement ; aucune balle ne commence dans un trou
//
// L'IDÉE
//   E1  le niveau a une solution, et le « par » écrit est le moins de gestes
//   E2  la solution se rejoue goutte à goutte jusqu'au gain
//   E3  remplir « à fond », vanne après vanne, dans un ordre quelconque, ne
//       gagne pas à tous les coups : l'ordre compte
//   E4  dans un niveau à purges, aucun remplissage « à fond » sans purge ne
//       gagne : la purge sert
//
// LES INVARIANTS — sur des parties aux gouttes au hasard ; une violation
// est un bug du moteur :
//   I1  deux balles ne partagent jamais une case ; une balle « dans son
//       trou » est sous un trou fermé de sa couleur
//   I2  une goutte de vanne ne fait jamais descendre une balle ; une goutte
//       de purge ne la fait jamais monter
//   I3  une goutte de vanne ajoute de l'eau, une de purge en retire, sans
//       jamais toucher aux autres cases
//   I4  les mêmes gouttes donnent la même partie
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x === "--" + n || x.startsWith("--" + n + "=")); return a ? (a.split("=")[1] ?? true) : null; };
for (const a of args) if (!a.startsWith("--")) { console.error("argument inconnu : " + a); process.exit(2); }
const FICHIER = opt("fichier") || "prototypes/prototype-remontee.html";
const PARTIES = +(opt("parties") || 300);
const GRAINE = +(opt("graine") || 1);
const SEUL = opt("niveau");

const html = readFileSync(FICHIER.startsWith("/") ? FICHIER : join(RACINE, FICHIER), "utf8");
function bloc(id) {
  const m = html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'));
  if (!m) { console.error("bloc introuvable dans " + FICHIER + " : " + id); process.exit(2); }
  return m[1];
}
const DONNEES = JSON.parse(bloc("niveaux"));
const ctx = createContext({});
runInContext(bloc("moteur") + "\n;globalThis.Flotte = Flotte;", ctx, { filename: "moteur.js" });
const F = ctx.Flotte;

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

function donnees(N) {
  const v = [], g = F.G(N), lignes = N.grille.map(l => [...l].length);
  if (new Set(lignes).size !== 1) v.push(`grille non rectangulaire (${lignes.join(", ")})`);
  const D = { N: [-1, 0], S: [1, 0], E: [0, 1], W: [0, -1] }, OPP = { N: "S", S: "N", E: "W", W: "E" };
  for (let r = 0; r < g.R; r++) for (let c = 0; c < g.C; c++) for (const d of g.ouv[g.at(r, c)]) {
    const rr = r + D[d][0], cc = c + D[d][1];
    if (rr < 0 || rr >= g.R || cc < 0 || cc >= g.C) { v.push(`(${r},${c}) ouvre vers ${d}, hors de la grille`); continue; }
    if (!g.ouv[g.at(rr, cc)].includes(OPP[d])) v.push(`(${r},${c}) ouvre vers ${d}, mais (${rr},${cc}) ne lui répond pas`);
  }
  const surTuyau = (r, c, quoi) => { if (!g.ouv[g.at(r, c)]) v.push(`${quoi} (${r},${c}) hors des tuyaux`); };
  N.trous.forEach(t => { surTuyau(t.r, t.c, "trou"); if (g.ouv[g.at(t.r, t.c)].includes("N")) v.push(`trou (${t.r},${t.c}) sous une case ouverte en haut`); });
  N.balles.forEach(b => surTuyau(b.r, b.c, "balle"));
  (N.eau || []).forEach(([r, c]) => surTuyau(r, c, "eau"));
  N.vannes.forEach(x => surTuyau(x.r, x.c, "vanne"));
  const compte = l => l.map(x => x.couleur).sort().join();
  if (compte(N.balles) !== compte(N.trous)) v.push(`balles ${compte(N.balles)} contre trous ${compte(N.trous)}`);
  const e = F.charger(N);
  if (e.fin) v.push(`le niveau est fini avant de commencer (${e.fin.fin})`);
  return v;
}

const cle = e => e.eau.join("") + "|" + e.balles.map(b => b.i + b.etat).join(",") + "|" +
  e.balles.map((b, k) => k).filter(k => e.balles[k].etat === "tuyau").sort((a, c) => e.balles[a].depuis - e.balles[c].depuis || a - c).join("") + "|" + e.trous.join("") + e.events.join("");
// 0-1 : une goutte de la même vanne ne coûte rien, une autre vanne coûte un geste
function resoudre(N) {
  const dq = [[F.charger(N), -1, 0, []]], vu = new Map();
  let best = null, n = 0;
  while (dq.length) {
    const [e, der, cout, chemin] = dq.shift();
    const k = cle(e) + "#" + der;
    if (vu.has(k) && vu.get(k) <= cout) continue;
    vu.set(k, cout);
    if (++n > 2000000) return { best, n, coupe: true };
    if (best && cout >= best.cout) continue;
    for (let v = 0; v < N.vannes.length; v++) {
      const f = F.copie(e);
      if (F.dose(N, f, v)) continue;
      const c = cout + (v === der ? 0 : 1), ch = chemin.concat(v);
      if (f.fin && f.fin.fin === "gagne") { if (!best || c < best.cout) best = { cout: c, chemin: ch }; continue; }
      if (f.fin) continue;
      if (v === der) dq.unshift([f, v, c, ch]); else dq.push([f, v, c, ch]);
    }
  }
  return { best, n };
}
const perms = a => a.length <= 1 ? [a] : a.flatMap((x, i) => perms(a.filter((_, j) => j !== i)).map(p => [x, ...p]));
function aFond(N, ordre) {
  const e = F.charger(N);
  for (const v of ordre) { while (!e.fin && !F.dose(N, e, v)); if (e.fin) break; }
  return e.fin ? e.fin.fin : "rien";
}
const suite = ch => ch.reduce((a, v, i) => (i && ch[i - 1] === v ? a[a.length - 1][1]++ : a.push([v, 1]), a), []);

function partie(N, hasard) {
  const g = F.G(N), v = [], e = F.charger(N), journal = [];
  for (let pas = 0; pas < 400 && !e.fin && !v.length; pas++) {
    const w = Math.floor(hasard() * N.vannes.length), avant = F.copie(e);
    if (F.dose(N, e, w)) continue;
    journal.push(w);
    const t = `goutte ${pas} (vanne ${w + 1})`;
    const cases = e.balles.filter(b => b.etat === "tuyau" || b.etat === "coincee").map(b => b.i);
    if (new Set(cases).size !== cases.length) v.push(`I1 ${t} : deux balles dans la même case`);
    e.balles.forEach((b, k) => { if (b.etat === "trou" && (!e.trous[b.trou] || N.trous[b.trou].couleur !== N.balles[k].couleur)) v.push(`I1 ${t} : la balle ${k} dans un trou qui n'est pas le sien`); });
    e.balles.forEach((b, k) => {
      const a = avant.balles[k];
      if (b.etat !== "tuyau" || a.etat !== "tuyau") return;
      if (!N.vannes[w].purge && g.ligne(b.i) > g.ligne(a.i)) v.push(`I2 ${t} : la balle ${k} descend`);
      if (N.vannes[w].purge && g.ligne(b.i) < g.ligne(a.i)) v.push(`I2 ${t} : la balle ${k} monte pendant une purge`);
    });
    const plus = e.eau.filter((x, i) => x && !avant.eau[i]).length, moins = e.eau.filter((x, i) => !x && avant.eau[i]).length;
    if (N.vannes[w].purge ? plus || !moins : moins || !plus) v.push(`I3 ${t} : ${plus} cases remplies, ${moins} vidées`);
  }
  const bis = F.charger(N);
  for (const w of journal) F.dose(N, bis, w);
  if (!v.length && JSON.stringify(bis) !== JSON.stringify(e)) v.push("I4 la partie rejouée diffère");
  return { v, e };
}

const niveaux = DONNEES.niveaux.filter(n => !SEUL || n.id === SEUL);
if (!niveaux.length) { console.error("niveau inconnu : " + SEUL); process.exit(2); }
console.log(`La remontée — ${niveaux.length} niveau(x), ${PARTIES} parties au hasard chacun, graines ${GRAINE}…${GRAINE + PARTIES - 1}`);
for (const N of niveaux) {
  const purges = N.vannes.some(x => x.purge);
  console.log(`\n${N.id} ${N.titre} (${N.balles.length} balles, ${N.vannes.filter(x => !x.purge).length} vannes, ${N.vannes.filter(x => x.purge).length} purges, par ${N.par})`);
  const d = donnees(N);
  dire(!d.length, "D1 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));
  if (d.length) continue;
  const t0 = Date.now(), r = resoudre(N);
  dire(r.best && !r.coupe && r.best.cout === N.par, `E1 ${r.best ? "meilleure solution en " + r.best.cout + " geste(s) : " + suite(r.best.chemin).map(([v, n]) => (N.vannes[v].purge ? "purge " : "vanne ") + (v + 1) + " ×" + n).join(", ") : "AUCUNE SOLUTION"} (${r.n} états, ${Date.now() - t0} ms${r.coupe ? ", COUPÉ" : ""})`);
  if (r.best) {
    const e = F.charger(N);
    for (const v of r.best.chemin) F.dose(N, e, v);
    dire(e.fin && e.fin.fin === "gagne", `E2 la solution rejouée : ${e.fin ? e.fin.fin : "pas finie"}`);
  }
  const ordres = perms(N.vannes.map((_, i) => i).filter(i => !N.vannes[i].purge)), fins = ordres.map(o => aFond(N, o));
  const gagnes = fins.filter(f => f === "gagne").length;
  const detail = ordres.map((o, k) => o.map(v => v + 1).join("") + " " + fins[k]).join(", ");
  dire(gagnes < ordres.length, `E3 « à fond » sans purge : ${gagnes}/${ordres.length} gagnent (${detail})`);
  if (purges) dire(gagnes === 0, `E4 la purge sert : aucun remplissage sans purge ne gagne`);
  const viol = [], stats = {};
  for (let k = 0; k < PARTIES && viol.length < 4; k++) {
    const p = partie(N, Hasard(GRAINE + k));
    viol.push(...p.v);
    const f = p.e.fin ? p.e.fin.fin : "en cours";
    stats[f] = (stats[f] || 0) + 1;
  }
  dire(!viol.length, `I1-I4 invariants sur ${PARTIES} parties` + (viol.length ? " :\n      " + viol.slice(0, 4).join("\n      ") : ""));
  console.log("    au hasard : " + Object.entries(stats).map(([f, n]) => `${f} ${Math.round(100 * n / PARTIES)} %`).join(", "));
}
console.log(echecs ? `\n${echecs} échec(s).` : "\nTout est vert.");
process.exit(echecs ? 1 : 0);
