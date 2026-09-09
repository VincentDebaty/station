extends Node
## LES SONS DU POSTE — les mêmes signatures que le prototype, sans un fichier.
##
## Le jeu web ne charge aucun échantillon : `js/render.js` fabrique six petites
## signatures à la volée avec WebAudio (`playTone` + le dictionnaire `SND`), et
## c'est délibéré — une ambiance de poste d'aiguillage, pas une fanfare, et
## rien à télécharger. On garde le principe ET LES CHIFFRES : mêmes fréquences,
## mêmes durées, mêmes formes d'onde, même enveloppe. Ce qui change, c'est
## qu'ici la synthèse a lieu UNE FOIS au démarrage, dans un tampon PCM, au lieu
## d'être recalculée par le navigateur à chaque note.
##
## `playTone(f, t0, dur, forme, vol)` de WebAudio, transposé exactement :
##   — attaque LINÉAIRE de 0,0001 à `vol` en 20 ms ;
##   — extinction EXPONENTIELLE de `vol` à 0,0001 sur le reste de `dur`.
## Une signature est un empilement de tons décalés dans le temps ; on la cuit
## donc en un seul tampon, offsets compris.
##
## LES OSCILLATEURS DE WEBAUDIO SONT À BANDE LIMITÉE, pas les naïfs : un carré
## obtenu par `sign(sin)` remonte à l'infini et se replie en criaillements sur
## un échantillonnage fini. On les reconstruit donc par ADDITION d'harmoniques,
## bornées par Nyquist — c'est la définition même des formes de WebAudio, et
## ça coûte une poignée de millisecondes au chargement (mesuré plus bas).
##
## `Sauvegarde.get_muet()` fait autorité, comme `getMuted()` côté web : le
## réglage vit dans la sauvegarde, pas ici.

const TAUX := 22050          # large pour des tons dont le plus aigu est à 1,8 kHz
const HARMONIQUES := 24      # au-delà, 1/n et 1/n² ne s'entendent plus
const VOIX := 8              # deux signatures peuvent se croiser (départ + incident)

const SINUS := 0
const TRIANGLE := 1
const CARRE := 2
const DENT := 3

var _pistes: Dictionary = {}          # nom → AudioStreamWAV
var _voix: Array[AudioStreamPlayer] = []
var _tour := 0
var duree_synthese_ms := 0            # cité dans STATION_MESURE


func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	# Le dictionnaire SND de js/render.js, ligne pour ligne. Un ton est
	# [fréquence, retard, durée, forme, volume].
	_cuire("annonce", [[830, 0.0, 0.12, SINUS, 0.05], [1108, 0.13, 0.2, SINUS, 0.05]])
	_cuire("fret", [[98, 0.0, 0.55, DENT, 0.045], [147, 0.0, 0.55, DENT, 0.03]])
	_cuire("depart", [[1244, 0.0, 0.08, TRIANGLE, 0.05], [1661, 0.09, 0.13, TRIANGLE, 0.05]])
	_cuire("incident", [[622, 0.0, 0.16, CARRE, 0.03], [466, 0.18, 0.24, CARRE, 0.03]])
	_cuire("fin", [[659, 0.0, 0.12, SINUS, 0.05], [830, 0.13, 0.12, SINUS, 0.05],
		[988, 0.26, 0.3, SINUS, 0.05]])
	var parfait: Array = []
	for i in range(5):
		parfait.append([[523, 659, 784, 1047, 1319][i], i * 0.10, 0.24, TRIANGLE, 0.05])
	_cuire("parfait", parfait)
	# LA REMISE DES RÉCOMPENSES, sur l'écran du ruban. Ces cinq-là n'ont pas
	# d'équivalent web — le prototype ne montrait rien : le relevé s'affichait
	# d'un coup. Elles restent dans le registre des autres : bas, court, et
	# jamais une fanfare. Trois étoiles montent en accord majeur (sol, si, ré),
	# le diamant sonne deux octaves de cristal, la puce du convoi souffle une
	# note grave en partant et deux notes claires en arrivant.
	for k in range(3):
		var f: float = [784.0, 988.0, 1175.0][k]
		_cuire("etoile%d" % k, [[f, 0.0, 0.16, TRIANGLE, 0.05],
			[f * 1.5, 0.05, 0.20, TRIANGLE, 0.035]])
	# LE DIAMANT SONNE PLUS LONG QUE LE RESTE : c'est la plus haute récompense
	# d'un service, et elle se tient trois quarts de seconde à l'écran. Un
	# fondamental grave lui donne du corps, trois octaves de cristal le timbre.
	_cuire("diamant", [[659, 0.0, 0.55, TRIANGLE, 0.030], [1319, 0.0, 0.44, SINUS, 0.050],
		[1976, 0.07, 0.46, SINUS, 0.040], [2637, 0.15, 0.42, SINUS, 0.024],
		[3136, 0.24, 0.36, SINUS, 0.014]])
	_cuire("puce", [[392, 0.0, 0.14, TRIANGLE, 0.035]])
	_cuire("arrivee", [[659, 0.0, 0.10, TRIANGLE, 0.045], [988, 0.09, 0.22, TRIANGLE, 0.04]])
	# Le carillon À L'HEURE monte avec la série, plafonnée à huit crans :
	# `base = 720 + k·66`, `k = min(n-1, 7)`. Huit variantes, cuites d'avance.
	for k in range(8):
		var base: float = 720.0 + k * 66.0
		_cuire("heure%d" % k, [[base, 0.0, 0.08, TRIANGLE, 0.05],
			[base * 1.5, 0.07, 0.14, TRIANGLE, 0.045]])
	for i in range(VOIX):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voix.append(p)
	duree_synthese_ms = int((Time.get_ticks_usec() - t0) / 1000)
	if OS.get_environment("STATION_MESURE") != "":
		var octets := 0
		for nom in _pistes:
			octets += _pistes[nom].data.size()
		print("%d signatures synthétisées en %d ms — %d ko de PCM"
			% [_pistes.size(), duree_synthese_ms, octets / 1024])
		if OS.get_environment("STATION_SONS_MESURE") != "":
			for nom in _pistes:
				var f: AudioStreamWAV = _pistes[nom]
				var d: PackedByteArray = f.data
				var pic := 0
				var somme := 0.0
				for i in range(0, d.size(), 2):
					var v: int = d[i] | (d[i + 1] << 8)
					if v > 32767:
						v -= 65536
					pic = max(pic, abs(v))
					somme += abs(v)
				print("  %-10s %5.3f s  pic %5d (%.3f)  moyenne %.4f"
					% [nom, f.get_length(), pic, pic / 32768.0, somme / max(1, d.size() / 2) / 32768.0])


## Une signature, par son nom. Muette si le joueur a coupé le son.
func jouer(nom: String) -> void:
	if Sauvegarde.get_muet() or not _pistes.has(nom):
		return
	var p: AudioStreamPlayer = _voix[_tour]
	_tour = (_tour + 1) % VOIX
	p.stream = _pistes[nom]
	p.play()


## Le carillon du départ à l'heure, dont la hauteur suit la série.
func jouer_a_l_heure(serie: int) -> void:
	jouer("heure%d" % clampi(serie - 1, 0, 7))


# ------------------------------------------------------------------
# La synthèse
# ------------------------------------------------------------------
func _cuire(nom: String, tons: Array) -> void:
	var fin := 0.0
	for ton in tons:
		fin = maxf(fin, float(ton[1]) + float(ton[2]))
	var n := int(ceil((fin + 0.05) * TAUX))
	var ech := PackedFloat32Array()
	ech.resize(n)
	for ton in tons:
		_poser(ech, float(ton[0]), float(ton[1]), float(ton[2]), int(ton[3]), float(ton[4]))
	# 16 bits signés, petit-boutien : le format que lit AudioStreamWAV.
	var octets := PackedByteArray()
	octets.resize(n * 2)
	for i in range(n):
		var v := int(round(clampf(ech[i], -1.0, 1.0) * 32767.0))
		octets[i * 2] = v & 0xFF
		octets[i * 2 + 1] = (v >> 8) & 0xFF
	var flux := AudioStreamWAV.new()
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = TAUX
	flux.stereo = false
	flux.data = octets
	_pistes[nom] = flux


## Un ton, ajouté au tampon. La forme est reconstruite par addition
## d'harmoniques — celles qui tiennent sous Nyquist —, l'enveloppe est celle
## de WebAudio : 20 ms de montée droite, puis une descente exponentielle.
func _poser(ech: PackedFloat32Array, f: float, t0: float, duree: float, forme: int, vol: float) -> void:
	var debut := int(t0 * TAUX)
	var n := int(duree * TAUX)
	var maxi: int = min(HARMONIQUES, int(floor((TAUX / 2.0) / f)))
	var w := TAU * f / float(TAUX)
	for i in range(n):
		var j := debut + i
		if j < 0 or j >= ech.size():
			continue
		var s := 0.0
		match forme:
			SINUS:
				s = sin(w * i)
			TRIANGLE:
				# harmoniques impaires en 1/n², de signe alterné
				for h in range(1, maxi + 1, 2):
					var m: int = (h - 1) / 2
					s += (1.0 if m % 2 == 0 else -1.0) * sin(w * h * i) / float(h * h)
				s *= 8.0 / (PI * PI)
			CARRE:
				for h in range(1, maxi + 1, 2):
					s += sin(w * h * i) / float(h)
				s *= 4.0 / PI
			DENT:
				for h in range(1, maxi + 1):
					s += (1.0 if h % 2 == 1 else -1.0) * sin(w * h * i) / float(h)
				s *= 2.0 / PI
		# l'enveloppe de playTone
		var t := float(i) / float(TAUX)
		var g := 0.0
		if t < 0.02:
			g = 0.0001 + (vol - 0.0001) * (t / 0.02)
		else:
			var reste: float = maxf(duree - 0.02, 0.0001)
			g = vol * pow(0.0001 / vol, minf((t - 0.02) / reste, 1.0))
		ech[j] += s * g
