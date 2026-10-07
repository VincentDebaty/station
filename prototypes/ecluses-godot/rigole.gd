class_name Rigole
extends Node2D
# ------------------------------------------------------------------
# LA RIGOLE (chapitre 3, 7 octobre 2026, d'après l'image cible validée par
# Vincent) : entre le bord du canal et la mare, une butte d'herbe. Son tracé
# est marqué en pointillés, une pelle y est plantée : on devine qu'on peut
# creuser. Chaque coup de pelle (le moteur : « creuser », la crête de la digue
# baisse d'une unité) approfondit la rigole le long du tracé, de la mare au
# bord du canal ; l'eau de la mare la descend et tombe en cascade dans le
# bassin. On ne rebouche pas.
#
# La rigole court SUR la butte, à mi-profondeur : la face de terre dans la
# coupe reste entière. On voit son flanc du fond et son lit ; le pré devant
# elle cache son flanc avant.
# ------------------------------------------------------------------

var canal: Canal
var i := 0
var vue := 0.0           # le lit de la rigole affiché (unités), qui descend vers « cible »
var cible := 0.0
var crete0 := 0.0         # la crête de départ : le tracé, pas encore creusé
var y_rive := 0.0         # le dessus de la butte (y monde, plan de la coupe)
var y_bas := 0.0
var x_bord := 0.0         # le bord du canal, où l'eau tombe
var x_mare := 0.0         # l'entrée de la rigole, côté mare
const Z := 1.15           # la rigole arrive au milieu de la mare, loin dans la profondeur
const LARGE := 0.5        # sa largeur, en part de la profondeur
var _mottes := []
var _pelle: Texture2D
var _coup := 0.0          # la pelle plonge (1 → 0)
var _t := 0.0

func preparer(c: Canal, ai: int, crete: float, rive: float, mare_x: float) -> void:
	canal = c; i = ai
	vue = crete; cible = crete; crete0 = crete
	y_rive = c.Y(rive)
	var B: Array = c.N["bassins"]
	y_bas = c.Y(minf(float(B[ai]["fond"]), float(B[ai + 1]["fond"])))
	x_bord = c.X(c.gl[ai][0])
	x_mare = mare_x
	if ResourceLoader.exists("res://art/pelle.png"): _pelle = Images.reduire("res://art/pelle.png", 140)
	z_index = 1
	# La face de terre de la butte, dans la coupe, redessinée PAR-DESSUS la
	# rigole : vue un peu d'en haut, une rigole creusée près de la coupe
	# descend plus bas que le bord avant de la butte, et son eau dépassait
	# sous le pré comme une bande bleue flottante (Vincent). La terre la cache.
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/terre.gdshader")
	m.set_shader_parameter("sol_y", c.Y(0.0))
	Peint.habiller(m, "terre")
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(x_bord, y_rive), Vector2(x_mare + 60.0, y_rive), Vector2(x_mare + 60.0, y_bas), Vector2(x_bord, y_bas)])
	face.material = m
	add_child(face)
	var bord := Line2D.new()
	bord.points = PackedVector2Array([Vector2(x_bord, y_rive + 1.0), Vector2(x_mare + 60.0, y_rive + 1.0)])
	bord.width = 4.0
	bord.default_color = Color("#6a9c3c")
	add_child(bord)

func regler(crete: float) -> void:
	if crete < cible - 0.01:
		_coup = 1.0
		for k in 10:
			var a := randf_range(-PI * 0.9, -PI * 0.1)
			var x := randf_range(x_bord + 10.0, x_mare - 10.0)
			_mottes.append([_pt(randf(), 0.0, y_rive), Vector2(cos(a), sin(a)) * randf_range(70, 160), 0.0])
	cible = crete

func arrive() -> bool:
	return absf(vue - cible) < 0.01 and _coup <= 0.0

# Le doigt sur la butte ou sur la pelle ?
func sous(p: Vector2) -> bool:
	var D := canal.D
	return p.x > x_bord + minf(D.x, 0.0) - 20.0 and p.x < x_mare + 30.0 and p.y > y_rive + D.y * 1.6 - 60.0 and p.y < y_rive + 30.0

func _process(dt: float) -> void:
	_t += dt
	_coup = maxf(_coup - dt * 2.2, 0.0)
	if not is_equal_approx(vue, cible) and _coup < 0.5:
		vue = move_toward(vue, cible, dt * 2.0)
	for m in _mottes:
		m[2] += dt
		m[1] += Vector2(0, 520) * dt
		m[0] += m[1] * dt
	_mottes = _mottes.filter(func(m): return m[2] < 0.9)
	queue_redraw()

# Les points de la rigole, vue d'en haut : son axe va en diagonale de la rive
# de la mare (loin dans la profondeur) au bord du canal (à mi-profondeur du
# bassin, où l'eau tombe), comme sur l'image cible. Sa profondeur est dessinée
# réduite (ECHELLE) : 3 unités de crête creusées feraient une tranchée de
# 144 px ; la mare, elle aussi, montre sa baisse en rétrécissant.
const Z_BORD := 0.5
const ECHELLE := 0.32
func _pt(x_frac: float, cote: float, y: float) -> Vector2:
	var D := canal.D
	var z := lerpf(Z_BORD, Z, x_frac) + cote * LARGE * 0.5
	return Vector2(lerpf(x_bord, x_mare, x_frac), y) + D * z

func _draw() -> void:
	var D := canal.D
	var prof := maxf(canal.Y(vue) - y_rive, 0.0) * ECHELLE
	var yb := y_rive + prof
	var herbe_c := Color("#8fc456")
	var herbe_f := Color("#6a9c3c")
	# la butte, vue d'en haut, du bord du canal à la mare
	var butte := PackedVector2Array([Vector2(x_bord, y_rive), Vector2(x_mare + 20.0, y_rive), Vector2(x_mare + 20.0, y_rive) + D * (Z + 0.45), Vector2(x_bord, y_rive) + D * (Z + 0.45)])
	draw_polygon(butte, PackedColorArray([herbe_c, herbe_c, herbe_f, herbe_f]))
	if prof > 0.5:
		# le flanc du fond (terre fraîche) et le lit
		draw_colored_polygon(PackedVector2Array([_pt(0, 1, y_rive), _pt(1, 1, y_rive), _pt(1, 1, yb), _pt(0, 1, yb)]), Color("#7a4c26"))
		draw_colored_polygon(PackedVector2Array([_pt(0, -1, yb), _pt(1, -1, yb), _pt(1, 1, yb), _pt(0, 1, yb)]), Color("#5e3a1c"))
		# l'eau de la mare qui la descend
		var niv_mare: float = canal.vue_niv[i + 1]
		var mare: Mare = canal.mares.get(i + 1)
		if niv_mare > vue + 0.02 and (mare == null or mare.plein() > 0.005):
			var h := minf((niv_mare - vue) * canal.UY * ECHELLE, prof)
			var e := PackedVector2Array([_pt(0, -1, yb - h), _pt(1, -1, yb - h), _pt(1, 1, yb - h), _pt(0, 1, yb - h)])
			draw_colored_polygon(e, Color(0.36, 0.7, 0.88, 0.92))
			# l'eau qui relie la mare à la rigole, jusqu'au bord de son eau
			# (sans elle, une cassure séparait l'étang de la cascade)
			if mare:
				var bd := mare.bord_eau(0.18)
				var lien := PackedVector2Array([_pt(1, -1, yb - h), bd[1], bd[0], _pt(1, 1, yb - h)])
				draw_colored_polygon(lien, Color(0.36, 0.7, 0.88, 0.92))
			for k in 5:
				var f := fmod(_t * 0.9 + k / 5.0, 1.0)
				var q := _pt(1.0 - f, 0.0, yb - h)
				var q2 := _pt(maxf(1.0 - f - 0.06, 0.0), 0.0, yb - h)
				draw_line(q, q2, Color(0.92, 1, 1, 0.65), 1.6, true)
	# le pré devant la rigole, qui cache son flanc avant
	var devant := PackedVector2Array([Vector2(x_bord, y_rive), Vector2(x_mare + 20.0, y_rive), _pt(1, -1, y_rive) + Vector2(20.0, 0), _pt(1, -1, y_rive), _pt(0, -1, y_rive)])
	draw_colored_polygon(devant, herbe_c)
	if prof > 0.5:
		draw_line(_pt(0, -1, y_rive), _pt(1, -1, y_rive), Color("#4a2c12"), 2.0, true)
		draw_line(_pt(0, 1, y_rive), _pt(1, 1, y_rive), Color("#4a2c12"), 1.5, true)
	# le tracé en pointillés, tant qu'on peut creuser
	if vue > float(canal.N["liaisons"][i]["min"]) + 0.01:
		for c in [-1.0, 1.0]:
			draw_dashed_line(_pt(0, c, y_rive), _pt(1, c, y_rive), Color(1, 0.98, 0.9, 0.9), 2.5, 8.0)
		draw_dashed_line(_pt(1, -1, y_rive), _pt(1, 1, y_rive), Color(1, 0.98, 0.9, 0.9), 2.5, 8.0)
	# la pelle, plantée au bord du tracé ; elle plonge à chaque coup, et
	# se balance doucement tant qu'on n'a pas creusé, pour inviter le doigt
	if _pelle:
		var h2 := 150.0
		var w := h2 * _pelle.get_width() / _pelle.get_height()
		var p := _pt(0.55, -1.3, y_rive) + Vector2(0, 8.0 + 14.0 * sin(_coup * PI))
		var inv := 0.0 if _coup > 0.0 else 0.06 * sin(_t * 2.2) * (1.0 if vue >= crete0 - 0.01 else 0.3)
		draw_set_transform(p, -0.15 + inv)
		draw_texture_rect(_pelle, Rect2(-w * 0.5, -h2, w, h2), false)
		draw_set_transform(Vector2.ZERO)
	for m in _mottes:
		draw_circle(m[0], 3.2 * (1.0 - m[2]), Color(0.4, 0.25, 0.12, 1.0 - m[2]))

# Le bas de la rigole, au bord du canal : d'où tombe la cascade.
func bouche(vue_crete: float) -> Vector2:
	var prof := maxf(canal.Y(vue_crete) - y_rive, 0.0) * ECHELLE
	return Vector2(x_bord, y_rive + prof)
