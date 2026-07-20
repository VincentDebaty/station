"use strict";
// ------------------------------------------------------------------
// Navigation : carte-parcours <-> gares
// ------------------------------------------------------------------
// La carte-parcours : un bloc par pays, parcouru de gauche à droite.
// La première gare disponible ouvre la ligne à gauche ; la progression
// avance vers la droite (une étoile débloque la gare suivante).
function renderHub() {
  const map = document.getElementById("hub-map");
  map.innerHTML = "";
  const regions = [];
  for (const cfg of CATALOG) {
    const last = regions[regions.length - 1];
    if (!last || last.name !== cfg.country) regions.push({ name: cfg.country, items: [] });
    regions[regions.length - 1].items.push(cfg);
  }
  const prog = getProgress();
  for (const region of regions) {
    const block = document.createElement("div");
    block.className = "hub-block";
    map.appendChild(block);
    // Libellé ancré en haut à gauche du bloc, juste au-dessus de ses gares.
    const banner = document.createElement("div");
    banner.className = "hub-region";
    banner.textContent = region.name;
    block.appendChild(banner);
    const n = region.items.length;
    // Positions : réparties horizontalement, ondulation douce et déterministe.
    // Ondulation centrée (50 %) pour laisser de la place aux légendes posées
    // en alternance au-dessus/en dessous des pastilles (voir cap-up plus bas).
    const pos = region.items.map((_, i) => ({
      x: n === 1 ? 50 : 6 + 88 * i / (n - 1),
      y: 50 + 9 * Math.sin(i * 0.9 + 0.4)
    }));
    // Combien de gares de cette région sont déjà ouvertes (préfixe contigu),
    // et laquelle est « courante » : première ouverte pas encore parfaite
    // (3 étoiles) — le point de reprise, propre à CE pays.
    let lastOpen = -1, regionCurrent = -1;
    region.items.forEach((cfg, i) => {
      if (!isUnlocked(CATALOG.indexOf(cfg))) return;
      lastOpen = i;
      if (regionCurrent === -1 && ((prog[cfg.id] || {}).stars || 0) < 3) regionCurrent = i;
    });
    const svg = document.createElementNS(SVGNS, "svg");
    svg.setAttribute("viewBox", "0 0 100 100");
    svg.setAttribute("preserveAspectRatio", "none");
    const d = pos.map((p, i) => (i ? "L " : "M ") + p.x + " " + p.y).join(" ");
    // Voie de fond (grisée) sur tout le trajet.
    const base = document.createElementNS(SVGNS, "path");
    base.setAttribute("class", "hub-path");
    base.setAttribute("d", d);
    svg.appendChild(base);
    // Voie « parcourue » (accent) jusqu'à la dernière gare ouverte.
    if (lastOpen >= 1) {
      const done = document.createElementNS(SVGNS, "path");
      done.setAttribute("class", "hub-path done");
      done.setAttribute("d", pos.slice(0, lastOpen + 1)
        .map((p, i) => (i ? "L " : "M ") + p.x + " " + p.y).join(" "));
      svg.appendChild(done);
    }
    block.appendChild(svg);
    region.items.forEach((cfg, i) => {
      const gi = CATALOG.indexOf(cfg);
      const unlocked = isUnlocked(gi);
      const p = prog[cfg.id] || {};
      const node = document.createElement("div");
      // Légende alternée : une gare sur deux porte son cartouche au-dessus,
      // pour que les gares serrées (jusqu'à 10 par pays) ne se chevauchent pas.
      node.className = "hub-node" + (unlocked ? "" : " locked") +
        (i === regionCurrent ? " current" : "") + (i % 2 ? " cap-up" : "");
      node.style.left = pos[i].x + "%";
      node.style.top = pos[i].y + "%";
      node.innerHTML =
        '<div class="disc">' + (unlocked ? cfg.name[0] : icon(ICON.lock, 14)) + "</div>" +
        '<div class="cap">' +
          '<div class="nm">' + cfg.name + "</div>" +
          '<div class="st">' + "★".repeat(p.stars || 0) + "☆".repeat(3 - (p.stars || 0)) + "</div>" +
          (p.bestDelay != null ? '<div class="bd">record : +' + p.bestDelay + " min</div>" : "") +
        "</div>";
      if (unlocked) node.addEventListener("click", () => startStation(gi));
      block.appendChild(node);
    });
  }
}
function showHub() {
  started = false;
  document.getElementById("help").classList.add("hidden");
  document.getElementById("end").classList.add("hidden");
  renderHub();
  document.getElementById("hub").classList.remove("hidden");
}
// Cliquer une gare prend le service SANS écran intercalé : le clic autorise
// l'audio, la partie démarre aussitôt, et la description de la gare passe en
// toast non bloquant. L'aide (règles) reste à la demande via l'icône « ? ».
function startStation(i) {
  currentIdx = i;
  const cfg = CATALOG[i];
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
