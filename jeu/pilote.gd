extends Node
## LE PILOTE — des gestes joués sans personne devant, pour photographier un
## enchaînement d'écrans.
##
##   STATION_PILOTE="1 capture /tmp/a.png | 1.2 clic 700 400 | 2 touche space | 6 capture /tmp/b.png | 6.5 quitter"
##
## Chaque pas est « <secondes depuis le début> <geste> [args] » :
##   clic X Y        un clic gauche à cette position d'écran (fenêtre 1400 × 760)
##   touche NOM      une touche (space, escape, r, 1, 2, 4, enter…)
##   capture CHEMIN  une image de l'écran, sans quitter
##   quitter         la fin
##
## C'est Capture.eventuelle en plus long : un service se photographie une fois,
## un enchaînement — ruban, service, relevé, ruban — se pilote.


static func eventuel(hote: Node) -> void:
	var s := OS.get_environment("STATION_PILOTE")
	if s == "":
		return
	var p := new()
	p.script_texte = s
	hote.add_child(p)


var script_texte := ""


func _ready() -> void:
	_jouer()


func _jouer() -> void:
	var debut := Time.get_ticks_msec()
	for pas in script_texte.split("|"):
		var mots: PackedStringArray = pas.strip_edges().split(" ", false)
		if mots.size() < 2:
			continue
		var quand := float(mots[0]) * 1000.0
		var attente := quand - (Time.get_ticks_msec() - debut)
		if attente > 0:
			await get_tree().create_timer(attente / 1000.0).timeout
		match mots[1]:
			"clic":
				_clic(Vector2(float(mots[2]), float(mots[3])))
			"touche":
				_touche(mots[2])
			"capture":
				await _capture(mots[2])
			"quitter":
				get_tree().quit()
				return
			_:
				printerr("pilote : geste inconnu « %s »" % mots[1])


func _clic(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	for presse in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = presse
		Input.parse_input_event(ev)


func _touche(nom: String) -> void:
	var code := OS.find_keycode_from_string(nom)
	for presse in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = presse
		Input.parse_input_event(ev)


func _capture(chemin: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png(chemin) == OK:
		print("capture : " + chemin)
	else:
		push_error("capture impossible : " + chemin)
