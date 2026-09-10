extends Node
## LE MAGASIN — ce qui se vend, et par où l'argent passe (economie-du-jeu.md
## §6, lot 3, 10 septembre 2026).
##
## Le modèle est tranché : la première carte est gratuite et complète, les
## cartes suivantes se paient (en pièces, ou ici en argent), et un pack prend
## toutes les cartes. On ne vend JAMAIS de pièces, de pierres, d'étoiles, de
## rangs, de médailles ni de temps — data/boutique.json le dit,
## tools/boutique-check.mjs le refuse. Le contenu se vend, pas la progression.
##
## TROIS DOS, UNE SEULE PORTE. Le reste du jeu n'appelle que `acheter(id)` et
## écoute `fini` ; ce qui se passe derrière dépend de la plateforme :
##   « plateforme »  le singleton InAppStore du greffon iOS de Godot est là :
##                   StoreKit fait le paiement, on accorde à l'événement.
##   « libre »       STATION_MAGASIN=libre — le déblocage de débogage que
##                   le design prévoyait : on accorde tout de suite, sans
##                   payer. Pour voir les écrans et jouer la suite.
##   « aucun »       ni l'un ni l'autre : l'offre s'affiche avec son prix, le
##                   bouton dit pourquoi il ne fait rien.
## Le raccord StoreKit suit l'interface du greffon (request_product_info,
## purchase, restore_purchases, pop_pending_event) et N'A PAS ÉTÉ EXERCÉ
## ici : le greffon n'est pas dans le dépôt, et le magasin d'Apple ne se
## simule pas. Il est écrit pour que la version publiée n'ait rien d'autre à
## faire qu'ajouter le greffon et déclarer les produits.
##
## CE QUI EST ACCORDÉ EST ÉCRIT DANS LA SAUVEGARDE, et rien d'autre : une
## carte → `possedees[id] = "achat"`, le pack → `possessions["pack-du-poste"]
## = "achat"` plus toutes les cartes. L'accès aux cartes s'en déduit.

signal fini(offre_id: String, ok: bool, message: String)

const PACK := "pack-du-poste"
const EXPLICATION := "Le paiement arrivera avec la version publiée."

var dos := "aucun"          ## « plateforme » | « libre » | « aucun »
var prix_reels := {}        ## produit -> prix localisé rendu par le magasin
var en_cours := ""          ## l'offre dont on attend le paiement
var _store: Object = null


func _ready() -> void:
	if OS.get_environment("STATION_MAGASIN") == "libre":
		dos = "libre"
	elif Engine.has_singleton("InAppStore"):
		dos = "plateforme"
		_store = Engine.get_singleton("InAppStore")
		_store.set_auto_finish_transaction(true)
		var ids := PackedStringArray()
		for o in offres():
			ids.append(String(o.get("produit", "")))
		_store.request_product_info({"product_ids": ids})


# --- Le catalogue ---------------------------------------------------------------
func offres() -> Array:
	var b: Dictionary = Donnees.boutique
	return b["offres"] if b.get("offres") is Array else []


func offre(id: String) -> Dictionary:
	for o in offres():
		if String(o.get("id", "")) == id:
			return o
	return {}


func offre_de_carte(carte_id: String) -> Dictionary:
	for o in offres():
		if o.get("type") == "carte" and String(o.get("carte", "")) == carte_id:
			return o
	return {}


func offre_pack() -> Dictionary:
	for o in offres():
		if o.get("type") == "pack":
			return o
	return {}


## Le prix à écrire : celui du magasin s'il a répondu, sinon celui du catalogue.
func prix_de(o: Dictionary) -> String:
	return String(prix_reels.get(String(o.get("produit", "")), o.get("prix", "")))


func disponible() -> bool:
	return dos != "aucun"


func possede_pack() -> bool:
	return Sauvegarde.possede(PACK)


# --- Acheter -----------------------------------------------------------------------
func acheter(id: String) -> void:
	var o := offre(id)
	if o.is_empty():
		fini.emit(id, false, "Offre inconnue.")
		return
	match dos:
		"libre":
			_accorder(o)
			fini.emit(id, true, "")
		"plateforme":
			if en_cours != "":
				fini.emit(id, false, "Un achat est déjà en cours.")
				return
			en_cours = id
			_store.purchase({"product_id": String(o.get("produit", ""))})
		_:
			fini.emit(id, false, EXPLICATION)


## Les achats non consommables (cartes, pack) se retrouvent depuis le magasin.
func restaurer() -> void:
	match dos:
		"plateforme":
			_store.restore_purchases()
		"libre":
			fini.emit("restaurer", true, "Rien à restaurer ici.")
		_:
			fini.emit("restaurer", false, EXPLICATION)


func _accorder(o: Dictionary) -> void:
	match String(o.get("type", "")):
		"carte":
			Sauvegarde.acquerir_carte(String(o.get("carte", "")), "achat")
		"pack":
			Sauvegarde.acquerir_possession(PACK, "achat")
			for e in Donnees.cartes_index:
				var cid := String(e.get("id", ""))
				if not Sauvegarde.possede_carte(cid):
					Sauvegarde.acquerir_carte(cid, "achat")


func _offre_du_produit(produit: String) -> Dictionary:
	for o in offres():
		if String(o.get("produit", "")) == produit:
			return o
	return {}


# --- Les événements du magasin de la plateforme --------------------------------
func _process(_delta: float) -> void:
	if dos != "plateforme" or _store == null:
		return
	while _store.get_pending_event_count() > 0:
		var ev: Dictionary = _store.pop_pending_event()
		match String(ev.get("type", "")):
			"product_info":
				var ids: Array = ev.get("ids", [])
				var prix: Array = ev.get("localized_prices", [])
				for i in mini(ids.size(), prix.size()):
					prix_reels[String(ids[i])] = String(prix[i])
			"purchase":
				var o := _offre_du_produit(String(ev.get("product_id", "")))
				var id := String(o.get("id", en_cours))
				if ev.get("result") == "ok":
					_accorder(o)
					en_cours = ""
					fini.emit(id, true, "")
				elif ev.get("result") != "progress":
					en_cours = ""
					fini.emit(id, false, "Le paiement n'a pas abouti.")
			"restore":
				var o := _offre_du_produit(String(ev.get("product_id", "")))
				if ev.get("result") == "ok" and not o.is_empty():
					_accorder(o)
					fini.emit(String(o.get("id", "")), true, "")
