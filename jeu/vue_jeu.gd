extends Node2D
## L'ÉCRAN DE JEU — un convoi qui roule.
##
##   godot --path . res://jeu/jeu.tscn
##   STATION_GARE=namur STATION_GRAINE=3 STATION_AUTO=1 STATION_VITESSE=4 godot --path . res://jeu/jeu.tscn
##
## Ce que cet écran dessine, il ne le décide jamais : la journée vient de
## Journee, chaque position de chaque état vient d'Enclenchement, et ce fichier
## ne fait que TRADUIRE un état en pixels — comme render.js le faisait pour le
## prototype, avec les mêmes formules de placement (placeQueue, placeEntry,
## placeExit, le transit de fret). Aucune règle de jeu ici : si un convoi ne
## part pas, c'est l'enclenchement qui l'a décidé, et l'oracle l'a vérifié.
##
## Commandes : un clic sur un convoi le choisit, un clic sur un quai l'y
## envoie ; espace met en pause ; 1, 2, 4 règlent la vitesse ; R rejoue une
## journée neuve ; Échap désélectionne. STATION_AUTO=1 laisse le joueur
## scripté de l'oracle jouer seul — c'est ainsi qu'on photographie un service
## sans personne devant.

const Geo := preload("res://jeu/geometrie.gd")
const Jour := preload("res://jeu/journee.gd")
const Has := preload("res://jeu/hasard.gd")
const Enc := preload("res://jeu/enclenchement.gd")
const Plan := preload("res://jeu/gare.gd")
const Cap := preload("res://jeu/capture.gd")

# Les couleurs du prototype (css/station.css) : l'esthétique est conservée.
const TEXTE := Color("#dbe2ee")
const MUET := Color("#7a8699")
const ACCENT := Color("#2dd4bf")
const OR := Color("#f5b23c")
const VERT := Color("#4ade80")
const ROUGE := Color("#ef4444")
const FRET := Color("#8f98a8")
const VOILE := Color(0.055, 0.078, 0.125, 0.82)

var fiche: Dictionary
var G: Dictionary
var enc: Enc                          # le script préchargé sert de type
var graine: int
var vitesse: float = 1.0
var pause: bool = false
var auto: bool = false
var duree_generation_ms: int = 0
var positions: Dictionary = {}       # id -> Array[{x, y, ang}], recalculé à chaque image
var plan: Node2D


func _ready() -> void:
	var id := OS.get_environment("STATION_GARE")
	if id == "":
		id = "darlington"
	fiche = Donnees.fiche(id)
	if fiche.is_empty():
		push_error("gare inconnue : " + id)
		return
	var g := OS.get_environment("STATION_GRAINE")
	graine = int(g) if g != "" else int(Time.get_unix_time_from_system()) % 100000
	var v := OS.get_environment("STATION_VITESSE")
	if v != "":
		vitesse = float(v)
	auto = OS.get_environment("STATION_AUTO") != ""

	G = Geo.construire(fiche)
	plan = Plan.new()
	plan.autonome = false
	# Un enfant se dessine APRÈS son parent : sans ceci, les quais recouvraient
	# les convois à l'arrêt — deux badges au-dessus de quais vides, à la première
	# capture. Le plan passe dessous, les convois roulent dessus.
	plan.show_behind_parent = true
	add_child(plan)
	plan.poser(fiche, G)
	_nouvelle_journee()
	Cap.eventuelle(self)


func _nouvelle_journee() -> void:
	var t0 := Time.get_ticks_msec()
	var day: Dictionary = Jour.new(G, fiche, Has.new(graine)).generate_schedule()
	duree_generation_ms = Time.get_ticks_msec() - t0
	enc = Enc.new(G, fiche)
	enc.charger(day)
	print("%s · graine %d — %d convois, journée tirée en %d ms"
		% [fiche.get("id", "?"), graine, enc.trains.size(), duree_generation_ms])


func _process(delta: float) -> void:
	if enc == null:
		return
	if not pause and not enc.ended:
		var dt_min: float = delta * vitesse / Geo.SEC_PER_GAMEMIN
		enc.game_min += dt_min
		enc.tick(dt_min)
		if auto and not enc.ended:
			_joueur_scripte()
	_calculer_positions()
	queue_redraw()


# ------------------------------------------------------------------
# Où est chaque voiture — les formules de placement de render.js
# ------------------------------------------------------------------
func _calculer_positions() -> void:
	positions.clear()
	for t in enc.trains:
		var p := _positions_de(t)
		if not p.is_empty():
			positions[t.id] = p


func _positions_de(t) -> Array:
	var out: Array = []
	var cs: float = Geo.CAR_SPACING
	var n := int(t.cars)
	match t.state:
		Enc.S_APPROACHING, Enc.S_WAITING:
			if t.qs == null:
				return out
			var ap: Dictionary = enc.approach[t.from]
			for i in range(n):
				out.append(Geo.path_point(ap, float(t.qs) - i * cs))
		Enc.S_MOVING_IN, Enc.S_DWELL:
			var path: Dictionary = enc.paths[t.entry_path]
			var ap: Dictionary = enc.approach[t.from]
			var head_s: float = t.stop_s
			if t.state == Enc.S_MOVING_IN:
				var stop_p: float = t.stop_s / path["len"]
				head_s = t.start_s + Enc.ease_run(t.progress / stop_p, 0.10, 0.22) * (t.stop_s - t.start_s)
			for i in range(n):
				var s: float = head_s - i * cs
				out.append(Geo.path_point(path, s) if s >= 0 else Geo.path_point(ap, ap["len"] + s))
		Enc.S_MOVING_BACK:
			var path: Dictionary = enc.paths[t.exit_path]
			var ap: Dictionary = enc.approach[t.from]
			var p0: float = 1 - t.stop_s / path["len"]
			var eff_p: float = p0 + Enc.ease_run((t.progress - p0) / (1 - p0), 0.16, 0) * (1 - p0)
			var head_s: float = (1 - eff_p) * path["len"]
			for i in range(n):
				var s: float = head_s - i * cs
				out.append(Geo.path_point(path, s) if s >= 0 else Geo.path_point(ap, ap["len"] + s))
		Enc.S_MOVING_OUT:
			var path: Dictionary = enc.paths[t.exit_path]
			var dep: Dictionary = enc.depart[t.to]
			var tail: float = (t.cars - 1) * cs
			var gone_p: float = 1 + (tail + Geo.EXIT_RUN) / path["len"]
			var eff_p: float = Enc.ease_run(t.progress / gone_p, 0.16, 0) * gone_p
			var head_s: float = (1 - eff_p) * (path["len"] + t.back_s)
			for i in range(n):
				var s: float = head_s + i * cs
				out.append(Geo.path_point(path, s) if s >= 0 else Geo.path_point(dep, -s))
		Enc.S_MOVING_THROUGH:
			var pin: Dictionary = enc.paths[t.entry_path]
			var pout: Dictionary = enc.paths[t.exit_path]
			var ap: Dictionary = enc.approach[t.from]
			var total_arc: float = pin["len"] + pout["len"]
			var tail: float = (t.cars - 1) * cs
			var end_u: float = 1 + (tail + Geo.EXIT_RUN) / total_arc
			var h: float = t.start_s + Enc.ease_run(t.progress / end_u, 0.12, 0) * (end_u * total_arc - t.start_s)
			for i in range(n):
				var s: float = h - i * cs
				if s < 0:
					out.append(Geo.path_point(ap, ap["len"] + s))
				elif s <= pin["len"]:
					out.append(Geo.path_point(pin, s))
				else:
					var out_arc: float = pout["len"] - (s - pin["len"])
					out.append(Geo.path_point(pout, out_arc) if out_arc >= 0 else Geo.path_point(enc.depart[t.to], -out_arc))
	return out


# ------------------------------------------------------------------
# Le dessin
# ------------------------------------------------------------------
static func fmt(minute: float) -> String:
	var m := int(max(0.0, floor(minute)))
	return "%02d:%02d" % [7 + m / 60, m % 60]


func _draw() -> void:
	if enc == null:
		return
	var police := ThemeDB.fallback_font
	var sel = enc.selected

	# --- les quais éligibles, fermés, promis ---------------------------------
	for q in G["platforms"]:
		var pid = q["id"]
		var r := Rect2(Geo.PLAT_X1, float(q["cy"]) - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
		if enc.platform_closed(pid):
			draw_rect(r, Color(ROUGE, 0.12), true)
			draw_rect(r, ROUGE, false, 1.5)
			var fin := ""
			for ev in enc.events:
				if ev.get("type") == "closure" and ev["plat"] == pid and ev["revealed"] and not ev["cleared"]:
					fin = "fermé jusqu'à " + fmt(float(ev["end"]))
			var w := police.get_string_size(fin, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(police, Vector2(Geo.PLAT_MID - w / 2, r.position.y - 6), fin, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ROUGE)
		elif sel != null and sel.target == null and enc.links.get(sel.from, []).has(pid) \
				and not enc.platform_claimed(pid):
			var col := Color(String(G["dest_color"][sel.to]))
			col.a = 0.45 if enc.platform_occupied(pid) else 1.0
			draw_rect(r.grow(2), col, false, 2.5)
		else:
			for t in enc.trains:
				if t.target == pid and (t.state == Enc.S_WAITING or t.state == Enc.S_APPROACHING):
					draw_rect(r.grow(1), Color(String(G["dest_color"][t.to]), 0.55), false, 1.5)
					break

	# --- les itinéraires accordés, à la couleur de la destination ------------
	for pid in enc.active_routes:
		var t = enc.active_routes[pid]
		var p: Dictionary = enc.paths[pid]
		var col := Color(String(G["dest_color"][t.to]))
		draw_polyline(Geo.vers_vector2(p["xs"], p["ys"]), col, 3.5, true)
	# --- l'itinéraire promis, en attente d'entrée ----------------------------
	for t in enc.trains:
		if t.target != null and (t.state == Enc.S_WAITING or t.state == Enc.S_APPROACHING):
			var pid := "in:%s:%d" % [t.from, int(t.target)]
			if enc.paths.has(pid) and not enc.active_routes.has(pid):
				var p: Dictionary = enc.paths[pid]
				draw_polyline(Geo.vers_vector2(p["xs"], p["ys"]), Color(String(G["dest_color"][t.to]), 0.35), 2.0, true)

	# --- les convois ----------------------------------------------------------
	for t in enc.trains:
		if not positions.has(t.id):
			continue
		var pos: Array = positions[t.id]
		var col := Color(String(G["dest_color"][t.to]))
		for i in range(pos.size()):
			var p: Dictionary = pos[i]
			var h: float = Geo.CAR_H if i == 0 else Geo.CAR_H - 4
			draw_set_transform(Vector2(p["x"], p["y"]), deg_to_rad(p["ang"]), Vector2.ONE)
			var r := Rect2(-Geo.CAR_LEN / 2.0, -h / 2.0, Geo.CAR_LEN, h)
			var caisse: Color = FRET if (t.freight and i > 0) else col
			if i > 0:
				caisse.a = 0.72
			if t == sel:
				draw_rect(r.grow(4), Color(ACCENT, 0.9), false, 2.0)
			if t.holding and i == 0:
				draw_circle(Vector2(Geo.CAR_LEN / 2.0 + 8, 0), 4, ROUGE)
			draw_rect(r, caisse, true)
			draw_rect(r, col, false, 1.2)
			if i == 0:
				var ab := String(G["dest_abbr"].get(t.to, ""))
				var w := police.get_string_size(ab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				draw_string(police, Vector2(-w / 2, 4), ab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#0E1420"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# le badge : l'heure de départ, puis le retard — jamais pour le fret
		var montre: bool = not t.freight and not t.wrong_platform \
			and t.state != Enc.S_MOVING_OUT and t.state != Enc.S_DONE \
			and not (t.state == Enc.S_APPROACHING and not t.settled)
		if montre:
			var late: float = Enc.lateness(t, enc.game_min)
			var txt: String
			var c: Color
			if late >= 1:
				txt = "+%d min" % int(floor(late))
				c = ROUGE
			elif late > -3:
				txt = fmt(t.dep)
				c = OR
			else:
				txt = fmt(t.dep)
				c = VERT
			var tete: Dictionary = pos[0]
			var w := police.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var bx := Vector2(tete["x"] - w / 2 - 6, tete["y"] - 30 - 10)
			draw_rect(Rect2(bx, Vector2(w + 12, 20)), Color(0.055, 0.078, 0.125, 0.88), true)
			draw_rect(Rect2(bx, Vector2(w + 12, 20)), c, false, 1.0)
			draw_string(police, Vector2(bx.x + 6, bx.y + 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)

	# --- le HUD ---------------------------------------------------------------
	var horloge := fmt(enc.game_min)
	var wh := police.get_string_size(horloge, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(police, Vector2(700 - wh / 2 - 24, 44), horloge, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TEXTE)
	var d := enc.live_delay()
	var cd: Color = VERT if d < 10 else (OR if d < 30 else ROUGE)
	draw_string(police, Vector2(700 + wh / 2 - 12, 44), "+%d" % int(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, cd)
	var etat := ("pause" if pause else "x%d" % int(vitesse)) + ("  ·  auto" if auto else "")
	var we := police.get_string_size(etat, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(police, Vector2(1400 - 28 - we, 40), etat, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUET)
	draw_string(police, Vector2(28, 760 - 22),
		"clic convoi → clic quai   ·   espace pause   ·   1 2 4 vitesse   ·   R rejouer   ·   graine %d, journée en %d ms" % [graine, duree_generation_ms],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUET)

	# --- la fin de service ----------------------------------------------------
	if enc.ended:
		draw_rect(Rect2(0, 0, 1400, 760), VOILE, true)
		var r: Dictionary = enc.resultat
		var titre: String = "Service interrompu" if r.get("failed", false) \
			else ("Sans faute !" if r.get("perfect", false) else ("Fin du service" if r.get("win", false) else "Objectif manqué"))
		var etoiles := "★".repeat(int(r.get("stars", 0))) + "☆".repeat(3 - int(r.get("stars", 0)))
		var ligne := "%s   ·   retard cumulé %d min" % [etoiles, int(r.get("d", 0))]
		var wt := police.get_string_size(titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var wl := police.get_string_size(ligne, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(police, Vector2(700 - wt / 2, 360), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, TEXTE)
		draw_string(police, Vector2(700 - wl / 2, 400), ligne, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, OR)
		var wr := police.get_string_size("R pour rejouer", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(police, Vector2(700 - wr / 2, 440), "R pour rejouer", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUET)


# ------------------------------------------------------------------
# Les commandes
# ------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if enc == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				pause = not pause
			KEY_1:
				vitesse = 1.0
			KEY_2:
				vitesse = 2.0
			KEY_4:
				vitesse = 4.0
			KEY_R:
				graine = (graine * 7 + 13) % 100000
				pause = false
				_nouvelle_journee()
			KEY_ESCAPE:
				enc.selected = null
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if enc.ended:
			return
		var m: Vector2 = get_global_mouse_position()
		# un convoi ?
		for t in enc.trains:
			if not positions.has(t.id):
				continue
			for p in positions[t.id]:
				if Vector2(p["x"], p["y"]).distance_to(m) <= Geo.CAR_LEN / 2.0 + 10:
					var dit := enc.clic_train(t)
					if dit != "":
						print(t.id + " — " + dit)
					return
		# un quai ?
		for q in G["platforms"]:
			var r := Rect2(Geo.PLAT_X1, float(q["cy"]) - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
			if r.has_point(m):
				var dit := enc.clic_quai(q["id"])
				if dit != "":
					print("quai %d — %s" % [int(q["id"]), dit])
				return
		enc.selected = null


## Le joueur scripté de l'oracle, pour une démonstration sans personne devant.
func _joueur_scripte() -> void:
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
		enc.clic_quai(pick)
