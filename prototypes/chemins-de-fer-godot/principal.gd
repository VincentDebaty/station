extends Node2D
# ------------------------------------------------------------------
# « Chemins de fer » joué en direct sur le moteur (moteur.gd).
#
# Deux vues : la CARTE (la grille octogonale) et le DÉPÔT (la voie, les
# stocks, l'achat du matériel : on y entre en touchant le dépôt, case D).
# Sur la carte, trois modes : construire une voie (toucher une case voisine
# de la tête de voie), explorer le brouillard, choisir les arrêts d'un
# itinéraire. Le temps est réel ; les boutons ×60 et ×600 ne servent qu'à
# tester (le jeu, lui, n'accélère pas).
#
# CHEMINS_CAPTURE=<dossier> joue le début du scénario, photographie la
# carte puis le dépôt, et quitte (vérification en fenêtre, sans les doigts).
# ------------------------------------------------------------------

const Moteur = preload("res://moteur.gd")

const CASE := 34.0
const X0 := 11.0
const Y0 := 150.0

# La charte du pontier et des carrefours : plateau vu de dessus, bois et
# crème, un seul aspect voulu (pas de thème sombre).
const PAVE := Color("#efe0c2")
const BOIS := Color("#7a4a26")
const BOIS_FONCE := Color("#5a3418")
const CREME := Color("#fff3dc")
const ENCRE := Color("#3b2414")
const OR := Color("#ffc93c")
const BORD_CARTON := Color("#c9b48c")
const OMBRE_CARTON := Color("#b39a6c")
const COULEURS := {
	"depot": Color("#ffc93c"), "prairie": Color("#b5d77a"), "charbon": Color("#5b4a3d"),
	"foret": Color("#3e9b5a"), "fer": Color("#d9663e"), "lac": Color("#4aa3e0"),
	"ferme": Color("#f0b43c"), "carriere": Color("#d96d92"), "ville": Color("#e0533d"),
	"friche": Color("#e3d1aa"), "terre": Color("#e3d1aa")}
const LETTRES := {"depot": "D", "charbon": "C", "foret": "B", "fer": "Fe", "lac": "E",
	"ferme": "Bl", "carriere": "P", "ville": "V"}
const COUL_WAGON := {"tombereau": Color("#8d8678"), "citerne": Color("#4aa3e0"),
	"couvert": Color("#d98c1f"), "plat": Color("#3e9b5a")}
const NOM_WAGON := {"tombereau": "Tombereau", "citerne": "Citerne",
	"couvert": "Couvert agr.", "plat": "Plat"}

var m: Moteur
var vue := "carte"
var mode := "construire"
var tete: Vector2i
var selection: Array[Vector2i] = []
var message := "Touchez une case voisine de la tête de voie (cercle), ou le dépôt D."
var vitesse := 1.0
var police: Font
var boutons := {}
var cadre: Control

func _ready() -> void:
	var f0 := SystemFont.new()
	f0.font_names = PackedStringArray(["Lilita One", "Arial Rounded MT Bold", "Avenir Next", "Helvetica Neue"])
	f0.font_weight = 700
	police = f0
	var f := FileAccess.open("res://niveau.json", FileAccess.READ)
	m = Moteur.new(JSON.parse_string(f.get_as_text()))
	tete = m.centre
	cadre = Control.new()
	add_child(cadre)
	_construire_ui()
	_montrer()
	if OS.get_environment("CHEMINS_CAPTURE") != "":
		_capture.call_deferred()

func _bouton(id: String, texte: String, x: float, y: float, w: float, h: float, cb: Callable) -> void:
	var b := Button.new()
	b.text = texte
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.add_theme_font_override("font", police)
	b.add_theme_font_size_override("font_size", 19)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, ENCRE)
	_style(b, false)
	b.pressed.connect(cb)
	cadre.add_child(b)
	boutons[id] = b

func _construire_ui() -> void:
	var y := 664.0
	# carte
	_bouton("construire", "Construire", 11, y, 140, 52, func(): mode = "construire"; message = "Mode construction."; _montrer())
	_bouton("explorer", "Explorer 50 or", 158, y, 160, 52, func(): mode = "explorer"; message = "Touchez une case de brouillard bordée de pointillés."; _montrer())
	_bouton("itineraire", "Itinéraire", 325, y, 120, 52, func(): mode = "itineraire"; selection.clear(); message = "Touchez les arrêts (ressources, ville), puis Valider."; _montrer())
	_bouton("annuler", "Annuler", 452, y, 137, 52, func(): _dire(m.annuler()); tete = m.centre)
	y += 62
	_bouton("valider", "Valider l'itinéraire", 11, y, 215, 52, _valider)
	_bouton("train", "Lancer le train", 233, y, 190, 52, _bascule_train)
	_bouton("vitesse", "×1", 430, y, 159, 52, _vitesse)
	# dépôt
	y = 664.0
	_bouton("loco", "Locomotive 400 or", 11, y, 215, 52, func(): _dire(m.acheter_loco()))
	_bouton("w_tombereau", "+ Tombereau 100", 233, y, 175, 52, func(): _dire(m.acheter_wagon("tombereau")))
	_bouton("w_citerne", "+ Citerne 100", 415, y, 174, 52, func(): _dire(m.acheter_wagon("citerne")))
	y += 62
	_bouton("w_couvert", "+ Couvert 100", 11, y, 215, 52, func(): _dire(m.acheter_wagon("couvert")))
	_bouton("w_plat", "+ Plat 100", 233, y, 175, 52, func(): _dire(m.acheter_wagon("plat")))
	_bouton("retirer", "Retirer le dernier", 415, y, 174, 52, func(): m.retirer_wagon())
	_bouton("retour", "Retour à la carte", 11, y + 62, 578, 52, func(): vue = "carte"; message = ""; _montrer())

func _boite(fond: Color, bord: Color, ombre: Color, rayon: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fond
	sb.border_color = bord
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(rayon)
	sb.shadow_color = ombre
	sb.shadow_offset = Vector2(0, 3)
	sb.shadow_size = 1
	return sb

func _style(b: Button, actif: bool) -> void:
	var fond := OR if actif else CREME
	var bord := Color("#c99a1a") if actif else BORD_CARTON
	var ombre := Color("#a87c10") if actif else OMBRE_CARTON
	var sb := _boite(fond, bord, ombre, 26)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", _boite(fond.darkened(0.06), bord, ombre, 26))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _dire(r: String) -> void:
	if r != "":
		message = r

func _vitesse() -> void:
	vitesse = {1.0: 60.0, 60.0: 600.0, 600.0: 1.0}[vitesse]
	boutons["vitesse"].text = "×%d" % int(vitesse)

func _valider() -> void:
	var r := m.definir_itineraire(selection)
	if r != "":
		message = r
	else:
		message = "Itinéraire : %d cases, %d de charbon par boucle." % [m.cases_boucle(), m.carburant_boucle()]
		mode = "construire"
	_montrer()

func _bascule_train() -> void:
	if m.train.is_empty():
		var r := m.lancer()
		message = r if r != "" else "Le train est lancé."
	else:
		m.arreter_train()
		message = "Train arrêté."
	_montrer()

func _montrer() -> void:
	var carte := vue == "carte"
	for id in ["construire", "explorer", "itineraire", "annuler", "valider", "train", "vitesse"]:
		boutons[id].visible = carte
	for id in ["loco", "w_tombereau", "w_citerne", "w_couvert", "w_plat", "retirer", "retour"]:
		boutons[id].visible = not carte
	boutons["train"].text = "Arrêter le train" if not m.train.is_empty() else "Lancer le train"
	for id in ["construire", "explorer", "itineraire"]:
		_style(boutons[id], mode == id)
	boutons["valider"].visible = carte and mode == "itineraire"
	queue_redraw()

func _process(dt: float) -> void:
	var reste := dt * vitesse
	while reste > 0.0:
		var pas := minf(reste, 0.5)
		m.avancer(pas)
		reste -= pas
	queue_redraw()

# ---------------------------------------------------------------- les touches

func _case_sous(p: Vector2) -> Vector2i:
	var x := int(floor((p.x - X0) / CASE))
	var y := int(floor((p.y - Y0) / CASE))
	return Vector2i(x, y)

func _input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if vue != "carte":
		return
	var c := _case_sous(e.position)
	if not m.dans_grille(c) or e.position.y < Y0 or e.position.y > Y0 + CASE * m.hauteur:
		return
	if c == m.centre and mode != "itineraire":
		vue = "depot"
		message = ""
		_montrer()
		return
	match mode:
		"explorer":
			var r := m.explorer(c)
			message = r if r != "" else ("Vous avez trouvé la ville !" if c == m.ville else "Case explorée (-50 or).")
		"construire":
			if not m.connues.has(c):
				message = "Case inconnue : explorez-la d'abord."
			elif c == tete:
				message = "Tête de voie ici. Touchez une case voisine."
			elif c in m.voisins(tete):
				var r2 := m.poser(tete, c)
				if r2 == "":
					tete = c
					message = "Case posée."
				else:
					message = r2
			elif m.a_voie(c):
				tete = c
				message = "Tête de voie déplacée."
			else:
				message = "Cette case n'est pas voisine de la tête de voie."
		"itineraire":
			if c in selection:
				selection.erase(c)
			elif m.sources.has(c) or c == m.ville:
				selection.append(c)
			else:
				message = "Un arrêt est une ressource ou la ville."
	_montrer()

# ---------------------------------------------------------------- le dessin

func _centre_case(c: Vector2i) -> Vector2:
	return Vector2(X0 + c.x * CASE + CASE / 2.0, Y0 + c.y * CASE + CASE / 2.0)

func _octogone(c: Vector2, demi: float, coupe: float) -> PackedVector2Array:
	var d := demi
	var k := coupe
	return PackedVector2Array([
		c + Vector2(-d + k, -d), c + Vector2(d - k, -d), c + Vector2(d, -d + k), c + Vector2(d, d - k),
		c + Vector2(d - k, d), c + Vector2(-d + k, d), c + Vector2(-d, d - k), c + Vector2(-d, -d + k)])

func _texte(p: Vector2, t: String, taille: int, col: Color, centre := false) -> void:
	var pos := p
	if centre:
		var w := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		pos.x -= w / 2.0
	draw_string(police, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, col)

func _pastille(x: float, y: float, t: String, taille: int, fond: Color, col: Color) -> float:
	var w := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + 26.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = fond
	sb.set_corner_radius_all(20)
	draw_style_box(sb, Rect2(x, y, w, taille + 14.0))
	_texte(Vector2(x + 13.0, y + taille + 3.0), t, taille, col)
	return w

func _carton(r: Rect2, fond: Color, bord: Color, rayon: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fond
	sb.border_color = bord
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(rayon)
	draw_style_box(sb, r)

func _bulle(t: String, centre_x: float, y: float) -> void:
	var lignes: PackedStringArray = [t]
	if police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > 540.0:
		var mots := t.split(" ")
		var l1 := ""
		var l2 := ""
		for mot in mots:
			if police.get_string_size(l1 + " " + mot, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x < 520.0 and l2 == "":
				l1 += (" " if l1 != "" else "") + mot
			else:
				l2 += (" " if l2 != "" else "") + mot
		lignes = PackedStringArray([l1, l2])
	var w := 0.0
	for l in lignes:
		w = maxf(w, police.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
	var h := 14.0 + 22.0 * lignes.size()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ENCRE
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_offset = Vector2(0, 4)
	sb.shadow_size = 1
	draw_style_box(sb, Rect2(centre_x - w / 2.0 - 16.0, y - h, w + 32.0, h))
	for i in lignes.size():
		_texte(Vector2(centre_x, y - h + 24.0 + 22.0 * i), lignes[i], 17, CREME, true)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(600, 1300)), BOIS)
	_barre()
	if vue == "carte":
		_dessiner_carte()
	else:
		_dessiner_depot()

func _barre() -> void:
	var x := 14.0
	x += _pastille(x, 12.0, "Or %d" % m.or_, 24, OR, ENCRE) + 8.0
	x += _pastille(x, 12.0, "Bois %d" % m.bois, 21, BOIS_FONCE, CREME) + 8.0
	x += _pastille(x, 12.0, "Fer %d" % m.fer, 21, BOIS_FONCE, CREME) + 8.0
	_pastille(x, 12.0, "Charbon %d/100" % m.charbon, 21, BOIS_FONCE, CREME)
	var h := m.temps / 3600.0
	_pastille(14.0, 58.0, "%d h %02d" % [int(h), int(fmod(m.temps / 60.0, 60.0))], 18, Color(0, 0, 0, 0.3), CREME)
	if not m.train.is_empty():
		_pastille(110.0, 58.0, String(m.train["message"]).left(48), 17, Color("#2f9e58"), CREME)

func _dessiner_carte() -> void:
	_carton(Rect2(5, Y0 - 8, 590, CASE * m.hauteur + 16), PAVE, BOIS_FONCE, 18)
	for y in m.hauteur:
		for x in m.largeur:
			var c := Vector2i(x, y)
			var ctr := _centre_case(c)
			var poly := _octogone(ctr, CASE / 2.0 - 1.5, 8.0)
			if m.connues.has(c):
				var t := m.type_case(c)
				var col: Color = COULEURS[t]
				if LETTRES.has(t):
					draw_colored_polygon(_octogone(ctr + Vector2(0, 2.5), CASE / 2.0 - 1.5, 8.0), col.darkened(0.3))
				draw_colored_polygon(poly, col)
				draw_polyline(poly + PackedVector2Array([poly[0]]), col.darkened(0.25), 1.5)
				if LETTRES.has(t):
					_texte(ctr + Vector2(0, 6), LETTRES[t], 17, ENCRE if t in ["depot", "ferme", "prairie"] else CREME, true)
			else:
				var voisin := false
				for n in m.voisins(c):
					if m.connues.has(n):
						voisin = true
				draw_colored_polygon(poly, Color("#e6d6b3") if not voisin else Color("#dcc89c"))
				if voisin:
					draw_polyline(poly + PackedVector2Array([poly[0]]), BOIS, 1.5)
					_texte(ctr + Vector2(0, 5), "50", 13, BOIS, true)
	for k in m.aretes:
		var p := String(k).split("|")
		var a := p[0].split(",")
		var b := p[1].split(",")
		var pa := _centre_case(Vector2i(int(a[0]), int(a[1])))
		var pb := _centre_case(Vector2i(int(b[0]), int(b[1])))
		draw_line(pa, pb, BOIS_FONCE, 7.0)
		draw_line(pa, pb, CREME, 2.0)
	for i in selection.size():
		var q := _centre_case(selection[i])
		draw_arc(q, 15.0, 0.0, TAU, 20, OR, 4.0)
		_texte(q + Vector2(11, -12), str(i + 1), 17, ENCRE)
	if mode == "construire":
		draw_arc(_centre_case(tete), 14.0, 0.0, TAU, 24, Color("#2d6fb8"), 4.0)
	if not m.train.is_empty() and m.chemin.size() > 1:
		var i: int = m.train["i"]
		var a2 := _centre_case(m.chemin[i])
		var pos := a2
		if m.train["etat"] == "roule" and i < m.chemin.size() - 1:
			var f: float = float(m.train["t"]) / float(m.N["locomotive"]["secondes_par_case"])
			pos = a2.lerp(_centre_case(m.chemin[i + 1]), clampf(f, 0.0, 1.0))
		draw_circle(pos, 11.0, BOIS_FONCE)
		draw_circle(pos, 8.0, Color("#e0533d"))
		draw_circle(pos + Vector2(0, -1), 3.0, CREME)
	if message != "":
		_bulle(message, 300.0, Y0 + CASE * m.hauteur - 14.0)
	_texte(Vector2(14, Y0 + CASE * m.hauteur + 24), "D dépôt · C charbon · B forêt · Fe fer · E lac · Bl ferme · P carrière · V ville", 15, CREME)
	_texte(Vector2(14, Y0 + CASE * m.hauteur + 44), "Voie : 2 bois + 1 fer par case, virage de 45° au plus.", 15, Color(1, 0.953, 0.863, 0.7))

func _dessiner_depot() -> void:
	_carton(Rect2(11, Y0 - 8, 578, 470), CREME, BORD_CARTON, 18)
	_texte(Vector2(28, Y0 + 32), "Dépôt principal · niveau 1", 26, ENCRE)
	_texte(Vector2(28, Y0 + 58), "1 voie · quai de 5 emplacements", 16, Color(0.23, 0.14, 0.08, 0.7))
	var yv := Y0 + 190.0
	draw_rect(Rect2(20, yv + 34, 560, 7), BOIS_FONCE)
	for i in 28:
		draw_rect(Rect2(26 + i * 20, yv + 30, 6, 15), BORD_CARTON)
	for s in 6:
		var x := 24.0 + s * 93.0
		var r := Rect2(x, yv - 20, 86, 50)
		if s == 0:
			if m.loco:
				draw_rect(Rect2(x, yv - 20, 86, 50), Color("#e0533d"))
				draw_rect(Rect2(x + 52, yv - 34, 26, 16), BOIS_FONCE)
				_texte(Vector2(x + 43, yv + 12), "Loco", 18, CREME, true)
				draw_circle(Vector2(x + 22, yv + 38), 8.0, ENCRE)
				draw_circle(Vector2(x + 62, yv + 38), 8.0, ENCRE)
			else:
				draw_rect(r, BORD_CARTON, false, 2.0)
				_texte(Vector2(x + 43, yv + 10), "Loco ?", 16, OMBRE_CARTON, true)
		elif s - 1 < m.wagons.size():
			var w: String = m.wagons[s - 1]
			draw_rect(r, COUL_WAGON[w])
			draw_rect(r, BOIS_FONCE, false, 2.0)
			_texte(Vector2(x + 43, yv), NOM_WAGON[w], 14, Color.WHITE, true)
			var cont: Dictionary = m.contenus[s - 1]
			_texte(Vector2(x + 43, yv + 20), "%d / 20" % int(cont["n"]), 16, Color.WHITE, true)
			draw_circle(Vector2(x + 20, yv + 38), 7.0, ENCRE)
			draw_circle(Vector2(x + 66, yv + 38), 7.0, ENCRE)
		else:
			draw_rect(r, BORD_CARTON, false, 1.5)
	_texte(Vector2(28, Y0 + 130), "%d wagon(s) sur 5" % m.wagons.size(), 16, Color(0.23, 0.14, 0.08, 0.7))
	var stocks := [["Charbon", "%d / 100" % m.charbon], ["Bois", str(m.bois)], ["Fer", str(m.fer)], ["Pierre", str(m.pierre)], ["Or", str(m.or_)]]
	for i in stocks.size():
		var x2 := 22.0 + i * 112.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAVE
		sb.set_corner_radius_all(12)
		draw_style_box(sb, Rect2(x2, Y0 + 320, 104, 72))
		_texte(Vector2(x2 + 10, Y0 + 346), stocks[i][0], 15, Color(0.23, 0.14, 0.08, 0.7))
		_texte(Vector2(x2 + 10, Y0 + 378), stocks[i][1], 22, ENCRE)
	_texte(Vector2(28, Y0 + 428), "Améliorer le dépôt (niveau 2) : 500 or + bois livré — pas encore disponible.", 14, Color(0.23, 0.14, 0.08, 0.6))
	if message != "":
		_bulle(message, 300.0, Y0 + 300.0)

# ---------------------------------------------------------------- la vérification

func _capture() -> void:
	var dossier := OS.get_environment("CHEMINS_CAPTURE")
	DirAccess.make_dir_recursive_absolute(dossier)
	m.acheter_loco()
	m.acheter_wagon("tombereau")
	m.acheter_wagon("tombereau")
	m.poser(m.centre, Vector2i(7, 5))
	m.poser(Vector2i(7, 5), Vector2i(6, 5))
	m.definir_itineraire([Vector2i(6, 5)] as Array[Vector2i])
	m.lancer()
	m.explorer(Vector2i(11, 6))
	for i in 12:
		m.avancer(10.0)
	_montrer()
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(dossier + "/carte.png")
	vue = "depot"
	_montrer()
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(dossier + "/depot.png")
	get_tree().quit()
