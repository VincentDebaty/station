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
# Sur la pancarte de victoire (Vincent : « étoiles qui apparaissent
# dynamiquement puis qui scintillent ») : une à une, elles surgissent en
# dépassant un peu ; puis des éclats blancs s'allument tour à tour sur les
# étoiles gagnées, et elles battent doucement. Les étoiles du haut de l'écran,
# elles, ne s'animent pas.
var _anime := false
# En arc, comme sur la maquette de victoire : celle du milieu plus grande et
# plus haute, les deux autres plus bas sur les côtés, des paillettes autour.
var en_arc := false
var _t := 0.0
const DEBUT := 0.35          # après la chute de la pancarte
const ECART := 0.32          # entre deux étoiles
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

# L'étoile vide : la même image, en brun foncé — le bois de la maquette, où
# l'étoile non gagnée est sombre et brune, pas grise. Reflets gardés.
func _griser(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := 0.30 * c.r + 0.59 * c.g + 0.11 * c.b
			var b := Color(0.16, 0.08, 0.03).lerp(Color(0.62, 0.38, 0.18), l)
			img.set_pixel(x, y, Color(b.r, b.g, b.b, c.a))
	return ImageTexture.create_from_image(img)

func regler(nombre: int) -> void:
	n = nombre
	queue_redraw()

func animer() -> void:
	_anime = true
	_t = 0.0
	queue_redraw()

func _process(dt: float) -> void:
	if _anime:
		_t += dt
		queue_redraw()

# L'échelle de l'étoile i à l'instant t : 0 avant son tour, puis elle surgit
# (courbe « back » : elle dépasse un peu, se pose), puis bat doucement.
func _echelle(i: int) -> float:
	if not _anime: return 1.0
	var t := _t - DEBUT - i * ECART
	if t <= 0.0: return 0.0
	if t < 0.38:
		var u := t / 0.38 - 1.0
		return 1.0 + 2.9 * u * u * u + 1.9 * u * u
	if i < n: return 1.0 + 0.035 * sin((t - 0.38) * 3.2 + i)
	return 1.0

func _cote(i: int) -> float:
	return taille * (1.3 if en_arc and i == 1 else 1.0)

func _centre(i: int) -> Vector2:
	if not en_arc:
		return Vector2(taille * 0.5 + i * taille * 1.15, taille * 0.5)
	var ecart := taille * 0.04
	var x := 0.0
	for j in i: x += _cote(j) + ecart
	x += _cote(i) * 0.5
	var y := _cote(1) * 0.5 + (0.0 if i == 1 else taille * 0.22)
	return Vector2(x, y)

func _get_minimum_size() -> Vector2:
	if en_arc:
		return Vector2(_cote(0) + _cote(1) + _cote(2) + taille * 0.08, _cote(1) * 0.5 + taille * 0.22 + taille * 0.5)
	return Vector2(taille * 3.0 + taille * 0.15 * 2.0, taille)

func _draw() -> void:
	if _anime and en_arc: _paillettes()
	for i in 3:
		var c := _centre(i)
		var cote := _cote(i)
		var e := _echelle(i)
		if e <= 0.01: continue
		var tour := 0.0
		if _anime:
			tour = (1.0 - clampf((_t - DEBUT - i * ECART) / 0.38, 0.0, 1.0)) * -0.5
		draw_set_transform(c, tour, Vector2(e, e))
		var tex := _pleine if i < n else _vide
		if tex:
			draw_texture_rect(tex, Rect2(-Vector2(cote, cote) * 0.5, Vector2(cote, cote)), false)
		else:
			_etoile(Vector2.ZERO, cote * 0.52, i < n)
		draw_set_transform(Vector2.ZERO)
	if _anime: _eclats()

# Les paillettes : de petits points dorés qui clignotent autour des étoiles,
# chacun à son rythme, une fois les étoiles apparues.
func _paillettes() -> void:
	var depart := DEBUT + 0.2
	if _t < depart: return
	var l := get_combined_minimum_size()
	var points := [Vector2(-0.06, 0.62), Vector2(0.05, 0.25), Vector2(0.3, 0.02), Vector2(0.7, 0.04),
		Vector2(0.95, 0.28), Vector2(1.05, 0.66), Vector2(0.22, 0.9), Vector2(0.8, 0.92)]
	for j in points.size():
		var a := 0.5 + 0.5 * sin((_t - depart) * (2.3 + j * 0.37) + j * 1.7)
		a *= clampf((_t - depart) / 0.6, 0.0, 1.0)
		var p: Vector2 = points[j] * l
		var r := taille * (0.05 + 0.03 * a)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 2.2), p + Vector2(r * 0.5, 0), p + Vector2(0, r * 2.2), p + Vector2(-r * 0.5, 0)]), Color(1, 0.92, 0.55, a))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 2.2, 0), p + Vector2(0, r * 0.5), p + Vector2(r * 2.2, 0), p + Vector2(0, -r * 0.5)]), Color(1, 0.92, 0.55, a))

# Les éclats : une petite croix de lumière à quatre branches qui s'allume et
# s'éteint, à tour de rôle sur chaque étoile gagnée, une fois toutes posées.
func _eclats() -> void:
	var depart := DEBUT + 3 * ECART + 0.4
	if n <= 0 or _t < depart: return
	var cycle := 0.75
	var rang := int((_t - depart) / cycle)
	var phase := fmod(_t - depart, cycle) / cycle
	var i := rang % n
	var c := _centre(i)
	var o := c + Vector2(_cote(i) * (0.12 if rang % 2 == 0 else -0.18), -_cote(i) * (0.2 if rang % 3 == 0 else 0.05))
	var a := sin(phase * PI)
	var r := taille * 0.32 * (0.6 + 0.4 * a)
	var blanc := Color(1, 1, 0.94, a)
	for ang in [0.0, PI * 0.5]:
		var d := Vector2(cos(ang + phase), sin(ang + phase))
		var p := Vector2(-d.y, d.x) * r * 0.16
		draw_colored_polygon(PackedVector2Array([o + d * r, o + p, o - d * r, o - p]), blanc)
	draw_circle(o, r * 0.18, blanc)

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
	var bord := Color("#8f5a0c") if pleine else Color("#2e1808")
	var fonce := Color("#f0a81c") if pleine else Color("#4a2b12")
	var clair := Color("#ffd94a") if pleine else Color("#7a4d26")
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
