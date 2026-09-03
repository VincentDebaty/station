extends SceneTree
## LE CÔTÉ GODOT DE L'ORACLE DE LA SAUVEGARDE — sans scène, sans autoload.
##
##   godot --headless --path . --script res://jeu/oracle_sauvegarde.gd -- <dossier_sortie> <cas.json>
##
## `cas.json` : { fixtures: [{nom, brut}], ops: [[fonction, args…]] }. Pour
## chaque sauvegarde de départ, un dossier de travail à elle, où l'on pose la
## chaîne brute sous la clé du prototype ; puis migration, chargement, la
## suite d'écritures (chaque valeur rendue notée), l'état, le fichier écrit,
## et un rechargement à neuf. Écrit <dossier_sortie>/cas-<i>.json — le même
## relevé que __jouer côté prototype. C'est tools/oracle-sauvegarde.mjs qui
## lance, puis compare.

const Sauv := preload("res://jeu/sauvegarde.gd")
const Json := preload("res://jeu/json_exact.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage : --script res://jeu/oracle_sauvegarde.gd -- <dossier_sortie> <cas.json>")
		quit(2)
		return
	var dossier: String = args[0]
	var f := FileAccess.open(args[1], FileAccess.READ)
	if f == null:
		printerr("cas illisibles : " + args[1])
		quit(2)
		return
	var cas: Variant = JSON.parse_string(f.get_as_text())
	if not (cas is Dictionary):
		printerr("cas invalides")
		quit(2)
		return
	var fixtures: Array = cas["fixtures"]
	var ops: Array = cas["ops"]
	for i in fixtures.size():
		var travail := dossier.path_join("fx-%d" % i)
		DirAccess.make_dir_recursive_absolute(travail)
		var out := _jouer(fixtures[i].get("brut"), ops, travail)
		var fo := FileAccess.open(dossier.path_join("cas-%d.json" % i), FileAccess.WRITE)
		fo.store_string(Json.ecrire(out))
		fo.close()
	quit(0)


func _jouer(brut: Variant, ops: Array, travail: String) -> Dictionary:
	var s = Sauv.new()
	s.dossier = travail
	if brut != null:
		s._ecrire(Sauv.CLE_PROGRESSION, String(brut))
	var parsed: Variant = null
	if brut is String and brut != "":
		var j := JSON.new()
		if j.parse(brut) == OK:
			parsed = j.data
	var migre: Dictionary = Sauv.migrer(parsed)
	s.charger()
	var rets: Array = []
	for op in ops:
		rets.append(_appliquer(s, op))
	var e1 := _etat(s)
	var fichier: Variant = JSON.parse_string(String(s._lire(Sauv.CLE_PROGRESSION)))
	var muet_ecrit: Variant = s._lire(Sauv.CLE_MUET)
	var accueilli_ecrit: Variant = s._lire(Sauv.CLE_ACCUEILLI)
	s.charger()
	var e2 := _etat(s)
	s.free()
	return {"migre": migre, "ops": rets, "etat": e1, "fichier": fichier, "rechargement": e2,
		"muetEcrit": muet_ecrit, "accueilliEcrit": accueilli_ecrit}


## Une écriture du prototype, par son nom JavaScript. null pour celles qui ne
## rendent rien.
func _appliquer(s, op: Array) -> Variant:
	match String(op[0]):
		"markTentee":
			s.marquer_tentee(op[1])
			return null
		"saveResult":
			s.enregistrer_resultat(op[1], op[2], op[3])
			return null
		"pushSerie":
			return s.pousser_serie(bool(op[1]))
		"payerPassage":
			return s.payer_passage(op[1])
		"setCarteCourante":
			s.set_carte_courante(op[1])
			return null
		"acquerirCarte":
			return s.acquerir_carte(op[1], op[2] if op.size() > 2 else null)
		"setMuted":
			s.set_muet(bool(op[1]))
			return null
		"setOnboarded":
			s.set_accueilli(bool(op[1]))
			return null
	printerr("écriture inconnue : " + String(op[0]))
	return null


func _etat(s) -> Dictionary:
	return {
		"progression": s.get_progression().duplicate(true), "passees": s.get_passees().duplicate(),
		"serie": s.get_serie(), "carte": s.get_carte_courante(),
		"possedees": s.cartes_possedees().duplicate(), "cartes": s.cartes_enregistrees(),
		"muet": s.get_muet(), "accueilli": s.get_accueilli(),
	}
