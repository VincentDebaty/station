# -*- coding: utf-8 -*-
import sys, json, collections, io
sys.path.insert(0,"/private/tmp/claude-501/-Users-vincentdebaty-Documents-dev-games-Station/77d22f41-47a7-4fad-a3ee-cb68a8fa3043/scratchpad")
from ruban import ACTES
EX=set(); PAYS={}
for p in json.load(open('data/stations/index.json')):
    EX.update(p['stations'])
    for s in p['stations']: PAYS[s]=p['country']
CH=[c for a in ACTES for c in a['ch']]
used=set(i for c in CH for _,i in c['gares'] if i)
tot=sum(len(c['gares']) for c in CH)
o=[]
W=o.append

W("# Le ruban d'Europe — le tracé complet")
W("")
W("> Écrit le 25 août 2026, après la décision de faire de la carte un **ruban**")
W("> (`meta-progression-jeu-aiguillage.md` §0) et la règle R6 « on ne refait")
W("> jamais la même ligne ». Ce document **est** le contenu de la carte Europe :")
W("> l'ordre des chapitres, leurs noms, et la liste des gares dans l'ordre du rail.")
W("> Il alimente le lot C (les données) et le lot F (l'écriture des fiches).")
W("")
W("## Ce que c'est")
W("")
W("Un seul fil, de **Cork à Istanbul**, sans embranchement et sans choix. Le joueur")
W("part de la pointe sud-ouest de l'Irlande et arrive au Bosphore ; entre les deux,")
W("il traverse l'Europe une fois, dans un ordre écrit d'avance, en franchissant")
W("neuf actes et huit ruptures de continuité.")
W("")
W("Le voyage n'est pas une ligne droite : c'est une **spirale**. Les Îles, puis la")
W("France atlantique, la boucle ibérique, le Midi et l'Italie jusqu'à la Sicile,")
W("la remontée par le Pô et les Alpes, le Rhin et la Germanie, le Nord jusqu'au")
W("golfe de Finlande, la Baltique et la Bohême, enfin les Balkans et l'Orient.")
W("Chaque région est traversée **une fois**, et on n'y revient jamais.")
W("")
W("| | |")
W("|---|---|")
W("| Actes | **%d** |" % len(ACTES))
W("| Chapitres | **%d** |" % len(CH))
W("| Gares — c'est-à-dire **niveaux** | **%d** |" % tot)
W("| Fiches déjà écrites, réemployées telles quelles | **%d** |" % len(used))
W("| Fiches à écrire | **%d** |" % (tot-len(used)))
W("| Sauts déclarés (§4 bis) | **%d** |" % sum(1 for c in CH if c['saut']))
W("| Longueur des chapitres | 5 à 9 gares, médiane 6 |")
W("")
W("**Vérifié par script** (`scratchpad/verif.py`, à porter dans `carte-check` au")
W("lot C) : les %d chapitres tiennent tous R3 (5 à 10 gares), aucune gare" % len(CH))
W("n'apparaît deux fois (R6), le chaînage est continu d'un bout à l'autre, et")
W("les %d fiches annoncées comme existantes existent bien au catalogue." % len(used))
W("")
W("## Comment lire les tableaux")
W("")
W("- Les gares sont **dans l'ordre du rail**, de gauche à droite. La **dernière,")
W("  en gras, est la grande gare** qui ferme le chapitre.")
W("- ✓ = la fiche existe déjà dans `data/stations/`. Sans marque = **à écrire**.")
W("- Un chapitre précédé d'un bandeau *Saut* commence par une rupture de")
W("  continuité déclarée : bateau, train de nuit, ou correspondance.")
W("- **Après un saut, la ville d'arrivée est jouée comme première gare du")
W("  chapitre suivant** — sauf si elle a déjà été jouée, auquel cas elle n'est")
W("  qu'un point de départ. C'est ce qui évite qu'un débarquement n'échappe au")
W("  ruban.")
W("")
W("> ⚠️ **Les listes de gares sont des propositions de tracé, pas des fiches.**")
W("> Chaque gare à écrire doit encore passer le §0 de `tools/AUTHORING-STATIONS.md`")
W("> — **au moins 3 directions réelles et 3-4 quais**. Une candidate qui n'a que")
W("> deux directions ne s'invente pas : on prend la gare voisine, ou on redécoupe")
W("> le chapitre (voir [[r3-contre-plancher-trois-directions]] : Sète et Bar-le-Duc")
W("> ont déjà été refusées pour cette raison).")
W("")
W("---")
W("")

num=0
for a in ACTES:
    n_g=sum(len(c['gares']) for c in a['ch'])
    n_ex=sum(1 for c in a['ch'] for _,i in c['gares'] if i)
    W("## %s" % a['nom'])
    W("")
    W("*%s* — %d chapitres, **%d gares** (%d déjà écrites, %d à écrire)."
      % (a['sous'], len(a['ch']), n_g, n_ex, n_g-n_ex))
    W("")
    W("| # | Chapitre | Gares, dans l'ordre du rail | n |")
    W("|---|---|---|---|")
    for c in a['ch']:
        num+=1
        if c['saut']:
            mode,txt=c['saut']
            W("| | ⤳ **Saut (%s)** | *%s* | |" % (mode,txt))
        gs=[]
        for k,(nom,fid) in enumerate(c['gares']):
            t = nom + (" ✓" if fid else "")
            if k==len(c['gares'])-1: t="**"+nom+"**"+(" ✓" if fid else "")
            gs.append(t)
        W("| %d | %s | %s | %d |" % (num, c['nom'], " · ".join(gs), len(c['gares'])))
    W("")

W("---")
W("")
W("## Les huit sauts")
W("")
W("Il n'existe pas de parcours continu qui traverse toute l'Europe sans repasser")
W("nulle part (pas de parcours hamiltonien — mesuré au lot 2). Le ruban assume")
W("donc huit ruptures, toutes **entre deux chapitres**, jamais à l'intérieur (R5),")
W("et toutes **montrées** au joueur.")
W("")
W("| # | Saut | Mode | Pourquoi il est là |")
W("|---|---|---|---|")
SAUTS=[("Belfast → Cairnryan","mer","L'Irlande est une île et le ruban doit rejoindre l'Écosse."),
 ("Penzance → Bristol","nuit","La Cornouailles est un cul-de-sac : on n'en sort qu'en refaisant la voie. Le Night Riviera existe pour ça."),
 ("Palerme → Naples","nuit","La Sicile est un cul-de-sac. Le train de nuit reprend le ferry de Messine dans l'autre sens."),
 ("Bergen → Oslo","nuit","Le Bergensbanen ne va nulle part au-delà de Bergen."),
 ("Stockholm → Turku","mer","Aucune voie ne fait le tour du golfe de Botnie à une longueur acceptable (R7 : sinuosité 4,5)."),
 ("Helsinki → Tallinn","mer","Deux heures de golfe, aucun rail."),
 ("Split → Ploče","mer","La voie Split–Sarajevo par Knin et Bihać n'est plus exploitée ; la ligne réelle vers Mostar part de Ploče."),
 ("Athènes → Thessalonique","nuit","La Grèce continentale est une impasse ferroviaire vers le sud.")]
for i,(s,m,w) in enumerate(SAUTS,1): W("| %d | %s | %s | %s |" % (i,s,m,w))
W("")
W("Chaque saut est **une transition, jamais une punition ni une récompense** :")
W("une animation de trajet sur la carte, une phrase, et un geste pour passer.")
W("")

# réserve
reserve=sorted(EX-used, key=lambda i:(PAYS[i],i))
W("## Ce qui reste en réserve")
W("")
W("### Les %d fiches déjà écrites que le ruban ne traverse pas" % len(reserve))
W("")
W("Elles ne sont pas perdues : ce sont les gares d'**allongement** — le ruban")
W("s'étend par le bout, ou un chapitre se redécoupe pour les prendre.")
W("")
bypays=collections.defaultdict(list)
for i in reserve: bypays[PAYS[i]].append(i)
for p in sorted(bypays):
    W("- **%s** (%d) : %s" % (p, len(bypays[p]), ", ".join(bypays[p])))
W("")
W("### Les grandes gares laissées de côté")
W("")
W("- **Tirana.** L'Albanie n'a plus de service voyageurs digne d'un niveau, et")
W("  son seul lien crédible est le ferry de Bari. Écartée **volontairement** :")
W("  un jeu « ancré dans la géographie ferroviaire réelle » ne s'invente pas un")
W("  réseau. À reprendre si la ligne Durrës–Tirana rouvre.")
W("- **Les branches non parcourues** de villes traversées : Newcastle–Londres par")
W("  la côte Est, Paris–Lyon, Paris–Strasbourg, Bordeaux–Bilbao par la côte,")
W("  Montpellier–Toulouse, Cologne–Hambourg par la Ruhr, Hanovre–Berlin,")
W("  Munich–Vienne, Berlin–Prague, Venise–Ljubljana, Zurich–Milan,")
W("  Göteborg–Stockholm, Varsovie–Cracovie… Une trentaine de tracés réels")
W("  entièrement disponibles pour la version 2 du ruban.")
W("")
io.open('ruban-europe.md','w',encoding='utf-8').write("\n".join(o))
print("écrit : ruban-europe.md (%d lignes)" % len(o))
