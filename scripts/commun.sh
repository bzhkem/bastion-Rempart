#!/usr/bin/env bash
XP=0
TOTAL=0
LIGNES=()

resultat() {
  local etat="$1" points="$2" titre="$3" conseil="$4"
  case "$etat" in
    ok)
      TOTAL=$((TOTAL + points)); XP=$((XP + points))
      printf '  [ OK ]     +%-3s %s\n' "$points" "$titre"
      LIGNES+=("| OK | $titre | +$points |") ;;
    ko)
      TOTAL=$((TOTAL + points))
      printf '  [A FAIRE]  %-4s %s\n' "" "$titre"
      printf '             -> %s\n' "$conseil"
      LIGNES+=("| A faire | $titre : $conseil | 0 / $points |") ;;
    nv)
      printf '  [ ?? ]     %-4s %s\n' "" "$titre"
      [ -n "$conseil" ] && printf '             -> %s\n' "$conseil"
      LIGNES+=("| Non vérifiable | $titre | retiré du calcul |") ;;
    info)
      printf '  [ INFO ]   %-4s %s\n' "" "$titre"
      LIGNES+=("| Info | $titre | |") ;;
  esac
}

score_final() {
  local nom="$1" fichier="$2"
  local score=0 couleur
  if [ "$TOTAL" -gt 0 ]; then score=$((XP * 100 / TOTAL)); fi
  if [ "$score" -ge 80 ]; then couleur="VERT"
  elif [ "$score" -ge 50 ]; then couleur="ORANGE"
  else couleur="ROUGE"; fi
  echo
  echo "  Score : $score / 100   Couleur : $couleur"
  echo
  if [ -n "$fichier" ]; then
    mkdir -p "$(dirname "$fichier")" 2>/dev/null
    {
      echo "# $nom : $(hostname), $(date '+%d/%m/%Y %H:%M')"
      echo
      echo "Score : **$score / 100** ($couleur)"
      echo
      echo "| État | Point | Points |"
      echo "|---|---|---|"
      printf '%s\n' "${LIGNES[@]}"
    } > "$fichier" || { echo "  Impossible d'écrire le rapport : $fichier"; return; }
    if [ -n "${SUDO_USER:-}" ]; then chown "$SUDO_USER": "$fichier" 2>/dev/null; fi
    echo "  Rapport enregistré : $fichier"
  fi
}

sshd_conf() {
  if [ -d /run/sshd ]; then /usr/sbin/sshd -T 2>/dev/null
  else unshare -m sh -c 'mount -t tmpfs tmpfs /run && mkdir /run/sshd && exec /usr/sbin/sshd -T' 2>/dev/null
  fi
}

sshd_erreur() {
  if [ -d /run/sshd ]; then /usr/sbin/sshd -t 2>&1 | head -1
  else unshare -m sh -c 'mount -t tmpfs tmpfs /run && mkdir /run/sshd && exec /usr/sbin/sshd -t' 2>&1 | head -1
  fi
}

pas_en_root() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "Lance-moi sans sudo : le mot de passe sera demandé quand il le faut."
    exit 1
  fi
}
