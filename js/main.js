"use strict";
// ------------------------------------------------------------------
// Horloge
// ------------------------------------------------------------------
let lastTs = null;
function frame(ts) {
  if (lastTs === null) lastTs = ts;
  const dtReal = Math.min(0.1, (ts - lastTs) / 1000);
  lastTs = ts;
  if (started && !paused && !ended) {
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
document.getElementById("btn-pause").addEventListener("click", () => {
  paused = !paused;
  document.getElementById("btn-pause").textContent = paused ? "▶" : "⏸";
});
document.querySelectorAll(".speed").forEach(b => b.addEventListener("click", () => {
  speed = +b.dataset.s;
  paused = false;
  document.getElementById("btn-pause").textContent = "⏸";
  document.querySelectorAll(".speed").forEach(x => x.classList.toggle("active", x === b));
}));
document.getElementById("btn-start").addEventListener("click", () => {
  ensureAudio(); // le geste utilisateur autorise l'audio
  document.getElementById("intro").classList.add("hidden");
  started = true;
});
document.getElementById("btn-mute").addEventListener("click", () => {
  muted = !muted;
  localStorage.setItem("station-muted", muted ? "1" : "0");
  document.getElementById("btn-mute").textContent = muted ? "🔇" : "🔊";
});
document.getElementById("btn-mute").textContent = muted ? "🔇" : "🔊";
document.getElementById("btn-reset").addEventListener("click", () => {
  resetGame(); started = true;
  document.getElementById("end").classList.add("hidden");
});
document.getElementById("btn-replay").addEventListener("click", () => {
  resetGame(); started = true;
  document.getElementById("end").classList.add("hidden");
});
document.getElementById("btn-map").addEventListener("click", () => showHub());
document.getElementById("btn-end-map").addEventListener("click", () => showHub());
document.getElementById("btn-next").addEventListener("click", () => startStation(currentIdx + 1));

// ------------------------------------------------------------------
// Démarrage : chargement du catalogue (data/stations/) puis carte-parcours
// ------------------------------------------------------------------
started = false;
loadCatalog()
  .then(() => showHub())
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
