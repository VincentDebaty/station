"use strict";
// ------------------------------------------------------------------
// Lieux du réseau qui ne sont pas des gares jouables — leurs coordonnées, et
// rien d'autre. Ils ne se dessinent PLUS : la carte ne montre que le réseau
// jouable, et une ville qu'on ne peut pas prendre en main n'y a pas sa place.
// Ils servent à deux choses, dans cet ordre :
//
// 1. **Points de passage** (le rôle qui restera). Une ligne de data/lines.js
//    enchaîne les gares jouables EN PASSANT par eux : Namur – Ciney – Marloie
//    donne au trait la forme de la voie, là où Namur – Marloie tendait une
//    corde à travers la Famenne. Le point lui-même reste invisible.
// 2. **Extrémités des pays pas encore décrits en lignes** (France, Allemagne,
//    Royaume-Uni) : tant que leur topologie se déduit des portails, un portail
//    doit pouvoir se situer quelque part. Ces entrées disparaîtront avec
//    l'écriture de leurs lignes.
//
// Une destination en CUL-DE-SAC (Ostende, Genk, Turnhout, Couvin…) n'a rien à
// faire ici : elle vit sur le gril et dans le texte de la fiche, jamais sur la
// carte. Voir tools/AUTHORING-STATIONS.md §0.
//
// Clé = NOM du portail tel qu'il est écrit dans la fiche (la clé de l'objet
// `portals`), normalisé par netKey() : sans accents, sans casse, sans
// séparateurs. Attention : c'est le nom, PAS le champ `label` qui l'habille à
// l'écran — la fiche de Berlin écrit `WARSCHAU` et affiche « VARSOVIE ».
// Valeur = [lon, lat], même convention que GEO.cities.
// ------------------------------------------------------------------

const PLACES = {
  // --- Belgique : POINTS DE PASSAGE seulement -----------------------------
  // La Belgique tient sa topologie de data/lines.js ; ces points ne sont pas des
  // destinations mais les gares que les lignes TRAVERSENT — ce sont eux qui
  // donnent au tracé la forme de la voie plutôt qu'une corde tendue. Une
  // destination non jouable (Ostende, Genk, Turnhout…) n'a rien à faire ici :
  // elle vit sur le gril, pas sur la carte.
  aalter:       [3.450, 51.090],
  alost:        [4.039, 50.943],   // Aalst
  anzegem:      [3.475, 50.835],
  bertrix:      [5.257, 49.855],
  braine:       [4.137, 50.607],   // Braine-le-Comte
  ciney:        [5.100, 50.293],
  depinte:      [3.644, 50.994],   // De Pinte
  enghien:      [4.041, 50.694],
  fleurus:      [4.545, 50.484],
  ghislain:     [3.814, 50.447],   // Saint-Ghislain
  grammont:     [3.874, 50.772],   // Geraardsbergen
  haacht:       [4.639, 50.977],
  hal:          [4.235, 50.736],   // Halle
  herseaux:     [3.281, 50.717],
  huy:          [5.235, 50.520],
  jurbise:      [3.902, 50.535],
  kontich:      [4.450, 51.132],
  leuze:        [3.616, 50.599],   // Leuze-en-Hainaut
  lier:         [4.570, 51.131],   // Lierre
  manage:       [4.239, 50.502],
  niklaas:      [4.145, 51.170],   // Saint-Nicolas / Sint-Niklaas
  nivelles:     [4.331, 50.599],
  opwijk:       [4.191, 50.972],
  puurs:        [4.288, 51.077],
  rivage:       [5.532, 50.469],
  roulers:      [3.128, 50.943],   // Roeselare
  schellebelle: [3.938, 51.020],
  soignies:     [4.070, 50.583],
  tirlemont:    [4.933, 50.807],   // Tienen
  tongres:      [5.470, 50.783],   // Tongeren
  vilvorde:     [4.428, 50.930],
  waregem:      [3.417, 50.885],
  waremme:      [5.256, 50.699],
  zottegem:     [3.813, 50.868],

  // --- France : POINTS DE PASSAGE seulement -------------------------------
  // Même règle qu'en Belgique : ces gares ne sont pas jouables et ne se
  // dessinent pas ; elles donnent leur tracé aux lignes. Les quatre têtes de
  // ligne parisiennes que le jeu n'ouvre pas (Est, Saint-Lazare, Austerlitz,
  // Bercy) en font partie : les lignes de l'Est, de Normandie et du Centre
  // passent par elles avant de rejoindre la gare jouable la plus proche.
  parisest:        [2.358, 48.877],
  parisstlazare:   [2.325, 48.876],
  parisausterlitz: [2.365, 48.842],
  parisbercy:      [2.383, 48.839],

  agen:         [0.621, 44.208],
  alencon:      [0.099, 48.434],
  ales:         [4.085, 44.128],
  amberieu:     [5.342, 45.954],
  ancenis:      [-1.178, 47.369],
  angouleme:    [0.165, 45.654],
  arras:        [2.782, 50.287],
  aubrais:      [1.907, 47.927],   // Les Aubrais, la gare de passage d'Orléans
  barleduc:     [5.167, 48.773],
  belfort:      [6.854, 47.633],
  besancon:     [6.022, 47.247],
  beziers:      [3.219, 43.336],
  brive:        [1.529, 45.159],
  cahors:       [1.433, 44.449],
  cannes:       [7.020, 43.554],
  carcassonne:  [2.352, 43.218],
  chalons:      [4.349, 48.955],
  chartres:     [1.481, 48.448],
  chateauroux:  [1.700, 46.810],
  chateauthierry: [3.410, 49.038],
  colmar:       [7.347, 48.073],
  creil:        [2.475, 49.263],
  culmont:      [5.443, 47.810],   // Culmont-Chalindrey
  dol:          [-1.751, 48.544],
  dole:         [5.488, 47.096],
  etampes:      [2.159, 48.437],
  lalochesuryon: [-1.436, 46.672],
  langogne:     [3.857, 44.733],
  larochelle:   [-1.145, 46.153],
  laval:        [-0.761, 48.076],
  lecreusot:    [4.500, 46.765],
  macon:        [4.825, 46.303],
  mantes:       [1.703, 48.990],
  miramas:      [4.994, 43.586],
  moirans:      [5.582, 45.322],
  montargis:    [2.743, 48.007],
  montauban:    [1.341, 44.014],
  montelimar:   [4.745, 44.559],
  montmelian:   [6.043, 45.503],
  nevers:       [3.151, 46.987],
  pontamousson: [6.051, 48.901],
  redon:        [-2.088, 47.652],
  roanne:       [4.063, 46.039],
  sable:        [-0.342, 47.842],
  saintes:      [-0.618, 45.749],
  saintraphael: [6.769, 43.424],
  sarrebourg:   [7.053, 48.738],
  sens:         [3.268, 48.198],
  serquigny:    [0.719, 49.107],
  sete:         [3.697, 43.412],
  tarascon:     [4.657, 43.801],
  vendome:      [1.021, 47.822],
  vichy:        [3.430, 46.127],
  vienne:       [4.874, 45.521],
  chatellerault: [0.549, 46.819],
  calais:       [1.812, 50.902],   // Calais-Fréthun, dernière gare avant le tunnel

  // --- Allemagne ----------------------------------------------------------
  aachen:       [6.091, 50.768],
  ansbach:      [10.573, 49.301],
  augsburg:     [10.886, 48.365],
  bamberg:      [10.898, 49.901],
  bonn:         [7.097, 50.732],
  braunschweig: [10.540, 52.252],
  breisach:     [7.583, 48.030],
  bremen:       [8.814, 53.083],
  chemnitz:     [12.881, 50.839],
  cottbus:      [14.325, 51.754],
  dortmund:     [7.459, 51.518],
  dusseldorf:   [6.794, 51.220],
  fulda:        [9.684, 50.554],
  garmisch:     [11.096, 47.492],
  gorlitz:      [14.988, 51.147],
  halle:        [11.988, 51.478],
  hamm:         [7.809, 51.678],
  hof:          [11.917, 50.313],
  karlsruhe:    [8.402, 48.994],
  kiel:         [10.132, 54.315],
  lindau:       [9.681, 47.548],
  lubeck:       [10.670, 53.833],
  mainz:        [8.259, 50.001],
  mannheim:     [8.469, 49.479],
  muhldorf:     [12.525, 48.244],
  neustadt:     [8.216, 47.912],   // Titisee-Neustadt, en Forêt-Noire (ligne de Fribourg)
  offenburg:    [7.945, 48.470],
  osnabruck:    [8.043, 52.272],
  regensburg:   [12.099, 49.011],
  trier:        [6.641, 49.756],
  wuppertal:    [7.150, 51.256],
  wurzburg:     [9.936, 49.801],

  // --- Hors des pays jouables : ce sont eux qui font déborder le réseau du
  //     cadre national, donc ils comptent double pour la lecture « Europe ».
  bale:         [7.590, 47.548],   // Suisse
  copenhague:   [12.564, 55.673],  // Danemark
  enschede:     [6.890, 52.221],   // Pays-Bas
  geneve:       [6.142, 46.210],   // Suisse
  luxembourg:   [6.134, 49.600],   // Luxembourg
  maastricht:   [5.706, 50.850],   // Pays-Bas
  prague:       [14.435, 50.083],  // Tchéquie
  salzburg:     [13.046, 47.813],  // Autriche
  warschau:     [21.003, 52.229],  // Varsovie, Pologne (la fiche de Berlin écrit WARSCHAU)
  zurich:       [8.540, 47.378],   // Suisse

  // --- Royaume-Uni --------------------------------------------------------
  aberdeen:     [-2.097, 57.144],
  airport:      [-2.276, 53.365],  // Manchester Airport
  ayr:          [-4.625, 55.458],
  basingstoke:  [-1.089, 51.268],
  bournemouth:  [-1.874, 50.727],
  bradford:     [-1.751, 53.793],
  cambridge:    [0.137, 52.194],
  cardiff:      [-3.179, 51.476],
  chester:      [-2.881, 53.196],
  derby:        [-1.463, 52.916],
  exeter:       [-3.543, 50.729],
  gloucester:   [-2.235, 51.865],
  gourock:      [-4.816, 55.962],
  yarmouth:     [1.722, 52.607],   // Great Yarmouth
  guildford:    [-0.581, 51.237],
  harrogate:    [-1.538, 53.993],
  lanark:       [-3.778, 55.674],
  lowestoft:    [1.750, 52.475],
  newcastle:    [-1.617, 54.968],
  northberwick: [-2.723, 56.058],
  oxford:       [-1.245, 51.753],
  paisley:      [-4.423, 55.846],
  portsmouth:   [-1.091, 50.798],
  preston:      [-2.708, 53.758],
  scarborough:  [-0.404, 54.280],
  sheffield:    [-1.466, 53.378],
  sheringham:   [1.207, 52.943],
  stirling:     [-3.936, 56.119],
  wolverhampton: [-2.129, 52.588]
};

// Noms de portail qui désignent en réalité une gare JOUABLE sous un autre nom :
// une fiche peut nommer un terminus (Paddington) ou la ville dans sa langue
// (Londres) là où le catalogue connaît « London Waterloo ». Sans cette table,
// on perdrait de vraies arêtes — dont l'Eurostar Paris–Londres.
const PLACE_ALIASES = {
  paddington: "waterloo",
  londres:    "waterloo",
  london:     "waterloo"
};
