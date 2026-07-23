"use strict";
// ------------------------------------------------------------------
// Jeu : état de la partie, enclenchement (routes et conflits),
// interactions (sélection train/quai), imprévus et boucle de simulation.
// ------------------------------------------------------------------
let trains, gameMin, speed, paused, started, ended, totalDelay, selected, activeRoutes, queueSeq;

// Retard plafond : au-delà, le service est interrompu (game over). Réglable
// par gare via le champ « maxDelay » de sa fiche ; 120 min par défaut.
const DEFAULT_MAX_DELAY = 120;
function maxDelay() { return STATION.maxDelay ?? DEFAULT_MAX_DELAY; }

// ------------------------------------------------------------------
// Génération d'horaire hors thread principal (Web Worker).
// La simulation du « joueur parfait » peut prendre plusieurs secondes sur une
// grosse gare ; on la délègue au worker pour ne pas figer l'écran. Repli
// synchrone si les Workers sont indisponibles (vieux moteur, contexte réduit).
// ------------------------------------------------------------------
let _genWorker = null, _genSeq = 0;
function genWorker() {
  if (_genWorker === null) {
    try { _genWorker = (typeof Worker !== "undefined") ? new Worker("js/gen-worker.js") : false; }
    catch (e) { _genWorker = false; }
  }
  return _genWorker || null;
}
function generateDay(cfg) {
  const w = genWorker();
  if (!w) return Promise.resolve(generateSchedule()); // repli synchrone
  const id = ++_genSeq;
  return new Promise(resolve => {
    const onMsg = e => {
      if (!e.data || e.data.id !== id) return;   // ignore une réponse périmée (rejeu rapide)
      w.removeEventListener("message", onMsg);
      if (e.data.error) { console.warn("Worker:", e.data.error); resolve(generateSchedule()); return; }
      resolve({ schedule: e.data.schedule, events: e.data.events });
    };
    w.addEventListener("message", onMsg);
    w.postMessage({ id, cfg });
  });
}
// Voile « préparation du service » pendant la génération asynchrone.
function setPreparing(on) {
  const el = document.getElementById("preparing");
  if (el) el.classList.toggle("hidden", !on);
}

async function resetGame() {
  // Gèle la boucle pendant la génération : la journée arrive du worker de façon
  // asynchrone. On dessine tout de suite le plan (vide) pour que le joueur voie
  // le réseau se poser, puis on peuple les trains à réception.
  started = false; ended = false; paused = false;
  gameMin = 0; speed = 1;
  totalDelay = 0; selected = null; activeRoutes = {}; queueSeq = 0;
  document.getElementById("hud-controls").classList.add("hidden");
  document.getElementById("settings").classList.remove("open"); // engrenage revient à l'état repos
  if (typeof updatePauseIcon === "function") updatePauseIcon(); // paused=false → icône ▶→⏸, clock non-teal
  drawStatic();
  setPreparing(true);
  const day = await generateDay(STATION);
  SCHEDULE = day.schedule;
  EVENTS = day.events.map(ev => ({ ...ev, revealed: false, cleared: false, el: null }));
  trains = SCHEDULE.map(s => ({
    ...s,
    cars: s.freight ? s.cars : Math.min(MAX_CARS, Math.max(1, s.cars || 1)),
    state: "scheduled", // scheduled | approaching | waiting | movingIn | dwell | movingOut | movingThrough | done
    progress: 0, qs: null,
    platform: null, target: s.freight ? s.plat : null,
    entryPath: null, exitPath: null, exitTo: null, refoul: false, validated: false,
    pendingEl: null, stopS: null, startS: 0, backS: 0,
    actualArr: null, queuedAt: null, el: null, carEls: null, maskEls: null,
    badgeEl: null, badgeText: null, badgeRect: null, headPos: null
  }));
  buildTimeline();
  updateDelay();
  setPreparing(false);
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
  // une fermeture ne bloque que si elle est effectivement révélée (donc posée
  // sur un quai libre) et pas encore rouverte
  return EVENTS.some(ev => ev.type === "closure" && ev.plat === pid &&
    ev.revealed && !ev.cleared && gameMin < ev.end);
}
// Un quai est occupé tant qu'un train y est physiquement (entrée, arrêt,
// transit de fret ou refoulement) — on ne ferme jamais un quai occupé.
function platformOccupied(pid) {
  return trains.some(t => t.platform === pid &&
    (t.state === "movingIn" || t.state === "dwell" ||
     t.state === "movingThrough" || t.state === "movingBack"));
}
// ------------------------------------------------------------------
// Imprévus : révélation en cours de partie (le calibrage les connaît déjà,
// le joueur les découvre ici)
// ------------------------------------------------------------------
// Cadenas (Material Symbols) — signifiant NON coloré : la fermeture reste lisible
// même sans percevoir le rouge (daltonisme), en plus de la texture hachurée.
const LOCK_D = "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1s3.1 1.39 3.1 3.1v2z";
function showClosure(ev) {
  const q = PLATFORMS.find(x => x.id === ev.plat);
  // le quai passe en « désactivé » : numéro grisé, teinte éteinte — lecture
  // indépendante de la couleur (cf. daltonisme)
  const plat = document.getElementById("plat-" + ev.plat);
  if (plat) plat.classList.add("closed");
  const g = el("g", {}, gFx);
  el("rect", {
    x: PLAT_X1, y: q.cy - PLAT_H / 2, width: PLAT_X2 - PLAT_X1, height: PLAT_H,
    rx: 10, fill: "url(#hatch)", stroke: "var(--red)", "stroke-width": 1.5,
    "pointer-events": "none"
  }, g);
  // Pastille compacte au centre du quai : cadenas + heure de réouverture (même
  // langage visuel que les badges « dép HH:MM »). Ensemble mesuré et centré.
  const mid = (PLAT_X1 + PLAT_X2) / 2;
  const icoS = 15 * UIK, gap = 5 * UIK;
  const bg = el("rect", {
    rx: 8 * UIK, fill: "rgba(14,20,32,.94)", stroke: "var(--red)",
    "stroke-width": 1.3, "pointer-events": "none"
  }, g);
  const txt = el("text", { y: q.cy, class: "closure-tag" }, g);
  txt.style.fontSize = (15 * UIK) + "px";
  txt.style.dominantBaseline = "central";
  txt.textContent = fmt(ev.end);
  let tw; try { tw = txt.getBBox().width; } catch (e) { tw = 44 * UIK; }
  const totalW = icoS + gap + tw;
  const x0 = mid - totalW / 2;               // bord gauche de [cadenas · texte]
  txt.setAttribute("x", x0 + icoS + gap + tw / 2);
  const lock = el("path", { d: LOCK_D, "pointer-events": "none" }, g);
  lock.setAttribute("transform",
    "translate(" + x0.toFixed(1) + " " + (q.cy - icoS / 2).toFixed(1) + ") scale(" + (icoS / 24).toFixed(3) + ")");
  lock.style.fill = "var(--red)";
  const padX = 12 * UIK, padY = 7 * UIK;
  bg.setAttribute("x", x0 - padX); bg.setAttribute("y", q.cy - icoS / 2 - padY);
  bg.setAttribute("width", totalW + 2 * padX); bg.setAttribute("height", icoS + 2 * padY);
  ev.el = g;
}
function processEvents() {
  for (const ev of EVENTS) {
    if (!ev.revealed) {
      if (ev.type === "late" && gameMin >= ev.revealAt) {
        ev.revealed = true;
        SND.incident();
        toast(ev.trainId + " retardé de +" + ev.delay + " min");
        const tl = document.getElementById("tl-" + ev.trainId);
        if (tl) {
          tl.classList.add("delayed");
          const x = document.createElement("div");
          x.className = "tl-extra"; x.textContent = "+" + ev.delay;
          tl.appendChild(x);
        }
      } else if (ev.type === "closure" && gameMin >= ev.start) {
        // On ne ferme jamais un quai occupé : si un train y est présent, la
        // fermeture est repoussée jusqu'à ce qu'il soit parti (dans la limite
        // de la fenêtre). Si la fenêtre s'écoule sans quai libre, elle n'a
        // simplement pas lieu.
        if (platformOccupied(ev.plat)) {
          if (gameMin >= ev.end) { ev.revealed = true; ev.cleared = true; }
        } else {
          ev.revealed = true;
          SND.incident();
          toast("Quai " + ev.plat + " fermé jusqu'à " + fmt(ev.end));
          showClosure(ev);
          refreshEligible();
        }
      }
    }
    if (ev.type === "closure" && ev.revealed && !ev.cleared && gameMin >= ev.end) {
      ev.cleared = true;
      if (ev.el) { ev.el.remove(); ev.el = null; }
      const plat = document.getElementById("plat-" + ev.plat);
      if (plat) plat.classList.remove("closed"); // quai réactivé
      toast("Quai " + ev.plat + " rouvert");
      refreshEligible();
    }
  }
}
function refreshEligible() {
  const selecting = selected && !selected.target &&
    (selected.state === "waiting" || selected.state === "approaching");
  const eligColor = selecting ? (selected.freight ? "#8f98a8" : DEST_COLOR[selected.to]) : null;
  document.querySelectorAll(".platform").forEach(pl => {
    const pid = +pl.dataset.platform;
    // tout quai accessible depuis l'origine est surligné (.eligible) pendant
    // la sélection — un mauvais choix vaudra un refoulement automatique
    const ok = selecting &&
               LINKS[selected.from].includes(pid) &&
               !platformReserved(pid) && !platformClosed(pid);
    pl.classList.toggle("eligible", !!ok);
    if (ok) pl.style.setProperty("--elig", eligColor);
    else pl.style.removeProperty("--elig");
  });
}
// État de repos des quais : un quai physiquement occupé porte un liseré à la
// couleur du convoi présent. Rafraîchi à chaque tick (l'occupation évolue).
function refreshPlatformStates() {
  document.querySelectorAll(".platform").forEach(pl => {
    const pid = +pl.dataset.platform;
    const occ = trains.find(t => t.platform === pid &&
      (t.state === "movingIn" || t.state === "dwell" ||
       t.state === "movingThrough" || t.state === "movingBack"));
    pl.classList.toggle("occupied", !!occ);
    if (occ) pl.style.setProperty("--occ", occ.freight ? "#8f98a8" : DEST_COLOR[occ.to]);
    else pl.style.removeProperty("--occ");
  });
}
function onPlatformClick(pid) {
  if (!selected || selected.target ||
      (selected.state !== "waiting" && selected.state !== "approaching")) return;
  const q = PLATFORMS.find(x => x.id === pid);
  const center = { x: (PLAT_X1 + PLAT_X2) / 2, y: q.cy };
  if (!LINKS[selected.from].includes(pid)) {
    flashAt(center, "Quai " + pid + " : pas de voie depuis " + PORTALS[selected.from].label);
    return;
  }
  if (platformReserved(pid)) {
    flashAt(center, "Quai " + pid + " déjà réservé");
    return;
  }
  if (platformClosed(pid)) {
    flashAt(center, "Quai " + pid + " fermé");
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
    toast("Fret — passage automatique prioritaire");
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
    toast(t.id + " — choisissez un nouveau quai");
    return;
  }
  if (t.state === "dwell" && paths["out:" + t.to + ":" + t.platform]) {
    toast(t.id + " quai " + t.platform + " — départ " + fmt(t.dep) + " → " + PORTALS[t.to].label);
    return;
  }
  if (t.state === "movingIn" || t.state === "movingOut" || t.state === "movingBack") {
    toast(t.id + " en mouvement");
    return;
  }
  // Train sur un mauvais quai : le refoulement est automatique
  if (t.state === "dwell" && !paths["out:" + t.to + ":" + t.platform]) {
    toast(t.id + " — mauvais quai, refoulement en cours");
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
  d.textContent = "+" + Math.round(v);
  // Couleur alignée sur le barème d'étoiles : vert tant qu'on vise 3★ (< 10),
  // ambre tant qu'une étoile reste jouable (< 30), rouge dès que 0★ (≥ 30).
  d.className = v < 10 ? "" : v < 30 ? "warn" : "bad";
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
        // FIFO sur la voie d'approche : tant qu'un train du même portail, entré
        // avant lui dans la file, n'a pas dégagé la voie, il ne peut pas
        // s'engager — pas de dépassement (le 2ᵉ ne double jamais le 1ᵉʳ).
        if (trains.some(o => o !== t && o.from === t.from && o.queuedAt < t.queuedAt &&
            (o.state === "approaching" || o.state === "waiting"))) break;
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
            toast("Fret en transit — quai " + t.plat + " neutralisé");
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
          // l'heure de départ est déjà portée par le badge au-dessus du train :
          // pas de doublon sous le quai. Un mauvais quai se résout par
          // refoulement + toast.
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
                toast(t.id + " refoule — quai " + t.platform + " ≠ " + PORTALS[t.to].label);
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
                toast(t.id + " refoule — quai " + t.platform + " ≠ " + PORTALS[t.to].label);
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
        const goneP = 1 + (tail + EXIT_RUN) / path.len; // dernier wagon avalé par le tunnel
        // démarrage progressif depuis l'arrêt
        const effP = easeRun(t.progress / goneP, 0.16, 0) * goneP;
        const headS = (1 - effP) * (path.len + (t.backS || 0));
        // Itinéraire relâché seulement quand le dernier wagon a dégagé la gorge
        // du portail (s < -PORTAL_CLEAR), pas au simple bord du gril : sinon un
        // convoi adverse pourrait s'engager nez-à-nez dans la zone de
        // convergence approche/départ avant que celui-ci l'ait quittée.
        if (headS + tail < -PORTAL_CLEAR && activeRoutes[t.exitPath] === t)
          release(t.exitPath);
        // terminé dès que le dernier wagon a réellement quitté la carte
        const offMap = headS + tail < -(DEPART[t.exitTo ?? t.to].len + 20);
        if (t.progress >= goneP || offMap) {
          if (t.refoul) {
            // Refoulé : sorti de carte, il se représente aussitôt sur la
            // voie d'approche, en bout de file derrière les trains en attente
            if (activeRoutes[t.exitPath] === t) release(t.exitPath);
            t.refoul = false; t.exitTo = null; t.exitPath = null;
            t.platform = null; t.target = null; t.actualArr = null;
            t.validated = false;
            t.qs = null; t.settled = false; t.progress = 0;
            t.backS = 0; t.startS = 0;
            t.el.remove(); t.el = null;
            if (t.badgeEl) t.badgeEl.remove(); // badge dans son calque à part
            t.carEls = null; t.maskEls = null; t.badgeEl = null; t.headPos = null;
            t.arrEff = gameMin + 1.5;
            t.state = "scheduled";
          } else {
            t.state = "done";
            t.el.remove();
            if (t.badgeEl) { t.badgeEl.remove(); t.badgeEl = null; }
            const tl = document.getElementById("tl-" + t.id);
            if (tl) { tl.classList.remove("active"); tl.classList.add("done"); }
          }
        } else {
          // demi-tour compris : au départ, la loco change de bout (changement
          // de cabine) et mène le convoi, en glissant d'abord le long du quai
          placeExit(t, t.exitPath, headS);
          // « validé » : quand la loco glisse sous le nom de la destination
          // (et seulement vers une vraie destination, pas un refoulement)
          if (!t.refoul && !t.validated && t.headPos) {
            const u = portalUI[t.exitTo ?? t.to];
            if (u && (u.side === "L" ? t.headPos.x <= u.nameX : t.headPos.x >= u.nameX)) {
              t.validated = true; validatePortal(t.exitTo ?? t.to);
            }
          }
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
        const durTot = TRAVEL * totalArc / 700 * FREIGHT_SLOWNESS;
        t.progress += dtMin / durTot;
        const tail = (t.cars - 1) * CAR_SPACING;
        const endU = 1 + (tail + EXIT_RUN) / totalArc;
        // démarrage progressif depuis son point d'arrêt, puis roule sans s'arrêter
        const s0 = t.startS || 0;
        const h = s0 + easeRun(t.progress / endU, 0.12, 0) * (endU * totalArc - s0);
        if (h - tail > pin.len && activeRoutes[t.entryPath] === t)
          release(t.entryPath);
        // sortie relâchée seulement quand le dernier wagon a dégagé la gorge
        // du portail (au-delà de la fin de l'itinéraire + PORTAL_CLEAR)
        if (h - tail > totalArc + PORTAL_CLEAR && activeRoutes[t.exitPath] === t) {
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
          if (t.badgeEl) { t.badgeEl.remove(); t.badgeEl = null; }
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
    updateBoarding(t);
  }
  updateTimeline();
  updateDelay();
  refreshPlatformStates();

  // retard plafond dépassé : on arrête tout, service interrompu
  if (!ended && liveDelay() > maxDelay()) { endGame(true); return; }
  // Fin de service : dès que chaque train a QUITTÉ LE GRIL (itinéraire relâché),
  // le score est figé — inutile d'attendre qu'il ait fini de glisser hors écran.
  // La modale sort donc plus tôt ; le dernier convoi termine sa sortie derrière
  // le voile assombri.
  if (!ended && trains.every(t =>
      t.state === "done" ||
      ((t.state === "movingOut" || t.state === "movingThrough") &&
       !Object.values(activeRoutes).includes(t))))
    endGame();
}

// failed = true : retard plafond dépassé (game over, 0 étoile, rien à débloquer)
function endGame(failed) {
  ended = true;
  // en échec, on affiche le retard « vivant » (celui qui a crevé le plafond),
  // sinon le retard cumulé réellement encaissé
  const d = Math.round(failed ? liveDelay() : totalDelay);
  // Tolérance de retard (minutes) : 3★ < 10, 2★ < 20, 1★ < 30, sinon 0.
  const stars = failed ? 0 : (d < 10 ? 3 : d < 20 ? 2 : d < 30 ? 1 : 0);
  // Réussite = au moins une étoile (débloque la suite). 0 étoile = échec, qu'on
  // ait terminé sans étoile OU crevé le plafond de retard : dans les deux cas il
  // faut recommencer. On le rend visuellement sans ambiguïté.
  const win = stars >= 1;
  // Étoiles de CETTE gare avant enregistrement : sert à savoir si ce service
  // vient de boucler le pays (dernier maillon décroché à l'instant).
  const prevStars = (getProgress()[STATION.id] || {}).stars || 0;
  if (!failed && !STATION.adhoc) saveResult(STATION.id, stars, d); // un échec (ou la démo limites) ne modifie pas le record
  // Pays terminé À L'INSTANT : gagné, cette gare passe de 0 à ≥1 étoile, et toutes
  // les gares du pays ont désormais au moins une étoile. (Seule cette gare a pu
  // changer ce tour-ci, d'où la condition sur prevStars.)
  const justCompletedCountry = win && !STATION.adhoc && prevStars === 0 && countryComplete(currentIdx);
  const card = document.querySelector("#end .card");
  card.classList.toggle("win", win);
  card.classList.toggle("fail", !win);
  card.classList.toggle("country-done", justCompletedCountry);
  document.getElementById("end-title").textContent =
    failed ? "Service interrompu" : justCompletedCountry ? "Pays terminé !" : (win ? "Fin du service" : "Objectif manqué");
  document.getElementById("stars").textContent = "★★★".slice(0, stars) + "☆☆☆".slice(0, 3 - stars);
  // une étoile ne débloque que la gare suivante DU MÊME pays (les autres
  // pays sont déjà ouverts) ; en fin de pays, on invite à en choisir un autre
  const nextInCountry = sameCountry(currentIdx, currentIdx + 1);
  document.getElementById("end-delay").textContent = failed
    ? "Retard de +" + d + " min — la limite de " + maxDelay() + " min est dépassée."
    : win
      ? (d === 0 ? "Service parfait — aucun retard." : "Retard cumulé : " + d + " min") +
        (nextInCountry ? " — gare suivante débloquée !" : "")
      : "Retard cumulé : " + d + " min — il faut moins de 30 min pour décrocher une étoile. Réessayez !";
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
  // Bandeau « pays terminé » : drapeau + nom + total d'étoiles du pays.
  const ec = document.getElementById("end-country");
  if (justCompletedCountry) {
    const country = CATALOG[currentIdx].country || "";
    const toks = country.trim().split(" ");
    const cflag = toks[0], cname = toks.slice(1).join(" ") || country;
    let earned = 0, total = 0;
    const prog = getProgress();
    for (const c of CATALOG) if (c.country === country) { total += 3; earned += (prog[c.id] || {}).stars || 0; }
    ec.innerHTML = '<span class="ec-flag">' + cflag + "</span>" +
      '<span class="ec-txt"><b>' + cname + "</b> — toutes les gares décrochées !" +
      '<span class="ec-stars">' + earned + " / " + total + " ★</span></span>";
    ec.classList.remove("hidden");
  } else ec.classList.add("hidden");
  (win ? SND.end : SND.incident)(); // 0 étoile → tonalité d'échec, pas la fanfare
  const next = !failed && nextInCountry && isUnlocked(currentIdx + 1);
  document.getElementById("btn-next").classList.toggle("hidden", !next);
  // Bouton principal (rempli teal) selon le contexte : « suivante » si gagné +
  // débloqué, « rejouer » si échec, « carte » si gagné en fin de pays.
  document.getElementById("btn-next").classList.toggle("primary", next);
  document.getElementById("btn-replay").classList.toggle("primary", !win && !next);
  document.getElementById("btn-end-map").classList.toggle("primary", win && !next);
  document.getElementById("end").classList.remove("hidden");
}
