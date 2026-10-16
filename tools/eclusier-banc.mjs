#!/usr/bin/env node
// ------------------------------------------------------------------
// eclusier-banc — LE BANC D'ESSAI DU PROTOTYPE « L'ÉCLUSIER ».
//
//   node tools/eclusier-banc.mjs                  tous les niveaux, 300 parties au hasard
//   node tools/eclusier-banc.mjs --graine=500     une autre batterie de parties au hasard
//   node tools/eclusier-banc.mjs --niveau=1-2 --parties=1000
//
// Le mélange de Station et d'Écluses : le 1-2 d'Écluses, mais les bateaux
// arrivent à l'horaire et le bief de partage n'a qu'une rigole pour se
// refaire. Le moteur (bloc <script id="moteur"> de
// prototypes/prototype-eclusier.html) et les niveaux (bloc JSON « niveaux »)
// sont extraits du fichier et joués sans navigateur — jamais une copie. Le
// banc REFUSE (code de sortie 1) au lieu d'avertir.
//
// LES DONNÉES
//   D1  l'horaire est dans l'ordre, chaque bateau va d'une rive à l'autre,
//       les seuils sont sur les fonds, aucun bief n'est à sec au départ
//
// L'IDÉE — ce qui fait de l'horaire un choix, pas une corvée :
//   E1  la fouille (gestes aux instants de repos et aux arrivées) trouve une
//       partie gagnée, et elle se rejoue geste par geste jusqu'au gain
//   E2  l'attente totale de cette partie est exactement le « par » écrit :
//       les étoiles se comptent contre la vraie meilleure partie trouvée
//   E3  l'éclusier PRESSÉ — sert le plus ancien bateau tout de suite, ne fait
//       jamais attendre personne — PERD, par le bief à sec : servir dans
//       l'ordre ne suffit pas, l'eau compte
//   E4  le même, avec un bief de partage sans fond, GAGNE : c'est bien l'eau
//       qui fait la difficulté, pas l'horaire
//   E6  la meilleure partie attend PLUS que la meilleure partie avec un bief
//       sans fond : l'eau oblige à faire attendre quelqu'un — sinon la jauge
//       ne serait qu'une contrainte de plus à respecter, pas un choix
//   E5  l'éclusier AVARE — fait tout de suite ce qui est gratuit, mais ne
//       remplit jamais le sas sans deux bateaux qui montent tant qu'un autre
//       peut encore monter — PERD, par la patience : grouper à tout prix ne
//       suffit pas non plus. Il faut doser. (Mutant de patience infinie : il
//       doit alors GAGNER, sinon c'est qu'il se bloque au lieu de grouper.)
//
// LES INVARIANTS — sur des parties aux gestes au hasard, à n'importe quel
// pas (pas seulement au repos) ; une violation est un bug du moteur :
//   I1  l'eau se conserve : bief + sas = départ + rigole − déversoir − rivière
//   I2  aucun niveau sous son fond ni qui n'est pas un nombre ; la rivière ne
//       bouge pas
//   I3  jamais les deux portes ouvertes ; jamais plus de deux bateaux dans le
//       sas ; un bateau ne franchit qu'une porte ouverte, entre deux eaux au
//       même niveau, et d'un bassin à son voisin
//   I4  sur chaque rive, les bateaux entrent dans le sas dans l'ordre où ils
//       sont arrivés (la file de Station : personne ne double)
//   I5  les mêmes gestes aux mêmes pas donnent la même partie
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
for (const a of args) if (!a.startsWith("--")) { console.error("argument inconnu : " + a); process.exit(2); }
const FICHIER = opt("fichier") || "prototypes/prototype-eclusier.html";
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
const ctx = createContext({ console });
runInContext(bloc("moteur") + "\n;globalThis.Eclusier = Eclusier;", ctx, { filename: "moteur.js" });
const E = ctx.Eclusier;

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
const fin = f => !f ? "rien" : f.fin === "gagne" ? `gagné, ${f.attente.toFixed(1).replace(".", ",")} s d'attente` :
  f.fin === "sec" ? "perdu, bief à sec" : f.fin === "patience" ? `perdu, le bateau ${f.bateau} a perdu patience` : f.fin;

function donnees(N) {
  const v = [], n = N.bassins.length;
  N.horaire.forEach((h, k) => {
    if (k && h.heure < N.horaire[k - 1].heure) v.push(`horaire hors d'ordre au bateau ${k}`);
    if (![0, n - 1].includes(h.de) || ![0, n - 1].includes(h.vers) || h.de === h.vers) v.push(`bateau ${k} : de ${h.de} vers ${h.vers}`);
  });
  N.liaisons.forEach((l, g) => {
    const f = Math.max(N.bassins[g].fond, N.bassins[g + 1].fond);
    if (Math.abs(l.seuil - f) > 1e-9 || l.crete <= l.seuil) v.push(`porte ${g} : seuil ${l.seuil}, crête ${l.crete}, fonds ${f}`);
  });
  N.bassins.forEach((b, i) => { if (b.type === "bief" && b.niveau < b.fond + N.tirant) v.push(`bassin ${i} à sec au départ`); });
  return v;
}

// --- Jouer jusqu'au repos, et ouvrir un côté -------------------------------------
const HORIZON = N => E.pasDe(N.horaire[N.horaire.length - 1].heure + N.patience + 60);
function auRepos(N, e) {
  const lim = HORIZON(N);
  do E.pas(N, e); while (!e.fin && !E.repos(N, e) && e.k < lim);
}
// Ouvrir la porte g : fermer d'abord l'autre si elle l'est. Rend les gestes faits.
function ouvrir(N, e, g, journal) {
  const o = e.ouvert.findIndex(x => x);
  if (o >= 0) { if (E.geste(N, e, o)) return false; journal.push({ k: e.k, g: o }); }
  if (E.geste(N, e, g)) return false;
  journal.push({ k: e.k, g });
  return true;
}
// Attendre le prochain bateau ; s'il n'en vient plus, quelques secondes (la rigole remplit).
function attendre(N, e) {
  const p = E.prochaine(N, e), lim = HORIZON(N);
  const jusque = p >= 0 ? p : e.k + E.pasDe(5);
  while (!e.fin && e.k < jusque && e.k < lim) E.pas(N, e);
  if (!e.fin && !E.repos(N, e)) auRepos(N, e);
}

// --- Les éclusiers ---------------------------------------------------------------
// Une politique regarde l'état au repos et rend la porte à ouvrir, ou -1 : attendre.
const SAS = 1;
const dansLeSas = (N, e) => e.bat.map((b, k) => k).filter(k => e.bat[k].ou === SAS && e.bat[k].va < 0 && e.bat[k].fini < 0);
const enAttente = (N, e) => e.bat.map((b, k) => k).filter(k => e.bat[k].arrive >= 0 && e.bat[k].entre < 0);
const coteDe = (N, i) => i === 0 ? 0 : N.liaisons.length - 1;            // la porte du côté du bassin i
function presse(N, e) {
  const s = dansLeSas(N, e);
  if (s.length) { const g = coteDe(N, N.horaire[s[0]].vers); return e.ouvert[g] ? -1 : g; }
  const a = enAttente(N, e);
  if (a.length) { const g = coteDe(N, N.horaire[a[0]].de); return e.ouvert[g] ? -1 : g; }
  return -1;
}
function avare(N, e) {
  // Tout ce qui est gratuit, tout de suite ; remplir le sas, seulement à pleine
  // charge (deux bateaux qui montent), sauf si plus personne ne peut monter.
  const G = N.liaisons.length - 1, haut = e.niv[SAS] >= e.niv[G + 1] - E.POSE;
  const montants = k => N.horaire[k].vers > N.horaire[k].de;
  const plusPersonne = () => !e.bat.some((b, k) => montants(k) && b.entre < 0);
  const s = dansLeSas(N, e), a = enAttente(N, e);
  if (s.length) {
    if (!montants(s[0])) return e.ouvert[0] ? -1 : 0;                  // descendre ne coûte rien
    if (haut) return e.ouvert[G] ? -1 : G;
    return s.length >= 2 || plusPersonne() ? (e.ouvert[G] ? -1 : G) : -1;
  }
  if (a.some(montants)) return e.ouvert[0] ? -1 : 0;                   // le sas descend à vide : gratuit
  if (a.length) return haut || plusPersonne() ? (e.ouvert[G] ? -1 : G) : -1;
  return -1;
}
function jouerPolitique(N, politique) {
  const e = E.charger(N), journal = [], lim = HORIZON(N);
  auRepos(N, e);
  let bas = Infinity;
  while (!e.fin && e.k < lim) {
    const g = politique(N, e);
    if (g >= 0) { if (!ouvrir(N, e, g, journal)) break; auRepos(N, e); }
    else { const k = e.k; attendre(N, e); if (e.k === k) break; }
    bas = Math.min(bas, e.niv[N.bassins.length - 1]);
  }
  return { e, journal, bas };
}

// --- La fouille ----------------------------------------------------------------
// À chaque repos (et à chaque arrivée qu'on a attendue) : ouvrir l'une des
// portes, ou attendre le bateau suivant. Branche et borne sur l'attente totale,
// qui ne fait que croître ; un état déjà vu à moindre coût est coupé.
function fouiller(N, limite) {
  const vus = new Map();
  let meilleur = null, noeuds = 0, coupe = false;
  const cle = e => e.k + "|" + e.ouvert.map(Number).join("") + "|" + e.niv.map(x => x.toFixed(4)).join(",") + "|" +
    e.bat.map(b => b.fini >= 0 ? "f" : b.ou + ":" + b.va).join(",");
  function explorer(e, journal) {
    if (++noeuds > limite) { coupe = true; return; }
    if (e.fin) {
      if (e.fin.fin === "gagne" && (!meilleur || e.fin.attente < meilleur.attente - 1e-9)) meilleur = { attente: e.fin.attente, journal: journal.slice(), e };
      return;
    }
    const cout = E.attente(N, e);
    if (meilleur && cout >= meilleur.attente - 1e-9) return;
    const c = cle(e), v = vus.get(c);
    if (v != null && v <= cout + 1e-9) return;
    vus.set(c, cout);
    for (let g = 0; g < N.liaisons.length; g++) {
      if (e.ouvert[g]) continue;
      const f = E.copie(e), j = journal.slice();
      if (!ouvrir(N, f, g, j)) continue;
      auRepos(N, f);
      explorer(f, j);
    }
    const f = E.copie(e);
    attendre(N, f);
    if (f.k > e.k) explorer(f, journal);
  }
  const e = E.charger(N);
  auRepos(N, e);
  explorer(e, []);
  return { meilleur, noeuds, coupe };
}
// Rejouer un journal de gestes, pas à pas, comme la page.
function rejouer(N, journal) {
  const e = E.charger(N);
  let i = 0;
  const lim = HORIZON(N);
  while (!e.fin && e.k < lim) {
    while (i < journal.length && journal[i].k === e.k) { if (E.geste(N, e, journal[i].g)) return { e, refus: journal[i] }; i++; }
    E.pas(N, e);
  }
  return { e };
}

// --- Les invariants -------------------------------------------------------------
function partie(N, hasard) {
  const v = [], e = E.charger(N), journal = [];
  const depart = E.eauTotale(N, e), riv = N.bassins.map((b, i) => b.fixe ? b.niveau : null);
  const ordre = [[], []];                 // les entrées dans le sas, rive par rive
  const lim = HORIZON(N);
  while (!e.fin && e.k < lim && !v.length) {
    if (hasard() < 0.02) { const g = Math.floor(hasard() * N.liaisons.length); if (!E.geste(N, e, g)) journal.push({ k: e.k, g }); }
    const avant = e.bat.map(b => ({ ...b }));
    E.pas(N, e);
    const t = "à " + sec(e.k);
    const total = E.eauTotale(N, e), attendu = depart + e.entree - e.sortie;
    if (Math.abs(total - attendu) > 1e-6) v.push(`I1 ${t} : ${total.toFixed(6)} d'eau, attendu ${attendu.toFixed(6)}`);
    N.bassins.forEach((b, i) => {
      if (!Number.isFinite(e.niv[i])) v.push(`I2 ${t} : bassin ${i} à ${e.niv[i]}`);
      else if (e.niv[i] < b.fond - 1e-9) v.push(`I2 ${t} : bassin ${i} sous son fond`);
      if (riv[i] != null && e.niv[i] !== riv[i]) v.push(`I2 ${t} : la rivière a bougé (${e.niv[i]})`);
    });
    if (e.ouvert.filter(x => x).length > 1) v.push(`I3 ${t} : les deux portes ouvertes`);
    const dans = e.bat.filter(b => b.fini < 0 && ((b.va < 0 && b.ou === SAS) || b.va === SAS)).length;
    if (dans > E.capacite(N, SAS)) v.push(`I3 ${t} : ${dans} bateaux dans le sas`);
    e.bat.forEach((b, k) => {
      if (b.va >= 0) {
        const g = Math.min(b.ou, b.va);
        if (Math.abs(b.va - b.ou) !== 1) v.push(`I3 ${t} : bateau ${k} saute un bassin`);
        if (!e.ouvert[g]) v.push(`I3 ${t} : bateau ${k} passe la porte ${g} fermée`);
        if (Math.abs(e.niv[b.ou] - e.niv[b.va]) > E.POSE) v.push(`I3 ${t} : bateau ${k} passe entre deux eaux (${e.niv[b.ou]} / ${e.niv[b.va]})`);
      }
      if (avant[k].entre < 0 && b.entre >= 0) ordre[N.horaire[k].de === 0 ? 0 : 1].push(k);
    });
  }
  ordre.forEach((o, r) => { for (let j = 1; j < o.length; j++) if (o[j] < o[j - 1]) v.push(`I4 rive ${r} : le bateau ${o[j]} double le bateau ${o[j - 1]}`); });
  const bis = rejouer(N, journal).e;
  if (JSON.stringify(bis) !== JSON.stringify(e) && !v.length) v.push(`I5 la partie rejouée diffère`);
  return { v, fin: e.fin };
}

// --- Le banc ---------------------------------------------------------------------
const niveaux = DONNEES.niveaux.filter(n => !SEUL || n.id === SEUL);
if (!niveaux.length) { console.error("niveau inconnu : " + SEUL); process.exit(2); }
console.log(`L'éclusier — ${niveaux.length} niveau(x), ${PARTIES} parties au hasard chacun, graines ${GRAINE}…${GRAINE + PARTIES - 1}`);
for (const N of niveaux) {
  console.log(`\n${N.id} ${N.titre} (${N.horaire.length} bateaux, patience ${N.patience} s, par ${N.par} s)`);
  const d = donnees(N);
  dire(!d.length, "D1 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));

  const t0 = Date.now(), r = fouiller(N, +(opt("limite") || 400000));
  let ok = false;
  if (r.meilleur) { const b = rejouer(N, r.meilleur.journal); ok = !b.refus && b.e.fin && b.e.fin.fin === "gagne" && Math.abs(b.e.fin.attente - r.meilleur.attente) < 1e-9; }
  dire(ok, `E1 la fouille gagne (${r.noeuds} nœuds${r.coupe ? ", COUPÉE à la limite" : ""}, ${Date.now() - t0} ms)` +
    (r.meilleur ? ` : ${r.meilleur.e.remplis} éclusées montantes, ${r.meilleur.journal.length} gestes\n      ` +
      r.meilleur.journal.map(j => `${sec(j.k)} ${["aval", "amont"][j.g]}`).join(", ") +
      "\n      attentes : " + r.meilleur.e.bat.map((b, k) => `${N.horaire[k].couleur} ${sec(b.sort - b.arrive)}`).join(", ") : ""));
  if (r.meilleur) dire(!r.coupe && Math.abs(r.meilleur.attente - N.par) < 0.01, `E2 par ${N.par} s = meilleure attente ${r.meilleur.attente} s` + (r.coupe ? " (fouille coupée : pas une preuve)" : ""));

  const p = jouerPolitique(N, presse);
  dire(p.e.fin && p.e.fin.fin === "sec", `E3 l'éclusier pressé : ${fin(p.e.fin)} à ${sec(p.e.k)} (${p.e.remplis} éclusées montantes)`);
  const sansFond = { ...N, bassins: N.bassins.map(b => b.type === "bief" ? { ...b, surface: 1e7 } : b) };
  const q = jouerPolitique(sansFond, presse);
  dire(q.e.fin && q.e.fin.fin === "gagne", `E4 le même, bief sans fond : ${fin(q.e.fin)}`);
  const r2 = fouiller(sansFond, +(opt("limite") || 400000));
  if (r.meilleur && r2.meilleur) dire(r.meilleur.attente > r2.meilleur.attente + 1, `E6 l'eau fait attendre : meilleure partie ${r.meilleur.attente} s, ${r2.meilleur.attente} s avec un bief sans fond`);
  const a = jouerPolitique(N, avare);
  dire(a.e.fin && a.e.fin.fin === "patience", `E5 l'éclusier avare : ${fin(a.e.fin)} à ${sec(a.e.k)} (${a.e.remplis} éclusées montantes)`);

  const viol = [], stats = {};
  for (let k = 0; k < PARTIES && viol.length < 4; k++) {
    const r = partie(N, Hasard(GRAINE + k));
    viol.push(...r.v);
    const f = r.fin ? r.fin.fin : "temps";
    stats[f] = (stats[f] || 0) + 1;
  }
  dire(!viol.length, `I1-I5 invariants sur ${PARTIES} parties` + (viol.length ? " :\n      " + viol.slice(0, 4).join("\n      ") : ""));
  console.log("    au hasard : " + Object.entries(stats).map(([f, n]) => `${f} ${Math.round(100 * n / PARTIES)} %`).join(", "));
}
console.log(echecs ? `\n${echecs} échec(s).` : "\nTout est vert.");
process.exit(echecs ? 1 : 0);
