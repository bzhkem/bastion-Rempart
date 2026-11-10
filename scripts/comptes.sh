#!/usr/bin/env bash
set -u
echo
echo "Comptes et droits : $(hostname) ($(date '+%d/%m/%Y %H:%M'))"
echo "Lecture seule : ce script ne modifie rien."
echo
echo "1. Les comptes humains (numéro 1000 et plus) :"
getent passwd | awk -F: '$3>=1000 && $3<65534 {printf "   %-14s numéro %-6s dossier %-22s shell %s\n", $1, $3, $6, $7}'
echo
echo "2. Les administrateurs (groupe sudo) :"
m=$(getent group sudo | cut -d: -f4)
echo "   ${m:-personne}"
echo
echo "3. Les comptes qui peuvent ouvrir une session (shell bash ou sh) :"
getent passwd | awk -F: '$7 ~ /(bash|sh)$/ {printf "   %s\n", $1}'
echo
echo "4. Les droits de ton dossier personnel :"
ls -ld "$HOME"
echo
echo "5. Les fichiers de ton dossier que tout le monde peut modifier (il ne devrait y en avoir aucun) :"
t=$(find "$HOME" -xdev -type f -perm -0002 2>/dev/null | head -20)
if [ -z "$t" ]; then echo "   aucun"; else echo "$t" | sed 's/^/   /'; fi
echo
echo "6. Les programmes qui s'exécutent avec les droits de root (SUID), sur le système :"
find /usr/bin /usr/sbin /usr/local/bin -xdev -perm -4000 -type f 2>/dev/null | sed 's/^/   /'
echo
echo "Commandes utilisées : getent passwd, getent group sudo, ls -ld, find -perm"
