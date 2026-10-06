extends Node2D
# ------------------------------------------------------------------
# LA TRANCHE — un niveau d'Écluses, de bout en bout : la coupe, le toucher,
# l'enchaînement d'un coup (la roue tourne, la porte pivote, l'eau passe,
# les bateaux avancent), les coups, les étoiles, la fin.
#
# Variables d'environnement, pour vérifier sans les doigts :
#   ECLUSES_NIVEAU=1-2        le niveau (1-2 par défaut)
#   ECLUSES_DEMO=1            joue la solution toute seule
#   ECLUSES_CAPTURE=<dossier> photographie l'écran à des instants choisis
#                             (avec la démo), puis quitte en donnant les
#                             images par seconde moyennes
#   ECLUSES_COUPS=0,1         la démo joue ces portes-là au lieu de la solution
#                             (pour voir un bateau se coincer)
#   ECLUSES_SURE=g,h,d,b      simule les bords d'un téléphone (en pixels de
#                             fenêtre), pour vérifier les marges sur le Mac
# ------------------------------------------------------------------

var N: Dictionary
var etat: Dictionary
var histoire := []
var canal: Canal
var camera: Camera2D
var occupe := false
var fini := false

var _lab_coups: Label
var _etoiles: Etoiles
var _b_annuler: Button
var _fin: PanelContainer
var _lab_fin: Label
var _etoiles_fin: Etoiles
var _b_annuler_fin: Button
var _calcul := 0          # numéro de la dernière recherche d'impasse : une réponse périmée est ignorée
var _images := 0
var _secondes := 0.0
var _ips: Label
var _panneau: PanelContainer   # les curseurs du rendu de l'eau (reglages.gd)
var _valeurs := {}             # clé -> [HSlider, Label de la valeur]
var _sure: Control      # la zone sûre : tout ce qu'on touche ou qu'on lit y reste

func _ready() -> void:
	var tous: Array = JSON.parse_string(FileAccess.get_file_as_string("res://niveaux.json"))["niveaux"]
	var id := OS.get_environment("ECLUSES_NIVEAU")
	if id == "": id = "1-2"
	for n in tous:
		if n["id"] == id: N = n
	_lancer()
	_interface()
	get_viewport().size_changed.connect(_cadrer)
	_cadrer()
	if OS.get_environment("ECLUSES_DEMO") != "":
		_demo()

func _lancer() -> void:
	_calcul += 1
	if canal: canal.queue_free()
	etat = Moteur.charger(N)
	histoire = []
	fini = false
	occupe = false
	canal = Canal.new()
	add_child(canal)
	move_child(canal, 0)
	canal.construire(N, etat)
	if camera == null:
		camera = Camera2D.new()
		add_child(camera)
	if _fin: _fin.hide()
	_maj()
	_cadrer()

# Les bords que l'écran mange : encoche, barre d'accueil, coins arrondis.
# iOS donne la zone sûre ; les coins arrondis mordent encore un peu dedans
# (l'iPhone de Vincent rognait le numéro du niveau et les boutons), d'où la
# marge en plus. Sur ordinateur, une simple marge.
func _marges() -> Dictionary:
	var m := {"g": 16.0, "h": 12.0, "d": 16.0, "b": 12.0}
	var vis := get_viewport().get_visible_rect().size
	var fen := Vector2(DisplayServer.window_get_size())
	var force := OS.get_environment("ECLUSES_SURE")
	var bords := []
	if force != "":
		bords = Array(force.split(",")).map(func(x): return float(x))
	elif OS.has_feature("mobile"):
		var sur := Rect2(DisplayServer.get_display_safe_area())
		if sur.size.x > 0:
			bords = [sur.position.x, sur.position.y, fen.x - sur.end.x, fen.y - sur.end.y]
	if bords.size() == 4 and fen.x > 0:
		var k := vis.x / fen.x
		m = {"g": bords[0] * k + 24.0, "h": bords[1] * k + 16.0, "d": bords[2] * k + 24.0, "b": bords[3] * k + 16.0}
	return m

func _cadrer() -> void:
	if canal == null or camera == null: return
	var ecran := get_viewport().get_visible_rect().size
	var m := _marges()
	if _sure:
		_sure.offset_left = m["g"]; _sure.offset_top = m["h"]
		_sure.offset_right = -m["d"]; _sure.offset_bottom = -m["b"]
	var r := canal.rect_monde()
	# la coupe tient entre les marges, sous les pastilles du haut et au-dessus des boutons
	# sous les pastilles du haut (88 px) et au-dessus des boutons du bas (58 px)
	var dispo := Rect2(m["g"], m["h"] + 92.0, ecran.x - m["g"] - m["d"], ecran.y - m["h"] - m["b"] - 92.0 - 64.0)
	var z := minf(dispo.size.x / r.size.x, dispo.size.y / r.size.y)
	camera.zoom = Vector2(z, z)
	camera.position = r.get_center() - (dispo.get_center() - ecran * 0.5) / z

# --- Le toucher et les coups ----------------------------------------------------------
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var i := canal.porte_sous(get_global_mouse_position())
		if i >= 0: jouer({"type": "porte", "i": i})

func jouer(a: Dictionary) -> void:
	if occupe or fini: return
	var permis := Moteur.actions(N, etat).any(func(x): return x["type"] == a["type"] and int(x.get("i", -1)) == int(a.get("i", -1)))
	if not permis: return
	occupe = true
	var avant := etat
	var r := Moteur.jouer(N, etat, a)
	histoire.append(avant)
	etat = r["etat"]
	_maj()
	# Comme une vraie écluse. Ouvrir : la roue ouvre la vanne, l'eau passe par
	# l'aqueduc, et quand les deux eaux sont au même niveau le vantail se lève.
	# Fermer : le vantail redescend d'abord, puis la roue ferme la vanne.
	if a["type"] == "porte":
		var p: Porte = canal.portes[int(a["i"])]
		if etat["ouvert"][int(a["i"])]:
			p.manoeuvrer_vanne(true)
			await get_tree().create_timer(0.4).timeout
		else:
			await canal.placer_vantaux(etat)
			p.manoeuvrer_vanne(false)
			await p.roue_finie
	canal.ecouler(avant["niv"], etat["niv"], r["flux"])
	await canal.ecoulement_fini
	await canal.placer_vantaux(etat)
	canal.deplacer(r["dep"])
	await canal.bateaux_arrives
	occupe = false
	_maj()
	var v := Moteur.verdict(N, etat)
	if v.get("fin", "") == "gagne":
		fini = true
		_montrer_fin()
	else:
		_chercher_impasse()

# Un bateau peut-il encore avancer ? (Moteur.bloque, le même que la page web,
# vérifié par l'oracle.) Une partie qui ne peut plus être gagnée continue tant
# qu'un bateau peut encore avancer ; elle n'est perdue que quand plus aucun ne
# le peut (Vincent, 6 octobre 2026 — d'abord, l'échec tombait dès que la
# victoire devenait impossible, alors que le bateau jaune pouvait encore
# descendre). La recherche tourne dans un fil de travail pour ne pas figer
# l'écran. Bloqué : les bateaux non arrivés reçoivent leur « ! », et on propose
# de rejouer.
func _chercher_impasse() -> void:
	_calcul += 1
	var mon_calcul := _calcul
	var niveau := N.duplicate(true)
	var e := etat.duplicate(true)
	var reponse := [-1]
	var tache := WorkerThreadPool.add_task(func(): reponse[0] = Moteur.bloque(niveau, e))
	while not WorkerThreadPool.is_task_completed(tache):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(tache)
	if mon_calcul != _calcul or fini or occupe: return
	if reponse[0] == 1: _coince()

func _coince() -> void:
	fini = true
	var coinces := []
	for k in N["bateaux"].size():
		var vers := int(N["bateaux"][k]["vers"])
		if etat["bateaux"][k] != vers or not Moteur.flotte(N, etat, k, vers): coinces.append(k)
	canal.alerter(coinces)
	_maj()
	await get_tree().create_timer(1.3).timeout
	if not fini: return     # on a annulé entre-temps
	_etoiles_fin.hide()
	_b_annuler_fin.show()
	_lab_fin.text = "Bateaux coincés !\nPlus aucun bateau ne peut avancer." if coinces.size() > 1 else "Bateau coincé !\nPlus aucun bateau ne peut avancer."
	_fin.show()

func annuler() -> void:
	if occupe or histoire.is_empty(): return
	_calcul += 1
	var e: Dictionary = histoire.pop_back()
	# on reconstruit la coupe sur l'état d'avant : pas d'animation à rebours
	etat = e
	var h := histoire.duplicate()
	canal.queue_free()
	canal = Canal.new()
	add_child(canal)
	move_child(canal, 0)
	canal.construire(N, etat)
	histoire = h
	fini = false
	_fin.hide()
	_maj()
	_chercher_impasse()      # l'état d'avant peut lui-même être une impasse

# --- L'interface ----------------------------------------------------------------------
# L'interface suit la maquette du niveau 14 (Vincent, 6 octobre 2026) : une
# pastille bleue pour le numéro, collée à une pastille crème pour les coups ;
# une pastille crème pour les étoiles ; des boutons du même crème. Toutes ont
# un liseré blanc et une ombre douce. Police arrondie : Arial Rounded MT Bold,
# présente d'origine sur iOS et macOS — rien à embarquer.
const CREME := Color("#f8f3ea")
const ENCRE := Color("#3d3b38")
const BLEU := Color("#2b7de0")

func _style(fond: Color, rayon := 26, ombre := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.set_corner_radius_all(rayon)
	s.content_margin_left = 22; s.content_margin_right = 22
	s.content_margin_top = 8; s.content_margin_bottom = 8
	if ombre:
		s.shadow_color = Color(0, 0, 0, 0.25); s.shadow_size = 8; s.shadow_offset = Vector2(0, 4)
	s.border_color = Color(1, 1, 1, 0.95); s.set_border_width_all(3)
	s.anti_aliasing = true
	return s

func _theme() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial Rounded MT", "Avenir Next", "Helvetica Neue"])
	f.font_weight = 700
	t.default_font = f
	return t

func _interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.theme = _theme()
	couche.add_child(racine)
	_sure = Control.new()
	_sure.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(_sure)
	# en haut à gauche : le numéro du niveau, puis les coups
	var gauche := HBoxContainer.new()
	gauche.add_theme_constant_override("separation", -20)
	_sure.add_child(gauche)
	var badge := PanelContainer.new()
	var st_badge := _style(BLEU, 20)
	st_badge.content_margin_left = 14; st_badge.content_margin_right = 14
	badge.add_theme_stylebox_override("panel", st_badge)
	badge.custom_minimum_size = Vector2(100, 88)
	var num := _label(N["id"], 44, Color.WHITE)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(num)
	var pilule := PanelContainer.new()
	var st_pil := _style(CREME, 28)
	st_pil.content_margin_left = 40; st_pil.content_margin_right = 26
	pilule.add_theme_stylebox_override("panel", st_pil)
	pilule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pilule.custom_minimum_size = Vector2(0, 70)
	_lab_coups = _label("", 34, ENCRE)
	pilule.add_child(_lab_coups)
	pilule.z_index = -1      # la pastille des coups passe sous le numéro, comme sur la maquette
	gauche.add_child(badge)
	gauche.add_child(pilule)
	# en haut à droite : les étoiles
	var cadre_et := PanelContainer.new()
	var st_et := _style(CREME, 28)
	st_et.content_margin_left = 16; st_et.content_margin_right = 16
	cadre_et.add_theme_stylebox_override("panel", st_et)
	_etoiles = Etoiles.new()
	_etoiles.taille = 52.0
	cadre_et.add_child(_etoiles)
	_sure.add_child(cadre_et)
	cadre_et.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	cadre_et.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# en bas à droite : annuler, recommencer
	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 10)
	_b_annuler = _bouton("Annuler", annuler)
	boutons.add_child(_b_annuler)
	boutons.add_child(_bouton("Recommencer", _lancer))
	_sure.add_child(boutons)
	boutons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	boutons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	boutons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# la fin
	_fin = PanelContainer.new()
	var st_fin := _style(CREME, 30)
	st_fin.content_margin_left = 40; st_fin.content_margin_right = 40
	st_fin.content_margin_top = 26; st_fin.content_margin_bottom = 26
	_fin.add_theme_stylebox_override("panel", st_fin)
	# en bas, sur la terre, au-dessus des boutons : les bateaux et leurs « ! »
	# restent visibles au-dessus de la carte
	_fin.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_fin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fin.offset_bottom = -80.0
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_etoiles_fin = Etoiles.new()
	_etoiles_fin.taille = 72.0
	_etoiles_fin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_etoiles_fin)
	_lab_fin = _label("", 28, ENCRE)
	_lab_fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_lab_fin)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	_b_annuler_fin = _bouton("Annuler le coup", annuler)
	actions.add_child(_b_annuler_fin)
	actions.add_child(_bouton("Rejouer", _lancer))
	col.add_child(actions)
	_fin.add_child(col)
	_fin.hide()
	_sure.add_child(_fin)
	# en bas à gauche : le panneau des réglages (replié), son bouton, et les
	# images par seconde dans les versions de test
	var coin := VBoxContainer.new()
	coin.add_theme_constant_override("separation", 8)
	_sure.add_child(coin)
	coin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	coin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panneau = _panneau_reglages()
	_panneau.hide()
	coin.add_child(_panneau)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 14)
	coin.add_child(ligne)
	if not OS.has_feature("movie"):
		var defaut := _bouton("Valeurs de départ", func(): Reglages.remettre(); _maj_valeurs(true))
		defaut.hide()
		ligne.add_child(_bouton("Réglages", func():
			_panneau.visible = not _panneau.visible
			defaut.visible = _panneau.visible))
		ligne.add_child(defaut)
	if OS.is_debug_build() and not OS.has_feature("movie"):
		_ips = _label("", 16, Color(1, 1, 1, 0.85))
		ligne.add_child(_ips)
	_maj()

# Un curseur par réglage de reglages.gd, sa valeur affichée à côté : Vincent
# cherche le bon dosage au doigt et n'a qu'à recopier les chiffres.
func _panneau_reglages() -> PanelContainer:
	var p := PanelContainer.new()
	var st := _style(Color(0.97, 0.95, 0.9, 0.8), 16)
	st.content_margin_left = 16; st.content_margin_right = 16
	st.content_margin_top = 8; st.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", st)
	# deux colonnes de curseurs : le panneau reste bas, posé sur la terre du bas
	# de l'écran, et laisse voir l'eau qu'on règle
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	var grille := GridContainer.new()
	grille.columns = 6
	grille.add_theme_constant_override("h_separation", 10)
	grille.add_theme_constant_override("v_separation", 0)
	col.add_child(grille)
	for k in Reglages.CURSEURS:
		var c: Array = Reglages.CURSEURS[k]
		var nom := _label(c[0], 16, Color("#2a3a40"))
		nom.custom_minimum_size = Vector2(170, 0)
		var curseur := HSlider.new()
		curseur.min_value = c[2]; curseur.max_value = c[3]; curseur.step = c[4]
		curseur.value = Reglages.v(k)
		curseur.custom_minimum_size = Vector2(190, 42)
		curseur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var val := _label("", 16, Color("#1f6fd1"))
		val.custom_minimum_size = Vector2(48, 0)
		curseur.value_changed.connect(func(x): Reglages.regler(k, x); _maj_valeurs())
		grille.add_child(nom); grille.add_child(curseur); grille.add_child(val)
		_valeurs[k] = [curseur, val]
	_maj_valeurs()
	return p

func _maj_valeurs(curseurs_aussi := false) -> void:
	for k in _valeurs:
		var x := Reglages.v(k)
		if curseurs_aussi: _valeurs[k][0].set_value_no_signal(x)
		_valeurs[k][1].text = ("%.2f" % x).replace(".", ",")

func _label(t: String, taille: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", c)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _bouton(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", ENCRE)
	b.add_theme_color_override("font_hover_color", ENCRE)
	b.add_theme_color_override("font_pressed_color", ENCRE)
	b.add_theme_color_override("font_focus_color", ENCRE)
	b.add_theme_color_override("font_disabled_color", Color("#b3ada3"))
	for etat_b in ["normal", "hover", "pressed", "disabled", "focus"]:
		var st := _style(CREME if etat_b != "pressed" else Color("#ebe3d4"), 28)
		if etat_b == "focus": st.draw_center = false; st.shadow_size = 0
		b.add_theme_stylebox_override(etat_b, st)
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(f)
	return b

func _nb_etoiles() -> int:
	var c: int = etat["coups"]
	var par := int(N["par"])
	return 3 if c <= par else (2 if c <= par + 2 else 1)

func _maj() -> void:
	if _lab_coups == null or etat.is_empty(): return
	_lab_coups.text = "Coups : %d" % etat["coups"]
	_etoiles.regler(_nb_etoiles())
	_b_annuler.disabled = histoire.is_empty() or occupe

func _montrer_fin() -> void:
	var n := _nb_etoiles()
	_etoiles_fin.regler(n)
	_etoiles_fin.show()
	_b_annuler_fin.hide()
	_lab_fin.text = "Passé !\n%d coups — la meilleure solution en demande %d." % [etat["coups"], int(N["par"])]
	_fin.show()

# --- La démo et les photos ------------------------------------------------------------
func _process(dt: float) -> void:
	_images += 1
	_secondes += dt
	if _ips and Engine.get_process_frames() % 15 == 0:
		_ips.text = "%d images/s" % Engine.get_frames_per_second()

func _photo(nom: String) -> void:
	var dossier := OS.get_environment("ECLUSES_CAPTURE")
	if dossier == "": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dossier.path_join(nom + ".png"))

func _demo() -> void:
	var oracle: Array = JSON.parse_string(FileAccess.get_file_as_string("res://oracle.json"))["parties"]
	var solution := []
	for p in oracle:
		if p["niveau"] == N["id"]:
			for pas in p["pas"]:
				if pas["action"] != null: solution.append(pas["action"])
			break
	if OS.get_environment("ECLUSES_COUPS") != "":
		solution = Array(OS.get_environment("ECLUSES_COUPS").split(",")).map(func(x): return {"type": "porte", "i": int(x)})
	await get_tree().create_timer(1.2).timeout
	await _photo("00-repos")
	# ECLUSES_PANNEAU=1 : photographie aussi le panneau des réglages déplié
	if OS.get_environment("ECLUSES_PANNEAU") != "" and _panneau:
		_panneau.show()
		await get_tree().create_timer(0.3).timeout
		await _photo("00-reglages")
		_panneau.hide()
	var rang := 0
	for a in solution:
		rang += 1
		jouer(a)
		await get_tree().create_timer(1.15).timeout
		await _photo("%02d-pendant" % rang)
		while occupe: await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		await _photo("%02d-apres" % rang)
	await get_tree().create_timer(0.8).timeout
	await _photo("99-fin")
	if OS.get_environment("ECLUSES_COUPS") != "":
		await get_tree().create_timer(0.25).timeout
		await _photo("99-alerte")
		await get_tree().create_timer(1.6).timeout
		await _photo("99-coince")
	if OS.get_environment("ECLUSES_CAPTURE") != "":
		print("images par seconde (moyenne) : %.1f" % (_images / maxf(_secondes, 0.001)))
		get_tree().quit()
