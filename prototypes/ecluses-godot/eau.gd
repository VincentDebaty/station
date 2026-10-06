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
var fond_y := 0.0
var repos := 0.0          # y monde de la surface au repos
var remous := 0.0          # 0..1 : l'eau bouillonne (écume, réfraction)
var passage := false
var gauche: Eau = null     # pour un passage : les deux bassins qu'il relie
var droite: Eau = null
var visible_eau := true
var paroi_g := true        # une paroi de pierre de ce côté (pas une porte)
var paroi_d := true

var _h := PackedFloat32Array()
var _v := PackedFloat32Array()
var _t := 0.0
var _reste := 0.0
var _mat: ShaderMaterial

func preparer(ax0: float, ax1: float, afond: float, arepos: float, shader: Shader) -> void:
	x0 = ax0; x1 = ax1; fond_y = afond; repos = arepos
	var n := maxi(2, int(ceil((x1 - x0) / PAS)) + 1)
	_h.resize(n); _v.resize(n)
	_h.fill(0.0); _v.fill(0.0)
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

# La surface à l'abscisse x, en y monde.
func hauteur_a(x: float) -> float:
	if passage:
		var ya := gauche.hauteur_a(gauche.x1) if gauche else repos
		var yb := droite.hauteur_a(droite.x0) if droite else repos
		return lerpf(ya, yb, clampf((x - x0) / maxf(x1 - x0, 1.0), 0.0, 1.0))
	var f := clampf((x - x0) / maxf(x1 - x0, 1.0), 0.0, 1.0) * float(_h.size() - 1)
	var i := int(floor(f))
	var j := mini(i + 1, _h.size() - 1)
	var h := lerpf(_h[i], _h[j], f - float(i))
	return minf(repos + h + _houle(x), fond_y)

# Une poussée sur la surface, centrée en x, étalée sur « largeur » pixels.
# Positive : la surface descend ; négative : elle monte.
func impulsion(x: float, force: float, largeur := 24.0) -> void:
	if passage:
		return
	for i in _h.size():
		var d := absf(x_de(i) - x)
		if d < largeur:
			_v[i] += force * (1.0 - d / largeur)

func _process(dt: float) -> void:
	_t += dt
	if not passage:
		_reste += dt
		while _reste >= 1.0 / 60.0:
			_reste -= 1.0 / 60.0
			_pas_ressorts()
	_construire()

func _pas_ressorts() -> void:
	var amorti := Reglages.v("amortissement")     # plus haut, la surface se calme plus vite
	var n := _h.size()
	for i in n:
		_v[i] += -RAIDEUR * _h[i] - amorti * _v[i]
		_h[i] += _v[i]
	for _p in PASSES:
		var g := PackedFloat32Array(); g.resize(n)
		var d := PackedFloat32Array(); d.resize(n)
		for i in n:
			if i > 0:
				g[i] = ETALEMENT * (_h[i] - _h[i - 1]); _v[i - 1] += g[i]
			if i < n - 1:
				d[i] = ETALEMENT * (_h[i] - _h[i + 1]); _v[i + 1] += d[i]
		for i in n:
			if i > 0: _h[i - 1] += g[i]
			if i < n - 1: _h[i + 1] += d[i]

func _construire() -> void:
	var am := mesh as ArrayMesh
	am.clear_surfaces()
	var haut_moyen := 0.0
	var pts := PackedVector2Array()
	var n := _h.size() if not passage else 2
	for i in n:
		var x := x_de(i) if not passage else (x0 if i == 0 else x1)
		var y := hauteur_a(x)
		pts.append(Vector2(x, y))
		haut_moyen += y
	haut_moyen /= float(n)
	var ep := fond_y - haut_moyen
	if not visible_eau or ep < 1.5:
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
	_mat.set_shader_parameter("remous", remous)
