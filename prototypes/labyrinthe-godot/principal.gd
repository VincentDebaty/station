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
var fini := false
var attente_fin := 0
var ms_pas := 0.0
var ms_pire := 0.0

var fond: Node2D
var eau: Node2D
var murs: Node2D
var vannes_n: Node2D
var boule_n: Node2D
var titre: Label
var compteur: Label
var mesure: Label
var carte: PanelContainer
var carte_texte: Label

var capture := ""
var a_capturer := [60, 240, 300, 330, 400, 520, 700, 800]


func _ready() -> void:
	N = JSON.parse_string(FileAccess.get_file_as_string("res://niveau.json"))
	grille = N["grille"]
	W = String(grille[0]).length(); H = grille.size()
	M = Moteur.new(N)
	presse.resize(M.vannes.size()); presse.fill(0)

	fond = Node2D.new(); add_child(fond); fond.draw.connect(_dessiner_fond)
	eau = Node2D.new(); add_child(eau); eau.draw.connect(_dessiner_eau)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://eau.gdshader")
	eau.material = mat
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
	angle = 0.0; angle_avant = 0.0
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
	eau.queue_redraw()
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
	var h := M.surface_en(e, a, x)
	return h + ONDULATION * (sin(x * 2.3 + temps * 1.7) * 0.6 + sin(x * 5.1 - temps * 2.3) * 0.4)


func _dessiner_eau() -> void:
	var blanc := Color.WHITE
	for a in M.nb:
		var vol := e.vol[a]
		if vol < 0.004:
			continue
		var x0 := float(M.b_x[a]) - 0.04
		var x1 := float(M.b_x[a]) + 1.04
		var bas := float(M.b_bas[a]) - 0.04
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var tops := PackedFloat64Array()
		var xs := PackedFloat64Array()
		if M.libre(e, a):
			for p in Moteur.POINTS + 1:
				var x := lerpf(x0, x1, float(p) / Moteur.POINTS)
				xs.append(x)
				tops.append(_surface_vue(a, clampf(x, float(M.b_x[a]), float(M.b_x[a]) + 1.0)))
		else:
			var h := float(M.b_haut[a]) + 0.04
			xs.append(x0); tops.append(h); xs.append(x1); tops.append(h)
		# le fond, de gauche à droite, puis la surface, de droite à gauche
		pts.append(ecran(x0, bas)); uvs.append(Vector2(x0, tops[0] - bas)); cols.append(blanc)
		pts.append(ecran(x1, bas)); uvs.append(Vector2(x1, tops[tops.size() - 1] - bas)); cols.append(blanc)
		for i in range(xs.size() - 1, -1, -1):
			pts.append(ecran(xs[i], tops[i])); uvs.append(Vector2(xs[i], 0.0)); cols.append(blanc)
		eau.draw_polygon(pts, cols, uvs)
	_dessiner_cascades()


# Les cascades : à travers une ouverture dont le bassin d'arrivée est plus bas
# que le seuil, l'eau tombe en nappe, d'autant plus large et projetée que le
# débit est fort, jusqu'à la surface d'arrivée.
func _dessiner_cascades() -> void:
	var blanc := Color.WHITE
	for o in M.o_a.size():
		var q := absf(e.flux[o])
		if q < 0.0008:
			continue
		var src := M.o_a[o] if e.flux[o] > 0.0 else M.o_b[o]
		var dst := M.o_b[o] if e.flux[o] > 0.0 else M.o_a[o]
		var y0 := M.o_y0[o]
		var hd := M.charge(e, dst)
		if hd >= y0:
			continue
		var dir := 1.0 if e.flux[o] > 0.0 else -1.0
		var xb := float(M.b_x[M.o_b[o]])
		var hs := minf(M.charge(e, src), M.o_y1[o])
		var ep := clampf(q * 5.0, 0.05, maxf(0.05, hs - y0))
		var portee := 0.08 + 0.6 * sqrt(q)
		var arrivee := maxf(hd, float(M.b_bas[dst]))
		var g := PackedVector2Array()
		var d := PackedVector2Array()
		var segments := 10
		for i in segments + 1:
			var s := float(i) / segments
			var cx := xb + dir * portee * s
			var cy := y0 + ep * 0.5 - (y0 + ep * 0.5 - arrivee) * s * s
			var demi := ep * 0.5 * (1.0 - 0.35 * s)
			g.append(ecran(cx - dir * demi * 0.3, cy + demi))
			d.append(ecran(cx + dir * demi * 0.3, cy - demi))
		# tronçon par tronçon : chaque quadrilatère est convexe, rien à trianguler de travers
		var uv := PackedVector2Array([Vector2(xb, 0.12), Vector2(xb, 0.12), Vector2(xb, 0.12), Vector2(xb, 0.12)])
		var cols := PackedColorArray([blanc, blanc, blanc, blanc])
		for i in segments:
			eau.draw_polygon(PackedVector2Array([g[i], g[i + 1], d[i + 1], d[i]]), cols, uv)
		# l'écume au pied de la chute
		var pied := ecran(xb + dir * portee, arrivee)
		for k in 3:
			var a := temps * 9.0 + k * 2.1
			var r := (0.04 + 0.03 * k) * case_px * clampf(q * 12.0, 0.4, 1.4)
			eau.draw_circle(pied + Vector2(sin(a) * 0.18 * case_px, -absf(cos(a)) * 0.12 * case_px), r, ECUME)


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


func _dessiner_boule() -> void:
	var f := clampf(acc / PAS_S, 0.0, 1.0)
	var x := lerpf(boule_avant.x, e.bx, f)
	var y := lerpf(boule_avant.y, e.by, f)
	var ang := lerpf(angle_avant, angle, f)
	var c := ecran(x, y)
	var r := Moteur.RAYON * case_px
	boule_n.draw_circle(c, r, BLANC)
	var demi := PackedVector2Array()
	for q in 17:
		var a := ang + PI + PI * q / 16.0
		demi.append(c + Vector2(cos(a), sin(a)) * r)
	boule_n.draw_colored_polygon(demi, ROUGE)
	var axe := Vector2(cos(ang), sin(ang)) * r
	boule_n.draw_line(c - axe, c + axe, ROUGE_OMBRE, 0.08 * case_px)
	boule_n.draw_arc(c, r, 0, TAU, 40, BLANC_OMBRE, 0.04 * case_px, true)
	boule_n.draw_circle(c + Vector2(-0.35, -0.5) * r, 0.22 * r, Color(1, 1, 1, 0.7))


# --- sans les doigts ---------------------------------------------------------------
# Joue la solution écrite comme un joueur : les vidanges une à une, puis le
# robinet tenu ; avance d'un pas par image et photographie les images voulues.
var _script_vu := false
func _capturer() -> void:
	if not _script_vu:
		_script_vu = true
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
