"use strict";
// ------------------------------------------------------------------
// Navigation : carte-parcours <-> gares
// ------------------------------------------------------------------
// La carte-parcours : un bloc par pays, chaque bloc avec son chemin sinueux.
// La progression traverse les régions dans l'ordre du catalogue.
const HUB_XS = [22, 58, 30, 64, 34, 60];
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
    const banner = document.createElement("div");
    banner.className = "hub-region";
    banner.textContent = region.name;
    map.appendChild(banner);
    const block = document.createElement("div");
    block.className = "hub-block";
    block.style.height = (region.items.length * 106 + 30) + "px";
    map.appendChild(block);
    const n = region.items.length;
    const pos = region.items.map((_, i) => ({
      x: HUB_XS[i % HUB_XS.length],
      y: n === 1 ? 50 : 90 - 82 * i / (n - 1)
    }));
    const svg = document.createElementNS(SVGNS, "svg");
    svg.setAttribute("viewBox", "0 0 100 100");
    svg.setAttribute("preserveAspectRatio", "none");
    const path = document.createElementNS(SVGNS, "path");
    path.setAttribute("d", pos.map((p, i) => (i ? "L " : "M ") + p.x + " " + p.y).join(" "));
    path.setAttribute("fill", "none");
    path.setAttribute("stroke", "#323d4f");
    path.setAttribute("stroke-width", "1.1");
    path.setAttribute("stroke-dasharray", "2.6 2");
    svg.appendChild(path);
    block.appendChild(svg);
    region.items.forEach((cfg, i) => {
      const gi = CATALOG.indexOf(cfg);
      const unlocked = isUnlocked(gi);
      const p = prog[cfg.id] || {};
      const node = document.createElement("div");
      node.className = "hub-node" + (unlocked ? "" : " locked");
      node.style.left = pos[i].x + "%";
      node.style.top = pos[i].y + "%";
      node.innerHTML =
        '<div class="disc">' + (unlocked ? cfg.name[0] : "🔒") + "</div>" +
        '<div class="nm">' + cfg.name + "</div>" +
        '<div class="st">' + "★".repeat(p.stars || 0) + "☆".repeat(3 - (p.stars || 0)) + "</div>" +
        (p.bestDelay != null ? '<div class="bd">record : +' + p.bestDelay + " min</div>" : "");
      if (unlocked) node.addEventListener("click", () => startStation(gi));
      block.appendChild(node);
    });
  }
}
function showHub() {
  started = false;
  document.getElementById("intro").classList.add("hidden");
  document.getElementById("end").classList.add("hidden");
  renderHub();
  document.getElementById("hub").classList.remove("hidden");
}
function startStation(i) {
  currentIdx = i;
  const cfg = CATALOG[i];
  loadStation(cfg);
  document.getElementById("station-name").textContent = cfg.name;
  document.getElementById("intro-title").textContent = cfg.name + " — poste d'aiguillage";
  document.getElementById("intro-desc").textContent = cfg.desc;
  document.getElementById("hub").classList.add("hidden");
  document.getElementById("end").classList.add("hidden");
  document.getElementById("intro").classList.remove("hidden");
  started = false;
  resetGame();
}
