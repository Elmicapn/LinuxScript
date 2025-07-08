#!/bin/bash

IMAGE="env.img"
NOM_DU_VOLUME="crypt"
POINT_MONT="/mnt/secure_env"
GPG_KEY_PATH="$POINT_MONT/gpg_keys"
OPTIONS=("Installer l'environnement" "Ouvrir" "Fermer" "Générer clé GPG" "Exporter clé GPG" "Importer clé GPG" "Importer conf SSH" "Afficher périphériques" "Quitter")

# On détecte l'utilisateur d'origine si root, sinon $USER
if [ "$SUDO_USER" != "" ]; then
    MAINUSER="$SUDO_USER"
else
    MAINUSER="$USER"
fi

is_root() {
    [ "$(id -u)" -eq 0 ]
}

instal() {
    if ! is_root; then echo "Il faut être root pour cette action."; return 1; fi
    echo "Installation de l'environnement sécurisé"
    read -p "Entrez la taille de l'environnement (ex: 5G): " TAILLE

    if [ -f "$IMAGE" ]; then
        echo "[!] Le fichier $IMAGE existe déjà. Supprimez-le ou changez de nom."
        return 1
    fi

    fallocate -l "$TAILLE" "$IMAGE" || dd if=/dev/zero of="$IMAGE" bs=1M count=$(( ${TAILLE%G} * 1024 )) status=progress

    LOOP=$(losetup --find --show "$IMAGE")
    echo "Loop device utilisé : $LOOP"

    echo "Définissez le mot de passe pour l'environnement sécurisé :"
    cryptsetup luksFormat "$LOOP"
    cryptsetup luksOpen "$LOOP" $NOM_DU_VOLUME

    mkfs.ext4 /dev/mapper/$NOM_DU_VOLUME

    mkdir -p $POINT_MONT
    mount /dev/mapper/$NOM_DU_VOLUME $POINT_MONT

    mkdir -p "$GPG_KEY_PATH"
    chown -R $MAINUSER:$MAINUSER $POINT_MONT
    chmod 700 $POINT_MONT $GPG_KEY_PATH

    losetup -d "$LOOP"
    echo "Environnement sécurisé installé et monté à $POINT_MONT"
}

ouvrir() {
    if ! is_root; then echo "Il faut être root pour cette action."; return 1; fi
    LOOP=$(losetup --find --show "$IMAGE")
    cryptsetup luksOpen "$LOOP" $NOM_DU_VOLUME
    mkdir -p $POINT_MONT
    mount /dev/mapper/$NOM_DU_VOLUME $POINT_MONT
    chown -R $MAINUSER:$MAINUSER $POINT_MONT
    losetup -d "$LOOP"
    echo "Environnement ouvert à $POINT_MONT"
}

fermer() {
    if ! is_root; then echo "Il faut être root pour cette action."; return 1; fi
    umount $POINT_MONT
    cryptsetup luksClose $NOM_DU_VOLUME
    echo "Environnement fermé"
}

genere_gpg_key() {
    if is_root; then echo "NE PAS lancer cette fonction en root ! Relance en user normal."; return 1; fi
    mkdir -p "$GPG_KEY_PATH"
    echo "[*] Génération automatique d'une clé GPG pour $USER"
    gpg --batch --gen-key <<EOF
Key-Type: default
Key-Length: 4096
Subkey-Type: default
Name-Real: $USER
Name-Comment: clef_env
Name-Email: ${USER}@env.local
Expire-Date: 0
%no-protection
%commit
EOF

    KEYID=$(gpg --list-keys --with-colons | grep '^pub' | tail -1 | cut -d: -f5)
    gpg --armor --export $KEYID > "$GPG_KEY_PATH/cle_pub.asc"
    gpg --armor --export-secret-keys $KEYID > "$GPG_KEY_PATH/cle_priv.asc"
    chmod 600 "$GPG_KEY_PATH/cle_priv.asc"
    chmod 644 "$GPG_KEY_PATH/cle_pub.asc"
    echo "Clé GPG générée et exportée dans $GPG_KEY_PATH"
}

export_gpg_from_keyring() {
    if is_root; then echo " NE PAS lancer cette fonction en root ! Relance en user normal."; return 1; fi
    ls "$GPG_KEY_PATH/"*.asc 2>/dev/null
    read -p "Entrer l'ID de la clé à exporter : " KEYID
    gpg --armor --export-secret-keys $KEYID > "$GPG_KEY_PATH/exported_$KEYID.asc"
    chmod 600 "$GPG_KEY_PATH/exported_$KEYID.asc"
    echo "Clé privée exportée dans $GPG_KEY_PATH/exported_$KEYID.asc"
}

import_gpg_to_keyring() {
    if is_root; then echo " NE PAS lancer cette fonction en root ! Relance en user normal."; return 1; fi
    ls "$GPG_KEY_PATH/"*.asc 2>/dev/null
    read -p "Chemin du fichier .asc a importer : " FIC
    gpg --import "$FIC"
    echo "Clé importée dans le trousseau de $USER"
}

PS3="Choisissez une option (1-${#OPTIONS[@]}) : "

select choix in "${OPTIONS[@]}"; do
    case $REPLY in
        1) instal ;;
        2) ouvrir ;;
        3) fermer ;;
        4) genere_gpg_key ;;
        5) export_gpg_from_keyring ;;
        6) import_gpg_to_keyring ;;
        7) echo "[*] Import SSH pas encore implémenté ici";;
        8) lsblk ;;
        9) echo "Fermeture du script."; break ;;
        *) echo "Option invalide." ;;
    esac
done
