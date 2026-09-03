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
const Rub := preload("res://jeu/ruban.gd")
const Rec := preload("res://jeu/recompense.gd")

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
var ruban = null                     # le ruban de la carte qui porte la gare ; null hors carte
var carte_id := ""
var fiche_jouee: Dictionary          # la fiche telle que le ruban la sert (difficulty, gen recalculés)
var fin_enregistree := false         # la fin de service est écrite une fois
var app = null                       # l'application qui enchaîne les écrans ; null seul à l'écran
var autonome := true                 # lancé comme scène : la gare vient de l'environnement
var retour_lance := false            # la main est rendue une fois
var bilan_final := {}                # le relevé pour le ruban (endGame → CARTE.bilan)
var medailles_final: Array = []

# --- le tutoriel : le premier service, guidé pas à pas (js/game.js, onboarding)
var gel := false                     # le service est gelé par un repère
var tuto := ""                       # la phase ; "" quand il n'y a rien à enseigner
var tuto_premier := ""               # l'id du premier train guidé
var tuto_feu_vu := false
var tuto_vitesse_vu := false
var coach_cible: Dictionary = {}     # {train: id} | {quai: pid} | {hud: "retard"|"vitesse"}
var bulle: PanelContainer
var bulle_texte: Label
var bulle_bouton: Button
var accueil: Control


func _ready() -> void:
	_construire_coach()
	if not autonome:
		return
	var id := OS.get_environment("STATION_GARE")
	if id == "":
		id = "darlington"
	fiche = Donnees.fiche(id)
	if fiche.is_empty():
		push_error("gare inconnue : " + id)
		return
	# LA FICHE TELLE QU'ON LA JOUE (étape 5). La carte qui porte la gare décide
	# de son niveau — la rampe du ruban — et donc de son enveloppe et de son
	# barème. Hors carte : la fiche telle quelle, comme le prototype sans
	# CARTE_COURANTE. STATION_CARTE=<id> force la carte quand deux la portent.
	# STATION_SANS_TRACE=1 : rien n'est écrit (l'aperçu sans trace du prototype).
	Sauvegarde.apercu_sans_trace = OS.get_environment("STATION_SANS_TRACE") != ""
	_choisir_ruban(id)
	fiche_jouee = ruban.fiche_de_service(fiche) if ruban != null else fiche
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


## Un service commandé par l'application : la fiche, le ruban et sa carte.
func demarrer(f: Dictionary, r, cid: String) -> void:
	fiche = f
	ruban = r
	carte_id = cid
	fiche_jouee = ruban.fiche_de_service(fiche) if ruban != null else fiche
	var g := OS.get_environment("STATION_GRAINE")
	graine = int(g) if g != "" else int(Time.get_unix_time_from_system()) % 100000
	var v := OS.get_environment("STATION_VITESSE")
	vitesse = float(v) if v != "" else 1.0
	auto = OS.get_environment("STATION_AUTO") != ""
	pause = false
	retour_lance = false
	G = Geo.construire(fiche)
	if plan != null:
		remove_child(plan)
		plan.queue_free()
	plan = Plan.new()
	plan.autonome = false
	plan.show_behind_parent = true
	add_child(plan)
	plan.poser(fiche, G)
	_nouvelle_journee()
	_tuto_demarrer()


func _choisir_ruban(id: String) -> void:
	var voulu := OS.get_environment("STATION_CARTE")
	for e in Donnees.cartes_index:
		var cid := String(e.get("id", ""))
		if (voulu != "" and cid != voulu) or not Donnees.cartes.has(cid):
			continue
		var r = Rub.new(Donnees.cartes[cid], Donnees.fiches)
		if r.sur_le_ruban(id):
			ruban = r
			carte_id = cid
			# Jouer une gare, c'est jouer SA carte : la progression lue et écrite
			# est celle-là, vivante — le ruban voit chaque résultat enregistré.
			Sauvegarde.set_carte_courante(cid)
			r.stations = Sauvegarde.get_progression()
			r.passees = Sauvegarde.get_passees()
			return


## « europe, niveau 3 (fiche 4), 3 étoiles sous 10 min » — ce que le service
## demande vraiment, pour le journal et le bandeau.
func _niveau_texte() -> String:
	if ruban == null:
		return "hors carte, niveau de fiche %d" % int(fiche.get("difficulty", 0))
	var s: Dictionary = enc.seuils_de_service() if enc != null else {}
	return "%s, niveau %d%s (fiche %d), 3 étoiles sous %s min" % [
		carte_id, int(fiche_jouee.get("difficulty", 0)),
		" BOSS" if ruban.est_boss(String(fiche.get("id", "")), fiche) else "",
		int(fiche.get("difficulty", 0)), str(s.get("trois", "?"))]


func _nouvelle_journee() -> void:
	fin_enregistree = false
	var t0 := Time.get_ticks_msec()
	var day: Dictionary = Jour.new(G, fiche_jouee, Has.new(graine)).generate_schedule()
	duree_generation_ms = Time.get_ticks_msec() - t0
	enc = Enc.new(G, fiche_jouee)
	if ruban != null:
		enc.seuils = ruban.seuils_de_service(fiche)
	enc.charger(day)
	print("%s · graine %d — %d convois, journée tirée en %d ms · %s"
		% [fiche.get("id", "?"), graine, enc.trains.size(), duree_generation_ms, _niveau_texte()])


## LA FIN DE SERVICE S'ÉCRIT COMME DANS LE PROTOTYPE (js/game.js, endGame) :
## un échec se note sans toucher au record, une réussite garde le meilleur ;
## la série se tient après, et casse sur un échec. Les médailles se comparent
## avant/après, elles ne se stockent pas.
func _enregistrer_fin() -> void:
	fin_enregistree = true
	var r: Dictionary = enc.resultat
	var id := String(fiche.get("id", ""))
	var stars := int(r["stars"])
	var avant: Array = Rec.medailles_de(Rec.etat_recompenses(ruban, Sauvegarde.get_serie())) if ruban != null else []
	# Étoiles et record de CETTE gare AVANT enregistrement : c'est la
	# différence qui dit ce que le service a rapporté.
	var prev: Dictionary = ruban.progression_de(id) if ruban != null else {}
	bilan_final = {"gare": id, "stars": stars, "prevStars": Rub.etoiles_de(prev), "d": r["d"],
		"prevBest": prev.get("bestDelay"), "perfect": r["perfect"], "failed": r["failed"], "win": r["win"],
		"seuils": enc.seuils_de_service()}
	medailles_final = []
	if r["failed"]:
		Sauvegarde.marquer_tentee(id)
	else:
		Sauvegarde.enregistrer_resultat(id, stars, r["d"])
	var serie: Dictionary = Sauvegarde.pousser_serie((not r["failed"]) and stars >= Rec.SERIE_SEUIL)
	var texte := "enregistré : %s %d★, retard %d, série %d (record %d)" % [id, stars, int(r["d"]), serie["n"], serie["record"]]
	if ruban != null:
		var noms: PackedStringArray = []
		medailles_final = Rec.medailles_nouvelles(avant, Rec.medailles_de(Rec.etat_recompenses(ruban, Sauvegarde.get_serie())))
		for m in medailles_final:
			noms.append(m["nom"])
		if not noms.is_empty():
			texte += " · médailles : " + ", ".join(noms)
		texte += " · position %d/%d" % [ruban.position_courante(), ruban.longueur()]
	if Sauvegarde.apercu_sans_trace:
		texte += " (sans trace)"
	print(texte)


func _process(delta: float) -> void:
	if enc == null:
		return
	if not pause and not gel and not enc.ended:
		var dt_min: float = delta * vitesse / Geo.SEC_PER_GAMEMIN
		enc.game_min += dt_min
		enc.tick(dt_min)
		if auto and not enc.ended:
			_joueur_scripte()
	if enc.ended and not fin_enregistree:
		_enregistrer_fin()
		# Le relevé se lit sur la carte, sous la gare qu'on vient de tenir — le
		# temps de voir le dernier convoi s'arrêter, puis la main est rendue.
		if app != null and not retour_lance:
			retour_lance = true
			get_tree().create_timer(1.2).timeout.connect(_rendre_la_main)
	_calculer_positions()
	_tuto_tick()
	_placer_bulle()
	queue_redraw()


func _rendre_la_main() -> void:
	if app != null and enc != null and enc.ended:
		app.fin_de_service(bilan_final, medailles_final)


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
	if app != null:
		draw_string(police, Vector2(28, 86), "‹ Carte", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUET)
	var etat := ("pause" if pause else "x%d" % int(vitesse)) + ("  ·  auto" if auto else "")
	var we := police.get_string_size(etat, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(police, Vector2(1400 - 28 - we, 40), etat, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUET)
	draw_string(police, Vector2(28, 760 - 22),
		"clic convoi → clic quai   ·   espace pause   ·   1 2 4 vitesse   ·   R rejouer   ·   graine %d, journée en %d ms   ·   %s" % [graine, duree_generation_ms, _niveau_texte()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUET)

	# --- le repère du tutoriel : un cerne pulsé sur la cible ----------------------
	if not coach_cible.is_empty():
		var rc := _rect_cible()
		if rc != Rect2():
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
			draw_rect(rc.grow(8 + 4 * pulse), Color(ACCENT, 0.9), false, 2.5)
			draw_rect(rc.grow(14 + 6 * pulse), Color(ACCENT, 0.25), false, 1.5)

	# --- la fin de service, seul à l'écran (l'application lit le relevé sur la carte)
	if enc.ended and app == null:
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
				if app != null and enc.selected == null:
					app.abandonner_service()
				else:
					enc.selected = null
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = event.position
		if app != null and Rect2(20, 20, 260, 72).has_point(m):
			app.abandonner_service()
			return
		if enc.ended or tuto == "accueil":
			return
		# un convoi ?
		for t in enc.trains:
			if not positions.has(t.id):
				continue
			for p in positions[t.id]:
				if Vector2(p["x"], p["y"]).distance_to(m) <= Geo.CAR_LEN / 2.0 + 10:
					var dit := enc.clic_train(t)
					if dit != "":
						print(t.id + " — " + dit)
					if enc.selected == t:
						_tuto_train_touche(t)
					return
		# un quai ?
		for q in G["platforms"]:
			var r := Rect2(Geo.PLAT_X1, float(q["cy"]) - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
			if r.has_point(m):
				var choisi = enc.selected
				var dit := enc.clic_quai(q["id"])
				if dit != "":
					print("quai %d — %s" % [int(q["id"]), dit])
				if choisi != null and choisi.target != null:
					_tuto_quai_choisi()
				return
		enc.selected = null


# ------------------------------------------------------------------
# Le tutoriel — le premier service, guidé avec deux trains
# ------------------------------------------------------------------
# Transposition de l'accueil de js/game.js : un repère visuel (cerne pulsé +
# bulle) dit EXACTEMENT quoi toucher, le service se gèle pendant chaque repère
# et reprend quand le joueur agit. Ne s'affiche qu'une fois (Sauvegarde,
# accueilli). Deux étapes sont opportunistes : le premier feu rouge, et le
# moment où il n'y a plus rien à aiguiller.
func _construire_coach() -> void:
	bulle = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#151d2e")
	st.border_color = ACCENT
	st.set_border_width_all(1)
	for coin in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		st.set("corner_radius_" + coin, 10)
	st.set_content_margin_all(14)
	bulle.add_theme_stylebox_override("panel", st)
	bulle.custom_minimum_size = Vector2(340, 0)
	bulle.size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	bulle.add_child(v)
	bulle_texte = Label.new()
	bulle_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bulle_texte.custom_minimum_size = Vector2(312, 0)
	bulle_texte.add_theme_font_size_override("font_size", 14)
	bulle_texte.add_theme_color_override("font_color", TEXTE)
	v.add_child(bulle_texte)
	bulle_bouton = Button.new()
	bulle_bouton.text = "Suivant"
	bulle_bouton.pressed.connect(_coach_suivant)
	v.add_child(bulle_bouton)
	bulle.visible = false
	add_child(bulle)

	# L'accueil : un voile sur toute la scène, et la carte au centre. Le voile
	# est un enfant direct — dans un CenterContainer il serait réduit à rien.
	accueil = Control.new()
	accueil.set_anchors_preset(Control.PRESET_FULL_RECT)
	var voile := ColorRect.new()
	voile.color = VOILE
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	accueil.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	accueil.add_child(centre)
	var carte := PanelContainer.new()
	carte.add_theme_stylebox_override("panel", st.duplicate())
	carte.custom_minimum_size = Vector2(520, 0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	carte.add_child(cv)
	for ligne in [["Bienvenue", 12, ACCENT], ["Le poste d'aiguillage", 26, TEXTE],
			["Vous dirigez la gare : faites entrer et repartir chaque train à l'heure.", 15, TEXTE],
			["Je vous montre, pas à pas, avec deux trains — les repères indiquent quoi toucher. Rien ne presse.", 13, MUET]]:
		var l := Label.new()
		l.text = ligne[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", ligne[1])
		l.add_theme_color_override("font_color", ligne[2])
		cv.add_child(l)
	var b := Button.new()
	b.text = "Commencer"
	b.pressed.connect(_accueil_ferme)
	cv.add_child(b)
	centre.add_child(carte)
	accueil.visible = false
	add_child(accueil)
	# Les ancres pleines ne prennent leur taille qu'une fois dans l'arbre.
	accueil.set_deferred("size", Vector2(1400, 760))
	voile.set_deferred("size", Vector2(1400, 760))
	centre.set_deferred("size", Vector2(1400, 760))


func _tuto_demarrer() -> void:
	tuto = ""
	coach_cible = {}
	bulle.visible = false
	accueil.visible = false
	gel = false
	if app == null or auto or Sauvegarde.get_accueilli():
		return
	tuto_premier = ""
	tuto_feu_vu = false
	tuto_vitesse_vu = false
	tuto = "accueil"
	gel = true
	accueil.visible = true


func _accueil_ferme() -> void:
	if tuto != "accueil":
		return
	accueil.visible = false
	tuto = "attente1"
	gel = false


func _coach(cible: Dictionary, texte: String, bouton: String = "") -> void:
	coach_cible = cible
	bulle_texte.text = texte
	bulle_bouton.text = bouton if bouton != "" else "Suivant"
	bulle_bouton.visible = bouton != ""
	bulle.visible = true
	_placer_bulle()


func _cacher_coach() -> void:
	coach_cible = {}
	bulle.visible = false


## Un quai qui dessert la destination du train ET libre : le bon choix.
func _quai_desservant(t) -> Variant:
	var links: Array = enc.links.get(t.from, [])
	var bons: Array = []
	var avec_chemin: Array = []
	for pid in links:
		if enc.paths.has("out:%s:%d" % [t.to, int(pid)]):
			avec_chemin.append(pid)
			if not enc.platform_reserved(pid) and not enc.platform_closed(pid):
				bons.append(pid)
	if not bons.is_empty():
		return bons[0]
	if not avec_chemin.is_empty():
		return avec_chemin[0]
	return links[0] if not links.is_empty() else null


## Combien de quais s'allument, et combien desservent vraiment la destination.
func _comptes_quais(t) -> Dictionary:
	var lit := 0
	var sert := 0
	for pid in enc.links.get(t.from, []):
		if not enc.platform_claimed(pid) and not enc.platform_closed(pid):
			lit += 1
			if enc.paths.has("out:%s:%d" % [t.to, int(pid)]):
				sert += 1
	return {"lit": lit, "sert": sert}


func _train_pret(exclure: String) -> Variant:
	for o in enc.trains:
		if o.freight or o.target != null or not o.settled or o.id == exclure:
			continue
		if o.state == Enc.S_WAITING or o.state == Enc.S_APPROACHING:
			return o
	return null


func _train(id: String) -> Variant:
	for o in enc.trains:
		if o.id == id:
			return o
	return null


func _tuto_tick() -> void:
	if tuto == "" or enc.ended:
		return
	match tuto:
		"attente1":
			var choisi = null
			for o in enc.trains:
				if o.freight or o.target != null or not o.settled:
					continue
				if o.state != Enc.S_WAITING and o.state != Enc.S_APPROACHING:
					continue
				var n := _comptes_quais(o)
				if n["lit"] > 1 and n["sert"] < n["lit"]:
					choisi = o
					break
				if choisi == null:
					choisi = o
			if choisi == null:
				return
			tuto_premier = choisi.id
			gel = true
			tuto = "touche1"
			_coach({"train": choisi.id}, "Voici un train qui s'annonce. Touchez-le pour le choisir.")
		"quai1":
			var t = _train(tuto_premier)
			if t == null or t.wrong_platform or t.state == Enc.S_DONE or t.state == Enc.S_MOVING_BACK or t.state == Enc.S_MOVING_OUT:
				tuto = "attente2"
				return
			if t.state != Enc.S_DWELL:
				return
			gel = true
			tuto = "aquai"
			_coach({"train": t.id}, "Il est à quai. Les voyageurs montent et descendent : deux minutes au minimum. Et il ne repartira jamais avant son heure de départ, celle du cadran — même prêt, il attend l'heure. Tout cela se fait seul, vous n'avez rien à faire.", "Compris")
		"attente2":
			var t = _train_pret(tuto_premier)
			if t == null:
				return
			gel = true
			tuto = "touche2"
			_coach({"train": t.id}, "Un autre train arrive. Touchez-le à son tour.")
		"libre":
			_tuto_veille()


func _tuto_veille() -> void:
	if not tuto_feu_vu:
		for o in enc.trains:
			if o.holding and o.state == Enc.S_DWELL:
				tuto_feu_vu = true
				gel = true
				tuto = "feu"
				_coach({"train": o.id}, "Feu rouge : ce train est prêt, mais sa voie de sortie est occupée. Il repartira seul dès qu'elle se libère — vous n'avez rien à faire, et le retard court pendant ce temps.", "Compris")
				return
	if not tuto_vitesse_vu and not enc.trains.is_empty():
		var occupe := false
		for o in enc.trains:
			if not o.freight and (o.state == Enc.S_WAITING or o.state == Enc.S_APPROACHING or o.state == Enc.S_MOVING_IN):
				occupe = true
				break
		if not occupe:
			tuto_vitesse_vu = true
			gel = true
			tuto = "vitesse"
			_coach({"hud": "vitesse"}, "Tous les trains présents sont à quai : plus rien à décider pour l'instant. Accélérez (touches 2 et 4) pour ne pas attendre — vous pourrez ralentir dès qu'un train s'annonce.", "Compris")


func _tuto_train_touche(t) -> void:
	if tuto != "touche1" and tuto != "touche2":
		return
	var premier := tuto == "touche1"
	var pid: Variant = _quai_desservant(t)
	var n := _comptes_quais(t)
	var piege: bool = n["lit"] > 1 and n["sert"] < n["lit"]
	tuto = "choix1" if premier else "choix2"
	var texte: String
	if premier:
		texte = "Plusieurs quais s'allument : le train peut entrer sur chacun. Mais tous ne repartent pas vers sa destination — celui-ci, oui." if piege 			else "Envoyez-le sur ce quai éclairé : il dessert sa destination."
	else:
		texte = "À nouveau plusieurs quais possibles. Celui-ci dessert sa destination." if piege 			else "Envoyez-le sur ce quai éclairé."
	_coach({"quai": pid} if pid != null else {}, texte)


func _tuto_quai_choisi() -> void:
	if tuto == "choix1":
		tuto = "retard"
		_coach({"hud": "retard"}, "Il entre et s'arrête. Ici s'affiche le retard cumulé du service — gardez-le au plus bas.", "Suivant")
	elif tuto == "choix2":
		tuto = "objectif"
		_coach({"hud": "retard"}, "Un quai occupé peut quand même être choisi : le convoi attend dehors, sans pénalité — seule compte l'heure de départ. À vous ! Terminez le service avec moins de 30 min de retard pour décrocher une étoile.", "Continuer")


func _coach_suivant() -> void:
	match tuto:
		"retard":
			tuto = "quai1"
			_cacher_coach()
			gel = false
		"aquai":
			tuto = "attente2"
			_cacher_coach()
			gel = false
		"objectif":
			tuto = "libre"
			_cacher_coach()
			Sauvegarde.set_accueilli(true)
			gel = false
		"feu", "vitesse":
			tuto = "libre"
			_cacher_coach()
			gel = false


## Le rectangle d'écran de la cible du repère, ou Rect2() sans cible visible.
func _rect_cible() -> Rect2:
	if coach_cible.has("train"):
		var id: String = coach_cible["train"]
		if not positions.has(id) or positions[id].is_empty():
			return Rect2()
		var tete: Dictionary = positions[id][0]
		return Rect2(tete["x"] - Geo.CAR_LEN / 2.0, tete["y"] - Geo.CAR_H / 2.0, Geo.CAR_LEN, Geo.CAR_H)
	if coach_cible.has("quai"):
		for q in G["platforms"]:
			if q["id"] == coach_cible["quai"]:
				return Rect2(Geo.PLAT_X1, float(q["cy"]) - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
		return Rect2()
	if coach_cible.has("hud"):
		return Rect2(700 + 18, 18, 70, 34) if coach_cible["hud"] == "retard" else Rect2(1400 - 28 - 90, 20, 90, 28)
	return Rect2()


## La bulle se pose sous la cible si elle est haute, au-dessus sinon, et
## reste entièrement à l'écran.
func _placer_bulle() -> void:
	if not bulle.visible:
		return
	var rc := _rect_cible()
	var taille := bulle.get_combined_minimum_size()
	if rc == Rect2():
		bulle.position = Vector2(700 - taille.x / 2, 760 - taille.y - 26)
		return
	var dessous: bool = rc.get_center().y < 760 * 0.5
	var x: float = clamp(rc.get_center().x - taille.x / 2, 8.0, 1400.0 - taille.x - 8.0)
	var y: float = rc.end.y + 22 if dessous else rc.position.y - 22 - taille.y
	bulle.position = Vector2(x, y)


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
