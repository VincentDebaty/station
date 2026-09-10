# L'économie du jeu — pièces, diamants, et ce qu'on en fait

Écrit le 10 septembre 2026. **Les lots 1 (A, B, D) et 2 (C) sont livrés le
même jour** — voir `plan-de-dev.md`, lot G point 6, et `PORTAGE-GODOT.md`,
passes de la bourse et de la pierre. E reste une proposition. Le texte
ci-dessous est celui de l'analyse, conservé comme justification. Elle
répond à un constat de Vincent, capture à l'appui : « on ne se rend pas compte
qu'on gagne des crédits, "cr" ne veut pas dire grand-chose, et les diamants ne
servent à rien ». Elle mesure d'abord ce qui existe, puis propose cinq choses
qui se livrent séparément, et finit par les décisions à prendre.

Elle ne remplace ni `meta-progression-jeu-aiguillage.md` (§4 ter, §6, §7) ni
`plan-de-dev.md` (lot G, point 6 : « caler les trois barèmes ensemble »). Elle
est ce point 6, instruit. Une fois tranchée, ces deux documents se mettent à
jour et celui-ci devient leur justification.

---

## 1. Ce qu'on mesure aujourd'hui

Mesuré sur `jeu/vue_ruban.gd`, `jeu/vue_cartes.gd`, `jeu/recompense.gd` et
trois captures Godot faites sur une sauvegarde forgée (huit gares tenues,
20 étoiles, 2 sans-fautes, série de 3).

### 1.1 Les crédits tombent sans bruit

La remise des récompenses joue trois temps : les étoiles arrivent en grand et
rejoignent la feuille, la pierre fait de même sous son titre SANS FAUTE, puis
la puce de laiton part vers la ville suivante. Pendant tout ce temps, la
pastille « 30 cr » de la barre du haut **ne bouge pas**. Elle affiche déjà le
solde d'après, calculé au moment où le relevé s'ouvre. Rien ne dit « +8 ».
Aucun son, aucun chiffre qui roule, aucune ligne dans le relevé.

Le relevé du service tient en quatre lignes (ville, étoiles et retard, record
et objectif, deux médailles). **Les crédits n'y figurent pas.** La fête de
chapitre non plus : « 12 / 15 ★  1 ◆ », le rang, ce qui reste, la zone, les
médailles — mais pas les 20 crédits du chapitre d'or qui viennent de tomber, ni
les 100 de la zone.

C'est le seul compteur du jeu qui n'a **aucun moment**. Les étoiles ont leur
vol, le diamant sa gerbe, les médailles leur ligne dorée, la série sa pastille.
Le crédit n'a que son solde.

### 1.2 « cr » ne nomme rien

« 30 cr », « Passer · 8 cr », « Il te manque 5 crédits », « Ouvrir · 1500 CR ».
Un *crédit* est un mot de banque et d'école ; il ne désigne aucun objet, il
n'a pas de forme, on ne peut ni le dessiner ni le faire tinter. Dans un jeu
dont l'idiome est le laiton, le parchemin, le sceau cerclé et la pierre
taillée facette par facette, c'est le seul mot abstrait de l'écran. Le
diamant a gagné le droit d'être un objet le 9 septembre (« il est petit et
discret alors que c'est la plus haute récompense ») ; la monnaie ne l'a
jamais eu.

### 1.3 L'échelle est trop petite pour être ressentie, et l'argent tombe là où on ne regarde pas

Le barème (`recompense.gd`, `CREDIT_PAR_*`) :

| source | crédits |
|---|---|
| une étoile | 1 |
| un sans-faute | 5 |
| un chapitre d'or | 20 |
| une zone traversée | 100 |
| une carte terminée | 500 |

Un service rapporte donc **1, 2 ou 3 crédits**, 8 avec un sans-faute. Un
chiffre à un seul chiffre ne se lit pas comme un revenu, quel que soit
l'habillage. Et sur les 2 711 crédits que rapporte l'Europe entière en or,
**831 seulement (31 %) viennent des étoiles** — les 1 880 autres tombent en
trois sommes (chapitre, zone, carte) à des moments qui sont fêtés pour
*autre chose*. Le joueur voit ses pièces arriver goutte à goutte, puis un jour
le solde a fait un bond sans qu'il sache pourquoi.

Rejouer une gare pour améliorer un record ne rapporte **rien** tant que le
nombre d'étoiles ne change pas : « record battu · −3 min » est une ligne
gratuite. Or le design fait reposer toute la soupape sur le retour en
arrière (« le joueur à court de crédits va rejouer ses vieilles gares »).

### 1.4 Le diamant est un trophée qui ne sert à rien

Un sans-faute vaut : 5 crédits, un cran bleu dans la jauge de chapitre, une
part du rang « chapitre de diamant », trois médailles d'accumulation (5, 15,
40) et un compteur en barre du haut. Tout cela est **honorifique**. Le
diamant ne s'échange contre rien, n'ouvre rien, ne débloque rien. Vincent le
dit : « ils pourraient servir à quelque chose ».

Le design l'a voulu ainsi (« le diamant reste absolu, la seule mesure
comparable d'un bout à l'autre du jeu, et la vraie chasse de fin de partie »)
— c'est une bonne raison de ne pas le *dévaluer*, pas une raison de le laisser
inutile.

### 1.5 La soupape est écrite, pas montrée

Trois règles fines de §4 ter sont invisibles à l'écran :

- **La mise est rendue** quand on revient gagner une gare payée. C'est
  l'argument même du passage payant (« une avance, pas une amende ») — et
  rien ne l'annonce : le solde remonte silencieusement.
- **« Rejoue une gare déjà faite pour les gagner »** ne dit ni laquelle ni
  combien. Le joueur ne sait pas qu'une gare à une étoile en cache deux, ni
  ce que ça vaut.
- La fête dit « 3 étoiles à prendre ici », jamais ce que ça rapporte.

### 1.6 Ce qui est bon, et que rien ci-dessous ne casse

- **Tout se déduit, rien ne se stocke.** Le solde est gagnés − dépensés, les
  deux termes calculés depuis `{stars, bestDelay}` par gare, `passees` et
  `possedees`. On peut changer tout le barème sans toucher `SCHEMA_VERSION`.
  C'est ce qui rend les propositions A, B et D gratuites en migration.
- **Jamais de vies, jamais de minuterie**, rejeu illimité et gratuit. La
  soupape est une option posée à côté de *Réessayer*, pas un mur.
- **Une gare payée reste à zéro étoile.** On ne s'achète pas un chapitre d'or.
- **Deux symboles, deux sens** : ◆ est le diamant, jamais la monnaie.
- **La première carte est gratuite et complète**, les suivantes se paient en
  crédits ou par achat intégré. Le modèle commercial est déjà là : il ne
  manque que la monnaie qui le rend désirable.

---

## 2. Proposition A — La pièce d'or remplace le crédit

**Le crédit devient une pièce.** Un objet, dessiné comme la pierre l'est : une
classe `Piece` à côté de `Gemme`, un disque de laiton frappé en relief (une
roue ailée, ou le chiffre d'une compagnie), un éclat sur la tranche. La même
pièce partout — pastille de la barre, vol de la remise, ligne du relevé,
boutons — pour qu'on ne puisse jamais croire qu'il y en a deux.

**Le mot.** *Pièces*, tout court ; « pièces d'or » dans le tutoriel la première
fois, puis jamais plus. Les écritures :

| aujourd'hui | proposé |
|---|---|
| `30 cr` (pastille) | `◎ 30` — la pièce dessinée, puis le nombre, comme la pastille du diamant |
| `Passer · 8 cr` | `Passer · 8 pièces` |
| `Il te manque 5 crédits — rejoue une gare déjà faite pour les gagner.` | `Il te manque 5 pièces. Rejouer Doncaster peut en rapporter 20.` (voir D) |
| `Ouvrir · 1500 CR` | `Ouvrir · 15 000 pièces` |
| `prixCredits` (JSON de carte) | `prix` — le champ change de nom une fois, dans deux fichiers |

**Le contrat couleur tient.** La pièce est laiton, comme la pastille et la puce
qui traverse déjà la voie ; l'étoile reste or plat, la pierre reste bleue. Trois
objets, trois formes (disque, étoile, pierre taillée), et la couleur de
destination des convois n'est concurrencée par aucun des trois : ils ne
vivent que dans le panneau et la barre.

**Pourquoi une pièce et pas un jeton, un florin, un louis.** Un mot d'époque
demande une explication ; une pièce n'en demande aucune, à dix ans comme à
cinquante. Et une pièce *tinte* — c'est ce qui rend D possible.

Coût : un renommage dans `recompense.gd` / `recompense.js`, les deux écrans,
les deux cartes JSON, `tools/oracle-ruban.mjs`. Zéro migration.

---

## 3. Proposition B — Le barème, multiplié par dix, et deux revenus qui manquaient

### 3.1 Le principe

**On garde les rapports, on change l'unité.** Les rapports sont l'invariant
mesuré (« un passage ≈ trois à cinq gares bien jouées », « finir l'Europe paie
la deuxième carte avec de la marge ») ; les valeurs absolues, elles, ne
répondent qu'à une question de perception. Une gare qui rapporte 30 pièces
au lieu de 3 se joue exactement pareil, mais le compteur *bouge*.

### 3.2 Le barème proposé

| source | aujourd'hui (cr) | proposé (pièces) | déduit de |
|---|---|---|---|
| une étoile | 1 | **10** | `stars` |
| **chaque minute sous le seuil des 3 ★** (nouveau) | — | **1**, de 0 à 12 | `bestDelay` et le barème de la gare |
| un sans-faute | 5 | **1 diamant** (voir C) — ou 50 pièces si C est refusée | `bestDelay == 0` |
| un chapitre d'or | 20 | **200** | rang du chapitre |
| un chapitre de diamant (nouveau) | — | **+3 diamants** — ou 500 pièces si C est refusée | rang du chapitre |
| une zone traversée | 100 | **1 000** | complétion de zone |
| une carte terminée | 500 | **5 000** | complétion de carte |
| **une médaille** (nouveau) | — | **50 / 150 / 500** selon sa rareté | `medailles_de(etat)` |
| prix d'un passage | 5 + 3 × chapitre | **50 + 30 × chapitre** | position |
| prix du *Grand tour du Rhin* | 1 500 | **15 000** | définition de carte |

Tout reste **déduit**. Les deux revenus nouveaux le sont aussi :

- **La précision** se lit dans `bestDelay`, qui est déjà stocké pour le record
  et le diamant. Elle donne enfin un prix au « record battu · −3 min » (trois
  pièces), c'est-à-dire au *rejeu* — la boucle que la soupape suppose et que
  rien ne paie aujourd'hui. Plafond : 12 pièces par gare, 3 324 sur l'Europe,
  un dixième du revenu, gagné surtout par ceux qui reviennent.
- **Les médailles** sont déjà déduites et déjà fêtées. Les payer met une
  bourse sur des moments qui existent. Les vingt-six valent environ 5 000
  pièces en tout (neuf communes à 50, onze rares à 150, six « toutes / ultimes »
  à 500) : un cinquième du revenu de la carte, réparti là où on regarde.

### 3.3 Ce que ça donne, mesuré sur l'Europe

| | aujourd'hui | proposé |
|---|---|---|
| un premier service à 1 ★ | 1 cr | 10 pièces |
| un premier service à 3 ★, 9 min sous un seuil de 12 | 3 cr | 33 pièces |
| un sans-faute | 8 cr | 42 pièces + 1 diamant |
| un premier chapitre d'or (5 gares) | 35 cr | ≈ 640 pièces (150 ★, ~40 précision, 200 or, trois médailles ≈ 250) |
| passage au chapitre 1 / 10 / 48 | 5 / 35 / 149 | 50 / 350 / 1 490 |
| l'Europe entière en or, sans sans-faute | 2 711 | ≈ 32 000 (27 110 + médailles ≈ 3 500 + précision ≈ 1 500) |
| prix de la deuxième carte | 1 500 | 15 000 |

La contrainte tenante de §7 (« finir l'Europe doit payer la deuxième carte,
même après quelques passages achetés ») reste tenue avec la même marge — et
un peu plus, grâce aux médailles. Dix passages au milieu du ruban coûtent
≈ 7 700 ; il reste 24 000 pièces, de quoi ouvrir le Rhin et garder une réserve.

Le mur du débutant (§4 ter) ne bouge pas : au chapitre 1, cinq gares à une
étoile font 50 pièces, le passage en coûte 50. Exactement le rapport
d'aujourd'hui (5 pour 5).

### 3.4 Coût

Les constantes de `recompense.gd` et `recompense.js` — **ensemble**, parce
que `tools/oracle-ruban.mjs` et `jeu/oracle_ruban.gd` comparent les deux et
c'est ce qui garantit qu'on n'a pas dérivé. `credits_d_une_carte` gagne deux
termes et, pour D, une variante qui rend le **détail** (un dictionnaire
étoiles / précision / or / zones / carte / médailles) au lieu de la somme.
Zéro migration : un joueur existant voit son solde multiplié par dix au
premier lancement, ses passages payés aussi, et le rapport entre les deux est
le même.

---

## 4. Proposition C — Le diamant : un trophée qu'on garde, ou une pierre qu'on dépense

C'est la décision la plus lourde du document, et la seule qui touche la
sauvegarde. Elle se prend séparément de A, B et D.

### 4.1 Séparer ce qui se compte de ce qui se tient en poche

Le diamant a deux natures qu'on confond aujourd'hui dans un seul compteur :

- **le sans-faute**, un fait de progression : cette gare a été tenue sans une
  minute de retard. Il vit sur la carte (le sceau sous la gare), dans la jauge
  du chapitre (le cran bleu), dans le rang « chapitre de diamant », dans les
  médailles *Cinq diamants / Écrin / Coffre-fort*. Il se déduit de `bestDelay`,
  il est absolu, **il ne s'achète jamais et ne se dépense jamais** — c'est
  §2.1, et on n'y touche pas ;
- **la pierre**, l'objet que ce sans-faute a produit. Elle, on peut la garder
  ou la dépenser, exactement comme les étoiles produisent des pièces qu'on
  dépense sans que les étoiles disparaissent. Le stock en poche est déduit
  comme les pièces : *gagnées − dépensées*.

Le compteur de la barre du haut devient **les pierres en poche**. Le trophée,
lui, reste lisible partout où il l'est déjà, et la médaille *Coffre-fort* (40
sans-fautes) se décroche même si l'on a tout dépensé.

### 4.2 Ce qu'une pierre achète

1. **Un passage**, quand les pièces manquent — `ceil(prix en pièces / 50)`
   pierres : une au chapitre 1, sept au dixième, trente au dernier. C'est la
   soupape de la soupape : le joueur à court de pièces qui a fait des
   sans-fautes en a une réserve, et la fin du ruban reste hors de prix. La
   gare passée reste à zéro étoile, en pièces comme en pierres.
2. **Sous le moteur, des objets** : une livrée de pupitre (laiton, acajou,
   ardoise), une planche d'illustration de rechange pour un chapitre, un
   cadran d'horloge. Jamais rien qui touche le contrat couleur des convois.
   Ce point n'est pas pour le prototype : il est écrit pour que le schéma de
   sauvegarde le prévoie.

Et ce qu'elle **n'achète jamais** : une étoile, un rang, une médaille, une
carte. La carte se paie en pièces ou en argent — la pierre est la récompense
de l'excellence, pas la clé du contenu.

### 4.3 Ce que ça coûte

`SCHEMA_VERSION` **8**, avec trois champs, tous vides à la migration :

```
achats:     { diamants: number }              // pierres achetées, en tout (E)
passeesEnPierres: FicheId[]                   // passages payés en pierres, à côté de `passees`
possessions: { [objetId]: "diamants" | "achat" }   // les objets de 4.2, plus tard
```

Le stock en poche = sans-fautes + 3 × chapitres de diamant + `achats.diamants`
− Σ prix en pierres des `passeesEnPierres` **encore à zéro étoile** (la mise
se rend, comme pour les pièces) − Σ prix des `possessions` payées en pierres.
Un cas de plus dans `tools/oracle-sauvegarde.mjs` et `jeu/oracle_sauvegarde.gd`.

### 4.4 Si C est refusée

Le diamant reste un trophée, et il faut quand même qu'il *serve* : la
solution minimale est de lui rendre ses pièces (50 par sans-faute, 500 par
chapitre de diamant) et de le faire **ouvrir** quelque chose sans le
consommer — par exemple, à dix sans-fautes, une livrée ; à quarante, un
titre. Ce sont des médailles avec une récompense visible. Moins riche,
mais cohérent, et sans migration.

---

## 5. Proposition D — La bourse : le quatrième temps de la remise, et cinq moments

La remise a trois temps depuis le 9 septembre. Les pièces sont le
**quatrième**, et le plus court. Puis quatre autres moments, tous là où le
jeu parle déjà.

### 5.1 Le temps de la bourse (0,8 s)

Les étoiles sont posées, la pierre aussi. Une ligne apparaît dans le relevé,
sous le retard : **« + 33 pièces »** en laiton, et à sa droite, en muet, le
détail sur un mot (« 3 ★ · 3 min d'avance »). De cette ligne, des pièces
s'élèvent — six à dix, jamais une par pièce gagnée, le nombre suit le
logarithme du gain — et décrivent un arc vers la pastille de la barre. À
chaque arrivée la pastille **sursaute** (échelle 1,15 → 1) et son nombre
**roule** d'un cran vers le solde d'après ; un **tintement** par pièce, sur
une hauteur qui monte d'une à l'autre, et un accord bref quand la dernière se
pose. Un doigt abrège tout, comme les trois temps d'avant.

Deux règles reprises de la remise existante : la place d'arrivée est **lue**
sur la pastille, jamais calculée ; la couche de vol est le dernier enfant de
la vue. Et une troisième : **le solde ne s'écrit à la pastille qu'à
l'atterrissage** — jusqu'ici elle affiche le solde d'avant, comme les étoiles
sont masquées jusqu'à leur pose.

Le montant est un **delta**, `solde après − solde avant`, pris dans
`app.fin_de_service` de part et d'autre de l'écriture de la progression. Un
rejeu qui n'améliore rien donne zéro, et la ligne ne s'affiche pas.

### 5.2 La fête de chapitre : le butin, itemisé

Sous « 12 / 15 ★  1 ◆ », une ligne **« Butin du chapitre · 620 pièces »** dont
le nombre *monte* pendant qu'une pluie de pièces rejoint la pastille, puis le
détail en petit : « 150 étoiles · 40 précision · 200 chapitre d'or · 230 en
médailles ». Chaque médaille listée porte sa bourse à droite (« Voie royale —
un chapitre d'or · 150 »). Le joueur apprend le barème en le recevant : c'est
la seule pédagogie qui tienne.

### 5.3 Ce qui reste à prendre, en pièces

La fête dit « 3 étoiles à prendre ici ». Elle dira **« jusqu'à 60 pièces à
prendre ici »**. Et l'échec dira **« Il te manque 5 pièces. Rejouer Doncaster
peut en rapporter 20. »** — la gare du chapitre courant qui a le plus grand
manque à gagner, calculé depuis son barème et sa progression. Le bouton
*Rejouer* de cette gare le rappelle : « Rejouer · Doncaster · +20 ». C'est la
règle « retourner dorer » enfin dite au joueur, avec un chiffre et un nom.

### 5.4 Payer, et être remboursé

- **Passer · 50 pièces** : les pièces quittent la pastille vers le bouton,
  le nombre roule vers le bas, un son mat. Une gare payée sur la carte porte
  un petit disque de laiton **vidé** à côté du cercle — la mise avancée est
  visible tant qu'elle n'est pas rendue.
- **Mise rendue** : quand la gare est enfin gagnée, le relevé porte une ligne
  de plus, **« Mise rendue · + 50 pièces »**, et les pièces reviennent depuis
  la gare sur la carte vers la pastille, avant celles du service. La règle la
  plus élégante de §4 ter devient un moment.
- **Ouvrir · 15 000 pièces** (écran des cartes) : même sortie de pièces, puis
  l'entrée dans la carte — on ne revient pas à la liste, comme aujourd'hui.

### 5.5 La pierre, quand C est prise

Une pierre dépensée quitte la pastille avec sa gerbe à l'envers (les rais se
referment) ; le sceau sur la carte, lui, ne bouge pas. Le joueur voit la
différence entre ce qu'il a fait et ce qu'il a en poche.

### 5.6 Les sons

`jeu/sons.gd` cuit ses signatures ; il en manque trois : **« piece »** (un
tintement clair, 60 ms, sinus riche entre 1,2 et 1,8 kHz, joué à une hauteur
qui monte d'une pièce à l'autre), **« bourse »** (l'accord de fin, deux
tons, 200 ms) et **« depense »** (le même tintement, mat, une octave sous).

### 5.7 Coût

Tout est prototype Godot, dans l'idiome existant : `Vol` gagne une séquence
« pieces », `_bloc_bilan` deux lignes, `_bloc_fete` une, `_pied` un chiffre.
La pièce dessinée est une classe de soixante lignes sur le modèle de `Gemme`.
La partie règle (le delta et le détail) est dans `recompense` et vérifiée par
l'oracle. `STATION_REMISE=<étoiles>[,diamant][,pieces=N]` permet de la
photographier sans jouer.

---

## 6. Proposition E — Ce qui se vend, et ce qui ne se vend jamais

Le design a déjà tranché l'essentiel : première carte gratuite et complète,
pas de vies, pas de minuterie, une gare payée à zéro étoile. Ce qui suit ne
fait que nommer le modèle qui en découle et fixer ses ordres de grandeur.
**Le paiement réel reste hors prototype** (plan-de-dev, « Ce qu'on ne fait
pas ») : ce chapitre est écrit pour que le schéma de sauvegarde et l'écran
des cartes le prévoient.

### 6.1 Le modèle : gratuit, cartes payantes, pierres en option

| ce qui se vend | à quoi ça sert | ordre de grandeur |
|---|---|---|
| **Une carte** (le Rhin, puis d'autres) | le contenu — le revenu principal, honnête, sans pression | 2,99 – 4,99 € l'une, ou ses 15 000 pièces |
| **Des pierres** | passer une gare qui bloque ; sous le moteur, les objets de 4.2 | 20 pour 1,99 €, 60 pour 4,99 €, 150 pour 9,99 € |
| **Un « pack du poste »** (plus tard) | toutes les cartes présentes et à venir, en un achat | 9,99 – 14,99 € |

Ce qui **ne se vend jamais** : des pièces (ça vide la boucle « retourner dorer »,
qui est le jeu), des étoiles, des rangs, des médailles, du temps. Et la pierre
achetée ne se distingue pas de la pierre gagnée *en poche*, mais elle ne
produit **aucun sans-faute** sur la carte : le trophée reste intouchable.

### 6.2 Le garde-fou, chiffré

Un joueur qui achèterait tous ses passages jusqu'au bout de l'Europe paierait
environ 750 pierres (49 chapitres, une quinzaine de pierres en moyenne),
soit une cinquantaine d'euros — pour un ruban à **zéro étoile**, aucun
rang, aucune médaille, et une carte qu'il ne peut même pas ouvrir avec ça.
C'est le prix de la voie sans gloire, et c'est voulu : on ne s'achète pas un
chapitre d'or.

### 6.3 L'alternative, à trancher

Un jeu **payant** (un prix, tout compris, les cartes en extensions) est
l'autre modèle cohérent avec « jamais de vies ». Il est plus simple, plus
honnête pour un jeu testé par des enfants, et il vend moins. Si c'est celui-là,
la proposition C reste utile (les pierres achètent des passages et des objets,
mais ne s'achètent pas), et E se réduit à la première ligne du tableau.

---

## 7. Dans quel ordre, et ce qui le garde

| lot | contient | migration | contrôles |
|---|---|---|---|
| **1** | A + B + D — la pièce, le barème, la bourse | aucune | `oracle-ruban` (js ↔ gd, valeurs recalées ensemble), `oracle-sauvegarde` inchangé, `carte-check` inchangé, trois captures `STATION_REMISE` |
| **2** | C — la pierre en poche | schéma 8 | `oracle-sauvegarde` : un cas v7 → v8 et un cas avec `passeesEnPierres` ; `oracle-ruban` : le stock |
| **3** | E — le paiement réel | aucune de plus (les champs sont ceux de C) | sous le moteur, avec le magasin de la plateforme |

Le lot 1 se livre seul et règle le constat de départ. Le lot 2 attend une
décision. Le lot 3 attend le moteur.

Documents à mettre à jour quand c'est tranché : `meta-progression` §2.1
(la règle des deux symboles devient celle des trois objets), §7 (le barème)
et §8 (le schéma 8) ; `plan-de-dev` lot G point 6, clos par ce document ;
`PORTAGE-GODOT` §4, où le barème des pièces rejoint les invariants ;
`data/cartes/README.md` pour `prix` ; `tools/AUTHORING-CARTES.md`.

---

## 8. Les décisions à prendre

1. **Le mot et l'objet** (A) : *pièces*, dessinées en laiton, écrites
   `◎ 30` dans la barre et « 8 pièces » dans les boutons. Oui, ou un autre
   mot ?
2. **L'unité** (B) : ×10, tous les rapports gardés. Oui ?
3. **La précision paie** (B) : une pièce par minute sous le seuil des trois
   étoiles. C'est ce qui donne un prix au rejeu. Oui ?
4. **Les médailles paient** (B) : 50 / 150 / 500. Oui ?
5. **La pierre se dépense** (C) : trophée sur la carte, stock en poche, un
   passage contre `prix / 50` pierres. Oui, ou le diamant reste un trophée
   qui *ouvre* (4.4) ?
6. **Le modèle** (E) : gratuit avec cartes payantes et pierres en option, ou
   jeu payant avec cartes en extension ?

Les quatre premières se livrent ensemble, sans migration, et suffisent à ce
que le joueur *voie* qu'il gagne. Les deux dernières engagent la sauvegarde et
le commerce : elles peuvent attendre.
