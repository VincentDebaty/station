"use strict";
// ------------------------------------------------------------------
// LE GRAPHE EUROPÉEN — les nœuds, et rien d'autre pour l'instant.
//
// La méta-progression repose sur un principe unique : l'Europe est un graphe.
// Les NŒUDS sont des gares-boss, les ARÊTES des lignes, et progresser c'est
// étendre son réseau dans ce graphe. Ce fichier tient les nœuds ; les arêtes
// (LIENS) viennent ensuite, et les gares intermédiaires de chaque corridor
// après elles.
//
// ------------------------------------------------------------------
// CE QUI A DÉCIDÉ DE CETTE LISTE
// ------------------------------------------------------------------
// Trois mesures, faites avant d'écrire une ligne :
//
//   1. UN HUB EST UN CROISEMENT. La difficulté d'une gare n'est pas un réglage
//      libre : elle EST la taille de son croisement. Sur les 145 gares du
//      catalogue, une difficulté 1 a 3,9 directions et 4,6 quais en moyenne,
//      une difficulté 5 en a 6,4 et 9,8. On ne « promeut » donc pas une petite
//      gare — on choisit les grandes.
//
//   2. IL FAUT DE LA PLACE ENTRE DEUX HUBS. Un corridor de cinq à huit gares
//      suppose 250 à 400 km. En dessous de 110 km il n'y a plus de quoi y
//      glisser une seule gare : le hub est redondant. Seize l'étaient — Malmö
//      à 28 km de Copenhague, Cardiff à 41 de Bristol — et ont été retirées.
//      Deux exceptions assumées : Lille (94 km de Bruxelles) parce que c'est le
//      carrefour Eurostar/TGV, et Stuttgart (107 km de Strasbourg) parce que
//      ces 107 km franchissent une frontière.
//
//   3. LES CONSTELLATIONS DOIVENT S'ÉQUILIBRER. La première version allait de
//      6 hubs pour l'Italie à 13 pour la France : une région deux fois plus
//      longue à finir qu'une autre se sent. On a COMBLÉ plutôt que rogné —
//      le Mezzogiorno, l'Andalousie, l'Irlande et l'intérieur des Balkans
//      étaient vides sur la carte. L'écart est tombé de 2,2 à 1,86 pour 1, et
//      six constellations sur neuf comptent exactement neuf hubs.
//
// ------------------------------------------------------------------
// LES CHAMPS
// ------------------------------------------------------------------
// `id`     identifiant stable, sans accent — c'est lui qui voyage dans le code.
// `nom`    ce que le joueur lit.
// `ll`     [longitude, latitude]. Sert au tracé de la carte et au calcul des
//          écartements ; ce n'est PAS une position d'affichage, le rendu en
//          plan de métro s'autorise à déplacer les nœuds.
// `rang`   1 = hub continental (4 à 6 sorties, carrefour du graphe et réserve
//          d'extension) · 2 = hub régional (2 à 3 sorties, ferme une branche).
// `gare`   la fiche du catalogue, si elle existe déjà. 27 des 85 hubs sont
//          déjà jouables ; les 58 autres restent à écrire.
//
// Une CONSTELLATION est un calque de célébration, pas une frontière de jeu :
// elle colore la carte, mesure la complétion et porte les fêtes. On n'entre
// jamais dans une région par une porte — on y arrive par une ligne.
// ------------------------------------------------------------------

const CONSTELLATIONS = [
  { id: "bri", nom: "Îles britanniques",      couleur: "#a78bfa" },
  { id: "nw",  nom: "France et Benelux",      couleur: "#2dd4bf" },
  { id: "ger", nom: "Germanie et Alpes",      couleur: "#f5b23c" },
  { id: "ib",  nom: "Ibérie",                 couleur: "#f2588f" },
  { id: "it",  nom: "Italie",                 couleur: "#4ade80" },
  { id: "sca", nom: "Scandinavie et Baltique", couleur: "#60a5fa" },
  { id: "ctr", nom: "Europe centrale",        couleur: "#fb923c" },
  { id: "est", nom: "Europe de l'Est",        couleur: "#f87171" },
  { id: "bal", nom: "Balkans et Orient",      couleur: "#e879f9" }
];

const HUBS = [
  // ---- Îles britanniques (9) ----
  { id: "birmingham", nom: "Birmingham", c: "bri", ll: [-1.9, 52.48], rang: 1, gare: "Birmingham" },
  { id: "edimbourg", nom: "Édimbourg", c: "bri", ll: [-3.19, 55.95], rang: 1, gare: "Edinburgh" },
  { id: "londres", nom: "Londres", c: "bri", ll: [-0.13, 51.51], rang: 1, gare: "London King's Cross",
    // Un boss a autant de VERSIONS que de sorties. Londres n'a pas besoin
    // qu'on les invente : ses terminus SONT ses directions, et le catalogue
    // les a déjà écrits comme des fiches distinctes.
    versions: [
      { vers: "newcastle",  gare: "London King's Cross", nom: "la Côte Est" },
      { vers: "birmingham", gare: "London Euston",       nom: "la Côte Ouest" },
      { vers: "manchester", gare: "London Euston",       nom: "la Côte Ouest" },
      { vers: "bristol",    gare: "London Paddington",   nom: "le Great Western" },
      // Waterloo a été le terminus de l'Eurostar jusqu'en 2007 : c'est bien
      // par là qu'on passait sous la Manche.
      { vers: "lille",      gare: "London Waterloo",     nom: "le tunnel" },
      { vers: "amsterdam",  gare: "London Waterloo",     nom: "le tunnel" }
    ] },
  { id: "manchester", nom: "Manchester", c: "bri", ll: [-2.24, 53.48], rang: 1, gare: "Manchester" },
  { id: "aberdeen", nom: "Aberdeen", c: "bri", ll: [-2.1, 57.15], rang: 2 },
  { id: "bristol", nom: "Bristol", c: "bri", ll: [-2.59, 51.45], rang: 2, gare: "Bristol" },
  { id: "cork", nom: "Cork", c: "bri", ll: [-8.47, 51.9], rang: 2 },
  { id: "dublin", nom: "Dublin", c: "bri", ll: [-6.26, 53.35], rang: 2 },
  { id: "newcastle", nom: "Newcastle", c: "bri", ll: [-1.61, 54.97], rang: 2, gare: "Newcastle" },
  // ---- France et Benelux (13) ----
  { id: "amsterdam", nom: "Amsterdam", c: "nw", ll: [4.9, 52.37], rang: 1 },
  { id: "bordeaux", nom: "Bordeaux", c: "nw", ll: [-0.58, 44.84], rang: 1, gare: "Bordeaux" },
  { id: "bruxelles", nom: "Bruxelles", c: "nw", ll: [4.35, 50.85], rang: 1, gare: "Bruxelles" },
  { id: "lille", nom: "Lille", c: "nw", ll: [3.06, 50.63], rang: 1, gare: "Lille" },
  { id: "lyon", nom: "Lyon", c: "nw", ll: [4.83, 45.76], rang: 1, gare: "Lyon" },
  { id: "marseille", nom: "Marseille", c: "nw", ll: [5.37, 43.3], rang: 1, gare: "Marseille" },
  { id: "paris", nom: "Paris", c: "nw", ll: [2.35, 48.86], rang: 1, gare: "Paris-Nord",
    // Paris-Est manque au catalogue : la ligne de Strasbourg se joue depuis
    // Paris-Nord, sa voisine immédiate, en attendant sa fiche.
    versions: [
      { vers: "lille",      gare: "Paris-Nord",         nom: "le Nord" },
      { vers: "strasbourg", gare: "Paris-Nord",         nom: "l'Est" },
      { vers: "dijon",      gare: "Paris-Gare-de-Lyon", nom: "le Sud-Est" },
      { vers: "nantes",     gare: "Paris-Montparnasse", nom: "l'Ouest" },
      { vers: "bordeaux",   gare: "Paris-Montparnasse", nom: "l'Atlantique" }
    ] },
  { id: "strasbourg", nom: "Strasbourg", c: "nw", ll: [7.75, 48.58], rang: 1, gare: "Strasbourg" },
  { id: "dijon", nom: "Dijon", c: "nw", ll: [5.04, 47.32], rang: 2, gare: "Dijon" },
  { id: "luxembourg", nom: "Luxembourg", c: "nw", ll: [6.13, 49.61], rang: 2, gare: "Luxembourg" },
  { id: "montpellier", nom: "Montpellier", c: "nw", ll: [3.88, 43.61], rang: 2, gare: "Montpellier" },
  { id: "nantes", nom: "Nantes", c: "nw", ll: [-1.55, 47.22], rang: 2, gare: "Nantes" },
  { id: "toulouse", nom: "Toulouse", c: "nw", ll: [1.44, 43.6], rang: 2, gare: "Toulouse" },
  // ---- Germanie et Alpes (11) ----
  { id: "berlin", nom: "Berlin", c: "ger", ll: [13.4, 52.52], rang: 1, gare: "Berlin" },
  { id: "cologne", nom: "Cologne", c: "ger", ll: [6.96, 50.94], rang: 1, gare: "Cologne" },
  { id: "francfort", nom: "Francfort", c: "ger", ll: [8.68, 50.11], rang: 1, gare: "Francfort" },
  { id: "hambourg", nom: "Hambourg", c: "ger", ll: [10, 53.55], rang: 1, gare: "Hambourg" },
  { id: "hanovre", nom: "Hanovre", c: "ger", ll: [9.73, 52.37], rang: 1, gare: "Hanovre" },
  { id: "munich", nom: "Munich", c: "ger", ll: [11.58, 48.14], rang: 1, gare: "Munich" },
  { id: "zurich", nom: "Zurich", c: "ger", ll: [8.54, 47.38], rang: 1 },
  { id: "geneve", nom: "Genève", c: "ger", ll: [6.14, 46.2], rang: 2 },
  { id: "leipzig", nom: "Leipzig", c: "ger", ll: [12.37, 51.34], rang: 2, gare: "Leipzig" },
  { id: "nuremberg", nom: "Nuremberg", c: "ger", ll: [11.08, 49.45], rang: 2, gare: "Nuremberg" },
  { id: "stuttgart", nom: "Stuttgart", c: "ger", ll: [9.18, 48.78], rang: 2, gare: "Stuttgart" },
  // ---- Ibérie (9) ----
  { id: "barcelone", nom: "Barcelone", c: "ib", ll: [2.17, 41.39], rang: 1 },
  { id: "lisbonne", nom: "Lisbonne", c: "ib", ll: [-9.14, 38.72], rang: 2 },
  { id: "madrid", nom: "Madrid", c: "ib", ll: [-3.7, 40.42], rang: 1 },
  { id: "bilbao", nom: "Bilbao", c: "ib", ll: [-2.93, 43.26], rang: 2 },
  { id: "malaga", nom: "Malaga", c: "ib", ll: [-4.42, 36.72], rang: 2 },
  { id: "porto", nom: "Porto", c: "ib", ll: [-8.61, 41.15], rang: 2 },
  { id: "saragosse", nom: "Saragosse", c: "ib", ll: [-0.88, 41.65], rang: 2 },
  { id: "seville", nom: "Séville", c: "ib", ll: [-5.98, 37.39], rang: 2 },
  { id: "valence", nom: "Valence", c: "ib", ll: [-0.38, 39.47], rang: 2 },
  // ---- Italie (9) ----
  { id: "bologne", nom: "Bologne", c: "it", ll: [11.34, 44.49], rang: 1 },
  { id: "milan", nom: "Milan", c: "it", ll: [9.19, 45.46], rang: 1 },
  { id: "rome", nom: "Rome", c: "it", ll: [12.5, 41.9], rang: 1 },
  { id: "bari", nom: "Bari", c: "it", ll: [16.87, 41.13], rang: 2 },
  { id: "genes", nom: "Gênes", c: "it", ll: [8.93, 44.41], rang: 2 },
  { id: "naples", nom: "Naples", c: "it", ll: [14.25, 40.85], rang: 2 },
  { id: "palerme", nom: "Palerme", c: "it", ll: [13.36, 38.12], rang: 2 },
  { id: "turin", nom: "Turin", c: "it", ll: [7.69, 45.07], rang: 2 },
  { id: "venise", nom: "Venise", c: "it", ll: [12.32, 45.44], rang: 2 },
  // ---- Scandinavie et Baltique (9) ----
  { id: "copenhague", nom: "Copenhague", c: "sca", ll: [12.57, 55.68], rang: 1 },
  { id: "helsinki", nom: "Helsinki", c: "sca", ll: [24.94, 60.17], rang: 2 },
  { id: "oslo", nom: "Oslo", c: "sca", ll: [10.75, 59.91], rang: 1 },
  { id: "riga", nom: "Riga", c: "sca", ll: [24.11, 56.95], rang: 2 },
  { id: "stockholm", nom: "Stockholm", c: "sca", ll: [18.07, 59.33], rang: 1 },
  { id: "vilnius", nom: "Vilnius", c: "sca", ll: [25.28, 54.69], rang: 1 },
  { id: "bergen", nom: "Bergen", c: "sca", ll: [5.32, 60.39], rang: 2 },
  { id: "goteborg", nom: "Göteborg", c: "sca", ll: [11.97, 57.71], rang: 2 },
  { id: "tallinn", nom: "Tallinn", c: "sca", ll: [24.75, 59.44], rang: 2 },
  // ---- Europe centrale (9) ----
  { id: "budapest", nom: "Budapest", c: "ctr", ll: [19.04, 47.5], rang: 1 },
  { id: "prague", nom: "Prague", c: "ctr", ll: [14.44, 50.08], rang: 1 },
  { id: "varsovie", nom: "Varsovie", c: "ctr", ll: [21.01, 52.23], rang: 1 },
  { id: "vienne", nom: "Vienne", c: "ctr", ll: [16.37, 48.21], rang: 1 },
  { id: "cracovie", nom: "Cracovie", c: "ctr", ll: [19.94, 50.06], rang: 2 },
  { id: "gdansk", nom: "Gdańsk", c: "ctr", ll: [18.65, 54.35], rang: 2 },
  { id: "ljubljana", nom: "Ljubljana", c: "ctr", ll: [14.51, 46.06], rang: 2 },
  { id: "wroclaw", nom: "Wrocław", c: "ctr", ll: [17.04, 51.11], rang: 2 },
  { id: "zagreb", nom: "Zagreb", c: "ctr", ll: [15.98, 45.81], rang: 2 },
  // ---- Europe de l'Est (7) ----
  { id: "kharkiv", nom: "Kharkiv", c: "est", ll: [36.23, 49.99], rang: 2 },
  { id: "kyiv", nom: "Kyiv", c: "est", ll: [30.52, 50.45], rang: 1 },
  { id: "brest-litovsk", nom: "Brest-Litovsk", c: "est", ll: [23.66, 52.1], rang: 2 },
  { id: "dnipro", nom: "Dnipro", c: "est", ll: [35.05, 48.47], rang: 2 },
  { id: "lviv", nom: "Lviv", c: "est", ll: [24.03, 49.84], rang: 2 },
  { id: "minsk", nom: "Minsk", c: "est", ll: [27.56, 53.9], rang: 2 },
  { id: "odessa", nom: "Odessa", c: "est", ll: [30.73, 46.48], rang: 2 },
  // ---- Balkans et Orient (9) ----
  { id: "belgrade", nom: "Belgrade", c: "bal", ll: [20.46, 44.79], rang: 1 },
  { id: "bucarest", nom: "Bucarest", c: "bal", ll: [26.1, 44.43], rang: 1 },
  { id: "istanbul", nom: "Istanbul", c: "bal", ll: [28.98, 41.01], rang: 2 },
  { id: "athenes", nom: "Athènes", c: "bal", ll: [23.73, 37.98], rang: 2 },
  { id: "sarajevo", nom: "Sarajevo", c: "bal", ll: [18.41, 43.86], rang: 2 },
  { id: "sofia", nom: "Sofia", c: "bal", ll: [23.32, 42.7], rang: 2 },
  { id: "split", nom: "Split", c: "bal", ll: [16.44, 43.51], rang: 2 },
  { id: "thessalonique", nom: "Thessalonique", c: "bal", ll: [22.94, 40.64], rang: 2 },
  { id: "tirana", nom: "Tirana", c: "bal", ll: [19.82, 41.33], rang: 2 },
];

// ------------------------------------------------------------------
// LES LIENS — quelles gares-boss se font face au bout d'un corridor.
// ------------------------------------------------------------------
// Une arête dit qu'un corridor EXISTE entre deux hubs ; elle ne dit pas encore
// quelles gares le composent. C'est la couche suivante, et elle s'écrira
// corridor par corridor, en s'appuyant sur data/lines.js pour les tracés déjà
// décrits.
//
// Chaque lien correspond à une relation ferroviaire réelle. Les seules
// exceptions sont marquées `mer` : quatre traversées sans alternative
// ferroviaire, et qui sont pourtant la façon dont on voyage vraiment —
// Helsinki–Tallinn est la ligne passagère la plus fréquentée de la Baltique,
// et la Suède ne rejoint la Finlande par le rail qu'à Haparanda, tout au nord,
// avec un changement d'écartement des voies.
//
// L'Albanie n'a plus de liaison ferroviaire internationale : Tirana ne tient au
// réseau que par le ferry de Durrës vers Bari. L'Irlande non plus — Dublin
// passe par Holyhead. Les taire reviendrait à laisser deux hubs orphelins.
const LIENS = [
  // ---- Îles britanniques ----
  ["londres", "birmingham"], ["londres", "bristol"], ["londres", "newcastle"],
  ["londres", "manchester"], ["birmingham", "manchester"], ["birmingham", "bristol"],
  ["manchester", "newcastle"], ["manchester", "edimbourg"],
  ["newcastle", "edimbourg"], ["edimbourg", "aberdeen"],
  ["dublin", "cork"], ["dublin", "manchester", "mer"],   // Holyhead
  ["londres", "lille", "mer"],                            // le tunnel sous la Manche

  // ---- France et Benelux ----
  ["paris", "lille"], ["paris", "strasbourg"], ["paris", "dijon"],
  ["paris", "nantes"], ["paris", "bordeaux"],
  ["lille", "bruxelles"], ["bruxelles", "amsterdam"], ["bruxelles", "luxembourg"],
  ["bruxelles", "cologne"], ["amsterdam", "cologne"],
  ["amsterdam", "hanovre"],                               // l'IC Amsterdam-Berlin
  ["amsterdam", "londres", "mer"],                        // l'Eurostar depuis 2018
  ["luxembourg", "strasbourg"], ["luxembourg", "francfort"],
  ["dijon", "lyon"], ["lyon", "marseille"], ["lyon", "geneve"], ["lyon", "turin"],
  ["marseille", "montpellier"], ["montpellier", "toulouse"], ["montpellier", "barcelone"],
  ["toulouse", "bordeaux"], ["bordeaux", "nantes"], ["bordeaux", "bilbao"],
  ["strasbourg", "stuttgart"], ["strasbourg", "zurich"], ["strasbourg", "francfort"],
  ["marseille", "genes"],

  // ---- Germanie et Alpes ----
  ["cologne", "francfort"], ["cologne", "hanovre"], ["cologne", "hambourg"],
  ["francfort", "hanovre"], ["francfort", "nuremberg"], ["francfort", "stuttgart"],
  ["hanovre", "hambourg"], ["hanovre", "berlin"], ["hambourg", "berlin"],
  ["hambourg", "copenhague"], ["berlin", "leipzig"], ["berlin", "prague"],
  ["leipzig", "nuremberg"], ["nuremberg", "munich"], ["munich", "stuttgart"],
  ["munich", "zurich"], ["munich", "vienne"], ["zurich", "geneve"],
  ["zurich", "milan"], ["zurich", "stuttgart"],

  // ---- Ibérie ----
  ["madrid", "saragosse"], ["saragosse", "barcelone"], ["madrid", "seville"],
  ["madrid", "valence"], ["madrid", "bilbao"], ["madrid", "lisbonne"],
  ["barcelone", "valence"], ["valence", "malaga"], ["seville", "malaga"],
  ["lisbonne", "porto"], ["saragosse", "valence"],

  // ---- Italie ----
  ["milan", "turin"], ["milan", "bologne"], ["milan", "venise"], ["milan", "genes"],
  ["bologne", "rome"], ["rome", "naples"], ["naples", "bari"],
  ["rome", "bari"], ["rome", "genes"],                    // la Tyrrhénienne, par Pise
  ["naples", "palerme"],                                  // le train passe le détroit sur le bac
  ["venise", "ljubljana"], ["genes", "bologne"],

  // ---- Scandinavie et Baltique ----
  ["copenhague", "goteborg"], ["goteborg", "oslo"], ["goteborg", "stockholm"],
  ["stockholm", "oslo"], ["oslo", "bergen"],
  ["stockholm", "helsinki", "mer"],                       // par Turku
  ["helsinki", "tallinn", "mer"],                         // deux heures de traversée
  ["tallinn", "riga"], ["riga", "vilnius"], ["vilnius", "varsovie"],
  ["vilnius", "minsk"], ["copenhague", "gdansk", "mer"],

  // ---- Europe centrale ----
  ["varsovie", "gdansk"], ["varsovie", "cracovie"], ["varsovie", "wroclaw"],
  ["varsovie", "brest-litovsk"], ["cracovie", "wroclaw"], ["cracovie", "budapest"],
  ["wroclaw", "prague"], ["prague", "vienne"], ["vienne", "budapest"],
  ["vienne", "ljubljana"], ["ljubljana", "zagreb"], ["zagreb", "budapest"],
  ["zagreb", "belgrade"], ["budapest", "belgrade"], ["cracovie", "lviv"],

  // ---- Europe de l'Est ----
  ["brest-litovsk", "minsk"], ["minsk", "kyiv"], ["lviv", "kyiv"],
  ["kyiv", "kharkiv"], ["kyiv", "odessa"], ["odessa", "dnipro"],
  ["dnipro", "kharkiv"], ["odessa", "bucarest"], ["lviv", "budapest"],

  // ---- Balkans et Orient ----
  ["belgrade", "sarajevo"], ["belgrade", "sofia"], ["belgrade", "bucarest"],
  ["sarajevo", "split"], ["split", "zagreb"], ["sofia", "istanbul"],
  ["sofia", "thessalonique"], ["thessalonique", "athenes"],
  ["bucarest", "sofia"], ["bucarest", "istanbul"],
  ["tirana", "bari", "mer"]                               // le ferry de Durrës
];

// ------------------------------------------------------------------
// LES CORRIDORS — les gares qui composent chaque ligne.
// ------------------------------------------------------------------
// Un LIEN dit que deux hubs se font face ; un CORRIDOR dit par où l'on passe.
// L'ordre des gares est celui du trajet, de `de` vers `vers` — et le corridor
// se parcourt dans les deux sens, comme n'importe quelle ligne.
//
// Ne figurent ici que les corridors dont LES DEUX BOUTS sont déjà jouables :
// 23 sur 131. Les autres attendent que leur hub soit écrit — Nice attend
// Gênes, Kiel attend Copenhague, Rodange attend Zurich.
//
// Produit par `node tools/corridors-propose.mjs --js`, à graine fixe. Deux
// contraintes l'ont façonné, et elles se reperdent si on ne les écrit pas :
//
//   • LA COHÉRENCE DE LIGNE AVANT TOUT. Un corridor doit RESTER SUR LA MÊME
//     LIGNE réelle. Sans ce critère, Bruxelles – Luxembourg partait par le
//     Hainaut — Ath, Mons, La Louvière, Charleroi — parce que ce détour
//     plaçait huit gares au lieu de cinq et tenait sous le plafond de
//     sinuosité. Aucun voyageur ne le reconnaîtrait : on va de Bruxelles au
//     Luxembourg par Ottignies, Gembloux et Namur, sur la L161 puis la L162.
//     Les corridors y ont perdu un tiers de leurs gares et tout gagné en
//     vérité — mieux vaut cinq gares sur la vraie ligne que huit sur un
//     détour.
//
//   • LA SINUOSITÉ AVANT LA LONGUEUR. Chercher le chemin le plus long place le
//     plus de gares et donne Montpellier – Toulouse EN PASSANT PAR PARIS. On
//     filtre d'abord sur le rapport distance parcourue / distance à vol
//     d'oiseau (plafond 1,5), et l'on ne cherche le plus long qu'ensuite.
//
//   • UNE GARE, UN CORRIDOR. La couverture prime sur l'optimalité de chaque
//     ligne prise isolément : une gare dans deux corridors s'ouvrirait deux
//     fois, une gare dans aucun serait injouable.
const CORRIDORS = [
  { de: "berlin", vers: "leipzig", gares: ["halle"] },   // Halle  ×1.23
  { de: "bruxelles", vers: "cologne", gares: ["louvain", "landen", "liege"] },   // Louvain · Landen · Liège  ×1.07
  { de: "bruxelles", vers: "luxembourg", gares: ["ottignies", "namur", "marloie", "libramont", "arlon"] },   // Ottignies · Namur · Marloie · Libramont · Arlon  ×1.05
  { de: "cologne", vers: "hambourg", gares: ["dusseldorf", "duisburg", "essen", "dortmund", "munster", "osnabruck", "bremen"] },   // Düsseldorf · Duisbourg · Essen · Dortmund · Münster · Osnabrück · Brême  ×1.12
  { de: "francfort", vers: "hanovre", gares: ["kassel"] },   // Cassel  ×1.01
  { de: "francfort", vers: "nuremberg", gares: ["wurzburg"] },   // Wurtzbourg  ×1.00
  { de: "hambourg", vers: "berlin", gares: ["rostock"] },   // Rostock  ×1.36
  { de: "leipzig", vers: "nuremberg", gares: ["erfurt"] },   // Erfurt  ×1.18
  { de: "lille", vers: "bruxelles", gares: ["tournai", "ath"] },   // Tournai · Ath  ×1.04
  { de: "londres", vers: "birmingham", gares: ["leicester"] },   // Leicester  ×1.20
  { de: "londres", vers: "manchester", gares: ["peterborough", "nottingham", "derby", "crewe"] },   // Peterborough · Nottingham · Derby · Crewe  ×1.24
  { de: "luxembourg", vers: "francfort", gares: ["trier", "koblenz", "mainz"] },   // Trèves · Coblence · Mayence  ×1.20
  { de: "luxembourg", vers: "strasbourg", gares: ["bettembourg", "metz"] },   // Bettembourg · Metz  ×1.13
  { de: "manchester", vers: "edimbourg", gares: ["leeds", "carlisle"] },   // Leeds · Carlisle  ×1.16
  { de: "manchester", vers: "newcastle", gares: ["sheffield", "doncaster", "york"] },   // Sheffield · Doncaster · York  ×1.43
  { de: "marseille", vers: "montpellier", gares: ["avignon", "nimes"] },   // Avignon · Nîmes  ×1.34
  { de: "montpellier", vers: "toulouse", gares: ["narbonne"] },   // Narbonne  ×1.12
  { de: "munich", vers: "stuttgart", gares: ["augsburg", "ulm"] },   // Augsbourg · Ulm  ×1.03
  { de: "paris", vers: "bordeaux", gares: ["rouen", "caen", "le-mans", "tours", "poitiers"] },   // Rouen · Caen · Le Mans · Tours · Poitiers  ×1.45
  { de: "paris", vers: "strasbourg", gares: ["nancy"] },   // Nancy  ×1.00
  { de: "strasbourg", vers: "francfort", gares: ["karlsruhe", "mannheim"] },   // Karlsruhe · Mannheim  ×1.05
];
