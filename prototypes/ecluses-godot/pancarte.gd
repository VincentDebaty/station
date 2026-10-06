class_name Pancarte
extends VBoxContainer
# ------------------------------------------------------------------
# LA PANCARTE DE FIN — le panneau d'éclusier choisi par Vincent sur sa
# maquette ChatGPT (6 octobre 2026) : une planche de chêne aux coins ferrés,
# suspendue à deux cordes, qui descend en se balançant.
#
#   échec      « Bateaux coincés ! », puis [Annuler le coup] [Rejouer]
#              (Vincent a voulu Annuler d'abord, Rejouer ensuite)
#   victoire   les étoiles, « Passé ! », puis [Rejouer] [Niveau suivant]
#
# Les pièces sont des images vierges (art/panneau_bois.png, corde.png,
# bouton_vert.png, bouton_creme.png, icone_*.png) ; le texte est écrit par le
# jeu, crème cerclé de brun comme sur la maquette. La planche est découpée en
# neuf (StyleBoxTexture) : elle s'étire à la taille du texte sans déformer ses
# ferrures.
# ------------------------------------------------------------------

signal annuler
signal rejouer
signal suivant

const CREME := Color("#fff3dc")
const MARGE_BAS := 64.0      # au-dessus des boutons du bas
const BRUN := Color("#5b3416")

var _planche: PanelContainer
var _balance: Control
var _etoiles: Etoiles
var _titre: Label
var _sous_titre: Label
var _b_annuler: Button
var _b_rejouer: Button
var _b_suivant: Button

func _init() -> void:
	add_theme_constant_override("separation", -26)      # les cordes passent derrière le haut de la planche
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# les deux cordes
	var cordes := HBoxContainer.new()
	cordes.alignment = BoxContainer.ALIGNMENT_CENTER
	cordes.add_theme_constant_override("separation", 330)
	cordes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_corde := Images.reduire("res://art/corde.png", 60)
	for _k in 2:
		var c := TextureRect.new()
		c.texture = tex_corde
		c.custom_minimum_size = Vector2(42, 112)
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cordes.add_child(c)
	add_child(cordes)
	# la planche
	_planche = PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = Images.reduire("res://art/panneau_bois.png", 820)
	st.set_texture_margin_all(88.0)                    # les coins ferrés restent entiers
	st.content_margin_left = 64; st.content_margin_right = 64
	st.content_margin_top = 58; st.content_margin_bottom = 46     # le texte reste sur les planches, sous le bord ferré
	_planche.add_theme_stylebox_override("panel", st)
	_planche.custom_minimum_size = Vector2(660, 0)
	add_child(_planche)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_planche.add_child(col)
	_etoiles = Etoiles.new()
	_etoiles.taille = 68.0
	_etoiles.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_etoiles)
	_titre = _texte(52, 12)
	col.add_child(_titre)
	_sous_titre = _texte(28, 8)
	col.add_child(_sous_titre)
	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 22)
	col.add_child(boutons)
	_b_annuler = _bouton("Annuler le coup", "res://art/bouton_creme.png", "res://art/icone_annuler.png", Color("#6b3a18"), Color(0, 0, 0, 0))
	_b_rejouer = _bouton("Rejouer", "res://art/bouton_vert.png", "res://art/icone_rejouer.png", Color.WHITE, Color("#1d5f12"))
	_b_suivant = _bouton("Niveau suivant", "res://art/bouton_vert.png", "res://art/icone_suivant.png", Color.WHITE, Color("#1d5f12"))
	_b_annuler.pressed.connect(func(): annuler.emit())
	_b_rejouer.pressed.connect(func(): rejouer.emit())
	_b_suivant.pressed.connect(func(): suivant.emit())
	boutons.add_child(_b_annuler)
	boutons.add_child(_b_rejouer)
	boutons.add_child(_b_suivant)
	hide()

func _texte(taille: int, contour: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", CREME)
	l.add_theme_color_override("font_outline_color", BRUN)
	l.add_theme_constant_override("outline_size", contour)
	return l

func _bouton(texte: String, fond: String, icone: String, encre: Color, contour: Color) -> Button:
	var b := Button.new()
	b.text = texte
	b.icon = Images.reduire(icone, 64)
	b.add_theme_constant_override("icon_max_width", 40)
	b.add_theme_constant_override("h_separation", 12)
	b.add_theme_font_size_override("font_size", 30)
	for nom in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(nom, encre)
	b.add_theme_color_override("font_outline_color", contour)
	b.add_theme_constant_override("outline_size", 8 if contour.a > 0.0 else 0)
	var tex := Images.reduire(fond, 270)
	for etat in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.texture_margin_left = 44; st.texture_margin_right = 44
		st.content_margin_left = 30; st.content_margin_right = 34
		if etat == "pressed": st.modulate_color = Color(0.86, 0.86, 0.86)
		if etat == "focus": st.texture = null
		b.add_theme_stylebox_override(etat, st)
	b.custom_minimum_size = Vector2(0, 90)
	return b

func montrer_echec(plusieurs: bool) -> void:
	_etoiles.hide()
	_titre.text = "Bateaux coincés !" if plusieurs else "Bateau coincé !"
	_sous_titre.text = "Plus aucun bateau ne peut avancer."
	_b_annuler.show(); _b_rejouer.show(); _b_suivant.hide()
	_descendre()

func montrer_victoire(etoiles: int, texte: String, avec_suivant: bool) -> void:
	_etoiles.show()
	_etoiles.regler(etoiles)
	_titre.text = "Passé !"
	_sous_titre.text = texte
	_b_annuler.hide(); _b_rejouer.show(); _b_suivant.visible = avec_suivant
	_descendre()

# La pancarte descend et se balance un peu au bout de ses cordes. On la place
# soi-même, une fois sa taille connue : centrée, en bas, sur la terre, au-dessus
# des boutons (un ancrage au centre ne suivait pas son changement de taille à
# l'apparition, et elle se retrouvait en haut à gauche).
func _descendre() -> void:
	modulate.a = 0.0
	show()
	await get_tree().process_frame
	var cadre := (get_parent() as Control).size
	size = get_combined_minimum_size()
	var y := cadre.y - size.y - MARGE_BAS
	position = Vector2((cadre.x - size.x) * 0.5, y - 70.0)
	pivot_offset = Vector2(size.x * 0.5, 0.0)
	rotation = 0.05
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.tween_property(self, "position:y", y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation", 0.0, 1.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
