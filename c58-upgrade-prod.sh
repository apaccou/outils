#!/bin/bash

# Script d'upgrade de Concrete 5.8 sur Simple Hosting avec la version de concrete5 en download depuis le site Concrete5 (à mettre à jour manuellement dans le script en cas de MAJ)
# Version:   0.0.3
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
CONCRETE5_VERSION="concrete5-8.4.0"
CONCRETE5_DOWNLOAD_URL="https://www.concrete5.org/download_file/-/view/104344/"

# STARTS HERE
# ----------

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

# Test la taille de la sauvegarde sql > 500 Ko
echo -n "  >> Vérifie que la taille de la sauvegarde SQL > 500 Ko ... "
if [ `ls -l $DB_DATABASE-save$DATE.sql | cut -d " " -f5` -gt 500 ]
then
  echo "OK"
else
  echo " ERREUR : il semble y avoir une erreur avec la sauvegarde de la base de donnée."
 exit
fi

# Sauvegardes des fichiers avant MAJ
echo -n "  >> Sauvegardes du dossier /concrete avant MAJ ... "
echo "Mode silencieux : pas de prompt avant la fin du processus."
zip -qr $DB_DATABASE-save$DATE.zip concrete

# Test la taille de la sauvegarde zip > 1 Mo
echo -n "  >> Vérifie que la taille de la sauvegarde ZIP > 1 Mo ... "
if [ `ls -l $DB_DATABASE-save$DATE.zip | cut -d " " -f5` -gt 1000 ]
then
  echo "OK"
else
  echo " ERREUR : il semble y avoir une erreur avec la sauvegarde du dossier /concrete."
 exit
fi

# Téléchargement de Concrete5 dans le dossier /updates
cd updates/
echo "  >> Téléchargement de la version $CONCRETE5_VERSION de Concrete5 dans le dossier /updates : "
wget ${CONCRETE5_DOWNLOAD_URL} -O concrete5.zip

# Extraction des fichiers du dossier /updates/$CONCRETE5_VERSION
echo -n "  >> Extraction des fichiers du dossier /updates/$CONCRETE5_VERSION ... "
echo "Mode silencieux : pas de prompt avant la fin du processus."
unzip -q concrete5.zip
mv ${CONCRETE5_VERSION}/concrete/ .
echo "  >> Suppression des fichiers et dossier /updates/concrete5.zip et /updates/$CONCRETE5_VERSION ... "
rm -f concrete5.zip
rm -rf ${CONCRETE5_VERSION}/

# Mise à jour de Concrete5
echo "  >> Mise à jour de Concrete5 ... "
cd ..
mv concrete/ concrete.old/
mv updates/concrete/ .
concrete/bin/concrete5 c5:update
echo "Mise à jour effectuée. Veuillez vérifier que le site fonctionne correctement."

# Confirmation / Annulation de la mise à jour
echo "  >> Confirmation / Annulation de la mise à jour ... "
echo "Voulez-vous confirmer la mise à jour [oui/non] ? Si non, la mise à jour sera annulée."
while :
do
  read INPUT_STRING
  case $INPUT_STRING in
	non)
		echo "Non"
    echo "  >> Annulation en cours ... "
    rm -rf concrete/
    mv concrete.old/ concrete/
    echo "Ancien dossier concrete/ remis en place"
    mysql -l -h $DB_SERVER -u $DB_USERNAME -p"$DB_PASSWORD" $DB_DATABASE < $DB_DATABASE-save$DATE.sql
    echo "Sauvegarde de la base de donnée importée"
    echo "Annulation terminée, les sauvegardes au format zip et sql sont dans le dossier htdocs du site en cas de besoin."
    break
		;;
	oui)
		echo "Oui"
    rm -rf concrete.old/
		break
		;;
	*)
		echo "Veuillez taper [oui] ou [non]"
		;;
  esac
done

echo "That's all folks!"
