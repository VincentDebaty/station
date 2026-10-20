# Station — le poste d'aiguillage

Jeu d'aiguillage ferroviaire, web (PWA), projet personnel de Vincent.
Dépôt GitHub `VincentDebaty/station`, branche par défaut `main`.

**Lis `README.md` en premier** : lancement, organisation des fichiers, et la
procédure de rafraîchissement sur iPhone (service worker + cache — c'est la
source de bug la plus fréquente, elle est entièrement documentée là-bas).
Ce fichier-ci ne répète pas le README : il dit **comment travailler ici**.

## Langue

Tout est en français : commentaires, documents, messages de commit, et les
noms de fonctions du code récent (`prochaineGare`, `zonesDeCarte`,
`recompense.js`). Le noyau plus ancien (`engine.js`, `render.js`,
`schedule.js`) est resté en anglais (`loadStation`, `PLATFORMS`, `PORTALS`).

Suis la langue **du fichier dans lequel tu écris**. Ne renomme jamais pour
uniformiser : ces fichiers sont gros et le diff noierait le vrai changement.

## Pas de chaîne de build

Aucun `package.json`, aucune dépendance, aucun bundler. Les fichiers `js/` sont
des scripts classiques en `"use strict"` qui partagent des globales, chargés
**dans l'ordre** par `station.html` (lignes 240-255) — pas de modules ES, pas
d'`import` côté jeu. Ajouter un fichier `js/`, c'est aussi ajouter sa balise
`<script>` **à la bonne position** dans `station.html`.

Les outils `tools/*.mjs` sont, eux, de l'ESM Node lancé directement
(`node tools/...`), sans installation.

Lancer le jeu : `python3 tools/serve.py` (port 8000 par défaut). Un
double-clic sur `station.html` ne marche pas — les fiches de gares sont
chargées en `fetch`.

## Les contrôles sont les tests

Il n'y a pas de framework de test. Il y a quatre contrôles headless, qui
**refusent** au lieu d'avertir (code de sortie ≠ 0) :

| Commande | Ce qu'elle garde |
|---|---|
| `node tools/gen-check.mjs` | les fiches de gare : connectivité, génération d'horaire, **pression** (files d'attente sur un quai) |
| `node tools/brevet.mjs` | le **brevet** de chaque fiche : le niveau maximal mesuré sain, une fois pour toutes, sur graines fixes |
| `node tools/carte-check.mjs` | la carte est-elle livrable — règles **R1…R10 du ruban** |
| `node tools/net-check.mjs` | le réseau tracé et les coordonnées (`js/geo.js`, `data/places.js`) |
| `node tools/boutique-check.mjs` | ce qui se vend (`data/boutique.json`) — règles **B1…B4** : des cartes et le pack, jamais de pièces, de pierres, d'étoiles ni de temps |

**Le brevet évite de re-balayer le catalogue à chaque geste de carte** (ajouté
le 27 août 2026) : une gare du ruban ne joue que des régimes en nombre fini —
les enveloppes de niveau et le boss — qui ne dépendent pas de la carte. On les
certifie donc UNE FOIS par fiche (`brevet.mjs`, batterie de graines fixes,
K=30), et `carte-check` (R10) vérifie en millisecondes que la rampe d'une
carte ne demande à personne plus que son brevet. Modifier ou étendre une carte
ne coûte plus aucune simulation ; écrire ou retoucher une fiche coûte SA
certification (`node tools/brevet.mjs <id>`), pas celle des autres.

`graph-check`, `corridors-propose` et `graph-propose` ont été **retirés le
25 août 2026** : ils mesuraient le graphe de hubs et de corridors, qui n'existe
plus. `carte-check` les remplace entièrement.

**`gen-check` demande DEUX balayages, et ils ne servent pas à la même chose :**
`--seed=N` pour la non-régression (reproductible, comparable), puis au moins un
tirage **libre** relancé plusieurs fois pour explorer la queue de distribution.
Ne jamais conclure « c'est vert » sur un seul balayage non graîné : mesuré le
22 août 2026, quatre balayages verts d'affilée puis un cinquième qui sort deux
gares défectueuses depuis toujours. La règle et ses mesures sont dans
`tools/AUTHORING-STATIONS.md` §6 — lis-le avant de toucher une fiche.

Une story sur ce projet formule son « Done when » avec ces commandes, pas avec
« ça a l'air de marcher ».

## Où sont les règles du jeu

Ne déduis jamais une règle du code : elle est écrite quelque part, et un
contrôle en est l'autorité.

- `meta-progression-jeu-aiguillage.md` — le design : les quatre niveaux (gare,
  **chapitre**, zone, carte), la construction d'une carte, les récompenses, le
  modèle de données. La référence. **Refondu le 25 août 2026** : une carte est
  un **ruban** — une suite ordonnée de gares, sans embranchement et sans choix
  (§0). Les notions de hub, de sortie et de ligne à parcourir librement sont
  abandonnées ; les grandes gares sont désormais des fins de chapitre.
- `ruban-europe.md` — **le tracé** : les 9 actes, les 95 chapitres, les 593
  gares dans l'ordre du rail, les 8 sauts. C'est le contenu de la carte Europe,
  et l'autorité sur l'itinéraire. Les listes de gares sont des points de
  passage réels, pas des fiches validées : le §0 de `AUTHORING-STATIONS.md`
  reste seul juge de ce qui devient un niveau.
- `plan-de-dev.md` — les lots A→J, avec ce qui est **fait** et ce qui est
  reporté. À mettre à jour quand un lot avance.
- `tools/AUTHORING-STATIONS.md` — la procédure pour écrire une gare. Obligatoire.
- `tools/AUTHORING-CARTES.md` — la procédure pour écrire une carte.
- `tools/AUTHORING-MANIFESTE.md` — le format du manifeste d'enregistrement.
- `data/cartes/README.md` — le schéma d'une carte.

`carte-check.mjs` est explicitement « la seule autorité » sur la lecture des
règles de carte : une règle qu'on ne mesure pas est une intention, pas une règle.

## Les données priment sur le rendu

Le jeu web est un **prototype** : on n'investit rien dans une chaîne graphique
web, mais tout ce qui est données et règles (cartes, fiches, contrôles) est
écrit pour survivre à un portage sous Unity ou Godot. D'où le JSON pour les
cartes et les fiches. Ne mets jamais une règle de jeu dans `render.js`.

Une gare = `data/stations/<pays>/<id>.json` + son entrée dans
`data/stations/index.json` (la position dans l'index **est** la progression).

## Écrire plusieurs gares en parallèle

Cinq fichiers sont partagés et se disputent dès qu'on écrit à plusieurs :
`index.json`, `js/geo.js`, `data/lines.js`, `data/places.js`,
`data/cartes/europe.json`. Personne ne les édite à la main dans ce cas :

1. chaque session écrit ses fiches et **un manifeste**
   (format : `tools/AUTHORING-MANIFESTE.md`) ;
2. `node tools/gen-check.mjs --fiche=<chemin.json>` valide une fiche pas encore
   inscrite à l'index ;
3. `node tools/enregistrer.mjs <manifeste|dossier>` enregistre — dans l'ordre,
   une fois, de façon idempotente. Il ne valide rien et imprime à la fin les
   contrôles à repasser.

## La sauvegarde ne se casse pas

`js/store.js` est le **seul** fichier qui connaît le support de stockage
(localStorage, ou Capacitor Preferences en app native). Le reste du jeu lit un
cache mémoire en synchrone. Il n'existe pas encore de projet natif iOS/Android :
le support Capacitor est écrit d'avance, pour que le portage ne touche que
`makeBackend()`.

Toute modification du format sauvegardé impose d'incrémenter `SCHEMA_VERSION`
et d'écrire la migration dans `migrate()`, testée depuis une sauvegarde
ancienne. Schéma courant : **9** (la progression est par carte, plus les
`possessions` — le pack ; le schéma 8 et ses pierres ont vécu quelques heures
le 10 septembre 2026). Une mise à
jour qui perd la partie d'un joueur est un bug bloquant, pas un détail.

## Git

- Messages de commit **en français**, sur le modèle des commits existants :
  un titre = une phrase narrative, sans préfixe de type (`fix:`, `feat:`) ;
  un corps qui explique la **cause**, ce qui a été mesuré, et ce qui reste. Les
  chiffres du contrôle ont leur place dedans (« Quatre balayages : deux à graine
  fixe, deux libres. Aucun échec. »).
- **Commit direct sur `main` autorisé sur ce projet** — décidé par Vincent le
  25 août 2026. C'est une exception : sur tous les autres projets, une session
  déléguée s'arrête sur une branche poussée. Station est personnel, sans
  relecture à organiser, et l'historique s'est toujours écrit ainsi.
  Contrepartie : les contrôles ci-dessus ne sont pas négociables, puisque plus
  rien ne s'interpose entre un commit et `main`. Un travail long ou risqué
  mérite quand même une branche.
- **Jamais de force-push**, jamais de réécriture d'un historique déjà poussé.

## À ne pas toucher

- `prototypes/` — anciennes versions (Namur, gare centrale v2), gardées pour
  mémoire, hors du jeu. Le dossier reçoit aussi les prototypes de mécanique,
  une page autonome chacun (`prototype-voyageurs.html`,
  `prototype-nuit-de-fete.html`) : on y ajoute, on ne réécrit pas les anciens.
  Nuit de fête a son banc, `node tools/fete-banc.mjs`, qui refuse comme les
  contrôles : il extrait le moteur et les réglages de la page elle-même.
  `prototype-ecluses.html` n'est pas une mécanique de Station mais une autre
  idée de jeu (un puzzle d'eau en coupe), rangée ici faute de dépôt à elle.
  Son banc, `node tools/ecluses-banc.mjs`, résout chaque niveau et refuse si
  le `par` écrit n'est pas la meilleure solution. Sa tranche Godot,
  `prototypes/ecluses-godot/`, est un projet Godot séparé (le `.gdignore` de
  `prototypes/` le tient hors de Station 7) : elle lit `niveaux.json` et
  `oracle.json`, que `node tools/ecluses-vers-godot.mjs` DÉRIVE de la page web
  — ne jamais les éditer à la main. Son **banc visuel**,
  `godot --headless --path prototypes/ecluses-godot --fixed-fps 120 --script res://banc-visuel.gd`,
  mesure l'eau DESSINÉE (creux, cascade, cadences) et refuse comme les
  contrôles ; il remplace le film pour tout défaut de forme (README de la tranche).
  `prototype-caneton.html` est une autre idée sur le même thème : un caneton
  flotte, monte et descend avec l'eau qu'on lâche en ouvrant des vannes.
  Son banc, `node tools/caneton-banc.mjs`, joue TOUS les ordres de gestes
  (les vannes ne font que s'ouvrir) et refuse si le `par` ou l'intention
  `ordres` (« tous » gagnent, ou « certains » seulement) n'est pas tenu.
  `prototype-labyrinthe.html` le remplace dans l'exploration : une boule
  flotte dans un labyrinthe en cases, une tape de robinet = une case d'eau,
  une tape de vidange en retire une (appui long : en continu, sur les deux).
  **Depuis le 14 octobre 2026, Godot fait autorité** (décision de Vincent) :
  la page web est FIGÉE comme trace, avec son ancien banc
  `node tools/labyrinthe-banc.mjs`. Les règles vivent dans
  `prototypes/labyrinthe-godot/` : `niveau.json`, `moteur.gd` (l'eau par
  volumes — une colonne d'eau = un bassin, débit de Torricelli à travers les
  ouvertures —, une surface à ressorts, la boule), et le banc sans écran
  `godot --headless --path prototypes/labyrinthe-godot --script res://banc.gd`,
  qui refuse comme les contrôles. Le pourquoi est dans
  `reports/Animation de fluides pour jeu.md`.
  `prototype-billes.html` (16 octobre 2026) est une autre idée, sans eau :
  des billes de couleur tombent d'un réservoir, on pose avant de les lâcher
  aiguilles, bascules, trieurs et poches sur une grille 4×5 pour que chacune
  finisse dans le godet de sa couleur. Son banc, `node tools/billes-banc.mjs`,
  essaie TOUTES les poses de l'inventaire et refuse si un niveau n'a pas de
  solution, se résout avec moins de pièces, si la cloche ne demande aucun
  choix, ou si la `difficulte` écrite (poses ÷ solutions) n'est pas celle
  mesurée ou redescend sans pièce nouvelle. L'artefact privé pour l'iPhone
  est une copie dérivée de la page (sans squelette ni metas), à republier
  après chaque changement. Cette première page est FIGÉE comme trace :
  `prototype-billes-atelier.html` la remplace (même jour), avec un éditeur
  (Jouer / Éditer, grille jusqu'à 12 × 24, on construit la solution puis on
  marque les pièces « à poser ») et un autre moteur, à ÉLAN entier
  (descendre en donne, MONTER en coûte — la seule perte —, rouler à plat
  ne coûte rien), sur les modules de
  Vincent : rampes, rampe plate, accélérateur, courbes 45° et 90°, poche,
  tremplin, ascenseur, bascule, et des billes grises de lest pour les
  poches. Son banc, `node tools/billes-atelier-banc.mjs [niveaux.json]`,
  rejoue la solution de chaque niveau (ceux de la page, ou ceux exportés
  de l'éditeur) et refuse si elle échoue, s'il n'y a rien à poser, ou si
  une pièce à poser ne sert à rien. Le style suit la charte de
  `tools/PROMPT-billes-mockups.md` (« La charte retenue »).
  **Idée arrêtée le 16 octobre 2026** (« toujours pas convaincu », décision
  de Vincent) : les deux pages et leurs bancs restent comme trace.
  `prototype-eclusier.html` (16 octobre 2026) mélange Station et Écluses :
  le 1-2 d'Écluses, mais six bateaux arrivent à l'horaire comme des trains,
  les portes sont enclenchées, et le bief de partage n'a qu'une rigole —
  remplir le sas coûte de l'eau, le vider rien. Son banc,
  `node tools/eclusier-banc.mjs`, refuse si la fouille ne retrouve pas le
  `par` (l'attente totale), si l'éclusier PRESSÉ (sert tout de suite) ne
  tombe pas à sec, si le GROUPEUR (ne remplit qu'à deux) ne perd pas un
  marinier par la patience, ou si l'eau ne coûte pas d'attente.
  `prototype-pontier.html` (20 octobre 2026) est le premier essai du
  « jeu rêvé » que Vincent a cerné par QCM : Station sous un autre habit.
  Une ville de canaux vue de dessus ; des péniches à l'horaire, un
  aiguillage, une grand-rue qui coupe les deux bras par deux ponts levants,
  un seul ponton d'attente à poser pour de bon, une humeur du quartier qui
  ne fait que baisser. Son banc, `node tools/pontier-banc.mjs`, fait jouer
  une famille de pontiers automates et refuse si le `par` n'est pas le
  meilleur d'entre eux, si le PRESSÉ ou le GROUPEUR gagnent mieux qu'une
  étoile, si la rue vide ne rend pas tout facile, ou si le ponton (et le
  bras où on le pose) ne vaut pas au moins une étoile.
  `prototype-carrefour.html` (20 octobre 2026) en est la suite, à la demande
  de Vincent (« un objectif de réussite », « manipuler différentes choses »).
  C'est un carrefour à feux AUTOMATIQUES : l'avenue, la rue, les piétons
  tournent seuls, et le joueur règle la durée de chaque vert (− / +), qu'il
  réajuste aux heures de pointe (« automatiser un feu et jauger », même
  jour ; l'ambulance retirée). Trois flux (voitures, tram à l'horaire,
  piétons), un QUOTA de passages avant 18 h. Qui attend trop renonce et ne
  compte plus. Les étoiles se comptent en points : les passés plus l'humeur
  qui reste. Son banc, `node tools/carrefour-banc.mjs`, cherche le meilleur
  réglage par vague et refuse si le `par` n'est pas son score, si le meilleur
  réglage POSÉ UNE FOIS a deux étoiles, si le cycle de départ gagne sans
  qu'on y touche, si un cycle trop court ou trop long a deux étoiles, ou si
  l'on gagne en sautant toujours les piétons.
  `prototype-carrefours.html` (même jour) passe à PLUSIEURS carrefours
  (« moins dense, car vite en colère ») : deux carrefours sur une avenue,
  chacun ses feux automatiques réglés dans un panneau sous le plateau. Les
  voitures de l'avenue traversent les deux, et ne s'engagent pas sans
  place pour dégager (six voitures par sens entre eux). La patience est de
  40 s à chaque feu. La page d'un seul carrefour reste comme trace. Son
  banc, `node tools/carrefours-banc.mjs`, cherche le meilleur réglage par
  vague et par carrefour, et refuse comme celui du Carrefour (posé une
  fois, réglage de départ, cycles extrêmes, piétons sautés).
  **Le pontier et les carrefours ont été ARRÊTÉS le 20 octobre 2026 au
  soir** (« on ne s'y retrouve pas », Vincent) : les trois pages et leurs
  bancs restent comme trace. Leur charte graphique, elle, est gardée.
  `prototype-remontee.html` (même soir) est l'idée suivante de Vincent, sur
  cette charte. Des balles de couleur flottent dans un réseau de tuyaux
  vu en coupe. Des vannes versent l'eau (une rangée de plus par goutte,
  seulement là où l'air peut s'échapper), et des PURGES la vident. Chaque
  balle doit entrer dans le trou de sa couleur, qui se ferme derrière
  elle ; dans un autre trou, c'est perdu. Son banc,
  `node tools/remontee-banc.mjs`, résout chaque niveau exhaustivement
  (toutes les suites de gouttes). Il refuse si le `par` (en ouvertures de
  vanne) n'est pas le minimum, si remplir à fond dans n'importe quel ordre
  gagne toujours, ou si, dans un niveau à purges, on gagne sans purger.
  Mesuré : sans purge, une seule vanne bien choisie gagne toujours. La
  profondeur vient des purges et des niveaux qui commencent avec de l'eau.
  Même soir, Vincent : « on se demande comment la balle va aller à droite
  ou à gauche, ce n'est pas clair ». D'où les AIGUILLAGES : une palette
  fléchée à chaque fourche, qu'on bascule. Une balle ne quitte la fourche
  que du côté de la flèche, puis entre dans le premier trou ouvert qu'elle
  croise. Le banc compte les basculements comme des gestes et vérifie
  qu'un niveau à purge n'a aucune solution sans elle.
  **Idée arrêtée le 20 octobre 2026 au soir** (« ce jeu ne me convainc
  pas », Vincent) : la page et son banc restent comme trace.
- `data/worldmap.js` — généré depuis Natural Earth, jamais édité à la main.

## Détail connu

`js/carte.js` a été **supprimé le 26 août 2026** (lot J) : le ruban avait pris
la main au lot E avec `js/parcours.js`, qui a repris sa projection et sa
caméra. C'est là qu'on écrit désormais l'écran du ruban.

`js/catalog.js` a perdu au passage la **progression par pays** (déverrouillage,
jalons, achat de gare, proposition de la gare suivante) : le ruban ordonne les
gares, plus rien ne se choisit. Il ne reste que le chargement du catalogue, la
carte d'une gare, les paliers et grades, le total d'étoiles — et `isStartDoor`,
que `tools/net-check.mjs` charge pour décider d'une porte de départ. **Cette
dernière n'est pas morte : ne la retire pas parce que le jeu ne l'appelle
plus.**

`js/hub.js` est bien vivant : c'est lui qui porte `startStation`. Le
`plan-de-dev.md` le dit « fondu au lot J » — c'est faux, seul `renderHub()`
est un délégué d'une ligne.
