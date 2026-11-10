#!/usr/bin/env bash
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
if [ "$(id -u)" -ne 0 ]; then
  echo "Lance-moi avec sudo : sudo ./scripts/specialites.sh"
  exit 1
fi
MOI="${SUDO_USER:-root}"
. "$ICI/commun.sh"
ok() { printf '    [ OK ]     %s\n' "$1"; }
ko() { printf '    [A FAIRE]  %s\n               -> %s\n' "$1" "$2"; }
tampon() { if [ "$1" -eq "$2" ]; then echo "    => tampon possible : $3"; else echo "    => $1 sur $2 : pas encore de tampon"; fi; echo; }

echo
echo "Spécialités des guildes : $(hostname), compte $MOI"
echo "Lecture seule. Chaque guilde vérifie sa spécialité sur ton bastion, puis tamponne ta fiche."
echo

echo "  Guilde des Clés : comptes et mots de passe"
n=0
ml=$(grep -Es '^\s*minlen\s*=' /etc/security/pwquality.conf | tail -1 | tr -dc '0-9')
if grep -qs pam_pwquality /etc/pam.d/common-password && [ "${ml:-0}" -ge 12 ]; then ok "Mots de passe de 12 caractères au moins (minlen = $ml)"; n=$((n+1)); else ko "Mots de passe de 12 caractères au moins" "sudo apt install libpam-pwquality, puis remplace la ligne # minlen = 8 par minlen = 12 dans /etc/security/pwquality.conf"; fi
if id stagiaire >/dev/null 2>&1 && ! id -nG stagiaire | grep -qw sudo; then ok "Compte stagiaire standard, sans sudo"; n=$((n+1)); else ko "Compte stagiaire standard, sans sudo" "sudo adduser stagiaire (quête 4)"; fi
tt=$(sudo -l -U "$MOI" 2>/dev/null | grep -o 'timestamp_timeout=[-0-9.]*' | tail -1 | cut -d= -f2)
if [ -n "$tt" ] && [ "${tt%%.*}" -ge 0 ] 2>/dev/null && [ "${tt%%.*}" -le 5 ]; then ok "sudo redemande le mot de passe après $tt min au plus"; n=$((n+1)); else ko "sudo redemande le mot de passe après 5 min au plus" "sudo visudo -f /etc/sudoers.d/delai, ligne Defaults timestamp_timeout=5"; fi
tampon $n 3 "Guilde des Clés"

echo "  Guilde du Rempart : pare-feu"
n=0
st=$(LC_ALL=C ufw status verbose 2>/dev/null)
actif=non; echo "$st" | grep -q '^Status: active' && actif=oui
if [ "$actif" = oui ] && echo "$st" | grep -Eq '^Logging: on \((medium|high|full)\)'; then ok "Le pare-feu note en détail ce qu'il refuse"; n=$((n+1)); else ko "Le pare-feu note en détail ce qu'il refuse" "sudo ufw logging medium"; fi
if [ "$actif" = oui ] && echo "$st" | grep -Eq '^(22(/tcp)?|OpenSSH) .*LIMIT'; then ok "SSH limité contre les rafales de connexions"; n=$((n+1)); else ko "SSH limité contre les rafales de connexions" "sudo ufw limit OpenSSH"; fi
if [ "$actif" = oui ] && ! echo "$st" | grep -Eq 'ALLOW IN +Anywhere'; then ok "Aucune porte ouverte à tout le monde sans limite"; n=$((n+1)); else ko "Aucune porte ouverte à tout le monde sans limite" "sudo ufw status numbered, puis sudo ufw delete allow OpenSSH"; fi
tampon $n 3 "Guilde du Rempart"

echo "  Guilde de la Porte : SSH"
n=0
c=""; [ -x /usr/sbin/sshd ] && c=$(sshd_conf)
if [ -n "$c" ]; then
  m=$(echo "$c" | awk '$1=="maxauthtries"{print $2}'); g=$(echo "$c" | awk '$1=="logingracetime"{print $2}'); u=$(echo "$c" | awk '$1=="allowusers"{print $2}')
  if [ "${m:-6}" -le 3 ]; then ok "3 essais au plus par connexion"; n=$((n+1)); else ko "3 essais au plus par connexion" "MaxAuthTries 3"; fi
  if [ "${g:-120}" -le 30 ]; then ok "30 secondes au plus pour s'identifier"; n=$((n+1)); else ko "30 secondes au plus pour s'identifier" "LoginGraceTime 30"; fi
  if [ "$u" = "$MOI" ]; then ok "Seul $MOI peut se connecter"; n=$((n+1)); else ko "Seul $MOI peut se connecter" "AllowUsers $MOI (le nom affiché par whoami)"; fi
else
  ko "Serveur SSH installé" "quête 8 d'abord"
fi
tampon $n 3 "Guilde de la Porte"

echo "  Guilde des Veilleurs : journaux et alertes"
n=0
bt=$(fail2ban-client get sshd bantime 2>/dev/null | tr -dc '0-9')
if [ "${bt:-0}" -ge 3600 ]; then ok "fail2ban bannit 1 heure au moins"; n=$((n+1)); else ko "fail2ban bannit 1 heure au moins" "dans /etc/fail2ban/jail.local, remplace bantime = 10m par bantime = 1h, puis sudo fail2ban-client -t"; fi
if [ -d /var/log/journal ] && ! systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -Eq '^Storage=(volatile|none)'; then ok "Journaux conservés après redémarrage"; n=$((n+1)); else ko "Journaux conservés après redémarrage" "Storage=persistent dans /etc/systemd/journald.conf, puis sudo systemctl restart systemd-journald"; fi
if [ -s /var/log/lynis-report.dat ]; then ok "Audit Lynis réalisé (indice : $(sed -n 's/^hardening_index=//p' /var/log/lynis-report.dat))"; n=$((n+1)); else ko "Audit Lynis réalisé" "sudo apt install lynis puis sudo lynis audit system"; fi
tampon $n 3 "Guilde des Veilleurs"

echo "  Guilde des Ondes : la borne Wi-Fi"
n=0
dernier=$(ls "$ICI/../rapports"/bilan-borne-"$MOI"-*.md 2>/dev/null | sort | tail -1)
if [ -n "$dernier" ]; then
  s=$(sed -n 's/^Score : \*\*\([0-9]*\).*/\1/p' "$dernier")
  if [ "${s:-0}" -ge 80 ]; then ok "Dernier bilan de la borne au vert ($s)"; n=$((n+1)); else ko "Dernier bilan de la borne au vert (${s:-0})" "menu, choix 8 après les quêtes 10 à 13"; fi
  if grep -q "Réseau invité séparé et isolé | +" "$dernier"; then ok "Réseau invité isolé"; n=$((n+1)); else ko "Réseau invité isolé" "quête 12"; fi
  if ! grep -q "UPnP installé" "$dernier"; then ok "Pas d'UPnP sur la borne"; n=$((n+1)); else ko "Pas d'UPnP sur la borne" "apk del miniupnpd"; fi
else
  ko "Bilan de la borne" "menu, choix 8"
fi
tampon $n 3 "Guilde des Ondes"
