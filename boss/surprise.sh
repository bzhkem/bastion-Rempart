#!/usr/bin/env bash
# Attaques surprises du Glitch : des traces sans danger, cachees sur ta propre machine.
# Usage : sudo ./boss/surprise.sh lundi|mardi|jeudi
#         sudo ./boss/surprise.sh verifier lundi|mardi|jeudi
#         sudo ./boss/surprise.sh nettoyer lundi|mardi|jeudi|tout   (secours, maitre du jeu)
set -u
if [ "$(id -u)" -ne 0 ]; then
  echo "Le Glitch a besoin des droits d'administration : sudo ./boss/surprise.sh $*"
  exit 1
fi
MOI="${SUDO_USER:-}"
if [ -z "$MOI" ] || [ "$MOI" = "root" ]; then
  echo "Lance-le depuis ton compte avec sudo (pas en root) : sudo ./boss/surprise.sh $*"
  exit 1
fi
MAISON=$(getent passwd "$MOI" | cut -d: -f6)
ETAT=/var/lib/glitch-surprise
mkdir -p "$ETAT"; chmod 700 "$ETAT"
PORT=31337
UNITE=cache-maj

lent() { local t="$1" i; for ((i=0; i<${#t}; i++)); do printf '%s' "${t:i:1}"; sleep 0.01; done; echo; }
titre() { printf '\n\e[35m%s\e[0m\n' "$1"; }

# ------------------------------------------------------------------ lundi
lundi_poser() {
  stat -c %a "$MAISON" > "$ETAT/maison-avant"
  chmod 755 "$MAISON"
  mkdir -p "$MAISON/Documents"; chown "$MOI": "$MAISON/Documents"
  printf 'Plan du Glitch : revenir mardi.\n' > "$MAISON/Documents/plan-du-glitch.txt"
  chown "$MOI": "$MAISON/Documents/plan-du-glitch.txt"; chmod 666 "$MAISON/Documents/plan-du-glitch.txt"
  mkdir -p "$MAISON/.glitch"
  cat > "$MAISON/.glitch/LISEZMOI" <<'FIN'
Tu m'as trouve. Bien joue.
Dis au maitre du jeu : « quete cachee H1, le compte dormant ».
Puis efface-moi proprement.
FIN
  chown -R "$MOI": "$MAISON/.glitch"; chmod 777 "$MAISON/.glitch"; chmod 666 "$MAISON/.glitch/LISEZMOI"
  touch "$ETAT/lundi"
}
lundi_compter() {
  local n=0 m
  m=$(stat -c %a "$MAISON"); [ "${m: -1}" != "0" ] && n=$((n + 1))
  [ -n "$(find "$MAISON" -maxdepth 2 -name 'plan-du-glitch.txt' -perm -0002 2>/dev/null)" ] && n=$((n + 1))
  [ -d "$MAISON/.glitch" ] && [ -n "$(find "$MAISON/.glitch" -perm -0002 2>/dev/null)" ] && n=$((n + 1))
  echo "$n"
}
lundi_nettoyer() {
  local avant=750; [ -f "$ETAT/maison-avant" ] && avant=$(cat "$ETAT/maison-avant")
  [ "${avant: -1}" != "0" ] && avant=750
  chmod "$avant" "$MAISON"
  rm -f "$MAISON/Documents/plan-du-glitch.txt"; rm -rf "$MAISON/.glitch"
  rm -f "$ETAT/lundi" "$ETAT/maison-avant"
}

# ------------------------------------------------------------------ mardi
mardi_poser() {
  mkdir -p /var/lib/cache-maj
  cat > /var/lib/cache-maj/index.html <<'FIN'
<!doctype html><meta charset="utf-8"><title>cache</title>
<p>Tu as eu la curiosite de regarder ce que je sers. Bien joue.</p>
<p>Dis au maitre du jeu : « quete cachee H2, qui m'a lance ? ».</p>
FIN
  if [ -d /run/systemd/system ]; then
    systemd-run --quiet --unit="$UNITE" --description="Cache des mises a jour" \
      python3 -m http.server "$PORT" --bind 0.0.0.0 --directory /var/lib/cache-maj >/dev/null 2>&1
  else
    (cd /var/lib/cache-maj && setsid nohup python3 -m http.server "$PORT" --bind 0.0.0.0 >/dev/null 2>&1 &)
  fi
  if command -v ufw >/dev/null 2>&1; then ufw allow "$PORT"/tcp >/dev/null 2>&1; fi
  touch "$ETAT/mardi"
}
mardi_compter() {
  local n=0
  ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Eq ":$PORT\$" && n=$((n + 1))
  if command -v ufw >/dev/null 2>&1 && ufw show added 2>/dev/null | grep -q "$PORT"; then n=$((n + 1)); fi
  echo "$n"
}
mardi_nettoyer() {
  if [ -d /run/systemd/system ]; then systemctl stop "$UNITE" >/dev/null 2>&1; fi
  pkill -f "http.server $PORT" >/dev/null 2>&1
  if command -v ufw >/dev/null 2>&1; then ufw delete allow "$PORT"/tcp >/dev/null 2>&1; fi
  rm -rf /var/lib/cache-maj; rm -f "$ETAT/mardi"
}

# ------------------------------------------------------------------ jeudi
CLE_NOM="maintenance@borne-11nov"
jeudi_poser() {
  local t; t=$(mktemp -d)
  ssh-keygen -q -t ed25519 -N "" -C "$CLE_NOM" -f "$t/cle" >/dev/null
  mkdir -p "$MAISON/.ssh"; chown "$MOI": "$MAISON/.ssh"; chmod 700 "$MAISON/.ssh"
  cat "$t/cle.pub" >> "$MAISON/.ssh/authorized_keys"
  chown "$MOI": "$MAISON/.ssh/authorized_keys"; chmod 600 "$MAISON/.ssh/authorized_keys"
  rm -rf "$t"
  if command -v crontab >/dev/null 2>&1; then
    { crontab -u "$MOI" -l 2>/dev/null
      echo "# Quete cachee H3 : demande au maitre du jeu « d'ou vient cette cle ? »"
      echo "*/10 * * * * /bin/true glitch-reviens"; } | crontab -u "$MOI" - 2>/dev/null
  fi
  touch "$ETAT/jeudi"
}
jeudi_compter() {
  local n=0
  grep -qs "$CLE_NOM" "$MAISON/.ssh/authorized_keys" && n=$((n + 1))
  if command -v crontab >/dev/null 2>&1 && crontab -u "$MOI" -l 2>/dev/null | grep -q "glitch-reviens"; then n=$((n + 1)); fi
  echo "$n"
}
jeudi_total() { if command -v crontab >/dev/null 2>&1; then echo 2; else echo 1; fi; }
jeudi_nettoyer() {
  [ -f "$MAISON/.ssh/authorized_keys" ] && sed -i "/$CLE_NOM/d" "$MAISON/.ssh/authorized_keys"
  if command -v crontab >/dev/null 2>&1; then
    crontab -u "$MOI" -l 2>/dev/null | grep -v -e "glitch-reviens" -e "Quete cachee H3" | crontab -u "$MOI" - 2>/dev/null
  fi
  rm -f "$ETAT/jeudi"
}

total() { case "$1" in lundi) echo 3 ;; mardi) echo 2 ;; jeudi) jeudi_total ;; esac; }
jour_ok() { case "${1:-}" in lundi|mardi|jeudi) return 0 ;; *) return 1 ;; esac; }
usage() {
  echo "Usage : sudo ./boss/surprise.sh lundi|mardi|jeudi"
  echo "        sudo ./boss/surprise.sh verifier lundi|mardi|jeudi"
  echo "        sudo ./boss/surprise.sh nettoyer lundi|mardi|jeudi|tout"
  exit 1
}

case "${1:-}" in
  verifier)
    jour_ok "${2:-}" || usage
    j="$2"; reste=$("${j}_compter"); tot=$(total "$j")
    titre "Le Glitch, attaque surprise du $j"
    if [ ! -f "$ETAT/$j" ]; then echo "  Le Glitch n'est pas encore passé ici pour le $j."; exit 0; fi
    if [ "$reste" -eq 0 ]; then
      printf '  \e[32mToutes les traces du Glitch sont effacées (%s sur %s). Montre cet écran au maître du jeu.\e[0m\n' "$tot" "$tot"
    else
      printf '  \e[31mIl reste %s trace(s) du Glitch sur %s.\e[0m Je ne te dis pas où.\n' "$reste" "$tot"
    fi
    echo "  Vérifié le $(date '+%d/%m/%Y à %H:%M') sur $(hostname), compte $MOI." ;;
  nettoyer)
    case "${2:-}" in
      lundi|mardi|jeudi) "${2}_nettoyer" ;;
      tout) lundi_nettoyer; mardi_nettoyer; jeudi_nettoyer ;;
      *) usage ;;
    esac
    echo "  Traces du Glitch retirées (${2})." ;;
  lundi|mardi|jeudi)
    j="$1"
    if [ -f "$ETAT/$j" ]; then echo "  Le Glitch est déjà passé ici pour le $j. Vérifie : sudo ./boss/surprise.sh verifier $j"; exit 0; fi
    "${j}_poser"
    titre "GLITCH !"
    case "$j" in
      lundi) lent "Pendant que tu regardais tes comptes, je suis passé par tes dossiers. J'ai laissé $(total lundi) portes ouvertes chez toi." ;;
      mardi) lent "Tu as fermé tes portes ce matin ? J'en ai ouvert une nouvelle, et j'ai prévenu ton pare-feu. $(total mardi) traces à trouver." ;;
      jeudi) lent "Mercredi était férié. Pas pour moi. J'ai laissé de quoi revenir quand je veux : $(total jeudi) trace(s) à trouver." ;;
    esac
    echo
    echo "  Rien n'est cassé, et rien ne sort de ta machine. À toi de trouver et de corriger."
    echo "  Pour savoir combien il en reste : sudo ./boss/surprise.sh verifier $j" ;;
  *) usage ;;
esac
