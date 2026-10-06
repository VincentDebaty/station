class_name Images
extends RefCounted
# ------------------------------------------------------------------
# Les images livrées par ChatGPT font 1 200 à 2 200 px pour s'afficher en
# quelques centaines : réduites d'un coup à l'écran, elles crénèlent. On les
# réduit une fois, proprement (Lanczos), à la largeur dont on a besoin.
# ------------------------------------------------------------------

# Par défaut, l'image est d'abord recadrée sur ses pixels visibles : les images
# générées ont des marges transparentes (jusqu'à 262 px pour la corde, 16 % de
# la hauteur pour la planche), qui décalaient tout — les cordes s'arrêtaient
# dans le vide au-dessus du bois.
static func reduire(chemin: String, largeur: int, recadrer := true) -> Texture2D:
	if not ResourceLoader.exists(chemin): return null
	var img: Image = (load(chemin) as Texture2D).get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if recadrer:
		var r := img.get_used_rect()
		if r.size.x > 0 and r.size.y > 0: img = img.get_region(r)
	if img.get_width() > largeur:
		img.resize(largeur, int(float(largeur) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)
