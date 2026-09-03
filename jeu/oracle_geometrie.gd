extends SceneTree
## LE CÔTÉ GODOT DE L'ORACLE — sans scène, sans œil.
##
##   godot --headless --path . --script res://jeu/oracle_geometrie.gd -- <dossier_sortie> <fiche.json> [...]
##
## Lit chaque fiche, fait construire sa géométrie par Geometrie.construire(), et
## écrit <dossier_sortie>/<id>.json avec les mêmes noms qu'engine.js. C'est
## tools/oracle-geometrie.mjs qui le lance, puis compare à ce que le prototype
## calcule sur la même fiche. Ce script ne juge rien : il expose.
##
## EN LOT, VOLONTAIREMENT : démarrer Godot coûte la moitié d'une seconde, et
## l'oracle balaie 401 fiches. Un démarrage pour toutes, pas un par fiche.
##
## Le JSON de Godot n'écrit les flottants qu'à six chiffres : on les formate
## nous-mêmes, à 17, pour que la comparaison porte sur ce qui a été calculé et
## non sur ce qui a été écrit.
##
## PRELOAD, PAS class_name. En mode --script, Godot n'a pas chargé le cache des
## classes globales : `Geometrie` n'existe pas encore comme nom. Le chemin,
## lui, existe toujours.

const Geo := preload("res://jeu/geometrie.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage : --script res://jeu/oracle_geometrie.gd -- <dossier_sortie> <fiche.json> [...]")
		quit(2)
		return
	var dossier: String = args[0]
	var rate := 0
	for i in range(1, args.size()):
		if not _traiter(args[i], dossier):
			rate += 1
	quit(1 if rate > 0 else 0)


func _traiter(chemin: String, dossier: String) -> bool:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		printerr("fiche illisible : " + chemin)
		return false
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		printerr("JSON invalide : %s — %s" % [chemin, j.get_error_message()])
		return false
	var cfg: Dictionary = j.data
	var id := String(cfg.get("id", chemin.get_file().get_basename()))
	var G: Dictionary = Geo.construire(cfg)
	var sortie := dossier.path_join(id + ".json")
	var out := FileAccess.open(sortie, FileAccess.WRITE)
	if out == null:
		printerr("sortie impossible : " + sortie)
		return false
	out.store_string(_json(_exportable(G)))
	out.close()
	return true


## Aplatit le résultat : les paires xs/ys deviennent des listes de {x, y},
## comme les `pts` d'engine.js.
func _exportable(G: Dictionary) -> Dictionary:
	var paths := {}
	for id in G["paths"]:
		var p: Dictionary = G["paths"][id]
		paths[id] = {"id": id, "pts": _pts(p["xs"], p["ys"]), "cum": Array(p["cum"]),
			"len": p["len"], "side": p["side"], "dur": p["dur"]}
	var approach := {}
	for k in G["approach"]:
		var a: Dictionary = G["approach"][k]
		approach[k] = {"pts": _pts(a["xs"], a["ys"]), "cum": Array(a["cum"]), "len": a["len"]}
	var depart := {}
	for k in G["depart"]:
		var d: Dictionary = G["depart"][k]
		depart[k] = {"pts": _pts(d["xs"], d["ys"]), "cum": Array(d["cum"]), "len": d["len"]}
	return {
		"PLATFORMS": G["platforms"], "PORTALS": G["portals"],
		"DEST_COLOR": G["dest_color"], "DEST_ABBR": G["dest_abbr"], "LINKS": G["links"],
		"paths": paths, "APPROACH": approach, "DEPART": depart,
		"conflicts": G["conflicts"], "PAIRS": G["pairs"],
	}


func _pts(xs: PackedFloat64Array, ys: PackedFloat64Array) -> Array:
	var out: Array = []
	for i in range(xs.size()):
		out.append({"x": xs[i], "y": ys[i]})
	return out


## Sérialisation JSON maison : flottants à 17 chiffres, entiers sans point,
## clés dans l'ordre d'insertion.
func _json(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			if is_inf(v):
				return "\"Infinity\"" if v > 0 else "\"-Infinity\""
			if v == floor(v) and abs(v) < 1e15:
				return "%d" % int(v)
			# Pas de %g en GDScript. À 17 décimales, tout flottant de l'ordre du
			# pixel se réécrit exactement — plus que ses 16 chiffres utiles.
			return "%.17f" % v
		TYPE_STRING:
			return JSON.stringify(v)
		TYPE_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var parts: PackedStringArray = []
			for e in v:
				parts.append(_json(e))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts: PackedStringArray = []
			for k in v.keys():
				parts.append(JSON.stringify(str(k)) + ":" + _json(v[k]))
			return "{" + ",".join(parts) + "}"
		_:
			return JSON.stringify(str(v))
