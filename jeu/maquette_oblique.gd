extends Node2D
## LA MAQUETTE DE LA PROJECTION OBLIQUE — pour décider, pas pour livrer.
##
##   STATION_OBLIQUE="<gare> <variante>" godot --path . res://jeu/maquette_oblique.tscn
##   STATION_OBLIQUE="madrid-chamartin 3" …
##
## Vincent, 9 septembre 2026 : « les rails semblent en 3D vue de côté mais le
## train en 2D vue d'en haut. Pourrait-on avoir une vue effet 3D de côté ? »
## Une élévation pure est exclue — onze quais s'y superposeraient en une seule
## ligne, et un croisement, qui EST le conflit, deviendrait invisible. Reste la
## projection OBLIQUE : un cisaillement affine, qui conserve les incidences.
## Les quais restent distincts, les croisements restent des croisements, et le
## plan gagne une épaisseur.
##
##   p' = C + ((p.x - C.x) + (p.y - C.y)·s , (p.y - C.y)·c)
##
## Quatre variantes, à comparer sur la MÊME gare :
##
##   0 · le plan d'aujourd'hui — la référence, dessinée par ce même code
##   1 · oblique douce, sans épaisseur : ce que coûte le seul cisaillement
##   2 · oblique douce AVEC épaisseur : quais à face avant, convois à flanc
##   3 · oblique franche avec épaisseur : le maximum lisible
##
## CE QU'IL FAUT REGARDER, et c'est pour cela que le facteur d'ajustement
## s'affiche en bas : le cisaillement POUSSE les quais du fond vers la droite,
## donc le plan s'élargit, donc il faut le réduire pour qu'il tienne. C'est le
## seul vrai prix de l'opération, et il se paie en taille de caractères.
##
## Ce fichier ne sert qu'à décider. Il ne dessine PAS l'écran de jeu : ni
## bandeau, ni horloge, ni badges, ni signalisation d'état — seulement ce que
## la projection change.

const Geo := preload("res://jeu/geometrie.gd")
const Sty := preload("res://jeu/style.gd")
const Ill := preload("res://jeu/illustrations.gd")

const VARIANTES := [
	{"nom": "le plan d'aujourd'hui", "s": 0.00, "c": 1.00, "epais": 0.0},
	{"nom": "oblique douce, sans épaisseur", "s": 0.22, "c": 0.86, "epais": 0.0},
	{"nom": "oblique douce, avec épaisseur", "s": 0.22, "c": 0.86, "epais": 13.0},
	{"nom": "oblique franche, avec épaisseur", "s": 0.45, "c": 0.72, "epais": 20.0},
]

var G := {}
var fiche := {}
var v: Dictionary = VARIANTES[0]
var ech := 1.0             # l'ajustement, pour que le plan projeté tienne
var pose := Vector2.ZERO
var centre := Vector2(Geo.PLAT_MID, Geo.CENTER_Y)


func _ready() -> void:
	Sty.calibrer(get_viewport())
	var arg := OS.get_environment("STATION_OBLIQUE")
	var mots := arg.split(" ", false) if arg != "" else PackedStringArray()
	var id: String = String(mots[0]) if mots.size() > 0 else "madrid-chamartin"
	var n: int = clampi(int(mots[1]) if mots.size() > 1 else 0, 0, VARIANTES.size() - 1)
	v = VARIANTES[n]
	fiche = Donnees.fiche(id)
	if fiche.is_empty():
		push_error("gare inconnue : " + id)
		return
	G = Geo.construire(fiche)
	RenderingServer.set_default_clear_color(Sty.POSTE_FOND)
	_cadrer()
	get_viewport().size_changed.connect(func() -> void:
		_cadrer()
		queue_redraw())
	print("maquette oblique · %s · variante %d — %s · cisaillement %.2f, aplatissement %.2f, ajustement ×%.3f"
		% [id, n, String(v["nom"]), float(v["s"]), float(v["c"]), ech])
	_capture_eventuelle()


# ------------------------------------------------------------------
# La projection, et le cadrage qu'elle impose
# ------------------------------------------------------------------
## Un point du plan, projeté. C'est TOUTE la transformation : affine, donc
## deux voies qui se croisent se croisent encore, et une courbe reste courbe.
func p(q: Vector2) -> Vector2:
	var d := q - centre
	return pose + Vector2(d.x + d.y * float(v["s"]), d.y * float(v["c"])) * ech


## LE PRIX DE L'OBLIQUE SE MESURE ICI. On projette la boîte du plan — les
## coins suffisent, la transformation est affine — et on réduit jusqu'à ce
## qu'elle tienne dans la zone sûre. `ech` est le chiffre à citer.
func _cadrer() -> void:
	var e := get_viewport_rect().size
	var m := Sty.marges
	var utile := e - Vector2(m["gauche"] + m["droite"], m["haut"] + m["bas"] + 40.0)
	# la boîte du plan en unités monde : les voies filent jusqu'aux bords
	var x0: float = -Geo.EDGE_RUN
	var x1: float = 1400.0 + Geo.EDGE_RUN
	var y0: float = 1e9
	var y1: float = -1e9
	for q in G.get("platforms", []):
		y0 = minf(y0, float(q["cy"]) - Geo.PLAT_H)
		y1 = maxf(y1, float(q["cy"]) + Geo.PLAT_H + float(v["epais"]))
	for pn in G.get("portals", {}):
		var cy := float(G["portals"][pn]["cy"])
		y0 = minf(y0, cy - 60.0)
		y1 = maxf(y1, cy + 70.0)
	var s: float = float(v["s"])
	var c: float = float(v["c"])
	var cx0: float = x0 - centre.x
	var cx1: float = x1 - centre.x
	var cy0: float = y0 - centre.y
	var cy1: float = y1 - centre.y
	var lx0: float = minf(cx0 + cy0 * s, cx0 + cy1 * s)
	var lx1: float = maxf(cx1 + cy0 * s, cx1 + cy1 * s)
	ech = minf(utile.x / (lx1 - lx0), utile.y / ((cy1 - cy0) * c))
	# le centre de la boîte projetée tombe au centre de la zone utile
	var mx: float = (lx0 + lx1) / 2.0
	var my: float = (cy0 + cy1) / 2.0 * c
	pose = Vector2(m["gauche"], m["haut"]) + utile / 2.0 - Vector2(mx, my) * ech


# ------------------------------------------------------------------
# Le dessin
# ------------------------------------------------------------------
func _draw() -> void:
	if G.is_empty():
		return
	var k: float = Sty.UIK * ech
	# --- les voies d'entrée et de sortie ------------------------------------
	for pname in G["approach"]:
		for quoi in ["approach", "depart"]:
			var pts := Geo.vers_vector2(G[quoi][pname]["xs"], G[quoi][pname]["ys"])
			_rail(pts, Sty.POSTE_VOIE, 9.0 * k, 3.4 * k, 11.0, 3.5 * ech, 0.75)
	# --- le gril, teinté à sa destination -----------------------------------
	for m in G["mesh"]:
		var pts := Geo.vers_vector2(m["xs"], m["ys"])
		var col := Color(String(G["dest_color"].get(m["portal"], "#ffffff")))
		_rail(pts, col, 8.4 * ech, 3.2 * k, 10.0, 3.5 * ech, 0.38, 0.78)
	# --- les quais et leurs convois, de l'arrière-plan vers l'avant ---------
	# UN PLAN PROJETÉ SE DESSINE EN PROFONDEUR : le quai du fond d'abord, sans
	# quoi sa face avant recouvrirait celui d'en dessous. L'ordre est celui des
	# ordonnées, et c'est tout ce que le tri demande — le cisaillement ne
	# change pas qui est devant qui.
	var quais: Array = G["platforms"].duplicate()
	quais.sort_custom(func(a, b): return float(a["cy"]) < float(b["cy"]))
	var n := 0
	for q in quais:
		_quai(q, k)
		# deux convois posés à quai, pour juger la caisse sous la projection
		if n == 1 or n == 3:
			_convoi_a_quai(q, 4 if n == 1 else 3)
		n += 1
	# --- un convoi sur sa voie d'approche, pour juger la caisse en courbe ---
	var noms: Array = G["approach"].keys()
	if not noms.is_empty():
		_convoi_sur_chemin(G["approach"][noms[0]], 4, String(noms[0]))
	# --- les portails ------------------------------------------------------
	for pname in G["portals"]:
		_portail(pname)
	_legende()


## Une voie : ballast, traverses, rail. LES TRAVERSES SE CALCULENT DANS LE
## PLAN puis se projettent — une traverse perpendiculaire à l'écran serait
## perpendiculaire à la mauvaise chose, et trahirait la projection.
func _rail(pts: PackedVector2Array, col: Color, large: float, demi: float,
		pas: float, fin: float, force: float, opac: float = 1.0) -> void:
	var proj := PackedVector2Array()
	for q in pts:
		proj.append(p(q))
	draw_polyline(proj, Color(Sty.POSTE_BALLAST, 0.9), large, true)
	var reste := pas / 2.0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := a.distance_to(b)
		if d <= 0.0:
			continue
		var u := (b - a) / d
		var nrm := Vector2(-u.y, u.x)
		var s := reste
		while s < d:
			var mi := a + u * s
			draw_line(p(mi - nrm * demi / ech), p(mi + nrm * demi / ech),
				Color(col, force), maxf(1.0, 1.6 * ech), true)
			s += pas
		reste = s - d
	draw_polyline(proj, Color(col, opac), fin, true)


## LE QUAI PREND SON ÉPAISSEUR. C'est elle, et non le cisaillement, qui fait
## la « 3D » : un parallélogramme seul est un plan penché, un parallélogramme
## AVEC SA FACE AVANT est un objet posé. La face est plus sombre que le
## dessus — le vocabulaire du biseau, qui est déjà celui des quais du jeu.
func _quai(q: Dictionary, _k: float) -> void:
	var cy := float(q["cy"])
	var r := Rect2(Geo.PLAT_X1, cy - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
	var contour := Sty.rect_arrondi(r, 10)
	var haut := PackedVector2Array()
	for pt in contour:
		haut.append(p(pt))
	var ep: float = float(v["epais"]) * ech
	if ep > 0.0:
		# LA FACE EST UN QUADRILATÈRE, PAS LA MOITIÉ DU CONTOUR. Filtrer les
		# points du bas d'un rectangle arrondi rend une suite qui n'est plus un
		# polygone simple : la triangulation échoue et la face disparaît.
		# L'arête basse suffit, descendue de l'épaisseur.
		var a := p(Vector2(r.position.x + 10.0, r.end.y))
		var b2 := p(Vector2(r.end.x - 10.0, r.end.y))
		draw_colored_polygon(PackedVector2Array([a, b2, b2 + Vector2(0, ep), a + Vector2(0, ep)]),
			Sty.POSTE_QUAI_BAS.darkened(0.35))
		draw_line(a + Vector2(0, ep), b2 + Vector2(0, ep), Color(0, 0, 0, 0.35),
			maxf(1.0, 2.0 * ech), true)
	draw_colored_polygon(haut, Sty.POSTE_QUAI_HAUT)
	var b := haut.duplicate()
	b.append(haut[0])
	draw_polyline(b, Color(Sty.POSTE_BORD, 0.85), maxf(1.0, 1.6 * ech), true)
	# LE NUMÉRO RESTE DROIT. On projette sa PLACE, pas sa forme : un chiffre
	# cisaillé serait illisible, et aucune signalétique de gare n'est penchée.
	var f := Sty.mono(700)
	var t := int(round(20.0 * ech))
	if t > 0:
		Sty.texte_centre(self, f, t, p(Vector2(r.get_center().x, cy)) + Vector2(0, -2.0 * ech),
			str(int(q["id"])), Sty.TEXTE)


func _convoi_a_quai(q: Dictionary, cases: int) -> void:
	var cy := float(q["cy"])
	var x0: float = Geo.PLAT_X1 + Geo.PLAT_MARGIN + Geo.CAR_LEN / 2.0
	var col := Sty.LAITON_CLAIR
	var dests: Array = G["dest_color"].keys()
	if not dests.is_empty():
		col = Color(String(G["dest_color"][dests[int(cy) % dests.size()]]))
	for i in range(cases):
		_caisse(Vector2(x0 + float(i) * Geo.CAR_SPACING, cy), Vector2.RIGHT, col, i == 0)


func _convoi_sur_chemin(chemin: Dictionary, cases: int, pname: String) -> void:
	var col := Color(String(G["dest_color"].get(pname, "#ffffff")))
	var base: float = float(chemin["len"]) * 0.62
	for i in range(cases):
		var s: float = base - float(i) * Geo.CAR_SPACING
		var d: Dictionary = Geo.path_point(chemin, s)
		var d2: Dictionary = Geo.path_point(chemin, s + 1.0)
		var u := Vector2(float(d2["x"]) - float(d["x"]), float(d2["y"]) - float(d["y"]))
		_caisse(Vector2(float(d["x"]), float(d["y"])),
			u.normalized() if u.length() > 1e-6 else Vector2.RIGHT, col, i == 0)


## UNE CAISSE, PROJETÉE PAR SES QUATRE COINS. La planche est une image vue de
## dessus ; sous une transformation affine elle devient un parallélogramme, et
## c'est exactement ce qu'un toit devient vu de biais. Rien à redessiner pour
## juger — mais une planche en TROIS-QUARTS PLONGEANT, où l'on verrait le toit
## ET un flanc, serait la vraie réponse si la variante est retenue : ici le
## flanc est simulé par une bande sombre, il n'est pas dessiné.
func _caisse(c: Vector2, u: Vector2, col: Color, machine: bool) -> void:
	var n := Vector2(-u.y, u.x)
	var L: float = Geo.CAR_LEN / 2.0
	var H: float = Geo.CAR_H / 2.0
	var coins := [c - u * L - n * H, c + u * L - n * H, c + u * L + n * H, c - u * L + n * H]
	var quad := PackedVector2Array()
	for q in coins:
		quad.append(p(q))
	var ep: float = float(v["epais"]) * ech * 0.55
	if ep > 0.0:
		var flanc := PackedVector2Array([quad[3], quad[2],
			quad[2] + Vector2(0, ep), quad[3] + Vector2(0, ep)])
		draw_colored_polygon(flanc, col.darkened(0.55))
		draw_polyline(PackedVector2Array([quad[3] + Vector2(0, ep), quad[2] + Vector2(0, ep)]),
			Color(0, 0, 0, 0.4), maxf(1.0, 1.4 * ech), true)
	var tex: Texture2D = Ill.vehicule("loco" if machine else "fourgon")
	var lavis := Color(col.lerp(Sty.PAPIER, 0.06), 1.0)
	if tex != null:
		draw_colored_polygon(quad, lavis, PackedVector2Array([
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)
	else:
		draw_colored_polygon(quad, lavis)


func _portail(pname: String) -> void:
	var po: Dictionary = G["portals"][pname]
	var e := p(Vector2(float(po["x"]), float(po["cy"])))
	var col := Color(String(G["dest_color"].get(pname, "#ffffff")))
	draw_circle(e, 9.0 * ech, Color(col, 0.28))
	draw_circle(e, 5.0 * ech, col)
	var f := Sty.titre(600)
	var t := int(round(15.0 * ech))
	if t <= 0:
		return
	var nom := String(po.get("label", pname)).to_upper()
	var w: float = f.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
	var gauche: bool = String(po["side"]) == "L"
	draw_string(f, e + Vector2(-w - 16.0 * ech if gauche else 16.0 * ech, -14.0 * ech),
		nom, HORIZONTAL_ALIGNMENT_LEFT, -1, t, col)


## Ce qu'il faut lire sous l'image pour comparer deux captures.
func _legende() -> void:
	var f := Sty.sans(400)
	var e := get_viewport_rect().size
	var txt := "%s  ·  %s  ·  cisaillement %.2f  ·  aplatissement %.2f  ·  ajustement ×%.3f" % [
		String(fiche.get("name", "?")), String(v["nom"]), float(v["s"]), float(v["c"]), ech]
	draw_string(f, Vector2(Sty.marges["gauche"] + 18.0, e.y - Sty.marges["bas"] - 14.0),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Sty.POSTE_BORD, 0.9))


func _capture_eventuelle() -> void:
	var out := OS.get_environment("STATION_CAPTURE")
	if out == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("capture : " + out)
	get_tree().quit()
