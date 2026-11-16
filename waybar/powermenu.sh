#!/bin/sh
# Menu d'extinction via fuzzel — ~/.config/waybar/powermenu.sh
choix=$(printf "Verrouiller\nDéconnexion\nVeille\nRedémarrer\nÉteindre" | fuzzel --dmenu --prompt "Session : ")
case "$choix" in
  Verrouiller) hyprlock ;;
  Déconnexion) hyprctl dispatch 'hl.dsp.exit()' ;;
  Veille)      systemctl suspend ;;
  Redémarrer)  systemctl reboot ;;
  Éteindre)    systemctl poweroff ;;
esac
