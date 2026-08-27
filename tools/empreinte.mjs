// ------------------------------------------------------------------
// empreinte — ce qui, dans une fiche, change une journée générée.
// ------------------------------------------------------------------
// Partagée entre brevet.mjs (qui l'inscrit) et carte-check.mjs (qui la
// compare) : deux copies auraient fini par hacher deux choses différentes,
// et un brevet périmé serait passé pour valable.
//
// N'entrent dans l'empreinte que la géométrie (quais, portails, liaisons,
// paires même-côté) et le `gen` écrit (fondu au régime boss, joué tel quel
// hors ruban). Tagline, couleurs, descriptions : sans effet sur le jeu
// simulé, donc sans effet sur l'empreinte.
import crypto from "crypto";

function canonique(v) {
  if (Array.isArray(v)) return "[" + v.map(canonique).join(",") + "]";
  if (v && typeof v === "object")
    return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + canonique(v[k])).join(",") + "}";
  return JSON.stringify(v);
}

export function empreinte(cfg) {
  const joue = {
    platforms: cfg.platforms, portals: cfg.portals, links: cfg.links,
    sameSidePairs: cfg.sameSidePairs ?? [], gen: cfg.gen ?? null,
  };
  return crypto.createHash("sha1").update(canonique(joue)).digest("hex").slice(0, 12);
}
