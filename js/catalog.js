"use strict";
// ------------------------------------------------------------------
// Catalogue des gares — un fichier JSON par gare, classé par pays dans
// data/stations/. L'ordre de data/stations/index.json fait foi : c'est
// lui qui définit la progression (une étoile débloque la gare suivante).
// Chaque fiche décrit entièrement une gare : quais (impasses comprises),
// portails (côté, sens, couleur), liaisons, paires même-côté autorisées
// (rebroussements) et paramètres du générateur. Le moteur s'adapte,
// le calibrage garantit le zéro.
// ------------------------------------------------------------------
const CATALOG = [];

async function loadCatalog() {
  const base = "data/stations/";
  const index = await fetch(base + "index.json").then(r => {
    if (!r.ok) throw new Error("index.json : " + r.status);
    return r.json();
  });
  const files = [];
  for (const group of index)
    for (const id of group.stations)
      files.push(base + group.country + "/" + id + ".json");
  const cards = await Promise.all(files.map(f => fetch(f).then(r => {
    if (!r.ok) throw new Error(f + " : " + r.status);
    return r.json();
  })));
  CATALOG.length = 0;
  CATALOG.push(...cards);
}

// Progression : étoiles par gare ; la gare N+1 se débloque à ≥ 1 étoile
function getProgress() {
  try { return JSON.parse(localStorage.getItem("station-progress")) || {}; }
  catch (e) { return {}; }
}
function saveResult(id, stars, delay) {
  const p = getProgress();
  const cur = p[id] || { stars: 0, bestDelay: null };
  p[id] = {
    stars: Math.max(cur.stars, stars),
    bestDelay: cur.bestDelay == null ? delay : Math.min(cur.bestDelay, delay)
  };
  localStorage.setItem("station-progress", JSON.stringify(p));
}
function isUnlocked(i) {
  return i === 0 || ((getProgress()[CATALOG[i - 1].id] || {}).stars || 0) >= 1;
}
