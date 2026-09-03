extends RefCounted
## LE RUBAN, VU DU JEU — transposition de js/ruban.js (étape 5 du portage).
##
## Une carte est un RUBAN : une suite ordonnée de gares, sans embranchement et
## sans choix. On avance d'une gare à la suivante, dans l'ordre écrit ; la
## POSITION ne se stocke pas, elle se déduit (première gare ni faite ni payée) ;
## la DIFFICULTÉ se déduit de la position, rabattue sur ce que la géométrie
## peut porter. Tout ce qui est mesuré et commenté dans js/ruban.js l'est
## encore là-bas : ce fichier transpose les formules, pas leur justification.
##
## RIEN ICI NE CONNAÎT LA SAUVEGARDE NI L'AUTOLOAD. Le prototype lit des
## globales (CARTE_COURANTE, cardOf, getProgress, getPassees) ; ici on INJECTE
## la carte, les fiches, et la progression — ce qui rend le ruban jouable dans
## un script sans scène (jeu/oracle_ruban.gd) exactement comme dans le jeu.
##
##   var r := Ruban.new(Donnees.cartes["europe"], Donnees.fiches)
##   r.stations = { "arlon": {"stars": 3, "bestDelay": 0} }   # id -> résultat
##   r.passees = []                                           # gares payées
##   r.difficulte_de_gare("namur")   # 1..5, ou 0 hors du ruban
##   r.fiche_de_service(fiche)       # la fiche telle qu'on la JOUE
##
## Les ints du prototype sont des ints ici ; les seuls arrondis sont ceux de
## JavaScript (Math.round = floor(x + 0,5)), reproduits par js_round().

# --- L'enveloppe de génération se déduit du palier (js/ruban.js, ENVELOPPES)
const ENVELOPPES := {
	1: {"nMin": 12, "nMax": 15, "gapMin": 1.62, "gapMax": 2.84, "freightCount": 1},
	2: {"nMin": 13, "nMax": 16, "gapMin": 1.81, "gapMax": 3.02, "freightCount": 2},
	3: {"nMin": 14, "nMax": 17, "gapMin": 1.71, "gapMax": 2.92, "freightCount": 3},
	4: {"nMin": 16, "nMax": 20, "gapMin": 1.59, "gapMax": 2.73, "freightCount": 4},
	5: {"nMin": 18, "nMax": 22, "gapMin": 1.52, "gapMax": 2.58, "freightCount": 5},
}
const PROFILS := [
	{"nom": "heures creuses", "rush": "plat",   "densite": 0.85, "fret": 0},
	{"nom": "pointe",         "rush": "pointe", "densite": 1.00, "fret": 0},
	{"nom": "double pointe",  "rush": "double", "densite": 1.05, "fret": 1},
	{"nom": "bourrasque",     "rush": "rafale", "densite": 1.10, "fret": 1},
	{"nom": "service tendu",  "rush": "pointe", "densite": 1.15, "fret": 2},
	{"nom": "nocturne",       "rush": "plat",   "densite": 0.95, "fret": 3},
]
# --- Le barème d'étoiles suit la difficulté : une étoile reste à 30 minutes,
# partout et pour toujours ; le diamant reste absolu.
const SEUILS := {
	1: {"trois": 12, "deux": 20, "une": 30},
	2: {"trois": 11, "deux": 20, "une": 30},
	3: {"trois": 10, "deux": 20, "une": 30},
	4: {"trois":  9, "deux": 20, "une": 30},
	5: {"trois":  8, "deux": 20, "une": 30},
}
# --- L'enveloppe de boss : deux convois de plus que le niveau 5, une rafale et
# du fret. Mesurée, pas posée (js/ruban.js).
const ENVELOPPE_BOSS := {"nMin": 20, "nMax": 24, "gapMin": 1.50, "gapMax": 2.50, "freightCount": 6, "rush": "rafale"}

var carte: Dictionary
var fiches: Dictionary          ## id -> fiche : le catalogue (cardOf)
var stations: Dictionary = {}   ## id -> {stars, bestDelay} : la progression de la carte
var passees: Array = []         ## les gares payées par la soupape

var chapitres: Array = []       ## [{id, nom, zone, rang, gares, plancher, arrivee, saut, debut, fin}]
var ordre: Array = []           ## les gares dans l'ordre du rail
var index: Dictionary = {}      ## id -> rang dans ordre
var chapitre_de: Dictionary = {}  ## id -> son chapitre (le MÊME dictionnaire que dans chapitres)


func _init(carte_: Dictionary, fiches_: Dictionary) -> void:
	carte = carte_
	fiches = fiches_
	var k := 0
	for ch in carte.get("chapitres", []):
		var c := {
			"id": ch.get("id"), "nom": ch.get("nom"), "zone": ch.get("zone"), "rang": k,
			"gares": Array(ch.get("gares", [])).duplicate(),
			"plancher": ch.get("plancher"), "arrivee": ch.get("arrivee"),
			"saut": ch.get("saut") if _vrai(ch.get("saut")) else null,
			"debut": ordre.size(),
		}
		c["fin"] = c["debut"] + c["gares"].size() - 1
		chapitres.append(c)
		for g in c["gares"]:
			# R6 : une fiche n'apparaît qu'une fois. Si la donnée en contient
			# deux, c'est la PREMIÈRE qui compte — le contrôle de carte refuse.
			if index.has(g):
				continue
			index[g] = ordre.size()
			chapitre_de[g] = c
			ordre.append(g)
		k += 1


## La vérité de JavaScript : null, false, 0 et "" sont faux, tout le reste
## (y compris un dictionnaire vide) est vrai.
static func _vrai(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	if v is String:
		return v != ""
	return true


## Math.round de JavaScript : à la demie, vers le haut.
static func js_round(x: float) -> int:
	return int(floor(x + 0.5))


# --- Lecture de la forme -----------------------------------------------------
func longueur() -> int:
	return ordre.size()


func index_de(id: String) -> int:
	return index.get(id, -1)


## "" quand l'index déborde (null en JS).
func gare_at(i: int) -> String:
	return ordre[i] if i >= 0 and i < ordre.size() else ""


## {} quand la gare n'est pas sur le ruban (null en JS).
func chapitre_de_gare(id: String) -> Dictionary:
	return chapitre_de.get(id, {})


func chapitre_at(i: int) -> Dictionary:
	return chapitre_de.get(gare_at(i), {})


func sur_le_ruban(id: String) -> bool:
	return index_de(id) >= 0


## Une gare sans fiche est « à venir » : le ruban la porte, le jeu ne la
## propose jamais.
func est_ecrite(id: String) -> bool:
	return fiches.has(id)


func fiche_de(id: String) -> Dictionary:
	var f: Variant = fiches.get(id)
	return f if f is Dictionary else {}


# --- L'état d'une gare -------------------------------------------------------
## Le résultat enregistré pour une gare, ou {} (`prog[id] || {}`).
func progression_de(id: String) -> Dictionary:
	var r: Variant = stations.get(id)
	return r if r is Dictionary else {}


## `r.stars || 0` — les nombres du JSON sont des floats, les étoiles des ints.
static func etoiles_de(r: Dictionary) -> int:
	var s: Variant = r.get("stars")
	return int(s) if (s is int or s is float) else 0


## FAITE : au moins une étoile.
func est_faite(id: String) -> bool:
	return id != "" and etoiles_de(progression_de(id)) >= 1


## PAYÉE : franchie par la soupape, en crédits. Elle laisse avancer le ruban
## et ne rapporte rien.
func est_passee(id: String) -> bool:
	return id != "" and passees.has(id)


## FRANCHIE : faite ou payée. C'est ce qui fait avancer la position.
func est_franchie(id: String) -> bool:
	return est_faite(id) or est_passee(id)


## La première gare du ruban qui n'est ni faite ni payée.
func position_courante() -> int:
	for i in ordre.size():
		if not est_franchie(ordre[i]):
			return i
	return ordre.size()


## La première gare que le ruban porte SANS fiche écrite.
func premiere_a_venir() -> int:
	for i in ordre.size():
		if not est_ecrite(ordre[i]):
			return i
	return ordre.size()


## LA GARE COURANTE. "" quand le ruban est fini, ou quand ce qui vient n'est
## pas encore écrit.
func gare_courante() -> String:
	var p := position_courante()
	if p >= ordre.size():
		return ""
	var g := gare_at(p)
	return g if est_ecrite(g) else ""


func au_bout_de_l_ecrit() -> bool:
	var p := position_courante()
	return p < ordre.size() and not est_ecrite(gare_at(p))


## TENUE : à la position courante ou avant, et écrite. Une gare tenue se
## rejoue quand on veut (c'est l'ancien « isBought »).
func est_tenue(id: String) -> bool:
	var i := index_de(id)
	return i >= 0 and i <= position_courante() and est_ecrite(id)


## Un chapitre est TERMINÉ quand toutes ses gares sont franchies.
func chapitre_termine(ch: Dictionary) -> bool:
	if ch.is_empty():
		return false
	for g in ch["gares"]:
		if not est_franchie(g):
			return false
	return true


func chapitre_courant() -> Dictionary:
	return chapitre_at(min(position_courante(), ordre.size() - 1))


## « gare 3 sur 6 » — le rang dans le chapitre, à partir de 1.
func rang_dans_chapitre(id: String) -> int:
	var ch := chapitre_de_gare(id)
	return ch["gares"].find(id) + 1 if not ch.is_empty() else 0


# --- La difficulté se déduit de la position, la géométrie a le dernier mot ---
## Ce que le flux d'une gare peut porter : le palier de quais et les
## directions, moins l'entonnoir. Une fiche absente ({}) porte 5.
static func plafond_de_flux(cfg: Dictionary) -> int:
	if cfg.is_empty():
		return 5
	var quais: int = Array(cfg.get("platforms", [])).size()
	var portals: Dictionary = cfg["portals"] if cfg.get("portals") is Dictionary else {}
	var directions := portals.size()
	var par_quais: int = 5 if quais >= 8 else 4 if quais >= 6 else 3 if quais >= 5 else max(1, quais - 1)
	var entonnoir := 0
	# `sameSidePairs` est "all", une liste de paires, ou absent : comparer un
	# Array à une String est une erreur en GDScript, d'où le test de type.
	var ssp: Variant = cfg.get("sameSidePairs")
	if not (ssp is String and ssp == "all") and not portals.is_empty():
		var g := 0
		var d := 0
		for k in portals:
			if portals[k].get("side") == "L":
				g += 1
			else:
				d += 1
		if g == 1 or d == 1:
			entonnoir = 1
	return max(1, min(5, par_quais, directions) - entonnoir)


## Le plancher d'un chapitre : celui qu'il déclare, sinon un cran tous les
## trois chapitres.
static func plancher_de_chapitre(ch: Dictionary) -> int:
	if ch.is_empty():
		return 1
	if _vrai(ch.get("plancher")):
		return max(1, min(5, int(ch["plancher"])))
	return max(1, min(4, 1 + int(floor(float(ch.get("rang", 0)) / 3.0))))


## La difficulté d'ARRIVÉE d'un chapitre : ce que sa grande gare peut porter,
## ou le plafond qu'il déclare — toujours au moins un cran au-dessus du plancher.
func arrivee_de_chapitre(ch: Dictionary) -> int:
	if ch.is_empty() or Array(ch.get("gares", [])).is_empty():
		return 5
	var gares: Array = ch["gares"]
	var fin: String = gares[gares.size() - 1]
	var haut: int
	if _vrai(ch.get("arrivee")):
		haut = min(5, int(ch["arrivee"]))
	else:
		haut = min(5, plafond_de_flux(fiche_de(fin)))
	return max(plancher_de_chapitre(ch) + 1, haut)


## La rampe part du plancher et atteint l'arrivée au dernier pas.
static func difficulte_voulue(i: int, n: int, plancher: int, arrivee: int) -> int:
	if n <= 1:
		return arrivee
	return js_round(float(plancher) + float(arrivee - plancher) * (float(i) / float(n - 1)))


## Ce que la gare portera vraiment : 1..5, ou 0 si elle n'est pas sur le
## ruban (null en JS). `cfg` vide : on lit la fiche du catalogue.
func difficulte_de_gare(id: String, cfg: Dictionary = {}) -> int:
	var ch := chapitre_de_gare(id)
	if ch.is_empty():
		return 0
	var i: int = ch["gares"].find(id)
	if i < 0:
		return 0
	var voulue := difficulte_voulue(i, ch["gares"].size(), plancher_de_chapitre(ch), arrivee_de_chapitre(ch))
	var c := cfg if not cfg.is_empty() else fiche_de(id)
	return max(1, min(voulue, plafond_de_flux(c)))


# --- L'enveloppe de génération se déduit du palier ---------------------------
## `niveau` 0 : la difficulté de la fiche, sinon 1. Ce que la fiche impose
## (`gen`) reste prioritaire, sauf les champs que le palier fixe.
static func enveloppe_de(cfg: Dictionary, niveau: int, profil: Dictionary = {}) -> Dictionary:
	var base := niveau
	if base == 0 and not cfg.is_empty():
		base = int(cfg.get("difficulty", 0)) if cfg.get("difficulty") != null else 0
	if base == 0:
		base = 1
	var n: int = max(1, min(5, base))
	var e: Dictionary = ENVELOPPES[n]
	var p: Dictionary = profil if not profil.is_empty() else PROFILS[1]
	var out: Dictionary = (cfg["gen"] as Dictionary).duplicate() if cfg.get("gen") is Dictionary else {}
	out["nMin"] = js_round(float(e["nMin"]) * float(p["densite"]))
	out["nMax"] = js_round(float(e["nMax"]) * float(p["densite"]))
	out["gapMin"] = e["gapMin"]
	out["gapMax"] = e["gapMax"]
	out["freightCount"] = max(0, int(e["freightCount"]) + int(p["fret"]))
	out["rush"] = p["rush"]
	return out


# --- Le barème d'étoiles ------------------------------------------------------
## `niveau` 0 vaut 3 (`niveau || 3`). Le dictionnaire rendu est une constante :
## dupliquer avant de le modifier.
static func seuils_de_niveau(niveau: int) -> Dictionary:
	var n := niveau if niveau != 0 else 3
	return SEUILS[max(1, min(5, n))]


## Le barème d'une fiche HORS ruban : sa difficulté de fiche, et ses `seuils`
## s'il en impose. C'est ce que seuilsDeService rend quand aucune carte n'est
## chargée — et ce que l'oracle d'enclenchement mesure.
static func seuils_de_fiche(cfg: Dictionary) -> Dictionary:
	var d := 0
	if not cfg.is_empty() and cfg.get("difficulty") != null:
		d = int(cfg["difficulty"])
	var s := seuils_de_niveau(d)
	if cfg.get("seuils") is Dictionary:
		s = s.duplicate()
		s.merge(cfg["seuils"], true)
	return s


## Le barème d'une gare telle qu'on la JOUE : celui de sa difficulté sur le
## ruban, à défaut celui de sa fiche.
func seuils_de_service(cfg: Dictionary) -> Dictionary:
	if cfg.get("seuils") is Dictionary:
		return seuils_de_fiche(cfg)
	var d := 0
	if not cfg.is_empty():
		d = difficulte_de_gare(String(cfg.get("id", "")), cfg)
		if d == 0 and cfg.get("difficulty") != null:
			d = int(cfg["difficulty"])
	return seuils_de_niveau(d)


## Les étoiles d'un service : le retard face au barème.
static func etoiles_pour(retard: float, seuils: Dictionary = {}) -> int:
	var s := seuils if not seuils.is_empty() else seuils_de_niveau(3)
	if retard < float(s["trois"]):
		return 3
	if retard < float(s["deux"]):
		return 2
	if retard < float(s["une"]):
		return 1
	return 0


# --- Le boss : la grande gare qui ferme un chapitre, à pleine difficulté -----
func est_grande_gare(id: String) -> bool:
	var ch := chapitre_de_gare(id)
	if ch.is_empty():
		return false
	var gares: Array = ch["gares"]
	return gares.size() > 0 and gares[gares.size() - 1] == id


func est_boss(id: String, cfg: Dictionary = {}) -> bool:
	return est_grande_gare(id) and difficulte_de_gare(id, cfg) == 5


func enveloppe_de_gare(id: String, cfg: Dictionary = {}) -> Dictionary:
	var d := difficulte_de_gare(id, cfg)
	var niveau := d
	if niveau == 0 and not cfg.is_empty() and cfg.get("difficulty") != null:
		niveau = int(cfg["difficulty"])
	return enveloppe_de(cfg, niveau, PROFILS[1])


## LA FICHE TELLE QU'ON LA JOUE : même géométrie, `difficulty` et `gen`
## recalculés depuis la position. Hors ruban, la fiche telle quelle.
func fiche_de_service(cfg: Dictionary) -> Dictionary:
	if cfg.is_empty():
		return cfg
	var id := String(cfg.get("id", ""))
	var d := difficulte_de_gare(id, cfg)
	if d == 0:
		return cfg
	var gen: Dictionary
	if est_boss(id, cfg):
		gen = (cfg["gen"] as Dictionary).duplicate() if cfg.get("gen") is Dictionary else {}
		gen.merge(ENVELOPPE_BOSS, true)
	else:
		gen = enveloppe_de(cfg, d, PROFILS[1])
	var out := cfg.duplicate()
	out["difficulty"] = d
	out["gen"] = gen
	return out


# --- Zones -----------------------------------------------------------------------
func zones() -> Array:
	return carte["zones"] if carte.get("zones") is Array else []


func chapitres_de_zone(zone_id: Variant) -> Array:
	var out: Array = []
	for c in chapitres:
		if c["zone"] == zone_id:
			out.append(c)
	return out


## fermee ‹ entamee ‹ traversee. Les rangs sont l'affaire de recompense.gd.
func etat_de_zone(zone_id: Variant) -> String:
	var chs := chapitres_de_zone(zone_id)
	if chs.is_empty():
		return "fermee"
	var toutes := true
	for c in chs:
		if not chapitre_termine(c):
			toutes = false
			break
	if toutes:
		return "traversee"
	for c in chs:
		for g in c["gares"]:
			if est_franchie(g):
				return "entamee"
	return "fermee"
