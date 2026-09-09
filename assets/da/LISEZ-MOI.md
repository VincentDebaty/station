# Les illustrations de la direction artistique

Déposer ici les images générées, **exactement sous ces noms** — l'intégration
les cherche par nom, il n'y a rien d'autre à faire.

## Les bannières de zone (une par région de la carte Europe)

| Fichier | Zone (`data/cartes/europe.json`) |
|---|---|
| `banniere-atl.png` | L'Atlantique et l'Ibérie |
| `banniere-alpes.png` | L'arc méditerranéen et les Alpes |
| `banniere-rhin.png` | Le Benelux et le Rhin |
| `banniere-ger.png` | La Germanie |

Format demandé au générateur : **1536 × 1024** (paysage). Le jeu en recadre la
bande médiane ; c'est pourquoi la consigne impose un sujet centré en hauteur.

## Les vignettes de gare (attribuées par le profil de la fiche)

`gare-viaduc.png`, `gare-cathedrale.png`, `gare-industrielle.png`,
`gare-port.png`, `gare-halte.png`, `gare-monumentale.png`

Format : **1024 × 1024**. Fond de parchemin uni, pas de transparence — le jeu
pose lui-même le cadre et l'arrondi.

## Les trois véhicules gravés (le dessin des convois)

`loco.png`, `wagon.png`, `fourgon.png` — vus **strictement du dessus**, au
trait, encre noire sur fond blanc, sans couleur ni aplat gris. Le véhicule est
COUCHÉ, sa longueur de gauche à droite, et pour la machine la **cheminée à
gauche** : le jeu pose la planche avec son bord gauche du côté de la tête.

**Les proportions sont imposées par le gril**, pas par le goût. Une case fait
35 sur 30 unités.

| Fichier | Occupe | Proportion à dessiner |
|---|---|---|
| `loco.png` | une case | 7 pour 6 — trapue |
| `fourgon.png` | une case | 7 pour 6 — trapue |
| `wagon.png` | DEUX cases | 7 pour 3 — allongée |

**Pourquoi un fourgon.** Une voiture posée sur deux cases est mieux
proportionnée, mais une machine plus un nombre pair de cases ne couvre pas
tous les convois : mesuré sur les tirages des 401 fiches, **55 % d'entre eux
laissent une case impaire**. Le fourgon la prend. Un convoi de deux voitures
montre une machine et un fourgon ; de trois, une machine et une voiture ; de
quatre, une machine, une voiture et un fourgon. C'est une composition de train
réelle, pas un rattrapage.

**Deux consignes tirées des premières planches.** Pas de motif unique au
centre — une valve isolée oblige à décaler les découpages. Et le même trait
pour les trois : elles seront côte à côte dans la même rame.

Le noir devient l'encre, le blanc prend la couleur de destination : une seule
planche sert les six teintes.

## Deux règles qui font gagner du temps

**Aucun texte dans l'image.** Les générateurs écrivent du faux latin, et le
jeu pose ses propres libellés par-dessus.

**Le style se tient d'une image à l'autre** : générer la première, puis
demander les suivantes « dans le même style que l'image précédente ».

## Les deux séries de véhicules, et la silhouette

`loco.png`, `wagon.png`, `fourgon.png` sont vues **de haut** : c'est le poste,
qui est un plan d'aiguillage. `loco-profil.png`, `wagon-profil.png`,
`fourgon-profil.png` sont des **élévations**, dessinées le 9 septembre 2026
pour une tentative de vue oblique — abandonnée le jour même — et gardées parce
qu'elles servent à l'écran d'attente, où un train de côté vaut mieux qu'un
toit. La dérivation traite les six d'un même mouvement.

`silhouette.png` est un cas à part : une **découpe pleine**, noir sur blanc,
sans aucun détail intérieur — la ville qu'on devine au bas du pupitre. Elle
n'est pas traitée comme une gravure : la chaîne y garde la silhouette dans
l'alpha et met le RVB à BLANC, si bien que la couleur donnée au dessin sort
exactement telle qu'on la demande. Une découpe n'a pas de trait à préserver,
elle n'a qu'un contour.
