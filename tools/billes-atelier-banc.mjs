#!/usr/bin/env node
// ------------------------------------------------------------------
// billes-atelier-banc — LE BANC DE « L'ATELIER À BILLES ».
//
//   node tools/billes-atelier-banc.mjs                  les niveaux de la page
//   node tools/billes-atelier-banc.mjs mes-niveaux.json niveaux exportés de
//                                                        l'éditeur (un niveau,
//                                                        ou une liste)
//   node tools/billes-atelier-banc.mjs --detail         le trajet de chaque bille
//
// Le moteur (prototypes/prototype-billes-atelier.html, bloc <script
// id="moteur">) et les niveaux de démonstration (bloc JSON « niveaux-json »)
// sont extraits du fichier et joués sans navigateur — jamais une copie de
// l'un ou de l'autre. Le banc REFUSE (code de sortie 1) au lieu d'avertir.
//
// Une grille peut aller jusqu'à 12 × 24 : on ne fouille plus TOUTES les
// poses, comme le faisait billes-banc.mjs sur 4 × 5. Le niveau porte sa
// solution (tous ses modules) ; le banc vérifie qu'elle tient et que chaque
// pièce laissée au joueur sert à quelque chose. Ce sont les questions que
// l'éditeur pose lui-même, en direct, sous la grille.
//
// LES DONNÉES — D1 : defauts() du moteur ne trouve rien (dimensions, entrée,
// godets, file, modules dans la grille, un seul par case).
//
// LA SOLUTION :
//   S1  avec tous ses modules, le niveau réussit
//   S2  il reste au moins une pièce à poser, et le niveau ne se gagne pas
//       avec les seules pièces fixes
//   S3  retirer n'importe quelle pièce à poser fait échouer le niveau :
//       chacune sert
//
// LES INVARIANTS — une violation est un bug du moteur :
//   I1  la même pose rejouée donne exactement les mêmes trajets
//   I2  chaque trajet est fait de pas d'une case (deux pour un saut, une
//       pile entière pour un ascenseur), sans téléportation
//   I3  l'élan reste entre 0 et ELAN_MAX
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const FICHIER = "prototypes/prototype-billes-atelier.html";
const args = process.argv.slice(2);
const DETAIL = args.includes("--detail");
const fichiers = args.filter(a => !a.startsWith("--"));
for (const a of args) if (a.startsWith("--") && a !== "--detail") { console.error("option inconnue : " + a); process.exit(2); }

const html = readFileSync(join(RACINE, FICHIER), "utf8");
function bloc(id) {
  const m = html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'));
  if (!m) { console.error("bloc introuvable dans " + FICHIER + " : " + id); process.exit(2); }
  return m[1];
}
const ctx = createContext({});
runInContext(bloc("moteur") + "\n;globalThis.A = { Machine, jouer, defauts, MODULES, ELAN_MAX };", ctx, { filename: "moteur.js" });
const { jouer, defauts, MODULES, ELAN_MAX } = ctx.A;

let niveaux = JSON.parse(bloc("niveaux-json")).niveaux.map(n => ({ ...n, _de: "page" }));
if (fichiers.length) {
  niveaux = [];
  for (const f of fichiers) {
    const lu = JSON.parse(readFileSync(f, "utf8"));
    for (const n of Array.isArray(lu) ? lu : lu.niveaux || [lu]) niveaux.push({ ...n, _de: f });
  }
}

function invariants(niv, r) {
  const v = [];
  for (const t of r.trajets) for (let i = 0; i < t.pts.length; i++) {
    const p = t.pts[i];
    if (!(p.v >= 0 && p.v <= ELAN_MAX)) v.push(`I3 : bille ${t.c}, élan ${p.v} en (${p.x},${p.y})`);
    if (!i) continue;
    const q = t.pts[i - 1], dx = Math.abs(p.x - q.x), dy = Math.abs(p.y - q.y);
    const permis = p.ev === "saut" ? dx === 2 && dy === 0 : p.ev === "monte" ? dx === 0 && dy === 1 : dx <= 1 && dy <= 1 && dx + dy >= 1;
    if (!permis) v.push(`I2 : bille ${t.c}, pas de (${q.x},${q.y}) à (${p.x},${p.y})`);
  }
  return v.slice(0, 3);
}
const ecrire = t => t.pts.map(p => `${p.x},${p.y}:${p.v}${p.ev ? "(" + p.ev + ")" : ""}`).join(" ") + ` → ${t.fin}${t.col !== undefined ? " " + t.col : ""}${t.ok ? "" : " ✗"}`;

const refus = [];
console.log("niveau                    grille  billes  modules  à poser");
for (const niv of niveaux) {
  const nom = `« ${niv.nom || "sans nom"} »`;
  niv.modules = niv.modules || [];
  const d = defauts(niv);
  if (d.length) { refus.push(...d.map(x => `${nom} D1 : ${x}`)); continue; }
  const aposer = niv.modules.filter(q => !q.fixe);
  console.log(`${(niv.nom || "sans nom").slice(0, 24).padEnd(24)}  ${(niv.largeur + "×" + niv.hauteur).padStart(6)}  ${String(niv.file.length).padStart(6)}  ${String(niv.modules.length).padStart(7)}  ${String(aposer.length).padStart(7)}`);
  const r = jouer(niv);
  if (DETAIL) for (const t of r.trajets) console.log("    " + t.c + " " + ecrire(t));
  if (!r.ok) { const t = r.trajets[r.trajets.length - 1]; refus.push(`${nom} S1 : la solution échoue, bille ${t.c} n° ${r.trajets.length} → ${t.fin}`); }
  if (!aposer.length) refus.push(`${nom} S2 : aucune pièce à poser`);
  else if (jouer(niv, niv.modules.filter(q => q.fixe)).ok) refus.push(`${nom} S2 : se gagne sans rien poser`);
  if (r.ok) for (const q of aposer)
    if (jouer(niv, niv.modules.filter(z => z !== q)).ok) refus.push(`${nom} S3 : ${MODULES[q.t].nom} (${q.x},${q.y}) ne sert à rien`);
  if (JSON.stringify(jouer(niv).trajets) !== JSON.stringify(r.trajets)) refus.push(`${nom} I1 : la solution ne se rejoue pas à l'identique`);
  refus.push(...invariants(niv, r).map(x => `${nom} ${x}`));
}
if (refus.length) { console.error("\nREFUS :\n  " + refus.join("\n  ")); process.exit(1); }
console.log(`\n${niveaux.length} niveau${niveaux.length > 1 ? "x" : ""} : données, solutions, pièces utiles et invariants tenus.`);
