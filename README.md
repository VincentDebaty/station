# Station — Le poste d'aiguillage

Jeu d'aiguillage ferroviaire : orchestrez l'entrée et la sortie des trains d'une gare
avec zéro retard. Une étoile débloque la gare suivante.

## Lancer le jeu

Les fiches de gares sont chargées en JSON via `fetch`, ce qui exige un petit
serveur local (un simple double-clic sur `station.html` en `file://` ne suffit pas) :

```sh
python3 -m http.server
# puis ouvrir http://localhost:8000/station.html
```

## Organisation des fichiers

```
station.html                  Page du jeu (structure HTML seule)
css/station.css               Styles
js/
  catalog.js                  Chargement du catalogue JSON + progression (localStorage)
  engine.js                   Constantes, géométrie des voies, loadStation()
  schedule.js                 Générateur d'horaire calibré « zéro retard possible »
  render.js                   Rendu SVG, frise, animations, sons
  game.js                     État de la partie, enclenchement, interactions, boucle tick()
  hub.js                      Carte-parcours (sélection des gares)
  main.js                     Horloge, contrôles, démarrage
data/stations/
  index.json                  Ordre des pays et des gares = ordre de progression
  belgique/                   namur, charleroi, liege, anvers, bruxelles-midi
  france/                     lille, lyon, strasbourg, marseille, paris-nord
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
