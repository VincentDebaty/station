// ------------------------------------------------------------------
// boutique-check — CE QUI SE VEND EST-IL CE QU'ON A DÉCIDÉ DE VENDRE ?
//
//     node tools/boutique-check.mjs
//
// La seule autorité sur data/boutique.json (economie-du-jeu.md §6, lot 3).
// Quatre règles, et il REFUSE (code de sortie ≠ 0) :
//
//   B1  chaque offre a un id unique, un `produit` unique (l'identifiant du
//       magasin de la plateforme), un type parmi carte / pack, un prix
//       affiché « N,NN € », et une phrase `dit`.
//   B2  une offre de carte vise une carte de l'index qui n'est PAS gratuite ;
//       toute carte payante a EXACTEMENT une offre. La première carte est
//       gratuite et complète : elle ne se vend pas.
//   B3  au plus un pack.
//   B4  CE QUI NE SE VEND JAMAIS : aucune offre ne porte `pieces`, `pierres`,
//       `diamants`, `etoiles`, `rang`, `medaille`, `temps`, `vies`. Vendre des
//       pièces viderait la boucle « retourner dorer », qui est le jeu ; les
//       pierres ont été essayées et retirées le 10 septembre 2026 (Vincent :
//       « pas une bonne idée »). Le contenu se vend, jamais la progression.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const lire = p => JSON.parse(readFileSync(join(RACINE, p), "utf8"));
const boutique = lire("data/boutique.json");
const index = lire("data/cartes/index.json");

const offres = Array.isArray(boutique.offres) ? boutique.offres : [];
const echecs = [];
const euros = s => { const m = /^(\d+),(\d\d) €$/.exec(String(s)); return m ? Number(m[1]) + Number(m[2]) / 100 : NaN; };

// B1
const ids = new Set(), produits = new Set();
for (const o of offres) {
  if (!o.id || ids.has(o.id)) echecs.push(`B1 id manquant ou en double : ${JSON.stringify(o.id)}`);
  ids.add(o.id);
  if (!o.produit || produits.has(o.produit)) echecs.push(`B1 ${o.id} : produit manquant ou en double`);
  produits.add(o.produit);
  if (!["carte", "pack"].includes(o.type)) echecs.push(`B1 ${o.id} : type inconnu ${JSON.stringify(o.type)}`);
  if (Number.isNaN(euros(o.prix))) echecs.push(`B1 ${o.id} : prix illisible ${JSON.stringify(o.prix)} (attendu « N,NN € »)`);
  if (!o.dit) echecs.push(`B1 ${o.id} : pas de phrase`);
}
// B2
const payantes = index.filter(e => !e.gratuite).map(e => e.id);
for (const o of offres.filter(o => o.type === "carte")) {
  const e = index.find(x => x.id === o.carte);
  if (!e) echecs.push(`B2 ${o.id} : carte inconnue ${JSON.stringify(o.carte)}`);
  else if (e.gratuite) echecs.push(`B2 ${o.id} : ${o.carte} est gratuite, elle ne se vend pas`);
}
for (const id of payantes) {
  const n = offres.filter(o => o.type === "carte" && o.carte === id).length;
  if (n !== 1) echecs.push(`B2 la carte payante ${id} a ${n} offre(s), il en faut exactement une`);
}
// B3
const packs = offres.filter(o => o.type === "pack").length;
if (packs > 1) echecs.push(`B3 ${packs} packs, au plus un`);
// B4
for (const o of offres)
  for (const k of ["pieces", "pierres", "diamants", "etoiles", "rang", "medaille", "medailles", "temps", "vies"])
    if (k in o) echecs.push(`B4 ${o.id} vend « ${k} » — ça ne se vend jamais`);

console.log(`boutique-check — ${offres.length} offres : ${offres.filter(o => o.type === "carte").length} carte(s), ${packs} pack`);
for (const o of offres) console.log(`  ${o.id.padEnd(16)} ${o.prix.padStart(8)}  ${o.dit}`);
for (const e of echecs) console.log("  ✘ " + e);
console.log(echecs.length ? `  ${echecs.length} refus` : "  ✔ B1…B4 tenues");
process.exit(echecs.length ? 1 : 0);
