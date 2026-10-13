class_name Eau
extends MeshInstance2D
# ------------------------------------------------------------------
# L'EAU D'UN BASSIN — la couche de RENDU, qui ne décide de rien.
#
# Le moteur dit où est le niveau (« repos », en y monde). Cette eau-ci fait
# vivre la surface autour : une rangée de colonnes reliées par des ressorts
# (chacune rappelée vers le repos, chacune tirant ses voisines), plus une
# houle douce permanente. Les remous, les sillages et les jets lui donnent
# des impulsions ; elle les propage et les amortit toute seule.
#
# Un PASSAGE est l'eau qui remplit l'ouverture d'une porte : il n'a pas de
# ressorts, sa surface va en ligne droite du bord d'un bassin à l'autre.
# ------------------------------------------------------------------

const PAS := 8.0          # une colonne tous les 8 pixels
const RAIDEUR := 0.028     # rappel vers le repos, par pas de 1/60 s
const ETALEMENT := 0.22    # ce qu'une colonne transmet à ses voisines
const PASSES := 4

var x0 := 0.0
var x1 := 0.0
var fond_y := 0.0:
	set(v):
		if v != fond_y: _sale = true
		fond_y = v
var repos := 0.0:         # y monde de la surface au repos
	set(v):
		if v != repos: _sale = true
		repos = v
var remous := 0.0          # 0..1 : l'eau bouillonne (écume, réfraction)
var passage := false
var gauche: Eau = null     # pour un passage : les deux bassins qu'il relie
var droite: Eau = null
var visible_eau := true
var paroi_g := true        # une paroi de pierre de ce côté (pas une porte)
var paroi_d := true
var clarte := 0.0          # l'eau mince devant une porte : plus limpide
# Le raccord avec le bassin voisin, sous une porte ouverte où l'eau finit de
# passer (canal.gd) : la surface rejoint cette hauteur (y monde) sur les
# derniers RACCORD pixels de ce côté. INF : pas de raccord. Dans l'eau
# elle-même, pour que la coupe et la surface vue d'en haut le suivent
# ensemble (fait seulement sur la surface vue d'en haut, il laissait une
# fente entre les deux).
var lien_g := INF
var lien_d := INF
const RACCORD := 40.0
# Le raccord affiché suit sa cible en douceur, et s'installe ou s'efface en
# fondu : posé ou retiré d'une image à l'autre, il faisait sauter la surface
# de plusieurs pixels contre la porte (fin d'un remplissage, Vincent).
var _lien_g := 0.0
var _lien_d := 0.0
var _poids_g := 0.0
var _poids_d := 0.0

var _h := PackedFloat32Array()
var _v := PackedFloat32Array()
# La surface, colonne par colonne, calculée une fois par image (houle,
# raccords et tout) : tous ceux qui la lisent dans l'image (le maillage, les
# bandes de surface, les bateaux, la cascade) interpolent dans ce tableau.
# Recalculée pour chaque appel, la houle (trois sinus et un réglage lu par
# colonne) coûtait à elle seule plusieurs ms sur un Galaxy A12 (lot 0).
var _ycol := PackedFloat32Array()
var _sale := true
var _image_ycol := -1
# Les ressorts au repos ne calculent rien : ils se réveillent à la première
# poussée (impulsion). Sur un Galaxy A12, ils coûtaient 10 ms par image même
# sur une eau immobile.
var _dort := false
var _g := PackedFloat32Array()
var _d := PackedFloat32Array()
var _t := 0.0
var _reste := 0.0
var _mat: ShaderMaterial

func preparer(ax0: float, ax1: float, afond: float, arepos: float, shader: Shader) -> void:
	x0 = ax0; x1 = ax1; fond_y = afond; repos = arepos
	var n := maxi(2, int(ceil((x1 - x0) / PAS)) + 1)
	_h.resize(n); _v.resize(n)
	_h.fill(0.0); _v.fill(0.0)
	_g.resize(n); _d.resize(n); _ycol.resize(n)
	_sale = true
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
	mesh = ArrayMesh.new()

func n_colonnes() -> int:
	return _h.size()

func x_de(i: int) -> float:
	return lerpf(x0, x1, float(i) / float(_h.size() - 1))

func _houle(x: float) -> float:
	return Reglages.v("houle") * (1.5 * sin(x * 0.043 + _t * 1.55) + 0.9 * sin(x * 0.107 - _t * 2.25) + 0.5 * sin(x * 0.21 + _t * 3.1))

# 1 dans une eau d'au moins 12 px, 0 dans un bassin vide : les vagues
# meurent avec l'eau. Sans cela, un bassin vidé jusqu'à son fond (le bief
# amont du 1-2, vidé jusqu'au seuil de sa porte) ondulait autour de zéro, et
# un plan d'eau réapparaissait par instants (Vincent).
func calme() -> float:
	return clampf((fond_y - repos) / 12.0, 0.0, 1.0)

# Vide au repos, vagues comprises ou non.
func vide() -> bool:
	return fond_y - repos < 1.5

func _suivre_liens(dt: float) -> void:
	var v := minf(1.0, dt * 10.0)
	if lien_g != INF:
		_lien_g = lien_g if _poids_g <= 0.0 else lerpf(_lien_g, lien_g, v)
		_poids_g = move_toward(_poids_g, 1.0, dt * 5.0)
	else:
		_poids_g = move_toward(_poids_g, 0.0, dt * 5.0)
	if lien_d != INF:
		_lien_d = lien_d if _poids_d <= 0.0 else lerpf(_lien_d, lien_d, v)
		_poids_d = move_toward(_poids_d, 1.0, dt * 5.0)
	else:
		_poids_d = move_toward(_poids_d, 0.0, dt * 5.0)

# La surface à l'abscisse x, en y monde. Sans « liens », celle du bassin
# seul, sans les raccords avec ses voisins (le canal y mesure la chute, que
# le raccord qu'il pose lui-même ne doit pas fausser).
func hauteur_a(x: float, liens := true) -> float:
	if passage:
		var ya := gauche.hauteur_a(gauche.x1) if gauche else repos
		var yb := droite.hauteur_a(droite.x0) if droite else repos
		return lerpf(ya, yb, clampf((x - x0) / maxf(x1 - x0, 1.0), 0.0, 1.0))
	var f := clampf((x - x0) / maxf(x1 - x0, 1.0), 0.0, 1.0) * float(_h.size() - 1)
	var i := int(floor(f))
	var j := mini(i + 1, _h.size() - 1)
	if liens:
		if _sale or _image_ycol != Engine.get_process_frames(): _calculer_ycol()
		return lerpf(_ycol[i], _ycol[j], f - float(i))
	var h := lerpf(_h[i], _h[j], f - float(i))
	var y := repos + (h + _houle(x)) * calme()
	if liens and _poids_g > 0.0 and x - x0 < RACCORD:
		var k := 1.0 - clampf((x - x0) / RACCORD, 0.0, 1.0)
		y = lerpf(y, _lien_g, k * k * (3.0 - 2.0 * k) * _poids_g)
	if liens and _poids_d > 0.0 and x1 - x < RACCORD:
		var k := 1.0 - clampf((x1 - x) / RACCORD, 0.0, 1.0)
		y = lerpf(y, _lien_d, k * k * (3.0 - 2.0 * k) * _poids_d)
	return minf(y, fond_y)

func _calculer_ycol() -> void:
	_sale = false
	_image_ycol = Engine.get_process_frames()
	var n := _h.size()
	var c := calme()
	var a := Reglages.v("houle")
	var pas := (x1 - x0) / float(maxi(n - 1, 1))
	for i in n:
		var x := x0 + pas * i
		var y := repos + (_h[i] + a * (1.5 * sin(x * 0.043 + _t * 1.55) + 0.9 * sin(x * 0.107 - _t * 2.25) + 0.5 * sin(x * 0.21 + _t * 3.1))) * c
		if _poids_g > 0.0 and x - x0 < RACCORD:
			var k := 1.0 - clampf((x - x0) / RACCORD, 0.0, 1.0)
			y = lerpf(y, _lien_g, k * k * (3.0 - 2.0 * k) * _poids_g)
		if _poids_d > 0.0 and x1 - x < RACCORD:
			var k := 1.0 - clampf((x1 - x) / RACCORD, 0.0, 1.0)
			y = lerpf(y, _lien_d, k * k * (3.0 - 2.0 * k) * _poids_d)
		_ycol[i] = minf(y, fond_y)

# Une poussée sur la surface, centrée en x, étalée sur « largeur » pixels.
# Positive : la surface descend ; négative : elle monte.
func impulsion(x: float, force: float, largeur := 24.0) -> void:
	if passage:
		return
	_dort = false
	_sale = true
	for i in _h.size():
		var d := absf(x_de(i) - x)
		if d < largeur:
			_v[i] += force * (1.0 - d / largeur)

func _process(dt: float) -> void:
	var _c0 := Time.get_ticks_usec()
	_process_corps(dt)
	Chrono.ajouter("eau._process", _c0)

func _process_corps(dt: float) -> void:
	_t += dt
	_sale = true
	_suivre_liens(dt)
	var _c0 := Time.get_ticks_usec()
	if not passage:
		_reste += dt
		# (deux pas au plus par image : un téléphone qui rame en enchaînait
		# davantage à chaque image, et ramait d'autant plus)
		_reste = minf(_reste, 2.0 / 60.0)
		while _reste >= 1.0 / 60.0:
			_reste -= 1.0 / 60.0
			if not _dort: _pas_ressorts()
	Chrono.ajouter("eau.ressorts", _c0)
	_c0 = Time.get_ticks_usec()
	_construire()
	Chrono.ajouter("eau.construire", _c0)

func _pas_ressorts() -> void:
	var amorti := Reglages.v("amortissement")     # plus haut, la surface se calme plus vite
	var n := _h.size()
	var agite := 0.0
	for i in n:
		_v[i] += -RAIDEUR * _h[i] - amorti * _v[i]
		_h[i] += _v[i]
		agite = maxf(agite, absf(_h[i]) + absf(_v[i]))
	# l'eau s'est calmée : les ressorts s'endorment
	if agite < 0.02:
		_h.fill(0.0); _v.fill(0.0)
		_dort = true
		return
	for _p in PASSES:
		for i in n:
			_g[i] = ETALEMENT * (_h[i] - _h[i - 1]) if i > 0 else 0.0
			_d[i] = ETALEMENT * (_h[i] - _h[i + 1]) if i < n - 1 else 0.0
		for i in n:
			if i > 0: _v[i - 1] += _g[i]; _h[i - 1] += _g[i]
			if i < n - 1: _v[i + 1] += _d[i]; _h[i + 1] += _d[i]

var _vide_construit := false
func _construire() -> void:
	var am := mesh as ArrayMesh
	# (vide ou cachée : rien à reconstruire, une fois la surface effacée)
	if not visible_eau or (not passage and vide()):
		if not _vide_construit:
			am.clear_surfaces()
			_vide_construit = true
		return
	_vide_construit = false
	am.clear_surfaces()
	var haut_moyen := 0.0
	var pts := PackedVector2Array()
	var n := _h.size() if not passage else 2
	if not passage and (_sale or _image_ycol != Engine.get_process_frames()): _calculer_ycol()
	var pas := (x1 - x0) / float(maxi(n - 1, 1))
	for i in n:
		var x := x0 + pas * i
		var y := _ycol[i] if not passage else hauteur_a(x)
		pts.append(Vector2(x, y))
		haut_moyen += y
	haut_moyen /= float(n)
	var ep := fond_y - haut_moyen
	if not visible_eau or ep < 1.5 or (not passage and vide()):
		return
	var sommets := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in n:
		var p := pts[i]
		var u := float(i) / float(n - 1)
		sommets.append(Vector2(p.x, minf(p.y, fond_y)))
		uvs.append(Vector2(u, 0.0))
		sommets.append(Vector2(p.x, fond_y))
		uvs.append(Vector2(u, 1.0))
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_TEX_UV] = uvs
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, tableaux)
	_mat.set_shader_parameter("epaisseur", ep)
	_mat.set_shader_parameter("largeur", x1 - x0)
	_mat.set_shader_parameter("paroi_g", 1.0 if paroi_g and not passage else 0.0)
	_mat.set_shader_parameter("paroi_d", 1.0 if paroi_d and not passage else 0.0)
	_mat.set_shader_parameter("clarte", clarte)
	_mat.set_shader_parameter("remous", remous)
