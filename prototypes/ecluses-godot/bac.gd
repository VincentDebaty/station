class_name Bac
extends Node2D
# ------------------------------------------------------------------
# L'ASCENSEUR À BATEAUX (chapitre 9, nuit du 7 au 8 octobre 2026) : un bac
# d'acier qui monte et descend dans une chambre de pierre, entre deux quais.
# Il emporte son eau et le bateau qui est dedans ; arrêté d'un côté, le quai
# de ce côté s'ouvre (une porte sans roue, porte.gd) et son eau s'égalise avec
# celle du bief.
#
# En coupe, comme le reste du canal : la face avant du bac est ôtée, on voit
# son eau et le bateau. Restent visibles la tranche de son fond (une poutre
# d'acier rivetée), son fond vu d'en haut et sa paroi du fond, avec sa lisse
# en haut. Les câbles montent de la paroi du fond à une poutre en treillis
# posée sur les deux quais ; au milieu, la roue rouge du treuil, celle qu'on
# touche (la roue rouge, partout dans le jeu, est une commande). Deux
# contrepoids pendent le long des quais et bougent à l'envers du bac.
#
# Deux nœuds : celui-ci, derrière l'eau et les bateaux (le fond et la paroi
# du bac, les câbles), et « devant », après l'eau (la tranche du fond, la
# poutre, la roue, les contrepoids).
# ------------------------------------------------------------------

var canal: Canal
var ib := 0                # le bassin du bac
var x0 := 0.0              # le bac, d'un milieu de quai à l'autre (x monde)
var x1 := 0.0
var y_poutre := 0.0        # le dessous de la poutre du treuil
var hauteur := 2.4         # la hauteur du bac, en unités
var fond_vu := 0.0         # le fond du bac tel qu'affiché (unités)
var bas := 0.0
var haut := 0.0
var actif := true
var devant: Node2D         # après les portes : la poutre, la roue, les contrepoids
var tranche: Node2D        # après l'eau, avant les portes : la tranche du fond du bac
var _angle := 0.0
var _t := 0.0

const ACIER := Color("#5f7482")
const ACIER_CLAIR := Color("#8ea3b0")
const ACIER_SOMBRE := Color("#2f3d47")
const BRUN := Color("#3b2414")

func preparer(c: Canal, abassin: int, ax0: float, ax1: float, ay_poutre: float, abas: float, ahaut: float, afond: float) -> void:
	canal = c; ib = abassin; x0 = ax0; x1 = ax1; y_poutre = ay_poutre
	bas = abas; haut = ahaut; fond_vu = afond
	devant = Node2D.new()
	devant.draw.connect(_dessiner_devant)
	tranche = Node2D.new()
	tranche.draw.connect(_dessiner_tranche)

func centre_roue() -> Vector2:
	return Vector2((x0 + x1) * 0.5, y_poutre - 34.0)

func sous(p: Vector2) -> bool:
	if p.distance_to(centre_roue()) < 60.0: return true
	return p.x > x0 + 20.0 and p.x < x1 - 20.0 and p.y > y_poutre - 60.0 and p.y < canal.Y(fond_vu) + 20.0

# Le treuil tourne pendant le voyage : le canal règle « fond_vu », la roue suit.
func tourner(d: float) -> void:
	_angle += d

func _process(dt: float) -> void:
	_t += dt
	modulate = modulate.lerp(Color(1, 1, 1) if actif else Color(0.85, 0.83, 0.82), minf(1.0, dt * 6.0))
	devant.modulate = modulate
	queue_redraw()
	devant.queue_redraw()
	tranche.queue_redraw()

func _y_fond() -> float:
	return canal.Y(fond_vu)

func _y_lisse() -> float:
	return canal.Y(fond_vu + hauteur)

# Derrière l'eau : le fond du bac vu d'en haut, sa paroi du fond, les câbles.
func _draw() -> void:
	var D := canal.D
	var yf := _y_fond()
	var yl := _y_lisse()
	# la paroi du fond, des nervures et des rivets
	var paroi := PackedVector2Array([Vector2(x0, yl) + D, Vector2(x1, yl) + D, Vector2(x1, yf) + D, Vector2(x0, yf) + D])
	draw_polygon(paroi, PackedColorArray([ACIER_CLAIR, ACIER, ACIER_SOMBRE, ACIER]))
	var n := maxi(2, int((x1 - x0) / 44.0))
	for k in range(1, n):
		var x := lerpf(x0, x1, float(k) / n) + D.x
		draw_line(Vector2(x, yl + D.y + 6.0), Vector2(x, yf + D.y - 2.0), ACIER_SOMBRE, 3.0)
		draw_line(Vector2(x + 2.0, yl + D.y + 6.0), Vector2(x + 2.0, yf + D.y - 2.0), Color(1, 1, 1, 0.12), 1.0)
	for y in [yl + D.y + 8.0, yf + D.y - 8.0]:
		var x := x0 + D.x + 10.0
		while x < x1 + D.x - 6.0:
			draw_circle(Vector2(x, y), 1.6, ACIER_SOMBRE)
			x += 14.0
	# la lisse du haut de la paroi
	draw_rect(Rect2(x0 + D.x, yl + D.y - 5.0, x1 - x0, 7.0), ACIER_SOMBRE)
	draw_rect(Rect2(x0 + D.x, yl + D.y - 5.0, x1 - x0, 2.5), ACIER_CLAIR)
	# le fond du bac vu d'en haut (sous l'eau, on le devine)
	var fond := PackedVector2Array([Vector2(x0, yf), Vector2(x1, yf), Vector2(x1, yf) + D, Vector2(x0, yf) + D])
	draw_polygon(fond, PackedColorArray([ACIER, ACIER, ACIER_SOMBRE, ACIER_SOMBRE]))
	# les câbles, de la poutre du fond aux deux bouts de la lisse
	for f in [0.22, 0.78]:
		var x := lerpf(x0, x1, f) + D.x
		draw_line(Vector2(x, y_poutre + D.y), Vector2(x, yl + D.y - 5.0), Color("#2a2420"), 3.0, true)
		draw_line(Vector2(x - 0.8, y_poutre + D.y), Vector2(x - 0.8, yl + D.y - 5.0), Color(1, 1, 1, 0.18), 1.0, true)
		draw_rect(Rect2(x - 5.0, yl + D.y - 11.0, 10.0, 7.0), ACIER_SOMBRE)

# Devant l'eau : la tranche du fond du bac, la poutre du treuil sur les quais,
# la roue rouge, les contrepoids.
func _dessiner_tranche() -> void:
	var yf := _y_fond()
	# la tranche du fond : une poutre d'acier rivetée
	tranche.draw_rect(Rect2(x0, yf, x1 - x0, 13.0), ACIER_SOMBRE)
	tranche.draw_rect(Rect2(x0, yf + 2.0, x1 - x0, 4.0), ACIER)
	var x := x0 + 8.0
	while x < x1 - 4.0:
		tranche.draw_circle(Vector2(x, yf + 9.0), 1.8, Color("#1b242b"))
		x += 13.0

func _dessiner_devant() -> void:
	var D := canal.D
	# la poutre en treillis du treuil, de la coupe au mur du fond
	var g := x0 - 10.0
	var d := x1 + 10.0
	var yp := y_poutre
	var dessus := PackedVector2Array([Vector2(g, yp - 16.0), Vector2(d, yp - 16.0), Vector2(d, yp - 16.0) + D, Vector2(g, yp - 16.0) + D])
	devant.draw_colored_polygon(dessus, Color("#4c5c67"))
	for z in [0.0, 1.0]:
		var o: Vector2 = D * z
		devant.draw_rect(Rect2(g + o.x, yp - 16.0 + o.y, d - g, 4.0), ACIER_SOMBRE)
		devant.draw_rect(Rect2(g + o.x, yp - 1.0 + o.y, d - g, 4.0), ACIER_SOMBRE)
		var k := 0
		var xx := g
		while xx < d - 1.0:
			var x2 := minf(xx + 18.0, d)
			devant.draw_line(Vector2(xx, (yp - 12.0 if k % 2 == 0 else yp) ) + o, Vector2(x2, (yp if k % 2 == 0 else yp - 12.0)) + o, ACIER, 2.5, true)
			xx = x2
			k += 1
	# la roue rouge du treuil, posée au milieu de la poutre
	var c := centre_roue() + D * 0.5
	var r := 0.4 * canal.U
	devant.draw_rect(Rect2(c.x - 4.0, c.y, 8.0, yp - 16.0 + D.y * 0.5 - c.y), Color("#2d2a28"))
	devant.draw_circle(c + Vector2(2, 3), r + 5.0, Color(0, 0, 0, 0.18))
	var tr := Peint.roue()
	if tr:
		# la même roue peinte que celles des portes
		var R := r + 7.5
		devant.draw_set_transform(c, _angle)
		devant.draw_texture_rect(tr, Rect2(-R, -R, 2.0 * R, 2.0 * R), false)
		devant.draw_set_transform(Vector2.ZERO)
	else:
		_roue_dessinee(c, r)
	_fleche(c, r)
	_contrepoids()

func _roue_dessinee(c: Vector2, r: float) -> void:
	devant.draw_arc(c, r, 0.0, TAU, 40, Color("#7c1f13"), 9.0, true)
	devant.draw_arc(c, r, 0.0, TAU, 40, Color("#c8321f"), 6.0, true)
	for k in 6:
		var a := _angle + k * TAU / 6.0
		var v := Vector2(cos(a), sin(a))
		devant.draw_line(c, c + v * (r - 3.0), Color("#7c1f13"), 5.0, true)
		devant.draw_line(c, c + v * (r - 3.0), Color("#c8321f"), 3.0, true)
	devant.draw_circle(c, 6.0, Color("#7c1f13"))
	devant.draw_circle(c, 3.5, Color("#e8a090"))

func _fleche(c: Vector2, r: float) -> void:
	# une flèche douce qui dit où ira le bac au prochain coup, quand on peut
	# le toucher
	if actif:
		var monte := fond_vu < (bas + haut) * 0.5
		var dir := -1.0 if monte else 1.0
		var b := sin(_t * 3.5) * 3.0
		var p := c + Vector2(r + 22.0, dir * b)
		var fl := PackedVector2Array([p + Vector2(0, dir * 11.0), p + Vector2(-9.0, -dir * 4.0), p + Vector2(9.0, -dir * 4.0)])
		devant.draw_colored_polygon(fl, Color("#ffd447"))
		fl.append(fl[0])
		devant.draw_polyline(fl, BRUN, 2.0, true)

func _contrepoids() -> void:
	var yp := y_poutre
	# les contrepoids, à l'extérieur des quais : ils descendent quand le bac monte
	var course := canal.Y(bas) - canal.Y(haut)
	var t := clampf((fond_vu - bas) / maxf(haut - bas, 0.01), 0.0, 1.0)
	var y_cp := yp + 30.0 + course * (1.0 - t) * 0.7
	for xc in [x0 - 34.0, x1 + 34.0]:
		devant.draw_line(Vector2(xc, yp - 8.0), Vector2(xc, y_cp), Color("#2a2420"), 2.5, true)
		devant.draw_rect(Rect2(xc - 11.0, y_cp, 22.0, 30.0), Color("#3a3533"))
		devant.draw_rect(Rect2(xc - 11.0, y_cp, 22.0, 30.0), BRUN, false, 2.0)
		devant.draw_line(Vector2(xc - 7.0, y_cp + 6.0), Vector2(xc - 7.0, y_cp + 24.0), Color(1, 1, 1, 0.15), 2.0)
