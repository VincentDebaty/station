class_name Moulin
extends Node2D
# ------------------------------------------------------------------
# LE MOULIN (chapitre 13, nuit du 7 au 8 octobre 2026) : une porte de
# canal sert de vanne au bief du moulin. L'eau qui y passe tombe sur une
# grande roue à aubes, qui tourne, et le moulin moud : sur la berge du fond,
# à côté de la petite maison du meunier, une rangée de sacs de farine se
# remplit, un par unité d'eau passée. Le niveau est gagné quand tous les sacs
# sont pleins (et les bateaux arrivés) — sans un mot, on compte les sacs.
#
# Trois nœuds : la maison et les sacs (berge du fond, derrière l'eau), la roue
# (dans le plan des bateaux : l'eau passe devant sa partie immergée).
# ------------------------------------------------------------------

var canal: Canal
var centre := Vector2.ZERO      # l'axe de la roue (plan des bateaux, coordonnées monde)
var rayon := 70.0
var maison := Vector2.ZERO      # le pied de la maison, sur la berge du fond
var sacs := 3                   # le nombre de sacs à remplir (« farine »)
var moulu := 0.0                # l'eau passée, telle qu'affichée (unités de volume)
var vitesse := 0.0              # la roue tourne d'autant (radians/s), réglée par le canal
var fond: Node2D                # la maison et les sacs
var roue: Node2D                # la roue
var _angle := 0.0
var _t := 0.0
const BRUN := Color("#3b2414")
const BOIS := Color("#8a5a33")
const BOIS_CLAIR := Color("#b07a45")

func preparer(c: Canal, acentre: Vector2, arayon: float, amaison: Vector2, asacs: int, amoulu: float) -> void:
	canal = c; centre = acentre; rayon = arayon; maison = amaison; sacs = asacs; moulu = amoulu
	fond = Node2D.new()
	fond.draw.connect(_dessiner_fond)
	roue = Node2D.new()
	roue.draw.connect(_dessiner_roue)

func _process(dt: float) -> void:
	_t += dt
	# la roue tourne avec l'eau, puis ralentit doucement
	_angle += vitesse * dt
	vitesse = move_toward(vitesse, 0.25 if moulu < sacs - 0.01 else 0.0, dt * 0.8)
	fond.queue_redraw()
	roue.queue_redraw()

# La roue à aubes : un cercle de bois, ses rayons, et des aubes tout autour.
func _dessiner_roue() -> void:
	var c := centre
	var r := rayon
	# l'ombre sur le mur du fond
	roue.draw_circle(c + Vector2(6, 8), r + 4.0, Color(0, 0, 0, 0.15))
	for k in 12:
		var a := _angle + k * TAU / 12.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		# une aube : une planche qui dépasse de la jante
		var p0 := c + d * (r - 14.0)
		var p1 := c + d * (r + 10.0)
		roue.draw_colored_polygon(PackedVector2Array([p0 - n * 9.0, p1 - n * 9.0, p1 + n * 9.0, p0 + n * 9.0]), BOIS_CLAIR)
		roue.draw_polyline(PackedVector2Array([p0 - n * 9.0, p1 - n * 9.0, p1 + n * 9.0, p0 + n * 9.0, p0 - n * 9.0]), BRUN, 1.8, true)
	# la jante et les rayons
	roue.draw_arc(c, r - 8.0, 0.0, TAU, 48, BRUN, 10.0, true)
	roue.draw_arc(c, r - 8.0, 0.0, TAU, 48, BOIS, 7.0, true)
	roue.draw_arc(c, r * 0.45, 0.0, TAU, 32, BRUN, 6.0, true)
	roue.draw_arc(c, r * 0.45, 0.0, TAU, 32, BOIS, 3.5, true)
	for k in 6:
		var a := _angle + k * TAU / 6.0 + 0.26
		var d := Vector2(cos(a), sin(a))
		roue.draw_line(c + d * 8.0, c + d * (r - 10.0), BRUN, 6.0, true)
		roue.draw_line(c + d * 8.0, c + d * (r - 10.0), BOIS, 3.5, true)
	# le moyeu de fer
	roue.draw_circle(c, 11.0, BRUN)
	roue.draw_circle(c, 8.0, Color("#4a4440"))
	roue.draw_circle(c + Vector2(-2, -2), 3.0, Color("#8a8178"))

# La maison du meunier et ses sacs, sur la berge du fond.
func _dessiner_fond() -> void:
	var p := maison
	var w := 84.0
	var h := 58.0
	# l'ombre
	fond.draw_set_transform(p + Vector2(6, -2), 0.0, Vector2(1.0, 0.22))
	fond.draw_circle(Vector2.ZERO, w * 0.7, Color(0, 0, 0, 0.2))
	fond.draw_set_transform(Vector2.ZERO)
	# les murs de pierre claire
	var murs := Rect2(p.x - w * 0.5, p.y - h, w, h)
	fond.draw_polygon(PackedVector2Array([murs.position, Vector2(murs.end.x, murs.position.y), murs.end, Vector2(murs.position.x, murs.end.y)]),
		PackedColorArray([Color("#efe2c4"), Color("#d6c5a2"), Color("#c4b18c"), Color("#e2d3b2")]))
	for y in [p.y - h + 18.0, p.y - h + 36.0, p.y - h + 54.0]:
		fond.draw_line(Vector2(murs.position.x, y), Vector2(murs.end.x, y), Color(0.5, 0.42, 0.3, 0.3), 1.0)
	fond.draw_rect(murs, BRUN, false, 2.0)
	# le toit de tuiles
	var toit := PackedVector2Array([Vector2(p.x - w * 0.62, p.y - h + 2.0), Vector2(p.x, p.y - h - 40.0), Vector2(p.x + w * 0.62, p.y - h + 2.0)])
	fond.draw_colored_polygon(toit, Color("#c4553a"))
	for k in 4:
		var t := float(k + 1) / 5.0
		fond.draw_line(toit[0].lerp(toit[1], t), toit[2].lerp(toit[1], t), Color("#8e3522"), 1.5, true)
	var tt := toit.duplicate()
	tt.append(toit[0])
	fond.draw_polyline(tt, BRUN, 2.0, true)
	# la porte et la fenêtre
	fond.draw_rect(Rect2(p.x - 26.0, p.y - 30.0, 18.0, 30.0), Color("#6b4226"))
	fond.draw_rect(Rect2(p.x - 26.0, p.y - 30.0, 18.0, 30.0), BRUN, false, 1.5)
	fond.draw_rect(Rect2(p.x + 8.0, p.y - 44.0, 20.0, 16.0), Color("#7fb6d6"))
	fond.draw_rect(Rect2(p.x + 8.0, p.y - 44.0, 20.0, 16.0), BRUN, false, 1.5)
	fond.draw_line(Vector2(p.x + 18.0, p.y - 44.0), Vector2(p.x + 18.0, p.y - 28.0), BRUN, 1.2)
	# les sacs, en pyramide devant la maison, à sa gauche (à droite, le mur
	# du bout du canal les cachait ; en rangée, la roue les cachait) : pleins
	# (blancs, gonflés) ou à remplir (en pointillés), de bas en haut
	var places := []
	var rang := 0
	var n_rang := int(ceil((sqrt(8.0 * sacs + 1.0) - 1.0) * 0.5))
	var reste := sacs
	while reste > 0:
		var dans := mini(n_rang - rang, reste)
		for j in dans:
			places.append(Vector2(p.x - w * 0.5 - 14.0 - (n_rang - 1) * 22.0 + (j + rang * 0.5) * 22.0 + 11.0, p.y - 2.0 - rang * 20.0))
		reste -= dans
		rang += 1
	for k in sacs:
		var plein := moulu >= k + 1 - 0.01
		var part := clampf(moulu - k, 0.0, 1.0)
		var cs: Vector2 = places[k]
		var sac := PackedVector2Array([cs + Vector2(-10, 0), cs + Vector2(-11, -10), cs + Vector2(-6, -20), cs + Vector2(-2.5, -23), cs + Vector2(2.5, -23), cs + Vector2(6, -20), cs + Vector2(11, -10), cs + Vector2(10, 0)])
		if plein:
			fond.draw_colored_polygon(sac, Color("#f4ecd8"))
			fond.draw_line(cs + Vector2(-4, -19), cs + Vector2(4, -19), Color("#a8926c"), 2.0)
			var ferme := sac.duplicate()
			ferme.append(sac[0])
			fond.draw_polyline(ferme, BRUN, 1.8, true)
		else:
			if part > 0.02:
				# le sac qui se remplit, du bas vers le haut
				var hh := 22.0 * part
				fond.draw_rect(Rect2(cs.x - 9.0, cs.y - hh, 18.0, hh), Color("#f4ecd8", 0.85))
			var ferme2 := sac.duplicate()
			ferme2.append(sac[0])
			for j in ferme2.size() - 1:
				fond.draw_dashed_line(ferme2[j], ferme2[j + 1], Color(BRUN, 0.7), 1.6, 4.0)
