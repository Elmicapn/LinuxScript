#!/bin/bash

genere_gpg_key() {
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

    if [ -z "$KEYID" ]; then
        echo "[!] Aucune clé n'a été générée."
        return 1
    fi

    gpg --armor --export "$KEYID" > "$GPG_KEY_PATH/cle_pub.asc"
    gpg --armor --export-secret-keys "$KEYID" > "$GPG_KEY_PATH/cle_priv.asc"

    chmod 600 "$GPG_KEY_PATH/cle_priv.asc"
    chmod 644 "$GPG_KEY_PATH/cle_pub.asc"
    chown root:root "$GPG_KEY_PATH/cle_priv.asc" "$GPG_KEY_PATH/cle_pub.asc"

    echo "Clé GPG générée et exportée dans $GPG_KEY_PATH"
}

export_gpg_from_keyring() {
    gpg --list-keys
    read -p "Entrer l'ID de la clé à exporter : " KEYID

    if [ -z "$KEYID" ]; then
        echo "[!] Aucun ID spécifié."
        return 1
    fi

    gpg --armor --export-secret-keys "$KEYID" > "$GPG_KEY_PATH/exported_${KEYID}.asc"
    chmod 600 "$GPG_KEY_PATH/exported_${KEYID}.asc"
    chown root:root "$GPG_KEY_PATH/exported_${KEYID}.asc"

    echo "Clé privée exportée dans $GPG_KEY_PATH/exported_${KEYID}.asc"
}

import_gpg_to_keyring() {
    ls "$GPG_KEY_PATH/"*.asc 2>/dev/null || {
        echo "[!] Aucun fichier .asc trouvé."
        return 1
    }
    read -p "Chemin du fichier .asc à importer : " FIC
    if [ ! -f "$FIC" ]; then
        echo "[!] Fichier inexistant."
        return 1
    fi
    gpg --import "$FIC"
    echo "Clé importée dans le trousseau de $USER"
}
