class_name Hausse
extends Node2D
# ------------------------------------------------------------------
# UNE HAUSSE (chapitre 3, 7 octobre 2026) : un mur de pierre jusqu'à « min »,
# couronné de planches de bois amovibles jusqu'à la crête courante. L'eau passe
# par-dessus la dernière planche ; les bateaux ne passent pas. Comme la porte,
# elle est vue un peu de la gauche : les planches sont empilées EN TRAVERS du
# canal, entre un poteau à l'avant et un poteau au fond, et on voit leur face.
#
# Au doigt : toucher les planches en retire une, toucher la place vide au-dessus
# en ajoute une. Les places vides jusqu'à « max » sont marquées en pointillés.
# ------------------------------------------------------------------

var canal: Canal
var i := 0
var vue := 0.0           # la crête affichée, qui glisse vers « cible »
var cible := 0.0
var y_min := 0.0
var y_max := 0.0
var xc := 0.0
var _planches: Node2D    # dans la couche des vantaux, vues à travers l'eau
var _fond: Node2D        # le poteau du fond, derrière l'eau et les bateaux
const POTEAU := 9.0

func preparer(c: Canal, ai: int, crete: float, couche: Node2D, arriere: Node2D) -> void:
	canal = c; i = ai
	var l: Dictionary = c.N["liaisons"][ai]
	vue = crete; cible = crete
	y_min = c.Y(float(l["min"])); y_max = c.Y(float(l["max"]))
	xc = c.X(c.gl[ai][0] + c.gl[ai][1]) * 0.5
	_planches = Node2D.new()
	_planches.draw.connect(_dessiner_planches)
	couche.add_child(_planches)
	_fond = Node2D.new()
	_fond.draw.connect(_dessiner_poteau.bind(true))
	(arriere if arriere else couche).add_child(_fond)

func regler(crete: float) -> void:
	cible = crete

func arrive() -> bool:
	return absf(vue - cible) < 0.01

# Ce que fait un toucher en p : « hausser », « abaisser », ou rien.
func geste(p: Vector2) -> String:
	var D := canal.D
	var x0 := xc + minf(D.x, 0.0) - POTEAU - 16.0
	var x1 := xc + maxf(D.x, 0.0) + POTEAU + 16.0
	if p.x < x0 or p.x > x1: return ""
	var haut := canal.Y(vue)
	if p.y > y_min + 8.0 or p.y < y_max - 0.6 * canal.UY: return ""
	return "hausser" if p.y < haut else "abaisser"

func _process(dt: float) -> void:
	if not is_equal_approx(vue, cible):
		vue = move_toward(vue, cible, dt * 3.0)
		_planches.queue_redraw()
	queue_redraw()

func _draw() -> void:
	_dessiner_poteau_sur(self, false)

func _dessiner_poteau(fond: bool) -> void:
	_dessiner_poteau_sur(_fond, fond)

# Un poteau de pierre (avant, ou au fond décalé de D), du min au max, avec sa
# rainure sombre où glissent les planches.
func _dessiner_poteau_sur(n: Node2D, fond: bool) -> void:
	var o := canal.D if fond else Vector2.ZERO
	var haut := y_max - 0.25 * canal.UY
	var r := Rect2(xc - POTEAU + o.x, haut + o.y, POTEAU * 2.0, y_min - haut)
	n.draw_rect(r, Color("#c9b48f") if not fond else Color("#a8946f"))
	n.draw_rect(Rect2(r.position.x, r.position.y, 3.0, r.size.y), Color(0.15, 0.08, 0.02, 0.35))
	n.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), Color("#e6d6b4"))
	n.draw_line(Vector2(xc + o.x, haut + o.y + 4.0), Vector2(xc + o.x, y_min + o.y), Color(0.2, 0.12, 0.05, 0.6), 2.0)

# Les planches : la face de la pile, en travers du canal (de la coupe au plan
# du fond), une ligne sombre entre deux planches, des ferrures aux deux bouts ;
# au-dessus, les places vides en pointillés jusqu'au max.
func _dessiner_planches() -> void:
	var D := canal.D
	var UY := canal.UY
	var haut := canal.Y(vue)
	var n := _planches
	if haut < y_min - 0.5:
		var face := PackedVector2Array([Vector2(xc, haut), Vector2(xc + D.x, haut + D.y), Vector2(xc + D.x, y_min + D.y), Vector2(xc, y_min)])
		n.draw_colored_polygon(face, Color("#9a6332"))
		# le grain, et les joints entre planches
		var y := y_min
		var k := 0
		while y > haut + 1.0:
			var ya := maxf(y - UY, haut)
			var teinte := Color("#a86d38") if k % 2 == 0 else Color("#93592c")
			n.draw_colored_polygon(PackedVector2Array([Vector2(xc, ya), Vector2(xc + D.x, ya + D.y), Vector2(xc + D.x, y + D.y), Vector2(xc, y)]), teinte)
			for g in 3:
				var f := (g + 1) / 4.0
				var yy := lerpf(ya, y, f)
				n.draw_line(Vector2(xc - 1, yy), Vector2(xc + D.x + 1, yy + D.y), Color(0.35, 0.18, 0.06, 0.25), 1.0)
			n.draw_line(Vector2(xc, y), Vector2(xc + D.x, y + D.y), Color("#4a2a12"), 2.0)
			for z in [0.12, 0.88]:
				n.draw_circle(Vector2(xc, (ya + y) * 0.5) + D * z, 2.4, Color("#2b2622"))
			y -= UY
			k += 1
		# le dessus de la planche du haut, vu d'en haut
		n.draw_colored_polygon(PackedVector2Array([Vector2(xc, haut), Vector2(xc + D.x, haut + D.y), Vector2(xc + D.x + 6.0, haut + D.y - 2.0), Vector2(xc + 6.0, haut - 2.0)]), Color("#c08a52"))
		n.draw_polyline(face + PackedVector2Array([face[0]]), Color("#3a2410"), 2.5)
	# les places vides : où l'on peut ajouter une planche
	var y2 := haut
	while y2 > y_max + 2.0:
		var ya2 := maxf(y2 - UY, y_max)
		var cadre := PackedVector2Array([Vector2(xc, ya2), Vector2(xc + D.x, ya2 + D.y), Vector2(xc + D.x, y2 + D.y), Vector2(xc, y2), Vector2(xc, ya2)])
		for j in cadre.size() - 1:
			n.draw_dashed_line(cadre[j], cadre[j + 1], Color(1, 0.96, 0.86, 0.75), 2.0, 6.0)
		y2 -= UY
