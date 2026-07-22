"use strict";
// ------------------------------------------------------------------
// Navigation : carte du monde <-> gares
// ------------------------------------------------------------------
// La sélection des gares se fait sur une carte du monde zoomable (js/map.js) :
// monde → continent → pays → clic sur une ville lance la partie. renderHub()
// reste le point d'entrée historique (appelé par showHub) mais délègue
// désormais entièrement au renderer de la carte.
function renderHub() { renderMap(); }
function showHub() {
  started = false;
  document.getElementById("help").classList.add("hidden");
  document.getElementById("end").classList.add("hidden");
  // Afficher #hub AVANT de rendre la carte : l'overlay se positionne d'après la
  // taille rendue du SVG (screenPos). Si #hub est encore display:none, sa largeur
  // vaut 0 et toutes les villes se tassent dans le coin haut-gauche.
  document.getElementById("hub").classList.remove("hidden");
  renderHub();
}
// Cliquer une gare prend le service SANS écran intercalé : le clic autorise
// l'audio, la partie démarre aussitôt, et la description de la gare passe en
// toast non bloquant. L'aide (règles) reste à la demande via l'icône « ? ».
function startStation(i) {
  currentIdx = i;
  const cfg = CATALOG[i];
  // Cartouche haut-gauche : drapeau (1er token du champ country « 🇧🇪 Belgique »)
  // + nom de la gare.
  const flag = (cfg.country || "").trim().split(" ")[0];
  document.getElementById("station-tag").innerHTML =
    '<span class="flag">' + flag + '</span><span class="nm">' + cfg.name + "</span>";
  // Gare terminus (tous les quais en impasse) : le côté droit est vide (butoirs),
  // on y place le cadre HUD, centré verticalement, pour dégager le haut du plan.
  const terminus = (cfg.platforms || []).length > 0 && cfg.platforms.every(p => p.deadEnd);
  document.getElementById("hud-top").classList.toggle("terminus", terminus);
  loadStation(cfg);
  document.getElementById("hub").classList.add("hidden");
  document.getElementById("end").classList.add("hidden");
  document.getElementById("help").classList.add("hidden");
  ensureAudio(); // geste utilisateur : autorise le son
  resetGame();
  started = true;
  // orientation : tagline court dans la bande d'info réservée (une ligne).
  // La description longue (cfg.desc) reste disponible pour un usage ultérieur.
  toast(cfg.tagline || cfg.name, 6000);
}
