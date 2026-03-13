#!/bin/bash

# Set the device variable
read -p "Enter the device name (e.g., /dev/vda, /dev/sda, /dev/nvme0n1): " DEV_NAME

# Check if the device is an NVMe drive
if [[ "$DEV_NAME" == /dev/nvme* ]]; then
    # For NVMe, partitions are named with a "p" suffix, e.g., /dev/nvme0n1p1
    PART1="${DEV_NAME}p1"
    PART2="${DEV_NAME}p2"
else
    # For SATA or other drives, partitions are named without a "p" suffix
    PART1="${DEV_NAME}1"
    PART2="${DEV_NAME}2"
fi

# Ask for the username, hostname, and passwords
read -p "Enter your desired hostname: " HOSTNAME
read -p "Enter your desired username: " USERNAME

# Ask whether to use encryption or not
read -p "Do you want to use encryption? (y/n): " USE_ENCRYPTION

# Partition the disk
parted -s $DEV_NAME mklabel gpt &&
parted -s $DEV_NAME mkpart primary fat32 1MiB 501MiB &&
parted -s $DEV_NAME set 1 esp on &&
parted -s $DEV_NAME mkpart primary ext4 501MiB 100%

# Format the EFI partition (FAT32)
mkfs.fat -F 32 $PART1 &&

# Encryption logic
if [[ "$USE_ENCRYPTION" == "y" ]]; then
    # Encrypt the root partition (100% area)
    cryptsetup luksFormat $PART2 &&

    # Open the encrypted partition and map it to a device name (e.g., cryptroot)
    cryptsetup luksOpen $PART2 cryptroot &&

    # Format the encrypted root partition with ext4
    mkfs.ext4 /dev/mapper/cryptroot &&

    # Mount the encrypted root partition
    mount /dev/mapper/cryptroot /mnt &&

    # Mount the EFI partition
    mount --mkdir $PART1 /mnt/boot/
else
    # If no encryption, format the root partition with ext4
    mkfs.ext4 $PART2 &&

    # Mount the unencrypted root partition
    mount $PART2 /mnt &&

    # Mount the EFI partition
    mount --mkdir $PART1 /mnt/boot/
fi

# Install essential packages
pacman -Syy archlinux-keyring figlet --noconfirm &&

# Install base system and additional packages
pacstrap /mnt base base-devel linux linux-firmware sof-firmware efibootmgr man-db fuse wipe networkmanager networkmanager-openvpn net-tools openssh ufw nmap yt-dlp pipewire pipewire-pulse pipewire-jack pipewire-alsa gdm gnome-session gnome-control-center gnome-tweaks gnome-bluetooth-3.0 gnome-disk-utility gnome-software nautilus file-roller eyedropper loupe gvfs-mtp gvfs-gphoto2 gvfs-nfs power-profiles-daemon flatpak papirus-icon-theme adw-gtk-theme gnu-free-fonts ollama prismlauncher jdk21-openjdk neovim zed git tree wget unzip android-tools gnome-boxes docker obs-studio mpv qbittorrent handbrake chromium torbrowser-launcher signal-desktop raider dialect switcheroo amberol video-trimmer curtail htop decoder tealdeer &&                                                                      # 🧰 CLI utilities & extras

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab &&

# Timezone and localization
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Tbilisi /etc/localtime &&
arch-chroot /mnt hwclock --systohc &&
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /mnt/etc/locale.gen &&
arch-chroot /mnt locale-gen &&
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf &&

# User setup & passwords
echo $HOSTNAME > /mnt/etc/hostname &&
echo "Enter your desired password: " &&
arch-chroot /mnt passwd &&
arch-chroot /mnt useradd -mG wheel -s /bin/bash $USERNAME &&
arch-chroot /mnt passwd $USERNAME &&
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /mnt/etc/sudoers &&

# Bootloader setup
arch-chroot /mnt bootctl install &&

# Write the bootloader entry using the dynamically set ROOT_UUID
if [[ "$USE_ENCRYPTION" == "y" ]]; then
    # Use cryptdevice in the bootloader entry for encryption
    echo -e "title Arch Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions cryptdevice=UUID=$(blkid -s UUID -o value $PART2):cryptroot root=UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot) rw" > /mnt/boot/loader/entries/arch.conf
else
    # Normal boot entry without encryption
    echo -e "title Arch Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions root=UUID=$(blkid -s UUID -o value $PART2) rw" > /mnt/boot/loader/entries/arch.conf
fi

# Configure mkinitcpio encrypt hook (only if encryption is used)
if [[ "$USE_ENCRYPTION" == "y" ]]; then
    sed -i 's/\(.*block\)/\1 encrypt/' /mnt/etc/mkinitcpio.conf &&
    arch-chroot /mnt mkinitcpio -P
fi

# Enable services
arch-chroot /mnt systemctl enable NetworkManager &&
arch-chroot /mnt systemctl enable bluetooth &&
arch-chroot /mnt systemctl enable gdm &&
arch-chroot /mnt systemctl enable ufw &&
arch-chroot /mnt systemctl enable docker &&
arch-chroot /mnt systemctl enable ollama &&
arch-chroot /mnt systemctl enable sshd &&

# Finish installation
cp -r ~/full-install/ /mnt/home/$USERNAME/ &&
chown -R 1000:1000 /mnt/home/$USERNAME/full-install &&
figlet -c "installation finished reboot"
