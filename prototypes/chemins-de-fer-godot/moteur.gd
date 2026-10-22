extends RefCounted
# ------------------------------------------------------------------
# LES RÈGLES DE « CHEMINS DE FER » — sans écran, déterministes.
#
# La carte est une grille carrée à 8 voisins (dessinée en octogones).
# Une voie relie deux cases voisines ; elle coûte du bois et du fer ;
# le virage est de 45° au plus par case. Un train suit un itinéraire
# (dépôt, arrêts, dépôt), recommence tout seul, ne part que s'il a le
# charbon de toute sa boucle. Les valeurs viennent de niveau.json.
#
# SIMPLIFICATION DU PROTOTYPE : un train fait demi-tour à un arrêt ou au
# dépôt (le terminus). La plaque tournante et la boucle de retournement
# sont pour plus tard. Le demi-tour n'est jamais permis en pleine voie.
# ------------------------------------------------------------------

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

var N: Dictionary
var largeur: int
var hauteur: int
var centre: Vector2i
var ville: Vector2i

var or_: int
var bois: int
var fer: int
var pierre: int = 0
var charbon: int

var connues: Dictionary = {}     # Vector2i -> true
var aretes: Dictionary = {}      # "a|b" -> true
var adj: Dictionary = {}         # Vector2i -> Array[Vector2i]
var pile: Array = []             # {a, b, cout}
var sources: Dictionary = {}     # Vector2i -> {type, produit, stock}

var loco: bool = false
var wagons: Array = []           # types
var contenus: Array = []         # {p: produit, n: int}, parallèle à wagons
var arrets: Array[Vector2i] = [] # itinéraire hors dépôt
var chemin: Array[Vector2i] = [] # boucle complète, du dépôt au dépôt
var indices_arret: Array = []    # indices de chemin où le train s'arrête

var train: Dictionary = {}       # vide = pas de train lancé
var temps: float = 0.0

# comptes pour le banc
var produit_total: float = 0.0
var produit_charbon: float = 0.0
var brule_total: int = 0
var charge_total: int = 0
var depose_total: int = 0

func _init(niveau: Dictionary) -> void:
	N = niveau
	var g: Dictionary = N["grille"]
	largeur = int(g["largeur"])
	hauteur = int(g["hauteur"])
	centre = Vector2i(int(g["centre"][0]), int(g["centre"][1]))
	ville = Vector2i(int(g["ville"][0]), int(g["ville"][1]))
	or_ = int(N["depart"]["or"])
	bois = int(N["depart"]["bois"])
	fer = int(N["depart"]["fer"])
	charbon = int(N["depart"]["charbon"])
	var r := int(g["rayon_connu"])
	for y in hauteur:
		for x in largeur:
			var c := Vector2i(x, y)
			if maxi(absi(x - centre.x), absi(y - centre.y)) <= r:
				connues[c] = true
			var t := type_case(c)
			if N["sources"].has(t):
				sources[c] = {"type": t, "produit": N["sources"][t]["produit"],
					"stock": float(N["sources"][t]["stock_max"])}

# ---------------------------------------------------------------- la carte

func type_case(c: Vector2i) -> String:
	if c == centre:
		return "depot"
	if c == ville:
		return "ville"
	var dx := c.x - centre.x
	var dy := c.y - centre.y
	var d := maxi(absi(dx), absi(dy))
	if d == 1:
		return "prairie"
	if d == 2:
		return String(N["ressources"].get("%d,%d" % [dx, dy], "friche"))
	return "terre"

func dans_grille(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < largeur and c.y < hauteur

func voisins(c: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for d in DIRS:
		var n := c + d
		if dans_grille(n):
			r.append(n)
	return r

func est_hub(c: Vector2i) -> bool:
	return c == centre or c == ville

func cle(a: Vector2i, b: Vector2i) -> String:
	var ka := "%d,%d" % [a.x, a.y]
	var kb := "%d,%d" % [b.x, b.y]
	return ka + "|" + kb if ka < kb else kb + "|" + ka

func a_voie(c: Vector2i) -> bool:
	return c == centre or (adj.has(c) and adj[c].size() > 0)

# ---------------------------------------------------------------- les voies

func angle(u: Vector2i, v: Vector2i) -> float:
	var a := absf(Vector2(u).angle_to(Vector2(v)))
	return rad_to_deg(a)

func virage_refuse(a: Vector2i, b: Vector2i) -> String:
	var max_deg: float = float(N["virage_max_deg"]) + 0.5
	if not est_hub(a) and adj.has(a) and adj[a].size() > 0:
		var bon := false
		for p in adj[a]:
			if angle(a - p, b - a) <= max_deg:
				bon = true
		if not bon:
			return "Virage trop serré à la case de départ (45° au plus)."
	if not est_hub(b) and adj.has(b) and adj[b].size() > 0:
		var bon2 := false
		for q in adj[b]:
			if angle(b - a, q - b) <= max_deg:
				bon2 = true
		if not bon2:
			return "Virage trop serré à la case d'arrivée (45° au plus)."
	return ""

func cout_voie(b: Vector2i) -> bool:
	return b != centre and not (adj.has(b) and adj[b].size() > 0)

func poser(a: Vector2i, b: Vector2i) -> String:
	if not connues.has(a) or not connues.has(b):
		return "Case inconnue : il faut l'explorer d'abord."
	if not (b - a in DIRS):
		return "Les cases ne sont pas voisines."
	if aretes.has(cle(a, b)):
		return "Cette voie existe déjà."
	var r := virage_refuse(a, b)
	if r != "":
		return r
	var cout := cout_voie(b)
	var cb: int = int(N["prix"]["voie"]["bois"])
	var cf: int = int(N["prix"]["voie"]["fer"])
	if cout and (bois < cb or fer < cf):
		return "Pas assez de matériaux : une case coûte %d bois + %d fer." % [cb, cf]
	if cout:
		bois -= cb
		fer -= cf
	aretes[cle(a, b)] = true
	if not adj.has(a): adj[a] = []
	if not adj.has(b): adj[b] = []
	adj[a].append(b)
	adj[b].append(a)
	pile.append({"a": a, "b": b, "cout": cout})
	return ""

func annuler() -> String:
	if pile.is_empty():
		return "Rien à annuler."
	if not train.is_empty():
		return "Pas de travaux pendant qu'un train roule."
	var s: Dictionary = pile.pop_back()
	aretes.erase(cle(s["a"], s["b"]))
	adj[s["a"]].erase(s["b"])
	adj[s["b"]].erase(s["a"])
	if s["cout"]:
		bois += int(N["prix"]["voie"]["bois"])
		fer += int(N["prix"]["voie"]["fer"])
	arrets.clear()
	chemin.clear()
	return ""

func explorer(c: Vector2i) -> String:
	if connues.has(c):
		return "Cette case est déjà connue."
	var ok := false
	for n in voisins(c):
		if connues.has(n):
			ok = true
	if not ok:
		return "On n'explore que les cases voisines du territoire connu."
	var p: int = int(N["prix"]["exploration"])
	if or_ < p:
		return "Pas assez d'or (%d par case)." % p
	or_ -= p
	connues[c] = true
	return ""

# ---------------------------------------------------------------- le matériel

func acheter_loco() -> String:
	if loco:
		return "Vous avez déjà une locomotive."
	var p: int = int(N["prix"]["locomotive"])
	if or_ < p:
		return "Pas assez d'or."
	or_ -= p
	loco = true
	return ""

func acheter_wagon(t: String) -> String:
	if not N["wagons"].has(t):
		return "Type de wagon inconnu."
	if wagons.size() >= int(N["locomotive"]["traction"]) or wagons.size() >= int(N["depot"]["quai"]):
		return "Le quai est plein : %d wagons au plus." % int(N["depot"]["quai"])
	var p: int = int(N["prix"]["wagon"])
	if or_ < p:
		return "Pas assez d'or."
	or_ -= p
	wagons.append(t)
	contenus.append({"p": "", "n": 0})
	return ""

func retirer_wagon() -> void:
	if not wagons.is_empty() and train.is_empty():
		wagons.pop_back()
		contenus.pop_back()

# ---------------------------------------------------------------- les trajets

# Le plus court chemin de a à b qui ne tourne jamais de plus de 45° en route.
# Le demi-tour n'est permis qu'au départ (a) : un terminus.
func chemin_entre(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var max_deg: float = float(N["virage_max_deg"]) + 0.5
	var debut := [a, -1]
	var file: Array = [debut]
	var prev: Dictionary = {}   # cle d'état -> [clé précédente, case]
	var vus: Dictionary = {}
	vus["%d,%d,-1" % [a.x, a.y]] = true
	while not file.is_empty():
		var cur: Array = file.pop_front()
		var c: Vector2i = cur[0]
		var di: int = cur[1]
		var kc := "%d,%d,%d" % [c.x, c.y, di]
		if c == b and di != -1:
			var res: Array[Vector2i] = []
			var k := kc
			while k != "":
				var parts: PackedStringArray = k.split(",")
				res.push_front(Vector2i(int(parts[0]), int(parts[1])))
				k = String(prev[k]) if prev.has(k) else ""
			return res
		for i in 8:
			var n: Vector2i = c + DIRS[i]
			if not (adj.has(c) and n in adj[c]):
				continue
			if di != -1 and angle(DIRS[di], DIRS[i]) > max_deg:
				continue
			var kn := "%d,%d,%d" % [n.x, n.y, i]
			if vus.has(kn):
				continue
			vus[kn] = true
			prev[kn] = kc
			file.append([n, i])
	var vide: Array[Vector2i] = []
	return vide

func definir_itineraire(liste: Array[Vector2i]) -> String:
	if liste.is_empty():
		return "Choisissez au moins un arrêt."
	var noeuds: Array[Vector2i] = [centre]
	for c in liste:
		if not (sources.has(c) or c == ville):
			return "Un arrêt doit être une ressource ou la ville."
		if not a_voie(c):
			return "Cet arrêt n'est pas relié par une voie."
		noeuds.append(c)
	noeuds.append(centre)
	var tout: Array[Vector2i] = []
	var idx: Array = []
	for i in noeuds.size() - 1:
		var seg := chemin_entre(noeuds[i], noeuds[i + 1])
		if seg.is_empty():
			return "Aucun chemin sans demi-tour entre %s et %s." % [noeuds[i], noeuds[i + 1]]
		if tout.is_empty():
			tout = seg
		else:
			seg.remove_at(0)
			tout.append_array(seg)
		if i < noeuds.size() - 2:
			idx.append(tout.size() - 1)
	arrets = liste.duplicate()
	chemin = tout
	indices_arret = idx
	return ""

func cases_boucle() -> int:
	return maxi(chemin.size() - 1, 0)

func carburant_boucle() -> int:
	return cases_boucle() * int(N["locomotive"]["charbon_par_case"])

func lancer() -> String:
	if not loco:
		return "Il faut une locomotive."
	if wagons.is_empty():
		return "Il faut au moins un wagon."
	if chemin.is_empty():
		return "Définissez d'abord un itinéraire."
	train = {"i": 0, "etat": "depot", "t": 0.0, "duree": 0.0, "message": ""}
	return ""

func arreter_train() -> void:
	train = {}

# ---------------------------------------------------------------- le temps

func avancer(dt: float) -> void:
	temps += dt
	for c in sources:
		var s: Dictionary = sources[c]
		var cfg: Dictionary = N["sources"][s["type"]]
		var plus: float = float(cfg["par_heure"]) / 3600.0 * dt
		var avant: float = s["stock"]
		s["stock"] = minf(float(cfg["stock_max"]), avant + plus)
		produit_total += s["stock"] - avant
		if s["produit"] == "charbon":
			produit_charbon += s["stock"] - avant
	if train.is_empty():
		return
	var reste := dt
	var garde := 0
	while reste > 0.0 and garde < 64:
		garde += 1
		reste = _etape_train(reste)

# Une étape ; rend le temps qui reste.
func _etape_train(dt: float) -> float:
	var cfg: Dictionary = N["locomotive"]
	match train["etat"]:
		"depot":
			_decharger_depot()
			var besoin := carburant_boucle()
			if depot_plein_inutile():
				train["etat"] = "attend"
				train["message"] = "Dépôt plein : le charbon n'est plus urgent, un autre train le fera descendre."
				return 0.0
			if charbon >= besoin:
				charbon -= besoin
				brule_total += besoin
				train["i"] = 0
				train["t"] = 0.0
				train["etat"] = "roule"
				train["message"] = "En route (%d de charbon pour la boucle)." % besoin
			else:
				train["etat"] = "attend"
				train["message"] = "Attend du charbon : %d au dépôt, %d pour la boucle." % [charbon, besoin]
				return 0.0
			return dt
		"attend":
			if charbon >= carburant_boucle() and not depot_plein_inutile():
				train["etat"] = "depot"
				return dt
			return 0.0
		"roule":
			var par_case: float = float(cfg["secondes_par_case"])
			train["t"] += dt
			if train["t"] < par_case:
				return 0.0
			var surplus: float = train["t"] - par_case
			train["t"] = 0.0
			train["i"] += 1
			if train["i"] >= chemin.size() - 1:
				train["i"] = chemin.size() - 1
				train["etat"] = "depot"
				return surplus
			if train["i"] in indices_arret:
				_arriver_arret(chemin[train["i"]])
			return surplus
		"charge":
			train["t"] += dt
			if train["t"] < train["duree"]:
				return 0.0
			var s: float = train["t"] - train["duree"]
			train["t"] = 0.0
			train["etat"] = "roule"
			return s
	return 0.0

# Le dépôt est plein de charbon et le train ne va que chercher du charbon :
# repartir ne ferait que brûler du carburant pour rien.
func depot_plein_inutile() -> bool:
	if charbon < int(N["depot"]["charbon_max"]):
		return false
	for c in arrets:
		if not (sources.has(c) and sources[c]["produit"] == "charbon"):
			return false
	return true

func _arriver_arret(c: Vector2i) -> void:
	var total := 0
	if sources.has(c):
		total = _charger(c)
		train["message"] = "Chargement à %s : %d unités." % [type_case(c), total]
	elif c == ville:
		total = _livrer_ville()
		train["message"] = "Livraison à la ville : %d unités." % total
	train["etat"] = "charge"
	train["t"] = 0.0
	train["duree"] = float(total) / float(N["chargement_par_seconde"])

func _charger(c: Vector2i) -> int:
	var s: Dictionary = sources[c]
	var cfg: Dictionary = N["sources"][s["type"]]
	var cap: int = int(N["wagon"]["capacite"])
	var pris := 0
	for i in wagons.size():
		if wagons[i] != cfg["wagon"]:
			continue
		var cont: Dictionary = contenus[i]
		if cont["n"] > 0 and cont["p"] != s["produit"]:
			continue
		var place: int = cap - int(cont["n"])
		var q: int = mini(place, int(floor(s["stock"])))
		if q <= 0:
			continue
		s["stock"] -= q
		cont["p"] = s["produit"]
		cont["n"] += q
		pris += q
	charge_total += pris
	return pris

func _livrer_ville() -> int:
	var tot := 0
	var dem: Dictionary = N["ville"]["demande"]
	for i in wagons.size():
		var cont: Dictionary = contenus[i]
		if cont["n"] > 0 and dem.has(cont["p"]):
			or_ += int(cont["n"]) * int(dem[cont["p"]]["prix"])
			tot += int(cont["n"])
			depose_total += int(cont["n"])
			cont["n"] = 0
			cont["p"] = ""
	return tot

func _decharger_depot() -> void:
	for i in wagons.size():
		var cont: Dictionary = contenus[i]
		if cont["n"] <= 0:
			continue
		var q: int = int(cont["n"])
		match cont["p"]:
			"charbon":
				q = mini(q, int(N["depot"]["charbon_max"]) - charbon)
				charbon += q
			"bois":
				bois += q
			"fer":
				fer += q
			"pierre":
				pierre += q
			_:
				q = 0
		cont["n"] -= q
		depose_total += q
		if cont["n"] == 0:
			cont["p"] = ""

# ---------------------------------------------------------------- pour le banc

func tout_reveler() -> void:
	for y in hauteur:
		for x in largeur:
			connues[Vector2i(x, y)] = true

func charbon_en_wagons() -> int:
	var t := 0
	for cont in contenus:
		if cont["p"] == "charbon":
			t += int(cont["n"])
	return t

func charbon_aux_mines() -> float:
	var t := 0.0
	for c in sources:
		if sources[c]["produit"] == "charbon":
			t += sources[c]["stock"]
	return t

func produit_total_charbon() -> float:
	return produit_charbon
