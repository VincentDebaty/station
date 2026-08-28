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

PREMIER = int(sys.argv[1]) if len(sys.argv) > 1 else 31
DERNIER = int(sys.argv[2]) if len(sys.argv) > 2 else 57

# Les zones de la carte livrée. Elles ne sont PAS les actes du ruban complet :
# une tranche de onze chapitres se recoupe en deux régions cohérentes, et le
# découpage se refera quand le ruban s'allongera par le bout.
ZONES = [
  {"id": "alpes", "nom": "L'arc méditerranéen et les Alpes", "couleur": "#c084fc", "jusqua": 46},
  {"id": "rhin",  "nom": "Le Benelux et le Rhin",    "couleur": "#5b8def", "jusqua": 51},
  {"id": "ger",   "nom": "La Germanie",              "couleur": "#3fa87a", "jusqua": 57},
]
# Le plancher de difficulté par chapitre (§2.5) : une rampe qui monte par
# paliers le long du ruban. La difficulté voulue se calcule depuis lui, puis se
# rabat sur ce que chaque fiche peut porter (plafondDeFlux).
# Renumérotés le 27 août 2026 après la fusion des chapitres 46 et 47, et
# ÉTENDUS : la carte livrée commence désormais au Fréjus et non plus à
# L'Ardenne, l'acte V étant complet. Quinze chapitres au lieu de onze.
PLANCHER = {31:1, 32:2, 33:2, 34:2, 35:2, 36:2, 37:2, 38:2, 39:2, 40:2, 41:2, 42:2, 43:2, 44:2, 45:2, 46:2, 47:3, 48:3, 49:3, 50:3, 51:3,
            52:4, 53:4, 54:4, 55:4, 56:4, 57:4}
# R9 : le premier chapitre est le tutoriel. Il finit sur Bruxelles-Midi, qui
# porterait un niveau 5 — on le plafonne à 3. La regle est ecrite au §3 du
# document ; sans ce plafond, le tutoriel arriverait au sommet du jeu six gares
# apres l'avoir ouvert.
ARRIVEE = {31: 3, 32: 4, 33: 4, 34: 4, 35: 4, 36: 4, 37: 4, 38: 4, 39: 4, 40: 4, 41: 4, 42: 4, 43: 4, 44: 4}
# R7 : deux chapitres du Mezzogiorno ASSUMENT une sinuosité au-dessus de 1,5 —
# le rail y fait réellement le tour de la botte avant le détroit (mesuré 1,73)
# et la diagonale de Lucanie plonge par la côte ionienne (1,62). Décision du
# 28 août 2026 : l'exception se DÉCLARE, chapitre par chapitre, et carte-check
# vérifie contre la valeur déclarée — le seuil de 1,5 reste la règle partout
# ailleurs. Une exception non déclarée reste un refus.
SINUOSITE = {37: 1.75, 38: 1.65}

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
    if c["n"] in SINUOSITE: ch["sinuosite"] = SINUOSITE[c["n"]]
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
