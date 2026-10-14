#!/usr/bin/env node
// ------------------------------------------------------------------
// labyrinthe-film — UN FILM DE L'EAU, POUR ESSAYER UN RENDU AILLEURS.
//
//   node tools/labyrinthe-film.mjs
//
// Joue le niveau du prototype web (prototypes/prototype-labyrinthe.html —
// son moteur et son niveau, extraits du fichier, jamais copiés) comme un
// joueur le ferait en temps réel : deux tapes de vidange, puis le robinet
// tenu jusqu'à la sortie. Chaque image est enregistrée : l'eau de chaque
// petite case et la place de la boule. Le film sert à la tranche Godot
// (prototypes/labyrinthe-godot/), qui ne fait que le rejouer et le
// dessiner : on juge le rendu avant de porter le moteur.
//
// Sortie : prototypes/labyrinthe-godot/film.json — DÉRIVÉ, à refaire avec
// cette commande, jamais édité à la main.
//
// Le champ enregistré est celui que la vue web dessine (sa fonction
// champ(), sans le flou) : l'eau de chaque petite case, bornée à 1 ; un
// mur prend l'eau de ses huit voisines (le contour s'enfonce dans le mur,
// que le rendu dessine par-dessus) ; l'eau qui tombe est épaissie pour se
// lire en jet. En octets (0 à 255), rangée du HAUT d'abord.
// ------------------------------------------------------------------
import { readFileSync, writeFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const PAGE = "prototypes/prototype-labyrinthe.html";
const SORTIE = "prototypes/labyrinthe-godot/film.json";
const html = readFileSync(join(RACINE, PAGE), "utf8");
const bloc = id => html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'))[1];
const N = JSON.parse(bloc("niveau"));
const ctx = createContext({});
runInContext(bloc("moteur") + "\n;globalThis.Labyrinthe = Labyrinthe;", ctx);
const L = ctx.Labyrinthe, G = L.prep(N);
const APPUI_LONG = 18;            // comme la vue web

function champ(e) {
  const m = e.m, W = G.SW, H = G.SH, brut = new Float32Array(m.length);
  for (let i = 0; i < m.length; i++) {
    if (G.fmur[i]) continue;
    const a = Math.min(1, m[i]), posee = i < W || G.fmur[i - W] || m[i - W] >= 0.95;
    brut[i] = posee || a < 0.06 ? a : Math.min(1, 0.55 + a);
  }
  for (let i = 0; i < m.length; i++) {
    if (!G.fmur[i]) continue;
    const x = i % W, y = (i - x) / W;
    let v = 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const nx = x + dx, ny = y + dy;
      if ((dx || dy) && nx >= 0 && ny >= 0 && nx < W && ny < H && !G.fmur[ny * W + nx]) v = Math.max(v, brut[ny * W + nx]);
    }
    brut[i] = v;
  }
  const octets = new Uint8Array(m.length);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) octets[(H - 1 - y) * W + x] = Math.round(brut[y * W + x] * 255);
  return octets;
}

// Le jeu joué : une image = un pas de jeu, comme dans la page.
const vidange = G.vannes.findIndex(v => v.type === "vidange" && v.x === Math.max(...G.vannes.filter(w => w.type === "vidange").map(w => w.x)));
const robinet = G.vannes.findIndex(v => v.type === "robinet");
const script = [{ a: 30, k: vidange }, { a: 100, k: vidange }, { a: 170, k: robinet, tenu: true }];
let e = L.charger(N), appui = null, fin = -1;
const images = [], boule = [], actives = [];
for (let im = 0; im < 3000; im++) {
  for (const s of script) if (s.a === im) { const r = L.taper(N, e, s.k); if (r) e = r; if (s.tenu) appui = { k: s.k, depuis: im }; }
  if (appui && !e.gagne && im - appui.depuis >= APPUI_LONG && e.attente[appui.k] < 0.05) { const r = L.taper(N, e, appui.k); if (r) e = r; }
  L.pas(N, e);
  images.push(champ(e));
  boule.push(Math.round(e.b.x * 1000) / 1000, Math.round(e.b.y * 1000) / 1000);
  actives.push(e.attente.reduce((s, a, k) => s | (a > 0 ? 1 << k : 0), 0));
  if (e.gagne && fin < 0) fin = im;
  if (fin >= 0 && im - fin >= 90) break;
}
if (fin < 0) { console.error("le film ne sort pas la boule : le niveau ou le script a changé"); process.exit(1); }

const tout = new Uint8Array(images.length * G.SW * G.SH);
images.forEach((o, k) => tout.set(o, k * o.length));
const film = {
  source: PAGE, niveau: N.titre, images: images.length, sortie_image: fin, tapes: e.tapes,
  grille: N.grille, vannes: G.vannes.map(v => ({ type: v.type, x: v.x, y: v.y })),
  W: G.W, H: G.H, S: G.S, rayon: L.RAYON,
  champ: Buffer.from(tout).toString("base64"), boule, actives,
};
writeFileSync(join(RACINE, SORTIE), JSON.stringify(film));
console.log(`${SORTIE} : ${images.length} images (${(images.length / 60).toFixed(1)} s), boule sortie à l'image ${fin}, ${e.tapes} tapes, ${(JSON.stringify(film).length / 1e6).toFixed(2)} Mo`);
