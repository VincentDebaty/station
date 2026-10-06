class_name Etoiles
extends Control
# ------------------------------------------------------------------
# TROIS ÉTOILES, comme sur la maquette du niveau 14 : dorées et cerclées de
# brun quand elles sont gagnées, grises sinon.
#
# Pour être fidèle au rendu peint de la maquette (Vincent, 6 octobre 2026),
# le mieux est une image : si art/etoile_pleine.png existe, elle remplace le
# dessin (prompt dans ASSETS.md), et l'étoile vide en est la copie passée au
# gris — ChatGPT, lui, redessinerait une autre étoile, d'une autre taille
# (vu avec les bateaux). art/etoile_vide.png, si on la fournit, prime. Sans
# image, une étoile dessinée aux pointes arrondies (polygone adouci par
# Chaikin), avec un dégradé et un reflet.
# ------------------------------------------------------------------

var n := 3
var taille := 40.0
var _pleine: Texture2D = null
var _vide: Texture2D = null

func _ready() -> void:
	if ResourceLoader.exists("res://art/etoile_pleine.png"): _pleine = _reduire(load("res://art/etoile_pleine.png"))
	if ResourceLoader.exists("res://art/etoile_vide.png"): _vide = _reduire(load("res://art/etoile_vide.png"))
	elif _pleine: _vide = _griser(_pleine)

# L'image livrée fait plus de 1 200 px pour s'afficher à 50 : réduite d'un coup
# à l'écran, elle crénèle. On la réduit une fois, proprement (Lanczos).
func _reduire(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var cote := int(clampf(taille * 2.5, 64.0, 256.0))
	if img.get_width() > cote:
		img.resize(cote, int(float(cote) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

# L'étoile vide : la même image, en gris un peu plus sombre, reflets gardés.
func _griser(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := (0.30 * c.r + 0.59 * c.g + 0.11 * c.b) * 0.78
			img.set_pixel(x, y, Color(l, l, l * 0.98, c.a))
	return ImageTexture.create_from_image(img)

func regler(nombre: int) -> void:
	n = nombre
	queue_redraw()

func _get_minimum_size() -> Vector2:
	return Vector2(taille * 3.0 + taille * 0.15 * 2.0, taille)

func _draw() -> void:
	for i in 3:
		var c := Vector2(taille * 0.5 + i * taille * 1.15, taille * 0.5)
		var tex := _pleine if i < n else _vide
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(taille, taille) * 0.5, Vector2(taille, taille)), false)
		else:
			_etoile(c, taille * 0.52, i < n)

# Les dix sommets d'une étoile dodue (creux à 55 % du rayon), puis deux passes
# de Chaikin : chaque angle est remplacé par deux points, et les pointes
# s'arrondissent comme sur la maquette.
func _contour(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for j in 10:
		var a := -PI / 2.0 + j * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if j % 2 == 0 else r * 0.55))
	for _passe in 3:
		var lisse := PackedVector2Array()
		for j in pts.size():
			var a := pts[j]
			var b := pts[(j + 1) % pts.size()]
			lisse.append(a.lerp(b, 0.25))
			lisse.append(a.lerp(b, 0.75))
		pts = lisse
	return pts

func _etoile(c: Vector2, r: float, pleine: bool) -> void:
	var bord := Color("#8f5a0c") if pleine else Color("#66645f")
	var fonce := Color("#f0a81c") if pleine else Color("#8e8c86")
	var clair := Color("#ffd94a") if pleine else Color("#b5b3ad")
	var exterieur := _contour(c, r * 1.12)
	draw_colored_polygon(exterieur, bord)                     # le cerne épais
	var corps := _contour(c, r)
	# dégradé du haut (clair) vers le bas (foncé)
	var couleurs := PackedColorArray()
	for p in corps:
		couleurs.append(clair.lerp(fonce, clampf((p.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)))
	draw_polygon(corps, couleurs)
	# le reflet, petite étoile claire décalée vers le haut à gauche
	var reflet := PackedVector2Array()
	for p in _contour(c + Vector2(-r * 0.1, -r * 0.18), r * 0.42):
		reflet.append(p)
	draw_colored_polygon(reflet, Color(1, 1, 1, 0.38 if pleine else 0.22))
