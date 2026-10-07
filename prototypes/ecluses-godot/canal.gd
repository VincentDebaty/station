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
var D := Vector2(-34.0, -30.0)

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
var aqueducs := {}    # liaison -> Aqueduc, le conduit par où passe l'eau d'une porte
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

# --- La construction ---------------------------------------------------------------
func construire(niveau: Dictionary, e: Dictionary) -> void:
	N = niveau
	var B: Array = N["bassins"]
	var n := B.size()
	var x := 0.0 if B[0].get("fixe", false) else MARGE
	var crete_max := 0.0
	for i in n:
		gb.append([x, x + float(B[i]["largeur"])])
		x += float(B[i]["largeur"])
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
	if D != Vector2.ZERO:
		_dessous_des_bassins()
		_surface_fond = Node2D.new()
		add_child(_surface_fond)
	var flotte := Node2D.new()
	flotte.name = "Bateaux"
	flotte.position = D * 0.5          # à mi-profondeur
	add_child(flotte)
	var vantaux: Node2D = null
	if D != Vector2.ZERO:
		_surface_avant = Node2D.new()
		add_child(_surface_avant)
		vantaux = Node2D.new()
		vantaux.name = "Vantaux"
		add_child(vantaux)
	for i in n:
		var w := Eau.new()
		var xb := _x_bassin(i)
		w.preparer(xb.x, xb.y, Y(float(B[i]["fond"])), Y(vue_niv[i]), SH_EAU)
		w.paroi_g = i == 0 or N["liaisons"][i - 1]["type"] != "porte"
		w.paroi_d = i == n - 1 or N["liaisons"][i]["type"] != "porte"
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
			var bas_radier := Y(minf(float(B[i]["fond"]), float(B[i + 1]["fond"])) - 0.32)
			# trois hauteurs de portique, pour ne pas aligner trois colonnes
			# identiques (lot 4) ; plus bas seulement : le vantail levé garde
			# ~1,4 unité de place sous la traverse
			var decale: float = [0.0, -0.3, -0.15][i % 3]
			po.preparer(X(gl[i][0]), X(gl[i][1]), Y(float(l["seuil"])), Y(float(l["crete"])), Y(haut - 0.85 + decale), bas_radier, U,
				SH_PIERRE, SH_BOIS, e["ouvert"][i], _vantail_leve(e, i), _bas_ouvert(i))
			add_child(po)
			portes[i] = po
	# les aqueducs, dans la terre de la coupe, par-dessus le radier des portes
	for i in portes:
		var aq := Aqueduc.new()
		aq.preparer(_trace_aqueduc(i), 0.2 * UY)
		aq.ouverte = e["ouvert"][i]
		aq.vanne = 1.0 if aq.ouverte else 0.0
		add_child(aq)
		aqueducs[i] = aq
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
		bt.longueur = 1.75 * U
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
	if D != Vector2.ZERO:
		_cible = Node2D.new()
		_cible.name = "PlanDuFond"
		_cible.position = D
		add_child(_cible)
	for i in B.size():
		var b: Dictionary = B[i]
		var f := float(b["fond"])
		var xb := _x_bassin(i)
		var mx0 := xb.x if D != Vector2.ZERO else X(gb[i][0])
		var mx1 := xb.y if D != Vector2.ZERO else X(gb[i][1])
		var sommet: float
		if b["type"] == "sas":
			sommet = 0.0
			for j in [i - 1, i]:
				if j >= 0 and j < N["liaisons"].size() and N["liaisons"][j].has("crete"):
					sommet = maxf(sommet, float(N["liaisons"][j]["crete"]))
			sommet += 0.2
		else:
			# un bief a des quais de pierre presque jusqu'à la berge : la prairie
			# ne se voit qu'en haut, comme une pente qui s'éloigne
			sommet = maxf(maxf(f + 2.5, berge - 1.6), float(b.get("niveau", f)) + 0.8)
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
		_couronnement(mx0 - 8, mx1 + 8, Y(sommet), i)
		# le couronnement herbu du mur
		if not _bande_herbe(mx0 - 10, mx1 + 10, Y(sommet) + 2, 24.0):
			_poly(_quad(mx0 - 10, Y(sommet) - 7, mx1 + 10, Y(sommet) + 3), null,
				PackedColorArray([Color("#9ccc63"), Color("#9ccc63"), Color("#6f9a40"), Color("#6f9a40")]))

	_cible = null
	if D != Vector2.ZERO: return      # en oblique, les murs vont d'une porte à l'autre
	# derrière chaque porte aussi : sinon l'ouverture laisse voir la prairie
	for i in N["liaisons"].size():
		var l: Dictionary = N["liaisons"][i]
		var c := float(l.get("crete", maxf(float(B[i]["fond"]), float(B[i + 1]["fond"]))))
		var bas := minf(float(B[i]["fond"]), float(B[i + 1]["fond"]))
		_poly(_quad(X(gl[i][0]), Y(c + 0.2), X(gl[i][1]), Y(bas)), fond_porte)

# En oblique : ce qu'on voit à travers l'eau entre la coupe et le mur du
# fond — le fond de chaque bassin (vu d'en haut), la contremarche quand le
# bassin de droite est plus haut, et la paroi du bout du canal, à droite.
func _dessous_des_bassins() -> void:
	var B: Array = N["bassins"]
	var sol := _mat(SH_PIERRE, {"ombre": 0.82, "teinte": Color("#d6c7a8")})
	var paroi := _mat(SH_PIERRE, {"ombre": 0.66, "teinte": Color("#d6c7a8")})
	for i in B.size():
		var xb := _x_bassin(i)
		var y := Y(float(B[i]["fond"]))
		_poly(PackedVector2Array([Vector2(xb.x, y), Vector2(xb.y, y), Vector2(xb.y + D.x, y + D.y), Vector2(xb.x + D.x, y + D.y)]), sol)
		if i < B.size() - 1 and float(B[i + 1]["fond"]) > float(B[i]["fond"]):
			var yh := Y(float(B[i + 1]["fond"]))
			_poly(PackedVector2Array([Vector2(xb.y + D.x, yh + D.y), Vector2(xb.y, yh), Vector2(xb.y, y), Vector2(xb.y + D.x, y + D.y)]), paroi)
		if i > 0 and float(B[i - 1]["fond"]) > float(B[i]["fond"]):
			pass   # la contremarche d'un bassin de gauche plus haut nous tourne le dos
	var n := B.size()
	if not B[n - 1].get("fixe", false):
		var xb := _x_bassin(n - 1)
		var y := Y(float(B[n - 1]["fond"]))
		_poly(PackedVector2Array([Vector2(xb.y + D.x, Y(berge) + D.y), Vector2(xb.y, Y(berge)), Vector2(xb.y, y), Vector2(xb.y + D.x, y + D.y)]), paroi)

# La surface de l'eau vue d'en haut, en oblique : une bande de la coupe au mur
# du fond, en deux moitiés. Celle du fond passe derrière les bateaux ; celle de
# devant passe devant leur coque, un peu transparente — sous leur flottaison,
# la coque est dans l'eau. Elle suit la surface de la coupe, vagues comprises.
var _surface_fond: Node2D
var _surface_avant: Node2D
var _bandes := []          # par bassin : [moitié du fond, moitié de devant]
func _maj_surfaces() -> void:
	if _surface_fond == null: return
	if _bandes.is_empty():
		for i in eaux.size():
			var f := Polygon2D.new()
			var a := Polygon2D.new()
			_surface_fond.add_child(f)
			_surface_avant.add_child(a)
			_bandes.append([f, a])
	for i in eaux.size():
		var w: Eau = eaux[i]
		var bord := PackedVector2Array()
		var x := w.x0
		while true:
			bord.append(Vector2(x, minf(w.hauteur_a(x), w.fond_y)))
			if x >= w.x1: break
			x = minf(x + 12.0, w.x1)
		var sec := w.fond_y - bord[0].y < 1.5
		var f: Polygon2D = _bandes[i][0]
		var a: Polygon2D = _bandes[i][1]
		f.visible = not sec
		a.visible = not sec
		if sec: continue
		f.polygon = _bande(bord, 0.5, 1.0)
		a.polygon = _bande(bord, 0.0, 0.5)
		f.vertex_colors = _degrade_bande(bord.size(), Color(0.34, 0.76, 0.88, 0.96), Color(0.64, 0.88, 0.95, 0.96))
		a.vertex_colors = _degrade_bande(bord.size(), Color(0.17, 0.6, 0.78, 0.78), Color(0.34, 0.76, 0.88, 0.78))

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
		var x0 := X(gb[i][0])
		var x1 := X(gb[i][1])
		# le radier du bassin, puis la terre dessous
		_poly(_quad(x0 - 2, Y(f), x1 + 2, Y(f - 0.32)), pierre)
		_poly(_quad(x0 - 2, Y(f - 0.32), x1 + 2, tres_bas), terre)
	for i in N["liaisons"].size():
		var bas := minf(float(B[i]["fond"]), float(B[i + 1]["fond"]))
		_poly(_quad(X(gl[i][0]), Y(bas - 0.32), X(gl[i][1]), tres_bas), terre)
		if N["liaisons"][i]["type"] != "porte":
			var c: float = float(N["liaisons"][i].get("crete", maxf(float(B[i]["fond"]), float(B[i + 1]["fond"]))))
			_poly(_quad(X(gl[i][0]), Y(c), X(gl[i][1]), Y(bas - 0.32)), pierre)
	# les berges, aux deux bouts : terre, parement de pierre côté eau, herbe
	var g0 := X(gb[0][0])
	var g1 := X(gb[B.size() - 1][1])
	if not B[0].get("fixe", false):
		_poly(_quad(-LOIN, Y(berge), g0, tres_bas), terre)
		_poly(_quad(g0 - 0.3 * U, Y(berge), g0, Y(float(B[0]["fond"]) - 0.32)), pierre)
		_herbe(-LOIN, g0, Y(berge))
		_empattement(g0 - 0.3 * U, Y(float(B[0]["fond"]) - 0.32), -1.0, pierre)
	if not B[B.size() - 1].get("fixe", false):
		_poly(_quad(g1, Y(berge), W + LOIN, tres_bas), terre)
		_poly(_quad(g1, Y(berge), g1 + 0.3 * U, Y(float(B[B.size() - 1]["fond"]) - 0.32)), pierre)
		_herbe(g1, W + LOIN, Y(berge))
		_empattement(g1 + 0.3 * U, Y(float(B[B.size() - 1]["fond"]) - 0.32), 1.0, pierre)
	# la terre vit : une ombre douce sous tout ce qui la couvre (radiers, herbe
	# des berges, parements), et des pousses vertes, comme sur la maquette
	var tops := []      # [x0, x1, y] : le haut de chaque morceau de terre
	for i in B.size():
		tops.append([X(gb[i][0]) - 2, X(gb[i][1]) + 2, Y(float(B[i]["fond"]) - 0.32)])
	for i in N["liaisons"].size():
		tops.append([X(gl[i][0]), X(gl[i][1]), Y(minf(float(B[i]["fond"]), float(B[i + 1]["fond"])) - 0.32)])
	if not B[0].get("fixe", false):
		tops.append([-LOIN, g0 - 0.3 * U, Y(berge) + 6])
		_ombre_cote(g0 - 0.3 * U, Y(berge) + 6, Y(float(B[0]["fond"]) - 0.32), -1.0)
	if not B[B.size() - 1].get("fixe", false):
		tops.append([g1 + 0.3 * U, W + LOIN, Y(berge) + 6])
		_ombre_cote(g1 + 0.3 * U, Y(berge) + 6, Y(float(B[B.size() - 1]["fond"]) - 0.32), 1.0)
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
func _x_bassin(i: int) -> Vector2:
	var a := X(gb[i][0])
	var b := X(gb[i][1])
	if D != Vector2.ZERO:
		if i > 0 and N["liaisons"][i - 1]["type"] == "porte": a = X(gl[i - 1][0] + gl[i - 1][1]) * 0.5
		if i < gl.size() and N["liaisons"][i]["type"] == "porte": b = X(gl[i][0] + gl[i][1]) * 0.5
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

func porte_sous(p: Vector2) -> int:
	for i in portes:
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
	for i in aqueducs:
		aqueducs[i].ouverte = portes[i].vanne_ouverte
		aqueducs[i].niveau_g = Y(vue_niv[i])
		aqueducs[i].niveau_d = Y(vue_niv[i + 1])
	_poser_bateaux(dt)
	_reperes.queue_redraw()

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
func placer_vantaux(e: Dictionary) -> void:
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
	if dh < 1e-4:
		vue_niv = apres.duplicate()
		ecoulement_fini.emit.call_deferred()
		return
	var tetes := {}
	for i in flux.size():
		if absf(flux[i]) > 0.01: tetes[i] = absf(avant[i] - avant[i + 1])
	_ecou = {"t": 0.0, "T": 1.1 + 1.25 * sqrt(dh), "avant": avant.duplicate(), "apres": apres.duplicate(), "flux": flux.duplicate(), "tetes": tetes}

func _avancer_ecoulement(dt: float) -> void:
	_ecou["t"] += dt
	var p := clampf(_ecou["t"] / _ecou["T"], 0.0, 1.0)
	var f := (1.0 - p) * (1.0 - p)
	for i in vue_niv.size():
		vue_niv[i] = _ecou["apres"][i] + (_ecou["avant"][i] - _ecou["apres"][i]) * f
	for i in eaux.size(): eaux[i].remous = move_toward(eaux[i].remous, 0.0, dt * 0.8)
	for i in _ecou["flux"].size():
		if aqueducs.has(i): _aqueduc(i, _ecou["flux"][i], dt)
	if p >= 1.0:
		_ecou = {}
		for aq in aqueducs.values(): aq.couler(0.0, 1)
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
		var f := float(N["bassins"][i]["fond"])
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
func signaler_manque(bassin: int, niveau: float, k: int) -> void:
	_manque = {"bassin": bassin, "y": Y(niveau), "couleur": COULEURS[k % COULEURS.size()], "t": _t}

func manque_signale() -> bool:
	return not _manque.is_empty()

var _police_manque: Font = null
func _dessiner_manque() -> void:
	if _manque.is_empty(): return
	var i: int = _manque["bassin"]
	var x0 := X(gb[i][0]) + 4.0
	var x1 := X(gb[i][1]) - 4.0
	var y: float = _manque["y"]
	var c: Color = _manque["couleur"]
	var age := _t - float(_manque["t"])
	var a := clampf(age / 0.4, 0.0, 1.0)
	var bat := 0.75 + 0.25 * sin(age * 4.0)
	# l'eau qui manque : la bande entre la surface et le niveau qu'il faudrait,
	# hachurée à la couleur du bateau
	var surface := surface_a((x0 + x1) * 0.5)
	if surface > y + 1.0:
		_reperes.draw_rect(Rect2(x0, y, x1 - x0, surface - y), Color(c, 0.22 * a * bat))
		var pas := 14.0
		var x := x0 - (surface - y)
		while x < x1:
			var p0 := Vector2(x, surface)
			var p1 := Vector2(x + (surface - y), y)
			# rogner le trait au bassin
			if p0.x < x0: p0 = Vector2(x0, surface - (x0 - p0.x))
			if p1.x > x1: p1 = Vector2(x1, y + (p1.x - x1))
			if p1.x > p0.x: _reperes.draw_line(p0, p1, Color(c, 0.55 * a * bat), 2.0, true)
			x += pas
	_reperes.draw_dashed_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.9 * a), 7.0, 14.0)
	_reperes.draw_dashed_line(Vector2(x0, y), Vector2(x1, y), Color(c, a), 4.0, 14.0)
	# l'inscription, au-dessus de la ligne
	if _police_manque == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial Rounded MT", "Avenir Next", "Helvetica Neue"])
		f.font_weight = 700
		_police_manque = f
	var texte := "Il manque de l'eau"
	var taille := 22
	var l := _police_manque.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var pos := Vector2((x0 + x1 - l) * 0.5, y - 14.0)
	_reperes.draw_string_outline(_police_manque, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 8, Color(0.24, 0.13, 0.05, a))
	_reperes.draw_string(_police_manque, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(1, 0.95, 0.86, a))

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

func _dessiner_reperes() -> void:
	_dessiner_manque()
	for k in alertes:
		var bt: Bateau = bateaux[k]
		_exclamation(Vector2(bt.position.x, bt.position.y - 64.0), _t - float(alertes[k]))
	for k in N["bateaux"].size():
		var b: Dictionary = N["bateaux"][k]
		var v := int(b["vers"])
		var arrive: bool = positions[k] == v
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
func _bouee(k: int, x: float, sens: float) -> void:
	var v := int(N["bateaux"][k]["vers"])
	var fond := Y(float(N["bassins"][v]["fond"]))
	var surf := minf(surface_a(x), fond)
	var pente := (surface_a(x + 10.0) - surface_a(x - 10.0)) / 20.0
	var y := surf + 1.2 * sin(_t * 2.2 + k * 1.7)
	var rot := clampf(pente, -0.3, 0.3) * 0.8 + 0.07 * sin(_t * 1.6 + k)
	var c: Color = COULEURS[k % COULEURS.size()]
	if _bouees_img.has(k) or ResourceLoader.exists("res://art/bouee.png"):
		if not _bouees_img.has(k):
			var s := Sprite2D.new()
			s.texture = _recadrer(load("res://art/bouee.png"))
			var h := 52.0
			s.scale = Vector2.ONE * h / s.texture.get_height()
			s.offset = Vector2(0, -s.texture.get_height() * (0.5 - 0.27))    # le tiers bas sous l'eau
			s.flip_h = sens < 0.0
			var repeint = REPEINTS[k % REPEINTS.size()]
			if repeint != null:
				s.material = _mat(SH_TEINTE, {"actif": true, "teinte": repeint[0], "saturation": repeint[1], "luminosite": repeint[2]})
			s.z_index = 3
			add_child(s)
			_bouees_img[k] = s
		var sp: Sprite2D = _bouees_img[k]
		sp.position = Vector2(x, y)
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
