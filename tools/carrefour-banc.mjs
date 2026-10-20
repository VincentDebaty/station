#!/usr/bin/env node
// ------------------------------------------------------------------
// carrefour-banc — LE BANC D'ESSAI DU PROTOTYPE « LE CARREFOUR ».
//
//   node tools/carrefour-banc.mjs                  le niveau, 300 parties au hasard
//   node tools/carrefour-banc.mjs --graine=500     une autre batterie de parties au hasard
//   node tools/carrefour-banc.mjs --parties=1000 --detail
//
// La suite du Pontier (20 octobre 2026) : un carrefour, trois phases de feux
// (l'avenue, la rue, les piétons) qui tournent TOUTES SEULES, chacune pendant
// la durée que le joueur règle d'une seconde par geste ; trois flux
// (voitures, tram à l'horaire, piétons) ; un QUOTA de personnes à faire
// passer avant 18 h, et des étoiles en points (passés + humeur qui reste).
// Le moteur (bloc <script id="moteur"> de prototypes/prototype-carrefour.html)
// et le niveau (bloc JSON « niveaux ») sont extraits du fichier et joués sans
// navigateur — jamais une copie. Le banc REFUSE (code de sortie 1) au lieu
// d'avertir.
//
// Le geste du joueur est un RÉGLAGE : la durée de chaque vert. Le banc fait
// donc jouer des réglages. Le meilleur joueur du banc RÉAJUSTE à chaque vague
// (un réglage par vague, cherché vague par vague, deux passes) ; le « par »
// est son score, pas une preuve d'optimalité.
//
// LES DONNÉES
//   D1  les vagues se suivent de 0 à la durée, sans trou ; les trams sont
//       dans l'ordre et dans la partie ; deux voies par axe ; le cycle de
//       départ est dans ses bornes ; quota < deux < trois
//
// L'IDÉE — ce qui fait du réglage un choix, pas une corvée :
//   E1  le meilleur réglage par vague atteint le quota, et son journal de
//       gestes se rejoue pas à pas jusqu'au même score
//   E2  son score est exactement le « par » écrit, et « trois » ne le dépasse pas
//   E3  le meilleur réglage POSÉ UNE FOIS (jamais retouché) n'a pas deux
//       étoiles : il faut jauger en cours de route, quand les vagues changent
//   E4  le cycle de départ, jamais touché, n'atteint pas le quota : il faut
//       régler
//   E5  un cycle trop COURT (2 s au plus par axe) et un cycle trop LONG
//       (13 s au moins par axe) n'ont pas deux étoiles, même réajustés
//   E6  sans jamais la phase des piétons, le meilleur réglage perd : les trois
//       phases comptent
//
// LES INVARIANTS — sur des parties aux gestes au hasard (régler, forcer), à
// chaque pas ; une violation est un bug du moteur :
//   I1  rien ne se perd : chaque voiture née est sur sa voie, sortie, ou a
//       fait demi-tour ; chaque piéton né attend, traverse, est passé ou
//       est parti
//   I2  jamais deux axes dans la zone de conflit ; jamais un piéton sur un
//       passage avec un véhicule dans la zone ; personne ne franchit sa
//       ligne d'arrêt sans le vert de son axe ; les durées restent dans
//       leurs bornes
//   I3  l'humeur ne remonte jamais ; le compte ne redescend jamais
//   I4  personne ne double : sur chaque voie, les voitures restent dans
//       l'ordre de naissance, à l'écart voulu
//   I5  les mêmes gestes aux mêmes pas donnent la même partie
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x === "--" + n || x.startsWith("--" + n + "=")); return a ? (a.split("=")[1] ?? true) : null; };
for (const a of args) if (!a.startsWith("--")) { console.error("argument inconnu : " + a); process.exit(2); }
const FICHIER = opt("fichier") || "prototypes/prototype-carrefour.html";
const PARTIES = +(opt("parties") || 300);
const GRAINE = +(opt("graine") || 1);
const DETAIL = !!opt("detail");

const html = readFileSync(FICHIER.startsWith("/") ? FICHIER : join(RACINE, FICHIER), "utf8");
function bloc(id) {
  const m = html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'));
  if (!m) { console.error("bloc introuvable dans " + FICHIER + " : " + id); process.exit(2); }
  return m[1];
}
const DONNEES = JSON.parse(bloc("niveaux"));
const ctx = createContext({ console });
runInContext(bloc("moteur") + "\n;globalThis.Carrefour = Carrefour;", ctx, { filename: "moteur.js" });
const E = ctx.Carrefour;

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
const sec = k => (k * E.PAS).toFixed(1).replace(".", ",") + " s";
const num = x => x.toFixed(1).replace(".", ",");
const fin = e => !e.fin ? "pas fini" : e.fin.fin === "colere" ? `perdu à ${sec(e.k)} (${e.passes} passés)` :
  `${e.fin.fin === "gagne" ? "quota atteint" : "quota manqué"}, ${e.passes} passés + humeur ${Math.round(e.humeur)} = ${E.points(e)} points, ${E.etoiles(DONNEES.niveaux[0], e)} étoile(s)`;
const pertes = e => `${e.renonces.reduce((a, b) => a + b, 0)} demi-tours, ${e.renoncesP} piétons partis, tram −${num(e.perte.tram)} ; ${e.changements} changements`;

function donnees(N) {
  const v = [];
  N.vagues.forEach((w, k) => { if (w.de !== (k ? N.vagues[k - 1].a : 0)) v.push(`vague ${k} : commence à ${w.de}`); });
  if (N.vagues[N.vagues.length - 1].a < N.duree) v.push(`les vagues s'arrêtent à ${N.vagues[N.vagues.length - 1].a} s, avant la fin`);
  N.trams.forEach((h, k) => {
    if (k && h.heure < N.trams[k - 1].heure) v.push(`trams hors d'ordre (${k})`);
    if (h.heure >= N.duree) v.push(`tram ${k} après la fin`);
  });
  for (const axe of [0, 1]) if (N.voies.filter(x => x.axe === axe).length !== 2) v.push(`axe ${axe} : pas deux voies`);
  N.cycle.depart.forEach((d, p) => { if (d < N.cycle.min[p] || d > N.cycle.max[p]) v.push(`cycle de départ hors bornes (phase ${p})`); });
  if (!(N.quota < N.etoiles.deux && N.etoiles.deux < N.etoiles.trois)) v.push(`étoiles mal ordonnées : ${N.quota} / ${N.etoiles.deux} / ${N.etoiles.trois}`);
  return v;
}

// --- Les joueurs : un réglage par vague -------------------------------------------
// Un plan est une liste de réglages [avenue, rue, piétons], un par vague. Au
// début de chaque vague, le joueur ramène les durées à son réglage, d'une
// seconde par geste (tous les gestes au même pas : il tape vite).
const HORIZON = N => E.pasDe(N.duree) + 1;
function gestesVers(N, e, cible) {
  const g = [];
  for (let p = 0; p < 3; p++) {
    const d = cible[p] - e.cycle[p];
    for (let i = 0; i < Math.abs(d); i++) g.push((d > 0 ? "plus" : "moins") + p);
  }
  return g;
}
function jouerPlan(N, plan) {
  const e = E.charger(N), journal = [], lim = HORIZON(N);
  let vague = -1;
  while (!e.fin && e.k < lim) {
    const tt = E.heure(e), v = N.vagues.findIndex(w => tt >= w.de && tt < w.a);
    if (v !== vague && v >= 0) { vague = v; for (const g of gestesVers(N, e, plan[v])) if (!E.geste(N, e, g)) journal.push({ k: e.k, g }); }
    E.pas(N, e);
  }
  return { e, journal };
}
function rejouer(N, journal) {
  const e = E.charger(N), lim = HORIZON(N);
  let i = 0;
  while (!e.fin && e.k < lim) {
    while (i < journal.length && journal[i].k === e.k) { const r = E.geste(N, e, journal[i].g); if (r) return { e, refus: journal[i], r }; i++; }
    E.pas(N, e);
  }
  return { e };
}
// le score : les points d'une partie réussie ; une partie ratée ou perdue passe derrière
const score = e => e.fin && e.fin.fin === "gagne" ? E.points(e) : e.fin && e.fin.fin === "rate" ? -500 + e.passes / 1000 : -1000 + e.passes / 1000;
const REGLAGES = (N, filtre = () => true) => {
  const l = [];
  for (const a of [2, 3, 4, 5, 6, 8, 10, 13, 17]) for (const r of [2, 3, 4, 5, 6, 8, 10, 13]) for (const p of [0, 1, 2, 3, 5])
    if (a >= N.cycle.min[0] && r >= N.cycle.min[1] && p >= N.cycle.min[2] && filtre([a, r, p])) l.push([a, r, p]);
  return l;
};
// la recherche vague par vague : chaque vague prend le réglage qui donne le
// meilleur score de toute la partie, les autres vagues fixées
function meilleurPlan(N, reglages, passes = 2) {
  const n = N.vagues.length;
  let plan = null, m = null, s = -Infinity;
  for (const r of reglages) { const p = Array.from({ length: n }, () => r), x = jouerPlan(N, p), sx = score(x.e); if (sx > s) { plan = p; m = x; s = sx; } }
  for (let passe = 0; passe < passes; passe++)
    for (let v = 0; v < n; v++)
      for (const r of reglages) {
        const p = plan.slice(); p[v] = r;
        const x = jouerPlan(N, p), sx = score(x.e);
        if (sx > s + 1e-9) { plan = p; m = x; s = sx; }
      }
  return { plan, s, ...m };
}
function meilleurFixe(N, reglages) {
  let m = null;
  for (const r of reglages) { const x = jouerPlan(N, N.vagues.map(() => r)), sx = score(x.e); if (!m || sx > m.s) m = { s: sx, plan: [r], ...x }; }
  return m;
}
const montrer = (N, plan) => plan.map((r, v) => `${N.vagues[v].nom || "calme"} ${r[0]}/${r[1]}/${r[2]}`).join(", ");

// --- Les invariants -------------------------------------------------------------
const GESTES = ["plus0", "moins0", "plus1", "moins1", "plus2", "moins2", "feu0", "feu1", "feu2"];
function partie(N, hasard) {
  const c = E.C(N), v = [], e = E.charger(N), journal = [], lim = HORIZON(N);
  let humeur = e.humeur, passes = 0;
  const sortis = N.voies.map(() => 0);
  while (!e.fin && e.k < lim && !v.length) {
    if (hasard() < 0.03) { const g = GESTES[Math.floor(hasard() * GESTES.length)]; if (!E.geste(N, e, g)) journal.push({ k: e.k, g }); }
    const avant = N.voies.map((x, a) => new Map(e.voies[a].map(y => [y.id, y.q])));
    const avantT = e.trams.map(tr => tr.q), vertAvant = [0, 1, 2].map(p => E.vert(e, p));
    E.pas(N, e);
    const t = "à " + sec(e.k);
    // I1
    N.voies.forEach((x, a) => { for (const id of avant[a].keys()) if (!e.voies[a].some(y => y.id === id) && !e.partis.some(p => p.voie === a && p.id === id)) sortis[a]++; });
    N.voies.forEach((x, a) => { if (e.voies[a].length + sortis[a] + e.renonces[a] !== e.nes[a]) v.push(`I1 ${t} : voie ${x.id}, ${e.nes[a]} nées, ${e.voies[a].length} sur la voie, ${sortis[a]} sorties, ${e.renonces[a]} demi-tours`); });
    const att = e.attente.reduce((s, x) => s + x.length, 0);
    if (att + e.traversent.length + e.finisP + e.renoncesP !== e.nesP) v.push(`I1 ${t} : piétons ${e.nesP} nés, ${att} + ${e.traversent.length} + ${e.finisP} + ${e.renoncesP}`);
    // I2
    const z0 = E.zoneOccupee(N, e, 0), z1 = E.zoneOccupee(N, e, 1);
    if (z0 && z1) v.push(`I2 ${t} : les deux axes dans la zone`);
    if ((z0 || z1) && e.traversent.length) v.push(`I2 ${t} : des piétons traversent avec un véhicule dans la zone`);
    N.voies.forEach((x, a) => {
      for (const y of e.voies[a]) { const q0 = avant[a].get(y.id); if (q0 != null && q0 <= x.approche && y.q > x.approche && !vertAvant[x.axe] && !E.vert(e, x.axe)) v.push(`I2 ${t} : une voiture de ${x.id} passe au rouge`); }
    });
    N.trams.forEach((h, i) => { const x = N.voies[E.voieTram(N, h.sens)]; if (avantT[i] <= x.approche && e.trams[i].q > x.approche && !E.vert(e, 1)) v.push(`I2 ${t} : le tram ${i} passe au rouge`); });
    e.cycle.forEach((d, p) => { if (d < N.cycle.min[p] || d > N.cycle.max[p]) v.push(`I2 ${t} : la durée ${p} sort de ses bornes (${d})`); });
    // I3
    if (e.humeur > humeur + 1e-9) v.push(`I3 ${t} : l'humeur remonte`);
    if (e.passes < passes) v.push(`I3 ${t} : le compte redescend`);
    humeur = e.humeur; passes = e.passes;
    // I4
    N.voies.forEach((x, a) => { const f = e.voies[a]; for (let j = 1; j < f.length; j++) if (f[j].id <= f[j - 1].id || f[j].q > f[j - 1].q - c.GAP) v.push(`I4 ${t} : voie ${x.id}, ${f[j].id} contre ${f[j - 1].id}`); });
  }
  const bis = rejouer(N, journal).e;
  if (!v.length && JSON.stringify(bis) !== JSON.stringify(e)) v.push(`I5 la partie rejouée diffère`);
  return { v, e };
}

// --- Le banc ---------------------------------------------------------------------
console.log(`Le carrefour — ${DONNEES.niveaux.length} niveau(x), ${PARTIES} parties au hasard chacun, graines ${GRAINE}…${GRAINE + PARTIES - 1}`);
for (const N of DONNEES.niveaux) {
  const c = E.C(N), voitures = c.arr.reduce((s, x) => s + x.length, 0);
  console.log(`\n${N.id} ${N.titre} (${voitures} voitures, ${c.arrP.length} piétons, ${N.trams.length} trams ; quota ${N.quota}, étoiles ${N.etoiles.deux} et ${N.etoiles.trois}, par ${N.par})`);
  const d = donnees(N);
  dire(!d.length, "D1 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));

  const t0 = Date.now(), R = REGLAGES(N);
  const m = meilleurPlan(N, R);
  const b = rejouer(N, m.journal);
  const ok = m.e.fin && m.e.fin.fin === "gagne" && !b.refus && b.e.fin && E.points(b.e) === E.points(m.e);
  dire(ok, `E1 le meilleur réglage par vague (${R.length} réglages, ${Date.now() - t0} ms) : ${fin(m.e)}, ${m.journal.length} gestes\n      ${montrer(N, m.plan)}\n      ${pertes(m.e)}`);
  dire(E.points(m.e) === N.par && N.etoiles.trois <= N.par, `E2 par ${N.par} = meilleurs points ${E.points(m.e)} ; trois étoiles à ${N.etoiles.trois}`);

  const f = meilleurFixe(N, R);
  dire(f.s < N.etoiles.deux, `E3 le meilleur réglage posé une fois (${f.plan[0].join("/")}) : ${fin(f.e)} (${pertes(f.e)})`);
  const dep = jouerPlan(N, N.vagues.map(() => N.cycle.depart)).e;
  dire(!(dep.fin && dep.fin.fin === "gagne"), `E4 le cycle de départ (${N.cycle.depart.join("/")}), jamais touché : ${fin(dep)}`);
  const court = meilleurPlan(N, R.filter(r => r[0] <= 2 && r[1] <= 2), 1);
  const long = meilleurPlan(N, R.filter(r => r[0] >= 13 && r[1] >= 13), 1);
  dire(court.s < N.etoiles.deux && long.s < N.etoiles.deux, `E5 cycles trop courts, au mieux : ${fin(court.e)} ; trop longs : ${fin(long.e)}`);
  const sp = meilleurPlan(N, R.filter(r => r[2] === 0), 1);
  dire(sp.e.fin && sp.e.fin.fin === "colere", `E6 sans la phase des piétons, au mieux : ${fin(sp.e)}`);
  if (DETAIL) console.log(`    détail : arrivées ${voitures} voitures + ${c.arrP.length} piétons + ${N.trams.length * N.compte.tram} en tram ; posé une fois ${num(f.s)}, par vague ${num(m.s)}`);

  const viol = [], stats = {};
  for (let k = 0; k < PARTIES && viol.length < 4; k++) {
    const r = partie(N, Hasard(GRAINE + k));
    viol.push(...r.v);
    const f = r.e.fin ? r.e.fin.fin : "temps";
    stats[f] = (stats[f] || 0) + 1;
  }
  dire(!viol.length, `I1-I5 invariants sur ${PARTIES} parties` + (viol.length ? " :\n      " + viol.slice(0, 4).join("\n      ") : ""));
  console.log("    au hasard : " + Object.entries(stats).map(([f, n]) => `${f} ${Math.round(100 * n / PARTIES)} %`).join(", "));
}
console.log(echecs ? `\n${echecs} échec(s).` : "\nTout est vert.");
process.exit(echecs ? 1 : 0);
