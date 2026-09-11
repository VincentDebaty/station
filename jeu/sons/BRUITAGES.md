# Les bruitages — ce qu'il faut générer, et où le déposer

Écrit le 10 septembre 2026. Le jeu synthétise aujourd'hui vingt signatures au
démarrage (`jeu/sons.gd`), sans un fichier. **Déposer un fichier ici le
remplace** : `jeu/sons/<nom>.ogg` (ou `.wav`, `.mp3`) est joué à la place de
la signature `<nom>`, et tout ce qui n'a pas de fichier reste synthétisé. On
peut donc remplacer un son à la fois, écouter, revenir en arrière en effaçant
le fichier.

`STATION_MESURE=1` imprime au démarrage quels fichiers ont été pris.

## Le format

- **Ogg Vorbis** de préférence (`.wav` 16 bits accepté, `.mp3` aussi), **mono**,
  44,1 kHz.
- **Pas de silence au début** : le son part à la première milliseconde, il
  accompagne une animation qui, elle, ne l'attend pas.
- Crête vers −3 dBFS ; le jeu ne renormalise pas.
- **Court.** Les durées ci-dessous sont des cibles ; un son d'interface qui
  dépasse la seconde traîne derrière l'écran.
- Un fichier **par famille** suffit pour les variantes (`etoile`, `piece`,
  `heure`) : le jeu fait monter la hauteur lui-même. Un fichier par variante
  (`piece3.ogg`) est aussi accepté, et il l'emporte.

## Le registre

Un poste d'aiguillage d'avant-guerre : laiton, bois, papier, vapeur, cloches
de quai, sifflets. **Jamais une fanfare**, jamais un son de « jeu vidéo »
(pas de bip, pas de synthé, pas de whoosh). Bas, court, matériel. Chaque
description ci-dessous est en anglais parce que les générateurs y répondent
mieux ; la colonne « quand » dit ce que l'animation montre à cet instant.

## Les sons branchés

| fichier | quand | durée | description à coller |
|---|---|---|---|
| `depart` | un convoi quitte le quai en retard (et : le son est rétabli) | 0,4 s | *Short sharp blast of a station master's brass whistle, single note, close, dry, no reverb tail* |
| `heure` | un convoi part **à l'heure** ; la hauteur monte avec la série (8 crans, gérés par le jeu) | 0,5 s | *Single clear strike of a small brass platform bell, bright, short decay, no room* |
| `fret` | un lourd convoi de marchandises se présente à l'entrée | 1,0 s | *Distant diesel freight locomotive horn, low and rounded, one blast, fading, outdoors* |
| `incident` | un retard s'annonce, un quai ferme, ou un convoi s'est trompé de quai et refoule | 0,5 s | *Old railway signal box alarm bell, two quick clanks, metallic, small, dry* |
| `dommage` | l'échec : le tampon rouge se pose sur le relevé | 0,46 s | *A heavy wooden-handled rubber stamp pressed hard onto a thick sheet of paper lying on an oak desk. A deep muffled thud, the dull slap of the paper underneath, then the short wooden resonance of the desk itself. Close, indoors, small office, no reverb tail.* |
| `fin` | le service est tenu ; le relevé arrive | 0,7 s | *Small warm end-of-shift bell in a railway office, two soft strikes, close* |
| `parfait` | un sans-faute : la fanfare des cinq notes, la seule du jeu | 0,8 s | *Five ascending notes on a small glockenspiel, bright and quick, C major arpeggio, dry* |
| `etoile` | une étoile se pose sur la feuille (3 variantes en hauteur, gérées par le jeu) | 0,3 s | *Tiny brass pin dropped onto thick parchment on a desk, small metallic tick with a faint ring* |
| `diamant` | la pierre taillée se pose sur son sceau, dans sa gerbe | 0,9 s | *Cut crystal gem set into a brass seal, sparkling glassy ring, clean and bright, short tail* |
| `piece` | une pièce d'or atterrit dans la pastille (6 variantes en hauteur, gérées par le jeu) | 0,15 s | *Single gold coin dropped flat on a wooden desk, bright metallic clink, very short* |
| `bourse` | la dernière pièce est posée, la bourse est pleine | 0,4 s | *Handful of gold coins poured into a small leather pouch, short jingle, close* |
| `depense` | des pièces quittent la pastille pour payer un passage | 0,3 s | *Coin slid across a wooden counter and dropped into a brass tray, one soft clink* |
| `grade` | une promotion : le grade change dans la barre | 0,7 s | *Wax seal pressed onto parchment then a soft brass bell, ceremonial but quiet* |
| `puce` | la puce de laiton part le long de la voie (elle voyage `SEQ_PUCE` = 1,2 s) | 0,25 s | *Marble rolling on wood* — une bille qui roule, pas un jeton qui glisse : c'est le son d'une chose qui S'EN VA. Trois prises de glissement de laiton ont échoué avant celle-ci. Allégée après essai sur l'iPhone : +7 demi-tons et -9 dB. |
| `clic` | **n'importe quel bouton du jeu**, et la carte de mission qu'on touche | 0,11 s | **Tiré de `choix`**, monté de 3 demi-tons et reculé de 10 dB. Ce n'est pas une prise à part : c'est la même pièce d'échecs, plus petite et plus loin. RMS −38,4, le son le plus discret du jeu de 5 dB — il sonne à chaque geste, il ne doit pas s'entendre, seulement répondre. |
| `choix` | une gare qu'on touche sur la carte du ruban | 0,13 s | *Wood chess piece placed* — la pièce d'échecs posée sur son plateau. Crête à 20 ms, morte à 150 : un choc, pas une résonance. C'est le son le plus souvent entendu du jeu, il doit s'effacer. Allégée après essai sur l'iPhone : +4 demi-tons et -6 dB. |
| `arrivee` | la puce arrive à la gare suivante | 0,4 s | *Small brass desk bell, one ding, arrival, short* |
| `annonce` | en réserve (une annonce en gare) | 0,5 s | *Old railway station announcement chime, two mellow notes, slightly distant hall* |

## Les quatre autres, branchés le 10 septembre 2026 quand les fichiers sont arrivés

| fichier | quand | durée | description à coller |
|---|---|---|---|
| `glissement` | l'écran des cartes glisse devant le ruban, et revient | — | **MUET depuis le 11 septembre 2026 au soir : le fichier a été retiré.** Deux prises ont été essayées, et la seconde reculée deux fois, de RMS −13,6 à −18,1 puis à −29,1 ; à ce niveau elle ne servait plus à rien, et elle gênait encore. Une transition d'écran n'a peut-être pas besoin de son. Redéposer un `glissement.wav` suffit à le rétablir. |
| `saut` | le voyage de nuit : la caméra franchit un saut du ruban | 1,2 s | *Distant steam train passing at night, brief, receding, outdoors* |
| `vitesse` | le joueur passe en ×2 ou ×4 | 0,2 s | *Small brass lever clicked one notch, mechanical, dry* |
| `fermeture` | un quai ferme (`incident` à défaut de fichier) | 0,6 s | *Iron gate latch closed on a platform, metallic, echo of a station hall* |

Sans fichier déposé, `glissement`, `saut` et `vitesse` se taisent — ils n'ont
pas de signature synthétisée.

## Où s'accroche le clic des boutons (11 septembre 2026)

`Sty.bouton()` est la fabrique unique : `bouton_plaque()` et `lien()`
l'appellent, donc un seul `pressed.connect` y couvre tous les boutons du jeu.
Deux réserves, payées sur place :

- **La fonction est statique, et GDScript n'expose pas les autoloads dans un
  contexte statique.** Écrire `Sons.jouer(...)` dans `Sty.bouton` ne compile
  pas — « Identifier not found: Sons ». On passe par le nœud du bouton,
  `b.get_node_or_null("/root/Sons")`, qui est dans l'arbre au moment du clic.
- **Le bandeau du poste n'est pas fait de `Button`** : `_clic_bandeau`
  (`vue_jeu.gd`) teste des rectangles à la main, et échappe donc à la
  fabrique. Le clic y est posé branche par branche — sauf sur la vitesse, qui
  fait déjà entendre son levier, et sur l'interrupteur du son.

Deux autres cibles ne sont pas des boutons stylés et ont leur propre
accroche dans `vue_cartes.gd` : le voile d'une modale, et `_zone_cliquable`,
la carte de mission elle-même.

## `puce` et `choix` : deux gestes, deux sons (11 septembre 2026)

Jusqu'ici `puce` servait aux deux — le jeton qui PART le long de la voie, et
la gare qu'on SÉLECTIONNE sur la carte. Un mouvement d'une seconde et un choc
instantané : deux prises successives ont échoué à convenir aux deux, et c'est
normal. `vue_ruban.gd` appelle désormais `choix` pour la sélection, et
`sons.gd` le fait retomber sur `puce` tant que `choix.wav` n'est pas déposé —
soit exactement le comportement d'avant.

## Ce que valent ces descriptions (11 septembre 2026)

Quatre des cinq bruitages refaits ce jour-là ont demandé DEUX prises ou plus,
et `puce` en a demandé trois — la troisième n'a réussi qu'en changeant d'objet
physique (une bille qui roule au lieu d'un jeton qui glisse) et de source (la
bibliothèque au lieu de la génération : les frictions courtes et discrètes sont
ce que ces modèles ratent le plus). Affiner la même description une troisième
fois n'aurait rien donné.

Les deux descriptions de `dommage` et `glissement` ont été **réécrites après une écoute** : les précédentes
(« Heavy rubber stamp slammed once… », « Heavy sheet of paper slid… ») ont
produit un tampon sec et sans corps, et un souffle plutôt que du papier. Ce
qui a marché tient en une règle : **décrire la matière ET la pièce**, pas le
geste seul. Les autres lignes du tableau n'ont pas été revues ; elles ont
produit des sons acceptés, ce qui ne veut pas dire qu'elles les reproduiraient.

## Le niveau et la durée, tels qu'ils sont appliqués

- **Crête à −3 dBFS par voie**, pour tous les fichiers, sauf quatre reculés
  exprès : `depart` (−15 dBFS) et `fret` (−9 dBFS) — un départ en retard et un
  convoi lointain ne doivent pas dominer la cloche de la réussite —, puis
  `choix` (−9), `puce` (−12) et `clic` (−19).
- **Un son qu'on déclenche soi-même se recule beaucoup plus qu'on ne croit.**
  `clic`, `choix`, `puce` et `glissement` ont tous été descendus après une
  écoute en jeu, aucun ne s'est révélé trop faible. Le standard à −3 dBFS vaut
  pour ce que le jeu joue de lui-même ; ce que le joueur provoque doit
  répondre sans s'entendre. **Et parfois la bonne valeur est le silence** :
  `glissement` a fini par être retiré plutôt que reculé une troisième fois.
- **La crête ne dit pas la présence.** Un son continu et un choc à la même
  crête ne pèsent pas pareil dans le mixage : c'est le RMS qu'il faut
  comparer, et le peloton vit entre −18 et −27.
- **Un son qu'on déclenche soi-même se juge en jeu, pas au casque.** `choix` et
  `puce` avaient gagné leur banc d'essai à −3 dBFS ; au doigt, sur la carte,
  ils écrasaient. Monter la hauteur allège autant que baisser le volume : ce
  n'est plus le même objet, c'en est un plus petit.
- **Mono**, sauf si sommer les deux voies coûte plus d'un décibel de RMS : six
  fichiers sur vingt ont une vraie largeur et restent stéréo.
- **48 kHz conservé.** Godot le lit, et sans sox ni ffmpeg sur la machine un
  rééchantillonneur maison coûterait plus qu'il ne rapporterait.
- **La durée se taille sur l'animation, pas sur la cible du tableau.** Les
  chiffres qui font autorité sont dans le code : `GLISSE = 0,32` (app.gd),
  `SEQ_ECHEC_POSE = 0,32`, `SEQ_PUCE = 1,20`, `SEQ_ECART = 0,17` d'une étoile à
  la suivante et `SEQ_PIECE_ECART = 0,07` d'une pièce à la suivante
  (vue_ruban.gd). Un son plus long que l'écart de sa rafale se superpose à
  lui-même : `piece` à 0,48 s tenait sept exemplaires sur les huit voix de
  `sons.gd`.
