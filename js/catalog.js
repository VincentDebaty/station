"use strict";
// ------------------------------------------------------------------
// Catalogue des gares — un fichier JSON par gare, classé par pays dans
// data/stations/. index.json RÉUNIT les gares d'un pays ET fixe leur ORDRE DE
// JEU : un parcours géographiquement cohérent, démarrant sur une gare facile et
// montant globalement en difficulté (les gares proches s'enchaînent, la ligne du
// réseau ne zigzague plus). Chaque pays est une échelle indépendante : tous sont
// ouverts d'emblée, chacun se gravit pour son compte — un joueur commence par
// SON pays, pas par la Belgique.
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
  // Un pays = un bloc contigu dans CATALOG. L'ORDRE DE JEU (1→N, qui pilote le
  // déverrouillage, la numérotation sur la carte et la ligne du réseau) est
  // l'ordre CURATÉ de index.json : un parcours géographiquement cohérent qui
  // démarre par une gare facile et monte globalement en difficulté (compromis).
  // Le champ « difficulty » ne sert plus au tri — seulement aux pastilles de la
  // fiche de gare. Promise.all préserve l'ordre du tableau.
  const blocks = await Promise.all(index.map(group =>
    Promise.all(group.stations.map(id => {
      const f = base + group.country + "/" + id + ".json";
      return fetch(f).then(r => {
        if (!r.ok) throw new Error(f + " : " + r.status);
        return r.json();
      });
    }))
  ));
  CATALOG.length = 0;
  for (const cards of blocks) CATALOG.push(...cards);
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
// Pays « terminé » = toutes ses gares décrochées (≥ 1 étoile). Sert à souligner
// l'achèvement d'un pays en fin de service.
function countryComplete(i) {
  const country = CATALOG[i] && CATALOG[i].country;
  if (!country) return false;
  const prog = getProgress();
  return CATALOG.every(c => c.country !== country || ((prog[c.id] || {}).stars || 0) >= 1);
}
