"use strict";
// ------------------------------------------------------------------
// Jeu : état de la partie, enclenchement (routes et conflits),
// interactions (sélection train/quai), imprévus et boucle de simulation.
// ------------------------------------------------------------------
let trains, gameMin, speed, paused, started, ended, totalDelay, selected, activeRoutes, queueSeq;
let onTimeStreak; // série de départs à l'heure consécutifs (juice : combo)

// Retard plafond : au-delà, le service est interrompu (game over). Réglable
// par gare via le champ « maxDelay » de sa fiche ; 120 min par défaut.
const DEFAULT_MAX_DELAY = 120;
function maxDelay() { return STATION.maxDelay ?? DEFAULT_MAX_DELAY; }

// ------------------------------------------------------------------
// Accueil du tout premier service : TUTORIEL GUIDÉ (une seule fois)
// ------------------------------------------------------------------
// Au premier lancement (flag persistant côté store), on prend le joueur par la
// main avec des repères VISUELS — un halo pulsé + une bulle qui pointe EXACTEMENT
// quoi toucher, le reste de l'écran assombri (spotlight). Six temps :
//   0. choisir sa première gare (sur la CARTE, avant tout service)
//   1. le 1er train à choisir     2. le quai où l'envoyer
//   3. où se lit le retard         4. le 2e train
//   5. son quai                    6. l'objectif (< 30 min → étoile → ville suivante)
// Le service se gèle pendant chaque repère et reprend quand le joueur agit.
// Ne s'affiche qu'UNE fois (setOnboarded à la fin).
// Phases : null (initié) | "pickStation" (sur la CARTE) | "welcome"
//          | "wait1"/"tap1"/"plat1" | "delay" | "wait2"/"tap2"/"plat2" | "goal"
//          | "free" (jeu libre, mais on guette encore) | "hold" | "speed".
// Les deux dernières étapes sont OPPORTUNISTES : elles ne se déclenchent que si
// la situation se présente pendant ce premier service — un feu rouge, puis le
// moment où il n'y a plus rien à aiguiller.
let onboarding = null;
let _tutFirstId = null;  // id du 1er train guidé (pour en désigner un AUTRE ensuite)
let _tutHoldSeen = false, _tutSpeedSeen = false; // étapes opportunistes, une fois chacune
let _coachTarget = null; // élément DOM que le repère pointe (suivi chaque frame)

// ---- Étape 0, sur la CARTE : choisir sa première gare -------------------
// Les portes d'entrée pulsent déjà (js/mapnet.js) ; il reste à NOMMER le geste.
// Pas de halo ici : les portes sont plusieurs et équivalentes, en cerner une
// seule dirait « celle-ci » alors que le joueur choisit librement.
// Un accueil se referme. Sans bouton, la bulle revenait à chaque retour sur la
// carte et à chaque fiche refermée, et rien ne disait comment s'en défaire —
// elle finissait par cacher le sud de la Belgique. Fermée, elle ne revient plus
// de la partie ; au prochain lancement, si le joueur n'a toujours acheté
// aucune gare, elle se represente : il en a manifestement encore l'usage.
let _mapWelcomeOff = false;
function maybeStartMapOnboarding() {
  const done = (typeof getOnboarded === "function") && getOnboarded();
  const started = (typeof networkEmpty === "function") && !networkEmpty();
  if (done || started || _mapWelcomeOff) {
    if (onboarding === "pickStation") { onboarding = null; hideCoach(); }
    return;
  }
  onboarding = "pickStation";
  // Plus de solde à annoncer : ouvrir une gare ne coûte rien, c'est le réseau
  // qui décide de ce qui s'ouvre. Le message dit donc le geste, et rien d'autre.
  coachAt(null, "Bienvenue ! Les gares qui <b>pulsent</b> sont à votre portée — " +
                "choisissez la vôtre.",
          "Compris");
}

// Fiche de gare ouverte pendant l'étape 0 : le repère se déplace sur le bouton
// qui porte le geste — « Prendre le service » sur une gare déjà acquise,
// « Ouvrir » sur une gare qu'il reste à payer. Le texte doit dire lequel des
// deux, sinon il promet un service là où le joueur va d'abord dépenser.
function onboardingStationCard(btn, unlocked) {
  if (onboarding !== "pickStation") return;
  if (!btn) { hideCoach(); return; }
  coachAt(btn, unlocked
    ? "Prenez le service : vous dirigez cette gare pendant une journée."
    : "<b>Ouvrez cette gare</b> — elle vous appartiendra pour de bon, et vous pourrez la rejouer autant que vous voudrez.");
}

function maybeStartOnboarding() {
  hideCoach(); // le repère de l'étape 0 (carte / fiche) n'a plus lieu d'être
  // Démo « limites » (adhoc) et joueur déjà initié : aucun accueil.
  if (STATION.adhoc || (typeof getOnboarded === "function" && getOnboarded())) {
    onboarding = null; hideCoach(); return;
  }
  _tutFirstId = null; _tutHoldSeen = false; _tutSpeedSeen = false;
  onboarding = "welcome";
  if (typeof openWelcome === "function") openWelcome(); // écran de bienvenue ET pause
}
function freezeGame(on) {
  paused = !!on;
  if (typeof updatePauseIcon === "function") updatePauseIcon();
}
// Fin de la bienvenue : le service tourne jusqu'à ce que le 1er train se pose.
function onboardingWelcomeClosed() {
  if (onboarding !== "welcome") return;
  onboarding = "wait1";
  freezeGame(false);
}
// Un quai qui dessert la destination du train ET libre (le bon choix à désigner).
function tutServingPlatform(t) {
  const links = LINKS[t.from] || [];
  const good = links.filter(pid => paths["out:" + t.to + ":" + pid] &&
    !platformReserved(pid) && !platformClosed(pid));
  return good[0] ?? links.find(pid => paths["out:" + t.to + ":" + pid]) ?? links[0];
}
// Appelé chaque tick : fait apparaître le repère quand le bon train est prêt.
function onboardingTick() {
  if (onboarding === "wait1") {
    const ready = trains.filter(o => !o.freight && !o.target && o.settled &&
      (o.state === "waiting" || o.state === "approaching"));
    if (!ready.length) return;
    // On préfère un train dont le choix PORTE la règle : plusieurs quais
    // s'allument, mais tous ne desservent pas sa destination. Enseigner sur un
    // train sans piège laisserait croire « quai allumé = bon quai ».
    const t = ready.find(o => { const n = tutPlatformCounts(o); return n.lit > 1 && n.serving < n.lit; })
           || ready[0];
    _tutFirstId = t.id;
    freezeGame(true); onboarding = "tap1";
    coachAt(t.el, "Voici un train qui s'annonce. <b>Touchez-le</b> pour le choisir.");
  } else if (onboarding === "dwell1") {
    // LE MOMENT LE PLUS OPAQUE DU JEU : le train est arrivé, il ne bouge plus,
    // et rien ne dit ni pourquoi ni jusqu'à quand. On attend qu'il soit
    // vraiment à quai pour l'expliquer — une règle s'enseigne devant ce qu'elle
    // décrit, pas trois écrans avant.
    const t = trains.find(o => o.id === _tutFirstId);
    // Il n'ira jamais à quai (mauvais quai choisi, service fini) : on passe.
    // Sans cette porte de sortie, le tutoriel attendrait indéfiniment un arrêt
    // qui n'aura pas lieu, et le deuxième train ne serait jamais présenté.
    if (!t || t.wrongPlatform || t.state === "done" || t.state === "movingBack" ||
        t.state === "movingOut") { onboarding = "wait2"; return; }
    if (t.state !== "dwell" || !t.el) return;
    freezeGame(true); onboarding = "board";
    coachAt(t.el,
      "Il est à quai. Les voyageurs montent et descendent : <b>deux minutes au minimum</b>. " +
      "Et il ne repartira jamais avant <b>son heure de départ</b>, celle du cadran — " +
      "même prêt, il attend l'heure. Tout cela se fait seul, vous n'avez rien à faire.",
      "Compris");
  } else if (onboarding === "free") {
    onboardingWatch();
  } else if (onboarding === "wait2") {
    const t = trains.find(o => !o.freight && !o.target && o.settled && o.id !== _tutFirstId &&
      (o.state === "waiting" || o.state === "approaching"));
    if (!t) return;
    freezeGame(true); onboarding = "tap2";
    coachAt(t.el, "Un autre train arrive. <b>Touchez-le</b> à son tour.");
  }
}
// Combien de quais s'allument à la sélection, et combien repartent réellement
// vers la destination du train. Calculé sur l'ÉTAT du jeu et non sur le DOM :
// onboardingTrainTapped est appelé avant refreshEligible(), les classes
// `.eligible` ne sont pas encore posées.
function tutPlatformCounts(t) {
  const lit = (LINKS[t.from] || []).filter(pid => !platformClaimed(pid) && !platformClosed(pid));
  return { lit: lit.length, serving: lit.filter(pid => paths["out:" + t.to + ":" + pid]).length };
}
// Plus rien à aiguiller NI à regarder entrer : le dernier train voyageur vient
// de s'arrêter à son quai. Tant qu'un convoi roule encore vers le sien, il se
// passe quelque chose à l'écran ; geler la partie à cet instant-là ferait
// manquer l'arrivée. On attend donc que plus aucun train n'attende une décision
// et qu'aucun ne soit en route vers son quai.
function tutIdle() {
  if (!trains.length) return false;
  return !trains.some(o => !o.freight &&
    (o.state === "waiting" || o.state === "approaching" || o.state === "movingIn"));
}
// Veille pendant le jeu libre du premier service.
function onboardingWatch() {
  if (!_tutHoldSeen) {
    // Feu rouge : un convoi À QUAI dont la voie de sortie est prise. C'est le
    // cas le plus déroutant — le train est là, à l'heure, et ne part pas.
    const t = trains.find(o => o.holding && o.state === "dwell" && o.el);
    if (t) {
      _tutHoldSeen = true; freezeGame(true); onboarding = "hold";
      coachAt(t.el, "Feu rouge : ce train est prêt, mais <b>sa voie de sortie est occupée</b>. " +
                    "Il repartira seul dès qu'elle se libère — vous n'avez rien à faire, " +
                    "et le retard court pendant ce temps.", "Compris");
      return;
    }
  }
  if (!_tutSpeedSeen && tutIdle()) {
    const btn = document.getElementById("btn-speed");
    if (!btn) return;
    _tutSpeedSeen = true; freezeGame(true); onboarding = "speed";
    coachAt(btn, "Tous les trains présents sont à quai : plus rien à décider pour l'instant. " +
                 "<b>Accélérez</b> pour ne pas attendre — vous pourrez ralentir dès qu'un train s'annonce.",
            "Compris");
  }
}
// Tap sur un train voyageur pendant le tutoriel → on désigne son quai.
// C'est LE point où se joue la règle : tous les quais atteignables s'allument,
// mais ils ne desservent pas tous la destination du train. Le dire ici, sinon
// « quai éclairé = bon quai » s'installe et le joueur ne comprend pas ses
// premiers refoulements.
function onboardingTrainTapped(t) {
  if (onboarding !== "tap1" && onboarding !== "tap2") return;
  const pl = document.querySelector('.platform[data-platform="' + tutServingPlatform(t) + '"]');
  const first = onboarding === "tap1";
  onboarding = first ? "plat1" : "plat2";
  const n = tutPlatformCounts(t);
  const choice = n.lit > 1 && n.serving < n.lit; // y a-t-il vraiment un piège ?
  coachAt(pl, first
    ? (choice
        ? "Plusieurs quais s'allument : le train peut entrer sur chacun. Mais tous ne " +
          "repartent pas vers <b>sa</b> destination — <b>celui-ci, oui</b>."
        : "Envoyez-le sur ce <b>quai éclairé</b> : il dessert sa destination.")
    : (choice
        ? "À nouveau plusieurs quais possibles. <b>Celui-ci</b> dessert sa destination."
        : "Envoyez-le sur ce <b>quai éclairé</b>."));
}
// Quai choisi pendant le tutoriel → étape d'explication suivante.
function onboardingPlatformChosen() {
  if (onboarding === "plat1") {
    onboarding = "delay";
    coachAt(document.getElementById("delay"),
      "Il entre et s'arrête. <b>Ici s'affiche le retard</b> cumulé du service — gardez-le au plus bas.",
      "Suivant");
  } else if (onboarding === "plat2") {
    onboarding = "goal";
    coachAt(document.getElementById("delay"),
      "Un quai occupé peut quand même être choisi : le convoi <b>attend dehors</b>, sans pénalité — seule compte l'heure de départ. À vous ! Terminez le service avec <b>moins de 30 min</b> de retard pour décrocher une étoile.",
      "Continuer");
  }
}
// Bouton du repère (étapes d'explication) : avance / termine.
function coachNext() {
  if (onboarding === "pickStation") {
    // Accueil de la carte : on le referme, il ne revient plus de la partie.
    _mapWelcomeOff = true; onboarding = null; hideCoach();
  } else if (onboarding === "delay") {
    // On laisse tourner : le convoi entre en gare, et c'est SON ARRIVÉE À QUAI
    // qui déclenche l'explication suivante (onboardingTick, étape « dwell1 »).
    onboarding = "dwell1"; hideCoach(); freezeGame(false);
  } else if (onboarding === "board") {
    onboarding = "wait2"; hideCoach(); freezeGame(false); // le 1er part, un 2e arrive
  } else if (onboarding === "goal") {
    // Le guidage pas-à-pas est fini et ne se rejouera plus (setOnboarded), mais
    // on continue de guetter deux situations sur CE service : le premier feu
    // rouge, et le moment où il n'y a plus rien à aiguiller.
    onboarding = "free"; hideCoach();
    if (typeof setOnboarded === "function") setOnboarded(true);
    freezeGame(false);
  } else if (onboarding === "hold" || onboarding === "speed") {
    onboarding = "free"; hideCoach(); freezeGame(false);
  }
}
// --- Repère : halo pulsé sur la cible (spotlight) + bulle de texte (+ bouton). ---
function coachAt(target, html, btnLabel) {
  _coachTarget = target || null;
  const box = document.getElementById("coach");
  const txt = document.getElementById("coach-text");
  const btn = document.getElementById("coach-next");
  if (!box || !txt || !btn) return;
  txt.innerHTML = html;
  btn.textContent = btnLabel || "Suivant";
  btn.classList.toggle("hidden", !btnLabel); // bouton seulement pour les explications
  box.classList.remove("hidden");
  positionCoach();
}
function hideCoach() {
  _coachTarget = null;
  const box = document.getElementById("coach");
  if (box) box.classList.add("hidden");
}
// Recalé chaque frame (depuis la boucle) : le halo épouse la cible, la bulle se
// place au-dessus ou en dessous selon la place, ergot pointé vers la cible.
function positionCoach() {
  const box = document.getElementById("coach");
  if (!box || box.classList.contains("hidden")) return;
  // Sans cible : bulle seule, centrée en bas. Sert aux étapes qui parlent de
  // PLUSIEURS éléments à la fois (les portes d'entrée sur la carte) — y poser un
  // halo désignerait arbitrairement l'un d'eux.
  if (!_coachTarget) {
    const ring = document.getElementById("coach-ring");
    const bubble = document.getElementById("coach-bubble");
    ring.style.display = "none";
    bubble.classList.remove("above"); bubble.classList.add("no-caret");
    bubble.style.left = "50%";
    bubble.style.top = "auto";
    bubble.style.bottom = "calc(26px + var(--safe-b))";
    return;
  }
  document.getElementById("coach-ring").style.display = "";
  document.getElementById("coach-bubble").classList.remove("no-caret");
  if (!_coachTarget.getBoundingClientRect) return;
  const r = _coachTarget.getBoundingClientRect();
  if (!r.width && !r.height) return;
  const ring = document.getElementById("coach-ring");
  const bubble = document.getElementById("coach-bubble");
  const pad = 8;
  ring.style.left = (r.left - pad) + "px";
  ring.style.top = (r.top - pad) + "px";
  ring.style.width = (r.width + 2 * pad) + "px";
  ring.style.height = (r.height + 2 * pad) + "px";
  const vh = window.innerHeight, vw = window.innerWidth;
  const below = (r.top + r.height / 2) < vh * 0.5; // cible haute → bulle dessous
  const targetCx = r.left + r.width / 2;
  // bulle maintenue entièrement à l'écran (cible au bord comprise)…
  const bw = bubble.offsetWidth || 300, half = bw / 2 + 8;
  const cx = Math.max(half, Math.min(vw - half, targetCx));
  bubble.style.left = cx + "px";
  // …mais l'ergot continue de pointer la cible même si la bulle a été recentrée
  const caret = Math.max(14, Math.min(bw - 14, targetCx - (cx - bw / 2)));
  bubble.style.setProperty("--caret", caret + "px");
  bubble.classList.toggle("above", !below);
  bubble.classList.toggle("below", below);
  const gap = 16;
  if (below) { bubble.style.top = (r.top + r.height + gap) + "px"; bubble.style.bottom = "auto"; }
  else { bubble.style.top = "auto"; bubble.style.bottom = (vh - r.top + gap) + "px"; }
}

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
  if (typeof stopConfetti === "function") stopConfetti(); // salve d'un service précédent
  started = false; ended = false; paused = false;
  gameMin = 0; speed = 1;
  totalDelay = 0; selected = null; activeRoutes = {}; queueSeq = 0;
  onTimeStreak = 0;
  hideCoach(); // efface un éventuel repère de tutoriel resté d'un service précédent
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
    // le fret s'aiguille comme les autres : aucun quai ne lui est pré-attribué
    platform: null, target: null,
    entryPath: null, exitPath: null, exitTo: null, refoul: false, validated: false,
    pendingEl: null, stopS: null, startS: 0, backS: 0,
    actualArr: null, queuedAt: null, el: null, carEls: null, maskEls: null,
    badgeEl: null, badgeText: null, badgeRect: null, headPos: null
  }));
  buildTimeline();
  buildServiceBar();
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
// Tête de file d'approche : aucun convoi du même portail, entré dans la file
// avant lui, n'attend encore. C'est LE critère du FIFO (pas de dépassement, le
// 2ᵉ ne double jamais le 1ᵉʳ) — et aussi celui du feu rouge : seul le premier
// est retenu par la gare, ceux de derrière sont retenus par lui.
function isQueueHead(t) {
  return !trains.some(o => o !== t && o.from === t.from &&
    o.queuedAt < t.queuedAt &&
    (o.state === "approaching" || o.state === "waiting"));
}
// UN CONVOI QUI QUITTE LE QUAI PASSE AVANT UN FRET QUI ARRIVE.
//
// Les deux visent la même gorge d'aiguillage ; sans arbitrage, c'est l'ordre du
// tableau qui tranche, c'est-à-dire le hasard. Or le convoi à quai LIBÈRE une
// place et tient une heure de départ, quand le fret ne fait que traverser et
// n'a aucun horaire. Le fret cède donc et s'arrête au quai — un bloc de plus à
// attendre pour lui, une minute de retard en moins pour l'autre.
function departureWaiting(exitId, self) {
  return trains.some(o => {
    if (o === self || o.state !== "dwell" || o.wrongPlatform || o.platform == null) return false;
    // « prêt à partir » : le fret l'est toujours, les autres à leur heure.
    if (!(o.freight || gameMin >= Math.max(o.dep, o.actualArr + MIN_DWELL))) return false;
    const oid = "out:" + o.to + ":" + o.platform;
    if (!paths[oid]) return false;
    return oid === exitId || !!(conflicts[oid] && conflicts[oid][exitId]);
  });
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
  // itinéraire à la couleur de la DESTINATION, fret compris (son gris ne vaut
  // que pour ses wagons — voir trainNode)
  const c = DEST_COLOR[train.to];
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
// Quai PROMIS : un convoi encore dehors l'a déjà choisi. C'est la seule
// réservation qui INTERDIT le choix — deux convois ne peuvent pas viser le même
// quai, sinon le second entrerait sur un quai qu'on lui a pris.
function platformClaimed(pid) {
  return trains.some(t => t.target === pid &&
    (t.state === "waiting" || t.state === "approaching"));
}
// Réservation pour l'AFFECTATION : un convoi en transit (movingThrough) ne
// bloque pas le choix du quai — on peut pré-affecter, l'entrée attendra.
// Le fret n'a plus aucun régime propre ici : il réserve son quai comme les
// autres, dès qu'un joueur le lui a donné, et pas avant.
// Sert aux choix AUTOMATIQUES (fret, tutoriel), qui veulent un quai franchement
// disponible ; le joueur, lui, a le droit de viser un quai encore occupé (cf.
// onPlatformClick).
function platformReserved(pid) {
  return platformClaimed(pid) ||
    trains.some(t => t.platform === pid &&
      (t.state === "movingIn" || t.state === "dwell"));
}
// Choix du quai d'un FRET — il s'aiguille seul, le joueur n'y touche pas.
// Il se sert exactement comme le joueur sert un voyageur : le premier quai qui
// dessert sa destination, ni fermé ni déjà promis à un autre convoi. Ce quai
// lui est alors réservé et il attend que l'itinéraire se libère (l'entrée est
// re-vérifiée juste après). On n'exige donc PAS que la voie soit libre à
// l'instant du choix : sinon, sur une gare chargée où tous les quais sont
// promis en permanence, le fret ne se servirait jamais et bloquerait sa file.
// Le quai de calibrage (hint) passe en premier — c'est celui que le générateur
// a retenu pour que la journée reste jouable à zéro.
function pickFreightPlatform(t) {
  const ok = pid => !!paths["out:" + t.to + ":" + pid] &&   // dessert sa destination
    !platformReserved(pid) && !platformClosed(pid);
  if (t.hint != null && LINKS[t.from].includes(t.hint) && ok(t.hint)) return t.hint;
  const free = LINKS[t.from].filter(ok);
  // à défaut du quai de calibrage : celui où il peut s'engager TOUT DE SUITE
  // (entrée et sortie libres, personne à quai) — il squatte ainsi le moins
  // longtemps possible un quai dont le joueur pourrait avoir besoin.
  return free.find(pid =>
    !trains.some(o => o !== t && o.platform === pid &&
      (o.state === "movingIn" || o.state === "dwell" || o.state === "movingThrough")) &&
    canGrant("in:" + t.from + ":" + pid) && canGrant("out:" + t.to + ":" + pid))
    ?? free[0] ?? null;
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
  const eligColor = selecting ? DEST_COLOR[selected.to] : null; // fret compris : c'est sa destination qui compte
  // faisceau : on éclaire la ville d'origine du train choisi, on estompe le reste
  if (typeof focusPortal === "function") focusPortal(selecting ? selected.from : null);
  document.querySelectorAll(".platform").forEach(pl => {
    const pid = +pl.dataset.platform;
    // TOUS les quais accessibles depuis l'origine sont surlignés à l'identique
    // (à la couleur de la destination). On ne dit PAS lequel dessert vraiment la
    // destination : c'est au joueur de le savoir. Un mauvais choix reste possible
    // et sanctionné par un refoulement — signalé au clic et à l'arrêt, mais pas
    // AVANT le choix (sinon il n'y aurait plus d'erreur possible, donc plus de jeu).
    // Un quai OCCUPÉ reste éligible : le convoi patientera dehors et entrera
    // dès qu'il se libère. Il s'affiche seulement d'une main plus légère
    // (« busy ») — disponible, mais pas tout de suite.
    const ok = selecting &&
               LINKS[selected.from].includes(pid) &&
               !platformClaimed(pid) && !platformClosed(pid);
    pl.classList.toggle("eligible", !!ok);
    pl.classList.toggle("busy", !!ok && platformOccupied(pid));
    pl.classList.remove("serves"); // (plus de distinction visuelle à la sélection)
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
    // Quai en défaut : un train y stationne alors qu'il n'en repart pas vers sa
    // destination → liseré rouge le temps qu'il refoule (explique l'attente).
    pl.classList.toggle("wrong", !!(occ && occ.wrongPlatform && occ.state === "dwell"));
    if (occ) pl.style.setProperty("--occ", DEST_COLOR[occ.to]);
    else pl.style.removeProperty("--occ");
    // Quai PROMIS : un convoi encore dehors l'a choisi et attend d'y entrer. On
    // le montre au repos, à la couleur du convoi ATTENDU (pas de celui qui est
    // là) — c'est ce qui rend l'attente lisible plutôt que muette, et ce qui
    // évite au joueur de compter sur un quai déjà pris.
    const claim = trains.find(t => t.target === pid &&
      (t.state === "waiting" || t.state === "approaching"));
    const grp = pl.parentNode;
    grp.classList.toggle("claimed", !!claim);
    if (claim) grp.style.setProperty("--claim", DEST_COLOR[claim.to]);
    else grp.style.removeProperty("--claim");
  });
}
function onPlatformClick(pid) {
  if (!selected || selected.target ||
      (selected.state !== "waiting" && selected.state !== "approaching")) return;
  const q = PLATFORMS.find(x => x.id === pid);
  const center = { x: (PLAT_X1 + PLAT_X2) / 2, y: q.cy };
  if (!LINKS[selected.from].includes(pid)) {
    flashAt(center); flashLabel(center, "Aucune voie ici", "warn");
    return;
  }
  // Seul un quai DÉJÀ PROMIS à un autre convoi est refusé. Un quai simplement
  // occupé, lui, s'accepte : le convoi patiente dehors et entrera dès qu'il se
  // libère (cf. l'entrée automatique, plus bas dans tick). C'est le cœur du
  // jeu — attendre à l'extérieur ne coûte rien, seule compte l'heure de départ,
  // donc la ressource rare est le quai. Refuser ce geste obligeait à revenir
  // tapoter plus tard : de la charge mécanique, pas une décision.
  if (platformClaimed(pid)) {
    flashAt(center); flashLabel(center, "Quai déjà promis", "warn");
    return;
  }
  if (platformClosed(pid)) {
    flashAt(center); flashLabel(center, "Quai fermé", "warn");
    return;
  }
  const deferred = platformOccupied(pid); // entrée différée : on le DIT
  selected.target = pid;
  const pathId = "in:" + selected.from + ":" + pid;
  // l'itinéraire en pointillés démarre à la position actuelle du convoi. On NE
  // révèle PAS ici qu'un quai est mauvais : le tracé reste à la couleur de la
  // destination. L'erreur ne se découvre qu'à l'arrivée du train (pilule + demi-
  // tour), pour laisser le joueur se tromper.
  const ap = APPROACH[selected.from];
  const lead = slicePts(ap, selected.qs != null ? selected.qs : ap.len, ap.len);
  const pend = el("path", {
    d: pathD(lead.concat(paths[pathId].pts)),
    class: "route pending"
  }, gRoutes);
  pend.style.stroke = DEST_COLOR[selected.to]; pend.style.color = DEST_COLOR[selected.to];
  selected.pendingEl = pend;
  selected = null;
  // Quai encore occupé : le geste a bien été pris, mais rien ne bougera tout de
  // suite. Sans ce signe, l'immobilité se lirait comme un geste raté — et dire
  // « occupé » se lirait comme un refus, alors que le convoi prend simplement la
  // file. D'où le sablier : une seconde, au-dessus du quai.
  if (deferred) flashWait({ x: center.x, y: q.cy - PLAT_H / 2 - 14 });
  onboardingPlatformChosen(); // accueil : geste complet → joueur initié
  refreshEligible();
  // Le liseré « promis » se pose ICI, pas au prochain tick : en pause — le
  // moment où l'on aiguille le plus — aucun tick ne viendrait le peindre, et le
  // geste resterait sans trace jusqu'à la reprise.
  refreshPlatformStates();
}
function onTrainClick(t) {
  if (ended) return;
  if (t.freight) {
    // Le fret s'aiguille tout seul : il n'y a rien à décider pour lui. On ne le
    // sélectionne donc pas — mais le tap n'est pas mort pour autant, une pilule
    // dit pourquoi (règle générale du jeu : aucun geste sans retour).
    flashLabel(t.headPos, "Fret · passage auto", "info");
    return;
  }
  // Sélectionnable dès l'approche : on peut préparer l'itinéraire avant l'arrêt
  const routable = t.state === "waiting" || t.state === "approaching";
  if (routable && !t.target) {
    onboardingTrainTapped(t); // tutoriel : le repère passe du train à son quai
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
// trains pas encore partis — le compteur bouge PENDANT que le joueur hésite.
// On ne compte que les MINUTES ENTIÈRES de retard, par convoi : un train sous
// la minute est « à l'heure » (même règle que la pastille) et pèse 0. Ainsi le
// compteur et la mention « à l'heure » ne peuvent plus se contredire.
function liveDelay() {
  let d = totalDelay;
  for (const t of trains)
    if (!t.freight && (t.state !== "movingOut" || t.refoul) && t.state !== "done")
      d += Math.floor(Math.max(0, lateness(t, gameMin)));
  return d;
}
function updateDelay() {
  const d = document.getElementById("delay");
  const v = liveDelay();
  d.textContent = "+" + Math.round(v);
  // Couleur alignée sur le barème d'étoiles : vert tant qu'on vise 3★ (< 10),
  // ambre tant qu'une étoile reste jouable (< 30), rouge dès que 0★ (≥ 30).
  d.className = v < 10 ? "" : v < 30 ? "warn" : "bad";
  updateGoal(v);
}

// ------------------------------------------------------------------
// LE RECORD À BATTRE — la seule chose qu'on ne puisse pas déduire.
// ------------------------------------------------------------------
// Ce bandeau a d'abord porté le palier tenu (trois étoiles), une barre de marge
// et « marge 4 min ». Retiré : il RÉ-ENCODAIT un nombre déjà affiché. Avec les
// seuils 10 / 20 / 30, « +8 » donne la marge par soustraction, et les étoiles
// ne disaient rien que la couleur du « +8 » ne dise déjà (vert, ambre, rouge).
// Cinq objets à lire pour une information qu'on avait, sur un ruban de dix
// pixels de haut.
//
// Reste ce qui n'est nulle part ailleurs : LE RECORD DE LA GARE. C'est aussi la
// seule mesure qui décide de l'argent — les crédits ne tombent que si l'on bat
// son propre palier (js/catalog.js, stationGain). Le joueur court contre
// lui-même, et le bandeau ne dit que cela.
//
// Quand la journée est perdue, le record n'a plus d'objet : la croix et le
// raccourci de reprise prennent sa place.
function updateGoal(v) {
  const row = document.getElementById("goal-row");
  const rec = document.getElementById("goal-rec");
  const redo = document.getElementById("goal-redo");
  if (!row || !redo) return;
  const best = STATION.adhoc ? null : (getProgress()[STATION.id] || {}).bestDelay;
  // « Perdue » se lit sur le BARÈME lui-même, et sur le retard ARRONDI comme en
  // fin de service : à +29,5 min endGame arrondit à 30 et n'accorde rien.
  const perdu = !STATION.adhoc && typeof palierOf === "function" && palierOf(Math.round(v)) < 0;
  // LE RACCOURCI DE REPRISE VIT À CÔTÉ DU RETARD, pas sur une ligne à lui. Il
  // n'apparaît que lorsque la journée est perdue — le retard passé au rouge, à
  // sa gauche, dit déjà pourquoi. Une croix en plus ne faisait que répéter cette
  // couleur, et elle occupait une ligne pour ne rien ajouter.
  redo.classList.toggle("hidden", !perdu);
  // Le record cède la place : la journée perdue, il n'a plus d'objet. Et une
  // gare jamais jouée n'affiche rien — une ligne vide sous l'horloge se lit
  // comme un défaut d'affichage.
  const montre = best != null && !perdu;
  row.classList.toggle("hidden", !montre);
  if (montre) rec.textContent = best === 0 ? "rec. parfait" : "rec. +" + best;
}


// PAS DE COMPTEUR D'ARGENT PENDANT LE SERVICE — essayé, retiré.
//
// Le bandeau affichait la recette en cours, plafond déduit. Le compte est
// juste, mais il se lit à l'envers : la prime du sans-faute vaut le double, si
// bien que la première minute de retard fait tomber le nombre de moitié (120 →
// 60 à Landen). Le joueur ne lit pas « je gagne un peu moins », il lit « je
// perds de l'argent », et il le lit pendant qu'il travaille. Aucun réglage de
// présentation ne rattrape cela : ce n'est pas la forme du compteur qui blesse,
// c'est qu'un gain baisse sous les yeux de celui qui fait de son mieux.
//
// La recette s'annonce donc une seule fois, à la fin, quand elle est acquise
// (voir endGame). Pendant le service il reste le retard, qui monte — une chose
// qui monte quand on fait mal se lit sans détour.

// Reste-t-il un convoi en mouvement ? Sert à prolonger l'animation APRÈS la fin
// du service : la modale sort tôt (score figé), mais les derniers convois doivent
// finir de glisser hors écran en arrière-plan.
function anyTrainMoving() {
  return !!trains && trains.some(t =>
    t.state === "movingOut" || t.state === "movingThrough" ||
    t.state === "movingIn" || t.state === "movingBack");
}

function tick(dtMin) {
  processEvents();
  for (const t of trains) {
    switch (t.state) {

      case "scheduled":
        // Le train apparaît au loin ~1,3 min avant son heure et approche en douceur.
        // Le fret suit exactement la même règle : il prend sa place dans la file
        // d'approche, se fait aiguiller par le joueur, et n'a de particulier que
        // de ne pas s'arrêter au quai (voir « waiting » et movingThrough).
        if (gameMin >= (t.arrEff ?? t.arr) - APPROACH_LEAD) {
          t.state = "approaching";
          t.queuedAt = queueSeq++; // ordre réel d'entrée sur la voie d'approche
          t.el = trainNode(t);
          if (t.freight) SND.freight(); // corne grave : un lourd convoi se présente
          const tl = document.getElementById("tl-" + t.id);
          if (tl) tl.classList.add("active");
        }
        break;

      case "approaching":
        placeQueue(t, dtMin);
        t.el.classList.toggle("selected", selected === t);
        // « ready » = ce convoi attend une décision. Jamais pour un fret : il
        // n'y a rien à décider, il ne doit donc pas appeler le doigt.
        t.el.classList.toggle("ready", !t.freight && !t.target && selected !== t);
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
        // « ready » = ce convoi attend une décision. Jamais pour un fret : il
        // n'y a rien à décider, il ne doit donc pas appeler le doigt.
        t.el.classList.toggle("ready", !t.freight && !t.target && selected !== t);
        // FIFO sur la voie d'approche : tant qu'un train du même portail, entré
        // avant lui dans la file, n'a pas dégagé la voie, il ne peut pas
        // s'engager — pas de dépassement (le 2ᵉ ne double jamais le 1ᵉʳ).
        // Le fret compte dans la file comme les autres : il peut donc retenir
        // ceux qui le suivent, et c'est bien là sa nuisance.
        if (!isQueueHead(t)) break;
        // Le fret n'est PAS aiguillé par le joueur : il se donne son quai tout
        // seul, et seulement à l'instant où il peut réellement s'engager (voir
        // pickFreightPlatform). Tant qu'aucun quai ne convient il patiente sans
        // rien réserver — le joueur garde donc tous ses quais à sa main.
        if (t.freight && !t.target) {
          const pid = pickFreightPlatform(t);
          if (pid == null) break;
          t.target = pid;
        }
        // Entrée automatique dès que l'itinéraire demandé est libre — et que
        // le quai est physiquement dégagé (un convoi en transit peut encore
        // l'occuper alors que le joueur a déjà pré-affecté le quai)
        if (t.target && !platformClosed(t.target)) {
          const busy = trains.some(o => o !== t && o.platform === t.target &&
            (o.state === "movingIn" || o.state === "dwell" || o.state === "movingThrough"));
          const pathId = "in:" + t.from + ":" + t.target;
          // CANTONNEMENT DU FRET, UN BLOC À LA FOIS. Il s'engage dès que sa voie
          // d'entrée et le quai sont libres, et il ne réserve QUE cela.
          //
          // Il verrouillait auparavant sa voie de sortie au même instant, quand
          // elle était libre, pour traverser d'une traite. Un convoi à quai qui
          // partait dans la même direction se retrouvait alors au feu rouge à
          // cause d'un fret qui n'avait pas encore atteint le quai — il tenait
          // un aiguillage dont il était encore à une demi-gare. La sortie se
          // demande donc à l'arrivée au quai, et pas avant (voir « movingIn »).
          if (!busy && canGrant(pathId)) {
            if (t.pendingEl) { t.pendingEl.remove(); t.pendingEl = null; }
            grant(pathId, t);
            t.entryPath = pathId;
            t.platform = t.target;
            // le trajet d'entrée démarre au point d'arrêt réel sur la voie
            // d'approche (abscisse négative : en amont du point de convergence)
            t.startS = t.qs != null ? -(APPROACH[t.from].len - t.qs) : 0;
            t.progress = 0;
            t.badgeLift = 0;
            t.el.classList.remove("ready", "selected");
            gTrains.appendChild(t.el); // entre en gare : calque découpé au tunnel
            // tous les trains tirent jusqu'en tête de quai (heurtoir compris)
            t.stopS = paths[pathId].len;
            t.state = "movingIn";
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
          // LE FRET DEMANDE SA SORTIE ICI, au quai, et nulle part avant. Libre :
          // il enchaîne sans s'arrêter, comme un fret doit le faire. Prise : il
          // s'arrête au quai, au rouge, et repartira dès qu'elle se dégage
          // (le « dwell » ordinaire s'en charge — il n'a pas d'heure à tenir).
          const outId = "out:" + t.to + ":" + t.platform;
          if (t.freight && paths[outId] && canGrant(outId) && !departureWaiting(outId, t)) {
            release(t.entryPath);
            grant(outId, t);
            t.exitPath = outId;
            t.startS = t.stopS;   // il reprend la traversée depuis la tête de quai
            t.progress = 0;
            t.state = "movingThrough";
            refreshEligible();
            break;
          }
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
          if (!t.wrongPlatform) {
            // instant de l'arrêt sur le mauvais quai : on l'explique tout de
            // suite (pilule + son), puis le train refoule sans attendre
            t.wrongPlatform = true;
            flashLabel(t.headPos, "Mauvais quai — refoulement", "warn");
            SND.incident();
          }
          // Demi-tour IMMÉDIAT (plein, sans arrêt) : le convoi RECULE le long de
          // sa voie d'entrée jusqu'à l'aiguillage et s'y arrête, prêt à être
          // ré-aiguillé — il ne quitte jamais l'écran (pas de disparition/réapparition).
          const backPath = "in:" + t.from + ":" + t.platform;
          if (canGrant(backPath)) {
            grant(backPath, t);
            t.exitPath = backPath;
            t.state = "movingBack";
            t.progress = 1 - t.stopS / paths[backPath].len;
            refreshEligible();
          }
          break;
        }
        // Un FRET ne stationne pas : s'il est là, c'est qu'il a trouvé sa sortie
        // occupée en arrivant. Il tient donc le signal et repart à la seconde
        // où elle se libère — ni heure de départ, ni arrêt minimum.
        const canLeave = t.freight || gameMin >= Math.max(t.dep, t.actualArr + MIN_DWELL);
        if (canLeave) {
          const pathId = "out:" + t.to + ":" + t.platform;
          if (canGrant(pathId)) {
            t.holding = false;
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
            // Le fret n'a pas d'heure à tenir : il ne pèse pas au score et ne
            // touche NI au retard cumulé, NI à la série de départs à l'heure.
            if (t.freight) {
              SND.depart();
            } else {
              t.depDelay = Math.max(0, lateness(t, gameMin));
              // On n'encaisse que les minutes entières (même règle que liveDelay
              // et que la mention « à l'heure »). depDelay garde la valeur brute
              // pour la pastille et le pire retardataire du bilan.
              totalDelay += Math.floor(t.depDelay);
              // Juice : un départ À L'HEURE (< 1 min) allonge la série et
              // déclenche un éclat vert + un carillon qui monte avec le combo ;
              // un départ en retard casse la série (le badge rouge suffit à le dire).
              if (t.depDelay < 1) {
                onTimeStreak++;
                flashOnTime(t.headPos, onTimeStreak);
                SND.onTime(onTimeStreak);
              } else {
                onTimeStreak = 0;
                SND.depart();
              }
            }
            updateDelay();
            refreshEligible();
          } else if (!t.holding) {
            // Prêt à repartir, mais sa voie de sortie est occupée par le passage
            // d'un autre convoi : on le SIGNALE (pilule ambre + pulsation du
            // train) pour que le joueur comprenne pourquoi il reste à quai.
            // Plus de mention de texte : un feu rouge se dresse devant la
            // motrice tant que la voie est prise (updateHoldSignal, render.js).
            t.holding = true;
          }
        } else {
          t.holding = false; // arrêt en cours (embarquement) : pas encore bloqué
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
          t.wrongPlatform = false;
          // Le convoi a reculé jusqu'à l'aiguillage : on l'y LAISSE (tête à la
          // gorge du portail), il ne repart PAS hors écran. En passant en
          // « waiting » avec un qs valide (≠ null), placeQueue le fait juste
          // glisser à sa position d'attente sans le cacher/réapparaître.
          t.qs = APPROACH[t.from].len; t.settled = false;
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
            t.wrongPlatform = false;
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
        const tail = (t.cars - 1) * CAR_SPACING;
        const endU = 1 + (tail + EXIT_RUN) / totalArc;
        // démarrage progressif depuis son point d'arrêt, puis roule sans s'arrêter
        const s0 = t.startS || 0;
        // La durée suit la DISTANCE QUI RESTE : un fret qui reprend depuis la
        // tête de quai a la moitié du chemin à faire, il doit y mettre la moitié
        // du temps. Sans cela il roulait deux fois moins vite après un arrêt.
        const durTot = TRAVEL * totalArc / 700 * FREIGHT_SLOWNESS *
                       (endU * totalArc - s0) / (endU * totalArc);
        t.progress += dtMin / durTot;
        const h = s0 + easeRun(t.progress / endU, 0.12, 0) * (endU * totalArc - s0);
        // LE QUAI SE LIBÈRE QUAND LE FRET L'A QUITTÉ, PAS QUAND IL A QUITTÉ LA
        // GARE. Le fret garde l'état « movingThrough » de bout en bout, et
        // `busy` compte cet état comme une occupation (voir plus haut) : son
        // quai restait donc pris pendant TOUTE la course de sortie, alors qu'il
        // était déjà loin. Le convoi suivant devait attendre que le fret ait
        // franchi l'aiguillage de sortie pour s'engager.
        //
        // Un voyageur, lui, passe en « movingOut » — état ABSENT de `busy` — et
        // libère son quai dès qu'il s'ébranle. Le fret s'aligne : dernier wagon
        // au-delà de la voie d'entrée, le quai est rendu.
        //
        // IL Y AVAIT ICI UN release(t.entryPath) QUI NE POUVAIT JAMAIS S'EXÉCUTER :
        // l'itinéraire d'entrée est relâché au moment même où le fret bascule en
        // « movingThrough » (voir « movingIn »), donc activeRoutes[entryPath]
        // n'est déjà plus ce convoi. Sa présence donnait à croire que quelque
        // chose se libérait ici, et masquait le fait que le quai, lui, ne se
        // libérait qu'à la gorge du portail.
        //
        // Rien n'est relâché de trop : l'itinéraire de SORTIE reste verrouillé
        // jusqu'à cette gorge (plus bas), donc un convoi entrant dont la route
        // croise celle du fret sera toujours retenu par l'enclenchement.
        if (t.platform != null && h - tail > pin.len) {
          t.platform = null;
          refreshEligible();
        }
        // sortie relâchée seulement quand le dernier wagon a dégagé la gorge
        // du portail (au-delà de la fin de l'itinéraire + PORTAL_CLEAR)
        if (h - tail > totalArc + PORTAL_CLEAR && activeRoutes[t.exitPath] === t) {
          release(t.exitPath);
          refreshEligible();   // le quai, lui, est déjà rendu (voir au-dessus)
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
    updateHoldSignal(t); // feu rouge devant un convoi retenu à quai
    if (t.el) t.el.classList.toggle("holding", !!t.holding); // voie de sortie occupée
  }
  updateTimeline();
  updateServiceBar(); // horizon : curseur + encoches (reste-à-faire, pointe à venir)
  updateDelay();
  refreshPlatformStates();
  updateQueueUI(); // file d'attente en réduction (l'essentiel se joue hors champ)
  onboardingTick(); // accueil : gèle le service dès qu'un train est prêt à tapoter

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

// Décompte d'un montant, de `from` à `to`. Sortie rapide puis ralentie
// (easeOutCubic) : le chiffre part d'un coup — on voit tout de suite que ça
// monte — et s'installe doucement sur sa valeur, qu'on a le temps de lire.
// Respecte prefers-reduced-motion : on pose alors le total, sans mouvement.


// LA GARE QUE DÉSIGNE LE BOUTON — pour que la carte la désigne aussi.
//
// Le relevé nomme un pas suivant (« Ouvrir Anvers »), et le joueur devait
// ensuite CHERCHER Anvers parmi cent quarante-cinq points. Un bouton qui nomme
// un lieu doit pouvoir être suivi du regard : la pastille correspondante
// respire tant que le relevé est ouvert.
//
// Une seule chose respire à la fois sur la carte (js/mapnet.js) : ici, ce n'est
// plus le service en attente mais la cible du bouton — qui EST le service en
// attente quand il y en a un. La règle ne change donc pas, elle se déplace avec
// ce qu'on demande au joueur de faire.
// ------------------------------------------------------------------
// LA FICHE DE FIN TIENT DANS L'ÉCRAN — pour la seule démo « limites ».
// ------------------------------------------------------------------
// Une gare du catalogue ne passe plus par cette fiche : son résultat se pose
// en BULLE sous la gare, sur la ligne (js/carte.js, bilanHTML). La fiche
// centrée ne sert plus qu'à la démo limites, qui n'est sur aucune carte.
//
// `zoom` et non `transform: scale()` : zoom modifie la MISE EN PAGE, donc le
// centrage et le `max-height` de la fiche continuent de fonctionner tout seuls.
// Le plancher existe pour que le remède ne devienne pas le mal : sous 70 %, on
// laisse défiler plutôt que d'imposer un texte qu'on ne peut plus lire.
const END_FIT_FLOOR = 0.7;
function fitEndCard() {
  const ov = document.getElementById("end");
  if (!ov || ov.classList.contains("hidden")) return;
  const card = ov.querySelector(".card");
  if (!card) return;
  card.style.zoom = "";                       // on mesure toujours à taille réelle
  const st = getComputedStyle(ov);
  const avail = ov.clientHeight - parseFloat(st.paddingTop) - parseFloat(st.paddingBottom);
  const nat = card.scrollHeight + 2;          // scrollHeight ignore la bordure
  if (!(nat > 0) || !(avail > 0) || nat <= avail) return;
  card.style.zoom = Math.max(END_FIT_FLOOR, avail / nat).toFixed(3);
}
window.addEventListener("resize", fitEndCard);

// TROIS ÉTOILES, TROIS OBJETS — et non une chaîne « ★★☆ ». Chacune s'allume à
// son tour (CSS, st-pop), et une étoile NEUVE — que cette gare n'avait pas
// avant ce service — brille plus fort : c'est elle, la récompense. Partagé
// entre la bulle de la ligne et la fiche de la démo.
function etoilesHTML(stars, prevStars) {
  return [0, 1, 2].map(i =>
    '<span class="st' + (i < stars ? " on" : " off") +
    (i >= prevStars && i < stars ? " neuve" : "") +
    '" style="--i:' + i + '">★</span>').join("");
}

// failed = true : retard plafond dépassé (game over, 0 étoile, rien à débloquer)
function endGame(failed) {
  ended = true;
  // en échec, on affiche le retard « vivant » (celui qui a crevé le plafond),
  // sinon le retard cumulé réellement encaissé
  const d = Math.round(failed ? liveDelay() : totalDelay);
  // Tolérance de retard (minutes). Elle SUIT LA DIFFICULTÉ de la gare pour les
  // trois étoiles (12 min au niveau 1, 8 au niveau 5 — js/ruban.js, SEUILS) ;
  // une étoile reste à 30 partout, parce que c'est le plancher qui rend le
  // ruban praticable. Le repli sert à la démo « limites », hors ruban.
  const seuils = typeof seuilsDeService === "function"
    ? seuilsDeService(STATION) : { trois: 10, deux: 20, une: 30 };
  const stars = failed ? 0 : (typeof etoilesPour === "function"
    ? etoilesPour(d, seuils)
    : (d < seuils.trois ? 3 : d < seuils.deux ? 2 : d < seuils.une ? 1 : 0));
  // Réussite = au moins une étoile (débloque la suite). 0 étoile = échec, qu'on
  // ait terminé sans étoile OU crevé le plafond de retard : dans les deux cas il
  // faut recommencer.
  const win = stars >= 1;
  // Service PARFAIT : gagné, terminé sans le moindre retard cumulé.
  const perfect = win && !failed && d === 0;
  // Étoiles et record de CETTE gare AVANT enregistrement : c'est la différence
  // qui dit ce que le service a rapporté, et le record d'avant qui dit si on
  // vient de se dépasser. Mesurés après, ils vaudraient le service du jour.
  const prevStars = (getProgress()[STATION.id] || {}).stars || 0;
  const prevBest = (getProgress()[STATION.id] || {}).bestDelay;
  const noPay = failed || STATION.adhoc;
  // Un échec (ou la démo limites) ne modifie pas le record — mais il se note
  // quand même : une gare tentée et ratée n'ouvre pas la suivante (js/ruban.js,
  // estFranchie), et il faut pouvoir la distinguer d'une gare jamais jouée.
  if (!STATION.adhoc) {
    if (failed) markTentee(STATION.id);
    else saveResult(STATION.id, stars, d);
  }
  // LA SÉRIE SE TIENT APRÈS L'ENREGISTREMENT. La démo « limites » ne compte
  // pas. Un ÉCHEC, lui, compte : il casse la série — le seul endroit du jeu où
  // rater a une conséquence, et elle est minuscule.
  if (!STATION.adhoc && typeof pushSerie === "function") pushSerie(!failed && stars >= SERIE_SEUIL);
  const etoilesGagnees = noPay ? 0 : Math.max(0, stars - prevStars);
  (perfect ? SND.perfect : win ? SND.end : SND.incident)(); // parfait → fanfare, 0 étoile → échec

  // Le total d'étoiles de la carte compte en même temps : la récompense ne
  // s'additionne pas dans un coin de fiche, elle tombe dans le compteur qu'on
  // voit déjà. Lancé APRÈS le rendu de la carte, sinon il file à vide.
  function rollRecette() {
    if (noPay || !CARTE.etoiles || typeof etoilesTotal !== "function") return;
    const apres = etoilesTotal(), avant = apres - etoilesGagnees;
    if (apres === avant) return;
    let t0 = null;
    const pas = ts => {
      if (t0 === null) t0 = ts;
      const k = Math.min(1, (ts - t0) / 600), e = 1 - Math.pow(1 - k, 3);
      CARTE.etoiles.textContent = "★ " + Math.round(avant + (apres - avant) * e);
      if (k < 1) requestAnimationFrame(pas);
    };
    requestAnimationFrame(pas);
  }

  // ------------------------------------------------------------------
  // LE RÉSULTAT SE POSE SUR LA LIGNE, sous la gare qu'on vient de tenir.
  // ------------------------------------------------------------------
  // Il a été une fiche centrée, puis une bande au bas de l'écran avec un
  // barème, des tuiles, une série, des médailles. Tout était vrai, et le
  // joueur ne voyait plus ce qu'il venait de faire. Il reste ce que les
  // étoiles ne disent pas : le retard, et le record. La carte fait le reste —
  // la gare suivante est à un doigt, la gare jouée aussi pour recommencer.
  if (!STATION.adhoc && typeof renderCarte === "function") {
    CARTE.bilan = { gare: STATION.id, stars, prevStars, d, prevBest, perfect, failed, win, seuils };
    // LE RUBAN AVANCE, ET LA CAMÉRA SUIT. Seulement si le service est tenu :
    // sur un échec il n'y a pas de gare suivante, et voir la carte glisser
    // vers elle contredirait le relevé. `preparerSuite` (js/parcours.js) décide
    // au passage s'il y a une fin de chapitre à fêter — et il PRÉPARE sans
    // rendre, pour que showHub ne dessine qu'une fois : deux rendus faisaient
    // clignoter le chapitre suivant avant la fête du précédent.
    if (win && typeof preparerSuite === "function") preparerSuite(STATION.id);
    showHub();                   // #end rangé, la carte redessinée avec le relevé
    rollRecette();
    if (perfect && typeof perfectConfetti === "function") {
      const bulle = document.querySelector("#hub .c-bilan");
      if (bulle) perfectConfetti(bulle, document.getElementById("confetti-carte"));
    }
    return;
  }

  // ---- Démo « limites » : la fiche centrée, sans carte dessous -------------
  const card = document.querySelector("#end .card");
  card.classList.toggle("win", win);
  card.classList.toggle("fail", !win);
  card.classList.toggle("perfect", perfect);
  document.getElementById("end-title").textContent =
    failed ? "Service interrompu" : perfect ? "Sans faute !" : (win ? "Fin du service" : "Objectif manqué");
  const gareEl = document.getElementById("end-gare");
  if (gareEl) gareEl.textContent = STATION.name || "Démo";
  document.getElementById("stars").innerHTML = etoilesHTML(stars, 3); // rien n'est « neuf » : la démo n'enregistre rien
  const dl = document.getElementById("end-delay");
  dl.classList.remove("hidden");
  dl.textContent = failed ? "Retard de +" + d + " min — limite dépassée."
    : d === 0 ? "Service parfait — aucun retard." : "Retard cumulé : " + d + " min";
  const btnNext = document.getElementById("btn-next");
  btnNext.classList.remove("hidden");
  btnNext.classList.remove("primary");
  btnNext.textContent = "Voir la carte";
  btnNext.onclick = () => showHub();
  const btnReplay = document.getElementById("btn-replay");
  btnReplay.classList.remove("hidden");
  btnReplay.classList.add("primary");
  btnReplay.innerHTML = (typeof icon === "function" ? icon(ICON.restart, 18) : "") + "Rejouer";
  document.getElementById("end").classList.remove("hidden");
  fitEndCard();
  if (perfect && typeof perfectConfetti === "function") perfectConfetti();
}
