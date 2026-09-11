extends Control
## L'ÉCRAN DES CARTES — choisir son territoire, et l'acheter.
##
## Transposition de js/parcours.js (vueCartes, lot H). Il n'apparaît qu'à
## partir de deux cartes : avec une seule, il n'y a rien à choisir. Tout ce
## qu'une tuile montre se déduit de la définition de la carte et de la
## progression enregistrée — rien n'est stocké pour l'affichage. L'achat en
## argent passe par le Magasin (lot 3) : une carte se paie en pièces OU en
## argent, le pack prend toutes les cartes, et « Restaurer mes achats » les
## retrouve depuis le magasin de la plateforme.
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
var modale: Control = null
var avis: Label = null          # ce que le Magasin a répondu en dernier
var attendu := ""               # l'offre dont on attend la réponse


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


## Une pastille de compteur, celle de la barre du ruban.
## LE SOLDE, AVEC SA PIÈCE : la même pastille que sur le ruban.
func _pastille_piece(n: int) -> Control:
	var k := Sty.HUD_K
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := Sty.boite(Color(Sty.LAITON, 0.10), Color(Sty.LAITON, 0.35), Sty.R_PETIT * k, Sty.epaisseur(k))
	st.content_margin_left = 8 * k
	st.content_margin_right = 9 * k
	st.content_margin_top = 3 * k
	st.content_margin_bottom = 3 * k
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(5 * k)))
	var piece := Piece.new(13.0 * k)
	piece.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(piece)
	var l := _label(Sty.nombre(n), 13, Sty.LAITON, true, false)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	p.add_child(h)
	return p


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
# ------------------------------------------------------------------
# LA MODALE D'ACHAT
# ------------------------------------------------------------------
## Toucher une carte verrouillée ne peut pas ne rien faire, et ne peut pas non
## plus l'ouvrir : elle propose de l'acheter. C'est le seul endroit du jeu où
## l'on dépense, donc le seul où le solde et le prix doivent se lire ensemble
## — le compteur de la barre est derrière le voile.
func _ouvrir_modale(id: String) -> void:
	_fermer_modale()
	var k := Sty.HUD_K
	var e := _entree(id)
	var r := resume_de_carte(id)
	var prix: int = Rec.prix_de_carte(r["def"], e)
	var solde: int = app.solde() if app != null else 0

	modale = Control.new()
	modale.set_anchors_preset(Control.PRESET_TOP_LEFT)
	modale.size = size
	add_child(modale)
	# LE VOILE FERME AUSSI. Un doigt posé à côté d'une boîte de dialogue veut
	# en sortir : c'est le geste que tout le monde essaie en premier.
	var voile := Button.new()
	voile.size = size
	voile.focus_mode = Control.FOCUS_NONE
	for quoi in ["normal", "hover", "pressed", "focus"]:
		voile.add_theme_stylebox_override(quoi,
			Sty.boite(Color(Sty.BOIS, 0.82), Color(0, 0, 0, 0), 0, 0))
	voile.pressed.connect(func() -> void: Sons.jouer("clic"))
	voile.pressed.connect(_fermer_modale)
	modale.add_child(voile)

	var centre := CenterContainer.new()
	centre.size = size
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modale.add_child(centre)

	var carte := PanelContainer.new()
	var st := Sty.parchemin(Sty.R_GRAND, k)
	st.set_content_margin_all(22 * k)
	carte.add_theme_stylebox_override("panel", st)
	carte.custom_minimum_size = Vector2(min(430.0 * k, size.x * 0.7), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(8 * k)))
	carte.add_child(v)
	centre.add_child(carte)

	v.add_child(_encre("Carte verrouillée", 12, Sty.SARCELLE, false))
	v.add_child(_encre(String(e.get("nom", r["def"].get("nom", id))), 22, Sty.ENCRE, true))
	v.add_child(_encre(String(e.get("sousTitre", "")), 13, Sty.ENCRE_MUET, false))
	v.add_child(_encre("%d chapitre%s · %d gares" % [
		r["chapitres"], "s" if r["chapitres"] > 1 else "", r["gares"]], 13, Sty.ENCRE, false))
	var assez := solde >= prix
	if not assez:
		v.add_child(_encre("Il te manque %s pièces." % Sty.nombre(prix - solde), 13, Color("#a2432f"), false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(8 * k)))
	h.add_child(_bouton("Plus tard", false, true, _fermer_modale))
	h.add_child(_bouton("Ouvrir · %s pièces" % Sty.nombre(prix), true, assez, _acheter.bind(id)))
	v.add_child(h)
	# OU EN ARGENT (lot 3). Le prix vient du catalogue, ou du magasin de la
	# plateforme s'il a répondu ; le bouton dit lui-même quand il ne peut rien.
	var o: Dictionary = Magasin.offre_de_carte(id)
	if not o.is_empty():
		v.add_child(_bouton("Acheter · %s" % Magasin.prix_de(o), false, Magasin.disponible(),
			_acheter_argent.bind(String(o.get("id", "")))))
		if not Magasin.disponible():
			v.add_child(_encre(Magasin.EXPLICATION, 12, Sty.ENCRE_MUET, false))


func _encre(texte: String, taille: int, couleur: Color, titre: bool) -> Label:
	var l := _label(texte, taille, couleur, titre)
	l.add_theme_color_override("font_color", couleur)
	return l


func _fermer_modale() -> void:
	if modale != null:
		modale.queue_free()
		modale = null


## Acheter, puis ENTRER. On ne vient pas de payer pour revenir à la liste.
func _acheter(id: String) -> void:
	if app == null:
		return
	app.acheter_carte(id)
	_fermer_modale()
	if Sauvegarde.possede_carte(id):
		app.choisir_carte(id)


## Acheter en argent : on passe la commande, et on attend le Magasin.
func _acheter_argent(offre_id: String) -> void:
	attendu = offre_id
	if not Magasin.fini.is_connected(_sur_fini):
		Magasin.fini.connect(_sur_fini)
	Magasin.acheter(offre_id)


func _sur_fini(offre_id: String, ok: bool, message: String) -> void:
	if Magasin.fini.is_connected(_sur_fini):
		Magasin.fini.disconnect(_sur_fini)
	var o := Magasin.offre(offre_id)
	attendu = ""
	if ok and o.get("type") == "carte" and app != null:
		_fermer_modale()
		var cid := String(o.get("carte", ""))
		if Sauvegarde.possede_carte(cid):
			app.choisir_carte(cid)
		return
	rebatir()
	if avis != null:
		avis.text = message if not ok else ("C'est fait." if offre_id != "restaurer" else "Tes achats sont de retour.")


func _restaurer() -> void:
	if not Magasin.fini.is_connected(_sur_fini):
		Magasin.fini.connect(_sur_fini)
	Magasin.restaurer()


func _entree(id: String) -> Dictionary:
	for e in Donnees.cartes_index:
		if String(e.get("id", "")) == id:
			return e
	return {}


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
	_fermer_modale()
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
	entete.add_child(_pastille_piece(solde))
	colonne.add_child(entete)

	# UNE LISTE HORIZONTALE QU'ON FAIT GLISSER AU DOIGT. Les cartes se
	# feuillettent, elles ne se déroulent pas : une carte est un objet qu'on
	# compare à celle d'à côté, et il en viendra plus de deux. Le rang défile
	# donc en largeur, sans montrer sa barre — le glissement tactile suffit.
	var defil := ScrollContainer.new()
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	defil.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(defil)
	var bar := defil.get_h_scroll_bar()
	for quoi in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(quoi, StyleBoxEmpty.new())
	bar.custom_minimum_size = Vector2.ZERO
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", int(round(16 * k)))
	rangee.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.add_child(rangee)
	var courante: Variant = Sauvegarde.get_carte_courante()
	for e in Donnees.cartes_index:
		var id := String(e.get("id", ""))
		var r := resume_de_carte(id)
		var possede: bool = Sauvegarde.possede_carte(id) or bool(e.get("gratuite", false))
		var prix: int = Rec.prix_de_carte(r["def"], e)
		var est_courante: bool = id == courante
		rangee.add_child(_tuile(e, id, r, possede, prix, est_courante, solde))

	# LE PIED DE L'ÉCRAN (lot 3) : le pack, et la restauration.
	# Ce qui se vend se lit d'un seul regard, sous les cartes.
	var pied := HBoxContainer.new()
	pied.add_theme_constant_override("separation", int(round(12 * k)))
	var pack: Dictionary = Magasin.offre_pack()
	if not pack.is_empty():
		if Magasin.possede_pack():
			pied.add_child(_pastille("Pack du poste — acquis", Sty.SARCELLE_CLAIR))
		else:
			var bp := _bouton("Le pack du poste · %s" % Magasin.prix_de(pack), true, Magasin.disponible(),
				_acheter_argent.bind(String(pack.get("id", ""))))
			bp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bp.custom_minimum_size = Vector2(260 * k, 0)
			pied.add_child(bp)
	var ressort := Control.new()
	ressort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ressort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pied.add_child(ressort)
	var restaurer := Sty.lien("Restaurer mes achats", k, false)
	restaurer.pressed.connect(_restaurer)
	pied.add_child(restaurer)
	colonne.add_child(pied)
	avis = _label("" if Magasin.disponible() else Magasin.EXPLICATION, 12, MUET)
	colonne.add_child(avis)


func _tuile(e: Dictionary, id: String, r: Dictionary, possede: bool, prix: int,
		est_courante: bool, solde: int) -> Control:
	var k := Sty.HUD_K
	var tuile := PanelContainer.new()
	var st := Sty.plaque(Sty.BOIS_CLAIR,
		Sty.LAITON_CLAIR if est_courante else Color(Sty.LAITON, 0.55), Sty.R_GRAND, k)
	st.set_content_margin_all(12 * k)
	tuile.add_theme_stylebox_override("panel", st)
	# TOUTES LES TUILES À LA MÊME HAUTEUR : elles remplissent le rang, donc
	# l'écran. Deux cartes de hauteurs différentes se comparent mal, et la plus
	# courte a l'air inachevée. Leur LARGEUR, elle, est fixe : c'est ce qui fait
	# qu'on devine la suivante et qu'on a envie de la faire glisser.
	tuile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tuile.size_flags_vertical = Control.SIZE_FILL
	tuile.custom_minimum_size = Vector2(300 * k, 0)
	tuile.clip_contents = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(6 * k)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		ti.custom_minimum_size = Vector2(0, 66 * k)
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
	if not possede:
		var o: Dictionary = Magasin.offre_de_carte(id)
		if not o.is_empty():
			v.add_child(_label("%s pièces, ou %s" % [Sty.nombre(prix), Magasin.prix_de(o)], 13, OR))
	if r["entamee"]:
		v.add_child(_label("%d / %d gares · ★ %d" % [r["faites"], r["gares"], r["etoiles"]], 13, OR))

	# LE GESTE TOMBE EN BAS DE LA TUILE. Les tuiles ont maintenant la hauteur de
	# l'écran : sans ce ressort, le bouton flotterait au milieu du vide, à une
	# place différente dans chaque carte.
	var ressort := Control.new()
	ressort.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ressort.custom_minimum_size = Vector2(0, 8 * k)
	ressort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ressort)
	# LE PIED DE LA TUILE N'EST PLUS UN BOUTON, c'est une plaque : depuis que la
	# tuile ENTIÈRE se touche, un bouton posé dessus serait une seconde cible
	# pour le même geste. Il garde l'apparence d'un bouton parce que c'est bien
	# lui, l'appel — le prix y reste, et il suffit.
	var appel := "Carte en cours"
	if not est_courante:
		appel = ("Reprendre" if r["entamee"] else "Commencer") if possede else "Ouvrir · %s pièces" % Sty.nombre(prix)
	v.add_child(_plaque_appel(appel, possede and not est_courante))
	tuile.add_child(_zone_cliquable(id, possede))
	return tuile


## LA TUILE ENTIÈRE SE TOUCHE. « Quand je tape sur la carte, je dois y
## accéder » (Vincent, 5 septembre 2026) — et cela rend le lien « Le ruban »
## inutile : toucher la carte en cours y ramène. Le bouton transparent est
## posé PAR-DESSUS le contenu, dernier enfant du PanelContainer, qui l'étire
## comme les autres à son rectangle : il n'y a donc qu'une cible, jamais deux
## qui se disputent le même doigt.
func _zone_cliquable(id: String, possede: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	for quoi in ["normal", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(quoi, StyleBoxEmpty.new())
	# le seul retour visuel : un voile de laiton quand le doigt est dessus
	b.add_theme_stylebox_override("hover",
		Sty.boite(Color(Sty.LAITON, 0.07), Color(0, 0, 0, 0), Sty.R_GRAND * Sty.HUD_K, 0))
	b.pressed.connect(func() -> void: Sons.jouer("clic"))
	b.pressed.connect(_toucher.bind(id, possede))
	return b


func _toucher(id: String, possede: bool) -> void:
	if app == null:
		return
	if possede:
		app.choisir_carte(id)
	else:
		_ouvrir_modale(id)


## Le pied d'une tuile : l'aspect d'un bouton, sans en être un.
func _plaque_appel(texte: String, principal: bool) -> Control:
	var k := Sty.HUD_K
	var p := PanelContainer.new()
	var fond: Color = Sty.SARCELLE if principal else Sty.BOIS_CLAIR
	var st := Sty.plaque(fond, Sty.LAITON if principal else Color(Sty.LAITON, 0.45), Sty.R, k)
	st.content_margin_top = 9 * k
	st.content_margin_bottom = 9 * k
	st.content_margin_left = 14 * k
	st.content_margin_right = 14 * k
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = texte.to_upper()
	l.add_theme_font_override("font", Sty.titre(700 if principal else 600))
	l.add_theme_font_size_override("font_size", int(round(14 * k)))
	l.add_theme_color_override("font_color", Sty.PAPIER if principal else Color(Sty.PAPIER, 0.75))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	p.add_child(l)
	return p
