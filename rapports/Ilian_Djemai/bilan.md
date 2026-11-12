resumé du boss 
Dans cette quête, j’ai appris à sécuriser une borne Wi-Fi OpenWrt.

J’ai commencé par configurer les mots de passe et la sécurité du réseau Wi-Fi. Ensuite, je me suis connecté à la borne à distance grâce à SSH sur le port 2222.

J’ai installé ma clé publique SSH sur la borne pour pouvoir me connecter sans utiliser le mot de passe administrateur. Après avoir vérifié que la connexion fonctionnait, j’ai désactivé l’authentification SSH par mot de passe pour renforcer la sécurité.

J’ai ensuite enregistré les modifications avec uci commit et redémarré les services pour appliquer la configuration.

J’ai testé la connexion SSH pour vérifier que ma clé fonctionnait et que les connexions sans clé étaient refusées.

Enfin, j’ai configuré HTTPS pour sécuriser l’accès à l’interface web LuCI et j’ai vérifié que je pouvais y accéder depuis Firefox.

Ce que j’ai compris : cette quête m’a appris à protéger une borne Wi-Fi en sécurisant les mots de passe, en utilisant des clés SSH à la place des mots de passe et en chiffrant les connexions avec HTTPS.

Il me restait à finaliser la sauvegarde de la configuration de la borne.

