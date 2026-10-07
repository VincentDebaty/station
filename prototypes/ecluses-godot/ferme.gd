class_name Ferme
extends Node2D
# ------------------------------------------------------------------
# LA GRANGE EN FEU (chapitre 15, nuit du 7 au 8 octobre 2026) : un objectif
# qui n'est pas un bateau, pour le « feu » de Vincent. La cour de la ferme
# est un bassin « champ » du moteur, avec sa « cible » : l'eau doit y monter
# d'autant pour éteindre l'incendie. Une grange rouge brûle au fond de la
# cour, flammes et fumée noire ; un trait bleu en pointillés, avec une
# goutte, dit jusqu'où l'eau doit monter. Quand elle y est, les flammes
# s'éteignent dans un nuage de vapeur blanche, et il ne reste qu'une grange
# un peu noircie.
#
# Dans le plan des bateaux, derrière l'eau : si la cour se remplit, l'eau
# passe devant le bas de la grange.
# ------------------------------------------------------------------

var canal: Canal
var ib := 0
var pied := Vector2.ZERO    # le pied de la grange (plan des bateaux)
var y_cible := 0.0          # la hauteur d'eau qui éteint le feu (y monde, plan des bateaux)
var x0 := 0.0               # la cour, pour le trait de la cible
var x1 := 0.0
var feu := 1.0              # 1 en flammes, 0 éteint (glisse)
var _t := 0.0
var _volutes := []          # [position, vitesse, rayon, âge, durée, vapeur]
var _rng := RandomNumberGenerator.new()
var marque: Node2D          # le trait de la cible, devant l'eau

const BRUN := Color("#2e1a0b")

func preparer(c: Canal, abassin: int, apied: Vector2, ay_cible: float, ax0: float, ax1: float, eteint: bool) -> void:
	canal = c; ib = abassin; pied = apied; y_cible = ay_cible; x0 = ax0; x1 = ax1
	feu = 0.0 if eteint else 1.0
	_rng.seed = 31
	marque = Node2D.new()
	marque.z_index = 3
	marque.draw.connect(_dessiner_marque)

func eteint() -> bool:
	var b: Dictionary = canal.N["bassins"][ib]
	return float(canal.vue_niv[ib]) - float(b["fond"]) >= float(b["cible"]) - 1e-3

func _process(dt: float) -> void:
	_t += dt
	var avant := feu
	feu = move_toward(feu, 0.0 if eteint() else 1.0, dt * 1.2)
	# fumée noire tant qu'il brûle ; un grand nuage de vapeur quand il s'éteint
	if feu > 0.1 and _rng.randf() < dt * 10.0 * feu:
		_volutes.append([pied + Vector2(_rng.randf_range(-30, 30), -78.0), Vector2(_rng.randf_range(-10, 4), _rng.randf_range(-42, -28)), _rng.randf_range(8, 12), 0.0, _rng.randf_range(2.2, 3.0), false])
	if avant > feu and feu > 0.02 and _rng.randf() < dt * 30.0:
		_volutes.append([pied + Vector2(_rng.randf_range(-45, 45), _rng.randf_range(-70, -20)), Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-60, -35)), _rng.randf_range(10, 16), 0.0, _rng.randf_range(1.2, 1.8), true])
	for v in _volutes:
		v[3] += dt
		v[0] += v[1] * dt
		v[2] += dt * 9.0
	_volutes = _volutes.filter(func(v): return v[3] < v[4])
	queue_redraw()
	marque.queue_redraw()

func _draw() -> void:
	var p := pied
	var w := 120.0
	var h := 62.0
	var brule := clampf(1.0 - feu, 0.0, 1.0)
	# l'ombre
	draw_set_transform(p + Vector2(6, -2), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, w * 0.62, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	# les murs de planches rouges (assombris par le feu)
	var rouge := Color("#b8432f").darkened(0.15 * feu)
	var murs := Rect2(p.x - w * 0.5, p.y - h, w, h)
	draw_rect(murs, rouge)
	for k in range(1, 10):
		var x := murs.position.x + k * w / 10.0
		draw_line(Vector2(x, murs.position.y), Vector2(x, murs.end.y), Color(0, 0, 0, 0.18), 1.2)
	# le grand portail, en croix blanche
	var porte := Rect2(p.x - 22.0, p.y - 44.0, 44.0, 44.0)
	draw_rect(porte, Color("#7e2a1c"))
	draw_rect(porte, Color("#f4ecd8"), false, 3.0)
	draw_line(porte.position, porte.end, Color("#f4ecd8"), 3.0)
	draw_line(Vector2(porte.end.x, porte.position.y), Vector2(porte.position.x, porte.end.y), Color("#f4ecd8"), 3.0)
	draw_rect(murs, BRUN, false, 2.0)
	# le toit, gris ardoise, en deux pans
	var toit := PackedVector2Array([Vector2(p.x - w * 0.58, p.y - h + 2.0), Vector2(p.x - w * 0.28, p.y - h - 34.0), Vector2(p.x + w * 0.28, p.y - h - 34.0), Vector2(p.x + w * 0.58, p.y - h + 2.0)])
	draw_colored_polygon(toit, Color("#5b5450"))
	var tt := toit.duplicate()
	tt.append(toit[0])
	draw_polyline(tt, BRUN, 2.0, true)
	# des traces noires de suie, une fois éteint (elles restent)
	if brule > 0.05:
		for k in 4:
			var sx := p.x - w * 0.35 + k * w * 0.23
			draw_circle(Vector2(sx, p.y - h - 6.0 + (k % 2) * 8.0), 9.0, Color(0.1, 0.08, 0.07, 0.35 * brule))
	# les flammes sur le toit et aux fenêtres
	if feu > 0.02:
		for k in 5:
			var fx := p.x - w * 0.4 + k * w * 0.2
			var fy := p.y - h - 8.0 - (16.0 if k in [1, 2, 3] else 0.0)
			_flamme(Vector2(fx, fy), (26.0 + 8.0 * sin(_t * 6.0 + k * 1.7)) * feu, 11.0 * feu, k)
	# fumée et vapeur
	for v in _volutes:
		var vie: float = v[3] / v[4]
		var a := (1.0 - vie) * minf(1.0, v[3] * 6.0)
		var col := Color(0.95, 0.97, 1.0) if v[5] else Color(0.22, 0.2, 0.2)
		draw_circle(v[0], v[2], Color(col, (0.75 if v[5] else 0.55) * a))
		draw_circle(v[0] + Vector2(-v[2] * 0.3, -v[2] * 0.3), v[2] * 0.55, Color(col.lightened(0.15), 0.5 * a))

func _flamme(pied_f: Vector2, hauteur: float, largeur: float, k: int) -> void:
	# trop petite, elle ne se triangule plus (et ne se verrait pas)
	if hauteur < 3.0 or largeur < 1.5: return
	for c in [[Color("#e2421b"), 1.0], [Color("#ff8a1f"), 0.72], [Color("#ffd447"), 0.45]]:
		var s: float = c[1]
		var pts := PackedVector2Array()
		var n := 10
		for j in n + 1:
			var t := float(j) / n
			var demi := largeur * s * pow(1.0 - t, 0.75)
			pts.append(pied_f + Vector2(-demi + sin(_t * 8.0 + k + t * 3.0) * 3.0 * t, -t * hauteur * s))
		for j in range(n - 1, -1, -1):
			var t := float(j) / n
			var demi := largeur * s * pow(1.0 - t, 0.75)
			pts.append(pied_f + Vector2(demi + sin(_t * 8.0 + k + t * 3.0) * 3.0 * t, -t * hauteur * s))
		draw_colored_polygon(pts, c[0])

# Le niveau qu'il faut atteindre dans la cour : un trait bleu en pointillés
# et une goutte au bout, tant que le feu brûle.
func _dessiner_marque() -> void:
	if feu < 0.05: return
	var a := clampf(feu, 0.0, 1.0)
	marque.draw_dashed_line(Vector2(x0, y_cible), Vector2(x1, y_cible), Color(1, 1, 1, 0.85 * a), 6.0, 12.0)
	marque.draw_dashed_line(Vector2(x0, y_cible), Vector2(x1, y_cible), Color(0.18, 0.56, 0.85, a), 3.5, 12.0)
	var g := Vector2(x1 + 14.0, y_cible - 6.0 + 2.0 * sin(_t * 3.0))
	var r := 7.0
	var goutte := PackedVector2Array([g + Vector2(0, -r * 2.0)])
	for s in 11:
		var an := lerpf(-PI * 0.5 + 0.6, PI * 1.5 - 0.6, float(s) / 10.0)
		goutte.append(g + Vector2(cos(an), sin(an)) * r)
	marque.draw_colored_polygon(goutte, Color(0.31, 0.7, 0.88, a))
	goutte.append(goutte[0])
	marque.draw_polyline(goutte, Color(0.11, 0.31, 0.42, a), 1.8, true)
