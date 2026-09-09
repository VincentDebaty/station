extends Node2D
## L'ÉCRAN DE JEU — un convoi qui roule.
##
##   godot --path . res://jeu/jeu.tscn
##   STATION_GARE=namur STATION_GRAINE=3 STATION_AUTO=1 STATION_VITESSE=4 godot --path . res://jeu/jeu.tscn
##
## Ce que cet écran dessine, il ne le décide jamais : la journée vient de
## Journee, chaque position de chaque état vient d'Enclenchement, et ce fichier
## ne fait que TRADUIRE un état en pixels — comme render.js le faisait pour le
## prototype, avec les mêmes formules de placement (placeQueue, placeEntry,
## placeExit, le transit de fret). Aucune règle de jeu ici : si un convoi ne
## part pas, c'est l'enclenchement qui l'a décidé, et l'oracle l'a vérifié.
##
## Commandes : un clic sur un convoi le choisit, un clic sur un quai l'y
## envoie ; espace met en pause ; 1, 2, 4 règlent la vitesse ; R rejoue une
## journée neuve ; Échap désélectionne. STATION_AUTO=1 laisse le joueur
## scripté de l'oracle jouer seul — c'est ainsi qu'on photographie un service
## sans personne devant.

const Geo := preload("res://jeu/geometrie.gd")
const Jour := preload("res://jeu/journee.gd")
const Has := preload("res://jeu/hasard.gd")
const Enc := preload("res://jeu/enclenchement.gd")
const Plan := preload("res://jeu/gare.gd")
const Cap := preload("res://jeu/capture.gd")
const Rub := preload("res://jeu/ruban.gd")
const Rec := preload("res://jeu/recompense.gd")
const Sty := preload("res://jeu/style.gd")
const Ill := preload("res://jeu/illustrations.gd")

# Les couleurs du prototype (css/station.css) : l'esthétique est conservée.
const TEXTE := Color("#efe3c8")   # le papier, comme le ruban
const MUET := Color("#9d8b71")
const ACCENT := Color("#2dd4bf")
const OR := Color("#f5b23c")
const VERT := Color("#4ade80")
const ROUGE := Color("#ef4444")
const FRET := Color("#8f98a8")
const VOILE := Color(0.110, 0.086, 0.063, 0.86)

var fiche: Dictionary
var G: Dictionary
var enc: Enc                          # le script préchargé sert de type
var graine: int
var vitesse: float = 1.0
var pause: bool = false
var auto: bool = false
var duree_generation_ms: int = 0
var positions: Dictionary = {}       # id -> Array[{x, y, ang}], recalculé à chaque image
var plan: Node2D
var ruban = null                     # le ruban de la carte qui porte la gare ; null hors carte
var carte_id := ""
var fiche_jouee: Dictionary          # la fiche telle que le ruban la sert (difficulty, gen recalculés)
var fin_enregistree := false         # la fin de service est écrite une fois
var app = null                       # l'application qui enchaîne les écrans ; null seul à l'écran
var autonome := true                 # lancé comme scène : la gare vient de l'environnement
var retour_lance := false            # la main est rendue une fois
var bilan_final := {}                # le relevé pour le ruban (endGame → CARTE.bilan)
var medailles_final: Array = []

# --- le tutoriel : le premier service, guidé pas à pas (js/game.js, onboarding)
var gel := false                     # le service est gelé par un repère
var tuto := ""                       # la phase ; "" quand il n'y a rien à enseigner
var tuto_premier := ""               # l'id du premier train guidé
var tuto_feu_vu := false
var tuto_vitesse_vu := false
var coach_cible: Dictionary = {}     # {train: id} | {quai: pid} | {hud: "retard"|"vitesse"}
var zones_hud: Dictionary = {}       # les rectangles du bandeau, pour le doigt
var pupitre: Node2D
var bulle: PanelContainer
var bulle_texte: Label
var bulle_bouton: Button
var accueil: Control
var confirmation: Control          ## la question qui précède un geste destructeur
var conf_titre: Label
var conf_corps: Label
var conf_oui: Button
var conf_quoi := ""                ## « abandon » ou « recommencer »
var gel_avant_confirmation := false
var reglages_ouverts := false      ## le volet sous l'engrenage


func _ready() -> void:
	# Les deux facteurs d'échelle se lisent sur l'écran réel (jeu/style.gd) :
	# le tactile grossit les cibles du plan, le bandeau garde sa taille physique.
	Sty.calibrer(get_viewport())
	_construire_pupitre()
	_construire_coach()
	_construire_confirmation()
	if not autonome:
		return
	var id := OS.get_environment("STATION_GARE")
	if id == "":
		id = "darlington"
	fiche = Donnees.fiche(id)
	if fiche.is_empty():
		push_error("gare inconnue : " + id)
		return
	# LA FICHE TELLE QU'ON LA JOUE (étape 5). La carte qui porte la gare décide
	# de son niveau — la rampe du ruban — et donc de son enveloppe et de son
	# barème. Hors carte : la fiche telle quelle, comme le prototype sans
	# CARTE_COURANTE. STATION_CARTE=<id> force la carte quand deux la portent.
	# STATION_SANS_TRACE=1 : rien n'est écrit (l'aperçu sans trace du prototype).
	Sauvegarde.apercu_sans_trace = OS.get_environment("STATION_SANS_TRACE") != ""
	_choisir_ruban(id)
	fiche_jouee = ruban.fiche_de_service(fiche) if ruban != null else fiche
	var g := OS.get_environment("STATION_GRAINE")
	graine = int(g) if g != "" else int(Time.get_unix_time_from_system()) % 100000
	var v := OS.get_environment("STATION_VITESSE")
	if v != "":
		vitesse = float(v)
	auto = OS.get_environment("STATION_AUTO") != ""

	G = Geo.construire(fiche)
	plan = Plan.new()
	plan.autonome = false
	plan.cartouche = false
	# Un enfant se dessine APRÈS son parent : sans ceci, les quais recouvraient
	# les convois à l'arrêt — deux badges au-dessus de quais vides, à la première
	# capture. Le plan passe dessous, les convois roulent dessus.
	plan.show_behind_parent = true
	add_child(plan)
	plan.poser(fiche, G)
	_nouvelle_journee()
	Cap.eventuelle(self)


## Un service commandé par l'application : la fiche, le ruban et sa carte.
##
## LE SERVICE SE PRÉPARE EN TROIS TEMPS, ET C'EST VOULU. Tout tenait ici, dans
## un seul appel : la géométrie, le tirage de la journée, l'enclenchement, les
## nœuds. Or le tirage prend UNE SECONDE sur Darlington et cinq et demie sur
## Bruxelles-Midi — pendant lesquelles rien ne pouvait s'afficher, puisque le
## fil principal était pris. « On a l'impression que cela bug » (Vincent, 9
## septembre 2026), et ce n'était pas une impression : l'écran était gelé.
##
##   `commande()`  ce qu'il faut savoir — immédiat, sur le fil principal ;
##   `preparer()`  le calcul lourd — PUR, sans un nœud, donc portable sur un
##                 fil d'exécution (app.gd le fait) ;
##   `installer()` les nœuds et l'état — sur le fil principal, immédiat.
##
## `demarrer` enchaîne les trois d'un coup : c'est le chemin de l'oracle, des
## captures et du mode autonome, où personne ne regarde l'écran.
func demarrer(f: Dictionary, r, cid: String) -> void:
	var cmd := commande(f, r, cid)
	installer(cmd, preparer(cmd))


## Ce qu'il faut savoir avant de préparer un service. Rien de lourd.
func commande(f: Dictionary, r, cid: String) -> Dictionary:
	var fj: Dictionary = r.fiche_de_service(f) if r != null else f
	var g := OS.get_environment("STATION_GRAINE")
	var v := OS.get_environment("STATION_VITESSE")
	return {"fiche": f, "ruban": r, "carte": cid, "jouee": fj,
		"graine": int(g) if g != "" else int(Time.get_unix_time_from_system()) % 100000,
		"vitesse": float(v) if v != "" else 1.0,
		"seuils": r.seuils_de_service(f) if r != null else null}


## LA PART LOURDE, ET ELLE NE TOUCHE À AUCUN NŒUD. C'est la condition pour
## qu'elle parte sur un fil : la géométrie, la journée tirée et l'enclenchement
## chargé sont des objets de données — `Enclenchement` n'est même pas un Node.
## Rien ici ne lit ni n'écrit l'arbre de scène, la sauvegarde ou le style.
static func preparer(cmd: Dictionary) -> Dictionary:
	var g: Dictionary = Geo.construire(cmd["fiche"])
	var t0 := Time.get_ticks_msec()
	var day: Dictionary = Jour.new(g, cmd["jouee"], Has.new(int(cmd["graine"]))).generate_schedule()
	var ms := Time.get_ticks_msec() - t0
	var e = Enc.new(g, cmd["jouee"])
	if cmd["seuils"] != null:
		e.seuils = cmd["seuils"]
	e.charger(day)
	return {"G": g, "enc": e, "ms": ms}


## Les nœuds et l'état. Immédiat : le calcul est déjà fait.
func installer(cmd: Dictionary, pret: Dictionary) -> void:
	fiche = cmd["fiche"]
	ruban = cmd["ruban"]
	carte_id = cmd["carte"]
	fiche_jouee = cmd["jouee"]
	graine = int(cmd["graine"])
	vitesse = float(cmd["vitesse"])
	auto = OS.get_environment("STATION_AUTO") != ""
	pause = false
	retour_lance = false
	fin_enregistree = false
	G = pret["G"]
	enc = pret["enc"]
	duree_generation_ms = int(pret["ms"])
	if plan != null:
		remove_child(plan)
		plan.queue_free()
	plan = Plan.new()
	plan.autonome = false
	plan.cartouche = false
	plan.show_behind_parent = true
	add_child(plan)
	plan.poser(fiche, G)
	print("%s · graine %d — %d convois, journée tirée en %d ms · %s"
		% [fiche.get("id", "?"), graine, enc.trains.size(), duree_generation_ms, _niveau_texte()])
	_tuto_demarrer()


func _choisir_ruban(id: String) -> void:
	var voulu := OS.get_environment("STATION_CARTE")
	for e in Donnees.cartes_index:
		var cid := String(e.get("id", ""))
		if (voulu != "" and cid != voulu) or not Donnees.cartes.has(cid):
			continue
		var r = Rub.new(Donnees.cartes[cid], Donnees.fiches)
		if r.sur_le_ruban(id):
			ruban = r
			carte_id = cid
			# Jouer une gare, c'est jouer SA carte : la progression lue et écrite
			# est celle-là, vivante — le ruban voit chaque résultat enregistré.
			Sauvegarde.set_carte_courante(cid)
			r.stations = Sauvegarde.get_progression()
			r.passees = Sauvegarde.get_passees()
			return


## « europe, niveau 3 (fiche 4), 3 étoiles sous 10 min » — ce que le service
## demande vraiment, pour le journal et le bandeau.
func _niveau_texte() -> String:
	if ruban == null:
		return "hors carte, niveau de fiche %d" % int(fiche.get("difficulty", 0))
	var s: Dictionary = enc.seuils_de_service() if enc != null else {}
	return "%s, niveau %d%s (fiche %d), 3 étoiles sous %s min" % [
		carte_id, int(fiche_jouee.get("difficulty", 0)),
		" BOSS" if ruban.est_boss(String(fiche.get("id", "")), fiche) else "",
		int(fiche.get("difficulty", 0)), str(s.get("trois", "?"))]


func _nouvelle_journee() -> void:
	fin_enregistree = false
	var t0 := Time.get_ticks_msec()
	var day: Dictionary = Jour.new(G, fiche_jouee, Has.new(graine)).generate_schedule()
	duree_generation_ms = Time.get_ticks_msec() - t0
	enc = Enc.new(G, fiche_jouee)
	if ruban != null:
		enc.seuils = ruban.seuils_de_service(fiche)
	enc.charger(day)
	print("%s · graine %d — %d convois, journée tirée en %d ms · %s"
		% [fiche.get("id", "?"), graine, enc.trains.size(), duree_generation_ms, _niveau_texte()])


## LA FIN DE SERVICE S'ÉCRIT COMME DANS LE PROTOTYPE (js/game.js, endGame) :
## un échec se note sans toucher au record, une réussite garde le meilleur ;
## la série se tient après, et casse sur un échec. Les médailles se comparent
## avant/après, elles ne se stockent pas.
func _enregistrer_fin() -> void:
	fin_enregistree = true
	var r: Dictionary = enc.resultat
	# La signature de fin, comme game.js : fanfare pour un sans-faute, carillon
	# pour un service tenu, deux notes basses pour un échec.
	Sons.jouer("parfait" if r["perfect"] else ("fin" if r["win"] else "incident"))
	var id := String(fiche.get("id", ""))
	var stars := int(r["stars"])
	var avant: Array = Rec.medailles_de(Rec.etat_recompenses(ruban, Sauvegarde.get_serie())) if ruban != null else []
	# Étoiles et record de CETTE gare AVANT enregistrement : c'est la
	# différence qui dit ce que le service a rapporté.
	var prev: Dictionary = ruban.progression_de(id) if ruban != null else {}
	bilan_final = {"gare": id, "stars": stars, "prevStars": Rub.etoiles_de(prev), "d": r["d"],
		"prevBest": prev.get("bestDelay"), "perfect": r["perfect"], "failed": r["failed"], "win": r["win"],
		"seuils": enc.seuils_de_service()}
	medailles_final = []
	if r["failed"]:
		Sauvegarde.marquer_tentee(id)
	else:
		Sauvegarde.enregistrer_resultat(id, stars, r["d"])
	var serie: Dictionary = Sauvegarde.pousser_serie((not r["failed"]) and stars >= Rec.SERIE_SEUIL)
	var texte := "enregistré : %s %d★, retard %d, série %d (record %d)" % [id, stars, int(r["d"]), serie["n"], serie["record"]]
	if ruban != null:
		var noms: PackedStringArray = []
		medailles_final = Rec.medailles_nouvelles(avant, Rec.medailles_de(Rec.etat_recompenses(ruban, Sauvegarde.get_serie())))
		for m in medailles_final:
			noms.append(m["nom"])
		if not noms.is_empty():
			texte += " · médailles : " + ", ".join(noms)
		texte += " · position %d/%d" % [ruban.position_courante(), ruban.longueur()]
	if Sauvegarde.apercu_sans_trace:
		texte += " (sans trace)"
	print(texte)


func _process(delta: float) -> void:
	if enc == null:
		return
	if not pause and not gel and not enc.ended:
		var dt_min: float = delta * vitesse / Geo.SEC_PER_GAMEMIN
		enc.game_min += dt_min
		enc.tick(dt_min)
		if auto and not enc.ended:
			_joueur_scripte()
	_vider_les_sons()
	if enc.ended and not fin_enregistree:
		_enregistrer_fin()
		# LE TEMPS MORT DE 1,2 SECONDE ÉTAIT UN BLOCAGE, ET PAS UNE RESPIRATION.
		# Le service se termine à l'instant où le DERNIER convoi lâche son
		# itinéraire — c'est-à-dire alors qu'il est encore en train de sortir de
		# l'écran (enclenchement.gd : un convoi « sorti » suffit, il n'a pas
		# besoin d'être arrivé au bout). Or `tick` ne fait plus rien une fois
		# `ended` : le convoi se fige donc en pleine sortie, et l'écran reste
		# une seconde et deux dixièmes sur cette image morte. « On a
		# l'impression que le jeu se bloque une demi-seconde » (Vincent, 5
		# septembre 2026) — c'est exactement cela, et c'était même plus long.
		#
		# Je ne fais pas terminer sa sortie au convoi : cela demanderait de
		# faire tourner l'enclenchement après la fin, et l'enclenchement est la
		# seule pièce du jeu sous contrôle d'oracle. On raccourcit le battement
		# à ce qu'il faut pour que l'œil enregistre la fin, et la transition
		# prend le relais — c'est du mouvement, plus une image morte.
		if app != null and not retour_lance:
			retour_lance = true
			get_tree().create_timer(0.35).timeout.connect(_rendre_la_main)
	_calculer_positions()
	_tuto_tick()
	_placer_bulle()
	queue_redraw()


## LA FILE DE L'ENCLENCHEMENT SE VIDE ICI, ET NULLE PART AILLEURS. Le moteur
## nomme ce qui vient d'arriver ; cette vue est la seule pièce qui ait le droit
## de faire du bruit — et le joueur scripté, l'oracle et les captures headless
## passent par la même porte sans qu'on ait rien à leur dire de particulier.
func _vider_les_sons() -> void:
	if enc.sons.is_empty():
		return
	for nom in enc.sons:
		if nom.begins_with("heure:"):
			Sons.jouer_a_l_heure(int(nom.substr(6)))
		else:
			Sons.jouer(nom)
	enc.sons.clear()


func _rendre_la_main() -> void:
	if app != null and enc != null and enc.ended:
		app.fin_de_service(bilan_final, medailles_final)


# ------------------------------------------------------------------
# Où est chaque voiture — les formules de placement de render.js
# ------------------------------------------------------------------
func _calculer_positions() -> void:
	positions.clear()
	for t in enc.trains:
		var p := _positions_de(t)
		if not p.is_empty():
			positions[t.id] = p


func _positions_de(t) -> Array:
	var out: Array = []
	var cs: float = Geo.CAR_SPACING
	var n := int(t.cars)
	match t.state:
		Enc.S_APPROACHING, Enc.S_WAITING:
			if t.qs == null:
				return out
			var ap: Dictionary = enc.approach[t.from]
			for i in range(n):
				out.append(Geo.path_point(ap, float(t.qs) - i * cs))
		Enc.S_MOVING_IN, Enc.S_DWELL:
			var path: Dictionary = enc.paths[t.entry_path]
			var ap: Dictionary = enc.approach[t.from]
			var head_s: float = t.stop_s
			if t.state == Enc.S_MOVING_IN:
				var stop_p: float = t.stop_s / path["len"]
				head_s = t.start_s + Enc.ease_run(t.progress / stop_p, 0.10, 0.22) * (t.stop_s - t.start_s)
			for i in range(n):
				var s: float = head_s - i * cs
				out.append(Geo.path_point(path, s) if s >= 0 else Geo.path_point(ap, ap["len"] + s))
		Enc.S_MOVING_BACK:
			var path: Dictionary = enc.paths[t.exit_path]
			var ap: Dictionary = enc.approach[t.from]
			var p0: float = 1 - t.stop_s / path["len"]
			var eff_p: float = p0 + Enc.ease_run((t.progress - p0) / (1 - p0), 0.16, 0) * (1 - p0)
			var head_s: float = (1 - eff_p) * path["len"]
			for i in range(n):
				var s: float = head_s - i * cs
				out.append(Geo.path_point(path, s) if s >= 0 else Geo.path_point(ap, ap["len"] + s))
		Enc.S_MOVING_OUT:
			var path: Dictionary = enc.paths[t.exit_path]
			var dep: Dictionary = enc.depart[t.to]
			var tail: float = (t.cars - 1) * cs
			var gone_p: float = 1 + (tail + Geo.EXIT_RUN) / path["len"]
			var eff_p: float = Enc.ease_run(t.progress / gone_p, 0.16, 0) * gone_p
			var head_s: float = (1 - eff_p) * (path["len"] + t.back_s)
			for i in range(n):
				var s: float = head_s + i * cs
				out.append(Geo.path_point(path, s) if s >= 0 else Geo.path_point(dep, -s))
		Enc.S_MOVING_THROUGH:
			var pin: Dictionary = enc.paths[t.entry_path]
			var pout: Dictionary = enc.paths[t.exit_path]
			var ap: Dictionary = enc.approach[t.from]
			var total_arc: float = pin["len"] + pout["len"]
			var tail: float = (t.cars - 1) * cs
			var end_u: float = 1 + (tail + Geo.EXIT_RUN) / total_arc
			var h: float = t.start_s + Enc.ease_run(t.progress / end_u, 0.12, 0) * (end_u * total_arc - t.start_s)
			for i in range(n):
				var s: float = h - i * cs
				if s < 0:
					out.append(Geo.path_point(ap, ap["len"] + s))
				elif s <= pin["len"]:
					out.append(Geo.path_point(pin, s))
				else:
					var out_arc: float = pout["len"] - (s - pin["len"])
					out.append(Geo.path_point(pout, out_arc) if out_arc >= 0 else Geo.path_point(enc.depart[t.to], -out_arc))
	return out


# ------------------------------------------------------------------
# LE DESSIN — l'habillage du prototype, valeur pour valeur.
# ------------------------------------------------------------------
# Chaque rayon, épaisseur, couleur et durée vient de css/station.css ou de
# js/render.js, par jeu/style.gd. Ce qui était un `filter: drop-shadow` du web
# devient ici une ombre de StyleBoxFlat (pour une boîte) ou des passes larges
# et translucides sous le trait (pour une ligne) : Godot n'a pas de filtre de
# flou en 2D, et le prototype lui-même évitait les filtres animés — ils ne
# s'affichent pas de façon fiable sur iOS (voir .state-ring, css/station.css).
static func fmt(minute: float) -> String:
	var m := int(max(0.0, floor(minute)))
	return "%02d:%02d" % [7 + m / 60, m % 60]


## LE PUPITRE — la matière sous le plan.
##
## Le poste était un aplat brun : correct, et sans profondeur. Un vrai tableau
## de contrôle optique est une PLAQUE — bakélite ou tôle laquée — sous une
## lampe d'atelier, et c'est tout ce qui lui manquait. Trois couches, aucune
## qui touche à la signalisation : le grain de la plaque, la lampe chaude qui
## tombe du haut, et l'assombrissement des bords qui ramène l'œil au centre.
## Rien ici ne se lit : tout ici se regarde.
class Pupitre extends Node2D:
	var grain: NoiseTexture2D
	var lampe: GradientTexture2D
	var ombre: GradientTexture2D
	var ville: Texture2D
	var ecran := Vector2(1400, 760)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, ecran)
		# LA LAMPE D'ABORD, ET ELLE RELÈVE. Au premier essai j'ai posé le grain
		# et l'ombre sur un fond déjà très sombre : le pupitre est devenu noir,
		# exactement la faute que cet écran m'avait déjà values le 4 septembre.
		# Une plaque sous une lampe est plus CLAIRE au centre qu'un aplat, pas
		# plus foncée aux bords : on éclaire, puis on tempère.
		if lampe != null:
			draw_texture_rect(lampe, r, false, Color(1, 1, 1, 1))
		if grain != null and grain.get_width() > 0:
			draw_texture_rect(grain, r, true, Color(0.0, 0.0, 0.0, 0.13))
			draw_texture_rect(grain, Rect2(r.position + Vector2(3, 5), r.size), true,
				Color(1.0, 0.90, 0.72, 0.05))
		# LA VILLE AU LOIN, entre la lampe et l'ombre. C'est le détail de la
		# maquette du 9 septembre 2026 qui change le plus l'écran : le poste
		# cesse d'être un tableau posé nulle part, il est DANS une ville.
		#
		# ELLE SE DEVINE, ELLE NE SE VOIT PAS, et c'est ce qui la rend juste :
		# à peine plus sombre que le pupitre, et sous le grain plutôt que
		# dessus. Un horizon qu'on remarque est un horizon qui dispute
		# l'attention aux voies, et les voies sont le jeu.
		#
		# Elle est ancrée au BAS DE L'ÉCRAN et étalée sur toute la largeur : le
		# rapport de la planche fait le reste, et rien n'est déformé — une
		# flèche de cathédrale écrasée se verrait tout de suite.
		if ville != null:
			var t := ville.get_size()
			if t.x > 0.0:
				var hv: float = ecran.x * t.y / t.x
				draw_texture_rect(ville, Rect2(0.0, ecran.y - hv, ecran.x, hv), false,
					Color(0.16, 0.11, 0.07, 0.42))
		if ombre != null:
			draw_texture_rect(ombre, r, false, Color(1, 1, 1, 1))


func _construire_pupitre() -> void:
	pupitre = Pupitre.new()
	pupitre.show_behind_parent = true
	var g := FastNoiseLite.new()
	g.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	g.frequency = 0.35
	g.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = g
	pupitre.grain = t
	# la lampe éclaire un peu plus, l'ombre des bords retient un peu moins :
	# le relief du pupitre se garde, mais moins au prix de la clarté
	# LE FOND SE CREUSE. La maquette de Vincent (9 septembre 2026) est bien
	# plus CONTRASTÉE que le pupitre d'alors : une lumière franche au milieu,
	# des angles qui s'enfoncent. Le nôtre était plat — un brun uniforme d'un
	# bord à l'autre —, ce qui n'aidait ni les voies ni les plaques à se
	# détacher.
	#
	# LA LAMPE MONTE PLUS QUE L'OMBRE, et c'est délibéré : Vincent avait
	# demandé un écran plus clair sur son iPhone le 9 septembre au matin. Le
	# contraste vient donc surtout de la lumière ajoutée au centre, pas de
	# l'ombre ajoutée aux bords — le gain net de clarté est positif.
	pupitre.ville = Ill.silhouette()
	pupitre.lampe = _radial(Color(1.0, 0.85, 0.60, 0.30), Vector2(0.5, 0.12), 1.10)
	pupitre.ombre = _radial_inverse(Color(0.0, 0.0, 0.0, 0.24))
	add_child(pupitre)
	move_child(pupitre, 0)


## Une nappe radiale : pleine au centre, éteinte au bord.
func _radial(col: Color, centre: Vector2, rayon: float) -> GradientTexture2D:
	var d := Gradient.new()
	d.set_color(0, col)
	d.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var g := GradientTexture2D.new()
	g.gradient = d
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = centre
	g.fill_to = centre + Vector2(rayon, 0)
	g.width = 256
	g.height = 256
	return g


## L'inverse : rien au centre, sombre aux bords.
func _radial_inverse(col: Color) -> GradientTexture2D:
	var d := Gradient.new()
	d.set_color(0, Color(col.r, col.g, col.b, 0.0))
	d.set_color(1, col)
	d.set_offset(0, 0.58)
	var g := GradientTexture2D.new()
	g.gradient = d
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.06, 0.5)
	g.width = 256
	g.height = 256
	return g


func _draw() -> void:
	if enc == null:
		return
	if pupitre != null:
		pupitre.ecran = size_ecran()
		pupitre.queue_redraw()
	var sel = enc.selected
	# La ville d'origine du convoi choisi ressort dans le gril (.beam-lit) ;
	# c'est le plan, dessous, qui porte le faisceau.
	if plan != null:
		var f: String = String(sel.from) if sel != null else ""
		if plan.faisceau != f:
			plan.faisceau = f
			plan.queue_redraw()
	var t := Time.get_ticks_msec() / 1000.0
	var d := decalage()
	if plan != null and plan.position != d:
		plan.position = d
	draw_set_transform(d)
	_dessiner_quais(sel, t)
	_dessiner_itineraires()
	_dessiner_convois(sel, t)
	_dessiner_signaux(t)
	draw_set_transform(Vector2.ZERO)
	_dessiner_hud(t)
	# LES PASTILLES PASSENT EN DERNIER. « Il doit être au-dessus de tout » : une
	# heure de départ est la seule chose de l'écran qui commande un geste TOUT
	# DE SUITE, et elle se retrouvait sous le cadran quand un convoi tenait le
	# premier quai. Le bandeau est dessiné avant elles — et il leur sert
	# d'obstacle, pour qu'elles n'aient pas non plus à le couvrir.
	draw_set_transform(d)
	_dessiner_badges(t)
	draw_set_transform(Vector2.ZERO)
	_dessiner_coach(t)
	_dessiner_fin()


# --- les quais : les états, peints sur la pilule du plan ---------------------
func _train_a_quai(pid) -> Variant:
	for t in enc.trains:
		if t.platform == pid and (t.state == Enc.S_DWELL or t.state == Enc.S_MOVING_IN):
			return t
	return null


func _quai_en_defaut(pid) -> bool:
	for t in enc.trains:
		if t.platform == pid and t.wrong_platform and t.state == Enc.S_DWELL:
			return true
	return false


func _train_promis(pid) -> Variant:
	for t in enc.trains:
		if t.target == pid and (t.state == Enc.S_WAITING or t.state == Enc.S_APPROACHING):
			return t
	return null


func _boucle(contour: PackedVector2Array) -> PackedVector2Array:
	var b := contour.duplicate()
	b.append(contour[0])
	return b


## LES HACHURES DU QUAI FERMÉ. Le prototype en posait une VERTICALE toutes les
## huit unités : sur une plaque de 262 par 42, cela faisait trente-trois barres
## rouges collées — un code-barres, et c'est exactement ce que Vincent a vu.
## Une voie condamnée se barre en DIAGONALE, c'est le geste universel, et il
## en faut peu : un trait tous les seize points suffit à dire « pas ici ».
## Le rouge reste, il est la signalisation — il baisse seulement d'intensité,
## parce qu'un signal qu'on hurle n'est pas plus clair qu'un signal qu'on dit.
func _hachures(r: Rect2, col: Color) -> void:
	var inner := r.grow(-5)
	var pas := 16.0
	# une diagonale à 45° est la droite x + y = c : on la coupe au rectangle
	var c := inner.position.x + inner.position.y
	var fin := inner.end.x + inner.end.y
	while c <= fin:
		var x0: float = max(inner.position.x, c - inner.end.y)
		var x1: float = min(inner.end.x, c - inner.position.y)
		if x1 > x0:
			draw_line(Vector2(x0, c - x0), Vector2(x1, c - x1), col, 2.6, true)
		c += pas


func _dessiner_quais(sel, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * TAU / 1.2)        # elig-pulse : 1,2 s
	var pulse_lent := 0.5 + 0.5 * sin(t * TAU / 2.2)   # .eligible.busy : 2,2 s
	var pulse_faute := 0.5 + 0.5 * sin(t * TAU / 1.0)  # wrong-pulse : 1 s
	for q in G["platforms"]:
		var pid = q["id"]
		var r := Rect2(Geo.PLAT_X1, float(q["cy"]) - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
		var contour := Sty.rect_arrondi(r, 10)

		# FERMÉ : pilule éteinte, hachures, numéro estompé, heure de réouverture
		if enc.platform_closed(pid):
			# LA PLAQUE EST DÉPOSÉE : creusée, barrée en diagonale, cerclée de
			# rouge. Le numéro s'éteint sans disparaître — on doit encore
			# pouvoir dire DE QUEL quai on parle.
			draw_colored_polygon(contour, Sty.POSTE_QUAI_FERME)
			draw_polyline(_boucle(contour), Color(0, 0, 0, 0.45), 3.0, true)
			_hachures(r, Color(Sty.ROUGE, 0.26))
			draw_polyline(_boucle(contour), Color(Sty.ROUGE, 0.55), 1.6, true)
			# le numéro se détoure : les hachures le traversent, et il faut
			# encore pouvoir dire DE QUEL quai on parle.
			Sty.texte_centre(self, Sty.titre(600), 26, r.get_center(), str(int(pid)),
				Color(Sty.TEXTE, 0.50), 5, Color(0, 0, 0, 0.65))
			var fin := ""
			for ev in enc.events:
				if ev.get("type") == "closure" and ev["plat"] == pid and ev["revealed"] and not ev["cleared"]:
					fin = "fermé jusqu'à " + fmt(float(ev["end"]))
			if fin != "":
				var haut := Vector2(Geo.PLAT_MID, r.position.y - 13)
				Sty.texte_centre(self, Sty.mono(600), 13, haut, fin, Color(Sty.ROUGE, 0.30), 7, Color(Sty.ROUGE, 0.30))
				Sty.texte_centre(self, Sty.mono(600), 13, haut, fin, Sty.ROUGE)
			continue

		# ÉLIGIBLE : tous les quais atteignables depuis l'origine du convoi
		# choisi, au même titre — on n'indique PAS lequel dessert vraiment.
		var eligible: bool = sel != null and sel.target == null \
			and enc.links.get(sel.from, []).has(pid) and not enc.platform_claimed(pid)
		if eligible:
			var col := Color(String(G["dest_color"][sel.to]))
			var occupe: bool = enc.platform_occupied(pid)
			var p: float = pulse_lent if occupe else pulse
			# le quai libre se teinte (color-mix 14 %) ; l'occupé garde son
			# dégradé et souffle plus lentement : « oui, mais pas tout de suite »
			if not occupe:
				draw_colored_polygon(contour, Sty.POSTE_QUAI_ELIGIBLE.lerp(col, 0.14))
				# la teinte recouvre le numéro peint par le plan : on le repose
				Sty.texte_centre(self, Sty.titre(600), 26, r.get_center(), str(int(pid)), Sty.TEXTE)
			var larg: float = 2.5 + 0.9 * p
			Sty.pointille(self, contour, Color(col, 0.08 + 0.20 * p), larg + 8.0, 7, 5)
			Sty.pointille(self, contour, col, larg, 7, 5)
		else:
			# OCCUPÉ : liseré à la couleur du convoi présent
			var occupant = _train_a_quai(pid)
			if occupant != null:
				draw_polyline(_boucle(contour), Color(String(G["dest_color"][occupant.to])), 2.5, true)
			# EN DÉFAUT : un convoi y stationne sans pouvoir repartir
			if _quai_en_defaut(pid):
				draw_polyline(_boucle(contour), Sty.ROUGE, 2.5 + 1.1 * pulse_faute, true)

		# PROMIS : un convoi encore dehors l'a choisi. Liseré INTÉRIEUR, à SA
		# couleur, qui défile vers le quai — le quai est pris même s'il paraît
		# libre. Il se lit en même temps que le liseré d'occupation.
		var promis = _train_promis(pid)
		if promis != null:
			var interieur := Sty.rect_arrondi(Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10)), 6)
			Sty.pointille(self, interieur, Color(String(G["dest_color"][promis.to])), 2.4, 6, 6, t * 10.9)


# --- les itinéraires --------------------------------------------------------
func _dessiner_itineraires() -> void:
	for pid in enc.active_routes:
		var t = enc.active_routes[pid]
		var p: Dictionary = enc.paths[pid]
		Sty.trait_halo(self, Geo.vers_vector2(p["xs"], p["ys"]), Color(String(G["dest_color"][t.to])), 5.0, 4.0)
	# l'itinéraire PROMIS, en attente d'entrée : pointillé 10 8 à 55 %
	for t in enc.trains:
		if t.target != null and (t.state == Enc.S_WAITING or t.state == Enc.S_APPROACHING):
			var pid := "in:%s:%d" % [t.from, int(t.target)]
			if enc.paths.has(pid) and not enc.active_routes.has(pid):
				var p: Dictionary = enc.paths[pid]
				Sty.pointille(self, Geo.vers_vector2(p["xs"], p["ys"]),
					Color(String(G["dest_color"][t.to]), 0.55), 5.0, 10, 8, 0.0, false)


# --- les convois ------------------------------------------------------------
## L'embarquement : la part REMPLIE du convoi, de 0 à 1. Les voyageurs montent
## de la tête vers la queue entre l'arrivée réelle et l'heure de départ
## (js/render.js, updateBoarding). Hors arrêt, ou sur un mauvais quai, le
## convoi reste plein : il repartira sans que personne ne descende.
func _embarquement(t) -> float:
	if t.freight or t.state != Enc.S_DWELL or t.actual_arr == null:
		return 1.0
	if not enc.paths.has("out:%s:%d" % [t.to, int(t.platform)]):
		return 1.0
	var arr: float = float(t.actual_arr)
	var fin: float = max(t.dep, arr + Geo.MIN_DWELL)
	var denom: float = fin - arr
	return 1.0 if denom <= 0.0 else clampf((enc.game_min - arr) / denom, 0.0, 1.0)


## LE CONVOI EST UN TRAIN GRAVÉ.
##
## Trois planches dessinées du dessus, à l'encre, détourées : une machine, une
## voiture, un fourgon (jeu/illustrations.gd, tools/illustrations.sh). Leur
## canal alpha porte la silhouette, leurs couleurs portent le gris du dessin —
## multipliées par la teinte de destination, elles donnent une gravure mise en
## couleur, et une seule planche sert les six couleurs du jeu.
##
## UN VÉHICULE PAR CASE. Une case du gril fait 35 sur 30 : le véhicule y est
## trapu. On a essayé la voiture longue, sur deux cases, mieux proportionnée —
## et Vincent lui a préféré la rame courte, où chaque véhicule est une case et
## où le compte des voitures se voit sans compter. Une machine en tête, des
## fourgons derrière. `wagon.png` reste dans les sources, inutilisé.
##
## RIEN DE CE QUE LE JEU MESURE NE BOUGE : la rame occupe exactement les mêmes
## cases, donc même longueur, même quai nécessaire, même point d'arrêt, mêmes
## positions pour les signaux et les pastilles. Seul change ce qu'on dessine
## dessus.
##
## LES QUATRE CONTRATS ONT ÉTÉ REFAITS, comme à chaque changement de dessin :
## le halo blanc de la sélection et l'ambre du convoi retenu deviennent des
## nappes autour du corps entier ; le liseré du fret reste épais et opaque et
## son corps reste gris, seule sa machine gardant la teinte ; le masque
## d'embarquement vide la queue CASE PAR CASE, comme avant, mais en découpant
## chaque case entre ses deux coupures.
##
## L'INITIALE DE DESTINATION DISPARAÎT. Elle doublait la couleur, qui est déjà
## la destination, et le nom du portail l'écrit en toutes lettres au bout de
## chaque voie. Une ligne à remettre si elle manque.
func _dessiner_convois(sel, t: float) -> void:
	var anneau := 0.65 + 0.35 * sin(t * TAU / 1.1)      # ring-pulse : 1 → .3
	for tr in enc.trains:
		if not positions.has(tr.id):
			continue
		var pos: Array = positions[tr.id]
		if pos.is_empty():
			continue
		var axe := PackedVector2Array()
		var angles := PackedFloat32Array()
		for p in pos:
			axe.append(Vector2(float(p["x"]), float(p["y"])))
			angles.append(deg_to_rad(float(p["ang"])))
		if axe.size() < 2:
			axe.append(axe[0] - Vector2(Geo.CAR_SPACING * 0.5, 0))
			angles.append(angles[0])
		var col := Color(String(G["dest_color"][tr.to]))
		var choisi: bool = tr == sel
		var k := Sty.UIK
		# La HAUTEUR grossit au doigt, la LONGUEUR jamais : elle tient à
		# l'espacement du gril, l'étirer ferait se chevaucher les convois.
		var h: float = Geo.CAR_H * k

		# LA SÉLECTION EST UN CLIGNOTEMENT, PLUS UNE COURONNE. Une couronne
		# blanche cernait la rame d'un liseré large ; sur une caisse peinte elle
		# se lisait, sur un train DESSINÉ elle se lit comme une bavure autour du
		# dessin. Le convoi choisi FOND ET REVIENT : le signal est porté par
		# l'objet lui-même, pas par ce qui l'entoure, et rien ne peut le
		# confondre avec le halo de destination.
		var vie: float = 1.0
		if choisi:
			vie = 0.38 + 0.62 * (0.5 + 0.5 * sin(t * TAU / 0.9))
		# LE CONVOI RETENU GARDE SA COURONNE, à l'ambre : c'est un autre état,
		# il lui faut un autre signe. Sans quoi « choisi » et « retenu » se
		# diraient de la même façon.
		if tr.holding:
			for couche in [[16.0, 0.10], [10.0, 0.18], [5.5, 0.34], [2.5, 0.75]]:
				draw_polyline(axe, Color(Sty.AMBRE, float(couche[1]) * anneau * 0.9),
					h + float(couche[0]) * k, true)
		# PLUS DE HALO DE DESTINATION, ET J'AVAIS COMPRIS L'INVERSE. « Pas de
		# halo coloré pour le convoi de fret, il se confond avec les autres. Pas
		# de halo non plus pour les autres en fait » : c'était une consigne, je
		# l'ai lue comme un constat de manque et je les ai RENFORCÉS. Ils
		# partent.
		#
		# Ce qu'ils portaient ne se perd pas : la destination d'un convoi reste
		# dite par sa caisse, et sur un fret — dont les wagons sont gris — par sa
		# machine colorée et son liseré épais, qui restent. Un halo autour d'un
		# train DESSINÉ ajoutait une lueur là où le dessin a déjà un contour ;
		# c'est ce qui les faisait tous se ressembler.
		#
		# Ce qui disparaît vraiment, et il faut le dire : la RESPIRATION du
		# convoi qui attend, qui était portée par la largeur de ce halo. Le
		# badge d'heure la porte désormais seul.
		# LE LISERÉ DU FRET PART AUSSI. C'était le dernier halo, et il l'était
		# bel et bien : une polyligne cinq unités plus large que la caisse, à la
		# teinte de destination, qui débordait de tous côtés d'un train qui a
		# déjà son contour d'encre.
		#
		# LE FRET RESTE POURTANT LE PLUS RECONNAISSABLE DES CONVOIS, et par trois
		# marques qu'aucun autre ne porte : ses wagons sont GRIS quand sa machine
		# garde la couleur de destination — un contraste qu'aucun train de
		# voyageurs n'a — et il n'affiche AUCUNE heure de départ, parce qu'il
		# n'en a pas. Le liseré était la quatrième façon de dire la même chose.

		var coupes := _coupures(axe, angles)
		# UN VÉHICULE PAR CASE, ET RIEN QUE DES FOURGONS DERRIÈRE LA MACHINE.
		# Les voitures de deux cases donnaient une rame mieux proportionnée, mais
		# Vincent leur préfère la lecture de la rame courte, où chaque véhicule
		# est une case et où le compte se voit sans compter. `wagon.png` reste
		# dans les sources, inutilisé.
		for i in axe.size():
			var tex := Ill.vehicule("loco" if i == 0 else "fourgon")
			if tex == null:
				tex = Ill.vehicule("wagon")
			# la machine garde la teinte de destination même sur un fret, dont
			# les wagons sont gris : c'est elle qui annonce où il va
			var teinte: Color = col if (i == 0 or not tr.freight) else Sty.FRET
			var lavis := Color(teinte.lerp(Sty.PAPIER, 0.06), vie)
			for j in SOUS_CASES:
				var t0: float = float(i) + float(j) / float(SOUS_CASES)
				var t1: float = float(i) + float(j + 1) / float(SOUS_CASES)
				var a := _le_long_des_coupes(coupes, t0)
				var b := _le_long_des_coupes(coupes, t1)
				var quad := PackedVector2Array([
					a["p"] - a["n"] * h * 0.5, b["p"] - b["n"] * h * 0.5,
					b["p"] + b["n"] * h * 0.5, a["p"] + a["n"] * h * 0.5])
				var u0: float = float(j) / float(SOUS_CASES)
				var u1: float = float(j + 1) / float(SOUS_CASES)
				if tex != null:
					draw_colored_polygon(quad, lavis, PackedVector2Array([
						Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), tex)
				else:
					draw_colored_polygon(quad, lavis)

		# LE VIDE N'EST PLUS UN VOILE NOIR, C'EST LA MÊME CAISSE EN SOURDINE.
		# Le masque d'embarquement peignait un aplat presque noir par-dessus la
		# portion non remplie : sur une caisse peinte il se lisait, sur un
		# véhicule DESSINÉ il l'effaçait — « c'est tellement sombre qu'on ne
		# voit plus bien les fourgons » (Vincent, 9 septembre 2026). On repeint
		# donc la portion vide avec LA MÊME PLANCHE, dans une encre éteinte : le
		# dessin reste lisible, le véhicule garde sa forme et son contour, et
		# « vide » se dit par la VALEUR au lieu d'effacer l'objet.
		#
		# Les voyageurs montent de la tête vers la queue, case par case comme
		# avant, et la découpe suit la même courbe que la caisse.
		var plein := _embarquement(tr)
		if plein < 1.0:
			var n := axe.size()
			for i in n:
				var frac: float = clampf(plein * float(n) - float(i), 0.0, 1.0)
				if frac >= 1.0:
					continue
				var tex := Ill.vehicule("loco" if i == 0 else "fourgon")
				var teinte: Color = col if (i == 0 or not tr.freight) else Sty.FRET
				var eteint := Color(teinte.lerp(Sty.POSTE_FOND, 0.60), vie)
				for j in 2:
					var f0: float = lerpf(frac, 1.0, float(j) / 2.0)
					var f1: float = lerpf(frac, 1.0, float(j + 1) / 2.0)
					var a := _le_long_des_coupes(coupes, float(i) + f0)
					var b := _le_long_des_coupes(coupes, float(i) + f1)
					var quad := PackedVector2Array([
						a["p"] - a["n"] * h * 0.5, b["p"] - b["n"] * h * 0.5,
						b["p"] + b["n"] * h * 0.5, a["p"] + a["n"] * h * 0.5])
					if tex != null:
						draw_colored_polygon(quad, eteint, PackedVector2Array([
							Vector2(f0, 0), Vector2(f1, 0), Vector2(f1, 1), Vector2(f0, 1)]), tex)
					else:
						draw_colored_polygon(quad, eteint)


## LES COUPURES ENTRE CASES, avec leur normale : une case commence à mi-chemin
## de la voiture précédente et finit à mi-chemin de la suivante. Les véhicules
## PARTAGENT ces arêtes, ce qui permet à une voiture de deux cases de se plier
## dans la courbe sans laisser de fente à son articulation — une seule facette
## lui aurait fait couper la corde.
## LES BOUTS SE POSENT SUR LA TANGENTE RÉELLE DE LA VOIE, pas sur la corde.
##
## C'est ce qui manquait à une rame de DEUX véhicules, et l'explication est
## géométrique. Les coupures des bouts se plaçaient dans la direction rendue par
## les centres voisins ; à deux centres, cette direction est la même des deux
## côtés — la corde — et la coupure du milieu en est le milieu. Les trois
## coupures étaient donc COLINÉAIRES, la spline qui les traverse était une
## droite, et la rame restait raide quel que soit le virage : « quand il y a
## deux éléments, c'est toujours rigide » (Vincent, 9 septembre 2026).
##
## L'enclenchement donne pourtant à chaque voiture SON angle, mesuré sur la
## voie. On s'en sert : le bout se pose dans cette direction-là, qui n'est pas
## celle de la corde dès que ça tourne, et les trois coupures cessent d'être
## alignées. Son SIGNE, en revanche, ne veut rien dire — la rotation est bridée
## à l'endroit, le +x local pointe toujours à droite de l'écran — on le retourne
## donc vers la queue.
##
## LA CASE DU BOUT PREND LA MOITIÉ DE SA CORDE, et non un demi-pas fixe : les
## voitures sont espacées d'un pas constant LE LONG DE LA VOIE, si bien qu'en
## courbe les cases du milieu, mesurées de corde à corde, se resserrent. Sans
## cela le premier et le dernier véhicule paraissent plus longs que les autres.
func _coupures(axe: PackedVector2Array, angles: PackedFloat32Array) -> Array:
	var n := axe.size()
	var out: Array = []
	for i in n + 1:
		var p: Vector2
		var u: Vector2
		if i == 0:
			u = _vers_la_queue(angles[0], axe[1] - axe[0])
			p = axe[0] - u * axe[0].distance_to(axe[1]) * 0.5
		elif i == n:
			u = _vers_la_queue(angles[n - 1], axe[n - 1] - axe[n - 2])
			p = axe[n - 1] + u * axe[n - 2].distance_to(axe[n - 1]) * 0.5
		else:
			u = (axe[i] - axe[i - 1]).normalized()
			p = (axe[i - 1] + axe[i]) / 2.0
		out.append({"p": p, "n": Vector2(-u.y, u.x)})
	return out


func _vers_la_queue(angle: float, sens: Vector2) -> Vector2:
	var u := Vector2.RIGHT.rotated(angle)
	return -u if u.dot(sens) < 0.0 else u


## LE POINT ET LA NORMALE À UN ENDROIT QUELCONQUE DE LA RAME, l'indice étant
## compté en cases : 0 au nez, 1 à la première coupure, 2,5 au milieu de la
## troisième case. La position suit une spline de Catmull-Rom passant par les
## coupures — c'est ce qui donne une COURBE là où les seules coupures ne
## donnaient qu'une ligne brisée — et la normale se prend sur sa tangente, donc
## au bon endroit et non à celui de la coupure la plus proche.
const SOUS_CASES := 3

func _le_long_des_coupes(coupes: Array, t: float) -> Dictionary:
	var n := coupes.size()
	var i: int = clampi(int(floor(t)), 0, n - 2)
	var f: float = clampf(t - float(i), 0.0, 1.0)
	var p0: Vector2 = coupes[max(0, i - 1)]["p"]
	var p1: Vector2 = coupes[i]["p"]
	var p2: Vector2 = coupes[i + 1]["p"]
	var p3: Vector2 = coupes[min(n - 1, i + 2)]["p"]
	# aux deux bouts, on prolonge par symétrie plutôt que de plafonner : sans
	# quoi la spline s'aplatit et le nez de la rame redevient rigide
	if i == 0:
		p0 = p1 * 2.0 - p2
	if i + 2 > n - 1:
		p3 = p2 * 2.0 - p1
	var f2 := f * f
	var f3 := f2 * f
	var p: Vector2 = 0.5 * (2.0 * p1 + (p2 - p0) * f
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2
		+ (p3 - p0 + 3.0 * (p1 - p2)) * f3)
	var d: Vector2 = 0.5 * ((p2 - p0) + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * 2.0 * f
		+ (p3 - p0 + 3.0 * (p1 - p2)) * 3.0 * f2)
	if d.length() < 1e-6:
		d = p2 - p1
	d = d.normalized() if d.length() > 1e-6 else Vector2.RIGHT
	return {"p": p, "n": Vector2(-d.y, d.x)}


# --- le signal d'arrêt ---# --- le signal d'arrêt ------------------------------------------------------
## Un convoi prêt dont la voie de sortie est prise ne doit pas rester muet,
## sinon son immobilité se lit comme un bug. On plante un vrai signal devant sa
## motrice : mât, cible à deux feux, le rouge allumé et pulsé (js/render.js,
## signalNode). Il reste tant que le convoi est retenu.
##
## C'ÉTAIT LE DERNIER OBJET BLEU DU PUPITRE. Mât, cible et feu éteint venaient
## du prototype — #55617a, #0e1420, #1c2740 — et faisaient trois taches froides
## sur une planche de laiton. Il passe à la matière commune, et la
## SIGNALISATION NE BOUGE PAS D'UN IOTA : le rouge pulse, le vert reste éteint,
## aux mêmes places et au même rythme. C'est même la pièce la plus « poste
## d'aiguillage » de l'écran ; elle méritait d'en avoir l'air.
func _dessiner_signaux(t: float) -> void:
	var lampe := 0.45 + 0.55 * (0.5 + 0.5 * sin(t * TAU / 1.1))   # sig-pulse
	for tr in enc.trains:
		if not tr.holding or tr.state != Enc.S_DWELL or not positions.has(tr.id):
			continue
		var pos: Array = positions[tr.id]
		if pos.size() < 2:
			continue
		var tete := Vector2(float(pos[0]["x"]), float(pos[0]["y"]))
		var dir: float = 1.0 if tete.x >= float(pos[1]["x"]) else -1.0
		var k := Sty.UIK
		var o := tete + Vector2(dir * (Geo.CAR_LEN / 2.0 + 14.0 * k), 2.0 * k)
		# le socle : un signal est boulonné au ballast, il ne flotte pas
		draw_style_box(Sty.boite(Sty.POSTE_BALLAST, Color(Sty.POSTE_BORD, 0.45),
			1.5 * k, max(1.0, 0.9 * k)), Rect2(o.x - 5.0 * k, o.y + 11.0 * k, 10.0 * k, 3.6 * k))
		# le mât : fonte sombre, et une arête de lumière sur son flanc gauche —
		# c'est ce qui fait un cylindre plutôt qu'un trait
		draw_style_box(Sty.boite(Sty.POSTE_BALLAST, Sty.POSTE_BALLAST, 1.6 * k, 0),
			Rect2(o.x - 1.7 * k, o.y - 2.0 * k, 3.4 * k, 14.0 * k))
		draw_line(o + Vector2(-0.7 * k, -1.0 * k), o + Vector2(-0.7 * k, 12.0 * k),
			Color(Sty.POSTE_BORD, 0.50), max(1.0, 1.0 * k), true)
		# la cible : la même plaque sombre cerclée de laiton que le cadran
		draw_style_box(Sty.boite(Color(0, 0, 0, 0.70), Color(Sty.POSTE_BORD, 0.75),
			4.5 * k, max(1.0, 1.1 * k)), Rect2(o.x - 7.5 * k, o.y - 23.0 * k, 15.0 * k, 22.0 * k))
		_feu(o + Vector2(0, -17.0 * k), Sty.ROUGE, lampe, k)
		_feu(o + Vector2(0, -7.0 * k), Sty.VERT, 0.0, k)


## UN FEU EST UNE LENTILLE SOUS UNE VISIÈRE, pas un disque de couleur. La
## visière — l'auvent de tôle qui coiffe chaque lentille pour qu'on la voie de
## loin sans que le soleil l'allume — est le détail qui dit « signal » à qui a
## déjà vu une voie. Éteint, le feu garde SA teinte, très foncée : un vert
## éteint doit se lire comme un vert qui n'est pas allumé, pas comme un trou.
func _feu(centre: Vector2, col: Color, allume: float, k: float) -> void:
	if allume > 0.0:
		draw_circle(centre, 8.2 * k, Color(col, 0.10 * allume))
		draw_circle(centre, 5.6 * k, Color(col, 0.20 * allume))
	draw_circle(centre, 4.0 * k, Color(0, 0, 0, 0.60))                       # la douille
	draw_circle(centre, 3.3 * k, col.darkened(0.74) if allume <= 0.0 else Color(col, 0.40 + 0.60 * allume))
	# le reflet du verre, en haut à gauche
	draw_arc(centre + Vector2(-0.7 * k, -0.7 * k), 1.8 * k, PI * 1.02, PI * 1.72, 10,
		Color(1, 1, 1, 0.14 + 0.26 * allume), max(1.0, 0.9 * k), true)
	# la visière de tôle, par-dessus
	draw_arc(centre + Vector2(0, -0.6 * k), 4.9 * k, PI * 1.06, TAU * 0.97, 16,
		Color(Sty.POSTE_BORD, 0.62), 1.4 * k, true)


# --- les badges d'heure -----------------------------------------------------
## Le cadran de l'horloge, aiguilles figées sur 10 h 10 : la pose qui se lit le
## mieux en tout petit. Il dit « heure de départ » sans mot à lire, et s'efface
## quand le badge bascule sur le retard — « +3 min » n'est plus une heure.
func _cadran(centre: Vector2, col: Color, k: float = 1.0) -> void:
	draw_arc(centre, 5.4 * k, 0.0, TAU, 24, col, 1.4 * k, true)
	draw_line(centre, centre + Vector2(0, -3.2 * k), col, 1.4 * k, true)
	draw_line(centre, centre + Vector2(2.6 * k, 1.6 * k), col, 1.4 * k, true)


## LA PASTILLE NE S'ÉCARTE DE RIEN, ET C'EST LA RÉPONSE.
##
## J'ai construit en deux passes un placement qui l'écartait de ce qu'elle
## couvrait : d'abord vers le haut, puis sur le côté. Les deux étaient faux
## pour la même raison, et Vincent l'a dit d'une phrase — « elle doit suivre le
## même mouvement que le convoi ». Une étiquette rigidement attachée à un objet
## MOBILE ne peut pas négocier sa place : ce qu'elle rencontre change à chaque
## image, donc elle se décale à chaque image, et elle cesse d'appartenir à son
## convoi. Le solveur était la mauvaise réponse à une vraie question.
##
## La bonne réponse tenait en deux choses, et toutes deux sont déjà faites : la
## pastille se dessine EN DERNIER, donc elle passe devant ce qu'elle croise au
## lieu de disparaître dessous ; et les noms de portail, montés avec leur
## nouvelle taille, ne la rencontrent plus que de quelques unités. Elle suit sa
## tête, à hauteur constante, et rien d'autre.
func _dessiner_badges(t: float) -> void:
	var clign := 0.22 + 0.78 * (0.5 + 0.5 * sin(t * TAU / 0.9))   # badge-blink
	for tr in enc.trains:
		if not positions.has(tr.id):
			continue
		# jamais pour le fret : ce qui le distingue, c'est justement l'absence
		# d'heure de départ.
		var montre: bool = not tr.freight and not tr.wrong_platform \
			and tr.state != Enc.S_MOVING_OUT and tr.state != Enc.S_DONE \
			and not (tr.state == Enc.S_APPROACHING and not tr.settled)
		if not montre:
			continue
		var late: float = Enc.lateness(tr, enc.game_min)
		var en_retard: bool = late >= 1
		var txt: String = ("+%d min" % int(floor(late))) if en_retard else fmt(tr.dep)
		var col: Color = Sty.ROUGE if en_retard else (Sty.AMBRE if late > -3 else Sty.VERT)
		var k := Sty.UIK
		var police := Sty.mono(700 if en_retard else 600)
		var taille := int(round(12 * k))
		var w := police.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var cadran: bool = not en_retard
		var large: float = w + 24.0 * k + (14.0 * k if cadran else 0.0)
		var tete: Dictionary = positions[tr.id][0]
		# TRENTE-DEUX AU-DESSUS DE SA TÊTE, et cette valeur ne dépend de rien
		# d'autre : c'est ce qui fait que la pastille suit exactement le
		# mouvement du convoi, sans jamais glisser par rapport à lui.
		#
		# Elle était à quarante-deux, ce qui laissait vingt-sept unités de vide
		# entre le bas de la pastille et le haut du quai — assez pour qu'elle
		# paraisse flotter au-dessus plutôt que d'appartenir au convoi. À
		# trente-deux il en reste douze : elle se pose dessus.
		var centre := Vector2(float(tete["x"]), float(tete["y"]) - 32.0 * k)
		var r := Rect2(centre.x - large / 2.0, centre.y - 10.0 * k, large, 20.0 * k)
		# un convoi encore à l'arrêt dont le retard court réclame un aiguillage :
		# le badge clignote (en opacité seule).
		var a: float = clign if (en_retard and not tr.settled) else 1.0
		# LA PASTILLE EST UNE PLAQUE ÉMAILLÉE. C'était le dernier objet générique
		# du pupitre : un rectangle sombre à liseré. On lui donne son ombre —
		# elle est posée sur la planche, pas peinte dessus — un émail plus
		# profond, et un filet de brillance sous l'arête haute. Le liseré reste
		# à la couleur de l'état : c'est lui qui parle.
		draw_style_box(Sty.boite(Color(0, 0, 0, 0.30 * a), Color(0, 0, 0, 0),
			Sty.R_PETIT * k, 0), Rect2(r.position + Vector2(0, 2.0 * k), r.size))
		draw_style_box(Sty.boite(Color(Sty.BADGE_FOND, min(1.0, Sty.BADGE_FOND.a * 1.15) * a),
			Color(col, a), Sty.R_PETIT * k, 1.2 * k), r)
		draw_line(r.position + Vector2(6.0 * k, 2.2 * k), Vector2(r.end.x - 6.0 * k, r.position.y + 2.2 * k),
			Color(1, 1, 1, 0.10 * a), max(1.0, 1.0 * k), true)
		var x := r.position.x + 12.0 * k
		if cadran:
			_cadran(Vector2(x, centre.y), Color(col, a), k)
			x += 14.0 * k
		Sty.texte_centre(self, police, taille, Vector2(x + w / 2.0, centre.y), txt, Color(col, a))


# --- le bandeau -------------------------------------------------------------
## La taille RÉELLE de la scène. 1400 × 760 n'est que la base : le viewport
## s'étire (stretch « expand »), et sur un téléphone il est plus large. Le
## bandeau s'ancre donc sur les bords réels, pas sur la base.
func size_ecran() -> Vector2:
	return get_viewport_rect().size


## LE PLAN SE RECENTRE. Avec `stretch: expand`, un écran plus allongé que la
## base donne un viewport plus large, et Godot ajoute la place À DROITE :
## le gril se retrouvait décalé de 6 % vers la gauche sur un iPhone (mesuré
## le 3 septembre 2026 — ni `expand` ni `keep_height` ne recentrent). Le
## BANDEAU, lui, garde les vrais bords : c'est là qu'on va le chercher.
func decalage() -> Vector2:
	# le plan se centre dans la ZONE SÛRE, pas dans l'écran brut
	var m := Sty.marges
	var utile := size_ecran() - Vector2(m["gauche"] + m["droite"], m["haut"] + m["bas"])
	var d := (utile - Vector2(1400.0, 760.0)) / 2.0
	return Vector2(m["gauche"] + max(0.0, d.x), m["haut"] + max(0.0, d.y))


## Une chip de verre dépoli : le gabarit commun du bandeau (#hud-clock,
## #station-tag, les trois boutons) — fond rgba(21,29,46,.55), liseré #2a3550,
## coins de 12. Le flou du web n'existe pas ici : le fond translucide seul
## suffit, les voies restent lisibles dessous.
func _chip(r: Rect2, bord: Color = Sty.POSTE_BORD, k: float = 1.0) -> void:
	draw_style_box(Sty.boite(Color(Sty.POSTE_QUAI_HAUT, 0.88), bord, 12 * k, max(1.0, k)), r)


func _dessiner_hud(t: float) -> void:
	var sans := Sty.sans()
	var gras := Sty.sans(600)
	# Le bandeau garde sa TAILLE PHYSIQUE d'un écran à l'autre : au bureau
	# k vaut 1 et rien ne change ; sur un téléphone il grossit d'autant que le
	# viewport a été étiré (jeu/style.gd, calibrer).
	var k := Sty.HUD_K
	var ti := func(v: float) -> int: return int(round(v * k))
	zones_hud.clear()

	# --- le cartouche de gare, en haut à gauche : c'est le bouton RETOUR ------
	# LE DRAPEAU S'EN VA. Un drapeau est une paire d'indicateurs régionaux que
	# la police doit savoir composer : macOS le fait, l'iPhone de Vincent non —
	# et comme je lui réservais sa place au cas où sa largeur mentirait, il ne
	# restait qu'un TROU entre le chevron et « York ». Il ne manquera à
	# personne : le pays est écrit en toutes lettres sur la fiche du ruban,
	# juste avant qu'on prenne le service.
	var nom := String(fiche.get("name", ""))
	var d := int(fiche_jouee.get("difficulty", fiche.get("difficulty", 1)))
	var w_nm := gras.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, ti.call(15)).x
	var w_pips := (5.0 * 4.0 + 4.0 * 3.0) * k
	var large := (10.0 + 14.0 + 8.0) * k + w_nm + 12.0 * k + w_pips + 13.0 * k
	var chip := Rect2(Sty.marges["gauche"] + 4 * k, Sty.marges["haut"] + 10 * k, large, 34 * k)
	zones_hud["carte"] = chip
	# LE LISERÉ DU CARTOUCHE DE GARE ÉTAIT BLEU — `Sty.BORD`, #2a3550, hérité du
	# prototype — quand les trois boutons de droite sont cerclés de laiton. Il
	# les rejoint.
	_chip(chip, Sty.POSTE_BORD, k)
	var cy := chip.position.y + chip.size.y / 2.0
	var x := chip.position.x + 10.0 * k
	Sty.texte_centre(self, sans, ti.call(22), Vector2(x + 7 * k, cy - 1 * k), "‹", Sty.LAITON)
	x += (14.0 + 8.0) * k
	Sty.texte_centre(self, gras, ti.call(15), Vector2(x + w_nm / 2.0, cy), nom, Sty.TEXTE)
	# LA JAUGE RESPIRE. Trois unités séparaient « York » de ses crans : le nom
	# et la difficulté se lisaient comme un seul bloc, « York|||||».
	x += w_nm + 12.0 * k
	# la difficulté : la MÊME jauge à cinq crans que partout dans le jeu
	for i in range(5):
		draw_style_box(Sty.boite(Sty.AMBRE if i < d else Sty.POSTE_PIP_ETEINT, Color.TRANSPARENT, 1.5 * k, 0),
			Rect2(x + i * 7.0 * k, cy - 5.0 * k, 4.0 * k, 10.0 * k))

	# --- l'horloge, centrée : heure, retard, et la jauge du service ----------
	# LA SERIF DE LA MAQUETTE, ET DES CHIFFRES QUI NE SAUTENT PAS. Vincent a
	# fait dessiner une maquette où l'horloge est en romaine, et il a raison :
	# la mono était le dernier objet de l'écran à ne pas appartenir à la
	# direction artistique. Mais une horloge change de chiffre toutes les
	# minutes, et un chiffre plus étroit que le précédent la fait tressauter.
	# Mesuré sur les trois polices du jeu : Cinzel étale ses chiffres de 14 à
	# 24 unités — 42 % d'écart, l'heure danserait —, tandis que GARAMOND les
	# tient tous à 19, exactement comme la mono. C'est donc Garamond : la
	# serif qu'on voulait, et des chiffres tabulaires.
	var mono := Sty.sans(600)
	var horloge := fmt(enc.game_min)
	var retard := enc.live_delay()
	var txt_r := "+%d" % int(retard)
	var w_h := Sty.largeur_espacee(mono, ti.call(21), horloge, 1.0 * k)
	var w_r := mono.get_string_size(txt_r, HORIZONTAL_ALIGNMENT_LEFT, -1, ti.call(14)).x
	var w_chip := 13.0 * k + w_h + 8.0 * k + w_r + 13.0 * k
	var milieu: float = Sty.marges["gauche"] + (size_ecran().x - Sty.marges["gauche"] - Sty.marges["droite"]) / 2.0
	var ch := Rect2(milieu - w_chip / 2.0, Sty.marges["haut"] + 10 * k, w_chip, 38 * k)
	zones_hud["horloge"] = ch
	# LE CADRAN EST UN SEUL FOND. J'avais posé un guichet sombre DANS la chip
	# chaude : deux fonds, deux cadres, et le retard qui tombait à côté du
	# guichet sur la couleur de dessous — « il y a des fonds de couleur
	# différents » (Vincent, 5 septembre 2026), et il avait raison, c'était un
	# rapiéçage. La chip EST le cadran : une découpe sombre, un seul cerclage
	# de laiton, et tout ce qui se lit — heure, retard, jauge — dedans.
	draw_style_box(Sty.boite(Color(0, 0, 0, 0.42),
		Sty.ACCENT if (pause or gel) else Sty.POSTE_BORD, 12 * k, max(1.0, 1.2 * k)), ch)
	# LES QUATRE VIS DU CADRAN. Les plaques de quai en portent depuis le 4
	# septembre ; le cadran, lui, flottait sans attache. C'est le même objet —
	# une plaque vissée au pupitre — et la maquette le dit aussi.
	for vis in [ch.position + Vector2(8, 8) * k, Vector2(ch.end.x - 8 * k, ch.position.y + 8 * k),
			Vector2(ch.position.x + 8 * k, ch.end.y - 8 * k), ch.end - Vector2(8, 8) * k]:
		draw_circle(vis, 1.9 * k, Color(Sty.POSTE_BORD, 0.42))
		draw_circle(vis + Vector2(0, -0.5 * k), 1.0 * k, Color(0, 0, 0, 0.32))
	var base := ch.position.y + 5.0 * k + mono.get_ascent(ti.call(21))
	Sty.texte_espace(self, mono, ti.call(21), Vector2(ch.position.x + 13.0 * k, base),
		horloge, Sty.TEXTE, 1.0 * k)
	var col_r: Color = Sty.VERT if retard < 10 else (Sty.AMBRE if retard < 30 else Sty.ROUGE)
	draw_string(mono, Vector2(ch.position.x + 13.0 * k + w_h + 8.0 * k, base), txt_r,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ti.call(14), col_r)
	# la jauge : l'horloge se remplit à mesure que les convois quittent le quai
	var partis := 0
	for tr in enc.trains:
		if tr.state == Enc.S_DONE:
			partis += 1
	var part: float = float(partis) / float(max(1, enc.trains.size()))
	var jauge := Rect2(ch.position.x + 10.0 * k, ch.end.y - 7.0 * k, ch.size.x - 20.0 * k, 3.0 * k)
	# la jauge passe au laiton : la sarcelle du prototype était la dernière
	# couleur froide du pupitre, et elle n'y désignait rien.
	draw_style_box(Sty.boite(Color(Sty.LAITON, 0.16), Color.TRANSPARENT, 2 * k, 0), jauge)
	if part > 0.0:
		draw_style_box(Sty.boite(Sty.LAITON, Color.TRANSPARENT, 2 * k, 0),
			Rect2(jauge.position, Vector2(jauge.size.x * part, jauge.size.y)))
	# « EN PAUSE », sous l'horloge — et c'est une cible : on la touche pour
	# reprendre, comme la pilule du prototype.
	if pause or gel:
		var etiq := "EN PAUSE"
		var w_e := Sty.largeur_espacee(Sty.sans(700), ti.call(12), etiq, 1.5 * k)
		var re := Rect2(milieu - (w_e + 24.0 * k) / 2.0, ch.end.y + 5.0 * k, w_e + 24.0 * k, 22 * k)
		if not gel:
			zones_hud["pause"] = re
		draw_style_box(Sty.boite(Color(Sty.ACCENT, 0.14), Sty.ACCENT, 8 * k, 1 * k), re)
		Sty.texte_espace(self, Sty.sans(700), ti.call(12),
			Vector2(re.position.x + 12.0 * k, re.get_center().y + Sty.sans(700).get_ascent(ti.call(12)) / 2.0 - 1 * k),
			etiq, Sty.ACCENT, 1.5 * k)

	# --- les trois boutons, en haut à droite ---------------------------------
	var bx: float = size_ecran().x - Sty.marges["droite"] - 4.0 * k - 34.0 * k
	for bouton in [["gear", ""], ["speed", "%dx" % int(vitesse)], ["play", ""]]:
		var r := Rect2(bx, Sty.marges["haut"] + 10 * k, 34 * k, 34 * k)
		zones_hud[bouton[0]] = r
		var actif: bool = bouton[0] == "speed" and vitesse > 1.0
		_chip(r, Sty.ACCENT if actif else Sty.POSTE_BORD, k)
		var c := r.get_center()
		match bouton[0]:
			"speed":
				Sty.texte_espace(self, Sty.mono(700), ti.call(13),
					Vector2(c.x - Sty.largeur_espacee(Sty.mono(700), ti.call(13), bouton[1], 0.5 * k) / 2.0,
						c.y + Sty.mono(700).get_ascent(ti.call(13)) / 2.0 - 1 * k),
					bouton[1], Sty.ACCENT if actif else Sty.TEXTE, 0.5 * k)
			"play":
				if pause:
					draw_colored_polygon(PackedVector2Array([
						c + Vector2(-4, -6) * k, c + Vector2(7, 0) * k, c + Vector2(-4, 6) * k]), Sty.TEXTE)
				else:
					draw_rect(Rect2(c.x - 5 * k, c.y - 6 * k, 3.5 * k, 12 * k), Sty.TEXTE, true)
					draw_rect(Rect2(c.x + 1.5 * k, c.y - 6 * k, 3.5 * k, 12 * k), Sty.TEXTE, true)
			"gear":
				draw_arc(c, 6.0 * k, 0.0, TAU, 24, Sty.ACCENT if reglages_ouverts else Sty.TEXTE, 1.8 * k, true)
				for i in range(6):
					var a: float = TAU * float(i) / 6.0
					var u := Vector2(cos(a), sin(a))
					draw_line(c + u * 6.5 * k, c + u * 9.0 * k,
						Sty.ACCENT if reglages_ouverts else Sty.TEXTE, 1.8 * k, true)
		bx -= (34.0 + 8.0) * k
	_dessiner_reglages(k)

	# --- la ligne de mise au point : SUR DEMANDE SEULEMENT ------------------
	# Elle porte la graine à citer dans un retour de test, et c'est elle qui a
	# permis de mesurer HUD_K sur l'appareil quand tout y paraissait minuscule.
	# Ce travail est fait : elle ne s'affiche plus qu'avec `STATION_MESURE=1`,
	# et l'écran redevient ce que le jeu web a toujours été — 100 % visuel,
	# sans une bande de texte.
	if OS.get_environment("STATION_MESURE") == "":
		return
	draw_string(sans, Vector2(Sty.marges["gauche"] + 18, size_ecran().y - Sty.marges["bas"] - 14),
		"graine %d · journée en %d ms · %s%s"
			% [graine, duree_generation_ms, _niveau_texte(),
				("   ·   " + Sty.mesure) if Sty.mesure != "" else ""],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Sty.MUET, 0.55))


# --- le volet des réglages, sous l'engrenage --------------------------------
## L'ENGRENAGE NE FAISAIT RIEN DE CE QU'IL PROMET. Il rejouait la journée en
## silence — un geste destructeur sans un mot, sous une icône qui annonce un
## réglage. Le prototype, lui, déplie sous l'engrenage un volet de trois
## boutons (`station.html`, #hud-controls) : recommencer, son, aide. On en
## reprend les deux qui ont un sens ici — l'aide du prototype est un long texte
## HTML, et le portage a le tutoriel guidé à sa place.
##
## Deux pastilles empilées sous l'engrenage, au même gabarit que les trois du
## bandeau : rien de neuf à apprendre, et la cible reste celle du doigt.
func _dessiner_reglages(k: float) -> void:
	if not reglages_ouverts:
		return
	var g: Rect2 = zones_hud.get("gear", Rect2())
	if g == Rect2():
		return
	var y := g.end.y + 8.0 * k
	for nom in ["son", "recommencer"]:
		var r := Rect2(g.position.x, y, g.size.x, g.size.y)
		zones_hud[nom] = r
		var c := r.get_center()
		if nom == "son":
			var coupe := Sauvegarde.get_muet()
			_chip(r, Sty.POSTE_BORD, k)
			var teinte: Color = Sty.MUET if coupe else Sty.TEXTE
			# le haut-parleur : une caisse et son pavillon
			draw_rect(Rect2(c.x - 8.0 * k, c.y - 3.0 * k, 4.0 * k, 6.0 * k), teinte, true)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-4, -3) * k, c + Vector2(1, -8) * k,
				c + Vector2(1, 8) * k, c + Vector2(-4, 3) * k]), teinte)
			if coupe:
				# la croix : le son est coupé
				draw_line(c + Vector2(4, -4) * k, c + Vector2(10, 4) * k, teinte, 1.8 * k, true)
				draw_line(c + Vector2(10, -4) * k, c + Vector2(4, 4) * k, teinte, 1.8 * k, true)
			else:
				# deux ondes, comme l'icône du prototype
				draw_arc(c + Vector2(1, 0) * k, 6.0 * k, -PI / 3.0, PI / 3.0, 12, teinte, 1.6 * k, true)
				draw_arc(c + Vector2(1, 0) * k, 9.5 * k, -PI / 3.0, PI / 3.0, 16, teinte, 1.6 * k, true)
		else:
			_chip(r, Sty.POSTE_BORD, k)
			# la flèche circulaire : un arc ouvert et sa pointe
			draw_arc(c, 7.0 * k, -PI * 0.62, PI * 1.10, 28, Sty.TEXTE, 1.8 * k, true)
			var p := c + Vector2(cos(-PI * 0.62), sin(-PI * 0.62)) * 7.0 * k
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-3.6, -1.2) * k, p + Vector2(3.6, -1.6) * k, p + Vector2(0.4, 4.2) * k]),
				Sty.TEXTE)
		y = r.end.y + 8.0 * k


# --- le repère du tutoriel --------------------------------------------------
## Le PROJECTEUR : tout l'écran s'assombrit sauf la cible (#coach-ring, dont
## l'ombre de 9999 px fait exactement cela sur le web). Sans lui, le repère
## désigne sans isoler, et l'œil continue de partir ailleurs.
func _dessiner_coach(t: float) -> void:
	if coach_cible.is_empty():
		return
	var rc := _rect_cible()
	if rc == Rect2():
		return
	var trou := rc.grow(8)
	var e := size_ecran()
	draw_rect(Rect2(0, 0, e.x, trou.position.y), Sty.VOILE, true)
	draw_rect(Rect2(0, trou.end.y, e.x, e.y - trou.end.y), Sty.VOILE, true)
	draw_rect(Rect2(0, trou.position.y, trou.position.x, trou.size.y), Sty.VOILE, true)
	draw_rect(Rect2(trou.end.x, trou.position.y, e.x - trou.end.x, trou.size.y), Sty.VOILE, true)
	var pulse := 0.5 + 0.5 * sin(t * TAU / 1.2)
	var b := _boucle(Sty.rect_arrondi(trou, 12))
	draw_polyline(b, Color(Sty.ACCENT, 0.10 + 0.15 * pulse), 14.0, true)
	draw_polyline(b, Color(Sty.ACCENT, 0.25 + 0.25 * pulse), 7.0, true)
	draw_polyline(b, Sty.ACCENT.lerp(Sty.ACCENT_CLAIR, pulse), 2.5, true)
	# l'ergot de la bulle, pointé vers la cible
	if bulle != null and bulle.visible:
		var br := Rect2(bulle.position, bulle.size)
		var dessous: bool = br.position.y > trou.end.y
		var cx: float = clampf(trou.get_center().x, br.position.x + 14.0, br.end.x - 14.0)
		var y: float = br.position.y if dessous else br.end.y
		var s: float = 1.0 if dessous else -1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 8, y), Vector2(cx + 8, y), Vector2(cx, y - s * 8)]), Sty.ACCENT)


# --- la fin de service, seul à l'écran --------------------------------------
# L'application, elle, lit le relevé sur la carte du ruban.
func _dessiner_fin() -> void:
	if not enc.ended or app != null:
		return
	var e := size_ecran()
	draw_rect(Rect2(Vector2.ZERO, e), Color(Sty.FOND, 0.82), true)
	var r: Dictionary = enc.resultat
	var titre: String = "Service interrompu" if r.get("failed", false) \
		else ("Sans faute !" if r.get("perfect", false) else ("Fin du service" if r.get("win", false) else "Objectif manqué"))
	var etoiles := "★".repeat(int(r.get("stars", 0))) + "☆".repeat(3 - int(r.get("stars", 0)))
	var c := e / 2.0
	Sty.texte_centre(self, Sty.sans(600), 34, c - Vector2(0, 20), titre, Sty.TEXTE)
	Sty.texte_centre(self, Sty.sans(), 18, c + Vector2(0, 20),
		"%s   ·   retard cumulé %d min" % [etoiles, int(r.get("d", 0))], Sty.AMBRE)
	Sty.texte_centre(self, Sty.sans(), 14, c + Vector2(0, 60), "R pour rejouer", Sty.MUET)


# ------------------------------------------------------------------
# Les commandes
# ------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if app != null and app.en_transition():
		return
	# rien ne se touche derrière la question : ses deux boutons sont des
	# Controls, ils reçoivent le doigt avant d'arriver ici
	if confirmation != null and confirmation.visible:
		return
	if enc == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				pause = not pause
			KEY_1:
				vitesse = 1.0
			KEY_2:
				vitesse = 2.0
			KEY_4:
				vitesse = 4.0
			KEY_R:
				graine = (graine * 7 + 13) % 100000
				pause = false
				_nouvelle_journee()
			KEY_ESCAPE:
				if app != null and enc.selected == null:
					_demander_abandon()
				else:
					enc.selected = null
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = event.position
		# LE BANDEAU D'ABORD. Sans clavier — sur un téléphone — la pause, la
		# vitesse et le retour à la carte ne sont atteignables que par ces
		# boutons ; ils étaient dessinés sans être cliquables.
		if _clic_bandeau(m):
			return
		if enc.ended or tuto == "accueil":
			return
		m -= decalage()          # du geste à l'écran au plan de la gare
		# un convoi ?
		for t in enc.trains:
			if not positions.has(t.id):
				continue
			for p in positions[t.id]:
				# la zone de clic grossit avec le doigt (js/render.js, hitH × UIK)
				if Vector2(p["x"], p["y"]).distance_to(m) <= (Geo.CAR_LEN / 2.0 + 10.0) * Sty.UIK:
					var dit := enc.clic_train(t)
					if dit != "":
						print(t.id + " — " + dit)
					if enc.selected == t:
						_tuto_train_touche(t)
					return
		# un quai ?
		for q in G["platforms"]:
			var r := Rect2(Geo.PLAT_X1, float(q["cy"]) - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
			if r.has_point(m):
				var choisi = enc.selected
				var dit := enc.clic_quai(q["id"])
				if dit != "":
					print("quai %d — %s" % [int(q["id"]), dit])
				if choisi != null and choisi.target != null:
					_tuto_quai_choisi()
				return
		enc.selected = null


# ------------------------------------------------------------------
# Le tutoriel — le premier service, guidé avec deux trains
# ------------------------------------------------------------------
# Transposition de l'accueil de js/game.js : un repère visuel (cerne pulsé +
# bulle) dit EXACTEMENT quoi toucher, le service se gèle pendant chaque repère
# et reprend quand le joueur agit. Ne s'affiche qu'une fois (Sauvegarde,
# accueilli). Deux étapes sont opportunistes : le premier feu rouge, et le
# moment où il n'y a plus rien à aiguiller.
func _construire_coach() -> void:
	# #coach-bubble : une feuille de parchemin posée sur le pupitre, liseré de
	# laiton, texte centré. Elle était restée au bleu nuit du prototype ET EN
	# UNITÉS BRUTES : sur un téléphone, où tout le reste du bandeau est multiplié
	# par HUD_K, elle s'affichait à la moitié de sa taille et dans une autre
	# palette que l'écran d'à côté. C'est le même défaut que les cadres du ruban
	# — « les bordures et les arrondis ne sont pas uniformes » — mais sur l'écran
	# que le joueur voit en PREMIER.
	var k := Sty.HUD_K
	bulle = PanelContainer.new()
	var st := Sty.parchemin(Sty.R, k)
	st.set_content_margin_all(14 * k)
	st.content_margin_left = 18 * k
	st.content_margin_right = 18 * k
	bulle.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(12 * k)))
	bulle.add_child(v)
	bulle_texte = Label.new()
	bulle_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bulle_texte.custom_minimum_size = Vector2(364 * k, 0)
	bulle_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bulle_texte.add_theme_font_override("font", Sty.sans())
	bulle_texte.add_theme_font_size_override("font_size", int(round(15 * k)))
	bulle_texte.add_theme_color_override("font_color", Sty.ENCRE)
	bulle_texte.add_theme_constant_override("line_spacing", int(round(6 * k)))
	v.add_child(bulle_texte)
	bulle_bouton = Sty.bouton_plaque("Suivant", false, 14, k, 14.0, 8.0)
	bulle_bouton.pressed.connect(_coach_suivant)
	v.add_child(bulle_bouton)
	bulle.visible = false
	add_child(bulle)

	# L'accueil : un voile sur toute la scène, et la carte au centre. Le voile
	# est un enfant direct — dans un CenterContainer il serait réduit à rien.
	# TAILLES EXPLICITES, PAS D'ANCRES : sous un Node2D, un Control aux ancres
	# pleines n'a aucun parent à remplir, et sa taille retombe à zéro — la
	# carte se centrait alors sur l'origine, hors écran, et le service restait
	# gelé derrière un voile sans bouton. Vu par Vincent au premier lancement,
	# le 3 septembre 2026 ; le lancement direct (STATION_JOUER) le masquait.
	accueil = Control.new()
	var voile := ColorRect.new()
	voile.color = VOILE
	accueil.add_child(voile)
	var centre := CenterContainer.new()
	accueil.add_child(centre)
	# La taille suit l'écran réel : le viewport s'étire, et la carte doit rester
	# centrée dessus, pas sur la base de 1400 × 760.
	for n in [accueil, voile, centre]:
		n.size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void:
		for n in [accueil, voile, centre]:
			n.size = get_viewport_rect().size)
	var carte := PanelContainer.new()
	var sc := Sty.parchemin(Sty.R_GRAND, k)
	sc.set_content_margin_all(26 * k)
	carte.add_theme_stylebox_override("panel", sc)
	carte.custom_minimum_size = Vector2(min(520.0 * k, get_viewport_rect().size.x * 0.62), 0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", int(round(10 * k)))
	carte.add_child(cv)
	# .wc-badge, h1, .wc-lead, .wc-tip — les quatre lignes du prototype, au
	# parchemin : le titre en Cinzel comme toutes les enseignes du jeu.
	for ligne in [["Bienvenue", 12, Sty.SARCELLE, false],
			["Le poste d'aiguillage", 24, Sty.ENCRE, true],
			["Vous dirigez la gare : faites entrer et repartir chaque train à l'heure.", 15, Sty.ENCRE, false],
			["Je vous montre, pas à pas, avec deux trains — les repères indiquent quoi toucher. Rien ne presse.", 13, Sty.ENCRE_MUET, false]]:
		var l := Label.new()
		l.text = ligne[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", Sty.titre(600) if ligne[3] else Sty.sans(400))
		l.add_theme_font_size_override("font_size", int(round(float(ligne[1]) * k)))
		l.add_theme_color_override("font_color", ligne[2])
		l.add_theme_constant_override("line_spacing", int(round(5 * k)))
		cv.add_child(l)
	var b := Sty.bouton_plaque("Commencer", true, 16, k)
	b.pressed.connect(_accueil_ferme)
	cv.add_child(b)
	centre.add_child(carte)
	accueil.visible = false
	add_child(accueil)


## QUITTER UN SERVICE SE DEMANDE. Le cartouche de gare ramenait à la carte d'un
## seul doigt, et le service en cours était perdu sans un mot — les convois,
## l'horaire, le retard. C'est le seul geste destructeur de l'écran ; il méritait
## qu'on s'assure de l'intention.
##
## LE SERVICE SE FIGE PENDANT LA QUESTION, sans quoi le retard courrait pendant
## qu'on hésite — et hésiter coûterait des étoiles. On réutilise le gel du
## tutoriel, et on lui rend son état d'avant : poser la question ne doit pas
## dégeler une partie qui l'était.
##
## LE GESTE SÛR EST LE PLUS EN VUE : « Continuer le service » porte la plaque
## d'appel, « Abandonner » se contente du bois. Un bouton destructeur ne se met
## pas en avant.
func _construire_confirmation() -> void:
	var k := Sty.HUD_K
	confirmation = Control.new()
	var voile := ColorRect.new()
	voile.color = VOILE
	confirmation.add_child(voile)
	var centre := CenterContainer.new()
	confirmation.add_child(centre)
	for n in [confirmation, voile, centre]:
		n.size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void:
		for n in [confirmation, voile, centre]:
			n.size = get_viewport_rect().size)
	var carte := PanelContainer.new()
	var sc := Sty.parchemin(Sty.R_GRAND, k)
	sc.set_content_margin_all(24 * k)
	carte.add_theme_stylebox_override("panel", sc)
	carte.custom_minimum_size = Vector2(min(460.0 * k, get_viewport_rect().size.x * 0.6), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(10 * k)))
	carte.add_child(v)
	for ligne in [[22, true], [15, false]]:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", Sty.titre(600) if ligne[1] else Sty.sans(400))
		l.add_theme_font_size_override("font_size", int(round(float(ligne[0]) * k)))
		l.add_theme_color_override("font_color", Sty.ENCRE)
		l.add_theme_constant_override("line_spacing", int(round(5 * k)))
		v.add_child(l)
		if ligne[1]:
			conf_titre = l
		else:
			conf_corps = l
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(round(8 * k)))
	# « CONTINUER LE SERVICE » NE TENAIT PAS : coupé à « CONTINUER LE SERVIC »
	# par le clip qui protège la rangée. La question au-dessus dit déjà de quoi
	# il s'agit ; le bouton n'a qu'à dire le geste.
	var non := Sty.bouton_plaque("Continuer", true, 15, k, 14.0, 9.0)
	non.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	non.clip_text = true
	non.pressed.connect(_fermer_confirmation.bind(false))
	h.add_child(non)
	conf_oui = Sty.bouton_plaque("Abandonner", false, 15, k, 14.0, 9.0)
	conf_oui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conf_oui.clip_text = true
	conf_oui.pressed.connect(_fermer_confirmation.bind(true))
	h.add_child(conf_oui)
	v.add_child(h)
	centre.add_child(carte)
	confirmation.visible = false
	add_child(confirmation)


func _demander_abandon() -> void:
	_demander("abandon", "Abandonner le service ?",
		"Les convois, l'horaire et le retard seront perdus. La gare pourra être reprise depuis le début.",
		"Abandonner")


## RECOMMENCER SE DEMANDE AUSSI, et pour la même raison — le prototype le
## faisait déjà (station.html, #confirm-reset). Ce n'est pas le même geste que
## l'abandon : on reste dans la gare, mais la journée en cours est jetée et une
## AUTRE est tirée. La question le dit, plutôt que de laisser croire qu'on
## rejoue la même.
func _demander_recommencer() -> void:
	_demander("recommencer", "Recommencer le service ?",
		"Le service en cours sera abandonné. Une nouvelle journée sera tirée : les trains et leurs horaires ne seront pas les mêmes.",
		"Recommencer")


func _demander(quoi: String, titre: String, corps: String, oui: String) -> void:
	if confirmation == null or confirmation.visible:
		return
	conf_quoi = quoi
	conf_titre.text = titre
	conf_corps.text = corps
	conf_oui.text = oui
	gel_avant_confirmation = gel
	gel = true
	confirmation.visible = true


func _fermer_confirmation(accepter: bool) -> void:
	confirmation.visible = false
	gel = gel_avant_confirmation
	if not accepter:
		return
	if conf_quoi == "recommencer":
		# RECOMMENCER PASSE PAR L'APPLICATION, qui sait montrer l'écran
		# d'attente pendant que la journée se tire : c'est le même geste que
		# « Jouer », et il gelait l'écran de la même seconde.
		if app != null:
			app.jouer(String(fiche.get("id", "")))
			return
		graine = (graine * 7 + 13) % 100000
		pause = false
		gel = false
		_nouvelle_journee()
	elif app != null:
		app.abandonner_service()


func _tuto_demarrer() -> void:
	tuto = ""
	coach_cible = {}
	bulle.visible = false
	accueil.visible = false
	gel = false
	if app == null or auto or Sauvegarde.get_accueilli():
		return
	tuto_premier = ""
	tuto_feu_vu = false
	tuto_vitesse_vu = false
	tuto = "accueil"
	gel = true
	accueil.visible = true


func _accueil_ferme() -> void:
	if tuto != "accueil":
		return
	accueil.visible = false
	tuto = "attente1"
	gel = false


func _coach(cible: Dictionary, texte: String, bouton: String = "") -> void:
	coach_cible = cible
	bulle_texte.text = texte
	bulle_bouton.text = bouton if bouton != "" else "Suivant"
	bulle_bouton.visible = bouton != ""
	bulle.visible = true
	# UN CONTROL NE RÉTRÉCIT PAS DE LUI-MÊME : après un long message avec
	# bouton, une phrase courte gardait le cadre de la précédente — « le cadre
	# du message est fort grand », Vincent, 3 septembre 2026.
	bulle.reset_size()
	_placer_bulle()


func _cacher_coach() -> void:
	coach_cible = {}
	bulle.visible = false


## Un quai qui dessert la destination du train ET libre : le bon choix.
func _quai_desservant(t) -> Variant:
	var links: Array = enc.links.get(t.from, [])
	var bons: Array = []
	var avec_chemin: Array = []
	for pid in links:
		if enc.paths.has("out:%s:%d" % [t.to, int(pid)]):
			avec_chemin.append(pid)
			if not enc.platform_reserved(pid) and not enc.platform_closed(pid):
				bons.append(pid)
	if not bons.is_empty():
		return bons[0]
	if not avec_chemin.is_empty():
		return avec_chemin[0]
	return links[0] if not links.is_empty() else null


## Combien de quais s'allument, et combien desservent vraiment la destination.
func _comptes_quais(t) -> Dictionary:
	var lit := 0
	var sert := 0
	for pid in enc.links.get(t.from, []):
		if not enc.platform_claimed(pid) and not enc.platform_closed(pid):
			lit += 1
			if enc.paths.has("out:%s:%d" % [t.to, int(pid)]):
				sert += 1
	return {"lit": lit, "sert": sert}


func _train_pret(exclure: String) -> Variant:
	for o in enc.trains:
		if o.freight or o.target != null or not o.settled or o.id == exclure:
			continue
		if o.state == Enc.S_WAITING or o.state == Enc.S_APPROACHING:
			return o
	return null


func _train(id: String) -> Variant:
	for o in enc.trains:
		if o.id == id:
			return o
	return null


func _tuto_tick() -> void:
	if tuto == "" or enc.ended:
		return
	match tuto:
		"attente1":
			var choisi = null
			for o in enc.trains:
				if o.freight or o.target != null or not o.settled:
					continue
				if o.state != Enc.S_WAITING and o.state != Enc.S_APPROACHING:
					continue
				var n := _comptes_quais(o)
				if n["lit"] > 1 and n["sert"] < n["lit"]:
					choisi = o
					break
				if choisi == null:
					choisi = o
			if choisi == null:
				return
			tuto_premier = choisi.id
			gel = true
			tuto = "touche1"
			_coach({"train": choisi.id}, "Voici un train qui s'annonce. Touchez-le pour le choisir.")
		"quai1":
			var t = _train(tuto_premier)
			if t == null or t.wrong_platform or t.state == Enc.S_DONE or t.state == Enc.S_MOVING_BACK or t.state == Enc.S_MOVING_OUT:
				tuto = "attente2"
				return
			if t.state != Enc.S_DWELL:
				return
			gel = true
			tuto = "aquai"
			_coach({"train": t.id}, "Il est à quai. Les voyageurs montent et descendent : deux minutes au minimum. Et il ne repartira jamais avant son heure de départ, celle du cadran — même prêt, il attend l'heure. Tout cela se fait seul, vous n'avez rien à faire.", "Compris")
		"attente2":
			var t = _train_pret(tuto_premier)
			if t == null:
				return
			gel = true
			tuto = "touche2"
			_coach({"train": t.id}, "Un autre train arrive. Touchez-le à son tour.")
		"libre":
			_tuto_veille()


func _tuto_veille() -> void:
	if not tuto_feu_vu:
		for o in enc.trains:
			if o.holding and o.state == Enc.S_DWELL:
				tuto_feu_vu = true
				gel = true
				tuto = "feu"
				_coach({"train": o.id}, "Feu rouge : ce train est prêt, mais sa voie de sortie est occupée. Il repartira seul dès qu'elle se libère — vous n'avez rien à faire, et le retard court pendant ce temps.", "Compris")
				return
	if not tuto_vitesse_vu and not enc.trains.is_empty():
		var occupe := false
		for o in enc.trains:
			if not o.freight and (o.state == Enc.S_WAITING or o.state == Enc.S_APPROACHING or o.state == Enc.S_MOVING_IN):
				occupe = true
				break
		if not occupe:
			tuto_vitesse_vu = true
			gel = true
			tuto = "vitesse"
			_coach({"hud": "vitesse"}, "Tous les trains présents sont à quai : plus rien à décider pour l'instant. Accélérez (touches 2 et 4) pour ne pas attendre — vous pourrez ralentir dès qu'un train s'annonce.", "Compris")


func _tuto_train_touche(t) -> void:
	if tuto != "touche1" and tuto != "touche2":
		return
	var premier := tuto == "touche1"
	var pid: Variant = _quai_desservant(t)
	var n := _comptes_quais(t)
	var piege: bool = n["lit"] > 1 and n["sert"] < n["lit"]
	tuto = "choix1" if premier else "choix2"
	var texte: String
	if premier:
		texte = "Plusieurs quais s'allument : le train peut entrer sur chacun. Mais tous ne repartent pas vers sa destination — celui-ci, oui." if piege 			else "Envoyez-le sur ce quai éclairé : il dessert sa destination."
	else:
		texte = "À nouveau plusieurs quais possibles. Celui-ci dessert sa destination." if piege 			else "Envoyez-le sur ce quai éclairé."
	_coach({"quai": pid} if pid != null else {}, texte)


func _tuto_quai_choisi() -> void:
	if tuto == "choix1":
		tuto = "retard"
		_coach({"hud": "retard"}, "Il entre et s'arrête. Ici s'affiche le retard cumulé du service — gardez-le au plus bas.", "Suivant")
	elif tuto == "choix2":
		tuto = "objectif"
		_coach({"hud": "retard"}, "Un quai occupé peut quand même être choisi : le convoi attend dehors, sans pénalité — seule compte l'heure de départ. À vous ! Terminez le service avec moins de 30 min de retard pour décrocher une étoile.", "Continuer")


func _coach_suivant() -> void:
	match tuto:
		"retard":
			tuto = "quai1"
			_cacher_coach()
			gel = false
		"aquai":
			tuto = "attente2"
			_cacher_coach()
			gel = false
		"objectif":
			tuto = "libre"
			_cacher_coach()
			Sauvegarde.set_accueilli(true)
			gel = false
		"feu", "vitesse":
			tuto = "libre"
			_cacher_coach()
			gel = false


## Le rectangle d'écran de la cible du repère, ou Rect2() sans cible visible.
func _rect_cible() -> Rect2:
	# Le projecteur et la bulle se posent à l'ÉCRAN : une cible du monde y
	# arrive décalée comme le reste du plan.
	var d := decalage()
	if coach_cible.has("train"):
		var id: String = coach_cible["train"]
		if not positions.has(id) or positions[id].is_empty():
			return Rect2()
		var tete: Dictionary = positions[id][0]
		return Rect2(Vector2(tete["x"] - Geo.CAR_LEN / 2.0, tete["y"] - Geo.CAR_H * Sty.UIK / 2.0) + d,
			Vector2(Geo.CAR_LEN, Geo.CAR_H * Sty.UIK))
	if coach_cible.has("quai"):
		for q in G["platforms"]:
			if q["id"] == coach_cible["quai"]:
				return Rect2(Vector2(Geo.PLAT_X1, float(q["cy"]) - Geo.PLAT_H / 2.0) + d,
					Vector2(Geo.PLAT_LEN, Geo.PLAT_H))
		return Rect2()
	if coach_cible.has("hud"):
		# les vraies zones du bandeau, telles que le dernier rendu les a posées
		if coach_cible["hud"] == "vitesse":
			return zones_hud.get("speed", Rect2())
		return zones_hud.get("horloge", Rect2())
	return Rect2()


## La bulle se pose sous la cible si elle est haute, au-dessus sinon, et
## reste entièrement à l'écran.
func _placer_bulle() -> void:
	if not bulle.visible:
		return
	var rc := _rect_cible()
	var taille := bulle.get_combined_minimum_size()
	if bulle.size != taille:
		bulle.size = taille
	if rc == Rect2():
		var e0 := size_ecran()
		bulle.position = Vector2(e0.x / 2 - taille.x / 2, e0.y - taille.y - 26)
		return
	var e := size_ecran()
	var dessous: bool = rc.get_center().y < e.y * 0.5
	var x: float = clamp(rc.get_center().x - taille.x / 2, 8.0, e.x - taille.x - 8.0)
	var y: float = rc.end.y + 22 if dessous else rc.position.y - 22 - taille.y
	bulle.position = Vector2(x, y)


## Un geste sur le bandeau. Rend vrai s'il a été pris.
func _clic_bandeau(m: Vector2) -> bool:
	if zones_hud.get("carte", Rect2()).has_point(m):
		if app != null:
			_demander_abandon()
		return true
	if zones_hud.get("play", Rect2()).has_point(m) or zones_hud.get("pause", Rect2()).has_point(m):
		if not gel:
			pause = not pause
		return true
	if zones_hud.get("speed", Rect2()).has_point(m):
		# 1 → 2 → 4 → 1, comme le bouton du prototype
		vitesse = 1.0 if vitesse >= 4.0 else vitesse * 2.0
		return true
	if zones_hud.get("gear", Rect2()).has_point(m):
		reglages_ouverts = not reglages_ouverts
		return true
	if reglages_ouverts:
		if zones_hud.get("son", Rect2()).has_point(m):
			Sauvegarde.set_muet(not Sauvegarde.get_muet())
			# ON REND LE SON AUDIBLE SUR-LE-CHAMP : sans une note, rétablir le
			# son ne se distingue pas de le couper — l'icône change, et rien
			# d'autre. C'est le carillon de départ, le plus court des six.
			if not Sauvegarde.get_muet():
				Sons.jouer("depart")
			return true
		if zones_hud.get("recommencer", Rect2()).has_point(m):
			reglages_ouverts = false
			# Une journée finie n'a rien à abandonner : on la rejoue tout de
			# suite, comme « Rejouer » sur le relevé du prototype.
			if enc.ended:
				graine = (graine * 7 + 13) % 100000
				pause = false
				_nouvelle_journee()
			else:
				_demander_recommencer()
			return true
		# UN CLIC AILLEURS REFERME LE VOLET, et ne fait que cela : sur un
		# téléphone, le geste qui range un menu ne doit pas aussi aiguiller un
		# convoi resté sous le doigt.
		reglages_ouverts = false
		return true
	return false


## Le joueur scripté de l'oracle, pour une démonstration sans personne devant.
func _joueur_scripte() -> void:
	for t in enc.trains:
		if t.freight or t.target != null:
			continue
		if t.state != Enc.S_WAITING and t.state != Enc.S_APPROACHING:
			continue
		var lf: Array = enc.links.get(t.from, [])
		var cands: Array = []
		for pid in lf:
			if enc.paths.has("out:%s:%d" % [t.to, int(pid)]) \
					and not enc.platform_claimed(pid) and not enc.platform_closed(pid):
				cands.append(pid)
		if cands.is_empty():
			for pid in lf:
				if not enc.platform_claimed(pid) and not enc.platform_closed(pid):
					cands.append(pid)
		if cands.is_empty():
			continue
		var pick: Variant = cands[0]
		for pid in cands:
			if not enc.platform_occupied(pid):
				pick = pid
				break
		enc.clic_train(t)
		enc.clic_quai(pick)
