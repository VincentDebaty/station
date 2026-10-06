class_name Moteur
extends RefCounted
# ------------------------------------------------------------------
# LE MOTEUR D'ÉCLUSES — portage fidèle du bloc « moteur » de
# prototypes/prototype-ecluses.html, fonction pour fonction, dans le même
# ordre d'opérations : les deux doivent rendre les mêmes niveaux d'eau au
# millionième. Aucune règle n'est inventée ici. tools/ecluses-oracle.mjs
# fabrique des parties de référence avec le moteur JS, et oracle.gd vérifie
# que celui-ci les rejoue à l'identique.
#
# Un niveau N est le dictionnaire lu dans niveaux.json ; un état e est :
#   niv      niveau d'eau de chaque bassin (hauteurs, unités de la coupe)
#   ouvert   chaque liaison est-elle ouverte (portes, libres)
#   crete    crête courante des liaisons (null pour les portes et libres)
#   bateaux  bassin où se trouve chaque bateau
#   lache, coups, entree, sortie
# Le solveur, lui, reste en JS : il sert au banc, pas au jeu.
# ------------------------------------------------------------------

const EPS := 1e-6

# Math.round de JS arrondit les moitiés vers +∞ ; round() de Godot les
# éloigne de zéro. On reprend la règle de JS pour garder les mêmes chiffres.
static func arrondi(x: float) -> float:
	return floor(x * 1e6 + 0.5) / 1e6

static func _num(d: Dictionary, k: String, defaut := 0.0) -> float:
	return float(d[k]) if d.has(k) and d[k] != null else defaut

static func charger(N: Dictionary) -> Dictionary:
	var e := {
		"niv": [], "ouvert": [], "crete": [], "bateaux": [],
		"lache": N["mode"] != "chantier", "coups": 0, "entree": 0.0, "sortie": 0.0,
	}
	for b in N["bassins"]:
		e["niv"].append(float(b["niveau"]) if b.has("niveau") else float(b["fond"]))
	for l in N["liaisons"]:
		e["ouvert"].append(l["type"] == "libre" or (l["type"] == "porte" and bool(l.get("ouvert", false))))
		e["crete"].append(float(l["crete"]) if l.has("crete") else null)
	for b in N["bateaux"]:
		e["bateaux"].append(int(b["de"]))
	if e["lache"]:
		equilibrer(N, e)
		bouger(N, e)
	return e

static func copie(e: Dictionary) -> Dictionary:
	return {
		"niv": e["niv"].duplicate(), "ouvert": e["ouvert"].duplicate(), "crete": e["crete"].duplicate(),
		"bateaux": e["bateaux"].duplicate(), "lache": e["lache"], "coups": e["coups"],
		"entree": e["entree"], "sortie": e["sortie"],
	}

static func seuil(N: Dictionary, e: Dictionary, i: int) -> float:
	var l: Dictionary = N["liaisons"][i]
	if l["type"] == "libre":
		return maxf(float(N["bassins"][i]["fond"]), float(N["bassins"][i + 1]["fond"]))
	if l["type"] == "porte":
		return float(l["seuil"]) if e["ouvert"][i] else float(l["crete"])
	return float(e["crete"][i])

static func seuil_bateau(N: Dictionary, i: int) -> float:
	var l: Dictionary = N["liaisons"][i]
	if l["type"] == "porte":
		return float(l["seuil"])
	return maxf(float(N["bassins"][i]["fond"]), float(N["bassins"][i + 1]["fond"]))

static func profondeur(N: Dictionary, e: Dictionary, i: int) -> float:
	return e["niv"][i] - float(N["bassins"][i]["fond"])

# --- L'eau -------------------------------------------------------------------
static func paire(N: Dictionary, e: Dictionary, i: int) -> float:
	var a: float = e["niv"][i]
	var c: float = e["niv"][i + 1]
	if absf(a - c) < 1e-12:
		return 0.0
	var h := i if a > c else i + 1
	var l := i + 1 if a > c else i
	var H: Dictionary = N["bassins"][h]
	var L: Dictionary = N["bassins"][l]
	var s := seuil(N, e, i)
	var nh: float = e["niv"][h]
	var nl: float = e["niv"][l]
	var hf := bool(H.get("fixe", false))
	var lf := bool(L.get("fixe", false))
	if nh <= s + 1e-12 or (hf and lf):
		return 0.0
	var vol: float
	if hf:
		vol = (nh - nl) * float(L["largeur"])
	elif lf:
		vol = (nh - maxf(nl, s)) * float(H["largeur"])
	else:
		var m := (float(H["largeur"]) * nh + float(L["largeur"]) * nl) / (float(H["largeur"]) + float(L["largeur"]))
		vol = (nh - maxf(m, s)) * float(H["largeur"])
	return vol if h == i else -vol

static func verser(N: Dictionary, e: Dictionary, i: int, vol: float, flux: Array) -> void:
	if vol == 0.0:
		return
	flux[i] += vol
	var A: Dictionary = N["bassins"][i]
	var C: Dictionary = N["bassins"][i + 1]
	if A.get("fixe", false):
		if vol > 0: e["entree"] += vol
		else: e["sortie"] -= vol
	else:
		e["niv"][i] -= vol / float(A["largeur"])
	if C.get("fixe", false):
		if vol > 0: e["sortie"] += vol
		else: e["entree"] -= vol
	else:
		e["niv"][i + 1] += vol / float(C["largeur"])

static func poser(N: Dictionary, e: Dictionary) -> void:
	var n: int = N["bassins"].size()
	var i := 0
	while i < n:
		var j := i
		while j < n - 1:
			var s := seuil(N, e, j)
			if e["niv"][j] > s + 1e-6 and e["niv"][j + 1] > s + 1e-6 and absf(e["niv"][j] - e["niv"][j + 1]) < 1e-3:
				j += 1
			else:
				break
		if j > i:
			var fixe := -1
			var sv := 0.0
			var sw := 0.0
			for k in range(i, j + 1):
				var b: Dictionary = N["bassins"][k]
				if b.get("fixe", false):
					fixe = k
				else:
					sv += float(b["largeur"]) * e["niv"][k]
					sw += float(b["largeur"])
			var L: float = e["niv"][fixe] if fixe >= 0 else sv / sw
			var d := 0.0
			for k in range(i, j + 1):
				var b: Dictionary = N["bassins"][k]
				if not b.get("fixe", false):
					d += float(b["largeur"]) * (L - e["niv"][k])
					e["niv"][k] = L
			if fixe >= 0:
				if d > 0: e["entree"] += d
				else: e["sortie"] -= d
		i = j + 1

static func equilibrer(N: Dictionary, e: Dictionary) -> Array:
	var n: int = N["liaisons"].size()
	var flux := []
	flux.resize(n)
	flux.fill(0.0)
	for _tour in 20000:
		var v := []
		var mx := 0.0
		for i in n:
			v.append(paire(N, e, i) / 2.0)
			mx = maxf(mx, absf(v[i]))
		if mx < 1e-10:
			break
		if mx < 1e-4:
			for i in n:
				verser(N, e, i, paire(N, e, i), flux)
			poser(N, e)
			continue
		for i in n:
			verser(N, e, i, v[i], flux)
	for i in e["niv"].size():
		e["niv"][i] = arrondi(e["niv"][i])
	for i in n:
		flux[i] = arrondi(flux[i])
	return flux

# --- Les bateaux -----------------------------------------------------------------
static func capacite(N: Dictionary, i: int) -> int:
	var b: Dictionary = N["bassins"][i]
	if b.has("cap") and b["cap"]:
		return int(b["cap"])
	return 1 if b["type"] == "sas" else 3

static func flotte(N: Dictionary, e: Dictionary, k: int, i: int) -> bool:
	return profondeur(N, e, i) >= float(N["bateaux"][k]["tirant"]) - EPS

static func peut_passer(N: Dictionary, e: Dictionary, k: int, p: int, q: int) -> bool:
	var i := mini(p, q)
	var l: Dictionary = N["liaisons"][i]
	if not (l["type"] == "libre" or (l["type"] == "porte" and e["ouvert"][i])):
		return false
	if absf(e["niv"][p] - e["niv"][q]) > EPS:
		return false
	if not flotte(N, e, k, p) or not flotte(N, e, k, q):
		return false
	if e["niv"][q] - seuil_bateau(N, i) < float(N["bateaux"][k]["tirant"]) - EPS:
		return false
	return e["bateaux"].count(q) < capacite(N, q)

# Pourquoi le bateau k n'avance pas d'un bassin vers sa destination : les
# tests de peut_passer(), dans le même ordre. Ne décide de rien, sert à
# l'expliquer au joueur (Vincent, 6 octobre 2026 : « je suis bloqué alors que
# cela semble être le contraire » — porte levée, eaux égales, mais le bief
# d'arrivée n'avait plus assez de fond). Rend {"quoi", "bassin", "niveau"} :
#   arrive      il est arrivé
#   porte       la porte vers le bassin suivant est fermée
#   niveaux     les deux eaux ne sont pas au même niveau
#   fond_ici    il n'a plus assez d'eau sous lui (« bassin » = le sien)
#   fond_la     le bassin suivant n'a pas assez de fond (« bassin »)
#   seuil       pas assez d'eau au-dessus du seuil de la porte
#   plein       le bassin suivant n'a plus de place
#   passe       il peut passer
# « niveau » : le niveau d'eau qu'il faudrait dans « bassin » (cas de fond).
static func raison(N: Dictionary, e: Dictionary, k: int) -> Dictionary:
	var p: int = e["bateaux"][k]
	var vers := int(N["bateaux"][k]["vers"])
	if p == vers: return {"quoi": "arrive", "bassin": p}
	var q := p + signi(vers - p)
	var i := mini(p, q)
	var t := float(N["bateaux"][k]["tirant"])
	var l: Dictionary = N["liaisons"][i]
	if not (l["type"] == "libre" or (l["type"] == "porte" and e["ouvert"][i])):
		return {"quoi": "porte", "bassin": q}
	if absf(e["niv"][p] - e["niv"][q]) > EPS:
		return {"quoi": "niveaux", "bassin": q}
	if not flotte(N, e, k, p):
		return {"quoi": "fond_ici", "bassin": p, "niveau": float(N["bassins"][p]["fond"]) + t}
	if not flotte(N, e, k, q):
		return {"quoi": "fond_la", "bassin": q, "niveau": float(N["bassins"][q]["fond"]) + t}
	if e["niv"][q] - seuil_bateau(N, i) < t - EPS:
		return {"quoi": "seuil", "bassin": q, "niveau": seuil_bateau(N, i) + t}
	if e["bateaux"].count(q) >= capacite(N, q):
		return {"quoi": "plein", "bassin": q}
	return {"quoi": "passe", "bassin": q}

static func bouger(N: Dictionary, e: Dictionary) -> Array:
	var dep := []
	for tour in 60:
		var bouge := false
		for k in N["bateaux"].size():
			var p: int = e["bateaux"][k]
			var vers := int(N["bateaux"][k]["vers"])
			if p == vers:
				continue
			var q := p + signi(vers - p)
			if peut_passer(N, e, k, p, q):
				e["bateaux"][k] = q
				dep.append({"k": k, "de": p, "vers": q, "tour": tour})
				bouge = true
		if not bouge:
			break
	return dep

# --- Les coups -------------------------------------------------------------------
static func actions(N: Dictionary, e: Dictionary) -> Array:
	if not verdict(N, e).is_empty():
		return []
	var A := []
	for i in N["liaisons"].size():
		var l: Dictionary = N["liaisons"][i]
		if l["type"] == "porte" and not l.get("barrage", false) and e["lache"]:
			A.append({"type": "porte", "i": i})
		if l["type"] == "digue" and e["crete"][i] > float(l["min"]) + EPS:
			A.append({"type": "creuser", "i": i})
	if not e["lache"]:
		A.append({"type": "lacher"})
	elif N["bassins"].any(func(b): return b.has("apport") and b["apport"]):
		A.append({"type": "attendre"})
	return A

static func jouer(N: Dictionary, e0: Dictionary, a: Dictionary) -> Dictionary:
	var e := copie(e0)
	e["coups"] += 1
	var ai := int(a.get("i", -1))
	match a["type"]:
		"porte":
			e["ouvert"][ai] = not e["ouvert"][ai]
		"creuser":
			e["crete"][ai] = maxf(float(N["liaisons"][ai]["min"]), arrondi(e["crete"][ai] - 1.0))
		"lacher":
			e["lache"] = true
			for i in N["liaisons"].size():
				if N["liaisons"][i].get("barrage", false):
					e["ouvert"][i] = true
	var flux := []
	flux.resize(N["liaisons"].size())
	flux.fill(0.0)
	var dep := []
	var apport := 0.0
	if e["lache"]:
		if a["type"] != "lacher":
			for i in N["bassins"].size():
				var b: Dictionary = N["bassins"][i]
				if b.has("apport") and b["apport"]:
					e["niv"][i] = arrondi(e["niv"][i] + float(b["apport"]) / float(b["largeur"]))
					e["entree"] += float(b["apport"])
					apport += float(b["apport"])
		flux = equilibrer(N, e)
		dep = bouger(N, e)
	return {"etat": e, "flux": flux, "dep": dep, "apport": apport}

# --- La fin ----------------------------------------------------------------------
# Rend {} tant que la partie continue, sinon {"fin": "gagne" | "perdu" | "rate"}.
static func verdict(N: Dictionary, e: Dictionary) -> Dictionary:
	for i in N["bassins"].size():
		var b: Dictionary = N["bassins"][i]
		if b["type"] == "village" and profondeur(N, e, i) > _num(b, "tolere") + 0.01:
			return {"fin": "perdu", "raison": "village", "i": i}
	if not e["lache"]:
		return {}
	var bateaux := true
	for k in N["bateaux"].size():
		var vers := int(N["bateaux"][k]["vers"])
		if e["bateaux"][k] != vers or not flotte(N, e, k, vers):
			bateaux = false
	var champs := true
	for i in N["bassins"].size():
		var b: Dictionary = N["bassins"][i]
		if b["type"] == "champ" and profondeur(N, e, i) < float(b["cible"]) - EPS:
			champs = false
	if bateaux and champs:
		return {"fin": "gagne"}
	if N["mode"] == "chantier":
		return {"fin": "rate"}
	return {}

# --- L'impasse -----------------------------------------------------------------
# Reste-t-il une solution d'ici ? Le même solveur que la page web (en largeur,
# niveaux d'eau arrondis au centième dans la clé des états vus : l'eau est
# continue, et sans arrondi la fouille ne s'épuiserait jamais). Rend :
#    1  impasse : tout l'atteignable a été fouillé, aucune victoire
#    0  il reste au moins une solution
#   -1  la fouille a touché sa limite sans conclure : on ne dit rien
# Pur (aucun nœud, aucune scène) : se lance dans un fil de travail.
static func cle(e: Dictionary, q: float) -> String:
	var t := PackedStringArray()
	for h in e["niv"]:
		t.append(str(int(floor(h / q + 0.5))) if q > 0.0 else str(h))
	var s := ",".join(t) + "|"
	for o in e["ouvert"]: s += "1" if o else "0"
	s += "|"
	for c in e["crete"]: s += ("" if c == null else str(c)) + ","
	s += "|"
	for b in e["bateaux"]: s += str(b) + ","
	return s + ("|1" if e["lache"] else "|0")

static func impasse(N: Dictionary, depart: Dictionary, limite := 25000, q := 0.01) -> int:
	var v0 := verdict(N, depart)
	if not v0.is_empty(): return 0 if v0["fin"] == "gagne" else 1
	var vus := {cle(depart, q): true}
	var file := [depart]
	while not file.is_empty():
		var suivante := []
		for e in file:
			for a in actions(N, e):
				var r := jouer(N, e, a)
				var v := verdict(N, r["etat"])
				if v.get("fin", "") == "gagne": return 0
				if not v.is_empty(): continue
				var k := cle(r["etat"], q)
				if vus.has(k): continue
				vus[k] = true
				if vus.size() > limite: return -1
				suivante.append(r["etat"])
		file = suivante
	return 1

# Le face-à-face : deux bassins voisins pleins, dont aucun bateau ne peut
# sortir que vers l'autre (ou ne sort plus : il est arrivé). Plus rien n'en
# sortira jamais, quoi qu'on fasse de l'eau. Vrai si TOUS les bateaux pas
# encore arrivés sont pris dans de tels face-à-face : c'est bloqué, sans rien
# fouiller. (Sur le 1-4, deux bateaux qui se croisent dans l'escalier : la
# fouille tournait 5 s et touchait sa limite sans conclure — Vincent voyait
# le panneau d'échec arriver bien après.) Même fonction que figes() de la page.
static func figes(N: Dictionary, e: Dictionary) -> bool:
	var pris := {}
	for p in N["bassins"].size() - 1:
		var A := []
		var B := []
		for k in N["bateaux"].size():
			if e["bateaux"][k] == p: A.append(k)
			if e["bateaux"][k] == p + 1: B.append(k)
		if A.size() < capacite(N, p) or B.size() < capacite(N, p + 1): continue
		if not A.all(func(k): return int(N["bateaux"][k]["vers"]) >= p): continue
		if not B.all(func(k): return int(N["bateaux"][k]["vers"]) <= p + 1): continue
		for k in A + B: pris[k] = true
	var restent := 0
	var pas_arrives := 0
	for k in N["bateaux"].size():
		if e["bateaux"][k] != int(N["bateaux"][k]["vers"]):
			pas_arrives += 1
			if not pris.has(k): restent += 1
	return not pris.is_empty() and restent == 0 and pas_arrives > 0

# Bloqué : plus aucun bateau ne pourra bouger, quoi qu'on fasse — la règle
# d'échec de la tranche (Vincent, 6 octobre 2026 : une partie qui ne peut plus
# être gagnée continue tant qu'un bateau peut encore avancer). Les bateaux
# n'avancent que vers leur destination : il suffit de chercher, en largeur, un
# coup qui en fasse bouger un. Même fonction que bloque() dans la page web,
# vérifiée par l'oracle. Rend 1 (bloqué), 0 (un bateau peut encore avancer, ou
# c'est gagné), -1 (limite atteinte sans conclure).
static func bloque(N: Dictionary, depart: Dictionary, limite := 25000, q := 0.01) -> int:
	var v0 := verdict(N, depart)
	if not v0.is_empty(): return 0 if v0["fin"] == "gagne" else 1
	if figes(N, depart): return 1
	var vus := {cle(depart, q): true}
	var file := [depart]
	while not file.is_empty():
		var suivante := []
		for e in file:
			for a in actions(N, e):
				var r := jouer(N, e, a)
				var v := verdict(N, r["etat"])
				if not r["dep"].is_empty() or v.get("fin", "") == "gagne": return 0
				if not v.is_empty(): continue
				var k := cle(r["etat"], q)
				if vus.has(k): continue
				vus[k] = true
				if vus.size() > limite: return -1
				suivante.append(r["etat"])
		file = suivante
	return 1
