class_name Enclenchement
## L'ENCLENCHEMENT — le jeu lui-même, sans son rendu.
##
## Transposition de la partie RÈGLE de js/game.js : la machine à états d'un
## convoi (programmé → en approche → en attente → entrée → à quai → sortie, ou
## refoulement, ou transit de fret), la file d'approche et son FIFO, les
## itinéraires et leurs zones de conflit, les quatre prédicats de quai, le
## fret qui s'aiguille seul, les imprévus révélés en cours de partie, le
## retard vivant, et la fin de service. Tout ce qui est écran — nœuds SVG,
## badges, pilules, sons, chronologie, tutoriel — est resté dans le prototype.
##
## L'ORACLE A LE DERNIER MOT. tools/oracle-enclenchement.mjs fait jouer la
## même journée, au même pas, par le même joueur scripté, à game.js (dans Node,
## derrière un DOM inerte) et à ce fichier, et compare chaque transition
## d'état, à l'instant près. Une divergence est une régression, jamais une
## interprétation.
##
## CE QUE LE CALIBRAGE NE FAIT PAS ET QUE LE JEU FAIT. schedule.js simule un
## joueur parfait en mouvement linéaire ; ici les convois ACCÉLÈRENT et
## FREINENT (easeRun), se rangent dans une file en accordéon (qs), et le
## point de départ d'une entrée est la position réelle d'arrêt sur la voie
## d'approche (startS). Les huit pièges de PORTAGE-GODOT.md §5 vivent ici.
##
## Les identifiants de quai sont les floats du JSON, manipulés tels quels ;
## ils ne deviennent « 1 » que dans les identifiants de chemin, par int().

const Geo := preload("res://jeu/geometrie.gd")

const DEFAULT_MAX_DELAY := 120.0

# --- les états, en entiers -------------------------------------------------
const S_SCHEDULED := 0
const S_APPROACHING := 1
const S_WAITING := 2
const S_MOVING_IN := 3
const S_DWELL := 4
const S_MOVING_OUT := 5
const S_MOVING_BACK := 6
const S_MOVING_THROUGH := 7
const S_DONE := 8
const NOMS_ETAT := ["scheduled", "approaching", "waiting", "movingIn", "dwell",
	"movingOut", "movingBack", "movingThrough", "done"]

# --- le barème (js/ruban.js, SEUILS) ----------------------------------------
const SEUILS := {
	1: {"trois": 12, "deux": 20, "une": 30},
	2: {"trois": 11, "deux": 20, "une": 30},
	3: {"trois": 10, "deux": 20, "une": 30},
	4: {"trois": 9, "deux": 20, "une": 30},
	5: {"trois": 8, "deux": 20, "une": 30},
}


## Un convoi. Les champs « nullables » de game.js (platform, target, qs,
## actualArr, arrEff) sont des Variant tenus à null — c'est ce que le JS fait,
## et les tests `== null` gardent leur sens.
class Train:
	var id: String
	var from: String
	var to: String
	var cars: float
	var freight: bool = false
	var arr: float
	var dep: float
	var arr_eff: Variant = null
	var hint: Variant = null
	var state: int = S_SCHEDULED
	var progress: float = 0.0
	var qs: Variant = null
	var settled: bool = false
	var platform: Variant = null
	var target: Variant = null
	var entry_path: String = ""
	var exit_path: String = ""
	var refoul: bool = false
	var stop_s: float = 0.0
	var start_s: float = 0.0
	var back_s: float = 0.0
	var actual_arr: Variant = null
	var queued_at: int = 0
	var wrong_platform: bool = false
	var holding: bool = false
	var dep_delay: float = 0.0

	## `t.arrEff ?? t.arr`
	func heure_arrivee() -> float:
		return float(arr_eff) if arr_eff != null else arr


var G: Dictionary
var cfg: Dictionary
var paths: Dictionary
var conflicts: Dictionary
var links: Dictionary
var portals: Dictionary
var approach: Dictionary
var depart: Dictionary

var trains: Array = []
var events: Array = []
var game_min: float = 0.0
var total_delay: float = 0.0
var ended: bool = false
var selected: Train = null
var active_routes: Dictionary = {}   # id de chemin -> Train
var queue_seq: int = 0
var on_time_streak: int = 0
var resultat: Dictionary = {}        # rempli par fin_de_service


func _init(geometrie: Dictionary, fiche: Dictionary) -> void:
	G = geometrie
	cfg = fiche
	paths = G["paths"]
	conflicts = G["conflicts"]
	links = G["links"]
	portals = G["portals"]
	approach = G["approach"]
	depart = G["depart"]


## Ce que resetGame() fait de la journée : les convois à leur état initial.
func charger(day: Dictionary) -> void:
	trains.clear()
	events.clear()
	game_min = 0.0
	total_delay = 0.0
	ended = false
	selected = null
	active_routes = {}
	queue_seq = 0
	on_time_streak = 0
	resultat = {}
	for ev in day.get("events", []):
		var e: Dictionary = ev.duplicate()
		e["revealed"] = false
		e["cleared"] = false
		events.append(e)
	for s in day.get("schedule", []):
		var t := Train.new()
		t.id = String(s["id"])
		t.from = String(s["from"])
		t.to = String(s["to"])
		t.freight = bool(s.get("freight", false))
		var cars := float(s.get("cars", 1))
		t.cars = cars if t.freight else min(float(Geo.MAX_CARS), max(1.0, cars if cars else 1.0))
		t.arr = float(s["arr"])
		t.dep = float(s["dep"])
		t.arr_eff = float(s["arrEff"]) if s.has("arrEff") and s["arrEff"] != null else null
		t.hint = s.get("hint", null)
		trains.append(t)


# ------------------------------------------------------------------
# Petits calculs, aux noms de engine.js / render.js
# ------------------------------------------------------------------
func max_delay() -> float:
	return float(cfg["maxDelay"]) if cfg.has("maxDelay") and cfg["maxDelay"] != null else DEFAULT_MAX_DELAY


static func lateness(t: Train, now: float) -> float:
	return now - t.dep - Geo.DEPART_GRACE


static func slowness(t: Train) -> float:
	return Enclenchement.FREIGHT_SLOWNESS if t.freight else 1 + (t.cars - 1) * 0.22


const FREIGHT_SLOWNESS := 1 + (3 - 1) * 0.22


static func train_len(t: Train) -> float:
	return t.cars * Geo.CAR_SPACING - Geo.CAR_GAP


## Accélération puis freinage — render.js. Même expression, même ordre.
static func ease_run(u: float, ta: float, td: float) -> float:
	u = min(max(u, 0.0), 1.0)
	var v: float = 1 / (1 - ta / 2 - td / 2)
	if u < ta:
		return v * u * u / (2 * ta)
	if u > 1 - td:
		return 1 - v * (1 - u) * (1 - u) / (2 * td)
	return v * (ta / 2 + (u - ta))


func _pid_in(t: Train, pid: Variant) -> String:
	return "in:%s:%d" % [t.from, int(pid)]


func _pid_out(t: Train, pid: Variant) -> String:
	return "out:%s:%d" % [t.to, int(pid)]


# ------------------------------------------------------------------
# Enclenchement
# ------------------------------------------------------------------
## L'intervalle d'abscisse occupé par un convoi sur son chemin actif, et son
## sens ; null s'il n'y est pas encore.
func occupied_span(t: Train, path_id: String) -> Variant:
	var path: Dictionary = paths[path_id]
	var tail: float = (t.cars - 1) * Geo.CAR_SPACING
	if t.state == S_MOVING_THROUGH:
		var pin: Dictionary = paths[t.entry_path]
		var pout: Dictionary = paths[t.exit_path]
		var total_arc: float = pin["len"] + pout["len"]
		var end_u: float = 1 + (tail + Geo.EXIT_RUN) / total_arc
		var s0: float = t.start_s
		var h: float = s0 + ease_run(t.progress / end_u, 0.12, 0) * (end_u * total_arc - s0)
		if path_id == t.entry_path:
			return {"lo": h - tail, "hi": min(h, pin["len"]), "dir": 1}
		if h <= pin["len"]:
			return null
		var head_out: float = pout["len"] - (h - pin["len"])
		return {"lo": head_out, "hi": min(pout["len"], head_out + tail), "dir": -1}
	if t.state == S_MOVING_IN:
		var u: float = min(t.progress * path["len"] / t.stop_s, 1.0)
		var s0: float = t.start_s
		var head_s: float = s0 + ease_run(u, 0.10, 0.22) * (t.stop_s - s0)
		return {"lo": head_s - tail, "hi": head_s, "dir": 1}
	if t.state == S_MOVING_OUT:
		var gone_p: float = 1 + (tail + Geo.EXIT_RUN) / path["len"]
		var eff_p: float = ease_run(t.progress / gone_p, 0.16, 0) * gone_p
		var head_s: float = (1 - eff_p) * (path["len"] + t.back_s)
		return {"lo": head_s, "hi": head_s + tail, "dir": -1}
	if t.state == S_MOVING_BACK:
		var p0: float = 1 - t.stop_s / path["len"]
		var eff_p: float = p0 + ease_run((t.progress - p0) / (1 - p0), 0.16, 0) * (1 - p0)
		var head_s: float = (1 - eff_p) * path["len"]
		return {"lo": head_s - tail, "hi": head_s, "dir": -1}
	return null


## Tête de file : aucun convoi du même portail, entré avant lui, n'attend.
func is_queue_head(t: Train) -> bool:
	for o in trains:
		if o != t and o.from == t.from and o.queued_at < t.queued_at \
				and (o.state == S_APPROACHING or o.state == S_WAITING):
			return false
	return true


## Un convoi qui quitte le quai passe avant un fret qui arrive.
func departure_waiting(exit_id: String, moi: Train) -> bool:
	for o in trains:
		if o == moi or o.state != S_DWELL or o.wrong_platform or o.platform == null:
			continue
		if not (o.freight or game_min >= max(o.dep, float(o.actual_arr) + Geo.MIN_DWELL)):
			continue
		var oid := _pid_out(o, o.platform)
		if not paths.has(oid):
			continue
		if oid == exit_id or (conflicts.has(oid) and conflicts[oid].has(exit_id)):
			return true
	return false


func can_grant(path_id: String) -> bool:
	if active_routes.has(path_id):
		return false
	for aid in active_routes:
		var zone: Variant = conflicts[aid].get(path_id)
		if zone == null:
			continue
		var occ: Variant = occupied_span(active_routes[aid], aid)
		if occ == null:
			return false
		var cleared: bool = occ["lo"] > zone["hi"] if occ["dir"] == 1 else occ["hi"] < zone["lo"]
		if not cleared:
			return false
	return true


func grant(path_id: String, t: Train) -> void:
	active_routes[path_id] = t


func release(path_id: String) -> void:
	active_routes.erase(path_id)


# ------------------------------------------------------------------
# Les quais
# ------------------------------------------------------------------
func platform_claimed(pid: Variant) -> bool:
	for t in trains:
		if t.target == pid and (t.state == S_WAITING or t.state == S_APPROACHING):
			return true
	return false


func platform_reserved(pid: Variant) -> bool:
	if platform_claimed(pid):
		return true
	for t in trains:
		if t.platform == pid and (t.state == S_MOVING_IN or t.state == S_DWELL):
			return true
	return false


func platform_closed(pid: Variant) -> bool:
	for ev in events:
		if ev.get("type") == "closure" and ev["plat"] == pid and ev["revealed"] \
				and not ev["cleared"] and game_min < float(ev["end"]):
			return true
	return false


func platform_occupied(pid: Variant) -> bool:
	for t in trains:
		if t.platform == pid and (t.state == S_MOVING_IN or t.state == S_DWELL \
				or t.state == S_MOVING_THROUGH or t.state == S_MOVING_BACK):
			return true
	return false


## Le fret se sert seul : d'abord le quai de calibrage, sinon le premier
## qui dessert sa destination et où il peut s'engager tout de suite.
func pick_freight_platform(t: Train) -> Variant:
	var ok := func(pid) -> bool:
		return paths.has(_pid_out(t, pid)) and not platform_reserved(pid) and not platform_closed(pid)
	var lf: Array = links.get(t.from, [])
	if t.hint != null and lf.has(t.hint) and ok.call(t.hint):
		return t.hint
	var free: Array = []
	for pid in lf:
		if ok.call(pid):
			free.append(pid)
	for pid in free:
		var pris := false
		for o in trains:
			if o != t and o.platform == pid and (o.state == S_MOVING_IN or o.state == S_DWELL \
					or o.state == S_MOVING_THROUGH):
				pris = true
				break
		if not pris and can_grant(_pid_in(t, pid)) and can_grant(_pid_out(t, pid)):
			return pid
	return free[0] if not free.is_empty() else null


# ------------------------------------------------------------------
# Les imprévus, révélés en cours de partie
# ------------------------------------------------------------------
func process_events() -> void:
	for ev in events:
		if not ev["revealed"]:
			if ev.get("type") == "late" and game_min >= float(ev["revealAt"]):
				ev["revealed"] = true
			elif ev.get("type") == "closure" and game_min >= float(ev["start"]):
				# on ne ferme jamais un quai occupé : repoussée tant qu'il l'est
				if platform_occupied(ev["plat"]):
					if game_min >= float(ev["end"]):
						ev["revealed"] = true
						ev["cleared"] = true
				else:
					ev["revealed"] = true
		if ev.get("type") == "closure" and ev["revealed"] and not ev["cleared"] \
				and game_min >= float(ev["end"]):
			ev["cleared"] = true


# ------------------------------------------------------------------
# La file d'approche — la part de RÈGLE de placeQueue (render.js)
# ------------------------------------------------------------------
func placer_file(t: Train, dt: float) -> void:
	var queue: Array = []
	for o in trains:
		if (o.state == S_WAITING or o.state == S_APPROACHING) and o.from == t.from:
			queue.append(o)
	queue.sort_custom(func(a, b): return a.queued_at < b.queued_at)
	var idx := queue.find(t)
	if not approach.has(t.from):
		return
	var ap: Dictionary = approach[t.from]
	var ap_len: float = ap["len"]
	var s_target: float = ap_len - 85
	for k in range(idx):
		s_target -= train_len(queue[k]) + 14
	if idx > 0:
		var ahead: Train = queue[idx - 1]
		if ahead.qs != null:
			s_target = min(s_target, float(ahead.qs) - train_len(ahead) - 14)
	for o in trains:
		if o == t or o.from != t.from:
			continue
		if o.state != S_MOVING_IN and o.state != S_MOVING_THROUGH:
			continue
		var occ: Variant = occupied_span(o, o.entry_path)
		if occ != null:
			s_target = min(s_target, ap_len + occ["lo"] - 44)
	if t.qs == null:
		t.qs = min(-20.0, s_target - 40)
		t.settled = false
	var dist: float = s_target - float(t.qs)
	var cap: float = 300 * dt
	var step: float = min(abs(dist), max(cap * 0.3, cap * min(1.0, abs(dist) / 50)))
	t.qs = float(t.qs) + sign(dist) * step
	if abs(s_target - float(t.qs)) < 3:
		t.settled = true


# ------------------------------------------------------------------
# Interaction : sélection du train, choix du quai
# ------------------------------------------------------------------
## Le tap sur un convoi. Rend ce que le prototype dirait au joueur.
func clic_train(t: Train) -> String:
	if ended:
		return ""
	if t.freight:
		return "Fret · passage auto"
	var routable: bool = t.state == S_WAITING or t.state == S_APPROACHING
	if routable and t.target == null:
		selected = t
		return "sélectionné"
	if routable and t.target != null:
		t.target = null
		selected = t
		return "choisissez un nouveau quai"
	if t.state == S_DWELL and paths.has(_pid_out(t, t.platform)):
		return "à quai"
	if t.state == S_MOVING_IN or t.state == S_MOVING_OUT or t.state == S_MOVING_BACK:
		return "en mouvement"
	if t.state == S_DWELL and not paths.has(_pid_out(t, t.platform)):
		return "mauvais quai, refoulement en cours"
	return ""


## Le tap sur un quai, un convoi étant sélectionné.
func clic_quai(pid: Variant) -> String:
	if selected == null or selected.target != null \
			or (selected.state != S_WAITING and selected.state != S_APPROACHING):
		return ""
	if not links.get(selected.from, []).has(pid):
		return "Aucune voie ici"
	if platform_claimed(pid):
		return "Quai déjà promis"
	if platform_closed(pid):
		return "Quai fermé"
	var deferred := platform_occupied(pid)
	selected.target = pid
	selected = null
	return "différé" if deferred else "ok"


# ------------------------------------------------------------------
# Boucle de jeu
# ------------------------------------------------------------------
func live_delay() -> float:
	var d: float = total_delay
	for t in trains:
		if not t.freight and (t.state != S_MOVING_OUT or t.refoul) and t.state != S_DONE:
			d += floor(max(0.0, lateness(t, game_min)))
	return d


func any_train_moving() -> bool:
	for t in trains:
		if t.state == S_MOVING_OUT or t.state == S_MOVING_THROUGH \
				or t.state == S_MOVING_IN or t.state == S_MOVING_BACK:
			return true
	return false


func tick(dt: float) -> void:
	process_events()
	for t in trains:
		match t.state:
			S_SCHEDULED:
				if game_min >= t.heure_arrivee() - Geo.APPROACH_LEAD:
					t.state = S_APPROACHING
					t.queued_at = queue_seq
					queue_seq += 1
			S_APPROACHING:
				placer_file(t, dt)
				if game_min >= t.heure_arrivee():
					t.state = S_WAITING
			S_WAITING:
				placer_file(t, dt)
				if not is_queue_head(t):
					continue
				if t.freight and t.target == null:
					var pid: Variant = pick_freight_platform(t)
					if pid == null:
						continue
					t.target = pid
				if t.target != null and not platform_closed(t.target):
					var busy := false
					for o in trains:
						if o != t and o.platform == t.target and (o.state == S_MOVING_IN \
								or o.state == S_DWELL or o.state == S_MOVING_THROUGH):
							busy = true
							break
					var path_id := _pid_in(t, t.target)
					if not busy and can_grant(path_id):
						grant(path_id, t)
						t.entry_path = path_id
						t.platform = t.target
						t.start_s = -(approach[t.from]["len"] - float(t.qs)) if t.qs != null else 0.0
						t.progress = 0.0
						t.stop_s = paths[path_id]["len"]
						t.state = S_MOVING_IN
			S_MOVING_IN:
				var path: Dictionary = paths[t.entry_path]
				t.progress += dt / (path["dur"] * slowness(t))
				var stop_p: float = t.stop_s / path["len"]
				if t.progress >= stop_p:
					t.progress = stop_p
					var out_id := _pid_out(t, t.platform)
					if t.freight and paths.has(out_id) and can_grant(out_id) \
							and not departure_waiting(out_id, t):
						release(t.entry_path)
						grant(out_id, t)
						t.exit_path = out_id
						t.start_s = t.stop_s
						t.progress = 0.0
						t.state = S_MOVING_THROUGH
						continue
					t.state = S_DWELL
					t.actual_arr = game_min
					release(t.entry_path)
			S_DWELL:
				if not paths.has(_pid_out(t, t.platform)):
					if not t.wrong_platform:
						t.wrong_platform = true
					var back_path := _pid_in(t, t.platform)
					if can_grant(back_path):
						grant(back_path, t)
						t.exit_path = back_path
						t.state = S_MOVING_BACK
						t.progress = 1 - t.stop_s / paths[back_path]["len"]
					continue
				var can_leave: bool = t.freight or game_min >= max(t.dep, float(t.actual_arr) + Geo.MIN_DWELL)
				if can_leave:
					var path_id := _pid_out(t, t.platform)
					if can_grant(path_id):
						t.holding = false
						grant(path_id, t)
						t.exit_path = path_id
						var uturn: bool = portals[t.from]["side"] == portals[t.to]["side"]
						t.back_s = max(0.0, (Geo.PLAT_X2 - Geo.PLAT_X1 - 2 * Geo.STOP_MARGIN) \
							- (t.cars - 1) * Geo.CAR_SPACING) if uturn else 0.0
						t.state = S_MOVING_OUT
						t.progress = 0.0
						if not t.freight:
							t.dep_delay = max(0.0, lateness(t, game_min))
							total_delay += floor(t.dep_delay)
							if t.dep_delay < 1:
								on_time_streak += 1
							else:
								on_time_streak = 0
					elif not t.holding:
						t.holding = true
				else:
					t.holding = false
			S_MOVING_BACK:
				var path: Dictionary = paths[t.exit_path]
				t.progress += dt / (path["dur"] * slowness(t))
				if t.progress >= 1:
					release(t.exit_path)
					t.exit_path = ""
					t.platform = null
					t.target = null
					t.actual_arr = null
					t.wrong_platform = false
					t.qs = approach[t.from]["len"]
					t.settled = false
					t.state = S_WAITING
					t.queued_at = queue_seq
					queue_seq += 1
			S_MOVING_OUT:
				var path: Dictionary = paths[t.exit_path]
				t.progress += dt / (path["dur"] * slowness(t))
				var tail: float = (t.cars - 1) * Geo.CAR_SPACING
				var gone_p: float = 1 + (tail + Geo.EXIT_RUN) / path["len"]
				var eff_p: float = ease_run(t.progress / gone_p, 0.16, 0) * gone_p
				var head_s: float = (1 - eff_p) * (path["len"] + t.back_s)
				if head_s + tail < -Geo.PORTAL_CLEAR and active_routes.get(t.exit_path) == t:
					release(t.exit_path)
				var off_map: bool = head_s + tail < -(depart[t.to]["len"] + 20)
				if t.progress >= gone_p or off_map:
					t.state = S_DONE
			S_MOVING_THROUGH:
				var pin: Dictionary = paths[t.entry_path]
				var pout: Dictionary = paths[t.exit_path]
				var total_arc: float = pin["len"] + pout["len"]
				var tail: float = (t.cars - 1) * Geo.CAR_SPACING
				var end_u: float = 1 + (tail + Geo.EXIT_RUN) / total_arc
				var s0: float = t.start_s
				var dur_tot: float = Geo.TRAVEL * total_arc / 700 * FREIGHT_SLOWNESS \
					* (end_u * total_arc - s0) / (end_u * total_arc)
				t.progress += dt / dur_tot
				var h: float = s0 + ease_run(t.progress / end_u, 0.12, 0) * (end_u * total_arc - s0)
				if t.platform != null and h - tail > pin["len"]:
					t.platform = null
				if h - tail > total_arc + Geo.PORTAL_CLEAR and active_routes.get(t.exit_path) == t:
					release(t.exit_path)
				if t.progress >= end_u or h - tail > total_arc + depart[t.to]["len"] + 20:
					if active_routes.get(t.exit_path) == t:
						release(t.exit_path)
						t.platform = null
					t.state = S_DONE
	if not ended and live_delay() > max_delay():
		fin_de_service(true)
		return
	if not ended:
		var fini := true
		for t in trains:
			var sorti: bool = (t.state == S_MOVING_OUT or t.state == S_MOVING_THROUGH) \
				and not active_routes.values().has(t)
			if not (t.state == S_DONE or sorti):
				fini = false
				break
		if fini:
			fin_de_service(false)


## Le barème d'une gare telle qu'on la joue. Ici : celui de sa difficulté de
## fiche — la rampe du ruban (js/ruban.js, difficulteDeGare) est l'étape 5.
func seuils_de_service() -> Dictionary:
	var d := int(cfg.get("difficulty", 0))
	var s: Dictionary = SEUILS[max(1, min(5, d if d else 3))]
	if cfg.has("seuils") and cfg["seuils"] is Dictionary:
		s = s.duplicate()
		s.merge(cfg["seuils"], true)
	return s


func fin_de_service(failed: bool) -> Dictionary:
	ended = true
	var d: float = floor((live_delay() if failed else total_delay) + 0.5)
	var s := seuils_de_service()
	var stars: int = 0 if failed else (3 if d < s["trois"] else 2 if d < s["deux"] else 1 if d < s["une"] else 0)
	var win: bool = stars >= 1
	var perfect: bool = win and not failed and d == 0
	resultat = {"failed": failed, "d": d, "stars": stars, "win": win, "perfect": perfect,
		"totalDelay": total_delay, "streak": on_time_streak}
	return resultat
