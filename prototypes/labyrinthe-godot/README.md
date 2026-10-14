# Labyrinthe d'eau — la tranche Godot du rendu

Deux choses. **La scène** (`principal.gd`) rejoue un film de la partie,
enregistré depuis le moteur de la page web (`prototypes/prototype-labyrinthe.html`),
pour juger le rendu de l'eau sur l'iPhone. **Le moteur porté** (`moteur.gd`)
traduit celui de la page fonction pour fonction ; il n'est pas encore branché
sur la scène. C'est le plan d'essai de `reports/Animation de fluides pour jeu.md`
(étapes 1, 2 et le portage).

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

## Le moteur porté et son oracle

```bash
node tools/labyrinthe-vers-godot.mjs     # dérive niveau.json et oracle.json de la page
godot --headless --path prototypes/labyrinthe-godot --script res://oracle.gd
```

`oracle.json` contient des parties jouées par la page. Au repos, ce sont la
solution, le piège et six parties au hasard tirées comme celles du banc. En
temps réel, c'est le script du film. `oracle.gd` les rejoue avec `moteur.gd` et
refuse dans trois cas : une issue diffère, l'eau d'une case s'écarte de plus de
0,01 case, ou la boule de plus de 0,05 case. Le 14 octobre 2026 : 276 états,
écart maximal 2e-16 case d'eau et 2e-15 de boule (le dernier chiffre). En
revanche, le calcul est lent en GDScript : 2,5 ms par image en moyenne sur le
Mac, et 8 ms quand le robinet verse. `niveau.json` et `oracle.json` sont
**dérivés**, jamais édités à la main.

## Vérifier le rendu sans les doigts

```bash
LABY_CAPTURE=/un/dossier godot --path prototypes/labyrinthe-godot --resolution 600x1300
```

Cette commande ouvre la fenêtre, photographie huit images du film dans le
dossier, puis quitte.
