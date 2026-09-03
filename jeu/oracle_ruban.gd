extends SceneTree
## LE CÔTÉ GODOT DE L'ORACLE DU RUBAN — sans scène, sans œil.
##
##   godot --headless --path . --script res://jeu/oracle_ruban.gd -- <dossier_sortie> <scenarios.json>
##
## Charge le catalogue, les brevets et les cartes (jeu/donnees.gd, instancié à
## la main — les autoloads existent bien sous --script, mais on veut un
## chargement dont on lit les erreurs, pas un global), puis pour chaque
## scénario {carte, nom, stations, passees, serie, cartes, possedees} écrit
## <dossier_sortie>/<carte>-<nom>.json — le même relevé que __exporter côté
## prototype. C'est tools/oracle-ruban.mjs qui écrit les scénarios, lance,
## puis compare.

const Don := preload("res://jeu/donnees.gd")
const Rub := preload("res://jeu/ruban.gd")
const Rec := preload("res://jeu/recompense.gd")
const Json := preload("res://jeu/json_exact.gd")

const RETARDS := [0, 1, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 15, 19, 19.5, 20, 20.5, 25, 29, 29.5, 30, 30.5, 31, 60]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage : --script res://jeu/oracle_ruban.gd -- <dossier_sortie> <scenarios.json>")
		quit(2)
		return
	var dossier: String = args[0]
	var f := FileAccess.open(args[1], FileAccess.READ)
	if f == null:
		printerr("scénarios illisibles : " + args[1])
		quit(2)
		return
	var scenarios: Variant = JSON.parse_string(f.get_as_text())
	if not (scenarios is Array):
		printerr("scénarios invalides")
		quit(2)
		return
	var don := Don.new()
	don.charger()
	if not don.erreurs.is_empty():
		don.free()
		quit(1)
		return
	var rate := 0
	for sc in scenarios:
		if not _traiter(sc, don, dossier):
			rate += 1
	don.free()
	quit(1 if rate > 0 else 0)


func _traiter(sc: Dictionary, don: Node, dossier: String) -> bool:
	var carte: Variant = don.cartes.get(sc["carte"])
	if not (carte is Dictionary):
		printerr("carte inconnue : " + str(sc["carte"]))
		return false
	var r = Rub.new(carte, don.fiches)
	r.stations = sc["stations"]
	r.passees = sc["passees"]
	var vierge = Rub.new(carte, don.fiches)
	var out := _exporter(r, vierge, don, sc)
	var sortie := dossier.path_join("%s-%s.json" % [sc["carte"], sc["nom"]])
	var fo := FileAccess.open(sortie, FileAccess.WRITE)
	if fo == null:
		printerr("sortie impossible : " + sortie)
		return false
	fo.store_string(Json.ecrire(out))
	fo.close()
	return true


static func _ou_null(s: String) -> Variant:
	return s if s != "" else null


func _exporter(r, vierge, don: Node, sc: Dictionary) -> Dictionary:
	var out := {"chapitres": [], "gares": [], "zones": {}}
	for ch in r.chapitres:
		var rg: Dictionary = Rec.rang_de_chapitre(r, ch)
		out["chapitres"].append({
			"id": ch["id"], "rang": ch["rang"], "plancher": Rub.plancher_de_chapitre(ch),
			"arrivee": r.arrivee_de_chapitre(ch), "termine": r.chapitre_termine(ch),
			"rangId": rg["id"] if not rg.is_empty() else null,
			"debut": ch["debut"], "fin": ch["fin"], "saut": ch["saut"] != null,
		})
	for i in r.ordre.size():
		var id: String = r.ordre[i]
		var cfg: Dictionary = r.fiche_de(id)
		var ch: Dictionary = r.chapitre_de_gare(id)
		var d: int = r.difficulte_de_gare(id, cfg)
		var s: Dictionary = r.fiche_de_service(cfg)
		var e := {
			"id": id, "index": i, "chapitre": ch["id"] if not ch.is_empty() else null,
			"rangDansChapitre": r.rang_dans_chapitre(id),
			"difficulte": d, "plafond": Rub.plafond_de_flux(cfg), "seuils": r.seuils_de_service(cfg),
			"service": {"difficulty": s["difficulty"], "gen": s["gen"]} if not s.is_empty() else null,
			"enveloppe": r.enveloppe_de_gare(id, cfg),
			"grande": r.est_grande_gare(id), "boss": r.est_boss(id, cfg), "ecrite": r.est_ecrite(id),
			"faite": r.est_faite(id), "passee": r.est_passee(id), "franchie": r.est_franchie(id),
			"tenue": r.est_tenue(id), "niveau": Rec.niveau_de_gare(r, id), "prix": Rec.prix_de_passage(r, id),
			"r10": null,
		}
		var b: Variant = don.brevets.get(id)
		if not cfg.is_empty() and b is Dictionary:
			if e["boss"]:
				e["r10"] = "ok" if b.get("boss") == "OK" else "boss-ko"
			else:
				e["r10"] = "depasse" if d > int(b.get("niveau", 0) if b.get("niveau") != null else 0) else "ok"
		out["gares"].append(e)
	out["position"] = r.position_courante()
	out["premiereAVenir"] = r.premiere_a_venir()
	out["gareCourante"] = _ou_null(r.gare_courante())
	out["auBout"] = r.au_bout_de_l_ecrit()
	var cc: Dictionary = r.chapitre_courant()
	out["chapitreCourant"] = cc["id"] if not cc.is_empty() else null
	for z in r.zones():
		out["zones"][z["id"]] = r.etat_de_zone(z["id"])
	var etat: Dictionary = Rec.etat_recompenses(r, sc["serie"])
	out["etat"] = etat
	out["medailles"] = Rec.medailles_de(etat)
	var avant: Array = Rec.medailles_de(Rec.etat_recompenses(vierge, {"n": 0, "record": 0}))
	var nouvelles: Array = []
	for m in Rec.medailles_nouvelles(avant, out["medailles"]):
		nouvelles.append(m["id"])
	out["nouvelles"] = nouvelles
	var gagnes: int = Rec.credits_gagnes(sc["cartes"], don.cartes)
	var depenses: int = Rec.credits_depenses(sc["cartes"], don.cartes, sc["possedees"], don.cartes_index)
	out["credits"] = {"gagnes": gagnes, "depenses": depenses, "solde": Rec.solde_credits(gagnes, depenses)}
	var grille: Array = []
	for n in range(1, 6):
		for ret in RETARDS:
			grille.append([n, ret, Rub.etoiles_pour(float(ret), Rub.seuils_de_niveau(n))])
	out["etoilesPour"] = grille
	var envs: Array = []
	var c0: Dictionary = {}
	for g in r.ordre:
		if r.est_ecrite(g):
			c0 = r.fiche_de(g)
			break
	for n in range(0, 6):
		for p in Rub.PROFILS:
			envs.append(Rub.enveloppe_de(c0, n, p))
	out["enveloppes"] = envs
	return out
