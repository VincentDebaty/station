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

// ------------------------------------------------------------------
// LA FILE SUR UN QUAI — la seule congestion qui gâche une journée.
// ------------------------------------------------------------------
// Attendre dehors ne coûte rien : c'est la règle du jeu, et c'est ce qui rend
// l'aiguillage intéressant. Mais attendre dehors DERRIÈRE CINQ AUTRES, tous
// pour le même quai, n'est plus un choix — c'est une file, et le joueur ne fait
// plus que regarder. Le calibrage ne le voyait pas : il se contente de repousser
// les départs officiels, si bien qu'une journée en file reste « zéro retard
// possible » et passait tous les contrôles.
//
// Trois causes, traitées ensemble parce qu'aucune ne suffit :
//   1. le tirage origine/destination était uniforme et sans mémoire — rien
//      n'empêchait six relations de suite de viser le même quai ;
//   2. beaucoup de relations n'ont QU'UN SEUL quai commun (LINKS[a] ∩ LINKS[b]),
//      donc même un tirage varié peut s'entasser ;
//   3. l'affectation gloutonne n'optimisait que « qui repart le plus tôt »,
//      sans jamais répartir la charge.
//
// PLAT_TAU : combien de temps un convoi PÈSE sur son quai. Ce n'est pas sa durée
// d'occupation exacte (elle dépend de la longueur du convoi et du trafic) mais
// l'ordre de grandeur qui compte pour le tirage — arrêt minimum plus dégagement.
const PLAT_TAU = 6;              // minutes de jeu
// Ce qu'on accepte au bout du compte. La cible est 3 ; 4 est le repli des gares
// dont la géométrie ne permet pas mieux. Au-delà, la journée est rejetée.
const QUEUE_MAX = 3;
const QUEUE_MAX_FALLBACK = 4;
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = arr => arr[Math.floor(Math.random() * arr.length)];

// ------------------------------------------------------------------
// Forme de la journée : la courbe d'affluence
// ------------------------------------------------------------------
// Jusqu'ici les arrivées se tiraient avec un écart uniforme du premier au
// dernier convoi : la pression était PLATE d'un bout à l'autre du service — ni
// accalmie, ni coup de feu, ni retombée. Or un poste d'aiguillage, c'est fait
// de pointes : c'est là que naissent la tension et le souvenir d'une partie.
//
// On module donc l'écart entre arrivées par une densité d(u), où u est la
// position dans le service (0 = premier convoi, 1 = dernier). L'écart est
// DIVISÉ par d : une densité de 2 rapproche les arrivées deux fois plus.
//
// La courbe est NORMALISÉE (cf. rushWeights) : la durée totale du service reste
// en moyenne celle d'avant, seule sa RÉPARTITION change. Sans cette
// renormalisation, une gare à pointe étirerait ou raccourcirait sa journée et
// sortirait des enveloppes de calibrage mesurées gare par gare.
//
// Le profil est une propriété de la FICHE de gare (`gen.rush`) : c'est un
// caractère, pas un hasard. Une desserte de banlieue respire deux fois par
// jour, un nœud de transit reste tendu du début à la fin — même moteur,
// sensation différente, sans toucher à la géométrie.
const bell = (u, c, w) => Math.exp(-(((u - c) / w) ** 2));
// Amplitudes calibrées sur la mesure qui compte : le nombre de convois présents
// dans une fenêtre GLISSANTE de 5 minutes de jeu (compter par fraction du
// service ne mesure rien — chaque sixième contient n/6 trains par
// construction). Repère sur une gare à 18 convois : le service plat oscille
// entre 2 et 3 par tranche de 5 min ; « pointe » descend à 2 au creux et monte
// à 5 au sommet. Les courbes sont volontairement un peu marquées : le tirage
// aléatoire des écarts (gapMin..gapMax) en gomme une partie.
const RUSH = {
  plat:   _ => 1,                                    // pression constante (comportement d'avant)
  pointe: u => 1 + 1.80 * bell(u, 0.55, 0.21),       // une pointe nette au milieu — défaut
  double: u => 1 + 1.60 * bell(u, 0.24, 0.13)        // deux pointes : matin et soir
                 + 1.90 * bell(u, 0.74, 0.14),
  rafale: u => 1 + 2.60 * bell(u, 0.78, 0.15)        // long calme, puis bourrasque finale
};
const RUSH_DEFAULT = "pointe";
// Poids d'écart, un par convoi : 1/d, renormalisés pour que leur MOYENNE vaille
// exactement 1. C'est cette renormalisation qui préserve la durée du service.
function rushWeights(n) {
  const f = RUSH[(GEN && GEN.rush) || RUSH_DEFAULT] || RUSH[RUSH_DEFAULT];
  const w = [];
  for (let i = 0; i < n; i++) w.push(1 / f((i + 0.5) / n));
  const mean = w.reduce((a, b) => a + b, 0) / (n || 1);
  return w.map(x => x / mean);
}

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
          if (!free(pid)) break;
          // CANTONNEMENT du fret (même règle que le jeu) : il s'engage dès que
          // sa voie d'entrée et le quai sont libres. Si sa sortie l'est aussi,
          // il verrouille tout et traverse d'une traite ; sinon il entre comme
          // un voyageur et s'arrêtera au quai jusqu'à ce qu'elle se dégage.
          // depReal = l'instant où il s'engage (il n'a pas de départ à tenir,
          // mais le générateur s'en sert pour choisir son quai).
          if (t.freight) {
            const pout = "out:" + t.to + ":" + t.plat;
            t.depReal = now;
            if (free(pout)) {
              active[pid] = t; active[pout] = t;
              t.entryPath = pid; t.exitPath = pout;
              t.state = "movingThrough"; t.elapsed = 0; t.occStart = now;
              break;
            }
          }
          active[pid] = t; t.entryPath = pid;
          t.stopP = 1; // tous les trains tirent jusqu'en tête de quai
          t.state = "movingIn"; t.elapsed = 0; t.occStart = now;
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
          // le fret ne stationne pas : il repart dès que sa sortie se libère
          if (!t.freight && now < Math.max(t.dep, t.actualArr + MIN_DWELL)) break;
          const pid = "out:" + t.to + ":" + t.plat;
          if (free(pid)) {
            active[pid] = t; t.exitPath = pid;
            t.state = "movingOut"; t.elapsed = 0;
            if (!t.freight) t.depReal = now;
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

// ------------------------------------------------------------------
// PRESSION SUR UN QUAI — combien de convois l'attendent EN MÊME TEMPS.
// ------------------------------------------------------------------
// La fenêtre d'un convoi court de son ARRIVÉE — l'instant où il se présente et
// commence à peser, même s'il patiente sur la voie d'approche — à la fin de son
// occupation du quai. Compter depuis l'entrée en gare ne mesurerait que la file
// visible et manquerait justement ceux qui font la queue dehors, c'est-à-dire
// tout le problème.
//
// Balayage : +1 par début, −1 par fin, le maximum courant est la pression. À
// instant égal les fins passent AVANT les débuts (le tri sur le delta s'en
// charge), sinon deux convois qui se relaient proprement compteraient pour deux.
function platformPressure(schedule, res) {
  let worst = 0;
  for (const q of PLATFORMS) {
    const evs = [];
    for (let i = 0; i < schedule.length; i++) {
      if (res[i].plat !== q.id) continue;
      const a = schedule[i].arrEff ?? schedule[i].arr;
      const b = res[i].occEnd ?? res[i].depReal ?? a;
      evs.push([a, 1], [b, -1]);
    }
    evs.sort((x, y) => x[0] - y[0] || x[1] - y[1]);
    let cur = 0;
    for (const [, d] of evs) { cur += d; if (cur > worst) worst = cur; }
  }
  return worst;
}

function generateSchedule() {
  // Filtres de qualité, dans l'ordre du plus rédhibitoire au plus fin :
  //   • attente > 15 min : la journée est engorgée, on n'en veut à aucun prix ;
  //   • contrôle final à pas fin : la garantie « zéro retard possible » doit
  //     tenir à la précision du jeu, pas seulement à celle du calibrage ;
  //   • PRESSION SUR UN QUAI : la journée est jouable à zéro mais ne se joue
  //     pas — on y attend, on n'y aiguille pas. Voir platformPressure.
  //
  // La pression se demande en DEUX TEMPS. La cible (3) est ce qu'on veut ; le
  // repli (4) est ce qu'on accepte des gares dont la géométrie ne permet pas
  // mieux — Bettembourg, Malines et Leeds ont trop de relations à quai unique
  // pour tenir 3 à tous les coups. Exiger la cible partout reviendrait à
  // épuiser les essais puis à rendre n'importe quoi, ce qui est pire.
  //
  // LE PALIER STRICT EST COURT, ET C'EST TOUT LE RÉGLAGE. Une gare qui peut
  // tenir 3 y arrive en un ou deux essais — le tirage sous pression l'y amène
  // presque toujours du premier coup. En insister douze fois, on ne gagnait
  // rien sur celles-là et on payait douze calibrages complets sur celles qui ne
  // le peuvent pas : Bruxelles-Midi passait de 2,2 à 5,5 secondes par journée,
  // sous les yeux du joueur. Quatre essais suffisent à faire la différence
  // entre « peut tenir 3 » et « ne le peut pas ».
  //
  // Et l'on ne rend JAMAIS une journée non vérifiée : à défaut de trouver
  // mieux, on garde la moins congestionnée de celles qui ont passé le reste.
  // LE BUDGET SE COMPTE EN JOURNÉES ÉVALUABLES, PAS EN TIRAGES.
  //
  // La boucle rend la première journée qui passe : sur une gare tranquille elle
  // sort au premier tour et le plafond ne coûte rien. Mais sur les plus
  // chargées — Bruxelles-Midi, Bettembourg, Malines — le contrôle d'attente
  // rejette presque TOUS les tirages, bien avant qu'on parle de pression. Y
  // insister vingt-quatre fois ne trouvait rien de plus et faisait passer la
  // préparation de 2,2 à 4,7 secondes, sous les yeux du joueur.
  //
  // On garde donc les vingt-quatre tirages pour les gares où le filtre sert
  // vraiment, et l'on abandonne tôt là où il n'a rien à filtrer : dix tirages
  // sans une seule journée évaluable disent que ce n'est pas la pression qui
  // bloque, et que le temps du joueur est mieux employé ailleurs.
  let best = null, bestQ = Infinity, seen = 0;
  for (let attempt = 0; attempt < 24; attempt++) {
    if (attempt >= 10 && seen === 0) break;
    const day = generateOnce();
    if (Math.max(...day.schedule.map(s => s.dep - (s.arrEff ?? s.arr))) > 15) continue;
    const res = simulateDay(day.schedule, day.schedule.map(s => s.hint), 0.005, day.events);
    // critère sur le retard TOTAL de la journée : le zéro affiché doit
    // être réellement atteignable, pas seulement train par train
    let tot = 0, ok = true;
    for (let i = 0; i < day.schedule.length; i++) {
      if (day.schedule[i].freight) {
        // un fret qui n'obtient jamais sa sortie reste planté à quai et bloque
        // la gare : la journée n'est pas jouable, on la rejette. Il n'a pas
        // d'heure de départ à tenir, donc il ne pèse pas dans le total.
        if (!res[i].exitPath) { ok = false; break; }
        continue;
      }
      if (res[i].depReal == null) { ok = false; break; }
      tot += Math.max(0, res[i].depReal - day.schedule[i].dep);
    }
    if (!ok || tot > 0.15) continue;
    seen++;
    const q = platformPressure(day.schedule, res);
    if (q <= (attempt < 4 ? QUEUE_MAX : QUEUE_MAX_FALLBACK)) return day;
    if (q < bestQ) { bestQ = q; best = day; }
  }
  // Aucune journée sous le seuil : la moins encombrée de celles qui tenaient,
  // et à défaut une dernière — mieux vaut une journée jouable qu'aucune.
  return best || generateOnce();
}
// ------------------------------------------------------------------
// TIRER UNE RELATION EN TENANT COMPTE DES QUAIS DÉJÀ SOLLICITÉS.
// ------------------------------------------------------------------
// La charge de chaque quai AUTOUR d'un instant donné, lue sur les convois déjà
// tirés. Chacun répartit son poids sur les quais qui peuvent l'accueillir : il
// n'a pas encore choisi, il a seulement des options.
function loadAround(t, draft) {
  const load = {};
  for (const q of PLATFORMS) load[q.id] = 0;
  for (const s of draft) {
    const dt = Math.abs((s.arrEff ?? s.arr) - t);
    if (dt >= 2 * PLAT_TAU) continue;
    const opts = LINKS[s.from].filter(q => LINKS[s.to].includes(q));
    if (!opts.length) continue;
    const w = Math.exp(-dt / PLAT_TAU) / opts.length;
    for (const q of opts) load[q] += w;
  }
  return load;
}

// Une relation vaut ce que vaut SON MEILLEUR QUAI LIBRE : c'est celui-là que le
// joueur prendra. On la note donc 1/(1+charge du plus libre), au carré pour que
// l'écart se voie — sans jamais tomber à zéro, car aucune relation ne doit
// disparaître de la journée. Le hasard reste maître, il est seulement informé.
//
// C'est ce qui manquait : `pick(PAIRS)` tirait uniformément et sans mémoire, si
// bien que six relations de suite pouvaient viser le même quai. Sur une gare
// comme Liège, où plus de la moitié des relations n'ont qu'un quai commun, cela
// suffisait à fabriquer une file de six trains.
function pickPairUnderPressure(pairOpts, load) {
  const w = [];
  let tot = 0;
  for (const opts of pairOpts) {
    let freest = Infinity;
    for (const q of opts) if (load[q] < freest) freest = load[q];
    const v = 1 / ((1 + freest) * (1 + freest));
    w.push(v); tot += v;
  }
  let r = Math.random() * tot;
  for (let i = 0; i < w.length; i++) { r -= w[i]; if (r <= 0) return i; }
  return w.length - 1;
}

function generateOnce() {
  // 1) tirage des trains selon la fiche de la gare : liaisons, wagons,
  // espacement des arrivées
  const n = GEN.nMin + Math.floor(Math.random() * (GEN.nMax - GEN.nMin + 1));
  const draft = [];
  // écarts modulés par la courbe d'affluence de la gare (cf. rushWeights)
  const gapW = rushWeights(n);
  // Les quais possibles de chaque relation, calculés une fois : c'est
  // l'intersection des deux portails, et c'est elle qui décide de tout. Une
  // relation à un seul quai n'a aucune souplesse — c'est celle qu'il faut
  // espacer, pas interdire.
  const pairOpts = PAIRS.map(([a, b]) => LINKS[a].filter(q => LINKS[b].includes(q)));
  // Charge courante par quai, en « convois qui pèsent ». Un convoi à quatre
  // quais possibles n'en charge chacun que d'un quart : il ne fait pas encore
  // son choix, il pose seulement une option.
  const load = {};
  for (const q of PLATFORMS) load[q.id] = 0;
  let arr = rnd(FIRST_ARRIVAL[0], FIRST_ARRIVAL[1]);
  let prevArr = arr;
  for (let i = 0; i < n; i++) {
    // Le temps passé desserre la pression : un convoi arrivé il y a longtemps a
    // libéré son quai. Décroissance exponentielle de constante PLAT_TAU — pas
    // un seuil, sinon la charge sauterait d'un train à l'autre.
    const decay = Math.exp(-Math.max(0, arr - prevArr) / PLAT_TAU);
    for (const q in load) load[q] *= decay;
    prevArr = arr;
    const k = pickPairUnderPressure(pairOpts, load);
    const [from, to] = PAIRS[k];
    draft.push({
      id: "T" + String(i + 1).padStart(2, "0"),
      // MIN_CARS : garde-fou, même si une fiche de gare tire un 1
      from, to, cars: Math.max(MIN_CARS, pick(GEN.cars)),
      arr: Math.round(arr * 2) / 2, dep: 0
    });
    const share = 1 / pairOpts[k].length;
    for (const q of pairOpts[k]) load[q] += share;
    arr += rnd(GEN.gapMin, GEN.gapMax) * ARRIVAL_GAP_SCALE * gapW[i];
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
  // Les quais possibles de chaque relation traversante — même rôle que
  // pairOpts pour les voyageurs.
  const crossOpts = cross.map(([a, b]) => LINKS[a].filter(q => LINKS[b].includes(q)));
  for (let f = 0; f < nFreight; f++) {
    // Arrivées ÉTALÉES sur le service : un fret par tranche, sinon les cinq
    // se bousculent dans le même quart d'heure et la journée devient injouable.
    const lo = 6, hi = Math.max(lo + 2, lastArr - 4);
    const a = lo + (hi - lo) * f / nFreight, b = lo + (hi - lo) * (f + 1) / nFreight;
    const fArr = Math.round(rnd(a, b));
    // UN FRET SE TIRE COMME LES AUTRES — et même avec plus de soin. Il ne
    // s'arrête pas, mais il verrouille son quai ET ses deux itinéraires le
    // temps du transit : le poser sur un quai déjà couru coûte plus cher qu'un
    // voyageur de plus. Il était pourtant tiré uniformément, ce qui suffisait à
    // engorger une gare à six convois de fret comme Bettembourg.
    //
    // La charge se mesure AUTOUR DE SON HEURE D'ARRIVÉE, sur les voyageurs déjà
    // tirés — pas sur la charge de fin de journée, qui ne dit rien de l'instant
    // où il se présente.
    const [from, to] = cross[pickPairUnderPressure(crossOpts, loadAround(fArr, draft))];
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
  // À départ ÉQUIVALENT, deux quais ne se valent pas : l'un peut être déjà
  // couru, l'autre libre. Le glouton seul prenait toujours le premier trouvé et
  // convergeait donc sur le même quai — il fabriquait la file qu'on cherche à
  // éviter. Une demi-minute d'écart au départ ne se voit pas ; une file de six
  // se voit tout de suite.
  const TIE = 0.5; // minutes de jeu
  for (let i = 0; i < draft.length; i++) {
    if (opts[i].length === 1) { assign[i] = opts[i][0]; continue; }
    const cands = [];
    let bestT = Infinity;
    for (const q of opts[i]) {
      assign[i] = q;
      const d = simulateDay(draft, assign, 0.03, events)[i].depReal ?? Infinity;
      cands.push([q, d]);
      if (d < bestT) bestT = d;
    }
    // Parmi les quais à égalité, le moins sollicité AUTOUR de cette arrivée. On
    // ne compte que les trains déjà affectés (j < i) : ceux d'après n'ont
    // encore qu'une valeur provisoire, et les compter reviendrait à préférer
    // systématiquement le premier quai de leur liste.
    const aI = draft[i].arrEff ?? draft[i].arr;
    let bestQ = null, bestLoad = Infinity;
    for (const [q, d] of cands) {
      if (!(d <= bestT + TIE)) continue;
      let near = 0;
      for (let j = 0; j < i; j++) {
        if (assign[j] !== q) continue;
        if (Math.abs((draft[j].arrEff ?? draft[j].arr) - aI) < 2 * PLAT_TAU) near++;
      }
      if (near < bestLoad) { bestLoad = near; bestQ = q; }
    }
    assign[i] = bestQ == null ? opts[i][0] : bestQ;
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
