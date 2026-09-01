# Créer une nouvelle gare (procédure)

Procédure suivie pour rendre les gares fidèles au réseau réel tout en gardant
le jeu jouable. Éprouvée sur la Belgique (13 gares) et la France (10 gares) —
juillet 2026. À rejouer pour chaque nouveau pays.

## 0. Principe directeur : politique HYBRIDE

**Plancher de jouabilité : au moins 3 directions (portails) et 3-4 quais.**
Mesuré : une gare de passage sur une seule ligne (2 directions, ex. Huy) est
creuse à jouer — il n'y a rien à aiguiller. Une gare entre au catalogue parce
qu'elle est un **croisement** d'au moins deux lignes réelles, jamais parce
qu'une ligne de carte a besoin d'un point de plus.

On garde l'**échelle de difficulté** et sa progression pédagogique (d1 petit →
d5 gros). On utilise le **réel** pour : *quelles* destinations, leur **côté L/R**
(géographie), le **type** (traversante / terminus / mixte), le **caractère**
(tagline/desc) et le **niveau de fret**. On ne grossit le nombre de quais /
directions **que dans l'enveloppe du palier** (voir §5). On ne fait PAS grandir
une petite gare à sa taille réelle si ça casse le palier (Charleroi ≈ 11 voies
en vrai, mais reste d1 / 4 quais, gare-tutoriel).

### Le piège n° 1 du §0 : l'ANCIENNE gare de bifurcation

Une carte ferroviaire, un article encyclopédique et même le plan de la ville
montrent souvent une étoile à quatre branches là où il n'en circule plus que
deux. **Le §0 compte les directions RÉELLEMENT desservies aujourd'hui**, pas
celles que l'infrastructure a portées.

Le vocabulaire qui doit alerter, relevé en source : « *ancienne* gare de
bifurcation », « ligne *partiellement déclassée* », « *seul le trafic fret*
l'utilise », « entre les gares *fermées* de X et Y ».

Mesuré le 27 août 2026 sur trois candidates de l'acte II, toutes trois
refusées pour ce motif exact :

| gare | ce que la carte montre | ce qui circule |
|---|---|---|
| Rochefort | bifurcation vers Aigrefeuille-Le Thou | branche **déclassée en 1954** — 2 directions |
| Marmande | origine de la ligne de Mont-de-Marsan | voyageurs arrêtés en **1938**, fret en **1971** — 2 directions |
| Jonzac | gare de la ligne Chartres – Bordeaux | encadrée de deux gares **fermées** — 2 directions |

La parade est celle du §0 : prendre la gare voisine qui est un carrefour
ACTUEL, ou redécouper le chapitre. Jamais inventer un portail sur une voie que
plus personne ne parcourt — le joueur y attendrait un train qui n'existe pas.

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
  "country": "belgique",
  // ^ LE SLUG DU PAYS, pas son libellé (1er septembre 2026). C'est le nom du
  //   dossier, et la clé du bloc dans index.json. Le libellé affichable
  //   (« 🇧🇪 Belgique ») vit UNE fois, dans `label` de index.json, et se lit
  //   par paysDe(slug) — js/catalog.js. Il était recopié dans les 401 fiches.
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

⚠ **Une antenne se met du côté OPPOSÉ à ce qu'elle dessert, pas du côté où elle
part.** À Ettelbruck, la navette de Diekirch quitte la gare vers l'est, comme
Luxembourg : les deux écrites en `R`, la navette n'avait plus aucun partenaire et
deux quais mouraient avec elle. Ce qu'un côté encode n'est pas un point cardinal
mais **le sens du parcours** — Diekirch se lit depuis Luxembourg, donc `L`. Le
réflexe géographique se retourne à chaque fois qu'une antenne repart dans la
direction de la ligne principale.

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
- **Sa ligne de carte** : une gare intermédiaire se joue parce qu'une ligne la
  porte. L'ajouter dans `data/cartes/<carte>.json`, dans le champ `gares` de SA
  ligne (une seule — règle R6), à sa position réelle de `de` vers `vers`. Un
  hub se déclare par son nom dans `hubs[].gare`. Voir `tools/AUTHORING-CARTES.md`.

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

> ⚠️ **SUR UNE GARE DU RUBAN, LE `gen` QUE VOUS ÉCRIVEZ N'EST PAS JOUÉ.**
> `ficheDeService` (`js/ruban.js`) le remplace par l'enveloppe de la difficulté
> **déduite de la position** de la gare dans son chapitre, rabattue par
> `plafondDeFlux`. Mesuré le 26 août 2026 : **60 des 63 gares** du ruban
> jouaient autre chose que ce qui était écrit dans leur fiche — Roth écrite
> 13-15 et jouée 18-22, Osnabrück écrite en difficulté 1 et jouée en 4.
>
> Ce qui reste entre vos mains sur une gare du ruban, c'est la **GÉOMÉTRIE** :
> le nombre de quais, le nombre de directions, et les `links`. C'est elle qui
> fixe le plafond, donc le niveau, donc l'enveloppe. Calibrer `nMax` à la main
> sur une telle gare ne change rien à ce que voit le joueur — l'erreur a été
> faite, et elle coûte une séance.
>
> Le `gen` écrit sert encore à trois choses : les gares **hors ruban**, les
> **grandes gares** de fin de chapitre (où `ENVELOPPE_BOSS` se fond avec lui),
> et les fiches **pas encore enregistrées**. Le tableau ci-dessous reste donc
> la référence pour les écrire — et c'est lui qui a servi à caler `ENVELOPPES`.
>
> `gen-check` teste **l'enveloppe jouée** par défaut. Pour mesurer celle qui est
> écrite — utile avant qu'une fiche rejoigne un ruban — passer `--ecrite`.

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

## 5 bis. LE PLAFOND DE FLUX — ce qu'une géométrie peut porter

Mesuré, et c'est la contrainte qui décide de la difficulté d'une gare de
corridor. On a pris de vraies petites gares et on leur a appliqué les
enveloppes `gen` de chaque palier, en regardant la **file d'attente** — le
nombre de convois qui visent le même quai en même temps (`platformPressure`,
`js/schedule.js`) :

| gare | directions / quais | plafond |
|---|---|---|
| Dinant | 3 / 3 | niveau **2** |
| Landen, Aarschot | 3 / 4 | niveau **3** |
| Bruges, Namur | 5-6 / 5-6 | niveau **4** |
| Liège | 6 / 9 | niveau **5** |

**Le générateur ne casse jamais** : à tous les paliers, il produit encore des
journées jouables à zéro retard. Ce qui casse, c'est la SENSATION. Au-delà du
plafond, le trafic supplémentaire ne devient pas de la difficulté mais de la
file : Dinant passe d'une pression de 4 à 7 entre le palier 1 et le palier 5 —
on n'y aiguille plus, on y attend. C'est exactement ce que le lot 1 a corrigé,
et qu'il ne faut pas réintroduire par l'enveloppe.

### La règle qui en découle

**Le flux déplace une gare d'un palier, pas de deux.** La difficulté d'une gare
vient d'abord de sa géométrie — combien de directions à aiguiller, combien de
quais pour les recevoir — et l'enveloppe `gen` ne fait que l'ajuster.

Conséquence pour l'écriture des corridors : **les gares doivent grossir à
l'approche du boss**. Une gare de fin de corridor à trois directions restera
facile quoi qu'on fasse de son trafic. C'est d'ailleurs la réalité du rail —
les abords des métropoles ont de grandes gares.

Repère : compter environ **un palier par paire de quais**, à partir de trois
directions.

## 6. Validation (obligatoire avant commit)

⚠ **Un balayage sans `--seed` ne se répète pas.** `reseed()` ne remplace
`Math.random` QUE si la graine est passée : deux exécutions tirent alors des
journées différentes, et « toutes les gares passent » ne vaut que pour ce
tirage-là. Mesuré le 22 août 2026 — quatre balayages verts d'affilée, puis un
cinquième qui sort Berne et Amersfoort à une file de 6, seuil jamais toléré.
Berne était réellement défectueuse depuis le début (quai 3 desservi par quatre
portails) ; les quatre premiers balayages ne l'avaient pas vue.

Il en faut donc **deux, et ils ne servent pas à la même chose** :
- `--seed=N` : le contrôle de non-régression. Reproductible, comparable d'un
  lot à l'autre, c'est lui qui dit si on a cassé quelque chose.
- sans graine, relancé plusieurs fois : l'exploration de la QUEUE de
  distribution. C'est le seul qui trouve les défauts rares — et « file de 6 »
  est précisément un événement rare qu'on ne veut jamais livrer.

Ne jamais conclure « le catalogue est vert » sur un seul balayage non graîné.

**LE BREVET REMPLACE LE RE-BALAYAGE DU CATALOGUE** (27 août 2026). Une gare du
ruban ne joue que des régimes en nombre fini — les enveloppes de niveau 1 à 5,
rabattues par `plafondDeFlux`, et le régime boss — et aucun ne dépend de la
carte. `node tools/brevet.mjs <id>` mesure donc chaque fiche sur chacun de ses
régimes, une fois, sur une batterie de graines fixes (3 × K=30 = 90 journées
par régime), et inscrit le niveau maximal sain dans
`data/stations/brevets.json`. Ensuite :

- **écrire ou retoucher une fiche** coûte SA certification, pas celle des
  autres (l'empreinte de la géométrie et du `gen` invalide le brevet au
  moindre changement — l'outil sans argument recertifie ce qui a changé) ;
- **modifier ou étendre une carte** ne coûte plus aucune simulation :
  `carte-check` (R10) croise la rampe de la carte avec les brevets, en
  millisecondes. C'est ce qui a manqué le 27 août, quand greffer l'acte V a
  déplacé la rampe des 63 gares existantes et ressorti Colmar au hasard d'une
  graine — un croisement de R10 l'aurait dit sans un seul tirage.

Le balayage `gen-check` garde deux usages : l'exploration d'une gare qu'on
soupçonne (tirage libre, K=30) et le contrôle de non-régression graîné d'un
lot. Il cesse d'être le péage de chaque modification de carte.

**LE CONTRÔLE DIT MAINTENANT « JE NE SAIS PAS ».** La règle de congestion
comparait une fréquence observée à une cible de 12 %, ce qui n'est pas un test :
mesuré le 26 août 2026, une gare dont le taux RÉEL vaut exactement 12 %
échouait 44 % du temps à K=20, et une gare à 8 % — sous la cible — une fois sur
cinq. Sur 63 gares, cela sortait une ou deux fausses alertes par balayage,
toujours différentes, et donnait l'illusion d'une dette sans fond.

`gen-check` teste désormais l'hypothèse : quelle probabilité d'observer autant
d'excursions si le taux réel valait la cible ? Sous 5 %, il refuse. Au-dessus,
il **avertit avec sa p-valeur sans faire échouer** — la gare dépasse peut-être,
l'échantillon ne le prouve pas. Un `⚠ … non concluant` n'est donc **ni un
échec ni un feu vert** : c'est une invitation à relancer cette gare seule à
K=30, qui tranche.

Les seuils de refus qui en découlent : 3 journées sur 6, 6 sur 20, 8 sur 30.
La **file de 6** et le **retard garanti** ne changent pas — ce sont des maxima,
pas des taux, et ils ne souffrent pas de ce biais. C'est d'ailleurs une faute
dure qui a désigné Wittenberg le 27 août, une fois les fausses alertes
écartées : rare (4 tirages sur 20), invisible à graine fixe, et bien réelle.

**Mais ne pas non plus extrapoler la queue.** K=6 est un estimateur bruité : sur
226 fiches, chaque tirage libre sort une ou deux gares « limites » différentes,
ce qui donne l'impression d'une dette sans fond. La mesure exhaustive du
23 août 2026 — 226 fiches × 30 journées × 2 graines — dit l'inverse :

| moyenne de pression | fiches |
|---|---|
| ≥ 4,0 | **0** |
| 3,5 – 3,9 | 8 |
| 3,0 – 3,4 | 79 |
| < 3,0 | 139 |

Une seule touchait 6 (Bad Kleinen, corrigée). Autrement dit : traiter les échecs
au fil de l'eau suffit, et un « passage systématique » sur tout le catalogue ne
se justifie pas. Quand le doute revient, refaire cette mesure
(`node tools/gen-check.mjs 30 --seed=1`, ~1 h) plutôt que d'inférer.

### Diagnostiquer une pression : la FORME ou le VOLUME

Deux causes, deux leviers, et les confondre aggrave la gare (mesuré sur Horb,
dégradée par deux tentatives sur son faisceau avant que l'enveloppe seule
suffise) :

- **La forme** — les quais centraux sont desservis par TOUS les portails, ceux
  du bord par deux. Le trafic se tasse au milieu. Se lit d'un coup d'œil en
  comptant les portails par quai. Vu sur Aachen (5 portails sur les quais 3-4,
  2 sur les quais 6-7), Berne, Amersfoort, Ottignies.
- **Le volume** — le faisceau est équilibré mais l'enveloppe trop dense pour ce
  que la géométrie porte, typiquement quand un côté n'a qu'un seul portail
  (tout passe par lui). Vu sur Colmar, Aarau, Roosendaal, Bingen, Horb, Harburg.

**LE TEST QUI SÉPARE LES DEUX, à faire AVANT de choisir le levier.** Deux
chiffres suffisent, et les lire coûte trente secondes contre un cycle de mesure
perdu :

1. **portails par quai** — si un quai en concentre nettement plus que les
   autres, c'est la FORME ;
2. **quais par paire portail-L × portail-R** — si la paire la plus étroite est
   à zéro ou un quai, c'est la FORME aussi, surtout si cette paire est **l'axe
   que le ruban emprunte**.

Faisceau plat et paires larges, mais la gare sort quand même : c'est le VOLUME,
et on descend l'enveloppe.

```bash
python3 - <<'EOF'
import json
d = json.load(open("data/stations/<pays>/<id>.json"))
P, L = d["portals"], d["links"]
print("portails/quai :", [len([k for k in P if q["id"] in L[k]]) for q in d["platforms"]])
G = [k for k in P if P[k]["side"] == "L"]; D = [k for k in P if P[k]["side"] == "R"]
for n, a, b in sorted((len(set(L[a]) & set(L[b])), a, b) for a in G for b in D):
    print(f"  {a} x {b} : {n} quai(s)")
EOF
```

**Mesuré le 26 août 2026 sur Hamm et Hengelo**, qui échouaient sur le MÊME
symptôme (file de 6) et demandaient l'inverse l'une de l'autre :

| | portails/quai | paire la plus étroite | cause | geste |
|---|---|---|---|---|
| Hamm | 2·2·3·3·4·3·2 | **Hagen × Bielefeld = 0** — l'axe du ruban | forme | élargir Hagen aux quais 3-7 |
| Hengelo | 3·3·3·2 (plat) | Amsterdam × Hanovre = 2 | volume | 14-15 → 12-13 convois |

Hengelo a d'abord été élargie comme Hamm : donner le quai 2 à Hanovre a mis les
QUATRE portails sur ce quai, et la gare est passée de 1 échec sur 24 à **8 sur
10**. Le geste a été rendu. C'est le même piège que Horb, et il se referme
exactement là — sur une gare dont le faisceau était déjà sain.

**Le cas le plus fréquent du VOLUME : un côté à portail unique.** Quand un côté
n'a qu'une seule destination, toutes les paires passent par elle — la gare
devient un entonnoir, et l'enveloppe doit descendre d'un cran, quelle que soit
la beauté du faisceau. Relevé sur Colmar (tout par Strasbourg), Aarau (par
Olten), Agen (par Montauban), Fürth (par Nuremberg) et Potsdam (par Berlin) :
toutes les cinq sortaient au-dessus de 4, toutes les cinq sont rentrées en
retirant deux ou trois convois. Un profil `rush` marqué aggrave le cas, parce
qu'il concentre le trafic dans l'entonnoir.

**Depuis le 27 août 2026, cette règle est dans `plafondDeFlux`** (`js/ruban.js`) :
un côté à portail unique coûte un cran de plafond, terminus exceptés. Elle y est
entrée quand l'acte V a mis Colmar en jeu : sa correction d'août dormait dans un
`gen` que le ruban ne joue plus (voir §5), et la gare ressortait à graine fixe
avec une file de 6. Sur une gare du ruban, il n'y a donc plus rien à régler à la
main pour ce motif — la formule rabat l'enveloppe jouée. Le paragraphe reste la
référence pour les gares HORS ruban, dont le `gen` écrit est joué tel quel.

Ce motif se balaie d'un coup sur tout le catalogue — pour chaque fiche, la
plus petite paire portail-L × portail-R, et le `nMax` de son enveloppe. Relevé
le 23 août 2026 : **43 fiches** ont un côté à portail unique, dont 38 avec un
`nMax` de 15 ou plus. Elles ne sont pas toutes fautives, loin de là : c'est un
FACTEUR DE RISQUE, pas un défaut, et les desserrer en bloc déplacerait
l'équilibre du jeu sans raison. Ce qui se corrige, c'est la fiche qui échoue,
et celle dont **la plus petite paire tombe à un seul quai** — Angers n'en avait
qu'un pour Cholet, Malines quatre paires sur six.

Le diagnostic qui tranche : **compter les quais partagés par chaque PAIRE**
portail-L × portail-R. Une paire à un ou deux quais est un goulet, surtout si
c'est l'axe du corridor. Bad Kleinen sortait une file de 6 parce que
Schwerin ↔ Rostock — l'axe même de Hambourg – Berlin — n'avait que deux quais,
et Lübeck ↔ Wismar aucun. Élargir la paire a réglé ce que baisser le trafic
avait empiré.

```bash
node tools/gen-check.mjs                # tout le catalogue, K=6
node tools/gen-check.mjs <id>           # une gare, K=30
node tools/gen-check.mjs <id1> <id2> 20 # gares ciblées, K=20
node tools/brevet.mjs                   # certifie les fiches nouvelles ou modifiées
node tools/brevet.mjs <id>              # certifie une fiche (tous ses régimes)
node tools/net-check.mjs                # le réseau de la carte
node tools/carte-check.mjs --detail     # la carte : règles R1–R10 et couverture
```

`carte-check` vérifie les règles de construction d'une carte (20 hubs, 50
lignes, 3 sorties par hub, 4 à 9 gares par ligne, zones, connexité, une gare
une ligne, sinuosité, rampe) et liste, ligne par ligne, les gares réelles qui
manquent. `gen-check` en affiche le résumé en fin de rapport
(`CARTE_BLOC=nw,ger node tools/gen-check.mjs` pour le résumé d'un bloc).

`gen-check` charge le vrai moteur + générateur (headless, sans navigateur) et
vérifie pour chaque gare : **connectivité** (aucun portail/quai mort) + **K
journées générées** (0 erreur, aucun train non plaçable, retard garanti sous le
seuil). Code de sortie ≠ 0 si échec. Un « portail mort » ou un retard > seuil =
à corriger avant de committer.

`net-check` vérifie le réseau DESSINÉ : lignes continues, points de passage
plausibles, aucune gare jouable isolée. Un portail qui ne désigne aucune gare
jouable n'y est **pas** une erreur — c'est un cul-de-sac (§0), et la carte
l'ignore. Il contrôle aussi la **progression** : une gare qu'aucune porte de
départ n'atteint de proche en proche est injouable à jamais.

`eco-check` charge le vrai barème (`js/catalog.js`) et contrôle que l'économie
tient : prix < tarif pour chaque gare, coût d'un pays < ce qu'il rapporte à
trois étoiles, et surtout le **seuil d'équilibre** — le multiplicateur moyen
qu'il faut atteindre pour que le réseau continue de croître (0,81 aujourd'hui,
soit un peu mieux que deux étoiles). Ajouter des gares ne le déplace pas tant
que tarif et prix dérivent de la même valeur ; le lire quand même après un ajout
de pays, c'est le seul chiffre qui dit si le jeu reste finissable.

## 7. Récap du flux pour un nouveau pays

1. Lister les gares visées + attribuer une difficulté (bâtir la rampe 1→5).
2. Un agent de recherche par gare (§1), en parallèle.
3. **Tracer le graphe du pays d'abord** : qui est voisin de qui, sur quelle
   ligne. C'est lui qui donne les portails (§0), donc les côtés L/R, donc la
   forme du gril — pas l'inverse.
4. Composer chaque fiche (§2) en respectant hybride (§0) et connectivité (§3).
5. Enregistrer (§4) : index.json + geo.js, puis les lignes du pays dans
   `data/lines.js` (+ `LINE_COUNTRIES`).
6. `node tools/gen-check.mjs`, `node tools/net-check.mjs` et
   `node tools/eco-check.mjs` → itérer jusqu'à « Toutes les gares passent ».

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

## Contrôler une grande gare de fin de chapitre

Une gare qui ferme un chapitre ne joue pas la journée de son niveau : elle
porte l'**enveloppe de boss** (`ENVELOPPE_BOSS`, js/ruban.js) — 20 à 24
convois, six trains de fret, courbe `rafale`. Le contrôle ordinaire ne la
mesure pas. Il faut donc :

```sh
node tools/gen-check.mjs --boss --seed=7 <gare>   # non-régression
node tools/gen-check.mjs --boss <gare>            # puis DEUX tirages libres
```

Et la règle du §6 vaut doublement ici : **un balayage graîné vert ne prouve
rien**. Mesuré le 25 août 2026 — une enveloppe à 24-28 convois passait les neuf
boss à graine 7 (Leipzig à 0,30 pile), et deux tirages libres l'ont aussitôt
fait échouer sur Leipzig et Stuttgart. Une gare posée sur le seuil n'est pas
une gare qui passe.
