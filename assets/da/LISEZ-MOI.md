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

## La voiture gravée (le dessin des convois)

`wagon.png` — une voiture de chemin de fer vue **strictement du dessus**, au
trait, à l'encre noire sur fond blanc, sans couleur ni aplat gris.

Le jeu la découpe en **trois tranches** : la ferrure de tête, une section
centrale répétée autant de fois qu'il y a de voitures, et la ferrure de queue.
C'est ce qui permet à une rame de deux voitures et à une rame de six d'avoir
le même rythme de nervures — et c'est pour cela que les deux extrémités du
dessin doivent porter leurs tampons et leurs robinets, et la partie centrale
un motif qui se répète sans accident.

Le noir devient l'encre, le blanc prend la couleur de destination : une seule
planche sert les six teintes du jeu.

## Deux règles qui font gagner du temps

**Aucun texte dans l'image.** Les générateurs écrivent du faux latin, et le
jeu pose ses propres libellés par-dessus.

**Le style se tient d'une image à l'autre** : générer la première, puis
demander les suivantes « dans le même style que l'image précédente ».
