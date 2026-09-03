class_name Capture
## VÉRIFICATION VISUELLE SANS ŒIL HUMAIN.
##
##   STATION_CAPTURE=/chemin/image.png godot --path . [scène]
##
## Rend deux images (le temps que tout soit peint), enregistre la seconde, et
## quitte. C'est ce qui permet de contrôler un écran depuis un script, sans
## dépendre de quelqu'un qui regarde — et c'est déjà comme ça qu'on a attrapé
## le premier défaut du portage : une liste invisible faute d'avoir réclamé sa
## place dans sa colonne.
##
## Appeler `Capture.eventuelle(self)` en fin de `_ready()` ; sans la variable
## d'environnement, ça ne fait rien.


## `STATION_CAPTURE_APRES=<secondes>` laisse d'abord tourner la scène : c'est
## ainsi qu'on photographie un convoi EN MOUVEMENT, pas un plan vide.
static func eventuelle(depuis: Node) -> void:
	var vers := OS.get_environment("STATION_CAPTURE")
	if vers == "":
		return
	var apres := OS.get_environment("STATION_CAPTURE_APRES")
	if apres != "":
		await depuis.get_tree().create_timer(float(apres)).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := depuis.get_viewport().get_texture().get_image()
	if img.save_png(vers) == OK:
		print("capture : " + vers)
	else:
		push_error("capture impossible : " + vers)
	depuis.get_tree().quit()
