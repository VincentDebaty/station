"use strict";
// ------------------------------------------------------------------
// Navigation : carte du monde <-> gares
// ------------------------------------------------------------------
// La sélection des gares se fait sur une carte du monde zoomable (js/map.js) :
// monde → continent → pays → clic sur une ville lance la partie. renderHub()
// reste le point d'entrée historique (appelé par showHub) mais délègue
// désormais entièrement au renderer de la carte.
// La carte en lignes (js/carte.js) a remplacé la carte géographique. Le
// point d'entrée historique ne change pas : tout le jeu appelle showHub().
function renderHub() { renderCarte(); }
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
// Pastilles de difficulté (mêmes symboles que la fiche de la carte) : le joueur
// garde en jeu le repère qu'il avait avant de prendre le service.
// Difficulté du cartouche : la MÊME jauge à cinq crans que la fiche de gare
// (js/map.js) — une seule façon de montrer un niveau dans tout le jeu.
function diffPips(d) {
  const n = Math.max(1, Math.min(5, d || 1));
  return '<span class="dif">' + Array.from({ length: 5 }, (_, i) =>
    '<span class="b' + (i < n ? " on" : "") + '"></span>').join("") + "</span>";
}
// LA DERNIÈRE GARE RÉELLEMENT PRISE EN MAIN — et non `currentIdx`, qui vaut 0
// au chargement et désigne donc une gare que le joueur n'a jamais jouée. La
// carte s'en sert comme ANCRE pour ordonner ses propositions ; avec un index
// par défaut, la première gare du catalogue s'excluait de sa propre proposition
// (« Landen attend son service » ne s'affichait pas, parce que Landen était
// réputée être l'endroit d'où l'on regarde).
let lastPlayedId = null;

async function startStation(i) {
  currentIdx = i;
  lastPlayedId = (CATALOG[i] || {}).id || null;
  // Un service commence : le relevé précédent et le bouton qu'il désignait
  // appartiennent au passé (js/game.js, endFocusId).
  if (typeof endFocusId !== "undefined") endFocusId = null;
  const cfg = CATALOG[i];
  // Cartouche haut-gauche : drapeau (1er token du champ country « 🇧🇪 Belgique »)
  // + nom de la gare.
  const flag = (cfg.country || "").trim().split(" ")[0];
  // Cartouche = bouton RETOUR (même logique que « ‹ France » sur la carte) :
  // flèche + drapeau + nom + difficulté, cliquable pour revenir à la carte.
  document.getElementById("station-tag").innerHTML =
    '<span class="arw">‹</span><span class="flag">' + flag + '</span><span class="nm">' + cfg.name + "</span>" +
    diffPips(cfg.difficulty);
  loadStation(cfg);
  document.getElementById("hub").classList.add("hidden");
  document.getElementById("end").classList.add("hidden");
  document.getElementById("help").classList.add("hidden");
  ensureAudio(); // geste utilisateur : autorise le son
  await resetGame(); // génération asynchrone (worker) : on attend la journée
  started = true;
  maybeStartOnboarding(); // premier service : accueil (aide + départ en pause)
  // orientation : tagline court dans la bande d'info réservée (une ligne).
  // La description longue (cfg.desc) reste disponible pour un usage ultérieur.
  toast(cfg.tagline || cfg.name, 6000);
}

// Démo « limites » : lance une gare construite à la volée (hors carte du monde,
// donc aucune entrée géo à créer). currentIdx = -1 neutralise la logique de
// déverrouillage / gare suivante ; le flag cfg.adhoc évite d'écrire un record.
async function startAdhocStation(cfg) {
  currentIdx = -1;
  document.getElementById("station-tag").innerHTML =
    '<span class="arw">‹</span><span class="flag">🧪</span><span class="nm">' + cfg.name + "</span>" +
    diffPips(cfg.difficulty);
  loadStation(cfg);
  document.getElementById("hub").classList.add("hidden");
  document.getElementById("end").classList.add("hidden");
  document.getElementById("help").classList.add("hidden");
  ensureAudio();
  await resetGame();
  started = true;
  toast(cfg.tagline || cfg.name, 6000);
}
