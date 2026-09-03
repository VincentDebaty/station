extends SceneTree
## LE CÔTÉ GODOT DE L'ORACLE DE L'ENCLENCHEMENT — sans scène, sans œil.
##
##   godot --headless --path . --script res://jeu/oracle_enclenchement.gd -- <sortie.json> <fiche.json> <journee.json> <denominateur>
##
## Joue une journée donnée (celle que schedule.js a tirée côté Node) au pas
## dt = 1/denominateur minute, avec le JOUEUR SCRIPTÉ — le même des deux côtés :
## à chaque pas, après le tick, chaque convoi voyageur en attente et sans quai
## reçoit le premier quai qui dessert sa destination, ni promis ni fermé, de
## préférence libre ; à défaut le premier quai atteignable (donc un mauvais
## quai : le refoulement est ainsi exercé). Écrit la TRACE : chaque transition
## d'état avec son instant, chaque choix du joueur, et la fin de service.
## tools/oracle-enclenchement.mjs compare à la trace de game.js.

const Geo := preload("res://jeu/geometrie.gd")
const Enc := preload("res://jeu/enclenchement.gd")
const Json := preload("res://jeu/json_exact.gd")

const MAX_PAS := 400000


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		printerr("usage : -- <sortie.json> <fiche.json> <journee.json> <denominateur>")
		quit(2)
		return
	var cfg: Variant = _json(args[1])
	var day: Variant = _json(args[2])
	if not (cfg is Dictionary) or not (day is Dictionary):
		printerr("fiche ou journée illisible")
		quit(1)
		return
	var dt: float = 1.0 / int(args[3])
	var G: Dictionary = Geo.construire(cfg)
	var enc = Enc.new(G, cfg)
	enc.charger(day)

	var trace := {"pas": [], "choix": [], "fin": null}
	var etats: Array = []
	for t in enc.trains:
		etats.append(t.state)
	var n := 0
	while not enc.ended and n < MAX_PAS:
		n += 1
		enc.game_min += dt
		enc.tick(dt)
		for i in range(enc.trains.size()):
			var t = enc.trains[i]
			if t.state != etats[i]:
				trace["pas"].append({"n": n, "t": enc.game_min, "id": t.id,
					"de": Enc.NOMS_ETAT[etats[i]], "a": Enc.NOMS_ETAT[t.state],
					"quai": t.platform, "cible": t.target, "qs": t.qs, "startS": t.start_s,
					"depDelay": t.dep_delay})
				etats[i] = t.state
		if enc.ended:
			break
		_joueur(enc, n, trace["choix"])
	if enc.resultat.is_empty():
		enc.fin_de_service(true)
	var fin: Dictionary = enc.resultat.duplicate()
	fin["n"] = n
	fin["t"] = enc.game_min
	trace["fin"] = fin

	var out := FileAccess.open(args[0], FileAccess.WRITE)
	if out == null:
		printerr("sortie impossible : " + args[0])
		quit(1)
		return
	out.store_string(Json.ecrire(trace))
	out.close()
	quit(0)


## Le joueur scripté — la même politique que côté Node, mot pour mot.
func _joueur(enc, n: int, choix: Array) -> void:
	for t in enc.trains:
		if t.freight or t.target != null:
			continue
		if t.state != Enc.S_WAITING and t.state != Enc.S_APPROACHING:
			continue
		var lf: Array = enc.links.get(t.from, [])
		var cands: Array = []
		for pid in lf:
			if enc.paths.has("out:%s:%d" % [t.to, int(pid)]) \
					and not enc.platform_claimed(pid) and not enc.platform_closed(pid):
				cands.append(pid)
		if cands.is_empty():
			for pid in lf:
				if not enc.platform_claimed(pid) and not enc.platform_closed(pid):
					cands.append(pid)
		if cands.is_empty():
			continue
		var pick: Variant = cands[0]
		for pid in cands:
			if not enc.platform_occupied(pid):
				pick = pid
				break
		enc.clic_train(t)
		var reponse: String = enc.clic_quai(pick)
		choix.append({"n": n, "id": t.id, "quai": pick, "reponse": reponse})


func _json(chemin: String) -> Variant:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return null
	return j.data
