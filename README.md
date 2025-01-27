### Arch Linux Installation Script (not for normies)

### This script automates the installation of Arch Linux in two stages: pre-installation (system setup) and post-installation (configuration). It is designed for reproducibility and minimalism.

Fully automated process with no user choices.

Requirements:
A fresh Arch Linux live iso.
Internet connection for downloading packages.
if you have wireless AP
iwctl station wlan0 connect "your-ssid-here"

Usage:
Boot into the Arch Linux live environment and connect to the internet.

Run the Pre-Installation Script:

full-install/preinstall/scriptsysd.sh
This script handles partitioning, mounting, and installs the base system.

Run the Post-Installation Script:

full-install/postinstall/script.sh
This script copies my dotfiles and sets up the firewall.


