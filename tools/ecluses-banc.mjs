#!/usr/bin/env node
// ------------------------------------------------------------------
// ecluses-banc — LE BANC D'ESSAI DU PROTOTYPE « ÉCLUSES ».
//
//   node tools/ecluses-banc.mjs                   tous les niveaux, 300 parties au hasard chacun
//   node tools/ecluses-banc.mjs --graine=500      une autre batterie de parties au hasard
//   node tools/ecluses-banc.mjs --niveau=1-3 --parties=2000
//
// Le moteur (prototypes/prototype-ecluses.html, bloc <script id="moteur">)
// et les niveaux (bloc JSON « niveaux ») sont extraits du fichier et joués
// sans navigateur — jamais une copie de l'un ou de l'autre. Le banc REFUSE
// (code de sortie 1) au lieu d'avertir.
//
// LES DONNÉES — un niveau mal écrit, avant même de le jouer :
//   D1  chaque seuil est au-dessus des deux fonds voisins, chaque crête au
//       moins au seuil, chaque digue a un « min » entre les deux
//   D2  au départ, l'eau tient derrière ses murs et ses portes, et rien ne
//       bouge au chargement : le niveau commence au repos
//
// LA SOLUTION — ce qui fait d'un niveau un puzzle :
//   S1  le solveur trouve une solution, et elle se rejoue jusqu'au gain
//   S2  sa longueur est exactement le « par » écrit dans le niveau : les
//       étoiles se comptent contre la vraie meilleure solution
//   S3  sans les coups « requis », le niveau devient impossible ou plus long :
//       la mécanique du chapitre sert pour de vrai
//
// LES INVARIANTS — sur des parties jouées au hasard, une violation est un
// bug du moteur, pas un réglage :
//   I1  l'eau se conserve : volume des bassins = départ + entrées − sorties
//       (seuls le fleuve et la mer font entrer ou sortir de l'eau)
//   I2  aucun niveau sous son fond, aucun nombre qui n'en est pas un
//   I3  aucun sas avec deux bateaux, aucun bateau hors de la rangée ni sauté
//       de plus d'un bassin par tour
//   I4  le même coup sur le même état donne le même état
//   I5  une impasse annoncée par la page (fouille à niveaux arrondis au
//       centième, comme dans la vue) n'est jamais contredite par le solveur
//       exact : la page ne dit pas « plus de solution » à tort
//
// En information (pas un refus) : la part des parties au hasard qui se
// terminent en impasse — un repère de la sévérité de chaque niveau.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const FICHIER = "prototypes/prototype-ecluses.html";
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
for (const a of args) if (!a.startsWith("--")) { console.error("argument inconnu : " + a); process.exit(2); }
const PARTIES = +(opt("parties") || 300);
const GRAINE = +(opt("graine") || 1);
const SEUL = opt("niveau");

const html = readFileSync(join(RACINE, FICHIER), "utf8");
function bloc(id) {
  const m = html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'));
  if (!m) { console.error("bloc introuvable dans " + FICHIER + " : " + id); process.exit(2); }
  return m[1];
}
const DONNEES = JSON.parse(bloc("niveaux"));
const ctx = createContext({ console });
runInContext(bloc("moteur") + "\n;globalThis.Ecluses = Ecluses;", ctx, { filename: "moteur.js" });
const E = ctx.Ecluses;

function Hasard(graine) {
  let a = (graine >>> 0) || 1;
  return () => {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const nom = a => a.type === "porte" ? "porte " + a.i : a.type === "creuser" ? "pelle " + a.i : a.type;
let echecs = 0;
const dire = (ok, texte) => { console.log((ok ? "  ✓ " : "  ✗ ") + texte); if (!ok) echecs++; };

function donnees(N) {
  const v = [];
  N.liaisons.forEach((l, i) => {
    const fonds = Math.max(N.bassins[i].fond, N.bassins[i + 1].fond);
    if (l.type === "porte" && (l.seuil < fonds - 1e-9 || l.crete < l.seuil)) v.push(`porte ${i} : seuil ${l.seuil}, crête ${l.crete}, fonds ${fonds}`);
    if (l.type === "digue" && (l.min < fonds - 1e-9 || l.min > l.crete)) v.push(`digue ${i} : min ${l.min}, crête ${l.crete}, fonds ${fonds}`);
    if (l.type === "mur" && l.crete < fonds - 1e-9) v.push(`mur ${i} : crête ${l.crete} sous les fonds ${fonds}`);
  });
  N.bateaux.forEach((b, k) => { if (!(b.de in N.bassins) || !(b.vers in N.bassins)) v.push(`bateau ${k} hors de la rangée`); });
  return v;
}
function auRepos(N) {
  const v = [], e = E.charger(N);
  N.bassins.forEach((b, i) => {
    const h = b.niveau != null ? b.niveau : b.fond;
    if (N.mode !== "chantier" && Math.abs(e.niv[i] - h) > 1e-6) v.push(`bassin ${i} bouge au chargement (${h} → ${e.niv[i]})`);
  });
  if (N.mode === "chantier") {
    // à sec, rien ne coule : l'eau doit tenir sous les crêtes de départ
    N.liaisons.forEach((l, i) => {
      if (l.type === "libre") return;
      const s = E.seuil(N, e, i);
      if (Math.max(e.niv[i], e.niv[i + 1]) > s + 1e-9 && Math.abs(e.niv[i] - e.niv[i + 1]) > 1e-9) v.push(`liaison ${i} : l'eau passe déjà par-dessus (${s})`);
    });
  }
  N.bateaux.forEach((b, k) => { if (e.bateaux[k] !== b.de) v.push(`bateau ${k} part tout seul au chargement`); });
  return v;
}
const IMPASSE = { limite: 25000, quantum: 0.01 };   // les réglages de la vue (verifierImpasse)
const CONTROLES = 12;                               // impasses recoupées par niveau, au solveur exact
function partie(N, hasard, stats) {
  const v = [];
  let e = E.charger(N);
  const depart = E.eauTotale(N, e) - e.entree + e.sortie;
  for (let coup = 0; coup < 40; coup++) {
    const A = E.actions(N, e);
    if (!A.length) break;
    const a = A[Math.floor(hasard() * A.length)];
    const r = E.jouer(N, e, a), r2 = E.jouer(N, e, a);
    if (E.cle(r.etat) !== E.cle(r2.etat)) v.push(`I4 coup ${coup} (${nom(a)}) : deux résultats différents`);
    const avant = e.bateaux;
    e = r.etat;
    const total = E.eauTotale(N, e), attendu = depart + e.entree - e.sortie;
    if (Math.abs(total - attendu) > 1e-3) v.push(`I1 coup ${coup} (${nom(a)}) : ${total.toFixed(4)} d'eau, attendu ${attendu.toFixed(4)}`);
    N.bassins.forEach((b, i) => {
      if (!Number.isFinite(e.niv[i])) v.push(`I2 coup ${coup} : bassin ${i} à ${e.niv[i]}`);
      else if (e.niv[i] < b.fond - 1e-6) v.push(`I2 coup ${coup} : bassin ${i} sous son fond (${e.niv[i]} < ${b.fond})`);
    });
    N.bassins.forEach((b, i) => {
      const n = e.bateaux.filter(p => p === i).length;
      if (n > E.capacite(N, i)) v.push(`I3 coup ${coup} : ${n} bateaux dans le bassin ${i}`);
    });
    e.bateaux.forEach((p, k) => {
      if (!(p in N.bassins)) v.push(`I3 coup ${coup} : bateau ${k} hors de la rangée`);
      const pas = r.dep.filter(d => d.k === k);
      if (pas.some((d, j) => Math.abs(d.vers - d.de) !== 1 || (j > 0 && pas[j - 1].tour === d.tour))) v.push(`I3 coup ${coup} : bateau ${k} saute des bassins`);
      if (Math.abs(p - avant[k]) !== pas.length && pas.length) v.push(`I3 coup ${coup} : bateau ${k} arrive ailleurs que ses pas`);
    });
    if (v.length) break;
    const fin = E.verdict(N, e);
    if (fin) { stats[fin.fin] = (stats[fin.fin] || 0) + 1; return v; }
  }
  // sans fin : impasse ou non, au sens de la page ?
  if (N.mode === "pas") {
    const r = E.resoudre(N, e, IMPASSE.limite, null, { quantum: IMPASSE.quantum });
    if (!r.chemin && r.epuise) {
      stats.impasse = (stats.impasse || 0) + 1;
      if ((stats.recoupees || 0) < CONTROLES) {
        stats.recoupees = (stats.recoupees || 0) + 1;
        const exact = E.resoudre(N, e, 200000);
        if (exact.chemin) v.push(`I5 impasse annoncée, mais le solveur exact gagne en ${exact.chemin.length} coups`);
      }
    } else stats.ouverte = (stats.ouverte || 0) + 1;
  }
  return v;
}

const niveaux = DONNEES.niveaux.filter(n => !SEUL || n.id === SEUL);
if (!niveaux.length) { console.error("niveau inconnu : " + SEUL); process.exit(2); }
console.log(`Écluses — ${niveaux.length} niveau(x), ${PARTIES} parties au hasard chacun, graines ${GRAINE}…${GRAINE + PARTIES - 1}`);
for (const N of niveaux) {
  console.log(`\n${N.id} ${N.titre} (${N.mode}, par ${N.par})`);
  const d = donnees(N).concat(auRepos(N));
  dire(!d.length, "D1-D2 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));

  const t0 = Date.now(), r = E.resoudre(N, null, 1500000);
  let ok = !!r.chemin;
  if (ok) {
    let e = E.charger(N);
    for (const a of r.chemin) e = E.jouer(N, e, a).etat;
    ok = (E.verdict(N, e) || {}).fin === "gagne";
  }
  dire(ok, `S1 solution en ${r.chemin ? r.chemin.length : "∅"} coups (${r.etats} états, ${Date.now() - t0} ms)` + (r.chemin ? " : " + r.chemin.map(nom).join(", ") : ""));
  if (r.chemin) dire(r.chemin.length === N.par, `S2 par ${N.par} = meilleure solution ${r.chemin.length}`);
  for (const q of N.requis || []) {
    const sans = E.resoudre(N, null, 1500000, [q]);
    const plusLong = !sans.chemin || sans.chemin.length > N.par;
    dire(plusLong && (sans.chemin || sans.epuise), `S3 sans « ${q} » : ` + (sans.chemin ? `${sans.chemin.length} coups` : sans.epuise ? "impossible" : `rien trouvé en ${sans.etats} états, sans preuve`));
  }

  const stats = {}, viol = [];
  for (let p = 0; p < PARTIES && viol.length < 4; p++) viol.push(...partie(N, Hasard(GRAINE + p), stats));
  dire(!viol.length, "I1-I5 invariants sur " + PARTIES + " parties" + (viol.length ? " :\n      " + viol.slice(0, 4).join("\n      ") : ""));
  const pc = n => Math.round(100 * (n || 0) / PARTIES) + " %";
  console.log(`    au hasard : gagnées ${pc(stats.gagne)}, village inondé ${pc(stats.perdu)}` +
    (N.mode === "chantier" ? `, chantier raté ${pc(stats.rate)}` : `, impasse ${pc(stats.impasse)}, encore ouvertes ${pc(stats.ouverte)}`));
}
console.log(echecs ? `\n${echecs} échec(s).` : "\nTout est vert.");
process.exit(echecs ? 1 : 0);
