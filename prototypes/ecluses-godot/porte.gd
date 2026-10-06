class_name Porte
extends Node2D
# ------------------------------------------------------------------
# UNE PORTE D'ÉCLUSE — comme une vraie, en deux temps (retours de Vincent
# après le test sur iPhone, 6 octobre 2026) :
#
#   1. la roue ouvre une VANNE : l'eau passe d'un bassin à l'autre par un
#      aqueduc (aqueduc.gd), pas par la porte — aucun jet ne vient pousser
#      les bateaux ;
#   2. quand les deux eaux sont au même niveau, le VANTAIL s'efface : il
#      descend dans le radier, derrière sa pierre, et les bateaux passent
#      par-dessus. (Une fente dessinée faisait un puits noir dans la terre.)
#
# Une porte qui monterait devrait s'élever deux fois plus haut que l'écluse
# pour laisser passer un bateau ; vue de côté, elle sortirait de l'écran.
#
# « abaisse » va de 0 (vantail levé, porte fermée) à 1 (vantail dans sa fente).
# Le moteur ne connaît que « ouvert » : la vanne. Le vantail ne fait que
# suivre la règle qu'il applique déjà — un bateau ne passe que si les deux
# eaux sont au même niveau.
# ------------------------------------------------------------------

signal roue_finie
signal vantail_fini

var gx0 := 0.0
var gx1 := 0.0
var y_seuil := 0.0
var y_crete := 0.0
var y_bas := 0.0
var u := 64.0
var abaisse := 0.0
var vanne_ouverte := false
var _cible := 0.0
var _angle := 0.0
var _rotation := 0.0       # tours de roue qui restent à faire
var _vantail: Polygon2D
var _mat_bois: ShaderMaterial
var roue: Node2D

func preparer(ax0: float, ax1: float, aseuil: float, acrete: float, abas: float, au: float, pierre: Shader, bois: Shader, terre: Material, vanne: bool, baisse: bool) -> void:
	gx0 = ax0; gx1 = ax1; y_seuil = aseuil; y_crete = acrete; y_bas = abas; u = au
	vanne_ouverte = vanne
	abaisse = 1.0 if baisse else 0.0
	_cible = abaisse
	var mp := ShaderMaterial.new()
	mp.shader = pierre
	# le vantail d'abord : le radier et la terre, dessinés par-dessus, le
	# cachent quand il s'enfonce
	_mat_bois = ShaderMaterial.new()
	_mat_bois.shader = bois
	_vantail = Polygon2D.new()
	_vantail.material = _mat_bois
	add_child(_vantail)
	add_child(_rect(gx0, y_seuil, gx1, y_bas, mp))
	add_child(_rect(gx0, y_bas, gx1, y_bas + 2600.0, terre))
	# les deux montants
	add_child(_rect(gx0 - 5, y_crete - 0.32 * u, gx0 + 9, y_seuil, mp))
	add_child(_rect(gx1 - 9, y_crete - 0.32 * u, gx1 + 5, y_seuil, mp))
	# la passerelle, poutre sombre posée sur les montants
	var poutre := Polygon2D.new()
	poutre.color = Color("#3b2a1e")
	poutre.polygon = _quad(gx0 - 14, y_crete - 0.46 * u, gx1 + 14, y_crete - 0.30 * u)
	add_child(poutre)
	roue = Node2D.new()
	roue.z_index = 6
	roue.draw.connect(_dessiner_roue)
	add_child(roue)
	_maj_vantail()

func _hauteur() -> float:
	return y_seuil - (y_crete - 0.30 * u)

func _rect(ax0: float, ay0: float, ax1: float, ay1: float, mat: Material) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = _quad(ax0, ay0, ax1, ay1)
	p.material = mat
	return p

func _quad(ax0: float, ay0: float, ax1: float, ay1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(ax0, ay0), Vector2(ax1, ay0), Vector2(ax1, ay1), Vector2(ax0, ay1)])

func centre_roue() -> Vector2:
	return Vector2((gx0 + gx1) / 2.0, y_crete - 1.3 * u)

# La vanne : la roue fait un tour et demi. Émet roue_finie.
func manoeuvrer_vanne(ouvrir: bool) -> void:
	vanne_ouverte = ouvrir
	_rotation = 1.5 * TAU * (1.0 if ouvrir else -1.0)

# Le vantail : il descend dans sa fente, ou en remonte. Émet vantail_fini
# (tout de suite s'il est déjà où on le veut).
func placer_vantail(baisser: bool) -> void:
	_cible = 1.0 if baisser else 0.0
	if is_equal_approx(abaisse, _cible):
		vantail_fini.emit.call_deferred()

func _process(dt: float) -> void:
	if _rotation != 0.0:
		var pas := signf(_rotation) * minf(absf(_rotation), dt * TAU * 2.6)
		_rotation -= pas
		_angle += pas
		roue.queue_redraw()
		if is_zero_approx(_rotation):
			_rotation = 0.0
			roue_finie.emit()
	if not is_equal_approx(abaisse, _cible):
		abaisse = move_toward(abaisse, _cible, dt / 1.1)
		_maj_vantail()
		if is_equal_approx(abaisse, _cible):
			vantail_fini.emit()

func _maj_vantail() -> void:
	var a := gx0 + 9.0
	var b := gx1 - 9.0
	var descente := ease(abaisse, -2.2) * _hauteur()
	var haut := y_crete - 0.30 * u + descente
	var bas := y_seuil + descente
	_vantail.polygon = _quad(a, haut, b, bas)
	_mat_bois.set_shader_parameter("cadre", Vector4(a, haut, b, bas))
	_mat_bois.set_shader_parameter("tranche", 0.0)

func _dessiner_roue() -> void:
	var c := centre_roue()
	var r := 0.4 * u
	var rouge := Color("#c8321f")
	var sombre := Color("#7c1f13")
	# le pied, de la passerelle à l'axe
	roue.draw_rect(Rect2(c.x - 4, c.y, 8, (y_crete - 0.46 * u) - c.y), Color("#2d2a28"))
	roue.draw_circle(c + Vector2(2, 3), r + 5, Color(0, 0, 0, 0.18))
	roue.draw_arc(c, r, 0, TAU, 40, sombre, 10.0, true)
	roue.draw_arc(c, r, 0, TAU, 40, rouge, 7.0, true)
	roue.draw_arc(c, r - 1.5, PI * 1.1, PI * 1.6, 12, Color(1, 0.6, 0.5, 0.7), 2.0, true)
	for k in 6:
		var a := _angle + k * TAU / 6.0
		var d := Vector2(cos(a), sin(a))
		roue.draw_line(c + d * 5.0, c + d * (r - 3.0), sombre, 5.0, true)
		roue.draw_line(c + d * 5.0, c + d * (r - 3.0), rouge, 3.0, true)
		if k % 2 == 0:
			roue.draw_circle(c + d * (r + 4.0), 3.5, sombre)
	roue.draw_circle(c, 7.0, sombre)
	roue.draw_circle(c, 4.0, Color("#e9e2d8"))
	# la vanne : une pastille verte quand elle est ouverte
	var p := c + Vector2(0, -r - 11)
	roue.draw_circle(p, 6.0, Color(1, 1, 1, 0.9))
	roue.draw_circle(p, 4.0, Color("#2f9e58") if vanne_ouverte else Color("#8a8f92"))
