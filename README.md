# GUILDE DES REMPART

### Roles

Pierre-Louis Le Guen-Geffroy : Chef de Guilde

Abdelouadoud Benali : Gardien

Ilian Djemai : Rempart

Rayanatou Dialo : Passeuse

Guilde du Rempart

la suite de commandes à exécuter dans l'ordre pour valider les 3 épreuves de la **Guilde du Rempart** :

```bash
sudo ufw enable
sudo ufw logging medium
sudo ufw limit OpenSSH
sudo ufw status numbered

```

### le seul point d'attention

le script vérifie qu'il n'existe **aucune règle `ALLOW` ouverte à tout le monde (`Anywhere`)**.

Si tu as déjà autorisé SSH avant, `ufw limit OpenSSH` ajoute la limite, mais **laisse l'ancienne règle `ALLOW` active**.

Regarde la liste affichée par `sudo ufw status numbered` et supprime toutes les lignes marquées `ALLOW` avec leur numéro :

```bash
sudo ufw delete <regle>

```

