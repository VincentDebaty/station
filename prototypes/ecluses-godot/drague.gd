class_name Drague
extends Node2D
# ------------------------------------------------------------------
# LA VASE ET LA DRAGUE (chapitre 16, nuit du 7 au 8 octobre 2026) : le port
# s'est envasé. Une couche de vase brune couvre son fond de pierre ; un
# bateau échoué dessus ne flotte plus. Sur la berge du fond, une petite grue
# de bois (une potence et son treuil) tient une benne à griffes : toucher la
# grue (le moteur : « draguer ») descend la benne dans l'eau, elle remonte
# pleine de vase qui dégoutte, et la vide sur un tas qui grossit au bord du
# quai. La vase baisse d'un cran ; l'eau la remplace, et la mer refait le
# niveau.
#
# Deux nœuds : celui-ci, sur la berge du fond (la grue, la benne, le tas,
# derrière l'eau), et « couche » (la vase, avant l'eau : sa face dans la
# coupe et son dessus vu d'en haut).
# ------------------------------------------------------------------

signal coup_fini

var canal: Canal
var ib := 0
var x0 := 0.0               # la vase, d'un bout du bassin à l'autre (x monde)
var x1 := 0.0
var y_pierre := 0.0         # le fond de pierre (y monde)
var fond_vu := 0.0          # le dessus de la vase, tel qu'affiché (unités)
var godets := 0             # la vase déjà draguée (nombre de godets), pour le tas
var pied := Vector2.ZERO    # le pied de la grue, sur la berge du fond
var actif := true
var couche: Node2D
var _coup := -1.0
var _t := 0.0
var _gouttes := []
var _rng := RandomNumberGenerator.new()

const BOIS := Color("#8a5a33")
const BRUN := Color("#2e1a0b")
const VASE := Color("#6b4f2e")
const VASE_CLAIRE := Color("#8a6a40")

func preparer(c: Canal, abassin: int, ax0: float, ax1: float, apierre: float, afond: float, agodets: int, apied: Vector2) -> void:
	canal = c; ib = abassin; x0 = ax0; x1 = ax1; y_pierre = apierre; fond_vu = afond; godets = agodets; pied = apied
	_rng.seed = 17
	couche = Node2D.new()
	couche.draw.connect(_dessiner_couche)

func sous(p: Vector2) -> bool:
	return Rect2(pied.x - 70.0, pied.y - 150.0, 150.0, 170.0).has_point(p)

func draguer() -> void:
	_coup = 0.0

# La benne : sa hauteur sous le bout de la flèche, selon le temps du coup.
# 0 → 0,7 s elle descend dans l'eau, 0,7 → 1,4 s elle remonte pleine, 1,4 →
# 1,9 s la grue pivote et la vide sur le tas.
func _process(dt: float) -> void:
	_t += dt
	if _coup >= 0.0:
		_coup += dt
		if _coup > 0.7 and _coup - dt <= 0.7: coup_fini.emit()
		if _coup > 1.0 and _coup < 1.6 and _rng.randf() < dt * 25.0:
			_gouttes.append([_monde(_benne() + Vector2(_rng.randf_range(-8, 8), 10.0)), 0.0])
		if _coup > 2.0: _coup = -1.0
	for g in _gouttes:
		g[1] += 500.0 * dt
		g[0].y += g[1] * dt
	_gouttes = _gouttes.filter(func(g): return g[0].y < canal.Y(canal.vue_niv[ib]) + canal.D.y * 0.5)
	modulate = modulate.lerp(Color(1, 1, 1) if actif else Color(0.82, 0.8, 0.8), minf(1.0, dt * 6.0))
	queue_redraw()
	couche.queue_redraw()

func _bout_fleche() -> Vector2:
	# la flèche pivote vers le tas pendant le vidage
	var a := 0.0
	if _coup > 1.4 and _coup < 2.0: a = sin((_coup - 1.4) / 0.6 * PI) * 0.6
	return pied + Vector2(-70.0 * cos(a), -120.0 + 70.0 * sin(a) * 0.3)

# La grue est dessinée agrandie autour de son pied : un point de son dessin
# (« local ») et le même point dans le monde.
const ECHELLE := 1.3
func _monde(p: Vector2) -> Vector2:
	return pied + (p - pied) * ECHELLE

func _local(p: Vector2) -> Vector2:
	return pied + (p - pied) / ECHELLE

func _benne() -> Vector2:
	var b := _bout_fleche()
	# jusqu'à la vase, à mi-profondeur (en coordonnées du dessin)
	var bas := _local(Vector2(0, canal.Y(fond_vu) + canal.D.y * 0.5)).y - b.y - 6.0
	var haut := 40.0
	var d := haut
	if _coup >= 0.0 and _coup < 0.7: d = lerpf(haut, bas, _coup / 0.7)
	elif _coup >= 0.7 and _coup < 1.4: d = lerpf(bas, haut, (_coup - 0.7) / 0.7)
	return b + Vector2(0, d)

func _draw() -> void:
	# toute la grue un peu plus grande que son dessin (ECHELLE), autour de son pied
	draw_set_transform(pied * (1.0 - ECHELLE), 0.0, Vector2(ECHELLE, ECHELLE))
	_dessiner_grue()
	draw_set_transform(Vector2.ZERO)
	for g in _gouttes:
		draw_circle(g[0], 2.5, VASE)

func _dessiner_grue() -> void:
	# le tas de vase au bord du quai, qui grossit à chaque godet
	var tas := pied + Vector2(52.0, 0.0)
	var r := 10.0 + 9.0 * godets
	if godets > 0:
		var pts := PackedVector2Array()
		for k in 17:
			var a := PI + PI * k / 16.0
			pts.append(tas + Vector2(cos(a) * r, sin(a) * r * 0.55 + 1.0))
		draw_colored_polygon(pts, VASE)
		draw_circle(tas + Vector2(-r * 0.3, -r * 0.3), r * 0.25, VASE_CLAIRE)
		pts.append(pts[0])
		draw_polyline(pts, BRUN, 1.6, true)
	# la grue : un poteau, une jambe de force, la flèche, le treuil
	var p := pied
	var haut := p + Vector2(0, -130.0)
	draw_line(p, haut, BRUN, 9.0, true)
	draw_line(p, haut, BOIS, 6.0, true)
	draw_line(p + Vector2(22, 0), p + Vector2(2, -60), BRUN, 6.0, true)
	draw_line(p + Vector2(22, 0), p + Vector2(2, -60), BOIS, 3.5, true)
	var bout := _bout_fleche()
	draw_line(haut + Vector2(0, 12), bout, BRUN, 8.0, true)
	draw_line(haut + Vector2(0, 12), bout, BOIS.lightened(0.1), 5.0, true)
	draw_line(haut, bout, Color("#2a2420"), 1.5, true)       # le hauban
	# le treuil, une petite roue rouge (la commande)
	var tr := p + Vector2(0, -45.0)
	var ang := _t * 0.0 + (_coup * 8.0 if _coup >= 0.0 else 0.0)
	var tex := Peint.roue()
	if tex:
		# la roue peinte des portes : partout, la roue rouge est la commande
		draw_set_transform(_monde(tr), ang, Vector2(ECHELLE, ECHELLE))
		draw_texture_rect(tex, Rect2(-17, -17, 34, 34), false)
		draw_set_transform(pied * (1.0 - ECHELLE), 0.0, Vector2(ECHELLE, ECHELLE))
	else:
		draw_circle(tr, 13.0, Color("#7c1f13"))
		draw_circle(tr, 10.0, Color("#c8321f"))
		for k in 4:
			var a := ang + k * PI * 0.5
			draw_line(tr, tr + Vector2(cos(a), sin(a)) * 10.0, Color("#7c1f13"), 2.5, true)
		draw_circle(tr, 3.0, Color("#e8a090"))
	# la corde et la benne
	var bn := _benne()
	draw_line(bout, bn, Color("#2a2420"), 2.0, true)
	var pleine := _coup > 0.7 and _coup < 1.75
	var benne := PackedVector2Array([bn + Vector2(-12, 0), bn + Vector2(12, 0), bn + Vector2(9, 14), bn + Vector2(-9, 14)])
	draw_colored_polygon(benne, Color("#4a4440"))
	if pleine: draw_colored_polygon(PackedVector2Array([bn + Vector2(-11, 1), bn + Vector2(11, 1), bn + Vector2(6, -6), bn + Vector2(-6, -6)]), VASE)
	benne.append(benne[0])
	draw_polyline(benne, BRUN, 1.8, true)
	# au repos et touchable : la benne se balance un peu pour inviter le doigt
	if actif and _coup < 0.0:
		var b2 := bn + Vector2(0, -8.0)
		draw_arc(b2, 22.0 + 2.0 * sin(_t * 3.0), -PI * 0.85, -PI * 0.15, 12, Color(1, 0.9, 0.4, 0.5), 2.5, true)

# La vase dans le bassin : sa face dans la coupe (du fond de pierre au dessus
# de la vase) et son dessus vu d'en haut, avant l'eau.
func _dessiner_couche() -> void:
	var D := canal.D
	var yv := canal.Y(fond_vu)
	if yv >= y_pierre - 0.5: return
	var dessus := PackedVector2Array([Vector2(x0, yv), Vector2(x1, yv), Vector2(x1, yv) + D, Vector2(x0, yv) + D])
	couche.draw_polygon(dessus, PackedColorArray([VASE_CLAIRE, VASE_CLAIRE, VASE, VASE]))
	# des bosses et des flaques sur le dessus
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 9:
		var z := rng.randf_range(0.15, 0.85)
		var c := Vector2(rng.randf_range(x0 + 20.0, x1 - 20.0), yv) + D * z
		var rx := rng.randf_range(10.0, 22.0)
		couche.draw_set_transform(c, 0.0, Vector2(1.0, 0.3))
		couche.draw_circle(Vector2.ZERO, rx, VASE.darkened(0.15) if k % 2 == 0 else VASE_CLAIRE.lightened(0.08))
		couche.draw_set_transform(Vector2.ZERO)
	# la face dans la coupe, en couches
	var face := PackedVector2Array([Vector2(x0, yv), Vector2(x1, yv), Vector2(x1, y_pierre), Vector2(x0, y_pierre)])
	couche.draw_polygon(face, PackedColorArray([VASE_CLAIRE, VASE_CLAIRE, VASE.darkened(0.2), VASE.darkened(0.2)]))
	var y := yv + 7.0
	while y < y_pierre - 3.0:
		couche.draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.25, 0.16, 0.08, 0.25), 1.2)
		y += 9.0
	for k in 7:
		var p := Vector2(rng.randf_range(x0 + 8.0, x1 - 8.0), rng.randf_range(yv + 6.0, maxf(y_pierre - 5.0, yv + 6.5)))
		couche.draw_circle(p, rng.randf_range(1.5, 3.0), Color(0.85, 0.8, 0.7, 0.6))
	couche.draw_line(Vector2(x0, yv), Vector2(x1, yv), Color(0.95, 0.85, 0.6, 0.45), 1.5)
