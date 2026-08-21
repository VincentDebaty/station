# Créer une carte (procédure)

Une carte est une **mission indépendante** : un territoire (continent, pays,
ville) de 20 hubs et 50 lignes au moins, découpé en zones, dont chaque ligne
compte 4 à 9 gares entre deux hubs. Les règles sont dans
`meta-progression-jeu-aiguillage.md` §3 ; l'outil qui les mesure est
`node tools/carte-check.mjs`. Cette page dit **dans quel ordre** faire les
choses, et ce qui a déjà été mesuré pour qu'on ne le remesure pas.

Une fiche de gare s'écrit selon `tools/AUTHORING-STATIONS.md` — ici on ne parle
que de la carte qui les relie.

## 0. Le fichier

`data/cartes/<id>.json`, listé dans `data/cartes/index.json`. Schéma et
exemple : `data/cartes/README.md`. Trois listes : `zones`, `hubs`, `lignes`.
Une ligne = `{ de, vers, gares: [ids de fiches, de de vers vers] }`. Les
fiches sont une **bibliothèque partagée** : une carte y puise par id, et la
même gare peut servir sur deux cartes.

## 1. Choisir les hubs (avant toute ligne)

Trois mesures ont fixé la méthode sur l'Europe, elles valent pour toute carte :

1. **Un hub est un croisement.** La difficulté d'une gare EST la taille de son
   croisement (d1 : 3,9 directions / 4,6 quais ; d5 : 6,4 / 9,8). On ne promeut
   pas une petite gare en hub — on choisit les grandes gares réelles, celles
   qui ont plusieurs directions d'approche et beaucoup de voies.
2. **Il faut de la place entre deux hubs.** Quatre à neuf gares entre deux
   hubs supposent une distance : sur l'Europe, 250 à 400 km, et **110 km au
   minimum** (`echelle.kmMinEntreHubs`) — en dessous, le hub est redondant.
   Sur une carte « pays » ou « ville », fixer cette échelle d'abord, et s'y
   tenir.
3. **Chaque hub doit pouvoir avoir 3 sorties** réelles (trois lignes
   ferroviaires qui en partent vers trois autres hubs). Un hub qui n'en aura
   jamais trois n'entre pas ; un hub dont la troisième viendra d'une zone
   livrée plus tard entre, et `carte-check --livrable` le tolère en
   attendant.

Cible : **20 hubs au minimum**, deux rangs — continental (`rang: 1`, 4 à 6
sorties) et régional (`rang: 2`, 3 sorties). Coordonnées `ll` réelles : elles
servent aux mesures, pas à l'affichage.

## 2. Découper en zones

**7 à 13 hubs par zone, au moins deux zones.** Les zones s'équilibrent en
durée : une zone deux fois plus longue à finir qu'une autre se sent (sur
l'Europe, on a COMBLÉ les zones creuses plutôt que rogné les pleines). Une zone
n'est pas une porte : on y arrive par une ligne, via un hub-porte. Prévoir ces
hubs-portes aux frontières de zones — ce sont eux qui porteront les extensions.

## 3. Tracer les lignes

- **50 lignes au minimum** sur la carte finie. Compter une ligne par tracé
  entre deux hubs, quel que soit le sens.
- Une ligne suit **une ligne réelle** : sinuosité ≤ 1,5 × le vol d'oiseau, et
  on ne change pas de ligne ferroviaire en route si l'on peut l'éviter
  (Bruxelles – Luxembourg passe par Namur, pas par le Hainaut).
- Ordonner `gares` de `de` vers `vers`, dans l'ordre du rail. `de` est
  l'origine réelle : c'est depuis elle que la ligne se lit à l'écran.
- **Une gare, une ligne** (R6). Si une gare réelle est sur deux tracés,
  choisir celui dont elle est le plus « la ligne de », et laisser l'autre
  sans elle.
- Une traversée sans rail (ferry, tunnel) se marque `type: "mer"` et ne porte
  pas de gares.

## 4. Remplir les lignes — d'où partent les fiches

```bash
node tools/carte-check.mjs --livrable=<zones> --detail
```

Pour chaque ligne trop courte, le rapport donne **les gares réelles que la
voie traverse** (points de passage de `data/lines.js` / `data/places.js` sans
fiche) et les gares du catalogue qu'aucune ligne ne tient. C'est la liste de
départ. Quand il dit « pas de tracé dans data/lines.js », écrire d'abord la
ligne réelle dans `data/lines.js` (la topologie du pays en dépend), puis
relancer.

Pour chaque gare candidate, vérifier le **plancher de jouabilité** (≥ 3
directions, 3-4 quais) avant d'écrire : une gare de passage à deux directions
ne fait pas un niveau, même si la ligne a besoin d'un point. Si la voie n'offre
pas assez de croisements, la ligne sera courte — et c'est la carte qu'on
ajuste (un hub de plus, un tracé différent), pas la gare qu'on gonfle.

**Rampe** : la difficulté d'une gare se déduit de sa position (js/graph.js),
mais sa géométrie la plafonne (`plafondDeFlux` : 3 quais → 2, 4 → 3, 5-6 → 4).
Près d'un hub continental, il faut des gares à 5 quais et plus. `carte-check`
l'avertit (R8) dans les deux sens de lecture ; une dent de scie est acceptée,
une dernière gare trop petite avant un hub ne l'est pas.

Ordre d'écriture conseillé : les hubs manquants d'abord (sans eux, les lignes
ne peuvent pas se mesurer), puis les **lignes de départ** (une par pays
d'entrée, rampe douce), puis les lignes entre hubs déjà écrits, ligne par
ligne — chaque ligne livrée est un commit.

## 5. Valider

```bash
node tools/carte-check.mjs --livrable=<zones>   # les règles et la couverture
node tools/gen-check.mjs                        # chaque fiche, et le résumé de carte
node tools/graph-check.mjs                      # intégrité et écartements
node tools/net-check.mjs                        # le réseau dessiné
```

`carte-check` rend un code de sortie ≠ 0 tant qu'une règle ✘ échoue sur
l'ensemble évalué. Sur un bloc (`--livrable`), R2 (50 lignes) est informatif
et un hub sous 3 sorties est un avertissement : on livre zone par zone.

## 6. Livrer une zone de plus

Les hubs-portes de la zone livrée ont des sorties « à venir » : chaque nouvelle
zone s'y greffe. Écrire ses hubs, tracer ses lignes, relancer `carte-check
--livrable=<anciennes>,<nouvelle>`. Rien dans le code ne change : le graphe
se construit depuis le JSON, les médailles et les rangs se déduisent.

## 7. État de l'Europe (21 août 2026)

85 hubs, 131 lignes, 9 zones — la carte entière satisfait R1, R2, R4, R6, R7.
Échecs : 31 hubs sous 3 sorties, 127 lignes hors 4–9, 58 hubs sans fiche. Bloc
de lancement **France-Benelux + Germanie-Alpes** (`--livrable=nw,ger`) : 24
hubs, 39 lignes, 3 conformes ; 3 hubs à écrire (Amsterdam, Zurich, Genève),
≥ 89 fiches à écrire sur les lignes dont les deux hubs existent ; 5 hubs à 2
sorties gardés (Dijon, Nantes, Toulouse, Genève, Leipzig — reliés plus tard ou
par une ligne à ajouter).
