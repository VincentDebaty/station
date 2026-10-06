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
# ------------------------------------------------------------------

var N: Dictionary
var etat: Dictionary
var histoire := []
var canal: Canal
var camera: Camera2D
var occupe := false
var fini := false

var _lab_coups: Label
var _etoiles: Label
var _b_annuler: Button
var _fin: PanelContainer
var _lab_fin: Label
var _etoiles_fin: Label
var _images := 0
var _secondes := 0.0
var _ips: Label

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

func _cadrer() -> void:
	if canal == null or camera == null: return
	var ecran := get_viewport_rect().size
	var r := canal.rect_monde()
	var haut_hud := 84.0
	var bas_hud := 70.0
	var z := minf((ecran.x - 24.0) / r.size.x, (ecran.y - haut_hud - bas_hud) / r.size.y)
	camera.zoom = Vector2(z, z)
	camera.position = r.get_center() - Vector2(0, (haut_hud - bas_hud) * 0.5 / z)

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
	if a["type"] == "porte":
		var p: Porte = canal.portes[int(a["i"])]
		p.manoeuvrer(etat["ouvert"][int(a["i"])])
		# l'eau part quand la porte est à moitié ouverte ; à la fermeture, on attend qu'elle soit close
		await get_tree().create_timer(0.3 if etat["ouvert"][int(a["i"])] else 0.62).timeout
	canal.ecouler(avant["niv"], etat["niv"], r["flux"])
	await canal.ecoulement_fini
	canal.deplacer(r["dep"])
	await canal.bateaux_arrives
	occupe = false
	_maj()
	var v := Moteur.verdict(N, etat)
	if v.get("fin", "") == "gagne":
		fini = true
		_montrer_fin()

func annuler() -> void:
	if occupe or histoire.is_empty(): return
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

# --- L'interface ----------------------------------------------------------------------
func _style(fond: Color, rayon := 18, ombre := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.set_corner_radius_all(rayon)
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 6; s.content_margin_bottom = 6
	if ombre:
		s.shadow_color = Color(0, 0, 0, 0.22); s.shadow_size = 6; s.shadow_offset = Vector2(0, 3)
	s.border_color = Color(1, 1, 1, 0.9); s.set_border_width_all(2)
	return s

func _interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(racine)
	# en haut à gauche : le numéro du niveau, puis les coups
	var gauche := HBoxContainer.new()
	gauche.position = Vector2(18, 14)
	gauche.add_theme_constant_override("separation", -10)
	racine.add_child(gauche)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _style(Color("#1f6fd1"), 16))
	badge.custom_minimum_size = Vector2(76, 60)
	var num := _label(N["id"], 30, Color.WHITE)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(num)
	var pilule := PanelContainer.new()
	pilule.add_theme_stylebox_override("panel", _style(Color("#f6f1e6"), 18))
	_lab_coups = _label("", 22, Color("#2a3a40"))
	pilule.add_child(_lab_coups)
	pilule.z_index = -1
	gauche.add_child(badge)
	gauche.add_child(pilule)
	# en haut à droite : les étoiles
	var cadre_et := PanelContainer.new()
	cadre_et.add_theme_stylebox_override("panel", _style(Color("#f6f1e6"), 18))
	_etoiles = _label("", 32, Color("#f2b705"))
	cadre_et.add_child(_etoiles)
	cadre_et.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	cadre_et.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	racine.add_child(cadre_et)
	# en bas à droite : annuler, recommencer
	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 10)
	_b_annuler = _bouton("Annuler", annuler)
	boutons.add_child(_b_annuler)
	boutons.add_child(_bouton("Recommencer", _lancer))
	boutons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	boutons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	boutons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	racine.add_child(boutons)
	# la fin
	_fin = PanelContainer.new()
	_fin.add_theme_stylebox_override("panel", _style(Color("#f6f1e6"), 22))
	_fin.set_anchors_preset(Control.PRESET_CENTER)
	_fin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fin.grow_vertical = Control.GROW_DIRECTION_BOTH
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	_etoiles_fin = _label("", 54, Color("#f2b705"))
	_etoiles_fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_etoiles_fin)
	_lab_fin = _label("", 26, Color("#2a3a40"))
	_lab_fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_lab_fin)
	col.add_child(_bouton("Rejouer", _lancer))
	_fin.add_child(col)
	_fin.hide()
	racine.add_child(_fin)
	# les images par seconde, en bas à gauche, dans les versions de test : c'est
	# la mesure qu'on vient chercher sur l'iPhone
	if OS.is_debug_build() and not OS.has_feature("movie"):
		_ips = _label("", 16, Color(1, 1, 1, 0.8))
		_ips.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
		_ips.grow_vertical = Control.GROW_DIRECTION_BEGIN
		racine.add_child(_ips)
	_maj()

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
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color("#2a3a40"))
	b.add_theme_color_override("font_hover_color", Color("#1f6fd1"))
	b.add_theme_color_override("font_disabled_color", Color("#a8a39a"))
	for etat_b in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(etat_b, _style(Color("#f6f1e6") if etat_b != "pressed" else Color("#e6dfcf"), 16))
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(f)
	return b

func _nb_etoiles() -> int:
	var c: int = etat["coups"]
	var par := int(N["par"])
	return 3 if c <= par else (2 if c <= par + 2 else 1)

func _maj() -> void:
	if _lab_coups == null or etat.is_empty(): return
	_lab_coups.text = "      Coups : %d   ·   par %d" % [etat["coups"], int(N["par"])]
	var n := _nb_etoiles()
	_etoiles.text = "★".repeat(n) + "☆".repeat(3 - n)
	_b_annuler.disabled = histoire.is_empty() or occupe

func _montrer_fin() -> void:
	var n := _nb_etoiles()
	_etoiles_fin.text = "★".repeat(n) + "☆".repeat(3 - n)
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
	await get_tree().create_timer(1.2).timeout
	await _photo("00-repos")
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
	if OS.get_environment("ECLUSES_CAPTURE") != "":
		print("images par seconde (moyenne) : %.1f" % (_images / maxf(_secondes, 0.001)))
		get_tree().quit()
