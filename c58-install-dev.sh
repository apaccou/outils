#!/bin/bash

# Script d'installation de Concrete 5.8
# Version:   0.0.2
# Author:    Alexandre PACCOU / COTEO

# Documentation commandes CLI Concrete5
# http://documentation.concrete5.org/developers/appendix/cli-commands

# Pré-requis
# apt-get install git-core
# apt-get install php5-gd
# apt-get install composer
# apt-get install npm

# Paramètres
DB_SERVER='localhost'

MYSQL_USERNAME=""
MYSQL_PASSWORD=""

SAMPLE_DATA="elemental_blank" # elemental_full / elemental_blank

ADMIN_EMAIL=""
ADMIN_PASS=""

CONCRETE5_LANGUAGE="fr_FR"
CONCRETE5_LOCALE="fr_FR"

# Demande le nom du site à créer (répertoire + base de donnée + virtualhost)
echo -n "Entrez le nom du site sans espace, sans accents, sans caractères spéciaux, tirets acceptés : "
read SITE_NAME
if [ -e "$SITE_NAME" ]; then
        echo "Erreur : un site avec le même nom existe déjà !"
        exit 0
else
        mkdir $SITE_NAME
        echo "Répertoire $SITE_NAME créé"
fi

# Génération d'un mot de passe aléatoire
echo -n "Génération d'un mot de passe aléatoire : "
DB_PASSWORD=$(date | md5sum | cut -d' ' -f1)
echo $DB_PASSWORD

# Création de la base de donnée et des accès
DB_NAME=${SITE_NAME//-/} # Élimination de tous les '-' dans le nom de la bdd
echo -n "Création de la base de donnée : "
echo $DB_NAME

DB_USERNAME=$SITE_NAME
taille=`expr length $SITE_NAME`
if [ 15 -lt $taille ]; then
  DB_USERNAME=${SITE_NAME:0:16}
fi
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD -e "CREATE USER '${DB_USERNAME}'@'$DB_SERVER' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD -e "GRANT USAGE ON * . * TO '$DB_USERNAME'@'$DB_SERVER' IDENTIFIED BY '$DB_PASSWORD' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;"
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_NAME . * TO '$DB_USERNAME'@'localhost';"

# Téléchargement et configuration de Concrete5
cd $SITE_NAME
echo -n "Téléchargement de la dernière version de Concrete5 : "
git clone https://github.com/concrete5/concrete5.git
cd concrete5/
#git checkout master
composer install

# Traduction
mkdir -p application/languages/site
cd application/languages/site
cp /home/alexandre/Downloads/translations-fr_FR.mo .
mv translations-fr_FR.mo fr_FR.mo
cd ../../..

# Paramétrage des droits sur le serveur
chown -R www-data:www-data application/files/
chown -R www-data:www-data application/config/
chown -R www-data:www-data application/languages/
chown -R www-data:www-data packages/
chown -R www-data:www-data updates

chmod -R 775 application/files/
chmod -R 775 application/config/
chmod -R 775 application/languages/
chmod -R 775 packages/
chmod -R 775 updates

# Installation et configuration de la base de donnée
echo -n "Installation de Concrete5 : "
concrete/bin/concrete5 c5:install --db-server=${DB_SERVER} --db-username=${DB_USERNAME} --db-password=${DB_PASSWORD} --db-database=${DB_NAME} --site="${SITE_NAME}" --starting-point=${SAMPLE_DATA} --admin-email=${ADMIN_EMAIL} --admin-password="${ADMIN_PASS}"  --language="${CONCRETE5_LANGUAGE}" --site-locale="${CONCRETE5_LOCALE}"

# Installation des packages
cd packages/
git clone https://github.com/coteo/coteo_package_themesimpleo.git
git clone https://github.com/coteo/coteo_package_actus.git
git clone https://github.com/coteo/coteo_package_geoloc.git
cd coteo_package_geoloc/
composer install
cd ..

cd ..
chown -R www-data:www-data application/files/
chown -R www-data:www-data application/config/

# Ajout pour le développement
cd application/config/
touch concrete.php
echo '<?php

return ['debug'=> ['display_errors' => true, 'detail' => 'debug']];
' > concrete.php

cd ../..
chmod -R 775 application/files/cache

echo "Installation terminée, let's go!"
exit 0
