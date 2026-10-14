#!/usr/bin/env node
// ------------------------------------------------------------------
// labyrinthe-vers-godot — CE QUE LE MOTEUR GODOT DU LABYRINTHE DOIT REJOUER.
//
//   node tools/labyrinthe-vers-godot.mjs
//
// La page web (prototypes/prototype-labyrinthe.html) reste la seule source
// du niveau et des règles. Cet outil en DÉRIVE, dans prototypes/labyrinthe-godot/ :
//   niveau.json   le bloc JSON « niveau », tel quel
//   oracle.json   des parties jouées par le moteur JS :
//                 - au repos (une tape, puis l'eau et la boule se posent) :
//                   la solution écrite, le piège, et des parties au hasard
//                   (les graines et le tirage du banc) ; après chaque tape,
//                   l'eau de chaque case du labyrinthe, la boule, les compteurs ;
//                 - en temps réel : deux vidanges puis le robinet tenu (le
//                   script du film), la boule toutes les 10 images et l'image
//                   où elle sort
// puis oracle.gd (godot --headless --path prototypes/labyrinthe-godot
// --script res://oracle.gd) vérifie que moteur.gd rejoue chacune. Relancer
// après avoir touché au niveau ou au moteur JS. Jamais édités à la main.
// ------------------------------------------------------------------
import { readFileSync, writeFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const PAGE = "prototypes/prototype-labyrinthe.html";
const DOSSIER = "prototypes/labyrinthe-godot";
const html = readFileSync(join(RACINE, PAGE), "utf8");
const bloc = id => html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'))[1];
const texte = bloc("niveau");
const N = JSON.parse(texte);
const ctx = createContext({});
runInContext(bloc("moteur") + "\n;globalThis.Labyrinthe = Labyrinthe;", ctx);
const L = ctx.Labyrinthe, G = L.prep(N);
const PARTIES_AU_HASARD = 6, TAPES = 30;

function Hasard(graine) {             // le tirage du banc (tools/labyrinthe-banc.mjs)
  let a = (graine >>> 0) || 1;
  return () => {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
// L'eau de chaque case du labyrinthe (rangée du bas d'abord), en cases.
function eauParCase(e) {
  const r = [];
  for (let y = 0; y < G.H; y++) for (let x = 0; x < G.W; x++) {
    let s = 0;
    for (let dy = 0; dy < G.S; dy++) for (let dx = 0; dx < G.S; dx++) s += e.m[(y * G.S + dy) * G.SW + x * G.S + dx];
    r.push(s / G.S2);
  }
  return r;
}
const photo = (e, k) => ({ tape: k, tapes: e.tapes, gagne: e.gagne, pas: e.pas, b: [e.b.x, e.b.y], verse: e.verse, sorti: e.sorti, vide: e.vide, eau: eauParCase(e) });

const parties = [];
function auRepos(nom, suite) {
  let e = L.charger(N);
  const pas = [photo(e, -1)];
  for (const k of suite) {
    const r = L.jouer(N, e, k);
    if (!r) continue;                 // la tape ne peut rien : l'état ne bouge pas
    e = r;
    pas.push(photo(e, k));
    if (e.gagne) break;
  }
  parties.push({ nom, mode: "repos", pas });
}
auRepos("solution", [...N.solution].map(c => +c - 1));
for (const p of N.pieges || []) auRepos("piège " + p.slice(0, 8) + "…", [...p].map(c => +c - 1));
for (let g = 1; g <= PARTIES_AU_HASARD; g++) {
  const h = Hasard(g), suite = [];
  for (let t = 0; t < TAPES; t++) suite.push(Math.floor(h() * G.vannes.length));
  auRepos("hasard " + g, suite);
}

// En temps réel : le script du film (tools/labyrinthe-film.mjs).
{
  const vidange = G.vannes.findIndex(v => v.type === "vidange" && v.x === Math.max(...G.vannes.filter(w => w.type === "vidange").map(w => w.x)));
  const robinet = G.vannes.findIndex(v => v.type === "robinet");
  const script = [{ a: 30, k: vidange }, { a: 100, k: vidange }, { a: 170, k: robinet, tenu: true }];
  let e = L.charger(N), appui = null, sortie = -1;
  const boule = [];
  for (let im = 0; im < 3000 && sortie < 0; im++) {
    for (const s of script) if (s.a === im) { const r = L.taper(N, e, s.k); if (r) e = r; if (s.tenu) appui = { k: s.k, depuis: im }; }
    if (appui && !e.gagne && im - appui.depuis >= 18 && e.attente[appui.k] < 0.05) { const r = L.taper(N, e, appui.k); if (r) e = r; }
    L.pas(N, e);
    if (im % 10 === 0) boule.push([im, e.b.x, e.b.y]);
    if (e.gagne) sortie = im;
  }
  parties.push({ nom: "temps réel", mode: "temps", script, appui_long: 18, boule, sortie, tapes: e.tapes, eau: eauParCase(e) });
}

writeFileSync(join(RACINE, DOSSIER, "niveau.json"), texte.trim() + "\n");
writeFileSync(join(RACINE, DOSSIER, "oracle.json"), JSON.stringify({ source: PAGE, parties }));
const tapes = parties.filter(p => p.mode === "repos").reduce((s, p) => s + p.pas.length - 1, 0);
console.log(`${DOSSIER}/niveau.json et oracle.json : ${parties.length} parties (${tapes} tapes au repos, plus une partie en temps réel sortie à l'image ${parties.at(-1).sortie})`);
