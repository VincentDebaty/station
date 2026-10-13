class_name Cuisson
# ------------------------------------------------------------------
# CUIRE LE DÉCOR FIXE (lot 0, 13 octobre 2026). Sur un Galaxy A12, le jeu
# dessinait 650 objets par image, dont plus de 300 polygones du mur du fond
# qui ne bougent jamais (leurs matières — pierre, terre, herbe — n'ont pas
# d'animation). On les dessine UNE fois, à la taille exacte de l'écran, dans
# une image hors écran ; à leur place dans la scène, un seul Sprite2D montre
# cette image, pixel pour pixel. Recuit quand l'écran change de taille.
#
# Ne jamais cuire un nœud qui change après la construction du niveau : il
# resterait figé.
# ------------------------------------------------------------------

# Cuit le sous-arbre « n » ; rend le Sprite2D qui le remplace (à mettre à jour
# avec recuire() quand la caméra change).
static func cuire(n: Node2D) -> Sprite2D:
	var parent := n.get_parent()
	var rang := n.get_index()
	var four := SubViewport.new()
	four.transparent_bg = true
	four.render_target_update_mode = SubViewport.UPDATE_ONCE
	four.msaa_2d = n.get_viewport().msaa_2d
	four.canvas_item_default_texture_filter = n.get_viewport().canvas_item_default_texture_filter
	parent.add_child(four)
	var vue := Sprite2D.new()
	vue.centered = false
	vue.name = n.name + "Cuit"
	parent.add_child(vue)
	parent.move_child(vue, rang)
	# le sous-arbre passe dans le four, avec sa transformation dans le monde
	var t := n.global_transform
	parent.remove_child(n)
	four.add_child(n)
	n.global_transform = t
	vue.set_meta("four", four)
	vue.texture = four.get_texture()
	return vue

static func recuire(vue: Sprite2D) -> void:
	var four: SubViewport = vue.get_meta("four")
	var vp := vue.get_viewport()
	var ecran := vp.get_visible_rect().size
	var xf := vue.get_canvas_transform()       # monde → écran
	four.size = Vector2i(int(ceil(ecran.x)), int(ceil(ecran.y)))
	four.canvas_transform = xf
	four.render_target_update_mode = SubViewport.UPDATE_ONCE
	# le sprite couvre l'écran : son coin haut gauche est le monde sous le
	# pixel (0, 0), et un pixel de l'image vaut un pixel de l'écran
	var inv := xf.affine_inverse()
	vue.global_position = inv * Vector2.ZERO
	vue.global_scale = Vector2(1.0 / xf.get_scale().x, 1.0 / xf.get_scale().y)
	vue.global_rotation = 0.0
