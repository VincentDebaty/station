# Le ruban d'Europe — le tracé complet

> Écrit le 25 août 2026, après la décision de faire de la carte un **ruban**
> (`meta-progression-jeu-aiguillage.md` §0) et la règle R6 « on ne refait
> jamais la même ligne ». Ce document **est** le contenu de la carte Europe :
> l'ordre des chapitres, leurs noms, et la liste des gares dans l'ordre du rail.
> Il alimente le lot C (les données) et le lot F (l'écriture des fiches).

## Ce que c'est

Un seul fil, de **Cork à Istanbul**, sans embranchement et sans choix. Le joueur
part de la pointe sud-ouest de l'Irlande et arrive au Bosphore ; entre les deux,
il traverse l'Europe une fois, dans un ordre écrit d'avance, en franchissant
neuf actes et huit ruptures de continuité.

Le voyage n'est pas une ligne droite : c'est une **spirale**. Les Îles, puis la
France atlantique, la boucle ibérique, le Midi et l'Italie jusqu'à la Sicile,
la remontée par le Pô et les Alpes, le Rhin et la Germanie, le Nord jusqu'au
golfe de Finlande, la Baltique et la Bohême, enfin les Balkans et l'Orient.
Chaque région est traversée **une fois**, et on n'y revient jamais.

| | |
|---|---|
| Actes | **9** |
| Chapitres | **95** |
| Gares — c'est-à-dire **niveaux** | **592** |
| Fiches déjà écrites, réemployées telles quelles | **126** |
| Fiches à écrire | **466** |
| Sauts déclarés (§4 bis) | **8** |
| Longueur des chapitres | 5 à 9 gares, médiane 6 |

**Vérifié par script** (`scratchpad/verif.py`, à porter dans `carte-check` au
lot C) : les 94 chapitres tiennent tous R3 (5 à 10 gares), aucune gare
n'apparaît deux fois (R6), le chaînage est continu d'un bout à l'autre, et
les 123 fiches annoncées comme existantes existent bien au catalogue.

## Comment lire les tableaux

- Les gares sont **dans l'ordre du rail**, de gauche à droite. La **dernière,
  en gras, est la grande gare** qui ferme le chapitre.
- ✓ = la fiche existe déjà dans `data/stations/`. Sans marque = **à écrire**.
- ✗ barré = **refusée par le §0** (moins de trois directions réelles).
  ⊘ = fiche écrite et validée, mais pas encore enregistrée (isolée du réseau).
- Un chapitre précédé d'un bandeau *Saut* commence par une rupture de
  continuité déclarée : bateau, train de nuit, ou correspondance.
- **Après un saut, la ville d'arrivée est jouée comme première gare du
  chapitre suivant** — sauf si elle a déjà été jouée, auquel cas elle n'est
  qu'un point de départ. C'est ce qui évite qu'un débarquement n'échappe au
  ruban.

> ⚠️ **Les listes de gares sont des propositions de tracé, pas des fiches.**
> Chaque gare à écrire doit encore passer le §0 de `tools/AUTHORING-STATIONS.md`
> — **au moins 3 directions réelles et 3-4 quais**. Une candidate qui n'a que
> deux directions ne s'invente pas : on prend la gare voisine, ou on redécoupe
> le chapitre (voir [[r3-contre-plancher-trois-directions]] : Sète et Bar-le-Duc
> ont déjà été refusées pour cette raison).
>
> **Refusées le 26 août 2026, chapitre 57** (numéroté 58 avant la fusion des
> chapitres 46 et 47) : Pfaffenhofen (Munich/Ingolstadt),
> Kinding et Allersberg (Nuremberg/Ingolstadt) — deux directions chacune. Les
> deux dernières sont des haltes de la ligne à grande vitesse de 2006, bâties
> pour que des trains passent à 300 km/h à côté d'elles : il n'y a rien à y
> aiguiller. Le chapitre a donc quitté la LGV pour la **ligne classique par
> Treuchtlingen**, qui offre de vrais nœuds. Pfaffenhofen reste un point de
> passage de la ligne M-IN dans `data/places.js`.
>
> **Refusées le 26 août 2026, chapitres 46 et 47 — depuis FUSIONNÉS en 46** :
> Modane
> (Saint-Jean-de-Maurienne / Bardonnèche), Saint-Jean-de-Maurienne (Chambéry /
> Modane), Meximieux-Pérouges (La Valbonne / Ambérieu) et Seyssel-Corbonod
> (Culoz / Bellegarde) — **deux directions chacune**, vérifié en source. Ce
> sont des gares de vallée sur une ligne unique : la Maurienne pour les deux
> premières, la ligne de Lyon à Genève pour les deux autres. Modane est même un
> terminus de ligne prolongé par le tunnel du Fréjus — un point de passage
> international, pas un carrefour.
>
> **Conséquence, à trancher.** Les deux chapitres ne tiennent plus tels quels :
>
> - **46 Le Fréjus** survit à cinq gares — Bussoleno · Chambéry ✓ ·
>   Aix-les-Bains ✓ · Ambérieu ✓ · **Lyon Part-Dieu** ✓. R3 est tenue (5 gares)
>   et R5 aussi : Bussoleno – Chambéry fait **107 km** à vol d'oiseau, sous le
>   seuil de 250. Le trou saute toute la Maurienne, ce qui se défend — c'est un
>   tunnel de treize kilomètres et une vallée sans nœud.
> - **47 Le Bugey** ne survit PAS : il tombe à Culoz ✓ · Bellegarde ✓ ·
>   **Genève** ✓, soit **trois gares** contre cinq exigées par R3. Aucune
>   candidate de secours sur ce corridor : entre Lyon et Genève, seules
>   Ambérieu, Culoz et Bellegarde ont trois directions, et Ambérieu est déjà
>   prise par le chapitre 46.
>
> **Bourg-en-Bresse a été écrite le 27 août 2026** — cinq directions réelles
> (Lyon, Ambérieu, Mâcon, Bellegarde par le Haut-Bugey, Besançon par Mouchard),
> enregistrée et verte. Elle ne suffit PAS à sauver le chapitre 47, contrairement
> à ce qui était espéré ici : le corridor de Turin à Genève ne compte que
> **neuf gares qualifiées** en tout, et aucun découpage en deux chapitres ne
> donne cinq gares à chacun.
>
> | découpage | n | R3 |
> |---|---|---|
> | 46 = Bussoleno · Chambéry · Aix · Ambérieu · **Lyon** | 5 | ✓ |
> | 47 = Bourg · Bellegarde · **Genève** | 3 | ✗ |
> | 47 = Ambérieu · Bourg · Bellegarde · **Genève** (46 tombe à 4) | 4 | ✗ |
> | 47 = Culoz · Bellegarde · **Genève** | 3 | ✗ |
>
> **FUSION TRANCHÉE le 27 août 2026**, et c'est R7 qui a choisi l'itinéraire.
> Deux fusions étaient possibles, la sinuosité les départage :
>
> | itinéraire | gares | km | sinuosité | |
> |---|---|---|---|---|
> | par **Culoz** : Bussoleno · Chambéry · Aix-les-Bains · Culoz · Bellegarde · **Genève** | 6 | 197 | **1,38** | ✓ |
> | par le **Haut-Bugey** : … Ambérieu · Bourg-en-Bresse · Bellegarde · **Genève** | 7 | 277 | **1,95** | ✗ R7 |
>
> Le Haut-Bugey remonte vers Bourg avant de redescendre sur Bellegarde : le
> ruban y ferait un crochet de 80 km pour rien. Le chapitre 46 passe donc par
> **Culoz**, et il coûte trois gares au ruban — **Lyon Part-Dieu**, **Ambérieu**
> et **Bourg-en-Bresse**, cette dernière écrite le jour même. Toutes trois
> restent au catalogue et rejoignent la réserve des fiches que le ruban ne
> traverse pas ; Lyon, grande gare, a sa place ailleurs.

---

## Acte I — Les Îles

*De Cork au tunnel sous la Manche* — 18 chapitres, **111 gares** (22 déjà écrites, 89 à écrire).

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 1 | La ligne du Sud | Mallow · Limerick Junction · Thurles · Portlaoise · Kildare · **Dublin Heuston** | 6 |
| 2 | L'Enterprise | Drogheda · Dundalk · Newry · Portadown · Lisburn · **Belfast Lanyon Place** | 6 |
| | ⤳ **Saut (mer)** | *Le North Channel — le ferry de Belfast à Cairnryan* | |
| 3 | Les Lowlands | Stranraer · Girvan · Ayr · Troon · Kilmarnock · Paisley · **Glasgow Central** ✓ | 7 |
| 4 | La Highland Main Line | Stirling ✓ · Perth ✓ · Pitlochry · Blair Atholl · Kingussie · Aviemore · **Inverness** | 7 |
| 5 | Le Moray Firth | Nairn · Forres · Elgin · Keith · Huntly · Inverurie · Dyce · **Aberdeen** ✓ | 8 |
| 6 | La côte des Grampians | Stonehaven · Montrose · Arbroath · Dundee · Leuchars · Kirkcaldy · Inverkeithing · **Edinburgh Waverley** ✓ | 8 |
| 7 | La côte de Northumbrie | Dunbar · Berwick-upon-Tweed · Alnmouth · Morpeth · **Newcastle** ✓ | 5 |
| 8 | La côte Est | Durham · Darlington · Northallerton · York ✓ · **Leeds** ✓ | 5 |
| 9 | Le Yorkshire noir | Wakefield · Pontefract · Doncaster ✓ · Rotherham · **Sheffield** ✓ | 5 |
| 10 | La vallée de Hope | Dore · Hathersage · Edale · Chinley · New Mills · Stockport · **Manchester Piccadilly** ✓ | 7 |
| 11 | La première ligne du monde | Salford · Eccles · Newton-le-Willows · St Helens · Huyton · **Liverpool Lime Street** ✓ | 6 |
| 12 | Le West Coast | Runcorn · Crewe ✓ · Stafford · Wolverhampton · **Birmingham New Street** ✓ | 5 |
| 13 | Les Marches galloises | Bromsgrove · Worcester · Hereford · Abergavenny · Pontypool · **Cardiff Central** ✓ | 6 |
| 14 | Le tunnel de la Severn | Newport · Caldicot · Severn Tunnel Junction · Pilning · Filton Abbey Wood · **Bristol Temple Meads** ✓ | 6 |
| 15 | La Riviera anglaise | Taunton · Exeter St Davids ✓ · Newton Abbot · Totnes · Plymouth ✓ · Truro · **Penzance** | 7 |
| | ⤳ **Saut (nuit)** | *Le Night Riviera — le train de nuit de Penzance remonte à Bristol* | |
| 16 | Le Wessex | Bath Spa · Trowbridge · Westbury · Salisbury ✓ · Romsey · **Southampton Central** ✓ | 6 |
| 17 | Le South Western | Winchester · Basingstoke · Woking · Clapham Junction · **London Waterloo** ✓ | 5 |
| 18 | Le tunnel | Stratford International · Ebbsfleet · Ashford · Calais-Fréthun · Hazebrouck · **Lille-Europe** ✓ | 6 |

## Acte II — La France atlantique

*De la Manche aux Pyrénées* — 7 chapitres, **41 gares** (14 déjà écrites, 27 à écrire).

> ⚠️ **Trois candidates refusées le 27 août 2026**, toutes pour le même motif :
> Rochefort, Marmande et Jonzac sont d'ANCIENNES gares de bifurcation dont la
> branche a fermé — 1954, 1971 et deux gares voisines closes. Il ne leur reste
> que deux directions. Le motif est désormais décrit au §0 de
> `tools/AUTHORING-STATIONS.md` (« le piège n° 1 »).
>
> **Redécoupage tranché le 28 août 2026** (option A, décision de Vincent),
> après vérification de sept candidates. La Réole, Moissac et Royan sont
> tombées au même §0 ; le corridor Bordeaux–Toulouse n'a aucune bifurcation
> vivante. Le chapitre 23 passe par **Niort** (l'intérieur), et le 24 devient
> **« Le Périgord et la Garonne »** : Libourne · Périgueux · Agen · Montauban
> · Toulouse, par la ligne de l'Agenais. Angoulême et Coutras restent en
> réserve documentée. Trois fiches nouvelles (Niort, Libourne, Périgueux),
> écrites et brevetées le jour même.

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 19 | L'Étoile du Nord | Douai ✓ · Arras ✓ · Amiens ✓ · Creil ✓ · **Paris-Nord** ✓ | 5 |
| 20 | La Normandie | Mantes-la-Jolie · Évreux · Bernay · Lisieux · **Caen** | 5 |
| 21 | Le Cotentin et la baie | Bayeux · Saint-Lô · Avranches · Pontorson · Dol-de-Bretagne · **Rennes** ✓ | 6 |
| 22 | La Bretagne intérieure | Bruz · Messac · Redon · Savenay · **Nantes** ✓ | 5 |
| 23 | Le littoral atlantique | La Roche-sur-Yon ✓ · La Rochelle ✓ · ~~Rochefort~~ Niort ✓ · Saintes ✓ · ~~Jonzac~~ · **Bordeaux Saint-Jean** ✓ | 5 |
| 24 | Le Périgord et la Garonne | ~~La Réole~~ Libourne ✓ · ~~Marmande~~ Périgueux ✓ · Agen ✓ · ~~Moissac~~ · Montauban ✓ · **Toulouse Matabiau** ✓ | 5 |
| 25 | Le piémont pyrénéen | Saint-Gaudens · Tarbes · Pau · Orthez · Bayonne · Hendaye · Irún · **Bilbao Abando** | 8 |

## Acte III — L'Ibérie

*La grande boucle de la péninsule* — 10 chapitres, **65 gares** (3 déjà écrites, 62 à écrire).

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 26 | La Castille | Miranda de Ebro · Burgos · Palencia · Valladolid · Ávila · **Madrid-Chamartín** | 6 |
| 27 | L'Estrémadure | Talavera de la Reina · Navalmoral · Cáceres · Mérida · Badajoz · Elvas · Entroncamento · **Lisbonne Santa Apolónia** | 8 |
| 28 | La côte d'Argent | Azambuja · Santarém · Pombal · Coimbra · Aveiro · Espinho · **Porto Campanhã** | 7 |
| 29 | La Galice | Nine · Valença · Vigo · Ourense · Zamora · Medina del Campo · **Madrid-Atocha** | 7 |
| 30 | L'Andalousie | Aranjuez · Alcázar de San Juan · Ciudad Real · Puertollano · Cordoue · **Séville Santa Justa** | 6 |
| 31 | La Bétique | Utrera · Marchena · Osuna · Bobadilla · Antequera · **Malaga María Zambrano** | 6 |
| 32 | Le Levant | Grenade · Guadix · Almería · Lorca · Murcie · Alicante · **Valence-Nord** | 7 |
| 33 | La ligne de Teruel | Sagonte · Segorbe · Caudiel · Teruel · Calamocha · **Saragosse-Delicias** | 6 |
| 34 | L'Èbre | Lérida · Reus · Tarragone · Vilanova i la Geltrú · **Barcelone-Sants** | 5 |
| 35 | Le Roussillon | Gérone · Figueres · Portbou · Perpignan · Narbonne ✓ · Béziers ✓ · **Montpellier-Saint-Roch** ✓ | 7 |

## Acte IV — Le Midi et l'Italie

*De la Camargue à la Sicile, et retour par le Pô* — 10 chapitres, **65 gares** (6 déjà écrites, 59 à écrire).

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 36 | La Camargue | Nîmes ✓ · Tarascon ✓ · ~~Arles~~ Avignon ✓ · Miramas ✓ · **Marseille Saint-Charles** ✓ | 5 |
| 37 | La Riviera | Toulon ✓ · ~~Saint-Raphaël~~ · Cannes ✓ · Nice ✓ · ~~Monaco~~ · Vintimille ✓ · ~~San Remo~~ · Savone ✓ · **Gênes Piazza Principe** ✓ | 6 |
| 38 | La Tyrrhénienne | La Spezia ✓ · Pise ✓ · ~~Livourne~~ Campiglia Marittima ✓ · Grosseto ✓ · ~~Civitavecchia~~ · **Rome Termini** ✓ | 5 |
| 39 | La Campanie | ~~Latina~~ Ciampino ✓ · ~~Fondi~~ Campoleone ✓ · ~~Formia~~ · ~~Minturno~~ · Villa Literno ✓ · Caserte ✓ · **Naples Centrale** ✓ | 5 |
| 40 | Le train qui prend le bateau | Salerne ✓ · ~~Sapri~~ · Paola ✓ · Lamezia Terme ✓ · Villa San Giovanni ✓ · Messine ✓ · ~~Cefalù~~ Termini Imerese ✓ · **Palerme Centrale** ✓ | 7 |
| | ⤳ **Saut (nuit)** | *Le Palerme–Naples de nuit — le ferry de Messine dans l'autre sens* | |
| 41 | La Lucanie | Battipaglia ✓ · Potenza ✓ · Metaponto ✓ · Tarente ✓ · ~~Gioia del Colle~~ · **Bari Centrale** ✓ | 5 |
| 42 | L'Adriatique | ~~Barletta~~ · Foggia ✓ · ~~Termoli~~ San Severo ✓ · Pescara ✓ · Ancône ✓ · Rimini ✓ · **Bologne Centrale** ✓ | 6 |
| 43 | La Vénétie | Ferrare ✓ · Rovigo ✓ · Padoue ✓ · Mestre ✓ · **Venise Santa Lucia** ✓ | 5 |
| 44 | La plaine lombarde | Vicence ✓ · Vérone ✓ · ~~Peschiera~~ · ~~Desenzano~~ · Brescia ✓ · Treviglio ✓ · **Milan Centrale** ✓ | 5 |
| 45 | Le Piémont | Rho ✓ · ~~Magenta~~ · Novare ✓ · Verceil ✓ · Chivasso ✓ · **Turin Porta Nuova** ✓ | 5 |

## Acte V — Les Alpes, le Rhin et la Germanie

*Du Fréjus à la Baltique, le cœur écrit du catalogue* — 15 chapitres,
**86 gares, TOUTES ÉCRITES**. C'est le premier acte complet du ruban.

Achevé le 27 août 2026 par Bussoleno, qui ouvre au passage le catalogue à
l'**Italie**. Quatre candidates ont été **refusées** en chemin par le §0 —
Modane, Saint-Jean-de-Maurienne, Meximieux, Seyssel, deux directions chacune
(encadré plus haut) — et les chapitres 46 et 47 ont été **fusionnés** en
conséquence, R7 départageant les deux itinéraires possibles.

Bussoleno se raccorde **directement à Chambéry** (ligne L920) : les deux gares
que le rail met entre elles sont justement les deux refusées, et un point de
passage ne porte pas l'atteignabilité — `js/network.js` ne relie deux gares
dans `.to` que si elles sont voisines directes. Modane, Bardonnèche, Suse et
Saint-Jean-de-Maurienne restent des lieux dans `data/places.js`, pour que la
carte dessine la vallée sans que le ruban prétende s'y arrêter.

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 46 | Le Fréjus et le Bugey | Bussoleno ✓ · Chambéry ✓ · Aix-les-Bains ✓ · Culoz ✓ · Bellegarde ✓ · **Genève-Cornavin** ✓ | 6 |
| 47 | Le Plateau suisse | Lausanne ✓ · Fribourg ✓ · Berne ✓ · Olten ✓ · Aarau ✓ · **Zurich HB** ✓ | 6 |
| 48 | Le Rhin supérieur | Bâle ✓ · Mulhouse ✓ · Colmar ✓ · Sélestat ✓ · **Strasbourg** ✓ | 5 |
| 49 | La Lorraine | Sarrebourg ✓ · Nancy ✓ · Metz ✓ · Thionville ✓ · Bettembourg ✓ · **Luxembourg** ✓ | 6 |
| 50 | L'Ardenne | Arlon ✓ · Libramont ✓ · Marloie ✓ · Namur ✓ · Ottignies ✓ · **Bruxelles-Midi** ✓ | 6 |
| 51 | Le Benelux | Malines ✓ · Anvers ✓ · Roosendaal ✓ · Dordrecht ✓ · Rotterdam ✓ · **Amsterdam Centraal** ✓ | 6 |
| 52 | La Basse-Saxe | Amersfoort ✓ · Deventer ✓ · Hengelo ✓ · Rheine ✓ · Osnabrück ✓ · **Hanovre Hbf** ✓ | 6 |
| 53 | La Ruhr | Minden ✓ · Bielefeld ✓ · Hamm ✓ · Hagen ✓ · Wuppertal ✓ · **Cologne Hbf** ✓ | 6 |
| 54 | Le Rhin romantique | Bonn ✓ · Coblence ✓ · Bingen ✓ · Mayence ✓ · Wiesbaden · **Francfort Hbf** ✓ | 6 |
| 55 | Le Neckar | Darmstadt · Mannheim ✓ · Heidelberg · Bruchsal · Vaihingen · **Stuttgart Hbf** ✓ | 6 |
| 56 | La Souabe | Plochingen ✓ · Ulm ✓ · Günzburg ✓ · Augsbourg ✓ · **Munich Hbf** ✓ | 5 |
| 57 | La Bavière | Dachau ✓ · Ingolstadt ✓ · Treuchtlingen ✓ · Roth ✓ · **Nuremberg Hbf** ✓ | 5 |
| 58 | La Franconie et la Thuringe | Bamberg ✓ · Lichtenfels ✓ · Saalfeld ✓ · Erfurt ✓ · Weimar ✓ · Naumbourg ✓ · **Leipzig Hbf** ✓ | 7 |
| 59 | La marche de Brandebourg | Halle ✓ · Bitterfeld ✓ · Wittenberg ✓ · Jüterbog ✓ · **Berlin Hbf** ✓ | 5 |
| 60 | Le Mecklembourg | Neustrelitz ✓ · Rostock ✓ · Bad Kleinen ✓ · Schwerin ✓ · **Hambourg Hbf** ✓ | 5 |

## Acte VI — Le Nord

*Du Jutland au golfe de Finlande* — 8 chapitres, **57 gares** (0 déjà écrites, 57 à écrire).

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 61 | Le Jutland | Neumünster · Rendsburg · Flensbourg · Padborg · Kolding · Odense · **Copenhague H** | 7 |
| 62 | L'Øresund | Malmö · Lund · Helsingborg · Halmstad · Varberg · Kungsbacka · **Göteborg Central** | 7 |
| 63 | Le Bohuslän | Trollhättan · Öxnered · Ed · Halden · Sarpsborg · Moss · **Oslo Sentralstasjon** | 7 |
| 64 | Le Bergensbanen | Hønefoss · Ål · Geilo · Finse · Myrdal · Voss · **Bergen** | 7 |
| | ⤳ **Saut (nuit)** | *Le train de nuit du Bergensbanen — Bergen redescend sur Oslo* | |
| 65 | Le Värmland | Lillestrøm · Kongsvinger · Arvika · Karlstad · Kristinehamn · Örebro · Västerås · **Stockholm Central** | 8 |
| | ⤳ **Saut (mer)** | *Le ferry de l'archipel — Stockholm à Turku, une nuit entre vingt mille îles* | |
| 66 | La Finlande du Sud | Turku · Salo · Karjaa · Lohja · Espoo · Pasila · **Helsinki** | 7 |
| | ⤳ **Saut (mer)** | *Le golfe de Finlande — Helsinki à Tallinn, deux heures de mer* | |
| 67 | La Livonie | Tallinn · Tapa · Tartu · Valga · Valmiera · Cēsis · Sigulda · **Riga** | 8 |
| 68 | La Sémigalie | Jelgava · Joniškis · Šiauliai · Radviliškis · Kaunas · **Vilnius** | 6 |

## Acte VII — La Baltique et la Bohême

*De la Lituanie à Vienne par la Pologne* — 9 chapitres, **53 gares** (0 déjà écrites, 53 à écrire).

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 69 | La Ruthénie blanche | Kena · Gudogaï · Maladzetchna · Smaliavitchy · **Minsk-Pasajyrski** | 5 |
| 70 | La Polésie | Stoubtsy · Baranavitchy · Ivatsevitchy · Biaroza · **Brest-Tsentralny** | 5 |
| 71 | La Mazovie | Terespol · Biała Podlaska · Łuków · Siedlce · Mińsk Mazowiecki · **Varsovie Centrale** | 6 |
| 72 | La Vistule | Nasielsk · Ciechanów · Działdowo · Iława · Malbork · Tczew · **Gdańsk Główny** | 7 |
| 73 | La Cujavie | Laskowice · Bydgoszcz · Inowrocław · Gniezno · **Poznań Główny** | 5 |
| 74 | La Grande-Pologne | Kościan · Leszno · Rawicz · Żmigród · Oborniki Śląskie · **Wrocław Główny** | 6 |
| 75 | La Silésie | Oława · Brzeg · Opole · Gliwice · Katowice · **Cracovie Główny** | 6 |
| 76 | La Moravie | Oświęcim · Bohumín · Ostrava · Olomouc · Pardubice · Kolín · **Prague hlavní nádraží** | 7 |
| 77 | La Bohême | Benešov · Havlíčkův Brod · Brno · Břeclav · Hohenau · **Vienne Hbf** | 6 |

## Acte VIII — Les Alpes orientales et la Dalmatie

*De Vienne à la Pannonie par la mer Adriatique* — 6 chapitres, **38 gares** (0 déjà écrites, 38 à écrire).

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 78 | Le Semmering | Wiener Neustadt · Semmering · Bruck an der Mur · Graz · Maribor · Celje · **Ljubljana** | 7 |
| 79 | La Save | Zidani Most · Sevnica · Brežice · Dobova · Zaprešić · **Zagreb Glavni** | 6 |
| 80 | La Dalmatie | Karlovac · Ogulin · Gospić · Knin · Perković · **Split** | 6 |
| | ⤳ **Saut (mer)** | *Le littoral dalmate — le bateau côtier de Split à Ploče* | |
| 81 | La Neretva | Ploče · Metković · Čapljina · Mostar · Konjic · Pazarić · **Sarajevo** | 7 |
| 82 | La Bosnie | Zenica · Doboj · Šamac · Vinkovci · Šid · **Belgrade Centar** | 6 |
| 83 | La Pannonie | Novi Sad · Subotica · Kelebia · Kiskunhalas · Kecskemét · **Budapest Keleti** | 6 |

## Acte IX — L'Est et l'Orient

*Des Carpates au Bosphore* — 11 chapitres, **70 gares** (0 déjà écrites, 70 à écrire).

| # | Chapitre | Gares, dans l'ordre du rail | n |
|---|---|---|---|
| 84 | Les Carpates | Szolnok · Debrecen · Nyíregyháza · Záhony · Tchop · Moukatchevo · Stryï · **Lviv** | 8 |
| 85 | La Volhynie | Ternopil · Khmelnytskyï · Vinnytsia · Kazatyn · Fastiv · **Kyiv-Passajyrskyï** | 6 |
| 86 | La Sloboda | Yagotyn · Poltava · Krasnohrad · Merefa · **Kharkiv-Passajyrskyï** | 5 |
| 87 | Le Donets | Lozova · Pavlohrad · Synelnykove · Novomoskovsk · **Dnipro-Holovnyï** | 5 |
| 88 | La steppe | Piatykhatky · Znamianka · Pomichna · Podilsk · Rozdilna · **Odessa-Holovna** | 6 |
| 89 | La Bessarabie | Koutchourhan · Tiraspol · Bender · Căinari · **Chișinău** | 5 |
| 90 | La Moldavie | Ungheni · Iași · Roman · Bacău · Adjud · Buzău · Ploiești · **Bucarest Nord** | 8 |
| 91 | Le Danube | Giurgiu · Roussé · Gorna Oriakhovitsa · Pleven · Mezdra · **Sofia** | 6 |
| 92 | La Macédoine | Pernik · Blagoevgrad · Sandanski · Koulata · Sidirokastro · **Thessalonique** | 6 |
| 93 | La Thessalie | Katerini · Larissa · Palaiofarsalos · Lianokladi · Livadiá · **Athènes** | 6 |
| | ⤳ **Saut (nuit)** | *Le train de nuit de Thessalie — Athènes remonte sur Thessalonique* | |
| 94 | L'Express d'Orient | Serrès · Drama · Xanthi · Komotini · Alexandroúpoli · Pythio · Edirne · Çerkezköy · **Istanbul Sirkeci** | 9 |

---

## Les huit sauts

Il n'existe pas de parcours continu qui traverse toute l'Europe sans repasser
nulle part (pas de parcours hamiltonien — mesuré au lot 2). Le ruban assume
donc huit ruptures, toutes **entre deux chapitres**, jamais à l'intérieur (R5),
et toutes **montrées** au joueur.

| # | Saut | Mode | Pourquoi il est là |
|---|---|---|---|
| 1 | Belfast → Cairnryan | mer | L'Irlande est une île et le ruban doit rejoindre l'Écosse. |
| 2 | Penzance → Bristol | nuit | La Cornouailles est un cul-de-sac : on n'en sort qu'en refaisant la voie. Le Night Riviera existe pour ça. |
| 3 | Palerme → Naples | nuit | La Sicile est un cul-de-sac. Le train de nuit reprend le ferry de Messine dans l'autre sens. |
| 4 | Bergen → Oslo | nuit | Le Bergensbanen ne va nulle part au-delà de Bergen. |
| 5 | Stockholm → Turku | mer | Aucune voie ne fait le tour du golfe de Botnie à une longueur acceptable (R7 : sinuosité 4,5). |
| 6 | Helsinki → Tallinn | mer | Deux heures de golfe, aucun rail. |
| 7 | Split → Ploče | mer | La voie Split–Sarajevo par Knin et Bihać n'est plus exploitée ; la ligne réelle vers Mostar part de Ploče. |
| 8 | Athènes → Thessalonique | nuit | La Grèce continentale est une impasse ferroviaire vers le sud. |

Chaque saut est **une transition, jamais une punition ni une récompense** :
une animation de trajet sur la carte, une phrase, et un geste pour passer.

## Ce qui reste en réserve

### Les 111 fiches déjà écrites que le ruban ne traverse pas

Elles ne sont pas perdues : ce sont les gares d'**allongement** — le ruban
s'étend par le bout, ou un chapitre se redécoupe pour les prendre.

- **allemagne** (41) : aachen, aschaffenburg, bebra, brandenburg, braunschweig, bremen, buchloe, celle, dortmund, dresden, duisburg, dusseldorf, essen, freiburg, fulda, furth, gemunden, gottingen, hanau, harburg, horb, karlsruhe, kassel, kiel, lindau, lubeck, luneburg, magdeburg, memmingen, munster, offenburg, potsdam, rastatt, regensburg, saarbrucken, singen, treuchtlingen, trier, tuttlingen, uelzen, wurzburg
- **belgique** (24) : aarschot, ath, audenarde, bruges, charleroi, courtrai, deinze, denderleeuw, dinant, enghien, gand, hal, hasselt, herentals, lalouviere, landen, liege, lokeren, louvain, mons, mouscron, termonde, tournai, verviers
- **france** (23) : angers, angouleme, avignon, carcassonne, chalon, chalons, chartres, clermont-ferrand, dijon, grenoble, laroche, le-mans, limoges, macon, orleans, paris-est, paris-lyon, paris-montparnasse, poitiers, reims, tours, valence, vierzon
- **luxembourg** (5) : esch-sur-alzette, ettelbruck, kautenbach, petange, rodange
- **royaume-uni** (15) : brighton, cambridge, carlisle, chester, derby, euston, kings-cross, leicester, norwich, nottingham, oxford, paddington, peterborough, preston, reading
- **suisse** (3) : schaffhausen, stgallen, winterthur

### Les grandes gares laissées de côté

- **Tirana.** L'Albanie n'a plus de service voyageurs digne d'un niveau, et
  son seul lien crédible est le ferry de Bari. Écartée **volontairement** :
  un jeu « ancré dans la géographie ferroviaire réelle » ne s'invente pas un
  réseau. À reprendre si la ligne Durrës–Tirana rouvre.
- **Les branches non parcourues** de villes traversées : Newcastle–Londres par
  la côte Est, Paris–Lyon, Paris–Strasbourg, Bordeaux–Bilbao par la côte,
  Montpellier–Toulouse, Cologne–Hambourg par la Ruhr, Hanovre–Berlin,
  Munich–Vienne, Berlin–Prague, Venise–Ljubljana, Zurich–Milan,
  Göteborg–Stockholm, Varsovie–Cracovie… Une trentaine de tracés réels
  entièrement disponibles pour la version 2 du ruban.

---

## L'équilibre des actes

| Acte | Chapitres | Gares | Fiches à écrire |
|---|---:|---:|---:|
| I — Les Îles | 18 | 111 | 89 |
| II — La France atlantique | 7 | 41 | 27 |
| III — L'Ibérie | 10 | 65 | 62 |
| IV — Le Midi et l'Italie | 10 | 65 | 59 |
| V — Les Alpes, le Rhin et la Germanie | 16 | 92 | 11 |
| VI — Le Nord | 8 | 57 | 57 |
| VII — La Baltique et la Bohême | 9 | 53 | 53 |
| VIII — Les Alpes orientales et la Dalmatie | 6 | 38 | 38 |
| IX — L'Est et l'Orient | 11 | 70 | 70 |
| **Total** | **95** | **592** | **466** |

L'écart entre le plus court acte (VIII, 6 chapitres) et le plus long (I, 18)
est de **3 pour 1**. C'est la limite de l'acceptable : au-delà, une région se
sent deux fois plus longue qu'une autre et le voyage traîne.

**Conséquence sur R4.** La règle actuelle — « une zone compte 3 à 6
chapitres » — a été écrite pour un ruban de lancement de 16 chapitres. Elle
est cassée par un ruban de 95. Elle doit devenir : **une zone compte 6 à 20
chapitres, et l'écart entre la plus courte et la plus longue reste sous 3
pour 1.** L'Acte I est à la limite haute et gagnerait à céder l'Irlande et
l'Écosse à un acte séparé si le ruban s'allonge encore.

## La rampe de difficulté

Le ruban a **une seule courbe** (§2.5), en dents de scie : chaque chapitre
monte vers sa grande gare, et le plancher des chapitres monte par paliers le
long du ruban. Découpage proposé, à mesurer en headless (question ouverte n° 3
du document de design) :

| Chapitres | Plancher | Grande gare d'arrivée | Ce que ça donne |
|---|---|---|---|
| 1 – 12 (Îles, Irlande et Écosse) | 1 | 2 puis 3 | l'apprentissage : R9 est tenue, Cork ouvre en difficulté 1 |
| 13 – 25 (Angleterre, France atlantique) | 2 | 3 | Londres et Paris sont les premiers vrais carrefours |
| 26 – 45 (Ibérie, Midi, Italie) | 2 puis 3 | 4 | Madrid, Rome, Milan : le régime de croisière |
| 46 – 61 (Alpes, Rhin, Germanie) | 3 | 4 puis 5 | le cœur écrit du catalogue, le plus dense en trafic |
| 62 – 78 (Nord, Baltique, Bohême) | 3 | 4 | des gares plus petites, un répit géographique |
| 79 – 95 (Balkans, Est, Orient) | 4 | 5 | la fin de ruban : Belgrade, Kyiv, Bucarest, Istanbul |

La difficulté voulue reste toujours **rabattue sur ce que la fiche peut
porter** (`plafondDeFlux`) : une gare de quatre quais ne portera jamais un
niveau 5, où qu'elle tombe. C'est la géométrie qui a le dernier mot, pas la
position.

## Ce que ce ruban coûte, et par où commencer

**463 fiches à écrire.** À raison d'une séance par gare, c'est le travail de
plusieurs mois — mais il est **entièrement parallélisable** (une session par
gare, un manifeste, `tools/enregistrer.mjs`) et surtout **il n'est jamais
bloquant** : le ruban est jouable dès que son début l'est. C'est tout
l'intérêt d'un fil par rapport à un graphe.

Ordre de livraison conseillé, du plus rentable au moins :

1. **Acte V est TERMINÉ** (15 chapitres, 86 gares) — le premier acte complet
   du ruban, achevé le 27 août 2026. Les Alpes, le Rhin, le Benelux et la
   Germanie n'ont plus une seule fiche à écrire. La suite passe donc à
   l'acte II.

**Douze chapitres sont jouables intégralement aujourd'hui**, sans écrire une
seule fiche — soit **68 niveaux prêts** :

| Chapitre | Trajet | Gares |
|---|---|---:|
| L'Étoile du Nord | Lille → Paris | 5 |
| Le Plateau suisse | Genève → Zurich | 6 |
| Le Rhin supérieur | Zurich → Strasbourg | 5 |
| La Lorraine | Strasbourg → Luxembourg | 6 |
| L'Ardenne | Luxembourg → Bruxelles | 6 |
| Le Benelux | Bruxelles → Amsterdam | 6 |
| La Basse-Saxe | Amsterdam → Hanovre | 6 |
| La Ruhr | Hanovre → Cologne | 6 |
| La Souabe | Stuttgart → Munich | 5 |
| La Franconie et la Thuringe | Nuremberg → Leipzig | 7 |
| La marche de Brandebourg | Leipzig → Berlin | 5 |
| Le Mecklembourg | Berlin → Hambourg | 5 |

Et deux autres tombent à **une seule gare près** : *La Camargue* (il manque
Arles) et *Le Rhin romantique* (il manque Wiesbaden). Écrire ces deux fiches
porte le tout à **14 chapitres et 79 niveaux** — de quoi jouer un ruban
complet, cohérent et continu de Genève à Hambourg, dès cette semaine.
2. **Acte II** (7 chapitres, 24 gares à écrire) : la France atlantique
   complète le noyau français.
3. **Acte I** (96 gares à écrire) : les Îles portent le début du jeu, donc la
   rampe la plus douce et les fiches les plus simples — 3 à 5 quais.
4. **Actes III, IV** : Ibérie et Italie, les deux gros blocs de recherche.
5. **Actes VI à IX** : le Nord et l'Est, entièrement à écrire.

> Le ruban se joue **dans l'ordre**, mais il peut se **livrer dans le désordre** :
> un acte complet en milieu de ruban est du contenu prêt, il attend seulement
> que le début soit écrit. Rien n'oblige à écrire de gauche à droite.

## Ce que ce document ne tranche pas

1. **Les gares elles-mêmes.** Chaque nom de cette liste est un point de
   passage réel, pas une fiche validée. Le §0 de `AUTHORING-STATIONS.md`
   (≥ 3 directions, 3-4 quais) reste l'autorité, et il en refusera.
2. **Le pas exact de la rampe** — le tableau ci-dessus est une proposition, à
   mesurer.
3. **Les noms de chapitres** croisent des marques déposées (l'Express
   d'Orient, le Night Riviera, le Bergensbanen). Question ouverte n° 8 du
   document de design : préférer les noms historiques ou des noms maison.
4. **Les collisions d'identifiants.** `valence` existe déjà comme fiche
   française (Valence, Drôme) et le ruban ajoute Valence d'Espagne :
   il faudra `valencia`. Même vigilance pour Fribourg (`freiburg` en Brisgau,
   `fribourg` en Suisse — les deux existent déjà et sont distinctes) et pour
   Cordoue, Naples, Brest (Brest-Litovsk ≠ Brest en Bretagne).
5. **Les tronçons dont le service est suspendu** : Almería–Murcie (bus de
   substitution), Sofia–Thessalonique (service interrompu), Split–Knin. Le
   tracé est réel, l'exploitation ne l'est pas toujours. À trancher : jouer la
   géographie ou l'horaire du jour.
6. **Où s'arrête l'Europe.** Le ruban finit à Istanbul Sirkeci, rive
   européenne. Aller plus loin, c'est une autre carte.

---

*Généré depuis `scratchpad/ruban.py` et vérifié par `scratchpad/verif.py`.
Au lot C, ces deux scripts deviennent `data/cartes/europe.json` et les règles
R1–R9 de `tools/carte-check.mjs`.*
