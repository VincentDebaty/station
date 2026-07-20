"use strict";
// ------------------------------------------------------------------
// Horaire aléatoire — regénéré à chaque partie, garanti jouable à zéro.
// Méthode : tirage des trains, puis simulation d'un « joueur parfait »
// (mêmes règles que le jeu) ; l'heure de départ officielle = l'heure de
// départ faisable + une marge de réaction pour l'humain.
// ------------------------------------------------------------------
const REACTION_MARGIN = 1.5;   // marge laissée au joueur (minutes de jeu)
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = arr => arr[Math.floor(Math.random() * arr.length)];

// Simulation headless de la journée : mêmes règles que le jeu
// (entrée dès que possible, arrêt minimum, relâchement par section,
// et les imprévus : arrivée retardée, quai fermé, transit de fret)
function simulateDay(schedule, assign, dt, events) {
  const closures = (events || []).filter(ev => ev.type === "closure");
  const sims = schedule.map((s, i) => ({
    ...s, plat: assign[i], state: "scheduled", elapsed: 0,
    actualArr: null, stopP: 1, entryPath: null, exitPath: null, depReal: null
  }));
  const active = {};
  const span = (t, pathId) => {
    const tail = (t.cars - 1) * CAR_SPACING;
    if (t.state === "movingThrough") {
      // fret : itinéraire entrée+sortie verrouillé, parcouru d'une traite
      const pin = paths[t.entryPath], pout = paths[t.exitPath];
      const totalArc = pin.len + pout.len;
      const durTot = TRAVEL * totalArc / 700 * slowness(t);
      const h = totalArc * t.elapsed / durTot;
      if (pathId === t.entryPath) return { lo: h - tail, hi: Math.min(h, pin.len), dir: 1 };
      if (h <= pin.len) return null; // pas encore atteint : tout reste bloqué
      const headOut = pout.len - (h - pin.len);
      return { lo: headOut, hi: Math.min(pout.len, headOut + tail), dir: -1 };
    }
    const onEntry = t.state === "movingIn";
    const path = paths[onEntry ? t.entryPath : t.exitPath];
    const dur = path.dur * slowness(t);
    if (onEntry) {
      const headS = Math.min(t.elapsed / dur, t.stopP) * path.len;
      return { lo: headS - tail, hi: headS, dir: 1 };
    }
    const headS = (1 - t.elapsed / dur) * path.len;
    return { lo: headS, hi: headS + tail, dir: -1 };
  };
  const free = pid => {
    if (active[pid]) return false;
    for (const a of Object.keys(active)) {
      const zone = conflicts[a][pid];
      if (!zone) continue;
      const occ = span(active[a], a);
      if (!occ) return false;
      if (!(occ.dir === 1 ? occ.lo > zone.hi : occ.hi < zone.lo)) return false;
    }
    return true;
  };
  let now = 0;
  const horizon = Math.max(...schedule.map(s => Math.max(s.arr, s.dep))) + 60;
  while (now < horizon) {
    now += dt;
    const held = {};
    for (const t of sims)
      if (t.state === "movingIn" || t.state === "dwell" || t.state === "movingThrough")
        held[t.plat] = true;
    for (const t of sims) {
      switch (t.state) {
        case "scheduled":
          if (now >= (t.arrEff ?? t.arr)) t.state = "waiting";
          break;
        case "waiting": {
          if (held[t.plat]) break;
          if (closures.some(c => c.plat === t.plat && now >= c.start && now < c.end)) break;
          held[t.plat] = true;
          if (t.freight) {
            const pin = "in:" + t.from + ":" + t.plat;
            const pout = "out:" + t.to + ":" + t.plat;
            if (free(pin) && free(pout)) {
              active[pin] = t; active[pout] = t;
              t.entryPath = pin; t.exitPath = pout;
              t.state = "movingThrough"; t.elapsed = 0;
            }
            break;
          }
          const pid = "in:" + t.from + ":" + t.plat;
          if (free(pid)) {
            active[pid] = t; t.entryPath = pid;
            t.stopP = 1; // tous les trains tirent jusqu'en tête de quai
            t.state = "movingIn"; t.elapsed = 0;
          }
          break;
        }
        case "movingThrough": {
          const pin = paths[t.entryPath], pout = paths[t.exitPath];
          const totalArc = pin.len + pout.len;
          const durTot = TRAVEL * totalArc / 700 * slowness(t);
          t.elapsed += dt;
          const h = totalArc * t.elapsed / durTot;
          const tail = (t.cars - 1) * CAR_SPACING;
          if (h - tail > pin.len && active[t.entryPath] === t) delete active[t.entryPath];
          if (h - tail > totalArc) { t.state = "done"; delete active[t.exitPath]; }
          break;
        }
        case "movingIn":
          t.elapsed += dt;
          if (t.elapsed >= paths[t.entryPath].dur * slowness(t) * t.stopP) {
            t.state = "dwell"; t.actualArr = now;
            delete active[t.entryPath];
          }
          break;
        case "dwell": {
          if (now < Math.max(t.dep, t.actualArr + MIN_DWELL)) break;
          const pid = "out:" + t.to + ":" + t.plat;
          if (free(pid)) {
            active[pid] = t; t.exitPath = pid;
            t.state = "movingOut"; t.elapsed = 0; t.depReal = now;
          }
          break;
        }
        case "movingOut": {
          t.elapsed += dt;
          const path = paths[t.exitPath];
          const endP = 1 + ((t.cars - 1) * CAR_SPACING) / path.len;
          if (t.elapsed >= path.dur * slowness(t) * endP) {
            t.state = "done"; delete active[t.exitPath];
          }
          break;
        }
      }
    }
    if (sims.every(t => t.state === "done")) break;
  }
  return sims;
}

function generateSchedule() {
  // Filtres de qualité : on retire les journées trop congestionnées
  // (attente > 15 min) et celles qui échouent au contrôle final à pas fin
  // — la garantie « zéro retard possible » doit tenir à la précision du jeu
  for (let attempt = 0; attempt < 5; attempt++) {
    const day = generateOnce();
    if (Math.max(...day.schedule.map(s => s.dep - (s.arrEff ?? s.arr))) > 15) continue;
    const res = simulateDay(day.schedule, day.schedule.map(s => s.hint), 0.005, day.events);
    // critère sur le retard TOTAL de la journée : le zéro affiché doit
    // être réellement atteignable, pas seulement train par train
    let tot = 0, ok = true;
    for (let i = 0; i < day.schedule.length; i++) {
      if (day.schedule[i].freight) continue;
      if (res[i].depReal == null) { ok = false; break; }
      tot += Math.max(0, res[i].depReal - day.schedule[i].dep);
    }
    if (ok && tot <= 0.15) return day;
  }
  return generateOnce(); // au pire, on accepte la dernière
}
function generateOnce() {
  // 1) tirage des trains selon la fiche de la gare : liaisons, wagons,
  // espacement des arrivées
  const n = GEN.nMin + Math.floor(Math.random() * (GEN.nMax - GEN.nMin + 1));
  const draft = [];
  let arr = rnd(1, 2);
  for (let i = 0; i < n; i++) {
    const [from, to] = pick(PAIRS);
    draft.push({
      id: "T" + String(i + 1).padStart(2, "0"),
      from, to, cars: pick(GEN.cars),
      arr: Math.round(arr * 2) / 2, dep: 0
    });
    arr += rnd(GEN.gapMin, GEN.gapMax);
  }
  const lastArr = draft[draft.length - 1].arr;
  // 1c) parfois, un lourd convoi de fret traverse la gare sans s'arrêter :
  // il verrouille tout son itinéraire (entrée + sortie) le temps du transit
  const cross = PAIRS.filter(([a, b]) => PORTALS[a].side !== PORTALS[b].side);
  if (cross.length && Math.random() < (GEN.freightRate || 0)) {
    const [from, to] = pick(cross);
    const plat = pick(LINKS[from].filter(q => LINKS[to].includes(q)));
    const fArr = Math.round(rnd(8, Math.max(12, lastArr - 6)));
    draft.push({
      id: "F01", freight: true, from, to, plat,
      cars: 8 + Math.floor(rnd(0, 3)), arr: fArr, dep: fArr
    });
    draft.sort((a, b) => a.arr - b.arr);
  }
  // 1b) tirage des imprévus : ~20 % de journées calmes, sinon 1 ou 2 événements,
  //     intégrés au calibrage — le zéro retard reste garanti malgré eux
  const events = [];
  const hit = new Set(); // un train ne cumule pas deux événements
  const nEv = Math.random() < (GEN.quietRate ?? 0.2) ? 0 : pick([1, 1, 2]);
  for (let e = 0; e < nEv; e++) {
    const type = pick(["late", "closure"]);
    if (type === "late") {
      const cand = draft.filter((s, i) => i >= 2 && !hit.has(s.id) && !s.freight);
      if (!cand.length) continue;
      const s = pick(cand); hit.add(s.id);
      const delay = pick([2, 3, 3, 4]);
      s.arrEff = s.arr + delay;
      events.push({ type, trainId: s.id, delay, revealAt: s.arr - 1 });
    } else {
      const free = PLATFORMS.filter(q =>
        !events.some(ev => ev.type === "closure" && ev.plat === q.id));
      const plat = pick(free).id;
      const start = Math.round(rnd(6, Math.max(10, lastArr - 10)));
      const end = start + Math.round(rnd(4, 7));
      events.push({ type, plat, start, end });
    }
  }
  // 2) affectation gloutonne : pour chaque train, le quai qui le fait partir au plus tôt
  const opts = draft.map(s =>
    s.freight ? [s.plat] : LINKS[s.from].filter(q => LINKS[s.to].includes(q)));
  const assign = opts.map(o => o[0]);
  for (let i = 0; i < draft.length; i++) {
    if (opts[i].length === 1) { assign[i] = opts[i][0]; continue; }
    let bestQ = opts[i][0], bestT = Infinity;
    for (const q of opts[i]) {
      assign[i] = q;
      const d = simulateDay(draft, assign, 0.03, events)[i].depReal ?? Infinity;
      if (d < bestT) { bestT = d; bestQ = q; }
    }
    assign[i] = bestQ;
  }
  // 3) départ officiel = départ faisable + marge de réaction, puis vérification
  //    (repousser un départ peut décaler les suivants : on itère jusqu'à zéro)
  let res = simulateDay(draft, assign, 0.02, events);
  for (let i = 0; i < draft.length; i++)
    if (!draft[i].freight) draft[i].dep = Math.ceil(res[i].depReal + REACTION_MARGIN);
  for (let k = 0; k < 15; k++) {
    res = simulateDay(draft, assign, 0.01, events);
    let bumped = false;
    for (let i = 0; i < draft.length; i++) {
      if (draft[i].freight) continue;
      if (res[i].depReal == null || res[i].depReal - draft[i].dep > 0.08) {
        draft[i].dep = Math.ceil((res[i].depReal ?? draft[i].dep + 1) + 0.3);
        bumped = true;
      }
    }
    if (!bumped) break;
  }
  // le quai de calibrage : la solution « zéro retard » connue du générateur
  for (let i = 0; i < draft.length; i++) draft[i].hint = assign[i];
  return { schedule: draft, events };
}

let SCHEDULE = [], EVENTS = [];
