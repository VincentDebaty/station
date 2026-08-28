# Les cartes — le schéma

Une carte est un **territoire fermé** parcouru par un **ruban** : une suite
ordonnée de gares, sans embranchement et sans choix. Un fichier par carte,
autonome : `data/cartes/<id>.json`, listé dans `index.json`.

Les cartes sont des **missions indépendantes** : chacune a sa progression, et
rien de l'une ne sert à l'autre. Ce qu'elles partagent, c'est la bibliothèque
des fiches de gares (`data/stations/`) — la même Namur peut servir sur deux
cartes, avec deux progressions distinctes.

Pourquoi du JSON et non du JS : le jeu web est un prototype, le moteur final
(Unity ou Godot) lira les mêmes fichiers. Une carte ne doit rien devoir au
navigateur.

## Le schéma

```jsonc
{
  "id": "europe",
  "nom": "L'Europe",
  "gratuite": true,
  "prixCredits": 0,              // absent si gratuite
  "enChantier": true,            // relâche R2 et R4 dans carte-check (voir plus bas)
  "note": "…",                   // à l'usage des auteurs, jamais affichée
  "echelle": { "kmMinEntreHubs": 110 },

  "zones": [                     // les grandes régions du voyage
    { "id": "rhin", "nom": "Le Benelux et le Rhin", "couleur": "#5b8def" }
  ],

  "chapitres": [                 // ★ DANS L'ORDRE DU RUBAN — c'est la progression
    {
      "id": "l-ardenne",
      "nom": "L'Ardenne",        // un nom de VOYAGE, pas un nom de règle
      "zone": "rhin",
      "gares": ["arlon", "libramont", "marloie", "namur", "ottignies", "bruxelles-midi"],
      "plancher": 1,             // difficulté de départ du chapitre (§2.5)
      "arrivee": 3,              // plafond de la difficulté à l'arrivée (facultatif)
      "sinuosite": 1.75,         // sinuosité ASSUMÉE au-dessus de 1,5 (facultatif, R7) —
                                 // pour les rails réels qui serpentent (tour de la botte)
      "saut": {                  // rupture géographique AVANT ce chapitre (§4 bis)
        "mode": "nuit",          // "nuit" | "correspondance" | "mer"
        "texte": "Le train de nuit pour Marseille"
      }
    }
  ]
}
```

**Ce qui a disparu avec le graphe** (25 août 2026) : `hubs`, `lignes`,
`de`/`vers`, les `versions` de hub. Une grande gare n'est plus un nœud de
choix : c'est la **dernière gare d'un chapitre**, et rien ne la distingue dans
les données. Les coordonnées des villes vivent dans `js/geo.js`, jamais ici.

## Les règles, et qui les mesure

`tools/carte-check.mjs` est **la seule autorité**. Il refuse (code de sortie
≠ 0) plutôt qu'il n'avertit — une règle qu'on ne mesure pas est une intention.

| # | Règle |
|---|---|
| R1 | La carte est un **ruban unique** : aucune gare deux fois, aucun chapitre vide |
| R2 | **≥ 60 gares et ≥ 8 chapitres** |
| R3 | Un chapitre compte **5 à 10 gares**, la dernière étant une grande gare |
| R4 | Une zone compte **6 à 20 chapitres**, ≥ 2 zones, écart entre zones < 3 pour 1 |
| R5 | **Continuité réelle** dans un chapitre ; une rupture n'est permise qu'entre deux chapitres, et seulement si `saut` est déclaré |
| R6 | Une fiche une seule fois ; revenir dans une ville suppose **une autre gare** |
| R7 | **Sinuosité ≤ 1,5** par chapitre |
| R8 | La difficulté croît vers la grande gare (avertissement : la géométrie a le dernier mot) |
| R9 | **Le premier chapitre est doux** : plancher 1, arrivée ≤ 3 — c'est le tutoriel |

**`enChantier: true`** relâche **R2 et R4** en avertissements. Ce sont les deux
règles de *complétude* : elles parlent d'une carte finie. Les règles de
*correction* — R1, R3, R5 à R9 — ne se relâchent jamais.

## Le ruban livré, et le ruban visé

`europe.json` ne porte pour l'instant que **onze chapitres**, de Luxembourg à
Hambourg : la tranche du ruban qui est **écrite**. Le ruban complet — de Cork à
Istanbul, 95 chapitres, 593 gares — est décrit dans **`ruban-europe.md`** à la
racine du dépôt, et se greffe **devant** celui-ci au fur et à mesure.

Le fichier se régénère depuis le ruban :

```sh
python3 tools/ruban/export-carte.py 51 61     # premier et dernier chapitre
node tools/carte-check.mjs
```

Une gare du ruban **sans fiche écrite** ne casse rien : le jeu s'arrête devant
elle et affiche « la suite du ruban n'est pas encore écrite ». Aucune gare
n'est jamais proposée sans fiche.
