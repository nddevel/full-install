#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# Arch Preinstall (Interactive)
# =========================
# - Supports SATA (/dev/sda) and NVMe (/dev/nvme0n1) naming
# - Optional LUKS encryption
# - Adds strong error handling and validation
# - Uses systemd-boot
#
# Run as root from Arch ISO:
#   bash automated-script-test.sh
# =========================

MNT="/mnt"
TIMEZONE="Asia/Tbilisi"
LOCALE="en_US.UTF-8"

on_error() {
  local line="$1"
  local cmd="$2"
  local code="$3"
  printf '\n[ERROR] Line %s failed (exit %s): %s\n' "$line" "$code" "$cmd" >&2
  echo "[ERROR] Installation stopped."
}
trap 'on_error "${LINENO}" "${BASH_COMMAND}" "$?"' ERR

log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run this script as root."
}

check_tools() {
  local tools=(
    parted mkfs.fat mkfs.ext4 mount umount
    pacman pacstrap genfstab arch-chroot
    bootctl blkid sed cryptsetup
  )
  local missing=()
  for t in "${tools[@]}"; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  ((${#missing[@]} == 0)) || die "Missing required tools: ${missing[*]}"
}

confirm() {
  local prompt="$1"
  read -r -p "$prompt [y/N]: " ans
  [[ "${ans,,}" == "y" ]]
}

validate_block_device() {
  local dev="$1"
  [[ -b "$dev" ]] || die "Not a block device: $dev"
}

prepare_part_names() {
  local dev="$1"
  if [[ "$dev" == /dev/nvme* ]]; then
    PART1="${dev}p1"
    PART2="${dev}p2"
  else
    PART1="${dev}1"
    PART2="${dev}2"
  fi
}

cleanup_mounts_if_needed() {
  # Best effort cleanup, no hard fail
  if mountpoint -q "${MNT}/boot"; then umount -R "${MNT}/boot" || true; fi
  if mountpoint -q "${MNT}"; then umount -R "${MNT}" || true; fi
}

main() {
  require_root
  check_tools

  read -r -p "Enter device (e.g. /dev/vda, /dev/sda, /dev/nvme0n1): " DEV_NAME
  DEV_NAME="${DEV_NAME// /}"
  validate_block_device "$DEV_NAME"
  prepare_part_names "$DEV_NAME"

  read -r -p "Enter hostname: " HOSTNAME
  read -r -p "Enter username: " USERNAME
  [[ -n "$HOSTNAME" ]] || die "Hostname cannot be empty."
  [[ -n "$USERNAME" ]] || die "Username cannot be empty."

  read -r -p "Use encryption? (y/n): " USE_ENCRYPTION
  USE_ENCRYPTION="${USE_ENCRYPTION,,}"
  [[ "$USE_ENCRYPTION" == "y" || "$USE_ENCRYPTION" == "n" ]] || die "Enter y or n."

  log "Configuration:"
  log "  Device:     $DEV_NAME"
  log "  EFI part:   $PART1"
  log "  Root part:  $PART2"
  log "  Hostname:   $HOSTNAME"
  log "  Username:   $USERNAME"
  log "  Encryption: $USE_ENCRYPTION"

  confirm "This will ERASE ${DEV_NAME}. Continue?" || die "Cancelled by user."

  cleanup_mounts_if_needed

  # Partition
  parted -s "$DEV_NAME" mklabel gpt
  parted -s "$DEV_NAME" mkpart primary fat32 1MiB 501MiB
  parted -s "$DEV_NAME" set 1 esp on
  parted -s "$DEV_NAME" mkpart primary ext4 501MiB 100%

  # Format EFI
  mkfs.fat -F 32 "$PART1"

  # Root setup
  if [[ "$USE_ENCRYPTION" == "y" ]]; then
    cryptsetup luksFormat "$PART2"
    cryptsetup luksOpen "$PART2" cryptroot
    mkfs.ext4 /dev/mapper/cryptroot
    mount /dev/mapper/cryptroot "$MNT"
  else
    mkfs.ext4 "$PART2"
    mount "$PART2" "$MNT"
  fi

  mount --mkdir "$PART1" "$MNT/boot"

  # Base install
  pacman -Syy archlinux-keyring figlet --noconfirm
  pacstrap "$MNT" \
    base base-devel linux linux-firmware sof-firmware efibootmgr man-db fuse wipe \
    networkmanager networkmanager-openvpn net-tools openssh ufw nmap yt-dlp \
    pipewire pipewire-pulse pipewire-jack pipewire-alsa \
    gdm gnome-session gnome-control-center gnome-tweaks gnome-bluetooth-3.0 \
    gnome-disk-utility gnome-software nautilus file-roller eyedropper loupe \
    gvfs-mtp gvfs-gphoto2 gvfs-nfs power-profiles-daemon flatpak \
    papirus-icon-theme adw-gtk-theme gnu-free-fonts \
    ollama prismlauncher jdk21-openjdk neovim zed git tree wget unzip android-tools \
    gnome-boxes docker obs-studio mpv qbittorrent handbrake chromium \
    torbrowser-launcher signal-desktop raider dialect switcheroo amberol \
    video-trimmer curtail htop decoder tealdeer

  genfstab -U "$MNT" > "$MNT/etc/fstab"

  # Locale/time
  arch-chroot "$MNT" ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  arch-chroot "$MNT" hwclock --systohc
  sed -i "s/#${LOCALE} UTF-8/${LOCALE} UTF-8/g" "$MNT/etc/locale.gen"
  arch-chroot "$MNT" locale-gen
  echo "LANG=${LOCALE}" > "$MNT/etc/locale.conf"

  # Host/user
  echo "$HOSTNAME" > "$MNT/etc/hostname"
  echo "[INFO] Set root password:"
  arch-chroot "$MNT" passwd
  arch-chroot "$MNT" useradd -mG wheel -s /bin/bash "$USERNAME"
  echo "[INFO] Set password for $USERNAME:"
  arch-chroot "$MNT" passwd "$USERNAME"
  sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' "$MNT/etc/sudoers"

  # Bootloader
  arch-chroot "$MNT" bootctl install

  if [[ "$USE_ENCRYPTION" == "y" ]]; then
    cat > "$MNT/boot/loader/entries/arch.conf" <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=UUID=$(blkid -s UUID -o value "$PART2"):cryptroot root=UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot) rw
EOF

    sed -i 's/\(.*block\)/\1 encrypt/' "$MNT/etc/mkinitcpio.conf"
    arch-chroot "$MNT" mkinitcpio -P
  else
    cat > "$MNT/boot/loader/entries/arch.conf" <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value "$PART2") rw
EOF
  fi

  # Services
  arch-chroot "$MNT" systemctl enable NetworkManager
  arch-chroot "$MNT" systemctl enable bluetooth
  arch-chroot "$MNT" systemctl enable gdm
  arch-chroot "$MNT" systemctl enable ufw
  arch-chroot "$MNT" systemctl enable docker
  arch-chroot "$MNT" systemctl enable ollama
  arch-chroot "$MNT" systemctl enable sshd

  # Copy repo folder if present
  if [[ -d "$HOME/full-install" ]]; then
    cp -r "$HOME/full-install/" "$MNT/home/$USERNAME/"
    chown -R 1000:1000 "$MNT/home/$USERNAME/full-install"
  else
    warn "Directory not found, skipping copy: $HOME/full-install"
  fi

  figlet -c "installation finished reboot"
  log "Install complete."
}

main "$@"
