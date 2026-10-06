class_name Jet
extends Node2D
# ------------------------------------------------------------------
# L'EAU QUI PASSE UNE PORTE — rendu seulement.
#
# Deux régimes, selon le bassin qui reçoit :
#   libre    son eau est sous le seuil : une nappe sort de l'ouverture,
#            tombe en parabole et éclabousse là où elle touche
#   noyé     son eau couvre déjà le seuil : rien ne tombe, mais l'eau
#            bouillonne devant la porte (bulles, écume, remous)
# La force suit Torricelli : le débit va comme la racine de la hauteur
# d'eau qui pousse, et s'éteint quand les niveaux se rejoignent.
# ------------------------------------------------------------------

var force := 0.0
var libre := true
var nappe := PackedVector2Array()   # le contour du jet, haut à l'aller, bas au retour
var _uvs := PackedVector2Array()
var eclaboussures: CPUParticles2D
var bulles: CPUParticles2D

func preparer(shader: Shader) -> void:
	var m := ShaderMaterial.new()
	m.shader = shader
	material = m
	z_index = 4
	var rond := GradientTexture2D.new()
	rond.width = 16; rond.height = 16
	rond.fill = GradientTexture2D.FILL_RADIAL
	rond.fill_from = Vector2(0.5, 0.5); rond.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	rond.gradient = g
	eclaboussures = _particules(rond)
	eclaboussures.direction = Vector2(0, -1)
	eclaboussures.spread = 55.0
	eclaboussures.gravity = Vector2(0, 1100)
	eclaboussures.initial_velocity_min = 110.0
	eclaboussures.initial_velocity_max = 290.0
	eclaboussures.lifetime = 0.75
	eclaboussures.amount = 70
	eclaboussures.scale_amount_min = 0.35
	eclaboussures.scale_amount_max = 0.95
	eclaboussures.color = Color(0.9, 0.98, 1.0, 0.95)
	bulles = _particules(rond)
	bulles.direction = Vector2(1, -0.6)
	bulles.spread = 35.0
	bulles.gravity = Vector2(0, -260)
	bulles.initial_velocity_min = 90.0
	bulles.initial_velocity_max = 220.0
	bulles.damping_min = 60.0
	bulles.damping_max = 120.0
	bulles.lifetime = 1.1
	bulles.amount = 60
	bulles.scale_amount_min = 0.25
	bulles.scale_amount_max = 0.7
	bulles.color = Color(0.92, 1.0, 1.0, 0.75)

func _particules(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 4)
	var fondu := Gradient.new()
	fondu.set_color(0, Color(1, 1, 1, 1)); fondu.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fondu
	add_child(p)
	return p

func poser(contour: PackedVector2Array, uvs: PackedVector2Array, aforce: float, alibre: bool) -> void:
	nappe = contour
	_uvs = uvs
	force = aforce
	libre = alibre
	(material as ShaderMaterial).set_shader_parameter("force", force)
	queue_redraw()

func eteindre() -> void:
	force = 0.0
	nappe = PackedVector2Array()
	eclaboussures.emitting = false
	bulles.emitting = false
	queue_redraw()

func _draw() -> void:
	if nappe.size() >= 3 and libre and force > 0.02 and not Geometry2D.triangulate_polygon(nappe).is_empty():
		draw_polygon(nappe, PackedColorArray([Color.WHITE]), _uvs)
