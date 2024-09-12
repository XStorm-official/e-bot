#!/bin/bash

read -p "Entrez la taille du swap en gigaoctets (ex: 1 ou 2) : " VALEUR

if ! [[ "$VALEUR" =~ ^[0-9]+$ ]]; then
  echo "Erreur : Veuillez entrer un nombre entier positif."
  exit 1
fi

sudo fallocate -l ${VALEUR}G /swapfile
ls -lh /swapfile
sudo chmod 600 /swapfile
ls -lh /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo swapon --show
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

echo "Le swap de ${VALEUR}G a été créé et activé avec succès."
