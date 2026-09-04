# Les polices

Deux familles, toutes deux sous **licence SIL Open Font 1.1** (le texte de la
licence est à côté, `*-OFL.txt`) : redistribution libre, y compris dans une
application commerciale, à condition de ne pas les vendre seules et de garder
la licence. Elles sont donc livrées AVEC l'application — sur iOS, une police
système ne se redistribue pas, et il n'y a pas de serveur de polices.

| Fichier | Famille | Où elle sert |
|---|---|---|
| `Cinzel.ttf` | Cinzel (Natanael Gama) | les titres et les petites capitales — nom de chapitre, nom de gare, boutons, compteurs |
| `EBGaramond.ttf` | EB Garamond (Octavio Pardo) | le texte courant — la phrase d'une gare, les libellés, les mesures |

Les deux sont **variables** : un seul fichier porte toutes les graisses, et
`FontVariation` en tire le gras sans charger un second fichier.

Choisies le 4 septembre 2026 pour la direction artistique de carte
ferroviaire ancienne (voir `PORTAGE-GODOT.md`). Cinzel est une capitale
romaine lapidaire — c'est elle qui donne à l'écran son air de gravure ; EB
Garamond est une Garamond d'usage, lisible en petit corps sur un téléphone.

Le poste d'aiguillage, lui, garde une police à chasse fixe pour l'horloge et
les badges : une heure se lit mieux quand ses chiffres ne bougent pas de
largeur (`Sty.mono`, police système).
