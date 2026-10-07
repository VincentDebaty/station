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
var _t := 0.0
var _point_chute := Vector2.ZERO
var bulles: CPUParticles2D

func _ready() -> void:
	z_index = 2
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
	bulles.emitting = force > 0.05 and noye()
	if bulles.emitting:
		bulles.global_position = to_global(origine + Vector2(sens * (26.0 + 30.0 * force), 0))
		bulles.modulate.a = clampf(force * 1.3, 0.25, 1.0)
	queue_redraw()

func _draw() -> void:
	if force <= 0.03: return
	if noye():
		_panache()
	else:
		_lame()

# La lame d'eau, de la fente à la surface d'en bas : une parabole, plus
# épaisse au départ, avec des filets clairs qui courent dessus.
func _lame() -> void:
	var vx := (70.0 + 150.0 * force) * sens
	var g := 900.0
	var pts := PackedVector2Array()
	var t := 0.0
	var p := origine
	while true:
		p = origine + Vector2(vx * t, 0.5 * g * t * t)
		pts.append(p)
		if p.y >= surface_bas or t > 1.5: break
		t += 0.02
	_point_chute = p
	if pts.size() < 2: return
	var ep := maxf(fente, 4.0) * (0.75 + 0.35 * force)
	# un voile d'embruns autour, la lame, puis son cœur plus clair
	draw_polyline(pts, Color(0.85, 0.97, 1.0, 0.18), ep + 10.0, true)
	draw_polyline(pts, Color(0.2, 0.58, 0.74, 0.88), ep + 2.0, true)
	draw_polyline(pts, Color(0.42, 0.8, 0.92, 0.9), ep * 0.6, true)
	# des reflets doux qui glissent dans le sens du jet
	for k in 6:
		var f := fmod(_t * 1.4 + k / 6.0, 1.0)
		var i := int(f * (pts.size() - 1))
		var j := mini(i + 1, pts.size() - 1)
		if j > i: draw_line(pts[i], pts[j], Color(0.92, 1, 1, 0.4), maxf(ep * 0.25, 1.2), true)
	# les gerbes là où elle frappe
	for k in 6:
		var f := fmod(_t * 2.3 + k / 6.0, 1.0)
		var a := -PI * (0.2 + 0.6 * (float(k) / 5.0))
		var v := Vector2(cos(a) * sens * 0.6 + cos(a) * 0.4, sin(a)) * (14.0 + 26.0 * force)
		var q := _point_chute + v * f + Vector2(0, 40.0 * f * f)
		draw_circle(q, (1.0 - f) * (2.0 + 2.5 * force), Color(0.92, 1, 1, 0.8 * (1.0 - f)))
	draw_arc(_point_chute, 10.0 + 8.0 * force, PI, TAU, 16, Color(0.92, 1, 1, 0.5), 2.5, true)

# Le panache sous l'eau : une gerbe plus claire qui pousse depuis la fente et
# s'évase en se perdant, en bouffées.
func _panache() -> void:
	var long := 40.0 + 90.0 * force
	for k in 5:
		var f := fmod(_t * 1.2 + k * 0.2, 1.0)
		var c := origine + Vector2(sens * long * f, -6.0 * f)
		var r := (fente * 0.5 + 4.0) * (1.0 + 1.6 * f)
		draw_circle(c, r, Color(0.75, 0.95, 1.0, 0.3 * (1.0 - f) * force))
	_point_chute = origine + Vector2(sens * long * 0.5, 0)
