class_name Aqueduc
extends Node2D
# ------------------------------------------------------------------
# L'AQUEDUC D'UNE PORTE — le conduit par où l'eau passe d'un bassin à
# l'autre quand on ouvre la vanne. Dessiné en coupe sous le fond des bassins :
# on voit l'eau courir dedans, dans le sens du courant. Il débouche par une
# grille dans le fond de chaque bassin, si bien que l'eau entre par en bas et
# que le bassin se remplit en bouillonnant, sans jet qui pousserait les bateaux.
#
# « chemin » va du bassin de gauche au bassin de droite ; « sens » vaut 1
# quand l'eau va de gauche à droite.
# ------------------------------------------------------------------

var chemin := PackedVector2Array()
var rayon := 8.0
var debit := 0.0
var sens := 1
var vanne := 0.0          # 0 fermée, 1 levée : suit la roue de la porte
var ouverte := false
# Le niveau de l'eau des deux bassins reliés, en y monde : chaque moitié du
# conduit, de part et d'autre de la vanne, est pleine jusqu'au niveau de son
# bassin (Vincent : « l'eau dans les aqueducs doit rester et respecter les
# niveaux des bassins adjacents »). Sous le fond, elle est toujours pleine.
var niveau_g := 1e9
var niveau_d := 1e9
var bulles: CPUParticles2D
var _eau: Line2D           # l'eau dans le conduit, dessinée par shaders/courant.gdshader
var _mat_eau: ShaderMaterial
var _dessus: Node2D        # la vanne et les grilles, par-dessus l'eau du conduit

func preparer(points: PackedVector2Array, r: float) -> void:
	chemin = points
	rayon = r
	var longueur := 0.0
	for k in chemin.size() - 1: longueur += chemin[k].distance_to(chemin[k + 1])
	_mat_eau = ShaderMaterial.new()
	_mat_eau.shader = preload("res://shaders/courant.gdshader")
	_mat_eau.set_shader_parameter("longueur", longueur)
	_eau = Line2D.new()
	_eau.points = chemin
	_eau.width = rayon * 2.0 - 3.0
	_eau.joint_mode = Line2D.LINE_JOINT_ROUND
	_eau.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var blanc := GradientTexture2D.new()
	blanc.width = 4; blanc.height = 4
	_eau.texture = blanc              # sans texture, la ligne n'a pas d'UV
	_eau.material = _mat_eau
	_eau.visible = false
	add_child(_eau)
	_dessus = Node2D.new()
	_dessus.draw.connect(_dessiner_dessus)
	add_child(_dessus)
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
	bulles.z_index = 4             # devant l'eau : les bulles montent de la grille vers la surface
	bulles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	bulles.emission_sphere_radius = r
	bulles.direction = Vector2(0, -1)
	bulles.spread = 30.0
	bulles.gravity = Vector2(0, -220)
	bulles.initial_velocity_min = 40.0
	bulles.initial_velocity_max = 120.0
	bulles.damping_min = 20.0
	bulles.damping_max = 60.0
	bulles.lifetime = 1.4
	bulles.amount = 50
	bulles.scale_amount_min = 0.25
	bulles.scale_amount_max = 0.7
	var fondu := Gradient.new()
	fondu.set_color(0, Color(0.92, 1, 1, 0.85)); fondu.set_color(1, Color(0.92, 1, 1, 0))
	bulles.color_ramp = fondu
	add_child(bulles)

# Le bout par où l'eau sort, et celui par où elle entre.
func sortie() -> Vector2:
	return chemin[chemin.size() - 1] if sens > 0 else chemin[0]

func entree() -> Vector2:
	return chemin[0] if sens > 0 else chemin[chemin.size() - 1]

func couler(force: float, asens: int) -> void:
	debit = force
	if force > 0.0: sens = asens
	bulles.emitting = force > 0.03
	if bulles.emitting:
		bulles.global_position = sortie()
		bulles.modulate.a = clampf(force * 1.2, 0.2, 1.0) * clampf(Reglages.v("bouillon") * 1.5, 0.0, 1.0)
	queue_redraw()

func _process(dt: float) -> void:
	var cible := 1.0 if ouverte else 0.0
	if not is_equal_approx(vanne, cible):
		vanne = move_toward(vanne, cible, dt / 0.5)
		_dessus.queue_redraw()
	# le conduit garde son eau : il n'est sec que là où il monte plus haut que
	# l'eau du bassin auquel il est relié. Partout ailleurs, l'eau y dort, et
	# elle glisse au rythme du débit quand la vanne laisse passer.
	var sec := _parties_seches()
	_eau.visible = not sec
	if sec != _sec_avant:
		_sec_avant = sec
		queue_redraw()
	_mat_eau.set_shader_parameter("debit", debit)
	_mat_eau.set_shader_parameter("sens", float(sens))
	_mat_eau.set_shader_parameter("contraste", Reglages.v("courant_contraste"))
	_mat_eau.set_shader_parameter("allure", Reglages.v("courant_vitesse"))

var _sec_avant := false

# Une partie du conduit est-elle plus haute que l'eau de son bassin ? (Jamais
# avec des aqueducs sous le fond ; la règle reste juste si un tracé change.)
func _parties_seches() -> bool:
	if vanne > 0.5: return false     # vanne ouverte : l'eau remplit tout le conduit
	var milieu := _milieu_x()
	for p in chemin:
		var niveau := niveau_g if p.x <= milieu else niveau_d
		if p.y < niveau - 0.5: return true
	return false

func _milieu_x() -> float:
	return (chemin[1].x + chemin[2].x) * 0.5 if chemin.size() >= 3 else (chemin[0].x + chemin[chemin.size() - 1].x) * 0.5

func _draw() -> void:
	if chemin.size() < 2: return
	# l'ombre du conduit sur la terre, décalée vers le bas à droite, en deux
	# passes pour l'adoucir ; puis le corps de pierre et l'intérieur sombre
	var ombre := PackedVector2Array()
	for p in chemin: ombre.append(p + Vector2(5.0, 7.0))
	draw_polyline(ombre, Color(0.1, 0.04, 0.0, 0.14), rayon * 2.0 + 24.0, true)
	draw_polyline(ombre, Color(0.1, 0.04, 0.0, 0.22), rayon * 2.0 + 12.0, true)
	# l'enveloppe : un cerne sombre, la pierre, puis un grain peint — de
	# petites taches plus sombres et plus claires semées le long du conduit
	draw_polyline(chemin, Color("#4a3d2e"), rayon * 2.0 + 12.0, true)
	draw_polyline(chemin, Color("#8c7f69"), rayon * 2.0 + 9.0, true)
	draw_polyline(chemin, Color("#b8a988"), rayon * 2.0 + 4.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(chemin[0].x * 13.0 + chemin[0].y)
	for k in chemin.size() - 1:
		var a := chemin[k]
		var b := chemin[k + 1]
		var d := (b - a).normalized()
		var nrm := Vector2(-d.y, d.x)
		var l := a.distance_to(b)
		var t := rng.randf_range(4.0, 12.0)
		while t < l:
			var cote := 1.0 if rng.randf() < 0.5 else -1.0
			var p := a + d * t + nrm * cote * (rayon + rng.randf_range(1.5, 4.0))
			var c := Color(0.32, 0.25, 0.17, 0.35) if rng.randf() < 0.6 else Color(1, 0.96, 0.86, 0.3)
			draw_line(p, p + d * rng.randf_range(3.0, 7.0), c, 1.5, true)
			t += rng.randf_range(5.0, 11.0)
	draw_polyline(chemin, Color("#1c2327"), rayon * 2.0, true)
	if _sec_avant:
		# l'eau dormante, tronçon par tronçon, jusqu'au niveau de son bassin
		var milieu := _milieu_x()
		for k in chemin.size() - 1:
			var a := chemin[k]
			var b := chemin[k + 1]
			var niveau := niveau_g if (a.x + b.x) * 0.5 <= milieu else niveau_d
			if a.y < niveau and b.y < niveau: continue
			if a.y < niveau: a = a.lerp(b, (niveau - a.y) / (b.y - a.y))
			if b.y < niveau: b = b.lerp(a, (niveau - b.y) / (a.y - b.y))
			draw_line(a, b, Color(0.13, 0.42, 0.54), rayon * 2.0 - 3.0, true)

# Le point du tuyau sous la porte, où se tient la vanne.
func haut_vanne_point() -> Vector2:
	return (chemin[1] + chemin[2]) * 0.5

# Le haut du logement de la vanne : là où arrive la tige du volant.
func haut_logement() -> float:
	return haut_vanne_point().y - rayon - (rayon * 2.0 + 8.0) - 4.0

func _dessiner_dessus() -> void:
	# La vanne : une plaque de laiton, de la couleur du volant qui la
	# commande, au milieu du conduit sous la porte, dans un logement de pierre
	# sombre au-dessus du tuyau. Fermée, elle barre le tuyau ; ouverte, elle
	# monte dans son logement. (Vincent, 7 octobre 2026 : la petite plaque de
	# 7 px « n'est pas claire pour le joueur ».)
	if chemin.size() >= 3:
		var m := haut_vanne_point()
		var h := rayon * 2.0 + 8.0
		var larg := 20.0
		# le logement, au-dessus du tuyau
		_dessus.draw_rect(Rect2(m.x - larg * 0.5 - 4.0, m.y - rayon - h - 4.0, larg + 8.0, h + 6.0), Color("#3b342d"))
		_dessus.draw_rect(Rect2(m.x - larg * 0.5 - 2.0, m.y - rayon - h - 2.0, larg + 4.0, h + 2.0), Color("#1d1a17"))
		# la plaque, qui monte avec l'ouverture
		var y := m.y - rayon - 3.0 - vanne * (h - 2.0)
		_dessus.draw_rect(Rect2(m.x - larg * 0.5, y, larg, h), Color("#5a3f12"))
		_dessus.draw_rect(Rect2(m.x - larg * 0.5 + 2.0, y + 2.0, larg - 4.0, h - 4.0), Color("#d6a83a"))
		_dessus.draw_line(Vector2(m.x - larg * 0.5 + 3.0, y + 3.0), Vector2(m.x - larg * 0.5 + 3.0, y + h - 4.0), Color(1, 1, 1, 0.35), 1.5)
		# deux rivets et une poignée
		for dy in [0.25, 0.75]:
			_dessus.draw_circle(Vector2(m.x, y + h * dy), 2.0, Color("#5a3f12"))
		# la tige, qui remonte vers le volant
		_dessus.draw_line(Vector2(m.x, y), Vector2(m.x, m.y - rayon - h - 4.0), Color("#b8892c"), 3.0)

	# les brides : un collier de fer boulonné au milieu de chaque tronçon droit
	# (lot 7 : des raccords plus épais, comme le reste du décor) ; aux coudes,
	# en biais, elles faisaient bizarre
	var brides := []
	for k in chemin.size() - 1:
		var l := chemin[k].distance_to(chemin[k + 1])
		if l > 40.0: brides.append([(chemin[k] + chemin[k + 1]) * 0.5, (chemin[k + 1] - chemin[k]).normalized()])
	for br in brides:
		var m: Vector2 = br[0]
		var d: Vector2 = br[1]
		if chemin.size() >= 3 and m.distance_to((chemin[1] + chemin[2]) * 0.5) < 14.0: continue   # la vanne est là
		var nrm := Vector2(-d.y, d.x)
		var demi := rayon + 7.0
		_dessus.draw_line(m - nrm * demi, m + nrm * demi, Color("#2c2622"), 9.0, true)
		_dessus.draw_line(m - nrm * demi, m + nrm * demi, Color("#4e4640"), 6.0, true)
		_dessus.draw_line(m - nrm * demi + d * -1.5, m + nrm * demi + d * -1.5, Color(1, 1, 1, 0.18), 1.2, true)
		for cote in [-1.0, 1.0]:
			_dessus.draw_circle(m + nrm * cote * (demi - 2.5), 2.2, Color("#8a8178"))
	# la grille de chaque bouche, dans le fond du bassin
	for bout in [chemin[0], chemin[chemin.size() - 1]]:
		_dessus.draw_rect(Rect2(bout.x - rayon - 5.0, bout.y - 3.0, 2.0 * rayon + 10.0, 6.0), Color("#3d3833"))
		for k in range(-2, 3):
			_dessus.draw_line(bout + Vector2(k * rayon * 0.42, -3.0), bout + Vector2(k * rayon * 0.42, 3.0), Color("#8a8178"), 2.0)
