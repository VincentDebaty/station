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
4. **Les pastilles se comptent.** Rangées par destination (les couleurs ne
   sont plus mêlées) et groupées par cinq. L'ordre à l'intérieur d'une
   destination reste tiré au sort : la séquence des départs n'est toujours pas
   écrite sur le quai.
5. **La jauge se voit.** Le nombre passe de 12 à 18 px, la barre s'élargit, et
   le « +X » d'un convoi qui part passe de 18 à 26 px.
6. **L'embarquement sonne.** Une note grave (`puce`) quand un convoi prend des
   voyageurs, deux notes descendantes (`dommage`) quand il part à vide alors
   que des voyageurs pour sa destination attendent ailleurs. Une fois par
   convoi, jamais une fanfare.
7. **Le tutoriel dit la bonne règle** en mode jauge, et le commentaire périmé
   de `JAUGE_SECONDES_PAR_POINT` (« quinze secondes valent un point ») est
   corrigé.

Ce qui n'est **pas** touché : l'enclenchement, la génération, les brevets, les
cartes. Tout tient dans `vue_jeu.gd` et six lignes de `vue_ruban.gd`.

---

## 5. Les quatre idées qui en feraient une mécanique

Par coût croissant. Aucune n'est faite ; la première est la moins chère et
sans doute la plus payante.

### 5.1 Les voyageurs arrivent au fil de la journée

Aujourd'hui, tout le monde est là à 7 h 00. Une heure d'arrivée par unité et
un filtre au dessin suffisent à changer ça. Gains : le hall respire, le mur de
confettis disparaît, le corrigé ne se lit plus d'un coup, l'heure de pointe
existe, et le hall vide en fin de service devient une récompense visuelle.
Rien d'autre ne bouge — ni le calibrage, ni l'enclenchement.

### 5.2 Les correspondances

Un convoi qui **arrive** dépose des voyageurs pour d'autres directions. La
foule devient alors la conséquence de mon aiguillage, et non un décor posé
d'avance : la gare devient un flux. C'est, à mon sens, le « volume » que
cherche Vincent. Coût : une règle de dépôt dans la vue, et un plafond pour que
la journée reste finie.

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

## 7. Ce qui reste à trancher

1. **La jauge reste-t-elle ?** Le §4 la rend lisible et discriminante ; c'est
   sur cette version-là qu'il faut rejouer trois ou quatre chapitres avant de
   décider.
2. **Le corrigé affiché** (§1) : accepté comme aide au joueur, ou corrigé par
   5.1 (les voyageurs arrivent tard) ?
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
