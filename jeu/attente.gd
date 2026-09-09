extends CanvasLayer
## L'ÉCRAN D'ATTENTE — un convoi qui roule pendant qu'on tire la journée.
##
## LE JEU AVAIT L'AIR DE PLANTER. « Quand je clique sur le bouton Jouer, j'ai
## une seconde d'attente avant que le jeu commence, il faudrait montrer que
## cela charge. On a l'impression que cela bug » (Vincent, 9 septembre 2026).
## Une seconde sur Darlington, cinq et demie sur Bruxelles-Midi : c'est le
## tirage de la journée, la seule opération lourde du jeu, et elle bloquait le
## fil principal — donc aucune image ne pouvait s'afficher pendant ce temps.
##
## Un voile qui ne bouge pas n'aurait rien réglé : un écran figé se lit comme
## un plantage, animé ou non. C'est pourquoi le tirage part sur un FIL
## D'EXÉCUTION (jeu/app.gd) ; cette couche-ci est ce qu'on regarde pendant.
##
## Elle est une CanvasLayer : elle passe au-dessus de tout, sans rien devoir
## aux transitions de `montrer()` qui déplacent et redimensionnent les vues.
##
## Le convoi ne bouge pas, c'est la voie qui défile — comme dans un plan fixe
## de cinéma. Le regard reste sur la machine, la vitesse se lit aux traverses
## qui passent, et le nom de la gare tient sa place sous le train sans jamais
## se faire rattraper.

const Sty := preload("res://jeu/style.gd")
const Ill := preload("res://jeu/illustrations.gd")
const Ob := preload("res://jeu/oblique.gd")

var toile: Toile


func _init() -> void:
	layer = 10
	toile = Toile.new()
	add_child(toile)
	visible = false


## Ouvrir sur une gare. `verbe` dit ce qu'on attend.
func ouvrir(ville: String, verbe: String = "on prépare le service") -> void:
	toile.ville = ville
	toile.verbe = verbe
	toile.t = 0.0
	visible = true
	toile.queue_redraw()


func fermer() -> void:
	visible = false


class Toile extends Node2D:
	const VITESSE := 210.0        # unités par seconde, ce que la voie défile
	const PANACHE := 12            # bouffées de fumée en vol

	var ville := ""
	var verbe := ""
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var e := get_viewport_rect().size
		var k := Sty.HUD_K
		# LE FOND EST CELUI DU POSTE, pas un voile gris : on va vers le poste,
		# et arriver sur la même couleur fait de l'attente le début du service
		# au lieu d'un écran de plus.
		draw_rect(Rect2(Vector2.ZERO, e), Sty.POSTE_FOND, true)
		var c := e / 2.0
		var y: float = c.y - 14.0 * k
		# une lampe posée au-dessus du convoi, comme sur le pupitre. BEAUCOUP DE
		# NAPPES ET TRÈS PEU D'ENCRE : à quatorze marches on voyait les anneaux.
		for i in range(30):
			draw_circle(Vector2(c.x, y - 20.0 * k),
				(50.0 + 330.0 * (1.0 - float(i) / 30.0)) * k, Color(Sty.LAITON_CLAIR, 0.006))

		var cell: float = 78.0 * k                 # une case de convoi
		var h: float = cell / 1.75                 # la proportion des planches
		var pas: float = 26.0 * k                  # l'écart des traverses
		var glisse: float = fmod(t * VITESSE * k, pas)
		# LES ROUES TOUCHENT LE RAIL. La planche porte son propre bas de caisse :
		# on pose donc la file supérieure À L'INTÉRIEUR du bas de l'image, sans
		# quoi le convoi flotte au-dessus de sa voie.
		var sol: float = y + h / 2.0 - 4.0 * k

		# --- LA VOIE, DANS L'IDIOME DU JEU --------------------------------
		# Elle était en ÉLÉVATION — un épaulement de ballast vu de côté, sous
		# des traverses en perspective — pendant que le convoi restait vu de
		# dessus. Deux points de vue dans la même image, et c'est exactement ce
		# que Vincent a vu. C'est maintenant la voie du poste, avec le même
		# cisaillement : ballast étroit, traverses penchées de `Ob.S`, deux
		# files. La demi-longueur d'une traverse se cisaille en x et
		# s'aplatit en y, comme n'importe quel point du plan.
		draw_line(Vector2(0, sol + 4.0 * k), Vector2(e.x, sol + 4.0 * k),
			Color(Sty.POSTE_BALLAST, 0.85), 13.0 * k, true)
		var demi := 7.0 * k
		var x: float = -pas - glisse
		while x < e.x + pas:
			draw_line(Vector2(x - demi * Ob.S, sol + 4.0 * k - demi * Ob.A),
				Vector2(x + demi * Ob.S, sol + 4.0 * k + demi * Ob.A),
				Color(Sty.POSTE_VOIE, 0.75), 3.0 * k, true)
			x += pas
		for dy in [-0.5, 8.5]:
			draw_line(Vector2(0, sol + dy * k), Vector2(e.x, sol + dy * k),
				Color(Sty.POSTE_VOIE, 0.95), 2.4 * k, true)

		# --- le convoi : une machine et trois fourgons ---------------------
		# Il tangue d'un rien — un véhicule parfaitement immobile sur une voie
		# qui défile a l'air collé au décor.
		var tangue: float = sin(t * 7.0) * 1.2 * k
		var teinte := Sty.LAITON_CLAIR
		var x0: float = c.x - cell * 2.0
		var flanc: float = 5.0 * k
		for i in range(4):
			var tex: Texture2D = Ill.vehicule("loco" if i == 0 else "fourgon")
			var g: float = x0 + float(3 - i) * cell
			var dy: float = tangue * (1.0 if i % 2 == 0 else -1.0)
			var cy2: float = y + dy
			var xa: float = g + 2.0 * k
			var xb: float = g + cell - 2.0 * k
			var dh: float = h / 2.0
			# la caisse cisaillée comme dans le poste : le bord du fond glisse
			# à gauche et remonte, celui de devant glisse à droite et descend
			var quad := PackedVector2Array([
				Vector2(xa - dh * Ob.S, cy2 - dh * Ob.A), Vector2(xb - dh * Ob.S, cy2 - dh * Ob.A),
				Vector2(xb + dh * Ob.S, cy2 + dh * Ob.A), Vector2(xa + dh * Ob.S, cy2 + dh * Ob.A)])
			# le flanc, sous l'arête basse — le même qu'à quai
			draw_colored_polygon(PackedVector2Array([quad[3], quad[2],
				quad[2] + Vector2(0, flanc), quad[3] + Vector2(0, flanc)]),
				teinte.darkened(0.62))
			draw_line(quad[3] + Vector2(0, flanc), quad[2] + Vector2(0, flanc),
				Color(0, 0, 0, 0.42), max(1.0, 1.3 * k), true)
			var lavis := Color(teinte.lerp(Sty.PAPIER, 0.06), 1.0)
			if tex != null:
				draw_colored_polygon(quad, lavis, PackedVector2Array([
					Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)
			else:
				draw_colored_polygon(quad, lavis)

		# --- la fumée, qui part de la cheminée et se laisse distancer ------
		# ELLE DOIT SE VOIR : une fumée à la couleur du quai sur le fond du
		# poste, c'était deux bruns l'un sur l'autre. Elle prend le papier.
		var chem := Vector2(x0 + 3.0 * cell + cell * 0.30, y - h * 0.52 + tangue)
		for i in range(PANACHE):
			var age: float = fmod(t * 1.5 + float(i) * 0.30, 2.7)
			var u: float = age / 2.7
			var p := chem + Vector2(-VITESSE * k * age * 0.46, -70.0 * k * age * 0.66)
			p.x += sin(age * 2.2 + float(i)) * 5.0 * k
			# UNE BOUFFÉE N'EST PAS UN DISQUE : trois lobes décalés, et le
			# panache cesse d'être un chapelet de perles.
			var r: float = (6.0 + 32.0 * u) * k
			var a: float = 0.17 * (1.0 - u) * (1.0 - u)
			for j in range(3):
				var d: float = float(j) * 2.1 + float(i)
				draw_circle(p + Vector2(cos(d), sin(d * 1.7)) * r * 0.42,
					r * (0.62 + 0.16 * float(j)), Color(Sty.PAPIER, a))

		# --- ce qu'on attend ----------------------------------------------
		var titre := Sty.titre(700)
		var ts := int(round(26.0 * k))
		if ville != "":
			Sty.texte_espace(self, titre, ts,
				Vector2(c.x - Sty.largeur_espacee(titre, ts, ville.to_upper(), 3.0 * k) / 2.0,
					sol + 62.0 * k), ville.to_upper(), Sty.TEXTE, 3.0 * k)
		# les trois points qui s'allument l'un après l'autre : c'est le seul
		# endroit de l'écran qui dise « ce n'est pas fini »
		var sans := Sty.sans(400)
		var vs := int(round(14.0 * k))
		var w: float = sans.get_string_size(verbe, HORIZONTAL_ALIGNMENT_LEFT, -1, vs).x
		var bx: float = c.x - (w + 22.0 * k) / 2.0
		var by: float = sol + 92.0 * k
		draw_string(sans, Vector2(bx, by), verbe, HORIZONTAL_ALIGNMENT_LEFT, -1, vs,
			Color(Sty.POSTE_BORD, 0.85))
		for i in range(3):
			var a: float = 0.25 + 0.75 * maxf(0.0, sin(t * 3.4 - float(i) * 0.7))
			draw_circle(Vector2(bx + w + (7.0 + float(i) * 7.0) * k, by - 4.0 * k), 2.0 * k,
				Color(Sty.LAITON_CLAIR, a))
