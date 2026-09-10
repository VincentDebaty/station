class_name Boutique
extends Control
## LA BOUTIQUE DES PIERRES — une modale, ouverte depuis l'échec sans le sou
## (« Obtenir des pierres ») et depuis l'écran des cartes. Elle liste les
## lots de data/boutique.json avec leur prix, et passe la commande au Magasin.
## Elle ne vend que ce que le catalogue porte : rien d'autre n'a de bouton.

const Sty := preload("res://jeu/style.gd")

var sur_fini: Callable = Callable()
var avis: Label


## Ouvre la boutique par-dessus `parent`, à la taille de l'écran. `apres` est
## rappelé quand un achat aboutit, pour que l'écran d'en dessous se refasse.
static func ouvrir(parent: Node, apres: Callable = Callable()) -> Boutique:
	var b := Boutique.new()
	b.sur_fini = apres
	parent.add_child(b)
	b._batir()
	return b


func _batir() -> void:
	var k := Sty.HUD_K
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var voile := Button.new()
	voile.size = size
	voile.focus_mode = Control.FOCUS_NONE
	for quoi in ["normal", "hover", "pressed", "focus"]:
		voile.add_theme_stylebox_override(quoi, Sty.boite(Color(Sty.BOIS, 0.82), Color(0, 0, 0, 0), 0, 0))
	voile.pressed.connect(fermer)
	add_child(voile)
	var centre := CenterContainer.new()
	centre.size = size
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var carte := PanelContainer.new()
	var st := Sty.parchemin(Sty.R_GRAND, k)
	st.set_content_margin_all(22 * k)
	carte.add_theme_stylebox_override("panel", st)
	carte.custom_minimum_size = Vector2(min(430.0 * k, size.x * 0.7), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(8 * k)))
	carte.add_child(v)
	centre.add_child(carte)

	v.add_child(_encre("Des pierres", 12, Sty.SARCELLE, false))
	v.add_child(_encre("La pierre du sans-faute", 22, Sty.ENCRE, true))
	v.add_child(_encre("Une pierre paie un passage quand les pièces manquent. Elle n'achète ni étoile, ni rang, ni carte.", 13, Sty.ENCRE_MUET, false))
	for o in Magasin.offres_de_pierres():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(round(10 * k)))
		var l := _encre("%d pierres" % int(o.get("pierres", 0)), 15, Sty.ENCRE, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		var b := Sty.bouton_plaque(Magasin.prix_de(o), true, 14, k, 14.0, 9.0)
		b.disabled = not Magasin.disponible()
		b.custom_minimum_size = Vector2(120 * k, 0)
		b.pressed.connect(_acheter.bind(String(o.get("id", ""))))
		h.add_child(b)
		v.add_child(h)
	avis = _encre(Magasin.EXPLICATION if not Magasin.disponible() else "", 12, Color("#a2432f"), false)
	v.add_child(avis)
	var pied := HBoxContainer.new()
	pied.add_theme_constant_override("separation", int(round(8 * k)))
	var plus_tard := Sty.bouton_plaque("Plus tard", false, 14, k, 14.0, 9.0)
	plus_tard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plus_tard.pressed.connect(fermer)
	pied.add_child(plus_tard)
	v.add_child(pied)
	Magasin.fini.connect(_sur_fini)


func _encre(texte: String, taille: int, couleur: Color, titre: bool) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Sty.titre(600) if titre else Sty.sans(400))
	l.add_theme_font_size_override("font_size", int(round(taille * Sty.HUD_K)))
	l.add_theme_color_override("font_color", couleur)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _acheter(id: String) -> void:
	avis.text = "…"
	Magasin.acheter(id)


func _sur_fini(id: String, ok: bool, message: String) -> void:
	if ok:
		var o := Magasin.offre(id)
		avis.text = "+ %d pierres." % int(o.get("pierres", 0)) if o.get("type") == "pierres" else "C'est fait."
		if sur_fini.is_valid():
			sur_fini.call()
	else:
		avis.text = message


func fermer() -> void:
	if Magasin.fini.is_connected(_sur_fini):
		Magasin.fini.disconnect(_sur_fini)
	queue_free()
