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

# LA VOITURE GRAVÉE — trois opérations, et chacune répond à un besoin précis.
#
# ON LA COUCHE : le générateur dessine une voiture debout, le jeu la fait
# rouler de gauche à droite.
#
# ON LA DÉTOURE PAR LE DEHORS, et c'est la subtilité. Il faut DEUX choses de
# la même planche : la SILHOUETTE de la voiture, pour y couler le lavis de
# destination, et l'ENCRE, pour poser le trait par-dessus. Un simple seuil sur
# le blanc ne donne ni l'une ni l'autre : il rendrait transparent le blanc du
# papier À L'INTÉRIEUR de la caisse, et le lavis ne remplirait que les traits.
# On propage donc depuis les bords : tout le blanc qui communique avec
# l'extérieur devient transparent, le reste est la caisse. Le canal alpha porte
# la silhouette, les canaux de couleur portent le gris du dessin — le jeu
# multiplie l'un par la teinte de destination et obtient une gravure mise en
# couleur, en une seule passe et avec une seule planche pour les six teintes.
#
# ON LA RÉDUIT à 640 points de long : la rame fait trente unités de haut à
# l'écran, la moitié de la trame fine disparaîtra de toute façon. Garder
# davantage ne coûterait que des octets.
if [ -f "$SRC/wagon.png" ]; then
  cp "$SRC/wagon.png" "$DST/wagon.png"
  sips -c 1620 348 "$DST/wagon.png" >/dev/null 2>&1     # le sujet est centré
  sips -r 90 "$DST/wagon.png" >/dev/null 2>&1
  sips -Z 640 "$DST/wagon.png" >/dev/null 2>&1
  python3 - "$DST/wagon.png" <<'PYEOF'
import sys, zlib, struct
ENCRAGE = 0.50
def lire(p):
    d=open(p,'rb').read(); i=8; idat=b''; w=hh=0; bd=ct=0
    while i < len(d):
        ln=struct.unpack('>I',d[i:i+4])[0]; t=d[i+4:i+8]; dat=d[i+8:i+8+ln]; i+=12+ln
        if t==b'IHDR': w,hh,bd,ct=struct.unpack('>IIBB',dat[:10])
        elif t==b'IDAT': idat+=dat
        elif t==b'IEND': break
    raw=zlib.decompress(idat); nc={0:1,2:3,3:1,4:2,6:4}[ct]; bpp=nc*bd//8; st=w*bpp
    out=bytearray(); prev=bytearray(st); p2=0
    for y in range(hh):
        f=raw[p2]; p2+=1; ln2=bytearray(raw[p2:p2+st]); p2+=st
        for x in range(st):
            a=ln2[x-bpp] if x>=bpp else 0; b=prev[x]; c=prev[x-bpp] if x>=bpp else 0
            if f==1: ln2[x]=(ln2[x]+a)&255
            elif f==2: ln2[x]=(ln2[x]+b)&255
            elif f==3: ln2[x]=(ln2[x]+(a+b)//2)&255
            elif f==4:
                pa=abs(b-c); pb=abs(a-c); pc=abs(a+b-2*c)
                pr=a if (pa<=pb and pa<=pc) else (b if pb<=pc else c)
                ln2[x]=(ln2[x]+pr)&255
        out+=ln2; prev=ln2
    return w,hh,bpp,bytes(out)
w,h,bpp,px = lire(sys.argv[1])
def lum(x,y):
    o=y*w*bpp+x*bpp
    return (px[o]*3+px[o+1]*6+px[o+2])//10
# le dehors, par propagation depuis les bords sur ce qui est presque blanc
dehors=bytearray(w*h)
pile=[]
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
out=bytearray()
for y in range(h):
    for x in range(w):
        # LA FORCE D'ENCRAGE. À pleine force, la gravure porte son propre
        # ombré et mange la vivacité de la couleur — or ici la couleur EST la
        # destination, et à la taille réelle du jeu c'est elle qui doit se lire
        # en premier. On éclaircit donc le gris de moitié : le trait reste, le
        # modelé s'allège, et le lavis ressort. Un seul nombre à changer.
        g=min(255, 255 - int((255 - lum(x,y)) * ENCRAGE))
        out += bytes((g,g,g, 0 if dehors[y*w+x] else 255))
raw=b''.join(b'\x00'+bytes(out[y*w*4:(y+1)*w*4]) for y in range(h))
def ch(t,d):
    c=t+d; return struct.pack('>I',len(d))+c+struct.pack('>I',zlib.crc32(c))
open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\x0a'[:8]+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+ch(b'IDAT',zlib.compress(raw,6))+ch(b'IEND',b''))
print("  wagon : %d x %d, silhouette et encre séparées" % (w,h))
PYEOF
  m=$((m + 1))
fi

# LA LOCOMOTIVE — même chaîne que la voiture, avec DEUX opérations de plus.
#
# ON LAISSE LE TENDER. Le générateur en a dessiné un, superbe et encombrant :
# la planche fait un pour quatre virgule sept là où il en fallait deux. Or la
# tête d'une rame occupe une place bornée par la longueur du convoi le plus
# court — deux voitures, soit soixante-cinq unités en tout. On ne garde donc
# que la MACHINE, de la cabine à la cheminée, et le tender reste dans les
# sources au cas où il servirait un jour.
#
# ON LA RETOURNE. Le jeu pose la tranche de tête au DÉBUT de la rame, et lit
# la planche de gauche à droite : la cheminée doit donc se trouver à gauche,
# alors qu'elle est à droite sur le dessin couché.
if [ -f "$SRC/loco.png" ]; then
  cp "$SRC/loco.png" "$DST/loco.png"
  sips -c 1760 380 "$DST/loco.png" >/dev/null 2>&1
  sips -r 90 "$DST/loco.png" >/dev/null 2>&1
  sips -Z 700 "$DST/loco.png" >/dev/null 2>&1
  python3 - "$DST/loco.png" 0.307 1 <<'PYEOF'
import sys, zlib, struct
ENCRAGE = 0.50
exec(open("tools/lire_png.py").read())
w,h,bpp,px = lire(sys.argv[1])
d0 = int(float(sys.argv[2]) * w)
miroir = sys.argv[3] == "1"
w2 = w - d0
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
out=bytearray()
for y in range(h):
    for i in range(w2):
        x = (w - 1 - i) if miroir else (d0 + i)
        # LA FORCE D'ENCRAGE. À pleine force, la gravure porte son propre
        # ombré et mange la vivacité de la couleur — or ici la couleur EST la
        # destination, et à la taille réelle du jeu c'est elle qui doit se lire
        # en premier. On éclaircit donc le gris de moitié : le trait reste, le
        # modelé s'allège, et le lavis ressort. Un seul nombre à changer.
        g=min(255, 255 - int((255 - lum(x,y)) * ENCRAGE))
        out += bytes((g,g,g, 0 if dehors[y*w+x] else 255))
raw=b''.join(b'\x00'+bytes(out[y*w2*4:(y+1)*w2*4]) for y in range(h))
def ch(t,d):
    c=t+d; return struct.pack('>I',len(d))+c+struct.pack('>I',zlib.crc32(c))
open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\x0a'[:8]+ch(b'IHDR',struct.pack('>IIBBBBB',w2,h,8,6,0,0,0))+ch(b'IDAT',zlib.compress(raw,6))+ch(b'IEND',b''))
print("  loco : %d x %d, machine seule, retournée" % (w2,h))
PYEOF
  m=$((m + 1))
fi

if [ $((n + m)) -eq 0 ]; then
  rouge "aucune image dans $SRC — voir $SRC/LISEZ-MOI.md pour les noms attendus"
  exit 1
fi
avant=$(du -sh "$SRC" | cut -f1)
apres=$(du -sh "$DST" | cut -f1)
vert "$n bannière(s) et $m vignette(s) dérivées — $avant en source, $apres embarqués"
