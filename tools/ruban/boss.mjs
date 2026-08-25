// L'ENVELOPPE DE BOSS. On ne cherche pas plus de convois — la mesure a montré
// que le mur tombe entre 28 et 34 (retard garanti au-dessus de 0,30, génération
// à 5 s la journée). On cherche plus de PRESSION à volume tenable : un peu plus
// de trafic, une courbe d'affluence marquée, et du fret en plus.
import fs from "node:fs"; import vm from "node:vm"; import path from "node:path";
const ROOT = process.argv[2];
const read = p => fs.readFileSync(path.join(ROOT, p), "utf8");
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);
  t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
const mathShim = Object.create(Math); const SEED = 11;
const reseed = () => { mathShim.random = mulberry32(SEED); }; reseed();
const sandbox = { Math: mathShim, console, JSON };
sandbox.self = { onmessage: null, postMessage(){} };
vm.createContext(sandbox);
for (const f of ["js/engine.js","js/schedule.js","js/ruban.js"])
  vm.runInContext(read(f), sandbox, { filename: f });
const idx = JSON.parse(read("data/stations/index.json"));
const ou = {}; for (const g of idx) for (const s of g.stations) ou[s] = g.country;
const simulateDay = vm.runInContext("simulateDay", sandbox);
const platformPressure = vm.runInContext("platformPressure", sandbox);
const K = 14;
const GARES = ["bruxelles-midi","koln","hamburg","munchen","berlin","frankfurt","hannover"];
// Les candidates. « actuel » = ce que le niveau 5 produit aujourd'hui.
const CANDIDATES = [
  { nom: "actuel  n18-22 pointe f5", nMin:18, nMax:22, rush:"pointe", fret:5, gapMin:1.52, gapMax:2.58 },
  { nom: "boss A  n22-26 rafale f6", nMin:22, nMax:26, rush:"rafale", fret:6, gapMin:1.48, gapMax:2.48 },
  { nom: "boss B  n24-28 rafale f6", nMin:24, nMax:28, rush:"rafale", fret:6, gapMin:1.45, gapMax:2.40 },
  { nom: "boss C  n22-26 double f7", nMin:22, nMax:26, rush:"double", fret:7, gapMin:1.48, gapMax:2.48 },
];
console.log("L'enveloppe de boss — %d gares de fin de chapitre, K=%d journées, graine %d\n", GARES.length, K, SEED);
console.log("candidate".padEnd(26) + "retard".padEnd(9) + "file max".padEnd(10) +
  "file moy".padEnd(10) + "j>4".padEnd(6) + "non plaç.".padEnd(11) + "ms/journée");
console.log("-".repeat(80));
for (const c of CANDIDATES) {
  let worst = 0, qMax = 0, qSum = 0, days = 0, qHigh = 0, unpl = 0, ms = 0, err = 0;
  for (const id of GARES) {
    const base = JSON.parse(read(`data/stations/${ou[id]}/${id}.json`));
    const cfg = { ...base, difficulty: 5, gen: { ...(base.gen||{}),
      nMin:c.nMin, nMax:c.nMax, gapMin:c.gapMin, gapMax:c.gapMax, freightCount:c.fret, rush:c.rush } };
    reseed();
    vm.runInContext("loadStation(" + JSON.stringify(cfg) + ")", sandbox);
    const t0 = Date.now();
    for (let k = 0; k < K; k++) {
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
        const q = platformPressure(day.schedule, res);
        qMax = Math.max(qMax, q); qSum += q; days++; if (q > 4) qHigh++;
      } catch (e) { err++; }
    }
    ms += Date.now() - t0;
  }
  console.log(c.nom.padEnd(26) + (err ? "ERR" : worst.toFixed(2)).padEnd(9) +
    String(qMax).padEnd(10) + (qSum/Math.max(1,days)).toFixed(2).padEnd(10) +
    String(qHigh).padEnd(6) + String(unpl).padEnd(11) + Math.round(ms/(K*GARES.length)));
}
console.log("\nretard : gen-check refuse > 0,30 · file : 4 toléré, 6 jamais · j>4 : journées au-dessus du seuil");
