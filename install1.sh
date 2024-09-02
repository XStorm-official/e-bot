#!/bin/bash

# Installer Docker
curl -sSL https://get.docker.com/ | CHANNEL=stable bash

# Activer et démarrer Docker
sudo systemctl enable --now docker

# Supprimer le fichier /etc/default/grub
sudo rm -f /etc/default/grub

# Télécharger le fichier grub dans le répertoire /etc/default/
sudo wget -O /etc/default/grub https://raw.githubusercontent.com/XStorm-official/e-bot/main/grub

# Redémarrer le système
sudo reboot
