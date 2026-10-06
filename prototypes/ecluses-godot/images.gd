class_name Images
extends RefCounted
# ------------------------------------------------------------------
# Les images livrées par ChatGPT font 1 200 à 2 200 px pour s'afficher en
# quelques centaines : réduites d'un coup à l'écran, elles crénèlent. On les
# réduit une fois, proprement (Lanczos), à la largeur dont on a besoin.
# ------------------------------------------------------------------

static func reduire(chemin: String, largeur: int) -> Texture2D:
	if not ResourceLoader.exists(chemin): return null
	var img: Image = (load(chemin) as Texture2D).get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() > largeur:
		img.resize(largeur, int(float(largeur) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)
