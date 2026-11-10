#!/usr/bin/env bash
set -u
echo
echo "Qui écoute ? $(hostname) ($(date '+%d/%m/%Y %H:%M'))"
echo "Lecture seule : ce script ne modifie rien."
echo
echo "1. Les portes TCP ouvertes (LISTEN) et le programme derrière chacune :"
echo "   Adresse 127.0.0.1 ou [::1] : joignable seulement depuis ta machine."
echo "   Adresse 0.0.0.0, [::] ou *   : joignable depuis le réseau, si le pare-feu laisse passer."
echo
if [ "$(id -u)" -ne 0 ]; then
  echo "   (sans sudo, le nom du programme n'apparaît pas pour les services du système)"
fi
ss -tlnp 2>/dev/null | awk 'NR==1 {print "   " $0; next} {print "   " $0}'
echo
echo "2. Les portes UDP :"
ss -ulnp 2>/dev/null | awk '{print "   " $0}'
echo
echo "3. Les services qui démarrent avec la machine :"
systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null | awk 'NR>1 && $1 ~ /\.service$/ {print "   " $1}'
echo
echo "4. Le pare-feu :"
if command -v ufw >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
  LC_ALL=C ufw status verbose | sed 's/^/   /'
else
  echo "   lance ce choix avec sudo pour voir les règles de ufw"
fi
echo
echo "Commandes utilisées : ss -tlnp, ss -ulnp, systemctl list-unit-files, ufw status verbose"
