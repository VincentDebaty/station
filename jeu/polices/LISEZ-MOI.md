# Les polices

Quatre fichiers, tous sous **licence SIL Open Font 1.1** (le texte de la licence
est à côté, `*-OFL.txt`) : redistribution libre, y compris dans une application
commerciale, à condition de ne pas les vendre seules et de garder la licence.
Elles sont livrées AVEC l'application — sur iOS, une police système ne se
redistribue pas, et il n'y a pas de serveur de polices.

| Fichier | Famille | Où elle sert |
|---|---|---|
| `CormorantGaramond.ttf` | Cormorant Garamond (Christian Thalmann) | **l'identité** — noms de gare et de destination, numéros de quai, boutons, compteurs, titres de chapitre |
| `EBGaramond.ttf` | EB Garamond (Octavio Pardo) | le texte courant — la phrase d'une gare, les libellés, les mesures |
| `SpaceMono.ttf` / `-Bold` | Space Mono (Colophon Foundry) | **l'information de jeu** — l'horloge, le retard, les heures de départ |
| `Cinzel.ttf` | Cinzel (Natanael Gama) | plus utilisée — gardée le temps que la nouvelle identité se confirme |

## La séparation, et pourquoi elle tient

**Cormorant dit l'univers, Space Mono dit l'information.** Ce qui est gravé sur
une plaque — un nom de gare, un numéro de quai — appartient à une compagnie de
chemin de fer britannique du XIXᵉ siècle. Ce qui se lit d'un coup d'œil et
change à chaque minute — l'heure, le retard — appartient au tableau de contrôle.
Deux mondes, deux dessins.

**Pourquoi Cormorant et non Cinzel** (9 septembre 2026, sur la maquette de
Vincent) : Cinzel est une capitale romaine LAPIDAIRE, qui donne un air de
monument. Cormorant est plus fine, légèrement irrégulière, et surtout elle a une
VRAIE bas-de-casse là où Cinzel n'a que des petites capitales — « Sheffield »
s'écrit Sheffield, et non SHEFFIELD en deux tailles.

**Cormorant est FINE**, et cela se paie : à taille égale elle pèse bien moins
que la lapidaire qu'elle remplace. Les numéros de quai sont passés de 24 en
sans à 31 en Cormorant 700 pour tenir la même présence sur le plan.

## Les cotes de la maquette

Relevées par Vincent le 9 septembre 2026. Une unité de viewport vaut un pixel
sur l'iPhone (1652 unités pour une maquette large de 1670) :

| Élément | Police | Taille | Interlettrage |
|---|---|---|---|
| nom de destination | Cormorant SemiBold, capitales | 17 × `UIK` (25,5) | 2,6 × `UIK` |
| horloge | Space Mono Regular | 24 × `HUD_K` (46,3) | 1,05 × `HUD_K` |

## Le gras synthétique, et pourquoi il a fallu y venir

« Il faudrait épaissir un peu la typo, c'est trop fin » (Vincent, 9 septembre
2026). Monter la graisse ne suffisait pas : l'axe `wght` de Cormorant va de
**300 à 700 seulement**, et à 700 elle pèse encore moins que la lapidaire
qu'elle remplace — elle est dessinée fine. `FontVariation.variation_embolden`
épaissit le TRACÉ lui-même, ce qu'aucune graisse ne peut faire au-delà du
dessin de la fonte.

Deux valeurs plutôt qu'une : **0,13 pour l'identité**, qui porte des capitales
espacées en grand et réclame un tracé franc ; **0,06 pour le texte courant**,
écrit en petit corps sur un téléphone, où trop d'épaisseur boucherait les
contre-formes. Choisies en comparant quatre valeurs à l'écran (0,00 · 0,04 ·
0,08 · 0,13). `STATION_GRAS=<x>` les force toutes deux, pour comparer sans
recompiler.

Space Mono n'en reçoit pas : elle n'est pas variable, et le Bold est un
fichier.

## Deux remarques techniques

Cormorant Garamond et EB Garamond sont **variables** : un seul fichier porte
toutes les graisses, et `FontVariation` en tire le gras. Space Mono ne l'est
pas — deux fichiers, Regular et Bold, et `Sty.mono` choisit par la graisse
demandée (seuil à 650).

Les chiffres de Space Mono et d'EB Garamond sont **tabulaires** ; ceux de
Cormorant ne le sont pas (de 14 à 24 unités, 42 % d'écart, mesuré). Une horloge
en Cormorant tressauterait à chaque minute : c'est pour cela qu'elle est en
Space Mono, et non par goût.
