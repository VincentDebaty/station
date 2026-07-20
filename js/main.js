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
  }
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
  lock:      "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1s3.1 1.39 3.1 3.1v2z"
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
const btnPausep = document.getElementById("btn-pausep");
const pauseTag = document.getElementById("pause-tag");
function updatePauseIcon() {
  btnPausep.innerHTML = icon(paused ? ICON.play : ICON.pause, 24);
  hudClock.classList.toggle("paused", paused);
  btnPausep.title = paused ? "Reprendre" : "Pause";
  pauseTag.classList.toggle("hidden", !paused);
}
function updateMuteIcon() {
  document.getElementById("btn-mute").innerHTML = icon(muted ? ICON.volumeOff : ICON.volumeOn, 22);
}
// icônes fixes
document.getElementById("btn-reset").innerHTML = icon(ICON.restart, 26); // restart plus grand
document.getElementById("btn-hub").innerHTML = icon(ICON.close, 24);     // croix : quitter vers la carte
document.getElementById("btn-help").innerHTML = icon(ICON.help, 22);     // aide dans le volet de réglages
// (l'aide de la carte est un simple « ? » gris, défini en HTML/CSS)
document.getElementById("btn-replay").innerHTML = icon(ICON.restart, 18) + "Rejouer"; // fin de service : flèche « refresh » + texte
updatePauseIcon();
updateMuteIcon();

hudClock.addEventListener("click", () => hudControls.classList.toggle("hidden"));
// on referme le volet dès qu'on clique sur le voile (hors carte) OU sur
// n'importe quel bouton. En phase de CAPTURE : certains boutons (pause, sons)
// remplacent leur propre icône dans leur handler, ce qui détache e.target ;
// en capture on lit e.target avant cette mutation. L'action du bouton
// (phase de bulle) s'exécute ensuite normalement, le chemin d'événement étant figé.
hudControls.addEventListener("click", e => {
  if (e.target === hudControls || e.target.closest(".btn"))
    hudControls.classList.add("hidden");
}, true);
btnPausep.addEventListener("click", () => { paused = !paused; updatePauseIcon(); });
document.querySelectorAll(".speed").forEach(b => b.addEventListener("click", () => {
  speed = +b.dataset.s;
  paused = false; updatePauseIcon(); // choisir une vitesse relance le jeu
  document.querySelectorAll(".speed").forEach(x => x.classList.toggle("active", x === b));
}));
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
document.getElementById("btn-help").addEventListener("click", openHelp);
document.getElementById("btn-help-map").addEventListener("click", openHelp);
document.getElementById("btn-help-close").addEventListener("click", closeHelp);
// clic sur le fond (hors carte) : referme l'aide
helpOverlay.addEventListener("click", e => { if (e.target === helpOverlay) closeHelp(); });
document.getElementById("btn-mute").addEventListener("click", () => {
  muted = !muted;
  setMuted(muted);
  updateMuteIcon();
});
document.getElementById("btn-reset").addEventListener("click", () => {
  resetGame(); started = true;
  document.getElementById("end").classList.add("hidden");
});
document.getElementById("btn-replay").addEventListener("click", () => {
  resetGame(); started = true;
  document.getElementById("end").classList.add("hidden");
});
document.getElementById("btn-hub").addEventListener("click", () => showHub());
document.getElementById("btn-end-map").addEventListener("click", () => showHub());
document.getElementById("btn-next").addEventListener("click", () => startStation(currentIdx + 1));

// ------------------------------------------------------------------
// Démarrage : chargement du catalogue (data/stations/) puis carte-parcours
// ------------------------------------------------------------------
started = false;
// Chargement store (progression + préférences) ET catalogue avant la carte :
// la carte lit la progression, l'icône son lit la préférence hydratée.
Promise.all([loadStore(), loadCatalog()])
  .then(() => { muted = getMuted(); updateMuteIcon(); showHub(); })
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
