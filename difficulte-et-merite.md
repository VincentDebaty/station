# La difficulté et le mérite — pourquoi tout se gagne, et ce qu'on peut y faire

Écrit le 10 septembre 2026, sur un constat de Vincent : « je réussis
pratiquement toutes les gares plutôt facilement ; je remets en cause le niveau
de difficulté pour avoir des étoiles ; le mérite doit être plus prononcé, quitte
à payer des pièces pour passer au suivant ». Il ajoute une piste : des vies
qui se récupèrent toutes les trente minutes, comme Cookie Jam.

Le document mesure d'abord **pourquoi** c'est facile — dans le moteur, dans
l'horaire, dans le barème et dans la rampe —, regarde ce que font les jeux
populaires du même genre, puis pose des leviers qui se livrent séparément, et
finit par les décisions à prendre. Il ne remplace ni `meta-progression` (§2.1,
§2.5, §4, §4 ter) ni `economie-du-jeu.md` : il est ce que ces deux documents
supposaient sans l'avoir mesuré — que l'échec existe.

Ce qui n'est **pas** mesuré ici : le taux d'échec réel d'un joueur. Il n'y a
pas de télémétrie et pas de simulation de joueur moyen dans les outils (les
contrôles simulent un placement *idéal*). Tout ce qui suit est structurel :
lu dans les règles, les constantes et les données. La proposition 3.4 dit
comment le mesurer.

---

## 1. Ce qu'on mesure : cinq raisons pour lesquelles on ne perd pas

### 1.1 Le retard ne se produit qu'au départ, et par minutes entières

Le seul événement qui coûte est un **départ en retard d'un train de
voyageurs**. Attendre dehors ne coûte rien (« le convoi attend dehors, sans
pénalité — seule compte l'heure de départ », dit le tutoriel lui-même). Le fret
ne pèse jamais. Un mauvais quai ne coûte que le temps du refoulement, qui ne
compte que s'il fait manquer le départ.

Et le retard d'un départ n'est encaissé que par **minutes entières**
(`totalDelay += Math.floor(depDelay)`, `js/game.js`), après une tolérance
`DEPART_GRACE` de 0,15 min. Un train qui part **1,14 min** après son heure
pèse **zéro**. C'est vrai pour le compteur, pour les étoiles, et pour le
**sans-faute** : un service dont chaque convoi part une minute en retard vaut
trois étoiles **et un diamant**. Sur quinze convois, jusqu'à dix-sept minutes de
retard réel sont invisibles au score.

### 1.2 L'horaire est construit pour être tenu

L'heure de départ officielle n'est pas tirée : elle est **déduite d'un
placement idéal**, puis relevée d'une marge de réaction et arrondie à la
minute au-dessus — `dep = ceil(depReal + REACTION_MARGIN)`, avec
`REACTION_MARGIN = 1,5` (`js/schedule.js` ligne 516, `jeu/journee.gd` ligne
733). Chaque train a donc, en moyenne, **deux minutes** de mou entre le départ
faisable et le départ demandé. Et `gen-check` refuse toute fiche dont le retard
garanti par le placement idéal dépasse 0,30 min : la journée à zéro est
démontrée possible partout.

Additionnées, 1.1 et 1.2 donnent **environ trois minutes par convoi** avant
qu'une seule minute ne compte. La marge est la même au niveau 1 et au
niveau 5 : elle est écrite une fois, en constante.

### 1.3 Le barème demande peu, et le plancher ne demande rien

Le seuil des trois étoiles suit le niveau (12 → 8 min), mais il faut le
rapporter au nombre de convois, qui monte lui aussi :

| niveau | convois | 3 ★ sous | tolérance par convoi | 1 ★ (échec au-delà) | retard **réel** moyen par convoi pour échouer |
|---|---|---|---|---|---|
| 1 | 12–15 | 12 min | 0,8–1,0 min | 30 min | ≈ 3,2 min, sur chaque train |
| 2 | 13–16 | 11 | 0,7–0,85 | 30 | ≈ 3,1 |
| 3 | 14–17 | 10 | 0,6–0,7 | 30 | ≈ 3,0 |
| 4 | 16–20 | 9 | 0,45–0,55 | 30 | ≈ 2,7 |
| 5 | 18–22 | 8 | 0,36–0,44 | 30 | ≈ 2,5 |

Avec la minute entière de 1.1, la tolérance par convoi des trois étoiles se
lit en réalité **« presque deux minutes de retard sur chaque train »** au
niveau 1. Et **échouer** demande que chaque train, sans exception, parte plus
de trois minutes après son heure — deux minutes de marge d'horaire plus une
minute entière plus deux minutes comptées. Ça ne se produit pas en jouant, ça
se produit en ne jouant pas.

Le plancher de 30 minutes est une décision structurelle (§2.1 : « c'est le
plancher qui rend le ruban praticable ») et ce document ne propose pas de le
toucher. Mais il faut voir ce qu'il implique : **la soupape de §4 ter, tout
le mécanisme « Réessayer / Payer le passage », et donc la seule dépense de
pièces du ruban, ne s'exercent jamais.** Les pièces s'accumulent vers un seul
puits, la deuxième carte à 15 000.

### 1.4 La rampe est plate sur deux cents gares

Mesuré sur `data/cartes/europe.json` avec le modèle du jeu (`js/ruban.js`,
`plafondDeFlux` inclus), niveau réellement joué des 277 gares :

| niveau | gares | part |
|---|---|---|
| 1 | 8 | 3 % |
| 2 | 106 | 38 % |
| 3 | 96 | 35 % |
| 4 | 53 | 19 % |
| 5 | 14 | 5 % |

Trois gares sur quatre se jouent au niveau 3 ou moins. **35 des 49 chapitres
déclarent un plancher de 2**, du chapitre 2 au chapitre 38 : la première zone
(*atl*, 26 chapitres, 148 gares) ne dépasse jamais 4, et ne touche 4 qu'en fin
de chapitre. La première gare de niveau 5 est la 208e. Le joueur qui arrive au
chapitre 39 a joué 220 gares dont une seule au-dessus de 4.

Le §9 du design pose la question depuis le 25 août — « le pas de la courbe :
tous les combien de chapitres le plancher monte-t-il ? À mesurer » — et elle
n'a jamais été mesurée : les planchers ont été posés à 2 par défaut en
écrivant les chapitres.

Il y a une raison de fond à cette platitude, et elle ne se corrige pas par
les données : **la difficulté est plafonnée par la géométrie**
(`plafondDeFlux` : quais, directions, entonnoir). Une gare de quatre quais ne
portera jamais un niveau 4, quelle que soit sa position. Le ruban est fait de
vraies gares, et les vraies gares de province sont petites. Le trafic ne peut
donc pas monter partout. C'est pour cela que le second cadran — la
**précision** — est le seul qui puisse porter la difficulté sur toute la
longueur du ruban, et c'est celui qui, aujourd'hui, ne serre pas (1.1, 1.2).

### 1.5 Le temps réel ne presse pas

Une minute de jeu dure 4 secondes réelles (`SEC_PER_GAMEMIN`), à tous les
niveaux. Un service de quinze convois espacés de deux minutes dure de l'ordre
de trois minutes réelles, avec une décision — choisir un quai — toutes les
huit à dix secondes, et la pause à portée de doigt. Mini Motorways ou Mini
Metro, qui sont les cousins les plus proches, tiennent le joueur par
l'escalade du rythme ; ici le rythme est plat, seul le nombre change.

### 1.6 Ce qui est bon, et que rien ci-dessous ne casse

- **« Réussir est facile, exceller est le vrai jeu »** est le bon pilier pour
  un jeu testé par une enfant de dix ans sans aide. Le défaut n'est pas que
  réussir soit facile, c'est qu'**exceller l'est aussi**.
- Les deux cadrans (débit, précision) sont la bonne idée. Le second ne mord
  pas encore.
- Tout est déduit, rien n'est stocké : on peut resserrer le barème, la rampe
  et le score sans migration — à une exception près, les étoiles acquises
  (§3.1, L3).
- Le brevet (R10) rend les changements de rampe gratuits en simulation. Ce
  sont les changements de **génération** (marge, imprévus) qui coûtent des
  heures de certification. Le tableau du §3 le dit levier par levier.

---

## 2. Ce que font les jeux populaires, et ce que ça vaut ici

| jeu | mécanisme de mérite ou d'échec | ce qu'il achète | ce que ça vaut pour Station |
|---|---|---|---|
| **Candy Crush, Cookie Jam, Royal Match** | 5 vies, une revient toutes les 30 min, recharge payante ; 1 ★ passe, 3 ★ rares ; les niveaux « murs » sont réglés pour échouer 5 à 10 fois | rythme des sessions, tension, ventes | Les vies y marchent parce que l'échec est **surtout de la chance** et que le niveau dure deux minutes : on ne perd rien à réessayer. Chez nous l'échec est de la **compétence** — c'est en réessayant qu'on apprend. Voir P3. |
| **Super Mario 3D World, Rayman Legends, Crash 4, Cut the Rope** | **porte à étoiles** : le monde suivant exige N étoiles (ou lums) cumulées ; on repasse dans les niveaux faits pour les compléter | le mérite devient la **clé du contenu**, sans bloquer personne (les étoiles manquantes sont dans des niveaux déjà faits) | La transposition la plus directe de « le mérite doit être plus prononcé, quitte à payer ». Voir P1. |
| **Cut the Rope, Angry Birds** | 3 étoiles **difficiles par design**, la première facile ; à Cut the Rope les étoiles se **collectent** dans le niveau (objectifs), pas un seuil | lisibilité du mérite ; chaque étoile a une raison | Le barème (L3) et, plus loin, les objectifs de gare (P5). |
| **Mini Metro, Mini Motorways** | pas de vies, pas de niveaux : une partie **escalade** jusqu'à la rupture ; score = ce qu'on a tenu ; défi quotidien classé | rejouabilité, mérite continu, aucune frustration d'échec (perdre est la fin normale) | Le cousin de genre. La journée sans fin (P4), et le temps qui presse (L4). |
| **Rail Route, Train Valley 2** | horaire strict, bonus de ponctualité, contrats optionnels plus durs | profondeur pour experts | La précision qui compte (L1, L2). |
| **Trackmania, Sonic** | médailles de temps : bronze, argent, or, **auteur** (le temps du créateur) | une cible absolue, jamais floue | Le diamant est déjà notre médaille d'auteur (le placement idéal fait zéro). Il faut qu'il redevienne rare (L1). |
| **Duolingo** | 5 cœurs, un échec en retire un ; on en regagne **en s'exerçant** sur du connu, ou au temps | l'échec renvoie vers la révision, pas vers la caisse | La version de « vies » compatible avec la soupape et avec « retourner dorer ». Voir P2. |
| **Monument Valley** | aucun échec, aucun mérite | contemplation | Le contre-exemple : Station a choisi le mérite (étoiles, rangs, diamant). Il faut donc qu'il coûte. |

---

## 3. Les leviers, en trois familles

Chaque levier dit ce qu'il change, ce qu'il coûte, et s'il touche la
**génération** (donc les 277 brevets, plusieurs heures de machine) ou la
**sauvegarde** (donc une migration).

### 3.1 Rendre la gare exigeante — la précision qui mord

**L1 — Les dixièmes comptent.** Le score additionne les retards **bruts**
(`depDelay`, déjà calculé) au lieu de leur partie entière ; les étoiles se
lisent sur le total arrondi ; le **sans-faute** exige un total qui arrondit à
zéro, donc moins de trente secondes de retard cumulé sur toute la journée. La
pastille « à l'heure » cesse de mentir : elle ne s'affiche que sous la
tolérance de départ (0,15 min, `DEPART_GRACE`, qui existe déjà pour cela) ;
au-dessus, elle dit « + 0,8 ». Une seule définition du retard, partagée par la
pastille, le compteur et le score — c'est le piège documenté de
`PORTAGE-GODOT` §4, à respecter dans les deux implémentations, et
`oracle-journee` doit le vérifier.

C'est le levier le moins cher et le plus fort : il rend au diamant sa rareté
d'un coup, et retire au niveau 1 ses dix-sept minutes invisibles. Ni brevet,
ni migration.

**L2 — La marge de réaction suit le niveau.** `REACTION_MARGIN` devient une
table : 1,5 · 1,25 · 1,0 · 0,8 · 0,6 min du niveau 1 au niveau 5. C'est le
levier *vrai* — littéralement « combien l'horaire vous laisse » —, et le seul
qui fasse jouer les petites gares de fin de ruban comme des gares de fin de
ruban, malgré leur géométrie. Il touche la génération : **tous les brevets
sont à refaire**, et le retard garanti (≤ 0,30) doit être revérifié, puisque
la marge participe au calibrage. Compter une nuit de machine. Il s'écrit
dans `schedule.js` et `journee.gd` ensemble.

**L3 — Le barème serre.** Deux formes possibles, à choisir :

- *absolue* : 3 ★ sous 8 · 7 · 6 · 5 · 4 min (au lieu de 12 → 8), 2 ★ sous
  15 (au lieu de 20), 1 ★ sous 30, inchangé ;
- *relative au nombre de convois* : 3 ★ = 0,5 min par convoi au niveau 1,
  0,2 au niveau 5, arrondi ; le barème s'affiche comme aujourd'hui (« Pour
  3 ★ : 7 min »), il est seulement calculé depuis la journée tirée.

Les étoiles sont **stockées** (`{stars, bestDelay}`), pas déduites : après
un resserrement, un joueur garde des étoiles qu'il n'aurait plus. Deux
choix : les garder (acquis, simple), ou les **recalculer depuis `bestDelay`**
à la migration (schéma 10, `migrate()`, un cas dans `oracle-sauvegarde`).
Le second est le plus honnête, et le seul qui rende la porte P1 juste.

**L4 — Le temps presse.** `SEC_PER_GAMEMIN` par niveau : 4 · 4 · 3,5 · 3 ·
2,5 s. Aucun changement de génération (le temps réel n'entre pas dans
l'horaire), aucune migration, et une difficulté honnête : au niveau 5, les
mêmes décisions arrivent presque deux fois plus vite. Les niveaux 1 et 2 ne
bougent pas, l'enfant non plus. Le bouton ×2 garde son sens (il double ce qui
est). À vérifier sur téléphone : que le geste reste faisable à 2,5 s la
minute, avec les cibles tactiles actuelles.

**L5 — Les imprévus suivent le niveau.** Aujourd'hui : 20 % de journées
calmes, sinon un ou deux événements (arrivée retardée, quai fermé), à tous les
niveaux. Proposé : 0–1 au niveau 1, jusqu'à 2–3 au niveau 5, et un troisième
type — un convoi qui **change de destination en approche** (l'affichage du
quai devient faux, il faut re-aiguiller). Touche la génération : brevets à
refaire, à faire donc dans le même lot que L2.

### 3.2 Une rampe qui monte — le pas de la courbe, enfin décidé

Répondre à la question 3 du §9. Proposition de planchers par acte, qui garde
R9 (premier chapitre doux) et laisse la géométrie plafonner comme aujourd'hui :

| chapitres | plancher aujourd'hui | proposé | ce que ça change |
|---|---|---|---|
| 1–3 | 1 · 2 · 2 | 1 · 1 · 2 | l'apprentissage, inchangé |
| 4–12 | 2 | 2 | le premier acte reste doux |
| 13–26 | 2 | 3 | la fin de la zone *atl* joue enfin au niveau 3 partout où la géométrie le permet |
| 27–38 | 2 | 4 | les Alpes et l'Italie deviennent le milieu de jeu qu'elles sont sur la carte |
| 39–49 | 3–4 | 4, puis 5 pour les six derniers | la fin du ruban est une fin |

Coût : les champs `plancher` de `europe.json`, et `carte-check` en
millisecondes — R10 dit immédiatement si un brevet manque. Aucune simulation
si les brevets couvrent le niveau (ils certifient le maximum sain de chaque
fiche). Là où la géométrie rabat le niveau voulu (la plupart des petites
gares), la rampe ne change rien : **c'est pour cela que 3.1 est nécessaire
et que 3.2 ne suffit pas.**

### 3.3 Le mérite dans la structure — portes, cœurs, vies, journée sans fin

**P1 — Les portes à étoiles (recommandé).** *Le chapitre suivant s'ouvre
quand le chapitre courant totalise au moins deux étoiles par gare* (10 sur
15 pour cinq gares — un chapitre d'argent y suffit, un chapitre à 3+3+1+1+2
aussi). Sinon, la fête de chapitre le dit avec les mots qu'elle a déjà :
« il manque 2 étoiles pour ouvrir *Le Yorkshire noir* — Doncaster peut en
rapporter 2 », et propose **« Ouvrir · 200 pièces »** (deux fois le prix du
passage du chapitre), la mise **rendue** quand les étoiles sont enfin
gagnées, comme pour un passage. Une porte de zone, plus haute (70 % des
étoiles de la zone), ferme la carte à qui la traverse à une étoile.

Ce que ça donne : les étoiles deviennent la **clé du contenu**, ce qui est
exactement « le mérite plus prononcé » ; les pièces trouvent un puits ; la
boucle « retourner dorer » cesse d'être une phrase du design pour devenir le
chemin normal ; et personne n'est bloqué, puisque les étoiles manquantes sont
dans des gares déjà faites, donc plus faciles. Ce que ça coûte : renverser la
phrase « il n'y a aucune porte » (§4, §4 quater), un tableau
`portesPayees: [chapitreId]` dans la sauvegarde (schéma 10), un cas d'oracle,
et un écran — la fête de chapitre, qui a déjà la place. La porte ne joue qu'à
partir du chapitre 3, pour que l'enfant ne la rencontre pas pendant
l'apprentissage.

**P2 — Les cœurs à la Duolingo (sans horloge).** Cinq cœurs. Un service à
zéro étoile en retire un. Un cœur revient à chaque **étoile nouvelle** gagnée
n'importe où sur la carte — donc en rejouant ce qu'on a déjà fait, ce qui est
le sens du jeu. À zéro cœur, la gare en cours reste jouable... non : à zéro
cœur, seul le **rejeu** des gares faites est ouvert ; la gare bloquante
rouvre au premier cœur regagné, ou contre des pièces (le prix du passage).
Pas d'horloge, donc pas de fuseau ni de triche à l'heure du téléphone ; les
cœurs sont stockés comme la série (ils dépendent de l'ordre des services) :
schéma 10. Contrairement aux vies, l'échec renvoie vers l'entraînement, pas
vers l'attente.

**P3 — Les vies à la Cookie Jam (demandé).** Cinq vies, une revient toutes
les trente minutes, recharge en pierres. Évaluation honnête :

- ce qu'elles achètent : de la tension, un rythme de session, et une vente ;
- ce qu'elles coûtent : **une horloge dans la sauvegarde** (un horodatage de
  la dernière vie perdue) — c'est l'objection qui a écarté la médaille de
  régularité, et elle vaut ici : fuseaux, changement d'heure, et la triche
  banale qui consiste à avancer l'heure du téléphone (Cookie Jam la subit et
  la tolère) ; la promesse écrite de §4 ter (« jamais de vies, jamais de
  minuterie »), à renverser explicitement ; et le pilier de l'enfant qui joue
  seule — dans un jeu de compétence, la vie punit l'apprentissage ;
- et surtout : **au taux d'échec d'aujourd'hui, elles ne changeraient rien**.
  Elles n'ont de sens qu'après 3.1 et 3.2, quand perdre existe. Elles se
  décident donc après, en connaissance du taux mesuré — et P2 fait le même
  travail sans horloge.

Si Vincent la veut malgré tout, elle s'écrit : `vies: { n, perdueA }` dans la
sauvegarde, `Time.get_unix_time_from_system()` côté Godot, `Date.now()` côté
web, la recharge en pierres au prix de la boutique (`boutique-check` B-x : la
vie n'est pas du temps qu'on vend, c'est une pierre qu'on dépense), et
l'écran d'échec qui affiche le compte à rebours à la place de *Réessayer*.

**P4 — La journée sans fin (Mini Metro).** Une fois une gare à trois
étoiles, un mode où le service **ne s'arrête pas** : la cadence se resserre
tous les dix convois, les imprévus s'accumulent, jusqu'à ce que le retard
crève les trente minutes. Score = convois servis à l'heure ; record par gare
(`sansFin: { record }`, schéma 10). C'est le mérite continu des experts, la
rejouabilité sans toucher au ruban, et une mesure de difficulté qui parle
d'elle-même (« j'ai tenu 61 convois à Lille »). Coût : le générateur travaille
par journée fermée — il faut une génération **incrémentale** dans
`schedule.js`/`journee.gd`, c'est-à-dire du moteur. À réserver au portage,
mais à décider maintenant pour que le schéma le prévoie.

**P5 — Les objectifs de gare (Cut the Rope).** La troisième étoile n'est plus
un seuil mais un **objectif** propre à la gare : aucun refoulement, aucun
convoi attendu dehors plus de deux minutes, le fret passé sans arrêter
personne. Le mérite devient lisible (« pourquoi deux étoiles ? — le fret »)
et les gares se distinguent enfin les unes des autres (le chantier « maps
feel samey »). Coût : la sémantique des étoiles change, donc les rangs, les
médailles et le barème des pièces se relisent ; les objectifs sont des données
de fiche, ou se déduisent de la géométrie et du niveau. Lourd, à garder en
option.

### 3.4 Mesurer avant et après — le joueur paresseux

Les contrôles simulent un placement idéal ; ils prouvent qu'on *peut* faire
zéro, pas que c'est difficile. Il manque **un joueur simulé médiocre** : une
politique « premier quai libre qui dessert la destination, décision prise
deux à trois secondes réelles après l'arrivée, jamais d'anticipation », jouée
sur K journées par gare et par niveau, qui rende la distribution des retards
et le **taux d'échec**. Un outil `tools/joueur-check.mjs` sur le modèle de
`gen-check` (même moteur, même générateur). C'est le seul chiffre qui puisse
dire si L1–L4 suffisent, et c'est celui qu'il faut avoir avant de décider P2
ou P3. Il ne remplace pas la seule mesure qui compte : Vincent, puis l'enfant,
qui rejouent dix gares.

---

## 4. Ce que je recommande, dans l'ordre

| lot | contient | génération (brevets) | sauvegarde | ce qu'on saura après |
|---|---|---|---|---|
| **1** | L1 les dixièmes · L3 le barème · L4 le temps qui presse · 3.4 le joueur paresseux | non | schéma 10 si les étoiles sont recalculées | si la précision suffit à faire exister l'échec |
| **2** | 3.2 la rampe · L2 la marge par niveau · L5 les imprévus | **oui**, une nuit | non | si la fin du ruban est une fin |
| **3** | P1 les portes à étoiles | non | schéma 10 (`portesPayees`) | si les pièces se dépensent, et si « retourner dorer » se fait |
| **4** | P2 ou P3, décidé sur le taux mesuré ; P4 sous le moteur | P4 : moteur | schéma 10 | — |

Le lot 1 se fait en une séance et règle l'essentiel du constat : aujourd'hui
le diamant tolère une minute par train, et c'est ce qui rend tout facile. Le
lot 3 est la vraie réponse à « quitte à payer des pièces pour passer » : ce
qu'on paie, c'est la porte, et elle se paie d'abord en étoiles.

---

## 5. Les décisions à prendre

1. **Les dixièmes comptent** (L1), et le sans-faute exige moins de trente
   secondes cumulées ? C'est la décision qui change le plus pour le moins.
2. **Le barème** (L3) : absolu (8 · 7 · 6 · 5 · 4) ou relatif au nombre de
   convois ? Et les étoiles déjà acquises : gardées, ou recalculées depuis le
   meilleur retard ?
3. **Le temps presse** (L4) : 4 s la minute au niveau 1, 2,5 s au niveau 5 ?
4. **Le pas de la courbe** (3.2) : les planchers par acte proposés ?
5. **La marge de réaction par niveau** (L2), au prix d'une nuit de brevets ?
6. **Les portes à étoiles** (P1) : deux étoiles par gare, deux passages pour
   forcer, à partir du chapitre 3 ? Cela renverse « aucune porte ».
7. **L'échec qui coûte** : cœurs sans horloge (P2), vies à la Cookie Jam
   (P3), ou rien tant que le taux d'échec n'est pas mesuré ?
8. **La journée sans fin** (P4) : à prévoir dans le schéma dès maintenant ?
