#!/usr/bin/env bash
set -u
if [ "$(id -u)" -eq 0 ]; then echo "Lance-moi sans sudo : le mot de passe sera demandé quand il le faut."; exit 1; fi
VERSION="25.12.6"
IMAGE="openwrt-$VERSION-x86-64-generic-squashfs-combined.img.gz"
URL="https://downloads.openwrt.org/releases/$VERSION/targets/x86/64/$IMAGE"
SHA256="56cf27d6f76aa582eea4c5ea18bc5f76065df48e87bf3d84e1dec82ab7f7ead4"
DOSSIER="$HOME/borne"
DISQUE="$DOSSIER/borne.img"
USINE="$DOSSIER/usine.img"
PID="$DOSSIER/borne.pid"
JOURNAL="$DOSSIER/console.log"
SSH_OPTS=(-p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile="$DOSSIER/known_hosts" -o ConnectTimeout=5)

en_marche() { local p; p=$(cat "$PID" 2>/dev/null) && [ -n "$p" ] && [ "$(cat "/proc/$p/comm" 2>/dev/null)" = "qemu-system-x86" ]; }
eteindre() {
  local i
  echo "Extinction propre : si la borne demande son mot de passe root, tape-le."
  ssh "${SSH_OPTS[@]}" root@127.0.0.1 'sync; poweroff' < /dev/null 2>/dev/null
  for i in $(seq 60); do en_marche || break; sleep 1; done
  if en_marche; then echo "Pas de réponse : extinction forcée."; kill "$(cat "$PID")"; sleep 1; fi
}

attendre_ssh() {
  local i
  for i in $(seq 1 90); do
    if timeout 4 bash -c 'exec 3<>/dev/tcp/127.0.0.1/2222; head -c 20 <&3' 2>/dev/null | grep -q 'SSH-2.0-dropbear'; then sleep 2; return 0; fi
    sleep 2
  done
  return 1
}

lancer_vm() {
  local acc=()
  if ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Eq ':(8080|8443|2222)$'; then
    echo "Un autre programme utilise le port 8080, 8443 ou 2222 : menu, choix 3 pour le trouver."; return 1
  fi
  if [ -w /dev/kvm ]; then acc=(-enable-kvm -cpu host); fi
  qemu-system-x86_64 "${acc[@]}" -m 256 -smp 2 -display none -daemonize \
    -pidfile "$PID" -serial "file:$JOURNAL" \
    -drive file="$DISQUE",format=raw,if=virtio \
    -netdev user,id=lan,net=192.168.1.0/24,host=192.168.1.2,dhcpstart=192.168.1.100,hostfwd=tcp:127.0.0.1:8080-192.168.1.1:80,hostfwd=tcp:127.0.0.1:8443-192.168.1.1:8443,hostfwd=tcp:127.0.0.1:2222-192.168.1.1:22 \
    -device virtio-net-pci,netdev=lan \
    -netdev user,id=wan -device virtio-net-pci,netdev=wan
}

case "${1:-aide}" in
  installer)
    if en_marche; then echo "La borne tourne : éteins-la d'abord (menu, choix 7)."; exit 1; fi
    if [ -f "$USINE" ]; then
      read -r -p "La borne est déjà installée. Réinstaller efface tout. Taper OUI pour confirmer : " rep
      [ "$rep" = "OUI" ] || { echo "Rien n'a été fait."; exit 0; }
    fi
    echo "Installation de la borne virtuelle (une seule fois, environ 10 minutes)."
    if ! command -v qemu-system-x86_64 >/dev/null 2>&1 || ! command -v qemu-img >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
      echo "Installation de QEMU et curl, les logiciels qui font tourner la borne (ton mot de passe est demandé) :"
      sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils curl || exit 1
    fi
    [ -w /dev/kvm ] || echo "KVM indisponible : la borne tournera en mode lent (installation plus longue)."
    mkdir -p "$DOSSIER"
    cd "$DOSSIER" || exit 1
    if [ ! -f "$IMAGE" ]; then
      echo "Téléchargement d'OpenWrt $VERSION (environ 13 Mo)..."
      curl -fL --retry 3 -o "$IMAGE" "$URL" || { echo "Téléchargement impossible : vérifie Internet."; exit 1; }
    fi
    if ! echo "$SHA256  $IMAGE" | sha256sum -c --quiet -; then
      echo "L'empreinte du fichier ne correspond pas : fichier abîmé ou modifié. Je l'efface, relance l'installation."
      rm -f "$IMAGE"; exit 1
    fi
    echo "Empreinte SHA-256 vérifiée : c'est bien l'image officielle d'OpenWrt."
    gunzip -c "$IMAGE" > "$DISQUE" 2>/dev/null
    rm -f "$DOSSIER/known_hosts" "$USINE"
    ssh-keygen -R '[127.0.0.1]:2222' >/dev/null 2>&1
    qemu-img resize -f raw "$DISQUE" 300M >/dev/null
    echo "Premier démarrage et ajout de la puce Wi-Fi simulée..."
    lancer_vm || exit 1
    attendre_ssh || { en_marche && kill "$(cat "$PID")"; echo "La borne ne répond pas. Regarde $JOURNAL et appelle le maître du jeu."; exit 1; }
    MIROIR="${BORNE_MIROIR:-}"
    ssh "${SSH_OPTS[@]}" root@127.0.0.1 "MIROIR=$MIROIR"'
      if [ -n "$MIROIR" ]; then sed -i "s#https://downloads.openwrt.org#$MIROIR#" /etc/apk/repositories.d/distfeeds.list; fi
      for i in $(seq 30); do ifstatus wan | grep -q "\"up\": true" && break; sleep 2; done
      apk update >/dev/null 2>&1
      apk add kmod-mac80211-hwsim wpad-basic-mbedtls wifi-scripts iwinfo >/dev/null 2>&1 || exit 2
      apk add luci-i18n-base-fr luci-i18n-firewall-fr >/dev/null 2>&1
      [ -n "$MIROIR" ] && sed -i "s#$MIROIR#https://downloads.openwrt.org#" /etc/apk/repositories.d/distfeeds.list
      sleep 3; wifi config
      uci set wireless.radio0.band=2g; uci set wireless.radio0.channel=6; uci set wireless.radio0.htmode=HT20; uci set wireless.radio0.country=FR
      uci set wireless.radio1.band=5g; uci set wireless.radio1.channel=36; uci set wireless.radio1.htmode=VHT80; uci set wireless.radio1.country=FR
      for i in default_radio0 default_radio1; do uci set wireless.$i.encryption=none; uci set wireless.$i.ssid=OpenWrt; done
      uci commit wireless
      uci delete uhttpd.main.listen_https; uci add_list uhttpd.main.listen_https=0.0.0.0:8443; uci add_list uhttpd.main.listen_https=[::]:8443; uci commit uhttpd; sync
      uci -q show wireless | grep -q "=wifi-iface" || exit 3' < /dev/null
    code=$?
    ssh "${SSH_OPTS[@]}" root@127.0.0.1 'sync; poweroff' < /dev/null 2>/dev/null
    for i in $(seq 90); do en_marche || break; sleep 1; done
    en_marche && kill "$(cat "$PID")"
    if [ "$code" -ne 0 ]; then
      echo "La préparation de la borne a échoué (code $code) : Internet est-il accessible ? Relance ./scripts/borne.sh installer"
      exit 1
    fi
    cp "$DISQUE" "$USINE"
    echo "La borne est prête, en sortie d'usine. Lance : ./scripts/borne.sh demarrer"
    ;;
  demarrer)
    [ -f "$USINE" ] || { echo "La borne n'est pas installée (ou l'installation a échoué) : menu, choix 5"; exit 1; }
    if en_marche; then echo "La borne tourne déjà."; else lancer_vm || exit 1; fi
    echo "Démarrage... (jusqu'à 1 minute)"
    attendre_ssh || { echo "La borne ne répond pas. Regarde $JOURNAL"; exit 1; }
    sleep 20
    echo "La borne est allumée."
    echo "  Interface web (LuCI) : http://127.0.0.1:8080"
    echo "  En SSH                : ssh -p 2222 root@127.0.0.1"
    ;;
  arreter)
    if en_marche; then
      eteindre
      echo "La borne est éteinte."
    else
      echo "La borne est déjà éteinte."
    fi
    ;;
  usine)
    [ -f "$USINE" ] || { echo "Pas d'image d'usine : ./scripts/borne.sh installer"; exit 1; }
    read -r -p "Remettre la borne en sortie d'usine efface tous tes réglages. Taper OUI pour confirmer : " rep
    [ "$rep" = "OUI" ] || { echo "Rien n'a été fait."; exit 0; }
    if en_marche; then kill "$(cat "$PID")"; sleep 2; fi
    cp "$USINE" "$DISQUE"
    rm -f "$DOSSIER/known_hosts"
    ssh-keygen -R '[127.0.0.1]:2222' >/dev/null 2>&1
    echo "La borne est revenue en sortie d'usine. Lance : ./scripts/borne.sh demarrer"
    ;;
  sauvegarder)
    en_marche || { echo "Allume d'abord la borne."; exit 1; }
    ICI="$(cd "$(dirname "$0")/.." && pwd)"
    mkdir -p "$ICI/sauvegardes"
    umask 077
    f="$ICI/sauvegardes/borne-$(date +%Y%m%d-%H%M).tar.gz"
    if ssh "${SSH_OPTS[@]}" root@127.0.0.1 'sysupgrade -b -' > "$f" && [ -s "$f" ]; then
      echo "Configuration sauvegardée : $f"
      echo "Elle contient les mots de passe de la borne : elle ne va jamais dans le dépôt Git."
    else
      rm -f "$f"; echo "Sauvegarde impossible."
    fi
    ;;
  etat)
    if en_marche; then echo "La borne est allumée (http://127.0.0.1:8080)."; else echo "La borne est éteinte."; fi
    ;;
  *)
    echo "Utilisation : ./scripts/borne.sh installer | demarrer | arreter | etat | sauvegarder | usine"
    ;;
esac
