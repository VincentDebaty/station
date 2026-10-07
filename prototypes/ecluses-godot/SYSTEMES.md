# Écluses — le catalogue des systèmes qui déplacent l'eau

Vincent, 7 octobre 2026 : l'écluse est la base du jeu. Il faut lister tout ce
qui pourrait faire bouger l'eau, puis l'essayer **un système à la fois**. La
règle de départ reste celle du 6 octobre : varier les mécanismes sans entrer
dans la complexité.

**L'autorité sur les règles est le moteur de la page web**
(`prototypes/prototype-ecluses.html`) et son banc
(`node tools/ecluses-banc.mjs`). Godot ne fait que porter ce moteur, vérifié
par l'oracle. Un système n'existe donc qu'une fois écrit dans la page et
passé au banc.

## Le modèle, en deux phrases

Le canal est une **rangée de bassins** vus en coupe. Chaque bassin a un fond,
une largeur et un niveau. Entre deux voisins, une **liaison** a un **seuil** :
l'eau au-dessus du seuil passe d'un côté à l'autre jusqu'à égaliser, celle qui
est dessous reste. L'eau ne se crée pas et ne se perd pas, sauf par le fleuve
(apport à chaque coup) et la mer (niveau constant).

Tout système nouveau se range dans l'une de ces familles :
- **un seuil qui change** (porte, digue, hausse) : rien de neuf dans le
  calcul de l'eau ;
- **une liaison qui sort de la rangée** (siphon, bassin d'épargne) : il faut
  étendre le modèle ;
- **de l'eau qui monte ou qui entre** (pompe, marée) : une exception à la règle
  « l'eau ne remonte jamais », à doser ;
- **un bateau qui bouge sans l'eau** (ascenseur, plan incliné).

## Le tableau

| # | Système | Le geste | Ce que le joueur décide | État | Coût |
|---|---|---|---|---|---|
| 1 | Porte simple | toucher la roue | l'ordre des ouvertures, avec une eau comptée | **existe** (chap. 1) | — |
| 2 | Digue à creuser | un coup de pelle = un cran | jusqu'où l'eau pourra monter, sans retour | **existe** (chap. 2) | — |
| 3 | Mur, déversoir fixe | aucun | rien : il borne un niveau | **existe** | — |
| 4 | Passage libre | aucun | rien : la même eau des deux côtés | **existe** | — |
| 5 | Barrage à lâcher | un coup, une fois | quand le chantier est prêt | **existe** (chap. 2) | — |
| 6 | Fleuve et crue | attendre un coup | le temps : l'eau arrive toute seule | **existe** (chap. 3) | — |
| 7 | Mer | aucun | rien : une source et un puits sans fond | **existe** (chap. 3) | — |
| 8 | Porte à vanne | vanne, puis porte | égaliser sans laisser passer, retenir un bateau | **écrite** (chap. 2, niveau 2-1, 7 octobre 2026) | moyen |
| 9 | Hausses mobiles | monter ou baisser un cran | un seuil réglable, réversible | **écartée** par Vincent le 7 octobre 2026 (« pratiquement la même chose qu'une porte ») ; la règle reste au moteur | faible |
| 9 bis | Rigole | un coup de pelle dans une berge de terre | doser l'eau d'un étang, sans retour | **écrite** (chap. 3, niveau 3-1, 7 octobre 2026) : la digue du moteur, jouée en direct | faible |
| 10 | Clapet | aucun | rien : l'eau ne passe que dans un sens | à écrire | faible |
| 11 | Pompe | un coup = un volume qui monte | quand dépenser un coup pour remonter de l'eau | **écrite** (chap. 4, niveau 4-1, 7 octobre 2026) | faible |
| 12 | Marée | aucun (la mer monte et descend) | le bon moment | à écrire | faible |
| 13 | Siphon | l'amorcer | faire passer l'eau par-dessus un mur | à écrire | moyen |
| 14 | Ascenseur à bateaux | un coup | monter un bateau sans dépenser d'eau | à écrire | moyen |
| 15 | Bassin d'épargne | une vanne latérale | garder de l'eau pour plus tard | à écrire | fort |
| 17 | Chaudière (vapeur) | un coup = un volume qui part en fumée | quand se débarrasser d'une eau qui menace le village | **écrite** (chap. 5, niveau 5-1, nuit du 7 au 8 octobre 2026) | faible |

Les **objectifs** ne déplacent pas l'eau mais s'y ajoutent : bateau à
conduire, champ à irriguer (« cible »), village à épargner (« tolere »).

## Les systèmes à écrire, un par un

### 8. Porte à vanne — vanne et porte séparées
- **On voit :** la vanne dans son aqueduc, sous le fond, et la porte. Le
  rendu existe déjà : c'était l'écluse de Godot jusqu'au 7 octobre
  (`aqueduc.gd`, liaison `"vanne": true`).
- **La règle :** la vanne ouverte, l'eau égalise sous la porte close (le seuil
  de l'eau est bas, mais pas celui des bateaux). La porte ne se lève que si
  les deux eaux sont égales, et les bateaux ne passent que porte levée.
- **Ce que ça apporte :** égaliser sans laisser passer, retenir un bateau dans
  un sas pendant qu'on prépare l'autre côté.
- **Risque :** deux touches pour un passage. Le décompte des coups (« par »)
  augmente, et la règle « la porte ne se lève pas » doit se voir : roue
  bloquée, petit cadenas, ou l'eau qui pousse la porte.
- **Coût :** un état de plus par liaison dans le moteur (page web et Godot),
  le banc, l'oracle à régénérer.

### 9. Hausses mobiles — un seuil réglable

**Écrite le 7 octobre 2026** (chapitre 3, niveau 3-1 « Les planches »). Le
solveur l'a montré : dans un niveau, retirer des planches compte, en remettre
presque jamais (l'eau passée ne revient pas). Le 3-1 enseigne donc le DOSAGE :
trois planches exactement, sinon le village est inondé.
- **On voit :** des planches empilées sur un mur, qu'on ajoute ou qu'on
  retire.
- **La règle :** comme une digue, mais réversible, d'un cran vers le haut ou
  vers le bas, entre un minimum et un maximum.
- **Ce que ça apporte :** retenir de l'eau puis la relâcher plus tard. C'est
  la digue du chapitre 2, sans l'irréversible.
- **Coût :** faible, une action de plus sur un seuil qui existe.

### 10. Clapet anti-retour
- **On voit :** un volet sur un passage, qui ne s'ouvre que d'un côté.
- **La règle :** l'eau ne passe que du bassin A vers le bassin B. Le calcul
  par paire (`paire()`) ignore le sens interdit.
- **Ce que ça apporte :** un piège ou une aide passive. L'eau entre dans un
  bassin et n'en ressort pas.
- **Coût :** faible. **Risque :** il faut un sens bien visible.

### 11. Pompe
- **On voit :** une pompe à bras ou une roue, reliant un bassin bas à un
  bassin haut.
- **La règle :** un coup transfère une unité de volume du bas vers le haut,
  si le bas en a.
- **Ce que ça apporte :** la seule exception à « l'eau ne remonte jamais ».
  Elle coûte des coups, donc des étoiles. À limiter : par exemple une pompe à
  trois coups, ou une seule par niveau.
- **Coût :** faible, une action.

### 12. Marée
- **On voit :** la mer qui monte et descend, avec une échelle de marée.
- **La règle :** la mer reste un bassin fixe, mais son niveau suit une suite
  connue d'avance, un pas par coup (par exemple 1, 2, 3, 2, 1…).
- **Ce que ça apporte :** le moment juste pour ouvrir la porte de mer.
- **Coût :** faible, le niveau de la mer devient fonction du nombre de coups.
  **Risque :** le joueur doit voir venir la marée (une jauge, ou la suite
  affichée).

### 13. Siphon
- **On voit :** un tuyau en U renversé, par-dessus un mur, avec un robinet
  d'amorçage.
- **La règle :** une fois amorcé, il égalise deux bassins par-dessus leur
  séparation, tant que l'eau du côté haut couvre son entrée. Il peut relier
  des bassins non voisins.
- **Ce que ça apporte :** déplacer de l'eau sans ouvrir de porte, enjamber un
  bassin.
- **Coût :** moyen. Une liaison entre bassins non voisins sort de la rangée :
  `equilibrer()` doit traiter un graphe.

### 14. Ascenseur à bateaux, plan incliné
- **On voit :** un bac plein d'eau qui monte et descend entre deux biefs
  (Strépy-Thieu, ou le plan incliné de Ronquières).
- **La règle :** un coup fait passer le bac d'un bief à l'autre, avec le
  bateau qui est dedans, sans échanger d'eau. Variante à deux bacs avec
  contrepoids : l'un ne monte que si l'autre descend.
- **Ce que ça apporte :** monter un bateau quand l'eau manque. C'est la
  réponse aux blocages « il manque de l'eau ».
- **Coût :** moyen : un objet qui transporte un bateau, et un nouveau type de
  liaison.

### 15. Bassin d'épargne
- **On voit :** un bassin à côté du sas, à mi-hauteur, relié par une vanne.
  En vue oblique, il peut se tenir **derrière** le sas, dans la profondeur.
- **La règle :** on vide la moitié haute du sas dans le bassin d'épargne au
  lieu de la perdre vers l'aval, puis on la reprend pour remplir le sas.
- **Ce que ça apporte :** économiser l'eau du bief amont, la ressource rare
  des chapitres 1 et 3. C'est une vraie technique d'écluse.
- **Coût :** fort. Un bassin hors de la rangée oblige à étendre le modèle,
  comme le siphon.

### 16. Déversoir et débordement hors du canal (idée du 7 octobre 2026)
- **Né d'un essai de Vincent :** il voulait faire déborder le bief amont du
  4-1 en pompant. Aujourd'hui, le surplus passe par-dessus la porte fermée
  (c'est la règle, rendue visible le 7 octobre) et rien ne quitte le canal.
- **Variante A, le déversoir :** une échancrure dans le mur d'un bassin, avec
  une rigole vers un fossé. Le niveau ne dépasse jamais le déversoir, et
  l'excès est perdu. C'est une liaison vers un bassin « puits ».
- **Variante B, le débordement sur le pré :** l'eau passe par-dessus le mur du
  bassin et s'étale. S'il y a un village de ce côté, il est inondé. C'est un
  piège pour un niveau de pompe : pomper trop inonde le village.
- **Coût :** faible pour A (un bassin fixe comme puits, comme la mer) ;
  moyen pour B (de l'eau qui sort du jeu, le banc doit l'admettre comme une
  « sortie »).

### 17. La chaudière — la vapeur (nuit du 7 au 8 octobre 2026)
- **On voit :** une petite chaudière de cuivre sur la berge du fond, son
  tuyau qui descend dans le bief, le feu qui couve, un filet de fumée.
- **La règle :** un coup (« chauffer ») fait partir « debit » d'eau du
  bassin en vapeur (`objets`, type `chaudiere`). Le pendant de la pompe :
  elle ne remonte pas l'eau, elle la fait disparaître.
- **Le niveau 5-1 :** un bateau descend, l'autre monte, et le bief aval est
  au ras de la levée du village. Vidé tel quel, le sas l'inonde : il faut
  faire bouillir juste assez du bief aval (deux coups), et pas plus, car le
  bateau qui monte a besoin de cette eau.

### Écartés pour l'instant
- **Moulin, roue à aubes** qui actionnerait autre chose quand l'eau y passe :
  un enchaînement de causes, trop loin de « sans complexité ».
- **Pluie, évaporation, fuite** : de l'eau qui entre ou sort sans geste ni
  calendrier. Le joueur ne peut ni la prévoir ni la contrer.

## Comment on essaie un système

1. **La règle dans la page web**, en quelques lignes du moteur, avec son
   action dans `actions()` et son effet dans `jouer()`.
2. **Deux ou trois niveaux d'essai**, avec leur `par` et le système dans
   `requis`. Le banc refuse si le système ne sert pas vraiment (le niveau
   doit devenir impossible ou plus long sans lui), ou si `par` n'est pas la
   meilleure solution.
3. **Vincent y joue** dans la page web, sur l'iPhone par l'artefact privé
   comme pour Nuit de fête. On garde, on règle ou on jette.
4. **Seulement s'il est gardé**, on le porte dans Godot :
   - le moteur ;
   - `node tools/ecluses-vers-godot.mjs` ;
   - l'oracle doit rester vert ;
   - le rendu, puis l'iPhone.

## L'ordre proposé

Du moins cher au plus cher, en commençant par ce qui s'appuie sur l'existant :
1. **Porte à vanne (8)** : le rendu Godot existe déjà, et c'était ta question
   de départ.
2. **Hausses mobiles (9)** et **clapet (10)** : deux seuils de plus, presque
   rien à écrire.
3. **Pompe (11)** et **marée (12)** : deux façons de tordre la règle
   « l'eau ne remonte jamais », à comparer.
4. **Ascenseur (14)** : il répond aux blocages par manque d'eau.
5. **Siphon (13)** et **bassin d'épargne (15)** : ils étendent le modèle hors
   de la rangée, à faire ensemble.
