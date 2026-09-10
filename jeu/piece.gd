class_name Piece
extends Control
## LA PIÈCE — l'objet que le crédit est devenu (10 septembre 2026,
## economie-du-jeu.md §2). « CR ne veut pas dire grand-chose » (Vincent) : un
## crédit est un mot de banque, il n'a pas de forme, on ne peut ni le dessiner
## ni le faire tinter. La pièce est frappée en laiton et dessinée comme la
## pierre l'est, pan par pan : la tranche sombre, le champ qui prend la
## lumière, le listel, une roue au centre, et l'éclat sur le bord haut.
##
## UNE SEULE PIÈCE POUR TOUT LE JEU — la barre du haut, le relevé, le vol de la
## remise, la gare payée sur la carte, l'écran des cartes. On ne doit jamais
## pouvoir croire qu'il y en a deux. Un Control pour les mises en page, et une
## fonction statique pour les `_draw` : même recette, même laiton.

const Sty := preload("res://jeu/style.gd")

var diametre := 14.0


func _init(d: float) -> void:
	diametre = d
	custom_minimum_size = Vector2(d, d)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	frapper(self, size / 2.0, diametre, 1.0)


## La pièce, frappée à `c`, de diamètre `d`.
static func frapper(canvas: CanvasItem, c: Vector2, d: float, alpha: float) -> void:
	var r: float = d / 2.0
	var or_: Color = Sty.LAITON
	var clair: Color = Sty.LAITON_CLAIR
	var sombre: Color = Sty.LAITON.darkened(0.48)
	# la tranche : le disque entier, dans le laiton sombre
	canvas.draw_circle(c, r, Color(sombre, alpha))
	# le champ, décalé d'un rien vers le haut : c'est ce qui donne l'épaisseur
	canvas.draw_circle(c + Vector2(-r * 0.03, -r * 0.06), r * 0.86, Color(or_, alpha))
	# le listel
	canvas.draw_arc(c, r * 0.70, 0.0, TAU, 36, Color(sombre, 0.50 * alpha), maxf(1.0, r * 0.09), true)
	# la roue : une jante, six rayons, un moyeu — le signe du rail
	var rr: float = r * 0.44
	canvas.draw_arc(c, rr, 0.0, TAU, 28, Color(sombre, 0.85 * alpha), maxf(1.0, r * 0.11), true)
	for i in range(6):
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		canvas.draw_line(c, c + Vector2(cos(a), sin(a)) * rr, Color(sombre, 0.85 * alpha), maxf(1.0, r * 0.08), true)
	canvas.draw_circle(c, r * 0.13, Color(sombre, 0.95 * alpha))
	# l'éclat, sur le bord haut-gauche
	canvas.draw_arc(c, r * 0.80, PI * 1.08, PI * 1.52, 12, Color(clair, 0.95 * alpha), maxf(1.0, r * 0.13), true)
