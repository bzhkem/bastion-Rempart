#!/usr/bin/env bash
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
. "$ICI/commun.sh"
pas_en_root
DOSSIER="$HOME/borne"
RAPPORT="$ICI/../rapports/bilan-borne-$(whoami)-$(date +%Y%m%d-%H%M).md"

echo
echo "Bilan de la borne Wi-Fi ($(date '+%d/%m/%Y %H:%M'))"
echo "Lecture seule : ce script lit la configuration de la borne, il ne modifie rien."
echo "Si la borne demande son mot de passe root, tape-le (rien ne s'affiche)."
echo

if ! timeout 4 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2222; head -c 20 <&3' 2>/dev/null | grep -q 'SSH-2.0-dropbear'; then
  echo "La borne ne répond pas : allume-la d'abord (menu, choix 6)."
  exit 1
fi

DONNEES=$(ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile="$DOSSIER/known_hosts" -o ConnectTimeout=5 root@127.0.0.1 '
  echo "VERSION=$(. /etc/openwrt_release; echo $DISTRIB_RELEASE)"
  h=$(awk -F: "\$1==\"root\"{print \$2}" /etc/shadow)
  [ -n "$h" ] && echo "MDP=oui" || echo "MDP=non"
  for s in $(uci -q show wireless | sed -n "s/^wireless\.\([^.=]*\)=wifi-iface$/\1/p"); do
    net=$(uci -q get wireless.$s.network); dev=$(uci -q get wireless.$s.device)
    off=$(uci -q get wireless.$s.disabled); roff=$(uci -q get wireless.$dev.disabled)
    k=$(uci -q get wireless.$s.key)
    echo "IFACE=$s|$net|$(uci -q get wireless.$s.ssid)|$(uci -q get wireless.$s.encryption)|${#k}|$(uci -q get wireless.$s.isolate)|${off:-0}|${roff:-0}"
  done
  for z in $(uci -q show firewall | sed -n "s/^firewall\.\([^.=]*\)=zone$/\1/p"); do
    echo "ZONE=$(uci -q get firewall.$z.name)|$(uci -q get firewall.$z.input)|$(uci -q get firewall.$z.forward)|$(uci -q get firewall.$z.network | tr " " ",")"
  done
  for f in $(uci -q show firewall | sed -n "s/^firewall\.\([^.=]*\)=forwarding$/\1/p"); do
    echo "FWD=$(uci -q get firewall.$f.src)>$(uci -q get firewall.$f.dest)"
  done
  for r in $(uci -q show firewall | sed -n "s/^firewall\.\([^.=]*\)=rule$/\1/p"); do
    echo "REGLE=$(uci -q get firewall.$r.src)|$(uci -q get firewall.$r.dest_port)|$(uci -q get firewall.$r.target)|$(uci -q get firewall.$r.enabled)|$(uci -q get firewall.$r.proto)|$(uci -q get firewall.$r.dest)"
  done
  d=$(uci -q show dropbear | sed -n "s/^dropbear\.\([^.=]*\)=dropbear$/\1/p" | head -1)
  echo "SSH_MDP=$(uci -q get dropbear.$d.PasswordAuth)|$(uci -q get dropbear.$d.RootPasswordAuth)|$(uci -q get dropbear.$d.Interface)"
  [ -s /etc/dropbear/authorized_keys ] && echo "CLES=oui" || echo "CLES=non"
  echo "HTTPS=$(uci -q get uhttpd.main.redirect_https)|$(uci -q get uhttpd.main.listen_https | head -c 40)"
  [ -x /usr/sbin/miniupnpd ] && echo "UPNP=oui" || echo "UPNP=non"
')

if [ -z "$DONNEES" ]; then
  echo "Impossible de lire la borne (mot de passe refusé ?)."
  exit 1
fi

val() { echo "$DONNEES" | sed -n "s/^$1=//p" | head -1; }

if [ "$(val MDP)" = "oui" ]; then
  resultat ok 15 "Mot de passe administrateur défini" ""
else
  resultat ko 15 "Mot de passe administrateur défini" "n'importe qui sur le réseau peut tout régler : LuCI, Système, Administration (quête 10)"
fi

principal=$(echo "$DONNEES" | sed -n 's/^IFACE=//p' | awk -F'|' '$2=="lan" && $7!="1" && $8!="1"' | head -1)
[ -z "$principal" ] && principal=$(echo "$DONNEES" | sed -n 's/^IFACE=//p' | awk -F'|' '$2=="lan"' | head -1)
ouverts_wifi=$(echo "$DONNEES" | sed -n 's/^IFACE=//p' | awk -F'|' '$7!="1" && $8!="1" && $4!~/^(sae|psk2)/ {print $3}' | tr '\n' ' ')
invite=$(echo "$DONNEES" | sed -n 's/^IFACE=//p' | awk -F'|' '$2=="guest"' | head -1)

if [ -z "$principal" ]; then
  resultat ko 5 "Wi-Fi principal allumé, nom personnalisé" "LuCI, Réseau, Sans fil : active la radio et le réseau relié à lan (quête 11)"
  resultat ko 20 "Chiffrement WPA3 ou WPA2/WPA3" "pas de Wi-Fi principal à vérifier (quête 11)"
  resultat ko 10 "Clé Wi-Fi d'au moins 12 caractères" "pas de Wi-Fi principal à vérifier (quête 11)"
else
  IFS='|' read -r _ _ ssid chif lg _ off roff <<< "$principal"
  if [ "$off" = "1" ] || [ "$roff" = "1" ]; then
    resultat ko 5 "Wi-Fi principal allumé, nom personnalisé" "la radio ou le réseau est désactivé : LuCI, Réseau, Sans fil, Activer (quête 11)"
  elif [ "$ssid" = "OpenWrt" ] || [ -z "$ssid" ]; then
    resultat ko 5 "Wi-Fi principal allumé, nom personnalisé" "le nom d'usine OpenWrt dit quel matériel attaquer : choisis un nom sans ton nom ni ta marque (quête 11)"
  else
    resultat ok 5 "Wi-Fi principal allumé, nom personnalisé ($ssid)" ""
  fi
  if [ -n "$ouverts_wifi" ]; then chif="ouvert:$ouverts_wifi"; fi
  case "$chif" in
    sae|sae+*|sae-mixed|sae-mixed+*) resultat ok 20 "Chiffrement WPA3 ou WPA2/WPA3 ($chif)" "" ;;
    psk2*) resultat ko 20 "Chiffrement WPA3 ou WPA2/WPA3 (WPA2 seul)" "passe en WPA2-PSK/WPA3-SAE mixte, ou WPA3-SAE seul (quête 11)" ;;
    ouvert:*) resultat ko 20 "Chiffrement WPA3 ou WPA2/WPA3 (réseau ouvert : ${chif#ouvert:})" "un réseau allumé n'est pas chiffré : WPA3-SAE ou mixte, ou éteins-le (quête 11)" ;;
    *) resultat ko 20 "Chiffrement WPA3 ou WPA2/WPA3 (${chif:-aucun})" "réseau ouvert ou chiffrement cassé : WPA3-SAE (quête 11)" ;;
  esac
  if [ "${chif%%:*}" != "none" ] && [ "${chif%%:*}" != "ouvert" ] && [ "${lg:-0}" -ge 12 ]; then
    resultat ok 10 "Clé Wi-Fi d'au moins 12 caractères" ""
  else
    resultat ko 10 "Clé Wi-Fi d'au moins 12 caractères (${lg:-0})" "une phrase de passe d'au moins 12 caractères, rangée dans Bitwarden (quête 11)"
  fi
fi

zone_invite=$(echo "$DONNEES" | sed -n 's/^ZONE=//p' | awk -F'|' '$1=="guest"' | head -1)
fwd=$(echo "$DONNEES" | sed -n 's/^FWD=//p')
ok_invite=non
raison="crée le réseau invité (quête 12)"
if [ -n "$invite" ] && [ -n "$zone_invite" ]; then
  IFS='|' read -r _ _ _ ichif _ iso ioff _ <<< "$invite"
  IFS='|' read -r _ zin _ _ <<< "$zone_invite"
  if [ "$ioff" = "1" ]; then raison="le réseau invité est désactivé"
  elif [ "${ichif:-none}" = "none" ]; then raison="le Wi-Fi invité n'est pas chiffré"
  elif [ "$iso" != "1" ]; then raison="les invités se voient entre eux : option isolate (quête 12)"
  elif [ "$zin" = "ACCEPT" ]; then raison="la zone guest accepte les connexions vers la borne : entrée REJECT (quête 12)"
  elif echo "$fwd" | grep -q '^guest>lan$'; then raison="les invités peuvent entrer dans ton réseau privé : supprime le transfert guest vers lan"
  elif ! echo "$fwd" | grep -q '^guest>wan$'; then raison="les invités n'ont pas accès à Internet : transfert guest vers wan"
  else ok_invite=oui
  fi
fi
if [ "$ok_invite" = oui ]; then
  resultat ok 15 "Réseau invité séparé et isolé" ""
else
  resultat ko 15 "Réseau invité séparé et isolé" "$raison"
fi

zone_wan=$(echo "$DONNEES" | sed -n 's/^ZONE=//p' | awk -F'|' '$1=="wan"' | head -1)
IFS='|' read -r _ win _ _ <<< "$zone_wan"
ouvert_wan=$(echo "$DONNEES" | sed -n 's/^REGLE=//p' | awk -F'|' '$1=="wan" && $6=="" && $3=="ACCEPT" && $4!="0" && ($5=="" || $5~/tcp|all/) && ($2=="" || $2~/(^| )(22|80|443)( |$)/)')
if [ "$win" != "ACCEPT" ] && [ -z "$ouvert_wan" ]; then
  resultat ok 10 "Administration fermée côté Internet (WAN)" ""
else
  resultat ko 10 "Administration fermée côté Internet (WAN)" "zone wan en REJECT, et aucune règle qui ouvre 22, 80 ou 443 depuis le WAN"
fi

IFS='|' read -r pa rpa _ <<< "$(val SSH_MDP)"
if [ "$(val CLES)" = "oui" ] && { [ "$pa" = "0" ] || [ "$pa" = "off" ]; } && { [ "$rpa" = "0" ] || [ "$rpa" = "off" ]; }; then
  resultat ok 10 "SSH de la borne par clé seulement" ""
else
  resultat ko 10 "SSH de la borne par clé seulement" "ajoute ta clé, teste-la, puis coupe les mots de passe (quête 13)"
fi

IFS='|' read -r rh lh <<< "$(val HTTPS)"
if [ "$rh" = "1" ] && [ -n "$lh" ]; then
  resultat ok 10 "Interface web en HTTPS" ""
else
  resultat ko 10 "Interface web en HTTPS" "uci set uhttpd.main.redirect_https=1 (quête 13)"
fi

if ls "$ICI/../sauvegardes"/borne-*.tar.gz >/dev/null 2>&1; then
  resultat ok 5 "Configuration de la borne sauvegardée" ""
else
  resultat ko 5 "Configuration de la borne sauvegardée" "menu, choix 9 (quête 13)"
fi

echo
resultat info 0 "Version d'OpenWrt : $(val VERSION) (vérifie sur openwrt.org qu'elle est encore suivie)" ""
if [ "$(val UPNP)" = "oui" ]; then
  resultat info 0 "UPnP installé : il laisse les appareils ouvrir des ports tout seuls, à éviter" ""
fi

score_final "Bilan de la borne" "$RAPPORT"
