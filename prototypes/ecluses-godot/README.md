# Écluses — la tranche Godot

Un niveau (le 1-2, « Croisement ») joué de bout en bout dans Godot 4.7, pour
répondre à une seule question : **peut-on garder l'allure de la maquette avec
une eau qui bouge de façon fluide et crédible ?**

C'est un projet Godot à part entière, rangé dans `prototypes/` du dépôt Station
(que le projet Station 7 ignore, grâce à `prototypes/.gdignore`). La page web
`prototypes/prototype-ecluses.html` reste la source des niveaux et des règles.

## Lancer

```bash
godot --path prototypes/ecluses-godot
```

On touche une roue rouge pour ouvrir ou fermer sa porte. `ECLUSES_NIVEAU=1-3`
lance un autre niveau (tous les niveaux à portes s'affichent ; les digues, les
champs et le fleuve ne sont pas encore dessinés).

## L'architecture : deux couches qui ne se mélangent pas

| | ce qu'elle fait | fichiers |
|---|---|---|
| **La logique** | décide des niveaux d'eau et des bateaux, au millionième — c'est le moteur de la page web, porté fonction pour fonction | `moteur.gd` |
| **Le rendu** | fait vivre l'eau *entre* deux états du moteur, sans jamais rien décider | `canal.gd`, `eau.gd`, `porte.gd`, `jet.gd`, `bateau.gd`, `shaders/` |

Le rendu n'a pas de simulation de fluide, exprès : un niveau doit rester
déterministe pour que le solveur puisse le vérifier. L'eau a l'air libre, mais
elle va où le moteur l'a décidé :

- **la surface** est une rangée de colonnes reliées par des ressorts, plus une
  houle douce ; jets, sillages et remous lui donnent des impulsions (`eau.gd`) ;
- **les niveaux** suivent Torricelli : l'écart fond comme le carré du temps qui
  reste, l'eau ralentit en se posant (`canal.gd`, `ecouler`) ;
- **le jet** sort de la porte en nappe et tombe en parabole quand le bassin qui
  reçoit est sous le seuil ; s'il le couvre déjà, l'eau bouillonne au lieu de
  tomber (`jet.gd`) ;
- **l'eau** réfracte ce qui est derrière elle, s'assombrit avec la profondeur,
  porte des reflets mouvants et une ligne d'écume (`shaders/eau.gdshader`).

## Vérifier sans les doigts

```bash
# le moteur porté rejoue-t-il le moteur web ? (refuse au premier écart)
node tools/ecluses-vers-godot.mjs
godot --headless --path prototypes/ecluses-godot --script res://oracle.gd

# la démo joue la solution et photographie l'écran
ECLUSES_DEMO=1 ECLUSES_CAPTURE=/tmp/ecluses godot --path prototypes/ecluses-godot --audio-driver Dummy

# la même, filmée à 30 images/s
ECLUSES_DEMO=1 ECLUSES_CAPTURE=/tmp/ecluses godot --path prototypes/ecluses-godot --audio-driver Dummy --write-movie /tmp/ecluses/film.avi --fixed-fps 30
```

`--headless` ne rend rien : la démo se lance en fenêtre.

## Les images

`art/maquette.webp` est la maquette du niveau 14 générée par ChatGPT ; on en
découpe le panorama en attendant le vrai. Ce qui manque, et les prompts pour
l'obtenir : `ASSETS.md`.
