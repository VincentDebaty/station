# -*- coding: utf-8 -*-
import sys, json, collections
# Le chemin pointait vers le scratchpad d'une session de août 2026, disparu
# depuis. On lit ruban.py là où il vit : à côté de ce fichier.
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruban import ACTES
EX=set()
for pays in json.load(open('data/stations/index.json')): EX.update(pays['stations'])
CH=[c for a in ACTES for c in a['ch']]
pb=[]
# R3
for c in CH:
    n=len(c['gares'])
    if not (5<=n<=10): pb.append("R3 %s : %d gares" % (c['nom'],n))
# chaînage
for i in range(1,len(CH)):
    if CH[i]['de']!=CH[i-1]['vers']: pb.append("chaînage : %s (%s) après %s" % (CH[i]['nom'],CH[i]['de'],CH[i-1]['vers']))
# R6 : aucune gare deux fois
noms=collections.Counter(n for c in CH for n,_ in c['gares'])
for n,k in noms.items():
    if k>1: pb.append("R6 doublon : %s ×%d" % (n,k))
# fiches annoncées existantes
ids=[i for c in CH for _,i in c['gares'] if i]
for i in ids:
    if i not in EX: pb.append("fiche annoncée absente du catalogue : "+i)
d=collections.Counter(ids)
for i,k in d.items():
    if k>1: pb.append("fiche employée deux fois : %s ×%d" % (i,k))
print("chapitres %d · gares %d · fiches déjà écrites %d · à écrire %d"
      % (len(CH), sum(len(c['gares']) for c in CH), len(ids), sum(len(c['gares']) for c in CH)-len(ids)))
print("longueurs :", dict(sorted(collections.Counter(len(c['gares']) for c in CH).items())))
print("sauts :", sum(1 for c in CH if c['saut']))
print("catalogue employé %d / %d fiches" % (len(set(ids)), len(EX)))
print()
print(("PROBLÈMES (%d) :"%len(pb)) if pb else "aucun problème")
for x in pb[:40]: print("  ·",x)
