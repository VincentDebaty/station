#!/usr/bin/env node
// ------------------------------------------------------------------
// pontier-banc — LE BANC D'ESSAI DU PROTOTYPE « LE PONTIER ».
//
//   node tools/pontier-banc.mjs                  le niveau, 300 parties au hasard
//   node tools/pontier-banc.mjs --graine=500     une autre batterie de parties au hasard
//   node tools/pontier-banc.mjs --parties=1000 --detail
//
// Le portrait du jeu rêvé (20 octobre 2026) : Station sous un autre habit. Des
// péniches à l'horaire, un aiguillage, une grand-rue qui coupe les deux bras
// par deux ponts levants, et un seul ponton d'attente à poser. Le moteur
// (bloc <script id="moteur"> de prototypes/prototype-pontier.html) et le
// niveau (bloc JSON « niveaux ») sont extraits du fichier et joués sans
// navigateur — jamais une copie. Le banc REFUSE (code de sortie 1) au lieu
// d'avertir.
//
// Il n'y a pas de fouille exhaustive ici : une partie dure trois minutes et
// chaque pas est un geste possible. Le banc fait jouer des PONTIERS
// AUTOMATES, une famille réglée par quelques paramètres (combien de bateaux
// attendre avant de lever, combien de temps au plus, garder levé pour le
// suivant, lever les deux ponts ensemble, ménager la rue, où poser le ponton,
// et quand). Tous aiguillent sans faute : l'aiguillage est le réflexe à
// apprendre, pas la stratégie à mesurer. Le « par » est le meilleur de la
// famille — le meilleur pontier du banc, pas une preuve d'optimalité.
//
// LES DONNÉES
//   D1  l'horaire est dans l'ordre et vise un bras qui existe ; les vagues se
//       suivent sans trou ; il y a un ponton à poser
//
// L'IDÉE — ce qui fait des deux flux un choix, pas une corvée :
//   E1  le meilleur pontier gagne, et son journal de gestes se rejoue pas à
//       pas jusqu'au même gain
//   E2  son humeur finale est exactement le « par » écrit
//   E3  le pontier PRESSÉ — lève pour chaque bateau dès qu'il attend, baisse
//       dès qu'il est passé, ne pose pas de ponton — n'a qu'une étoile ou
//       perd : servir chaque bateau tout de suite coûte trop à la rue
//   E4  le même, rue vide, finit avec trois étoiles : c'est bien le croisement
//       des deux flux qui fait la difficulté, pas l'horaire des bateaux
//   E5  le pontier GROUPEUR — ne lève que pour deux bateaux à la fois — n'a
//       qu'une étoile ou perd : grouper à tout prix ne suffit pas non plus
//   E6  la pièce rare compte : sans ponton, le meilleur pontier perd au moins
//       une étoile (il finit à plus de « trois » points sous le par)
//   E7  sa PLACE compte : posé sur l'autre bras, le meilleur ponton fait
//       moins bien d'au moins « trois » points — le choix n'est pas gratuit
//
// LES INVARIANTS — sur des parties aux gestes au hasard, à chaque pas ; une
// violation est un bug du moteur :
//   I1  rien ne se perd : chaque bateau arrivé est dans le chenal, un bras,
//       sous un pont ou à quai ; chaque charrette née est sur la rue ou sortie
//   I2  jamais un pont qui n'est pas baissé avec une charrette sur son
//       tablier ; jamais un bateau dessous un pont qui n'est pas levé
//   I3  jamais plus de bateaux dans un bras que de places (1, 2 avec ponton) ;
//       l'humeur ne remonte jamais
//   I4  personne ne double : les bateaux franchissent le carrefour dans
//       l'ordre d'arrivée, chaque pont dans l'ordre d'entrée dans son bras ;
//       les charrettes sortent dans l'ordre où elles sont nées
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
const FICHIER = opt("fichier") || "prototypes/prototype-pontier.html";
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
runInContext(bloc("moteur") + "\n;globalThis.Pontier = Pontier;", ctx, { filename: "moteur.js" });
const E = ctx.Pontier;

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
const fin = e => !e.fin ? "pas fini" : e.fin.fin === "gagne" ? `gagné, humeur ${num(e.fin.jauge)}` : `perdu à ${sec(e.k)}`;
const pertes = e => `rue −${num(e.perte.rue)}, mariniers −${num(e.perte.bateaux)}, quais −${num(e.perte.quais)}`;
const HORIZON = N => E.pasDe(N.horaire[N.horaire.length - 1].heure + 400);

function donnees(N) {
  const v = [];
  N.horaire.forEach((h, k) => {
    if (k && h.heure < N.horaire[k - 1].heure) v.push(`horaire hors d'ordre au bateau ${k}`);
    if (!(h.vers >= 0 && h.vers < N.bras.length)) v.push(`bateau ${k} : bras ${h.vers}`);
  });
  N.rue.vagues.forEach((w, k) => { if (k && w.de !== N.rue.vagues[k - 1].a) v.push(`vague ${k} : commence à ${w.de}, la précédente finit à ${N.rue.vagues[k - 1].a}`); });
  if (N.bras.length !== 2) v.push(`${N.bras.length} bras : le moteur en attend deux`);
  if (!(N.pontons >= 1)) v.push("aucun ponton à poser");
  return v;
}

// --- Les pontiers automates ------------------------------------------------------
// Une politique regarde l'état à chaque pas et rend les gestes à faire.
//   k        lever dès que k bateaux attendent dans le bras (2 n'a de sens qu'avec un ponton)
//   w        ... ou dès que la tête du bras attend depuis w secondes
//   tau      garder levé si un bateau du bras arrive à l'arrêt dans moins de tau secondes
//   sync     lever aussi l'autre pont si un bateau y attend, quand on en lève un
//   rue      ne pas lever (avant w) tant que la rue a au moins « rue » charrettes arrêtées
//   ponton   le bras où poser le ponton (-1 : jamais), à l'heure tPonton
//   debloque lever tout de suite si la tête du chenal attend au carrefour un bras plein
function pontier(P) {
  return (N, e) => {
    const c = E.C(N), g = [], tt = E.heure(e);
    if (P.ponton >= 0 && !e.pontons[P.ponton] && e.reste > 0 && tt >= P.tPonton) g.push("ponton" + P.ponton);
    // l'aiguillage : vers le bras que vise la tête du chenal
    if (e.chenal.length) {
      const v = N.horaire[e.chenal[0]].vers;
      if (v !== e.aig && !E.carrefourOccupe(N, e)) g.push("aiguille");
    }
    const tete = e.chenal.length ? e.bat[e.chenal[0]] : null;
    const arretes = e.chars.reduce((s, f) => s + f.filter(ch => ch.arret > 0).length, 0);
    const veut = [0, 1].map(a => {
      const f = e.files[a];
      if (!f.length) return false;
      const b0 = e.bat[f[0]];
      if (b0.q < c.LBR) return false;
      const presse = b0.arret >= E.pasDe(P.w);
      const coince = P.debloque && tete && tete.q >= c.LCH && e.aig === a && f.length >= 1 + (e.pontons[a] ? 1 : 0);
      if (presse || coince) return true;
      if (P.rue && arretes >= P.rue) return false;
      return f.length >= P.k;
    });
    for (let a = 0; a < 2; a++) {
      const p = e.ponts[a], f = e.files[a];
      let lever = veut[a] || (P.sync && veut[1 - a] && f.length && e.bat[f[0]].q >= c.LBR);
      if (p.cible === 0 && lever) g.push("pont" + a);
      if (p.cible === 1 && !lever && !E.dessous(e, a)) {
        const garder = f.some(i => e.bat[i].q >= c.LBR - E.pasDe(P.tau)) ||
          (P.tau > 0 && tete && e.aig === a && tete.q >= c.LCH - E.pasDe(P.tau));
        if (!garder) g.push("pont" + a);
      }
    }
    return g;
  };
}
function jouer(N, politique) {
  const e = E.charger(N), journal = [], lim = HORIZON(N);
  while (!e.fin && e.k < lim) {
    for (const g of politique(N, e)) if (!E.geste(N, e, g)) journal.push({ k: e.k, g });
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
const score = e => e.fin && e.fin.fin === "gagne" ? e.fin.jauge : -1000 + E.heure(e) / 1000;

const PRESSE = { k: 1, w: 0, tau: 0, sync: false, rue: 0, ponton: -1, tPonton: 0, debloque: false };
const GROUPEUR = { k: 2, w: 1e9, tau: 0, sync: true, rue: 0, ponton: -1, tPonton: 0, debloque: false };
function famille(pontons, tPontons) {
  const l = [];
  for (const k of [1, 2]) for (const w of [0, 3, 6, 10, 15]) for (const tau of [0, 2, 4]) for (const sync of [false, true])
    for (const rue of [0, 4, 8]) for (const ponton of pontons) for (const tPonton of ponton < 0 ? [0] : tPontons)
      l.push({ k, w, tau, sync, rue, ponton, tPonton, debloque: true });
  return l;
}
function meilleur(N, liste) {
  let m = null;
  for (const P of liste) {
    const r = jouer(N, pontier(P)), s = score(r.e);
    if (!m || s > m.s + 1e-9) m = { s, P, ...r };
  }
  return m;
}
const reglage = P => `k ${P.k}, w ${P.w} s, tau ${P.tau} s, ${P.sync ? "ensemble" : "chacun"}, rue ${P.rue || "—"}, ponton ${P.ponton < 0 ? "aucun" : (P.ponton ? "est" : "ouest") + " à " + P.tPonton + " s"}`;

// --- Les invariants -------------------------------------------------------------
const GESTES = ["aiguille", "pont0", "pont1", "ponton0", "ponton1"];
function partie(N, hasard) {
  const c = E.C(N), v = [], e = E.charger(N), journal = [], lim = HORIZON(N);
  const ordreCarrefour = [], ordrePont = [[], []], ordreBras = [[], []], sortiesRue = [[], []];
  let jauge = e.jauge;
  while (!e.fin && e.k < lim && !v.length) {
    if (hasard() < 0.03) { const g = GESTES[Math.floor(hasard() * GESTES.length)]; if (!E.geste(N, e, g)) journal.push({ k: e.k, g }); }
    const avant = e.bat.map(b => b.etat), ids = e.chars.map(f => f.map(ch => ch.id));
    E.pas(N, e);
    const t = "à " + sec(e.k);
    // I1
    const ou = { chenal: 0, bras: 0, dessous: 0, livre: 0, avant: 0 };
    e.bat.forEach(b => ou[b.etat]++);
    const arrives = N.horaire.filter(h => E.pasDe(h.heure) <= e.k).length;
    if (ou.chenal + ou.bras + ou.dessous + ou.livre !== arrives) v.push(`I1 ${t} : ${arrives} bateaux arrivés, ${JSON.stringify(ou)}`);
    if (ou.chenal !== e.chenal.length || ou.bras !== e.files[0].length + e.files[1].length) v.push(`I1 ${t} : files incohérentes`);
    for (let d = 0; d < 2; d++) if (e.chars[d].length + e.sortis[d] !== e.nes[d]) v.push(`I1 ${t} : sens ${d}, ${e.nes[d]} nées, ${e.chars[d].length} sur la rue, ${e.sortis[d]} sorties`);
    // I2
    e.ponts.forEach((p, b) => {
      if (p.n > 0 && E.tablierOccupe(N, e, b)) v.push(`I2 ${t} : une charrette sur le pont ${b} qui se lève (${p.n})`);
      if (E.dessous(e, b) && p.n !== c.NLEV) v.push(`I2 ${t} : un bateau sous le pont ${b} qui n'est pas levé (${p.n})`);
    });
    // I3
    e.files.forEach((f, a) => { if (f.length > 1 + (e.pontons[a] ? 1 : 0)) v.push(`I3 ${t} : ${f.length} bateaux dans le bras ${a}`); });
    if (e.jauge > jauge + 1e-9) v.push(`I3 ${t} : l'humeur remonte`);
    jauge = e.jauge;
    // I4
    e.bat.forEach((b, i) => {
      if (avant[i] === "chenal" && b.etat !== "chenal") { ordreCarrefour.push(i); ordreBras[b.bras].push(i); }
      if (avant[i] === "bras" && b.etat === "dessous") ordrePont[b.bras].push(i);
    });
    for (let d = 0; d < 2; d++) { const reste = new Set(e.chars[d].map(ch => ch.id)); for (const id of ids[d]) if (!reste.has(id)) sortiesRue[d].push(id); }
  }
  const croissant = l => l.every((x, j) => !j || x > l[j - 1]);
  if (!croissant(ordreCarrefour)) v.push(`I4 le carrefour : ${ordreCarrefour.join(" ")}`);
  for (let a = 0; a < 2; a++) if (ordrePont[a].join() !== ordreBras[a].slice(0, ordrePont[a].length).join()) v.push(`I4 le pont ${a} : ${ordrePont[a].join(" ")} pour ${ordreBras[a].join(" ")}`);
  for (let d = 0; d < 2; d++) if (!croissant(sortiesRue[d])) v.push(`I4 la rue, sens ${d} : une charrette en double une autre`);
  const bis = rejouer(N, journal).e;
  if (!v.length && JSON.stringify(bis) !== JSON.stringify(e)) v.push(`I5 la partie rejouée diffère`);
  return { v, e };
}

// --- Le banc ---------------------------------------------------------------------
console.log(`Le pontier — ${DONNEES.niveaux.length} niveau(x), ${PARTIES} parties au hasard chacun, graines ${GRAINE}…${GRAINE + PARTIES - 1}`);
for (const N of DONNEES.niveaux) {
  const c = E.C(N);
  console.log(`\n${N.id} ${N.titre} (${N.horaire.length} péniches, ${c.arr[0].length + c.arr[1].length} charrettes, par ${N.par})`);
  const d = donnees(N);
  dire(!d.length, "D1 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));

  const t0 = Date.now();
  const T = [0, 30, 60, 100];
  const fam = famille([-1, 0, 1], T);
  const m = meilleur(N, fam);
  const b = rejouer(N, m.journal);
  const ok = m.e.fin && m.e.fin.fin === "gagne" && !b.refus && b.e.fin && b.e.fin.fin === "gagne" && b.e.fin.jauge === m.e.fin.jauge;
  dire(ok, `E1 le meilleur pontier (${fam.length} essayés, ${Date.now() - t0} ms) : ${fin(m.e)}, ${m.journal.length} gestes\n      ${reglage(m.P)}\n      ${pertes(m.e)}`);
  if (m.e.fin && m.e.fin.fin === "gagne") dire(Math.abs(m.e.fin.jauge - N.par) < 0.05, `E2 par ${N.par} = meilleure humeur ${m.e.fin.jauge}`);

  const p = jouer(N, pontier(PRESSE)).e;
  dire(!(p.fin && p.fin.fin === "gagne") || E.etoiles(N, p.fin.jauge) === 1, `E3 le pontier pressé : ${fin(p)}${p.fin && p.fin.fin === "gagne" ? ", " + E.etoiles(N, p.fin.jauge) + " étoile(s)" : ""} (${pertes(p)})`);
  const rueVide = { ...N, rue: { ...N.rue, vagues: N.rue.vagues.map(w => ({ ...w, intervalle: 1e6 })) } };
  const pv = jouer(rueVide, pontier(PRESSE)).e;
  dire(pv.fin && pv.fin.fin === "gagne" && E.etoiles(N, pv.fin.jauge) === 3, `E4 le même, rue vide : ${fin(pv)}`);
  const g = jouer(N, pontier(GROUPEUR)).e;
  const gp = meilleur(N, [0, 1].flatMap(a => T.map(tp => ({ ...GROUPEUR, ponton: a, tPonton: tp }))));
  const gm = score(g) >= score(gp.e) ? g : gp.e;
  dire(!(gm.fin && gm.fin.fin === "gagne") || E.etoiles(N, gm.fin.jauge) === 1, `E5 le pontier groupeur (le mieux, avec ou sans ponton) : ${fin(gm)}${gm.fin && gm.fin.fin === "gagne" ? ", " + E.etoiles(N, gm.fin.jauge) + " étoile(s)" : ""} (${pertes(gm)})`);
  const sans = meilleur(N, famille([-1], T));
  dire(score(sans.e) <= N.par - N.etoiles.trois - 1e-9, `E6 sans ponton, le meilleur : ${fin(sans.e)} (${reglage(sans.P)})`);
  if (m.P.ponton >= 0) {
    const autre = meilleur(N, famille([1 - m.P.ponton], T));
    dire(score(autre.e) <= N.par - N.etoiles.trois - 1e-9, `E7 le ponton sur l'autre bras (${1 - m.P.ponton ? "est" : "ouest"}), le meilleur : ${fin(autre.e)}`);
  } else dire(false, "E7 le meilleur pontier ne pose pas de ponton : la pièce rare ne sert à rien");
  if (DETAIL) {
    const parBras = [0, 1].map(a => meilleur(N, famille([a], T)));
    console.log(`    détail : sans ponton ${num(score(sans.e))}, ouest ${num(score(parBras[0].e))}, est ${num(score(parBras[1].e))}, pressé ${num(score(p))}, groupeur ${num(score(gm))}`);
    const r = m.e;
    console.log("    attentes du meilleur : " + r.bat.map((x, i) => `${i}:${num(x.arret * E.PAS)}`).join(" "));
  }

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
