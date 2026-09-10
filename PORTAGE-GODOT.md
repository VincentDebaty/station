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
change (`user://` au lieu de localStorage). Fait le 3 septembre 2026 :
`jeu/sauvegarde.gd`, étape 6 du §8.

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
position sur le ruban. **Tout est déduit, rien n'est stocké.** Transposé le
3 septembre 2026 en `jeu/ruban.gd` — voir l'étape 5 du §8.

### `js/recompense.js` — 352 lignes, la récompense

Étoiles, rangs de chapitre, **26 médailles**, crédits. Déduit également.
Transposé le même jour en `jeu/recompense.gd`.

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
SEC_PER_GAMEMIN   4.0     1 minute de jeu = 4 secondes réelles à ×1, aux niveaux 1-2
TEMPS             4 · 4 · 3,5 · 3 · 2,5   les secondes d'une minute, par niveau (ruban.js / ruban.gd, 10 septembre 2026)
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

Minutes de retard tolérées pour trois étoiles, **par palier de difficulté**
(serré le 10 septembre 2026, `difficulte-et-merite.md` lot 1 — c'était
12 → 8 et 20) :

| palier | 3 ★ | 2 ★ | 1 ★ |
|---|---|---|---|
| 1 | 8 | 15 | 30 |
| 2 | 7 | 15 | 30 |
| 3 | 6 | 15 | 30 |
| 4 | 5 | 15 | 30 |
| 5 | 4 | 15 | 30 |

Une étoile reste à **30 partout** : c'est le plancher qui rend le ruban
praticable.

**Le retard se compte au dixième** (même jour). Le retard brut d'un départ
(`lateness`, tolérance `DEPART_GRACE` déduite) s'additionne tel quel dans
`totalDelay` / `total_delay` ; c'est le TOTAL qui s'arrondit, une fois, au
relevé. Avant, chaque convoi n'encaissait que sa minute entière : un train
parti 1,14 min après son heure pesait zéro, et un diamant tolérait une minute
par convoi. « À l'heure » (série, carillon) veut dire à zéro, donc sous la
tolérance ; la pastille écrit « + 0,8 min » dès que le retard coûte.
`oracle-enclenchement` compare les deux implémentations sur le total et les
étoiles.

### Le barème des pièces (`recompense.js` / `recompense.gd`, 10 septembre 2026)

```
étoile 10 · minute sous le seuil 3 ★ 1 (0..12)
chapitre d'or 200 · zone 1 000 · carte 5 000
médaille 50 / 150 / 500 · passage 50 + 30 × chapitre · le Rhin 15 000
```

Le sans-faute vaut 50 pièces et le chapitre de diamant 500 : la pierre qui se
dépensait à leur place (schéma 8) a été retirée le jour même de sa livraison.

Tout est déduit, rien n'est stocké : `oracle-ruban` compare les deux
implémentations sur douze scénarios, dont trois cartes mixtes à trous. Les
RAPPORTS sont l'invariant mesuré (un passage ≈ trois à cinq gares bien
jouées ; finir l'Europe paie le Rhin avec de la marge), pas les valeurs.

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

9. **Comparer deux Variants de types différents est une ERREUR en GDScript, pas
   un `false`.** `cfg.sameSidePairs !== "all"` passe en JavaScript quel que soit
   le contenu ; en GDScript, `[] != "all"` lève « Invalid operands 'Array' and
   'String' » — et `sameSidePairs` est tantôt `"all"`, tantôt une liste de
   paires. Mesuré le 3 septembre 2026 sur `plafond_de_flux` : 401 erreurs,
   aucune valeur fausse. Tester le type avant de comparer
   (`ssp is String and ssp == "all"`). Seule la comparaison à `null` est
   tolérante.

10. **`JSON.stringify` de Godot TRIE les clés d'un dictionnaire ; son
    analyseur, lui, conserve l'ordre du document.** Mesuré le 3 septembre 2026 :
    `{"germanie": 1, "europe": 2}` sort `{"europe":2,"germanie":1}`. Une
    sauvegarde relue avait donc ses cartes dans un autre ordre que le
    prototype — rien de faux, mais plus la même sauvegarde, et l'oracle l'a
    vu au premier rechargement. Tout ce qui doit se relire à l'identique
    s'écrit avec `Sauvegarde.vers_json` (ordre d'insertion, entiers sans
    décimale, comme JavaScript). Au passage, mesuré le même jour : les
    autoloads se chargent bien sous `--script` en 4.7, mais APRÈS `_init()`
    du SceneTree — dans `_init`, `root.has_node("Donnees")` est faux — et leur
    `_ready` s'exécute même quand `_init` a déjà appelé `quit()`. C'est ainsi
    que l'autoload `Sauvegarde` a laissé une v7 vierge dans le vrai `user://`
    à chaque oracle : sans conséquence (il n'écrit que ce qui n'est pas au
    schéma courant), mais un oracle qui veut un support à lui l'instancie à
    la main, sur son dossier. `--check-only`, lui, ne les charge pas du tout
    (piège 6 du §8).

11. **Un Label qui se replie n'a plus de largeur minimale.** Dans une rangée
    (HBoxContainer), un Label en `AUTOWRAP_WORD_SMART` sans expansion se
    réduit à zéro et s'écrit LETTRE PAR LETTRE, en colonne — les compteurs
    « 0 cr » et « ★ 0 » du ruban, à la première capture. Un texte long se
    replie ; un compteur ou une mesure, jamais (`_label(…, replie = false)`).

12. **Un anneau de Natural Earth se ferme sur son premier point répété, et
    le triangulateur en fait un dernier triangle dégénéré** — un par anneau,
    mesuré sur les 68 anneaux d'Europe. Et une oreille peut encore traverser
    le polygone sans s'inverser : la Grande-Bretagne (781 points) gardait un
    triangle dont le centre tombe hors de l'anneau. Retirer le point répété,
    puis passer l'anneau par Clipper (`Geometry2D.merge_polygons` avec rien)
    : zéro triangle hors anneau après. Au passage, une lecture trop rapide de
    la capture zoomée avait pris la mer du Nord pour un défaut de rendu ; ce
    qui a tranché, c'est la mesure du centre des triangles, pas l'œil.

13. **Un Control aux ancres pleines sous un Node2D n'a aucun parent à
    remplir : sa taille est zéro.** La carte d'accueil du tutoriel, centrée
    dans un CenterContainer ancré plein sous l'écran de jeu (un Node2D), se
    centrait sur l'origine, hors écran — et le service restait gelé derrière
    un voile sans bouton. Trouvé par Vincent au premier lancement, le 3
    septembre 2026 ; mes captures ne l'avaient pas vu parce que le lancement
    direct (`STATION_JOUER`) construisait et montrait la carte dans la même
    image, avant que la mise en page ne retombe. Sous un Node2D, les Controls
    reçoivent une `size` explicite, pas des ancres — et une vérification
    passe par le chemin du joueur (`STATION_PILOTE`, un clic sur « Jouer »),
    pas par un raccourci.

14. **`max()` rend un Variant dès qu'on mélange les types, et l'inférence
    `:=` échoue en cascade.** `var w := max(20.0, police.get_string_size(…).x)`
    refuse de compiler, et toute variable qui en dépend refuse à son tour —
    l'erreur signalée est trois lignes plus bas que la cause. Annoter
    (`var w: float = max(…)`) suffit.

15. **La largeur d'un drapeau ne se mesure pas.** Un drapeau est une paire de
    caractères combinés, que la police système rend en un glyphe unique dont
    `get_string_size` rapporte une largeur fausse : le nom de la gare
    débordait de sa chip. On lui réserve une largeur fixe.

---

## 5 bis. POSER LE JEU SUR UN iPHONE

`tools/ios.sh` fait tout — export, signature, installation, lancement — et
`tools/ios.sh --etat` dit ce qui manque. Il y a **une seule chose qu'aucun
script ne peut faire** : ajouter un compte Apple à Xcode. Il y faut un mot de
passe et une double authentification, donc une main humaine, une fois pour
toutes (Xcode → Réglages → Comptes → + → Apple ID). Un compte GRATUIT suffit
pour son propre téléphone ; l'app expire alors au bout de sept jours et se
réinstalle en relançant le script.

La première fois seulement, il faut aussi ouvrir `build/ios/Station.xcodeproj`
et cocher « Automatically manage signing » avec son équipe : Xcode crée le
profil et enregistre l'appareil. Ensuite le script se débrouille seul.

**Le choix de l'équipe n'est pas neutre.** La seule équipe présente sur la
machine de Vincent est celle de sa société ; l'utiliser enregistrerait un
identifiant d'app dans un compte développeur d'entreprise, pour un projet
personnel. Un Apple ID personnel l'évite.

**Deux pièges mesurés le 3 septembre 2026 :**

· **L'export iOS refuse avec un message VIDE en ligne de commande** quand le
projet n'active pas la compression de texture ETC2/ASTC — l'avertissement ne
vit que dans le bandeau de la fenêtre d'export de l'éditeur. Une heure de
suppositions à l'aveugle, puis l'éditeur ouvert a tout dit en une ligne rouge.
**Quand la ligne de commande se tait, ouvrir l'éditeur.** Le réglage est
désormais dans `project.godot` (`textures/vram_compression/import_etc2_astc`).

· **Le simulateur iOS est une impasse** : l'exportateur de Godot 4.7 ne produit
que l'architecture de l'appareil (`arm64`), et l'édition de liens pour le
simulateur échoue sur un `_main` introuvable. D'où `STATION_TACTILE=1`, qui
force au bureau le régime du téléphone (UIK 1,5, facteur de bandeau 1,93 —
ce que la mesure donne sur un iPhone en paysage). C'est le seul moyen de voir
la passe tactile sans appareil, et il a servi tout de suite : la ligne de mise
au point débordait de l'écran une fois grossie.

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
- ~~Le barème des crédits~~ Tranché le 10 septembre 2026 : la pièce, ×10,
  précision et médailles (`economie-du-jeu.md`, §4 ci-dessus). Finir l'Europe
  en or rapporte ≈ 32 000, le Rhin coûte 15 000.
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

   ✅ **Fait le 3 septembre 2026.** `jeu/ruban.gd` (la carte, le catalogue et
   la progression sont INJECTÉS — pas d'autoload, pas de sauvegarde : un
   `Ruban.new(carte, fiches)` avec `stations` et `passees` posés dessus) et
   `jeu/recompense.gd` (tout statique, prend le ruban en paramètre ; la série,
   les cartes enregistrées et les cartes possédées viennent de l'appelant,
   c'est-à-dire de l'étape 6). L'oracle `tools/oracle-ruban.mjs` +
   `jeu/oracle_ruban.gd` évalue `ruban.js` et `recompense.js` dans un
   `node:vm` avec une fausse sauvegarde, et compare sur **les deux cartes ×
   six progressions** (vierge, début, complète, trois tirages mixtes à graine
   fixe avec trous, gares payées, et une gare hors ruban enregistrée) : par
   chapitre le plancher, l'arrivée, le rang ; pour chacune des **348 gares** la
   difficulté jouée, le plafond, le barème, la fiche de service
   (`difficulty` + `gen`), le boss, les cinq états, le niveau, le prix de
   passage et le verdict R10 ; puis position, zones, état des récompenses, les
   26 médailles, les crédits, une grille de 130 retards et 36 enveloppes.
   **12 scénarios sur 12 identiques**, Godot en 619 ms.

   `carte-check` continue d'évaluer `js/ruban.js` — c'est la référence
   exécutable, et R10 rend le même verdict sur les deux cartes après l'étape
   (« toutes les gares jouent sous leur brevet »). L'oracle prouve que
   `jeu/ruban.gd` calcule la même rampe gare par gare, y compris le régime
   boss ; le contrôle n'a donc pas à lire du GDScript.

   L'enclenchement a perdu sa copie du barème : `Enclenchement.seuils` est
   posé par l'écran de jeu depuis `Ruban.seuils_de_service`, et vide il
   retombe sur `Ruban.seuils_de_fiche` — le chemin sans carte du prototype,
   toujours mesuré identique par `oracle-enclenchement` (Darlington, Namur,
   Stuttgart, graine 1). L'écran de jeu choisit la carte qui porte la gare
   (`STATION_CARTE=<id>` pour forcer) et joue `fiche_de_service` : Darlington
   ouvre au niveau 1 avec une fiche écrite à 3, Namur joue 4 (fiche 3), et
   une gare qu'aucune carte ne porte (Louvain) joue sa fiche telle quelle. Le
   bandeau dit désormais « europe, niveau 4 (fiche 3), 3 étoiles sous 9 min ».
6. **La sauvegarde** (`store.js`) : `makeBackend()` seul change. Tester une
   migration depuis une sauvegarde du prototype.

   ✅ **Fait le 3 septembre 2026.** `jeu/sauvegarde.gd`, autoload
   `Sauvegarde` : le support est `user://`, un fichier par clé, la MÊME chaîne
   JSON sous la MÊME clé que localStorage (`station-progress.json`) — seuls
   `_lire` et `_ecrire` connaissent le disque, comme `makeBackend()` le
   promettait. `migrer()` transpose `migrate()` schéma par schéma, y compris
   la vérité JavaScript (`x | 0`, `||`, `typeof "object"` qui accepte un
   tableau). `STATION_SAUVEGARDE=<dossier>` détourne le support pour un essai,
   `STATION_SANS_TRACE=1` n'écrit rien.

   L'oracle `tools/oracle-sauvegarde.mjs` + `jeu/oracle_sauvegarde.gd` fait
   jouer `store.js` dans un `node:vm` avec un localStorage en mémoire, et la
   sauvegarde Godot dans un dossier de travail, sur **18 sauvegardes de
   départ** — une par schéma de v0 (objet plat) à v7, et les cas tordus :
   absente, vide, `null`, JSON invalide, un nombre, une série en chaînes, une
   version en chaîne, une version future, des cartes en tableau — puis **29
   écritures identiques** des deux côtés (tentée, résultat amélioré puis non,
   série qui monte, bat, casse, passage payé deux fois, changement de carte,
   acquisition, préférences), en notant chaque valeur rendue, l'état lu, le
   FICHIER écrit, et l'état après rechargement à neuf. **18 sur 18
   identiques**, Godot en 245 ms. Le premier passage en avait 17 : le piège 10
   du §5, attrapé au rechargement.

   La vraie sauvegarde de Vincent n'a pas pu servir : elle est dans son
   navigateur, hors de portée d'ici (le navigateur intégré n'a qu'une v7
   vierge). Les dix-huit sauvegardes forgées couvrent chaque branche de
   `migrate()` ; le jour où une vraie sauvegarde ancienne se présente,
   `--fixture=<fichier>` l'ajoute à la batterie.

   L'écran de jeu écrit sa fin de service comme `endGame` : échec → gare
   tentée sans record, réussite → meilleur score et meilleur retard, puis la
   série ; les médailles se comparent avant/après et se disent au journal.
   Jouer une gare, c'est jouer SA carte : le ruban lit la progression vivante
   de la carte courante. Mesuré : Darlington joué deux fois sur un dossier de
   travail — « 1★, retard 28, position 1/277 », puis au redémarrage « 1★,
   retard 25 » : le record s'améliore, l'étoile reste, la position tient.
7. **Les écrans** : ruban, cartes, relevé, tutoriel. En dernier, parce que c'est
   la partie qu'on jette et refait le plus volontiers.

   ✅ **Fait le 3 septembre 2026.** `jeu/app.tscn` est la scène principale :
   `jeu/app.gd` tient le ruban de la carte courante et sa progression vivante,
   et passe la parole à trois écrans. `jeu/vue_ruban.gd` transpose
   `js/parcours.js` — la projection cadrée sur le ruban (160 × 100, étirement
   1,6), la caméra sur le voisinage de quatre gares (zoom log-interpolé,
   0,75 s, 1,5 s pour un saut), le rail du seul chapitre vu avec ses quatre
   états, les gares et leurs étoiles, le fond des pays en Polygon2D sous la
   caméra ; le panneau de gauche porte les compteurs (série, grade et jauge,
   crédits, diamants, étoiles), le chapitre et sa jauge à crans, le cartouche
   de la gare qui vient (quais, directions, difficulté, barème, phrase), le
   relevé du service (étoiles, retard, record, seuil visé, deux médailles), la
   fête de chapitre (butin, rang, ce qui reste, zone, toutes les médailles), et
   les boutons du prototype mot pour mot : Jouer · <ville>, Rejouer, Réessayer,
   Passer · N cr avec le manque dit. Le voyage de fin de chapitre se joue
   PENDANT la lecture du bilan, comme le prototype depuis le 1er septembre.
   `jeu/vue_cartes.gd` transpose `vueCartes` (tuiles, avancement, Reprendre /
   Commencer / Ouvrir · prix / manque, carte bancaire inerte). L'écran de jeu
   s'emboîte (`demarrer`, `‹ Carte`, Échap) et rend la main avec son relevé
   1,2 s après la fin, comme `endGame → showHub`.

   **Le tutoriel** transpose l'accueil de `js/game.js` : la carte de
   bienvenue, puis le repère (cerne pulsé + bulle, service gelé) sur le premier
   train, son quai desservant (avec le piège des quais éclairés qui ne
   desservent pas tous), le retard, l'arrêt à quai, le deuxième train, son
   quai, l'objectif — puis deux repères opportunistes, le feu rouge et
   l'accélération. Ne s'affiche qu'une fois (`Sauvegarde.set_accueilli`).

   **Vérifié sans personne devant** grâce à `jeu/pilote.gd`
   (`STATION_PILOTE="1.5 clic 700 461 | 9 clic 70 645 | 10 capture …"`) : sur
   la graine 37162, Commencer → le repère sur le train de Bishop Auckland →
   le quai 5 désigné, les deux quais éligibles allumés → le retard pointé avec
   « Suivant ». Le relevé d'un échec revient sur la carte (☆☆☆, 30 min,
   objectif manqué, « Il te manque 5 crédits », Passer grisé, Réessayer) ; une
   sauvegarde forgée à quatre gares sur cinq puis Leeds gagné à trois étoiles
   par le joueur scripté (graine 2) donne la fête : 12 / 15 ★, 1 ◆, trois
   médailles, « Chapitre suivant · Le Yorkshire noir », et la caméra posée sur
   Wakefield. `STATION_ZOOM=1` photographie le continent entier.

   Ce qui n'est PAS repris, volontairement : les sons, les confettis, la
   remontée animée du compteur d'étoiles, l'aide « ? », les confirmations de
   sortie et de remise à zéro, la démo « limites » (`station.html?fin=`). Ce
   sont les finitions du moteur, et le prototype les garde en référence.

   **L'HABILLAGE, passe du 3 septembre 2026.** Les écrans transposaient la mise
   en page et les règles, pas la feuille de style : primitives brutes, police de
   secours du moteur. Vincent, capture à l'appui : « on est quand même loin du
   design de la version web ». C'était vrai, et c'était trop tôt pour le
   remettre aux finitions — la lisibilité d'un quai éclairé ou d'un badge change
   la façon de jouer, donc elle fait partie de ce qu'on teste.

   `jeu/style.gd` porte désormais `css/station.css`, valeur pour valeur, avec la
   source en commentaire : les couleurs de `:root`, le verre dépoli des chips
   (rgba(21,29,46,.55), liseré #2a3550, coins de 12), le dégradé des quais
   (#243049 → #161f30, coins de 10), les rayons des caisses (8 pour la loco, 5
   pour un wagon), les quatre couches du halo d'état ([16, .10], [10, .18],
   [5.5, .34], [2.5, .75]), le badge (72 × 20, coins de 6, fond
   rgba(14,20,32,.88)), et les deux piles de polices du web — SF Pro / Segoe UI
   pour l'interface, SF Mono / Menlo pour l'horloge et les badges, chargées par
   `SystemFont`.

   Ce que Godot n'a pas, et comment on le rend : le `filter: drop-shadow`
   devient l'ombre d'un `StyleBoxFlat` (une boîte) ou deux passes larges et
   translucides sous le trait (une ligne) ; le `letter-spacing` devient
   `Sty.texte_espace`, qui pose les caractères un par un ; les
   `stroke-dasharray` deviennent `Sty.pointille`, qui suit un contour arrondi en
   abscisse curviligne et sait défiler (le liseré du quai promis avance de 12 px
   par 1,1 s, comme `claim-march`).

   Sont revenus avec la passe, et se jouent : le gril qui s'éclaircit sur la
   ville d'origine du convoi choisi (.beam-lit), les quais éligibles en
   pointillé pulsé et teinté à 14 % (le souffle plus lent quand le quai est
   encore occupé — « oui, mais pas tout de suite »), le liseré intérieur du quai
   promis, le liseré rouge du quai en défaut, les hachures et l'heure de
   réouverture d'un quai fermé, le halo d'état blanc ou ambre autour d'un convoi
   choisi ou retenu, la jauge d'embarquement qui remplit les voitures de la tête
   vers la queue, le signal d'arrêt planté devant une motrice retenue, le badge
   à cadran d'horloge (10 h 10, la pose qui se lit le mieux en tout petit) qui
   clignote quand un convoi à l'arrêt prend du retard, l'horloge et sa jauge de
   service, « EN PAUSE », les trois boutons du bandeau, le cartouche de gare
   avec son drapeau et ses cinq crans de difficulté, et le PROJECTEUR du
   tutoriel — tout l'écran s'assombrit sauf la cible, ce que l'ombre de 9 999 px
   de `#coach-ring` fait sur le web.

   Aucune règle n'a bougé : les quatre contrôles et les deux oracles rendent le
   même verdict qu'avant la passe.

   **LE DOIGT, passe du 3 septembre 2026**, avant le premier essai sur iPhone.
   Deux facteurs, et ils ne disent pas la même chose (`jeu/style.gd`,
   `calibrer`) :

   · `UIK` reprend le facteur du prototype (`js/render.js`) : **1,5 sur écran
   tactile**, appliqué à la hauteur des caisses, aux rayons, au halo d'état, aux
   badges, au signal d'arrêt et aux zones de clic. `CAR_LEN` ne bouge JAMAIS :
   la longueur d'une voiture tient à `CAR_SPACING`, et l'étirer ferait se
   chevaucher les convois. C'est la valeur que Vincent a validée sur son iPhone
   avec la version web ; on la reprend telle quelle.

   · `HUD_K` n'a pas d'équivalent web, et c'est justement pourquoi il faut
   l'écrire : le prototype tient son bandeau en **pixels CSS**, qui valent un
   point d'écran sur l'appareil — une chip de 34 px fait 34 points sur un iPhone
   comme sur un Mac. Sous Godot le bandeau vit dans le viewport étiré : la même
   chip tomberait à trois millimètres sur un téléphone. `HUD_K` garde donc au
   bandeau sa **taille physique**, celle qu'il a au bureau — mesurée à 127,5
   unités par pouce le 3 septembre 2026 (fenêtre 1400 points, échelle 2,
   255 dpi). Au bureau il vaut 1, et rien ne change.

   Trois choses ne s'ancrent plus sur 1400 × 760 mais sur le viewport RÉEL : le
   bandeau, le projecteur du tutoriel et la carte d'accueil. Avec
   `stretch: expand`, un écran plus allongé qu'un 16/9 donne un viewport plus
   LARGE que la base — les boutons de droite seraient sortis de l'écran.

   Et surtout : **les boutons du bandeau sont devenus des cibles.** Ils étaient
   dessinés sans être cliquables, ce qui ne se voyait pas au bureau (tout passe
   par le clavier) mais rendait la pause, la vitesse et le retour à la carte
   INATTEIGNABLES sur un téléphone. La pilule « EN PAUSE » reprend aussi le
   service, comme dans le prototype. L'engrenage rejoue la journée en attendant
   son menu de réglages — il l'a eu le 9 septembre, voir juste en dessous.

   **LES SONS ET LE VOLET DE RÉGLAGES, passe du 9 septembre 2026.** L'engrenage
   ne faisait pas ce que son icône promet : il rejouait la journée en silence,
   sans un mot — un geste destructeur sous un bouton de réglage. « Le bouton
   settings dans une gare ne fonctionne pas » (Vincent). Il déplie désormais
   deux pastilles, au gabarit des trois du bandeau, comme `#hud-controls` du
   prototype : le son, et recommencer. La troisième du prototype — l'aide — n'a
   pas suivi : c'est un long texte HTML, et le portage a le tutoriel guidé à sa
   place. Recommencer un service en cours pose la question du prototype
   (`#confirm-reset`), et la modale d'abandon a été rendue réutilisable pour
   la porter.

   Un interrupteur de son n'a de sens que s'il y a du son : **`jeu/sons.gd`
   transpose les signatures de `js/render.js`**, et le principe avec elles —
   aucun fichier, rien à télécharger, une ambiance de poste et pas une fanfare.
   Là où WebAudio recalcule chaque note, on cuit les quatorze signatures UNE
   FOIS au démarrage dans un tampon PCM : **91 ms, 219 ko** (mesuré au bureau,
   `STATION_MESURE=1 STATION_SONS_MESURE=1`). Mêmes fréquences, mêmes durées,
   même enveloppe — 20 ms de montée droite puis une extinction exponentielle —
   et les pics relevés valent exactement les `vol` de `playTone` : 0,050 pour
   l'annonce, 0,061 pour le fret (deux dents de scie superposées), 0,035 pour
   l'incident. Les oscillateurs de WebAudio sont à BANDE LIMITÉE, pas les
   naïfs : un carré obtenu par `sign(sin)` remonte à l'infini et se replie en
   criaillements. On les reconstruit donc par addition d'harmoniques bornées
   par Nyquist, plafonnées à 24 — au-delà, 1/n et 1/n² ne s'entendent plus.

   **L'enclenchement ne joue rien.** Il n'a ni scène ni haut-parleur, et
   l'oracle le rejoue mille fois par seconde en tête-à-tête avec `game.js` : il
   se contente d'empiler des noms dans `sons`, aux six endroits exacts où
   `game.js` appelle `SND.*`, et `vue_jeu.gd` vide la file à chaque image.
   Aucune règle n'a bougé : `oracle-enclenchement` donne 4 fiches identiques
   sur 4 (Leeds, Darlington, Northallerton, York), `oracle-sauvegarde` 18 sur
   18, et les quatre contrôles restent verts.

   Reste à vérifier sur l'appareil : iOS coupe les catégories audio « ambient »
   avec l'interrupteur de sonnerie. Si le son se tait alors que le volet le dit
   ouvert, c'est là qu'il faut regarder.

   **LA REMISE DES RÉCOMPENSES, passe du 9 septembre 2026.** Le service gagné,
   l'écran du ruban s'ouvrait sur son relevé DÉJÀ ÉCRIT : trois étoiles
   apparaissaient dans un coin du panneau, et rien ne disait qu'on venait de
   les gagner. « Il faut animer tout cela » (Vincent). Trois temps, dans son
   ordre : les étoiles arrivent en grand au milieu de l'écran et rejoignent
   leur place sur la feuille ; le diamant fait le même chemin ensuite ; enfin
   une puce de laiton traverse la voie vers la ville suivante, sa traîne
   allumée derrière elle.

   Deux choses portent tout le reste. La première : **la place d'arrivée n'est
   pas calculée, elle est LUE** — le vol vise le `Label` qui porte les étoiles
   dans le relevé, et c'est ce même Label qu'on masque jusqu'à l'atterrissage.
   La feuille peut changer de hauteur, de police ou de contenu, le vol tombe
   toujours juste, et la récompense n'est jamais en place avant d'y arriver.
   La seconde : **la couche de vol est le DERNIER enfant de la vue** — un
   enfant se dessine après son parent, et le panneau est un enfant ; une étoile
   peinte dans le `_draw` de la vue passerait derrière l'endroit même où elle
   doit atterrir.

   **Le diamant n'est plus un glyphe.** « Il est petit et discret alors que
   c'est la plus haute récompense d'une partie » (Vincent, le même jour) : il
   valait exactement une étoile de plus. C'est maintenant une pierre TAILLÉE,
   dessinée facette par facette — table, couronne, culasse, chacune sa nuance,
   plus un éclat blanc sur le pan qui prend la lumière —, une fois et demie
   plus grande qu'une étoile, dans une gerbe de douze rais, tenue trois quarts
   de seconde sous son titre SANS FAUTE. Elle atterrit sur un sceau cerclé de
   sarcelle, et non plus sur une ligne de texte de 14 qui pesait autant qu'un
   « 7 min de retard ».

   **La carte est devenue cliquable pour de bon.** Elle l'était déjà, mais d'un
   seul geste : toucher une gare la LANÇAIT. Désormais la gare qui vient part
   d'un doigt — elle est déjà décrite sur la feuille, il n'y a rien de plus à
   lire —, et toute autre gare tenue se POSE dans le panneau, avec sa fiche
   complète et son bouton ; une gare verrouillée ne fait rien. La cible n'est
   plus le seul point de 16 unités (huit points sur l'iPhone, moins d'un tiers
   de pulpe) : le nom compte aussi, et le rayon suit `HUD_K`.

   **Et le ruban est devenu du rail sur toute sa longueur** (même jour) : « il y
   a juste une simple ligne pour aller au chapitre suivant, la logique voudrait
   que ce soit des rails aussi » (Vincent). Deux causes derrière ce trait. Les
   courbes se construisaient PAR CHAPITRE, si bien que la liaison qui mène au
   chapitre suivant n'avait aucun tracé et retombait sur la droite de secours ;
   elles se construisent désormais par SUITES, coupées seulement par un saut —
   un saut n'est pas du rail et garde son pointillé. Et le reste du ruban se
   dessinait au fil de fer, une polyligne de 1,3 : c'est maintenant la même
   voie que partout, en plus fine et en plus sourde.

   Avec un NIVEAU DE DÉTAIL, parce que le rail se paie : une voie, ce sont deux
   files et une traverse toutes les dix unités. Au zoom du chapitre il y a une
   dizaine de liaisons en vue et cela ne coûte rien (120 images par seconde,
   plafond de synchro) ; quand la caméra recule sur le continent — pendant un
   saut, ou avec `STATION_ZOOM` — il y en a 271, et l'écran tombait de 78 à
   34 images par seconde au 1600 × 736. En dessous de cinquante unités une
   liaison n'a de toute façon pas de traverses lisibles : elle repasse en
   trait, et toutes les courtes en UN SEUL `draw_multiline` — 271 polylignes
   séparées coûtaient encore vingt images par seconde à elles seules. Mesuré à
   73 contre 78, pour un mode qui ne sert qu'à la photographie.

   **PRENDRE UN SERVICE NE GÈLE PLUS L'ÉCRAN** (même jour). « Quand je clique
   sur le bouton Jouer, j'ai une seconde d'attente avant que le jeu commence,
   il faudrait montrer que cela charge. On a l'impression que cela bug »
   (Vincent) — et ce n'était pas une impression : le tirage d'une journée, la
   seule opération lourde du jeu, tenait sur le fil principal. Une seconde sur
   Darlington, cinq et demie sur Bruxelles-Midi, pendant lesquelles AUCUNE
   image ne pouvait s'afficher. C'est aussi pourquoi une pancarte n'aurait rien
   réglé : un écran gelé se lit comme un plantage, animé ou non.

   `demarrer` se coupe donc en trois, et la coupure est la vraie affaire :
   `commande()` dit ce qu'il faut savoir (immédiat) ; `preparer()` fait le
   calcul lourd — géométrie, journée, enclenchement — et ne touche à AUCUN
   nœud, ce qui est la condition pour partir sur un `Thread` ; `installer()`
   pose les nœuds et l'état au retour. `demarrer` enchaîne les trois d'un coup
   pour l'oracle, les captures et le mode autonome, où personne ne regarde.
   `STATION_JOUER=1` prend le même chemin pressé : un fil ferait photographier
   un écran d'attente.

   `jeu/attente.gd` est ce qu'on regarde pendant : une `CanvasLayer` au-dessus
   de tout, sur le fond du POSTE — on va vers le poste, arriver sur la même
   couleur fait de l'attente le début du service au lieu d'un écran de plus.
   Le convoi ne bouge pas, c'est la voie qui défile : le regard reste sur la
   machine, la vitesse se lit aux traverses, et le nom de la gare tient sa
   place dessous. Les planches de véhicules sont celles du jeu.

   Deux garde-fous. Un écran d'attente qui CLIGNOTE est pire que pas d'écran :
   une petite gare se tire en 160 ms sur un Mac. Il ne s'ouvre donc qu'au-delà
   de 140 ms, et une fois ouvert se tient 650 ms au moins. Et le fil se rejoint
   à la fermeture (`NOTIFICATION_WM_CLOSE_REQUEST`), sans quoi le moteur aboie
   — et iOS plante à la sortie.

   **LA PROJECTION OBLIQUE, posée le 9 septembre 2026** après une maquette
   (`jeu/maquette_oblique.gd`, gardée). « Les rails semblent en 3D vue de côté
   mais le train en 2D vue d'en haut. Pourrait-on avoir une vue effet 3D de
   côté ? » (Vincent). Une ÉLÉVATION pure était exclue, et pas par goût : les
   onze quais de Madrid-Chamartín s'y superposeraient en une seule ligne, et un
   croisement — qui EST le conflit — deviendrait invisible. Un poste
   d'aiguillage se lit en plan, et les vrais aussi.

   Ce qui est appliqué est un CISAILLEMENT AFFINE, donc qui conserve les
   incidences : deux voies qui se croisent se croisent encore, une courbe reste
   une courbe, onze quais restent onze. `p' = C + ((x−Cx) + (y−Cy)·0,22 ,
   (y−Cy)·0,86)`, dans `jeu/oblique.gd`, appliqué au DESSIN seulement —
   `geometrie.gd` n'a pas bougé d'une décimale, et l'oracle le confirme (pire
   écart 1,1 × 10⁻¹³ sur York et Madrid).

   Les trois chiffres sont mesurés, pas choisis. **0,22** contre 0,45 : le
   franc était plus spectaculaire mais écrasait les quais et gaspillait la
   hauteur. **0,86** rend de la place verticale au lieu d'en prendre — c'est le
   cisaillement qui élargit, et l'élargissement part dans les marges où filent
   déjà les voies d'entrée et de sortie (`EDGE_RUN` = 360) ; rien n'a donc eu à
   être réduit. **8 d'épaisseur** est un PLAFOND relevé sur les 401 fiches :
   deux quais voisins ne sont séparés que de 10 unités au plus serré, soit 8,6
   après aplatissement. Au-delà, la face avant passe derrière le quai suivant
   et disparaît.

   Trois règles tiennent tout le reste. **Le texte ne se projette jamais** — on
   projette sa PLACE, pas sa forme : un chiffre de quai cisaillé serait
   illisible. **Ce qui est debout reste debout** : un signal est un mât
   vertical, vu de biais il reste vertical à l'écran et seul son pied se
   déplace ; idem pour les pastilles d'heure. **Les traverses se calculent dans
   le plan puis se projettent**, sinon elles sont perpendiculaires à l'écran
   au lieu de l'être à la voie, et trahissent la projection à chaque courbe.

   Le doigt n'a coûté qu'une ligne : `Ob.inv(m − decalage())`. Toutes les zones
   de clic restent écrites dans le plan, et aucune n'a bougé.

   **LES VÉHICULES SE TIENNENT DEBOUT, 9 septembre 2026.** L'oblique posée, les
   convois restaient des TOITS — « pas très fan, les trains sont toujours vus
   de haut » (Vincent) — et c'était sans issue par le code : un flanc peint à
   la main sous la caisse ne fait, sans dessin dessus, qu'un pan de couleur
   uni (essayé à 5 puis à 9, revenu à 5, puis retiré). Vincent a redessiné les
   trois planches en ÉLÉVATION — toit, joue, roues — et c'est le montage qui
   change avec elles.

   Un véhicule est désormais un panneau DEBOUT : son arête basse suit la voie
   projetée, donc il s'inscrit dans les courbes case par case comme avant, et
   il monte à la verticale de l'écran. C'est exact pour cette projection, qui
   n'aplatit que le sol et jamais les verticales.

   SA HAUTEUR NE SE RÈGLE PAS, ELLE SE LIT. La chaîne rogne chaque planche à la
   boîte de son sujet ; la case fait 35 unités de long ; la hauteur est donc le
   rapport de la planche, et rien d'autre. Locomotive 1,477:1 → 23,7 ; fourgon
   1,562:1 → 22,4 ; voiture longue 2,000:1 → 17,5. Le véhicule le plus long est
   le plus bas, sans qu'on décide rien.

   Deux corrections tombées avec : la couronne ambre du convoi retenu était
   peinte en coordonnées de PLAN, sans passer par la projection — elle tombait
   à côté de son train depuis l'oblique ; elle est maintenant une nappe de
   lumière au pied de la rame. Et la pastille d'heure partait de la voie à 32
   unités, ce qui tombait en plein toit depuis que la caisse se tient debout :
   elle part du sommet de la machine.

   **Attention au cache d'import.** Remplacer un PNG sous `jeu/illustrations/`
   ne suffit pas : une exécution (hors éditeur) lit la texture importée dans
   `.godot/imported/`, et affiche donc l'ANCIENNE planche. Après
   `tools/illustrations.sh`, il faut `godot --headless --path . --import`.
   J'y ai perdu une capture entière, à me demander pourquoi le montage neuf
   rendait les vieux tonneaux.

   L'écran d'attente a suivi : convoi debout sur sa voie, et la voie mesurée en
   FRACTIONS DE LA CASE — « tu peux faire les rails plus larges pour que cela
   s'adapte bien au train » (Vincent). Le convoi avait grandi, la voie non.
   Changer la taille du convoi déplace la voie avec lui ; il n'y a plus deux
   réglages à tenir d'accord.

   `STATION_REMISE=<étoiles>[,diamant]` rejoue la remise sur la gare courante,
   sans service et sans rien écrire : le joueur scripté n'a jamais fait de
   sans-faute, et sans ce crochet le deuxième temps ne se vérifierait qu'à la
   main. Cinq signatures de plus dans `jeu/sons.gd` — vingt en tout, 122 ms et
   302 ko au démarrage. `oracle-ruban` 12 sur 12, `oracle-sauvegarde` 18 sur
   18, `carte-check` et `net-check` verts.

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

   **LA BOURSE, passe du 10 septembre 2026** (`economie-du-jeu.md`, lot 1).
   « On ne se rend pas compte qu'on gagne des crédits, "cr" ne veut pas dire
   grand-chose » (Vincent). Mesuré sur trois captures : la pastille « 30 cr »
   affichait le solde d'APRÈS dès l'ouverture du relevé et ne bougeait pas
   pendant la remise ; les crédits ne figuraient ni dans le relevé ni dans la
   fête. Le crédit est devenu une **pièce** (`jeu/piece.gd`, frappée en laiton :
   tranche, champ, listel, roue, éclat — une seule pour tout le jeu), le
   barème a été multiplié par dix à rapports constants, la précision et les
   médailles paient (voir §4). Puis la remise a pris son **quatrième temps** :
   la ligne « + 90 pièces · étoiles 30 · avance 10 · sans-faute 50 » s'écrit
   sur le relevé au moment où les pièces en partent, six à dix pièces
   (logarithme du gain) décrivent un arc vers la pastille, qui SURSAUTE à
   chaque arrivée pendant que son nombre roule du solde d'avant vers celui
   d'après, un tintement montant par pièce et un accord à la fin. La pastille
   ne montre le solde d'après qu'à l'atterrissage (`solde_montre`), comme les
   étoiles restent creuses jusqu'au leur. Le montant est un DELTA du solde,
   photographié dans `app.gd` quand le service commence (`bourse_du_service`)
   — un rejeu qui n'améliore rien ne fait voler aucune pièce, et la mise
   rendue d'une gare payée se lit dans la dépense qui a baissé : elle a sa
   ligne, et ses pièces reviennent depuis la gare sur la carte.

   Le reste dit le barème là où il se reçoit : le butin itemisé de la fête
   (« Butin du chapitre · 250 pièces / chapitre d'or 250 »), les médailles avec
   leur bourse, « jusqu'à 215 pièces à prendre ici », et l'échec sans le sou :
   « Il te manque 50 pièces. Rejouer Darlington peut en rapporter 82. » — la
   gare tenue au plus grand manque à gagner, nommée. Payer se voit : cinq
   pièces quittent la pastille vers la gare passée, qui garde une pièce à
   côté de son nom tant que la mise n'est pas rendue. `STATION_REMISE`
   accepte `0` (un échec), `pieces=N`, `butin=N` et `rendu=N` pour tout
   photographier sans jouer. Trois signatures de plus dans `sons.gd`
   (`piece0..5`, `bourse`, `depense`).

   **LA PIERRE SE DÉPENSE, passe du 10 septembre 2026** (`economie-du-jeu.md`,
   lot 2). Le diamant avait deux natures dans un seul compteur. Séparées : le
   SANS-FAUTE est un fait de progression — sceau, cran bleu, rang, médailles,
   déduits de `bestDelay`, jamais achetés ni dépensés — et la PIERRE est
   l'objet qu'il produit, en poche, déduite elle aussi : sans-fautes + 3 par
   chapitre de diamant + `achats.diamants` − passages payés en pierres encore
   à zéro étoile (`passeesEnPierres`, à côté de `passees`). **Schéma 8**, trois
   champs vides à la migration ; `oracle-sauvegarde` 20/20 avec deux cas v8
   dont un tordu (`passeesEnPierres: "york"`, `achats: [5]`), et quatre
   écritures de plus (`payerPassageEnPierres`, `ajouterDiamantsAchetes`).
   `Ruban` porte `passees_pierres` ; `est_passee` lit les deux listes. Le
   sans-faute ne rend plus de pièces (le poste `sansFaute` a disparu du
   détail). À l'écran : la pastille des pierres dit le stock et monte d'un
   cran au moment où la gemme se pose sur son sceau (`pierres_montre`, même
   règle que `solde_montre`) ; quand les pièces manquent, le pied propose
   « Passer · 1 pierre » à la place, et « Il te manque 8 pièces, ou 1 pierre »
   ; les pierres partent de la pastille vers la gare avec la gerbe à
   l'envers ; la gare payée en pierres porte une gemme pâle ; « Mise rendue ·
   + 1 pierre » a sa ligne. Le prototype web suit (`data-payer-pierres`).

   **CE QUI SE VEND, passe du 10 septembre 2026** (`economie-du-jeu.md`,
   lot 3). Le modèle est tranché et écrit en données : `data/boutique.json`
   porte une offre par carte payante, trois lots de pierres et le pack ;
   `tools/boutique-check.mjs` refuse tout le reste (B1…B6, dont le garde-fou
   « la voie sans gloire coûte cinq fois la carte », mesuré à 5,4 pour le
   Rhin et 295 € pour l'Europe). `jeu/magasin.gd` est un autoload à trois
   dos : « plateforme » si le singleton `InAppStore` du greffon iOS est là
   (request_product_info, purchase, restore_purchases, pop_pending_event —
   ÉCRIT À L'AVEUGLE, le greffon n'est pas dans le dépôt et le magasin
   d'Apple ne se simule pas), « libre » sous `STATION_MAGASIN=libre` (le
   déblocage de débogage prévu au design : on accorde sans payer), « aucun »
   sinon (l'offre s'affiche, le bouton dit pourquoi il ne fait rien). Une
   seule porte, `acheter(id)`, un seul signal, `fini`. Accorder, c'est écrire
   dans la sauvegarde : `possedees[carte] = "achat"`, `achats.diamants += n`,
   `possessions["pack-du-poste"]` plus toutes les cartes — le reste se déduit.
   `jeu/boutique.gd` est la modale des pierres, ouverte depuis l'échec sans
   le sou et depuis le pied des cartes. Vérifié en mode libre, au pilote :
   acheter la carte la rend courante, le pack marque tout. Reste à exercer
   sur l'appareil : le greffon, les produits dans App Store Connect, et la
   restauration.

   **LES PIERRES SONT DÉFAITES, le 10 septembre 2026 au soir.** « Les pierres
   peuvent être supprimées. Pas une bonne idée. » (Vincent). Tout ce que la
   passe de la pierre avait posé est retiré : le stock en poche, le passage en
   pierres, la gemme pâle sur la carte, la mise rendue en pierres, la boutique
   des pierres et ses trois lots, `achats.diamants`. Le diamant est un
   trophée, il rend ses 50 pièces (500 par chapitre de diamant), et la
   pastille de la barre redit les sans-fautes. **Schéma 9** : les passages
   payés en pierres rejoignent `passees` à la migration — une gare passée
   reste passée, rien n'est perdu —, `possessions` reste pour le pack.
   `oracle-sauvegarde` 21/21 (un cas v9 de plus, la migration v8 → v9
   vérifiée des deux côtés), `oracle-ruban` 12/12, `boutique-check` B1…B4.

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
