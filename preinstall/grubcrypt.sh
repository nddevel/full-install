#!/bin/bash
# -------------------------------------------------------------
#                      UNFINISHED
# -------------------------------------------------------------


# Partition the disk
parted -s /dev/vda mklabel gpt &&
parted -s /dev/vda mkpart primary fat32 1MiB 501MiB &&
parted -s /dev/vda set 1 esp on &&
parted -s /dev/vda mkpart primary linux-swap 501MiB 5GiB &&
parted -s /dev/vda mkpart primary ext4 5GiB 100% &&

# Encrypt the root partition (5GiB - 100% area)
cryptsetup luksFormat /dev/vda3 &&

# Open the encrypted partition and map it to a device name (e.g., cryptroot)
cryptsetup luksOpen /dev/vda3 cryptroot &&

# Format the encrypted root partition with ext4
mkfs.ext4 /dev/mapper/cryptroot &&

# Format the EFI partition (FAT32)
mkfs.fat -F 32 /dev/vda1 &&

# Format the swap partition
mkswap /dev/vda2 &&

# Mount the partitions
mount /dev/mapper/cryptroot /mnt &&
swapon /dev/vda2 &&
mount --mkdir /dev/vda1 /mnt/boot/ &&

# Install essential packages (add cryptsetup for encryption)
pacman -Syy archlinux-keyring figlet cryptsetup --noconfirm &&

# Install base system and additional packages
pacstrap /mnt base base-devel efibootmgr linux linux-firmware networkmanager ufw neovim tree pipewire pipewire-pulse pipewire-jack pipewire-alsa obs-studio gnome-console gnome-bluetooth gnome-tweaks nautilus bluez tlp figlet celluloid android-tools gnome-boxes neovim decoder adw-gtk-theme flatpak torbrowser-launcher chromium pycharm-community-edition git unzip gnu-free-fonts &&

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab &&

# Timezone and localization
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Tbilisi /etc/localtime &&
arch-chroot /mnt hwclock --systohc &&
arch-chroot /mnt sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen &&
arch-chroot /mnt locale-gen &&
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf &&

# User setup & passwords
echo pchost > /mnt/etc/hostname &&
arch-chroot /mnt passwd &&
arch-chroot /mnt useradd -mG wheel pcuser &&
arch-chroot /mnt passwd pcuser &&
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers &&

# Bootloader setup
arch-chroot /mnt grub-install --efi-directory=/boot --bootloader-id=GRUB /dev/vda && 
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg && 

# Enable services
arch-chroot /mnt systemctl enable NetworkManager && 
arch-chroot /mnt systemctl enable bluetooth && 
arch-chroot /mnt systemctl enable gdm &&
arch-chroot /mnt systemctl enable tlp &&
arch-chroot /mnt systemctl enable ufw &&

# Finish installation
figlet installation finished reboot system
