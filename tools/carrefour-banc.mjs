#!/usr/bin/env node
// ------------------------------------------------------------------
// carrefour-banc — LE BANC D'ESSAI DU PROTOTYPE « LE CARREFOUR ».
//
//   node tools/carrefour-banc.mjs                  le niveau, 300 parties au hasard
//   node tools/carrefour-banc.mjs --graine=500     une autre batterie de parties au hasard
//   node tools/carrefour-banc.mjs --parties=1000 --detail
//
// La suite du Pontier (20 octobre 2026) : un carrefour, trois phases de feux
// (l'avenue, la rue, les piétons), quatre flux (voitures, tram à l'horaire,
// piétons, ambulances), et un QUOTA de personnes à faire passer avant 18 h.
// Le moteur (bloc <script id="moteur"> de prototypes/prototype-carrefour.html)
// et le niveau (bloc JSON « niveaux ») sont extraits du fichier et joués sans
// navigateur — jamais une copie. Le banc REFUSE (code de sortie 1) au lieu
// d'avertir.
//
// Comme pour Le pontier, pas de fouille exhaustive : le banc fait jouer une
// famille de RÉGULATEURS AUTOMATES (vert minimal, vert maximal, attente
// tolérée en face, file vide, seuil des piétons, priorité au tram) ; le
// « par » est le meilleur d'entre eux, pas une preuve d'optimalité. Tous
// laissent passer l'ambulance dès qu'elle arrive.
//
// LES DONNÉES
//   D1  les vagues se suivent de 0 à la durée, sans trou ; les trams et les
//       ambulances sont dans l'ordre et dans la partie ; deux voies par axe ;
//       quota < deux < trois
//
// L'IDÉE — ce qui fait des feux un choix, pas une corvée :
//   E1  le meilleur régulateur atteint le quota, et son journal de gestes se
//       rejoue pas à pas jusqu'au même score. Le score, ce sont les POINTS
//       du moteur : les passés plus l'humeur qui reste à 18 h
//   E2  ses points sont exactement le « par » écrit, et « trois » ne le dépasse pas
//   E3  le NERVEUX — change dès que quelqu'un attend ailleurs — n'a pas deux
//       étoiles : chaque orange coûte du débit
//   E4  le TÊTU — ne lâche le vert que quand sa file est vide — n'a pas deux
//       étoiles : l'autre côté enrage
//   E5  le meilleur FEU AUTOMATIQUE à cycle fixe (une grille de cycles) n'a
//       pas deux étoiles : regarder le carrefour paie — sinon le joueur
//       n'aurait qu'à régler une minuterie
//   E6  sans jamais le bouton des piétons, le meilleur régulateur perd : la
//       troisième commande est nécessaire
//
// LES INVARIANTS — sur des parties aux gestes au hasard, à chaque pas ; une
// violation est un bug du moteur :
//   I1  rien ne se perd : chaque voiture née est sur sa voie, sortie, ou a
//       fait demi-tour ; chaque piéton né attend, traverse, est passé ou
//       est parti
//   I2  jamais deux axes dans la zone de conflit ; jamais un piéton sur un
//       passage avec un véhicule dans la zone ; personne ne franchit sa
//       ligne d'arrêt sans le vert de son axe
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
const pertes = e => `${e.renonces.reduce((a, b) => a + b, 0)} demi-tours, ${e.renoncesP} piétons partis, tram −${num(e.perte.tram)}, urgences −${num(e.perte.urgences)} ; ${e.changements} changements`;

function donnees(N) {
  const v = [];
  N.vagues.forEach((w, k) => { if (w.de !== (k ? N.vagues[k - 1].a : 0)) v.push(`vague ${k} : commence à ${w.de}`); });
  if (N.vagues[N.vagues.length - 1].a < N.duree) v.push(`les vagues s'arrêtent à ${N.vagues[N.vagues.length - 1].a} s, avant la fin`);
  for (const [nom, l] of [["trams", N.trams], ["urgences", N.urgences]]) l.forEach((h, k) => {
    if (k && h.heure < l[k - 1].heure) v.push(`${nom} hors d'ordre (${k})`);
    if (h.heure >= N.duree) v.push(`${nom} ${k} après la fin`);
  });
  for (const axe of [0, 1]) if (N.voies.filter(x => x.axe === axe).length !== 2) v.push(`axe ${axe} : pas deux voies`);
  if (!(N.quota < N.etoiles.deux && N.etoiles.deux < N.etoiles.trois)) v.push(`étoiles mal ordonnées : ${N.quota} / ${N.etoiles.deux} / ${N.etoiles.trois}`);
  return v;
}

// --- Les régulateurs automates -----------------------------------------------------
// Une politique regarde l'état à chaque pas et rend les gestes à faire.
const HORIZON = N => E.pasDe(N.duree) + 1;
function demandes(N, e, gap) {
  const c = E.C(N), d = [0, 1, 2].map(() => ({ n: 0, vieux: 0, proche: false, gap }));
  N.voies.forEach((v, a) => {
    for (const x of e.voies[a]) if (x.q <= v.approche && x.q >= v.approche - 140) {
      const D = d[v.axe]; D.n++; D.vieux = Math.max(D.vieux, x.arret);
      if (x.q >= v.approche - D.gap) D.proche = true;
    }
  });
  // le tram : dans combien de secondes il sera à sa ligne d'arrêt (l'horaire est affiché au joueur)
  N.trams.forEach((h, i) => {
    const tr = e.trams[i], v = N.voies[E.voieTram(N, h.sens)];
    if (tr.etat === "fini" || tr.q > v.approche) return;
    const dans = tr.etat === "avant" ? h.heure + v.approche / N.vehicule.vitesse - E.heure(e) : (v.approche - tr.q) / N.vehicule.vitesse;
    if (d[1].tram == null || dans < d[1].tram) d[1].tram = dans;
    if (tr.etat === "route") d[1].vieux = Math.max(d[1].vieux, tr.arret);
  });
  N.urgences.forEach((h, i) => {
    const b = e.ambus[i], v = N.voies[h.voie];
    if (b.etat === "route" && b.q <= v.approche) d[v.axe].ambu = true;
  });
  for (const coin of e.attente) for (const p of coin) { d[2].n++; d[2].vieux = Math.max(d[2].vieux, p.arret); }
  void c;
  return d;
}
//   gmin        le vert le plus court (s)
//   gmax        le vert le plus long, [avenue, rue] (s)
//   w           changer si quelqu'un attend en face depuis w s
//   gap         changer si plus personne n'arrive à moins de gap px de la ligne du vert (0 : la file est vide)
//   np, wp      les piétons comptent quand ils sont np, ou que l'un attend depuis wp s
//   tram        avance (s) : donner la rue au tram qui arrive dans moins de tant ; null : il attend comme les autres
//   pietons     false : ne jamais servir les piétons
function regulateur(P) {
  return (N, e) => {
    if (e.etat !== "vert" || e.demande != null) return [];
    const d = demandes(N, e, P.gap), cur = e.phase, g = e.t * E.PAS;
    for (const axe of [0, 1]) if (d[axe].ambu && cur !== axe) return ["feu" + axe];
    if (d[cur].ambu) return [];
    if (P.tram != null && d[1].tram != null && d[1].tram <= P.tram) return cur === 1 ? [] : g >= P.gmin ? ["feu1"] : [];
    if (g < P.gmin) return [];
    const veut = p => p === 2 ? P.pietons !== false && (d[2].n >= P.np || d[2].vieux * E.PAS >= P.wp) : d[p].n > 0;
    const autres = [0, 1, 2].filter(p => p !== cur && veut(p));
    if (!autres.length) return [];
    const vide = cur === 2 || (P.gap ? !d[cur].proche : d[cur].n === 0);
    const presse = autres.some(p => d[p].vieux * E.PAS >= P.w);
    if (!(g >= (cur === 2 ? 0 : P.gmax[cur]) || vide || presse)) return [];
    autres.sort((a, b) => (d[b].vieux + d[b].n * 20) - (d[a].vieux + d[a].n * 20));
    return ["feu" + autres[0]];
  };
}
// le feu automatique : un cycle fixe avenue → rue → piétons, sans regarder
function horloge(av, ru, pi) {
  return (N, e) => {
    if (e.etat !== "vert" || e.demande != null) return [];
    const g = e.t * E.PAS, duree = [av, ru, pi][e.phase];
    return g >= duree ? ["feu" + (e.phase + 1) % 3] : [];
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
// le score : les points d'une partie réussie ; une partie ratée ou perdue passe derrière
const score = e => e.fin && e.fin.fin === "gagne" ? E.points(e) : e.fin && e.fin.fin === "rate" ? -500 + e.passes / 1000 : -1000 + e.passes / 1000;
function meilleur(N, liste, fabrique) {
  let m = null;
  for (const P of liste) {
    const r = jouer(N, fabrique(P)), s = score(r.e);
    if (!m || s > m.s + 1e-9) m = { s, P, ...r };
  }
  return m;
}
function famille(extra = {}) {
  const l = [];
  for (const gmin of [0, 4]) for (const ga of [14, 20, 30]) for (const gr of [8, 12, 18]) for (const w of [10, 18, 30]) for (const gap of [0, 40, 90])
    for (const np of [6, 12]) for (const wp of [10, 20]) for (const tram of [null, 4, 8])
      l.push({ gmin, gmax: [ga, gr], w, gap, np, wp, tram, ...extra });
  return l;
}
const reglage = P => `vert ${P.gmin} s au moins, ${P.gmax[0]} s l'avenue, ${P.gmax[1]} s la rue, attente ${P.w} s, ${P.gap ? "trou de " + P.gap + " px" : "file vide"}, piétons à ${P.np} ou ${P.wp} s, tram ${P.tram == null ? "sans priorité" : "annoncé à " + P.tram + " s"}`;
const NERVEUX = { gmin: 0, gmax: [1e9, 1e9], w: 0, gap: 0, np: 1, wp: 0, tram: null };
const TETU = { gmin: 0, gmax: [1e9, 1e9], w: 1e9, gap: 0, np: 1, wp: 1e9, tram: null };

// --- Les invariants -------------------------------------------------------------
function partie(N, hasard) {
  const c = E.C(N), v = [], e = E.charger(N), journal = [], lim = HORIZON(N);
  let humeur = e.humeur, passes = 0;
  const sortis = N.voies.map(() => 0);
  while (!e.fin && e.k < lim && !v.length) {
    if (hasard() < 0.02) { const g = "feu" + Math.floor(hasard() * 3); if (!E.geste(N, e, g)) journal.push({ k: e.k, g }); }
    const avant = N.voies.map((x, a) => new Map(e.voies[a].map(y => [y.id, y.q])));
    const avantA = e.ambus.map(b => b.q), avantT = e.trams.map(tr => tr.q), vertAvant = [0, 1, 2].map(p => E.vert(e, p));
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
    N.urgences.forEach((h, i) => { const x = N.voies[h.voie]; if (avantA[i] <= x.approche && e.ambus[i].q > x.approche && !E.vert(e, x.axe)) v.push(`I2 ${t} : l'ambulance ${i} passe au rouge`); });
    N.trams.forEach((h, i) => { const x = N.voies[E.voieTram(N, h.sens)]; if (avantT[i] <= x.approche && e.trams[i].q > x.approche && !E.vert(e, 1)) v.push(`I2 ${t} : le tram ${i} passe au rouge`); });
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
  console.log(`\n${N.id} ${N.titre} (${voitures} voitures, ${c.arrP.length} piétons, ${N.trams.length} trams, ${N.urgences.length} ambulances ; quota ${N.quota}, étoiles ${N.etoiles.deux} et ${N.etoiles.trois}, par ${N.par})`);
  const d = donnees(N);
  dire(!d.length, "D1 données" + (d.length ? " :\n      " + d.join("\n      ") : ""));

  const t0 = Date.now(), fam = famille();
  const m = meilleur(N, fam, regulateur);
  const b = rejouer(N, m.journal);
  const ok = m.e.fin && m.e.fin.fin === "gagne" && !b.refus && b.e.fin && E.points(b.e) === E.points(m.e);
  dire(ok, `E1 le meilleur régulateur (${fam.length} essayés, ${Date.now() - t0} ms) : ${fin(m.e)}, ${m.journal.length} gestes\n      ${reglage(m.P)}\n      ${pertes(m.e)}`);
  dire(E.points(m.e) === N.par && N.etoiles.trois <= N.par, `E2 par ${N.par} = meilleurs points ${E.points(m.e)} ; trois étoiles à ${N.etoiles.trois}`);

  const nv = jouer(N, regulateur(NERVEUX)).e;
  dire(score(nv) < N.etoiles.deux, `E3 le nerveux : ${fin(nv)} (${pertes(nv)})`);
  const tt = jouer(N, regulateur(TETU)).e;
  dire(score(tt) < N.etoiles.deux, `E4 le têtu : ${fin(tt)} (${pertes(tt)})`);
  const cycles = [];
  for (const av of [10, 14, 18, 24, 30, 40]) for (const ru of [6, 9, 12, 16, 22]) for (const pi of [0.5, 3, 6]) cycles.push([av, ru, pi]);
  const h = meilleur(N, cycles, ([av, ru, pi]) => horloge(av, ru, pi));
  dire(h.s < N.etoiles.deux, `E5 le meilleur feu automatique (avenue ${h.P[0]} s, rue ${h.P[1]} s, piétons ${h.P[2]} s) : ${fin(h.e)} (${pertes(h.e)})`);
  const sp = meilleur(N, famille({ pietons: false }).filter((P, i) => i % 6 === 0), regulateur);
  dire(sp.e.fin && sp.e.fin.fin === "colere", `E6 sans le bouton des piétons, le meilleur : ${fin(sp.e)}`);
  if (DETAIL) {
    const sansTram = meilleur(N, fam.filter(P => P.tram == null), regulateur);
    console.log(`    détail : sans priorité au tram ${num(score(sansTram.e))} ; arrivées ${voitures} voitures + ${c.arrP.length} piétons + ${N.trams.length * N.compte.tram} en tram`);
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
