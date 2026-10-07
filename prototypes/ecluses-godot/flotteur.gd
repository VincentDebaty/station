class_name Flotteur
extends Node2D
# ------------------------------------------------------------------
# LA PORTE À FLOTTEUR (chapitre 12, nuit du 7 au 8 octobre 2026) : comme le
# robinet d'une chasse d'eau. On ouvre la porte à sa roue ; contre son
# pilier, dans le bassin qu'elle remplit, une tige de guidage plantée devant
# le mur du fond, et un gros flotteur rouge et blanc qui y coulisse avec
# l'eau. Une bague jaune marque sur la tige la hauteur où il s'arrête : quand
# l'eau l'y porte, sa corde se tend, passe par une poulie sur la traverse et
# referme la porte. L'eau s'arrête juste là.
#
# Dessiné dans le plan des bateaux (à mi-profondeur, derrière l'eau) : on
# voit le flotteur à travers la surface.
# ------------------------------------------------------------------

var canal: Canal
var i_bassin := 0
var x := 0.0               # la tige, en x monde (plan des bateaux)
var y_haut := 0.0          # le haut de la tige
var y_bas := 0.0           # son pied (le fond du bassin)
var y_bague := 0.0         # la hauteur de déclenchement
var poulie := Vector2.ZERO # la poulie, sur la traverse de la porte
var _t := 0.0
const R := 16.0            # le flotteur

func preparer(c: Canal, ib: int, ax: float, ay_haut: float, ay_bas: float, ay_bague: float, apoulie: Vector2) -> void:
	canal = c; i_bassin = ib; x = ax; y_haut = ay_haut; y_bas = ay_bas; y_bague = ay_bague; poulie = apoulie
	z_index = 1

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

# Le flotteur flotte à la surface (son centre un peu dessous), sans
# descendre sous le pied de la tige ni monter au-dessus de la bague.
func _y_flotteur() -> float:
	var surf := canal.Y(canal.vue_niv[i_bassin]) + canal.D.y * 0.5 + R * 0.35
	return clampf(surf, y_bague + R * 0.35, y_bas - R)

func _draw() -> void:
	var yf := _y_flotteur()
	# la tige de guidage, en fer
	draw_line(Vector2(x, y_haut), Vector2(x, y_bas), Color("#2c2622"), 5.0, true)
	draw_line(Vector2(x - 1.0, y_haut), Vector2(x - 1.0, y_bas), Color("#6b625c"), 2.0, true)
	# la bague, jaune, qui luit doucement tant que le flotteur ne l'a pas atteinte
	var tendue := yf <= y_bague + R * 0.35 + 1.0
	var lueur := 0.0 if tendue else 0.5 + 0.3 * sin(_t * 3.0)
	if lueur > 0.0: draw_circle(Vector2(x, y_bague), 20.0, Color(1.0, 0.85, 0.3, lueur * 0.45))
	# la bague, en avant du flotteur quand il l'atteint (on la voit toujours),
	# avec deux ergots qui dépassent
	draw_rect(Rect2(x - 15.0, y_bague - 6.0, 30.0, 12.0), Color("#3b2414"))
	draw_rect(Rect2(x - 13.0, y_bague - 4.0, 26.0, 8.0), Color("#ffd447"))
	draw_line(Vector2(x - 13.0, y_bague - 2.0), Vector2(x + 13.0, y_bague - 2.0), Color(1, 1, 1, 0.5), 1.5)
	# la corde, du haut du flotteur à la poulie, puis vers la porte : lâche
	# tant que le flotteur est bas, tendue quand il atteint la bague
	var haut_f := Vector2(x, yf - R)
	var c := Color("#6b4a2e")
	if tendue:
		draw_line(haut_f, poulie, c, 2.5, true)
	else:
		# une corde lâche, qui pend en courbe
		var pts := PackedVector2Array()
		for k in 17:
			var t := float(k) / 16.0
			var p := haut_f.lerp(poulie, t)
			p.y += sin(t * PI) * minf(26.0, (yf - y_bague) * 0.5 + 6.0)
			pts.append(p)
		draw_polyline(pts, c, 2.5, true)
	# la poulie
	draw_circle(poulie, 7.0, Color("#2c2622"))
	draw_circle(poulie, 4.0, Color("#8a8178"))
	# le flotteur : une boule de cuivre cerclée de laiton, comme celui d'une
	# chasse d'eau (rouge et blanc, on le prenait pour la bouée d'un bateau)
	var cf := Vector2(x, yf)
	draw_circle(cf + Vector2(1.5, 2.0), R + 1.5, Color(0, 0, 0, 0.18))
	draw_circle(cf, R + 1.8, Color("#3b2414"))
	draw_circle(cf, R, Color("#c8743a"))
	draw_circle(cf + Vector2(R * 0.2, R * 0.25), R * 0.75, Color("#a85a28"))
	draw_line(cf + Vector2(-R, 0), cf + Vector2(R, 0), Color("#ffd166"), 3.0, true)
	draw_circle(cf + Vector2(-R * 0.35, -R * 0.4), R * 0.28, Color(1, 0.92, 0.75, 0.8))
	# la bague par-dessus le flotteur arrivé : elle reste visible
	if tendue:
		draw_rect(Rect2(x - 15.0, y_bague - 6.0, 30.0, 12.0), Color("#3b2414"))
		draw_rect(Rect2(x - 13.0, y_bague - 4.0, 26.0, 8.0), Color("#ffd447"))
	draw_rect(Rect2(cf.x - 3.0, cf.y - R - 5.0, 6.0, 6.0), Color("#3b2414"))
