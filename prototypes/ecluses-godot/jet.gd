class_name Jet
extends Node2D
# ------------------------------------------------------------------
# UNE CHUTE D'EAU : sous une porte entrouverte, par-dessus une porte fermée
# (trop-plein), au bout d'une rigole, par-dessus une levée, au bec d'une
# pompe. Toutes se dessinent de la même façon, en APLAT (planche du
# 19 octobre 2026, retenu par Vincent) :
#   - si le départ est au-dessus de l'eau d'en bas : une nappe d'un seul bleu
#     qui tombe, et un bourrelet d'écume à cheval sur l'eau d'en bas ;
#   - si le départ est noyé : l'écume seule, contre la porte, et des bulles.
# La chute recouvre ses raccords au lieu de les viser : quelques pixels
# d'écart entre la nappe et une surface qui bouge ne font plus de creux, et
# il n'y a pas d'état à basculer (l'ancienne chute réaliste — parabole,
# tranche sombre, gerbes, panache, lame pleine, pentes, bosses — en avait
# demandé des dizaines de retouches).
# Les bateaux ne sont pas entraînés : le moteur ne les fait passer qu'une fois
# les deux eaux au même niveau, la porte levée en grand.
#
# Le canal règle chaque image : le départ (origine, épaisseur), le sens, la
# force (Torricelli, 0..1) et la surface d'en bas sous la chute.
# ------------------------------------------------------------------

var force := 0.0
var sens := 1.0
var origine := Vector2.ZERO     # le milieu de la fente, côté bas de la porte
var fente := 10.0               # la hauteur de la fente, en pixels
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
# L'écume se dessine sur ce calque, que le canal range juste
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
	# disparaissait d'un coup (Vincent) — sur 4 px : sur 10, la nappe opaque
	# restait un voile pâle pendant tout le début de l'ouverture
	modulate.a = clampf(fente / 4.0, 0.0, 1.0)
	if calque_ecume:
		_placer_ecume()
		# (la transparence se pose sur le CanvasGroup qui porte le calque : sur
		# chaque rond, les chevauchements se voyaient en cercles plus opaques)
		(calque_ecume.get_parent() as CanvasItem).modulate.a = modulate.a * A_ECUME
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
	_aplat()

# L'épaisseur de la nappe.
func _epaisseur() -> float:
	return fente * (0.7 + 0.3 * force)

# Le tracé de la lame, de la fente à la surface d'en bas, pour l'image en
# cours (le banc visuel le lit sans attendre le dessin : chute() date du
# dernier _draw, une image plus tôt).
func trajectoire() -> PackedVector2Array:
	# presque verticale : l'eau tombe le long de la porte, sans arroser le
	# bateau qui attend dans le sas (Vincent : « la cascade noie le bateau »)
	var vx := (14.0 + 34.0 * force) * sens
	var g := 900.0
	var o := origine
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
# Un blanc pâle et fondu dans l'eau : le blanc pur (écume opaque, stries et
# liseré marqués) faisait trop de très blanc (Vincent, planche des blancs)
const C_ECUME := Color("#e2f6fa")
const A_LISERE := 0.35
const A_STRIE := 0.32
const A_ECUME := 0.62

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
		draw_polyline(chute, C_NAPPE, maxf(_epaisseur(), 2.0), true)
		draw_polyline(chute, Color(C_ECUME, A_LISERE), 2.5, true)
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
				draw_polyline(seg, Color(C_ECUME, A_STRIE), 3.0, true)

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
	# sur la largeur de la chute ; sans largeur (le bec d'une pompe, vu de
	# profil), étalée à plat de part et d'autre : tous au même point, les
	# bouillons faisaient un disque pâle bien rond
	var large := profondeur
	var depart := _ecume_c
	if large == Vector2.ZERO:
		large = Vector2(r * 3.0, 0)
		depart = _ecume_c - large * 0.5
	for k in 11:
		var z := float(k) / 10.0
		var taille := 0.75 + 0.45 * fmod(k * 0.618, 1.0)
		var bat := absf(sin(_t * 6.0 + k * 2.3))
		var c := depart + large * z + Vector2(sens * 2.0 * (k % 2), -1.0 - 3.0 * bat * _ecume_f)
		calque_ecume.draw_circle(c, r * taille * (0.8 + 0.25 * bat), C_ECUME)
