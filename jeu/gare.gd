extends Node2D
## LE PLAN D'UNE GARE, DESSINÉ DEPUIS SA FICHE.
##
##   godot --path . res://jeu/gare.tscn                (Darlington)
##   STATION_GARE=namur godot --path . res://jeu/gare.tscn
##
## Le décor immobile de l'écran de jeu : les voies d'approche, le gril teinté à
## la couleur de chaque destination, les quais en pilule, les heurtoirs, les
## points de convergence et les noms des portails. Ce qui bouge — convois,
## itinéraires, états des quais, badges — est peint par-dessus par vue_jeu.gd.
##
## LA GÉOMÉTRIE EST CELLE DU PROTOTYPE, valeur pour valeur (js/render.js) :
## gril à 50 % de la couleur de sa ville, quai aux coins de 10, numéro à 24,
## nom de portail à 15 détouré de fond. La MATIÈRE, elle, est passée au
## laiton et au bois le 4 septembre 2026 — sans qu'aucune couleur de
## destination ne bouge : ici, la couleur EST la destination.

const Geo := preload("res://jeu/geometrie.gd")
const Cap := preload("res://jeu/capture.gd")
const Sty := preload("res://jeu/style.gd")

var G: Dictionary = {}
var fiche: Dictionary = {}
## Seul à l'écran (lancé comme scène) : il choisit sa gare d'après
## l'environnement et se photographie. Posé par l'écran de jeu : il dessine le
## plan qu'on lui donne, et rien d'autre.
var autonome := true
## Le cartouche de diagnostic (nom, quais, directions…) : seul à l'écran
## seulement — l'écran de jeu a le sien.
var cartouche := true
## Le faisceau mis en avant : la ville d'origine du train choisi ressort un
## peu (.mesh.beam-lit, opacité .82 au lieu de .5). "" au repos.
var faisceau := ""
## Les portails « validés » : un convoi glisse sous leur nom, qui s'allume à
## pleine couleur avec un halo (.portal-name.valid).
var noms_allumes: Array = []


func _ready() -> void:
	if not autonome:
		return
	var id := OS.get_environment("STATION_GARE")
	if id == "":
		id = "darlington"
	var f := Donnees.fiche(id)
	if f.is_empty():
		push_error("gare inconnue : " + id)
		return
	poser(f, Geo.construire(f))
	Cap.eventuelle(self)


## Le plan d'une fiche, avec sa géométrie déjà construite.
func poser(f: Dictionary, geometrie: Dictionary) -> void:
	fiche = f
	G = geometrie
	queue_redraw()


## LA TAILLE D'UN NOM DE PORTAIL. Elle était restée à 15, la valeur CSS du
## prototype, sans le facteur tactile — alors que ce facteur existe justement
## pour cela : sur un pointeur grossier, « tout ce qu'on touche et tout ce
## qu'on lit sur le plan » grossit d'une moitié, et les libellés de portail
## sont nommément dans cette liste (jeu/style.gd). Ils ne l'avaient jamais
## reçu. « La police est trop petite pour le nom des destinations » — c'était
## un oubli, pas un choix.
static func taille_nom() -> int:
	return int(round(15.0 * Sty.UIK))


## Où se pose le nom d'un portail : au-dessus de l'aiguillage, à 34 px au
## plus — × le facteur tactile depuis que le nom a grandi — borné à 40 % de
## l'écart au voisin du même côté (js/render.js).
func position_nom(pname: String) -> Vector2:
	var p: Dictionary = G["portals"][pname]
	var cy := float(p["cy"])
	var gap := INF
	for autre in G["portals"]:
		var q: Dictionary = G["portals"][autre]
		if autre != pname and q["side"] == p["side"]:
			gap = min(gap, absf(float(q["cy"]) - cy))
	return Vector2(float(p["x"]), cy - min(34.0 * Sty.UIK, gap * 0.40))


func _draw() -> void:
	if G.is_empty():
		return
	var sans_g := Sty.sans(700)
	var grave := Sty.titre(600)

	# --- voies d'approche et de départ : la fuite vers le bord ---------------
	# Elles portent leurs traverses depuis le 4 septembre 2026 : ce sont les
	# seules voies du plan qui ne sont pas colorées par une destination, donc
	# les seules où la matière peut parler sans brouiller la signalisation.
	var k := Sty.UIK
	for pname in G["approach"]:
		for quoi in ["approach", "depart"]:
			var v: Dictionary = G[quoi][pname]
			var pts := Geo.vers_vector2(v["xs"], v["ys"])
			draw_polyline(pts, Sty.POSTE_BALLAST, 9.0 * k, true)
			Sty.traverses(self, pts, Color(Sty.POSTE_VOIE, 0.75), 3.4 * k, 11.0 * k)
			draw_polyline(pts, Sty.POSTE_VOIE, 3.5, true)

	# --- le gril : une bézier par liaison, teintée à sa destination -----------
	# LA LIAISON EST INCRUSTÉE DANS LE PUPITRE, pas posée dessus : une saignée
	# sombre creusée sous elle, un biseau clair sur sa lèvre haute, et la
	# couleur par-dessus comme un verre éclairé. C'est le vocabulaire d'un vrai
	# tableau de contrôle optique — et il ne touche à aucune signalisation :
	# la couleur reste la destination, à la même opacité qu'avant.
	for m in G["mesh"]:
		var pts := Geo.vers_vector2(m["xs"], m["ys"])
		var allume: bool = faisceau != "" and m["portal"] == faisceau
		var col := Color(String(G["dest_color"].get(m["portal"], "#ffffff")))
		draw_polyline(pts, Color(0, 0, 0, 0.40), 7.0, true)
		var levre := PackedVector2Array()
		for pt in pts:
			levre.append(pt + Vector2(0, -1.6))
		draw_polyline(levre, Color(Sty.POSTE_BORD, 0.10), 1.0, true)
		if allume:
			draw_polyline(pts, Color(col, 0.16), 9.0, true)
		# LES TRAVERSES, comme sur les voies d'entrée et de sortie. Le gril était
		# le seul tracé du plan à n'être qu'un trait : les voies d'approche
		# portaient leur ballast et leurs traverses depuis le 4 septembre, et
		# lui non. Elles sont à SA couleur, sous le rail — une traverse est sous
		# le rail, pas dessus — et discrètes : elles disent la voie ferrée, elles
		# ne disputent pas la destination, qui reste ce que la couleur signale.
		Sty.traverses(self, pts, Color(col, 0.34 if allume else 0.22), 2.8 * k, 10.0 * k)
		col.a = 0.82 if allume else 0.5
		draw_polyline(pts, col, 3.5, true)

	# --- les quais : la pilule en dégradé, son liseré, son numéro -------------
	var dead_ends := {}
	for q in fiche.get("platforms", []):
		if q is Dictionary and q.get("deadEnd", false):
			dead_ends[int(q["id"])] = true
	for q in G["platforms"]:
		var cy := float(q["cy"])
		var r := Rect2(Geo.PLAT_X1, cy - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
		var contour := Sty.rect_arrondi(r, 10)
		# LE QUAI EST UNE PLAQUE VISSÉE : bois sombre, liseré de laiton, numéro
		# gravé. Il reste assez sombre pour que la teinte d'un quai éligible
		# s'y lise — c'est elle qui compte, pas la matière.
		# L'OMBRE PORTÉE, d'abord : c'est elle qui décolle la plaque du pupitre.
		# Sans elle, huit rectangles peints à plat sur une planche ; avec elle,
		# huit plaques vissées dessus.
		var sous := PackedVector2Array()
		for pt in contour:
			sous.append(pt + Vector2(0, 3.0))
		var sous_ferme := sous.duplicate()
		sous_ferme.append(sous[0])
		draw_polyline(sous_ferme, Color(0, 0, 0, 0.34), 4.5, true)
		# LA LAMPE ÉCLAIRE AUSSI CE QUI EST POSÉ DESSUS. Elle tombait sur le
		# pupitre et s'arrêtait là : les quais gardaient tous exactement la même
		# valeur, où qu'ils soient sous elle. Une plaque proche de la lampe est
		# un peu plus claire, et c'est ce qui rattache l'objet à son éclairage.
		var haut := Sty.POSTE_QUAI_HAUT.lightened(0.07 * _part_de_lumiere(r.get_center()))
		var couleurs := PackedColorArray()
		for pt in contour:
			couleurs.append(haut.lerp(Sty.POSTE_QUAI_BAS, (pt.y - r.position.y) / r.size.y))
		draw_polygon(contour, couleurs)
		var ferme := contour.duplicate()
		ferme.append(contour[0])
		draw_polyline(ferme, Sty.POSTE_BORD, 1.8, true)
		# LE BISEAU : arête de lumière en haut, ombre en bas. Deux traits, et la
		# plaque cesse d'être un aplat pour devenir une épaisseur.
		draw_line(Vector2(r.position.x + 13, r.position.y + 2.2),
			Vector2(r.end.x - 13, r.position.y + 2.2), Color(1.0, 0.94, 0.80, 0.15), 2.0, true)
		draw_line(Vector2(r.position.x + 13, r.end.y - 2.2),
			Vector2(r.end.x - 13, r.end.y - 2.2), Color(0, 0, 0, 0.28), 2.0, true)
		# LES FILETS DE SÉCURITÉ ONT ÉTÉ RETIRÉS. Je les avais posés à six unités
		# du bord pour qu'une plaque devienne un QUAI ; le biseau, arrivé après,
		# passe à deux unités du même bord. Les deux paires se retrouvaient à
		# quatre unités l'une de l'autre : plus un quai, un double encadrement,
		# et l'œil y lisait une erreur d'impression. Le biseau gagne — il dit
		# une ÉPAISSEUR, ce qu'un filet ne dira jamais, et cet objet est de
		# toute façon une plaque de pupitre avant d'être un quai de gare.
		# les quatre vis qui la tiennent au pupitre
		for coin in [Vector2(r.position.x + 7, cy - Geo.PLAT_H / 2.0 + 7),
				Vector2(r.end.x - 7, cy - Geo.PLAT_H / 2.0 + 7),
				Vector2(r.position.x + 7, cy + Geo.PLAT_H / 2.0 - 7),
				Vector2(r.end.x - 7, cy + Geo.PLAT_H / 2.0 - 7)]:
			draw_circle(coin, 2.2, Color(Sty.POSTE_BORD, 0.45))
			draw_circle(coin + Vector2(0, -0.6), 1.2, Color(0, 0, 0, 0.35))
		Sty.texte_centre(self, sans_g, 24, r.get_center(), str(int(q["id"])), Color(Sty.PAPIER, 0.92))
		# le heurtoir du quai en impasse : rouge, avec son halo
		if dead_ends.has(int(q["id"])):
			var h := Rect2(Geo.PLAT_X2 + 4, cy - 13, 7, 26)
			draw_style_box(Sty.boite(Sty.ROUGE, Sty.ROUGE, 2, 0, 4, Color(Sty.ROUGE, 0.45)), h)

	# --- les portails : le point de convergence, et le nom au-dessus ----------
	for pname in G["portals"]:
		var p: Dictionary = G["portals"][pname]
		var col := Color(String(G["dest_color"].get(pname, "#ffffff")))
		# LE PORTAIL EST UNE LAMPE, sertie de laiton : un point coloré posé sur
		# un pupitre ne dit rien, une lampe allumée dit « c'est par là que ça
		# vient ». La teinte ne bouge pas d'un iota — c'est la destination.
		var c := Vector2(float(p["x"]), float(p["cy"]))
		draw_circle(c, 11.0, Color(col, 0.10))
		draw_circle(c, 7.5, Color(col, 0.18))
		draw_circle(c, 5.0, Color(col, 0.85))
		draw_arc(c, 6.4, 0.0, TAU, 24, Color(Sty.POSTE_BORD, 0.55), 1.2, true)
		var nom := String(p["label"])
		var pos := position_nom(pname)
		# EN CINZEL, ET NON EN GARAMOND. « Elle semble un peu fine globalement » :
		# EB Garamond est une romane ancienne, dont les déliés s'amincissent
		# encore sur un fond sombre. Un nom de gare sur un pupitre est GRAVÉ —
		# c'est exactement ce que la capitale lapidaire du jeu sait faire, et
		# elle porte deux fois plus de matière à taille égale.
		var t := taille_nom()
		if noms_allumes.has(pname):
			# « validé » : pleine couleur, halo à sa teinte
			Sty.texte_centre(self, grave, t, pos, nom, Color(col, 0.35), 7, Color(col, 0.35))
			Sty.texte_centre(self, grave, t, pos, nom, col, 3, Sty.POSTE_FOND)
		else:
			Sty.texte_centre(self, grave, t, pos, nom, Color(col, 0.80), 3, Sty.POSTE_FOND)

	# --- le cartouche de diagnostic, seul à l'écran --------------------------
	if cartouche:
		var pays := Donnees.pays_de(String(fiche.get("country", "")))
		draw_string(sans_g, Vector2(28, 40), "%s  %s" % [pays["nom"], String(fiche.get("name", ""))],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Sty.PAPIER)
		draw_string(Sty.sans(), Vector2(28, 62),
			"%d quais · %d directions · %d chemins · %d conflits" % [
				G["platforms"].size(), G["portals"].size(), G["paths"].size(), _nb_conflits()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Sty.MUET)


## LA PART DE LUMIÈRE reçue par un point du plan : un, sous la lampe ; zéro,
## dans l'angle le plus éloigné. La lampe du pupitre est posée en haut au
## milieu de l'ÉCRAN (vue_jeu.gd, Pupitre) — le plan est décalé pour se centrer
## dedans, donc c'est ce décalage qui fait le lien entre les deux repères.
func _part_de_lumiere(p: Vector2) -> float:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0:
		return 0.0
	var e := p + position
	var lampe := Vector2(vp.x / 2.0, vp.y * 0.10)
	return clampf(1.0 - e.distance_to(lampe) / (0.95 * vp.x), 0.0, 1.0)


func _nb_conflits() -> int:
	var n := 0
	for id in G["conflicts"]:
		n += G["conflicts"][id].size()
	return n / 2
