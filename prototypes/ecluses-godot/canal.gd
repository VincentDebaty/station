class_name Canal
extends Node2D
# ------------------------------------------------------------------
# LE CANAL EN COUPE — la scène d'un niveau, plan par plan, du fond vers
# l'avant :
#   ciel, panorama, prairie            le décor, sourd
#   murs du fond des bassins           la pierre derrière l'eau, plus sombre
#   bateaux, puis l'eau                l'eau réfracte la coque immergée
#   terre et radiers, portes           la coupe au premier plan
#   aqueducs                           sous le fond, dans la terre de la coupe
#   places réservées, roues            ce qu'on touche et ce qu'on vise
#
# Le canal ne décide de rien. Il reçoit des états du moteur et anime le
# passage de l'un à l'autre : les niveaux suivent Torricelli (l'écart fond
# comme le carré du temps qui reste, si bien que l'eau ralentit en se
# posant), les bateaux glissent de place en place.
#
# Les images de art/ remplacent le dessin quand elles existent (voir
# ASSETS.md) : fond.png pour le panorama, bateau_<k>.png pour les bateaux.
# ------------------------------------------------------------------

signal ecoulement_fini
signal bateaux_arrives

const U := 64.0       # une unité en largeur, en pixels
# Une unité en HAUTEUR est plus courte qu'en largeur. Le moteur exige une
# unité d'eau sous un bateau pour qu'il flotte, et la coque doit montrer ce
# tirant : à 64 px, elle plongeait de près de la moitié de sa longueur — un
# jouet de baignoire. À 48 px, un bon tiers : profonde, mais crédible
# (Vincent, 6 octobre 2026). Les niveaux et le moteur n'en savent rien.
const UY := 48.0
const MUR := 0.9
const MARGE := 1.4
const BAS := -1.6
const LOIN := 2600.0   # le décor déborde : aucun bord vide autour de la coupe
const COULEURS := [Color("#e5462f"), Color("#f2b705"), Color("#2b7be0"), Color("#2ea65a")]

# LA PROJECTION OBLIQUE (branche ecluses-oblique, 7 octobre 2026). Vincent :
# tout est vu de profil sauf les écluses, dans un « faux angle de gauche » —
# perturbant. On voit maintenant toute la coupe un peu de la gauche et d'en
# haut : le plan de la coupe reste un profil exact (les niveaux d'eau restent
# horizontaux et se comparent), et la profondeur part en diagonale, vers le
# haut et la gauche. D est le décalage du plan du fond ; les bateaux et les
# bouées voguent à mi-profondeur (D/2). ECLUSES_PROFIL=1 rend la vue de profil.
# Approfondie le 7 octobre (34, 30 → 46, 40), d'après l'image cible de
# Vincent : les portes et les murs y gagnent leur volume.
var D := Vector2(-46.0, -40.0)

const SH_EAU := preload("res://shaders/eau.gdshader")
const SH_PIERRE := preload("res://shaders/pierre.gdshader")
const SH_TERRE := preload("res://shaders/terre.gdshader")
const SH_BOIS := preload("res://shaders/bois.gdshader")
const SH_HERBE := preload("res://shaders/herbe.gdshader")
const SH_TEINTE := preload("res://shaders/teinte.gdshader")
# Comment repeindre le rouge vif du bateau modèle pour chaque bateau du niveau :
# teinte, puis facteurs de saturation et de luminosité. Le rouge reste tel quel.
const REPEINTS := [
	null,
	[0.135, 1.0, 1.05],   # jaune
	[0.60, 0.95, 0.95],   # bleu
	[0.34, 0.85, 0.82],   # vert
]

var N: Dictionary
var gb := []          # [x0, x1] en unités, par bassin
var gl := []          # [x0, x1] en unités, par liaison
var largeur := 0.0
var haut := 0.0
var berge := 0.0
var eaux := []        # une Eau par bassin
var passages := {}    # liaison -> Eau qui remplit l'ouverture d'une porte
var voiles := {}      # liaison -> l'eau du bassin de gauche devant le vantail, porte fermée
var portes := {}      # liaison -> Porte
var aqueducs := {}    # liaison -> Aqueduc, le conduit par où passe l'eau d'une porte à vanne
var _flotte: Node2D
var hausses := {}     # liaison -> Hausse, ses planches et ses poteaux
var pompes := {}      # pompe -> Pompe, sa pompe à bras
var tuyaux_pompe := {} # pompe -> Aqueduc, son tuyau
var jets_pompe := {}  # pompe -> Jet, l'eau qui sort du bec
var _pompage := -1    # la pompe en train de pomper, pendant l'écoulement
var chaudieres := {}  # objet -> Chaudiere, sur la berge du fond
var tuyaux_chaudiere := {} # objet -> Aqueduc, le tuyau qui descend le long du mur du fond
var _chauffe := -1    # la chaudière en train de chauffer, pendant l'écoulement
var glacons := {}     # objet -> Glacon, le bloc de glace et son brasero, sur la berge du fond
var _fontes := {}     # objet -> [part avant, part après] : le glaçon qui fond pendant l'écoulement
var orage: Orage = null # la pluie, les nuages et les éclairs d'un niveau à « pluie »
var marees := {}      # bassin -> Maree : l'échelle, les algues et la flèche de la marée
var bacs := {}        # objet -> Bac : le bac d'un ascenseur à bateaux, ses câbles et sa tête
var siphons := {}     # objet -> Siphon : son tuyau sur la berge du fond, sa roue d'amorçage
var flotteurs := {}   # porte -> Flotteur : la porte que l'eau ouvre toute seule
var dragues := {}     # objet -> Drague : la vase d'un bassin et la grue qui la drague
var _vases := {}      # objet -> [fond avant, fond après] pendant l'écoulement
var fermes := {}      # bassin -> Ferme : la grange en feu de la cour (un « champ » à abreuver)
var moulins := {}     # porte -> Moulin : la roue à aubes, la maison du meunier et ses sacs
var _mouture := []    # [farine avant, farine après] pendant l'écoulement
var _declenches := []  # portes à flotteur qui s'ouvrent pendant ce coup
var _rang_siphon := {} # objet -> son rang dans le tableau des flux (après les liaisons)
var _cible_arriere: Node2D # le plan des tours du fond (derrière les bateaux et l'eau)
var _siphons_apres := {} # objet -> amorcé à la fin du coup (appliqué quand l'eau s'est posée)
var fonds_vus := {}   # bassin -> le fond affiché du bac (unités) : il glisse pendant un voyage
var sommets_fond := [] # le haut du mur du fond de chaque bassin, en unités
var rigoles := {}     # liaison -> Rigole, la berge de terre que l'on creuse
var mares := {}       # bassin -> Mare, la cuvette naturelle sur le pré
var trop_pleins := {}  # porte -> Jet, l'eau qui passe par-dessus une porte fermée
var debordements := {} # liaison -> vrai : une levée que l'eau peut franchir
var levees_noyees := {} # liaison -> le nœud qui dessine l'eau sur sa crête (vue d'en haut)
var coupes_noyees := {} # liaison -> l'Eau de sa coupe
var jets := {}        # liaison -> Jet, l'eau sous une porte simple entrouverte
var bateaux := []     # un Bateau par bateau du niveau
var positions := []   # bassin de chaque bateau, tel qu'affiché
var bat_x := []       # abscisse courante de chaque bateau
var vue_niv := []     # niveaux affichés, en unités
var vue_ouvert := []
var _ecou := {}
var _depl := {}
var _reperes: Node2D
var alertes := {}     # bateau coincé -> l'instant où son « ! » est apparu
var _t := 0.0

func X(x: float) -> float: return x * U
func Y(h: float) -> float: return (haut - h) * UY
func rect_monde() -> Rect2: return Rect2(0, 0, X(largeur), Y(BAS))

# La largeur DESSINÉE d'un bassin, en unités. Le moteur calcule les volumes
# avec la largeur du niveau, et le dessin n'a pas à la suivre : un sas de 2
# unités tenait tout juste un bateau de 1,75, qui y paraissait coincé, et la
# cascade de la porte lui tombait dessus (Vincent, 7 octobre 2026 : « il faut
# toujours un peu d'espace en plus pour qu'un bateau ne soit pas coincé »).
# Chaque place de bateau a donc son jeu de JEU unités de chaque côté.
const LONG_BATEAU := 1.75
const JEU := 0.45
func _largeur_vue(i: int) -> float:
	var l := float(N["bassins"][i]["largeur"])
	var places := mini(Moteur.capacite(N, i), maxi(N["bateaux"].size(), 1))
	# un sas qui porte un objet sur sa berge du fond (glaçon, chaudière) : de
	# la place entre les tours des portes pour qu'on le voie et qu'on le touche
	for o in N.get("objets", []):
		if int(o.get("bassin", -1)) == i and N["bassins"][i]["type"] == "sas": l = maxf(l, 3.9)
	return maxf(l, places * LONG_BATEAU + (places + 1) * JEU)

# --- La construction ---------------------------------------------------------------
# Le canal dessine un QUAI d'ascenseur comme une porte sans roue : ses deux
# piliers, son vantail qui se lève quand le bac est arrêté de son côté. Le
# niveau et l'état sont donc traduits pour la vue : le quai devient une porte
# (« quai » : vrai), ouverte quand Moteur.quai_ouvert le dit.
func _niveau_vu(niveau: Dictionary) -> Dictionary:
	var a_quai := false
	for l in niveau["liaisons"]:
		if l["type"] == "quai": a_quai = true
	if not a_quai: return niveau
	var nv := niveau.duplicate(true)
	for l in nv["liaisons"]:
		if l["type"] == "quai":
			l["type"] = "porte"
			l["quai"] = true
	return nv

func etat_vu(e: Dictionary) -> Dictionary:
	if bacs.is_empty() and not N.get("objets", []).any(func(o): return o["type"] == "ascenseur"): return e
	var ev := e.duplicate(true)
	for i in N["liaisons"].size():
		if N["liaisons"][i].get("quai", false): ev["ouvert"][i] = Moteur.quai_ouvert(N, e, i)
	return ev

func construire(niveau: Dictionary, e0: Dictionary) -> void:
	N = _niveau_vu(niveau)
	var e := etat_vu(e0)
	var B: Array = N["bassins"]
	var n := B.size()
	var x := 0.0 if B[0].get("fixe", false) else MARGE
	var crete_max := 0.0
	for i in n:
		var l := _largeur_vue(i)
		gb.append([x, x + l])
		x += l
		if i < n - 1:
			gl.append([x, x + MUR])
			x += MUR
	largeur = x + (0.0 if B[n - 1].get("fixe", false) else MARGE)
	for l in N["liaisons"]:
		if l.has("crete"): crete_max = maxf(crete_max, float(l["crete"]))
	for b in B:
		crete_max = maxf(crete_max, float(b.get("niveau", b["fond"])) + 0.6)
	haut = crete_max + 3.0
	berge = crete_max + 0.25
	vue_niv = e["niv"].duplicate()
	vue_ouvert = e["ouvert"].duplicate()

	if OS.get_environment("ECLUSES_PROFIL") != "": D = Vector2.ZERO
	_decor()
	_murs_du_fond()
	# le plan des tours de gauche des portes : derrière les bateaux et l'eau
	var arriere := Node2D.new()
	arriere.name = "ToursDuFond"
	add_child(arriere)
	_cible_arriere = arriere
	if D != Vector2.ZERO:
		_dessous_des_bassins()
		_surface_fond = Node2D.new()
		add_child(_surface_fond)
	var flotte := Node2D.new()
	flotte.name = "Bateaux"
	flotte.position = D * 0.5          # à mi-profondeur
	add_child(flotte)
	_flotte = flotte
	for i in n:
		if B[i]["type"] == "village":
			_habiller_village(i, flotte)
			_maisons(i, flotte)
		# (seulement une cour en feu : les champs à irriguer des chapitres Canaux
		# et Fleuve sont aussi des « champ » du moteur)
		if B[i]["type"] == "champ" and B[i].get("feu", false):
			_habiller_village(i, flotte)
			var fe := Ferme.new()
			var o := -D * 0.5
			var f := float(B[i]["fond"])
			fe.preparer(self, i, Vector2(X(gb[i][0] + gb[i][1]) * 0.5, Y(f)) + o + D * 0.75, Y(f + float(B[i]["cible"])) + D.y * 0.5 + o.y,
				X(gb[i][0]) + 6.0 + D.x * 0.5 + o.x, X(gb[i][1]) - 6.0 + D.x * 0.5 + o.x, float(e["niv"][i]) - f >= float(B[i]["cible"]) - 1e-3)
			flotte.add_child(fe)
			fermes[i] = fe
	var vantaux: Node2D = null
	if D != Vector2.ZERO:
		_surface_avant = Node2D.new()
		add_child(_surface_avant)
		vantaux = Node2D.new()
		vantaux.name = "Vantaux"
		add_child(vantaux)
		# la bande de la surface du bassin de gauche où se tient chaque vantail,
		# redessinée PAR-DESSUS lui : l'eau de gauche est devant la porte (on la
		# voit de la gauche), celle de droite derrière. Sans lui, le vantail
		# couvrait la ligne d'eau qui monte en diagonale le long de la porte.
		_surface_dessus = Node2D.new()
		add_child(_surface_dessus)
		_contacts = Node2D.new()
		_contacts.draw.connect(_dessiner_contacts)
		add_child(_contacts)
	for i in n:
		var w := Eau.new()
		var xb := _x_bassin(i)
		w.preparer(xb.x, xb.y, Y(float(B[i]["fond"])), Y(vue_niv[i]), SH_EAU)
		w.paroi_g = i == 0 or not (N["liaisons"][i - 1]["type"] in ["porte", "libre"])
		w.paroi_d = i == n - 1 or not (N["liaisons"][i]["type"] in ["porte", "libre"])
		add_child(w)
		eaux.append(w)
	for i in N["liaisons"].size():
		if N["liaisons"][i]["type"] == "porte":
			var p := Eau.new()
			p.passage = true
			p.gauche = eaux[i]; p.droite = eaux[i + 1]
			p.preparer(X(gl[i][0]), X(gl[i][1]), Y(float(N["liaisons"][i]["seuil"])), 0.0, SH_EAU)
			add_child(p)
			passages[i] = p
			if D != Vector2.ZERO:
				# en oblique, l'eau des bassins va jusqu'au vantail : celle de
				# l'ouverture ne sert plus qu'au calcul de la surface
				p.visible = false
				continue
			# Porte FERMÉE, l'eau du bassin de gauche passe DEVANT le vantail,
			# jusqu'au pilier de droite. Vincent, 6 octobre 2026 : « soyons
			# logiques : il y a de l'eau des deux côtés, la porte devrait être
			# immergée au niveau du bassin de gauche. On a une vue transversale,
			# mais faussement de gauche. » L'écluse est vue un peu de biais : le
			# pilier de gauche est au fond, celui de droite devant, et l'eau de
			# gauche baigne la face de la porte. La porte la place juste devant
			# son vantail (porte.gd) ; porte levée, c'est l'eau de l'ouverture
			# qui la remplace.
			var v := Eau.new()
			v.passage = true
			v.gauche = eaux[i]
			# une eau mince : on y devine le vantail et le pilier, comme la
			# coque immergée d'un bateau (Vincent)
			v.clarte = 1.0
			v.preparer(X(gl[i][0]), X(gl[i][1]) - 9.0, Y(float(N["liaisons"][i]["seuil"])), 0.0, SH_EAU)
			voiles[i] = v
	_coupe_avant()
	for i in N["liaisons"].size():
		var l: Dictionary = N["liaisons"][i]
		if l["type"] == "porte":
			var po := Porte.new()
			po.arriere = arriere
			po.voile = voiles.get(i)
			po.oblique = D
			po.couche_vantail = vantaux
			po.a_vanne = bool(l.get("vanne", false))
			po.sans_roue = bool(l.get("quai", false))
			var bas_radier := Y(minf(float(B[i]["fond"]), float(B[i + 1]["fond"])) - 0.32)
			# trois hauteurs de portique, pour ne pas aligner trois colonnes
			# identiques (lot 4) ; plus bas seulement : le vantail levé garde
			# ~1,4 unité de place sous la traverse
			var decale: float = [0.0, -0.3, -0.15][i % 3]
			# le portique se règle sur la crête de SA porte, pas sur le plus haut
			# du niveau (la mare du 3-1 le montait bien trop haut) : 2,15 unités
			# au-dessus, comme sur les niveaux où toutes les crêtes sont égales
			var portique := minf(haut - 0.85, float(l["crete"]) + 2.15) + decale
			po.preparer(X(gl[i][0]), X(gl[i][1]), Y(float(l["seuil"])), Y(float(l["crete"])), Y(portique), bas_radier, U,
				SH_PIERRE, SH_BOIS, e["vanne"][i] if l.get("vanne", false) else e["ouvert"][i], _vantail_leve(e, i), _bas_ouvert(i))
			add_child(po)
			portes[i] = po
	# les rigoles : chaque digue est une berge de terre où l'on creuse
	# la mare : une cuvette sur le pré, vue d'en haut (son eau de bassin n'est
	# plus dessinée dans la coupe)
	for i in n:
		if B[i]["type"] == "reservoir":
			eaux[i].visible_eau = false
			var m := Mare.new()
			m.preparer(self, i, _rive())
			add_child(m)
			mares[i] = m
	_construire_siphons(e)
	for i in N["liaisons"].size():
		if N["liaisons"][i]["type"] == "digue":
			var x_mare := X(gl[i][1]) + 0.3 * U
			if mares.has(i + 1): x_mare = mares[i + 1].cx - mares[i + 1].rx * 0.9
			var rg := Rigole.new()
			rg.preparer(self, i, e["crete"][i], _rive(), x_mare)
			add_child(rg)
			rigoles[i] = rg
			var jt := Jet.new()
			jt.profondeur = D * Rigole.LARGE          # la largeur de la rigole
			jt.position = D * (Rigole.Z_BORD - Rigole.LARGE * 0.5)
			# au-dessus de la butte (z_index 1) : sa face de terre couvrait le
			# haut de la cascade, qui semblait coupée de la rigole (Vincent)
			jt.z_index = 2
			add_child(jt)
			move_child(jt, _flotte.get_index())
			jets[i] = jt
	# le débordement d'une levée de terre : quand le bief passe sa crête,
	# l'eau la franchit en nappe et coule dans le village (Vincent : « il faut
	# voir l'eau couler dans celui-ci »)
	for i in N["liaisons"].size():
		if N["liaisons"][i]["type"] == "mur" and _terrestre(i):
			var jt := Jet.new()
			jt.profondeur = D
			add_child(jt)
			move_child(jt, _flotte.get_index())
			jets[i] = jt
			debordements[i] = true
			# la levée noyée : quand l'eau est au-dessus de sa crête des deux
			# côtés, une nappe la couvre et relie le bief à la flaque du
			# village (Vincent : il restait une « séparation » d'herbe)
			# sa coupe : une Eau de passage, au même shader que les bassins (un
			# polygone d'une autre teinte faisait « planche », Vincent), qui
			# descend un peu sous la crête pour se voir
			var ep := Eau.new()
			ep.passage = true
			ep.gauche = eaux[i]; ep.droite = eaux[i + 1]
			ep.preparer(X(gl[i][0]) - 1.0, X(gl[i][1]) + 1.0, Y(float(N["liaisons"][i]["crete"])) + 6.0, 0.0, SH_EAU)
			ep.visible_eau = false
			add_child(ep)
			coupes_noyees[i] = ep
			var nv := Node2D.new()
			nv.draw.connect(_dessiner_levee_noyee.bind(i, nv))
			add_child(nv)
			levees_noyees[i] = nv
	# les pompes : sur la berge du bassin qu'elles remplissent, leur tuyau
	# depuis une grille au fond du bassin d'en bas, et leur jet
	var pp: Array = N.get("pompes", [])
	for i in pp.size():
		var de := int(pp[i]["de"])
		var vers := int(pp[i]["vers"])
		# juste derrière le parement de pierre (0,3 unité) : le tuyau monte dans
		# la terre, et le bec avance au-dessus du bassin
		var x_pompe := X(gb[vers][1]) + 0.42 * U if vers >= int(pp[i]["de"]) else X(gb[vers][0]) - 0.42 * U
		var y_pompe := Y(berge)
		var po := Pompe.new()
		po.preparer(self, i, Vector2(x_pompe, y_pompe))
		add_child(po)
		pompes[i] = po
		var bas := Y(minf(float(B[de]["fond"]), float(B[vers]["fond"])) - 0.75)
		for k in range(mini(de, vers), maxi(de, vers) + 1): bas = maxf(bas, Y(float(B[k]["fond"]) - 0.75))
		var xg := X(gb[de][0]) + 0.7 * U
		var aq := Aqueduc.new()
		aq.tuyau_de_pompe = true
		aq.preparer(PackedVector2Array([Vector2(xg, Y(float(B[de]["fond"]))), Vector2(xg, bas), Vector2(x_pompe, bas), Vector2(x_pompe, y_pompe - 6.0)]), 0.2 * UY)
		add_child(aq)
		tuyaux_pompe[i] = aq
		var jt := Jet.new()
		jt.z_index = 2
		add_child(jt)
		jets_pompe[i] = jt
	# les chaudières : sur la berge du fond, au-dessus du bassin qu'elles
	# boivent, dans le plan des tours du fond (derrière les bateaux et l'eau) ;
	# leur tuyau descend le long du mur du fond jusque près du fond, où l'eau
	# le cache à demi
	var objets: Array = N.get("objets", [])
	for k in objets.size():
		if objets[k]["type"] != "chaudiere": continue
		var ib := int(objets[k]["bassin"])
		var xb := _x_bassin(ib)
		var pied := Vector2(lerpf(xb.x, xb.y, 0.62), Y(sommets_fond[ib])) + D + Vector2(0, -3.0)
		var tu := Aqueduc.new()
		tu.tuyau_de_pompe = true
		var ch := Chaudiere.new()
		ch.preparer(pied)
		var x_t := ch.entree_tuyau().x - 26.0
		tu.preparer(PackedVector2Array([Vector2(x_t, Y(float(B[ib]["fond"])) + D.y - 18.0), Vector2(x_t, ch.entree_tuyau().y), ch.entree_tuyau()]), 0.14 * UY)
		tu.bulles.visible = false
		arriere.add_child(tu)
		arriere.add_child(ch)
		chaudieres[k] = ch
		tuyaux_chaudiere[k] = tu
	# les glaçons : le bloc et son brasero sur la berge du fond, au-dessus du
	# bassin qu'ils rempliront, entre les tours du fond des portes voisines
	for k in objets.size():
		if objets[k]["type"] != "glacon": continue
		var ib := int(objets[k]["bassin"])
		var xb := _x_bassin(ib)
		# la place libre sur la berge du fond : du pilier avant de la porte de
		# gauche au pilier du fond de la porte de droite
		var g0 := X(gb[ib][0]) + 12.0
		var g1 := X(gb[ib][1]) + D.x - 30.0
		if g1 - g0 < 110.0:
			g0 = xb.x + D.x; g1 = xb.y + D.x
		var ob: int = e["obj"][k]
		var gl_ := Glacon.new()
		gl_.preparer(Vector2(lerpf(g0, g1, 0.32), Y(sommets_fond[ib]) + D.y - 2.0), lerpf(g0, g1, 0.82),
			1.0 if ob < 0 else float(ob) / float(objets[k]["fonte"]), ob >= 0)
		gl_.y_eau = Y(vue_niv[ib]) + D.y
		arriere.add_child(gl_)
		glacons[k] = gl_
	# le trop-plein d'une porte fermée : quand l'amont atteint sa crête, l'eau
	# passe par-dessus le vantail et tombe de l'autre côté (Vincent : on
	# remplissait le bief amont sans voir que le surplus filait au sas)
	for i in portes:
		var tp := Jet.new()
		tp.profondeur = D
		add_child(tp)
		# devant le vantail (l'eau tombe sur sa face aval), mais derrière le
		# pilier avant, dessiné par la porte (Vincent : elle passait devant)
		move_child(tp, portes[i].get_index())
		trop_pleins[i] = tp
	# les portes à flotteur : la tige, la bague, le flotteur et sa corde, dans
	# le plan des bateaux, contre le pilier, du côté du bassin qui commande
	for i in portes:
		var lf: Dictionary = N["liaisons"][i]
		if not lf.has("flotteur"): continue
		var fb := int(lf["flotteur"]["bassin"])
		var xf := X(gl[i][0]) - 0.4 * U if fb == i else X(gl[i][1]) + 0.4 * U
		var po2: Porte = portes[i]
		var fl := Flotteur.new()
		var o := D * 0.5
		fl.preparer(self, fb, xf + o.x, po2.y_portique + o.y, Y(float(B[fb]["fond"])) + o.y, Y(float(lf["flotteur"]["niveau"])) + o.y,
			Vector2(X(gl[i][0] + gl[i][1]) * 0.5 - 22.0, po2.y_portique + 4.0) + o)
		_flotte.add_child(fl)
		fl.position = -o
		flotteurs[i] = fl
	# les moulins : la roue dans le bassin où tombe l'eau de la vanne, dans le
	# plan des bateaux ; la maison et les sacs sur la berge du fond
	for i in portes:
		var lm: Dictionary = N["liaisons"][i]
		if not lm.get("moulin", false): continue
		var bas_: int = i + 1 if float(B[i + 1]["fond"]) < float(B[i]["fond"]) else i
		var sg := 1.0 if bas_ == i + 1 else -1.0
		# une grande roue, son axe une unité au-dessus du seuil : sa moitié haute
		# reste hors de l'eau même bief du moulin plein (à 0,45 sous le seuil,
		# elle était presque noyée)
		var r := 1.1 * U
		var xr := (X(gl[i][1]) if sg > 0 else X(gl[i][0])) + sg * r * 0.95
		var mo := Moulin.new()
		var xm := (X(gb[bas_][1]) - 0.75 * U if sg > 0 else X(gb[bas_][0]) + 0.75 * U) + D.x
		mo.preparer(self, Vector2(xr, Y(float(lm["seuil"]) + 1.0)) + D * 0.5, r,
			Vector2(xm, Y(sommets_fond[bas_]) + D.y - 2.0), int(ceil(float(N.get("farine", 3)))), float(e.get("moulu", 0.0)))
		arriere.add_child(mo.fond)
		_flotte.add_child(mo.roue)
		mo.roue.position = -D * 0.5
		add_child(mo)
		moulins[i] = mo
	# les ponts bas : sur un passage libre, le pilier du fond derrière l'eau et
	# les bateaux, le pilier avant et le tablier devant
	for i in N["liaisons"].size():
		var lp: Dictionary = N["liaisons"][i]
		if not lp.has("pont"): continue
		var pt := Pont.new()
		pt.preparer(self, X(gl[i][0] + gl[i][1]) * 0.5, Y(float(lp["pont"])), Y(maxf(float(B[i]["fond"]), float(B[i + 1]["fond"])) - 0.32))
		arriere.add_child(pt.fond)
		add_child(pt)
	# les hausses : leurs planches dans la couche des vantaux (vues à travers
	# l'eau), leurs poteaux devant et au fond
	for i in N["liaisons"].size():
		if N["liaisons"][i]["type"] == "hausse":
			var h := Hausse.new()
			h.preparer(self, i, e["crete"][i], vantaux if vantaux else self, arriere)
			add_child(h)
			hausses[i] = h
	# l'ascenseur : le bac (fond et paroi derrière l'eau, tranche avant les
	# portes), la poutre du treuil posée sur les deux quais, après les portes
	for k in objets.size():
		if objets[k]["type"] != "ascenseur": continue
		var ib := int(objets[k]["bassin"])
		var xb := _x_bassin(ib)
		var yp := minf(portes[ib - 1].y_portique, portes[ib].y_portique) - 0.32 * U - 2.0
		var bc := Bac.new()
		var fv := Moteur.fond_de(N, e, ib)
		bc.preparer(self, ib, xb.x, xb.y, yp, float(objets[k]["bas"]), float(objets[k]["haut"]), fv)
		fonds_vus[ib] = fv
		eaux[ib].fond_y = Y(fv)
		arriere.add_child(bc)
		add_child(bc.tranche)
		move_child(bc.tranche, portes[mini(ib - 1, ib)].get_index())
		add_child(bc.devant)
		bacs[k] = bc
	# la vase : sa couche avant l'eau, la grue sur la berge du fond
	for k in objets.size():
		if objets[k]["type"] != "vase": continue
		var ibv := int(objets[k]["bassin"])
		var xbv := _x_bassin(ibv)
		var fv := Moteur.fond_de(N, e, ibv)
		var dg := Drague.new()
		dg.preparer(self, ibv, xbv.x, xbv.y, Y(float(B[ibv]["fond"])), fv, int(e["obj"][k]),
			# à droite du bassin : la benne descend loin de la place du bateau
			Vector2(X(gb[ibv][1]) + D.x - 0.75 * U, Y(sommets_fond[ibv]) + D.y - 2.0))
		fonds_vus[ibv] = fv
		eaux[ibv].fond_y = Y(fv)
		arriere.add_child(dg)
		# sous les bandes de surface (vue d'en haut) : posée après elles, son
		# dessus brun passait par-dessus l'eau
		add_child(dg.couche)
		move_child(dg.couche, (_surface_fond.get_index() if _surface_fond else eaux[ibv].get_index()))
		dragues[k] = dg
	# les aqueducs, dans la terre de la coupe, par-dessus le radier des portes
	for i in portes:
		# porte simple : pas de tuyau, l'eau passe sous la porte entrouverte
		# (jet.gd). L'aqueduc reste pour une porte à vanne (« vanne » dans la
		# liaison), mécanique à venir.
		if not N["liaisons"][i].get("vanne", false):
			var jt := Jet.new()
			jt.profondeur = D            # la nappe traverse tout le canal
			add_child(jt)
			# derrière les bateaux : la lame tombe dans le bassin, pas sur eux
			move_child(jt, _flotte.get_index())
			jets[i] = jt
			continue
		var aq := Aqueduc.new()
		aq.preparer(_trace_aqueduc(i), 0.2 * UY)
		aq.ouverte = e["vanne"][i]
		aq.vanne = 1.0 if aq.ouverte else 0.0
		add_child(aq)
		aqueducs[i] = aq
		portes[i].y_bas_tige = aq.haut_logement()
	for i in fermes: add_child(fermes[i].marque)
	_reperes = Node2D.new()
	_reperes.position = D * 0.5        # les bouées voguent avec les bateaux
	_reperes.z_index = 3
	_reperes.draw.connect(_dessiner_reperes)
	add_child(_reperes)
	for k in N["bateaux"].size():
		var bt := Bateau.new()
		var b: Dictionary = N["bateaux"][k]
		bt.couleur = COULEURS[k % COULEURS.size()]
		bt.tirant = float(b["tirant"]) * UY * 0.92
		bt.longueur = LONG_BATEAU * U
		bt.sens = 1.0 if int(b["vers"]) >= int(b["de"]) else -1.0
		# un seul modèle, le bateau rouge, repeint pour les autres : ChatGPT
		# redessine au lieu de recolorier, et la taille changeait à chaque fois
		var chemin := "res://art/bateau_0.png"
		if ResourceLoader.exists(chemin):
			bt.image = _recadrer(load(chemin))
			bt.ligne = float(_reglages_bateaux().get("bateau_0", {}).get("ligne", 0.71))
			var repeint = REPEINTS[k % REPEINTS.size()]
			if repeint != null:
				bt.material = _mat(SH_TEINTE, {"actif": true, "teinte": repeint[0], "saturation": repeint[1], "luminosite": repeint[2]})
			# l'image est mise à l'échelle pour que sa partie immergée soit le
			# tirant du moteur ; si elle devient alors plus longue que le sas
			# n'en contient, on la plafonne, et sa coque plonge moins que la règle
			var aspect := float(bt.image.get_width()) / bt.image.get_height()
			var h := bt.tirant / maxf(1.0 - bt.ligne, 0.05)
			var plafond := 1.12 * bt.longueur
			if h * aspect > plafond:
				if k == 0: print("bateau_0.png : la coque plonge de %d px pour un tirant de %d (il faudrait %d px de long, le sas en tient %d)" % [int((1.0 - bt.ligne) * plafond / aspect), int(bt.tirant), int(h * aspect), int(plafond)])
				h = plafond / aspect
			bt.largeur_image = h * aspect
			bt.tirant = (1.0 - bt.ligne) * h
		flotte.add_child(bt)
		bateaux.append(bt)
		bt.allumer()
	# la marée : sur le mur du fond de la mer, près de la porte du port
	for i in n:
		if not B[i].has("maree"): continue
		var mr := Maree.new()
		var xb := _x_bassin(i)
		var a := maxf(xb.x, X(gb[i][1]) - 14.0 * U) + D.x
		var bb := X(gb[i][1]) + D.x
		mr.preparer(self, i, a, bb, bb - 0.9 * U)
		mr.regler(int(e["phase"]), int(e["coups"]))
		arriere.add_child(mr)
		marees[i] = mr
	if N.get("pluie"):
		orage = Orage.new()
		add_child(orage)
		orage.preparer(self)
	positions = e["bateaux"].duplicate()
	_preparer_places()
	for k in bateaux.size():
		bat_x.append(place(positions[k], "b%d" % k, positions))
	_maj_passages()

# La partie opaque d'une image : les marges d'une image générée varient d'une
# image à l'autre, et c'est elles qui faisaient des bateaux de tailles différentes.
func _recadrer(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img.is_compressed(): img.decompress()
	var x0 := img.get_width(); var y0 := img.get_height(); var x1 := 0; var y1 := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x); y0 = mini(y0, y); x1 = maxi(x1, x); y1 = maxi(y1, y)
	if x1 <= x0 or y1 <= y0: return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	return at

func _reglages_bateaux() -> Dictionary:
	if not FileAccess.file_exists("res://art/bateaux.json"): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://art/bateaux.json"))
	return d if d is Dictionary else {}

# Le plan où ajouter ce qu'on dessine (le plan du fond, en oblique) ; sinon
# la coupe elle-même.
var _cible: Node2D = null
func _ajouter(n: Node) -> void:
	(_cible if _cible else self).add_child(n)

func _poly(points: PackedVector2Array, mat: Material = null, couleurs := PackedColorArray()) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	if mat: p.material = mat
	# une seule couleur : tout le polygone (en vertex_colors, les sommets sans
	# couleur passeraient en blanc)
	if couleurs.size() == 1: p.color = couleurs[0]
	elif not couleurs.is_empty(): p.vertex_colors = couleurs
	_ajouter(p)
	return p

func _quad(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

func _mat(shader: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params: m.set_shader_parameter(k, params[k])
	if shader == SH_PIERRE: Peint.habiller(m, "pierre")
	elif shader == SH_TERRE: Peint.habiller(m, "terre")
	return m

var _lointain: ShaderMaterial
func _decor() -> void:
	var W := X(largeur)
	var yb := Y(berge)
	# le ciel
	_poly(_quad(-LOIN, -LOIN, W + LOIN, yb + 40), null,
		PackedColorArray([Color("#6fb8e8"), Color("#6fb8e8"), Color("#d8eef2"), Color("#d8eef2")]))
	# le panorama : art/fond.png s'il existe, sinon un bandeau découpé dans la maquette
	var tex: Texture2D = null
	if ResourceLoader.exists("res://art/fond.png"):
		# au-dessus de la berge il n'y a que ~200 px de ciel : on garde la bande
		# de l'image où sont les collines (34 % à 72 % de sa hauteur, ASSETS.md),
		# le reste serait du ciel vide en haut et de la prairie cachée en bas
		# On part aussi après le moulin (17 % de la largeur) : selon la largeur
		# du niveau, le haut de l'écran le coupait par le milieu, ce qui
		# « paraît accidentel » (lot 8). Découpée une fois en image, la bande
		# a ses UV de 0 à 1, dont la brume du shader « lointain » a besoin.
		var brut: Image = (load("res://art/fond.png") as Texture2D).get_image()
		if brut.is_compressed(): brut.decompress()
		var w := brut.get_width()
		var h := brut.get_height()
		tex = ImageTexture.create_from_image(brut.get_region(Rect2i(int(w * 0.17), int(h * 0.34), int(w * 0.83), int(h * 0.38))))
	elif ResourceLoader.exists("res://art/maquette.webp"):
		var at := AtlasTexture.new()
		at.atlas = load("res://art/maquette.webp")
		at.region = Rect2(0, 104, 1050, 196)
		tex = at
	if tex:
		_lointain = ShaderMaterial.new()
		_lointain.shader = preload("res://shaders/lointain.gdshader")
		# l'échelle de l'image entière, même sans le moulin : les copies en
		# miroir comblent la largeur
		var echelle := (W + 160.0) / (tex.get_width() / (0.83 if ResourceLoader.exists("res://art/fond.png") else 1.0))
		var large := tex.get_width() * echelle
		# au centre, puis une copie en miroir de chaque côté : un écran plus
		# allongé que la coupe ne voit jamais le bord du panorama
		for k in [-1, 0, 1]:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.flip_h = k != 0
			s.scale = Vector2(echelle, echelle)
			s.position = Vector2(-80 + k * large, yb + 60 - tex.get_height() * echelle)
			s.material = _lointain
			add_child(s)
	# la prairie, qui descend derrière les bassins
	var pts := PackedVector2Array()
	var y_pre := yb + 46
	for k in 41:
		var xx := -LOIN + (W + 2.0 * LOIN) * k / 40.0
		pts.append(Vector2(xx, y_pre + sin(xx * 0.004) * 10.0 + sin(xx * 0.011) * 5.0))
	pts.append(Vector2(W + LOIN, Y(BAS)))
	pts.append(Vector2(-LOIN, Y(BAS)))
	_poly(pts, _mat(SH_HERBE, {"y_haut": y_pre, "y_bas": Y(0.0)}))

func _murs_du_fond() -> void:
	var B: Array = N["bassins"]
	var fond_pierre := _mat(SH_PIERRE, {"ombre": 0.74, "teinte": Color("#d6c7a8")})
	# derrière une porte, le mur est dans l'ombre du portique : plus sombre
	var fond_porte := _mat(SH_PIERRE, {"ombre": 0.5, "teinte": Color("#d6c7a8")})
	var terre_fond := _mat(SH_TERRE, {"sol_y": Y(0.0)})
	var herbe_fond := _mat(SH_HERBE, {"y_haut": Y(berge), "y_bas": Y(0.0)})
	if D != Vector2.ZERO:
		_cible = Node2D.new()
		_cible.name = "PlanDuFond"
		_cible.position = D
		add_child(_cible)
	var sommets := []
	for i in B.size():
		var b: Dictionary = B[i]
		var f := float(b["fond"])
		var xb := _x_bassin(i)
		var mx0 := xb.x
		var mx1 := xb.y
		var sommet: float
		if b["type"] == "sas" or b["type"] == "bac":
			sommet = 0.0
			for j in [i - 1, i]:
				if j >= 0 and j < N["liaisons"].size() and N["liaisons"][j].has("crete"):
					sommet = maxf(sommet, float(N["liaisons"][j]["crete"]))
			sommet += 0.2
		else:
			# un bief a des quais de pierre presque jusqu'à la berge : la prairie
			# ne se voit qu'en haut, comme une pente qui s'éloigne
			sommet = maxf(maxf(f + 2.5, berge - 1.6), float(b.get("niveau", f)) + 0.8)
			# jamais plus haut que les ouvrages qui le bordent : sur le 3-1, la
			# berge haute de la mare montait le mur du bief aval à 7,25, bien
			# au-dessus du sas (Vincent : « aligner au mur du milieu »)
			var bord := -INF
			for j in [i - 1, i]:
				if j >= 0 and j < N["liaisons"].size() and N["liaisons"][j].has("crete") and not _terrestre(j):
					bord = maxf(bord, float(N["liaisons"][j]["crete"]) + 0.2)
			if bord > -INF: sommet = maxf(minf(sommet, bord), float(b.get("niveau", f)) + 0.8)
		if b["type"] == "reservoir":
			sommets.append(_rive())
			sommets_fond.append(_rive())
			continue
		if _naturel(i):
			# derrière un pré, la prairie continue (rien à dessiner, le décor
			# est là) ; derrière un étang, une berge de terre qui le tient,
			# coiffée d'herbe
			var haut_b := f + 0.9 if b["type"] in ["village", "champ"] else float(b.get("niveau", f)) + 0.6
			sommets.append(haut_b)
			sommets_fond.append(haut_b)
			# la cour d'une ferme : rien au fond, le pré continue (une haie
			# flottait au-dessus de la cour, 15-1) ; la clôture la borde
			if b["type"] == "champ" and b.get("feu", false):
				sommets[sommets.size() - 1] = f
				continue
			_poly(_quad(mx0 - 8, Y(haut_b), mx1 + 8, Y(f)), terre_fond if not (b["type"] in ["village", "champ"]) else herbe_fond)
			_bande_herbe(mx0 - 10, mx1 + 10, Y(haut_b) + 2, 26.0)
			continue
		sommets.append(sommet)
		sommets_fond.append(sommet)
		_poly(_quad(mx0 - 8, Y(sommet), mx1 + 8, Y(f)), fond_pierre)
		# les ombres de contact du mur : au pied, sur le radier, et dans les
		# deux angles du bassin — on les voit à travers l'eau
		var fonce := Color(0.06, 0.03, 0.0, 0.32)
		var clair := Color(0.06, 0.03, 0.0, 0.0)
		_poly(_quad(mx0, Y(f) - 22.0, mx1, Y(f)), null, PackedColorArray([clair, clair, fonce, fonce]))
		_poly(_quad(mx0, Y(sommet), mx0 + 16.0, Y(f)), null, PackedColorArray([fonce, clair, clair, fonce]))
		_poly(_quad(mx1 - 16.0, Y(sommet), mx1, Y(f)), null, PackedColorArray([clair, fonce, fonce, clair]))
		# l'ombre que le couronnement jette sur le haut du mur
		_poly(_quad(mx0 - 8, Y(sommet), mx1 + 8, Y(sommet) + 16), null,
			PackedColorArray([Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		_vie_du_mur(i, mx0, mx1, Y(sommet), Y(f), float(b.get("niveau", f)))
		if D != Vector2.ZERO: _dessus_de_mur(mx0 - 8, mx1 + 8, Y(sommet) + 26.0 - 28.0)
		_couronnement(mx0 - 8, mx1 + 8, Y(sommet), i)
		# le couronnement herbu du mur
		if not _bande_herbe(mx0 - 10, mx1 + 10, Y(sommet) + 2, 24.0):
			_poly(_quad(mx0 - 10, Y(sommet) - 7, mx1 + 10, Y(sommet) + 3), null,
				PackedColorArray([Color("#9ccc63"), Color("#9ccc63"), Color("#6f9a40"), Color("#6f9a40")]))

	# derrière chaque liaison aussi : sinon l'ouverture laisse voir la prairie
	# (en oblique, le mur du fond passe déjà derrière les portes : seules les
	# digues, murs et passages libres restent à boucher)
	for i in N["liaisons"].size():
		var l: Dictionary = N["liaisons"][i]
		if D != Vector2.ZERO and l["type"] == "porte": continue
		# une digue : la rigole dessine toute la berge, entaille comprise
		if D != Vector2.ZERO and l["type"] == "digue": continue
		# la levée d'une mare : rien derrière elle, c'est le pré (le morceau de
		# terre dépassait en carré au-dessus de la rive, 10-1)
		if D != Vector2.ZERO and l["type"] == "mur" and (B[i]["type"] in ["reservoir", "champ"] or B[i + 1]["type"] in ["reservoir", "champ"]): continue
		var c := float(l.get("max", l.get("crete", maxf(float(B[i]["fond"]), float(B[i + 1]["fond"])))))
		var bas := minf(float(B[i]["fond"]), float(B[i + 1]["fond"]))
		# aussi haut que le plus bas des deux murs voisins : derrière un mur
		# bas, on voyait une fente de prairie
		var haut_fente := maxf(c + 0.2, minf(sommets[i], sommets[i + 1]))
		# (un passage libre : la même pierre que le mur des bassins — dans
		# l'ombre d'un portique qui n'existe pas, il traçait une bande sombre)
		_poly(_quad(X(gl[i][0]), Y(haut_fente), X(gl[i][1]), Y(bas)), terre_fond if _terrestre(i) else (fond_pierre if l["type"] == "libre" else fond_porte))
	_cible = null

# En oblique : ce qu'on voit à travers l'eau entre la coupe et le mur du
# fond — le fond de chaque bassin (vu d'en haut), la contremarche quand le
# bassin de droite est plus haut, et la paroi du bout du canal, à droite.
func _dessous_des_bassins() -> void:
	var B: Array = N["bassins"]
	var sol := _mat(SH_PIERRE, {"ombre": 0.82, "teinte": Color("#d6c7a8")})
	var paroi := _mat(SH_PIERRE, {"ombre": 0.66, "teinte": Color("#d6c7a8")})
	for i in B.size():
		# le fond, d'un mur à l'autre (pas jusqu'au milieu des portes : sous
		# la porte, c'est le bloc du seuil)
		var y := Y(float(B[i]["fond"]))
		var f0 := X(gb[i][0]) - (DEBORD if i == 0 and B[i].get("fixe", false) else 0.0)
		var f1 := X(gb[i][1]) + (DEBORD if i == B.size() - 1 and B[i].get("fixe", false) else 0.0)
		# Le fond, vu d'en haut comme la surface de l'eau : un plan qui part en
		# diagonale vers le mur du fond, ses dalles dans SES coordonnées (les
		# joints suivent la profondeur), éclairé et un peu plus sombre au fond.
		# Avec la pierre du mur à l'échelle du monde, il passait pour un bout
		# de mur, et un bateau échoué semblait flotter devant (Vincent).
		var prof := D.length()
		var fond_pts := PackedVector2Array([Vector2(f0, y), Vector2(f1, y), Vector2(f1 + D.x, y + D.y), Vector2(f0 + D.x, y + D.y)])
		if B[i]["type"] == "reservoir": continue
		if B[i]["type"] == "mer":
			# la mer : un fond de sable, ridé, plus sombre vers le large
			_poly(fond_pts, null, PackedColorArray([Color("#e2cf9c"), Color("#e2cf9c"), Color("#b9a46f"), Color("#b9a46f")]))
			var rg := RandomNumberGenerator.new()
			rg.seed = 5
			for k in 60:
				var t := rg.randf()
				var x := lerpf(f0 + 40.0, f1 - 20.0, rg.randf()) + D.x * t
				var yy := y + D.y * t
				_poly(PackedVector2Array([Vector2(x - 9.0, yy), Vector2(x, yy - 1.6), Vector2(x + 9.0, yy), Vector2(x, yy + 0.8)]), null, PackedColorArray([Color(0.55, 0.45, 0.25, 0.35)]))
			continue
		if _naturel(i):
			# un pré (le village) ou un fond de vase (l'étang)
			_poly(fond_pts, null, PackedColorArray([Color("#86b84f"), Color("#86b84f"), Color("#5f8f37"), Color("#5f8f37")]) if B[i]["type"] in ["village", "champ"]
				else PackedColorArray([Color("#6e5130"), Color("#6e5130"), Color("#4f3920"), Color("#4f3920")]))
			continue
		_face(fond_pts, PackedVector2Array([Vector2(0, prof), Vector2(f1 - f0, prof), Vector2(f1 - f0, 0), Vector2(0, 0)]), Color(1.04, 1.0, 0.92), sol)
		_poly(fond_pts, null, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.08, 0.04, 0, 0.28), Color(0.08, 0.04, 0, 0.28)]))
		# l'arête de devant, claire
		_poly(_quad(f0, y - 1.0, f1, y + 1.0), null, PackedColorArray([Color(1, 0.97, 0.88, 0.4)]))
	# Le bloc de maçonnerie entre deux bassins, en volume (Vincent, 7 octobre
	# 2026 : sous la porte de droite du 1-2, « le mur qui relie les deux
	# bassins n'a pas de volume, la porte flotte en l'air ») : son dessus, le
	# seuil où la porte se pose, éclairé ; et sa face gauche, dans l'ombre,
	# quand il domine le bassin de gauche. Sa face droite nous tourne le dos.
	var dessus := _mat(SH_PIERRE, {"ombre": 0.98, "teinte": Color("#e3d4b4")})
	var face := _mat(SH_PIERRE, {"ombre": 0.55, "teinte": Color("#d6c7a8")})
	for i in N["liaisons"].size():
		var l: Dictionary = N["liaisons"][i]
		var haut: float
		match String(l["type"]):
			"porte": haut = float(l["seuil"])
			"libre": haut = maxf(float(B[i]["fond"]), float(B[i + 1]["fond"]))
			"hausse": haut = float(l["min"])
			_: haut = float(l.get("crete", 0.0))
		var a := X(gl[i][0])
		var b := X(gl[i][1])
		var yh := Y(haut)
		var prof := D.length()
		if _terrestre(i):
			# une levée de terre : le dessus en herbe, la face gauche en terre
			# (une digue : la rigole dessine sa butte ; ici, sa face gauche en
			# terre, du pré au fond du bassin, derrière l'eau — sans elle, on
			# voyait la prairie entre le mur du fond et la butte)
			# une levée qui borde la mare : la coupe la dessine jusqu'au pré
			# (_coupe_avant) ; son dessus, posé sur rien derrière elle — la mare
			# n'a pas de fond dessiné —, flottait comme une marche (siphon, 10-1)
			if l["type"] == "mur" and (B[i]["type"] == "reservoir" or B[i + 1]["type"] == "reservoir"):
				continue
			if l["type"] == "digue":
				var yr := Y(_rive())
				var yf := Y(float(B[i]["fond"]))
				_poly(PackedVector2Array([Vector2(a, yr), Vector2(a, yr) + D, Vector2(a, yf) + D, Vector2(a, yf)]), _mat(SH_TERRE, {"sol_y": Y(0.0)}))
				_poly(PackedVector2Array([Vector2(a, yr), Vector2(a, yr) + D, Vector2(a, yf) + D, Vector2(a, yf)]), null,
					PackedColorArray([Color(0.1, 0.05, 0, 0.25), Color(0.1, 0.05, 0, 0.45), Color(0.1, 0.05, 0, 0.45), Color(0.1, 0.05, 0, 0.25)]))
				continue
			_poly(PackedVector2Array([Vector2(a, yh), Vector2(b, yh), Vector2(b + D.x, yh + D.y), Vector2(a + D.x, yh + D.y)]), null,
				PackedColorArray([Color("#9ccc63"), Color("#9ccc63"), Color("#6f9a40"), Color("#6f9a40")]))
			var yg2 := Y(float(B[i]["fond"]))
			if yg2 > yh + 0.5:
				_poly(PackedVector2Array([Vector2(a + D.x, yh + D.y), Vector2(a, yh), Vector2(a, yg2), Vector2(a + D.x, yg2 + D.y)]), _mat(SH_TERRE, {"sol_y": Y(0.0)}))
			continue
		# Chaque face porte la pierre dans SES coordonnées (les joints suivent la
		# profondeur) : posée à l'échelle du monde, elle prolongeait les joints
		# du mur du fond, et le bloc paraissait creux (Vincent).
		_face(PackedVector2Array([Vector2(a, yh), Vector2(b, yh), Vector2(b + D.x, yh + D.y), Vector2(a + D.x, yh + D.y)]),
			PackedVector2Array([Vector2(0, prof), Vector2(b - a, prof), Vector2(b - a, 0), Vector2(0, 0)]), Color(1.08, 1.04, 0.96), dessus)
		var yg := Y(float(B[i]["fond"]))
		if yg > yh + 0.5:
			_face(PackedVector2Array([Vector2(a + D.x, yh + D.y), Vector2(a, yh), Vector2(a, yg), Vector2(a + D.x, yg + D.y)]),
				PackedVector2Array([Vector2(0, 0), Vector2(prof, 0), Vector2(prof, yg - yh), Vector2(0, yg - yh)]), Color(0.62, 0.58, 0.54), face)
			# l'arête verticale de devant, claire, et celle du fond, sombre
			_poly(_quad(a - 1.5, yh, a + 0.5, yg), null, PackedColorArray([Color(1, 0.96, 0.86, 0.5)]))
			var fond_arete := PackedVector2Array([Vector2(a + D.x, yh + D.y), Vector2(a + D.x + 2.0, yh + D.y), Vector2(a + D.x + 2.0, yg + D.y), Vector2(a + D.x, yg + D.y)])
			_poly(fond_arete, null, PackedColorArray([Color(0.2, 0.13, 0.07, 0.55)]))
		# l'arête du dessus, claire, côté coupe, et celle du fond, sombre
		_poly(_quad(a, yh - 1.0, b, yh + 1.5), null, PackedColorArray([Color(1, 0.97, 0.88, 0.5)]))
		_poly(PackedVector2Array([Vector2(a + D.x, yh + D.y - 1.0), Vector2(b + D.x, yh + D.y - 1.0), Vector2(b + D.x, yh + D.y + 1.0), Vector2(a + D.x, yh + D.y + 1.0)]), null, PackedColorArray([Color(0.2, 0.13, 0.07, 0.45)]))
	var n := B.size()
	if not B[n - 1].get("fixe", false):
		var xb := _x_bassin(n - 1)
		var y := Y(float(B[n - 1]["fond"]))
		_face(PackedVector2Array([Vector2(xb.y + D.x, Y(berge) + D.y), Vector2(xb.y, Y(berge)), Vector2(xb.y, y), Vector2(xb.y + D.x, y + D.y)]),
			PackedVector2Array([Vector2(0, 0), Vector2(D.length(), 0), Vector2(D.length(), y - Y(berge)), Vector2(0, y - Y(berge))]), Color(0.66, 0.62, 0.58), paroi)

# Une face de maçonnerie en biais : la pierre peinte plaquée dans les
# coordonnées de la face (« plan », en pixels), teintée ; sans image, le
# matériau dessiné du shader.
func _face(points: PackedVector2Array, plan: PackedVector2Array, teinte: Color, secours: Material) -> void:
	var t := Peint.pierre()
	if t == null:
		_poly(points, secours)
		return
	var p := Polygon2D.new()
	p.polygon = points
	p.texture = t
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var k := float(t.get_width()) / Peint.tuile_pierre().x      # pixels de texture par pixel du monde
	var uv := PackedVector2Array()
	for q in plan: uv.append(q * k)
	p.uv = uv
	p.color = teinte
	_ajouter(p)

# La surface de l'eau vue d'en haut, en oblique : une bande de la coupe au mur
# du fond, en deux moitiés. Celle du fond passe derrière les bateaux ; celle de
# devant passe devant leur coque, un peu transparente — sous leur flottaison,
# la coque est dans l'eau. Elle suit la surface de la coupe, vagues comprises.
var _surface_fond: Node2D
var _surface_avant: Node2D
var _surface_dessus: Node2D
var _bandes := []          # par bassin : [moitié du fond, moitié de devant]
func _maj_surfaces() -> void:
	if _surface_fond == null: return
	if _bandes.is_empty():
		for i in eaux.size():
			var f := Polygon2D.new()
			var a := Polygon2D.new()
			var g := Line2D.new()
			var d := Line2D.new()
			for l in [g, d]:
				l.width = 1.3
				l.default_color = Color(0.85, 0.97, 1.0, 0.45)
				l.antialiased = true
				_surface_avant.add_child(l)
			var bout := Polygon2D.new()
			_surface_dessus.add_child(bout)
			_surface_fond.add_child(f)
			_surface_avant.add_child(a)
			_bandes.append([f, a, g, d, bout])
	for i in eaux.size():
		var w: Eau = eaux[i]
		if mares.has(i):
			for nd in _bandes[i]: nd.visible = false
			continue
		# La surface s'arrête contre la face du bloc d'une porte tant que l'eau
		# est sous son seuil : son bord trace alors, sur la face, la ligne d'eau
		# en diagonale jusqu'au mur du fond (Vincent). Au-dessus du seuil, elle
		# passe sur le bloc jusqu'au vantail.
		var x0 := w.x0
		var x1 := w.x1
		var bloc_g: bool = i > 0 and _pied(i - 1) != INF and vue_niv[i] < _pied(i - 1) - 0.01
		var bloc_d: bool = i < gl.size() and _pied(i) != INF and vue_niv[i] < _pied(i) - 0.01
		if bloc_g: x0 = X(gl[i - 1][1])
		if bloc_d: x1 = X(gl[i][0])
		var bord := PackedVector2Array()
		var x := x0
		while true:
			bord.append(Vector2(x, minf(w.hauteur_a(x), w.fond_y)))
			if x >= x1: break
			x = minf(x + 12.0, x1)
		# Porte levée, les deux eaux n'en font qu'une : chaque bassin a pourtant
		# ses propres vagues, et leurs bandes de surface se rejoignaient en
		# marche d'escalier au milieu de la porte — le plan d'eau « se cassait
		# en deux » au passage d'un bateau (Vincent). Les deux bandes se raccordent
		# à la même hauteur, en fondu sur les 36 derniers pixels.
		if i > 0 and ((passages.has(i - 1) and passages[i - 1].visible_eau) or N["liaisons"][i - 1]["type"] == "libre") and not bloc_g:
			_raccorder(bord, _jonction(i - 1), true)
		if ((passages.has(i) and passages[i].visible_eau) or (i < gl.size() and N["liaisons"][i]["type"] == "libre")) and not bloc_d:
			_raccorder(bord, _jonction(i), false)
		var sec := w.vide()
		_maj_mouille(i, sec)
		var f: Polygon2D = _bandes[i][0]
		var a: Polygon2D = _bandes[i][1]
		f.visible = not sec
		a.visible = not sec
		# le liseré d'écume là où l'eau touche une face de bloc (seule la face
		# gauche d'un bloc se voit : celle de droite du bassin)
		var ld: Line2D = _bandes[i][3]
		ld.visible = bloc_d and not sec
		if ld.visible:
			var p := bord[bord.size() - 1]
			ld.points = PackedVector2Array([p, p + D])
		_bandes[i][2].visible = false
		# le bout contre le vantail de droite, s'il y a une porte et que l'eau
		# va jusqu'à lui
		var bout: Polygon2D = _bandes[i][4]
		# La partie immergée du vantail, vue à travers l'eau de gauche : du
		# bord de la surface (en diagonale, de la coupe au mur du fond) jusqu'au
		# bas du vantail, un voile d'eau par-dessus lui. Une simple bande de
		# surface laissait sous elle un triangle sans eau (Vincent).
		bout.visible = not sec and not bloc_d and i < gl.size() and N["liaisons"][i]["type"] == "porte" \
			and portes.has(i) and portes[i].bas_y > bord[bord.size() - 1].y + 1.0
		if bout.visible:
			var po: Porte = portes[i]
			var xf := X(gl[i][0] + gl[i][1]) * 0.5 - 5.0
			var ys := minf(w.hauteur_a(xf), w.fond_y)
			var yb: float = po.bas_y
			bout.polygon = PackedVector2Array([Vector2(xf - 3.0, ys), Vector2(xf - 3.0 + D.x, ys + D.y), Vector2(xf + 3.0 + D.x, yb + D.y), Vector2(xf + 3.0, yb)])
			bout.vertex_colors = PackedColorArray([Color(0.2, 0.62, 0.8, 0.62), Color(0.45, 0.78, 0.9, 0.62), Color(0.05, 0.36, 0.55, 0.75), Color(0.05, 0.36, 0.55, 0.75)])
		if sec: continue
		f.polygon = _bande(bord, 0.5, 1.0)
		a.polygon = _bande(bord, 0.0, 0.5)
		# un bassin presque vide : sa surface pâlit avec la profondeur (8 px)
		var mince := clampf((w.fond_y - w.repos) / 8.0, 0.0, 1.0)
		f.vertex_colors = _degrade_bande(bord.size(), Color(0.34, 0.76, 0.88, 0.96 * mince), Color(0.64, 0.88, 0.95, 0.96 * mince))
		a.vertex_colors = _degrade_bande(bord.size(), Color(0.17, 0.6, 0.78, 0.78 * mince), Color(0.34, 0.76, 0.88, 0.78 * mince))

# Le pré au bord de la mare (unités) : un peu au-dessus de son eau et de la
# crête de sa digue.
func _rive() -> float:
	var r := 0.0
	for i in N["bassins"].size():
		if N["bassins"][i]["type"] == "reservoir": r = maxf(r, float(N["bassins"][i].get("niveau", N["bassins"][i]["fond"])) + 0.3)
	for l in N["liaisons"]:
		if l["type"] == "digue": r = maxf(r, float(l["crete"]) + 0.3)
	return r

# Un bassin NATUREL : pas de maçonnerie, de la terre et de l'herbe (Vincent,
# 7 octobre 2026 : un village au fond d'un bassin de pierre vide, « c'est très
# bizarre »). Le village est un pré, l'étang a des berges de terre.
func _naturel(i: int) -> bool:
	return String(N["bassins"][i]["type"]) in ["village", "reservoir", "champ"]

# Une liaison de TERRE : une digue, ou un mur qui borde un bassin naturel (une
# levée herbeuse).
func _terrestre(g: int) -> bool:
	var t := String(N["liaisons"][g]["type"])
	return t == "digue" or (t == "mur" and (_naturel(g) or _naturel(g + 1)))

# Le dessus du bloc de pierre au pied d'une porte (son seuil) ou d'une hausse
# (son « min ») : sous lui, l'eau s'arrête contre sa face ; INF ailleurs.
func _pied(g: int) -> float:
	var l: Dictionary = N["liaisons"][g]
	if l["type"] == "porte": return float(l["seuil"])
	if l["type"] == "hausse": return float(l["min"])
	return INF

# L'habillage du village (seconde image cible de Vincent) : un arbre derrière
# les maisons, une clôture au fond du pré, des buissons fleuris. Dans le plan
# des bateaux, derrière l'eau : si le village est inondé, l'eau passe devant.
func _habiller_village(i: int, plan: Node2D) -> void:
	var x0 := X(gb[i][0])
	var x1 := X(gb[i][1])
	var y := Y(float(N["bassins"][i]["fond"]))
	var o := -D * 0.5                # le plan des bateaux est à mi-profondeur
	var cl := _sprite("res://art/cloture.png", 34.0)
	if cl:
		# la clôture, au fond du pré, répétée sur toute sa largeur et au-delà,
		# du côté où il n'y a pas de canal : un village au bout droit de la
		# rangée la prolongeait vers la gauche, par-dessus le bief et le bac
		# de l'ascenseur (9-1)
		var w := cl.texture.get_width() * cl.scale.x
		var debut := x0 - 3.0 * w if i == 0 else x0
		var fin := x1 + 3.0 * w if i == gb.size() - 1 else x1
		var x := debut
		while x + w < fin:                 # jamais au-dessus du canal
			var c := _sprite("res://art/cloture.png", 34.0)
			c.position = Vector2(x + w * 0.5, y - 17.0) + o + D * 0.95
			plan.add_child(c)
			x += w * 0.98
	var ar := _sprite("res://art/arbre.png", 210.0)
	if ar:
		# l'arbre, du côté du pré où il n'y a pas de canal
		var xa := x1 + 0.35 * U if i == gb.size() - 1 and i > 0 else x0 - 0.35 * U
		ar.position = Vector2(xa, y - 105.0) + o + D * 0.85
		plan.add_child(ar)
	for b in [[x0 - 0.05 * U, 0.25, 30.0], [x1 + 0.05 * U, 0.3, 26.0], [(x0 + x1) * 0.5, 0.9, 22.0]]:
		var bu := _sprite("res://art/buisson.png", b[2])
		if bu:
			bu.position = Vector2(b[0], y - b[2] * 0.42) + o + D * b[1]
			plan.add_child(bu)

# Un sprite d'image de art/, à « hauteur » px, ou null.
func _sprite(chemin: String, hauteur: float) -> Sprite2D:
	if not ResourceLoader.exists(chemin): return null
	if not _textures.has(chemin): _textures[chemin] = Images.reduire(chemin, 400)
	var t: Texture2D = _textures[chemin]
	var sp := Sprite2D.new()
	sp.texture = t
	sp.scale = Vector2.ONE * hauteur / t.get_height()
	return sp
var _textures := {}

# Le VILLAGE à épargner : deux maisons au fond de son bassin, à mi-profondeur
# comme les bateaux, derrière l'eau (si elle monte, on les voit à travers).
func _maisons(i: int, plan: Node2D) -> void:
	var n := Node2D.new()
	var x0 := X(gb[i][0])
	var x1 := X(gb[i][1])
	var y := Y(float(N["bassins"][i]["fond"]))
	var tex: Texture2D = null
	if ResourceLoader.exists("res://art/maison.png"): tex = Images.reduire("res://art/maison.png", 300)
	n.draw.connect(func():
		var larg := (x1 - x0) / 2.0
		if tex:
			# l'image peinte de Vincent : deux maisons, la seconde retournée et
			# un peu plus petite, posées dans le pré
			for k in 2:
				var w := larg * (1.05 if k == 0 else 0.88)
				var h := w * tex.get_height() / tex.get_width()
				var cx := x0 + larg * (k + 0.5) + (4.0 if k == 0 else -2.0)
				var base := y - (1.0 if k == 0 else 7.0)
				n.draw_set_transform(Vector2(cx, base), 0.0, Vector2(-1.0 if k == 1 else 1.0, 1.0))
				n.draw_texture_rect(tex, Rect2(-w * 0.5, -h, w, h), false)
			n.draw_set_transform(Vector2.ZERO)
			return
		for k in 2:
			var cx := x0 + larg * (k + 0.5) + (6.0 if k == 0 else -4.0)
			var w := larg * (0.78 if k == 0 else 0.66)
			var h := w * 0.62
			var base := y - (2.0 if k == 0 else 6.0)
			var mur := Color("#f1e3c4") if k == 0 else Color("#e8d6b2")
			n.draw_rect(Rect2(cx - w * 0.5, base - h, w, h), mur)
			n.draw_rect(Rect2(cx - w * 0.5, base - h, w, h), Color("#6b4a2a"), false, 2.0)
			var toit := PackedVector2Array([Vector2(cx - w * 0.62, base - h + 2.0), Vector2(cx, base - h - w * 0.45), Vector2(cx + w * 0.62, base - h + 2.0)])
			n.draw_colored_polygon(toit, Color("#c4542e"))
			n.draw_polyline(toit, Color("#6b2a14"), 2.0)
			n.draw_rect(Rect2(cx - w * 0.1, base - h * 0.55, w * 0.2, h * 0.55), Color("#6b4426"))
			n.draw_rect(Rect2(cx + w * 0.18, base - h * 0.78, w * 0.18, h * 0.24), Color("#8fc3d9"))
			n.draw_rect(Rect2(cx - w * 0.36, base - h * 0.78, w * 0.18, h * 0.24), Color("#8fc3d9"))
			n.draw_rect(Rect2(cx + w * 0.2, base - h - w * 0.4, w * 0.1, w * 0.22), Color("#8a6a52"))
	)
	plan.add_child(n)

# La hauteur commune de deux eaux au milieu d'une porte levée.
func _jonction(g: int) -> float:
	var xc := X(gl[g][0] + gl[g][1]) * 0.5
	return (minf(eaux[g].hauteur_a(xc), eaux[g].fond_y) + minf(eaux[g + 1].hauteur_a(xc), eaux[g + 1].fond_y)) * 0.5

func _raccorder(bord: PackedVector2Array, y: float, debut: bool) -> void:
	var n := bord.size()
	var bout := bord[0] if debut else bord[n - 1]
	for k in n:
		var d := absf(bord[k].x - bout.x)
		if d < 36.0:
			var f := 1.0 - d / 36.0
			bord[k] = Vector2(bord[k].x, lerpf(bord[k].y, y, f * f * (3.0 - 2.0 * f)))

# Un bassin VIDE garde la trace de l'eau (analyse graphique : vide, la grande
# surface claire passait pour un quai) : son fond est sombre et mouillé, avec
# deux ou trois flaques qui luisent. Le mur du fond porte déjà la ligne de
# niveau (_vie_du_mur).
var _mouilles := {}
func _maj_mouille(i: int, sec: bool) -> void:
	if not _mouilles.has(i):
		var n := Node2D.new()
		n.draw.connect(_dessiner_mouille.bind(i))
		_surface_fond.add_child(n)
		_mouilles[i] = n
	var n: Node2D = _mouilles[i]
	var etait: bool = n.visible
	n.visible = sec
	if sec and not etait: n.set_meta("t", _t)
	if sec: n.queue_redraw()

func _dessiner_mouille(i: int) -> void:
	var n: Node2D = _mouilles[i]
	var a := clampf((_t - float(n.get_meta("t", _t))) / 0.8, 0.0, 1.0)
	var x0 := X(gb[i][0]) + 4.0
	var x1 := X(gb[i][1]) - 4.0
	var y: float = eaux[i].fond_y
	n.draw_colored_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1 + D.x, y + D.y), Vector2(x0 + D.x, y + D.y)]),
		Color(0.18, 0.13, 0.08, 0.32 * a))
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 * (i + 1)
	for _j in 3:
		var z := rng.randf_range(0.25, 0.75)
		var c := Vector2(rng.randf_range(x0 + 30.0, x1 - 30.0), y) + D * z
		var rx := rng.randf_range(18.0, 40.0)
		var flaque := PackedVector2Array()
		for j in 20:
			var t := TAU * j / 20.0
			flaque.append(c + Vector2(cos(t) * rx, sin(t) * rx * 0.28) * (1.0 + 0.1 * sin(t * 3.0 + c.x)))
		n.draw_colored_polygon(flaque, Color(0.32, 0.62, 0.72, 0.55 * a))
		# de la mousse au bord de la flaque
		for m in 3:
			var q := c + Vector2(rng.randf_range(-rx, rx), rng.randf_range(-3.0, 3.0))
			n.draw_circle(q, rng.randf_range(2.5, 5.0), Color(0.3, 0.45, 0.17, 0.55 * a))
		n.draw_line(c + Vector2(-rx * 0.5, -1.5), c + Vector2(rx * 0.1, -2.5), Color(0.92, 1, 1, 0.55 * a), 1.5, true)

# Le CONTACT de l'eau (analyse graphique : les bateaux semblaient posés sur
# l'eau, et l'eau sur le décor). Autour de chaque coque et de chaque bouée, à
# leur flottaison et à mi-profondeur, un cerne clair sur la surface vue d'en
# haut, l'avant un peu plus marqué que l'arrière, qui respire doucement.
var _contacts: Node2D
func _dessiner_contacts() -> void:
	if D == Vector2.ZERO: return
	for k in bateaux.size():
		var bt: Bateau = bateaux[k]
		var x: float = bat_x[k]
		var i := bassin_sous(x)
		if eaux[i].vide(): continue
		var y := minf(surface_a(x), eaux[i].fond_y)
		if bt.position.y < y - 4.0: continue        # échoué : pas de cerne
		_cerne(Vector2(x, y) + D * 0.5, bt.longueur * 0.56, absf(D.y) * 0.42, 1.0)
	for k in _bouees_vues:
		var p: Vector2 = _bouees_vues[k]
		_cerne(p + D * 0.5, 17.0, absf(D.y) * 0.22, 0.7)

func _cerne(c: Vector2, rx: float, ry: float, force: float) -> void:
	var pts := PackedVector2Array()
	for j in 33:
		var a := TAU * j / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	var r := 0.85 + 0.15 * sin(_t * 2.4 + c.x * 0.05)
	_contacts.draw_polyline(pts, Color(0.92, 1.0, 1.0, 0.42 * force * r), 2.0, true)
	var pts2 := PackedVector2Array()
	for p in pts: pts2.append(c + (p - c) * 1.18)
	_contacts.draw_polyline(pts2, Color(0.92, 1.0, 1.0, 0.16 * force * r), 1.4, true)

func _bande(bord: PackedVector2Array, z0: float, z1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in bord: pts.append(p + D * z0)
	for k in range(bord.size() - 1, -1, -1): pts.append(bord[k] + D * z1)
	return pts

func _degrade_bande(n: int, devant: Color, fond: Color) -> PackedColorArray:
	var c := PackedColorArray()
	for _k in n: c.append(devant)
	for _k in n: c.append(fond)
	return c

func _coupe_avant() -> void:
	var B: Array = N["bassins"]
	var W := X(largeur)
	var terre := _mat(SH_TERRE, {"sol_y": Y(0.0)})
	var pierre := _mat(SH_PIERRE)
	var tres_bas := Y(BAS) + LOIN
	for i in B.size():
		var f := float(B[i]["fond"])
		var xb := _x_bassin(i)
		var x0 := minf(xb.x, X(gb[i][0]))
		var x1 := maxf(xb.y, X(gb[i][1]))
		# le radier du bassin, puis la terre dessous (un bassin naturel n'a
		# que la terre)
		if B[i]["type"] == "reservoir":
			_poly(_quad(x0 - 2, Y(_rive()), x1 + 2, tres_bas), terre)
			_herbe(x0 - 2, x1 + 2, Y(_rive()))
			continue
		if _naturel(i):
			_poly(_quad(x0 - 2, Y(f), x1 + 2, tres_bas), terre)
			continue
		_poly(_quad(x0 - 2, Y(f), x1 + 2, Y(f - 0.32)), pierre)
		_poly(_quad(x0 - 2, Y(f - 0.32), x1 + 2, tres_bas), terre)
	for i in N["liaisons"].size():
		var bas := minf(float(B[i]["fond"]), float(B[i + 1]["fond"]))
		_poly(_quad(X(gl[i][0]), Y(bas - 0.32), X(gl[i][1]), tres_bas), terre)
		if N["liaisons"][i]["type"] != "porte":
			var c: float = float(N["liaisons"][i].get("crete", maxf(float(B[i]["fond"]), float(B[i + 1]["fond"]))))
			if N["liaisons"][i]["type"] == "hausse": c = float(N["liaisons"][i]["min"])
			if _terrestre(i):
				# une levée de terre, un peu évasée en bas, coiffée d'herbe (la
				# digue d'une rigole est dessinée par la rigole)
				if N["liaisons"][i]["type"] == "digue" or B[i]["type"] == "reservoir" or B[i + 1]["type"] == "reservoir":
					# la butte de la rigole, ou la levée de la mare : de la terre
					# jusqu'au pré (et jusqu'à la terre d'en dessous du radier)
					_poly(_quad(X(gl[i][0]), Y(_rive()), X(gl[i][1]), Y(bas - 0.32)), terre)
					_herbe(X(gl[i][0]), X(gl[i][1]), Y(_rive()))
				else:
					# (jusqu'à la terre d'en dessous, sous le radier : arrêtée au fond,
					# elle laissait un jour de 0,32 unité où l'on voyait le pré du
					# panorama, une bande verte au pied de la levée)
					_poly(PackedVector2Array([Vector2(X(gl[i][0]) - 0.15 * U, Y(bas)), Vector2(X(gl[i][0]) + 0.05 * U, Y(c)), Vector2(X(gl[i][1]) - 0.05 * U, Y(c)), Vector2(X(gl[i][1]) + 0.15 * U, Y(bas)), Vector2(X(gl[i][1]) + 0.15 * U, Y(bas - 0.32)), Vector2(X(gl[i][0]) - 0.15 * U, Y(bas - 0.32))]), terre)
					_herbe(X(gl[i][0]), X(gl[i][1]), Y(c) + 3.0)
			else:
				_poly(_quad(X(gl[i][0]), Y(c), X(gl[i][1]), Y(bas - 0.32)), pierre)
	# les berges, aux deux bouts : terre, parement de pierre côté eau, herbe
	var g0 := X(gb[0][0])
	var g1 := X(gb[B.size() - 1][1])
	if not B[0].get("fixe", false) and _naturel(0):
		# un bassin naturel au bout : la plaine à son niveau, en herbe — le
		# village est posé dans la campagne, pas au fond d'un trou (Vincent)
		var yf0 := Y(float(B[0]["fond"]))
		_poly(_quad(-LOIN, yf0, g0, tres_bas), terre)
		_herbe(-LOIN, g0, yf0)
	elif not B[0].get("fixe", false):
		_poly(_quad(-LOIN, Y(berge), g0, tres_bas), terre)
		_poly(_quad(g0 - 0.3 * U, Y(berge), g0, Y(float(B[0]["fond"]) - 0.32)), pierre)
		if D != Vector2.ZERO: _dessus_de_mur(g0 - 0.3 * U, g0, Y(berge) + 4.0)
		_herbe(-LOIN, g0, Y(berge))
		_empattement(g0 - 0.3 * U, Y(float(B[0]["fond"]) - 0.32), -1.0, pierre)
	var dn := B.size() - 1
	if not B[dn].get("fixe", false) and _naturel(dn):
		# au bout, un étang : sa berge de terre monte jusqu'à la campagne
		var yb1 := Y(_rive()) if B[dn]["type"] == "reservoir" else Y(maxf(float(B[dn].get("niveau", B[dn]["fond"])) + 0.6, float(B[dn]["fond"])))
		_poly(_quad(g1, yb1, W + LOIN, tres_bas), terre)
		_herbe(g1, W + LOIN, yb1)
	elif not B[B.size() - 1].get("fixe", false):
		_poly(_quad(g1, Y(berge), W + LOIN, tres_bas), terre)
		_poly(_quad(g1, Y(berge), g1 + 0.3 * U, Y(float(B[B.size() - 1]["fond"]) - 0.32)), pierre)
		if D != Vector2.ZERO: _dessus_de_mur(g1, g1 + 0.3 * U, Y(berge) + 4.0)
		_herbe(g1, W + LOIN, Y(berge))
		_empattement(g1 + 0.3 * U, Y(float(B[B.size() - 1]["fond"]) - 0.32), 1.0, pierre)
	# la terre vit : une ombre douce sous tout ce qui la couvre (radiers, herbe
	# des berges, parements), et des pousses vertes, comme sur la maquette
	var tops := []      # [x0, x1, y] : le haut de chaque morceau de terre
	for i in B.size():
		# (la terre d'une mare monte jusqu'au pré : son ombre est là, pas à son
		# fond — elle traçait un trait sombre au milieu de la terre)
		var haut_terre := Y(_rive()) if B[i]["type"] == "reservoir" else Y(float(B[i]["fond"]) - (0.0 if _naturel(i) else 0.32))
		tops.append([X(gb[i][0]) - 2, X(gb[i][1]) + 2, haut_terre])
	for i in N["liaisons"].size():
		tops.append([X(gl[i][0]), X(gl[i][1]), Y(minf(float(B[i]["fond"]), float(B[i + 1]["fond"])) - 0.32)])
	if not B[0].get("fixe", false):
		tops.append([-LOIN, g0 - 0.3 * U, (Y(float(B[0]["fond"])) if _naturel(0) else Y(berge)) + 6])
		if not _naturel(0): _ombre_cote(g0 - 0.3 * U, Y(berge) + 6, Y(float(B[0]["fond"]) - 0.32), -1.0)
	if not B[B.size() - 1].get("fixe", false):
		tops.append([g1 + 0.3 * U, W + LOIN, Y(berge) + 6])
		if not _naturel(B.size() - 1): _ombre_cote(g1 + 0.3 * U, Y(berge) + 6, Y(float(B[B.size() - 1]["fond"]) - 0.32), 1.0)
	for t in tops:
		_poly(_quad(t[0], t[2], t[1], t[2] + 26.0), null,
			PackedColorArray([Color(0.12, 0.05, 0, 0.32), Color(0.12, 0.05, 0, 0.32), Color(0.12, 0.05, 0, 0), Color(0.12, 0.05, 0, 0)]))
	for t in tops:
		_rochers(maxf(t[0], -300.0), minf(t[1], W + 300.0), t[2])
	for t in tops:
		_pousses(maxf(t[0], -300.0), minf(t[1], W + 300.0), t[2])

# Le bord d'herbe peint (art/herbe_bord.png), s'il existe : une bande de
# « hauteur » px qui se répète en largeur. Son pied — là où les brins sortent
# de la terre, aux deux tiers de l'image — tombe sur y ; les racines pendent
# dessous. Renvoie faux sans image (le dessin d'avant reprend).
func _bande_herbe(x0: float, x1: float, y: float, hauteur: float) -> bool:
	var t := Peint.herbe()
	if t == null: return false
	var haut_y := y - 0.64 * hauteur
	var k := t.get_height() / hauteur          # pixels de texture par pixel du monde
	# en tronçons de 260 à 560 px, chacun lu à un endroit pris au hasard de la
	# bande et retourné une fois sur deux : la répétition ne se voit plus
	# (lot 5) ; même hasard d'une partie à l'autre
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(x0)) * 31 + int(y) * 7 + 3
	var x := x0
	while x < x1:
		var fin := minf(x + rng.randf_range(260.0, 560.0), x1)
		var u0 := rng.randf_range(0.0, t.get_width())
		var u1 := u0 + (fin - x) * k
		if rng.randf() < 0.5:
			var tmp := u0; u0 = u1; u1 = tmp
		var p := Polygon2D.new()
		p.texture = t
		p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		p.polygon = _quad(x, haut_y, fin, haut_y + hauteur)
		p.uv = PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, t.get_height()), Vector2(u0, t.get_height())])
		_ajouter(p)
		x = fin
	return true

# Des rochers peints (art/rochers.png) à demi enfouis dans la terre, sous un
# bord : rares, de tailles variées, chacun avec son ombre, jamais sur le trajet
# d'un aqueduc. Sans image, ce sont les cailloux du shader de la terre.
func _rochers(x0: float, x1: float, y: float) -> void:
	var images := Peint.rochers()
	if images.is_empty(): return
	var traces := []
	for i in N["liaisons"].size():
		if N["liaisons"][i]["type"] == "porte": traces.append(_trace_aqueduc(i))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(x0) * 3.0 + y * 17.0) + 5
	var x := x0 + rng.randf_range(40.0, 200.0)
	while x < x1 - 30.0:
		var t: Texture2D = images[rng.randi() % images.size()]
		var w := rng.randf_range(36.0, 74.0)
		var h := w * t.get_height() / t.get_width()
		var c := Vector2(x, y + rng.randf_range(70.0, 300.0))
		var libre := rng.randf() < 0.2 + 0.8 * _pres(x)
		for tr in traces:
			for j in tr.size() - 1:
				if Geometry2D.get_closest_point_to_segment(c, tr[j], tr[j + 1]).distance_to(c) < w * 0.6 + 16.0:
					libre = false
		if libre:
			# l'ombre dans la terre, en bas à droite
			var ombre := PackedVector2Array()
			for a in 20:
				var ang := TAU * a / 20.0
				ombre.append(c + Vector2(4.0, h * 0.28) + Vector2(cos(ang) * w * 0.52, sin(ang) * h * 0.32))
			var po := _poly(ombre)
			po.color = Color(0.12, 0.05, 0.0, 0.3)
			var sp := Sprite2D.new()
			sp.texture = t
			sp.scale = Vector2(w / t.get_width(), h / t.get_height())
			sp.flip_h = rng.randf() < 0.5
			sp.position = c
			add_child(sp)
		x += lerpf(380.0, 160.0, _pres(x)) * rng.randf_range(0.7, 1.3)

# L'ombre que fait un parement de pierre sur la terre à côté de lui (sens : -1,
# la terre est à gauche).
func _ombre_cote(x: float, y0: float, y1: float, sens: float) -> void:
	var fonce := Color(0.12, 0.05, 0, 0.28)
	var clair := Color(0.12, 0.05, 0, 0)
	var xe := x + sens * 20.0
	if sens < 0:
		_poly(_quad(xe, y0, x, y1), null, PackedColorArray([clair, fonce, fonce, clair]))
	else:
		_poly(_quad(x, y0, xe, y1), null, PackedColorArray([fonce, clair, clair, fonce]))

# Des pousses dans la terre, sous un bord : de petites touffes de feuilles
# pointues, vert sombre au pied et clair au bout, semées au hasard — mais
# toujours le même hasard pour un même niveau.
# 1 contre la maçonnerie, puis de moins en moins en s'éloignant (lot 10 :
# « un peu plus près des constructions, pas uniformément »).
func _pres(x: float) -> float:
	var a := X(gb[0][0]) - 0.3 * U
	var b := X(gb[gb.size() - 1][1]) + 0.3 * U
	var d := maxf(maxf(a - x, x - b), 0.0)
	return exp(-d / 320.0)

func _pousses(x0: float, x1: float, y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(x0) * 7.0 + y * 13.0) + 1
	var images := Peint.pousses()
	var x := x0 + rng.randf_range(10.0, 60.0)
	while x < x1 - 10.0:
		var py := y + rng.randf_range(30.0, 110.0)
		if rng.randf() > 0.15 + 0.85 * _pres(x):
			x += rng.randf_range(60.0, 140.0)
			continue
		if not images.is_empty():
			# une pousse peinte, posée sur son pied
			var t: Texture2D = images[rng.randi() % images.size()]
			var h := rng.randf_range(20.0, 30.0)
			var w := h * t.get_width() / t.get_height()
			var sp := Sprite2D.new()
			sp.texture = t
			sp.centered = false
			sp.scale = Vector2(w / t.get_width(), h / t.get_height())
			sp.flip_h = rng.randf() < 0.5
			sp.position = Vector2(x - w * 0.5, py - h)
			add_child(sp)
			x += lerpf(240.0, 70.0, _pres(x)) * rng.randf_range(0.6, 1.4)
			continue
		var n := rng.randi_range(3, 5)
		var taille := rng.randf_range(1.3, 2.0)
		for k in n:
			var ang := lerpf(-1.0, 1.0, (float(k) + 0.5) / n) * 0.75 + rng.randf_range(-0.12, 0.12)
			var lg := (10.0 + 6.0 * (1.0 - absf(ang))) * taille
			var d := Vector2(sin(ang), -cos(ang))
			var cote := Vector2(-d.y, d.x) * 2.3 * taille
			var base := Vector2(x, py)
			var milieu := base + d * lg * 0.5
			_poly(PackedVector2Array([base - cote * 0.4, milieu - cote, base + d * lg, milieu + cote, base + cote * 0.4]), null,
				PackedColorArray([Color("#3f6e22"), Color("#5f9a35"), Color("#a8d866"), Color("#5f9a35"), Color("#3f6e22")]))
		x += rng.randf_range(90.0, 230.0)

# L'empattement au pied d'un parement extérieur : deux assises de pierre en
# escalier, dans la terre, côté « sens » (lot 4 : casser la silhouette sur les
# bords extérieurs seulement, jamais dans l'eau).
func _empattement(x: float, y_bas: float, sens: float, pierre: Material) -> void:
	for k in 2:
		var large := 22.0 - k * 10.0
		var y0 := y_bas - 26.0 - k * 24.0
		var y1 := y_bas - k * 24.0
		var xa := x if sens > 0 else x - large
		var xb := x + large if sens > 0 else x
		_poly(_quad(xa, y0, xb, y1), pierre)
		var fonce := Color(0.08, 0.04, 0, 0.3)
		var nul := Color(0.08, 0.04, 0, 0)
		# l'ombre sur la terre, côté opposé à la lumière, et l'arête du dessus
		_poly(_quad(xa, y1, xb, y1 + 6.0), null, PackedColorArray([fonce, fonce, nul, nul]))
		_poly(_quad(xa, y0, xb, y0 + 2.0), null, PackedColorArray([Color(1, 0.96, 0.85, 0.22)]))

# La vie d'un mur du fond (lot 10 de PLAN-RENDU.md), très discrète :
#   la trace d'humidité : la pierre un peu plus sombre du fond jusqu'au niveau
#     de DÉPART de l'eau, et un fin dépôt clair à cette hauteur. Le niveau de
#     départ et pas le plus haut possible : une marque plus haute suggérerait
#     au joueur un niveau atteignable, et pourrait le tromper ;
#   deux ou trois taches de pierre plus foncée et une fissure, au hasard (le
#     même d'une partie à l'autre).
# On les voit à travers l'eau, comme le reste du mur.
func _vie_du_mur(i: int, x0: float, x1: float, y_haut: float, y_fond: float, niveau: float) -> void:
	var y_eau := Y(niveau)
	if y_eau < y_fond - 4.0:
		var humide := Color(0.16, 0.12, 0.06, 0.16)
		var sec := Color(0.16, 0.12, 0.06, 0.0)
		_poly(_quad(x0, y_eau - 10.0, x1, y_eau + 6.0), null, PackedColorArray([sec, sec, humide, humide]))
		_poly(_quad(x0, y_eau + 6.0, x1, y_fond), null, PackedColorArray([humide]))
		_poly(_quad(x0, y_eau - 1.5, x1, y_eau + 1.0), null, PackedColorArray([Color(0.95, 0.92, 0.8, 0.22)]))
	# la mousse (image cible de Vincent) : des touffes vertes au pied du mur,
	# et plus clairsemées le long de la ligne d'humidité
	var rm := RandomNumberGenerator.new()
	rm.seed = 7177 * (i + 1) + int(x0)
	_mousse(rm, x0, x1, y_fond - 3.0, 1.0)
	if y_eau < y_fond - 4.0: _mousse(rm, x0, x1, y_eau + 2.0, 0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 104729 * (i + 1) + int(x0)
	var h := y_fond - y_haut
	if h < 40.0: return
	for _k in rng.randi_range(2, 3):
		var c := Vector2(rng.randf_range(x0 + 20.0, x1 - 20.0), rng.randf_range(y_haut + 30.0, y_fond - 10.0))
		var r := Vector2(rng.randf_range(18.0, 34.0), rng.randf_range(10.0, 18.0))
		var tache := PackedVector2Array()
		for j in 18:
			var a := TAU * j / 18.0
			tache.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * (1.0 + 0.12 * sin(a * 3.0 + c.x)))
		var po := _poly(tache)
		po.color = Color(0.2, 0.15, 0.08, 0.12)
	# la fissure : une ligne brisée qui descend en zigzag
	var p := Vector2(rng.randf_range(x0 + 30.0, x1 - 30.0), rng.randf_range(y_haut + 30.0, y_haut + h * 0.4))
	var fissure := PackedVector2Array([p])
	for _j in rng.randi_range(4, 6):
		p += Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(6.0, 12.0))
		fissure.append(p)
	var ligne := Line2D.new()
	ligne.points = fissure
	ligne.width = 1.6
	ligne.default_color = Color(0.22, 0.16, 0.1, 0.45)
	ligne.antialiased = true
	_ajouter(ligne)

# Le DESSUS d'un mur, vu d'en haut (image cible de Vincent : chaque mur a son
# épaisseur, une bande de pierre dans la même perspective que l'eau). Dans le
# plan où l'on dessine, de y vers l'arrière, sur une demi-profondeur, sous
# l'herbe qui le borde. Éclairé, un peu plus sombre au fond.
func _dessus_de_mur(x0: float, x1: float, y: float) -> void:
	var e := D * 0.45
	var pts := PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1 + e.x, y + e.y), Vector2(x0 + e.x, y + e.y)])
	_face(pts, PackedVector2Array([Vector2(0, e.length()), Vector2(x1 - x0, e.length()), Vector2(x1 - x0, 0), Vector2(0, 0)]),
		Color(1.1, 1.06, 0.98), _mat(SH_PIERRE, {"teinte": Color("#e3d4b4")}))
	_poly(pts, null, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.1, 0.05, 0, 0.22), Color(0.1, 0.05, 0, 0.22)]))

# Une frange de mousse le long de y : des taches vert sombre et vert tendre,
# serrées selon « densite », plus épaisses par endroits.
func _mousse(rng: RandomNumberGenerator, x0: float, x1: float, y: float, densite: float) -> void:
	var x := x0 + rng.randf_range(0.0, 12.0)
	while x < x1 - 4.0:
		if rng.randf() < densite:
			var r := Vector2(rng.randf_range(5.0, 14.0), rng.randf_range(2.5, 6.0))
			var c := Vector2(x, y - r.y * 0.4 + rng.randf_range(-2.0, 2.0))
			var tache := PackedVector2Array()
			for j in 12:
				var a := TAU * j / 12.0
				tache.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * (1.0 + 0.2 * sin(a * 3.0 + x)))
			var vert := Color(0.28, 0.42, 0.16, 0.55) if rng.randf() < 0.6 else Color(0.45, 0.6, 0.22, 0.5)
			var po := _poly(tache)
			po.color = vert
		x += rng.randf_range(6.0, 16.0)

# Les pierres de couronnement en haut d'un mur (lot 4 de PLAN-RENDU.md : la
# grande maçonnerie formait « un énorme rectangle ») : une rangée de pierres
# plus claires, de longueurs et de hauteurs un peu inégales, qui débordent de
# quelques pixels. L'herbe retombe par-dessus leur haut.
func _couronnement(x0: float, x1: float, y: float, graine: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (graine + 1) + int(x0)
	var bas := y + 26.0               # le bas de la rangée ; l'herbe couvre son haut
	# l'ombre que la rangée jette sur le mur
	_poly(_quad(x0, bas, x1, bas + 12.0), null,
		PackedColorArray([Color(0.08, 0.04, 0, 0.3), Color(0.08, 0.04, 0, 0.3), Color(0.08, 0.04, 0, 0), Color(0.08, 0.04, 0, 0)]))
	var x := x0 - 5.0
	while x < x1 + 5.0:
		var w := minf(rng.randf_range(38.0, 66.0), x1 + 5.0 - x)
		var h := 24.0 + rng.randf_range(-2.0, 2.0) + (4.0 if rng.randf() < 0.2 else 0.0)
		var pierre := Color("#d9c093").darkened(rng.randf_range(0.0, 0.12))
		var haut_y := bas - h
		_poly(_quad(x, haut_y, x + w, bas), null,
			PackedColorArray([pierre.lightened(0.1), pierre.lightened(0.04), pierre.darkened(0.14), pierre.darkened(0.08)]))
		# les joints, à droite, et l'arête basse dans l'ombre
		_poly(_quad(x + w - 2.0, haut_y, x + w, bas), null, PackedColorArray([Color("#86704f")]))
		_poly(_quad(x, bas - 3.0, x + w, bas), null, PackedColorArray([Color(0.4, 0.3, 0.18, 0.55)]))
		x += w

func _herbe(x0: float, x1: float, y: float) -> void:
	if _bande_herbe(x0, x1, y, 34.0): return
	_poly(_quad(x0, y - 8, x1, y + 6), null,
		PackedColorArray([Color("#a6d46a"), Color("#a6d46a"), Color("#5f8d37"), Color("#5f8d37")]))
	var touffes := PackedVector2Array()
	var x := maxf(x0, -200.0)
	var fin := minf(x1, X(largeur) + 200.0)
	var k := 0
	while x < fin:
		var h := 7.0 + 6.0 * absf(sin(x * 0.37 + k))
		touffes = PackedVector2Array([Vector2(x, y - 6), Vector2(x + 4, y - 6 - h), Vector2(x + 7, y - 6)])
		_poly(touffes, null, PackedColorArray([Color("#7fb04a"), Color("#b8e07a"), Color("#7fb04a")]))
		x += 9.0 + 7.0 * absf(sin(x * 1.3))
		k += 1

# L'étendue d'un bassin dans le plan de la coupe : en oblique, l'eau va
# jusqu'au milieu de chaque porte voisine (le vantail est en travers du canal,
# au milieu de la porte) ; de profil, entre les murs.
# Un bassin « fixe » au bout du niveau (la mer) n'a pas de bord : il continue
# hors de l'écran, de DEBORD px — avant, l'eau, le mur et la terre
# s'arrêtaient au bord du niveau, et l'écran montrait le vide à côté.
const DEBORD := 900.0
func _x_bassin(i: int) -> Vector2:
	var a := X(gb[i][0])
	var b := X(gb[i][1])
	if N["bassins"][i].get("fixe", false):
		if i == 0: a -= DEBORD
		if i == gb.size() - 1: b += DEBORD
	if D != Vector2.ZERO:
		# (une hausse aussi : ses planches sont au milieu du mur, l'eau les touche)
		# (un passage libre aussi : les deux eaux se rejoignent au milieu)
		if i > 0 and N["liaisons"][i - 1]["type"] in ["porte", "hausse", "libre"]: a = X(gl[i - 1][0] + gl[i - 1][1]) * 0.5
		if i < gl.size() and N["liaisons"][i]["type"] in ["porte", "hausse", "libre"]: b = X(gl[i][0] + gl[i][1]) * 0.5
	return Vector2(a, b)

# --- Où sont les choses ---------------------------------------------------------------
func bassin_sous(x: float) -> int:
	for i in gb.size():
		if x <= X(gb[i][1]) + X(MUR) * 0.5: return i
	return gb.size() - 1

func surface_a(x: float) -> float:
	for i in gb.size():
		if x >= X(gb[i][0]) and x <= X(gb[i][1]): return eaux[i].hauteur_a(x)
	for i in passages:
		if x > X(gl[i][0]) and x < X(gl[i][1]) and passages[i].visible_eau: return passages[i].hauteur_a(x)
	var i2 := bassin_sous(x)
	return eaux[i2].hauteur_a(clampf(x, X(gb[i2][0]), X(gb[i2][1])))

# Une hausse sous le doigt : {i, quoi} (« hausser » au-dessus des planches,
# « abaisser » dessus), ou {} .
func hausse_sous(p: Vector2) -> Dictionary:
	for i in hausses:
		var q: String = hausses[i].geste(p)
		if q != "": return {"i": i, "quoi": q}
	return {}

# Le volant de vanne sous le doigt (porte à vanne), ou -1. Cherché avant la
# porte : il est sur son pilier.
func vanne_sous(p: Vector2) -> int:
	for i in portes:
		if portes[i].a_vanne and p.distance_to(portes[i].centre_vanne()) < 0.6 * U: return i
	return -1

func porte_sous(p: Vector2) -> int:
	for i in portes:
		if portes[i].sans_roue: continue
		var c: Vector2 = portes[i].centre_roue()
		if p.distance_to(c) < 0.95 * U: return i
		if p.x > X(gl[i][0]) - 0.7 * U and p.x < X(gl[i][1]) + 0.7 * U and p.y > c.y - 0.6 * U and p.y < Y(BAS): return i
	return -1

# Les places d'un bassin sont FIXES pour toute la partie : autant de places
# que de bateaux qui passeront par ce bassin, chacun la sienne. Avant, elles
# se recalculaient selon les bateaux présents, et un bateau seul se recentrait
# puis se poussait quand un autre arrivait (Vincent, 6 octobre 2026). Un sas
# n'a qu'une place, au milieu. Dans un bief, un bateau qui en repart vers la
# droite, ou qui y arrive par la droite, se range à droite ; vers la gauche, à
# gauche ; un bateau qui ne fait que passer, au milieu. La place réservée
# (pointillés) d'un bateau est sa place dans son bassin d'arrivée.
var _places := {}    # bassin -> liste ordonnée des bateaux qui y ont une place

func _preparer_places() -> void:
	var B: Array = N["bassins"]
	for i in B.size():
		var L := []
		for k in N["bateaux"].size():
			var de := int(N["bateaux"][k]["de"])
			var vers := int(N["bateaux"][k]["vers"])
			if i >= mini(de, vers) and i <= maxi(de, vers): L.append(k)
		L.sort_custom(func(a, b): return _cote(a, i) < _cote(b, i) or (_cote(a, i) == _cote(b, i) and a < b))
		_places[i] = L

func _cote(k: int, i: int) -> int:
	var de := int(N["bateaux"][k]["de"])
	var vers := int(N["bateaux"][k]["vers"])
	var sens := signi(vers - de)
	if i == de: return sens          # il repartira de ce côté
	if i == vers: return -sens       # il est arrivé par ce côté
	return 0                         # il ne fait que passer

func place(i: int, cle: String, _pos: Array = []) -> float:
	var k := int(cle.substr(1))
	if Moteur.capacite(N, i) <= 1 or not _places.has(i):
		return (X(gb[i][0]) + X(gb[i][1])) * 0.5
	var L: Array = _places[i]
	var j := L.find(k)
	if j < 0: return (X(gb[i][0]) + X(gb[i][1])) * 0.5
	return lerpf(X(gb[i][0]), X(gb[i][1]), float(j + 1) / float(L.size() + 1))

# --- Le temps qui passe ---------------------------------------------------------------
func _process(dt: float) -> void:
	_t += dt
	if not _ecou.is_empty(): _avancer_ecoulement(dt)
	if not _depl.is_empty(): _avancer_bateaux(dt)
	for i in eaux.size():
		eaux[i].repos = Y(vue_niv[i])
	for i in portes: portes[i].bas_ouvert_y = _bas_ouvert(i)
	_maj_passages()
	_maj_surfaces()
	_maj_voiles()
	for i in levees_noyees:
		levees_noyees[i].queue_redraw()
		coupes_noyees[i].visible_eau = minf(vue_niv[i], vue_niv[i + 1]) > float(N["liaisons"][i]["crete"])
	# le tuyau d'une pompe est plein jusqu'à la pompe (elle est amorcée) tant
	# que sa source a de l'eau ; l'eau n'y court que pendant un coup de pompe
	# (Vincent : un tuyau à moitié plein qui coulait faisait une animation
	# incohérente)
	for i in tuyaux_pompe:
		var de := int(N["pompes"][i]["de"])
		var a_eau: bool = vue_niv[de] > float(N["bassins"][de]["fond"]) + 0.01
		tuyaux_pompe[i].niveau_g = Y(vue_niv[de])
		tuyaux_pompe[i].niveau_d = -1e9 if a_eau else Y(vue_niv[de])
	for k in glacons:
		glacons[k].y_eau = Y(vue_niv[int(N["objets"][k]["bassin"])]) + D.y
	for k in siphons:
		var so: Dictionary = N["objets"][k]
		siphons[k].tuyau.niveau_g = Y(vue_niv[int(so["a"])]) + D.y
		siphons[k].tuyau.niveau_d = Y(vue_niv[int(so["b"])]) + D.y
	for k in dragues:
		var ibd: int = dragues[k].ib
		dragues[k].fond_vu = fonds_vus[ibd]
		eaux[ibd].fond_y = Y(fonds_vus[ibd])
	for k in bacs:
		var ibc: int = bacs[k].ib
		bacs[k].fond_vu = fonds_vus[ibc]
		eaux[ibc].fond_y = Y(fonds_vus[ibc])
	for k in tuyaux_chaudiere:
		var ib := int(N["objets"][k]["bassin"])
		var a_eau: bool = vue_niv[ib] > float(N["bassins"][ib]["fond"]) + 0.01
		tuyaux_chaudiere[k].niveau_g = Y(vue_niv[ib]) + D.y
		tuyaux_chaudiere[k].niveau_d = -1e9 if a_eau else Y(vue_niv[ib]) + D.y
	for i in aqueducs:
		aqueducs[i].ouverte = portes[i].vanne_ouverte
		aqueducs[i].niveau_g = Y(vue_niv[i])
		aqueducs[i].niveau_d = Y(vue_niv[i + 1])
	_poser_bateaux(dt)
	_reperes.queue_redraw()
	if _contacts: _contacts.queue_redraw()

# L'eau devant le vantail : la SEULE qu'on voit dans l'ouverture d'une porte,
# fermée comme ouverte. Porte fermée, au niveau du bassin de gauche ; porte
# levée, de bord à bord entre les deux bassins. L'eau de l'ouverture
# (passages) reste pour le calcul (surface_a) mais n'est plus dessinée : elle
# était derrière le vantail, et en prenant le relais pendant que la porte
# bougeait, elle laissait le bas du vantail apparaître d'un coup puis
# replonger à la fin (Vincent).
func _maj_voiles() -> void:
	for i in voiles:
		var v: Eau = voiles[i]
		passages[i].visible = false
		v.droite = eaux[i + 1] if passages[i].visible_eau else null
		v.repos = eaux[i].hauteur_a(X(gb[i][1]))
		v.visible_eau = vue_niv[i] > float(N["liaisons"][i]["seuil"]) + 0.03 or passages[i].visible_eau

func _maj_passages() -> void:
	for i in passages:
		var s := float(N["liaisons"][i]["seuil"])
		var ouvert: float = portes[i].ouverture() if portes.has(i) else 0.0
		passages[i].visible_eau = ouvert > 0.15 and maxf(vue_niv[i], vue_niv[i + 1]) > s + 0.03
		passages[i].remous = maxf(eaux[i].remous, eaux[i + 1].remous)

# Le tracé d'un aqueduc : il part d'une grille dans le fond du bassin de
# gauche, près de la porte, plonge sous le radier, passe sous la porte et
# remonte par une grille dans le fond du bassin de droite. Les vraies écluses
# ont souvent leurs aqueducs sous le radier ; ici, ça le montre en entier
# dans la coupe, et il ne croise jamais un bateau. (Dans le mur du fond, il
# disparaissait sous une eau presque opaque.)
func _trace_aqueduc(i: int) -> PackedVector2Array:
	var B: Array = N["bassins"]
	var fg := float(B[i]["fond"])
	var fd := float(B[i + 1]["fond"])
	var bas := minf(fg, fd) - 0.75
	var xg := X(gl[i][0]) - 0.5 * U
	var xd := X(gl[i][1]) + 0.5 * U
	return PackedVector2Array([Vector2(xg, Y(fg)), Vector2(xg, Y(bas)), Vector2(xd, Y(bas)), Vector2(xd, Y(fd))])

# Le vantail d'une porte se lève quand sa vanne est ouverte ET que les deux
# eaux sont au même niveau — c'est exactement quand le moteur laisse passer
# un bateau.
func _vantail_leve(e: Dictionary, i: int) -> bool:
	return bool(e["ouvert"][i]) and absf(float(e["niv"][i]) - float(e["niv"][i + 1])) < 1e-6

# Où monte le bas d'un vantail levé : au-dessus de l'eau, de quoi laisser
# passer un bateau cheminée comprise (une unité au-dessus de sa flottaison,
# plus une marge). Il suit l'eau si elle bouge pendant que la porte est levée.
const DEGAGEMENT := 1.35
func _bas_ouvert(i: int) -> float:
	return Y(maxf(vue_niv[i], vue_niv[i + 1]) + DEGAGEMENT)

# Pose chaque vantail selon l'état e ; rend la main quand tous sont arrivés.
func placer_vantaux(e0: Dictionary) -> void:
	var e := etat_vu(e0)
	for i in portes:
		portes[i].placer_vantail(_vantail_leve(e, i))
	var bouge := true
	while bouge:
		await get_tree().process_frame
		bouge = false
		for i in portes:
			if not portes[i].arrive(): bouge = true

# Un écoulement : de l'état « avant » à l'état « après », niveaux et aqueducs.
func ecouler(avant: Array, apres: Array, flux: Array) -> void:
	var dh := 0.0
	for i in avant.size(): dh = maxf(dh, absf(apres[i] - avant[i]))
	# De l'eau peut circuler sans qu'aucun niveau ne change : pompée en haut,
	# elle redescend par les portes ouvertes jusqu'au bassin d'où elle vient.
	# Sans animation, on croyait que la pompe ne marchait pas (Vincent). On
	# montre l'écoulement dès qu'il y a du débit, ou un coup de pompe.
	var fl_max := 0.0
	for f in flux: fl_max = maxf(fl_max, absf(float(f)))
	if dh < 1e-4 and fl_max < 0.01 and _pompage < 0 and _chauffe < 0 and _fontes.is_empty() and _vases.is_empty():
		vue_niv = apres.duplicate()
		ecoulement_fini.emit.call_deferred()
		return
	var tetes := {}
	for i in mini(flux.size(), N["liaisons"].size()):
		if absf(flux[i]) > 0.01: tetes[i] = absf(avant[i] - avant[i + 1])
	_ecou = {"t": 0.0, "T": maxf(1.1 + 1.25 * sqrt(dh), 1.6 if fl_max >= 0.01 or _pompage >= 0 else 0.0), "avant": avant.duplicate(), "apres": apres.duplicate(), "flux": flux.duplicate(), "tetes": tetes}

func _avancer_ecoulement(dt: float) -> void:
	_ecou["t"] += dt
	var p := clampf(_ecou["t"] / _ecou["T"], 0.0, 1.0)
	var f := (1.0 - p) * (1.0 - p)
	for i in vue_niv.size():
		vue_niv[i] = _ecou["apres"][i] + (_ecou["avant"][i] - _ecou["apres"][i]) * f
	# Le bassin derrière une levée ne se remplit qu'une fois l'eau arrivée à sa
	# crête : avant, tous les niveaux glissaient ensemble, et le village
	# s'inondait avant que l'eau ne déborde (Vincent).
	var par_dessus: Array = debordements.keys()
	for g in portes:
		if _porte_close(g): par_dessus.append(g)
	for g in par_dessus:
		var crete := float(N["liaisons"][g]["crete"])
		for c in [[g + 1, g], [g, g + 1]]:          # [qui monte au-dessus de la crête, qui reçoit]
			var h: int = c[0]
			var l: int = c[1]
			var av_h: float = _ecou["avant"][h]
			var ap_h: float = _ecou["apres"][h]
			var ap_l: float = _ecou["apres"][l]
			var av_l: float = _ecou["avant"][l]
			# (une porte fermée qui déborde : l'amont s'arrête AU ras de la crête)
			if ap_l - av_l < 1e-4 or av_h >= crete - 1e-6 or ap_h < crete - 1e-6: continue
			# l'instant où le niveau affiché de h passe la crête, ramené à 0,75
			# au plus pour que l'inondation ait le temps de se voir
			var p0 := 1.0 - sqrt(clampf((crete - ap_h) / (av_h - ap_h), 0.0, 1.0))
			p0 = minf(p0, 0.75)
			var q := clampf((p - p0) / maxf(1.0 - p0, 0.01), 0.0, 1.0)
			vue_niv[l] = ap_l + (av_l - ap_l) * (1.0 - q) * (1.0 - q)
	# Un bassin TRAVERSÉ : l'eau y entre d'un côté et en ressort de l'autre
	# sans s'y arrêter (sur le 3-1, la mare se vide dans le bief amont vide, qui
	# se vide aussitôt dans le sas par sa porte ouverte). Son niveau ne bouge
	# pas, et l'on ne voyait pas l'eau passer (Vincent). Pendant l'écoulement,
	# une pellicule d'eau court sur son fond — quelques pixels, trop peu pour
	# remettre un bateau à flot — et franchit le seuil de la porte.
	var fl: Array = _ecou["flux"].slice(0, N["liaisons"].size())
	for i in vue_niv.size():
		var entre_d := i < fl.size() and float(fl[i]) < -0.01
		var sort_g := i > 0 and float(fl[i - 1]) < -0.01
		var entre_g := i > 0 and float(fl[i - 1]) > 0.01
		var sort_d := i < fl.size() and float(fl[i]) > 0.01
		# (l'eau d'une pompe qui arrive dans un bassin vide et en ressort par
		# une porte ouverte le traverse aussi : sans cette pellicule, le bassin
		# restait sec et l'on croyait que la pompe ne marchait pas, Vincent)
		var par_pompe := _pompage >= 0 and int(N["pompes"][_pompage]["vers"]) == i and (sort_g or sort_d)
		if not ((entre_d and sort_g) or (entre_g and sort_d) or par_pompe): continue
		var fond := float(N["bassins"][i]["fond"])
		if vue_niv[i] > fond + 0.12: continue
		var film := 0.1 * minf(1.0, p * 8.0) * minf(1.0, (1.0 - p) * 5.0)
		vue_niv[i] = maxf(vue_niv[i], fond + film)
	for i in eaux.size(): eaux[i].remous = move_toward(eaux[i].remous, 0.0, dt * 0.8)
	for i in trop_pleins: trop_pleins[i].force = 0.0
	for k in siphons:
		# l'eau court dans le tuyau du siphon, dans le sens du débit
		var fs := float(_ecou["flux"][_rang_siphon[k]]) if _rang_siphon[k] < _ecou["flux"].size() else 0.0
		var sp: Siphon = siphons[k]
		if absf(fs) > 0.01:
			var force := clampf(minf(p * 5.0, (1.0 - p) * 2.5), 0.0, 1.0)
			sp.tuyau.ouverte = true
			sp.tuyau.couler(force * 0.9, 1 if fs > 0 else -1)
			var o: Dictionary = N["objets"][k]
			var recoit := int(o["b"]) if fs > 0 else int(o["a"])
			var bout: Vector2 = sp.tuyau.chemin[sp.tuyau.chemin.size() - 1] if fs > 0 else sp.tuyau.chemin[0]
			if force > 0.2 and randf() < 0.3 and not mares.has(recoit):
				eaux[recoit].impulsion(bout.x - D.x * 0.5, randf_range(-0.5, 0.4) * force, 22.0)
		else:
			sp.tuyau.couler(0.0, 1)
	for i in mini(_ecou["flux"].size(), N["liaisons"].size()):
		if portes.has(i) and _porte_close(i) and absf(float(_ecou["flux"][i])) > 0.01 and _deborde(i):
			_trop_plein(i, float(_ecou["flux"][i]))
			continue
		if aqueducs.has(i): _aqueduc(i, _ecou["flux"][i], dt)
		elif rigoles.has(i): _jet_rigole(i, _ecou["flux"][i], dt)
		elif debordements.has(i): _jet_mur(i, _ecou["flux"][i], dt)
		elif jets.has(i): _jet(i, _ecou["flux"][i], dt)
	if _pompage >= 0:
		var jt: Jet = jets_pompe[_pompage]
		var po: Pompe = pompes[_pompage]
		var aq: Aqueduc = tuyaux_pompe[_pompage]
		var vers := int(N["pompes"][_pompage]["vers"])
		var force := clampf(minf(p * 6.0, (1.0 - p) * 3.0), 0.0, 1.0)
		jt.force = force
		jt.sens = -1.0
		jt.fente = 7.0
		jt.depart_x = po.bec().x + 1.0
		jt.origine = po.bec()
		jt.y_seuil = 0.0
		jt.haut_veine = 0.0
		jt.surface_bas = minf(eaux[vers].hauteur_a(po.bec().x - 14.0), eaux[vers].fond_y)
		aq.ouverte = force > 0.05
		aq.couler(force * 0.8, 1)
		aq.bulles.global_position = aq.chemin[0]
		if force > 0.1:
			eaux[vers].remous = maxf(eaux[vers].remous, force * 0.5)
			if randf() < 0.4: eaux[vers].impulsion(jt.chute().x, randf_range(-0.3, 1.0) * force, 18.0)
	if _chauffe >= 0:
		# la chaudière boit : l'eau court dans son tuyau, la surface se creuse
		# un peu au-dessus de la crépine, la vapeur part par le sifflet
		var chf: Chaudiere = chaudieres[_chauffe]
		var tch: Aqueduc = tuyaux_chaudiere[_chauffe]
		var ibc := int(N["objets"][_chauffe]["bassin"])
		var fc := clampf(minf(p * 5.0, (1.0 - p) * 2.5), 0.0, 1.0)
		chf.force = fc
		tch.ouverte = fc > 0.05
		tch.couler(fc * 0.8, 1)
		if fc > 0.1 and randf() < 0.3:
			eaux[ibc].impulsion(tch.chemin[0].x - D.x * 0.5, 0.25 * fc, 40.0)
	for g in moulins:
		# la roue tourne avec l'eau qui passe, les sacs se remplissent
		# (la roue ne tourne que quand l'eau descend vers le bassin du moulin)
		var vers_droite := float(N["bassins"][g + 1]["fond"]) < float(N["bassins"][g]["fond"])
		var fm := float(_ecou["flux"][g]) * (1.0 if vers_droite else -1.0) if g < _ecou["flux"].size() else 0.0
		if fm > 0.01:
			moulins[g].vitesse = maxf(moulins[g].vitesse, 3.5 * clampf(minf(p * 6.0, (1.0 - p) * 2.0), 0.0, 1.0))
		if _mouture.size() == 2:
			moulins[g].moulu = lerpf(_mouture[0], _mouture[1], clampf(p * 1.2, 0.0, 1.0))
	for k in _vases:
		# la vase baisse pendant l'écoulement
		fonds_vus[dragues[k].ib] = lerpf(_vases[k][0], _vases[k][1], clampf(p * 1.5, 0.0, 1.0))
	if orage:
		# chaque coup, l'averse redouble puis retombe en bruine
		orage.averse = clampf(minf(p * 4.0, (1.0 - p) * 2.0), 0.0, 1.0)
	for k in _fontes:
		# le bloc rapetisse et son eau coule pendant tout l'écoulement
		var gl_: Glacon = glacons[k]
		gl_.reste = lerpf(_fontes[k][0], _fontes[k][1], clampf(p * 1.15, 0.0, 1.0))
		gl_.coule = clampf(minf(p * 6.0, (1.0 - p) * 3.0), 0.0, 1.0)
		if gl_.coule > 0.2 and randf() < 0.25:
			eaux[int(N["objets"][k]["bassin"])].impulsion(gl_.base.x - D.x * 0.5, randf_range(-0.4, 0.6) * gl_.coule, 20.0)
	if p >= 1.0:
		for k in _vases: fonds_vus[dragues[k].ib] = _vases[k][1]
		_vases = {}
		if orage: orage.averse = 0.0
		# le flotteur a atteint sa bague : il referme sa porte
		for g in _declenches:
			portes[g].entrouvrir(false)
			portes[g].manoeuvrer_vanne(false)
		_declenches = []
		for k in _siphons_apres:
			siphons[k].regler(_siphons_apres[k])
			siphons[k].tuyau.couler(0.0, 1)
		_siphons_apres = {}
		for k in _fontes:
			glacons[k].coule = 0.0
			glacons[k].reste = _fontes[k][1]
			if _fontes[k][1] <= 0.0: glacons[k].feu_cible = 0.22     # fondu : il ne reste que des braises
		_fontes = {}
		if _chauffe >= 0:
			chaudieres[_chauffe].force = 0.0
			tuyaux_chaudiere[_chauffe].ouverte = false
			tuyaux_chaudiere[_chauffe].couler(0.0, 1)
			_chauffe = -1
		if _pompage >= 0:
			jets_pompe[_pompage].force = 0.0
			tuyaux_pompe[_pompage].ouverte = false
			tuyaux_pompe[_pompage].couler(0.0, 1)
			_pompage = -1
		_ecou = {}
		for aq in aqueducs.values(): aq.couler(0.0, 1)
		for jt in jets.values(): jt.force = 0.0
		for jt in trop_pleins.values(): jt.force = 0.0
		for rg in rigoles.values(): rg.debit = 0.0
		ecoulement_fini.emit()

# L'eau qui passe par l'aqueduc d'une porte : elle court dans le conduit,
# creuse un peu la surface au-dessus de l'entrée, et bouillonne doucement au
# débouché, près du fond du bassin qui se remplit. La force suit Torricelli :
# le débit va comme la racine de la hauteur d'eau qui pousse.
func _aqueduc(i: int, flux: float, dt: float) -> void:
	var aq: Aqueduc = aqueducs[i]
	if absf(flux) <= 0.01:
		aq.couler(0.0, 1)
		return
	var sens := 1 if flux > 0 else -1
	var h := i if flux > 0 else i + 1
	var l := i + 1 if flux > 0 else i
	var s := float(N["liaisons"][i]["seuil"])
	var tete: float = vue_niv[h] - maxf(vue_niv[l], s)
	var tete0: float = maxf(_ecou["tetes"].get(i, 1.0), 0.05)
	var force := clampf(sqrt(maxf(tete, 0.0) / tete0), 0.0, 1.0)
	aq.couler(force if force > 0.03 else 0.0, sens)
	if force <= 0.03: return
	var recoit: Eau = eaux[l]
	var donne: Eau = eaux[h]
	var bouillon := Reglages.v("bouillon")
	recoit.remous = maxf(recoit.remous, force * 0.55 * minf(bouillon, 1.0))
	var sortie := aq.sortie()
	var entree := aq.entree()
	# au-dessus du débouché, la surface se soulève par bouffées
	if randf() < 0.5:
		recoit.impulsion(sortie.x + randf_range(-0.5, 0.5) * U, randf_range(-1.1, 0.4) * force * bouillon, 26.0)
	# au-dessus de l'entrée, elle se creuse un peu
	donne.impulsion(entree.x, 0.25 * force * dt * 60.0 * 0.1, 40.0)

# L'eau sous une porte simple entrouverte : une lame qui jaillit de la fente
# vers le côté bas, en cascade ou noyée. Même force que l'aqueduc
# (Torricelli). La surface d'en bas bouillonne où la lame tombe ; celle d'en
# haut se creuse un peu contre la porte.
func _jet(i: int, flux: float, dt: float) -> void:
	var jt: Jet = jets[i]
	var po: Porte = portes[i]
	if absf(flux) <= 0.01:
		jt.force = 0.0
		return
	var sens := 1.0 if flux > 0 else -1.0
	var h := i if flux > 0 else i + 1
	var l := i + 1 if flux > 0 else i
	var s := float(N["liaisons"][i]["seuil"])
	# La force suit la hauteur d'eau qui pousse, dans l'absolu (Torricelli,
	# pleine force à 1,5 unité). Rapportée à l'écart du DÉBUT du coup, elle
	# valait 1 dès qu'un bassin recoulait alors que les deux étaient égaux au
	# départ : une nappe pleine réapparaissait pour quelques gouttes (Vincent).
	var tete: float = vue_niv[h] - maxf(vue_niv[l], s)
	jt.force = clampf(sqrt(maxf(tete, 0.0) / 1.5), 0.0, 1.0)
	jt.sens = sens
	# L'épaisseur de la nappe : l'eau qui reste au-dessus du seuil en amont,
	# jamais plus que la fente. Elle s'amincit à mesure que le bassin d'en haut
	# se vide, jusqu'à rien quand il atteint le seuil (Vincent).
	jt.fente = minf(po.fente(), maxf(vue_niv[h] - s, 0.0) * UY)
	if jt.fente < 1.0: jt.force = 0.0
	# la fente : sous le vantail (au milieu de la porte en oblique, contre sa
	# face côté bas de profil)
	# L'eau sort sous la porte, glisse sur le dessus du bloc du seuil, et tombe
	# de son BORD dans le bassin d'en bas — partie du milieu de la porte, la
	# nappe tombait devant la face du bloc (Vincent : « la cascade est
	# décalée »).
	var x := X(gl[i][0] + gl[i][1]) * 0.5 if D != Vector2.ZERO else (X(gl[i][1]) - 9.0 if sens > 0 else X(gl[i][0]) + 9.0)
	var bord_x := X(gl[i][1]) if sens > 0 else X(gl[i][0])
	jt.depart_x = x
	# la veine sous le vantail : du bas de la porte (ou de la surface amont si
	# elle est plus basse) jusqu'au seuil, dans le plan du vantail
	jt.vantail_x = x - 5.0 if D != Vector2.ZERO else x
	jt.y_seuil = po.y_seuil
	jt.haut_veine = maxf(po.bas_y, minf(eaux[h].hauteur_a(x - sens * 30.0), eaux[h].fond_y))
	jt.origine = Vector2(bord_x, po.y_seuil - jt.fente * 0.4)
	jt.surface_bas = eaux[l].hauteur_a(x + sens * 60.0)
	jt.fond_bas = eaux[l].fond_y
	if jt.force <= 0.03: return
	var recoit: Eau = eaux[l]
	var bouillon := Reglages.v("bouillon")
	recoit.remous = maxf(recoit.remous, jt.force * 0.6 * minf(bouillon * 2.0, 1.0))
	if randf() < 0.5:
		recoit.impulsion(jt.chute().x + randf_range(-0.4, 0.4) * U, randf_range(-0.6, 1.2) * jt.force * bouillon * 2.0, 22.0)
	eaux[h].impulsion(x - sens * 20.0, 0.25 * jt.force * dt * 6.0, 40.0)

# L'eau qui file par la rigole : une lame qui sort de l'entaille, du côté
# haut, et retombe dans le bassin d'en bas ; son épaisseur suit l'eau qui
# reste au-dessus du fond de la rigole.
func _jet_rigole(i: int, flux: float, dt: float) -> void:
	var jt: Jet = jets[i]
	var rg: Rigole = rigoles[i]
	rg.debit = 0.0
	if absf(flux) <= 0.01:
		jt.force = 0.0
		return
	var sens := 1.0 if flux > 0 else -1.0
	var h := i if flux > 0 else i + 1
	var l := i + 1 if flux > 0 else i
	var crete := rg.vue
	var tete: float = vue_niv[h] - maxf(vue_niv[l], crete)
	jt.force = clampf(sqrt(maxf(tete, 0.0) / 1.5), 0.0, 1.0)
	jt.sens = sens
	jt.fente = minf(maxf(vue_niv[h] - crete, 0.0) * UY, 26.0)
	if jt.fente < 1.0: jt.force = 0.0
	rg.debit = jt.force
	var bord_x := X(gl[i][1]) if sens > 0 else X(gl[i][0])
	jt.depart_x = bord_x + 1.0          # la rigole elle-même dessine l'eau qui la descend
	# elle tombe de la bouche de la rigole, au bord du canal (le filet est
	# déjà placé à sa profondeur)
	jt.fente = minf(jt.fente * Rigole.ECHELLE + 3.0, 14.0)
	jt.origine = rg.surface_bouche()
	jt.vantail_x = jt.depart_x
	jt.y_seuil = 0.0
	jt.haut_veine = 0.0
	jt.surface_bas = eaux[l].hauteur_a(bord_x + sens * 60.0)
	if jt.force <= 0.03: return
	eaux[l].remous = maxf(eaux[l].remous, jt.force * 0.5)
	if randf() < 0.5:
		eaux[l].impulsion(jt.chute().x, randf_range(-0.5, 1.0) * jt.force * Reglages.v("bouillon") * 2.0, 20.0)

# Une porte fermée : ni levée, ni entrouverte, ni vanne ouverte.
func _porte_close(g: int) -> bool:
	var po: Porte = portes[g]
	return not po._leve and not po._entrouvert and not (po.a_vanne and po.vanne_ouverte)

# L'écoulement de ce coup passe-t-il par-dessus la crête de la porte g ? (un
# des deux côtés atteint la crête à l'arrivée)
func _deborde(g: int) -> bool:
	var crete := float(N["liaisons"][g]["crete"])
	return maxf(float(_ecou["apres"][g]), float(_ecou["apres"][g + 1])) >= crete - 1e-6

# La nappe qui passe par-dessus le vantail fermé : de la crête, sur toute la
# largeur du canal, jusqu'à l'eau d'en bas ; tant que le bassin d'en bas monte.
func _trop_plein(g: int, flux: float) -> void:
	var jt: Jet = trop_pleins[g]
	var sens := 1.0 if flux > 0 else -1.0
	var l := g + 1 if flux > 0 else g
	# Visible tant que le bassin d'en bas monte ; ou, s'il ne monte pas du tout
	# (l'eau y passe et repart, par exemple par une porte ouverte vers le
	# bassin d'où la pompe la reprend), pendant tout l'écoulement — sinon le
	# trop-plein ne se voyait que dans un cas sur deux (Vincent).
	var reste: float = float(_ecou["apres"][l]) - vue_niv[l]
	var circule: bool = absf(float(_ecou["apres"][l]) - float(_ecou["avant"][l])) < 1e-4
	var p := clampf(float(_ecou["t"]) / float(_ecou["T"]), 0.0, 1.0)
	if (not circule and reste < 0.003) or (circule and p > 0.92):
		jt.force = 0.0
		return
	var crete := float(N["liaisons"][g]["crete"])
	var xc := X(gl[g][0] + gl[g][1]) * 0.5
	# contre la face aval du vantail, et presque droite : sur le plan de
	# devant, elle reste derrière le pilier avant, qu'elle ne doit pas
	# dépasser ; on la voit en profondeur, le long du vantail
	jt.force = 0.3
	jt.sens = sens
	jt.fente = 8.0
	jt.depart_x = xc - 5.0 + 1.0
	jt.origine = Vector2(xc - 5.0 + sens * 3.0, Y(crete) - 4.0)
	jt.vantail_x = xc
	jt.y_seuil = 0.0
	jt.haut_veine = 0.0
	jt.surface_bas = minf(eaux[l].hauteur_a(xc + sens * 50.0), eaux[l].fond_y)
	eaux[l].remous = maxf(eaux[l].remous, 0.4)

# L'eau sur une levée noyée : la coupe (de la crête à la surface, au moins
# 5 px pour qu'on la voie) et sa surface vue d'en haut, de bord à bord. Elle
# apparaît en fondu dès que les deux eaux dépassent la crête.
func _dessiner_levee_noyee(i: int, n: Node2D) -> void:
	var crete := float(N["liaisons"][i]["crete"])
	var dessus := minf(vue_niv[i], vue_niv[i + 1]) - crete
	if dessus <= 0.0: return
	var a := clampf(dessus / 0.01, 0.0, 1.0)
	# exactement entre les deux eaux, à leur hauteur, aux mêmes couleurs que
	# leurs surfaces : décalée ou plus claire, elle passait pour une planche
	# posée au bord du bassin (Vincent)
	var x0 := X(gl[i][0])
	var x1 := X(gl[i][1])
	var yg: float = eaux[i].hauteur_a(eaux[i].x1)
	var yd: float = eaux[i + 1].hauteur_a(eaux[i + 1].x0)
	if D != Vector2.ZERO:
		var av := Color(0.17, 0.6, 0.78, 0.78 * a)
		var mi := Color(0.34, 0.76, 0.88, 0.78 * a)
		var fo := Color(0.64, 0.88, 0.95, 0.96 * a)
		n.draw_polygon(PackedVector2Array([Vector2(x0, yg), Vector2(x1, yd), Vector2(x1, yd) + D * 0.5, Vector2(x0, yg) + D * 0.5]), PackedColorArray([av, av, mi, mi]))
		n.draw_polygon(PackedVector2Array([Vector2(x0, yg) + D * 0.5, Vector2(x1, yd) + D * 0.5, Vector2(x1, yd) + D, Vector2(x0, yg) + D]), PackedColorArray([mi, mi, fo, fo]))

# L'eau qui franchit une levée : une nappe sur toute la largeur, de la crête
# jusqu'au pré d'en bas.
func _jet_mur(i: int, flux: float, dt: float) -> void:
	var jt: Jet = jets[i]
	if absf(flux) <= 0.01:
		jt.force = 0.0
		return
	var sens := 1.0 if flux > 0 else -1.0
	var h := i if flux > 0 else i + 1
	var l := i + 1 if flux > 0 else i
	var crete := float(N["liaisons"][i]["crete"])
	# Les niveaux affichés glissent chacun de leur départ à leur arrivée : le
	# village monte pendant que le bief, lui, n'a pas encore atteint la crête.
	# La nappe suit donc l'eau qui passera (l'arrivée du bief au-dessus de la
	# crête) tant que le village n'a pas fini de monter.
	var dessus := maxf(float(_ecou["apres"][h]) - crete, maxf(vue_niv[h] - crete, 0.0))
	var reste: float = float(_ecou["apres"][l]) - vue_niv[l]
	if dessus < 0.005 or reste < 0.003:
		jt.force = 0.0
		return
	# il en faut peu pour inonder un village : la nappe reste bien visible
	# même pour quelques centimètres d'eau (6 px et demi-force au moins)
	jt.force = clampf(maxf(sqrt(dessus / 0.6), 0.55), 0.0, 1.0)
	jt.sens = sens
	jt.fente = clampf(dessus * UY, 6.0, 18.0)
	var bord_x := X(gl[i][1]) + 0.15 * U if sens > 0 else X(gl[i][0]) - 0.15 * U
	jt.depart_x = X(gl[i][1]) if sens < 0 else X(gl[i][0])
	jt.origine = Vector2(bord_x, Y(crete) - jt.fente * 0.5)
	jt.vantail_x = jt.depart_x
	jt.y_seuil = 0.0
	jt.haut_veine = 0.0
	jt.surface_bas = minf(eaux[l].hauteur_a(bord_x + sens * 50.0), eaux[l].fond_y)
	eaux[l].remous = maxf(eaux[l].remous, jt.force * 0.5)

# Un coup de pompe : le levier, puis l'eau pendant l'écoulement qui suit.
func pomper(i: int) -> void:
	_pompage = i
	pompes[i].pomper()
	await pompes[i].coup_fini

# Les siphons : un tuyau en U renversé, de sa crépine dans un bassin à sa
# crépine dans l'autre, par-dessus tout ce qui est entre eux. L'arche passe
# une unité au-dessus de la plus haute crête qu'elle enjambe, sur la berge du
# fond, derrière les tours des portes ; la roue d'amorçage est au-dessus de
# la première liaison enjambée.
func _bout_siphon(ib: int, crepine: float, vers_droite: bool) -> Vector2:
	if mares.has(ib):
		var m: Mare = mares[ib]
		return Vector2(m.cx + m.rx * (0.45 if vers_droite else -0.45), m.y_rive) + D * 1.15
	var xb := _x_bassin(ib)
	var x := lerpf(xb.x, xb.y, 0.62 if vers_droite else 0.38) if N["bassins"][ib]["type"] != "sas" else lerpf(xb.x, xb.y, 0.5)
	return Vector2(x, Y(crepine)) + D

func _construire_siphons(e: Dictionary) -> void:
	var objets: Array = N.get("objets", [])
	var r: int = N["liaisons"].size()
	for k in objets.size():
		if objets[k]["type"] != "siphon": continue
		_rang_siphon[k] = r
		r += 1
		var o: Dictionary = objets[k]
		var ia := int(o["a"])
		var ib := int(o["b"])
		var g := mini(ia, ib)
		var d := maxi(ia, ib)
		var haut_ := berge
		for j in range(g, d):
			var l: Dictionary = N["liaisons"][j]
			haut_ = maxf(haut_, float(l.get("crete", 0.0)) + 0.6)
		var y_arche := Y(haut_ + 0.4) + D.y
		var pa := _bout_siphon(ia, float(o["ha"]), ia < ib)
		var pb := _bout_siphon(ib, float(o["hb"]), ib < ia)
		var chemin := PackedVector2Array([pa, Vector2(pa.x, y_arche), Vector2(pb.x, y_arche), pb])
		var xs := X(gl[g][0] + gl[g][1]) * 0.5 + D.x
		var sp := Siphon.new()
		sp.preparer(self, k, chemin, Vector2(xs, y_arche - 0.16 * UY), int(e["obj"][k]) == 1)
		# des poteaux tous les 2,3 unités environ, sur la berge du fond des
		# bassins de pierre (pas sur une porte, ni au-dessus de la mare)
		var xp := minf(pa.x, pb.x) + 1.2 * U
		while xp < maxf(pa.x, pb.x) - 0.8 * U:
			var x_coupe := xp - D.x
			var ib_ := bassin_sous(x_coupe)
			var sur_bassin := x_coupe > X(gb[ib_][0]) + 10.0 and x_coupe < X(gb[ib_][1]) - 10.0
			if sur_bassin and not _naturel(ib_) and absf(xp - xs) > 0.6 * U:
				sp.poteaux.append([xp, y_arche + 0.16 * UY, Y(sommets_fond[ib_]) + D.y + 2.0])
			xp += 2.3 * U
		_cible_arriere.add_child(sp)
		add_child(sp.roue)
		siphons[k] = sp

# Un voyage du bac : le quai ouvert se ferme, le bac monte ou descend avec
# son eau et son bateau (le treuil tourne, les contrepoids filent à l'envers),
# puis le quai d'arrivée s'entrouvre ; l'écoulement qui suit égalise l'eau du
# bac et celle du bief, et le vantail se lève quand elles sont égales.
func voyage_bac(k: int, avant: Dictionary, apres: Dictionary) -> void:
	var bc: Bac = bacs[k]
	var ib := bc.ib
	for q in [ib - 1, ib]:
		portes[q].entrouvrir(false)
		portes[q].placer_vantail(false)
		portes[q].vanne_ouverte = false
	var bouge := true
	while bouge:
		await get_tree().process_frame
		bouge = portes[ib - 1].arrive() == false or portes[ib].arrive() == false
	var f0 := Moteur.fond_de(N, avant, ib)
	var f1 := Moteur.fond_de(N, apres, ib)
	var n0: float = vue_niv[ib]
	var T := 1.2 + 0.35 * absf(f1 - f0)
	var t := 0.0
	while t < T:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t = minf(t + dt, T)
		var p := t / T
		var lisse := p * p * (3.0 - 2.0 * p)
		var avant_f: float = fonds_vus[ib]
		fonds_vus[ib] = lerpf(f0, f1, lisse)
		vue_niv[ib] = n0 + (fonds_vus[ib] - f0)
		bc.tourner((fonds_vus[ib] - avant_f) * 2.2)
	# le quai d'arrivée s'entrouvre : l'eau passe dessous si elle n'est pas au
	# même niveau
	var q := ib - 1 if f1 < f0 else ib
	portes[q].vanne_ouverte = true
	portes[q].entrouvrir(true)

# Amorcer : la roue tourne, le tuyau se remplit.
func amorcer(k: int) -> void:
	siphons[k].regler(true)
	await get_tree().create_timer(0.45).timeout

func siphon_sous(p: Vector2) -> int:
	for k in siphons:
		if siphons[k].sous(p): return k
	return -1

func bac_sous(p: Vector2) -> int:
	for k in bacs:
		if bacs[k].sous(p): return k
	return -1

# Le brasero d'un glaçon s'allume (le coup lui-même verse la première part).
func allumer(i: int) -> void:
	glacons[i].allumer()
	await glacons[i].allume_fini

func glacon_sous(p: Vector2) -> int:
	for i in glacons:
		if glacons[i].sous(p): return i
	return -1

# Avant l'écoulement d'un coup : les glaçons qui fondent pendant ce coup-ci.
func objets_changent(avant: Dictionary, apres: Dictionary) -> void:
	for k in dragues:
		if int(avant["obj"][k]) != int(apres["obj"][k]):
			_vases[k] = [Moteur.fond_de(N, avant, dragues[k].ib), Moteur.fond_de(N, apres, dragues[k].ib)]
			dragues[k].godets = int(apres["obj"][k])
	# le castor a remonté sa digue : la rigole se rebouche
	for g in rigoles:
		if rigoles[g].castor and apres["crete"][g] != null: rigoles[g].regler(float(apres["crete"][g]))
	_mouture = [float(avant.get("moulu", 0.0)), float(apres.get("moulu", 0.0))]
	_declenches = []
	for g in flotteurs:
		if bool(avant["ouvert"][g]) and not bool(apres["ouvert"][g]) and int(apres["coups"]) > int(avant["coups"]): _declenches.append(g)
	for k in siphons:
		# désamorcé pendant le coup : le tuyau reste plein tant que l'eau
		# coule, et se vide une fois l'eau posée
		_siphons_apres[k] = int(apres["obj"][k]) == 1
	for i in marees: marees[i].regler(int(apres["phase"]), int(apres["coups"]))
	for k in glacons:
		var a := int(avant["obj"][k])
		var b := int(apres["obj"][k])
		if a == b: continue
		var f := float(N["objets"][k]["fonte"])
		_fontes[k] = [1.0 if a < 0 else a / f, b / f]

# Un coup de drague : la benne descend dans l'eau (la vase baisse ensuite,
# pendant l'écoulement).
func draguer(i: int) -> void:
	dragues[i].draguer()
	await dragues[i].coup_fini

func drague_sous(p: Vector2) -> int:
	for i in dragues:
		if dragues[i].sous(p): return i
	return -1

# Un coup de chaudière : le feu flambe, puis l'eau part pendant l'écoulement.
func chauffer(i: int) -> void:
	_chauffe = i
	chaudieres[i].chauffer()
	await chaudieres[i].coup_fini

func chaudiere_sous(p: Vector2) -> int:
	for i in chaudieres:
		if chaudieres[i].sous(p): return i
	return -1

func pompe_sous(p: Vector2) -> int:
	for i in pompes:
		if pompes[i].sous(p): return i
	return -1

# La berge de terre sous le doigt (une rigole), ou -1.
func rigole_sous(p: Vector2) -> int:
	for i in rigoles:
		if rigoles[i].sous(p): return i
	return -1

# Les bateaux : un tour de déplacements après l'autre, comme le moteur les a rendus.
func deplacer(dep: Array) -> void:
	if dep.is_empty():
		bateaux_arrives.emit.call_deferred()
		return
	# Des étapes à l'écran : les mouvements d'un même tour du moteur partent
	# ensemble, sauf deux qui passent la même porte — dans le moteur, l'un sort
	# du sas avant que l'autre y entre ; à l'écran, ils se croiseraient.
	var etapes := []
	var courante := []
	var tour := -1
	for d in dep:
		var porte_d := mini(int(d["de"]), int(d["vers"]))
		var conflit := courante.any(func(x): return mini(int(x["de"]), int(x["vers"])) == porte_d or x["k"] == d["k"])
		if int(d["tour"]) != tour or conflit:
			if not courante.is_empty(): etapes.append(courante)
			courante = []
			tour = int(d["tour"])
		courante.append(d)
	etapes.append(courante)
	_depl = {"tours": etapes, "rang": -1, "t": 0.0, "D": 1.35, "mouvements": []}
	_tour_suivant()

func _tour_suivant() -> void:
	_depl["rang"] += 1
	if _depl["rang"] >= _depl["tours"].size():
		_depl = {}
		bateaux_arrives.emit()
		return
	var apres := positions.duplicate()
	for d in _depl["tours"][_depl["rang"]]: apres[int(d["k"])] = int(d["vers"])
	# tous les bateaux vont à leur nouvelle place : ceux qui changent de bassin,
	# et ceux qui se poussent pour leur faire de la place
	var mvt := []
	var bougent := {}
	for d in _depl["tours"][_depl["rang"]]: bougent[int(d["k"])] = true
	for k in bateaux.size():
		mvt.append({"k": k, "xa": bat_x[k], "xb": place(int(apres[k]), "b%d" % k, apres), "vers": int(apres[k]), "passe": bougent.has(k)})
		# dessiné avant les autres bateaux : il passe derrière eux, pas derrière le décor
		if bougent.has(k): bateaux[k].get_parent().move_child(bateaux[k], 0)
	_depl["mouvements"] = mvt
	_depl["apres"] = apres
	_depl["t"] = 0.0

func _avancer_bateaux(dt: float) -> void:
	_depl["t"] += dt
	var p := clampf(_depl["t"] / _depl["D"], 0.0, 1.0)
	var e := ease(p, -1.8)
	for m in _depl["mouvements"]:
		var k: int = m["k"]
		var avant: float = bat_x[k]
		bat_x[k] = lerpf(m["xa"], m["xb"], e)
		var vitesse: float = (bat_x[k] - avant) / maxf(dt, 1e-3)
		# celui qui change de bassin passe derrière les autres, comme plus loin de nous
		var loin := sin(p * PI) if m["passe"] else 0.0
		bateaux[k].scale = Vector2.ONE * (1.0 - 0.07 * loin)
		bateaux[k].modulate = Color(1, 1, 1).darkened(0.12 * loin)
		# le sillage : la poupe pousse l'eau
		var poupe: float = bat_x[k] - signf(vitesse) * bateaux[k].longueur * 0.45
		var i := bassin_sous(poupe)
		var sillage := Reglages.v("sillage")
		eaux[i].impulsion(poupe, absf(vitesse) * 0.0045 * sillage, 34.0)
		eaux[i].impulsion(bat_x[k] + signf(vitesse) * bateaux[k].longueur * 0.55, -absf(vitesse) * 0.002 * sillage, 28.0)
		if p >= 0.5: positions[k] = m["vers"]
	if p >= 1.0:
		positions = _depl["apres"].duplicate()
		_tour_suivant()

func _poser_bateaux(dt := 1.0) -> void:
	for k in bateaux.size():
		var bt: Bateau = bateaux[k]
		var x: float = bat_x[k]
		var demi := bt.longueur * 0.4
		var i := bassin_sous(x)
		var f := fond_vu(i)
		var echoue_y := Y(f) - bt.tirant          # ligne de flottaison d'une coque posée au fond
		var ya := minf(surface_a(x - demi), echoue_y)
		var yb := minf(surface_a(x + demi), echoue_y)
		var echoue := surface_a(x) > echoue_y + 1.0
		bt.position = Vector2(x, (ya + yb) * 0.5 + (2.0 if not echoue else 0.0))
		# le bateau s'incline en douceur : il ne suit pas chaque ride au coup par coup
		var cible := clampf(atan2(yb - ya, 2.0 * demi) * 0.8, -0.12, 0.12) + (0.11 * bt.sens if echoue else 0.0)
		bt.rotation = lerp_angle(bt.rotation, cible, minf(1.0, dt * 4.0))
		bt.queue_redraw()

# --- Les repères : la place où chaque bateau doit finir, et les « ! » --------------------
# Un bateau coincé (plus d'eau, ou plus moyen de passer) : un point
# d'exclamation rouge surgit au-dessus de lui, rebondit, lance de petits
# éclats, puis bat doucement — comme sur la maquette du niveau 47.
func alerter(bateaux_coinces: Array) -> void:
	for k in bateaux_coinces: alertes[k] = _t

# Quand c'est l'eau qui manque : le niveau qu'il faudrait dans ce bassin pour
# porter le bateau k, en pointillés à sa couleur, la bande d'eau manquante
# hachurée, et « Il manque de l'eau » écrit au-dessus. Effacé quand on
# reconstruit la coupe (annuler, rejouer).
var _manque := {}
func signaler_manque(bassin: int, niveau: float, k: int, trop := false) -> void:
	_manque = {"bassin": bassin, "y": Y(niveau), "couleur": COULEURS[k % COULEURS.size()], "t": _t, "k": k, "trop": trop}

func manque_signale() -> bool:
	return not _manque.is_empty()

func _dessiner_manque() -> void:
	if not _manque.is_empty():
		_tracer_manque(int(_manque["bassin"]), float(_manque["y"]), _manque["couleur"], _t - float(_manque["t"]), int(_manque.get("k", -1)), bool(_manque.get("trop", false)))
	# Un bateau à sa place mais échoué : pour le jeu, il n'est pas arrivé (il
	# faut qu'il flotte). Rien ne le disait, et Vincent croyait le niveau fini
	# sans que rien ne se passe. On montre le niveau qu'il lui faut, comme pour
	# un échec, tant que la partie continue.
	for k in N["bateaux"].size():
		var v := int(N["bateaux"][k]["vers"])
		if positions[k] != v or _a_flot(k, v) or (not _manque.is_empty() and int(_manque["bassin"]) == v): continue
		if not _echoues_a_quai.has(k): _echoues_a_quai[k] = _t
		_tracer_manque(v, Y(fond_vu(v) + float(N["bateaux"][k]["tirant"])), COULEURS[k % COULEURS.size()], _t - float(_echoues_a_quai[k]), k)
	for k in _indices:
		var d: Dictionary = _indices[k]
		_tracer_manque(int(d["bassin"]), float(d["y"]), COULEURS[k % COULEURS.size()], _t - float(d["t"]), k, bool(d.get("trop", false)), not _bulles.has(k))
	for k in _echoues_a_quai.keys():
		var v2 := int(N["bateaux"][k]["vers"])
		if positions[k] != v2 or _a_flot(k, v2): _echoues_a_quai.erase(k)

var _echoues_a_quai := {}   # bateau -> l'instant où on l'a vu échoué à sa place
# Les indices : un bateau arrêté devant une porte ouverte, eaux égales, faute
# de fond (Vincent : « on a l'impression que le bateau peut avancer »).
# principal.gd les pose après 5 s sans coup ; le prochain coup les efface.
var _indices := {}   # bateau -> {bassin, y, t, trop}
# « trop » : il y a TROP d'eau (un pont bas) — la flèche de la bulle monte,
# et la bande teintée est celle de l'eau en trop.
func indiquer_manque(k: int, bassin: int, niveau: float, trop := false) -> void:
	if not _indices.has(k): _indices[k] = {"bassin": bassin, "y": Y(niveau), "t": _t, "trop": trop}

func effacer_indices() -> void:
	_indices.clear()
func _a_flot(k: int, i: int) -> bool:
	return vue_niv[i] - fond_vu(i) >= float(N["bateaux"][k]["tirant"]) - 1e-6

# Le fond affiché d'un bassin : celui du niveau, ou celui du bac d'un
# ascenseur, ou le dessus de la vase.
func fond_vu(i: int) -> float:
	return float(fonds_vus.get(i, float(N["bassins"][i]["fond"])))

# Le niveau qu'il faudrait, en pointillés à la couleur du bateau, une bande
# d'eau qui manque à peine teintée, et une BULLE sans texte au-dessus du
# bateau (Vincent : « évitons du texte, cela doit être enfantin ») : une
# goutte, une flèche rouge vers le bas, des tirets — il manque de l'eau.
func _tracer_manque(i: int, y: float, c: Color, age: float, k := -1, trop := false, bulle := true) -> void:
	var xb := _x_bassin(i)                 # en oblique, l'eau va jusqu'aux vantaux
	var x0 := xb.x + 4.0
	var x1 := xb.y - 4.0
	var a := clampf(age / 0.4, 0.0, 1.0)
	var surface := surface_a((x0 + x1) * 0.5)
	if surface > y + 1.0:
		_reperes.draw_rect(Rect2(x0, y, x1 - x0, surface - y), Color(c, 0.12 * a))
	if trop and surface < y - 1.0:
		# l'eau en trop, au-dessus du niveau qu'il faudrait
		_reperes.draw_rect(Rect2(x0, surface, x1 - x0, y - surface), Color(c, 0.16 * a))
	_reperes.draw_dashed_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.9 * a), 7.0, 14.0)
	_reperes.draw_dashed_line(Vector2(x0, y), Vector2(x1, y), Color(c, a), 4.0, 14.0)
	# (la bulle des raisons dit déjà « il manque de l'eau » au-dessus du bateau)
	if not bulle: return
	# la bulle, au-dessus du bateau (ou au milieu du bassin), qui surgit puis
	# flotte doucement
	var bx: float = bat_x[k] if k >= 0 and k < bat_x.size() else (x0 + x1) * 0.5
	var t := clampf(age / 0.3, 0.0, 1.0)
	var u := t - 1.0
	var sc := 1.0 + 2.7 * u * u * u + 1.7 * u * u
	if sc <= 0.01: return
	var centre := Vector2(bx + 18.0, y - 44.0 + 2.5 * sin(age * 2.6))
	var w := 62.0 * sc
	var h := 50.0 * sc
	var r := Rect2(centre - Vector2(w, h) * 0.5, Vector2(w, h))
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#fff3dc")
	st.border_color = Color("#5b3416")
	st.set_border_width_all(3)
	st.set_corner_radius_all(int(14 * sc))
	st.shadow_color = Color(0, 0, 0, 0.2); st.shadow_size = 4; st.shadow_offset = Vector2(1, 2)
	st.anti_aliasing = true
	# la queue de la bulle, vers le bateau
	var q0 := Vector2(r.position.x + w * 0.22, r.end.y - 2.0)
	var q1 := Vector2(r.position.x + w * 0.44, r.end.y - 2.0)
	var q2 := Vector2(bx - 4.0, r.end.y + 14.0 * sc)
	_reperes.draw_colored_polygon(PackedVector2Array([q0 + Vector2(-2, 0), q2 + Vector2(-1, 2), q1 + Vector2(2, 0)]), Color("#5b3416"))
	st.draw(_reperes.get_canvas_item(), r)
	_reperes.draw_colored_polygon(PackedVector2Array([q0 + Vector2(1, -3), q2, q1 + Vector2(-1, -3)]), Color("#fff3dc"))
	# la goutte
	var g := centre + Vector2(-w * 0.17, -h * 0.02)
	var gr := 9.0 * sc
	var goutte := PackedVector2Array()
	for j in 21:
		var an := PI * j / 20.0
		goutte.append(g + Vector2(cos(an) * gr, sin(an) * gr))
	goutte.append(g + Vector2(0, -gr * 2.1))
	_reperes.draw_colored_polygon(goutte, Color("#2f8fd8"))
	_reperes.draw_polyline(goutte + PackedVector2Array([goutte[0]]), Color("#1d5c94"), 1.5, true)
	_reperes.draw_circle(g + Vector2(-gr * 0.35, -gr * 0.1), gr * 0.25, Color(1, 1, 1, 0.7))
	# la flèche rouge vers le bas (il manque de l'eau) ou vers le haut (il y en
	# a trop : un pont bas)
	var f := centre + Vector2(w * 0.2, -h * 0.12)
	var sg := -1.0 if trop else 1.0
	var fy := 0.0 if not trop else 2.0
	_reperes.draw_line(f + Vector2(0, (-9 * sg + fy) * sc), f + Vector2(0, (3 * sg + fy) * sc), Color("#d9412d"), 4.0 * sc, true)
	_reperes.draw_colored_polygon(PackedVector2Array([f + Vector2(-7, 2 * sg + fy) * sc, f + Vector2(7, 2 * sg + fy) * sc, f + Vector2(0, 11 * sg + fy) * sc]), Color("#d9412d"))
	# les tirets du niveau, sous la goutte et la flèche
	for j in 3:
		var dx := (-0.32 + 0.24 * j) * w
		_reperes.draw_line(centre + Vector2(dx, h * 0.3), centre + Vector2(dx + w * 0.15, h * 0.3), Color("#5b3416"), 3.0 * sc, true)

func _exclamation(c: Vector2, age: float) -> void:
	var t := clampf(age / 0.32, 0.0, 1.0)
	var u := t - 1.0
	var s := 1.0 + 2.7 * u * u * u + 1.7 * u * u        # surgit en dépassant un peu, puis se pose
	if age > 0.32: s = 1.0 + 0.06 * sin((age - 0.32) * 6.0)
	if s <= 0.01: return
	var h := 40.0 * s
	var w := 13.0 * s
	var barre := PackedVector2Array([c + Vector2(-w * 0.62, -h), c + Vector2(w * 0.62, -h),
		c + Vector2(w * 0.34, -h * 0.34), c + Vector2(-w * 0.34, -h * 0.34)])
	var tour := PackedVector2Array()
	var centre := c + Vector2(0, -h * 0.66)
	for p in barre: tour.append(centre + (p - centre) * 1.32)
	# une bulle crème cerclée de brun, comme les plaques de l'interface : seul
	# sur le décor, le « ! » faisait pictogramme provisoire (analyse graphique)
	var bulle := c + Vector2(0, -h * 0.5)
	_reperes.draw_circle(bulle + Vector2(1.5, 2.5), h * 0.74, Color(0, 0, 0, 0.18))
	_reperes.draw_circle(bulle, h * 0.74, Color("#5b3416"))
	_reperes.draw_circle(bulle, h * 0.74 - 3.0, Color("#fff3dc"))
	_reperes.draw_colored_polygon(tour, Color.WHITE)
	_reperes.draw_circle(c + Vector2(0, -h * 0.1), w * 0.62, Color.WHITE)
	_reperes.draw_colored_polygon(barre, Color("#e2332a"))
	_reperes.draw_circle(c + Vector2(0, -h * 0.1), w * 0.44, Color("#e2332a"))
	# les éclats, de part et d'autre
	if age > 0.12:
		var a := clampf((age - 0.12) / 0.2, 0.0, 1.0) * (0.75 + 0.25 * sin(age * 7.0))
		for cote in [-1.0, 1.0]:
			for j in 3:
				var ang := deg_to_rad(-35.0 + j * 35.0)
				var d := Vector2(cos(ang) * cote, sin(ang))
				var o := c + Vector2(cote * w * 1.1, -h * 0.62)
				_reperes.draw_line(o + d * 6.0 * s, o + d * 15.0 * s, Color(1.0, 0.68, 0.12, a), 3.0, true)

# --- Les bulles des bateaux (9 octobre 2026) -------------------------------------------
# Tant que la partie attend le joueur, chaque bateau qui n'est pas arrivé dit
# dans une bulle, sans un mot, ce qui le retient : « porte » (une roue rouge et
# sa flèche : touche-la), « eau » (une goutte et une flèche vers le bas : il
# manque de l'eau), « trop » (flèche vers le haut : le pont bas), « plein »
# (un autre bateau : la place est prise), « niveaux » (deux eaux inégales) ;
# avec des bateaux au doigt, « passe » (une flèche verte : touche-moi, je peux
# avancer). Le joueur les donne (principal.gd, Moteur.raison) ; toucher un
# bateau refait surgir sa bulle.
var _bulles := {}       # bateau -> [quoi, instant d'apparition]
func montrer_raisons(r: Dictionary) -> void:
	for k in _bulles.keys():
		if not r.has(k) or r[k] != _bulles[k][0]: _bulles.erase(k)
	for k in r:
		if not _bulles.has(k): _bulles[k] = [r[k], _t]

func relancer_bulle(k: int) -> void:
	if _bulles.has(k): _bulles[k][1] = _t

func refuser_bateau(k: int) -> void:
	bateaux[k].refuser()
	relancer_bulle(k)

func bateau_sous(p: Vector2) -> int:
	for k in bateaux.size():
		var bt: Bateau = bateaux[k]
		var c := bt.global_position
		if Rect2(c.x - bt.longueur * 0.62, c.y - bt.longueur * 0.85, bt.longueur * 1.24, bt.longueur * 1.1).has_point(p): return k
	return -1

# Un toucher : un rond qui s'élargit sous le doigt (l'enfant voit qu'il a été
# entendu, même quand rien ne peut se passer).
var _ondes := []
func onde(p: Vector2) -> void:
	_ondes.append([p, _t])

func _dessiner_bulles() -> void:
	for k in _bulles:
		var bt: Bateau = bateaux[k]
		var age: float = _t - float(_bulles[k][1])
		var centre := bt.position + Vector2(22.0, -bt.longueur * 0.78 - 18.0)
		_bulle(centre, bt.position.x - 4.0, bt.position.y - bt.longueur * 0.5, age, String(_bulles[k][0]), COULEURS[k % COULEURS.size()])

# Une bulle crème cerclée de brun, sa queue vers le bateau, qui surgit en
# dépassant puis flotte doucement, et son pictogramme.
func _bulle(c0: Vector2, x_queue: float, y_queue: float, age: float, quoi: String, couleur: Color) -> void:
	var t := clampf(age / 0.3, 0.0, 1.0)
	var u := t - 1.0
	var sc := 1.0 + 2.7 * u * u * u + 1.7 * u * u
	if sc <= 0.01: return
	var centre := c0 + Vector2(0, 2.5 * sin(age * 2.6))
	var w := 62.0 * sc
	var h := 50.0 * sc
	var r := Rect2(centre - Vector2(w, h) * 0.5, Vector2(w, h))
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#fff3dc")
	st.border_color = Color("#5b3416")
	st.set_border_width_all(3)
	st.set_corner_radius_all(int(14 * sc))
	st.shadow_color = Color(0, 0, 0, 0.2); st.shadow_size = 4; st.shadow_offset = Vector2(1, 2)
	st.anti_aliasing = true
	var q0 := Vector2(r.position.x + w * 0.22, r.end.y - 2.0)
	var q1 := Vector2(r.position.x + w * 0.44, r.end.y - 2.0)
	var q2 := Vector2(x_queue, minf(r.end.y + 14.0 * sc, y_queue))
	_reperes.draw_colored_polygon(PackedVector2Array([q0 + Vector2(-2, 0), q2 + Vector2(-1, 2), q1 + Vector2(2, 0)]), Color("#5b3416"))
	st.draw(_reperes.get_canvas_item(), r)
	_reperes.draw_colored_polygon(PackedVector2Array([q0 + Vector2(1, -3), q2, q1 + Vector2(-1, -3)]), Color("#fff3dc"))
	match quoi:
		"eau", "trop": _icone_eau(centre, w, h, sc, quoi == "trop")
		"porte": _icone_roue(centre, sc, age)
		"plein": _icone_plein(centre, sc, couleur)
		"passe": _icone_passe(centre, sc, age, couleur)
		"niveaux": _icone_niveaux(centre, sc)

func _icone_eau(centre: Vector2, w: float, h: float, sc: float, trop: bool) -> void:
	var g := centre + Vector2(-w * 0.17, -h * 0.02)
	var gr := 9.0 * sc
	var goutte := PackedVector2Array()
	for j in 21:
		var an := PI * j / 20.0
		goutte.append(g + Vector2(cos(an) * gr, sin(an) * gr))
	goutte.append(g + Vector2(0, -gr * 2.1))
	_reperes.draw_colored_polygon(goutte, Color("#2f8fd8"))
	_reperes.draw_polyline(goutte + PackedVector2Array([goutte[0]]), Color("#1d5c94"), 1.5, true)
	_reperes.draw_circle(g + Vector2(-gr * 0.35, -gr * 0.1), gr * 0.25, Color(1, 1, 1, 0.7))
	var f := centre + Vector2(w * 0.2, -h * 0.12)
	var sg := -1.0 if trop else 1.0
	var fy := 2.0 if trop else 0.0
	_reperes.draw_line(f + Vector2(0, (-9 * sg + fy) * sc), f + Vector2(0, (3 * sg + fy) * sc), Color("#d9412d"), 4.0 * sc, true)
	_reperes.draw_colored_polygon(PackedVector2Array([f + Vector2(-7, 2 * sg + fy) * sc, f + Vector2(7, 2 * sg + fy) * sc, f + Vector2(0, 11 * sg + fy) * sc]), Color("#d9412d"))
	for j in 3:
		var dx := (-0.32 + 0.24 * j) * w
		_reperes.draw_line(centre + Vector2(dx, h * 0.3), centre + Vector2(dx + w * 0.15, h * 0.3), Color("#5b3416"), 3.0 * sc, true)

# La roue rouge des portes, qui tourne doucement, et une flèche en arc :
# « tourne la roue ».
func _icone_roue(centre: Vector2, sc: float, age: float) -> void:
	var r := 13.0 * sc
	var c := centre + Vector2(-3.0 * sc, 0)
	var tr := Peint.roue()
	if tr:
		_reperes.draw_set_transform(c, age * 1.8, Vector2.ONE)
		_reperes.draw_texture_rect(tr, Rect2(-r - 3, -r - 3, 2 * r + 6, 2 * r + 6), false)
		_reperes.draw_set_transform(Vector2.ZERO)
	else:
		_reperes.draw_arc(c, r, 0.0, TAU, 24, Color("#c8321f"), 4.0 * sc, true)
	_reperes.draw_arc(c, r + 7.0 * sc, -PI * 0.15, PI * 0.55, 12, Color("#5b3416"), 3.0 * sc, true)
	var bout := c + Vector2(cos(PI * 0.55), sin(PI * 0.55)) * (r + 7.0 * sc)
	_reperes.draw_colored_polygon(PackedVector2Array([bout + Vector2(-6, -3) * sc, bout + Vector2(4, -6) * sc, bout + Vector2(0, 5) * sc]), Color("#5b3416"))

# Un autre bateau dans la place : un petit bateau gris barré d'une croix rouge.
func _icone_plein(centre: Vector2, sc: float, _couleur: Color) -> void:
	var c := centre + Vector2(0, 4.0 * sc)
	var coque := PackedVector2Array([c + Vector2(-16, -4) * sc, c + Vector2(16, -6) * sc, c + Vector2(10, 5) * sc, c + Vector2(-12, 5) * sc])
	_reperes.draw_colored_polygon(coque, Color("#8a8580"))
	_reperes.draw_rect(Rect2(c + Vector2(-8, -12) * sc, Vector2(12, 8) * sc), Color("#cfc9c0"))
	_reperes.draw_line(c + Vector2(-14, -16) * sc, c + Vector2(14, 8) * sc, Color("#d9412d"), 4.0 * sc, true)
	_reperes.draw_line(c + Vector2(14, -16) * sc, c + Vector2(-14, 8) * sc, Color("#d9412d"), 4.0 * sc, true)

# Une flèche verte qui pousse dans le sens du voyage : « touche-moi, j'y vais ».
func _icone_passe(centre: Vector2, sc: float, age: float, _couleur: Color) -> void:
	var c := centre + Vector2(3.0 * sin(age * 5.0) * sc, 0)
	_reperes.draw_circle(c, 16.0 * sc, Color("#2ea65a"))
	_reperes.draw_arc(c, 16.0 * sc, 0.0, TAU, 24, Color("#1b6b39"), 2.0 * sc, true)
	var fl := PackedVector2Array([c + Vector2(-8, -4) * sc, c + Vector2(1, -4) * sc, c + Vector2(1, -10) * sc, c + Vector2(10, 0) * sc,
		c + Vector2(1, 10) * sc, c + Vector2(1, 4) * sc, c + Vector2(-8, 4) * sc])
	_reperes.draw_colored_polygon(fl, Color.WHITE)

# Deux eaux inégales de part et d'autre d'une porte.
func _icone_niveaux(centre: Vector2, sc: float) -> void:
	var b := centre + Vector2(0, 14.0 * sc)
	_reperes.draw_rect(Rect2(b + Vector2(-18, -10) * sc, Vector2(14, 10) * sc), Color("#2f8fd8"))
	_reperes.draw_rect(Rect2(b + Vector2(4, -22) * sc, Vector2(14, 22) * sc), Color("#2f8fd8"))
	_reperes.draw_line(b + Vector2(-1, -26) * sc, b + Vector2(-1, 0), Color("#5b3416"), 3.0 * sc)

func _dessiner_ondes() -> void:
	var gardees := []
	for o in _ondes:
		var age: float = _t - float(o[1])
		if age > 0.45: continue
		gardees.append(o)
		var k := age / 0.45
		var p: Vector2 = o[0] - _reperes.global_position
		_reperes.draw_arc(p, 8.0 + 34.0 * k, 0.0, TAU, 32, Color(1, 1, 1, 0.9 * (1.0 - k)), 4.0 * (1.0 - k) + 1.0, true)
	_ondes = gardees

func _dessiner_reperes() -> void:
	_dessiner_bulles()
	_dessiner_ondes()
	_dessiner_manque()
	for k in alertes:
		var bt: Bateau = bateaux[k]
		_exclamation(Vector2(bt.position.x, bt.position.y - 64.0), _t - float(alertes[k]))
	for k in N["bateaux"].size():
		var b: Dictionary = N["bateaux"][k]
		var v := int(b["vers"])
		# arrivé, c'est à sa place ET à flot (la règle du moteur) : échoué à
		# sa place, la bouée reste, couchée si le bassin est à sec
		# (à sa place mais échoué, la bulle du manque suffit : la bouée, au même
		# endroit, chevauchait le bateau)
		var arrive: bool = positions[k] == v
		if arrive: _bouees_vues.erase(k)
		var sp: Sprite2D = _bouees_img.get(k)
		if sp: sp.visible = not arrive
		if arrive: continue
		var x := place(v, "f%d" % k, positions)
		var sens := 1.0 if v >= int(b["de"]) else -1.0
		_bouee(k, x, sens)

# La DESTINATION d'un bateau : une bouée à sa couleur, qui flotte à la place
# qu'il doit atteindre et suit l'eau (lot 3 de PLAN-RENDU.md, choix A de
# Vincent, 6 octobre 2026 — la coque en pointillés faisait calque de mise au
# point). Elle monte et descend avec la houle et penche avec la pente de la
# surface ; le tiers bas de son flotteur est sous l'eau. Bassin à sec, elle
# repose sur le fond. art/bouee.png, si elle existe, remplace le dessin
# (peinte en rouge, repeinte comme les bateaux).
var _bouees_img := {}
var _bouees_vues := {}     # bouée -> sa flottaison (pour le cerne d'eau)
var _bouees_couchees := {} # bouée -> 0 à flot … 1 couchée sur le fond
func _bouee(k: int, x: float, sens: float) -> void:
	var v := int(N["bateaux"][k]["vers"])
	var fond := Y(float(N["bassins"][v]["fond"]))
	var surf := minf(surface_a(x), fond)
	var pente := (surface_a(x + 10.0) - surface_a(x - 10.0)) / 20.0
	var y := surf + 1.2 * sin(_t * 2.2 + k * 1.7)
	var rot := clampf(pente, -0.3, 0.3) * 0.8 + 0.07 * sin(_t * 1.6 + k)
	# Échouée dans un bassin à sec : elle ne bouge plus et se couche sur le
	# fond, fanion vers le sol, du côté où il pointait (Vincent). Elle se
	# couche et se relève en douceur.
	# elle ne flotte que si l'eau dépasse sa partie immergée (~14 px) : dans
	# une pellicule d'eau, elle reste couchée (Vincent)
	var sec: bool = eaux[v].vide() or fond - surf < 14.0
	var couche: float = _bouees_couchees.get(k, 0.0)
	couche = move_toward(couche, 1.0 if sec else 0.0, get_process_delta_time() * 2.5)
	_bouees_couchees[k] = couche
	if couche > 0.0:
		var c := couche * couche * (3.0 - 2.0 * couche)
		y = lerpf(y, fond - 9.0, c)
		rot = lerpf(rot, sens * 1.35, c)
	if surf < fond - 2.0: _bouees_vues[k] = Vector2(x, surf)
	else: _bouees_vues.erase(k)
	var c: Color = COULEURS[k % COULEURS.size()]
	if _bouees_img.has(k) or ResourceLoader.exists("res://art/bouee.png"):
		if not _bouees_img.has(k):
			var s := Sprite2D.new()
			s.texture = _recadrer(load("res://art/bouee.png"))
			var h := 60.0
			s.scale = Vector2.ONE * h / s.texture.get_height()
			# la boule plonge : la flottaison au bas de la bande blanche
			s.offset = Vector2(0, -s.texture.get_height() * (0.5 - 0.2))
			s.flip_h = sens < 0.0
			var repeint = REPEINTS[k % REPEINTS.size()]
			if repeint != null:
				s.material = _mat(SH_TEINTE, {"actif": true, "teinte": repeint[0], "saturation": repeint[1], "luminosite": repeint[2]})
			# dans le plan des bateaux, derrière l'eau : sa partie immergée se
			# voit à travers elle, sous une ligne de flottaison (Vincent : posée
			# par-dessus tout, elle flottait au-dessus de l'eau)
			_flotte.add_child(s)
			_bouees_img[k] = s
		var sp: Sprite2D = _bouees_img[k]
		sp.position = Vector2(x, y)      # le plan des bateaux est déjà à mi-profondeur
		sp.rotation = rot
		return
	var t := Transform2D(rot, Vector2(1.25, 1.25), 0.0, Vector2(x, y))
	_reperes.draw_set_transform_matrix(t)
	var sombre := Color(0.17, 0.09, 0.05)
	# le mât, le fanion, la boule du sommet
	_reperes.draw_line(Vector2(0, -14), Vector2(0, -40), sombre, 3.0, true)
	_reperes.draw_colored_polygon(PackedVector2Array([Vector2(1, -40), Vector2(1 + sens * 18, -35), Vector2(1, -30)]), c)
	_reperes.draw_polyline(PackedVector2Array([Vector2(1, -40), Vector2(1 + sens * 18, -35), Vector2(1, -30)]), sombre, 1.5, true)
	_reperes.draw_circle(Vector2(0, -41), 2.6, sombre)
	# le flotteur : un œuf couché, cerné, avec sa bande blanche et un reflet
	var corps := PackedVector2Array()
	for j in 28:
		var a := TAU * j / 28.0
		corps.append(Vector2(cos(a) * 15.0, -4.0 + sin(a) * (11.0 if sin(a) < 0.0 else 12.0)))
	var cerne := PackedVector2Array()
	for p in corps: cerne.append(p * 1.0 + (p - Vector2(0, -4)).normalized() * 2.2)
	_reperes.draw_colored_polygon(cerne, sombre)
	_reperes.draw_colored_polygon(corps, c)
	var bande := PackedVector2Array()
	for p in corps:
		bande.append(Vector2(p.x, clampf(p.y, -9.0, -3.0)))
	_reperes.draw_colored_polygon(bande, Color(1, 0.98, 0.94))
	_reperes.draw_circle(Vector2(-6, -11), 3.0, Color(1, 1, 1, 0.5))
	# la part immergée, vue à travers l'eau
	var dessous := PackedVector2Array()
	for p in cerne:
		dessous.append(Vector2(p.x, maxf(p.y, 0.0)))
	_reperes.draw_colored_polygon(dessous, Color(0.08, 0.45, 0.6, 0.55))
	_reperes.draw_set_transform_matrix(Transform2D.IDENTITY)
