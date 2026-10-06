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

Remplace le bandeau découpé dans la maquette. Il est étiré sur toute la
largeur de la coupe, son bas posé juste sous la berge : **seule la moitié
haute compte** (ciel, collines, quelques bâtiments au loin), la moitié basse
est cachée par la prairie et les murs.

```text
[bloc de style] Wide panoramic countryside background for a side-view game, landscape format 3:2. Top half: soft blue sky with a few fluffy clouds. Middle: rolling green hills, a windmill on the far left, a small stone farmhouse with a red tile roof, cypress trees and round trees, distant blue mountains. The bottom third must be a plain, flat green meadow with nothing on it. No water, no canal, no boats, no people, no text, no user interface.
```

### `art/bateau_0.png`, `bateau_1.png`, `bateau_2.png` — les bateaux

Un fichier par bateau du niveau, dans l'ordre du JSON : 0 rouge, 1 jaune,
2 bleu (3 vert). L'image est posée **quille en bas du cadre**, et sa largeur
vaut 1,12 fois la longueur de coque. La ligne de flottaison tombera donc là
où le tirant d'eau la met : il faut que la coque soit **dessinée en entier,
y compris sous l'eau**.

```text
[bloc de style] A small canal tugboat, exact side profile facing right, isolated on a transparent background. Hull painted bright RED above the waterline, dark brown-red antifouling paint below it, a white stripe, three round portholes, a cream wooden cabin with two blue windows, a black chimney with a red band, a small mast with a red pennant at the stern, a red-and-white life ring on the cabin. The whole hull is visible, including the part that sits underwater. The keel touches the bottom edge of the image, the boat fills the width of the image. No water, no shadow on the ground, no text.
```

Pour les autres, remplacer RED / red par YELLOW / yellow, puis BLUE / blue
(une péniche plus longue et plus basse pour le bleu : « a long low canal
barge » au lieu de « a small canal tugboat », avec des caisses en bois sur le
pont).

---

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
