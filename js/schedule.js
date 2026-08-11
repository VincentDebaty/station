"use strict";
// ------------------------------------------------------------------
// Horaire aléatoire — regénéré à chaque partie, garanti jouable à zéro.
// Méthode : tirage des trains, puis simulation d'un « joueur parfait »
// (mêmes règles que le jeu) ; l'heure de départ officielle = l'heure de
// départ faisable + une marge de réaction pour l'humain.
// ------------------------------------------------------------------
const REACTION_MARGIN = 1.5;   // marge laissée au joueur (minutes de jeu)
// Densité globale du trafic (réglage transversal, toutes gares confondues) :
// on veut un jeu sans temps mort. Le service démarre plus tôt et les arrivées
// sont resserrées — quitte à ce que les convois fassent la queue sur la voie
// d'approche. Le calibrage « zéro retard possible » s'adapte (les départs sont
// repoussés en conséquence), donc la journée reste gagnable, juste plus dense.
const FIRST_ARRIVAL = [0.5, 1];   // 1re arrivée (était [1, 2]) : service plus tôt
const ARRIVAL_GAP_SCALE = 0.82;   // < 1 : écart entre arrivées resserré (~18 % plus dense)
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = arr => arr[Math.floor(Math.random() * arr.length)];

// Simulation headless de la journée : mêmes règles que le jeu
// (entrée dès que possible, arrêt minimum, relâchement par section,
// et les imprévus : arrivée retardée, quai fermé, transit de fret)
function simulateDay(schedule, assign, dt, events) {
  const closures = (events || []).filter(ev => ev.type === "closure");
  const sims = schedule.map((s, i) => ({
    ...s, plat: assign[i], state: "scheduled", elapsed: 0,
    actualArr: null, stopP: 1, entryPath: null, exitPath: null, depReal: null,
    // occStart/occEnd : fenêtre où le train occupe physiquement son quai
    // (de l'engagement jusqu'à la sortie complète) — sert à placer les
    // fermetures sur un quai réellement libre
    occStart: null, occEnd: null
  }));
  const active = {};
  const span = (t, pathId) => {
    const tail = (t.cars - 1) * CAR_SPACING;
    if (t.state === "movingThrough") {
      // fret : itinéraire entrée+sortie verrouillé, parcouru d'une traite
      const pin = paths[t.entryPath], pout = paths[t.exitPath];
      const totalArc = pin.len + pout.len;
      const durTot = TRAVEL * totalArc / 700 * FREIGHT_SLOWNESS;
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
          // FIFO sur la voie d'approche : un train du même portail, arrivé
          // avant lui, occupe encore la voie devant → il patiente derrière.
          // Pas de dépassement (même contrainte que le jeu). Le fret est dans
          // la file comme les autres : il attend son tour et retient les suivants.
          if (sims.some(o => o !== t && o.from === t.from &&
              o.state === "waiting" &&
              (o.arrEff ?? o.arr) < (t.arrEff ?? t.arr))) break;
          if (held[t.plat]) break;
          if (closures.some(c => c.plat === t.plat && now >= c.start && now < c.end)) break;
          // le quai visé est tenu dès l'attente (dans le jeu, l'affectation du
          // joueur le réserve : plus personne ne peut s'y glisser)
          held[t.plat] = true;
          const pid = "in:" + t.from + ":" + t.plat;
          if (t.freight) {
            // Le fret ne s'arrête pas : il lui faut entrée ET sortie d'un seul
            // tenant. depReal = l'instant où il s'engage (il n'a pas de départ
            // à tenir, mais le générateur s'en sert pour choisir son quai).
            const pout = "out:" + t.to + ":" + t.plat;
            if (free(pid) && free(pout)) {
              active[pid] = t; active[pout] = t;
              t.entryPath = pid; t.exitPath = pout;
              t.state = "movingThrough"; t.elapsed = 0;
              t.occStart = now; t.depReal = now;
            }
            break;
          }
          if (free(pid)) {
            active[pid] = t; t.entryPath = pid;
            t.stopP = 1; // tous les trains tirent jusqu'en tête de quai
            t.state = "movingIn"; t.elapsed = 0; t.occStart = now;
          }
          break;
        }
        case "movingThrough": {
          const pin = paths[t.entryPath], pout = paths[t.exitPath];
          const totalArc = pin.len + pout.len;
          const durTot = TRAVEL * totalArc / 700 * FREIGHT_SLOWNESS;
          t.elapsed += dt;
          const h = totalArc * t.elapsed / durTot;
          const tail = (t.cars - 1) * CAR_SPACING;
          if (h - tail > pin.len && active[t.entryPath] === t) delete active[t.entryPath];
          if (h - tail > totalArc) { t.state = "done"; delete active[t.exitPath]; t.occEnd = now; }
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
            t.state = "done"; delete active[t.exitPath]; t.occEnd = now;
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
  for (let attempt = 0; attempt < 10; attempt++) {
    const day = generateOnce();
    if (Math.max(...day.schedule.map(s => s.dep - (s.arrEff ?? s.arr))) > 15) continue;
    const res = simulateDay(day.schedule, day.schedule.map(s => s.hint), 0.005, day.events);
    // critère sur le retard TOTAL de la journée : le zéro affiché doit
    // être réellement atteignable, pas seulement train par train
    let tot = 0, ok = true;
    for (let i = 0; i < day.schedule.length; i++) {
      // un fret qui ne trouve jamais son créneau bloque la file derrière lui :
      // la journée n'est pas jouable, on la rejette (il n'a pas d'heure de
      // départ à tenir, donc il ne pèse pas dans le total de retard)
      if (res[i].depReal == null) { ok = false; break; }
      if (day.schedule[i].freight) continue;
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
  let arr = rnd(FIRST_ARRIVAL[0], FIRST_ARRIVAL[1]);
  for (let i = 0; i < n; i++) {
    const [from, to] = pick(PAIRS);
    draft.push({
      id: "T" + String(i + 1).padStart(2, "0"),
      from, to, cars: pick(GEN.cars),
      arr: Math.round(arr * 2) / 2, dep: 0
    });
    arr += rnd(GEN.gapMin, GEN.gapMax) * ARRIVAL_GAP_SCALE;
  }
  const lastArr = draft[draft.length - 1].arr;
  // 1c) les convois de fret : ils se présentent comme les autres (file
  // d'approche, aiguillage par le joueur) mais ne s'arrêtent pas — ils
  // verrouillent entrée + sortie d'un seul tenant le temps du transit, donc
  // ils mobilisent un quai ET deux itinéraires sans rien rapporter.
  const cross = PAIRS.filter(([a, b]) => PORTALS[a].side !== PORTALS[b].side);
  // COMBIEN : c'est la difficulté de la gare qui le dit — 1 fret au niveau 1,
  // 5 au niveau 5. Une fiche peut encore l'imposer (freightCount) pour les
  // gares « stress test ». Une gare TERMINUS n'en voit aucun : traverser sans
  // s'arrêter suppose d'entrer par un côté et de sortir par l'autre (cross est
  // alors vide). Les paires de PAIRS ont déjà un quai commun garanti.
  const nFreight = cross.length === 0 ? 0
    : (GEN.freightCount != null ? GEN.freightCount
       : Math.max(1, Math.min(5, STATION.difficulty || 1)));
  for (let f = 0; f < nFreight; f++) {
    const [from, to] = pick(cross);
    // Arrivées ÉTALÉES sur le service : un fret par tranche, sinon les cinq
    // se bousculent dans le même quart d'heure et la journée devient injouable.
    const lo = 6, hi = Math.max(lo + 2, lastArr - 4);
    const a = lo + (hi - lo) * f / nFreight, b = lo + (hi - lo) * (f + 1) / nFreight;
    const fArr = Math.round(rnd(a, b));
    draft.push({
      id: "F" + String(f + 1).padStart(2, "0"), freight: true, from, to,
      // 6-7 wagons : le convoi reste le plus long du plateau
      // (MAX_CARS = 7 côté voyageurs) sans immobiliser le gril trop longtemps.
      cars: 6 + Math.floor(rnd(0, 2)), arr: fArr, dep: fArr
    });
  }
  if (nFreight > 0) draft.sort((a, b) => a.arr - b.arr);
  // 1b) tirage des imprévus : ~20 % de journées calmes, sinon 1 ou 2 événements,
  //     intégrés au calibrage — le zéro retard reste garanti malgré eux
  const events = [];
  const hit = new Set(); // un train ne cumule pas deux événements
  const nEv = Math.random() < (GEN.quietRate ?? 0.2) ? 0 : pick([1, 1, 2]);
  // Les retards sont posés tout de suite ; les fermetures sont DIFFÉRÉES : on
  // ne les place qu'après le calibrage, sur un quai réellement libre (voir 4).
  let wantClosures = 0;
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
      wantClosures++;
    }
  }
  // 2) affectation gloutonne : pour chaque train, le quai qui le fait partir au plus tôt
  // (fret compris : lui aussi doit se poser sur un quai qui relie ses deux
  // portails, et le calibrage lui en cherche un qui ne gêne pas le service)
  const opts = draft.map(s => LINKS[s.from].filter(q => LINKS[s.to].includes(q)));
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
  for (let k = 0; k < 45; k++) {
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

  // 4) fermetures : on ne ferme JAMAIS un quai occupé. On relève l'occupation
  //    de chaque quai dans la solution de calibrage, puis on place chaque
  //    fermeture dans une fenêtre où le quai est réellement libre. Comme cette
  //    fenêtre n'entrave aucun mouvement de la solution, le zéro reste garanti.
  if (wantClosures > 0) {
    const horizon = Math.max(...draft.map(s => Math.max(s.arr, s.dep))) + 60;
    res = simulateDay(draft, assign, 0.01, events);
    const busy = {}; // quai -> intervalles [début, fin] d'occupation
    for (const q of PLATFORMS) busy[q.id] = [];
    const M = 0.5; // marge autour de l'occupation (jitter de simulation)
    for (const s of res) {
      if (s.occStart == null) continue;
      busy[s.plat].push([s.occStart - M, (s.occEnd == null ? horizon : s.occEnd) + M]);
    }
    const lo = 6, hi = Math.max(10, lastArr - 10), placed = [];
    for (let c = 0; c < wantClosures; c++) {
      const dur = Math.round(rnd(4, 7));
      // fenêtres libres candidates : trous entre les intervalles occupés
      // (fermetures déjà posées comprises) assez larges pour dur, et dont le
      // début autorise un démarrage dans [lo, hi]
      const cands = [];
      const addWindow = (q, from, to) => {
        // début possible ∈ [from, min(hi, to - dur)]
        const sMax = Math.min(hi, to - dur);
        if (sMax >= from) cands.push({ plat: q, from, sMax });
      };
      for (const q of PLATFORMS) {
        const iv = busy[q.id].concat(
          placed.filter(p => p.plat === q.id).map(p => [p.start, p.end]))
          .slice().sort((a, b) => a[0] - b[0]);
        let t = lo;
        for (const [a, b] of iv) {
          if (a > t) addWindow(q.id, t, a);
          t = Math.max(t, b);
          if (t > hi) break;
        }
        if (t <= hi) addWindow(q.id, t, hi + dur); // trou final, ouvert à droite
      }
      if (!cands.length) break; // aucun quai libre assez longtemps : on renonce
      const w = pick(cands);
      const start = Math.round(rnd(w.from, w.sMax));
      placed.push({ plat: w.plat, start, end: start + dur });
    }
    for (const p of placed) events.push({ type: "closure", plat: p.plat, start: p.start, end: p.end });
  }
  return { schedule: draft, events };
}

let SCHEDULE = [], EVENTS = [];
