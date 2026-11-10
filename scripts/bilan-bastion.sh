#!/usr/bin/env bash
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
. "$ICI/commun.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Ce bilan doit lire des fichiers protégés : lance-le avec sudo."
  echo "  sudo ./scripts/bilan-bastion.sh"
  exit 1
fi

MOI="${SUDO_USER:-root}"
RAPPORT="$ICI/../rapports/bilan-bastion-$MOI-$(date +%Y%m%d-%H%M).md"
WSL=non
grep -qi microsoft /proc/version 2>/dev/null && WSL=oui

echo
echo "Bilan du bastion : $(hostname), compte $MOI ($(date '+%d/%m/%Y %H:%M'))"
echo "Lecture seule : ce script ne modifie rien sur la machine."
[ "$WSL" = oui ] && echo "Tu es dans WSL : certains points sont marqués ?? et retirés du calcul."
echo

stamp=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp 2>/dev/null || stat -c %Y /var/lib/apt/lists 2>/dev/null || echo 0)
vieux=$(( $(date +%s) - stamp > 172800 ))
n=$(LC_ALL=C apt-get -s --with-new-pkgs upgrade 2>/dev/null | grep -c '^Inst ' || true)
if [ -f /var/run/reboot-required ]; then
  resultat ko 15 "Système à jour" "des mises à jour attendent un redémarrage : redémarre la machine"
elif [ "$vieux" -eq 1 ]; then
  resultat ko 15 "Système à jour (liste des paquets de plus de 2 jours)" "sudo apt update puis sudo apt upgrade, puis relance le bilan (quête 3)"
elif [ "$n" -eq 0 ]; then
  resultat ok 15 "Système à jour" ""
else
  resultat ko 15 "Système à jour ($n paquets en attente)" "sudo apt update puis sudo apt upgrade (quête 3)"
fi

if dpkg -s unattended-upgrades >/dev/null 2>&1 && apt-config dump APT::Periodic::Unattended-Upgrade 2>/dev/null | grep -q '"1"'; then
  resultat ok 10 "Mises à jour de sécurité automatiques" ""
else
  resultat ko 10 "Mises à jour de sécurité automatiques" "sudo dpkg-reconfigure -plow unattended-upgrades (quête 3)"
fi

if command -v ufw >/dev/null 2>&1; then
  etat=$(LC_ALL=C ufw status verbose 2>/dev/null)
  if echo "$etat" | grep -q '^Status: active' && echo "$etat" | grep -q 'deny (incoming)'; then
    resultat ok 15 "Pare-feu actif, entrées refusées par défaut" ""
  else
    resultat ko 15 "Pare-feu actif, entrées refusées par défaut" "sudo ufw default deny incoming puis sudo ufw enable (quête 7)"
  fi
else
  resultat ko 15 "Pare-feu actif, entrées refusées par défaut" "sudo apt install ufw (quête 7)"
fi

r=$(passwd -S root 2>/dev/null | awk '{print $2}')
if [ "$r" = "L" ]; then
  resultat ok 5 "Compte root verrouillé" ""
else
  resultat ko 5 "Compte root verrouillé" "sudo passwd -l root : on passe par sudo, jamais par root (quête 4)"
fi

vides=$(awk -F: '($2==""){print $1}' /etc/shadow | tr '\n' ' ')
if [ -z "$vides" ]; then
  resultat ok 5 "Aucun compte sans mot de passe" ""
else
  resultat ko 5 "Aucun compte sans mot de passe (comptes : $vides)" "sudo passwd NOM pour en donner un, ou sudo passwd -l NOM pour le bloquer (quête 4)"
fi

admins=$(getent group sudo | cut -d: -f4 | tr ',' ' ')
autres=""
for u in $admins; do [ "$u" != "$MOI" ] && autres="$autres $u"; done
if [ -z "$autres" ]; then
  resultat ok 10 "Un seul administrateur : toi" ""
else
  resultat ko 10 "Un seul administrateur : toi (aussi dans sudo :$autres)" "sudo deluser NOM sudo pour chaque compte qui n'en a pas besoin (quête 4)"
fi

if [ "$WSL" = oui ]; then
  resultat nv 5 "Verrouillage automatique de l'écran" "dans WSL, c'est Windows qui verrouille l'écran"
else
  g() { sudo -u "$MOI" -H env XDG_RUNTIME_DIR="/run/user/$(id -u "$MOI")" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$MOI")/bus" gsettings get "$@" 2>/dev/null; }
  verrou=$(g org.gnome.desktop.screensaver lock-enabled)
  delai=$(g org.gnome.desktop.session idle-delay | awk '{print $NF}')
fi
if [ "$WSL" = oui ]; then
  :
elif [ -n "${verrou:-}" ] && [ -n "${delai:-}" ]; then
  if [ "$verrou" = "true" ] && [ "$delai" -gt 0 ] 2>/dev/null && [ "$delai" -le 600 ]; then
    resultat ok 5 "Verrouillage automatique de l'écran (10 min au plus)" ""
  else
    resultat ko 5 "Verrouillage automatique de l'écran (10 min au plus)" "Paramètres, Confidentialité, Écran : écran vide 5 min, verrouillage automatique activé"
  fi
else
  resultat nv 5 "Verrouillage automatique de l'écran" ""
fi

maison=$(getent passwd "$MOI" | cut -d: -f6)
if [ -d "$maison" ]; then
  droits=$(stat -c %a "$maison")
  if [ "${droits: -1}" = "0" ]; then
    resultat ok 5 "Dossier personnel fermé aux autres comptes ($droits)" ""
  else
    resultat ko 5 "Dossier personnel fermé aux autres comptes ($droits)" "chmod 750 $maison (quête 5)"
  fi
else
  resultat nv 5 "Dossier personnel fermé aux autres comptes" ""
fi

if [ -x /usr/sbin/sshd ]; then
  conf=$(sshd_conf)
  if [ -z "$conf" ]; then
    resultat ko 15 "Serveur SSH durci" "la configuration de SSH contient une erreur : $(sshd_erreur) (quête 8)"
  else
    pr=$(echo "$conf" | awk '$1=="permitrootlogin"{print $2}')
    pa=$(echo "$conf" | awk '$1=="passwordauthentication"{print $2}')
    kb=$(echo "$conf" | awk '$1=="kbdinteractiveauthentication"{print $2}')
    if [ "$pr" = "no" ] && [ "$pa" = "no" ] && [ "$kb" = "no" ]; then
      resultat ok 15 "Serveur SSH durci (clé seulement, pas de root)" ""
    else
      resultat ko 15 "Serveur SSH durci (root : $pr, mot de passe : $pa, clavier interactif : $kb)" "PermitRootLogin no et PasswordAuthentication no, après avoir testé ta clé (quête 8)"
    fi
  fi
else
  resultat ok 15 "Aucun serveur SSH installé (rien à attaquer de ce côté)" ""
fi

port=22
[ -n "${conf:-}" ] && port=$(echo "$conf" | awk '$1=="port"{print $2; exit}')
ouverts=$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Ev '^(127\.|\[::1\]|::1)' | grep -Ev ":${port:-22}\$" | sort -u | tr '\n' ' ')
if [ -z "$ouverts" ]; then
  resultat ok 10 "Aucun port TCP ouvert au réseau, sauf SSH" ""
else
  resultat ko 10 "Aucun port TCP ouvert au réseau, sauf SSH (ouverts : $ouverts)" "menu, choix 3 : trouve le service et arrête-le ou limite-le à 127.0.0.1 (quête 6)"
fi

if [ -x /usr/sbin/sshd ]; then
  if systemctl is-active --quiet fail2ban 2>/dev/null && fail2ban-client status sshd >/dev/null 2>&1; then
    resultat ok 5 "fail2ban surveille SSH" ""
  else
    resultat ko 5 "fail2ban surveille SSH" "sudo apt install fail2ban, puis la prison sshd (quête 9)"
  fi
else
  resultat nv 5 "fail2ban surveille SSH" "pas de serveur SSH : rien à surveiller pour l'instant"
fi

echo
if [ "$WSL" = non ]; then
  if command -v aa-enabled >/dev/null 2>&1 && [ "$(aa-enabled 2>/dev/null)" = "Yes" ]; then
    resultat info 0 "AppArmor actif : chaque programme protégé reste dans sa cage" ""
  else
    resultat info 0 "AppArmor inactif ou absent : à signaler au maître du jeu" ""
  fi
  if lsblk -rno FSTYPE 2>/dev/null | grep -q 'crypto_LUKS'; then
    resultat info 0 "Disque chiffré (LUKS) : on n'y touche pas cette semaine" ""
  else
    resultat info 0 "Disque non chiffré : on n'y touche pas cette semaine, à signaler au maître du jeu" ""
  fi
fi

score_final "Bilan du bastion" "$RAPPORT"
