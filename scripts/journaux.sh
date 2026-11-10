#!/usr/bin/env bash
set -u
echo
echo "Qui a frappé à la porte ? $(hostname) ($(date '+%d/%m/%Y %H:%M'))"
echo "Lecture seule : ce script ne modifie rien."
echo
echo "1. Les dernières ouvertures de session réussies :"
last -n 8 2>/dev/null | sed 's/^/   /'
echo
echo "2. Les dernières utilisations de sudo :"
journalctl _COMM=sudo -n 8 --no-pager -o short 2>/dev/null | sed 's/^/   /'
echo
echo "3. Les tentatives SSH ratées des dernières 24 h :"
r=$(journalctl -u ssh -u sshd --since "-24h" --no-pager 2>/dev/null | grep -E "Failed|Invalid user|authentication failure")
if [ -z "$r" ]; then echo "   aucune"; else echo "$r" | tail -10 | sed 's/^/   /'; echo "   total : $(echo "$r" | wc -l)"; fi
echo
echo "4. fail2ban :"
if command -v fail2ban-client >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
  if out=$(fail2ban-client status sshd 2>/dev/null); then echo "$out" | sed 's/^/   /'; else echo "   pas de prison sshd"; fi
else
  echo "   pas installé, ou lance ce choix avec sudo"
fi
echo
echo "5. Les erreurs graves du système depuis le dernier démarrage :"
journalctl -b -p err -n 10 --no-pager 2>/dev/null | sed 's/^/   /'
echo
echo "Commandes utilisées : last, journalctl, fail2ban-client status sshd"
