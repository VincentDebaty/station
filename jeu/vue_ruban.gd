extends Node2D
## L'ÉCRAN DU RUBAN — où en suis-je, et quelle est la gare suivante.
##
## Transposition de js/parcours.js (étape 7). Le panneau de gauche porte tout
## ce qui se lit : les compteurs, le chapitre, la gare qui vient, le relevé du
## service qu'on vient de tenir, la fête de fin de chapitre, et les boutons.
## La carte prend le reste : le fond des pays, le rail du chapitre en cours,
## ses gares, et le convoi qui passe d'un chapitre au suivant PENDANT qu'on
## lit son bilan.
##
## Rien ici ne décide d'une règle : la position, la difficulté, les rangs, les
## médailles et le prix d'un passage viennent de ruban.gd et recompense.gd.
## Cet écran traduit, il ne calcule pas.

const Rub := preload("res://jeu/ruban.gd")
const Rec := preload("res://jeu/recompense.gd")
const Sty := preload("res://jeu/style.gd")

# Le cadre de la projection, en unités du prototype (160 × 100), et son
# étirement : l'Europe est plus haute que large.
const CADRE_L := 160.0
const CADRE_H := 100.0
const ETIREMENT_X := 1.6
const PANNEAU_L := 380.0
const ECRAN_L := 1400.0
const ECRAN_H := 760.0
const K_MAX_CHAPITRE := 200.0
const PX_PAR_UNITE_MIN := 48.0
const DUREE_CAMERA := 0.75
const DUREE_CAMERA_SAUT := 1.5
const DUREE_VOYAGE := 1.15
const DUREE_SAUT := 1.9
const DELAI_LECTURE := 0.7

const FOND := Color("#0E1420")
const PAYS := Color("#151d2e")
const PANNEAU := Color("#111827")
const BORD := Color("#2a3550")
const TEXTE := Color("#dbe2ee")
const MUET := Color("#7a8699")
const ACCENT := Color("#2dd4bf")
const OR := Color("#f5b23c")
const DIAMANT := Color("#7fd4ff")
const ROUGE := Color("#ef4444")

var app = null
var ruban: Rub = null
var carte_id := ""

# --- la projection, fixée par carte ------------------------------------------
var proj := {}                # {lo, la, cosm, s} — vide tant qu'aucune carte
var fond: Node2D              # les pays, en Polygon2D, sous la caméra
var contours: Array = []      # les anneaux dessinés en Line2D, à la largeur du zoom

# --- la caméra ------------------------------------------------------------------
var cam := {"x": CADRE_L / 2, "y": CADRE_H / 2, "k": 1.0}
var zoom_force := false
var cam_de := {}
var cam_vers := {}
var cam_t := 0.0
var cam_duree := 0.0

# --- l'état de l'écran (CARTE dans le prototype) ---------------------------------
var bilan := {}               # le relevé du service qu'on vient de tenir
var medailles: Array = []     # ce qu'on vient de décrocher
var fete := {}                # {ch, suivant, zone_finie}
var transit := {}             # {de, vers, chapitre, saut} pendant le voyage de chapitre
var voyage_fait := {}         # le chapitre rejoint, où la caméra reste
var chapitre := {}            # celui que le panneau raconte
var prochaine := ""
var transit_t := -1.0         # < 0 : pas parti ; 0..1 : en route
var voyage_saut := false

# --- le panneau ---------------------------------------------------------------------
var panneau: PanelContainer
var colonne: VBoxContainer
var police: Font


func _ready() -> void:
	police = Sty.sans(600)
	fond = Node2D.new()
	fond.show_behind_parent = true
	add_child(fond)
	_construire_panneau()


# ------------------------------------------------------------------
# Poser une carte
# ------------------------------------------------------------------
func poser(ruban_, carte_id_: String) -> void:
	ruban = ruban_
	carte_id = carte_id_
	bilan = {}
	medailles = []
	fete = {}
	transit = {}
	voyage_fait = {}
	transit_t = -1.0
	_projeter()
	_construire_fond()
	prochaine = ruban.gare_courante()
	chapitre = _chapitre_de_reference()
	cam = camera_voulue()
	cam_vers = {}
	# STATION_ZOOM=<k> : une caméra forcée, pour photographier le fond de carte
	# à l'échelle qu'on veut (k = 1 : tout le cadre).
	var z := OS.get_environment("STATION_ZOOM")
	if z != "":
		cam = {"x": CADRE_L / 2, "y": CADRE_H / 2, "k": float(z)}
		zoom_force = true
	rebatir()
	queue_redraw()


## Le chapitre que le panneau raconte : pendant la fête, celui qu'on vient de
## finir ; sinon celui de la gare qui vient.
func _chapitre_de_reference() -> Dictionary:
	if not fete.is_empty():
		return fete["ch"]
	var ch: Dictionary = ruban.chapitre_de_gare(prochaine) if prochaine != "" else {}
	return ch if not ch.is_empty() else ruban.chapitre_courant()


# ------------------------------------------------------------------
# La projection — cadrée sur le ruban, pas sur le continent
# ------------------------------------------------------------------
func _projeter() -> void:
	var lo0 := INF
	var lo1 := -INF
	var la0 := INF
	var la1 := -INF
	for g in ruban.ordre:
		var ll := Donnees.coord_de(g)
		if ll.is_empty():
			continue
		lo0 = min(lo0, float(ll[0]))
		lo1 = max(lo1, float(ll[0]))
		la0 = min(la0, float(ll[1]))
		la1 = max(la1, float(ll[1]))
	if not is_finite(lo0):
		proj = {}
		return
	var mx: float = max(2.0, (lo1 - lo0) * 0.35)
	var my: float = max(1.5, (la1 - la0) * 0.30)
	lo0 -= mx
	lo1 += mx
	la0 -= my
	la1 += my
	var cosm := cos(deg_to_rad((la0 + la1) / 2.0))
	var s: float = min((CADRE_L - 12) / max((lo1 - lo0) * cosm * ETIREMENT_X, 1.0),
		(CADRE_H - 12) / max(la1 - la0, 1.0))
	proj = {"lo": (lo0 + lo1) / 2.0, "la": (la0 + la1) / 2.0, "cosm": cosm, "s": s}


func _xy(lon: float, lat: float) -> Vector2:
	return Vector2(CADRE_L / 2 + (lon - proj["lo"]) * proj["cosm"] * proj["s"] * ETIREMENT_X,
		CADRE_H / 2 - (lat - proj["la"]) * proj["s"])


## La position d'une gare en unités du cadre, ou Vector2.INF.
func pos(id: String) -> Vector2:
	if proj.is_empty():
		return Vector2.INF
	var ll := Donnees.coord_de(id)
	return _xy(float(ll[0]), float(ll[1])) if not ll.is_empty() else Vector2.INF


func _construire_fond() -> void:
	for c in fond.get_children():
		fond.remove_child(c)
		c.queue_free()
	if proj.is_empty():
		return
	# UN ANNEAU QUI NE SE TRIANGULE PAS SE DESSINE EN CONTOUR. On demande
	# d'abord à Geometry2D ; s'il refuse, l'anneau devient une Line2D fermée,
	# dont la largeur suit le zoom (voir _process). Mesuré sur les 68 anneaux
	# d'Europe : aucun refus, mais deux défauts silencieux, corrigés ci-dessous.
	contours.clear()
	var rates := 0
	for r in Donnees.fond_europe:
		var pts := PackedVector2Array()
		var i := 0
		while i + 1 < r.size():
			var p := _xy(float(r[i]), float(r[i + 1]))
			if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 1e-7:
				pts.append(p)
			i += 2
		# L'ANNEAU SE FERME SUR SON PREMIER POINT RÉPÉTÉ, et le triangulateur
		# fait de cette fermeture un dernier triangle dégénéré — mesuré le 3
		# septembre 2026 sur les 68 anneaux : un triangle inversé par anneau,
		# toujours le dernier. On retire le point répété.
		if pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 1e-7:
			pts.remove_at(pts.size() - 1)
		# ET UNE OREILLE PEUT ENCORE TRAVERSER LE POLYGONE sans s'inverser :
		# la Grande-Bretagne (781 points) gardait un triangle dont le centre
		# tombe hors de l'anneau. Le passage par Clipper (merge_polygons avec
		# rien) nettoie l'anneau, et le triangle disparaît. Mesuré sur les 68
		# anneaux : un seul fautif, zéro après.
		var propres := Geometry2D.merge_polygons(pts, PackedVector2Array())
		if propres.is_empty():
			propres = [pts]
		for anneau in propres:
			if not Geometry2D.triangulate_polygon(anneau).is_empty():
				var poly := Polygon2D.new()
				poly.polygon = anneau
				poly.color = PAYS
				fond.add_child(poly)
			else:
				rates += 1
				var ligne := Line2D.new()
				ligne.points = anneau
				ligne.closed = true
				ligne.default_color = Color(BORD, 0.9)
				ligne.width = 0.2
				fond.add_child(ligne)
				contours.append(ligne)
	if rates > 0:
		print("fond : %d anneau(x) en contour (triangulation refusée)" % rates)


# ------------------------------------------------------------------
# La caméra — trois boîtes à cadrer, une fenêtre à remplir
# ------------------------------------------------------------------
## La fenêtre de la carte, en unités du cadre : l'écran moins le panneau.
func fenetre() -> Dictionary:
	var w := ECRAN_L - PANNEAU_L
	var h := ECRAN_H
	var a := w / h
	if a >= CADRE_L / CADRE_H:
		return {"w": CADRE_H * a, "h": CADRE_H, "px": w / (CADRE_H * a)}
	return {"w": CADRE_L, "h": CADRE_L / a, "px": w / CADRE_L}


## D'une position du cadre à l'écran, par la caméra courante.
func ecran(p: Vector2) -> Vector2:
	var f := fenetre()
	var centre := Vector2(PANNEAU_L + (ECRAN_L - PANNEAU_L) / 2, ECRAN_H / 2)
	return centre + (p - Vector2(cam["x"], cam["y"])) * cam["k"] * f["px"]


func zoom_pour(bw: float, bh: float, marge: float, k_max: float) -> float:
	var f := fenetre()
	var plafond: float = max(k_max, PX_PAR_UNITE_MIN / f["px"])
	return max(1.0, min(plafond, (f["w"] - 2 * marge) / max(bw, 1.0), (f["h"] - 2 * marge) / max(bh, 1.0)))


func boite(ids: Array) -> Dictionary:
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for g in ids:
		var p := pos(g)
		if p == Vector2.INF:
			continue
		x0 = min(x0, p.x)
		x1 = max(x1, p.x)
		y0 = min(y0, p.y)
		y1 = max(y1, p.y)
	if not is_finite(x0):
		return {}
	return {"x": (x0 + x1) / 2, "y": (y0 + y1) / 2, "w": x1 - x0, "h": y1 - y0}


## Ce que la carte MONTRE — pas forcément ce que le panneau raconte.
func chapitre_vu() -> Dictionary:
	if not transit.is_empty():
		return transit["chapitre"]
	if not voyage_fait.is_empty():
		return voyage_fait
	return chapitre


func camera_voulue() -> Dictionary:
	if not transit.is_empty():
		var ch1 := chapitre_vu()
		var ids: Array = [transit["de"]]
		ids.append_array(ch1["gares"] if not ch1.is_empty() else [transit["vers"]])
		var bt := boite(ids)
		if not bt.is_empty():
			return {"x": bt["x"], "y": bt["y"], "k": zoom_pour(bt["w"], bt["h"], 15, K_MAX_CHAPITRE)}
	var ch := chapitre_vu()
	if ch.is_empty():
		return {"x": CADRE_L / 2, "y": CADRE_H / 2, "k": 1.0}
	# Le voisinage, pas le chapitre entier : la gare courante avec sa
	# précédente et ses trois suivantes.
	var vues: Array = ch["gares"]
	if vues.size() > 4:
		var i: int = max(0, vues.find(ruban.gare_courante()))
		var d: int = max(0, min(i - 1, vues.size() - 4))
		vues = vues.slice(d, d + 4)
	var b := boite(vues)
	if b.is_empty():
		return {"x": CADRE_L / 2, "y": CADRE_H / 2, "k": 1.0}
	return {"x": b["x"], "y": b["y"], "k": zoom_pour(b["w"], b["h"], 15, K_MAX_CHAPITRE)}


func aller_camera(saut: bool = false) -> void:
	if zoom_force:
		return
	var v := camera_voulue()
	if is_equal_approx(v["x"], cam["x"]) and is_equal_approx(v["y"], cam["y"]) and is_equal_approx(v["k"], cam["k"]):
		return
	cam_de = cam.duplicate()
	cam_vers = v
	cam_t = 0.0
	cam_duree = DUREE_CAMERA_SAUT if saut else DUREE_CAMERA


func _process(delta: float) -> void:
	if ruban == null:
		return
	if not cam_vers.is_empty():
		cam_t = min(1.0, cam_t + delta / cam_duree)
		var e := ease(cam_t, -2.0)          # ease in-out
		# Le zoom s'interpole en log : une caméra qui recule de ×100 à ×10 le
		# fait en douceur, pas d'un coup au début.
		cam = {"x": lerp(cam_de["x"], cam_vers["x"], e), "y": lerp(cam_de["y"], cam_vers["y"], e),
			"k": exp(lerp(log(cam_de["k"]), log(cam_vers["k"]), e))}
		if cam_t >= 1.0:
			cam_vers = {}
	if not transit.is_empty():
		var duree: float = DUREE_SAUT if transit["saut"] else DUREE_VOYAGE
		if transit_t < 0.0:
			transit_t += delta / DELAI_LECTURE
			if transit_t >= 0.0:
				transit_t = 0.0
		else:
			transit_t += delta / duree
			if transit_t >= 1.0:
				_arriver()
	var f := fenetre()
	var centre := Vector2(PANNEAU_L + (ECRAN_L - PANNEAU_L) / 2, ECRAN_H / 2)
	var k: float = cam["k"] * f["px"]
	fond.transform = Transform2D(0.0, Vector2(k, k), 0.0, centre - Vector2(cam["x"], cam["y"]) * k)
	for l in contours:
		l.width = 1.2 / k
	queue_redraw()


# ------------------------------------------------------------------
# Le dessin de la carte
# ------------------------------------------------------------------
func couleur_de_zone(zid: Variant) -> Color:
	for z in ruban.zones():
		if z.get("id") == zid and z.get("couleur") is String:
			return Color(String(z["couleur"]))
	return ACCENT


## Quatre états, et ils s'excluent.
func etat_de_gare(id: String) -> String:
	if not ruban.est_ecrite(id):
		return "avenir"
	if ruban.est_faite(id):
		return "faite"
	if ruban.est_passee(id):
		return "payee"
	var i: int = ruban.index_de(id)
	return "courante" if (i >= 0 and i <= ruban.position_courante()) else "fermee"


func nom_de(id: String) -> String:
	var c := ruban.fiche_de(id)
	if c.is_empty():
		return id.capitalize()
	return String(c.get("city", c.get("name", id)))


func ville_de(id: String) -> String:
	var c := ruban.fiche_de(id)
	return String(c.get("name", c.get("city", id))) if not c.is_empty() else id.capitalize()


func _draw() -> void:
	# Le fond de l'écran est la couleur d'effacement du projet (FOND) : un
	# rectangle peint ici passerait DEVANT les pays, qui se dessinent derrière
	# ce nœud (show_behind_parent).
	if ruban == null or proj.is_empty():
		return
	var ch := chapitre_vu()
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	# --- le rail du chapitre vu ------------------------------------------------
	if not ch.is_empty():
		var g: Array = ch["gares"]
		var col := couleur_de_zone(ch["zone"])
		var gc: String = ruban.gare_courante()
		for i in range(1, g.size()):
			var a := pos(g[i - 1])
			var b := pos(g[i])
			if a == Vector2.INF or b == Vector2.INF:
				continue
			var ecrit: bool = ruban.est_ecrite(g[i - 1]) and ruban.est_ecrite(g[i])
			var fait: bool = ruban.est_franchie(g[i - 1]) and ruban.est_franchie(g[i])
			var avance: bool = ecrit and not fait and g[i] == gc
			var pa := ecran(a)
			var pb := ecran(b)
			if not ecrit:
				_pointille(pa, pb, Color(MUET, 0.5), 2.0, 6.0)
			elif fait:
				draw_line(pa, pb, col, 3.5, true)
			elif avance:
				draw_line(pa, pb, Color(col, 0.72 + 0.28 * pulse), 4.0, true)
			else:
				draw_line(pa, pb, Color(col, 0.3), 2.5, true)
	# --- la liaison de transit, et le convoi ------------------------------------
	if not transit.is_empty():
		var a := pos(transit["de"])
		var b := pos(transit["vers"])
		if a != Vector2.INF and b != Vector2.INF:
			var col := couleur_de_zone(ch["zone"]) if not ch.is_empty() else ACCENT
			var pa := ecran(a)
			var pb := ecran(b)
			_pointille(pa, pb, Color(col, 0.6), 2.5, 12.0 if transit["saut"] else 6.0)
			if transit_t >= 0.0:
				var e := ease(transit_t, -2.0)
				var p := pa.lerp(pb, e)
				draw_circle(p, 7.0, Color(col, 0.35))
				draw_circle(p, 4.0, col)
	# --- les gares du chapitre vu, et la gare quittée ---------------------------
	var dessinees: Array = []
	if not ch.is_empty():
		dessinees = ch["gares"].duplicate()
	if not transit.is_empty() and not dessinees.has(transit["de"]):
		dessinees.push_front(transit["de"])
	for id in dessinees:
		var p := pos(id)
		if p == Vector2.INF:
			continue
		var e := ecran(p)
		var etat := etat_de_gare(id)
		var chg := ruban.chapitre_de_gare(id)
		var col := couleur_de_zone(chg["zone"]) if not chg.is_empty() else ACCENT
		var fin: bool = not chg.is_empty() and chg["gares"][chg["gares"].size() - 1] == id
		var ici: bool = id == prochaine
		var r: float = 6.0 if fin else 4.5
		var teinte: Color
		match etat:
			"avenir":
				teinte = Color(MUET, 0.5)
			"fermee":
				teinte = Color(col, 0.35)
			"payee":
				teinte = Color(MUET, 0.9)
			_:
				teinte = col
		if ici:
			draw_circle(e, r + 6.0 + 3.0 * pulse, Color(col, 0.18 + 0.12 * pulse))
			draw_arc(e, r + 4.0, 0.0, TAU, 40, Color(col, 0.9), 1.5, true)
		if not bilan.is_empty() and bilan.get("gare") == id:
			draw_arc(e, r + 9.0, 0.0, TAU, 48, Color(OR, 0.8), 1.5, true)
		draw_circle(e, r, teinte)
		if etat == "payee":
			draw_arc(e, r, 0.0, TAU, 24, col, 1.0, true)
		# le nom, au-dessus ; les étoiles ou le diamant à sa droite
		var nom := nom_de(id)
		var taille := 15 if fin else 13
		var w := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var st: int = Rub.etoiles_de(ruban.progression_de(id))
		var dia: bool = Rec.est_diamant(ruban.progression_de(id))
		var suffixe := "◆" if dia else ("★".repeat(st) if st > 0 else "")
		var ws := police.get_string_size(suffixe, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x if suffixe != "" else 0.0
		var x0 := e.x - (w + (ws + 4.0 if ws > 0 else 0.0)) / 2
		var y0 := e.y - r - 8
		draw_string(police, Vector2(x0, y0), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille,
			TEXTE if etat != "avenir" and etat != "fermee" else MUET)
		if suffixe != "":
			draw_string(police, Vector2(x0 + w + 4, y0), suffixe, HORIZONTAL_ALIGNMENT_LEFT, -1, taille,
				DIAMANT if dia else OR)


func _pointille(a: Vector2, b: Vector2, col: Color, larg: float, pas: float) -> void:
	var d := a.distance_to(b)
	if d < 0.5:
		return
	var dir := (b - a) / d
	var s := 0.0
	while s < d:
		var e: float = min(d, s + pas)
		draw_line(a + dir * s, a + dir * e, col, larg, true)
		s += pas * 2


# ------------------------------------------------------------------
# Ce qui se passe quand une gare est franchie
# ------------------------------------------------------------------
## Appelé par la fin de service (app) et par le passage payé.
func fin_de_service(b: Dictionary, meds: Array) -> void:
	bilan = b
	medailles = meds
	fete = {}
	transit = {}
	voyage_fait = {}
	transit_t = -1.0
	prochaine = ruban.gare_courante()
	if b.get("win", false):
		_preparer_suite(String(b["gare"]))
	chapitre = _chapitre_de_reference()
	rebatir()
	aller_camera(voyage_saut)


func apres_passage(id: String) -> void:
	bilan = {}
	medailles = []
	fete = {}
	prochaine = ruban.gare_courante()
	_preparer_suite(id)
	chapitre = _chapitre_de_reference()
	rebatir()
	aller_camera(voyage_saut)


func _preparer_suite(id: String) -> void:
	var ch: Dictionary = ruban.chapitre_de_gare(id)
	var gc: String = ruban.gare_courante()
	var nouveau: Dictionary = ruban.chapitre_de_gare(gc) if gc != "" else {}
	prochaine = gc
	voyage_saut = false
	if not ch.is_empty() and ruban.chapitre_termine(ch) and nouveau.get("id") != ch.get("id"):
		var chs: Array = ruban.chapitres
		var rang: int = ch["rang"]
		var zone_finie := true
		for c in chs:
			if c["zone"] == ch["zone"] and not ruban.chapitre_termine(c):
				zone_finie = false
		fete = {"ch": ch, "suivant": chs[rang + 1] if rang + 1 < chs.size() else {}, "zone_finie": zone_finie}
		# Le voyage vers le chapitre suivant se joue PENDANT la lecture du bilan.
		if not gc.is_empty() and not nouveau.is_empty():
			transit = {"de": ch["gares"][ch["gares"].size() - 1], "vers": gc, "chapitre": nouveau,
				"saut": nouveau["saut"] != null}
			transit_t = -1.0
	else:
		voyage_saut = not nouveau.is_empty() and nouveau.get("id") != ch.get("id") and nouveau["saut"] != null


func _arriver() -> void:
	var t := transit
	transit = {}
	transit_t = -1.0
	voyage_fait = t["chapitre"]
	aller_camera(t["saut"])


## Cliquer une gare : un service commence, le relevé appartient au passé.
func jouer(id: String) -> void:
	if not ruban.est_tenue(id):
		return
	if not fete.is_empty():
		if not transit.is_empty():
			voyage_saut = transit["saut"]
			transit = {}
			transit_t = -1.0
		fete = {}
		voyage_fait = ruban.chapitre_de_gare(id)
	bilan = {}
	medailles = []
	if app != null:
		app.jouer(id)


func _unhandled_input(event: InputEvent) -> void:
	if ruban == null or not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = event.position
		if m.x < PANNEAU_L:
			return
		var ch := chapitre_vu()
		if ch.is_empty():
			return
		for id in ch["gares"]:
			var p := pos(id)
			if p == Vector2.INF:
				continue
			var etat := etat_de_gare(id)
			if etat != "faite" and etat != "courante" and etat != "payee":
				continue
			if ecran(p).distance_to(m) <= 16.0:
				jouer(id)
				return


# ------------------------------------------------------------------
# Le panneau de gauche — tout ce qui se lit, d'un seul côté
# ------------------------------------------------------------------
func _construire_panneau() -> void:
	panneau = PanelContainer.new()
	panneau.position = Vector2.ZERO
	panneau.size = Vector2(PANNEAU_L, ECRAN_H)
	var style := StyleBoxFlat.new()
	style.bg_color = PANNEAU
	style.border_color = BORD
	style.border_width_right = 1
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.anti_aliasing = true
	panneau.add_theme_stylebox_override("panel", style)
	add_child(panneau)
	var defil := ScrollContainer.new()
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panneau.add_child(defil)
	colonne = VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_theme_constant_override("separation", 10)
	defil.add_child(colonne)


## `replie` : un texte long se replie sur la largeur du panneau ; un compteur
## ou une mesure ne se replie jamais — dans une rangée, un Label qui se
## replie n'a plus de largeur minimale et s'écrit lettre par lettre.
func _label(texte: String, taille: int, couleur: Color, gras: bool = false, replie: bool = true) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Sty.sans(600 if gras else 400))
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("line_spacing", 5)
	if replie:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _bouton(texte: String, principal: bool, actif: bool, sur: Callable) -> Button:
	var b := Sty.bouton(texte, principal, 16 if principal else 14)
	b.disabled = not actif
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sd := Sty.boite(Color("#1a2234"), Sty.BORD, 10, 1)
	sd.content_margin_top = 8
	sd.content_margin_bottom = 8
	sd.content_margin_left = 14
	sd.content_margin_right = 14
	b.add_theme_stylebox_override("disabled", sd)
	b.add_theme_color_override("font_disabled_color", Sty.MUET)
	if sur.is_valid():
		b.pressed.connect(sur)
	return b


func _separateur() -> Control:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 8)
	return s


func _vider(noeud: Node) -> void:
	for c in noeud.get_children():
		noeud.remove_child(c)
		c.queue_free()


## Tout le panneau, d'un bloc — comme renderCarte dans le prototype.
func rebatir() -> void:
	_vider(colonne)
	if ruban == null:
		return
	colonne.add_child(_compteurs())
	colonne.add_child(_entete_chapitre())
	# LE RELEVÉ DE LA GARE RESTE pendant la fête : au seul moment du jeu où
	# deux récompenses tombent ensemble, on ne perd pas de vue les étoiles
	# qu'on vient de décrocher. Les médailles, elles, vont à la fête.
	if not bilan.is_empty():
		colonne.add_child(_bloc_bilan(fete.is_empty()))
	if not fete.is_empty():
		colonne.add_child(_bloc_fete())
	if prochaine != "" and fete.is_empty():
		colonne.add_child(_cartouche(prochaine))
	colonne.add_child(_pied())
	if app != null and app.plusieurs_cartes():
		colonne.add_child(_bouton("Les cartes", false, true, app.ouvrir_cartes))


func _compteurs() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var n: int = Rec.etoiles_total(Sauvegarde.progression_toutes_cartes())
	var g: Dictionary = Rec.grade_de(n)
	var serie: Dictionary = Sauvegarde.get_serie()
	var e: Dictionary = Rec.etat_recompenses(ruban, serie)
	if int(serie["n"]) >= 2:
		h.add_child(_label("» %d" % int(serie["n"]), 13, ACCENT, false, false))
	var grade := _label(String(g["nom"]), 13, TEXTE, false, false)
	grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(grade)
	if app != null:
		h.add_child(_label("%d cr" % app.solde(), 13, MUET, false, false))
	if int(e["diamants"]) > 0:
		h.add_child(_label("◆ %d" % int(e["diamants"]), 13, DIAMANT, false, false))
	h.add_child(_label("★ %d" % n, 13, OR, false, false))
	var v := VBoxContainer.new()
	v.add_child(h)
	var jauge := ProgressBar.new()
	jauge.show_percentage = false
	jauge.custom_minimum_size = Vector2(0, 4)
	jauge.value = 100.0 * float(g["part"])
	var fondj := StyleBoxFlat.new()
	fondj.bg_color = Color("#1f2a40")
	var plein := StyleBoxFlat.new()
	plein.bg_color = ACCENT
	jauge.add_theme_stylebox_override("background", fondj)
	jauge.add_theme_stylebox_override("fill", plein)
	v.add_child(jauge)
	v.add_child(_separateur())
	return v


func _entete_chapitre() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var ch := chapitre
	if ch.is_empty():
		v.add_child(_label(String(ruban.carte.get("nom", "La carte")), 22, TEXTE, true))
		return v
	var col := couleur_de_zone(ch["zone"])
	v.add_child(_label("Chapitre %d / %d" % [int(ch["rang"]) + 1, ruban.chapitres.size()], 12, MUET))
	v.add_child(_label(String(ch["nom"]), 22, TEXTE, true))
	var zone_nom := String(ruban.carte.get("nom", ""))
	for z in ruban.zones():
		if z.get("id") == ch["zone"]:
			zone_nom = String(z.get("nom", zone_nom))
	v.add_child(_label(zone_nom, 13, col))
	# la jauge du chapitre : un cran par gare
	var crans := ""
	var faits := 0
	for g in ch["gares"]:
		var p: Dictionary = ruban.progression_de(g)
		if ruban.est_faite(g):
			faits += 1
		if g == prochaine:
			crans += "◉"
		elif Rec.est_diamant(p):
			crans += "◆"
		elif ruban.est_faite(g):
			crans += "●"
		elif ruban.est_passee(g):
			crans += "◌"
		else:
			crans += "○"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var lc := _label(crans, 14, col, false, false)
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lc)
	var rang: Dictionary = Rec.rang_de_chapitre(ruban, ch)
	if not rang.is_empty() and rang["id"] != "ouverte" and fete.is_empty():
		h.add_child(_label(String(rang["nom"]), 12, Color(String(rang["couleur"])), false, false))
	else:
		h.add_child(_label("%d/%d" % [faits, ch["gares"].size()], 12, MUET, false, false))
	v.add_child(h)
	v.add_child(_separateur())
	return v


func _pips(d: int) -> String:
	var n: int = max(1, min(5, d if d > 0 else 1))
	return "▮".repeat(n) + "▯".repeat(5 - n)


## La gare en cours, et ce qu'il faut en savoir : quais, directions,
## difficulté, barème.
func _cartouche(id: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var cfg := ruban.fiche_de(id)
	if cfg.is_empty():
		return v
	var ch := ruban.chapitre_de_gare(id)
	var rang := ruban.rang_dans_chapitre(id)
	var total: int = ch["gares"].size() if not ch.is_empty() else 0
	var fin: bool = not ch.is_empty() and ch["gares"][total - 1] == id
	var d := ruban.difficulte_de_gare(id, cfg)
	var quais: int = Array(cfg.get("platforms", [])).size()
	var dirs: int = (cfg["portals"] as Dictionary).size() if cfg.get("portals") is Dictionary else 0
	var seuils := ruban.seuils_de_service(cfg)
	var pays := Donnees.pays_de(String(cfg.get("country", "")))
	v.add_child(_label("Gare %d sur %d%s" % [rang, total, "  ·  terminus" if fin else ""], 12, MUET))
	v.add_child(_label(ville_de(id), 20, TEXTE, true))
	v.add_child(_label("%s %s" % [pays.get("drapeau", ""), pays.get("nom", "")], 13, MUET))
	var phrase := String(cfg.get("tagline", ""))
	var re := RegEx.new()
	re.compile("^\\s*[^—–-]{2,28}\\s*[—–]\\s*")
	phrase = re.sub(phrase, "", false)
	if phrase != "":
		v.add_child(_label(phrase, 13, TEXTE))
	if ruban.est_boss(id, cfg):
		v.add_child(_label("Bourrasque — le trafic se resserre en fin de service.", 13, OR))
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 14)
	for paire in [["Quais", str(quais)], ["Directions", str(dirs)], ["Difficulté", _pips(d)], ["Pour 3 ★", "%d min" % int(seuils["trois"])]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(_label(paire[0], 11, MUET, false, false))
		cell.add_child(_label(paire[1], 16, OR if paire[0] == "Difficulté" else TEXTE, false, false))
		grille.add_child(cell)
	v.add_child(grille)
	var p: Dictionary = ruban.progression_de(id)
	var st := Rub.etoiles_de(p)
	if st > 0:
		var score := "★".repeat(st)
		if Rec.est_diamant(p):
			score += "   ◆ sans faute"
		elif p.get("bestDelay") != null:
			score += "   record %d min" % int(p["bestDelay"])
		v.add_child(_label(score, 14, OR))
	v.add_child(_separateur())
	return v


## Le relevé du service, sous la gare qu'on vient de tenir.
func _bloc_bilan(avec_medailles: bool = true) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var b := bilan
	var st := int(b["stars"])
	v.add_child(_label(ville_de(String(b["gare"])), 13, MUET))
	v.add_child(_label("★".repeat(st) + "☆".repeat(3 - st), 26, OR if b["win"] else MUET))
	if b.get("perfect", false):
		v.add_child(_label("◆ Diamant", 15, DIAMANT))
	if b.get("failed", false):
		v.add_child(_label("%d min — plafond dépassé" % int(b["d"]), 14, ROUGE))
	elif b.get("perfect", false):
		v.add_child(_label("0 min — pas une minute", 14, TEXTE))
	else:
		v.add_child(_label("%d min de retard" % int(b["d"]), 14, TEXTE))
	var pb: Variant = b.get("prevBest")
	if b.get("failed", false):
		pass
	elif not b["win"]:
		v.add_child(_label("objectif manqué", 12, MUET))
	elif pb == null:
		v.add_child(_label("premier service", 12, ACCENT))
	elif float(b["d"]) < float(pb):
		v.add_child(_label("record battu · −%d min" % int(float(pb) - float(b["d"])), 12, ACCENT))
	elif float(b["d"]) == float(pb):
		v.add_child(_label("record égalé", 12, MUET))
	else:
		v.add_child(_label("record : %d min" % int(pb), 12, MUET))
	var s: Dictionary = b.get("seuils", {})
	if not s.is_empty() and b["win"] and not b.get("perfect", false) and st < 3:
		v.add_child(_label("3 ★ sous %d min" % int(s["trois"]), 12, MUET))
	if avec_medailles:
		_ajouter_medailles(v, 2)
	v.add_child(_separateur())
	return v


func _ajouter_medailles(v: VBoxContainer, combien: int) -> void:
	if medailles.is_empty():
		return
	var montrees: Array = medailles.slice(0, combien) if combien > 0 and medailles.size() > combien else medailles
	for m in montrees:
		v.add_child(_label("%s — %s" % [m["nom"], m["dit"]], 13, OR))
	var reste := medailles.size() - montrees.size()
	if reste > 0:
		v.add_child(_label("+%d" % reste, 12, MUET))


## La fête de fin de chapitre : ce qu'on a gagné, et ce qui reste à prendre.
func _bloc_fete() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var ch: Dictionary = fete["ch"]
	var n: int = ch["gares"].size()
	var et := 0
	var dia := 0
	var payees := 0
	for g in ch["gares"]:
		var p: Dictionary = ruban.progression_de(g)
		et += Rub.etoiles_de(p)
		if Rec.est_diamant(p):
			dia += 1
		if ruban.est_passee(g):
			payees += 1
	var et_max := n * 3
	v.add_child(_label("Chapitre terminé", 12, couleur_de_zone(ch["zone"])))
	v.add_child(_label("%d / %d ★     %d ◆" % [et, et_max, dia], 20, OR, true))
	var rang: Dictionary = Rec.rang_de_chapitre(ruban, ch)
	if not rang.is_empty() and rang["id"] != "ouverte":
		v.add_child(_label(String(rang["nom"]), 15, Color(String(rang["couleur"]))))
	if et == et_max and dia == n:
		v.add_child(_label("Pas une minute de retard, nulle part.", 13, DIAMANT))
	elif et < et_max:
		var reste := et_max - et
		var texte := "%d étoile%s à prendre ici" % [reste, "s" if reste > 1 else ""]
		if payees > 0:
			texte += ", dont %d gare%s passée%s" % [payees, "s" if payees > 1 else "", "s" if payees > 1 else ""]
		v.add_child(_label(texte + ".", 13, TEXTE))
	else:
		v.add_child(_label("Toutes les étoiles. Reste les sans-faute : %d." % (n - dia), 13, TEXTE))
	if fete.get("zone_finie", false):
		for z in ruban.zones():
			if z.get("id") == ch["zone"]:
				v.add_child(_label("%s — région traversée" % String(z.get("nom", "")), 13, couleur_de_zone(ch["zone"])))
	_ajouter_medailles(v, 0)
	v.add_child(_separateur())
	return v


## Les boutons : un seul geste au repos, et il nomme la gare.
func _pied() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var gc := prochaine
	if not fete.is_empty():
		var suivant: Dictionary = fete["suivant"]
		if not suivant.is_empty() and gc != "":
			v.add_child(_label("Chapitre suivant · %s" % String(suivant["nom"]), 12, MUET))
			v.add_child(_bouton("Jouer  ·  " + ville_de(gc), true, true, jouer.bind(gc)))
		else:
			v.add_child(_label("Le ruban s'arrête ici — pour le moment.", 13, MUET))
		return v
	if not bilan.is_empty() and not bilan["win"]:
		var gare := String(bilan["gare"])
		var prix: int = Rec.prix_de_passage(ruban, gare)
		var solde: int = app.solde() if app != null else 0
		var assez := solde >= prix
		if not assez:
			var manque := prix - solde
			v.add_child(_label("Il te manque %d crédit%s — rejoue une gare déjà faite pour les gagner." % [manque, "s" if manque > 1 else ""], 12, MUET))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(_bouton("Passer · %d cr" % prix, false, assez, _passer.bind(gare)))
		h.add_child(_bouton("Réessayer  ·  " + ville_de(gare), true, true, jouer.bind(gare)))
		v.add_child(h)
		return v
	if not bilan.is_empty():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(_bouton("Rejouer", false, true, jouer.bind(String(bilan["gare"]))))
		if gc != "":
			h.add_child(_bouton("Jouer  ·  " + ville_de(gc), true, true, jouer.bind(gc)))
		v.add_child(h)
		return v
	if gc != "":
		v.add_child(_bouton("Jouer  ·  " + ville_de(gc), true, true, jouer.bind(gc)))
		return v
	v.add_child(_label("La suite du ruban n'est pas encore écrite." if ruban.au_bout_de_l_ecrit()
		else "Le ruban est terminé. Reste à le dorer.", 13, MUET))
	return v


func _passer(id: String) -> void:
	if app != null:
		app.passer(id)
