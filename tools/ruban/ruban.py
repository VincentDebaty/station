# -*- coding: utf-8 -*-
# Le ruban d'Europe — données source. Génère ruban-europe.md et vérifie R3/R6.
# g("Nom") : gare à écrire. g("Nom","id") : fiche déjà au catalogue (vérifié).
def g(nom, fid=None): return (nom, fid)

ACTES = []
def acte(id, nom, sous): 
    a={"id":id,"nom":nom,"sous":sous,"ch":[]}; ACTES.append(a); return a
def ch(a, nom, de, vers, gares, saut=None):
    a["ch"].append({"nom":nom,"de":de,"vers":vers,"gares":gares,"saut":saut})

# =====================================================================
A = acte("bri","Acte I — Les Îles","De Cork au tunnel sous la Manche")
ch(A,"La ligne du Sud","Cork","Dublin",[
  g("Mallow"),g("Limerick Junction"),g("Thurles"),g("Portlaoise"),g("Kildare"),g("Dublin Heuston")])
ch(A,"L'Enterprise","Dublin","Belfast",[
  g("Drogheda"),g("Dundalk"),g("Newry"),g("Portadown"),g("Lisburn"),g("Belfast Lanyon Place")])
ch(A,"Les Lowlands","Belfast","Glasgow",[
  g("Stranraer"),g("Girvan"),g("Ayr"),g("Troon"),g("Kilmarnock"),g("Paisley"),g("Glasgow Central","glasgow")],
  saut=("mer","Le North Channel — le ferry de Belfast à Cairnryan"))
ch(A,"La Highland Main Line","Glasgow","Inverness",[
  g("Stirling","stirling"),g("Perth","perth"),g("Pitlochry"),g("Blair Atholl"),g("Kingussie"),g("Aviemore"),g("Inverness")])
ch(A,"Le Moray Firth","Inverness","Aberdeen",[
  g("Nairn"),g("Forres"),g("Elgin"),g("Keith"),g("Huntly"),g("Inverurie"),g("Dyce"),g("Aberdeen","aberdeen")])
ch(A,"La côte des Grampians","Aberdeen","Édimbourg",[
  g("Stonehaven"),g("Montrose"),g("Arbroath"),g("Dundee"),g("Leuchars"),g("Kirkcaldy"),g("Inverkeithing"),g("Edinburgh Waverley","edinburgh")])
ch(A,"La côte de Northumbrie","Édimbourg","Newcastle",[
  g("Dunbar"),g("Berwick-upon-Tweed"),g("Alnmouth"),g("Morpeth"),g("Newcastle","newcastle")])
ch(A,"La côte Est","Newcastle","Leeds",[
  g("Durham"),g("Darlington"),g("Northallerton"),g("York","york"),g("Leeds","leeds")])
ch(A,"Le Yorkshire noir","Leeds","Sheffield",[
  g("Wakefield"),g("Pontefract"),g("Doncaster","doncaster"),g("Rotherham"),g("Sheffield","sheffield")])
ch(A,"La vallée de Hope","Sheffield","Manchester",[
  g("Dore"),g("Hathersage"),g("Edale"),g("Chinley"),g("New Mills"),g("Stockport"),g("Manchester Piccadilly","manchester")])
ch(A,"La première ligne du monde","Manchester","Liverpool",[
  g("Salford"),g("Eccles"),g("Newton-le-Willows"),g("St Helens"),g("Huyton"),g("Liverpool Lime Street","liverpool")])
ch(A,"Le West Coast","Liverpool","Birmingham",[
  g("Runcorn"),g("Crewe","crewe"),g("Stafford"),g("Wolverhampton"),g("Birmingham New Street","birmingham")])
ch(A,"Les Marches galloises","Birmingham","Cardiff",[
  g("Bromsgrove"),g("Worcester"),g("Hereford"),g("Abergavenny"),g("Pontypool"),g("Cardiff Central","cardiff")])
ch(A,"Le tunnel de la Severn","Cardiff","Bristol",[
  g("Newport"),g("Caldicot"),g("Severn Tunnel Junction"),g("Pilning"),g("Filton Abbey Wood"),g("Bristol Temple Meads","bristol")])
ch(A,"La Riviera anglaise","Bristol","Penzance",[
  g("Taunton"),g("Exeter St Davids","exeter"),g("Newton Abbot"),g("Totnes"),g("Plymouth","plymouth"),g("Truro"),g("Penzance")])
ch(A,"Le Wessex","Penzance","Southampton",[
  g("Bath Spa"),g("Trowbridge"),g("Westbury"),g("Salisbury","salisbury"),g("Romsey"),g("Southampton Central","southampton")],
  saut=("nuit","Le Night Riviera — le train de nuit de Penzance remonte à Bristol"))
ch(A,"Le South Western","Southampton","Londres",[
  g("Winchester"),g("Basingstoke"),g("Woking"),g("Clapham Junction"),g("London Waterloo","waterloo")])
ch(A,"Le tunnel","Londres","Lille",[
  g("Stratford International"),g("Ebbsfleet"),g("Ashford"),g("Calais-Fréthun"),g("Hazebrouck"),g("Lille-Europe","lille")])

# =====================================================================
B = acte("nw","Acte II — La France atlantique","De la Manche aux Pyrénées")
ch(B,"L'Étoile du Nord","Lille","Paris",[
  g("Douai","douai"),g("Arras","arras"),g("Amiens","amiens"),g("Creil","creil"),g("Paris-Nord","paris-nord")])
ch(B,"La Normandie","Paris","Caen",[
  g("Mantes-la-Jolie"),g("Évreux"),g("Bernay"),g("Lisieux"),g("Caen")])
ch(B,"Le Cotentin et la baie","Caen","Rennes",[
  g("Bayeux"),g("Saint-Lô"),g("Avranches"),g("Pontorson"),g("Dol-de-Bretagne"),g("Rennes","rennes")])
ch(B,"La Bretagne intérieure","Rennes","Nantes",[
  g("Bruz"),g("Messac"),g("Redon"),g("Savenay"),g("Nantes","nantes")])
# REDÉCOUPAGE DU 28 AOÛT 2026 (décision de Vincent). Rochefort et Jonzac,
# refusées la veille (anciennes bifurcations, branches mortes en 1954 et par
# gares voisines closes), sont remplacées par NIORT : trois directions
# voyageurs, une ligne vers Saintes rénovée en 2025, et une quatrième branche
# rendue au fret (Thouars) — le chapitre passe par l'intérieur, comme la
# Campanie par Ciampino.
ch(B,"Le littoral atlantique","Nantes","Bordeaux",[
  g("La Roche-sur-Yon","lalochesuryon"),g("La Rochelle","larochelle"),g("Niort","niort"),
  g("Saintes","saintes"),g("Bordeaux Saint-Jean","bordeaux")])
# LE CANAL DEVIENT LE PÉRIGORD (décision de Vincent, 28 août 2026). Marmande
# avait été refusée la veille ; La Réole et Moissac sont tombées au même
# balayage — la « ligne » de Moissac vers Cahors n'a même jamais ouvert,
# chantier abandonné en 1934. Le corridor Bordeaux–Toulouse n'a AUCUNE gare
# intermédiaire à trois directions vivantes : toutes ses bifurcations sont
# mortes avant ou juste après la guerre. Le chapitre est donc RE-ROUTÉ par
# les seules bifurcations vivantes du secteur : Libourne (Bergerac), la
# gare-atelier de Périgueux, et la ligne de l'Agenais — quatre allers-retours
# par jour, fragile mais vivante, et le §0 juge aujourd'hui.
ch(B,"Le Périgord et la Garonne","Bordeaux","Toulouse",[
  g("Libourne","libourne"),g("Périgueux","perigueux"),g("Agen","agen"),
  g("Montauban","montauban"),g("Toulouse Matabiau","toulouse")])
ch(B,"Le piémont pyrénéen","Toulouse","Bilbao",[
  g("Saint-Gaudens"),g("Tarbes"),g("Pau"),g("Orthez"),g("Bayonne"),g("Hendaye"),g("Irún"),g("Bilbao Abando")])

# =====================================================================
C = acte("ib","Acte III — L'Ibérie","La grande boucle de la péninsule")
ch(C,"La Castille","Bilbao","Madrid",[
  g("Miranda de Ebro"),g("Burgos"),g("Palencia"),g("Valladolid"),g("Ávila"),g("Madrid-Chamartín")])
ch(C,"L'Estrémadure","Madrid","Lisbonne",[
  g("Talavera de la Reina"),g("Navalmoral"),g("Cáceres"),g("Mérida"),g("Badajoz"),g("Elvas"),g("Entroncamento"),g("Lisbonne Santa Apolónia")])
ch(C,"La côte d'Argent","Lisbonne","Porto",[
  g("Azambuja"),g("Santarém"),g("Pombal"),g("Coimbra"),g("Aveiro"),g("Espinho"),g("Porto Campanhã")])
ch(C,"La Galice","Porto","Madrid",[
  g("Nine"),g("Valença"),g("Vigo"),g("Ourense"),g("Zamora"),g("Medina del Campo"),g("Madrid-Atocha")])
ch(C,"L'Andalousie","Madrid","Séville",[
  g("Aranjuez"),g("Alcázar de San Juan"),g("Ciudad Real"),g("Puertollano"),g("Cordoue"),g("Séville Santa Justa")])
ch(C,"La Bétique","Séville","Malaga",[
  g("Utrera"),g("Marchena"),g("Osuna"),g("Bobadilla"),g("Antequera"),g("Malaga María Zambrano")])
# LA LIGNE DE TERUEL EST FONDUE DANS LE LEVANT (décision de Vincent, 28 août
# 2026, option B). Le chapitre 33 ne pouvait pas exister : la ligne 610
# Saragosse–Sagonte est une voie unique non électrifiée SANS UNE SEULE
# bifurcation voyageurs vivante — Segorbe, Caudiel, Calamocha et même TERUEL
# (2 quais, 13 voies de croisement fret) sont des passantes à deux bouts, et
# Caminreal, l'ancienne étoile du secteur, a perdu sa branche de Calatayud le
# 1er janvier 1985 (démantelée en 2011). Quatre refus §0 d'un coup, mesurés
# le 28 août 2026. Ne restaient que SAGONTE (la vraie bifurcation de la
# Central de Aragón : Valence, Castellón, Teruel) et SARAGOSSE-DELICIAS —
# deux gares, R3 en exige cinq. Le Levant s'étend donc jusqu'à Saragosse :
# le boss passe à Delicias, Valence-Nord se joue en cours de chapitre, et la
# ligne de Teruel devient le dernier tronçon du récit, pas un chapitre.
ch(C,"Le Levant et l'Aragon","Malaga","Saragosse",[
  g("Grenade"),g("Guadix"),g("Almería"),g("Lorca"),g("Murcie"),g("Alicante"),
  g("Valence-Nord"),g("Sagonte","sagunto"),g("Saragosse-Delicias","zaragoza")])
# VILANOVA I LA GELTRÚ REFUSÉE le 28 août 2026 (§0) : passante à deux bouts
# sur la côte, malgré son musée du rail dans la rotonde. SANT VICENÇ DE
# CALDERS la remplace : le Y du Penedès, deux itinéraires vers Barcelone qui
# s'y séparent et trois terminus de banlieue — la vraie bifurcation du
# tronçon. Tarragone tient par ses trois directions de trafic (la bifurcation
# de Vila-seca est à 5 km — standard Lausanne), Lérida par ses cinq sorties.
ch(C,"L'Èbre","Saragosse","Barcelone",[
  g("Lérida","lleida"),g("Reus","reus"),g("Tarragone","tarragona"),
  g("Sant Vicenç de Calders","santvicenc"),g("Barcelone-Sants","barcelona")])
# LE ROUSSILLON A FUSIONNÉ AVEC LA CAMARGUE le 28 août 2026 (décision de
# Vincent, option A) : sa moitié espagnole est morte au §0 — Gérone et
# Figueres sont des passantes depuis la fermeture des lignes d'Olot et de
# Sant Feliu en 1969, et Portbou, deux terminus dos à dos sur deux
# écartements que plus aucun train ne relie depuis la fin des Talgo (2013),
# n'offre AUCUNE paire à aiguiller. Le ruban franchit désormais la frontière
# par le SAUT DU PERTHUS, comme le vrai TGV. Le chapitre fusionné vit au
# début de l'acte IV.

# =====================================================================
D = acte("it","Acte IV — Le Midi et l'Italie","De la Camargue à la Sicile, et retour par le Pô")
# ARLES REFUSÉE le 28 août 2026 (§0) : l'ancienne étoile à cinq branches est
# réduite à un couloir — Port-Saint-Louis morte en voyageurs en 1932 et
# déclassée en 2019, Lunel et Salon fermées. AVIGNON-CENTRE la remplace
# (quatre sorties physiques, fiche de juillet déjà brevetée) : le chapitre
# monte par Tarascon, marque Avignon sous les remparts, et redescend sur
# Miramas par la ligne de Cavaillon, vivante à quatorze allers-retours par
# jour. Sinuosité mesurée sous 1,5 — pas d'exception à déclarer.
# FUSION ROUSSILLON + CAMARGUE (28 août 2026, option A) : neuf gares de
# Perpignan à Marseille, ouvertes par le saut du Perthus. Montpellier, grande
# gare, vit en milieu de chapitre — c'est le compromis assumé de l'option A,
# préféré à une exception au plancher de R3. Sinuosité mesurée sous 1,5.
ch(D,"Le Roussillon et la Camargue","Barcelone","Marseille",[
  g("Perpignan","perpignan"),g("Narbonne","narbonne"),g("Béziers","beziers"),
  g("Montpellier-Saint-Roch","montpellier"),g("Nîmes","nimes"),g("Tarascon","tarascon"),
  g("Avignon","avignon"),g("Miramas","miramas"),g("Marseille Saint-Charles","marseille")],
  saut=("lgv","Le tunnel du Perthus — de Barcelone à Perpignan par la grande vitesse"))
# SAINT-RAPHAËL, MONACO ET SAN REMO REFUSÉES le 28 août 2026 (§0) : trois
# gares de passage à deux directions — Saint-Raphaël a perdu son littoral
# varois en 1948 (le piège exact de l'ancienne bifurcation), Monaco et San
# Remo sont des cavernes souterraines sur le seul fil de la côte. Cannes
# tient par la ligne de Grasse (standard Lausanne, bifurcation à La Bocca),
# Vintimille par la vallée de la Roya, bien vivante. Le chapitre tient à six.
ch(D,"La Riviera","Marseille","Gênes",[
  g("Toulon","toulon"),g("Cannes","cannes"),g("Nice","nice"),
  g("Vintimille","ventimiglia"),g("Savone","savona"),g("Gênes Piazza Principe","genova")])
# LIVOURNE ET CIVITAVECCHIA REFUSÉES le 28 août 2026 (§0). Livourne : sa
# troisième branche (Collesalvetti) est fret-seul depuis 1966, à 262 trains
# PAR AN — il n'y a rien à y aiguiller. Civitavecchia : la branche du port est
# suspendue depuis 2009, la ligne d'Orte déclassée en 2011. CAMPIGLIA
# MARITTIMA les remplace : la gare-portier de l'île d'Elbe, trois directions
# franches qui divergent EN GARE. Grosseto tient par sa ligne de Sienne
# (diesel, terminus de fait — standard Lausanne, bifurcation à Montepescali).
ch(D,"La Tyrrhénienne","Gênes","Rome",[
  g("La Spezia","laspezia"),g("Pise","pisa"),g("Campiglia Marittima","campiglia"),
  g("Grosseto","grosseto"),g("Rome Termini","roma")])
# LA DIRETTISSIMA EST UNE HÉCATOMBE (§0, 28 août 2026) : Latina, Fondi,
# Minturno et Formia n'ont que deux directions — la branche de Gaeta est morte
# en 1966, celle de Minturno détruite en 1944. Une seule survivante sur le
# tronçon : Campoleone (le Y de Nettuno). Le chapitre est donc RE-ROUTÉ aux
# deux bouts, sur du rail entièrement réel : entrée par Ciampino (l'éventail
# des Castelli, première ligne des États pontificaux) et sortie par la rocade
# Villa Literno – Cancello – Caserte (fret quotidien, voyageurs depuis
# juillet 2026), qui ramène sur Naples par la gare du palais royal. C'est le
# précédent du Fréjus : la route choisie par les règles, pas par la carte.
ch(D,"La Campanie","Rome","Naples",[
  g("Ciampino","ciampino"),g("Campoleone","campoleone"),g("Villa Literno","villaliterno"),
  g("Caserte","caserta"),g("Naples Centrale","napoli")])
# SAPRI ET CEFALÙ REFUSÉES le 28 août 2026 (§0) : gares de passage à deux
# directions — Sapri n'a jamais eu de branche, Cefalù sera même déclassée en
# halte souterraine par le doublement. TERMINI IMERESE remplace Cefalù :
# dernière gare commune aux trois flux de Messine, d'Agrigente et de Catane
# (bifurcation à Fiumetorto, 5 km — le standard Lausanne s'applique). Sapri
# n'a pas de remplaçante : sa seule candidate, Battipaglia, ouvre le chapitre
# suivant. Le chapitre tient à sept.
ch(D,"Le train qui prend le bateau","Naples","Palerme",[
  g("Salerne","salerno"),g("Paola","paola"),g("Lamezia Terme","lamezia"),
  g("Villa San Giovanni","villasg"),g("Messine","messina"),
  g("Termini Imerese","termini"),g("Palerme Centrale","palermo")])
# GIOIA DEL COLLE REFUSÉE le 28 août 2026 (§0) : sa transversale de
# Rocchetta est morte en voyageurs depuis 2016, ressuscitée seulement pour un
# train touristique de luxe. Aucune bifurcation vivante entre Bari et Tarente
# — le chapitre tient à cinq.
ch(D,"La Lucanie","Palerme","Bari",[
  g("Battipaglia","battipaglia"),g("Potenza","potenza"),g("Metaponto","metaponto"),
  g("Tarente","taranto"),g("Bari Centrale","bari")],
  saut=("nuit","Le Palerme–Naples de nuit — le ferry de Messine dans l'autre sens"))
# BARLETTA ET TERMOLI REFUSÉES le 28 août 2026 (§0) : deux nœuds amputés.
# Barletta n'a plus que la côte — Spinazzola est sans trains malgré des travaux
# finis, la Ferrotramviaria est coupée à Andria Sud jusqu'en 2027. Termoli a
# perdu Campobasso en 2023 (glissement de terrain, aucune date de retour).
# SAN SEVERO les remplace : la ligne privée du Gargano (Peschici) s'y greffe
# sur l'Adriatique, bien vivante — le carrefour ACTUEL du tronçon, comme le
# veut la parade du §0. Ancône reste : Bologne, Rome et Lecce y sont trois
# axes de service vivants, même si Rome ne diverge qu'à Falconara — le
# standard est celui de Lausanne, dont les trois portails ouest convergent à
# Renens. Falconara et Santhià restent en réserve documentée.
ch(D,"L'Adriatique","Bari","Bologne",[
  g("Foggia","foggia"),g("San Severo","sansevero"),g("Pescara","pescara"),
  g("Ancône","ancona"),g("Rimini","rimini"),g("Bologne Centrale","bologna")])
ch(D,"La Vénétie","Bologne","Venise",[
  g("Ferrare","ferrara"),g("Rovigo","rovigo"),g("Padoue","padova"),
  g("Mestre","mestre"),g("Venise Santa Lucia","venezia")])
# PESCHIERA ET DESENZANO REFUSÉES le 28 août 2026 (§0) : gares de passage à
# deux directions sur le tronc Milan–Venise — leurs seuls embranchements sont
# morts en 1967 (Mantoue) et 1969 (le port). Aucune bifurcation voyageurs ne
# survit entre Brescia et Vérone (Rezzato–Vobarno déposée en 1976) : le lac de
# Garde ne fournit aucun niveau, le chapitre tient à cinq.
ch(D,"La plaine lombarde","Venise","Milan",[
  g("Vicence","vicenza"),g("Vérone","verona"),g("Brescia","brescia"),
  g("Treviglio","treviglio"),g("Milan Centrale","milano")])
# MAGENTA REFUSÉE le 28 août 2026 (§0) : pure gare de passage à deux directions
# et deux voies sur la ligne Turin–Milan, jamais été une bifurcation — la seule
# desserte disparue était un tramway routier (1957). Le chapitre tient à cinq.
ch(D,"Le Piémont","Milan","Turin",[
  g("Rho","rho"),g("Novare","novara"),g("Verceil","vercelli"),
  g("Chivasso","chivasso"),g("Turin Porta Nuova","torino")])

# =====================================================================
E = acte("alp","Acte V — Les Alpes, le Rhin et la Germanie","Du Fréjus à la Baltique, le cœur écrit du catalogue")
# FUSION du 27 août 2026. « Le Fréjus » et « Le Bugey » n'existent plus
# séparément : quatre de leurs gares ont été refusées par le §0 (Modane,
# Saint-Jean-de-Maurienne, Meximieux, Seyssel — deux directions chacune), et le
# corridor de Turin à Genève ne compte que neuf gares qualifiées, trop peu pour
# donner cinq gares à deux chapitres. R7 a choisi l'itinéraire : par Culoz,
# sinuosité 1,38 ; par le Haut-Bugey et Bourg-en-Bresse, 1,95 — refusé.
# Lyon Part-Dieu, Ambérieu et Bourg-en-Bresse sortent donc du ruban et restent
# au catalogue. Le raisonnement complet est dans ruban-europe.md, qui fait foi.
ch(E,"Le Fréjus et le Bugey","Turin","Genève",[
  g("Bussoleno","bussoleno"),g("Chambéry","chambery"),g("Aix-les-Bains","aix-les-bains"),
  g("Culoz","culoz"),g("Bellegarde","bellegarde"),g("Genève-Cornavin","geneve")])
ch(E,"Le Plateau suisse","Genève","Zurich",[
  g("Lausanne","lausanne"),g("Fribourg","fribourg"),g("Berne","bern"),g("Olten","olten"),g("Aarau","aarau"),g("Zurich HB","zurich")])
ch(E,"Le Rhin supérieur","Zurich","Strasbourg",[
  g("Bâle","bale"),g("Mulhouse","mulhouse"),g("Colmar","colmar"),g("Sélestat","selestat"),g("Strasbourg","strasbourg")])
ch(E,"La Lorraine","Strasbourg","Luxembourg",[
  g("Sarrebourg","sarrebourg"),g("Nancy","nancy"),g("Metz","metz"),g("Thionville","thionville"),g("Bettembourg","bettembourg"),g("Luxembourg","luxembourg")])
ch(E,"L'Ardenne","Luxembourg","Bruxelles",[
  g("Arlon","arlon"),g("Libramont","libramont"),g("Marloie","marloie"),g("Namur","namur"),g("Ottignies","ottignies"),g("Bruxelles-Midi","bruxelles-midi")])
ch(E,"Le Benelux","Bruxelles","Amsterdam",[
  g("Malines","malines"),g("Anvers","anvers"),g("Roosendaal","roosendaal"),g("Dordrecht","dordrecht"),g("Rotterdam","rotterdam"),g("Amsterdam Centraal","amsterdam")])
ch(E,"La Basse-Saxe","Amsterdam","Hanovre",[
  g("Amersfoort","amersfoort"),g("Deventer","deventer"),g("Hengelo","hengelo"),g("Rheine","rheine"),g("Osnabrück","osnabruck"),g("Hanovre Hbf","hannover")])
ch(E,"La Ruhr","Hanovre","Cologne",[
  g("Minden","minden"),g("Bielefeld","bielefeld"),g("Hamm","hamm"),g("Hagen","hagen"),g("Wuppertal","wuppertal"),g("Cologne Hbf","koln")])
ch(E,"Le Rhin romantique","Cologne","Francfort",[
  g("Bonn","bonn"),g("Coblence","koblenz"),g("Bingen","bingen"),g("Mayence","mainz"),g("Wiesbaden"),g("Francfort Hbf","frankfurt")])
ch(E,"Le Neckar","Francfort","Stuttgart",[
  g("Darmstadt"),g("Mannheim","mannheim"),g("Heidelberg"),g("Bruchsal"),g("Vaihingen"),g("Stuttgart Hbf","stuttgart")])
ch(E,"La Souabe","Stuttgart","Munich",[
  g("Plochingen","plochingen"),g("Ulm","ulm"),g("Günzburg","gunzburg"),g("Augsbourg","augsburg"),g("Munich Hbf","munchen")])
# Le chapitre a QUITTÉ LA LGV le 26 août 2026 : Pfaffenhofen, Kinding et
# Allersberg n'ont que deux directions — les deux dernières sont des haltes de
# la ligne à grande vitesse de 2006, bâties pour que des trains passent à
# 300 km/h à côté d'elles. Il n'y a rien à y aiguiller. La ligne classique par
# Treuchtlingen offre de vrais nœuds.
ch(E,"La Bavière","Munich","Nuremberg",[
  g("Dachau","dachau"),g("Ingolstadt","ingolstadt"),g("Treuchtlingen","treuchtlingen"),
  g("Roth","roth"),g("Nuremberg Hbf","nurnberg")])
ch(E,"La Franconie et la Thuringe","Nuremberg","Leipzig",[
  g("Bamberg","bamberg"),g("Lichtenfels","lichtenfels"),g("Saalfeld","saalfeld"),g("Erfurt","erfurt"),g("Weimar","weimar"),g("Naumbourg","naumburg"),g("Leipzig Hbf","leipzig")])
ch(E,"La marche de Brandebourg","Leipzig","Berlin",[
  g("Halle","halle"),g("Bitterfeld","bitterfeld"),g("Wittenberg","wittenberg"),g("Jüterbog","juterbog"),g("Berlin Hbf","berlin")])
ch(E,"Le Mecklembourg","Berlin","Hambourg",[
  g("Neustrelitz","neustrelitz"),g("Rostock","rostock"),g("Bad Kleinen","badkleinen"),g("Schwerin","schwerin"),g("Hambourg Hbf","hamburg")])

# =====================================================================
F = acte("sca","Acte VI — Le Nord","Du Jutland au golfe de Finlande")
ch(F,"Le Jutland","Hambourg","Copenhague",[
  g("Neumünster"),g("Rendsburg"),g("Flensbourg"),g("Padborg"),g("Kolding"),g("Odense"),g("Copenhague H")])
ch(F,"L'Øresund","Copenhague","Göteborg",[
  g("Malmö"),g("Lund"),g("Helsingborg"),g("Halmstad"),g("Varberg"),g("Kungsbacka"),g("Göteborg Central")])
ch(F,"Le Bohuslän","Göteborg","Oslo",[
  g("Trollhättan"),g("Öxnered"),g("Ed"),g("Halden"),g("Sarpsborg"),g("Moss"),g("Oslo Sentralstasjon")])
ch(F,"Le Bergensbanen","Oslo","Bergen",[
  g("Hønefoss"),g("Ål"),g("Geilo"),g("Finse"),g("Myrdal"),g("Voss"),g("Bergen")])
ch(F,"Le Värmland","Bergen","Stockholm",[
  g("Lillestrøm"),g("Kongsvinger"),g("Arvika"),g("Karlstad"),g("Kristinehamn"),g("Örebro"),g("Västerås"),g("Stockholm Central")],
  saut=("nuit","Le train de nuit du Bergensbanen — Bergen redescend sur Oslo"))
ch(F,"La Finlande du Sud","Stockholm","Helsinki",[
  g("Turku"),g("Salo"),g("Karjaa"),g("Lohja"),g("Espoo"),g("Pasila"),g("Helsinki")],
  saut=("mer","Le ferry de l'archipel — Stockholm à Turku, une nuit entre vingt mille îles"))
ch(F,"La Livonie","Helsinki","Riga",[
  g("Tallinn"),g("Tapa"),g("Tartu"),g("Valga"),g("Valmiera"),g("Cēsis"),g("Sigulda"),g("Riga")],
  saut=("mer","Le golfe de Finlande — Helsinki à Tallinn, deux heures de mer"))
ch(F,"La Sémigalie","Riga","Vilnius",[
  g("Jelgava"),g("Joniškis"),g("Šiauliai"),g("Radviliškis"),g("Kaunas"),g("Vilnius")])

# =====================================================================
G_ = acte("ctr","Acte VII — La Baltique et la Bohême","De la Lituanie à Vienne par la Pologne")
ch(G_,"La Ruthénie blanche","Vilnius","Minsk",[
  g("Kena"),g("Gudogaï"),g("Maladzetchna"),g("Smaliavitchy"),g("Minsk-Pasajyrski")])
ch(G_,"La Polésie","Minsk","Brest-Litovsk",[
  g("Stoubtsy"),g("Baranavitchy"),g("Ivatsevitchy"),g("Biaroza"),g("Brest-Tsentralny")])
ch(G_,"La Mazovie","Brest-Litovsk","Varsovie",[
  g("Terespol"),g("Biała Podlaska"),g("Łuków"),g("Siedlce"),g("Mińsk Mazowiecki"),g("Varsovie Centrale")])
ch(G_,"La Vistule","Varsovie","Gdansk",[
  g("Nasielsk"),g("Ciechanów"),g("Działdowo"),g("Iława"),g("Malbork"),g("Tczew"),g("Gdańsk Główny")])
ch(G_,"La Cujavie","Gdansk","Poznan",[
  g("Laskowice"),g("Bydgoszcz"),g("Inowrocław"),g("Gniezno"),g("Poznań Główny")])
ch(G_,"La Grande-Pologne","Poznan","Wroclaw",[
  g("Kościan"),g("Leszno"),g("Rawicz"),g("Żmigród"),g("Oborniki Śląskie"),g("Wrocław Główny")])
ch(G_,"La Silésie","Wroclaw","Cracovie",[
  g("Oława"),g("Brzeg"),g("Opole"),g("Gliwice"),g("Katowice"),g("Cracovie Główny")])
ch(G_,"La Moravie","Cracovie","Prague",[
  g("Oświęcim"),g("Bohumín"),g("Ostrava"),g("Olomouc"),g("Pardubice"),g("Kolín"),g("Prague hlavní nádraží")])
ch(G_,"La Bohême","Prague","Vienne",[
  g("Benešov"),g("Havlíčkův Brod"),g("Brno"),g("Břeclav"),g("Hohenau"),g("Vienne Hbf")])

# =====================================================================
H_ = acte("bal","Acte VIII — Les Alpes orientales et la Dalmatie","De Vienne à la Pannonie par la mer Adriatique")
ch(H_,"Le Semmering","Vienne","Ljubljana",[
  g("Wiener Neustadt"),g("Semmering"),g("Bruck an der Mur"),g("Graz"),g("Maribor"),g("Celje"),g("Ljubljana")])
ch(H_,"La Save","Ljubljana","Zagreb",[
  g("Zidani Most"),g("Sevnica"),g("Brežice"),g("Dobova"),g("Zaprešić"),g("Zagreb Glavni")])
ch(H_,"La Dalmatie","Zagreb","Split",[
  g("Karlovac"),g("Ogulin"),g("Gospić"),g("Knin"),g("Perković"),g("Split")])
ch(H_,"La Neretva","Split","Sarajevo",[
  g("Ploče"),g("Metković"),g("Čapljina"),g("Mostar"),g("Konjic"),g("Pazarić"),g("Sarajevo")],
  saut=("mer","Le littoral dalmate — le bateau côtier de Split à Ploče"))
ch(H_,"La Bosnie","Sarajevo","Belgrade",[
  g("Zenica"),g("Doboj"),g("Šamac"),g("Vinkovci"),g("Šid"),g("Belgrade Centar")])
ch(H_,"La Pannonie","Belgrade","Budapest",[
  g("Novi Sad"),g("Subotica"),g("Kelebia"),g("Kiskunhalas"),g("Kecskemét"),g("Budapest Keleti")])

# =====================================================================
I_ = acte("est","Acte IX — L'Est et l'Orient","Des Carpates au Bosphore")
ch(I_,"Les Carpates","Budapest","Lviv",[
  g("Szolnok"),g("Debrecen"),g("Nyíregyháza"),g("Záhony"),g("Tchop"),g("Moukatchevo"),g("Stryï"),g("Lviv")])
ch(I_,"La Volhynie","Lviv","Kyiv",[
  g("Ternopil"),g("Khmelnytskyï"),g("Vinnytsia"),g("Kazatyn"),g("Fastiv"),g("Kyiv-Passajyrskyï")])
ch(I_,"La Sloboda","Kyiv","Kharkiv",[
  g("Yagotyn"),g("Poltava"),g("Krasnohrad"),g("Merefa"),g("Kharkiv-Passajyrskyï")])
ch(I_,"Le Donets","Kharkiv","Dnipro",[
  g("Lozova"),g("Pavlohrad"),g("Synelnykove"),g("Novomoskovsk"),g("Dnipro-Holovnyï")])
ch(I_,"La steppe","Dnipro","Odessa",[
  g("Piatykhatky"),g("Znamianka"),g("Pomichna"),g("Podilsk"),g("Rozdilna"),g("Odessa-Holovna")])
ch(I_,"La Bessarabie","Odessa","Chișinău",[
  g("Koutchourhan"),g("Tiraspol"),g("Bender"),g("Căinari"),g("Chișinău")])
ch(I_,"La Moldavie","Chișinău","Bucarest",[
  g("Ungheni"),g("Iași"),g("Roman"),g("Bacău"),g("Adjud"),g("Buzău"),g("Ploiești"),g("Bucarest Nord")])
ch(I_,"Le Danube","Bucarest","Sofia",[
  g("Giurgiu"),g("Roussé"),g("Gorna Oriakhovitsa"),g("Pleven"),g("Mezdra"),g("Sofia")])
ch(I_,"La Macédoine","Sofia","Thessalonique",[
  g("Pernik"),g("Blagoevgrad"),g("Sandanski"),g("Koulata"),g("Sidirokastro"),g("Thessalonique")])
ch(I_,"La Thessalie","Thessalonique","Athènes",[
  g("Katerini"),g("Larissa"),g("Palaiofarsalos"),g("Lianokladi"),g("Livadiá"),g("Athènes")])
ch(I_,"L'Express d'Orient","Athènes","Istanbul",[
  g("Serrès"),g("Drama"),g("Xanthi"),g("Komotini"),g("Alexandroúpoli"),g("Pythio"),g("Edirne"),g("Çerkezköy"),g("Istanbul Sirkeci")],
  saut=("nuit","Le train de nuit de Thessalie — Athènes remonte sur Thessalonique"))
