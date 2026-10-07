class_name Jet
extends Node2D
# ------------------------------------------------------------------
# L'EAU QUI PASSE SOUS UNE PORTE ENTROUVERTE (porte simple, sans tuyau —
# Vincent, 7 octobre 2026 : « un joueur s'attend à ce que la porte s'ouvre
# directement »). On touche la roue, la porte se soulève un peu, et l'eau du
# côté haut file par la fente du bas vers le côté bas :
#   - si la fente est au-dessus de l'eau d'en bas : une lame d'eau qui jaillit
#     et retombe en cascade, avec des gerbes là où elle frappe ;
#   - si la fente est noyée : un panache plus clair qui pousse sous la surface,
#     et des bulles qui remontent.
# Les bateaux ne sont pas entraînés : le moteur ne les fait passer qu'une fois
# les deux eaux au même niveau, la porte levée en grand.
#
# Le canal règle chaque image : la fente (origine, hauteur), le sens, la force
# (Torricelli, 0..1) et la surface d'en bas sous le jet.
# ------------------------------------------------------------------

var force := 0.0
var sens := 1.0
var origine := Vector2.ZERO     # le milieu de la fente, côté bas de la porte
var fente := 10.0               # la hauteur de la fente, en pixels
var surface_bas := 0.0          # y de la surface d'en bas, sous le jet
var fond_bas := 0.0             # y du fond d'en bas
var depart_x := 0.0             # sous la porte : l'eau glisse de là jusqu'au bord du bloc
var profondeur := Vector2.ZERO
var vantail_x := 0.0            # la fente sous le vantail : son plan,
var haut_veine := 0.0           # le haut de l'eau qui y passe,
var y_seuil := 0.0              # et le seuil  # la largeur du canal en vue oblique (le D du canal)
var _t := 0.0
var _point_chute := Vector2.ZERO
var bulles: CPUParticles2D

func _ready() -> void:
	# pas de z_index : le canal range la nappe avant les bateaux et les portes,
	# pour qu'elle passe derrière le pilier avant (Vincent : « de l'eau
	# apparaît devant le pilier de la porte, ça passe derrière uniquement »)
	var rond := GradientTexture2D.new()
	rond.width = 16; rond.height = 16
	rond.fill = GradientTexture2D.FILL_RADIAL
	rond.fill_from = Vector2(0.5, 0.5); rond.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	rond.gradient = g
	bulles = CPUParticles2D.new()
	bulles.texture = rond
	bulles.emitting = false
	bulles.local_coords = false
	bulles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bulles.emission_rect_extents = Vector2(14, 6)
	bulles.direction = Vector2(0, -1)
	bulles.spread = 25.0
	bulles.gravity = Vector2(0, -200)
	bulles.initial_velocity_min = 20.0
	bulles.initial_velocity_max = 70.0
	bulles.lifetime = 1.1
	bulles.amount = 40
	bulles.scale_amount_min = 0.25
	bulles.scale_amount_max = 0.6
	var fondu := Gradient.new()
	fondu.set_color(0, Color(0.92, 1, 1, 0.85)); fondu.set_color(1, Color(0.92, 1, 1, 0))
	bulles.color_ramp = fondu
	add_child(bulles)

func noye() -> bool:
	return origine.y > surface_bas + 2.0

# Le point où une lame lancée à l'horizontale retombe sur la surface d'en bas.
func chute() -> Vector2:
	return _point_chute

func _process(dt: float) -> void:
	_t += dt
	# la nappe pâlit à mesure que l'eau d'amont s'épuise, jusqu'à rien : sans
	# cela, sa face vue d'en haut gardait toute la largeur du canal et
	# disparaissait d'un coup (Vincent)
	modulate.a = clampf(fente / 10.0, 0.0, 1.0)
	bulles.emitting = force > 0.05 and noye()
	if bulles.emitting:
		bulles.global_position = to_global(origine + profondeur * 0.5 + Vector2(sens * (26.0 + 30.0 * force), 0))
		bulles.emission_rect_extents = Vector2(14, 6) + profondeur.abs() * 0.5
		bulles.modulate.a = clampf(force * 1.3, 0.25, 1.0)
	queue_redraw()

func _draw() -> void:
	if force <= 0.03: return
	_veine()
	if noye():
		_panache()
	else:
		_lame()

# L'eau qui passe SOUS le vantail, dans la fente, sur toute la largeur du
# canal : sans elle, on voyait le mur du fond entre le bas de la porte et le
# seuil, et la nappe paraissait coupée de son bassin (Vincent).
func _veine() -> void:
	if profondeur == Vector2.ZERO or y_seuil - haut_veine < 1.0: return
	var D := profondeur
	var a := Vector2(vantail_x, haut_veine)
	var b := Vector2(vantail_x, y_seuil)
	draw_polygon(PackedVector2Array([a, a + D, b + D, b]),
		PackedColorArray([Color(0.4, 0.78, 0.92, 0.95), Color(0.55, 0.86, 0.95, 0.95), Color(0.12, 0.45, 0.62, 0.95), Color(0.1, 0.42, 0.6, 0.95)]))
	# des filets qui filent sous la porte
	for k in 3:
		var f := fmod(_t * 1.8 + k / 3.0, 1.0)
		var y := lerpf(haut_veine, y_seuil, 0.2 + 0.6 * float(k) / 2.0)
		var p := Vector2(vantail_x, y) + D * f
		draw_line(p, p + D * 0.18, Color(0.9, 1, 1, 0.5), 1.4, true)

# La lame d'eau, de la fente à la surface d'en bas. En vue oblique, la fente
# sous la porte traverse tout le canal, de la coupe au mur du fond : l'eau en
# sort en NAPPE sur toute cette largeur (Vincent : « on dirait un jet d'eau,
# alors que ce devrait être un flux qui prend toute la largeur de l'ouverture
# de porte »). La nappe est la parabole balayée sur la profondeur : son dessus,
# vu d'en haut, avec des filets qui courent dans le sens du courant, et sa
# tranche de devant, plus sombre, de l'épaisseur de la fente. Elle tombe sur
# toute la largeur, et l'écume court le long de la ligne de chute.
func _lame() -> void:
	# presque verticale : l'eau tombe le long de la porte, sans arroser le
	# bateau qui attend dans le sas (Vincent : « la cascade noie le bateau »)
	var vx := (14.0 + 34.0 * force) * sens
	var g := 900.0
	var pts := PackedVector2Array()
	# d'abord à plat, de sous la porte jusqu'au bord du bloc
	if absf(origine.x - depart_x) > 2.0:
		pts.append(Vector2(depart_x, origine.y))
	var t := 0.0
	var p := origine
	while true:
		p = origine + Vector2(vx * t, 0.5 * g * t * t)
		pts.append(p)
		if p.y >= surface_bas or t > 1.5: break
		t += 0.02
	_point_chute = p
	if pts.size() < 2: return
	var ep := fente * (0.7 + 0.3 * force)
	var D := profondeur
	if D == Vector2.ZERO:
		# de profil, pas de largeur à montrer : un simple ruban
		draw_polyline(pts, Color(0.2, 0.58, 0.74, 0.88), ep + 2.0, true)
		draw_polyline(pts, Color(0.42, 0.8, 0.92, 0.9), ep * 0.6, true)
		_gerbes(_point_chute)
		return
	# le dessus de la nappe : du bord de devant au bord du fond, plus clair au
	# fond (il reçoit le ciel), un peu transparent
	var dessus := PackedVector2Array()
	var couleurs := PackedColorArray()
	for q in pts:
		dessus.append(q)
		couleurs.append(Color(0.3, 0.68, 0.84, 0.82))
	for k in range(pts.size() - 1, -1, -1):
		dessus.append(pts[k] + D)
		couleurs.append(Color(0.55, 0.85, 0.95, 0.82))
	draw_polygon(dessus, couleurs)
	# des filets clairs, à plusieurs profondeurs, qui glissent avec le courant
	for z in [0.15, 0.35, 0.55, 0.75, 0.92]:
		for k in 3:
			var f := fmod(_t * 1.5 + k / 3.0 + z * 1.7, 1.0)
			var i := int(f * (pts.size() - 1))
			var j := mini(i + 2, pts.size() - 1)
			if j > i: draw_line(pts[i] + D * z, pts[j] + D * z, Color(0.92, 1, 1, 0.45), 1.6, true)
	# la tranche de devant : l'épaisseur de la nappe, plus sombre
	var tranche := PackedVector2Array()
	for q in pts: tranche.append(q + Vector2(0, -ep * 0.5))
	for k in range(pts.size() - 1, -1, -1): tranche.append(pts[k] + Vector2(0, ep * 0.5))
	draw_colored_polygon(tranche, Color(0.14, 0.5, 0.68, 0.9))
	draw_polyline(pts, Color(0.85, 0.97, 1.0, 0.5), 1.2, true)
	# l'écume le long de la ligne de chute, sur toute la largeur
	for z in [0.0, 0.25, 0.5, 0.75, 1.0]:
		_gerbes(_point_chute + D * z)
	draw_line(_point_chute, _point_chute + D, Color(0.92, 1, 1, 0.55), 5.0, true)

func _gerbes(c: Vector2) -> void:
	for k in 5:
		var f := fmod(_t * 2.3 + k / 5.0 + c.x * 0.013, 1.0)
		var a := -PI * (0.2 + 0.6 * (float(k) / 4.0))
		var v := Vector2(cos(a), sin(a)) * (10.0 + 20.0 * force)
		var q := c + v * f + Vector2(0, 34.0 * f * f)
		draw_circle(q, (1.0 - f) * (1.8 + 2.2 * force), Color(0.92, 1, 1, 0.75 * (1.0 - f)))

# Le panache sous l'eau : une gerbe plus claire qui pousse depuis la fente et
# s'évase en se perdant, en bouffées.
func _panache() -> void:
	var long := 40.0 + 90.0 * force
	var zs := [0.0] if profondeur == Vector2.ZERO else [0.1, 0.35, 0.6, 0.85]
	for z in zs:
		for k in 5:
			var f := fmod(_t * 1.2 + k * 0.2 + z, 1.0)
			var c: Vector2 = origine + profondeur * z + Vector2(sens * long * f, -6.0 * f)
			var r := (fente * 0.5 + 4.0) * (1.0 + 1.6 * f)
			draw_circle(c, r, Color(0.75, 0.95, 1.0, 0.24 * (1.0 - f) * force))
	_point_chute = origine + Vector2(sens * long * 0.5, 0)
