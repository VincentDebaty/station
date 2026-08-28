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
//
// CE FICHIER EST DE NOUVEAU CHARGÉ PAR LE JEU depuis le lot E (25 août 2026) :
// la carte du ruban (js/parcours.js) pose chaque gare à ses coordonnées, donc
// elle les lit ici. Les OUTILS s'en servent aussi — la sinuosité des chapitres
// et la continuité réelle se mesurent dessus (tools/carte-check.mjs,
// tools/net-check.mjs).
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
        arlon: [5.810, 49.681],
        verviers: [5.855, 50.589],
        enghien: [4.047, 50.697],
        hal: [4.24, 50.733]
      } },
    france: { name: "France", flag: "🇫🇷", iso: "FRA", continent: "europe",
      cities: {
        // Les trois têtes de ligne parisiennes sont à 2 km l'une de l'autre : à
        // l'échelle du pays elles ne font qu'un point, et la règle du centimètre
        // (mapnet.js) n'en garderait qu'une. On les ÉCARTE de quelques kilomètres
        // sur l'axe de leur propre desserte — Nord au nord, Montparnasse à
        // l'ouest, Lyon au sud-est, Est à l'est. Le mensonge est de 5 km, invisible à
        // l'échelle où l'on choisit une gare, et il rend les quatre cliquables.
        "paris-nord": [2.355, 48.925], "paris-lyon": [2.425, 48.815],
        "paris-montparnasse": [2.255, 48.825], "paris-est": [2.435, 48.895],
        // Les six de la fin août : la ligne de Genève (Ambérieu – Culoz –
        // Bellegarde) et l'arc atlantique (Bordeaux – Nantes).
        // Les sept du 23 août : la Bourgogne (Paris – Dijon – Lyon), la Garonne
        // (Toulouse – Bordeaux) et la Bavière (Nuremberg – Munich).
        chalon: [4.853, 46.780],
        macon: [4.825, 46.303],
        laroche: [3.517, 47.968],
        montauban: [1.341, 44.014],
        agen: [0.621, 44.208],
        angouleme: [0.157, 45.649],
        chartres: [1.489, 48.447],
        amberieu: [5.342, 45.954],
        culoz: [5.780, 45.845],
        bellegarde: [5.826, 46.109],
        saintes: [-0.618, 45.749],
        larochelle: [-1.145, 46.153],
        lalochesuryon: [-1.436, 46.672],
        chalons: [4.365, 48.956],
        lille: [3.070, 50.638], amiens: [2.313, 49.891],
        rennes: [-1.673, 48.104], "le-mans": [0.193, 47.996],
        angers: [-0.557, 47.465], nantes: [-1.542, 47.218], tours: [0.724, 47.386],
        orleans: [1.905, 47.908], vierzon: [2.060, 47.226], limoges: [1.267, 45.836],
        poitiers: [0.333, 46.582], bordeaux: [-0.556, 44.826], toulouse: [1.454, 43.611],
        beziers: [3.216, 43.344], carcassonne: [2.353, 43.213],
        narbonne: [3.006, 43.190], montpellier: [3.881, 43.605], nimes: [4.366, 43.832],
        avignon: [4.805, 43.942], marseille: [5.380, 43.303], toulon: [5.929, 43.128],
        nice: [7.262, 43.705], valence: [4.893, 44.928], grenoble: [5.715, 45.191],
        chambery: [5.920, 45.571], lyon: [4.859, 45.761], dijon: [5.027, 47.323],
        mulhouse: [7.342, 47.742], strasbourg: [7.734, 48.585], metz: [6.176, 49.120],
        nancy: [6.175, 48.690], reims: [4.024, 49.259], "clermont-ferrand": [3.087, 45.778],
        thionville: [6.168, 49.355],
        sarrebourg: [7.053, 48.738],
        miramas: [4.994, 43.586],
        tarascon: [4.657, 43.801],
        creil: [2.475, 49.263],
        arras: [2.782, 50.287],
        douai: [3.089, 50.371],
        // L'Alsace du TER 200, entre Strasbourg et Bâle.
        selestat: [7.442, 48.256],
        colmar: [7.347, 48.073],
        "aix-les-bains": [5.9086, 45.6889],
        "bourg-en-bresse": [5.2153, 46.2028]
      } },
    allemagne: { name: "Allemagne", flag: "🇩🇪", iso: "DEU", continent: "europe",
      cities: {
        // Gares du ruban restant à écrire (lot F) : leurs coordonnées sont ici
        // dès maintenant pour que le tracé se dessine sans trou — la carte les
        // montre « à venir », le jeu ne les propose jamais.
        wiesbaden: [8.244, 50.070], darmstadt: [8.629, 49.873], heidelberg: [8.675, 49.404],
        bruchsal: [8.588, 49.128], vaihingen: [8.960, 48.930], dachau: [11.434, 48.253],
        pfaffenhofen: [11.508, 48.531], kinding: [11.386, 49.000], allersberg: [11.234, 49.253],
        berlin: [13.369, 52.525], munchen: [11.555, 48.141], frankfurt: [8.663, 50.107],
        hamburg: [10.006, 53.553],
        koln: [6.958, 50.943], hannover: [9.742, 52.377], leipzig: [12.382, 51.345],
        stuttgart: [9.182, 48.784], nurnberg: [11.082, 49.446], munster: [7.635, 51.956],
        dresden: [13.732, 51.040], freiburg: [7.842, 47.998],
        // Les vingt-quatre ajoutées en août 2026 (coordonnées Wikidata). La Ruhr
        // en aligne quatre en quarante kilomètres : contrairement aux quatre
        // Londres, ce sont de vraies villes distinctes — on ne les écarte pas,
        // c'est le zoom qui les sépare.
        dusseldorf: [6.793, 51.220], dortmund: [7.459, 51.517], essen: [7.014, 51.451],
        duisburg: [6.776, 51.430], bielefeld: [8.532, 52.028], osnabruck: [8.061, 52.273],
        bremen: [8.814, 53.083], kiel: [10.132, 54.315], lubeck: [10.669, 53.867],
        rostock: [12.131, 54.078], magdeburg: [11.628, 52.131], halle: [11.988, 51.478],
        erfurt: [11.038, 50.972], kassel: [9.448, 51.311], wurzburg: [9.936, 49.803],
        mannheim: [8.470, 49.480], karlsruhe: [8.401, 48.994], saarbrucken: [6.991, 49.241],
        mainz: [8.259, 50.001], koblenz: [7.589, 50.351], bonn: [7.097, 50.732],
        ulm: [9.983, 48.400], augsburg: [10.886, 48.366], regensburg: [12.100, 49.012],
        // Trèves, ajoutée avec le Luxembourg : c'est elle qui donne au Grand-Duché
        // sa frontière allemande. Sans elle, l'axe de la Moselle s'arrêtait dans le
        // vide et les portails TRIER de Coblence et Sarrebruck restaient morts.
        trier: [6.641, 49.756],
        aachen: [6.091, 50.768],
        bingen: [7.894, 49.967],
        juterbog: [13.074, 51.993],
        wittenberg: [12.647, 51.866],
        bitterfeld: [12.33, 51.624],
        wuppertal: [7.152, 51.255],
        hagen: [7.461, 51.363],
        hamm: [7.809, 51.678],
        minden: [8.933, 52.291],
        hanau: [8.929, 50.121],
        fulda: [9.684, 50.554],
        bebra: [9.791, 50.974],
        gottingen: [9.926, 51.537],
        braunschweig: [10.521, 52.264],
        brandenburg: [12.562, 52.412],
        potsdam: [13.064, 52.396],
        celle: [10.081, 52.622],
        uelzen: [10.561, 52.965],
        luneburg: [10.414, 53.25],
        harburg: [9.992, 53.456],
        gunzburg: [10.278, 48.459],
        plochingen: [9.413, 48.711],
        // Les quinze d'août 2026 : le Spessart et la Franconie (Francfort –
        // Nuremberg), la Saale et le Frankenwald (Leipzig – Nuremberg), la
        // Gäubahn (Zurich – Stuttgart), l'Allgäu (Munich – Zurich) et Rheine
        // sur l'IC d'Amsterdam. Coordonnées Wikidata, comme les précédentes.
        // Les cinq de la fin août : le corridor du Rhin (Strasbourg – Francfort)
        // et la Baltique (Hambourg – Berlin). Coordonnées Wikidata.
        ingolstadt: [11.437, 48.744],
        treuchtlingen: [10.908, 48.961],
        offenburg: [7.941, 48.471],
        rastatt: [8.212, 48.858],
        schwerin: [11.408, 53.634],
        badkleinen: [11.489, 53.815],
        neustrelitz: [13.070, 53.362],
        aschaffenburg: [9.143, 49.980],
        gemunden: [9.694, 50.052],
        furth: [10.990, 49.474],
        bamberg: [10.897, 49.900],
        lichtenfels: [11.058, 50.146],
        saalfeld: [11.366, 50.649],
        weimar: [11.329, 50.981],
        naumburg: [11.797, 51.163],
        rheine: [7.436, 52.277],
        singen: [8.841, 47.758],
        tuttlingen: [8.818, 47.983],
        horb: [8.690, 48.443],
        lindau: [9.681, 47.544],
        memmingen: [10.180, 47.985],
        buchloe: [10.727, 48.037],
        wiesbaden: [8.2417, 50.0826],
        darmstadt: [8.6512, 49.8728],
        heidelberg: [8.6724, 49.3988],
        bruchsal: [8.5983, 49.1244],
        vaihingen: [8.9581, 48.9297],
        dachau: [11.4342, 48.26],
        roth: [11.0919, 49.2469]
      } },
    luxembourg: { name: "Luxembourg", flag: "🇱🇺", iso: "LUX", continent: "europe",
      cities: {
        // Pétange et Rodange sont à 2,4 km : à l'échelle du pays elles ne font
        // qu'un point, et c'est le zoom qui les sépare. On ne les écarte PAS
        // comme les têtes de ligne parisiennes — ce sont deux vraies communes
        // voisines, et le trait qui les relie est une vraie ligne.
        luxembourg: [6.134, 49.600], bettembourg: [6.104, 49.518],
        "esch-sur-alzette": [5.981, 49.494], petange: [5.881, 49.558],
        rodange: [5.842, 49.546], ettelbruck: [6.104, 49.847],
        kautenbach: [6.024, 49.947]
      } },
    "pays-bas": { name: "Pays-Bas", flag: "🇳🇱", iso: "NLD", continent: "europe",
      cities: {
        amsterdam: [4.9, 52.379],
        // La Randstad vers Anvers (Rotterdam, Dordrecht, Roosendaal) et l'IC
        // d'Amsterdam vers Berlin (Amersfoort, Deventer, Hengelo).
        rotterdam: [4.469, 51.925],
        dordrecht: [4.665, 51.807],
        roosendaal: [4.458, 51.591],
        amersfoort: [5.371, 52.153],
        deventer: [6.160, 52.257],
        hengelo: [6.794, 52.262]
      } },
    "suisse": { name: "Suisse", flag: "🇨🇭", iso: "CHE", continent: "europe",
      cities: {
        geneve: [6.142, 46.21],
        zurich: [8.54, 47.378],
        aarau: [8.051, 47.391],
        olten: [7.908, 47.352],
        bern: [7.439, 46.949],
        fribourg: [7.151, 46.803],
        lausanne: [6.629, 46.517],
        // Bâle est la porte du Rhin (Strasbourg – Zurich) ; Winterthour et
        // Schaffhouse tiennent la Gäubahn ; Saint-Gall l'Arlberg vers Munich.
        bale: [7.590, 47.548],
        winterthur: [8.724, 47.500],
        schaffhausen: [8.632, 47.698],
        stgallen: [9.370, 47.423]
      } },
    "italie": { name: "Italie", flag: "🇮🇹", iso: "IT", continent: "europe",
      cities: {
        bussoleno: [7.1478, 45.1367],
        rho: [9.0433, 45.5242],
        novara: [8.6253, 45.4508],
        vercelli: [8.4164, 45.3298],
        chivasso: [7.89, 45.1933],
        torino: [7.6789, 45.0625],
        vicenza: [11.5404, 45.5411],
        verona: [10.9822, 45.4292],
        brescia: [10.2128, 45.5324],
        treviglio: [9.5887, 45.5154],
        milano: [9.204, 45.4857]
      } },
    "royaume-uni": { name: "Royaume-Uni", flag: "🇬🇧", iso: "GBR", continent: "europe",
      frame: [-6.3, 49.9, 1.9, 57.6], neighbors: { belgique: [3.25, 51.22] },
      cities: {
        // Les quatre têtes de ligne londoniennes tiennent dans deux kilomètres.
        // Même traitement qu'à Paris : on les écarte de quelques kilomètres, sur
        // l'axe de leur propre ligne — Euston au nord-ouest, King's Cross au
        // nord-est, Paddington à l'ouest, Waterloo au sud. Sans cet écart, la
        // règle du centimètre n'en garderait qu'une et trois seraient injouables.
        waterloo: [-0.100, 51.435], euston: [-0.205, 51.567],
        "kings-cross": [-0.070, 51.572], paddington: [-0.295, 51.505],
        reading: [-0.972, 51.459], oxford: [-1.270, 51.753], southampton: [-1.414, 50.907],
        brighton: [-0.141, 50.829], salisbury: [-1.806, 51.071], bristol: [-2.582, 51.449],
        cardiff: [-3.179, 51.476], exeter: [-3.544, 50.730], plymouth: [-4.143, 50.378],
        birmingham: [-1.900, 52.478], leicester: [-1.124, 52.632], nottingham: [-1.147, 52.947],
        derby: [-1.463, 52.916], crewe: [-2.433, 53.089], chester: [-2.880, 53.197],
        manchester: [-2.230, 53.477], liverpool: [-2.978, 53.408], preston: [-2.707, 53.756],
        carlisle: [-2.933, 54.891], leeds: [-1.548, 53.795], sheffield: [-1.462, 53.378],
        doncaster: [-1.139, 53.523], york: [-1.093, 53.958], newcastle: [-1.617, 54.969],
        norwich: [1.306, 52.627], cambridge: [0.138, 52.194], peterborough: [-0.250, 52.575],
        edinburgh: [-3.188, 55.952], glasgow: [-4.257, 55.860], stirling: [-3.936, 56.119],
        perth: [-3.439, 56.393], aberdeen: [-2.098, 57.144]
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
