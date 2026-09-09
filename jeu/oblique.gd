## LA PROJECTION OBLIQUE — ESSAYÉE, PUIS ÉCARTÉE.
##
## Le 9 septembre 2026, Vincent a demandé une vue « effet 3D de côté » ; une
## élévation pure était exclue — onze quais s'y superposeraient en une seule
## ligne, et un croisement, qui EST le conflit, deviendrait invisible. On a
## donc essayé la projection OBLIQUE : un cisaillement affine, qui conserve les
## incidences. Le plan tenait, les quais gagnaient une épaisseur, et
## `jeu/maquette_oblique.gd` en garde la démonstration.
##
## LE MÊME JOUR, ELLE A ÉTÉ ABANDONNÉE, et pour une raison qu'aucun réglage ne
## rattrape : « cela semble écrasé quand le train monte et descend » — un plan
## d'aiguillage a des voies qui montent et descendent sans arrêt, et sous un
## aplatissement du sol, tout convoi qui suit une courbe se raccourcit. C'est
## géométriquement exact et visuellement pénible. « Revenons à une vue 2D
## classique vue de haut. » Le poste y est revenu.
##
## CE QUI RESTE, ET POURQUOI. L'écran d'attente s'en sert encore : sa voie est
## une élévation, et le cisaillement lui donne l'inclinaison de ses traverses.
## Deux constantes suffisent à cela. Le reste — `p`, `inv`, `trace`,
## `traverses`, `face`, `quad` — ne sert plus à personne : c'est de la mémoire,
## gardée parce que la question reviendra peut-être, et qu'elle est chère à
## retrouver.
##
##   p' = C + ( (x − Cx) + (y − Cy)·S , (y − Cy)·A )

const Geo := preload("res://jeu/geometrie.gd")

const S := 0.22
const A := 0.86
const EPAIS := 8.0
const CENTRE := Vector2(Geo.PLAT_MID, Geo.CENTER_Y)


## Un point du plan, projeté.
static func p(q: Vector2) -> Vector2:
	var d := q - CENTRE
	return CENTRE + Vector2(d.x + d.y * S, d.y * A)


## L'inverse : d'un point de l'écran (déjà ramené au repère du plan par
## `decalage()`) au point du plan. C'est lui qui rend le doigt exact — toutes
## les zones de clic restent écrites dans le plan, et rien d'autre n'a bougé.
static func inv(e: Vector2) -> Vector2:
	var d := e - CENTRE
	var y: float = d.y / A
	return CENTRE + Vector2(d.x - y * S, y)


## Une polyligne du plan, projetée.
static func trace(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = p(pts[i])
	return out


## LES TRAVERSES SE CALCULENT DANS LE PLAN PUIS SE PROJETTENT. Posées sur le
## tracé déjà projeté, elles seraient perpendiculaires à l'écran — c'est-à-dire
## perpendiculaires à la mauvaise chose — et trahiraient la projection à
## chaque courbe. C'est la même marche que `Sty.traverses`, mais chaque bout de
## traverse passe par `p()`.
static func traverses(canvas: CanvasItem, pts: PackedVector2Array, col: Color,
		demi: float, pas: float, larg: float = 1.6) -> void:
	if pts.size() < 2:
		return
	var reste := pas / 2.0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := a.distance_to(b)
		if d <= 0.0:
			continue
		var u := (b - a) / d
		var n := Vector2(-u.y, u.x)
		var s := reste
		while s < d:
			var m := a + u * s
			canvas.draw_line(p(m - n * demi), p(m + n * demi), col, larg, true)
			s += pas
		reste = s - d


## La face avant d'une plaque : son arête basse, descendue de l'épaisseur.
## C'EST ELLE QUI FAIT LA PROFONDEUR, et non le cisaillement — un
## parallélogramme seul est un plan penché ; avec sa face, c'est un objet posé.
static func face(canvas: CanvasItem, r: Rect2, retrait: float, col: Color,
		ep: float = EPAIS) -> void:
	var a := p(Vector2(r.position.x + retrait, r.end.y))
	var b := p(Vector2(r.end.x - retrait, r.end.y))
	canvas.draw_colored_polygon(PackedVector2Array([
		a, b, b + Vector2(0, ep), a + Vector2(0, ep)]), col)
	canvas.draw_line(a + Vector2(0, ep), b + Vector2(0, ep), Color(0, 0, 0, 0.35), 1.6, true)


## Un rectangle du plan, projeté en quadrilatère.
static func quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([p(r.position), p(Vector2(r.end.x, r.position.y)),
		p(r.end), p(Vector2(r.position.x, r.end.y))])
