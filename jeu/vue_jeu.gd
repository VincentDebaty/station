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
const Sty := preload("res://jeu/style.gd")

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
var zones_hud: Dictionary = {}       # les rectangles du bandeau, pour le doigt
var bulle: PanelContainer
var bulle_texte: Label
var bulle_bouton: Button
var accueil: Control


func _ready() -> void:
	# Les deux facteurs d'échelle se lisent sur l'écran réel (jeu/style.gd) :
	# le tactile grossit les cibles du plan, le bandeau garde sa taille physique.
	Sty.calibrer(get_viewport())
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
	plan.cartouche = false
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
	plan.cartouche = false
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
# LE DESSIN — l'habillage du prototype, valeur pour valeur.
# ------------------------------------------------------------------
# Chaque rayon, épaisseur, couleur et durée vient de css/station.css ou de
# js/render.js, par jeu/style.gd. Ce qui était un `filter: drop-shadow` du web
# devient ici une ombre de StyleBoxFlat (pour une boîte) ou des passes larges
# et translucides sous le trait (pour une ligne) : Godot n'a pas de filtre de
# flou en 2D, et le prototype lui-même évitait les filtres animés — ils ne
# s'affichent pas de façon fiable sur iOS (voir .state-ring, css/station.css).
static func fmt(minute: float) -> String:
	var m := int(max(0.0, floor(minute)))
	return "%02d:%02d" % [7 + m / 60, m % 60]


func _draw() -> void:
	if enc == null:
		return
	var sel = enc.selected
	# La ville d'origine du convoi choisi ressort dans le gril (.beam-lit) ;
	# c'est le plan, dessous, qui porte le faisceau.
	if plan != null:
		var f: String = String(sel.from) if sel != null else ""
		if plan.faisceau != f:
			plan.faisceau = f
			plan.queue_redraw()
	var t := Time.get_ticks_msec() / 1000.0
	_dessiner_quais(sel, t)
	_dessiner_itineraires()
	_dessiner_convois(sel, t)
	_dessiner_signaux(t)
	_dessiner_badges(t)
	_dessiner_hud(t)
	_dessiner_coach(t)
	_dessiner_fin()


# --- les quais : les états, peints sur la pilule du plan ---------------------
func _train_a_quai(pid) -> Variant:
	for t in enc.trains:
		if t.platform == pid and (t.state == Enc.S_DWELL or t.state == Enc.S_MOVING_IN):
			return t
	return null


func _quai_en_defaut(pid) -> bool:
	for t in enc.trains:
		if t.platform == pid and t.wrong_platform and t.state == Enc.S_DWELL:
			return true
	return false


func _train_promis(pid) -> Variant:
	for t in enc.trains:
		if t.target == pid and (t.state == Enc.S_WAITING or t.state == Enc.S_APPROACHING):
			return t
	return null


func _boucle(contour: PackedVector2Array) -> PackedVector2Array:
	var b := contour.duplicate()
	b.append(contour[0])
	return b


## Les hachures du quai fermé : le motif 8 × 8 de js/render.js, une barre
## verticale toutes les huit unités.
func _hachures(r: Rect2, col: Color) -> void:
	var inner := r.grow(-4)
	var x := inner.position.x
	while x < inner.end.x:
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), col, 2.0)
		x += 8.0


func _dessiner_quais(sel, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * TAU / 1.2)        # elig-pulse : 1,2 s
	var pulse_lent := 0.5 + 0.5 * sin(t * TAU / 2.2)   # .eligible.busy : 2,2 s
	var pulse_faute := 0.5 + 0.5 * sin(t * TAU / 1.0)  # wrong-pulse : 1 s
	for q in G["platforms"]:
		var pid = q["id"]
		var r := Rect2(Geo.PLAT_X1, float(q["cy"]) - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
		var contour := Sty.rect_arrondi(r, 10)

		# FERMÉ : pilule éteinte, hachures, numéro estompé, heure de réouverture
		if enc.platform_closed(pid):
			draw_colored_polygon(contour, Sty.QUAI_FERME)
			_hachures(r, Color(Sty.ROUGE, 0.5))
			draw_polyline(_boucle(contour), Sty.QUAI_FERME_BORD, 1.5, true)
			Sty.texte_centre(self, Sty.sans(600), 24, r.get_center(), str(int(pid)), Color(Sty.TEXTE, 0.28))
			var fin := ""
			for ev in enc.events:
				if ev.get("type") == "closure" and ev["plat"] == pid and ev["revealed"] and not ev["cleared"]:
					fin = "fermé jusqu'à " + fmt(float(ev["end"]))
			if fin != "":
				var haut := Vector2(Geo.PLAT_MID, r.position.y - 13)
				Sty.texte_centre(self, Sty.mono(600), 13, haut, fin, Color(Sty.ROUGE, 0.30), 7, Color(Sty.ROUGE, 0.30))
				Sty.texte_centre(self, Sty.mono(600), 13, haut, fin, Sty.ROUGE)
			continue

		# ÉLIGIBLE : tous les quais atteignables depuis l'origine du convoi
		# choisi, au même titre — on n'indique PAS lequel dessert vraiment.
		var eligible: bool = sel != null and sel.target == null \
			and enc.links.get(sel.from, []).has(pid) and not enc.platform_claimed(pid)
		if eligible:
			var col := Color(String(G["dest_color"][sel.to]))
			var occupe: bool = enc.platform_occupied(pid)
			var p: float = pulse_lent if occupe else pulse
			# le quai libre se teinte (color-mix 14 %) ; l'occupé garde son
			# dégradé et souffle plus lentement : « oui, mais pas tout de suite »
			if not occupe:
				draw_colored_polygon(contour, Sty.QUAI_ELIGIBLE_FOND.lerp(col, 0.14))
				# la teinte recouvre le numéro peint par le plan : on le repose
				Sty.texte_centre(self, Sty.sans(600), 24, r.get_center(), str(int(pid)), Sty.TEXTE)
			var larg: float = 2.5 + 0.9 * p
			Sty.pointille(self, contour, Color(col, 0.08 + 0.20 * p), larg + 8.0, 7, 5)
			Sty.pointille(self, contour, col, larg, 7, 5)
		else:
			# OCCUPÉ : liseré à la couleur du convoi présent
			var occupant = _train_a_quai(pid)
			if occupant != null:
				draw_polyline(_boucle(contour), Color(String(G["dest_color"][occupant.to])), 2.5, true)
			# EN DÉFAUT : un convoi y stationne sans pouvoir repartir
			if _quai_en_defaut(pid):
				draw_polyline(_boucle(contour), Sty.ROUGE, 2.5 + 1.1 * pulse_faute, true)

		# PROMIS : un convoi encore dehors l'a choisi. Liseré INTÉRIEUR, à SA
		# couleur, qui défile vers le quai — le quai est pris même s'il paraît
		# libre. Il se lit en même temps que le liseré d'occupation.
		var promis = _train_promis(pid)
		if promis != null:
			var interieur := Sty.rect_arrondi(Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10)), 6)
			Sty.pointille(self, interieur, Color(String(G["dest_color"][promis.to])), 2.4, 6, 6, t * 10.9)


# --- les itinéraires --------------------------------------------------------
func _dessiner_itineraires() -> void:
	for pid in enc.active_routes:
		var t = enc.active_routes[pid]
		var p: Dictionary = enc.paths[pid]
		Sty.trait_halo(self, Geo.vers_vector2(p["xs"], p["ys"]), Color(String(G["dest_color"][t.to])), 5.0, 4.0)
	# l'itinéraire PROMIS, en attente d'entrée : pointillé 10 8 à 55 %
	for t in enc.trains:
		if t.target != null and (t.state == Enc.S_WAITING or t.state == Enc.S_APPROACHING):
			var pid := "in:%s:%d" % [t.from, int(t.target)]
			if enc.paths.has(pid) and not enc.active_routes.has(pid):
				var p: Dictionary = enc.paths[pid]
				Sty.pointille(self, Geo.vers_vector2(p["xs"], p["ys"]),
					Color(String(G["dest_color"][t.to]), 0.55), 5.0, 10, 8, 0.0, false)


# --- les convois ------------------------------------------------------------
## L'embarquement : la part REMPLIE du convoi, de 0 à 1. Les voyageurs montent
## de la tête vers la queue entre l'arrivée réelle et l'heure de départ
## (js/render.js, updateBoarding). Hors arrêt, ou sur un mauvais quai, le
## convoi reste plein : il repartira sans que personne ne descende.
func _embarquement(t) -> float:
	if t.freight or t.state != Enc.S_DWELL or t.actual_arr == null:
		return 1.0
	if not enc.paths.has("out:%s:%d" % [t.to, int(t.platform)]):
		return 1.0
	var arr: float = float(t.actual_arr)
	var fin: float = max(t.dep, arr + Geo.MIN_DWELL)
	var denom: float = fin - arr
	return 1.0 if denom <= 0.0 else clampf((enc.game_min - arr) / denom, 0.0, 1.0)


func _dessiner_convois(sel, t: float) -> void:
	var anneau := 0.65 + 0.35 * sin(t * TAU / 1.1)      # ring-pulse : 1 → .3
	var pret := 0.5 + 0.5 * sin(t * TAU / 1.1)          # .train.ready
	for tr in enc.trains:
		if not positions.has(tr.id):
			continue
		var pos: Array = positions[tr.id]
		var n := pos.size()
		if n == 0:
			continue
		var col := Color(String(G["dest_color"][tr.to]))
		var choisi: bool = tr == sel
		var attend: bool = tr.state == Enc.S_WAITING or tr.state == Enc.S_APPROACHING
		# la rotation est bridée à l'endroit (Geo.path_point) : le +x local
		# pointe toujours à droite de l'écran, la tête peut donc être d'un côté
		# ou de l'autre — c'est ce qui décide du côté « vide » des voitures.
		var tete_a_droite: bool = n < 2 or float(pos[0]["x"]) >= float(pos[1]["x"])
		var plein := _embarquement(tr)
		for i in range(n):
			var p: Dictionary = pos[i]
			# La HAUTEUR grossit au doigt, la LONGUEUR jamais : CAR_LEN tient à
			# l'espacement du gril, l'étirer ferait se chevaucher les convois.
			var h: float = (Geo.CAR_H if i == 0 else Geo.CAR_H - 4.0) * Sty.UIK
			var rayon: float = (8.0 if i == 0 else 5.0) * Sty.UIK
			var r := Rect2(-Geo.CAR_LEN / 2.0, -h / 2.0, Geo.CAR_LEN, h)
			draw_set_transform(Vector2(p["x"], p["y"]), deg_to_rad(p["ang"]), Vector2.ONE)

			# LE HALO D'ÉTAT, sous la caisse : quatre couches concentriques de
			# plus en plus larges et transparentes. C'est le signal PRINCIPAL de
			# sélection, et il ne dépend d'aucun filtre.
			if choisi or tr.holding:
				var teinte: Color = Color.WHITE if choisi else Sty.AMBRE
				var opac: float = anneau if choisi else anneau * 0.9
				var b := _boucle(Sty.rect_arrondi(r, rayon))
				for couche in [[16.0, 0.10], [10.0, 0.18], [5.5, 0.34], [2.5, 0.75]]:
					draw_polyline(b, Color(teinte, float(couche[1]) * opac), float(couche[0]) * Sty.UIK, true)

			# LA CAISSE, et son halo à la couleur de la DESTINATION — y compris
			# pour un fret, dont la caisse est grise mais le halo coloré.
			var caisse: Color = Sty.FRET if (tr.freight and i > 0) else col
			if i > 0 and not tr.freight:
				caisse.a = 0.72
			var halo := 7.0
			if choisi:
				halo = 14.0
			elif attend and not tr.freight:
				halo = 7.0 + 6.0 * pret
			draw_style_box(Sty.boite(caisse, caisse, rayon, 0, halo, Color(col, 0.30)), r)

			# LE MASQUE D'EMBARQUEMENT : la portion vide, côté queue, qui recule
			# à mesure qu'on approche du départ.
			if plein < 1.0:
				var frac: float = clampf(plein * n - i, 0.0, 1.0)
				var w: float = (1.0 - frac) * Geo.CAR_LEN
				if w > 0.5:
					var x: float = -Geo.CAR_LEN / 2.0 if tete_a_droite else Geo.CAR_LEN / 2.0 - w
					draw_style_box(Sty.boite(Sty.MASQUE, Sty.MASQUE, rayon, 0),
						Rect2(x, -h / 2.0, w, h))

			# LE CONTOUR : la silhouette reste lisible, wagon plein ou vide. Sur
			# un fret il est épais et opaque : c'est LUI le signe distinctif.
			draw_polyline(_boucle(Sty.rect_arrondi(r, rayon)),
				Color(col, 1.0 if tr.freight else 0.85), (2.6 if tr.freight else 1.4) * Sty.UIK, true)

			# La loco porte l'initiale de sa destination, fret compris.
			if i == 0:
				Sty.texte_centre(self, Sty.sans(700), int(round(12 * Sty.UIK)), Vector2.ZERO,
					String(G["dest_abbr"].get(tr.to, "")), Sty.ETIQUETTE_TRAIN)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- le signal d'arrêt ------------------------------------------------------
## Un convoi prêt dont la voie de sortie est prise ne doit pas rester muet,
## sinon son immobilité se lit comme un bug. On plante un vrai signal devant sa
## motrice : mât, cible à deux feux, le rouge allumé et pulsé (js/render.js,
## signalNode). Il reste tant que le convoi est retenu.
func _dessiner_signaux(t: float) -> void:
	var lampe := 0.45 + 0.55 * (0.5 + 0.5 * sin(t * TAU / 1.1))   # sig-pulse
	for tr in enc.trains:
		if not tr.holding or tr.state != Enc.S_DWELL or not positions.has(tr.id):
			continue
		var pos: Array = positions[tr.id]
		if pos.size() < 2:
			continue
		var tete := Vector2(float(pos[0]["x"]), float(pos[0]["y"]))
		var dir: float = 1.0 if tete.x >= float(pos[1]["x"]) else -1.0
		var k := Sty.UIK
		var o := tete + Vector2(dir * (Geo.CAR_LEN / 2.0 + 14.0 * k), 2.0 * k)
		draw_style_box(Sty.boite(Color("#55617a"), Color("#55617a"), 1.3 * k, 0),
			Rect2(o.x - 1.3 * k, o.y - 2 * k, 2.6 * k, 16 * k))                       # le mât
		draw_style_box(Sty.boite(Color("#0e1420"), Color("#55617a"), 4 * k, 1.2 * k),
			Rect2(o.x - 7 * k, o.y - 22 * k, 14 * k, 21 * k))                         # la cible
		draw_circle(o + Vector2(0, -16 * k), 3.6 * k, Color(Sty.ROUGE, lampe))        # le rouge
		draw_circle(o + Vector2(0, -6.5 * k), 3.6 * k, Color("#1c2740"))              # le vert, éteint


# --- les badges d'heure -----------------------------------------------------
## Le cadran de l'horloge, aiguilles figées sur 10 h 10 : la pose qui se lit le
## mieux en tout petit. Il dit « heure de départ » sans mot à lire, et s'efface
## quand le badge bascule sur le retard — « +3 min » n'est plus une heure.
func _cadran(centre: Vector2, col: Color, k: float = 1.0) -> void:
	draw_arc(centre, 5.4 * k, 0.0, TAU, 24, col, 1.4 * k, true)
	draw_line(centre, centre + Vector2(0, -3.2 * k), col, 1.4 * k, true)
	draw_line(centre, centre + Vector2(2.6 * k, 1.6 * k), col, 1.4 * k, true)


func _dessiner_badges(t: float) -> void:
	var clign := 0.22 + 0.78 * (0.5 + 0.5 * sin(t * TAU / 0.9))   # badge-blink
	for tr in enc.trains:
		if not positions.has(tr.id):
			continue
		# jamais pour le fret : ce qui le distingue, c'est justement l'absence
		# d'heure de départ.
		var montre: bool = not tr.freight and not tr.wrong_platform \
			and tr.state != Enc.S_MOVING_OUT and tr.state != Enc.S_DONE \
			and not (tr.state == Enc.S_APPROACHING and not tr.settled)
		if not montre:
			continue
		var late: float = Enc.lateness(tr, enc.game_min)
		var en_retard: bool = late >= 1
		var txt: String = ("+%d min" % int(floor(late))) if en_retard else fmt(tr.dep)
		var col: Color = Sty.ROUGE if en_retard else (Sty.AMBRE if late > -3 else Sty.VERT)
		var k := Sty.UIK
		var police := Sty.mono(700 if en_retard else 600)
		var taille := int(round(12 * k))
		var w := police.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var cadran: bool = not en_retard
		var large: float = w + 24.0 * k + (14.0 * k if cadran else 0.0)
		var tete: Dictionary = positions[tr.id][0]
		var centre := Vector2(float(tete["x"]), float(tete["y"]) - 40.0 * k)
		var r := Rect2(centre.x - large / 2.0, centre.y - 10.0 * k, large, 20.0 * k)
		# un convoi encore à l'arrêt dont le retard court réclame un aiguillage :
		# le badge clignote (en opacité seule).
		var a: float = clign if (en_retard and not tr.settled) else 1.0
		draw_style_box(Sty.boite(Color(Sty.BADGE_FOND, Sty.BADGE_FOND.a * a), Color(col, a), 6 * k, 1.2 * k), r)
		var x := r.position.x + 12.0 * k
		if cadran:
			_cadran(Vector2(x, centre.y), Color(col, a), k)
			x += 14.0 * k
		Sty.texte_centre(self, police, taille, Vector2(x + w / 2.0, centre.y), txt, Color(col, a))


# --- le bandeau -------------------------------------------------------------
## La taille RÉELLE de la scène. 1400 × 760 n'est que la base : le viewport
## s'étire (stretch « expand »), et sur un téléphone il est plus large. Le
## bandeau s'ancre donc sur les bords réels, pas sur la base.
func size_ecran() -> Vector2:
	return get_viewport_rect().size


## Une chip de verre dépoli : le gabarit commun du bandeau (#hud-clock,
## #station-tag, les trois boutons) — fond rgba(21,29,46,.55), liseré #2a3550,
## coins de 12. Le flou du web n'existe pas ici : le fond translucide seul
## suffit, les voies restent lisibles dessous.
func _chip(r: Rect2, bord: Color = Sty.BORD, k: float = 1.0) -> void:
	draw_style_box(Sty.boite(Sty.VERRE, bord, 12 * k, max(1.0, k)), r)


func _dessiner_hud(t: float) -> void:
	var sans := Sty.sans()
	var gras := Sty.sans(600)
	# Le bandeau garde sa TAILLE PHYSIQUE d'un écran à l'autre : au bureau
	# k vaut 1 et rien ne change ; sur un téléphone il grossit d'autant que le
	# viewport a été étiré (jeu/style.gd, calibrer).
	var k := Sty.HUD_K
	var ti := func(v: float) -> int: return int(round(v * k))
	zones_hud.clear()

	# --- le cartouche de gare, en haut à gauche : c'est le bouton RETOUR ------
	var pays := Donnees.pays_de(String(fiche.get("country", "")))
	var drapeau := String(pays.get("drapeau", ""))
	var nom := String(fiche.get("name", ""))
	var d := int(fiche_jouee.get("difficulty", fiche.get("difficulty", 1)))
	# Un drapeau est une paire de caractères combinés : la police système en
	# rend un glyphe unique dont la largeur mesurée ment (mesuré le 3 septembre
	# 2026 : le nom débordait de la chip). On lui réserve sa place.
	var w_fl: float = max(20.0 * k, sans.get_string_size(drapeau, HORIZONTAL_ALIGNMENT_LEFT, -1, ti.call(15)).x)
	var w_nm := gras.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, ti.call(13)).x
	var w_pips := (5.0 * 4.0 + 4.0 * 3.0) * k
	var large := (10.0 + 14.0 + 6.0) * k + w_fl + 6.0 * k + w_nm + 3.0 * k + w_pips + 13.0 * k
	var chip := Rect2(4 * k, 10 * k, large, 34 * k)
	zones_hud["carte"] = chip
	_chip(chip, Sty.BORD, k)
	var cy := chip.position.y + chip.size.y / 2.0
	var x := chip.position.x + 10.0 * k
	Sty.texte_centre(self, sans, ti.call(22), Vector2(x + 7 * k, cy - 1 * k), "‹", Sty.MUET)
	x += (14.0 + 6.0) * k
	Sty.texte_centre(self, sans, ti.call(15), Vector2(x + w_fl / 2.0, cy), drapeau, Sty.TEXTE)
	x += w_fl + 6.0 * k
	Sty.texte_centre(self, gras, ti.call(13), Vector2(x + w_nm / 2.0, cy), nom, Sty.TEXTE)
	x += w_nm + 3.0 * k
	# la difficulté : la MÊME jauge à cinq crans que partout dans le jeu
	for i in range(5):
		draw_style_box(Sty.boite(Sty.AMBRE if i < d else Sty.PIP_ETEINT, Color.TRANSPARENT, 1.5 * k, 0),
			Rect2(x + i * 7.0 * k, cy - 5.0 * k, 4.0 * k, 10.0 * k))

	# --- l'horloge, centrée : heure, retard, et la jauge du service ----------
	var mono := Sty.mono(600)
	var horloge := fmt(enc.game_min)
	var retard := enc.live_delay()
	var txt_r := "+%d" % int(retard)
	var w_h := Sty.largeur_espacee(mono, ti.call(21), horloge, 1.0 * k)
	var w_r := mono.get_string_size(txt_r, HORIZONTAL_ALIGNMENT_LEFT, -1, ti.call(14)).x
	var w_chip := 13.0 * k + w_h + 8.0 * k + w_r + 13.0 * k
	var milieu := size_ecran().x / 2.0
	var ch := Rect2(milieu - w_chip / 2.0, 10 * k, w_chip, 38 * k)
	zones_hud["horloge"] = ch
	_chip(ch, Sty.ACCENT if (pause or gel) else Sty.BORD, k)
	var base := ch.position.y + 5.0 * k + mono.get_ascent(ti.call(21))
	Sty.texte_espace(self, mono, ti.call(21), Vector2(ch.position.x + 13.0 * k, base), horloge, Sty.TEXTE, 1.0 * k)
	var col_r: Color = Sty.VERT if retard < 10 else (Sty.AMBRE if retard < 30 else Sty.ROUGE)
	draw_string(mono, Vector2(ch.position.x + 13.0 * k + w_h + 8.0 * k, base), txt_r,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ti.call(14), col_r)
	# la jauge : l'horloge se remplit à mesure que les convois quittent le quai
	var partis := 0
	for tr in enc.trains:
		if tr.state == Enc.S_DONE:
			partis += 1
	var part: float = float(partis) / float(max(1, enc.trains.size()))
	var jauge := Rect2(ch.position.x + 10.0 * k, ch.end.y - 7.0 * k, ch.size.x - 20.0 * k, 3.0 * k)
	draw_style_box(Sty.boite(Color(Sty.ACCENT, 0.14), Color.TRANSPARENT, 2 * k, 0), jauge)
	if part > 0.0:
		draw_style_box(Sty.boite(Sty.ACCENT, Color.TRANSPARENT, 2 * k, 0),
			Rect2(jauge.position, Vector2(jauge.size.x * part, jauge.size.y)))
	# « EN PAUSE », sous l'horloge — et c'est une cible : on la touche pour
	# reprendre, comme la pilule du prototype.
	if pause or gel:
		var etiq := "EN PAUSE"
		var w_e := Sty.largeur_espacee(Sty.sans(700), ti.call(12), etiq, 1.5 * k)
		var re := Rect2(milieu - (w_e + 24.0 * k) / 2.0, ch.end.y + 5.0 * k, w_e + 24.0 * k, 22 * k)
		if not gel:
			zones_hud["pause"] = re
		draw_style_box(Sty.boite(Color(Sty.ACCENT, 0.14), Sty.ACCENT, 8 * k, 1 * k), re)
		Sty.texte_espace(self, Sty.sans(700), ti.call(12),
			Vector2(re.position.x + 12.0 * k, re.get_center().y + Sty.sans(700).get_ascent(ti.call(12)) / 2.0 - 1 * k),
			etiq, Sty.ACCENT, 1.5 * k)

	# --- les trois boutons, en haut à droite ---------------------------------
	var bx := size_ecran().x - 4.0 * k - 34.0 * k
	for bouton in [["gear", ""], ["speed", "%dx" % int(vitesse)], ["play", ""]]:
		var r := Rect2(bx, 10 * k, 34 * k, 34 * k)
		zones_hud[bouton[0]] = r
		var actif: bool = bouton[0] == "speed" and vitesse > 1.0
		_chip(r, Sty.ACCENT if actif else Sty.BORD, k)
		var c := r.get_center()
		match bouton[0]:
			"speed":
				Sty.texte_espace(self, Sty.mono(700), ti.call(13),
					Vector2(c.x - Sty.largeur_espacee(Sty.mono(700), ti.call(13), bouton[1], 0.5 * k) / 2.0,
						c.y + Sty.mono(700).get_ascent(ti.call(13)) / 2.0 - 1 * k),
					bouton[1], Sty.ACCENT if actif else Sty.TEXTE, 0.5 * k)
			"play":
				if pause:
					draw_colored_polygon(PackedVector2Array([
						c + Vector2(-4, -6) * k, c + Vector2(7, 0) * k, c + Vector2(-4, 6) * k]), Sty.TEXTE)
				else:
					draw_rect(Rect2(c.x - 5 * k, c.y - 6 * k, 3.5 * k, 12 * k), Sty.TEXTE, true)
					draw_rect(Rect2(c.x + 1.5 * k, c.y - 6 * k, 3.5 * k, 12 * k), Sty.TEXTE, true)
			"gear":
				draw_arc(c, 6.0 * k, 0.0, TAU, 24, Sty.TEXTE, 1.8 * k, true)
				for i in range(6):
					var a: float = TAU * float(i) / 6.0
					var u := Vector2(cos(a), sin(a))
					draw_line(c + u * 6.5 * k, c + u * 9.0 * k, Sty.TEXTE, 1.8 * k, true)
		bx -= (34.0 + 8.0) * k

	# --- la ligne d'aide, en bas : hors prototype, elle porte la graine ------
	# Le jeu web est « 100 % visuel » et n'a aucune bande de texte. Celle-ci est
	# un outil de mise au point — c'est elle qui donne la graine à citer dans un
	# retour de test. Volontairement discrète, et elle partira au moteur final.
	# Elle ne suit PAS le facteur du bandeau : grossie, elle déborde de l'écran
	# d'un téléphone (mesuré le 3 septembre 2026). Petite, elle reste lisible
	# quand on la cherche et invisible quand on joue — ce qu'on veut d'elle.
	draw_string(sans, Vector2(18, size_ecran().y - 14),
		"clic convoi → clic quai   ·   espace pause   ·   1 2 4 vitesse   ·   R rejouer   ·   graine %d, journée en %d ms   ·   %s"
			% [graine, duree_generation_ms, _niveau_texte()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Sty.MUET, 0.55))


# --- le repère du tutoriel --------------------------------------------------
## Le PROJECTEUR : tout l'écran s'assombrit sauf la cible (#coach-ring, dont
## l'ombre de 9999 px fait exactement cela sur le web). Sans lui, le repère
## désigne sans isoler, et l'œil continue de partir ailleurs.
func _dessiner_coach(t: float) -> void:
	if coach_cible.is_empty():
		return
	var rc := _rect_cible()
	if rc == Rect2():
		return
	var trou := rc.grow(8)
	var e := size_ecran()
	draw_rect(Rect2(0, 0, e.x, trou.position.y), Sty.VOILE, true)
	draw_rect(Rect2(0, trou.end.y, e.x, e.y - trou.end.y), Sty.VOILE, true)
	draw_rect(Rect2(0, trou.position.y, trou.position.x, trou.size.y), Sty.VOILE, true)
	draw_rect(Rect2(trou.end.x, trou.position.y, e.x - trou.end.x, trou.size.y), Sty.VOILE, true)
	var pulse := 0.5 + 0.5 * sin(t * TAU / 1.2)
	var b := _boucle(Sty.rect_arrondi(trou, 12))
	draw_polyline(b, Color(Sty.ACCENT, 0.10 + 0.15 * pulse), 14.0, true)
	draw_polyline(b, Color(Sty.ACCENT, 0.25 + 0.25 * pulse), 7.0, true)
	draw_polyline(b, Sty.ACCENT.lerp(Sty.ACCENT_CLAIR, pulse), 2.5, true)
	# l'ergot de la bulle, pointé vers la cible
	if bulle != null and bulle.visible:
		var br := Rect2(bulle.position, bulle.size)
		var dessous: bool = br.position.y > trou.end.y
		var cx: float = clampf(trou.get_center().x, br.position.x + 14.0, br.end.x - 14.0)
		var y: float = br.position.y if dessous else br.end.y
		var s: float = 1.0 if dessous else -1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 8, y), Vector2(cx + 8, y), Vector2(cx, y - s * 8)]), Sty.ACCENT)


# --- la fin de service, seul à l'écran --------------------------------------
# L'application, elle, lit le relevé sur la carte du ruban.
func _dessiner_fin() -> void:
	if not enc.ended or app != null:
		return
	var e := size_ecran()
	draw_rect(Rect2(Vector2.ZERO, e), Color(Sty.FOND, 0.82), true)
	var r: Dictionary = enc.resultat
	var titre: String = "Service interrompu" if r.get("failed", false) \
		else ("Sans faute !" if r.get("perfect", false) else ("Fin du service" if r.get("win", false) else "Objectif manqué"))
	var etoiles := "★".repeat(int(r.get("stars", 0))) + "☆".repeat(3 - int(r.get("stars", 0)))
	var c := e / 2.0
	Sty.texte_centre(self, Sty.sans(600), 34, c - Vector2(0, 20), titre, Sty.TEXTE)
	Sty.texte_centre(self, Sty.sans(), 18, c + Vector2(0, 20),
		"%s   ·   retard cumulé %d min" % [etoiles, int(r.get("d", 0))], Sty.AMBRE)
	Sty.texte_centre(self, Sty.sans(), 14, c + Vector2(0, 60), "R pour rejouer", Sty.MUET)


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
		# LE BANDEAU D'ABORD. Sans clavier — sur un téléphone — la pause, la
		# vitesse et le retour à la carte ne sont atteignables que par ces
		# boutons ; ils étaient dessinés sans être cliquables.
		if _clic_bandeau(m):
			return
		if enc.ended or tuto == "accueil":
			return
		# un convoi ?
		for t in enc.trains:
			if not positions.has(t.id):
				continue
			for p in positions[t.id]:
				# la zone de clic grossit avec le doigt (js/render.js, hitH × UIK)
				if Vector2(p["x"], p["y"]).distance_to(m) <= (Geo.CAR_LEN / 2.0 + 10.0) * Sty.UIK:
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
	# #coach-bubble : panneau, liseré teal, coins de 12, ombre portée,
	# texte centré à 15 px. Sa largeur ne dépend que de son texte (le
	# `width: max-content` du web), plafonnée à 400 px comme la feuille.
	bulle = PanelContainer.new()
	var st := Sty.boite(Sty.PANNEAU, Sty.ACCENT, 12, 1, 22, Color(0, 0, 0, 0.55))
	st.set_content_margin_all(14)
	st.content_margin_left = 18
	st.content_margin_right = 18
	bulle.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	bulle.add_child(v)
	bulle_texte = Label.new()
	bulle_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bulle_texte.custom_minimum_size = Vector2(364, 0)
	bulle_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bulle_texte.add_theme_font_override("font", Sty.sans())
	bulle_texte.add_theme_font_size_override("font_size", 15)
	bulle_texte.add_theme_color_override("font_color", Sty.TEXTE)
	bulle_texte.add_theme_constant_override("line_spacing", 6)
	v.add_child(bulle_texte)
	bulle_bouton = Sty.bouton("Suivant", false, 15)
	bulle_bouton.pressed.connect(_coach_suivant)
	v.add_child(bulle_bouton)
	bulle.visible = false
	add_child(bulle)

	# L'accueil : un voile sur toute la scène, et la carte au centre. Le voile
	# est un enfant direct — dans un CenterContainer il serait réduit à rien.
	# TAILLES EXPLICITES, PAS D'ANCRES : sous un Node2D, un Control aux ancres
	# pleines n'a aucun parent à remplir, et sa taille retombe à zéro — la
	# carte se centrait alors sur l'origine, hors écran, et le service restait
	# gelé derrière un voile sans bouton. Vu par Vincent au premier lancement,
	# le 3 septembre 2026 ; le lancement direct (STATION_JOUER) le masquait.
	accueil = Control.new()
	var voile := ColorRect.new()
	voile.color = VOILE
	accueil.add_child(voile)
	var centre := CenterContainer.new()
	accueil.add_child(centre)
	# La taille suit l'écran réel : le viewport s'étire, et la carte doit rester
	# centrée dessus, pas sur la base de 1400 × 760.
	for n in [accueil, voile, centre]:
		n.size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void:
		for n in [accueil, voile, centre]:
			n.size = get_viewport_rect().size)
	var carte := PanelContainer.new()
	var sc := Sty.boite(Sty.PANNEAU, Sty.ACCENT, 16, 1, 30, Color(0, 0, 0, 0.5))
	sc.set_content_margin_all(30)
	carte.add_theme_stylebox_override("panel", sc)
	carte.custom_minimum_size = Vector2(520, 0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	carte.add_child(cv)
	# .wc-badge, h1, .wc-lead, .wc-tip — les quatre lignes du prototype
	for ligne in [["Bienvenue", 12, Sty.ACCENT, 600],
			["Le poste d'aiguillage", 26, Sty.TEXTE, 600],
			["Vous dirigez la gare : faites entrer et repartir chaque train à l'heure.", 15, Sty.TEXTE, 400],
			["Je vous montre, pas à pas, avec deux trains — les repères indiquent quoi toucher. Rien ne presse.", 13, Sty.MUET, 400]]:
		var l := Label.new()
		l.text = ligne[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", Sty.sans(ligne[3]))
		l.add_theme_font_size_override("font_size", ligne[1])
		l.add_theme_color_override("font_color", ligne[2])
		l.add_theme_constant_override("line_spacing", 7)
		cv.add_child(l)
	var b := Sty.bouton("Commencer", true, 17)
	b.pressed.connect(_accueil_ferme)
	cv.add_child(b)
	centre.add_child(carte)
	accueil.visible = false
	add_child(accueil)


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
	# UN CONTROL NE RÉTRÉCIT PAS DE LUI-MÊME : après un long message avec
	# bouton, une phrase courte gardait le cadre de la précédente — « le cadre
	# du message est fort grand », Vincent, 3 septembre 2026.
	bulle.reset_size()
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
		# les vraies zones du bandeau, telles que le dernier rendu les a posées
		if coach_cible["hud"] == "vitesse":
			return zones_hud.get("speed", Rect2())
		return zones_hud.get("horloge", Rect2())
	return Rect2()


## La bulle se pose sous la cible si elle est haute, au-dessus sinon, et
## reste entièrement à l'écran.
func _placer_bulle() -> void:
	if not bulle.visible:
		return
	var rc := _rect_cible()
	var taille := bulle.get_combined_minimum_size()
	if bulle.size != taille:
		bulle.size = taille
	if rc == Rect2():
		var e0 := size_ecran()
		bulle.position = Vector2(e0.x / 2 - taille.x / 2, e0.y - taille.y - 26)
		return
	var e := size_ecran()
	var dessous: bool = rc.get_center().y < e.y * 0.5
	var x: float = clamp(rc.get_center().x - taille.x / 2, 8.0, e.x - taille.x - 8.0)
	var y: float = rc.end.y + 22 if dessous else rc.position.y - 22 - taille.y
	bulle.position = Vector2(x, y)


## Un geste sur le bandeau. Rend vrai s'il a été pris.
func _clic_bandeau(m: Vector2) -> bool:
	if zones_hud.get("carte", Rect2()).has_point(m):
		if app != null:
			app.abandonner_service()
		return true
	if zones_hud.get("play", Rect2()).has_point(m) or zones_hud.get("pause", Rect2()).has_point(m):
		if not gel:
			pause = not pause
		return true
	if zones_hud.get("speed", Rect2()).has_point(m):
		# 1 → 2 → 4 → 1, comme le bouton du prototype
		vitesse = 1.0 if vitesse >= 4.0 else vitesse * 2.0
		return true
	if zones_hud.get("gear", Rect2()).has_point(m):
		# Le menu des réglages n'existe pas encore (son, aide, recommencer) :
		# le bouton tient sa place et rejoue la journée, ce que fait « R ».
		graine = (graine * 7 + 13) % 100000
		pause = false
		_nouvelle_journee()
		return true
	return false


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
