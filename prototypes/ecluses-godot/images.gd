class_name Images
extends RefCounted
# ------------------------------------------------------------------
# Les images livrées par ChatGPT font 1 200 à 2 200 px pour s'afficher en
# quelques centaines : réduites d'un coup à l'écran, elles crénèlent. On les
# réduit une fois, proprement (Lanczos), à la largeur dont on a besoin.
# ------------------------------------------------------------------

# Par défaut, l'image est d'abord recadrée sur ses pixels FRANCHEMENT opaques
# (alpha > 0,4). Les images générées ont des marges transparentes (jusqu'à
# 262 px pour la corde), et get_used_rect ne suffit pas : il garde aussi le
# voile d'alpha presque invisible que ChatGPT laisse autour (quelques %). La
# planche gardait ainsi 136 px de vide au-dessus du bois, et les cordes
# s'arrêtaient dans le vide.
static func reduire(chemin: String, largeur: int, recadrer := true) -> Texture2D:
	if not ResourceLoader.exists(chemin): return null
	var img: Image = (load(chemin) as Texture2D).get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if recadrer:
		var r := _opaque(img)
		if r.size.x > 0 and r.size.y > 0: img = img.get_region(r)
	if img.get_width() > largeur:
		img.resize(largeur, int(float(largeur) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

# Le rectangle des pixels d'alpha > 0,4, cherché sur une copie réduite au
# quart (rapide), puis rapporté à la taille réelle avec une marge d'un pas.
static func _opaque(img: Image) -> Rect2i:
	var petit := img.duplicate() as Image
	var f := 4
	petit.resize(maxi(1, img.get_width() / f), maxi(1, img.get_height() / f), Image.INTERPOLATE_BILINEAR)
	var x0 := petit.get_width(); var y0 := petit.get_height(); var x1 := -1; var y1 := -1
	for y in petit.get_height():
		for x in petit.get_width():
			if petit.get_pixel(x, y).a > 0.4:
				x0 = mini(x0, x); y0 = mini(y0, y); x1 = maxi(x1, x); y1 = maxi(y1, y)
	if x1 < 0: return Rect2i()
	var r := Rect2i((x0 - 1) * f, (y0 - 1) * f, (x1 - x0 + 3) * f, (y1 - y0 + 3) * f)
	return r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))

# --- Les pictogrammes des médaillons de bois ---------------------------------
# Sur l'image d'exemple de Vincent, les pictogrammes des boutons ronds sont
# crème, cerclés de brun foncé. Les icônes livrées sont peintes (flèche orange,
# flèche crème cerclée de vert) : on n'en garde que la SILHOUETTE, repeinte —
# l'intérieur crème, un liseré brun de « bord » pixels autour. Le liseré vient
# d'une érosion de l'alpha (minimum glissant, en deux passes séparées).
const PICTO_CREME := Color("#fff3dc")
const PICTO_BRUN := Color("#3e210d")

static func pictogramme(chemin: String, cote: int, bord := 5) -> Texture2D:
	if not ResourceLoader.exists(chemin): return null
	var img: Image = (load(chemin) as Texture2D).get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var r := _opaque(img)
	if r.size.x > 0: img = img.get_region(r)
	# carré, avec la place du liseré tout autour
	var plus := img.get_width() if img.get_width() > img.get_height() else img.get_height()
	var interieur := cote - 2 * (bord + 1)
	img.resize(int(float(interieur) * img.get_width() / plus), int(float(interieur) * img.get_height() / plus), Image.INTERPOLATE_LANCZOS)
	var w := img.get_width(); var h := img.get_height()
	var a := PackedFloat32Array(); a.resize(cote * cote)
	var ox := (cote - w) / 2; var oy := (cote - h) / 2
	for y in h:
		for x in w:
			a[(y + oy) * cote + x + ox] = img.get_pixel(x, y).a
	return _peindre(a, cote, bord)

# L'engrenage des réglages, qui n'a pas d'image : dessiné par sa distance au
# centre — huit dents larges, un moyeu percé. Le cœur crème est la même forme
# en retrait de « bord » (l'érosion rongerait les dents, plus fines que deux
# liserés).
static func engrenage(cote: int, bord := 5) -> Texture2D:
	var a := PackedFloat32Array(); a.resize(cote * cote)
	var e := PackedFloat32Array(); e.resize(cote * cote)
	var c := cote * 0.5
	var R := c - 1.0
	for y in cote:
		for x in cote:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c)
			var l := d.length()
			var dent := clampf(cos(d.angle() * 8.0) * 2.2 + 0.4, -1.0, 1.0) * 0.5 + 0.5
			var rayon := lerpf(R * 0.72, R, dent)
			var trou := R * 0.24
			a[y * cote + x] = clampf(rayon - l + 0.5, 0.0, 1.0) * clampf(l - trou + 0.5, 0.0, 1.0)
			e[y * cote + x] = clampf(rayon - bord - l + 0.5, 0.0, 1.0) * clampf(l - trou - bord + 0.5, 0.0, 1.0)
	return _composer(a, e, cote)

# Silhouette (alpha) → crème au cœur, brun sur le liseré ; le liseré est
# l'écart entre la silhouette et sa version rongée de « bord » pixels.
static func _peindre(a: PackedFloat32Array, cote: int, bord: int) -> Texture2D:
	return _composer(a, _eroder(_eroder(a, cote, bord, true), cote, bord, false), cote)

# alpha « a », brun partout, crème là où « e »
static func _composer(a: PackedFloat32Array, e: PackedFloat32Array, cote: int) -> Texture2D:
	var out := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	for y in cote:
		for x in cote:
			var i := y * cote + x
			out.set_pixel(x, y, Color(PICTO_BRUN.lerp(PICTO_CREME, e[i]), a[i]))
	return ImageTexture.create_from_image(out)

static func _eroder(a: PackedFloat32Array, cote: int, r: int, horizontal: bool) -> PackedFloat32Array:
	var o := PackedFloat32Array(); o.resize(cote * cote)
	for y in cote:
		for x in cote:
			var m := 1.0
			for k in range(-r, r + 1):
				var xx := x + k if horizontal else x
				var yy := y if horizontal else y + k
				if xx < 0 or yy < 0 or xx >= cote or yy >= cote: m = 0.0; break
				m = minf(m, a[yy * cote + xx])
			o[y * cote + x] = m
	return o
