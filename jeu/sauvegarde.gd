extends Node
## LA SAUVEGARDE — transposition de js/store.js (étape 6 du portage).
##
## SEUL fichier qui connaît le support de stockage. Le reste du jeu lit la
## progression en synchrone depuis un cache mémoire ; le support réel est lu
## UNE fois au démarrage (charger) et réécrit à chaque changement.
##
## Sous Godot le support est `user://` : un fichier par clé, le même contenu
## que localStorage dans le prototype — la même chaîne JSON sous la même clé.
## Passer du prototype au jeu ne touche donc que _lire() et _ecrire(), comme
## `makeBackend()` le promettait (PORTAGE-GODOT.md §1).
##
## LE FORMAT EST VERSIONNÉ, ET LA RÈGLE NE CHANGE PAS : toute modification du
## format impose d'incrémenter SCHEMA_VERSION et d'écrire la migration dans
## migrer(), testée depuis une sauvegarde ancienne (tools/oracle-sauvegarde.mjs
## rejoue chaque schéma de v0 à v7 des deux côtés). Une mise à jour qui perd la
## partie d'un joueur est un bug bloquant.
##
## Autoload `Sauvegarde` (project.godot) — qui existe aussi sous --script, et
## y charge la vraie partie. Pour un essai, on instancie à la main sur un
## dossier de travail : `var s = Sauv.new(); s.dossier = "..."; s.charger()`.
##
## Correspondance avec js/store.js :
##   getProgress → get_progression · getPassees → get_passees
##   getSerie / pushSerie → get_serie / pousser_serie
##   saveResult / markTentee → enregistrer_resultat / marquer_tentee
##   getCarteCourante / setCarteCourante → get_carte_courante / set_carte_courante
##   cartesPossedees / possedeCarte / acquerirCarte → idem en français
##   getCartesEnregistrees → cartes_enregistrees · isBought → Ruban.est_tenue
##   getMuted / setMuted → get_muet / set_muet · getOnboarded → get_accueilli

const SCHEMA_VERSION := 7
## La carte de tout joueur d'avant les cartes : l'Europe, et elle est gratuite.
const CARTE_PAR_DEFAUT := "europe"
const CLE_PROGRESSION := "station-progress"
const CLE_MUET := "station-muted"
const CLE_ACCUEILLI := "station-onboarded"

## Le support : un dossier, un fichier par clé. `user://` en jeu ; l'oracle
## pose un dossier de travail.
var dossier := "user://"

var sauve: Dictionary = sauvegarde_vierge()   ## le cache mémoire, source de vérité en partie
var _muet := false
var _accueilli := false
## APERÇU SANS TRACE : la progression reste en mémoire et n'est plus écrite
## tant que ce drapeau est levé (le relevé de fin joué pour de faux).
var apercu_sans_trace := false


func _ready() -> void:
	# STATION_SAUVEGARDE=<dossier> : un support de travail pour les essais, qui
	# laisse la vraie partie (user://) tranquille.
	var d := OS.get_environment("STATION_SAUVEGARDE")
	if d != "":
		dossier = d
	charger()


# --- Le support ---------------------------------------------------------------
func _chemin(cle: String) -> String:
	return dossier.path_join(cle + (".json" if cle == CLE_PROGRESSION else ".txt"))


## La chaîne enregistrée sous une clé, ou null (comme localStorage.getItem).
func _lire(cle: String) -> Variant:
	var chemin := _chemin(cle)
	if not FileAccess.file_exists(chemin):
		return null
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return null
	var s := f.get_as_text()
	f.close()
	return s


func _ecrire(cle: String, valeur: String) -> void:
	var chemin := _chemin(cle)
	var d := chemin.get_base_dir()
	if not DirAccess.dir_exists_absolute(d):
		DirAccess.make_dir_recursive_absolute(d)
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		push_error("sauvegarde impossible : " + chemin)
		return
	f.store_string(valeur)
	f.close()


# --- Le format ----------------------------------------------------------------
static func carte_vierge() -> Dictionary:
	return {"stations": {}, "passees": [], "serie": {"n": 0, "record": 0}}


static func sauvegarde_vierge() -> Dictionary:
	return {"version": SCHEMA_VERSION, "carteCourante": CARTE_PAR_DEFAUT,
		"cartes": {CARTE_PAR_DEFAUT: carte_vierge()},
		"possedees": {CARTE_PAR_DEFAUT: "gratuite"}}


## La vérité de JavaScript : null, false, 0 et "" sont faux.
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


static func _nombre(v: Variant) -> bool:
	return v is int or v is float


## `x | 0` de JavaScript : un entier, zéro pour tout ce qui n'en est pas un.
static func _entier(v: Variant) -> int:
	if v is int:
		return v
	if v is float:
		return 0 if (is_nan(v) or is_inf(v)) else int(v)
	if v is bool:
		return 1 if v else 0
	if v is String:
		var t: String = v.strip_edges()
		if t == "":
			return 0
		return int(float(t)) if t.is_valid_float() else 0
	return 0


## La série se lit avec un défaut : « aucune série en cours » n'a pas besoin
## d'être écrit pour être vrai.
static func lire_serie(r: Variant) -> Dictionary:
	var v: Variant = r.get("serie") if r is Dictionary else null
	if not (v is Dictionary):
		return {"n": 0, "record": 0}
	return {"n": max(0, _entier(v.get("n"))), "record": max(0, _entier(v.get("record")))}


## MIGRATION : amène n'importe quel format vers le schéma courant.
##
## v6 et v7 : déjà par carte. `bought` (v6) est abandonné et rien n'est
## perdu — étoiles et records passent intacts, la position se recalcule.
## v5 et avant : une seule progression, et c'était l'Europe ; elle devient la
## progression de la carte « europe », intacte.
static func migrer(raw: Variant) -> Dictionary:
	if raw is Dictionary and _nombre(raw.get("version")) \
			and (float(raw["version"]) == 6.0 or float(raw["version"]) == 7.0) \
			and _objet(raw.get("cartes")):
		var brutes: Dictionary = _en_dictionnaire(raw["cartes"])
		var cartes := {}
		for id in brutes:
			var c: Variant = brutes[id]
			if not (c is Dictionary):
				c = {}
			cartes[id] = {
				"stations": c["stations"].duplicate() if c.get("stations") is Dictionary else {},
				"passees": c["passees"].duplicate() if c.get("passees") is Array else [],
				"serie": lire_serie(c),
			}
		var possedees: Dictionary = _en_dictionnaire(raw["possedees"]).duplicate() if _objet(raw.get("possedees")) else {}
		if not _vrai(possedees.get(CARTE_PAR_DEFAUT)):
			possedees[CARTE_PAR_DEFAUT] = "gratuite"
		var courante: Variant = raw.get("carteCourante")
		return {"version": SCHEMA_VERSION,
			"carteCourante": courante if _vrai(courante) else CARTE_PAR_DEFAUT,
			"cartes": cartes, "possedees": possedees}
	var v5 := _migrer_vers_v5(raw)
	return {"version": SCHEMA_VERSION, "carteCourante": CARTE_PAR_DEFAUT,
		"cartes": {CARTE_PAR_DEFAUT: {"stations": v5["stations"], "passees": [], "serie": v5["serie"]}},
		"possedees": {CARTE_PAR_DEFAUT: "gratuite"}}


## `typeof x === "object" && x` : un dictionnaire, ou un tableau (JavaScript
## itère ses indices comme des clés).
static func _objet(v: Variant) -> bool:
	return v is Dictionary or v is Array


static func _en_dictionnaire(v: Variant) -> Dictionary:
	if v is Dictionary:
		return v
	var d := {}
	if v is Array:
		for i in v.size():
			d[str(i)] = v[i]
	return d


## Toute sauvegarde d'avant les cartes ramenée à { stations, serie } : ce que
## v7 en garde. `bought`, `opened`, crédits et ponctualité sont abandonnés —
## le ruban n'achète plus rien, et tout le reste se déduit des records.
static func _migrer_vers_v5(raw: Variant) -> Dictionary:
	var stations: Dictionary = {}
	if raw is Dictionary:
		if raw.get("version") == null:
			stations = raw.duplicate()          # v0 : objet plat { id: {stars, bestDelay} }
		elif raw.get("stations") is Dictionary:
			stations = raw["stations"].duplicate()
	return {"stations": stations, "serie": lire_serie(raw)}


# --- Chargement unique au démarrage, AVANT toute lecture de progression ----------
func charger() -> void:
	var brut: Variant = _lire(CLE_PROGRESSION)
	var parsed: Variant = null
	if brut is String and brut != "":
		var j := JSON.new()
		if j.parse(brut) == OK:
			parsed = j.data
	sauve = migrer(parsed)
	_muet = _lire(CLE_MUET) == "1"
	_accueilli = _lire(CLE_ACCUEILLI) == "1"
	# Si la sauvegarde n'était pas déjà au schéma courant, on la réécrit migrée.
	if not (parsed is Dictionary and _nombre(parsed.get("version")) and float(parsed["version"]) == float(SCHEMA_VERSION)):
		persister()


func persister() -> void:
	if apercu_sans_trace:
		return
	_ecrire(CLE_PROGRESSION, vers_json(sauve))


## JSON.stringify de JavaScript, pas celui de Godot : ce dernier TRIE les clés
## d'un dictionnaire (mesuré le 3 septembre 2026 : `{"germanie", "europe"}`
## sort `{"europe":…,"germanie":…}`), alors que son analyseur conserve l'ordre
## du document. Une sauvegarde relue aurait donc ses cartes dans un autre
## ordre que le prototype — rien de faux, mais plus la même sauvegarde. On
## écrit soi-même, dans l'ordre d'insertion, avec les nombres entiers sans
## décimale comme en JavaScript.
static func vers_json(v: Variant) -> String:
	if v == null:
		return "null"
	if v is bool:
		return "true" if v else "false"
	if v is int:
		return str(v)
	if v is float:
		if is_nan(v) or is_inf(v):
			return "null"
		if v == floor(v) and absf(v) < 1e15:
			return str(int(v))
		var t := "%.17f" % v
		return t.rstrip("0")
	if v is String:
		return JSON.stringify(v)
	if v is Array:
		var parts: PackedStringArray = []
		for x in v:
			parts.append(vers_json(x))
		return "[" + ",".join(parts) + "]"
	if v is Dictionary:
		var parts: PackedStringArray = []
		for k in v:
			parts.append(JSON.stringify(str(k)) + ":" + vers_json(v[k]))
		return "{" + ",".join(parts) + "}"
	return JSON.stringify(str(v))


# --- La progression de la carte COURANTE ------------------------------------------
## Créée à la demande : ouvrir une carte pour la première fois ne demande
## aucune écriture préalable.
func _carte() -> Dictionary:
	var id: Variant = sauve.get("carteCourante")
	if not _vrai(id):
		id = CARTE_PAR_DEFAUT
	var cartes: Dictionary = sauve["cartes"]
	if not (cartes.get(id) is Dictionary):
		cartes[id] = carte_vierge()
	return cartes[id]


## La table { id: {stars, bestDelay} } de la carte courante — vivante.
func get_progression() -> Dictionary:
	return _carte()["stations"]


## Les tables de TOUTES les cartes. Lecture seule.
func progression_toutes_cartes() -> Array:
	var out: Array = []
	for id in sauve["cartes"]:
		var c: Variant = sauve["cartes"][id]
		out.append(c["stations"] if c is Dictionary and c.get("stations") is Dictionary else {})
	return out


## Les cartes enregistrées, avec leur id et leurs gares payées (copiées).
func cartes_enregistrees() -> Array:
	var out: Array = []
	for id in sauve["cartes"]:
		var c: Variant = sauve["cartes"][id]
		if not (c is Dictionary):
			c = {}
		out.append({"id": id,
			"stations": c["stations"] if c.get("stations") is Dictionary else {},
			"passees": c["passees"].duplicate() if c.get("passees") is Array else []})
	return out


# --- Les cartes : laquelle on joue, lesquelles on possède ---------------------------
func get_carte_courante() -> Variant:
	var id: Variant = sauve.get("carteCourante")
	return id if _vrai(id) else CARTE_PAR_DEFAUT


## Changer de carte n'efface rien : chaque carte garde sa progression.
func set_carte_courante(id: Variant) -> void:
	if not _vrai(id) or id == sauve.get("carteCourante"):
		return
	sauve["carteCourante"] = id
	_carte()
	persister()


func cartes_possedees() -> Dictionary:
	if not (sauve.get("possedees") is Dictionary):
		sauve["possedees"] = {}
	return sauve["possedees"]


func possede_carte(id: Variant) -> bool:
	return _vrai(cartes_possedees().get(id))


## Acquérir une carte : `mode` dit comment (« gratuite », « credits », « achat »).
func acquerir_carte(id: Variant, mode: Variant = null) -> bool:
	if not _vrai(id) or possede_carte(id):
		return false
	cartes_possedees()[id] = mode if _vrai(mode) else "achat"
	persister()
	return true


# --- Payée : le seul fait nouveau du schéma 7 -------------------------------------
func get_passees() -> Array:
	var c := _carte()
	if not (c.get("passees") is Array):
		c["passees"] = []
	return c["passees"]


func est_gare_payee(id: Variant) -> bool:
	return get_passees().has(id)


func payer_passage(id: Variant) -> bool:
	if not _vrai(id) or est_gare_payee(id):
		return false
	get_passees().append(id)
	persister()
	return true


# --- Les résultats ----------------------------------------------------------------------
## Une gare tentée, même ratée, laisse une trace vide de tout score.
func marquer_tentee(id: Variant) -> void:
	if not _vrai(id):
		return
	var stations: Dictionary = _carte()["stations"]
	if _vrai(stations.get(id)):
		return
	stations[id] = {"stars": 0, "bestDelay": null}
	persister()


## On ne garde que le meilleur score et le meilleur retard.
func enregistrer_resultat(id: Variant, stars: Variant, delay: Variant) -> void:
	var stations: Dictionary = _carte()["stations"]
	var cur: Variant = stations.get(id)
	if not (cur is Dictionary):
		cur = {"stars": 0, "bestDelay": null}
	var bd: Variant = cur.get("bestDelay")
	var cs: Variant = cur.get("stars")
	stations[id] = {
		"stars": max(cs if _nombre(cs) else 0, stars),      # Math.max(null, s) vaut s
		"bestDelay": delay if bd == null else min(bd, delay),
	}
	persister()


# --- La série : le seul compteur qui puisse redescendre ---------------------------------
func _serie() -> Dictionary:
	var c := _carte()
	if not (c.get("serie") is Dictionary):
		c["serie"] = {"n": 0, "record": 0}
	return c["serie"]


func get_serie() -> Dictionary:
	var s := _serie()
	return {"n": s["n"], "record": s["record"]}


## Enregistre un service. `tenu` : a-t-il atteint le seuil de la série ?
## Rend l'état avant et après, pour que le relevé sache quoi raconter.
func pousser_serie(tenu: bool) -> Dictionary:
	var s := _serie()
	var avant: Variant = s["n"]
	s["n"] = s["n"] + 1 if tenu else 0
	var battu: bool = s["n"] > s["record"]
	if battu:
		s["record"] = s["n"]
	persister()
	return {"avant": avant, "n": s["n"], "record": s["record"], "casse": (not tenu) and _vrai(avant) and float(avant) > 0.0, "battu": battu}


# --- Préférences : même support durable que la progression --------------------------------
func get_muet() -> bool:
	return _muet


func set_muet(on: bool) -> void:
	_muet = on
	_ecrire(CLE_MUET, "1" if _muet else "0")


func get_accueilli() -> bool:
	return _accueilli


func set_accueilli(on: bool) -> void:
	_accueilli = on
	_ecrire(CLE_ACCUEILLI, "1" if _accueilli else "0")
