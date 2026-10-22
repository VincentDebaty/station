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

const FOND := Color("#1f2430")
const PANNEAU := Color("#2b3140")
const TEXTE := Color("#f1efe8")
const DISCRET := Color("#9b9a92")
const COULEURS := {
	"depot": Color("#7f77dd"), "prairie": Color("#97c459"), "charbon": Color("#5f5e5a"),
	"foret": Color("#1d9e75"), "fer": Color("#d85a30"), "lac": Color("#378add"),
	"ferme": Color("#ba7517"), "carriere": Color("#d4537e"), "ville": Color("#e24b4a"),
	"friche": Color("#3a4152"), "terre": Color("#3a4152")}
const LETTRES := {"depot": "D", "charbon": "C", "foret": "B", "fer": "Fe", "lac": "E",
	"ferme": "Bl", "carriere": "P", "ville": "V"}
const COUL_WAGON := {"tombereau": Color("#888780"), "citerne": Color("#378add"),
	"couvert": Color("#ba7517"), "plat": Color("#1d9e75")}
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
	police = ThemeDB.fallback_font
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
	b.add_theme_font_size_override("font_size", 18)
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

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(600, 1300)), FOND)
	_barre()
	if vue == "carte":
		_dessiner_carte()
	else:
		_dessiner_depot()

func _barre() -> void:
	_texte(Vector2(14, 34), "Or %d" % m.or_, 26, TEXTE)
	_texte(Vector2(150, 34), "Bois %d" % m.bois, 22, TEXTE)
	_texte(Vector2(260, 34), "Fer %d" % m.fer, 22, TEXTE)
	_texte(Vector2(350, 34), "Charbon %d/100" % m.charbon, 22, TEXTE)
	var h := m.temps / 3600.0
	_texte(Vector2(14, 66), "Temps de jeu : %d h %02d min" % [int(h), int(fmod(m.temps / 60.0, 60.0))], 18, DISCRET)
	if not m.train.is_empty():
		_texte(Vector2(14, 92), "Train : " + String(m.train["message"]), 18, Color("#b5d4f4"))
	_texte(Vector2(14, 124), message, 18, TEXTE)

func _dessiner_carte() -> void:
	for y in m.hauteur:
		for x in m.largeur:
			var c := Vector2i(x, y)
			var ctr := _centre_case(c)
			var poly := _octogone(ctr, CASE / 2.0 - 1.5, 8.0)
			if m.connues.has(c):
				var t := m.type_case(c)
				var col: Color = COULEURS[t]
				draw_colored_polygon(poly, col)
				if LETTRES.has(t):
					_texte(ctr + Vector2(0, 6), LETTRES[t], 16, Color("#101218"), true)
			else:
				var voisin := false
				for n in m.voisins(c):
					if m.connues.has(n):
						voisin = true
				draw_colored_polygon(poly, Color("#272c39"))
				if voisin:
					draw_polyline(poly + PackedVector2Array([poly[0]]), Color("#6b7388"), 1.0)
					_texte(ctr + Vector2(0, 5), "50", 13, DISCRET, true)
	for k in m.aretes:
		var p := String(k).split("|")
		var a := p[0].split(",")
		var b := p[1].split(",")
		var pa := _centre_case(Vector2i(int(a[0]), int(a[1])))
		var pb := _centre_case(Vector2i(int(b[0]), int(b[1])))
		draw_line(pa, pb, Color("#d3d1c7"), 5.0)
		draw_line(pa, pb, Color("#4b5063"), 1.5)
	for i in selection.size():
		var q := _centre_case(selection[i])
		draw_arc(q, 14.0, 0.0, TAU, 20, Color("#fac775"), 3.0)
		_texte(q + Vector2(10, -12), str(i + 1), 16, Color("#fac775"))
	if mode == "construire":
		draw_arc(_centre_case(tete), 13.0, 0.0, TAU, 24, Color("#85b7eb"), 3.0)
	if not m.train.is_empty() and m.chemin.size() > 1:
		var i: int = m.train["i"]
		var a2 := _centre_case(m.chemin[i])
		var pos := a2
		if m.train["etat"] == "roule" and i < m.chemin.size() - 1:
			var f: float = float(m.train["t"]) / float(m.N["locomotive"]["secondes_par_case"])
			pos = a2.lerp(_centre_case(m.chemin[i + 1]), clampf(f, 0.0, 1.0))
		draw_circle(pos, 9.0, Color("#185fa5"))
		draw_arc(pos, 9.0, 0.0, TAU, 16, Color.WHITE, 2.0)
	_texte(Vector2(14, Y0 + CASE * m.hauteur + 24), "D dépôt · C charbon · B forêt · Fe fer · E lac · Bl ferme · P carrière · V ville", 15, DISCRET)
	_texte(Vector2(14, Y0 + CASE * m.hauteur + 44), "Voie : 2 bois + 1 fer par case, virage de 45° au plus.", 15, DISCRET)

func _dessiner_depot() -> void:
	draw_rect(Rect2(11, Y0, 578, 440), PANNEAU)
	_texte(Vector2(26, Y0 + 34), "Dépôt principal · niveau 1", 24, TEXTE)
	_texte(Vector2(26, Y0 + 58), "1 voie · quai de 5 emplacements", 16, DISCRET)
	var yv := Y0 + 180.0
	draw_rect(Rect2(20, yv + 34, 560, 6), Color("#9b9a92"))
	for i in 28:
		draw_rect(Rect2(26 + i * 20, yv + 30, 5, 14), Color("#5f5e5a"))
	for s in 6:
		var x := 24.0 + s * 93.0
		var r := Rect2(x, yv - 20, 86, 50)
		if s == 0:
			if m.loco:
				draw_rect(r, Color("#444441"))
				draw_rect(Rect2(x + 52, yv - 32, 26, 14), Color("#444441"))
				_texte(Vector2(x + 43, yv + 10), "Loco", 17, TEXTE, true)
				draw_circle(Vector2(x + 22, yv + 38), 7.0, Color("#2c2c2a"))
				draw_circle(Vector2(x + 62, yv + 38), 7.0, Color("#2c2c2a"))
			else:
				draw_rect(r, Color("#5f5e5a"), false, 1.0)
				_texte(Vector2(x + 43, yv + 10), "Loco ?", 15, DISCRET, true)
		elif s - 1 < m.wagons.size():
			var w: String = m.wagons[s - 1]
			draw_rect(r, COUL_WAGON[w])
			_texte(Vector2(x + 43, yv), NOM_WAGON[w], 14, Color.WHITE, true)
			var cont: Dictionary = m.contenus[s - 1]
			_texte(Vector2(x + 43, yv + 20), "%d / 20" % int(cont["n"]), 15, Color.WHITE, true)
			draw_circle(Vector2(x + 20, yv + 38), 6.0, Color("#2c2c2a"))
			draw_circle(Vector2(x + 66, yv + 38), 6.0, Color("#2c2c2a"))
		else:
			draw_rect(r, Color("#454b5d"), false, 1.0)
	_texte(Vector2(26, Y0 + 130), "%d wagon(s) sur 5" % m.wagons.size(), 16, DISCRET)
	var stocks := [["Charbon", "%d / 100" % m.charbon], ["Bois", str(m.bois)], ["Fer", str(m.fer)], ["Pierre", str(m.pierre)], ["Or", str(m.or_)]]
	for i in stocks.size():
		var x2 := 20.0 + i * 112.0
		draw_rect(Rect2(x2, Y0 + 320, 104, 70), Color("#3a4152"))
		_texte(Vector2(x2 + 8, Y0 + 344), stocks[i][0], 15, DISCRET)
		_texte(Vector2(x2 + 8, Y0 + 376), stocks[i][1], 21, TEXTE)
	_texte(Vector2(26, Y0 + 424), "Améliorer le dépôt (niveau 2) : 500 or + bois livré — pas encore disponible.", 14, DISCRET)

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
