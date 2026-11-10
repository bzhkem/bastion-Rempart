# Bilan du bastion : user-vmwarevirtualplatform, 10/11/2026 11:06

Score : **68 / 100** (ORANGE)

| État | Point | Points |
|---|---|---|
| A faire | Système à jour : des mises à jour attendent un redémarrage : redémarre la machine | 0 / 15 |
| OK | Mises à jour de sécurité automatiques | +10 |
| A faire | Pare-feu actif, entrées refusées par défaut : sudo ufw default deny incoming puis sudo ufw enable (quête 7) | 0 / 15 |
| OK | Compte root verrouillé | +5 |
| OK | Aucun compte sans mot de passe | +5 |
| OK | Un seul administrateur : toi | +10 |
| OK | Verrouillage automatique de l'écran (10 min au plus) | +5 |
| OK | Dossier personnel fermé aux autres comptes (750) | +5 |
| OK | Aucun serveur SSH installé (rien à attaquer de ce côté) | +15 |
| OK | Aucun port TCP ouvert au réseau, sauf SSH | +10 |
| Non vérifiable | fail2ban surveille SSH | retiré du calcul |
| Info | AppArmor actif : chaque programme protégé reste dans sa cage | |
| Info | Disque non chiffré : on n'y touche pas cette semaine, à signaler au maître du jeu | |
