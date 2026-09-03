extends Control
## PREMIER JALON DU PORTAGE : le catalogue s'affiche.
##
## Rien n'est jouable ici, et c'est voulu. Ce que cet écran prouve, et qui
## représente la moitié du risque du portage : les chemins `res://` tombent
## juste, les 401 fiches se parsent, l'UTF-8 des libellés survit, les cartes se
## lisent, et les brevets se croisent avec elles.
##
## L'écran est construit en code plutôt qu'en scène : à ce stade il n'y a aucune
## intention de mise en page à préserver, et une scène .tscn de trente nœuds
## serait un décor à jeter au premier vrai écran.

const FOND := Color(0.0549, 0.0784, 0.1255)
const TEXTE := Color(0.859, 0.886, 0.933)
const MUET := Color(0.478, 0.525, 0.600)
const ACCENT := Color(0.176, 0.831, 0.749)
const OR := Color(0.910, 0.722, 0.231)
const ROUGE := Color(0.937, 0.267, 0.267)


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for c in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + c, 28)
	add_child(marge)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	marge.add_child(colonne)

	colonne.add_child(_titre())
	if not Donnees.erreurs.is_empty():
		colonne.add_child(_bloc_erreurs())
		return
	colonne.add_child(_resume())
	colonne.add_child(_cartes())
	colonne.add_child(_liste_pays())
	_capture_eventuelle()


## VÉRIFICATION VISUELLE SANS ŒIL HUMAIN. Le prototype a la sienne (Chrome
## headless) ; celle-ci est native : `STATION_CAPTURE=/chemin.png godot --path .`
## rend une image et quitte. Ça permet de contrôler un écran depuis un script,
## sans dépendre de quelqu'un qui regarde — et c'est déjà comme ça qu'on a
## attrapé des défauts d'affichage sur le prototype.
func _capture_eventuelle() -> void:
	var vers := OS.get_environment("STATION_CAPTURE")
	if vers == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png(vers) == OK:
		print("capture : " + vers)
	else:
		push_error("capture impossible : " + vers)
	get_tree().quit()


func _label(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _titre() -> Control:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 2)
	boite.add_child(_label("STATION", 13, MUET))
	boite.add_child(_label("Le catalogue est chargé", 30, TEXTE))
	return boite


func _bloc_erreurs() -> Control:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 4)
	boite.add_child(_label("%d erreur(s) au chargement" % Donnees.erreurs.size(), 18, ROUGE))
	for e in Donnees.erreurs:
		boite.add_child(_label("  " + e, 13, MUET))
	return boite


func _resume() -> Control:
	var brevetees := 0
	for id in Donnees.fiches:
		if Donnees.brevet(id) > 0:
			brevetees += 1
	var boite := HBoxContainer.new()
	boite.add_theme_constant_override("separation", 34)
	for paire in [
		["fiches", str(Donnees.fiches.size())],
		["brevetées", "%d / %d" % [brevetees, Donnees.fiches.size()]],
		["pays", str(Donnees.pays.size())],
		["cartes", str(Donnees.cartes.size())],
		["lignes réelles", str(Donnees.lignes.size())],
		["points de passage", str(Donnees.lieux.size())],
		["chargé en", "%d ms" % Donnees.duree_ms],
	]:
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 1)
		c.add_child(_label(String(paire[0]).to_upper(), 11, MUET))
		c.add_child(_label(String(paire[1]), 21, OR))
		boite.add_child(c)
	return boite


func _cartes() -> Control:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 5)
	boite.add_child(_label("LES CARTES", 11, MUET))
	for e in Donnees.cartes_index:
		var id := String(e.get("id", ""))
		var carte: Dictionary = Donnees.cartes.get(id, {})
		var chapitres: Array = carte.get("chapitres", [])
		var gares := 0
		var sous_brevet := 0
		for ch in chapitres:
			var liste: Array = ch.get("gares", [])
			gares += liste.size()
			# On croise dès maintenant la rampe et les brevets : c'est R10, et
			# c'est la règle la plus facile à casser en transposant.
			for g in liste:
				if Donnees.brevet(String(g)) <= 0:
					sous_brevet += 1
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 12)
		ligne.add_child(_label(String(carte.get("nom", id)), 17, TEXTE))
		ligne.add_child(_label("%d chapitres · %d gares" % [chapitres.size(), gares], 14, MUET))
		if not bool(e.get("gratuite", false)):
			ligne.add_child(_label("%d cr" % int(carte.get("prixCredits", 0)), 14, OR))
		if sous_brevet > 0:
			ligne.add_child(_label("⚠ %d sans brevet" % sous_brevet, 14, ROUGE))
		boite.add_child(ligne)
	return boite


func _liste_pays() -> Control:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 6)
	# SANS CETTE LIGNE, LA LISTE EST INVISIBLE. Le ScrollContainer plus bas
	# demande à s'étendre, mais un enfant ne peut prendre que la place que son
	# parent a reçue : ce conteneur-ci doit donc réclamer le reste de la colonne.
	# Attrapé à la première capture — l'en-tête s'affichait au-dessus du vide.
	boite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boite.add_child(_label("LE CATALOGUE, DANS L'ORDRE CURÉ DE L'INDEX", 11, MUET))

	var defile := ScrollContainer.new()
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boite.add_child(defile)

	var dedans := VBoxContainer.new()
	dedans.add_theme_constant_override("separation", 10)
	dedans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(dedans)

	for bloc in Donnees.index:
		var slug := String(bloc.get("country", ""))
		var stations: Array = bloc.get("stations", [])
		var p := Donnees.pays_de(slug)
		var entete := HBoxContainer.new()
		entete.add_theme_constant_override("separation", 10)
		entete.add_child(_label("%s %s" % [p["drapeau"], p["nom"]], 17, TEXTE))
		entete.add_child(_label("%d gares" % stations.size(), 13, MUET))
		dedans.add_child(entete)

		# Les gares en une ligne dense : à ce stade on vérifie que TOUT est là,
		# pas qu'on saura le mettre en page.
		var noms: PackedStringArray = []
		for id in stations:
			var f := Donnees.fiche(String(id))
			var n := String(f.get("city", f.get("name", id)))
			noms.append("%s·%d" % [n, int(f.get("difficulty", 0))])
		var l := _label("   " + " ".join(noms), 12, MUET)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dedans.add_child(l)

	return boite
