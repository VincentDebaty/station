extends SceneTree
# ------------------------------------------------------------------
# LE BANC D'ESSAI DE « CHEMINS DE FER » — sans écran, il REFUSE au lieu
# d'avertir.
#
#   godot --headless --path prototypes/chemins-de-fer-godot --script res://banc.gd
#
# LES DONNÉES :
#   D2  la locomotive fait 40 km/h : 90 s par case d'1 km
#   D1  niveau.json se lit, la ville est au bord et inconnue au départ,
#       chaque ressource de l'anneau a une source et un wagon connus
# LES VOIES :
#   V1  le tout droit et le virage de 45° passent ; 90° et 135° sont refusés
#   V2  une case coûte 2 bois + 1 fer, et « annuler » les rend
#   V3  une voie vers une case inconnue est refusée
#   V4  le dépôt et la ville n'ont pas de limite de virage
# L'EXPLORATION :
#   E1  50 or par case, seulement au voisinage du connu
# LE TRAIN :
#   T1  sans charbon pour la boucle, le train attend à quai
#   T2  il ne part jamais sans le charbon de toute sa boucle
#   T3  le demi-tour n'existe qu'aux arrêts : un chemin qui en exigerait
#       un en pleine voie est refusé
#   T4  le charbon se conserve : dépôt + wagons + mines + brûlé =
#       départ + produit, à 1e-6
#   T5  le dépôt plein (100) n'accepte rien de plus, le train attend
#   T6  la livraison d'eau à la ville paie 5 or par unité
#   T7  la première boucle dure 400 s (4 cases à 90 s, 40 s de chargement)
# LES SCÉNARIOS :
#   S1  la première heure du papier : charbon, puis eau, tient dans la mise
# ------------------------------------------------------------------

const Moteur = preload("res://moteur.gd")

var echecs: Array[String] = []

func refuse(code: String, texte: String) -> void:
	echecs.append("%s  %s" % [code, texte])
	print("  ECHEC ", code, " ", texte)

func verifie(ok: bool, code: String, texte: String) -> void:
	if ok:
		print("  ok    ", code, " ", texte)
	else:
		refuse(code, texte)

func niveau() -> Dictionary:
	var f := FileAccess.open("res://niveau.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func neuf() -> Moteur:
	return Moteur.new(niveau())

func ligne(m: Moteur, cases: Array) -> String:
	for i in cases.size() - 1:
		var r := m.poser(cases[i], cases[i + 1])
		if r != "":
			return r
	return ""

func _init() -> void:
	var N := niveau()
	var m := neuf()
	print("DONNÉES")
	verifie(m.largeur == 17 and m.hauteur == 13 and m.centre == Vector2i(8, 6), "D1", "grille 17×13, dépôt au centre")
	verifie(m.ville.x == m.largeur - 1 and not m.connues.has(m.ville), "D1", "la ville est au bord et inconnue")
	var tout_connu := true
	for k in N["ressources"]:
		if not N["sources"].has(N["ressources"][k]):
			tout_connu = false
		elif not N["wagons"].has(N["sources"][N["ressources"][k]]["wagon"]):
			tout_connu = false
	verifie(tout_connu, "D1", "chaque ressource a une source et un wagon connus")
	verifie(absf(float(N["locomotive"]["secondes_par_case"]) - 3600.0 / 40.0) < 1e-9, "D2", "40 km/h sur des cases d'1 km : 90 s par case")

	print("VOIES")
	m = neuf()
	m.tout_reveler()
	var c := m.centre
	verifie(m.poser(c, c + Vector2i(1, 0)) == "", "V4", "du dépôt vers l'est")
	verifie(m.poser(c + Vector2i(1, 0), c + Vector2i(2, 0)) == "", "V1", "tout droit")
	verifie(m.poser(c + Vector2i(2, 0), c + Vector2i(3, 1)) == "", "V1", "virage de 45°")
	verifie(m.poser(c + Vector2i(3, 1), c + Vector2i(2, 2)) != "", "V1", "virage de 90° refusé")
	verifie(m.poser(c + Vector2i(3, 1), c + Vector2i(2, 1)) != "", "V1", "virage de 135° refusé")
	m = neuf()
	verifie(m.poser(c, c + Vector2i(1, 0)) == "", "V4", "le dépôt n'a pas de limite de virage (sortie)")
	verifie(m.poser(c, c + Vector2i(0, 1)) == "", "V4", "le dépôt accepte une seconde sortie à 90°")
	m = neuf()
	var b0 := m.bois
	var f0 := m.fer
	ligne(m, [c, c + Vector2i(1, 0), c + Vector2i(2, 0)])
	verifie(m.bois == b0 - 4 and m.fer == f0 - 2, "V2", "deux cases coûtent 4 bois et 2 fer")
	m.annuler()
	m.annuler()
	verifie(m.bois == b0 and m.fer == f0, "V2", "annuler rend les matériaux")
	verifie(m.poser(c + Vector2i(2, 0), c + Vector2i(3, 0)) != "", "V3", "voie vers une case inconnue refusée")

	print("EXPLORATION")
	m = neuf()
	verifie(m.explorer(Vector2i(8, 0)) != "", "E1", "pas d'exploration loin du connu")
	var o0 := m.or_
	verifie(m.explorer(Vector2i(11, 6)) == "" and m.or_ == o0 - 50, "E1", "50 or par case voisine du connu")
	m.or_ = 40
	verifie(m.explorer(Vector2i(12, 6)) != "", "E1", "pas assez d'or")

	print("TRAIN")
	m = neuf()
	m.acheter_loco()
	m.acheter_wagon("tombereau")
	m.acheter_wagon("tombereau")
	var mine := Vector2i(6, 5)   # charbon : (-2,-1)
	verifie(ligne(m, [c, Vector2i(7, 5), mine]) == "", "T0", "voie du dépôt à la mine, 2 cases")
	verifie(m.definir_itineraire([mine]) == "", "T0", "itinéraire dépôt, mine, dépôt")
	verifie(m.carburant_boucle() == 4, "T0", "boucle de 4 cases = 4 de charbon (voie de 2 cases)")
	m.charbon = 3
	m.lancer()
	for i in 200:
		m.avancer(0.5)
	verifie(m.train["etat"] == "attend" and m.brule_total == 0, "T1", "3 de charbon pour 4 : le train attend à quai")
	m.charbon = 4
	m.avancer(0.5)
	verifie(m.train["etat"] == "roule", "T2", "avec 4 de charbon il part")
	verifie(m.charbon == 0 and m.brule_total == 4, "T2", "il emporte exactement le charbon de sa boucle")

	m = neuf()
	m.acheter_loco()
	m.acheter_wagon("tombereau")
	m.acheter_wagon("tombereau")
	ligne(m, [c, Vector2i(7, 5), mine])
	m.definir_itineraire([mine])
	m.lancer()
	var t_retour := -1.0
	for i in 4000:
		m.avancer(0.5)
		if m.depose_total > 0:
			t_retour = m.temps
			break
	verifie(t_retour >= 399.9 and t_retour <= 401.0, "T7", "première boucle : 4 cases à 90 s + 40 s de chargement = 400 s (%.1f s)" % t_retour)

	print("DEMI-TOUR")
	m = neuf()
	ligne(m, [c, c + Vector2i(1, 0), c + Vector2i(2, 0)])
	ligne(m, [c + Vector2i(1, 0), c + Vector2i(2, 1)])   # fourche à 45°
	verifie(m.chemin_entre(c + Vector2i(2, 0), c + Vector2i(2, 1)).is_empty(), "T3", "d'une branche à l'autre sans repasser : demi-tour refusé")
	verifie(not m.chemin_entre(c, c + Vector2i(2, 1)).is_empty(), "T3", "du dépôt à l'une des branches : permis")

	print("CONSERVATION")
	m = neuf()
	m.acheter_loco()
	m.acheter_wagon("tombereau")
	m.acheter_wagon("tombereau")
	ligne(m, [c, Vector2i(7, 5), mine])
	m.definir_itineraire([mine])
	m.charbon = 20
	var depart := float(m.charbon) + m.charbon_aux_mines()
	m.lancer()
	for i in 14400:   # 2 heures à 0,5 s
		m.avancer(0.5)
	var somme := float(m.charbon + m.charbon_en_wagons() + m.brule_total) + m.charbon_aux_mines()
	verifie(absf(somme - (depart + m.produit_total_charbon())) < 1e-6, "T4", "dépôt + wagons + mines + brûlé = départ + produit (%.3f / %.3f)" % [somme, depart + m.produit_total_charbon()])
	verifie(m.charbon >= 0 and m.charbon <= 100, "T5", "le stock du dépôt reste entre 0 et 100 (%d)" % m.charbon)
	verifie(m.charbon == 100, "T5", "après 2 h le dépôt est plein (100)")
	verifie(m.train["etat"] == "attend", "T5", "le train attend au lieu de brûler du charbon pour rien (%s)" % m.train["etat"])

	print("EAU")
	m = neuf()
	m.tout_reveler()
	m.acheter_loco()
	m.acheter_wagon("citerne")
	var lac := Vector2i(10, 7)   # lac : (2,1)
	var rangee: Array = [Vector2i(8, 6), Vector2i(9, 6), lac, Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 7), Vector2i(14, 7), Vector2i(15, 6), Vector2i(16, 6)]
	verifie(ligne(m, rangee) == "", "T6", "voie du dépôt à la ville en passant par le lac (8 cases)")
	var r := m.definir_itineraire([lac, m.ville])
	verifie(r == "", "T6", "itinéraire lac, ville : %s" % r)
	m.charbon = 100
	m.lancer()
	for i in 4000:
		m.avancer(0.5)
	verifie(m.depose_total >= 20 and (m.or_ - (1000 - 400 - 100)) == m.depose_total * 5, "T6", "eau livrée à 5 or l'unité (%d unités, +%d or)" % [m.depose_total, m.or_ - 500])

	print("SCÉNARIO")
	m = neuf()
	var dep := m.or_
	m.acheter_loco()
	m.acheter_wagon("tombereau")
	m.acheter_wagon("tombereau")
	verifie(m.or_ == dep - 600, "S1", "locomotive + 2 wagons = 600 or")
	ligne(m, [c, Vector2i(7, 5), mine])
	verifie(m.bois == 60 - 4 and m.fer == 30 - 2, "S1", "la voie du charbon coûte 4 bois et 2 fer")
	verifie(m.or_ >= 250 + 100 + 50, "S1", "il reste de quoi explorer, une citerne et un feu (%d or)" % m.or_)

	print("")
	if echecs.is_empty():
		print("BANC : tout est vert.")
		quit(0)
	else:
		print("BANC : %d échec(s)." % echecs.size())
		for e in echecs:
			print("  - ", e)
		quit(1)
