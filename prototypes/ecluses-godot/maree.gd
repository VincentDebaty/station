class_name Maree
extends Node2D
# ------------------------------------------------------------------
# LA MARÉE (chapitre 8, nuit du 7 au 8 octobre 2026) : la mer monte et
# descend d'un pas à chaque coup, selon une suite connue d'avance. On la lit
# sur le mur du port, sans texte :
#   - une ÉCHELLE DE MARÉE peinte, rouge et blanche, une bande par
#     demi-unité ;
#   - la bande d'ALGUES, sombre, entre la plus basse et la plus haute mer :
#     la marque que laisse la mer sur la pierre ;
#   - une FLÈCHE jaune sur l'échelle, et un pointillé sur le mur, à la hauteur
#     où sera la mer au coup suivant. Elle monte ou descend doucement pour
#     dire le sens de la marée.
# Dans le plan du mur du fond : l'eau passe devant, comme sur la pierre.
# ------------------------------------------------------------------

var canal: Canal
var i := 0                 # le bassin de la mer
var x0 := 0.0              # la bande d'algues, sur le mur du fond (x monde)
var x1 := 0.0
var x_echelle := 0.0
var prochain := 0.0        # le niveau de la mer au coup suivant (unités)
var _affiche := 0.0        # tel qu'affiché, il glisse vers « prochain »
var _t := 0.0
var bas := 0.0             # la plus basse et la plus haute mer (unités)
var haut := 0.0
var _fleche: Node2D        # la flèche, devant l'eau : sous la surface, on ne la voyait plus

func preparer(c: Canal, ai: int, ax0: float, ax1: float, aechelle: float) -> void:
	canal = c; i = ai; x0 = ax0; x1 = ax1; x_echelle = aechelle
	var m: Array = c.N["bassins"][ai]["maree"]
	bas = INF; haut = -INF
	for h in m:
		bas = minf(bas, float(h)); haut = maxf(haut, float(h))
	z_index = 0
	_fleche = Node2D.new()
	_fleche.z_index = 3
	_fleche.draw.connect(_dessiner_fleche)
	add_child(_fleche)

func regler(phase: int, coups: int) -> void:
	var m: Array = canal.N["bassins"][i]["maree"]
	prochain = float(m[(coups + 1) % m.size()])
	if _affiche == 0.0: _affiche = prochain

func _process(dt: float) -> void:
	_t += dt
	_affiche = move_toward(_affiche, prochain, dt * 2.0)
	queue_redraw()
	_fleche.queue_redraw()

func _y(h: float) -> float:
	return canal.Y(h) + canal.D.y

func _draw() -> void:
	# la bande d'algues entre basse et haute mer, au bord irrégulier
	var haut_alg := PackedVector2Array()
	var x := x0
	var k := 0
	while x <= x1:
		haut_alg.append(Vector2(x, _y(haut) - 4.0 - 4.0 * absf(sin(x * 0.07)) - 3.0 * sin(x * 0.23)))
		x += 10.0
		k += 1
	var poly := haut_alg.duplicate()
	poly.append(Vector2(x1, _y(bas) + 6.0))
	poly.append(Vector2(x0, _y(bas) + 6.0))
	var cols := PackedColorArray()
	for p in poly:
		var f := clampf((p.y - _y(haut)) / maxf(_y(bas) - _y(haut), 1.0), 0.0, 1.0)
		cols.append(Color(0.24, 0.32, 0.16, 0.30 + 0.25 * f))
	draw_polygon(poly, cols)
	# quelques touffes pendantes au bord haut des algues
	for p in haut_alg:
		if int(p.x) % 3 == 0:
			draw_line(p, p + Vector2(1.5, 7.0), Color(0.22, 0.34, 0.12, 0.6), 2.0, true)
	# l'échelle de marée : une planche peinte, du fond à un peu au-dessus de la
	# plus haute mer, une bande rouge ou blanche par demi-unité
	var fond := float(canal.N["bassins"][i]["fond"])
	var sommet := haut + 1.0
	var w := 16.0
	draw_rect(Rect2(x_echelle - w * 0.5 - 2.0, _y(sommet) - 2.0, w + 4.0, _y(fond) - _y(sommet) + 2.0), Color("#3b2414"))
	var h := fond
	var n := 0
	while h < sommet - 1e-6:
		var y0 := _y(minf(h + 0.5, sommet))
		var y1 := _y(h)
		var c := Color("#d8402b") if n % 2 == 0 else Color("#f6f1e4")
		draw_rect(Rect2(x_echelle - w * 0.5, y0, w, y1 - y0), c)
		# un trait plus long à chaque unité
		if n % 2 == 1:
			draw_line(Vector2(x_echelle - w * 0.5, y0), Vector2(x_echelle + w * 0.5 + 5.0, y0), Color("#3b2414"), 1.5)
		h += 0.5
		n += 1
	# le pied et la tête de la planche
	draw_rect(Rect2(x_echelle - w * 0.5 - 3.0, _y(sommet) - 5.0, w + 6.0, 5.0), Color("#6b4a2e"))
	# le pointillé sur le mur, à la hauteur où sera la mer au coup suivant (la
	# flèche, elle, est devant l'eau : _dessiner_fleche)
	var y_p := _y(_affiche)
	var xx := x0 + 6.0
	while xx < x1 - 6.0:
		draw_line(Vector2(xx, y_p), Vector2(minf(xx + 10.0, x1), y_p), Color(1.0, 0.92, 0.45, 0.75), 2.0, true)
		xx += 18.0

func _dessiner_fleche() -> void:
	var w := 16.0
	var y_p := _y(_affiche)
	var monte := prochain >= float(canal.vue_niv[i]) - 1e-6
	var bond := 3.0 * sin(_t * 4.0) * (-1.0 if monte else 1.0)
	var pointe := Vector2(x_echelle + w * 0.5 + 4.0, y_p + bond * 0.3)
	var fleche := PackedVector2Array([pointe, pointe + Vector2(18.0, -11.0), pointe + Vector2(18.0, 11.0)])
	_fleche.draw_colored_polygon(fleche, Color("#ffd447"))
	fleche.append(pointe)
	_fleche.draw_polyline(fleche, Color("#3b2414"), 2.2, true)
	# le sens : un chevron « ^ » si la mer monte, « v » si elle descend
	var cx := pointe.x + 30.0
	var dir := -1.0 if monte else 1.0
	var cy := y_p + bond
	var chevron := PackedVector2Array([Vector2(cx - 8.0, cy - dir * 5.0), Vector2(cx, cy + dir * 5.0), Vector2(cx + 8.0, cy - dir * 5.0)])
	_fleche.draw_polyline(chevron, Color("#3b2414"), 6.0, true)
	_fleche.draw_polyline(chevron, Color("#ffd447"), 3.0, true)
