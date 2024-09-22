#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer-e-bot'                                              #
#                                                                                    #
# Copyright (C) 2024, Pierre-Louis Lestriez, <pierrelouis.lestriez@gmail.com>        #
#                                                                                    #
#   Unauthorized use, reproduction, or distribution of this script is prohibited.    #
#   Modifying, decrypting, or reverse engineering this script is strictly forbidden.  #
#                                                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/XStorm-official/e-bot                                           #
#                                                                                    #
######################################################################################

LOGFILE="e-bot-pterodactyl.log"
exec > >(tee -a "$LOGFILE") 2>&1

GREEN='\033[0;32m'
RED='\033[0;31m'
VIOLET='\033[0;35m'
NC='\033[0m'

function success_message {
    echo -e "${GREEN}$1 terminé avec succès.${NC}"
}

function error_message {
    echo -e "${RED}$1 a échoué.${NC}" >&2
}

function warning_message {
    echo -e "${VIOLET}$1${NC}"
}

echo "Mise à jour des dépôts..."
if apt update; then
    success_message "Mise à jour des dépôts"
else
    error_message "Mise à jour des dépôts"
    exit 1
fi

echo "Mise à niveau des paquets..."
if apt upgrade -y; then
    success_message "Mise à niveau des paquets"
else
    error_message "Mise à niveau des paquets"
    exit 1
fi

echo "Installation des paquets nécessaires..."
if sudo apt install -y software-properties-common curl apt-transport-https ca-certificates gnupg apache2 cron libapache2-mod-php8.3; then
    success_message "Paquets nécessaires installés"
else
    error_message "Échec de l'installation des paquets"
    exit 1
fi

echo "Ajout du dépôt PHP..."
if echo "deb https://packages.sury.org/php/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/php.list; then
    success_message "Dépôt PHP ajouté avec succès"
else
    error_message "Échec de l'ajout du dépôt PHP"
    exit 1
fi
if wget -qO - https://packages.sury.org/php/apt.gpg | sudo apt-key add -; then
    success_message "Clé du dépôt ajoutée avec succès"
else
    error_message "Échec de l'ajout de la clé du dépôt"
    exit 1
fi

echo "Ajout du dépôt Redis..."
if curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg &&
   echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list; then
    success_message "Ajout du dépôt Redis"
else
    error_message "Ajout du dépôt Redis"
    exit 1
fi

echo "Ajout du dépôt MariaDB..."
if curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash; then
    success_message "Ajout du dépôt MariaDB"
else
    error_message "Ajout du dépôt MariaDB"
    exit 1
fi

echo "Mise à jour des dépôts après ajout..."
if apt update; then
    success_message "Mise à jour des dépôts après ajout"
else
    error_message "Mise à jour des dépôts après ajout"
    exit 1
fi

echo "Installation des paquets nécessaires (PHP, MariaDB, Nginx, Redis, etc.)..."
if apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server; then
    success_message "Installation des paquets"
else
    error_message "Installation des paquets"
    exit 1
fi

echo "Installation de Composer..."
if curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer; then
    success_message "Installation de Composer"
else
    error_message "Installation de Composer"
fi

echo "Création du répertoire /var/www/pterodactyl..."
if mkdir -p /var/www/pterodactyl; then
    success_message "Répertoire créé"
else
    error_message "Échec de la création du répertoire"
    exit 1
fi

cd /var/www/pterodactyl || { error_message "Échec de l'entrée dans le répertoire"; exit 1; }

echo "Téléchargement du panel Pterodactyl..."
if curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz; then
    success_message "Téléchargement du panel réussi"
else
    error_message "Échec du téléchargement du panel"
    exit 1
fi

echo "Extraction du panel..."
if tar -xzvf panel.tar.gz; then
    success_message "Extraction réussie"
else
    error_message "Échec de l'extraction du panel"
    exit 1
fi

echo "Modification des permissions sur les répertoires..."
if chmod -R 755 storage/* bootstrap/cache/; then
    success_message "Permissions modifiées"
else
    error_message "Échec de la modification des permissions"
    exit 1
fi

function prompt_for_input {
    local prompt="$1"
    read -p "$prompt" response
    echo "$response"
}

DBUSERNAME=$(prompt_for_input "Entrez le nom d'utilisateur de la base de données : ")
DBPASSWORD=$(prompt_for_input "Entrez le mot de passe de la base de données : ")
DBNAME=$(prompt_for_input "Entrez le nom de la base de données : ")

echo "Création de l'utilisateur et de la base de données dans MySQL..."
mysql -u root -p <<EOF
CREATE USER '${DBUSERNAME}'@'127.0.0.1' IDENTIFIED BY '${DBPASSWORD}';
CREATE DATABASE ${DBNAME};
GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSERNAME}'@'127.0.0.1' WITH GRANT OPTION;
EOF

if [ $? -eq 0 ]; then
    success_message "Utilisateur et base de données créés avec succès"
else
    error_message "Échec de la création de l'utilisateur ou de la base de données"
fi

echo "Copie du fichier .env.example vers .env..."
if cp .env.example .env; then
    success_message "Fichier .env copié"
else
    error_message "Échec de la copie du fichier .env"
    exit 1
fi

echo "Installation des dépendances avec Composer..."
if COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader; then
    success_message "Installation des dépendances réussie"
else
    error_message "Échec de l'installation des dépendances"
    exit 1
fi

echo "Génération de la clé d'application Laravel..."
if php artisan key:generate --force; then
    success_message "Clé d'application générée"
else
    error_message "Échec de la génération de la clé d'application"
    exit 1
fi

php artisan p:environment:setup

if [ $? -eq 0 ]; then
    echo "La configuration de l'environnement s'est effectuée sans erreur."
else
    echo "Une erreur s'est produite lors de la configuration de l'environnement."
fi

php artisan p:environment:database

if [ $? -eq 0 ]; then
    echo "La configuration de la nase de donnée s'est effectuée sans erreur."
else
    echo "Une erreur s'est produite lors de la configuration de la base de donnée."
fi

read -p "Souhaitez-vous configurer les mails ? (o/n) : " configure_mails

if [[ "$configure_mails" =~ ^[oO]$ ]]; then
    php artisan p:environment:mail

    if [ $? -eq 0 ]; then
        echo "La configuration des mails s'est effectuée sans erreur."
    else
        echo "Une erreur s'est produite lors de la configuration des mails."
    fi
else
    echo "Configuration des mails ignorée."
fi

php artisan migrate --seed --force

if [ $? -eq 0 ]; then
    echo "Migration de la base de données et semis effectués sans erreur."
else
    echo "Une erreur s'est produite lors de la migration de la base de données."
fi

php artisan p:user:make

if [ $? -eq 0 ]; then
    echo "L'utilisateur a été créé avec succès."
else
    echo "Une erreur s'est produite lors de la création de l'utilisateur."
fi

chown -R www-data:www-data /var/www/pterodactyl/*

if [ $? -eq 0 ]; then
    echo "Les permissions ont été mises à jour avec succès."
else
    echo "Une erreur s'est produite lors de la mise à jour des permissions."
fi

(echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | sudo /usr/bin/crontab -

if [ $? -eq 0 ]; then
    echo "La tâche cron a été ajoutée avec succès."
else
    echo "Une erreur s'est produite lors de l'ajout de la tâche cron."
fi

cat <<EOL | sudo tee /etc/systemd/system/pteroq.service
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

if [ $? -eq 0 ]; then
    echo "Le fichier pteroq.service a été créé avec succès."
else
    echo "Une erreur s'est produite lors de la création du fichier pteroq.service."
fi

sudo systemctl enable --now redis-server

if [ $? -eq 0 ]; then
    echo "Le service redis-server a été activé et démarré avec succès."
else
    echo "Une erreur s'est produite lors de l'activation et du démarrage de redis-server."
fi

sudo systemctl enable --now pteroq.service

if [ $? -eq 0 ]; then
    echo "Le service pteroq a été activé et démarré avec succès."
else
    echo "Une erreur s'est produite lors de l'activation et du démarrage de pteroq."
fi

mkdir -p /etc/certs

if [ $? -eq 0 ]; then
    echo "Le répertoire /etc/certs a été créé avec succès."
else
    echo "Une erreur s'est produite lors de la création du répertoire /etc/certs."
    exit 1
fi

cd /etc/certs

openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" -keyout privkey.pem -out fullchain.pem

if [ $? -eq 0 ]; then
    echo "Le certificat SSL a été généré avec succès."
else
    echo "Une erreur s'est produite lors de la génération du certificat SSL."
    exit 1
fi

read -p "Veuillez entrer le nom de domaine : " DOMAINNAME

sudo a2dissite 000-default.conf

if [ $? -eq 0 ]; then
    echo "Le site par défaut a été désactivé avec succès."
else
    echo "Une erreur s'est produite lors de la désactivation du site par défaut."
    exit 1
fi

cat <<EOL | sudo tee /etc/apache2/sites-available/pterodactyl.conf
<VirtualHost *:80>
    ServerName $DOMAINNAME

    RewriteEngine On
    RewriteCond %{HTTPS} !=on
    RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L] 
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAINNAME
    DocumentRoot "/var/www/pterodactyl/public"

    AllowEncodedSlashes On

    php_value upload_max_filesize 100M
    php_value post_max_size 100M

    <Directory "/var/www/pterodactyl/public">
        Require all granted
        AllowOverride all
    </Directory>

    SSLEngine on
    SSLCertificateFile /etc/certs/fullchain.pem 
    SSLCertificateKeyFile /etc/certs/privkey.pem 
</VirtualHost>
EOL

if [ $? -eq 0 ]; then
    echo "Le fichier pterodactyl.conf a été créé avec succès."
else
    echo "Une erreur s'est produite lors de la création du fichier pterodactyl.conf."
    exit 1
fi

sudo ln -s /etc/apache2/sites-available/pterodactyl.conf /etc/apache2/sites-enabled/pterodactyl.conf

if [ $? -eq 0 ]; then
    echo "Le lien symbolique pour pterodactyl.conf a été créé avec succès."
else
    echo "Une erreur s'est produite lors de la création du lien symbolique."
    exit 1
fi

sudo a2enmod rewrite

if [ $? -eq 0 ]; then
    echo "Le module rewrite a été activé avec succès."
else
    echo "Une erreur s'est produite lors de l'activation du module rewrite."
    exit 1
fi

sudo a2enmod ssl

if [ $? -eq 0 ]; then
    echo "Le module ssl a été activé avec succès."
else
    echo "Une erreur s'est produite lors de l'activation du module ssl."
    exit 1
fi

sudo systemctl restart apache2

if [ $? -eq 0 ]; then
    echo "Apache a été redémarré avec succès."
else
    echo "Une erreur s'est produite lors du redémarrage d'Apache."
    exit 1
fi
