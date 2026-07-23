"use strict";
// ------------------------------------------------------------------
// Web Worker — génération d'horaire HORS thread principal.
//
// Sur une grosse gare, generateSchedule() (simulation d'un « joueur parfait »
// pour garantir le zéro retard possible) peut prendre plusieurs secondes. Le
// faire ici évite de figer l'écran au lancement / au rejeu.
//
// On réutilise tels quels le moteur (géométrie, chemins, conflits) et le
// générateur : engine.js est neutre vis-à-vis du DOM (l'accès au board y est
// gardé), schedule.js est du calcul pur. Le worker reçoit une fiche de gare,
// reconstruit le réseau (loadStation) puis renvoie la journée générée.
// ------------------------------------------------------------------
importScripts("engine.js", "schedule.js");

self.onmessage = e => {
  const { id, cfg } = e.data || {};
  try {
    loadStation(cfg);            // même réseau que le thread principal (déterministe)
    const day = generateSchedule();
    self.postMessage({ id, schedule: day.schedule, events: day.events });
  } catch (err) {
    self.postMessage({ id, error: String(err && err.message || err) });
  }
};
