"use strict";
// ------------------------------------------------------------------
// Catalogue des gares — un fichier JSON par gare, classé par pays dans
// data/stations/. index.json ne fait que RÉUNIR les gares d'un pays ;
// à l'intérieur d'un pays, l'ordre de jeu est le tri par « difficulty »
// croissante (rampe d'accès facile en tête, boss en fin). Chaque pays est
// une échelle indépendante : tous sont ouverts d'emblée, chacun se gravit
// pour son compte — un joueur commence par SON pays, pas par la Belgique.
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
  // Un pays = un bloc contigu dans CATALOG. On charge chaque bloc puis on le
  // trie par difficulté croissante ; l'ordre du fichier ne sert que de
  // départage à difficulté égale (tri stable via l'index d'origine).
  const blocks = await Promise.all(index.map(group =>
    Promise.all(group.stations.map((id, ord) => {
      const f = base + group.country + "/" + id + ".json";
      return fetch(f).then(r => {
        if (!r.ok) throw new Error(f + " : " + r.status);
        return r.json();
      }).then(card => ({ card, ord }));
    }))
  ));
  CATALOG.length = 0;
  for (const cards of blocks) {
    cards.sort((a, b) => (a.card.difficulty || 0) - (b.card.difficulty || 0) || a.ord - b.ord);
    CATALOG.push(...cards.map(x => x.card));
  }
}

// Progression (étoiles + record par id) : persistance dans js/store.js
// (getProgress / saveResult). Ici, seule la logique de DÉVERROUILLAGE, qui
// dépend du catalogue.
// Déverrouillage PAR PAYS : la première gare d'un pays (la plus facile) est
// toujours ouverte ; les suivantes se débloquent à ≥ 1 étoile sur la
// précédente du MÊME pays. Aucun couloir entre pays.
function sameCountry(i, j) {
  return CATALOG[i] && CATALOG[j] && CATALOG[i].country === CATALOG[j].country;
}
function isUnlocked(i) {
  if (i === 0 || !sameCountry(i - 1, i)) return true; // tête de pays : ouverte
  return ((getProgress()[CATALOG[i - 1].id] || {}).stars || 0) >= 1;
}
