class_name Mare
extends Node2D
# ------------------------------------------------------------------
# LA MARE (chapitre 3, 7 octobre 2026, d'après l'image cible validée par
# Vincent) : l'étang n'est plus un bassin de pierre dans la coupe, c'est une
# cuvette naturelle sur le pré, vue d'en haut et un peu de la gauche. Pour le
# moteur, c'est toujours le bassin « reservoir » de la rangée ; seul son dessin
# change. Quand on creuse la rigole, son eau baisse : elle rétrécit dans sa
# cuvette et découvre une rive de boue. Des roseaux sur ses bords, des
# nénuphars sur l'eau.
# ------------------------------------------------------------------

var canal: Canal
var i := 0
var y_rive := 0.0        # le pré, au bord de la mare (y monde, plan de la coupe)
var cx := 0.0
var rx := 0.0
var fond := 0.0          # en unités
var rive := 0.0
var _roseau: Texture2D
var _nenuphar: Texture2D
var _buisson: Texture2D
var _t := 0.0

func preparer(c: Canal, ai: int, arive: float) -> void:
	canal = c; i = ai
	var b: Dictionary = c.N["bassins"][ai]
	fond = float(b["fond"]); rive = arive
	y_rive = c.Y(rive)
	# un peu en retrait du canal, pour que la rigole ait de la longueur
	cx = c.X(c.gb[ai][0] + c.gb[ai][1]) * 0.5 + 0.6 * c.U
	rx = c.X(c.gb[ai][1] - c.gb[ai][0]) * 0.36
	if ResourceLoader.exists("res://art/roseaux.png"): _roseau = Images.reduire("res://art/roseaux.png", 160)
	if ResourceLoader.exists("res://art/nenuphar.png"): _nenuphar = Images.reduire("res://art/nenuphar.png", 120)
	if ResourceLoader.exists("res://art/buisson.png"): _buisson = Images.reduire("res://art/buisson.png", 200)

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

# Un point de l'ovale de la mare : t l'angle, s l'échelle, centre décalé de dy.
func _ovale(t: float, s: float, dy := 0.0) -> Vector2:
	var D := canal.D
	var c := Vector2(cx, y_rive + dy) + D * 1.15
	# l'ovale s'étend loin dans la profondeur : vue d'en haut, la mare a de
	# l'ampleur (à 0,46 de D, elle n'était qu'un trait)
	return c + Vector2(cos(t) * rx * s, 0) + D * (sin(t) * 1.1 * s)

func _contour(s: float, dy := 0.0, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var t := TAU * k / n
		var bosse := 1.0 + 0.05 * sin(t * 3.0 + 1.3) + 0.03 * sin(t * 5.0)
		pts.append(_ovale(t, s * bosse, dy))
	return pts

# 0 à sec, 1 pleine jusqu'au pré
func plein() -> float:
	return clampf((canal.vue_niv[i] - fond) / maxf(rive - fond, 0.01), 0.0, 1.0)

# Le bord gauche de l'eau, côté rigole : deux points, à la hauteur de l'eau.
func bord_eau(ecart: float) -> PackedVector2Array:
	var s := 0.92 * sqrt(plein())
	return PackedVector2Array([_ovale(PI - ecart, s), _ovale(PI + ecart, s)])

func _draw() -> void:
	var f := plein()
	# la rive d'herbe, puis la cuvette de boue
	draw_colored_polygon(_contour(1.08), Color("#7fb04a"))
	draw_colored_polygon(_contour(1.0), Color("#6b4e2c"))
	draw_colored_polygon(_contour(0.92, 3.0), Color("#5a3f22"))
	# des buissons fleuris sur la rive du fond, puis les roseaux
	if _buisson:
		for b in [[1.5, 30.0], [2.55, 26.0], [5.9, 22.0]]:
			var p := _ovale(b[0], 1.12)
			var h: float = b[1]
			var w := h * _buisson.get_width() / _buisson.get_height()
			draw_texture_rect(_buisson, Rect2(p.x - w * 0.5, p.y - h * 0.85, w, h), false)
	_roseaux([2.3, 2.75, 1.85], 1.0)
	# l'eau : elle baisse un peu et rétrécit dans sa cuvette
	if f > 0.005:
		# elle rétrécit jusqu'à rien, sans palier (Vincent : diminuer jusqu'au
		# bout, au plus fin possible)
		var s := 0.92 * sqrt(f)
		# elle rétrécit sans descendre : décalée vers le bas, elle sortait de
		# sa cuvette et passait devant la terre de la coupe (Vincent)
		var dy := 0.0
		var eau := _contour(s, dy)
		var couleurs := PackedColorArray()
		for k in eau.size():
			var t := TAU * k / eau.size()
			couleurs.append(Color(0.2, 0.55, 0.72).lerp(Color(0.5, 0.82, 0.93), clampf(-sin(t) * 0.5 + 0.5, 0.0, 1.0)))
		draw_polygon(eau, couleurs)
		# un liseré clair au bord de l'eau, et des rides
		draw_polyline(eau + PackedVector2Array([eau[0]]), Color(0.9, 1, 1, 0.5), 1.6, true)
		for k in 3:
			var ph := fmod(_t * 0.3 + k / 3.0, 1.0)
			var rr := _contour(s * (0.3 + 0.5 * ph), dy, 24)
			draw_polyline(rr + PackedVector2Array([rr[0]]), Color(1, 1, 1, 0.18 * (1.0 - ph)), 1.0, true)
		# les nénuphars, qui suivent l'eau
		if _nenuphar:
			for n in [[0.4, 0.5, 46.0], [2.0, 0.6, 38.0], [3.6, 0.35, 32.0]]:
				var p := _ovale(n[0], s * n[1], dy)
				var w: float = n[2] * (0.6 + 0.4 * f)
				var h := w * _nenuphar.get_height() / _nenuphar.get_width() * 0.7
				draw_texture_rect(_nenuphar, Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h), false)
	# les roseaux de devant, sur la rive droite et avant
	_roseaux([0.35, 5.6, 0.9], 1.15)

func _roseaux(angles: Array, taille: float) -> void:
	if _roseau == null: return
	for a in angles:
		var p := _ovale(a, 1.02)
		var h := 92.0 * taille
		var w := h * _roseau.get_width() / _roseau.get_height()
		var vent := 0.03 * sin(_t * 1.3 + a)
		draw_set_transform(p, vent)
		draw_texture_rect(_roseau, Rect2(-w * 0.5, -h, w, h), false)
		draw_set_transform(Vector2.ZERO)
