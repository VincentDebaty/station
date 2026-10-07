class_name Orage
extends Node2D
# ------------------------------------------------------------------
# L'ORAGE (chapitre 7, nuit du 7 au 8 octobre 2026) : sur un niveau à
# « pluie », chaque coup fait monter tous les bassins (sauf le village, où
# elle s'infiltre). On le voit : la lumière baisse, de gros nuages gris
# passent en haut, une bruine tombe en permanence et redouble en averse
# pendant chaque coup ; les gouttes font des ronds sur l'eau. De temps en
# temps, un éclair au loin.
#
# La pluie tombe dans l'air, jamais dans la terre de la coupe : chaque
# goutte s'arrête sur l'eau d'un bassin, sur le pré, ou sur la berge.
# ------------------------------------------------------------------

var canal: Canal
var averse := 0.0          # 0 bruine, 1 averse (le canal la règle pendant un coup)
var _t := 0.0
var _gouttes := []         # [x, y, vitesse, longueur, profondeur 0 (la coupe) … 1 (le fond)]
var _ronds := []           # [position, âge]
var _eclair := -1.0        # le temps depuis le dernier éclair, -1 s'il n'y en a pas
var _prochain := 3.0
var _trace := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
var _sombre: CanvasModulate

func preparer(c: Canal) -> void:
	canal = c
	_rng.seed = 23
	z_index = 8
	# la lumière d'orage : tout le monde du jeu un peu plus sombre et plus bleu
	# (l'interface, dans sa propre couche, n'est pas touchée)
	_sombre = CanvasModulate.new()
	_sombre.color = Color(0.74, 0.78, 0.9)
	c.add_child(_sombre)

# Où s'arrête une goutte tombée en x : la surface de l'eau d'un bassin, son
# fond s'il est vide, sinon la berge.
func _sol(x: float) -> float:
	var r := canal.rect_monde()
	if x < 0.0 or x > r.size.x: return canal.Y(canal.berge)
	for i in canal.gb.size():
		if x >= canal.X(canal.gb[i][0]) and x <= canal.X(canal.gb[i][1]):
			return canal.Y(canal.vue_niv[i])
	return canal.Y(canal.berge)

func _process(dt: float) -> void:
	_t += dt
	var r := canal.rect_monde()
	var marge := 300.0
	# des gouttes neuves, d'autant plus que l'averse est forte
	var n := int((110.0 + 600.0 * averse) * dt * r.size.x / 1000.0 + _rng.randf())
	for k in n:
		var x := _rng.randf_range(-marge, r.size.x + marge)
		_gouttes.append([x, _rng.randf_range(-200.0, -20.0), _rng.randf_range(900.0, 1200.0), _rng.randf_range(14.0, 24.0), _rng.randf()])
	var restent := []
	for g in _gouttes:
		g[1] += g[2] * dt
		g[0] -= g[2] * dt * 0.12          # un peu de vent
		# la goutte tombe quelque part entre la coupe et le mur du fond : elle
		# s'arrête sur la surface (de l'eau ou du pré) vue en oblique
		var sol: float = _sol(g[0] - canal.D.x * g[4]) + canal.D.y * g[4]
		if g[1] >= sol:
			if _rng.randf() < 0.5: _ronds.append([Vector2(g[0], sol), 0.0])
			# une goutte dans un bassin ride sa surface
			if _rng.randf() < 0.12:
				var i := canal.bassin_sous(g[0])
				if i >= 0 and i < canal.eaux.size(): canal.eaux[i].impulsion(g[0], _rng.randf_range(0.1, 0.35), 10.0)
		else:
			restent.append(g)
	_gouttes = restent
	for o in _ronds: o[1] += dt
	_ronds = _ronds.filter(func(o): return o[1] < 0.35)
	# l'éclair : rarement, plus souvent pendant l'averse
	_prochain -= dt * (1.0 + 2.0 * averse)
	if _prochain <= 0.0:
		_prochain = _rng.randf_range(5.0, 9.0)
		_eclair = 0.0
		_trace = _zigzag(Vector2(_rng.randf_range(r.size.x * 0.15, r.size.x * 0.85), -40.0), _rng.randf_range(160.0, 260.0))
	if _eclair >= 0.0:
		_eclair += dt
		if _eclair > 0.5: _eclair = -1.0
	var lum := 0.0
	if _eclair >= 0.0: lum = clampf(1.0 - _eclair / 0.18, 0.0, 1.0) + (0.6 if _eclair > 0.22 and _eclair < 0.28 else 0.0)
	_sombre.color = Color(0.74, 0.78, 0.9).lerp(Color(1, 1, 1), clampf(lum, 0.0, 1.0) * 0.6).darkened(0.06 * averse)
	queue_redraw()

func _zigzag(depart: Vector2, longueur: float) -> PackedVector2Array:
	var p := PackedVector2Array([depart])
	var c := depart
	while c.y - depart.y < longueur:
		c += Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(16.0, 30.0))
		p.append(c)
	return p

func _draw() -> void:
	var r := canal.rect_monde()
	# les nuages, tout en haut, dans le ciel au-dessus de la coupe (les roues
	# des portes montent jusqu'à y = 0 environ) : des boules opaques qui se
	# fondent en une seule masse — semi-transparentes, leurs recouvrements
	# faisaient des taches — un dessous sombre, un dessus éclairé
	var ombre := Color(0.42, 0.47, 0.56)
	var corps := Color(0.58, 0.62, 0.70)
	var clair := Color(0.74, 0.77, 0.83)
	var boules := [[0.0, 0.0, 70.0], [62.0, 12.0, 54.0], [-58.0, 14.0, 50.0], [22.0, -26.0, 50.0], [-24.0, -18.0, 44.0], [112.0, 24.0, 40.0], [-104.0, 26.0, 36.0]]
	for k in 8:
		var x := fmod(k * 300.0 + _t * 8.0, r.size.x + 900.0) - 450.0
		var y := -175.0 + 22.0 * sin(k * 1.7)
		var t := 1.0 + 0.2 * sin(k * 2.3)
		for b in boules: draw_circle(Vector2(x + b[0] * t + 3.0, y + b[1] * t + 9.0), b[2] * t, ombre)
		for b in boules: draw_circle(Vector2(x + b[0] * t, y + b[1] * t), b[2] * t * 0.94, corps)
		for b in boules: draw_circle(Vector2(x + b[0] * t - 9.0, y + b[1] * t - 11.0), b[2] * t * 0.62, clair)
	# l'éclair
	if _eclair >= 0.0 and _eclair < 0.3:
		var a := 1.0 - _eclair / 0.3
		draw_polyline(_trace, Color(0.85, 0.9, 1.0, 0.45 * a), 7.0, true)
		draw_polyline(_trace, Color(1, 1, 1, a), 2.5, true)
	# la pluie : des traits fins, inclinés par le vent
	var c := Color(0.88, 0.94, 1.0, 0.7)
	for g in _gouttes:
		var bas := Vector2(g[0], g[1])
		draw_line(bas, bas + Vector2(g[3] * 0.12, -g[3]), c, 1.8, true)
	# les ronds des gouttes sur l'eau
	for o in _ronds:
		var k: float = o[1] / 0.35
		draw_set_transform(o[0], 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, 2.0 + 7.0 * k, 0.0, TAU, 12, Color(1, 1, 1, 0.55 * (1.0 - k)), 1.2, true)
		draw_set_transform(Vector2.ZERO)
