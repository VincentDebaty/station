# Reprendre le chantier du son — prompt pour une nouvelle session Claude

Écrit le 11 septembre 2026, au moment où Vincent change de compte Claude.
Copier tout ce qui suit la ligne dans la première demande de la nouvelle
session, lancée à la racine du dépôt.

---

Tu reprends le chantier du **son et de la musique** de « Station », mon jeu d'aiguillage ferroviaire. Une autre session Claude l'a mené jusqu'ici ; tu n'as pas son historique, tout ce qu'il te faut est ci-dessous et dans le dépôt.

## Avant tout

1. Lis `CLAUDE.md` à la racine : langue (tout en français, y compris les commits), style des messages de commit (une phrase narrative, un corps qui dit la cause et ce qui a été mesuré), commit direct sur `main` autorisé, jamais de force-push, les contrôles ne se négocient pas.
2. `git fetch && git status && git log --oneline -10`. **Une autre session Claude travaille peut-être dans le même dossier** (sur la difficulté du jeu). Ne commite jamais un fichier que tu n'as pas modifié toi-même ; si l'arbre contient des changements qui ne sont pas les tiens, dis-le-moi avant de commiter.
3. Lis `jeu/sons.gd`, `jeu/sons/BRUITAGES.md` et `jeu/sons/PROMPT-SONS.md`.

## Où en est le son

Le jeu tourne sous **Godot 4.7.2** (dossier `jeu/`). Le prototype web (`js/`) existe encore mais on n'y touche plus pour le son.

**Le mécanisme, déjà en place et vérifié sur iPhone :**
- `jeu/sons.gd` (autoload `Sons`) synthétise au démarrage vingt signatures courtes, sans fichier. C'est le filet de sécurité.
- Un fichier `jeu/sons/<nom>.wav` (ou `.ogg`, `.mp3`) **remplace** la signature du même nom. Pas de fichier : la signature synthétisée joue.
- Les familles à variantes — `etoile` (3), `piece` (6), `heure` (8) — se contentent d'**un** fichier ; le jeu fait monter la hauteur par `pitch_scale`. Un nom exact (`piece3.wav`) l'emporte sur la famille.
- `fermeture` retombe sur `incident` sans fichier (`REPLI`) ; `glissement`, `saut` et `vitesse` se taisent sans fichier.
- `STATION_MESURE=1 godot --headless --path . --quit-after 3 res://jeu/app.tscn` imprime la liste des fichiers pris.

**Trois pièges déjà payés :**
- **Les fiches `.import` doivent être au dépôt.** Après tout ajout ou remplacement de son : `godot --headless --path . --import`, puis commiter le `.wav` ET son `.wav.import`. Sans la fiche, le son n'est pas embarqué dans l'export. Remplacer le dossier à la main les efface.
- **Un nom, un fichier.** Ne jamais laisser `piece.ogg` et `piece.wav` côte à côte : un seul serait pris, sans garantie duquel.
- **Dans un export, le dossier liste `x.wav.import`, pas `x.wav`.** C'est géré dans `_charger_fichiers` ; ne le casse pas. Sur le Mac, dans l'éditeur, les deux formes marchent — un test local ne prouve donc rien pour l'iPhone.

**Où chaque son se déclenche :**
- Poste d'aiguillage — le moteur empile des noms dans `enc.sons` (`jeu/enclenchement.gd`), `jeu/vue_jeu.gd` les joue : `depart`, `heure:N` (départ à l'heure, la hauteur suit la série), `fret`, `incident`, `fermeture` ; fin de service dans `_enregistrer_fin` : `parfait`, `fin` ou `incident` ; `vitesse` aux touches 1/2/4 et au bouton du bandeau.
- Carte du ruban — `jeu/vue_ruban.gd`, la remise en temps successifs (`_avancer_remise`) : `etoile0..2`, `diamant`, `piece0..5` puis `bourse`, `grade`, `puce` puis `arrivee` ; l'échec joue `dommage` ; payer un passage joue `depense` ; `saut` dans `aller_camera` ; `puce` aussi quand on touche une gare.
- Écrans — `glissement` dans `_glisser` (`jeu/app.gd`), quand l'écran des cartes passe devant le ruban.
- `annonce` est synthétisé mais n'est appelé nulle part.

**Si tu modifies `jeu/enclenchement.gd`**, lance `node tools/oracle-enclenchement.mjs darlington bruxelles-midi` : il doit rester identique au prototype.

## Les fichiers actuels

Vingt WAV choisis par moi dans la **bibliothèque d'ElevenLabs** (stéréo, 48 kHz, 16 bits). **Certains sont bien, d'autres non.** Ta première question doit être : lesquels garder, lesquels remplacer. Ne devine pas.

Mesures faites sur ces fichiers :
- Aucun silence de tête, sauf `vitesse` (50 ms).
- Durées de 0,48 à 1,2 s. `piece` fait 0,48 s pour une cible de 0,15 s : les pièces se chevauchent pendant la pluie.
- **Quatre sons très faibles** à côté de la corne et du sifflet (crête 1,0) : `fin` 0,04, `glissement` 0,07, `arrivee` 0,08, `heure` 0,16. Proposé mais pas fait : normaliser les copies du jeu vers −3 dBFS.

Pour écouter sur le Mac : `afplay jeu/sons/fin.wav`. Pour mesurer : Python `wave` et `audioop` suffisent — ni ffmpeg ni sox ne sont installés. Pour rejouer la remise sans jouer une partie : `STATION_REMISE=3,diamant godot --path .` (voir le commentaire de `_remise_pour_voir` dans `jeu/vue_ruban.gd`).

## Les droits

**Je génère ou télécharge les sons moi-même** pour en avoir les droits (abonnement ElevenLabs). Tu ne génères pas d'audio : tu m'aides à choisir, tu écris les descriptions ou les mots-clés, tu copies, renommes, mesures, branches, déploies. Mes téléchargements arrivent dans `~/Downloads` avec des noms comme `crystal_chime,_glass_#2-1789120146976.wav` ; copie-les, ne les déplace pas.

## La direction sonore

Un poste d'aiguillage d'avant-guerre : laiton patiné, chêne, cuir, papier épais, vapeur, cristal. Chaque son est une petite scène (attaque, matière, courte queue d'espace), pas un bruit sec. Trois matières dominantes : **laiton et cristal** pour les récompenses, **bois et papier** pour l'interface, **vapeur et fonte** pour les trains. Chaleur pour les gains. **Jamais de fanfare, jamais de son de « jeu vidéo »** (synthé, bip, whoosh) — sauf `parfait`, seule mélodie, cinq notes. Sons courts : un son d'interface qui traîne se superpose à l'animation suivante. Détail et durées cibles : `jeu/sons/BRUITAGES.md`.

Mots-clés qui m'ont servi dans la bibliothèque ElevenLabs :

| nom | mots-clés |
|---|---|
| depart | train conductor whistle, station master whistle |
| heure | brass bell single ring, platform bell |
| fret | freight train horn distant |
| incident | railway signal bell, old alarm bell two rings |
| fermeture | iron gate close, metal gate latch |
| vitesse | mechanical lever click, brass switch, ratchet |
| fin | desk bell double ring, service bell warm |
| parfait | glockenspiel arpeggio, celesta ascending, music box |
| dommage | rubber stamp on paper |
| grade | wax seal press, small bell |
| etoile | small metal object on paper, tiny chime |
| diamant | crystal chime, glass shimmer, gem sparkle |
| piece | single coin drop wood, gold coin clink |
| bourse | coins pour into pouch |
| depense | coin slide counter, coin drop tray |
| puce | token slide wood, game piece move |
| arrivee | hotel desk bell ding |
| glissement | paper slide desk, parchment |
| saut | steam train passing distant |
| annonce | station announcement chime |

## La musique : rien n'existe encore

Pas de bus audio (tout sort sur `Master`), pas de musique, pas d'ambiance, et le volet de réglages n'a qu'un interrupteur muet (`Sauvegarde.get_muet` / `set_muet`, stocké sous sa propre clé `station-muted`, hors de la progression). **Je n'ai rien décidé sur la musique** : demande-moi ce que je veux avant de construire.

Ce qui avait été proposé, à rediscuter :
- trois bus — Musique, Ambiance, Effets — et un curseur de volume par bus dans le volet, rangés comme préférences à part (clés séparées comme `station-muted`, pas dans la progression — sinon `SCHEMA_VERSION` à incrémenter, migration et `node tools/oracle-sauvegarde.mjs`) ;
- une ambiance par écran (hall de gare au poste, vent et rail lointain sur la carte) ;
- un thème par zone de carte (l'Europe en a quatre, le grand tour du Rhin deux), en couches séparées, calme sur la carte, plus tendu pendant un service, avec `AudioStreamInteractive` pour passer d'une couche à l'autre sans coupure ;
- Ogg Vorbis pour la musique ; outils possibles : Suno ou Udio (Suno rend les pistes séparées), Stable Audio pour des boucles instrumentales, Logic Pro ou GarageBand pour monter. Vérifier la licence commerciale au moment de l'abonnement.

Non vérifié : iOS peut couper la catégorie audio « ambient » avec l'interrupteur de sonnerie. Si le son se tait sur l'iPhone en mode silencieux, c'est là qu'il faut regarder — et ce sera plus sensible encore avec une musique.

## Déployer sur mon iPhone

`./tools/ios.sh` exporte, signe, installe et lance ; `./tools/ios.sh --etat` dit ce qui manque. Il faut l'iPhone branché et déverrouillé. Le projet Xcode est dans `~/Library/Caches/Station-ios/`. Si l'installation est refusée pour « profile has not been explicitly trusted », c'est à moi de faire confiance au profil sur le téléphone (Réglages → Général → VPN et gestion de l'appareil).

## Comment travailler avec moi

Dis en une ligne ce que tu vas faire, fais-le, vérifie-le (mesure, liste des sons chargés, déploiement), commite en français avec les mesures dans le corps, et termine par un court récapitulatif. Quand un choix est artistique — garder un son, monter un niveau, le style d'une musique — pose-moi la question plutôt que de trancher.
