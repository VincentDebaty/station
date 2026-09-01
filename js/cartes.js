"use strict";
// ------------------------------------------------------------------
// LES CARTES — où l'on joue.
// ------------------------------------------------------------------
// Une carte est un territoire fermé (l'Europe, un pays, une ville) : ses
// zones, ses hubs et ses lignes, dans un fichier JSON autonome
// (data/cartes/<id>.json). Les cartes sont des MISSIONS INDÉPENDANTES : chacune
// a sa progression, et rien de l'une ne sert à l'autre. Ce que les cartes
// partagent, c'est la bibliothèque des fiches de gares (data/stations/) : la
// même Namur peut être une gare de ligne sur deux cartes différentes.
//
// Pourquoi du JSON et non du JS comme l'ancien data/graph.js : le jeu web est
// un prototype, le moteur final (Unity ou Godot) lira les mêmes fichiers. Une
// carte ne doit rien devoir au navigateur.
//
// Ce fichier CHARGE ; il ne répond à aucune question de jeu. C'est js/ruban.js
// qui lit CARTE_COURANTE et en déduit sorties, parcours et difficultés.
// ------------------------------------------------------------------

const CARTES = [];          // l'index : { id, nom, gratuite, fichier, sousTitre }
let CARTE_COURANTE = null;  // la carte chargée : { id, nom, zones, hubs, lignes, … }

async function loadCartes() {
  const r = await fetch("data/cartes/index.json");
  if (!r.ok) throw new Error("cartes/index.json : " + r.status);
  const liste = await r.json();
  CARTES.length = 0;
  CARTES.push(...liste);
  return CARTES;
}

// Charge une carte et en fait la carte courante. Le graphe se reconstruit au
// prochain appel (js/ruban.js, resetRuban) : changer de carte, c'est changer
// de monde, et rien de l'ancien ne doit rester en mémoire.
async function loadCarte(id) {
  const entree = CARTES.find(c => c.id === id) || CARTES[0];
  if (!entree) throw new Error("aucune carte dans data/cartes/index.json");
  const r = await fetch("data/cartes/" + (entree.fichier || entree.id + ".json"));
  if (!r.ok) throw new Error("carte " + entree.id + " : " + r.status);
  CARTE_COURANTE = await r.json();
  DEFS[CARTE_COURANTE.id || entree.id] = CARTE_COURANTE;
  if (typeof resetRuban === "function") resetRuban();
  return CARTE_COURANTE;
}

// --- LES DÉFINITIONS DE TOUTES LES CARTES, gardées en mémoire ---------
// Pourquoi : les crédits sont un fait de COMPTE et non de carte (lot G,
// point 4). Le solde somme les étoiles, les chapitres d'or et les zones de
// TOUTES les cartes jouées — et compter les chapitres d'or d'une carte qu'on
// ne joue pas demande sa composition, alors que `creditsGagnes()` est
// synchrone. On charge donc tout l'index une fois, au démarrage : quelques
// kilo-octets de JSON, et plus aucune question de crédit n'est asynchrone.
const DEFS = Object.create(null);
async function precargerCartes() {
  if (!CARTES.length) await loadCartes();
  await Promise.all(CARTES.map(async e => {
    if (DEFS[e.id]) return;
    try {
      const r = await fetch("data/cartes/" + (e.fichier || e.id + ".json"));
      if (r.ok) DEFS[e.id] = await r.json();
    } catch (err) { /* une carte illisible ne doit jamais empêcher de jouer */ }
  }));
  return DEFS;
}
// La définition d'une carte par son id, ou null si elle n'a pas pu être lue.
function defDeCarte(id) {
  if (DEFS[id]) return DEFS[id];
  return CARTE_COURANTE && CARTE_COURANTE.id === id ? CARTE_COURANTE : null;
}
// Le prix en crédits d'une carte — porté par sa définition, à défaut par son
// entrée d'index. Une carte gratuite vaut zéro.
function prixDeCarte(id) {
  const d = defDeCarte(id);
  if (d && typeof d.prixCredits === "number") return d.prixCredits;
  const e = CARTES.find(c => c.id === id);
  return (e && typeof e.prixCredits === "number") ? e.prixCredits : 0;
}

// --- Lecture ---------------------------------------------------------
function carteCourante() { return CARTE_COURANTE; }
function zonesDeCarte() { return CARTE_COURANTE ? CARTE_COURANTE.zones || [] : []; }
function hubsDeCarte() { return CARTE_COURANTE ? CARTE_COURANTE.hubs || [] : []; }
function zoneById(id) { return zonesDeCarte().find(z => z.id === id) || null; }
function hubsDeZone(zoneId) { return hubsDeCarte().filter(h => h.zone === zoneId); }
// Le nom qu'on affiche au dézoom maximal — « L'Europe », « La Belgique »…
function nomDeCarte() { return CARTE_COURANTE ? CARTE_COURANTE.nom : "La carte"; }
