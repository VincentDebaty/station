# Écluses — plan de la mise en scène

D'après l'analyse graphique que Vincent a fait faire le 6 octobre 2026, sur
une capture du niveau 1-4. Son constat de fond : **les images, une à une, sont
désormais plus finies que leur assemblage**. Le prochain gain ne viendra pas
de nouvelles images, mais de la mise en scène dans Godot : ombres,
superpositions, petites irrégularités et profondeur.

## Les règles du chantier

- **La lecture du puzzle passe d'abord.** On doit toujours voir d'un coup
  d'œil :
  - où va chaque bateau ;
  - le niveau de chaque eau ;
  - si une porte est ouverte ou fermée ;
  - où passe l'eau.
  Une irrégularité qui brouille l'un de ces points est retirée.
- **Rendu seulement.** Le moteur ne change pas. L'oracle doit rester vert
  (`godot --headless --path prototypes/ecluses-godot --script res://oracle.gd`).
- **Chaque lot se vérifie** par des photos à la taille de l'iPhone, avant et
  après, puis sur l'iPhone lui-même avec le compteur d'images par seconde
  (environ 100 aujourd'hui). Un lot qui le fait tomber sous 60 est revu.
- **Du code d'abord.** On ne demande une image à ChatGPT que là où le dessin
  ne tient pas la comparaison.

## Les lots, dans l'ordre proposé

Les numéros entre crochets renvoient aux cinq priorités de l'analyse.

### 1. Les ombres de contact [2] — code

- **Portes :**
  - une ombre d'occlusion, en dégradé, de chaque côté du vantail, contre les
    tours ;
  - le mur visible dans l'ouverture, derrière la porte, nettement plus sombre ;
  - un liseré sombre le long des tours, qui donne l'impression d'une rainure
    où le vantail coulisse.
- **Murs :** une ombre dans les angles intérieurs des bassins, et au pied des
  tours sur le radier.
- **Tuyaux :** une ombre portée sur la terre (le tracé repris en sombre, décalé
  vers le bas à droite, flou) et une ombre de contact là où ils sortent de la
  pierre.

Fichiers : `porte.gd`, `canal.gd`, `aqueduc.gd`.

### 2. La profondeur de l'eau [3] — code

Dans `shaders/eau.gdshader` :
- un dégradé plus franc, de l'eau claire en surface au bleu profond au fond ;
- deux ou trois ondulations claires, horizontales, qui glissent juste sous la
  surface ;
- une mince ligne claire au contact des parois de pierre, à gauche et à droite
  du bassin ;
- la paroi du fond, vue à travers l'eau, plus bleutée et plus sombre.

Le grand bassin de droite du 1-4 sert de juge : il ne doit plus ressembler à un
rectangle bleu posé devant le décor.

### 3. Les destinations [1] — décision de Vincent, puis code (et une image)

Aujourd'hui, une coque en pointillés et un fanion, à la couleur du bateau. Ça
se lit très bien, mais ça fait calque de mise au point.

Une contrainte : le joueur ne sélectionne jamais un bateau, il touche les
roues. « Montrer la cible au survol, ou quand le bateau est choisi » n'existe
donc pas sur l'iPhone.

Les pistes :
- **A — une bouée à la couleur du bateau** (recommandée). Elle flotte à la
  place visée, monte et descend avec l'eau, et plonge en saluant quand le
  bateau arrive. Il faut une image : `bouee.png`, blanche, que le shader de
  teinte repeint comme les bateaux. D'ici là, une bouée dessinée.
- **B — deux fanions reliés par une corde**, plantés sur la margelle au-dessus
  de la place. Pas d'image nécessaire.
- **C — garder la silhouette**, mais beaucoup plus légère : un trait plein,
  très transparent, sans pointillés, plus le fanion.

### 4. Casser la grande masse rectangulaire [4] — code, une image peut-être

- **Couronnement :** une rangée de pierres plus claires, qui déborde de
  quelques pixels, en haut de chaque mur, avec un sommet un peu irrégulier (une
  pierre sur cinq légèrement plus haute ou plus basse). Avec `pierre.png`
  d'abord ; une image `couronnement.png` si ça ne suffit pas.
- **Les trois portiques :** chacun de sa hauteur (+0 / +0,3 / +0,15 unité,
  jamais plus bas, car le vantail levé doit pouvoir s'y ranger). Cela casse
  les trois colonnes identiques.
- **Contreforts et décrochements :** seulement sur les bords extérieurs de la
  maçonnerie, jamais dans l'eau, pour que les niveaux se lisent toujours sur
  un mur droit.
- **Plus tard :** un mécanisme secondaire (un contrepoids, un engrenage) sur
  une seule porte.

### 5. Masquer la répétition de la terre et de l'herbe [5] — code, puis images si besoin

- **Terre :** le shader découpe le sol en grandes cellules d'environ 400 px.
  Chaque cellule prend la tuile décalée et retournée au hasard, avec un fondu
  sur les bords, plus une teinte qui varie lentement à grande échelle. La
  répétition devrait disparaître sans nouvelle image.
- **Herbe :** chaque tronçon est décalé et retourné au hasard.
- **Si ça ne suffit pas :** des variantes `terre_b.png`, `terre_c.png`,
  `herbe_bord_b.png`, etc. (prompts à écrire).

### 6. Les chaînes sous les roues — code

Les suites de petits points font collier de perles. À la place, une vraie
chaîne :
- des maillons ovales, de 8 à 10 px, alternés de face et de profil ;
- gris acier, avec un reflet ;
- deux ou trois maillons bien visibles plutôt que vingt points.

Une image `chaine.png` seulement si le dessin ne convainc pas.

### 7. Les tuyaux — code

- On garde la forme, qui se lit très bien.
- Un bleu moins cyan, tirant vers l'ardoise.
- Des brides plus épaisses avec leurs boulons.
- Un léger grain peint sur l'enveloppe.
- L'ombre de contact (lot 1).

### 8. L'arrière-plan et le moulin — code

- Le panorama : environ 15 % de saturation et de contraste en moins, et une
  brume bleutée qui monte vers les montagnes. Les éléments jouables
  ressortent sans devenir criards.
- Le moulin coupé par le haut de l'écran : le jeu découpe une bande de
  `fond.png` (34 % à 72 % de sa hauteur). On la remonte ou on l'élargit pour
  qu'il entre en entier.

### 9. L'interface — code

- Les étoiles du haut un peu plus petites et un peu moins jaunes.
- Le compteur d'images par seconde : visible seulement quand le panneau
  Réglages est ouvert. Il reste utile tant qu'on mesure.
- Le panneau Réglages reste clair : c'est un outil de test, qui disparaîtra.

### 10. La micro-vie et la façade — code

- **Pousses et cailloux :** plus nombreux près des constructions, de plus en
  plus rares en s'éloignant, au lieu d'être semés partout pareil.
- **Trace d'humidité :** sur le mur du fond, une bande plus sombre du fond du
  bassin jusqu'au plus haut que l'eau puisse y monter, avec une fine ligne de
  dépôt clair à cette hauteur. C'est vrai dans une écluse, et ça raconte les
  niveaux.
- **La façade :** deux ou trois taches de pierre plus foncée et une ou deux
  fissures, très discrètes.

## Les images à demander

Seulement si le code ne suffit pas, sauf la bouée :

| Image | Lot | Quand |
|---|---|---|
| `bouee.png` | 3 | si Vincent choisit la bouée |
| `couronnement.png` | 4 | si la pierre recoupée ne suffit pas |
| `chaine.png` | 6 | si la chaîne dessinée ne convainc pas |
| `terre_b/c.png`, `herbe_bord_b/c.png` | 5 | si la répétition se voit encore |

## Fait en chemin : un bateau coincé dit pourquoi

Le 6 octobre 2026, Vincent se trouvait « bloqué alors que cela semble être le
contraire » : porte levée, eaux égales, bateau immobile. Le bief d'arrivée n'avait
plus assez de fond. La pancarte nomme maintenant la raison (eau qui manque,
face-à-face). Quand c'est l'eau, la coupe montre le niveau qu'il aurait fallu.

Piste à décider, pour prévenir plutôt qu'expliquer : une **échelle de
navigation** sur le mur de chaque bassin, c'est-à-dire un trait peint au
niveau minimal qui porte un bateau. Quand l'eau descend sous le trait, on le
voit avant qu'il soit trop tard.

## Où on en est

- [x] 1. Ombres de contact (6 octobre 2026)
- [x] 2. Profondeur de l'eau (6 octobre 2026)
- [x] 3. Destinations — bouée dessinée (6 octobre 2026) ; `art/bouee.png` la remplacera
- [x] 4. Masse rectangulaire (6 octobre 2026 ; reste le mécanisme secondaire, « plus tard »)
- [x] 5. Répétition terre / herbe (6 octobre 2026, sans nouvelle image)
- [x] 6. Chaînes (6 octobre 2026 : maillons accrochés au vantail, qui montent avec lui)
- [ ] 7. Tuyaux
- [ ] 8. Arrière-plan et moulin
- [ ] 9. Interface
- [ ] 10. Micro-vie et façade
