### 1. Sécuriser le Bastion 

L'objectif est de verrouiller toutes les entrées sauf une, et d'exiger une clé cryptographique plutôt qu'un mot de passe devinable.

**Suite 1 : Remplacer le mot de passe par une clé SSH**
Cette suite se tape depuis votre ordinateur personnel, avant même de configurer le serveur.

```bash
ssh-keygen -t ed25519

# envoi de la clée ssh sur bastillon
ssh-copy-id root@127.0.0.1 #l'ip du serveur (loopback)

```

*Explication :* Une fois la clé copiée, le bastion vous laissera entrer sans mot de passe, car il reconnaîtra votre clée.

Une fois connecté avec votre clé, l'étape suivante consiste à ouvrir le fichier de configuration du serveur (`/etc/ssh/sshd_config`), d'y chercher la ligne `PasswordAuthentication` et de la passer sur `no`. On redémarre ensuite le service pour fermer définitivement la porte aux attaques par mots de passe.

**Suite 2 : Monter la garde avec le Pare-feu (UFW)**
On va ordonner au système de rejeter les inconnus par défaut. Les commandes s'enchaînent logiquement :

```bash
# on bloque tentative d'entrer
sudo ufw default deny incoming

# on autorise le serveur à sortir
sudo ufw default allow outgoing

# on crée une exception
sudo ufw allow ssh

# on active les nouvelles régles
sudo ufw enable

```

*Fail2ban :*
il suffit de taper `sudo apt install fail2ban`. Dès son installation, il tourne en arrière-plan. Il lit les journaux en temps réel : si un robot tente de se connecter en boucle, Fail2ban ordonne automatiquement à UFW de bannir l'adresse IP du robot pour une durée déterminée.


### 2. La Borne Wi-Fi 

si votre système gère aussi la diffusion du réseau sans fil, cela passe par un service appelé `hostapd`. la sécurité ne se gère pas par une suite de commandes, mais par un fichier de configuration.

*configuration WPA3 :*
Dans le fichier de réglages du Wi-Fi (souvent `/etc/hostapd/hostapd.conf`), on ignore les anciens chiffrements et on impose les standards modernes. les lignes clés ressemblent à ceci :

```bash
wpa=2              
wpa_key_mgmt=SAE   # mécanique d'authentification exclusive au WPA3
rsn_pairwise=CCMP 

```

**suite de validation du réseau Wi-Fi :**
Une fois le fichier modifié et sauvegardé, on relance la machine :

```bash
# on redémarre le diffuseur Wi-Fi avec les nouveaux paramètres
sudo systemctl restart hostapd

# on vérifie qu'il n'a pas planté suite à une erreur de syntaxe
sudo systemctl status hostapd

```
