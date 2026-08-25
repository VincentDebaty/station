# -*- coding: utf-8 -*-
"""Génère data/cartes/europe.json depuis le ruban (tools/ruban/ruban.py).

Le ruban complet va de Cork à Istanbul (95 chapitres, 593 gares) ; la carte
LIVRÉE n'en prend qu'une tranche — celle qui est écrite. Décision du 25 août
2026 : la v1 livre les chapitres 51 à 61, Luxembourg → Hambourg, parce que
L'Ardenne est le seul chapitre écrit dont le profil puisse ouvrir une carte
(d1·2·1·3·2·5). Le reste se greffe DEVANT quand il sera écrit.

    python3 tools/ruban/export-carte.py [premier] [dernier]
"""
import sys, os, json, unicodedata
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruban import ACTES

PREMIER = int(sys.argv[1]) if len(sys.argv) > 1 else 51
DERNIER = int(sys.argv[2]) if len(sys.argv) > 2 else 61

# Les zones de la carte livrée. Elles ne sont PAS les actes du ruban complet :
# une tranche de onze chapitres se recoupe en deux régions cohérentes, et le
# découpage se refera quand le ruban s'allongera par le bout.
ZONES = [
  {"id": "rhin", "nom": "Le Benelux et le Rhin", "couleur": "#5b8def", "jusqua": 55},
  {"id": "ger",  "nom": "La Germanie",           "couleur": "#3fa87a", "jusqua": 61},
]
# Le plancher de difficulté par chapitre (§2.5) : une rampe qui monte par
# paliers le long du ruban. La difficulté voulue se calcule depuis lui, puis se
# rabat sur ce que chaque fiche peut porter (plafondDeFlux).
PLANCHER = {51:1, 52:2, 53:2, 54:3, 55:3, 56:3, 57:3, 58:4, 59:4, 60:4, 61:4}
# R9 : le premier chapitre est le tutoriel. Il finit sur Bruxelles-Midi, qui
# porterait un niveau 5 — on le plafonne à 3. La regle est ecrite au §3 du
# document ; sans ce plafond, le tutoriel arriverait au sommet du jeu six gares
# apres l'avoir ouvert.
ARRIVEE = {51: 3, 52: 4}

def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    out = "".join(c.lower() if c.isalnum() else "-" for c in s)
    while "--" in out: out = out.replace("--", "-")
    return out.strip("-")

CH = [c for a in ACTES for c in a["ch"]]
for i, c in enumerate(CH, 1): c["n"] = i

ids = set()
for p in json.load(open("data/stations/index.json")): ids.update(p["stations"])

chapitres, manquantes = [], []
for c in CH:
    if not (PREMIER <= c["n"] <= DERNIER): continue
    zone = next(z["id"] for z in ZONES if c["n"] <= z["jusqua"])
    gares = []
    for nom, fid in c["gares"]:
        gid = fid or slug(nom)
        if gid not in ids: manquantes.append((gid, nom, c["nom"]))
        gares.append(gid)
    ch = {"id": slug(c["nom"]), "nom": c["nom"], "zone": zone, "gares": gares}
    if c["n"] in PLANCHER: ch["plancher"] = PLANCHER[c["n"]]
    if c["n"] in ARRIVEE: ch["arrivee"] = ARRIVEE[c["n"]]
    if c["saut"]: ch["saut"] = {"mode": c["saut"][0], "texte": c["saut"][1]}
    chapitres.append(ch)

carte = {
  "id": "europe", "nom": "L'Europe", "gratuite": True,
  "enChantier": True,
  "note": ("Tranche livrée du ruban : chapitres %d a %d de ruban-europe.md "
           "(Luxembourg vers Hambourg). Le ruban complet va de Cork a Istanbul ; "
           "les actes I a IV se greffent DEVANT celui-ci quand ils seront ecrits." % (PREMIER, DERNIER)),
  "echelle": {"kmMinEntreHubs": 110},
  "zones": [{k: z[k] for k in ("id", "nom", "couleur")} for z in ZONES],
  "chapitres": chapitres,
}
json.dump(carte, open("data/cartes/europe.json", "w"), ensure_ascii=False, indent=1)

n = sum(len(c["gares"]) for c in chapitres)
print("data/cartes/europe.json : %d chapitres, %d gares, %d zones"
      % (len(chapitres), n, len(carte["zones"])))
print("fiches manquantes : %d" % len(manquantes))
for gid, nom, ch in manquantes: print("   %-16s %-16s (%s)" % (gid, nom, ch))
