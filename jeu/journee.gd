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
## LE CHEMIN CHAUD EST SIMULATE_DAY, et il est écrit pour la vitesse SANS
## changer une formule (3 septembre 2026). La première version, fidèle au JS
## dictionnaire pour dictionnaire, tournait 14 fois plus lentement que V8 —
## 23 s pour Bruxelles-Midi. Ce qui coûtait : les dictionnaires à clés texte
## lus des milliers de fois par pas, les identifiants de chemin reformatés à
## chaque pas, la file FIFO qui balayait tous les convois, et le test « tous
## finis » à chaque pas. D'où : des objets `Sim` à champs typés, les chemins
## et quais indexés par entier, les identifiants calculés une fois par convoi,
## la FIFO limitée au portail, un compteur de finis. Chaque expression
## arithmétique est restée la même, dans le même ordre : l'oracle en est juge.
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

# Les états d'un convoi dans la simulation — des entiers, pour que le `match`
# ne compare pas des chaînes des milliers de fois par pas.
const S_SCHEDULED := 0
const S_WAITING := 1
const S_MOVING_IN := 2
const S_DWELL := 3
const S_MOVING_THROUGH := 4
const S_MOVING_OUT := 5
const S_DONE := 6

var G: Dictionary          # la géométrie (Geometrie.construire)
var cfg: Dictionary        # la fiche
var GEN: Dictionary        # cfg.gen
var hasard: Has

# --- la géométrie, indexée par entier pour le chemin chaud -----------------
var _path_index: Dictionary = {}       # "in:YORK:1" -> int
var _path_len: PackedFloat64Array = []
var _path_dur: PackedFloat64Array = []
var _conf_lo: Array = []               # par chemin : Dictionary[int -> lo]
var _conf_hi: Array = []               # par chemin : Dictionary[int -> hi]
var _plat_index: Dictionary = {}       # id de quai (float) -> int
var _n_plats: int = 0

# Compteurs de mesure (jeu/bench_journee.gd) : combien de simulations, de pas,
# d'itérations convoi×pas et de tests de voie libre coûte une journée.
static var n_sim := 0
static var n_ticks := 0
static var n_iter := 0
static var n_free := 0

# Le résultat de _span, écrit dans des champs plutôt qu'alloué à chaque appel.
var _sp_lo: float
var _sp_hi: float
var _sp_dir: int


## Un convoi en cours de simulation. Des champs typés : l'accès à un champ
## d'objet est résolu à la compilation, celui d'un dictionnaire est un hachage
## de chaîne à chaque lecture — et il y en a des millions par journée.
class Sim:
	var idx: int                 # rang dans schedule : l'ORDRE DE PASSAGE du pas
	var from: String
	var to: String
	var cars: float
	var freight: bool
	var ae: float                # arrEff ?? arr
	var dep: float
	var plat: Variant            # l'id de quai tel quel (le float du JSON)
	var plat_i: int
	var pin: int                 # index de "in:from:plat"
	var pout: int                # index de "out:to:plat"
	var tail: float              # (cars - 1) * CAR_SPACING
	var slow: float              # slowness()
	var state: int = S_SCHEDULED
	var elapsed: float = 0.0
	var actual_arr: float = 0.0
	var stop_p: float = 1.0
	var entry_path: int = -1
	var exit_path: int = -1
	var dep_real: float = 0.0
	var has_dep_real: bool = false
	var occ_start: float = 0.0
	var has_occ_start: bool = false
	var occ_end: float = 0.0
	var has_occ_end: bool = false
	# Les seuils d'un mouvement ne dépendent que du chemin et du convoi : on les
	# calcule UNE fois, à la transition, avec la même expression que schedule.js
	# évalue à chaque pas — même double, comparaison identique.
	var seuil_in: float = 0.0
	var seuil_out: float = 0.0
	var pin_len: float = 0.0
	var total_arc: float = 0.0
	var dur_tot: float = 0.0


func _init(geometrie: Dictionary, fiche: Dictionary, h: Has) -> void:
	G = geometrie
	cfg = fiche
	GEN = fiche.get("gen", {})
	hasard = h
	_indexer()


## Les chemins et les quais reçoivent un entier, une fois pour toutes.
func _indexer() -> void:
	var paths: Dictionary = G["paths"]
	var ids: Array = paths.keys()
	for i in range(ids.size()):
		_path_index[ids[i]] = i
	_path_len.resize(ids.size())
	_path_dur.resize(ids.size())
	_conf_lo.resize(ids.size())
	_conf_hi.resize(ids.size())
	var conflicts: Dictionary = G["conflicts"]
	for i in range(ids.size()):
		var p: Dictionary = paths[ids[i]]
		_path_len[i] = p["len"]
		_path_dur[i] = p["dur"]
		var lo := {}
		var hi := {}
		var zones: Dictionary = conflicts.get(ids[i], {})
		for autre in zones.keys():
			var j: int = _path_index[autre]
			lo[j] = float(zones[autre]["lo"])
			hi[j] = float(zones[autre]["hi"])
		_conf_lo[i] = lo
		_conf_hi[i] = hi
	var platforms: Array = G["platforms"]
	_n_plats = platforms.size()
	for i in range(_n_plats):
		_plat_index[platforms[i]["id"]] = i


# ------------------------------------------------------------------
# Petits accès, aux noms de schedule.js
# ------------------------------------------------------------------

## `s.arrEff ?? s.arr`
static func arr_eff(s: Dictionary) -> float:
	return float(s["arrEff"]) if s.has("arrEff") and s["arrEff"] != null else float(s["arr"])


static func slowness_de(cars: float, freight: bool) -> float:
	return FREIGHT_SLOWNESS if freight else 1 + (cars - 1) * 0.22


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
	# les fermetures, indexées par quai
	var cl_plat: PackedInt32Array = []
	var cl_start: PackedFloat64Array = []
	var cl_end: PackedFloat64Array = []
	for ev in events:
		if ev.get("type") == "closure":
			cl_plat.append(_plat_index[ev["plat"]])
			cl_start.append(float(ev["start"]))
			cl_end.append(float(ev["end"]))
	var n_cl := cl_plat.size()

	var n := schedule.size()
	n_sim += 1
	var sims: Array = []
	var par_portail := {}                 # portail -> Array[Sim], pour la FIFO
	for i in range(n):
		var s: Dictionary = schedule[i]
		var t := Sim.new()
		t.idx = i
		t.from = s["from"]
		t.to = s["to"]
		t.cars = float(s["cars"])
		t.freight = s.get("freight", false)
		t.ae = arr_eff(s)
		t.dep = float(s["dep"])
		t.plat = assign[i]
		t.plat_i = _plat_index[t.plat]
		# Les identifiants de chemin ne dépendent que du convoi et de son quai :
		# calculés ici une fois, plus jamais dans la boucle de temps.
		t.pin = _path_index["in:%s:%d" % [t.from, int(t.plat)]]
		t.pout = _path_index["out:%s:%d" % [t.to, int(t.plat)]]
		t.tail = (t.cars - 1) * Geo.CAR_SPACING
		t.slow = slowness_de(t.cars, t.freight)
		sims.append(t)
		if not par_portail.has(t.from):
			par_portail[t.from] = []
		par_portail[t.from].append(t)
	var active := {}                      # index de chemin -> Sim
	var held: Array = []
	held.resize(_n_plats)

	# ON NE PASSE QUE SUR CEUX QUI PEUVENT AGIR. schedule.js balaie les n
	# convois à chaque pas ; mesuré sur Bruxelles-Midi, 35 millions
	# d'itérations dont l'immense majorité sur des convois pas encore arrivés
	# ou déjà partis. Un convoi programmé n'a d'effet sur personne avant le pas
	# où `now` atteint son arrivée ; un convoi fini n'en a plus jamais. Les
	# `dormants` (triés par arrivée) rejoignent les `vivants` À LEUR RANG
	# d'origine juste avant le pas où ils arrivent, et y basculent en
	# « waiting » à leur tour de passage, comme dans le JS — les convois
	# traités avant eux dans ce pas les voient encore programmés, ceux d'après
	# les voient en attente. Les finis sont retirés après le pas. L'ordre de
	# passage, seule chose qui compte, est donc conservé ; l'oracle en juge.
	var vivants: Array = []
	var dormants: Array = sims.duplicate()
	dormants.sort_custom(func(x, y): return x.ae < y.ae if x.ae != y.ae else x.idx < y.idx)

	var now := 0.0
	var horizon := -INF
	for s in schedule:
		horizon = max(horizon, max(float(s["arr"]), float(s["dep"])))
	horizon += 60
	var finis := 0
	while now < horizon:
		now += dt
		n_ticks += 1
		while not dormants.is_empty() and dormants[0].ae <= now:
			var t: Sim = dormants.pop_front()
			var k := vivants.size()
			while k > 0 and vivants[k - 1].idx > t.idx:
				k -= 1
			vivants.insert(k, t)
		held.fill(false)
		for t in vivants:
			if t.state == S_MOVING_IN or t.state == S_DWELL or t.state == S_MOVING_THROUGH:
				held[t.plat_i] = true
		var fini_ce_pas := false
		for t in vivants:
			n_iter += 1
			match t.state:
				S_SCHEDULED:
					if now >= t.ae:
						t.state = S_WAITING
				S_WAITING:
					# FIFO sur la voie d'approche : pas de dépassement. On ne
					# regarde que les convois du même portail — le résultat est
					# le même, le balayage dix fois plus court.
					var derriere := false
					for o in par_portail[t.from]:
						if o != t and o.state == S_WAITING and o.ae < t.ae:
							derriere = true
							break
					if derriere:
						continue
					if held[t.plat_i]:
						continue
					var ferme := false
					for c in range(n_cl):
						if cl_plat[c] == t.plat_i and now >= cl_start[c] and now < cl_end[c]:
							ferme = true
							break
					if ferme:
						continue
					held[t.plat_i] = true
					if not _free(t.pin, active):
						continue
					if t.freight:
						t.dep_real = now
						t.has_dep_real = true
						if _free(t.pout, active):
							active[t.pin] = t
							active[t.pout] = t
							t.entry_path = t.pin
							t.exit_path = t.pout
							t.pin_len = _path_len[t.pin]
							t.total_arc = t.pin_len + _path_len[t.pout]
							t.dur_tot = Geo.TRAVEL * t.total_arc / 700 * FREIGHT_SLOWNESS
							t.state = S_MOVING_THROUGH
							t.elapsed = 0.0
							t.occ_start = now
							t.has_occ_start = true
							continue
					active[t.pin] = t
					t.entry_path = t.pin
					t.stop_p = 1.0
					t.seuil_in = _path_dur[t.pin] * t.slow * t.stop_p
					t.state = S_MOVING_IN
					t.elapsed = 0.0
					t.occ_start = now
					t.has_occ_start = true
				S_MOVING_THROUGH:
					t.elapsed += dt
					var h: float = t.total_arc * t.elapsed / t.dur_tot
					if h - t.tail > t.pin_len and active.get(t.entry_path) == t:
						active.erase(t.entry_path)
					if h - t.tail > t.total_arc:
						t.state = S_DONE
						finis += 1
						fini_ce_pas = true
						active.erase(t.exit_path)
						t.occ_end = now
						t.has_occ_end = true
				S_MOVING_IN:
					t.elapsed += dt
					if t.elapsed >= t.seuil_in:
						t.state = S_DWELL
						t.actual_arr = now
						active.erase(t.entry_path)
				S_DWELL:
					# le fret ne stationne pas : il repart dès que sa sortie se libère
					if not t.freight and now < max(t.dep, t.actual_arr + Geo.MIN_DWELL):
						continue
					if _free(t.pout, active):
						active[t.pout] = t
						t.exit_path = t.pout
						var end_p: float = 1 + ((t.cars - 1) * Geo.CAR_SPACING) / _path_len[t.pout]
						t.seuil_out = _path_dur[t.pout] * t.slow * end_p
						t.state = S_MOVING_OUT
						t.elapsed = 0.0
						if not t.freight:
							t.dep_real = now
							t.has_dep_real = true
				S_MOVING_OUT:
					t.elapsed += dt
					if t.elapsed >= t.seuil_out:
						t.state = S_DONE
						finis += 1
						fini_ce_pas = true
						active.erase(t.exit_path)
						t.occ_end = now
						t.has_occ_end = true
		if fini_ce_pas:
			var restants: Array = []
			for t in vivants:
				if t.state != S_DONE:
					restants.append(t)
			vivants = restants
		if finis == n:
			break
	return sims


## L'intervalle d'abscisse qu'un convoi occupe sur un chemin, dans _sp_lo /
## _sp_hi / _sp_dir. Rend false s'il n'y est pas encore (fret en transit,
## avant la sortie) — le `null` de schedule.js.
func _span(t: Sim, path: int) -> bool:
	var tail := t.tail
	if t.state == S_MOVING_THROUGH:
		var pin_len: float = _path_len[t.entry_path]
		var pout_len: float = _path_len[t.exit_path]
		var total_arc: float = pin_len + pout_len
		var dur_tot: float = Geo.TRAVEL * total_arc / 700 * FREIGHT_SLOWNESS
		var h: float = total_arc * t.elapsed / dur_tot
		if path == t.entry_path:
			_sp_lo = h - tail
			_sp_hi = min(h, pin_len)
			_sp_dir = 1
			return true
		if h <= pin_len:
			return false
		var head_out: float = pout_len - (h - pin_len)
		_sp_lo = head_out
		_sp_hi = min(pout_len, head_out + tail)
		_sp_dir = -1
		return true
	var on_entry: bool = t.state == S_MOVING_IN
	var p: int = t.entry_path if on_entry else t.exit_path
	var dur: float = _path_dur[p] * t.slow
	var plen: float = _path_len[p]
	if on_entry:
		var head_s: float = min(t.elapsed / dur, t.stop_p) * plen
		_sp_lo = head_s - tail
		_sp_hi = head_s
		_sp_dir = 1
		return true
	var head_s2: float = (1 - t.elapsed / dur) * plen
	_sp_lo = head_s2
	_sp_hi = head_s2 + tail
	_sp_dir = -1
	return true


func _free(pid: int, active: Dictionary) -> bool:
	n_free += 1
	if active.has(pid):
		return false
	for a in active:                      # les clés, sans en copier le tableau
		var lo: Dictionary = _conf_lo[a]
		if not lo.has(pid):
			continue
		if not _span(active[a], a):
			return false
		var degage: bool = _sp_lo > _conf_hi[a][pid] if _sp_dir == 1 else _sp_hi < lo[pid]
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
			var r: Sim = res[i]
			if r.plat != q["id"]:
				continue
			var a := arr_eff(schedule[i])
			var b: float = a
			if r.has_occ_end:
				b = r.occ_end
			elif r.has_dep_real:
				b = r.dep_real
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
			var r: Sim = res[i]
			if sched[i].get("freight", false):
				if r.exit_path == -1:
					ok = false
					break
				continue
			if not r.has_dep_real:
				ok = false
				break
			tot += max(0.0, r.dep_real - float(sched[i]["dep"]))
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
			var r: Sim = simulate_day(draft, assign, 0.03, events)[i]
			var d: float = r.dep_real if r.has_dep_real else INF
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
			var r: Sim = res[i]
			var dr: float = r.dep_real if r.has_dep_real else 0.0
			draft[i]["dep"] = ceil(dr + REACTION_MARGIN)
	for k in range(45):
		res = simulate_day(draft, assign, 0.01, events)
		var bumped := false
		for i in range(draft.size()):
			if draft[i].get("freight", false):
				continue
			var r: Sim = res[i]
			if not r.has_dep_real or r.dep_real - float(draft[i]["dep"]) > 0.08:
				var base: float = r.dep_real if r.has_dep_real else float(draft[i]["dep"]) + 1
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
		for r in res:
			if not r.has_occ_start:
				continue
			var fin: float = r.occ_end if r.has_occ_end else horizon
			busy[r.plat].append([r.occ_start - M, fin + M])
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
