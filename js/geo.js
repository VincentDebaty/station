"use strict";
// ------------------------------------------------------------------
// Données de jeu de la carte — continents + pays JOUABLES.
//
// La GÉOMÉTRIE (frontières réelles des continents/pays, ancres de labels) vit
// dans data/worldmap.js (global WORLDMAP, Natural Earth 110m). Ici on ne garde
// que ce qui touche au JEU : la liste des continents (id, nom, bbox de cadrage)
// et les pays réellement jouables avec leurs villes.
//
// Un pays de WORLDMAP sans entrée jouable ici s'affiche « Bientôt » (forme
// grisée, non cliquable). Lien géo ↔ jeu par le code ISO A3 (champ `iso`).
//
// Clé de ville = id de gare ("namur") → lien direct getProgress()/CATALOG.
// Les coordonnées des villes vivent ICI (pas dans les fiches de gare).
// ------------------------------------------------------------------

const GEO = {
  // Projection équirectangulaire interne (ratio 2:1 du monde). Le viewBox du
  // niveau monde est resserré sur la BANDE HABITÉE (≈ lat +75 à −56) : on retire
  // le vide au-dessus du pôle Nord et l'essentiel de l'Antarctique, ce qui
  // agrandit les continents. Cadré verticalement sur le centre des terres.
  world: { W: 2000, H: 1000, viewBox: [0, 45, 2000, 800] },

  // Les 6 zones. bbox [lonMin,latMin,lonMax,latMax] = cadrage de zoom (fiable,
  // pas de souci d'antiméridien contrairement à un calcul sur les formes).
  continents: [
    { id: "europe",      name: "Europe",                     bbox: [-11, 35, 32, 66] },
    { id: "am-nord",     name: "Amérique du Nord",           bbox: [-168, 12, -52, 72] },
    { id: "am-sud",      name: "Amérique du Sud",            bbox: [-82, -56, -34, 13] },
    { id: "afrique",     name: "Afrique",                    bbox: [-19, -35, 52, 38] },
    { id: "asie",        name: "Asie",                       bbox: [26, 5, 150, 75] },
    { id: "sea-oceanie", name: "Océanie",                    bbox: [92, -48, 180, 28] }
  ],

  // Pays jouables uniquement. iso = ADM0_A3 (lien vers WORLDMAP).
  countries: {
    belgique: { name: "Belgique", flag: "🇧🇪", iso: "BEL", continent: "europe", chipDy: -20,
      cities: {
        "bruxelles-midi": [4.336, 50.836], anvers: [4.421, 51.219], gand: [3.710, 51.036],
        bruges: [3.217, 51.197], louvain: [4.716, 50.881], namur: [4.862, 50.469],
        charleroi: [4.437, 50.412], mons: [3.952, 50.454], liege: [5.567, 50.639],
        hasselt: [5.338, 50.930], libramont: [5.378, 49.921],
        ottignies: [4.570, 50.671], tournai: [3.395, 50.613],
        // Les seize ajoutées en août 2026, relevées sur la gare elle-même (iRail).
        malines: [4.482, 51.017], termonde: [4.101, 51.023], lokeren: [3.988, 51.108],
        denderleeuw: [4.072, 50.892], audenarde: [3.600, 50.850], deinze: [3.534, 50.978],
        courtrai: [3.265, 50.825], mouscron: [3.228, 50.741], ath: [3.768, 50.632],
        lalouviere: [4.180, 50.478], landen: [5.080, 50.748], aarschot: [4.824, 50.984],
        herentals: [4.830, 51.182], dinant: [4.908, 50.261], marloie: [5.314, 50.203],
        arlon: [5.810, 49.681]
      } },
    france: { name: "France", flag: "🇫🇷", iso: "FRA", continent: "europe",
      cities: {
        // Les trois têtes de ligne parisiennes sont à 2 km l'une de l'autre : à
        // l'échelle du pays elles ne font qu'un point, et la règle du centimètre
        // (mapnet.js) n'en garderait qu'une. On les ÉCARTE de quelques kilomètres
        // sur l'axe de leur propre desserte — Nord au nord, Montparnasse à
        // l'ouest, Lyon au sud-est. Le mensonge est de 5 km, invisible à
        // l'échelle où l'on choisit une gare, et il rend les trois cliquables.
        "paris-nord": [2.355, 48.925], "paris-lyon": [2.425, 48.815],
        "paris-montparnasse": [2.255, 48.825],
        lille: [3.070, 50.638], amiens: [2.313, 49.891], rouen: [1.094, 49.449],
        caen: [-0.348, 49.176], rennes: [-1.673, 48.104], "le-mans": [0.193, 47.996],
        angers: [-0.557, 47.465], nantes: [-1.542, 47.218], tours: [0.724, 47.386],
        orleans: [1.905, 47.908], vierzon: [2.060, 47.226], limoges: [1.267, 45.836],
        poitiers: [0.333, 46.582], bordeaux: [-0.556, 44.826], toulouse: [1.454, 43.611],
        narbonne: [3.006, 43.190], montpellier: [3.881, 43.605], nimes: [4.366, 43.832],
        avignon: [4.805, 43.942], marseille: [5.380, 43.303], toulon: [5.929, 43.128],
        nice: [7.262, 43.705], valence: [4.893, 44.928], grenoble: [5.715, 45.191],
        chambery: [5.920, 45.571], lyon: [4.859, 45.761], dijon: [5.027, 47.323],
        mulhouse: [7.342, 47.742], strasbourg: [7.734, 48.585], metz: [6.176, 49.120],
        nancy: [6.175, 48.690], reims: [4.024, 49.259], "clermont-ferrand": [3.087, 45.778]
      } },
    allemagne: { name: "Allemagne", flag: "🇩🇪", iso: "DEU", continent: "europe",
      cities: {
        berlin: [13.369, 52.525], munchen: [11.558, 48.140], frankfurt: [8.664, 50.107],
        hamburg: [10.006, 53.553],
        koln: [6.959, 50.943], hannover: [9.741, 52.377], leipzig: [12.383, 51.345],
        stuttgart: [9.182, 48.784], nurnberg: [11.082, 49.446], munster: [7.635, 51.956],
        dresden: [13.732, 51.041], freiburg: [7.841, 47.997]
      } },
    "royaume-uni": { name: "Royaume-Uni", flag: "🇬🇧", iso: "GBR", continent: "europe",
      frame: [-5.8, 50.6, 1.8, 56.5], neighbors: { belgique: [3.25, 51.22] },
      cities: {
        york: [-1.093, 53.958], norwich: [1.306, 52.627], reading: [-0.972, 51.459],
        bristol: [-2.582, 51.449], manchester: [-2.230, 53.477], leeds: [-1.548, 53.795],
        edinburgh: [-3.188, 55.952], glasgow: [-4.257, 55.860], liverpool: [-2.978, 53.408],
        birmingham: [-1.900, 52.478], waterloo: [-0.113, 51.503]
      } }
  }
};

// ------------------------------------------------------------------
// Zone de départ : chez l'utilisateur, sans rien lui demander.
// ------------------------------------------------------------------
// La carte s'ouvre sur le pays de l'utilisateur. On le déduit du FUSEAU HORAIRE
// du navigateur, puis de sa langue — jamais de l'API de géolocalisation : elle
// ouvrirait le jeu sur une demande de permission, ce qui n'a pas sa place dans
// un jeu pour enfants, et elle est refusée la plupart du temps.
// Les fuseaux des pays voisins pointent vers le pays jouable le plus proche :
// mieux vaut ouvrir sur la Belgique depuis Amsterdam que sur le monde entier.
const ZONE_BY_TZ = {
  "Europe/Brussels": "belgique", "Europe/Amsterdam": "belgique",
  "Europe/Luxembourg": "belgique",
  "Europe/Paris": "france", "Europe/Monaco": "france", "Europe/Andorra": "france",
  "Europe/Berlin": "allemagne", "Europe/Busingen": "allemagne",
  "Europe/Zurich": "allemagne", "Europe/Vienna": "allemagne",
  "Europe/Prague": "allemagne", "Europe/Copenhagen": "allemagne",
  "Europe/London": "royaume-uni", "Europe/Dublin": "royaume-uni",
  "Europe/Isle_of_Man": "royaume-uni", "Europe/Guernsey": "royaume-uni",
  "Europe/Jersey": "royaume-uni"
};
const ZONE_BY_LANG = {
  "fr-be": "belgique", "nl-be": "belgique", "nl": "belgique",
  "fr": "france",
  "de": "allemagne", "de-at": "allemagne", "de-ch": "allemagne",
  "en-gb": "royaume-uni", "cy": "royaume-uni", "ga": "royaume-uni"
};
function userCountrySlug() {
  try {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (ZONE_BY_TZ[tz] && GEO.countries[ZONE_BY_TZ[tz]]) return ZONE_BY_TZ[tz];
  } catch (e) { /* Intl indisponible : on passe à la langue */ }
  const langs = (navigator.languages && navigator.languages.length)
    ? navigator.languages : [navigator.language || ""];
  for (const raw of langs) {
    const l = String(raw).toLowerCase();
    // « fr-BE » d'abord (plus précis), « fr » ensuite.
    if (ZONE_BY_LANG[l]) return ZONE_BY_LANG[l];
    const base = l.split("-")[0];
    if (ZONE_BY_LANG[base]) return ZONE_BY_LANG[base];
  }
  return null; // inconnu : la carte s'ouvrira sur l'Europe
}

// ------------------------------------------------------------------
// Projection équirectangulaire lon/lat → unités SVG internes.
// ------------------------------------------------------------------
function geoProject(lon, lat) {
  return {
    x: (lon + 180) / 360 * GEO.world.W,
    y: (90 - lat) / 180 * GEO.world.H
  };
}
// bbox géo [lonMin,latMin,lonMax,latMax] → rectangle SVG {x,y,w,h}.
function geoBoxToRect(bbox) {
  const a = geoProject(bbox[0], bbox[3]); // haut-gauche (latMax = plus haut)
  const b = geoProject(bbox[2], bbox[1]); // bas-droit  (latMin = plus bas)
  return { x: a.x, y: a.y, w: b.x - a.x, h: b.y - a.y };
}

// ------------------------------------------------------------------
// Progression agrégée, calculée à la volée depuis getProgress().
// ------------------------------------------------------------------
function countryStationIds(slug) {
  const c = GEO.countries[slug];
  return c && c.cities ? Object.keys(c.cities) : [];
}
function countryProgress(slug) {
  const ids = countryStationIds(slug);
  const prog = (typeof getProgress === "function") ? getProgress() : {};
  let done = 0, earned = 0;
  for (const id of ids) {
    const stars = (prog[id] || {}).stars || 0;
    if (stars > 0) done++;
    earned += stars;
  }
  return { total: ids.length, done, earned, max: ids.length * 3 };
}
function continentProgress(contId) {
  const acc = { total: 0, done: 0, earned: 0, max: 0 };
  for (const slug in GEO.countries) {
    if (GEO.countries[slug].continent !== contId) continue;
    const p = countryProgress(slug);
    acc.total += p.total; acc.done += p.done; acc.earned += p.earned; acc.max += p.max;
  }
  return acc;
}
