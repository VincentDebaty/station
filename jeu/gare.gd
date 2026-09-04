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


## Où se pose le nom d'un portail : au-dessus de l'aiguillage, à 34 px au
## plus, borné à 40 % de l'écart au voisin du même côté (js/render.js).
func position_nom(pname: String) -> Vector2:
	var p: Dictionary = G["portals"][pname]
	var cy := float(p["cy"])
	var gap := INF
	for autre in G["portals"]:
		var q: Dictionary = G["portals"][autre]
		if autre != pname and q["side"] == p["side"]:
			gap = min(gap, absf(float(q["cy"]) - cy))
	return Vector2(float(p["x"]), cy - min(34.0, gap * 0.40))


func _draw() -> void:
	if G.is_empty():
		return
	var sans_g := Sty.sans(600)

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
	for m in G["mesh"]:
		var col := Color(String(G["dest_color"].get(m["portal"], "#ffffff")))
		col.a = 0.82 if (faisceau != "" and m["portal"] == faisceau) else 0.5
		draw_polyline(Geo.vers_vector2(m["xs"], m["ys"]), col, 3.5, true)

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
		var couleurs := PackedColorArray()
		for pt in contour:
			couleurs.append(Sty.POSTE_QUAI_HAUT.lerp(Sty.POSTE_QUAI_BAS, (pt.y - r.position.y) / r.size.y))
		draw_polygon(contour, couleurs)
		var ferme := contour.duplicate()
		ferme.append(contour[0])
		draw_polyline(ferme, Sty.POSTE_BORD, 1.8, true)
		Sty.texte_centre(self, sans_g, 24, r.get_center(), str(int(q["id"])), Color(Sty.PAPIER, 0.92))
		# le heurtoir du quai en impasse : rouge, avec son halo
		if dead_ends.has(int(q["id"])):
			var h := Rect2(Geo.PLAT_X2 + 4, cy - 13, 7, 26)
			draw_style_box(Sty.boite(Sty.ROUGE, Sty.ROUGE, 2, 0, 4, Color(Sty.ROUGE, 0.45)), h)

	# --- les portails : le point de convergence, et le nom au-dessus ----------
	for pname in G["portals"]:
		var p: Dictionary = G["portals"][pname]
		var col := Color(String(G["dest_color"].get(pname, "#ffffff")))
		draw_circle(Vector2(float(p["x"]), float(p["cy"])), 5.0, Color(col, 0.85))
		var nom := String(p["label"])
		var pos := position_nom(pname)
		if noms_allumes.has(pname):
			# « validé » : pleine couleur, halo à sa teinte
			Sty.texte_centre(self, sans_g, 15, pos, nom, Color(col, 0.35), 7, Color(col, 0.35))
			Sty.texte_centre(self, sans_g, 15, pos, nom, col, 3, Sty.POSTE_FOND)
		else:
			Sty.texte_centre(self, sans_g, 15, pos, nom, Color(col, 0.72), 3, Sty.POSTE_FOND)

	# --- le cartouche de diagnostic, seul à l'écran --------------------------
	if cartouche:
		var pays := Donnees.pays_de(String(fiche.get("country", "")))
		draw_string(sans_g, Vector2(28, 40), "%s  %s" % [pays["drapeau"], String(fiche.get("name", ""))],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Sty.PAPIER)
		draw_string(Sty.sans(), Vector2(28, 62),
			"%d quais · %d directions · %d chemins · %d conflits" % [
				G["platforms"].size(), G["portals"].size(), G["paths"].size(), _nb_conflits()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Sty.MUET)


func _nb_conflits() -> int:
	var n := 0
	for id in G["conflicts"]:
		n += G["conflicts"][id].size()
	return n / 2
