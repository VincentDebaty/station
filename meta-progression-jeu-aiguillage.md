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
- **Les versions de trafic sont conservées, et deviennent un outil d'auteur.**
  Quand le ruban repasse par une ville déjà jouée, il la joue **dans une autre
  de ses gares réelles** (Paris-Nord au chapitre 3, Paris-Gare-de-Lyon au
  chapitre 14) ou, à défaut, dans le profil de trafic suivant (`PROFILS`,
  js/graph.js : heures creuses → pointe → double pointe → bourrasque → service
  tendu → nocturne). C'est de la répétition espacée, exactement comme
  Duolingo : une force, pas une redite. La différence avec la version graphe :
  **l'auteur décide quand ça arrive**, ce n'est plus un effet de bord du
  parcours choisi par le joueur.

### 2.3 La zone (niveau 3)

- Une zone regroupe **3 à 6 chapitres** sur un territoire cohérent. Sur
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
  partir à 140 niveaux et grandir indéfiniment vers l'est et le sud.

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
| R2 | **≥ 60 gares et ≥ 8 chapitres** par carte | En dessous, la mission se finit trop vite pour mériter d'être une carte. Cible de lancement sur l'Europe : ~140 |
| R3 | Un chapitre compte **5 à 10 gares**, la dernière étant une grande gare | Moins de 5 : la promesse « parcourir une ligne » n'est pas tenue. Plus de 10 : le joueur ne voit plus l'arrivée |
| R4 | Une zone compte **3 à 6 chapitres** ; une carte a **≥ 2 zones** | Équilibre de durée entre zones ; une carte à une seule zone n'a pas de niveau 3 |
| R5 | **Continuité réelle** : deux gares consécutives d'un même chapitre sont voisines sur une ligne réelle. Une rupture géographique n'est permise **qu'entre deux chapitres**, et elle est alors déclarée comme un **saut** (§4 bis) | Le tracé doit rester vrai. Un saut assumé est honnête ; un saut caché au milieu d'un chapitre est un bug de crédibilité |
| R6 | **Une fiche n'apparaît qu'une fois** dans le ruban. Une ville peut revenir, mais par une **autre gare réelle** ou une **version de trafic** supérieure, et **jamais avant 20 gares d'écart** | La répétition est un outil (§2.2 bis), pas un remplissage. L'écart minimal fait la différence entre « rappel » et « redite » |
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
| Europe au lancement | ~24 chapitres → **~140 niveaux** (le noyau déjà écrit) |
| Europe à terme | le ruban s'allonge par le bout, sans plafond structurel |

---

## 4. Boucle de progression

1. **Ouvrir le jeu** : un bouton, *Continuer*. La prochaine gare pulse sur le
   tracé. Il n'y a jamais rien d'autre à décider.
2. **Jouer la gare** : le service, le relevé de fin, les étoiles.
3. **≥ 1 étoile** → la gare suivante du ruban s'ouvre. **< 1 étoile** → on
   rejoue ; le rejeu est gratuit et immédiat.
4. **La soupape** (§4 ter) : après trois échecs sur la même gare, le jeu
   propose de **passer** la gare à 0 étoile. Le ruban continue ; la gare
   passée reste marquée et se rejoue quand on veut.
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

### 4 ter La soupape

Le ruban a un défaut que le graphe n'avait pas : **une gare bloquante bloque
tout**. Dans la version graphe, un échec n'arrêtait que le boss et on pouvait
continuer ailleurs.

La parade tient en deux points, tous les deux nécessaires :

1. **Le barème est déjà doux** : 1 étoile = 30 minutes de retard cumulé. La
   philosophie « réussir est facile » n'est pas décorative, c'est ce qui rend
   le ruban praticable.
2. **Passer après trois échecs** : le jeu le propose de lui-même, sans le
   présenter comme un abandon. Candy Crush et Duolingo ont tous les deux une
   soupape ; un jeu linéaire sans soupape perd le joueur au premier mur.

---

## 5. Première carte : l'Europe — état mesuré le 25 août 2026

Ce que contient `data/cartes/europe.json` aujourd'hui, lu avec les yeux du
ruban :

| Mesure | Valeur | Lecture |
|---|---|---|
| Lignes complètes **et jouables bout en bout** (5 à 10 gares, toutes les fiches écrites) | **26** sur 128 | ce sont les 26 premiers **chapitres** du ruban, tels quels |
| Gares intermédiaires dessus | 118 | |
| Grandes gares à leurs bouts | 22 | |
| **Noyau jouable immédiatement** | **140 niveaux** | c'est la carte de lancement, sans écrire une fiche |
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

Le plus long enchaînement **sans jamais repasser par une grande gare** fait
89 niveaux et 17 grandes gares. Passer les 140 niveaux du noyau demande donc
de repasser par certaines villes — ce qui est précisément l'usage prévu des
versions de gare (§2.2 bis, R6). L'ordre exact du ruban est le travail du
lot F.

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
premier coup, séries). *Régularité* (jours consécutifs) volontairement non
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

## 7. Crédits et cartes payantes — inchangé

- **Rôle des crédits** : acheter des cartes. C'est leur seul usage au
  lancement.
- **Gain** (à caler) : les crédits se **déduisent** de la progression comme
  tout le reste — par exemple 1 crédit par étoile, 5 par diamant, 20 par
  chapitre doré, 100 par zone maîtrisée, 500 par carte terminée. Solde =
  gagnés − dépensés : **on ne stocke que la liste des cartes possédées et leur
  mode d'acquisition**. Un joueur qui a fini l'Europe doit pouvoir s'offrir
  une deuxième carte sans payer.
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
      passees?: FicheId[];    // gares franchies par la soupape (§4 ter)
      serie: { n: number; record: number };
    }
  };
  cartesPossedees: { [carteId: string]: "gratuite" | "credits" | "achat" };
  carteCourante: CarteId;
}
// La POSITION sur le ruban n'est pas stockée : c'est la première gare du ruban
// qui n'est ni faite (≥ 1 ★) ni passée. Un état déduit ne peut pas désynchroniser.
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
2. **L'ordre du ruban d'Europe** : quel enchaînement des 26 chapitres du
   noyau, combien de sauts, où placer Paris–Lyon et Montpellier–Bordeaux
   (lot F).
3. **Le pas de la courbe** : tous les combien de chapitres le plancher de
   difficulté monte-t-il d'un cran ? À mesurer en headless sur le ruban réel.
4. **Barème des crédits** et **prix des cartes** (§7).
5. **Deuxième carte** pour prouver que le modèle est générique : un pays
   (échelle resserrée) ou un autre continent ? Le ruban rend l'exercice
   beaucoup moins cher qu'avec le graphe — 60 gares suffisent.
6. **Départ localisé** : commencer le ruban près du joueur ? Contradictoire
   avec un ruban unique ; probablement à écarter.
7. **Habillage des noms** : marques déposées (TGV, Eurostar, Thalys,
   Orient-Express) — préférer les noms historiques (L'Étoile du Nord, Le
   Rheingold, L'Oiseau Bleu, l'Express d'Orient) ou des noms maison. Devient
   plus important : chaque chapitre porte un nom (§2.2).
8. **Chapitres légendaires** (fin de ruban) : les dix dernières gares d'une
   carte, difficulté haute de bout en bout. Conservé comme intention.
