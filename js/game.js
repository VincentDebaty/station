"use strict";
// ------------------------------------------------------------------
// Jeu : état de la partie, enclenchement (routes et conflits),
// interactions (sélection train/quai), imprévus et boucle de simulation.
// ------------------------------------------------------------------
let trains, gameMin, speed, paused, started, ended, totalDelay, selected, activeRoutes, queueSeq;

function resetGame() {
  const day = generateSchedule(); // nouvelle journée à chaque partie
  SCHEDULE = day.schedule;
  EVENTS = day.events.map(ev => ({ ...ev, revealed: false, cleared: false, el: null }));
  trains = SCHEDULE.map(s => ({
    ...s,
    cars: s.freight ? s.cars : Math.min(MAX_CARS, Math.max(1, s.cars || 1)),
    state: "scheduled", // scheduled | approaching | waiting | movingIn | dwell | movingOut | movingThrough | done
    progress: 0, qs: null,
    platform: null, target: s.freight ? s.plat : null,
    entryPath: null, exitPath: null, exitTo: null, refoul: false,
    pendingEl: null, stopS: null, startS: 0, backS: 0,
    actualArr: null, queuedAt: null, el: null, carEls: null,
    badgeEl: null, badgeText: null, badgeRect: null, headPos: null
  }));
  gameMin = 0; speed = 1; paused = false; ended = false;
  totalDelay = 0; selected = null; activeRoutes = {}; queueSeq = 0;
  document.querySelectorAll(".speed").forEach(b => b.classList.toggle("active", b.dataset.s === "1"));
  document.getElementById("btn-pause").textContent = "⏸";
  drawStatic();
  buildTimeline();
  updateDelay();
}

// ------------------------------------------------------------------
// Enclenchement
// ------------------------------------------------------------------
// Intervalle d'abscisse occupé par un convoi sur son chemin actif, et son
// sens de parcours (+1 : s croissant). Sert au relâchement par section.
function occupiedSpan(t, pathId) {
  const path = paths[pathId];
  const tail = (t.cars - 1) * CAR_SPACING;
  if (t.state === "movingThrough") {
    // fret : itinéraire entrée+sortie verrouillé, parcouru d'une traite
    const pin = paths[t.entryPath], pout = paths[t.exitPath];
    const totalArc = pin.len + pout.len;
    const endU = 1 + (tail + EXIT_RUN) / totalArc;
    const s0 = t.startS || 0;
    const h = s0 + easeRun(t.progress / endU, 0.12, 0) * (endU * totalArc - s0);
    if (pathId === t.entryPath) return { lo: h - tail, hi: Math.min(h, pin.len), dir: 1 };
    if (h <= pin.len) return null; // pas encore atteint : tout reste bloqué
    const headOut = pout.len - (h - pin.len);
    return { lo: headOut, hi: Math.min(pout.len, headOut + tail), dir: -1 };
  }
  if (t.state === "movingIn") {
    const u = Math.min(t.progress * path.len / t.stopS, 1);
    const s0 = t.startS || 0;
    const headS = s0 + easeRun(u, 0.10, 0.22) * (t.stopS - s0);
    return { lo: headS - tail, hi: headS, dir: 1 };
  }
  if (t.state === "movingOut") {
    const goneP = 1 + (tail + EXIT_RUN) / path.len;
    const effP = easeRun(t.progress / goneP, 0.16, 0) * goneP;
    const headS = (1 - effP) * (path.len + (t.backS || 0));
    return { lo: headS, hi: headS + tail, dir: -1 };
  }
  if (t.state === "movingBack") {
    const p0 = 1 - t.stopS / path.len;
    const effP = p0 + easeRun((t.progress - p0) / (1 - p0), 0.16, 0) * (1 - p0);
    const headS = (1 - effP) * path.len;
    return { lo: headS - tail, hi: headS, dir: -1 };
  }
  return null;
}
function canGrant(pathId) {
  if (activeRoutes[pathId]) return false; // chemin déjà occupé par un autre train
  for (const aid of Object.keys(activeRoutes)) {
    const zone = conflicts[aid][pathId]; // zone partagée, sur le chemin actif
    if (!zone) continue;
    const occ = occupiedSpan(activeRoutes[aid], aid);
    if (!occ) return false;
    // libre seulement si le convoi actif a entièrement dépassé la zone,
    // dernier wagon compris — un train qui ne l'a pas encore atteinte bloque
    const cleared = occ.dir === 1 ? occ.lo > zone.hi : occ.hi < zone.lo;
    if (!cleared) return false;
  }
  return true;
}
function grant(pathId, train) {
  activeRoutes[pathId] = train;
  const c = train.freight ? "#8f98a8" : DEST_COLOR[train.to];
  const p = el("path", { d: pathD(paths[pathId].pts), class: "route",
    id: "route-" + pathId.replace(":", "-") }, gRoutes);
  p.style.stroke = c; p.style.color = c;
}
function release(pathId) {
  delete activeRoutes[pathId];
  const p = document.getElementById("route-" + pathId.replace(":", "-"));
  if (p) p.remove();
}

// ------------------------------------------------------------------
// Interaction : sélection du train, choix du quai
// ------------------------------------------------------------------
// Réservation pour l'AFFECTATION : un fret en transit (movingThrough) ne
// bloque pas le choix du quai — on peut pré-affecter, l'entrée attendra
function platformReserved(pid) {
  return trains.some(t =>
    (t.platform === pid && (t.state === "movingIn" || t.state === "dwell")) ||
    (t.target === pid && (t.state === "waiting" || t.state === "approaching")));
}
function platformClosed(pid) {
  return EVENTS.some(ev => ev.type === "closure" && ev.plat === pid &&
    gameMin >= ev.start && gameMin < ev.end);
}
// ------------------------------------------------------------------
// Imprévus : révélation en cours de partie (le calibrage les connaît déjà,
// le joueur les découvre ici)
// ------------------------------------------------------------------
function showClosure(ev) {
  const q = PLATFORMS.find(x => x.id === ev.plat);
  const g = el("g", {}, gFx);
  el("rect", {
    x: PLAT_X1, y: q.cy - PLAT_H / 2, width: PLAT_X2 - PLAT_X1, height: PLAT_H,
    rx: 10, fill: "url(#hatch)", stroke: "var(--red)", "stroke-width": 1.5,
    "pointer-events": "none"
  }, g);
  // le message s'affiche SUR le quai, avec un fond pour rester lisible
  const mid = (PLAT_X1 + PLAT_X2) / 2;
  el("rect", {
    x: mid - 92, y: q.cy - 12, width: 184, height: 24, rx: 7,
    fill: "rgba(14,20,32,.9)", "pointer-events": "none"
  }, g);
  el("text", { x: mid, y: q.cy, class: "closure-tag" }, g)
    .textContent = "⚠ fermé jusqu'à " + fmt(ev.end);
  ev.el = g;
}
function processEvents() {
  for (const ev of EVENTS) {
    if (!ev.revealed) {
      if (ev.type === "late" && gameMin >= ev.revealAt) {
        ev.revealed = true;
        SND.incident();
        toast(ev.trainId + " annoncé avec +" + ev.delay + " min de retard");
        const tl = document.getElementById("tl-" + ev.trainId);
        if (tl) {
          tl.classList.add("delayed");
          const x = document.createElement("div");
          x.className = "tl-extra"; x.textContent = "+" + ev.delay;
          tl.appendChild(x);
        }
      } else if (ev.type === "closure" && gameMin >= ev.start) {
        ev.revealed = true;
        SND.incident();
        toast("Quai " + ev.plat + " fermé jusqu'à " + fmt(ev.end));
        showClosure(ev);
        refreshEligible();
      }
    }
    if (ev.type === "closure" && ev.revealed && !ev.cleared && gameMin >= ev.end) {
      ev.cleared = true;
      if (ev.el) { ev.el.remove(); ev.el = null; }
      toast("Quai " + ev.plat + " rouvert");
      refreshEligible();
    }
  }
}
function refreshEligible() {
  const selecting = selected && !selected.target &&
    (selected.state === "waiting" || selected.state === "approaching");
  document.querySelectorAll(".platform").forEach(pl => {
    const pid = +pl.dataset.platform;
    // tout quai accessible depuis l'origine est proposé : au joueur de lire
    // les pastilles — un mauvais choix vaudra un refoulement automatique
    const ok = selecting &&
               LINKS[selected.from].includes(pid) &&
               !platformReserved(pid) && !platformClosed(pid);
    pl.classList.toggle("eligible", !!ok);
  });
}
function onPlatformClick(pid) {
  if (!selected || selected.target ||
      (selected.state !== "waiting" && selected.state !== "approaching")) return;
  const q = PLATFORMS.find(x => x.id === pid);
  const center = { x: (PLAT_X1 + PLAT_X2) / 2, y: q.cy };
  if (!LINKS[selected.from].includes(pid)) {
    flashAt(center, "Aucune voie depuis " + PORTALS[selected.from].label + " vers le quai " + pid);
    return;
  }
  if (platformReserved(pid)) {
    flashAt(center, "Quai " + pid + " déjà réservé");
    return;
  }
  if (platformClosed(pid)) {
    flashAt(center, "Quai " + pid + " fermé — réouverture à venir");
    return;
  }
  selected.target = pid;
  const pathId = "in:" + selected.from + ":" + pid;
  // l'itinéraire en pointillés démarre à la position actuelle du convoi
  const ap = APPROACH[selected.from];
  const lead = slicePts(ap, selected.qs != null ? selected.qs : ap.len, ap.len);
  const pend = el("path", {
    d: pathD(lead.concat(paths[pathId].pts)),
    class: "route pending"
  }, gRoutes);
  pend.style.stroke = DEST_COLOR[selected.to]; pend.style.color = DEST_COLOR[selected.to];
  selected.pendingEl = pend;
  selected = null;
  refreshEligible();
}
function onTrainClick(t) {
  if (ended) return;
  if (t.freight) {
    toast("Convoi de fret — passage automatique, sillon prioritaire");
    return;
  }
  // Sélectionnable dès l'approche : on peut préparer l'itinéraire avant l'arrêt
  const routable = t.state === "waiting" || t.state === "approaching";
  if (routable && !t.target) {
    selected = t;
    t.el.classList.add("selected"); // retour visuel immédiat, sans attendre le tick
    refreshEligible();
    return;
  }
  // Train déjà affecté : retoucher = annuler et rechoisir
  if (routable && t.target) {
    t.target = null;
    if (t.pendingEl) { t.pendingEl.remove(); t.pendingEl = null; }
    selected = t;
    t.el.classList.add("selected");
    refreshEligible();
    toast(t.id + " : affectation annulée — choisissez un nouveau quai");
    return;
  }
  if (t.state === "dwell" && paths["out:" + t.to + ":" + t.platform]) {
    toast(t.id + " à quai " + t.platform + " — départ " + fmt(t.dep) + " vers " + PORTALS[t.to].label);
    return;
  }
  if (t.state === "movingIn" || t.state === "movingOut" || t.state === "movingBack") {
    toast(t.id + " est en mouvement");
    return;
  }
  // Train sur un mauvais quai : le refoulement est automatique
  if (t.state === "dwell" && !paths["out:" + t.to + ":" + t.platform]) {
    toast(t.id + " est sur un mauvais quai — refoulement automatique en cours");
  }
}
board.addEventListener("click", e => {
  if (e.target === board) { selected = null; refreshEligible(); }
});

// ------------------------------------------------------------------
// Boucle de jeu
// ------------------------------------------------------------------
// Retard vivant : le retard déjà encaissé + celui qui se creuse pour les
// trains pas encore partis — le compteur bouge PENDANT que le joueur hésite
function liveDelay() {
  let d = totalDelay;
  for (const t of trains)
    if (!t.freight && (t.state !== "movingOut" || t.refoul) && t.state !== "done")
      d += Math.max(0, gameMin - t.dep);
  return d;
}
function updateDelay() {
  const d = document.getElementById("delay");
  const v = liveDelay();
  d.textContent = "retard +" + Math.round(v) + " min";
  d.className = v <= 5 ? "" : v <= 10 ? "warn" : "bad";
  document.getElementById("progress").textContent =
    trains.filter(t => t.state === "done").length + "/" + trains.length + " trains";
}

function tick(dtMin) {
  processEvents();
  for (const t of trains) {
    switch (t.state) {

      case "scheduled":
        // Le train apparaît au loin ~1,3 min avant son heure et approche en douceur
        if (gameMin >= (t.arrEff ?? t.arr) - 1.3) {
          t.state = "approaching";
          t.queuedAt = queueSeq++; // ordre réel d'entrée sur la voie d'approche
          t.el = trainNode(t);
          const tl = document.getElementById("tl-" + t.id);
          if (tl) tl.classList.add("active");
          if (t.freight) SND.freight(); // les voyageurs arrivent sans carillon
        }
        break;

      case "approaching":
        placeQueue(t, dtMin);
        t.el.classList.toggle("selected", selected === t);
        t.el.classList.toggle("ready", !t.freight && !t.target);
        if (gameMin >= (t.arrEff ?? t.arr)) {
          t.state = "waiting";
          // le train est à l'arrêt en gare : son heure d'arrivée s'efface
          const d = document.getElementById("tl-" + t.id);
          if (d) d.classList.add("arrived");
          refreshEligible();
        }
        break;

      case "waiting": {
        placeQueue(t, dtMin);
        t.el.classList.toggle("selected", selected === t);
        t.el.classList.toggle("ready", !t.freight && !t.target);
        if (t.freight) {
          // Le fret verrouille tout son itinéraire et traverse sans s'arrêter
          const pin = "in:" + t.from + ":" + t.plat;
          const pout = "out:" + t.to + ":" + t.plat;
          const busy = trains.some(o => o !== t &&
            ((o.platform === t.plat && (o.state === "movingIn" || o.state === "dwell" || o.state === "movingThrough")) ||
             (o.target === t.plat && o.state === "waiting")));
          if (!busy && !platformClosed(t.plat) && canGrant(pin) && canGrant(pout)) {
            grant(pin, t); grant(pout, t);
            t.entryPath = pin; t.exitPath = pout; t.platform = t.plat;
            t.startS = t.qs != null ? -(APPROACH[t.from].len - t.qs) : 0;
            t.state = "movingThrough";
            t.progress = 0;
            gTrains.appendChild(t.el); // entre en gare : calque découpé au tunnel
            toast("Convoi de fret en transit — quai " + t.plat + " neutralisé");
            refreshEligible();
          }
          break;
        }
        // Entrée automatique dès que l'itinéraire demandé est libre — et que
        // le quai est physiquement dégagé (un fret en transit peut encore
        // l'occuper alors que le joueur a déjà pré-affecté le quai)
        if (t.target && !platformClosed(t.target)) {
          const busy = trains.some(o => o !== t && o.platform === t.target &&
            (o.state === "movingIn" || o.state === "dwell" || o.state === "movingThrough"));
          const pathId = "in:" + t.from + ":" + t.target;
          if (!busy && canGrant(pathId)) {
            if (t.pendingEl) { t.pendingEl.remove(); t.pendingEl = null; }
            grant(pathId, t);
            t.entryPath = pathId;
            t.platform = t.target;
            // tous les trains tirent jusqu'en tête de quai (heurtoir compris)
            t.stopS = paths[pathId].len;
            // le trajet d'entrée démarre au point d'arrêt réel sur la voie
            // d'approche (abscisse négative : en amont du point de convergence)
            t.startS = t.qs != null ? -(APPROACH[t.from].len - t.qs) : 0;
            t.state = "movingIn";
            t.progress = 0;
            t.badgeLift = 0;
            t.el.classList.remove("ready", "selected");
            gTrains.appendChild(t.el); // entre en gare : calque découpé au tunnel
          }
        }
        break;
      }

      case "movingIn": {
        const path = paths[t.entryPath];
        t.progress += dtMin / (path.dur * slowness(t));
        const stopP = t.stopS / path.len;
        if (t.progress >= stopP) {
          t.progress = stopP;
          t.state = "dwell";
          t.actualArr = gameMin;
          release(t.entryPath);
          const chip = document.getElementById("depchip-" + t.platform);
          if (paths["out:" + t.to + ":" + t.platform]) {
            chip.textContent = "dep " + fmt(t.dep) + " → " + PORTALS[t.to].label;
            chip.style.fill = DEST_COLOR[t.to];
          } else {
            chip.textContent = "✕ " + PORTALS[t.to].label + " inaccessible — refoulement imminent";
            chip.style.fill = "var(--red)";
          }
          refreshEligible();
        }
        // freinage progressif à l'approche du point d'arrêt, en partant
        // de la position où le convoi s'était immobilisé
        const s0 = t.startS || 0;
        const headS = s0 + easeRun(t.progress / stopP, 0.10, 0.22) * (t.stopS - s0);
        placeEntry(t, t.entryPath, headS);
        // la route brille du dernier wagon jusqu'au quai : elle se consume
        // derrière le convoi à mesure que les sections se libèrent
        if (activeRoutes[t.entryPath] === t) {
          const tailS = headS - (t.cars - 1) * CAR_SPACING;
          const ap = APPROACH[t.from];
          setRouteD(t.entryPath, tailS < 0
            ? slicePts(ap, ap.len + tailS, ap.len).concat(slicePts(path, 0, t.stopS))
            : slicePts(path, tailS, t.stopS));
        }
        break;
      }

      case "dwell": {
        // Mauvais quai (pas de sortie vers la destination) : dès son arrêt
        // minimum, le train repart comme un vrai départ — changement de
        // cabine, voie du haut — vers son portail d'origine, puis se
        // représentera à l'arrivée. La perte de temps est la sanction.
        if (!paths["out:" + t.to + ":" + t.platform]) {
          if (gameMin >= t.actualArr + MIN_DWELL) {
            const backOut = "out:" + t.from + ":" + t.platform;
            if (paths[backOut]) {
              if (canGrant(backOut)) {
                grant(backOut, t);
                t.exitPath = backOut;
                t.exitTo = t.from; // la sortie mène au portail d'origine
                t.refoul = true;
                // sortie du même côté que l'entrée : le convoi glisse
                // d'abord le long du quai, comme un demi-tour
                t.backS = Math.max(0, (PLAT_X2 - PLAT_X1 - 2 * STOP_MARGIN) - (t.cars - 1) * CAR_SPACING);
                t.state = "movingOut";
                t.progress = 0;
                SND.depart();
                document.getElementById("depchip-" + t.platform).textContent = "";
                toast(t.id + " refoule vers " + PORTALS[t.from].label + " : le quai " +
                  t.platform + " ne dessert pas " + PORTALS[t.to].label);
                refreshEligible();
              }
            } else {
              // portail sans voie de départ : ancienne manœuvre en marche arrière
              const backPath = "in:" + t.from + ":" + t.platform;
              if (canGrant(backPath)) {
                grant(backPath, t);
                t.exitPath = backPath;
                t.state = "movingBack";
                t.progress = 1 - t.stopS / paths[backPath].len;
                document.getElementById("depchip-" + t.platform).textContent = "";
                toast(t.id + " refoule : le quai " + t.platform + " ne dessert pas " +
                  PORTALS[t.to].label);
                refreshEligible();
              }
            }
          }
          break;
        }
        const canLeave = gameMin >= Math.max(t.dep, t.actualArr + MIN_DWELL);
        if (canLeave) {
          const pathId = "out:" + t.to + ":" + t.platform;
          if (canGrant(pathId)) {
            grant(pathId, t);
            t.exitPath = pathId;
            // Demi-tour : le convoi est garé au fond du quai ; la sortie
            // démarre en amont du chemin, il glisse le long du quai puis sort
            const uturn = PORTALS[t.from].side === PORTALS[t.to].side;
            t.backS = uturn
              ? Math.max(0, (PLAT_X2 - PLAT_X1 - 2 * STOP_MARGIN) - (t.cars - 1) * CAR_SPACING)
              : 0;
            t.state = "movingOut";
            t.progress = 0;
            t.depDelay = Math.max(0, gameMin - t.dep);
            totalDelay += t.depDelay;
            SND.depart();
            updateDelay();
            document.getElementById("depchip-" + t.platform).textContent = "";
            refreshEligible();
          }
        }
        break;
      }

      case "movingBack": {
        // Refoulement : le convoi recule, wagons de queue en tête de manœuvre
        const path = paths[t.exitPath];
        t.progress += dtMin / (path.dur * slowness(t));
        if (t.progress >= 1) {
          release(t.exitPath);
          t.exitPath = null;
          t.platform = null; t.target = null; t.actualArr = null;
          t.qs = null; // il se représentera au portail en douceur
          t.state = "waiting";
          t.queuedAt = queueSeq++; // un refoulé repart en bout de file
          gQueue.appendChild(t.el); // ressorti du tunnel, sur la ligne d'approche
        } else {
          const p0 = 1 - t.stopS / path.len;
          const effP = p0 + easeRun((t.progress - p0) / (1 - p0), 0.16, 0) * (1 - p0);
          const headS = (1 - effP) * path.len;
          placeEntry(t, t.exitPath, headS);
          if (activeRoutes[t.exitPath] === t)
            setRouteD(t.exitPath, slicePts(path, 0, headS));
        }
        break;
      }

      case "movingOut": {
        // le chemin est défini portail -> quai : on le parcourt à l'envers.
        // Le gril est libéré quand le dernier wagon l'a quitté, mais le convoi
        // continue de s'éloigner à l'écran avant de disparaître
        const path = paths[t.exitPath];
        t.progress += dtMin / (path.dur * slowness(t));
        const tail = (t.cars - 1) * CAR_SPACING;
        const endP = 1 + tail / path.len;             // dernier wagon hors du gril
        const goneP = endP + EXIT_RUN / path.len;     // dernier wagon avalé par le tunnel
        // démarrage progressif depuis l'arrêt
        const effP = easeRun(t.progress / goneP, 0.16, 0) * goneP;
        if (effP >= endP && activeRoutes[t.exitPath] === t)
          release(t.exitPath);
        const headS = (1 - effP) * (path.len + (t.backS || 0));
        // terminé dès que le dernier wagon a réellement quitté la carte
        const offMap = headS + tail < -(DEPART[t.exitTo ?? t.to].len + 20);
        if (t.progress >= goneP || offMap) {
          if (t.refoul) {
            // Refoulé : sorti de carte, il se représente aussitôt sur la
            // voie d'approche, en bout de file derrière les trains en attente
            if (activeRoutes[t.exitPath] === t) release(t.exitPath);
            t.refoul = false; t.exitTo = null; t.exitPath = null;
            t.platform = null; t.target = null; t.actualArr = null;
            t.qs = null; t.settled = false; t.progress = 0;
            t.backS = 0; t.startS = 0;
            t.el.remove(); t.el = null;
            t.carEls = null; t.badgeEl = null; t.headPos = null;
            t.arrEff = gameMin + 1.5;
            t.state = "scheduled";
          } else {
            t.state = "done";
            t.el.remove();
            const tl = document.getElementById("tl-" + t.id);
            if (tl) { tl.classList.remove("active"); tl.classList.add("done"); }
          }
        } else {
          // demi-tour compris : au départ, la loco change de bout (changement
          // de cabine) et mène le convoi, en glissant d'abord le long du quai
          placeExit(t, t.exitPath, headS);
          // la route brille du dernier wagon jusqu'à la sortie (bord de carte)
          if (activeRoutes[t.exitPath] === t) {
            const tailS = headS + tail;
            const dep = DEPART[t.exitTo ?? t.to];
            setRouteD(t.exitPath, slicePts(path, 0, tailS).reverse()
              .concat(slicePts(dep, Math.max(0, -tailS), dep.len)));
          }
        }
        break;
      }

      case "movingThrough": {
        // Convoi de fret : traverse entrée + sortie d'une seule traite
        const pin = paths[t.entryPath], pout = paths[t.exitPath];
        const totalArc = pin.len + pout.len;
        const durTot = TRAVEL * totalArc / 700 * slowness(t);
        t.progress += dtMin / durTot;
        const tail = (t.cars - 1) * CAR_SPACING;
        const endU = 1 + (tail + EXIT_RUN) / totalArc;
        // démarrage progressif depuis son point d'arrêt, puis roule sans s'arrêter
        const s0 = t.startS || 0;
        const h = s0 + easeRun(t.progress / endU, 0.12, 0) * (endU * totalArc - s0);
        if (h - tail > pin.len && activeRoutes[t.entryPath] === t)
          release(t.entryPath);
        if (h - tail > totalArc && activeRoutes[t.exitPath] === t) {
          release(t.exitPath);
          t.platform = null; // le quai redevient disponible
          refreshEligible();
        }
        // terminé dès que le dernier wagon a réellement quitté la carte
        if (t.progress >= endU ||
            h - tail > totalArc + DEPART[t.to].len + 20) {
          if (activeRoutes[t.exitPath] === t) { release(t.exitPath); t.platform = null; }
          t.state = "done";
          t.el.remove();
          const tl = document.getElementById("tl-" + t.id);
          if (tl) { tl.classList.remove("active"); tl.classList.add("done"); }
        } else {
          for (let i = 0; i < t.cars; i++) {
            const s = h - i * CAR_SPACING;
            let pos;
            if (s < 0) {
              const ap = APPROACH[t.from];
              pos = pathPoint(ap, ap.len + s);
            } else if (s <= pin.len) pos = pathPoint(pin, s);
            else {
              const outArc = pout.len - (s - pin.len);
              pos = outArc >= 0 ? pathPoint(pout, outArc) : pathPoint(DEPART[t.to], -outArc);
            }
            if (i === 0) t.headPos = { x: pos.x, y: pos.y };
            t.carEls[i].setAttribute("transform",
              "translate(" + pos.x.toFixed(1) + " " + pos.y.toFixed(1) + ") rotate(" + pos.ang.toFixed(1) + ")");
          }
          // routes lumineuses : du dernier wagon jusqu'au bord de la carte
          const tailS = h - tail;
          if (activeRoutes[t.entryPath] === t) {
            const ap = APPROACH[t.from];
            setRouteD(t.entryPath, tailS < 0
              ? slicePts(ap, ap.len + tailS, ap.len).concat(slicePts(pin, 0, pin.len))
              : slicePts(pin, tailS, pin.len));
          }
          if (activeRoutes[t.exitPath] === t) {
            const dep = DEPART[t.to];
            const tailOut = tailS <= pin.len ? pout.len : pout.len - (tailS - pin.len);
            setRouteD(t.exitPath, slicePts(pout, 0, tailOut).reverse()
              .concat(slicePts(dep, Math.max(0, -tailOut), dep.len)));
          }
        }
        break;
      }
    }
    updateBadge(t);
  }
  updateTimeline();
  updateDelay();

  if (!ended && trains.every(t => t.state === "done")) endGame();
}

function endGame() {
  ended = true;
  const d = Math.round(totalDelay);
  const stars = d <= 5 ? 3 : d <= 10 ? 2 : d <= 15 ? 1 : 0;
  saveResult(STATION.id, stars, d);
  document.getElementById("stars").textContent = "★★★".slice(0, stars) + "☆☆☆".slice(0, 3 - stars);
  document.getElementById("end-delay").textContent =
    (d === 0 ? "Service parfait — aucun retard." : "Retard cumulé : " + d + " min") +
    (stars >= 1 && currentIdx + 1 < CATALOG.length ? " — gare suivante débloquée !" : "");
  // bilan de la journée
  const pax = trains.filter(t => !t.freight);
  const onTime = pax.filter(t => (t.depDelay || 0) < 1).length;
  let worst = null;
  for (const t of pax)
    if ((t.depDelay || 0) >= 1 && (!worst || t.depDelay > worst.depDelay)) worst = t;
  const nEv = EVENTS.filter(ev => ev.revealed).length;
  const nFret = trains.filter(t => t.freight).length;
  const inc = [];
  if (nEv) inc.push(nEv + " imprévu" + (nEv > 1 ? "s" : ""));
  if (nFret) inc.push(nFret + " fret" + (nFret > 1 ? "s" : ""));
  document.getElementById("end-stats").innerHTML =
    "Trains à l'heure : " + onTime + "/" + pax.length +
    (worst ? "<br>Pire retard : " + worst.id + " (+" + Math.round(worst.depDelay) + " min)" : "") +
    (inc.length ? "<br>Incidents gérés : " + inc.join(", ") : "");
  SND.end();
  const next = currentIdx + 1 < CATALOG.length && isUnlocked(currentIdx + 1);
  document.getElementById("btn-next").classList.toggle("hidden", !next);
  document.getElementById("end").classList.remove("hidden");
}
