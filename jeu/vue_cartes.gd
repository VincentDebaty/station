extends Control
## L'ÉCRAN DES CARTES — choisir son territoire, et l'acheter.
##
## Transposition de js/parcours.js (vueCartes, lot H). Il n'apparaît qu'à
## partir de deux cartes : avec une seule, il n'y a rien à choisir. Tout ce
## qu'une tuile montre se déduit de la définition de la carte et de la
## progression enregistrée — rien n'est stocké pour l'affichage. La carte
## bancaire est hors prototype : le bouton prend la place, et ne fait rien.
##
## IL ÉTAIT RESTÉ À L'ANCIENNE PALETTE (5 septembre 2026). Le bleu nuit du
## prototype, des rayons de 12 posés en dur sans facteur d'échelle, les
## boutons de `Sty.bouton` par défaut : dès que le glissement l'a mis à une
## demi-seconde du ruban, on a vu deux applications au lieu d'une. Il passe au
## parchemin, et à la trame commune — trois rayons, deux traits.

const Rub := preload("res://jeu/ruban.gd")
const Rec := preload("res://jeu/recompense.gd")
const Sty := preload("res://jeu/style.gd")
const Ill := preload("res://jeu/illustrations.gd")

const TEXTE := Sty.PAPIER
const MUET := Color("#a28f74")
const OR := Sty.LAITON

var app = null
var colonne: VBoxContainer


func _ready() -> void:
	# UN CONTROL SOUS UN NŒUD QUI N'EN EST PAS UN N'A PAS DE TAILLE. Ses ancres
	# ne s'appuient sur rien : il reste à zéro, ses enfants avec lui, et le fond
	# comme les marges disparaissent — mesuré le 5 septembre 2026, l'écran des
	# cartes se dessinait dans un rectangle vide et empruntait la couleur
	# d'effacement du ruban. On lui pose donc sa taille, et on la lui repose à
	# chaque changement d'écran.
	# On tient sa taille à la main plutôt que par des ancres : des ancres
	# opposées se recalculent après `_ready` et Godot le dit dans un
	# avertissement — ici, c'est nous qui savons.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ajuster()
	get_viewport().size_changed.connect(_ajuster)
	var fond := ColorRect.new()
	fond.color = Sty.BOIS
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	# la zone sûre s'ajoute à la marge, elle ne la remplace pas
	for paire in [["left", "gauche"], ["right", "droite"], ["top", "haut"], ["bottom", "bas"]]:
		marge.add_theme_constant_override("margin_" + paire[0], int(24 * Sty.HUD_K + Sty.marges[paire[1]]))
	add_child(marge)
	colonne = VBoxContainer.new()
	colonne.add_theme_constant_override("separation", int(round(14 * Sty.HUD_K)))
	marge.add_child(colonne)


func _ajuster() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _label(texte: String, taille: int, couleur: Color, titre: bool = false, replie: bool = true) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Sty.titre(600) if titre else Sty.sans(400))
	l.add_theme_font_size_override("font_size", int(round(taille * Sty.HUD_K)))
	l.add_theme_constant_override("line_spacing", int(round(3 * Sty.HUD_K)))
	l.add_theme_color_override("font_color", couleur)
	if replie:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## LE MÊME BOUTON QUE SUR LE RUBAN : plaque vissée, sarcelle pour l'appel,
## bois pour le reste, texte sur le papier. Deux écrans qui se répondent en
## une demi-seconde ne peuvent pas avoir deux boutons différents.
func _bouton(texte: String, principal: bool, actif: bool, sur: Callable) -> Button:
	var b := Sty.bouton_plaque(texte, principal, 14, Sty.HUD_K, 14.0, 9.0)
	b.disabled = not actif
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sur.is_valid():
		b.pressed.connect(sur)
	return b


## Le retour : un chevron et un mot, sans cadre — le pendant exact du bouton
## « Les cartes » de la barre du ruban. Il pointe à droite, parce que le ruban
## est à droite : c'est de là qu'il revient.
func _retour() -> Button:
	var b := Sty.lien("Le ruban", Sty.HUD_K, false)
	if app != null:
		b.pressed.connect(app.fermer_cartes)
	return b


## Une pastille de compteur, celle de la barre du ruban.
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


## LA BANNIÈRE D'UNE CARTE : celle de sa première zone. Une carte n'a pas
## d'illustration à elle — il en faudrait une par carte, donc une par carte à
## venir — mais elle a des zones, et chaque zone a son paysage. La première
## dit d'où l'on part, ce qui est exactement ce qu'on demande à une vignette
## de choix.
func _banniere_de(def: Dictionary) -> Texture2D:
	var zones: Array = def["zones"] if def.get("zones") is Array else []
	for z in zones:
		var t := Ill.banniere(z.get("id", ""))
		if t != null:
			return t
	return null


func rebatir() -> void:
	for c in colonne.get_children():
		colonne.remove_child(c)
		c.queue_free()
	var k := Sty.HUD_K
	var solde: int = app.solde() if app != null else 0

	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", int(round(14 * k)))
	var titre := _label("Les cartes", 22, TEXTE, true)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	entete.add_child(titre)
	entete.add_child(_pastille("%d cr" % solde, Sty.LAITON))
	entete.add_child(_retour())
	colonne.add_child(entete)

	# UNE TUILE PEUT ÊTRE PLUS HAUTE QUE L'ÉCRAN — celle qu'on n'a pas encore
	# achetée porte deux boutons et une phrase d'explication de plus. Elle
	# débordait sous le bord bas. Le rang défile donc, sans montrer sa barre :
	# la même solution que la colonne du ruban, et pour la même raison.
	var defil := ScrollContainer.new()
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(defil)
	var bar := defil.get_v_scroll_bar()
	for quoi in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(quoi, StyleBoxEmpty.new())
	bar.custom_minimum_size = Vector2.ZERO
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", int(round(16 * k)))
	rangee.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defil.add_child(rangee)
	var courante: Variant = Sauvegarde.get_carte_courante()
	for e in Donnees.cartes_index:
		var id := String(e.get("id", ""))
		var r := resume_de_carte(id)
		var possede: bool = Sauvegarde.possede_carte(id) or bool(e.get("gratuite", false))
		var prix: int = Rec.prix_de_carte(r["def"], e)
		var est_courante: bool = id == courante
		rangee.add_child(_tuile(e, id, r, possede, prix, est_courante, solde))


func _tuile(e: Dictionary, id: String, r: Dictionary, possede: bool, prix: int,
		est_courante: bool, solde: int) -> Control:
	var k := Sty.HUD_K
	var tuile := PanelContainer.new()
	var st := Sty.plaque(Sty.BOIS_CLAIR,
		Sty.LAITON_CLAIR if est_courante else Color(Sty.LAITON, 0.55), Sty.R_GRAND, k)
	st.set_content_margin_all(12 * k)
	tuile.add_theme_stylebox_override("panel", st)
	tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tuile.custom_minimum_size = Vector2(260 * k, 0)
	tuile.clip_contents = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(6 * k)))
	tuile.add_child(v)

	var img := _banniere_de(r["def"])
	if img != null:
		var cadre := PanelContainer.new()
		cadre.add_theme_stylebox_override("panel",
			Sty.boite(Color(0, 0, 0, 0), Color(Sty.LAITON, 0.45), Sty.R * k, Sty.epaisseur(k)))
		cadre.clip_contents = true
		var ti := TextureRect.new()
		ti.texture = img
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ti.custom_minimum_size = Vector2(0, 46 * k)
		cadre.add_child(ti)
		v.add_child(cadre)

	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", int(round(8 * k)))
	var nom := _label(String(e.get("nom", r["def"].get("nom", id))), 19, TEXTE, true)
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(nom)
	if est_courante:
		tete.add_child(_pastille("ici", Sty.SARCELLE_CLAIR))
	elif not possede:
		tete.add_child(_pastille("verrouillée", MUET))
	v.add_child(tete)

	v.add_child(_label(String(e.get("sousTitre", "")), 13, MUET))
	v.add_child(_label("%d chapitre%s · %d gares" % [
		r["chapitres"], "s" if r["chapitres"] > 1 else "", r["gares"]], 13, TEXTE))
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
		v.add_child(_label("Il te manque %d crédit%s — gagne des étoiles sur ta carte en cours."
			% [manque, "s" if manque > 1 else ""], 12, MUET))
		v.add_child(_bouton("Ouvrir · %d cr" % prix, true, false, Callable()))
	# LA CARTE BANCAIRE N'EST PAS UN BOUTON. Elle en portait un, éteint, qui ne
	# s'allumera pas dans ce prototype : un bouton qu'on ne peut pas presser
	# n'est pas une commande, c'est une phrase — et il coûtait la hauteur qui
	# faisait déborder la tuile sous le bord bas de l'écran.
	if not possede:
		v.add_child(_label("Ou par carte bancaire, bientôt.", 12, Color(MUET, 0.8)))
	return tuile
