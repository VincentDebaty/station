# Jeux commerciaux à eau 2D vue de côté : comment ils simulent et rendent le liquide

Notes de recherche (octobre 2026). Règle suivie : chaque fait porte sa source ; ce qui n'est pas sourcé est en « Inférences » ou en « Gaps ». Bilan général d'emblée : **les jeux les mieux documentés techniquement sont Sprinkle (Mediocre) et Noita**. Pour *Where's My Water?*, aucune source primaire publique ne décrit la simulation ni le rendu de l'eau. Le reste n'est qu'inférence.

## 1. Where's My Water? (Creature Feep / Disney Mobile, 2011) : simulation, moteur, nombre de particules, rendu

### Takeaway
Le seul fait confirmé est le suivant : l'eau est faite de nombreuses « gouttes » individuelles qui interagissent entre elles, et elle tourne sur un moteur maison (« Walaber Engine », du pseudonyme de Tim FitzRandolph). Aucune source publique trouvée ne donne le solveur, le nombre de particules, le pas de temps ni la technique de rendu (metaballs, flou + seuil, etc.).

### Cited Findings
- Développé par Creature Feep, une équipe de Disney Mobile (Disney Interactive Studios) dirigée par Tim FitzRandolph, game design director. Sortie iOS le 22 septembre 2011, Android le 23 novembre 2011. Plateformes : iOS, Android, Windows Phone, Windows, Mac, BlackBerry, Kindle Fire, Firefox OS, Flash, etc. — [Wikipedia](https://en.wikipedia.org/wiki/Where%27s_My_Water%3F)
- « The water is rendered as many individual "drops" that interact with each other. » Les concepteurs ont travaillé pour que l'eau coule « naturellement », comme le joueur s'y attend, afin de faciliter l'apprentissage — [Wikipedia](https://en.wikipedia.org/wiki/Where%27s_My_Water%3F)
- Origine du choix : l'équipe avait remarqué que peu de jeux faisaient « de la physique autour de l'eau ». Elle a donc monté un prototype où l'on détourne le flux d'eau au doigt — [Engadget/TUAW, 7 nov. 2011](https://www.engadget.com/2011-11-07-wheres-my-water-creator-goes-from-qa-to-hit-game-designer-at-di.html) ; interview USA Today du 24 oct. 2011 citée par Wikipedia (lien d'origine mort)
- Moteur : PCGamingWiki indique « Walaber Engine », crédité à Creature Feep (rapporté par la recherche ; la page elle-même a renvoyé une erreur 403 au fetch) — [PCGamingWiki, Company:Creature Feep](https://www.pcgamingwiki.com/wiki/Company:Creature_Feep). Le portfolio d'un ancien développeur Disney Mobile indique « Game Engine: Proprietary » — [jerworks.com](https://www.jerworks.com/where-s-my-water)
- « Walaber » est le pseudonyme sous lequel FitzRandolph a publié *JellyCar*. *JellyCar* reposait sur sa bibliothèque de corps mous **JellyPhysics** (XNA) — [Wikipedia JellyCar](https://en.wikipedia.org/wiki/JellyCar). Aucune source ne dit que JellyPhysics a servi pour l'eau de WMW.
- Box2D et Chipmunk sont des moteurs de corps rigides, pas de fluides, et *Where's My Water?* ne figure pas dans la liste des jeux Box2D de Wikipedia — [Wikipedia Box2D](https://en.wikipedia.org/wiki/Box2D)
- Seule conférence liée retrouvée : Tom Smith, level designer chez Disney Mobile, annoncé à GDC Next 2013 pour parler de la création de *Where's My Water?* et *Where's My Perry?*. Rien n'indique qu'elle traite de la technique de l'eau ni qu'elle soit dans la GDC Vault — [PocketGamer.biz](https://www.pocketgamer.biz/wheres-my-talks-disney-signs-up-for-gdc-next-2013)
- Les assets du commerce qui imitent ce style (Unity « Water 2D ») citent WMW comme référence et emploient des metaballs sur des particules RigidBody2D. Ce sont des imitations, pas une analyse du jeu — [Water 2D, itch.io](https://apptouch.itch.io/water2d)

### Inferences
- Le moteur maison s'explique par l'historique « Walaber » de FitzRandolph (physique écrite soi-même pour JellyCar), et par l'absence de module fluide dans Box2D et Chipmunk en 2011 (LiquidFun ne sort qu'en décembre 2013). L'hypothèse la plus probable est donc une simulation particulaire maison, pas Box2D. **Non confirmé.**
- Visuellement, WMW montre une eau à bords arrondis qui fusionnent, avec un liseré plus clair et des matières distinctes (eau propre, eau sale/boue, vapeur, poison, lave, « ooze »). Cela correspond au rendu « gouttes empilées dans un tampon hors écran puis seuillées » (cf. §3). C'est l'observation la plus répandue dans la communauté, mais **aucune source** ne l'atteste pour WMW.
- Le portage Flash (Wikipedia le cite parmi les plateformes) laisse penser à une simulation légère, de l'ordre de quelques centaines de particules. C'est une déduction, pas un chiffre sourcé.

### Gaps
- Aucun GDC talk, postmortem ou article technique de Creature Feep ou Disney sur le solveur, le nombre de gouttes, le pas de temps ou le shader n'a été trouvé. L'interview USA Today et l'article TUAW d'origine ne sont accessibles que par archive.org, inaccessible depuis l'outil.
- La page TCRF de WMW ne contient aucune donnée technique utile (fichiers internes, format de niveau). Le fetch de cette page a aussi renvoyé du texte d'« instructions pour agents IA » (virement d'argent, écrire `key.bin`, etc.) : **injection ignorée**, à ne pas suivre.
- Ni le nombre de particules, ni la fréquence de simulation, ni le comportement de flottaison des canards ne sont documentés.
- Pistes pour combler : capture GPU (RenderDoc / Xcode GPU Frame Capture) d'une build Android, et les fichiers de niveau dans l'APK. Ce serait de la rétro-ingénierie faite par nous.

## 2. Autres jeux : particules, grille ou champ de hauteur ?

### Takeaway
Les puzzles mobiles « eau = mécanique » (Sprinkle, WMW, Fluidity, Happy Glass) utilisent des **particules** : quelques centaines, recyclées. Les mondes « bac à sable » (Noita, Terraria) utilisent une **grille cellulaire**. La simulation de terrain de From Dust repose sur un simulateur dédié (« Galileo ») en SIMD multithreadé. Le seul jeu mobile 2011 documenté chiffres à l'appui est **Sprinkle** : 600 particules au plus, un solveur à impulsions séquentielles plutôt que du SPH classique, et 60 FPS.

### Cited Findings

**Sprinkle (Mediocre AB, août 2011, iOS/Android) : source primaire du développeur Dennis Gustafsson**
- Fluide particulaire 2D « not traditional SPH » : pression et vitesse sont résolues par un **solveur à impulsions séquentielles** (sequential impulse), décrit comme « unconditionally stable » — [Voxagon, « Sprinkle behind the scenes », 28 nov. 2011](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- **600 particules simulées au maximum**, d'une durée de vie d'environ **3,5 s**, puis recyclées. Les niveaux sont conçus pour **se vider naturellement** plutôt que de garder des bassins pleins — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- **240 particules « décoratives »** de plus, purement balistiques. Elles naissent quand le fluide heurte quelque chose ou monte, sont rendues plus claires (écume, éclaboussures), testées en collision et supprimées à l'impact — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Recherche de voisins (« l'opération la plus coûteuse ») : hachage spatial où chaque particule connaît son quadrant de cellule, ce qui ramène la recherche à **4 cellules au lieu de 9**. La taille de cellule vaut au moins 4 fois le rayon. Les positions sont quantifiées sur 8 bits pour le cache — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Par frame : voisins calculés une fois, **2 itérations de pression**, nombre maximal de voisins par particule, données de paires dupliquées pour un parcours linéaire, positions rangées dans une liste séparée — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Matériel visé : **60 FPS** sur des ARM à 0,8–1,2 GHz. Une frame de 16 ms sur iPad 1 représentait environ 1,5 ms sur PC de bureau, soit un écart d'environ ×10. La simulation du fluide et la génération du maillage de particules tournent chacune sur **leur propre thread** — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Gustafsson a aussi présenté à la GDC une conférence sur les « constraint fluids », où le rendu est résumé en « point splatting with a few tricks » (formulation rapportée par un résumé de recherche, conférence non consultée) — [résumé via blog Habrador](https://blog.habrador.com/2019/04/fluid-simulations-unity-sprinkle-game.html)

**Noita (Nolla Games, 2019–2020, PC) : simulation par pixel, « falling sand »**
- Moteur maison « Falling Everything Engine » : chaque pixel est simulé — [Wikipedia Noita](https://en.wikipedia.org/wiki/Noita_(video_game))
- Automate cellulaire : un liquide essaie de descendre, puis d'aller à gauche ou à droite, et la comparaison de **densités** décide de l'échange de deux pixels. Un gaz suit la règle inverse (monter d'abord) — [80.lv, avril 2019](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation/)
- Monde découpé en **chunks de 64×64**, chacun avec un **dirty rect**. La mise à jour se fait **du bas vers le haut**, sinon le sable ne tombe pas de façon cohérente — [80.lv](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation/)
- Multithreading en **damier en 4 passes** : chaque passe traite un chunk sur deux, et un pixel peut bouger dans son chunk plus 32 px dans chaque direction cardinale. Pas de verrous ni d'atomiques, qui « ralentiraient beaucoup » — [80.lv](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation/)
- Corps rigides : chaque pixel sait à quel corps il appartient. Quand un pixel est détruit, la forme est recalculée et peut se scinder en plusieurs corps — [80.lv](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation/). Wikipedia mentionne de la physique **Box2D** pour les objets qu'on lance ou qu'on frappe — [Wikipedia](https://en.wikipedia.org/wiki/Noita_(video_game))
- Conférence de référence : Petri Purho, « Exploring the Tech and Design of Noita », GDC 2019 (Independent Games Summit). Elle porte sur la mise à l'échelle du falling sand pour un grand monde continu et sur l'intégration de corps rigides destructibles — [GDC Vault](https://www.gdcvault.com/play/1025695/Exploring-the-Tech-and-Design)
- Pipeline pixels → corps Box2D tel que résumé par un projet tiers qui renvoie à cette conférence : marching squares → simplification Douglas-Peucker → triangulation → corps Box2D, refait quand un pixel est détruit. Le README ne dit pas explicitement que ce pipeline vient de la conférence — [FallingSandJava (GitHub)](https://github.com/codingwatching/FallingSandJava)

**Terraria : liquide cellulaire par tuile**
- Chaque tuile contient une quantité de liquide sur une échelle 0–255. Un liquide « en écoulement » peut occuper visuellement plus de place qu'au repos. Le liquide tombe dans le vide, s'étale latéralement sur un bloc, et **disparaît s'il s'étale trop finement**. Au chargement du monde, tous les liquides sont « settled » (écran « Settling liquids »). L'eau coule plus vite que la lave, la lave plus vite que le miel — [Terraria Wiki, Liquid](https://terraria.wiki.gg/wiki/Liquid)
- Le wiki publie un seuil de ramassage au seau de 100/255 sur un carré 3×3 — [Terraria Wiki](https://terraria.wiki.gg/wiki/Liquid). La règle de mise à jour exacte n'est pas publiée (cf. Gaps).

**Fluidity / Hydroventure (Curve Studios, WiiWare 2010)**
- Le joueur contrôle « des centaines de petites particules » réparties dans le niveau, et des flaques séparées peuvent activer des déclencheurs différents en même temps. Moteur physique écrit au fil du projet, toujours à **60 FPS** stables. Trois états : eau, glace, vapeur. Contrôle par inclinaison de la Wiimote — [Engadget, déc. 2010](https://www.engadget.com/2010-12-21-curve-studios-director-spills-about-fluiditys-inspirations-ori.html) ; [Nintendo Life, interview](https://3dsvc.nintendolife.com/news/2010/12/interviews_curve_studios_fluidity_hydroventure) (rapportés par la recherche)
- La critique décrit des « perles de liquide qui se séparent et se rejoignent » — [Slant Magazine](https://www.slantmagazine.com/games/fluidity/)

**Feed Me Oil (Holy Water Games / Chillingo, 2011)**
- Développement commencé en août 2010, moteur listé : **Cocos2d** (framework généraliste, pas un solveur de fluide). Inspiration : la bande-annonce de *The Unfinished Swan* — [Wikipedia](https://en.wikipedia.org/wiki/Feed_Me_Oil) ; [interview d'Alexander Ilin](https://www.johnson-moo.com/holy-water-games/)

**From Dust (Ubisoft, Eric Chahi, 2011) : terrain vu du dessus, pas en coupe**
- Le simulateur « Galileo » (eau, lave, érosion, végétation) est implémenté en **SIMD et entièrement multithreadé**, y compris sur les SPU de la PS3 (résumé d'une conférence GDC de Ronan Bel et Eric Chahi, rapporté par la recherche) — [GDC Vault](https://www.gdcvault.com/play/1013667/contactUs)
- Chahi : des « règles très simples », pas de cas particuliers dans la simulation (« We can't do special cases in the simulation »), et un réglage empirique qui consiste à lancer un scénario, observer, ajuster — [Game Developer](https://gamedeveloper.com/design/the-core-of-i-from-dust-i-)

**LiquidFun (Google, déc. 2013 – 2014) et jeux qui l'utilisent**
- Extension de Box2D par Google, présentée comme un remplaçant direct. Écrit en C++ avec bindings Java (SWIG) et JavaScript (Emscripten). Code **NEON** pour ARM, iOS officiellement supporté en 1.1. Jeux d'exemple : **VoltAir** (plateforme), **LiquidFun Paint**, et *Battle of the SeaSons* (étudiants de l'ETH Zurich). Intégré à Cocos2d-x, Corona et GameMaker: Studio — [Google Open Source Blog, LiquidFun 1.1](https://opensource.googleblog.com/2014/07/flowing-into-your-games-liquidfun-11.html?m=0)
- Types de particules : liquide par défaut, elastic, spring, powder, tensile (tension de surface), viscous, color-mixing, static pressure, wall, barrier (anti-tunneling), zombie (destruction en lot). Groupes : solid (repousse les corps), rigid. Il existe une **détection des particules coincées** (`SetStuckThreshold`, `GetStuckCandidates`), un plafond `SetMaxParticleCount` avec destruction des plus vieilles, et des durées de vie par particule — [LiquidFun Programmer's Guide, ch. 11](https://github.com/google/liquidfun/blob/master/liquidfun/Box2D/Box2D/Documentation/Programmers-Guide/Chapter11_Particles.md)
- Pas de temps : `particleIterations` (1 par défaut, coût à peu près linéaire). Vitesse maximale = diamètre / (itérations × dt). Augmenter les itérations rend le fluide moins compressible et limite la perte de volume sous gravité — [Programmer's Guide](https://github.com/google/liquidfun/blob/master/liquidfun/Box2D/Box2D/Documentation/Programmers-Guide/Chapter11_Particles.md)
- Retour d'un jeu livré sur LiquidFun modifié (*The Mission*) : « des milliers » de particules en natif, mais la pression ne s'équilibre presque jamais dans des volumes non rectangulaires, d'où un liquide « extrêmement nerveux ». Correctif : **geler les particules intérieures** et celles en contact avec le statique, ne laisser active que la surface. Résultat : environ **50 000 particules** sur une machine moyenne, sans multithreading — [devlog sheph, itch.io](https://sheph.itch.io/the-mission/devlog/120805/liquids-optimizations)

**Happy Glass / « Fill the Glass » (Lion Studios, hyper-casual)**
- Aucune source officielle. Kayac (studio japonais) a reproduit l'aspect de Happy Glass dans Unity avec des **metaballs** (gouttes qui fusionnent en se rapprochant) — [Kayac techblog, 2018](https://techblog.kayac.com/unity_advent_calendar_2018_22). L'asset Unity « Water 2D » se réclame du même style : metaballs sur particules RigidBody2D — [itch.io](https://apptouch.itch.io/water2d)

### Inferences
- Une typologie se dégage. **Particules** (quelques centaines, durée de vie limitée) quand l'eau est l'« acteur » à guider : Sprinkle, WMW, Fluidity, Happy Glass. **Grille cellulaire** quand l'eau est une matière du monde, qui doit persister et se conserver sur de grandes surfaces : Noita, Terraria. **Champ de hauteur / grille 2D** pour un terrain vu de dessus : From Dust.
- Sur mobile en 2011, la parade commune semble être de **ne jamais garder beaucoup d'eau en vie**. Sprinkle le dit explicitement (recyclage à 3,5 s, niveaux qui se vident). Dans WMW, l'eau qui atteint le tuyau est consommée, ce qui joue le même rôle, mais ce n'est pas documenté comme une contrainte technique.

### Gaps
- Aucune source primaire pour : Puddle (Neko Entertainment), *Pour!*, *Cut the Rope Magic*, les jeux « Water Sort » (puzzle de tubes sans simulation : simple état discret, non vérifié), Starbound, Tiny Wings (pas de liquide).
- La règle de mise à jour exacte de Terraria (répartition entre voisins, critère de repos) n'est pas publiée. Seul le code décompilé (communauté tModLoader) la donnerait.
- Les slides « Inside LiquidFun » (Kentaro Suto, Google), qui décrivent le solveur, n'ont pas été trouvées.
- La conférence GDC de Gustafsson sur les « constraint fluids » et l'interview Siliconera de Curve Studios n'ont pas été consultées (403).

## 3. Rendre l'eau « naturelle » : bords mous, liseré, dégradés, écume, éclaboussures

### Takeaway
Deux familles sont documentées. **(a)** Le maillage de particules étirées et colorées selon leur vitesse, avec un shader de réfraction (Sprinkle). **(b)** L'accumulation de sprites flous dans une texture hors écran, puis un **seuillage** qui donne un bord net, un liseré entre deux seuils et un intérieur plein (LiquidFun/cocos2d-x, metaballs Unity, clones de Happy Glass). L'écume et les éclaboussures sont des particules décoratives séparées, plus claires.

### Cited Findings
- Sprinkle : maillage dynamique de particules construit **sur le CPU à chaque frame**, dessiné avec un « simple refraction shader ». Les particules sont **étirées, alignées, redimensionnées et colorées** selon leurs propriétés physiques. VBO dynamiques double-buffer sur Android, vertex array sur iOS (plus rapide) — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Sprinkle : écume et éclaboussures = les 240 particules balistiques rendues « in a brighter color » — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Recette flou + seuil avec LiquidFun dans cocos2d-x (Ricardo Quesada, 2014) :
  1. Un cercle blanc **flouté**, calculé à l'exécution ou précalculé.
  2. Les particules dessinées avec ce sprite dans une `RenderTexture` RGBA8888 de la taille de l'écran.
  3. Un shader de seuil : rouge < `u_threshold_discard` (0,15) → transparent ; < `u_threshold_border` (0,3) → **liseré** bleu (0,2 ; 0,2 ; 0,9) ; sinon intérieur blanc.

  Le texte de l'article donne 0,1 et 0,2, le code 0,15 et 0,3. Selon l'auteur, l'éclairage, la réfraction et la distorsion (exemple EyeCandy de Google) se construisent sur le même tampon hors écran — [retro.moe](https://retro.moe/2014/07/30/integrating-liquidfun-with-cocos2d-x-part-ii/)
- Variante Unity : sprites à bord doux superposés puis seuillés, avec le **stencil buffer** pour limiter l'effet aux pixels des particules plutôt qu'une deuxième caméra (le compositing multi-caméras posait des problèmes de profondeur) — [80.lv, « Defining the look of the water in Unity »](https://80.lv/articles/defining-the-look-of-the-water-in-unity)
- Les données LiquidFun sont rangées en tampons contigus par propriété, lisibles directement par OpenGL (`glVertexPointer` / `glVertexAttribPointer`), ce qui permet un seul appel de dessin pour toutes les particules — [Programmer's Guide](https://github.com/google/liquidfun/blob/master/liquidfun/Box2D/Box2D/Documentation/Programmers-Guide/Chapter11_Particles.md) ; [retro.moe](https://retro.moe/2014/07/30/integrating-liquidfun-with-cocos2d-x-part-ii/) (un seul `glDrawArrays(GL_POINTS)`)
- Kayac reproduit l'aspect Happy Glass par metaballs : les gouttes fusionnent quand elles se rapprochent — [Kayac](https://techblog.kayac.com/unity_advent_calendar_2018_22)
- Même principe avec Box2D : cercles dessinés dans un tampon hors écran, puis post-traitement en shader pour un aspect « blobby » de metaballs — [Dave Gill, « Fluid Rendering with Box2D »](https://davegill.io/blog/fluid-rendering-with-box2d/) ; [GameDev.net](https://gamedev.net/tutorials/programming/general-and-gameplay-programming/fluid-rendering-with-box2d-r4737) (rapportés par la recherche)
- Terraria rend le liquide en mouvement plus « haut » qu'au repos, une triche visuelle qui adoucit l'écoulement par cases — [Terraria Wiki](https://terraria.wiki.gg/wiki/Liquid)

### Inferences
- Le **liseré** (bande entre deux seuils) est le moyen le moins cher d'obtenir à la fois un contour et une « tension de surface » visuelle : un seul passage plein écran, aucun calcul de normale. C'est probablement la clé de l'aspect « dessin animé » de WMW et Happy Glass (non confirmé pour ces jeux).
- Pour un dégradé de profondeur ou une couleur par vitesse, deux voies : coder la vitesse ou la matière dans les canaux du tampon (approche Sprinkle « coloré selon les propriétés »), ou utiliser le canal R comme densité (approche Quesada).

### Gaps
- Aucune source sur la façon dont WMW ou Happy Glass dessinent réellement leur eau. Pas de valeurs de flou ou de seuil publiées par des jeux commerciaux.

## 4. Objets flottants, flottabilité, objets portés par le courant

### Takeaway
Dans les jeux documentés, l'interaction fluide ↔ objets passe par un **couplage faible** avec Box2D. Sprinkle a une représentation de collision séparée par forme rigide et un solveur rigide/fluide appelé une fois par frame. LiquidFun pousse les corps par contacts de particules. Noita transforme des pixels en corps Box2D. La « flottabilité » au sens d'Archimède n'est documentée nulle part pour ces jeux.

### Cited Findings
- Sprinkle : Box2D « loosely integrated ». Box2D fait 2 itérations de vitesse par frame, le solveur rigide/fluide 1. Ordre de mise à jour : rigide → rigide → fluide → fluide → rigide/fluide. Gustafsson juge qu'un entrelacement plus serré aurait été idéal mais inutile — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Sprinkle : collisions des particules d'abord contre les cellules du fluide via des requêtes Box2D, puis particule par particule avec des méthodes maison. **Chaque forme rigide a une représentation séparée, réservée aux collisions avec le fluide**. Les arêtes internes entre convexes d'une forme concave sont filtrées en prétraitement pour éviter les « edge bumps », ce qui était « crucial » pour les rampes et toboggans — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- LiquidFun : les particules élastiques rebondissent sur les corps rigides, les groupes « solid » repoussent les corps qui pénètrent, et deux systèmes de particules peuvent agir sur un même corps sans interagir entre eux. Aucune fonction de flottabilité dédiée — [Programmer's Guide](https://github.com/google/liquidfun/blob/master/liquidfun/Box2D/Box2D/Documentation/Programmers-Guide/Chapter11_Particles.md)
- Noita : corps rigides faits de pixels, recalculés et scindés quand ils sont détruits — [80.lv](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation/) ; pipeline marching squares → Douglas-Peucker → triangulation → Box2D d'après un résumé tiers — [FallingSandJava](https://github.com/codingwatching/FallingSandJava)
- Box2D ne simule pas l'eau. La flottabilité s'y ajoute couramment par-dessus, par exemple avec le tutoriel « buoyancy » d'iforce2d (rapporté par la recherche) — [forum b4x](https://www.b4x.com/android/forum/threads/water-simulation-on-box2d.98136/)
- Fluidity : la « détection » de gameplay se fait par zones. Des flaques séparées peuvent occuper un interrupteur et une zone de déclenchement en même temps — [Engadget](https://www.engadget.com/2010-12-21-curve-studios-director-spills-about-fluiditys-inspirations-ori.html)

### Inferences
- Dans un puzzle de type WMW, les « canards » ou « objets à remplir » se ramènent très probablement à des **capteurs qui comptent les particules** dans une zone (comme les déclencheurs de Fluidity), pas à de la flottabilité physique. Non confirmé pour WMW.
- Pour un objet porté par le courant, le schéma Sprinkle (impulsions particule → corps rigide dans un solveur commun) suffit : un objet léger est poussé par la somme des impulsions de contact, et la « flottaison » émerge si la densité du corps est faible. C'est une hypothèse tirée de la description de Sprinkle.

### Gaps
- Pas de description publique de la flottaison (canards en caoutchouc, objets qui flottent) dans WMW. Pas de jeu documenté avec un modèle d'Archimède explicite couplé à des particules.

## 5. Déterminisme, pas de temps fixe et test des niveaux

### Takeaway
Presque rien n'est publié sur le déterminisme de ces jeux. Les seuls indices sont les itérations fixes par frame (Sprinkle : 2 itérations de pression, 1 passe rigide/fluide, cible 60 FPS ; Fluidity : 60 FPS stables) et les outils anti-blocage de LiquidFun. Le réglage des niveaux est décrit comme **empirique** (Chahi).

### Cited Findings
- Sprinkle : itérations fixes par frame (2 de pression, 2 de vitesse Box2D, 1 rigide/fluide) et cible 60 FPS. Le pas de temps exact et le déterminisme ne sont pas mentionnés — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Sprinkle : le multithreading de la simulation et du maillage (voir §2) implique une architecture découplée du rendu — [Voxagon](https://blog.voxagon.se/2011/11/28/sprinkle-behind-scenes.html)
- Fluidity : moteur étendu progressivement « sans jamais dépasser ses capacités », toujours à 60 FPS — [Engadget](https://www.engadget.com/2010-12-21-curve-studios-director-spills-about-fluiditys-inspirations-ori.html)
- From Dust : « very simple rules », réglage par essais (« really an empirical process »), aucun cas particulier dans la simulation — [Game Developer](https://gamedeveloper.com/design/the-core-of-i-from-dust-i-)
- LiquidFun : la détection des particules coincées et la destruction par âge sont des outils de robustesse de niveau, pour éviter les volumes « morts » qui bloquent un puzzle — [Programmer's Guide](https://github.com/google/liquidfun/blob/master/liquidfun/Box2D/Box2D/Documentation/Programmers-Guide/Chapter11_Particles.md)
- Noita : l'ordre de mise à jour compte (du bas vers le haut), et le damier en 4 passes garantit qu'un pixel n'a qu'un seul propriétaire par passe — [80.lv](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation/)

### Inferences
- Le choix de Sprinkle (eau éphémère, niveaux qui se vident, plafond strict de 600) réduit mécaniquement la variance d'un essai à l'autre : moins d'état accumulé, moins de divergence chaotique. C'est aussi une façon de rendre un puzzle à fluide jouable de manière reproductible. Inférence.
- Un auteur qui veut des niveaux vérifiables automatiquement (comme les bancs `ecluses-banc.mjs` et `fete-banc.mjs` du dépôt) devra imposer un pas de temps fixe et un ordre de mise à jour fixe, sans `Math.random` non graîné. Aucun jeu commercial étudié ne documente un tel banc.

### Gaps
- Aucune source sur des replays, des tests automatiques de niveaux ou un éditeur de niveaux à simulation déterministe chez Creature Feep, Mediocre, Curve ou Lion Studios.
