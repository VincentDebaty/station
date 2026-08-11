"use strict";
// ------------------------------------------------------------------
// Lieux SECONDAIRES du réseau — les destinations que citent les fiches sans
// être elles-mêmes jouables (Ostende, Aachen, Prague…).
//
// Sans coordonnées, une ligne vers Ostende ne pouvait être qu'un trait qui
// s'arrête dans le vide. Avec elles, le réseau va vraiment quelque part : ces
// lieux deviennent de petits points, reliés à leur gare, qui n'apparaissent
// qu'une fois zoomé (voir le LOD dans js/mapnet.js).
//
// Clé = NOM du portail tel qu'il est écrit dans la fiche (la clé de l'objet
// `portals`), normalisé par netKey() : sans accents, sans casse, sans
// séparateurs. Attention : c'est le nom, PAS le champ `label` qui l'habille à
// l'écran — la fiche de Berlin écrit `WARSCHAU` et affiche « VARSOVIE ».
// Valeur = [lon, lat], même convention que GEO.cities.
//
// Ces points ne sont PAS jouables : pas de progression, pas de clic. Ils
// existent pour que le réseau soit continu et lisible à travers l'Europe, y
// compris hors des pays jouables (Bâle, Zurich, Luxembourg, Prague, Varsovie…).
// ------------------------------------------------------------------

const PLACES = {
  // --- Belgique -----------------------------------------------------------
  aarschot:     [4.837, 50.985],
  arlon:        [5.812, 49.683],
  bertrix:      [5.257, 49.855],
  blankenberge: [3.133, 51.313],
  courtrai:     [3.265, 50.828],
  couvin:       [4.494, 50.053],
  dinant:       [4.912, 50.259],
  eeclo:        [3.564, 51.187],
  essen:        [4.470, 51.465],
  genk:         [5.500, 50.965],
  knokke:       [3.283, 51.345],
  lier:         [4.570, 51.131],
  liers:        [5.575, 50.688],
  malines:      [4.480, 51.028],
  ostende:      [2.925, 51.228],
  quievrain:    [3.685, 50.407],
  quevy:        [3.945, 50.351],
  termonde:     [4.101, 51.028],

  // --- France -------------------------------------------------------------
  amiens:       [2.302, 49.892],
  arcachon:     [-1.166, 44.658],
  aurillac:     [2.445, 44.926],
  bayonne:      [-1.475, 43.493],
  brive:        [1.533, 45.159],
  colmar:       [7.357, 48.079],
  creil:        [2.475, 49.263],
  douai:        [3.080, 50.370],
  dunkerque:    [2.377, 51.034],
  foix:         [1.605, 42.965],
  grenoble:     [5.714, 45.191],
  lecroisic:    [-2.512, 47.293],
  miramas:      [4.994, 43.586],
  nancy:        [6.174, 48.690],
  narbonne:     [3.005, 43.190],
  nice:         [7.262, 43.705],
  nimes:        [4.361, 43.832],
  quimper:      [-4.093, 47.995],
  rennes:       [-1.673, 48.103],
  saintetienne: [4.390, 45.440],
  thionville:   [6.168, 49.357],
  toulon:       [5.930, 43.128],

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
  sarrebruck:   [6.991, 49.241],
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
