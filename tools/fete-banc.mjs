#!/usr/bin/env node
// ------------------------------------------------------------------
// fete-banc — LE BANC D'ESSAI DU PROTOTYPE « NUIT DE FÊTE ».
//
//   node tools/fete-banc.mjs                  les deux modes, 20 soirées par automate
//   node tools/fete-banc.mjs --mode=nuit --parties=40 --graine=100
//   node tools/fete-banc.mjs --detail         une ligne par soirée
//
// Le moteur du prototype (prototypes/prototype-nuit-de-fete.html, bloc
// <script id="moteur">) est extrait du fichier et joué sans navigateur, avec
// les réglages de son bloc JSON — jamais une copie de l'un ou de l'autre.
// Trois automates (PILOTES, dans le moteur) jouent chacun N soirées aux mêmes
// graines. Les invariants sont vérifiés à chaque pas, l'étalonnage à la fin.
// Le banc REFUSE (code de sortie 1) au lieu d'avertir.
//
// LES INVARIANTS — une violation est un bug du moteur, pas un réglage :
//   I1  la matière se conserve : générés = arrivés + refoulés ;
//       arrivés = sur les quais + embarqués + évacués ; embarqués = à bord
//   I2  aucun quai au-delà de sa capacité, aucun train au-delà de la sienne,
//       aucun compte négatif
//   I3  deux convois ne se chevauchent jamais (voitures à moins de 15 unités)
//   I4  la soirée se termine à l'heure dite
//
// L'ÉTALONNAGE — ce que la soirée doit être pour valoir d'être jugée :
//   E1  l'inerte ne gagne aucune étoile et voit des quais évacués : la
//       soirée mord, il faut jouer
//   E2  le stratège fait mieux que le glouton en moyenne : bien jouer paie
//       (seulement si la fluidité est active — sans elle, ils ne diffèrent
//       guère que par le hasard)
//   E3  le stratège a au moins 2 étoiles sur 80 % des soirées : la barre
//       n'est pas hors d'atteinte
//   E4  le glouton reste sous 2,5 étoiles en moyenne : trois étoiles ne
//       s'obtiennent pas en jouant sans réfléchir
//   E5  la vague met au moins un quai en danger dans 80 % des soirées du
//       glouton : la tension existe
//
// Les seuils d'étoiles du bloc JSON ont été posés sur les centiles de ces
// automates (29 septembre 2026, graines 1001 à 1040) : nuit, stratège p20 à
// 18 800 et médiane à 23 200, glouton médiane à 20 100 et p90 à 26 700.
// La boucle a deux bosses — une évacuation coûte 3 500 points, pénalité et
// prime perdue — : stratège p20 à 5 200 puis p30 à 8 500, glouton p30 à 4 900
// puis médiane à 8 400 ; trois étoiles y veulent une soirée sans évacuation,
// et une seule évacuation ne coûte qu'une étoile.
// Changer le jeu déplace ces centiles : le banc le dira.
// ------------------------------------------------------------------
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const FICHIER = "prototypes/prototype-nuit-de-fete.html";
const args = process.argv.slice(2);
const opt = n => { const a = args.find(x => x.startsWith("--" + n)); return a ? (a.split("=")[1] ?? true) : null; };
for (const a of args) if (!a.startsWith("--")) { console.error("argument inconnu : " + a); process.exit(2); }
const PARTIES = +(opt("parties") || 20);
const GRAINE = +(opt("graine") || 1);
const DETAIL = !!opt("detail");

const html = readFileSync(join(RACINE, FICHIER), "utf8");
function bloc(id) {
  const m = html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'));
  if (!m) { console.error("bloc introuvable dans " + FICHIER + " : " + id); process.exit(2); }
  return m[1];
}
const REGLAGES = JSON.parse(bloc("reglages"));
const ctx = createContext({ console });
runInContext(bloc("moteur") + "\n;globalThis.Fete = Fete;", ctx, { filename: "moteur.js" });
const Fete = ctx.Fete;
const MODES = opt("mode") ? [opt("mode")] : Object.keys(REGLAGES.modes);
for (const m of MODES) if (!REGLAGES.modes[m]) { console.error("mode inconnu : " + m); process.exit(2); }
const PILOTES = ["inerte", "glouton", "stratege"];

// --- une soirée -------------------------------------------------------------
function verifier(p, v) {
  const m = p.matiere(), t = p.t.toFixed(1);
  if (m.generes !== m.arrives + m.refoules) v.push(`I1 t=${t} : générés ${m.generes} ≠ arrivés ${m.arrives} + refoulés ${m.refoules}`);
  if (m.arrives !== m.surQuais + m.embarques + m.evacues) v.push(`I1 t=${t} : arrivés ${m.arrives} ≠ quais ${m.surQuais} + embarqués ${m.embarques} + évacués ${m.evacues}`);
  if (m.embarques !== m.aBord) v.push(`I1 t=${t} : embarqués ${m.embarques} ≠ à bord ${m.aBord}`);
  for (const q of p.quais) {
    if (q.file.total > q.capacite) v.push(`I2 t=${t} : quai ${q.id} à ${q.file.total}/${q.capacite}`);
    for (const d of p.idsDest) if (q.file.n[d] < 0) v.push(`I2 t=${t} : quai ${q.id}, ${d} négatif`);
  }
  for (const tr of p.trains) if (tr.aBord > tr.cap) v.push(`I2 t=${t} : train ${tr.id} à ${tr.aBord}/${tr.cap}`);
  const pos = p.trains.map(tr => p.voitures(tr));
  for (let a = 0; a < pos.length; a++) for (let b = a + 1; b < pos.length; b++)
    for (const ca of pos[a]) for (const cb of pos[b]) {
      const dx = ca.x - cb.x, dy = ca.y - cb.y;
      if (dx * dx + dy * dy < 225) {
        const A = p.trains[a], B = p.trains[b];
        v.push(`I3 t=${t} : trains ${A.id} (${A.etat} ${A.lien || A.dest}) et ${B.id} (${B.etat} ${B.lien || B.dest}) se chevauchent en (${ca.x.toFixed(0)}, ${ca.y.toFixed(0)})`);
        return;
      }
    }
}
function jouer(cfg, pilote, graine) {
  const p = new Fete.Partie(cfg, { graine, silencieux: true });
  const dt = 1 / 30, fin = cfg.duree + cfg.delaiFinal;
  const violations = [];
  let horloge = 0;
  while (!p.fini) {
    p.tick(dt);
    horloge -= dt;
    if (horloge <= 0) { Fete.PILOTES[pilote](p); horloge = 0.4; }
    verifier(p, violations);
    if (violations.length) break;
    if (p.t > fin + 1) { violations.push(`I4 : la soirée dure encore à t=${p.t.toFixed(1)}`); break; }
  }
  return { b: p.bilan(), violations };
}

// --- le banc ----------------------------------------------------------------
const moy = xs => xs.reduce((a, x) => a + x, 0) / (xs.length || 1);
const f0 = x => Math.round(x).toLocaleString("fr-FR");
const pc = x => Math.round(100 * x) + " %";
let echecs = 0;
const dire = (ok, texte) => { console.log((ok ? "  ✓ " : "  ✗ ") + texte); if (!ok) echecs++; };

for (const mode of MODES) {
  const cfg = REGLAGES.modes[mode];
  console.log(`\n${cfg.titre} (${mode}) — ${PARTIES} soirées par automate, graines ${GRAINE}…${GRAINE + PARTIES - 1}`);
  console.log("  seuils des étoiles : " + cfg.score.etoiles.map(f0).join(" · "));
  const res = {};
  for (const pilote of PILOTES) {
    const liste = [];
    for (let i = 0; i < PARTIES; i++) {
      const g = GRAINE + i, r = jouer(cfg, pilote, g);
      if (r.violations.length) {
        console.log(`  ✗ ${pilote}, graine ${g} :\n      ` + r.violations.slice(0, 4).join("\n      "));
        echecs++;
      }
      liste.push(r.b);
      if (DETAIL) console.log(`    ${pilote.padEnd(8)} g${String(g).padEnd(4)} ${f0(r.b.score).padStart(8)}  ${"★".repeat(r.b.etoiles).padEnd(3)}  ` +
        `transp. ${r.b.transportes}  rempl. ${pc(r.b.remplissage)}  ponct. ${pc(r.b.ponctualite)}  ×${r.b.comboMax}  évac. ${r.b.evacuations}  refoulés ${r.b.refoules}  renforts ${r.b.renforts}`);
    }
    res[pilote] = liste;
  }
  console.log("\n  automate    score moyen [min … max]      ★0 ★1 ★2 ★3   transp.  rempl.  ponct.  combo  évac.  refoulés  restés  renforts  trains (suppr.)");
  for (const pilote of PILOTES) {
    const L = res[pilote], sc = L.map(b => b.score), et = [0, 0, 0, 0];
    for (const b of L) et[b.etoiles]++;
    console.log("  " + pilote.padEnd(10) +
      f0(moy(sc)).padStart(9) + (" [" + f0(Math.min(...sc)) + " … " + f0(Math.max(...sc)) + "]").padEnd(22) +
      et.map(n => String(n).padStart(3)).join("") +
      f0(moy(L.map(b => b.transportes))).padStart(10) +
      pc(moy(L.map(b => b.remplissage))).padStart(8) +
      pc(moy(L.map(b => b.ponctualite))).padStart(8) +
      ("×" + moy(L.map(b => b.comboMax)).toFixed(1)).padStart(7) +
      moy(L.map(b => b.evacuations)).toFixed(1).padStart(7) +
      f0(moy(L.map(b => b.refoules))).padStart(10) +
      f0(moy(L.map(b => b.restes))).padStart(8) +
      moy(L.map(b => b.renforts)).toFixed(1).padStart(10) +
      (moy(L.map(b => b.trains)).toFixed(1) + " (" + moy(L.map(b => b.supprimes)).toFixed(1) + ")").padStart(15));
  }
  const etoilesMoy = p => moy(res[p].map(b => b.etoiles));
  console.log("");
  dire(res.inerte.every(b => b.etoiles === 0) && moy(res.inerte.map(b => b.evacuations)) >= 1,
    `E1 l'inerte : ${etoilesMoy("inerte").toFixed(2)} étoile en moyenne, ${moy(res.inerte.map(b => b.evacuations)).toFixed(1)} évacuations`);
  if (cfg.combo.actif) dire(moy(res.stratege.map(b => b.score)) > moy(res.glouton.map(b => b.score)),
    `E2 stratège ${f0(moy(res.stratege.map(b => b.score)))} contre glouton ${f0(moy(res.glouton.map(b => b.score)))}`);
  const deux = res.stratege.filter(b => b.etoiles >= 2).length / PARTIES;
  dire(deux >= 0.8, `E3 le stratège a 2 étoiles ou plus sur ${pc(deux)} des soirées`);
  dire(etoilesMoy("glouton") < 2.5, `E4 le glouton : ${etoilesMoy("glouton").toFixed(2)} étoiles en moyenne`);
  const tendues = res.glouton.filter(b => b.tempsDanger > 0).length / PARTIES;
  dire(tendues >= 0.8, `E5 un quai passe en danger dans ${pc(tendues)} des soirées du glouton (${moy(res.glouton.map(b => b.tempsDanger)).toFixed(0)} s en moyenne)`);
}
console.log(echecs ? `\n${echecs} échec(s).` : "\nTout est vert.");
process.exit(echecs ? 1 : 0);
