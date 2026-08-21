# Plan de développement — la structure en quatre niveaux

> Établi le 21 août 2026 à partir de `meta-progression-jeu-aiguillage.md`.
> Le jeu web reste un **prototype** : on n'investit rien dans une chaîne
> graphique web, mais tout ce qui est **données et règles** (cartes, fiches,
> contrôles) est écrit pour survivre au passage sous Unity ou Godot —
> d'où le choix du JSON pour les cartes.
> Les lots sont ordonnés par dépendance ; A et B conditionnent tout le reste,
> C est le plus long et se mène en parallèle de D-E-F dès que B existe.

## Vue d'ensemble

| Lot | Objet | Taille | Dépend de |
|---|---|---|---|
| **A** | Le modèle multi-cartes (données + sauvegarde) | M | — |
| **B** | Outils d'auteur : contrôle de carte et remplissage des lignes | M | A |
| **C** | Contenu Europe v1 : porter le bloc de lancement aux règles | XL | B |
| **D** | La zone comme palier d'objectifs | S | A |
| **E** | L'écran des cartes et la carte courante | M | A |
| **F** | Les crédits et l'achat de cartes | S | E |
| **G** | Deuxième carte (preuve de généricité) | L | B, E |
| **H** | Nettoyage : ce que les lots rendent mort | S | A, E |

Tailles : S = une séance, M = quelques séances, L = une à deux semaines de
contenu, XL = contenu long, parallélisable par agents.

---

## Lot A — Le modèle multi-cartes

**But** : le code ne connaît plus « l'Europe » mais « la carte courante » ; la
progression est rattachée à une carte.

1. **`data/cartes/europe.json`** — déplacer `CONSTELLATIONS`, `HUBS`, `LIENS`,
   `CORRIDORS` de `data/graph.js` vers le schéma du §8 du document (`zones`,
   `hubs`, `lignes` avec `de/vers/gares` fusionnés — un LIEN et son CORRIDOR
   deviennent un seul objet `Ligne`). Ajouter `id`, `nom`, `gratuite`,
   `echelle`. Un script de conversion à usage unique, dans le scratchpad.
2. **`data/cartes/index.json`** — la liste des cartes (id, nom, gratuite, prix
   en crédits, sous-titre). Une seule entrée au départ.
3. **Chargement** — `loadCarte(id)` (nouveau `js/cartes.js`) lit le JSON via
   `fetch` comme les fiches, puis `buildGraphe()` (js/graph.js) construit le
   graphe **à partir de la carte chargée** et non plus des globales. Le graphe
   doit pouvoir se **reconstruire** quand on change de carte (`GRAPHE.pret`
   remis à faux).
4. **Sauvegarde par carte** — `js/store.js` : `SCHEMA_VERSION` 5 → **6**, avec
   migration : `{ stations, bought, serie }` → `cartes.europe.{ resultats,
   acquises, versionsJouees, serie }` + `cartesPossedees.europe = "gratuite"`
   + `carteCourante = "europe"`. Les accesseurs (`getProgress`, `getBought`,
   `isBought`, `saveResult`, `getSerie`…) gardent leur signature et lisent la
   carte courante — personne d'autre ne change.
5. **Versions jouées** — aujourd'hui la version d'un hub se déduit de ses
   sorties ouvertes ; vérifier que c'est suffisant ou stocker
   `versionsJouees` (le document le prévoit).
6. **Grade et médailles de compte** — `etoilesTotal()` (catalog.js) somme
   **toutes les cartes** ; les médailles *de carte* (lignes, hubs, zones)
   restent par carte. Séparer dans `js/recompense.js` ce qui est « carte » de
   ce qui est « compte ».

*Fini quand* : le jeu se joue exactement comme avant sur `europe.json`, une
sauvegarde v5 se migre sans perte (test headless : charger une sauvegarde
fabriquée au schéma 5, vérifier étoiles et gares acquises), et
`data/graph.js` a disparu.

## Lot B — Outils d'auteur

**But** : rendre les règles R1–R9 vérifiables et le remplissage des lignes
outillé, avant d'écrire 200 fiches.

1. **`tools/carte-check.mjs <carte>`** — vérifie R1 (≥ 20 hubs), R2 (≥ 50
   lignes), R2 bis (≥ 3 sorties par hub), R3 (4–9 gares par ligne), R4 (zones de 7–13, ≥ 2 zones),
   R5 (connexité, aucune fiche référencée absente, aucun hub sans fiche dans
   le sous-ensemble livré), R6 (une gare, une ligne), R7 (sinuosité ≤ 1,5
   depuis `ll` des hubs et `geo.js`), R8 (plafond de flux croissant vers le
   hub — avertissement, pas erreur). Sortie : un tableau par règle, et un
   **rapport de couverture** : lignes conformes / total, fiches manquantes par
   ligne. Option `--livrable <zone,zone>` pour évaluer un bloc de lancement.
2. **Étendre `tools/corridors-propose.mjs`** — viser 4–9 gares par ligne au
   lieu de « le plus long sous le plafond », et **lister les gares réelles
   manquantes** (depuis `data/lines.js` enrichi / Wikipédia Infrabel, SNCF,
   DB) pour que l'écriture des fiches parte d'une liste, pas d'une recherche.
3. **`tools/AUTHORING-CARTES.md`** — la procédure « créer une carte » (choix
   des hubs par taille de croisement, espacement, zones équilibrées, tracés
   sur les lignes réelles, contrôle), en miroir de `AUTHORING-STATIONS.md`.
   Y inscrire la règle « ≥ 3 directions » manquante côté gares.
4. **Brancher `carte-check` dans `gen-check`** (ou l'inverse) pour qu'un seul
   `node tools/gen-check.mjs` dise si une carte est livrable.

*Fini quand* : `node tools/carte-check.mjs europe` imprime les 4 écarts connus
(31 hubs sous 3 sorties, 17 lignes trop courtes, 110 lignes vides, 58 hubs
sans fiche) et un rapport « bloc nw+ger » exact (24 hubs, 39 lignes, 8 hubs
sous 3 sorties internes).

## Lot C — Contenu Europe v1

**But** : un bloc d'au moins 20 hubs qui passe `carte-check` sans erreur.

1. **Le bloc est tranché** : France-Benelux + Germanie-Alpes (24 hubs, 39
   lignes internes, ~215 fiches). Si le bloc livré doit atteindre 50 lignes à
   lui seul (question ouverte n° 3 du document), les Îles britanniques
   s'ajoutent en **C bis** après ce lot, même méthode.
2. **Corriger R2 bis dans le bloc** — règle tranchée : *ajouter des lignes,
   sinon supprimer le hub*. Huit hubs concernés. Proposer pour chacun une
   ligne réelle (Nantes–Rennes ; Toulouse–Narbonne ; Dijon–Belfort–Mulhouse
   ou Dijon–Besançon ; Genève–Simplon–Milan ; Leipzig–Dresde ; Lille,
   Marseille, Montpellier ont leur 3e sortie vers une zone grisée) et, à
   défaut de ligne crédible à 4–9 gares, **retirer le hub** et rattacher ses
   gares aux lignes voisines. Passer la même revue sur les 23 autres hubs de
   l'Europe avant de livrer leurs zones.
3. **Écrire les hubs manquants** du bloc : Amsterdam, Zurich, Genève
   (vérifié le 21 août).
4. **Remplir les lignes** à 4–9 gares, **ligne par ligne**, un agent par gare
   selon `AUTHORING-STATIONS.md` (recherche réelle → fiche → `gen-check`).
   Ordre : d'abord les lignes de départ (rampe douce), puis les lignes entre
   hubs jouables, puis le reste. Chaque ligne livrée = un commit poussé.
5. **Rampe de difficulté** : vérifier avec `carte-check` (R8) que les gares
   grossissent vers le hub ; sinon réordonner ou remplacer une gare.
6. **Le reste de l'Europe** s'affiche **grisé « à venir »** dans la vue Europe
   (js/carte.js) ; un hub non jouable n'est jamais proposé comme sortie.

*Fini quand* : `carte-check europe --livrable nw,ger` est vert ; une partie
complète (test headless accéléré par `tick()`) parcourt une ligne de départ,
bat un hub, ouvre une ligne, et ne tombe jamais sur une gare sans fiche.

## Lot D — La zone comme palier d'objectifs

**But** : la constellation devient un niveau de progression lisible.

1. **`js/recompense.js`** : `etatDeZone(zoneId)` déduit → *fermée* (aucun hub
   battu) ‹ *entamée* ‹ *ouverte* (tous les hubs battus) ‹ *maîtrisée* (tous
   maîtrisés) ‹ *or* ‹ *diamant* (toutes les lignes internes au rang). Même
   esprit que les rangs de ligne : **minimum**, rien de stocké.
2. **Vue zone** (js/carte.js, échelle « constellation ») : le rang de zone, la
   jauge « 6 / 10 hubs », et la célébration au passage *ouverte* / *maîtrisée*
   (réutiliser le relevé de fin de service et les pastilles `flashLabel`).
3. **Médailles** : « Voie royale » (première zone maîtrisée), « Hub-porte
   franchi » (première gare tenue dans une deuxième zone).
4. **Vue carte** (échelle « Europe ») : chaque zone colorée par son rang, les
   zones non livrées grisées.

*Fini quand* : en jouant tous les hubs de la zone France-Benelux, la vue zone
passe à *ouverte* avec célébration, et la vue Europe la colore.

## Lot E — L'écran des cartes

**But** : choisir sa mission.

1. **Écran « Cartes »** (nouvelle échelle au-dessus de la vue carte, ou
   premier écran quand aucune carte n'est possédée) : une tuile par carte de
   `data/cartes/index.json` — nom, sous-titre, nombre de hubs / lignes /
   niveaux, progression du joueur (hubs battus, rang), état *possédée* /
   *verrouillée* avec le prix en crédits et le bouton CB (inactif dans le
   prototype, §7 du document).
2. **Changer de carte** : `loadCarte(id)` + reconstruction du graphe + la vue
   ligne de cette carte. La dernière carte jouée est la carte courante au
   lancement.
3. **Première ouverture** : une seule carte gratuite → on saute l'écran et on
   tombe sur le choix de la ligne de départ comme aujourd'hui. L'écran
   n'apparaît que s'il y a au moins deux cartes, ou depuis le dézoom maximal.

*Fini quand* : avec deux entrées dans `index.json` (la seconde pouvant être une
carte de test de 20 hubs fictifs), on passe de l'une à l'autre et chaque
progression reste intacte.

## Lot F — Les crédits

**But** : acheter une carte en jouant.

1. **Barème déduit** (`js/recompense.js`) : `creditsGagnes()` = Σ sur toutes
   les cartes (étoiles × 1, diamants × 5, hubs maîtrisés × 20, zones
   maîtrisées × 100, cartes terminées × 500 — valeurs à caler). Solde =
   gagnés − Σ prix des cartes achetées en crédits. Rien d'autre n'est stocké
   que `cartesPossedees` (lot A).
2. **Affichage** : le solde à côté du grade (barre du haut), l'écran des cartes
   affiche « il te manque N crédits ».
3. **Achat** : bouton actif quand le solde suffit ; `cartesPossedees[id] =
   "credits"`. Déblocage de débogage via un paramètre d'URL, comme les autres
   outils de test.
4. **CB** : hors prototype. Prévoir seulement l'état `"achat"` dans la
   sauvegarde pour que le moteur final n'ait pas à migrer.

*Fini quand* : un joueur qui a maîtrisé le bloc de lancement a de quoi
s'offrir la deuxième carte au prix prévu.

## Lot G — Deuxième carte

**But** : prouver que le modèle est générique avant d'industrialiser.

1. Choisir le territoire (question ouverte n° 5) et son échelle
   (`kmMinEntreHubs`).
2. Suivre `AUTHORING-CARTES.md` : hubs (20+), zones (2+), tracés (3+ par hub),
   puis les fiches. Réutiliser les fiches existantes quand la ville est déjà
   au catalogue.
3. La livrer **verrouillée** derrière un prix en crédits — c'est aussi le test
   du lot F.

## Lot H — Nettoyage

- `data/graph.js` supprimé (lot A) ; `js/catalog.js` perd les restes de la
  progression par pays (`isUnlocked`, `countryComplete`, `JALONS`,
  `cheapestBuyable*`, `nextMove`) s'ils ne sont plus appelés — vérifier à
  la main, plusieurs sont déjà des coquilles (`idleStation`, `buyBlock`).
- `js/hub.js` (89 lignes) ne fait plus que déléguer à `renderCarte` : fondre.
- `README.md` : suivre l'organisation des fichiers à chaque lot.
- Mettre à jour `tools/AUTHORING-STATIONS.md` §4 (enregistrement) quand une
  fiche doit aussi être rattachée à une ligne de carte.

---

## Ce qu'on ne fait pas (et pourquoi)

- **Pas de chaîne graphique web** nouvelle (écran des cartes en HTML/CSS
  simple, pas d'illustrations) : le prototype sert à valider la structure, le
  rendu final est l'affaire du moteur.
- **Pas de paiement réel** dans le prototype.
- **Pas de contenu hors du bloc de lancement** tant que `carte-check` n'est
  pas vert dessus : une deuxième zone à moitié écrite n'apprend rien de plus.
- **Pas de lignes légendaires, pas de régularité quotidienne** : intentions
  conservées dans le document, hors plan.

## Prochaine action

Lot A, point 1 : écrire `data/cartes/europe.json` depuis `data/graph.js`
(conversion scriptée), puis le chargeur — en gardant le jeu jouable à chaque
commit.
