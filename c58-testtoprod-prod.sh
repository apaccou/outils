#!/bin/bash

# Script de copie de Concrete 5.8 sur Simple Hosting du site de test vers site de prod
# Version:   0.0.1
# Author:    Alexandre PACCOU / COTEO

# Pré-requis
# ----------

# Utilisation
# ----------
# A lancer directement depuis le répertoire htdocs du vhost de test soit /srv/data/web/vhosts/ndd_du_site_de_test/htdocs/ sur Simple Hosting
# Commande à lancer : ../../../../home/c58-testtoprod-prod.sh ou ~/c58-testtoprod-prod.sh

# Paramètres
# ----------
DB_SERVER='localhost'
MYSQL_USERNAME=""
MYSQL_PASSWORD=""

# STARTS HERE
# ----------

DIRECTORY_TEST=$PWD

# Demande le nom du vhost de prod
echo "  >> Entrez le nom du vhost de PROD... ex : www.ndd_du_site.ext"
read VHOST_PROD

DIRECTORY_PROD="../../$VHOST_PROD"

if [ ! -d "$DIRECTORY_PROD" ]; then
  # Control will enter here if $DIRECTORY exists.
  echo "Directory '$DIRECTORY_PROD' does not exist !"
  exit
fi

# Récupére les accès à la BDD de TEST
echo "  >> Lecture des accès BDD TEST ... "
DB_SERVER_TEST=$(concrete/bin/concrete5 c5:config get database.connections.concrete.server)
DB_DATABASE_TEST=$(concrete/bin/concrete5 c5:config get database.connections.concrete.database)
DB_USERNAME_TEST=$(concrete/bin/concrete5 c5:config get database.connections.concrete.username)
DB_PASSWORD_TEST=$(concrete/bin/concrete5 c5:config get database.connections.concrete.password)

if [ -z $DB_SERVER_TEST ] || [ -z $DB_DATABASE_TEST ] || [ -z $DB_USERNAME_TEST ] || [ -z $DB_PASSWORD_TEST ]
then
  echo " ERREUR : problème à la lecture des accès BDD."
  exit
else
  echo -n "  >> DB_SERVER_TEST ... "
  echo $DB_SERVER_TEST
  echo -n "  >> DB_DATABASE_TEST ... "
  echo $DB_DATABASE_TEST
  echo -n "  >> DB_USERNAME_TEST ... "
  echo $DB_USERNAME_TEST
  echo -n "  >> DB_PASSWORD_TEST ... "
  echo $DB_PASSWORD_TEST
fi

# Go to PROD htdocs
echo "  >> Go to PROD htdocs ... "
cd $DIRECTORY_PROD/htdocs
echo "Now in " $PWD

# Récupére les accès à la BDD de PROD
echo "  >> Lecture des accès BDD PROD ... "
DB_SERVER_PROD=$(concrete/bin/concrete5 c5:config get database.connections.concrete.server)
DB_DATABASE_PROD=$(concrete/bin/concrete5 c5:config get database.connections.concrete.database)
DB_USERNAME_PROD=$(concrete/bin/concrete5 c5:config get database.connections.concrete.username)
DB_PASSWORD_PROD=$(concrete/bin/concrete5 c5:config get database.connections.concrete.password)

if [ -z $DB_SERVER_PROD ] || [ -z $DB_DATABASE_PROD ] || [ -z $DB_USERNAME_PROD ] || [ -z $DB_PASSWORD_PROD ]
then
  echo " ERREUR : problème à la lecture des accès BDD."
  exit
else
  echo -n "  >> DB_SERVER_PROD ... "
  echo $DB_SERVER_PROD
  echo -n "  >> DB_DATABASE_PROD ... "
  echo $DB_DATABASE_PROD
  echo -n "  >> DB_USERNAME_PROD ... "
  echo $DB_USERNAME_PROD
  echo -n "  >> DB_PASSWORD_PROD ... "
  echo $DB_PASSWORD_PROD
fi

# Set maintenance mode for production site
echo "  >> Set maintenance mode for production site ... "
concrete/bin/concrete5 c5:config set -g concrete.maintenance_mode true

# Rename prod database to database_save_YYYYMMDD_HHMM
# Can't RENAME DATABASE with MySQL
#
## Dump prod database to database_save_YYYYMMDD_HHMM.sql
echo "  >> Dump prod database to database_save_YYYYMMDD_HHMM.sql... "
mysqldump -l -h $DB_SERVER_PROD -u $DB_USERNAME_PROD -p"$DB_PASSWORD_PROD" $DB_DATABASE_PROD > ${DB_DATABASE_PROD}_save_${DATE_YMD_HM}.sql
# 0 for Success
# 1 for Warning
# 2 for Not Found
if [ "$?" -eq 0 ]
then
  wait
  echo "OK : ${DB_DATABASE_PROD}_save_${DATE_YMD_HM}.sql"
else
  echo " ERREUR : mysqldump ne s'est pas executé correctement."
  exit
fi

## Test la taille de la sauvegarde sql > 500 Ko
echo -n "  >> Vérifie que la taille de la sauvegarde SQL > 500 Ko ... "
if [ `ls -l ${DB_DATABASE_PROD}_save_${DATE_YMD_HM}.sql | cut -d " " -f5` -gt 500 ]
then
  echo "OK"
else
  echo " ERREUR : il semble y avoir une erreur avec la sauvegarde de la base de donnée."
 exit
fi

## Drop Database
echo " >> Drop Database... "
mysqladmin -u $DB_USERNAME_PROD -p"$DB_PASSWORD_PROD" drop $DB_DATABASE_PROD

# Move prod htdocs to htdocs_save_YYYYMMDD_HHMM
echo "  >> Move prod htdocs to htdocs_save_YYYYMMDD_HHMM ... "
cd ..
DATE_YMD_HM=$(date +%Y%m%d_%H%M)
mv htdocs/ htdocs_save_$DATE_YMD_HM/

# Rename test database to prod name
# Can't RENAME DATABASE with MySQL
#
## Dump test database to database_test.sql
echo "  >> Dump test database to database_test.sql... "
mysqldump -l -h $DB_SERVER_TEST -u $DB_USERNAME_TEST -p"$DB_PASSWORD_TEST" $DB_DATABASE_TEST > ${DB_DATABASE_TEST}_test.sql
# 0 for Success
# 1 for Warning
# 2 for Not Found
if [ "$?" -eq 0 ]
then
  wait
  echo "OK : ${DB_DATABASE_TEST}_test.sql"
else
  echo " ERREUR : mysqldump ne s'est pas executé correctement."
  exit
fi

## Test la taille de la sauvegarde sql > 500 Ko
echo -n "  >> Vérifie que la taille de la sauvegarde SQL > 500 Ko ... "
if [ `ls -l ${DB_DATABASE_TEST}_test.sql | cut -d " " -f5` -gt 500 ]
then
  echo "OK"
else
  echo " ERREUR : il semble y avoir une erreur avec la sauvegarde de la base de donnée."
 exit
fi

## Create prod database
echo " >> Create prod database... "
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_DATABASE_PROD DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -u $MYSQL_USERNAME --password=$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_DATABASE_PROD . * TO '$DB_USERNAME_PROD'@'localhost';"

## Import test data to prod database
echo " >> Import test data to prod database... "
mysql -h $DB_SERVER_PROD -u $DB_USERNAME_PROD -p"$DB_PASSWORD_PROD" $DB_DATABASE_PROD < ${DB_DATABASE_TEST}_test.sql

## Drop Database
# echo " >> Drop Database... "
# mysqladmin -u $DB_USERNAME_TEST -p"$DB_PASSWORD_TEST" drop $DB_DATABASE_TEST

# Move test htdocs to prod htdocs
echo " >> Move test htdocs to prod htdocs... "
mv $DIRECTORY_TEST .

# Configuration de l'instance de prod
echo -n "Configuration de l'instance de prod"
cd htdocs/

## Clear cache
echo -n "Clear cache : "
concrete/bin/concrete5 c5:clear-cache

## Show errors true (true/false)
echo -n "Show errors : "
concrete/bin/concrete5 c5:config set -g concrete.debug.display_errors false
echo "false"

## Show detailed errors (message/debug)
echo -n "Show detailed errors : "
concrete/bin/concrete5 c5:config set -g concrete.debug.detail message
echo "message"

## Modify database to prod
echo -n "Modify database to prod : "
concrete/bin/concrete5 c5:config set database.connections.concrete.database $DB_DATABASE_PROD
echo $DB_DATABASE_PROD

## Modify canonical url
echo -n "Modify canonical url : "
concrete/bin/concrete5 c5:config set -g site.default.seo.canonical_url http://$VHOST_PROD
echo "http://$VHOST_PROD"

## Enable Block Cache
echo -n "Enable Block Cache : "
concrete/bin/concrete5 c5:config set -g concrete.cache.blocks true
echo "true"

## Enable Theme CSS Cache
echo -n "Enable Theme CSS Cache : "
concrete/bin/concrete5 c5:config set -g concrete.cache.theme_css true
echo "true"

## Enable Compress LESS Output
echo -n "Enable Compress LESS Output : "
concrete/bin/concrete5 c5:config set -g concrete.theme.compress_preprocessor_output true
concrete/bin/concrete5 c5:config set -g concrete.theme.generate_less_sourcemap false
echo "enable"

## Enable CSS and JavaScript Cache
echo -n "CSS and JavaScript Cache : "
concrete/bin/concrete5 c5:config set -g concrete.cache.assets true
echo "true"

## Enable Overrides Cache
echo -n "Enable Overrides Cache : "
concrete/bin/concrete5 c5:config set -g concrete.cache.overrides true
echo "true"

## Enable Full Page Caching
echo -n "Enable Full Page Caching : "
concrete/bin/concrete5 c5:config set -g concrete.cache.pages blocks
echo "enable"

## Clear cache
echo -n "Clear cache : "
concrete/bin/concrete5 c5:clear-cache
