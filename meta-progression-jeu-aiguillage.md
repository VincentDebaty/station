# Jeu d'aiguillage — Conception de la méta-progression

> Document de référence. Première version le 20 août 2026 (le graphe européen,
> les boss, les lignes, les récompenses) ; **révisé le 21 août 2026** pour poser
> la structure définitive en quatre niveaux et la notion de CARTE.
> Le gameplay d'un niveau (aiguiller les trains d'une gare vers la bonne
> destination) est acquis, testé et approuvé : il n'est pas couvert ici.
> Le plan de réalisation est dans `plan-de-dev.md`.

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
| **2. La ligne** | 4 à 9 gares entre deux hubs, jouées dans l'ordre du rail | Atteindre et battre le hub au bout de la ligne, ou — s'il est déjà battu — ouvrir une nouvelle ligne depuis ce hub | Implémentée sur l'Europe, corridors trop courts (voir §5) |
| **3. La zone** | Une dizaine de hubs reliés par des lignes | Ouvrir tous les hubs de la zone ; la dorer entièrement | Existe comme « constellation » (calque), pas encore comme palier d'objectifs |
| **4. La carte** | Un territoire (continent, pays, ville) : ≥ 20 hubs répartis en zones | Conquérir tout le réseau | Une seule carte (Europe), codée en dur ; pas de notion de carte dans le code |

Les trois premiers niveaux décrivent *comment on avance* ; le quatrième
décrit *où l'on joue*. Les cartes sont des **missions indépendantes** (§2.4).

---

## 2. Les quatre niveaux

### 2.1 La gare (niveau 1)

- Une gare = un niveau = un service d'une journée à aiguiller. Acquis.
- Condition de réussite : **ne pas cumuler plus de 30 minutes de retard**.
  Barème : 3 ★ < 10 min · 2 ★ < 20 · 1 ★ < 30 · sans-faute = 3 ★ **+ 1 diamant**
  (le diamant s'empile, il ne remplace jamais : mieux jouer ne rapporte jamais
  moins). Seuils configurables par gare, défaut 30/20/10.
- Plancher de jouabilité : **au moins 3 directions et 3-4 quais**. Une gare de
  passage sur une seule ligne (2 directions) n'est pas un niveau — mesuré :
  trop creux à jouer. C'est un croisement d'au moins deux lignes réelles.
- La difficulté d'une gare n'est pas un réglage libre : **c'est la taille de
  son croisement** (mesuré sur 145 fiches : d1 → 3,9 directions / 4,6 quais ;
  d5 → 6,4 / 9,8). Le nombre de quais plafonne le trafic absorbable
  (`plafondDeFlux`, js/graph.js) ; au-delà, le trafic ajouté n'est plus de la
  difficulté mais de la file d'attente.

### 2.2 La ligne (niveau 2)

- Une ligne relie **deux hubs** et compte **4 à 9 gares intermédiaires**.
  Jouée depuis un hub tenu vers le hub d'en face, elle fait donc **5 à 10
  niveaux, hub d'arrivée compris** (le hub de départ est déjà battu, il ne
  compte pas).
- **Objectif clair et unique** : le hub au bout. Soit il n'est pas encore battu
  et la ligne le débloque ; soit il l'est déjà et la victoire (dans une
  nouvelle version de trafic, §2.2 bis) débloque **une ligne supplémentaire
  depuis ce hub**. Dans les deux cas, finir une ligne ouvre un choix.
- Les gares se jouent **dans l'ordre du rail**, jamais dans l'ordre de la
  difficulté (écarté : « un habitué de cette ligne trouverait ça bizarre »). La
  ligne se lit toujours depuis son origine réelle (`de` → `vers`), quel que
  soit le bout que le joueur tient.
- **La difficulté est une fonction de la position** : rampe depuis deux crans
  sous le boss jusqu'au boss, rabattue sur ce que chaque gare peut porter. La
  même donnée sert les deux sens, puisqu'on la calcule par rapport au hub
  d'arrivée. Justification diégétique : le trafic se densifie à l'approche des
  métropoles. Courbe en dents de scie bienvenue (pic intermédiaire sur une
  grosse gare réelle à mi-ligne, ex. Dijon sur Paris–Lyon).
- **Le boss s'atteint au terme de sa ligne**, jamais en se tenant à côté : il
  ne s'ouvre qu'une fois toutes les gares de la ligne **faites** (≥ 1 étoile),
  pas seulement acquises. L'échec ne bloque que le boss : on peut continuer sa
  route et repasser prendre son étoile.
- **Traversée gratuite** : une gare déjà faite sur une autre ligne ne se rejoue
  pas quand une nouvelle ligne la traverse (mais la règle d'auteur « une gare,
  une ligne » rend le cas rare).
- **Une gare de ligne = un seul niveau** ; seuls les hubs ont des versions.
- Les lignes ne portent pas de difficulté propre : la difficulté globale monte
  par trois canaux — versions de hub plus dures, lignes tardives qui démarrent
  moins bas, lignes plus longues (5 niveaux pour une secondaire, 10 pour un
  grand corridor).

### 2.2 bis Les hubs (les nœuds)

- Grandes gares connues, beaucoup de voies, plusieurs directions d'approche.
- Chaque hub a **N sorties** (lignes), **N ≥ 3** (voir §3). Deux rangs : hub
  **continental** (4 à 6 sorties, carrefour et réserve d'extension) et hub
  **régional** (3 sorties, ferme une branche).
- Un hub existe en **autant de versions de trafic que de sorties**, de
  difficulté croissante (heures creuses → pointe → double pointe → bourrasque →
  service tendu → nocturne — `PROFILS`, js/graph.js). Revenir à un hub connu
  par une nouvelle ligne le rejoue dans la version suivante : c'est **la seule
  répétition du jeu**, espacée d'une ligne complète par construction. Quand le
  hub a plusieurs gares réelles (Londres, Paris), ses versions sont ses
  terminus — déjà écrits comme fiches distinctes.
- **Hub maîtrisé** = toutes ses sorties parcourues jusqu'au bout : récompense
  majeure, statut doré sur la carte.
- Équilibre garanti : chaque victoire de hub ouvre exactement une ligne, donc
  nombre de lignes = nombre de victoires nécessaires, quel que soit l'ordre
  choisi.

### 2.3 La zone (niveau 3)

- Une zone regroupe **environ dix hubs** (fourchette 7–13) reliés entre eux par
  des lignes. Sur l'Europe ce sont les « constellations » (Îles britanniques,
  France et Benelux, Germanie et Alpes…).
- **Ce n'est pas une porte.** On n'entre pas dans une zone par un portillon, on
  y arrive par une ligne — via un **hub-porte** partagé ou frontalier (Lille,
  Cologne, Milan, Vienne, Copenhague…). Le joueur peut mordre sur une zone
  voisine avant d'avoir fini la sienne.
- **C'est un palier d'objectifs et de célébration** :
  - *Zone ouverte* — tous ses hubs battus au moins une fois.
  - *Zone maîtrisée* — tous ses hubs maîtrisés (toutes les lignes internes
    parcourues).
  - *Zone d'or / de diamant* — toutes ses lignes au rang correspondant.
  - La zone colore la carte, affiche son pourcentage de complétion, porte les
    fêtes et une médaille de famille *Maîtrise* (« Voie royale »).
- Les zones doivent **s'équilibrer** en taille : une zone deux fois plus longue
  à finir qu'une autre se sent (mesuré sur l'Europe ; écart ramené à 1,86 pour 1
  en comblant les vides plutôt qu'en rognant).

### 2.4 La carte (niveau 4)

- Une carte est un **territoire fermé** — un continent (Europe), un pays, une
  ville, une époque — contenant **au moins 20 hubs** répartis en **plusieurs
  zones**, reliés par des lignes. Le réseau qu'on y dessine est libre : ce qui
  compte, c'est qu'il respecte les règles du §3.
- **Les cartes n'ont aucun lien entre elles.** Ce sont des missions
  différentes, avec chacune **sa progression propre** : on peut avoir doré
  l'Europe et n'avoir rien ouvert sur la carte suivante. Les étoiles et les
  médailles *de carte* ne se mélangent pas ; seuls les compteurs de compte
  (grade, crédits, §6–7) se cumulent.
- Les **fiches de gares sont une bibliothèque partagée** : une carte y puise par
  référence. Namur peut servir sur une carte « Europe » et sur une carte
  « Belgique » — c'est le même plan de voies, mais une progression distincte.
- **Modèle économique** : une seule carte gratuite au départ (l'Europe) ; les
  autres s'achètent **par carte bancaire (achat intégré) ou avec des crédits
  accumulés en jouant** (§7). Aucune carte n'est jamais requise pour finir une
  autre.
- On peut créer **autant de cartes qu'on veut** ; c'est le levier de contenu
  du jeu. Chaque carte a son échelle : sur l'Europe, deux hubs sont à 250–400 km
  l'un de l'autre (il faut 4 à 9 gares entre eux) ; sur une carte « pays » ou
  « ville », la même structure se replie sur des distances plus courtes. Les
  règles du §3 sont les mêmes, les kilomètres non.

---

## 3. Règles de construction d'une carte

Ces règles sont **normatives** : un outil de contrôle (`tools/carte-check.mjs`,
à écrire — voir le plan) les vérifie avant toute livraison.

| # | Règle | Pourquoi |
|---|---|---|
| R1 | **≥ 20 hubs** par carte | En dessous, la carte n'offre pas assez de choix de direction pour tenir la boucle « battre un hub → choisir une ligne » sur la durée |
| R2 | **≥ 50 lignes** par carte, quoi qu'il arrive — c'est un plancher absolu, indépendant du nombre de hubs | Une carte est une mission longue : en dessous de 50 lignes elle se finit trop vite pour mériter d'être une carte |
| R2 bis | **Chaque hub a ≥ 3 sorties.** Un hub qui ne peut pas en avoir trois (géographie, lignes réelles) **est supprimé** de la carte, jamais gardé comme cul-de-sac | Chaque hub doit offrir un choix après sa première victoire ; un hub à 1 ou 2 sorties est un couloir |
| R3 | Une ligne compte **4 à 9 gares intermédiaires** → **5 à 10 niveaux** hub d'arrivée compris | Moins de 4 : le hub est à portée de main, la promesse « parcourir une ligne » n'est pas tenue. Plus de 9 : le joueur ne voit plus l'objectif |
| R4 | Une zone compte **7 à 13 hubs** (cible ~10) et une carte a **≥ 2 zones** | Équilibre de durée entre zones ; une carte à une seule zone n'a pas de niveau 3 |
| R5 | **Pas de cul-de-sac** : chaque gare intermédiaire est sur une ligne, le graphe est connexe | Rien ne doit être injouable ou sans lendemain |
| R6 | **Une gare intermédiaire appartient à une seule ligne** | Une gare dans deux lignes s'ouvrirait deux fois ; la couverture prime sur l'optimalité de chaque ligne |
| R7 | Une ligne **reste sur la même ligne réelle** (sinuosité ≤ 1,5 × le vol d'oiseau) | La vérité du tracé avant la longueur : Bruxelles–Luxembourg passe par Namur, pas par le Hainaut |
| R8 | Les gares intermédiaires **grossissent vers le hub** | La difficulté se déduit de la position mais la géométrie a le dernier mot : une rampe ne tient que si les gares peuvent la porter |
| R9 | Une **ligne de départ** par zone d'entrée au moins, à rampe douce ; la gare d'amorce se joue en niveau 1 quelle que soit sa fiche | Le premier geste du jeu doit être facile et offrir un choix de pays |

**Sur R1 et R2 (tranché le 21 août 2026).** Les deux planchers sont
indépendants : **20 hubs minimum ET 50 lignes minimum**. Une ligne est un
tracé entre deux hubs, compté une fois (pas un par sens). Avec 20 hubs,
50 lignes font 5 sorties par hub en moyenne — une carte minimale est donc
**dense** ; avec plus de hubs, la densité redescend vers les 3 sorties
réglementaires (l'Europe : 131 lignes pour 85 hubs, 3,1 par hub).

**Volumes qui en découlent** pour la carte minimale (20 hubs, 50 lignes) :

| Élément | Compte |
|---|---|
| Gares intermédiaires (50 lignes × 4 à 9) | 200 à 450, médiane ~325 |
| Versions de hub (20 hubs × ≥ 3, en pratique ≈ 5) | 60 à 100 |
| **Niveaux** | **≈ 260 à 550** |

Pour l'Europe entière (85 hubs, 131 tracés) : 525 à 1 180 gares
intermédiaires + ~260 versions de hub → **800 à 1 400 niveaux**.

---

## 4. Boucle de progression

1. **Choix d'une ligne de départ** (on ne choisit pas une gare, on choisit une
   direction) : sa première gare se joue en niveau 1, puis la ligne se
   parcourt gare après gare jusqu'au premier hub.
2. Victoire sur le hub → **choix d'une ligne** parmi ses sorties verrouillées.
3. Le joueur parcourt la ligne choisie et arrive au hub suivant → nouvelle
   victoire, nouveau choix.
4. **Retour à un hub déjà connu** par une nouvelle ligne : il se rejoue dans
   sa version de trafic suivante ; la victoire ouvre une ligne de plus.
5. **Hub maîtrisé** (toutes ses sorties parcourues) : récompense majeure.
6. **Zone ouverte / maîtrisée** : célébration de zone, la carte se colore.
7. **Voyage libre** : les lignes terminées ne se rejouent jamais
   obligatoirement — on les *parcourt* (fast travel animé, skippable). Le
   rejeu volontaire de toute gare reste possible pour améliorer son score.
8. **Carte terminée** (tous les hubs maîtrisés) : crédits, titre ; le joueur
   choisit une autre carte — ou continue de dorer celle-ci.

Il n'y a **pas de porte entre zones** ni entre cartes : seul le prix d'une
carte (CB ou crédits) en conditionne l'accès.

---

## 5. Première carte : l'Europe — état mesuré le 21 août 2026

Ce que contient `data/graph.js` aujourd'hui, face aux règles du §3 :

| Règle | Mesure | Verdict |
|---|---|---|
| R1 ≥ 20 hubs | **85 hubs**, 27 jouables (fiche écrite), 58 à écrire | ✔ |
| R2 ≥ 50 lignes | **131 lignes** | ✔ |
| R2 bis ≥ 3 sorties / hub | 3,1 par hub en moyenne mais **31 hubs sous 3** (dont 7 à une seule sortie : Aberdeen, Cork, Porto, Palerme, Bergen, Athènes, Tirana) | ✘ à corriger : **ajouter des lignes, sinon supprimer le hub** (tranché) |
| R3 4–9 gares par ligne | **21 corridors écrits** sur 131 ; longueurs 1 → 8, 2 → 6, 3 → 3, 4 → 1, 5 → 2, 7 → 1 : **4 conformes** | ✘ le gros du travail de contenu |
| R4 zones de 7–13 hubs | 9 zones : 7 (Est), 9 ×6, 11 (Germanie), 13 (France-Benelux) | ✔ |
| R5 connexité | connexe, 41 tracés ont leurs deux bouts jouables | ✔ (sur la partie écrite) |
| Catalogue | **145 fiches** de gares, 5 pays (BE, FR, DE, LU, UK) | — |

**Bloc de lancement (tranché le 21 août 2026)** : les zones **France et
Benelux + Germanie et Alpes** — 24 hubs (21 déjà jouables ; Amsterdam, Zurich
et Genève à écrire), 39 lignes internes, 40 gares intermédiaires déjà écrites
sur ces lignes, **~215 fiches à écrire** pour porter toutes les lignes à 4–9
gares. Le reste de l'Europe s'affiche grisé (« à venir ») et se greffe
ensuite, zone par zone, sur les hubs-portes.

Deux points d'attention sur ce bloc :

- **R2 bis à l'intérieur du bloc** : huit hubs y ont moins de 3 sorties
  internes — Dijon, Nantes, Toulouse, Genève, Leipzig (2 en tout), et Lille,
  Marseille, Montpellier (2 internes, la 3e sort du bloc vers une zone
  grisée). Pour les cinq premiers : ajouter une ligne réelle (Nantes–Rennes,
  Toulouse–Narbonne, Dijon–Belfort–Mulhouse, Genève–Simplon, Leipzig–Dresde…)
  ou supprimer le hub. Pour les trois autres : la ligne sortante compte dès
  que la zone voisine est livrée ; en attendant, leur donner une 3e ligne
  interne ou accepter une sortie « à venir » le temps du lancement.
- **R2 (≥ 50 lignes)** : le bloc en a 39. Le plancher porte sur la carte
  Europe entière (131), pas sur son premier bloc livré ; mais si le bloc
  doit valoir carte complète à lui seul, il faut y adjoindre les Îles
  britanniques (33 hubs, 53 lignes, ~300 fiches de plus). **À trancher.**

Ce qui est déjà en place dans le code et qu'il faut **conserver** : le graphe
vu du jeu (js/graph.js : sorties, parcours, difficulté par position, versions
de hub, lignes de départ, ouverture du boss au bout de la ligne), la carte à
trois échelles (js/carte.js : ligne / constellation / Europe), la couche
récompense déduite (js/recompense.js).

Ce qui **manque** : la notion de carte (tout est l'Europe en dur, la
progression n'est pas rattachée à une carte), la zone comme palier
d'objectifs, l'écran des cartes et leur achat, les crédits.

---

## 6. Récompenses

### 6.1 Par gare
Étoiles et diamant, §2.1. Les seuils sont par gare.

### 6.2 Rangs de ligne (implémentés)
Le rang d'une ligne est le **minimum** de ses gares — intermédiaires **plus
les deux hubs** (jamais la moyenne, sinon le rang dépendrait du sens de
lecture). Quatre crans lus sur la couleur du tracé : *ouverte* (toutes
faites) ‹ *argent* (toutes ≥ 2 ★) ‹ *or* (toutes 3 ★) ‹ *diamant* (toutes
sans-faute). Même logique aux échelles supérieures : hub maîtrisé doré, zone
entièrement dorée = célébration, carte dorée = titre.

### 6.3 Grades (compte, toutes cartes confondues)
Le grade suit le **total d'étoiles** cumulées sur toutes les cartes. Purement
honorifique (titre, livrée), jamais bloquant. Échelle : Aiguilleur stagiaire 0 ·
Aiguilleur 25 · Chef de quai 75 · Chef de gare 150 · Chef de ligne 300 ·
Régulateur 600 · Inspecteur 1 000 · Directeur régional 1 600 · Directeur de
réseau 2 400 · Légende du rail 3 500.

### 6.4 Médailles (implémentées, déduites)
Familles : *Accumulation* (paliers d'étoiles, diamants, gares, lignes),
*Maîtrise* (lignes d'or, hubs maîtrisés, zones complètes), *Exploration*
(terminus, hubs-portes), *Style* (sans pause, du premier coup, séries).
*Régularité* (jours consécutifs) volontairement non faite. Les seuils sont
calés sur le contenu réel et se réécrivent sans migration, parce que rien
n'est stocké.

**Règle structurante** : presque rien n'est stocké. La sauvegarde tient
`{ étoiles, meilleur retard }` par gare et la série ; tout le reste (rangs,
médailles, maîtrises, complétion de zone, grade) se **déduit**. Un état déduit
est vrai par construction et se rééquilibre sans migration.

---

## 7. Crédits et cartes payantes

- **Rôle des crédits** : acheter des cartes. C'est leur seul usage au
  lancement (les boosters et collections du premier document restent
  reportés).
- **Gain** (proposition, à trancher) : les crédits se **déduisent** de la
  progression comme tout le reste — par exemple 1 crédit par étoile, 5 par
  diamant, 20 par hub maîtrisé, 100 par zone maîtrisée, 500 par carte
  terminée. Les crédits *dépensés* sont la somme des prix des cartes achetées
  en crédits. Solde = gagnés − dépensés : **on ne stocke que la liste des
  cartes possédées et leur mode d'acquisition**. Un joueur qui a fini
  l'Europe doit pouvoir s'offrir une deuxième carte sans payer.
- **Achat CB** : achat intégré (App Store / Play). Hors prototype web : le
  prototype ne fait que modéliser l'état *possédée / verrouillée* et un prix en
  crédits, avec un déblocage de débogage. Le paiement réel arrive avec le
  moteur final (Unity ou Godot, non tranché).
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
  echelle: { kmMinEntreHubs: number };   // 110 sur l'Europe
  zones: Zone[];
  hubs: Hub[];
  lignes: Ligne[];
}
interface Zone { id: string; nom: string; couleur: string; }
interface Hub {
  id: string; nom: string; zone: ZoneId; ll: [number, number];
  rang: 1 | 2;                // continental / régional
  gare: FicheId;              // la fiche de la bibliothèque partagée
  versions?: { vers: HubId; gare: FicheId; nom: string }[];  // sinon PROFILS
}
interface Ligne {
  id: string; de: HubId; vers: HubId;   // sens de lecture = le réel
  type?: "rail" | "mer";
  gares: FicheId[];           // 4 à 9, dans l'ordre de `de` vers `vers`
  legendaire?: boolean;
}
// Les fiches de gares (data/stations/<pays>/<id>.json) sont une BIBLIOTHÈQUE
// partagée entre cartes : géométrie, seuils, description. Leur `difficulty`
// est descriptif (taille) ; l'enveloppe jouée vient de la position sur la ligne.

interface EtatJoueur {
  cartes: {                   // une progression PAR carte, indépendantes
    [carteId: string]: {
      resultats: { [ficheId: string]: { etoiles: 0|1|2|3; meilleurRetard: number } };
      acquises: FicheId[];    // l'ordre compte : la première est la gare d'amorce
      versionsJouees: { [hubId: string]: number };
      serie: { n: number; record: number };
    }
  };
  cartesPossedees: { [carteId: string]: "gratuite" | "credits" | "achat" };
  carteCourante: CarteId;
}
// Tout le reste — grade, crédits, rangs, médailles, zones, maîtrises — est dérivé.
```

---

## 9. Questions ouvertes

1. ~~R2~~ Tranché : 20 hubs minimum **et** 50 lignes minimum.
2. ~~Hubs à 1–2 sorties~~ Tranché : ajouter des lignes, sinon supprimer le
   hub. Reste à faire, hub par hub (31 sur l'Europe, 8 dans le bloc de
   lancement — §5).
3. ~~Bloc de lancement~~ Tranché : France-Benelux + Germanie. Reste à dire si
   le bloc livré doit atteindre 50 lignes à lui seul (§5).
4. **Barème des crédits** et **prix des cartes** (§7).
5. **Deuxième carte** pour prouver que le modèle est générique : un pays
   (échelle resserrée) ou un autre continent ? Hors Europe, le catalogue est
   vide : c'est surtout un coût de contenu.
6. **Départ localisé** : proposer la ligne de départ selon le pays du joueur.
7. **Habillage des noms** : marques déposées (TGV, Eurostar, Thalys,
   Orient-Express) — préférer les noms historiques (L'Étoile du Nord, Le
   Rheingold, L'Oiseau Bleu, l'Express d'Orient) ou des noms maison.
8. **Lignes légendaires** (fin de jeu) : grandes transversales de 10 niveaux,
   difficulté élevée de bout en bout, déblocables après maîtrise de leurs hubs
   d'ancrage. Conservées comme intention, non planifiées.
