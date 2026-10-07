class_name Pont
extends Node2D
# ------------------------------------------------------------------
# LE PONT BAS (chapitre 11, nuit du 7 au 8 octobre 2026) : un pont de
# pierre qui enjambe le canal là où deux biefs se rejoignent par un passage
# libre. Vu comme les portes : un pilier devant (dans le plan de la coupe),
# un pilier au fond, et entre eux le tablier, dont on voit le dessus (une
# route pavée, deux parapets) et la face de gauche. Les bateaux passent
# dessous, entre les deux piliers — si l'eau est assez basse pour leur
# cheminée.
#
# Sous le tablier, à gauche, une plaque ronde de hauteur limitée (deux
# flèches qui se font face, sans chiffre) : on comprend qu'il ne faut pas
# que l'eau monte trop.
#
# Deux nœuds : « fond » (le pilier du fond, derrière l'eau et les bateaux)
# et celui-ci (le pilier avant et le tablier, devant).
# ------------------------------------------------------------------

var canal: Canal
var xc := 0.0              # le milieu du passage (x monde, plan de la coupe)
var y_dessous := 0.0       # le dessous du tablier (y monde)
var y_pied := 0.0          # le pied des piliers (y monde)
var fond: Node2D
const PILIER := 20.0
const EPAISSEUR := 26.0    # le tablier
const LARGE := 36.0        # le tablier déborde des piliers de chaque côté
const PIERRE := Color("#d9c7a2")
const PIERRE_SOMBRE := Color("#a8926c")
const BRUN := Color("#3b2414")

func preparer(c: Canal, axc: float, ay_dessous: float, ay_pied: float) -> void:
	canal = c; xc = axc; y_dessous = ay_dessous; y_pied = ay_pied
	fond = Node2D.new()
	fond.draw.connect(_dessiner_fond)

func _pierre_rect(n: CanvasItem, r: Rect2, clair: Color, sombre: Color) -> void:
	n.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([clair, clair.lerp(sombre, 0.3), sombre, clair.lerp(sombre, 0.6)]))
	# les joints des pierres, en assises
	var y := r.position.y + 14.0
	var rang := 0
	while y < r.end.y - 2.0:
		n.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.35, 0.27, 0.17, 0.35), 1.2)
		var x := r.position.x + (8.0 if rang % 2 == 0 else 18.0)
		while x < r.end.x - 3.0:
			n.draw_line(Vector2(x, y - 14.0), Vector2(x, y), Color(0.35, 0.27, 0.17, 0.25), 1.0)
			x += 20.0
		y += 14.0
		rang += 1
	n.draw_rect(r, Color(0.3, 0.22, 0.13, 0.6), false, 1.5)

# Le pilier du fond, dans le plan du mur du fond.
func _dessiner_fond() -> void:
	var D := canal.D
	var r := Rect2(xc - PILIER + D.x, y_dessous + D.y, 2.0 * PILIER, y_pied - y_dessous)
	_pierre_rect(fond, r, PIERRE.darkened(0.12), PIERRE_SOMBRE.darkened(0.15))
	# l'ombre du tablier sur le haut du pilier
	fond.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 12.0), Color(0, 0, 0, 0.25))

func _draw() -> void:
	var D := canal.D
	var g := xc - LARGE
	var d := xc + LARGE
	var y0 := y_dessous - EPAISSEUR       # le dessus du tablier
	var y1 := y_dessous
	# la face gauche du tablier : une parallélogramme de pierre, dans l'ombre
	var gauche := PackedVector2Array([Vector2(g, y0), Vector2(g, y1), Vector2(g + D.x, y1 + D.y), Vector2(g + D.x, y0 + D.y)])
	draw_polygon(gauche, PackedColorArray([PIERRE_SOMBRE, PIERRE_SOMBRE.darkened(0.2), PIERRE_SOMBRE.darkened(0.3), PIERRE_SOMBRE.darkened(0.1)]))
	# un arc en relief sur cette face : la voûte, qu'on devine
	var arc := PackedVector2Array()
	for k in 13:
		var t := float(k) / 12.0
		var p := Vector2(g, y1) + D * t
		p.y -= sin(t * PI) * 7.0
		arc.append(p)
	draw_polyline(arc, Color(0.3, 0.22, 0.13, 0.55), 2.0, true)
	# le dessus : la route pavée
	var dessus := PackedVector2Array([Vector2(g, y0), Vector2(d, y0), Vector2(d + D.x, y0 + D.y), Vector2(g + D.x, y0 + D.y)])
	draw_polygon(dessus, PackedColorArray([Color("#b9a98c"), Color("#b9a98c"), Color("#9e8f74"), Color("#9e8f74")]))
	for k in range(1, 6):
		var t := float(k) / 6.0
		draw_line(Vector2(g, y0) + D * t, Vector2(d, y0) + D * t, Color(0.35, 0.3, 0.22, 0.35), 1.0)
	# les deux parapets, le long des bords du tablier
	for x in [g, d - 7.0]:
		var p := PackedVector2Array([Vector2(x, y0 - 9.0), Vector2(x + 7.0, y0 - 9.0), Vector2(x + 7.0 + D.x, y0 - 9.0 + D.y), Vector2(x + D.x, y0 - 9.0 + D.y)])
		draw_colored_polygon(p, Color("#e6d6b4"))
		draw_colored_polygon(PackedVector2Array([Vector2(x, y0 - 9.0), Vector2(x + 7.0, y0 - 9.0), Vector2(x + 7.0, y0), Vector2(x, y0)]), PIERRE_SOMBRE)
	# la tranche avant du tablier, dans le plan de la coupe
	_pierre_rect(self, Rect2(g, y0, d - g, EPAISSEUR), PIERRE, PIERRE_SOMBRE)
	# le pilier avant, sous le tablier, jusqu'au pied
	_pierre_rect(self, Rect2(xc - PILIER, y1, 2.0 * PILIER, y_pied - y1), PIERRE, PIERRE_SOMBRE)
	draw_rect(Rect2(xc - PILIER, y1, 2.0 * PILIER, 10.0), Color(0, 0, 0, 0.22))
	# la plaque de hauteur limitée, sous le tablier, à gauche du pilier
	var c := Vector2(g - 2.0, y1 + 16.0)
	draw_line(Vector2(c.x + 6.0, y1), c, Color("#4a4440"), 3.0, true)
	draw_circle(c, 13.0, BRUN)
	draw_circle(c, 11.5, Color("#d9412d"))
	draw_circle(c, 8.0, Color("#fdf6e6"))
	# deux flèches qui se font face (haut et bas), la limite entre elles
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -7), c + Vector2(4, -7), c + Vector2(0, -2)]), BRUN)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 7), c + Vector2(4, 7), c + Vector2(0, 2)]), BRUN)
	draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), BRUN, 1.5)
