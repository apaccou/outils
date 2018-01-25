#!/bin/bash

# Script d'upgrade de Concrete 5.8 sur Simple Hosting avec la dernière version de concrete5 en download depuis le site Concrete5
# Version:   0.0.1
# Author:    Alexandre PACCOU / COTEO

# Documentation commandes CLI Concrete5
# http://documentation.concrete5.org/developers/appendix/cli-commands

# Pré-requis
# ----------

# Utilisation
# ----------
# A lancer directement depuis le répertoire htdocs du site à installer soit /srv/data/web/vhosts/ndd_du_site/htdocs/ sur Simple Hosting
# Commande à lancer : ../../../../home/c58-upgrade-prod.sh ou ~/c58-upgrade-prod.sh

# Paramètres
# ----------
CONCRETE5_VERSION="concrete5-8.3.2"
CONCRETE5_DOWNLOAD_URL="https://www.concrete5.org/download_file/-/view/100595/"

# STARTS HERE
# ----------

# Récupére les accès à la BDD
echo "  >> Lecture des accès BDD ... "
DB_SERVER=$( grep server application/config/database.php | cut -d"'" -f4 )
DB_DATABASE=$( grep database application/config/database.php | cut -d"'" -f4 )
DB_USERNAME=$( grep username application/config/database.php | cut -d"'" -f4 )
DB_PASSWORD=$( grep password application/config/database.php | cut -d"'" -f4 )


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

exit

# Sauvegarde de la BDD avant MAJ
echo -n "  >> Sauvegarde de la BDD ... "
DATE=$(date +%Y%m%d)
mysqldump -l -h $DB_SERVER -u $DB_USERNAME -p"$DB_PASSWORD" $DB_DATABASE > $DB_DATABASE-save$DATE.sql
# 0 for Success
# 1 for Warning
# 2 for Not Found
if [ "$?" -eq 0 ]
then
  wait
  echo "OK : $DB_DATABASE-save$DATE.sql"
else
  echo " ERREUR : mysqldump ne s'est pas executé correctement."
  exit
fi

# Test la taille de la sauvegarde sql > 1 Mo
echo -n "  >> Vérifie que la taille de la sauvegarde > 1 Mo ... "
if [ `du $DB_DATABASE-save$DATE.sql | cut -f1` -gt 1000 ]
then
  echo "OK"
else
  echo " ERREUR : il semble y avoir une erreur avec la sauvegarde."
#  exit
fi

# Sauvegardes des fichiers avant MAJ
zip -r $DB_DATABASE-save$DATE.zip .
