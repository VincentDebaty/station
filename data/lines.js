"use strict";
// ------------------------------------------------------------------
// LIGNES DE CHEMIN DE FER RÉELLES — la topologie du réseau de la carte.
//
// Pourquoi ce fichier existe : les `portals` d'une fiche sont des DESTINATIONS,
// pas des voisins. « Namur → LUXEMBOURG » désigne un train qui roule par
// Libramont et Arlon ; en déduire une arête Namur–Luxembourg dessinait une corde
// droite à travers l'Ardenne, et multipliait les traits qui ne correspondent à
// aucune voie. Un réseau ferré ne se décrit pas par des couples origine ↔
// destination mais par des LIGNES : une suite ordonnée de points desservis.
//
// Une ligne = { id, name, nodes: [...] }, où chaque nœud est soit l'id d'une
// gare jouable (« namur »), soit la clé d'un POINT DE PASSAGE de data/places.js
// (« ciney »), qui donne au trait la forme de la voie sans se dessiner lui-même.
// js/network.js en tire les arêtes : chaque paire CONSÉCUTIVE, et rien d'autre.
// Namur–Ciney, Ciney–Marloie, Marloie–Libramont — jamais Namur–Libramont.
//
// On ne décrit QUE ce qui relie des gares jouables. Une antenne vers un
// cul-de-sac (Bruges–Ostende, Hasselt–Genk, Herentals–Turnhout) n'est pas une
// ligne de ce fichier : ces destinations existent sur le gril, pas sur la carte
// (tools/AUTHORING-STATIONS.md §0). Un trait qui s'arrête dans le vide est
// exactement ce qu'on cherche à éviter.
//
// Règle de préséance (js/network.js) : elle s'applique PAR PAYS, via
// LINE_COUNTRIES ci-dessous. Un pays qui y figure tient toute sa topologie des
// lignes ; les autres gardent la déduction par portails en attendant les leurs.
//
// Pourquoi par pays et non par gare : Lille apparaît au bout de la L94F, sans
// qu'aucune de ses lignes françaises ne soit écrite. La traiter comme « décrite »
// lui retirait ses portails, donc toutes ses relations françaises — elle devenait
// un cul-de-sac, et la France se retrouvait coupée de la Belgique.
//
// `id` reprend le numéro de ligne de l'infrastructure (L50A, L162…) : c'est la
// façon la plus courte de retrouver la source si un tracé est contesté.
// ------------------------------------------------------------------

// Pays dont la topologie vient des LIGNES. Ajouter un pays ici en même temps
// que ses lignes, jamais avant : sans elles, ses gares n'auraient plus aucune
// arête.
const LINE_COUNTRIES = ["🇧🇪 Belgique"];

const LINES = [
  // ---- Flandre occidentale et orientale --------------------------------
  { id: "L50A", name: "Bruges – Gand",            nodes: ["bruges", "aalter", "gand"] },
  { id: "L50",  name: "Gand – Alost – Denderleeuw – Bruxelles",
    nodes: ["gand", "alost", "denderleeuw", "bruxelles-midi"] },
  { id: "L66",  name: "Bruges – Roulers – Courtrai", nodes: ["bruges", "roulers", "courtrai"] },
  { id: "L75",  name: "Gand – Deinze – Courtrai – Mouscron",
    nodes: ["gand", "deinze", "waregem", "courtrai", "mouscron"] },
  { id: "L75A", name: "Mouscron – Tournai",       nodes: ["mouscron", "herseaux", "tournai"] },
  { id: "L75F", name: "Mouscron – Lille (frontière française)", nodes: ["mouscron", "lille"] },
  { id: "L89",  name: "Courtrai – Audenarde – Zottegem – Denderleeuw",
    nodes: ["courtrai", "anzegem", "audenarde", "zottegem", "denderleeuw"] },
  { id: "L86",  name: "Audenarde – De Pinte – Gand", nodes: ["audenarde", "depinte", "gand"] },

  // ---- Pays de Waes, Dendre et Escaut -----------------------------------
  { id: "L59",  name: "Gand – Lokeren – Saint-Nicolas – Anvers",
    nodes: ["gand", "lokeren", "niklaas", "anvers"] },
  { id: "L53",  name: "Gand – Termonde – Malines – Louvain",
    nodes: ["gand", "schellebelle", "termonde", "malines", "haacht", "louvain"] },
  { id: "L57",  name: "Lokeren – Termonde – Alost – Denderleeuw",
    nodes: ["lokeren", "termonde", "alost", "denderleeuw"] },
  { id: "L60",  name: "Termonde – Opwijk – Bruxelles", nodes: ["termonde", "opwijk", "bruxelles-midi"] },
  { id: "L52",  name: "Termonde – Puurs – Anvers",  nodes: ["termonde", "puurs", "anvers"] },

  // ---- Anvers et la Campine --------------------------------------------
  { id: "L25",  name: "Bruxelles – Malines – Anvers",
    nodes: ["bruxelles-midi", "vilvorde", "malines", "anvers"] },
  { id: "L15",  name: "Anvers – Lierre – Herentals", nodes: ["anvers", "lier", "herentals"] },
  { id: "L13",  name: "Malines – Kontich – Lierre",  nodes: ["malines", "kontich", "lier"] },
  { id: "L16",  name: "Lierre – Aarschot",           nodes: ["lier", "aarschot"] },

  // ---- Axe Bruxelles – Liège et le Limbourg ----------------------------
  { id: "L36",  name: "Bruxelles – Louvain – Landen – Liège",
    nodes: ["bruxelles-midi", "louvain", "tirlemont", "landen", "waremme", "liege"] },
  { id: "L35",  name: "Louvain – Aarschot – Hasselt", nodes: ["louvain", "aarschot", "hasselt"] },
  { id: "L21",  name: "Landen – Hasselt",            nodes: ["landen", "hasselt"] },
  { id: "L34",  name: "Hasselt – Tongres – Liège",   nodes: ["hasselt", "tongres", "liege"] },
  { id: "L43",  name: "Liège – Rivage – Marloie",    nodes: ["liege", "rivage", "marloie"] },

  // ---- Brabant wallon et sillon Sambre-et-Meuse ------------------------
  { id: "L161", name: "Bruxelles – Ottignies – Namur",
    nodes: ["bruxelles-midi", "ottignies", "namur"] },
  { id: "L139", name: "Louvain – Ottignies",         nodes: ["louvain", "ottignies"] },
  { id: "L140", name: "Ottignies – Fleurus – Charleroi", nodes: ["ottignies", "fleurus", "charleroi"] },
  { id: "L124", name: "Bruxelles – Nivelles – Charleroi",
    nodes: ["bruxelles-midi", "nivelles", "charleroi"] },
  { id: "L130", name: "Charleroi – Namur",           nodes: ["charleroi", "namur"] },
  { id: "L125", name: "Namur – Huy – Liège",         nodes: ["namur", "huy", "liege"] },
  { id: "L154", name: "Namur – Dinant",              nodes: ["namur", "dinant"] },

  // ---- Ardenne et Luxembourg -------------------------------------------
  // L'exemple qui a motivé ce fichier : la relation Bruxelles – Luxembourg
  // n'est PAS une arête, c'est un parcours le long de cette ligne.
  { id: "L162", name: "Namur – Ciney – Marloie – Libramont – Arlon",
    nodes: ["namur", "ciney", "marloie", "libramont", "arlon"] },
  { id: "L166", name: "Dinant – Bertrix – Libramont", nodes: ["dinant", "bertrix", "libramont"] },

  // ---- Hainaut ----------------------------------------------------------
  { id: "L96",  name: "Bruxelles – Braine-le-Comte – Mons",
    nodes: ["bruxelles-midi", "hal", "braine", "soignies", "mons"] },
  { id: "L116", name: "Bruxelles – Braine-le-Comte – Manage – La Louvière",
    nodes: ["bruxelles-midi", "hal", "braine", "manage", "lalouviere"] },
  { id: "L112", name: "La Louvière – Charleroi",     nodes: ["lalouviere", "charleroi"] },
  { id: "L118", name: "La Louvière – Mons",          nodes: ["lalouviere", "mons"] },
  { id: "L78",  name: "Mons – Saint-Ghislain – Tournai", nodes: ["mons", "ghislain", "tournai"] },
  { id: "L90",  name: "Denderleeuw – Grammont – Ath – Jurbise – Mons",
    nodes: ["denderleeuw", "grammont", "ath", "jurbise", "mons"] },
  { id: "L94",  name: "Bruxelles – Ath – Tournai",
    nodes: ["bruxelles-midi", "hal", "enghien", "ath", "leuze", "tournai"] },
  { id: "L94F", name: "Tournai – Lille (frontière française)", nodes: ["tournai", "lille"] }
];
