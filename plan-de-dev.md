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
| **C** | Le ruban dans les données — **fait le 25 août 2026** | M | A |
| **D** | Le ruban dans le moteur — **fait le 25 août 2026** | M | C |
| **G** | Récompense **et crédits** : chapitre, zone, solde déduit | S | D |
| **E** | Les écrans — **fait le 25 août 2026** | M | D, G |
| **F** | Contenu : écrire les 470 fiches du ruban (`ruban-europe.md`) | XL | C, D |
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

## Lot C — Le ruban dans les données — FAIT (25 août 2026)

*Livré* : `data/cartes/europe.json` au schéma `chapitres[]` (11 chapitres,
64 gares, 2 zones, Luxembourg → Hambourg), régénérable par
`python3 tools/ruban/export-carte.py 51 61` ; `data/cartes/README.md` réécrit
(schéma + R1–R9 + `enChantier`) ; `tools/carte-check.mjs` **entièrement
refondu** sur les règles du ruban — R1 ruban unique, R2 longueur, R3 chapitre
de 5 à 10, R4 zones, R5 continuité réelle (distance à vol d'oiseau, 250 km),
R6 retour en ville par une autre gare, R7 sinuosité, R8 rampe (avertissement),
R9 premier chapitre doux. `enChantier: true` relâche R2 et R4 — les deux
règles de complétude — et jamais les règles de correction.

*Décidé en écrivant* : **R9 exigeait un chapitre d'ouverture arrivant à 3 au
plus, et L'Ardenne finit sur Bruxelles-Midi qui porte un 5.** Le champ
`arrivee` a donc été ajouté au schéma : un chapitre peut plafonner ce que sa
dernière gare doit produire. Sans lui, le tutoriel arrivait au sommet du jeu
six gares après l'avoir ouvert.

*Retirés* : `tools/graph-check.mjs`, `tools/corridors-propose.mjs`,
`tools/graph-propose.mjs` — ils mesuraient le graphe de hubs, qui n'existe
plus. `carte-check` les remplace. `tools/AUTHORING-CARTES.md` est marqué
périmé en tête (sa réécriture reste due).

<details><summary>Le plan d'origine du lot C</summary>


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

6. **Le ruban v1 — quel préfixe on livre** (mesuré le 25 août). Le ruban
   complet commence à Cork, où **rien n'est écrit** : le jeu ne peut pas
   démarrer là. Et sur les 12 chapitres entièrement écrits, **un seul peut
   ouvrir une carte** — *L'Ardenne* (Luxembourg → Bruxelles), dont le profil
   est d1·2·1·3·2·5 : Arlon d1 en tutoriel, rampe jusqu'à Bruxelles-Midi d5.
   Tous les autres ouvrent en d4 ou d5, parce qu'ils ont été écrits pour un
   milieu de ruban.

   **Décision : la v1 livre les chapitres 51 à 61 du ruban définitif** —
   Luxembourg → Bruxelles → Amsterdam → Hanovre → Cologne → Francfort →
   Stuttgart → Munich → Nuremberg → Leipzig → Berlin → **Hambourg**. Ce n'est
   pas un autre ruban, c'est un **préfixe pris là où il est écrit** ; Cork →
   Luxembourg se greffe devant plus tard sans rien casser.

   | | |
   |---|---|
   | Jouable dès le lot D | 4 chapitres, 24 niveaux (jusqu'à Cologne) |
   | Après 9 fiches | 11 chapitres, **63 niveaux**, jusqu'à Hambourg |

   Les neuf : Wiesbaden, Darmstadt, Heidelberg, Bruchsal, Vaihingen, Dachau,
   Pfaffenhofen, Kinding, Allersberg.

   Sur la carte, la partie non écrite du ruban s'affiche **« à venir »** et ne
   se joue pas — jamais de gare proposée sans fiche.

*Fini quand* : `node tools/carte-check.mjs europe` est vert sur le ruban v1, et
refuse (code ≠ 0) si on retire une gare d'un chapitre, si on duplique une
fiche, ou si on casse la continuité sans déclarer de saut.

</details>

## Lot D — Le ruban dans le moteur — FAIT (25 août 2026)

*Livré* : `js/ruban.js` (254 lignes) remplace `js/graph.js` — position déduite,
jamais stockée ; `estFaite` / `estPassee` / `estFranchie` / `estTenue` ;
`gareCourante`, `auBoutDeLEcrit`, `chapitreTermine` ; la rampe de difficulté
(plancher du chapitre → arrivée, rabattue par `plafondDeFlux`) ; `PROFILS`,
`ENVELOPPES`, `enveloppeDe` repris tels quels parce qu'ils étaient mesurés.
`js/store.js` en **schéma 7** : `bought` abandonné, `passees` créé,
`isBought` délègue à `estTenue`. `js/recompense.js` passe aux chapitres et
reçoit les **crédits déduits** (`soldeCredits`, `prixDePassage`, la dépense ne
comptant que les gares passées encore à 0 ★). `js/parcours.js` (269 lignes)
remplace `js/carte.js` : un bouton *Continuer*, la piste du chapitre, le
relevé avec *Continuer* / *Rejouer* ou *Réessayer* / *Passer · ◆ N*.

*Vérifié en headless* (Chrome + client CDP maison) :
- Arlon se joue en **difficulté 1**, Bruxelles-Midi en 3 (plafond de chapitre) ;
  la rampe du ruban est 1·1·2·2·3·3 puis 2·2·3·3·4·4, jusqu'à 4·4·4·5·5·5.
- On appuie sur *Continuer* et l'on joue **six gares d'affilée sans jamais
  rien choisir**.
- Échec → *Réessayer* et *Passer · ◆ 5* côte à côte ; payer avance le ruban
  sans donner d'étoile ; **regagner la gare rend la mise** (dépense 0).
- **Migration v6 → v7 sans perte** : étoiles, diamant, série et même les
  étoiles des gares HORS ruban conservées ; position recalculée seule.
- Au bout des 28 gares écrites : « la suite du ruban n'est pas encore écrite ».

*Reste* : `js/carte.js` et `js/hub.js` sont au dépôt mais **plus chargés** —
le lot E doit reprendre leur projection et leur caméra avant qu'on les retire.

<details><summary>Le plan d'origine du lot D</summary>


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

</details>

## Lot E — Les écrans — FAIT (25 août 2026)

*Livré* : `js/parcours.js` réécrit — **la carte cadrée sur le chapitre en
cours**, et sur lui seul. Deux colonnes : le **panneau à gauche** (chapitre,
fiche de la gare, relevé, bouton) et la **scène** à droite, où la carte prend
tout le reste.

*Corrigé le jour même, après le premier test de Vincent* : la première version
dessinait tout le ruban et zoomait sur la gare, avec trois niveaux de caméra.
Trois retours, trois simplifications — un seul chapitre à l'écran (« cela
paraît trop petit sinon »), les infos dans un panneau à gauche plutôt qu'au
milieu, et **le bouton de dézoom supprimé** (« je ne suis pas certain qu'il
soit nécessaire » — il ne l'était pas). La projection reste globale : changer
de chapitre déplace vraiment la caméra vers le nord ou vers l'est, et un
**saut** dure deux fois plus longtemps.

*Ce qui se voit* : le fond de pays (Natural Earth) reste neutre — **le fond est
un fond, le ruban est le sujet** — et c'est le fil qui porte la couleur de la
zone. Fait : plein. À faire : éteint. Pas encore écrit : pointillé, parce que
la carte ne ment pas sur ce qui n'existe pas. La gare en cours pulse d'un cerne
géométrique (jamais un `drop-shadow` : invisible sur iPhone, mesuré).

*Le cartouche* dit ce qu'il faut savoir avant de prendre le service : la ville,
« L'Ardenne · gare 1 sur 6 », **les quais et les directions** — c'est de là que
vient la difficulté — et la jauge à cinq crans.

*Le relevé* : **Continuer** et *Rejouer* à la réussite ; **Réessayer** et
*Passer · ◆ N* à l'échec, avec, si le solde ne suffit pas, où aller le gagner.
La hiérarchie s'inverse selon l'issue : à l'échec, c'est *Réessayer* qui est le
geste principal.

*La fin de chapitre* : la caméra prend du recul, le chapitre se ferme avec son
rang, et **le suivant est nommé** — c'est ce qui manquait le plus au test de
jeu. *En route* redescend sur la gare.

*Deux réparations en chemin* : `js/geo.js` n'était plus chargé par le jeu
depuis que la carte géographique avait disparu — la carte du ruban en a besoin,
il est de nouveau dans `station.html` ; et les symboles se dessinaient en
unités du monde, donc grossissaient avec le zoom (à ×7 un point de gare faisait
une soucoupe). Rayons et décalages se divisent maintenant par k, ce qui impose
de redessiner le calque des gares après la caméra — le seul qui en dépende.

*Vérifié en headless, capture à l'appui* : six gares jouées d'affilée, la fête de fin de chapitre (« L'Ardenne · Chapitre d'or
· La suite : Le Benelux »), *En route* qui relance sur Malines et redescend au
niveau gare, l'échec avec ses deux issues et « il te manque 5 crédits ».

**Reprise du panneau (25 août, après le deuxième retour)** — « arrange le cadre
à gauche pour que ce soit plus agréable à lire, corrige les défauts
d'alignement » :

- **Une seule gouttière pour tout le panneau**, portée par le conteneur et non
  par chaque bloc. C'était le vrai défaut : compteur, titre, région, jauge,
  fiche et bouton avaient chacun leur marge, et le bouton se retrouvait
  indenté deux fois. Bords gauche ET droit coïncident désormais partout.
- **L'eyebrow ne casse plus en orphelin** (« CHAPITRE / 1 SUR 11 ») : trois
  lignes assumées — compteur court en monospace, nom du chapitre en grand,
  région dessous dans sa couleur.
- **Le filet du chapitre** tient la largeur du texte au lieu de courir sous
  tout le panneau. Un trait qui déborde de son bloc n'appartient à rien.
- **Le corps ne flotte plus au milieu** : il est posé sous l'en-tête, le vide
  est en bas, et le bouton tient le pied en pleine largeur.
- **La fiche cesse de répéter le chapitre** (« L'Ardenne · gare 1 sur 6 » →
  « Gare 1 sur 6 »), gagne le pays et **la phrase de la gare** — écrite pour
  chaque fiche, inutilisée depuis que le toast a été désactivé, et c'est elle
  qui rend le panneau *lisible* plutôt qu'un relevé de compteurs. Les mesures
  passent en colonnes libellées (Quais / Directions / Difficulté) : la jauge
  flottait au bout d'une rangée sans dire ce qu'elle mesurait.
- **La fête reste sur le chapitre qu'on vient de finir** — en-tête, jauge
  pleine, rang, et la carte encore allumée dessus. L'écran passait déjà au
  suivant pendant qu'on célébrait le précédent : on félicitait le joueur d'un
  chapitre en lui montrant l'autre. *En route* fait le pas, et c'est là que la
  caméra voyage.

*Reste au lot H* : l'écran des cartes proprement dit (il n'y a qu'une carte, il
est sauté). `js/carte.js` peut maintenant être retiré (lot J).

<details><summary>Le plan d'origine du lot E</summary>


**But** : l'enchaînement décrit par Vincent le 25 août (§4 quater du document).
C'est ce lot qui répond au test de jeu.

1. **L'écran des cartes** — sauté tant qu'il n'y a qu'une carte possédée ;
   accessible au dézoom maximal. Une tuile par carte (nom, sous-titre,
   chapitres, niveaux, progression, prix). Le gros de l'écran est au lot H ;
   ici on ne pose que le passage.
2. **La carte posée sur la gare en cours** (`js/carte.js`) — pas l'Europe
   entière : la caméra cadre **la prochaine gare**, mise en évidence, avec son
   cartouche d'infos (nom, ville, « gare 3 sur 6 · Le Rhin romantique »,
   quais, directions). Le ruban se lit derrière : fait en couleur, à venir en
   gris, non écrit en « à venir ». Trois crans de dézoom : gare → chapitre →
   carte. La caméra existante (`CARTE.camCible {x,y,k}`) fait déjà ce travail,
   il s'agit de la piloter depuis la position sur le ruban.
3. **Un seul bouton au lancement** : *Continuer* — nom de la prochaine gare,
   nom du chapitre, « gare 4 sur 7 ». Rien d'autre à décider.
4. **La première gare est le tutoriel** : pas un écran séparé, le premier
   niveau guidé. Réutiliser l'onboarding existant (`station-onboarded`) en le
   rattachant à la première gare du ruban plutôt qu'au premier lancement.
5. **Le relevé de fin.** Réussite : retard, étoiles, diamant, série, puis
   **Continuer** et **Rejouer**. Échec : **Réessayer** (gratuit, illimité) et
   **Payer le passage** (§4 ter) côte à côte, avec le solde et le prix, et —
   si le solde ne suffit pas — où aller le gagner.
6. **Le voyage vers la gare suivante** : la caméra glisse le long du rail. La
   même animation, allongée et accompagnée de sa phrase, joue les **sauts**
   (§4 bis). Passable d'un geste.
7. **La fin de chapitre** s'intercale : rang du chapitre, nom du suivant
   annoncé. **La fin de zone** colore la carte.
8. **Jamais de vies, jamais de minuterie.**

*Fini quand* : en headless, on ouvre le jeu, on appuie sur *Continuer*, on joue
trois gares d'affilée sans jamais choisir quoi que ce soit, la fin de chapitre
annonce le suivant, le premier échec fait apparaître l'offre de passage à côté
de *Réessayer*, dix échecs de suite la laissent intacte, la payer avance le
ruban sans donner d'étoile, et gagner la gare ensuite restitue les crédits.

</details>

## Lot F — Contenu : écrire le ruban

**But** : donner au ruban ses gares. Le tracé n'est plus une question — il est
écrit dans **`ruban-europe.md`** : 9 actes, 95 chapitres, 593 gares dans
l'ordre du rail, 8 sauts, de Cork à Istanbul. Ce lot ne décide plus, il écrit.

1. **123 gares sont déjà écrites** et réemployées telles quelles. **12 chapitres
   sont jouables intégralement dès aujourd'hui** (68 niveaux : Lille–Paris, puis
   Genève → Zurich → Strasbourg → Luxembourg → Bruxelles → Amsterdam → Hanovre →
   Cologne, et Stuttgart → Munich, Nuremberg → Leipzig → Berlin → Hambourg).
   Écrire **Arles** et **Wiesbaden** en porte deux de plus : 14 chapitres,
   79 niveaux, un ruban continu de Genève à Hambourg.
2. **470 fiches à écrire**, dans l'ordre de rentabilité (`ruban-europe.md`,
   « par où commencer ») : acte V (25 fiches), acte II (24), acte I (96),
   puis Ibérie, Italie, et enfin le Nord et l'Est, entièrement neufs.
3. **Le ruban se joue dans l'ordre, mais se livre dans le désordre** : un acte
   complet en milieu de ruban est du contenu prêt. Rien n'oblige à écrire de
   gauche à droite.
4. **Chaque gare passe le §0 de `AUTHORING-STATIONS.md`** — ≥ 3 directions
   réelles, 3-4 quais. Les listes de `ruban-europe.md` sont des points de
   passage réels, **pas des fiches validées** : il y aura des refus, et la
   parade est de prendre la gare voisine ou de redécouper le chapitre, jamais
   d'inventer un portail.
5. **Caler la rampe** : le tableau des planchers par tranche de chapitres
   (`ruban-europe.md`, « la rampe de difficulté ») est une proposition. La
   mesurer en headless sur le ruban réel, et vérifier que `plafondDeFlux`
   rabat proprement (question ouverte n° 3).
6. **Trancher les collisions d'identifiants** avant d'écrire : `valence`
   (Drôme) vs Valence d'Espagne → `valencia` ; Brest-Litovsk vs Brest ;
   Cordoue, Naples. Une collision découverte après coup coûte un renommage
   dans l'index, la carte et `geo.js`.
7. **Chaque chapitre livré = un commit poussé**, avec ses contrôles.

*Fini quand* : `carte-check europe` est vert, et une partie complète en
headless va de Cork à Istanbul sans blocage, sans doublon de gare, et sans
saut non déclaré.

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

**Le ruban v1 est complet et se joue de bout en bout** — 11 chapitres,
63 gares, d'Arlon à Hambourg, vérifié en headless le 26 août 2026.
`carte-check` dit « 63 jouables d'affilée · 0 fiche à écrire ».

La suite est donc le **lot F** hors du v1 : allonger le ruban vers les actes
voisins. Par rentabilité (`ruban-europe.md`, « par où commencer ») c'est
l'acte V qui est le plus près d'être fini — **11 fiches** le complètent, contre
27 pour l'acte II et 89 pour l'acte I.

Deux dettes connues, petites et indépendantes :

- **Toulouse et Lunebourg** sont des gares « de queue » : elles passent les
  30 journées (moyennes 3,0-3,4) mais échouent au hasard sur un balayage libre
  à K=6. Elles rendront `gen-check` rouge de temps en temps tant qu'on n'a pas
  desserré leur enveloppe.
- **`enregistrer.mjs` replie `index.json` sur 90 caractères**, ce qui produit
  des centaines de lignes de diff sans contenu à chaque enregistrement. Le
  faire écrire une gare par ligne rendrait les diffs lisibles.

Le **lot J** (supprimer `js/carte.js`, mort depuis le lot E) reste ouvert.
