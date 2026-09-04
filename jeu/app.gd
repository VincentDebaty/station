extends Node
## L'APPLICATION — l'enchaînement des écrans (étape 7 du portage).
##
##   godot --path .                       (jeu/app.tscn est la scène principale)
##   STATION_VUE=cartes godot --path .    ouvre l'écran des cartes
##   STATION_JOUER=1 godot --path .       prend tout de suite le service de la gare courante
##
## Trois écrans, et un seul enchaînement : le RUBAN (où l'on est, ce qui
## vient, le relevé du dernier service), le JEU (un service), les CARTES
## (choisir son territoire, à partir de deux). Le jeu rend la main au ruban
## avec son bilan, exactement comme endGame → showHub dans le prototype : le
## relevé se lit sur la carte, sous la gare qu'on vient de tenir.
##
## Ce fichier ne calcule rien : il tient le ruban de la carte courante, sa
## progression vivante (Sauvegarde), et passe la parole.

const Rub := preload("res://jeu/ruban.gd")
const Rec := preload("res://jeu/recompense.gd")
const VueRuban := preload("res://jeu/vue_ruban.gd")
const VueCartes := preload("res://jeu/vue_cartes.gd")
const VueJeu := preload("res://jeu/vue_jeu.gd")
const Pilote := preload("res://jeu/pilote.gd")
const Cap := preload("res://jeu/capture.gd")

var ruban = null
var carte_id := ""
var vue_ruban: Node2D
var vue_jeu: Node2D
var vue_cartes: Control
var vue := ""


func _ready() -> void:
	Sauvegarde.apercu_sans_trace = OS.get_environment("STATION_SANS_TRACE") != ""
	vue_ruban = VueRuban.new()
	vue_ruban.app = self
	add_child(vue_ruban)
	vue_cartes = VueCartes.new()
	vue_cartes.app = self
	add_child(vue_cartes)
	vue_jeu = VueJeu.new()
	vue_jeu.autonome = false
	vue_jeu.app = self
	add_child(vue_jeu)
	charger_carte(String(Sauvegarde.get_carte_courante()))
	montrer("ruban")
	if OS.get_environment("STATION_VUE") == "cartes":
		ouvrir_cartes()
	if OS.get_environment("STATION_JOUER") != "":
		var gc: String = ruban.gare_courante()
		if gc != "":
			jouer(gc)
	Pilote.eventuel(self)
	Cap.eventuelle(self)


## Changer de carte, c'est changer de monde : la progression de l'ancienne
## reste intacte, mais tout ce que l'écran gardait tombe.
func charger_carte(id: String) -> void:
	if not Donnees.cartes.has(id):
		id = Sauvegarde.CARTE_PAR_DEFAUT
	Sauvegarde.set_carte_courante(id)
	ruban = Rub.new(Donnees.cartes[id], Donnees.fiches)
	ruban.stations = Sauvegarde.get_progression()
	ruban.passees = Sauvegarde.get_passees()
	carte_id = id
	vue_ruban.poser(ruban, id)


func montrer(nom: String) -> void:
	vue = nom
	for paire in [[vue_ruban, "ruban"], [vue_jeu, "jeu"], [vue_cartes, "cartes"]]:
		var n: Node = paire[0]
		var actif: bool = paire[1] == nom
		n.visible = actif
		n.process_mode = Node.PROCESS_MODE_INHERIT if actif else Node.PROCESS_MODE_DISABLED


# --- LA CAPTURE D'ÉCRAN, DEPUIS L'APPAREIL ------------------------------------------
# Sur un téléphone il n'y a ni console lisible ni commande de capture dans
# devicectl : le seul moyen de me montrer un écran était l'AirDrop à la main.
# TROIS DOIGTS POSÉS ensemble enregistrent donc l'image dans le conteneur de
# l'app, que `tools/ios.sh --capture` va chercher. Au bureau, F12 fait pareil.
var _doigts := {}


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_doigts[event.index] = true
			if _doigts.size() >= 3:
				_doigts.clear()
				capturer()
		else:
			_doigts.erase(event.index)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		capturer()


func capturer() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var vers := "user://capture.png"
	if img.save_png(vers) == OK:
		print("capture : " + ProjectSettings.globalize_path(vers))
	else:
		push_error("capture impossible")


# --- le service ---------------------------------------------------------------------
func jouer(id: String) -> void:
	if not ruban.est_tenue(id):
		return
	var f := Donnees.fiche(id)
	if f.is_empty():
		return
	vue_jeu.demarrer(f, ruban, carte_id)
	montrer("jeu")


## Le jeu rend la main avec son relevé et les médailles décrochées.
func fin_de_service(bilan: Dictionary, medailles: Array) -> void:
	montrer("ruban")
	vue_ruban.fin_de_service(bilan, medailles)


## Quitter un service en cours : rien n'est écrit, le ruban reprend.
func abandonner_service() -> void:
	montrer("ruban")
	vue_ruban.rebatir()


## Passer en payant : la gare reste à zéro étoile et se rejoue quand on veut.
func passer(id: String) -> void:
	var prix: int = Rec.prix_de_passage(ruban, id)
	if solde() < prix or not Sauvegarde.payer_passage(id):
		return
	vue_ruban.apres_passage(id)


# --- les crédits : un fait de compte, déduit --------------------------------------------
func solde() -> int:
	var cartes: Array = Sauvegarde.cartes_enregistrees()
	var gagnes: int = Rec.credits_gagnes(cartes, Donnees.cartes)
	var depenses: int = Rec.credits_depenses(cartes, Donnees.cartes, Sauvegarde.cartes_possedees(), Donnees.cartes_index)
	return Rec.solde_credits(gagnes, depenses)


# --- les cartes ------------------------------------------------------------------------------
func plusieurs_cartes() -> bool:
	return Donnees.cartes_index.size() >= 2


func ouvrir_cartes() -> void:
	vue_cartes.rebatir()
	montrer("cartes")


func fermer_cartes() -> void:
	montrer("ruban")


func choisir_carte(id: String) -> void:
	if not (Sauvegarde.possede_carte(id) or _gratuite(id)):
		return
	if id != carte_id:
		charger_carte(id)
	montrer("ruban")


func acheter_carte(id: String) -> void:
	var prix: int = Rec.prix_de_carte(Donnees.cartes.get(id, {}), _entree(id))
	if solde() < prix:
		return
	if not Sauvegarde.acquerir_carte(id, "credits"):
		return
	vue_cartes.rebatir()


func _entree(id: String) -> Dictionary:
	for e in Donnees.cartes_index:
		if e.get("id") == id:
			return e
	return {}


func _gratuite(id: String) -> bool:
	return bool(_entree(id).get("gratuite", false))
