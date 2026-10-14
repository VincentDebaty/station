# Labyrinthe d'eau — la tranche Godot du rendu

Un seul but : **juger sur l'iPhone le rendu de l'eau**, avant de porter quoi que
ce soit. Ce projet ne calcule rien. Il rejoue un film de la partie, enregistré
depuis le moteur de la page web (`prototypes/prototype-labyrinthe.html`), et le
dessine. C'est l'étape 2 du plan d'essai de `reports/Animation de fluides pour jeu.md`.

## Lancer

```bash
node tools/labyrinthe-film.mjs          # refait film.json depuis la page web
godot --path prototypes/labyrinthe-godot
tools/ios-labyrinthe.sh                 # l'exporte et le pose sur l'iPhone
```

Le film dure 7,6 s : deux vidanges, puis le robinet tenu jusqu'à la sortie de
la boule. Il reprend tout seul. Toucher l'écran le relance. En haut, trois
compteurs : images par seconde, millisecondes de processeur et de carte graphique.

`film.json` est **dérivé** : refait par `tools/labyrinthe-film.mjs`, jamais
édité à la main.

## Le rendu

- **L'eau** est un shader (`eau.gdshader`) posé sur le champ du film. Le champ
  est la part d'eau de chaque petite case (4 × 4 par case du labyrinthe), en
  texture. Les étapes :
  - lecture en **B-spline cubique**, pour une surface lisse sans facettes ;
  - **fondu entre deux images** du moteur, pour que l'eau glisse même à 120 i/s ;
  - **bord adouci au pixel** ;
  - **liseré clair** d'épaisseur constante à l'écran ;
  - eau qui **fonce en profondeur**.
- **Les murs** sont dessinés par-dessus l'eau, en une bande de sable autour de
  chaque creux. L'eau s'enfonce un peu dans les murs, et la bande la coupe net.
- **La boule** est placée et tournée d'après le film, interpolée entre deux images.

## Vérifier sans les doigts

```bash
LABY_CAPTURE=/un/dossier godot --path prototypes/labyrinthe-godot --resolution 600x1300
```

Cette commande ouvre la fenêtre, photographie huit images du film dans le
dossier, puis quitte.
