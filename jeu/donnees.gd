extends Node
## LES DONNÉES DU JEU — chargées une fois, au démarrage.
##
## Autoload (`Donnees`). Il lit EXACTEMENT les mêmes fichiers que le prototype
## web et que les quatre contrôles Node : rien n'est recopié, rien n'est
## reformaté. C'est tout l'intérêt d'avoir posé le projet à la racine du dépôt.
##
## Ce qui est lu tel quel, sans transformation :
##   data/stations/index.json      l'ordre curé + le libellé de pays
##   data/stations/<pays>/*.json   les 401 fiches
##   data/stations/brevets.json    le niveau certifié sain par fiche
##   data/cartes/index.json + <carte>.json
##
## Et ce qui vient de `tools/vers-json.mjs`, parce que quatre fichiers du jeu
## déclarent leurs données en JavaScript et que Godot ne sait pas les lire :
##   data/derive/geo.json, lines.json, places.json, worldmap.json
## Le JS reste la source ; relancer `node tools/vers-json.mjs` régénère.
##
## RIEN N'EST SILENCIEUX ICI. Un fichier manquant ou illisible est enregistré
## dans `erreurs` et signalé — un catalogue à moitié chargé qui s'affiche quand
## même est la pire façon de découvrir un problème de chemin.

const RACINE := "res://data/"

var index: Array = []                 ## [{country, label, stations}]
var fiches: Dictionary = {}           ## id -> fiche
var brevets: Dictionary = {}          ## id -> {niveau, boss, geometrie, ...}
var pays: Dictionary = {}             ## slug -> {label, drapeau, nom}
var cartes_index: Array = []          ## [{id, nom, gratuite, fichier, sousTitre}]
var cartes: Dictionary = {}           ## id -> carte complète
var geo: Dictionary = {}
var lignes: Array = []
var lieux: Dictionary = {}

var erreurs: PackedStringArray = []
var duree_ms: int = 0


func _ready() -> void:
	charger()


func charger() -> void:
	var t0 := Time.get_ticks_msec()
	erreurs.clear()
	_charger_pays_et_fiches()
	_charger_brevets()
	_charger_cartes()
	_charger_derive()
	duree_ms = Time.get_ticks_msec() - t0

	if erreurs.is_empty():
		print("Données chargées en %d ms — %d fiches, %d brevets, %d cartes."
			% [duree_ms, fiches.size(), brevets.size(), cartes.size()])
	else:
		push_error("Chargement incomplet : %d erreur(s)." % erreurs.size())
		for e in erreurs:
			push_error("  " + e)


## Le libellé d'affichage d'un pays, à partir de son slug. Le prototype fait le
## même découpage, au même endroit unique (js/catalog.js, `paysDe`) : une fiche
## dit DE QUEL pays elle est, jamais comment l'afficher.
func pays_de(slug: String) -> Dictionary:
	return pays.get(slug, {"label": "", "drapeau": "", "nom": slug})


func fiche(id: String) -> Dictionary:
	return fiches.get(id, {})


## Le niveau maximal certifié sain d'une fiche, ou 0 si elle n'est pas brevetée.
func brevet(id: String) -> int:
	var b: Variant = brevets.get(id)
	return int(b.get("niveau", 0)) if b is Dictionary else 0


# ------------------------------------------------------------------
# Lecture
# ------------------------------------------------------------------

func _lire_json(chemin: String) -> Variant:
	if not FileAccess.file_exists(chemin):
		erreurs.append("introuvable : " + chemin)
		return null
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		erreurs.append("illisible : %s (%d)" % [chemin, FileAccess.get_open_error()])
		return null
	var brut := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(brut) != OK:
		erreurs.append("JSON invalide : %s ligne %d — %s" % [chemin, j.get_error_line(), j.get_error_message()])
		return null
	return j.data


func _charger_pays_et_fiches() -> void:
	var idx: Variant = _lire_json(RACINE + "stations/index.json")
	if not (idx is Array):
		return
	index = idx
	for bloc in index:
		var slug := String(bloc.get("country", ""))
		var label := String(bloc.get("label", "")).strip_edges()
		# Le libellé est authored « 🇬🇧 Royaume-Uni » : drapeau, espace, nom.
		var i := label.find(" ")
		pays[slug] = {
			"label": label,
			"drapeau": label.substr(0, i) if i > 0 else "",
			"nom": label.substr(i + 1) if i > 0 else label,
		}
		for id in bloc.get("stations", []):
			var f: Variant = _lire_json("%sstations/%s/%s.json" % [RACINE, slug, id])
			if f is Dictionary:
				fiches[String(id)] = f


func _charger_brevets() -> void:
	var b: Variant = _lire_json(RACINE + "stations/brevets.json")
	if b is Dictionary:
		for k in b.keys():
			if k != "_doc":
				brevets[String(k)] = b[k]


func _charger_cartes() -> void:
	var ci: Variant = _lire_json(RACINE + "cartes/index.json")
	if not (ci is Array):
		return
	cartes_index = ci
	for e in cartes_index:
		var id := String(e.get("id", ""))
		var fichier := String(e.get("fichier", id + ".json"))
		var c: Variant = _lire_json(RACINE + "cartes/" + fichier)
		if c is Dictionary:
			cartes[id] = c


func _charger_derive() -> void:
	var g: Variant = _lire_json(RACINE + "derive/geo.json")
	if g is Dictionary:
		geo = g
	var l: Variant = _lire_json(RACINE + "derive/lines.json")
	if l is Array:
		lignes = l
	var p: Variant = _lire_json(RACINE + "derive/places.json")
	if p is Dictionary:
		lieux = p
