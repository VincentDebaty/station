# Écluses — le concept du jeu complet (phase 2)

Vincent, 13 octobre 2026 : la phase 1 du prototype est validée (chapitre 1 au
doigt maintenu, croisement côte à côte dans un sas, pancartes, déploiement
sans câble). On passe au **jeu complet, limité à un seul monde** : un petit
village de campagne et ses écluses. D'autres mondes viendront plus tard
(montagne enneigée, Caraïbes, désert, volcans, futuriste…).

Ce document **verrouille** les bases avant d'écrire du code : la boucle d'une
partie, la difficulté, le nombre de niveaux, les récompenses, la monétisation,
et ce que le design actuel doit encore régler. Chaque point se termine par une
**décision proposée**. Celles qui demandent l'avis de Vincent sont regroupées
au §10.

Modèle revendiqué : **Block Out** — simple et efficace.

---

## 1. Ce qu'on prend à Block Out, et ce qu'on n'en prend pas

« Block Out » désigne plusieurs jeux sur les stores. Le plus en vue est celui de
**Grand Games** (les auteurs de *Magic Sort* et *Color Block Jam*) : un casse-tête
de tri de blocs, à niveaux déterministes, qui fait environ 300 000 $ par jour sur
iOS d'après une analyse d'acquisition d'utilisateurs ([Gamigion](https://www.gamigion.com/?p=33871)).
Ce que les sources publiques en disent ([fiche App Store](https://apps.apple.com/app/id6740481627),
[analyse](https://tr.linkedin.com/in/okan-sayar)) :

- **une suite linéaire de niveaux**, sans choix de parcours : on joue le suivant ;
- des niveaux **déterministes**, avec une **étiquette « difficile »** sur certains
  niveaux, pour prévenir le joueur ;
- un **chrono** par niveau : c'est lui qui crée l'échec ;
- des **vies** : un échec en coûte une, elles se rechargent avec le temps ;
- des **pièces** (gagnées en jouant, vendues en paquets de 1 000 pour 1,99 $ à
  25 000 pour 49,99 $), qui paient les **bonus** et la **reprise après un échec** ;
- un **pass** à 7,99 $ (plus de vies, et l'offre montrée après un échec), un
  **pack de départ** à 9,99 $ ;
- de la **publicité entre les niveaux** (interstitielle après chaque niveau
  gagné, environ un tiers des revenus publicitaires) et de la **vidéo
  récompensée** pour recharger ses vies.

**Confirmé par Vincent** (13 octobre 2026) : c'est bien celui de Grand Games.
Le guide de fans [blockout.cc](https://blockout.cc/fr/) ajoute : **946 niveaux**
recensés, chacun noté Facile, Moyen, Difficile ou Super difficile ; un bloc
glisse jusqu'à un obstacle et sort par la porte de sa couleur, et **l'ordre
des coups** fait tout. Surtout, **Annuler y est gratuit et illimité** : ce
n'est pas Annuler qui crée la tension, c'est le chrono, qui continue de tourner
quand on annule. Le guide présente le jeu comme « sans publicité », ce que
contredit l'analyse de Gamigion ; on retient le modèle avec publicité, le plus
courant dans le genre.

**Ce qu'on prend :** la suite linéaire, les étiquettes de difficulté, les vies,
les pièces, les bonus, la reprise après échec, le duo publicité + achats.

**Ce qu'on ne prend pas :** le chrono. Écluses est un casse-tête de
**réflexion** : l'eau met plusieurs secondes à passer, et l'enfant de 10 ans
qui l'a testé l'a aimé pour cela. L'échec viendra du **nombre de coups**, pas
du temps (§2).

---

## 2. La boucle d'une partie

Aujourd'hui, le prototype n'a pas vraiment d'échec : **Annuler** est gratuit et
illimité, et on peut faire autant de coups qu'on veut. Le solveur connaît la
meilleure solution (le « par »), mais ne s'en sert que pour les étoiles.

Sans échec, il n'y a ni vie, ni reprise, ni bonus à vendre. C'est le premier
verrou. Block Out le résout par le chrono ; on le résout par les coups.

**Décidé** (Vincent, 13 octobre 2026). Exemple : le 1-3 « L'escalier »,
meilleure solution en 7 coups, étiqueté Normal.

| Élément | Règle |
|---|---|
| **Un coup** | Chaque appui sur une roue (ou sur la pelle, la pompe…). Tenir le doigt ne coûte rien de plus : un appui tenu jusqu'au bout reste un coup. Les bateaux qui avancent et l'eau qui coule ne coûtent rien. |
| **Le doigt qui glisse** | Reprendre aussitôt la même porte dans le même sens, sans avoir rien touché entre les deux, **ne compte pas** un nouveau coup. |
| **Le budget** | Meilleure solution + une marge selon l'étiquette (§3) : Normal +4, Difficile +2, Très difficile +1. Au 1-3 : **11 coups**. Le HUD affiche « Coups restants : 11 », qui descend à chaque appui. |
| **Victoire** | Tous les bateaux à leur bouée (et le feu éteint, le champ abreuvé…). Si le dernier coup fait gagner, on laisse l'eau se poser et les bateaux arriver avant de juger. |
| **Étoiles** | 3 étoiles au par (7 coups au 1-3), 2 étoiles jusqu'à par + 2 (9), 1 étoile au-delà, dans le budget. Elles nourrissent la méta (§5). |
| **Annuler** | **Gratuit et illimité**, comme dans Block Out, mais **le coup reste dépensé** : l'eau et les bateaux reviennent, le compteur continue. C'est le chrono de Block Out, qui tourne même quand on annule. |
| **Un seul échec** | **Plus de coups** : le budget arrive à 0 et les bateaux ne sont pas arrivés → pancarte « Plus de coups ! ». |
| **Coincés, inondé** | Ce ne sont **plus des échecs** : la pancarte dit ce qui s'est passé et propose Annuler. Comme Annuler coûte des coups, une impasse finit par épuiser le budget. |
| **Reprise** | À l'échec, une seule fois : **+3 coups**, contre des pièces ou une vidéo. |
| **Vies** | Rejouer après un échec coûte une vie ; **quitter un niveau commencé** aussi (sinon on contourne les vies en partant juste avant de perdre). |

**Le réglage délicat, c'est la marge.** Trop large, on ne perd jamais et la
monétisation tombe ; trop serrée, on ne fait plus que chercher la solution
parfaite. +4 / +2 / +1 est un point de départ. Le banc mesure, pour chaque
niveau, la part des parties au hasard qui tiennent dans le budget ; on règle
ensuite sur les vrais taux d'échec du lancement test (§7.3).

Ce qui ne change pas : le doigt maintenu, l'eau qui se pose, les bateaux qui
partent seuls, la bulle d'aide au toucher du bateau.

---

## 3. Les niveaux de difficulté

### 3.1 Mesurer, pas deviner

Le banc mesure déjà, pour chaque niveau : le par, le nombre d'états explorés
par le solveur, et le taux de victoire de 300 parties jouées au hasard. Sur
les 25 niveaux actuels, le hasard gagne de 0 % à 69 % des parties. On ajoute
deux mesures, et on en tire **une note de difficulté** calculée par le banc :

1. **le par** (longueur de la solution) ;
2. **le taux de victoire au hasard** (plus il est bas, plus le niveau piège) ;
3. **la marge** : le nombre de solutions qui tiennent dans le maximum de coups ;
4. **les pièges** : la part des premiers coups qui mènent à une impasse.

La note est calibrée sur les essais de Vincent et de sa fille, puis sur les
données réelles (taux d'échec par niveau, §7).

### 3.2 Trois étiquettes, une courbe en dents de scie

Comme dans le genre :

- **Normal** — la plupart des niveaux ;
- **Difficile** — environ 1 niveau sur 5, étiquette orange, récompense ×2 ;
- **Très difficile** — environ 1 niveau sur 10, étiquette rouge, récompense ×3.

Dans chaque chapitre de 10 niveaux, la difficulté monte puis retombe :

| Niveau | Rôle |
|---|---|
| 1 | **présentation** du nouveau mécanisme (la main le montre déjà) |
| 2 à 8 | le nouveau mécanisme combiné aux anciens, dont **2 Difficile** |
| 9 | **Très difficile**, le sommet du chapitre |
| 10 | **respiration**, plus facile, avant le coffre de chapitre |

Le chapitre 1, qui n'a que des portes, aura peut-être du mal à offrir 10
niveaux vraiment différents : le générateur le dira, et il pourra être plus
court au profit d'un autre.

**Règle du banc** (refuse, comme les autres contrôles) : un niveau étiqueté
doit avoir une note dans la plage de son étiquette, et aucun niveau Normal ne
doit dépasser le premier Difficile du chapitre.

---

## 4. Combien de niveaux pour le monde du village

### 4.1 Les mécanismes du village

Le prototype a 18 systèmes (SYSTEMES.md). Ils ne vont pas tous au village. On
les répartit par monde, pour que chaque monde ait **ses** nouveautés :

| Monde | Mécanismes |
|---|---|
| **Village (monde 1)** | dans l'ordre des chapitres : porte, porte à vanne, rigole, pompe, pont bas, orage, moulin, castor, grange en feu, crue du fleuve — **10** |
| Montagne (neige) | glaçon et brasero, ascenseur à bateaux, gel |
| Caraïbes | marée, vase et drague, mer |
| Volcan | chaudière (vapeur), coulée qui bouche |
| Futuriste | siphon, clapet, bassin d'épargne, porte à flotteur |

Les mécanismes déjà écrits pour d'autres mondes restent au moteur et attendent
leur monde.

**Décidé** (Vincent, 13 octobre 2026) : **10 chapitres** pour le village. Deux
mécanismes en sortent : la **porte à flotteur** (trop technique pour un
village, rangée au monde futuriste) et les **champs à irriguer** (sans bateau,
c'est presque un autre jeu : gardés pour un éventuel mode bonus). Sur les 10,
les quatre premiers sont validés sur iPhone ; les six autres sont écrits mais
pas encore essayés par Vincent : ils passent par son essai au lot 3.

### 4.2 Le compte

Un chapitre par mécanisme. Chaque chapitre : 1 niveau de présentation, puis
des niveaux qui combinent le nouveau mécanisme avec les précédents.

- **Au lancement test : 10 chapitres × 10 niveaux = 100 niveaux** (décidé
  par Vincent le 13 octobre 2026). **Au lancement mondial : 200**, si le
  générateur confirme qu'autant de niveaux distincts sont possibles. Un niveau dure 1 à 2 minutes (5 à 8 coups, l'eau qui passe) :
  **2 h 30 à 3 h 30 de jeu**.
- **Plafond estimé pour le monde 1 : 200 à 250 niveaux**, avant que les
  combinaisons ne se répètent. C'est une **estimation**, à mesurer (§4.3).

Pour comparaison, Block Out compte 946 niveaux recensés par son guide de
fans, et le genre en ajoute chaque semaine. Un monde d'une centaine de niveaux suffit pour un
lancement test (§9, lot 7), pas pour un lancement mondial.

### 4.3 Fabriquer les niveaux : un générateur

À la main, un niveau coûte aujourd'hui une à deux heures (règle, solveur,
banc, rendu). Cent niveaux à la main, c'est trop. On écrit un **générateur**
(outil Node, comme le banc) qui :

1. tire des canaux au hasard dans les gabarits d'un chapitre (3 à 6 bassins,
   1 à 3 bateaux, les mécanismes permis) ;
2. les résout ;
3. garde ceux qui ont une **solution unique ou presque**, une note dans la
   plage voulue, et un **coup clé** (un moment où le mauvais choix piège) ;
4. range les élus dans `niveaux.json`, avec leur note et leur étiquette.

Vincent garde le dernier mot : il joue et écarte. La première mesure du
générateur dira **combien de niveaux distincts** le village peut vraiment
produire. C'est elle qui fixera le plafond du §4.2.

---

## 5. Les récompenses

Le genre garde la méta **légère** : on joue le niveau suivant, on gagne des
pièces, on ouvre un coffre de temps en temps. Pas de ville à construire.

**Décision proposée :**

| Récompense | Quand | Ce qu'elle donne |
|---|---|---|
| **Pièces** | chaque victoire | 10 (Normal), 20 (Difficile), 30 (Très difficile) ; ×2 contre une vidéo |
| **Étoiles** | chaque victoire | 1 à 3 selon les coups (§2) |
| **Coffre de chapitre** | fin de chapitre (tous les 10 niveaux) | pièces + 1 bonus |
| **Collection de bateaux** | paliers d'étoiles (30, 60, 100…) | une nouvelle couleur ou un nouveau bateau. Le shader de recoloration existe déjà. |
| **Le village qui s'anime** | chaque chapitre | la carte de progression montre le village : une maison s'allume, un moulin tourne, des gens apparaissent |
| **Série quotidienne** | 1 niveau gagné par jour | petit bonus croissant sur 7 jours |

Ce qu'on ne fait pas au lancement : événements en équipe, classements,
concours. Ce sont les leviers des jeux à grosse équipe ; ils viennent après le
lancement test, si les chiffres le justifient.

---

## 6. Les bonus (ce que paient les pièces)

Ils doivent sortir d'une impasse **sans casser la règle de l'eau**, et le
solveur doit pouvoir les vérifier.

| Bonus | Effet | Débloqué |
|---|---|---|
| **Rendre un coup** | annule le dernier coup **et** le rend au compteur (Annuler, lui, est gratuit mais ne rend pas le coup). Il ne sert qu'à celui qui est à court de coups : un levier de vente qui ne gêne pas le joueur normal. | niveau 10 |
| **Indice** | la main montre le prochain coup de la meilleure solution (main.gd existe) | niveau 5 |
| **+3 coups** | trois coups de plus | à l'échec |
| **Seau** | ajoute ou retire un cran d'eau dans un bassin | niveau 20 |

---

## 7. La monétisation

### 7.1 Le modèle

**Gratuit, avec publicité et achats intégrés**, comme Block Out.

| Levier | Règle proposée |
|---|---|
| **Vies** | 5 au maximum ; un échec en coûte une ; une revient toutes les 30 minutes. |
| **Interstitielle** | après une victoire, **à partir du niveau 15**, au plus une tous les 2 niveaux et toutes les 90 secondes. Jamais pendant un niveau, jamais après un échec. |
| **Vidéo récompensée** | toujours au choix du joueur : une vie, +3 coups, pièces ×2, un bonus gratuit par jour. |
| **Sans publicité** | achat unique, autour de 5,99 € ; garde les vidéos récompensées (au choix). |
| **Pièces** | paquets de 1 000 à 25 000, de 1,99 € à 49,99 € (les prix du genre). |
| **Pack de départ** | une fois, autour de 4,99 € : pièces, bonus, sans publicité 24 h. |
| **Pass** | plus tard, après le lancement test. |

### 7.2 Le public — une question à trancher tôt

La fille de Vincent (10 ans) a adoré. Si le jeu **vise les enfants**, les
règles changent du tout au tout : catégorie Enfants d'Apple et COPPA (États-Unis),
publicité très limitée, pas de suivi, achats verrouillés derrière un contrôle
parental. **Proposition : un jeu tous publics** (classé 4+, rien de choquant),
pensé pour les adultes du genre casual, **sans** viser la catégorie Enfants.
À faire vérifier avant le lancement (règles Apple, Google, RGPD).

### 7.3 Les données

Le genre règle sa difficulté **sur les chiffres** : taux d'échec par niveau,
nombre d'essais, abandon. Il faut un outil de mesure dès le lancement test,
sinon l'étiquette Difficile reste une intuition.

---

## 8. Le design actuel est-il adapté ?

**Oui pour l'essentiel.** Le geste (doigt maintenu), l'eau, les bateaux et les
pancartes ont été validés à la main, par Vincent et par un enfant de 10 ans
sans aide. Cinq points restent à régler :

1. **L'orientation.** Le jeu est en **paysage** ; les succès du genre sont en
   **portrait**, à une main, pour les sessions courtes et les vidéos
   publicitaires. Une coupe de canal est naturellement en largeur : passer en
   portrait voudrait dire empiler les bassins ou zoomer. **Proposition : rester
   en paysage**, en acceptant ce handicap, et le noter comme un risque pour
   l'acquisition.
2. **La lisibilité.** Les niveaux vont jusqu'à 6 bassins. Au-delà, sur un
   téléphone de 6 pouces, tout rétrécit. **Plafond proposé : 6 bassins,
   3 bateaux.**
3. **Le temps d'attente.** Un sas met environ 6 secondes à se remplir. Sur 7
   coups, c'est près d'une minute à regarder l'eau. C'est agréable au début,
   long au 80e niveau. À mesurer au lancement test ; le toucher qui accélère
   existe déjà.
4. **Le HUD.** Il faut y ajouter les coups restants, les vies, les pièces et la
   barre de bonus, sans couvrir le canal.
5. **La cohérence des images.** Les images viennent de ChatGPT, image par
   image. Pour le monde 1 au complet, puis les mondes suivants, il faut une
   **fiche de style** (palette, lumière, épaisseur des contours, cadrage) et
   une liste d'images par monde. ASSETS.md en est le début.

**Deux risques techniques**, à lever avant tout le reste (lot 0) :

- **la publicité et les achats dans Godot.** Les régies (AdMob, AppLovin) n'ont
  pas toutes de module Godot officiel, et c'était le seul argument pour Unity ;
- **la performance sur Android d'entrée de gamme.** L'iPhone 16 Pro tient 100
  images par seconde ; un téléphone Android à 150 € n'a pas été mesuré.

---

## 9. Le plan de développement

Chaque lot a sa condition de fin, mesurable (comme les contrôles de Station).

| Lot | Contenu | Fini quand |
|---|---|---|
| **0 — Risques** | une version de test iOS + Android avec une publicité, un achat test et l'envoi d'une mesure ; performance sur un Android d'entrée de gamme | les trois marchent sur les deux systèmes, et l'Android tient 60 images/s sur le 1-4 |
| **1 — La partie** | budget de coups, un seul échec (plus de coups), Annuler qui ne rend pas le coup, reprise, vies, pancartes | le banc vérifie le budget de chaque niveau ; démos filmées |
| **2 — Difficulté et générateur** | note de difficulté, étiquettes, générateur de niveaux | le banc refuse une étiquette fausse ; le générateur sort 30 niveaux acceptés pour un chapitre |
| **3 — Les 10 mécanismes du village** | porter au doigt maintenu ceux qui ne le sont pas encore | chacun a son niveau de présentation, validé par Vincent sur iPhone |
| **4 — La méta** | carte du village, pièces, étoiles, coffres, collection, série | sauvegarde versionnée qui survit à une mise à jour |
| **5 — La boutique** | vies, bonus, publicité, achats, sans publicité | achats de test passés sur les deux stores |
| **6 — Le contenu** | 100 niveaux, équilibrés | banc vert ; Vincent a joué chaque chapitre |
| **7 — Lancement test** | un ou deux pays, mesures | taux de retour à J1 et J7, taux d'échec par niveau lus et appliqués |

L'autorité reste la même : la page web et son banc pour les règles, Godot pour
le rendu, l'oracle entre les deux.

---

## 10. Les décisions à prendre par Vincent

1. ~~Block Out : est-ce bien celui de Grand Games ?~~ Oui (13 octobre 2026).
2. ~~L'échec par les coups (§2), plutôt que par le temps ?~~ Oui (13 octobre 2026).
3. ~~Annuler reste gratuit mais ne rend pas le coup (§2) ?~~ Oui, avec un seul échec : plus de coups.
4. ~~Les mécanismes du village (§4.1) ?~~ 10 chapitres, sans le flotteur ni les champs (13 octobre 2026).
5. ~~Combien de niveaux au lancement (§4.2) ?~~ 100 pour le lancement test, 200 visés au lancement mondial (13 octobre 2026).
6. **Le public** : tous publics sans viser la catégorie Enfants (§7.2) ?
7. **Paysage** maintenu malgré le genre en portrait (§8) ?
8. **L'ordre des lots** : lever d'abord les risques techniques (lot 0) ?
