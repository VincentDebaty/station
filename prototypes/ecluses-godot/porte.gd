class_name Porte
extends Node2D
# ------------------------------------------------------------------
# UNE PORTE LEVANTE À PORTIQUE — choisie par Vincent le 6 octobre 2026,
# après une porte qui pivotait (trompe-l'œil) puis une qui s'enfonçait dans
# le radier (bizarre). Vue de côté, c'est la seule dont le mouvement est vrai :
# le vantail monte tout droit entre deux tours de pierre.
#
# Comme une vraie écluse, en deux temps :
#   1. la roue, en haut du portique, ouvre une VANNE : l'eau passe d'un
#      bassin à l'autre par l'aqueduc (aqueduc.gd), pas par la porte ;
#   2. quand les deux eaux sont au même niveau, le VANTAIL monte, juste assez
#      pour qu'un bateau passe dessous, cheminée comprise (le canal lui donne
#      cette hauteur, « bas_ouvert_y », et il la suit si l'eau bouge). Sa
#      partie haute rentre dans la traverse du portique : il ne sort jamais
#      de l'écran.
#
# Le moteur ne connaît que « ouvert » : la vanne. Le vantail ne fait que
# suivre la règle qu'il applique déjà — un bateau ne passe que si les deux
# eaux sont au même niveau.
# ------------------------------------------------------------------

signal roue_finie

var gx0 := 0.0
var gx1 := 0.0
var y_seuil := 0.0
var y_crete := 0.0
var y_portique := 0.0      # le haut des tours, sous la traverse
var u := 64.0
var vanne_ouverte := false
var bas_y := 0.0           # le bas du vantail, en y monde (y_seuil quand il est fermé)
var bas_ouvert_y := 0.0    # où le bas doit monter quand la porte est levée
var _leve := false
var _angle := 0.0
var _rotation := 0.0       # ce qui reste à tourner de la roue
var _vantail: Polygon2D
var _mat_bois: ShaderMaterial
var _chaines: Node2D
var roue: Node2D
# Le plan où poser la tour de GAUCHE, derrière les bateaux et l'eau (le canal
# le donne avant preparer). Vincent, 6 octobre 2026 : l'écluse entière passait
# devant, et le bateau semblait passer derrière elle ; avec la tour de gauche
# au fond et celle de droite devant, il passe ENTRE les deux piliers. Sans ce
# plan, la tour reste avec le reste de la porte.
var arriere: Node2D = null

func preparer(ax0: float, ax1: float, aseuil: float, acrete: float, aportique: float, abas: float, au: float,
		pierre: Shader, bois: Shader, vanne: bool, leve: bool, abas_ouvert: float) -> void:
	gx0 = ax0; gx1 = ax1; y_seuil = aseuil; y_crete = acrete; y_portique = aportique; u = au
	vanne_ouverte = vanne
	_leve = leve
	bas_ouvert_y = abas_ouvert
	bas_y = bas_ouvert_y if leve else y_seuil
	var mp := ShaderMaterial.new()
	mp.shader = pierre
	Peint.habiller(mp, "pierre")
	# le vantail d'abord : les tours et la traverse passent devant lui
	_mat_bois = ShaderMaterial.new()
	_mat_bois.shader = bois
	Peint.habiller(_mat_bois, "bois")
	_vantail = Polygon2D.new()
	_vantail.material = _mat_bois
	add_child(_vantail)
	_chaines = Node2D.new()
	_chaines.draw.connect(_dessiner_chaines)
	add_child(_chaines)
	# Les ombres de contact (analyse graphique du 6 octobre 2026 : les portes
	# faisaient « sprite posé par-dessus ») : sur le vantail, l'ombre des
	# tours de chaque côté ; sur le mur à droite, l'ombre portée de la tour
	# (la lumière vient d'en haut à gauche).
	var haut_ombre := y_portique - 0.2 * u
	add_child(_degrade(gx0 + 9, haut_ombre, gx0 + 21, y_seuil, 0.42, 0.0))
	add_child(_degrade(gx1 - 21, haut_ombre, gx1 - 9, y_seuil, 0.0, 0.3))
	add_child(_degrade(gx1 + 6, y_portique, gx1 + 20, y_seuil, 0.26, 0.0))
	# le radier, sous le seuil
	add_child(_rect(gx0, y_seuil, gx1, abas, mp))
	# les deux tours du portique, du radier jusque sous la traverse
	var fond := arriere if arriere else self
	var tour_fond := _rect(gx0 - 6, y_portique, gx0 + 9, y_seuil, mp)
	fond.add_child(tour_fond)
	add_child(_rect(gx1 - 9, y_portique, gx1 + 6, y_seuil, mp))
	# la rainure où coulisse le vantail, au bord intérieur de chaque tour, et
	# l'ombre de la traverse sur ce qui est dessous
	fond.add_child(_degrade(gx0 + 6, y_portique, gx0 + 9, y_seuil, 0.15, 0.55))
	add_child(_degrade(gx1 - 9, y_portique, gx1 - 6, y_seuil, 0.55, 0.15))
	var sous_traverse := Polygon2D.new()
	sous_traverse.polygon = _quad(gx0 - 16, y_portique + 4, gx1 + 16, y_portique + 16)
	sous_traverse.vertex_colors = PackedColorArray([Color(0.08, 0.04, 0.0, 0.34), Color(0.08, 0.04, 0.0, 0.34), Color(0.08, 0.04, 0.0, 0.0), Color(0.08, 0.04, 0.0, 0.0)])
	add_child(sous_traverse)
	# la traverse, où le vantail levé vient se ranger
	var tx := Peint.traverse()
	if tx:
		# la poutre peinte, découpée en trois : ses deux bouts ferrés gardent
		# leur forme, le bois du milieu s'étire à la largeur de la porte
		var np := NinePatchRect.new()
		np.texture = tx
		var bout := int(tx.get_width() * 0.11)
		np.patch_margin_left = bout; np.patch_margin_right = bout
		var e := (0.2 * u + 4.0) / tx.get_height()
		np.position = Vector2(gx0 - 16, y_portique - 0.2 * u)
		np.size = Vector2((gx1 - gx0 + 32) / e, tx.get_height())
		np.scale = Vector2(e, e)
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(np)
	else:
		var traverse := Polygon2D.new()
		traverse.color = Color("#3b2a1e")
		traverse.polygon = _quad(gx0 - 16, y_portique - 0.2 * u, gx1 + 16, y_portique + 4)
		add_child(traverse)
		var filet := Polygon2D.new()
		filet.color = Color("#5a4330")
		filet.polygon = _quad(gx0 - 16, y_portique - 0.2 * u, gx1 + 16, y_portique - 0.2 * u + 4)
		add_child(filet)
	roue = Node2D.new()
	roue.z_index = 6
	roue.draw.connect(_dessiner_roue)
	add_child(roue)
	_maj_vantail()

func _hauteur() -> float:
	return y_seuil - y_crete     # le vantail fermé va du seuil à la crête

func _rect(ax0: float, ay0: float, ax1: float, ay1: float, mat: Material) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = _quad(ax0, ay0, ax1, ay1)
	p.material = mat
	return p

# Une ombre en dégradé horizontal : « a0 » d'opacité à gauche, « a1 » à droite.
func _degrade(ax0: float, ay0: float, ax1: float, ay1: float, a0: float, a1: float) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = _quad(ax0, ay0, ax1, ay1)
	var g := Color(0.08, 0.04, 0.0, a0)
	var d := Color(0.08, 0.04, 0.0, a1)
	p.vertex_colors = PackedColorArray([g, d, d, g])
	return p

func _quad(ax0: float, ay0: float, ax1: float, ay1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(ax0, ay0), Vector2(ax1, ay0), Vector2(ax1, ay1), Vector2(ax0, ay1)])

func centre_roue() -> Vector2:
	return Vector2((gx0 + gx1) / 2.0, y_portique - 0.2 * u - 0.5 * u)

# La vanne : la roue fait un tour et demi. Émet roue_finie.
func manoeuvrer_vanne(ouvrir: bool) -> void:
	vanne_ouverte = ouvrir
	_rotation = 1.5 * TAU * (1.0 if ouvrir else -1.0)

# Le vantail : levé (au-dessus de l'eau, assez pour un bateau) ou baissé.
func placer_vantail(lever: bool) -> void:
	_leve = lever

func arrive() -> bool:
	return absf(bas_y - _cible()) < 0.6

# 0 fermé, 1 assez levé pour que l'eau remplisse l'ouverture
func ouverture() -> float:
	return clampf((y_seuil - bas_y) / (0.5 * u), 0.0, 1.0)

func _cible() -> float:
	return bas_ouvert_y if _leve else y_seuil

func _process(dt: float) -> void:
	if _rotation != 0.0:
		var pas := signf(_rotation) * minf(absf(_rotation), dt * TAU * 2.6)
		_rotation -= pas
		_angle += pas
		roue.queue_redraw()
		if is_zero_approx(_rotation):
			_rotation = 0.0
			roue_finie.emit()
	# le vantail démarre doucement, file, et ralentit en arrivant ; la roue
	# tourne avec lui, comme un treuil qui enroule ses chaînes (Vincent : « la
	# roue ne tourne pas toujours en même temps que la porte »)
	var ecart := _cible() - bas_y
	if absf(ecart) > 0.01:
		var vitesse := clampf(absf(ecart) * 3.0, 30.0, 170.0)
		var avant := bas_y
		bas_y = move_toward(bas_y, _cible(), vitesse * dt)
		_angle += (avant - bas_y) / 11.0
		roue.queue_redraw()
		_maj_vantail()

func _maj_vantail() -> void:
	var a := gx0 + 9.0
	var b := gx1 - 9.0
	var haut := bas_y - _hauteur()
	var cache := y_portique - 0.2 * u        # au-dessus, le vantail est rangé dans la traverse
	var haut_vu := maxf(haut, cache)
	if bas_y <= haut_vu + 1.0:
		_vantail.polygon = PackedVector2Array()
	else:
		_vantail.polygon = _quad(a, haut_vu, b, bas_y)
	# le cadre du bois suit le vantail entier, même la part cachée : les
	# ferrures montent avec lui
	_mat_bois.set_shader_parameter("cadre", Vector4(a, haut, b, bas_y))
	_mat_bois.set_shader_parameter("tranche", 0.0)
	_chaines.queue_redraw()

# Les deux chaînes, de la traverse au haut du vantail. Elles sont ACCROCHÉES
# AU VANTAIL : quand il monte, les maillons montent avec lui et rentrent dans la
# traverse, au lieu d'une chaîne fixe qui raccourcit (Vincent : « ce serait
# bien que les chaînes bougent »). De vrais maillons, alternés de face et de
# profil, plutôt qu'un collier de points (analyse graphique, lot 6).
const MAILLON := 9.0
func _dessiner_chaines() -> void:
	var haut := bas_y - _hauteur()
	var cache := y_portique              # au-dessus, la traverse cache la chaîne
	if haut <= cache: return
	var acier := Color("#34353a")
	var reflet := Color("#9a9ca3")
	for x in [gx0 + 16.0, gx1 - 16.0]:
		# la manille, sur le haut du vantail
		_chaines.draw_rect(Rect2(x - 4.0, haut - 3.0, 8.0, 4.0), acier)
		var y := haut - 2.0
		var j := 0
		while y > cache - MAILLON:
			var m := Vector2(x, y - MAILLON * 0.5)
			if j % 2 == 0:
				# de face : un anneau ovale
				var anneau := PackedVector2Array()
				for k in 13:
					var t := TAU * k / 12.0
					anneau.append(m + Vector2(cos(t) * 3.4, sin(t) * MAILLON * 0.62))
				_chaines.draw_polyline(anneau, acier, 2.4, true)
				_chaines.draw_line(m + Vector2(-1.6, -MAILLON * 0.35), m + Vector2(-1.6, MAILLON * 0.05), reflet, 1.0, true)
			else:
				# de profil : une barre
				_chaines.draw_line(m + Vector2(0, -MAILLON * 0.62), m + Vector2(0, MAILLON * 0.62), acier, 2.8, true)
				_chaines.draw_line(m + Vector2(-0.6, -MAILLON * 0.4), m + Vector2(-0.6, MAILLON * 0.1), reflet, 0.9, true)
			y -= MAILLON
			j += 1

func _dessiner_roue() -> void:
	var c := centre_roue()
	var r := 0.4 * u
	var rouge := Color("#c8321f")
	var sombre := Color("#7c1f13")
	# le pied, de la traverse à l'axe
	roue.draw_rect(Rect2(c.x - 4, c.y, 8, (y_portique - 0.2 * u) - c.y), Color("#2d2a28"))
	roue.draw_circle(c + Vector2(2, 3), r + 5, Color(0, 0, 0, 0.18))
	var tr := Peint.roue()
	if tr:
		# la roue peinte, qui tourne sur son moyeu ; ses boutons dépassent
		# du cercle dessiné d'avant, d'où le rayon un peu plus grand
		var R := r + 7.5
		roue.draw_set_transform(c, _angle)
		roue.draw_texture_rect(tr, Rect2(-R, -R, 2.0 * R, 2.0 * R), false)
		roue.draw_set_transform(Vector2.ZERO)
		return
	roue.draw_arc(c, r, 0, TAU, 40, sombre, 10.0, true)
	roue.draw_arc(c, r, 0, TAU, 40, rouge, 7.0, true)
	roue.draw_arc(c, r - 1.5, PI * 1.1, PI * 1.6, 12, Color(1, 0.6, 0.5, 0.7), 2.0, true)
	for k in 6:
		var a := _angle + k * TAU / 6.0
		var d := Vector2(cos(a), sin(a))
		roue.draw_line(c + d * 5.0, c + d * (r - 3.0), sombre, 5.0, true)
		roue.draw_line(c + d * 5.0, c + d * (r - 3.0), rouge, 3.0, true)
		if k % 2 == 0:
			roue.draw_circle(c + d * (r + 4.0), 3.5, sombre)
	roue.draw_circle(c, 7.0, sombre)
	roue.draw_circle(c, 4.0, Color("#e9e2d8"))
