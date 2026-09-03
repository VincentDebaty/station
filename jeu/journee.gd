class_name Journee
## LA JOURNÉE D'UNE GARE — tirée au hasard, garantie jouable à zéro retard.
##
## Transposition de js/schedule.js, ligne à ligne : tirage des convois selon la
## fiche, simulation d'un « joueur parfait » avec les mêmes règles que le jeu,
## départ officiel = départ faisable + marge de réaction, puis les imprévus
## (retard, fermeture de quai, fret) intégrés au calibrage.
##
## L'ORACLE A LE DERNIER MOT. tools/oracle-journee.mjs tire la même journée
## des deux côtés — schedule.js et ce fichier — avec la même graine, et
## compare convoi par convoi. Deux choses y sont vitales, et ne se voient pas :
##
##   1. L'ORDRE DES TIRAGES. Cinq points d'appel de Math.random ; un appel de
##      plus ou de moins, même sans effet sur la valeur, désynchronise tout ce
##      qui suit. Chaque `hasard.random()` ici est à la place du sien.
##
##   2. LA STABILITÉ DU TRI. Array.sort de JavaScript est stable ;
##      Array.sort_custom de GDScript ne le garantit pas. Le tri des convois
##      par heure d'arrivée, une fois le fret ajouté, tranche donc les
##      égalités par l'indice d'origine (voir _trier_stable).
##
## Les valeurs numériques d'un JSON arrivent en float : les identifiants de
## quai sont manipulés tels quels (1.0) et ne deviennent « 1 » que dans les
## identifiants de chemin, par int() — même leçon qu'en géométrie.

const Geo := preload("res://jeu/geometrie.gd")
# Le script préchargé sert aussi de TYPE : le class_name « Hasard » n'existe
# pas hors éditeur (cache des classes globales), le chemin, si.
const Has := preload("res://jeu/hasard.gd")

const REACTION_MARGIN := 1.5
const FIRST_ARRIVAL := [0.5, 1.0]
const ARRIVAL_GAP_SCALE := 0.82
const PLAT_TAU := 6.0
const QUEUE_MAX := 3
const QUEUE_MAX_FALLBACK := 4
const RUSH_DEFAULT := "pointe"
# 7 wagons ≈ 2,3× plus lent qu'une rame seule ; le fret roule comme un 3 wagons.
const FREIGHT_SLOWNESS := 1 + (3 - 1) * 0.22

var G: Dictionary          # la géométrie (Geometrie.construire)
var cfg: Dictionary        # la fiche
var GEN: Dictionary        # cfg.gen
var hasard: Has


func _init(geometrie: Dictionary, fiche: Dictionary, h: Has) -> void:
	G = geometrie
	cfg = fiche
	GEN = fiche.get("gen", {})
	hasard = h


# ------------------------------------------------------------------
# Petits accès, aux noms de schedule.js
# ------------------------------------------------------------------

## `s.arrEff ?? s.arr`
static func arr_eff(s: Dictionary) -> float:
	return float(s["arrEff"]) if s.has("arrEff") and s["arrEff"] != null else float(s["arr"])


static func slowness(t: Dictionary) -> float:
	return FREIGHT_SLOWNESS if t.get("freight", false) else 1 + (float(t["cars"]) - 1) * 0.22


static func bell(u: float, c: float, w: float) -> float:
	var x := (u - c) / w
	return exp(-(x * x))


func rush(u: float) -> float:
	var nom := String(GEN.get("rush", RUSH_DEFAULT))
	match nom:
		"plat":
			return 1.0
		"double":
			return 1 + 1.60 * bell(u, 0.24, 0.13) + 1.90 * bell(u, 0.74, 0.14)
		"rafale":
			return 1 + 2.60 * bell(u, 0.78, 0.15)
		_:
			return 1 + 1.80 * bell(u, 0.55, 0.21)   # pointe, le défaut


## Poids d'écart, un par convoi : 1/d, renormalisés pour que leur MOYENNE
## vaille exactement 1.
func rush_weights(n: int) -> Array:
	var w: Array = []
	for i in range(n):
		w.append(1.0 / rush((i + 0.5) / n))
	var somme := 0.0
	for x in w:
		somme += x
	var mean := somme / (n if n else 1)
	var out: Array = []
	for x in w:
		out.append(x / mean)
	return out


func _opts(a: String, b: String) -> Array:
	var out: Array = []
	var lb: Array = G["links"].get(b, [])
	for q in G["links"].get(a, []):
		if lb.has(q):
			out.append(q)
	return out


# ------------------------------------------------------------------
# Simulation headless de la journée : mêmes règles que le jeu
# ------------------------------------------------------------------
func simulate_day(schedule: Array, assign: Array, dt: float, events: Array) -> Array:
	var paths: Dictionary = G["paths"]
	var conflicts: Dictionary = G["conflicts"]
	var closures: Array = []
	for ev in events:
		if ev.get("type") == "closure":
			closures.append(ev)
	var sims: Array = []
	for i in range(schedule.size()):
		var s: Dictionary = schedule[i].duplicate()
		s["plat"] = assign[i]
		s["state"] = "scheduled"
		s["elapsed"] = 0.0
		s["actualArr"] = null
		s["stopP"] = 1.0
		s["entryPath"] = null
		s["exitPath"] = null
		s["depReal"] = null
		s["occStart"] = null
		s["occEnd"] = null
		sims.append(s)
	var active := {}

	var now := 0.0
	var horizon := -INF
	for s in schedule:
		horizon = max(horizon, max(float(s["arr"]), float(s["dep"])))
	horizon += 60
	while now < horizon:
		now += dt
		var held := {}
		for t in sims:
			if t["state"] == "movingIn" or t["state"] == "dwell" or t["state"] == "movingThrough":
				held[t["plat"]] = true
		for t in sims:
			match t["state"]:
				"scheduled":
					if now >= arr_eff(t):
						t["state"] = "waiting"
				"waiting":
					# FIFO sur la voie d'approche : pas de dépassement.
					var derriere := false
					for o in sims:
						if o != t and o["from"] == t["from"] and o["state"] == "waiting" \
								and arr_eff(o) < arr_eff(t):
							derriere = true
							break
					if derriere:
						continue
					if held.has(t["plat"]):
						continue
					var ferme := false
					for c in closures:
						if c["plat"] == t["plat"] and now >= float(c["start"]) and now < float(c["end"]):
							ferme = true
							break
					if ferme:
						continue
					held[t["plat"]] = true
					var pid := "in:%s:%d" % [t["from"], int(t["plat"])]
					if not _free(pid, active, conflicts):
						continue
					if t.get("freight", false):
						var pout := "out:%s:%d" % [t["to"], int(t["plat"])]
						t["depReal"] = now
						if _free(pout, active, conflicts):
							active[pid] = t
							active[pout] = t
							t["entryPath"] = pid
							t["exitPath"] = pout
							t["state"] = "movingThrough"
							t["elapsed"] = 0.0
							t["occStart"] = now
							continue
					active[pid] = t
					t["entryPath"] = pid
					t["stopP"] = 1.0
					t["state"] = "movingIn"
					t["elapsed"] = 0.0
					t["occStart"] = now
				"movingThrough":
					var pin: Dictionary = paths[t["entryPath"]]
					var pout: Dictionary = paths[t["exitPath"]]
					var total_arc: float = pin["len"] + pout["len"]
					var dur_tot: float = Geo.TRAVEL * total_arc / 700 * FREIGHT_SLOWNESS
					t["elapsed"] += dt
					var h: float = total_arc * t["elapsed"] / dur_tot
					var tail: float = (float(t["cars"]) - 1) * Geo.CAR_SPACING
					if h - tail > pin["len"] and active.get(t["entryPath"]) == t:
						active.erase(t["entryPath"])
					if h - tail > total_arc:
						t["state"] = "done"
						active.erase(t["exitPath"])
						t["occEnd"] = now
				"movingIn":
					t["elapsed"] += dt
					if t["elapsed"] >= paths[t["entryPath"]]["dur"] * slowness(t) * t["stopP"]:
						t["state"] = "dwell"
						t["actualArr"] = now
						active.erase(t["entryPath"])
				"dwell":
					# le fret ne stationne pas : il repart dès que sa sortie se libère
					if not t.get("freight", false) \
							and now < max(float(t["dep"]), float(t["actualArr"]) + Geo.MIN_DWELL):
						continue
					var pid := "out:%s:%d" % [t["to"], int(t["plat"])]
					if _free(pid, active, conflicts):
						active[pid] = t
						t["exitPath"] = pid
						t["state"] = "movingOut"
						t["elapsed"] = 0.0
						if not t.get("freight", false):
							t["depReal"] = now
				"movingOut":
					t["elapsed"] += dt
					var path: Dictionary = paths[t["exitPath"]]
					var end_p: float = 1 + ((float(t["cars"]) - 1) * Geo.CAR_SPACING) / path["len"]
					if t["elapsed"] >= path["dur"] * slowness(t) * end_p:
						t["state"] = "done"
						active.erase(t["exitPath"])
						t["occEnd"] = now
		var tous_finis := true
		for t in sims:
			if t["state"] != "done":
				tous_finis = false
				break
		if tous_finis:
			break
	return sims


## L'intervalle d'abscisse qu'un convoi occupe sur un chemin, ou null s'il
## n'y est pas encore (fret en transit, avant la sortie).
func _span(t: Dictionary, path_id: String) -> Variant:
	var paths: Dictionary = G["paths"]
	var tail: float = (float(t["cars"]) - 1) * Geo.CAR_SPACING
	if t["state"] == "movingThrough":
		var pin: Dictionary = paths[t["entryPath"]]
		var pout: Dictionary = paths[t["exitPath"]]
		var total_arc: float = pin["len"] + pout["len"]
		var dur_tot: float = Geo.TRAVEL * total_arc / 700 * FREIGHT_SLOWNESS
		var h: float = total_arc * t["elapsed"] / dur_tot
		if path_id == t["entryPath"]:
			return {"lo": h - tail, "hi": min(h, pin["len"]), "dir": 1}
		if h <= pin["len"]:
			return null
		var head_out: float = pout["len"] - (h - pin["len"])
		return {"lo": head_out, "hi": min(pout["len"], head_out + tail), "dir": -1}
	var on_entry: bool = t["state"] == "movingIn"
	var path: Dictionary = paths[t["entryPath"] if on_entry else t["exitPath"]]
	var dur: float = path["dur"] * slowness(t)
	if on_entry:
		var head_s: float = min(t["elapsed"] / dur, t["stopP"]) * path["len"]
		return {"lo": head_s - tail, "hi": head_s, "dir": 1}
	var head_s2: float = (1 - t["elapsed"] / dur) * path["len"]
	return {"lo": head_s2, "hi": head_s2 + tail, "dir": -1}


func _free(pid: String, active: Dictionary, conflicts: Dictionary) -> bool:
	if active.has(pid):
		return false
	for a in active.keys():
		var zone: Variant = conflicts[a].get(pid)
		if zone == null:
			continue
		var occ: Variant = _span(active[a], a)
		if occ == null:
			return false
		var degage: bool = occ["lo"] > zone["hi"] if occ["dir"] == 1 else occ["hi"] < zone["lo"]
		if not degage:
			return false
	return true


# ------------------------------------------------------------------
# PRESSION SUR UN QUAI — combien de convois l'attendent EN MÊME TEMPS.
# ------------------------------------------------------------------
func platform_pressure(schedule: Array, res: Array) -> int:
	var worst := 0
	for q in G["platforms"]:
		var evs: Array = []
		for i in range(schedule.size()):
			if res[i]["plat"] != q["id"]:
				continue
			var a := arr_eff(schedule[i])
			var b: float = a
			if res[i]["occEnd"] != null:
				b = res[i]["occEnd"]
			elif res[i]["depReal"] != null:
				b = res[i]["depReal"]
			evs.append([a, 1])
			evs.append([b, -1])
		# à instant égal, les fins (-1) passent avant les débuts (+1)
		evs.sort_custom(func(x, y): return x[0] < y[0] if x[0] != y[0] else x[1] < y[1])
		var cur := 0
		for e in evs:
			cur += e[1]
			if cur > worst:
				worst = cur
	return worst


# ------------------------------------------------------------------
# La journée retenue : la première qui passe les filtres, sinon la moins
# encombrée de celles qui tenaient.
# ------------------------------------------------------------------
func generate_schedule() -> Dictionary:
	var best: Variant = null
	var best_q := INF
	var seen := 0
	for attempt in range(24):
		if attempt >= 10 and seen == 0:
			break
		var day := generate_once()
		var sched: Array = day["schedule"]
		var pire_attente := -INF
		for s in sched:
			pire_attente = max(pire_attente, float(s["dep"]) - arr_eff(s))
		if pire_attente > 15:
			continue
		var hints: Array = []
		for s in sched:
			hints.append(s["hint"])
		var res := simulate_day(sched, hints, 0.005, day["events"])
		var tot := 0.0
		var ok := true
		for i in range(sched.size()):
			if sched[i].get("freight", false):
				if res[i]["exitPath"] == null:
					ok = false
					break
				continue
			if res[i]["depReal"] == null:
				ok = false
				break
			tot += max(0.0, float(res[i]["depReal"]) - float(sched[i]["dep"]))
		if not ok or tot > 0.15:
			continue
		seen += 1
		var q := platform_pressure(sched, res)
		if q <= (QUEUE_MAX if attempt < 4 else QUEUE_MAX_FALLBACK):
			return day
		if q < best_q:
			best_q = q
			best = day
	return best if best != null else generate_once()


# ------------------------------------------------------------------
# Tirer une relation en tenant compte des quais déjà sollicités
# ------------------------------------------------------------------
func load_around(t: float, draft: Array) -> Dictionary:
	var load := {}
	for q in G["platforms"]:
		load[q["id"]] = 0.0
	for s in draft:
		var dt: float = abs(arr_eff(s) - t)
		if dt >= 2 * PLAT_TAU:
			continue
		var opts := _opts(s["from"], s["to"])
		if opts.is_empty():
			continue
		var w: float = exp(-dt / PLAT_TAU) / opts.size()
		for q in opts:
			load[q] += w
	return load


func pick_pair_under_pressure(pair_opts: Array, load: Dictionary) -> int:
	var w: Array = []
	var tot := 0.0
	for opts in pair_opts:
		var freest := INF
		for q in opts:
			if load[q] < freest:
				freest = load[q]
		var v: float = 1 / ((1 + freest) * (1 + freest))
		w.append(v)
		tot += v
	var r: float = hasard.random() * tot
	for i in range(w.size()):
		r -= w[i]
		if r <= 0:
			return i
	return w.size() - 1


## Array.sort est stable en JS ; sort_custom ne le garantit pas. On tranche
## les égalités par l'indice d'origine, ce qui revient au même.
static func _trier_stable(draft: Array) -> void:
	var indexe: Array = []
	for i in range(draft.size()):
		indexe.append([draft[i], i])
	indexe.sort_custom(func(x, y):
		var ax: float = float(x[0]["arr"])
		var ay: float = float(y[0]["arr"])
		return ax < ay if ax != ay else x[1] < y[1])
	for i in range(indexe.size()):
		draft[i] = indexe[i][0]


func generate_once() -> Dictionary:
	var platforms: Array = G["platforms"]
	var pairs: Array = G["pairs"]
	var portals: Dictionary = G["portals"]

	# 1) tirage des trains selon la fiche : liaisons, wagons, espacement
	var n_min: float = float(GEN.get("nMin", 0))
	var n_max: float = float(GEN.get("nMax", 0))
	var n := int(n_min + floor(hasard.random() * (n_max - n_min + 1)))
	var draft: Array = []
	var gap_w := rush_weights(n)
	var pair_opts: Array = []
	for pr in pairs:
		pair_opts.append(_opts(pr[0], pr[1]))
	var load := {}
	for q in platforms:
		load[q["id"]] = 0.0
	var arr: float = hasard.rnd(FIRST_ARRIVAL[0], FIRST_ARRIVAL[1])
	var prev_arr := arr
	var cars_choix: Array = GEN.get("cars", [])
	for i in range(n):
		var decay: float = exp(-max(0.0, arr - prev_arr) / PLAT_TAU)
		for q in load.keys():
			load[q] *= decay
		prev_arr = arr
		var k := pick_pair_under_pressure(pair_opts, load)
		var pr: Array = pairs[k]
		var cars: int = max(Geo.MIN_CARS, int(hasard.pick(cars_choix)))
		draft.append({
			"id": "T%02d" % (i + 1),
			"from": pr[0], "to": pr[1], "cars": cars,
			"arr": floor(arr * 2 + 0.5) / 2, "dep": 0,
		})
		var share: float = 1.0 / pair_opts[k].size()
		for q in pair_opts[k]:
			load[q] += share
		arr += hasard.rnd(float(GEN.get("gapMin", 0)), float(GEN.get("gapMax", 0))) \
			* ARRIVAL_GAP_SCALE * gap_w[i]
	var last_arr: float = float(draft[draft.size() - 1]["arr"])

	# 1c) le fret : traverse sans s'arrêter, verrouille entrée + sortie
	var cross: Array = []
	for pr in pairs:
		if portals[pr[0]]["side"] != portals[pr[1]]["side"]:
			cross.append(pr)
	var n_freight: int
	if cross.is_empty():
		n_freight = 0
	elif GEN.has("freightCount") and GEN["freightCount"] != null:
		n_freight = int(GEN["freightCount"])
	else:
		var diff := int(cfg.get("difficulty", 0))
		n_freight = max(1, min(5, diff if diff else 1))
	var cross_opts: Array = []
	for pr in cross:
		cross_opts.append(_opts(pr[0], pr[1]))
	for f in range(n_freight):
		var lo := 6.0
		var hi: float = max(lo + 2, last_arr - 4)
		var a: float = lo + (hi - lo) * f / n_freight
		var b: float = lo + (hi - lo) * (f + 1) / n_freight
		var f_arr: float = floor(hasard.rnd(a, b) + 0.5)
		var pr: Array = cross[pick_pair_under_pressure(cross_opts, load_around(f_arr, draft))]
		var cars: int = 6 + int(floor(hasard.rnd(0, 2)))
		draft.append({
			"id": "F%02d" % (f + 1), "freight": true, "from": pr[0], "to": pr[1],
			"cars": cars, "arr": f_arr, "dep": f_arr,
		})
	if n_freight > 0:
		_trier_stable(draft)

	# 1b) les imprévus : ~20 % de journées calmes, sinon 1 ou 2 événements
	var events: Array = []
	var hit := {}
	var quiet: float = float(GEN["quietRate"]) if GEN.has("quietRate") and GEN["quietRate"] != null else 0.2
	var n_ev: int = 0 if hasard.random() < quiet else int(hasard.pick([1, 1, 2]))
	var want_closures := 0
	for e in range(n_ev):
		var type: String = hasard.pick(["late", "closure"])
		if type == "late":
			var cand: Array = []
			for i in range(draft.size()):
				var s: Dictionary = draft[i]
				if i >= 2 and not hit.has(s["id"]) and not s.get("freight", false):
					cand.append(s)
			if cand.is_empty():
				continue
			var s: Dictionary = hasard.pick(cand)
			hit[s["id"]] = true
			var delay: int = int(hasard.pick([2, 3, 3, 4]))
			s["arrEff"] = float(s["arr"]) + delay
			events.append({"type": type, "trainId": s["id"], "delay": delay, "revealAt": float(s["arr"]) - 1})
		else:
			want_closures += 1

	# 2) affectation gloutonne : le quai qui fait partir au plus tôt, et à
	#    égalité le moins sollicité autour de cette arrivée
	var opts: Array = []
	for s in draft:
		opts.append(_opts(s["from"], s["to"]))
	var assign: Array = []
	for o in opts:
		assign.append(o[0])
	var TIE := 0.5
	for i in range(draft.size()):
		if opts[i].size() == 1:
			assign[i] = opts[i][0]
			continue
		var cands: Array = []
		var best_t := INF
		for q in opts[i]:
			assign[i] = q
			var r := simulate_day(draft, assign, 0.03, events)
			var d: float = float(r[i]["depReal"]) if r[i]["depReal"] != null else INF
			cands.append([q, d])
			if d < best_t:
				best_t = d
		var a_i := arr_eff(draft[i])
		var best_q: Variant = null
		var best_load := INF
		for cd in cands:
			if not (cd[1] <= best_t + TIE):
				continue
			var near := 0
			for j in range(i):
				if assign[j] != cd[0]:
					continue
				if abs(arr_eff(draft[j]) - a_i) < 2 * PLAT_TAU:
					near += 1
			if near < best_load:
				best_load = near
				best_q = cd[0]
		assign[i] = opts[i][0] if best_q == null else best_q

	# 3) départ officiel = départ faisable + marge, puis vérification itérée
	var res := simulate_day(draft, assign, 0.02, events)
	for i in range(draft.size()):
		if not draft[i].get("freight", false):
			# `Math.ceil(null + 1.5)` vaut 2 en JS : null y compte pour 0.
			var dr: float = float(res[i]["depReal"]) if res[i]["depReal"] != null else 0.0
			draft[i]["dep"] = ceil(dr + REACTION_MARGIN)
	for k in range(45):
		res = simulate_day(draft, assign, 0.01, events)
		var bumped := false
		for i in range(draft.size()):
			if draft[i].get("freight", false):
				continue
			var dr: Variant = res[i]["depReal"]
			if dr == null or float(dr) - float(draft[i]["dep"]) > 0.08:
				var base: float = float(dr) if dr != null else float(draft[i]["dep"]) + 1
				draft[i]["dep"] = ceil(base + 0.3)
				bumped = true
		if not bumped:
			break
	for i in range(draft.size()):
		draft[i]["hint"] = assign[i]

	# 4) fermetures : jamais sur un quai occupé
	if want_closures > 0:
		var horizon := -INF
		for s in draft:
			horizon = max(horizon, max(float(s["arr"]), float(s["dep"])))
		horizon += 60
		res = simulate_day(draft, assign, 0.01, events)
		var busy := {}
		for q in platforms:
			busy[q["id"]] = []
		var M := 0.5
		for s in res:
			if s["occStart"] == null:
				continue
			var fin: float = horizon if s["occEnd"] == null else float(s["occEnd"])
			busy[s["plat"]].append([float(s["occStart"]) - M, fin + M])
		var lo := 6.0
		var hi: float = max(10.0, last_arr - 10)
		var placed: Array = []
		for c in range(want_closures):
			var dur: float = floor(hasard.rnd(4, 7) + 0.5)
			var cands: Array = []
			for q in platforms:
				var iv: Array = busy[q["id"]].duplicate()
				for p in placed:
					if p["plat"] == q["id"]:
						iv.append([p["start"], p["end"]])
				iv.sort_custom(func(x, y): return x[0] < y[0])
				var t := lo
				var coupe := false
				for ab in iv:
					if ab[0] > t:
						_add_window(cands, q["id"], t, ab[0], hi, dur)
					t = max(t, ab[1])
					if t > hi:
						coupe = true
						break
				if not coupe and t <= hi:
					_add_window(cands, q["id"], t, hi + dur, hi, dur)
			if cands.is_empty():
				break
			var w: Dictionary = hasard.pick(cands)
			var start: float = floor(hasard.rnd(w["from"], w["sMax"]) + 0.5)
			placed.append({"plat": w["plat"], "start": start, "end": start + dur})
		for p in placed:
			events.append({"type": "closure", "plat": p["plat"], "start": p["start"], "end": p["end"]})
	return {"schedule": draft, "events": events}


static func _add_window(cands: Array, q: Variant, from: float, to: float, hi: float, dur: float) -> void:
	var s_max: float = min(hi, to - dur)
	if s_max >= from:
		cands.append({"plat": q, "from": from, "sMax": s_max})
