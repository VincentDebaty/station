# Brief à coller dans ChatGPT pour obtenir les descriptions des vingt sons

Écrit le 10 septembre 2026, après une première fournée jugée « métallique et
simpliste ». Copier tout ce qui suit la ligne, tel quel.

---

Tu es sound designer de jeux vidéo, spécialisé dans les bruitages courts d'interface et de récompense, avec une culture du cinéma d'époque et du son diégétique. Je vais te décrire un jeu et vingt sons. Ta tâche : écrire, pour chacun, une description de génération en anglais, prête à coller dans un générateur de bruitages par texte (ElevenLabs Sound Effects), qui produise un son riche, évocateur et cohérent avec les dix-neuf autres — pas un simple bruit métallique.

## Le jeu

« Station » est un jeu d'aiguillage ferroviaire sur iPhone. Le joueur tient le poste d'aiguillage d'une gare des années 1900-1930 : il choisit le quai de chaque train qui se présente, et un service réussi rapporte des étoiles, des pièces d'or, parfois un diamant pour un sans-faute. Entre deux gares, il regarde une carte ancienne d'Europe dessinée sur parchemin, où une puce de laiton avance le long du rail vers la ville suivante. L'univers est fait de laiton patiné, de chêne verni, de cuir, de papier épais, de vapeur, de verre et de cuivre. Rien n'est numérique, rien n'est moderne.

## La direction sonore

- **Chaque son est une petite scène, pas un bruit.** Deux ou trois couches : une attaque nette (ce qui produit le son), un corps qui dit la matière (laiton, bois, cristal, papier), et une courte queue d'espace — un bureau lambrissé pour les sons d'interface, un hall de gare lointain pour les trains. Un clic sec et sec de synthèse n'est pas accepté.
- **Chaleur et récompense.** Les sons de gain (étoile, pièce, bourse, diamant, sans-faute, promotion) doivent faire plaisir : du cristal, du laiton chaud, une petite résonance harmonique, une lumière dans le timbre. Pensez cloche de comptoir de grand hôtel, coffret à bijoux, montre à gousset, plutôt que tiroir-caisse.
- **Jamais de fanfare, jamais de « jeu vidéo ».** Pas de synthétiseur, pas de bip, pas de whoosh, pas de trémolo, pas de musique — sauf le sans-faute, seule mélodie du jeu, cinq notes.
- **Cohérence.** Les vingt sons doivent sembler enregistrés dans la même pièce, avec les mêmes objets. Choisis une matière dominante par famille : laiton et cristal pour les récompenses, bois et papier pour l'interface, vapeur et fonte pour les trains, et tiens-t'y.
- **Court.** Les durées indiquées sont impératives : un son d'interface qui traîne se superpose à l'animation suivante.

## Les contraintes techniques (à rappeler dans chaque description si utile)

Mono, 44,1 kHz. Le son doit démarrer à la première milliseconde, sans silence de tête, parce qu'il accompagne une animation qui ne l'attend pas. Pas de réverbération longue : la queue tient dans la durée. Crête vers −3 dBFS.

## Les vingt sons

Pour chacun : le nom du fichier, le moment exact où il joue à l'écran, la durée cible.

**Les trains (le poste d'aiguillage)**
1. `depart` — 0,4 s — un convoi quitte le quai en retard. Le coup de sifflet du chef de gare : bref, autoritaire, avec le hall de gare autour.
2. `heure` — 0,5 s — un convoi part à l'heure ; le jeu fait monter la hauteur à chaque départ à l'heure d'affilée. Une cloche de quai claire et satisfaite, une seule frappe, qui doit rester belle une fois montée d'un ton ou deux.
3. `fret` — 1,0 s — un lourd train de marchandises se présente à l'entrée. Corne grave et ronde, lointaine, avec le poids du convoi dedans.
4. `incident` — 0,5 s — un retard s'annonce, ou un convoi s'est trompé de quai et refoule. Une alarme de cabine d'aiguillage : mécanique, deux frappes, inquiète mais pas agressive.
5. `fermeture` — 0,6 s — un quai ferme. Une grille de fer qu'on referme sur un quai, avec l'écho du hall.
6. `vitesse` — 0,2 s — le joueur passe la vitesse du temps en ×2 ou ×4. Un levier de laiton qui passe un cran, mécanique, précis.

**La fin du service (le relevé)**
7. `fin` — 0,7 s — le service est tenu. Une cloche de fin de service dans un bureau de gare, chaude, deux frappes douces.
8. `parfait` — 0,8 s — un sans-faute : la seule mélodie du jeu, cinq notes qui montent, sur un instrument d'époque (glockenspiel, célesta, boîte à musique), joyeuse et brève.
9. `dommage` — 0,6 s — l'échec : un gros tampon rouge se pose sur le relevé. Un tampon de caoutchouc frappé sur du papier posé sur un bureau de bois, avec le poids du geste.
10. `grade` — 0,7 s — une promotion : le grade du joueur change. Un sceau de cire pressé sur le parchemin, puis une petite cloche de laiton, cérémonieux et discret.

**La remise des récompenses (elles volent une à une vers leur place)**
11. `etoile` — 0,3 s — une étoile se pose sur la feuille ; trois variantes en hauteur, gérées par le jeu. Un petit objet de laiton posé sur du parchemin épais, avec une résonance claire et courte.
12. `diamant` — 0,9 s — la pierre taillée se pose sur son sceau dans une gerbe de lumière. Le son le plus précieux du jeu : cristal, lumière, une résonance harmonique qui s'ouvre puis se referme.
13. `piece` — 0,15 s — une pièce d'or atterrit dans la bourse de la barre du haut ; six à dix pièces se suivent à 70 ms d'écart, le jeu fait monter la hauteur. Une seule pièce d'or lourde qui tombe sur du bois, claire, très courte — elle doit bien se répéter.
14. `bourse` — 0,4 s — la dernière pièce est posée, la bourse est pleine. Une poignée de pièces d'or versée dans une bourse de cuir, satisfaisante.
15. `depense` — 0,3 s — des pièces quittent la bourse pour payer un passage. Une pièce glissée sur le comptoir et lâchée dans un plateau de laiton, un peu à regret.

**La carte (le ruban)**
16. `puce` — 0,2 s — la puce de laiton part le long de la voie, ou une gare est choisie du doigt. Un jeton de laiton glissé sur du bois verni, avec un petit clic d'arrêt.
17. `arrivee` — 0,4 s — la puce arrive à la gare suivante. Une petite cloche de comptoir, une frappe, arrivée à bon port.
18. `glissement` — 0,4 s — l'écran des cartes glisse devant la carte du ruban, et revient. Une grande feuille de papier épais qu'on fait glisser sur un bureau, d'un seul mouvement.
19. `saut` — 1,2 s — le voyage de nuit : la caméra franchit un saut du ruban (un train de nuit, une traversée). Un train à vapeur qui passe au loin dans la nuit, bref, qui s'éloigne.
20. `annonce` — 0,5 s — en réserve, une annonce en gare. Un carillon d'annonce de gare ancienne, deux notes feutrées, un peu lointain dans le hall.

## Ce que j'attends de toi

Pour chacun des vingt sons, dans l'ordre, donne :
- une **description en anglais de 40 à 80 mots**, prête à coller dans le générateur, qui nomme l'objet, la matière, le geste, les couches, l'espace, la durée, et qui exclut explicitement ce qu'on ne veut pas (« no music, no synth, no reverb tail beyond N ms ») ;
- une **variante B** plus courte, dans une autre interprétation de la même scène, pour pouvoir choisir ;
- une ligne en français : **à quoi reconnaître la bonne prise** parmi celles que le générateur rendra.

Termine par un paragraphe sur la cohérence : la pièce commune, les trois matières dominantes, et ce qu'il faut vérifier à l'écoute des vingt sons à la suite.
