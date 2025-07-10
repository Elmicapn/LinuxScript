#!/bin/bash

# Variables communes
IMAGE="env.img"
NOM_DU_VOLUME="crypt"
POINT_MONT="/mnt/secure_env"
GPG_KEY_PATH="$POINT_MONT/gpg_keys"

if [ "$SUDO_USER" != "" ]; then
    MAINUSER="$SUDO_USER"
else
    MAINUSER="$USER"
fi

is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Source les autres fichiers
source "$(dirname "$0")/fonctions_env.sh"
source "$(dirname "$0")/fonctions_gpg.sh"
source "$(dirname "$0")/fonctions_ssh.sh"

# Menu
OPTIONS=(
    "Installer l'environnement"
    "Ouvrir"
    "Fermer"
    "Générer clé GPG"
    "Exporter clé GPG"
    "Importer clé GPG"
    "Créer template SSH config"
    "Importer config SSH"
    "Créer alias evsh"
    "Afficher périphériques"
    "Quitter"
)

PS3="Choisissez une option (1-${#OPTIONS[@]}): "

select choix in "${OPTIONS[@]}"; do
    case $REPLY in
        1) instal ;;
        2) ouvrir ;;
        3) fermer ;;
        4) genere_gpg_key ;;
        5) export_gpg_from_keyring ;;
        6) import_gpg_to_keyring ;;
        7) creer_ssh_config_template ;;
        8) importer_ssh_config ;;
        9) creer_alias_evsh ;;
        10) lsblk ;;
        11) echo "Fermeture du script."; break ;;
        *) echo "Option invalide." ;;
    esac
done
