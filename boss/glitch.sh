#!/usr/bin/env bash
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
if [ "$(id -u)" -ne 0 ]; then
  echo "Le Glitch a besoin de lire ta configuration : sudo ./boss/glitch.sh"
  exit 1
fi
MOI="${SUDO_USER:-root}"
. "$ICI/../scripts/commun.sh"
command -v curl >/dev/null 2>&1 || { echo "curl manque : sudo apt install curl, puis relance le Glitch."; exit 1; }
conf=""; [ -x /usr/sbin/sshd ] && conf=$(sshd_conf)
port=$(echo "$conf" | awk '$1=="port"{print $2; exit}'); port=${port:-22}
RAPPORTS="$ICI/../rapports"
RAPPORT="$RAPPORTS/boss-$MOI-$(date +%Y%m%d-%H%M).md"
ENTRE=0
REPOUSSE=0
LIGNES=()

lent() { local t="$1" i; for ((i=0; i<${#t}; i++)); do printf '%s' "${t:i:1}"; sleep 0.01; done; echo; }
attaque() {
  local num="$1" nom="$2" etat="$3" detail="$4"
  if [ "$etat" = "entre" ]; then
    ENTRE=$((ENTRE + 1))
    printf '  \e[31m[ENTRÉ]\e[0m     %s. %s\n             %s\n' "$num" "$nom" "$detail"
    LIGNES+=("| $num | $nom | ENTRÉ | $detail |")
  else
    REPOUSSE=$((REPOUSSE + 1))
    printf '  \e[32m[REPOUSSÉ]\e[0m  %s. %s\n' "$num" "$nom"
    LIGNES+=("| $num | $nom | repoussé | |")
  fi
  sleep 0.4
}

echo
printf '\e[35m'
lent "  ...signal capté. Bonjour, $MOI. Je suis le Glitch."
lent "  La semaine dernière, tes fenêtres étaient fermées. Voyons tes remparts."
printf '\e[0m\n'
echo "  (Simulation : le Glitch ne teste que ta propre machine et ta propre borne. Il ne modifie rien.)"
echo

r=$(passwd -S root 2>/dev/null | awk '{print $2}')
vides=$(awk -F: '($2==""){print $1}' /etc/shadow | tr '\n' ' ')
if [ "$r" != "L" ] || [ -n "$vides" ]; then
  attaque 1 "La porte de service" entre "root n'est pas verrouillé, ou un compte n'a pas de mot de passe ${vides}"
else
  attaque 1 "La porte de service" repousse ""
fi

if [ -x /usr/sbin/sshd ] && ss -tlnH 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$"; then
  m=$(timeout 10 ssh -o BatchMode=yes -o PreferredAuthentications=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$port" glitch@127.0.0.1 2>&1 | grep -o 'Permission denied ([^)]*)')
  if echo "$m" | grep -Eq 'password|keyboard-interactive'; then
    attaque 2 "Le mot de passe deviné" entre "ton SSH accepte les mots de passe : je n'ai plus qu'à deviner ($m)"
  else
    attaque 2 "Le mot de passe deviné" repousse ""
  fi
  pr=$(echo "$conf" | awk '$1=="permitrootlogin"{print $2}')
  if [ "$pr" != "no" ]; then
    attaque 3 "Le trône de root" entre "PermitRootLogin vaut $pr : je vise directement le compte le plus puissant"
  else
    attaque 3 "Le trône de root" repousse ""
  fi
  mr=$(fail2ban-client get sshd maxretry 2>/dev/null | tr -dc '0-9')
  if [ -n "$mr" ] && [ "$mr" -le 5 ]; then
    attaque 4 "La rafale" repousse ""
  else
    attaque 4 "La rafale" entre "personne ne me bannit si j'essaie mille mots de passe : installe fail2ban"
  fi
else
  attaque 2 "Le mot de passe deviné" repousse ""
  attaque 3 "Le trône de root" repousse ""
  attaque 4 "La rafale" repousse ""
fi

etat=$(LC_ALL=C ufw status verbose 2>/dev/null)
ouverts=$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Ev '^(127\.|\[::1\]|::1)' | grep -Ev ":${port}\$" | sort -u | tr '\n' ' ')
if ! echo "$etat" | grep -q '^Status: active' || ! echo "$etat" | grep -q 'deny (incoming)'; then
  attaque 5 "Les portes oubliées" entre "ton pare-feu n'est pas actif ou laisse entrer par défaut"
elif [ -n "$ouverts" ]; then
  attaque 5 "Les portes oubliées" entre "des services écoutent le réseau : $ouverts"
else
  attaque 5 "Les portes oubliées" repousse ""
fi

secu=$(LC_ALL=C apt-get -s --with-new-pkgs upgrade 2>/dev/null | grep '^Inst ' | grep -c -- '-security' || true)
if [ "$secu" -gt 0 ] || [ -f /var/run/reboot-required ]; then
  attaque 6 "Le vieux bug" entre "$secu correctifs de sécurité ne sont pas installés (ou un redémarrage attend)"
else
  attaque 6 "Le vieux bug" repousse ""
fi

borne_ok=non
if timeout 4 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2222; head -c 20 <&3' 2>/dev/null | grep -q 'SSH-2.0-dropbear'; then borne_ok=oui; fi
if [ "$borne_ok" = oui ]; then
  entre_borne=""
  for mdp in "" admin password openwrt root 12345678 azerty; do
    corps='{"jsonrpc":"2.0","id":1,"method":"call","params":["00000000000000000000000000000000","session","login",{"username":"root","password":"'"$mdp"'"}]}'
    for url in https://127.0.0.1:8443/ubus http://127.0.0.1:8080/ubus; do
      rep=$(curl -sk --noproxy "*" -m 5 -H 'Content-Type: application/json' -d "$corps" "$url" 2>/dev/null)
      if echo "$rep" | grep -q 'ubus_rpc_session'; then entre_borne="${mdp:-(vide)}"; break 2; fi
    done
  done
  if [ -n "$entre_borne" ]; then
    attaque 7 "Le mot de passe d'usine" entre "je suis entré dans ta borne avec un des 7 mots de passe les plus courants"
  else
    attaque 7 "Le mot de passe d'usine" repousse ""
  fi
  dernier=$(ls "$RAPPORTS"/bilan-borne-"$MOI"-"$(date +%Y%m%d)"-*.md 2>/dev/null | sort | tail -1)
  if [ -z "$dernier" ]; then
    attaque 8 "Les ondes ouvertes" entre "aucun bilan de la borne aujourd'hui : je suppose que tes ondes sont ouvertes (menu, choix 8)"
  elif grep -q "Chiffrement WPA3 ou WPA2/WPA3.* | +" "$dernier" && grep -q "Clé Wi-Fi d'au moins 12 caractères | +" "$dernier"; then
    attaque 8 "Les ondes ouvertes" repousse ""
  else
    attaque 8 "Les ondes ouvertes" entre "ton Wi-Fi est ouvert, en vieux chiffrement ou avec une clé trop courte"
  fi
  if [ -n "$dernier" ] && grep -q "Réseau invité séparé et isolé | +" "$dernier"; then
    attaque 9 "L'invité indiscret" repousse ""
  else
    attaque 9 "L'invité indiscret" entre "je me suis connecté au Wi-Fi invité, et de là j'ai vu ton réseau privé"
  fi
else
  attaque 7 "Le mot de passe d'usine" entre "ta borne est éteinte : allume-la (menu, choix 6), un vrai Glitch n'attend pas"
  attaque 8 "Les ondes ouvertes" entre "borne éteinte : rien n'a été vérifié"
  attaque 9 "L'invité indiscret" entre "borne éteinte : rien n'a été vérifié"
fi

echo
printf '\e[35m'
if [ "$ENTRE" -eq 0 ]; then
  lent "  ...9 attaques, 9 portes fermées. Tes remparts tiennent. Je m'en vais... pour cette fois."
  verdict="Glitch repoussé"
else
  lent "  ...je suis entré $ENTRE fois. Je reviendrai quand tu auras réparé. Ou pas."
  verdict="Glitch entré $ENTRE fois"
fi
printf '\e[0m\n'
echo "  Résultat : $REPOUSSE attaques repoussées sur 9."
{
  echo "# Combat contre le Glitch : $MOI, $(hostname), $(date '+%d/%m/%Y %H:%M')"
  echo
  echo "**$verdict** : $REPOUSSE attaques repoussées sur 9."
  echo
  echo "| N° | Attaque | Résultat | Par où |"
  echo "|---|---|---|---|"
  printf '%s\n' "${LIGNES[@]}"
} > "$RAPPORT"
chown "$MOI": "$RAPPORT" 2>/dev/null
echo "  Rapport : $RAPPORT"
