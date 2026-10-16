# Billes — consigne de mockups pour ChatGPT

Une consigne à coller dans ChatGPT (génération d'images) pour obtenir des
mockups de niveaux du prototype `prototypes/prototype-billes.html`, avec un
meilleur visuel et des mécanismes plus riches.

Retour de Vincent du 16 octobre 2026 sur le prototype : « ça fonctionne mais
cela reste très simple et pas forcément très fun. Le côté fun sera les
différents mécanismes, un peu comme dans Écluses. »

Deuxième retour, sur la première planche des mécanismes (jouet en bois vu de
face, panneau d'érable, laiton) : « cela fait trop jeu en bois, pas jeu
mobile ». Les mécanismes y étaient lisibles (flèches d'entrée et de sortie,
motifs des billes, bascule et tourniquet en deux états) : on garde ce
vocabulaire et ce format de planche, on change la direction artistique.

Usage :
1. Joindre une capture du prototype (niveau 7 ou 8, en portrait) : elle donne
   la mise en page, pas le style.
2. Coller la consigne ci-dessous.
3. Demander les images **une par une** dans la même conversation, en
   commençant par la planche des mécanismes : c'est elle qui fixe le style que
   les niveaux reprendront.

Les images sont des **intentions**, pas des règles. Chaque mécanisme retenu
devra recevoir une règle discrète dans le moteur, et passer
`node tools/billes-banc.mjs` avant d'entrer dans un niveau.

---

## Message de correction, dans la conversation déjà ouverte

Si la conversation avec la planche en bois est encore ouverte, coller
seulement ceci (sinon, repartir de la consigne complète ci-dessous, déjà
corrigée) :

```text
Les mécanismes sont très bien : lisibles, avec leurs flèches, leurs deux états et les motifs des billes. Garde exactement ce vocabulaire et ce format de planche. Mais c'est trop « jouet en bois », et je veux un JEU MOBILE.

Refais la même planche dans ce style :
- une illustration 2D stylisée de jeu mobile premium (le niveau de finition de Cut the Rope, Where's My Water? ou Two Dots, sans les copier) : formes simples et arrondies, aplats et modelé doux, contours nets, ombre portée courte ;
- AUCUN bois, aucun grain, aucune vis, aucun laiton réaliste, aucune texture photographique ;
- un fond uni clair (crème ou bleu-gris très pâle), sans atelier derrière ;
- des mécanismes trapus en tons neutres (blanc cassé, gris bleuté, pivots et engrenages couleur or), pour que les seules couleurs vives soient les billes, les godets et les trieurs ;
- des billes grosses et brillantes comme des bonbons, avec un reflet net, et toujours leur motif (spirale, uni, points, rayures) ;
- une typographie ronde et grasse de jeu mobile.

Ensuite seulement, on passera aux écrans de niveau, dans ce nouveau style.
```

## La consigne complète

```text
Tu es directeur artistique d'un petit jeu mobile de puzzle. Je veux des MOCKUPS d'écran de jeu (images), pas du code.

LE JEU (pour comprendre ce que tu dessines)
« Billes d'aiguillage » : un jeu de puzzle pour iPhone, en portrait. En haut de l'écran, un réservoir en tube de verre contient une file de billes de couleur, dans un ordre imposé. Elles tomberont une à une. Avant de les lâcher, le joueur pose des pièces sur un panneau vertical percé d'emplacements (une grille de 5 colonnes sur 4 à 6 rangées). Puis il appuie sur « Lâcher » et regarde : chaque bille roule, tombe, est déviée par les mécanismes, et doit finir dans le godet de SA couleur, en bas de l'écran. Une bille dans le mauvais godet, et c'est raté. Le plaisir vient de la mécanique : voir une machine qu'on a construite fonctionner, comme une machine de Rube Goldberg.

DIRECTION ARTISTIQUE
- Un JEU MOBILE premium, pas un jouet : une illustration 2D stylisée, aux formes simples et arrondies, avec des aplats et un modelé doux (un dégradé léger, un reflet, une ombre portée courte). La finition des bons jeux de puzzle mobiles grand public, du niveau de Cut the Rope, Where's My Water? ou Two Dots : à prendre comme niveau d'exigence, pas comme modèle à copier.
- Aucune matière réelle : ni bois, ni grain, ni vis, ni texture photographique. Pas de vue en perspective 3/4 : de face, presque à plat.
- Le plateau est un grand panneau aux coins très arrondis, d'une couleur claire et calme (crème, bleu-gris pâle ou lavande pâle selon le chapitre), posé sur un fond coloré. Les emplacements vides sont des alvéoles rondes, légèrement creusées, bien visibles.
- Les mécanismes ont des formes trapues et lisibles, avec un contour net. Ils sont dans des tons neutres (blanc cassé, gris bleuté, avec des pivots et des engrenages couleur or), pour que les seules couleurs vives de l'écran soient les billes, leurs godets et les trieurs.
- Les billes sont grosses et brillantes, comme des bonbons (un reflet blanc net), en quatre couleurs franches et très distinctes : rouge, bleu, jaune, vert. Chacune porte AUSSI un motif simple (rouge : une spirale ; bleu : uni ; jaune : des points ; vert : des rayures), pour rester lisible par un daltonien.
- Les godets du bas sont des réceptacles arrondis, de la couleur attendue et avec le même motif. Une colonne sans godet est un trou sombre, barré d'une petite croix.
- Chaque chapitre a son décor de fond, flou et doux, qui ne vole pas l'attention : un atelier lumineux, une salle des machines, une horlogerie, une fête foraine.
- Du mouvement et des retours visibles, comme dans un vrai jeu : une traînée derrière les billes rapides, de petites étincelles quand une bille tombe dans le bon godet, un halo sur la pièce qu'on est en train de poser.
- La LISIBILITÉ passe avant la beauté : on doit comprendre chaque mécanisme et son état (de quel côté penche une bascule, si une trappe est ouverte ou fermée) sans lire un mot. Les pièces fournies par le niveau (fixes) sont plus sombres et portent un petit cadenas. Celles posées par le joueur sont claires.
- À éviter : le bois, le jouet artisanal, les néons, le photoréalisme, les personnages ou mascottes, les logos, le texte décoratif, les écrans surchargés.

ÉCRAN (le même cadre pour tous les mockups)
- Format portrait iPhone, 1170 × 2532 px (rapport 9:19,5), avec les marges de l'encoche et de la barre d'accueil.
- Haut : le numéro du niveau et le nom du chapitre (ex. « 3-2 · Les engrenages »), trois étoiles (pleines ou vides), et un petit bouton pause.
- Sous le haut : le réservoir en tube de verre, centré, avec la file de billes, et l'entrée au sommet du panneau.
- Centre : le panneau avec ses emplacements, ses pièces et ses mécanismes, sur environ 55 % de la hauteur.
- Bas du panneau : la rangée de godets.
- Sous les godets : le bac de pièces (l'inventaire), une barre aux coins arrondis avec 2 à 4 cartes. Chaque carte montre une pièce, son nom court en français et un badge rond avec son nombre (« 2 »). Une carte épuisée est grisée.
- Tout en bas : un gros bouton « Lâcher », bombé et coloré, qui donne envie d'appuyer, et deux petits boutons ronds (recommencer, aide).
- Typographie : une sans-serif ronde et grasse, de jeu mobile, en français, et le moins de texte possible.

LES MÉCANISMES (le vocabulaire du jeu)
Chaque pièce occupe un emplacement, reçoit la bille par le haut et la renvoie en bas à gauche, en bas à droite, ou tout droit.
1. Aiguille : une planchette inclinée qui envoie toujours du même côté.
2. Bascule : un balancier sur un pivot doré ; il envoie d'un côté, puis bascule sous le poids et enverra la bille suivante de l'autre côté.
3. Trieur : un portillon peint d'une couleur ; les billes de sa couleur passent d'un côté, les autres de l'autre.
4. Poche : une petite nacelle qui garde la première bille qui y tombe, et ne la relâche qu'à la fin.
5. Levier relié : une palette sur laquelle passe la bille ; une tringle ou des engrenages la relient à une AUTRE pièce, plus loin sur le panneau, qu'elle fait basculer. Le lien doit être visible.
6. Écluse à billes : un petit sas qui retient les billes jusqu'à en avoir 3, puis s'ouvre et les lâche ensemble.
7. Balance : un plateau qui ne s'abaisse (et n'ouvre un passage) que sous le poids de deux billes.
8. Ascenseur : une noria (une chaîne à godets) qui remonte une bille du bas vers le haut du panneau.
9. Tourniquet : une roue à trois logements qui tourne d'un tiers de tour à chaque bille et distribue vers trois sorties à tour de rôle.
10. Tremplin : une rampe courbe ; une bille qui arrive vite (après une longue chute) saute par-dessus l'emplacement voisin, une bille lente tombe dedans.
11. Carillon : une lame de xylophone ou une cloche dorée, posée sur le trajet, qui sonne au passage. C'est le bonus de l'étoile.

CE QUE JE TE DEMANDE
Produis 6 images, UNE PAR RÉPONSE, dans cet ordre. Garde exactement le même style, le même cadre, la même lumière et les mêmes proportions d'une image à l'autre. Avant chaque image, écris en deux ou trois lignes ce qu'elle montre.

Image 0 — La planche des mécanismes. Pas un écran de jeu : une planche de référence, sur fond uni clair, qui présente les 11 mécanismes côte à côte (grille 4 × 3), chacun avec son nom en dessous et une petite flèche qui montre par où la bille entre et ressort. Pour la bascule et le tourniquet, montre deux états côte à côte. C'est cette planche qui fixe le style de toutes les images suivantes.

Image 1 — Niveau 1-3 · L'atelier. Un niveau d'apprentissage, très aéré : 4 rangées, 2 couleurs (rouge et bleu), une aiguille fixe (avec son cadenas), une bascule et une aiguille posées par le joueur, une file de 4 billes. Montre l'instant où la 2e bille arrive sur la bascule, qui vient de basculer. Un carillon est sur le chemin.

Image 2 — Niveau 2-4 · Le tri. 5 rangées, 3 couleurs. Deux trieurs (rouge et jaune), une poche qui garde déjà une bille verte, un trou au milieu du socle. Montre trois billes en route en même temps, sur trois trajets différents.

Image 3 — Niveau 3-2 · Les engrenages. 5 rangées, 3 couleurs. Un levier relié par une tringle et deux engrenages à une bascule située deux colonnes plus loin. Montre l'instant où une bille appuie sur la palette et où la bascule distante se retourne. Les engrenages doivent être grands, beaux et lisibles : c'est la star du niveau.

Image 4 — Niveau 4-1 · La noria. 6 rangées, 4 couleurs. Un ascenseur à godets sur le bord droit remonte une bille jusqu'en haut, un tourniquet à trois sorties distribue au centre, une écluse à billes en retient 2 sur 3. Le niveau est plus chargé, mais il doit rester lisible.

Image 5 — Niveau 5-5 · Le grand final. 6 rangées, 4 couleurs. Une machine complète qui combine balance, tremplin (une bille en plein saut), levier relié, poche et carillon. Les godets du bas sont presque pleins, deux étoiles sont gagnées, et la dernière bille est en route. On doit avoir envie d'y jouer.

Pour finir, après l'image 5, donne-moi en texte la liste des mécanismes visibles dans chaque niveau, avec leur position (colonne, rangée), pour que je puisse reconstruire ces niveaux.
```
