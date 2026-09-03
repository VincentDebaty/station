// ------------------------------------------------------------------
// oracle-ruban — LE PROTOTYPE JUGE LA RAMPE ET LA RÉCOMPENSE DE GODOT.
//
//     node tools/oracle-ruban.mjs                # les deux cartes, tous les scénarios
//     node tools/oracle-ruban.mjs europe --detail
//
// js/ruban.js et js/recompense.js sont des fonctions pures de trois choses :
// la carte, le catalogue, et la progression. On les évalue dans un node:vm
// avec une fausse sauvegarde (les globales que js/store.js et js/cartes.js
// leur donnent d'ordinaire), puis jeu/oracle_ruban.gd fait le même travail
// avec jeu/ruban.gd et jeu/recompense.gd sur la même progression, et l'on
// compare tout ce qui se déduit : par chapitre le plancher, l'arrivée, le
// rang ; par gare la difficulté jouée, le plafond, le barème, la fiche de
// service (difficulty + gen), le boss, les cinq états (écrite, faite, payée,
// franchie, tenue), le niveau, le prix de passage et le verdict R10 ; puis
// la position, les zones, l'état des récompenses, les médailles, les crédits,
// et une grille d'étoiles et d'enveloppes.
//
// LA PROGRESSION EST SYNTHÉTIQUE ET REPRODUCTIBLE : une carte vierge, un
// début, une carte complète, et trois tirages mixtes à graine fixe qui
// laissent des trous, paient des gares, et enregistrent une gare hors ruban —
// exprès, pour exercer les chemins que le jeu n'emprunte pas tous les jours.
// ------------------------------------------------------------------
import { readFileSync, writeFileSync, mkdtempSync, existsSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const lire = p => JSON.parse(readFileSync(join(RACINE, p), "utf8"));
const src = p => readFileSync(join(RACINE, p), "utf8");
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
const TOL = 1e-9;
const GODOT = process.env.GODOT || "godot";

// --- le catalogue, les cartes, les brevets ----------------------------------
const index = lire("data/stations/index.json");
const FICHES = new Map();
for (const g of index) for (const id of g.stations) {
  const p = `data/stations/${g.country}/${id}.json`;
  if (existsSync(join(RACINE, p))) FICHES.set(id, lire(p));
}
const INDEX_CARTES = lire("data/cartes/index.json");
const DEFS = {};
for (const e of INDEX_CARTES) DEFS[e.id] = lire("data/cartes/" + e.fichier);
let brevets = {};
try { brevets = lire("data/stations/brevets.json"); } catch { /* pas certifié */ }
let cartes = args.filter(a => !a.startsWith("--"));
if (!cartes.length) cartes = INDEX_CARTES.map(e => e.id);
for (const c of cartes) if (!DEFS[c]) { console.error("carte inconnue : " + c); process.exit(2); }

// --- les scénarios de progression --------------------------------------------
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
const ordreDe = def => { const o = []; for (const ch of def.chapitres) for (const g of ch.gares) if (!o.includes(g)) o.push(g); return o; };
function mixte(def, graine) {
  const rnd = mulberry32(graine), stations = {}, passees = [];
  for (const g of ordreDe(def)) {
    const r = rnd();
    if (r < 0.55) stations[g] = { stars: 1 + Math.floor(rnd() * 3), bestDelay: rnd() < 0.25 ? 0 : 1 + Math.floor(rnd() * 25) };
    else if (r < 0.65) { passees.push(g); if (rnd() < 0.5) stations[g] = { stars: 0, bestDelay: null }; }
    else if (r < 0.70) { passees.push(g); stations[g] = { stars: 2, bestDelay: 3 }; }   // payée PUIS gagnée : la mise est rendue
  }
  // Une gare du catalogue HORS ruban, avec un résultat : le prototype compte
  // ses étoiles (CATALOG) mais pas sa gare (isBought).
  const hors = [...FICHES.keys()].filter(id => !ordreDe(def).includes(id));
  if (hors.length) stations[hors[Math.floor(rnd() * hors.length)]] = { stars: 2, bestDelay: 0 };
  return { stations, passees, serie: { n: Math.floor(rnd() * 5), record: Math.floor(rnd() * 14) } };
}
function scenarios(carteId) {
  const def = DEFS[carteId], ordre = ordreDe(def), autre = INDEX_CARTES.map(e => e.id).find(id => id !== carteId);
  const debut = { stations: {}, passees: [ordre[7]], serie: { n: 2, record: 3 } };
  ordre.slice(0, 7).forEach((g, k) => { debut.stations[g] = { stars: (k % 3) + 1, bestDelay: k === 2 ? 0 : 5 + k }; });
  const complet = { stations: {}, passees: [], serie: { n: 12, record: 12 } };
  ordre.forEach((g, k) => { complet.stations[g] = { stars: 3, bestDelay: k % 2 === 0 ? 0 : 1 }; });
  const liste = [
    { nom: "vierge", stations: {}, passees: [], serie: { n: 0, record: 0 } },
    { nom: "debut", ...debut }, { nom: "complet", ...complet },
    { nom: "mixte-1", ...mixte(def, 1) }, { nom: "mixte-2", ...mixte(def, 2) }, { nom: "mixte-3", ...mixte(def, 3) }
  ];
  return liste.map((s, k) => ({
    carte: carteId, ...s,
    // Le compte : la carte courante telle quelle, plus l'autre carte avec sa
    // propre progression — le solde est un fait de compte, pas de carte.
    cartes: [{ id: carteId, stations: s.stations, passees: s.passees },
      ...(autre ? [{ id: autre, ...(k % 2 ? mixte(DEFS[autre], 100 + k) : { stations: {}, passees: [] }) }] : [])]
      .map(c => ({ id: c.id, stations: c.stations, passees: c.passees })),
    possedees: k % 2 ? { [carteId]: "offerte", ...(autre ? { [autre]: "credits" } : {}) } : { [carteId]: "gratuite" }
  }));
}
const SCENARIOS = cartes.flatMap(scenarios);

// --- côté prototype : la fausse sauvegarde, puis les deux scripts -----------
const sandbox = { console, JSON, Math, __SC: null, CARTE_COURANTE: null };
sandbox.getProgress = () => sandbox.__SC.stations;
sandbox.getPassees = () => sandbox.__SC.passees;
sandbox.getSerie = () => ({ ...sandbox.__SC.serie });
sandbox.getCartesEnregistrees = () => sandbox.__SC.cartes;
sandbox.getCarteCourante = () => sandbox.__SC.carte;
sandbox.cartesPossedees = () => sandbox.__SC.possedees;
sandbox.cardOf = id => FICHES.get(id) || null;
sandbox.CATALOG = [...FICHES.values()];
sandbox.defDeCarte = id => DEFS[id] || null;
sandbox.carteCourante = () => sandbox.CARTE_COURANTE;
sandbox.zonesDeCarte = () => sandbox.CARTE_COURANTE ? sandbox.CARTE_COURANTE.zones || [] : [];
sandbox.prixDeCarte = id => {
  const d = DEFS[id];
  if (d && typeof d.prixCredits === "number") return d.prixCredits;
  const e = INDEX_CARTES.find(c => c.id === id);
  return (e && typeof e.prixCredits === "number") ? e.prixCredits : 0;
};
sandbox.isBought = id => sandbox.estTenue(id);   // js/store.js : tenir, c'est avoir atteint
createContext(sandbox);
runInContext(src("js/ruban.js"), sandbox, { filename: "ruban.js" });
runInContext(src("js/recompense.js"), sandbox, { filename: "recompense.js" });
const RETARDS = [0, 1, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 15, 19, 19.5, 20, 20.5, 25, 29, 29.5, 30, 30.5, 31, 60];
runInContext(`
function __exporter(brevets, viergeIds, retards) {
  const chs = chapitresDuRuban(), ordre = ordreDuRuban();
  const out = { chapitres: [], gares: [], zones: {} };
  for (const ch of chs) {
    const r = rangDeChapitre(ch);
    out.chapitres.push({ id: ch.id, rang: ch.rang, plancher: plancherDeChapitre(ch), arrivee: arriveeDeChapitre(ch),
      termine: chapitreTermine(ch), rangId: r ? r.id : null, debut: ch.debut, fin: ch.fin, saut: !!ch.saut });
  }
  ordre.forEach((id, i) => {
    const cfg = cardOf(id), ch = chapitreDeGare(id), d = difficulteDeGare(id, cfg), s = ficheDeService(cfg);
    const e = { id, index: i, chapitre: ch ? ch.id : null, rangDansChapitre: rangDansChapitre(id),
      difficulte: d, plafond: plafondDeFlux(cfg), seuils: seuilsDeService(cfg),
      service: s ? { difficulty: s.difficulty, gen: s.gen } : null, enveloppe: enveloppeDeGare(id, cfg),
      grande: estGrandeGare(id), boss: estBoss(id, cfg), ecrite: estEcrite(id),
      faite: estFaite(id), passee: estPassee(id), franchie: estFranchie(id), tenue: estTenue(id),
      niveau: niveauDeGare(id), prix: prixDePassage(id), r10: null };
    const b = brevets[id];
    if (cfg && b && typeof b === "object")
      e.r10 = e.boss ? (b.boss === "OK" ? "ok" : "boss-ko") : (d > (b.niveau || 0) ? "depasse" : "ok");
    out.gares.push(e);
  });
  out.position = positionCourante(); out.premiereAVenir = premiereAVenir();
  out.gareCourante = gareCourante(); out.auBout = auBoutDeLEcrit();
  const cc = chapitreCourant(); out.chapitreCourant = cc ? cc.id : null;
  for (const z of zonesDeCarte()) out.zones[z.id] = etatDeZone(z.id);
  out.etat = etatRecompenses();
  out.medailles = [...medaillesDe(out.etat)];
  out.nouvelles = medaillesNouvelles(new Set(viergeIds), medaillesDe(out.etat)).map(m => m.id);
  out.credits = { gagnes: creditsGagnes(), depenses: creditsDepenses(), solde: soldeCredits() };
  out.etoilesPour = [];
  for (let n = 1; n <= 5; n++) for (const r of retards) out.etoilesPour.push([n, r, etoilesPour(r, seuilsDeNiveau(n))]);
  out.enveloppes = [];
  const c0 = cardOf(ordre.find(g => cardOf(g)));
  for (let n = 0; n <= 5; n++) for (let p = 0; p < PROFILS.length; p++) out.enveloppes.push(enveloppeDe(c0, n, PROFILS[p]));
  return out;
}`, sandbox, { filename: "exporter.js" });
function exporterJS(sc) {
  if (!sandbox.CARTE_COURANTE || sandbox.CARTE_COURANTE.id !== sc.carte) { sandbox.CARTE_COURANTE = DEFS[sc.carte]; sandbox.resetRuban(); }
  sandbox.__SC = { ...sc, stations: {}, passees: [], serie: { n: 0, record: 0 } };
  const vierge = [...sandbox.medaillesDe(sandbox.etatRecompenses())];
  sandbox.__SC = sc;
  sandbox.__brevets = brevets; sandbox.__vierge = vierge; sandbox.__retards = RETARDS;
  return JSON.parse(JSON.stringify(runInContext("__exporter(__brevets, __vierge, __retards)", sandbox)));
}

// --- côté Godot : un seul démarrage ----------------------------------------
const sortie = mkdtempSync(join(tmpdir(), "oracle-ruban-"));
const fichierScenarios = join(sortie, "scenarios.json");
writeFileSync(fichierScenarios, JSON.stringify(SCENARIOS));
const t0 = Date.now();
const r = spawnSync(GODOT, ["--headless", "--path", RACINE, "--script", "res://jeu/oracle_ruban.gd", "--", sortie, fichierScenarios],
  { encoding: "utf8", maxBuffer: 1 << 26, timeout: 10 * 60 * 1000 });
const sortieGodot = ((r.stdout || "") + "\n" + (r.stderr || "")).trim();
if (r.status !== 0 || /SCRIPT ERROR|^ERROR:|Parse Error/m.test(sortieGodot)) {
  console.error("Godot a refusé (code " + r.status + ") :\n" +
    sortieGodot.split("\n").filter(l => !/^Godot Engine|^$/.test(l)).join("\n"));
  process.exit(1);
}
const dureeGodot = Date.now() - t0;

// --- la comparaison ---------------------------------------------------------
function comparer(a, b, ou, ecarts) {
  if (a === undefined) a = null;
  if (b === undefined) b = null;
  if (typeof a === "number" && typeof b === "number") {
    if (!(Math.abs(a - b) <= TOL)) ecarts.push(`${ou} : js=${a} godot=${b}`);
    return;
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b)) { ecarts.push(`${ou} : types`); return; }
    if (a.length !== b.length) { ecarts.push(`${ou} : ${a.length} contre ${b.length} éléments`); return; }
    a.forEach((x, i) => comparer(x, b[i], `${ou}[${i}]`, ecarts));
    return;
  }
  if (a && b && typeof a === "object" && typeof b === "object") {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      if (k.startsWith("_")) continue;
      if (!(k in a) && b[k] === null) continue;
      if (!(k in b) && a[k] === null) continue;
      if (!(k in a) || !(k in b)) { ecarts.push(`${ou}.${k} : ${k in a ? "absent côté Godot" : "absent côté JS"}`); continue; }
      comparer(a[k], b[k], `${ou}.${k}`, ecarts);
    }
    return;
  }
  if (a !== b) ecarts.push(`${ou} : js=${JSON.stringify(a)} godot=${JSON.stringify(b)}`);
}

let ok = 0, ko = 0;
const lignes = [];
for (const sc of SCENARIOS) {
  const js = exporterJS(sc);
  const nom = `${sc.carte}·${sc.nom}`;
  const f = join(sortie, `${sc.carte}-${sc.nom}.json`);
  if (!existsSync(f)) { ko++; lignes.push(`  ✘ ${nom.padEnd(22)} Godot n'a rien écrit`); continue; }
  const gd = JSON.parse(readFileSync(f, "utf8"));
  const ecarts = [];
  comparer(js, gd, nom, ecarts);
  const resume = `${js.gares.length} gares · position ${js.position} · ${js.etat.etoiles} étoiles · ${js.medailles.length} médailles · solde ${js.credits.solde}`;
  if (ecarts.length) {
    ko++;
    const n = opt("detail") ? 60 : 6;
    lignes.push(`  ✘ ${nom.padEnd(22)} ${ecarts.length} écart(s) — ${resume}`);
    for (const e of ecarts.slice(0, n)) lignes.push(`      ${e}`);
    if (ecarts.length > n) lignes.push(`      … ${ecarts.length - n} de plus`);
  } else { ok++; lignes.push(`  ✔ ${nom.padEnd(22)} ${resume}`); }
}
console.log(`oracle-ruban — ${cartes.length} carte(s) × ${SCENARIOS.length / cartes.length} scénarios, ruban.js + recompense.js contre jeu/ruban.gd + jeu/recompense.gd (Godot en ${dureeGodot} ms)`);
for (const l of lignes) console.log(l);
console.log(`  ${ok} identique(s), ${ko} divergent(s)`);
process.exit(ko ? 1 : 0);
