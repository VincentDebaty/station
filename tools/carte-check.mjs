#!/usr/bin/env node
// ------------------------------------------------------------------
// carte-check — LA SEULE AUTORITÉ SUR LES RÈGLES DE CARTE.
// ------------------------------------------------------------------
// Une carte est un RUBAN : une suite ordonnée de gares, sans embranchement et
// sans choix (meta-progression-jeu-aiguillage.md §0). Ce contrôle vérifie les
// règles R1 à R9 du §3, plus R10 — la rampe contre les brevets des fiches
// (tools/brevet.mjs) — et REFUSE — code de sortie ≠ 0 — plutôt qu'il n'avertit.
// Une règle qu'on ne mesure pas est une intention, pas une règle.
//
//   node tools/carte-check.mjs [--carte=europe] [--detail] [--resume]
//
// UNE CARTE EN CHANTIER (`enChantier: true` dans le JSON) relâche les deux
// règles de COMPLÉTUDE — R2 (longueur) et R4 (taille des zones) — qui parlent
// d'une carte finie. Les règles de CORRECTION (R1, R3, R5 à R9) ne se
// relâchent jamais : elles disent si ce qui est écrit est juste.
// ------------------------------------------------------------------
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { empreinte } from "./empreinte.mjs";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
const DETAIL = !!opt("detail"), RESUME = !!opt("resume");
const CARTE_ID = opt("carte") || "europe";
for (const a of args) if (!a.startsWith("--")) { console.error("argument inconnu : " + a); process.exit(2); }

const lire = p => JSON.parse(readFileSync(join(RACINE, p), "utf8"));
const carte = lire("data/cartes/" + CARTE_ID + ".json");
const chapitres = carte.chapitres || [];
const zones = carte.zones || [];
const chantier = !!carte.enChantier;

// --- Le catalogue : quelles fiches existent, et ce qu'elles portent --------
const index = lire("data/stations/index.json");
const FICHES = new Map();
for (const pays of index)
  for (const id of pays.stations) {
    const p = join(RACINE, "data/stations", pays.country, id + ".json");
    if (existsSync(p)) FICHES.set(id, lire("data/stations/" + pays.country + "/" + id + ".json"));
  }
const quais = id => ((FICHES.get(id) || {}).platforms || []).length;
// LE MODÈLE DE DIFFICULTÉ VIENT DU JEU, JAMAIS D'UNE COPIE. Ce fichier
// portait sa propre formule de plafond (`quais - 1`) pendant que js/ruban.js
// apprenait le terme des directions (26 août), le palier de quais (26 août)
// puis l'entonnoir (27 août) : R8 et R9 jugeaient la rampe avec un plafond
// que le jeu ne sert plus. On évalue donc js/ruban.js — un script classique,
// comme js/geo.js plus bas — et on lui donne le `cardOf` qu'il attend, pour
// que `arriveeDeChapitre` lise les vraies fiches au lieu de son repli.
const RUBAN_FNS = (() => {
  const src = readFileSync(join(RACINE, "js/ruban.js"), "utf8");
  const fn = new Function("cardOf", src +
    "\n;return { plafondDeFlux, plancherDeChapitre, arriveeDeChapitre, difficulteVoulue };");
  return fn(id => FICHES.get(id) || null);
})();
const plafond = id => FICHES.has(id) ? RUBAN_FNS.plafondDeFlux(FICHES.get(id)) : 1;
const nom = id => { const f = FICHES.get(id); return f ? (f.city || f.name || id) : id; };

// --- Le réseau réel, pour la continuité (R5) et la sinuosité (R7) ---------
// `js/geo.js` et `data/places.js` sont des scripts classiques : on les évalue
// dans un bac à sable minimal plutôt que d'en réécrire un analyseur.
function charger(fichier, globales) {
  const src = readFileSync(join(RACINE, fichier), "utf8");
  const fn = new Function(src + "\n;return {" + globales.map(g => g + ":typeof " + g + '!=="undefined"?' + g + ":null").join(",") + "};");
  try { return fn(); } catch { return {}; }
}
const { GEO } = charger("js/geo.js", ["GEO"]);
// GEO.countries est un objet { pays: { cities: { id: [lon, lat] } } }.
const COORD = new Map();
if (GEO && GEO.countries)
  for (const pays of Object.values(GEO.countries))
    for (const [id, ll] of Object.entries(pays.cities || {}))
      if (Array.isArray(ll) && ll.length === 2) COORD.set(id, ll);

// --- Le rapport -----------------------------------------------------------
const regles = [];
function R(id, titre, ok, dit, dur = true) {
  regles.push({ id, titre, ok, dit, dur: dur && !(chantier && (id === "R2" || id === "R4")) });
}
const listes = {};

// R1 — LA CARTE EST UN RUBAN UNIQUE.
// Une suite ordonnée, sans embranchement : chaque gare a exactement une
// suivante. Ce qui se mesure, c'est qu'aucune gare n'apparaisse deux fois et
// qu'aucun chapitre ne soit vide — un ruban n'a ni fourche ni trou.
const vues = new Map(), doublons = [];
let vide = 0;
for (const ch of chapitres) {
  if (!ch.gares || !ch.gares.length) { vide++; continue; }
  for (const g of ch.gares) {
    if (vues.has(g)) doublons.push({ gare: g, a: vues.get(g), b: ch.id });
    else vues.set(g, ch.id);
  }
}
const ordre = [...vues.keys()];
R("R1", "ruban unique, sans embranchement", !doublons.length && !vide,
  doublons.length ? doublons.length + " gare(s) en double" : vide ? vide + " chapitre(s) vide(s)" : ordre.length + " gares en une seule suite");
listes.R1 = doublons.map(d => `${d.gare} : ${d.a} et ${d.b}`);

// R2 — ≥ 60 GARES ET ≥ 8 CHAPITRES.
R("R2", "≥ 60 gares et ≥ 8 chapitres", ordre.length >= 60 && chapitres.length >= 8,
  `${chapitres.length} chapitres · ${ordre.length} gares`);

// R3 — UN CHAPITRE COMPTE 5 À 10 GARES, la dernière étant une grande gare.
const horsR3 = chapitres.filter(c => !c.gares || c.gares.length < 5 || c.gares.length > 10);
R("R3", "chapitre de 5 à 10 gares", !horsR3.length,
  horsR3.length ? horsR3.length + " chapitre(s) hors fourchette" : "tous entre 5 et 10");
listes.R3 = horsR3.map(c => `${c.id} : ${(c.gares || []).length} gares`);

// R4 — UNE ZONE COMPTE 6 À 20 CHAPITRES, la carte en a ≥ 2, et l'écart entre
// la plus courte et la plus longue reste sous 3 pour 1.
const parZone = new Map();
for (const ch of chapitres) parZone.set(ch.zone, (parZone.get(ch.zone) || 0) + 1);
const tailles = [...parZone.values()];
const ecart = tailles.length ? Math.max(...tailles) / Math.min(...tailles) : 0;
const zonesHors = [...parZone.entries()].filter(([, n]) => n < 6 || n > 20);
R("R4", "zones de 6 à 20 chapitres, écart < 3 pour 1",
  zones.length >= 2 && !zonesHors.length && ecart < 3,
  `${zones.length} zones · ${tailles.join("/")} chapitres · écart ${ecart.toFixed(2)} pour 1`);
listes.R4 = zonesHors.map(([z, n]) => `${z} : ${n} chapitres`);

// R5 — CONTINUITÉ RÉELLE. Deux gares consécutives d'un même chapitre sont
// voisines sur une ligne réelle ; une rupture n'est tolérée qu'ENTRE deux
// chapitres, et seulement si un `saut` est déclaré.
//
// La mesure : la distance à vol d'oiseau entre deux gares consécutives. Un
// écart supérieur à 250 km à l'intérieur d'un chapitre n'est plus une portée
// de rail, c'est un trou. On ne se prononce que sur les gares dont on a les
// coordonnées — le reste est signalé, pas condamné.
const RAD = Math.PI / 180;
function km(a, b) {
  const A = COORD.get(a), B = COORD.get(b);
  if (!A || !B) return null;
  const dx = (B[0] - A[0]) * Math.cos((A[1] + B[1]) / 2 * RAD) * 111.32, dy = (B[1] - A[1]) * 110.57;
  return Math.hypot(dx, dy);
}
// SAUF PORTÉE DÉCLARÉE (28 août 2026, sur le modèle de la sinuosité de R7) :
// certains rails réels franchissent plus de 250 km sans une seule gare que le
// §0 accepte — la LAV de Galice survole la Sanabria (Ourense → Medina del
// Campo, 270 km mesurés), ses arrêts n'ayant que deux directions. Un chapitre
// peut donc ASSUMER une portée en la déclarant (`portees`, liste de
// `[de, vers, km]`), et la règle vérifie contre la valeur déclarée. Une
// portée non déclarée reste un trou, une déclaration devenue inutile
// (mesure repassée sous 250) est signalée pour être retirée.
const trous = [], porteesInutiles = [], sansCoord = new Set();
let nPortees = 0;
for (const ch of chapitres)
  for (let i = 1; i < (ch.gares || []).length; i++) {
    const d = km(ch.gares[i - 1], ch.gares[i]);
    if (d == null) { sansCoord.add(ch.gares[i - 1]); sansCoord.add(ch.gares[i]); continue; }
    const decl = (ch.portees || []).find(p => p[0] === ch.gares[i - 1] && p[1] === ch.gares[i]);
    if (decl) {
      nPortees++;
      if (d > decl[2]) trous.push(`${ch.id} : ${nom(ch.gares[i - 1])} → ${nom(ch.gares[i])} = ${Math.round(d)} km (déclarée ${decl[2]})`);
      else if (d <= 250) porteesInutiles.push(`${ch.id} : ${nom(ch.gares[i - 1])} → ${nom(ch.gares[i])} mesurée ${Math.round(d)} km — retirer la déclaration`);
      continue;
    }
    if (d > 250) trous.push(`${ch.id} : ${nom(ch.gares[i - 1])} → ${nom(ch.gares[i])} = ${Math.round(d)} km`);
  }
R("R5", "continuité réelle à l'intérieur des chapitres", !trous.length,
  trous.length ? trous.length + " saut(s) non déclaré(s)" :
    `aucun trou (${nPortees ? nPortees + " portée(s) déclarée(s), " : ""}${sansCoord.size} gare(s) sans coordonnées, non jugées)`);
listes.R5 = [...trous, ...porteesInutiles];

// R6 — UNE FICHE N'APPARAÎT QU'UNE FOIS, et l'on ne réemprunte jamais un
// tracé déjà parcouru. Le doublon de fiche est mesuré en R1 ; ce qui reste
// ici, c'est le retour dans une VILLE : permis, mais seulement par une autre
// gare réelle. Deux gares de la même ville portent des `city` identiques.
const parVille = new Map();
for (const g of ordre) {
  const f = FICHES.get(g);
  if (!f || !f.city) continue;
  if (!parVille.has(f.city)) parVille.set(f.city, []);
  parVille.get(f.city).push(g);
}
const retours = [...parVille.entries()].filter(([, gs]) => gs.length > 1);
R("R6", "une fiche une fois ; retour en ville par une autre gare", true,
  retours.length ? retours.length + " ville(s) revisitée(s), par des gares distinctes" : "aucun retour en ville");
listes.R6 = retours.map(([v, gs]) => `${v} : ${gs.join(", ")}`);

// R7 — SINUOSITÉ ≤ 1,5. La longueur cumulée d'un chapitre, rapportée au vol
// d'oiseau entre sa première et sa dernière gare. Au-delà, le chapitre a
// quitté sa ligne réelle.
//
// SAUF SINUOSITÉ DÉCLARÉE (28 août 2026) : certains rails réels serpentent —
// le tour de la botte avant le détroit de Messine mesure 1,73, la diagonale
// ionienne de Lucanie 1,62, et ce sont bien les lignes réelles. Un chapitre
// peut donc ASSUMER sa sinuosité en la déclarant (`sinuosite`), sur le modèle
// de `arrivee` pour R9 : la règle vérifie alors contre la valeur déclarée.
// L'exception est écrite dans la carte, visible ici, et bornée — une
// sinuosité non déclarée au-dessus de 1,5 reste un refus, et une déclaration
// devenue inutile (mesure repassée sous 1,5) est signalée pour être retirée.
const sinueux = [], declarationsInutiles = [];
for (const ch of chapitres) {
  const g = ch.gares || [];
  if (g.length < 2) continue;
  let cum = 0, complet = true;
  for (let i = 1; i < g.length; i++) { const d = km(g[i - 1], g[i]); if (d == null) { complet = false; break; } cum += d; }
  const vol = km(g[0], g[g.length - 1]);
  if (!complet || !vol) continue;
  const s = cum / vol;
  const tolere = ch.sinuosite || 1.5;
  if (s > tolere) sinueux.push(`${ch.id} : ${s.toFixed(2)} (${Math.round(cum)} km pour ${Math.round(vol)} à vol d'oiseau${ch.sinuosite ? `, déclarée ${ch.sinuosite}` : ""})`);
  else if (ch.sinuosite && s <= 1.5) declarationsInutiles.push(`${ch.id} : déclarée ${ch.sinuosite}, mesurée ${s.toFixed(2)} — retirer la déclaration`);
}
const nDeclares = chapitres.filter(c => c.sinuosite).length;
R("R7", "sinuosité ≤ 1,5 par chapitre (sauf déclarée)", !sinueux.length,
  sinueux.length ? sinueux.length + " chapitre(s) trop sinueux" :
    nDeclares ? `tous dans leur borne (${nDeclares} déclarée(s))` : "tous sous 1,5");
listes.R7 = [...sinueux, ...declarationsInutiles];

// R8 — LA DIFFICULTÉ PORTABLE CROÎT LE LONG DU CHAPITRE, et la grande gare
// finale est la plus haute. AVERTISSEMENT et non erreur : la géométrie a le
// dernier mot, et une gare qui ne peut pas monter ne se réécrit pas.
const rampes = [];
for (const ch of chapitres) {
  const g = (ch.gares || []).filter(x => FICHES.has(x));
  if (g.length < 2) continue;
  const fin = plafond(g[g.length - 1]);
  const plusHaut = Math.max(...g.map(plafond));
  if (fin < plusHaut) rampes.push(`${ch.id} : arrivée ${nom(g[g.length - 1])} plafonne à ${fin}, une gare du chapitre monte à ${plusHaut}`);
}
R("R8", "la difficulté croît vers la grande gare", !rampes.length,
  rampes.length ? rampes.length + " chapitre(s) dont l'arrivée n'est pas le sommet" : "l'arrivée est le sommet partout", false);
listes.R8 = rampes;

// R9 — LE PREMIER CHAPITRE EST DOUX : sa première gare se joue en 1 et son
// arrivée ne dépasse pas 3. C'est le tutoriel, et il n'a pas de deuxième chance.
const c1 = chapitres[0];
let ditR9 = "aucun chapitre", okR9 = false;
if (c1 && c1.gares && c1.gares.length) {
  const p1 = plancher(c1);
  // L'arrivée VOULUE : ce que le chapitre déclare, sinon ce que sa grande gare
  // peut porter. C'est celle-là que R9 juge — pas la taille du bâtiment.
  const a1 = Math.min(5, c1.arrivee || plafond(c1.gares[c1.gares.length - 1]));
  okR9 = p1 === 1 && a1 <= 3;
  ditR9 = `${c1.nom} : plancher ${p1}, arrivée ${a1}` + (a1 > 3 ? " (au-dessus de 3)" : "");
}
function plancher(ch) { return ch.plancher || Math.max(1, Math.min(4, 1 + Math.floor(chapitres.indexOf(ch) / 3))); }
R("R9", "premier chapitre doux (plancher 1, arrivée ≤ 3)", okR9, ditR9);

// R10 — LA RAMPE NE DÉPASSE LE BREVET DE PERSONNE.
// Chaque fiche porte un brevet (tools/brevet.mjs) : le niveau maximal auquel
// elle a été mesurée saine, une fois pour toutes, sur une batterie de graines
// fixes. La carte, elle, décide du niveau que chaque gare JOUE — la rampe du
// chapitre, rabattue par le plafond de la géométrie. Cette règle croise les
// deux, et c'est elle qui rend l'extension d'une carte instantanée : plus
// besoin de re-balayer 86 gares au tirage aléatoire pour savoir si la
// nouvelle rampe demande à quelqu'un plus qu'il ne porte. Née le 27 août
// 2026, quand l'acte V greffé devant le ruban a servi à Colmar une enveloppe
// que sa correction d'août — endormie dans un `gen` que le ruban ne joue
// plus — ne couvrait pas : une file de 6, découverte au hasard d'une graine.
//
// Trois verdicts : une gare qui joue AU-DESSUS de son brevet est une erreur
// dure ; une gare sans brevet, ou dont la fiche a changé depuis le sien, est
// un avertissement (lancer tools/brevet.mjs) ; brevets.json absent, la règle
// s'abstient — elle avertit sans condamner une carte qu'on n'a pas mesurée.
let brevets = null;
try { brevets = lire("data/stations/brevets.json"); } catch { /* pas encore certifié */ }
const depasse = [], sansBrevet = [], perime = [];
if (brevets) {
  chapitres.forEach((ch, rang) => {
    const g = ch.gares || [];
    const ch2 = { rang, plancher: ch.plancher, arrivee: ch.arrivee, gares: g };
    const p = RUBAN_FNS.plancherDeChapitre(ch2), a = RUBAN_FNS.arriveeDeChapitre(ch2);
    g.forEach((id, i) => {
      const f = FICHES.get(id);
      if (!f) return;                                    // fiche à écrire : mesurée ailleurs
      const b = brevets[id];
      if (!b || typeof b !== "object") { sansBrevet.push(id); return; }
      if (b.geometrie !== empreinte(f)) { perime.push(id); return; }
      const joue = Math.max(1, Math.min(RUBAN_FNS.difficulteVoulue(i, g.length, p, a), plafond(id)));
      // La grande gare d'un chapitre joue le régime BOSS quand la rampe
      // l'amène à 5 (estBoss, js/ruban.js) — c'est le brevet boss qui juge.
      if (i === g.length - 1 && joue === 5) {
        if (b.boss !== "OK") depasse.push(`${ch.id} : ${nom(id)} ferme en boss, brevet boss « ${b.boss || "non mesuré"} »`);
      } else if (joue > (b.niveau || 0))
        depasse.push(`${ch.id} : ${nom(id)} joue ${joue}, brevet ${b.niveau || 0}`);
    });
  });
  const dit = depasse.length ? depasse.length + " gare(s) au-dessus de leur brevet"
    : (sansBrevet.length || perime.length)
      ? `${sansBrevet.length} sans brevet, ${perime.length} périmé(s) — lancer tools/brevet.mjs`
      : "toutes les gares jouent sous leur brevet";
  R("R10", "la rampe ne dépasse le brevet de personne", !depasse.length && !sansBrevet.length && !perime.length,
    dit, depasse.length > 0);
  listes.R10 = [...depasse, ...sansBrevet.map(id => nom(id) + " : sans brevet"), ...perime.map(id => nom(id) + " : brevet périmé")];
} else {
  R("R10", "la rampe ne dépasse le brevet de personne", false,
    "pas de brevets.json — lancer tools/brevet.mjs pour certifier le catalogue", false);
}

// --- Ce qui reste à écrire ------------------------------------------------
const aEcrire = ordre.filter(g => !FICHES.has(g));
const premiereAVenir = ordre.findIndex(g => !FICHES.has(g));
const jouables = premiereAVenir < 0 ? ordre.length : premiereAVenir;

// --- Sortie ---------------------------------------------------------------
const dur = regles.filter(r => r.dur && !r.ok);
const mou = regles.filter(r => !r.dur && !r.ok);
if (RESUME) {
  console.log(`carte-check — ${carte.nom} : ${chapitres.length} chapitres · ${ordre.length} gares · ` +
    `${jouables} jouables · ${dur.length ? "✘ " + dur.length + " règle(s)" : "✔"}${mou.length ? " · ⚠ " + mou.length : ""}`);
  process.exit(dur.length ? 1 : 0);
}
console.log(`\ncarte-check — ${carte.nom}${chantier ? "  (en chantier)" : ""}`);
console.log("-".repeat(74));
for (const r of regles) {
  const marque = r.ok ? "✔" : (r.dur ? "✘" : "⚠");
  console.log(`  ${marque} ${r.id.padEnd(3)} ${r.titre.padEnd(44)} ${r.dit}`);
  if ((DETAIL || !r.ok) && (listes[r.id] || []).length)
    for (const l of listes[r.id].slice(0, DETAIL ? 99 : 8)) console.log("        · " + l);
}
console.log("-".repeat(74));
console.log(`  ruban      ${ordre.length} gares · ${jouables} jouables d'affilée · ${aEcrire.length} fiches à écrire`);
if (aEcrire.length && (DETAIL || aEcrire.length <= 12))
  console.log("             " + aEcrire.join(", "));
if (chantier) console.log("  chantier   R2 et R4 sont informatives : la carte n'est pas encore complète.");
console.log();
process.exit(dur.length ? 1 : 0);
