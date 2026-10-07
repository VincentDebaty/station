class_name Glacon
extends Node2D
# ------------------------------------------------------------------
# LE GROS GLAÇON ET SON BRASERO (chapitre 6, nuit du 7 au 8 octobre 2026) :
# sur la berge du fond, au-dessus du bassin qu'il remplira, un bloc de glace,
# et à côté un brasero de fer. Toucher le brasero l'allume (le moteur :
# « allumer ») ; le bloc fond alors en « fonte » coups, et à chacun une part
# de son eau coule le long du mur dans le bassin. Le bloc rapetisse d'autant,
# une flaque s'élargit à son pied. Fondu, il ne reste que la flaque et les
# braises.
#
# Vue oblique de la scène : on voit la face avant, le dessus et la face
# GAUCHE du bloc (la profondeur part en haut à gauche, comme le canal).
# Dessiné ici, en attendant art/glacon.png et art/brasero.png (prompts dans
# ASSETS.md) ; la flamme, l'eau et la vapeur restent dessinées.
# Repère : « base » est le milieu du pied du bloc, posé sur la berge du fond.
# ------------------------------------------------------------------

signal allume_fini

var base := Vector2.ZERO
var x_feu := 0.0           # le pied du brasero, à droite du bloc
var reste := 1.0           # la part de glace qui reste, telle qu'affichée
var feu := 0.0             # 0 éteint, 1 vif, telle qu'affichée
var feu_cible := 0.0
var coule := 0.0           # 0..1 : l'eau de fonte coule (le canal la règle)
var y_eau := 0.0           # la surface du bassin contre le mur du fond (y monde)
var actif := true
var _t := 0.0
var _allume := -1.0
var _etincelles := []      # [position, vitesse, âge, durée]
var _gouttes := []         # [position, vitesse]
var _rng := RandomNumberGenerator.new()
var _img_bloc: Texture2D
var _img_feu: Texture2D

const L := 70.0            # le bloc entier
const H := 60.0
const P := Vector2(-15.0, -13.0)   # la profondeur du bloc, dans le sens du canal
const CONTOUR := Color("#2b5d77")
const BRUN := Color("#3b2414")

func preparer(abase: Vector2, ax_feu: float, areste: float, allume: bool) -> void:
	base = abase
	x_feu = ax_feu
	reste = areste
	feu = 1.0 if allume and areste > 0.0 else (0.22 if allume else 0.0)
	feu_cible = feu
	_rng.seed = 11
	if ResourceLoader.exists("res://art/glacon.png"): _img_bloc = Images.reduire("res://art/glacon.png", 220)
	if ResourceLoader.exists("res://art/brasero.png"): _img_feu = Images.reduire("res://art/brasero.png", 140)

func sous(p: Vector2) -> bool:
	return Rect2(base.x - L * 0.6, base.y - H - 60.0, (x_feu - base.x) + L * 0.6 + 50.0, H + 76.0).has_point(p)

func allumer() -> void:
	_allume = 0.0
	feu_cible = 1.0

func _process(dt: float) -> void:
	_t += dt
	if _allume >= 0.0:
		_allume += dt
		if _allume >= 0.45:
			_allume = -1.0
			allume_fini.emit()
	feu = move_toward(feu, feu_cible, dt * 1.6)
	# des étincelles qui montent du brasero
	if feu > 0.3 and _rng.randf() < dt * 7.0 * feu:
		_etincelles.append([Vector2(x_feu + _rng.randf_range(-10, 10), base.y - 45.0), Vector2(_rng.randf_range(-14, 10), _rng.randf_range(-70, -40)), 0.0, _rng.randf_range(0.6, 1.1)])
	for e in _etincelles:
		e[2] += dt
		e[0] += e[1] * dt
		e[1].x += sin(_t * 9.0 + e[3] * 20.0) * 30.0 * dt
	_etincelles = _etincelles.filter(func(e): return e[2] < e[3])
	# le bloc goutte tant que le feu brûle à côté
	if feu > 0.5 and reste > 0.02 and _rng.randf() < dt * 5.0:
		var w := _largeur()
		_gouttes.append([Vector2(base.x + _rng.randf_range(-w * 0.45, w * 0.45), base.y - 2.0), 0.0])
	for g in _gouttes:
		g[1] += 260.0 * dt
		g[0].y += g[1] * dt
	_gouttes = _gouttes.filter(func(g): return g[0].y < y_eau - 2.0)
	modulate = modulate.lerp(Color(1, 1, 1) if actif or feu > 0.1 else Color(0.82, 0.8, 0.8), minf(1.0, dt * 6.0))
	queue_redraw()

func _largeur() -> float:
	return L * (0.5 + 0.5 * reste)

func _hauteur() -> float:
	return maxf(H * pow(reste, 0.85), 4.0)

func _draw() -> void:
	_dessiner_flaque()
	_dessiner_filets()
	if reste > 0.02:
		if _img_bloc:
			var w := _largeur() + 15.0
			var h := _hauteur() + 13.0
			draw_texture_rect(_img_bloc, Rect2(base.x - w * 0.5 - 8.0, base.y - h, w, h), false)
		else:
			_dessiner_bloc()
	_dessiner_brasero()
	for e in _etincelles:
		var a: float = 1.0 - e[2] / e[3]
		draw_circle(e[0], 1.8, Color(1.0, 0.85, 0.35, a))
		draw_circle(e[0], 3.5, Color(1.0, 0.55, 0.15, 0.25 * a))

# La flaque au pied du bloc, de plus en plus large à mesure qu'il fond.
func _dessiner_flaque() -> void:
	# l'ombre du bloc sur l'herbe
	if reste > 0.02:
		draw_set_transform(base + Vector2(3.0, -1.0), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, _largeur() * 0.62, Color(0.05, 0.1, 0.15, 0.22))
		draw_set_transform(Vector2.ZERO)
	var fondu := 1.0 - reste
	if fondu < 0.02 and feu < 0.1: return
	var rx := L * (0.35 + 0.45 * fondu)
	draw_set_transform(base + Vector2(-4.0, -3.0), 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, rx, Color(0.35, 0.55, 0.62, 0.35))
	draw_circle(Vector2(-rx * 0.2, -rx * 0.15), rx * 0.6, Color(0.8, 0.95, 1.0, 0.25))
	draw_set_transform(Vector2.ZERO)

# L'eau de fonte : des filets qui passent le bord de la berge et descendent le
# long du mur jusqu'à l'eau du bassin, avec leurs reflets qui glissent ; et les
# gouttes du bloc.
func _dessiner_filets() -> void:
	for g in _gouttes:
		draw_circle(g[0], 1.6, Color(0.82, 0.95, 1.0, 0.85))
	if coule <= 0.02 or y_eau <= base.y: return
	var w := _largeur()
	for k in 3:
		var x0 := base.x + (k - 1) * w * 0.28 + 4.0 * sin(k * 2.1)
		var ep := (2.6 + 1.6 * coule) * (1.25 if k == 1 else 0.8)
		var pts := PackedVector2Array()
		var y := base.y - 1.0
		while y < y_eau:
			pts.append(Vector2(x0 + 0.7 * sin(y * 0.09 + _t * 5.0 + k), y))
			y += 6.0
		pts.append(Vector2(x0, y_eau))
		if pts.size() < 2: continue
		draw_polyline(pts, Color(0.55, 0.82, 0.95, 0.75 * coule), ep + 1.6, true)
		draw_polyline(pts, Color(0.86, 0.97, 1.0, 0.9 * coule), ep * 0.55, true)
		# les reflets qui descendent
		var lg := y_eau - base.y
		for r in 2:
			var yy := base.y + fmod(_t * 140.0 + r * lg * 0.5 + k * 37.0, maxf(lg, 1.0))
			draw_line(Vector2(x0, yy), Vector2(x0, minf(yy + 7.0, y_eau)), Color(1, 1, 1, 0.8 * coule), ep * 0.5, true)
		# l'éclaboussure en bas
		draw_set_transform(Vector2(x0, y_eau), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, 5.0 + 2.0 * sin(_t * 12.0 + k), 0.0, TAU, 14, Color(1, 1, 1, 0.65 * coule), 1.5, true)
		draw_set_transform(Vector2.ZERO)

# Le bloc de glace : la face gauche, le dessus, la face avant ; des reflets,
# des bulles prises dans la glace, une fissure, un peu de neige sur le dessus.
# En fondant, ses arêtes s'arrondissent.
func _dessiner_bloc() -> void:
	var w := _largeur()
	var h := _hauteur()
	var x0 := base.x - w * 0.5
	var x1 := base.x + w * 0.5
	var y0 := base.y
	var y1 := base.y - h
	var r := minf(4.0 + 12.0 * (1.0 - reste), minf(w, h) * 0.45)      # l'arrondi des arêtes
	var avant := _rect_arrondi(x0, y1, x1, y0, r)
	# la face gauche et le dessus, derrière la face avant
	var gauche := PackedVector2Array([Vector2(x0, y0 - r * 0.3), Vector2(x0, y1 + r), Vector2(x0, y1 + r) + P, Vector2(x0, y0 - r * 0.3) + P])
	draw_polygon(gauche, PackedColorArray([Color("#6fb6d6"), Color("#a5daf0"), Color("#b8e3f4"), Color("#7cbdd9")]))
	var dessus := PackedVector2Array([Vector2(x0 + r, y1), Vector2(x1 - r, y1), Vector2(x1 - r, y1) + P, Vector2(x0 + r, y1) + P])
	var dessus_g := PackedVector2Array([Vector2(x0, y1 + r), Vector2(x0 + r, y1), Vector2(x0 + r, y1) + P, Vector2(x0, y1 + r) + P])
	draw_colored_polygon(dessus_g, Color("#d9f2fc"))
	draw_colored_polygon(dessus, Color("#eef9ff"))
	var tour := PackedVector2Array([Vector2(x0, y0 - r * 0.3) + P, Vector2(x0, y1 + r) + P, Vector2(x0 + r, y1) + P, Vector2(x1 - r, y1) + P, Vector2(x1 - r, y1)])
	draw_polyline(tour, CONTOUR, 2.0, true)
	draw_line(Vector2(x0, y0 - r * 0.3), Vector2(x0, y0 - r * 0.3) + P, CONTOUR, 2.0, true)
	# la face avant : un dégradé de bleu glacier, plus clair en haut
	var cols := PackedColorArray()
	for p in avant:
		var k := clampf((p.y - y1) / maxf(h, 1.0), 0.0, 1.0)
		cols.append(Color("#d6f2fc").lerp(Color("#86c9e6"), k))
	draw_polygon(avant, cols)
	# la lueur du feu, à droite
	if feu > 0.05:
		var lueur := PackedColorArray()
		for p in avant:
			var k := clampf((p.x - x0) / maxf(w, 1.0), 0.0, 1.0)
			lueur.append(Color(1.0, 0.62, 0.25, 0.32 * feu * k * k))
		draw_polygon(avant, lueur)
	# reflets : deux traits en biais
	var cx := x0 + w * 0.3
	draw_line(Vector2(cx, y1 + h * 0.2), Vector2(cx - w * 0.12, y1 + h * 0.62), Color(1, 1, 1, 0.75), 3.0, true)
	draw_line(Vector2(cx + 7.0, y1 + h * 0.18), Vector2(cx + 2.0, y1 + h * 0.36), Color(1, 1, 1, 0.6), 2.0, true)
	# des bulles prises dans la glace
	for b in [[0.62, 0.55, 2.6], [0.72, 0.3, 1.8], [0.5, 0.78, 2.0], [0.82, 0.68, 1.5]]:
		var p := Vector2(x0 + w * b[0], y1 + h * b[1])
		if p.y > y1 + 4.0 and p.y < y0 - 3.0:
			draw_arc(p, b[2], 0.0, TAU, 10, Color(1, 1, 1, 0.7), 1.0, true)
	# une fissure
	if h > 20.0:
		draw_polyline(PackedVector2Array([Vector2(x0 + w * 0.7, y1 + 3.0), Vector2(x0 + w * 0.64, y1 + h * 0.3), Vector2(x0 + w * 0.73, y1 + h * 0.46), Vector2(x0 + w * 0.68, y1 + h * 0.6)]), Color(0.45, 0.72, 0.86, 0.9), 1.4, true)
	# la neige sur le dessus, tant qu'il reste du bloc et que le feu n'a pas pris
	var neige := clampf(1.0 - feu * 1.4, 0.0, 1.0) * clampf(reste * 2.0, 0.0, 1.0)
	if neige > 0.02:
		var c := Color(1, 1, 1, neige)
		for b in [[0.3, 6.0], [0.52, 8.0], [0.72, 5.5]]:
			draw_set_transform(Vector2(x0 + w * b[0], y1) + P * 0.5, 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, b[1], c)
			draw_set_transform(Vector2.ZERO)
	var ferme := avant.duplicate()
	ferme.append(avant[0])
	draw_polyline(ferme, CONTOUR, 2.2, true)
	# la face mouillée qui brille quand le feu la lèche
	if feu > 0.3:
		draw_line(Vector2(x1 - 3.0, y1 + r + 2.0), Vector2(x1 - 3.0, y0 - 4.0), Color(1, 1, 1, 0.45 * feu), 2.0, true)

func _rect_arrondi(x0: float, y0: float, x1: float, y1: float, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var coins := [[x1 - r, y0 + r, -PI * 0.5], [x1 - r, y1 - r * 0.3, 0.0], [x0 + r, y1 - r * 0.3, PI * 0.5], [x0 + r, y0 + r, PI]]
	for k in 4:
		var c: Array = coins[k]
		var rr := r if k == 0 or k == 3 else r * 0.3
		for s in 5:
			var a: float = c[2] + PI * 0.5 * s / 4.0
			p.append(Vector2(c[0], c[1]) + Vector2(cos(a), sin(a)) * rr)
	return p

# Le brasero : une corbeille de fer sur trois pieds, deux bûches ; allumé,
# des flammes qui dansent et une lueur. Éteint mais touchable, une braise
# rougeoie doucement entre les bûches : elle invite le doigt.
func _dessiner_brasero() -> void:
	# dessiné à 1,45 fois sa taille de modèle, autour de son pied : c'est lui
	# qu'on touche, il doit se voir
	draw_set_transform(Vector2(x_feu, base.y) * (1.0 - ECHELLE_FEU), 0.0, Vector2(ECHELLE_FEU, ECHELLE_FEU))
	_dessiner_brasero_modele()
	draw_set_transform(Vector2.ZERO)

const ECHELLE_FEU := 1.8
func _dessiner_brasero_modele() -> void:
	var b := Vector2(x_feu, base.y)
	var y_c := b.y - 22.0           # le bord de la corbeille
	# l'ombre
	draw_set_transform(b + Vector2(3, -1), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	# la lueur derrière les flammes
	if feu > 0.05:
		for k in 3:
			draw_circle(Vector2(b.x, y_c - 12.0), 30.0 - k * 8.0, Color(1.0, 0.6, 0.2, 0.08 * feu * (k + 1)))
	if _img_feu:
		var h := 40.0
		var w := h * _img_feu.get_width() / _img_feu.get_height()
		draw_texture_rect(_img_feu, Rect2(b.x - w * 0.5, b.y - h, w, h), false)
	else:
		# les trois pieds
		for dx in [-11.0, 0.0, 11.0]:
			draw_line(Vector2(b.x + dx * 0.6, y_c + 6.0), Vector2(b.x + dx, b.y - 1.0), BRUN, 4.0, true)
			draw_line(Vector2(b.x + dx * 0.6, y_c + 6.0), Vector2(b.x + dx, b.y - 1.0), Color("#4a4440"), 2.0, true)
		# les bûches, en croix, qui dépassent de la corbeille
		for s in [-1.0, 1.0]:
			var a := Vector2(b.x - 13.0 * s, y_c + 2.0)
			var c := Vector2(b.x + 9.0 * s, y_c - 9.0)
			draw_line(a, c, BRUN, 8.0, true)
			draw_line(a, c, Color("#8a5a33") if feu < 0.5 else Color("#5a3a22"), 5.5, true)
			draw_circle(c, 3.0, Color("#d9b48a") if feu < 0.5 else Color("#ff9a3c"))
		# la corbeille : un bol de fer à barreaux
		var bol := PackedVector2Array()
		for k in 9:
			var a := PI * k / 8.0
			bol.append(Vector2(b.x - cos(a) * 15.0, y_c + sin(a) * 9.0))
		draw_colored_polygon(bol, Color("#3c3532"))
		for k in 4:
			var x := b.x - 9.0 + k * 6.0
			draw_line(Vector2(x, y_c), Vector2(x, y_c + 7.5), Color("#6b625c"), 1.6)
		var bord := bol.duplicate()
		draw_polyline(bord, BRUN, 2.0, true)
		draw_line(Vector2(b.x - 16.0, y_c), Vector2(b.x + 16.0, y_c), BRUN, 3.0, true)
		draw_line(Vector2(b.x - 15.0, y_c - 0.5), Vector2(b.x + 15.0, y_c - 0.5), Color("#6b625c"), 1.4, true)
	# éteint et touchable : une braise qui respire
	if feu < 0.1 and actif:
		var a := 0.45 + 0.4 * sin(_t * 3.2)
		draw_circle(Vector2(b.x, y_c - 2.0), 5.0, Color(1.0, 0.45, 0.12, 0.35 * a))
		draw_circle(Vector2(b.x, y_c - 2.0), 2.4, Color(1.0, 0.7, 0.3, a))
	if feu > 0.05:
		_flammes(Vector2(b.x, y_c - 1.0), feu)

# Trois langues de feu superposées (rouge, orange, jaune) qui dansent : une
# goutte renversée, large au pied, pointue en haut, dont la pointe ondule.
func _flammes(pied: Vector2, f: float) -> void:
	var couches := [[Color("#e2421b"), 1.0, 0.0], [Color("#ff8a1f"), 0.74, 1.7], [Color("#ffd447"), 0.46, 3.1]]
	for c in couches:
		var k: float = c[1]
		var hauteur := (30.0 + 5.0 * sin(_t * 7.0 + c[2]) + 3.0 * sin(_t * 13.0 + c[2] * 2.0)) * k * f
		var largeur := 12.0 * k * (0.75 + 0.25 * f)
		var gauche := PackedVector2Array()
		var droite := PackedVector2Array()
		var n := 10
		for s in n + 1:
			var t := float(s) / n                 # 0 au pied, 1 à la pointe
			var demi := largeur * pow(1.0 - t, 0.75) * (0.75 + 0.25 * sin(t * PI))
			var ondule := sin(_t * 8.0 + c[2] - t * 3.0) * 4.0 * t * t
			var y := -t * hauteur
			gauche.append(pied + Vector2(-demi + ondule, y))
			if s < n: droite.append(pied + Vector2(demi + ondule, y))
		var pts := PackedVector2Array()
		pts.append(pied + Vector2(-largeur * 0.8, 3.0))
		pts.append_array(gauche)
		droite.reverse()
		pts.append_array(droite)
		pts.append(pied + Vector2(largeur * 0.8, 3.0))
		draw_colored_polygon(pts, c[0])
