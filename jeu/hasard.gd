class_name Hasard
## LE HASARD GRAINÉ — mulberry32, à l'identique de tools/gen-check.mjs.
##
## Le prototype tire ses journées avec Math.random ; gen-check le remplace par
## un mulberry32 graine pour qu'une journée se rejoue. C'est ce même générateur
## qu'il faut ici, AU BIT PRÈS : l'oracle (tools/oracle-journee.mjs) compare
## des journées tirées des deux côtés avec la même graine, et la moindre
## différence de séquence rend toute comparaison impossible.
##
## POURQUOI DES ENTIERS NON SIGNÉS MASQUÉS. JavaScript fait ses opérations
## bit-à-bit en 32 bits : `|0` ramène en int32, `>>>` décale en uint32,
## Math.imul multiplie modulo 2³². GDScript n'a que l'int64. On tient donc
## l'état en uint32 (masque 0xFFFFFFFF après chaque opération) : le
## dépassement d'int64 sur la multiplication s'enroule silencieusement et les
## 32 bits bas restent justes — c'est exactement ce que fait imul.
##
## Une instance = une séquence. Pas de singleton : la journée reçoit son
## Hasard, et un `Hasard.new(graine)` neuf rejoue la même journée.

const MASQUE := 0xFFFFFFFF

var _a: int


func _init(graine: int) -> void:
	_a = graine & MASQUE


static func _imul(x: int, y: int) -> int:
	return (x * y) & MASQUE


## Un flottant dans [0, 1), comme Math.random.
func random() -> float:
	_a = (_a + 0x6D2B79F5) & MASQUE
	var a := _a
	var t := _imul(a ^ (a >> 15), 1 | a)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & MASQUE) ^ t
	return float((t ^ (t >> 14)) & MASQUE) / 4294967296.0


## `a + Math.random() * (b - a)` — la même expression, dans le même ordre.
func rnd(a: float, b: float) -> float:
	return a + random() * (b - a)


## `arr[Math.floor(Math.random() * arr.length)]`.
func pick(arr: Array) -> Variant:
	return arr[int(floor(random() * arr.size()))]
