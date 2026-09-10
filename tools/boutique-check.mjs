// ------------------------------------------------------------------
// boutique-check — CE QUI SE VEND EST-IL CE QU'ON A DÉCIDÉ DE VENDRE ?
//
//     node tools/boutique-check.mjs
//
// La seule autorité sur data/boutique.json (economie-du-jeu.md §6, lot 3).
// Six règles, et il REFUSE (code de sortie ≠ 0) :
//
//   B1  chaque offre a un id unique, un `produit` unique (l'identifiant du
//       magasin de la plateforme), un type parmi carte / pierres / pack, un
//       prix affiché « N,NN € », et une phrase `dit`.
//   B2  une offre de carte vise une carte de l'index qui n'est PAS gratuite ;
//       toute carte payante a EXACTEMENT une offre. La première carte est
//       gratuite et complète : elle ne se vend pas.
//   B3  une offre de pierres en donne un nombre entier > 0, et le prix par
//       pierre ne remonte jamais quand le lot grossit.
//   B4  au plus un pack.
//   B5  CE QUI NE SE VEND JAMAIS : aucune offre ne porte `pieces`, `etoiles`,
//       `rang`, `medaille`, `temps`, `vies`. Vendre des pièces viderait la
//       boucle « retourner dorer », qui est le jeu.
//   B6  LE GARDE-FOU : acheter en pierres tous les passages d'une carte
//       payante coûte au moins CINQ fois la carte, au meilleur prix de la
//       pierre. On ne s'achète pas un chapitre d'or — ni même un ruban à
//       zéro étoile pour le prix d'une carte.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const lire = p => JSON.parse(readFileSync(join(RACINE, p), "utf8"));
const boutique = lire("data/boutique.json");
const index = lire("data/cartes/index.json");
const DEFS = {};
for (const e of index) DEFS[e.id] = lire("data/cartes/" + e.fichier);
// le barème des passages, tel que js/recompense.js le calcule
const PASSAGE_BASE = 50, PASSAGE_PAR_CHAPITRE = 30, PIERRE_VAUT = 50;

const offres = Array.isArray(boutique.offres) ? boutique.offres : [];
const echecs = [], notes = [];
const euros = s => { const m = /^(\d+),(\d\d) €$/.exec(String(s)); return m ? Number(m[1]) + Number(m[2]) / 100 : NaN; };

// B1
const ids = new Set(), produits = new Set();
for (const o of offres) {
  if (!o.id || ids.has(o.id)) echecs.push(`B1 id manquant ou en double : ${JSON.stringify(o.id)}`);
  ids.add(o.id);
  if (!o.produit || produits.has(o.produit)) echecs.push(`B1 ${o.id} : produit manquant ou en double`);
  produits.add(o.produit);
  if (!["carte", "pierres", "pack"].includes(o.type)) echecs.push(`B1 ${o.id} : type inconnu ${JSON.stringify(o.type)}`);
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
const pierres = offres.filter(o => o.type === "pierres").slice().sort((a, b) => (a.pierres | 0) - (b.pierres | 0));
let dernier = Infinity;
for (const o of pierres) {
  if (!Number.isInteger(o.pierres) || o.pierres <= 0) { echecs.push(`B3 ${o.id} : pierres doit être un entier > 0`); continue; }
  const par = euros(o.prix) / o.pierres;
  if (par > dernier + 1e-9) echecs.push(`B3 ${o.id} : ${par.toFixed(4)} € la pierre, plus cher que le lot plus petit`);
  dernier = par;
  notes.push(`${o.id.padEnd(14)} ${String(o.pierres).padStart(4)} pierres  ${o.prix.padStart(8)}  ${par.toFixed(4)} €/pierre`);
}
// B4
const packs = offres.filter(o => o.type === "pack").length;
if (packs > 1) echecs.push(`B4 ${packs} packs, au plus un`);
// B5
for (const o of offres)
  for (const k of ["pieces", "etoiles", "rang", "medaille", "medailles", "temps", "vies"])
    if (k in o) echecs.push(`B5 ${o.id} vend « ${k} » — ça ne se vend jamais`);
// B6
const meilleur = pierres.length ? Math.min(...pierres.map(o => euros(o.prix) / o.pierres)) : NaN;
for (const o of offres.filter(o => o.type === "carte" && DEFS[o.carte])) {
  const chs = DEFS[o.carte].chapitres || [];
  let total = 0;
  chs.forEach((ch, i) => { total += (ch.gares || []).length * Math.ceil((PASSAGE_BASE + i * PASSAGE_PAR_CHAPITRE) / PIERRE_VAUT); });
  const cout = total * meilleur, prix = euros(o.prix);
  notes.push(`${o.carte.padEnd(14)} tous les passages en pierres : ${total} pierres ≈ ${cout.toFixed(2)} €, la carte ${o.prix} (× ${(cout / prix).toFixed(1)})`);
  if (!(cout >= 5 * prix)) echecs.push(`B6 ${o.carte} : la voie sans gloire (${cout.toFixed(2)} €) coûte moins de cinq fois la carte (${o.prix})`);
}
const europe = DEFS.europe;
if (europe) {
  let total = 0;
  (europe.chapitres || []).forEach((ch, i) => { total += (ch.gares || []).length * Math.ceil((PASSAGE_BASE + i * PASSAGE_PAR_CHAPITRE) / PIERRE_VAUT); });
  notes.push(`europe         tous les passages en pierres : ${total} pierres ≈ ${(total * meilleur).toFixed(2)} € — pour un ruban à zéro étoile`);
}

console.log(`boutique-check — ${offres.length} offres : ${offres.filter(o => o.type === "carte").length} carte(s), ${pierres.length} lot(s) de pierres, ${packs} pack`);
for (const n of notes) console.log("  " + n);
for (const e of echecs) console.log("  ✘ " + e);
console.log(echecs.length ? `  ${echecs.length} refus` : "  ✔ B1…B6 tenues");
process.exit(echecs.length ? 1 : 0);
