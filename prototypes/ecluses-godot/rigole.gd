class_name Rigole
extends Node2D
# ------------------------------------------------------------------
# LA RIGOLE (chapitre 3, 7 octobre 2026) : une digue de terre herbeuse entre
# deux bassins, où l'on creuse au doigt. Chaque coup de pelle approfondit
# l'entaille d'une unité (le moteur : « creuser », la crête baisse jusqu'à
# « min ») ; l'eau du côté haut file par l'entaille. On ne rebouche pas.
# Vincent préférait « creuser un petit canal pour déverser l'eau » aux planches
# d'une hausse, trop proches d'une porte.
#
# Vue de la gauche comme le reste : la berge a sa face de terre dans la coupe,
# son dessus en herbe vers le fond, et l'entaille la traverse au milieu de la
# berge (là où file l'eau), visible sur la face et sur le dessus.
# ------------------------------------------------------------------

var canal: Canal
var i := 0
var vue := 0.0           # le fond de l'entaille affiché, qui descend vers « cible »
var cible := 0.0
var y_max := 0.0          # le haut de la berge (crête de départ)
var y_bas := 0.0
var x0 := 0.0
var x1 := 0.0
var xc := 0.0
var _mottes := []         # [position, vitesse, âge] des mottes de terre qui volent
var _terre: ShaderMaterial

func preparer(c: Canal, ai: int, crete: float) -> void:
	canal = c; i = ai
	var B: Array = c.N["bassins"]
	vue = crete; cible = crete
	y_max = c.Y(crete)
	y_bas = c.Y(minf(float(B[ai]["fond"]), float(B[ai + 1]["fond"])))
	x0 = c.X(c.gl[ai][0]); x1 = c.X(c.gl[ai][1])
	xc = (x0 + x1) * 0.5
	_terre = ShaderMaterial.new()
	_terre.shader = preload("res://shaders/terre.gdshader")
	_terre.set_shader_parameter("sol_y", c.Y(0.0))
	Peint.habiller(_terre, "terre")
	z_index = 1

func regler(crete: float) -> void:
	if crete < cible - 0.01:
		# un coup de pelle : des mottes volent de l'entaille
		for k in 9:
			var a := randf_range(-PI * 0.85, -PI * 0.15)
			_mottes.append([Vector2(xc + randf_range(-6, 6), canal.Y(cible)) + canal.D * 0.5, Vector2(cos(a), sin(a)) * randf_range(80, 170), 0.0])
	cible = crete

func arrive() -> bool:
	return absf(vue - cible) < 0.01

# Le doigt sur la berge ?
func sous(p: Vector2) -> bool:
	var D := canal.D
	return p.x > x0 + minf(D.x, 0.0) - 10.0 and p.x < x1 + 10.0 and p.y > y_max + minf(D.y, 0.0) - 0.6 * canal.UY and p.y < y_bas

func _process(dt: float) -> void:
	if not is_equal_approx(vue, cible):
		vue = move_toward(vue, cible, dt * 2.2)
	for m in _mottes:
		m[2] += dt
		m[1] += Vector2(0, 520) * dt
		m[0] += m[1] * dt
	_mottes = _mottes.filter(func(m): return m[2] < 0.9)
	queue_redraw()

# La largeur de l'entaille à la hauteur y : un V évasé, de 0,35 unité au fond.
func _entaille(prof: float) -> float:
	return 0.35 * canal.U + prof * 0.55

func _draw() -> void:
	var D := canal.D
	var yv := canal.Y(vue)
	var prof := maxf(yv - y_max, 0.0)
	# l'entaille ne dépasse jamais la berge : en V tant qu'elle est peu
	# profonde, puis en fente droite
	var largeur_max := (x1 - x0) * 0.5 - 0.1 * canal.U - 3.0
	var dem := minf(_entaille(prof) * 0.5, largeur_max)
	var bas_dem := minf(0.35 * canal.U * 0.5, dem - 1.0)
	var g := x0 - 0.15 * canal.U
	var d := x1 + 0.15 * canal.U
	# la face de terre, dans la coupe, avec l'entaille en V
	var face := PackedVector2Array([Vector2(g, y_bas), Vector2(x0 + 0.05 * canal.U, y_max)])
	if prof > 0.5:
		face.append_array([Vector2(xc - dem, y_max), Vector2(xc - bas_dem, yv), Vector2(xc + bas_dem, yv), Vector2(xc + dem, y_max)])
	face.append_array([Vector2(x1 - 0.05 * canal.U, y_max), Vector2(d, y_bas)])
	draw_colored_polygon(face, Color("#8a5a32"))
	# le dessus en herbe, de la face vers le fond, de part et d'autre de l'entaille
	var herbe_c := Color("#8fc456")
	var herbe_f := Color("#6a9c3c")
	var gauche := PackedVector2Array([Vector2(x0 + 0.05 * canal.U, y_max), Vector2(xc - dem, y_max), Vector2(xc - dem, y_max) + D, Vector2(x0 + 0.05 * canal.U, y_max) + D])
	var droite := PackedVector2Array([Vector2(xc + dem, y_max), Vector2(x1 - 0.05 * canal.U, y_max), Vector2(x1 - 0.05 * canal.U, y_max) + D, Vector2(xc + dem, y_max) + D])
	if prof <= 0.5:
		gauche = PackedVector2Array([Vector2(x0 + 0.05 * canal.U, y_max), Vector2(x1 - 0.05 * canal.U, y_max), Vector2(x1 - 0.05 * canal.U, y_max) + D, Vector2(x0 + 0.05 * canal.U, y_max) + D])
	draw_polygon(gauche, PackedColorArray([herbe_c, herbe_c, herbe_f, herbe_f]))
	if prof > 0.5:
		draw_polygon(droite, PackedColorArray([herbe_c, herbe_c, herbe_f, herbe_f]))
		# l'intérieur de l'entaille : son flanc gauche (terre fraîche, plus
		# sombre) qui file vers le fond, et son lit
		draw_colored_polygon(PackedVector2Array([Vector2(xc - dem, y_max), Vector2(xc - bas_dem, yv), Vector2(xc - bas_dem, yv) + D, Vector2(xc - dem, y_max) + D]), Color("#7a4c26"))
		draw_colored_polygon(PackedVector2Array([Vector2(xc - bas_dem, yv), Vector2(xc + bas_dem, yv), Vector2(xc + bas_dem, yv) + D, Vector2(xc - bas_dem, yv) + D]), Color("#6f4826"))
		# les bords de l'entaille, en terre fraîche
		draw_polyline(PackedVector2Array([Vector2(xc - dem, y_max), Vector2(xc - bas_dem, yv), Vector2(xc + bas_dem, yv), Vector2(xc + dem, y_max)]), Color("#3e2410"), 2.0, true)
	# le liseré d'herbe sur l'arête de la face, et quelques touffes
	var fin_g := xc - dem if prof > 0.5 else x1 - 0.05 * canal.U
	draw_line(Vector2(x0 + 0.05 * canal.U, y_max), Vector2(fin_g, y_max), Color("#5f8f37"), 3.0)
	if prof > 0.5: draw_line(Vector2(xc + dem, y_max), Vector2(x1 - 0.05 * canal.U, y_max), Color("#5f8f37"), 3.0)
	# des grains dans la terre de la face
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 * (i + 1)
	for k in 22:
		var p := Vector2(rng.randf_range(g + 6.0, d - 6.0), rng.randf_range(y_max + 6.0, y_bas - 4.0))
		if prof > 0.5 and absf(p.x - xc) < dem + 2.0 and p.y < yv + 3.0: continue
		draw_circle(p, rng.randf_range(1.2, 2.6), Color(0.3, 0.18, 0.08, 0.5))
	# les mottes qui volent
	for m in _mottes:
		draw_circle(m[0], 3.2 * (1.0 - m[2]), Color(0.4, 0.25, 0.12, 1.0 - m[2]))
