#!/usr/bin/env node
// ------------------------------------------------------------------
// caneton-banc — LE BANC D'ESSAI DU PROTOTYPE « CANETON ».
//
//   node tools/caneton-banc.mjs               tous les niveaux
//   node tools/caneton-banc.mjs --niveau=2    un seul
//
// Le moteur (prototypes/prototype-caneton.html, bloc <script id="moteur">)
// et les niveaux (bloc JSON « niveaux ») sont extraits du fichier et joués
// sans navigateur — jamais une copie de l'un ou de l'autre. Le banc REFUSE
// (code de sortie 1) au lieu d'avertir.
//
// Les vannes ne font que s'ouvrir : un niveau à n vannes n'a que n! parties
// complètes. Le banc les joue TOUTES, pas au hasard.
//
// LES DONNÉES — un niveau mal écrit, avant même de le jouer :
//   D1  les passages tiennent dans leurs murs : une porte est dans un mur de
//       son bassin, son seuil et son linteau entre le fond et le haut ; une
//       trappe est dans le fond, au-dessus d'un bassin qui la reçoit ; une
//       cascade tombe DANS le bassin d'arrivée ; la rivière est sous chaque
//       seuil de sortie ; l'eau et le caneton de départ sont dans leur bassin
//   D2  au chargement, avec les seuls passages toujours ouverts, rien ne
//       coule : le niveau commence au repos
//
// LA SOLUTION :
//   S1  le solveur trouve une solution, et elle se rejoue jusqu'au gain
//   S2  sa longueur est exactement le « par » écrit dans le niveau
//   S3  l'intention écrite est tenue : « ordres: tous » = chaque ordre
//       complet des gestes gagne (le niveau pardonne) ; « ordres: certains »
//       = au moins un ordre gagne et au moins un perd (l'ordre compte)
//
// LES INVARIANTS — à chaque pas d'eau de chaque partie :
//   I1  l'eau se conserve : bassins + rivière = départ
//   I2  aucun bassin ne déborde ni ne passe sous son fond, aucun NaN
//   I3  le même geste sur le même état donne le même état
//   I4  l'eau se pose : chaque geste finit au repos en un nombre fini de pas
//
// En information : les ordres gagnants, et la durée de chaque coulée en pas
// (la vue en joue un par image : 60 pas ≈ une seconde).
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const FICHIER = "prototypes/prototype-caneton.html";
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n + "=")); return a ? a.split("=")[1] : null; };
for (const a of args) if (!a.startsWith("--niveau=")) { console.error("argument inconnu : " + a); process.exit(2); }
const SEUL = opt("niveau");

const html = readFileSync(join(RACINE, FICHIER), "utf8");
function bloc(id) {
  const m = html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'));
  if (!m) { console.error("bloc introuvable dans " + FICHIER + " : " + id); process.exit(2); }
  return m[1];
}
const DONNEES = JSON.parse(bloc("niveaux"));
const ctx = createContext({ console });
runInContext(bloc("moteur") + "\n;globalThis.Caneton = Caneton;", ctx, { filename: "moteur.js" });
const E = ctx.Caneton;
const RIV = E.RIVIERE;
const T = 0.4;   // l'épaisseur des murs de la vue : une cascade tombe juste derrière

let echecs = 0;
const dire = (ok, texte) => { console.log((ok ? "  ✓ " : "  ✗ ") + texte); if (!ok) echecs++; };
const nomDe = (N, j) => N.passages[j].id;

function donnees(N) {
  const v = [];
  const ids = new Set();
  N.bassins.forEach(b => {
    if (ids.has(b.id)) v.push(`bassin ${b.id} en double`);
    ids.add(b.id);
    if (!(b.x0 < b.x1 && b.fond < b.haut)) v.push(`bassin ${b.id} : dimensions impossibles`);
    if (b.eau < b.fond || b.eau > b.haut) v.push(`bassin ${b.id} : eau ${b.eau} hors de [${b.fond}, ${b.haut}]`);
  });
  const B = id => N.bassins.find(b => b.id === id);
  for (const p of N.passages) {
    const de = B(p.de), vers = p.vers === "riviere" ? null : B(p.vers);
    if (!de) { v.push(`${p.id} : bassin « ${p.de} » inconnu`); continue; }
    if (p.vers !== "riviere" && !vers) { v.push(`${p.id} : bassin « ${p.vers} » inconnu`); continue; }
    if (p.type === "porte") {
      const sens = p.x === de.x1 ? 1 : p.x === de.x0 ? -1 : 0;
      if (!sens) v.push(`${p.id} : x=${p.x} n'est pas un mur de ${de.id}`);
      if (!(p.bas >= de.fond && p.bas < p.haut && p.haut <= de.haut)) v.push(`${p.id} : ouverture [${p.bas}, ${p.haut}] hors du mur de ${de.id} [${de.fond}, ${de.haut}]`);
      if (vers) {
        const partage = vers.x0 === p.x || vers.x1 === p.x;
        const chute = p.x + sens * (T + 0.1);
        if (partage) { if (p.bas < vers.fond || p.haut > vers.haut) v.push(`${p.id} : ouverture hors du mur de ${vers.id}`); }
        else if (!(vers.x0 < chute && chute < vers.x1 && vers.haut < p.bas)) v.push(`${p.id} : la cascade ne tombe pas dans ${vers.id}`);
      } else if (N.riviere.niveau >= p.bas) v.push(`${p.id} : la rivière (${N.riviere.niveau}) n'est pas sous le seuil ${p.bas}`);
    } else if (p.type === "trappe") {
      if (!vers) v.push(`${p.id} : une trappe ne donne pas sur la rivière`);
      else {
        if (!(de.x0 <= p.x0 && p.x0 < p.x1 && p.x1 <= de.x1)) v.push(`${p.id} : hors du fond de ${de.id}`);
        if (!(vers.x0 <= p.x0 && p.x1 <= vers.x1 && vers.haut < de.fond - T)) v.push(`${p.id} : ${vers.id} n'est pas sous la trappe`);
      }
    } else v.push(`${p.id} : type « ${p.type} » inconnu`);
  }
  const c = B(N.canard.bassin);
  if (!c) v.push(`caneton dans un bassin inconnu « ${N.canard.bassin} »`);
  else if (!(c.x0 < N.canard.x && N.canard.x < c.x1)) v.push(`caneton hors de son bassin`);
  if (!N.passages.some(p => p.vers === "riviere")) v.push("aucune sortie vers la rivière");
  return v;
}

function total(N, e) { return e.vol.reduce((a, b) => a + b, 0) + e.sorti; }
function verifierPas(N, e, depart, ou) {
  const v = [];
  const t = total(N, e);
  if (Math.abs(t - depart) > 1e-6) v.push(`I1 ${ou} : ${t.toFixed(6)} d'eau, attendu ${depart.toFixed(6)}`);
  N.bassins.forEach((b, i) => {
    const h = E.niveau(N, e, i);
    if (!Number.isFinite(h)) v.push(`I2 ${ou} : bassin ${b.id} à ${h}`);
    else if (h > b.haut + 1e-6) v.push(`I2 ${ou} : ${b.id} déborde (${h.toFixed(3)} > ${b.haut})`);
    else if (e.vol[i] < -1e-9) v.push(`I2 ${ou} : ${b.id} sous son fond`);
  });
  return v;
}
// Joue un geste pas à pas en vérifiant chaque pas ; rend l'état final et la durée.
function gesteVerifie(N, e, j, depart, viol, ou) {
  let pas = 0, fin;
  try {
    fin = E.reposer(N, E.ouvrir(N, e, j), r => {
      pas++;
      if (viol.length < 4) viol.push(...verifierPas(N, r.e, depart, `${ou}, pas ${pas}`));
    });
  } catch (err) { viol.push(`I4 ${ou} : ${err.message}`); return null; }
  const bis = E.jouer(N, e, j);
  if (JSON.stringify(bis) !== JSON.stringify(fin)) viol.push(`I3 ${ou} : deux résultats différents`);
  return { e: fin, pas };
}
function permutations(a) {
  if (a.length <= 1) return [a];
  return a.flatMap((x, i) => permutations(a.slice(0, i).concat(a.slice(i + 1))).map(r => [x].concat(r)));
}

const niveaux = DONNEES.niveaux.filter(n => !SEUL || n.id === SEUL);
if (!niveaux.length) { console.error("niveau inconnu : " + SEUL); process.exit(2); }
console.log(`Caneton — ${niveaux.length} niveau(x)`);
for (const N of niveaux) {
  console.log(`\n${N.id} ${N.titre} (par ${N.par}, ordres : ${N.ordres})`);
  const d = donnees(N);
  if (!d.length) {
    const r = E.tick(N, E.charger(N));
    if (!r.calme) d.push("D2 l'eau coule dès le chargement");
  }
  dire(!d.length, "D1-D2 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));
  if (d.length) continue;

  const depart = total(N, E.charger(N));
  const t0 = Date.now(), sol = E.resoudre(N, E.charger(N));
  let ok = !!sol;
  if (ok) { let e = E.charger(N); for (const j of sol) e = E.jouer(N, e, j); ok = E.gagne(e); }
  dire(ok, `S1 solution en ${sol ? sol.length : "∅"} gestes (${Date.now() - t0} ms)` + (sol ? " : " + sol.map(j => nomDe(N, j)).join(", ") : ""));
  if (sol) dire(sol.length === N.par, `S2 par ${N.par} = meilleure solution ${sol.length}`);

  const vannes = E.actions(N, E.charger(N));
  const viol = [], gagnants = [], perdants = [];
  let plusLong = 0;
  for (const ordre of permutations(vannes)) {
    let e = E.charger(N);
    const nom = ordre.map(j => nomDe(N, j)).join(" → ");
    for (const j of ordre) {
      if (E.gagne(e)) break;
      const r = gesteVerifie(N, e, j, depart, viol, nom);
      if (!r) break;
      e = r.e; plusLong = Math.max(plusLong, r.pas);
    }
    (E.gagne(e) ? gagnants : perdants).push(nom);
  }
  if (N.ordres === "tous") dire(!perdants.length, `S3 chaque ordre gagne (${gagnants.length}/${gagnants.length + perdants.length})` + (perdants.length ? " — perdent : " + perdants.join(", ") : ""));
  else if (N.ordres === "certains") dire(gagnants.length > 0 && perdants.length > 0, `S3 l'ordre compte : ${gagnants.length} ordre(s) gagnent, ${perdants.length} perdent`);
  else dire(false, `S3 « ordres » doit valoir "tous" ou "certains", pas ${JSON.stringify(N.ordres)}`);
  dire(!viol.length, `I1-I4 invariants à chaque pas des ${gagnants.length + perdants.length} parties` + (viol.length ? " :\n      " + viol.slice(0, 4).join("\n      ") : ""));
  console.log(`    gagnent : ${gagnants.join(" | ") || "aucun"}`);
  if (perdants.length) console.log(`    perdent : ${perdants.join(" | ")}`);
  console.log(`    coulée la plus longue : ${plusLong} pas (≈ ${(plusLong / 60).toFixed(1)} s à l'écran)`);
}
console.log(echecs ? `\n${echecs} échec(s).` : "\nTout est vert.");
process.exit(echecs ? 1 : 0);
