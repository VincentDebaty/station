// ------------------------------------------------------------------
// carte-check — UNE CARTE EST-ELLE LIVRABLE ?
//
//     node tools/carte-check.mjs                    # la carte Europe entière
//     node tools/carte-check.mjs --livrable=nw,ger  # un bloc de zones, comme on le livrera
//     node tools/carte-check.mjs --detail           # la couverture ligne par ligne, avec les candidats
//     node tools/carte-check.mjs --resume           # une ligne, pour gen-check
//     node tools/carte-check.mjs --carte=<id>       # une autre carte de data/cartes/
//
// Les règles viennent de meta-progression-jeu-aiguillage.md §3, et ce fichier
// est la seule autorité sur leur lecture : une règle qu'on ne mesure pas n'est
// pas une règle, c'est une intention.
//
//   R1   20 hubs au moins.
//   R2   50 lignes au moins — un plancher DE CARTE. Sur un bloc (--livrable)
//        il s'affiche mais ne compte pas : on développe zone par zone, et le
//        bloc de lancement (24 hubs, 39 lignes) a été accepté tel quel.
//   R2b  3 sorties par hub. Sur la carte entière, un hub sous 3 est une erreur :
//        ajouter des lignes, sinon supprimer le hub. Sur un bloc, une sortie
//        qui part vers une zone pas encore livrée est « à venir » : le hub
//        reste, c'est décidé.
//   R3   4 à 9 gares par ligne, donc 5 à 10 niveaux hub d'arrivée compris.
//   R4   des zones de 7 à 13 hubs, et au moins deux.
//   R5   pas de cul-de-sac : graphe connexe, fiches existantes, hubs écrits.
//   R6   une gare intermédiaire appartient à une seule ligne, et n'est jamais
//        un hub.
//   R7   une ligne reste sur sa ligne réelle : sinuosité ≤ 1,5 × le vol d'oiseau.
//   R8   les gares grossissent vers le hub — avertissement seulement, parce
//        qu'une ligne se joue dans les deux sens et qu'une dent de scie est
//        acceptée. On mesure, dans chaque sens, les gares dont le plafond de
//        flux (js/graph.js) est sous la difficulté voulue à leur position.
//
// Et la COUVERTURE, qui n'est pas une règle mais la liste du travail : pour
// chaque ligne trop courte ou vide dont les deux hubs sont écrits, les gares
// réelles que data/lines.js place entre eux et qui n'ont pas encore de fiche.
// C'est de cette liste que part l'écriture — pas d'une recherche.
//
// Code de sortie ≠ 0 dès qu'une règle ✘ échoue sur l'ensemble évalué.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";

const ROOT = new URL("..", import.meta.url).pathname;
const read = f => readFileSync(ROOT + f, "utf8");

let CARTE_ID = "europe", LIVRABLE = null, DETAIL = false, RESUME = false;
for (const a of process.argv.slice(2)) {
  let m;
  if ((m = /^--carte=(.+)$/.exec(a))) CARTE_ID = m[1];
  else if ((m = /^--livrable=(.+)$/.exec(a))) LIVRABLE = new Set(m[1].split(",").map(s => s.trim()).filter(Boolean));
  else if (a === "--detail") DETAIL = true;
  else if (a === "--resume") RESUME = true;
  else { console.error("argument inconnu : " + a); process.exit(2); }
}

// ------------------------------------------------------------------
// CHARGEMENT — la carte, la bibliothèque de fiches, la géographie, le réseau.
// ------------------------------------------------------------------
const CARTE = JSON.parse(read("data/cartes/" + CARTE_ID + ".json"));
const index = JSON.parse(read("data/stations/index.json"));
const CATALOG = [];
for (const g of index)
  for (const id of g.stations) CATALOG.push(JSON.parse(read(`data/stations/${g.country}/${id}.json`)));
const card = Object.fromEntries(CATALOG.map(c => [c.id, c]));
const idOfName = {};
for (const c of CATALOG) idOfName[c.city || c.name] = c.id;
const nomDe = id => card[id] ? (card[id].city || card[id].name) : id;

// Les outils de lecture du jeu, sans navigateur : geo (coordonnées des
// villes), network (le réseau réel, gares ET points de passage), graph (le
// modèle de difficulté). js/graph.js se garde tout seul sans carte chargée.
const ctx = createContext({ console, CATALOG });
for (const [f, n] of [
  ["js/geo.js", ["GEO"]],
  ["data/places.js", ["PLACES", "PLACE_ALIASES"]],
  ["data/lines.js", ["LINES", "LINE_COUNTRIES"]],
  ["js/network.js", ["netEdges", "netKey", "netPlaces"]],
  ["js/graph.js", ["difficulteVoulue", "plafondDeFlux"]]
]) runInContext(read(f) + "\n" + n.map(x => `globalThis.${x} = ${x};`).join(""), ctx);
const { GEO, PLACES, netEdges, netPlaces, difficulteVoulue, plafondDeFlux } = ctx;

const lonlat = {};
for (const slug in GEO.countries)
  for (const id in GEO.countries[slug].cities) lonlat[id] = GEO.countries[slug].cities[id];
const R = 6371, rad = Math.PI / 180;
const km = (A, B) => (!A || !B) ? null
  : R * Math.hypot((B[0] - A[0]) * rad * Math.cos((A[1] + B[1]) / 2 * rad), (B[1] - A[1]) * rad);

// ------------------------------------------------------------------
// L'ENSEMBLE ÉVALUÉ — toute la carte, ou un bloc de zones.
// ------------------------------------------------------------------
const zones = CARTE.zones || [], hubs = CARTE.hubs || [], lignes = CARTE.lignes || [];
const hubById = Object.fromEntries(hubs.map(h => [h.id, h]));
for (const h of hubs) h.gareId = h.gare ? idOfName[h.gare] || null : null;

if (LIVRABLE) for (const z of LIVRABLE)
  if (!zones.some(x => x.id === z)) { console.error(`zone inconnue : ${z} (${zones.map(x => x.id).join(", ")})`); process.exit(2); }
const dedans = h => !LIVRABLE || LIVRABLE.has(h.zone);
const H = hubs.filter(dedans);
const Hset = new Set(H.map(h => h.id));
const Z = zones.filter(z => !LIVRABLE || LIVRABLE.has(z.id));
const L = lignes.filter(l => Hset.has(l.de) && Hset.has(l.vers));
const SORTANTES = lignes.filter(l => Hset.has(l.de) !== Hset.has(l.vers));
const nomLigne = l => `${(hubById[l.de] || {}).nom || l.de} – ${(hubById[l.vers] || {}).nom || l.vers}`;

// ------------------------------------------------------------------
// LES RÈGLES
// ------------------------------------------------------------------
const regles = [];   // { id, titre, mesure, etat: "ok" | "ko" | "warn" | "info", detail: [] }
const regle = (id, titre, etat, mesure, detail = []) => regles.push({ id, titre, etat, mesure, detail });

// R1
regle("R1", "20 hubs au moins", H.length >= 20 ? "ok" : "ko", `${H.length} hubs`);

// R2 — plancher de carte ; informatif sur un bloc.
regle("R2", "50 lignes au moins", L.length >= 50 ? "ok" : (LIVRABLE ? "info" : "ko"),
  `${L.length} lignes` + (LIVRABLE && L.length < 50 ? " (plancher de carte, pas de bloc)" : ""));

// R2b — sorties par hub.
{
  const total = {}, internes = {};
  for (const l of lignes) { total[l.de] = (total[l.de] || 0) + 1; total[l.vers] = (total[l.vers] || 0) + 1; }
  for (const l of L) { internes[l.de] = (internes[l.de] || 0) + 1; internes[l.vers] = (internes[l.vers] || 0) + 1; }
  const sous = H.filter(h => (total[h.id] || 0) < 3);
  const aVenir = LIVRABLE ? H.filter(h => (total[h.id] || 0) >= 3 && (internes[h.id] || 0) < 3) : [];
  const detail = sous.map(h => `${h.nom} : ${total[h.id] || 0} sortie(s) — ajouter une ligne, sinon retirer le hub`)
    .concat(aVenir.map(h => `${h.nom} : ${internes[h.id] || 0} dans le bloc, ${total[h.id]} au total — la suite vient d'une autre zone`));
  regle("R2b", "3 sorties par hub", sous.length ? (LIVRABLE ? "warn" : "ko") : (aVenir.length ? "warn" : "ok"),
    sous.length ? `${sous.length} hub(s) sous 3` + (LIVRABLE ? " (tolérés le temps du développement)" : "")
      : aVenir.length ? `${aVenir.length} hub(s) complétés par une autre zone` : "tous à 3 ou plus", detail);
}

// R3 — longueur des lignes.
const longueur = l => (l.gares || []).length;
const etatLigne = l => { const n = longueur(l); return n === 0 ? "vide" : n < 4 ? "courte" : n > 9 ? "longue" : "conforme"; };
{
  const compte = { conforme: 0, courte: 0, vide: 0, longue: 0 };
  for (const l of L) compte[etatLigne(l)]++;
  regle("R3", "4 à 9 gares par ligne", compte.conforme === L.length ? "ok" : "ko",
    `${compte.conforme} conformes · ${compte.courte} trop courtes · ${compte.vide} vides` + (compte.longue ? ` · ${compte.longue} trop longues` : ""),
    L.filter(l => etatLigne(l) !== "conforme").map(l => `${nomLigne(l)} : ${longueur(l)} gare(s)`));
}

// R4 — zones.
{
  const tailles = Z.map(z => ({ z, n: hubs.filter(h => h.zone === z.id).length }));
  const hors = tailles.filter(t => t.n < 7 || t.n > 13);
  const sansZone = H.filter(h => !zones.some(z => z.id === h.zone));
  regle("R4", "zones de 7 à 13 hubs, au moins deux", (Z.length >= 2 && !hors.length && !sansZone.length) ? "ok" : "ko",
    `${Z.length} zone(s)` + (tailles.length ? ` de ${Math.min(...tailles.map(t => t.n))} à ${Math.max(...tailles.map(t => t.n))} hubs` : ""),
    hors.map(t => `${t.z.nom} : ${t.n} hubs`).concat(sansZone.map(h => `${h.nom} : zone inconnue « ${h.zone} »`)));
}

// R5 — pas de cul-de-sac : connexité, fiches, hubs écrits.
{
  const detail = [];
  const adj = {}; for (const h of H) adj[h.id] = [];
  for (const l of L) { adj[l.de].push(l.vers); adj[l.vers].push(l.de); }
  const vus = new Set(); const pile = H.length ? [H[0].id] : [];
  while (pile.length) { const u = pile.pop(); if (vus.has(u)) continue; vus.add(u); for (const v of adj[u]) pile.push(v); }
  const isoles = H.filter(h => !vus.has(h.id));
  if (isoles.length) detail.push(`hors du réseau : ${isoles.map(h => h.nom).join(", ")}`);
  const sansFiche = H.filter(h => !h.gareId);
  if (sansFiche.length) detail.push(`hubs à écrire (${sansFiche.length}) : ${sansFiche.map(h => h.nom + (h.gare ? ` (fiche « ${h.gare} » introuvable)` : "")).join(", ")}`);
  const inconnues = [];
  for (const l of L) for (const g of l.gares || []) if (!card[g]) inconnues.push(`${g} (${nomLigne(l)})`);
  if (inconnues.length) detail.push(`fiches référencées absentes : ${inconnues.join(", ")}`);
  for (const l of L) for (const k of ["de", "vers"]) if (!hubById[l[k]]) detail.push(`ligne ${nomLigne(l)} : hub inconnu « ${l[k]} »`);
  regle("R5", "connexe, fiches existantes, hubs écrits", detail.length ? "ko" : "ok",
    detail.length ? `${isoles.length} isolé(s) · ${sansFiche.length} hub(s) sans fiche · ${inconnues.length} fiche(s) absente(s)` : "aucun cul-de-sac", detail);
}

// R6 — une gare, une ligne, et jamais un hub.
const ligneDeGare = {};
{
  const detail = [];
  const hubGares = new Set(hubs.map(h => h.gareId).filter(Boolean));
  for (const l of lignes) for (const g of l.gares || []) {
    if (ligneDeGare[g]) detail.push(`${nomDe(g)} sur ${nomLigne(ligneDeGare[g])} ET ${nomLigne(l)}`);
    else ligneDeGare[g] = l;
    if (hubGares.has(g)) detail.push(`${nomDe(g)} est un hub et figure sur ${nomLigne(l)}`);
  }
  regle("R6", "une gare, une seule ligne", detail.length ? "ko" : "ok",
    detail.length ? `${detail.length} doublon(s)` : `${Object.keys(ligneDeGare).length} gares placées, aucune en double`, detail);
}

// R7 — sinuosité.
const sinuosite = l => {
  const a = hubById[l.de], b = hubById[l.vers];
  if (!a || !b || !longueur(l)) return null;
  const pts = [a.ll, ...l.gares.map(g => lonlat[g]), b.ll];
  if (pts.some(p => !p)) return null;
  let parcouru = 0;
  for (let i = 0; i + 1 < pts.length; i++) parcouru += km(pts[i], pts[i + 1]);
  const direct = km(a.ll, b.ll);
  return direct < 1 ? null : parcouru / direct;
};
{
  const detail = [], sansCoord = [];
  for (const l of L) {
    if (!longueur(l)) continue;
    const s = sinuosite(l);
    if (s == null) { sansCoord.push(nomLigne(l)); continue; }
    if (s > 1.5) detail.push(`${nomLigne(l)} : ×${s.toFixed(2)}`);
  }
  if (sansCoord.length) detail.push(`non mesurables (coordonnée manquante dans js/geo.js) : ${sansCoord.join(", ")}`);
  regle("R7", "sinuosité ≤ 1,5", detail.length > sansCoord.length ? "ko" : (sansCoord.length ? "warn" : "ok"),
    detail.length ? `${detail.length - (sansCoord.length ? 1 : 0)} ligne(s) au-dessus` + (sansCoord.length ? `, ${sansCoord.length} non mesurable(s)` : "") : "toutes sous 1,5", detail);
}

// R8 — la rampe : avertissement.
{
  const detail = [];
  for (const l of L) {
    if (!longueur(l)) continue;
    const sens = [[l.de, l.vers, l.gares], [l.vers, l.de, l.gares.slice().reverse()]];
    const sous = [];
    for (const [, vers, gares] of sens) {
      const boss = hubById[vers]; if (!boss) continue;
      const dBoss = boss.rang === 1 ? 5 : 4;
      gares.forEach((g, i) => {
        if (!card[g]) return;
        const voulu = difficulteVoulue(i, gares.length, dBoss), porte = plafondDeFlux(card[g]);
        if (porte < voulu) sous.push(`${nomDe(g)} ${porte}<${voulu} vers ${boss.nom}`);
      });
    }
    if (sous.length) detail.push(`${nomLigne(l)} : ${sous.join(", ")}`);
  }
  regle("R8", "les gares grossissent vers le hub", detail.length ? "warn" : "ok",
    detail.length ? `${detail.length} ligne(s) dont une gare porte moins que sa position` : "toutes les rampes tiennent", detail);
}

// ------------------------------------------------------------------
// LA COUVERTURE — ce qu'il reste à écrire, ligne par ligne.
// ------------------------------------------------------------------
// Les candidats viennent du réseau réel (data/lines.js + data/places.js, lus
// par js/network.js) : entre les deux gares-hubs, en passant par les gares
// déjà posées, on suit la voie et l'on relève ce qu'elle traverse — points de
// passage sans fiche, et gares du catalogue qu'aucune ligne ne tient encore.
const adjNet = {};
for (const [a, b] of netEdges()) { (adjNet[a] = adjNet[a] || []).push(b); (adjNet[b] = adjNet[b] || []).push(a); }
const places = netPlaces();
const hubGareIds = new Set(hubs.map(h => h.gareId).filter(Boolean));
function segment(u, v, interdits) {
  // Plus court chemin en nombre de pas, sans traverser un hub ni une gare
  // déjà prise par une autre ligne.
  const prev = { [u]: null }, file = [u];
  while (file.length) {
    const x = file.shift();
    if (x === v) break;
    for (const y of adjNet[x] || []) {
      if (y in prev) continue;
      if (y !== v && interdits.has(y)) continue;
      prev[y] = x; file.push(y);
    }
  }
  if (!(v in prev)) return null;
  const out = []; for (let x = prev[v]; x && x !== u; x = prev[x]) out.unshift(x);
  return out;
}
// La gare par laquelle un hub regarde vers un autre : celle de sa VERSION pour
// cette direction quand il en a (Paris-Lyon vers Dijon, Paddington vers
// Bristol), sinon sa gare par défaut.
function gareVers(h, vers) {
  const v = (h.versions || []).find(x => x.vers === vers);
  return (v && idOfName[v.gare]) || h.gareId;
}
function candidats(l) {
  const a = hubById[l.de], b = hubById[l.vers];
  if (!a || !b || !a.gareId || !b.gareId) return { manque: true };
  const jalons = [gareVers(a, l.vers), ...(l.gares || []), gareVers(b, l.de)];
  const interdits = new Set([...hubGareIds, ...Object.keys(ligneDeGare).filter(g => ligneDeGare[g] !== l)]);
  const traverses = [], trous = [];
  for (let i = 0; i + 1 < jalons.length; i++) {
    const seg = segment(jalons[i], jalons[i + 1], interdits);
    if (!seg) { trous.push(`${nomDe(jalons[i])} → ${nomDe(jalons[i + 1])}`); continue; }
    for (const n of seg) if (!traverses.includes(n)) traverses.push(n);
  }
  return {
    lieux: traverses.filter(n => !card[n]).map(n => (places[n] || {}).label || n),
    libres: traverses.filter(n => card[n]).map(nomDe),
    trous
  };
}

// ------------------------------------------------------------------
// RAPPORT
// ------------------------------------------------------------------
const conformes = L.filter(l => etatLigne(l) === "conforme").length;
const ko = regles.filter(r => r.etat === "ko"), warn = regles.filter(r => r.etat === "warn");
const titre = `carte-check — ${CARTE.nom}` + (LIVRABLE ? ` · bloc ${[...LIVRABLE].join("+")}` : "") +
  ` : ${Z.length} zones · ${H.length} hubs · ${L.length} lignes · ${conformes}/${L.length} conformes · ` +
  (ko.length ? `✘ ${ko.length} règle(s)` : "✔ règles") + (warn.length ? ` · ⚠ ${warn.length}` : "");
if (RESUME) { console.log(titre); process.exit(ko.length ? 1 : 0); }

const pad = (s, n) => String(s).padEnd(n);
const signe = { ok: "✔", ko: "✘", warn: "⚠", info: "—" };
console.log("\n" + titre + "\n");
for (const r of regles) {
  console.log(`${signe[r.etat]}  ${pad(r.id, 4)} ${pad(r.titre, 40)} ${r.mesure}`);
  if (r.detail.length && (DETAIL || r.etat === "ko"))
    for (const d of r.detail.slice(0, DETAIL ? 1e9 : 12)) console.log(`          · ${d}`);
  if (!DETAIL && r.detail.length > 12 && r.etat === "ko") console.log(`          · … ${r.detail.length - 12} de plus (--detail)`);
}

// Couverture : toujours le compte, le détail sur demande.
const aFaire = L.filter(l => etatLigne(l) !== "conforme");
let fichesManquantes = 0, hubsManquants = new Set();
const lignesCouv = [];
for (const l of aFaire) {
  const n = longueur(l), c = candidats(l);
  const besoin = Math.max(0, 4 - n);
  if (c.manque) {
    for (const k of ["de", "vers"]) if (hubById[l[k]] && !hubById[l[k]].gareId) hubsManquants.add(hubById[l[k]].nom);
  } else fichesManquantes += besoin;
  lignesCouv.push({ l, n, c, besoin });
}
console.log(`\nCOUVERTURE : ${aFaire.length} ligne(s) à compléter · au moins ${fichesManquantes} fiche(s) à écrire sur les lignes dont les deux hubs existent` +
  (hubsManquants.size ? ` · ${hubsManquants.size} hub(s) à écrire d'abord : ${[...hubsManquants].join(", ")}` : ""));
if (LIVRABLE && SORTANTES.length)
  console.log(`${SORTANTES.length} ligne(s) sortent du bloc (à venir) : ${SORTANTES.map(nomLigne).join(", ")}`);
if (DETAIL) {
  console.log();
  lignesCouv.sort((x, y) => y.n - x.n || nomLigne(x.l).localeCompare(nomLigne(y.l)));
  for (const { l, n, c, besoin } of lignesCouv) {
    const tete = `${pad(n + " gare" + (n > 1 ? "s" : ""), 9)}${pad(nomLigne(l), 28)}`;
    if (c.manque) { console.log(`${tete} hub à écrire d'abord`); continue; }
    const s = sinuosite(l);
    console.log(`${tete} ${pad("+" + besoin + " à écrire", 12)}` + (s ? ` ×${s.toFixed(2)}` : "") +
      (n ? `  [${l.gares.map(nomDe).join(" · ")}]` : ""));
    if (c.lieux.length) console.log(`${pad("", 9)}  sur la voie, sans fiche : ${c.lieux.join(", ")}`);
    if (c.libres.length) console.log(`${pad("", 9)}  au catalogue, sur aucune ligne : ${c.libres.join(", ")}`);
    if (c.trous.length) console.log(`${pad("", 9)}  pas de tracé dans data/lines.js : ${c.trous.join(" ; ")}`);
    if (!c.lieux.length && !c.libres.length && !c.trous.length) console.log(`${pad("", 9)}  la voie ne traverse rien d'autre : chercher les gares réelles (Wikipédia, OpenRailwayMap)`);
  }
}
console.log(ko.length ? `\n${ko.length} règle(s) en échec — la carte${LIVRABLE ? " (ce bloc)" : ""} n'est pas livrable.\n`
  : `\nToutes les règles tiennent${warn.length ? ", avec des avertissements" : ""} — ${LIVRABLE ? "le bloc" : "la carte"} est livrable.\n`);
process.exit(ko.length ? 1 : 0);
