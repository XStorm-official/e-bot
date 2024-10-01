#!/bin/bash

# Chemin du script de vérification
SCRIPT_PATH="/usr/local/bin/check_disk_usage.sh"

# Créer le script de vérification de l'utilisation du disque
echo "Création du script de vérification de l'utilisation du disque à $SCRIPT_PATH"

cat << 'EOF' > $SCRIPT_PATH
#!/bin/bash

# Vérifie l'utilisation du disque
disk_usage=$(df / | grep / | awk '{ print $5 }' | sed 's/%//g')

# Si l'utilisation est supérieure à 90%, exécuter la commande docker system prune avec confirmation automatique
if [ "$disk_usage" -gt 90 ]; then
    echo "L'utilisation du disque est supérieure à 90% ($disk_usage%), exécution de docker system prune..."
    echo "y" | docker system prune -a --volumes
else
    echo "L'utilisation du disque est de $disk_usage%, pas besoin de nettoyer."
fi
EOF

# Rendre le script exécutable
chmod +x $SCRIPT_PATH
echo "Le script de vérification a été rendu exécutable."

# Ajouter la tâche cron pour exécuter le script toutes les minutes
echo "Ajout de la tâche cron pour exécuter le script toutes les minutes."
(crontab -l 2>/dev/null; echo "* * * * * $SCRIPT_PATH") | crontab -

echo "Configuration terminée. Le script de vérification s'exécutera toutes les minutes."
