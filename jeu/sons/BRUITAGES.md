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
| `dommage` | l'échec : le tampon rouge se pose sur le relevé | 0,6 s | *Heavy rubber stamp slammed once on paper over a wooden desk, thud with a short paper slap* |
| `fin` | le service est tenu ; le relevé arrive | 0,7 s | *Small warm end-of-shift bell in a railway office, two soft strikes, close* |
| `parfait` | un sans-faute : la fanfare des cinq notes, la seule du jeu | 0,8 s | *Five ascending notes on a small glockenspiel, bright and quick, C major arpeggio, dry* |
| `etoile` | une étoile se pose sur la feuille (3 variantes en hauteur, gérées par le jeu) | 0,3 s | *Tiny brass pin dropped onto thick parchment on a desk, small metallic tick with a faint ring* |
| `diamant` | la pierre taillée se pose sur son sceau, dans sa gerbe | 0,9 s | *Cut crystal gem set into a brass seal, sparkling glassy ring, clean and bright, short tail* |
| `piece` | une pièce d'or atterrit dans la pastille (6 variantes en hauteur, gérées par le jeu) | 0,15 s | *Single gold coin dropped flat on a wooden desk, bright metallic clink, very short* |
| `bourse` | la dernière pièce est posée, la bourse est pleine | 0,4 s | *Handful of gold coins poured into a small leather pouch, short jingle, close* |
| `depense` | des pièces quittent la pastille pour payer un passage | 0,3 s | *Coin slid across a wooden counter and dropped into a brass tray, one soft clink* |
| `grade` | une promotion : le grade change dans la barre | 0,7 s | *Wax seal pressed onto parchment then a soft brass bell, ceremonial but quiet* |
| `puce` | la puce de laiton part le long de la voie ; aussi : une gare choisie sur la carte | 0,2 s | *Brass token slid a few centimetres on polished wood, soft click at the end* |
| `arrivee` | la puce arrive à la gare suivante | 0,4 s | *Small brass desk bell, one ding, arrival, short* |
| `annonce` | en réserve (une annonce en gare) | 0,5 s | *Old railway station announcement chime, two mellow notes, slightly distant hall* |

## Les animations sans son (à brancher si un fichier arrive)

| fichier | quand | durée | description à coller |
|---|---|---|---|
| `glissement` | l'écran des cartes glisse devant le ruban, et revient | 0,4 s | *Heavy sheet of paper slid across a wooden desk, soft, one movement* |
| `saut` | le voyage de nuit : la caméra franchit un saut du ruban | 1,2 s | *Distant steam train passing at night, brief, receding, outdoors* |
| `vitesse` | le joueur passe en ×2 ou ×4 | 0,2 s | *Small brass lever clicked one notch, mechanical, dry* |
| `fermeture` | un quai ferme (aujourd'hui : `incident`) | 0,6 s | *Iron gate latch closed on a platform, metallic, echo of a station hall* |

Ces quatre-là ne jouent pas encore : un nom réservé, pour que le fichier
puisse être généré maintenant et branché après.
