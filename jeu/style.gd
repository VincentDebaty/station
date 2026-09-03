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

# --- les polices, en cache --------------------------------------------------------
static var _sans: Dictionary = {}
static var _mono: Dictionary = {}


## L'interface : « Segoe UI », system-ui, -apple-system, sans-serif.
static func sans(graisse: int = 400) -> Font:
	if not _sans.has(graisse):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["SF Pro Text", "Helvetica Neue", "Segoe UI", "Inter", "Roboto", "Arial"])
		f.font_weight = graisse
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_sans[graisse] = f
	return _sans[graisse]


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
static func bouton(texte: String, principal: bool = false, taille: int = 15) -> Button:
	var b := Button.new()
	b.text = texte
	b.add_theme_font_override("font", sans(600 if principal else 400))
	b.add_theme_font_size_override("font_size", taille)
	var fond := ACCENT if principal else PANNEAU
	var s := boite(fond, ACCENT if principal else BORD, 10, 1)
	s.content_margin_left = 22 if principal else 14
	s.content_margin_right = s.content_margin_left
	s.content_margin_top = 8
	s.content_margin_bottom = 8
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
