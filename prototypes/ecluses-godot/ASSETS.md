# Les images d'Écluses — ce qu'il faut, et les prompts pour les obtenir

La tranche dessine tout elle-même (shaders et dessin vectoriel). Une image
posée dans `art/` sous le bon nom **remplace** le dessin correspondant, sans
rien toucher au code. Ce qui n'a pas d'image reste dessiné.

## Les règles communes à toutes les images

- **Fond transparent** (PNG avec canal alpha), sauf le panorama.
- **Vue de profil stricte**, orthographique : pas de perspective, pas de
  trois-quarts. La coupe du jeu est vue exactement de côté.
- **Lumière du soleil venant d'en haut à gauche**, ombres douces.
- **Un seul objet par image**, centré, qui remplit le cadre sans être coupé.
- Pour la cohérence, générer toutes les images **dans la même conversation**
  ChatGPT, en commençant par joindre la maquette du niveau 14 comme référence
  de style, puis en demandant à chaque fois « same art style as before ».

Le bloc de style à coller en tête de chaque prompt :

```text
2D casual mobile game asset, hand-painted look with soft cel shading, warm sunny afternoon light from the top-left, clean readable shapes, bright friendly palette, same art style as the reference image (a canal lock puzzle game seen in side cross-section)
```

---

## Branché aujourd'hui

### `art/fond.png` — le panorama derrière le canal

Remplace le bandeau découpé dans la maquette. Au-dessus de la berge, il n'y a
qu'une bande de ciel d'environ 200 px : le jeu ne garde que **la bande entre
34 % et 72 % de la hauteur de l'image** (collines, moulin, maison, villages
au loin), étirée sur toute la largeur de la coupe. Le ciel au-dessus et la
prairie en dessous ne se voient pas. Le premier `fond.png` (6 octobre 2026)
tombe juste : sa prairie commence à 70 %.

```text
[bloc de style] Wide panoramic countryside background for a side-view game, landscape format 3:2. Top half: soft blue sky with a few fluffy clouds. Middle: rolling green hills, a windmill on the far left, a small stone farmhouse with a red tile roof, cypress trees and round trees, distant blue mountains. The bottom third must be a plain, flat green meadow with nothing on it. No water, no canal, no boats, no people, no text, no user interface.
```

### `art/bateau_0.png` — le bateau modèle, que le jeu repeint

**Une seule image suffit : le bateau rouge.** Le jeu le repeint pour les autres
bateaux (jaune, bleu, vert — `REPEINTS` dans `canal.gd`, shader
`shaders/teinte.gdshader`) : seul le rouge VIF change de teinte (coque,
fanion, bande de la cheminée, bouée), le rouge sombre sous la flottaison
reste. Ainsi tous les bateaux ont exactement la même taille.

Pourquoi pas ChatGPT pour les couleurs (essayé le 6 octobre 2026) : il ne
recolorie pas une image, il en redessine une nouvelle qui s'en inspire — la
forme et le cadrage changent à chaque demande, quel que soit le prompt.

Le jeu **recadre l'image sur ses pixels opaques**, cale sa largeur sur la
longueur de coque (le sas fait deux unités : un bateau ne peut pas être plus
long), et pose sur l'eau sa ligne de flottaison, que donne
`art/bateaux.json` : la fraction de la hauteur, depuis le haut, où finit la
bande blanche (0,635 pour le modèle du 6 octobre). À remesurer si l'image
change. **Garder du rouge franc et lumineux** pour la coque et un rouge
sombre pour le dessous : c'est cet écart de luminosité qui dit au shader quoi
repeindre.

**Bateau rouge → `art/bateau_0.png`**

```text
2D casual mobile game asset, hand-painted look with soft cel shading, warm sunny afternoon light from the top-left, clean readable shapes, bright friendly palette, same art style as the reference image (a canal lock puzzle game seen in side cross-section). A small canal tugboat with a DEEP rounded hull, exact side profile facing right, isolated on a transparent background. Proportions: the whole boat (keel to top of the chimney) is about 1.4 times longer than it is tall. The waterline is at mid-height: the dark red-brown antifouling part of the hull below the waterline is as tall as everything above it (colored hull, cabin and chimney together). Above the waterline: hull painted bright red with a white stripe on the waterline, three round portholes, a cream wooden cabin with two blue windows, a black chimney with a red band, a small mast with a red pennant at the stern, a red-and-white life ring on the cabin. The keel touches the bottom edge of the image, the boat fills the width of the image. No water, no shadow, no glow, no text.
```

Les prompts pour le jaune, le bleu et le vert ont été retirés : le jeu fait
ces couleurs lui-même.

---

### Le tirant d'eau : tranché le 6 octobre 2026

**Coque profonde, mais pas trop** (Vincent). Le jeu dessine une unité de
hauteur sur 48 px (une unité de largeur sur 64) : le tirant du moteur fait
44 px sous l'eau pour une coque de 125 px de long, un bon tiers. D'où le
prompt ci-dessus : 1,4 pour 1, flottaison à mi-hauteur. Une image plus plate
est quand même affichée, sa coque plongeant moins que la règle ; Godot écrit
dans sa console de combien (« la coque plonge de 26 px pour un tirant de
44 »). C'est le cas du modèle du 6 octobre, et c'est acceptable : un bateau
qui a assez d'eau flotte avec un peu de marge sous la quille, et un bateau
échoué, posé au fond, paraît un peu enfoncé — ce qui se lit comme coincé.

Pourquoi ce n'est pas un détail : la profondeur d'eau est le cœur des
puzzles. Un bateau réaliste n'enfonce que 10 à 20 % de sa longueur ; avec lui,
un bateau **échoué** (niveaux 1-1, 1-3) semblerait flotter encore dans 30 px
d'eau, et la règle deviendrait illisible. L'autre voie — bateaux réalistes et
tirant réduit dans les niveaux — obligeait à réaccorder tous les niveaux.

### `art/etoile_pleine.png` — l'étoile de score

Pour être fidèle à la maquette (Vincent, 6 octobre 2026) : une étoile
peinte, dodue, aux pointes arrondies. **Une seule image** : le jeu en tire
l'étoile vide en la passant au gris (ChatGPT redessinerait une autre étoile,
d'une autre taille — comme pour les bateaux). Sans image, le jeu dessine des
étoiles arrondies. À faire en joignant la maquette du niveau 14.

```text
2D casual mobile game UI icon, same art style as the reference image (look at the three stars in its top-right corner). A single plump five-pointed star with softly rounded tips, glossy golden-yellow with a warm gradient (light yellow on top, deeper orange-gold at the bottom), a thick dark brown-orange outline, a soft white highlight on the upper left. Front view, centered, square image, the star fills about 90 % of the image, transparent background. No text, no glow, no shadow outside the star.
```

### `art/plaque_bois.png` — les plaques du haut de l'écran

Le numéro du niveau et le compteur de coups sont posés sur des plaques de bois,
comme le « 47 » de la maquette du panneau d'éclusier. Sans image, le jeu
dessine un bois uni (brun, liseré clair) ; avec elle, la plaque est recadrée
et découpée en neuf pour s'étirer à la largeur du texte. Joindre la maquette
du panneau d'éclusier comme référence.

```text
Using the attached image as the exact style reference (look at the wooden badge holding the number "47" in the top-left corner), draw the same wooden badge EMPTY, with no text: a rounded rectangle of warm brown polished wood with a fine grain, a lighter wooden rim all around, soft cel shading and a subtle highlight on top. Wide format about 2:1, the badge fills the image, transparent background, no shadow outside the badge.
```

### `art/medaillon_bois.png` — les boutons ronds du bas de l'écran

Réglages, Annuler et Recommencer sont des médaillons ronds en bois épais,
comme les boutons de l'image d'exemple de Vincent (l'engrenage et la carte en
bas à gauche). Sans image, le jeu les dessine (`relief.gd`). Avec elle, il pose
le médaillon tel quel et dessine lui-même le pictogramme crème au milieu. Le
médaillon doit donc être **vide**. Le jeu le fonce quand on appuie et le pâlit
quand le bouton est indisponible : une seule image suffit.

Joindre l'image d'exemple (le panneau « Passé ! » au coucher du soleil) comme
référence.

```text
Using the attached image as the exact style reference (look at the round wooden buttons in the bottom-left and bottom-right corners, the ones holding a gear and a map), draw ONE of those round wooden buttons EMPTY, with no icon and no symbol at all: a thick circular medallion of warm brown polished wood, seen exactly from the front, slightly from above so that the darker side thickness shows only at the bottom. A very dark brown outline all around, a lighter domed wooden face with fine concentric wood grain rings, a soft highlight on the upper edge, gentle cel shading. Square image, the medallion centred and filling about 90% of the frame, transparent background, no drop shadow outside the medallion, no text.
```

À vérifier en la recevant : **aucun pictogramme** (ChatGPT a tendance à
recopier l'engrenage de la référence), un cercle bien rond et pas ovale, une
face assez unie au centre pour que le pictogramme crème s'y lise, et une vraie
transparence autour (pas de damier peint).

## Le décor de la coupe — pour que tout soit beau (6 octobre 2026)

Vincent veut que la coupe soit aussi belle que la maquette du niveau 14 : la
terre, les pierres des murs, les portes, la roue. Les shaders font un dessin
correct, mais pas peint. Chaque image ci-dessous remplace un dessin.

**Toutes branchées le 6 octobre 2026** par `peint.gd`, qui les charge une fois.
Pour chacune, ce que fait le jeu :
- **terre.png** : en tuiles de 512 px.
- **pierre.png** : recoupée sur un nombre pair de rangées entières (l'image en
  avait 4,7 et la quinconce cassait au raccord), à 36 px par rangée.
- **vantail.png** : posé sur le cadre entier du vantail.
- **traverse.png** : découpée en trois, les bouts ferrés intacts.
- **roue.png** : tourne sur son moyeu.
- **herbe_bord.png** : répétée en largeur, son pied sur le bord.
- **rochers.png** et **pousses.png** : découpées en trois images, semées dans
  la terre hors du trajet des aqueducs.

Sans l'image, le dessin d'avant reprend.

Pour toutes : **une conversation ChatGPT unique**, en joignant d'abord la
maquette du niveau 14 (`art/maquette.webp`), puis le bloc de style en tête de
chaque prompt. Une texture « raccordable » (seamless) doit pouvoir se poser
bord à bord sans couture visible. Si ChatGPT en laisse une, le jeu sait
l'estomper, mais une vraie texture raccordable rend mieux.

### `art/terre.png` — la terre en coupe (raccordable)

Elle couvre tout le bas de l'écran et le tour des bassins. Elle se répète en
damier, donc **pas de gros caillou** dedans (on le verrait revenir) : les
rochers sont une image à part.

```text
Seamless tileable texture of warm reddish-brown soil seen in side cross-section, exactly like the soil under the canal in the reference image: hand-painted soft patches of darker brown and lighter ochre with soft brush strokes, a few tiny pebbles and grains, subtle horizontal layering. No large rocks, no plants, no grass, no roots, no lighting gradient (the same brightness at the top and the bottom). Front view, flat, square 1024×1024, edges must tile seamlessly.
```

### `art/rochers.png` — trois rochers à semer dans la terre

Le jeu les sème lui-même dans la terre, à des tailles variées, avec leur
ombre.

```text
Three separate rounded rocks half-buried in soil style, like the grey-brown rocks embedded in the soil of the reference image: smooth, slightly flattened, warm grey-brown with a soft highlight on the top-left and a darker bottom-right, thin dark outline. Three different shapes and sizes, side by side in a single row with wide empty gaps between them, isolated on a transparent background, no soil around them, no shadow.
```

### `art/pousses.png` — trois petites pousses vertes

```text
Three small separate green sprouts growing from the soil, like the little plants in the soil of the reference image: a tuft of pointed leaves, a two-leaf seedling, and a tiny clover-like plant, bright fresh green with darker bases. Side by side in a single row with wide empty gaps, isolated on a transparent background, no soil, no shadow.
```

### `art/pierre.png` — les pierres taillées des écluses (raccordable)

La même pierre partout : les tours des portes, les radiers sous l'eau, les
parements des berges, et le mur du fond derrière l'eau (le jeu l'assombrit).
Un appareil régulier de blocs, pour que les joints tombent juste en bord de
bassin.

```text
Seamless tileable texture of light sandstone masonry exactly like the beige stone blocks around the lock basins in the reference image: rectangular blocks twice as wide as high laid in a running bond, warm beige and cream with slight variations from block to block, softly bevelled edges (lit top-left, shaded bottom-right), thin darker mortar joints, a few subtle cracks and tiny chips, no moss. Front view, flat, no perspective, exactly 4 rows of blocks, square 1024×1024, edges must tile seamlessly.
```

### `art/vantail.png` — la porte de l'écluse

Le vantail est **étroit et haut** (environ 1 de large pour 6 de haut) et sa
hauteur change d'un niveau à l'autre. Le jeu étire donc le milieu et garde
intacts le haut et le bas. Il faut des ferrures régulières, pas un motif
unique au centre.

```text
A wooden canal lock gate leaf seen exactly from the front, like the wooden gates with dark iron bands in the reference image: vertical oak planks in warm brown, a dark iron strap across the top and across the bottom, and evenly spaced dark iron bands with rivets in between, a slightly darker wooden frame on the left and right edges. Very tall and narrow rectangle, ratio 1:6, filling the image, isolated on a transparent background, no shadow, no hinges, no handle.
```

### `art/traverse.png` — la poutre du portique

La poutre horizontale en haut de la porte, où le vantail levé vient se
ranger. Le jeu l'étire en largeur.

```text
A heavy horizontal wooden beam reinforced with dark iron plates and big rivets at both ends, seen exactly from the front, like the wooden and iron parts of the lock gates in the reference image. Long thin rectangle, ratio about 6:1, filling the image, isolated on a transparent background, no shadow.
```

### `art/roue.png` — la roue de manœuvre

Le jeu la fait tourner : elle doit être **vue de face, parfaitement ronde et
centrée**, sans axe ni support (le jeu dessine la tige).

```text
A red cast-iron valve handwheel seen exactly from the front, like the red wheels on top of the lock gates in the reference image: a thick round rim with small knobs, six spokes, a central hub with a bolt, glossy red paint with a dark outline and a soft highlight on the top-left. Perfectly circular and centred, square image, isolated on a transparent background, no stem, no support, no shadow.
```

### `art/herbe_bord.png` — le bord d'herbe (raccordable en largeur)

Il ourle le haut des berges et des murs, et retombe un peu sur la terre,
comme sur la maquette.

```text
A horizontal strip of grass edge seen exactly from the side, like the grassy top of the canal banks in the reference image: a lush band of bright green grass with a few tiny white and yellow flowers, the top edge made of irregular grass blades, the bottom edge hanging slightly with a few short roots. Long horizontal strip, ratio about 8:1, tileable seamlessly from left to right, isolated on a transparent background, no soil, no shadow.
```

### `art/bouee.png` — la destination d'un bateau (lot 3 de PLAN-RENDU.md)

Vincent a choisi la bouée pour remplacer la coque en pointillés. Elle flotte à
la place visée et suit l'eau. Comme le bateau, elle est peinte **en rouge** :
le jeu la repeint en jaune, bleu ou vert pour les autres bateaux. Le blanc
reste blanc.

```text
Same art style as before. A small canal marker buoy seen exactly from the side, like a toy: a rounded red float with one broad white horizontal band, a short dark mast on top carrying a small red triangular pennant, thin dark outline, soft highlight on the top-left. The lower third of the float is where it will sit in the water. Square image, the buoy centred and filling about 80% of the height, isolated on a transparent background, no water, no reflection, no shadow.
```

### `art/planche.png` — une planche de hausse (chapitre 3)

Les hausses sont des planches empilées entre deux poteaux, que l'on retire ou
que l'on remet. Le jeu les dessine ; l'image remplacera chaque planche de la
pile (vue de sa face, en biais comme le vantail).

```text
Same art style as before. One single thick wooden plank used to dam a canal (a stop log), seen exactly from the front: a long horizontal board of warm brown oak with a visible grain, slightly rounded edges, a dark iron strap at each end with two rivets, thin dark outline, soft highlight on the top edge. Long horizontal rectangle, ratio about 4:1, filling the image, isolated on a transparent background, no shadow.
```

### `art/maison.png` — une maison du village à épargner (chapitre 3)

Le village est un bassin sec qu'il ne faut pas inonder. Le jeu y dessine deux
maisons simples ; l'image les remplacera (une seule image, posée deux fois,
la seconde retournée et un peu plus petite).

```text
Same art style as before, like the stone cottage in the background of the reference image. A small cosy village cottage seen exactly from the front: cream stone walls, a red tiled roof, a wooden door, two small windows with blue shutters, a little chimney, a few flowers at the foot of the wall. Square image, the cottage centred and filling about 85% of the frame, isolated on a transparent background, no ground, no shadow.
```

### La rigole du chapitre 3 (7 octobre 2026)

D'après l'image cible validée par Vincent : la berge est une butte d'herbe
entre le bassin du haut et une mare naturelle, une pelle plantée et le tracé
de la rigole en pointillés invitent à creuser. Trois images, dans la même
conversation, en joignant cette image cible.

#### `art/pelle.png` — la pelle plantée dans la berge

```text
Same art style as the attached image. A single garden spade standing upright, as if stuck in the ground at a slight angle: a worn wooden handle with a T-grip, a dark iron blade with a little earth on it, thin dark outline, soft highlight on the top-left. The lower part of the blade is where it enters the ground. Tall portrait image, the spade centred and filling about 90% of the height, isolated on a transparent background, no ground, no shadow.
```

#### `art/roseaux.png` — une touffe de roseaux, pour les bords de la mare

```text
Same art style as the attached image. One clump of pond reeds and bulrushes: long thin green leaves, three or four brown cattail heads on tall stems, a few shorter blades at the base, thin dark outline, soft cel shading. Portrait image, the clump centred and filling about 90% of the height, isolated on a transparent background, no water, no ground, no shadow.
```

#### `art/nenuphar.png` — un nénuphar, posé sur la mare

```text
Same art style as the attached image. A single water lily pad seen from slightly above, flat and round with its little notch, glossy green with lighter veins, and one small white and pink lily flower on it, thin dark outline. Square image, centred, filling about 80% of the frame, isolated on a transparent background, no water, no shadow.
```

### L'habillage du 3-1 (7 octobre 2026)

D'après la seconde image cible de Vincent (le 3-1 retravaillé par ChatGPT) :
la même scène, habillée. Trois images, à semer par le jeu.

#### `art/buisson.png` — un buisson fleuri

```text
Same art style as the attached image. One small rounded bush with green leaves and a few small pink, white and yellow flowers, like the flowery bushes around the pond and the cottages in the reference. Square image, the bush centred and filling about 85% of the frame, isolated on a transparent background, no ground, no shadow.
```

#### `art/cloture.png` — un tronçon de clôture de bois

```text
Same art style as the attached image. A short section of a rustic wooden fence seen exactly from the front, like the fences in the reference: three posts and two horizontal rails, weathered brown wood, thin dark outline. Long horizontal image, ratio about 3:1, the fence filling the image, tileable left to right, isolated on a transparent background, no ground, no shadow.
```

#### `art/arbre.png` — un arbre, près du village

```text
Same art style as the attached image. One round leafy deciduous tree, like the tree next to the cottages in the reference: a short brown trunk and a full, round, bright green crown with soft shading. Portrait image, the tree centred and filling about 90% of the height, isolated on a transparent background, no ground, no shadow.
```

### Plus tard, peut-être

- `premier_plan.png` : un buisson flou et des marguerites au premier plan,
  dans un coin, comme sur la maquette. Ça donne de la profondeur, mais ça
  gênerait les boutons : à voir une fois le reste en place.
- Les aqueducs : ce sont des tracés qui tournent, avec de l'eau animée
  dedans. Une image s'y plie mal, ils restent dessinés.

## Ce qu'il faut regarder en recevant une image

- Le **profil strict** : une proue en trois-quarts se verra tout de suite à
  côté des murs vus de face.
- La **transparence réelle** : ChatGPT livre parfois un damier peint dans
  l'image au lieu d'un vrai canal alpha.
- La **teinte** contre la maquette : l'eau du jeu est turquoise et saturée,
  un bateau trop pâle y disparaît.
