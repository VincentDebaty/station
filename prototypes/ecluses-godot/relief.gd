class_name Relief
extends StyleBox
# ------------------------------------------------------------------
# LE BOIS EN RELIEF — les plaques et les boutons de l'interface, d'après
# l'image d'exemple de Vincent (6 octobre 2026) : « des boutons avec plus de
# relief ». Une pièce de bois épaisse, vue de face et un peu d'en haut :
#
#   l'ombre portée      sous la pièce, décalée vers le bas
#   le cerne            brun presque noir, tout autour
#   la tranche          bois sombre, visible surtout EN BAS (l'épaisseur)
#   la face             bois clair, plus foncée vers le bas, un reflet sur le
#                       bord haut, quelques veines (droites sur une plaque,
#                       en cernes concentriques sur un médaillon rond)
#
# Enfoncée, la face descend sur sa tranche et l'ombre se resserre. Pâle (un
# bouton indisponible), toute la pièce s'efface à moitié.
# ------------------------------------------------------------------

var rayon := 20.0
var enfonce := false
var pale := false

const EPAIS := 7.0      # la tranche visible sous la face, au repos
const CERNE := Color("#3a1d0a")
const TRANCHE := Color("#6b3a16")
const FACE := Color("#b0733a")
const FACE_OMBRE := Color("#8a5124")
const REFLET := Color("#dca06a")
const VEINE := Color(0.33, 0.16, 0.05, 0.28)

static func plaque(r: float, marge_x: float, enfoncee := false, pal := false) -> Relief:
	var s := Relief.new()
	s.rayon = r; s.enfonce = enfoncee; s.pale = pal
	s.content_margin_left = marge_x; s.content_margin_right = marge_x
	# le contenu suit la face : centré sur elle, et il descend avec elle
	s.content_margin_top = 8.0 + (5.0 if enfoncee else 0.0)
	s.content_margin_bottom = 14.0 - (5.0 if enfoncee else 0.0)
	return s

func _a(c: Color) -> Color:
	return Color(c, c.a * (0.5 if pale else 1.0))

func _boite(couleur: Color, r: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = _a(couleur)
	b.set_corner_radius_all(int(maxf(r, 0.0)))
	b.anti_aliasing = true
	b.anti_aliasing_size = 1.2
	return b

func _draw(ci: RID, rect: Rect2) -> void:
	var r := minf(rayon, minf(rect.size.x, rect.size.y) * 0.5)
	var rond := r >= rect.size.y * 0.5 - 0.5 and absf(rect.size.x - rect.size.y) < 1.0
	var bas := 5.0 if enfonce else 0.0          # enfoncée, la face descend sur sa tranche
	# l'ombre portée et le cerne
	var cerne := _boite(CERNE, r)
	cerne.shadow_color = _a(Color(0, 0, 0, 0.38))
	cerne.shadow_size = 5 if enfonce else 8
	cerne.shadow_offset = Vector2(0, 2 if enfonce else 5)
	cerne.draw(ci, rect)
	# la tranche
	var t := rect.grow(-3.0)
	_boite(TRANCHE, r - 3.0).draw(ci, t)
	# la face, posée sur la tranche
	var f := Rect2(t.position + Vector2(2.0, 2.0 + bas), t.size - Vector2(4.0, 4.0 + EPAIS))
	if rond: f = Rect2(f.position + Vector2((f.size.x - f.size.y) * 0.5, 0), Vector2(f.size.y, f.size.y))
	var rf := r - 5.0 if not rond else f.size.y * 0.5
	# la face : un fond plus sombre, puis la face claire un peu plus courte,
	# remontée — il reste en bas un croissant d'ombre, qui la bombe
	_boite(FACE_OMBRE, rf).draw(ci, f)
	var fc := Rect2(f.position, f.size - Vector2(0, f.size.y * 0.14))
	if rond: fc = Rect2(f.position + Vector2(f.size.x * 0.05, 0), f.size * 0.9)
	var face := _boite(FACE, rf if not rond else fc.size.x * 0.5)
	face.border_color = _a(REFLET)
	face.border_width_top = 3
	face.border_blend = true
	face.draw(ci, fc)
	_veines(ci, f, rf, rond)

# Les veines du bois : sur une plaque, trois lignes ondulées en travers ; sur
# un médaillon, des cernes autour d'un cœur décentré, comme une rondelle de
# tronc.
func _veines(ci: RID, f: Rect2, rf: float, rond: bool) -> void:
	var c := _a(VEINE)
	if rond:
		var centre := f.get_center() + Vector2(f.size.x * 0.08, f.size.y * 0.06)
		for k in 3:
			var rr := f.size.x * (0.16 + 0.11 * k)
			var pts := PackedVector2Array()
			for j in 33:
				var a := TAU * j / 32.0
				var w := 1.0 + 0.06 * sin(a * 3.0 + k)
				var p := centre + Vector2(cos(a), sin(a)) * rr * w
				# rester sur la face
				if p.distance_to(f.get_center()) > f.size.x * 0.5 - 3.0:
					if pts.size() > 1: RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([c]), 1.5, true)
					pts = PackedVector2Array()
					continue
				pts.append(p)
			if pts.size() > 1: RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([c]), 1.5, true)
		return
	var x0 := f.position.x + rf * 0.8
	var x1 := f.end.x - rf * 0.8
	if x1 - x0 < 10.0: return
	for k in 3:
		var y := f.position.y + f.size.y * (0.3 + 0.22 * k)
		var pts := PackedVector2Array()
		var n := 12
		for j in n + 1:
			var x := lerpf(x0, x1, float(j) / n)
			pts.append(Vector2(x, y + 1.6 * sin(x * 0.07 + k * 2.1)))
		RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([c]), 1.5, true)
