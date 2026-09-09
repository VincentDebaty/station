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
const Sty := preload("res://jeu/style.gd")
const Attente := preload("res://jeu/attente.gd")

var ruban = null
var carte_id := ""
var vue_ruban: Node2D
var vue_jeu: Node2D
var vue_cartes: Control
var porte_cartes: Node2D     ## le porteur des cartes, celui qui glisse
var vue := ""

# --- LE SERVICE QUI SE PRÉPARE, PENDANT QU'ON REGARDE ROULER UN TRAIN -------
var attente: CanvasLayer     ## l'écran d'attente, au-dessus de tout
var fil: Thread              ## le tirage de la journée, hors du fil principal
var fil_cmd := {}            ## la commande qu'il prépare
var fil_ville := ""
var fil_depuis := 0

const SEUIL_ATTENTE := 0.14  ## en deçà, l'écran d'attente clignoterait
const MINI_ATTENTE := 0.65   ## une fois ouvert, il se tient au moins ce temps


func _ready() -> void:
	Sauvegarde.apercu_sans_trace = OS.get_environment("STATION_SANS_TRACE") != ""
	vue_ruban = VueRuban.new()
	vue_ruban.app = self
	add_child(vue_ruban)
	vue_cartes = VueCartes.new()
	vue_cartes.app = self
	# UN PORTEUR POUR LES CARTES. L'écran des cartes est un Control ancré au
	# viewport : lui poser une position ne le déplace pas durablement, ses
	# ancres la reprennent au premier recalcul. Un Node2D parent, lui,
	# transporte tout ce qu'il contient — c'est déjà ainsi que la barre et le
	# panneau du ruban suivent leur écran.
	porte_cartes = Node2D.new()
	porte_cartes.add_child(vue_cartes)
	add_child(porte_cartes)
	vue_jeu = VueJeu.new()
	vue_jeu.autonome = false
	vue_jeu.app = self
	add_child(vue_jeu)
	attente = Attente.new()
	add_child(attente)
	charger_carte(String(Sauvegarde.get_carte_courante()))
	montrer("ruban")
	if OS.get_environment("STATION_VUE") == "cartes":
		vue_cartes.rebatir()
		montrer("cartes")
	if OS.get_environment("STATION_JOUER") != "":
		var gc: String = ruban.gare_courante()
		if gc != "":
			jouer(gc, true)
	Pilote.eventuel(self)
	Cap.eventuelle(self)


## UN FIL SE REJOINT TOUJOURS. Quitter l'application en laissant un Thread
## vivant fait aboyer le moteur — et sur iOS, plante à la sortie.
func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST or quoi == NOTIFICATION_PREDELETE:
		if fil != null and fil.is_started():
			fil.wait_to_finish()
			fil = null


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
	# CHAQUE ÉCRAN SA COULEUR DE FOND. Le ruban est une carte sur un bureau de
	# cuir ; le poste d'aiguillage garde son bleu nuit, où la couleur d'une
	# voie est sa destination et ne se rediscute pas.
	RenderingServer.set_default_clear_color(Sty.POSTE_FOND if nom == "jeu" else Sty.MER)
	for paire in [[vue_ruban, "ruban"], [vue_jeu, "jeu"], [porte_cartes, "cartes"]]:
		var n: CanvasItem = paire[0]
		var actif: bool = paire[1] == nom
		n.visible = actif
		n.process_mode = Node.PROCESS_MODE_INHERIT if actif else Node.PROCESS_MODE_DISABLED
		n.position = Vector2.ZERO
		n.scale = Vector2.ONE
		n.modulate = Color.WHITE


# --- LE GLISSEMENT ENTRE LE RUBAN ET LES CARTES ---------------------------------------
# LES CARTES SONT À GAUCHE DU RUBAN. Le chevron du bouton le dit, et le
# mouvement le confirme : l'écran part vers la droite pour les découvrir, et
# revient depuis la droite quand on en choisit une. Un écran qui apparaît sans
# venir de nulle part ne dit pas où l'on est allé ; celui-ci le dit sans un mot.
#
# Pendant le mouvement les deux écrans sont visibles et AUCUN DES DEUX
# n'écoute : un clic tombé au milieu d'une transition déclenche l'écran
# d'après, ce que personne n'a jamais voulu. `PROCESS_MODE_DISABLED` suffit —
# il coupe l'entrée sans rien cesser de dessiner.
const GLISSE := 0.32

var glisse_t := -1.0
var glisse_de: CanvasItem = null
var glisse_vers: CanvasItem = null
var glisse_nom := ""
var glisse_sens := 1.0


func en_glissement() -> bool:
	return glisse_t >= 0.0


## Un écran change : le doigt attend. Un clic tombé au milieu d'une transition
## déclenche l'écran d'après, ce que personne n'a jamais voulu.
func en_transition() -> bool:
	return glisse_t >= 0.0 or appar_t >= 0.0


# --- L'APPARITION : un zoom et un fondu depuis le milieu -----------------------------
# ON ENTRE DANS UNE GARE, ON EN RESSORT. Le ruban est la carte, la gare en est
# un point : y entrer resserre la vue sur ce point, en sortir la rouvre. Le
# poste d'aiguillage se pose donc en se CONTRACTANT — il arrive de plus grand
# que l'écran — et le relevé s'ouvre en GRANDISSANT depuis le milieu. Deux
# sens opposés pour deux gestes opposés ; c'est ce que dit un zoom, et c'est
# tout ce qu'il a à dire.
const APPARITION := 0.32

var appar_t := -1.0
var appar_qui: CanvasItem = null
var appar_de := 1.0


func _apparaitre(qui: CanvasItem, depuis: float) -> void:
	appar_qui = qui
	appar_de = depuis
	appar_t = 0.0
	_poser_apparition(0.0)


func _poser_apparition(e: float) -> void:
	if appar_qui == null:
		return
	var s: float = lerpf(appar_de, 1.0, e)
	var c: Vector2 = get_viewport().get_visible_rect().size / 2.0
	appar_qui.scale = Vector2(s, s)
	appar_qui.position = c - c * s
	# le fondu se termine avant le zoom : une image qui finit de grandir en
	# étant encore translucide donne l'impression de n'être jamais arrivée.
	appar_qui.modulate = Color(1, 1, 1, min(1.0, e * 1.7))


func _glisser(de: CanvasItem, vers: CanvasItem, nom: String, sens: float) -> void:
	if en_glissement():
		return
	glisse_de = de
	glisse_vers = vers
	glisse_nom = nom
	glisse_sens = sens
	glisse_t = 0.0
	var large := get_viewport().get_visible_rect().size.x
	for n in [de, vers]:
		n.visible = true
		n.process_mode = Node.PROCESS_MODE_DISABLED
	de.position = Vector2.ZERO
	vers.position = Vector2(-sens * large, 0.0)
	RenderingServer.set_default_clear_color(Sty.MER)


func _process(delta: float) -> void:
	_suivre_le_fil()
	if appar_t >= 0.0:
		appar_t = min(1.0, appar_t + delta / APPARITION)
		_poser_apparition(ease(appar_t, -1.8))
		if appar_t >= 1.0:
			appar_t = -1.0
			appar_qui.scale = Vector2.ONE
			appar_qui.position = Vector2.ZERO
			appar_qui.modulate = Color.WHITE
			appar_qui = null
	if not en_glissement():
		return
	glisse_t = min(1.0, glisse_t + delta / GLISSE)
	var e := ease(glisse_t, -1.8)          # entrée et sortie adoucies
	var large := get_viewport().get_visible_rect().size.x
	glisse_de.position = Vector2(lerpf(0.0, glisse_sens * large, e), 0.0)
	glisse_vers.position = Vector2(lerpf(-glisse_sens * large, 0.0, e), 0.0)
	if glisse_t >= 1.0:
		glisse_t = -1.0
		montrer(glisse_nom)


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
## PRENDRE UN SERVICE NE GÈLE PLUS L'ÉCRAN. Le tirage d'une journée coûte une
## seconde sur Darlington et cinq et demie sur Bruxelles-Midi, et il tenait sur
## le fil principal : entre le doigt sur « Jouer » et la première image, rien
## ne bougeait — « on a l'impression que cela bug » (Vincent, 9 septembre
## 2026). Il part maintenant sur un FIL D'EXÉCUTION, et l'écran d'attente
## tourne pendant ce temps. C'est la seule façon d'animer quoi que ce soit :
## une pancarte immobile sur un écran gelé se lit encore comme un plantage.
##
## Ce qui part sur le fil est PUR — géométrie, journée, enclenchement, aucun
## nœud (vue_jeu.preparer). Ce qui touche à l'arbre de scène attend le retour.
## `presse` : préparer sur place, sans écran d'attente. C'est ce que demande
## `STATION_JOUER=1` — on ouvre l'application DANS le service, pour une capture
## ou une mesure, et le service doit être prêt au retour de l'appel. Le fil
## ferait photographier un train qui roule à vide.
func jouer(id: String, presse: bool = false) -> void:
	if fil != null or not ruban.est_tenue(id):
		return
	var f := Donnees.fiche(id)
	if f.is_empty():
		return
	fil_cmd = vue_jeu.commande(f, ruban, carte_id)
	if presse:
		_prendre_le_service(VueJeu.preparer(fil_cmd))
		return
	fil_ville = vue_ruban.ville_de(id)
	fil_depuis = Time.get_ticks_msec()
	fil = Thread.new()
	fil.start(VueJeu.preparer.bind(fil_cmd))


## Vrai tant qu'un service se prépare : les écrans dessous n'écoutent pas —
## un doigt tombé sur la carte pendant l'attente ne doit pas choisir une gare
## qu'on ne verra jamais.
func en_attente() -> bool:
	return fil != null


func _prendre_le_service(pret: Dictionary) -> void:
	vue_jeu.installer(fil_cmd, pret)
	fil_cmd = {}
	attente.fermer()
	montrer("jeu")
	_apparaitre(vue_jeu, 1.10)


## Le fil ne prévient pas : on le cueille dès qu'il a fini. `is_alive` reste
## vrai tant que la fonction tourne ; `wait_to_finish` rend son résultat et
## libère le fil.
## UN ÉCRAN D'ATTENTE QUI CLIGNOTE EST PIRE QUE PAS D'ÉCRAN DU TOUT. Une
## petite gare se tire en cent soixante millisecondes sur un Mac : y faire
## passer un train une sixième de seconde donnerait un sursaut, pas une
## information. On ne l'ouvre donc qu'au-delà du SEUIL, et une fois ouvert on
## le tient au moins le temps du MINIMUM — la moitié du désagrément d'une
## attente, c'est de ne pas savoir si elle a commencé.
func _suivre_le_fil() -> void:
	if fil == null:
		return
	var ecoule: float = (Time.get_ticks_msec() - fil_depuis) / 1000.0
	if not attente.visible and ecoule >= SEUIL_ATTENTE and fil.is_alive():
		attente.ouvrir(fil_ville)
	if fil.is_alive():
		return
	if attente.visible and ecoule < SEUIL_ATTENTE + MINI_ATTENTE:
		return
	var pret: Dictionary = fil.wait_to_finish()
	fil = null
	_prendre_le_service(pret)


## Le jeu rend la main avec son relevé et les médailles décrochées.
func fin_de_service(bilan: Dictionary, medailles: Array) -> void:
	montrer("ruban")
	vue_ruban.fin_de_service(bilan, medailles)
	_apparaitre(vue_ruban, 0.90)


## Quitter un service en cours : rien n'est écrit, le ruban reprend.
func abandonner_service() -> void:
	montrer("ruban")
	vue_ruban.rebatir()
	_apparaitre(vue_ruban, 0.90)


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
	if en_glissement():
		return
	vue_cartes.rebatir()
	_glisser(vue_ruban, porte_cartes, "cartes", 1.0)


func fermer_cartes() -> void:
	_glisser(porte_cartes, vue_ruban, "ruban", -1.0)


func choisir_carte(id: String) -> void:
	if not (Sauvegarde.possede_carte(id) or _gratuite(id)):
		return
	if id != carte_id:
		charger_carte(id)
	_glisser(porte_cartes, vue_ruban, "ruban", -1.0)


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
