### 1. Sécurisation du Bastion (Ubuntu)

Pour préparer le bastion Ubuntu, il faut d'abord appliquer les correctifs de sécurité, vérifier l'isolation des comptes utilisateurs et fermer tous les ports inutiles pour ne garder que l'accès SSH.

#### Mises à jour, comptes et droits sur les fichiers

On commence par mettre à jour les paquets et activer l'installation automatique des correctifs de sécurité (`unattended-upgrades`). On contrôle ensuite que le compte `root` est bien verrouillé (statut `L`) avant de créer un compte standard `stagiaire`. Pour éviter que ce dernier puisse parcourir nos dossiers, on restreint les droits du répertoire personnel avec `chmod 750 ~` et on réserve la lecture de `secret.txt` au seul propriétaire (`600`).

```bash
# mise a jour des paquets et activation des correctifs de securite auto
sudo apt update && sudo apt upgrade -y
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
sudo snap refresh

# verification de root verrouille (L) et creation d'un compte invite standard
sudo passwd -S root
sudo adduser stagiaire

# fermeture du dossier personnel et protection des fichiers sensibles
chmod 750 ~
chmod 600 ~/secret.txt

```

#### Fermeture des services inutiles et pare-feu UFW

Après avoir relevé les ports en écoute sur la machine (`ss -tulnp`), on coupe `cups-browsed` qui ne sert à rien sur un serveur. On configure ensuite UFW pour bloquer tout le trafic entrant par défaut tout en autorisant les flux sortants. La règle `ufw limit OpenSSH` permet de freiner les attaques par force brute en bloquant automatiquement une IP qui tente 6 connexions ou plus en 30 secondes. On vérifie enfin avec `status numbered` qu'aucune règle trop permissive (`Anywhere`) n'est restée active.

```bash
# lister les ports TCP/UDP ouverts et couper cups-browsed
sudo ss -tulnp
sudo systemctl disable --now cups-browsed

# politique par defaut : on bloque tout en entree, on autorise la sortie
sudo ufw default deny incoming
sudo ufw default allow outgoing

# journaux detailles et limitation SSH contre les rafales (specialite Rempart)
sudo ufw logging medium
sudo ufw limit OpenSSH

# activation du pare-feu et verification
sudo ufw enable
sudo ufw status numbered

```

#### Durcissement SSH et installation de Fail2ban

On remplace la connexion par mot de passe par une paire de clés `ed25519`. Une fois la clé copiée en local, on garde un terminal ouvert par sécurité avant de toucher à la configuration du démon SSH.

```bash
# installation du serveur SSH et creation de la paire de cles
sudo apt install -y openssh-server
ssh-keygen -t ed25519
ssh-copy-id localhost

```

Dans `/etc/ssh/sshd_config.d/10-bastion.conf`, on bloque la connexion root et l'authentification par mot de passe (`PermitRootLogin no`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`), puis on valide la syntaxe avant de relancer le service. On installe ensuite Fail2ban en configurant la prison `[sshd]` dans `/etc/fail2ban/jail.local` (`enabled = true`, `maxretry = 5`, `findtime = 10m`, `bantime = 10m`) afin de bannir pendant 10 minutes toute adresse IP qui échoue 5 fois de suite.

```bash
# verification de la config SSH et redemarrage du service
sudo mkdir -p /run/sshd
sudo sshd -t
sudo systemctl restart ssh

# installation de fail2ban et verification de la prison sshd
sudo apt install -y fail2ban
sudo nano /etc/fail2ban/jail.local
sudo fail2ban-client -t
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd

```

---

**Fichier 2 : `Kil-wifi.md**`

### 2. Sécurisation de la borne Wi-Fi (OpenWrt)

La borne tourne dans une VM OpenWrt équipée de deux interfaces radio simulées (`mac80211_hwsim`). L'idée est de supprimer la configuration ouverte d'usine, de chiffrer le réseau principal, de cloisonner le Wi-Fi invité et de verrouiller l'administration.

#### Mot de passe administrateur et Wi-Fi principal

Une fois la machine lancée depuis `./menu.sh` (choix 6), on se connecte sur l'interface web LuCI (`[http://127.0.0.1:8080](http://127.0.0.1:8080)`, rubrique *Système > Administration*) pour définir un mot de passe admin de 20 caractères généré via Bitwarden.

Côté sans-fil (*Réseau > Sans-fil*), on édite la première radio (2,4 GHz) pour lui donner un `ESSID` neutre (sans marque ni nom personnel) et activer le chiffrement `WPA2-PSK/WPA3-SAE Mixed Mode` avec une phrase de passe longue. Ce mode mixte permet aux appareils récents d'utiliser WPA3-SAE (protégé contre les attaques par dictionnaire hors ligne) tout en gardant la compatibilité WPA2. On vérifie ensuite l'état de la borne en SSH :

```bash
# connexion SSH a la borne et verification du point d'acces
ssh -p 2222 root@127.0.0.1
iwinfo

```

#### Création et isolation du réseau invité

Toujours en SSH sur la borne (`ssh -p 2222 root@127.0.0.1`), on utilise `uci` pour monter un sous-réseau séparé (`192.168.2.1/24`) sur `radio1` avec son propre serveur DHCP et sa zone de pare-feu.

Pour isoler complètement les invités, la zone `guest` refuse les connexions vers la borne elle-même (`input=REJECT`, ce qui coupe l'accès à LuCI et au SSH) et n'autorise le routage que vers Internet (`wan`), sans aucun passage vers le `lan`. On n'ouvre que les ports strictement nécessaires au réseau (DHCP 67-68 et DNS 53), et le paramètre `isolate=1` empêche les appareils invités de communiquer entre eux.

```bash
# creation de l'interface reseau guest et de son serveur DHCP
uci set network.guest=interface
uci set network.guest.proto=static
uci set network.guest.ipaddr=192.168.2.1/24
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface=guest
uci set dhcp.guest.start=100
uci set dhcp.guest.limit=50
uci set dhcp.guest.leasetime=1h

# creation de la zone pare-feu guest : acces Internet (wan) uniquement, aucun acces au lan
uci set firewall.guest=zone
uci set firewall.guest.name=guest
uci set firewall.guest.network=guest
uci set firewall.guest.input=REJECT
uci set firewall.guest.output=ACCEPT
uci set firewall.guest.forward=REJECT
uci set firewall.guest_wan=forwarding
uci set firewall.guest_wan.src=guest
uci set firewall.guest_wan.dest=wan

# autorisation du DHCP (67-68) et du DNS (53) pour les invites
uci set firewall.guest_dhcp=rule
uci set firewall.guest_dhcp.name=Allow-Guest-DHCP
uci set firewall.guest_dhcp.src=guest
uci set firewall.guest_dhcp.proto=udp
uci set firewall.guest_dhcp.dest_port=67-68
uci set firewall.guest_dhcp.target=ACCEPT
uci set firewall.guest_dns=rule
uci set firewall.guest_dns.name=Allow-Guest-DNS
uci set firewall.guest_dns.src=guest
uci set firewall.guest_dns.proto='tcp udp'
uci set firewall.guest_dns.dest_port=53
uci set firewall.guest_dns.target=ACCEPT

# activation du Wi-Fi invite sur radio1 avec isolement des clients
uci set wireless.radio1.disabled=0
uci set wireless.guest=wifi-iface
uci set wireless.guest.device=radio1
uci set wireless.guest.mode=ap
uci set wireless.guest.network=guest
uci set wireless.guest.ssid=Bastion-Invites
uci set wireless.guest.encryption=sae-mixed
uci set wireless.guest.key='CLE_INVITE'
uci set wireless.guest.isolate=1

# enregistrement et application des reglages
uci commit
reload_config

```

#### Authentification SSH par clé et passage en HTTPS

Pour terminer, on envoie notre clé publique dans `dropbear` depuis le bastion Ubuntu, puis on coupe l'authentification par mot de passe en SSH, on restreint l'écoute au réseau local (`lan`) et on force la redirection HTTPS sur l'interface web `uhttpd`.

```bash
# depuis Ubuntu : envoi de la cle publique sur la borne
ssh -p 2222 root@127.0.0.1 "cat >> /etc/dropbear/authorized_keys" < ~/.ssh/id_ed25519.pub

# dans la borne : coupure des mots de passe SSH, restriction au lan et passage en HTTPS
uci set dropbear.@dropbear[0].PasswordAuth=off
uci set dropbear.@dropbear[0].RootPasswordAuth=off
uci set dropbear.@dropbear[0].Interface=lan
uci commit dropbear
uci set uhttpd.main.redirect_https=1
uci commit uhttpd
service uhttpd restart
service dropbear restart

```
