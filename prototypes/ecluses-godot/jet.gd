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
# Au doigt maintenu (canal.gd) : la lame occupe toute l'ouverture, du seuil à
# son haut, centrée sur sa trajectoire.
var plein := false
# 0..1 : la nappe s'efface (sans ses bulles) quand la chute devient trop
# courte et que la surface d'en bas se relève à sa place (canal.gd, bosses).
var pale := 1.0
var surface_bas := 0.0          # y de la surface d'en bas, sous le jet
# L'eau d'en bas, quand c'est un bassin (sous une porte) : la lame s'arrête
# sur sa surface À L'ENDROIT où elle tombe. Arrêtée sur surface_bas, mesurée
# 60 px plus loin, elle restait suspendue quelques pixels au-dessus d'une
# surface plus basse (banc visuel, 1-4).
var eau_bas: Node2D = null
var fond_bas := 0.0             # y du fond d'en bas
var depart_x := 0.0             # sous la porte : l'eau glisse de là jusqu'au bord du bloc
var profondeur := Vector2.ZERO
var vantail_x := 0.0            # la fente sous le vantail : son plan,
var haut_veine := 0.0           # le haut de l'eau qui y passe,
var y_seuil := 0.0              # et le seuil  # la largeur du canal en vue oblique (le D du canal)
var _t := 0.0
var _point_chute := Vector2.ZERO
# La chute en aplat (plus bas) : posée par le canal sur l'eau qui passe sous
# une porte. Les autres chutes (rigole, levée, trop-plein, pompe) gardent
# leur dessin en attendant de passer à l'aplat à leur tour.
var aplat := false
# L'écume de l'aplat se dessine sur ce calque, que le canal range juste
# APRÈS l'eau des bassins : dessinée avec la nappe, sous l'eau translucide,
# elle disparaissait dès que le bassin d'en bas avait de l'eau, et le raccord
# redevenait visible (1-4).
var calque_ecume: Node2D = null
var _ecume_c := Vector2.ZERO
var _ecume_f := 0.0
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

# Noyée quand l'eau d'en bas est au-dessus du départ de la lame : elle ne
# tombe pas, elle sort sous la surface et la fait bouillonner. (Basculer en
# bouillon dès que l'eau d'en bas couvrait une partie de l'ouverture faisait
# disparaître d'un coup une cascade encore haute, à la fin d'un remplissage,
# Vincent ; c'est la lame qui s'amincit avec l'écart qui reste, canal.gd.)
func noye() -> bool:
	return origine.y > surface_bas + 2.0

# Le point où une lame lancée à l'horizontale retombe sur la surface d'en bas.
func chute() -> Vector2:
	return _point_chute

func _process(dt: float) -> void:
	var _c0 := Time.get_ticks_usec()
	_process_corps(dt)
	Chrono.ajouter("jet._process", _c0)

func _process_corps(dt: float) -> void:
	_t += dt
	# la nappe pâlit à mesure que l'eau d'amont s'épuise, jusqu'à rien : sans
	# cela, sa face vue d'en haut gardait toute la largeur du canal et
	# disparaissait d'un coup (Vincent)
	# (en aplat, sur 4 px : sur 10, la nappe opaque restait un voile pâle
	# pendant tout le début de l'ouverture)
	modulate.a = clampf(fente / (4.0 if aplat else 10.0), 0.0, 1.0)
	self_modulate.a = pale
	if calque_ecume:
		_placer_ecume()
		calque_ecume.modulate.a = modulate.a * pale
		calque_ecume.queue_redraw()
	bulles.emitting = force > 0.05 and noye()
	if bulles.emitting:
		bulles.global_position = to_global(origine + profondeur * 0.5 + Vector2(sens * (26.0 + 30.0 * force), 0))
		bulles.emission_rect_extents = Vector2(14, 6) + profondeur.abs() * 0.5
		bulles.modulate.a = clampf(force * 1.3, 0.25, 1.0)
	queue_redraw()

func _draw() -> void:
	var _c0 := Time.get_ticks_usec()
	_draw_corps()
	Chrono.ajouter("jet._draw", _c0)

func _draw_corps() -> void:
	if force <= 0.03: return
	if aplat:
		_aplat()
		return
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

# L'épaisseur de la lame.
func _epaisseur() -> float:
	return fente * (0.7 + 0.3 * force) if not plein else fente

# Le tracé de la lame, de la fente à la surface d'en bas, pour l'image en
# cours (le banc visuel le lit sans attendre le dessin : chute() date du
# dernier _draw, une image plus tôt).
func trajectoire() -> PackedVector2Array:
	# presque verticale : l'eau tombe le long de la porte, sans arroser le
	# bateau qui attend dans le sas (Vincent : « la cascade noie le bateau »)
	var vx := (14.0 + 34.0 * force) * sens
	var g := 900.0
	var ep := _epaisseur()
	# Pleine, sans tranche, la nappe se dessine par son DESSUS, au haut de
	# l'ouverture, contre le bas du vantail : tracée par son milieu, elle
	# laissait entre le vantail et la cascade un coin de mur, un creux.
	var o := origine - Vector2(0, ep * 0.5) if plein else origine
	var pts := PackedVector2Array()
	# d'abord à plat, de sous la porte jusqu'au bord du bloc
	if absf(o.x - depart_x) > 2.0:
		pts.append(Vector2(depart_x, o.y))
	var t := 0.0
	var p := o
	while true:
		p = o + Vector2(vx * t, 0.5 * g * t * t)
		pts.append(p)
		var sous := surface_bas
		if eau_bas and p.x >= eau_bas.x0 and p.x <= eau_bas.x1: sous = maxf(surface_bas, eau_bas.hauteur_a(p.x))
		if p.y >= sous or t > 1.5: break
		# (un pas de 0,035 s : à 0,02, la nappe comptait jusqu'à 75 segments
		# dessinés un à un à chaque image, trop pour un petit téléphone)
		t += 0.035
	return pts

# La lame d'eau, de la fente à la surface d'en bas. En vue oblique, la fente
# sous la porte traverse tout le canal, de la coupe au mur du fond : l'eau en
# sort en NAPPE sur toute cette largeur (Vincent : « on dirait un jet d'eau,
# alors que ce devrait être un flux qui prend toute la largeur de l'ouverture
# de porte »). La nappe est la parabole balayée sur la profondeur : son dessus,
# vu d'en haut, avec des filets qui courent dans le sens du courant, et sa
# tranche de devant, plus sombre, de l'épaisseur de la fente. Elle tombe sur
# toute la largeur, et l'écume court le long de la ligne de chute.
func _lame() -> void:
	var ep := _epaisseur()
	var pts := trajectoire()
	_point_chute = pts[pts.size() - 1]
	if pts.size() < 2: return
	var D := profondeur
	if D == Vector2.ZERO:
		# de profil, pas de largeur à montrer : un simple ruban
		draw_polyline(pts, Color(0.2, 0.58, 0.74, 0.88), ep + 2.0, true)
		draw_polyline(pts, Color(0.42, 0.8, 0.92, 0.9), ep * 0.6, true)
		_gerbes(_point_chute)
		return
	# le dessus de la nappe : du bord de devant au bord du fond, plus clair au
	# fond (il reçoit le ciel), un peu transparent
	# segment par segment : d'un seul tenant, le polygone se recoupait quand
	# l'eau coulait vers la gauche (la profondeur part aussi vers la gauche),
	# et Godot refusait de le trianguler — la nappe disparaissait
	var avant_c := Color(0.3, 0.68, 0.84, 0.82)
	var fond_c := Color(0.55, 0.85, 0.95, 0.82)
	if Canal.cartoon:
		avant_c = Color(0.10, 0.78, 0.98, 1.0)
		fond_c = Color(0.45, 0.90, 0.99, 1.0)
	# (en un seul lot de triangles donnés tels quels : dessinés quadrilatère
	# par quadrilatère, chacun triangulé par Godot, ils coûtaient plusieurs ms
	# par image sur un Galaxy A12, lot 0)
	var sommets := PackedVector2Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()
	for q in pts:
		sommets.append(q); couleurs.append(avant_c)
		sommets.append(q + D); couleurs.append(fond_c)
	for k in pts.size() - 1:
		var a := 2 * k
		indices.append_array([a, a + 2, a + 3, a, a + 3, a + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, sommets, couleurs)
	# des filets clairs, à plusieurs profondeurs, qui glissent avec le courant
	for z in [0.2, 0.5, 0.8]:
		for k in 3:
			var f := fmod(_t * 1.5 + k / 3.0 + z * 1.7, 1.0)
			var i := int(f * (pts.size() - 1))
			var j := mini(i + 2, pts.size() - 1)
			if j > i: draw_line(pts[i] + D * z, pts[j] + D * z, Color(0.92, 1, 1, 0.45), 1.6, true)
	# la tranche de devant : l'épaisseur de la nappe, plus sombre
	# (seulement dans la chute, à partir de 6 px sous le bord, et d'un bleu
	# proche de la nappe : foncée dès le bord, elle traçait un trait entre
	# l'eau qui arrive et la cascade — la « cassure » que voyait Vincent)
	# Pas de tranche pour une lame pleine (au doigt maintenu) : épaisse comme
	# toute l'ouverture, cette bande plus sombre se posait là où l'œil attend
	# la surface claire du sas, et l'eau semblait plonger vers la porte — « le
	# creux » de Vincent, vu enfin sur sa vidéo d'écran de l'iPhone. Il a
	# choisi, sur planche, le voile clair sans tranche.
	var chute := PackedVector2Array()
	for q in pts:
		if not plein and q.y > origine.y + 6.0: chute.append(q)
	if chute.size() >= 2:
		# un trait épais plutôt qu'un ruban décalé en hauteur : là où la chute
		# devient verticale, le ruban s'aplatissait et ne se triangulait plus
		draw_polyline(chute, Color(0.22, 0.6, 0.78, 0.85), maxf(ep, 1.5), true)
	draw_polyline(pts, Color(0.85, 0.97, 1.0, 0.5), 1.2, true)

	# l'écume le long de la ligne de chute, sur toute la largeur
	for z in [0.0, 0.5, 1.0]:
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
	# le bouillon monte À la surface d'en bas, contre la porte
	var base := Vector2(origine.x, maxf(origine.y, surface_bas))
	for z in zs:
		for k in 5:
			var f := fmod(_t * 1.2 + k * 0.2 + z, 1.0)
			var c: Vector2 = base + profondeur * z + Vector2(sens * long * f, -6.0 * f)
			var r := (minf(fente, 24.0) * 0.5 + 4.0) * (1.0 + 1.6 * f)
			draw_circle(c, r, Color(0.75, 0.95, 1.0, 0.24 * (1.0 - f) * force))
	_point_chute = origine + Vector2(sens * long * 0.5, 0)

# ------------------------------------------------------------------
# LA CHUTE EN APLAT (style A de la planche du 19 octobre 2026, retenu par
# Vincent). Une nappe d'un seul bleu, opaque, sans tranche sombre ; un
# liseré clair sur le bord de devant, des stries qui descendent ; un
# bourrelet d'écume posé à cheval sur l'eau d'en bas. Les raccords sont
# recouverts au lieu d'être visés : quelques pixels d'écart entre la nappe
# et une surface qui bouge ne font plus de creux. Noyée, il ne reste que
# l'écume, qui s'éteint avec la force : plus de bloc translucide dressé
# contre la porte à la fin d'un remplissage.
# ------------------------------------------------------------------
# entre la surface d'un bassin (#60bfd7) et son eau juste dessous (#2d93a3) :
# le bleu ciel d'abord essayé (#61c2e8) dénotait (Vincent, planche des bleus)
const C_NAPPE := Color("#4aa5bb")
const C_ECUME := Color(0.95, 1.0, 1.0)

func _aplat() -> void:
	var D := profondeur
	# l'eau sous le vantail, d'un seul ton — seulement au-dessus de l'eau
	# d'en bas : noyée, elle faisait une plaque claire sur le sas
	if D != Vector2.ZERO:
		var bas := minf(y_seuil, _surface_sous(vantail_x))
		if bas - haut_veine >= 1.0:
			var a := Vector2(vantail_x, haut_veine)
			var b := Vector2(vantail_x, bas)
			draw_colored_polygon(PackedVector2Array([a, a + D, b + D, b]), C_NAPPE)
	if noye():
		var x := origine.x + sens * (8.0 + 10.0 * force)
		_point_chute = Vector2(x, _surface_sous(x))
		return
	var pts := trajectoire()
	_point_chute = pts[pts.size() - 1]
	if pts.size() < 2: return
	if D == Vector2.ZERO: D = Vector2(0, -1)
	# la nappe : la trajectoire balayée sur toute la largeur du canal (en un
	# lot de triangles donnés tels quels, lot 0)
	var sommets := PackedVector2Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()
	for q in pts:
		sommets.append(q); couleurs.append(C_NAPPE)
		sommets.append(q + D); couleurs.append(C_NAPPE)
	for k in pts.size() - 1:
		var a := 2 * k
		indices.append_array([a, a + 2, a + 3, a, a + 3, a + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, sommets, couleurs)
	# l'épaisseur de devant, du même bleu, et son liseré : seulement dans la
	# chute (sur le dessus du seuil, le liseré faisait un crochet sous la porte)
	var chute := PackedVector2Array()
	for q in pts:
		if q.y > origine.y + 4.0: chute.append(q)
	if chute.size() >= 2:
		if not plein: draw_polyline(chute, C_NAPPE, maxf(_epaisseur(), 2.0), true)
		draw_polyline(chute, Color(C_ECUME, 0.85), 2.5, true)
	# les stries qui descendent, à trois profondeurs
	var n := pts.size() - 1
	var vit := 1.0 + 1.2 * force
	for z in [0.25, 0.55, 0.85]:
		for k in 2:
			var f := fmod(_t * vit + k * 0.5 + z * 1.3, 1.0)
			var i := int(f * n)
			var j := mini(i + maxi(2, n / 5), n)
			if j > i:
				var seg := pts.slice(i, j + 1)
				for m in seg.size(): seg[m] += D * z
				draw_polyline(seg, Color(C_ECUME, 0.7), 3.0, true)

# La surface d'en bas à l'abscisse x (celle du bassin quand elle y passe).
func _surface_sous(x: float) -> float:
	if eau_bas and x >= eau_bas.x0 and x <= eau_bas.x1: return eau_bas.hauteur_a(x)
	return surface_bas

# Le bourrelet d'écume, à cheval sur la surface d'en bas, sur toute la
# largeur de la chute : là où la nappe tombe, ou, noyée, contre la porte.
# (calculé à chaque image, pas au dessin : l'ordre des deux dessins n'est
# pas garanti)
func _placer_ecume() -> void:
	_ecume_f = 0.0
	if force <= 0.03: return
	if noye():
		var x := origine.x + sens * (8.0 + 10.0 * force)
		_ecume_c = Vector2(x, _surface_sous(x))
		_ecume_f = 0.6 * force
	else:
		var pts := trajectoire()
		_ecume_c = pts[pts.size() - 1]
		_ecume_f = force

func dessiner_ecume() -> void:
	if _ecume_f <= 0.02: return
	# des bouillons de tailles inégales qui se chevauchent : réguliers et
	# fins, ils faisaient un collier de perles posé sur l'eau
	var r := 6.0 + 8.0 * _ecume_f
	for k in 11:
		var z := float(k) / 10.0
		var taille := 0.75 + 0.45 * fmod(k * 0.618, 1.0)
		var bat := absf(sin(_t * 6.0 + k * 2.3))
		var c := _ecume_c + profondeur * z + Vector2(sens * 2.0 * (k % 2), -1.0 - 3.0 * bat * _ecume_f)
		calque_ecume.draw_circle(c, r * taille * (0.8 + 0.25 * bat), Color(C_ECUME, 0.92))
