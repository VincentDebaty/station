class_name Pancarte
extends VBoxContainer
# ------------------------------------------------------------------
# LA PANCARTE DE FIN — le panneau d'éclusier des maquettes ChatGPT choisies
# par Vincent (6 octobre 2026) : une planche de chêne aux coins ferrés,
# suspendue à deux cordes, qui tombe puis se balance.
#
#   échec      « Bateaux coincés ! », puis [Annuler le coup] (crème)
#              [Rejouer] (vert) — Vincent a voulu Annuler d'abord
#   victoire   trois étoiles en arc AU-DESSUS de la planche, entre les cordes
#              (celle du milieu plus grande), « Passé ! », puis
#              [Rejouer] (crème) [Niveau suivant] (vert)
#
# Au-dessus de la planche, un bandeau porte les cordes et les étoiles ; il est
# disposé une fois la taille de la planche connue, d'après sa position réelle
# (deviner le bord du bois laissait les cordes pendre dans le vide). Les
# pièces sont des images vierges (art/), recadrées sur leurs pixels visibles ;
# le texte est écrit par le jeu, crème cerclé de brun. La planche est découpée
# en neuf (StyleBoxTexture) : elle s'étire sans déformer ses ferrures.
# ------------------------------------------------------------------

signal annuler
signal rejouer
signal suivant

const CREME := Color("#fff3dc")
const BRUN := Color("#5b3416")
const MARGE_BAS := 56.0       # au-dessus des boutons du bas de l'écran
const RECOUVREMENT := 30.0    # de combien la planche passe devant le bas des cordes

var _entete: Control
var _cordes := []
var _planche: PanelContainer
var _etoiles: Etoiles
var _titre: Label
var _sous_titre: Label
var _b_annuler: Button
var _b_rejouer: Button          # vert (échec, ou victoire sans niveau suivant)
var _b_rejouer_creme: Button    # crème (victoire, à droite de « Niveau suivant »)
var _b_suivant: Button
var _balance_t := -1.0
var _sous_etoiles: Control      # la place que mordent les étoiles sur la planche (victoire)

func _init() -> void:
	add_theme_constant_override("separation", -int(RECOUVREMENT))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# le bandeau du haut : les cordes, et les étoiles de la victoire
	_entete = Control.new()
	_entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_entete)
	var tex_corde := Images.reduire("res://art/corde.png", 40)
	for _k in 2:
		var c := TextureRect.new()
		c.texture = tex_corde
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_SCALE
		c.size = Vector2(28, 118)
		_entete.add_child(c)
		_cordes.append(c)
	_etoiles = Etoiles.new()
	_etoiles.taille = 82.0
	_etoiles.en_arc = true
	_etoiles.z_index = 2           # devant le bord de la planche
	_entete.add_child(_etoiles)
	# la planche
	_planche = PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = Images.reduire("res://art/panneau_bois.png", 900)
	st.texture_margin_left = 100; st.texture_margin_right = 100
	st.texture_margin_top = 100; st.texture_margin_bottom = 100   # planche recadrée : 900 × 333
	# de l'air entre le bord ferré et le texte ou les boutons (Vincent : « besoin
	# de plus d'espace au bord du panneau »)
	st.content_margin_left = 90; st.content_margin_right = 90
	st.content_margin_top = 80; st.content_margin_bottom = 66
	_planche.add_theme_stylebox_override("panel", st)
	_planche.custom_minimum_size = Vector2(820, 0)
	add_child(_planche)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	_planche.add_child(col)
	_sous_etoiles = Control.new()
	_sous_etoiles.custom_minimum_size = Vector2(0, 10)
	col.add_child(_sous_etoiles)
	_titre = _texte(58, 14)
	col.add_child(_titre)
	_sous_titre = _texte(30, 9)
	# la raison d'un échec peut tenir sur deux lignes
	_sous_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sous_titre.custom_minimum_size = Vector2(640, 0)
	col.add_child(_sous_titre)
	var air := Control.new()
	air.custom_minimum_size = Vector2(0, 14)
	col.add_child(air)
	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 40)
	col.add_child(boutons)
	var vert := Color("#1d5f12")
	var brun := Color("#6b3a18")
	_b_suivant = _bouton("Niveau suivant", "res://art/bouton_vert.png", "res://art/icone_suivant.png", Color.WHITE, vert, Color.WHITE)
	_b_annuler = _bouton("Annuler le coup", "res://art/bouton_creme.png", "res://art/icone_annuler.png", brun, Color(0, 0, 0, 0), Color.WHITE)
	_b_rejouer = _bouton("Rejouer", "res://art/bouton_vert.png", "res://art/icone_rejouer.png", Color.WHITE, vert, Color.WHITE)
	# sur le bouton crème, la flèche blanche passe au brun, comme sur la maquette
	_b_rejouer_creme = _bouton("Rejouer", "res://art/bouton_creme.png", "res://art/icone_rejouer.png", brun, Color(0, 0, 0, 0), brun)
	_b_annuler.pressed.connect(func(): annuler.emit())
	_b_rejouer.pressed.connect(func(): rejouer.emit())
	_b_rejouer_creme.pressed.connect(func(): rejouer.emit())
	_b_suivant.pressed.connect(func(): suivant.emit())
	# échec : [Annuler le coup] [Rejouer] ; victoire : [Rejouer] [Niveau suivant]
	# (Vincent a voulu, dans les deux cas, revenir en arrière à gauche et
	# avancer à droite)
	for b in [_b_annuler, _b_rejouer_creme, _b_rejouer, _b_suivant]: boutons.add_child(b)
	# les cordes et les étoiles suivent la planche réelle, à chaque fois que la
	# mise en page la déplace ou la redimensionne
	_planche.item_rect_changed.connect(_disposer)
	hide()

func _texte(taille: int, contour: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", CREME)
	l.add_theme_color_override("font_outline_color", BRUN)
	l.add_theme_constant_override("outline_size", contour)
	return l

func _bouton(texte: String, fond: String, icone: String, encre: Color, contour: Color, teinte_icone: Color) -> Button:
	var b := Button.new()
	b.text = texte
	b.icon = Images.reduire(icone, 96)
	b.add_theme_constant_override("icon_max_width", 46)
	b.add_theme_constant_override("h_separation", 14)
	b.add_theme_font_size_override("font_size", 30)
	for nom in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(nom, encre)
	for nom in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(nom, teinte_icone)
	b.add_theme_color_override("font_outline_color", contour)
	b.add_theme_constant_override("outline_size", 9 if contour.a > 0.0 else 0)
	var tex := Images.reduire(fond, 330)
	for etat in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.texture_margin_left = 42; st.texture_margin_right = 42     # bouton recadré : 330 × 84
		st.content_margin_left = 36; st.content_margin_right = 40
		if etat == "pressed": st.modulate_color = Color(0.86, 0.86, 0.86)
		if etat == "focus": st.texture = null
		b.add_theme_stylebox_override(etat, st)
	b.custom_minimum_size = Vector2(270, 90)
	return b

# « pourquoi » : la raison, en une phrase (principal.gd la trouve) ; sans
# elle, le constat seul.
func montrer_echec(plusieurs: bool, pourquoi := "", titre := "") -> void:
	_etoiles.hide()
	_sous_etoiles.hide()
	_titre.text = titre if titre != "" else ("Bateaux coincés !" if plusieurs else "Bateau coincé !")
	_sous_titre.text = pourquoi if pourquoi != "" else "Plus aucun bateau ne peut avancer."
	for b in [_b_suivant, _b_rejouer_creme]: b.hide()
	for b in [_b_annuler, _b_rejouer]: b.show()
	_descendre()

func montrer_victoire(etoiles: int, texte: String, avec_suivant: bool) -> void:
	_etoiles.show()
	_sous_etoiles.show()
	_etoiles.regler(etoiles)
	_etoiles.animer()
	_titre.text = "Passé !"
	_sous_titre.text = texte
	_b_annuler.hide()
	_b_suivant.visible = avec_suivant
	_b_rejouer_creme.visible = avec_suivant
	_b_rejouer.visible = not avec_suivant
	_descendre()

# Le bandeau du haut, disposé d'après la position RÉELLE de la planche — à
# chaque fois que la mise en page la déplace (item_rect_changed) : les cordes
# tombent vers le cinquième et les quatre cinquièmes de sa largeur et
# descendent 60 px derrière son bord haut, la part en trop cachée par le bois ;
# les étoiles, centrées, mordent sur ce bord. (Mesurée trop tôt, la position de
# la planche était périmée et les cordes s'arrêtaient au-dessus du bois.)
func _disposer() -> void:
	var avec_etoiles := _etoiles.visible
	var h := 150.0 if avec_etoiles else 112.0
	_entete.custom_minimum_size = Vector2(0, h)
	var w := _planche.size.x
	var bord := _planche.position.y - _entete.position.y     # le haut de la planche, dans le repère du bandeau
	for k in 2:
		var c: TextureRect = _cordes[k]
		c.size = Vector2(34, bord + 60.0)
		c.position = Vector2(w * (0.19 if k == 0 else 0.81) - c.size.x * 0.5, 0.0)
	if avec_etoiles:
		var t := _etoiles.get_combined_minimum_size()
		_etoiles.size = t
		_etoiles.position = Vector2((w - t.x) * 0.5, bord + 40.0 - t.y)

# La pancarte tombe, puis se balance comme un pendule au bout de ses cordes.
# On la place soi-même une fois sa taille connue : centrée, en bas, au-dessus
# des boutons de l'écran.
func _descendre() -> void:
	modulate.a = 0.0
	show()
	await get_tree().process_frame
	_disposer()
	await get_tree().process_frame
	var cadre := (get_parent() as Control).size
	size = get_combined_minimum_size()
	_disposer()
	var y := cadre.y - size.y - MARGE_BAS
	position = Vector2((cadre.x - size.x) * 0.5, y - 110.0)
	pivot_offset = Vector2(size.x * 0.5, 0.0)
	_balance_t = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.tween_property(self, "position:y", y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Le balancement : une oscillation de pendule qui s'amortit, accrochée au milieu
# du bord haut. Amplitude de départ ~8°, ~2,5 s.
func _process(dt: float) -> void:
	if _balance_t < 0.0: return
	_balance_t += dt
	rotation = 0.14 * exp(-_balance_t * 1.5) * sin(_balance_t * 6.2 + 0.4)
	if _balance_t > 3.5:
		rotation = 0.0
		_balance_t = -1.0
