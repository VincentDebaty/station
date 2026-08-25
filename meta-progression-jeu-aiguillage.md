# Jeu d'aiguillage — Conception de la méta-progression

> Document de référence. Première version le 20 août 2026 (le graphe européen,
> les boss, les lignes, les récompenses) ; révisé le 21 août 2026 (structure en
> quatre niveaux, notion de CARTE) ; **refondu le 25 août 2026 : la carte n'est
> plus un graphe à parcourir librement, c'est un RUBAN — une suite ordonnée de
> gares, sans embranchement.**
> Le gameplay d'un niveau (aiguiller les trains d'une gare vers la bonne
> destination) est acquis, testé et approuvé : il n'est pas couvert ici.
> Le plan de réalisation est dans `plan-de-dev.md`.

---

## 0. Pourquoi le ruban (décidé le 25 août 2026)

La version graphe a été jouée. Verdict du test : **on ne comprend pas où on
veut aller.** Trois causes, mesurées le 25 août sur `data/cartes/europe.json` :

1. **Le choix au hub est un choix sans information.** Arrivé à Bruxelles, on
   propose Amsterdam, Luxembourg ou Cologne. Rien ne distingue ces trois
   branches : même gameplay, même récompense, même promesse. Un choix sans
   enjeu ne donne pas de la liberté, il donne de la charge mentale.
2. **Le document se contredisait.** Le §1 annonçait « Candy Crush ferroviaire »
   et le §3 posait R1/R2/R2 bis — 20 hubs, 50 lignes, 3 sorties par hub. Ce
   sont les règles d'un jeu de conquête, pas d'un jeu à niveaux. Candy Crush
   et Duolingo n'ont pas de graphe : ils ont **un fil et un seul bouton**.
3. **Le coût de contenu était intenable.** Le graphe demandait 800 à 1 400
   niveaux pour être seulement cohérent, parce que chaque hub devait avoir
   trois sorties remplies. Mesure du 25 août : 26 lignes complètes sur 128,
   28 grandes gares écrites sur 83. Quatre sorties sur cinq menaient dans le
   gris — la structure était illisible autant par vide que par branchement.

**Ce que le ruban change** : on avance d'une gare à la suivante, dans un ordre
écrit à l'avance. Un seul bouton, *Continuer*. La carte d'Europe reste — mais
elle **montre** la progression au lieu de la **décider**.

**Ce que le ruban ne change pas** — et c'est l'essentiel : le gameplay d'une
gare, les 234 fiches, la carte à trois échelles (`js/carte.js`), la couche
récompense déduite (`js/recompense.js`), la notion de carte du lot A. Le
travail de contenu déjà fait est intégralement réemployé : les 26 lignes
complètes **sont** les premiers chapitres du ruban.

**Ce qu'on perd, dit franchement** : la fantaisie de conquête, « je fais
l'Europe à ma façon ». Elle n'a jamais été validée comme amusante et le test
dit qu'elle n'est pas lisible. On l'abandonne sans compensation.

**Embranchements** : écartés au lancement (tranché le 25 août). Un ruban
strictement unique d'abord ; on pourra ajouter plus tard des fourches qui se
rejoignent, comme Candy Crush en a. L'inverse — retirer des fourches d'un jeu
qui en a — est beaucoup plus dur.

---

## 1. Vision d'ensemble

Un jeu de type « Candy Crush ferroviaire » : des centaines de niveaux
autonomes, ancrés dans la géographie ferroviaire réelle. Chaque niveau est une
gare réelle avec son vrai plan de voies — c'est l'identité du jeu et on n'y
renonce pas.

Philosophie de difficulté : **réussir est facile, exceller est le vrai jeu**.
Aucune porte dure, aucun rejeu obligatoire ; la performance (étoiles,
diamants) est la chasse optionnelle qui fait revenir.

La progression s'empile sur **quatre niveaux**, du plus petit au plus grand :

| Niveau | Ce que c'est | Objectif du joueur | État |
|---|---|---|---|
| **1. La gare** | Un niveau : aiguiller les trains vers la bonne destination | Finir le service (≥ 1 étoile), puis exceller (3 ★, diamant) | **En place, testé, approuvé** |
| **2. Le chapitre** | 5 à 10 gares consécutives du ruban, finissant sur une grande gare | Atteindre la grande gare au bout et la tenir | Remplace la « ligne » — à écrire |
| **3. La zone** | 3 à 6 chapitres sur un territoire cohérent (France-Benelux, Germanie…) | Traverser la zone, puis la dorer | Existe comme calque ; devient un palier d'objectifs |
| **4. La carte** | Un territoire (continent, pays, ville) : le ruban entier | Aller au bout du ruban, puis le dorer | Une seule carte (Europe) ; le modèle multi-cartes est en place (lot A) |

Les trois premiers niveaux décrivent *comment on avance* ; le quatrième décrit
*où l'on joue*. Les cartes sont des **missions indépendantes** (§2.4).

---

## 2. Les quatre niveaux

### 2.1 La gare (niveau 1) — inchangé

- Une gare = un niveau = un service d'une journée à aiguiller. Acquis.
- Condition de réussite : **ne pas cumuler plus de 30 minutes de retard**.
  Barème : 3 ★ < 10 min · 2 ★ < 20 · 1 ★ < 30 · sans-faute = 3 ★ **+ 1 diamant**
  (le diamant s'empile, il ne remplace jamais : mieux jouer ne rapporte jamais
  moins). Seuils configurables par gare, défaut 30/20/10.
- Plancher de jouabilité : **au moins 3 directions et 3-4 quais**. Une gare de
  passage sur une seule ligne (2 directions) n'est pas un niveau — mesuré :
  trop creux à jouer. C'est un croisement d'au moins deux lignes réelles.
- La difficulté qu'une gare peut porter n'est pas un réglage libre : **c'est la
  taille de son croisement** (mesuré sur 145 fiches : d1 → 3,9 directions /
  4,6 quais ; d5 → 6,4 / 9,8). Le nombre de quais plafonne le trafic absorbable
  (`plafondDeFlux`, js/graph.js) ; au-delà, le trafic ajouté n'est plus de la
  difficulté mais de la file d'attente.

### 2.2 Le chapitre (niveau 2)

Le chapitre remplace la **ligne**. C'est l'unité que le joueur nomme, voit
finir, et fête.

- **5 à 10 gares consécutives du ruban**, la dernière étant une **grande
  gare**. Fourchette choisie pour ne rien réécrire : les 26 lignes déjà
  complètes font 5 à 8 gares, médiane 5 (mesuré le 25 août).
- **Un chapitre porte un nom de voyage**, pas un nom de règle : « La Côte
  Est », « Le Rhin », « L'Étoile du Nord ». C'est ce nom qui répond à la
  question « où va-t-on ? », posée pendant le test.
- **Les gares se jouent dans l'ordre du rail.** Jamais dans l'ordre de la
  difficulté (écarté : « un habitué de cette ligne trouverait ça bizarre »).
- **La difficulté monte à l'intérieur du chapitre** vers la grande gare
  finale, puis le chapitre suivant redémarre plus haut que le précédent n'a
  démarré : une dent de scie qui monte (§2.5). Justification diégétique : le
  trafic se densifie à l'approche des métropoles.
- **Aucun choix au bout.** Finir un chapitre ouvre le suivant, point. La fête
  de fin de chapitre est la récompense ; le choix ne l'était pas.
- Un chapitre n'a pas de difficulté propre affichée : sa dureté se lit sur sa
  position dans le ruban.

### 2.2 bis Les grandes gares (ex-hubs)

Les hubs ne sont plus des nœuds de choix — il n'y a plus de choix. Ils
redeviennent ce qu'ils auraient toujours dû être : **les fins de chapitre**.

- Grandes gares connues, beaucoup de voies, plusieurs directions d'approche.
  Elles ferment un chapitre, portent son nom d'arrivée et sa célébration.
- **La règle « ≥ 3 sorties par hub » (ex-R2 bis) est morte.** Elle n'existait
  que pour garantir un choix après chaque victoire. Le travail déjà fait pour
  la satisfaire n'est pas perdu : les lignes ajoutées sont des chapitres
  candidats.
- **Revenir dans une ville se fait par un autre croisement** (R6). Le ruban peut
  repasser par Paris, à condition d'y arriver **par une autre ligne** et d'y
  jouer **une autre gare réelle** : Paris-Nord au chapitre 3, Paris-Gare-de-Lyon
  au chapitre 14, Paris-Montparnasse plus loin. Ce qui est interdit, c'est de
  refaire le même tracé — pas de revoir une ville.
- **Conséquence dure, mesurée le 25 août** : une grande gare qui n'a **qu'une
  fiche** ne se traverse **qu'une fois**. Sur le noyau écrit, seules Londres
  (4 fiches) et Paris (3) échappent à la règle ; les vingt autres n'en ont
  qu'une. C'est ce qui plafonne le ruban de lancement (§5), et c'est la
  première chose qu'écrire une deuxième gare dans une grande ville débloque.
- **Les profils de trafic** (`PROFILS`, js/graph.js : heures creuses → pointe →
  double pointe → bourrasque → service tendu → nocturne) restent disponibles
  pour durcir une arrivée, mais **ils ne rachètent pas un tracé déjà
  parcouru** : rejouer la même ligne « en heure de pointe » reste rejouer la
  même ligne.

### 2.3 La zone (niveau 3)

- Une zone regroupe **6 à 20 chapitres** sur un territoire cohérent — ce sont
  les **actes** du voyage (`ruban-europe.md`). Sur
  l'Europe ce sont les zones existantes (Îles britanniques, France et Benelux,
  Germanie et Alpes…), qui gardent leur couleur sur la carte.
- **Ce n'est pas une porte** — il n'y en a plus nulle part. C'est un **palier
  d'objectifs et de célébration** :
  - *Zone traversée* — tous ses chapitres finis.
  - *Zone d'or / de diamant* — tous ses chapitres au rang correspondant.
  - La zone colore la carte, affiche son pourcentage, porte les fêtes et une
    médaille de famille *Maîtrise* (« Voie royale »).
- Les zones doivent **s'équilibrer** en nombre de chapitres : une zone deux
  fois plus longue à finir qu'une autre se sent.
- Le ruban traverse une zone puis passe à la suivante ; il peut y revenir plus
  tard (retour vers l'ouest en fin de carte), ce n'est pas interdit.

### 2.4 La carte (niveau 4)

- Une carte est un **territoire fermé** — un continent (Europe), un pays, une
  ville, une époque — parcouru par **un ruban unique**.
- **Les cartes n'ont aucun lien entre elles.** Ce sont des missions
  différentes, avec chacune **sa progression propre**. Les étoiles et les
  médailles *de carte* ne se mélangent pas ; seuls les compteurs de compte
  (grade, crédits, §6–7) se cumulent.
- Les **fiches de gares sont une bibliothèque partagée** : une carte y puise
  par référence. Namur peut servir sur une carte « Europe » et sur une carte
  « Belgique » — même plan de voies, progression distincte.
- **Modèle économique** : une seule carte gratuite au départ (l'Europe) ; les
  autres s'achètent par carte bancaire (achat intégré) ou avec des crédits
  accumulés en jouant (§7). Aucune carte n'est jamais requise pour finir une
  autre.
- **Une carte s'allonge par le bout.** C'est le gain de contenu le plus
  important du ruban : ajouter un chapitre, c'est l'écrire et le mettre à la
  suite. Il n'y a plus de graphe à re-satisfaire, plus de sortie à combler,
  plus de hub à supprimer faute de troisième ligne. Le ruban d'Europe peut
  partir à 89 niveaux et grandir indéfiniment vers l'est et le sud.

### 2.5 La courbe de difficulté

Le ruban a **une seule courbe**, croissante, en dents de scie :

- à l'intérieur d'un chapitre, la difficulté monte de son plancher à la
  grande gare finale ;
- d'un chapitre au suivant, le plancher monte d'un cran (pas à chaque
  chapitre : par paliers, sinon la fin de carte est injouable) ;
- la difficulté voulue est toujours **rabattue sur ce que la fiche peut
  porter** (`plafondDeFlux`, inchangé). Une gare de 4 quais ne portera jamais
  une difficulté 5, quelle que soit sa position.

C'est plus simple que la version graphe, où la difficulté était relative au
boss visé et devait valoir dans les deux sens de parcours. Ici il n'y a qu'un
sens.

---

## 3. Règles de construction d'une carte

Ces règles sont **normatives** : `tools/carte-check.mjs` les vérifie et refuse
(code de sortie ≠ 0). Une règle qu'on ne mesure pas est une intention, pas une
règle.

| # | Règle | Pourquoi |
|---|---|---|
| R1 | **La carte est un ruban unique** : une suite ordonnée de gares, sans embranchement, sans choix. Chaque gare a exactement une suivante | C'est toute la décision du 25 août : un seul bouton, *Continuer* |
| R2 | **≥ 60 gares et ≥ 8 chapitres** par carte | En dessous, la mission se finit trop vite pour mériter d'être une carte. Le ruban de lancement de l'Europe en fait 89 sur 16 chapitres (§5) : le plancher est tenu, sans marge |
| R3 | Un chapitre compte **5 à 10 gares**, la dernière étant une grande gare | Moins de 5 : la promesse « parcourir une ligne » n'est pas tenue. Plus de 10 : le joueur ne voit plus l'arrivée |
| R4 | Une zone compte **6 à 20 chapitres** ; une carte a **≥ 2 zones** ; et **l'écart entre la zone la plus courte et la plus longue reste sous 3 pour 1** | Révisée le 25 août 2026 : la fourchette 3–6 avait été écrite pour un ruban de 16 chapitres, elle est cassée par un ruban de 95. C'est l'**écart** qui compte, pas la taille absolue : une région deux fois plus longue qu'une autre se sent |
| R5 | **Continuité réelle** : deux gares consécutives d'un même chapitre sont voisines sur une ligne réelle. Une rupture géographique n'est permise **qu'entre deux chapitres**, et elle est alors déclarée comme un **saut** (§4 bis) | Le tracé doit rester vrai. Un saut assumé est honnête ; un saut caché au milieu d'un chapitre est un bug de crédibilité |
| R6 | **Le ruban ne réemprunte jamais un tracé déjà parcouru.** Une fiche n'apparaît qu'une fois. Revenir dans une ville est permis **à condition d'y revenir par une autre gare — un autre croisement — et par une autre ligne réelle** | Tranché le 25 août 2026 : « pas de souci de revenir à une autre gare si c'est un croisement, mais pas refaire la même ligne ». Le critère n'est pas la distance parcourue depuis, c'est le **tracé** : c'est refaire la même ligne qui se sent, pas revoir une ville |
| R7 | Un chapitre **reste sur la même ligne réelle** (sinuosité ≤ 1,5 × le vol d'oiseau entre sa première et sa dernière gare) | La vérité du tracé avant la longueur : Bruxelles–Luxembourg passe par Namur, pas par le Hainaut |
| R8 | La difficulté portable **croît le long du chapitre**, et la grande gare finale est la plus haute du chapitre. Le plancher des chapitres croît par paliers le long du ruban | La difficulté se déduit de la position mais la géométrie a le dernier mot : une rampe ne tient que si les gares peuvent la porter |
| R9 | **Le premier chapitre est doux** : sa première gare se joue en difficulté 1 et sa grande gare finale ne dépasse pas 3 | Le premier geste du jeu doit être facile |

**Règles supprimées le 25 août, et pourquoi** :

| Ancienne | Sort |
|---|---|
| R1 « ≥ 20 hubs » | supprimée — il n'y a plus de hub au sens de nœud de choix |
| R2 « ≥ 50 lignes » | remplacée par la longueur du ruban (nouvelle R2) |
| R2 bis « ≥ 3 sorties par hub » | **supprimée** — elle n'existait que pour garantir un choix. C'est elle qui coûtait le plus cher en contenu |
| R4 « zones de 7–13 hubs » | remplacée par « 3 à 6 chapitres » |
| R5 « pas de cul-de-sac, graphe connexe » | sans objet : un ruban est connexe par construction |
| R6 « une gare, une ligne » | devient la nouvelle R6, plus précise (écart minimal de 20) |

**Volumes qui en découlent** :

| Élément | Compte |
|---|---|
| Carte minimale (R2) | 8 chapitres × 5–10 gares → **60 à 80 niveaux** |
| Europe au lancement | 16 chapitres → **89 niveaux** (mesuré, §5) |
| Europe, réserve immédiate | 10 chapitres écrits mais hors ruban + 21 lignes à compléter + 94 fiches |
| Europe à terme | le ruban s'allonge par le bout, sans plafond structurel |

---

## 4. Boucle de progression

1. **Ouvrir le jeu** : un bouton, *Continuer*. La prochaine gare pulse sur le
   tracé. Il n'y a jamais rien d'autre à décider.
2. **Jouer la gare** : le service, le relevé de fin, les étoiles.
3. **≥ 1 étoile** → la gare suivante du ruban s'ouvre. **< 1 étoile** → on
   rejoue ; le rejeu est gratuit et immédiat.
4. **La soupape** (§4 ter) : il faut **réussir** la gare. À **chaque** échec,
   le jeu propose de la **payer en crédits** pour passer à la suivante — offre
   toujours disponible, jamais imposée. La gare payée reste sans étoile,
   marquée sur la carte, et se rejoue quand on veut.
5. **Fin de chapitre** (la grande gare est tenue) : célébration, nom du
   chapitre suivant annoncé, rang du chapitre affiché (§6.2).
6. **Fin de zone** : célébration de zone, la carte se colore.
7. **Rejeu volontaire** : toute gare déjà faite se rejoue à tout moment depuis
   la carte, pour améliorer son score. Jamais obligatoire.
8. **Carte terminée** (dernière gare du ruban tenue) : crédits, titre ; le
   joueur choisit une autre carte — ou revient dorer celle-ci.

Il n'y a **aucune porte** : ni entre chapitres, ni entre zones, ni au bout du
ruban. Seul le prix d'une carte (CB ou crédits) conditionne un accès.

### 4 bis Les sauts

Il n'existe **pas de parcours continu qui traverse toute l'Europe** en passant
une seule fois par chaque gare (mesuré au lot 2 : pas de parcours hamiltonien).
Le ruban doit donc, de temps en temps, se déplacer sans rail continu.

- Un **saut** est déclaré dans les données, **entre deux chapitres seulement**
  (R5), jamais à l'intérieur.
- Il est **montré** : une animation de trajet sur la carte, une phrase
  diégétique (« train de nuit pour Marseille », « correspondance à Bâle »),
  passable d'un geste.
- Un saut n'est jamais une punition ni une récompense : c'est une transition.

### 4 ter La soupape — passer une gare se paie (tranché le 25 août 2026)

Le ruban a un défaut que le graphe n'avait pas : **une gare bloquante bloque
tout**. Dans la version graphe, un échec n'arrêtait que le boss et on pouvait
continuer ailleurs.

**Règle** : *il faut réussir la gare.* On ne la contourne pas gratuitement ; on
peut la **payer en crédits** pour passer à la suivante.

1. **Le barème est déjà doux** : 1 étoile = 30 minutes de retard cumulé. La
   philosophie « réussir est facile » n'est pas décorative, c'est ce qui rend
   le ruban praticable. La soupape doit rester rare.
2. **L'offre apparaît à chaque échec, dès le premier**, et ne disparaît
   jamais (tranché le 25 août 2026). **Aucune limite au nombre d'essais** :
   qui veut recommencer dix fois recommence dix fois, gratuitement, et
   retrouve l'offre de passage intacte au onzième. Le jeu ne pousse pas, il
   pose l'option à côté du bouton *Réessayer* et laisse le joueur choisir.
3. **Le passage coûte des crédits** — la monnaie gagnée en jouant (§7). Le prix
   monte avec la position dans le ruban (barème au §7).
4. **Une gare payée reste à 0 étoile.** Elle ne compte ni pour la jauge du
   chapitre, ni pour son rang, ni pour une médaille. Le ruban avance ; la
   récompense, non. C'est la troisième valeur d'un état déjà à deux :
   **faite** (≥ 1 ★) ≠ **payée** (passée, 0 ★) ≠ **à venir**.
5. **La mise est rendue** si le joueur revient gagner la gare plus tard. C'est
   une avance, pas une amende — et ça n'ajoute rien à stocker (§8 : la dépense
   se déduit des gares passées **encore** sans étoile).

**Pourquoi payer plutôt que passer gratuitement.** Un passage gratuit fait de
la linéarité un décor : on traverse le mur et on oublie. Un passage payant
transforme le mur en **raison de retourner en arrière** — le joueur à court de
crédits va rejouer ses vieilles gares pour améliorer leurs étoiles. C'est
exactement le pilier « réussir est facile, exceller est le vrai jeu », branché
sur le seul endroit du ruban où l'on risquait de perdre quelqu'un.

**Le risque à surveiller : le mur du débutant.** Au chapitre 1, le joueur a
cinq étoiles, donc cinq crédits ; s'il se bloque là, il ne peut rien payer.
Trois garde-fous, tous nécessaires :
- R9 (le premier chapitre est doux) porte maintenant une vraie charge ;
- le prix du passage suit la position dans le ruban : il est petit au début
  (§7) ;
- il reste toujours l'issue gratuite du rejeu : la gare se retente autant de
  fois qu'on veut, sans coût, sans attente et **sans plafond**. **Jamais de
  vies, jamais de minuterie** — c'est ce qui distingue la soupape d'un mur
  commercial. Le joueur sans crédits n'est jamais bloqué, il est seulement
  invité à réessayer ou à retourner dorer ce qu'il a déjà fait.

---

### 4 quater Les écrans (tranché par Vincent le 25 août 2026)

L'enchaînement visuel du jeu, du lancement au deuxième niveau. C'est la
spécification du lot E.

1. **L'écran des cartes.** On choisit sa mission. Une seule pour le moment,
   l'Europe — donc l'écran est **sauté tant qu'il n'y a qu'une carte possédée**
   (§7) et n'apparaît qu'au dézoom maximal ou dès qu'une deuxième existe.
2. **La carte, zoomée sur la gare en cours.** Pas la carte d'Europe entière :
   la caméra est **posée sur la prochaine gare**, mise en évidence, avec ses
   **infos de base** — son nom, sa ville, le chapitre en cours et le rang qu'on
   y tient (« gare 3 sur 6 · Le Rhin romantique »), ses quais et ses
   directions. Le tracé du ruban se lit derrière : fait en couleur, à venir en
   gris. Un dézoom montre le chapitre, puis la carte entière.
3. **La première gare est le tutoriel.** Elle est facile par construction (R9)
   et c'est elle qui enseigne l'aiguillage. Le tutoriel n'est pas un écran
   séparé : c'est le premier niveau, guidé.
4. **Le relevé de fin.** À la réussite : le retard cumulé, les étoiles, le
   diamant s'il est gagné, la série — puis deux boutons, **Continuer** et
   **Rejouer**. À l'échec : **Réessayer** (gratuit, illimité) et **Payer le
   passage** (§4 ter), côte à côte, jamais l'un à la place de l'autre.
5. **Le tracé rejoint la gare suivante.** La caméra glisse le long du rail
   jusqu'à la gare d'après, qui devient la nouvelle gare en évidence. C'est
   l'animation qui porte le sentiment d'avancer — et c'est aussi elle qui joue
   les **sauts** (§4 bis), en plus long et avec sa phrase.
6. **La fin de chapitre** s'intercale entre 4 et 5 : rang du chapitre, nom du
   chapitre suivant annoncé.

Il n'y a **aucun autre écran obligatoire**. Tout le reste — l'indicateur, les
médailles, le rejeu volontaire, l'écran des cartes — se rejoint depuis la
carte, jamais en travers du chemin.

## 5. Première carte : l'Europe — le ruban, mesuré le 25 août 2026

**Le tracé complet est dans `ruban-europe.md`** : les 9 actes, les 95
chapitres, les 593 gares dans l'ordre du rail, les 8 sauts. Ce §5 n'en donne
que les comptes ; le document du ruban est l'autorité sur l'itinéraire.

| Mesure | Valeur |
|---|---|
| Le voyage | **de Cork à Istanbul**, une spirale qui traverse chaque région une fois |
| Actes (zones) | 9, de 6 à 18 chapitres — écart 3 pour 1 |
| Chapitres | **95**, de 5 à 9 gares, médiane 6 |
| Gares, c'est-à-dire niveaux | **593** |
| Fiches déjà écrites et réemployées | **123** sur les 234 du catalogue |
| Fiches à écrire | **470** |
| Chapitres jouables **intégralement aujourd'hui** | **12** (68 niveaux), 14 en écrivant deux fiches |
| Sauts déclarés | 8 (deux îles, trois culs-de-sac, trois traversées maritimes) |
| Fiches du catalogue hors ruban | 111 — la réserve d'allongement |

Vérifié par script : R3 (5 à 10 gares) tenue par les 95 chapitres, R6 (aucune
gare deux fois) tenue, chaînage continu d'un bout à l'autre, et les 123 fiches
annoncées comme existantes existent.

**Une grande gare écartée volontairement** : Tirana. L'Albanie n'a plus de
service voyageurs digne d'un niveau et son seul lien crédible est un ferry ;
un jeu ancré dans la géographie ferroviaire réelle ne s'invente pas un réseau.

### 5 bis Ce que contenait la carte avant le ruban

Ce que contient `data/cartes/europe.json` aujourd'hui, lu avec les yeux du
ruban :

| Mesure | Valeur | Lecture |
|---|---|---|
| Lignes complètes **et jouables bout en bout** (5 à 10 gares, toutes les fiches écrites) | **26** sur 128 | ce sont les 26 premiers **chapitres** du ruban, tels quels |
| Gares intermédiaires dessus | 118 | |
| Grandes gares à leurs bouts | 22 | |
| Contenu écrit et jouable, en tout | **140 niveaux** | 118 gares de chapitre + 22 grandes gares |
| **Ruban de lancement extractible sous R6** | **16 chapitres, 89 niveaux** | mesuré le 25 août : c'est la carte de lancement, sans écrire une fiche |
| Chapitres écrits mais **hors ruban** | 10 | ils exigeraient de repasser par une grande gare déjà jouée (R6) : réserve d'extension |
| Lignes à deux bouts jouables mais incomplètes | 21 (10 trop courtes, 11 vides) | la première réserve d'extension |
| Fiches écrites hors du noyau | 94 | la deuxième réserve : de quoi allonger le ruban sans recherche |
| Fiches au catalogue | 234, 7 pays (BE, FR, DE, LU, UK, NL, CH) | bibliothèque partagée, intacte |
| Grandes gares sans fiche | 55 (Rome, Madrid, Vienne, Prague…) | **plus une dette** : le ruban ne les traverse pas encore, c'est tout |

Le noyau s'enchaîne géographiquement : Londres–Manchester d'un côté ;
Paris–Lille–Bruxelles puis Amsterdam / Luxembourg / Cologne ; la traversée
allemande Cologne–Hanovre–Hambourg–Berlin–Leipzig–Nuremberg–Francfort ;
l'axe alpin Strasbourg–Zurich–Genève / Munich–Stuttgart ; et deux morceaux
détachés (Paris–Lyon, Montpellier–Bordeaux) qui arriveront par un **saut**
(§4 bis) ou par un chapitre à écrire.

**Le plafond du noyau, mesuré sous R6** : le plus long ruban qui ne réemprunte
aucun tracé et ne rejoue aucune fiche fait **16 chapitres et 89 niveaux** —
Munich → Stuttgart → Zurich → Strasbourg → Luxembourg → Francfort → Nuremberg →
Leipzig → Berlin → Hambourg → Cologne → Hanovre → Amsterdam → Bruxelles →
Lille → Paris → Lyon (à lire plutôt à l'envers : R9 veut un début doux, et
cette chaîne monte bien de la France vers les Alpes).

Les **dix chapitres restants ne sont pas perdus**, ils sont en réserve : ils
demanderaient de traverser une deuxième fois une grande gare qui n'a qu'une
fiche. Deux façons de les récupérer plus tard, dans cet ordre de préférence :
écrire une **deuxième gare réelle** dans les villes qui en ont une (Hanovre,
Cologne, Zurich, Bruxelles…), ou les rattacher au ruban par un **saut**.

L'ordre exact du ruban, ses sauts et ses noms sont le travail du lot F. Attention
au piège : le plus long n'est pas le meilleur — la chaîne ci-dessus fait un
aller-retour Berlin → Hambourg → Cologne → Hanovre → Amsterdam qui se lit mal
sur une carte. Un ruban un peu plus court mais qui ressemble à un voyage vaut
mieux.

Ce qui est déjà en place et qu'il faut **conserver** : les fiches, la carte à
trois échelles (`js/carte.js`), la couche récompense déduite
(`js/recompense.js`), le modèle multi-cartes et la sauvegarde par carte
(lot A), le plafond de flux et les profils de trafic (`js/graph.js`).

Ce qui **disparaît** : les sorties d'un hub, le choix d'une ligne, l'ouverture
du boss au terme de sa ligne, la difficulté relative à un boss dans les deux
sens, et les règles R1/R2/R2 bis/R4/R5 de la version graphe.

---

## 6. Récompenses

### 6.1 Par gare — inchangé
Étoiles et diamant, §2.1. Les seuils sont par gare.

### 6.2 Rangs de chapitre
Le rang d'un chapitre est le **minimum** de ses gares, grande gare comprise
(jamais la moyenne : une moyenne laisse passer un trou). Quatre crans lus sur
la couleur du tracé : *fait* (toutes ≥ 1 ★) ‹ *argent* (toutes ≥ 2 ★) ‹ *or*
(toutes 3 ★) ‹ *diamant* (toutes sans-faute). Même logique aux échelles
supérieures : zone entièrement dorée = célébration, carte dorée = titre.

C'est exactement l'ancien « rang de ligne », appliqué au chapitre : le code de
`js/recompense.js` change de vocabulaire, pas de calcul.

### 6.3 Grades (compte, toutes cartes confondues) — inchangé
Le grade suit le **total d'étoiles** cumulées sur toutes les cartes. Purement
honorifique (titre, livrée), jamais bloquant. Échelle : Aiguilleur stagiaire 0 ·
Aiguilleur 25 · Chef de quai 75 · Chef de gare 150 · Chef de ligne 300 ·
Régulateur 600 · Inspecteur 1 000 · Directeur régional 1 600 · Directeur de
réseau 2 400 · Légende du rail 3 500.

### 6.4 Médailles (déduites)
Familles : *Accumulation* (paliers d'étoiles, diamants, gares, chapitres),
*Maîtrise* (chapitres d'or, zones complètes, carte terminée), *Exploration*
(sauts franchis, premières zones atteintes, terminus), *Style* (sans pause, du
premier coup, séries, **une zone entière sans jamais payer un passage**). *Régularité* (jours consécutifs) volontairement non
faite. Les seuils sont calés sur le contenu réel et se réécrivent sans
migration, parce que rien n'est stocké.

Les médailles adossées aux hubs maîtrisés disparaissent avec les hubs et sont
remplacées par des médailles de chapitre et de zone.

**Règle structurante, plus vraie que jamais** : presque rien n'est stocké. La
sauvegarde tient `{ étoiles, meilleur retard }` par gare et la série ; tout le
reste — la **position sur le ruban**, les rangs, les médailles, la complétion
de zone, le grade — se **déduit**. Un état déduit est vrai par construction et
se rééquilibre sans migration.

---

## 7. Crédits, passages payés et cartes payantes

- **Rôle des crédits** — ils ont désormais **deux usages** (le second tranché
  le 25 août 2026) :
  1. **acheter une carte** ;
  2. **payer le passage d'une gare** sur laquelle on bloque (§4 ter).
- **Gain** (à caler) : les crédits se **déduisent** de la progression comme
  tout le reste — par exemple 1 crédit par étoile, 5 par diamant, 20 par
  chapitre doré, 100 par zone maîtrisée, 500 par carte terminée.
- **Prix d'un passage** (à caler, §9) : il suit la position dans le ruban, pour
  que le débutant puisse se le payer et que la fin de carte ne s'achète pas —
  par exemple 5 crédits dans la première zone, 15 au milieu, 40 sur une grande
  gare de fin de ruban. Ordre de grandeur voulu : **le prix d'un passage ≈ ce
  que rapportent trois à cinq gares bien jouées**. Assez cher pour qu'on
  préfère réessayer, assez bon marché pour ne jamais enfermer personne.
- **Solde = gagnés − dépensés**, et **rien de plus n'est stocké** :
  - dépense en cartes = Σ prix des cartes acquises en crédits
    (`cartesPossedees`) ;
  - dépense en passages = Σ prix des gares de `passees` **qui sont encore à
    0 étoile** — d'où la restitution de la mise (§4 ter, point 5) : gagner la
    gare plus tard la retire du calcul, sans qu'aucune ligne de sauvegarde
    n'ait bougé.
- Un joueur qui a fini l'Europe doit pouvoir s'offrir une deuxième carte sans
  payer, **même s'il a payé quelques passages en route**. C'est la contrainte
  qui cale les deux barèmes l'un contre l'autre.
- **Achat CB** : achat intégré (App Store / Play). Hors prototype web : le
  prototype ne modélise que l'état *possédée / verrouillée*, un prix en
  crédits, et un déblocage de débogage. Le paiement réel arrive avec le moteur
  final (Unity ou Godot, non tranché).
- **La première carte est gratuite** et complète : pas de démo tronquée.

---

## 8. Modèle de données

```ts
// Une CARTE est un fichier autonome : data/cartes/<id>.json
interface Carte {
  id: string;                 // "europe"
  nom: string;
  gratuite: boolean;
  prixCredits?: number;       // absent si gratuite
  echelle: { kmMinEntreHubs: number };
  zones: Zone[];
  chapitres: Chapitre[];      // DANS L'ORDRE DU RUBAN — c'est la progression
}

interface Zone { id: string; nom: string; couleur: string; }

interface Chapitre {
  id: string;
  nom: string;                // « Le Rhin », « L'Étoile du Nord » — un voyage
  zone: ZoneId;
  gares: FicheId[];           // 5 à 10, dans l'ordre ; la DERNIÈRE est la grande gare
  plancher?: 1|2|3|4|5;       // difficulté de départ ; sinon déduite du rang du chapitre
  saut?: {                    // rupture géographique AVANT ce chapitre (§4 bis)
    mode: "nuit" | "correspondance" | "mer";
    texte: string;            // « train de nuit pour Marseille »
  };
}

// Les fiches de gares (data/stations/<pays>/<id>.json) sont une BIBLIOTHÈQUE
// partagée entre cartes : géométrie, seuils, description. Leur `difficulty`
// est descriptif (taille du croisement) ; l'enveloppe réellement jouée vient
// de la position dans le chapitre, rabattue par plafondDeFlux.

interface EtatJoueur {
  cartes: {                   // une progression PAR carte, indépendantes
    [carteId: string]: {
      resultats: { [ficheId: string]: { etoiles: 0|1|2|3; meilleurRetard: number } };
      passees?: FicheId[];    // gares PAYÉES en crédits pour passer (§4 ter).
                              // Seul fait nouveau du schéma 7. La dépense s'en
                              // déduit : Σ prix des passees ENCORE à 0 étoile,
                              // d'où la restitution de la mise sans rien stocker.
      serie: { n: number; record: number };
    }
  };
  cartesPossedees: { [carteId: string]: "gratuite" | "credits" | "achat" };
  carteCourante: CarteId;
}
// La POSITION sur le ruban n'est pas stockée : c'est la première gare du ruban
// qui n'est ni faite (≥ 1 ★) ni payée. Un état déduit ne peut pas désynchroniser.
// Le SOLDE de crédits n'est pas stocké non plus : gagnés (déduits des étoiles,
// diamants, chapitres, zones) − prix des cartes achetées en crédits − prix des
// gares passées encore à 0 ★.
// Disparaissent du schéma 6 : `acquises` (l'ordre était la progression) et
// `versionsJouees` (le ruban dit lui-même quelle version se joue quand).
```

**Migration schéma 6 → 7** : `resultats` et `serie` sont repris tels quels ;
`acquises` et `versionsJouees` sont abandonnés ; `passees` naît vide. Aucune
étoile n'est perdue — un joueur du graphe retrouve toutes ses gares faites, et
sa position sur le ruban se recalcule seule. Un joueur qui avait pris une autre
branche que le ruban garde ses étoiles sur des gares hors ruban : elles restent
au catalogue et comptent pour le grade.

---

## 9. Questions ouvertes

1. ~~Structure~~ Tranché le 25 août 2026 : **ruban unique**, sans
   embranchement, sans choix. Fourches éventuelles remises à plus tard (§0).
2. ~~L'ordre du ruban d'Europe~~ **Tranché le 25 août 2026** : le tracé
   complet est écrit dans `ruban-europe.md` — 95 chapitres, 593 gares, 8 sauts,
   de Cork à Istanbul. Restent ouvertes, à l'intérieur : la validation gare par
   gare contre le §0 de `AUTHORING-STATIONS.md`, et les collisions
   d'identifiants (`valence` française vs espagnole).
3. **Le pas de la courbe** : tous les combien de chapitres le plancher de
   difficulté monte-t-il d'un cran ? À mesurer en headless sur le ruban réel.
4. **Les trois barèmes de crédits** (§7), à caler **ensemble** parce qu'ils se
   contraignent : ce qu'une gare rapporte, ce qu'un **passage** coûte, ce
   qu'une carte vaut. Contrainte tenante : finir l'Europe doit payer la
   deuxième carte, même après quelques passages achetés.
5. **Les deuxièmes gares des grandes villes** : écrire Hanovre, Cologne,
   Zurich ou Bruxelles une seconde fois (autre gare réelle) rouvre plusieurs
   des dix chapitres mis en réserve par R6 (§5). Lesquelles, et dans quel
   ordre ?
6. **Deuxième carte** pour prouver que le modèle est générique : un pays
   (échelle resserrée) ou un autre continent ? Le ruban rend l'exercice
   beaucoup moins cher qu'avec le graphe — 60 gares suffisent.
7. **Départ localisé** : commencer le ruban près du joueur ? Contradictoire
   avec un ruban unique ; probablement à écarter.
8. **Habillage des noms** : marques déposées (TGV, Eurostar, Thalys,
   Orient-Express) — préférer les noms historiques (L'Étoile du Nord, Le
   Rheingold, L'Oiseau Bleu, l'Express d'Orient) ou des noms maison. Devient
   plus important : chaque chapitre porte un nom (§2.2).
9. **Chapitres légendaires** (fin de ruban) : les dix dernières gares d'une
   carte, difficulté haute de bout en bout. Conservé comme intention.
