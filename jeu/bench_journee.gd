extends SceneTree
## LE BANC DE LA JOURNÉE — où passe le temps, en chiffres.
##
##   godot --headless --path . --script res://jeu/bench_journee.gd -- <fiche.json> <graine>
##
## Tire une journée et rend le compte : combien de simulations, de pas de
## temps, d'itérations convoi × pas, de tests de voie libre — et le coût
## unitaire qui en découle. C'est ce qui a remplacé la devinette après une
## première optimisation « évidente » qui n'a gagné que 1,5× (3 septembre
## 2026) : on ne raccourcit pas ce qu'on n'a pas mesuré.

const Geo := preload("res://jeu/geometrie.gd")
const Jour := preload("res://jeu/journee.gd")
const Has := preload("res://jeu/hasard.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage : --script res://jeu/bench_journee.gd -- <fiche.json> <graine>")
		quit(2)
		return
	var f := FileAccess.open(args[0], FileAccess.READ)
	var j := JSON.new()
	if f == null or j.parse(f.get_as_text()) != OK:
		printerr("fiche illisible : " + args[0])
		quit(1)
		return
	var cfg: Dictionary = j.data
	var G: Dictionary = Geo.construire(cfg)
	Jour.n_sim = 0
	Jour.n_ticks = 0
	Jour.n_iter = 0
	Jour.n_free = 0
	var t0 := Time.get_ticks_usec()
	var journee = Jour.new(G, cfg, Has.new(int(args[1])))
	var day: Dictionary = journee.generate_schedule()
	var us := Time.get_ticks_usec() - t0
	print("%s · graine %s — %d convois, %d événements" % [cfg.get("id", "?"), args[1],
		day["schedule"].size(), day["events"].size()])
	print("  durée            %8.0f ms" % (us / 1000.0))
	print("  simulations      %8d" % Jour.n_sim)
	print("  pas de temps     %8d   (%.0f par simulation)" % [Jour.n_ticks, float(Jour.n_ticks) / max(1, Jour.n_sim)])
	print("  convoi × pas     %8d   (%.1f convois par pas)" % [Jour.n_iter, float(Jour.n_iter) / max(1, Jour.n_ticks)])
	print("  tests voie libre %8d   (%.2f par pas)" % [Jour.n_free, float(Jour.n_free) / max(1, Jour.n_ticks)])
	print("  coût unitaire    %8.0f ns par convoi × pas" % (us * 1000.0 / max(1, Jour.n_iter)))
	quit(0)
