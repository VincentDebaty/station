class_name Pompe
extends Node2D
# ------------------------------------------------------------------
# LA POMPE À BRAS (chapitre 4, 7 octobre 2026, d'après l'image cible validée
# par Vincent) : sur la berge, au-dessus du bassin qu'elle remplit. Chaque
# toucher (le moteur : « pomper ») abaisse le levier puis le relève ; un jet
# sort du bec et tombe dans le bassin, et l'eau court dans le tuyau qui part
# d'une grille au fond du bassin d'en bas. Les images : art/pompe.png (le
# corps, bec à gauche) et art/levier.png (le levier, anneau de pivot à
# gauche), que le jeu fait basculer.
# ------------------------------------------------------------------

signal coup_fini

var canal: Canal
var i := 0                 # la pompe, dans N["pompes"]
var base := Vector2.ZERO   # le pied de la pompe, sur la berge
var _corps: Texture2D
var _levier: Texture2D
const HAUT := 150.0
var _angle := -0.32        # le levier au repos, relevé
var _coup := -1.0           # le temps du coup en cours, -1 au repos
var _t := 0.0
var actif := true

func preparer(c: Canal, ai: int, abase: Vector2) -> void:
	canal = c; i = ai; base = abase
	if ResourceLoader.exists("res://art/pompe.png"): _corps = Images.reduire("res://art/pompe.png", 240)
	if ResourceLoader.exists("res://art/levier.png"): _levier = Images.reduire("res://art/levier.png", 300)
	z_index = 2

func _w() -> float:
	return HAUT * _corps.get_width() / _corps.get_height() if _corps else 40.0

# Le bout du bec, d'où sort le jet.
func bec() -> Vector2:
	return base + Vector2(-_w() * 0.5 + 2.0, -HAUT * 0.66)

# Le pivot du levier, sur le haut de la pompe.
func pivot() -> Vector2:
	return base + Vector2(_w() * 0.13, -HAUT * 0.94)

func sous(p: Vector2) -> bool:
	return Rect2(base.x - _w() * 0.8, base.y - HAUT - 40.0, _w() * 1.6 + 70.0, HAUT + 50.0).has_point(p)

# Un coup de pompe : le levier descend (0,25 s) et remonte (0,35 s).
func pomper() -> void:
	_coup = 0.0

func _process(dt: float) -> void:
	_t += dt
	if _coup >= 0.0:
		_coup += dt
		if _coup < 0.25: _angle = lerpf(-0.32, 0.38, _coup / 0.25)
		elif _coup < 0.6: _angle = lerpf(0.38, -0.32, (_coup - 0.25) / 0.35)
		else:
			_angle = -0.32
			_coup = -1.0
			coup_fini.emit()
	modulate = modulate.lerp(Color(1, 1, 1) if actif else Color(0.75, 0.72, 0.72), minf(1.0, dt * 6.0))
	queue_redraw()

func _draw() -> void:
	var w := _w()
	# l'ombre au pied
	draw_set_transform(base + Vector2(4, -2), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, w * 0.7, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	# le levier, derrière le corps : il pivote sur le haut de la pompe ; tant
	# qu'on n'a pas pompé, il se balance un peu pour inviter le doigt
	var a := _angle + (0.03 * sin(_t * 2.4) if _coup < 0.0 and actif else 0.0)
	if _levier:
		var lw := 110.0
		var lh := lw * _levier.get_height() / _levier.get_width()
		draw_set_transform(pivot(), a)
		draw_texture_rect(_levier, Rect2(-lw * 0.05, -lh * 0.5, lw, lh), false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_line(pivot(), pivot() + Vector2(cos(a), sin(a)) * 80.0, Color("#8a5a2e"), 7.0, true)
	if _corps:
		draw_texture_rect(_corps, Rect2(base.x - w * 0.5, base.y - HAUT, w, HAUT), false)
	else:
		draw_rect(Rect2(base.x - 10, base.y - HAUT, 20, HAUT), Color("#3a3a3e"))
