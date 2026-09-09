## LA PROJECTION OBLIQUE DU PLAN — le poste vu de biais, pas de face.
##
## « Les rails semblent en 3D vue de côté mais le train en 2D vue d'en haut.
## Pourrait-on avoir une vue effet 3D de côté ? » (Vincent, 9 septembre 2026).
##
## Une ÉLÉVATION pure est exclue, et ce n'est pas une affaire de goût : les
## onze quais de Madrid-Chamartín s'y superposeraient en une seule ligne, et un
## croisement — qui EST le conflit, le cœur du jeu — deviendrait invisible. Un
## poste d'aiguillage se lit en plan, et les vrais aussi.
##
## Ce qu'on applique est une projection OBLIQUE : un cisaillement affine, donc
## qui CONSERVE LES INCIDENCES. Deux voies qui se croisent se croisent encore,
## une courbe reste une courbe, deux quais restent distincts. Vérifié sur les
## onze quais de Madrid avant d'y toucher (jeu/maquette_oblique.gd).
##
##   p' = C + ( (x − Cx) + (y − Cy)·S , (y − Cy)·A )
##
## LES TROIS CHIFFRES, ET POURQUOI CEUX-LÀ.
##
## `S` = 0,22 — le cisaillement, mesuré en maquette contre 0,45. Le franc était
## plus spectaculaire mais écrasait les quais les uns sur les autres et
## gaspillait la hauteur d'écran ; le doux garde la lecture intacte.
##
## `A` = 0,86 — l'aplatissement. Il REND de la place verticale, il n'en prend
## pas : c'est le cisaillement qui élargit, et l'élargissement part dans les
## marges où filent déjà les voies d'entrée et de sortie (EDGE_RUN = 360 de
## chaque côté). Le plan n'a donc pas à être réduit, et rien ne rapetisse.
##
## `EPAIS` = 8 — et ce plafond n'est pas un choix, il est MESURÉ. Deux quais
## voisins ne sont séparés que de 10 unités au plus serré (Madrid-Chamartín,
## relevé sur les 401 fiches, pour un quai de 42 de haut) ; après
## aplatissement il reste 8,6 unités entre le bas d'un quai et le haut du
## suivant. Une face plus épaisse passerait DERRIÈRE le quai d'en dessous et
## disparaîtrait — c'est exactement ce que la maquette montrait à 13.
##
## CE QUI NE SE PROJETTE JAMAIS : le texte. On projette sa PLACE, pas sa forme.
## Un chiffre de quai cisaillé serait illisible, et aucune signalétique de gare
## n'est penchée. Même chose pour les lampes de portail, qui restent rondes :
## une lampe est une lampe.

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
