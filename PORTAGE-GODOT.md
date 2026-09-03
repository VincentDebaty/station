# Le portage sous Godot

Écrit le 1er septembre 2026, quand le prototype web a été jugé assez complet
pour être porté. Ce document dit **ce qui traverse, ce qui se jette, ce qui se
réécrit, et ce qui ne doit surtout pas dériver au passage**.

Il ne décide rien sur l'esthétique : elle est conservée telle quelle, et
l'embellissement viendra sous le moteur (`plan-de-dev.md`, « Ce qu'on ne fait
pas »).

---

## 0. Le principe qui a guidé tout le prototype

> Le jeu web est un **prototype**. On n'investit rien dans une chaîne graphique
> web, mais tout ce qui est **données et règles** est écrit pour survivre au
> portage.

C'est pour ça que les cartes et les fiches sont du JSON et non du JS, que les
règles de jeu ne sont jamais dans `render.js`, et que les quatre contrôles sont
des scripts Node indépendants du navigateur. Le portage encaisse aujourd'hui ce
qui a été payé pendant six mois.

**Le rapport est d'environ 2 pour 1** : sur 8 610 lignes de JS, ~2 300 sont du
rendu jetable et ~4 000 sont de la règle à transposer — le reste étant des
outils qui ne bougent pas.

---

## 1. Ce qui passe TEL QUEL — aucune réécriture

### Les données

| | volume | ce que c'est |
|---|---|---|
| `data/stations/<pays>/*.json` | **401 fiches** | la gare : quais, portails, liens, enveloppe de génération |
| `data/stations/index.json` | 10 pays | l'ordre curé, et le libellé de pays (une fois) |
| `data/stations/brevets.json` | 401 entrées | le niveau maximal certifié sain par fiche |
| `data/cartes/*.json` | 2 cartes | le ruban : chapitres, zones, rampe, sauts |
| `js/geo.js` | 404 villes | `id: [lon, lat]` — coordonnées, pas géométrie de gare |
| `data/lines.js` | ~200 lignes | la topologie réelle du réseau, pour le tracé |
| `data/places.js` | points de passage | ce qui donne sa forme au trait sans être jouable |
| `data/worldmap.js` | Natural Earth | **généré, jamais édité à la main** |

Godot lit du JSON nativement. `js/geo.js`, `data/lines.js`, `data/places.js` et
`data/worldmap.js` sont du JS déclaratif : **`tools/vers-json.mjs` en DÉRIVE**
`data/derive/*.json`, en les évaluant dans un `node:vm` comme le fait déjà
`net-check`. Le JS reste la source, le JSON en découle, le prototype n'est pas
touché — convertir une fois aurait créé une deuxième source qui dérive au
premier changement. Relancer l'outil après avoir touché un de ces quatre
fichiers.

### Les quatre contrôles

`gen-check`, `brevet`, `carte-check`, `net-check` sont de l'ESM Node lancé
directement, sans dépendance ni installation. Ils ne connaissent pas le
navigateur.

**Ils ne se portent pas : ils restent.** Un contrôle qui tourne hors moteur est
un contrôle qu'on peut lancer en CI, sur une machine sans Godot, et qui ne ment
pas parce qu'il partagerait un bug avec le jeu. Il y a **une** exception à
surveiller : `carte-check` **évalue `js/ruban.js`** pour ne pas dupliquer le
modèle de difficulté (`tools/carte-check.mjs`, commentaire « LE MODÈLE DE
DIFFICULTÉ VIENT DU JEU, JAMAIS D'UNE COPIE »). Au portage, ce fichier devient
la source qui n'est plus jouée — il faudra soit le garder comme référence
exécutable, soit faire lire à `carte-check` le GDScript. La première option est
la moins chère et la plus honnête.

### La sauvegarde

`js/store.js` est le **seul** fichier qui connaît le support de stockage.
Schéma courant : **7**. La migration (`migrate()`) sait remonter depuis les
schémas 5, 6 et 7. Le modèle — cache mémoire lu en synchrone, backend
échangeable — a été écrit d'avance pour ça : sous Godot, seul `makeBackend()`
change (`user://` au lieu de localStorage).

**La règle ne change pas** : toute modification du format impose d'incrémenter
`SCHEMA_VERSION` et d'écrire la migration, testée depuis une sauvegarde
ancienne. Une mise à jour qui perd la partie d'un joueur est un bug bloquant.

---

## 2. Ce qui se JETTE

- **`js/render.js`** (1 175 lignes) — toute la chaîne SVG du plan de voies.
- **`js/parcours.js`** (1 107 lignes) — l'écran du ruban, son panneau, sa caméra.
- **`css/station.css`** (2 700 lignes) — l'habillage entier.
- **`station.html`**, `js/main.js` — l'assemblage DOM, la boucle
  `requestAnimationFrame`, les contrôles HUD.
- **`js/network.js` / `js/mapnet.js`** — le tracé du réseau à l'écran (les
  DONNÉES qu'ils consomment restent, eux non).

Soit ~2 300 lignes de rendu, plus le CSS. C'était le plan depuis le début.

---

## 3. Ce qui se RÉÉCRIT — et ce que ça pèse

C'est le vrai travail. Par ordre de difficulté décroissante :

### `js/game.js` — 1 455 lignes, le cœur

L'enclenchement : états des convois, aiguillage, files d'approche, occupation
des quais, refoulement, retards, score. **C'est le fichier le plus dense du
projet et celui qui contient le plus de règles mesurées.** Les états d'un
convoi : `scheduled` → `approaching` → `waiting` → `movingIn` → `dwell` →
(`movingThrough` | `movingBack`) → `movingOut` → `done` → `gone`.

### `js/engine.js` — 271 lignes, la géométrie GÉNÉRÉE

Il construit le plan de voies **à partir de la fiche** : quais, portails,
courbes d'approche et de sortie, points d'entrée. **Aucune gare n'est dessinée à
la main, et il y en a 401.** C'est la contrainte structurante du portage : sous
Godot il faut un **kit modulaire** — quai, voie, aiguille, portail, convoi — et
jamais un décor peint par gare.

Le rendu actuel place les convois par abscisse curviligne sur un chemin
(`pathPoint`), ce qui correspond **directement** à `Path2D` / `PathFollow2D`.
C'est la meilleure nouvelle du portage : la primitive existe déjà côté moteur.

### `js/schedule.js` — 580 lignes, la journée

La génération d'un service : qui arrive, d'où, vers où, à quelle heure, avec
combien de voitures. Tourne dans un **Web Worker** (`js/gen-worker.js`) parce
que c'est coûteux. Sous Godot : un `Thread`, ou du GDScript synchrone si les
mesures le permettent.

### `js/ruban.js` — 414 lignes, la difficulté

La rampe, les enveloppes de génération par palier, le plafond de flux, la
position sur le ruban. **Tout est déduit, rien n'est stocké.**

### `js/recompense.js` — 352 lignes, la récompense

Étoiles, rangs de chapitre, **26 médailles**, crédits. Déduit également.

### `js/catalog.js`, `js/cartes.js`, `js/hub.js` — ~400 lignes

Chargement, libellés de pays, grades. Mécanique.

---

## 4. LES INVARIANTS QUI NE DOIVENT PAS DÉRIVER

Ce sont des nombres qui ont coûté des mesures. Les changer au portage, même de
peu, change le jeu sans que personne s'en aperçoive avant longtemps.

### Le gabarit, en unités monde (`js/engine.js`)

```
viewBox           1400 × 760          axe horizontal  CENTER_Y = 400
voiture           CAR_LEN 30 × CAR_H 20,  CAR_GAP 5  →  CAR_SPACING 35
convoi            MIN_CARS 2 … MAX_CARS 7
quai              PLAT_H 42,  PLAT_LEN 262  (x de 569 à 831, centré en 700)
marge de quai     PLAT_MARGIN = (PLAT_H − CAR_H) / 2 = 11
fuite des voies   EXIT_RUN 700,  EDGE_RUN 360   (au-delà du viewBox, exprès)
dégagement        PORTAL_CLEAR 130
```

`PLAT_LEN` n'est **pas** une constante libre : elle découle du convoi le plus
long — `MAX_CARS × CAR_SPACING − CAR_GAP + 2 × PLAT_MARGIN` = 262. Si
`MAX_CARS` bouge, le quai bouge.

⚠ Le commentaire de `js/engine.js` annonce « 240 + 60 » à côté de ce calcul :
**il est périmé**, la valeur réelle vaut 262. Vérifié le 1er septembre 2026 en
évaluant la formule. Ne pas reprendre le commentaire au portage.

### Le temps (`js/engine.js`)

```
SEC_PER_GAMEMIN   4.0     1 minute de jeu = 4 secondes réelles à ×1
TRAVEL            1.6     minutes de jeu pour traverser un gril
MIN_DWELL         2       arrêt minimum au quai
DEPART_GRACE      0.15    tolérance de départ, en minutes de jeu
```

**`DEPART_GRACE` est un piège documenté.** Le retard d'un convoi a **UNE seule
définition**, partagée par la pastille au-dessus du train, le compteur du HUD et
le score. La dupliquer — ne serait-ce qu'en oubliant la tolérance — fait
diverger deux affichages d'une fraction de minute, et le joueur voit le jeu se
contredire.

### Le barème (`js/ruban.js`, `SEUILS`)

Minutes de retard tolérées pour trois étoiles, **par palier de difficulté** :

| palier | 3 ★ | 2 ★ | 1 ★ |
|---|---|---|---|
| 1 | 12 | 20 | 30 |
| 2 | 11 | 20 | 30 |
| 3 | 10 | 20 | 30 |
| 4 | 9 | 20 | 30 |
| 5 | 8 | 20 | 30 |

Une étoile reste à **30 partout** : c'est le plancher qui rend le ruban
praticable.

### La rampe (`js/ruban.js`)

```
difficulteVoulue(i, n, plancher, arrivee)
  = round(plancher + (arrivee − plancher) × i / (n − 1))
```

**`round` est l'arrondi de JavaScript**, qui monte à la moitié : `round(2.5) = 3`.
Python descend au pair (`2`), GDScript monte comme JS. Cette différence m'a fait
publier une carte fausse le 1er septembre — trois gares jouaient un cran
au-dessus de leur brevet. **À vérifier explicitement au portage.**

### Le contrat couleur

`DEST_COLOR[destination]` — **la couleur dit la destination, et rien d'autre**.
Toute la lisibilité du jeu repose dessus, et ça contraint la palette entière :
un décor coloré entre en concurrence directe avec l'information. C'est ce qui a
disqualifié une des trois directions artistiques explorées.

### Le brevet (R10)

Chaque fiche porte un **brevet** : le niveau maximal auquel elle a été mesurée
saine, sur graines fixes, une fois pour toutes. `carte-check` croise la rampe
d'une carte avec les brevets. C'est ce qui rend l'extension d'une carte
instantanée — plus besoin de re-balayer le catalogue.

**Le brevet dépend d'une empreinte de géométrie.** Si le portage change la
génération, ne serait-ce qu'au bruit de tirage près, **tous les brevets sont à
refaire** (`tools/brevet.mjs`, ~430 s pour 6 fiches en parallèle — compter
plusieurs heures pour 401).

---

## 5. LES PIÈGES — mesurés, et silencieux si on les casse

Chacun a coûté un bug et une session. Ils ne sont pas déductibles du code : ils
sont écrits ici parce qu'ils ne se voient qu'en jouant longtemps.

1. **FIFO sur la voie d'approche.** Les convois entrent dans l'ordre où ils se
   sont présentés, sans dépassement (`t.queuedAt`, `js/game.js:418`). Un
   terminus dense a demandé une calibration plus forte.

2. **Relâchement d'itinéraire au portail.** Une sortie ne se relâche qu'une fois
   le convoi entièrement dégagé (`PORTAL_CLEAR`). Sinon : collisions frontales.

3. **Fermeture de quai.** Une fermeture ne tombe **jamais** sur un quai occupé —
   génération différée dans les fenêtres libres, plus un garde à l'exécution.

4. **Un quai occupé reste choisissable.** Le convoi patiente dehors et entre dès
   qu'il se libère. Attendre à l'extérieur ne coûte rien ; seule compte l'heure
   de départ. **C'est le cœur du jeu** : la ressource rare est le quai. Refuser
   ce geste obligerait à revenir tapoter plus tard — de la charge mécanique, pas
   une décision.

5. **On ne dit pas au joueur quel quai dessert sa destination.** Tous les quais
   accessibles depuis l'origine s'allument à l'identique. Le mauvais choix reste
   possible, et se paie d'un refoulement. Le révéler avant le choix supprimerait
   l'erreur — donc le jeu.

6. **Le fret est un train normal.** Il fait la file et s'aiguille comme les
   autres ; il ne s'arrête simplement pas au quai.

7. **La position sur le ruban ne se stocke pas**, elle se déduit : première gare
   ni faite ni payée. Un état déduit ne peut pas se désynchroniser.

8. **Une gare payée reste à zéro étoile.** Ni rang, ni médaille. On ne s'achète
   pas un chapitre d'or.

---

## 6. Ce que Godot offre, et que le prototype simule

- **`Path2D` / `PathFollow2D`** — le placement par abscisse curviligne existe
  nativement. C'est déjà la façon dont le prototype pense les convois.
- **Un vrai fil d'exécution** pour la génération, au lieu d'un Web Worker.
- **Le son**, qui est aujourd'hui minimal.
- **La sauvegarde native** (`user://`), sans les pièges de cache du web.
- **Et surtout : plus de piège de cache.** La source de bug la plus fréquente du
  prototype — un iPhone servant un mélange de versions — disparaît avec le
  navigateur.

---

## 7. Ce qui n'est PAS tranché

- **L'esthétique.** Conservée telle quelle ; l'embellissement viendra sous le
  moteur. Trois directions ont été explorées le 1er septembre et rejetées.
- **Le multi-langue.** Sous Godot, avec `tr()` et des fichiers CSV/PO. Coût
  mesuré d'une deuxième langue : **22 122 mots** de prose sur les 401 fiches,
  plus 67 noms de chapitres et de zones. Coût éditorial, pas technique.
- **Cinq gares de calibrage** — Toulouse, Lunebourg, Berne, Louvain (hors ruban)
  et **Stuttgart** (sur le ruban, chapitre `le-neckar`) sortent au hasard sur un
  balayage libre. À traiter ou à assumer.
- **Deux avertissements de `carte-check`** acceptés : R4 (zones déséquilibrées
  sur l'Europe) et R8 (deux chapitres dont l'arrivée n'est pas le sommet).
- **Trois coordonnées orphelines** dans `js/geo.js` — `allersberg`, `kinding`,
  `pfaffenhofen` : les haltes de LGV retirées du ruban le 26 août 2026, dont
  l'entrée géo est restée. Sans effet (aucune fiche, aucun contrôle ne les
  voit), mais à ne pas porter.
- **Le barème des crédits** (lot G, point 6). Finir l'Europe rapporte 2 711,
  la deuxième carte coûte 1 500, finir la deuxième n'en rapporte que 1 153.
  La pente est à valider si d'autres cartes payantes suivent.
- **Abréviation des directions en paysage sur téléphone.** Mesuré : à
  844 × 390, six quais avec leurs numéros, quatre directions et le compteur ne
  tiennent qu'avec des noms abrégés (YK, BA, NC, MI). Contrainte de lisibilité.

---

## 8. Un ordre de portage

Il suit une règle : **ce qui se vérifie tout seul d'abord**.

1. **Charger les données et les afficher.** — ✅ **FAIT le 1er septembre 2026.**
   Les 401 fiches, les 401 brevets, les 2 cartes, le réseau dérivé : chargés en
   **23 ms**, affichés, sans une erreur. Les libellés accentués et les drapeaux
   passent intacts. `project.godot` est à la racine, les dossiers du prototype
   portent un `.gdignore`, et les quatre contrôles continuent de tourner à côté
   sans rien savoir de Godot. Scène : `jeu/catalogue.tscn`, autoload
   `jeu/donnees.gd`.
2. **La géométrie générée** (`engine.js`) — ✅ **FAIT le 3 septembre 2026.**
   `jeu/geometrie.gd` transpose `loadStation()` ligne à ligne, en flottants
   64 bits. **L'oracle a le dernier mot** : `tools/oracle-geometrie.mjs` fait
   calculer chaque fiche par `engine.js` (dans un `node:vm`) et par Godot
   (`jeu/oracle_geometrie.gd`, sans fenêtre, les 401 en un seul démarrage), puis
   compare quais, portails, les 2 210 points de Darlington, abscisses cumulées,
   longueurs, durées, voies d'approche et de départ, zones de conflit et
   liaisons autorisées. **401 fiches identiques, pire écart 2,3 × 10⁻¹³** — le
   dernier bit de `Math.hypot` contre `sqrt`, comme prévu. `jeu/gare.tscn`
   dessine n'importe quelle fiche (`STATION_GARE=<id>`) ; vérifié sur
   Darlington (6 quais, 4 directions) et Bruxelles-Midi (10 quais, 8
   directions, 437 conflits) : le kit tient.

   Trois pièges Godot appris là, à ne pas réapprendre :
   - **le cache des `class_name` n'est construit que par l'éditeur.** Un projet
     cloné et lancé en ligne de commande ne connaît pas `Geometrie`. Tout ce
     qui doit tourner sans éditeur passe par `preload("res://…")`.
   - **en mode `--script`, Godot rend 0 sur une erreur de parsing.** Un outil
     qui se fie au code de sortie croit que tout va bien ; l'oracle lit la
     sortie et refuse sur `SCRIPT ERROR`.
   - **les nombres d'un JSON arrivent en `float`** : `str(1.0)` donne « 1.0 »,
     et un identifiant construit dessus (`in:YORK:1.0`) ne correspond plus à
     celui du prototype. L'oracle l'a attrapé — 104 clés absentes, écart
     numérique nul.
3. **La journée** (`schedule.js`) — ✅ **transposée et vérifiée le 3 septembre
   2026 ; ⚠ trop lente pour être jouée telle quelle.**
   `jeu/journee.gd` transpose `generateSchedule()` en entier — tirage sous
   pression, simulation du joueur parfait, affectation gloutonne, calibrage
   itéré, fermetures sur quai libre — avec `jeu/hasard.gd`, le mulberry32 de
   `gen-check` en entiers 32 bits masqués. `tools/oracle-journee.mjs` tire la
   même journée des deux côtés avec la même graine : **18 journées sur 18
   identiques** (Darlington, Namur, Liège, Arlon, Stuttgart, Bruxelles-Midi ×
   graines 1-3), convoi par convoi, événements compris. Deux choses invisibles
   y sont vitales : l'ORDRE des cinq tirages, et la STABILITÉ du tri des
   convois par arrivée (`Array.sort` est stable en JS, `sort_custom` ne le
   garantit pas — on tranche par l'indice d'origine).

   **Le chiffre qui décide de la suite** — génération d'une journée, même
   algorithme, même résultat :

   | gare | V8 (prototype) | GDScript |
   |---|---|---|
   | Arlon | 46 ms | 548 ms |
   | Darlington | 395 ms | 4 828 ms |
   | Liège | 941 ms | 13 941 ms |
   | Bruxelles-Midi, graine 3 | 1 528 ms | **22 969 ms** |

   GDScript était **14 fois plus lent** sur cette boucle. Le prototype avait
   déjà dû reléguer la génération dans un Web Worker à 2 s ; à 23 s, un niveau
   ne démarre pas. Quatre options ont été posées : (a) optimiser sans changer
   le résultat, (b) un fil d'exécution, (c) sortir le générateur de GDScript,
   (d) pré-tirer les journées avec le prototype. **Vincent a choisi (a).**

   **Résultat de (a), le 3 septembre 2026 — ×3,9, sans qu'un bit ne bouge :**

   | gare | V8 | GDScript avant | GDScript après |
   |---|---|---|---|
   | Arlon | 46 ms | 548 ms | **164 ms** |
   | Darlington | 395 ms | 4 828 ms | **1 327 ms** |
   | Liège | 941 ms | 13 941 ms | **3 617 ms** |
   | Bruxelles-Midi, graine 3 | 1 528 ms | 22 969 ms | **5 572 ms** |

   Les 18 journées de l'oracle restent identiques. Deux leçons de méthode, à
   retenir pour game.js qui vient ensuite :

   - **La première optimisation « évidente » n'a rendu que ×1,5.** Objets
     typés au lieu de dictionnaires, indices entiers au lieu de clés texte,
     identifiants calculés une fois par convoi, FIFO limitée au portail. Bien,
     mais à côté de la cible.
   - **Le banc a montré la vraie cible.** `jeu/bench_journee.gd` compte : une
     journée de Bruxelles-Midi, c'est 626 simulations, 1,3 million de pas, et
     **35 millions d'itérations convoi × pas à 425 ns** — alors que 3 à 6
     convois seulement peuvent agir à un pas donné, les autres n'étant pas
     encore arrivés ou déjà partis. Ne passer que sur les vivants, en gardant
     leur ORDRE de passage (un dormant rejoint les vivants à son rang, juste
     avant le pas où il arrive), ramène à 8 millions d'itérations : ×2,5 d'un
     coup, et c'est exact — un convoi programmé n'a d'effet qu'à partir du pas
     où il arrive, un convoi fini n'en a plus jamais.

   **Ce qui reste, et pourquoi on s'arrête là.** GDScript est encore ~3,7 fois
   V8. Le coût restant est le pas de temps lui-même — 1,3 million de pas, on
   ne saute pas un pas sans changer une somme flottante, donc sans casser
   l'oracle. 5,6 s au pire, 0,2 à 1,8 s sur une gare ordinaire. C'est jouable
   à deux conditions, qui relèvent de l'écran et non du générateur : (b) un
   fil d'exécution pour ne rien geler, et **pré-tirer la journée de la gare
   suivante pendant que le joueur lit son relevé** — les secondes d'attente
   sont déjà là, il suffit de s'en servir. Si ça ne suffit pas au test, (c) et
   (d) restent sur la table, avec un chiffre et non une crainte.
4. **L'enclenchement** (`game.js`) — ✅ **transposé et vérifié le 3 septembre
   2026.** `jeu/enclenchement.gd` porte la partie RÈGLE de `game.js` : la
   machine à états d'un convoi, la file d'approche en accordéon (`placeQueue`
   de `render.js` fixe `qs`, donc `startS`, donc l'enclenchement — c'est de la
   règle malgré son fichier), `occupiedSpan` avec `easeRun`, le FIFO, les
   itinéraires et leurs zones de conflit, les quatre prédicats de quai, le fret
   qui s'aiguille seul, les imprévus révélés en partie, le retard vivant, la fin
   de service. Tout ce qui est écran est resté dans le prototype.

   **L'oracle fait tourner `game.js` dans Node, derrière un DOM inerte** — un
   Proxy qui rend un objet inerte à tout accès, accepte toute écriture, absorbe
   tout appel. Les règles s'exécutent, le rendu tombe dans le vide, et aucun
   navigateur n'est nécessaire. `tools/oracle-enclenchement.mjs` tire la
   journée avec `schedule.js` sur graine, la fait jouer des deux côtés au pas
   de 1/240 min par le MÊME joueur scripté — volontairement naïf : il envoie
   sur un mauvais quai quand rien ne dessert, donc refoulements, feux rouges et
   coupure au plafond sont exercés — et compare chaque transition d'état à
   l'instant près, chaque choix, et la fin de service. **18 journées sur 18
   identiques** (Darlington, Namur, Liège, Arlon, Stuttgart, Bruxelles-Midi ×
   graines 1-3), sur toute la palette : un sans-faute, des zéro-étoile, cinq
   services interrompus au plafond. Puis **les 401 fiches, graine 1 : 401
   identiques**, en 305 s de Godot — moins d'une seconde par journée.

   Pas de problème de vitesse ici : l'enclenchement est du travail par image,
   pas une boucle serrée — Godot est au niveau de V8 (Bruxelles-Midi : 1,0 s
   contre 0,7 s pour toute une journée à 240 pas par minute).

   Un piège de l'oracle, pas du jeu, consigné pour la prochaine fois qu'on fait
   tourner du code navigateur en aveugle : un Proxy qui rend toujours quelque
   chose de vrai fait boucler sans fin `while (el.firstChild) el.removeChild(…)`
   (`render.js`, la file en réduction). Dix minutes à 99 % avant de le voir.
   Les liens de parenté d'un nœud inerte rendent `null`.
5. **La rampe et la récompense** (`ruban.js`, `recompense.js`) : étoiles, rangs,
   crédits. `carte-check` doit rendre le même verdict qu'aujourd'hui.
6. **La sauvegarde** (`store.js`) : `makeBackend()` seul change. Tester une
   migration depuis une sauvegarde du prototype.
7. **Les écrans** : ruban, cartes, relevé, tutoriel. En dernier, parce que c'est
   la partie qu'on jette et refait le plus volontiers.

   **Pris hors d'ordre le 3 septembre 2026, à la demande de Vincent : l'écran de
   jeu.** `jeu/jeu.tscn` (`jeu/vue_jeu.gd`) est la scène principale. Il ne
   décide de rien : la journée vient de `Journee`, chaque position vient de
   l'état d'`Enclenchement`, et l'écran traduit en pixels avec les formules de
   placement de `render.js` — `path_point` (qui extrapole au-delà du chemin,
   c'est ce qui fait glisser un convoi le long du quai au demi-tour),
   `placeEntry` qui compte les voitures vers l'arrière, `placeExit` vers
   l'avant, le transit de fret. Convois, badges (heure de départ en ambre,
   « +N min » en rouge), itinéraires accordés et promis, quais éligibles,
   fermés, promis, feu rouge, horloge, retard vivant, fin de service.
   Commandes : clic convoi puis clic quai, espace, 1/2/4, R, Échap.
   `STATION_AUTO=1` laisse jouer le joueur scripté de l'oracle ;
   `STATION_CAPTURE_APRES=<s>` photographie un service en cours. Vérifié sur
   Darlington graine 1 à 07:09 et 07:20 : tout ce que montre l'image se déduit
   de l'état, y compris la loco à gauche d'un convoi entré par la droite.

   Ce qu'il n'a pas encore, et que le prototype a : les sons, le tutoriel, la
   chronologie et la barre de service, les pilules de retour au geste, le
   glissement de l'embarquement, la file en réduction. Et la journée se tire
   au démarrage, en synchrone — 1,3 s sur Darlington, 5,6 s sur Bruxelles-Midi
   — là où il faudra un fil d'exécution et le pré-tirage pendant le relevé.

À l'étape 3 et à l'étape 5, il existe une **oracle** : le prototype. Faire
tourner les deux sur la même graine et comparer les sorties est le meilleur test
de non-régression disponible, et il ne coûte rien à écrire.

---

## Où sont les règles

Ce document ne les remplace pas :

- `meta-progression-jeu-aiguillage.md` — le design (les quatre niveaux, la
  construction d'une carte, les récompenses, le modèle de données).
- `ruban-europe.md` — le tracé : 9 actes, 95 chapitres, 593 gares. Autorité sur
  l'itinéraire, y compris pour les 316 gares que le prototype n'écrira pas.
- `tools/AUTHORING-STATIONS.md` — écrire une gare. Obligatoire.
- `tools/AUTHORING-CARTES.md` — écrire une carte.
- `data/cartes/README.md` — le schéma d'une carte.
- `plan-de-dev.md` — les lots, ce qui est fait et ce qui est reporté.
