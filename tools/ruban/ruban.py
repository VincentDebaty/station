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
ch(B,"Le littoral atlantique","Nantes","Bordeaux",[
  g("La Roche-sur-Yon","lalochesuryon"),g("La Rochelle","larochelle"),g("Rochefort"),g("Saintes","saintes"),g("Jonzac"),g("Bordeaux Saint-Jean","bordeaux")])
ch(B,"Le canal des Deux-Mers","Bordeaux","Toulouse",[
  g("La Réole"),g("Marmande"),g("Agen","agen"),g("Moissac"),g("Montauban","montauban"),g("Toulouse Matabiau","toulouse")])
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
ch(C,"Le Levant","Malaga","Valence",[
  g("Grenade"),g("Guadix"),g("Almería"),g("Lorca"),g("Murcie"),g("Alicante"),g("Valence-Nord")])
ch(C,"La ligne de Teruel","Valence","Saragosse",[
  g("Sagonte"),g("Segorbe"),g("Caudiel"),g("Teruel"),g("Calamocha"),g("Saragosse-Delicias")])
ch(C,"L'Èbre","Saragosse","Barcelone",[
  g("Lérida"),g("Reus"),g("Tarragone"),g("Vilanova i la Geltrú"),g("Barcelone-Sants")])
ch(C,"Le Roussillon","Barcelone","Montpellier",[
  g("Gérone"),g("Figueres"),g("Portbou"),g("Perpignan"),g("Narbonne","narbonne"),g("Béziers","beziers"),g("Montpellier-Saint-Roch","montpellier")])

# =====================================================================
D = acte("it","Acte IV — Le Midi et l'Italie","De la Camargue à la Sicile, et retour par le Pô")
ch(D,"La Camargue","Montpellier","Marseille",[
  g("Nîmes","nimes"),g("Tarascon","tarascon"),g("Arles"),g("Miramas","miramas"),g("Marseille Saint-Charles","marseille")])
ch(D,"La Riviera","Marseille","Gênes",[
  g("Toulon","toulon"),g("Saint-Raphaël"),g("Cannes"),g("Nice","nice"),g("Monaco"),g("Vintimille"),g("San Remo"),g("Savone"),g("Gênes Piazza Principe")])
ch(D,"La Tyrrhénienne","Gênes","Rome",[
  g("La Spezia"),g("Pise"),g("Livourne"),g("Grosseto"),g("Civitavecchia"),g("Rome Termini")])
ch(D,"La Campanie","Rome","Naples",[
  g("Latina"),g("Fondi"),g("Formia"),g("Minturno"),g("Villa Literno"),g("Naples Centrale")])
ch(D,"Le train qui prend le bateau","Naples","Palerme",[
  g("Salerne"),g("Sapri"),g("Paola"),g("Lamezia Terme"),g("Villa San Giovanni"),g("Messine"),g("Cefalù"),g("Palerme Centrale")])
ch(D,"La Lucanie","Palerme","Bari",[
  g("Battipaglia"),g("Potenza"),g("Metaponto"),g("Tarente"),g("Gioia del Colle"),g("Bari Centrale")],
  saut=("nuit","Le Palerme–Naples de nuit — le ferry de Messine dans l'autre sens"))
ch(D,"L'Adriatique","Bari","Bologne",[
  g("Barletta"),g("Foggia"),g("Termoli"),g("Pescara"),g("Ancône"),g("Rimini"),g("Bologne Centrale")])
ch(D,"La Vénétie","Bologne","Venise",[
  g("Ferrare"),g("Rovigo"),g("Padoue"),g("Mestre"),g("Venise Santa Lucia")])
ch(D,"La plaine lombarde","Venise","Milan",[
  g("Vicence"),g("Vérone"),g("Peschiera"),g("Desenzano"),g("Brescia"),g("Treviglio"),g("Milan Centrale")])
ch(D,"Le Piémont","Milan","Turin",[
  g("Rho"),g("Magenta"),g("Novare"),g("Verceil"),g("Chivasso"),g("Turin Porta Nuova")])

# =====================================================================
E = acte("alp","Acte V — Les Alpes, le Rhin et la Germanie","Du Fréjus à la Baltique, le cœur écrit du catalogue")
ch(E,"Le Fréjus","Turin","Lyon",[
  g("Bussoleno"),g("Modane"),g("Saint-Jean-de-Maurienne"),g("Chambéry","chambery"),g("Aix-les-Bains"),g("Ambérieu","amberieu"),g("Lyon Part-Dieu","lyon")])
ch(E,"Le Bugey","Lyon","Genève",[
  g("Meximieux"),g("Culoz","culoz"),g("Seyssel"),g("Bellegarde","bellegarde"),g("Genève-Cornavin","geneve")])
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
ch(E,"La Bavière","Munich","Nuremberg",[
  g("Dachau"),g("Pfaffenhofen"),g("Ingolstadt","ingolstadt"),g("Kinding"),g("Allersberg"),g("Nuremberg Hbf","nurnberg")])
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
