#!/bin/sh
# ~/.config/hypr/radio.sh — lecteur radio minimal : fuzzel + mpv + Waybar
#   radio.sh          → menu de choix
#   radio.sh stop     → arrêt direct (clic droit dans Waybar)
#   radio.sh status   → nom de la radio en cours (utilisé par Waybar)

SOCK=/tmp/radio-mpv
CUR=/tmp/radio-current

refresh_bar() { pkill -RTMIN+8 waybar 2>/dev/null; }

stop_radio() {
    pkill -f "$SOCK" 2>/dev/null
    rm -f "$CUR"
    refresh_bar
}

case "$1" in
  status)
    # n'affiche le nom que si mpv tourne vraiment
    if pgrep -f "$SOCK" >/dev/null && [ -s "$CUR" ]; then
        cat "$CUR"
    fi
    exit 0 ;;
  stop)
    stop_radio
    exit 0 ;;
esac

choix=$(printf "■ Arrêter\nFIP\nFrance Inter\nFrance Culture\nFrance Musique\nRTL2" \
        | fuzzel --dmenu --prompt "Radio : ")

case "$choix" in
  "FIP")            url="https://icecast.radiofrance.fr/fip-hifi.aac" ;;
  "France Inter")   url="https://icecast.radiofrance.fr/franceinter-hifi.aac" ;;
  "France Culture") url="https://icecast.radiofrance.fr/franceculture-hifi.aac" ;;
  "France Musique") url="https://icecast.radiofrance.fr/francemusique-hifi.aac" ;;
  "RTL2")           url="http://icecast.rtl2.fr/rtl2-1-44-128" ;;
  "■ Arrêter")      stop_radio; exit 0 ;;
  *)                exit 0 ;;          # Échap : on ne change rien
esac

stop_radio
echo "$choix" > "$CUR"
refresh_bar
notify-send "Radio" "$choix"

mpv --no-video --input-ipc-server="$SOCK" "$url"

# mpv s'est arrêté (flux coupé, arrêt…) : on efface l'affichage
# seulement si aucune autre radio n'a été lancée entre-temps
[ "$(cat "$CUR" 2>/dev/null)" = "$choix" ] && ! pgrep -f "$SOCK" >/dev/null && { rm -f "$CUR"; refresh_bar; }
