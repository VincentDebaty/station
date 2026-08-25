# Station — le poste d'aiguillage

Jeu d'aiguillage ferroviaire, web (PWA), projet personnel de Vincent.
Dépôt GitHub `VincentDebaty/station`, branche par défaut `main`.

**Lis `README.md` en premier** : lancement, organisation des fichiers, et la
procédure de rafraîchissement sur iPhone (service worker + cache — c'est la
source de bug la plus fréquente, elle est entièrement documentée là-bas).
Ce fichier-ci ne répète pas le README : il dit **comment travailler ici**.

## Langue

Tout est en français : commentaires, documents, messages de commit, et les
noms de fonctions du code récent (`prochaineGare`, `zonesDeCarte`,
`recompense.js`). Le noyau plus ancien (`engine.js`, `render.js`,
`schedule.js`) est resté en anglais (`loadStation`, `PLATFORMS`, `PORTALS`).

Suis la langue **du fichier dans lequel tu écris**. Ne renomme jamais pour
uniformiser : ces fichiers sont gros et le diff noierait le vrai changement.

## Pas de chaîne de build

Aucun `package.json`, aucune dépendance, aucun bundler. Les fichiers `js/` sont
des scripts classiques en `"use strict"` qui partagent des globales, chargés
**dans l'ordre** par `station.html` (lignes 240-255) — pas de modules ES, pas
d'`import` côté jeu. Ajouter un fichier `js/`, c'est aussi ajouter sa balise
`<script>` **à la bonne position** dans `station.html`.

Les outils `tools/*.mjs` sont, eux, de l'ESM Node lancé directement
(`node tools/...`), sans installation.

Lancer le jeu : `python3 tools/serve.py` (port 8000 par défaut). Un
double-clic sur `station.html` ne marche pas — les fiches de gares sont
chargées en `fetch`.

## Les contrôles sont les tests

Il n'y a pas de framework de test. Il y a quatre contrôles headless, qui
**refusent** au lieu d'avertir (code de sortie ≠ 0) :

| Commande | Ce qu'elle garde |
|---|---|
| `node tools/gen-check.mjs` | les fiches de gare : connectivité, génération d'horaire, **pression** (files d'attente sur un quai) |
| `node tools/carte-check.mjs` | la carte est-elle livrable — règles R1…R5 |
| `node tools/graph-check.mjs` | les invariants du graphe : intégrité, connexité, écartement |
| `node tools/net-check.mjs` | le réseau tracé et les coordonnées (`js/geo.js`, `data/places.js`) |

**`gen-check` demande DEUX balayages, et ils ne servent pas à la même chose :**
`--seed=N` pour la non-régression (reproductible, comparable), puis au moins un
tirage **libre** relancé plusieurs fois pour explorer la queue de distribution.
Ne jamais conclure « c'est vert » sur un seul balayage non graîné : mesuré le
22 août 2026, quatre balayages verts d'affilée puis un cinquième qui sort deux
gares défectueuses depuis toujours. La règle et ses mesures sont dans
`tools/AUTHORING-STATIONS.md` §6 — lis-le avant de toucher une fiche.

Une story sur ce projet formule son « Done when » avec ces commandes, pas avec
« ça a l'air de marcher ».

## Où sont les règles du jeu

Ne déduis jamais une règle du code : elle est écrite quelque part, et un
contrôle en est l'autorité.

- `meta-progression-jeu-aiguillage.md` — le design : les quatre niveaux (gare,
  ligne, zone, carte), la construction d'une carte, les récompenses, le modèle
  de données. La référence.
- `plan-de-dev.md` — les lots A→H, avec ce qui est **fait** et ce qui est
  reporté. À mettre à jour quand un lot avance.
- `tools/AUTHORING-STATIONS.md` — la procédure pour écrire une gare. Obligatoire.
- `tools/AUTHORING-CARTES.md` — la procédure pour écrire une carte.
- `tools/AUTHORING-MANIFESTE.md` — le format du manifeste d'enregistrement.
- `data/cartes/README.md` — le schéma d'une carte.

`carte-check.mjs` est explicitement « la seule autorité » sur la lecture des
règles de carte : une règle qu'on ne mesure pas est une intention, pas une règle.

## Les données priment sur le rendu

Le jeu web est un **prototype** : on n'investit rien dans une chaîne graphique
web, mais tout ce qui est données et règles (cartes, fiches, contrôles) est
écrit pour survivre à un portage sous Unity ou Godot. D'où le JSON pour les
cartes et les fiches. Ne mets jamais une règle de jeu dans `render.js`.

Une gare = `data/stations/<pays>/<id>.json` + son entrée dans
`data/stations/index.json` (la position dans l'index **est** la progression).

## Écrire plusieurs gares en parallèle

Cinq fichiers sont partagés et se disputent dès qu'on écrit à plusieurs :
`index.json`, `js/geo.js`, `data/lines.js`, `data/places.js`,
`data/cartes/europe.json`. Personne ne les édite à la main dans ce cas :

1. chaque session écrit ses fiches et **un manifeste**
   (format : `tools/AUTHORING-MANIFESTE.md`) ;
2. `node tools/gen-check.mjs --fiche=<chemin.json>` valide une fiche pas encore
   inscrite à l'index ;
3. `node tools/enregistrer.mjs <manifeste|dossier>` enregistre — dans l'ordre,
   une fois, de façon idempotente. Il ne valide rien et imprime à la fin les
   contrôles à repasser.

## La sauvegarde ne se casse pas

`js/store.js` est le **seul** fichier qui connaît le support de stockage
(localStorage, ou Capacitor Preferences en app native). Le reste du jeu lit un
cache mémoire en synchrone. Il n'existe pas encore de projet natif iOS/Android :
le support Capacitor est écrit d'avance, pour que le portage ne touche que
`makeBackend()`.

Toute modification du format sauvegardé impose d'incrémenter `SCHEMA_VERSION`
et d'écrire la migration dans `migrate()`, testée depuis une sauvegarde
ancienne. Schéma courant : **6** (la progression est par carte). Une mise à
jour qui perd la partie d'un joueur est un bug bloquant, pas un détail.

## Git

- Messages de commit **en français**, sur le modèle des commits existants :
  un titre = une phrase narrative, sans préfixe de type (`fix:`, `feat:`) ;
  un corps qui explique la **cause**, ce qui a été mesuré, et ce qui reste. Les
  chiffres du contrôle ont leur place dedans (« Quatre balayages : deux à graine
  fixe, deux libres. Aucun échec. »).
- **Commit direct sur `main` autorisé sur ce projet** — décidé par Vincent le
  25 août 2026. C'est une exception : sur tous les autres projets, une session
  déléguée s'arrête sur une branche poussée. Station est personnel, sans
  relecture à organiser, et l'historique s'est toujours écrit ainsi.
  Contrepartie : les contrôles ci-dessus ne sont pas négociables, puisque plus
  rien ne s'interpose entre un commit et `main`. Un travail long ou risqué
  mérite quand même une branche.
- **Jamais de force-push**, jamais de réécriture d'un historique déjà poussé.

## À ne pas toucher

- `prototypes/` — anciennes versions (Namur, gare centrale v2), gardées pour
  mémoire, hors du jeu.
- `data/worldmap.js` — généré depuis Natural Earth, jamais édité à la main.

## Détail connu

L'en-tête de `tools/graph-check.mjs` annonce `data/graph.js` : ce fichier
n'existe plus depuis le lot A (août 2026), le contrôle lit
`data/cartes/<id>.json`. Commentaire périmé, script correct.
