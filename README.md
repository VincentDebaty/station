# Station — Le poste d'aiguillage

Jeu d'aiguillage ferroviaire : orchestrez l'entrée et la sortie des trains d'une gare
avec zéro retard. Une étoile ouvre la gare suivante sur la ligne ; au bout de la
ligne, un hub ; derrière le hub, le choix d'une nouvelle ligne.

## Lancer le jeu

Les fiches de gares sont chargées en JSON via `fetch`, ce qui exige un petit
serveur local (un simple double-clic sur `station.html` en `file://` ne suffit pas) :

```sh
python3 tools/serve.py
# affiche l'adresse à ouvrir sur le Mac ET celle à ouvrir sur le téléphone
```

`tools/serve.py` est un `http.server` qui envoie `Cache-Control: no-store`.
C'est important pour tester sur téléphone : sans cet en-tête, Safari réutilise
un fichier déjà vu sans demander s'il a changé, et l'on finit avec un mélange
de versions (un `engine.js` de la veille face à un `game.js` du jour) — le jeu
s'ouvre alors sur un plan vide. `python3 -m http.server` reste utilisable pour
jouer sur le Mac seulement.

### Actualiser sur iPhone

Le jeu est une PWA : un service worker (`sw.js`) et un cache s'interposent.
Pour voir une modification, du plus simple au plus radical :

1. **Recharger l'onglet** Safari. `sw.js` est en « réseau d'abord », il est
   enregistré avec `updateViaCache: "none"` et `update()` est appelé à chaque
   chargement (bas de `station.html`) ; quand la nouvelle version prend la main,
   la page se recharge d'elle-même via `controllerchange`. Si tu as changé
   `sw.js` lui-même, compte deux rechargements.
2. **Onglet privé** : ni service worker ni cache ne s'y appliquent — le meilleur
   moyen de tester une version fraîche sans effacer ta progression.
3. **App installée sur l'écran d'accueil** : la fermer depuis le sélecteur
   d'apps (glisser vers le haut) puis la rouvrir, sinon elle reste en vie avec
   son ancien code.
4. **Inspecteur Web** (le plus fiable) : iPhone → Réglages ▸ Safari ▸ Avancé ▸
   Inspecteur Web ; puis, sur le Mac, Safari ▸ Développement ▸ *ton iPhone* —
   tu obtiens la console et *Vider les caches*.
5. En dernier recours : Réglages ▸ Safari ▸ Avancé ▸ Données de sites web, puis
   supprimer l'entrée du site. ⚠️ Cela efface aussi le `localStorage`, donc
   **la progression et les préférences**.

En cas d'écran vide, un bandeau rouge en bas affiche l'erreur (il n'y a pas de
console sur téléphone) ; un mélange de versions est détecté et réparé tout seul
par un rechargement unique — voir le script en tête de `station.html`.

## Documents de conception

- `meta-progression-jeu-aiguillage.md` — la méta-progression en quatre niveaux
  (gare, ligne, zone, carte), les règles de construction d'une carte, les
  récompenses, le modèle de données.
- `plan-de-dev.md` — le plan de réalisation par lots.
- `tools/AUTHORING-STATIONS.md` — la procédure pour écrire une fiche de gare.

## Organisation des fichiers

```
station.html                  Page du jeu (structure HTML seule) ; index.html y redirige
css/station.css               Styles
js/
  store.js                    Persistance (cache mémoire, versionnement, localStorage ou Capacitor)
  catalog.js                  Chargement du catalogue JSON, paliers, grades
  engine.js                   Constantes, géométrie des voies, loadStation()
  schedule.js                 Générateur d'horaire calibré « zéro retard possible »
  gen-worker.js               La génération tourne dans un Web Worker
  render.js                   Rendu SVG, frise, animations, sons
  game.js                     État de la partie, enclenchement, interactions, boucle tick()
  cartes.js                   Chargement des cartes et de la carte courante
  graph.js                    Le graphe vu du jeu : sorties, parcours, difficulté par position,
                              versions de hub, lignes de départ, gares ouvrables
  recompense.js               Série, rangs de ligne, médailles — déduits de la progression
  carte.js                    La carte à trois échelles (ligne / constellation / Europe)
  network.js, geo.js          Réseau ferré dérivé et coordonnées des villes
  hub.js                      Point d'entrée historique showHub(), délègue à carte.js
  main.js                     Horloge, contrôles, démarrage
data/
  cartes/index.json           La liste des cartes (missions indépendantes)
  cartes/europe.json          La carte Europe : zones, hubs, lignes (voir cartes/README.md)
  lines.js, places.js         Lignes réelles et points de passage pour le tracé
  worldmap.js                 Frontières (Natural Earth), généré
  stations/index.json         Les pays et leurs gares (bibliothèque de fiches)
  stations/<pays>/<id>.json   Une fiche par gare : plan de voies, portails, liaisons, gen
tools/                        Serveur local, contrôles (gen-check, carte-check,
                              net-check), propositions de corridors, procédures d'écriture
                              (AUTHORING-STATIONS.md pour une gare, AUTHORING-CARTES.md pour une carte)
assets/                       Images concept
prototypes/                   Anciennes versions (prototype Namur, gare centrale v2)
```

## Ajouter une gare

1. Créer `data/stations/<pays>/<id>.json` sur le modèle d'une fiche existante :
   `id`, `name`, `country`, `desc`, `platforms` (avec `deadEnd` pour les impasses),
   `portals` (côté `L`/`R`, couleur, abréviation), `links` (portail → quais),
   `sameSidePairs` (`"all"` pour une gare terminus) et `gen` (paramètres du générateur).
2. L'ajouter dans `data/stations/index.json` à la position voulue dans la progression.

Le moteur s'adapte automatiquement au nombre de quais et de portails ;
le calibrage garantit qu'une journée à zéro retard reste jouable.
