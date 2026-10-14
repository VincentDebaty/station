class_name Moteur
extends RefCounted
# ------------------------------------------------------------------
# LE MOTEUR DU LABYRINTHE D'EAU — l'eau par volumes, la surface à ressorts.
#
# Godot fait autorité sur les règles depuis le 14 octobre 2026 (décision de
# Vincent) ; la page web prototypes/prototype-labyrinthe.html reste figée
# comme trace. banc.gd vérifie ce moteur sans écran.
#
# L'EAU PAR VOLUMES. Le labyrinthe est découpé une fois pour toutes en
# BASSINS : chaque colonne d'eau d'un seul tenant (une case de large, de son
# plancher à son plafond). Un bassin a un volume, une capacité, et une CHARGE :
# la hauteur de sa surface libre, ou, plein sous un plafond, une hauteur de
# pression (une petite compressibilité : un surplus de volume la fait monter
# vite, ce qui pousse l'eau à travers les passages noyés en conservant
# exactement le volume). Deux bassins voisins sont reliés par l'ouverture
# qu'ils ont en commun. À travers elle, l'eau passe du côté le plus chargé
# vers l'autre, d'un débit
#       q = DEBIT_OUVERTURE × hauteur mouillée × √(différence de charge)
# — Torricelli : fort quand l'écart est grand, il ralentit à l'approche de
# l'équilibre. Si le bassin d'arrivée est plus bas que l'ouverture, c'est une
# CASCADE : l'eau tombe, sans que le niveau d'arrivée la freine. Une sortie
# avale ce qui la passe. Les calculs se font en sous-pas fixes (SOUS_PAS par
# image), sans dépendre de la cadence d'affichage.
#
# LA SURFACE À RESSORTS. Chaque bassin à surface libre porte POINTS points
# par case : une hauteur et une vitesse autour du niveau, un rappel, une
# propagation aux voisins (aussi à travers une ouverture vers le bassin voisin,
# quand la surface y passe), un amortissement. La moyenne des écarts d'un
# bassin est ramenée à zéro : la surface moyenne est TOUJOURS le niveau du
# volume réel. Les cascades, les vidanges et la boule y lancent des vagues.
# Tout est déterministe (+ − × /, racine carrée) : le banc rejoue à l'identique.
#
# LA BOULE flotte sur la surface locale (niveau + vague), bute sous un
# plafond, et prend la vitesse de l'eau qui passe les ouvertures près d'elle.
# ------------------------------------------------------------------

# ---- l'eau (en cases ; une image = 1/60 s) ----
const SOUS_PAS := 4
const DEBIT := 0.1              # ce qu'un robinet verse, ou qu'une vidange retire, par image
const SEC := 0.05               # sous cette eau, une vidange refuse la tape
const UNITE := 1.0              # une tape = une case d'eau
const DEBIT_OUVERTURE := 0.1    # q (cases²/image) = ce coefficient × hauteur mouillée × √écart
const RAIDEUR := 30.0           # un bassin plein sous un plafond : charge = plafond + RAIDEUR × surplus
const PRUDENCE := 0.5           # un sous-pas ne fait passer que cette part de ce qui égaliserait
const DEBIT_MIN := 0.006        # par image : la dernière pellicule au-dessus d'un seuil finit de passer

# ---- la surface ----
const POINTS := 8               # points de surface par case
const RAPPEL := 0.025           # rappel de chaque point vers le niveau
const AMORTI_SURFACE := 0.04
const PROPAGE := 0.22           # partage avec les voisins, par passe
const PASSES_PROPAGE := 6
const VAGUE_MAX := 0.22         # écart maximal d'un point, en cases
const ELAN_CASCADE := 0.5       # la vitesse donnée à la surface par une case d'eau qui tombe
const ELAN_VIDANGE := 0.25
const ELAN_BOULE := 0.12

# ---- la boule (en cases, par image) ----
const RAYON := 0.34
const FLOTTE := 0.08
const RESSORT := 0.08
const AMORTI := 0.8
const PESANTEUR := 0.02
const CHUTE_MAX := 0.3
const PORTE := 2.5
const SUIT := 0.1
const ATTIRE := 2.2             # la boule sent le courant d'une ouverture jusqu'à cette distance…
const ATTIRE_PLEIN := 1.0       # … pleinement jusqu'à celle-ci, puis de moins en moins
const FROTTE := 0.85

# ---- le repos ----
const CALME := 2e-4
const CALME_PAS := 30
const MAXPAS := 6000


class Etat:
	var vol: PackedFloat64Array       # le volume de chaque bassin
	var flux: PackedFloat64Array      # ce qui a passé chaque ouverture cette image (> 0 : de gauche à droite)
	var sortie_flux: PackedFloat64Array
	var vague: PackedFloat64Array     # l'écart de chaque point de surface
	var vague_v: PackedFloat64Array   # et sa vitesse
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

	func copie() -> Etat:
		var e := Etat.new()
		e.vol = vol.duplicate(); e.flux = flux.duplicate(); e.sortie_flux = sortie_flux.duplicate()
		e.vague = vague.duplicate(); e.vague_v = vague_v.duplicate()
		e.bx = bx; e.by = by; e.bvx = bvx; e.bvy = bvy
		e.attente = attente.duplicate(); e.tapes = tapes; e.verse = verse; e.sorti = sorti; e.vide = vide
		e.gagne = gagne; e.calme = calme; e.pas = pas
		return e


# --- la géométrie : les cases, les bassins, les ouvertures ------------------------
var W: int
var H: int
var mur: PackedByteArray
var sortie: PackedByteArray
var boule0 := Vector2.ZERO
var vannes: Array = []                # [{type, x, y, bassin}]
var b_x: PackedInt32Array             # bassin : sa colonne
var b_bas: PackedInt32Array           # son plancher
var b_haut: PackedInt32Array          # son plafond (première case au-dessus qui n'est pas à lui)
var b_ferme: PackedByteArray          # 1 : un mur au-dessus (il peut monter en pression)
var bassin_de: PackedInt32Array       # le bassin de chaque case, -1 : aucun
var o_a: PackedInt32Array             # ouverture : bassin de gauche
var o_b: PackedInt32Array             # bassin de droite
var o_y0: PackedFloat64Array          # le bas de l'ouverture
var o_y1: PackedFloat64Array          # son haut
var s_bassin: PackedInt32Array        # sortie : le bassin qui s'y vide
var s_y0: PackedFloat64Array          # son seuil
var s_y1: PackedFloat64Array
var s_x: PackedFloat64Array           # la ligne où elle est franchie (pour le courant), ou -1 par le haut
var vol0: PackedFloat64Array
var nb := 0                           # nombre de bassins


func _init(N: Dictionary) -> void:
	var grille: Array = N["grille"]
	H = grille.size(); W = String(grille[0]).length()
	mur = PackedByteArray(); mur.resize(W * H)
	sortie = PackedByteArray(); sortie.resize(W * H)
	var defs: Array = N["vannes"]
	var vv := []
	vv.resize(defs.size())
	for r in H:
		var ligne := String(grille[r])
		for x in W:
			var ch := ligne[x]
			var y := H - 1 - r
			if ch == "#": mur[y * W + x] = 1
			elif ch == "S": sortie[y * W + x] = 1
			elif ch == "o": boule0 = Vector2(x + 0.5, y + 0.5)
			elif ch >= "1" and ch <= "9":
				var k := int(ch) - 1
				vv[k] = {"type": String(defs[k]["type"]), "x": x, "y": y}
	# les bassins : les colonnes de cases ouvertes (hors sorties)
	bassin_de = PackedInt32Array(); bassin_de.resize(W * H); bassin_de.fill(-1)
	b_x = PackedInt32Array(); b_bas = PackedInt32Array(); b_haut = PackedInt32Array(); b_ferme = PackedByteArray()
	for x in W:
		var y := 0
		while y < H:
			if mur[y * W + x] or sortie[y * W + x]:
				y += 1
				continue
			var bas := y
			while y < H and not mur[y * W + x] and not sortie[y * W + x]:
				bassin_de[y * W + x] = b_x.size()
				y += 1
			b_x.append(x); b_bas.append(bas); b_haut.append(y)
			b_ferme.append(1 if y >= H or mur[y * W + x] else 0)
	nb = b_x.size()
	# les ouvertures entre colonnes voisines, et les sorties
	o_a = PackedInt32Array(); o_b = PackedInt32Array(); o_y0 = PackedFloat64Array(); o_y1 = PackedFloat64Array()
	s_bassin = PackedInt32Array(); s_y0 = PackedFloat64Array(); s_y1 = PackedFloat64Array(); s_x = PackedFloat64Array()
	for a in nb:
		for b in nb:
			if b_x[b] != b_x[a] + 1:
				continue
			var y0 := maxi(b_bas[a], b_bas[b])
			var y1 := mini(b_haut[a], b_haut[b])
			if y0 < y1:
				o_a.append(a); o_b.append(b); o_y0.append(y0); o_y1.append(y1)
	for a in nb:
		var x := b_x[a]
		if b_haut[a] < H and sortie[b_haut[a] * W + x]:          # une sortie au-dessus
			s_bassin.append(a); s_y0.append(b_haut[a]); s_y1.append(b_haut[a] + 1); s_x.append(-1.0)
		for y in range(b_bas[a], b_haut[a]):                       # une sortie sur le côté
			for d in [-1, 1]:
				var nx: int = x + d
				if nx >= 0 and nx < W and sortie[y * W + nx]:
					s_bassin.append(a); s_y0.append(y); s_y1.append(y + 1); s_x.append(float(x + (1 if d > 0 else 0)))
	for v in vv:
		v["bassin"] = bassin_de[int(v["y"]) * W + int(v["x"])]
	vannes = vv
	# l'eau de départ : jusqu'à la rangée « eau »
	vol0 = PackedFloat64Array(); vol0.resize(nb)
	var niv := float(N.get("eau", 0))
	for a in nb:
		vol0[a] = clampf(niv - b_bas[a], 0.0, float(b_haut[a] - b_bas[a]))


func ouvert(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and not mur[y * W + x]

func capacite(a: int) -> float:
	return float(b_haut[a] - b_bas[a])


# La charge d'un bassin : sa surface libre, ou sa pression sous un plafond.
func charge(e: Etat, a: int) -> float:
	var v := e.vol[a]
	var cap := capacite(a)
	if v <= cap:
		return b_bas[a] + v
	if b_ferme[a]:
		return b_haut[a] + (v - cap) * RAIDEUR
	return b_haut[a] + (v - cap)

# De combien la charge monte pour un peu de volume en plus.
func souplesse(e: Etat, a: int) -> float:
	return RAIDEUR if b_ferme[a] and e.vol[a] >= capacite(a) else 1.0

# Le bassin a-t-il une surface libre (de l'eau, de l'air au-dessus) ?
func libre(e: Etat, a: int) -> bool:
	return e.vol[a] > 0.02 and not (b_ferme[a] and e.vol[a] >= capacite(a) - 1e-6)

# Le niveau affiché d'un bassin (borné à son plafond).
func niveau_bassin(e: Etat, a: int) -> float:
	return minf(b_bas[a] + e.vol[a], float(b_haut[a]))


func charger() -> Etat:
	var e := Etat.new()
	e.vol = vol0.duplicate()
	e.flux = PackedFloat64Array(); e.flux.resize(o_a.size())
	e.sortie_flux = PackedFloat64Array(); e.sortie_flux.resize(s_bassin.size())
	e.vague = PackedFloat64Array(); e.vague.resize(nb * POINTS)
	e.vague_v = PackedFloat64Array(); e.vague_v.resize(nb * POINTS)
	e.bx = boule0.x; e.by = boule0.y
	e.attente = PackedFloat64Array(); e.attente.resize(vannes.size())
	for k in 400:
		_bouger(e, 1.0)
	e.bvx = 0.0; e.bvy = 0.0
	return e


func eau_totale(e: Etat) -> float:
	var s := 0.0
	for a in nb:
		s += e.vol[a]
	return s


# --- l'écoulement -------------------------------------------------------------------
# Ce qui passe en un sous-pas d'un bassin (charge hs) vers l'autre (charge hd,
# souplesse cd ; cd = 0 pour une sortie ou une cascade) à travers [y0, y1).
func _debit(hs: float, cs: float, hd: float, cd: float, y0: float, y1: float, dt: float) -> float:
	if hs <= y0:
		return 0.0
	var base := maxf(hd, y0)
	var ecart := hs - base
	if ecart <= 0.0:
		return 0.0
	var mouille := minf(hs, y1) - y0
	var q := maxf(DEBIT_OUVERTURE * mouille * sqrt(ecart) * dt, DEBIT_MIN * dt)
	var c := cs + (cd if hd >= y0 else 0.0)
	return minf(q, PRUDENCE * ecart / c)


func _ecouler(e: Etat, dt: float) -> float:
	var total := 0.0
	for o in o_a.size():
		var a := o_a[o]
		var b := o_b[o]
		var ha := charge(e, a)
		var hb := charge(e, b)
		if ha == hb:
			continue
		var q := 0.0
		if ha > hb:
			q = _debit(ha, souplesse(e, a), hb, souplesse(e, b), o_y0[o], o_y1[o], dt)
			q = minf(q, e.vol[a])
			e.vol[a] -= q; e.vol[b] += q; e.flux[o] += q
			if hb < o_y0[o]: _elan(e, b, b_x[b] + portee(e, o, a, b), -ELAN_CASCADE * q)
		else:
			q = _debit(hb, souplesse(e, b), ha, souplesse(e, a), o_y0[o], o_y1[o], dt)
			q = minf(q, e.vol[b])
			e.vol[b] -= q; e.vol[a] += q; e.flux[o] -= q
			if ha < o_y0[o]: _elan(e, a, b_x[a] + 1.0 - portee(e, o, b, a), -ELAN_CASCADE * q)
		total += q
	for s in s_bassin.size():
		var a := s_bassin[s]
		var q := _debit(charge(e, a), souplesse(e, a), s_y0[s], 0.0, s_y0[s], s_y1[s], dt)
		q = minf(q, e.vol[a])
		e.vol[a] -= q; e.sorti += q; e.sortie_flux[s] += q
		total += q
	return total


# La portée d'une cascade de l'ouverture o, de src vers dst, en cases depuis
# la paroi : l'eau sort du seuil à la vitesse de Torricelli (√(2g·charge)) et
# tombe de la hauteur de chute, d'où 2·√(charge × chute). Bornée à la case
# d'arrivée. La vague du bassin d'arrivée part de là, et le rendu y fait
# tomber la nappe.
func portee(e: Etat, o: int, src: int, dst: int) -> float:
	var y0 := o_y0[o]
	var tete := clampf(charge(e, src) - y0, 0.0, o_y1[o] - y0)
	var chute := maxf(0.0, y0 - maxf(charge(e, dst), float(b_bas[dst])))
	return clampf(2.0 * sqrt(tete * chute), 0.06, 0.85)


func _vannes(e: Etat, dt: float) -> bool:
	var actif := false
	for k in vannes.size():
		var v: Dictionary = vannes[k]
		var a: int = v["bassin"]
		var reste := e.attente[k]
		if reste <= 0.0:
			continue
		if v["type"] == "robinet":
			var q := minf(reste, DEBIT * dt)
			e.vol[a] += q; e.verse += q; e.attente[k] -= q; actif = true
		else:
			# la vidange prend l'eau qui couvre sa case
			var dispo := clampf(charge(e, a) - float(v["y"]), 0.0, 1.0)
			dispo = minf(dispo, e.vol[a])
			var q := minf(minf(reste, DEBIT * dt), dispo)
			if q <= 1e-9:
				e.attente[k] = 0.0
				continue
			e.vol[a] -= q; e.vide += q; e.attente[k] -= q; actif = true
			_elan(e, a, float(v["x"]) + 0.5, -ELAN_VIDANGE * q)
		if e.attente[k] < 1e-9:
			e.attente[k] = 0.0
	return actif


# --- la surface à ressorts ------------------------------------------------------------
# Deux bassins voisins partagent leur surface si elle passe dans leur ouverture.
func lies(e: Etat, o: int) -> bool:
	var a := o_a[o]
	var b := o_b[o]
	if not libre(e, a) or not libre(e, b):
		return false
	var la := niveau_bassin(e, a)
	var lb := niveau_bassin(e, b)
	return minf(la, lb) > o_y0[o] and maxf(la, lb) < o_y1[o]

# Un coup sur la surface d'un bassin, près de x.
func _elan(e: Etat, a: int, x: float, dv: float) -> void:
	if not libre(e, a):
		return
	var p := clampi(floori((x - b_x[a]) * POINTS), 0, POINTS - 1)
	var i := a * POINTS + p
	e.vague_v[i] += dv
	if p > 0: e.vague_v[i - 1] += dv * 0.5
	if p < POINTS - 1: e.vague_v[i + 1] += dv * 0.5


func _surface(e: Etat) -> void:
	# les voisins de chaque point : dans le bassin, ou à travers une ouverture liée
	var gauche := PackedInt32Array(); gauche.resize(nb); gauche.fill(-1)
	var droite := PackedInt32Array(); droite.resize(nb); droite.fill(-1)
	for o in o_a.size():
		if lies(e, o):
			droite[o_a[o]] = o_b[o]; gauche[o_b[o]] = o_a[o]
	# ressorts : rappel et amortissement
	for a in nb:
		var base := a * POINTS
		if not libre(e, a):
			for p in POINTS:
				e.vague[base + p] = 0.0; e.vague_v[base + p] = 0.0
			continue
		for p in POINTS:
			var i := base + p
			e.vague_v[i] += -RAPPEL * e.vague[i] - AMORTI_SURFACE * e.vague_v[i]
			e.vague[i] += e.vague_v[i]
	# propagation, en quelques passes, sur des écarts gelés à chaque passe
	var delta := PackedFloat64Array(); delta.resize(nb * POINTS)
	for passe in PASSES_PROPAGE:
		delta.fill(0.0)
		for a in nb:
			if not libre(e, a):
				continue
			var base := a * POINTS
			for p in POINTS:
				var i := base + p
				var j := -1
				if p > 0: j = i - 1
				elif gauche[a] >= 0: j = gauche[a] * POINTS + POINTS - 1
				if j >= 0: delta[i] += PROPAGE * (e.vague[j] - e.vague[i])
				j = -1
				if p < POINTS - 1: j = i + 1
				elif droite[a] >= 0: j = droite[a] * POINTS
				if j >= 0: delta[i] += PROPAGE * (e.vague[j] - e.vague[i])
		for i in nb * POINTS:
			e.vague[i] += delta[i] * 0.5
	# la moyenne d'un bassin reste son niveau ; les écarts restent bornés
	for a in nb:
		if not libre(e, a):
			continue
		var base := a * POINTS
		var m := 0.0
		for p in POINTS:
			e.vague[base + p] = clampf(e.vague[base + p], -VAGUE_MAX, VAGUE_MAX)
			m += e.vague[base + p]
		m /= POINTS
		for p in POINTS:
			e.vague[base + p] -= m


# Le niveau de repos à l'abscisse x d'un bassin : son niveau au milieu,
# rejoignant en pente douce celui d'un voisin lié (sinon à plat).
func repos_surface(e: Etat, a: int, x: float, gauche: int, droite: int) -> float:
	var la := niveau_bassin(e, a)
	var t := x - b_x[a]
	if t < 0.5 and gauche >= 0:
		var lb := (niveau_bassin(e, gauche) + la) * 0.5
		return lb + (la - lb) * (t / 0.5)
	if t > 0.5 and droite >= 0:
		var lb := (niveau_bassin(e, droite) + la) * 0.5
		return la + (lb - la) * ((t - 0.5) / 0.5)
	return la

# La surface vraie à l'abscisse x d'un bassin libre : repos + vague.
func surface_en(e: Etat, a: int, x: float) -> float:
	var g := -1
	var d := -1
	for o in o_a.size():
		if o_b[o] == a and lies(e, o): g = o_a[o]
		if o_a[o] == a and lies(e, o): d = o_b[o]
	var p := clampf((x - b_x[a]) * POINTS - 0.5, 0.0, POINTS - 1.0)
	var p0 := floori(p)
	var p1 := mini(p0 + 1, POINTS - 1)
	var f := p - p0
	var v := e.vague[a * POINTS + p0] * (1.0 - f) + e.vague[a * POINTS + p1] * f
	return repos_surface(e, a, x, g, d) + v


# --- la boule ---------------------------------------------------------------------
var _plafond := false

# L'eau sous (ou sur) la boule, en cases ; NAN : pas d'eau dans sa colonne.
func niveau(e: Etat, x: float, y: float) -> float:
	_plafond = false
	var cx := floori(x)
	var cy := floori(y)
	if cx < 0 or cy < 0 or cx >= W or cy >= H:
		return NAN
	var a := bassin_de[cy * W + cx]
	if a < 0 or e.vol[a] <= 0.02:
		return NAN
	if not libre(e, a):
		_plafond = true
		return float(b_haut[a])
	return surface_en(e, a, x)

# La vitesse de l'eau à travers les ouvertures proches de la boule, dans la
# bande où elle trempe : le débit de l'image sur la hauteur mouillée, pesé
# par la distance (plein jusqu'à ATTIRE_PLEIN, nul à ATTIRE) — une boule près
# d'une sortie d'eau y est aspirée. On garde le courant le plus fort.
func _poids(d: float) -> float:
	if d <= ATTIRE_PLEIN:
		return 1.0
	return clampf((ATTIRE - d) / (ATTIRE - ATTIRE_PLEIN), 0.0, 1.0)

func _courant(e: Etat, y0: float, y1: float) -> float:
	var u := 0.0
	for o in o_a.size():
		var w := _poids(absf(float(b_x[o_b[o]]) - e.bx))
		if w <= 0.0 or o_y1[o] <= y0 or o_y0[o] >= y1:
			continue
		var hs := maxf(charge(e, o_a[o]), charge(e, o_b[o]))
		var mouille := minf(hs, o_y1[o]) - o_y0[o]
		if mouille <= 0.05:
			continue
		var v := w * e.flux[o] / mouille
		if absf(v) > absf(u):
			u = v
	for s in s_bassin.size():
		if s_x[s] < 0.0:
			continue
		var w := _poids(absf(s_x[s] - e.bx))
		if w <= 0.0 or s_y1[s] <= y0 or s_y0[s] >= y1:
			continue
		var mouille := minf(charge(e, s_bassin[s]), s_y1[s]) - s_y0[s]
		if mouille <= 0.05:
			continue
		var v := w * e.sortie_flux[s] / mouille
		u = v if absf(v) > absf(u) else u
	return u


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
	push_error("sous-pas non pris en charge : %s (1, 2 ou 4)" % (1.0 / dt))
	return x


func _bouger(e: Etat, dt: float) -> void:
	if e.gagne:
		e.by += 0.05 * dt
		return
	var h := niveau(e, e.bx, e.by)
	var plafond := _plafond
	var vy_avant := e.bvy
	if not is_nan(h) and h > e.by - RAYON:
		var cible := h - RAYON if plafond else h + FLOTTE
		e.bvy += (cible - e.by) * RESSORT * dt
		e.bvy *= _puissance(AMORTI, dt)
		var u := _courant(e, e.by - RAYON - 0.25, minf(e.by + RAYON, h))
		e.bvx += (u * PORTE - e.bvx) * (1.0 - _puissance(1.0 - SUIT, dt))
		# la boule pousse l'eau qu'elle fend : une vague à son passage
		var a := bassin_de[floori(e.by) * W + floori(e.bx)] if ouvert(floori(e.bx), floori(e.by)) else -1
		if a >= 0 and not plafond:
			_elan(e, a, e.bx, ELAN_BOULE * (e.bvy - vy_avant) * dt + ELAN_BOULE * 0.2 * absf(e.bvx) * dt)
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
# Un pas de jeu (une image) : SOUS_PAS d'écoulement, la surface, puis la boule.
func pas(e: Etat) -> float:
	e.flux.fill(0.0); e.sortie_flux.fill(0.0)
	var dt := 1.0 / SOUS_PAS
	var actif := false
	var flux := 0.0
	for k in SOUS_PAS:
		if _vannes(e, dt): actif = true
		flux += _ecouler(e, dt)
	_surface(e)
	for k in SOUS_PAS:
		_bouger(e, dt)
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
	if v["type"] == "vidange":
		var a: int = v["bassin"]
		if clampf(charge(e0, a) - float(v["y"]), 0.0, 1.0) < SEC and e0.attente[k] <= 0.0:
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
