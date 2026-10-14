#!/bin/bash
# ------------------------------------------------------------------
# Poser la tranche Godot du LABYRINTHE D'EAU sur l'iPhone — export,
# signature, installation, lancement.
#
#     tools/ios-labyrinthe.sh              exporte, installe et lance
#     tools/ios-labyrinthe.sh --export     exporte et signe seulement
#     tools/ios-labyrinthe.sh --etat       dit ce qui manque, sans rien faire
#
# Copie de tools/ios-ecluses.sh (et donc petit frère de tools/ios.sh) : même
# compte, même équipe, même gabarit Godot 4.7.2, mêmes pièges — leurs
# explications sont là-bas. Ce qui change : le projet
# (prototypes/labyrinthe-godot), l'identifiant (be.vincentdebaty.labyrinthe),
# et la sortie (~/Library/Caches/Labyrinthe-ios).
#
# Le préréglage d'export, prototypes/labyrinthe-godot/export_presets.cfg, est
# IGNORÉ PAR GIT : il porte l'équipe Apple et les identités de signature de
# cette machine. Dérivé de celui d'Écluses le 14 octobre 2026 (seuls changent
# export_path et bundle_identifier) ; sur une autre machine, le refaire de la
# même façon.
# ------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.."
RACINE="$PWD"
PROJET_GODOT="$RACINE/prototypes/labyrinthe-godot"
SORTIE="$HOME/Library/Caches/Labyrinthe-ios"
PROJET="$SORTIE/Labyrinthe.xcodeproj"
BUNDLE=$(grep -E '^application/bundle_identifier' "$PROJET_GODOT/export_presets.cfg" 2>/dev/null | cut -d'"' -f2)
JOURNAL=/tmp/labyrinthe-ios-export.log

rouge() { printf '\033[31m%s\033[0m\n' "$1"; }
vert()  { printf '\033[32m%s\033[0m\n' "$1"; }

if [ -z "${BUNDLE}" ]; then
  rouge "pas de préréglage d'export : prototypes/labyrinthe-godot/export_presets.cfg (voir l'en-tête)"
  exit 1
fi

# Un VRAI iPhone jumelé, au bout d'un fil ou par le Wi-Fi (Vincent, 10 octobre
# 2026 : « voir le résultat du jeu sur mon iPhone sans qu'il soit branché au
# Mac ») — jamais l'Apple Watch, jointe elle aussi par le réseau : on trie sur
# le type d'appareil, plus sur le seul fil. Le fil passe devant le Wi-Fi.
# Depuis Xcode 15, un iPhone jumelé une fois par câble est joignable par le
# réseau sans rien cocher, Mac et iPhone sur le même Wi-Fi. Lu en JSON (le
# tableau de devicectl se découpe mal) — cf. tools/ios.sh.
appareil() {
  xcrun devicectl list devices --json-output /tmp/labyrinthe-ios-dev.json >/dev/null 2>&1
  python3 -c "
import json
try:
    d = json.load(open('/tmp/labyrinthe-ios-dev.json'))
except Exception:
    raise SystemExit
def iphone(x):
    h = x.get('hardwareProperties', {})
    p = x.get('connectionProperties', {})
    return (h.get('deviceType') == 'iPhone' and h.get('reality') == 'physical'
            and p.get('pairingState') == 'paired'
            and p.get('transportType') in ('wired', 'localNetwork'))
def note(x):
    p = x.get('connectionProperties', {})
    n = 4 if p.get('transportType') == 'wired' else 0
    if p.get('tunnelState') == 'connected': n += 2
    return n
cands = sorted([x for x in d['result']['devices'] if iphone(x)], key=note, reverse=True)
if cands:
    print(cands[0]['identifier'])
" 2>/dev/null
}

if [ "${1:-}" = "--etat" ]; then
  echo "identifiant   : ${BUNDLE}"
  n_comptes=$(defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists 2>/dev/null | grep -c "identifier = ")
  if [ "${n_comptes:-0}" -gt 0 ]; then vert "compte Xcode  : présent"; else rouge "compte Xcode  : AUCUN — Xcode → Réglages → Comptes"; fi
  ID=$(appareil)
  if [ -n "${ID}" ]; then vert "iPhone        : joignable (${ID})"; else rouge "iPhone        : AUCUN — le brancher, ou le déverrouiller sur le même Wi-Fi que le Mac"; fi
  [ -d "$PROJET" ] && echo "dernier export : $(stat -f '%Sm' "$PROJET")" || echo "dernier export : aucun"
  exit 0
fi

# --- l'export : Godot pose le projet Xcode, le compile et le signe ----------
# « error: » ou « ERROR: », jamais « error » tout court (ibtool écrit
# `--errors` dans sa ligne de commande : un export réussi passait pour un
# échec — tools/ios.sh, 3 septembre 2026).
echo "→ export du projet Xcode…"
mkdir -p "$SORTIE"
godot --headless --path "$PROJET_GODOT" --import > /dev/null 2>&1
godot --headless --path "$PROJET_GODOT" --export-debug "iOS" "$PROJET" > "$JOURNAL" 2>&1
if grep -qE "error:|^ERROR:|BUILD FAILED" "$JOURNAL"; then
  rouge "  l'export a rendu une erreur :"
  grep -E "error:|^ERROR:|BUILD FAILED" "$JOURNAL" | head -6 | sed 's/^/    /'
  # Un identifiant neuf demande un profil neuf. Godot lance xcodebuild sans
  # -allowProvisioningDeviceRegistration : avec un iPhone branché, on refait
  # la compilation avec, ce qui crée le profil (remède du 20 septembre 2026).
  ID=$(appareil)
  if grep -qiE "profile|provision|no devices" "$JOURNAL" && [ -n "${ID}" ]; then
    echo "→ création du profil pour ${BUNDLE}, avec l'iPhone ${ID}…"
    ( cd "$SORTIE" && xcodebuild -project Labyrinthe.xcodeproj -scheme Labyrinthe -destination "id=${ID}" \
        -allowProvisioningUpdates -allowProvisioningDeviceRegistration build ) > /tmp/labyrinthe-ios-profil.log 2>&1 \
      && vert "  profil créé — relancer ce script" \
      || { rouge "  échec, voir /tmp/labyrinthe-ios-profil.log"; grep -E "error:" /tmp/labyrinthe-ios-profil.log | head -4 | sed 's/^/    /'; }
  else
    echo "  Si elle parle de profil : brancher l'iPhone et relancer (le profil se crée alors)."
    echo "  Journal complet : $JOURNAL"
  fi
  exit 1
fi
vert "  projet exporté et signé"
[ "${1:-}" = "--export" ] && exit 0

# --- l'installation, puis le lancement -------------------------------------
# L'application de l'APPAREIL est celle de l'archive (cf. tools/ios.sh, 9 septembre 2026).
APP=$(find "$SORTIE/Labyrinthe.xcarchive" -name "*.app" -maxdepth 4 2>/dev/null | head -1)
[ -n "${APP}" ] || APP=$(find "$SORTIE" -name "*.app" -maxdepth 5 2>/dev/null | head -1)
if [ -z "${APP}" ]; then
  rouge "aucune application produite — voir $JOURNAL"
  exit 1
fi
ID=$(appareil)
if [ -z "${ID}" ]; then
  rouge "aucun iPhone joignable (ni fil, ni Wi-Fi) : l'export est prêt, il ne reste qu'à installer"
  exit 1
fi
echo "→ installation sur ${ID}…"
xcrun devicectl device install app --device "${ID}" "${APP}" || exit 1
echo "→ lancement…"
xcrun devicectl device process launch --device "${ID}" "${BUNDLE}"
vert "posé sur l'iPhone. Les compteurs (images par seconde, millisecondes) sont en haut de l'écran."
