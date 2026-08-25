# Plan de développement — le ruban

> Établi le 21 août 2026 pour la structure en graphe ; **refondu le 25 août
> 2026** après le test de jeu : la carte devient un **ruban unique**
> (`meta-progression-jeu-aiguillage.md` §0).
> Le jeu web reste un **prototype** : on n'investit rien dans une chaîne
> graphique web, mais tout ce qui est **données et règles** (cartes, fiches,
> contrôles) est écrit pour survivre au passage sous Unity ou Godot.
> Les lots sont ordonnés par dépendance. C et D sont le cœur du changement ;
> rien d'autre ne peut avancer avant eux.

## Vue d'ensemble

| Lot | Objet | Taille | Dépend de |
|---|---|---|---|
| **A** | Le modèle multi-cartes (données + sauvegarde) — **fait le 21 août 2026** | M | — |
| **B** | Outils d'auteur — **fait le 21 août 2026**, en partie caduc (voir C) | M | A |
| **C** | Le ruban dans les données : schéma, conversion, `carte-check` refondu | M | A |
| **D** | Le ruban dans le moteur : `js/ruban.js`, sauvegarde schéma 7 | M | C |
| **G** | Récompense **et crédits** : chapitre, zone, solde déduit | S | D |
| **E** | Le ruban à l'écran : *Continuer*, fin de chapitre, saut, soupape payante | M | D, **G** |
| **F** | Contenu : l'ordre du ruban d'Europe et sa rampe (89 niveaux au départ) | L | C, D |
| **H** | L'écran des cartes et l'achat | M | G |
| **I** | Deuxième carte (preuve de généricité) | L | C, H |
| **J** | Nettoyage : ce que le ruban rend mort | S | E, G |

Tailles : S = une séance, M = quelques séances, L = une à deux semaines de
contenu.

**G passe avant E** (changement du 25 août) : la soupape se paie en crédits, donc
le solde doit exister avant l'écran qui le dépense.

**Le jeu doit rester jouable à chaque commit.** C et D se font dans cet ordre
et se poussent ensemble si nécessaire : entre les deux, la carte est un ruban
que le moteur ne sait pas encore lire.

---

## Lot A — Le modèle multi-cartes — FAIT (21 août 2026)

Toujours valable, le ruban ne le remet pas en cause.

*Livré* : `data/cartes/europe.json` + `index.json` + `README.md` ;
`js/cartes.js` (`loadCartes`, `loadCarte`, `zonesDeCarte`, `hubsDeZone`,
`nomDeCarte`) ; `js/graph.js` construit depuis `CARTE_COURANTE` ; `js/store.js`
en schéma **6** (`cartes[id] = { stations, bought, serie }`, `carteCourante`,
`possedees`) avec migration v0/v5 → v6 testée ; `etoilesTotal` somme toutes les
cartes ; `graph-check` et `corridors-propose` lisent le JSON.

*Ce qui reste du lot est annulé* : le point 5 (appliquer les versions de hub au
moment de jouer un boss) n'a plus d'objet sous cette forme — les versions
deviennent un choix d'auteur inscrit dans le ruban (lot C, §2.2 bis du
document). Le point 6 (médailles de carte vs de compte) passe au lot G.

## Lot B — Outils d'auteur — FAIT (21 août 2026), partiellement caduc

*Livré* : `tools/carte-check.mjs` (R1–R8 de la version graphe),
`tools/AUTHORING-CARTES.md`, le rapport de couverture, l'affichage du résumé
de carte dans `gen-check`.

*Ce qui survit* : la mécanique du contrôle (lecture de la carte, sortie en
tableau, code de retour ≠ 0, option `--carte`), le rapport de couverture, le
branchement dans `gen-check`, et R7 (sinuosité) et R8 (rampe) qui restent des
règles du ruban.

*Ce qui meurt* : R1 (≥ 20 hubs), R2 (≥ 50 lignes), R2 bis (≥ 3 sorties par
hub), R4 (zones de 7–13 hubs), R5 (connexité), R6 ancienne version. Elles sont
remplacées au lot C. `tools/corridors-propose.mjs` et `tools/graph-propose.mjs`
perdent leur raison d'être (proposer des sorties de hub) : à réévaluer au lot J.

---

## Lot C — Le ruban dans les données

**But** : `data/cartes/europe.json` décrit un ruban, et un contrôle refuse
tout ce qui n'en est pas un.

1. **Schéma** — `data/cartes/<id>.json` : `zones` + `chapitres[]` **dans
   l'ordre du ruban** (§8 du document). Un chapitre = `{ id, nom, zone,
   gares[5..10], plancher?, saut? }`, la dernière gare étant la grande gare.
   Plus de `hubs`, plus de `lignes`, plus de `de`/`vers`. Mettre à jour
   `data/cartes/README.md`.
2. **Conversion** — un script à usage unique dans le scratchpad : les 26
   lignes complètes et jouables (mesure du 25 août) deviennent 26 chapitres
   `{ gares: [...intermédiaires, grande gare] }`. L'**ordre** entre chapitres
   et les **sauts** sont le travail du lot F ; ici on produit un ruban
   provisoire, cohérent mais pas encore agréable.
3. **Ce qui sort du fichier de carte** : les coordonnées `ll` des grandes
   gares et leurs `versions` de terminus (Paris-Nord / Paris-Gare-de-Lyon /
   Paris-Montparnasse…). Les `ll` sont déjà dans `js/geo.js` — ne pas
   dupliquer. Les versions deviennent **des fiches distinctes citées
   directement** dans `gares[]` : le ruban dit lui-même quelle gare de Paris
   se joue quand, il n'y a plus rien à déduire.
4. **`tools/carte-check.mjs` refondu** sur les nouvelles R1–R9 (§3 du
   document) :
   - R1 ruban unique (une seule suite, aucune gare orpheline, aucun doublon
     d'ordre) ;
   - R2 ≥ 60 gares et ≥ 8 chapitres ;
   - R3 chapitre de 5 à 10 gares, la dernière étant une grande gare ;
   - R4 zone de 3 à 6 chapitres, ≥ 2 zones ;
   - R5 **continuité réelle** : deux gares consécutives d'un chapitre sont
     voisines sur une ligne réelle (`data/lines.js` / `js/geo.js`) ; une
     rupture n'est tolérée qu'entre chapitres **et** si `saut` est déclaré ;
   - R6 une fiche une seule fois, et ≥ 20 gares d'écart entre deux gares de
     la même ville ;
   - R7 sinuosité ≤ 1,5 par chapitre (repris de l'existant) ;
   - R8 la difficulté portable croît dans le chapitre, la grande gare est la
     plus haute, et le plancher des chapitres croît le long du ruban
     (avertissement, pas erreur — la géométrie a le dernier mot) ;
   - R9 premier chapitre doux (première gare jouable en 1, arrivée ≤ 3).
5. **`tools/AUTHORING-CARTES.md` réécrit** : la procédure « écrire un ruban »
   — choisir le fil, découper en chapitres, les nommer, placer les sauts,
   vérifier la rampe. `AUTHORING-STATIONS.md` §4 : une fiche se rattache
   désormais à un **chapitre**, pas à une ligne.

*Fini quand* : `node tools/carte-check.mjs europe` est vert sur le ruban
provisoire, et refuse (code ≠ 0) si on retire une gare d'un chapitre, si on
duplique une fiche, ou si on casse la continuité sans déclarer de saut.

## Lot D — Le ruban dans le moteur

**But** : le jeu avance d'une gare à la suivante ; plus aucun choix.

1. **`js/ruban.js`** remplace `js/graph.js` (même place dans l'ordre de
   chargement de `station.html`). Ce qu'il expose :
   `rubanDeCarte()`, `chapitreDe(ficheId)`, `indexDe(ficheId)`,
   `gareSuivante()`, `positionCourante()`, `chapitreTermine(id)`,
   `difficulteDeGare(ficheId)`, `enveloppeDeGare(ficheId)`.
2. **Ce qui est repris tel quel** de `js/graph.js` : `plafondDeFlux`,
   `enveloppeDe`, `ficheDeService`, `PROFILS`. Ce sont les seules parties
   mesurées et calibrées ; elles ne bougent pas.
3. **Ce qui disparaît** : `sortiesDeHub`, `parcours`, `lienEntre`,
   `tousLesLiens`, `hubDeGare`, `corridorDeGare`, `corridorTermine`,
   `bossMaitrise`, `versionsDeHub`, `lignesDeDepart`, `hubsDeDepart`,
   `garesDeDepart`, `estGareDamorce`, `hubDeDepart`, `garesOuvrables`,
   `ouvreLaSuite`. Vérifier chaque appelant avant suppression.
4. **La difficulté** (§2.5 du document) : `difficulteVoulue(i, n, plancher)`
   monte du plancher du chapitre à la grande gare finale, puis
   `Math.min(..., plafondDeFlux(cfg))`. Le plancher vient du chapitre
   (`plancher`) ou se déduit de son rang dans le ruban.
5. **`js/store.js` schéma 6 → 7** : `resultats` et `serie` repris tels quels,
   `acquises` et `versionsJouees` abandonnés, `passees` (soupape) créé vide.
   **La position n'est pas stockée** : c'est la première gare du ruban ni
   faite ni passée. Migration testée depuis une sauvegarde v6 **et** v5 : un
   joueur du graphe ne perd aucune étoile, et retrouve sa position sur le
   ruban recalculée. Une mise à jour qui perd la partie d'un joueur est un bug
   bloquant.
6. **`js/main.js` / `js/game.js`** : la fin de service enchaîne sur
   `gareSuivante()` au lieu d'un écran de choix.

*Fini quand* : en headless, une sauvegarde v6 se migre sans perte d'étoile ;
`gareSuivante()` avance de la première à la dernière gare du ruban sans jamais
rendre `null` au milieu ; aucune erreur JS sur les trois vues.

## Lot E — Le ruban à l'écran

**But** : le geste. C'est ce lot qui répond au test de jeu.

1. **Un bouton** au lancement : *Continuer* — le nom de la prochaine gare, le
   nom du chapitre, « gare 4 sur 7 ». Rien d'autre à décider.
2. **La carte montre, ne décide plus** (`js/carte.js`) : le ruban tracé,
   les gares faites derrière (colorées par étoiles), la prochaine qui pulse,
   la suite en gris. Le zoom reste libre. Une gare faite se rejoue d'un
   toucher ; une gare pas encore atteinte ne se joue pas.
3. **Fin de chapitre** : relevé, rang du chapitre (§6.2), **nom du chapitre
   suivant annoncé** — c'est ce qui manquait le plus au test.
4. **Le saut** (§4 bis) : animation de trajet sur la carte + la phrase
   (« train de nuit pour Marseille »), passable d'un geste.
5. **La soupape payante** (§4 ter, tranché le 25 août) : il faut **réussir** la
   gare ; au troisième échec seulement, proposer de **payer le passage en
   crédits**. Formulation neutre, jamais « abandonner ». La gare payée reste à
   0 étoile, marquée sur la carte, et se rejoue quand on veut — la gagner plus
   tard **rend la mise** (rien à stocker : la dépense ne compte que les
   `passees` encore à 0 ★). Afficher le solde et le prix au moment de l'offre,
   et, si le solde ne suffit pas, dire **où aller le gagner** : « il te manque
   12 crédits — trois gares de la ligne de Lorraine te les donnent ». C'est ce
   renvoi vers le rejeu qui fait tout l'intérêt du passage payant.
6. **Jamais de vies, jamais de minuterie.** Le rejeu reste gratuit, immédiat et
   illimité. Le prix ne s'applique qu'à *sauter* la gare, jamais à la retenter.
7. **Fin de zone** : célébration, la carte se colore.

*Fini quand* : en headless, on ouvre le jeu, on appuie sur *Continuer*, on
joue trois gares d'affilée sans jamais choisir quoi que ce soit, et la fin de
chapitre annonce le suivant. Et : trois échecs d'affilée déclenchent l'offre de
passage, la payer avance le ruban sans donner d'étoile, gagner la gare ensuite
restitue les crédits. Vérification visuelle (Chrome headless + CDP,
`tick()` pour avancer le temps).

## Lot F — Contenu : le ruban d'Europe

**But** : un ruban qu'on a envie de suivre, pas une suite de chapitres.

1. **Écrire l'ordre** des chapitres. Contraintes : R5 (continuité), **R6 (ne
   jamais réemprunter un tracé ; revenir dans une ville seulement par un autre
   croisement et une autre ligne)**, R8 (la rampe), R9 (le début doux).
   **Mesuré le 25 août : le ruban extractible du noyau plafonne à 16 chapitres
   et 89 niveaux**, parce que 20 des 22 grandes gares n'ont qu'une fiche.
   Chaîne maximale : Munich → Stuttgart → Zurich → Strasbourg → Luxembourg →
   Francfort → Nuremberg → Leipzig → Berlin → Hambourg → Cologne → Hanovre →
   Amsterdam → Bruxelles → Lille → Paris → Lyon. **À lire à l'envers** (R9 : le
   début doux part de France, la rampe monte vers les Alpes), et à retoucher :
   le tronçon Berlin → Hambourg → Cologne → Hanovre → Amsterdam se lit mal sur
   une carte. Un ruban plus court mais qui ressemble à un voyage vaut mieux.
2. **Les 10 chapitres hors ruban** partent en réserve, pas à la poubelle. Pour
   les récupérer : écrire une **deuxième gare réelle** dans les villes qui n'en
   ont qu'une (Hanovre, Cologne, Zurich, Bruxelles…) — c'est ce qui rouvre le
   plus de chapitres d'un coup — ou les raccrocher par un saut.
3. **Placer les sauts** : Londres–Manchester, Paris–Lyon et
   Montpellier–Bordeaux sont détachés du noyau continental. Soit un saut
   déclaré, soit un chapitre à écrire pour les relier.
4. **Nommer les chapitres** (§2.2) : des noms de voyage. Question ouverte n° 7
   du document (marques déposées) — préférer les noms historiques.
5. **Caler la rampe** : mesurer en headless la difficulté réellement jouée
   gare après gare le long du ruban, et fixer le pas du plancher (question
   ouverte n° 3). Une courbe qui monte trop vite se voit tout de suite au
   nombre de rejeux.
6. **Allonger** ensuite, par le bout, avec les 21 lignes à compléter puis les
   94 fiches déjà écrites hors du noyau. Chaque chapitre livré = un commit
   poussé.

*Fini quand* : `carte-check europe` est vert, et une partie complète en
headless va de la première à la dernière gare sans blocage, sans doublon de
ville rapproché, et sans saut non déclaré.

## Lot G — Récompense

**But** : le chapitre remplace la ligne, la zone devient un palier.

1. **`js/recompense.js`** : `garesDeLigne`/`rangDeLigne`/`toutesLesLignes`
   deviennent `garesDeChapitre`/`rangDeChapitre`/`tousLesChapitres`. Le calcul
   (minimum des gares) ne change pas — seul le vocabulaire.
2. **`etatDeZone(zoneId)`** déduit : *fermée* ‹ *entamée* ‹ *traversée* (tous
   ses chapitres finis) ‹ *or* ‹ *diamant*. Rien de stocké.
3. **Médailles** : retirer celles adossées aux hubs maîtrisés ; ajouter
   chapitres dorés, zones traversées, sauts franchis, carte terminée.
4. **Séparer carte et compte** (reste du lot A, point 6) : le grade et les
   crédits somment toutes les cartes ; les rangs et médailles de carte non.
5. **Le solde de crédits, déduit** — remonté ici depuis le lot H parce que la
   soupape du lot E en dépend. `creditsGagnes()` = Σ sur toutes les cartes
   (étoiles × 1, diamants × 5, chapitres dorés × 20, zones maîtrisées × 100,
   cartes terminées × 500 — valeurs à caler). `creditsDepenses()` = Σ prix des
   cartes acquises en crédits + Σ **prix des gares `passees` encore à 0 ★**.
   `prixDePassage(ficheId)` suit la position dans le ruban (§7 du document).
   Rien de plus n'est stocké.
6. **Caler les trois barèmes ensemble** (question ouverte n° 4) : gain d'une
   gare, prix d'un passage, prix d'une carte. Contrainte à vérifier en
   headless sur le ruban réel : finir l'Europe paie la deuxième carte, même
   après quelques passages achetés ; et un débutant bloqué au chapitre 1 peut
   se payer un passage en rejouant deux ou trois gares.

*Fini quand* : finir tous les chapitres de la zone France-Benelux la fait
passer *traversée* avec célébration, la vue Europe la colore, et le solde de
crédits affiché correspond au barème sur une sauvegarde de test.

## Lot H — L'écran des cartes et l'achat

Le **calcul** des crédits est remonté au lot G (la soupape en a besoin) ; il
reste ici la **dépense en cartes** et l'écran. Inchangé sur le fond par rapport
au plan du 21 août : il ne dépend que du modèle multi-cartes, pas de la
structure interne d'une carte.

1. **Écran « Cartes »** : une tuile par carte de `data/cartes/index.json` —
   nom, sous-titre, nombre de chapitres et de niveaux, progression, état
   *possédée* / *verrouillée* avec prix en crédits et bouton CB (inactif dans
   le prototype).
2. **Changer de carte** : `loadCarte(id)` + reconstruction du ruban. La
   dernière carte jouée est la carte courante au lancement.
3. **Une seule carte gratuite** → l'écran est sauté et on tombe sur
   *Continuer*. Il n'apparaît qu'à partir de deux cartes.
4. **Acheter une carte** : bouton actif quand le solde (lot G) suffit ;
   `cartesPossedees[id] = "credits"`. L'écran affiche « il te manque N
   crédits ». Rien d'autre n'est stocké que `cartesPossedees`.
5. **CB** : hors prototype ; seul l'état `"achat"` est prévu dans la
   sauvegarde pour que le moteur final n'ait pas à migrer.

*Fini quand* : avec deux entrées dans `index.json`, on passe de l'une à
l'autre et chaque progression reste intacte ; un joueur qui a fini le ruban
d'Europe a de quoi s'offrir la seconde.

## Lot I — Deuxième carte

**But** : prouver que le modèle est générique — bien moins cher qu'avec le
graphe : **60 gares suffisent** (R2) au lieu de 260.

1. Choisir le territoire (question ouverte n° 5) et son échelle.
2. Suivre le `AUTHORING-CARTES.md` du lot C : le fil, les chapitres, les
   noms, les sauts, puis les fiches. Réutiliser les fiches existantes quand la
   ville est déjà au catalogue (94 fiches sont hors du ruban d'Europe).
3. La livrer **verrouillée** derrière un prix en crédits — c'est aussi le test
   du lot H.

## Lot J — Nettoyage

- `js/graph.js` supprimé (lot D), `js/hub.js` (88 lignes, ne fait plus que
  déléguer à `renderCarte`) fondu.
- `js/catalog.js` perd les restes de la progression par pays (`isUnlocked`,
  `countryComplete`, `JALONS`, `cheapestBuyable*`, `nextMove`) s'ils ne sont
  plus appelés — plusieurs sont déjà des coquilles.
- `tools/corridors-propose.mjs` et `tools/graph-propose.mjs` : supprimés, ou
  refaits en « propose la suite du ruban » s'ils rendent encore service.
- `tools/graph-check.mjs` : réévaluer (il garde les invariants du graphe des
  voies **d'une gare**, pas de la carte — probablement à conserver tel quel,
  seul son en-tête est périmé).
- `README.md` : suivre l'organisation des fichiers à chaque lot.

---

## Ce qu'on ne fait pas (et pourquoi)

- **Pas d'embranchement**, pas de fourche qui se rejoint : tranché le 25 août,
  ruban strictement unique d'abord (§0 du document).
- **Pas de chaîne graphique web** nouvelle : le prototype valide la structure,
  le rendu final est l'affaire du moteur.
- **Pas de paiement réel** dans le prototype.
- **Pas d'allongement du ruban** tant que `carte-check` n'est pas vert sur le
  noyau : un ruban à moitié cohérent n'apprend rien de plus.
- **Pas de chapitres légendaires, pas de régularité quotidienne** : intentions
  conservées dans le document, hors plan.

## Prochaine action

Lot C, point 1 : le schéma `chapitres[]` dans `data/cartes/README.md`, puis la
conversion des 26 lignes jouables en un ruban provisoire — en gardant le jeu
jouable à chaque commit.
