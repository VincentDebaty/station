#!/usr/bin/env node
// ------------------------------------------------------------------
// billes-banc — LE BANC D'ESSAI DU PROTOTYPE « BILLES ».
//
//   node tools/billes-banc.mjs                tous les niveaux
//   node tools/billes-banc.mjs --niveau=9     un seul niveau
//   node tools/billes-banc.mjs --detail       les solutions trouvées
//
// Le moteur (prototypes/prototype-billes.html, bloc <script id="moteur">) et
// les niveaux (bloc JSON « niveaux-json ») sont extraits du fichier et joués
// sans navigateur — jamais une copie de l'un ou de l'autre. Le solveur essaie
// TOUTES les façons de poser l'inventaire (case, ordre des pièces, côté de
// départ). Le banc REFUSE (code de sortie 1) au lieu d'avertir.
//
// LES DONNÉES — un niveau mal écrit, avant même de le jouer :
//   D1  5 godets (R, B, J ou « - »), une file non vide dont chaque couleur a
//       son godet, des pièces connues, des cases dans la grille, une cloche
//       ni sur l'entrée ni sous une pièce fixe
//
// LA SOLUTION — ce qui fait d'un niveau un puzzle :
//   S1  il existe une façon de poser tout l'inventaire qui réussit
//   S2  aucune façon de réussir avec MOINS de pièces : chaque pièce sert
//   S3  s'il y a une cloche, au moins une solution la fait sonner, mais pas
//       toutes : l'étoile de la cloche demande un choix
//
// LA RAMPE — la difficulté se mesure, elle ne s'estime pas :
//   R1  la difficulté écrite est la difficulté mesurée : nombre de façons de
//       poser tout l'inventaire ÷ nombre de solutions (arrondi). C'est
//       grossier, mais c'est cette mesure qui a vu que l'ancien niveau à
//       trois couleurs valait 13 fois le précédent (16 octobre 2026)
//   R2  la difficulté ne redescend d'un niveau au suivant que lorsqu'il
//       introduit une pièce (« introduit ») : on apprend, puis ça monte
//
// LES INVARIANTS — sur toutes les poses essayées, une violation est un bug
// du moteur, pas un niveau mal écrit :
//   I1  une partie réussie livre chaque bille de la file, une fois, dans le
//       godet de sa couleur, et ne laisse rien dans les poches
//   I2  la même pose rejouée donne exactement les mêmes trajets
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const FICHIER = "prototypes/prototype-billes.html";
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
for (const a of args) if (!a.startsWith("--")) { console.error("argument inconnu : " + a); process.exit(2); }
const DETAIL = !!opt("detail");

const html = readFileSync(join(RACINE, FICHIER), "utf8");
function bloc(id) {
  const m = html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'));
  if (!m) { console.error("bloc introuvable dans " + FICHIER + " : " + id); process.exit(2); }
  return m[1];
}
const NIVEAUX = JSON.parse(bloc("niveaux-json")).niveaux;
const ctx = createContext({});
runInContext(bloc("moteur") + "\n;globalThis.M = { Machine, jouer, plateau, PIECES, RANGEES, COLONNES, ENTREE };", ctx, { filename: "moteur.js" });
const { Machine, jouer, plateau, PIECES, RANGEES, COLONNES, ENTREE } = ctx.M;

const CASES = [];
for (let r = 0; r < RANGEES; r++) for (let c = 0; c < COLONNES; c++) CASES.push(r + "," + c);

// --- D1 -----------------------------------------------------------------
function donnees(niv) {
  const e = [];
  if (typeof niv.godets !== "string" || niv.godets.length !== COLONNES || /[^RBJ-]/.test(niv.godets)) e.push(`godets « ${niv.godets} » : 5 caractères parmi R, B, J, -`);
  if (!niv.file || /[^RBJ]/.test(niv.file)) e.push(`file « ${niv.file} » : une suite de R, B, J`);
  else for (const c of new Set(niv.file)) if (!niv.godets.includes(c)) e.push(`la couleur ${c} de la file n'a pas de godet`);
  for (const tok in niv.inventaire) if (!PIECES[tok] || !(niv.inventaire[tok] >= 1)) e.push(`inventaire : « ${tok} » ×${niv.inventaire[tok]}`);
  for (const [k, p] of Object.entries(niv.fixes || {})) {
    if (!CASES.includes(k)) e.push(`pièce fixe hors grille : ${k}`);
    if (!["f", "b"].includes(p.t) || ![0, 1].includes(p.d)) e.push(`pièce fixe ${k} : ${JSON.stringify(p)}`);
  }
  if (niv.cloche !== undefined && (!CASES.includes(niv.cloche) || niv.cloche === ENTREE || (niv.fixes || {})[niv.cloche])) e.push(`cloche mal placée : ${niv.cloche}`);
  if (niv.introduit !== undefined && !(niv.introduit in niv.inventaire)) e.push(`introduit « ${niv.introduit} » absent de l'inventaire`);
  if (!Number.isInteger(niv.difficulte)) e.push(`difficulté non écrite`);
  return e;
}

// --- le solveur -----------------------------------------------------------
function* combinaisons(t, k, d = 0, acc = []) {
  if (acc.length === k) { yield acc.slice(); return; }
  for (let i = d; i < t.length; i++) { acc.push(t[i]); yield* combinaisons(t, k, i + 1, acc); acc.pop(); }
}
function ordres(jetons) {
  if (!jetons.length) return [[]];
  const vus = new Set();
  (function p(reste, acc) {
    if (!reste.length) { vus.add(acc.join("|")); return; }
    for (let i = 0; i < reste.length; i++) p(reste.slice(0, i).concat(reste.slice(i + 1)), acc.concat(reste[i]));
  })(jetons, []);
  return [...vus].map(s => s.split("|"));
}
// Toutes les poses de ces jetons ; rappel(poses) pour chacune.
function poses(niv, jetons, rappel) {
  const libres = CASES.filter(k => !(niv.fixes || {})[k] && k !== niv.cloche);
  for (const cases of combinaisons(libres, jetons.length))
    for (const ordre of ordres(jetons)) {
      const cotes = ordre.map(t => PIECES[t].t === "p" ? 1 : 2), total = cotes.reduce((a, b) => a * b, 1);
      for (let n = 0; n < total; n++) {
        let x = n; const p = new Map();
        cases.forEach((k, i) => { p.set(k, { tok: ordre[i], d: x % cotes[i] }); x = Math.floor(x / cotes[i]); });
        rappel(p);
      }
    }
}
const ecrire = p => [...p].map(([k, v]) => `${k}:${v.tok}${PIECES[v.tok].t === "p" ? "" : v.d ? "→" : "←"}`).join(" ");
function trajets(niv, pieces) {
  const m = Machine(niv, pieces), out = [];
  for (const c of niv.file) { out.push(...m.lacher(c)); if (!m.ok) break; }
  out.push(...m.vider());
  return { m, out };
}
function resoudre(niv) {
  const inv = Object.entries(niv.inventaire).flatMap(([t, n]) => Array(n).fill(t));
  const r = { poses: 0, solutions: [], avecCloche: 0, moins: null, invariants: [] };
  poses(niv, inv, p => {
    r.poses++;
    const pieces = plateau(niv, p), j = jouer(niv, pieces);
    // I1 et I2, sur chaque pose
    const a = trajets(niv, plateau(niv, p)), b = trajets(niv, plateau(niv, p));
    if (JSON.stringify(a.out) !== JSON.stringify(b.out) && r.invariants.length < 3) r.invariants.push(`I2 : ${ecrire(p)} ne se rejoue pas à l'identique`);
    if (j.ok) {
      const livr = a.out.filter(t => t.end === "cup").map(t => t.c).sort().join(""), file = [...niv.file].sort().join("");
      const tenu = [...a.m.s.values()].some(v => v.t === "p" && v.h !== null);
      if ((livr !== file || tenu || a.out.some(t => t.end === "cup" && niv.godets[t.col] !== t.c)) && r.invariants.length < 3)
        r.invariants.push(`I1 : ${ecrire(p)} réussit sans livrer exactement la file (${livr} pour ${file})`);
      r.solutions.push({ p, cloche: j.cloche });
      if (j.cloche) r.avecCloche++;
    }
  });
  // S2 : chaque sous-inventaire strict
  const sous = new Set();
  for (let masque = 0; masque < (1 << inv.length) - 1; masque++) sous.add(inv.filter((_, i) => masque >> i & 1).sort().join("|"));
  for (const s of sous) {
    if (r.moins) break;
    const jetons = s ? s.split("|") : [];
    poses(niv, jetons, p => { if (!r.moins && jouer(niv, plateau(niv, p)).ok) r.moins = p; });
  }
  return r;
}

// --- le banc ---------------------------------------------------------------
const choix = opt("niveau") ? [+opt("niveau") - 1] : NIVEAUX.map((_, i) => i);
const refus = [];
let precedente = null;
console.log("niveau  pièces        poses  solutions  cloche  difficulté (écrite)");
for (let i = 0; i < NIVEAUX.length; i++) {
  const niv = NIVEAUX[i], nom = `niveau ${i + 1}`;
  const d = donnees(niv);
  if (d.length) { refus.push(...d.map(x => `${nom} D1 : ${x}`)); continue; }
  if (!choix.includes(i)) { precedente = niv.difficulte; continue; }
  const r = resoudre(niv);
  const n = r.solutions.length, mesure = n ? Math.round(r.poses / n) : null;
  const inv = Object.entries(niv.inventaire).map(([t, k]) => k > 1 ? `${t}×${k}` : t).join("+");
  console.log(`${String(i + 1).padStart(6)}  ${inv.padEnd(12)} ${String(r.poses).padStart(6)}  ${String(n).padStart(9)}  ${niv.cloche ? String(r.avecCloche).padStart(6) : "     –"}  ${String(mesure ?? "–").padStart(10)} (${niv.difficulte})`);
  if (DETAIL) for (const s of r.solutions) console.log(`          ${ecrire(s.p)}${s.cloche ? "  + cloche" : ""}`);
  if (!n) refus.push(`${nom} S1 : aucune solution`);
  if (r.moins) refus.push(`${nom} S2 : réussit avec moins de pièces (${ecrire(r.moins) || "aucune pièce"})`);
  if (niv.cloche && n && (r.avecCloche === 0 || r.avecCloche === n)) refus.push(`${nom} S3 : la cloche sonne dans ${r.avecCloche} solution(s) sur ${n}`);
  if (mesure !== null && mesure !== niv.difficulte) refus.push(`${nom} R1 : difficulté écrite ${niv.difficulte}, mesurée ${mesure}`);
  if (precedente !== null && niv.difficulte < precedente && !niv.introduit) refus.push(`${nom} R2 : la difficulté redescend (${precedente} → ${niv.difficulte}) sans pièce nouvelle`);
  refus.push(...r.invariants.map(x => `${nom} ${x}`));
  precedente = niv.difficulte;
}
if (refus.length) { console.error("\nREFUS :\n  " + refus.join("\n  ")); process.exit(1); }
console.log(`\n${choix.length} niveau${choix.length > 1 ? "x" : ""} : données, solutions, rampe et invariants tenus.`);
