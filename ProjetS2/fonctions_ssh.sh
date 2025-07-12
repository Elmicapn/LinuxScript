#!/bin/bash

creer_ssh_config_template() {
    mkdir -p "$POINT_MONT"
    CONF="$POINT_MONT/ssh_config"
    echo "[*] Création d'un template de configuration SSH dans $CONF"
    cat > "$CONF" <<EOF
Host exemple
    HostName exemple.com
    User $USER
    IdentityFile $POINT_MONT/id_rsa
    IdentitiesOnly yes
EOF
    chmod 600 "$CONF"
    chown root:root "$CONF"
    echo "Template SSH créé."
}


importer_ssh_config() {
    SSH_CONF="$HOME/.ssh/config"
    if [ ! -f "$SSH_CONF" ]; then
        echo "Pas de fichier $SSH_CONF trouvé."
        return 1
    fi

    echo "[*] Hosts trouvés dans $SSH_CONF :"
    HOSTS=($(grep '^Host ' "$SSH_CONF" | awk '{print $2}'))
    if [ ${#HOSTS[@]} -eq 0 ]; then
        echo "Aucun host trouvé."
        return 1
    fi

    select h in "${HOSTS[@]}"; do
        if [ -n "$h" ]; then
            HOST_SELECTED="$h"
            break
        fi
    done

    START=$(grep -n "^Host $HOST_SELECTED" "$SSH_CONF" | cut -d: -f1)
    END=$(tail -n +"$((START+1))" "$SSH_CONF" | grep -n "^Host " | head -n1 | cut -d: -f1)
    if [ -z "$END" ]; then
        END=$(wc -l < "$SSH_CONF")
        END=$((END+1))
    else
        END=$((START + END - 1))
    fi

    mkdir -p "$POINT_MONT"
    CONF="$POINT_MONT/ssh_config"

    sed -n "${START},${END}p" "$SSH_CONF" > "$CONF"
    chmod 600 "$CONF"
    chown root:root "$CONF"

    echo "[*] Config SSH importée dans $CONF."

    ID_FILE=$(grep 'IdentityFile' "$CONF" | awk '{print $2}' | head -n1)
    if [ -n "$ID_FILE" ] && [ -f "$ID_FILE" ]; then
        cp "$ID_FILE" "$POINT_MONT/"
        chmod 600 "$POINT_MONT/$(basename "$ID_FILE")"
        chown root:root "$POINT_MONT/$(basename "$ID_FILE")"
        sed -i "s|$ID_FILE|$POINT_MONT/$(basename "$ID_FILE")|" "$CONF"
        echo "[*] Clé privée copiée et référence mise à jour."
    else
        echo "[!] Aucune clé IdentityFile trouvée ou le fichier n'existe pas."
    fi
}

creer_alias_evsh() {
    ALIAS_FILE="$POINT_MONT/alias_evsh"
    echo "alias evsh=\"ssh -F $POINT_MONT/ssh_config\"" > "$ALIAS_FILE"
    chmod 644 "$ALIAS_FILE"
    chown root:root "$ALIAS_FILE"
    echo "[*] Alias evsh créé dans $ALIAS_FILE."
    echo "Pour l'activer, ajoutez dans ~/.bashrc ou ~/.bash_aliases :"
    echo "source $ALIAS_FILE"
}
