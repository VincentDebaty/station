#!/usr/bin/env node
// ------------------------------------------------------------------
// ecluses-vers-godot — CE QUE LA TRANCHE GODOT D'ÉCLUSES LIT, DÉRIVÉ DE LA PAGE.
//
//   node tools/ecluses-vers-godot.mjs
//
// La page web (prototypes/prototype-ecluses.html) reste la seule source des
// niveaux et des règles. Cet outil en DÉRIVE, dans prototypes/ecluses-godot/ :
//   niveaux.json   le bloc JSON « niveaux », tel quel
//   oracle.json    des parties de référence jouées par le moteur JS : la
//                  solution de chaque niveau, puis des parties au hasard
//                  graînées, avec l'état complet après chaque coup — et,
//                  pour les niveaux à portes sans fleuve, le verdict
//                  d'impasse du solveur (1 impasse, 0 soluble, -1 sans
//                  conclusion) et celui de blocage (1 : plus aucun bateau
//                  ne pourra bouger — c'est lui que la tranche affiche par
//                  un « ! » et une carte d'échec)
// puis oracle.gd (godot --headless --path prototypes/ecluses-godot
// --script res://oracle.gd) vérifie que le moteur GDScript rejoue chacune au
// millionième près. Relancer après avoir touché aux niveaux ou au moteur JS.
// ------------------------------------------------------------------
import { readFileSync, writeFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RACINE = join(dirname(fileURLToPath(import.meta.url)), "..");
const html = readFileSync(join(RACINE, "prototypes/prototype-ecluses.html"), "utf8");
const bloc = id => html.match(new RegExp('<script[^>]*id="' + id + '"[^>]*>([\\s\\S]*?)</script>'))[1];
const texte = bloc("niveaux");
const D = JSON.parse(texte);
const ctx = createContext({ console });
runInContext(bloc("moteur") + "\n;globalThis.Ecluses = Ecluses;", ctx);
const E = ctx.Ecluses;

function Hasard(graine) {
  let a = (graine >>> 0) || 1;
  return () => {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const photo = (e, r) => ({
  niv: e.niv, ouvert: e.ouvert, crete: e.crete, bateaux: e.bateaux, coups: e.coups, obj: e.obj, phase: e.phase, moulu: e.moulu,
  entree: e.entree, sortie: e.sortie, lache: e.lache,
  flux: r ? r.flux : null, dep: r ? r.dep : null
});
const parties = [];
for (const N of D.niveaux) {
  const jeux = [E.resoudre(N, null, 1500000).chemin];
  for (let g = 1; g <= 12; g++) {
    const h = Hasard(g * 7919 + N.id.charCodeAt(0) * 31 + N.id.charCodeAt(2));
    let e = E.charger(N);
    const seq = [];
    for (let c = 0; c < 14; c++) {
      const A = E.actions(N, e);
      if (!A.length) break;
      const a = A[Math.floor(h() * A.length)];
      seq.push(a);
      e = E.jouer(N, e, a).etat;
    }
    jeux.push(seq);
  }
  for (const seq of jeux) {
    let e = E.charger(N);
    const pas = [{ action: null, ...photo(e, null), verdict: E.verdict(N, e) || {} }];
    const avecImpasse = N.mode === "pas" && !N.bassins.some(b => b.apport);
    const impasse = e => {
      const r = E.resoudre(N, e, 25000, null, { quantum: 0.01 });
      return r.chemin ? 0 : (r.epuise ? 1 : -1);
    };
    const bloque = e => E.bloque(N, e, 25000, { quantum: 0.01 });
    if (avecImpasse) { pas[0].impasse = impasse(e); pas[0].bloque = bloque(e); }
    for (const a of seq) {
      const r = E.jouer(N, e, a);
      e = r.etat;
      const p = { action: a, ...photo(e, r), verdict: E.verdict(N, e) || {} };
      if (avecImpasse) { p.impasse = impasse(e); p.bloque = bloque(e); }
      pas.push(p);
    }
    parties.push({ niveau: N.id, pas });
  }
}
const SORTIE = join(RACINE, "prototypes/ecluses-godot");
writeFileSync(join(SORTIE, "niveaux.json"), texte.trim() + "\n");
writeFileSync(join(SORTIE, "oracle.json"), JSON.stringify({ parties }) + "\n");
console.log(`niveaux.json : ${D.niveaux.length} niveaux ; oracle.json : ${parties.length} parties, ${parties.reduce((s, p) => s + p.pas.length - 1, 0)} coups.`);
