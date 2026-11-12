============================================================
RAPPORT TECHNIQUE PERSONNEL : SÉCURISATION DE MON POSTE UBUNTU
============================================================

Pour transformer mon PC Ubuntu en bastion, j’ai sécurisé la machine étape par étape :

------------------------------------------------------------
1. UBUNTU : MISES À JOUR, COMPTES ET DROITS
------------------------------------------------------------
• Mises à jour :
  J’ai mis le système à niveau avec "sudo apt update" et 
  "sudo apt upgrade -y" pour corriger les failles connues, 
  puis activé les correctifs automatiques avec "sudo dpkg-reconfigure -plow unattended-upgrades".

• Comptes :
  J’ai vérifié avec "getent group sudo" que j’étais le seul administrateur, 
  et avec "sudo passwd -S root" que le compte root était verrouillé. 
  J’ai ensuite créé un compte invité stagiaire sans droits admin via "sudo adduser stagiaire".

• Protection :
  J’ai fermé mon dossier personnel aux autres comptes avec "chmod 750 ~" 
  et coupé le service d’imprimantes réseau inutile avec "sudo systemctl disable --now cups-browsed".

------------------------------------------------------------
2. UFW : LE PARE-FEU
------------------------------------------------------------
• Filtrage réseau :
  J’ai activé le pare-feu avec "sudo ufw default deny incoming",
  "sudo ufw default allow outgoing" et "sudo ufw enable". 
  Tout ce qui vient de l’extérieur est bloqué par défaut, mais je garde mon accès à Internet.

------------------------------------------------------------
3. SSH : L’ACCÈS À DISTANCE BLINDÉ
------------------------------------------------------------
• Clé de connexion :
  J’ai installé le serveur avec "sudo apt install -y openssh-server", créé ma clé avec "ssh-keygen -t ed25519" 
  et copié ma clé publique sur le poste avec "ssh-copy-id localhost".

• Blocage des mots de passe :
  Dans "/etc/ssh/sshd_config.d/10-bastion.conf", j’ai ajouté "PermitRootLogin no", "PasswordAuthentication no" 
  et "KbdInteractiveAuthentication no", puis redémarré le service avec "sudo systemctl restart ssh". 
  Désormais, seule ma clé permet d’entrer.

------------------------------------------------------------
4. FAIL2BAN : LA SURVEILLANCE ACTIVE
------------------------------------------------------------
• Bannissement automatique :
  J’ai installé l’outil avec "sudo apt install -y fail2ban" pour surveiller les journaux. 
  Dans "/etc/fail2ban/jail.local", j’ai réglé la prison sshd sur "maxretry = 5", "findtime = 10m" et "bantime = 10m",
  puis relancé avec "sudo systemctl restart fail2ban".
  Si quelqu’un rate 5 essais en 10 minutes, il est banni 10 minutes.

============================================================
BILAN FINAL
============================================================
En relançant le bilan avec "./menu.sh" dans "~/bastion_tp", mon score est passé au vert, 100/100.
