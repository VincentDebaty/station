extends Control
## L'ÉCRAN DES CARTES — choisir son territoire, et l'acheter.
##
## Transposition de js/parcours.js (vueCartes, lot H). Il n'apparaît qu'à
## partir de deux cartes : avec une seule, il n'y a rien à choisir. Tout ce
## qu'une tuile montre se déduit de la définition de la carte et de la
## progression enregistrée — rien n'est stocké pour l'affichage. La carte
## bancaire est hors prototype : le bouton prend la place, et ne fait rien.

const Rub := preload("res://jeu/ruban.gd")
const Rec := preload("res://jeu/recompense.gd")
const Sty := preload("res://jeu/style.gd")

const FOND := Color("#0E1420")
const TUILE := Color("#151d2e")
const BORD := Color("#2a3550")
const TEXTE := Color("#dbe2ee")
const MUET := Color("#7a8699")
const ACCENT := Color("#2dd4bf")
const OR := Color("#f5b23c")

var app = null
var colonne: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fond := ColorRect.new()
	fond.color = FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	# la zone sûre s'ajoute à la marge, elle ne la remplace pas
	for paire in [["left", "gauche"], ["right", "droite"], ["top", "haut"], ["bottom", "bas"]]:
		marge.add_theme_constant_override("margin_" + paire[0], int(28 * Sty.HUD_K + Sty.marges[paire[1]]))
	add_child(marge)
	colonne = VBoxContainer.new()
	colonne.add_theme_constant_override("separation", int(round(14 * Sty.HUD_K)))
	marge.add_child(colonne)


func _label(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Sty.sans(600 if taille >= 20 else 400))
	l.add_theme_font_size_override("font_size", int(round(taille * Sty.HUD_K)))
	l.add_theme_constant_override("line_spacing", int(round(5 * Sty.HUD_K)))
	l.add_theme_color_override("font_color", couleur)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _bouton(texte: String, principal: bool, actif: bool, sur: Callable) -> Button:
	var k := Sty.HUD_K
	var b := Sty.bouton(texte, principal, 15, k)
	b.disabled = not actif
	var sd := Sty.boite(Color("#1a2234"), Sty.BORD, 10 * k, max(1.0, k))
	sd.content_margin_top = 9 * k
	sd.content_margin_bottom = 9 * k
	sd.content_margin_left = 14 * k
	sd.content_margin_right = 14 * k
	b.add_theme_stylebox_override("disabled", sd)
	b.add_theme_color_override("font_disabled_color", Sty.MUET)
	if sur.is_valid():
		b.pressed.connect(sur)
	return b


## Ce qu'une carte montre d'elle-même avant d'être ouverte.
func resume_de_carte(id: String) -> Dictionary:
	var def: Dictionary = Donnees.cartes.get(id, {})
	var chs: Array = def["chapitres"] if def.get("chapitres") is Array else []
	var stations := {}
	var passees: Array = []
	for c in Sauvegarde.cartes_enregistrees():
		if c["id"] == id:
			stations = c["stations"]
			passees = c["passees"]
	var gares := 0
	var faites := 0
	var etoiles := 0
	for ch in chs:
		for g in (ch["gares"] if ch.get("gares") is Array else []):
			gares += 1
			var r: Variant = stations.get(g)
			var st: int = Rub.etoiles_de(r) if r is Dictionary else 0
			if st >= 1:
				faites += 1
			etoiles += st
	return {"def": def, "chapitres": chs.size(), "gares": gares, "faites": faites, "etoiles": etoiles,
		"entamee": faites > 0 or not passees.is_empty()}


func rebatir() -> void:
	for c in colonne.get_children():
		colonne.remove_child(c)
		c.queue_free()
	var solde: int = app.solde() if app != null else 0
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", int(round(16 * Sty.HUD_K)))
	entete.add_child(_bouton("‹  Revenir au ruban", false, true, app.fermer_cartes if app != null else Callable()))
	var titre := _label("Les cartes", 24, TEXTE)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(titre)
	entete.add_child(_label("%d cr" % solde, 15, MUET))
	colonne.add_child(entete)
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", int(round(18 * Sty.HUD_K)))
	colonne.add_child(rangee)
	var courante: Variant = Sauvegarde.get_carte_courante()
	for e in Donnees.cartes_index:
		var id := String(e.get("id", ""))
		var r := resume_de_carte(id)
		var possede: bool = Sauvegarde.possede_carte(id) or bool(e.get("gratuite", false))
		var prix: int = Rec.prix_de_carte(r["def"], e)
		var est_courante: bool = id == courante
		var tuile := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = TUILE
		st.border_color = ACCENT if est_courante else BORD
		st.set_border_width_all(1)
		for coin in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			st.set("corner_radius_" + coin, 12)
		st.set_content_margin_all(18)
		tuile.add_theme_stylebox_override("panel", st)
		tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tuile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tuile.custom_minimum_size = Vector2(420, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", int(round(6 * Sty.HUD_K)))
		tuile.add_child(v)
		var tete := HBoxContainer.new()
		var nom := _label(String(e.get("nom", r["def"].get("nom", id))), 20, TEXTE)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tete.add_child(nom)
		if est_courante:
			tete.add_child(_label("ici", 12, ACCENT))
		elif not possede:
			tete.add_child(_label("verrouillée", 12, MUET))
		v.add_child(tete)
		v.add_child(_label(String(e.get("sousTitre", "")), 13, MUET))
		v.add_child(_label("%d chapitre%s · %d gares" % [r["chapitres"], "s" if r["chapitres"] > 1 else "", r["gares"]], 13, TEXTE))
		if r["entamee"]:
			v.add_child(_label("%d / %d gares · ★ %d" % [r["faites"], r["gares"], r["etoiles"]], 13, OR))
		if est_courante:
			v.add_child(_bouton("Carte en cours", false, false, Callable()))
		elif possede:
			v.add_child(_bouton("Reprendre" if r["entamee"] else "Commencer", true, true,
				app.choisir_carte.bind(id) if app != null else Callable()))
		elif solde >= prix:
			v.add_child(_bouton("Ouvrir · %d cr" % prix, true, true,
				app.acheter_carte.bind(id) if app != null else Callable()))
		else:
			var manque := prix - solde
			v.add_child(_label("Il te manque %d crédit%s — gagne des étoiles sur ta carte en cours." % [manque, "s" if manque > 1 else ""], 12, MUET))
			v.add_child(_bouton("Ouvrir · %d cr" % prix, true, false, Callable()))
		if not possede:
			v.add_child(_bouton("Carte bancaire — bientôt", false, false, Callable()))
		rangee.add_child(tuile)
