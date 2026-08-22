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
  // Points de passage ajoutés en août 2026, pour que les sept lignes remplies
  // ce mois-ci suivent la voie et non la corde : le Neckar de la Gäubahn, la
  // Saale et le Frankenwald entre Weimar et Bamberg, la Thüringer Bahn depuis
  // Leipzig, et Bad Bentheim sur l'IC Amsterdam – Berlin.
  badbentheim: [7.157, 52.303],
  weissenfels: [11.975, 51.203],
  apolda:      [11.516, 51.026],
  arnstadt:    [10.951, 50.836],
  rottenbach:  [11.155, 50.686],
  probstzella: [11.386, 50.535],
  erlangen:    [11.002, 49.596],
  rottweil:    [8.628, 48.163],
  geislingen: [9.83, 48.624],
  goppingen: [9.653, 48.703],
  burg: [11.855, 52.272],
  genthin: [12.157, 52.408],
  werder: [12.934, 52.378],
  sangerhausen: [11.298, 51.471],
  nordhausen: [10.795, 51.497],
  northeim: [9.996, 51.707],
  eichenberg: [9.919, 51.379],
  eschwege: [10.053, 51.186],
  melsungen: [9.546, 51.131],
  badhersfeld: [9.708, 50.868],
  lohne: [8.704, 52.197],
  arnsberg: [8.064, 51.397],
  unna: [7.69, 51.534],
  schwerte: [7.566, 51.443],
  bregenz: [9.74, 47.503],
  emmerich: [6.25, 51.834],
  arnhem: [5.901, 51.985],
  utrecht: [5.11, 52.089],
  schiphol: [4.762, 52.309],
  rognac: [5.235, 43.488],
  arles: [4.632, 43.685],
  konz: [6.581, 49.701],
  perl: [6.383, 49.474],
  apach: [6.378, 49.462],
  duren: [6.483, 50.809],
  welkenraedt: [5.975, 50.66],
  pepinster: [5.806, 50.573],
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
  fleurus:      [4.545, 50.484],
  ghislain:     [3.814, 50.447],   // Saint-Ghislain
  grammont:     [3.874, 50.772],   // Geraardsbergen
  haacht:       [4.639, 50.977],
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
  parisausterlitz: [2.365, 48.842],
  parisbercy:      [2.383, 48.839],

  agen:         [0.621, 44.208],
  ales:         [4.085, 44.128],
  ancenis:      [-1.178, 47.369],
  aubrais:      [1.907, 47.927],   // Les Aubrais, la gare de passage d'Orléans
  barleduc:     [5.167, 48.773],
  belfort:      [6.854, 47.633],
  besancon:     [6.022, 47.247],
  brive:        [1.529, 45.159],
  cahors:       [1.433, 44.449],
  cannes:       [7.020, 43.554],
  chateauroux:  [1.700, 46.810],
  chateauthierry: [3.410, 49.038],
  culmont:      [5.443, 47.810],   // Culmont-Chalindrey
  dole:         [5.488, 47.096],
  etampes:      [2.159, 48.437],
  langogne:     [3.857, 44.733],
  laval:        [-0.761, 48.076],
  lecreusot:    [4.500, 46.765],
  macon:        [4.825, 46.303],
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
  saintraphael: [6.769, 43.424],
  sens:         [3.268, 48.198],
  sete:         [3.697, 43.412],
  vendome:      [1.021, 47.822],
  vichy:        [3.430, 46.127],
  vienne:       [4.874, 45.521],
  chatellerault: [0.549, 46.819],
  calais:       [1.812, 50.902],   // Calais-Fréthun, dernière gare avant le tunnel

  // --- Allemagne : POINTS DE PASSAGE seulement ----------------------------
  // Aachen a un statut à part : c'est par elle que la ligne de Liège entre en
  // Allemagne — le point de passage qui recoud la Belgique au reste.
  coburg:       [10.968, 50.259],
  crailsheim:   [10.072, 49.135],
  donauworth:   [10.777, 48.718],
  eisenach:     [10.313, 50.978],
  elsterwerda:  [13.522, 51.463],
  gelsenkirchen: [7.104, 51.505],
  grobers:      [12.113, 51.349],  // bifurcation de Gröbers, où la LGV se sépare vers Halle et Leipzig
  heidelberg:   [8.670, 49.404],
  ingolstadt:   [11.437, 48.744],
  jena:         [11.586, 50.927],
  kaiserslautern: [7.769, 49.436],
  landshut:     [12.128, 48.545],
  limburg:      [8.052, 50.386],
  oberhausen:   [6.852, 51.478],
  riesa:        [13.294, 51.306],
  treuchtlingen: [10.908, 48.961],
  unstruttal:   [11.653, 51.276],  // viaduc de l'Unstrut (Karsdorf) : le nord de la LGV Erfurt – Leipzig
  warburg:      [9.146, 51.489],
  // Weimar n'est traversée par AUCUNE ligne écrite : la LGV passe au nord par
  // la Finne, la Saalebahn au sud par Iéna. Elle attend sa Thüringer Bahn
  // (Erfurt – Weimar – Apolda – Naumburg) ; le portail WEIMAR d'Erfurt reste un
  // cul-de-sac d'ici là. Coordonnée gardée pour ce jour-là.
  wismar:       [11.463, 53.892],
  wolfsburg:    [10.788, 52.429],
  // Forbach : la dernière gare française avant la Sarre.
  forbach:      [6.899, 49.190],
  // La Moselle et l'Eifel, le tracé des deux lignes de Trèves.
  bullay:       [7.153, 50.048],
  cochem:       [7.166, 50.145],
  euskirchen:   [6.787, 50.660],
  gerolstein:   [6.663, 50.223],
  merzig:       [6.638, 49.444],
  wittlich:     [6.899, 49.976],

  // --- Luxembourg : POINTS DE PASSAGE seulement ---------------------------
  // Wasserbillig et Kleinbettingen sont les deux gares frontières du pays :
  // elles donnent leur tracé aux lignes de Trèves et d'Arlon sans se dessiner.
  // Thionville en fait autant côté français.
  bascharage:     [5.906, 49.567],   // Bascharage-Sanem
  belval:         [5.945, 49.500],   // Belval-Université
  clervaux:       [6.030, 50.055],
  differdange:    [5.885, 49.524],
  dippach:        [5.984, 49.581],   // Dippach-Reckange
  kleinbettingen: [5.918, 49.652],
  mersch:         [6.106, 49.750],
  noertzange:     [6.043, 49.505],
  troisvierges:   [6.000, 50.123],
  wasserbillig:   [6.499, 49.714],
  // Belgique et France, sur les lignes du Grand-Duché.
  gouvy:          [5.945, 50.187],
  vielsalm:       [5.917, 50.283],

  // --- Hors des pays jouables : ce sont eux qui font déborder le réseau du
  //     cadre national, donc ils comptent double pour la lecture « Europe ».
  copenhague:   [12.564, 55.673],  // Danemark
  enschede:     [6.890, 52.221],   // Pays-Bas
  // (Luxembourg a quitté cette liste : le Grand-Duché est jouable, ses
  //  coordonnées vivent dans js/geo.js comme celles de toute gare du catalogue.)
  maastricht:   [5.706, 50.850],   // Pays-Bas
  prague:       [14.435, 50.083],  // Tchéquie
  salzburg:     [13.046, 47.813],  // Autriche
  warschau:     [21.003, 52.229],  // Varsovie, Pologne (la fiche de Berlin écrit WARSCHAU)

  // --- Royaume-Uni : POINTS DE PASSAGE seulement --------------------------
  // Les quatre têtes de ligne londoniennes jouables sont dans le catalogue ;
  // St Pancras, Liverpool Street et Victoria n'y sont pas, mais les lignes
  // passent par elles avant de rejoindre la gare jouable la plus proche —
  // King's Cross est à deux cents mètres de St Pancras.
  stpancras:    [-0.126, 51.531],
  liverpoolst:  [-0.081, 51.519],
  victoria:     [-0.144, 51.495],

  banbury:      [-1.328, 52.060],
  basingstoke:  [-1.088, 51.268],
  bath:         [-2.356, 51.377],
  berwick:      [-2.011, 55.775],
  carstairs:    [-3.669, 55.693],
  cheltenham:   [-2.100, 51.897],
  chesterfield: [-1.420, 53.238],
  colchester:   [0.893, 51.901],
  darlington:   [-1.547, 54.521],
  dundee:       [-2.971, 56.457],
  durham:       [-1.581, 54.780],
  ely:          [0.266, 52.390],
  falkirk:      [-3.786, 56.002],
  gatwick:      [-0.161, 51.157],
  grantham:     [-0.642, 52.906],
  guildford:    [-0.581, 51.237],
  ipswich:      [1.144, 52.051],
  lancaster:    [-2.807, 54.048],
  loughborough: [-1.196, 52.779],
  motherwell:   [-3.994, 55.792],
  newbury:      [-1.323, 51.398],
  newport:      [-2.998, 51.588],
  newtonabbot:  [-3.609, 50.529],
  nuneaton:     [-1.464, 52.527],
  oxenholme:    [-2.722, 54.305],
  rugby:        [-1.250, 52.379],
  shrewsbury:   [-2.750, 52.711],
  stoke:        [-2.181, 53.008],
  swindon:      [-1.785, 51.566],
  taunton:      [-3.103, 51.023],
  wakefield:    [-1.506, 53.682],
  warrington:   [-2.603, 53.386],
  westbury:     [-2.200, 51.267],
  wigan:        [-2.632, 53.543],
  wolverhampton: [-2.129, 52.588]
};

// Noms de portail qui désignent en réalité une gare JOUABLE sous un autre nom :
// une fiche peut nommer la ville dans sa langue là où le catalogue connaît la
// gare. Sans cette table, on perdrait de vraies arêtes.
// « PADDINGTON » n'y figure plus : c'est une gare jouable depuis août 2026.
// « LONDRES », lui, désigne l'Eurostar — qui arrive à St Pancras, mitoyenne de
// King's Cross.
const PLACE_ALIASES = {
  londres: "kings-cross",
  london:  "kings-cross"
};
