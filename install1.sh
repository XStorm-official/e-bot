#!/bin/bash
curl -sSL https://get.docker.com/ | CHANNEL=stable bash
sudo systemctl enable --now docker
rm /etc/default/grub
cd /etc/default/
wget "https://raw.githubusercontent.com/XStorm-official/e-bot/main/grub"
reboot
