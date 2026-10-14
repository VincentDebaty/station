extends Node2D
# ------------------------------------------------------------------
# Le labyrinthe d'eau, joué en direct sur le moteur par volumes (moteur.gd).
#
# Le moteur avance à pas fixes (60 par seconde, quelle que soit la cadence
# de l'écran) ; la boule est interpolée entre deux pas. On touche un bouton
# de vanne pour verser ou vider une unité ; l'appui long verse (ou vide) en
# continu, une unité dès que la précédente est passée.
#
# Les couches, du fond vers l'avant : le décor (cadre, creux), l'eau (un
# polygone par bassin, bord du haut = la surface à ressorts, et les
# cascades), les bords de mur, les vannes, la boule, l'interface.
#
# LABY_CAPTURE=<dossier> joue la solution toute seule, photographie quelques
# images puis quitte (vérification sans les doigts, en fenêtre).
# Avec LABY_GESTES, il joue une manœuvre écrite à la main et photographie
# une image toutes les 0,2 s (voir le README).
# ------------------------------------------------------------------

const SABLE := Color("#efc68b")
const SABLE_BORD := Color("#b8844c")
const CREUX := Color("#211862")
const FOND := Color("#33278a")
const ROUGE := Color("#e5322d")
const ROUGE_OMBRE := Color("#b32020")
const BLANC := Color("#f6f6fb")
const BLANC_OMBRE := Color("#cfd2e3")
const ROBINET := Color("#3f8ff0")
const ROBINET_OMBRE := Color("#2560b8")
const VIDANGE := Color("#f08a24")
const VIDANGE_OMBRE := Color("#c0651a")
const TUYAU := Color("#8a8fae")
const TUYAU_OMBRE := Color("#5c6080")
const SORTIE := Color("#ffc93c")
const ECUME := Color("#c9f0ff")
const PAS_S := 1.0 / 60.0             # un pas du moteur
const APPUI_LONG := 18                # pas avant que l'appui long verse en continu
const ONDULATION := 0.012             # la houle de repos, purement visuelle, en cases

var N: Dictionary
var grille: Array
var W: int
var H: int
var M: Moteur
var e: Moteur.Etat

var case_px := 50.0
var origine := Vector2.ZERO
var acc := 0.0
var image := 0
var temps := 0.0
var appui := -1
var appui_depuis := 0
var presse: Array = []
var boule_avant := Vector2.ZERO
var angle := 0.0
var angle_avant := 0.0
# L'inclinaison de la boule sur les vagues : un ressort amorti vers la pente
# de la surface sous elle, comme une bouée (purement visuel).
var incline := 0.0
var incline_v := 0.0
const INCLINE_PULS := 7.0             # rad/s
const INCLINE_AMORTI := 0.8
var fini := false
var attente_fin := 0
var ms_pas := 0.0
var ms_pire := 0.0

var fond: Node2D
var eau: Node2D
var chutes: Node2D
var gouttes: Node2D
var murs: Node2D
var vannes_n: Node2D
var boule_n: Node2D
var titre: Label
var compteur: Label
var mesure: Label
var carte: PanelContainer
var carte_texte: Label

# Les cascades vues : le débit de chaque ouverture, lissé (il monte vite et
# retombe doucement : une chute qui s'arrête s'amincit puis s'éteint), et le
# sens de la dernière chute.
var debit_vu := PackedFloat64Array()
var chute_src := PackedInt32Array()
var chute_dst := PackedInt32Array()
var budget := PackedFloat64Array()       # les particules à émettre, au fil du temps
var robinet_de := PackedInt32Array()     # par bassin : le robinet qui y verse, ou -1
# Les particules : un réservoir fixe, rien n'est alloué image par image.
const GOUTTE := 0
const BULLE := 1
const ECUME_P := 2
const NB_PARTICULES := 220
var p_x := PackedFloat64Array()
var p_y := PackedFloat64Array()
var p_vx := PackedFloat64Array()
var p_vy := PackedFloat64Array()
var p_vie := PackedFloat64Array()
var p_vie0 := PackedFloat64Array()
var p_taille := PackedFloat64Array()
var p_type := PackedInt32Array()
var p_suivante := 0
var hasard := RandomNumberGenerator.new()

var capture := ""
var a_capturer := [60, 240, 300, 330, 400, 520, 700, 800]


func _ready() -> void:
	N = JSON.parse_string(FileAccess.get_file_as_string("res://niveau.json"))
	grille = N["grille"]
	W = String(grille[0]).length(); H = grille.size()
	M = Moteur.new(N)
	presse.resize(M.vannes.size()); presse.fill(0)
	robinet_de.resize(M.nb); robinet_de.fill(-1)
	for k in M.vannes.size():
		if M.vannes[k]["type"] == "robinet":
			robinet_de[int(M.vannes[k]["bassin"])] = k
	var no := M.o_a.size()
	debit_vu.resize(no); chute_src.resize(no); chute_dst.resize(no); budget.resize(no * 3)
	for t in [p_x, p_y, p_vx, p_vy, p_vie, p_vie0, p_taille]:
		t.resize(NB_PARTICULES)
	p_type.resize(NB_PARTICULES)
	hasard.seed = 7

	fond = Node2D.new(); add_child(fond); fond.draw.connect(_dessiner_fond)
	eau = Node2D.new(); add_child(eau); eau.draw.connect(_dessiner_eau)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://eau.gdshader")
	eau.material = mat
	chutes = Node2D.new(); add_child(chutes); chutes.draw.connect(_dessiner_chutes)
	var mat_chute := ShaderMaterial.new()
	mat_chute.shader = load("res://chute.gdshader")
	chutes.material = mat_chute
	gouttes = Node2D.new(); add_child(gouttes); gouttes.draw.connect(_dessiner_gouttes)
	murs = Node2D.new(); add_child(murs); murs.draw.connect(_dessiner_murs)
	vannes_n = Node2D.new(); add_child(vannes_n); vannes_n.draw.connect(_dessiner_vannes)
	boule_n = Node2D.new(); add_child(boule_n); boule_n.draw.connect(_dessiner_boule)
	_interface()
	get_viewport().size_changed.connect(_cadrer)
	capture = OS.get_environment("LABY_CAPTURE")
	recommencer()


func _interface() -> void:
	var hud := CanvasLayer.new(); add_child(hud)
	titre = Label.new(); hud.add_child(titre)
	titre.add_theme_font_size_override("font_size", 26)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compteur = Label.new(); hud.add_child(compteur)
	compteur.add_theme_font_size_override("font_size", 20)
	compteur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compteur.add_theme_color_override("font_color", Color("#b9b0ec"))
	mesure = Label.new(); hud.add_child(mesure)
	mesure.add_theme_font_size_override("font_size", 14)
	mesure.add_theme_color_override("font_color", Color("#8f86c9"))
	var rejouer := Button.new(); hud.add_child(rejouer)
	rejouer.text = "Recommencer"
	rejouer.add_theme_font_size_override("font_size", 18)
	rejouer.pressed.connect(recommencer)
	rejouer.name = "rejouer"
	carte = PanelContainer.new(); hud.add_child(carte)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fffaf0")
	style.set_corner_radius_all(22)
	style.content_margin_left = 20; style.content_margin_right = 20
	style.content_margin_top = 18; style.content_margin_bottom = 16
	style.shadow_color = Color("#1c1550"); style.shadow_offset = Vector2(0, 6); style.shadow_size = 0
	carte.add_theme_stylebox_override("panel", style)
	var boite := VBoxContainer.new(); carte.add_child(boite)
	carte_texte = Label.new(); boite.add_child(carte_texte)
	carte_texte.add_theme_font_size_override("font_size", 24)
	carte_texte.add_theme_color_override("font_color", Color("#2a2350"))
	carte_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := Button.new(); boite.add_child(b)
	b.text = "Rejouer"
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(recommencer)
	carte.visible = false


func recommencer() -> void:
	e = M.charger()
	image = 0; appui = -1; fini = false; attente_fin = 0; acc = 0.0
	boule_avant = Vector2(e.bx, e.by)
	angle = 0.0; angle_avant = 0.0; incline = 0.0; incline_v = 0.0
	debit_vu.fill(0.0); budget.fill(0.0); p_vie.fill(0.0)
	carte.visible = false
	_cadrer()
	_maj_interface()


# Le labyrinthe et ses boutons tiennent dans l'écran, sous l'interface.
func _cadrer() -> void:
	var ecran := get_viewport_rect().size
	var gauche := 2.0
	var droite := 0.7
	var haut := 1.4
	var bas := 2.2
	var largeur_cases := W + gauche + droite
	var hauteur_cases := H + haut + bas
	var bandeau := 150.0
	case_px = minf(ecran.x / largeur_cases, (ecran.y - bandeau) / hauteur_cases)
	var x0 := (ecran.x - largeur_cases * case_px) / 2.0 + gauche * case_px
	var y_haut := bandeau + (ecran.y - bandeau - hauteur_cases * case_px) / 2.0 + haut * case_px
	origine = Vector2(x0, y_haut + H * case_px)
	(eau.material as ShaderMaterial).set_shader_parameter("case_px", case_px)
	titre.position = Vector2(0, 40); titre.size = Vector2(ecran.x, 34)
	compteur.position = Vector2(0, 80); compteur.size = Vector2(ecran.x, 28)
	mesure.position = Vector2(12, ecran.y - 26)
	for c in get_children():
		if c is CanvasLayer:
			for d in c.get_children():
				if d is Button:
					d.position = Vector2(ecran.x - 170, 104); d.size = Vector2(156, 40)
	carte.position = Vector2(ecran.x / 2 - 170, ecran.y / 2 - 70); carte.size = Vector2(340, 140)
	for n in [fond, eau, murs, vannes_n, boule_n]:
		n.queue_redraw()


func _maj_interface() -> void:
	titre.text = "Niveau 1 · %s" % N["titre"]
	compteur.text = "tapes %d · par %d" % [e.tapes, int(N["par"])]


# --- le temps ---------------------------------------------------------------------
func _process(delta: float) -> void:
	temps += delta
	if capture != "":
		_capturer()
	else:
		acc += delta
		var n := 0
		while acc >= PAS_S and n < 4:
			_pas()
			acc -= PAS_S
			n += 1
		if n == 4:
			acc = 0.0
	_dt_rendu = PAS_S if capture != "" else delta
	_cascades(PAS_S if capture != "" else delta)
	_incliner(PAS_S if capture != "" else delta)
	eau.queue_redraw()
	chutes.queue_redraw()
	gouttes.queue_redraw()
	vannes_n.queue_redraw()
	boule_n.queue_redraw()
	mesure.text = "%d i/s · moteur %.2f ms (au plus %.2f)" % [Engine.get_frames_per_second(), ms_pas, ms_pire]


func _pas() -> void:
	if appui >= 0 and not fini and image - appui_depuis >= APPUI_LONG and e.attente[appui] < 0.05:
		_taper(appui)
	boule_avant = Vector2(e.bx, e.by)
	angle_avant = angle
	var t0 := Time.get_ticks_usec()
	M.pas(e)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	ms_pas = ms_pas * 0.95 + ms * 0.05
	ms_pire = maxf(ms_pire * 0.999, ms)
	var dx := e.bx - boule_avant.x
	if absf(dx) < 1.0:
		angle += dx / Moteur.RAYON
	image += 1
	for k in presse.size():
		if presse[k] > 0: presse[k] -= 1
	if e.gagne and not fini:
		fini = true; appui = -1; attente_fin = 70
	if attente_fin > 0:
		attente_fin -= 1
		if attente_fin == 0:
			carte_texte.text = "La boule est libre !\nEn %d tapes%s." % [e.tapes, " : parfait" if e.tapes <= int(N["par"]) else " (par %d)" % int(N["par"])]
			carte.visible = true


func _taper(k: int) -> void:
	presse[k] = 6
	var r := M.taper(e, k)
	if r != null:
		e = r
		_maj_interface()


func _input(ev: InputEvent) -> void:
	var appuye := false
	var lache := false
	var pos := Vector2.ZERO
	if ev is InputEventScreenTouch:
		appuye = ev.pressed; lache = not ev.pressed; pos = ev.position
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		appuye = ev.pressed; lache = not ev.pressed; pos = ev.position
	else:
		return
	if lache:
		appui = -1
		return
	if not appuye or fini:
		return
	for k in M.vannes.size():
		var b := bouton(M.vannes[k])
		if pos.distance_to(ecran(b.x, b.y)) <= 0.75 * case_px:
			_taper(k)
			appui = k; appui_depuis = image
			get_viewport().set_input_as_handled()
			return


# --- les repères ---------------------------------------------------------------------
func ecran(x: float, y: float) -> Vector2:
	return Vector2(origine.x + x * case_px, origine.y - y * case_px)

func rect_cases(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	var a := ecran(minf(x0, x1), maxf(y0, y1))
	return Rect2(a, Vector2(absf(x1 - x0), absf(y1 - y0)) * case_px)

func car(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= W or y >= H:
		return "#"
	return grille[H - 1 - y][x]

func mur(x: int, y: int) -> bool:
	return car(x, y) == "#"

func bouton(v: Dictionary) -> Vector2:
	var x: float = v["x"]
	var y: float = v["y"]
	if v["type"] == "vidange":
		return Vector2(x + 0.5, -1.15)
	if x == 0:
		return Vector2(-1.15, y + 0.5)
	if x == W - 1:
		return Vector2(W + 1.15, y + 0.5)
	return Vector2(x + 0.5, H + 1.15)


# --- le décor ---------------------------------------------------------------------
func _dessiner_fond() -> void:
	var cadre := StyleBoxFlat.new()
	cadre.bg_color = SABLE
	cadre.set_corner_radius_all(int(case_px * 0.45))
	fond.draw_style_box(cadre, rect_cases(-0.15, -0.15, W + 0.15, H + 0.15))
	for y in H:
		for x in W:
			if mur(x, y):
				continue
			fond.draw_rect(rect_cases(x - 0.02, y - 0.02, x + 1.02, y + 1.02), FOND if car(x, y) == "S" else CREUX)
	for y in H:
		for x in W:
			if car(x, y) == "S" and y == H - 1:
				var p := ecran(x + 0.5, y + 1.75)
				var s := case_px
				fond.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-0.38, 0.42) * s, p + Vector2(-0.14, 0.42) * s,
					p + Vector2(-0.14, 0.78) * s, p + Vector2(0.14, 0.78) * s, p + Vector2(0.14, 0.42) * s, p + Vector2(0.38, 0.42) * s]), SORTIE)


# Les bords de mur, au-dessus de l'eau : une bande de sable de 0,3 case autour
# de chaque creux coupe net l'eau qui déborde un peu de ses bassins.
func _dessiner_murs() -> void:
	const B := 0.3
	for y in H:
		for x in W:
			if mur(x, y):
				continue
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if (dx == 0 and dy == 0) or not mur(x + dx, y + dy):
						continue
					if x + dx < 0 or y + dy < 0 or x + dx >= W or y + dy >= H:
						continue
					var x0: float = x + (1.0 if dx == 1 else (-B if dx == -1 else 0.0))
					var x1: float = x + (1.0 + B if dx == 1 else (0.0 if dx == -1 else 1.0))
					var y0: float = y + (1.0 if dy == 1 else (-B if dy == -1 else 0.0))
					var y1: float = y + (1.0 + B if dy == 1 else (0.0 if dy == -1 else 1.0))
					murs.draw_rect(rect_cases(x0 - 0.01, y0 - 0.01, x1 + 0.01, y1 + 0.01), SABLE)
	var ep := maxf(1.5, case_px * 0.06)
	for y in H:
		for x in W:
			if mur(x, y):
				continue
			if x > 0 and mur(x - 1, y): murs.draw_line(ecran(x, y), ecran(x, y + 1), SABLE_BORD, ep)
			if x < W - 1 and mur(x + 1, y): murs.draw_line(ecran(x + 1, y), ecran(x + 1, y + 1), SABLE_BORD, ep)
			if y > 0 and mur(x, y - 1): murs.draw_line(ecran(x, y), ecran(x + 1, y), SABLE_BORD, ep)
			if y < H - 1 and mur(x, y + 1): murs.draw_line(ecran(x, y + 1), ecran(x + 1, y + 1), SABLE_BORD, ep)
	var cadre := StyleBoxFlat.new()
	cadre.draw_center = false
	cadre.border_color = SABLE_BORD
	cadre.set_border_width_all(int(maxf(2.0, case_px * 0.08)))
	cadre.set_corner_radius_all(int(case_px * 0.45))
	murs.draw_style_box(cadre, rect_cases(-0.15, -0.15, W + 0.15, H + 0.15))
	for v in M.vannes:
		var b := bouton(v)
		var cx: float = float(v["x"]) + 0.5
		var cy: float = float(v["y"]) + 0.5
		if v["type"] == "vidange":
			murs.draw_rect(rect_cases(cx - 0.17, b.y, cx + 0.17, float(v["y"]) + 0.05), TUYAU)
			for q in 3:
				murs.draw_rect(rect_cases(float(v["x"]) + 0.18 + q * 0.24, float(v["y"]), float(v["x"]) + 0.3 + q * 0.24, float(v["y"]) + 0.09), TUYAU_OMBRE)
		elif b.y == cy:
			murs.draw_rect(rect_cases(minf(b.x, cx), cy - 0.17, maxf(b.x, cx), cy + 0.17), TUYAU)
		else:
			murs.draw_rect(rect_cases(cx - 0.17, float(v["y"]) + 0.85, cx + 0.17, b.y), TUYAU)


# --- l'eau ---------------------------------------------------------------------
# La surface vue à l'abscisse x d'un bassin libre : celle du moteur (niveau +
# vagues), raccordée au voisin lié sur leur bord commun, plus une houle de
# repos très légère, purement visuelle.
func _surface_vue(a: int, x: float) -> float:
	return M.surface_en(e, a, x) + _houle(x)

func _houle(x: float) -> float:
	return ONDULATION * (sin(x * 2.3 + temps * 1.7) * 0.6 + sin(x * 5.1 - temps * 2.3) * 0.4)


# Les masses d'eau : les bassins reliés par de l'eau (les deux côtés d'une
# ouverture mouillés au-dessus de son seuil) forment une seule masse, et la
# profondeur se compte depuis SA surface — la plus haute surface libre de la
# masse. Ainsi la teinte est continue d'un bassin à l'autre, et un bassin
# plein sous un plafond n'a ni surface ni liseré : il est le fond de la masse.
var _masse := PackedInt32Array()
var _reference := PackedFloat64Array()
var _membres := PackedInt32Array()     # par racine : le nombre de bassins mouillés de la masse

# La case d'un robinet, quand son eau n'a rejoint aucune autre : c'est encore
# le tuyau. On ne la dessine pas (un carré d'eau dans le mur), et sa chute
# part du bout du tuyau, comme un jet.
func _dans_le_tuyau(a: int) -> bool:
	return robinet_de[a] >= 0 and _membres[_racine(a)] <= 1

func _masses() -> void:
	_masse.resize(M.nb)
	for a in M.nb:
		_masse[a] = a
	for o in M.o_a.size():
		var a := M.o_a[o]
		var b := M.o_b[o]
		if e.vol[a] < 0.004 or e.vol[b] < 0.004:
			continue
		if minf(M.niveau_bassin(e, a), M.niveau_bassin(e, b)) <= M.o_y0[o] + 0.02:
			continue
		var ra := _racine(a)
		var rb := _racine(b)
		if ra != rb:
			_masse[maxi(ra, rb)] = mini(ra, rb)
	_membres.resize(M.nb)
	_membres.fill(0)
	for a in M.nb:
		if e.vol[a] >= 0.004:
			_membres[_racine(a)] += 1
	_reference.resize(M.nb)
	_reference.fill(-INF)
	var plafond := PackedFloat64Array(); plafond.resize(M.nb); plafond.fill(-INF)
	for a in M.nb:
		if e.vol[a] < 0.004:
			continue
		var r := _racine(a)
		if M.libre(e, a):
			_reference[r] = maxf(_reference[r], M.niveau_bassin(e, a))
		plafond[r] = maxf(plafond[r], float(M.b_haut[a]))
	for a in M.nb:
		if _reference[a] == -INF:
			_reference[a] = plafond[a]

func _teinte(ref: float, y: float, lisere: float, reflets: float) -> Color:
	return Color(0.5 + (ref - y) / 16.0, lisere, reflets, 1.0)

func _racine(a: int) -> int:
	while _masse[a] != a:
		a = _masse[a]
	return a


# Le haut de l'eau de chaque bassin, échantillonné de gauche à droite :
# la surface (à ressorts) d'un bassin libre, le plafond d'un bassin plein.
const ECHANTILLONS := 17
const RACCORD := 0.35        # en cases, de part et d'autre d'une ouverture
var _xs: Array = []          # par bassin : PackedFloat64Array
var _hauts: Array = []
var _profs: Array = []       # la profondeur du point sous la surface locale (0 sur une surface ;
                             # sous un plafond, sa profondeur sous la surface de la masse)
var _liseres: Array = []     # 1 : le point est sur une surface libre et porte le liseré

# Les puits : deux colonnes voisines reliées par une ouverture haute, où l'eau
# de la plus basse a de l'air au-dessus d'elle dans l'ouverture. Dans un vrai
# puits, leurs niveaux s'égalisent à l'instant ; le moteur, lui, laisse un
# retard (une colonne encore pleine sous son plafond quand sa voisine se vide
# par le fond), qui se voyait comme une bosse. On dessine donc un puits à un
# niveau commun, celui que donne son volume.
var _niv_puits := PackedFloat64Array()     # par bassin : ce niveau commun, ou -INF

func _puits() -> void:
	var par := PackedInt32Array()
	par.resize(M.nb)
	for a in M.nb:
		par[a] = a
	for o in M.o_a.size():
		var a := M.o_a[o]
		var b := M.o_b[o]
		if M.o_y1[o] - M.o_y0[o] < 1.5 or e.vol[a] < 0.004 or e.vol[b] < 0.004:
			continue
		var bas_cote := minf(M.niveau_bassin(e, a), M.niveau_bassin(e, b))
		if bas_cote < M.o_y0[o] + 0.02 or bas_cote > M.o_y1[o] - 0.02:
			continue
		var ra := a
		while par[ra] != ra: ra = par[ra]
		var rb := b
		while par[rb] != rb: rb = par[rb]
		par[maxi(ra, rb)] = mini(ra, rb)
	_niv_puits.resize(M.nb)
	_niv_puits.fill(-INF)
	for r in M.nb:
		if par[r] != r:
			continue
		var membres: Array[int] = []
		for a in M.nb:
			var q := a
			while par[q] != q: q = par[q]
			if q == r:
				membres.append(a)
		if membres.size() < 2:
			continue
		# le volume visible (le trop-plein d'un bassin sous pression n'est que
		# de la pression), réparti à un niveau commun, par dichotomie
		var v := 0.0
		var lo := INF
		var hi := -INF
		for a in membres:
			v += minf(e.vol[a], M.capacite(a))
			lo = minf(lo, float(M.b_bas[a])); hi = maxf(hi, float(M.b_haut[a]))
		for i in 30:
			var mi := 0.5 * (lo + hi)
			var f := 0.0
			for a in membres:
				f += clampf(mi - float(M.b_bas[a]), 0.0, float(M.b_haut[a] - M.b_bas[a]))
			if f < v: lo = mi
			else: hi = mi
		for a in membres:
			_niv_puits[a] = 0.5 * (lo + hi)

func _hauts_d_eau() -> void:
	_puits()
	_xs.resize(M.nb); _hauts.resize(M.nb); _profs.resize(M.nb); _liseres.resize(M.nb)
	for a in M.nb:
		var vol := e.vol[a]
		if vol < 0.004 or _dans_le_tuyau(a):
			_xs[a] = null
			continue
		var x0 := float(M.b_x[a]) - 0.04
		var x1 := float(M.b_x[a]) + 1.04
		var bas := float(M.b_bas[a]) - 0.04
		var ref := _reference[_racine(a)]
		var xs := PackedFloat64Array()
		var hs := PackedFloat64Array()
		var ps := PackedFloat64Array()
		var ls := PackedFloat64Array()
		var libre := M.libre(e, a)
		var plein := vol >= M.capacite(a) - 1e-6
		# une surface libre collée à son plafond (moins de 0,15 case d'air) se
		# lit comme un bassin plein : sous le plafond, sans liseré ni reflets,
		# de la même eau que la colonne pleine d'à côté ; elle s'en détache
		# progressivement à mesure que l'air s'ouvre
		var puits := _niv_puits[a]
		var w := 1.0
		if (libre or puits != -INF) and M.b_ferme[a] == 1:
			w = smoothstep(0.03, 0.15, float(M.b_haut[a]) - (puits if puits != -INF else M.niveau_bassin(e, a)))
		for k in ECHANTILLONS:
			var x := lerpf(x0, x1, float(k) / (ECHANTILLONS - 1))
			xs.append(x)
			if puits != -INF:
				# au niveau commun du puits, avec les vagues du bassin s'il en a
				var xc := clampf(x, float(M.b_x[a]), float(M.b_x[a]) + 1.0)
				var vague := _surface_vue(a, xc) - M.niveau_bassin(e, a) if libre else _houle(xc)
				var h := minf(maxf(puits + vague, bas + 0.01), float(M.b_haut[a]) + 0.04)
				h = lerpf(float(M.b_haut[a]) + 0.04, h, w)
				hs.append(h)
				ps.append((ref - h) * (1.0 - w)); ls.append(w)
			elif libre:
				# jamais sous le fond : un creux de vague ne retourne pas le polygone
				var h := maxf(_surface_vue(a, clampf(x, float(M.b_x[a]), float(M.b_x[a]) + 1.0)), bas + 0.01)
				h = lerpf(float(M.b_haut[a]) + 0.04, h, w)
				hs.append(h)
				ps.append((ref - h) * (1.0 - w)); ls.append(w)
			elif plein:
				# sous un plafond, la profondeur se compte depuis la surface de la
				# masse, comme dans le bassin libre voisin : les reflets et les
				# voiles, qui en dépendent, passent d'un bassin à l'autre sans couture
				hs.append(float(M.b_haut[a]) + 0.04)
				ps.append(ref - float(M.b_haut[a]) - 0.04); ls.append(0.0)
			else:
				hs.append(maxf(M.niveau_bassin(e, a), bas + 0.01))
				ps.append(0.0); ls.append(1.0)
		if robinet_de[a] >= 0:
			# la case d'un robinet ne monte pas plus haut que l'eau où elle
			# débouche : son trop-plein n'est que l'eau qui arrive du tuyau
			for o in M.o_a.size():
				var autre := M.o_b[o] if M.o_a[o] == a else (M.o_a[o] if M.o_b[o] == a else -1)
				if autre < 0 or e.vol[autre] < 0.004 or not M.libre(e, autre):
					continue
				var xo := float(M.b_x[M.o_b[o]])
				var niv := _surface_vue(autre, clampf(xo, float(M.b_x[autre]), float(M.b_x[autre]) + 1.0))
				for k in hs.size():
					if niv < hs[k] - 0.01:
						hs[k] = maxf(niv, bas + 0.01); ps[k] = 0.0; ls[k] = 1.0
		_xs[a] = xs; _hauts[a] = hs; _profs[a] = ps; _liseres[a] = ls


# Le raccord à une ouverture : quand l'eau d'un côté est plus haute que celle
# de l'autre, et que le côté bas a de l'air au-dessus de lui dans l'ouverture,
# l'eau ne s'arrête pas en falaise sur la frontière : sa surface descend en
# courbe douce d'un côté à l'autre, sur RACCORD de part et d'autre. Un bassin
# plein y décolle de son plafond, comme l'eau qui sort d'un tuyau, et la
# surface ainsi découverte reçoit le liseré.
func _raccorder() -> void:
	for o in M.o_a.size():
		var a := M.o_a[o]
		var b := M.o_b[o]
		if _xs[a] == null or _xs[b] == null:
			continue
		var xb := float(M.b_x[b])
		var ha: PackedFloat64Array = _hauts[a]
		var hb: PackedFloat64Array = _hauts[b]
		var ta := _haut_en(a, xb)
		var tb := _haut_en(b, xb)
		var bas_cote := minf(ta, tb)
		if absf(ta - tb) < 0.01 or bas_cote >= M.o_y1[o] - 0.005 or bas_cote <= M.o_y0[o]:
			continue
		# entre deux colonnes d'un même puits (une ouverture haute), l'écart de
		# niveau est un retard du moteur : il s'étale sur toute la largeur
		var r := RACCORD if M.o_y1[o] - M.o_y0[o] < 1.5 else 0.5
		var gauche := _haut_en(a, xb - r)
		var droite := _haut_en(b, xb + r)
		for cote in [a, b]:
			var xs: PackedFloat64Array = _xs[cote]
			var hs: PackedFloat64Array = _hauts[cote]
			var ps: PackedFloat64Array = _profs[cote]
			var ls: PackedFloat64Array = _liseres[cote]
			for k in xs.size():
				var d := xs[k] - xb
				if absf(d) > r:
					continue
				var t := smoothstep(-r, r, d)
				var h := lerpf(gauche, droite, t)
				if h < hs[k] - 0.02:
					ps[k] = 0.0; ls[k] = 1.0
				hs[k] = maxf(h, float(M.b_bas[cote]) - 0.03)
			_hauts[cote] = hs; _profs[cote] = ps; _liseres[cote] = ls

# La lèvre d'une chute : l'épaisseur de la nappe au moment où elle passe le
# bord — les deux tiers de l'eau au-dessus du seuil (la surface s'abaisse en
# approchant du bord, comme au-dessus d'un vrai déversoir).
func _levre(o: int) -> float:
	var tete := clampf(M.charge(e, chute_src[o]) - M.o_y0[o], 0.0, M.o_y1[o] - M.o_y0[o])
	return clampf(tete * 0.7, 0.03, 0.5)

# La surface du bassin qui déverse s'arrondit en approchant du bord, jusqu'à
# l'épaisseur de la nappe : l'eau qui part et l'eau qui tombe ne font qu'un.
const ARRONDI := 0.45        # en cases, avant le bord
var pente_levre := PackedFloat64Array()

var levre_vue := PackedFloat64Array()   # par ouverture : l'épaisseur de la nappe au bord, telle que dessinée

func _arrondir_levres() -> void:
	pente_levre.resize(M.o_a.size())
	pente_levre.fill(0.0)
	levre_vue.resize(M.o_a.size())
	levre_vue.fill(0.0)
	for o in M.o_a.size():
		if not _chute_active(o):
			continue
		var src := chute_src[o]
		if _xs[src] == null:
			continue
		var bord := M.o_y0[o] + _levre(o)
		# une chute qui s'éteint alors que l'aval est déjà remonté au seuil
		# n'est plus dessinée : sa lèvre non plus
		if M.o_y0[o] + _levre(o) * 0.5 - _arrivee(o).y < 0.05:
			continue
		var dir := 1.0 if chute_dst[o] == M.o_b[o] else -1.0
		var xb := float(M.b_x[M.o_b[o]])
		var xs: PackedFloat64Array = _xs[src]
		var hs: PackedFloat64Array = _hauts[src]
		var ps: PackedFloat64Array = _profs[src]
		var ls: PackedFloat64Array = _liseres[src]
		# la surface en amont de l'arrondi ; si elle est déjà plus basse que la
		# lèvre (un creux de vague, une eau qui s'écoule), c'est elle qui fait
		# l'épaisseur de la nappe : la nappe ne repart jamais plus haut que
		# l'eau qu'elle prolonge
		var amont := _haut_en(src, xb - dir * ARRONDI)
		bord = clampf(minf(bord, amont), M.o_y0[o] + 0.03, M.o_y1[o])
		levre_vue[o] = bord - M.o_y0[o]
		# la pente de l'arrondi au bord : la nappe part dans son prolongement
		pente_levre[o] = maxf(0.0, 2.0 * (amont - bord) / ARRONDI)
		# sur les ARRONDI dernières cases, la surface rejoint une courbe qui
		# descend sans remonter, de l'amont jusqu'au bord : ni creux ni crête
		# juste avant la chute
		for k in xs.size():
			var d := (xb - xs[k]) * dir          # la distance au bord, côté source
			if d > ARRONDI:
				continue
			var t := 1.0 - clampf(d / ARRONDI, 0.0, 1.0)
			var courbe := amont - (amont - bord) * t * t
			if d < 0.0:
				# au-delà du bord (le polygone déborde un peu), la surface suit
				# déjà le dessus de la nappe, sans palier
				courbe = maxf(bord + d * pente_levre[o], M.o_y0[o])
			hs[k] = lerpf(hs[k], courbe, smoothstep(0.0, 0.6, t))
			ps[k] = 0.0; ls[k] = 1.0
		_hauts[src] = hs; _profs[src] = ps; _liseres[src] = ls

# Les reflets (COLOR.b) vivent sous une surface libre. Sous un plafond, ils
# s'éteignent : une eau emprisonnée au-dessus de la surface de sa masse
# n'est pas striée d'une ligne de reflets. Ils débordent seulement un peu
# d'un bassin libre dans le bassin plein voisin, pour s'y fondre.
var _reflets: Array = []
func _etendre_reflets() -> void:
	_reflets.resize(M.nb)
	for a in M.nb:
		_reflets[a] = null if _xs[a] == null else _liseres[a].duplicate()
	for o in M.o_a.size():
		var a := M.o_a[o]
		var b := M.o_b[o]
		if _xs[a] == null or _xs[b] == null:
			continue
		var xb := float(M.b_x[b])
		for paire in [[a, b], [b, a]]:
			var plein: int = paire[0]
			if not M.libre(e, paire[1]) or M.libre(e, plein):
				continue
			var xs: PackedFloat64Array = _xs[plein]
			var rs: PackedFloat64Array = _reflets[plein]
			for k in xs.size():
				rs[k] = maxf(rs[k], 1.0 - smoothstep(0.0, 0.45, absf(xs[k] - xb)))
			_reflets[plein] = rs

func _haut_en(a: int, x: float) -> float:
	var xs: PackedFloat64Array = _xs[a]
	var hs: PackedFloat64Array = _hauts[a]
	var f := clampf((x - xs[0]) / (xs[xs.size() - 1] - xs[0]), 0.0, 1.0) * (xs.size() - 1)
	var k := mini(floori(f), xs.size() - 2)
	return lerpf(hs[k], hs[k + 1], f - k)


# La teinte de chaque bassin se compte depuis une surface de référence qui
# suit celle de sa masse sans à-coup : quand une masse se sépare ou se
# rejoint, la couleur glisse au lieu de sauter.
var _ref_vue := PackedFloat64Array()
var _dt_rendu := PAS_S
const SUIT_TEINTE := 2.5             # par seconde

func _dessiner_eau() -> void:
	_masses()
	_hauts_d_eau()
	_raccorder()
	_arrondir_levres()
	_etendre_reflets()
	if _ref_vue.size() != M.nb:
		_ref_vue.resize(M.nb); _ref_vue.fill(-INF)
	# une bande verticale par intervalle entre deux échantillons : son haut sur
	# la surface, son bas sur le fond. Chaque sommet porte, dans UV.y, SA
	# profondeur sous la surface locale (liseré, reflets) et, dans COLOR.r, sa
	# profondeur sous la surface de la masse (la teinte), linéaire et non
	# bornée (0,5 + p/16) : l'interpolation ne dépend plus du découpage en
	# triangles, deux bassins voisins se raccordent sans couture. COLOR.g : 1
	# sur une surface libre (le liseré), 0 sous un plafond ; COLOR.b : les reflets
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for a in M.nb:
		if _xs[a] == null:
			_ref_vue[a] = -INF
			continue
		var cible := _reference[_racine(a)]
		_ref_vue[a] = cible if _ref_vue[a] == -INF else lerpf(_ref_vue[a], cible, minf(1.0, _dt_rendu * SUIT_TEINTE))
	# tous les bassins d'une même masse prennent la même référence (la moyenne
	# pondérée par leur eau) : des histoires différentes ne doivent pas
	# laisser deux teintes côte à côte dans une eau qui ne fait qu'un
	var somme := PackedFloat64Array(); somme.resize(M.nb)
	var poids := PackedFloat64Array(); poids.resize(M.nb)
	for a in M.nb:
		if _xs[a] != null:
			var r := _racine(a)
			somme[r] += _ref_vue[a] * e.vol[a]; poids[r] += e.vol[a]
	for a in M.nb:
		if _xs[a] != null:
			var r := _racine(a)
			_ref_vue[a] = somme[r] / poids[r]
	for a in M.nb:
		if _xs[a] == null:
			continue
		var ref := _ref_vue[a]
		var xs: PackedFloat64Array = _xs[a]
		var tops: PackedFloat64Array = _hauts[a]
		var prof: PackedFloat64Array = _profs[a]
		var lis: PackedFloat64Array = _liseres[a]
		var ref_: PackedFloat64Array = _reflets[a]
		var bas := float(M.b_bas[a]) - 0.04
		for i in xs.size():
			var base := pts.size()
			var haut := maxf(tops[i], bas + 0.005)
			pts.append(ecran(xs[i], haut)); uvs.append(Vector2(xs[i], prof[i])); cols.append(_teinte(ref, haut, lis[i], ref_[i]))
			pts.append(ecran(xs[i], bas)); uvs.append(Vector2(xs[i], prof[i] + haut - bas)); cols.append(_teinte(ref, bas, lis[i], ref_[i]))
			if i > 0:
				idx.append_array([base - 2, base, base - 1, base - 1, base, base + 1])
	if OS.get_environment("LABY_DEBUG") != "" and image == int(OS.get_environment("LABY_DEBUG")):
		for a in M.nb:
			if _xs[a] != null:
				print("bassin %d x%d libre=%s vol=%.3f cap=%.2f niv=%.3f racine=%d ref=%.3f vue=%.3f prof0=%.3f haut0=%.3f" % [a, M.b_x[a], M.libre(e, a), e.vol[a], M.capacite(a), M.niveau_bassin(e, a), _racine(a), _reference[_racine(a)], _ref_vue[a], _profs[a][0], _hauts[a][0]])
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(eau.get_canvas_item(), idx, pts, cols, uvs)


# --- les cascades et les éclaboussures ---------------------------------------------
# Une cascade : à travers une ouverture dont le bassin d'arrivée est plus bas
# que le seuil, l'eau sort à la vitesse de Torricelli et tombe en parabole
# jusqu'au point que le moteur calcule (Moteur.portee) — c'est là aussi que
# sa vague part. Tout ce qui suit est réglé sur le débit lissé :
#   faible  (< 0,015 case/image) : un filet étroit, presque pas de gouttes ;
#   moyen   (< 0,05)             : une nappe plus large, des bulles au pied ;
#   fort                         : une cascade, de l'écume, des éclaboussures.
const FAIBLE := 0.015
const FORT := 0.05

func _chute_active(o: int) -> bool:
	return debit_vu[o] >= 0.0008

# Le point où la chute de l'ouverture o touche l'eau (ou le fond).
func _arrivee(o: int) -> Vector2:
	var src := chute_src[o]
	var dst := chute_dst[o]
	var dir := 1.0 if dst == M.o_b[o] else -1.0
	var x := float(M.b_x[M.o_b[o]]) + dir * M.portee(e, o, src, dst)
	var y := float(M.b_bas[dst])
	if e.vol[dst] > 0.02:
		y = M.surface_en(e, dst, x) if M.libre(e, dst) else float(M.b_haut[dst])
	return Vector2(x, y)

# La surface sous un point (x, y) du labyrinthe ; -INF s'il n'y a pas d'eau.
func _surface_ici(x: float, y: float) -> float:
	var cx := floori(x)
	var cy := floori(y)
	if cx < 0 or cy < 0 or cx >= W or cy >= H:
		return -INF
	var a := M.bassin_de[cy * W + cx]
	if a < 0 or e.vol[a] <= 0.02:
		return -INF
	return M.surface_en(e, a, x) if M.libre(e, a) else float(M.b_haut[a])

func _emettre(type: int, x: float, y: float, vx: float, vy: float, vie: float, taille: float) -> void:
	var i := p_suivante
	p_suivante = (p_suivante + 1) % NB_PARTICULES
	p_type[i] = type; p_x[i] = x; p_y[i] = y; p_vx[i] = vx; p_vy[i] = vy
	p_vie[i] = vie; p_vie0[i] = vie; p_taille[i] = taille


func _cascades(dt: float) -> void:
	# le débit vu de chaque ouverture : il suit le débit calculé, vite à la
	# montée, doucement à la descente
	for o in M.o_a.size():
		var q := absf(e.flux[o])
		var cible := 0.0
		if q > 0.0004:
			var src := M.o_a[o] if e.flux[o] > 0.0 else M.o_b[o]
			var dst := M.o_b[o] if e.flux[o] > 0.0 else M.o_a[o]
			if M.charge(e, dst) < M.o_y0[o]:
				cible = q
				chute_src[o] = src; chute_dst[o] = dst
		var k := 12.0 if cible > debit_vu[o] else 2.5
		debit_vu[o] += (cible - debit_vu[o]) * minf(1.0, dt * k)
		if debit_vu[o] < 0.0003:
			debit_vu[o] = 0.0
		if not _chute_active(o):
			continue
		# l'émission, au pied de la chute
		var I := debit_vu[o]
		var pied := _arrivee(o)
		var dir := 1.0 if chute_dst[o] == M.o_b[o] else -1.0
		var force := clampf(sqrt(I) * 4.0, 0.35, 1.4)
		budget[3 * o] += (140.0 * I if I > FAIBLE else 20.0 * I) * dt
		budget[3 * o + 1] += (90.0 * I if I > FAIBLE * 0.8 else 0.0) * dt
		budget[3 * o + 2] += (160.0 * I if I > FORT else (40.0 * I if I > FAIBLE else 0.0)) * dt
		while budget[3 * o] >= 1.0:
			budget[3 * o] -= 1.0
			_emettre(GOUTTE, pied.x + hasard.randf_range(-0.08, 0.08), pied.y + 0.02,
				(-dir * hasard.randf_range(0.2, 1.1) + hasard.randf_range(-0.4, 0.4)) * force,
				hasard.randf_range(1.0, 2.6) * force, hasard.randf_range(0.5, 0.9), hasard.randf_range(0.035, 0.06))
		while budget[3 * o + 1] >= 1.0:
			budget[3 * o + 1] -= 1.0
			var prof := hasard.randf_range(0.15, 0.6) * minf(1.0, sqrt(I) * 4.0)
			_emettre(BULLE, pied.x + hasard.randf_range(-0.2, 0.2), pied.y - prof,
				hasard.randf_range(-0.08, 0.08), hasard.randf_range(0.35, 0.7), 1.6, hasard.randf_range(0.022, 0.048))
		while budget[3 * o + 2] >= 1.0:
			budget[3 * o + 2] -= 1.0
			var cote := -1.0 if hasard.randf() < 0.5 else 1.0
			_emettre(ECUME_P, pied.x + cote * hasard.randf_range(0.0, 0.22), pied.y,
				cote * hasard.randf_range(0.2, 0.5), 0.0, hasard.randf_range(0.5, 1.1), hasard.randf_range(0.05, 0.1))
	# les particules vivent
	for i in NB_PARTICULES:
		if p_vie[i] <= 0.0:
			continue
		p_vie[i] -= dt
		var t := p_type[i]
		if t == GOUTTE:
			p_vy[i] -= 9.0 * dt
			p_x[i] += p_vx[i] * dt; p_y[i] += p_vy[i] * dt
			if not M.ouvert(floori(p_x[i]), floori(p_y[i])) or (p_vy[i] < 0.0 and p_y[i] < _surface_ici(p_x[i], p_y[i])):
				p_vie[i] = 0.0
		elif t == BULLE:
			p_x[i] += p_vx[i] * dt; p_y[i] += p_vy[i] * dt
			if p_y[i] >= _surface_ici(p_x[i], p_y[i]) - 0.02 or not M.ouvert(floori(p_x[i]), floori(p_y[i])):
				p_vie[i] = 0.0
		else:
			p_x[i] += p_vx[i] * dt
			p_vx[i] *= 1.0 - minf(1.0, 2.5 * dt)
			var h := _surface_ici(p_x[i], p_y[i] + 0.05)
			if h == -INF or not M.ouvert(floori(p_x[i]), floori(p_y[i])):
				p_vie[i] = 0.0
			else:
				p_y[i] = h + 0.01


# La nappe : un ruban le long de la parabole, du seuil au pied de la chute,
# d'autant plus large que le débit est fort, qui s'amincit en tombant.
func _dessiner_chutes() -> void:
	var segments := 14
	for o in M.o_a.size():
		if not _chute_active(o):
			continue
		var I := debit_vu[o]
		var src := chute_src[o]
		var dst := chute_dst[o]
		var dir := 1.0 if dst == M.o_b[o] else -1.0
		var xb := float(M.b_x[M.o_b[o]])
		var y0 := M.o_y0[o]
		# la nappe part du seuil avec l'épaisseur de la lèvre : son bord du bas
		# sur le seuil, son bord du haut sur la surface arrondie
		var largeur := levre_vue[o] if levre_vue.size() > o and levre_vue[o] > 0.0 else _levre(o)
		var y_seuil := y0 + largeur * 0.5
		var tuyau := _dans_le_tuyau(src)
		if tuyau:
			# le jet sort du tuyau, à sa hauteur, pas plus large que lui
			var v: Dictionary = M.vannes[robinet_de[src]]
			largeur = minf(largeur, 0.3)
			y_seuil = float(v["y"]) + 0.5
			xb = float(v["x"]) + 0.5 + dir * 0.02
		var pied := _arrivee(o)
		var chute := y_seuil - pied.y
		if chute < 0.05:
			continue
		var portee := pied.x - xb
		var alpha := clampf(0.55 + I * 8.0, 0.6, 0.95)      # un filet reste clair sur le fond sombre
		# La nappe a deux bords, chacun une parabole : le dessus part du haut de
		# la lèvre, dans la pente de la surface arrondie, et devient la face
		# extérieure ; le dessous part du coin même du seuil et devient la face
		# contre la paroi. Au bord, la nappe a donc exactement la tranche
		# verticale de l'eau qui la nourrit — pas de décalage, pas de marche.
		var bas_y := y_seuil - largeur * 0.5
		var haut_y := y_seuil + largeur * 0.5
		var w_pied := largeur * 0.55
		var x_dessus := pied.x + dir * w_pied * 0.5
		var x_dessous := pied.x - dir * w_pied * 0.5
		if (x_dessous - xb) * dir < 0.02:
			x_dessous = xb + dir * 0.02
		var chute_h := haut_y - pied.y
		var chute_b := maxf(bas_y - pied.y, 0.0)
		var a_h := 0.0 if tuyau else clampf(pente_levre[o] * absf(x_dessus - xb), 0.0, chute_h * 0.6)
		var g := PackedVector2Array()
		var d := PackedVector2Array()
		var long := PackedFloat64Array()
		# un point d'avance, caché sous l'eau du bassin (ou dans le tuyau)
		var recul := 0.12 if tuyau else 0.03
		g.append(ecran(xb - dir * recul, haut_y)); d.append(ecran(xb - dir * recul, bas_y)); long.append(0.0)
		var l := 0.0
		var avant := Vector2(xb - dir * recul, y_seuil)
		for i in segments + 1:
			var t := float(i) / segments
			var ph := Vector2(lerpf(xb, x_dessus, t), haut_y - a_h * t - (chute_h - a_h) * t * t)
			var pb := Vector2(lerpf(xb, x_dessous, t), bas_y - chute_b * t * t)
			var milieu := (ph + pb) * 0.5
			l += milieu.distance_to(avant)
			avant = milieu
			g.append(ecran(ph.x, ph.y)); d.append(ecran(pb.x, pb.y)); long.append(l)
		# COLOR.r : 1 pour une nappe qui prolonge l'eau d'un bassin (le shader la
		# fond dans sa couleur au départ), 0 pour le jet du robinet
		# COLOR.g : 1 pour un filet presque tari, que le shader égrène en gouttes
		var filet := 1.0 - smoothstep(FAIBLE * 0.25, FAIBLE * 0.7, I)
		# COLOR.b : la profondeur de la lèvre sous la surface de sa masse, sur 8
		# cases — la nappe part de la teinte de l'eau qu'elle prolonge
		var m := 0.0
		if not tuyau and _ref_vue.size() == M.nb and _ref_vue[src] != -INF:
			m = clampf((_ref_vue[src] - y_seuil) / 8.0, 0.0, 1.0)
		_tracer_ruban(g, d, long, Color(0.0 if tuyau else 1.0, filet, m, alpha), 1.0)   # g : toujours le dessus
	_jets_noyes()


# Le jet d'un robinet dont la case a rejoint l'eau de la colonne voisine : la
# case se dessine au niveau de cette eau (pas en carré plein), et tant que le
# robinet verse, un jet court tombe du tuyau sur la surface.
func _jets_noyes() -> void:
	for k in M.vannes.size():
		var v: Dictionary = M.vannes[k]
		var a: int = v["bassin"]
		if v["type"] != "robinet" or (e.attente[k] <= 0.0 and appui != k) or _xs[a] == null:
			continue
		var x0: int = v["x"]
		if x0 != 0 and x0 != W - 1:
			continue
		var dir := 1.0 if x0 == 0 else -1.0
		var bout := Vector2(float(x0) + 0.5, float(v["y"]) + 0.5)
		var portee := 0.32 * dir
		var pied_y := _haut_en(a, bout.x + portee)
		var chute := bout.y - pied_y
		if chute < 0.08:
			continue                     # le tuyau est noyé : l'eau entre sous la surface
		var g := PackedVector2Array()
		var d := PackedVector2Array()
		var long := PackedFloat64Array()
		var avant := Vector2(bout.x - dir * 0.12, bout.y)
		var l := 0.0
		var segments := 8
		for i in segments + 2:
			var p := avant
			var tangente := Vector2(dir, 0.0)
			if i > 0:
				var s := float(i - 1) / segments
				p = Vector2(bout.x + portee * s, bout.y - chute * s * s)
				tangente = Vector2(portee, -2.0 * chute * s).normalized()
				l += p.distance_to(avant)
			avant = p
			var n := Vector2(-tangente.y, tangente.x) * 0.11 * (1.0 - 0.35 * maxf(0.0, float(i - 1) / segments))
			g.append(ecran(p.x + n.x, p.y + n.y)); d.append(ecran(p.x - n.x, p.y - n.y)); long.append(l)
		_tracer_ruban(g, d, long, Color(0.0, 0.0, 0.0, 0.9), dir)


func _tracer_ruban(g: PackedVector2Array, d: PackedVector2Array, long: PackedFloat64Array, col: Color, dir: float) -> void:
		var cols := PackedColorArray([col, col, col, col])
		var cols3 := PackedColorArray([col, col, col])
		for i in g.size() - 1:
			var quad := PackedVector2Array([g[i], g[i + 1], d[i + 1], d[i]])
			var uv := PackedVector2Array([Vector2(long[i], -dir), Vector2(long[i + 1], -dir), Vector2(long[i + 1], dir), Vector2(long[i], dir)])
			if not Geometry2D.triangulate_polygon(quad).is_empty():
				chutes.draw_polygon(quad, cols, uv)
			else:
				# là où la nappe tourne court (une chute haute et une portée courte),
				# le quadrilatère se croise : deux triangles le couvrent
				chutes.draw_polygon(PackedVector2Array([quad[0], quad[1], quad[3]]), cols3, PackedVector2Array([uv[0], uv[1], uv[3]]))
				chutes.draw_polygon(PackedVector2Array([quad[1], quad[2], quad[3]]), cols3, PackedVector2Array([uv[1], uv[2], uv[3]]))


func _dessiner_gouttes() -> void:
	for i in NB_PARTICULES:
		if p_vie[i] <= 0.0:
			continue
		var f := clampf(p_vie[i] / p_vie0[i], 0.0, 1.0)
		var c := ecran(p_x[i], p_y[i])
		var r := p_taille[i] * case_px
		match p_type[i]:
			GOUTTE:
				gouttes.draw_circle(c, r * (0.6 + 0.4 * f), Color(0.86, 0.97, 1.0, 0.9 * minf(1.0, f * 2.0)))
			BULLE:
				gouttes.draw_arc(c, r, 0.0, TAU, 12, Color(0.9, 0.98, 1.0, 0.75), maxf(1.0, r * 0.35), true)
			_:
				gouttes.draw_circle(c, r * (0.7 + 0.3 * f), Color(0.95, 0.99, 1.0, 0.8 * f))


# --- les vannes, la boule -----------------------------------------------------------
func _dessiner_vannes() -> void:
	for k in M.vannes.size():
		var v: Dictionary = M.vannes[k]
		var b := bouton(v)
		var rob: bool = v["type"] == "robinet"
		var actif: bool = e.attente[k] > 0.0 or presse[k] > 0 or appui == k
		var enfonce := 0.08 if actif else 0.0
		var c := ecran(b.x, b.y)
		vannes_n.draw_circle(c + Vector2(0, 0.08 * case_px), 0.62 * case_px, ROBINET_OMBRE if rob else VIDANGE_OMBRE)
		var cc := c + Vector2(0, enfonce * case_px)
		vannes_n.draw_circle(cc, 0.6 * case_px, ROBINET if rob else VIDANGE)
		vannes_n.draw_arc(cc, 0.6 * case_px, 0, TAU, 48, Color.WHITE, maxf(1.5, 0.06 * case_px), true)
		var s := case_px
		if rob:
			vannes_n.draw_circle(cc + Vector2(0, 0.09) * s, 0.2 * s, Color.WHITE)
			vannes_n.draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -0.32) * s, cc + Vector2(0.18, 0.02) * s, cc + Vector2(-0.18, 0.02) * s]), Color.WHITE)
		else:
			for q in 3:
				var l := 0.26 - q * 0.08
				vannes_n.draw_line(cc + Vector2(-l, -0.1 + q * 0.16) * s, cc + Vector2(l, -0.1 + q * 0.16) * s, Color.WHITE, 0.09 * s)
			# une vidange ouverte tourbillonne à la surface au-dessus d'elle
			if e.attente[k] > 0.0:
				var a: int = v["bassin"]
				var h := minf(M.niveau_bassin(e, a), float(v["y"]) + 1.0) - 0.12
				for q in 3:
					var t := -temps * 9.0 + q * 2.09
					var r := 0.12 + 0.1 * q
					vannes_n.draw_circle(ecran(float(v["x"]) + 0.5 + cos(t) * r, h + sin(t) * r * 0.35), 0.05 * case_px, ECUME)


# Le bassin de la boule s'il a une surface libre sous elle, sinon -1.
func _bassin_boule(x: float, y: float) -> int:
	var cx := floori(x)
	var cy := floori(y)
	if cx < 0 or cy < 0 or cx >= W or cy >= H:
		return -1
	var a := M.bassin_de[cy * W + cx]
	if a < 0 or e.vol[a] <= 0.02:
		return -1
	return a


# La boule s'incline avec la pente de la surface sous elle : la normale de
# l'eau devient son « haut ». Un ressort amorti, pour qu'elle suive les vagues
# sans trembler ; sous un plafond ou au sec, elle se redresse.
func _incliner(dt: float) -> void:
	var cible := 0.0
	var a := _bassin_boule(e.bx, e.by)
	if a >= 0 and M.libre(e, a) and absf(M.surface_en(e, a, e.bx) - e.by) < 0.5:
		var pente := (_surface_vue(a, e.bx + 0.15) - _surface_vue(a, e.bx - 0.15)) / 0.3
		cible = -atan(pente) * 0.9
	incline_v += ((cible - incline) * INCLINE_PULS * INCLINE_PULS - 2.0 * INCLINE_AMORTI * INCLINE_PULS * incline_v) * dt
	incline += incline_v * dt


func _dessiner_boule() -> void:
	var f := clampf(acc / PAS_S, 0.0, 1.0)
	var x := lerpf(boule_avant.x, e.bx, f)
	var y := lerpf(boule_avant.y, e.by, f)
	var ang := lerpf(angle_avant, angle, f) + incline
	var r_c := Moteur.RAYON
	# la surface sous la boule, telle qu'on la voit ; la boule qui flotte suit
	# aussi la petite houle de repos de l'affichage
	# (celle qu'on a dessinée : un puits au niveau commun, une lèvre arrondie)
	var a := _bassin_boule(x, y)
	var eau_haut := -INF
	if a >= 0:
		var dessinee := a < _xs.size() and _xs[a] != null
		var puits := a < _niv_puits.size() and _niv_puits[a] != -INF
		if dessinee and (M.libre(e, a) or puits):
			eau_haut = _haut_en(a, x)
			var moteur := M.surface_en(e, a, x) if M.libre(e, a) else float(M.b_haut[a])
			if absf(moteur - y) < 0.5:
				y += eau_haut - moteur
				if M.b_ferme[a] == 1:
					y = minf(y, float(M.b_haut[a]) - r_c)
		elif M.libre(e, a):
			eau_haut = _surface_vue(a, x)
		else:
			eau_haut = float(M.b_haut[a]) + 1.0
	var c := ecran(x, y)
	var r := r_c * case_px
	boule_n.draw_circle(c, r, BLANC)
	var demi := PackedVector2Array()
	for q in 17:
		var t := ang + PI + PI * q / 16.0
		demi.append(c + Vector2(cos(t), sin(t)) * r)
	boule_n.draw_colored_polygon(demi, ROUGE)
	var axe := Vector2(cos(ang), sin(ang)) * r
	boule_n.draw_line(c - axe, c + axe, ROUGE_OMBRE, 0.08 * case_px)
	boule_n.draw_arc(c, r, 0, TAU, 40, BLANC_OMBRE, 0.04 * case_px, true)
	boule_n.draw_circle(c + Vector2(-0.35, -0.5) * r, 0.22 * r, Color(1, 1, 1, 0.7))
	# la part immergée : voilée d'eau, sous une ligne de flottaison claire
	if eau_haut > y - r_c:
		var voile := PackedVector2Array()
		if eau_haut >= y + r_c:
			for q in 33:
				var t := TAU * q / 32.0
				voile.append(ecran(x + cos(t) * r_c, y + sin(t) * r_c))
		else:
			var t0 := asin(clampf((eau_haut - y) / r_c, -1.0, 1.0))
			for q in 25:
				var t := lerpf(PI - t0, TAU + t0, q / 24.0)
				voile.append(ecran(x + cos(t) * r_c, y + sin(t) * r_c))
			var g := ecran(x - cos(t0) * r_c, eau_haut)
			var d := ecran(x + cos(t0) * r_c, eau_haut)
			boule_n.draw_colored_polygon(voile, Color(0.3, 0.72, 1.0, 0.3))
			boule_n.draw_line(g, d, Color(0.82, 0.96, 1.0, 0.9), maxf(1.5, 0.05 * case_px), true)
			return
		boule_n.draw_colored_polygon(voile, Color(0.3, 0.72, 1.0, 0.3))


# --- sans les doigts ---------------------------------------------------------------
# Joue la solution écrite comme un joueur : les vidanges une à une, puis le
# robinet tenu ; avance d'un pas par image et photographie les images voulues.
var _script_vu := false
# LABY_GESTES joue une suite de gestes écrite à la main et photographie une
# image toutes les LABY_TOUTES images du moteur (12 : toutes les 0,2 s),
# jusqu'à LABY_FIN, sous le nom LABY_NOM. Un geste « image:k » tape la vanne
# k, « image:+k » la tient, « image:- » la relâche. Pour traquer les défauts
# de rendu sur toute une manœuvre, pas seulement sur quelques images.
var _gestes := {}
func _filmer() -> void:
	if _gestes.is_empty():
		for g in OS.get_environment("LABY_GESTES").split(" ", false):
			var p := g.split(":")
			_gestes[int(p[0])] = p[1]
	if _gestes.has(image):
		var g: String = _gestes[image]
		if g == "-":
			appui = -1
		elif g.begins_with("+"):
			var k := int(g.substr(1))
			_taper(k); appui = k; appui_depuis = image
		else:
			_taper(int(g))
	_pas()
	acc = 0.0
	var toutes := int(OS.get_environment("LABY_TOUTES")) if OS.get_environment("LABY_TOUTES") != "" else 12
	var fin := int(OS.get_environment("LABY_FIN")) if OS.get_environment("LABY_FIN") != "" else 900
	if image % toutes == 0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s-%04d.png" % [capture, OS.get_environment("LABY_NOM"), image])
	if image >= fin:
		get_tree().quit()

func _capturer() -> void:
	if OS.get_environment("LABY_GESTES") != "":
		_filmer()
		return
	if not _script_vu:
		_script_vu = true
	var demo := OS.get_environment("LABY_DEMO")
	if demo != "":
		# « chute », une chute haute : la vidange de gauche tenue d'abord (le
		# bassin de gauche se vide), puis le robinet tenu, qui retombe de haut.
		# « deversoir » : le robinet tenu remplit tout, puis la vidange de droite
		# tenue fait déborder le couloir dans la colonne de droite
		var premier := 1 if demo == "chute" else 0
		var second := 0 if demo == "chute" else 2
		if image == 10:
			appui = premier; appui_depuis = image; _taper(premier)
		if image == 200:
			appui = -1
		if image == 230:
			_taper(second); appui = second; appui_depuis = image
		_pas()
		acc = 0.0
		if a_capturer.has(image):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s-%03d.png" % [capture, demo, image])
		if image > a_capturer.max() + 2:
			get_tree().quit()
		return
	var sol := String(N["solution"])
	var nb_vidanges := 0
	while nb_vidanges < sol.length() and sol[nb_vidanges] != sol[sol.length() - 1]:
		nb_vidanges += 1
	var k_vidange := int(sol[0]) - 1
	var k_robinet := int(sol[sol.length() - 1]) - 1
	for i in nb_vidanges:
		if image == 30 + 70 * i:
			_taper(k_vidange)
	if image == 30 + 70 * nb_vidanges:
		_taper(k_robinet); appui = k_robinet; appui_depuis = image
	_pas()
	acc = 0.0
	if a_capturer.has(image):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/godot-%03d.png" % [capture, image])
	if image > a_capturer.max() + 2:
		get_tree().quit()
