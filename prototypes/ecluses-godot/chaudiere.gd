class_name Chaudiere
extends Node2D
# ------------------------------------------------------------------
# LA CHAUDIÈRE (chapitre 5, nuit du 7 au 8 octobre 2026) : une petite
# chaudière à vapeur sur la berge du fond, au-dessus du bassin qu'elle boit.
# Chaque toucher (le moteur : « chauffer ») attise le feu : la porte du foyer
# rougeoie, le manomètre s'affole, l'eau monte dans le tuyau, et la vapeur
# s'échappe en grosses bouffées par le sifflet. Le bassin baisse d'autant.
# Au repos, un filet de fumée sort de la cheminée et le feu couve : elle
# invite le doigt.
#
# Dessinée ici, en attendant art/chaudiere.png (prompt dans ASSETS.md) : si
# l'image existe, elle remplace le corps ; la vapeur, le feu et le manomètre
# restent dessinés.
# Repère : « base » est le milieu du pied, posé sur la berge du fond.
# ------------------------------------------------------------------

signal coup_fini

var base := Vector2.ZERO
var actif := true
var force := 0.0           # 0 à 1 pendant un coup : le canal la règle pendant l'écoulement
var _t := 0.0
var _coup := -1.0          # le temps depuis le toucher, -1 au repos
var _bouffees := []        # [position, vitesse, rayon, âge, durée, blanc (1 vapeur, 0 fumée)]
var _aiguille := -2.2      # l'aiguille du manomètre, en radians
var _image: Texture2D
var _rng := RandomNumberGenerator.new()

const BRUN := Color("#3b2414")
const L := 60.0            # largeur du ballon
const H_BASE := 30.0       # le foyer de briques
const H_BALLON := 58.0

func preparer(abase: Vector2) -> void:
	base = abase
	_rng.seed = 7
	if ResourceLoader.exists("res://art/chaudiere.png"):
		_image = Images.reduire("res://art/chaudiere.png", 260)

# Le bout du tuyau, au pied gauche du foyer : le canal y fait arriver l'eau.
func entree_tuyau() -> Vector2:
	return base + Vector2(-L * 0.5 - 6.0, -10.0)

func sous(p: Vector2) -> bool:
	return Rect2(base.x - L - 10.0, base.y - 175.0, 2.0 * L + 20.0, 190.0).has_point(p)

func chauffer() -> void:
	_coup = 0.0
	force = 0.7

func _sifflet() -> Vector2:
	return base + Vector2(-L * 0.22, -H_BASE - H_BALLON - 24.0)

func _cheminee() -> Vector2:
	return base + Vector2(L * 0.2, -H_BASE - H_BALLON - 52.0)

func _process(dt: float) -> void:
	_t += dt
	if _coup >= 0.0:
		_coup += dt
		if _coup > 0.5 and _coup - dt <= 0.5: coup_fini.emit()
		if _coup > 4.0: _coup = -1.0
	# l'aiguille monte avec le feu, retombe au repos
	var cible := -2.2 + 2.6 * maxf(force, 0.0) + 0.06 * sin(_t * 3.0)
	_aiguille = lerpf(_aiguille, cible, minf(1.0, dt * 4.0))
	# la fumée de la cheminée : un filet au repos, plus dense quand on chauffe
	var fume := 1.6 + 8.0 * force
	if _rng.randf() < dt * fume:
		_bouffees.append([_cheminee() + Vector2(_rng.randf_range(-2, 2), 0), Vector2(_rng.randf_range(-12, -5), _rng.randf_range(-32, -24)), _rng.randf_range(4.5, 6.0), 0.0, _rng.randf_range(2.4, 3.2), 0.0])
	# la vapeur du sifflet : de grosses bouffées blanches quand on chauffe
	if force > 0.05 and _rng.randf() < dt * 26.0 * force:
		_bouffees.append([_sifflet() + Vector2(0, -6), Vector2(_rng.randf_range(-34, -8), _rng.randf_range(-95, -60)), _rng.randf_range(5.0, 8.0), 0.0, _rng.randf_range(1.4, 2.0), 1.0])
	for b in _bouffees:
		b[3] += dt
		b[0] += b[1] * dt
		b[1] *= 1.0 - 1.1 * dt
		b[2] += dt * (16.0 if b[5] > 0.5 else 6.0)
	_bouffees = _bouffees.filter(func(b): return b[3] < b[4])
	modulate = modulate.lerp(Color(1, 1, 1) if actif else Color(0.78, 0.75, 0.74), minf(1.0, dt * 6.0))
	queue_redraw()

func _draw() -> void:
	# une petite secousse pendant que la vapeur part
	var o := Vector2(sin(_t * 47.0), cos(_t * 39.0)) * 1.2 * force
	var c := base + o
	# l'ombre au pied, sur l'herbe de la berge
	draw_set_transform(base + Vector2(6, -1), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, L * 0.85, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	_dessiner_fumees(false)
	if _image:
		var h := H_BASE + H_BALLON + 60.0
		var w := h * _image.get_width() / _image.get_height()
		draw_texture_rect(_image, Rect2(c.x - w * 0.5, c.y - h, w, h), false)
		_dessiner_feu(c)
	else:
		_dessiner_corps(c)
	_dessiner_fumees(true)

# Le corps peint à la main : un foyer de briques, un ballon de cuivre cerclé de
# laiton, un dôme de fonte, une cheminée, un sifflet et un manomètre.
func _dessiner_corps(c: Vector2) -> void:
	var y_b := c.y - H_BASE          # le haut du foyer
	var y_h := y_b - H_BALLON        # le haut du ballon
	# la cheminée, derrière le dôme
	var ch := c + Vector2(L * 0.2, 0)
	_rect_degrade(Rect2(ch.x - 6, y_h - 46, 12, 50), Color("#5a4c46"), Color("#2a211d"))
	_contour(PackedVector2Array([Vector2(ch.x - 6, y_h + 4), Vector2(ch.x - 6, y_h - 46), Vector2(ch.x + 6, y_h - 46), Vector2(ch.x + 6, y_h + 4)]), false)
	var chapeau := PackedVector2Array([Vector2(ch.x - 10, y_h - 46), Vector2(ch.x - 8, y_h - 54), Vector2(ch.x + 8, y_h - 54), Vector2(ch.x + 10, y_h - 46)])
	draw_colored_polygon(chapeau, Color("#3a302c"))
	_contour(chapeau, true)
	# le foyer de briques
	var foyer := Rect2(c.x - L * 0.62, y_b, L * 1.24, H_BASE)
	_rect_degrade(foyer, Color("#b65a38"), Color("#7e3520"))
	for rang in 4:
		var y := y_b + 7.5 * rang
		draw_line(Vector2(foyer.position.x, y), Vector2(foyer.end.x, y), Color("#5e2414", 0.55), 1.2)
		var dec := 7.0 if rang % 2 == 0 else 0.0
		var x := foyer.position.x + dec
		while x < foyer.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 7.5, foyer.end.y)), Color("#5e2414", 0.5), 1.0)
			x += 14.0
	_contour(_coins(foyer), true)
	# la dalle de pierre sur le foyer
	var dalle := Rect2(c.x - L * 0.68, y_b - 5, L * 1.36, 6)
	_rect_degrade(dalle, Color("#e2d3b2"), Color("#b3a07c"))
	_contour(_coins(dalle), true)
	_dessiner_feu(c)
	# le ballon de cuivre
	var ballon := Rect2(c.x - L * 0.5, y_h, L, H_BALLON - 5)
	_cylindre(ballon, Color("#f0a46a"), Color("#c76a35"), Color("#7c3519"))
	# le dôme de fonte
	var dome := PackedVector2Array()
	for k in 17:
		var a := PI + PI * k / 16.0
		dome.append(Vector2(c.x + cos(a) * L * 0.5, y_h + sin(a) * 15.0))
	var cd := PackedColorArray()
	for p in dome: cd.append(Color("#6e5d55").lerp(Color("#2e2522"), clampf((p.x - c.x) / L + 0.5, 0.0, 1.0)))
	draw_polygon(dome, cd)
	_contour(dome, false)
	# les cerclages de laiton et leurs rivets
	for yy in [y_h + 9.0, y_h + H_BALLON - 14.0]:
		_cylindre(Rect2(c.x - L * 0.5 - 1.5, yy - 3.5, L + 3.0, 7.0), Color("#ffe08a"), Color("#d6a23a"), Color("#8a5f17"))
		for k in 7:
			var x: float = c.x - L * 0.42 + k * L * 0.14
			draw_circle(Vector2(x, yy), 1.5, Color("#6b4610"))
	_contour(_coins(ballon), true)
	# le sifflet de laiton, sur le dôme
	var s := _sifflet()
	_rect_degrade(Rect2(s.x - 3.5, s.y - 2, 7, 14), Color("#ffe08a"), Color("#a8741f"))
	_contour(_coins(Rect2(s.x - 3.5, s.y - 2, 7, 14)), true)
	draw_circle(s + Vector2(0, -3), 4.0, BRUN)
	draw_circle(s + Vector2(0, -3), 2.6, Color("#ffd166"))
	# le manomètre : un cadran blanc cerclé de laiton, l'aiguille suit le feu
	var m := Vector2(c.x - L * 0.08, y_h + 27.0)
	draw_circle(m, 10.5, BRUN)
	draw_circle(m, 9.0, Color("#d6a23a"))
	draw_circle(m, 6.8, Color("#fbf3df"))
	draw_arc(m, 5.0, -2.4, -0.5, 8, Color("#d9442e"), 1.6)
	draw_line(m, m + Vector2(cos(_aiguille), sin(_aiguille)) * 5.8, BRUN, 1.6, true)
	draw_circle(m, 1.4, BRUN)

# La porte du foyer : une arche de fonte, et derrière la grille, le feu qui
# couve (et flambe quand on chauffe).
func _dessiner_feu(c: Vector2) -> void:
	var y0 := c.y - 4.0
	var w := 22.0
	var h := 18.0
	var arche := PackedVector2Array([Vector2(c.x - w * 0.5, y0)])
	for k in 9:
		var a := PI + PI * k / 8.0
		arche.append(Vector2(c.x + cos(a) * w * 0.5, y0 - h + 7.0 + sin(a) * 7.0))
	arche.append(Vector2(c.x + w * 0.5, y0))
	draw_colored_polygon(arche, Color("#2a1f1b"))
	var vif := clampf(0.62 + 0.12 * sin(_t * 9.0) + 0.08 * sin(_t * 23.0) + 0.5 * force, 0.0, 1.0)
	var flamme := PackedVector2Array()
	var cf := PackedColorArray()
	for p in arche:
		flamme.append(c + (p - c) * Vector2(0.78, 1.0) + Vector2(0, 2.0))
	for p in flamme:
		var bas := clampf((p.y - (y0 - h)) / h, 0.0, 1.0)
		cf.append(Color("#ff6a10").lerp(Color("#ffe066"), bas).darkened(0.5 * (1.0 - vif)))
	draw_polygon(flamme, cf)
	# la grille de la porte
	for k in 3:
		var x := c.x - w * 0.25 + k * w * 0.25
		draw_line(Vector2(x, y0 - h + 4.0), Vector2(x, y0), Color("#2a1f1b"), 2.0)
	_contour(arche, true)
	# la lueur sur l'herbe devant le foyer
	if vif > 0.5:
		draw_set_transform(Vector2(c.x, y0 + 2.0), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.62, 0.2, 0.35 * (vif - 0.5) / 0.5))
		draw_set_transform(Vector2.ZERO)
		# et le halo dans l'arche
		draw_circle(Vector2(c.x, y0 - h * 0.45), w * 0.42, Color(1.0, 0.75, 0.3, 0.25 * (vif - 0.5) / 0.5))

# Fumée (grise, de la cheminée) ou vapeur (blanche, du sifflet) : des disques
# doux, plusieurs cercles de moins en moins opaques.
func _dessiner_fumees(vapeur: bool) -> void:
	# des nuages de dessin animé : un dessous un peu ombré, un cœur opaque,
	# un liseré doux ; ils s'effacent en vieillissant
	for b in _bouffees:
		if (b[5] > 0.5) != vapeur: continue
		var vie: float = b[3] / b[4]
		var a := (1.0 - vie * vie) * minf(1.0, b[3] * 8.0)
		var col := Color(1, 1, 1) if vapeur else Color(0.80, 0.78, 0.77)
		var ombre := Color(0.86, 0.9, 0.96) if vapeur else Color(0.6, 0.58, 0.58)
		var r: float = b[2]
		var p: Vector2 = b[0]
		draw_circle(p, r * 1.3, Color(col, 0.16 * a))
		draw_circle(p + Vector2(0, r * 0.18), r, Color(ombre, 0.75 * a))
		draw_circle(p + Vector2(-r * 0.12, -r * 0.08), r * 0.88, Color(col, 0.85 * a))
		draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Color(1, 1, 1, 0.6 * a))

func _coins(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

func _contour(p: PackedVector2Array, ferme: bool) -> void:
	var q := p.duplicate()
	if ferme: q.append(p[0])
	draw_polyline(q, BRUN, 2.2, true)

func _rect_degrade(r: Rect2, clair: Color, sombre: Color) -> void:
	draw_polygon(_coins(r), PackedColorArray([clair, sombre, sombre, clair]))

# Un cylindre debout, éclairé d'en haut à gauche : clair au tiers, sombre à droite.
func _cylindre(r: Rect2, reflet: Color, moyen: Color, ombre: Color) -> void:
	var xs := [0.0, 0.12, 0.32, 0.62, 1.0]
	var cs := [moyen, reflet, moyen, moyen.lerp(ombre, 0.5), ombre]
	for k in 4:
		var x0: float = r.position.x + r.size.x * xs[k]
		var x1: float = r.position.x + r.size.x * xs[k + 1]
		draw_polygon(PackedVector2Array([Vector2(x0, r.position.y), Vector2(x1, r.position.y), Vector2(x1, r.end.y), Vector2(x0, r.end.y)]),
			PackedColorArray([cs[k], cs[k + 1], cs[k + 1], cs[k]]))
