"use strict";
// ------------------------------------------------------------------
// LIGNES DE CHEMIN DE FER RÉELLES — la topologie du réseau de la carte.
//
// Pourquoi ce fichier existe : les `portals` d'une fiche sont des DESTINATIONS,
// pas des voisins. « Namur → LUXEMBOURG » désigne un train qui roule par
// Libramont et Arlon ; en déduire une arête Namur–Luxembourg dessinait une corde
// droite à travers l'Ardenne, et multipliait les traits qui ne correspondent à
// aucune voie. Un réseau ferré ne se décrit pas par des couples origine ↔
// destination mais par des LIGNES : une suite ordonnée de points desservis.
//
// Une ligne = { id, name, nodes: [...] }, où chaque nœud est soit l'id d'une
// gare jouable (« namur »), soit la clé d'un POINT DE PASSAGE de data/places.js
// (« ciney »), qui donne au trait la forme de la voie sans se dessiner lui-même.
// js/network.js en tire les arêtes : chaque paire CONSÉCUTIVE, et rien d'autre.
// Namur–Ciney, Ciney–Marloie, Marloie–Libramont — jamais Namur–Libramont.
//
// On ne décrit QUE ce qui relie des gares jouables. Une antenne vers un
// cul-de-sac (Bruges–Ostende, Hasselt–Genk, Herentals–Turnhout) n'est pas une
// ligne de ce fichier : ces destinations existent sur le gril, pas sur la carte
// (tools/AUTHORING-STATIONS.md §0). Un trait qui s'arrête dans le vide est
// exactement ce qu'on cherche à éviter.
//
// Règle de préséance (js/network.js) : elle s'applique PAR PAYS, via
// LINE_COUNTRIES ci-dessous. Un pays qui y figure tient toute sa topologie des
// lignes ; les autres gardent la déduction par portails en attendant les leurs.
//
// Pourquoi par pays et non par gare : Lille apparaît au bout de la L94F, sans
// qu'aucune de ses lignes françaises ne soit écrite. La traiter comme « décrite »
// lui retirait ses portails, donc toutes ses relations françaises — elle devenait
// un cul-de-sac, et la France se retrouvait coupée de la Belgique.
//
// `id` reprend le numéro de ligne de l'infrastructure (L50A, L162…) : c'est la
// façon la plus courte de retrouver la source si un tracé est contesté.
// ------------------------------------------------------------------

// Pays dont la topologie vient des LIGNES. Ajouter un pays ici en même temps
// que ses lignes, jamais avant : sans elles, ses gares n'auraient plus aucune
// arête.
const LINE_COUNTRIES = ["🇧🇪 Belgique", "🇫🇷 France", "🇬🇧 Royaume-Uni", "🇩🇪 Allemagne",
  "🇱🇺 Luxembourg"];

const LINES = [
  // ---- Flandre occidentale et orientale --------------------------------
  { id: "L50A", name: "Bruges – Gand",            nodes: ["bruges", "aalter", "gand"] },
  { id: "L50",  name: "Gand – Alost – Denderleeuw – Bruxelles",
    nodes: ["gand", "alost", "denderleeuw", "bruxelles-midi"] },
  { id: "L66",  name: "Bruges – Roulers – Courtrai", nodes: ["bruges", "roulers", "courtrai"] },
  { id: "L75",  name: "Gand – Deinze – Courtrai – Mouscron",
    nodes: ["gand", "deinze", "waregem", "courtrai", "mouscron"] },
  { id: "L75A", name: "Mouscron – Tournai",       nodes: ["mouscron", "herseaux", "tournai"] },
  { id: "L75F", name: "Mouscron – Lille (frontière française)", nodes: ["mouscron", "lille"] },
  { id: "L89",  name: "Courtrai – Audenarde – Zottegem – Denderleeuw",
    nodes: ["courtrai", "anzegem", "audenarde", "zottegem", "denderleeuw"] },
  { id: "L86",  name: "Audenarde – De Pinte – Gand", nodes: ["audenarde", "depinte", "gand"] },

  // ---- Pays de Waes, Dendre et Escaut -----------------------------------
  { id: "L59",  name: "Gand – Lokeren – Saint-Nicolas – Anvers",
    nodes: ["gand", "lokeren", "niklaas", "anvers"] },
  { id: "L53",  name: "Gand – Termonde – Malines – Louvain",
    nodes: ["gand", "schellebelle", "termonde", "malines", "haacht", "louvain"] },
  { id: "L57",  name: "Lokeren – Termonde – Alost – Denderleeuw",
    nodes: ["lokeren", "termonde", "alost", "denderleeuw"] },
  { id: "L60",  name: "Termonde – Opwijk – Bruxelles", nodes: ["termonde", "opwijk", "bruxelles-midi"] },
  { id: "L52",  name: "Termonde – Puurs – Anvers",  nodes: ["termonde", "puurs", "anvers"] },

  // ---- Anvers et la Campine --------------------------------------------
  { id: "L25",  name: "Bruxelles – Malines – Anvers",
    nodes: ["bruxelles-midi", "vilvorde", "malines", "anvers"] },
  { id: "L15",  name: "Anvers – Lierre – Herentals", nodes: ["anvers", "lier", "herentals"] },
  { id: "L13",  name: "Malines – Kontich – Lierre",  nodes: ["malines", "kontich", "lier"] },
  { id: "L16",  name: "Lierre – Aarschot",           nodes: ["lier", "aarschot"] },

  // ---- Axe Bruxelles – Liège et le Limbourg ----------------------------
  { id: "L36",  name: "Bruxelles – Louvain – Landen – Liège",
    nodes: ["bruxelles-midi", "louvain", "tirlemont", "landen", "waremme", "liege"] },
  { id: "L35",  name: "Louvain – Aarschot – Hasselt", nodes: ["louvain", "aarschot", "hasselt"] },
  { id: "L21",  name: "Landen – Hasselt",            nodes: ["landen", "hasselt"] },
  { id: "L34",  name: "Hasselt – Tongres – Liège",   nodes: ["hasselt", "tongres", "liege"] },
  { id: "L43",  name: "Liège – Rivage – Marloie",    nodes: ["liege", "rivage", "marloie"] },

  // ---- Brabant wallon et sillon Sambre-et-Meuse ------------------------
  { id: "L161", name: "Bruxelles – Ottignies – Namur",
    nodes: ["bruxelles-midi", "ottignies", "namur"] },
  { id: "L139", name: "Louvain – Ottignies",         nodes: ["louvain", "ottignies"] },
  { id: "L140", name: "Ottignies – Fleurus – Charleroi", nodes: ["ottignies", "fleurus", "charleroi"] },
  { id: "L124", name: "Bruxelles – Nivelles – Charleroi",
    nodes: ["bruxelles-midi", "nivelles", "charleroi"] },
  { id: "L130", name: "Charleroi – Namur",           nodes: ["charleroi", "namur"] },
  { id: "L125", name: "Namur – Huy – Liège",         nodes: ["namur", "huy", "liege"] },
  { id: "L154", name: "Namur – Dinant",              nodes: ["namur", "dinant"] },

  // ---- Ardenne et Luxembourg -------------------------------------------
  // L'exemple qui a motivé ce fichier : la relation Bruxelles – Luxembourg
  // n'est PAS une arête, c'est un parcours le long de cette ligne.
  { id: "L162", name: "Namur – Ciney – Marloie – Libramont – Arlon",
    nodes: ["namur", "ciney", "marloie", "libramont", "arlon"] },
  { id: "L166", name: "Dinant – Bertrix – Libramont", nodes: ["dinant", "bertrix", "libramont"] },

  // ---- Hainaut ----------------------------------------------------------
  { id: "L96",  name: "Bruxelles – Braine-le-Comte – Mons",
    nodes: ["bruxelles-midi", "hal", "braine", "soignies", "mons"] },
  { id: "L116", name: "Bruxelles – Braine-le-Comte – Manage – La Louvière",
    nodes: ["bruxelles-midi", "hal", "braine", "manage", "lalouviere"] },
  { id: "L112", name: "La Louvière – Charleroi",     nodes: ["lalouviere", "charleroi"] },
  { id: "L118", name: "La Louvière – Mons",          nodes: ["lalouviere", "mons"] },
  { id: "L78",  name: "Mons – Saint-Ghislain – Tournai", nodes: ["mons", "ghislain", "tournai"] },
  { id: "L90",  name: "Denderleeuw – Grammont – Ath – Jurbise – Mons",
    nodes: ["denderleeuw", "grammont", "ath", "jurbise", "mons"] },
  { id: "L94",  name: "Bruxelles – Ath – Tournai",
    nodes: ["bruxelles-midi", "hal", "enghien", "ath", "leuze", "tournai"] },
  { id: "L94F", name: "Tournai – Lille (frontière française)", nodes: ["tournai", "lille"] },
  // ==================== FRANCE ====================
  // Une étoile, pas un maillage : presque tout part d'une des trois têtes de
  // ligne parisiennes. Les lignes venues de l'Est, de Normandie et du Centre
  // aboutissent aux gares que le jeu n'ouvre pas (Paris-Est, Saint-Lazare,
  // Austerlitz, Bercy) : on les fait passer PAR ces points, puis rejoindre la
  // tête de ligne jouable la plus proche — 2 km plus loin, invisible à l'échelle.

  // ---- Nord et Picardie -------------------------------------------------
  { id: "LGV-N", name: "Paris-Nord – Arras – Lille", nodes: ["paris-nord", "arras", "lille"] },
  { id: "L272", name: "Paris-Nord – Creil – Amiens", nodes: ["paris-nord", "creil", "amiens"] },
  { id: "L281", name: "Amiens – Arras – Lille",      nodes: ["amiens", "arras", "lille"] },
  { id: "L310", name: "Amiens – Rouen",              nodes: ["amiens", "rouen"] },

  // ---- Normandie ---------------------------------------------------------
  { id: "L340", name: "Paris-Saint-Lazare – Mantes – Rouen",
    nodes: ["rouen", "mantes", "parisstlazare", "paris-nord"] },
  { id: "L365", name: "Rouen – Serquigny – Caen",    nodes: ["rouen", "serquigny", "caen"] },
  { id: "L390", name: "Caen – Dol – Rennes",         nodes: ["caen", "dol", "rennes"] },
  { id: "L395", name: "Caen – Alençon – Le Mans",    nodes: ["caen", "alencon", "le-mans"] },

  // ---- Ouest et Bretagne -------------------------------------------------
  { id: "LGV-A", name: "Paris-Montparnasse – Chartres – Le Mans",
    nodes: ["paris-montparnasse", "chartres", "le-mans"] },
  { id: "LGV-BPL", name: "Le Mans – Laval – Rennes", nodes: ["le-mans", "laval", "rennes"] },
  { id: "L410", name: "Le Mans – Sablé – Angers",    nodes: ["le-mans", "sable", "angers"] },
  { id: "L415", name: "Angers – Ancenis – Nantes",   nodes: ["angers", "ancenis", "nantes"] },
  { id: "L470", name: "Rennes – Redon – Nantes",     nodes: ["rennes", "redon", "nantes"] },
  { id: "L500", name: "Le Mans – Tours",             nodes: ["le-mans", "tours"] },

  // ---- Val de Loire, Berry et Limousin -----------------------------------
  { id: "L570", name: "Paris-Montparnasse – Vendôme – Tours",
    nodes: ["paris-montparnasse", "vendome", "tours"] },
  { id: "L590", name: "Tours – Châtellerault – Poitiers", nodes: ["tours", "chatellerault", "poitiers"] },
  { id: "L595", name: "Poitiers – Angoulême – Bordeaux", nodes: ["poitiers", "angouleme", "bordeaux"] },
  { id: "L600", name: "Nantes – La Rochelle – Saintes – Bordeaux",
    nodes: ["nantes", "lalochesuryon", "larochelle", "saintes", "bordeaux"] },
  { id: "L610", name: "Tours – Vierzon",             nodes: ["tours", "vierzon"] },
  { id: "L615", name: "Vierzon – Les Aubrais – Orléans", nodes: ["vierzon", "aubrais", "orleans"] },
  { id: "L620", name: "Orléans – Étampes – Paris-Austerlitz",
    nodes: ["orleans", "aubrais", "etampes", "parisausterlitz", "paris-lyon"] },
  { id: "L630", name: "Vierzon – Châteauroux – Limoges", nodes: ["vierzon", "chateauroux", "limoges"] },
  { id: "L640", name: "Limoges – Brive – Cahors – Toulouse",
    nodes: ["limoges", "brive", "cahors", "toulouse"] },
  { id: "L650", name: "Poitiers – Limoges",          nodes: ["limoges", "poitiers"] },

  // ---- Sud-Ouest et Languedoc -------------------------------------------
  { id: "L660", name: "Bordeaux – Agen – Montauban – Toulouse",
    nodes: ["bordeaux", "agen", "montauban", "toulouse"] },
  { id: "L670", name: "Toulouse – Carcassonne – Narbonne", nodes: ["toulouse", "carcassonne", "narbonne"] },
  { id: "L680", name: "Narbonne – Béziers – Sète – Montpellier",
    nodes: ["narbonne", "beziers", "sete", "montpellier"] },
  { id: "L690", name: "Montpellier – Nîmes",         nodes: ["montpellier", "nimes"] },
  { id: "L700", name: "Nîmes – Tarascon – Avignon",  nodes: ["nimes", "tarascon", "avignon"] },
  { id: "L800", name: "Nîmes – Alès – Clermont-Ferrand (ligne des Cévennes)",
    nodes: ["nimes", "ales", "langogne", "clermont-ferrand"] },

  // ---- Vallée du Rhône, Alpes et Côte d'Azur -----------------------------
  { id: "L810", name: "Avignon – Miramas – Marseille", nodes: ["avignon", "miramas", "marseille"] },
  { id: "L820", name: "Avignon – Montélimar – Valence", nodes: ["avignon", "montelimar", "valence"] },
  { id: "L830", name: "Valence – Vienne – Lyon",     nodes: ["valence", "vienne", "lyon"] },
  { id: "L840", name: "Valence – Moirans – Grenoble", nodes: ["valence", "moirans", "grenoble"] },
  { id: "L850", name: "Grenoble – Montmélian – Chambéry", nodes: ["grenoble", "montmelian", "chambery"] },
  { id: "L860", name: "Lyon – Ambérieu – Chambéry",  nodes: ["lyon", "amberieu", "chambery"] },
  { id: "L870", name: "Marseille – Toulon",          nodes: ["marseille", "toulon"] },
  { id: "L880", name: "Toulon – Saint-Raphaël – Cannes – Nice",
    nodes: ["toulon", "saintraphael", "cannes", "nice"] },

  // ---- Bourgogne, Franche-Comté et Alsace --------------------------------
  { id: "LGV-SE", name: "Paris-Lyon – Le Creusot – Lyon", nodes: ["paris-lyon", "lecreusot", "lyon"] },
  { id: "L750", name: "Paris-Lyon – Sens – Dijon",   nodes: ["paris-lyon", "sens", "dijon"] },
  { id: "L760", name: "Dijon – Mâcon – Lyon",        nodes: ["dijon", "macon", "lyon"] },
  { id: "L770", name: "Dijon – Dole – Besançon – Belfort – Mulhouse",
    nodes: ["dijon", "dole", "besancon", "belfort", "mulhouse"] },
  { id: "L780", name: "Dijon – Culmont-Chalindrey – Nancy", nodes: ["dijon", "culmont", "nancy"] },
  { id: "L115", name: "Mulhouse – Colmar – Strasbourg", nodes: ["mulhouse", "colmar", "strasbourg"] },

  // ---- Lorraine, Champagne et Massif central -----------------------------
  { id: "L155", name: "Strasbourg – Sarrebourg – Metz", nodes: ["strasbourg", "sarrebourg", "metz"] },
  { id: "L160", name: "Strasbourg – Sarrebourg – Nancy", nodes: ["strasbourg", "sarrebourg", "nancy"] },
  { id: "L170", name: "Nancy – Pont-à-Mousson – Metz", nodes: ["nancy", "pontamousson", "metz"] },
  { id: "LGV-E", name: "Paris-Est – Châlons – Bar-le-Duc – Nancy",
    nodes: ["nancy", "barleduc", "chalons", "parisest", "paris-nord"] },
  { id: "LGV-E2", name: "Paris-Est – Château-Thierry – Reims",
    nodes: ["reims", "chateauthierry", "parisest", "paris-nord"] },
  { id: "L690B", name: "Paris-Bercy – Nevers – Vichy – Clermont-Ferrand",
    nodes: ["clermont-ferrand", "vichy", "nevers", "montargis", "parisbercy", "paris-lyon"] },
  { id: "L790", name: "Clermont-Ferrand – Roanne – Lyon", nodes: ["clermont-ferrand", "roanne", "lyon"] },

  // ---- Les deux lignes qui recousent le continent ------------------------
  // Elles ne sont pas là pour le décor : dès que la France a eu ses lignes, ses
  // portails ont cessé de compter pour la carte, et le Royaume-Uni comme
  // l'Allemagne se sont retrouvés SANS AUCUNE arête vers le reste — donc
  // injouables (mesuré : York tombait de 88 gares atteignables à 11, Freiburg
  // n'était même plus une porte d'entrée valable). L'Eurostar et la vallée du
  // Rhin sont pourtant deux itinéraires on ne peut plus réels.
  { id: "Eurostar", name: "Paris-Nord – Lille – Calais – Londres St Pancras (tunnel sous la Manche)",
    nodes: ["paris-nord", "arras", "lille", "calais", "stpancras", "kings-cross"] },
  { id: "L4000", name: "Strasbourg – Offenburg – Fribourg (Rheintalbahn)",
    nodes: ["strasbourg", "offenburg", "freiburg"] },
  { id: "L4010", name: "Mulhouse – Bâle – Fribourg", nodes: ["mulhouse", "bale", "freiburg"] },
  // ==================== ROYAUME-UNI ====================
  // Quatre compagnies rivales, quatre lignes principales, quatre terminus
  // londoniens qui ne communiquent pas : c'est la topologie que le pays a
  // gardée. Rien ne traverse Londres — tout y bute.

  // ---- West Coast Main Line et le Nord-Ouest -----------------------------
  { id: "WCML", name: "Euston – Rugby – Birmingham",
    nodes: ["euston", "rugby", "nuneaton", "birmingham"] },
  { id: "WCML-B", name: "Birmingham – Wolverhampton – Crewe",
    nodes: ["birmingham", "wolverhampton", "crewe"] },
  { id: "WCML-C", name: "Euston – Rugby – Crewe", nodes: ["euston", "rugby", "crewe"] },
  { id: "WCML-D", name: "Crewe – Warrington – Wigan – Preston",
    nodes: ["crewe", "warrington", "wigan", "preston"] },
  { id: "WCML-E", name: "Preston – Lancaster – Oxenholme – Carlisle",
    nodes: ["preston", "lancaster", "oxenholme", "carlisle"] },
  { id: "WCML-F", name: "Carlisle – Motherwell – Glasgow",
    nodes: ["carlisle", "motherwell", "glasgow"] },
  { id: "CRE-M", name: "Crewe – Manchester",   nodes: ["crewe", "manchester"] },
  { id: "CRE-L", name: "Crewe – Liverpool",    nodes: ["crewe", "liverpool"] },
  { id: "CRE-C", name: "Crewe – Chester",      nodes: ["crewe", "chester"] },
  { id: "WIRRAL", name: "Chester – Liverpool", nodes: ["chester", "liverpool"] },
  { id: "MARCHES", name: "Chester – Shrewsbury – Newport – Cardiff",
    nodes: ["chester", "shrewsbury", "newport", "cardiff"] },
  { id: "CHATMOSS", name: "Liverpool – Manchester (la ligne de 1830)",
    nodes: ["liverpool", "manchester"] },
  { id: "BOLTON", name: "Manchester – Preston", nodes: ["manchester", "preston"] },
  { id: "PRE-L", name: "Preston – Wigan – Liverpool", nodes: ["preston", "wigan", "liverpool"] },

  // ---- East Coast Main Line et le Nord-Est -------------------------------
  { id: "ECML", name: "King's Cross – Peterborough – Doncaster – York",
    nodes: ["kings-cross", "peterborough", "grantham", "doncaster", "york"] },
  { id: "ECML-B", name: "York – Darlington – Durham – Newcastle",
    nodes: ["york", "darlington", "durham", "newcastle"] },
  { id: "ECML-C", name: "Newcastle – Berwick – Edinburgh",
    nodes: ["newcastle", "berwick", "edinburgh"] },
  { id: "KX-SP", name: "King's Cross – St Pancras (deux cents mètres)",
    nodes: ["kings-cross", "stpancras"] },
  { id: "WAKE", name: "Doncaster – Wakefield – Leeds", nodes: ["doncaster", "wakefield", "leeds"] },
  { id: "DON-S", name: "Doncaster – Sheffield",  nodes: ["doncaster", "sheffield"] },
  { id: "DON-Y", name: "Doncaster – York",       nodes: ["doncaster", "york"] },
  { id: "TPE", name: "Leeds – York",             nodes: ["leeds", "york"] },
  { id: "TPE-B", name: "Manchester – Leeds",     nodes: ["manchester", "leeds"] },
  { id: "SETTLE", name: "Leeds – Settle – Carlisle", nodes: ["leeds", "carlisle"] },
  { id: "LDS-S", name: "Leeds – Wakefield – Sheffield", nodes: ["leeds", "wakefield", "sheffield"] },
  { id: "TYNE", name: "Carlisle – Newcastle (vallée de la Tyne)", nodes: ["carlisle", "newcastle"] },
  { id: "CARST", name: "Carlisle – Carstairs – Edinburgh", nodes: ["carlisle", "carstairs", "edinburgh"] },

  // ---- Great Western et le Sud-Ouest -------------------------------------
  { id: "GWML", name: "Paddington – Reading",    nodes: ["paddington", "reading"] },
  { id: "GWML-B", name: "Reading – Swindon – Bath – Bristol",
    nodes: ["reading", "swindon", "bath", "bristol"] },
  { id: "SWALES", name: "Bristol – Newport – Cardiff", nodes: ["bristol", "newport", "cardiff"] },
  { id: "XC", name: "Bristol – Cheltenham – Birmingham", nodes: ["bristol", "cheltenham", "birmingham"] },
  { id: "BEX", name: "Bristol – Taunton – Exeter", nodes: ["bristol", "taunton", "exeter"] },
  { id: "CORN", name: "Exeter – Newton Abbot – Plymouth", nodes: ["exeter", "newtonabbot", "plymouth"] },
  { id: "BHANTS", name: "Reading – Newbury – Taunton", nodes: ["reading", "newbury", "taunton"] },
  { id: "CHERW", name: "Reading – Oxford",       nodes: ["reading", "oxford"] },
  { id: "CHERW-B", name: "Oxford – Banbury – Birmingham", nodes: ["oxford", "banbury", "birmingham"] },

  // ---- South Western et la Manche ----------------------------------------
  { id: "SWML", name: "Waterloo – Basingstoke – Southampton",
    nodes: ["waterloo", "basingstoke", "southampton"] },
  { id: "WAT-R", name: "Waterloo – Guildford – Reading", nodes: ["waterloo", "guildford", "reading"] },
  { id: "WOE", name: "Waterloo – Salisbury – Exeter", nodes: ["waterloo", "salisbury", "exeter"] },
  { id: "WESSEX", name: "Salisbury – Southampton", nodes: ["salisbury", "southampton"] },
  { id: "WESSEX-B", name: "Salisbury – Westbury – Bristol", nodes: ["salisbury", "westbury", "bristol"] },
  { id: "BML", name: "Brighton – Gatwick – Londres Victoria",
    nodes: ["brighton", "gatwick", "victoria", "waterloo"] },
  { id: "COASTWAY", name: "Brighton – Southampton (par la côte)", nodes: ["brighton", "southampton"] },

  // ---- Midlands et East Anglia -------------------------------------------
  { id: "MML", name: "St Pancras – Leicester – Loughborough – Derby",
    nodes: ["stpancras", "leicester", "loughborough", "derby"] },
  { id: "LEI-B", name: "Leicester – Nuneaton – Birmingham",
    nodes: ["leicester", "nuneaton", "birmingham"] },
  { id: "DER-N", name: "Derby – Nottingham",     nodes: ["derby", "nottingham"] },
  { id: "MML-B", name: "Derby – Chesterfield – Sheffield", nodes: ["derby", "chesterfield", "sheffield"] },
  { id: "NSTAFF", name: "Derby – Stoke – Crewe", nodes: ["derby", "stoke", "crewe"] },
  { id: "ROBIN", name: "Nottingham – Sheffield", nodes: ["nottingham", "sheffield"] },
  { id: "NOT-P", name: "Nottingham – Grantham – Peterborough",
    nodes: ["nottingham", "grantham", "peterborough"] },
  { id: "XC-B", name: "Birmingham – Derby",      nodes: ["birmingham", "derby"] },
  { id: "HOPE", name: "Sheffield – Manchester (Hope Valley)", nodes: ["sheffield", "manchester"] },
  { id: "GEML", name: "Norwich – Ipswich – Colchester – Liverpool Street",
    nodes: ["norwich", "ipswich", "colchester", "liverpoolst", "kings-cross"] },
  { id: "BRECK", name: "Norwich – Ely – Cambridge", nodes: ["norwich", "ely", "cambridge"] },
  { id: "NOR-P", name: "Norwich – Ely – Peterborough", nodes: ["norwich", "ely", "peterborough"] },
  { id: "CAMB", name: "Cambridge – King's Cross", nodes: ["cambridge", "kings-cross"] },
  { id: "FEN", name: "Cambridge – Ely – Peterborough", nodes: ["cambridge", "ely", "peterborough"] },

  // ---- Écosse -------------------------------------------------------------
  { id: "E&G", name: "Glasgow – Edinburgh",      nodes: ["glasgow", "edinburgh"] },
  { id: "CUMB", name: "Glasgow – Falkirk – Stirling", nodes: ["glasgow", "falkirk", "stirling"] },
  { id: "FIFE", name: "Edinburgh – Stirling",    nodes: ["edinburgh", "stirling"] },
  { id: "HIGH", name: "Stirling – Perth",        nodes: ["stirling", "perth"] },
  { id: "DUND", name: "Perth – Dundee – Aberdeen", nodes: ["perth", "dundee", "aberdeen"] },
  { id: "FIFE-B", name: "Edinburgh – Dundee – Aberdeen", nodes: ["edinburgh", "dundee", "aberdeen"] },
  // ==================== ALLEMAGNE ====================
  // Un maillage, pas une étoile : aucune gare n'est le centre, et l'on traverse
  // le pays d'un bout à l'autre sans repasser deux fois par le même nœud.
  // Les trois dernières lignes referment la carte d'Europe — sans elles,
  // l'Allemagne reste un continent à part (mesuré : 12 gares inatteignables).

  // ---- Rhin et Ruhr -------------------------------------------------------
  { id: "LinkeRhein", name: "Cologne – Bonn – Coblence – Mayence – Mannheim",
    nodes: ["koln", "bonn", "koblenz", "mainz", "mannheim"] },
  { id: "MZ-F", name: "Mayence – Francfort",     nodes: ["mainz", "frankfurt"] },
  { id: "RUHR", name: "Cologne – Düsseldorf – Duisbourg – Essen – Dortmund",
    nodes: ["koln", "dusseldorf", "duisburg", "essen", "dortmund"] },
  { id: "DU-MS", name: "Duisbourg – Oberhausen – Münster", nodes: ["duisburg", "oberhausen", "munster"] },
  { id: "K-DO", name: "Cologne – Wuppertal – Dortmund", nodes: ["koln", "wuppertal", "dortmund"] },
  { id: "K-Minden", name: "Dortmund – Hamm – Bielefeld – Minden – Hanovre",
    nodes: ["dortmund", "hamm", "bielefeld", "minden", "hannover"] },
  { id: "DO-MS", name: "Dortmund – Münster",     nodes: ["dortmund", "munster"] },
  { id: "Rollbahn", name: "Münster – Osnabrück – Brême", nodes: ["munster", "osnabruck", "bremen"] },
  { id: "HB-HH", name: "Brême – Hambourg",       nodes: ["bremen", "hamburg"] },
  { id: "SFS-KRM", name: "Cologne – Limburg – Francfort (LGV)", nodes: ["koln", "limburg", "frankfurt"] },
  { id: "Emscher", name: "Essen – Gelsenkirchen – Dortmund", nodes: ["essen", "gelsenkirchen", "dortmund"] },
  { id: "DO-KS", name: "Dortmund – Warburg – Cassel", nodes: ["dortmund", "warburg", "kassel"] },

  // ---- Le Sud-Ouest -------------------------------------------------------
  { id: "Riedbahn", name: "Francfort – Mannheim", nodes: ["frankfurt", "mannheim"] },
  { id: "Rheintal", name: "Mannheim – Karlsruhe – Offenburg – Fribourg – Bâle",
    nodes: ["mannheim", "karlsruhe", "offenburg", "freiburg", "bale"] },
  { id: "SFS-MS", name: "Mannheim – Stuttgart",  nodes: ["mannheim", "stuttgart"] },
  { id: "Pfalz", name: "Mannheim – Kaiserslautern – Sarrebruck",
    nodes: ["mannheim", "kaiserslautern", "saarbrucken"] },
  { id: "MA-HD", name: "Mannheim – Heidelberg",  nodes: ["mannheim", "heidelberg"] },
  { id: "Filstal", name: "Stuttgart – Ulm – Augsbourg – Munich",
    nodes: ["stuttgart", "ulm", "augsburg", "munchen"] },
  { id: "S-N", name: "Stuttgart – Crailsheim – Nuremberg", nodes: ["stuttgart", "crailsheim", "nurnberg"] },

  // ---- Bavière ------------------------------------------------------------
  { id: "SFS-WU", name: "Francfort – Wurtzbourg – Nuremberg", nodes: ["frankfurt", "wurzburg", "nurnberg"] },
  { id: "SFS-IN", name: "Nuremberg – Ingolstadt – Munich", nodes: ["nurnberg", "ingolstadt", "munchen"] },
  { id: "N-R", name: "Nuremberg – Ratisbonne",   nodes: ["nurnberg", "regensburg"] },
  { id: "R-M", name: "Ratisbonne – Landshut – Munich", nodes: ["regensburg", "landshut", "munchen"] },
  { id: "A-N", name: "Augsbourg – Donauwörth – Treuchtlingen – Nuremberg",
    nodes: ["augsburg", "donauworth", "treuchtlingen", "nurnberg"] },

  // ---- Le centre et le nord ----------------------------------------------
  { id: "SFS-GO", name: "Francfort – Fulda – Cassel – Göttingen – Hanovre",
    nodes: ["frankfurt", "fulda", "kassel", "gottingen", "hannover"] },
  { id: "H-HH", name: "Hanovre – Hambourg",      nodes: ["hannover", "hamburg"] },
  { id: "H-HB", name: "Hanovre – Brême",         nodes: ["hannover", "bremen"] },
  { id: "SFS-B", name: "Hanovre – Wolfsburg – Berlin", nodes: ["hannover", "wolfsburg", "berlin"] },
  { id: "H-MD", name: "Hanovre – Brunswick – Magdebourg", nodes: ["hannover", "braunschweig", "magdeburg"] },
  { id: "HH-KI", name: "Hambourg – Kiel",        nodes: ["hamburg", "kiel"] },
  { id: "HH-HL", name: "Hambourg – Lübeck",      nodes: ["hamburg", "lubeck"] },
  { id: "KI-HL", name: "Kiel – Lübeck",          nodes: ["lubeck", "kiel"] },
  { id: "Ostsee", name: "Lübeck – Wismar – Rostock", nodes: ["lubeck", "wismar", "rostock"] },
  { id: "HH-HR", name: "Hambourg – Schwerin – Rostock", nodes: ["hamburg", "schwerin", "rostock"] },
  { id: "HR-B", name: "Rostock – Neustrelitz – Berlin", nodes: ["rostock", "neustrelitz", "berlin"] },

  // ---- L'Est ---------------------------------------------------------------
  { id: "B-MD", name: "Berlin – Magdebourg",     nodes: ["berlin", "magdeburg"] },
  { id: "MD-HA", name: "Magdebourg – Halle",     nodes: ["magdeburg", "halle"] },
  { id: "B-HA", name: "Berlin – Bitterfeld – Halle", nodes: ["berlin", "bitterfeld", "halle"] },
  { id: "HA-L", name: "Halle – Leipzig",         nodes: ["halle", "leipzig"] },
  { id: "L-DD", name: "Leipzig – Riesa – Dresde", nodes: ["leipzig", "riesa", "dresden"] },
  { id: "B-DD", name: "Berlin – Elsterwerda – Dresde", nodes: ["berlin", "elsterwerda", "dresden"] },
  // La LGV Erfurt – Leipzig ne dessert PAS Weimar : elle quitte Erfurt plein
  // nord-est, franchit la Finne en tunnel et l'Unstrut en viaduc, puis rejoint
  // Leipzig à la bifurcation de Gröbers. La faire passer par Weimar la collait
  // au tracé de la Saalebahn — deux lignes en un seul trait dédoublé.
  { id: "SFS-EF", name: "Leipzig – Gröbers – Unstrut – Erfurt (LGV)",
    nodes: ["leipzig", "grobers", "unstruttal", "erfurt"] },
  // La Saalebahn plonge au sud-est par Iéna avant de remonter la vallée de la
  // Saale : sans ce point, la corde Erfurt – Naumburg venait coller au tracé de
  // la SFS par Weimar (4 px d'écart à Naumburg) et les deux lignes se lisaient
  // comme un seul trait dédoublé.
  { id: "Saalebahn", name: "Halle – Naumburg – Iéna – Erfurt",
    nodes: ["halle", "naumburg", "jena", "erfurt"] },
  { id: "SFS-EB", name: "Erfurt – Cobourg – Nuremberg (LGV)", nodes: ["erfurt", "coburg", "nurnberg"] },
  { id: "Mitte", name: "Erfurt – Eisenach – Fulda", nodes: ["erfurt", "eisenach", "fulda"] },

  // ---- Les liaisons qui referment l'Europe --------------------------------
  // Sans elles, l'Allemagne n'a AUCUNE arête vers le reste du réseau : douze
  // gares que personne ne peut atteindre. Elles sont écrites dans le même
  // commit que les fiches, jamais après (la leçon de l'Eurostar).
  { id: "L37", name: "Liège – Aachen – Cologne (le Thalys)", nodes: ["liege", "aachen", "koln"] },
  { id: "LGV-E3", name: "Sarrebruck – Forbach – Metz (l'ICE de Paris)",
    nodes: ["saarbrucken", "forbach", "metz"] },

  // ---- Trèves : les trois lignes qui la sortent du cul-de-sac -------------
  // Coblence et Sarrebruck portaient déjà un portail TRIER, sans destinataire.
  // L'Eifel (Cologne – Trèves) a rouvert fin mars 2026 après les crues de 2021 :
  // sans elle, Trèves n'aurait que deux arêtes allemandes.
  { id: "Mosel", name: "Coblence – Cochem – Bullay – Wittlich – Trèves",
    nodes: ["koblenz", "cochem", "bullay", "wittlich", "trier"] },
  { id: "Eifel", name: "Cologne – Euskirchen – Gerolstein – Trèves",
    nodes: ["koln", "euskirchen", "gerolstein", "trier"] },
  { id: "Saar", name: "Trèves – Merzig – Sarrebruck", nodes: ["trier", "merzig", "saarbrucken"] },

  // ==================== LUXEMBOURG ====================
  // Une étoile, pas un maillage : six branches partent de la capitale et rien
  // ne se referme, sauf au sud où le bassin minier forme la seule boucle du
  // pays (Luxembourg – Bettembourg – Esch – Pétange – Luxembourg). Trois des
  // branches sortent du pays, vers trois voisins déjà jouables — c'est ce qui
  // fait du Grand-Duché la charnière de l'Europe de l'Ouest.
  { id: "CFL10", name: "Luxembourg – Mersch – Ettelbruck – Kautenbach – Troisvierges",
    nodes: ["luxembourg", "mersch", "ettelbruck", "kautenbach", "clervaux", "troisvierges"] },
  { id: "L42", name: "Troisvierges – Gouvy – Vielsalm – Rivage – Liège (la ligne des Ardennes)",
    nodes: ["troisvierges", "gouvy", "vielsalm", "rivage", "liege"] },
  { id: "CFL6", name: "Luxembourg – Kleinbettingen – Arlon",
    nodes: ["luxembourg", "kleinbettingen", "arlon"] },
  { id: "CFL1", name: "Luxembourg – Wasserbillig – Trèves",
    nodes: ["luxembourg", "wasserbillig", "trier"] },
  { id: "CFL3", name: "Luxembourg – Bettembourg – Thionville – Metz",
    nodes: ["luxembourg", "bettembourg", "thionville", "metz"] },
  { id: "CFL60", name: "Bettembourg – Noertzange – Esch-sur-Alzette – Belval – Pétange",
    nodes: ["bettembourg", "noertzange", "esch-sur-alzette", "belval", "differdange", "petange"] },
  { id: "CFL70", name: "Luxembourg – Dippach – Bascharage – Pétange – Rodange",
    nodes: ["luxembourg", "dippach", "bascharage", "petange", "rodange"] }
];
