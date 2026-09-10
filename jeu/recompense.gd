extends RefCounted
## LA RÉCOMPENSE — transposition de js/recompense.js (étape 5 du portage).
##
## Presque rien n'est stocké, et c'est la décision structurante du prototype :
## rangs de chapitre, médailles, diamants et crédits se DÉDUISENT de la
## progression, seule la série est écrite. Ici, tout est statique et prend le
## ruban en paramètre : le ruban porte la carte, le catalogue et la
## progression injectée, la récompense ne fait que compter.
##
##   Recompense.niveau_de_gare(r, "namur")          # 0..4
##   Recompense.rang_de_chapitre(r, ch)             # {} ou une entrée de RANGS
##   Recompense.etat_recompenses(r, serie)          # l'instantané
##   Recompense.medailles_de(etat)                  # les ids décrochés
##   Recompense.pieces_d_une_carte(def, fiches, stations, passees, serie)
##
## La série, les cartes enregistrées et les cartes possédées viennent de la
## sauvegarde (étape 6) : ils sont passés en argument, jamais lus ici.

const Rub := preload("res://jeu/ruban.gd")

## Le seuil de la série : trois étoiles.
const SERIE_SEUIL := 3

## Quatre crans, lus sur la couleur du tracé. L'ordre compte.
const RANGS := [
	{"id": "ouverte", "nom": "Chapitre fait",       "seuil": 1, "couleur": "#2dd4bf"},
	{"id": "argent",  "nom": "Chapitre d'argent",   "seuil": 2, "couleur": "#c9d4e6"},
	{"id": "or",      "nom": "Chapitre d'or",       "seuil": 3, "couleur": "#e8b923"},
	{"id": "diamant", "nom": "Chapitre de diamant", "seuil": 4, "couleur": "#7fd4ff"},
]

## LE BARÈME DES PIÈCES (10 septembre 2026, economie-du-jeu.md §3). Le crédit
## est devenu une pièce et l'unité a été multipliée par dix, tous les rapports
## mesurés gardés ; deux revenus s'ajoutent, déduits comme le reste : la
## PRÉCISION (une pièce par minute sous le seuil des trois étoiles, lue dans
## `bestDelay`) et la BOURSE des médailles. Même chiffres que js/recompense.js,
## et tools/oracle-ruban.mjs le vérifie.
## LE DIAMANT RESTE UN TROPHÉE, ET IL REND SES PIÈCES. La pierre qui se
## dépense (lot 2, schéma 8) a vécu quelques heures le 10 septembre 2026 —
## « pas une bonne idée » (Vincent) : un sans-faute vaut 50 pièces, un
## chapitre de diamant 500, et le diamant ne s'échange contre rien.
const PIECES_PAR_ETOILE := 10
const PIECES_PAR_MINUTE := 1
const PIECES_PAR_DIAMANT := 50
const PIECES_PAR_CHAPITRE_DOR := 200
const PIECES_PAR_CHAPITRE_DIAMANT := 500
const PIECES_PAR_ZONE := 1000
const PIECES_PAR_CARTE := 5000
const PASSAGE_BASE := 50
const PASSAGE_PAR_CHAPITRE := 30
const SEUIL_OR := 3        # RANGS « or »
const SEUIL_DIAMANT := 4   # RANGS « diamant »
## Les postes du détail, dans l'ordre où le relevé les dit.
const POSTES := ["etoiles", "avance", "sansFaute", "or", "diamant", "zones", "carte", "medailles"]

## Les vingt-six médailles, dans l'ordre de la plus commune à la plus rare.
## Le prédicat de chacune est dans medaille_tenue() : GDScript n'a pas de
## lambda dans une constante. Chacune porte sa BOURSE en pièces (50 / 150 /
## 500 selon la rareté — economie-du-jeu.md §3) : déduite avec elle.
const MEDAILLES := [
	{"id": "et25",   "fam": "Accumulation", "nom": "Premières étoiles",  "dit": "25 étoiles", "bourse": 50},
	{"id": "et50",   "fam": "Accumulation", "nom": "Bon élève",          "dit": "50 étoiles", "bourse": 50},
	{"id": "et100",  "fam": "Accumulation", "nom": "Cent étoiles",       "dit": "100 étoiles", "bourse": 150},
	{"id": "etmoit", "fam": "Accumulation", "nom": "Ciel chargé",        "dit": "la moitié du ruban", "bourse": 150},
	{"id": "ettout", "fam": "Accumulation", "nom": "Tout le ruban",      "dit": "toutes les étoiles", "bourse": 500},
	{"id": "di5",    "fam": "Accumulation", "nom": "Cinq diamants",      "dit": "5 sans-fautes", "bourse": 50},
	{"id": "di15",   "fam": "Accumulation", "nom": "Écrin",              "dit": "15 sans-fautes", "bourse": 150},
	{"id": "di40",   "fam": "Accumulation", "nom": "Coffre-fort",        "dit": "40 sans-fautes", "bourse": 500},
	{"id": "ga10",   "fam": "Accumulation", "nom": "Petit réseau",       "dit": "10 gares", "bourse": 50},
	{"id": "ga30",   "fam": "Accumulation", "nom": "Réseau régional",    "dit": "30 gares", "bourse": 150},
	{"id": "gatout", "fam": "Accumulation", "nom": "Réseau national",    "dit": "toutes les gares", "bourse": 500},
	{"id": "ch1",    "fam": "Maîtrise",     "nom": "Bout en bout",       "dit": "un chapitre fini", "bourse": 50},
	{"id": "ch5",    "fam": "Maîtrise",     "nom": "Cinq chapitres",     "dit": "5 chapitres finis", "bourse": 150},
	{"id": "chtout", "fam": "Maîtrise",     "nom": "Toile ferrée",       "dit": "tous les chapitres", "bourse": 500},
	{"id": "or1",    "fam": "Maîtrise",     "nom": "Voie royale",        "dit": "un chapitre d'or", "bourse": 150},
	{"id": "or3",    "fam": "Maîtrise",     "nom": "Trois fois l'or",    "dit": "3 chapitres d'or", "bourse": 150},
	{"id": "diam1",  "fam": "Maîtrise",     "nom": "Pas une minute",     "dit": "un chapitre de diamant", "bourse": 500},
	{"id": "zo1",    "fam": "Maîtrise",     "nom": "Région traversée",   "dit": "une zone entière", "bourse": 150},
	{"id": "av1",    "fam": "Exploration",  "nom": "En route",           "dit": "un chapitre entamé", "bourse": 50},
	{"id": "av5",    "fam": "Exploration",  "nom": "Cinq étapes",        "dit": "5 chapitres franchis", "bourse": 150},
	{"id": "zo2",    "fam": "Exploration",  "nom": "Passeport",          "dit": "2 zones touchées", "bourse": 50},
	{"id": "sa1",    "fam": "Exploration",  "nom": "Par-delà la mer",    "dit": "un saut franchi", "bourse": 150},
	{"id": "sf1",    "fam": "Style",        "nom": "Sans faute",         "dit": "un service parfait", "bourse": 50},
	{"id": "se3",    "fam": "Style",        "nom": "Trois d'affilée",    "dit": "série de 3", "bourse": 50},
	{"id": "se6",    "fam": "Style",        "nom": "Ponctualité suisse", "dit": "série de 6", "bourse": 150},
	{"id": "se12",   "fam": "Style",        "nom": "Horloge de gare",    "dit": "série de 12", "bourse": 500},
]


## Les grades (js/catalog.js, GRADES) : ils nomment, ils ne paient plus.
## CINQUANTE CRANS (10 septembre 2026). « On pourrait inventer jusqu'à
## cinquante niveaux, car il y aura de nombreuses cartes à terme » (Vincent).
## Les seuils suivent une courbe presque quadratique — 8, 20, 40, 65… — pour
## que le premier tombe après trois gares et que le dernier, à 7 370 étoiles,
## reste l'horizon d'une dizaine de cartes dorées. L'Europe en or (831 ★)
## mène au dix-septième cran. Rien n'est stocké : changer l'échelle ne coûte
## aucune migration. Même table que js/catalog.js, GRADES.
const GRADES := [
	{"at": 0, "nom": "Apprenti aiguilleur"},
	{"at": 8, "nom": "Aiguilleur stagiaire"},
	{"at": 20, "nom": "Aiguilleur"},
	{"at": 40, "nom": "Aiguilleur confirmé"},
	{"at": 65, "nom": "Aiguilleur principal"},
	{"at": 95, "nom": "Chef de poste"},
	{"at": 130, "nom": "Chef de quai"},
	{"at": 170, "nom": "Chef de quai principal"},
	{"at": 215, "nom": "Sous-chef de gare"},
	{"at": 265, "nom": "Chef de gare"},
	{"at": 320, "nom": "Chef de gare principal"},
	{"at": 380, "nom": "Chef de circulation"},
	{"at": 445, "nom": "Régulateur adjoint"},
	{"at": 515, "nom": "Régulateur"},
	{"at": 590, "nom": "Régulateur principal"},
	{"at": 670, "nom": "Chef de ligne"},
	{"at": 755, "nom": "Chef de secteur"},
	{"at": 845, "nom": "Chef de district"},
	{"at": 940, "nom": "Inspecteur adjoint"},
	{"at": 1040, "nom": "Inspecteur"},
	{"at": 1150, "nom": "Inspecteur principal"},
	{"at": 1265, "nom": "Inspecteur général"},
	{"at": 1385, "nom": "Chef d'arrondissement"},
	{"at": 1510, "nom": "Chef de région"},
	{"at": 1640, "nom": "Directeur adjoint"},
	{"at": 1780, "nom": "Directeur régional"},
	{"at": 1925, "nom": "Directeur de l'exploitation"},
	{"at": 2075, "nom": "Directeur du trafic"},
	{"at": 2230, "nom": "Directeur de réseau"},
	{"at": 2390, "nom": "Directeur général"},
	{"at": 2560, "nom": "Ingénieur en chef"},
	{"at": 2740, "nom": "Inspecteur des chemins de fer"},
	{"at": 2925, "nom": "Commissaire du rail"},
	{"at": 3115, "nom": "Haut-commissaire"},
	{"at": 3310, "nom": "Maître du poste"},
	{"at": 3515, "nom": "Maître des horaires"},
	{"at": 3730, "nom": "Maître des correspondances"},
	{"at": 3950, "nom": "Grand régulateur"},
	{"at": 4180, "nom": "Grand maître du rail"},
	{"at": 4420, "nom": "Conseiller du réseau"},
	{"at": 4670, "nom": "Doyen des aiguilleurs"},
	{"at": 4930, "nom": "Gardien des voies"},
	{"at": 5200, "nom": "Seigneur des gares"},
	{"at": 5480, "nom": "Prince des correspondances"},
	{"at": 5770, "nom": "Roi des horaires"},
	{"at": 6070, "nom": "Empereur du rail"},
	{"at": 6380, "nom": "L'Étoile du Nord"},
	{"at": 6700, "nom": "Le Rheingold"},
	{"at": 7030, "nom": "L'Express d'Orient"},
	{"at": 7370, "nom": "Légende du rail"},
]


## Le total d'étoiles, toutes gares et TOUTES cartes confondues : un fait de
## compte. `tables` : les tables de progression (Sauvegarde.progression_toutes_cartes).
static func etoiles_total(tables: Array) -> int:
	var n := 0
	for t in tables:
		if t is Dictionary:
			for id in t:
				if t[id] is Dictionary:
					n += Rub.etoiles_de(t[id])
	return n


## Le grade courant et la part du chemin vers le suivant (0..1 ; 1 au dernier).
static func grade_de(points: int) -> Dictionary:
	var i := 0
	for k in GRADES.size():
		if points >= int(GRADES[k]["at"]):
			i = k
	var suivant: Dictionary = GRADES[i + 1] if i + 1 < GRADES.size() else {}
	var part := 1.0
	if not suivant.is_empty():
		part = float(points - int(GRADES[i]["at"])) / float(int(suivant["at"]) - int(GRADES[i]["at"]))
	return {"i": i, "nom": GRADES[i]["nom"], "from": GRADES[i]["at"], "next": suivant, "part": part}


## `r.bestDelay === 0` : un sans-faute, et rien d'autre (null, absent : non).
static func est_diamant(r: Dictionary) -> bool:
	var bd: Variant = r.get("bestDelay")
	return (bd is int or bd is float) and float(bd) == 0.0


# --- Les rangs de chapitre ----------------------------------------------------
## 0 si la gare n'est pas tenue, sinon ses étoiles, et 4 pour un sans-faute.
static func niveau_de_gare(r: Rub, id: String) -> int:
	if not r.est_tenue(id):
		return 0
	var p := r.progression_de(id)
	if est_diamant(p):
		return 4
	return Rub.etoiles_de(p)


## Combien de gares sont FAITES (pas payées) dans une composition.
static func gares_faites(r: Rub, composition: Array) -> int:
	var n := 0
	for g in composition:
		if niveau_de_gare(r, g) >= 1:
			n += 1
	return n


## Le rang d'un chapitre, ou {} tant qu'une gare manque : le MINIMUM sur ses
## gares, jamais la moyenne.
static func rang_de_chapitre(r: Rub, ch: Dictionary) -> Dictionary:
	var gares: Array = ch["gares"] if ch.get("gares") is Array else []
	if gares.is_empty():
		return {}
	var bas := 4
	for g in gares:
		bas = min(bas, niveau_de_gare(r, g))
	if bas < 1:
		return {}
	return RANGS[bas - 1]


# --- L'état du joueur, en chiffres ------------------------------------------------
## Un instantané, calculé d'un bloc. `serie` : {n, record} depuis la sauvegarde.
static func etat_recompenses(r: Rub, serie: Dictionary = {}) -> Dictionary:
	var etoiles := 0
	var diamants := 0
	var gares := 0
	# Le CATALOGUE entier, comme le prototype (CATALOG) — pas seulement le
	# ruban : une progression enregistrée hors du ruban compte ses étoiles.
	for id in r.fiches:
		if r.est_tenue(id):
			gares += 1
		var p: Variant = r.stations.get(id)
		if not (p is Dictionary):
			continue
		etoiles += Rub.etoiles_de(p)
		if est_diamant(p):
			diamants += 1
	# Les chapitres, par rang atteint : chaque cran compte les chapitres AU
	# MOINS à ce rang.
	var chapitres := {"ouverte": 0, "argent": 0, "or": 0, "diamant": 0}
	var chapitres_finis := 0
	for ch in r.chapitres:
		if r.chapitre_termine(ch):
			chapitres_finis += 1
		var rg := rang_de_chapitre(r, ch)
		if rg.is_empty():
			continue
		for k in int(rg["seuil"]):          # seuil = rang + 1 : tous les crans jusqu'à lui
			chapitres[RANGS[k]["id"]] += 1
	# Un saut franchi : le chapitre qui le porte est entamé.
	var sauts := 0
	for ch in r.chapitres:
		if ch["saut"] != null and _une_faite(r, ch["gares"]):
			sauts += 1
	# Les zones : touchées, et entièrement traversées.
	var touchees := {}
	var zones_finies := 0
	var zones: Array = r.zones()
	for z in zones:
		var dans := r.chapitres_de_zone(z.get("id"))
		if dans.is_empty():
			continue
		var toutes := true
		for c in dans:
			if _une_faite(r, c["gares"]):
				touchees[z.get("id")] = true
			if not r.chapitre_termine(c):
				toutes = false
		if toutes:
			zones_finies += 1
	var n_gares := 0
	for ch in r.chapitres:
		n_gares += ch["gares"].size()
	return {
		"etoiles": etoiles, "diamants": diamants, "gares": gares,
		"chapitres": chapitres, "chapitresFinis": chapitres_finis, "sauts": sauts,
		"zones": touchees.size(), "zonesFinies": zones_finies,
		"max": {"etoiles": n_gares * 3, "gares": n_gares, "chapitres": r.chapitres.size(), "zones": zones.size()},
		"serie": int(serie.get("n", 0)), "serieRecord": int(serie.get("record", 0)),
	}


static func _une_faite(r: Rub, gares: Array) -> bool:
	for g in gares:
		if niveau_de_gare(r, g) >= 1:
			return true
	return false


# --- Les médailles ------------------------------------------------------------------
## Le prédicat d'une médaille sur un état. Un état partiel (sans `max`, sans
## `chapitres`) ne décroche rien — le prototype avale l'exception, ici on
## lit avec défaut.
static func medaille_tenue(id: String, e: Dictionary) -> bool:
	var mx: Dictionary = e["max"] if e.get("max") is Dictionary else {}
	var ch: Dictionary = e["chapitres"] if e.get("chapitres") is Dictionary else {}
	var etoiles: int = e.get("etoiles", 0)
	match id:
		"et25":   return etoiles >= 25
		"et50":   return etoiles >= 50
		"et100":  return etoiles >= 100
		"etmoit": return not mx.is_empty() and mx.get("etoiles", 0) > 0 and etoiles >= float(mx["etoiles"]) / 2.0
		"ettout": return not mx.is_empty() and mx.get("etoiles", 0) > 0 and etoiles >= mx["etoiles"]
		"di5":    return e.get("diamants", 0) >= 5
		"di15":   return e.get("diamants", 0) >= 15
		"di40":   return e.get("diamants", 0) >= 40
		"ga10":   return e.get("gares", 0) >= 10
		"ga30":   return e.get("gares", 0) >= 30
		"gatout": return not mx.is_empty() and mx.get("gares", 0) > 0 and e.get("gares", 0) >= mx["gares"]
		"ch1":    return ch.get("ouverte", 0) >= 1
		"ch5":    return ch.get("ouverte", 0) >= 5
		"chtout": return not mx.is_empty() and mx.get("chapitres", 0) > 0 and ch.get("ouverte", 0) >= mx["chapitres"]
		"or1":    return ch.get("or", 0) >= 1
		"or3":    return ch.get("or", 0) >= 3
		"diam1":  return ch.get("diamant", 0) >= 1
		"zo1":    return e.get("zonesFinies", 0) >= 1
		"av1":    return e.get("chapitresFinis", 0) >= 1
		"av5":    return e.get("chapitresFinis", 0) >= 5
		"zo2":    return e.get("zones", 0) >= 2
		"sa1":    return e.get("sauts", 0) >= 1
		"sf1":    return e.get("diamants", 0) >= 1
		"se3":    return e.get("serieRecord", 0) >= 3
		"se6":    return e.get("serieRecord", 0) >= 6
		"se12":   return e.get("serieRecord", 0) >= 12
	return false


## Les ids des médailles décrochées dans un état, dans l'ordre de la liste.
static func medailles_de(e: Dictionary) -> Array:
	var out: Array = []
	for m in MEDAILLES:
		if medaille_tenue(m["id"], e):
			out.append(m["id"])
	return out


## Ce qui vient d'être décroché (les médailles, pas leurs ids), dans l'ordre
## de la liste — de la plus commune à la plus rare.
static func medailles_nouvelles(avant: Array, apres: Array) -> Array:
	var out: Array = []
	for m in MEDAILLES:
		if apres.has(m["id"]) and not avant.has(m["id"]):
			out.append(m)
	return out


# --- Les pièces -----------------------------------------------------------------------
## Le barème d'une gare sur CE ruban-là : la règle de seuils_de_service, sans
## passer par la carte courante (seuilsDansRuban côté web).
static func _seuils_dans(r: Rub, id: String, cfg: Dictionary) -> Dictionary:
	if cfg.get("seuils") is Dictionary:
		return Rub.seuils_de_fiche(cfg)
	var d: int = r.difficulte_de_gare(id, cfg)
	if d == 0 and cfg.get("difficulty") != null:
		d = int(cfg["difficulty"])
	return Rub.seuils_de_niveau(d)


## Les minutes d'avance sur le seuil des trois étoiles : 0 sans étoile, sans
## record, ou au-dessus du seuil. Plafond : le seuil lui-même (12 au palier 1).
static func avance_de(r: Dictionary, seuils: Dictionary) -> int:
	var bd: Variant = r.get("bestDelay")
	if not (bd is int or bd is float) or Rub.etoiles_de(r) < 1:
		return 0
	return max(0, int(floor(float(seuils["trois"]) - float(bd))))


## Ce qu'UNE gare rapporte, et ce qu'elle peut rapporter au plus. La
## différence est le manque à gagner : ce que « rejouer Doncaster » rend encore.
static func pieces_de_gare(r: Dictionary, seuils: Dictionary) -> int:
	if r.is_empty():
		return 0
	return Rub.etoiles_de(r) * PIECES_PAR_ETOILE + avance_de(r, seuils) * PIECES_PAR_MINUTE \
		+ (PIECES_PAR_DIAMANT if est_diamant(r) else 0)


static func plafond_de_gare(seuils: Dictionary) -> int:
	return 3 * PIECES_PAR_ETOILE + int(seuils["trois"]) * PIECES_PAR_MINUTE + PIECES_PAR_DIAMANT


static func manque_a_gagner(r: Dictionary, seuils: Dictionary) -> int:
	return plafond_de_gare(seuils) - pieces_de_gare(r, seuils)


## La bourse des médailles tenues dans un état.
static func bourse_des_medailles(e: Dictionary) -> int:
	var b := 0
	for m in MEDAILLES:
		if medaille_tenue(m["id"], e):
			b += int(m.get("bourse", 0))
	return b


static func detail_vide() -> Dictionary:
	var d := {}
	for k in POSTES:
		d[k] = 0
	d["total"] = 0
	return d


## Ce qu'UNE carte rapporte, POSTE PAR POSTE, sans qu'elle soit la carte
## courante : sa définition, le catalogue, la progression enregistrée pour
## elle et sa série, rien d'autre. Un ruban éphémère porte la rampe et le
## barème — la précision dépend de la difficulté jouée, donc de la position.
## Une gare PAYÉE reste à zéro : franchie, pas tenue.
static func detail_pieces_d_une_carte(def: Dictionary, fiches: Dictionary, stations: Dictionary,
		passees: Array, serie: Dictionary) -> Dictionary:
	var d := detail_vide()
	var r := Rub.new(def, fiches)
	r.stations = stations
	r.passees = passees
	for id in stations:
		var p: Variant = stations[id]
		if not (p is Dictionary):
			continue
		d["etoiles"] += Rub.etoiles_de(p) * PIECES_PAR_ETOILE
		if est_diamant(p):
			d["sansFaute"] += PIECES_PAR_DIAMANT
		# la précision ne se lit que sur une gare dont on connaît la fiche
		var cfg: Dictionary = r.fiche_de(String(id))
		if not cfg.is_empty():
			d["avance"] += avance_de(p, _seuils_dans(r, String(id), cfg)) * PIECES_PAR_MINUTE
	var chs: Array = def["chapitres"] if def.get("chapitres") is Array else []
	var finis := 0
	for ch in chs:
		var g: Array = ch["gares"] if ch.get("gares") is Array else []
		if g.is_empty():
			continue
		var bas := 4
		var toutes := true
		for x in g:
			bas = min(bas, _niveau_dans(stations, x))
			if not _franchie_dans(stations, passees, x):
				toutes = false
		if bas >= SEUIL_OR:
			d["or"] += PIECES_PAR_CHAPITRE_DOR
		if bas >= SEUIL_DIAMANT:
			d["diamant"] += PIECES_PAR_CHAPITRE_DIAMANT
		if toutes:
			finis += 1
	var zs: Array = def["zones"] if def.get("zones") is Array else []
	for z in zs:
		var dans := 0
		var toutes := true
		for c in chs:
			if c.get("zone") != z.get("id"):
				continue
			dans += 1
			for x in (c["gares"] if c.get("gares") is Array else []):
				if not _franchie_dans(stations, passees, x):
					toutes = false
		if dans > 0 and toutes:
			d["zones"] += PIECES_PAR_ZONE
	if not chs.is_empty() and finis == chs.size():
		d["carte"] += PIECES_PAR_CARTE
	d["medailles"] = bourse_des_medailles(etat_recompenses(r, serie))
	for k in POSTES:
		d["total"] += d[k]
	return d


static func pieces_d_une_carte(def: Dictionary, fiches: Dictionary, stations: Dictionary,
		passees: Array, serie: Dictionary) -> int:
	return int(detail_pieces_d_une_carte(def, fiches, stations, passees, serie)["total"])


## Mêmes crans que niveau_de_gare, mais lus dans la table qu'on nous donne.
static func _niveau_dans(stations: Dictionary, id: Variant) -> int:
	var p: Variant = stations.get(id)
	if not (p is Dictionary):
		return 0
	return 4 if est_diamant(p) else Rub.etoiles_de(p)


static func _franchie_dans(stations: Dictionary, passees: Array, id: Variant) -> bool:
	return _niveau_dans(stations, id) >= 1 or passees.has(id)


## La somme sur toutes les cartes jouées, poste par poste. `cartes` :
## [{id, stations, passees, serie}] (la sauvegarde), `defs` : id -> définition
## de carte, `fiches` : le catalogue. Une carte sans définition ne rapporte que
## ses étoiles, sa précision et ses diamants.
static func detail_pieces_gagnees(cartes: Array, defs: Dictionary, fiches: Dictionary) -> Dictionary:
	var t := detail_vide()
	for c in cartes:
		var def: Variant = defs.get(c.get("id"))
		var d := detail_pieces_d_une_carte(def if def is Dictionary else {}, fiches,
			c["stations"] if c.get("stations") is Dictionary else {},
			c["passees"] if c.get("passees") is Array else [],
			c["serie"] if c.get("serie") is Dictionary else {})
		for k in t:
			t[k] += d[k]
	return t


static func pieces_gagnees(cartes: Array, defs: Dictionary, fiches: Dictionary) -> int:
	return int(detail_pieces_gagnees(cartes, defs, fiches)["total"])


## Le prix d'un passage suit la position dans le ruban : 50 + 30 par chapitre.
static func prix_de_passage_dans(def: Dictionary, id: String) -> int:
	var chs: Array = def["chapitres"] if def.get("chapitres") is Array else []
	for i in chs.size():
		var g: Array = chs[i]["gares"] if chs[i].get("gares") is Array else []
		if g.has(id):
			return PASSAGE_BASE + i * PASSAGE_PAR_CHAPITRE
	return PASSAGE_BASE


static func prix_de_passage(r: Rub, id: String) -> int:
	var ch := r.chapitre_de_gare(id)
	if not ch.is_empty():
		return PASSAGE_BASE + int(ch["rang"]) * PASSAGE_PAR_CHAPITRE
	return prix_de_passage_dans(r.carte, id)



## Le prix en pièces d'une carte : sa définition (`prix`), à défaut son entrée
## d'index. Une carte gratuite vaut zéro.
static func prix_de_carte(def: Dictionary, entree: Dictionary) -> int:
	var p: Variant = def.get("prix")
	if p is int or p is float:
		return int(p)
	p = entree.get("prix")
	if p is int or p is float:
		return int(p)
	return 0


## La dépense sur toutes les cartes : les passages payés dont la gare est
## ENCORE à zéro étoile, plus le prix des cartes acquises en pièces.
## `possedees` : id de carte -> comment ("credits", ou autre chose).
static func pieces_depensees(cartes: Array, defs: Dictionary, possedees: Dictionary, index_cartes: Array) -> int:
	var d := 0
	for c in cartes:
		var def: Variant = defs.get(c.get("id"))
		var st: Dictionary = c["stations"] if c.get("stations") is Dictionary else {}
		var pa: Array = c["passees"] if c.get("passees") is Array else []
		for g in pa:
			var p: Variant = st.get(g)
			var stars: int = Rub.etoiles_de(p) if p is Dictionary else 0
			if not (stars >= 1):
				d += prix_de_passage_dans(def if def is Dictionary else {}, g)
	for id in possedees:
		if possedees[id] == "credits":
			var def: Variant = defs.get(id)
			var entree := {}
			for e in index_cartes:
				if e.get("id") == id:
					entree = e
					break
			d += prix_de_carte(def if def is Dictionary else {}, entree)
	return d


static func solde_pieces(gagnes: int, depenses: int) -> int:
	return max(0, gagnes - depenses)

