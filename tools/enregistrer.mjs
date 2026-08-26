// ------------------------------------------------------------------
// enregistrer — APPLIQUER LES MANIFESTES des agents d'écriture.
//
//     node tools/enregistrer.mjs <manifeste.json> [...]
//     node tools/enregistrer.mjs <dossier/>          # tous les manifestes du dossier
//
// Écrire des gares en parallèle, c'est se disputer cinq fichiers partagés :
// index.json, js/geo.js, data/lines.js, data/places.js, data/cartes/europe.json.
// On ne les laisse donc toucher par personne : chaque agent livre ses fiches
// et UN MANIFESTE (format : scratchpad/CONSIGNE-FICHE.md), et c'est cet outil,
// seul, qui enregistre — dans l'ordre, une fois, et de façon idempotente (une
// fiche déjà dans l'index est passée).
//
// Ce qu'il fait, fichier par fichier :
//   index.json    la fiche entre dans le bloc de son pays (créé si `pays_nouveau`)
//   js/geo.js     `id: [lon, lat]` dans countries.<pays>.cities (pays créé si besoin)
//   data/lines.js une ligne de même id est REMPLACÉE, une nouvelle est ajoutée
//   data/places.js les points de passage nouveaux, en tête de PLACES
//   europe.json   la composition de la ligne (`gares`), ou la `gare` du hub
//
// Il ne valide rien : c'est le travail de gen-check, net-check et
// carte-check, dont il imprime les commandes à la fin.
// ------------------------------------------------------------------
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from "node:fs";
import path from "node:path";

const ROOT = new URL("..", import.meta.url).pathname;
const read = f => readFileSync(path.join(ROOT, f), "utf8");
const write = (f, s) => writeFileSync(path.join(ROOT, f), s);

let args = process.argv.slice(2);
if (!args.length) { console.error("usage : node tools/enregistrer.mjs <manifeste.json|dossier> [...]"); process.exit(2); }
const manifestes = [];
for (const a of args) {
  if (statSync(a).isDirectory())
    for (const f of readdirSync(a).filter(f => f.endsWith(".json")).sort()) manifestes.push(path.join(a, f));
  else manifestes.push(a);
}

const index = JSON.parse(read("data/stations/index.json"));
const carte = JSON.parse(read("data/cartes/europe.json"));
let carteTouchee = false;   // on ne réécrit la carte que si un manifeste y touche
let geo = read("js/geo.js"), lines = read("data/lines.js"), places = read("data/places.js");
const dejaDansIndex = new Set(index.flatMap(g => g.stations));
const journal = [], erreurs = [];
const nouveauxIds = [];

for (const mf of manifestes) {
  const m = JSON.parse(readFileSync(mf, "utf8"));
  const nom = path.basename(mf, ".json");

  // --- le pays, s'il est nouveau -------------------------------------
  if (m.pays_nouveau && m.pays_nouveau.slug) {
    const p = m.pays_nouveau;
    if (!index.some(g => g.country === p.slug)) {
      index.push({ country: p.slug, label: `${p.flag} ${p.name}`, stations: [] });
      journal.push(`${nom} : pays ${p.slug} créé dans index.json`);
    }
    if (!new RegExp(`^\\s*"?${p.slug}"?: \\{`, "m").test(geo)) {
      const bloc = `    "${p.slug}": { name: ${JSON.stringify(p.name)}, flag: "${p.flag}", iso: ${JSON.stringify(p.iso || "")}, continent: "europe",\n      cities: {\n      } },\n`;
      // Juste avant le Royaume-Uni, dernier pays écrit à la main.
      const i = geo.indexOf('    "royaume-uni": {');
      if (i < 0) erreurs.push(`${nom} : impossible de placer le pays ${p.slug} dans js/geo.js`);
      else { geo = geo.slice(0, i) + bloc + geo.slice(i); journal.push(`${nom} : pays ${p.slug} créé dans js/geo.js`); }
    }
  }

  // --- les fiches ----------------------------------------------------------
  for (const f of m.fiches || []) {
    const chemin = `data/stations/${f.pays}/${f.id}.json`;
    if (!existsSync(path.join(ROOT, chemin))) { erreurs.push(`${nom} : fiche absente ${chemin}`); continue; }
    let cfg;
    try { cfg = JSON.parse(read(chemin)); } catch (e) { erreurs.push(`${nom} : ${chemin} n'est pas du JSON (${e.message})`); continue; }
    if (cfg.id !== f.id) { erreurs.push(`${nom} : ${chemin} porte l'id « ${cfg.id} » au lieu de « ${f.id} »`); continue; }
    if (dejaDansIndex.has(f.id)) { journal.push(`${nom} : ${f.id} déjà enregistrée, passée`); continue; }
    const bloc = index.find(g => g.country === f.pays);
    if (!bloc) { erreurs.push(`${nom} : pays inconnu « ${f.pays} » pour ${f.id} (renseigner pays_nouveau)`); continue; }
    bloc.stations.push(f.id);
    dejaDansIndex.add(f.id);
    nouveauxIds.push(f.id);
    // geo.js : dans le bloc `cities` du pays, juste avant sa fermeture `} },`.
    if (Array.isArray(f.lonlat) && f.lonlat.length === 2) {
      const re = new RegExp(`(^\\s*"?${f.pays}"?: \\{[\\s\\S]*?cities: \\{)([\\s\\S]*?)(\\n\\s*\\} \\},?)`, "m");
      const mm = re.exec(geo);
      if (!mm) erreurs.push(`${nom} : bloc cities du pays ${f.pays} introuvable dans js/geo.js pour ${f.id}`);
      else {
        const corps = mm[2].replace(/\s+$/, "");
        const virgule = corps.trim() && !corps.trim().endsWith(",") && !corps.trim().endsWith("{") ? "," : "";
        const cle = /^[a-z][a-z0-9]*$/.test(f.id) ? f.id : JSON.stringify(f.id);
        const ligne = `\n        ${cle}: [${f.lonlat[0]}, ${f.lonlat[1]}]`;
        geo = geo.slice(0, mm.index) + mm[1] + corps + virgule + ligne + mm[3] + geo.slice(mm.index + mm[0].length);
      }
    } else erreurs.push(`${nom} : ${f.id} sans lonlat`);
    journal.push(`${nom} : ${f.id} → index.json (${f.pays}), geo.js`);
  }

  // --- les points de passage ------------------------------------------------
  // Une gare qui devient jouable cesse d'être un lieu : sa clé de point de
  // passage (data/places.js) est retirée, sinon net-check la voit orpheline.
  for (const f of m.fiches || []) {
    const k = String(f.id).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]/g, "");
    const re = new RegExp(`^\\s*${k}:\\s*\\[[^\\]]*\\],?[^\\n]*\\n`, "m");
    if (re.test(places)) { places = places.replace(re, ""); journal.push(`${nom} : point de passage ${k} retiré (devenu gare jouable)`); }
  }
  for (const k of m.places_a_retirer || []) {
    const re = new RegExp(`^\\s*${k}:\\s*\\[[^\\]]*\\],?[^\\n]*\\n`, "m");
    if (re.test(places)) { places = places.replace(re, ""); journal.push(`${nom} : point de passage ${k} retiré`); }
  }
  for (const k in m.places || {}) {
    if (new RegExp(`^\\s*${k}:\\s*\\[`, "m").test(places)) continue;
    const [lon, lat] = m.places[k];
    places = places.replace("const PLACES = {\n", `const PLACES = {\n  ${k}: [${lon}, ${lat}],\n`);
    journal.push(`${nom} : point de passage ${k}`);
  }

  // --- les lignes réelles ---------------------------------------------------
  for (const L of m.lines_js || []) {
    if (!L.id || !Array.isArray(L.nodes) || L.nodes.length < 2) { erreurs.push(`${nom} : ligne réelle invalide ${JSON.stringify(L)}`); continue; }
    const entree = `{ id: ${JSON.stringify(L.id)}, name: ${JSON.stringify(L.name || L.id)},\n    nodes: [${L.nodes.map(n => JSON.stringify(n)).join(", ")}] }`;
    const re = new RegExp(`\\{ id: ${JSON.stringify(L.id).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")},[\\s\\S]*?\\] \\}`);
    if (re.test(lines)) { lines = lines.replace(re, entree); journal.push(`${nom} : ligne ${L.id} remplacée`); }
    else {
      lines = lines.replace(/\}\s*\n\];\s*$/, `},\n  ${entree}\n];\n`);
      journal.push(`${nom} : ligne ${L.id} ajoutée`);
    }
  }

  // --- la carte ---------------------------------------------------------------
  if (m.hub) {
    const h = (carte.hubs || []).find(x => x.id === m.hub);
    if (!carte.hubs) erreurs.push(`${nom} : la carte n'a plus de hubs — c'est un ruban de chapitres depuis le 25 août 2026`);
    const f = (m.fiches || [])[0];
    if (!h) erreurs.push(`${nom} : hub inconnu « ${m.hub} »`);
    else if (!f) erreurs.push(`${nom} : hub ${m.hub} sans fiche`);
    else {
      const cfg = JSON.parse(read(`data/stations/${f.pays}/${f.id}.json`));
      h.gare = cfg.city || cfg.name; carteTouchee = true;
      journal.push(`${nom} : hub ${m.hub} joue « ${h.gare} »`);
    }
  }
  if (m.ligne && m.ligne.de && m.ligne.vers) {
    if (!carte.lignes) erreurs.push(`${nom} : la carte n'a plus de lignes — c'est un ruban de chapitres depuis le 25 août 2026`);
    const l = (carte.lignes || []).find(x => (x.de === m.ligne.de && x.vers === m.ligne.vers) || (x.de === m.ligne.vers && x.vers === m.ligne.de));
    if (!l) erreurs.push(`${nom} : ligne ${m.ligne.de} – ${m.ligne.vers} inconnue sur la carte`);
    else if (!Array.isArray(m.composition) || !m.composition.length) erreurs.push(`${nom} : composition vide`);
    else {
      const comp = l.de === m.ligne.de ? m.composition.slice() : m.composition.slice().reverse();
      const inconnues = comp.filter(g => !dejaDansIndex.has(g));
      if (inconnues.length) erreurs.push(`${nom} : composition cite des gares hors index : ${inconnues.join(", ")}`);
      else { l.gares = comp; carteTouchee = true; journal.push(`${nom} : ${l.de} – ${l.vers} = [${comp.join(", ")}]`); }
    }
  }
}

// --- écriture ------------------------------------------------------------------
if (erreurs.length) {
  console.log("\nERREURS — rien n'est écrit :\n  · " + erreurs.join("\n  · ") + "\n");
  process.exit(1);
}
// UNE GARE PAR LIGNE. L'outil repliait les listes sur ~90 caractères : ajouter
// une seule gare refluait tout le bloc de son pays, et noyait chaque
// enregistrement sous des centaines de lignes de diff sans contenu. Le format
// naturel de JSON.stringify fait exactement ce qu'il faut — une gare ajoutée
// est une ligne ajoutée, et l'index redevient relisible en revue.
write("data/stations/index.json", JSON.stringify(index, null, 2) + "\n");
write("js/geo.js", geo);
write("data/lines.js", lines);
write("data/places.js", places);
// LA CARTE NE SE RÉÉCRIT QUE SI ON Y A TOUCHÉ. L'outil la réécrivait à chaque
// passage en supposant `hubs` et `lignes` — la refonte en ruban les a
// remplacés par `chapitres`, et tout enregistrement plantait là, même quand le
// manifeste ne parlait pas de carte. On sérialise donc la forme RÉELLE.
if (carteTouchee) {
  const j = o => JSON.stringify(o);
  const cles = Object.keys(carte);
  const morceaux = [];
  for (const k of cles) {
    const v = carte[k];
    if (!Array.isArray(v)) { morceaux.push(`  ${j(k)}: ${j(v)}`); continue; }
    const lignes = v.map(e => "    " + j(k === "hubs" ? (({ gareId, ...reste }) => reste)(e) : e));
    morceaux.push(`  ${j(k)}: [\n` + lignes.join(",\n") + "\n  ]");
  }
  write("data/cartes/europe.json", "{\n" + morceaux.join(",\n") + "\n}\n");
}

console.log("\n" + journal.map(l => "  · " + l).join("\n"));
console.log(`\n${nouveauxIds.length} fiche(s) enregistrée(s). À lancer maintenant :\n` +
  (nouveauxIds.length ? `  node tools/gen-check.mjs ${nouveauxIds.join(" ")} 20\n` : "") +
  `  node tools/net-check.mjs\n  node tools/carte-check.mjs\n`);
