extends SceneTree
# ------------------------------------------------------------------
# LE BANC VISUEL — l'eau qu'on DESSINE tient-elle debout ?
#
#   godot --headless --path prototypes/ecluses-godot --fixed-fps 120 --script res://banc-visuel.gd
#   (… --script res://banc-visuel.gd -- --niveau=1-2   pour un autre niveau)
#
# L'oracle vérifie le moteur ; ce banc vérifie le RENDU, sans écran et sans
# regarder. Il joue la meilleure solution du niveau (oracle.json) comme un
# doigt le ferait, et mesure à CHAQUE image la géométrie que le rendu a
# produite : les surfaces, la cascade, les niveaux affichés. Il REFUSE (code
# de sortie 1) dès qu'une règle est violée, en disant laquelle, à quel coup
# et à quel instant.
#
# Il joue la partie à trois cadences — 120, 60 et 30 images/s, celles de
# l'iPhone, d'un film et d'un petit Android — puis une seconde fois à 60 :
#   - à chaque cadence, les règles V1 à V5 et V8 doivent tenir ;
#   - V6 : les trois cadences racontent la même partie (mêmes niveaux, mêmes
#     portes, mêmes bateaux, au même instant de chaque geste) ;
#   - V7 : rejouée, la partie donne exactement les mêmes images (le hasard du
#     rendu part d'une graine fixe par niveau).
#
# Une cadence plus basse s'obtient en accélérant le temps (time_scale) sur une
# image fixe de 1/120 s : 2 = 60 images/s, 4 = 30. --fixed-fps est donc
# obligatoire ; sans lui, les images suivraient l'horloge de la machine.
#
# Les seuils sont en pixels de la coupe (une unité de hauteur = 48 px) et
# viennent de la MESURE du rendu validé par Vincent sur son iPhone (1-2 au
# doigt maintenu, 120 images/s), avec un peu de marge — pas de l'œil. Le
# relevé final imprime le pire écart mesuré de chaque règle : c'est lui qu'on
# regarde avant de toucher un seuil.
#
# Né le 15 octobre 2026 : 110 des 161 commits de la tranche Godot portaient
# sur des défauts de l'eau, trouvés un à un sur film.
# ------------------------------------------------------------------

const BASE := 120                 # la cadence de --fixed-fps
const CADENCES := [120, 60, 30]
# V1 : jusqu'où une surface peut s'écarter de son niveau — la houle (2,6 px
# au plus) et le bouillon au pied d'une cascade ; dans le sillage d'un bateau
# en marche (à moins d'une coque et demie de lui), le creux derrière la poupe
# est voulu et va plus loin
const TOL_SURFACE := 6.5
const TOL_SILLAGE := 22.0
# V3 / V4 : la cascade part de l'eau d'en haut et tombe sur l'eau d'en bas.
# Son pied ne doit pas rester suspendu au-dessus de l'eau (on verrait le jour
# entre les deux) ; il peut finir un peu dessous, la nappe passe derrière
# l'eau du bassin (canal.gd range le jet avant les bateaux et l'eau).
const TOL_DEPART := 3.0
const TOL_SUSPENDU := 3.0
const TOL_ENFONCE := 20.0
# V2 : un niveau ne fait pas d'aller-retour pendant un geste (unités)
const TOL_RETOUR := 0.002
# V6 : écart permis entre deux cadences, au même instant d'un geste (unités)
const TOL_CADENCE := 0.03
# V8 : la vitesse d'une surface, hors sillage (px/s) — l'eau la plus vive du
# 1-2 monte de ~2 unités par seconde au début d'un remplissage
const TOL_VITESSE := 200.0
const RACCORD := 40.0      # eau.gd : la longueur du raccord contre une porte

var niveau := "1-2"
var echecs := []          # [règle, message]
var _p: Node              # la scène du jeu (principal.gd)
var _c                    # le canal (canal.gd) — sans type : le banc se compile
                          # avant les autoloads, et Canal en dépend
var _cadence := 60
var _coup := 0            # le geste en cours (1 = le premier)
var _t_geste := 0.0       # le temps depuis le début du geste
var _t := 0.0
var _trace := []          # [coup, t_geste, niveaux, ouvertures, bateaux]
var _poses := []          # l'eau posée après chaque geste
var _signature := PackedStringArray()
var _sens_niv := {}       # V2 : le sens où va chaque niveau pendant ce geste
var _niv_avant := []
var _agitation := {}      # V6 : l'agitation moyenne de l'eau, par geste [somme, n]
var _avant_y := {}        # V8 : la surface de l'image d'avant, par bassin et colonne
var _pires := {}          # règle -> le pire écart mesuré, pour le relevé
var _vus := {}            # règle -> nombre de mesures faites

class Sonde extends Node:
	var banc
	func _process(dt: float) -> void: banc.mesurer(dt)

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--niveau="): niveau = a.substr(9)
	_courir.call_deferred()

func _courir() -> void:
	print("BANC VISUEL — niveau %s" % niveau)
	var traces := {}
	var poses := {}
	var agitations := {}
	var signatures := {}
	for c in CADENCES:
		var r: Dictionary = await _partie(c)
		if r.is_empty(): return _finir()
		traces[c] = r["trace"]
		poses[c] = r["poses"]
		agitations[c] = r["agitation"]
		signatures[c] = r["signature"]
	var r2: Dictionary = await _partie(60, true)
	if r2.is_empty(): return _finir()
	_comparer_cadences(traces, poses)
	_comparer_agitation(agitations)
	_vu("V7")
	if r2["signature"] != signatures[60]:
		_echec("V7", "partie", "rejouée à 60 images/s, elle ne donne pas les mêmes images", 0)
	_finir()

func _finir() -> void:
	print("")
	for regle in ["V1", "V1s", "V2", "V3", "V4", "V4s", "V5", "V6", "V6a", "V7", "V8"]:
		var n := int(_vus.get(regle, 0))
		# une règle qui n'a rien mesuré ne prouve rien : le banc refuse
		if n == 0 and echecs.is_empty(): _echec(regle, "partie", "aucune mesure : la partie n'a pas été jouée", 0)
		var pire = _pires.get(regle, null)
		print("  %s  %6d mesures%s" % [regle, n, ("   pire écart %.2f" % pire) if pire != null else ""])
	if echecs.is_empty():
		print("\nBANC VISUEL VERT — aucune règle violée.")
		quit(0)
	else:
		var groupes := {}
		var ordre := []
		for e in echecs:
			var cle := "%s|%s|%d|%d" % [e[0], e[1], e[3], e[5]]
			if not groupes.has(cle):
				groupes[cle] = [e, 0, e[4]]
				ordre.append(cle)
			groupes[cle][1] += 1
			groupes[cle][2] = e[4]
		print("\nBANC VISUEL ROUGE — %d défaut(s) :" % ordre.size())
		for cle in ordre:
			var e: Array = groupes[cle][0]
			var n: int = groupes[cle][1]
			var ou := ""
			if int(e[3]) > 0 and float(e[4]) > 0.0:
				ou = "  — coup %d, %d im/s, à %.2f s%s" % [e[3], e[5], e[4], (" (%d images, jusqu'à %.2f s)" % [n, groupes[cle][2]]) if n > 1 else ""]
			elif int(e[3]) > 0:
				ou = "  — coup %d, %d im/s" % [e[3], e[5]]
			print("  %s  %s%s%s" % [e[0], e[1], (" : " + e[2]) if e[2] != "" else "", ou])
		quit(1)

# --- Une partie ------------------------------------------------------------

func _partie(cadence: int, replay := false) -> Dictionary:
	_cadence = cadence
	_coup = 0
	_t = 0.0
	_t_geste = 0.0
	_trace = []
	_poses = []
	_avant_y = {}
	_agitation = {}
	_signature = PackedStringArray()
	# les réglages par défaut, pas ceux que le Mac a gardés (sans les écrire)
	# (par le nœud : le script du banc se compile avant les autoloads)
	var reglages: Node = root.get_node_or_null("Reglages")
	if reglages == null:
		_echec("--", "l'autoload Reglages n'est pas chargé")
		return {}
	for k in reglages.CURSEURS: reglages.valeurs[k] = reglages.CURSEURS[k][1]
	OS.set_environment("ECLUSES_NIVEAU", niveau)
	_p = load("res://principal.tscn").instantiate()
	root.add_child(_p)
	var sonde := Sonde.new()
	sonde.banc = self
	sonde.process_priority = 100000        # après tout le reste : l'image telle qu'elle est dessinée
	root.add_child(sonde)
	await process_frame
	_c = _p.canal
	if _p.N.is_empty() or _p.N["id"] != niveau:
		_echec("--", "niveau %s introuvable" % niveau)
		return {}
	Engine.time_scale = float(BASE) / float(cadence)
	await process_frame
	var dt := root.get_process_delta_time()
	if absf(dt - 1.0 / float(cadence)) > 1e-4:
		_echec("--", "lancer avec --fixed-fps %d (image de %.4f s au lieu de %.4f)" % [BASE, dt, 1.0 / float(cadence)])
		return {}
	var solution := []
	for partie in JSON.parse_string(FileAccess.get_file_as_string("res://oracle.json"))["parties"]:
		if partie["niveau"] == niveau:
			for pas in partie["pas"]:
				if pas["action"] != null: solution.append(pas["action"])
			break
	if not _p._continu:
		_echec("--", "le banc ne sait jouer que les niveaux au doigt maintenu (« continu »)")
		return {}
	for a in solution:
		if a["type"] != "porte":
			_echec("--", "geste %s : le banc ne sait pas encore le jouer" % a["type"])
			return {}
		_coup += 1
		_t_geste = 0.0
		_sens_niv = {}
		_niv_avant = _c.vue_niv.duplicate()
		var ip := int(a["i"])
		_p._tenir(ip)
		var tenu := 0.0
		while tenu < 12.0:
			await process_frame
			tenu += root.get_process_delta_time()
			if (_p._sens[ip] > 0 and _p._ouv[ip] >= 1.0) or (_p._sens[ip] < 0 and _p._ouv[ip] <= 0.0): break
		_p._relacher()
		var attente := 0.0
		while (_p._a_juger or _p.occupe) and attente < 30.0:
			await process_frame
			attente += root.get_process_delta_time()
		if attente >= 30.0:
			_echec("--", "coup %d : l'eau ne se pose pas en 30 s" % _coup)
			return {}
		_poses.append(_p.etat["niv"].duplicate())
	var fin := 0.0
	while not _p.fini and fin < 5.0:
		await process_frame
		fin += root.get_process_delta_time()
	if not _p.fini:
		_echec("--", "à %d images/s, la solution de l'oracle ne gagne pas" % cadence)
	print("  %3d images/s%s : %d coups, %.1f s de jeu, %d images mesurées" % [cadence, " (rejouée)" if replay else "", _coup, _t, _signature.size()])
	var r := {"trace": _trace, "poses": _poses, "agitation": _agitation, "signature": "\n".join(_signature).sha256_text(), "etat": _p.etat.duplicate(true)}
	sonde.queue_free()
	_p.queue_free()
	Engine.time_scale = 1.0
	await process_frame
	return r

# --- Les mesures, à chaque image -------------------------------------------

func mesurer(dt: float) -> void:
	if _c == null or _coup == 0: return
	_t += dt
	_t_geste += dt
	var niv: Array = _c.vue_niv
	var B: Array = _c.N["bassins"]
	var L: Array = _c.N["liaisons"]
	var bx := []
	for k in _c.bateaux.size(): bx.append(float(_c.bat_x[k]))
	_trace.append([_coup, _t_geste, niv.duplicate(), _p._ouv.duplicate(), bx])
	var sig := PackedStringArray()
	for v in niv: sig.append("%.5f" % v)

	# V1 — chaque surface reste près de son niveau. Près d'une porte ouverte,
	# elle peut rejoindre le niveau du voisin (le raccord en pente douce),
	# jamais passer au-dessous du plus bas des deux ni au-dessus du plus haut :
	# ce serait un creux, ou un bloc d'eau.
	for i in _c.eaux.size():
		var e = _c.eaux[i]
		if not e.visible_eau or e.vide(): continue
		var bas: float = e.repos
		var haut: float = e.repos
		var ouvert_g: bool = i > 0 and L[i - 1]["type"] == "porte" and _p._ouv[i - 1] > 0.001
		var ouvert_d: bool = i < L.size() and L[i]["type"] == "porte" and _p._ouv[i] > 0.001
		var x: float = e.x0
		var pas: float = (e.x1 - e.x0) / 48.0
		var ecart := 0.0
		var x_pire := 0.0
		var creux := false
		var ecart_s := 0.0         # dans le sillage
		var en_marche: bool = not _c._depl.is_empty()
		var col := 0
		var vite := 0.0
		var x_vite := 0.0
		while x <= e.x1 + 0.01:
			var y: float = e.hauteur_a(x)
			sig.append("%.2f" % y)
			var b := bas
			var h := haut
			if ouvert_g and x - e.x0 < RACCORD:
				b = maxf(b, _c.eaux[i - 1].repos); h = minf(h, _c.eaux[i - 1].repos)
			if ouvert_d and e.x1 - x < RACCORD:
				b = maxf(b, _c.eaux[i + 1].repos); h = minf(h, _c.eaux[i + 1].repos)
			# (y vers le bas : un creux, c'est y plus grand que le plus bas)
			var d := maxf(y - b, h - y)
			# (pas plus bas que le fond : une eau presque vide se pose au fond)
			if y >= e.fond_y - 0.01: d = 0.0
			var sillage := false
			if en_marche:
				for k in _c.bateaux.size():
					if absf(float(_c.bat_x[k]) - x) < 1.5 * float(_c.bateaux[k].longueur): sillage = true
			# (comparée seulement à l'image juste avant : un bassin vidé puis
			# rempli n'a pas de surface entre les deux)
			var cle: int = i * 1000 + col
			var image := _signature.size()
			if not sillage and _avant_y.has(cle) and _avant_y[cle][0] == image - 1:
				var v := absf(y - float(_avant_y[cle][1])) / dt
				if v > vite: vite = v; x_vite = x
			_avant_y[cle] = [image, y]
			col += 1
			# (clé : le geste, ou le geste + 100 dans le sillage)
			var cle_ag: int = _coup + (100 if sillage else 0)
			var ag: Array = _agitation.get(cle_ag, [0.0, 0])
			_agitation[cle_ag] = [ag[0] + absf(y - e.repos), ag[1] + 1]
			if sillage:
				ecart_s = maxf(ecart_s, d)
			elif d > ecart:
				ecart = d; x_pire = x; creux = y - b > h - y
			x += pas
		_noter("V1", ecart)
		if ecart > TOL_SURFACE:
			_echec("V1", "bassin %d (%s)" % [i, B[i].get("nom", "")], "%s de %.1f px à x = %d" % ["creux" if creux else "bosse", ecart, int(x_pire)])
		_noter("V8", vite)
		if vite > TOL_VITESSE:
			_echec("V8", "bassin %d (%s)" % [i, B[i].get("nom", "")], "la surface saute à %d px/s à x = %d" % [int(vite), int(x_vite)])
		if en_marche:
			_noter("V1s", ecart_s)
			if ecart_s > TOL_SILLAGE:
				_echec("V1", "bassin %d (%s)" % [i, B[i].get("nom", "")], "sillage de %.1f px" % ecart_s)

	# V2 — pendant un geste, un niveau va dans un seul sens
	for i in niv.size():
		var dv: float = niv[i] - float(_niv_avant[i])
		_vu("V2")
		if absf(dv) > TOL_RETOUR:
			var s := signf(dv)
			if _sens_niv.has(i) and _sens_niv[i] != s:
				_echec("V2", "bassin %d" % i, "le niveau repart dans l'autre sens")
			_sens_niv[i] = s
		_niv_avant[i] = niv[i]

	# V3 à V5 — la cascade sous chaque porte
	for g in _c.jets:
		var jt = _c.jets[g]
		var vu: bool = jt.force > 0.03 and jt.fente >= 1.0 and jt.modulate.a > 0.05 and jt.self_modulate.a > 0.05
		sig.append("%.2f,%.2f,%.2f" % [jt.force, jt.origine.y, jt.fente])
		if not vu: continue
		var h: int = g if jt.sens > 0 else g + 1          # le côté haut
		var l: int = g + 1 if jt.sens > 0 else g          # le côté bas
		var s := float(L[g]["seuil"])
		# V5 — l'eau coule de l'eau haute vers l'eau basse, porte ouverte,
		# et seulement s'il reste de l'eau au-dessus du seuil en haut
		_vu("V5")
		if float(niv[h]) < float(niv[l]) - 1e-4:
			_echec("V5", "porte %d" % g, "la cascade coule de l'eau basse vers l'eau haute")
		if _p._ouv[g] <= 0.0:
			_echec("V5", "porte %d" % g, "une cascade sous une porte fermée")
		if float(niv[h]) < s - 1e-4:
			_echec("V5", "porte %d" % g, "une cascade alors que l'eau d'en haut est sous le seuil")
		if jt.noye(): continue
		# V3 — la lame part de l'eau d'en haut : son dessus n'est pas plus haut
		# que la surface d'amont contre la porte (de l'eau sortie de rien)
		var ep: float = jt.fente if jt.plein else jt.fente * (0.7 + 0.3 * jt.force)
		var dessus: float = jt.origine.y - (ep * 0.5 if jt.plein else 0.0)
		var x_amont: float = _c.X(_c.gl[g][0]) if jt.sens > 0 else _c.X(_c.gl[g][1])
		var surf_h: float = _c.eaux[h].hauteur_a(x_amont)
		var d3 := surf_h - dessus
		_noter("V3", d3)
		if d3 > TOL_DEPART:
			_echec("V3", "porte %d" % g, "la cascade part %.1f px au-dessus de l'eau d'en haut" % d3)
		# V4 — elle tombe SUR l'eau d'en bas : son pied n'est ni suspendu
		# au-dessus, ni enfoncé dans l'eau
		var pied: Vector2 = jt.chute()
		if pied.x < _c.eaux[l].x0 or pied.x > _c.eaux[l].x1: continue
		var d4: float = pied.y - _c.eaux[l].hauteur_a(pied.x)
		# (y vers le bas : d4 > 0, le pied est sous la surface)
		_noter("V4", -d4)
		_noter("V4s", d4)
		if -d4 > TOL_SUSPENDU:
			_echec("V4", "porte %d" % g, "le pied de la cascade reste suspendu %.1f px au-dessus de l'eau d'en bas" % -d4)
		if d4 > TOL_ENFONCE:
			_echec("V4", "porte %d" % g, "le pied de la cascade s'enfonce de %.1f px dans l'eau d'en bas" % d4)
	_signature.append(" ".join(sig))

# V6 — les trois cadences racontent la même partie.
#   - Après chaque geste, l'eau posée est la même au millième près : ce que le
#     joueur obtient ne dépend pas de son téléphone.
#   - Pendant le geste, au même instant depuis son début, niveaux, portes et
#     bateaux suivent le même chemin. On tolère un décalage de deux images de
#     la cadence lente : un bateau part à l'image qui suit l'eau posée, et à
#     30 images/s cette image tombe jusqu'à 1/30 s plus tard.
func _comparer_cadences(traces: Dictionary, poses: Dictionary) -> void:
	var ref: Array = traces[BASE]
	for c in traces:
		if c == BASE: continue
		for g in mini(poses[c].size(), poses[BASE].size()):
			var ecart := 0.0
			for i in poses[c][g].size(): ecart = maxf(ecart, absf(float(poses[c][g][i]) - float(poses[BASE][g][i])))
			_noter("V6", ecart)
			if ecart > 1e-3:
				_echec("V6", "eau posée", "à %d images/s, elle diffère de %.4f u de celle à 120" % [c, ecart], g + 1, 0.0, c)
		var fenetre := 2.0 / float(c) + 1e-4
		var j0 := 0
		for m in traces[c]:
			while j0 < ref.size() and (ref[j0][0] < m[0] or (ref[j0][0] == m[0] and ref[j0][1] < m[1] - fenetre)): j0 += 1
			var meilleur := INF
			var quoi := ""
			var j := j0
			while j < ref.size() and ref[j][0] == m[0] and ref[j][1] <= m[1] + fenetre:
				var r: Array = ref[j]
				var ecart := 0.0
				var q := ""
				for i in m[2].size():
					var d := absf(float(m[2][i]) - float(r[2][i]))
					if d > ecart: ecart = d; q = "niveau du bassin %d" % i
				for i in m[3].size():
					var d := absf(float(m[3][i]) - float(r[3][i]))
					if d > ecart: ecart = d; q = "ouverture de la porte %d" % i
				for k in m[4].size():
					var d := absf(float(m[4][k]) - float(r[4][k])) / 64.0
					if d > ecart: ecart = d; q = "bateau %d" % k
				if ecart < meilleur: meilleur = ecart; quoi = q
				j += 1
			if meilleur == INF: continue
			_noter("V6", meilleur)
			if meilleur > TOL_CADENCE:
				_echec("V6", quoi, "à %d images/s, s'écarte de %.3f u de la partie à 120" % [c, meilleur], m[0], m[1], c)

# V6 encore — l'eau n'est pas plus agitée sur un téléphone rapide : par geste,
# l'écart moyen de la surface à son niveau (hors sillage) reste le même à
# toutes les cadences, à 25 % près. Un remous tiré à chaque image battait
# deux fois plus souvent à 120 images/s qu'à 60.
const TOL_AGITATION := 0.25
func _comparer_agitation(agitations: Dictionary) -> void:
	var ref: Dictionary = agitations[BASE]
	for c in agitations:
		if c == BASE: continue
		for g in ref:
			if not agitations[c].has(g): continue
			var a: float = ref[g][0] / maxf(ref[g][1], 1)
			var b: float = agitations[c][g][0] / maxf(agitations[c][g][1], 1)
			if a < 0.3 and b < 0.3: continue        # une eau presque immobile : rien à comparer
			var rapport := b / maxf(a, 1e-6)
			_noter("V6a", absf(rapport - 1.0))
			if absf(rapport - 1.0) > TOL_AGITATION:
				_echec("V6", "agitation de l'eau" + (" dans le sillage" if g >= 100 else ""), "à %d images/s, %.2f px en moyenne contre %.2f à 120" % [c, b, a], g % 100, 0.0, c)

func _vu(regle: String) -> void:
	_vus[regle] = int(_vus.get(regle, 0)) + 1

func _noter(regle: String, ecart: float) -> void:
	_vu(regle)
	_pires[regle] = maxf(float(_pires.get(regle, -INF)), ecart)

# Un défaut. Pendant la partie, il est daté du geste et de l'instant en cours
# (coup < 0). Un défaut qui dure se signale une fois par règle, lieu, geste et
# cadence, avec le nombre d'images où il se voit et son premier instant.
func _echec(regle: String, lieu: String, detail := "", coup := -1, t := -1.0, cadence := -1) -> void:
	if coup < 0:
		coup = _coup; t = _t_geste; cadence = _cadence
	echecs.append([regle, lieu, detail, coup, t, cadence])
