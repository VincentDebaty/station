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
