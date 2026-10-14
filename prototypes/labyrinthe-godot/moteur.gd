class_name Moteur
extends RefCounted
# ------------------------------------------------------------------
# LE MOTEUR DU LABYRINTHE D'EAU — porté de la page web, fonction pour fonction.
#
# La page (prototypes/prototype-labyrinthe.html, bloc <script id="moteur">)
# reste la seule autorité sur les règles. Ce fichier la traduit dans le même
# ordre d'opérations : le moteur n'utilise que + − × /, la racine carrée et
# des arrondis vers le bas, tous exacts en double précision, si bien que les
# nombres doivent sortir IDENTIQUES. oracle.gd le vérifie contre des parties
# jouées par la page (node tools/labyrinthe-vers-godot.mjs).
#
# Deux échelles. Le LABYRINTHE (murs, vannes, sortie, boule, unités de
# jeu) se compte en cases. L'EAU se calcule en petites cases : chaque case
# du labyrinthe en contient S × S, et un pas de jeu (une image) en enchaîne
# S de calcul. Les commentaires de la page valent ici ; on ne les répète pas.
# ------------------------------------------------------------------

const DEBIT := 0.1
const SEC := 0.05
const UNITE := 1.0
const RAYON := 0.34
const FLOTTE := 0.08
const RESSORT := 0.08
const AMORTI := 0.8
const PESANTEUR := 0.02
const CHUTE_MAX := 0.3
const PORTE := 2.5
const SUIT := 0.1
const ATTIRE := 1.5
const FROTTE := 0.85
const CALME := 2e-4
const CALME_PAS := 30
const MAXPAS := 6000
const PLEIN := 0.99
const VIDE := 0.005
const ECART := 0.02
const ETALE := 3
const NIVELLE_MAX := 0.4
const NIVELLE_FOIS := 24
const PLEINE := 0.98
const SECHE := 0.02


# L'état d'une partie : tout ce qui change.
class Etat:
	var m: PackedFloat64Array
	var bx := 0.0
	var by := 0.0
	var bvx := 0.0
	var bvy := 0.0
	var attente: PackedFloat64Array
	var tapes := 0
	var verse := 0.0
	var sorti := 0.0
	var vide := 0.0
	var gagne := false
	var calme := 0
	var pas := 0
	var fx: PackedFloat64Array
	var fy: PackedFloat64Array

	func copie() -> Etat:
		var e := Etat.new()
		e.m = m.duplicate(); e.bx = bx; e.by = by; e.bvx = bvx; e.bvy = bvy
		e.attente = attente.duplicate(); e.tapes = tapes; e.verse = verse; e.sorti = sorti; e.vide = vide
		e.gagne = gagne; e.calme = calme; e.pas = pas; e.fx = fx.duplicate(); e.fy = fy.duplicate()
		return e


# --- la géométrie d'un niveau (prep de la page) --------------------------------
var W: int
var H: int
var S: int
var S2: int
var SW: int
var SH: int
var mur: PackedByteArray
var sortie: PackedByteArray
var fmur: PackedByteArray
var fsortie: PackedByteArray
var m0: PackedFloat64Array
var boule0 := Vector2.ZERO
var vannes: Array = []      # [{type, x, y, i, bec, bloc: PackedInt32Array, fond: PackedInt32Array}]

# des tableaux de travail, pour ne rien allouer à chaque pas
var _vu: PackedByteArray             # déjà pris dans un corps (pression)
var _corps_de: PackedInt32Array      # numéro du corps de chaque petite case
var _vue_de: PackedInt32Array        # surfaces déjà retenues pour ce corps
var _prec: PackedInt32Array          # le chemin du courant ; -2 : pas encore atteinte
var _num := 0


func _init(N: Dictionary) -> void:
	var grille: Array = N["grille"]
	H = grille.size(); W = String(grille[0]).length(); S = int(N.get("finesse", 4))
	mur = PackedByteArray(); mur.resize(W * H)
	sortie = PackedByteArray(); sortie.resize(W * H)
	var plein := PackedByteArray(); plein.resize(W * H)
	var defs: Array = N["vannes"]
	var vv := []
	vv.resize(defs.size())
	for r in H:
		var ligne := String(grille[r])
		for x in W:
			var ch := ligne[x]
			var y := H - 1 - r
			var i := y * W + x
			if ch == "#": mur[i] = 1
			elif ch == "S": sortie[i] = 1
			elif ch == "o": boule0 = Vector2(x + 0.5, y + 0.5)
			elif ch == "~": plein[i] = 1
			elif ch >= "1" and ch <= "9":
				var k := int(ch) - 1
				vv[k] = {"type": String(defs[k]["type"]), "x": x, "y": y, "i": i}
	if N.has("eau"):
		for y in int(N["eau"]):
			for x in W:
				var i := y * W + x
				if not mur[i] and not sortie[i]: plein[i] = 1
	SW = W * S; SH = H * S; S2 = S * S
	fmur = PackedByteArray(); fmur.resize(SW * SH)
	fsortie = PackedByteArray(); fsortie.resize(SW * SH)
	m0 = PackedFloat64Array(); m0.resize(SW * SH)
	for fy in SH:
		for fx in SW:
			var i := (fy / S) * W + (fx / S)
			var j := fy * SW + fx
			fmur[j] = mur[i]; fsortie[j] = sortie[i]; m0[j] = float(plein[i])
	for v in vv:
		var vx: int = v["x"]
		var vy: int = v["y"]
		var bx := S - 1 if vx == 0 else (0 if vx == W - 1 else S / 2)
		var by := 0 if vy == H - 1 else S / 2
		v["bec"] = (vy * S + by) * SW + vx * S + bx
		var bloc := PackedInt32Array()
		var fond := PackedInt32Array()
		for dy in S:
			for dx in S:
				var j := (vy * S + dy) * SW + vx * S + dx
				bloc.append(j)
				if dy == 0: fond.append(j)
		v["bloc"] = bloc; v["fond"] = fond
	vannes = vv
	_vu = PackedByteArray(); _vu.resize(SW * SH)
	_corps_de = PackedInt32Array(); _corps_de.resize(SW * SH)
	_vue_de = PackedInt32Array(); _vue_de.resize(SW * SH)
	_prec = PackedInt32Array(); _prec.resize(SW * SH); _prec.fill(-2)


func ouvert(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and not mur[y * W + x]

func fouvert(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < SW and y < SH and not fmur[y * SW + x]


func charger() -> Etat:
	var e := Etat.new()
	e.m = m0.duplicate()
	e.bx = boule0.x; e.by = boule0.y
	e.attente = PackedFloat64Array(); e.attente.resize(vannes.size())
	e.fx = PackedFloat64Array(); e.fx.resize(SW * SH)
	e.fy = PackedFloat64Array(); e.fy.resize(SW * SH)
	for k in 400:
		bouger(e, 1.0)
	e.bvx = 0.0; e.bvy = 0.0
	return e


func eau_de(e: Etat, cases: PackedInt32Array) -> float:
	var s := 0.0
	for j in cases:
		s += e.m[j]
	return s / S2


# --- l'eau ------------------------------------------------------------------
func _eau(e: Etat) -> float:
	var n := e.m
	var nn := n.size()
	var total := 0.0
	# 1. la chute, de bas en haut
	for y in range(1, SH):
		for x in SW:
			var i := y * SW + x
			var j := i - SW
			if fmur[i] or fsortie[i] or fmur[j] or n[i] <= 0.0:
				continue
			var q := minf(n[i], 1.0 - n[j])
			if q > 1e-9:
				n[i] -= q; n[j] += q; e.fy[j] -= q; total += q
	# 2. l'étalement, ETALE passes, chacune sur un instantané
	for passe in ETALE:
		var s := n.duplicate()
		for i in nn:
			if fmur[i] or fsortie[i] or s[i] <= VIDE:
				continue
			if not (i < SW or fmur[i - SW] or s[i - SW] >= PLEIN):
				continue
			var x := i % SW
			# à gauche, puis à droite
			if x - 1 >= 0 and not fmur[i - 1]:
				var q := (s[i] - s[i - 1]) / 4.0
				if q > 1e-9:
					n[i] -= q; n[i - 1] += q; total += q; e.fx[i - 1] -= q
			if x + 1 < SW and not fmur[i + 1]:
				var q := (s[i] - s[i + 1]) / 4.0
				if q > 1e-9:
					n[i] -= q; n[i + 1] += q; total += q; e.fx[i] += q
	# 3. la pression
	total += _pression(e)
	for i in nn:
		if fsortie[i] and n[i] > 0.0:
			e.sorti += n[i] / S2
			n[i] = 0.0
	return total


# Les voisines ouvertes, dans l'ordre de la page : droite, gauche, haut, bas.
func _voisins(i: int) -> PackedInt32Array:
	var x := i % SW
	var y := i / SW
	var r := PackedInt32Array()
	if x + 1 < SW and not fmur[i + 1]: r.append(i + 1)
	if x > 0 and not fmur[i - 1]: r.append(i - 1)
	if y + 1 < SH and not fmur[i + SW]: r.append(i + SW)
	if y > 0 and not fmur[i - SW]: r.append(i - SW)
	return r


func _hauteur(n: PackedFloat64Array, recoit: int, est_sortie: bool) -> float:
	return float(recoit / SW) + (0.0 if est_sortie else n[recoit])


func _pression(e: Etat) -> float:
	var n := e.m
	var total := 0.0
	_vu.fill(0)
	for i0 in n.size():
		if _vu[i0] or fmur[i0] or fsortie[i0] or n[i0] < PLEIN:
			continue
		_num += 1
		var num := _num
		var corps := PackedInt32Array([i0])
		_vu[i0] = 1
		_corps_de[i0] = num
		var c := 0
		while c < corps.size():
			for j in _voisins(corps[c]):
				if not _vu[j] and not fsortie[j] and n[j] >= PLEIN:
					_vu[j] = 1; _corps_de[j] = num; corps.append(j)
			c += 1
		# ses surfaces : (k, reçoit, sortie)
		var s_k := PackedInt32Array()
		var s_r := PackedInt32Array()
		var s_s: Array[bool] = []
		for k in corps:
			for j in _voisins(k):
				if _corps_de[j] == num or _vue_de[j] == num:
					continue
				var y := j / SW
				var dessous := j - SW
				if fsortie[j]:
					_vue_de[j] = num; s_k.append(k); s_r.append(j); s_s.append(true)
					continue
				var posee := y == 0 or fmur[dessous] or _corps_de[dessous] == num or n[dessous] >= PLEIN
				var dessus := j + SW
				var air := y + 1 >= SH or fmur[dessus] or n[dessus] <= VIDE
				if posee and air:
					_vue_de[j] = num; s_k.append(k); s_r.append(j); s_s.append(false)
		var ns := s_k.size()
		if ns == 0:
			continue
		# le surplus d'une case trop pleine, vers la surface la plus basse
		for k in corps:
			var surplus := n[k] - 1.0
			if surplus <= 1e-4:
				continue
			var b := 0
			for t in ns:
				if _hauteur(n, s_r[t], s_s[t]) < _hauteur(n, s_r[b], s_s[b]):
					b = t
			if k == s_r[b]:
				continue
			var q := minf(surplus, 0.5)
			n[k] -= q; n[s_r[b]] += q; total += q
			_courant(e, k, s_r[b], num, q)
		# le nivellement
		var deplace := 0.0
		var fois := 0
		while fois < NIVELLE_FOIS and deplace < NIVELLE_MAX:
			var haut := -1
			var bas := -1
			var hh := -INF
			var hb := INF
			for t in ns:
				var h := _hauteur(n, s_r[t], s_s[t])
				var don := s_r[t] if n[s_r[t]] > VIDE else s_k[t]
				if not s_s[t] and n[don] > VIDE and h > hh:
					haut = t; hh = h
				if h < hb:
					bas = t; hb = h
			if haut < 0 or haut == bas or hh - hb <= ECART:
				break
			var de := s_r[haut] if n[s_r[haut]] > VIDE else s_k[haut]
			var q := minf(minf(n[de], (hh - hb) / 2.0), NIVELLE_MAX - deplace)
			if not s_s[bas]:
				q = minf(q, 1.0 - n[s_r[bas]])
			if q <= 1e-9:
				break
			n[de] -= q; n[s_r[bas]] += q; total += q; deplace += q
			_courant(e, de, s_r[bas], num, q)
			fois += 1
	return total


# Le courant d'une poussée : le long du plus court chemin dans le corps.
func _courant(e: Etat, de: int, vers: int, num: int, q: float) -> void:
	var file := PackedInt32Array([de])
	_prec[de] = -1
	var k := 0
	while k < file.size() and _prec[vers] == -2:
		for j in _voisins(file[k]):
			if _prec[j] != -2 or not (_corps_de[j] == num or j == vers):
				continue
			_prec[j] = file[k]
			file.append(j)
		k += 1
	if _prec[vers] != -2:
		var j := vers
		while _prec[j] != -1:
			var a := _prec[j]
			if j == a + 1: e.fx[a] += q
			elif j == a - 1: e.fx[j] -= q
			elif j == a + SW: e.fy[a] += q
			else: e.fy[j] -= q
			j = a
	for c in file:
		_prec[c] = -2


# --- les vannes ---------------------------------------------------------------
func _vannes(e: Etat) -> bool:
	var part := 1.0 / S
	var actif := false
	for k in vannes.size():
		var v: Dictionary = vannes[k]
		var a := e.attente[k]
		if a <= 0.0:
			continue
		if v["type"] == "robinet":
			var q := minf(a, DEBIT * part)
			e.m[v["bec"]] += q * S2
			e.verse += q; e.attente[k] -= q; actif = true
		else:
			var fond: PackedInt32Array = v["fond"]
			var dispo := eau_de(e, fond)
			var q := minf(minf(a, DEBIT * part), dispo)
			if q <= 1e-9:
				e.attente[k] = 0.0
				continue
			var r := q / dispo
			for j in fond:
				e.m[j] -= e.m[j] * r
			e.vide += q; e.attente[k] -= q; actif = true
		if e.attente[k] < 1e-9:
			e.attente[k] = 0.0
	return actif


# --- la boule -------------------------------------------------------------------
var _plafond := false

# La hauteur d'eau sous (ou sur) la boule, en cases ; NAN : pas d'eau.
func niveau(e: Etat, x: float, y: float) -> float:
	_plafond = false
	var cx := floori(x * S)
	var cy := mini(SH - 1, maxi(0, floori(y * S)))
	if not fouvert(cx, cy):
		return NAN
	if e.m[cy * SW + cx] > SECHE:
		while e.m[cy * SW + cx] >= PLEINE and fouvert(cx, cy + 1) and e.m[(cy + 1) * SW + cx] > SECHE:
			cy += 1
		if e.m[cy * SW + cx] >= PLEINE and not fouvert(cx, cy + 1):
			_plafond = true
			return float(cy + 1) / S
		return (cy + minf(1.0, e.m[cy * SW + cx])) / S
	while cy > 0 and fouvert(cx, cy - 1) and e.m[(cy - 1) * SW + cx] <= SECHE:
		cy -= 1
	if cy == 0 or not fouvert(cx, cy - 1):
		return NAN
	return (cy - 1 + minf(1.0, e.m[(cy - 1) * SW + cx])) / S


func _vitesse(e: Etat, fxc: int, y0: float, y1: float) -> float:
	var q := 0.0
	var mouille := 0.0
	for fy in range(maxi(0, floori(y0 * S)), mini(SH, ceili(y1 * S))):
		if not fouvert(fxc, fy) or not fouvert(fxc + 1, fy):
			continue
		var i := fy * SW + fxc
		q += e.fx[i]
		mouille += minf(1.0, (e.m[i] + e.m[i + 1]) / 2.0)
	return q / (S * mouille) if mouille > 0.25 else 0.0


func _contacts(e: Etat) -> void:
	for passe in 2:
		for cy in range(floori(e.by - RAYON), floori(e.by + RAYON) + 1):
			for cx in range(floori(e.bx - RAYON), floori(e.bx + RAYON) + 1):
				if ouvert(cx, cy):
					continue
				var px := maxf(cx, minf(cx + 1, e.bx))
				var py := maxf(cy, minf(cy + 1, e.by))
				var nx := e.bx - px
				var ny := e.by - py
				var d := sqrt(nx * nx + ny * ny)
				if d >= RAYON:
					continue
				if d < 1e-9:
					# le plus proche des quatre côtés, le premier à égalité (le tri stable de la page)
					var cotes := [[e.bx - cx, -1.0, 0.0], [cx + 1 - e.bx, 1.0, 0.0], [e.by - cy, 0.0, -1.0], [cy + 1 - e.by, 0.0, 1.0]]
					var c: Array = cotes[0]
					for t in range(1, 4):
						if cotes[t][0] < c[0]:
							c = cotes[t]
					nx = c[1]; ny = c[2]
					e.bx += nx * (c[0] + RAYON); e.by += ny * (c[0] + RAYON)
				else:
					nx /= d; ny /= d
					e.bx += nx * (RAYON - d); e.by += ny * (RAYON - d)
				var vn := e.bvx * nx + e.bvy * ny
				if vn < 0.0:
					e.bvx -= vn * nx; e.bvy -= vn * ny


func _puissance(x: float, dt: float) -> float:
	if dt == 1.0: return x
	if dt == 0.5: return sqrt(x)
	if dt == 0.25: return sqrt(sqrt(x))
	push_error("finesse non prise en charge : %s (1, 2 ou 4)" % (1.0 / dt))
	return x


func bouger(e: Etat, dt: float) -> void:
	if e.gagne:
		e.by += 0.05 * dt
		return
	var h := niveau(e, e.bx, e.by)
	var plafond := _plafond
	if not is_nan(h) and h > e.by - RAYON:
		var cible := h - RAYON if plafond else h + FLOTTE
		e.bvy += (cible - e.by) * RESSORT * dt
		e.bvy *= _puissance(AMORTI, dt)
		var y0 := e.by - RAYON - 1.0 / S
		var y1 := minf(e.by + RAYON, h)
		var u := 0.0
		for fxc in range(floori((e.bx - ATTIRE) * S), floori((e.bx + ATTIRE) * S) + 1):
			if fxc < 0 or fxc + 1 >= SW:
				continue
			var v := _vitesse(e, fxc, y0, y1)
			if absf(v) > absf(u):
				u = v
		e.bvx += (u * PORTE - e.bvx) * (1.0 - _puissance(1.0 - SUIT, dt))
	else:
		e.bvy = maxf(-CHUTE_MAX, e.bvy - PESANTEUR * dt)
		e.bvx *= _puissance(FROTTE, dt)
	if absf(e.bvx) > 0.25:
		e.bvx = signf(e.bvx) * 0.25
	e.bx += e.bvx * dt
	e.by += e.bvy * dt
	_contacts(e)
	var cx := floori(e.bx)
	var cy := floori(e.by)
	if cx >= 0 and cy >= 0 and cx < W and cy < H and sortie[cy * W + cx]:
		e.gagne = true


# --- le jeu ---------------------------------------------------------------------
func pas(e: Etat) -> float:
	e.fx.fill(0.0); e.fy.fill(0.0)
	var actif := false
	var flux := 0.0
	for k in S:
		if _vannes(e): actif = true
		flux += _eau(e)
	flux /= S2
	for k in S:
		bouger(e, 1.0 / S)
	var vite := absf(e.bvx) + absf(e.bvy)
	if not actif and flux < CALME and vite < 1e-3: e.calme += 1
	else: e.calme = 0
	e.pas += 1
	return flux


func repos(e: Etat) -> bool:
	return e.calme >= CALME_PAS or e.gagne


# Une tape : une unité de plus à verser ou à vider. null si elle ne peut rien.
func taper(e0: Etat, k: int) -> Etat:
	var v: Dictionary = vannes[k]
	if e0.gagne:
		return null
	if v["type"] == "vidange" and eau_de(e0, v["bloc"]) < SEC and e0.attente[k] <= 0.0:
		return null
	var e := e0.copie()
	e.attente[k] += UNITE
	e.tapes += 1
	e.calme = 0
	return e


func reposer(e: Etat) -> Etat:
	var n := 0
	while not repos(e):
		if n > MAXPAS:
			push_error("l'eau ne se pose pas en %d pas" % MAXPAS)
			return e
		pas(e)
		n += 1
	return e


func jouer(e: Etat, k: int) -> Etat:
	var t := taper(e, k)
	return reposer(t) if t != null else null
