"use strict";
// ------------------------------------------------------------------
// Orientation : le plan de voies se joue en paysage. Sur un mobile tenu en
// portrait, l'overlay #rotate (CSS) recouvre l'écran ET la simulation est
// gelée ici — sinon l'heure de jeu filerait derrière l'invite de rotation.
// ------------------------------------------------------------------
const portraitMQ = window.matchMedia(
  "(orientation: portrait) and (pointer: coarse) and (max-width: 820px)");
let orientationBlocked = portraitMQ.matches;
const onOrientationChange = e => { orientationBlocked = e.matches; };
// addEventListener sur MediaQueryList ; addListener en repli (vieux Safari)
if (portraitMQ.addEventListener) portraitMQ.addEventListener("change", onOrientationChange);
else if (portraitMQ.addListener) portraitMQ.addListener(onOrientationChange);

// ------------------------------------------------------------------
// Horloge
// ------------------------------------------------------------------
let lastTs = null;
function frame(ts) {
  if (lastTs === null) lastTs = ts;
  const dtReal = Math.min(0.1, (ts - lastTs) / 1000);
  lastTs = ts;
  if (started && !paused && !ended && !orientationBlocked) {
    const dtMin = dtReal * speed / SEC_PER_GAMEMIN;
    gameMin += dtMin;
    tick(dtMin);
    document.getElementById("clock").textContent = fmt(gameMin);
  } else if (started && ended && !paused && !orientationBlocked &&
             typeof anyTrainMoving === "function" && anyTrainMoving()) {
    // Service terminé, score figé : on laisse les derniers convois TERMINER leur
    // sortie en arrière-plan (derrière la modale), sans avancer l'horloge ni le
    // score — le mouvement de sortie ne dépend que de dtMin, pas de gameMin.
    tick(dtReal * speed / SEC_PER_GAMEMIN);
  }
  // Repère de tutoriel : recalé chaque frame (même en pause) pour épouser sa cible.
  if (typeof positionCoach === "function") positionCoach();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// ------------------------------------------------------------------
// Contrôles
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// Icônes (Material Symbols, tracés inline en SVG — nets, sans réseau)
// ------------------------------------------------------------------
const ICON = {
  pause:     "M6 19h4V5H6v14zm8-14v14h4V5h-4z",
  play:      "M8 5v14l11-7z",
  restart:   "M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z",
  volumeOn:  "M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z",
  volumeOff: "M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z",
  close:     "M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z",
  help:      "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 17h-2v-2h2v2zm2.07-7.75l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z",
  // Coche : « c'est à vous » sur une gare déjà achetée (fiche de gare).
  check:     "M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z",
  lock:      "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1s3.1 1.39 3.1 3.1v2z",
  settings:  "M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z",
  logout:    "M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"
};
function icon(d, size) {
  return '<svg viewBox="0 0 24 24" width="' + (size || 22) + '" height="' + (size || 22) +
         '" fill="currentColor" aria-hidden="true"><path d="' + d + '"/></svg>';
}

// ------------------------------------------------------------------
// Volet de commandes : taper l'horloge le déplie/replie. Pause, vitesses,
// recommencer et son sont des boutons explicites.
// ------------------------------------------------------------------
const hudClock = document.getElementById("hud-clock");
const hudControls = document.getElementById("hud-controls");
const btnPlayback = document.getElementById("btn-playback");
const btnSpeed = document.getElementById("btn-speed");
const pauseTag = document.getElementById("pause-tag");
function updatePauseIcon() {
  // Bouton lecture = bascule DIRECTE : son icône est l'action à faire au tap
  // (▶ pour reprendre quand en pause, ⏸ pour mettre en pause quand ça tourne).
  btnPlayback.innerHTML = icon(paused ? ICON.play : ICON.pause, 20);
  btnPlayback.title = paused ? "Reprendre" : "Pause";
  hudClock.classList.toggle("paused", paused);
  pauseTag.classList.toggle("hidden", !paused);
  // Bouton vitesse : libellé = vitesse courante, accentué au-delà de 1x.
  btnSpeed.textContent = speed + "x";
  btnSpeed.classList.toggle("active", speed > 1);
}
function updateMuteIcon() {
  document.getElementById("btn-mute").innerHTML = icon(muted ? ICON.volumeOff : ICON.volumeOn, 22);
}
// icônes fixes
document.getElementById("btn-reset").innerHTML = icon(ICON.restart, 26); // restart plus grand
document.getElementById("btn-help").innerHTML = icon(ICON.help, 22);     // aide dans le volet de réglages
document.getElementById("btn-settings").innerHTML = icon(ICON.settings, 20); // engrenage : ouvre le volet
// (l'aide de la carte est un simple « ? » gris, défini en HTML/CSS)
document.getElementById("btn-replay").innerHTML = icon(ICON.restart, 18) + "Rejouer"; // fin de service : flèche « refresh » + texte
updatePauseIcon();
updateMuteIcon();

// Le menu d'icônes se déplie/replie sous l'engrenage (haut à droite).
// #settings.open pilote l'état visuel du bouton (teal + rotation).
const settingsWrap = document.getElementById("settings");
const btnSettings = document.getElementById("btn-settings");
function setMenu(open) {
  hudControls.classList.toggle("hidden", !open);
  settingsWrap.classList.toggle("open", open);
  btnSettings.setAttribute("aria-expanded", open ? "true" : "false");
}
function toggleMenu() { setMenu(hudControls.classList.contains("hidden")); }
btnSettings.addEventListener("click", toggleMenu);
// Lecture : bascule pause/reprise au tap. Vitesse : cycle 1x → 2x → 4x → 1x
// (change le rythme sans toucher à l'état pause).
btnPlayback.addEventListener("click", () => { paused = !paused; updatePauseIcon(); });
btnSpeed.addEventListener("click", () => { speed = speed >= 4 ? 1 : speed * 2; updatePauseIcon(); });
// on referme dès qu'on clique un bouton du menu. En phase de CAPTURE : certains
// boutons (pause, sons) remplacent leur propre icône dans leur handler, ce qui
// détache e.target ; en capture on lit e.target avant cette mutation. L'action
// du bouton (phase de bulle) s'exécute ensuite, le chemin d'événement étant figé.
// On ne referme QUE sur une action (recommencer/son/aide/quitter) : régler le
// rythme dans le segment lecture laisse le menu ouvert (contrôle de jeu, pas
// un réglage ponctuel).
hudControls.addEventListener("click", e => {
  if (e.target.closest(".act-row .btn")) setMenu(false);
}, true);
// clic hors du menu réglages → le referme.
document.addEventListener("click", e => {
  if (!hudControls.classList.contains("hidden") && !settingsWrap.contains(e.target)) setMenu(false);
});
// Le badge « En pause » sert aussi de bouton reprise : un tap relance le jeu.
pauseTag.addEventListener("click", () => { paused = false; updatePauseIcon(); });
// Aide (règles du jeu) à la demande : depuis la carte et depuis le volet de
// réglages. Ouverte en cours de partie, elle met en pause — on lit sans que
// le temps de jeu file derrière l'overlay.
const helpOverlay = document.getElementById("help");
function openHelp() {
  hudControls.classList.add("hidden"); // referme le volet de réglages
  helpOverlay.classList.remove("hidden");
  if (started && !ended) { paused = true; updatePauseIcon(); }
}
function closeHelp() { helpOverlay.classList.add("hidden"); }
// ------------------------------------------------------------------
// Écran de bienvenue (accueil première fois) : distinct de l'aide de rappel.
// Ouvert par maybeStartOnboarding() ; sa fermeture relance le service guidé.
// ------------------------------------------------------------------
const welcomeOverlay = document.getElementById("welcome");
function openWelcome() {
  hudControls.classList.add("hidden");
  welcomeOverlay.classList.remove("hidden");
  if (started && !ended) { paused = true; updatePauseIcon(); }
}
function closeWelcome() {
  welcomeOverlay.classList.add("hidden");
  // relance le service : un train s'annonce, puis le jeu se regèle à son arrivée
  if (typeof onboardingWelcomeClosed === "function") onboardingWelcomeClosed();
}
document.getElementById("btn-welcome-start").addEventListener("click", closeWelcome);
welcomeOverlay.addEventListener("click", e => { if (e.target === welcomeOverlay) closeWelcome(); });
// Bouton du repère de tutoriel (« Suivant » / « Continuer ») : avance/termine.
document.getElementById("coach-next").addEventListener("click", () => {
  if (typeof coachNext === "function") coachNext();
});
document.getElementById("btn-help").addEventListener("click", openHelp);
document.getElementById("btn-help-close").addEventListener("click", closeHelp);
// clic sur le fond (hors carte) : referme l'aide
helpOverlay.addEventListener("click", e => { if (e.target === helpOverlay) closeHelp(); });
document.getElementById("btn-mute").addEventListener("click", () => {
  muted = !muted;
  setMuted(muted);
  updateMuteIcon();
});
async function doReset() {
  document.getElementById("end").classList.add("hidden");
  document.getElementById("hub").classList.add("hidden");
  await resetGame(); started = true; // génération asynchrone : on attend la journée
  maybeStartOnboarding(); // sans effet si déjà initié (garde interne)
}
// Recommencer : le bouton est à un doigt de l'engrenage, et le geste jette le
// service en cours pour en tirer un NOUVEAU (autres trains, autres horaires) —
// il demande donc confirmation, comme quitter. Service déjà terminé ou pas
// encore commencé : rien à perdre, on repart sans rien demander.
const confirmReset = document.getElementById("confirm-reset");
let _wasPausedBeforeReset = false;
function showConfirmReset() {
  _wasPausedBeforeReset = paused;
  confirmReset.classList.remove("hidden");
  // Gèle la partie le temps de décider : pas de retard encaissé « à vide ».
  paused = true; updatePauseIcon();
}
function dismissConfirmReset() {
  confirmReset.classList.add("hidden");
  // « Continuer » : on reprend là où on en était (sauf si déjà en pause avant).
  if (!_wasPausedBeforeReset) { paused = false; updatePauseIcon(); }
}
document.getElementById("btn-reset").addEventListener("click", () => {
  if (started && !ended) showConfirmReset();
  else doReset();
});
document.getElementById("btn-reset-cancel").addEventListener("click", dismissConfirmReset);
document.getElementById("btn-reset-confirm").addEventListener("click", async () => {
  confirmReset.classList.add("hidden");
  await doReset();
});
confirmReset.addEventListener("click", e => { if (e.target === confirmReset) dismissConfirmReset(); });
// « Rejouer » sur l'écran de fin : le service est terminé, il n'y a rien à
// abandonner — pas de confirmation.
document.getElementById("btn-replay").addEventListener("click", doReset);
// Reprendre la journée sans attendre : le raccourci n'apparaît que lorsqu'elle
// est perdue (js/game.js, updateGoal), donc il ne peut pas être pressé par
// mégarde pendant un service qui tient encore.

// Fermer le relevé de fin : la carte est DÉJÀ là, derrière lui. On le range et
// on recentre le pays. Repli sur la bascule d'écran quand il n'y a pas de carte
// dessous (démo « limites », gare hors catalogue).
document.getElementById("btn-end-close").innerHTML = icon(ICON.close, 20);
document.getElementById("btn-end-close").addEventListener("click", showHub);
// Cartouche haut-gauche = bouton retour vers la carte (même logique que « ‹ »
// sur la carte). Une partie EN COURS demande confirmation (abandon = progression
// du service perdue) ; sinon (partie finie) on repart directement.
const confirmQuit = document.getElementById("confirm-quit");
let _wasPausedBeforeConfirm = false;
function showConfirmQuit() {
  _wasPausedBeforeConfirm = paused;
  confirmQuit.classList.remove("hidden");
  // Gèle la partie pendant la décision : aucun retard n'est encaissé « à vide ».
  if (started && !ended) { paused = true; updatePauseIcon(); }
}
function dismissConfirmQuit() {
  confirmQuit.classList.add("hidden");
  // « Rester » : on reprend là où on en était (sauf si déjà en pause avant).
  if (started && !ended && !_wasPausedBeforeConfirm) { paused = false; updatePauseIcon(); }
}
(function () {
  const tag = document.getElementById("station-tag");
  tag.setAttribute("role", "button");
  tag.setAttribute("aria-label", "Revenir à la carte");
  tag.addEventListener("click", () => {
    if (started && !ended) showConfirmQuit();
    else showHub();
  });
})();
document.getElementById("btn-quit-cancel").addEventListener("click", dismissConfirmQuit);
document.getElementById("btn-quit-confirm").addEventListener("click", () => {
  confirmQuit.classList.add("hidden"); showHub();
});
confirmQuit.addEventListener("click", e => { if (e.target === confirmQuit) dismissConfirmQuit(); });
// ------------------------------------------------------------------
// Démo « limites » : gare construite à la volée pour éprouver les plafonds
// (quais, destinations, trains, frets). Se lance par l'URL —
//   station.html?limits              → 10 quais · 10 dest · 30 trains · 2 frets
//   station.html?limits=10,5,30,2    → quais, destinations/côté, trains, frets
//   station.html?limits=13,6,40,3    → mode « extrême » : chargé, ~11 s de génération
// Le défaut est le point d'équilibre mesuré : le plus tendu qui reste lisible,
// rapide à générer (~2 s) et toujours solvable à zéro. Au-delà de ~34 trains la
// génération explose ET le zéro n'est plus garanti (pas assez de quais).
// Hors carte du monde (aucune entrée géo requise). La génération passe par le
// Web Worker, donc même une grosse gare ne fige pas l'écran au lancement.
// ------------------------------------------------------------------
function buildLimitsStation(params) {
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v | 0));
  const Q = clamp(params[0] || 10, 2, 13);   // quais : 13 = mur géométrique
  const P = clamp(params[1] || 5, 1, 8);     // destinations PAR CÔTÉ
  const nTrains = clamp(params[2] || 30, 2, 80);
  const nFreight = clamp(params[3] ?? 2, 0, 12);
  // palette distincte (au-delà, les couleurs se répètent — limite de lisibilité)
  const COLORS = ["#f2588f","#4ade80","#a78bfa","#f5b23c","#25dede","#60a5fa",
                  "#fb923c","#34d399","#c084fc","#f87171","#2dd4bf","#facc15",
                  "#818cf8","#f472b6","#22d3ee","#a3e635"];
  const platforms = Array.from({ length: Q }, (_, i) => ({ id: i + 1 }));
  const portals = {}, links = {};
  // Liaisons en fenêtre glissante : chaque portail dessert une bande d'environ
  // 60 % des quais, la bande se décale selon l'indice du portail. Résultat :
  // faisceau très dense (chaque quai reste desservi des deux côtés, donc du
  // fret et des rebroussements possibles) SANS le coût du maillage complet —
  // l'assignation gloutonne du générateur teste ~win options/train, pas Q.
  const win = Math.min(Q, Math.max(6, Math.ceil(Q * 0.6)));
  let ci = 0;
  for (const side of ["L", "R"]) for (let i = 0; i < P; i++) {
    const name = side + "_" + i;
    portals[name] = { side, color: COLORS[ci % COLORS.length],
      abbr: (side === "L" ? "O" : "E") + (i + 1),
      label: (side === "L" ? "OUEST " : "EST ") + (i + 1) };
    const start = P > 1 ? Math.round(i / (P - 1) * (Q - win)) : 0;
    links[name] = platforms.slice(start, start + win).map(p => p.id);
    ci++;
  }
  return {
    id: "limits-demo", adhoc: true,
    name: "LIMITES · " + Q + "q " + (2 * P) + "d " + nTrains + "t " + nFreight + "f",
    tagline: "Démo limites — " + Q + " quais, " + (2 * P) + " destinations, " +
             nTrains + " trains, " + nFreight + " frets. maillage complet.",
    maxDelay: 100000, // pas de game over : on veut observer la saturation
    platforms, portals, links, sameSidePairs: "all",
    gen: { nMin: nTrains, nMax: nTrains, gapMin: 1.8, gapMax: 3.0,
           cars: [3, 4, 5, 5, 6, 7], freightCount: nFreight, quietRate: 0.6 }
  };
}
// ------------------------------------------------------------------
// Aperçu du RELEVÉ DE FIN, sans jouer la journée. Se lance par l'URL —
//   station.html?fin=tournai           → Tournai, service parfait (0 min)
//   station.html?fin=tournai,6         → 6 min de retard (trois étoiles)
//   station.html?fin=tournai,24        → 24 min (une étoile)
//   station.html?fin=tournai,41,echec  → plafond crevé : service interrompu
// Il fallait tenir une gare entière — dix minutes — pour voir l'écran qu'on
// est en train de dessiner. Ici la gare se charge, la journée se déclare finie
// avec le retard demandé, réparti sur quelques convois pour que la tuile
// « trains à l'heure » ait quelque chose à compter, et le relevé s'ouvre.
// RIEN N'EST ÉCRIT : le magasin est mis en lecture seule (APERCU_SANS_TRACE),
// la gare « achetée » et le record « enregistré » s'évaporent au rechargement.
// ------------------------------------------------------------------
function finParamsFromURL() {
  const raw = new URLSearchParams(location.search).get("fin");
  if (raw === null) return null;
  const parts = raw.split(",");
  return { gare: parts[0] || "", retard: Math.max(0, parseInt(parts[1], 10) || 0),
           echec: parts[2] === "echec" };
}
async function apercuFin(p) {
  let i = CATALOG.findIndex(c => c.id === p.gare);
  if (i < 0) i = 0;
  const id = CATALOG[i].id;
  APERCU_SANS_TRACE = true;
  if (!isBought(id)) buyStation(id, 0);      // en mémoire seulement
  _onboarded = true;                        // pas d'accueil, et sans l'écrire (js/store.js)
  await startStation(i);
  onboarding = null; hideCoach(); freezeGame(false);
  const w = document.getElementById("welcome"); if (w) w.classList.add("hidden");
  paused = true;
  // Tous les convois sont passés ; le retard se répartit sur les derniers
  // partis, une ou deux minutes chacun, le reste sur le dernier.
  let reste = p.retard;
  for (let k = trains.length - 1; k >= 0; k--) {
    const t = trains[k];
    t.state = "done";
    if (t.freight) continue;
    const part = reste <= 0 ? 0 : (k === 0 ? reste : Math.min(reste, 1 + (k % 2)));
    t.depDelay = part; reste -= part;
  }
  totalDelay = p.retard;
  gameMin += 60 * 5;
  endGame(p.echec);
}
function limitsParamsFromURL() {
  const raw = new URLSearchParams(location.search).get("limits");
  if (raw === null) return null;               // pas de démo demandée
  return raw.split(",").map(s => parseInt(s, 10)); // [] si "?limits" seul
}

// ------------------------------------------------------------------
// Démarrage : chargement du catalogue (data/stations/) puis carte-parcours
// ------------------------------------------------------------------
started = false;
// Chargement store (progression + préférences) ET catalogue avant la carte :
// la carte lit la progression, l'icône son lit la préférence hydratée.
// Puis la CARTE COURANTE : elle se lit dans la sauvegarde, donc après le
// magasin. Son index se charge en même temps que le reste.
Promise.all([loadStore(), loadCatalog(), loadCartes()])
  .then(() => loadCarte(getCarteCourante()))
  .then(() => {
    // Le magasin et le catalogue sont là : la ponctualité d'une sauvegarde
    // ancienne peut enfin se reconstituer depuis les records (js/catalog.js).
    muted = getMuted(); updateMuteIcon();
    const lp = limitsParamsFromURL();
    const fp = finParamsFromURL();
    if (lp) startAdhocStation(buildLimitsStation(lp)); // démo limites directe
    else if (fp) apercuFin(fp);                      // aperçu du relevé de fin
    else showHub();
  })
  .catch(err => {
    console.error(err);
    document.getElementById("hub-map").innerHTML =
      '<p style="color:var(--muted);font-size:15px;line-height:1.8;">' +
      "Impossible de charger les fiches de gares (" + err.message + ").<br>" +
      "Ouvert en <b>file://</b>, le navigateur bloque la lecture des fichiers JSON :<br>" +
      "lancez un petit serveur local depuis le dossier du jeu, par exemple<br>" +
      "<code>python3 -m http.server</code> puis ouvrez " +
      '<code>http://localhost:8000/station.html</code></p>';
  });
