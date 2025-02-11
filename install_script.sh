#!/bin/bash

# Variables
DISK="/dev/sda"
EFI_PART="${DISK}1"
LUKS_PART="${DISK}2"
CRYPT_NAME="cryptroot"
VG_NAME="vg_arch"
LV_ROOT="lv_root"
LV_SWAP="lv_swap"
LV_VBOX="lv_vbox"
LV_SHARED="lv_shared"
LUKS_STORAGE="lv_luks_storage"
MOUNT_POINT="/mnt"
BOOT_MOUNT="$MOUNT_POINT/boot"
SHARED_DIR="$MOUNT_POINT/shared"
LUKS_PASSWORD="azerty123"
USER1="Collegue"
USER2="Fils"
USER_PASSWORD="azerty123"

# Vérifier que le script est exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

echo "Partitionnement du disque..."
# Création de la table de partition GPT et des partitions
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 512MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary 512MiB 100%

# Formater la partition EFI
mkfs.fat -F32 "$EFI_PART"

# Chiffrement LUKS
echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat "$LUKS_PART"
echo -n "$LUKS_PASSWORD" | cryptsetup open "$LUKS_PART" "$CRYPT_NAME"

# Initialisation LVM
pvcreate "/dev/mapper/$CRYPT_NAME"
vgcreate "$VG_NAME" "/dev/mapper/$CRYPT_NAME"
lvcreate -L 30G -n "$LV_ROOT" "$VG_NAME"
lvcreate -L 8G -n "$LV_SWAP" "$VG_NAME"
lvcreate -L 10G -n "$LUKS_STORAGE" "$VG_NAME"
lvcreate -L 20G -n "$LV_VBOX" "$VG_NAME"
lvcreate -L 5G -n "$LV_SHARED" "$VG_NAME"

# Formater les partitions
mkfs.ext4 "/dev/$VG_NAME/$LV_ROOT"
mkswap "/dev/$VG_NAME/$LV_SWAP"
mkfs.ext4 "/dev/$VG_NAME/$LV_VBOX"
mkfs.ext4 "/dev/$VG_NAME/$LV_SHARED"

# Monter les partitions
mount "/dev/$VG_NAME/$LV_ROOT" "$MOUNT_POINT"
mkdir "$BOOT_MOUNT"
mount "$EFI_PART" "$BOOT_MOUNT"
mkdir "$MOUNT_POINT/vbox"
mount "/dev/$VG_NAME/$LV_VBOX" "$MOUNT_POINT/vbox"
mkdir "$SHARED_DIR"
mount "/dev/$VG_NAME/$LV_SHARED" "$SHARED_DIR"

# Activer le swap
swapon "/dev/$VG_NAME/$LV_SWAP"

# Installation du système de base
pacstrap "$MOUNT_POINT" base base-devel linux linux-firmware lvm2 cryptsetup vim nano sudo networkmanager

# Génération du fstab
genfstab -U "$MOUNT_POINT" >> "$MOUNT_POINT/etc/fstab"

# Chroot dans le système
arch-chroot "$MOUNT_POINT" /bin/bash <<EOF

# Configuration de l'horloge
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

# Configuration du réseau
echo "archlinux" > /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    archlinux.localdomain archlinux" >> /etc/hosts
systemctl enable NetworkManager

# Installation de GRUB et configuration
pacman -S grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Configuration de LUKS au démarrage
echo "GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid -s UUID -o value $LUKS_PART):$CRYPT_NAME root=/dev/$VG_NAME/$LV_ROOT\"" >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Création des utilisateurs
useradd -m -G wheel $USER1
echo "$USER1:$USER_PASSWORD" | chpasswd
useradd -m -G wheel $USER2
echo "$USER2:$USER_PASSWORD" | chpasswd

# Activation de sudo pour le groupe wheel
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Installation des paquets nécessaires
pacman -S xorg firefox git virtualbox hyprland --noconfirm
systemctl enable vboxservice

# Création du dossier partagé et permissions
mkdir /home/$USER1/shared
mkdir /home/$USER2/shared
chmod 770 /home/$USER1/shared
chmod 770 /home/$USER2/shared
chown $USER1:$USER2 /home/$USER1/shared
chown $USER1:$USER2 /home/$USER2/shared

# Configuration de Hyprland
mkdir -p /home/$USER1/.config/hypr
mkdir -p /home/$USER2/.config/hypr
echo "exec Hyprland" > /home/$USER1/.xinitrc
echo "exec Hyprland" > /home/$USER2/.xinitrc
chown $USER1:$USER1 /home/$USER1/.config/hypr /home/$USER1/.xinitrc
chown $USER2:$USER2 /home/$USER2/.config/hypr /home/$USER2/.xinitrc

EOF

# Fin de l'installation
echo "Installation terminée ! Vous pouvez redémarrer."
