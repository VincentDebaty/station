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

## Choisir un style : six variantes du même écran

Troisième retour, sur la planche refaite en 2D arrondie (mécanismes bleu-gris,
pivots dorés, billes bonbons) : « c'est bien, mais je voudrais avoir d'autres
styles pour choisir ». Cette planche devient le style **0**, la référence.

Pour comparer, chaque variante dessine le MÊME écran de jeu, avec la même
disposition : seul le style change. Coller dans la conversation ouverte :

```text
Cette planche est réussie : garde-la comme référence (on l'appellera « style 0 »). Avant de choisir, je veux comparer d'autres directions artistiques.

Produis 6 images, UNE PAR RÉPONSE. Chaque image montre le MÊME écran de jeu, avec exactement la même disposition. Seul le style change, pour que je puisse comparer.

L'ÉCRAN À DESSINER (identique dans les 6 images)
Format portrait iPhone (rapport 9:19,5). De haut en bas :
- en haut, « 1-3 · L'atelier », trois étoiles dont une pleine, un bouton pause ;
- un réservoir en tube transparent, centré, avec 4 billes dans l'ordre (de bas en haut) : rouge, bleu, rouge, bleu ;
- le plateau : 5 colonnes × 4 rangées d'emplacements. On y voit une aiguille fixe (avec son cadenas) en colonne 2, rangée 2 ; une bascule en colonne 3, rangée 1, qui vient de basculer vers la droite ; un trieur rouge en colonne 4, rangée 3 ; un levier relié en colonne 1, rangée 3, dont la tringle rejoint l'aiguille fixe ; une cloche en colonne 5, rangée 2. Les autres emplacements sont vides ;
- une bille bleue en pleine chute, avec une traînée, entre la bascule et le trieur ; une bille rouge déjà arrivée dans son godet, avec des étincelles ;
- en bas du plateau, 5 godets : rouge, trou, bleu, trou, rouge ;
- le bac de pièces : 3 cartes (Aiguille 1, Bascule 0 grisée, Trieur 0 grisée) ;
- tout en bas, un gros bouton « Lâcher » et deux petits boutons ronds.
Les billes gardent toujours leurs motifs (rouge spirale, bleu uni, jaune points, vert rayures).

LES 6 STYLES
1. Papier découpé : tout est fait de couches de papier coloré découpé, superposées, avec de vraies petites ombres entre les couches et des bords légèrement irréguliers. Couleurs douces et mates.
2. 3D douce : des pièces en plastique mat, aux formes gonflées et arrondies, rendues en 3D avec une lumière studio douce, comme un jeu Nintendo. Très tactile, fond pastel uni.
3. Ligne claire : un dessin de bande dessinée franco-belge, avec un contour noir régulier, des aplats de couleur franche, sans dégradé, et un décor d'atelier dessiné au trait derrière le plateau.
4. Fête foraine rétro : une machine de flipper des années 60 en émail et en chrome, avec des ampoules autour du plateau, des couleurs crème, rouge cerise et bleu canard, et des lettrages de fête foraine.
5. Plan d'ingénieur : un plan technique bleu (cyanotype), aux traits blancs fins et aux cotes discrètes. Seules les billes et les godets sont en couleur, comme si la machine dessinée prenait vie.
6. Livre illustré : de la gouache ou de l'aquarelle, aux couleurs chaudes, avec des textures de pinceau visibles, comme une page d'album jeunesse, mais avec une interface de jeu nette par-dessus.

Pour chaque image, la lisibilité reste la règle : on doit voir de quel côté penche la bascule, quel côté du trieur reçoit le rouge, et que le levier est relié à l'aiguille. Avant chaque image, écris son numéro et le nom du style.
```

## Le style retenu : la fête foraine, à améliorer

Quatrième retour, sur les six variantes : 1 « sympa et mignon », 2 « plus jeu
vidéo mais trop réaliste », 3 « trop dessin », 4 « proche de ce que je
souhaite mais à améliorer », 5 « original mais pas adapté », 6 « mélange des
autres ». **Vincent s'oriente vers la 4, la fête foraine rétro.**

Constat sur les six : ChatGPT a gardé le même plateau et les mêmes pièces,
et n'a changé que le cadre et le fond. Dans la 4, la fête foraine s'arrête au
cadre. Ce qui est à corriger :
- le cadre rouge cerise concurrence les billes et les godets rouges : le
  rouge doit rester réservé aux billes ;
- la patine usée (rouille, éclats, rayures) fait sale et daté sur un écran ;
- trop d'ampoules et d'étoiles partout, qui se battent avec le plateau ;
- l'intérieur du plateau est resté un panneau beige à trous, sans thème ;
- les mécanismes sont les mêmes pièces grises que dans les autres styles ;
- le bouton « Lâcher » vert sort de la palette.

Ce qu'on garde : le cadre de manège qui fait « machine », les ampoules, l'or,
les rayures du chapiteau, et la parenté avec le flipper et le pachinko, qui
sont déjà des machines à billes.

Idée qui en découle : chaque mécanisme devient une attraction (le tourniquet
un carrousel, la noria une grande roue, le tremplin un grand huit, la balance
un « test de force »), et les ampoules du cadre comptent les billes bien
rangées.

```text
C'est la 4, la fête foraine rétro, que je préfère. Elle est proche de ce que je veux, mais il faut l'améliorer. Refais CE MÊME écran (même disposition, mêmes pièces aux mêmes cases, même instant de jeu) avec ces corrections :

1. Plus de rouge dans le décor. Le rouge est réservé aux billes et aux godets rouges : le cadre rouge cerise les noie. Fais DEUX variantes de palette, une image chacune :
   - 4A : prune profond (aubergine), crème et or ;
   - 4B : bleu nuit, crème et or.
   Dans les deux, les rayures du chapiteau reprennent la couleur du cadre avec le crème.
2. Tout est NEUF : émail laqué et brillant, dorures propres. Aucune rouille, aucune rayure, aucun éclat, aucune patine.
3. Moins de décor : une seule rangée d'ampoules autour du plateau, bien espacées, et presque plus d'étoiles semées. Les ampoules du bas sont allumées, celles du haut éteintes : elles montrent combien de billes sont déjà bien rangées.
4. Le thème entre DANS le plateau : un fond crème avec un léger soleil rayonnant qui part de l'entrée, comme un plateau de flipper, et des emplacements cerclés d'un fin anneau doré, moins grands qu'aujourd'hui.
5. Les mécanismes deviennent des objets de fête foraine, sans perdre leur forme ni leur lisibilité : la bascule est une planche de balançoire aux bouts rayés ; le trieur est un fanion de couleur sur un mât ; la cloche est la cloche du « test de force » ; le levier relié a une poignée de manège. Ils sont laqués crème et or, avec un détail de la couleur du cadre.
6. Le bouton « Lâcher » prend la forme d'un grand ticket de manège doré, bombé, avec un lettrage de fête foraine. Les cartes du bac de pièces sont aussi des tickets, avec un bord dentelé. Recommencer et l'indice restent deux jetons ronds.
7. En haut, le titre « 1-3 · Le manège » est écrit sur un fronton de manège, avec les trois étoiles dessous.
8. Le fond derrière la machine : une fête foraine la nuit, très floue, avec des lumières en bokeh et le haut d'un chapiteau. Elle doit rester sombre et calme.

Lisibilité d'abord, comme avant : on voit de quel côté penche la bascule, quel côté du trieur reçoit le rouge, et que le levier est relié à l'aiguille. Les billes gardent leurs motifs. Une image par réponse : 4A, puis 4B.
```

## Une fête foraine pour adultes

Cinquième retour : « cela fait trop jeu d'enfant quand même ». Ce qui tire
vers l'enfance, et qui venait en partie de la correction « jeu mobile » :
les formes gonflées et arrondies, les couleurs primaires saturées, les
billes en bonbon, la typographie ronde et grasse, les étincelles et les
étoiles de dessin animé, les boutons bombés comme des bonbons, et les objets
forains trop littéraux (balançoire, tickets). On garde la fête foraine et la
machine, mais avec la tenue d'un jeu de puzzle pour adultes (le niveau de
Monument Valley, The Room ou Alto).

```text
L'ensemble fait encore trop « jeu d'enfant ». Je veux garder l'idée de la fête foraine et de la machine, mais avec la tenue d'un jeu de puzzle mobile pour ADULTES, au niveau de Monument Valley, The Room ou Alto (comme niveau d'exigence, pas comme modèles à copier).

Ce qui fait enfantin, et que je ne veux plus :
- les formes gonflées et arrondies comme des jouets ;
- les couleurs primaires saturées ;
- les billes en bonbon ;
- la typographie ronde et grasse ;
- les étincelles, les étoiles et les éclats de dessin animé ;
- les boutons bombés comme des bonbons ;
- les objets forains trop littéraux (balançoire, tickets).

Ce que je veux à la place, dans les trois images :
- des proportions fines et précises, des arêtes nettes, une vraie profondeur (ombres et lumières crédibles), mais toujours stylisées : pas de photoréalisme ;
- des billes en verre, avec un reflet et un fin ruban intérieur, en couleurs de pierres précieuses, sombres mais bien distinctes : rubis, saphir, ambre, émeraude. Elles gardent leur motif pour les daltoniens (spirale, uni, points, rayures), discret mais lisible ;
- une typographie élégante : des capitales fines, Art déco ou à empattements, pour les titres, et une sans-serif sobre pour l'interface ;
- des retours sobres : une lueur, un reflet qui passe, une ampoule qui s'allume. Plus d'étoiles qui jaillissent ;
- des boutons plats ou légèrement gravés, cerclés d'un filet doré, sans effet de bonbon ;
- des mécanismes qui ressemblent à de vraies pièces de machine (laiton poli, émail ivoire, acier bleui), lisibles par leur forme et non par des déguisements.

Refais LE MÊME écran (même disposition, mêmes pièces aux mêmes cases, même instant de jeu) en 3 variantes, une image par réponse :

4C — Art déco nocturne. Une machine de foire de 1925 : laque noire et bleu nuit, filets d'or géométriques, éventails et chevrons Art déco autour du plateau, une rangée d'ampoules tamisées. L'ambiance d'un salon de jeux chic, la nuit.

4D — Automate de foire. L'intérieur d'une machine de foire ancienne, comme une diseuse de bonne aventure mécanique : derrière le plateau, sous une vitre, on devine des engrenages et des cames en mouvement. Cuivre, vert bouteille et ivoire, avec une lumière chaude et contrastée. Un objet de collection.

4E — Fête foraine épurée. Une version moderne et minimale : une palette sourde (anthracite, ivoire, or mat), peu d'ornements. La fête foraine n'est que suggérée, par une rangée d'ampoules et une fine rayure de chapiteau. Des aplats précis, beaucoup d'air, comme Alto ou Monument Valley.

La lisibilité reste la règle : on voit de quel côté penche la bascule, quel côté du trieur reçoit le rubis, et que le levier est relié à l'aiguille. Avant chaque image, écris son nom.
```

## Dans l'esprit de Royal Match

Sixième retour : « dans un style que le jeu Royal Match pourrait être
bien ». Ce n'est pas une contradiction avec « trop jeu d'enfant » : Royal
Match vise un public adulte. Ce qui le sépare de nos images enfantines,
c'est la FINITION. Un rendu 3D soigné, des matières riches (or, émail,
velours, pierres), une lumière travaillée, des cadres dorés ouvragés, des
effets généreux mais maîtrisés, une interface très construite (objectifs en
haut, barre de bonus en bas). On reprend ce niveau de production, pas son
univers : ni son roi, ni son château, ni son logo.

Deux thèmes à comparer : la fête foraine retenue jusqu'ici, et la salle du
trésor d'un palais, où les billes deviennent des joyaux à ranger dans des
coffres.

Le prix à garder en tête : une telle finition demande des images rendues en
3D, donc un graphiste ou des sprites précalculés le jour du portage. Pour
l'instant, ce ne sont que des mockups.

```text
Nouvelle direction : je voudrais la finition d'un grand jeu mobile comme Royal Match. Je parle de son niveau de production, pas de son univers : pas de roi, pas de château copié, pas de logo, aucun de ses personnages.

Ce que j'attends de cette finition :
- un rendu 3D soigné et brillant, avec une lumière douce et chaude, des reflets francs sur le métal et le verre, de la profondeur ;
- des matières riches : or ouvragé, émail laqué, velours, verre, pierres précieuses ;
- des couleurs vives et saturées, mais harmonieuses, et un contraste fort entre le plateau et le décor ;
- un cadre doré ouvragé autour du plateau, et des panneaux d'interface aux bords dorés ;
- une typographie de titre très grasse, blanche ou dorée, avec un contour sombre et une ombre, comme dans les grands jeux mobiles ;
- des boutons épais et brillants : « Lâcher » est un grand bouton vert, contouré, très appétissant ;
- en haut, un panneau « Objectifs » qui montre combien de billes de chaque couleur il reste à ranger (par exemple : 2 rouges, 2 bleues) ;
- en bas, le bac de pièces présenté comme une barre de bonus : des médaillons ronds aux bords dorés, chacun avec sa pièce et un badge rond indiquant le nombre ;
- des retours généreux : une gerbe de lumière dorée et des éclats quand une bille tombe dans le bon godet.

Les billes sont de grosses billes de verre brillantes, toujours avec leur motif pour les daltoniens (rouge spirale, bleu uni, jaune points, vert rayures).

Refais LE MÊME écran que les fois précédentes (même disposition, mêmes pièces aux mêmes cases, même instant de jeu) en 2 variantes, une image par réponse :

R1 — La fête foraine. Le cadre est un fronton de manège doré et laqué, avec des ampoules et un chapiteau rayé bleu nuit et crème. Derrière, une fête foraine le soir, colorée mais floue.

R2 — La salle du trésor. Le plateau est une machine d'orfèvre dans la salle du trésor d'un palais : velours bleu roi, or ouvragé, colonnes de marbre floues à l'arrière-plan. Les billes sont des joyaux taillés en sphère (rubis, saphir, topaze, émeraude), toujours avec leur motif, et les godets sont de petits coffres au trésor ouverts, de la couleur du joyau attendu.

La lisibilité reste la règle : on voit de quel côté penche la bascule, quel côté du trieur reçoit le rouge, et que le levier est relié à l'aiguille. Avant chaque image, écris son nom.
```

## La simplicité de Royal Match et de Block out

Septième retour, sur R1 (fête foraine surchargée : chapiteau, ampoules,
dorures, foule) et avec deux captures de référence, Royal Match et un jeu
« Block out » : « ça ne va pas. Je veux rester simple graphiquement. On ne
doit pas forcément avoir cet effet tableau à compléter. Juste l'espace de
l'écran avec les différents modules. La simplicité comme Royal Match ou
Block out ! »

Ce que les deux captures ont en commun :
- un fond d'UNE couleur dominante (le bleu roi, le violet profond), sans
  décor ni texture ;
- peu d'objets, gros, chacun d'une seule couleur et d'une silhouette
  reconnaissable (gemme, couronne, bouclier ; briques à picots) ;
- un modelé simple : un aplat, un biseau, un reflet, et c'est tout ;
- une interface réduite à quelques cartes et boutons ronds épais, avec un
  texte blanc très gras ;
- toute la couleur vive est sur les objets du jeu, pas sur le décor.

Et surtout : **plus de grille d'emplacements visible**. Les modules flottent
dans l'espace de l'écran. Pour le moteur, rien ne change : les pièces se
calent toujours sur une grille, mais elle reste invisible et n'apparaît, en
points discrets, que pendant qu'on glisse une pièce.

Joindre les deux captures de référence à la demande.

```text
Ça ne va pas : c'est beaucoup trop chargé. Je veux un jeu SIMPLE graphiquement, comme Royal Match ou ce jeu de briques (je joins deux captures). Regarde ce qu'elles ont en commun :
- un fond d'UNE seule couleur dominante, sans décor ni texture ;
- peu d'objets, gros, chacun d'une seule couleur et d'une silhouette reconnaissable ;
- un modelé simple : un aplat, un biseau, un reflet, et c'est tout ;
- une interface réduite à quelques cartes et boutons ronds épais, avec un texte blanc très gras ;
- toute la couleur vive est sur les objets du jeu, jamais sur le décor.

Le plus important : il n'y a PLUS de plateau ni de grille de trous. L'écran lui-même est l'espace de jeu. Les modules sont posés directement dans cet espace, à leur place, et rien ne marque les emplacements libres.

Dessine l'écran de jeu ainsi, au format portrait iPhone (rapport 9:19,5) :
- en haut, une barre simple : « Niveau 13 » dans une pastille, une carte « Objectifs » qui montre 2 billes rouges et 2 bleues à ranger, et un bouton pause rond ;
- sous la barre, au centre, un entonnoir simple d'où sortent les billes, et au-dessus de lui la file des billes qui attendent (rouge, bleu, rouge, bleu), en rangée ou dans un tube court ;
- au milieu, l'espace de jeu, vide, sur le fond uni. Cinq modules y sont posés, chacun avec une silhouette simple et franche, en plastique blanc ou gris clair avec une seule pièce de couleur :
  • une bascule (un balancier sur un pivot), juste sous l'entonnoir, qui vient de pencher vers la droite ;
  • une aiguille fixe (une rampe inclinée vers la gauche, avec un petit cadenas), en haut à gauche ;
  • un levier relié (une palette avec une tige fine qui rejoint l'aiguille fixe), plus bas à gauche ;
  • un trieur rouge (un portillon avec un fanion rouge : les rouges partent du côté du fanion, les autres de l'autre côté), au centre droit ;
  • une cloche dorée, à droite ;
- une bille bleue en train de tomber de la bascule vers le trieur, avec une traînée légère, et un pointillé fin qui montre la suite de son trajet ;
- en bas de l'espace de jeu, une rangée de 5 godets simples : rouge, vide, bleu, vide, rouge. Les colonnes vides n'ont pas de godet : juste une ouverture sombre. Une bille rouge vient d'arriver dans le premier godet, avec un petit éclat ;
- en bas de l'écran, une rangée de 3 boutons carrés aux coins arrondis, comme les bonus du jeu de briques : l'aiguille (badge « 1 »), la bascule et le trieur (grisés, badge « 0 ») ; et à côté, ou dessous, un gros bouton « Lâcher ».

Les billes sont des billes brillantes simples, d'une seule couleur franche, avec leur motif blanc pour les daltoniens (rouge spirale, bleu uni, jaune points, vert rayures).

Fais 3 images, une par réponse, IDENTIQUES sauf la couleur du fond :
S1 — fond bleu roi profond ;
S2 — fond violet profond ;
S3 — fond clair (gris bleuté très pâle), avec des modules un peu plus foncés pour garder le contraste.
```

## Le style trouvé : S1, à resserrer

Huitième retour, sur S1 (fond bleu roi, modules en plastique blanc, sans
grille) : « c'est déjà plus dans le style que je recherche ». **C'est la
direction.**

Ce qui marche : le fond uni, les modules blancs aux silhouettes franches,
les godets simples et les trous ovales, le tube et l'entonnoir, les
pointillés de couleur qui partent du trieur, la barre de pièces avec ses
badges, le gros bouton vert.

Ce qui reste à corriger :
- sur fond bleu, la bille bleue et le godet bleu perdent du contraste :
  c'est la couleur d'une bille, elle ne peut pas être celle du fond ;
- les modules n'ont pas la même taille (l'aiguille fixe est énorme), et le
  levier relié flotte loin de tout trajet : ils doivent tenir dans des
  colonnes invisibles, à une échelle commune ;
- dans la barre de pièces, l'aiguille porte un cadenas : le cadenas est
  réservé aux pièces fixes du niveau ;
- la carte « Objectifs » répète les billes au lieu de les compter.

Ensuite : la planche des 11 mécanismes dans ce style, pour fixer leurs
silhouettes, puis les niveaux. Et côté jeu, le plaisir viendra des
mécanismes, pas du visuel : les suivants à coder dans le prototype (levier
relié, tourniquet, balance ou écluse) se décideront sur cette planche.

```text
C'est exactement la direction que je cherche : garde ce style (fond uni, modules en plastique blanc aux silhouettes franches, aucune grille, godets simples, gros boutons). Quatre corrections, sur le MÊME écran :

1. Le contraste : sur fond bleu, la bille bleue et le godet bleu se perdent. Fais deux images : S2 sur fond violet profond, S4 sur fond bleu nuit presque noir. Je choisirai.
2. Une échelle commune : tous les modules ont la même taille et se calent sur 5 colonnes invisibles, comme si l'écran était une grille qu'on ne voit pas. L'aiguille fixe est moins grande, et le levier relié est placé SUR le trajet d'une bille, près de l'aiguille qu'il commande.
3. Le cadenas n'apparaît que sur les pièces fixes du niveau, jamais dans la barre de pièces : l'aiguille de la barre n'a pas de cadenas.
4. La carte « Objectifs » compte au lieu de répéter : une bille rouge « ×2 » et une bille bleue « ×2 ».

Une image par réponse : S2, puis S4.
```

Puis, une fois le fond choisi :

```text
Avec ce style et ce fond, fais la planche des mécanismes : les 11 modules (aiguille, bascule, trieur, poche, levier relié, écluse à billes, balance, ascenseur, tourniquet, tremplin, carillon), tous à la même échelle, sur une grille de 4 × 3, chacun avec son nom dessous et une flèche fine qui montre par où la bille entre et ressort. Pour la bascule et le tourniquet, montre deux états côte à côte. Mêmes matières : plastique blanc, une seule pièce de couleur par module, biseau et reflet simples.
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
