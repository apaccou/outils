#!/bin/bash

# Script d'installation de Concrete 5.8 sur Simple Hosting avec la dernière version de concrete5 en download depuis le site Concrete5
# Version:   0.0.3
# Author:    Alexandre PACCOU / COTEO

# Documentation commandes CLI Concrete5
# http://documentation.concrete5.org/developers/appendix/cli-commands

# Pré-requis
# ----------

# Utilisation
# ----------
# A lancer directement depuis le répertoire htdocs du site à installer soit /srv/data/web/vhosts/ndd_du_site/htdocs/ sur Simple Hosting
# Commande à lancer : ../../../../home/c58-htaccess-prod.sh

# Paramètres
# ----------
CONCRETE5_VERSION="concrete5-8.3.1"
CONCRETE5_DOWNLOAD_URL="https://www.concrete5.org/download_file/-/view/99963/"

DB_SERVER='localhost'
MYSQL_USERNAME=""
MYSQL_PASSWORD=""

ADMIN_EMAIL=''
ADMIN_PASS=''

SAMPLE_DATA="elemental_blank" # elemental_full / elemental_blank
CONCRETE5_LANGUAGE="fr_FR"
CONCRETE5_LOCALE="fr_FR"


# STARTS HERE
# ----------

# Vérifie si un fichier index.php existe déjà dans le répertoire pour éviter de supprimer un concrete5 existant
if [ -f "index.php" ];then
    echo "Installation annulée : un fichier index.php existe déjà dans le répertoire !";
    exit
fi

# Demande le nom du site à créer (base de donnée)
echo "Entrez le nom du site à créer (base de donnée + utilisateur BDD) sans espace, sans accents, sans caractères spéciaux, tirets acceptés (ex : coteoweb) : "
# Propose comme valeur par défaut le nom du virtual host, taper sur la touche Entrée pour valider ou indiquer un autre nom
PARENTDIR=$(dirname `pwd`)
SITE_NAME=${PARENTDIR##*/}
SITE_NAME=${SITE_NAME%.elnath.coteo.net}
echo "Utiliser comme nom : $SITE_NAME ? (touche Entrée pour valider ou indiquer un autre nom)"
read INPUT
SITE_NAME="${INPUT:-$SITE_NAME}"
# Teste si la valeur n'est pas vide
if [ -z "$SITE_NAME" ]
then
      echo "Le nom du site ne peut être vide !"
      exit
fi
echo $SITE_NAME


# Demande l'url finale de production du site pour la renseigner dans le fichier robots.txt
echo -n "Entrez l'url finale de production du site pour la renseigner dans le fichier robots.txt avec http:// ou https://, sans slash à la fin, ex : http://www.coteo.com : "
read SITE_URL
echo $SITE_URL

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
echo -n "Téléchargement de la dernière version de Concrete5 : "
wget ${CONCRETE5_DOWNLOAD_URL} -O concrete5.zip
unzip concrete5.zip
mv ${CONCRETE5_VERSION}/* .
rm -f concrete5.zip
rm -rf ${CONCRETE5_VERSION}/

# Paramétrage des droits sur le serveur


# Installation et configuration du site en ligne de commande
echo "Installation de Concrete5 : "
concrete/bin/concrete5 c5:install --db-server=${DB_SERVER} --db-username=${DB_USERNAME} --db-password=${DB_PASSWORD} --db-database=${DB_NAME} --site="${SITE_NAME}" --starting-point=${SAMPLE_DATA} --admin-email=${ADMIN_EMAIL} --admin-password="${ADMIN_PASS}" --language="${CONCRETE5_LANGUAGE}" --site-locale="${CONCRETE5_LOCALE}"

# Installe les traductions françaises de l'admin
echo "Installation traductions françaises de l'admin : "
concrete/bin/concrete5 c5:install-language --add fr_FR

# Disabling news overlay
echo "Disabling news overlay : "
concrete/bin/concrete5 c5:config set -g concrete.external.news_overlay false

# Disabling intro guide
echo "Disabling intro guide : "
concrete/bin/concrete5 c5:config set -g concrete.misc.help_overlay false

# Show errors off (true/false)
echo "Show errors : "
concrete/bin/concrete5 c5:config set -g concrete.debug.display_errors false

# Show detailed errors (message/debug)
echo "Show detailed errors : "
concrete/bin/concrete5 c5:config set -g concrete.debug.detail message

# Active l'url rewriting
echo "Activate URL Rewriting : "
concrete/bin/concrete5 c5:config set -g concrete.seo.url_rewriting true

# Copie le fichier c58-htaccess-prod.txt (.htaccess optimisé) de /srv/data/home vers le dossier courant en le renommant .htaccess
echo "Copie le fichier .htaccess optimisé de vers le dossier courant : "
SCRIPT_PATH=${0%/*}
cp $SCRIPT_PATH/c58-htaccess-prod.txt ./.htaccess

# Copie le fichier favicon.png de /srv/data/home vers le dossier courant en le renommant favicon.ico
echo "Copie le fichier .htaccess optimisé de vers le dossier courant : "
SCRIPT_PATH=${0%/*}
cp $SCRIPT_PATH/favicon.png ./favicon.ico

# Génération du sitemap.xml
echo "Génération du sitemap.xml : "
concrete/bin/concrete5 c5:job generate_sitemap
# Ajout d'une référence au sitemap dans le fichier robots.txt
echo "Sitemap: $SITE_URL/sitemap.xml" >> robots.txt

# Ajout du Package informations
cd packages/
git clone git@github.com:coteo/coteo_package_informations.git
cd ..
echo -n "Installation du Package coteo_package_informations : "
concrete/bin/concrete5 c5:package-install coteo_package_informations

# Ajout du Package themesimpleo
cd packages/
git clone git@github.com:coteo/coteo_package_themesimpleo.git
cd ..
echo -n "Installation du Package coteo_package_themesimpleo : "
concrete/bin/concrete5 c5:package-install coteo_package_themesimpleo

# Ajout du Package imagesdefilantes
cd packages/
git clone git@github.com:coteo/coteo_package_imagesdefilantes.git
cd ..
echo -n "Installation du Package coteo_package_imagesdefilantes : "
concrete/bin/concrete5 c5:package-install coteo_package_imagesdefilantes

# Ajout du Package image_content
cd packages/
git clone git@github.com:coteo/coteo_package_image_content.git
cd ..
echo -n "Installation du Package coteo_package_image_content : "
concrete/bin/concrete5 c5:package-install coteo_package_image_content

# Ajout du Package fluxrss
cd packages/
git clone git@github.com:coteo/coteo_package_fluxrss.git
cd ..
echo -n "Installation du Package coteo_package_fluxrss : "
concrete/bin/concrete5 c5:package-install coteo_package_fluxrss

# Ajout du Package simple_gallery
cd packages/
git clone git@github.com:coteo/coteo_package_simple_gallery.git
cd ..
echo -n "Installation du Package coteo_package_simple_gallery : "
concrete/bin/concrete5 c5:package-install coteo_package_simple_gallery
