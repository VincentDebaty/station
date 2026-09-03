class_name Geometrie
## LA GÉOMÉTRIE D'UNE GARE, GÉNÉRÉE DEPUIS SA FICHE.
##
## Transposition de `loadStation()` (js/engine.js), ligne à ligne. Aucune gare
## n'est dessinée à la main : quais, portails, courbes du gril, voies d'approche
## et de départ, zones de conflit et liaisons autorisées DÉCOULENT de la fiche.
## C'est la contrainte structurante du portage (PORTAGE-GODOT.md §3).
##
## L'ORACLE A LE DERNIER MOT. `tools/oracle-geometrie.mjs` fait calculer la même
## fiche par engine.js et par ce fichier, et compare point par point. Toute
## divergence est une régression, pas une interprétation : ne « corrige » jamais
## une formule ici sans que l'oracle passe derrière.
##
## FLOTTANTS 64 BITS, VOLONTAIREMENT. `Vector2` est en 32 bits dans une
## compilation standard de Godot ; sur des abscisses cumulées de ~1 000 px,
## l'erreur atteint le dixième de pixel, et les zones de conflit se décident à
## un seuil de 16 px sur des points échantillonnés. Les points sont donc tenus
## en `PackedFloat64Array` (xs, ys) et ne deviennent des Vector2 qu'au rendu.
##
## L'ARRONDI EST CELUI DE JAVASCRIPT : Math.round monte à la moitié, quel que
## soit le signe — floor(x + 0.5). Le `round()` de GDScript s'éloigne de zéro ;
## sur nos ordonnées, toutes positives, les deux coïncident, mais on n'y compte
## pas (PORTAGE-GODOT.md §4, la rampe).

# --- Gabarit, en unités monde = pixels Godot (PORTAGE-GODOT.md §4) ----------
const PLAT_H := 42
const CENTER_Y := 400
const MIN_CARS := 2
const MAX_CARS := 7
const CAR_LEN := 30
const CAR_GAP := 5
const CAR_SPACING := CAR_LEN + CAR_GAP            # 35
const CAR_H := 20
const PLAT_MARGIN := (PLAT_H - CAR_H) / 2.0       # 11
const PLAT_LEN := MAX_CARS * CAR_SPACING - CAR_GAP + 2 * PLAT_MARGIN   # 262
const PLAT_MID := 700
const PLAT_X1 := PLAT_MID - PLAT_LEN / 2.0        # 569
const PLAT_X2 := PLAT_MID + PLAT_LEN / 2.0        # 831
const EXIT_RUN := 700
const EDGE_RUN := 360
const STOP_MARGIN := PLAT_MARGIN + CAR_LEN / 2.0  # 26
const PORTAL_CLEAR := 130

# --- Temps (PORTAGE-GODOT.md §4) ----------------------------------------------
const TRAVEL := 1.6
const MIN_DWELL := 2
const SEC_PER_GAMEMIN := 4.0
const DEPART_GRACE := 0.15
const APPROACH_LEAD := 1.3
const FREIGHT_COLOR := "#8f98a8"


static func js_round(v: float) -> int:
	return int(floor(v + 0.5))


## Un point d'une cubique de Bézier — même ordre d'opérations qu'en JS, pour
## que l'oracle compare des doubles calculés pareil.
static func _cubic(p0x: float, p0y: float, c1x: float, c1y: float,
		c2x: float, c2y: float, p1x: float, p1y: float, t: float) -> Array:
	var u := 1.0 - t
	return [
		u * u * u * p0x + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t * t * t * p1x,
		u * u * u * p0y + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t * t * t * p1y,
	]


## Échantillonne une cubique en n+1 points → [xs, ys].
static func _sample_path(p0x: float, p0y: float, c1x: float, c1y: float,
		c2x: float, c2y: float, p1x: float, p1y: float, n: int = 60) -> Array:
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	for i in range(n + 1):
		var p := _cubic(p0x, p0y, c1x, c1y, c2x, c2y, p1x, p1y, float(i) / n)
		xs.append(p[0])
		ys.append(p[1])
	return [xs, ys]


## Abscisses cumulées le long d'une polyligne. `Math.hypot` côté JS, racine
## de la somme des carrés ici : identiques à 1e-9 près, l'oracle le vérifie.
static func _cum(xs: PackedFloat64Array, ys: PackedFloat64Array) -> PackedFloat64Array:
	var cum := PackedFloat64Array([0.0])
	for i in range(1, xs.size()):
		var dx := xs[i] - xs[i - 1]
		var dy := ys[i] - ys[i - 1]
		cum.append(cum[i - 1] + sqrt(dx * dx + dy * dy))
	return cum


## Construit tout le réseau d'une fiche. Le résultat reprend les noms de
## engine.js pour que l'oracle n'ait rien à traduire :
##   platforms, portals, dest_color, dest_abbr, links,
##   paths, approach, depart, conflicts, pairs
static func construire(cfg: Dictionary) -> Dictionary:
	var G := {}

	# --- layout : quais et portails répartis selon leur nombre --------------
	var quais: Array = cfg.get("platforms", [])
	var n_q := quais.size()
	var step_q: float = min(100.0, 520.0 / (n_q - 1)) if n_q > 1 else 0.0
	var span_q := step_q * (n_q - 1)
	var top_q := CENTER_Y - span_q / 2.0
	var platforms: Array = []
	for i in range(n_q):
		var q: Dictionary = quais[i].duplicate()
		q["cy"] = js_round(top_q + i * step_q)
		platforms.append(q)
	G["platforms"] = platforms

	var portals := {}
	var dest_color := {}
	var dest_abbr := {}
	var span_p: float = min(420.0, span_q)
	var cfg_portals: Dictionary = cfg.get("portals", {})
	for side in ["L", "R"]:
		var names: Array = []
		for k in cfg_portals.keys():
			if cfg_portals[k].get("side") == side:
				names.append(k)
		for i in range(names.size()):
			var k: String = names[i]
			var c: Dictionary = cfg_portals[k]
			var cy: int = CENTER_Y if names.size() == 1 \
				else js_round(CENTER_Y - span_p / 2.0 + span_p * i / (names.size() - 1))
			portals[k] = {
				"side": side,
				"x": 150 if side == "L" else 1250,
				"cy": cy,
				"label": c.get("label", k),
				"in": not (c.has("in") and c["in"] == false),
				"out": not (c.has("out") and c["out"] == false),
			}
			dest_color[k] = c.get("color")
			dest_abbr[k] = c.get("abbr")
	G["portals"] = portals
	G["dest_color"] = dest_color
	G["dest_abbr"] = dest_abbr
	var links: Dictionary = cfg.get("links", {})
	G["links"] = links

	# --- réseau : un chemin par liaison (portail <-> quai) --------------------
	var paths := {}
	var mesh: Array = []          # les béziers seules, pour le tracé gris du gril
	for pname in portals.keys():
		var p: Dictionary = portals[pname]
		for pid in links.get(pname, []):
			var q: Dictionary = {}
			for x in platforms:
				if x.get("id") == pid:
					q = x
					break
			var qcy := float(q["cy"])
			var bez: Array
			var edge_x: float
			var dir: int
			if p["side"] == "L":
				bez = _sample_path(p["x"], p["cy"], p["x"] + 190, p["cy"],
					PLAT_X1 - 190, qcy, PLAT_X1, qcy)
				edge_x = PLAT_X1
				dir = 1
			else:
				bez = _sample_path(p["x"], p["cy"], p["x"] - 190, p["cy"],
					PLAT_X2 + 190, qcy, PLAT_X2, qcy)
				edge_x = PLAT_X2
				dir = -1
			mesh.append({"portal": pname, "platform": pid, "xs": bez[0], "ys": bez[1]})
			var far_x: float = PLAT_X2 - STOP_MARGIN if dir == 1 else PLAT_X1 + STOP_MARGIN
			var near_x: float = PLAT_X1 + STOP_MARGIN if dir == 1 else PLAT_X2 - STOP_MARGIN
			for role_end in [["in", far_x], ["out", near_x]]:
				var role: String = role_end[0]
				var end_x: float = role_end[1]
				if role == "in" and not p["in"]:
					continue
				if role == "out" and not p["out"]:
					continue
				# Les nombres d'un JSON arrivent en float : str(1.0) donne « 1.0 »,
				# et l'identifiant ne correspondrait plus à celui d'engine.js
				# (« in:YORK:1 »). Attrapé par l'oracle — 104 clés absentes.
				var id := "%s:%s:%d" % [role, pname, int(pid)]
				var xs: PackedFloat64Array = bez[0].duplicate()
				var ys: PackedFloat64Array = bez[1].duplicate()
				var n := 24
				for i in range(1, n + 1):
					xs.append(edge_x + (end_x - edge_x) * i / n)
					ys.append(qcy)
				var cum := _cum(xs, ys)
				var len_ := cum[cum.size() - 1]
				paths[id] = {"id": id, "xs": xs, "ys": ys, "cum": cum, "len": len_,
					"side": p["side"], "dur": TRAVEL * len_ / 700}
	G["paths"] = paths
	G["mesh"] = mesh

	# --- deux voies par portail : approche (bas) et départ (haut) ------------
	var approach := {}
	var depart := {}
	for pname in portals.keys():
		var p: Dictionary = portals[pname]
		var px := float(p["x"])
		var pcy := float(p["cy"])
		var start_x: float = -EDGE_RUN if p["side"] == "L" else 1400 + EDGE_RUN
		var merge_x: float = px + (-110 if p["side"] == "L" else 110)
		var mid_x: float = px + (-55 if p["side"] == "L" else 55)
		var raccord := _sample_path(merge_x, pcy + 36, mid_x, pcy + 36, mid_x, pcy, px, pcy, 24)
		var axs := PackedFloat64Array([start_x])
		var ays := PackedFloat64Array([pcy + 36])
		axs.append_array(raccord[0])
		ays.append_array(raccord[1])
		var acum := _cum(axs, ays)
		approach[pname] = {"xs": axs, "ys": ays, "cum": acum, "len": acum[acum.size() - 1]}
		var dxs := PackedFloat64Array([px, start_x])
		var dys := PackedFloat64Array([pcy, pcy])
		var dcum := _cum(dxs, dys)
		depart[pname] = {"xs": dxs, "ys": dys, "cum": dcum, "len": dcum[dcum.size() - 1]}
	G["approach"] = approach
	G["depart"] = depart

	# --- conflits : deux chemins du même gril à moins de 16 px ---------------
	var conflicts := {}
	var ids: Array = paths.keys()
	for id in ids:
		conflicts[id] = {}
	for a in range(ids.size()):
		for b in range(a + 1, ids.size()):
			var ra: Dictionary = paths[ids[a]]
			var rb: Dictionary = paths[ids[b]]
			if ra["side"] != rb["side"]:
				continue
			var touching := false
			var a_lo := INF
			var a_hi := -INF
			var b_lo := INF
			var b_hi := -INF
			var axs: PackedFloat64Array = ra["xs"]
			var ays: PackedFloat64Array = ra["ys"]
			var bxs: PackedFloat64Array = rb["xs"]
			var bys: PackedFloat64Array = rb["ys"]
			var acum: PackedFloat64Array = ra["cum"]
			var bcum: PackedFloat64Array = rb["cum"]
			for i in range(axs.size()):
				for j in range(bxs.size()):
					var dx := axs[i] - bxs[j]
					var dy := ays[i] - bys[j]
					if dx * dx + dy * dy < 16 * 16:
						touching = true
						a_lo = min(a_lo, acum[i])
						a_hi = max(a_hi, acum[i])
						b_lo = min(b_lo, bcum[j])
						b_hi = max(b_hi, bcum[j])
			if touching:
				# Marge de sécurité : presque un wagon. Si la zone touche la
				# gorge du portail (s ≤ 0), le dégagement s'étend à tout le
				# raccord approche/départ.
				var M := 28.0
				conflicts[ids[a]][ids[b]] = {"lo": _lo(a_lo, M), "hi": a_hi + M}
				conflicts[ids[b]][ids[a]] = {"lo": _lo(b_lo, M), "hi": b_hi + M}
	G["conflicts"] = conflicts

	# --- liaisons autorisées ---------------------------------------------------
	var pairs: Array = []
	var ssp: Variant = cfg.get("sameSidePairs", [])
	for a in portals.keys():
		for b in portals.keys():
			if a == b:
				continue
			if not portals[a]["in"] or not portals[b]["out"]:
				continue
			var commun := false
			for q in links.get(a, []):
				if links.get(b, []).has(q):
					commun = true
					break
			if not commun:
				continue
			if portals[a]["side"] == portals[b]["side"] and not (ssp is String and ssp == "all"):
				var declare := false
				if ssp is Array:
					for pr in ssp:
						if pr[0] == a and pr[1] == b:
							declare = true
							break
				if not declare:
					continue
			pairs.append([a, b])
	G["pairs"] = pairs
	return G


static func _lo(v: float, M: float) -> float:
	return -float(PORTAL_CLEAR) if v - M <= 0 else v - M


## Les points d'un chemin en Vector2, pour le rendu seulement.
static func vers_vector2(xs: PackedFloat64Array, ys: PackedFloat64Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(xs.size())
	for i in range(xs.size()):
		out[i] = Vector2(xs[i], ys[i])
	return out
