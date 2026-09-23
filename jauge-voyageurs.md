# La jauge des voyageurs — ce qu'elle change, et ce qu'elle ne change pas

Écrit le 22 septembre 2026, sur la branche `jauge-voyageurs`, après une démo
jouée par Vincent : « cela donne un peu plus de volume au jeu mais je sens
qu'il y a moyen de mieux faire ». Le document mesure d'abord ce que le proto
fait **vraiment** — en simulant deux joueurs sur soixante services —, puis dit
pourquoi l'impression est juste, ce qui est corrigé tout de suite, et les
quatre idées qui feraient de la jauge une mécanique plutôt qu'un compteur.

Il ne remplace ni `difficulte-et-merite.md` (dont il réemploie le barème 8 · 15
· 30 au §2) ni `economie-du-jeu.md` (dont il propose au §5 de brancher la
bourse sur les voyageurs). Il est le rapport d'essai du proto : une fois
tranché, soit la jauge entre dans `meta-progression-jeu-aiguillage.md`, soit
la branche se jette.

---

## 0. Comment c'est mesuré

Deux joueurs scriptés, sur la carte d'atelier (`data/cartes/essai.json`, treize
gares belges, plancher 1), en headless, sauvegarde isolée :

- **le joueur au plus court** — celui du dépôt (`_joueur_scripte`) : il prend
  le premier quai libre qui dessert la destination, sans regarder les
  voyageurs. 13 gares × 3 graines = **39 services** ;
- **le joueur qui suit les pastilles** — même code, mais il attend le quai où
  la foule l'attend (`tr.hint`), et ne dévie jamais. 7 gares × 3 graines =
  **21 services**.

Les deux sont médiocres au regard d'un humain : ils ne planifient pas et se
bloquent (quinze services sur trente-neuf finissent au plafond de retard).
Les chiffres qui suivent ne valent donc que par leur **écart**, qui est net.

---

## 1. La jauge compte autrement ; elle ne fait pas décider autrement

C'est structurel, et ce n'est pas une question de réglage. Dans
`vue_jeu.gd` :

- une unité par wagon, `n = cars − 1` ;
- posée **sous le quai que le calibrage a retenu** (`tr.hint`) ;
- un convoi à ce quai prend **jusqu'à sa capacité** — c'est-à-dire exactement
  le monde qui l'attend.

L'offre égale la demande, à l'unité près, sur le quai que la solution
désigne. Il n'existe donc **aucun arbitrage de remplissage** : un train part
plein ou vide, et jamais à moitié par la faute du joueur.

| joueur | embarqués | retard médian |
|---|---|---|
| au plus court (39 services) | **86 %** en médiane, 68 % au pire | 19,4 min |
| qui suit les pastilles (21 services) | **100 % dans 14 services sur 21**, zéro resté à quai | 0,3 à 3,8 min quand il ne se bloque pas |

Autrement dit : **la rangée de pastilles est le corrigé du niveau, affiché dès
la première seconde.** Suivre les points, c'est tout embarquer ; dévier, c'est
perdre un train entier d'un coup, puisqu'un convoi mal placé prend *zéro*
voyageur — même à la bonne couleur, même à un quai de distance. La décision
n'est pas « combien j'emporte », elle est « j'obéis ou je perds ».

Deux conséquences, l'une bonne, l'autre non :

- **pour l'accueil, c'est un gain** : un débutant lit le plan de la journée
  sans qu'on le lui explique ;
- **pour le jeu, c'est une perte** : la recherche du bon quai était le jeu, et
  elle est maintenant écrite à l'écran.

Le seul arbitrage vraiment neuf existe — *le quai prévu est pris : j'attends
(du retard) ou je dévie (des voyageurs)* — et il est bon, parce que les deux
branches se paient dans la même monnaie. Mais il est rare, et rien ne le met
en scène.

Le poids relatif le confirme : sur les vingt-quatre services non bloqués, le
retard coûte **22,7 points en moyenne**, les voyageurs manqués **4,7**. La
jauge reste à 80 % un compteur de retard déguisé. Elle ne cesse de l'être que
chez un joueur qui ne prend plus de retard — c'est-à-dire Vincent.

---

## 2. Le barème part en vrille d'un côté, et ne mord pas de l'autre

**Le côté négatif n'est pas borné.** `_points_live()` retranche
`live_delay()`, qui est le retard **cumulé sur tous les convois** : trois
trains en retard de cinq minutes coûtent quinze points. Mesuré : **−111 points
pour un maximum de 21**. La petite jauge est collée à fond de rouge dès le
premier tiers de la journée ; la partie est morte, et elle continue.

**Le côté positif est trop large.** Trois étoiles à deux tiers du maximum :
mesuré à Gand, **trois étoiles avec neuf voyageurs laissés à quai** (32 points
sur 43). L'axe voyageurs ne mord donc jamais — ce qui est une autre façon de
dire le §1.

**Et il y a deux barèmes.** Les étoiles viennent de la jauge, mais le tutoriel
promet toujours une étoile « avec moins de 30 min de retard », et le relevé du
ruban ne parle que de minutes. Le joueur reçoit une note calculée dans une
unité qu'on ne lui montre jamais.

---

## 3. Ce que le joueur ne peut pas apprendre

Relevé après un service à **27 voyageurs sur 28** (Landen, graine 3) : le
panneau du ruban affiche « 2 min de retard ». Rien d'autre.

- `bilan_final` porte pourtant `points` et `pointsMax` : personne ne les lit ;
- l'écran « +X points sur Y » de fin de service n'existe **que** hors ruban
  (`app == null`) : en jeu normal, il ne s'affiche jamais ;
- **aucun son** n'accompagne un embarquement, alors que vingt et un bruitages
  sont disponibles ;
- hiérarchie du bandeau inversée : l'horloge à 46 px, le but du jeu à 12 px ;
- les pastilles de 3,4 px se confondent avec le pointillé des voies. Réduites
  à la taille d'un téléphone (844 × 390), elles sont des confettis : à
  Paris‑Nord, **56 unités sur dix quais** qu'on ne peut ni compter ni
  attribuer à leur quai d'un coup d'œil.

C'est la moitié de l'impression de Vincent : la mécanique existe, personne ne
la lui dit.

---

## 4. Ce qui est corrigé tout de suite — fait le 22 septembre 2026

Les correctifs qui ne coûtent rien et ne tranchent rien. Ils rendent la jauge
**lisible et discriminante**, pour que la décision de la garder ou non se
prenne sur une version qui se défend.

1. **Le relevé dit les voyageurs.** « 27 voyageurs sur 28 · 1 resté à quai »,
   au-dessus du retard, sur l'écran du ruban (`vue_ruban.gd`, `_bloc_bilan`) ;
   `bilan_final` transporte `montes` et `restes`.
2. **Les étoiles se calculent dans la monnaie de la jauge.** La **perte** d'un
   service est `maximum − points`, c'est-à-dire *voyageurs manqués + minutes de
   retard cumulées*, et elle passe dans le barème existant de la fiche
   (8 · 15 · 30 au niveau 1, 4 · 15 · 30 au niveau 5). Une minute de retard et
   un voyageur laissé pèsent donc pareil — ce que la jauge affirmait déjà, et
   que les étoiles ignoraient. Le sans-faute devient « personne n'est resté, et
   pas une minute ». **Mesuré sur les 39 services du §0 : sept perdent une
   étoile, aucun n'en gagne** — 6 · 5 · 6 · 22 (trois, deux, une, zéro) avant,
   4 · 5 · 5 · 25 après. Gand passe de trois étoiles à deux avec ses neuf
   voyageurs à quai ; un joueur qui embarque tout le monde ne voit, lui, aucun
   changement, puisque sa perte se réduit à son retard. La règle punit ce
   qu'on laisse, pas la compétence.
3. **La perte est bornée à `−maximum`.** En dessous, le nombre ne veut plus
   rien dire et la barre est pleine de toute façon.
4. **Les pastilles se comptent, et chacune a sa place.** Les couleurs ne sont
   plus mêlées : chaque destination reçoit sa **bande** sur le quai, dans un
   ordre tiré au sort et d'une largeur proportionnelle à sa foule du jour — on
   attend près de l'affichage de son train. L'ordre à l'intérieur d'une
   destination reste au hasard : la séquence des départs n'est toujours pas
   écrite sur le quai. Et **la place de chacun est tirée une fois pour
   toutes**, n'importe où dans son pas et pas exactement à la même hauteur :
   personne ne se décale quand un voisin arrive ou monte. (Première version :
   une rangée centrée, recalculée à chaque image depuis le rang des présents —
   « cet effet qu'arrivé pousse les autres », Vincent, 22 septembre. Les
   paquets de cinq, qui rendaient cette rangée comptable, ont disparu avec
   elle.)
5. **La jauge se voit.** Le nombre passe de 12 à 18 px, la barre s'élargit, et
   le « +X » d'un convoi qui part passe de 18 à 26 px.
6. **L'embarquement sonne.** Une note grave (`puce`) quand un convoi prend des
   voyageurs, deux notes descendantes (`dommage`) quand il part à vide alors
   que des voyageurs pour sa destination attendent ailleurs. Une fois par
   convoi, jamais une fanfare.
7. **Les voyageurs attendent SUR le quai** (ajouté le 22 septembre au soir,
   sur une capture de Clapham Junction : « les voyageurs semblent être sur le
   quai du bas »). La géométrie lui donnait raison : à dix quais le pas
   vertical tombe à 57,8 unités pour une pilule de 42 — un écart de 15,8 —, et
   la rangée, posée à `PLAT_H/2 + 9 × UIK`, tombait à 34,5 sous le centre quand
   la pilule suivante commence à 36,8 ; sur téléphone (`UIK` = 1,5) les
   pastilles mordaient la plaque d'en dessous. Elles sont maintenant **dans**
   la pilule, sur la bande basse que la marge du quai laisse libre, portées par
   une bordure creusée d'un filet de laiton qui ne paraît que là où quelqu'un
   attend. Aucune ambiguïté possible, quel que soit le nombre de quais — et
   c'est ce qui se passe en vrai : on attend SUR le quai. La rangée est
   **centrée** et se serre quand la foule déborde, au lieu de s'aligner à
   gauche et de passer à la ligne : « que cela fasse plus naturel ».
8. **Le tutoriel dit la bonne règle** en mode jauge, et le commentaire périmé
   de `JAUGE_SECONDES_PAR_POINT` (« quinze secondes valent un point ») est
   corrigé.

Ce qui n'est **pas** touché : l'enclenchement, la génération, les brevets, les
cartes. Tout tient dans `vue_jeu.gd` et six lignes de `vue_ruban.gd`.

---

## 5. Les quatre idées qui en feraient une mécanique

Par coût croissant. Aucune n'est faite ; la première est la moins chère et
sans doute la plus payante.

### 5.1 Les voyageurs arrivent au fil de la journée — FAIT le 22 septembre 2026

Tout le monde était là à 7 h 00. Chacun se présente maintenant **un à quatre
convois avant le sien**, et paraît en six dixièmes de minute de jeu — il
grandit et se teinte, faute de quoi une pastille surgirait du néant au milieu
de la rangée.

**L'avance se compte en convois, pas en minutes**, et c'est la mesure qui l'a
imposé. Trois à dix-huit minutes, essayées d'abord, ne voulaient rien dire :
un service dure une demi-heure de jeu et porte quinze convois — un train
toutes les deux minutes —, et dix-huit minutes d'avance ramenaient
**dix-sept voyageurs sur quarante-trois dès l'ouverture**, c'est-à-dire le mur
d'avant. Le pas moyen entre deux convois sert donc d'unité : la foule vaut
quelques convois à venir, aussi bien au niveau 1 qu'au niveau 5, où les trains
se serrent sans que les gens se pressent.

Mesuré à Gand, graine 3 : **six présents à l'ouverture** au lieu de
quarante-trois. À Landen, le hall ne dépasse jamais dix-huit personnes sur les
vingt-huit de la journée. Le hall se lit enfin d'un coup d'œil à la taille
d'un téléphone, il se remplit avant une rafale et il est vide à la fin du
service.

**La garantie du calibrage tient.** L'heure d'arrivée est tirée sur l'HORAIRE,
une fois, et tombe toujours avant l'annonce du convoi (`heure_arrivee −
APPROACH_LEAD`) : un convoi ne peut jamais se présenter à son quai avant sa
foule, et la journée où tout le monde monte existe toujours. Le retard du
joueur ne retarde personne — les voyageurs ne sont pas au courant.

**Et cela ne change rien au jeu, ce qui est le but.** Les 39 services du banc
rejoués à graines identiques, avec et sans échelonnement : mêmes étoiles
(4 · 5 · 5 · 25), même embarquement médian (86 %), même retard médian
(19,4 contre 19,6 min), même perte médiane (27). La journée est la même ; c'est
le hall qui a changé d'allure.

Effet de bord voulu : **le corrigé ne se lit plus d'un coup**. Le hall
n'annonce plus que les quelques convois à venir ; c'est un radar, plus une
solution.

### 5.2 Les correspondances — FAIT le 22 septembre 2026

**Un tiers des voyageurs ne vient plus de la ville : il descend d'un train.**
Ils ne sont nulle part tant que leur convoi d'apport n'est pas à quai — on les
voit dedans, points noirs dans ses wagons —, ils en descendent à l'arrêt,
traversent la gare au pas pressé de qui a une correspondance (une fois et
demie l'allure du flâneur), rejoignent leur quai puis leur place. La foule
devient la conséquence de ce qu'on fait des trains, et non un décor posé
d'avance.

**C'est la première fois qu'un retard se propage.** Retenez l'apport, et ses
voyageurs descendent trop tard pour leur correspondance : ils restent, et ils
comptent comme tous les autres. Un convoi mal aiguillé ne coûte plus seulement
son propre retard — il coûte la foule d'un autre.

**Le total ne bouge pas** : ce sont les mêmes voyageurs, arrivés autrement. Ni
le maximum de la journée, ni le barème, ni la garantie du calibrage ne
changent. L'apport est choisi À LA CONSTRUCTION parmi les convois qui arrivent
au moins trois minutes avant celui qu'ils alimentent — de quoi couvrir la plus
longue traversée possible (770 unités au pas pressé, deux minutes) — et qui ne
viennent pas de là où va leur voyageur : on ne revient pas de Brighton pour
repartir à Brighton. Un convoi ne débarque jamais plus de monde qu'il n'a de
wagons.

**Le couloir sous les quais** (ajouté le 22 au soir : « un voyageur ne traverse
pas les voies ; il faudrait dessiner un tunnel sous les voies par lequel tous
les voyageurs passent »). C'était le défaut de la première version : le
voyageur coupait à travers le faisceau comme s'il marchait sur les rails. Il
court à l'aplomb du milieu des quais — **sous l'horloge**, que Vincent prend
pour le bâtiment de la gare —, ne croise aucune voie (le gril et les courbes
tiennent les deux bouts du plan, le milieu est libre), et se dessine **dans les
intervalles** entre les quais : il disparaît sous chacun d'eux, ce qui est
exactement ce qu'il est. Le voyageur y passe en demi-teinte — on le suit des
yeux d'un bout à l'autre, mais il est dessous.

**Et la ville entre par là.** Personne ne paraît plus à sa place : le voyageur
sort de la bouche du couloir, le descend et surgit sur son quai. Son heure
d'arrivée reste celle qu'elle était — c'est son ENTRÉE qu'on recule du temps de
la marche —, si bien que le calibrage, le barème et le compte n'en savent rien.
Ceux dont la marche aurait commencé avant l'ouverture sont déjà sur les quais
au premier instant : « en début de partie, on voit directement les premiers
voyageurs sur les quais ». Le fondu d'apparition disparaît avec eux — c'était
lui qu'on voyait se rejouer à l'arrivée de quelqu'un qu'on venait de suivre des
yeux (« ils disparaissent puis réapparaissent dans un fondu ») ; seule la
bordure du quai en garde un, parce qu'elle ne peut pas entrer par le couloir.

Deux conséquences qu'il a fallu régler au passage :

- **un convoi à quai continue de se remplir.** L'embarquement était décidé une
  fois pour toutes à l'arrêt ; une correspondance qui traversait encore la gare
  arrivait alors deux secondes trop tard et restait, aussi durement qu'une
  minute entière. Le convoi prend maintenant les retardataires tant qu'il est à
  quai et qu'il lui reste des wagons — le « dommage » du départ à vide se joue
  donc au départ, seul moment où l'on sait qu'il n'a emmené personne ;
- **un wagon est en couleur dès qu'il porte quelqu'un**, à l'arrivée comme au
  départ. Un convoi n'arrive plus forcément vide.

Mesuré sur les 39 services du banc, à graines identiques : **357
correspondances sur 1 160 voyageurs, soit 31 %**. Les étoiles ne bougent pas
(4 · 5 · 5 · 25, comme avant), le retard médian non plus (19,6 min), et
l'embarquement médian passe de 86 à **84 %** — la mécanique mord un peu, sans
déplacer la difficulté. Sur les 357 correspondances, 91 sont restées à quai
(un quart, contre un sixième pour l'ensemble des voyageurs : c'est la
pression nouvelle) et **3 seulement ne sont jamais descendues**, dans des
services où leur apport n'est jamais arrivé — c'est-à-dire des services
échoués. La journée reste la même pour qui tient l'horaire.

### 5.3 La capacité doit mordre

Tant qu'un quai porte exactement ce qu'un train peut prendre, il n'y a aucune
question. À 120–130 %, « quel train prend la foule » devient une décision, un
train qui part plein devient une petite victoire, et le wagon grisé veut enfin
dire quelque chose. Attention : cela rend le maximum **inatteignable**, donc
le §4.2 devrait alors compter la perte sur ce qui était *emportable*, pas sur
le total.

### 5.4 L'embarquement pèse sur l'heure de départ — le gros morceau

`dwell = max(2 min, temps d'embarquement)`, plafonné, et les voyageurs
**marchent vers le quai annoncé** au lieu de rester plantés. C'est la seule
version où la marche déjà animée raconte quelque chose : envoyer le train de
Liège loin de la foule de Liège coûte du temps, et le voyageur têtu — qui
refuse aujourd'hui un train de sa couleur à un quai de distance — disparaît.

La réserve existe : `difficulte-et-merite.md` §1.1 et §1.2 mesurent **environ
trois minutes de mou par convoi** avant qu'une minute ne compte. Mais cela
touche l'enclenchement (sous oracle) et le calibrage : `gen-check` et les
**401 brevets** seraient à repasser. À n'essayer que sur la carte d'atelier, et
seulement si 5.1 à 5.3 ont convaincu.

---

## 6. Une idée de bourse, en passant

Si la jauge reste, la pièce devrait suivre : **les pièces d'un service = les
voyageurs transportés**, au lieu de 1, 2 ou 3 par service
(`economie-du-jeu.md` §1). Le gain devient proportionnel à la performance
plutôt qu'au palier d'étoile, ce qui est exactement ce que cherchait le
constat de mérite du 10 septembre — et ce qui donne une raison de rejouer une
gare autrement qu'à l'étoile près. Cela déplacerait tout le barème de la
bourse : à instruire dans `economie-du-jeu.md`, pas ici.

---

## 7. Ce que l'essai a fait retirer : le fret et les fermetures de quai

Décidé le 22 septembre 2026, après une partie : « le vrai problème qui me
frustre à chaque fois, c'est les convois de fret qui bloquent souvent tout
systématiquement. Je désactiverais cela ainsi que le quai bloqué qui n'apporte
rien au jeu » (Vincent).

Les deux mobilisaient un quai sans rien rapporter : le fret verrouille entrée
ET sortie d'un seul tenant le temps du transit, la fermeture retire un quai
pour quelques minutes. **Depuis la jauge, ils coûtent en plus la foule qu'un
convoi n'a pas pu emmener** — le prix a doublé sans que le plaisir suive.
C'est donc un effet de bord de la jauge, et il vaut d'être noté comme tel : un
obstacle supportable quand il ne coûtait que des minutes devient odieux quand
il coûte des gens.

Deux interrupteurs, `FREIGHT` et `CLOSURES`, dans **les deux** générateurs —
`js/schedule.js` et `jeu/journee.gd`. Ils bougent ensemble, sans quoi
`oracle-journee` refuse : une journée n'est pas « proche », elle est la même ou
elle ne l'est pas. Les enveloppes gardent leur `freightCount` : remettre `true`
suffit à retrouver le jeu d'avant.

Une fermeture tirée ne devient pas un retard — elle ne devient rien, et la
journée est simplement plus calme.

**Contrôles.** `oracle-journee` et `oracle-enclenchement` verts (les deux
implémentations tirent et jouent la même journée) ; `gen-check` passé **quatre
fois** — une à graine fixe, trois libres —, toutes les gares passent ;
`carte-check` vert. Les **brevets ne sont pas repassés** : ils certifient qu'un
niveau est sain, et retirer un fret et une fermeture ne peut que détendre une
journée. Ils restent donc valides, et conservateurs.

---

## 8. Quatre voyageurs par wagon

Demandé le 23 septembre 2026 : « les passagers pourraient être plus nombreux.
Si on mettait 4 passagers par wagon ? Le but est de mettre plus d'animation
dans la gare. » Un wagon en portait un, et la gare était vide entre deux
convois.

**Le barème suit le facteur, sinon le jeu change sans qu'on l'ait décidé.** Une
minute de retard coûte désormais quatre points — `JAUGE_SECONDES_PAR_POINT`
repasse à quinze, sa valeur d'origine — et les trois seuils d'étoiles sont
multipliés d'autant. Un wagon laissé derrière vaut donc exactement ce qu'il
valait la veille, et une minute de retard aussi : tout est quadruplé, rien ne
bouge. Vérifié à Gand, graine 3 : perte de 37 points pour 36 voyageurs manqués
et 0,2 minute de retard, soit 9,25 wagons — quand le compte à un voyageur par
wagon aurait donné 9 wagons manqués plus 0,2, c'est-à-dire 9,2. La granularité
est quatre fois plus fine, l'équilibre est le même.

Ce que quinze secondes par point avaient d'insupportable le 20 septembre n'était
pas leur valeur : c'était qu'un wagon ne valait alors qu'un point, si bien qu'une
minute de retard coûtait quatre wagons. Elle en coûte un.

**Deux ajustements de dessin** que le nombre imposait :

- **le rayon d'une pastille suit la densité du quai.** Un quai de Clapham porte
  vingt-deux places sur deux cent trente-huit unités : à cinq de rayon, elles se
  chevauchaient. Chacun emporte le sien, mesuré sur le pas de son quai — les
  gares tranquilles gardent de grosses pastilles, les gares chargées en ont de
  petites, ce qui est aussi ce qu'on veut voir ;
- **les quatre places d'une caisse sont en carré, et le carré tourne avec
  elle.** Posé dans le repère de l'écran, il restait à plat quand la caisse
  s'inclinait sur une courbe — « cela reste figé » (Vincent, le jour même).

**Et trois défauts de descente que le nombre a révélés** (Vincent, le jour
même) : les quatre voyageurs d'une caisse partaient tous de son centre — « ils
sont les uns sur les autres et cela n'a pas de sens » —, ils marchaient ensuite
comme un seul point, et ils longeaient l'axe du quai au lieu de sa bordure, « pas
le long du quai comme les autres voyageurs qui attendent ». Chacun sort
désormais de SA place, met pied à terre sur la bordure et marche où marchent les
autres ; et ils descendent l'un après l'autre, quelques secondes de jeu entre
deux — on ne vide pas une voiture d'un bloc. Le décalage coûte au plus 0,4
minute, soit moins que ce qui reste de la marge de trois minutes qui garantit
les correspondances.

**Une seule taille, et une file à chaque porte** (même jour). Le rayon d'une
pastille suivait la densité de son quai : bonne idée de géomètre, mauvaise idée
de jeu — « la taille des voyageurs est très différente d'un quai à l'autre, il
faut uniformiser ; j'en vois des trop petits ». Tout le monde fait désormais
quatre unités de rayon, sur le quai comme à bord : « la taille de départ mais
légèrement plus petit pour que ça passe dans le wagon à 4 ». Les quatre places
d'une caisse sont mesurées en unités du plan et non de l'écran tactile, faute de
quoi elles se chevauchaient au bureau.

Restait un voyageur plus gros que les autres, et c'était le cerne blanc de
« ceux-là montent », tracé à 1,45 fois le rayon : il grossissait le voyageur au
moment précis où on le regardait — « au moment où ils montent dans le train, ils
sont plus grands ». Le cerne **remplace** désormais le trait sombre au lieu de
s'ajouter autour : un voyageur fait la même taille du premier au dernier
instant, seule son encre change. Vérifié au pixel sur une capture de
Lille-Flandres : sept à huit pixels de diamètre sur le quai comme dans le wagon.

Et l'on monte **un par un, porte par porte** : ils partaient tous à l'instant de
l'arrêt, donc ensemble — « ils doivent rentrer un à un dans chaque wagon ; tout
doit sembler naturel ». Chacun attend son rang dans SA voiture, les quatre d'une
caisse se suivent, et les caisses se remplissent en même temps.

**On descend d'abord, on monte ensuite** (même jour) : « à l'arrivée du train,
les passagers qui étaient dans le train sortent en premier et dès qu'ils sont
tous sortis, les passagers sur le quai entrent dans le train ». C'est la règle de
tous les quais du monde, et les deux flux se croisaient. Le convoi n'embarque
donc plus tant qu'il lui reste quelqu'un d'assis — au plus le temps de la file
de descente, quatre dixièmes de minute, sur un arrêt qui en dure deux. Mesuré à
Gand et à Landen, graine 3 : un point d'écart sur Landen, rien sur Gand.

Mesuré, 21 services : de **84 à 184 voyageurs** par service, embarquement
médian 81 %, retard médian 5,8 min, étoiles 5 · 8 · 5 · 3.

**Et une découverte au passage** : depuis que le fret a disparu (§7), le joueur
au plus court **ne se bloque plus jamais** — zéro service au plafond de retard
sur 21, contre quinze sur trente-neuf auparavant, et un retard médian qui tombe
de 19,6 à 5,8 minutes. Ce n'était donc pas une impression : le fret était bien
ce qui faisait s'effondrer les journées.

---

## 9. Le comptage refait — tranché le 23 septembre 2026

« Il faut revoir le comptage des points et des récompenses. Pour le moment rien
n'est clair » (Vincent). La jauge mêlait dans un seul nombre ce qu'on gagne et
ce qu'on risque. Les deux axes se séparent, et les cinq questions posées ont été
tranchées :

1. **Les étoiles ne paient plus de pièces.** Elles disent l'heure tenue, rien
   d'autre — sans quoi le retard aurait continué d'en coûter, indirectement.
2. **Le rejeu ne paie que le progrès.** Rien à écrire : le solde est déduit de
   la progression, qui ne garde que le meilleur score.
3. **L'échec à trente minutes** — le seuil `une` de la fiche remplace le
   plafond de 120, qui laissait la partie continuer une heure et demie après
   qu'elle était perdue. On recommence le niveau.
4. **Le diamant demande les deux** : pas une minute de retard ET personne resté
   à quai.
5. **Vingt points pour une pièce**, soit quatre voyageurs.

Ce qui en découle est écrit dans `economie-du-jeu.md` §9 : le schéma de
sauvegarde passe à 10, chaque gare garde `bestPoints` et `bestMax`, et la
migration convertit les étoiles acquises en points, arrondie en faveur du
joueur.

Reste **l'impatience** (§5 du plan) : faire partir les voyageurs quand un train
tarde. Non fait, et volontairement — cela remettrait le retard à se payer en
points, c'est-à-dire à punir deux fois. Si l'on veut la lecture dans le hall,
le voyageur peut changer d'encre sans partir.

---

## 10. Ce qui reste à trancher

1. **La jauge reste-t-elle ?** Le §4 la rend lisible et discriminante ; c'est
   sur cette version-là qu'il faut rejouer trois ou quatre chapitres avant de
   décider.
2. **Le corrigé affiché** (§1) : 5.1 l'a réduit à un horizon de quelques
   convois. Reste à dire si ce qu'il en montre est encore trop — la question se
   tranche en jouant, pas en mesurant.
3. **Le voyageur têtu** (§1) : règle assumée, ou 5.4 ?
4. **Le barème du §4.2** : une minute de retard vaut-elle vraiment un
   voyageur ? C'est l'arithmétique de la jauge elle-même, mais elle durcit le
   jeu — et Vincent le trouvait déjà plus dur le 20 septembre.
5. **La carte d'atelier** (`essai`) : elle reste `enChantier` et se retire dès
   que le proto est tranché.

---

## Journal

- **20 septembre 2026** — le proto est écrit sur la branche (unités, marche,
  camembert, petite jauge à zéro central, carte d'atelier).
- **22 septembre 2026** — soixante services mesurés, ce document, et les sept
  correctifs du §4. Les 39 services du joueur au plus court ont été rejoués
  après coup, à graines identiques, pour mesurer ce que le nouveau barème
  déplace : sept étoiles perdues, aucune gagnée. `carte-check`, `net-check` et
  `boutique-check` repassés — aucune donnée n'a bougé, ils ne pouvaient rien
  dire d'autre, mais autant que ce soit écrit.
- **22 septembre 2026, le soir** — §5.1 : les voyageurs arrivent au fil de la
  journée. Une première fenêtre en minutes s'est révélée sans effet (dix-sept
  présents sur quarante-trois à l'ouverture) ; l'avance se compte désormais en
  convois. Troisième passage du banc, à graines identiques : rien ne bouge au
  score, ce qui était la condition.
- **22 septembre 2026, la nuit** — posé sur l'iPhone. Deux remarques de Vincent
  sur une capture de Clapham Junction, toutes deux vraies et toutes deux
  mesurables : les voyageurs semblaient appartenir au quai du dessous, et leur
  rangée collait à gauche. §4.7.
- **22 septembre 2026, plus tard** — chacun sa place sur le quai, tirée une
  fois : « possible de les afficher aléatoirement sur le quai et pas au milieu
  à chaque fois, avec cet effet qu'arrivé pousse les autres ? ». Posé à mi-pas
  avec un frisson de 22 %, le quai redevenait une règle graduée ; un tiers de
  pas dans les deux sens, et deux unités de haut, lui donnent sa foule.
- **22 septembre 2026, la fin** — §5.2, les correspondances. Un tiers des
  voyageurs descend d'un train, traverse la gare et va prendre sa place. Le
  retard se propage enfin d'un convoi à l'autre. Quatrième passage du banc :
  étoiles inchangées, embarquement de 86 à 84 %.
- **22 septembre 2026, tard** — le couloir sous les quais, la ville qui entre
  par sa bouche, et les voyageurs alignés sur le bord du quai. Trois remarques
  de Vincent sur le jeu posé, trois corrections : on ne traverse pas les voies,
  on ne paraît pas de nulle part, et on ne tangue pas sur un quai.
- **22 septembre 2026, au soir** — le fret et les fermetures de quai sont
  retirés (§7), après une partie de Vincent. Quatre balayages de `gen-check`,
  les deux oracles, `carte-check`.
- **23 septembre 2026** — quatre voyageurs par wagon (§8), et le barème
  quadruplé avec eux. La gare est pleine, et le banc montre que le retrait du
  fret avait déjà supprimé les effondrements.
- **23 septembre 2026, le soir** — le refoulement est remplacé par le convoi
  perdu : un mauvais quai fait repartir le train vers ailleurs, sans ses
  voyageurs, et éteint une étoile. Mesuré sur 20 services : le jeu devient plus
  DOUX (11 services à trois étoiles contre 5, retard médian de 6 à 4 min, aucun
  service qui perde une étoile), parce que le vrai coût du refoulement n'était
  pas sa sanction mais l'embouteillage qu'il provoquait.
