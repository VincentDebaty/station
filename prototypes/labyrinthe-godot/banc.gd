extends SceneTree
# ------------------------------------------------------------------
# LE BANC D'ESSAI DU LABYRINTHE D'EAU — sans écran, il REFUSE au lieu d'avertir.
#
#   godot --headless --path prototypes/labyrinthe-godot --script res://banc.gd
#   (LABY_PARTIES=60 LABY_GRAINE=900 pour une autre batterie au hasard)
#
# Godot fait autorité sur les règles depuis le 14 octobre 2026 : ce banc
# remplace tools/labyrinthe-banc.mjs, qui gardait la page web. Il joue
# moteur.gd « au repos » (une tape, puis l'eau et la boule se posent).
#
# LES DONNÉES — un niveau mal écrit, avant même de le jouer :
#   D1  une grille rectangulaire, des caractères connus, une boule, une
#       sortie au bord, une vanne par chiffre et un type connu par vanne
#   D2  au chargement rien ne coule et la boule ne bouge plus
# LA SOLUTION :
#   S1  la « solution » écrite sort la boule
#   S2  sa longueur est le « par », et aucune suite plus courte ne gagne parmi
#       celles de deux séries au plus (une série = la même vanne tapée
#       plusieurs fois d'affilée)
#   S3  chaque suite de « pieges » NE sort PAS la boule
# LES INVARIANTS — à chaque image de parties au hasard :
#   I1  l'eau se compte : dans les bassins = départ + versé − sorti − vidé, à 1e-9
#   I2  aucun volume négatif, aucun NaN ; la surface à ressorts garde sa
#       moyenne : dans chaque bassin libre, la moyenne des vagues est nulle
#   I3  la même suite de tapes donne le même état (déterminisme)
#   I4  la boule reste dans une case ouverte
#   I5  l'eau se pose : chaque tape finit au repos
# LES MESURES — en information :
#   M1  la butte : le plus grand écart de niveau entre bassins liés (une même
#       nappe) pendant 10 unités versées en continu, en cases — hors de la
#       bouche du robinet, où l'eau est plus haute puisqu'elle en sort
#   M2  un tube en U, une colonne pleine, l'autre vide : images pour se mettre
#       de niveau (écart < 0,05 case)
#   M3  le repos : images entre une tape et le repos, sur la solution
#   M4  le coût : millisecondes par image, en moyenne et au plus
# ------------------------------------------------------------------

const TAPES := 30
const SERIES := 2

var echecs := 0
var N: Dictionary
var M: Moteur


func dire(ok: bool, texte: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + texte)
	if not ok:
		echecs += 1


func lire(s: String) -> PackedInt32Array:
	var r := PackedInt32Array()
	for c in s:
		r.append(int(c) - 1)
	return r


func compact(s: PackedInt32Array) -> String:
	var morceaux := []
	var i := 0
	while i < s.size():
		var j := i
		while j < s.size() and s[j] == s[i]:
			j += 1
		morceaux.append("%d×%d" % [s[i] + 1, j - i])
		i = j
	return ", ".join(morceaux)


func _init() -> void:
	var parties := int(OS.get_environment("LABY_PARTIES")) if OS.get_environment("LABY_PARTIES") != "" else 30
	var graine := int(OS.get_environment("LABY_GRAINE")) if OS.get_environment("LABY_GRAINE") != "" else 1
	N = JSON.parse_string(FileAccess.get_file_as_string("res://niveau.json"))
	print("Labyrinthe d'eau — « %s », %d parties au hasard, graines %d…%d" % [N["titre"], parties, graine, graine + parties - 1])
	var d := donnees()
	if d.is_empty():
		M = Moteur.new(N)
		var e := M.charger()
		var x := e.bx
		var y := e.by
		var flux := 0.0
		for k in 200:
			flux += M.pas(e)
		if flux > 1e-6: d.append("D2 l'eau coule au chargement (%f)" % flux)
		if Vector2(e.bx - x, e.by - y).length() > 1e-3: d.append("D2 la boule bouge au chargement")
	dire(d.is_empty(), "D1-D2 données" + ("" if d.is_empty() else " :\n      " + "\n      ".join(d)))
	if not d.is_empty():
		quit(1)
		return

	# S1-S3
	var sol := lire(N["solution"])
	dire(jouer_suite(sol).gagne, "S1 la solution écrite sort la boule : " + compact(sol))
	var t0 := Time.get_ticks_msec()
	_meilleure = PackedInt32Array()
	_noeuds = 0
	_limite = sol.size()
	_dfs(M.charger(), PackedInt32Array(), 0, -1)
	var plus_courte := _meilleure
	dire(sol.size() == int(N["par"]) and plus_courte.is_empty(), "S2 par %d = solution %d" % [int(N["par"]), sol.size()] +
		(" — mais %s gagne en %d" % [compact(plus_courte), plus_courte.size()] if not plus_courte.is_empty() else ", rien de plus court en %d séries (%d suites, %d ms)" % [SERIES, _noeuds, Time.get_ticks_msec() - t0]))
	for p in N.get("pieges", []):
		dire(not jouer_suite(lire(p)).gagne, "S3 le piège %s ne sort pas la boule" % compact(lire(p)))

	# I1-I5 sur des parties au hasard
	var viol: Array[String] = []
	var gagnees := 0
	for p in parties:
		var h := Hasard.new(graine + p)
		var e := M.charger()
		var suite := PackedInt32Array()
		var depart := M.eau_totale(e)
		for t in TAPES:
			if e.gagne or viol.size() > 0:
				break
			var k := int(h.suivant() * M.vannes.size())
			var r := M.taper(e, k)
			if r == null:
				continue
			var n := 0
			while not M.repos(r):
				if n > Moteur.MAXPAS:
					viol.append("I5 partie %d, tape %d : pas de repos" % [graine + p, t + 1]); break
				M.pas(r); n += 1
				var v := invariants(r, depart, "partie %d, tape %d (vanne %d)" % [graine + p, t + 1, k + 1])
				if v != "":
					viol.append(v); break
			e = r
			suite.append(k)
		if viol.is_empty():
			var bis := jouer_suite(suite)
			if bis.vol != e.vol or bis.bx != e.bx or bis.by != e.by or bis.vague != e.vague:
				viol.append("I3 partie %d : la même suite donne un autre état" % (graine + p))
		if e.gagne: gagnees += 1
		if viol.size() > 0:
			break
	dire(viol.is_empty(), "I1-I5 invariants à chaque image de %d parties de %d tapes" % [parties, TAPES] + ("" if viol.is_empty() else " :\n      " + viol[0]))
	print("    au hasard : %d %% des parties sortent la boule" % roundi(100.0 * gagnees / parties))
	mesures(sol)
	print("\n%d échec(s)." % echecs if echecs else "\nTout est vert.")
	quit(1 if echecs else 0)


func donnees() -> Array[String]:
	var v: Array[String] = []
	var g: Array = N.get("grille", [])
	if g.is_empty():
		return ["grille vide"]
	var W := String(g[0]).length()
	var H := g.size()
	var boules := 0
	var sorties := 0
	var chiffres := {}
	for ry in H:
		var r := String(g[ry])
		if r.length() != W:
			return ["grille pas rectangulaire"]
		for x in W:
			var ch := r[x]
			if not "#.So~123456789".contains(ch): v.append("caractère inconnu « %s » en %d,%d" % [ch, x, H - 1 - ry])
			if ch == "o": boules += 1
			if ch == "S":
				sorties += 1
				if not (x == 0 or x == W - 1 or ry == 0 or ry == H - 1): v.append("sortie %d,%d hors du bord" % [x, H - 1 - ry])
			if ch >= "1" and ch <= "9":
				if chiffres.has(ch): v.append("vanne %s en double" % ch)
				chiffres[ch] = true
	if boules != 1: v.append("%d boule(s), il en faut une" % boules)
	if sorties == 0: v.append("aucune sortie")
	var n: int = N.get("vannes", []).size()
	if chiffres.size() != n: v.append("%d chiffres dans la grille pour %d vannes" % [chiffres.size(), n])
	for k in n:
		if not chiffres.has(str(k + 1)): v.append("vanne %d absente de la grille" % (k + 1))
		if not ["robinet", "vidange"].has(N["vannes"][k]["type"]): v.append("vanne %d : type inconnu" % (k + 1))
	return v


func invariants(e: Moteur.Etat, depart: float, ou: String) -> String:
	var total := 0.0
	for a in M.nb:
		var v := e.vol[a]
		if is_nan(v) or v < -1e-9:
			return "I2 %s : bassin %d à %f" % [ou, a, v]
		total += v
	var attendu := depart + e.verse - e.sorti - e.vide
	if absf(total - attendu) > 1e-9:
		return "I1 %s : %.12f d'eau, attendu %.12f" % [ou, total, attendu]
	for a in M.nb:
		if not M.libre(e, a):
			continue
		var m := 0.0
		for p in Moteur.POINTS:
			m += e.vague[a * Moteur.POINTS + p]
		if absf(m) > 1e-9:
			return "I2 %s : la surface du bassin %d a une moyenne de %f" % [ou, a, m / Moteur.POINTS]
	if not e.gagne and not M.ouvert(floori(e.bx), floori(e.by)):
		return "I4 %s : boule en %.2f,%.2f" % [ou, e.bx, e.by]
	return ""


func jouer_suite(s: PackedInt32Array) -> Moteur.Etat:
	var e := M.charger()
	for k in s:
		var r := M.jouer(e, k)
		if r != null:
			e = r
		if e.gagne:
			break
	return e


# S2 : fouille en profondeur, au plus SERIES séries, coupée à la longueur de la solution.
var _meilleure := PackedInt32Array()
var _noeuds := 0
var _limite := 0

func _dfs(e: Moteur.Etat, suite: PackedInt32Array, series: int, dernier: int) -> void:
	var borne := _meilleure.size() if not _meilleure.is_empty() else _limite
	if suite.size() >= borne - 1:
		return
	for k in M.vannes.size():
		var nouvelle := k != dernier
		if nouvelle and series >= SERIES:
			continue
		var e2 := M.jouer(e, k)
		_noeuds += 1
		if e2 == null:
			continue
		var s2 := suite.duplicate()
		s2.append(k)
		if e2.gagne:
			_meilleure = s2
			continue
		_dfs(e2, s2, series + (1 if nouvelle else 0), k)


func mesures(sol: PackedInt32Array) -> void:
	# M1 : les vidanges de la solution, puis 10 unités en appui long
	var e := M.charger()
	var rob := -1
	for k in M.vannes.size():
		if M.vannes[k]["type"] == "robinet": rob = k
	var i := 0
	while i < sol.size() and sol[i] != rob:
		e = M.jouer(e, sol[i]); i += 1
	var bouche: int = M.vannes[rob]["bassin"]      # la bouche du robinet : l'eau y est plus haute puisqu'elle en sort
	var verse := 0
	var butte := 0.0
	var apres := 0
	var t0 := Time.get_ticks_usec()
	var images := 0
	var pire := 0
	for im in 4000:
		if apres >= 60: break
		if verse < 10 and e.attente[rob] < 0.05:
			e = M.taper(e, rob); verse += 1
		var t1 := Time.get_ticks_usec()
		M.pas(e)
		pire = maxi(pire, Time.get_ticks_usec() - t1)
		images += 1
		for o in M.o_a.size():
			if M.lies(e, o) and M.o_a[o] != bouche and M.o_b[o] != bouche:
				butte = maxf(butte, absf(M.niveau_bassin(e, M.o_a[o]) - M.niveau_bassin(e, M.o_b[o])))
		if verse >= 10 and e.attente[rob] == 0.0: apres += 1
	var moyenne := (Time.get_ticks_usec() - t0) / 1000.0 / images
	print("    M1 butte : écart de niveau maximal %.3f case entre bassins d'une même nappe, pendant 10 unités versées en continu" % butte)
	# M2 : le tube en U
	var U := {"titre": "tube en U", "grille": ["#######", "#.###o#", "#.###.#", "#.###.#", "#.###.#", "#.###.#", "#.....#", "#######"], "vannes": [], "eau": 0}
	var MU := Moteur.new(U)
	var eu := MU.charger()
	eu.vol[MU.bassin_de[5 * MU.W + 1]] = 4.0         # la colonne de gauche pleine jusqu'à la rangée 5
	var n := 0
	while n < 3000 and absf(MU.charge(eu, MU.bassin_de[2 * MU.W + 1]) - MU.charge(eu, MU.bassin_de[2 * MU.W + 5])) >= 0.05:
		MU.pas(eu); n += 1
	print("    M2 tube en U : %s pour se mettre de niveau (écart < 0,05 case)" % ("%d images" % n if n < 3000 else "pas de niveau en 3000 images"))
	# M3 : le repos
	var es := M.charger()
	var durees := PackedInt32Array()
	for k in sol:
		var avant := es.pas
		var r := M.jouer(es, k)
		if r == null: continue
		es = r
		durees.append(es.pas - avant)
		if es.gagne: break
	var somme := 0
	var plus := 0
	for x in durees:
		somme += x; plus = maxi(plus, x)
	print("    M3 repos : %d images en moyenne entre une tape et le repos, %d au plus" % [roundi(float(somme) / maxi(1, durees.size())), plus])
	print("    M4 coût : %.3f ms par image en moyenne, %.3f ms au plus (GDScript, cette machine)" % [moyenne, pire / 1000.0])


class Hasard:                       # le tirage du banc web (mulberry32), pour garder les mêmes parties
	var a: int
	func _init(graine: int) -> void:
		a = graine if graine != 0 else 1
	func suivant() -> float:
		a = (a + 0x6D2B79F5) & 0xFFFFFFFF
		var t := _mul(a ^ (a >> 15), 1 | a)
		t = ((t + _mul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
	func _mul(x: int, y: int) -> int:
		return (x * y) & 0xFFFFFFFF
