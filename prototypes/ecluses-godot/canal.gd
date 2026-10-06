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

	_decor()
	_murs_du_fond()
	var flotte := Node2D.new()
	flotte.name = "Bateaux"
	add_child(flotte)
	for i in n:
		var w := Eau.new()
		w.preparer(X(gb[i][0]), X(gb[i][1]), Y(float(B[i]["fond"])), Y(vue_niv[i]), SH_EAU)
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
	_coupe_avant()
	for i in N["liaisons"].size():
		var l: Dictionary = N["liaisons"][i]
		if l["type"] == "porte":
			var po := Porte.new()
			var bas_radier := Y(minf(float(B[i]["fond"]), float(B[i + 1]["fond"])) - 0.32)
			po.preparer(X(gl[i][0]), X(gl[i][1]), Y(float(l["seuil"])), Y(float(l["crete"])), Y(haut - 0.85), bas_radier, U,
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

func _poly(points: PackedVector2Array, mat: Material = null, couleurs := PackedColorArray()) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	if mat: p.material = mat
	if not couleurs.is_empty(): p.vertex_colors = couleurs
	add_child(p)
	return p

func _quad(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

func _mat(shader: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params: m.set_shader_parameter(k, params[k])
	return m

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
		var brut: Texture2D = load("res://art/fond.png")
		var bande := AtlasTexture.new()
		bande.atlas = brut
		bande.region = Rect2(0, brut.get_height() * 0.34, brut.get_width(), brut.get_height() * 0.38)
		tex = bande
	elif ResourceLoader.exists("res://art/maquette.webp"):
		var at := AtlasTexture.new()
		at.atlas = load("res://art/maquette.webp")
		at.region = Rect2(0, 104, 1050, 196)
		tex = at
	if tex:
		var echelle := (W + 160.0) / tex.get_width()
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
	for i in B.size():
		var b: Dictionary = B[i]
		var f := float(b["fond"])
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
		_poly(_quad(X(gb[i][0]) - 8, Y(sommet), X(gb[i][1]) + 8, Y(f)), fond_pierre)
		# l'ombre que le couronnement jette sur le haut du mur
		_poly(_quad(X(gb[i][0]) - 8, Y(sommet), X(gb[i][1]) + 8, Y(sommet) + 16), null,
			PackedColorArray([Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		# le couronnement herbu du mur
		_poly(_quad(X(gb[i][0]) - 10, Y(sommet) - 7, X(gb[i][1]) + 10, Y(sommet) + 3), null,
			PackedColorArray([Color("#9ccc63"), Color("#9ccc63"), Color("#6f9a40"), Color("#6f9a40")]))

	# derrière chaque porte aussi : sinon l'ouverture laisse voir la prairie
	for i in N["liaisons"].size():
		var l: Dictionary = N["liaisons"][i]
		var c := float(l.get("crete", maxf(float(B[i]["fond"]), float(B[i + 1]["fond"]))))
		var bas := minf(float(B[i]["fond"]), float(B[i + 1]["fond"]))
		_poly(_quad(X(gl[i][0]), Y(c + 0.2), X(gl[i][1]), Y(bas)), fond_pierre)

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
	if not B[B.size() - 1].get("fixe", false):
		_poly(_quad(g1, Y(berge), W + LOIN, tres_bas), terre)
		_poly(_quad(g1, Y(berge), g1 + 0.3 * U, Y(float(B[B.size() - 1]["fond"]) - 0.32)), pierre)
		_herbe(g1, W + LOIN, Y(berge))

func _herbe(x0: float, x1: float, y: float) -> void:
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

# Les places d'un bassin : les bateaux qui y sont et les places réservées des
# bateaux qui doivent y finir, réparties sur la largeur. Un bateau qui repart
# vers la gauche attend à gauche, vers la droite à droite ; les arrivés et les
# places réservées au milieu. Ainsi un bateau n'a presque jamais à passer
# devant un autre pour sortir.
func place(i: int, cle: String, pos: Array) -> float:
	var L := []
	for k in pos.size():
		if pos[k] == i: L.append("b%d" % k)
	for k in N["bateaux"].size():
		if int(N["bateaux"][k]["vers"]) == i and pos[k] != i: L.append("f%d" % k)
	if not L.has(cle): L.append(cle)
	L.sort_custom(func(a, b): return _rang_place(a, pos) < _rang_place(b, pos))
	return lerpf(X(gb[i][0]), X(gb[i][1]), float(L.find(cle) + 1) / float(L.size() + 1))

func _rang_place(cle: String, pos: Array) -> float:
	var k := int(cle.substr(1))
	var cap := 0
	if cle[0] == "b":
		cap = signi(int(N["bateaux"][k]["vers"]) - int(pos[k]))
	return cap * 100.0 + k

# --- Le temps qui passe ---------------------------------------------------------------
func _process(dt: float) -> void:
	_t += dt
	if not _ecou.is_empty(): _avancer_ecoulement(dt)
	if not _depl.is_empty(): _avancer_bateaux(dt)
	for i in eaux.size():
		eaux[i].repos = Y(vue_niv[i])
	for i in portes: portes[i].bas_ouvert_y = _bas_ouvert(i)
	_maj_passages()
	for i in aqueducs: aqueducs[i].ouverte = portes[i].vanne_ouverte
	_poser_bateaux(dt)
	_reperes.queue_redraw()

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

# --- Les repères : la place où chaque bateau doit finir ------------------------------------
func _dessiner_reperes() -> void:
	for k in N["bateaux"].size():
		var b: Dictionary = N["bateaux"][k]
		var v := int(b["vers"])
		if positions[k] == v: continue
		var x := place(v, "f%d" % k, positions)
		var tirant: float = bateaux[k].tirant
		var y := minf(surface_a(x), Y(float(N["bassins"][v]["fond"])) - tirant)
		var c: Color = COULEURS[k % COULEURS.size()]
		var L := 1.75 * U * 0.5
		var pts := [Vector2(-L, -14), Vector2(L, -18), Vector2(L * 0.82, tirant * 0.55), Vector2(L * 0.55, tirant), Vector2(-L * 0.72, tirant), Vector2(-L * 0.96, tirant * 0.45), Vector2(-L, -14)]
		var sens := 1.0 if v >= int(b["de"]) else -1.0
		for j in pts.size() - 1:
			var a: Vector2 = Vector2(x, y) + pts[j] * Vector2(sens, 1)
			var z: Vector2 = Vector2(x, y) + pts[j + 1] * Vector2(sens, 1)
			_reperes.draw_dashed_line(a, z, c, 3.0, 9.0)
		var mat := Vector2(x - sens * L * 0.82, y - 14)
		_reperes.draw_line(mat, mat + Vector2(0, -0.7 * U), c, 3.0)
		_reperes.draw_colored_polygon(PackedVector2Array([mat + Vector2(0, -0.7 * U), mat + Vector2(sens * 28, -0.6 * U), mat + Vector2(0, -0.5 * U)]), c)
