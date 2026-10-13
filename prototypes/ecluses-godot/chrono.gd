class_name Chrono
# ------------------------------------------------------------------
# Des chronomètres pour savoir où passe le temps d'une image (lot 0,
# 13 octobre 2026 : 40 ms de calcul par image sur un Galaxy A12). Actifs
# seulement en démo ; principal.gd imprime le relevé chaque seconde.
# ------------------------------------------------------------------
static var actif := false
static var t := {}
static var images := 0

static func ajouter(nom: String, debut_us: int) -> void:
	if not actif: return
	t[nom] = int(t.get(nom, 0)) + Time.get_ticks_usec() - debut_us

static func releve() -> String:
	if images == 0: return ""
	var noms := t.keys()
	noms.sort_custom(func(a, b): return t[a] > t[b])
	var s := ""
	for n in noms.slice(0, 12):
		s += "%s %.2f  " % [n, float(t[n]) / images / 1000.0]
	t.clear()
	images = 0
	return s
