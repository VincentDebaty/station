extends SceneTree
## LE CÔTÉ GODOT DE L'ORACLE DES JOURNÉES — sans scène, sans œil.
##
##   godot --headless --path . --script res://jeu/oracle_journee.gd -- <dossier_sortie> <graines> <fiche.json> [...]
##
## Pour chaque fiche et chaque graine (« 1,2,3 »), construit la géométrie,
## tire la journée avec un Hasard neuf à cette graine, et écrit
## <dossier_sortie>/<id>-<graine>.json — le même JSON que JSON.stringify(day)
## côté prototype : schedule (id, from, to, cars, arr, dep, hint, freight,
## arrEff) et events. C'est tools/oracle-journee.mjs qui lance, puis compare.
##
## Une graine par (fiche, graine), REMISE À NEUF à chaque fois : c'est ce que
## fait gen-check (reseed avant chaque gare), et c'est ce qui permet de rejouer
## une journée précise sans rejouer toutes les précédentes.

const Geo := preload("res://jeu/geometrie.gd")
const Jour := preload("res://jeu/journee.gd")
const Has := preload("res://jeu/hasard.gd")
const Json := preload("res://jeu/json_exact.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("usage : --script res://jeu/oracle_journee.gd -- <dossier_sortie> <graines> <fiche.json> [...]")
		quit(2)
		return
	var dossier: String = args[0]
	var graines: Array = []
	for g in args[1].split(","):
		graines.append(int(g))
	var rate := 0
	for i in range(2, args.size()):
		if not _traiter(args[i], graines, dossier):
			rate += 1
	quit(1 if rate > 0 else 0)


func _traiter(chemin: String, graines: Array, dossier: String) -> bool:
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
	for graine in graines:
		var t0 := Time.get_ticks_msec()
		var journee = Jour.new(G, cfg, Has.new(graine))
		var day: Dictionary = journee.generate_schedule()
		var duree := Time.get_ticks_msec() - t0
		var sortie := dossier.path_join("%s-%d.json" % [id, graine])
		var out := FileAccess.open(sortie, FileAccess.WRITE)
		if out == null:
			printerr("sortie impossible : " + sortie)
			return false
		out.store_string(Json.ecrire(_exportable(day, duree)))
		out.close()
	return true


## Le JSON de JSON.stringify(day) : les convois avec leurs seuls champs
## publics, dans l'ordre où schedule.js les pose, et les événements tels quels.
func _exportable(day: Dictionary, duree_ms: int) -> Dictionary:
	var schedule: Array = []
	for s in day["schedule"]:
		var e := {}
		e["id"] = s["id"]
		if s.get("freight", false):
			e["freight"] = true
		e["from"] = s["from"]
		e["to"] = s["to"]
		e["cars"] = s["cars"]
		e["arr"] = s["arr"]
		e["dep"] = s["dep"]
		if s.has("arrEff"):
			e["arrEff"] = s["arrEff"]
		e["hint"] = s["hint"]
		schedule.append(e)
	return {"schedule": schedule, "events": day["events"], "_duree_ms": duree_ms}
