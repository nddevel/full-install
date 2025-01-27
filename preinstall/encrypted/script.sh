# ENCRYPTED VERSION

# Partition the disk
parted -s /dev/vda mklabel gpt &&
parted -s /dev/vda mkpart primary fat32 1MiB 501MiB &&
parted -s /dev/vda set 1 esp on &&
parted -s /dev/vda mkpart primary ext4 501MiB 100% &&

# Encrypt the root partition (5GiB - 100% area)
cryptsetup luksFormat /dev/vda2 &&

# Open the encrypted partition and map it to a device name (e.g., cryptroot)
cryptsetup luksOpen /dev/vda2 cryptroot &&

# Format the encrypted root partition with ext4
mkfs.ext4 /dev/mapper/cryptroot &&

# Format the EFI partition (FAT32)
mkfs.fat -F 32 /dev/vda1 &&

# Mount the partitions
mount /dev/mapper/cryptroot /mnt &&
mount --mkdir /dev/vda1 /mnt/boot/ &&

# Install essential packages (add cryptsetup for encryption)
pacman -Syy archlinux-keyring figlet --noconfirm &&

# Install base system and additional packages
# Base System: base base-devel linux linux-firmware efibootmgr, Networking: networkmanager net-tools ufw, Firmware: sof-firmware, Audio: pipewire pipewire-pulse pipewire-jack pipewire-alsa, GNOME Desktop Environment: gdm gnome-session power-profiles-daemon gnome-disk-utility gnome-control-center gnome-console gnome-tweaks gnome-bluetooth nautilus loupe gnome-text-editor file-roller, Bluetooth: bluez bluez-obex, Development & Utilities: neovim fuse wipe tree git unzip, Web & Flatpak: chromium flatpak torbrowser-launcher, Multimedia: gnome-boxes obs-studio mpv qbittorrent handbrake, System Tools: htop decoder android-tools, Fonts & Documentation: gnu-free-fonts man-db tealdeer yt-dlp nmap, Themes: papirus-icon-theme ttf-firacode-nerd adw-gtk-theme &&
pacstrap /mnt base base-devel linux linux-firmware efibootmgr networkmanager net-tools ufw sof-firmware pipewire pipewire-pulse pipewire-jack pipewire-alsa gdm gnome-session power-profiles-daemon gnome-disk-utility gnome-control-center gnome-console gnome-tweaks gnome-bluetooth nautilus loupe gnome-text-editor file-roller bluez bluez-obex neovim fuse wipe tree git unzip chromium flatpak torbrowser-launcher gnome-boxes obs-studio mpv qbittorrent handbrake htop decoder android-tools gnu-free-fonts man-db tealdeer yt-dlp nmap papirus-icon-theme ttf-firacode-nerd adw-gtk-theme &&

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab &&

# Timezone and localization
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Tbilisi /etc/localtime &&
arch-chroot /mnt hwclock --systohc &&
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /mnt/etc/locale.gen &&
arch-chroot /mnt locale-gen &&
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf &&

# User setup & passwords
echo pchost > /mnt/etc/hostname &&
arch-chroot /mnt passwd &&
arch-chroot /mnt useradd -mG wheel pcuser &&
arch-chroot /mnt passwd pcuser &&
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /mnt/etc/sudoers &&

# Bootloader setup
arch-chroot /mnt bootctl install &&

# Write the bootloader entry using the dynamically set ROOT_UUID
echo -e "title Arch Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions cryptdevice=UUID=$(blkid -s UUID -o value /dev/vda2):cryptroot root=UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot) rw" > /mnt/boot/loader/entries/arch.conf &&

# Configure mkinitcpio encrypt hook
sed -i 's/\(.*block\)/\1 encrypt/' /mnt/etc/mkinitcpio.conf &&
arch-chroot /mnt mkinitcpio -P &&

# Enable services
arch-chroot /mnt systemctl enable NetworkManager &&
arch-chroot /mnt systemctl enable bluetooth &&
arch-chroot /mnt systemctl enable gdm &&
arch-chroot /mnt systemctl enable ufw &&

# Finish installation
mv full-install/ /mnt/home/pcuser/ &&
chown -R 1000:1000 /mnt/home/pcuser/full-install &&
figlet -c "installation finished reboot"