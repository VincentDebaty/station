# Reprendre le chantier du son — prompt pour une nouvelle session Claude

Réécrit le 11 septembre 2026, au soir du jour où les vingt-et-un bruitages ont
été repris un par un. La version précédente disait « certains sons sont bons,
d'autres non, ta première question doit être lesquels » — c'est fait, et ce
document dit maintenant ce qui reste.

Copier tout ce qui suit la ligne dans la première demande d'une nouvelle
session, lancée à la racine du dépôt.

---

Tu reprends le chantier du **son et de la musique** de « Station », mon jeu
d'aiguillage ferroviaire. D'autres sessions Claude l'ont mené jusqu'ici ; tu
n'as pas leur historique, tout ce qu'il te faut est ci-dessous et dans le
dépôt.

## Avant tout

1. Lis `CLAUDE.md` à la racine : langue (tout en français, y compris les
   commits), style des messages de commit (une phrase narrative, un corps qui
   dit la cause et ce qui a été mesuré), commit direct sur `main` autorisé,
   jamais de force-push, les contrôles ne se négocient pas.
2. `git fetch && git status && git log --oneline -10`. **Une autre session
   Claude travaille peut-être dans le même dossier.** Ne commite jamais un
   fichier que tu n'as pas modifié toi-même ; si l'arbre contient des
   changements qui ne sont pas les tiens, dis-le-moi avant de commiter.
3. Lis `jeu/sons.gd` et `jeu/sons/BRUITAGES.md` — ce dernier fait autorité sur
   ce qu'est un bon bruitage ici, et il a été réécrit ce jour-là.

## Le mécanisme, en place et vérifié sur iPhone

Le jeu tourne sous **Godot 4.7.2** (dossier `jeu/`). Le prototype web (`js/`)
existe encore mais on n'y touche plus pour le son.

- `jeu/sons.gd` (autoload `Sons`) synthétise au démarrage **30 signatures**
  courtes, sans fichier. C'est le filet de sécurité, et il est beaucoup plus
  faible que les fichiers — si tu entends du synthé en jeu, c'est qu'un
  fichier manque.
- Un fichier `jeu/sons/<nom>.wav` (ou `.ogg`, `.mp3`) **remplace** la
  signature du même nom. **21 sont déposés** aujourd'hui.
- Les familles à variantes — `etoile` (3), `piece` (6), `heure` (8) — se
  contentent d'**un** fichier ; le jeu fait monter la hauteur par
  `pitch_scale`. Un nom exact (`piece3.wav`) l'emporte sur la famille.
- `REPLI` fait retomber un nom sur un autre : `fermeture` → `incident`, et
  `choix` → `puce`. `glissement`, `saut` et `vitesse` se taisent sans fichier.
- `STATION_MESURE=1 godot --headless --path . --quit-after 3 res://jeu/app.tscn`
  imprime la liste des fichiers pris. `STATION_SONS_MESURE=1` en plus détaille
  chaque signature synthétisée.

**Trois pièges déjà payés :**

- **Les fiches `.import` doivent être au dépôt.** Après tout ajout ou
  remplacement : `godot --headless --path . --import`, puis commiter le `.wav`
  **et** son `.wav.import`. Sans la fiche, le son n'est pas embarqué dans
  l'export. Remplacer le dossier à la main les efface.
- **Un nom, un fichier.** Ne jamais laisser `piece.ogg` et `piece.wav` côte à
  côte : un seul serait pris, sans garantie duquel.
- **Dans un export, le dossier liste `x.wav.import`, pas `x.wav`.** C'est géré
  dans `_charger_fichiers` ; ne le casse pas. Sur le Mac, dans l'éditeur, les
  deux formes marchent — un test local ne prouve donc rien pour l'iPhone.

**Vérifier qu'un son est vraiment dans le paquet iOS**, sans le téléphone :

```
python3 -c "import re;d=open('$HOME/Library/Caches/Station-ios/Station.xcarchive/Products/Applications/Station.app/Station.pck','rb').read();print(sorted(set(m.decode() for m in re.findall(rb'res://jeu/sons/[A-Za-z0-9_.-]+',d))))"
```

**Vérifier qu'un nom se résout comme prévu**, autoloads chargés : écrire un
`verif_tmp.gd` jetable qui `extends SceneTree`, appeler `_source(nom)` dans
`_process` (**pas** dans `_initialize` : les `_ready` des autoloads n'ont pas
encore tourné), lancer `godot --headless --path . -s res://verif_tmp.gd`, puis
effacer le fichier et son `.uid`.

## Où chaque son se déclenche

- **Poste d'aiguillage** — le moteur empile des noms dans `enc.sons`
  (`jeu/enclenchement.gd`), `jeu/vue_jeu.gd` les joue : `depart`, `heure:N`
  (départ à l'heure, la hauteur suit la série), `fret`, `incident`,
  `fermeture` ; fin de service dans `_enregistrer_fin` : `parfait`, `fin` ou
  `incident` ; `vitesse` aux touches 1/2/4 et au bouton du bandeau.
- **Carte du ruban** — `jeu/vue_ruban.gd`, la remise en temps successifs
  (`_avancer_remise`) : `etoile0..2`, `diamant`, `piece0..5` puis `bourse`,
  `grade`, `puce` puis `arrivee` ; l'échec joue `dommage` ; payer un passage
  joue `depense` ; `saut` dans `aller_camera` ; **`choix` dans
  `_selectionner`**, quand on touche une gare.
- **Écrans** — `glissement` dans `_glisser` (`jeu/app.gd`), quand l'écran des
  cartes passe devant le ruban.
- `annonce` est synthétisé et déposé, mais n'est appelé nulle part.

**Si tu modifies `jeu/enclenchement.gd`**, lance
`node tools/oracle-enclenchement.mjs darlington bruxelles-midi` : il doit
rester identique au prototype. Si tu modifies un autre `.gd`, passe aussi
`oracle-ruban`, `oracle-sauvegarde` et `oracle-journee --tous` (ce dernier
prend une bonne dizaine de minutes : 401 fiches).

## L'état des vingt-et-un fichiers

Tous ont été mesurés, normalisés et taillés le 11 septembre 2026, puis écoutés
un par un et déployés deux fois sur l'iPhone. **Ils sont bons, ne les reprends
pas d'office.** Le standard réellement appliqué est écrit dans
`BRUITAGES.md` ; en résumé :

- crête à **−3 dBFS par voie**, sauf quatre reculés exprès — `depart` (−15),
  `fret` (−9), `choix` (−9), `puce` (−12) ;
- **mono**, sauf si sommer les deux voies coûte plus d'un décibel de RMS (six
  fichiers ont une vraie largeur et restent stéréo) ;
- **48 kHz conservé** — ni sox ni ffmpeg sur la machine, et Godot le lit très
  bien ; pour mesurer, `wave` et `array` en Python suffisent ;
- **la durée se taille sur l'animation**, pas sur une cible de tableau. Les
  chiffres qui font autorité sont dans le code : `GLISSE = 0,32` (app.gd),
  `SEQ_ECHEC_POSE = 0,32`, `SEQ_PUCE = 1,20`, `SEQ_ECART = 0,17` entre deux
  étoiles, `SEQ_PIECE_ECART = 0,07` entre deux pièces (vue_ruban.gd). Un son
  plus long que l'écart de sa rafale se superpose à lui-même : `piece` à
  0,48 s tenait sept exemplaires sur les huit voix de `sons.gd`.

Pour écouter sur le Mac : `afplay jeu/sons/fin.wav`. Pour rejouer la remise
sans jouer une partie : `STATION_REMISE=3,diamant godot --path .` (voir le
commentaire de `_remise_pour_voir` dans `jeu/vue_ruban.gd`).

## Ce qui reste ouvert, par ordre d'urgence

1. **Le tampon de l'échec sonne 200 ms avant de se poser.**
   `Sons.jouer("dommage")` part à `seq_t = 0` dans `_avancer_remise`, mais le
   tampon met `SEQ_ECHEC_POSE = 0,32 s` à descendre, et le coup de la prise
   tombe à 120 ms. Je n'ai pas encore dit si je l'entends décalé en jeu.
   Demande-le-moi. Si oui, c'est une ligne de `vue_ruban.gd`, pas un fichier.
2. **`puce` est peut-être trop effacée.** Je l'ai allégée de 9 dB après essai
   sur le téléphone : RMS −33,6, de loin le son le plus discret du jeu, 7 dB
   sous `grade`. Or elle sonne **pendant la remise**, au milieu de la bourse
   et du grade. Elle peut y disparaître. Demande-moi si je l'entends encore.
3. **Le mode silencieux de l'iPhone n'a jamais été vérifié.** iOS peut couper
   la catégorie audio « ambient » avec l'interrupteur de sonnerie. Si le jeu
   se tait en silencieux, c'est là qu'il faut regarder — et ce sera bloquant
   le jour où il y aura de la musique.
4. **La musique : rien n'existe encore.** Voir plus bas.

## La musique : rien n'est décidé

Pas de bus audio (tout sort sur `Master`), pas de musique, pas d'ambiance, et
le volet de réglages n'a qu'un interrupteur muet (`Sauvegarde.get_muet` /
`set_muet`, stocké sous sa propre clé `station-muted`, hors de la
progression). **Je n'ai rien décidé : demande-moi ce que je veux avant de
construire.**

Ce qui avait été proposé, à rediscuter :

- trois bus — Musique, Ambiance, Effets — et un curseur de volume par bus dans
  le volet, rangés comme préférences à part (clés séparées comme
  `station-muted`, **pas** dans la progression — sinon `SCHEMA_VERSION` à
  incrémenter, migration et `node tools/oracle-sauvegarde.mjs`) ;
- une ambiance par écran (hall de gare au poste, vent et rail lointain sur la
  carte) ;
- un thème par zone de carte (l'Europe en a quatre, le grand tour du Rhin
  deux), en couches séparées, calme sur la carte, plus tendu pendant un
  service, avec `AudioStreamInteractive` pour passer d'une couche à l'autre
  sans coupure ;
- Ogg Vorbis pour la musique ; outils possibles : Suno ou Udio (Suno rend les
  pistes séparées), Stable Audio pour des boucles instrumentales, Logic Pro ou
  GarageBand pour monter. Vérifier la licence commerciale au moment de
  l'abonnement.

## Les droits

**Je génère ou télécharge les sons moi-même** pour en avoir les droits
(abonnement ElevenLabs). Tu ne génères pas d'audio : tu m'aides à choisir, tu
écris les descriptions ou les mots-clés, tu copies, renommes, mesures,
branches, déploies. Mes téléchargements arrivent dans `~/Downloads` avec des
noms comme `Wood_chess_piece_pla_#1-1789131990347.wav` ; **copie-les, ne les
déplace pas**, et vérifie le nom exact avec `ls` — le Finder affiche parfois
un seul tiret bas là où il y en a deux.

## La direction sonore

Un poste d'aiguillage d'avant-guerre : laiton patiné, chêne, cuir, papier
épais, vapeur, cristal. Chaque son est une petite scène (attaque, matière,
courte queue d'espace), pas un bruit sec. Trois matières dominantes : **laiton
et cristal** pour les récompenses, **bois et papier** pour l'interface,
**vapeur et fonte** pour les trains. Chaleur pour les gains. **Jamais de
fanfare, jamais de son de « jeu vidéo »** (synthé, bip, whoosh) — sauf
`parfait`, seule mélodie, cinq notes. Sons courts : un son d'interface qui
traîne se superpose à l'animation suivante.

## Comment on travaille ensemble sur le son

Ce qui a marché le 11 septembre, et qu'il faut refaire tel quel :

1. **Séparer le technique de l'artistique AVANT de me faire écouter.** Un son
   trop faible ou trop long s'entend comme un son raté : me le faire juger tel
   quel me fait condamner des prises qui n'avaient qu'un niveau à corriger. Ce
   matin-là, 28 dB d'écart entre le plus fort et le plus faible expliquaient à
   eux seuls la moitié de mes reproches.
2. **Un script d'audition** qui joue les sons *dans l'ordre du jeu*, annonce à
   chaque fois ce que l'écran montre à cet instant, et enregistre mon verdict
   au clavier (garder / refaire / à corriger) dans un fichier que tu relis.
   Une passe, trois minutes.
3. **Me demander le DÉFAUT, pas seulement le rejet**, en propositions à
   cliquer plutôt qu'en question ouverte (« trop moderne », « mauvaise
   matière », « c'est un clic, pas un glissement »). Sans ce mot, la
   description suivante est un coup dans le noir. Et si je réponds « je ne
   saurais pas dire », change d'objet physique.
4. **Un banc d'essai en A/B** : ancien contre neuf, deux passages chacun,
   verdict au clavier. Ne me fais jamais juger une prise seule.

Deux leçons chèrement acquises :

- **Quand une description échoue deux fois, change d'objet physique et de
  source**, n'affine pas la phrase. `puce` n'a réussi qu'en abandonnant le
  jeton qui glisse pour une bille qui roule, et la génération pour la
  bibliothèque — les frictions courtes et discrètes sont ce que ces modèles
  ratent le plus.
- **Un son qui déplaît peut être un son mal partagé.** Deux prises ont échoué
  sur `puce` parce que le même nom servait à deux gestes sans rapport — le
  jeton qui PART le long de la voie, et la gare qu'on SÉLECTIONNE. La solution
  était dans le code (`choix`), pas dans le fichier. Cherche les appels avant
  de me commander une prise.
- **Un son qu'on déclenche soi-même se juge en jeu, pas au casque.** `choix`
  et `puce` avaient gagné leur banc d'essai ; au doigt, sur le téléphone, ils
  écrasaient. Monter la hauteur allège autant que baisser le volume : ce n'est
  plus le même objet, c'en est un plus petit.

## Déployer sur mon iPhone

`./tools/ios.sh` exporte, signe, installe et lance ; `./tools/ios.sh --etat`
dit ce qui manque. Il faut l'iPhone branché et déverrouillé. Compter trois
minutes. Le projet Xcode est dans `~/Library/Caches/Station-ios/`. Si
l'installation est refusée pour « profile has not been explicitly trusted »,
c'est à moi de faire confiance au profil sur le téléphone (Réglages → Général
→ VPN et gestion de l'appareil).

## Comment travailler avec moi

Dis en une ligne ce que tu vas faire, fais-le, vérifie-le (mesure, liste des
sons chargés, contenu du `.pck`, déploiement), commite en français avec les
mesures dans le corps, et termine par un court récapitulatif. Quand un choix
est artistique — garder un son, monter un niveau, le style d'une musique —
pose-moi la question plutôt que de trancher.
