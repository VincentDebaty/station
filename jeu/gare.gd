extends Node2D
## UNE GARE QUI SE DESSINE DEPUIS SA FICHE — deuxième jalon du portage.
##
##   godot --path . res://jeu/gare.tscn                (Darlington)
##   STATION_GARE=namur godot --path . res://jeu/gare.tscn
##
## Rien n'est jouable : pas de convoi, pas de temps. Ce que cet écran prouve,
## c'est que Geo.construire() produit, pour n'importe laquelle des 401
## fiches, un plan qui se lit — et que le KIT tient : un quai, une voie, un
## portail, et rien qui soit peint pour une gare en particulier.
##
## Le dessin se fait dans _draw(), pas avec des nœuds : à ce stade il n'y a
## aucune interaction, et un Line2D par chemin ferait 30 nœuds pour dire ce
## que dix lignes disent. Le vrai écran de jeu choisira ses nœuds quand il
## saura ce qu'il doit faire bouger.
##
## LES COULEURS SONT CELLES DU PROTOTYPE (css/station.css, :root), parce que
## l'esthétique est conservée telle quelle (plan-de-dev.md, « Ce qu'on ne fait
## pas ») — et surtout parce que la couleur d'une voie est la DESTINATION,
## contrat qui ne se rediscute pas (PORTAGE-GODOT.md §4).

# PRELOAD, PAS class_name : le cache des classes globales n'est construit que
# par l'éditeur. Un projet cloné et lancé en ligne de commande ne connaîtrait
# jamais « Geometrie ». Le chemin, lui, existe toujours.
const Geo := preload("res://jeu/geometrie.gd")
const Cap := preload("res://jeu/capture.gd")

const FOND := Color("#0E1420")
const PANNEAU := Color("#151d2e")
const BORD := Color("#2a3550")
const VOIE_SOMBRE := Color("#323d4f")
const TEXTE := Color("#dbe2ee")
const MUET := Color("#7a8699")

var G: Dictionary = {}
var fiche: Dictionary = {}


func _ready() -> void:
	var id := OS.get_environment("STATION_GARE")
	if id == "":
		id = "darlington"
	fiche = Donnees.fiche(id)
	if fiche.is_empty():
		push_error("gare inconnue : " + id)
		return
	G = Geo.construire(fiche)
	queue_redraw()
	Cap.eventuelle(self)


func _draw() -> void:
	if G.is_empty():
		return
	var police := ThemeDB.fallback_font

	# --- voies d'approche et de départ : la fuite vers le bord ---------------
	for pname in G["approach"]:
		var a: Dictionary = G["approach"][pname]
		draw_polyline(Geo.vers_vector2(a["xs"], a["ys"]), VOIE_SOMBRE, 3.0, true)
		var d: Dictionary = G["depart"][pname]
		draw_polyline(Geo.vers_vector2(d["xs"], d["ys"]), VOIE_SOMBRE, 3.0, true)

	# --- le gril : une bézier par liaison, à la couleur de sa destination ----
	for m in G["mesh"]:
		var col := Color(String(G["dest_color"].get(m["portal"], "#ffffff")))
		col.a = 0.55
		draw_polyline(Geo.vers_vector2(m["xs"], m["ys"]), col, 3.0, true)

	# --- les quais -----------------------------------------------------------
	for q in G["platforms"]:
		var cy := float(q["cy"])
		var r := Rect2(Geo.PLAT_X1, cy - Geo.PLAT_H / 2.0, Geo.PLAT_LEN, Geo.PLAT_H)
		draw_rect(r, PANNEAU, true)
		draw_rect(r, BORD, false, 1.5)
		var num := str(int(q["id"]))     # le JSON livre 1.0, le quai s'appelle 1
		var larg := police.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(police, Vector2(Geo.PLAT_MID - larg / 2.0, cy + 7), num,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, MUET)

	# --- les portails : un point et un nom, à la couleur de la destination ---
	for pname in G["portals"]:
		var p: Dictionary = G["portals"][pname]
		var col := Color(String(G["dest_color"].get(pname, "#ffffff")))
		var centre := Vector2(float(p["x"]), float(p["cy"]))
		draw_circle(centre, 5.0, col)
		var nom := String(p["label"])
		var larg := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var x := centre.x - larg / 2.0
		draw_string(police, Vector2(x, centre.y - 16), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

	# --- le cartouche, comme dans le prototype -------------------------------
	var pays := Donnees.pays_de(String(fiche.get("country", "")))
	draw_string(police, Vector2(28, 40), "%s  %s" % [pays["drapeau"], String(fiche.get("name", ""))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXTE)
	draw_string(police, Vector2(28, 62),
		"%d quais · %d directions · %d chemins · %d conflits" % [
			G["platforms"].size(), G["portals"].size(), G["paths"].size(), _nb_conflits()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUET)


func _nb_conflits() -> int:
	var n := 0
	for id in G["conflicts"]:
		n += G["conflicts"][id].size()
	return n / 2
