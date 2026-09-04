extends RefCounted
## LE STYLE — la feuille de style du prototype (css/station.css), valeur pour
## valeur, pour les écrans Godot.
##
## Rien d'inventé ici : chaque couleur, rayon, épaisseur et taille de police
## vient de css/station.css ou de js/render.js, et le commentaire dit d'où.
## Les polices sont celles du système, dans la même pile que le web :
## « Segoe UI, system-ui, -apple-system » pour l'interface, « SF Mono, Menlo »
## pour l'horloge et les badges. Godot les charge par SystemFont.
##
## Les halos du web (`filter: drop-shadow`) deviennent une ombre de
## StyleBoxFlat (pour une boîte) ou une ligne large et translucide dessinée
## sous la ligne pleine (pour un trait).

# --- :root ------------------------------------------------------------------
const FOND := Color("#0E1420")
const PANNEAU := Color("#151d2e")
const VOIE_SOMBRE := Color("#323d4f")
const ROUGE := Color("#ef4444")
const VERT := Color("#4ade80")
const TEXTE := Color("#dbe2ee")
const MUET := Color("#7a8699")
const ACCENT := Color("#2dd4bf")
const ACCENT_CLAIR := Color("#7ee7d7")
const AMBRE := Color("#f5b23c")
const BORD := Color("#2a3550")
const BORD_QUAI := Color("#3b465c")
const FRET := Color("#8f98a8")
# le verre dépoli des chips du bandeau : rgba(21, 29, 46, .55)
const VERRE := Color(21.0 / 255, 29.0 / 255, 46.0 / 255, 0.55)
# le quai : dégradé #243049 (haut) → #161f30 (bas), platGrad
const QUAI_HAUT := Color("#243049")
const QUAI_BAS := Color("#161f30")
const QUAI_FERME := Color("#141b29")
const QUAI_FERME_BORD := Color("#2a3446")
const QUAI_ELIGIBLE_FOND := Color("#1b2436")
const BADGE_FOND := Color(14.0 / 255, 20.0 / 255, 32.0 / 255, 0.88)
const MASQUE := Color(10.0 / 255, 15.0 / 255, 25.0 / 255, 0.8)   # .board-mask
const ETIQUETTE_TRAIN := Color("#08141a")
const PIP_ETEINT := Color("#3b465c")
const VOILE := Color(10.0 / 255, 14.0 / 255, 24.0 / 255, 0.58)  # le projecteur du repère

# --- LA PALETTE DE PARCHEMIN (direction artistique du 4 septembre 2026) ------
# Vincent a fait produire une maquette du ruban dans un style de carte
# ferroviaire ancienne — parchemin, laiton, sarcelle profonde, encre brune —
# et l'a choisie contre l'esthétique du prototype, qu'il avait pourtant
# décidé de garder le 1er septembre. Elle ne remplace PAS la palette du
# poste d'aiguillage : la couleur d'une voie y est sa DESTINATION, contrat
# qui ne se rediscute pas. Elle habille ce qui l'entoure.
const PAPIER := Color("#efe3c8")          # le parchemin d'une fiche
const PAPIER_OMBRE := Color("#ddcfae")    # son creux, et la ligne de pliure
const ENCRE := Color("#33251a")           # ce qui s'écrit dessus
const ENCRE_MUET := Color("#7d6a52")
const BOIS := Color("#241a12")            # le cuir du bureau, derrière tout
const BOIS_CLAIR := Color("#33261a")
const LAITON := Color("#d9a441")          # les ferrures, les étoiles, le rail
const LAITON_CLAIR := Color("#f0c96b")
const SARCELLE := Color("#1d6b66")        # les plaques, le bouton d'appel
const SARCELLE_CLAIR := Color("#2dd4bf")
const TERRE := Color("#6d5a3f")           # la terre de la carte
const TERRE_OMBRE := Color("#5a4933")
const MER := Color("#2b2118")             # l'eau, plus sombre que la terre


## Une fiche de parchemin : fond clair, liseré de laiton, ombre chaude.
static func parchemin(rayon: float = 10.0, k: float = 1.0) -> StyleBoxFlat:
	var b := boite(PAPIER, Color(ENCRE, 0.45), rayon * k, max(1.0, k), 10.0 * k, Color(0, 0, 0, 0.45))
	return b


## Une plaque de laiton sur bois : les pastilles de la barre, les cartouches.
static func plaque(fond: Color, bord: Color, rayon: float = 8.0, k: float = 1.0) -> StyleBoxFlat:
	return boite(fond, bord, rayon * k, max(1.0, k), 6.0 * k, Color(0, 0, 0, 0.35))


# --- LES DEUX FACTEURS D'ÉCHELLE ---------------------------------------------
# LE FACTEUR TACTILE, celui du prototype (js/render.js, UIK) : sur un pointeur
# grossier, tout ce qu'on touche et tout ce qu'on lit sur le plan grossit d'une
# moitié — hauteur des caisses, zones de clic, badges, libellés de portail,
# signal d'arrêt. La LONGUEUR d'une voiture, elle, ne bouge jamais : elle tient
# à la physique du gril (CAR_SPACING), et l'étirer ferait se chevaucher les
# convois. C'est la valeur que Vincent a validée sur son iPhone avec le
# prototype web ; on la reprend telle quelle.
static var UIK := 1.0

# LE FACTEUR DU BANDEAU, qui n'existait pas sur le web — et c'est justement
# pour cela qu'il faut l'écrire ici. Le prototype tient son bandeau en PIXELS
# CSS, qui valent un point d'écran sur l'appareil : une chip de 34 px fait
# 34 points sur un iPhone comme sur un Mac. Ici le bandeau vit dans le viewport
# de 1400 unités, étiré à la taille de l'écran : sur un téléphone, la même chip
# tomberait à trois millimètres. On garde donc au bandeau sa TAILLE PHYSIQUE —
# celle qu'il a au bureau, mesurée à 127 unités par pouce le 3 septembre 2026.
const UNITES_PAR_POUCE_BUREAU := 127.5
const PLANCHER_TACTILE := 1.9
static var HUD_K := 1.0
## Ce que la calibration a vu, pour la ligne de mise au point : sur un
## téléphone, c'est le seul journal qu'on puisse lire.
static var mesure := ""

## LA ZONE SÛRE — les coins arrondis, l'île interactive, la barre d'accueil.
## Le prototype la connaît depuis toujours (css/station.css, --safe-l/r/t/b
## posées sur `env(safe-area-inset-*)`) et je ne l'avais pas transposée : sur
## l'iPhone 16 de Vincent, une partie des boutons et des infos passait sous
## le bord. Elle vaut zéro partout ailleurs, et le bureau ne bouge pas.
static var marges := {"gauche": 0.0, "droite": 0.0, "haut": 0.0, "bas": 0.0}


## À appeler une fois l'écran connu. Sans elle, les deux facteurs valent 1 et
## le jeu s'affiche comme au bureau — ce qui est le bon repli.
## STATION_TACTILE=1 force le régime du téléphone au bureau : c'est le seul
## moyen de VOIR la passe tactile sans appareil, l'exportateur iOS de Godot 4.7
## ne produisant que l'architecture de l'appareil (pas de simulateur).
## STATION_TACTILE=0 force l'inverse, pour comparer.
static func calibrer(viewport: Viewport) -> void:
	var force := OS.get_environment("STATION_TACTILE")
	var tactile: bool = force == "1" if force != "" else DisplayServer.is_touchscreen_available()
	UIK = 1.5 if tactile else 1.0
	if force == "1":
		# Au bureau, la fenêtre est déjà à l'échelle du viewport : sans cela le
		# bandeau ne bougerait pas, et l'essai ne montrerait que la moitié de la
		# passe. 1,93 est ce que la mesure donne sur un iPhone 17 en paysage.
		HUD_K = PLANCHER_TACTILE
		_mesurer_marges(viewport)
		# de quoi voir au bureau ce que le téléphone réserve à ses bords
		if marges["gauche"] + marges["droite"] == 0.0:
			marges = {"gauche": 100.0, "droite": 100.0, "haut": 0.0, "bas": 40.0}
		mesure = "régime tactile forcé · HUD_K %.2f · marges %s" % [HUD_K, marges]
		return
	var dpi := DisplayServer.screen_get_dpi()
	var large := float(DisplayServer.window_get_size().x)
	var unites := viewport.get_visible_rect().size.x
	if dpi <= 0 or large <= 0 or unites <= 0:
		HUD_K = max(PLANCHER_TACTILE, UIK) if UIK > 1.0 else 1.0
		_mesurer_marges(viewport)
		mesure = "mesure impossible · HUD_K %.2f" % HUD_K
		return
	# window_get_size() est en points sur macOS et sur iOS ; les pixels
	# physiques en découlent par l'échelle de l'écran, et le pouce par le dpi.
	var pouces := large * DisplayServer.screen_get_max_scale() / dpi
	if pouces <= 0.0:
		HUD_K = max(PLANCHER_TACTILE, UIK) if UIK > 1.0 else 1.0
		_mesurer_marges(viewport)
		mesure = "pouces inconnus · HUD_K %.2f" % HUD_K
		return
	var calcule := clampf((unites / pouces) / UNITES_PAR_POUCE_BUREAU, 1.0, 3.0)
	# LE CALCUL NE SUFFIT PAS, ET C'EST MESURÉ. `window_get_size()` ne rend pas
	# la même unité d'une plateforme à l'autre — des points sur macOS, autre
	# chose sur iOS — si bien que le facteur retombait à 1 sur l'iPhone et que
	# tout le bandeau y paraissait minuscule (Vincent, 3 septembre 2026). Un
	# écran tactile a de toute façon besoin d'un bandeau plus grand qu'un
	# bureau : on pose donc un PLANCHER, et le calcul ne peut que le relever.
	# 1,9 est le rapport mesuré sur un iPhone en paysage entre les unités du
	# viewport (1652) et les points de l'écran (874) — de quoi rendre à une
	# chip de 34 unités les 34 points qu'elle a sur le web.
	HUD_K = max(PLANCHER_TACTILE, calcule) if UIK > 1.0 else 1.0
	_mesurer_marges(viewport)
	mesure = "tactile %s · fenêtre %s · échelle %.1f · dpi %d · écran %s · viewport %s · calcul %.2f · HUD_K %.2f · marges %s" % [
		DisplayServer.is_touchscreen_available(), DisplayServer.window_get_size(),
		DisplayServer.screen_get_max_scale(), dpi, DisplayServer.screen_get_size(),
		viewport.get_visible_rect().size, calcule, HUD_K, marges]


## Les retraits de la zone sûre, convertis en unités du viewport. Les deux
## grandeurs viennent du même DisplayServer, donc du même espace : le rapport
## est fiable là où une taille absolue ne l'est pas.
static func _mesurer_marges(viewport: Viewport) -> void:
	marges = {"gauche": 0.0, "droite": 0.0, "haut": 0.0, "bas": 0.0}
	# SEULEMENT SUR MOBILE. `get_display_safe_area()` rend une zone en
	# coordonnées d'ÉCRAN, pas relative à la fenêtre : sur macOS elle vaut le
	# bureau utile, et prise pour un retrait elle donnait 3 288 unités de marge
	# à gauche — l'écran du ruban en est devenu tout noir (mesuré le
	# 3 septembre 2026). Sur un téléphone la fenêtre EST l'écran, et la
	# comparaison a un sens ; ailleurs, il n'y a pas d'encoche à contourner.
	if not OS.has_feature("mobile"):
		return
	var ecran := Vector2(DisplayServer.screen_get_size())
	var vp := viewport.get_visible_rect().size
	if ecran.x <= 0.0 or ecran.y <= 0.0:
		return
	var sure := DisplayServer.get_display_safe_area()
	if sure.size.x <= 0 or sure.size.y <= 0:
		return
	var k := Vector2(vp.x / ecran.x, vp.y / ecran.y)
	marges = {
		"gauche": max(0.0, float(sure.position.x)) * k.x,
		"haut": max(0.0, float(sure.position.y)) * k.y,
		"droite": max(0.0, ecran.x - float(sure.position.x + sure.size.x)) * k.x,
		"bas": max(0.0, ecran.y - float(sure.position.y + sure.size.y)) * k.y,
	}


# --- les polices, en cache --------------------------------------------------------
static var _sans: Dictionary = {}
static var _mono: Dictionary = {}


## LES POLICES DE LA DIRECTION ARTISTIQUE (4 septembre 2026). Livrées avec
## l'application — sur iOS une police système ne se redistribue pas — et sous
## licence SIL Open Font (voir jeu/polices/LISEZ-MOI.md). Toutes deux sont
## VARIABLES : un seul fichier porte toutes les graisses, et FontVariation en
## tire le gras sans charger un second fichier.
const FICHIER_TITRE := "res://jeu/polices/Cinzel.ttf"
const FICHIER_TEXTE := "res://jeu/polices/EBGaramond.ttf"
static var _titre: Dictionary = {}


## LE TEXTE COURANT : EB Garamond. C'est elle qui remplace la police système
## partout où le prototype écrivait en sans-serif — le nom de `sans` reste
## parce que tout l'appelle, mais ce n'en est plus une.
static func sans(graisse: int = 400) -> Font:
	if not _sans.has(graisse):
		_sans[graisse] = _charger(FICHIER_TEXTE, graisse)
	return _sans[graisse]


## LES TITRES ET LES PETITES CAPITALES : Cinzel, une capitale romaine
## lapidaire. C'est elle qui donne à l'écran son air de gravure.
static func titre(graisse: int = 600) -> Font:
	if not _titre.has(graisse):
		_titre[graisse] = _charger(FICHIER_TITRE, graisse)
	return _titre[graisse]


static func _charger(chemin: String, graisse: int) -> Font:
	var base: FontFile = load(chemin) if ResourceLoader.exists(chemin) else null
	if base == null:
		# repli : la police système, pour que rien ne disparaisse si un fichier
		# manque (un export mal filtré, par exemple).
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Georgia", "Times New Roman", "Serif"])
		sf.font_weight = graisse
		return sf
	base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {&"wght": graisse}
	return v


## L'horloge et les badges : ui-monospace, « SF Mono », Menlo, monospace.
static func mono(graisse: int = 600) -> Font:
	if not _mono.has(graisse):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["SF Mono", "Menlo", "Consolas", "DejaVu Sans Mono", "Courier New"])
		f.font_weight = graisse
		_mono[graisse] = f
	return _mono[graisse]


# --- les boîtes ------------------------------------------------------------------------
## Une boîte à coins ronds, avec son liseré et, si on veut, son ombre (le halo).
static func boite(fond: Color, bord: Color, rayon: float, larg_bord: float = 1.0,
		ombre: float = 0.0, couleur_ombre: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(int(round(larg_bord)))
	s.set_corner_radius_all(int(round(rayon)))
	s.anti_aliasing = true
	if ombre > 0.0:
		s.shadow_size = int(round(ombre))
		s.shadow_color = couleur_ombre
		s.shadow_offset = Vector2.ZERO
	return s


## Le contour d'un rectangle à coins ronds, en points (pour un dégradé, un
## pointillé, ou un cerne).
static func rect_arrondi(r: Rect2, rayon: float, pas: int = 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ra: float = min(rayon, r.size.x / 2, r.size.y / 2)
	var coins := [
		[Vector2(r.end.x - ra, r.position.y + ra), -PI / 2],
		[Vector2(r.end.x - ra, r.end.y - ra), 0.0],
		[Vector2(r.position.x + ra, r.end.y - ra), PI / 2],
		[Vector2(r.position.x + ra, r.position.y + ra), PI],
	]
	for c in coins:
		var centre: Vector2 = c[0]
		var a0: float = c[1]
		for i in range(pas + 1):
			var a: float = a0 + (PI / 2) * float(i) / float(pas)
			pts.append(centre + Vector2(cos(a), sin(a)) * ra)
	return pts


## Un contour fermé en pointillés (le quai éligible, le quai promis), avec un
## décalage pour faire défiler les tirets.
static func pointille(canvas: CanvasItem, pts: PackedVector2Array, col: Color, larg: float,
		tiret: float, trou: float, decalage: float = 0.0, ferme: bool = true) -> void:
	var n := pts.size()
	if n < 2:
		return
	# les abscisses cumulées du contour (fermé : le dernier segment revient au premier point)
	var segments := n if ferme else n - 1
	var cum := PackedFloat64Array()
	cum.append(0.0)
	for i in range(segments):
		cum.append(cum[i] + pts[i].distance_to(pts[(i + 1) % n]))
	var total: float = cum[segments]
	if total <= 0.0:
		return
	var periode := tiret + trou
	var s: float = -fmod(decalage, periode)
	while s < total:
		var a: float = max(0.0, s)
		var b: float = min(total, s + tiret)
		if b > a:
			_trait_sur(canvas, pts, cum, segments, a, b, col, larg)
		s += periode


## Le tronçon [a, b] d'un contour fermé, en abscisse curviligne.
static func _trait_sur(canvas: CanvasItem, pts: PackedVector2Array, cum: PackedFloat64Array,
		segments: int, a: float, b: float, col: Color, larg: float) -> void:
	# `segments` et non pts.size() : sur un tracé OUVERT (un itinéraire), il y a
	# un segment de moins que de points, et cum s'arrête là.
	var n := pts.size()
	var i := 0
	while i < segments and cum[i + 1] < a:
		i += 1
	var pos := a
	while i < segments and pos < b:
		var fin: float = min(b, cum[i + 1])
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var l: float = cum[i + 1] - cum[i]
		if l > 0.0:
			var u0: float = (pos - cum[i]) / l
			var u1: float = (fin - cum[i]) / l
			canvas.draw_line(p0.lerp(p1, u0), p0.lerp(p1, u1), col, larg, true)
		pos = fin
		i += 1


## Une ligne pleine posée sur son halo (drop-shadow du web).
static func trait_halo(canvas: CanvasItem, pts: PackedVector2Array, col: Color, larg: float, halo: float) -> void:
	if pts.size() < 2:
		return
	if halo > 0.0:
		canvas.draw_polyline(pts, Color(col, 0.22), larg + halo * 2, true)
		canvas.draw_polyline(pts, Color(col, 0.35), larg + halo, true)
	canvas.draw_polyline(pts, col, larg, true)


## draw_string avec interlettrage (le `letter-spacing` du web, que Godot n'a
## pas) : chaque caractère est posé à la main.
static func texte_espace(canvas: CanvasItem, police: Font, taille: int, pos: Vector2,
		texte: String, col: Color, espace: float) -> void:
	var x := pos.x
	for c in texte:
		canvas.draw_string(police, Vector2(x, pos.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, col)
		x += police.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + espace


static func largeur_espacee(police: Font, taille: int, texte: String, espace: float) -> float:
	var w := 0.0
	for c in texte:
		w += police.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + espace
	return max(0.0, w - espace)


## Un texte centré sur un point (text-anchor: middle ; dominant-baseline: central).
static func texte_centre(canvas: CanvasItem, police: Font, taille: int, centre: Vector2, texte: String, col: Color,
		contour: float = 0.0, col_contour: Color = FOND) -> void:
	var dim := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille)
	var asc := police.get_ascent(taille)
	var desc := police.get_descent(taille)
	var pos := Vector2(centre.x - dim.x / 2, centre.y + (asc - desc) / 2)
	if contour > 0.0:
		canvas.draw_string_outline(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, int(round(contour)), col_contour)
	canvas.draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, col)


## Un bouton du prototype (.btn / .card .btn.primary), stylé.
static func bouton(texte: String, principal: bool = false, taille: int = 15, k: float = 1.0) -> Button:
	var b := Button.new()
	b.text = texte
	# LE BOUTON EST GRAVÉ : Cinzel, en capitales, comme les plaques d'une gare.
	b.text = texte.to_upper()
	b.add_theme_font_override("font", titre(700 if principal else 600))
	b.add_theme_font_size_override("font_size", int(round(taille * k)))
	b.add_theme_constant_override("h_separation", int(round(2 * k)))
	var fond := ACCENT if principal else PANNEAU
	var s := boite(fond, ACCENT if principal else BORD, 10 * k, max(1.0, k))
	s.content_margin_left = (22 if principal else 14) * k
	s.content_margin_right = s.content_margin_left
	s.content_margin_top = 8 * k
	s.content_margin_bottom = 8 * k
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = Color("#3ee0cc") if principal else PANNEAU
	h.border_color = Color("#3ee0cc") if principal else Color("#40507a")
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("#0b1a1f") if principal else TEXTE)
	b.add_theme_color_override("font_hover_color", Color("#0b1a1f") if principal else TEXTE)
	b.add_theme_color_override("font_pressed_color", Color("#0b1a1f") if principal else TEXTE)
	return b
