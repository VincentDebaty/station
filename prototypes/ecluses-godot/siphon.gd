class_name Siphon
extends Node2D
# ------------------------------------------------------------------
# LE SIPHON (chapitre 10, nuit du 7 au 8 octobre 2026) : un tuyau en U
# renversé qui plonge dans un bassin, monte par-dessus ce qui le sépare d'un
# autre — une levée, un bief, une porte — et redescend dans celui-ci. Au
# sommet de l'arche, la roue rouge du robinet d'amorçage : on la touche
# (« amorcer »), l'eau remplit le tuyau et coule du plus haut au plus bas.
# Quand la crépine du bassin qui se vide sort de l'eau, l'air entre : le
# tuyau se vide et le siphon se désamorce.
#
# Le tuyau court sur la berge du fond, derrière les tours des portes ; ses
# deux bouts descendent le long du mur du fond (ou dans la mare) jusqu'à leur
# crépine. L'eau dans le tuyau est celle des aqueducs (aqueduc.gd).
# ------------------------------------------------------------------

var canal: Canal
var k := 0                 # l'objet
var tuyau: Aqueduc
var sommet := Vector2.ZERO # le haut de l'arche, où est la roue
var actif := true
var amorce := false
var roue: Node2D           # la roue et sa flèche, devant tout
var _angle := 0.0
var _vise := 0.0
var _t := 0.0
var poteaux := []          # [x, y du haut, y du pied] : les poteaux qui portent l'arche

func preparer(c: Canal, ak: int, chemin: PackedVector2Array, asommet: Vector2, aamorce: bool) -> void:
	canal = c; k = ak; sommet = asommet; amorce = aamorce
	tuyau = Aqueduc.new()
	tuyau.tuyau_de_pompe = true
	tuyau.preparer(chemin, 0.16 * c.UY)
	tuyau.bulles.visible = false
	tuyau.ouverte = aamorce
	tuyau.vanne = 1.0 if aamorce else 0.0
	add_child(tuyau)
	roue = Node2D.new()
	roue.z_index = 4
	roue.draw.connect(_dessiner_roue)

# Les poteaux de bois sous l'arche, posés sur la berge du fond : sans eux, le
# tuyau flottait en l'air. Dessinés avant le tuyau (il passe devant eux).
func _draw() -> void:
	for po in poteaux:
		var x: float = po[0]
		var y0: float = po[1]
		var y1: float = po[2]
		draw_rect(Rect2(x - 4.5, y0, 9.0, y1 - y0), Color("#3b2414"))
		draw_rect(Rect2(x - 3.0, y0, 6.0, y1 - y0), Color("#7a5232"))
		draw_line(Vector2(x - 1.5, y0 + 2.0), Vector2(x - 1.5, y1 - 2.0), Color(1, 1, 1, 0.15), 1.2)
		# le collier qui tient le tuyau
		draw_rect(Rect2(x - 7.0, y0 - 3.0, 14.0, 6.0), Color("#3a332e"))

func sous(p: Vector2) -> bool:
	return p.distance_to(sommet + Vector2(0, -22.0)) < 52.0

func regler(aamorce: bool) -> void:
	if aamorce and not amorce: _vise += TAU * 1.5
	amorce = aamorce
	tuyau.ouverte = aamorce

func _process(dt: float) -> void:
	_t += dt
	var pas := minf(absf(_vise - _angle), dt * 9.0)
	_angle += signf(_vise - _angle) * pas
	roue.modulate = roue.modulate.lerp(Color(1, 1, 1) if actif else Color(0.8, 0.78, 0.78), minf(1.0, dt * 6.0))
	roue.queue_redraw()

# La roue rouge du robinet, sur l'arche ; et, quand on peut l'amorcer, une
# petite goutte bleue qui l'invite.
func _dessiner_roue() -> void:
	var c := sommet + Vector2(0, -22.0)
	var r := 0.3 * canal.U
	roue.draw_rect(Rect2(c.x - 3.5, c.y, 7.0, sommet.y - c.y), Color("#2d2a28"))
	roue.draw_circle(c + Vector2(2, 3), r + 4.0, Color(0, 0, 0, 0.18))
	var tr := Peint.roue()
	if tr:
		var R := r + 6.0
		roue.draw_set_transform(c, _angle)
		roue.draw_texture_rect(tr, Rect2(-R, -R, 2.0 * R, 2.0 * R), false)
		roue.draw_set_transform(Vector2.ZERO)
	else:
		roue.draw_arc(c, r, 0.0, TAU, 32, Color("#7c1f13"), 8.0, true)
		roue.draw_arc(c, r, 0.0, TAU, 32, Color("#c8321f"), 5.0, true)
	if actif and not amorce:
		# une goutte bleue qui invite à amorcer : la pointe en haut, le ventre
		# rond en bas
		var g := c + Vector2(r + 16.0, -2.0 + 2.5 * sin(_t * 3.5))
		var rr := 6.0
		var goutte := PackedVector2Array([g + Vector2(0, -rr * 2.0)])
		for s in 11:
			var a := lerpf(-PI * 0.5 + 0.6, PI * 1.5 - 0.6, float(s) / 10.0)
			goutte.append(g + Vector2(cos(a), sin(a)) * rr)
		roue.draw_colored_polygon(goutte, Color("#4fb3e0"))
		goutte.append(goutte[0])
		roue.draw_polyline(goutte, Color("#1d4f6b"), 1.8, true)
		roue.draw_circle(g + Vector2(-2.0, 1.0), 1.8, Color(1, 1, 1, 0.8))
