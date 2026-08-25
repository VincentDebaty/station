// Combien de convois une grande gare peut-elle porter ? On balaie nMax sur les
// gares de fin de chapitre du ruban, et l'on mesure ce que gen-check mesure :
// retard garanti sous le placement idéal, pression maximale sur un quai,
// journées avec un train non plaçable, et le coût de génération.
import fs from "node:fs";
import vm from "node:vm";
import path from "node:path";
const ROOT = process.argv[2];
const read = p => fs.readFileSync(path.join(ROOT, p), "utf8");
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);
  t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
const mathShim = Object.create(Math);
const SEED = 11;
const reseed = () => { mathShim.random = mulberry32(SEED); };
reseed();
const sandbox = { Math: mathShim, console, JSON };
sandbox.self = { onmessage: null, postMessage(){} };
vm.createContext(sandbox);
vm.runInContext(read("js/engine.js"), sandbox, { filename: "engine.js" });
vm.runInContext(read("js/schedule.js"), sandbox, { filename: "schedule.js" });
vm.runInContext(read("js/ruban.js"), sandbox, { filename: "ruban.js" });

const idx = JSON.parse(read("data/stations/index.json"));
const ou = {}; for (const g of idx) for (const s of g.stations) ou[s] = g.country;
const carte = JSON.parse(read("data/cartes/europe.json"));
const grandes = ['bruxelles-midi','koln','hamburg','munchen','berlin'].filter(g => ou[g]);

const simulateDay = vm.runInContext("simulateDay", sandbox);
const platformPressure = vm.runInContext("platformPressure", sandbox);
const K = 10;
const PALIERS = [22, 28, 34, 40];
const BUDGET = 45000;  // ms par cellule : au-delà, la génération est le verdict

console.log("Gares de fin de chapitre — ce qu'elles portent (K=%d journées, graine %d)\n", K, SEED);
console.log("gare".padEnd(16) + "quais".padEnd(7) + "dest".padEnd(6) +
  PALIERS.map(n => ("n=" + n).padEnd(22)).join(""));
console.log("".padEnd(29) + PALIERS.map(() => "retard  file  ✗j   ms".padEnd(22)).join(""));
console.log("-".repeat(29 + PALIERS.length * 22));

for (const id of grandes) {
  const base = JSON.parse(read(`data/stations/${ou[id]}/${id}.json`));
  const quais = (base.platforms || []).length;
  const dest = Object.keys(base.portals || {}).length;
  let ligne = id.padEnd(16) + String(quais).padEnd(7) + String(dest).padEnd(6);
  for (const n of PALIERS) {
    sandbox.__cfg = base;
    const gen = vm.runInContext(`enveloppeDe(this.__cfg, 5, PROFILS[1])`, sandbox);
    const cfg = { ...base, difficulty: 5, gen: { ...gen, nMin: n, nMax: n } };
    reseed();
    vm.runInContext("loadStation(" + JSON.stringify(cfg) + ")", sandbox);
    let worst = 0, qMax = 0, unpl = 0, err = 0;
    const t0 = Date.now();
    let coupe = false;
    for (let k = 0; k < K; k++) {
      if (Date.now() - t0 > BUDGET) { coupe = true; break; }
      try {
        const day = vm.runInContext("generateSchedule()", sandbox);
        const res = simulateDay(day.schedule, day.schedule.map(s => s.hint), 0.01, day.events);
        let tot = 0, u = 0;
        for (let i = 0; i < day.schedule.length; i++) {
          if (day.schedule[i].freight) continue;
          if (res[i].depReal == null) { u++; continue; }
          tot += Math.max(0, res[i].depReal - day.schedule[i].dep);
        }
        worst = Math.max(worst, tot); if (u) unpl++;
        qMax = Math.max(qMax, platformPressure(day.schedule, res));
      } catch (e) { err++; }
    }
    const ms = Math.round((Date.now() - t0) / K);
    const cell = (err ? "ERR" : coupe ? ">" + (BUDGET / 1000) + "s" : worst.toFixed(2)).padEnd(8) +
      String(qMax).padEnd(6) + String(unpl).padEnd(5) + String(ms).padEnd(5);
    ligne += cell.padEnd(22);
  }
  console.log(ligne);
}
console.log("\nretard = retard garanti sous placement idéal (gen-check refuse > 0,30)");
console.log("file   = pression maximale sur un quai (gen-check : 4 toléré, 6 jamais)");
console.log("✗j     = journées avec un train non plaçable · ms = coût moyen d'une journée");
