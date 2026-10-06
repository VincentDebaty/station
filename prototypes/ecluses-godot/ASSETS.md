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

## Pas encore branché — à faire quand le style sera validé

Ces éléments sont dessinés par des shaders aujourd'hui. Ils deviendront des
images quand on passera à la production ; je n'écris pas le code de
chargement tant qu'on n'a pas une image qui tient la comparaison.

| Fichier | Ce que c'est | Prompt (après le bloc de style) |
|---|---|---|
| `pierre.png` | les blocs de pierre des murs, **en motif raccordable** | `Seamless tileable texture of light sandstone blocks laid in a running bond, warm beige, soft bevels, thin mortar joints, front view, square 1024×1024, no perspective.` |
| `terre.png` | la terre en coupe, raccordable | `Seamless tileable texture of brown soil cross-section with small rounded pebbles and faint layers, front view, square 1024×1024.` |
| `vantail.png` | une porte d'écluse fermée | `A wooden canal lock gate leaf seen exactly from the front: vertical oak planks, three black iron bands with rivets, tall rectangle about 1:5, isolated on transparent background.` |
| `roue.png` | la roue de manœuvre | `A red cast-iron valve handwheel with six spokes and a central hub, seen exactly from the front, isolated on transparent background, square.` |
| `prairie.png` | la pente herbue derrière les bassins, raccordable | `Seamless tileable texture of a grassy meadow seen from the side, short grass with a few tiny white and yellow flowers, front view, square 1024×1024.` |

## Ce qu'il faut regarder en recevant une image

- Le **profil strict** : une proue en trois-quarts se verra tout de suite à
  côté des murs vus de face.
- La **transparence réelle** : ChatGPT livre parfois un damier peint dans
  l'image au lieu d'un vrai canal alpha.
- La **teinte** contre la maquette : l'eau du jeu est turquoise et saturée,
  un bateau trop pâle y disparaît.
