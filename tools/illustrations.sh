#!/bin/bash
# ------------------------------------------------------------------
# Dériver les illustrations pour le jeu.
#
#     tools/illustrations.sh
#
# Les originaux vivent dans `assets/da/` — c'est là qu'on dépose ce qui sort
# du générateur, en pleine résolution, et ce dossier porte un `.gdignore` :
# Godot ne le voit pas. Ce script en tire ce que l'application embarque,
# dans `jeu/illustrations/`.
#
# POURQUOI DEUX COPIES, alors que le projet tient à n'en avoir qu'une. Parce
# que ce ne sont pas deux copies de la même chose : l'une est la SOURCE
# (1536 × 1024, quatre mégaoctets pièce), l'autre un ARTEFACT DÉRIVÉ, taillé
# pour l'écran d'un téléphone. Les dix originaux pèsent 33 Mo ; embarqués
# tels quels ils feraient une application quatre fois plus lourde que le jeu
# lui-même, pour des images affichées à 240 pixels de haut. C'est exactement
# ce que fait déjà `tools/vers-json.mjs` avec `data/derive/`.
#
# Relancer après chaque dépôt dans `assets/da/`. Idempotent.
# ------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.."
SRC="assets/da"
DST="jeu/illustrations"
mkdir -p "$DST"

vert() { printf '\033[32m%s\033[0m\n' "$1"; }
rouge() { printf '\033[31m%s\033[0m\n' "$1"; }

# LA BANNIÈRE N'EST PLUS RECADRÉE ICI. Elle l'était, et le résultat coupait
# DEUX FOIS : une bande centrée à la dérivation, puis un second rognage à
# l'affichage, le panneau étant plus large encore que la bande. Le phare de
# l'Atlantique y a disparu. Le jeu choisit désormais sa bande lui-même, par
# une AtlasTexture (jeu/illustrations.gd) : un seul recadrage, et sur la
# partie qui porte le sujet plutôt que sur le milieu géométrique.
n=0
for f in "$SRC"/banniere-*.png; do
  [ -f "$f" ] || continue
  nom=$(basename "$f")
  cp "$f" "$DST/$nom"
  sips -Z 1024 "$DST/$nom" >/dev/null 2>&1
  n=$((n + 1))
done

# LA VIGNETTE EST UN TIMBRE. Elle s'affiche dans un carré d'environ soixante
# points ; 384 pixels lui laissent de la marge sur un écran à trois fois la
# densité, et rien de plus.
m=0
for f in "$SRC"/gare-*.png; do
  [ -f "$f" ] || continue
  nom=$(basename "$f")
  cp "$f" "$DST/$nom"
  sips -Z 384 "$DST/$nom" >/dev/null 2>&1
  m=$((m + 1))
done

# LES VÉHICULES GRAVÉS — une planche par véhicule, ENTIÈRE dans sa case.
#
# La première chaîne découpait une voiture allongée en trois tranches et les
# répétait : le compte des voitures était juste, mais chaque case ne montrait
# qu'un MORCEAU de véhicule. « On doit les voir en entier » (Vincent, 8
# septembre 2026), et c'est évidemment la bonne réponse : une case du gril est
# un véhicule, pas un fragment. Les planches sont donc redessinées au format de
# la case — 35 sur 30, presque carré — et posées telles quelles, une par
# voiture. Plus de tranches, plus de raccord, plus de nervure qui compte double.
#
# TROIS OPÉRATIONS, ET RIEN D'AUTRE.
#
# ON REDRESSE si le générateur a dessiné debout : le jeu fait rouler de gauche
# à droite.
#
# ON DÉTOURE PAR LE DEHORS, puis on ROGNE À LA BOÎTE du sujet. Il faut deux
# choses de la même planche : la SILHOUETTE, pour y couler le lavis de
# destination, et le GRIS du dessin, pour poser le trait. Un simple seuil sur le
# blanc ne donne ni l'une ni l'autre — il rendrait transparent le blanc du
# papier À L'INTÉRIEUR du véhicule, et le lavis ne remplirait que les traits ;
# mon premier essai a sorti une rame noire. On propage donc depuis les bords.
# La boîte du sujet sert ensuite à jeter les marges blanches, sans quoi le
# véhicule flotterait dans sa case.
#
# ON ALLÈGE L'ENCRAGE de moitié. À pleine force la gravure porte son propre
# ombré et mange la vivacité de la couleur — or ici la couleur EST la
# destination, et à la taille réelle du jeu c'est elle qui doit se lire en
# premier. Le trait reste, le modelé s'allège. Un seul nombre, `ENCRAGE`.
# DEUX SÉRIES, ET ELLES NE DISENT PAS LA MÊME CHOSE. Les planches sans suffixe
# sont vues DE HAUT : c'est le poste, qui est un plan d'aiguillage et se lit
# comme tel. Celles en `-profil` sont des ÉLÉVATIONS, dessinées le 9 septembre
# 2026 pour la tentative de vue oblique — abandonnée le jour même —, et elles
# servent aujourd'hui à l'écran d'attente, où un train de profil vaut mieux
# qu'un toit. La même dérivation convient aux deux.
for f in "$SRC"/loco.png "$SRC"/wagon.png "$SRC"/fourgon.png \
         "$SRC"/loco-profil.png "$SRC"/wagon-profil.png "$SRC"/fourgon-profil.png; do
  [ -f "$f" ] || continue
  nom=$(basename "$f")
  cp "$f" "$DST/$nom"
  python3 - "$DST/$nom" <<'PYEOF'
import sys, zlib, struct
ENCRAGE = 0.50
exec(open("tools/lire_png.py").read())
w,h,bpp,px = lire(sys.argv[1])
def lum(x,y):
    o=y*w*bpp+x*bpp
    return (px[o]*3+px[o+1]*6+px[o+2])//10
dehors=bytearray(w*h); pile=[]
for x in range(w):
    for y in (0,h-1):
        if lum(x,y)>=232 and not dehors[y*w+x]: dehors[y*w+x]=1; pile.append((x,y))
for y in range(h):
    for x in (0,w-1):
        if lum(x,y)>=232 and not dehors[y*w+x]: dehors[y*w+x]=1; pile.append((x,y))
while pile:
    x,y=pile.pop()
    for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
        a,b=x+dx,y+dy
        if 0<=a<w and 0<=b<h and not dehors[b*w+a] and lum(a,b)>=232:
            dehors[b*w+a]=1; pile.append((a,b))
x0,y0,x1,y1 = w,h,0,0
for y in range(h):
    for x in range(w):
        if not dehors[y*w+x]:
            if x<x0: x0=x
            if x>x1: x1=x
            if y<y0: y0=y
            if y>y1: y1=y
debout = (y1-y0) > (x1-x0)
lw = (y1-y0+1) if debout else (x1-x0+1)
lh = (x1-x0+1) if debout else (y1-y0+1)
def src(i,j):
    # couché : (x0+i, y0+j) ; debout : on tourne d'un quart de tour
    return (x0+j, y1-i) if debout else (x0+i, y0+j)
out=bytearray()
for j in range(lh):
    for i in range(lw):
        x,y = src(i,j)
        g = min(255, 255 - int((255 - lum(x,y)) * ENCRAGE))
        out += bytes((g,g,g, 0 if dehors[y*w+x] else 255))
raw=b''.join(b'\x00'+bytes(out[j*lw*4:(j+1)*lw*4]) for j in range(lh))
def ch(t,d):
    c=t+d; return struct.pack('>I',len(d))+c+struct.pack('>I',zlib.crc32(c))
open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\x0a'[:8]+ch(b'IHDR',struct.pack('>IIBBBBB',lw,lh,8,6,0,0,0))+ch(b'IDAT',zlib.compress(raw,6))+ch(b'IEND',b''))
print("  %s : %d x %d%s" % (sys.argv[1].split("/")[-1], lw, lh, ", redressé" if debout else ""))
PYEOF
  sips -Z 256 "$DST/$nom" >/dev/null 2>&1
  m=$((m + 1))
done

if [ $((n + m)) -eq 0 ]; then
  rouge "aucune image dans $SRC — voir $SRC/LISEZ-MOI.md pour les noms attendus"
  exit 1
fi
avant=$(du -sh "$SRC" | cut -f1)
apres=$(du -sh "$DST" | cut -f1)
vert "$n bannière(s) et $m vignette(s) dérivées — $avant en source, $apres embarqués"
