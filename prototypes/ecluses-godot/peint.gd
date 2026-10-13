class_name Peint
extends RefCounted
# ------------------------------------------------------------------
# LE DÉCOR PEINT — les images de art/ que Vincent a fait peindre par ChatGPT
# (6 octobre 2026, prompts dans ASSETS.md) pour remplacer le dessin des
# shaders : terre, pierre, vantail, traverse, roue, bord d'herbe, rochers et
# pousses. Chacune est chargée une fois, préparée (recadrée, réduite, avec ses
# mipmaps pour les textures qui se répètent) et partagée. Une image absente
# renvoie null : le dessin d'avant reprend sa place.
#
# Les tailles sont en pixels du monde ; on garde le double de résolution, pour
# que l'iPhone (plus dense que la fenêtre) ne voie pas flou.
# ------------------------------------------------------------------

static var _cache := {}

# La terre, en tuiles de TERRE px de côté.
const TERRE := 512.0
# La pierre : quatre rangées de blocs par tuile, RANGEE px chacune.
const RANGEE := 36.0

static func terre() -> Texture2D:
	return _memo("terre", func(): return _tuile(art("terre.png"), int(TERRE * 1.5), false))

static func pierre() -> Texture2D:
	return _memo("pierre", func(): return _tuile(art("pierre.png"), 0, true))

# La taille d'une tuile de pierre dans le monde, d'après les rangées trouvées.
static func tuile_pierre() -> Vector2:
	var t := pierre()
	if t == null: return Vector2.ONE
	var rangees: int = _cache.get(("c:" if Canal.cartoon else "") + "pierre_rangees", 4)
	var h := RANGEE * rangees
	return Vector2(h * t.get_width() / t.get_height(), h)

static func vantail() -> Texture2D:
	return _memo("vantail", func(): return _simple(art("vantail.png"), 96, true))

static func traverse() -> Texture2D:
	return _memo("traverse", func(): return _simple_h(art("traverse.png"), 40))

static func roue() -> Texture2D:
	return _memo("roue", func(): return _simple(art("roue.png"), 160, false))

static func herbe() -> Texture2D:
	return _memo("herbe", func(): return _simple_h(art("herbe_bord.png"), 80))

# Les rochers et les pousses : une planche de trois, découpée en trois images.
static func rochers() -> Array:
	return _memo("rochers", func(): return _planche(art("rochers.png"), 160))

static func pousses() -> Array:
	return _memo("pousses", func(): return _planche(art("pousses.png"), 80))

# Le chemin d'une image : en style dessin animé, art/cartoon/<nom> s'il
# existe (les images refaites dans le style de l'image cible, 13 octobre
# 2026), sinon l'image peinte d'avant.
static func art(nom: String) -> String:
	if Canal.cartoon and ResourceLoader.exists("res://art/cartoon/" + nom): return "res://art/cartoon/" + nom
	return "res://art/" + nom

static func _memo(cle: String, f: Callable):
	cle = ("c:" if Canal.cartoon else "") + cle    # une préparation par style
	if not _cache.has(cle): _cache[cle] = f.call()
	return _cache[cle]

static func _image(chemin: String) -> Image:
	if not ResourceLoader.exists(chemin): return null
	var img: Image = (load(chemin) as Texture2D).get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img

# Une image posée telle quelle, recadrée sur ses pixels visibles, à
# « largeur » px de large.
static func _simple(chemin: String, largeur: int, mip: bool) -> Texture2D:
	var img := _image(chemin)
	if img == null: return null
	var r := Images._opaque(img)
	if r.size.x > 0: img = img.get_region(r)
	img.resize(largeur, maxi(1, int(float(largeur) * img.get_height() / img.get_width())), Image.INTERPOLATE_LANCZOS)
	if mip: img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# Pareil, mais à « hauteur » px de haut (les bandes : traverse, herbe).
static func _simple_h(chemin: String, hauteur: int) -> Texture2D:
	var img := _image(chemin)
	if img == null: return null
	var r := Images._opaque(img)
	if r.size.x > 0: img = img.get_region(r)
	img.resize(maxi(1, int(float(hauteur) * img.get_width() / img.get_height())), hauteur, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

# Une texture qui se répète. Pour la pierre (« rangees »), on la coupe d'abord
# sur un nombre PAIR de rangées entières : l'image de ChatGPT en contient 4,7,
# et posée bord à bord, deux rangées se retrouvaient alignées, sans quinconce.
static func _tuile(chemin: String, cote: int, rangees: bool) -> Texture2D:
	var img := _image(chemin)
	if img == null: return null
	if rangees:
		var coupe := _rangees(img)
		if coupe.y > 0:
			img = img.get_region(Rect2i(0, coupe.z, img.get_width(), coupe.y - coupe.z))
			_cache[("c:" if Canal.cartoon else "") + "pierre_rangees"] = coupe.x
		cote = int(RANGEE * _cache.get(("c:" if Canal.cartoon else "") + "pierre_rangees", 4) * 2.0 * img.get_width() / img.get_height())
	img.resize(cote, maxi(1, int(float(cote) * img.get_height() / img.get_width())), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# Les joints horizontaux du mortier : les lignes nettement plus sombres que la
# moyenne. Renvoie (nombre de rangées gardées, hauteur de coupe) : la coupe
# tombe à la fin du joint qui clôt la dernière rangée paire ; (0, 0) si l'on ne
# trouve pas au moins deux joints.
static func _rangees(img: Image) -> Vector3i:
	var h := img.get_height()
	var w := img.get_width()
	var lum := PackedFloat32Array(); lum.resize(h)
	var moy := 0.0
	for y in h:
		var s := 0.0
		var n := 0
		for x in range(0, w, 6):
			var c := img.get_pixel(x, y)
			s += 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
			n += 1
		lum[y] = s / n
		moy += lum[y]
	moy /= h
	var joints := []       # la dernière ligne de chaque joint
	var dans := false
	for y in h:
		var sombre := lum[y] < moy * 0.86
		if dans and not sombre: joints.append(y)
		dans = sombre
	# Les pierres cernées de trait (style dessin animé, 13 octobre 2026) font
	# deux bandes sombres par joint, séparées par le liseré clair d'un bloc :
	# des joints à moins d'un vingtième de l'image n'en font qu'un. Et un joint
	# tout en haut de l'image ouvre la première rangée : on coupe à partir de
	# lui (comptée comme rangée, il doublait la taille des blocs).
	var fusion := []
	for y in joints:
		if not fusion.is_empty() and y - fusion[-1] < h / 20: fusion[-1] = y
		else: fusion.append(y)
	joints = fusion
	var debut := 0
	if not joints.is_empty() and joints[0] < h / 20:
		debut = joints[0]
		joints.remove_at(0)
	# un joint qui touche le bas de l'image est coupé : on ne le compte pas
	var k := joints.size()
	if k % 2 == 1: k -= 1
	if k < 2: return Vector3i.ZERO
	return Vector3i(k, joints[k - 1], debut)

# Une planche de plusieurs objets côte à côte, séparés par du vide : chacun
# devient une image, recadrée, à « hauteur » px de haut au plus.
static func _planche(chemin: String, hauteur: int) -> Array:
	var img := _image(chemin)
	if img == null: return []
	var w := img.get_width()
	var h := img.get_height()
	var plein := PackedByteArray(); plein.resize(w)
	for x in w:
		for y in range(0, h, 3):
			if img.get_pixel(x, y).a > 0.4:
				plein[x] = 1
				break
	var morceaux := []
	var x0 := -1
	for x in w + 1:
		var p := x < w and plein[x] == 1
		if p and x0 < 0: x0 = x
		if not p and x0 >= 0:
			if x - x0 > 12:
				var bout := img.get_region(Rect2i(x0, 0, x - x0, h))
				var r := Images._opaque(bout)
				if r.size.x > 0: bout = bout.get_region(r)
				var echelle := minf(1.0, float(hauteur) / bout.get_height())
				bout.resize(maxi(1, int(bout.get_width() * echelle)), maxi(1, int(bout.get_height() * echelle)), Image.INTERPOLATE_LANCZOS)
				morceaux.append(ImageTexture.create_from_image(bout))
			x0 = -1
	return morceaux

# Branche l'image sur un matériau de shader qui sait la prendre (pierre,
# terre, bois du vantail). Sans image, le matériau garde son dessin.
static func habiller(m: ShaderMaterial, quoi: String) -> void:
	match quoi:
		"pierre":
			var t := pierre()
			if t == null: return
			m.set_shader_parameter("avec_image", true)
			m.set_shader_parameter("image", t)
			m.set_shader_parameter("tuile", tuile_pierre())
		"terre":
			var t := terre()
			if t == null: return
			m.set_shader_parameter("avec_image", true)
			m.set_shader_parameter("image", t)
			m.set_shader_parameter("tuile", TERRE)
		"bois":
			var t := vantail()
			if t == null: return
			m.set_shader_parameter("avec_image", true)
			m.set_shader_parameter("image", t)
