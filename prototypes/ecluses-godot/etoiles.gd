class_name Etoiles
extends Control
# ------------------------------------------------------------------
# TROIS ÉTOILES, dessinées comme sur la maquette du niveau 14 : dorées et
# cerclées de brun quand elles sont gagnées, grises sinon, avec un reflet.
# (Un caractère « ★ » ne donne ni le contour ni l'étoile vide grise.)
# ------------------------------------------------------------------

var n := 3
var taille := 40.0

func regler(nombre: int) -> void:
	n = nombre
	queue_redraw()

func _get_minimum_size() -> Vector2:
	return Vector2(taille * 3.0 + taille * 0.2 * 2.0, taille)

func _draw() -> void:
	for i in 3:
		var c := Vector2(taille * 0.5 + i * taille * 1.2, taille * 0.53)
		_etoile(c, taille * 0.5, i < n)

func _etoile(c: Vector2, r: float, pleine: bool) -> void:
	var pts := PackedVector2Array()
	for j in 10:
		var a := -PI / 2.0 + j * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if j % 2 == 0 else r * 0.5))
	var fond := Color("#f8c22a") if pleine else Color("#a3a19b")
	var bord := Color("#9a6410") if pleine else Color("#6c6a65")
	draw_colored_polygon(pts, fond)
	# le reflet : une étoile plus petite et plus claire, décalée vers le haut
	var reflet := PackedVector2Array()
	for p in pts: reflet.append(c + (p - c) * 0.55 + Vector2(-r * 0.06, -r * 0.14))
	draw_colored_polygon(reflet, Color(1, 1, 1, 0.32 if pleine else 0.18))
	var tour := pts.duplicate()
	tour.append(pts[0])
	draw_polyline(tour, bord, maxf(2.0, r * 0.13), true)
