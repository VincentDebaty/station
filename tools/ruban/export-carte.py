# -*- coding: utf-8 -*-
"""Génère data/cartes/europe.json depuis le ruban (tools/ruban/ruban.py).

Le ruban complet va de Cork à Istanbul (95 chapitres, 593 gares) ; la carte
LIVRÉE n'en prend qu'une tranche — celle qui est écrite. Décision du 25 août
2026 : la v1 livrait les chapitres 51 à 61, Luxembourg → Hambourg, parce que
L'Ardenne était le seul chapitre écrit dont le profil puisse ouvrir une carte.

ÉTENDU le 27 août 2026 : l'acte V est complet, la carte prend donc ses quinze
chapitres, de Bussoleno à Hambourg. Le Fréjus et le Bugey ouvre désormais le
jeu — Bussoleno a quatre quais et trois directions, elle se joue en 1, et
l'arrivée sur Genève est plafonnée à 3 comme l'exige R9.

    python3 tools/ruban/export-carte.py [premier] [dernier]
"""
import sys, os, json, unicodedata
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruban import ACTES

PREMIER = int(sys.argv[1]) if len(sys.argv) > 1 else 45
DERNIER = int(sys.argv[2]) if len(sys.argv) > 2 else 60

# Les zones de la carte livrée. Elles ne sont PAS les actes du ruban complet :
# une tranche de onze chapitres se recoupe en deux régions cohérentes, et le
# découpage se refera quand le ruban s'allongera par le bout.
ZONES = [
  {"id": "alpes", "nom": "Le Piémont, les Alpes et la Lorraine", "couleur": "#c084fc", "jusqua": 49},
  {"id": "rhin",  "nom": "Le Benelux et le Rhin",    "couleur": "#5b8def", "jusqua": 54},
  {"id": "ger",   "nom": "La Germanie",              "couleur": "#3fa87a", "jusqua": 60},
]
# Le plancher de difficulté par chapitre (§2.5) : une rampe qui monte par
# paliers le long du ruban. La difficulté voulue se calcule depuis lui, puis se
# rabat sur ce que chaque fiche peut porter (plafondDeFlux).
# Renumérotés le 27 août 2026 après la fusion des chapitres 46 et 47, et
# ÉTENDUS : la carte livrée commence désormais au Fréjus et non plus à
# L'Ardenne, l'acte V étant complet. Quinze chapitres au lieu de onze.
PLANCHER = {45:1, 46:2, 47:2, 48:2, 49:2, 50:3, 51:3, 52:3, 53:3, 54:3,
            55:4, 56:4, 57:4, 58:4, 59:4, 60:4}
# R9 : le premier chapitre est le tutoriel. Il finit sur Bruxelles-Midi, qui
# porterait un niveau 5 — on le plafonne à 3. La regle est ecrite au §3 du
# document ; sans ce plafond, le tutoriel arriverait au sommet du jeu six gares
# apres l'avoir ouvert.
ARRIVEE = {45: 3, 46: 4, 47: 4}

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
  "note": ("Tranche livree du ruban : chapitres %d a %d de ruban-europe.md "
           "(Bussoleno vers Hambourg) — l'acte V en entier. Le ruban complet va "
           "de Cork a Istanbul ; les actes I a IV se greffent DEVANT celui-ci "
           "quand ils seront ecrits." % (PREMIER, DERNIER)),
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
