#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
if [ "$(id -u)" -eq 0 ]; then echo "Lance le menu sans sudo : ./menu.sh (le mot de passe sera demandé quand il le faut)."; exit 1; fi
montrer() {
  echo
  printf '\e[2mCommande lancée (tu peux la taper toi-même) :\e[0m\n'
  printf '  \e[36m%s\e[0m\n\n' "$*"
}
lancer() { montrer "$@"; "$@"; }

while true; do
  echo
  printf '\e[33m=============================================\e[0m\n'
  printf '\e[33m  KIT DU BASTION\e[0m\n'
  printf '\e[33m=============================================\e[0m\n'
  echo "  Lundi : le bastion"
  echo "   1  Bilan du bastion           (lit seulement, demande ton mot de passe)"
  echo "   2  Comptes et droits          (lit seulement)"
  echo "  Mardi : les remparts"
  echo "   3  Qui écoute ?               (lit seulement, demande ton mot de passe)"
  echo "   4  Qui a frappé à la porte ?  (lit seulement, demande ton mot de passe)"
  echo "  Jeudi : la borne Wi-Fi"
  echo "   5  Installer la borne         (une seule fois)"
  echo "   6  Allumer la borne"
  echo "   7  Éteindre la borne"
  echo "   8  Bilan de la borne          (lit seulement)"
  echo "   9  Sauvegarder la borne       (copie sa configuration dans sauvegardes)"
  echo "  10  Remettre la borne en sortie d'usine (efface tes réglages)"
  echo "  Toute la semaine"
  echo "  11  Spécialités des guildes    (lit seulement)"
  echo
  echo "   0  Quitter"
  read -r -p "Ton choix : " choix
  case "$choix" in
    1) lancer sudo ./scripts/bilan-bastion.sh ;;
    2) lancer ./scripts/comptes.sh ;;
    3) lancer sudo ./scripts/ecoute.sh ;;
    4) lancer sudo ./scripts/journaux.sh ;;
    5) lancer ./scripts/borne.sh installer ;;
    6) lancer ./scripts/borne.sh demarrer ;;
    7) lancer ./scripts/borne.sh arreter ;;
    8) lancer ./scripts/bilan-borne.sh ;;
    9) lancer ./scripts/borne.sh sauvegarder ;;
    10) lancer ./scripts/borne.sh usine ;;
    11) lancer sudo ./scripts/specialites.sh ;;
    0) exit 0 ;;
    *) echo "Choix inconnu : tape un nombre de 0 à 11." ;;
  esac
  echo
  read -r -p "Appuie sur Entrée pour revenir au menu " _
done
