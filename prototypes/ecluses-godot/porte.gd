class_name Porte
extends Node2D
# ------------------------------------------------------------------
# UNE PORTE D'ÉCLUSE — le radier de pierre sous le seuil, deux montants, une
# passerelle, le vantail de bois et la roue de manœuvre au-dessus.
#
# Ouvrir, c'est faire pivoter le vantail : on finit par le voir de côté,
# plaqué contre son montant, et l'ouverture laisse passer l'eau. La roue tourne
# pendant la manœuvre. « ouverture » va de 0 (fermée) à 1 (ouverte).
# ------------------------------------------------------------------

signal manoeuvre_finie

var gx0 := 0.0
var gx1 := 0.0
var y_seuil := 0.0
var y_crete := 0.0
var y_bas := 0.0
var u := 64.0
var ouverture := 0.0
var _cible := 0.0
var _angle := 0.0
var _vantail: Polygon2D
var _mat_bois: ShaderMaterial
var roue: Node2D

func preparer(ax0: float, ax1: float, aseuil: float, acrete: float, abas: float, au: float, pierre: Shader, bois: Shader, ouverte: bool) -> void:
	gx0 = ax0; gx1 = ax1; y_seuil = aseuil; y_crete = acrete; y_bas = abas; u = au
	ouverture = 1.0 if ouverte else 0.0
	_cible = ouverture
	var mp := ShaderMaterial.new()
	mp.shader = pierre
	# le radier, sous le seuil, et les deux montants
	add_child(_rect(gx0, y_seuil, gx1, y_bas, mp))
	add_child(_rect(gx0 - 5, y_crete - 0.32 * u, gx0 + 9, y_seuil, mp))
	add_child(_rect(gx1 - 9, y_crete - 0.32 * u, gx1 + 5, y_seuil, mp))
	# le vantail
	_mat_bois = ShaderMaterial.new()
	_mat_bois.shader = bois
	_vantail = Polygon2D.new()
	_vantail.material = _mat_bois
	add_child(_vantail)
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

func _rect(ax0: float, ay0: float, ax1: float, ay1: float, mat: Material) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = _quad(ax0, ay0, ax1, ay1)
	p.material = mat
	return p

func _quad(ax0: float, ay0: float, ax1: float, ay1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(ax0, ay0), Vector2(ax1, ay0), Vector2(ax1, ay1), Vector2(ax0, ay1)])

func manoeuvrer(ouvrir: bool) -> void:
	_cible = 1.0 if ouvrir else 0.0

func centre_roue() -> Vector2:
	return Vector2((gx0 + gx1) / 2.0, y_crete - 1.3 * u)

func _process(dt: float) -> void:
	if not is_equal_approx(ouverture, _cible):
		var avant := ouverture
		ouverture = move_toward(ouverture, _cible, dt / 0.6)
		_angle += (ouverture - avant) * TAU * 1.5
		_maj_vantail()
		roue.queue_redraw()
		if is_equal_approx(ouverture, _cible):
			manoeuvre_finie.emit()

func _maj_vantail() -> void:
	var a := gx0 + 9.0
	var b := gx1 - 9.0
	# le vantail pivote autour du montant de gauche : sa largeur apparente fond
	var e := ease(ouverture, -2.0)
	var largeur := (b - a) * lerpf(1.0, 0.2, e)
	var haut := y_crete - 0.30 * u
	# le bord libre du vantail vient vers nous en pivotant : il s'allonge un peu
	var biais := 9.0 * sin(e * PI * 0.5)
	_vantail.polygon = PackedVector2Array([Vector2(a, haut), Vector2(a + largeur, haut - biais), Vector2(a + largeur, y_seuil + biais), Vector2(a, y_seuil)])
	_mat_bois.set_shader_parameter("cadre", Vector4(a, haut, a + largeur, y_seuil))
	_mat_bois.set_shader_parameter("tranche", e)

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
