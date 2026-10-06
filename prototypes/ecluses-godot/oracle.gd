extends SceneTree
# ------------------------------------------------------------------
# L'ORACLE — le moteur GDScript rejoue-t-il le moteur JS ?
#
#   node tools/ecluses-vers-godot.mjs
#   godot --headless --path prototypes/ecluses-godot --script res://oracle.gd
#
# oracle.json contient des parties jouées par le moteur de la page web, avec
# l'état complet après chaque coup. On les rejoue ici, coup pour coup, et on
# REFUSE (code de sortie 1) au premier écart de plus d'un millionième.
# ------------------------------------------------------------------

func _init() -> void:
	var niveaux := {}
	for N in _lire("res://niveaux.json")["niveaux"]:
		niveaux[N["id"]] = N
	var parties: Array = _lire("res://oracle.json")["parties"]
	var coups := 0
	var ecarts := []
	for partie in parties:
		var N: Dictionary = niveaux[partie["niveau"]]
		var e := Moteur.charger(N)
		for pas in partie["pas"]:
			var r := {}
			if pas["action"] != null:
				r = Moteur.jouer(N, e, pas["action"])
				e = r["etat"]
				coups += 1
			var ecart := _compare(N, e, r, pas)
			if ecart != "":
				ecarts.append("%s, coup %d : %s" % [partie["niveau"], e["coups"], ecart])
				break
		if ecarts.size() >= 5:
			break
	if ecarts.is_empty():
		print("Oracle : %d parties, %d coups rejoués à l'identique." % [parties.size(), coups])
		quit(0)
	else:
		for x in ecarts:
			printerr("  ✗ " + x)
		quit(1)

func _compare(N: Dictionary, e: Dictionary, r: Dictionary, attendu: Dictionary) -> String:
	for cle in ["niv", "crete"]:
		for i in e[cle].size():
			var a = e[cle][i]
			var b = attendu[cle][i]
			if (a == null) != (b == null) or (a != null and absf(float(a) - float(b)) > 1e-6):
				return "%s[%d] = %s, attendu %s" % [cle, i, a, b]
	for i in e["ouvert"].size():
		if e["ouvert"][i] != attendu["ouvert"][i]:
			return "ouvert[%d]" % i
	for k in e["bateaux"].size():
		if e["bateaux"][k] != int(attendu["bateaux"][k]):
			return "bateau %d au bassin %d, attendu %d" % [k, e["bateaux"][k], int(attendu["bateaux"][k])]
	for cle in ["entree", "sortie"]:
		if absf(float(e[cle]) - float(attendu[cle])) > 1e-6:
			return "%s = %f, attendu %f" % [cle, e[cle], attendu[cle]]
	if not r.is_empty():
		for i in r["flux"].size():
			if absf(float(r["flux"][i]) - float(attendu["flux"][i])) > 1e-6:
				return "flux[%d] = %f, attendu %f" % [i, r["flux"][i], attendu["flux"][i]]
		if r["dep"].size() != attendu["dep"].size():
			return "%d déplacements, attendu %d" % [r["dep"].size(), attendu["dep"].size()]
	var v := Moteur.verdict(N, e)
	var fin_a: String = v.get("fin", "")
	var fin_b: String = attendu["verdict"].get("fin", "")
	if fin_a != fin_b:
		return "verdict « %s », attendu « %s »" % [fin_a, fin_b]
	return ""

func _lire(chemin: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(chemin))
