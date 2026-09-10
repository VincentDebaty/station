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
const Ill := preload("res://jeu/illustrations.gd")

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
## Au-delà de cette course, un doigt ne DÉSIGNE plus, il TIRE. Un demi-
## centimètre sur l'appareil de Vincent : assez pour qu'un doigt qui appuie ne
## déclenche pas un déplacement, assez peu pour qu'un déplacement démarre sans
## qu'on ait à forcer.
const COURSE_CLIC := 14.0
## Au-delà, on ne rend plus que les points : le placement des plaques est
## quadratique, et à cette densité aucun nom ne serait lisible de toute façon.
const PLAQUES_MAX := 26
## LES BORNES DU ZOOM LIBRE. En bas, 1 : la carte entière tient dans la
## fenêtre, on ne recule pas au-delà. En haut, deux fois le plafond du cadrage
## automatique — de quoi lire une gare de près sans que le fond de carte, qui
## est dessiné en unités de terrain, ne se délite.
const K_MIN_LIBRE := 1.0
const K_MAX_LIBRE := 2.0 * K_MAX_CHAPITRE
## Un cran de molette. Le pincement, lui, suit le rapport des doigts.
const CRAN_ZOOM := 1.18

# --- LA REMISE DES RÉCOMPENSES, en trois temps ------------------------------
# « Les étoiles arrivent en grand au milieu de l'écran et se replacent dans le
# cadre à gauche. Si il y a un diamant, on fait la même chose dans un second
# temps. Dernier temps, la carte s'anime en faisant traverser la ligne la puce
# jaune qui brille vers la ville suivante. » (Vincent, 9 septembre 2026)
const SEQ_DELAI := 0.30      # le temps que l'écran finisse d'arriver
const SEQ_ECART := 0.17      # d'une étoile à la suivante
const SEQ_POSE := 0.28       # une récompense grandit au milieu
const SEQ_TENUE := 0.22      # elle s'y tient, le temps qu'on la voie
const SEQ_TENUE_GEMME := 0.75  # le sans-faute se tient plus longtemps : il est rare
const SEQ_VOL := 0.55        # puis rejoint sa place sur la feuille
const SEQ_ENTRE := 0.25      # entre deux temps
const SEQ_PUCE := 1.20       # la puce d'un bout à l'autre de la liaison

# LA CARTE EST UN PARCHEMIN (4 septembre 2026). L'écran du ruban passe à la
# palette de jeu.style.gd : cuir, laiton, encre. Le poste d'aiguillage, lui,
# garde la sienne — la couleur d'une voie y est sa destination.
const FOND := Sty.MER
const PAYS := Sty.TERRE
const PANNEAU := Sty.BOIS
const BORD := Sty.LAITON
const TEXTE := Sty.PAPIER
const MUET := Color("#a28f74")
# CE QUI S'ÉCRIT SUR LE PAPIER. Tout le contenu du panneau est passé sur une
# seule feuille de parchemin : le relevé, la fête et la ligne « suivante »,
# écrits jusqu'ici en clair sur du bois, s'écrivent maintenant à l'encre.
# L'or n'y tient pas tel quel — #d9a441 sur #efe3c8 ne fait pas de contraste —
# il fonce d'un cran, comme une dorure imprimée plutôt qu'une ferrure.
const P_ENCRE := Sty.ENCRE
const P_MUET := Sty.ENCRE_MUET
const P_OR := Color("#9c6f1c")
const P_ACCENT := Sty.SARCELLE
const ACCENT := Sty.SARCELLE_CLAIR
const OR := Sty.LAITON
# PLUS BLEU, et c'est une couleur de pierre, pas d'écran : « le diamant sera
# plus bleu » (Vincent, 10 septembre 2026). C'était une sarcelle pâle, #9fdcd6,
# qui se confondait avec la sarcelle des plaques de gare tenues — deux choses
# différentes dites dans la même couleur.
const DIAMANT := Color("#6fbcf5")
const ROUGE := Color("#c4553d")

var app = null
var ruban: Rub = null
var carte_id := ""

# --- la projection, fixée par carte ------------------------------------------
var proj := {}                # {lo, la, cosm, s} — vide tant qu'aucune carte
var fond: Node2D              # les pays, en Polygon2D, sous la caméra
var contours: Array = []      # les anneaux dessinés en Line2D, à la largeur du zoom

# --- DE QUOI FAIRE UNE VIEILLE CARTE ----------------------------------------
# Trois techniques, et il en faut trois parce que le zoom va de l'Europe
# entière à cinq gares — aucune ne tient seule sur cet écart :
#
#   LE GRAIN DE PAPIER est en coordonnées d'ÉCRAN. C'est la feuille sur
#   laquelle la carte est imprimée, pas un terrain : elle ne bouge pas, ne
#   grossit pas, et ne peut donc jamais devenir floue.
#
#   LES HACHURES DE CÔTE sont VECTORIELLES et calculées une fois par carte,
#   par décalage des anneaux de pays. Du vecteur reste net à tout zoom, et
#   c'est la signature d'une carte ancienne : le rivage y est ombré de deux
#   ou trois traits parallèles qui s'éloignent dans la mer.
#
#   LE RELIEF est semé en coordonnées d'écran mais ANCRÉ par un bruit lu en
#   coordonnées du monde. Il garde donc une densité constante à l'œil — une
#   gravure a toujours la même finesse de trait, quelle que soit l'échelle —
#   tout en restant collé au terrain quand la carte se déplace.
var bruit := FastNoiseLite.new()
var papier: NoiseTexture2D
var anneaux: Array = []       # [{pts, bbox}] en unités du cadre, pour savoir où est la terre
var courbes: Dictionary = {}  # "gare|gare" -> le tracé de la liaison, en unités du cadre
var relief_traits := PackedVector2Array()
var relief_pour := {}         # la caméra pour laquelle le relief a été semé

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
var selection := ""           # la gare choisie sur la carte, dont le panneau parle

# --- la remise des récompenses ----------------------------------------------
var seq := ""                 # "" | "etoiles" | "diamant" | "puce"
var seq_t := 0.0
var seq_n := 0                # combien d'étoiles volent
var vol: Node2D               # la couche qui les dessine, PAR-DESSUS le panneau
var lbl_etoiles: Label        # leur place d'arrivée sur la feuille
var lbl_diamant: Label
var bloc_diamant: Control      # le sceau qu'on masque en entier jusqu'à l'atterrissage
var seq_joues := 0            # combien de sons d'étoile déjà donnés
var puce_de := ""
var puce_vers := ""
var plaques_ecran := {}       # la place des plaques au dernier dessin, pour le doigt

# --- LA CARTE SE DÉPLACE AU DOIGT --------------------------------------------
var cam_libre := false        # le joueur a pris la main sur le cadrage
var emprise := Rect2(0, 0, CADRE_L, CADRE_H)   # ce que la carte a le droit de montrer
var glisse_pris := false      # un doigt est posé sur la carte
var glisse_depuis := Vector2.ZERO
var glisse_cam := Vector2.ZERO
var glisse_course := 0.0      # combien il a parcouru : au-delà, ce n'est plus un clic
var zone_recentrer := Rect2()
var doigts := {}              # index du doigt -> position, pour le pincement
var pince_ecart := 0.0        # l'écart entre les deux doigts au début du geste
var pince_k := 1.0            # et le zoom qu'on avait alors

# --- le panneau ---------------------------------------------------------------------
var barre: PanelContainer      # la barre du haut, sur toute la largeur
var rangee_barre: HBoxContainer
var panneau: PanelContainer
var colonne: VBoxContainer
var pied: VBoxContainer     # le geste, ancré en bas : il ne défile jamais
var police: Font


func _ready() -> void:
	Sty.calibrer(get_viewport())
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX
	bruit.frequency = 0.9
	bruit.fractal_octaves = 3
	# le grain : un bruit fin et SANS COUTURE, pour se répéter sur tout l'écran
	papier = NoiseTexture2D.new()
	papier.width = 256
	papier.height = 256
	papier.seamless = true
	papier.as_normal_map = false
	var g := FastNoiseLite.new()
	g.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	g.frequency = 0.28
	g.fractal_octaves = 4
	papier.noise = g
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# la mer sous la carte : c'est la couleur d'effacement qui la porte, et
	# l'écran de jeu remet la sienne en reprenant la main (app.gd, montrer).
	RenderingServer.set_default_clear_color(Sty.MER)
	police = Sty.titre(600)
	fond = Node2D.new()
	fond.show_behind_parent = true
	add_child(fond)
	_construire_panneau()
	# LA COUCHE DE VOL EST LE DERNIER ENFANT, et c'est tout ce qui la définit :
	# un enfant se dessine après son parent, et le panneau est un enfant. Une
	# étoile peinte dans le `_draw` de cette vue passerait DERRIÈRE la feuille,
	# c'est-à-dire derrière l'endroit même où elle doit atterrir.
	vol = Vol.new()
	vol.vue = self
	add_child(vol)


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
	_construire_courbes()
	_mesurer_emprise()
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
	_poser_fond()
	queue_redraw()
	_remise_pour_voir()


## STATION_REMISE=<étoiles>[,diamant] : la remise des récompenses jouée sur la
## gare courante, SANS SERVICE ET SANS RIEN ÉCRIRE — de quoi la photographier
## et la revoir. Le joueur scripté n'a jamais fait de sans-faute : sans ce
## crochet, le deuxième temps ne se vérifierait qu'à la main.
func _remise_pour_voir() -> void:
	var arg := OS.get_environment("STATION_REMISE")
	if arg == "" or prochaine == "":
		return
	var mots := arg.split(",", false)
	# la gare « jouée » est celle d'AVANT : sans cela la puce du dernier temps
	# n'aurait nulle part où aller
	var i: int = ruban.index_de(prochaine)
	var gare: String = String(ruban.ordre[i - 1]) if i > 0 else prochaine
	var etoiles: int = clampi(int(mots[0]), 1, 3)
	var dia: bool = mots.size() > 1 and String(mots[1]).strip_edges() == "diamant"
	var seuils := ruban.seuils_de_service(ruban.fiche_de(gare))
	fin_de_service({"gare": gare, "stars": etoiles, "prevStars": 0, "d": 0 if dia else 7,
		"prevBest": null, "perfect": dia, "failed": false, "win": true, "seuils": seuils}, [])


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
	anneaux.clear()
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
			# on retient l'anneau et sa boîte : c'est ce qui dira, plus tard et
			# vite, si un point du relief tombe sur la terre ou dans l'eau.
			var bb := Rect2(anneau[0], Vector2.ZERO)
			for pt in anneau:
				bb = bb.expand(pt)
			anneaux.append({"pts": anneau, "bbox": bb})
			# LES HACHURES DE CÔTE : deux traits qui s'éloignent dans la mer,
			# de plus en plus pâles. Geometry2D sait décaler un polygone ; on
			# le fait UNE FOIS par carte, et le résultat reste net à tout zoom.
			var d := 0.30
			for niveau in range(2):
				for large in Geometry2D.offset_polygon(anneau, d):
					if large.size() < 3:
						continue
					var h := Line2D.new()
					h.points = large
					h.closed = true
					h.default_color = Color(Sty.TERRE_OMBRE, 0.55 - 0.20 * niveau)
					h.width = 0.25
					fond.add_child(h)
					contours.append(h)
				d += 0.42
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
# LES VOIES SE COURBENT
# ------------------------------------------------------------------
# Un rail tiré à la règle d'une gare à l'autre donne un zigzag d'épingles ;
# une carte ferroviaire montre des courbes, et une voie EST courbe — c'est
# même sa contrainte première. La base est une spline de Catmull-Rom passant
# par toutes les gares du chapitre : lisse, continue, et elle ne coupe aucun
# angle puisqu'elle passe exactement par chaque point.
#
# PUIS ON REGARDE LA MER. « Éviter de traverser la mer comme entre Salerne et
# Paola » (Vincent, 5 septembre 2026) : la corde Salerne-Paola coupe le golfe
# de Policastro, et aucune spline ne l'en sortira — c'est la géographie qui
# décide, pas le lissage. On ajoute donc, au segment fautif SEULEMENT, un
# renflement perpendiculaire nul aux deux bouts — 4t(1−t) — et on retient le
# premier écart qui ramène le tracé sur la terre. Nul aux deux bouts : la voie
# continue d'aboutir exactement sur ses gares, et les liaisons voisines ne
# bougent pas.
#
# UNE VRAIE TRAVERSÉE NE SE CORRIGE PAS. Le train qui prend le bateau passe
# le détroit de Messine, et aucun écart ne l'en dispensera : quand même le
# meilleur essai laisse le tracé dans l'eau, on garde la spline. Un bac se
# dessine droit.
const COURBE_PAS := 14
const COURBE_ECARTS := [0.07, -0.07, 0.14, -0.14, 0.24, -0.24, 0.36, -0.36]


func _construire_courbes() -> void:
	courbes.clear()
	if ruban == null or proj.is_empty():
		return
	var debut := Time.get_ticks_usec()
	var corriges := 0
	# LA COURBE NE S'ARRÊTE PLUS AU BOUT D'UN CHAPITRE. Chaque chapitre était
	# courbé pour lui seul : la liaison qui mène au chapitre suivant n'avait
	# donc pas de tracé du tout, et retombait sur la DROITE de secours — « il y
	# a juste une simple ligne pour aller au chapitre suivant » (Vincent, 9
	# septembre 2026). On courbe désormais des SUITES : le rail continu, d'un
	# chapitre à l'autre, coupé seulement par un saut — un saut n'est pas du
	# rail, et il garde son pointillé. Les fins de chapitre y gagnent en plus
	# leurs vrais points de contrôle, au lieu du reflet qu'on leur inventait.
	var suites: Array = []
	var suite: Array = []
	for ch in ruban.chapitres:
		if ch.get("saut") != null and not suite.is_empty():
			suites.append(suite)
			suite = []
		for id in ch["gares"]:
			suite.append(id)
	if not suite.is_empty():
		suites.append(suite)
	for gares in suites:
		var ids: Array = []
		var pts: Array = []
		for id in gares:
			var p := pos(id)
			if p != Vector2.INF:
				ids.append(id)
				pts.append(p)
		for i in range(1, pts.size()):
			# les deux points de contrôle : le voisin, ou son reflet au bout
			var p0: Vector2 = pts[i - 2] if i >= 2 else pts[i - 1] * 2.0 - pts[i]
			var p3: Vector2 = pts[i + 1] if i + 1 < pts.size() else pts[i] * 2.0 - pts[i - 1]
			var trace := _tracer(p0, pts[i - 1], pts[i], p3)
			if trace[1]:
				corriges += 1
			courbes[ids[i - 1] + "|" + ids[i]] = trace[0]
	print("courbes : %d liaisons, %d écartées de l'eau, %.1f ms" % [
		courbes.size(), corriges, (Time.get_ticks_usec() - debut) / 1000.0])


## Le tracé d'une liaison, et s'il a fallu l'écarter de l'eau.
func _tracer(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> Array:
	var base := PackedVector2Array()
	for j in range(COURBE_PAS + 1):
		base.append(_catmull(p0, p1, p2, p3, float(j) / float(COURBE_PAS)))
	var reste := _dans_l_eau(base)
	if reste == 0:
		return [base, false]
	var d := p2 - p1
	var l := d.length()
	if l <= 0.0:
		return [base, false]
	var n := Vector2(-d.y, d.x) / l
	for e in COURBE_ECARTS:
		var essai := PackedVector2Array()
		for j in range(base.size()):
			var t := float(j) / float(COURBE_PAS)
			essai.append(base[j] + n * (e * l) * 4.0 * t * (1.0 - t))
		var manque := _dans_l_eau(essai)
		if manque == 0:
			return [essai, true]
	return [base, false]


## Combien de points du tracé tombent dans l'eau — les DEUX BOUTS EXCEPTÉS :
## ce sont les gares, elles ne bougeront pas, et une gare posée sur une île
## que le fond de carte ignore condamnerait sa liaison à ne jamais convenir.
func _dans_l_eau(pts: PackedVector2Array) -> int:
	var n := 0
	for i in range(1, pts.size() - 1):
		if not _sur_terre(pts[i]):
			n += 1
	return n


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (2.0 * p1 + (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (p3 - p0 + 3.0 * (p1 - p2)) * t3)


## Le tracé d'une liaison, en points d'écran. À défaut de courbe — deux gares
## que rien ne relie dans un chapitre — la droite reste le repli.
func _voie_ecran(a: String, b: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c: Variant = courbes.get(a + "|" + b)
	if c is PackedVector2Array:
		for p in c:
			out.append(ecran(p))
		return out
	var pa := pos(a)
	var pb := pos(b)
	if pa != Vector2.INF and pb != Vector2.INF:
		out.append(ecran(pa))
		out.append(ecran(pb))
	return out


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
	return _ecran_de(p, cam)


## La même chose, par une caméra QUELCONQUE. Le cadrage doit pouvoir mesurer
## ce que donnerait une caméra qu'il n'a pas encore adoptée : sans cela il ne
## peut pas savoir où tomberont les plaques, donc pas cadrer ce qu'il montre.
func _ecran_de(p: Vector2, c: Dictionary) -> Vector2:
	var f := fenetre()
	return _centre_carte() + (p - Vector2(c["x"], c["y"])) * float(c["k"]) * f["px"]


## Le milieu de la carte : ce qui reste à droite du panneau, dans la zone sûre.
func _centre_carte() -> Vector2:
	var e := get_viewport_rect().size
	var g: float = panneau_l() + Sty.marges["gauche"]
	return Vector2(g + (e.x - g - Sty.marges["droite"]) / 2.0,
		hauteur_barre() + (e.y - hauteur_barre() - Sty.marges["bas"]) / 2.0)


## L'inverse d'`ecran` : où tombe, dans le cadre, un point de l'écran. C'est
## ce qui permet d'ancrer un semis dessiné à l'écran sur le terrain qu'il
## couvre.
func monde(p: Vector2) -> Vector2:
	return _monde_de(p, cam)


func _monde_de(p: Vector2, c: Dictionary) -> Vector2:
	var f := fenetre()
	var k: float = float(c["k"]) * f["px"]
	if k <= 0.0:
		return Vector2.ZERO
	return (p - _centre_carte()) / k + Vector2(c["x"], c["y"])


## Le degré de longitude d'une abscisse du cadre, et la latitude d'une
## ordonnée : l'inverse de `_xy`. C'est ce qui permet de savoir quels
## méridiens et quels parallèles passent dans la fenêtre.
func _lon(x: float) -> float:
	return proj["lo"] + (x - CADRE_L / 2) / (proj["cosm"] * proj["s"] * ETIREMENT_X)


func _lat(y: float) -> float:
	return proj["la"] + (CADRE_H / 2 - y) / proj["s"]


## LA SURFACE PEINTE de la carte : à droite du panneau, sous la barre, et
## JUSQU'AUX BORDS DE L'ÉCRAN. Le grain, le relief et le graticule s'arrêtaient
## à la zone sûre et laissaient une bande claire, non grainée, à droite et en
## bas — « il faut étirer le carré plus sombre sur toute la carte » (Vincent,
## 5 septembre 2026). La zone sûre retient ce qu'on doit LIRE ; elle n'a rien à
## dire du fond, et un papier va jusqu'au bord de la feuille.
func surface_carte() -> Rect2:
	var e := get_viewport_rect().size
	var g: float = panneau_l() + Sty.marges["gauche"]
	return Rect2(g, hauteur_barre(), max(1.0, e.x - g), max(1.0, e.y - hauteur_barre()))


## Le rectangle où la carte POSE ce qui se lit : la surface, moins la zone
## sûre. C'est lui que consulte le placement des plaques et la rose des vents.
func cadre_carte() -> Rect2:
	var e := get_viewport_rect().size
	var g: float = panneau_l() + Sty.marges["gauche"]
	return Rect2(g, hauteur_barre(),
		max(1.0, e.x - g - Sty.marges["droite"]),
		max(1.0, e.y - hauteur_barre() - Sty.marges["bas"]))


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
	# CADRER CE QU'ON DESSINE, et rien d'autre. Le cadrage prenait un
	# VOISINAGE — la gare courante, sa précédente et ses trois suivantes —
	# alors que le dessin montre tout le chapitre : à York, Darlington tombait
	# hors du cadrage tout en restant à l'écran, et la caméra poussait la
	# scène dans un angle. « Le centrage n'est pas bon » (Vincent, 5 septembre
	# 2026) : c'était ça, et c'était structurel.
	var ids := gares_dessinees()
	var b := boite(ids)
	if b.is_empty():
		return {"x": CADRE_L / 2, "y": CADRE_H / 2, "k": 1.0}
	# TROIS PASSES, parce que le calcul se mord la queue : la place que prend
	# une plaque est en pixels, sa traduction en unités du cadre dépend du
	# zoom, et le zoom dépend de la place à ménager. On cadre donc les points
	# seuls, on pose les plaques, on remesure l'encombrement réel, et on
	# recommence. À la troisième passe plus rien ne bouge à l'œil.
	var c := {"x": b["x"], "y": b["y"], "k": zoom_pour(b["w"], b["h"], 15, K_MAX_CHAPITRE)}
	for passe in 3:
		var r := _encombrement(ids, c)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			break
		var a := _monde_de(r.position, c)
		var z := _monde_de(r.end, c)
		c = {"x": (a.x + z.x) / 2.0, "y": (a.y + z.y) / 2.0,
			"k": zoom_pour(z.x - a.x, z.y - a.y, 10, K_MAX_CHAPITRE)}
	return c


## L'encombrement RÉEL de la scène, à l'écran : les points et leurs plaques,
## une fois celles-ci placées. C'est ce que la caméra doit contenir.
func _encombrement(ids: Array, c: Dictionary) -> Rect2:
	var plaques := _placer_plaques(ids, c)
	var r := Rect2()
	var premier := true
	for id in ids:
		var p := pos(id)
		if p == Vector2.INF:
			continue
		var m := _mesure_plaque(id)
		var e := _ecran_de(p, c)
		var rayon: float = m["r"] + 2.0 * Sty.HUD_K
		var boites: Array = [Rect2(e - Vector2.ONE * rayon, Vector2.ONE * 2.0 * rayon)]
		if plaques.has(id):
			boites.append(plaques[id])
		for boite_ in boites:
			r = boite_ if premier else r.merge(boite_)
			premier = false
	return r


## LA CARTE NE SORT PAS DE SES BORDS. On garde la fenêtre visible à
## l'intérieur du cadre : tirer la carte ne doit jamais découvrir du vide. Si
## le zoom est tel que le cadre est plus petit que la fenêtre — ce qui arrive
## quand on recule sur le continent —, il n'y a rien à borner, on centre.
func _borner_camera() -> void:
	var f := fenetre()
	var k: float = max(1e-6, float(cam["k"]))
	var demi_l: float = float(f["w"]) / (2.0 * k)
	var demi_h: float = float(f["h"]) / (2.0 * k)
	var e := emprise
	cam["x"] = e.get_center().x if demi_l * 2.0 >= e.size.x \
		else clampf(float(cam["x"]), e.position.x + demi_l, e.end.x - demi_l)
	cam["y"] = e.get_center().y if demi_h * 2.0 >= e.size.y \
		else clampf(float(cam["y"]), e.position.y + demi_h, e.end.y - demi_h)


## L'EMPRISE DE LA CARTE : le ruban, et une marge autour — pas le monde.
##
## Les bornes étaient celles du CADRE, c'est-à-dire du fond de carte entier :
## on pouvait reculer jusqu'à voir l'Asie et l'Atlantique, de grandes zones où
## aucune gare n'existe. « Il est inutile de voir des grandes zones vides (Asie
## ou océan). Limite plus la carte » (Vincent, 10 septembre 2026).
##
## On borne donc sur la BOÎTE DES GARES DU RUBAN, élargie d'un DIXIÈME de sa
## taille : assez pour que les gares du bord ne collent pas au cadre et que leur
## plaque tienne, trop peu pour ouvrir un désert. Un cinquième, essayé d'abord,
## laissait encore une bande de Méditerranée et un morceau de Russie. Mesurée une fois, à la pose de
## la carte — le ruban ne change pas en cours de route.
func _mesurer_emprise() -> void:
	var b := Rect2()
	var premier := true
	for id in ruban.ordre:
		var p := pos(id)
		if p == Vector2.INF:
			continue
		if premier:
			b = Rect2(p, Vector2.ZERO)
			premier = false
		else:
			b = b.expand(p)
	if premier:
		emprise = Rect2(0, 0, CADRE_L, CADRE_H)
		return
	var marge: float = max(b.size.x, b.size.y) * 0.10
	emprise = b.grow(marge).intersection(Rect2(0, 0, CADRE_L, CADRE_H))


## LE RECUL MAXIMAL SE DÉDUIT DE L'EMPRISE : le zoom où elle tient tout
## entière dans la fenêtre. En deçà, on reverrait le vide qu'on vient
## d'interdire.
func _k_min() -> float:
	var f := fenetre()
	var e := emprise
	if e.size.x <= 0.0 or e.size.y <= 0.0:
		return K_MIN_LIBRE
	return maxf(K_MIN_LIBRE, minf(float(f["w"]) / e.size.x, float(f["h"]) / e.size.y))


## ZOOMER AUTOUR D'UN POINT, ET NON AUTOUR DU MILIEU. C'est toute la
## différence entre un zoom qui obéit et un zoom qui fuit : ce qui est sous le
## doigt — ou sous le curseur — doit rester sous le doigt. On note donc le point
## du TERRAIN visé, on change l'échelle, et on ramène la caméra pour que ce
## point retombe exactement où il était.
func _zoomer(vers: float, foyer: Vector2) -> void:
	var k0: float = float(cam["k"])
	var k1: float = clampf(vers, _k_min(), K_MAX_LIBRE)
	if is_equal_approx(k0, k1):
		return
	var avant := monde(foyer)
	cam["k"] = k1
	var apres := monde(foyer)
	cam["x"] = float(cam["x"]) + avant.x - apres.x
	cam["y"] = float(cam["y"]) + avant.y - apres.y
	cam_libre = true
	cam_vers = {}
	_borner_camera()
	_poser_fond()
	queue_redraw()


## Rendre la main au cadrage automatique — celui qui tient le chapitre en cours
## et la gare qui vient. C'est ce que fait le bouton, et c'est aussi ce que fait
## la fin d'un service : on ne laisse pas le joueur revenir sur une carte
## décadrée par un geste d'il y a dix minutes.
func _recentrer() -> void:
	cam_libre = false
	glisse_pris = false
	aller_camera()


func aller_camera(saut: bool = false) -> void:
	if zoom_force:
		return
	cam_libre = false
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
	if seq != "":
		_avancer_remise(delta)
		if vol != null:
			vol.queue_redraw()
		queue_redraw()
	if not cam_vers.is_empty():
		cam_t = min(1.0, cam_t + delta / cam_duree)
		var e := ease(cam_t, -2.0)          # ease in-out
		# Le zoom s'interpole en log : une caméra qui recule de ×100 à ×10 le
		# fait en douceur, pas d'un coup au début.
		cam = {"x": lerp(cam_de["x"], cam_vers["x"], e), "y": lerp(cam_de["y"], cam_vers["y"], e),
			"k": exp(lerp(log(cam_de["k"]), log(cam_vers["k"]), e))}
		if cam_t >= 1.0:
			cam_vers = {}
	# LE CONVOI DE CHAPITRE ATTEND SON TOUR. Il partait 0,7 s après l'arrivée
	# sur le ruban, c'est-à-dire EN PLEIN VOL DES ÉTOILES : deux gestes en même
	# temps, et l'œil n'en suit aucun. Il est le dernier temps, comme la puce.
	if not transit.is_empty() and seq == "":
		var duree: float = DUREE_SAUT if transit["saut"] else DUREE_VOYAGE
		if transit_t < 0.0:
			transit_t += delta / DELAI_LECTURE
			if transit_t >= 0.0:
				transit_t = 0.0
		else:
			transit_t += delta / duree
			if transit_t >= 1.0:
				_arriver()
	_poser_fond()
	queue_redraw()


## Le calque des pays sous la caméra. Appelé par `_process`, mais AUSSI par
## `poser` : pendant un glissement l'écran ne tourne pas, et une carte changée
## garderait le fond de l'ancienne le temps de la transition.
func _poser_fond() -> void:
	var f := fenetre()
	var k: float = cam["k"] * f["px"]
	if k <= 0.0:
		return
	fond.transform = Transform2D(0.0, Vector2(k, k), 0.0, _centre_carte() - Vector2(cam["x"], cam["y"]) * k)
	for l in contours:
		l.width = 1.6 * Sty.HUD_K / k


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
	_grain()
	_relief()
	_graticule()
	_fil_du_ruban()
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
			# UNE VOIE, PAS UN TRAIT : deux files de rail et leurs traverses,
			# comme sur une carte ferroviaire. Le tracé parcouru est en laiton
			# vif, celui qui vient respire, celui qu'on n'a pas ouvert reste
			# gris de fonte.
			var trace := _voie_ecran(g[i - 1], g[i])
			var k := Sty.HUD_K
			if not ecrit:
				_pointille_ligne(trace, Color(Sty.LAITON, 0.28), 2.0 * k, 7.0 * k)
			elif fait:
				_voie(trace, Sty.LAITON_CLAIR, k, 1.0)
			elif avance:
				_voie(trace, Sty.LAITON_CLAIR, k, 0.65 + 0.35 * pulse)
			else:
				_voie(trace, Color("#7a6a55"), k, 0.75)
	# --- la liaison de transit, et le convoi ------------------------------------
	if not transit.is_empty():
		var a := pos(transit["de"])
		var b := pos(transit["vers"])
		if a != Vector2.INF and b != Vector2.INF:
			var col := couleur_de_zone(ch["zone"]) if not ch.is_empty() else ACCENT
			var pa := ecran(a)
			var pb := ecran(b)
			# UN SAUT N'EST PAS DU RAIL — bateau, tunnel, correspondance : il
			# garde son pointillé, qui dit précisément qu'on ne roule pas. Une
			# liaison de chapitre, elle, est une voie comme les autres, et se
			# dessine comme les autres : le tracé courbe existe désormais
			# jusque-là (voir _construire_courbes).
			var route := _voie_ecran(transit["de"], transit["vers"])
			if transit["saut"]:
				_pointille(pa, pb, Color(col, 0.6), 2.5, 12.0)
			else:
				_voie(route, col, Sty.HUD_K, 0.85)
			if transit_t >= 0.0:
				var e := ease(transit_t, -2.0)
				var p := pa.lerp(pb, e)
				if not transit["saut"] and route.size() >= 2:
					var lg := 0.0
					for i in range(route.size() - 1):
						lg += route[i].distance_to(route[i + 1])
					p = _le_long(route, lg * e)
				draw_circle(p, 7.0 * Sty.HUD_K, Color(col, 0.35))
				draw_circle(p, 4.0 * Sty.HUD_K, col)
	# --- LA PUCE DU DERNIER TEMPS ------------------------------------------------
	# Le convoi qui rejoint la ville suivante après un service gagné. Il file
	# sur la voie elle-même — la même courbe que le rail, pas une corde tendue
	# entre deux points —, et il laisse derrière lui la portion parcourue en
	# laiton vif : on voit la ligne SE FAIRE.
	if seq == "puce" and seq_t >= 0.0:
		var tr := _voie_ecran(puce_de, puce_vers)
		if tr.size() >= 2:
			var e: float = ease(clampf(seq_t / SEQ_PUCE, 0.0, 1.0), -2.0)
			var lg := 0.0
			for i in range(tr.size() - 1):
				lg += tr[i].distance_to(tr[i + 1])
			var d: float = lg * e
			var p := _le_long(tr, d)
			var kk := Sty.HUD_K
			# LA TRAÎNE : la portion déjà parcourue s'allume derrière la puce,
			# sur une longueur fixe. C'est ce qui donne le SENS de la marche —
			# une lampe seule ne dit pas d'où elle vient.
			var traine := PackedVector2Array()
			var pas := 6.0 * kk
			var n_t := 10
			for i in range(n_t, -1, -1):
				var di: float = d - float(i) * pas
				if di >= 0.0:
					traine.append(_le_long(tr, di))
			if traine.size() >= 2:
				draw_polyline(traine, Color(Sty.LAITON_CLAIR, 0.30), 7.0 * kk, true)
				draw_polyline(traine, Color(Sty.LAITON_CLAIR, 0.75), 3.0 * kk, true)
			var battement: float = 0.78 + 0.22 * sin(t * 11.0)
			for i in range(7):
				var u: float = 1.0 - float(i) / 7.0
				draw_circle(p, (5.0 + 13.0 * u * u) * kk * battement, Color(Sty.LAITON_CLAIR, 0.055))
			draw_circle(p, 5.0 * kk, Color(Sty.LAITON_CLAIR, 0.85))
			draw_circle(p, 2.6 * kk, Color(1, 1, 1, 0.95))
	_rose_des_vents()

	# --- les gares en vue, chapitre ou pas --------------------------------------
	var dessinees := gares_visibles()
	var noms: bool = dessinees.size() <= PLAQUES_MAX
	var plaques := _placer_plaques(dessinees, cam) if noms else {}
	plaques_ecran.clear()
	for id in dessinees:
		var p := pos(id)
		if p == Vector2.INF:
			continue
		var e := ecran(p)
		var m := _mesure_plaque(id)
		var ici: bool = id == prochaine
		var r: float = m["r"]
		var teinte: Color
		match String(m["etat"]):
			"avenir":
				teinte = Color(Sty.LAITON, 0.30)
			"fermee":
				teinte = Color(Sty.LAITON, 0.45)
			"payee":
				teinte = Color(Sty.PAPIER_OMBRE, 0.85)
			_:
				teinte = Sty.LAITON
		var kk := Sty.HUD_K
		# SANS SON NOM, UN POINT SE FAIT PLUS DISCRET. À l'échelle du continent
		# ils sont deux cent soixante-dix-sept, et à taille de doigt ils se
		# touchent : le semis devient une tache. Le point garde sa taille dès
		# qu'il porte un nom, c'est-à-dire dès qu'on peut le viser.
		if not noms:
			r *= 0.52
		if ici:
			# la gare qui vient : un halo d'ambre, comme une lampe posée dessus
			draw_circle(e, r + (7.0 + 4.0 * pulse) * kk, Color(Sty.LAITON, 0.16 + 0.12 * pulse))
			draw_circle(e, r + 3.0 * kk, Color(Sty.LAITON_CLAIR, 0.55 + 0.25 * pulse))
			draw_arc(e, r + 5.0 * kk, 0.0, TAU, 40, Color(Sty.LAITON_CLAIR, 0.95), 2.0 * kk, true)
		if not bilan.is_empty() and bilan.get("gare") == id:
			draw_arc(e, r + 9.0 * kk, 0.0, TAU, 48, Color(Sty.LAITON, 0.8), 1.6 * kk, true)
		# LA GARE CHOISIE PORTE SON CERNE : le panneau parle d'elle, la carte
		# doit dire laquelle — sans quoi on lit une fiche sans savoir d'où.
		if id == selection:
			draw_circle(e, r + (9.0 + 3.0 * pulse) * kk, Color(Sty.SARCELLE, 0.18))
			draw_arc(e, r + 7.0 * kk, 0.0, TAU, 48, Color(Sty.SARCELLE, 0.95), 2.2 * kk, true)
		draw_circle(e, r + 1.5 * kk, Color(Sty.BOIS, 0.85))
		draw_circle(e, r, Sty.LAITON_CLAIR if ici else teinte)
		draw_arc(e, r, 0.0, TAU, 28, Color(Sty.BOIS, 0.55), 1.2 * kk, true)
		# LE NOM SUR UNE PLAQUE, comme sur une vraie carte ferroviaire : une
		# étiquette posée à côté du point, et non un texte flottant que le
		# relief traverse. Sarcelle et laiton quand la gare est tenue, papier
		# fané quand elle attend son tour. Sa PLACE, elle, est négociée avec
		# les autres plaques (_placer_plaques) : deux gares voisines ne se
		# recouvrent plus.
		# À FAIBLE ZOOM, LE POINT SUFFIT. Cent noms qu'on ne peut pas lire ne
		# valent pas mieux que pas de nom du tout, et le placement les
		# comparerait tous deux à deux.
		if not noms:
			continue
		var reserve: Rect2 = plaques.get(id, Rect2(
			e.x + r + 6 * kk, e.y - float(m["haute"]) / 2, float(m["place"]), float(m["haute"])))
		var plaque := Rect2(reserve.position, Vector2(float(m["large"]), float(m["haute"])))
		plaques_ecran[id] = plaque
		var cy := plaque.get_center().y
		# LE FILET DE RAPPEL : quand la plaque a dû s'écarter du point pour
		# trouver sa place, un trait fin les rattache — sans quoi on ne sait
		# plus quel nom va à quelle gare.
		var attache := Vector2(clampf(e.x, plaque.position.x, plaque.end.x),
			clampf(e.y, plaque.position.y, plaque.end.y))
		if e.distance_to(attache) > r + 9.0 * kk:
			draw_line(e, attache, Color(Sty.LAITON, 0.45), max(1.0, 1.0 * kk), true)
		draw_style_box(Sty.plaque(Sty.SARCELLE if m["ouverte"] else Color(Sty.BOIS_CLAIR, 0.9),
			Color(Sty.LAITON, 0.9 if m["ouverte"] else 0.45), Sty.R_PETIT, Sty.HUD_K), plaque)
		var encre: Color = Sty.PAPIER if m["ouverte"] else MUET
		var xt: float = plaque.position.x + float(m["pad"])
		var w: float = m["w"]
		Sty.texte_centre(self, police, int(m["taille"]), Vector2(xt + w / 2, cy), String(m["nom"]), encre)
		if m["dia"]:
			# la même pierre que le vol, le sceau et la barre — on ne doit pas
			# pouvoir croire qu'il y en a deux
			var hg: float = float(m["taille"]) * 1.15
			tailler_gemme(self, Vector2(xt + w + 5 * kk + float(m["ws"]) / 2, cy - hg * 0.08), hg, 1.0)
		elif String(m["suffixe"]) != "":
			Sty.texte_centre(self, police, int(m["taille"]),
				Vector2(xt + w + 5 * kk + float(m["ws"]) / 2, cy), String(m["suffixe"]),
				Sty.LAITON_CLAIR)
		# une gare qu'on ne peut pas encore jouer porte son cadenas
		if not m["ouverte"]:
			# la place réservée au cadenas est du côté opposé au point : une
			# plaque posée à gauche porte donc son cadenas à gauche.
			var a_gauche: bool = plaque.get_center().x < e.x
			var c := Vector2(plaque.position.x - 9 * kk if a_gauche else plaque.end.x + 9 * kk, cy)
			draw_style_box(Sty.boite(Color(Sty.BOIS_CLAIR, 0.95), Color(Sty.LAITON, 0.5), 3 * kk, Sty.epaisseur(kk)),
				Rect2(c.x - 5 * kk, c.y - 4 * kk, 10 * kk, 8 * kk))
			draw_arc(Vector2(c.x, c.y - 4 * kk), 3.2 * kk, PI, TAU, 12, Color(Sty.LAITON, 0.7), 1.4 * kk, true)
	# LE BOUTON EN DERNIER, PAR-DESSUS TOUT. Il était peint avant les gares :
	# au recul continental, deux cent soixante-dix-sept points lui passaient
	# dessus.
	_bouton_recentrer()


# ------------------------------------------------------------------
# LES PLAQUES — ce que porte chaque nom, et où il tient
# ------------------------------------------------------------------
## Les gares que la carte DESSINE : le chapitre vu, plus la gare qu'on vient
## de quitter pendant un transit. Le cadrage lit la même liste — c'est ce qui
## garantit que rien de visible ne tombe hors du cadre.
func gares_dessinees() -> Array:
	var ch := chapitre_vu()
	var ids: Array = ch["gares"].duplicate() if not ch.is_empty() else []
	if not transit.is_empty() and not ids.has(transit["de"]):
		ids.push_front(transit["de"])
	return ids


## TOUTE GARE QUI TOMBE DANS LA FENÊTRE, chapitre ou pas.
##
## « Quand on se déplace, il faut voir le nom des villes et le résultat qu'on a
## fait. Pour les villes futures, juste affiche la ville comme bloquée »
## (Vincent, 10 septembre 2026). Depuis qu'on peut tirer la carte, s'en tenir au
## chapitre courant n'a plus de sens : on arrive chez les voisins et on n'y voit
## que des points sourds, sans un nom.
##
## ELLE NE SERT PAS AU CADRAGE, et c'est important : `camera_voulue` continue de
## lire `gares_dessinees`, le chapitre. Cadrer sur ce qui est visible serait
## circulaire — le cadre dépendrait de ce qu'il montre, qui dépend du cadre.
##
## ET IL Y A UN NIVEAU DE DÉTAIL. Le placement des plaques essaie huit positions
## par gare et les compare à toutes celles déjà posées : c'est quadratique, et à
## faible zoom la fenêtre peut contenir cent gares dont aucun nom ne serait
## lisible. Au-delà de PLAQUES_MAX on ne rend que les points — ce qui est de
## toute façon ce qu'on veut voir à cette échelle.
func gares_visibles() -> Array:
	var ids := gares_dessinees()
	if ruban == null:
		return ids
	var vu := surface_carte().grow(60.0 * Sty.HUD_K)
	for id in ruban.ordre:
		if ids.has(id):
			continue
		var p := pos(id)
		if p == Vector2.INF:
			continue
		if vu.has_point(ecran(p)):
			ids.append(id)
	return ids


## Ce que porte la plaque d'une gare, et la place qu'elle prend. Mesuré une
## fois et relu par le placement, le cadrage et le dessin : trois calculs de
## la même chose finissaient toujours par diverger.
func _mesure_plaque(id: String) -> Dictionary:
	var k := Sty.HUD_K
	var chg := ruban.chapitre_de_gare(id)
	var fin: bool = not chg.is_empty() and chg["gares"][chg["gares"].size() - 1] == id
	var etat := etat_de_gare(id)
	var ouverte: bool = etat == "faite" or etat == "courante" or etat == "payee"
	var nom := nom_de(id)
	var taille := int(round((15 if fin else 13) * k))
	var w: float = police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var prog := ruban.progression_de(id)
	var st: int = Rub.etoiles_de(prog)
	var dia: bool = Rec.est_diamant(prog)
	var suffixe := "◆" if dia else ("★".repeat(st) if st > 0 else "")
	# LA PIERRE SE MESURE COMME CE QU'ELLE EST : un dessin, pas un glyphe. Le
	# « ◆ » de Cormorant fait à peine le tiers d'une capitale — « Newport · »,
	# un point bleu à côté du nom (Vincent, 10 septembre 2026). La pierre prend
	# la hauteur d'une capitale et un peu plus, comme les étoiles d'à côté.
	var ws: float
	if dia:
		ws = float(taille) * 1.15 * 0.86
	else:
		ws = police.get_string_size(suffixe, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x if suffixe != "" else 0.0
	var pad := 7.0 * k
	var large: float = w + (ws + 5.0 * k if ws > 0.0 else 0.0) + 2.0 * pad
	return {"etat": etat, "ouverte": ouverte, "fin": fin, "nom": nom, "taille": taille,
		"w": w, "suffixe": suffixe, "ws": ws, "dia": dia, "pad": pad,
		"large": large, "place": large + (18.0 * k if not ouverte else 0.0),
		"haute": taille + 8.0 * k, "r": (6.0 if fin else 4.5) * k}


## LA PLACE DE CHAQUE PLAQUE, NÉGOCIÉE. Toutes les plaques se posaient à
## droite de leur point : deux gares proches se recouvraient — Darlington et
## Middlesbrough, à quinze kilomètres l'une de l'autre (Vincent, 5 septembre
## 2026). Chaque gare essaie donc huit positions autour de son point et garde
## la moins mauvaise : ce qui pénalise, c'est recouvrir une plaque déjà posée,
## couvrir un point de gare, traverser la voie, ou sortir de la carte. À
## pénalité égale, la droite gagne — c'est là qu'on lit d'abord.
const PLAQUE_JEU := 3.0

func _placer_plaques(ids: Array, c: Dictionary) -> Dictionary:
	var mis := {}
	if police == null or ids.is_empty():
		return mis
	var k := Sty.HUD_K
	var cadre := cadre_carte()
	var pts := {}
	for id in ids:
		var p := pos(id)
		if p != Vector2.INF:
			pts[id] = _ecran_de(p, c)
	# les segments de voie qu'une plaque ne doit pas couvrir : le tracé courbe,
	# décimé — cinq segments par liaison suffisent à dire où passe la voie.
	var segs: Array = []
	for i in range(1, ids.size()):
		if not (pts.has(ids[i - 1]) and pts.has(ids[i])):
			continue
		var t: PackedVector2Array = _tracer_pour(ids[i - 1], ids[i], c)
		var j := 0
		while j + 3 < t.size():
			segs.append([t[j], t[min(t.size() - 1, j + 3)]])
			j += 3
	# L'ORDRE COMPTE : la première servie choisit librement. On sert donc la
	# gare qui vient, puis les fins de chapitre, puis le reste dans l'ordre du
	# rail — les plus importantes ont la meilleure place.
	var ordre := ids.duplicate()
	ordre.sort_custom(func(a, b): return _rang_de_plaque(a) < _rang_de_plaque(b))
	# LA ROSE DES VENTS EST UN OBSTACLE, pas un fond : Middlesbrough est venu
	# se poser dessus au premier essai. Elle occupe sa place avant tout le monde.
	var poses: Array = [_cadre_rose()]
	for id in ordre:
		if not pts.has(id):
			continue
		var m := _mesure_plaque(id)
		var e: Vector2 = pts[id]
		var L: float = m["place"]
		var H: float = m["haute"]
		var d: float = float(m["r"]) + 6.0 * k
		var cands: Array = [
			Rect2(e.x + d, e.y - H / 2.0, L, H),
			Rect2(e.x - d - L, e.y - H / 2.0, L, H),
			Rect2(e.x + d * 0.4, e.y - d - H, L, H),
			Rect2(e.x + d * 0.4, e.y + d, L, H),
			Rect2(e.x - d * 0.4 - L, e.y - d - H, L, H),
			Rect2(e.x - d * 0.4 - L, e.y + d, L, H),
			Rect2(e.x - L / 2.0, e.y - d - H, L, H),
			Rect2(e.x - L / 2.0, e.y + d, L, H),
		]
		var meilleur: Rect2 = cands[0]
		var note := INF
		for i in cands.size():
			# le rang du candidat n'est plus qu'un DÉPARTAGE : à 22 points il
			# décidait tout seul, et une plaque partait à gauche pour éviter un
			# frôlement à droite qui n'aurait rien coûté.
			var q: float = float(i) * 12.0 + _note_plaque(cands[i], poses, pts, segs, cadre, id, e)
			if q < note:
				note = q
				meilleur = cands[i]
		poses.append(meilleur.grow(PLAQUE_JEU * k))
		mis[id] = meilleur
	return mis


## Le tracé d'une liaison pour une caméra QUELCONQUE — le placement des
## plaques doit pouvoir l'interroger avant que la caméra soit adoptée.
func _tracer_pour(a: String, b: String, c: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var t: Variant = courbes.get(a + "|" + b)
	if t is PackedVector2Array:
		for p in t:
			out.append(_ecran_de(p, c))
	return out


func _rang_de_plaque(id: String) -> int:
	var chg := ruban.chapitre_de_gare(id)
	var fin: bool = not chg.is_empty() and chg["gares"][chg["gares"].size() - 1] == id
	var tete := 2
	if id == prochaine:
		tete = 0
	elif fin:
		tete = 1
	return tete * 1000 + max(0, ruban.index_de(id))


## UNE PLAQUE APPARTIENT À SON POINT, ET À LUI SEUL.
##
## Pontefract s'écrivait 330 unités à GAUCHE de sa gare, juste au-dessus du
## point de Wakefield — plus près du point de Wakefield que la plaque de
## Wakefield elle-même. Les deux noms se lisaient comme une pile, et on ne
## savait plus lequel allait où : « ça se confond avec Pontefract, il y a
## pourtant beaucoup de place sur la droite » (Vincent, 9 septembre 2026).
##
## Rien ne l'interdisait : on ne payait qu'en RECOUVRANT un point. Or ce qui
## trompe, c'est la PROXIMITÉ — un nom posé à quarante unités d'une autre gare
## lui est attribué, même sans la toucher. On paie donc en s'approchant, avec
## une décroissance, et de son propre point on ne paie jamais.
func _note_plaque(r: Rect2, poses: Array, pts: Dictionary, segs: Array, cadre: Rect2,
		moi: String = "", mien: Vector2 = Vector2.INF) -> float:
	var k := Sty.HUD_K
	var aire: float = max(1.0, r.size.x * r.size.y)
	var n := 0.0
	for autre in poses:
		var i: Rect2 = r.intersection(autre)
		if i.size.x > 0.0 and i.size.y > 0.0:
			n += 900.0 * (i.size.x * i.size.y) / aire
		# DEUX PLAQUES QUI SE FRÔLENT SE LISENT DÉJÀ COMME UNE PILE : on garde
		# un cordon autour de chacune, moins cher qu'un recouvrement franc.
		var j: Rect2 = r.grow(9.0 * k).intersection(autre.grow(9.0 * k))
		if j.size.x > 0.0 and j.size.y > 0.0:
			n += 130.0 * (j.size.x * j.size.y) / aire
	var portee: float = 30.0 * k
	for id in pts:
		if id == moi:
			continue
		var d: float = _ecart_au_rect(r, pts[id])
		if d <= 2.0 * k:
			n += 400.0
		elif d < portee:
			n += 260.0 * (1.0 - d / portee)
	# et une plaque reste attachée à SA gare : plus elle s'en éloigne, moins on
	# devine à quoi elle appartient
	if mien != Vector2.INF:
		n += 0.55 * _ecart_au_rect(r, mien) / k
	for s in segs:
		if _segment_coupe(r, s[0], s[1]):
			n += 90.0
	# ce qui déborde de la carte n'est pas une place : on paie au point sorti
	n += 14.0 * (max(0.0, cadre.position.x - r.position.x) + max(0.0, r.end.x - cadre.end.x)
		+ max(0.0, cadre.position.y - r.position.y) + max(0.0, r.end.y - cadre.end.y)) / k
	return n


## La distance d'un point au rectangle — nulle s'il est dedans.
func _ecart_au_rect(r: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


func _segment_coupe(r: Rect2, a: Vector2, b: Vector2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


## UNE VOIE FERRÉE : le ballast sombre, les traverses, puis les deux files de
## rail. Les traverses sont espacées à l'ÉCRAN et non dans le monde — sinon
## elles se collent quand on dézoome et disparaissent quand on approche. Et
## tout se dessine sur une POLYLIGNE depuis que les voies se courbent : les
## deux files suivent la normale locale du tracé, pas celle d'une corde.
## `ech` : la voie du chapitre vu se dessine à 1, le fil du ruban plus fin —
## c'est du rail lui aussi, mais il ne doit pas disputer la vedette à la ligne
## qu'on est en train de parcourir.
func _voie(pts: PackedVector2Array, col: Color, k: float, force: float, ech: float = 1.0) -> void:
	if pts.size() < 2:
		return
	var demi := 2.2 * k * ech
	draw_polyline(pts, Color(Sty.BOIS, 0.55 * force), 8.0 * k * ech, true)   # le ballast
	Sty.traverses(self, pts, Color(col, 0.55 * force), demi * 1.55, 9.0 * k * ech)
	_file(pts, -demi, Color(col, force), k * ech)
	_file(pts, demi, Color(col, force), k * ech)


## Une file de rail : le tracé décalé d'un demi-écartement, chaque point
## poussé le long de la normale que lui donnent ses deux voisins.
func _file(pts: PackedVector2Array, ecart: float, col: Color, k: float) -> void:
	var out := PackedVector2Array()
	var dernier := pts.size() - 1
	for i in pts.size():
		var u: Vector2 = pts[min(dernier, i + 1)] - pts[max(0, i - 1)]
		u = u.normalized() if u.length() > 1e-6 else Vector2.RIGHT
		out.append(pts[i] + Vector2(-u.y, u.x) * ecart)
	draw_polyline(out, col, 1.7 * k, true)


## LE GRAIN DU PAPIER, en coordonnées d'écran. C'est la feuille sur laquelle
## la carte est imprimée : elle ne se déplace pas avec le terrain et ne peut
## donc jamais devenir floue, quel que soit le zoom. Très pâle — un grain qui
## se remarque n'est plus un grain, c'est une texture.
func _grain() -> void:
	if papier == null or papier.get_width() == 0:
		return
	# Modulé par le BOIS et non par du blanc : la texture est un gris, et
	# passée en blanc elle délavait la terre au lieu de la marbrer. Multipliée
	# par un brun, elle assombrit irrégulièrement — ce que fait un papier.
	draw_texture_rect(papier, surface_carte(), true, Color(Sty.BOIS.r, Sty.BOIS.g, Sty.BOIS.b, 0.22))


## LE RELIEF — un semis de hachures, à l'écran mais ancré au terrain.
##
## Semé À L'ÉCRAN : la densité reste celle d'une gravure, une hachure tous les
## quinze pixels, que l'on regarde l'Europe entière ou cinq gares. Semé dans
## le MONDE, il aurait été noir de traits de loin et vide de près — le zoom du
## ruban va de 1 à 70, aucune densité fixe ne tient sur un tel écart.
##
## ANCRÉ AU TERRAIN : la position de chaque hachure est décidée par un bruit
## lu aux coordonnées du MONDE. La carte se déplace, les collines restent où
## elles sont. Et l'inclinaison du trait suit la pente du bruit, comme une
## vraie hachure suit la ligne de plus grande pente.
##
## Recalculé seulement quand la caméra bouge : au repos, il ne coûte rien.
func _relief() -> void:
	if anneaux.is_empty():
		return
	var r := surface_carte()
	var cle := {"x": cam["x"], "y": cam["y"], "k": cam["k"], "r": r}
	if relief_pour != cle:
		relief_pour = cle
		_semer_relief(r)
	if not relief_traits.is_empty():
		draw_multiline(relief_traits, Color("#4a3a22", 0.62), max(1.0, 1.0 * Sty.HUD_K))


# Onze pixels et non quinze : à quinze, cent quarante traits sur toute la
# carte se lisaient comme des poussières et non comme un relief. Le seuil
# descend aussi — une gravure couvre ses reliefs, elle ne les pointille pas.
const RELIEF_PAS := 11.0        # un trait tous les onze pixels
const RELIEF_SEUIL := 0.10      # au-dessus de quoi le bruit fait une colline
const RELIEF_MAX := 5000        # garde-fou : jamais plus de traits que cela

func _semer_relief(r: Rect2) -> void:
	relief_traits = PackedVector2Array()
	var pas := RELIEF_PAS * Sty.HUD_K
	var e := 0.05                                  # l'écart pour lire la pente
	var y := r.position.y + pas * 0.5
	while y < r.end.y:
		var x := r.position.x + pas * 0.5
		while x < r.end.x:
			var w := monde(Vector2(x, y))
			var n := bruit.get_noise_2d(w.x, w.y)
			if n > RELIEF_SEUIL and _sur_terre(w):
				# la pente du bruit, et la hachure perpendiculaire
				var gx := bruit.get_noise_2d(w.x + e, w.y) - bruit.get_noise_2d(w.x - e, w.y)
				var gy := bruit.get_noise_2d(w.x, w.y + e) - bruit.get_noise_2d(w.x, w.y - e)
				var d := Vector2(gx, gy)
				d = d.normalized() if d.length() > 1e-6 else Vector2.RIGHT
				var l: float = pas * 0.62 * clampf((n - RELIEF_SEUIL) * 3.0, 0.40, 1.0)
				relief_traits.append(Vector2(x, y) - d * l * 0.5)
				relief_traits.append(Vector2(x, y) + d * l * 0.5)
				if relief_traits.size() >= RELIEF_MAX * 2:
					return
			x += pas
		y += pas


## Ce point du cadre est-il sur la terre ? On ne teste que les anneaux dont la
## boîte le contient — sans quoi ce serait soixante-huit tests par hachure, et
## des milliers de hachures.
func _sur_terre(w: Vector2) -> bool:
	for a in anneaux:
		if (a["bbox"] as Rect2).has_point(w) and Geometry2D.is_point_in_polygon(w, a["pts"]):
			return true
	return false


## LE GRATICULE — méridiens et parallèles, à l'encre pâle. C'est la marque de
## toute carte ancienne, et c'est surtout ce qui donne une ÉCHELLE : un brun
## uni ne dit pas si l'on voit trois vallées ou trois pays. Le pas suit le
## zoom — on prend la plus fine graduation qui laisse encore soixante-dix
## points entre deux traits, sans quoi le quadrillage devient un grillage.
const GRADUATIONS := [20.0, 10.0, 5.0, 2.0, 1.0, 0.5, 0.2, 0.1]

func _graticule() -> void:
	if proj.is_empty():
		return
	var r := surface_carte()
	var a := monde(r.position)
	var b := monde(r.end)
	var px: float = fenetre()["px"] * cam["k"]
	var pas: float = GRADUATIONS[0]
	for g in GRADUATIONS:
		if g * proj["cosm"] * proj["s"] * ETIREMENT_X * px >= 70.0:
			pas = g
	var col := Color(Sty.TERRE_OMBRE, 0.17)
	var ep: float = max(1.0, 0.9 * Sty.HUD_K)
	var traits := PackedVector2Array()
	var lo: float = ceil(_lon(a.x) / pas) * pas
	while lo <= _lon(b.x) and traits.size() < 200:
		var x := ecran(_xy(lo, 0.0)).x
		traits.append(Vector2(x, r.position.y))
		traits.append(Vector2(x, r.end.y))
		lo += pas
	var la: float = ceil(_lat(b.y) / pas) * pas
	while la <= _lat(a.y) and traits.size() < 400:
		var y := ecran(_xy(0.0, la)).y
		traits.append(Vector2(r.position.x, y))
		traits.append(Vector2(r.end.x, y))
		la += pas
	if not traits.is_empty():
		draw_multiline(traits, col, ep)


## LE FIL DU RUBAN — tout le parcours, en trait sourd, sous le chapitre en
## cours. La carte ne montrait que cinq gares au milieu d'un brun vide : « le
## fond n'est pas très engageant » (Vincent, 5 septembre 2026). Ce fil dit
## d'où l'on vient et où l'on va, et il le dit avec la seule chose que cette
## carte possède vraiment — son propre tracé. Un SAUT ne s'y dessine pas :
## rien ne relie deux bouts de rail qu'aucune voie ne relie.
func _fil_du_ruban() -> void:
	if ruban == null:
		return
	var vu := surface_carte().grow(80.0)
	var fils: Array = []
	var points := PackedVector2Array()
	var vus := chapitre_vu()
	var rang_vu: int = int(vus["rang"]) if not vus.is_empty() else -99
	var prec := ""
	var prec_e := Vector2.INF
	for ch in ruban.chapitres:
		if ch.get("saut") != null:
			prec = ""
		var voisin: bool = absi(int(ch["rang"]) - rang_vu) == 1
		for id in ch["gares"]:
			var p := pos(id)
			if p == Vector2.INF:
				continue
			var e := ecran(p)
			if prec != "" and (vu.has_point(prec_e) or vu.has_point(e)):
				fils.append(_voie_ecran(prec, id))
			if voisin and vu.has_point(e):
				points.append(e)
			prec = id
			prec_e = e
	# DU RAIL, PAS UN TRAIT. Le reste du ruban se dessinait au fil de fer —
	# une polyligne de 1,3 —, si bien que la ligne qui sort du chapitre vu ne
	# ressemblait à rien de ce qu'il y a dessus. C'est la même voie que
	# partout, en plus fine et en plus sourde : elle dit où l'on va sans
	# disputer la vedette à celle qu'on parcourt.
	# ET UN NIVEAU DE DÉTAIL, parce que le rail se paie. Une voie, ce sont deux
	# files et une traverse toutes les dix unités : au zoom du chapitre il y a
	# une dizaine de liaisons en vue et cela ne coûte rien, mais quand la
	# caméra recule sur le continent — pendant un saut, ou avec STATION_ZOOM —
	# il y en a deux cent soixante-onze, et l'écran tombait de 78 à 34 images
	# par seconde (mesuré au 1600 × 736). À cette échelle une liaison fait
	# quelques unités : les traverses n'y sont de toute façon PAS lisibles. En
	# dessous de cinquante unités, un trait dit la même chose pour rien.
	# Et les courtes repassent EN UN SEUL APPEL, comme avant : deux cent
	# soixante-onze polylignes séparées coûtaient déjà vingt images par
	# seconde à elles seules.
	var seuil: float = 50.0 * Sty.HUD_K
	var traits := PackedVector2Array()
	for trace in fils:
		if trace.size() >= 2 and trace[0].distance_to(trace[trace.size() - 1]) >= seuil:
			_voie(trace, Sty.LAITON, Sty.HUD_K, 0.40, 0.58)
		else:
			for j in range(trace.size() - 1):
				traits.append(trace[j])
				traits.append(trace[j + 1])
	if not traits.is_empty():
		draw_multiline(traits, Color(Sty.LAITON, 0.22), max(1.0, 1.3 * Sty.HUD_K))
	# les gares des chapitres d'avant et d'après : des points sourds, sans nom
	for e in points:
		draw_circle(e, 3.0 * Sty.HUD_K, Color(Sty.LAITON, 0.32))


## LE RETOUR AU CADRAGE, quand on s'est éloigné.
##
## Une carte qu'on peut tirer est une carte où l'on peut se perdre — surtout
## celle-ci, qui couvre l'Europe et dont le chapitre en cours n'occupe qu'un
## timbre-poste. Le bouton n'apparaît QUE si l'on a pris la main : tant que le
## cadrage est automatique, il n'aurait rien à faire, et un bouton qui ne sert
## à rien encombre.
##
## Il se pose en bas à droite de la carte, dans la zone sûre, du côté opposé au
## panneau — là où le pouce arrive, et là où il ne couvre ni les plaques de
## gare, ni la rose.
func _bouton_recentrer() -> void:
	zone_recentrer = Rect2()
	if not cam_libre:
		return
	var k := Sty.HUD_K
	var f := Sty.titre(600)
	var t := int(round(13.0 * k))
	var mot := "Recentrer"
	var w: float = Sty.largeur_espacee(f, t, mot, 1.0 * k)
	var r := Rect2(Vector2.ZERO, Vector2(w + 46.0 * k, 30.0 * k))
	var c := cadre_carte()
	r.position = Vector2(c.end.x - r.size.x - 14.0 * k, c.end.y - r.size.y - 14.0 * k)
	zone_recentrer = r
	draw_style_box(Sty.boite(Color(Sty.BOIS, 0.92), Color(Sty.LAITON, 0.85), Sty.R * k,
		Sty.epaisseur(k), 6.0 * k, Color(0, 0, 0, 0.35)), r)
	# LA MIRE : deux traits croisés et un cercle, le signe universel du
	# recentrage. Dessinée, pas écrite : un glyphe de police ne serait pas là
	# sur l'iPhone, on l'a déjà appris avec le drapeau.
	var m := Vector2(r.position.x + 17.0 * k, r.get_center().y)
	draw_arc(m, 6.5 * k, 0.0, TAU, 24, Color(Sty.LAITON_CLAIR, 0.9), 1.6 * k, true)
	draw_circle(m, 2.0 * k, Sty.LAITON_CLAIR)
	for u in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(m + u * 5.0 * k, m + u * 10.0 * k, Color(Sty.LAITON_CLAIR, 0.9), 1.6 * k, true)
	Sty.texte_espace(self, f, t,
		Vector2(r.position.x + 30.0 * k, r.get_center().y + f.get_ascent(t) / 2.0 - 2.0 * k),
		mot, Sty.PAPIER, 1.0 * k)


## LA ROSE DES VENTS, posée dans l'angle de la carte. Elle est à l'ÉCRAN et
## non sur le terrain : un ornement de cartouche ne dérive pas avec le zoom.
## Où la rose se pose, et la place qu'elle prend : le placement des plaques
## lit le même rectangle.
func _centre_rose() -> Vector2:
	var k := Sty.HUD_K
	return Vector2(get_viewport_rect().size.x - Sty.marges["droite"] - 34 * k, hauteur_barre() + 38 * k)


func _cadre_rose() -> Rect2:
	var d := 24.0 * Sty.HUD_K
	return Rect2(_centre_rose() - Vector2.ONE * d, Vector2.ONE * 2.0 * d)


func _rose_des_vents() -> void:
	var k := Sty.HUD_K
	var c := _centre_rose()
	var R := 15.0 * k
	# Plus petite et plus franche : à 22 unités et 38 % d'opacité elle occupait
	# un coin entier sans se lire. Un ornement se remarque ou disparaît.
	var col := Color(Sty.LAITON, 0.55)
	draw_arc(c, R, 0, TAU, 40, col, 1.2 * k, true)
	draw_arc(c, R * 0.72, 0, TAU, 36, Color(Sty.LAITON, 0.32), 1.0 * k, true)
	# les quatre branches principales, en losanges effilés
	for i in range(4):
		var a: float = -PI / 2 + PI / 2 * float(i)
		var u := Vector2(cos(a), sin(a))
		var n := Vector2(-u.y, u.x)
		draw_colored_polygon(PackedVector2Array([
			c + u * R, c + n * R * 0.16, c, c - n * R * 0.16]), Color(Sty.LAITON, 0.75))
	# et les quatre secondaires, plus courtes
	for i in range(4):
		var a: float = -PI / 4 + PI / 2 * float(i)
		draw_line(c, c + Vector2(cos(a), sin(a)) * R * 0.62, Color(Sty.LAITON, 0.45), 1.0 * k, true)
	Sty.texte_centre(self, police, int(round(9 * k)), c + Vector2(0, -R - 7 * k), "N", Color(Sty.LAITON, 0.75))


## Le pointillé le long d'un tracé quelconque : on marche en LONGUEUR D'ARC,
## un tiret sur deux. Compter segment par segment relancerait un tiret à
## chaque coude, et une voie courbe n'a plus que des coudes.
func _pointille_ligne(pts: PackedVector2Array, col: Color, larg: float, pas: float) -> void:
	if pts.size() < 2 or pas <= 0.0:
		return
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	var s := 0.0
	var plein := true
	while s < total:
		var e: float = min(total, s + pas)
		if plein:
			draw_line(_le_long(pts, s), _le_long(pts, e), col, larg, true)
		plein = not plein
		s = e


## Le point situé à telle distance du départ, le long du tracé.
func _le_long(pts: PackedVector2Array, d: float) -> Vector2:
	var reste := d
	for i in range(pts.size() - 1):
		var l := pts[i].distance_to(pts[i + 1])
		if reste <= l or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf(reste / max(l, 1e-6), 0.0, 1.0))
		reste -= l
	return pts[pts.size() - 1]


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
	selection = ""
	if b.get("win", false):
		_preparer_suite(String(b["gare"]))
	chapitre = _chapitre_de_reference()
	rebatir()
	aller_camera(voyage_saut)
	if b.get("win", false):
		_ouvrir_remise(String(b["gare"]))


## LES TROIS TEMPS S'OUVRENT ICI. Les étoiles et le diamant sont MASQUÉS sur
## la feuille tant qu'ils n'y sont pas arrivés : sans cela la récompense serait
## déjà en place avant que le vol ne la dépose, et le geste ne voudrait plus
## rien dire.
func _ouvrir_remise(gare: String) -> void:
	seq_n = int(bilan.get("stars", 0))
	seq_joues = 0
	puce_de = gare
	puce_vers = prochaine
	if seq_n <= 0:
		# gagné sans étoile n'existe pas, mais on ne laisse pas la porte ouverte
		_temps_de_la_puce()
		return
	seq = "etoiles"
	seq_t = -SEQ_DELAI
	# LA PLACE D'ARRIVÉE EST DÉJÀ LÀ, VIDE. Le relevé était masqué en entier
	# jusqu'à l'atterrissage : les étoiles volaient vers un endroit où il n'y
	# avait rien. « La zone où atterrissent les étoiles doit déjà avoir des
	# étoiles vides » (Vincent, 10 septembre 2026). On montre donc trois
	# étoiles creuses dès l'ouverture, et chacune se remplit à l'instant où la
	# sienne arrive.
	if lbl_etoiles != null and is_instance_valid(lbl_etoiles):
		lbl_etoiles.text = "☆☆☆"
		lbl_etoiles.modulate.a = 1.0
	if bloc_diamant != null and is_instance_valid(bloc_diamant) and bilan.get("perfect", false):
		bloc_diamant.modulate.a = 0.0


func _temps_du_diamant() -> void:
	_poser_label(lbl_etoiles)
	if not bilan.get("perfect", false) or bloc_diamant == null:
		_temps_de_la_puce()
		return
	seq = "diamant"
	seq_t = -SEQ_ENTRE


## LE DERNIER TEMPS N'EST PAS TOUJOURS À NOUS. Quand la gare finit un chapitre,
## un convoi traverse DÉJÀ vers le chapitre suivant (`transit`) : c'est le même
## geste, en plus long, et il porte la fête. On ne le double pas.
func _temps_de_la_puce() -> void:
	_poser_label(lbl_etoiles)
	_poser_label(bloc_diamant)
	if not transit.is_empty() or puce_vers == "" or puce_de == puce_vers \
			or pos(puce_de) == Vector2.INF or pos(puce_vers) == Vector2.INF:
		seq = ""
		return
	seq = "puce"
	seq_t = -SEQ_ENTRE
	Sons.jouer("puce")


func _finir_remise() -> void:
	seq = ""
	_poser_label(lbl_etoiles)
	_poser_label(bloc_diamant)


func _poser_label(l: Control) -> void:
	if l != null and is_instance_valid(l):
		l.modulate.a = 1.0
		if l == lbl_etoiles and not bilan.is_empty():
			var st := int(bilan.get("stars", 0))
			lbl_etoiles.text = "★".repeat(st) + "☆".repeat(3 - st)


## L'avancée des trois temps, appelée par `_process`.
func _avancer_remise(delta: float) -> void:
	if seq == "":
		return
	seq_t += delta
	match seq:
		"etoiles":
			# chaque étoile a son propre départ, décalé de SEQ_ECART
			while seq_joues < seq_n and seq_t >= float(seq_joues) * SEQ_ECART:
				Sons.jouer("etoile%d" % mini(seq_joues, 2))
				seq_joues += 1
			# une étoile se remplit quand la sienne se POSE, pas quand elle part
			if lbl_etoiles != null and is_instance_valid(lbl_etoiles):
				var posees := 0
				for i in range(seq_n):
					if seq_t >= float(i) * SEQ_ECART + SEQ_POSE + SEQ_TENUE + SEQ_VOL * 0.9:
						posees += 1
				lbl_etoiles.text = "★".repeat(posees) + "☆".repeat(3 - posees)
			if seq_t >= float(seq_n - 1) * SEQ_ECART + SEQ_POSE + SEQ_TENUE + SEQ_VOL:
				_temps_du_diamant()
		"diamant":
			if seq_t >= 0.0 and seq_joues == seq_n:
				Sons.jouer("diamant")
				seq_joues += 1
			if seq_t >= SEQ_POSE + SEQ_TENUE_GEMME + SEQ_VOL:
				_temps_de_la_puce()
		"puce":
			if seq_t >= SEQ_PUCE:
				Sons.jouer("arrivee")
				seq = ""


func apres_passage(id: String) -> void:
	bilan = {}
	medailles = []
	fete = {}
	selection = ""
	seq = ""
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
	selection = ""
	seq = ""
	if app != null:
		app.jouer(id)


## Reposer la gare choisie : le panneau redit ce qu'il disait avant.
func _selectionner(id: String) -> void:
	if selection == id:
		return
	selection = id
	Sons.jouer("puce")
	rebatir()


func _deselectionner() -> void:
	if selection == "":
		return
	selection = ""
	rebatir()


func _unhandled_input(event: InputEvent) -> void:
	if ruban == null or not visible:
		return
	if app != null and (app.en_glissement() or app.en_attente()):
		return
	# --- LE ZOOM ------------------------------------------------------------
	# « Le zoom peut être sympa quand même, et quand on clique sur recentrer le
	# zoom se réinitialise aussi » (Vincent, 10 septembre 2026) — ce dernier
	# point est déjà vrai : le bouton rend la main au cadrage automatique, qui
	# porte son échelle avec lui.
	#
	# DEUX GESTES POUR LA MÊME CHOSE. La molette au bureau, le pincement au
	# doigt. Le pincement demande de suivre les DEUX doigts : Godot envoie un
	# événement d'écran par doigt, et — l'émulation de la souris étant active —
	# le premier envoie AUSSI des événements de souris. On coupe donc le
	# déplacement dès qu'un second doigt se pose, sans quoi la carte serait
	# tirée pendant qu'on la pince.
	if event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if event.position.x < panneau_l() + Sty.marges["gauche"]:
			return
		var sens: float = CRAN_ZOOM if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / CRAN_ZOOM
		_zoomer(float(cam["k"]) * sens, event.position)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			doigts[event.index] = event.position
		else:
			doigts.erase(event.index)
		if doigts.size() == 2:
			var p := doigts.values()
			pince_ecart = max(1.0, (p[0] as Vector2).distance_to(p[1]))
			pince_k = float(cam["k"])
			glisse_pris = false
		return
	if event is InputEventScreenDrag:
		doigts[event.index] = event.position
		if doigts.size() == 2:
			var p := doigts.values()
			var e: float = max(1.0, (p[0] as Vector2).distance_to(p[1]))
			_zoomer(pince_k * e / pince_ecart, ((p[0] as Vector2) + (p[1] as Vector2)) / 2.0)
			return
		return

	# --- LA CARTE SE DÉPLACE AU DOIGT, dans ses limites -----------------------
	# Un doigt posé sur la carte peut faire deux choses, et on ne sait laquelle
	# qu'au relâcher : DÉSIGNER une gare, ou TIRER la carte. On garde donc le
	# geste en suspens et on mesure sa course — au-delà d'un demi-centimètre ce
	# n'est plus un clic, c'est un déplacement. C'est la règle de toutes les
	# cartes tactiles, et elle évite d'avoir à choisir entre les deux.
	if event is InputEventMouseMotion and glisse_pris:
		var d: Vector2 = event.position - glisse_depuis
		glisse_course = max(glisse_course, d.length())
		if glisse_course > COURSE_CLIC:
			cam_libre = true
			cam_vers = {}
			var f := fenetre()
			var u: float = max(1e-6, float(cam["k"]) * float(f["px"]))
			cam["x"] = glisse_cam.x - d.x / u
			cam["y"] = glisse_cam.y - d.y / u
			_borner_camera()
			_poser_fond()
			queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var pris := glisse_pris
		var course := glisse_course
		glisse_pris = false
		if pris and course <= COURSE_CLIC:
			_toucher_carte(event.position)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = event.position
		if m.x < panneau_l() + Sty.marges["gauche"]:
			return
		# UN DOIGT PENDANT LA REMISE L'ABRÈGE. Une animation qu'on ne peut pas
		# couper devient une attente dès la deuxième fois qu'on la voit.
		if seq != "":
			_finir_remise()
			return
		# LE BOUTON DE RECENTRAGE PASSE AVANT TOUT : il est posé sur la carte,
		# et il ne doit pas se confondre avec une gare qui serait dessous.
		if cam_libre and zone_recentrer.has_point(m):
			_recentrer()
			return
		glisse_pris = true
		glisse_depuis = m
		glisse_cam = Vector2(cam["x"], cam["y"])
		glisse_course = 0.0
		return


## Ce qu'un doigt DÉSIGNE sur la carte, une fois qu'on sait qu'il n'a pas tiré.
func _toucher_carte(m: Vector2) -> void:
	# LA CIBLE, C'EST LE POINT **ET** SA PLAQUE. Le rayon valait 16 unités
	# en dur : sur l'iPhone de Vincent, où le viewport est étiré, cela fait
	# huit points — moins d'un tiers de la pulpe d'un doigt. On vise donc
	# aussi le nom, qui est la partie qu'on regarde.
	# LE DOIGT VISE CE QUI EST DESSINÉ, et depuis qu'on peut tirer la carte cela
	# comprend les voisins : on doit pouvoir toucher la gare qu'on est allé
	# chercher.
	var r_doigt: float = 22.0 * Sty.HUD_K
	for id in gares_visibles():
		var p := pos(id)
		if p == Vector2.INF:
			continue
		var etat := etat_de_gare(id)
		# une gare non déverrouillée : il ne se passe rien
		if etat != "faite" and etat != "courante" and etat != "payee":
			continue
		var pl: Rect2 = plaques_ecran.get(id, Rect2())
		if ecran(p).distance_to(m) > r_doigt and not (pl != Rect2() and pl.grow(4.0 * Sty.HUD_K).has_point(m)):
			continue
		# LA GARE QUI VIENT SE LANCE D'UN DOIGT : elle est déjà décrite sur
		# la feuille, il n'y a rien de plus à lire. Les autres se posent
		# d'abord dans le panneau — on ne rejoue pas une gare par mégarde.
		if id == prochaine and selection == "":
			jouer(id)
		else:
			_selectionner(id)
		return
	# à côté de toute gare : on repose ce qu'on avait pris
	_deselectionner()


# ------------------------------------------------------------------
# Le panneau de gauche — tout ce qui se lit, d'un seul côté
# ------------------------------------------------------------------
## LA BARRE DU HAUT PREND TOUTE LA LARGEUR (demandé le 3 septembre 2026).
## Les compteurs — grade, jauge, crédits, diamants, étoiles — sont un fait de
## COMPTE, pas de carte : ils ne dépendent ni du chapitre ni de la gare, et
## n'avaient rien à faire dans la colonne du ruban, où ils volaient la hauteur
## qui manquait au reste. Sortis là-haut, la colonne respire et la barre de
## défilement disparaît.
## LA HAUTEUR DE LA BARRE SE MESURE, ELLE NE SE DEVINE PAS. Elle valait
## 34 × k + la zone sûre, c'est-à-dire une formule ; la barre, elle, est un
## PanelContainer qui prend la hauteur de son CONTENU — et le bloc du grade,
## sur deux lignes, la poussait quelques unités plus bas que la formule. Deux
## défauts en découlaient, vus tous les deux le 5 septembre 2026 :
##
##   « la topbar n'est pas à la même hauteur à gauche qu'à droite » — le
##   panneau, dessiné APRÈS la barre, recouvrait ces quelques unités : à
##   gauche la barre semblait finir plus haut qu'à droite ;
##
##   « mets la même bordure jaune en bas de la topbar à gauche » — il n'y en
##   avait pas, parce que c'est précisément le bord inférieur que le panneau
##   recouvrait.
##
## Une seule correction pour les deux : on demande sa taille à la barre.
func hauteur_barre() -> float:
	if barre != null:
		var h: float = barre.get_combined_minimum_size().y
		if h > 0.0:
			return h
	return 34.0 * Sty.HUD_K + Sty.marges["haut"]


func _construire_panneau() -> void:
	var k := Sty.HUD_K
	barre = PanelContainer.new()
	barre.position = Vector2.ZERO
	var sb := StyleBoxFlat.new()
	sb.bg_color = Sty.BOIS_CLAIR
	sb.border_color = Color(Sty.LAITON, 0.55)
	sb.border_width_bottom = int(Sty.epaisseur(k, true))
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
	style.border_width_right = int(Sty.epaisseur(k, true))
	style.content_margin_left = 22 * k + Sty.marges["gauche"]
	style.content_margin_right = 22 * k
	# LA FEUILLE MANQUAIT D'UNE LIGNE, ET C'ÉTAIT DE LA MARGE. « Je ne vois pas
	# la ligne avec mon record » (Vincent, 9 septembre 2026) : sur une fiche
	# dont la phrase tient sur deux lignes — Rotherham Central —, « ★★★ record
	# 1 min » tombait sous le bord du défilement, et rien ne disait qu'il y
	# avait quelque chose de plus bas. Or le panneau se payait 16 × k en haut
	# ET en bas, EN PLUS de la zone sûre de l'appareil, qui est déjà la
	# respiration du bord. Sept et huit suffisent : quarante unités rendues à
	# ce qui se lit, et la ligne rentre.
	style.content_margin_top = 7 * k
	style.content_margin_bottom = 8 * k + Sty.marges["bas"]
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
	pile.add_theme_constant_override("separation", int(round(8 * k)))
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
	l.add_theme_constant_override("line_spacing", int(round(2 * Sty.HUD_K)))
	if replie:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _bouton(texte: String, principal: bool, actif: bool, sur: Callable) -> Button:
	var b := Sty.bouton_plaque(texte, principal, 16 if principal else 14, Sty.HUD_K)
	b.disabled = not actif
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# LA GARANTIE, DERRIÈRE LA MESURE. Un Control ne descend jamais sous la
	# taille minimale de son contenu : un bouton trop long ne débordait pas, il
	# ÉLARGISSAIT LE PANNEAU — la carte reculait, et deux boutons cessaient
	# d'avoir la même largeur. Avec `clip_text` leur largeur minimale tombe à
	# rien : ils font exactement la moitié de la rangée, quoi qu'on y écrive.
	# `_appel` fait le reste, pour qu'aucun nom n'ait jamais à être coupé.
	b.clip_text = true
	if sur.is_valid():
		b.pressed.connect(sur)
	return b


## UN PLI DE PAPIER, pas un trait d'interface : depuis que tout se lit sur la
## feuille, le séparateur du thème par défaut y traçait une ligne grise.
func _separateur() -> Control:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator",
		Sty.boite(Sty.PAPIER_OMBRE, Color.TRANSPARENT, 0, 0))
	s.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
	return s


func _vider(noeud: Node) -> void:
	for c in noeud.get_children():
		noeud.remove_child(c)
		c.queue_free()


## Tout le panneau, d'un bloc — comme renderCarte dans le prototype.
func rebatir() -> void:
	_vider(colonne)
	lbl_etoiles = null
	lbl_diamant = null
	bloc_diamant = null
	if ruban == null:
		return
	_remplir_barre()
	# la barre change de hauteur quand un compteur apparaît : le cadre suit
	_poser_cadre()
	colonne.add_child(_feuille())
	_vider(pied)
	pied.add_child(_pied())


## LA FEUILLE — UN SEUL OBJET, SANS BORDURE.
##
## La bannière du chapitre et la carte de la gare étaient deux cadres empilés,
## chacun avec son liseré de laiton : « les deux cadres d'une gare à gauche
## pourraient être regroupés et ne pas avoir de bordure » (Vincent, 5 septembre
## 2026). Ils ne disaient pourtant qu'une chose — où l'on est, et ce qui vient.
## Un seul parchemin les porte, l'illustration en tête, et l'ombre chaude
## suffit à le décoller du bureau : un liseré ne sert qu'à séparer deux choses,
## et il n'y en a plus qu'une.
##
## LE RELEVÉ Y ENTRE AUSSI. Il flottait entre les deux cadres, sur le bois ;
## il n'y avait plus d'entre-deux. Il s'écrit donc à l'encre sur la feuille,
## à la place de la fiche complète — les deux ne tiennent pas sur un téléphone
## et ne se lisent pas au même moment.
func _feuille() -> Control:
	var k := Sty.HUD_K
	var feuille := PanelContainer.new()
	var st := Sty.parchemin(Sty.R_GRAND, k)
	st.set_border_width_all(0)
	st.set_content_margin_all(0)
	feuille.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	feuille.add_child(v)
	# L'ILLUSTRATION VA JUSQU'AUX BORDS. Elle restait dans la marge parce
	# qu'un Control ne se découpe qu'au rectangle et qu'une image poussée au
	# bord montrait ses angles carrés dans les coins arrondis de la feuille.
	# Le bandeau se dessine donc lui-même, en polygone (voir Bandeau).
	var b := _banniere()
	if b != null:
		v.add_child(b)
	var corps := MarginContainer.new()
	corps.add_theme_constant_override("margin_left", int(round(12 * k)))
	corps.add_theme_constant_override("margin_right", int(round(12 * k)))
	corps.add_theme_constant_override("margin_top", int(round(10 * k)))
	corps.add_theme_constant_override("margin_bottom", int(round(12 * k)))
	v.add_child(corps)
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", int(round(8 * k)))
	corps.add_child(v2)
	v = v2
	if b == null:
		v.add_child(_entete_chapitre())
	# UNE GARE CHOISIE SUR LA CARTE PARLE SEULE. « Les autres villes seront
	# aussi cliquables sur la carte si le joueur souhaite recommencer cette
	# gare. Dans ce cas, les infos s'affichent et le joueur clique ensuite sur
	# le bouton Jouer » (Vincent, 9 septembre 2026). Le relevé du service
	# précédent n'a plus rien à dire là : on regarde ailleurs.
	if selection != "":
		v.add_child(_cartouche(selection))
		return feuille
	# LE RELEVÉ RESTE PENDANT LA FÊTE : au seul moment du jeu où deux
	# récompenses tombent ensemble, on ne perd pas de vue les étoiles qu'on
	# vient de décrocher. Les médailles, elles, vont à la fête.
	if not bilan.is_empty():
		v.add_child(_bloc_bilan(fete.is_empty()))
	if not fete.is_empty():
		v.add_child(_bloc_fete())
	if prochaine != "" and fete.is_empty():
		v.add_child(_cartouche(prochaine) if bilan.is_empty() else _ligne_suivante(prochaine))
	return feuille


## LA BARRE DU HAUT, EN TROIS FENTES : le geste à gauche, les compteurs au
## milieu, le grade à droite. Ce sont des faits de COMPTE — ils ne bougent pas
## quand on change de chapitre.
##
## DEUX RESSORTS NE CENTRENT PAS. Un ressort partage l'espace LIBRE, pas
## l'espace total : le bloc du grade étant trois fois plus large que le bouton
## des cartes, les compteurs tombaient nettement à gauche du milieu de
## l'écran. On force donc les deux fentes de bord à la même largeur — celle de
## la plus large — et le milieu est vraiment au milieu.
func _remplir_barre() -> void:
	_vider(rangee_barre)
	var k := Sty.HUD_K
	var gauche := HBoxContainer.new()
	gauche.alignment = BoxContainer.ALIGNMENT_BEGIN
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee_barre.add_child(gauche)
	var milieu := HBoxContainer.new()
	milieu.add_theme_constant_override("separation", int(round(10 * k)))
	milieu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	milieu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee_barre.add_child(milieu)
	var droite := HBoxContainer.new()
	droite.alignment = BoxContainer.ALIGNMENT_END
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee_barre.add_child(droite)
	var n: int = Rec.etoiles_total(Sauvegarde.progression_toutes_cartes())
	var g: Dictionary = Rec.grade_de(n)
	var serie: Dictionary = Sauvegarde.get_serie()
	var e: Dictionary = Rec.etat_recompenses(ruban, serie)

	# À GAUCHE, LE GESTE. « Les cartes » n'est pas un compteur : c'est le seul
	# objet cliquable de la barre, et il se tient du côté où le pouce arrive.
	if app != null and app.plusieurs_cartes():
		# SANS CADRE, ET AVEC SA FLÈCHE. Ce n'est pas une commande de plus dans
		# la barre : c'est un RETOUR, et un retour se lit comme un lien — un
		# chevron, un mot, rien autour. Le cadre le faisait peser autant que le
		# grade, qui n'est qu'un compteur. Le chevron pointe à gauche parce que
		# les cartes sont à gauche : l'écran glisse vers la droite pour les
		# découvrir, et revient depuis la droite quand on en choisit une.
		var b := Sty.lien("Les cartes", k)
		b.pressed.connect(app.ouvrir_cartes)
		gauche.add_child(b)

	# AU MILIEU, CE QU'ON A GAGNÉ. Les trois compteurs se lisent ensemble et
	# se ressemblent : ils forment un bloc.
	if int(serie["n"]) >= 2:
		milieu.add_child(_pastille("» %d" % int(serie["n"]), ACCENT))
	if app != null:
		milieu.add_child(_pastille("%d cr" % app.solde(), Sty.LAITON))
	if int(e["diamants"]) > 0:
		milieu.add_child(_pastille_gemme(int(e["diamants"])))
	milieu.add_child(_pastille("★ %d" % n, OR))

	# À DROITE, LE GRADE. C'est le plus lent des trois — il ne change que
	# toutes les vingt-cinq étoiles — donc celui qu'on consulte, pas celui
	# qu'on surveille : il tient le bord, avec sa jauge sous le nom.
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", int(round(3 * k)))
	bloc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nom := _label(String(g["nom"]), 13, TEXTE, true, false)
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bloc.add_child(nom)
	var jauge := ProgressBar.new()
	jauge.show_percentage = false
	jauge.custom_minimum_size = Vector2(110 * k, 3 * k)
	jauge.size_flags_horizontal = Control.SIZE_SHRINK_END
	jauge.value = 100.0 * float(g["part"])
	jauge.add_theme_stylebox_override("background", Sty.boite(Color(Sty.LAITON, 0.18), Color.TRANSPARENT, 2 * k, 0))
	jauge.add_theme_stylebox_override("fill", Sty.boite(Sty.LAITON, Color.TRANSPARENT, 2 * k, 0))
	bloc.add_child(jauge)
	droite.add_child(bloc)

	# les deux bords à la même largeur : c'est cela, et cela seul, qui met le
	# milieu au milieu. On ne le fait que si les trois blocs y tiennent —
	# mieux vaut un centrage approximatif qu'un compteur coupé.
	var bord: float = max(gauche.get_combined_minimum_size().x, droite.get_combined_minimum_size().x)
	var dispo: float = get_viewport_rect().size.x - Sty.marges["gauche"] - Sty.marges["droite"] - 36.0 * k
	if 2.0 * bord + milieu.get_combined_minimum_size().x + 28.0 * k <= dispo:
		gauche.custom_minimum_size.x = bord
		droite.custom_minimum_size.x = bord


## Une pastille de compteur : le verre dépoli du bandeau de jeu, en plus petit.
func _pastille(texte: String, couleur: Color) -> Control:
	var k := Sty.HUD_K
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := Sty.boite(Color(couleur, 0.10), Color(couleur, 0.35), Sty.R_PETIT * k, Sty.epaisseur(k))
	st.content_margin_left = 9 * k
	st.content_margin_right = 9 * k
	st.content_margin_top = 3 * k
	st.content_margin_bottom = 3 * k
	p.add_theme_stylebox_override("panel", st)
	p.add_child(_label(texte, 13, couleur, true, false))
	return p


## LE COMPTEUR DE DIAMANTS, AVEC SA PIERRE. « Idem dans la top bar » : le
## « ◆ » y était un glyphe de corps 13, à peine un point à côté du nombre.
## Même pastille que ses voisines, mais la pierre dessinée à la place du glyphe.
func _pastille_gemme(n: int) -> Control:
	var k := Sty.HUD_K
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := Sty.boite(Color(DIAMANT, 0.10), Color(DIAMANT, 0.35), Sty.R_PETIT * k, Sty.epaisseur(k))
	st.content_margin_left = 8 * k
	st.content_margin_right = 9 * k
	st.content_margin_top = 3 * k
	st.content_margin_bottom = 3 * k
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(5 * k)))
	# TREIZE ET NON DIX-SEPT : « un peu trop grand dans la top bar » (Vincent,
	# 10 septembre 2026). À dix-sept la pierre dépassait la hauteur des
	# chiffres de ses voisines ; à treize elle s'aligne sur « 154 cr » et « 94 ».
	var pierre := Gemme.new(self, 13.0 * k)
	pierre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pierre)
	var l := _label(str(n), 13, DIAMANT, true, false)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	p.add_child(h)
	return p


## LA BANNIÈRE PORTE LE TITRE, comme sur la maquette. Empilés, l'image et
## l'en-tête prenaient cent unités de haut et poussaient la fiche de gare hors
## du panneau ; superposés, ils en prennent quatre-vingts et se lisent mieux —
## le nom du chapitre est posé sur son paysage, ce qui est exactement ce qu'il
## désigne. Le voile dégradé vers le bas lui garantit son contraste, quel que
## soit le ciel de l'illustration.
##
## Une bannière par ZONE et non par chapitre : quarante-neuf illustrations
## seraient une œuvre, quatre suffisent à dire où l'on est.
# ------------------------------------------------------------------
# LA REMISE DES RÉCOMPENSES — trois temps, par-dessus tout
# ------------------------------------------------------------------
## Le service gagné, l'écran du ruban s'ouvrait sur son relevé DÉJÀ ÉCRIT :
## trois étoiles apparaissaient dans un coin du panneau, et rien ne disait
## qu'on venait de les gagner. « Il faut animer tout cela » (Vincent, 9
## septembre 2026).
##
## Trois temps, dans cet ordre : les étoiles arrivent en grand au milieu de
## l'écran puis rejoignent leur place sur la feuille ; s'il y a un diamant, il
## fait le même chemin ensuite ; enfin la puce du convoi traverse la liaison
## vers la ville suivante. Un son court accompagne chacun.
##
## LA PLACE D'ARRIVÉE N'EST PAS CALCULÉE, ELLE EST LUE. Le vol vise le Label
## qui porte les étoiles dans le relevé (`lbl_etoiles`) : la feuille peut
## changer de hauteur, de police ou de contenu, le vol tombe toujours juste,
## et c'est ce Label qu'on masque jusqu'à l'atterrissage — sans quoi la
## récompense serait déjà en place avant d'y arriver.
## LA TAILLE DE LA PIERRE, de profil : table, couronne, culasse. C'est la
## silhouette que tout le monde lit comme un diamant, et elle tient à toutes
## les échelles — de la gerbe du milieu de l'écran au losange du relevé.
## Chaque pan a sa nuance : sans elles, la pierre redevient un losange plat.
static func tailler_gemme(canvas: CanvasItem, c: Vector2, h: float, alpha: float) -> void:
	var w: float = h * 0.86
	var y_table: float = c.y - h * 0.42
	var y_gird: float = c.y - h * 0.16
	var y_pointe: float = c.y + h * 0.58
	var xt: float = w * 0.27       # demi-largeur de la table
	var xg: float = w * 0.50       # demi-largeur du rondiste
	var clair := Color(1, 1, 1, 0.90).blend(Color(DIAMANT, 0.0))
	var pans := [
		# la table, le pan le plus clair : c'est lui qui rend la lumière
		[[Vector2(-xt, y_table - c.y), Vector2(xt, y_table - c.y),
			Vector2(xt * 0.72, y_gird - c.y), Vector2(-xt * 0.72, y_gird - c.y)], 1.00],
		# les deux pans de couronne
		[[Vector2(-xt, y_table - c.y), Vector2(-xt * 0.72, y_gird - c.y),
			Vector2(-xg, y_gird - c.y)], 0.62],
		[[Vector2(xt, y_table - c.y), Vector2(xt * 0.72, y_gird - c.y),
			Vector2(xg, y_gird - c.y)], 0.80],
		# la culasse, en deux versants
		[[Vector2(-xg, y_gird - c.y), Vector2(-xt * 0.72, y_gird - c.y),
			Vector2(0, y_pointe - c.y)], 0.46],
		[[Vector2(-xt * 0.72, y_gird - c.y), Vector2(xt * 0.72, y_gird - c.y),
			Vector2(0, y_pointe - c.y)], 0.70],
		[[Vector2(xt * 0.72, y_gird - c.y), Vector2(xg, y_gird - c.y),
			Vector2(0, y_pointe - c.y)], 0.55],
	]
	for pan in pans:
		var pts := PackedVector2Array()
		for v in pan[0]:
			pts.append(c + v)
		# « UN PEU MOINS TRANSPARENT » : les pans descendaient à 55 % d'opacité,
		# et le parchemin passait à travers la pierre. Ils ne descendent plus
		# sous 85 % — la nuance entre facettes vient de la couleur, plus du
		# fond qui transparaît.
		canvas.draw_colored_polygon(pts, Color(DIAMANT.lerp(clair, float(pan[1]) * 0.55),
			(0.85 + 0.15 * float(pan[1])) * alpha))
	# le contour, et l'arête du rondiste : deux traits, et la pierre tient
	var bord := PackedVector2Array([
		c + Vector2(-xt, y_table - c.y), c + Vector2(xt, y_table - c.y),
		c + Vector2(xg, y_gird - c.y), c + Vector2(0, y_pointe - c.y),
		c + Vector2(-xg, y_gird - c.y)])
	bord.append(bord[0])
	canvas.draw_polyline(bord, Color(Sty.ACCENT_CLAIR, 0.95 * alpha), maxf(1.0, h * 0.030), true)
	canvas.draw_line(c + Vector2(-xg, y_gird - c.y), c + Vector2(xg, y_gird - c.y),
		Color(Sty.ACCENT_CLAIR, 0.75 * alpha), maxf(1.0, h * 0.022), true)
	# l'éclat : un court trait blanc sur le pan de gauche de la couronne
	canvas.draw_line(c + Vector2(-xt * 0.86, y_table - c.y + h * 0.045),
		c + Vector2(-xg * 0.80, y_gird - c.y - h * 0.02),
		Color(1, 1, 1, 0.85 * alpha), maxf(1.0, h * 0.035), true)


## LA PIERRE, EN PETIT, DANS UNE MISE EN PAGE. Le vol la dessine au milieu de
## l'écran ; le relevé et la barre du haut la portent dans des conteneurs, où
## seul un Control prend sa place. Même recette de taille, même facettes :
## c'est la MÊME pierre, et on ne doit pas pouvoir croire qu'il y en a deux.
class Gemme extends Control:
	var vue: Node2D
	var hauteur := 16.0

	func _init(v: Node2D, h: float) -> void:
		vue = v
		hauteur = h
		custom_minimum_size = Vector2(h * 0.9, h * 1.05)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if vue != null:
			vue.tailler_gemme(self, size / 2.0 + Vector2(0, -hauteur * 0.06), hauteur, 1.0)


class Vol extends Node2D:
	var vue: Node2D

	func _draw() -> void:
		if vue == null or vue.seq == "":
			return
		var k: float = Sty.HUD_K
		var centre: Vector2 = to_local(vue.get_viewport_rect().size / 2.0)
		match vue.seq:
			"etoiles":
				var n: int = vue.seq_n
				# les étoiles s'alignent au milieu, comme sur la feuille
				var pas := 62.0 * k
				for i in range(n):
					var depart := centre + Vector2((float(i) - (n - 1) / 2.0) * pas, -20.0 * k)
					# CHAQUE ÉTOILE VISE SA FENTE. Le relevé écrit toujours trois
					# glyphes — les gagnées pleines, les autres creuses : la
					# première va au premier tiers, la deuxième au deuxième.
					var cible := _cible(vue.lbl_etoiles, centre, (float(i) + 0.5) / 3.0)
					_recompense(vue.seq_t - float(i) * SEQ_ECART, depart, cible, "★", Sty.LAITON_CLAIR, k)
			"diamant":
				# le losange vise le bord gauche du badge, pas le milieu de sa
				# phrase : c'est là qu'il est écrit
				var cd := _cible(vue.lbl_diamant, centre, 0.0, 9.0 * k)
				_gemme(vue.seq_t, centre + Vector2(0, -26.0 * k), cd, k)

	## Le point visé DANS le Label : une fraction de sa largeur, plus un
	## décalage. À défaut — le panneau n'a pas encore été mis en page — le
	## milieu de l'écran, ce qui fait simplement rester la récompense sur place.
	func _cible(l: Label, defaut: Vector2, frac: float, dx: float = 0.0) -> Vector2:
		if l == null or not is_instance_valid(l) or l.size == Vector2.ZERO:
			return defaut
		return to_local(l.global_position + Vector2(l.size.x * frac + dx, l.size.y / 2.0))

	## LE DIAMANT N'EST PAS UNE ÉTOILE DE PLUS. « Le diamant est petit et
	## discret alors que c'est la plus haute récompense d'une partie. Tu peux le
	## valoriser ? » (Vincent, 9 septembre 2026). Il l'était : un glyphe « ◆ »
	## de la police, au même gabarit qu'une étoile, dans la même couleur pâle.
	##
	## C'est maintenant une PIERRE TAILLÉE, dessinée : table, couronne, culasse
	## et leurs facettes, chacune sa nuance, plus un éclat blanc sur le pan qui
	## prend la lumière. Elle arrive une fois et demie plus grande qu'une
	## étoile, dans une gerbe de rayons qui s'ouvre puis retombe, et se tient
	## deux fois plus longtemps sous son titre — SANS FAUTE — avant de rejoindre
	## la feuille. Le sans-faute se joue une fois sur bien des services : il a
	## droit à son temps.
	func _gemme(t: float, depart: Vector2, cible: Vector2, k: float) -> void:
		if t <= 0.0:
			return
		var p := depart
		var taille := 1.0
		var alpha := 1.0
		var pose := 0.0                        # 0..1 pendant la pose, sinon 0
		var titre := 0.0                       # l'opacité du mot
		if t < SEQ_POSE:
			var u: float = t / SEQ_POSE
			taille = 1.5 * sin(u * PI * 0.72) / sin(PI * 0.72)
			taille = maxf(taille, 0.05)
			alpha = minf(1.0, u * 3.0)
			pose = u
			titre = maxf(0.0, (u - 0.55) / 0.45)
		elif t < SEQ_POSE + SEQ_TENUE_GEMME:
			taille = 1.5
			pose = 1.0
			titre = 1.0
		else:
			var u: float = minf((t - SEQ_POSE - SEQ_TENUE_GEMME) / SEQ_VOL, 1.0)
			var e: float = ease(u, -2.0)
			var milieu := depart.lerp(cible, 0.5) + Vector2(0, -70.0 * k)
			p = depart.lerp(milieu, e).lerp(milieu.lerp(cible, e), e)
			taille = lerpf(1.5, 0.22, e)
			alpha = 1.0 if u < 0.85 else lerpf(1.0, 0.0, (u - 0.85) / 0.15)
			titre = maxf(0.0, 1.0 - u * 4.0)
		var h: float = 78.0 * k * taille
		# LA GERBE, qui s'ouvre au moment où la pierre se pose : douze rais
		# fins, longs d'abord, qui rentrent et s'effacent. C'est ce qui fait
		# l'événement — la pierre seule ne ferait qu'apparaître.
		if pose > 0.0 and pose < 1.0:
			var g: float = sin(pose * PI)
			for i in range(12):
				var a: float = TAU * float(i) / 12.0 + pose * 0.35
				var u2 := Vector2(cos(a), sin(a))
				draw_line(p + u2 * h * (0.62 + 0.5 * pose), p + u2 * h * (0.95 + 1.5 * pose),
					Color(Sty.ACCENT_CLAIR, 0.55 * g * alpha), maxf(1.0, 2.2 * k), true)
		# DIX-HUIT NAPPES À PAS RÉGULIER. Douze à pas quadratique laissaient des
		# anneaux visibles : l'œil trouve un bord dès que deux marches sont
		# loin l'une de l'autre. Beaucoup de marches courtes, et le dégradé
		# redevient une lueur.
		for j in range(18):
			draw_circle(p, h * (0.45 + 1.00 * (1.0 - float(j) / 18.0)),
				Color(vue.DIAMANT, 0.020 * alpha))
		vue.tailler_gemme(self, p, h, alpha)
		if titre > 0.0:
			var ft: Font = Sty.titre(700)
			var ts2: int = int(round(19.0 * k))
			Sty.texte_espace(self, ft, ts2,
				Vector2(p.x - Sty.largeur_espacee(ft, ts2, "SANS FAUTE", 4.0 * k) / 2.0,
					p.y + h * 0.92 + ft.get_ascent(ts2)),
				"SANS FAUTE", Color(Sty.ACCENT_CLAIR, titre * alpha), 4.0 * k)



	## Une récompense, à l'instant `t` de sa propre vie : elle grandit sur
	## place, s'y tient, puis file vers la feuille en rapetissant.
	func _recompense(t: float, depart: Vector2, cible: Vector2, glyphe: String,
			col: Color, k: float) -> void:
		if t <= 0.0:
			return
		var p := depart
		var taille := 1.0
		var alpha := 1.0
		if t < SEQ_POSE:
			# l'arrivée : un dépassement, puis le repos — une récompense qui
			# se pose sans rebond n'a l'air de rien
			var u: float = t / SEQ_POSE
			taille = 1.35 * sin(u * PI * 0.72) / sin(PI * 0.72)
			taille = maxf(taille, 0.05)
			alpha = minf(1.0, u * 3.0)
		elif t < SEQ_POSE + SEQ_TENUE:
			taille = 1.35
		else:
			var u: float = minf((t - SEQ_POSE - SEQ_TENUE) / SEQ_VOL, 1.0)
			var e: float = ease(u, -2.0)
			# une courbe, pas une corde : le vol passe par le haut, ce qui
			# donne au geste sa direction
			var milieu := depart.lerp(cible, 0.5) + Vector2(0, -70.0 * k)
			p = depart.lerp(milieu, e).lerp(milieu.lerp(cible, e), e)
			taille = lerpf(1.35, 0.28, e)
			alpha = 1.0 if u < 0.85 else lerpf(1.0, 0.0, (u - 0.85) / 0.15)
		var f: Font = Sty.titre(700)
		var ts: int = int(round(52.0 * k * taille))
		if ts < 1:
			return
		# le halo d'abord, la lettre ensuite : c'est ce qui la fait briller
		# au-dessus du parchemin comme au-dessus de la carte
		var w: float = f.get_string_size(glyphe, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		# CINQ NAPPES, PAS DEUX. Deux disques donnaient un palet beige posé sur
		# la carte — une tache, pas une lueur. Le rayon décroît et l'opacité
		# monte : c'est la même recette que le halo du poste.
		for j in range(12):
			draw_circle(p, w * (0.28 + 0.52 * (1.0 - float(j) / 12.0)), Color(col, 0.028 * alpha))
		Sty.texte_centre(self, f, ts, p, glyphe, Color(col, alpha))


## LE BANDEAU — l'illustration à fond perdu, coins ronds compris.
##
## Godot ne sait découper un Control qu'au RECTANGLE : une TextureRect poussée
## jusqu'au bord montre ses angles carrés dans les coins arrondis de la
## feuille, et c'est pour cela que l'image restait sagement dans la marge.
## « L'image du haut peut être dans la marge » (Vincent, 5 septembre 2026) —
## on la dessine donc soi-même, en un polygone à deux coins ronds en haut et
## deux angles vifs en bas, dont les UV recadrent la bande utile de
## l'illustration en « couvrir ». Pas de shader, pas de masque : un polygone
## texturé, qui suit l'arrondi de la feuille au pixel près.
class Bandeau extends Control:
	var image: Texture2D
	var haut := 0.0        # la bande utile, en fraction de la hauteur d'origine
	var bas := 1.0
	var rayon := 16.0

	func _draw() -> void:
		if image == null or size.x < 2.0 or size.y < 2.0:
			return
		var w := size.x
		var h := size.y
		var r: float = min(rayon, w / 2.0, h)
		var pts := PackedVector2Array([Vector2(0, h), Vector2(0, r)])
		for i in range(9):                       # le coin haut-gauche
			var a: float = PI + PI / 2.0 * float(i) / 8.0
			pts.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r)
		for i in range(9):                       # le coin haut-droit
			var a: float = -PI / 2.0 + PI / 2.0 * float(i) / 8.0
			pts.append(Vector2(w - r, r) + Vector2(cos(a), sin(a)) * r)
		pts.append(Vector2(w, h))
		var tw := float(image.get_width())
		var th := float(image.get_height())
		var bh: float = th * (bas - haut)
		if tw <= 0.0 or bh <= 0.0:
			return
		# « couvrir » : la plus grande des deux échelles, et on centre le reste
		var e: float = max(w / tw, h / bh)
		var u0: float = (tw - w / e) / 2.0
		var v0: float = th * haut + (bh - h / e) / 2.0
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append(Vector2((u0 + p.x / e) / tw, (v0 + p.y / e) / th))
		draw_colored_polygon(pts, Color.WHITE, uvs, image)


func _banniere() -> Control:
	var ch := chapitre
	if ch.is_empty():
		return null
	var t := Ill.banniere_brute(ch["zone"])
	if t == null:
		return null
	var k := Sty.HUD_K

	var pile := Bandeau.new()
	pile.image = t
	pile.haut = Ill.BANDE_HAUT
	pile.bas = Ill.BANDE_BAS
	pile.rayon = Sty.R_GRAND * k
	pile.custom_minimum_size = Vector2(0, 78 * k)
	pile.clip_contents = true

	var voile := TextureRect.new()
	var g := GradientTexture2D.new()
	var d := Gradient.new()
	d.set_color(0, Color(Sty.BOIS, 0.0))
	d.set_color(1, Color(Sty.BOIS, 0.96))
	g.gradient = d
	# Le voile montait trop haut et pas assez fort : sur une bannière qui finit
	# par un coucher de soleil, la jauge à crans se perdait dans la lumière.
	g.fill_from = Vector2(0, 0.05)
	g.fill_to = Vector2(0, 1)
	voile.texture = g
	voile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	voile.stretch_mode = TextureRect.STRETCH_SCALE
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_child(voile)

	var bas := MarginContainer.new()
	bas.anchor_left = 0.0
	bas.anchor_right = 1.0
	bas.anchor_top = 1.0
	bas.anchor_bottom = 1.0
	bas.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cote in ["left", "right", "bottom"]:
		bas.add_theme_constant_override("margin_" + cote, int(round(10 * k)))
	pile.add_child(bas)
	bas.add_child(_titre_chapitre(ch))
	return pile


## Le nom du chapitre, sa région, et la jauge à crans : ce qui se pose sur la
## bannière. Séparé du reste pour qu'un chapitre sans illustration — une carte
## à venir, une zone qu'on n'a pas encore peinte — garde son en-tête.
func _titre_chapitre(ch: Dictionary) -> Control:
	var k := Sty.HUD_K
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(1 * k)))
	var col := couleur_de_zone(ch["zone"])
	# LE TITRE PORTE SON PROPRE CONTRASTE. Un voile suffit sur un ciel sombre et
	# pas sur un coucher de soleil : le nom du chapitre se lisait mal sur la
	# bannière de l'Atlantique. Un liseré d'encre autour des lettres le rend
	# indépendant de ce qu'il y a derrière — quelle que soit l'illustration que
	# Vincent produira demain.
	var titre := _label(String(ch["nom"]), 21, Sty.PAPIER, true, false)
	titre.clip_text = true
	_cerner(titre, 5)
	v.add_child(titre)
	var zone_nom := String(ruban.carte.get("nom", ""))
	for z in ruban.zones():
		if z.get("id") == ch["zone"]:
			zone_nom = String(z.get("nom", zone_nom))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(8 * k)))
	var lz := _label(zone_nom, 12, col.lightened(0.25), false, false)
	lz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lz.clip_text = true
	_cerner(lz, 4)
	h.add_child(lz)
	h.add_child(_crans_du_chapitre(ch))
	v.add_child(h)
	return v


## La jauge du chapitre : un cran par gare, l'état de chacune.
func _crans_du_chapitre(ch: Dictionary) -> Control:
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
	h.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
	var lc := _label(crans, 13, couleur_de_zone(ch["zone"]).lightened(0.3), false, false)
	_cerner(lc, 4)
	h.add_child(lc)
	var rang: Dictionary = Rec.rang_de_chapitre(ruban, ch)
	var droite: Label
	if not rang.is_empty() and rang["id"] != "ouverte" and fete.is_empty():
		droite = _label(String(rang["nom"]), 11, Color(String(rang["couleur"])), false, false)
	else:
		droite = _label("%d/%d" % [faits, ch["gares"].size()], 11, Color(Sty.PAPIER, 0.85), false, false)
	_cerner(droite, 4)
	h.add_child(droite)
	return h


## Un liseré d'encre autour des lettres, pour un texte posé sur une image.
func _cerner(l: Label, taille: int) -> void:
	l.add_theme_constant_override("outline_size", int(round(taille * Sty.HUD_K)))
	l.add_theme_color_override("font_outline_color", Color(Sty.BOIS, 0.85))


func _entete_chapitre() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(2 * Sty.HUD_K)))
	var ch := chapitre
	if ch.is_empty():
		v.add_child(_label(String(ruban.carte.get("nom", "La carte")), 22, P_ENCRE, true))
		return v
	var col := couleur_de_zone(ch["zone"]).darkened(0.42)
	# « Chapitre 1 / 49 » RETIRÉ (demandé le 3 septembre 2026) : sur un
	# téléphone la hauteur est la ressource rare, et le rang du chapitre ne
	# sert à rien pour décider du geste suivant. La jauge à crans, elle, dit
	# déjà où l'on en est DANS le chapitre — la seule position qui compte.
	v.add_child(_label(String(ch["nom"]), 22, P_ENCRE, true))
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
		h.add_child(_label(String(rang["nom"]), 12, Color(String(rang["couleur"])).darkened(0.42), false, false))
	else:
		h.add_child(_label("%d/%d" % [faits, ch["gares"].size()], 12, P_MUET, false, false))
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

	# LA GARE N'A PLUS DE CADRE À ELLE : elle est écrite sur la feuille, sous
	# l'illustration du chapitre, et c'est la feuille qui porte le parchemin.
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(4 * k)))

	# LA VIGNETTE, À GAUCHE DU NOM, comme sur la maquette : la figure du lieu
	# avant son nom. Six archétypes couvrent le catalogue, et c'est la phrase
	# de la fiche qui décide lequel revient à cette gare (jeu/illustrations.gd).
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", int(round(12 * k)))
	var vig := Ill.vignette(cfg)
	if vig != null:
		var cadre := PanelContainer.new()
		var sv := Sty.boite(Sty.PAPIER_OMBRE, Color(Sty.ENCRE, 0.5), Sty.R_PETIT * k, Sty.epaisseur(k))
		sv.set_content_margin_all(2 * k)
		cadre.add_theme_stylebox_override("panel", sv)
		cadre.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var ti := TextureRect.new()
		ti.texture = vig
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ti.custom_minimum_size = Vector2(46 * k, 46 * k)
		cadre.add_child(ti)
		cadre.clip_contents = true
		haut.add_child(cadre)

	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", int(round(2 * k)))
	bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", int(round(8 * k)))
	var nom := _label(ville_de(id), 20, Sty.ENCRE, true, false)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.clip_text = true
	tete.add_child(nom)
	if fin:
		tete.add_child(_pastille("terminus", OR))
	bloc.add_child(tete)
	# SANS DRAPEAU. Il ne s'affiche NULLE PART sur l'iPhone de Vincent (essayé
	# le 5 septembre 2026, ici comme dans le bandeau du poste) : composer un
	# drapeau demande à la police d'assembler une paire d'indicateurs
	# régionaux, et celle de l'appareil ne le fait pas. Le nom du pays suffit,
	# et il se lit partout.
	bloc.add_child(_label(String(pays.get("nom", "")), 12, Sty.SARCELLE))
	haut.add_child(bloc)
	v.add_child(haut)

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
	# LES QUATRE MESURES SUR UNE VRAIE GRILLE. Une GridContainer donne à chaque
	# colonne la largeur de son contenu : « QUAIS » occupait le tiers de la
	# place de « DIFFICULTÉ », et aucune des quatre valeurs ne tombait sous une
	# verticale commune — « l'alignement n'est pas toujours correct » (Vincent,
	# 5 septembre 2026). Quatre fentes de largeur égale alignent les intitulés
	# ET les valeurs.
	var grille := HBoxContainer.new()
	grille.add_theme_constant_override("separation", int(round(8 * k)))
	for trio in [["Quais", str(quais), "loco"], ["Directions", str(dirs), "aiguille"],
			["Difficulté", _pips(d), ""], ["Pour 3 ★", "%d min" % int(seuils["trois"]), "horloge"]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", int(round(2 * k)))
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
		v.add_child(_label(score, 14, P_OR))
	return v


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
	var k := Sty.HUD_K
	v.add_child(_label("SUIVANTE", 11, P_MUET, true, false))
	var ville := ville_de(id)
	var mesures := "%d quais · %d dir. · 3 ★ sous %d min" % [quais, dirs, int(seuils["trois"])]
	# UN NOM NE SE COUPE PAS. La ligne tient le nom et les mesures côte à côte
	# pour économiser de la hauteur, mais « Villa San Giovanni » ne laissait
	# plus la place aux mesures et se faisait rogner en plein mot. On mesure
	# avant : si les deux ne tiennent pas, elles s'empilent.
	var large: float = panneau_l() - 68.0 * k
	var ln: float = Sty.titre(600).get_string_size(ville, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(round(16 * k))).x
	var lm: float = Sty.sans(400).get_string_size(mesures, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(round(12 * k))).x
	var cote_a_cote: bool = ln + lm + 10.0 * k <= large
	var nom := _label(ville, 16, P_ENCRE, true, false)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mes := _label(mesures, 12, P_MUET, false, false)
	if cote_a_cote:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(round(10 * k)))
		h.add_child(nom)
		h.add_child(mes)
		v.add_child(h)
	else:
		v.add_child(nom)
		v.add_child(mes)
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
	v.add_child(_label(ville_de(String(b["gare"])), 12, P_MUET, false, false))

	# les étoiles, et à leur droite ce que le service a coûté
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(10 * Sty.HUD_K)))
	# CES DEUX LABELS SONT LA CIBLE DU VOL (voir la classe Vol) : on les garde,
	# c'est leur place à l'écran qui dit où atterrissent les récompenses.
	lbl_etoiles = _label("★".repeat(st) + "☆".repeat(3 - st), 22, P_OR if b["win"] else P_MUET, false, false)
	h.add_child(lbl_etoiles)
	var retard: String
	var couleur: Color = P_ENCRE
	if b.get("failed", false):
		retard = "%d min — plafond dépassé" % int(b["d"])
		couleur = ROUGE
	elif b.get("perfect", false):
		retard = "◆ Diamant — pas une minute"
		couleur = P_ACCENT
	else:
		retard = "%d min de retard" % int(b["d"])
	var lr := _label(retard, 14, couleur, false, false)
	lr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_diamant = null
	bloc_diamant = null
	if b.get("perfect", false):
		# LE SANS-FAUTE PORTE SON SCEAU. Écrit comme le reste — une ligne de
		# texte de 14 —, il pesait exactement autant qu'un « 7 min de retard ».
		# C'est la plus haute récompense d'un service : elle a droit à sa
		# plaque, cerclée de sarcelle, en capitales espacées.
		var sceau := PanelContainer.new()
		var ss := Sty.boite(Color(Sty.SARCELLE, 0.14), Color(Sty.SARCELLE, 0.85),
			Sty.R_PETIT * Sty.HUD_K, Sty.epaisseur(Sty.HUD_K))
		ss.set_content_margin_all(0)
		ss.content_margin_left = 9 * Sty.HUD_K
		ss.content_margin_right = 9 * Sty.HUD_K
		ss.content_margin_top = 3 * Sty.HUD_K
		ss.content_margin_bottom = 3 * Sty.HUD_K
		sceau.add_theme_stylebox_override("panel", ss)
		sceau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# LA PIERRE EST DESSINÉE, ET À LA TAILLE DES ÉTOILES. Le « ◆ » était un
		# glyphe de police en corps 12 : « le diamant à côté est minuscule, à
		# agrandir ! » (Vincent, 10 septembre 2026). C'est maintenant la même
		# pierre taillée que celle du vol, à la hauteur d'une étoile du relevé —
		# la plus haute récompense ne pèse pas moins que les étoiles qu'elle
		# couronne.
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", int(round(6 * Sty.HUD_K)))
		var pierre := Gemme.new(self, 20.0 * Sty.HUD_K)
		pierre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(pierre)
		lr.text = "DIAMANT · SANS FAUTE"
		lr.add_theme_font_override("font", Sty.titre(700))
		lr.add_theme_font_size_override("font_size", int(round(12 * Sty.HUD_K)))
		lr.add_theme_constant_override("outline_size", 0)
		lr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(lr)
		sceau.add_child(ligne)
		h.add_child(sceau)
		lbl_diamant = lr
		bloc_diamant = sceau
	else:
		h.add_child(lr)
	v.add_child(h)

	# le record d'un côté, l'objectif de l'autre — sur la même ligne
	var pb: Variant = b.get("prevBest")
	var dit := ""
	var teinte: Color = P_MUET
	if b.get("failed", false):
		dit = ""
	elif not b["win"]:
		dit = "objectif manqué"
	elif pb == null:
		dit = "premier service"
		teinte = P_ACCENT
	elif float(b["d"]) < float(pb):
		dit = "record battu · −%d min" % int(float(pb) - float(b["d"]))
		teinte = P_ACCENT
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
			h2.add_child(_label(vise, 12, P_MUET, false, false))
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
		v.add_child(_label("%s — %s" % [m["nom"], m["dit"]], 13, P_OR))
	var reste := utiles.size() - montrees.size()
	if reste > 0:
		v.add_child(_label("+%d" % reste, 12, P_MUET))


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
	v.add_child(_label("Chapitre terminé", 12, couleur_de_zone(ch["zone"]).darkened(0.42)))
	v.add_child(_label("%d / %d ★     %d ◆" % [et, et_max, dia], 20, P_OR, true))
	var rang: Dictionary = Rec.rang_de_chapitre(ruban, ch)
	if not rang.is_empty() and rang["id"] != "ouverte":
		v.add_child(_label(String(rang["nom"]), 15, Color(String(rang["couleur"])).darkened(0.42)))
	if et == et_max and dia == n:
		v.add_child(_label("Pas une minute de retard, nulle part.", 13, P_ACCENT))
	elif et < et_max:
		var reste := et_max - et
		var texte := "%d étoile%s à prendre ici" % [reste, "s" if reste > 1 else ""]
		if payees > 0:
			texte += ", dont %d gare%s passée%s" % [payees, "s" if payees > 1 else "", "s" if payees > 1 else ""]
		v.add_child(_label(texte + ".", 13, P_ENCRE))
	else:
		v.add_child(_label("Toutes les étoiles. Reste les sans-faute : %d." % (n - dia), 13, P_ENCRE))
	if fete.get("zone_finie", false):
		for z in ruban.zones():
			if z.get("id") == ch["zone"]:
				v.add_child(_label("%s — région traversée" % String(z.get("nom", "")), 13, couleur_de_zone(ch["zone"]).darkened(0.42)))
	_ajouter_medailles(v, 0)
	v.add_child(_separateur())
	return v


## Les boutons : un seul geste au repos, et il nomme la gare.
func _pied() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
	if selection != "":
		var deja: bool = ruban.est_faite(selection)
		var h0 := HBoxContainer.new()
		h0.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
		h0.add_child(_bouton("Retour", false, true, _deselectionner))
		h0.add_child(_bouton(_appel("Rejouer" if deja else "Jouer", ville_de(selection), _reste_pied(2)),
			true, true, jouer.bind(selection)))
		v.add_child(h0)
		return v
	var gc := prochaine
	if not fete.is_empty():
		var suivant: Dictionary = fete["suivant"]
		if not suivant.is_empty() and gc != "":
			v.add_child(_label("Chapitre suivant · %s" % String(suivant["nom"]), 12, MUET))
			v.add_child(_bouton(_appel("Jouer", ville_de(gc), _reste_pied()), true, true, jouer.bind(gc)))
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
		h.add_child(_bouton(_appel("Réessayer", ville_de(gare), _reste_pied(2)),
			true, true, jouer.bind(gare)))
		v.add_child(h)
		return v
	if not bilan.is_empty():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(round(8 * Sty.HUD_K)))
		h.add_child(_bouton("Rejouer", false, true, jouer.bind(String(bilan["gare"]))))
		if gc != "":
			h.add_child(_bouton(_appel("Jouer", ville_de(gc), _reste_pied(2)),
				true, true, jouer.bind(gc)))
		v.add_child(h)
		return v
	if gc != "":
		v.add_child(_bouton(_appel("Jouer", ville_de(gc), _reste_pied()), true, true, jouer.bind(gc)))
		return v
	v.add_child(_label("La suite du ruban n'est pas encore écrite." if ruban.au_bout_de_l_ecrit()
		else "Le ruban est terminé. Reste à le dorer.", 13, MUET))
	return v


## LE NOM DE LA VILLE NE DOIT PAS CASSER LA RANGÉE. « Jouer · Villa San
## Giovanni » ne tient pas dans la moitié du panneau d'un téléphone : le bouton
## poussait sa voisine, les deux cessaient d'être alignées et la rangée
## débordait. On mesure donc avant d'écrire — et si le nom ne tient pas, le
## bouton s'appelle « Jouer ». La ville est nommée juste au-dessus, sur la
## feuille : ce n'est pas une information perdue.
func _appel(verbe: String, ville: String, large: float) -> String:
	var texte := verbe + "  ·  " + ville
	var t := int(round(16 * Sty.HUD_K))
	if Sty.titre(700).get_string_size(texte.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, t).x <= large:
		return texte
	return verbe


## LA PLACE DU TEXTE d'un bouton d'appel, quand la rangée en porte `n`.
##
## J'ai mesuré la mauvaise chose. Le budget se calculait en retranchant la
## largeur du VOISIN — un modèle où chaque bouton prend la place de son
## contenu. Or `clip_text` a précisément supprimé ce modèle : depuis, deux
## boutons font EXACTEMENT la moitié de la rangée chacun, quoi qu'on y écrive.
## Le budget annoncé valait donc 365 unités là où il n'y en avait que 251, et
## « Réessayer · York » a été jugé tenable puis rogné à « RÉESSAYER · YO »
## (vu le 5 septembre 2026 sur un relevé d'échec). Deux mécanismes qui se
## contredisent en silence : le second était juste, c'est le premier qui
## devait suivre.
##
## Le panneau porte 22 × k de marge de chaque côté, 8 × k séparent deux
## boutons, et un bouton garde 16 × k de marge intérieure — 36 avec le jeu.
func _reste_pied(n: int = 1) -> float:
	var k := Sty.HUD_K
	var large: float = panneau_l() - 44.0 * k
	if n > 1:
		large = (large - 8.0 * k * float(n - 1)) / float(n)
	return large - 36.0 * k


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
