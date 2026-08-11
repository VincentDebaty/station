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
// gare jouable (« namur »), soit la clé d'un lieu de data/places.js (« arlon »).
// js/network.js en tire les arêtes : chaque paire CONSÉCUTIVE, et rien d'autre.
// Namur–Libramont, Libramont–Arlon, Arlon–Luxembourg — jamais Namur–Luxembourg.
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
  { id: "L50A", name: "Ostende – Bruges – Gand – Bruxelles",
    nodes: ["ostende", "bruges", "gand", "bruxelles-midi"] },
  { id: "L51",  name: "Bruges – Blankenberge",  nodes: ["bruges", "blankenberge"] },
  { id: "L51A", name: "Bruges – Knokke",        nodes: ["bruges", "knokke"] },
  { id: "L58",  name: "Gand – Eeklo",           nodes: ["gand", "eeclo"] },
  { id: "L75",  name: "Gand – Courtrai",        nodes: ["gand", "courtrai"] },
  { id: "L59",  name: "Gand – Anvers",          nodes: ["gand", "anvers"] },
  { id: "L60",  name: "Gand – Termonde – Malines", nodes: ["gand", "termonde", "malines"] },

  // ---- Anvers et la Campine --------------------------------------------
  { id: "L25",  name: "Bruxelles – Malines – Anvers",
    nodes: ["bruxelles-midi", "malines", "anvers"] },
  { id: "L12",  name: "Anvers – Essen (frontière néerlandaise)", nodes: ["anvers", "essen"] },
  { id: "L15",  name: "Anvers – Lier – Hasselt", nodes: ["anvers", "lier", "hasselt"] },

  // ---- Axe Bruxelles – Liège et le Limbourg ----------------------------
  { id: "L36",  name: "Bruxelles – Louvain – Liège",
    nodes: ["bruxelles-midi", "louvain", "liege"] },
  { id: "L35",  name: "Louvain – Aarschot – Hasselt", nodes: ["louvain", "aarschot", "hasselt"] },
  { id: "L21",  name: "Hasselt – Genk",         nodes: ["hasselt", "genk"] },
  { id: "L34",  name: "Hasselt – Liège",        nodes: ["hasselt", "liege"] },
  { id: "L36C", name: "Liège – Liers",          nodes: ["liege", "liers"] },
  { id: "L37",  name: "Liège – Aachen (frontière allemande)", nodes: ["liege", "aachen"] },
  { id: "L40",  name: "Liège – Maastricht (frontière néerlandaise)", nodes: ["liege", "maastricht"] },

  // ---- Brabant wallon et sillon Sambre-et-Meuse ------------------------
  { id: "L161", name: "Bruxelles – Ottignies – Namur",
    nodes: ["bruxelles-midi", "ottignies", "namur"] },
  { id: "L140", name: "Ottignies – Charleroi",  nodes: ["ottignies", "charleroi"] },
  { id: "L124", name: "Bruxelles – Charleroi",  nodes: ["bruxelles-midi", "charleroi"] },
  { id: "L130", name: "Charleroi – Namur",      nodes: ["charleroi", "namur"] },
  { id: "L132", name: "Charleroi – Couvin",     nodes: ["charleroi", "couvin"] },
  { id: "L118", name: "Charleroi – Mons",       nodes: ["charleroi", "mons"] },
  { id: "L125", name: "Namur – Liège",          nodes: ["namur", "liege"] },
  { id: "L154", name: "Namur – Dinant",         nodes: ["namur", "dinant"] },

  // ---- Ardenne et Luxembourg -------------------------------------------
  // L'exemple qui a motivé ce fichier : la relation Bruxelles – Luxembourg
  // n'est PAS une arête, c'est un parcours le long de cette ligne.
  { id: "L162", name: "Namur – Libramont – Arlon – Luxembourg",
    nodes: ["namur", "libramont", "arlon", "luxembourg"] },
  { id: "L165", name: "Libramont – Bertrix",    nodes: ["libramont", "bertrix"] },

  // ---- Hainaut ----------------------------------------------------------
  { id: "L96",  name: "Bruxelles – Mons – Quévy (frontière française)",
    nodes: ["bruxelles-midi", "mons", "quevy"] },
  { id: "L97",  name: "Mons – Quiévrain",       nodes: ["mons", "quievrain"] },
  { id: "L78",  name: "Mons – Tournai",         nodes: ["mons", "tournai"] },
  { id: "L94",  name: "Tournai – Ath – Bruxelles", nodes: ["tournai", "bruxelles-midi"] },
  { id: "L75B", name: "Tournai – Courtrai",     nodes: ["tournai", "courtrai"] },
  { id: "L94F", name: "Tournai – Lille (frontière française)", nodes: ["tournai", "lille"] }
];
