# Panorama des gares possibles — consigne

Produit une **planche d'étude** publiée en Artifact : une échelle d'archétypes de
gares, du plus simple au plus complexe, pour voir d'un coup d'œil l'espace des
possibles avant d'écrire de nouvelles fiches.

Usage : donner à Claude Code la consigne « **Suis `tools/PROMPT-panorama-gares.md`** ».

Cette planche est un **aperçu**, pas un catalogue : le nombre de combinaisons est
trop grand pour être énuméré. Elle échantillonne, et dit ce qu'elle laisse de côté.

Voir aussi `AUTHORING-STATIONS.md` (procédure d'écriture d'une vraie gare) et
`gen-check.mjs` (validation). Deux planches du même type existent déjà, sur la
duplication des fiches — même méthode, même mise en page.

---

## Règle absolue

Ne modifier **aucun** fichier de `data/stations/` ni de `js/`. Les fiches
d'archétypes sont construites **en mémoire**, pour le seul rendu et la
validation.

## Méthode

**1. Lire d'abord.** `AUTHORING-STATIONS.md` en entier : schéma d'une fiche (§2),
INVARIANT DE CONNECTIVITÉ (§3), enveloppes par palier (§5), limites moteur.
Ne pas deviner les champs de `gen` — lire une vraie fiche récente. Les champs de
fret ont bougé ; vérifier leur état courant avant de s'en servir.

**2. Rendre les plans avec le VRAI moteur**, jamais à la main. Charger
`js/engine.js` et `js/schedule.js` dans un contexte `vm` Node, appeler
`loadStation(cfg)`, puis lire `meshD`, `PLATFORMS`, `PORTALS`, `PLAT_X1`,
`PLAT_X2`, `PLAT_H` pour émettre un SVG : courbes teintées par ville, quais,
pastilles de ville, heurtoir sur les quais en impasse. Un plan dessiné à la main
ne prouve rien.

**3. Valider chaque archétype** avec la machinerie de `gen-check.mjs` :
- connectivité : lire `PAIRS` — aucun portail mort, aucun quai mort ;
- K = 20 journées via `generateSchedule()` + `simulateDay()`, `Math.random`
  remplacé par un générateur graine (voir l'option `--seed`) pour que les
  chiffres soient **reproductibles** ;
- rejeter tout archétype avec un train non plaçable ou un retard garanti > 0,30.
  Le corriger et revalider — ne pas publier un archétype en échec.

Ici on ne valide que les ~14 fiches composées, c'est rapide. (Le catalogue
complet à K=20 prend 12–15 min : à lancer en arrière-plan.)

**Ce que le retard garanti dit — et ne dit pas.** Il atteste qu'une gare est
*jouable* (le zéro reste atteignable). Il ne mesure **pas** la difficulté
ressentie : le générateur se calibre sur sa propre cible, si bien que deux
topologies très différentes rendent le même chiffre. Ne pas s'en servir pour
classer les archétypes du plus simple au plus complexe — ce classement se fait
sur la structure.

## L'espace à échantillonner

Les vrais leviers du moteur :

- **nombre de quais** (13 max) et **de directions** (~6 par côté max) ;
- **répartition L/R** des villes, y compris déséquilibrée (3 d'un côté, 1 de l'autre) ;
- **`links`** — quels quais chaque ville dessert. Le levier le plus expressif :
  un **axe** qui tient le tronc du gril contre une **antenne** cantonnée à un ou
  deux quais ;
- **`sameSidePairs`** : `[]` (traversante), `"all"` (terminus), ou paires
  explicites (rebroussement) ;
- **quais en impasse** (`deadEnd`) : le heurtoir est à droite, donc un quai en
  impasse ne s'aborde que **par la gauche** — il n'est desservi que par des
  villes d'un seul côté, et ne vit que grâce à une paire `sameSidePairs` ;
- **portails à sens unique** (`in: false` / `out: false`) : aucune fiche ne s'en
  sert aujourd'hui — montrer ce que ça donne ;
- **`gen`** : densité (`nMin`/`nMax`, `gapMin`/`gapMax`), longueurs de rames
  (`cars`), fret, part de journées calmes.

## L'échelle

Environ **14 archétypes**, strictement ordonnés du plus simple au plus complexe,
et la progression doit se **voir**. Point de départ à composer — non à recopier :

halte à 2 quais sur ligne unique · petite traversante 4 quais / 4 directions ·
la même en axe + antennes · côtés déséquilibrés · antenne en impasse avec
rebroussement · terminus court · traversante moyenne 6 quais / 5 directions ·
gare à sens unique · nœud de fret · grande traversante · grand terminus
8 quais / 6 directions · gare aux limites du moteur (13 quais).

Ajouter, retirer ou remplacer selon ce qu'on découvre en composant.

## Noms

Libellés de direction **neutres** (NORD, SUD, EST, OUEST, VALLÉE, CÔTE…), jamais
des villes réelles : la planche compare des **structures**, pas des géographies.
Le dire sur la planche.

## Pour chaque archétype, montrer

Un nom court · le plan rendu · **une phrase sur ce que la structure fait au jeu**
(ce qu'elle contraint, ce qu'elle apprend au joueur) · la signature « N quais,
D directions, mécaniques utilisées » · la validation mesurée (trains/jour,
retard garanti, seuil 0,30).

## Mise en page

Un document technique sobre, pas une page vitrine : une colonne, hiérarchie
typographique nette, les plans sur fond sombre (ce sont des **écrans**, pas des
illustrations) et lisibles en thème clair comme sombre.

## Pour finir

Une section « **ce que la planche ne montre pas** » : les dimensions non
échantillonnées, les combinaisons écartées et pourquoi, et les limites dures du
moteur à ne pas dépasser.
