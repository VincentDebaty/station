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
    { id: "sea-oceanie", name: "Asie du Sud-Est / Océanie",  bbox: [92, -48, 180, 28] }
  ],

  // Pays jouables uniquement. iso = ADM0_A3 (lien vers WORLDMAP).
  countries: {
    belgique: { name: "Belgique", flag: "🇧🇪", iso: "BEL", continent: "europe",
      cities: {
        "bruxelles-midi": [4.336, 50.836], anvers: [4.421, 51.219], gand: [3.710, 51.036],
        bruges: [3.217, 51.197], louvain: [4.716, 50.881], namur: [4.862, 50.469],
        charleroi: [4.437, 50.412], mons: [3.952, 50.454], liege: [5.567, 50.639],
        hasselt: [5.338, 50.930], libramont: [5.378, 49.921],
        ottignies: [4.570, 50.671], tournai: [3.395, 50.613]
      } },
    france: { name: "France", flag: "🇫🇷", iso: "FRA", continent: "europe",
      cities: {
        "paris-nord": [2.355, 48.881], lille: [3.070, 50.638], metz: [6.176, 49.120],
        strasbourg: [7.734, 48.585], nantes: [-1.542, 47.218], bordeaux: [-0.556, 44.826],
        lyon: [4.842, 45.750], marseille: [5.380, 43.303],
        toulouse: [1.454, 43.611], "clermont-ferrand": [3.087, 45.778]
      } },
    allemagne: { name: "Allemagne", flag: "🇩🇪", iso: "DEU", continent: "europe",
      cities: {
        berlin: [13.369, 52.525], munchen: [11.558, 48.140], frankfurt: [8.664, 50.107],
        hamburg: [10.006, 53.553],
        koln: [6.959, 50.943], hannover: [9.741, 52.377], leipzig: [12.383, 51.345],
        mannheim: [8.469, 49.479], munster: [7.635, 51.956], wiesbaden: [8.244, 50.070],
        wurzburg: [9.936, 49.801], freiburg: [7.841, 47.997]
      } }
  }
};

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
