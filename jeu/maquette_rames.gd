extends Node2D
## LE BANC D'ESSAI DES RAMES — quatre dessins du même convoi, côte à côte.
##
##   godot --path . res://jeu/maquette_rames.tscn
##   STATION_CAPTURE=/tmp/rames.png godot --path . res://jeu/maquette_rames.tscn
##
## Chercher dans une partie l'instant où juger un détail coûte cher et ne
## garantit rien : deux captures ne montrent jamais le même convoi au même
## endroit. Ce banc pose le MÊME convoi — quatre voitures sur la même courbe,
## à la même échelle — et n'en change que le dessin. C'est ce qui permet de
## comparer, et de trancher.
##
## Il ne sert QU'À CELA : rien ici n'est appelé par le jeu, et le fichier
## partira le jour où le dessin sera arrêté.

const Sty := preload("res://jeu/style.gd")
const Cap := preload("res://jeu/capture.gd")
const Geo := preload("res://jeu/geometrie.gd")

const NOMS := ["I — la rame actuelle", "II — la gravure pleine",
	"III — la gravure à caisses", "IV — la trame tissée", "V — la planche gravée"]
## LES TROIS TRANCHES DE LA PLANCHE, en fractions de sa largeur. Mesurées sur
## `jeu/illustrations/wagon.png` : les nervures y sont espacées de 44 points,
## la tranche centrale en prend DEUX et commence à mi-chemin entre deux d'entre
## elles, faute de quoi la nervure du raccord compterait double.
const TR_NEZ := Vector2(0.0, 0.116)        # la ferrure de tête
# La tranche centrale ÉVITE LE MILIEU DE LA PLANCHE : le dessin y porte une
# valve ronde, unique sur la voiture, qui se répétait à chaque section — et
# laissait au centre de la rame une marque que rien ne justifiait.
const TR_MILIEU := Vector2(0.698, 0.836)   # deux nervures, raccordables
const TR_QUEUE := Vector2(0.884, 1.0)      # la ferrure de queue
## UNE CASE, UN DESSIN. La rame se partage en autant de cases qu'elle a de
## voitures : la machine dans la première, une section de voiture dans chacune
## des autres, la ferrure de queue avec la dernière. Un convoi de cinq montre
## donc UNE machine et QUATRE voitures — ce qui n'était pas le cas quand la
## machine était posée à sa proportion naturelle : elle mangeait deux cases
## trois quarts, et il ne restait que trois sections pour quatre voitures.
## La case fait 35 sur 30, la planche de machine est découpée d'autant.
const TR_LOCO := Vector2(0.0, 0.352)       # cheminée, boîte à fumée, premier dôme
## Les teintes de destination du jeu, pour juger sur de vraies couleurs.
const TEINTES := ["#e8875a", "#5b8def", "#3fa87a", "#c084fc", "#d97757"]

var hachure: Texture2D
var planche: Texture2D
var machine: Texture2D
var grain: NoiseTexture2D


func _ready() -> void:
	Sty.calibrer(get_viewport())
	RenderingServer.set_default_clear_color(Sty.POSTE_FOND)
	hachure = _tisser_hachure()
	planche = load("res://jeu/illustrations/wagon.png") if ResourceLoader.exists("res://jeu/illustrations/wagon.png") else null
	machine = load("res://jeu/illustrations/loco.png") if ResourceLoader.exists("res://jeu/illustrations/loco.png") else null
	var g := FastNoiseLite.new()
	g.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	g.frequency = 0.35
	g.fractal_octaves = 4
	grain = NoiseTexture2D.new()
	grain.width = 256
	grain.height = 256
	grain.seamless = true
	grain.noise = g
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	await get_tree().process_frame
	queue_redraw()
	Cap.eventuelle(self)


## UNE HACHURE DE GRAVURE, TISSÉE EN MÉMOIRE. Des traits parallèles à 45°, un
## tous les six pixels : c'est la trame la plus simple d'une taille-douce, et
## elle se répète sans couture puisque le pas divise le côté. Une planche
## dessinée à la main donnerait un grain plus vivant — c'est exactement ce
## qu'un asset généré apporterait, et rien d'autre.
func _tisser_hachure() -> Texture2D:
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			if (x + y) % 6 == 0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.26))
			elif (x + y) % 6 == 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0.08))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	var e := get_viewport_rect().size
	if grain != null and grain.get_width() > 0:
		draw_texture_rect(grain, Rect2(Vector2.ZERO, e), true, Color(0, 0, 0, 0.13))
	# LA MISE EN PAGE SUIT LE VIEWPORT, pas la fenêtre : le projet étire un
	# viewport de 1400 × 760, et mes coordonnées en 2000 de large envoyaient la
	# quatrième rame sous le bord bas.
	var k := 2.2
	var titre := Sty.titre(600)
	var pas: float = (e.y - 50.0) / 5.0
	for v in 5:
		var y: float = 70.0 + float(v) * pas
		draw_string(titre, Vector2(46, y - pas * 0.34), NOMS[v], HORIZONTAL_ALIGNMENT_LEFT, -1,
			19, Color(Sty.PAPIER, 0.72))
		var col := Color(TEINTES[v])
		var axe := _courbe(Vector2(230, y), k)
		match v:
			0: _rame_actuelle(axe, col, k)
			1: _rame_gravee(axe, col, k, false)
			2: _rame_caisses(axe, col, k)
			3: _rame_gravee(axe, col, k, true)
			4: _rame_planche(axe, col, k)
		# et la même, à la TAILLE RÉELLE du jeu, en bout de ligne : c'est elle
		# qui décide, pas l'agrandissement
		var petit := _courbe(Vector2(e.x - 260, y), 1.0)
		match v:
			0: _rame_actuelle(petit, col, 1.0)
			1: _rame_gravee(petit, col, 1.0, false)
			2: _rame_caisses(petit, col, 1.0)
			3: _rame_gravee(petit, col, 1.0, true)
			4: _rame_planche(petit, col, 1.0)


## La même courbe pour les quatre : quatre voitures sur un S doux.
func _courbe(depart: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 5:
		var t := float(i) / 4.0
		out.append(depart + Vector2(t * Geo.CAR_SPACING * 4.0 * k,
			sin(t * PI) * 11.0 * k))
	return out


# ------------------------------------------------------------------
# I — la rame actuelle
# ------------------------------------------------------------------
func _rame_actuelle(axe: PackedVector2Array, col: Color, k: float) -> void:
	var h: float = Geo.CAR_H * 1.5 * k
	draw_polyline(axe, Color(col, 0.30), h + 7.0 * k, true)
	draw_polyline(axe, Color(col, 0.85), h + 2.8 * k, true)
	draw_circle(axe[0], h / 2.0 + 1.4 * k, Color(col, 0.85))
	draw_circle(axe[axe.size() - 1], h / 2.0 + 1.4 * k, Color(col, 0.85))
	draw_polyline(axe, col, h, true)
	draw_circle(axe[axe.size() - 1], h / 2.0, col)
	draw_circle(axe[0], h / 2.0, col)
	draw_polyline(axe, Color(col.lightened(0.34), 0.75), h * 0.46, true)
	var bloc := Color(col.darkened(0.50), 0.34)
	for i in axe.size():
		var u := _tangente(axe, i)
		draw_line(axe[i] - u * 4.5 * k, axe[i] + u * 4.5 * k, bloc, h * 0.28, true)
	for i in range(1, axe.size()):
		var m: Vector2 = (axe[i - 1] + axe[i]) / 2.0
		var nrm := _normale(axe, i)
		draw_line(m - nrm * h * 0.5, m + nrm * h * 0.5, Color(0, 0, 0, 0.26), 1.8 * k, true)


# ------------------------------------------------------------------
# II & IV — la gravure : un contour d'encre, un lavis, des tailles
# ------------------------------------------------------------------
## LE VOCABULAIRE D'UNE GRAVURE COLORÉE. Une taille-douce mise en couleur, ce
## n'est pas une masse teintée : c'est un TRAIT D'ENCRE qui décrit la forme, et
## un lavis posé dedans, plus pâle et légèrement débordant. Le volume ne vient
## pas d'un dégradé mais de la DENSITÉ DES TAILLES — serrées là où la forme
## fuit, absentes là où la lumière tombe.
func _rame_gravee(axe: PackedVector2Array, col: Color, k: float, texture: bool) -> void:
	var h: float = Geo.CAR_H * 1.5 * k
	var encre := Color(0.10, 0.07, 0.05, 0.92)
	var lavis := col.lerp(Sty.PAPIER, 0.18)
	var corps := _corps(axe, h, k)
	# LE LAVIS D'ABORD, LA TRAME PAR-DESSUS. Peindre le polygone AVEC la texture
	# ne marche pas : là où la trame est transparente, le corps l'est aussi, et
	# il ne reste que les traits — la rame virait au noir. Une trame est un
	# ENCRAGE posé sur une couleur, pas la couleur elle-même.
	draw_colored_polygon(corps, lavis)
	if texture and hachure != null:
		draw_colored_polygon(corps, Color.WHITE, _uv(corps, 26.0 * k), hachure)
	# LES TAILLES SONT LONGITUDINALES, ET C'EST TOUT LE POINT. Au premier essai
	# je les avais posées EN TRAVERS : elles faisaient des traverses de voie sur
	# le dos du train, pas un volume. Un graveur arrondit une forme par des
	# traits qui SUIVENT sa génératrice, serrés là où elle fuit, absents là où
	# la lumière tombe — ici, une ligne de faîte claire et des tailles qui
	# s'épaississent vers les flancs.
	if not texture:
		for cote in [-1.0, 1.0]:
			for rang in 3:
				var d: float = (0.20 + 0.11 * float(rang)) * h * cote
				var rang_pts := PackedVector2Array()
				for i in axe.size():
					rang_pts.append(axe[i] + _normale(axe, i) * d)
				draw_polyline(rang_pts, Color(encre, 0.16 + 0.14 * float(rang)),
					(0.9 + 0.5 * float(rang)) * k, true)
	# le filet de toiture, deux traits d'encre qui suivent la rame
	for cote in [-1.0, 1.0]:
		var f := PackedVector2Array()
		for i in axe.size():
			f.append(axe[i] + _normale(axe, i) * 0.24 * h * cote)
		draw_polyline(f, Color(encre, 0.55), 1.4 * k, true)
	# les articulations
	for i in range(1, axe.size()):
		var m: Vector2 = (axe[i - 1] + axe[i]) / 2.0
		var nrm := _normale(axe, i)
		draw_line(m - nrm * h * 0.5, m + nrm * h * 0.5, Color(encre, 0.75), 1.6 * k, true)
	# LE CONTOUR, EN DERNIER ET D'UN SEUL TRAIT : dans une gravure, c'est lui
	# qui tient tout le dessin.
	var ferme := corps.duplicate()
	ferme.append(corps[0])
	draw_polyline(ferme, encre, 2.4 * k, true)


## LE CORPS, EN POLYGONE. Un boudin d'épaisseur constante ne peut pas avoir de
## nez ; un polygone construit en décalant l'axe de part et d'autre le peut, et
## c'est aussi ce qui permet de le remplir d'une TEXTURE dont les UV suivent la
## longueur de la rame.
func _corps(axe: PackedVector2Array, h: float, k: float) -> PackedVector2Array:
	var n := axe.size()
	var gauche := PackedVector2Array()
	var droite := PackedVector2Array()
	for i in n:
		# le nez s'effile sur la première demi-voiture
		var t: float = float(i) / float(max(1, n - 1))
		var demi: float = h / 2.0 * (0.62 + 0.38 * clampf(t * 4.0, 0.0, 1.0))
		var nrm := _normale(axe, i)
		gauche.append(axe[i] - nrm * demi)
		droite.append(axe[i] + nrm * demi)
	var out := PackedVector2Array()
	# le bout du nez, arrondi en trois points
	var u0 := _tangente(axe, 0)
	var n0 := _normale(axe, 0)
	out.append(axe[0] - n0 * h * 0.31 - u0 * h * 0.06)
	out.append(axe[0] - u0 * h * 0.20)
	out.append(axe[0] + n0 * h * 0.31 - u0 * h * 0.06)
	for i in range(0, n):
		out.append(droite[i])
	var un := _tangente(axe, n - 1)
	var nn := _normale(axe, n - 1)
	out.append(axe[n - 1] + nn * h * 0.46 + un * h * 0.20)
	out.append(axe[n - 1] - nn * h * 0.46 + un * h * 0.20)
	for i in range(n - 1, -1, -1):
		out.append(gauche[i])
	return out


## LES UV : la longueur d'arc en x, la largeur en y. La trame suit donc la
## rame quand elle tourne, au lieu de glisser dessous.
func _uv(pts: PackedVector2Array, echelle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x / echelle, p.y / echelle))
	return out


# ------------------------------------------------------------------
# III — la gravure à caisses
# ------------------------------------------------------------------
## Le même vocabulaire, mais chaque voiture gardée SÉPARÉE, avec son attelage.
## C'est le dessin d'un train de gravure ancienne : des caisses distinctes,
## reliées, et non un tube articulé.
func _rame_caisses(axe: PackedVector2Array, col: Color, k: float) -> void:
	var h: float = Geo.CAR_H * 1.5 * k
	var encre := Color(0.10, 0.07, 0.05, 0.92)
	var lavis := col.lerp(Sty.PAPIER, 0.18)
	for i in range(1, axe.size()):
		var m: Vector2 = (axe[i - 1] + axe[i]) / 2.0
		var u := (axe[i] - axe[i - 1]).normalized()
		draw_line(m - u * 3.0 * k, m + u * 3.0 * k, encre, 2.6 * k, true)   # l'attelage
	for i in axe.size():
		var u := _tangente(axe, i)
		var nrm := Vector2(-u.y, u.x)
		var demi: float = Geo.CAR_LEN * 0.5 * k
		var large: float = h * (0.46 if i > 0 else 0.50)
		var c := axe[i]
		var quad := PackedVector2Array([
			c - u * demi - nrm * large, c + u * demi - nrm * large,
			c + u * demi + nrm * large, c - u * demi + nrm * large])
		draw_colored_polygon(quad, lavis)
		# deux tailles en travers du toit, et le filet de faîtage
		for j in 3:
			var x: float = (float(j) - 1.0) * demi * 0.55
			draw_line(c + u * x - nrm * large * 0.72, c + u * x + nrm * large * 0.72,
				Color(encre, 0.30), 1.2 * k, true)
		draw_line(c - u * demi, c + u * demi, Color(encre, 0.45), 1.2 * k, true)
		var ferme := quad.duplicate()
		ferme.append(quad[0])
		draw_polyline(ferme, encre, 2.2 * k, true)


# ------------------------------------------------------------------
# V — LA PLANCHE GRAVÉE, EN TROIS TRANCHES
# ------------------------------------------------------------------
## La planche dessine UNE voiture, d'une proportion de un pour quatre et demi ;
## une voiture du jeu occupe une case CARRÉE, que l'espacement du gril impose.
## Poser le dessin entier sur une voiture l'écraserait ; l'étirer sur toute la
## rame ferait varier l'écartement des nervures selon la longueur du convoi —
## deux voitures et six voitures n'auraient pas le même dessin.
##
## D'où les TROIS TRANCHES : la ferrure de tête, une section centrale répétée
## autant de fois que la longueur le demande, la ferrure de queue. Chaque
## tranche est posée À SA PROPRE PROPORTION, jamais étirée, et la dernière du
## milieu est rognée si elle ne tient pas — c'est ce qui garde aux nervures un
## écartement constant quelle que soit la rame.
##
## LE LAVIS D'ABORD, L'ENCRE PAR-DESSUS : la planche est détourée, son blanc
## est transparent. Le corps peint dessous donne la couleur de destination, le
## dessin ne donne que le trait. Une seule planche sert les six teintes.
## UNE CASE, UN VÉHICULE ENTIER. La première version découpait une voiture
## allongée en trois tranches et les répétait : le compte des voitures était
## juste, mais chaque case ne montrait qu'un MORCEAU de véhicule, et c'est
## exactement ce qui se voyait. Une case du gril EST un véhicule.
##
## Le dessin se pose donc tel quel, un par voiture, orienté sur la tangente
## locale — ce qui lui fait épouser la courbe sans qu'aucun raccord n'ait à
## être calculé. Les cases sont espacées de 35 et les caisses longues de 30 :
## le jeu d'attelage de cinq unités sépare les véhicules tout seul, et le trait
## d'attelage que j'avais ajouté n'a plus lieu d'être.
func _rame_planche(axe: PackedVector2Array, col: Color, k: float) -> void:
	if planche == null:
		return
	var h: float = Geo.CAR_H * 1.5 * k
	var demi: float = Geo.CAR_LEN * 0.5 * k
	var lavis := col.lerp(Sty.PAPIER, 0.06)
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	for i in axe.size():
		# LA TANGENTE POINTE VERS LA QUEUE — elle va de la tête au suivant —
		# donc le bord GAUCHE de la planche tombe du côté de la tête. C'est
		# pour cela que la cheminée doit être à gauche du dessin.
		var u := _tangente(axe, i)
		var nrm := Vector2(-u.y, u.x)
		var c := axe[i]
		var quad := PackedVector2Array([
			c - u * demi - nrm * h * 0.5, c + u * demi - nrm * h * 0.5,
			c + u * demi + nrm * h * 0.5, c - u * demi + nrm * h * 0.5])
		draw_colored_polygon(quad, lavis, uv,
			machine if (i == 0 and machine != null) else planche)


## Une tranche de planche posée sur la portion d'arc [s0, s1], subdivisée pour
## qu'elle ÉPOUSE la courbe au lieu de la couper à la corde.
func _tranche(axe: PackedVector2Array, h: float, s0: float, s1: float,
		u0: float, u1: float, lavis: Color = Color.WHITE, encre: Color = Color.BLACK,
		tex: Texture2D = null) -> void:
	if s1 - s0 <= 0.5:
		return
	var n: int = max(2, int((s1 - s0) / 7.0) + 1)
	for i in n:
		var a0: float = lerpf(s0, s1, float(i) / float(n))
		var a1: float = lerpf(s0, s1, float(i + 1) / float(n))
		var p0 := _sur_arc(axe, a0)
		var p1 := _sur_arc(axe, a1)
		var quad := PackedVector2Array([
			p0["p"] - p0["n"] * h * 0.5, p1["p"] - p1["n"] * h * 0.5,
			p1["p"] + p1["n"] * h * 0.5, p0["p"] + p0["n"] * h * 0.5])
		var v0: float = lerpf(u0, u1, float(i) / float(n))
		var v1: float = lerpf(u0, u1, float(i + 1) / float(n))
		# UNE SEULE PASSE, ET C'EST TOUT LE POINT. La planche porte sa
		# SILHOUETTE dans son canal alpha et son GRIS dans ses couleurs :
		# multipliée par le lavis de destination, le papier prend la teinte et
		# le trait reste noir. Deux passes — l'une au lavis, l'autre à l'encre —
		# ne donnaient rien, puisqu'elles partageaient le même masque et
		# noircissaient deux fois les mêmes traits.
		var uv := PackedVector2Array([Vector2(v0, 0), Vector2(v1, 0), Vector2(v1, 1), Vector2(v0, 1)])
		draw_colored_polygon(quad, lavis, uv, tex if tex != null else planche)


func _longueur(axe: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, axe.size()):
		l += axe[i - 1].distance_to(axe[i])
	return l


## L'axe prolongé d'un demi-nez à chaque bout : la rame commence AVANT le
## centre de sa première voiture.
func _etendre(axe: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(axe[0] - _tangente(axe, 0) * d)
	for p in axe:
		out.append(p)
	out.append(axe[axe.size() - 1] + _tangente(axe, axe.size() - 1) * d)
	return out


func _sur_arc(axe: PackedVector2Array, s: float) -> Dictionary:
	var reste := s
	for i in range(1, axe.size()):
		var l: float = axe[i - 1].distance_to(axe[i])
		if reste <= l or i == axe.size() - 1:
			var f: float = 0.0 if l <= 0.0 else clampf(reste / l, 0.0, 1.0)
			var u: Vector2 = (axe[i] - axe[i - 1]).normalized()
			return {"p": axe[i - 1].lerp(axe[i], f), "n": Vector2(-u.y, u.x)}
		reste -= l
	return {"p": axe[axe.size() - 1], "n": Vector2.UP}


# ------------------------------------------------------------------
func _tangente(axe: PackedVector2Array, i: int) -> Vector2:
	var a: Vector2 = axe[max(0, i - 1)]
	var b: Vector2 = axe[min(axe.size() - 1, i + 1)]
	var u := b - a
	return u.normalized() if u.length() > 1e-6 else Vector2.RIGHT


func _normale(axe: PackedVector2Array, i: int) -> Vector2:
	var u := _tangente(axe, i)
	return Vector2(-u.y, u.x)
