# Créer une nouvelle gare (procédure)

Procédure suivie pour rendre les gares fidèles au réseau réel tout en gardant
le jeu jouable. Éprouvée sur la Belgique (13 gares) et la France (10 gares) —
juillet 2026. À rejouer pour chaque nouveau pays.

## 0. Principe directeur : politique HYBRIDE

On garde l'**échelle de difficulté** et sa progression pédagogique (d1 petit →
d5 gros). On utilise le **réel** pour : *quelles* destinations, leur **côté L/R**
(géographie), le **type** (traversante / terminus / mixte), le **caractère**
(tagline/desc) et le **niveau de fret**. On ne grossit le nombre de quais /
directions **que dans l'enveloppe du palier** (voir §5). On ne fait PAS grandir
une petite gare à sa taille réelle si ça casse le palier (Charleroi ≈ 11 voies
en vrai, mais reste d1 / 4 quais, gare-tutoriel).

### Ce que nomme un portail : la destination AFFICHÉE sur le quai

Un portail porte le nom que le voyageur lit, pas celui de la gare suivante.

1. **La grande destination de l'axe**, même à deux ou trois gares de là. Liège
   annonce `BRUXELLES` et non Landen, `LUXEMBOURG` et non Marloie : Landen et
   Marloie sont des **gares de passage**. Elles restent parfaitement jouables —
   la continuité du pays ne vient pas des noms de portails mais des lignes
   (`data/lines.js`), et **le déblocage non plus** : on ouvre une VOISINE du
   réseau, pas la ville affichée sur le quai. Un portail à +2 ou +3 gares ne
   débloque donc rien, et c'est voulu.
   *Comment trancher* : le classement des destinations réellement annoncées se
   lit sur les liveboards (§1). À popularité comparable, préférer la gare
   **jouable** — elle donne au pays sa continuité de lecture. Ne jamais nommer
   le bout d'un long IC par-dessus la grande ville de l'axe (les trains de
   Tournai affichent « Turnhout » ; le portail dit `BRUXELLES`).
2. **À défaut, un cul-de-sac** : le terminus d'une antenne ou d'une frontière
   que le jeu n'ouvre pas (`OSTENDE`, `KNOKKE`, `GENK`, `COUVIN`, `TURNHOUT`,
   `LUXEMBOURG`, `LOUVAIN-LA-NEUVE`…). On les garde délibérément — Bruges sans
   la côte n'est plus Bruges — et ils fournissent souvent le **second côté** sans
   lequel le moteur ne forme aucune paire : Arlon n'a qu'un seul voisin belge,
   sans `LUXEMBOURG` la gare ne génère aucun train (§3).

**Un cul-de-sac n'est pas un objet de carte.** Pas de coordonnées, pas de point,
pas de trait : il n'existe que sur le gril et dans le texte de la fiche. La
carte ne montre que le réseau **jouable** — une ville qu'on ne peut pas prendre
en main n'a rien à y faire, et l'y dessiner ne fait qu'encombrer le zoom local.

Corollaire : ne pas transformer une antenne en gare jouable pour « boucler la
carte ». Une gare entre au catalogue parce qu'elle fait un bon poste
d'aiguillage, jamais pour donner un point d'arrivée à un trait.

## 1. Recherche des données réelles (un agent par gare, en parallèle)

Pour chaque gare, récupérer :
- **Type** : traversante, terminus (cul-de-sac à heurtoirs) ou mixte. *Décisif* —
  le jeu modélise les deux distinctement. Vérifier explicitement (beaucoup de
  gares réputées « terminus » sont traversantes, et inversement).
- **Nombre de voies à quai** réel.
- **Destinations principales par axe géographique** (point cardinal + ligne).
- **Fret** : passe-t-il RÉELLEMENT à quai, ou contourne-t-il par une rocade /
  un autre itinéraire ? (souvent surestimé — cf. Strasbourg, Liège, Mons).
- **Trait distinctif** réel (rôle de nœud, architecture, rénovation…).

Sources : **iRail** liveboard (Belgique : `https://api.irail.be/liveboard/?station=<NOM>&format=json&arrdep=departure`),
**SNCF Open Data** / **DB Open Data** (autres pays), **Wikipedia** (FR/EN/NL/DE),
**OpenRailwayMap** (plan de voies, traversante vs terminus). Prioriser la
**connectivité du graphe** (§3) sur la correspondance littérale des n° de quai
d'un instantané liveboard.

Erreurs réelles typiques déjà corrigées : desserte disparue (Libramont→Bastogne,
fermé 1993), fret arrêté (Mons→Quiévrain, 1992 ; corridor rhénan qui contourne
Strasbourg), mauvaise gare (Lille-Flandres≠Lille-Europe pour Bruxelles/Eurostar).

## 2. Schéma d'une fiche (`data/stations/<pays>/<id>.json`)

```jsonc
{
  "id": "liege",                    // = nom de fichier, = clé dans geo.js
  "name": "Liège-Guillemins",       // nom COMPLET de la gare (fiche détaillée)
  "city": "Liège",                  // nom de VILLE affiché sur la carte-pays.
                                    // À AJOUTER dès que le nom diffère de la ville
                                    // (ex. « … Hbf », « …-Central »). Sinon omis
                                    // (la carte retombe sur `name`).
  "tagline": "…",                   // une ligne, accroche de la carte
  "desc": "…",                      // 2-3 phrases, caractère réel
  "difficulty": 4,                  // 1..5, définit le palier (§5)
  "country": "🇧🇪 Belgique",
  "platforms": [                    // impasse : "deadEnd": true (heurtoir)
    { "id": 1 }, { "id": 2 }, …
  ],
  "portals": {                      // = destinations. Gare jouable voisine
                                    // d'abord, cul-de-sac ensuite (§0).
    "BRUXELLES": { "side": "L", "color": "#25dede", "abbr": "B" },
    "AACHEN":    { "side": "R", "color": "#f2588f", "abbr": "AC", "label": "AACHEN" }
    // side L = entre par la gauche, R = par la droite. label si accent/nom long.
    // in:false / out:false pour un portail à sens unique (rare).
  },
  "links": {                        // portail -> quais desservis. VOIR §3.
    "BRUXELLES": [3, 4, 5, 6],
    "AACHEN":    [4, 5, 6]
  },
  "sameSidePairs": [],              // [] normal ; "all" = terminus ;
                                    // [["A","B"],["B","A"]] = rebroussement A↔B
  "gen": { … }                      // paramètres du générateur, VOIR §5
}
```

Palette réutilisée : `#25dede` cyan, `#f5b23c` ambre, `#4ade80` vert,
`#f2588f` rose, `#60a5fa` bleu, `#a78bfa` violet.

Note : le champ `cap` (longueur de quai variable) est de la **donnée morte** —
non lue par le moteur, ne pas l'ajouter. Tous les quais font la même longueur
(≤ 7 wagons, `MAX_CARS`).

**Écrire trente-six grils à la main ne marche pas.** Mesuré sur l'Allemagne :
61 invariants cassés en une passe (portails sans partenaire, quais que rien ne
dessert). Le remède est une **règle**, pas de la patience :
- les grandes destinations d'un côté se partagent le gril en **fenêtres qui se
  recouvrent et pavent 1..q** — d'où « aucun quai orphelin » et « aucun portail
  mort » par construction ;
- un **cul-de-sac** ne prend que deux quais au bord : une antenne n'occupe pas
  le tronc (§8) ;
- un **terminus** reçoit un pavage CIRCULAIRE, parce que chacun de ses quais
  doit être desservi par deux portails (voir §3).
Un côté fait uniquement de culs-de-sac (Dresde vers l'est) n'a pas d'antenne :
ce sont eux, le tronc.

## 3. INVARIANT DE CONNECTIVITÉ (le piège n°1)

Un train ne circule qu'entre deux directions de **côtés opposés qui partagent au
moins un quai** dans `links` (ou une paire même-côté listée dans `sameSidePairs`).
Conséquences à garantir :
- **Aucun portail mort** : chaque portail doit partager un quai avec ≥1 portail
  du côté opposé. Sinon cette destination n'apparaît JAMAIS (invisible à l'œil).
- **Aucun quai mort** : chaque quai doit appartenir à l'intersection d'au moins
  une paire valide.
- Encoder les **vrais axes traversants** par des quais partagés (ex. le tronc
  Bruxelles–Aachen de Liège partage les quais 4-5-6).

Terminus (`sameSidePairs: "all"`, tous les portails du même côté, quais
`deadEnd`) : les trains entrent et rebroussent ; tout portail partageant un quai
avec un autre forme une paire valide.

⚠ **Dans un terminus, un quai qui n'appartient qu'à UN portail est mort.** Le
train entre par un portail et repart par un AUTRE : il lui faut donc deux
portails sur le même quai. C'est l'erreur la plus facile à rater — l'œil voit un
quai desservi, le moteur voit un cul-de-sac. Règle : **chaque quai d'un terminus
figure dans au moins deux listes de `links`** (mesuré sur London Waterloo, quais
6 et 8, que seuls Reading et Portsmouth desservaient).

## 4. Enregistrement (2 fichiers)

- `data/stations/index.json` : ajouter l'`id` dans le bloc `stations` du pays
  (créer le bloc `{ "country": "...", "label": "🏳️ ...", "stations": [...] }`
  pour un nouveau pays). L'ordre ne sert que de départage à difficulté égale.
- `js/geo.js` : ajouter `<id>: [longitude, latitude]` dans `countries.<pays>.cities`
  (coordonnées de la VILLE, pour la carte monde). Créer l'entrée pays si besoin
  (`{ name, flag, iso, continent, cities: {…} }`).

**Plusieurs gares dans la même ville** (Paris-Nord, Paris-Gare-de-Lyon,
Paris-Montparnasse) : ne PAS leur donner de `city` commun — la carte afficherait
trois pastilles « Paris » indiscernables. Chacune porte son nom complet. Et
comme la règle du centimètre (`mapnet.js`) n'en garderait qu'une, on les écarte
de quelques kilomètres dans `geo.js`, chacune sur l'axe de sa propre desserte :
5 km de mensonge, invisibles à l'échelle où l'on choisit une gare, et les trois
redeviennent cliquables dès qu'on zoome sur la ville.

⚠ **Faire entrer un pays dans `LINE_COUNTRIES` lui retire TOUS ses portails
comme source de carte** — d'un coup, et y compris ses relations
internationales. En écrivant les lignes françaises, l'Eurostar (Paris-Nord →
`LONDRES`) et la vallée du Rhin (Strasbourg → `OFFENBURG`) ont cessé d'exister
pour la carte : le Royaume-Uni est tombé de 88 gares atteignables à 11, et
Freiburg n'était même plus une porte d'entrée valable. Ces liaisons doivent être
RÉÉCRITES comme lignes en même temps que le pays. `net-check` les compte : lire
la couverture « atteignable depuis chaque porte » avant/après, pas seulement le
nombre d'erreurs.

Un **cul-de-sac ne s'enregistre nulle part** : ni dans `index.json`, ni dans
`geo.js`, ni comme point de carte. C'est une chaîne de caractères dans
`portals`, rien de plus. La carte, elle, se décrit à part : `data/lines.js`
enchaîne les gares JOUABLES d'un pays le long de leurs lignes réelles
(`data/places.js` ne sert plus qu'aux **points de passage** qui donnent leur
tracé à ces lignes — Lierre, Alost, Grammont, Ciney… — jamais à une
destination).

## 5. Enveloppes par palier (valeurs de référence `gen`)

`gen` = `{ nMin, nMax, gapMin, gapMax, cars[], quietRate, rush }`.
`cars` = tirage des longueurs (pondéré), **entre 2 et 7** : une valeur 1 est
remontée à `MIN_CARS` = 2 par le générateur (une motrice seule n'est pas un
convoi). `quietRate` = proba d'un jour sans imprévu.

**`rush` — la forme de la journée** (facultatif, défaut `"pointe"`). Module
l'écart entre arrivées selon la position dans le service : une densité de 2
rapproche les arrivées deux fois plus. La courbe est **normalisée**, donc la
durée du service ne change pas — seule sa répartition change, et les enveloppes
ci-dessous restent valables telles quelles.

| `rush` | forme | pour quelle gare |
|---|---|---|
| `"pointe"` | une pointe nette au milieu (défaut) | le cas général |
| `"double"` | deux pointes, matin et soir | desserte de banlieue, navetteurs |
| `"rafale"` | long calme puis bourrasque finale | gare qui « prend » tard |
| `"plat"` | pression constante | à réserver aux gares tutoriel |

C'est un levier de **caractère**, pas de difficulté : deux gares aux mêmes
chiffres se jouent différemment selon leur profil. Repère mesuré sur une gare à
18 convois : en fenêtre glissante de 5 min, `plat` oscille entre 2 et 3 convois,
`pointe` entre 2 au creux et 5 au sommet. Attention, un profil marqué creuse
aussi les accalmies — vérifier au `gen-check` que le retard garanti reste bas.

**Fret** : plus aucun réglage dans `gen` — le NOMBRE de convois de fret vient de
`difficulty` (1 au niveau 1 … 5 au niveau 5), étalés sur la journée. Un fret se
comporte comme un train normal (file d'approche, aiguillage par le joueur) sauf
qu'il ne s'arrête pas : il lui faut entrée + sortie libres d'un seul tenant, et
il n'a pas d'heure de départ. Il traverse donc forcément d'un côté à l'autre :
une gare TERMINUS (tous les portails du même côté) n'en reçoit aucun.
`gen.freightCount` reste possible pour forcer un nombre (gares de stress test).

| Diff | Quais | Directions | nMin–nMax | gap | cars (typique) | notes |
|---|---|---|---|---|---|---|
| **1** | 4 | 4 | 12–15 | 1.6 / 2.8 | `[2,2,2,2,3,3,4]` | rames courtes, tutoriel |
| **1** term. | 6 | 4 | 11–14 | 2.0 / 3.4 | `[2,2,3,3,4,4,5]` | Lille |
| **2** | 5–6 | 5 | 13–16 | 1.8 / 3.0 | `[2,2,2,3,3,4,4,5]` | Louvain, Bruges, Nantes |
| **2** term. | 6 | 5 | 12–15 | 1.9 / 3.2 | `[3,3,4,4,5,5,6,7]` | Marseille (rames longues) |
| **3** | 6 | 5–6 | 14–15 → 17–18 | 1.6 / 2.8–3.2 | `[2,3,3,4,4,5,5,6]` (+7 pour 6 dir) | Lyon, Bordeaux, Gand… |
| **4** | 5–9 | 5–6 | 14–16 → 17–20 | 1.5 / 2.6 | jusqu'à 6–7 | dense |
| **5** | 8–10 | 6–8 | 18–24 | 1.4 / 2.4 | `[2,3,3,4,4,5,5,6,7]` | boss (Bruxelles-Midi, Paris-Nord) |

Au-delà de **9 quais / 6 directions**, on sort de ce qui a été éprouvé : le
générateur travaille sur toutes les paires, le coût monte vite et le zéro n'est
plus garanti d'office. Une gare de ce gabarit (Bruxelles-Midi à 10 quais et 8
directions) se valide sur **30 journées** (`gen-check <id>`), pas sur 6, et se
redescend d'une direction si elle peine.

Limites moteur (ne pas dépasser) : **≤ 13 quais**, **~6 directions/côté**,
**≤ ~30-34 trains/jour** (au-delà : coût de génération cubique + le zéro n'est
plus garanti). Fret : 6–7 wagons, non plafonné par MAX_CARS.

## 6. Validation (obligatoire avant commit)

```bash
node tools/gen-check.mjs                # tout le catalogue, K=6
node tools/gen-check.mjs <id>           # une gare, K=30
node tools/gen-check.mjs <id1> <id2> 20 # gares ciblées, K=20
node tools/net-check.mjs                # le réseau de la carte
```

`gen-check` charge le vrai moteur + générateur (headless, sans navigateur) et
vérifie pour chaque gare : **connectivité** (aucun portail/quai mort) + **K
journées générées** (0 erreur, aucun train non plaçable, retard garanti sous le
seuil). Code de sortie ≠ 0 si échec. Un « portail mort » ou un retard > seuil =
à corriger avant de committer.

`net-check` vérifie le réseau DESSINÉ : lignes continues, points de passage
plausibles, aucune gare jouable isolée. Un portail qui ne désigne aucune gare
jouable n'y est **pas** une erreur — c'est un cul-de-sac (§0), et la carte
l'ignore.

## 7. Récap du flux pour un nouveau pays

1. Lister les gares visées + attribuer une difficulté (bâtir la rampe 1→5).
2. Un agent de recherche par gare (§1), en parallèle.
3. **Tracer le graphe du pays d'abord** : qui est voisin de qui, sur quelle
   ligne. C'est lui qui donne les portails (§0), donc les côtés L/R, donc la
   forme du gril — pas l'inverse.
4. Composer chaque fiche (§2) en respectant hybride (§0) et connectivité (§3).
5. Enregistrer (§4) : index.json + geo.js, puis les lignes du pays dans
   `data/lines.js` (+ `LINE_COUNTRIES`).
6. `node tools/gen-check.mjs` et `node tools/net-check.mjs` → itérer jusqu'à
   « Toutes les gares passent ».

## 8. Deux pièges d'écriture, mesurés

**La duplication de fiches.** En retirant noms et couleurs, il ne reste d'une
fiche que sa structure — quais, côtés, `links`. Huit gares réparties sur quatre
pays se sont retrouvées STRICTEMENT identiques (la gare d'ouverture recopiée de
pays en pays), et dix-huit autres jumelées. On croit alors que les plans se
ressemblent à cause de la géométrie du faisceau ; c'est faux, ce sont les mêmes
fiches. Avant d'ajouter une gare, comparer son empreinte structurelle à celles
du catalogue.

**Quatre directions équivalentes.** Le réflexe est de faire desservir à chaque
ville trois quais sur quatre. Une vraie gare a une **ligne principale**, qui
occupe le tronc du gril, et des **antennes**, cantonnées à un ou deux quais.
C'est ce qui distingue deux gares de même gabarit — et ça ne coûte rien : le
retard garanti ne bouge pas (mesuré : écart 0,00 entre liaisons d'origine et
redécoupées, à fiche et graine identiques).

Pour explorer l'espace des structures avant d'écrire :
`tools/PROMPT-panorama-gares.md`.
