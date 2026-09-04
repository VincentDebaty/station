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
const PANNEAU_L := 380.0   # au bureau ; sur un téléphone, × Sty.HUD_K
const ECRAN_L := 1400.0
const ECRAN_H := 760.0
const K_MAX_CHAPITRE := 200.0
const PX_PAR_UNITE_MIN := 48.0
const DUREE_CAMERA := 0.75
const DUREE_CAMERA_SAUT := 1.5
const DUREE_VOYAGE := 1.15
const DUREE_SAUT := 1.9
const DELAI_LECTURE := 0.7

# LA CARTE EST UN PARCHEMIN (4 septembre 2026). L'écran du ruban passe à la
# palette de jeu.style.gd : cuir, laiton, encre. Le poste d'aiguillage, lui,
# garde la sienne — la couleur d'une voie y est sa destination.
const FOND := Sty.MER
const PAYS := Sty.TERRE
const PANNEAU := Sty.BOIS
const BORD := Sty.LAITON
const TEXTE := Sty.PAPIER
const MUET := Color("#a28f74")
const ACCENT := Sty.SARCELLE_CLAIR
const OR := Sty.LAITON
const DIAMANT := Color("#9fdcd6")
const ROUGE := Color("#c4553d")

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
var barre: PanelContainer      # la barre du haut, sur toute la largeur
var rangee_barre: HBoxContainer
var panneau: PanelContainer
var colonne: VBoxContainer
var pied: VBoxContainer     # le geste, ancré en bas : il ne défile jamais
var police: Font


func _ready() -> void:
	Sty.calibrer(get_viewport())
	# la mer sous la carte : c'est la couleur d'effacement qui la porte, et
	# l'écran de jeu remet la sienne en reprenant la main (app.gd, montrer).
	RenderingServer.set_default_clear_color(Sty.MER)
	police = Sty.titre(600)
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


## LE PANNEAU SUIT LE FACTEUR DU BANDEAU. Sans cela il gardait sa largeur de
## bureau — 380 unités sur les 1 652 d'un iPhone, soit un quart d'écran de
## texte minuscule : « c'est très petit comme si on avait dézoomé » (Vincent,
## 3 septembre 2026). Tout ce qui se lit dans ce panneau passe par _label et
## _bouton, qui multiplient eux aussi.
func panneau_l() -> float:
	return PANNEAU_L * Sty.HUD_K


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
				# le trait de côte, à l'encre pâle : c'est lui qui fait la carte
				var cote := Line2D.new()
				cote.points = anneau
				cote.closed = true
				cote.default_color = Color(Sty.TERRE_OMBRE, 0.9)
				cote.width = 0.35
				fond.add_child(cote)
				contours.append(cote)
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
	var e := get_viewport_rect().size
	var w: float = max(50.0, e.x - panneau_l() - Sty.marges["gauche"] - Sty.marges["droite"])
	var h: float = max(50.0, e.y - hauteur_barre() - Sty.marges["bas"])
	var a := w / h
	if a >= CADRE_L / CADRE_H:
		return {"w": CADRE_H * a, "h": CADRE_H, "px": w / (CADRE_H * a)}
	return {"w": CADRE_L, "h": CADRE_L / a, "px": w / CADRE_L}


## D'une position du cadre à l'écran, par la caméra courante.
func ecran(p: Vector2) -> Vector2:
	var f := fenetre()
	return _centre_carte() + (p - Vector2(cam["x"], cam["y"])) * cam["k"] * f["px"]


## Le milieu de la carte : ce qui reste à droite du panneau, dans la zone sûre.
func _centre_carte() -> Vector2:
	var e := get_viewport_rect().size
	var g: float = panneau_l() + Sty.marges["gauche"]
	return Vector2(g + (e.x - g - Sty.marges["droite"]) / 2.0,
		hauteur_barre() + (e.y - hauteur_barre() - Sty.marges["bas"]) / 2.0)


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
	# LES NOMS DÉBORDENT À DROITE DES POINTS. Cadrer la boîte des seuls points
	# laissait tout le contenu poussé vers la droite de l'écran, une plaque de
	# large — « la carte devrait être mieux centrée » (4 septembre 2026). On
	# mesure la plus longue plaque des gares cadrées et on décale la caméra
	# d'une demi-plaque : le contenu revient au milieu.
	# DEUX PASSES, parce que le calcul se mord la queue : la largeur d'une
	# plaque est en pixels, sa traduction en unités dépend du zoom, et le zoom
	# dépend de la largeur à cadrer. On zoome donc une première fois sur les
	# points seuls, on en tire la place que prennent les noms, puis on refait
	# le cadrage sur la boîte élargie. Deux passes suffisent : la correction
	# de la seconde est petite devant la première.
	var k := zoom_pour(b["w"], b["h"], 15, K_MAX_CHAPITRE)
	var plaques := _largeur_plaques(vues, k)
	k = zoom_pour(b["w"] + plaques, b["h"], 15, K_MAX_CHAPITRE)
	plaques = _largeur_plaques(vues, k)
	return {"x": b["x"] + plaques / 2.0, "y": b["y"], "k": k}


## La plus large étiquette des gares cadrées, en unités du cadre.
func _largeur_plaques(ids: Array, k: float) -> float:
	if police == null or k <= 0.0:
		return 0.0
	var px: float = fenetre()["px"]
	if px <= 0.0:
		return 0.0
	var large := 0.0
	var t := int(round(15 * Sty.HUD_K))
	for id in ids:
		large = max(large, police.get_string_size(nom_de(id), HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
			+ 46.0 * Sty.HUD_K)
	return large / (k * px)


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
	var k: float = cam["k"] * f["px"]
	fond.transform = Transform2D(0.0, Vector2(k, k), 0.0, _centre_carte() - Vector2(cam["x"], cam["y"]) * k)
	for l in contours:
		l.width = 1.6 * Sty.HUD_K / k
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
			# UNE VOIE, PAS UN TRAIT : deux files de rail et leurs traverses,
			# comme sur une carte ferroviaire. Le tracé parcouru est en laiton
			# vif, celui qui vient respire, celui qu'on n'a pas ouvert reste
			# gris de fonte.
			var k := Sty.HUD_K
			if not ecrit:
				_pointille(pa, pb, Color(Sty.LAITON, 0.28), 2.0 * k, 7.0 * k)
			elif fait:
				_voie(pa, pb, Sty.LAITON_CLAIR, k, 1.0)
			elif avance:
				_voie(pa, pb, Sty.LAITON_CLAIR, k, 0.65 + 0.35 * pulse)
			else:
				_voie(pa, pb, Color("#7a6a55"), k, 0.75)
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
	_rose_des_vents()

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
		var r: float = (6.0 if fin else 4.5) * Sty.HUD_K
		var teinte: Color
		match etat:
			"avenir":
				teinte = Color(Sty.LAITON, 0.30)
			"fermee":
				teinte = Color(Sty.LAITON, 0.45)
			"payee":
				teinte = Color(Sty.PAPIER_OMBRE, 0.85)
			_:
				teinte = Sty.LAITON
		var kk := Sty.HUD_K
		if ici:
			# la gare qui vient : un halo d'ambre, comme une lampe posée dessus
			draw_circle(e, r + (7.0 + 4.0 * pulse) * kk, Color(Sty.LAITON, 0.16 + 0.12 * pulse))
			draw_circle(e, r + 3.0 * kk, Color(Sty.LAITON_CLAIR, 0.55 + 0.25 * pulse))
			draw_arc(e, r + 5.0 * kk, 0.0, TAU, 40, Color(Sty.LAITON_CLAIR, 0.95), 2.0 * kk, true)
		if not bilan.is_empty() and bilan.get("gare") == id:
			draw_arc(e, r + 9.0 * kk, 0.0, TAU, 48, Color(Sty.LAITON, 0.8), 1.6 * kk, true)
		draw_circle(e, r + 1.5 * kk, Color(Sty.BOIS, 0.85))
		draw_circle(e, r, Sty.LAITON_CLAIR if ici else teinte)
		draw_arc(e, r, 0.0, TAU, 28, Color(Sty.BOIS, 0.55), 1.2 * kk, true)
		# LE NOM SUR UNE PLAQUE, comme sur une vraie carte ferroviaire : une
		# étiquette posée à côté du point, et non un texte flottant que le
		# relief traverse. Sarcelle et laiton quand la gare est tenue, papier
		# fané quand elle attend son tour.
		var nom := nom_de(id)
		var taille := int(round((15 if fin else 13) * Sty.HUD_K))
		var w := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var prog := ruban.progression_de(id)
		var st: int = Rub.etoiles_de(prog)
		var dia: bool = Rec.est_diamant(prog)
		var suffixe := "◆" if dia else ("★".repeat(st) if st > 0 else "")
		var ws := police.get_string_size(suffixe, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x if suffixe != "" else 0.0
		var ouverte: bool = etat == "faite" or etat == "courante" or etat == "payee"
		var pad := 7.0 * Sty.HUD_K
		var large := w + (ws + 5.0 * Sty.HUD_K if ws > 0 else 0.0) + 2 * pad
		var haute := taille + 8.0 * Sty.HUD_K
		var plaque := Rect2(e.x + r + 6 * Sty.HUD_K, e.y - haute / 2, large, haute)
		draw_style_box(Sty.plaque(Sty.SARCELLE if ouverte else Color(Sty.BOIS_CLAIR, 0.9),
			Color(Sty.LAITON, 0.9 if ouverte else 0.45), 5, Sty.HUD_K), plaque)
		var encre: Color = Sty.PAPIER if ouverte else MUET
		var xt := plaque.position.x + pad
		Sty.texte_centre(self, police, taille, Vector2(xt + w / 2, e.y), nom, encre)
		if suffixe != "":
			Sty.texte_centre(self, police, taille,
				Vector2(xt + w + 5 * Sty.HUD_K + ws / 2, e.y), suffixe, DIAMANT if dia else Sty.LAITON_CLAIR)
		# une gare qu'on ne peut pas encore jouer porte son cadenas
		if not ouverte:
			var c := Vector2(plaque.end.x + 9 * Sty.HUD_K, e.y)
			draw_style_box(Sty.boite(Color(Sty.BOIS_CLAIR, 0.95), Color(Sty.LAITON, 0.5), 3 * kk, max(1.0, kk)),
				Rect2(c.x - 5 * kk, c.y - 4 * kk, 10 * kk, 8 * kk))
			draw_arc(Vector2(c.x, c.y - 4 * kk), 3.2 * kk, PI, TAU, 12, Color(Sty.LAITON, 0.7), 1.4 * kk, true)


## UNE VOIE FERRÉE : le ballast sombre, les traverses, puis les deux files de
## rail. Les traverses sont espacées à l'ÉCRAN et non dans le monde — sinon
## elles se collent quand on dézoome et disparaissent quand on approche.
func _voie(a: Vector2, b: Vector2, col: Color, k: float, force: float) -> void:
	var d := a.distance_to(b)
	if d < 1.0:
		return
	var u := (b - a) / d
	var n := Vector2(-u.y, u.x)
	var demi := 2.2 * k
	draw_line(a, b, Color(Sty.BOIS, 0.55 * force), 8.0 * k, true)      # le ballast
	var pas := 9.0 * k
	var s := pas / 2.0
	while s < d:
		var p := a + u * s
		draw_line(p - n * demi * 1.55, p + n * demi * 1.55, Color(col, 0.55 * force), 1.6 * k, true)
		s += pas
	draw_line(a - n * demi, b - n * demi, Color(col, force), 1.7 * k, true)
	draw_line(a + n * demi, b + n * demi, Color(col, force), 1.7 * k, true)


## LA ROSE DES VENTS, posée dans l'angle de la carte. Elle est à l'ÉCRAN et
## non sur le terrain : un ornement de cartouche ne dérive pas avec le zoom.
func _rose_des_vents() -> void:
	var k := Sty.HUD_K
	var e := get_viewport_rect().size
	var c := Vector2(e.x - Sty.marges["droite"] - 42 * k, hauteur_barre() + 46 * k)
	var R := 22.0 * k
	var col := Color(Sty.LAITON, 0.38)
	draw_arc(c, R, 0, TAU, 40, col, 1.2 * k, true)
	draw_arc(c, R * 0.72, 0, TAU, 36, Color(Sty.LAITON, 0.22), 1.0 * k, true)
	# les quatre branches principales, en losanges effilés
	for i in range(4):
		var a: float = -PI / 2 + PI / 2 * float(i)
		var u := Vector2(cos(a), sin(a))
		var n := Vector2(-u.y, u.x)
		draw_colored_polygon(PackedVector2Array([
			c + u * R, c + n * R * 0.16, c, c - n * R * 0.16]), Color(Sty.LAITON, 0.55))
	# et les quatre secondaires, plus courtes
	for i in range(4):
		var a: float = -PI / 4 + PI / 2 * float(i)
		draw_line(c, c + Vector2(cos(a), sin(a)) * R * 0.62, Color(Sty.LAITON, 0.30), 1.0 * k, true)
	Sty.texte_centre(self, police, int(round(9 * k)), c + Vector2(0, -R - 7 * k), "N", Color(Sty.LAITON, 0.75))


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
		if m.x < panneau_l() + Sty.marges["gauche"]:
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
## LA BARRE DU HAUT PREND TOUTE LA LARGEUR (demandé le 3 septembre 2026).
## Les compteurs — grade, jauge, crédits, diamants, étoiles — sont un fait de
## COMPTE, pas de carte : ils ne dépendent ni du chapitre ni de la gare, et
## n'avaient rien à faire dans la colonne du ruban, où ils volaient la hauteur
## qui manquait au reste. Sortis là-haut, la colonne respire et la barre de
## défilement disparaît.
func hauteur_barre() -> float:
	return 34.0 * Sty.HUD_K + Sty.marges["haut"]


func _construire_panneau() -> void:
	var k := Sty.HUD_K
	barre = PanelContainer.new()
	barre.position = Vector2.ZERO
	var sb := StyleBoxFlat.new()
	sb.bg_color = Sty.BOIS_CLAIR
	sb.border_color = Color(Sty.LAITON, 0.55)
	sb.border_width_bottom = int(max(1.0, 2 * k))
	sb.content_margin_left = 18 * k + Sty.marges["gauche"]
	sb.content_margin_right = 18 * k + Sty.marges["droite"]
	sb.content_margin_top = 7 * k + Sty.marges["haut"]
	sb.content_margin_bottom = 7 * k
	barre.add_theme_stylebox_override("panel", sb)
	add_child(barre)
	rangee_barre = HBoxContainer.new()
	rangee_barre.add_theme_constant_override("separation", int(round(14 * k)))
	barre.add_child(rangee_barre)

	panneau = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANNEAU
	style.border_color = Color(Sty.LAITON, 0.55)
	style.border_width_right = int(max(1.0, 2 * k))
	style.content_margin_left = 22 * k + Sty.marges["gauche"]
	style.content_margin_right = 22 * k
	style.content_margin_top = 16 * k
	style.content_margin_bottom = 16 * k + Sty.marges["bas"]
	style.anti_aliasing = true
	panneau.add_theme_stylebox_override("panel", style)
	add_child(panneau)
	var defil := ScrollContainer.new()
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# LA BARRE DE DÉFILEMENT NE S'AFFICHE PLUS. Elle disait « il y a autre
	# chose plus bas » sur un écran où tout doit se voir d'un coup ; le
	# glissement au doigt reste possible si le contenu déborde quand même.
	# Il faut habiller le RAIL et les trois états du curseur : n'en oublier
	# qu'un laisse un trait clair sur le bord du panneau.
	# LE GESTE NE DÉFILE PAS. Le bouton d'appel était en bas de la colonne, donc
	# emporté hors de l'écran dès que la fiche s'allongeait — « le bouton est
	# tronqué » (Vincent, 4 septembre 2026, en Cinzel qui prend plus de place).
	# Il vit désormais dans un pied FIXE : ce qui se lit peut défiler, ce qui
	# se touche est toujours là.
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", int(round(10 * k)))
	panneau.add_child(pile)
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pile.add_child(defil)
	var bar := defil.get_v_scroll_bar()
	for quoi in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(quoi, StyleBoxEmpty.new())
	bar.custom_minimum_size = Vector2.ZERO
	colonne = VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_theme_constant_override("separation", int(round(10 * k)))
	defil.add_child(colonne)
	pied = VBoxContainer.new()
	pied.add_theme_constant_override("separation", int(round(8 * k)))
	pile.add_child(pied)
	_poser_cadre()
	get_viewport().size_changed.connect(_poser_cadre)


## La barre en haut sur toute la largeur, le panneau dessous.
func _poser_cadre() -> void:
	var e := get_viewport_rect().size
	barre.position = Vector2.ZERO
	barre.size = Vector2(e.x, 0)
	panneau.position = Vector2(0, hauteur_barre())
	panneau.size = Vector2(panneau_l() + Sty.marges["gauche"], e.y - hauteur_barre())


## `replie` : un texte long se replie sur la largeur du panneau ; un compteur
## ou une mesure ne se replie jamais — dans une rangée, un Label qui se
## replie n'a plus de largeur minimale et s'écrit lettre par lettre.
## `gras` ne dit plus « en gras » mais « en TITRE » : Cinzel, la capitale
## lapidaire de la direction artistique. Le texte courant reste en Garamond.
func _label(texte: String, taille: int, couleur: Color, gras: bool = false, replie: bool = true) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Sty.titre(600) if gras else Sty.sans(400))
	l.add_theme_font_size_override("font_size", int(round(taille * Sty.HUD_K)))
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("line_spacing", int(round(5 * Sty.HUD_K)))
	if replie:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _bouton(texte: String, principal: bool, actif: bool, sur: Callable) -> Button:
	var k := Sty.HUD_K
	var b := Sty.bouton(texte, principal, 16 if principal else 14, k)
	b.disabled = not actif
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# LE BOUTON EST UNE PLAQUE VISSÉE : sarcelle profonde et liseré de laiton
	# pour l'appel, bois pour le reste. Le texte s'y écrit sur le papier.
	var fond: Color = Sty.SARCELLE if principal else Sty.BOIS_CLAIR
	var normal := Sty.plaque(fond, Sty.LAITON, 8, k)
	normal.content_margin_top = 10 * k
	normal.content_margin_bottom = 10 * k
	normal.content_margin_left = 16 * k
	normal.content_margin_right = 16 * k
	b.add_theme_stylebox_override("normal", normal)
	var survol := normal.duplicate()
	survol.bg_color = fond.lightened(0.10)
	survol.border_color = Sty.LAITON_CLAIR
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	var eteint := normal.duplicate()
	eteint.bg_color = Color(Sty.BOIS, 0.9)
	eteint.border_color = Color(Sty.LAITON, 0.35)
	b.add_theme_stylebox_override("disabled", eteint)
	for quoi in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(quoi, Sty.PAPIER)
	b.add_theme_color_override("font_disabled_color", Color(Sty.PAPIER, 0.4))
	if sur.is_valid():
		b.pressed.connect(sur)
	return b


func _separateur() -> Control:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
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
	_remplir_barre()
	colonne.add_child(_entete_chapitre())
	# LE RELEVÉ DE LA GARE RESTE pendant la fête : au seul moment du jeu où
	# deux récompenses tombent ensemble, on ne perd pas de vue les étoiles
	# qu'on vient de décrocher. Les médailles, elles, vont à la fête.
	if not bilan.is_empty():
		colonne.add_child(_bloc_bilan(fete.is_empty()))
	if not fete.is_empty():
		colonne.add_child(_bloc_fete())
	# APRÈS UN SERVICE, LA FICHE COMPLÈTE CÈDE LA PLACE AU RELEVÉ. Les deux
	# ensemble ne tiennent pas sur un téléphone, et elles ne se lisent pas au
	# même moment : le relevé dit ce qu'on vient de faire, la fiche prépare le
	# geste suivant — que le bouton nomme déjà. Elle se réduit donc à sa seule
	# ligne utile tant que le relevé est là.
	if prochaine != "" and fete.is_empty():
		if bilan.is_empty():
			colonne.add_child(_cartouche(prochaine))
		else:
			colonne.add_child(_ligne_suivante(prochaine))
	_vider(pied)
	pied.add_child(_pied())


## LA BARRE DU HAUT : le grade et sa jauge à gauche, les compteurs à droite,
## sur toute la largeur de l'écran. Ce sont des faits de COMPTE — ils ne
## bougent pas quand on change de chapitre.
func _remplir_barre() -> void:
	_vider(rangee_barre)
	var k := Sty.HUD_K
	var n: int = Rec.etoiles_total(Sauvegarde.progression_toutes_cartes())
	var g: Dictionary = Rec.grade_de(n)
	var serie: Dictionary = Sauvegarde.get_serie()
	var e: Dictionary = Rec.etat_recompenses(ruban, serie)

	# le grade, avec sa jauge de progression juste dessous
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", int(round(4 * k)))
	bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nom := _label(String(g["nom"]), 13, TEXTE, true, false)
	nom.clip_text = true
	bloc.add_child(nom)
	var jauge := ProgressBar.new()
	jauge.show_percentage = false
	jauge.custom_minimum_size = Vector2(90 * k, 3 * k)
	jauge.value = 100.0 * float(g["part"])
	jauge.add_theme_stylebox_override("background", Sty.boite(Color("#1f2a40"), Color.TRANSPARENT, 2 * k, 0))
	jauge.add_theme_stylebox_override("fill", Sty.boite(ACCENT, Color.TRANSPARENT, 2 * k, 0))
	bloc.add_child(jauge)
	rangee_barre.add_child(bloc)

	# la série, puis la monnaie du jeu — chacune dans sa pastille
	if int(serie["n"]) >= 2:
		rangee_barre.add_child(_pastille("» %d" % int(serie["n"]), ACCENT))
	if app != null:
		rangee_barre.add_child(_pastille("%d cr" % app.solde(), MUET))
	if int(e["diamants"]) > 0:
		rangee_barre.add_child(_pastille("◆ %d" % int(e["diamants"]), DIAMANT))
	rangee_barre.add_child(_pastille("★ %d" % n, OR))
	# « Les cartes » vit dans la barre, pas dans la colonne : c'est un geste de
	# navigation, pas une étape du ruban, et il libère la hauteur qui manquait.
	if app != null and app.plusieurs_cartes():
		var b := Sty.bouton("Les cartes", false, 12, k)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(app.ouvrir_cartes)
		rangee_barre.add_child(b)


## Une pastille de compteur : le verre dépoli du bandeau de jeu, en plus petit.
func _pastille(texte: String, couleur: Color) -> Control:
	var k := Sty.HUD_K
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := Sty.boite(Color(couleur, 0.10), Color(couleur, 0.35), 8 * k, max(1.0, k))
	st.content_margin_left = 9 * k
	st.content_margin_right = 9 * k
	st.content_margin_top = 3 * k
	st.content_margin_bottom = 3 * k
	p.add_theme_stylebox_override("panel", st)
	p.add_child(_label(texte, 13, couleur, true, false))
	return p


func _entete_chapitre() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(2 * Sty.HUD_K)))
	var ch := chapitre
	if ch.is_empty():
		v.add_child(_label(String(ruban.carte.get("nom", "La carte")), 22, TEXTE, true))
		return v
	var col := couleur_de_zone(ch["zone"])
	# « Chapitre 1 / 49 » RETIRÉ (demandé le 3 septembre 2026) : sur un
	# téléphone la hauteur est la ressource rare, et le rang du chapitre ne
	# sert à rien pour décider du geste suivant. La jauge à crans, elle, dit
	# déjà où l'on en est DANS le chapitre — la seule position qui compte.
	v.add_child(_label(String(ch["nom"]), 22, Sty.PAPIER, true))
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
	h.add_theme_constant_override("separation", int(round(10 * Sty.HUD_K)))
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
## LA GARE QUI VIENT, dans sa propre carte. Elle porte ce qu'il faut savoir
## AVANT de prendre le service : quais et directions — d'où vient la
## difficulté — le niveau, et le barème. « Gare 2 sur 5 » a été RETIRÉ le
## 3 septembre 2026 : la jauge à crans du chapitre, juste au-dessus, dit déjà
## la même chose et le dit mieux, en montrant ce qui est fait.
func _cartouche(id: String) -> Control:
	var k := Sty.HUD_K
	var cfg := ruban.fiche_de(id)
	if cfg.is_empty():
		return VBoxContainer.new()
	var ch := ruban.chapitre_de_gare(id)
	var total: int = ch["gares"].size() if not ch.is_empty() else 0
	var fin: bool = not ch.is_empty() and total > 0 and ch["gares"][total - 1] == id
	var d := ruban.difficulte_de_gare(id, cfg)
	var quais: int = Array(cfg.get("platforms", [])).size()
	var dirs: int = (cfg["portals"] as Dictionary).size() if cfg.get("portals") is Dictionary else 0
	var seuils := ruban.seuils_de_service(cfg)
	var pays := Donnees.pays_de(String(cfg.get("country", "")))

	# la carte de la gare : un fond légèrement relevé, un liseré discret
	var carte_gare := PanelContainer.new()
	var st := Sty.parchemin(10, k)
	st.set_content_margin_all(14 * k)
	carte_gare.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(4 * k)))
	carte_gare.add_child(v)

	# le nom, le drapeau, et le terminus s'il y a lieu — sur une ligne
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", int(round(8 * k)))
	var nom := _label(ville_de(id), 20, Sty.ENCRE, true, false)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.clip_text = true
	tete.add_child(nom)
	if fin:
		tete.add_child(_pastille("terminus", OR))
	v.add_child(tete)
	v.add_child(_label("%s %s" % [pays.get("drapeau", ""), pays.get("nom", "")], 12, Sty.SARCELLE))

	var phrase := String(cfg.get("tagline", ""))
	var re := RegEx.new()
	re.compile("^\\s*[^—–-]{2,28}\\s*[—–]\\s*")
	phrase = re.sub(phrase, "", false)
	if phrase != "":
		v.add_child(_label(phrase, 13, Sty.ENCRE))
	if ruban.est_boss(id, cfg):
		v.add_child(_label("Bourrasque — le trafic se resserre en fin de service.", 13, OR))

	# les quatre mesures, séparées du reste par un filet
	var filet := HSeparator.new()
	filet.add_theme_stylebox_override("separator", Sty.boite(Sty.PAPIER_OMBRE, Color.TRANSPARENT, 0, 0))
	filet.add_theme_constant_override("separation", int(round(10 * k)))
	v.add_child(filet)
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", int(round(16 * k)))
	for trio in [["Quais", str(quais), "loco"], ["Directions", str(dirs), "aiguille"],
			["Difficulté", _pips(d), ""], ["Pour 3 ★", "%d min" % int(seuils["trois"]), "horloge"]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(_label(String(trio[0]).to_upper(), 11, Sty.ENCRE_MUET, true, false))
		# la figure à gauche de la valeur, comme sur la maquette
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", int(round(5 * k)))
		if trio[2] != "":
			ligne.add_child(_icone(String(trio[2]), 17 * k, Sty.ENCRE_MUET))
		ligne.add_child(_label(String(trio[1]), 16,
			OR if trio[0] == "Difficulté" else Sty.ENCRE, false, false))
		cell.add_child(ligne)
		grille.add_child(cell)
	v.add_child(grille)

	# ce qu'on y a déjà fait
	var p: Dictionary = ruban.progression_de(id)
	var stars := Rub.etoiles_de(p)
	if stars > 0:
		var score := "★".repeat(stars)
		if Rec.est_diamant(p):
			score += "   ◆ sans faute"
		elif p.get("bestDelay") != null:
			score += "   record %d min" % int(p["bestDelay"])
		v.add_child(_label(score, 14, OR))
	return carte_gare


## La gare qui vient, en une ligne : son nom, sa taille, son barème. C'est
## tout ce qui aide à décider, et c'est ce qui reste quand le relevé occupe
## la place.
func _ligne_suivante(id: String) -> Control:
	var cfg := ruban.fiche_de(id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(2 * Sty.HUD_K)))
	if cfg.is_empty():
		return v
	var quais: int = Array(cfg.get("platforms", [])).size()
	var dirs: int = (cfg["portals"] as Dictionary).size() if cfg.get("portals") is Dictionary else 0
	var seuils := ruban.seuils_de_service(cfg)
	v.add_child(_label("SUIVANTE", 11, MUET, true, false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(10 * Sty.HUD_K)))
	var nom := _label(ville_de(id), 16, Sty.PAPIER, true, false)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.clip_text = true
	h.add_child(nom)
	h.add_child(_label("%d quais · %d dir. · 3 ★ sous %d min" % [quais, dirs, int(seuils["trois"])],
		12, MUET, false, false))
	v.add_child(h)
	return v


## Le relevé du service, sous la gare qu'on vient de tenir.
## LE RELEVÉ DU SERVICE, EN QUATRE LIGNES AU PLUS. Il en tenait six, et la
## gare suivante passait sous le bord de l'écran : les étoiles et le retard
## se lisent d'un même regard, le record et l'objectif aussi. Ce qui compte
## ici, c'est ce qu'on vient de faire — le reste attend son tour.
func _bloc_bilan(avec_medailles: bool = true) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(3 * Sty.HUD_K)))
	var b := bilan
	var st := int(b["stars"])
	v.add_child(_label(ville_de(String(b["gare"])), 12, MUET, false, false))

	# les étoiles, et à leur droite ce que le service a coûté
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(10 * Sty.HUD_K)))
	h.add_child(_label("★".repeat(st) + "☆".repeat(3 - st), 22, OR if b["win"] else MUET, false, false))
	var retard: String
	var couleur: Color = TEXTE
	if b.get("failed", false):
		retard = "%d min — plafond dépassé" % int(b["d"])
		couleur = ROUGE
	elif b.get("perfect", false):
		retard = "◆ Diamant — pas une minute"
		couleur = DIAMANT
	else:
		retard = "%d min de retard" % int(b["d"])
	var lr := _label(retard, 14, couleur, false, false)
	lr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(lr)
	v.add_child(h)

	# le record d'un côté, l'objectif de l'autre — sur la même ligne
	var pb: Variant = b.get("prevBest")
	var dit := ""
	var teinte: Color = MUET
	if b.get("failed", false):
		dit = ""
	elif not b["win"]:
		dit = "objectif manqué"
	elif pb == null:
		dit = "premier service"
		teinte = ACCENT
	elif float(b["d"]) < float(pb):
		dit = "record battu · −%d min" % int(float(pb) - float(b["d"]))
		teinte = ACCENT
	elif float(b["d"]) == float(pb):
		dit = "record égalé"
	else:
		dit = "record : %d min" % int(pb)
	var seuils: Dictionary = b.get("seuils", {})
	var vise := ""
	if not seuils.is_empty() and b["win"] and not b.get("perfect", false) and st < 3:
		vise = "3 ★ sous %d min" % int(seuils["trois"])
	if dit != "" or vise != "":
		var h2 := HBoxContainer.new()
		h2.add_theme_constant_override("separation", int(round(10 * Sty.HUD_K)))
		if dit != "":
			var ld := _label(dit, 12, teinte, false, false)
			ld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h2.add_child(ld)
		if vise != "":
			h2.add_child(_label(vise, 12, MUET, false, false))
		v.add_child(h2)

	if avec_medailles:
		_ajouter_medailles(v, 2)
	v.add_child(_separateur())
	return v


func _ajouter_medailles(v: VBoxContainer, combien: int) -> void:
	if medailles.is_empty():
		return
	# la médaille du sans-faute doublerait la ligne du diamant, juste au-dessus
	var utiles: Array = medailles.filter(func(m): return not (m["id"] == "sf1" and not bilan.is_empty() and bilan.get("perfect", false)))
	var montrees: Array = utiles.slice(0, combien) if combien > 0 and utiles.size() > combien else utiles
	for m in montrees:
		v.add_child(_label("%s — %s" % [m["nom"], m["dit"]], 13, OR))
	var reste := utiles.size() - montrees.size()
	if reste > 0:
		v.add_child(_label("+%d" % reste, 12, MUET))


## La fête de fin de chapitre : ce qu'on a gagné, et ce qui reste à prendre.
func _bloc_fete() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(3 * Sty.HUD_K)))
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
	v.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
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
		h.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
		h.add_child(_bouton("Passer · %d cr" % prix, false, assez, _passer.bind(gare)))
		h.add_child(_bouton("Réessayer  ·  " + ville_de(gare), true, true, jouer.bind(gare)))
		v.add_child(h)
		return v
	if not bilan.is_empty():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
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


## LES ICÔNES SONT DESSINÉES, PAS IMPORTÉES. Une locomotive, une aiguille, un
## cadran : trois figures simples qui se tracent au trait et suivent le
## facteur d'échelle sans jamais pixeliser. Le jour où une vraie illustration
## les remplacera, seul ce bloc changera.
class Icone extends Control:
	var quoi := ""
	var col := Color.WHITE
	var ep := 1.5

	func _draw() -> void:
		var r := size
		var c := r / 2.0
		match quoi:
			"loco":
				# caisse, cabine, cheminée, deux roues
				var corps := Rect2(r.x * 0.10, r.y * 0.34, r.x * 0.62, r.y * 0.34)
				draw_rect(corps, col, false, ep)
				draw_rect(Rect2(r.x * 0.62, r.y * 0.18, r.x * 0.28, r.y * 0.50), col, false, ep)
				draw_line(Vector2(r.x * 0.22, r.y * 0.34), Vector2(r.x * 0.22, r.y * 0.18), col, ep)
				draw_arc(Vector2(r.x * 0.28, r.y * 0.76), r.x * 0.10, 0, TAU, 14, col, ep)
				draw_arc(Vector2(r.x * 0.70, r.y * 0.76), r.x * 0.10, 0, TAU, 14, col, ep)
				draw_line(Vector2(0, r.y * 0.90), Vector2(r.x, r.y * 0.90), col, ep)
			"aiguille":
				# une voie qui se divise : le geste même du jeu
				draw_line(Vector2(c.x, r.y * 0.92), Vector2(c.x, r.y * 0.52), col, ep)
				draw_line(Vector2(c.x, r.y * 0.52), Vector2(r.x * 0.14, r.y * 0.10), col, ep)
				draw_line(Vector2(c.x, r.y * 0.52), Vector2(c.x, r.y * 0.10), col, ep)
				draw_line(Vector2(c.x, r.y * 0.52), Vector2(r.x * 0.86, r.y * 0.10), col, ep)
			"horloge":
				draw_arc(c, r.x * 0.40, 0, TAU, 28, col, ep)
				draw_line(c, c + Vector2(0, -r.y * 0.26), col, ep)
				draw_line(c, c + Vector2(r.x * 0.20, r.y * 0.12), col, ep)
			"etoile":
				var pts := PackedVector2Array()
				for i in range(10):
					var a: float = -PI / 2 + PI * float(i) / 5.0
					var rad: float = r.x * (0.44 if i % 2 == 0 else 0.19)
					pts.append(c + Vector2(cos(a), sin(a)) * rad)
				draw_colored_polygon(pts, col)


func _icone(quoi: String, taille: float, col: Color) -> Control:
	var i := Icone.new()
	i.quoi = quoi
	i.col = col
	i.ep = max(1.0, 1.4 * Sty.HUD_K)
	i.custom_minimum_size = Vector2(taille, taille)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return i
