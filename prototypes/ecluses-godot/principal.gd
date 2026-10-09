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
#   ECLUSES_LISTE=1           photographie aussi la liste des niveaux
#   ECLUSES_COUPS=0,v1,1      la démo joue ces coups-là au lieu de la solution
#                             (« v1 » : la vanne de la porte 1 ; « c3 » : un
#                             coup de pelle dans la digue 3)
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
var _b_attendre: Button
var _main: Main            # la main qui montre quoi toucher (niveaux « tuto »)
var _solution := []        # la meilleure solution du niveau (oracle.json), pour la main
var _joues := []           # les gestes joués depuis le début, pour savoir si l'on suit la solution
var _calme_bulles := 0.0   # le sablier : laisser passer un coup (glace qui fond, marée, orage)
var _pancarte: Pancarte   # le panneau d'éclusier de fin (pancarte.gd)
var _lab_num: Label
var _tous := []
var _calcul := 0          # numéro de la dernière recherche d'impasse : une réponse périmée est ignorée
var _images := 0
var _secondes := 0.0
var _ips: Label
var _panneau: PanelContainer   # les curseurs du rendu de l'eau (reglages.gd)
var _valeurs := {}             # clé -> [HSlider, Label de la valeur]
var _racine: Control
var _liste: Control     # la liste des niveaux, ouverte par le numéro
var _sure: Control      # la zone sûre : tout ce qu'on touche ou qu'on lit y reste

# Le niveau sur lequel le jeu s'ouvre : celui qu'on est en train d'essayer
# (Vincent, 7 octobre 2026 : « quand tu déploies sur l'iPhone, tu proposes le
# nouveau niveau à chaque fois »). À changer à chaque nouveauté.
const NIVEAU_EN_TEST := "1-1"

func _ready() -> void:
	_tous = JSON.parse_string(FileAccess.get_file_as_string("res://niveaux.json"))["niveaux"]
	var id := OS.get_environment("ECLUSES_NIVEAU")
	if id == "": id = NIVEAU_EN_TEST
	for n in _tous:
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
	_joues = []
	Engine.time_scale = 1.0
	_solution = _solution_de(N["id"])
	fini = false
	occupe = false
	canal = Canal.new()
	add_child(canal)
	move_child(canal, 0)
	canal.construire(N, etat)
	if camera == null:
		camera = Camera2D.new()
		add_child(camera)
	if _pancarte: _pancarte.hide()
	if _lab_num: _lab_num.text = N["id"]
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
		# le point touché, depuis l'événement lui-même (sur un écran tactile, la
		# « souris » ne suit pas toujours le doigt)
		var m: Vector2 = get_canvas_transform().affine_inverse() * ev.position
		canal.onde(m)
		# Pendant une manœuvre, l'enfant retape (Vincent, 9 octobre 2026) : au
		# lieu d'ignorer ses touchers, ils pressent l'eau et les bateaux (le
		# temps du jeu va jusqu'à trois fois plus vite, jusqu'à la fin du coup)
		if occupe and not fini:
			Engine.time_scale = minf(Engine.time_scale + 0.7, 3.0)
			return
		# le bateau, d'abord : c'était le premier geste de l'enfant
		var ib := canal.bateau_sous(m)
		if ib >= 0 and not fini:
			if Moteur.actions(N, etat).any(func(x): return x["type"] == "naviguer" and int(x["i"]) == ib):
				canal.bateaux[ib].sauter()
				jouer({"type": "naviguer", "i": ib})
			else:
				# il ne peut pas avancer (ou il avance tout seul) : il se secoue, et
				# sa bulle dit pourquoi
				canal.refuser_bateau(ib)
				_calme_bulles = 99.0
			return
		var idr := canal.drague_sous(m)
		if idr >= 0:
			jouer({"type": "draguer", "i": idr})
			return
		var isi := canal.siphon_sous(m)
		if isi >= 0:
			jouer({"type": "amorcer", "i": isi})
			return
		var ia := canal.bac_sous(m)
		if ia >= 0:
			jouer({"type": "ascenseur", "i": ia})
			return
		var ig := canal.glacon_sous(m)
		if ig >= 0:
			jouer({"type": "allumer", "i": ig})
			return
		var ic := canal.chaudiere_sous(m)
		if ic >= 0:
			jouer({"type": "chauffer", "i": ic})
			return
		var ip := canal.pompe_sous(m)
		if ip >= 0:
			jouer({"type": "pomper", "i": ip})
			return
		var ir := canal.rigole_sous(m)
		if ir >= 0:
			jouer({"type": "creuser", "i": ir})
			return
		var hs: Dictionary = canal.hausse_sous(m)
		if not hs.is_empty():
			jouer({"type": hs["quoi"], "i": int(hs["i"])})
			return
		var iv := canal.vanne_sous(m)
		if iv >= 0:
			jouer({"type": "vanne", "i": iv})
			return
		var i := canal.porte_sous(m)
		if i >= 0: jouer({"type": "porte", "i": i})

func jouer(a: Dictionary) -> void:
	if occupe or fini: return
	var permis := Moteur.actions(N, etat).any(func(x): return x["type"] == a["type"] and int(x.get("i", -1)) == int(a.get("i", -1)))
	if not permis:
		# une porte à vanne tenue par l'eau : la roue le dit
		if a["type"] == "porte" and canal.portes.has(int(a["i"])): canal.portes[int(a["i"])].refuser()
		return
	occupe = true
	canal.effacer_indices()
	canal.montrer_raisons({})
	if _main: _main.cacher()
	var avant := etat
	var r := Moteur.jouer(N, etat, a)
	histoire.append(avant)
	_joues.append({"type": a["type"], "i": int(a.get("i", -1))})
	etat = r["etat"]
	_maj()
	# Comme une vraie écluse. Ouvrir : la roue tourne, la porte se soulève d'une
	# fente et l'eau passe dessous (porte simple ; une porte à vanne ferait
	# passer l'eau par son aqueduc, porte close), et quand les deux eaux sont
	# au même niveau la porte se lève en grand. Fermer : elle redescend
	# d'abord, puis la roue se referme.
	if a["type"] == "pomper":
		await canal.pomper(int(a["i"]))
	elif a["type"] == "chauffer":
		await canal.chauffer(int(a["i"]))
	elif a["type"] == "allumer":
		await canal.allumer(int(a["i"]))
	elif a["type"] == "ascenseur":
		await canal.voyage_bac(int(a["i"]), avant, etat)
	elif a["type"] == "amorcer":
		await canal.amorcer(int(a["i"]))
	elif a["type"] == "draguer":
		await canal.draguer(int(a["i"]))
	elif a["type"] == "creuser" and canal.rigoles.has(int(a["i"])):
		# un coup de pelle : l'entaille se creuse, des mottes volent, puis
		# l'eau file
		var rg: Rigole = canal.rigoles[int(a["i"])]
		rg.regler(etat["crete"][int(a["i"])])
		while not rg.arrive(): await get_tree().process_frame
	elif a["type"] == "hausser" or a["type"] == "abaisser":
		# la planche glisse dans ses rainures, puis l'eau passe par-dessus
		var h: Hausse = canal.hausses[int(a["i"])]
		h.regler(etat["crete"][int(a["i"])])
		while not h.arrive(): await get_tree().process_frame
	elif a["type"] == "vanne":
		# la vanne : le petit volant tourne, puis l'eau passe par l'aqueduc,
		# porte close
		var pv: Porte = canal.portes[int(a["i"])]
		pv.manoeuvrer_vanne(etat["vanne"][int(a["i"])])
		await get_tree().create_timer(0.4).timeout
	elif a["type"] == "porte" and canal.portes[int(a["i"])].a_vanne:
		# la porte d'une porte à vanne : la grande roue la lève ou la baisse,
		# entre deux eaux déjà égales
		var pp: Porte = canal.portes[int(a["i"])]
		pp.tourner_roue(etat["ouvert"][int(a["i"])])
		if not etat["ouvert"][int(a["i"])]: await canal.placer_vantaux(etat)
	elif a["type"] == "porte":
		var p: Porte = canal.portes[int(a["i"])]
		if etat["ouvert"][int(a["i"])]:
			# la roue tourne, et une porte simple se soulève tout de suite d'une
			# fente : l'eau passe dessous (Vincent : le joueur s'attend à voir
			# la porte s'ouvrir quand il la touche)
			p.manoeuvrer_vanne(true)
			if not canal.aqueducs.has(int(a["i"])): p.entrouvrir(true)
			await get_tree().create_timer(0.4).timeout
		else:
			p.entrouvrir(false)
			await canal.placer_vantaux(etat)
			p.manoeuvrer_vanne(false)
			await p.roue_finie
	canal.objets_changent(avant, etat)
	# après un voyage du bac, l'eau part du niveau où le bac l'a emportée
	var niv_avant: Array = avant["niv"].duplicate()
	if a["type"] == "ascenseur": niv_avant = canal.vue_niv.duplicate()
	canal.ecouler(niv_avant, etat["niv"], r["flux"])
	await canal.ecoulement_fini
	await canal.placer_vantaux(etat)
	canal.deplacer(r["dep"])
	await canal.bateaux_arrives
	occupe = false
	Engine.time_scale = 1.0
	_maj()
	var v := Moteur.verdict(N, etat)
	if v.get("fin", "") == "gagne":
		fini = true
		_montrer_fin()
	elif v.get("fin", "") == "perdu":
		# un village inondé : perdu tout de suite (chapitre 3, hausses)
		fini = true
		_maj()
		await get_tree().create_timer(1.0).timeout
		if fini: _pancarte.montrer_echec(false, "Trop d'eau a passé le mur : le village a les pieds dans l'eau.", "Village inondé !")
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
	var pourquoi := _pourquoi(coinces)
	canal.alerter(coinces)
	_maj()
	# quand la coupe montre l'eau qui manque, on laisse le temps de la voir
	# avant que la pancarte ne la couvre
	await get_tree().create_timer(2.4 if canal.manque_signale() else 1.3).timeout
	if not fini: return     # on a annulé entre-temps
	_pancarte.montrer_echec(coinces.size() > 1, pourquoi)

# La raison d'un blocage, en une phrase, et sur la coupe quand c'est l'eau qui
# manque : le niveau qu'il aurait fallu, en pointillés. Vincent voyait une
# porte levée et deux eaux égales, et ne comprenait pas que le bief d'arrivée
# n'avait plus assez de fond pour porter le bateau.
const NOMS_COULEURS := ["rouge", "jaune", "bleu", "vert"]
func _pourquoi(coinces: Array) -> String:
	var nom := func(k: int) -> String: return "bateau " + NOMS_COULEURS[k % NOMS_COULEURS.size()]
	var bassin := func(i: int) -> String: return String(N["bassins"][i].get("nom", "bassin"))
	# le face-à-face d'abord : c'est lui qui fige tout, même porte fermée (la
	# raison immédiate serait alors « porte », qui n'explique rien)
	var suivant := func(k: int) -> int:
		var p: int = etat["bateaux"][k]
		return p + signi(int(N["bateaux"][k]["vers"]) - p)
	for k in coinces:
		for j in coinces:
			var p: int = etat["bateaux"][k]
			var q: int = etat["bateaux"][j]
			if j != k and suivant.call(k) == q and suivant.call(j) == p \
					and etat["bateaux"].count(p) >= Moteur.capacite(N, p) and etat["bateaux"].count(q) >= Moteur.capacite(N, q):
				return "Le %s et le %s se font face, et un sas ne tient qu'un bateau." % [nom.call(k), nom.call(j)]
	for k in coinces:
		var r := Moteur.raison(N, etat, k)
		match r["quoi"]:
			"fond_la", "seuil":
				canal.signaler_manque(int(r["bassin"]), float(r["niveau"]), k)
				return "Le %s n'a plus assez d'eau pour porter le %s, et l'eau ne remonte jamais." % [bassin.call(int(r["bassin"])), nom.call(k)]
			"fond_ici":
				canal.signaler_manque(int(r["bassin"]), float(r["niveau"]), k)
				return "Le %s touche le fond du %s." % [nom.call(k), bassin.call(int(r["bassin"]))]
			"plein":
				return "Le %s attend une place dans le %s, qui ne se libérera plus." % [nom.call(k), bassin.call(int(r["bassin"]))]
			"pont":
				canal.signaler_manque(int(r["bassin"]), float(r["niveau"]), k, true)
				return "L'eau est trop haute : la cheminée du %s ne passe plus sous le pont." % nom.call(k)
	return ""

func annuler() -> void:
	if occupe or histoire.is_empty(): return
	_calcul += 1
	var e: Dictionary = histoire.pop_back()
	if not _joues.is_empty(): _joues.pop_back()
	Engine.time_scale = 1.0
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
	_pancarte.hide()
	_maj()
	_chercher_impasse()      # l'état d'avant peut lui-même être une impasse

# --- L'interface ----------------------------------------------------------------------
# L'interface suit la maquette du panneau d'éclusier (Vincent, 6 octobre
# 2026) : tout ce qui se touche ou se lit autour du jeu est en bois — le
# numéro, les coups, les boutons du bas, la pancarte de fin. Seul le panneau des
# réglages, outil de test, reste une pastille claire. Police arrondie : Arial
# Rounded MT Bold, présente d'origine sur iOS et macOS — rien à embarquer.
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

# Une plaque de bois : l'image art/plaque_bois.png si elle existe (découpée en
# neuf, recadrée sur ses pixels visibles), sinon le bois en relief dessiné
# (relief.gd), le même que celui des boutons.
var _tex_plaque: Texture2D = null
func _style_bois(rayon: int, marge: int) -> StyleBox:
	if _tex_plaque == null and ResourceLoader.exists("res://art/plaque_bois.png"):
		_tex_plaque = Images.reduire("res://art/plaque_bois.png", 300)
	if _tex_plaque:
		var t := StyleBoxTexture.new()
		t.texture = _tex_plaque
		t.set_texture_margin_all(30.0)
		t.content_margin_left = marge; t.content_margin_right = marge
		t.content_margin_top = 6; t.content_margin_bottom = 8
		return t
	return Relief.plaque(rayon, marge)

# Le texte sur le bois : crème cerclé de brun foncé, comme sur la pancarte.
func _label_bois(t: String, taille: int) -> Label:
	var l := _label(t, taille, Color("#fff3dc"))
	l.add_theme_color_override("font_outline_color", Color("#3e210d"))
	l.add_theme_constant_override("outline_size", 10)
	return l

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
	# Le haut de l'écran en bois, comme sur la maquette du panneau d'éclusier
	# (Vincent, 6 octobre 2026) : à gauche, le numéro du niveau sur une plaque
	# de bois ; à droite, les coups sur une plaque (à la place du chronomètre
	# de la maquette : le jeu compte les coups), puis les étoiles posées sur le
	# décor, sans pastille.
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _style_bois(18, 14))
	badge.custom_minimum_size = Vector2(112, 80)
	var num := _label_bois(N["id"], 46)
	_lab_num = num
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(num)
	_sure.add_child(badge)
	# toucher le numéro ouvre la liste des niveaux (Vincent, 7 octobre 2026 :
	# tester un niveau sans refaire tous ceux d'avant)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_ouvrir_liste())
	_racine = racine
	var droite := HBoxContainer.new()
	droite.add_theme_constant_override("separation", 18)
	var pilule := PanelContainer.new()
	pilule.add_theme_stylebox_override("panel", _style_bois(22, 24))
	pilule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pilule.custom_minimum_size = Vector2(0, 66)
	_lab_coups = _label_bois("", 34)
	pilule.add_child(_lab_coups)
	droite.add_child(pilule)
	_etoiles = Etoiles.new()
	# un peu plus petites et moins jaunes qu'avant (lot 9 de PLAN-RENDU.md :
	# « un peu grosses et très jaunes par rapport au reste »)
	_etoiles.taille = 52.0
	_etoiles.modulate = Color(1.0, 0.94, 0.82)
	_etoiles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	droite.add_child(_etoiles)
	_sure.add_child(droite)
	droite.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	droite.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# en bas à droite : annuler, recommencer
	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 14)
	# le sablier, quand le temps fait quelque chose tout seul : on le laisse
	# passer d'un coup sans toucher à rien
	_b_attendre = _medaillon(Images.sablier(128, 8), func(): jouer({"type": "attendre"}))
	_b_attendre.visible = false
	boutons.add_child(_b_attendre)
	_b_annuler = _medaillon(Images.pictogramme("res://art/icone_annuler.png", 128, 8), annuler)
	boutons.add_child(_b_annuler)
	boutons.add_child(_medaillon(Images.pictogramme("res://art/icone_rejouer.png", 128, 8), _lancer))
	_sure.add_child(boutons)
	boutons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	boutons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	boutons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# la fin : le panneau d'éclusier, en bas, sur la terre, au-dessus des
	# boutons — les bateaux et leurs « ! » restent visibles au-dessus
	_pancarte = Pancarte.new()
	_sure.add_child(_pancarte)
	_pancarte.annuler.connect(annuler)
	_pancarte.rejouer.connect(_lancer)
	_pancarte.suivant.connect(_niveau_suivant)
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
		ligne.add_child(_medaillon(Images.engrenage(128, 8), func():
			_panneau.visible = not _panneau.visible
			defaut.visible = _panneau.visible
			if _ips: _ips.visible = _panneau.visible))
		ligne.add_child(defaut)
	if OS.is_debug_build() and not OS.has_feature("movie"):
		# seulement quand le panneau des réglages est ouvert (lot 9) : il sert
		# à mesurer, pas à jouer
		_ips = _label("", 16, Color(1, 1, 1, 0.85))
		_ips.visible = false
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

# Un bouton à texte en bois en relief (le « Valeurs de départ » des réglages).
func _bouton(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	var creme := Color("#fff3dc")
	b.add_theme_font_size_override("font_size", 24)
	for nom in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(nom, creme)
	b.add_theme_color_override("font_outline_color", Color("#3e210d"))
	b.add_theme_constant_override("outline_size", 8)
	_habiller(b, 22.0, 22.0)
	b.custom_minimum_size = Vector2(0, 66)
	b.pressed.connect(f)
	return b

# Les boutons du bas de l'écran, comme sur l'image d'exemple de Vincent
# (6 octobre 2026) : des médaillons ronds en bois épais, un pictogramme crème
# cerclé de brun au milieu, sans texte. Enfoncé, la face descend sur sa
# tranche et le pictogramme avec elle ; indisponible (rien à annuler), tout
# pâlit.
func _medaillon(picto: Texture2D, f: Callable) -> Button:
	var b := Button.new()
	b.icon = picto
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.45))
	if not _habiller_image(b): _habiller(b, 70.0, 27.0)
	b.custom_minimum_size = Vector2(120, 120)
	b.pressed.connect(f)
	return b

# Le médaillon peint, si art/medaillon_bois.png existe (prompt dans
# ASSETS.md) : posé tel quel, foncé quand on appuie, pâli quand le bouton est
# indisponible. Le pictogramme reste dessiné par le jeu, et il descend un peu
# quand on appuie.
var _tex_medaillon: Texture2D = null
func _habiller_image(b: Button) -> bool:
	if _tex_medaillon == null and ResourceLoader.exists("res://art/medaillon_bois.png"):
		_tex_medaillon = Images.reduire("res://art/medaillon_bois.png", 240)
	if _tex_medaillon == null: return false
	for etat_b in ["normal", "hover", "pressed", "disabled"]:
		var st := StyleBoxTexture.new()
		st.texture = _tex_medaillon
		var bas := 4.0 if etat_b == "pressed" else 0.0
		st.content_margin_left = 28; st.content_margin_right = 28
		st.content_margin_top = 28 + bas; st.content_margin_bottom = 28 - bas
		if etat_b == "pressed": st.modulate_color = Color(0.8, 0.76, 0.72)
		if etat_b == "disabled": st.modulate_color = Color(1, 1, 1, 0.55)
		b.add_theme_stylebox_override(etat_b, st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return true

func _habiller(b: Button, rayon: float, marge: float) -> void:
	b.add_theme_stylebox_override("normal", Relief.plaque(rayon, marge))
	b.add_theme_stylebox_override("hover", Relief.plaque(rayon, marge))
	b.add_theme_stylebox_override("pressed", Relief.plaque(rayon, marge, true))
	b.add_theme_stylebox_override("disabled", Relief.plaque(rayon, marge, false, true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

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
	_pancarte.montrer_victoire(_nb_etoiles(), "%d coups — la meilleure solution en demande %d." % [etat["coups"], int(N["par"])], not _suivant().is_empty())

# Un niveau que la tranche sait faire JOUER : des portes et des biefs, sans
# digue, champ ni fleuve (chapitre 1). Les autres se dessinent, mais leurs
# gestes (creuser une digue, lâcher l'eau, attendre la crue) n'existent pas
# encore au doigt.
func _jouable(n: Dictionary) -> bool:
	if n["mode"] != "pas": return false
	for b in n["bassins"]:
		if not (b["type"] in ["bief", "sas", "reservoir", "village", "mer", "bac", "champ"]): return false
	for l in n["liaisons"]:
		if not (l["type"] in ["porte", "libre", "hausse", "mur", "digue", "quai"]): return false
	return true

# Le niveau d'après, s'il est jouable.
func _suivant() -> Dictionary:
	var i := _tous.find(N)
	if i < 0 or i + 1 >= _tous.size(): return {}
	var n: Dictionary = _tous[i + 1]
	return n if _jouable(n) else {}

# --- La liste des niveaux -------------------------------------------------------------
# Toucher le numéro du niveau ouvre une planche de bois avec tous les niveaux,
# rangés par chapitre ; en toucher un le lance. Le niveau en cours est en
# jaune ; ceux qu'on ne sait pas encore jouer sont pâles, marqués « bientôt ».
# Toucher à côté de la planche la referme.
func _ouvrir_liste() -> void:
	if _liste: _liste.queue_free()
	_liste = Control.new()
	_liste.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(_liste)
	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.0, 0.5)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed: _fermer_liste())
	_liste.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_liste.add_child(centre)
	var planche := PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = Images.reduire("res://art/panneau_bois.png", 900)
	if st.texture:
		st.set_texture_margin_all(100)
		st.content_margin_left = 96; st.content_margin_right = 96
		st.content_margin_top = 64; st.content_margin_bottom = 70
		planche.add_theme_stylebox_override("panel", st)
	else:
		planche.add_theme_stylebox_override("panel", _style_bois(24, 40))
	centre.add_child(planche)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	planche.add_child(col)
	var titre := _label_bois("Les niveaux", 42)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titre)
	# Les chapitres défilent au doigt (Vincent, 8 octobre 2026 : une douzaine
	# de chapitres de plus ne tenaient plus sur l'écran) : une ligne par
	# chapitre, son nom à gauche, ses niveaux à droite ; la liste s'ouvre sur
	# le niveau en cours.
	var vis := get_viewport().get_visible_rect().size
	var defile := ScrollContainer.new()
	defile.custom_minimum_size = Vector2(minf(vis.x * 0.74, 1300.0), vis.y * 0.6)
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.scroll_deadzone = 14          # un doigt qui glisse sur un bouton fait défiler
	col.add_child(defile)
	var lignes := VBoxContainer.new()
	lignes.add_theme_constant_override("separation", 14)
	lignes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(lignes)
	var courant: Control = null
	var chapitres: Array = JSON.parse_string(FileAccess.get_file_as_string("res://niveaux.json"))["chapitres"]
	for ch in chapitres:
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", 14)
		lignes.add_child(rang)
		var nom := _label_bois("%d · %s" % [int(ch["n"]), ch["titre"]], 26)
		nom.custom_minimum_size = Vector2(360, 0)
		nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rang.add_child(nom)
		for n in _tous:
			if int(n["chapitre"]) == int(ch["n"]):
				var c := _case_niveau(n)
				rang.add_child(c)
				if n == N: courant = c
	if courant:
		await get_tree().process_frame
		if is_instance_valid(defile) and is_instance_valid(courant): defile.ensure_control_visible(courant)

func _case_niveau(n: Dictionary) -> Control:
	var case := VBoxContainer.new()
	case.add_theme_constant_override("separation", 2)
	var b := Button.new()
	b.text = n["id"]
	b.add_theme_font_size_override("font_size", 32)
	var encre := Color("#ffd75a") if n == N else Color("#fff3dc")
	for nom in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(nom, encre)
	b.add_theme_color_override("font_disabled_color", Color(1, 0.95, 0.86, 0.5))
	b.add_theme_color_override("font_outline_color", Color("#3e210d"))
	b.add_theme_constant_override("outline_size", 8)
	_habiller(b, 18.0, 16.0)
	b.custom_minimum_size = Vector2(150, 66)
	b.disabled = not _jouable(n)
	b.pressed.connect(func():
		_fermer_liste()
		N = n
		_lancer())
	case.add_child(b)
	var t := _label(n["titre"] if not b.disabled else "bientôt", 17, Color("#fff3dc") if not b.disabled else Color(1, 0.95, 0.86, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color("#3e210d"))
	t.add_theme_constant_override("outline_size", 6)
	t.custom_minimum_size = Vector2(150, 0)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	case.add_child(t)
	return case

func _fermer_liste() -> void:
	if _liste: _liste.queue_free()
	_liste = null

func _niveau_suivant() -> void:
	var n := _suivant()
	if n.is_empty(): return
	N = n
	_lancer()

# --- La démo et les photos ------------------------------------------------------------
# Après 5 s sans coup, un bateau qui semble pouvoir avancer (porte ouverte,
# eaux égales) mais n'a pas assez de fond reçoit son indice : le niveau qu'il
# lui faudrait, et la bulle du manque.
var _calme := 0.0
func _indices_de_fond(dt: float) -> void:
	if occupe or fini or canal == null:
		_calme = 0.0
		return
	_calme += dt
	if _calme < 5.0: return
	for k in N["bateaux"].size():
		var r := Moteur.raison(N, etat, k)
		if r["quoi"] in ["fond_ici", "fond_la", "seuil", "pont"]:
			canal.indiquer_manque(k, int(r["bassin"]), float(r["niveau"]), r["quoi"] == "pont")

# La meilleure solution d'un niveau, telle que l'oracle l'a jouée, pour la
# main : en entier sur un niveau « tuto » (le 1-1) ; jusqu'au premier usage
# de la nouveauté du chapitre sur un niveau qui en présente une (« nouveau »,
# Vincent, 9 octobre 2026 : « une présentation avec la main pour chaque
# nouvel élément »). La main suit la solution jusque-là plutôt que de
# montrer la nouveauté d'emblée : sur le 6-1, allumer le brasero tout de
# suite rend le niveau impossible.
func _solution_de(id: String) -> Array:
	if not N.get("tuto", false) and not N.has("nouveau"): return []
	var o = JSON.parse_string(FileAccess.get_file_as_string("res://oracle.json"))
	for p in o["parties"]:
		if p["niveau"] == id:
			var sol := []
			for pas in p["pas"]:
				if pas["action"] != null: sol.append({"type": pas["action"]["type"], "i": int(pas["action"].get("i", -1))})
			if N.get("tuto", false): return sol
			var nv: Dictionary = N["nouveau"]
			for j in sol.size():
				if sol[j]["type"] == nv["type"] and (not nv.has("i") or sol[j]["i"] == int(nv["i"])):
					return sol.slice(0, j + 1)
			return []
	return []

# Les bulles des bateaux et la main, quand la partie attend le joueur.
func _guider(dt: float) -> void:
	if canal == null: return
	if occupe or fini:
		_calme_bulles = 0.0
		if fini: canal.montrer_raisons({})
		if _main: _main.cacher()
		return
	_calme_bulles += dt
	# les bulles, après un court instant de calme
	if _calme_bulles > 0.8:
		var r := {}
		for k in N["bateaux"].size():
			var q: String = Moteur.raison(N, etat, k)["quoi"]
			match q:
				"porte": r[k] = "porte"
				"fond_ici", "fond_la", "seuil": r[k] = "eau"
				"pont": r[k] = "trop"
				"plein": r[k] = "plein"
				"niveaux": r[k] = "niveaux"
				"passe":
					if N.get("manuel", false): r[k] = "passe"
		canal.montrer_raisons(r)
	# la main : tant que l'on suit la solution du niveau tutoriel, elle montre
	# le geste suivant
	if _solution.is_empty(): return
	if _main == null:
		# au-dessus de l'interface : elle doit pouvoir montrer le sablier
		var couche := CanvasLayer.new()
		couche.layer = 5
		add_child(couche)
		_main = Main.new()
		couche.add_child(_main)
	var n := _joues.size()
	var suit := n < _solution.size()
	for j in mini(n, _solution.size()):
		if _joues[j]["type"] != _solution[j]["type"] or _joues[j]["i"] != _solution[j]["i"]: suit = false
	if suit and _calme_bulles > 0.5:
		var p := _cible_de(_solution[n])
		if p != Vector2.INF:
			# en pixels de l'écran (la main vit dans sa couche)
			if _solution[n]["type"] != "attendre": p = get_canvas_transform() * p
			_main.viser(p)
		else: _main.cacher()
	else:
		_main.cacher()

# Où se touche un geste, en coordonnées du monde.
func _cible_de(a: Dictionary) -> Vector2:
	var i := int(a["i"])
	match a["type"]:
		"porte": return canal.portes[i].centre_roue() if canal.portes.has(i) else Vector2.INF
		"vanne": return canal.portes[i].centre_vanne() if canal.portes.has(i) else Vector2.INF
		"naviguer": return canal.bateaux[i].global_position + Vector2(0, -20)
		"pomper": return canal.pompes[i].pivot() if canal.pompes.has(i) else Vector2.INF
		"creuser": return canal.rigoles[i].point_main() if canal.rigoles.has(i) else Vector2.INF
		"chauffer": return canal.chaudieres[i].base + Vector2(0, -60) if canal.chaudieres.has(i) else Vector2.INF
		"allumer": return Vector2(canal.glacons[i].x_feu, canal.glacons[i].base.y - 34.0) if canal.glacons.has(i) else Vector2.INF
		"ascenseur": return canal.bacs[i].centre_roue() + canal.D * 0.5 if canal.bacs.has(i) else Vector2.INF
		"amorcer": return canal.siphons[i].sommet + Vector2(0, -22) if canal.siphons.has(i) else Vector2.INF
		"draguer": return canal.dragues[i].pied + Vector2(0, -45.0 * Drague.ECHELLE) if canal.dragues.has(i) else Vector2.INF
		"attendre":
			# un bouton de l'interface : déjà en pixels de l'écran
			return _b_attendre.get_global_rect().get_center() if _b_attendre and _b_attendre.visible else Vector2.INF
	return Vector2.INF

func _process(dt: float) -> void:
	_guider(dt)
	_indices_de_fond(dt)
	if canal:
		for p in canal.portes.values(): p.actif = not occupe and not fini
		# une pompe dont la source est à sec ne répond plus : elle pâlit et
		# cesse d'inviter le doigt (Vincent)
		if not canal.pompes.is_empty():
			var A := Moteur.actions(N, etat) if not occupe and not fini else []
			for ip in canal.pompes:
				canal.pompes[ip].actif = A.any(func(x): return x["type"] == "pomper" and int(x["i"]) == ip)
		if not canal.dragues.is_empty():
			var A7 := Moteur.actions(N, etat) if not occupe and not fini else []
			for idr in canal.dragues:
				canal.dragues[idr].actif = A7.any(func(x): return x["type"] == "draguer" and int(x["i"]) == idr)
		if not canal.siphons.is_empty():
			var A6 := Moteur.actions(N, etat) if not occupe and not fini else []
			for isi in canal.siphons:
				canal.siphons[isi].actif = A6.any(func(x): return x["type"] == "amorcer" and int(x["i"]) == isi)
		if not canal.bacs.is_empty():
			var A5 := Moteur.actions(N, etat) if not occupe and not fini else []
			for ia in canal.bacs:
				canal.bacs[ia].actif = A5.any(func(x): return x["type"] == "ascenseur" and int(x["i"]) == ia)
		if not canal.glacons.is_empty():
			var A3 := Moteur.actions(N, etat) if not occupe and not fini else []
			for ig in canal.glacons:
				canal.glacons[ig].actif = A3.any(func(x): return x["type"] == "allumer" and int(x["i"]) == ig)
		if _b_attendre:
			var A4 := Moteur.actions(N, etat) if not fini else []
			_b_attendre.visible = A4.any(func(x): return x["type"] == "attendre")
			_b_attendre.disabled = occupe
		if not canal.chaudieres.is_empty():
			var A2 := Moteur.actions(N, etat) if not occupe and not fini else []
			for ic in canal.chaudieres:
				canal.chaudieres[ic].actif = A2.any(func(x): return x["type"] == "chauffer" and int(x["i"]) == ic)
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
		# « 1 » : la porte 1 ; « v1 » : la vanne de la porte 1
		# « type:i » pour tous les autres gestes (« chauffer:0 », « attendre »)
		solution = Array(OS.get_environment("ECLUSES_COUPS").split(",")).map(func(x): return {"type": x.split(":")[0], "i": int(x.split(":")[1])} if ":" in x else ({"type": x} if x.length() > 3 else ({"type": "vanne", "i": int(x.substr(1))} if x.begins_with("v") else ({"type": "creuser", "i": int(x.substr(1))} if x.begins_with("c") else ({"type": "pomper", "i": int(x.substr(1))} if x.begins_with("P") else {"type": "porte", "i": int(x)})))))
	await get_tree().create_timer(1.2).timeout
	await _photo("00-repos")
	# ECLUSES_SONDE="x,y" (pixels de l'écran) : liste les polygones dessinés
	# sous ce point, pour retrouver d'où vient un défaut
	if OS.get_environment("ECLUSES_SONDE") != "":
		var xy := OS.get_environment("ECLUSES_SONDE").split(",")
		var ecran := Vector2(float(xy[0]), float(xy[1]))
		var monde := get_viewport().get_canvas_transform().affine_inverse() * ecran
		print("sonde ", ecran, " → monde ", monde)
		var pile := [canal]
		while not pile.is_empty():
			var nd: Node = pile.pop_back()
			for c in nd.get_children(): pile.append(c)
			if nd is Polygon2D and nd.visible:
				var p2: Polygon2D = nd
				var loc := p2.get_global_transform().affine_inverse() * monde
				if p2.polygon.size() >= 3 and Geometry2D.is_point_in_polygon(loc, p2.polygon):
					print("  ", p2.get_path(), " couleur ", p2.color, " ", p2.polygon)
	if OS.get_environment("ECLUSES_LISTE") != "":
		_ouvrir_liste()
		await get_tree().create_timer(0.3).timeout
		await _photo("00-liste")
		_fermer_liste()
	# ECLUSES_PANNEAU=1 : photographie aussi le panneau des réglages déplié
	if OS.get_environment("ECLUSES_PANNEAU") != "" and _panneau:
		_panneau.show()
		await get_tree().create_timer(0.3).timeout
		await _photo("00-reglages")
		_panneau.hide()
	var rang := 0
	for a in solution:
		rang += 1
		if a["type"] == "toucher":
			# un vrai toucher sur un bateau (ECLUSES_COUPS « toucher:k »)
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = get_canvas_transform() * canal.bateaux[int(a["i"])].global_position
			_unhandled_input(ev)
		else:
			jouer(a)
		# ECLUSES_PENDANT : quand prendre la photo « pendant » (1,15 s par défaut)
		var pendant := float(OS.get_environment("ECLUSES_PENDANT")) if OS.get_environment("ECLUSES_PENDANT") != "" else 1.15
		await get_tree().create_timer(pendant).timeout
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
		await get_tree().create_timer(3.2).timeout     # le temps de voir la pancarte s'animer
		await _photo("99-pancarte")
		print("images par seconde (moyenne) : %.1f" % (_images / maxf(_secondes, 0.001)))
		get_tree().quit()
