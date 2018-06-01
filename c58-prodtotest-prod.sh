#!/bin/bash

# Script de copie de Concrete 5.8 sur Simple Hosting du site de prod vers site de test
# Version:   0.0.2
# Author:    Alexandre PACCOU / COTEO

# Pré-requis
# ----------
# Créer le vhost de test

# Utilisation
# ----------
# A lancer directement depuis le répertoire htdocs du vhost de prod soit /srv/data/web/vhosts/ndd_du_site/htdocs/ sur Simple Hosting
# Penser à supprimer le fichier index.html par défaut du vhost de test
# Commande à lancer : ../../../../home/c58-prodtotest-prod.sh ou ~/c58-prodtotest-prod.sh

# Paramètres
# ----------
DB_SERVER='localhost'
MYSQL_USERNAME=""
MYSQL_PASSWORD=""

# STARTS HERE
# ----------

# Demande le nom du vhost de test
echo "  >> Entrez le nom du vhost de test... ex : ndd_de_test.nom_du_serveur.coteo.net"
read VHOST_TEST

DIRECTORY="../../$VHOST_TEST"

if [ ! -d "$DIRECTORY" ]; then
  # Control will enter here if $DIRECTORY exists.
  echo "Directory '$DIRECTORY' does not exist !"
  exit
fi

# Récupére les accès à la BDD
echo "  >> Lecture des accès BDD ... "
DB_SERVER=$(concrete/bin/concrete5 c5:config get database.connections.concrete.server)
DB_DATABASE=$(concrete/bin/concrete5 c5:config get database.connections.concrete.database)
DB_USERNAME=$(concrete/bin/concrete5 c5:config get database.connections.concrete.username)
DB_PASSWORD=$(concrete/bin/concrete5 c5:config get database.connections.concrete.password)

if [ -z $DB_SERVER ] || [ -z $DB_DATABASE ] || [ -z $DB_USERNAME ] || [ -z $DB_PASSWORD ]
then
  echo " ERREUR : problème à la lecture des accès BDD."
  exit
else
  echo -n "  >> DB_SERVER ... "
  echo $DB_SERVER
  echo -n "  >> DB_DATABASE ... "
  echo $DB_DATABASE
  echo -n "  >> DB_USERNAME ... "
  echo $DB_USERNAME
  echo -n "  >> DB_PASSWORD ... "
  echo $DB_PASSWORD
fi

# Sauvegarde de la BDD
echo -n "  >> Sauvegarde de la BDD ... "
DATEHMS=$(date +%Y%m%d-%H%M%S)
mysqldump -l -h $DB_SERVER -u $DB_USERNAME -p"$DB_PASSWORD" $DB_DATABASE > $DB_DATABASE-save$DATEHMS.sql
# 0 for Success
# 1 for Warning
# 2 for Not Found
if [ "$?" -eq 0 ]
then
  wait
  echo "OK : $DB_DATABASE-save$DATEHMS.sql"
else
  echo " ERREUR : mysqldump ne s'est pas executé correctement."
  exit
fi

# Test la taille de la sauvegarde sql > 500 Ko
echo -n "  >> Vérifie que la taille de la sauvegarde SQL > 500 Ko ... "
if [ `ls -l $DB_DATABASE-save$DATEHMS.sql | cut -d " " -f5` -gt 500 ]
then
  echo "OK"
else
  echo " ERREUR : il semble y avoir une erreur avec la sauvegarde de la base de donnée."
 exit
fi

# Création de la base de donnée de test et des accès
echo -n "Création de la base de donnée de test : "

DATE=$(date +%Y%m%d)
DB_DATABASE_TEST=${DB_DATABASE}_test_$DATE
echo -n $DB_DATABASE_TEST " ... "
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_DATABASE_TEST DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_DATABASE_TEST . * TO '$DB_USERNAME'@'localhost';"
echo 'OK'

# Import de la base de donnée de prod dans celle de test
echo -n "Import de la base de donnée de prod dans celle de test ... "
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD $DB_DATABASE_TEST < $DB_DATABASE-save$DATEHMS.sql
echo 'OK'

# Copie des fichiers de prod vers le vhost de test
echo -n "Copie des fichiers de prod vers le vhost de test"
cp -R ../htdocs $DIRECTORY

# Configuration de l'instance de test
echo -n "Configuration de l'instance de test"
cd $DIRECTORY/htdocs

# Clear cache
echo -n "Clear cache : "
concrete/bin/concrete5 c5:clear-cache

# Show errors true (true/false)
echo -n "Show errors : "
concrete/bin/concrete5 c5:config set -g concrete.debug.display_errors true
echo "true"

# Show detailed errors (message/debug)
echo -n "Show detailed errors : "
concrete/bin/concrete5 c5:config set -g concrete.debug.detail debug
echo "debug"

# Modify database to test
echo -n "Modify database to test : "
concrete/bin/concrete5 c5:config set database.connections.concrete.database $DB_DATABASE_TEST
echo $DB_DATABASE_TEST

# Modify canonical url
echo -n "Modify canonical url : "
concrete/bin/concrete5 c5:config set -g site.seo.canonical_url http://$VHOST_TEST
echo "http://$VHOST_TEST"

# Disabling Block Cache
echo -n "Disabling Block Cache : "
concrete/bin/concrete5 c5:config set -g concrete.cache.blocks false
echo "false"

# Disabling Theme CSS Cache
echo -n "Disabling Theme CSS Cache : "
concrete/bin/concrete5 c5:config set -g concrete.cache.theme_css false
echo "false"

# Disabling Compress LESS Output
echo -n "Disabling Compress LESS Output : "
concrete/bin/concrete5 c5:config set -g concrete.theme.compress_preprocessor_output false
concrete/bin/concrete5 c5:config set -g concrete.theme.generate_less_sourcemap true
echo "disabled"

# Disabling CSS and JavaScript Cache
echo -n "CSS and JavaScript Cache : "
concrete/bin/concrete5 c5:config set -g concrete.cache.assets false
echo "false"

# Disabling Overrides Cache
echo -n "Disabling Overrides Cache : "
concrete/bin/concrete5 c5:config set -g concrete.cache.overrides false
echo "false"

# Disabling Full Page Caching
echo -n "Disabling Full Page Caching : "
concrete/bin/concrete5 c5:config set -g concrete.cache.pages 0
echo "disabled"

# Clear cache
echo -n "Clear cache : "
concrete/bin/concrete5 c5:clear-cache
