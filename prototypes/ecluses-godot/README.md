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
| **Le rendu** | fait vivre l'eau *entre* deux états du moteur, sans jamais rien décider | `canal.gd`, `eau.gd`, `porte.gd`, `aqueduc.gd`, `bateau.gd`, `shaders/` |

Le rendu n'a pas de simulation de fluide, exprès : un niveau doit rester
déterministe pour que le solveur puisse le vérifier. L'eau a l'air libre, mais
elle va où le moteur l'a décidé :

- **la surface** est une rangée de colonnes reliées par des ressorts, plus une
  houle douce ; sillages et bouillons lui donnent des impulsions (`eau.gd`) ;
- **les niveaux** suivent Torricelli : l'écart fond comme le carré du temps qui
  reste, l'eau ralentit en se posant (`canal.gd`, `ecouler`) ;
- **une porte se manœuvre comme une vraie écluse** (retours de Vincent, 6 octobre
  2026) : la roue, en haut d'un portique, ouvre une vanne ; l'eau passe par un
  **aqueduc** sous le fond des bassins — on la voit avancer dans le conduit,
  puis bouillonner à la grille du bassin qui se remplit — et c'est seulement
  quand les deux eaux sont au même niveau que le **vantail** monte entre les
  deux tours du portique, juste assez pour qu'un bateau passe dessous. Fermer,
  c'est l'inverse : le vantail redescend, puis la vanne se ferme (`porte.gd`,
  `aqueduc.gd`). Une porte levante parce que, vue de côté, c'est la seule dont
  le mouvement est vrai ; une porte qui pivotait puis une qui s'enfonçait dans
  le radier ont été essayées et écartées. Le moteur n'a pas changé — il
  exigeait déjà deux eaux au même niveau pour qu'un bateau passe, et c'est
  exactement quand le vantail se lève ;
- **l'eau** réfracte ce qui est derrière elle, s'assombrit avec la profondeur,
  porte des reflets mouvants et une ligne d'écume (`shaders/eau.gdshader`) ;
- **la chute sous une porte** est un aplat (style A de la planche du
  19 octobre 2026, choisi par Vincent) : une nappe d'un seul bleu, des stries
  qui descendent, et un bourrelet d'écume à cheval sur l'eau d'en bas, dessiné
  après elle. Elle recouvre ses raccords au lieu de les viser ; noyée, il ne
  reste que l'écume (`jet.gd`, `_aplat`). La rigole, la levée, le trop-plein
  et la pompe gardent l'ancien dessin en attendant de passer à l'aplat.

## Régler l'eau au doigt

Le bouton **Réglages**, en bas à gauche, déplie six curseurs qui dosent le
rendu de l'eau en direct : contraste et vitesse du courant dans l'aqueduc,
sillage des bateaux, bouillon à la sortie de l'aqueduc, houle, amortissement
des vagues. Chaque valeur s'affiche à côté de son curseur et se garde d'un
lancement à l'autre (sur le téléphone, `user://reglages.json`). Quand Vincent
a trouvé le bon dosage, ses chiffres deviennent les défauts de `reglages.gd`.

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

## Vérifier l'eau sans la regarder : le banc visuel

```bash
godot --headless --path prototypes/ecluses-godot --fixed-fps 120 --script res://banc-visuel.gd
```

Il joue la solution des 19 niveaux que Godot sait dessiner, du 1-1 au 16-1,
en 3 minutes (`-- --niveau=1-3` pour un seul, en quelques secondes) — comme
un doigt, d'un toucher par geste —, à 120, 60 et 30 images/s, puis une
seconde fois à 60. (Le doigt maintenu des niveaux « continu » a été abandonné
le 19 octobre 2026, Vincent : « une seule tape suffit » ; la tranche et le
banc savent encore le jouer, mais plus aucun niveau ne le porte.)
À chaque image, il mesure la géométrie que le rendu a produite, et REFUSE
(code 1) en disant la règle, la porte ou le bassin, le coup et l'instant :

| | la règle |
|---|---|
| V1 | une surface reste près de son niveau : ni creux, ni bloc d'eau (7,5 px hors sillage, 22 px dans le sillage d'un bateau en marche) |
| V2 | pendant un geste, un niveau ne fait pas d'aller-retour (il ne revient pas de plus d'un pixel du plus loin qu'il est allé) |
| V3 | une cascade (sous une porte, par-dessus un mur) part de l'eau d'en haut, pas d'au-dessus |
| V4 | son pied touche l'eau d'en bas : jamais suspendu (3 px), pas trop enfoncé (20 px, 30 pour la rigole qui tombe de haut et plonge dans une eau basse, validée ainsi par Vincent) |
| V5 | elle coule de l'eau haute vers l'eau basse, porte ouverte, eau au-dessus du seuil ou de la crête |
| V6 | les trois cadences racontent la même partie : même eau posée, même chemin des niveaux et des portes, même trajet de chaque bateau compté depuis son départ, même agitation ; le départ peut venir un peu plus tard à basse cadence (0,3 s au plus) |
| V7 | rejouée, la partie donne exactement les mêmes images |
| V8 | une surface ne saute pas d'une image à l'autre (200 px/s hors sillage) |

Les seuils viennent de la **mesure** du rendu validé, pas de l'œil. Pour
qu'une partie se rejoue à l'identique, le rendu ne dépend que du temps du jeu :
le hasard part d'une graine fixe par niveau (`principal.gd`), et ce qui se
tirait ou se poussait une fois par image est ramené à la durée de l'image
(`Canal._tirage`, sillage, roue qui force). La cadence de référence est celle
de l'iPhone (120 images/s), où l'eau a été réglée et validée : son rendu n'a
pas changé, ce sont les autres cadences qui s'alignent sur lui.

Éprouvé le 15 octobre 2026 en réintroduisant d'anciens défauts, niveau par
niveau (1-2, 1-3, 1-4, 4-1, 11-1, 15-1) : il refuse partout un courant à
l'envers et une cascade arrêtée au-dessus de l'eau ; un sillage poussé à
chaque image partout où les bateaux bougent assez (pas au 11-1) ; une nappe
plus épaisse que l'eau d'amont au 1-2 (ailleurs l'eau d'en haut ne descend
jamais jusqu'au seuil) ; une nappe qui franchit un mur avant que l'eau n'y
arrive au 15-1. Un niveau nouveau n'entre dans `NIVEAUX` qu'après cette
épreuve. `-- --suivre=coup:bassin` imprime un niveau (et la force des
cascades) image par image, `-- --suivre=coup:-1` les bateaux, pour chercher
une cause.

En l'étendant au 1-3 et au 1-4, il a trouvé deux vrais défauts, corrigés :
la cascade s'arrêtait sur la surface mesurée 60 px plus loin et restait
suspendue jusqu'à 3 px au-dessus d'une eau plus basse (elle s'arrête
maintenant sur l'eau là où elle tombe), et un bateau qui partait après un
autre perdait jusqu'à une image à chaque départ. Étendu aux niveaux au
toucher, il en a trouvé un troisième, bien visible : au 15-1, une nappe
coulait sur la levée vers la grange alors que le bief était encore 50 px plus
bas que la crête — le pré commençait à se remplir au plus tard aux trois
quarts de la manœuvre, et la nappe anticipait. Le bief monte maintenant à la
crête juste quand le pré commence à se remplir, et la nappe attend l'eau.
Il ne voit pas
les défauts de COULEUR (une tranche sombre, une eau trop opaque) : ceux-là
restent à l'œil, sur un film au format de l'iPhone.

## Sur l'iPhone

```bash
tools/ios-ecluses.sh --etat     # compte Xcode, iPhone branché, dernier export
tools/ios-ecluses.sh            # exporte, signe, installe et lance
```

Le préréglage d'export (`export_presets.cfg`) est ignoré par git : il porte
l'équipe Apple de la machine. Il a été dérivé de celui de Station 7 (seuls
changent le chemin d'export et l'identifiant `be.vincentdebaty.ecluses`).
Compte gratuit : l'app expire au bout de sept jours, relancer le script.
Les versions de test affichent les images par seconde en bas à gauche.

## Les images

`art/maquette.webp` est la maquette du niveau 14 générée par ChatGPT ; on en
découpe le panorama en attendant le vrai. Ce qui manque, et les prompts pour
l'obtenir : `ASSETS.md`.
