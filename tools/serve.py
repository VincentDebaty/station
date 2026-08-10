#!/usr/bin/env python3
"""Serveur de développement — comme `python3 -m http.server`, mais SANS cache.

`http.server` n'envoie aucun en-tête Cache-Control. Face à ce silence, Safari
applique une « fraîcheur heuristique » : il réutilise un fichier déjà vu sans
même demander au serveur s'il a changé. Sur iPhone, on s'est ainsi retrouvé
avec un engine.js de la veille et un game.js du jour — variable introuvable,
plan vide. `Cache-Control: no-store` supprime la classe entière du problème :
chaque rechargement repart du disque.

Le cache du service worker, lui, n'est pas touché : le jeu reste jouable
hors-ligne (voir sw.js).

    python3 tools/serve.py [port]     # défaut : 8000
"""
import http.server
import socket
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def lan_ip():
    """Adresse de la machine sur le réseau local, pour ouvrir depuis le téléphone."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))   # aucune donnée envoyée : juste le routage
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


if __name__ == "__main__":
    print("Station — serveur de développement (sans cache)")
    print("  Mac     : http://localhost:%d/station.html" % PORT)
    print("  iPhone  : http://%s:%d/station.html   (même Wi-Fi)" % (lan_ip(), PORT))
    print("  Ctrl-C pour arrêter.")
    http.server.ThreadingHTTPServer(("", PORT), NoCacheHandler).serve_forever()
