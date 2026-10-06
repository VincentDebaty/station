class_name Bateau
extends Node2D
# ------------------------------------------------------------------
# UN BATEAU — dessiné autour de l'origine, qui est le milieu de sa ligne de
# flottaison. La coque descend de « tirant » sous la ligne : c'est la même
# grandeur que le tirant d'eau du moteur, si bien qu'un bateau qui s'échoue
# touche le fond pour de vrai à l'écran.
#
# Si art/bateau_<k>.png existe, l'image remplace le dessin. Le canal la
# recadre sur ses pixels opaques (les marges d'une image générée varient) et
# la cale sur la longueur de coque ; « ligne » dit où tombe sa flottaison,
# en fraction de sa hauteur (art/bateaux.json). Son tirant visible est alors
# celui de l'image, plus celui du moteur : voir ASSETS.md.
# ------------------------------------------------------------------

var couleur := Color.RED
var longueur := 112.0
var tirant := 58.0          # pixels sous la ligne de flottaison
var sens := 1.0             # 1 : la proue à droite
var image: Texture2D = null
var ligne := 0.71

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sens, 1.0))
	var L := longueur * 0.5
	if image:
		var w := longueur * 1.12
		var h := w * image.get_height() / image.get_width()
		draw_texture_rect(image, Rect2(-w * 0.5, -ligne * h, w, h), false)
		return
	var fonce := Color("#4a2a26")
	var franc := 0.3 * longueur
	# l'ombre portée sur l'eau
	draw_colored_polygon(PackedVector2Array([Vector2(-L, 2), Vector2(L, 2), Vector2(L * 0.9, 8), Vector2(-L * 0.95, 8)]), Color(0, 0.2, 0.3, 0.18))
	# la coque : franc-bord coloré, œuvres vives plus sombres sous la ligne
	var coque := PackedVector2Array([
		Vector2(-L, -franc), Vector2(L * 1.04, -franc - 6), Vector2(L * 0.82, tirant * 0.55),
		Vector2(L * 0.55, tirant), Vector2(-L * 0.72, tirant), Vector2(-L * 0.96, tirant * 0.45)])
	draw_colored_polygon(coque, couleur)
	var vives := PackedVector2Array([
		Vector2(-L * 0.985, 0), Vector2(L * 0.96, 0), Vector2(L * 0.82, tirant * 0.55),
		Vector2(L * 0.55, tirant), Vector2(-L * 0.72, tirant), Vector2(-L * 0.96, tirant * 0.45)])
	draw_colored_polygon(vives, fonce)
	draw_polyline(coque + PackedVector2Array([coque[0]]), Color("#2a2420"), 2.0, true)
	# le liston blanc et les hublots
	draw_line(Vector2(-L * 0.98, -franc * 0.45), Vector2(L, -franc * 0.5), Color(1, 1, 1, 0.85), 3.0, true)
	for k in 3:
		var p := Vector2(-L * 0.45 + k * L * 0.42, -franc * 0.12)
		draw_circle(p, 4.5, Color("#2a2420"))
		draw_circle(p, 3.0, Color("#bfe6f2"))
	# la cabine, son toit, ses fenêtres, la bouée
	var cab := Rect2(-L * 0.55, -franc - 0.36 * longueur, 0.62 * longueur, 0.36 * longueur)
	draw_rect(cab, Color("#f6efe0"))
	draw_rect(cab, Color("#2a2420"), false, 2.0)
	draw_rect(Rect2(cab.position.x - 4, cab.position.y - 7, cab.size.x + 8, 8), couleur.darkened(0.15))
	for k in 2:
		draw_rect(Rect2(cab.position.x + 8 + k * 22, cab.position.y + 8, 15, 13), Color("#6fb6d4"))
	draw_circle(Vector2(cab.end.x - 12, cab.position.y + cab.size.y * 0.62), 7.0, Color("#e3452f"))
	draw_circle(Vector2(cab.end.x - 12, cab.position.y + cab.size.y * 0.62), 3.5, Color("#f6efe0"))
	# la cheminée
	draw_rect(Rect2(L * 0.2, -franc - 0.3 * longueur, 9, 0.3 * longueur), Color("#2a2420"))
	draw_rect(Rect2(L * 0.2, -franc - 0.24 * longueur, 9, 5), couleur)
	# le mât et le fanion, à la couleur du bateau
	var pied := Vector2(-L * 0.82, -franc)
	draw_line(pied, pied + Vector2(0, -0.62 * longueur), Color("#2a2420"), 2.5, true)
	draw_colored_polygon(PackedVector2Array([pied + Vector2(0, -0.62 * longueur), pied + Vector2(24, -0.55 * longueur), pied + Vector2(0, -0.48 * longueur)]), couleur)
