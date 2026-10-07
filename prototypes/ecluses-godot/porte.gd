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
var _cadre: Line2D            # le cadre de fer du vantail (vue oblique)
var _mat_bois: ShaderMaterial
var _chaines: Node2D
var roue: Node2D
# Le plan où poser la tour de GAUCHE, derrière les bateaux et l'eau (le canal
# le donne avant preparer). Vincent, 6 octobre 2026 : l'écluse entière passait
# devant, et le bateau semblait passer derrière elle ; avec la tour de gauche
# au fond et celle de droite devant, il passe ENTRE les deux piliers. Sans ce
# plan, la tour reste avec le reste de la porte.
var arriere: Node2D = null
# L'eau du bassin de gauche, que le canal donne avant preparer : posée juste
# devant le vantail, derrière le pilier de droite (voir canal.gd, « voiles »).
var voile: Eau = null
# La roue se touche-t-elle maintenant ? Pendant une manœuvre ou une fois la
# partie finie, elle pâlit et s'éteint un peu (seconde analyse graphique : les
# roues sont les commandes, il faut voir quand elles répondent).
var actif := true
# PORTE À VANNE (chapitre 2, 7 octobre 2026) : une seconde commande, la vanne
# de l'aqueduc, que l'on tourne par un petit volant de laiton sur le pilier
# avant, relié à l'aqueduc par sa tige. La grande roue rouge lève la porte.
var a_vanne := false
var _angle_vanne := 0.0
var _rotation_vanne := 0.0
var _secousse := 0.0         # la grande roue refuse : la porte est tenue par l'eau
var y_bas_tige := 0.0        # le bas de la tige du volant : le logement de la vanne (canal)
# La projection oblique : le décalage du plan du fond (zéro : la vue de profil)
# et la couche, avant l'eau, où poser le vantail.
var oblique := Vector2.ZERO
var couche_vantail: Node2D = null
# Le QUAI d'un ascenseur à bateaux (chapitre 9) : une porte que le bac ouvre
# et ferme tout seul en s'arrêtant. Ni roue ni volant : on ne la touche pas.
var sans_roue := false

func preparer(ax0: float, ax1: float, aseuil: float, acrete: float, aportique: float, abas: float, au: float,
		pierre: Shader, bois: Shader, vanne: bool, leve: bool, abas_ouvert: float) -> void:
	gx0 = ax0; gx1 = ax1; y_seuil = aseuil; y_crete = acrete; y_portique = aportique; u = au
	vanne_ouverte = vanne
	_leve = leve
	_entrouvert = vanne and not leve
	bas_ouvert_y = abas_ouvert
	bas_y = _cible()
	var mp := ShaderMaterial.new()
	mp.shader = pierre
	Peint.habiller(mp, "pierre")
	if oblique != Vector2.ZERO:
		_construire_oblique(mp, abas)
	else:
		_construire_profil(mp, abas, bois)
	roue = Node2D.new()
	roue.z_index = 6
	roue.draw.connect(_dessiner_roue)
	add_child(roue)
	_maj_vantail()

func _construire_profil(mp: ShaderMaterial, abas: float, bois: Shader) -> void:
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
	# l'eau de gauche, devant le vantail : elle réfracte ce qui est derrière
	# elle, et la copie de l'écran faite pour les bassins ne contient pas
	# encore le vantail — on la refait sur la porte
	if voile:
		var copie := BackBufferCopy.new()
		copie.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(copie)
		add_child(voile)
	# le radier, sous le seuil
	add_child(_rect(gx0, y_seuil, gx1, abas, mp))
	# les deux tours du portique, du radier jusque sous la traverse
	var fond := arriere if arriere else self
	fond.add_child(_rect(gx0 - 6, y_portique, gx0 + 9, y_seuil, mp))
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

# Le volant de la vanne : en laiton, comme sa tige et la plaque de la vanne
# dans le tuyau (l'acier bleuté se confondait avec le tuyau, Vincent), plus
# petit que la roue rouge ; sa tige descend jusqu'au logement de la vanne.
# Quand la grande roue refuse, il s'illumine.
func _dessiner_volant() -> void:
	var c := centre_vanne()
	var r := 0.24 * u
	var acier := Color("#d6a83a")      # laiton : la couleur de tout le système de la vanne
	var sombre := Color("#5a3f12")
	# la tige descend jusqu'au logement de la vanne, dans le tuyau sous le fond
	var bas := y_bas_tige if y_bas_tige > 0.0 else y_seuil
	roue.draw_line(c, Vector2(c.x, bas), sombre, 5.0, true)
	roue.draw_line(c, Vector2(c.x, bas), Color("#b8892c"), 2.5, true)
	if _secousse > 0.0:
		var a := clampf(_secousse / 0.4, 0.0, 1.0) * (0.65 + 0.35 * sin(_secousse * 14.0))
		roue.draw_circle(c, r + 11.0, Color(1.0, 0.85, 0.3, 0.6 * a))
	roue.draw_circle(c + Vector2(1.5, 2.5), r + 4, Color(0, 0, 0, 0.2))
	roue.draw_arc(c, r, 0, TAU, 32, sombre, 7.0, true)
	roue.draw_arc(c, r, 0, TAU, 32, acier, 4.5, true)
	for k in 4:
		var a := _angle_vanne + k * TAU / 4.0
		var d := Vector2(cos(a), sin(a))
		roue.draw_line(c, c + d * (r - 2.0), sombre, 4.0, true)
		roue.draw_line(c, c + d * (r - 2.0), acier, 2.2, true)
		roue.draw_circle(c + d * (r + 3.0), 2.8, sombre)
	roue.draw_circle(c, 5.0, sombre)
	roue.draw_circle(c, 2.8, Color("#f4e2a8"))
	# la vanne ouverte : un filet bleu sur la tige
	if vanne_ouverte:
		roue.draw_line(c + Vector2(0, r + 6.0), Vector2(c.x, bas), Color(0.4, 0.75, 0.9, 0.8), 2.0, true)

# --- La porte en projection oblique (branche ecluses-oblique) -----------------
# Vincent, 7 octobre 2026 : tout est vu de profil, sauf les écluses, dans un
# « faux angle de gauche » — c'est perturbant. En projection oblique, la
# profondeur part en diagonale (« oblique », vers le haut et la gauche) et
# chaque pièce est à sa vraie place : le pilier avant dans le plan de la coupe,
# le pilier arrière dans le plan du fond, le vantail EN TRAVERS du canal entre
# les deux, dont on voit la face de biais ; la traverse relie les deux piliers.
# Le vantail se pose dans « couche_vantail », avant l'eau : on le voit à travers
# l'eau du bassin de gauche, sans rien de plus.
# Vincent, 7 octobre 2026 : « les portes paraissent fines, elles doivent être
# un peu plus massives ». Piliers plus larges (demi-largeur 12, puis 15, puis
# 20), traverse plus haute qui déborde des piliers, et un cadre de fer épais
# sur le pourtour du vantail. Sa tranche, elle, est dans la rainure du pilier :
# on ne la voit pas.
const PILIER := 20.0
const DEBORD_TRAVERSE := 6.0
func _h_traverse() -> float:
	return 0.32 * u if oblique != Vector2.ZERO else 0.2 * u
func _xc() -> float:
	return (gx0 + gx1) * 0.5

func _construire_oblique(mp: ShaderMaterial, abas: float) -> void:
	var xc := _xc()
	var D := oblique
	# le vantail, dans la couche avant l'eau
	_vantail = Polygon2D.new()
	var tv := Peint.vantail()
	if tv:
		_vantail.texture = tv
	else:
		_vantail.color = Color("#8a5a2e")
	(couche_vantail if couche_vantail else self).add_child(_vantail)
	_cadre = Line2D.new()
	_cadre.width = 5.0
	_cadre.default_color = Color("#2b2622")
	_cadre.joint_mode = Line2D.LINE_JOINT_SHARP
	_cadre.closed = true
	(couche_vantail if couche_vantail else self).add_child(_cadre)
	_chaines = Node2D.new()
	_chaines.draw.connect(_dessiner_chaines)
	add_child(_chaines)
	# le pilier arrière, dans le plan du fond, derrière l'eau et les bateaux
	var fond := arriere if arriere else self
	var arr := _rect(xc - PILIER + D.x, y_portique + D.y, xc + PILIER + D.x, y_seuil + D.y, mp)
	arr.modulate = Color(0.86, 0.84, 0.8)
	fond.add_child(arr)
	# les ombres de contact (lot 1, refait pour le volume) : le pilier arrière
	# jette son ombre sur le mur du fond, à sa droite (lumière d'en haut à
	# gauche), et la traverse sur le haut du pilier arrière
	fond.add_child(_degrade(xc + PILIER + D.x, y_portique + D.y, xc + PILIER + 16.0 + D.x, y_seuil + D.y, 0.3, 0.0))
	var sous := Polygon2D.new()
	sous.polygon = _quad(xc - PILIER + D.x, y_portique + 4.0 + D.y, xc + PILIER + D.x, y_portique + 18.0 + D.y)
	var o := Color(0.08, 0.04, 0.0, 0.35)
	var z := Color(0.08, 0.04, 0.0, 0.0)
	sous.vertex_colors = PackedColorArray([o, o, z, z])
	fond.add_child(sous)
	# le radier sous le seuil, dans le plan de la coupe
	add_child(_rect(gx0, y_seuil, gx1, abas, mp))
	# le pilier avant, et l'arête sombre de son côté gauche (sa face en biais)
	add_child(_rect(xc - PILIER, y_portique, xc + PILIER, y_seuil, mp))
	add_child(_degrade(xc - PILIER, y_portique, xc - PILIER + 5.0, y_seuil, 0.35, 0.0))
	# la traverse, d'un pilier à l'autre : sa face de côté (gauche), sa face
	# du dessus, et son bout avant
	var y0 := y_portique - _h_traverse()
	var y1 := y_portique + 4.0
	var g := xc - PILIER - DEBORD_TRAVERSE
	var dr := xc + PILIER + DEBORD_TRAVERSE
	var gauche := PackedVector2Array([Vector2(g, y0), Vector2(g, y1), Vector2(g + D.x, y1 + D.y), Vector2(g + D.x, y0 + D.y)])
	var dessus := PackedVector2Array([Vector2(g, y0), Vector2(dr, y0), Vector2(dr + D.x, y0 + D.y), Vector2(g + D.x, y0 + D.y)])
	var tt := Peint.traverse()
	var cote := Polygon2D.new()
	cote.polygon = gauche
	if tt:
		cote.texture = tt
		var w := tt.get_width(); var h := tt.get_height()
		cote.uv = PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(0, h), Vector2(0, 0)])
	else:
		cote.color = Color("#5a3a20")
	add_child(cote)
	var pd := Polygon2D.new()
	pd.polygon = dessus
	pd.color = Color("#8a6038")
	add_child(pd)
	var bout := _rect(g, y0, dr, y1, null)
	bout.color = Color("#6e4524")
	add_child(bout)
	var plaque := _rect(g + 5, y0 + 3, dr - 5, y1 - 3, null)
	plaque.color = Color("#3a332e")
	add_child(plaque)

func _maj_oblique() -> void:
	var xc := _xc()
	var D := oblique
	var haut := bas_y - _hauteur()
	var cache := y_portique + 4.0               # le dessous de la traverse
	var haut_vu := maxf(haut, cache)
	if bas_y <= haut_vu + 1.0:
		_vantail.polygon = PackedVector2Array()
		_cadre.points = PackedVector2Array()
		_chaines.queue_redraw()
		return
	var xf := xc - 5.0
	_vantail.polygon = PackedVector2Array([Vector2(xf + D.x, haut_vu + D.y), Vector2(xf, haut_vu), Vector2(xf, bas_y), Vector2(xf + D.x, bas_y + D.y)])
	# le cadre de fer, sur tout le pourtour du vantail
	_cadre.points = _vantail.polygon
	# le vantail s'assombrit vers le pilier avant, qui lui fait de l'ombre, et
	# sous la traverse quand il est fermé (son haut y est rangé)
	var sous_t := 0.82 if haut_vu <= cache + 1.0 else 1.0
	_vantail.vertex_colors = PackedColorArray([Color(0.95 * sous_t, 0.95 * sous_t, 0.95 * sous_t), Color(0.66 * sous_t, 0.66 * sous_t, 0.66 * sous_t), Color(0.7, 0.7, 0.7), Color(0.92, 0.92, 0.92)])
	if _vantail.texture:
		var w := _vantail.texture.get_width()
		var h := _vantail.texture.get_height()
		var v0 := (haut_vu - haut) / maxf(bas_y - haut, 1.0) * h
		_vantail.uv = PackedVector2Array([Vector2(0, v0), Vector2(w, v0), Vector2(w, h), Vector2(0, h)])
	_chaines.queue_redraw()

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

# En oblique, la roue est posée au milieu du dessus de la traverse, à
# mi-profondeur ; le doigt la trouve là (canal.porte_sous).
func centre_roue() -> Vector2:
	return Vector2((gx0 + gx1) / 2.0, y_portique - _h_traverse() - 0.5 * u) + oblique * 0.5

# Le haut du pied de la roue : le dessus de la traverse, sous l'axe.
func _pied_roue() -> float:
	return y_portique - _h_traverse() + oblique.y * 0.5

# La vanne : la roue fait un tour et demi. Émet roue_finie.
func manoeuvrer_vanne(ouvrir: bool) -> void:
	vanne_ouverte = ouvrir
	if a_vanne:
		_rotation_vanne = 1.5 * TAU * (1.0 if ouvrir else -1.0)
	else:
		_rotation = 1.5 * TAU * (1.0 if ouvrir else -1.0)

# La grande roue d'une porte à vanne : elle ne fait que lever ou baisser la
# porte (le treuil suit le vantail, dans _process).
func tourner_roue(lever: bool) -> void:
	_rotation = 0.5 * TAU * (1.0 if lever else -1.0)

# Toucher la grande roue quand les deux eaux diffèrent : elle tressaille sans
# tourner, et le volant de la vanne s'illumine (c'est lui qu'il faut ouvrir).
func refuser() -> void:
	_secousse = 1.6          # la roue tressaille 0,5 s, le volant luit 1,6 s

# Le petit volant de la vanne : sur le pilier avant, sous la traverse.
func centre_vanne() -> Vector2:
	var xc := (gx0 + gx1) * 0.5
	return Vector2(xc, y_portique + 0.62 * u)

# Le vantail : levé (au-dessus de l'eau, assez pour un bateau) ou baissé.
func placer_vantail(lever: bool) -> void:
	_leve = lever

func arrive() -> bool:
	return absf(bas_y - _cible()) < 0.6

# La porte SIMPLE (sans aqueduc, Vincent, 7 octobre 2026) : toucher la roue
# soulève tout de suite la porte d'une fente, et l'eau passe dessous ; quand
# les deux eaux sont au même niveau, elle se lève en grand. La porte à vanne
# et aqueduc, elle, reste close tant que la vanne égalise.
const ENTREBAIL := 20.0
var _entrouvert := false
func entrouvrir(oui: bool) -> void:
	_entrouvert = oui

# La hauteur de la fente sous le vantail, en pixels.
func fente() -> float:
	return maxf(y_seuil - bas_y, 0.0)

# 0 fermée (ou seulement entrouverte), 1 assez levée pour que l'eau remplisse
# l'ouverture
func ouverture() -> float:
	return clampf((y_seuil - bas_y - ENTREBAIL) / (0.5 * u), 0.0, 1.0)

func _cible() -> float:
	if _leve: return bas_ouvert_y
	return y_seuil - ENTREBAIL if _entrouvert else y_seuil

func _process(dt: float) -> void:
	if _rotation_vanne != 0.0:
		var pv := signf(_rotation_vanne) * minf(absf(_rotation_vanne), dt * TAU * 2.6)
		_rotation_vanne -= pv
		_angle_vanne += pv
		roue.queue_redraw()
		if is_zero_approx(_rotation_vanne):
			_rotation_vanne = 0.0
			roue_finie.emit()
	if _secousse > 0.0:
		_secousse = maxf(_secousse - dt, 0.0)
		roue.queue_redraw()
	if roue:
		var cible := Color(1, 1, 1) if actif else Color(0.68, 0.64, 0.64, 0.85)
		roue.modulate = roue.modulate.lerp(cible, minf(1.0, dt * 6.0))
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
	if oblique != Vector2.ZERO:
		_maj_oblique()
		return
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
	if oblique != Vector2.ZERO:
		var haut_o := bas_y - _hauteur()
		var cache_o := y_portique + 4.0
		if haut_o <= cache_o: return
		for z in [0.25, 0.75]:
			_maillons(_xc() - 5.0 + oblique.x * z, cache_o + oblique.y * z, haut_o + oblique.y * z)
		return
	var haut := bas_y - _hauteur()
	var cache := y_portique              # au-dessus, la traverse cache la chaîne
	if haut <= cache: return
	for x in [gx0 + 16.0, gx1 - 16.0]:
		_maillons(x, cache, haut)

# Une chaîne, de la manille posée sur le haut du vantail (y_bas) jusqu'à la
# traverse (y_haut) : des maillons alternés de face et de profil.
func _maillons(x: float, y_haut: float, y_bas: float) -> void:
	var acier := Color("#34353a")
	var reflet := Color("#9a9ca3")
	_chaines.draw_rect(Rect2(x - 4.0, y_bas - 3.0, 8.0, 4.0), acier)
	var y := y_bas - 2.0
	var j := 0
	while y > y_haut - MAILLON:
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
	if sans_roue: return
	if a_vanne: _dessiner_volant()
	var c := centre_roue()
	var tressaille := sin(_secousse * 40.0) * 0.12 * clampf((_secousse - 1.1) / 0.5, 0.0, 1.0)
	var r := 0.4 * u
	var rouge := Color("#c8321f")
	var sombre := Color("#7c1f13")
	# le pied, de la traverse à l'axe
	roue.draw_rect(Rect2(c.x - 4, c.y, 8, _pied_roue() - c.y), Color("#2d2a28"))
	roue.draw_circle(c + Vector2(2, 3), r + 5, Color(0, 0, 0, 0.18))
	var tr := Peint.roue()
	if tr:
		# la roue peinte, qui tourne sur son moyeu ; ses boutons dépassent
		# du cercle dessiné d'avant, d'où le rayon un peu plus grand
		var R := r + 7.5
		roue.draw_set_transform(c, _angle + tressaille)
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
