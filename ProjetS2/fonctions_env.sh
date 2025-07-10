#!/bin/bash

instal() {
    if ! is_root; then echo "Il faut être root pour cette action."; return 1; fi
    echo "Installation de l'environnement sécurisé"

    read -p "Entrez la taille de l'environnement (ex: 5G ou 512M): " TAILLE

    # Vérifie le format
    if [[ ! "$TAILLE" =~ ^[0-9]+[GgMm]$ ]]; then
        echo "[!] Format invalide. Exemple valide: 5G ou 512M"
        return 1
    fi

    UNIT="${TAILLE: -1}"
    SIZE="${TAILLE:0:-1}"

    if [ -f "$IMAGE" ]; then
        echo "[!] Le fichier $IMAGE existe déjà. Supprimez-le ou changez de nom."
        return 1
    fi

    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l "$TAILLE" "$IMAGE"
    else
        if [[ "$UNIT" =~ [Gg] ]]; then
            COUNT=$((SIZE * 1024))
        else
            COUNT=$SIZE
        fi
        dd if=/dev/zero of="$IMAGE" bs=1M count=$COUNT status=progress
    fi

    LOOP=$(losetup --find --show "$IMAGE")
    echo "Loop device utilisé : $LOOP"

    echo "Définissez le mot de passe pour l'environnement sécurisé :"
    cryptsetup luksFormat "$LOOP"
    cryptsetup luksOpen "$LOOP" $NOM_DU_VOLUME

    mkfs.ext4 /dev/mapper/$NOM_DU_VOLUME

    mkdir -p "$POINT_MONT"
    mount /dev/mapper/$NOM_DU_VOLUME "$POINT_MONT"

    mkdir -p "$GPG_KEY_PATH"
    chmod 700 "$POINT_MONT"
    chmod 700 "$GPG_KEY_PATH"
    chown -R $MAINUSER:$MAINUSER "$POINT_MONT"

    losetup -d "$LOOP"
    echo "Environnement sécurisé installé et monté à $POINT_MONT"
}

ouvrir() {
    if ! is_root; then echo "Il faut être root pour cette action."; return 1; fi
    LOOP=$(losetup --find --show "$IMAGE")
    cryptsetup luksOpen "$LOOP" $NOM_DU_VOLUME
    mkdir -p "$POINT_MONT"
    mount /dev/mapper/$NOM_DU_VOLUME "$POINT_MONT"
    chmod 700 "$POINT_MONT"
    chmod 700 "$GPG_KEY_PATH"
    chown -R $MAINUSER:$MAINUSER "$POINT_MONT"
    losetup -d "$LOOP"
    echo "Environnement ouvert à $POINT_MONT"
}

fermer() {
    if ! is_root; then echo "Il faut être root pour cette action."; return 1; fi
    umount "$POINT_MONT"
    cryptsetup luksClose $NOM_DU_VOLUME
    echo "Environnement fermé"
}
