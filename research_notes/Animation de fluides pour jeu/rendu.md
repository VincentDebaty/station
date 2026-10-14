# Rendu de l'eau 2D cartoon (indépendant de la méthode de simulation)

Contexte local, relevé dans le dépôt (pas une source web) : `prototypes/prototype-labyrinthe.html`
simule l'eau en petites cases (4×4 par case de labyrinthe), en tire un champ, extrait
l'iso-contour 0,5 par marching squares, relie les segments en boucles, puis dessine un
`<path>` SVG rempli + un second `<path>` en trait clair (« écume », `stroke-width 0.07`),
le tout reconstruit à chaque `requestAnimationFrame`. Le dernier commit (e28323a) dit
« l'eau ne fait plus d'angles — contours arrondis ». Les remarques ci-dessous sur
SVG/Canvas/WebGL s'appliquent à ce cas précis.

## 1. D'où vient le look « blob doux + liseré clair » (Where's My Water? et apparentés), et comment le faire aujourd'hui

### Takeaway
La recette canonique documentée est : dessiner chaque particule comme un sprite rond à
bord dégradé dans une texture hors écran (blending additif), puis repasser cette texture
dans un shader de seuil (alpha-test / smoothstep) ; une bande de seuil intermédiaire
donne gratuitement le liseré, et un décalage ±1 px clair/sombre donne un biseau. Aucune
source primaire ne décrit la technique exacte de Where's My Water? — c'est une
attribution plausible, pas un fait.

### Cited Findings
**Where's My Water? lui-même**
- Développé par Creature Feep, équipe interne de Disney Mobile dirigée par Tim
  FitzRandolph (auteur de JellyCar) ; l'interview USA Today dit que le début du
  développement était centré sur la physique de l'eau et le toucher pour la guider —
  aucune donnée technique de rendu publiée trouvée — [Wikipedia](https://en.wikipedia.org/wiki/Where%27s_My_Water%3F) ; [Disney, Inside Perspective](https://thewaltdisneycompany.com/inside-perspective-the-team-behind-disneys-wheres-my-water/)
- Un brevet « Method for rendering fluid » décrit le rendu de chaque particule comme un
  metaball 2D par *point splatting*, avec empilement de couches et textures
  multicouches pour suggérer épaisseur et profondeur, temps réel pour jeux — rien ne
  le relie à WMW — [USPTO 8368688](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/8368688)

**Metaballs « vrais » (champ analytique)**
- Champ = Σ r²/d² sur toutes les boules ; la surface est f = 1 ; c'est la *somme* (et
  non le max) qui fait fusionner les blobs voisins — [Jamie Wong, Metaballs and Marching Squares](https://jamie-wong.com/2014/08/19/metaballs-and-marching-squares/)
- Évaluer f à chaque pixel coûte cher : 40 cercles sur 700×500 ≈ 14 M opérations par
  image (≈ 840 M/s à 60 fps) sur CPU — [Jamie Wong](https://jamie-wong.com/2014/08/19/metaballs-and-marching-squares/)
- Un brevet sur l'eau en particules note que les metaballs donnent une surface « goo »
  bosselée qui ne convient pas toujours à l'eau (alternatives : iso-surfaces, level sets) — [USPTO 7349832](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7349832)

**Sprites flous + seuil (la version GPU des metaballs)**
- Tuts+ (Michael Hoffman) : particules dessinées dans un `RenderTarget2D` vidé en
  transparent, en `BlendState.Additive`, teinte bleu clair, échelle ×2 ; la texture de
  particule s'estompe du centre vers le bord, c'est ce qui fait fusionner les gouttes ;
  composition à l'écran par `AlphaTestEffect` avec **ReferenceAlpha = 175** (≈ 0,69) — [Envato Tuts+, Make a Splash With Dynamic 2D Water Effects](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- Même tutoriel : pour que les gouttes se fondent dans la nappe, une bande de 20 px
  dégradée bleu clair → transparent est dessinée le long de la surface dans la même
  texture ; **biseau** obtenu en dessinant la texture trois fois : (−1,−1) teinte pâle
  (0.8,0.8,1.0), (+1,+1) bleu sombre (0,0,0.2), puis (0,0) la teinte normale — raccourci
  avoué à la place d'un vrai shader — [Envato Tuts+](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- LiquidFun + Cocos2d-x : cercle blanc flouté (à l'exécution ou hors ligne), dessiné par
  particule dans un `RenderTexture` RGBA8888 de la taille de l'écran ; shader de seuil
  à trois bandes sur le canal rouge : `r < 0.15` → jeté ; `r < 0.30` → couleur de
  **bordure** (0.2,0.2,0.9) ; sinon intérieur — c'est exactement le liseré type WMW,
  obtenu sans passe supplémentaire — [retro.moe, Integrating LiquidFun with Cocos2d-x Part II](https://retro.moe/2014/07/30/integrating-liquidfun-with-cocos2d-x-part-ii/)
- Corona/LiquidFun : un rayon d'image légèrement plus grand que le rayon physique fait
  se chevaucher les particules et donne un liquide plus cohésif — alternative bon marché
  au flou — [Corona Labs, LiquidFun Essentials](https://docs.coronalabs.com/tutorial/games/introLiquidFun/index.html)
- Defold : même pipeline (sprite dont l'alpha décroît = densité, additif dans une render
  target, seuil dans une 2e passe) ; bogue rencontré : layers *multipliés* au lieu
  d'*additionnés* dans le matériau de la render target — [Defold forum, Fluid simulation 2D – metaballs](https://forum.defold.com/t/fluid-simulation-2d-metaballs/47371)

**Version « screen-space » (van der Laan / NVIDIA), adaptable en 2D**
- Pipeline : sprites sphériques → image de profondeur → flou gaussien *bilatéral*
  (préserve les bords) → normales → ombrage ; épaisseur rendue en additif sans test de
  profondeur, « only needs to be approximate », « very fill-rate intensive », « can render
  at lower resolution » ; couleur atténuée par l'épaisseur (loi de Beer) ; réfraction
  par `tex2D(bg, uv + N.xy * thickness)` — [NVIDIA GDC 2010, Simon Green, Screen Space Fluid Rendering for Games](https://developer.download.nvidia.com/presentations/2010/gdc/Direct3D_Effects.pdf)
- Le papier original lisse la surface (curvature flow) précisément pour éviter le look
  « blobby / jelly » et évite toute polygonisation, donc les artefacts de grille du
  marching cubes — [van der Laan et al. 2009, I3D](https://www.win.tue.nl/~wstahw/edu/2IV05/andrei/particle_rendering/provided/p91-van_der_laan.pdf)

**Variante SVG (« gooey effect »)**
- `feGaussianBlur stdDeviation="10"` puis `feColorMatrix` dont la ligne alpha est
  `0 0 0 19 -9` : α' = 19α − 9 → transparent sous α ≈ 0,47, opaque au-dessus ; variantes
  plus douces `18 -7` ; on recompose souvent avec `feComposite operator="atop"` — [Codrops, Creative Gooey Effects](https://tympanus.net/codrops/2015/03/10/creative-gooey-effects/) (page 403 au moment de la recherche ; valeurs rapportées via le résumé de recherche, à vérifier) ; [CSS-Tricks, gooey](https://css-tricks.com/?p=195076)

**Godot 4**
- Shader `canvas_item` : `uniform sampler2D tex : hint_screen_texture` lu à `SCREEN_UV` ;
  flou bon marché en montant le LOD de `textureLod` avec un filtre mipmap (Godot génère
  les mips) ; la copie d'écran est faite **une fois** par back buffer (premier nœud
  qui l'utilise) ; `BackBufferCopy` pour forcer une recopie ou limiter à une région —
  [Godot docs, Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)
- Asset Unity (payant) pour 2D URP : matériau « liquide » Shader Graph avec caustiques,
  inner glow, edge foam, edge glow, distorsion — montre que le liseré/edge glow est la
  norme du genre — [Fab, 2D Liquid Shader](https://www.fab.com/listings/077b4709-66d6-445a-a5ef-91a1840c827f?lang=fr)

### Inferences
- Le « look WMW » se décompose en : (a) silhouette à seuil d'un champ lisse (aucune
  facette), (b) liseré clair = bande de seuil [t1, t2] coloriée plus clair (méthode
  Cocos) ou différence entre deux seuils, (c) intérieur en dégradé vertical ou selon
  la densité, (d) gouttes isolées qui restent rondes parce que le champ d'une seule
  particule est un disque. (b) est le point clé et ne coûte rien de plus que le seuil.
- Implémentation Godot 4 recommandée : une `SubViewport` (fond transparent,
  `transparent_bg = true`, taille ½ ou ¼ de l'écran) contenant les « blobs » (un
  `MultiMeshInstance2D` ou `GPUParticles2D` avec texture radiale blanche, matériau
  `blend_add`) ; un `TextureRect`/`Sprite2D` plein écran affiche la `ViewportTexture`
  avec un shader : `float a = texture(TEXTURE, UV).a; float body = smoothstep(t-e, t+e, a);
  float rim = body - smoothstep(t2-e, t2+e, a);` puis `COLOR = mix(water, rimColor, rim)
  * body`. Le `smoothstep` (au lieu d'un `step`/alpha-test) donne l'antialiasing du bord
  gratuitement, surtout quand la texture est sous-échantillonnée et upscalée en bilinéaire.
  (Synthèse personnelle, pas de tutoriel Godot 4 complet trouvé.)
- Même schéma en Unity URP 2D : une seconde caméra rendant un layer « eau » dans une
  RenderTexture, puis un sprite plein écran à shader de seuil. En WebGL : un FBO,
  `gl.blendFunc(ONE, ONE)`, quads instanciés, puis une passe plein écran.
- **Pour une simulation en grille** (le cas du labyrinthe), pas besoin de particules :
  téléverser le champ de masse comme une petite texture (une valeur par petite case),
  la laisser filtrer en bilinéaire (ou mieux bicubique) par le GPU, éventuellement
  flouter d'une passe, puis appliquer le même shader de seuil + liseré. C'est un
  marching squares « implicite » au pixel près, sans géométrie.
- SDF : le seuil d'un champ flouté est une approximation de SDF ; pour des formes
  analytiques (gouttes, boule) un `smin` polynomial permet de faire fusionner une
  goutte avec la nappe. (La page d'Inigo Quilez sur `smin` renvoyait 404 ; non citée.)

### Gaps
- Aucune source primaire (talk GDC, postmortem, capture de frame) sur la technique
  réelle de Where's My Water? ; l'attribution « metaballs/seuil » reste une hypothèse.
- Pas de tutoriel Godot 4 complet et vérifié « SubViewport + seuil » trouvé ; la
  recette ci-dessus est assemblée à partir de la doc et des autres moteurs.
- Vidéo de Sebastian Lague sur le rendu des fluides : non trouvée dans les résultats ;
  rien n'est cité à son sujet.

## 2. Pourquoi les simulations en grille ont l'air « cubiques / anguleuses » même lissées, et les remèdes

### Takeaway
Les angles viennent de trois sources : marching squares sans interpolation (segments à
45° fixés au milieu des arêtes), une résolution de grille grossière par rapport aux
pixels (la courbure maximale représentable est d'une cellule), et l'aliasing temporel
(le contour saute d'une cellule à l'autre d'un pas à l'autre). Les remèdes efficaces,
dans l'ordre : interpolation linéaire sur les arêtes, champ lissé (flou/bilinéaire)
avant extraction, extraction au pixel (shader) plutôt qu'en polygones, surface à
ressorts pour la ligne d'eau, et interpolation temporelle.

### Cited Findings
- Sans interpolation, les extrémités de segment sont placées à des positions fixes
  (milieux d'arêtes) : contour en segments à 45° qui « still looks blocky » ;
  l'interpolation linéaire des valeurs des deux coins place le point là où f croise le
  seuil et donne des courbes lisses sans augmenter la résolution — [Jamie Wong](https://jamie-wong.com/2014/08/19/metaballs-and-marching-squares/)
- Deux configurations sur 16 sont ambiguës (selles) ; il faut une règle (ex. supposer
  le centre de cellule à l'intérieur) — [Jamie Wong](https://jamie-wong.com/2014/08/19/metaballs-and-marching-squares/)
- Grille plus fine = plus lisse mais plus cher ; l'interpolation apporte l'essentiel du
  gain à résolution grossière — [Jamie Wong](https://jamie-wong.com/2014/08/19/metaballs-and-marching-squares/)
- Le rendu screen-space évite la polygonisation et donc les artefacts de grille du
  marching cubes — [van der Laan et al. 2009](https://www.win.tue.nl/~wstahw/edu/2IV05/andrei/particle_rendering/provided/p91-van_der_laan.pdf)
- Une approche « canal alpha » est plus simple que le marching en 2D, mais avec des
  résultats potentiellement « plus sales » — [gamedev.net forum, SPH](https://www.gamedev.net/forums/topic/397873-resources-on-smoothed-particle-hydrodynamics-sph/3644950/)
- Exemple GDevelop d'eau 2D par marching squares sur un champ scalaire + physique — [d8h, liquid demo](https://d8h.itch.io/liquid-demo)

### Inferences
- Même avec interpolation, un champ de *masse par cellule* (0..1) à transitions raides
  produit des contours qui suivent les murs et les marches de la grille : le
  remplissage partiel d'une cellule est souvent étalé horizontalement (surface plate
  par cellule), d'où des « marches d'escalier » sur une surface en pente. Remède :
  passer le champ à un flou séparable 3×3 ou 5×5 *avant* l'extraction (et masquer
  les murs pour ne pas « baver » à travers), ou dériver la hauteur de surface par
  colonne (voir §3) plutôt que de l'iso-contour.
- Le lissage des polygones extraits (Chaikin, Catmull-Rom, ou courbes `Q`/`C` en SVG
  au lieu de `L`) arrondit les coins mais ne corrige pas le saut temporel ; il faut
  aussi lisser dans le temps : soit interpoler l'état (§5), soit un EMA du champ rendu
  (`rendu = rendu*0.7 + sim*0.3`) qui supprime le scintillement au prix d'un léger retard.
- Surcouche de particules : quelques gouttes/éclaboussures rondes au-dessus du contour
  masquent les arêtes résiduelles et donnent de la vie ; l'œil lit « liquide » sur les
  gouttes plus que sur le contour.
- Dans le prototype SVG actuel, la plus grosse amélioration probable sans changer la
  sim : contour en courbes (Catmull-Rom → Bézier) + champ lissé + interpolation
  temporelle ; la plus grosse en rupture : passer le rendu de l'eau en
  Canvas2D/WebGL avec seuil au pixel (§4).

### Gaps
- Pas de devlog trouvé qui mesure avant/après pour une simulation cellulaire de jeu
  (type Noita, Terraria) ; les remèdes temporels (EMA) sont des inférences.

## 3. Combiner une surface « height-field / ressorts » avec une simulation de volume

### Takeaway
La surface à ressorts de Hoffman est un modèle 1D bon marché (une colonne = un ressort
vertical, Hooke + amortissement, propagation aux voisins en plusieurs passes) qui donne
des vagues et des réactions d'impact très lisibles ; on la superpose à une simulation de
volume en prenant le niveau moyen de chaque colonne comme hauteur de repos et en
injectant les impacts comme vitesses.

### Cited Findings
- Modèle : chaque point de surface est un ressort vertical, a = −(k/m)·x − d·v ; démo
  k = 0.025, d = 0.025 ; k bas = vagues lentes et grandes, k haut = vaguelettes rapides
  et « jiggly » ; intégration d'Euler, instable si k trop raide — [Envato Tuts+](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- Propagation : chaque ressort tire ses voisins gauche/droite selon la différence de
  hauteur × **Spread** (0 à 0,5) ; **8 passes** par image ; différences stockées dans
  `leftDeltas`/`rightDeltas` avant de modifier les hauteurs — [Envato Tuts+](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- 201 ressorts pour 800 px (≈ 4 px d'écart) ; l'auteur note que moins de ressorts
  resterait lisse — [Envato Tuts+](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- Rendu : chaque segment = trapèze (2 triangles) de la surface jusqu'au bas ; dégradé
  vertical par couleurs de sommets, haut bleu clair (0.2,0.5,1.0)×0.8, bas bleu nuit — [Envato Tuts+](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- Éclaboussures : déclenchées si vitesse d'impact > 60, nombre = vitesse/8, décalage
  aléatoire ≤ 40 px, angles −150° à −30°, vitesse 0,5·√vitesse, gravité 0,3/image,
  supprimées sous la surface — [Envato Tuts+](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- Coquilles du code de l'article : `springs[i]` au lieu de `springs[index]` dans
  `Splash()`, `velocity` au lieu de `vel` — [Envato Tuts+](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- Portages Godot/Unity existants du même modèle — [pixelipy, water 2d simulation (Godot 3)](https://pixelipy.itch.io/water-2d-simulation) ; [MemoryLeakHub, Water2D-Unity](https://github.com/MemoryLeakHub/Water2D-Unity)

### Inferences
- Couplage avec une sim de volume (grille) : pour chaque colonne de la sim, calculer
  la hauteur de surface h_sim(x) (somme des masses dans la colonne, à partir du fond du
  bassin connexe) ; la *hauteur cible* du ressort = h_sim(x), le ressort ne porte que
  le *déplacement* autour. Quand h_sim change brusquement (eau qui arrive), injecter
  une vitesse proportionnelle plutôt que téléporter la cible → vague. Les impacts
  (boule, gouttes) ajoutent une vitesse au ressort le plus proche.
- Le rendu final = polygone sous la courbe des ressorts (interpolée en spline) ∪ le
  volume « intérieur » de la sim ; ou, dans l'approche shader, ajouter le déplacement
  des ressorts au champ avant le seuil (une texture 1D de déplacements par colonne).
- Limite : un height-field ne représente qu'une surface par colonne (pas de
  déferlement, pas de deux nappes superposées) ; dans un labyrinthe à plusieurs poches,
  il faut un jeu de ressorts *par poche/segment de surface libre*, ou n'animer que les
  surfaces libres horizontales larges.
- Euler explicite est instable avec k élevé : sous-pas ou Euler semi-implicite
  (v += a·dt puis x += v·dt) recommandés.

### Gaps
- Aucune source trouvée décrivant précisément le couplage ressorts + sim de volume
  dans un jeu publié ; la recette ci-dessus est une inférence.

## 4. Performances mobiles (iPhone) et choix technique web (SVG / Canvas2D / WebGL)

### Takeaway
Le coût de « rendu hors écran + flou + seuil » est dominé par le *fill rate* (pixels
dessinés × chevauchement des sprites) et par les passes hors écran ; la parade standard
est de rendre la passe d'accumulation en basse résolution (½ à ¼) et d'upscaler dans la
passe de seuil, avec un `smoothstep` pour l'antialiasing. Sur GPU à tuiles (Apple), éviter
les chargements/stockages inutiles d'attachements. Côté web, le filtre SVG « goo » est
la solution la plus simple pour un prototype mais n'a pas de chiffres de perf publiés.

### Cited Findings
- La passe d'épaisseur (particules additives) n'a besoin que d'être approximative, est
  « very fill-rate intensive » et peut être rendue en basse résolution — [NVIDIA GDC 2010](https://developer.download.nvidia.com/presentations/2010/gdc/Direct3D_Effects.pdf)
- Le flou bilatéral 2D n'est pas séparable en X puis Y (coûteux) ; le flou gaussien
  l'est — [NVIDIA GDC 2010](https://developer.download.nvidia.com/presentations/2010/gdc/Direct3D_Effects.pdf)
- Metal, GPU à tuiles : load action `DontCare` gratuite si tous les pixels sont
  réécrits, `Clear` coûte l'écriture de la valeur, `Load` coûte une relecture ; store
  `DontCare` gratuit, `Store` nécessaire pour ce qui est relu plus tard — [Apple, Metal Best Practices: Load and Store Actions](https://developer-mdn.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/LoadandStoreActions.html)
- Le GPU exécute load → raster/ombrage → store **par tuile** ; charger seulement ce qui
  sert, vider quand on n'a pas besoin du contenu précédent — [WWDC20 session 10602](https://developer.apple.com/wwdc20/10602)
- Une texture intermédiaire *memoryless* reste en mémoire de tuile et économise la bande
  passante ; les apps multi-passes sinon écrivent et relisent en mémoire vidéo — [Metal by Tutorials ch.15](https://koenig-assets.raywenderlich.com/books/metal-by-tutorials/v4.0/chapters/15-tile-based-deferred-rendering) ; [Apple, Tailor your apps for Apple GPUs and TBDR](https://developer.apple.com/tutorials/data/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering.md)
- Godot : la lecture d'écran (`hint_screen_texture`) déclenche une copie plein écran,
  une seule fois par back buffer ; les mips donnent un flou sans passe dédiée — [Godot docs, Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)
- Cocos2d-x/LiquidFun crée sa texture hors écran à la taille de la fenêtre (RGBA8888) ;
  aucun chiffre de fps publié — [retro.moe](https://retro.moe/2014/07/30/integrating-liquidfun-with-cocos2d-x-part-ii/)
- Filtre SVG goo : support listé Chrome 111+, Edge 111+, Firefox 113+, **Safari 16.2+**
  pour un composant récent ; aucune mesure de perf trouvée — [freefrontend, CSS gooey](https://freefrontend.com/css-gooey/)

### Inferences
- Ordre de grandeur (calcul, non mesuré) : écran iPhone ~2556×1179 ≈ 3 Mpx en natif ;
  une texture à ¼ de résolution linéaire (≈ 640×295) = ~0,19 Mpx, soit 16× moins de
  fill pour l'accumulation ; à cette taille, quelques centaines de sprites de 16–32 px
  de rayon et une passe de seuil plein écran sont négligeables pour tout iPhone récent.
  Le seuil avec `smoothstep` + filtrage bilinéaire masque l'upscale.
- Pour une sim en grille, la « texture de champ » peut être *minuscule* (une valeur par
  petite case, ex. 64×48) : c'est le GPU qui interpole. Coût quasi nul — c'est
  l'option la plus rentable pour le labyrinthe/écluses sous Godot.
- Godot 4 : préférer une `SubViewport` dédiée (render_target_update_mode = always,
  taille réduite) au `hint_screen_texture` (qui copie tout l'écran). Sur le renderer
  Mobile/Compatibility, chaque SubViewport est une passe de rendu supplémentaire : en
  garder une seule pour toute l'eau.
- Web : 
  - **SVG** (actuel) : reconstruire un `d` de path à chaque image coûte en CPU
    (parsing + tessellation) proportionnellement au nombre de segments ; un filtre
    `feGaussianBlur` + `feColorMatrix` sur un groupe de cercles donne le look goo en
    10 lignes mais recalcule le flou sur toute la région filtrée à chaque image — à
    tester sur iPhone avant d'en dépendre.
  - **Canvas2D** : `ctx.filter = 'blur()'` n'est pas fiable sur Safari (à vérifier) ;
    on peut faire le seuil à la main sur un `ImageData` de petite taille (champ de la
    grille → canvas 64×48 → `drawImage` agrandi avec lissage) mais le seuil au pixel en
    JS est lent en grand.
  - **WebGL** : la seule option qui fait seuil + liseré + dégradé + réfraction au pixel
    à coût constant ; une texture de champ + un fragment shader de 20 lignes, et c'est
    exactement ce qui sera porté sous Godot (même shader, GLSL quasi identique).

### Gaps
- Aucune mesure publiée (ms GPU) de blur+threshold sur iPhone trouvée ; à mesurer
  avec la capture de frame Xcode ou le profiler Godot.
- Pas de benchmark SVG filter vs Canvas vs WebGL sur Safari iOS trouvé.

## 5. Objet flottant convaincant, éclaboussures, et fluidité temporelle

### Takeaway
Un flottant crédible = sa ligne de flottaison lue sur la *même* fonction de surface que
celle qui est dessinée (sinon il décroche), un ressort amorti vers cette ligne
(bobbing), une impulsion aux ressorts de surface + gerbe de particules à l'entrée, et
une partie immergée teintée/masquée par l'eau. Et toute la scène doit être rendue
interpolée entre deux pas fixes de simulation.

### Cited Findings
- Flottaison simple : comparer la position de l'objet à la hauteur de surface à son x,
  puis appliquer une force ou un lerp vers la ligne d'eau — [Unity Discussions, 2D water line without physics](https://discussions.unity.com/t/2d-water-line-without-physics/614533)
- Un développeur constate que brancher la hauteur de vague « vue » en différé faisait
  osciller les objets hors phase et dépasser la surface ; correctif : la **même**
  fonction de hauteur dans le shader et dans le code de jeu (le shader ne peut pas être
  relu par le CPU, donc réimplémentée en GDScript) — [gamedev.net, Playing with water physics](https://gamedev.net/blogs/entry/2266519-playing-with-water-physics)
- Module Hydro (Godot 3/4) : flottabilité, traînée, portance, fonction de vague
  branchable — [godot-extended-libraries/hydro](https://github.com/godot-extended-libraries/hydro/wiki)
- Éclaboussures : particules lancées à l'impact (seuil de vitesse, nombre ∝ vitesse),
  retirées quand elles repassent sous la surface ; rendues dans la même texture
  metaball que l'eau pour fusionner avec elle — [Envato Tuts+](https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
- Pas fixe + accumulateur : la sim consomme le temps par pas de `dt` ; on rend l'état
  interpolé `current*alpha + previous*(1-alpha)` avec `alpha = accumulator/dt` ; sans
  cela l'état affiché avance ou retarde d'une fraction de pas → saccade (« temporal
  aliasing ») ; plafonner le temps de trame (0,25 s) pour éviter la « spirale de la
  mort » — [Gaffer On Games, Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep/)

### Inferences
- **Immersion partielle** : dessiner l'objet, puis par-dessus la partie de l'eau qui le
  recouvre en semi-transparence (alpha 0,3–0,5) + un trait de flottaison clair
  (le liseré de §1 passe naturellement devant l'objet si l'eau est dessinée après) ;
  en shader, assombrir/teinter la partie sous la ligne et décaler ses UV par un bruit
  qui défile (réfraction factice). Cela se lit bien mieux qu'un objet simplement posé.
- **Bobbing** : ressort amorti (ζ ≈ 0,3–0,5) vers la flottaison + légère rotation
  proportionnelle à la pente locale de la surface (dérivée des hauteurs de ressorts) ;
  déphaser le visuel n'est jamais nécessaire si la même surface sert au calcul.
- **Entrée dans l'eau** : vitesse transmise aux 2–5 ressorts sous l'objet (creux puis
  rebond), gerbe proportionnelle à la vitesse, petites bulles qui remontent ; un
  « squash » de 1–2 images sur l'objet renforce le cartoon.
- **Jelly / wobble** : appliquer à l'objet flottant un ressort d'échelle (squash &
  stretch) excité par les impacts ; sur la nappe, un bruit lent (sinus de faible
  amplitude) ajouté aux ressorts empêche l'eau au repos d'avoir l'air figée.
- **Dégradé par profondeur** : couleur = mix(clair, sombre, distance à la surface) —
  en shader, on peut l'obtenir en échantillonnant le champ décalé vers le haut, ou via
  une texture de « hauteur de surface par colonne » ; en SVG, un `linearGradient`
  vertical par bassin suffit.
- **Interpolation pour une sim en grille** : interpoler le *champ* (lerp des masses
  entre deux pas) avant le seuil/contour, pas les polygones (dont la topologie change) ;
  avec un pas de sim à 30 Hz et un rendu à 60/120 Hz (ProMotion), c'est ce qui retire
  la saccade restante du prototype.

### Gaps
- Aucune source trouvée sur la façon exacte dont WMW ou d'autres jeux cartoon masquent
  la partie immergée d'un objet ; les techniques ci-dessus sont des inférences.
- Pas de valeurs de référence publiées pour l'amortissement du bobbing en jeu cartoon.
