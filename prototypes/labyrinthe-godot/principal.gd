extends Node2D
# ------------------------------------------------------------------
# Le rendu de l'eau du labyrinthe, rejoué depuis un film.
#
# Ce projet ne calcule rien : il rejoue film.json, que fabrique le moteur
# de la page web (node tools/labyrinthe-film.mjs), et le dessine. On juge
# ainsi le rendu sur l'iPhone avant de porter le moteur (plan d'essai,
# étape 2 — reports/Animation de fluides pour jeu.md).
#
# Les couches, du fond vers l'avant : le décor (cadre, creux), l'eau (un
# shader sur le champ du film), les bords de mur (qui coupent net l'eau
# enfoncée dans les murs), les vannes, la boule, les compteurs.
#
# Toucher l'écran relance le film. LABY_CAPTURE=<dossier> photographie
# quelques images puis quitte (vérification sans les doigts).
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
const IMAGES_PAR_SECONDE := 60.0      # le film : une image par pas de jeu
const PAUSE_FIN := 1.5                # secondes, avant de reprendre le film

var film: Dictionary
var grille: Array                     # rangée du haut d'abord, comme dans la page
var W: int
var H: int
var S: int
var champ: PackedByteArray
var n_cases: int
var n_images: int
var boule: PackedFloat32Array
var angles: PackedFloat32Array        # la rotation de la boule, cumulée sur le film
var actives: Array

var case_px := 50.0                   # une case du labyrinthe, en pixels
var origine := Vector2.ZERO           # le coin bas-gauche du labyrinthe, à l'écran
var t := 0.0                          # le temps du film, en images
var image_chargee := -1
var image_a: Image
var image_b: Image
var tex_a: ImageTexture
var tex_b: ImageTexture

var fond: Node2D
var eau: ColorRect
var murs: Node2D
var vannes: Node2D
var boule_n: Node2D
var compteur: Label

var capture := ""
var a_capturer := [30, 150, 190, 215, 240, 280, 330, 380]
var images_rendues := 0


func _ready() -> void:
	var f := FileAccess.open("res://film.json", FileAccess.READ)
	film = JSON.parse_string(f.get_as_text())
	grille = film.grille
	W = int(film.W); H = int(film.H); S = int(film.S)
	champ = Marshalls.base64_to_raw(film.champ)
	n_cases = W * S * H * S
	n_images = int(film.images)
	boule = PackedFloat32Array(film.boule)
	actives = film.actives
	angles = PackedFloat32Array()
	angles.resize(n_images)
	var a := 0.0
	for k in range(1, n_images):
		var dx: float = boule[2 * k] - boule[2 * k - 2]
		if absf(dx) < 1.0:
			a += dx / float(film.rayon)
		angles[k] = a

	fond = Node2D.new(); add_child(fond); fond.draw.connect(_dessiner_fond)
	eau = ColorRect.new(); add_child(eau)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://eau.gdshader")
	eau.material = mat
	murs = Node2D.new(); add_child(murs); murs.draw.connect(_dessiner_murs)
	vannes = Node2D.new(); add_child(vannes); vannes.draw.connect(_dessiner_vannes)
	boule_n = Node2D.new(); add_child(boule_n); boule_n.draw.connect(_dessiner_boule)
	var hud := CanvasLayer.new(); add_child(hud)
	compteur = Label.new(); hud.add_child(compteur)
	compteur.position = Vector2(16, 40)
	compteur.add_theme_font_size_override("font_size", 20)

	image_a = Image.create_empty(W * S, H * S, false, Image.FORMAT_L8)
	image_b = Image.create_empty(W * S, H * S, false, Image.FORMAT_L8)
	tex_a = ImageTexture.create_from_image(image_a)
	tex_b = ImageTexture.create_from_image(image_b)
	mat.set_shader_parameter("champ_a", tex_a)
	mat.set_shader_parameter("champ_b", tex_b)
	mat.set_shader_parameter("taille", Vector2(W * S, H * S))
	var carte_murs := Image.create_empty(W * S, H * S, false, Image.FORMAT_L8)
	for fy in H * S:
		for fx in W * S:
			if mur(fx / S, H - 1 - fy / S):
				carte_murs.set_pixel(fx, fy, Color.WHITE)
	mat.set_shader_parameter("murs", ImageTexture.create_from_image(carte_murs))
	mat.set_shader_parameter("finesse", float(S))

	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	get_viewport().size_changed.connect(_cadrer)
	_cadrer()
	capture = OS.get_environment("LABY_CAPTURE")


# Le labyrinthe et ses boutons tiennent dans l'écran : on prend la plus
# grande case qui laisse la place au robinet à gauche et aux vidanges en bas.
func _cadrer() -> void:
	var ecran := get_viewport_rect().size
	var gauche := 2.0
	var droite := 0.7
	var haut := 1.4
	var bas := 2.2
	var largeur_cases := W + gauche + droite
	var hauteur_cases := H + haut + bas
	case_px = minf(ecran.x / largeur_cases, (ecran.y - 140.0) / hauteur_cases)
	var x0 := (ecran.x - largeur_cases * case_px) / 2.0 + gauche * case_px
	var y_haut := 140.0 + (ecran.y - 140.0 - hauteur_cases * case_px) / 2.0 + haut * case_px
	origine = Vector2(x0, y_haut + H * case_px)
	eau.position = Vector2(origine.x, origine.y - H * case_px)
	eau.size = Vector2(W * case_px, H * case_px)
	for n in [fond, murs, vannes, boule_n]:
		n.queue_redraw()


# Une case du labyrinthe (x vers la droite, y vers le HAUT) vers l'écran.
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


# Les bords de mur, au-dessus de l'eau : l'eau s'enfonce d'une petite case
# dans les murs (le champ du film l'y prolonge), une bande de sable de
# 0,3 case autour de chaque creux la coupe net — sans toucher aux coins
# arrondis du cadre.
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
	var e := maxf(1.5, case_px * 0.06)
	for y in H:
		for x in W:
			if mur(x, y):
				continue
			var dedans := func(nx: int, ny: int) -> bool: return nx >= 0 and ny >= 0 and nx < W and ny < H and mur(nx, ny)
			if dedans.call(x - 1, y): murs.draw_line(ecran(x, y), ecran(x, y + 1), SABLE_BORD, e)
			if dedans.call(x + 1, y): murs.draw_line(ecran(x + 1, y), ecran(x + 1, y + 1), SABLE_BORD, e)
			if dedans.call(x, y - 1): murs.draw_line(ecran(x, y), ecran(x + 1, y), SABLE_BORD, e)
			if dedans.call(x, y + 1): murs.draw_line(ecran(x, y + 1), ecran(x + 1, y + 1), SABLE_BORD, e)
	var cadre := StyleBoxFlat.new()
	cadre.draw_center = false
	cadre.border_color = SABLE_BORD
	cadre.set_border_width_all(int(maxf(2.0, case_px * 0.08)))
	cadre.set_corner_radius_all(int(case_px * 0.45))
	murs.draw_style_box(cadre, rect_cases(-0.15, -0.15, W + 0.15, H + 0.15))


func bouton(v: Dictionary) -> Vector2:
	var x: float = v.x
	var y: float = v.y
	if v.type == "vidange":
		return Vector2(x + 0.5, -1.15)
	if x == 0:
		return Vector2(-1.15, y + 0.5)
	if x == W - 1:
		return Vector2(W + 1.15, y + 0.5)
	return Vector2(x + 0.5, H + 1.15)


func _dessiner_vannes() -> void:
	var k_image := clampi(int(t), 0, n_images - 1)
	var bits: int = int(actives[k_image])
	for k in film.vannes.size():
		var v: Dictionary = film.vannes[k]
		var b := bouton(v)
		var cx: float = v.x + 0.5
		var cy: float = v.y + 0.5
		if v.type == "vidange":
			vannes.draw_rect(rect_cases(cx - 0.17, b.y, cx + 0.17, v.y + 0.05), TUYAU)
			for q in 3:
				vannes.draw_rect(rect_cases(v.x + 0.18 + q * 0.24, v.y, v.x + 0.3 + q * 0.24, v.y + 0.09), TUYAU_OMBRE)
		elif b.y == cy:
			vannes.draw_rect(rect_cases(minf(b.x, cx), cy - 0.17, maxf(b.x, cx), cy + 0.17), TUYAU)
		else:
			vannes.draw_rect(rect_cases(cx - 0.17, v.y + 0.85, cx + 0.17, b.y), TUYAU)
		var rob: bool = v.type == "robinet"
		var enfonce := 0.08 if bits & (1 << k) else 0.0
		var c := ecran(b.x, b.y)
		vannes.draw_circle(c + Vector2(0, 0.08 * case_px), 0.62 * case_px, ROBINET_OMBRE if rob else VIDANGE_OMBRE)
		var cc := c + Vector2(0, enfonce * case_px)
		vannes.draw_circle(cc, 0.6 * case_px, ROBINET if rob else VIDANGE)
		vannes.draw_arc(cc, 0.6 * case_px, 0, TAU, 48, Color.WHITE, maxf(1.5, 0.06 * case_px), true)
		var s := case_px
		if rob:
			vannes.draw_circle(cc + Vector2(0, 0.09) * s, 0.2 * s, Color.WHITE)
			vannes.draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -0.32) * s, cc + Vector2(0.18, 0.02) * s, cc + Vector2(-0.18, 0.02) * s]), Color.WHITE)
		else:
			for q in 3:
				var l := 0.26 - q * 0.08
				vannes.draw_line(cc + Vector2(-l, -0.1 + q * 0.16) * s, cc + Vector2(l, -0.1 + q * 0.16) * s, Color.WHITE, 0.09 * s)


func _dessiner_boule() -> void:
	var k := clampi(int(t), 0, n_images - 1)
	var k2 := mini(k + 1, n_images - 1)
	var f := clampf(t - k, 0.0, 1.0)
	var x := lerpf(boule[2 * k], boule[2 * k2], f)
	var y := lerpf(boule[2 * k + 1], boule[2 * k2 + 1], f)
	var ang := lerpf(angles[k], angles[k2], f)
	var c := ecran(x, y)
	var r := float(film.rayon) * case_px
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


func charger_image(img: Image, k: int) -> void:
	var k_sur := clampi(k, 0, n_images - 1)
	img.set_data(W * S, H * S, false, Image.FORMAT_L8, champ.slice(k_sur * n_cases, (k_sur + 1) * n_cases))


func _process(delta: float) -> void:
	t += delta * IMAGES_PAR_SECONDE
	if t > n_images - 1 + PAUSE_FIN * IMAGES_PAR_SECONDE:
		t = 0.0
	var k := clampi(int(t), 0, n_images - 1)
	if k != image_chargee:
		charger_image(image_a, k)
		charger_image(image_b, k + 1)
		tex_a.update(image_a)
		tex_b.update(image_b)
		image_chargee = k
	eau.material.set_shader_parameter("melange", clampf(t - k, 0.0, 1.0))
	vannes.queue_redraw()
	boule_n.queue_redraw()
	var rid := get_viewport().get_viewport_rid()
	compteur.text = "%d i/s · processeur %.1f ms · carte graphique %.1f ms\nimage %d / %d — toucher pour reprendre" % [
		Engine.get_frames_per_second(),
		RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(rid), k, n_images - 1]
	if capture != "":
		_capturer()


func _input(ev: InputEvent) -> void:
	if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed):
		t = 0.0


# Sans les doigts : on avance le film image par image (pas l'horloge) et on
# photographie la fenêtre aux images voulues.
func _capturer() -> void:
	images_rendues += 1
	t = float(images_rendues)
	if a_capturer.has(images_rendues - 2):
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/godot-%03d.png" % [capture, images_rendues - 2])
	if images_rendues > a_capturer.max() + 3:
		get_tree().quit()
