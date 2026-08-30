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
# CALDICOT ET PILNING REFUSÉES le 30 août 2026. Caldicot : halte à deux
# quais de la seule ligne Gloucester–Newport — rien à aiguiller. PILNING est
# la pièce du musée : DEUX TRAINS PAR SEMAINE (le samedi), un seul quai
# accessible depuis que Network Rail a démoli la passerelle le 5 novembre
# 2016 pour passer les caténaires, et un taxi officiel vers Severn Tunnel
# Junction pour rentrer au pays de Galles. BRISTOL PARKWAY la remplace : la
# première « Parkway » du royaume (1972), quatre directions vivantes — sa
# paire Cardiff×Birmingham reste VIDE exprès, les CrossCountry passent par
# Gloucester. Newport a retrouvé sa quatrième direction en 2024 (Ebbw Vale,
# fermée aux voyageurs depuis 1962).
ch(A,"Le tunnel de la Severn","Cardiff","Bristol",[
  g("Newport","newport"),g("Severn Tunnel Junction","severn-tunnel"),
  g("Bristol Parkway","bristol-parkway"),g("Filton Abbey Wood","filton"),
  g("Bristol Temple Meads","bristol")])
# TOTNES REFUSÉE le 30 août 2026 : deux quais sur l'axe, et sa South Devon
# vers Buckfastleigh est TOURISTIQUE et part d'une gare séparée (Totnes
# Riverside, une passerelle de 1993) — doublement disqualifiée, le motif
# Winchester. LISKEARD la remplace, plus à l'ouest : la Looe Valley vivante,
# et le seul quai perpendiculaire du royaume (les trains de Looe partent à
# angle droit et rebroussent à Coombe Junction). PENZANCE ferme le chapitre
# en d3 : terminus à voie unique mais TROIS axes commerciaux réels (les IC
# de Paddington, les locaux de Plymouth, le CrossCountry du nord — et le
# Night Riviera chaque nuit) — le précédent Lisbonne, l'entonnoir assumé.
ch(A,"La Riviera anglaise","Bristol","Penzance",[
  g("Taunton","taunton"),g("Exeter St Davids","exeter"),
  g("Newton Abbot","newton-abbot"),g("Plymouth","plymouth"),
  g("Liskeard","liskeard"),g("Truro","truro"),g("Penzance","penzance")])
# LE WESSEX PASSE INTACT (instruit le 30 août 2026) : ses quatre candidates
# tiennent toutes le §0 — dont TROWBRIDGE, contre le pronostic : la
# TransWilts relancée en 2013 lui donne sa troisième direction (neuf A/R par
# jour vers Melksham et Swindon). Bath Spa tient au standard Lausanne (la
# bifurcation est à Bathampton, les trois flux touchent ses deux quais —
# remontés au plancher de jouabilité). Romsey a sa jonction EN GARE (la
# boucle de Chandler's Ford, rouverte en 2003) ; sa Sprat and Winkle vers
# Andover est morte en 1964, jamais de portail de ce côté. Westbury laisse
# SWINDON hors gril (leçon Ashford, le flux le plus mince, déjà servi à
# Trowbridge).
ch(A,"Le Wessex","Penzance","Southampton",[
  g("Bath Spa","bath"),g("Trowbridge","trowbridge"),g("Westbury","westbury"),
  g("Salisbury","salisbury"),g("Romsey","romsey"),g("Southampton Central","southampton")],
  saut=("nuit","Le Night Riviera — le train de nuit de Penzance remonte à Bristol"))
# WINCHESTER REFUSÉE le 30 août 2026 (piège n° 1 au carré) : deux quais sur
# la seule main line — sa ligne d'Alton est un train TOURISTIQUE depuis la
# fermeture du 5 février 1973 (la Watercress Line), et la gare de Chesil de
# la ligne de Didcot est fermée. Southampton Airport Parkway refusée aussi
# (deux quais, même ligne). EASTLEIGH la remplace : la ville que le rail a
# bâtie — quatre directions vivantes, et son portail ROMSEY recoud le
# chapitre précédent gratuitement. Clapham Junction, la gare la plus
# traversée d'Europe (17 quais réels), est réduite à dix quais en DEUX
# faisceaux disjoints (Waterloo × Victoria) qui ne partagent aucun quai,
# comme en vrai — la sobriété d'Ashford appliquée d'avance.
ch(A,"Le South Western","Southampton","Londres",[
  g("Eastleigh","eastleigh"),g("Basingstoke","basingstoke"),g("Woking","woking"),
  g("Clapham Junction","clapham-junction"),g("London Waterloo","waterloo")])
# LE TUNNEL PREND LE TRACÉ EUROSTAR DE 1994 (décision de Vincent, 30 août
# 2026). Le tracé écrit était ROMPU : aucun rail ne relie Waterloo à la HS1,
# et STRATFORD INTERNATIONAL n'a jamais vu un train international (« no
# international services stop » — l'éléphant blanc). Le chapitre suit donc
# l'itinéraire historique de l'Eurostar au départ de Waterloo (1994-2003) :
# la South Eastern Main Line via TONBRIDGE (quatre directions vivantes) puis
# Ashford — continuité réelle, sans saut. Ebbsfleet (admise mais limite, ses
# quais internationaux morts depuis 2020) reste hors tracé. À Ashford, la
# branche de MAIDSTONE (un train par heure) est restée hors gril : six
# directions sur six quais ne se jouent pas, cinq oui — elle reviendra si la
# géométrie grossit. Calais-Fréthun est admise en limite basse (l'Eurostar
# traverse sans s'arrêter depuis 2020 ; la navette de Calais-Ville compte,
# le standard n'est pas un plancher de fréquentation). Et le boss est bien
# LILLE-FLANDRES — le tableau du ruban écrivait Lille-Europe, mais la fiche
# ET le rail classique d'Hazebrouck donnent Flandres : l'inverse exact de
# l'erreur Lille-Flandres/Lille-Europe que le §1 documente déjà.
ch(A,"Le tunnel","Londres","Lille",[
  g("Tonbridge","tonbridge"),g("Ashford International","ashford"),
  g("Calais-Fréthun","calais-frethun"),g("Hazebrouck","hazebrouck"),
  g("Lille-Flandres","lille")])

# =====================================================================
B = acte("nw","Acte II — La France atlantique","De la Manche aux Pyrénées")
ch(B,"L'Étoile du Nord","Lille","Paris",[
  g("Douai","douai"),g("Arras","arras"),g("Amiens","amiens"),g("Creil","creil"),g("Paris-Nord","paris-nord")])
# ÉVREUX REFUSÉE le 29 août 2026 (piège n° 1) : sa ligne de Rouen par
# Louviers est morte en 1969 — le lien Rouen–Évreux d'aujourd'hui est un car.
# SERQUIGNY la remplace : la bifurcation réelle de la ligne de Rouen, où tous
# les Caen–Rouen s'arrêtent depuis le renfort Nomad — le précédent Puyoô, le
# §0 juge le croisement, pas la fréquentation. Bernay tient au standard
# Lausanne (trois axes de service à quai), Lisieux révèle quatre directions
# (la branche de Deauville ne rebrousse plus depuis 1894), et CAEN est un
# boss d4 honnête : sept voies réelles sous la verrière de 1934, cinq
# directions — précédent Lisbonne, on ne gonfle pas.
ch(B,"La Normandie","Paris","Caen",[
  g("Mantes-la-Jolie","mantes-la-jolie"),g("Serquigny","serquigny"),
  g("Bernay","bernay"),g("Lisieux","lisieux"),g("Caen","caen")])
# LE COTENTIN ET LA BRETAGNE ONT FUSIONNÉ (décision de Vincent, 30 août
# 2026). Six refus §0 sur les deux chapitres : Bayeux et Avranches
# (passantes), Saint-Lô (sa branche de Vire a perdu ses voyageurs le
# 10 octobre 1938 — un vélo-rail aujourd'hui), Pontorson (la ligne du Mont
# est déposée depuis 1945, le Mont se fait en bus), Bruz (halte périurbaine)
# et Messac (sa ligne de Châteaubriant est fermée). L'alternative
# Châteaubriant a été vérifiée : impasse — la gare elle-même est un refus,
# deux terminus séparés par un passage piéton. Entrent : LISON (l'aiguille
# du Cotentin), GRANVILLE — le tracé RÉEL du ruban : la fiche horaire 2026
# montre les Caen–Rennes entrant au terminus et y rebroussant —, FOLLIGNY
# (la croix de la Manche, quatre directions pour trois cents habitants) et
# DOL (quatre directions, Dinan renforcée en septembre 2025). Rennes se joue
# en cours de chapitre, comme Valence-Nord et Séville avant elle. Redon
# garde son rebroussement réel en Y (les Nantes–Rennes arrêtés rebroussent
# à quai, seul le triangle sauve les directs).
ch(B,"Le Cotentin et la Bretagne","Caen","Nantes",[
  g("Lison","lison"),g("Granville","granville"),g("Folligny","folligny"),
  g("Dol-de-Bretagne","dol"),g("Rennes","rennes"),g("Redon","redon"),
  g("Savenay","savenay"),g("Nantes","nantes")])
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
# LE PIÉMONT S'ARRÊTE À BAYONNE (décision de Vincent, 29 août 2026). Six
# refus §0 : Saint-Gaudens et Orthez (passantes pures), Tarbes (piège n° 1 —
# son étoile est morte en 1970, et Lourdes n'est pas une direction : elle est
# SUR la ligne de Pau), Lourdes elle-même (sa ligne de Pierrefitte est une
# voie verte depuis 1997), et surtout HENDAYE et IRÚN, à UNE direction
# chacune : plus aucun train de voyageurs ne franchit la Bidassoa côté
# grandes lignes depuis 2020 — seul le Topo d'Euskotren passe, depuis ses
# propres gares (règle Lille-Flandres). Le maillon Irún → Bilbao n'existe pas
# en écartement ibérique : trois heures de voie métrique Euskotren avec
# changement à Amara, arrivant à Matiko — pas à Abando. Entrent : MONTRÉJEAU
# (la branche de Luchon rouverte le 22 juin 2025, Régiolis hybrides), PUYOÔ
# (la bifurcation des Gaves — trois directions vivantes ; le standard
# Lausanne n'est pas un plancher de fréquentation, précédents Monfragüe et
# Sant Vicenç) et DAX (le reroutage Puyoô → Dax → Bayonne est le rail réel
# des TGV). Bayonne ferme le chapitre en d3 — précédent Lisbonne — et le
# ruban franchit le Pays basque par le SAUT DE LA CÔTE BASQUE : Bilbao
# Abando ouvre la Castille.
ch(B,"Le piémont pyrénéen","Toulouse","Bayonne",[
  g("Montréjeau","montrejeau"),g("Pau","pau"),g("Puyoô","puyoo"),
  g("Dax","dax"),g("Bayonne","bayonne")])

# =====================================================================
C = acte("ib","Acte III — L'Ibérie","La grande boucle de la péninsule")
# LA CASTILLE EST LE PREMIER CHAPITRE SANS UN SEUL REFUS §0 (instruit le
# 29 août 2026) : ses six gares d'origine passent toutes. Miranda de Ebro est
# un des rares croisements « en aspa » d'Espagne (deux lignes en X, plans de
# 1894 vérifiés — pas de rebroussement) ; Ávila est le CONTRE-EXEMPLE du
# piège n° 1 : sa ligne de Salamanque par Peñaranda est bien vivante (jusqu'à
# six MD par jour, accélérés en avril 2025). Refus périphériques documentés :
# Segovia-Guiomar (passante pure de la LAV), la ligne Valladolid–Ariza (morte
# en 1985 — jamais de portail SORIA). Réserve datée : la branche Miranda–
# Logroño tient à 1-2 régionaux par jour, rognés en 2025 — si elle meurt, le
# portail SARAGOSSE de Miranda tombe (la gare reste admissible à 3
# directions). Le tracé Valladolid→Ávila TRAVERSE Medina del Campo sans s'y
# arrêter (R6 ne mesure que les fiches et les villes — permis). Palencia a
# coûté trois grils : quatre directions sur cinq quais ne pardonnent ni le
# quai à quatre portails, ni le quai sans paire L×R — le pavage final partage
# le tronc Valladolid×León sur 1-3 et met chaque antenne face à son vrai
# partenaire (Burgos×León = le transversal Barcelone–Galice ; Burgos×
# Santander = rien, comme en vrai).
# BILBAO ABANDO OUVRE LA CASTILLE depuis le 29 août 2026 (saut de la côte
# basque) : huit heurtoirs sous le vitrail de 1948, six directions
# commerciales — l'Intercity de Vigo fournit la sixième — et la Concordia
# voisine, métrique, ne donne aucun portail (règle Lille-Flandres). Le
# maillon Bilbao → Miranda est la ligne d'Orduña, réelle (C-3 + Alvia).
ch(C,"La Castille","Bayonne","Madrid",[
  g("Bilbao Abando","bilbao"),g("Miranda de Ebro","miranda"),
  g("Burgos Rosa Manzano","burgos"),g("Palencia","palencia"),
  g("Valladolid-Campo Grande","valladolid"),g("Ávila","avila"),
  g("Madrid-Chamartín","madrid-chamartin")],
  saut=("correspondance","La côte basque — le Topo franchit la Bidassoa, puis trois heures d'Euskotren jusqu'à Bilbao"))
# SEPT REFUS §0 SUR L'ESTRÉMADURE, mesurés le 29 août 2026. Talavera et
# Navalmoral sont des passantes pures de la ligne 500 (aucune branche, jamais).
# Plasencia est le piège n° 1 le plus pur : terminus d'une antenne de 16,7 km
# depuis que la Ruta de la Plata est morte en 1985 — les Alvia y rebroussent.
# Aljucén : vraie bifurcation, mais le gril a été démonté en 2002 (2 voies).
# BADAJOZ, la capitale, n'a que deux directions : aucune ligne directe vers
# Cáceres ni Zafra, tout passe par Mérida — le nœud, c'est elle. ELVAS est
# une passante du Leste (2 A/R par jour) ; la Nova Linha d'Évora ouvrira au
# fret d'abord. Torre das Vargens a perdu son ramal de Cáceres (frontière de
# Marvão morte en 2012). Le chapitre se recompose sur les nœuds vivants :
# MONFRAGÜE (l'ancienne Palazuelo-Empalme, trois lignes dans le parc
# national), Cáceres (réserve consignée : sa troisième direction tient au
# régional de Valencia de Alcántara, trois matins par semaine), Mérida (la
# croix de l'Estrémadure, vérifiée sur OSM : trois branches au col ouest, les
# Alvia rebroussent), ABRANTES (le Leste quitte la Beira Baixa à Rossio),
# Entroncamento. Et LISBONNE SANTA APOLÓNIA est un boss d4 ASSUMÉ — six voies
# à quai en service (pas de voie 4), la première fin de chapitre non-d5 du
# ruban : le moteur le prévoit (« une fin de chapitre sur une gare de six
# quais ne vaut pas une fin sur Bruxelles-Midi »), et gonfler la doyenne de
# 1865 de deux voies inventées serait le mensonge inverse de Charleroi.
ch(C,"L'Estrémadure","Madrid","Lisbonne",[
  g("Monfragüe","monfrague"),g("Cáceres","caceres"),g("Mérida","merida"),
  g("Abrantes","abrantes"),g("Entroncamento","entroncamento"),
  g("Lisbonne Santa Apolónia","lisbonne")])
# CINQ REFUS §0 SUR LA LINHA DO NORTE, mesurés le 29 août 2026. Azambuja,
# Santarém et Pombal sont des passantes pures (la « Linha da Azambuja » est un
# nom de service, la bifurcation de Vendas Novas est à Setil ET fret-seul
# depuis 2005, Pombal n'a jamais eu de ramal — même ses correspondances de
# 1913 étaient des diligences). ESPINHO : le Vouga part d'Espinho-Vouga, une
# halte séparée depuis l'enfouissement de 2008 — la règle Lille-Flandres.
# Et COIMBRA-B est le piège n° 1 dans sa version la plus fraîche : le ramal
# vers Coimbra-ville est mort le 12 JANVIER 2025, converti en Metrobus — la
# Beira Alta bifurque à Pampilhosa, Figueira à Alfarelos, il ne reste que
# deux bouts. Le chapitre se recompose sur les bifurcations VIVANTES :
# Lisboa Oriente (la nef de Calatrava — gare distincte de Santa Apolónia,
# §4), Alfarelos (le seul aiguillage voyageurs entre Setil et Pampilhosa),
# Pampilhosa (la Beira Alta a rouvert en entier le 28 septembre 2025),
# Aveiro (la dernière voie métrique de CP, ~10 trains/jour vers Águeda).
# Cinq gares, le plancher de R3 — Entroncamento reste à l'Estrémadure.
ch(C,"La côte d'Argent","Lisbonne","Porto",[
  g("Lisboa Oriente","oriente"),g("Alfarelos","alfarelos"),g("Pampilhosa","pampilhosa"),
  g("Aveiro","aveiro"),g("Porto Campanhã","porto")])
# VALENÇA ET ZAMORA REFUSÉES le 28 août 2026 (§0, piège n° 1 deux fois) :
# Valença a perdu sa ligne de Monção le 2 janvier 1990 (une écopiste
# aujourd'hui) ; Zamora n'a jamais été aussi desservie (huit Alvia par jour)
# mais tout roule sur un seul axe — sa ligne de Salamanque, la Ruta de la
# Plata, est morte en 1985, déclassée en 1996. Aucun remplaçant sur le
# corridor : le chapitre joue cinq gares, le plancher exact de R3. VIGO, c'est
# GUIXAR, pas Urzáiz : le Celta de Porto y arrive ET les régionaux du Miño
# vers Ourense en partent — le ruban est continu dans une seule gare, quand
# Urzáiz ne rejoint Ourense que par le détour de Saint-Jacques. Et le chapitre
# finit bien à ATOCHA : les trains de Galice touchent Chamartín, mais le
# tunnel de grande vitesse Chamartín–Atocha (juillet 2022) prolonge l'axe
# jusqu'à elle — la fiche le porte par son portail CHAMARTÍN. La ligne du
# Minho côté espagnol est en rénovation intégrale (coupure avril 2026 → 2027,
# 265 M d'euros) : des travaux, pas un déclin.
ch(C,"La Galice","Porto","Madrid",[
  g("Nine","nine"),g("Vigo-Guixar","vigo"),g("Ourense-Empalme","ourense"),
  g("Medina del Campo","medina"),g("Madrid-Atocha","madrid-atocha")])
# LA BÉTIQUE A FONDU DANS L'ANDALOUSIE (décision de Vincent, 28 août 2026).
# Trois refus §0 sur la ligne unique de Bobadilla : MARCHENA est le piège n° 1
# au sens littéral (sa ligne de Cordoue est la Vía Verde de la Campiña depuis
# le 1er janvier 1971), OSUNA une passante simple, et UTRERA la variante la
# plus sournoise — la bifurcation de Malaga est VIVANTE mais passe à 1,5 km au
# nord de la gare : les MD de Malaga ne s'arrêtent pas à ses quais (les trains
# sans le nœud, ou le nœud sans les trains). La Roda de Andalucía, jonction
# déviée en 1992, sans voyageurs depuis 2013, ne repêche rien. Restaient
# quatre gares — R3 en veut cinq : fusion, dix gares, le maximum exact de R3.
# DOS HERMANAS est admise au standard Lausanne : tronc commun à deux quais,
# mais les trois flux (C-1, Cadix, Malaga) s'y arrêtent chaque jour, et le tri
# est réel en service. Le boss passe à Málaga-María Zambrano — le premier
# boss-terminus du ruban — et Séville Santa Justa se joue en cours de
# chapitre. À Bobadilla, ne jamais écrire de portail CORDOUE (voyageurs
# supprimés en 2013, fret seul) ; Antequera-Ciudad est fermée depuis 2015.
# ARANJUEZ REFUSÉE le 28 août 2026 (§0, piège n° 1) : l'étoile a porté quatre
# branches, il n'en circule plus que deux — Cuenca morte le 20 juillet 2022
# (le même jour que pour Valence-Nord), Tolède morte en novembre 2005 à
# l'ouverture de la LGV. Le corridor Madrid–Alcázar n'offre AUCUN remplaçant :
# Castillejo-Añover a perdu Tolède en 2005, Villacañas sa ligne de Quintanar
# vers 1990. Le chapitre s'ouvre donc sur Alcázar de San Juan, le carrefour
# ACTUEL de la Manche — neuf gares, toujours dans R3.
ch(C,"L'Andalousie et la Bétique","Madrid","Malaga",[
  g("Alcázar de San Juan","alcazar"),g("Ciudad Real","ciudad-real"),
  g("Puertollano","puertollano"),g("Córdoba Central","cordoba"),
  g("Séville Santa Justa","sevilla"),g("Dos Hermanas","dos-hermanas"),
  g("Bobadilla","bobadilla"),g("Antequera-Santa Ana","antequera"),
  g("Málaga-María Zambrano","malaga")])
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
# LE MAILLON ANDALOU EST TOMBÉ le 28 août 2026 (décision de Vincent, saut).
# GUADIX et LORCA : le piège n° 1 des deux côtés du même trou — l'itinéraire
# historique Andalousie–Levant (Guadix–Baza–Almendricos) est fermé depuis le
# 1er janvier 1985, chacune n'a gardé que sa ligne de passage à deux bouts.
# ALMERÍA : terminus à ligne physique unique (~4 trains/jour dans le même
# goulet), et gare fermée depuis mars 2024 pour l'enfouissement. Entre Almería
# et Lorca, AUCUNE ligne n'a jamais existé — la LGV Murcie–Almería du Corredor
# Mediterráneo n'ouvre pas avant 2028-2029. GRENADE, elle, est ADMISE (§0 :
# cinq directions voyageurs sur un terminus à changeur d'écartement, fiche
# instruite le 28 août 2026) mais ISOLÉE : aucun rail vivant vers Murcie, et
# un saut ne vit qu'entre deux chapitres — elle reste EN RÉSERVE documentée,
# prête si le modèle évolue ou si la LGV d'Almería ouvre un jour le passage.
# Le chapitre assume l'état cible du corridor (gare souterraine de Murcie
# 2026, C-2 de Lorca 2027), comme ses fiches.
ch(C,"Le Levant et l'Aragon","Malaga","Saragosse",[
  g("Murcie","murcia"),g("Alicante","alicante"),g("Valence-Nord","valencia"),
  g("Sagonte","sagunto"),g("Saragosse-Delicias","zaragoza")],
  saut=("lgv","Le Corredor Mediterráneo — de Malaga à Murcie par la côte d'Almería"))
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
