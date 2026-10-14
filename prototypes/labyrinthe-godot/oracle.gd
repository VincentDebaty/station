extends SceneTree
# ------------------------------------------------------------------
# L'ORACLE — moteur.gd rejoue-t-il le moteur de la page web ?
#
#   node tools/labyrinthe-vers-godot.mjs
#   godot --headless --path prototypes/labyrinthe-godot --script res://oracle.gd
#
# oracle.json contient des parties jouées par la page. On les rejoue ici et
# on REFUSE (code de sortie 1) si une issue diffère (gagné ou pas, nombre de
# tapes), si l'eau d'une case du labyrinthe s'écarte de plus de 0,01 case ou
# la boule de plus de 0,05 case (les seuils du plan d'essai, étape 3 du
# rapport). On compte aussi les états identiques AU BIT PRÈS — c'est ce que
# le portage vise, puisque le moteur n'utilise que des opérations exactes.
# Enfin, le temps d'un pas de jeu en GDScript, en moyenne et au plus.
# ------------------------------------------------------------------

const TOL_EAU := 0.01
const TOL_BOULE := 0.05

var ecarts: Array[String] = []
var max_eau := 0.0
var max_boule := 0.0
var etats := 0
var exacts := 0
var temps_us := 0
var pas_mesures := 0
var pire_us := 0


func _init() -> void:
	var N: Dictionary = _lire("res://niveau.json")
	var parties: Array = _lire("res://oracle.json")["parties"]
	var M := Moteur.new(N)
	for p in parties:
		if p["mode"] == "repos":
			_au_repos(M, p)
		else:
			_temps_reel(M, p)
		if ecarts.size() >= 6:
			break
	var moyenne := float(temps_us) / maxi(1, pas_mesures) / 1000.0
	if ecarts.is_empty():
		print("Oracle : %d parties, %d états comparés, %d identiques au bit près ; écart maximal %s case d'eau, %s case de boule. Un pas de jeu : %.2f ms en moyenne, %.2f ms au plus (GDScript, cette machine)." % [
			parties.size(), etats, exacts, String.num_scientific(max_eau), String.num_scientific(max_boule), moyenne, pire_us / 1000.0])
		quit(0)
	else:
		for x in ecarts:
			printerr("  ✗ " + x)
		printerr("Oracle : %d écart(s)." % ecarts.size())
		quit(1)


func _pas(M: Moteur, e: Moteur.Etat) -> void:
	var t0 := Time.get_ticks_usec()
	M.pas(e)
	var d := Time.get_ticks_usec() - t0
	temps_us += d; pas_mesures += 1; pire_us = maxi(pire_us, d)


func _reposer(M: Moteur, e: Moteur.Etat) -> void:
	var n := 0
	while not M.repos(e) and n <= Moteur.MAXPAS:
		_pas(M, e)
		n += 1


func _au_repos(M: Moteur, p: Dictionary) -> void:
	var e := M.charger()
	var photos: Array = p["pas"]
	_comparer(M, e, photos[0], "%s, départ" % p["nom"])
	for t in range(1, photos.size()):
		var ph: Dictionary = photos[t]
		var k := int(ph["tape"])
		var r := M.taper(e, k)
		if r == null:
			ecarts.append("%s, tape %d (vanne %d) : refusée ici, jouée dans la page" % [p["nom"], t, k + 1])
			return
		e = r
		_reposer(M, e)
		if not _comparer(M, e, ph, "%s, tape %d (vanne %d)" % [p["nom"], t, k + 1]):
			return


func _temps_reel(M: Moteur, p: Dictionary) -> void:
	var e := M.charger()
	var appui := -1
	var depuis := 0
	var script: Array = p["script"]
	var attendue: Array = p["boule"]
	var a := 0
	var sortie := -1
	for im in 3000:
		for s in script:
			if int(s["a"]) == im:
				var r := M.taper(e, int(s["k"]))
				if r != null: e = r
				if s.get("tenu", false):
					appui = int(s["k"]); depuis = im
		if appui >= 0 and not e.gagne and im - depuis >= int(p["appui_long"]) and e.attente[appui] < 0.05:
			var r := M.taper(e, appui)
			if r != null: e = r
		_pas(M, e)
		if im % 10 == 0 and a < attendue.size():
			var b: Array = attendue[a]
			var d := Vector2(e.bx - float(b[1]), e.by - float(b[2])).length()
			max_boule = maxf(max_boule, d)
			etats += 1
			if e.bx == float(b[1]) and e.by == float(b[2]): exacts += 1
			if d > TOL_BOULE:
				ecarts.append("temps réel, image %d : boule à %.3f,%.3f, attendue à %.3f,%.3f" % [im, e.bx, e.by, float(b[1]), float(b[2])])
				return
			a += 1
		if e.gagne:
			sortie = im
			break
	if sortie != int(p["sortie"]):
		ecarts.append("temps réel : boule sortie à l'image %d, attendue à %d" % [sortie, int(p["sortie"])])


# Compare un état à sa photo ; faux (et un écart noté) au premier refus.
func _comparer(M: Moteur, e: Moteur.Etat, ph: Dictionary, ou: String) -> bool:
	etats += 1
	if e.gagne != bool(ph["gagne"]) or e.tapes != int(ph["tapes"]):
		ecarts.append("%s : gagné %s, %d tapes ; attendu %s, %d" % [ou, e.gagne, e.tapes, ph["gagne"], int(ph["tapes"])])
		return false
	var b: Array = ph["b"]
	var db := Vector2(e.bx - float(b[0]), e.by - float(b[1])).length()
	max_boule = maxf(max_boule, db)
	var eau: Array = ph["eau"]
	var exact := e.bx == float(b[0]) and e.by == float(b[1]) and e.pas == int(ph["pas"])
	var pire := 0.0
	var ou_pire := -1
	for y in M.H:
		for x in M.W:
			var s := 0.0
			for dy in M.S:
				for dx in M.S:
					s += e.m[(y * M.S + dy) * M.SW + x * M.S + dx]
			s /= M.S2
			var d := absf(s - float(eau[y * M.W + x]))
			if d > pire:
				pire = d; ou_pire = y * M.W + x
			if s != float(eau[y * M.W + x]): exact = false
	max_eau = maxf(max_eau, pire)
	if exact: exacts += 1
	if pire > TOL_EAU:
		ecarts.append("%s : eau de la case %d,%d à %.4f de la page" % [ou, ou_pire % M.W, ou_pire / M.W, pire])
		return false
	if db > TOL_BOULE:
		ecarts.append("%s : boule à %.3f,%.3f, attendue à %.3f,%.3f" % [ou, e.bx, e.by, float(b[0]), float(b[1])])
		return false
	return true


func _lire(chemin: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(chemin))
