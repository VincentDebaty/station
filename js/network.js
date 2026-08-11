"use strict";
// ------------------------------------------------------------------
// Réseau ferré DÉRIVÉ des fiches de gare — aucune topologie écrite à la main.
//
// DEUX sources, dans cet ordre de préséance :
//
// 1. Les LIGNES RÉELLES (data/lines.js) — la bonne. Une ligne est une suite
//    ordonnée de points desservis ; les arêtes sont ses paires CONSÉCUTIVES.
//    Dès qu'une gare figure dans une ligne, ses arêtes viennent de là et de
//    nulle part ailleurs.
//
// 2. La déduction par PORTAILS — transitoire, pour les pays pas encore décrits
//    en lignes. Elle est structurellement fausse : un portail est une
//    DESTINATION, pas un voisin. « Namur → LUXEMBOURG » désigne un train qui
//    roule par Libramont et Arlon ; en tirer une arête dessine une corde droite
//    à travers l'Ardenne et multiplie les traits sans voie réelle. À remplacer
//    par des lignes, pays par pays.
//
// Un portail qui ne désigne ni une gare, ni un alias, ni un lieu connu est une
// erreur de fiche — `node tools/net-check.mjs` la refuse.
//
// Dans les deux cas le graphe se lit NON ORIENTÉ, EN UNION.
//
// Rien ici ne dépend de l'affichage : js/mapnet.js consomme ces fonctions pour
// dessiner, et rien d'autre ne s'appuie dessus.
// ------------------------------------------------------------------

const NET = { built: false, byKey: {}, links: {}, places: {}, edgeList: [] };

// Les fiches écrivent leurs destinations en CAPITALES — c'est de la
// signalétique de quai. Sur une carte ce sont des villes : on leur rend une
// casse de nom propre, une seule fois, pour la carte comme pour la fiche.
function netTitleCase(t) {
  return String(t || "").toLocaleLowerCase("fr")
    .replace(/(^|[\s'’\-])(\p{L})/gu, (m, a, b) => a + b.toLocaleUpperCase("fr"));
}

// Nom de portail → clé comparable : sans accents, sans casse, sans séparateurs.
// « LIÈGE », « Liège », « liege » et « LIEGE » désignent la même gare.
function netKey(s) {
  return String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/[^a-z0-9]/g, "");
}

function buildNetwork() {
  NET.byKey = {}; NET.links = {}; NET.places = {}; NET.edgeList = []; NET.built = false;
  if (typeof CATALOG === "undefined" || !CATALOG.length) return;
  const ALIAS = (typeof PLACE_ALIASES !== "undefined") ? PLACE_ALIASES : {};
  const POINTS = (typeof PLACES !== "undefined") ? PLACES : {};

  // Index nom → gare. DEUX clés par gare : son id (« bruxelles-midi ») et son
  // nom de ville (« Bruxelles »), qui est celui que portent les portails des
  // voisines. Une clé ambiguë (deux gares la revendiquent) est retirée : mieux
  // vaut un lieu secondaire de trop qu'une arête fausse.
  const ambiguous = {};
  for (const c of CATALOG) {
    for (const key of [netKey(c.id), netKey(c.city)]) {
      if (!key) continue;
      if (NET.byKey[key] && NET.byKey[key] !== c.id) ambiguous[key] = true;
      else NET.byKey[key] = c.id;
    }
  }
  for (const key in ambiguous) delete NET.byKey[key];
  // Alias explicites (data/places.js) : une fiche peut nommer un terminus
  // (PADDINGTON) ou la ville dans sa langue (LONDRES) là où le catalogue connaît
  // « London Waterloo ». Ils l'emportent sur la déduction.
  for (const key in ALIAS) NET.byKey[key] = ALIAS[key];

  for (const c of CATALOG) NET.links[c.id] = { to: [], places: [] };

  // Libellés d'affichage des lieux : on les prend dans les fiches, qui les
  // écrivent avec leurs accents (QUIÉVRAIN), plutôt que dans la clé normalisée
  // qui les a perdus. Fait AVANT les lignes, qui n'ont que des clés.
  const placeLabel = {};
  for (const c of CATALOG)
    for (const name in (c.portals || {})) {
      const k = netKey(name);
      if (POINTS[k] && !placeLabel[k]) placeLabel[k] = netTitleCase(c.portals[name].label || name);
    }

  // --- 1. Les lignes réelles. On note au passage quelles gares elles couvrent :
  // celles-là ne devront RIEN à la déduction par portails.
  //
  // Les arêtes sont accumulées dans une liste GÉNÉRIQUE : une ligne enchaîne
  // indifféremment des gares et des lieux, et deux lieux peuvent parfaitement se
  // suivre (Termonde – Malines sur la L60). Un modèle « gare → ses lieux »
  // cassait la chaîne à cet endroit précis.
  // Couverture PAR PAYS (data/lines.js) : une gare n'est « décrite par des
  // lignes » que si son pays l'est. Sinon une gare simplement citée au bout
  // d'une ligne étrangère perdrait ses propres relations.
  const lineCountries = (typeof LINE_COUNTRIES !== "undefined") ? LINE_COUNTRIES : [];
  const covered = new Set(CATALOG.filter(c => lineCountries.indexOf(c.country) >= 0).map(c => c.id));
  const seenEdge = new Set();
  const isStation = k => !!NET.links[k];
  const addPlace = k => {
    if (!POINTS[k] || NET.places[k]) return;
    NET.places[k] = { key: k, label: placeLabel[k] || netTitleCase(k), lonlat: POINTS[k], from: [] };
  };
  const linkPair = (a, b) => {
    if (a === b) return;
    if (!isStation(a) && !POINTS[a]) return;   // nœud inconnu : net-check le signale
    if (!isStation(b) && !POINTS[b]) return;
    const k = a < b ? a + "|" + b : b + "|" + a;
    if (seenEdge.has(k)) return;
    seenEdge.add(k);
    NET.edgeList.push([a, b]);
    if (isStation(a) && isStation(b)) {
      NET.links[a].to.push(b); NET.links[b].to.push(a);
    } else {
      addPlace(isStation(a) ? b : a);
      if (isStation(a)) { NET.links[a].places.push(b); NET.places[b].from.push(a); }
      if (isStation(b)) { NET.links[b].places.push(a); NET.places[a].from.push(b); }
    }
  };
  if (typeof LINES !== "undefined") {
    for (const line of LINES) {
      const ns = (line.nodes || []).map(n => NET.byKey[netKey(n)] || netKey(n));
      for (let i = 0; i + 1 < ns.length; i++) linkPair(ns[i], ns[i + 1]);
    }
  }

  // --- 2. Déduction par portails — transitoire, pour les gares qu'aucune ligne
  // ne couvre encore. Une gare couverte n'y touche pas, même comme extrémité :
  // sinon la corde fausse qu'on vient de retirer reviendrait par l'autre bout.
  for (const c of CATALOG) {
    if (covered.has(c.id)) continue;
    for (const name in (c.portals || {})) {
      const key = netKey(name);
      const target = NET.byKey[key];
      if (target && target !== c.id) {
        if (!covered.has(target)) linkPair(c.id, target);
      } else if (POINTS[key]) {
        linkPair(c.id, key);
      }
      // Sinon : portail non résolu. Silencieux ici (le rendu ne peut rien en
      // faire) ; tools/net-check.mjs le signale comme une erreur de fiche.
    }
  }

  NET.built = true;
}

// { to: [ids de gares jouables], places: [clés de lieux secondaires] }.
function netLinks(id) {
  if (!NET.built) buildNetwork();
  return NET.links[id] || { to: [], places: [] };
}
// Tous les lieux secondaires réellement cités, par clé :
// { key, label, lonlat: [lon, lat], from: [ids des gares qui les desservent] }.
function netPlaces() {
  if (!NET.built) buildNetwork();
  return NET.places;
}
// Toutes les arêtes du réseau, dans l'ordre où elles ont été posées.
// Chaque extrémité est soit un id de gare jouable, soit une clé de lieu — c'est
// au rendu de savoir ce qu'il en fait.
function netEdges() {
  if (!NET.built) buildNetwork();
  return NET.edgeList;
}
// Nombre de voisins d'une gare — sa « hub-ité ». C'est ce qui décide de son
// rang, donc du zoom auquel elle apparaît (les nœuds avant les feuilles).
function netDegree(id) {
  const l = netLinks(id);
  return l.to.length + l.places.length;
}
