class_name Main
extends Node2D
# ------------------------------------------------------------------
# LA MAIN QUI MONTRE (9 octobre 2026, d'après le test de la fille de
# Vincent, 10 ans, sans aide : elle n'a pas vu qu'on pouvait toucher les
# roues). Une main de dessin animé, l'index tendu, qui vient se poser sur ce
# qu'il faut toucher et tapote : elle s'enfonce, un rond s'élargit sous le
# doigt, elle se relève. Pas un mot.
#
# Le jeu lui donne une cible (« viser ») ou la cache (« cacher ») ; elle
# glisse d'une cible à la suivante et apparaît en fondu.
# art/main.png, si elle existe, remplace le dessin (prompt dans ASSETS.md) :
# l'image doit avoir le bout de l'index en haut à gauche.
# ------------------------------------------------------------------

var cible := Vector2.ZERO
var montree := false
var _pos := Vector2.ZERO
var _alpha := 0.0
var _t := 0.0
var _image: Texture2D

const CREME := Color("#fff3dc")
const BRUN := Color("#5b3416")

func _ready() -> void:
	z_index = 20
	if ResourceLoader.exists("res://art/main.png"): _image = Images.reduire("res://art/main.png", 220)

func viser(p: Vector2) -> void:
	if not montree or _alpha < 0.05: _pos = p + Vector2(60, 70)
	cible = p
	montree = true

func cacher() -> void:
	montree = false

func _process(dt: float) -> void:
	_t += dt
	_alpha = move_toward(_alpha, 1.0 if montree else 0.0, dt * 3.0)
	_pos = _pos.lerp(cible, minf(1.0, dt * 6.0))
	visible = _alpha > 0.01
	modulate.a = _alpha
	queue_redraw()

func _draw() -> void:
	# un tapotement toutes les 1,1 s : la main descend (0 → 0,18 s), appuie,
	# remonte ; un rond part du bout du doigt au moment où elle appuie
	var cycle := fmod(_t, 1.1)
	var appui := 0.0
	if cycle < 0.18: appui = cycle / 0.18
	elif cycle < 0.36: appui = 1.0 - (cycle - 0.18) / 0.18
	var bout := _pos + Vector2(0, -10.0 * (1.0 - appui))
	if cycle > 0.16 and cycle < 0.75:
		var k := (cycle - 0.16) / 0.59
		draw_arc(_pos, 10.0 + 30.0 * k, 0.0, TAU, 32, Color(1, 1, 1, 0.85 * (1.0 - k)), 4.0, true)
		draw_arc(_pos, 10.0 + 30.0 * k, 0.0, TAU, 32, Color(BRUN, 0.35 * (1.0 - k)), 1.5, true)
	var s := 1.15 * (1.0 - 0.06 * appui)     # en pixels de l'écran, bien visible pour un enfant
	if _image:
		var h := 110.0 * s
		var w := h * _image.get_width() / _image.get_height()
		draw_texture_rect(_image, Rect2(bout, Vector2(w, h)), false)
		return
	_dessiner_main(bout, s)

# La main dessinée : la paume en bas à droite du doigt, l'index tendu vers le
# haut à gauche (vers la cible), le pouce replié sur le côté, deux doigts
# repliés ; un liseré brun, un reflet.
func _dessiner_main(bout: Vector2, s: float) -> void:
	var ang := -0.55
	var xf := Transform2D(ang, Vector2(s, s), 0.0, bout)
	draw_set_transform_matrix(xf)
	# l'ombre
	_forme(Vector2(4, 6), Color(0, 0, 0, 0.22), 0.0)
	_forme(Vector2.ZERO, BRUN, 3.5)
	_forme(Vector2.ZERO, CREME, 0.0)
	# les plis des doigts repliés, l'ongle
	draw_arc(Vector2(16, 64), 9.0, PI * 0.1, PI * 0.9, 8, Color(BRUN, 0.6), 2.0, true)
	draw_arc(Vector2(28, 64), 9.0, PI * 0.1, PI * 0.9, 8, Color(BRUN, 0.6), 2.0, true)
	draw_rect(Rect2(-4.5, 3.0, 9.0, 8.0), Color("#f5d9c4"))
	draw_line(Vector2(-6, 30), Vector2(-6, 52), Color(1, 1, 1, 0.6), 3.0, true)
	draw_set_transform(Vector2.ZERO)

# La silhouette, grossie de « bord » pixels pour le liseré.
func _forme(o: Vector2, c: Color, bord: float) -> void:
	# l'index, de son bout (0,0) à la paume
	draw_rect(Rect2(o + Vector2(-8 - bord, 6 - bord), Vector2(16 + 2 * bord, 44 + bord)), c)
	draw_circle(o + Vector2(0, 7), 8.0 + bord, c)
	# la paume
	draw_circle(o + Vector2(14, 64), 22.0 + bord, c)
	draw_rect(Rect2(o + Vector2(-8 - bord, 44), Vector2(44 + 2 * bord, 28)), c)
	# les doigts repliés, en bosses
	for x in [16.0, 28.0, 38.0]:
		draw_circle(o + Vector2(x, 52), 9.0 + bord, c)
	# le pouce, sur le côté gauche
	var pouce := PackedVector2Array([o + Vector2(-8 - bord, 56), o + Vector2(-26 - bord, 46 - bord), o + Vector2(-30 - bord, 54), o + Vector2(-10, 74 + bord)])
	draw_colored_polygon(pouce, c)
	draw_circle(o + Vector2(-26, 50), 6.0 + bord, c)
