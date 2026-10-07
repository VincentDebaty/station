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
| 10 | Clapet | aucun | rien : l'eau ne passe que dans un sens | **règle écrite, aucun niveau** (nuit du 7 au 8 octobre 2026) : voir plus bas | faible |
| 11 | Pompe | un coup = un volume qui monte | quand dépenser un coup pour remonter de l'eau | **écrite** (chap. 4, niveau 4-1, 7 octobre 2026) | faible |
| 12 | Marée | aucun (la mer monte et descend), ou attendre | le bon moment | **écrite** (chap. 8, niveau 8-1, nuit du 7 au 8 octobre 2026) | faible |
| 13 | Siphon | l'amorcer (la roue rouge sur le tuyau) | faire passer l'eau par-dessus une levée, jusqu'à un bassin qui n'est pas voisin | **écrit** (chap. 10, niveau 10-1, nuit du 7 au 8 octobre 2026) | moyen |
| 14 | Ascenseur à bateaux | un coup (la roue du treuil) | combien d'eau le bac emporte | **écrit** (chap. 9, niveau 9-1, nuit du 7 au 8 octobre 2026) | moyen |
| 15 | Bassin d'épargne | une vanne latérale | garder de l'eau pour plus tard | à écrire | fort |
| 18 | Glaçon et brasero (gel, feu) | allumer une fois, puis le temps passe | quand allumer : l'eau arrive en trois coups, là où elle est posée | **écrite** (chap. 6, niveau 6-1, nuit du 7 au 8 octobre 2026) | moyen |
| 19 | Orage (tempête) | aucun, ou attendre | profiter de l'eau qui tombe sans laisser monter le bief du village | **écrit** (chap. 7, niveau 7-1, nuit du 7 au 8 octobre 2026) | faible |
| 20 | Pont bas | aucun | garder l'eau assez basse pour la cheminée des bateaux | **écrit** (chap. 11, niveau 11-1, nuit du 7 au 8 octobre 2026) | moyen |
| 21 | Moulin | la vanne du moulin (une porte) | quand faire passer l'eau par la roue, sachant que les bateaux en ont besoin | **écrit** (chap. 12, niveau 12-1, nuit du 7 au 8 octobre 2026) | moyen |
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

### 10. Clapet — essayé la nuit du 7 au 8 octobre 2026, sans niveau
La règle est au moteur (liaison `clapet`, `sens`, `seuil`, `crete`), mais le
solveur n'a trouvé aucun niveau où il compte : comparé à un mur et à une
ouverture dans les deux sens, il ne change jamais la solution. Avec la seule
gravité, l'eau ne remonte jamais vers lui ; il ne servirait qu'avec une eau
qui monte d'ailleurs (marée, pluie, pompe) — la « porte de flot » d'un port.
À reprendre en combinaison, pas en premier niveau.

### 10 bis. Portes jumelles — essayées la même nuit et retirées
Deux portes reliées par une chaîne, d'états contraires. Sur des escaliers
d'écluses, le lien ne raccourcit ni n'allonge jamais la meilleure solution
(4 coups avec ou sans) : il ne change rien au jeu. Retirées du moteur.

### 10 ter. Clapet anti-retour — l'idée de départ
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

### 12. Marée — écrite le 8 octobre 2026 (chapitre 8, niveau 8-1)
- **Ce qui a été fait :** la mer (bassin `mer`, `fixe`) suit `maree`, une
  suite de niveaux, un pas par coup ; l'état garde la phase. Sur le mur du
  port : une échelle de marée rouge et blanche, la bande d'algues entre basse
  et haute mer, et une flèche jaune (devant l'eau) avec un chevron qui monte
  ou descend, à la hauteur de la mer au coup suivant. Un fond de sable.
- **Le niveau 8-1 :** suite 1, 2, 3, 2. Il manque de l'eau au bief amont
  pour que le bateau rouge y monte : la marée haute, porte ouverte, remplit
  le sas pour rien ; il faut l'attendre (requis). Par 6.

### 12 bis. Marée — l'idée de départ
- **On voit :** la mer qui monte et descend, avec une échelle de marée.
- **La règle :** la mer reste un bassin fixe, mais son niveau suit une suite
  connue d'avance, un pas par coup (par exemple 1, 2, 3, 2, 1…).
- **Ce que ça apporte :** le moment juste pour ouvrir la porte de mer.
- **Coût :** faible, le niveau de la mer devient fonction du nombre de coups.
  **Risque :** le joueur doit voir venir la marée (une jauge, ou la suite
  affichée).

### 13. Siphon — écrit le 8 octobre 2026 (chapitre 10, niveau 10-1)
- **Ce qui a été fait :** `objets`, type `siphon`, entre deux bassins `a` et
  `b` quelconques, crépines à `ha` et `hb`. Amorcé, il égalise les deux
  bassins comme une liaison de plus (le moteur le traite dans
  `equilibrer()`, son débit vient après ceux des liaisons) ; le bassin qui se
  vide ne descend pas sous sa crépine, et quand une crépine sort de l'eau, il
  se désamorce.
- **On voit :** un tuyau sur des poteaux de bois, le long de la berge du
  fond, derrière les tours des portes ; ses bouts plongent dans la mare et
  dans le sas ; une roue rouge sur l'arche, et une goutte bleue qui invite à
  l'amorcer. L'eau court dans le tuyau, la mare rétrécit.
- **Le niveau 10-1 :** une mare derrière une levée, plus haute que le canal.
  Le siphon la vide dans le sas — par-dessus la levée et le bief amont —
  jusqu'à sa crépine : juste de quoi monter le bateau rouge, si la porte du
  bief amont est ouverte au bon moment pour partager l'eau. Par 6 ; au
  hasard, moins d'une partie sur cent est gagnée.

### 13 bis. Siphon — l'idée de départ
- **On voit :** un tuyau en U renversé, par-dessus un mur, avec un robinet
  d'amorçage.
- **La règle :** une fois amorcé, il égalise deux bassins par-dessus leur
  séparation, tant que l'eau du côté haut couvre son entrée. Il peut relier
  des bassins non voisins.
- **Ce que ça apporte :** déplacer de l'eau sans ouvrir de porte, enjamber un
  bassin.
- **Coût :** moyen. Une liaison entre bassins non voisins sort de la rangée :
  `equilibrer()` doit traiter un graphe.

### 14. Ascenseur à bateaux — écrit le 8 octobre 2026 (chapitre 9, niveau 9-1)
- **Ce qui a été fait :** le bac est un bassin (`bac`) dont le fond monte et
  descend (`objets`, type `ascenseur`, fonds `bas` et `haut`). Le geste
  « ascenseur » le déplace avec son eau et son bateau. Ses deux liaisons sont
  des `quai` : fermées, sauf celle du côté où il est arrêté, qui s'ouvre comme
  un passage libre. L'eau du bac et celle du bief s'y égalisent : **le bac
  emporte de l'eau**, c'est tout le jeu.
- **On voit :** une chambre de pierre, un bac d'acier (le fond en tranche, la
  paroi du fond nervurée, les câbles), les deux quais en portes sans roue,
  une poutre en treillis posée sur eux, la roue rouge du treuil au milieu
  (la roue rouge est la commande, partout), une flèche jaune qui dit si le
  bac va monter ou descendre, deux contrepoids qui filent à l'envers.
- **Le niveau 9-1 :** le bief amont est trop maigre pour le bateau rouge ;
  le bac doit y monter assez d'eau, mais pas trop, car un village borde ce
  bief. Le sas, en aval, sert de **mesure** : on le remplit au bief du
  moulin, on le referme, on le vide dans le bief aval, et le bac emporte
  juste ce qu'il faut. Ouvrir les deux portes ensemble inonde le village ;
  n'ouvrir que la seconde laisse le bief amont à 3,89 pour 4. Par 5 ; au
  hasard, une partie sur sept seulement est gagnée.

### 14 bis. Ascenseur à bateaux, plan incliné — l'idée de départ
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

### 18. Le glaçon et son brasero — le gel et le feu (nuit du 7 au 8 octobre 2026)
- **On voit :** un gros bloc de glace sur la berge du fond, et à côté un
  brasero. Allumé, le feu danse, le bloc goutte et rapetisse ; des filets
  d'eau descendent le long du mur dans le bassin.
- **La règle :** « allumer » (une fois) ; le bloc fond en « fonte » coups,
  et chacun, celui de l'allumage compris, verse « volume »/« fonte » d'eau
  dans son bassin (`objets`, type `glacon`). Un **sablier** apparaît dans les
  boutons du bas tant que la glace fond : laisser passer un coup sans rien
  toucher (« attendre »).
- **Le niveau 6-1 :** le glaçon fond dans le sas. Allumé tout de suite, son
  eau file dans le bief aval par la porte ouverte, ou remplit le sas trop
  tôt : le niveau devient impossible. Il faut faire entrer le bateau rouge,
  allumer, fermer derrière lui : la fonte le monte. Par 6.
- **Essayé et écarté la même nuit :** un bassin GELÉ (bateau pris dans la
  glace, portes bloquées) que le brasero dégèle. Le solveur n'y trouvait que
  « allumer, attendre, puis jouer normalement » : pas de décision. Et le
  rendu d'une glace dans le canal, avec les vantaux qui la traversent,
  promettait des défauts graphiques.

### 19. L'orage — la tempête (nuit du 7 au 8 octobre 2026)
- **On voit :** la lumière baisse, de gros nuages gris en haut, une bruine
  qui redouble en averse à chaque coup, des ronds sur l'eau, un éclair de
  temps en temps. Le sablier est toujours là : attendre, c'est laisser
  pleuvoir.
- **La règle :** « pluie » dans le niveau : chaque coup, chaque bassin monte
  d'autant (pas la mer, pas le village, où elle s'infiltre). C'est la pluie
  qu'on avait écartée (« le joueur ne peut ni la prévoir ni la contrer ») :
  régulière et connue d'avance, elle se prévoit.
- **Le niveau 7-1 :** le bateau rouge doit monter, et il manque un quart
  d'unité au bief amont : il faut attendre une averse (requis : attendre).
  Mais chaque coup monte aussi le bief aval vers le haut de la levée du
  village ; la solution finit à 3,98 pour une levée à 4. Neuf coups de trop
  et le village est inondé. Par 6.

### 20. Le pont bas (nuit du 7 au 8 octobre 2026)
- **On voit :** un pont de pierre sur un passage libre entre deux biefs,
  dessiné comme une porte (pilier devant, pilier au fond, tablier avec sa
  route pavée et ses parapets) ; sous le tablier, une plaque ronde de hauteur
  limitée. Un bateau bloqué par le pont montre, au bout de cinq secondes, le
  niveau qu'il faudrait en pointillés et une bulle « goutte, flèche vers le
  haut » : il y a trop d'eau.
- **La règle :** `pont` sur une liaison (le dessous du tablier) : un bateau
  ne passe dessous que si l'eau plus sa `hauteur` (0,6 par défaut, mesurée
  sur l'image des bateaux) n'y touche pas. Avec 1, on voyait le bateau tenir
  sous le pont alors que le moteur le refusait : la règle doit coller à
  l'image.
- **Le niveau 11-1 :** les deux biefs du haut sont trop pleins pour passer
  sous le pont ; l'écluse sert de seau, on l'emplit en haut et on la vide en
  bas, et l'on fait passer les deux bateaux dans le même mouvement. Par 7
  (5 sans le pont) ; au hasard, deux parties sur cent.
- **Rendu Godot du passage libre**, écrit pour l'occasion : les deux eaux se
  rejoignent au milieu de la liaison, sous le pilier avant.

### 21. Le moulin — un objectif qui n'est pas un bateau (nuit du 7 au 8 octobre 2026)
- **On voit :** une porte de canal qui sert de vanne au bief du moulin ; en
  aval, une grande roue à aubes qui tourne quand l'eau descend ; sur la
  berge du fond, la maison du meunier et une pyramide de sacs en pointillés,
  qui se remplissent de farine. On compte les sacs, sans un mot.
- **La règle :** porte avec `moulin` : jamais de bateau ; l'eau qui la
  traverse en DESCENDANT vers le bassin le plus bas est comptée (`e.moulu`).
  `farine` dans le niveau : le volume à moudre pour gagner. (Comptée dans les
  deux sens, l'eau faisait l'aller-retour par la roue et le solveur moulait
  en 29 coups de va-et-vient.)
- **Le niveau 12-1 :** cinq sacs, et deux bateaux qui se croisent. Le bief
  amont a juste assez d'eau pour les deux : il faut ouvrir le moulin au bon
  moment, et l'eau du bief du moulin revient au bief amont quand on remplit
  le sas. Par 6 ; au hasard, quatre parties sur cent.

### 22. La porte à flotteur (nuit du 7 au 8 octobre 2026)
- **La règle, au moteur, sans niveau encore :** comme le robinet d'une chasse
  d'eau — on ouvre la porte, et l'eau qui entre dans son bassin s'arrête à la
  hauteur du flotteur, qui la referme. Essayée d'abord à l'envers (une porte
  que l'eau OUVRE et qui reste ouverte) : c'était un piège sans solution.
  Sur le trajet des bateaux, elle se referme toujours avant que les eaux ne
  soient égales : elle ne peut que nourrir un bief, de côté.

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
