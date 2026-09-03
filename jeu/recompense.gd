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
##   Recompense.credits_d_une_carte(def, stations, passees)
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

const CREDIT_PAR_ETOILE := 1
const CREDIT_PAR_DIAMANT := 5
const CREDIT_PAR_CHAPITRE_DOR := 20
const CREDIT_PAR_ZONE := 100
const CREDIT_PAR_CARTE := 500
const SEUIL_OR := 3   # RANGS « or »

## Les vingt-six médailles, dans l'ordre de la plus commune à la plus rare.
## Le prédicat de chacune est dans medaille_tenue() : GDScript n'a pas de
## lambda dans une constante.
const MEDAILLES := [
	{"id": "et25",   "fam": "Accumulation", "nom": "Premières étoiles",  "dit": "25 étoiles"},
	{"id": "et50",   "fam": "Accumulation", "nom": "Bon élève",          "dit": "50 étoiles"},
	{"id": "et100",  "fam": "Accumulation", "nom": "Cent étoiles",       "dit": "100 étoiles"},
	{"id": "etmoit", "fam": "Accumulation", "nom": "Ciel chargé",        "dit": "la moitié du ruban"},
	{"id": "ettout", "fam": "Accumulation", "nom": "Tout le ruban",      "dit": "toutes les étoiles"},
	{"id": "di5",    "fam": "Accumulation", "nom": "Cinq diamants",      "dit": "5 sans-fautes"},
	{"id": "di15",   "fam": "Accumulation", "nom": "Écrin",              "dit": "15 sans-fautes"},
	{"id": "di40",   "fam": "Accumulation", "nom": "Coffre-fort",        "dit": "40 sans-fautes"},
	{"id": "ga10",   "fam": "Accumulation", "nom": "Petit réseau",       "dit": "10 gares"},
	{"id": "ga30",   "fam": "Accumulation", "nom": "Réseau régional",    "dit": "30 gares"},
	{"id": "gatout", "fam": "Accumulation", "nom": "Réseau national",    "dit": "toutes les gares"},
	{"id": "ch1",    "fam": "Maîtrise",     "nom": "Bout en bout",       "dit": "un chapitre fini"},
	{"id": "ch5",    "fam": "Maîtrise",     "nom": "Cinq chapitres",     "dit": "5 chapitres finis"},
	{"id": "chtout", "fam": "Maîtrise",     "nom": "Toile ferrée",       "dit": "tous les chapitres"},
	{"id": "or1",    "fam": "Maîtrise",     "nom": "Voie royale",        "dit": "un chapitre d'or"},
	{"id": "or3",    "fam": "Maîtrise",     "nom": "Trois fois l'or",    "dit": "3 chapitres d'or"},
	{"id": "diam1",  "fam": "Maîtrise",     "nom": "Pas une minute",     "dit": "un chapitre de diamant"},
	{"id": "zo1",    "fam": "Maîtrise",     "nom": "Région traversée",   "dit": "une zone entière"},
	{"id": "av1",    "fam": "Exploration",  "nom": "En route",           "dit": "un chapitre entamé"},
	{"id": "av5",    "fam": "Exploration",  "nom": "Cinq étapes",        "dit": "5 chapitres franchis"},
	{"id": "zo2",    "fam": "Exploration",  "nom": "Passeport",          "dit": "2 zones touchées"},
	{"id": "sa1",    "fam": "Exploration",  "nom": "Par-delà la mer",    "dit": "un saut franchi"},
	{"id": "sf1",    "fam": "Style",        "nom": "Sans faute",         "dit": "un service parfait"},
	{"id": "se3",    "fam": "Style",        "nom": "Trois d'affilée",    "dit": "série de 3"},
	{"id": "se6",    "fam": "Style",        "nom": "Ponctualité suisse", "dit": "série de 6"},
	{"id": "se12",   "fam": "Style",        "nom": "Horloge de gare",    "dit": "série de 12"},
]


## Les grades (js/catalog.js, GRADES) : ils nomment, ils ne paient plus.
const GRADES := [
	{"at": 0,    "nom": "Aiguilleur stagiaire"},
	{"at": 25,   "nom": "Aiguilleur"},
	{"at": 75,   "nom": "Chef de quai"},
	{"at": 150,  "nom": "Chef de gare"},
	{"at": 300,  "nom": "Chef de ligne"},
	{"at": 600,  "nom": "Régulateur"},
	{"at": 1000, "nom": "Inspecteur"},
	{"at": 1600, "nom": "Directeur régional"},
	{"at": 2400, "nom": "Directeur de réseau"},
	{"at": 3500, "nom": "Légende du rail"},
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


# --- Les crédits ----------------------------------------------------------------------
## Ce qu'UNE carte rapporte, sans qu'elle soit la carte courante : sa
## définition et la progression enregistrée pour elle, rien d'autre. Une gare
## PAYÉE reste à zéro : franchie, pas tenue.
static func credits_d_une_carte(def: Dictionary, stations: Dictionary, passees: Array) -> int:
	var etoiles := 0
	var diamants := 0
	for id in stations:
		var p: Variant = stations[id]
		if not (p is Dictionary):
			continue
		etoiles += Rub.etoiles_de(p)
		if est_diamant(p):
			diamants += 1
	var chs: Array = def["chapitres"] if def.get("chapitres") is Array else []
	var or_ := 0
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
			or_ += 1
		if toutes:
			finis += 1
	var zones := 0
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
			zones += 1
	var carte_finie := 1 if (not chs.is_empty() and finis == chs.size()) else 0
	return etoiles * CREDIT_PAR_ETOILE + diamants * CREDIT_PAR_DIAMANT \
		+ or_ * CREDIT_PAR_CHAPITRE_DOR + zones * CREDIT_PAR_ZONE + carte_finie * CREDIT_PAR_CARTE


## Mêmes crans que niveau_de_gare, mais lus dans la table qu'on nous donne.
static func _niveau_dans(stations: Dictionary, id: Variant) -> int:
	var p: Variant = stations.get(id)
	if not (p is Dictionary):
		return 0
	return 4 if est_diamant(p) else Rub.etoiles_de(p)


static func _franchie_dans(stations: Dictionary, passees: Array, id: Variant) -> bool:
	return _niveau_dans(stations, id) >= 1 or passees.has(id)


## La somme sur toutes les cartes jouées. `cartes` : [{id, stations, passees}]
## (la sauvegarde), `defs` : id -> définition de carte. Une carte sans
## définition ne rapporte que ses étoiles et ses diamants.
static func credits_gagnes(cartes: Array, defs: Dictionary) -> int:
	var t := 0
	for c in cartes:
		var def: Variant = defs.get(c.get("id"))
		t += credits_d_une_carte(def if def is Dictionary else {},
			c["stations"] if c.get("stations") is Dictionary else {},
			c["passees"] if c.get("passees") is Array else [])
	return t


## Le prix d'un passage suit la position dans le ruban : 5 + 3 par chapitre.
static func prix_de_passage_dans(def: Dictionary, id: String) -> int:
	var chs: Array = def["chapitres"] if def.get("chapitres") is Array else []
	for i in chs.size():
		var g: Array = chs[i]["gares"] if chs[i].get("gares") is Array else []
		if g.has(id):
			return 5 + i * 3
	return 5


static func prix_de_passage(r: Rub, id: String) -> int:
	var ch := r.chapitre_de_gare(id)
	if not ch.is_empty():
		return 5 + int(ch["rang"]) * 3
	return prix_de_passage_dans(r.carte, id)


## Le prix en crédits d'une carte : sa définition, à défaut son entrée
## d'index. Une carte gratuite vaut zéro.
static func prix_de_carte(def: Dictionary, entree: Dictionary) -> int:
	var p: Variant = def.get("prixCredits")
	if p is int or p is float:
		return int(p)
	p = entree.get("prixCredits")
	if p is int or p is float:
		return int(p)
	return 0


## La dépense sur toutes les cartes : les passages payés dont la gare est
## ENCORE à zéro étoile, plus le prix des cartes acquises en crédits.
## `possedees` : id de carte -> comment ("credits", ou autre chose).
static func credits_depenses(cartes: Array, defs: Dictionary, possedees: Dictionary, index_cartes: Array) -> int:
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


static func solde_credits(gagnes: int, depenses: int) -> int:
	return max(0, gagnes - depenses)
