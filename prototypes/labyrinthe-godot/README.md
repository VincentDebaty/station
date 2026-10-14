# Labyrinthe d'eau — la tranche Godot

Le labyrinthe d'eau joué dans Godot 4.7. Une boule flotte dans un labyrinthe
vu en coupe. Le robinet verse, les vidanges vident, et l'eau coule de bassin
en bassin jusqu'à porter la boule à la sortie.

**Godot fait autorité sur les règles depuis le 14 octobre 2026** (décision de
Vincent) : le moteur et le banc vivent ici. La page web
`prototypes/prototype-labyrinthe.html` reste figée comme trace du prototype,
avec son ancien banc `tools/labyrinthe-banc.mjs`.

## Lancer

```bash
godot --path prototypes/labyrinthe-godot
tools/ios-labyrinthe.sh                 # l'exporte et le pose sur l'iPhone
```

On touche un bouton de vanne pour verser ou vider une unité. L'appui long
verse (ou vide) en continu. En bas de l'écran, un compteur donne les images
par seconde et le coût du moteur.

## Les fichiers

| | ce qu'il fait |
|---|---|
| `niveau.json` | le niveau : la grille, les vannes, l'eau de départ, la solution, le *par*, les pièges |
| `moteur.gd` | les règles : l'eau par volumes, la surface à ressorts, la boule ; déterministe |
| `banc.gd` | le banc d'essai, sans écran ; il refuse au lieu d'avertir |
| `principal.gd` | la scène : joue le moteur en direct et le dessine |
| `eau.gdshader` | le rendu de l'eau : dégradé, liseré, reflets |
| `chute.gdshader` | la nappe d'une cascade : bords adoucis, stries qui descendent |

## Le moteur : l'eau par volumes, la surface à ressorts

**Les bassins.** Le labyrinthe est découpé en bassins : chaque colonne d'eau
d'un seul tenant. Un bassin a :
- un volume et une capacité ;
- une **charge** : la hauteur de sa surface ou, s'il est plein sous un
  plafond, une hauteur de pression. Une petite compressibilité pousse l'eau à
  travers les passages noyés en conservant exactement le volume.

**L'écoulement.** Deux bassins voisins sont reliés par leur ouverture commune.
L'eau y passe à un débit de
`DEBIT_OUVERTURE × hauteur mouillée × √(écart de charge)`, à la manière de
Torricelli : fort quand l'écart est grand, il ralentit à l'approche de
l'équilibre. Quand le bassin d'arrivée est plus bas que l'ouverture, c'est une
cascade. Le calcul se fait en 4 sous-pas fixes par image, sans dépendre de la
cadence de l'écran.

**La surface.** Chaque bassin à surface libre porte 8 points par case.
- Chaque point est rappelé vers le niveau, amorti, et transmet ses vagues à
  ses voisins, y compris d'un bassin à l'autre quand la surface passe par leur
  ouverture.
- Sa moyenne est ramenée au niveau du volume réel.
- Les cascades, les vidanges et la boule y créent des vagues.
- Une houle de repos très légère s'ajoute, seulement à l'écran.

**La boule.** Elle flotte sur la surface locale, bute sous un plafond, et prend
la vitesse de l'eau qui passe les ouvertures proches. Ce courant pèse
pleinement jusqu'à une case, puis s'affaiblit jusqu'à 2,2 cases.

## Les cascades et les éclaboussures

Une ouverture forme une cascade quand le bassin d'arrivée est plus bas que
son seuil.
- **La portée** est calculée par le moteur (`Moteur.portee`) :
  0,6·√(charge au-dessus du seuil × hauteur de chute), bornée à 0,3 case —
  bien moins qu'un jet de Torricelli, car une nappe qui déborde sort
  lentement et Vincent la voulait verticale. La vague de la surface d'arrivée part de
  ce point, et la nappe y tombe en parabole.
- **Un puits** (deux colonnes voisines reliées par une ouverture haute) se
  dessine à un niveau commun, celui que donne son volume : le moteur laisse un
  retard entre les deux colonnes quand on vide par le fond, qui se voyait
  comme une bosse. La boule suit l'eau dessinée.
- **Le débit lissé** règle tout l'effet. Il monte vite et retombe doucement :
  une chute qui s'arrête s'amincit puis s'éteint.

| débit (case/image) | nappe | au pied |
|---|---|---|
| faible, < 0,015 | un filet étroit | presque pas de gouttes |
| moyen, < 0,05 | plus large, stries visibles | des bulles qui remontent |
| fort | une cascade | de l'écume qui s'étale, des éclaboussures |

Les particules (gouttes, bulles, écume) vivent dans un réservoir fixe de
220 places, sans allocation image par image. Elles sont purement visuelles et
n'influencent jamais le moteur.

## Les reflets et la boule

`eau.gdshader` dessine dans chaque bassin :
- **le dégradé** : cyan en surface, bleu plus profond vers le fond ;
- **le liseré** de surface, qui scintille par endroits ;
- **les reflets** : de fins traits clairs juste sous la surface, tirés d'un
  bruit étiré qui dérive lentement. Ils épousent les vagues, car on les place
  en profondeur sous la surface, et ils ne répètent jamais le même motif ;
- **la lumière en profondeur** : des voiles très doux qui ondulent.

Le bruit est un hachage sans sinus, stable sur les cartes graphiques mobiles.

La boule, à l'affichage seulement :
- **elle roule** avec son déplacement ;
- **elle s'incline** avec la pente de la surface sous elle, comme une bouée,
  grâce à un ressort amorti qui l'empêche de trembler ;
- **elle suit la petite houle** de repos ;
- **sa part immergée** est voilée d'eau, sous une ligne de flottaison claire.

Le moteur n'en sait rien : la flottaison et le courant restent les siens.

## Vérifier

```bash
godot --headless --path prototypes/labyrinthe-godot --script res://banc.gd
LABY_PARTIES=60 LABY_GRAINE=900 godot --headless --path prototypes/labyrinthe-godot --script res://banc.gd
```

Le banc vérifie trois choses (environ 70 s) :
- **les données** du niveau ;
- **la solution** : elle sort la boule, aucune suite plus courte que le *par*
  ne gagne (en deux séries de tapes au plus), et les pièges ne gagnent pas ;
- **les invariants à chaque image** : conservation de l'eau à 1e-9 près,
  surface de moyenne nulle, déterminisme, boule hors des murs, retour au calme.

Il mesure aussi la butte, le tube en U, le retour au calme et le coût par image.

```bash
LABY_CAPTURE=/un/dossier godot --path prototypes/labyrinthe-godot --resolution 600x1300
```

Cette commande joue la solution toute seule, avec le robinet tenu, photographie
huit images et quitte. Elle a besoin d'une fenêtre : `--headless` ne rend rien.
Avec `LABY_DEMO=chute`, elle vide d'abord le bassin de gauche puis tient le
robinet : on y voit une chute haute, à fort débit, avec tous ses effets.
Avec `LABY_DEMO=deversoir`, le robinet tenu remplit tout, puis la vidange de
droite tenue fait passer le couloir du haut par-dessus son bord : on y juge la
lèvre d'une chute (la surface qui s'arrondit au bord, la nappe de la même
épaisseur que l'eau qui part).

Pour traquer les défauts sur toute une manœuvre, `LABY_GESTES` joue une suite
de gestes écrite à la main et photographie une image toutes les 0,2 s
(`LABY_TOUTES=12` images du moteur), jusqu'à `LABY_FIN`, sous le nom
`LABY_NOM`. Un geste `image:k` tape la vanne k (0 le robinet, 1 et 2 les
vidanges), `image:+k` la tient, `image:-` la relâche :

```bash
LABY_NOM=A LABY_GESTES="10:+0 250:- 280:+1" LABY_FIN=1000 LABY_CAPTURE=/un/dossier godot --path prototypes/labyrinthe-godot --resolution 600x1300
```

Les cinq manœuvres du 14 octobre 2026 : tout remplir puis vider à gauche
(`10:+0 250:- 280:+1`), à droite (`… 280:+2`), en alternant les deux
vidanges une tape toutes les 40 images, vider à droite puis verser puis
vider à gauche (`10:+2 200:- 220:+0 400:- 420:+1`), et la solution
(`30:2 100:2 170:2 240:+0`). On les monte en planches et on les regarde
image par image. `LABY_DEBUG=<image>` imprime l'état de chaque bassin à
cette image (niveau, masse, référence de teinte).
