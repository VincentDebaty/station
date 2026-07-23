# Créer une nouvelle gare (procédure)

Procédure suivie pour rendre les gares fidèles au réseau réel tout en gardant
le jeu jouable. Éprouvée sur la Belgique (13 gares) et la France (10 gares) —
juillet 2026. À rejouer pour chaque nouveau pays.

## 0. Principe directeur : politique HYBRIDE

On garde l'**échelle de difficulté** et sa progression pédagogique (d1 petit →
d5 gros). On utilise le **réel** pour : *quelles* destinations, leur **côté L/R**
(géographie), le **type** (traversante / terminus / mixte), le **caractère**
(tagline/desc) et le **niveau de fret**. On ne grossit le nombre de quais /
directions **que dans l'enveloppe du palier** (voir §5). On ne fait PAS grandir
une petite gare à sa taille réelle si ça casse le palier (Charleroi ≈ 11 voies
en vrai, mais reste d1 / 4 quais, gare-tutoriel).

## 1. Recherche des données réelles (un agent par gare, en parallèle)

Pour chaque gare, récupérer :
- **Type** : traversante, terminus (cul-de-sac à heurtoirs) ou mixte. *Décisif* —
  le jeu modélise les deux distinctement. Vérifier explicitement (beaucoup de
  gares réputées « terminus » sont traversantes, et inversement).
- **Nombre de voies à quai** réel.
- **Destinations principales par axe géographique** (point cardinal + ligne).
- **Fret** : passe-t-il RÉELLEMENT à quai, ou contourne-t-il par une rocade /
  un autre itinéraire ? (souvent surestimé — cf. Strasbourg, Liège, Mons).
- **Trait distinctif** réel (rôle de nœud, architecture, rénovation…).

Sources : **iRail** liveboard (Belgique : `https://api.irail.be/liveboard/?station=<NOM>&format=json&arrdep=departure`),
**SNCF Open Data** / **DB Open Data** (autres pays), **Wikipedia** (FR/EN/NL/DE),
**OpenRailwayMap** (plan de voies, traversante vs terminus). Prioriser la
**connectivité du graphe** (§3) sur la correspondance littérale des n° de quai
d'un instantané liveboard.

Erreurs réelles typiques déjà corrigées : desserte disparue (Libramont→Bastogne,
fermé 1993), fret arrêté (Mons→Quiévrain, 1992 ; corridor rhénan qui contourne
Strasbourg), mauvaise gare (Lille-Flandres≠Lille-Europe pour Bruxelles/Eurostar).

## 2. Schéma d'une fiche (`data/stations/<pays>/<id>.json`)

```jsonc
{
  "id": "liege",                    // = nom de fichier, = clé dans geo.js
  "name": "Liège-Guillemins",       // nom COMPLET de la gare (fiche détaillée)
  "city": "Liège",                  // nom de VILLE affiché sur la carte-pays.
                                    // À AJOUTER dès que le nom diffère de la ville
                                    // (ex. « … Hbf », « …-Central »). Sinon omis
                                    // (la carte retombe sur `name`).
  "tagline": "…",                   // une ligne, accroche de la carte
  "desc": "…",                      // 2-3 phrases, caractère réel
  "difficulty": 4,                  // 1..5, définit le palier (§5)
  "country": "🇧🇪 Belgique",
  "platforms": [                    // impasse : "deadEnd": true (heurtoir)
    { "id": 1 }, { "id": 2 }, …
  ],
  "portals": {                      // = destinations
    "BRUXELLES": { "side": "L", "color": "#25dede", "abbr": "B" },
    "AACHEN":    { "side": "R", "color": "#f2588f", "abbr": "AC", "label": "AACHEN" }
    // side L = entre par la gauche, R = par la droite. label si accent/nom long.
    // in:false / out:false pour un portail à sens unique (rare).
  },
  "links": {                        // portail -> quais desservis. VOIR §3.
    "BRUXELLES": [3, 4, 5, 6],
    "AACHEN":    [4, 5, 6]
  },
  "sameSidePairs": [],              // [] normal ; "all" = terminus ;
                                    // [["A","B"],["B","A"]] = rebroussement A↔B
  "gen": { … }                      // paramètres du générateur, VOIR §5
}
```

Palette réutilisée : `#25dede` cyan, `#f5b23c` ambre, `#4ade80` vert,
`#f2588f` rose, `#60a5fa` bleu, `#a78bfa` violet.

Note : le champ `cap` (longueur de quai variable) est de la **donnée morte** —
non lue par le moteur, ne pas l'ajouter. Tous les quais font la même longueur
(≤ 7 wagons, `MAX_CARS`).

## 3. INVARIANT DE CONNECTIVITÉ (le piège n°1)

Un train ne circule qu'entre deux directions de **côtés opposés qui partagent au
moins un quai** dans `links` (ou une paire même-côté listée dans `sameSidePairs`).
Conséquences à garantir :
- **Aucun portail mort** : chaque portail doit partager un quai avec ≥1 portail
  du côté opposé. Sinon cette destination n'apparaît JAMAIS (invisible à l'œil).
- **Aucun quai mort** : chaque quai doit appartenir à l'intersection d'au moins
  une paire valide.
- Encoder les **vrais axes traversants** par des quais partagés (ex. le tronc
  Bruxelles–Aachen de Liège partage les quais 4-5-6).

Terminus (`sameSidePairs: "all"`, tous les portails du même côté, quais
`deadEnd`) : les trains entrent et rebroussent ; tout portail partageant un quai
avec un autre forme une paire valide.

## 4. Enregistrement (2 fichiers)

- `data/stations/index.json` : ajouter l'`id` dans le bloc `stations` du pays
  (créer le bloc `{ "country": "...", "label": "🏳️ ...", "stations": [...] }`
  pour un nouveau pays). L'ordre ne sert que de départage à difficulté égale.
- `js/geo.js` : ajouter `<id>: [longitude, latitude]` dans `countries.<pays>.cities`
  (coordonnées de la VILLE, pour la carte monde). Créer l'entrée pays si besoin
  (`{ name, flag, iso, continent, cities: {…} }`).

## 5. Enveloppes par palier (valeurs de référence `gen`)

`gen` = `{ nMin, nMax, gapMin, gapMax, cars[], freightRate, quietRate }`.
`cars` = tirage des longueurs (pondéré). `freightRate` = proba d'un fret
traversant/jour (0..1 ; ou `freightCount` fixe). `quietRate` = proba d'un jour
sans imprévu.

| Diff | Quais | Directions | nMin–nMax | gap | cars (typique) | notes |
|---|---|---|---|---|---|---|
| **1** | 4 | 4 | 12–15 | 1.6 / 2.8 | `[1,1,2,2,3,3,4]` | rames courtes, tutoriel |
| **1** term. | 6 | 4 | 11–14 | 2.0 / 3.4 | `[2,2,3,3,4,4,5]` | Lille |
| **2** | 5–6 | 5 | 13–16 | 1.8 / 3.0 | `[1,2,2,3,3,4,4,5]` | Louvain, Bruges, Nantes |
| **2** term. | 6 | 5 | 12–15 | 1.9 / 3.2 | `[3,3,4,4,5,5,6,7]` | Marseille (rames longues) |
| **3** | 6 | 5–6 | 14–15 → 17–18 | 1.6 / 2.8–3.2 | `[2,3,3,4,4,5,5,6]` (+7 pour 6 dir) | Lyon, Bordeaux, Gand… |
| **4** | 5–9 | 5–6 | 14–16 → 17–20 | 1.5 / 2.6 | jusqu'à 6–7 | dense ; fret 0.7 SI réel (Metz), sinon 0.15 (Strasbourg) |
| **5** | 8 | 6 | 18–22 | 1.4 / 2.4 | `[2,3,3,4,4,5,5,6,7]` | boss (Bruxelles-Midi, Paris-Nord) |

Limites moteur (ne pas dépasser) : **≤ 13 quais**, **~6 directions/côté**,
**≤ ~30-34 trains/jour** (au-delà : coût de génération cubique + le zéro n'est
plus garanti). Fret : cars 8–10, non plafonné par MAX_CARS.

## 6. Validation (obligatoire avant commit)

```bash
node tools/gen-check.mjs                # tout le catalogue, K=6
node tools/gen-check.mjs <id>           # une gare, K=30
node tools/gen-check.mjs <id1> <id2> 20 # gares ciblées, K=20
```

Charge le vrai moteur + générateur (headless, sans navigateur) et vérifie pour
chaque gare : **connectivité** (aucun portail/quai mort) + **K journées
générées** (0 erreur, aucun train non plaçable, retard garanti sous le seuil).
Code de sortie ≠ 0 si échec. Un « portail mort » ou un retard > seuil = à
corriger avant de committer.

## 7. Récap du flux pour un nouveau pays

1. Lister les gares visées + attribuer une difficulté (bâtir la rampe 1→5).
2. Un agent de recherche par gare (§1), en parallèle.
3. Composer chaque fiche (§2) en respectant hybride (§0) et connectivité (§3).
4. Enregistrer (§4) : index.json + geo.js.
5. `node tools/gen-check.mjs` → itérer jusqu'à « Toutes les gares passent ».
