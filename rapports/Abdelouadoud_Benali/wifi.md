============================================================
RAPPORT TECHNIQUE PERSONNEL : SÉCURISATION DE MA BORNE WI-FI
============================================================

Pour sécuriser ma borne Wi-Fi OpenWrt, je suis parti d’une configuration sortie d’usine et je l’ai blindée étape par étape :

------------------------------------------------------------
1. ADMINISTRATION : FERMER L’ACCÈS D’USINE
------------------------------------------------------------
• Allumage et mot de passe :
  J’ai démarré la borne via le menu (choix 6), puis je me suis connecté à l’interface web LuCI sur "http://127.0.0.1:8080" qui n’avait aucun mot de passe au départ. Dans Système > Administration, j’ai défini un mot de passe fort de 20 caractères (rangé dans Bitwarden) pour verrouiller l’accès.

------------------------------------------------------------
2. WI-FI PRINCIPAL : CHIFFREMENT MODERNE
------------------------------------------------------------
• Nom et sécurité sans-fil :
  Dans LuCI (Réseau > Sans-fil), j’ai modifié la première radio pour donner un nom neutre au réseau (ESSID), sans mon nom ni la marque de l’appareil. J’ai activé le chiffrement "WPA2-PSK/WPA3-SAE Mixed Mode" avec une phrase de passe longue générée dans Bitwarden, puis j’ai vérifié que le réseau était bien actif avec "iwinfo" en SSH.

------------------------------------------------------------
3. RÉSEAU INVITÉ : ISOLER LES VISITEURS
------------------------------------------------------------
• Séparation réseau et pare-feu :
  En SSH avec l’outil "uci", j’ai créé un second Wi-Fi sur la deuxième radio avec sa propre plage d’adresses (192.168.2.1/24) et son serveur DHCP. J’ai réglé sa zone de pare-feu en "input=REJECT" et "forward=REJECT" pour bloquer l’accès à la borne et à mon réseau privé (lan), en autorisant uniquement Internet (wan).

• Isolement des clients :
  J’ai activé le chiffrement "sae-mixed" et l’option "isolate=1" pour que les invités connectés ne puissent pas se voir entre eux, avant d’enregistrer et d’appliquer avec "uci commit" et "reload_config".

------------------------------------------------------------
4. SSH, HTTPS ET SAUVEGARDE
------------------------------------------------------------
• SSH par clé uniquement :
  J’ai copié ma clé publique dans "/etc/dropbear/authorized_keys", puis j’ai coupé les mots de passe et limité SSH au réseau privé avec "uci set dropbear.@dropbear[0].PasswordAuth=off", "RootPasswordAuth=off" et "Interface=lan".

• Interface chiffrée et sauvegarde :
  J’ai forcé le passage de LuCI en HTTPS (https://127.0.0.1:8443) via "uci set uhttpd.main.redirect_https=1" avant de redémarrer "dropbear" et "uhttpd". J’ai ensuite sauvegardé ma configuration avec le choix 9 du menu.

============================================================
BILAN ET REMARQUE
============================================================
Une fois toutes ces étapes terminées et malgré le fait que j’aie bien sauvegardé ma configuration, je ne pouvais plus accéder aux choix 8 (bilan de la borne) et 9 (sauvegarde) depuis le menu.
