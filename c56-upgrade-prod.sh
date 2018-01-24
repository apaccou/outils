#!/bin/bash

# Script d'ugrade semi-automatique de concrete5 (il faut renseigner manuellement le site à MAJ)
# Version:   1.00
# Author:    Alexandre PACCOU / COTEO
# A lancer depuis /var/www/concrete5/sites

# liste des concrete5 clients à ignorer pour les MAJ (modules spécifiques, ...)
IGNORE_CLIENTS=('cashmetal' 'sportica')
# liste des versions de MAJ concrete5 ==> les MAJ seront effectuées en cascade dans cet ordre
C5_VERSIONS=('5.4.2.2	' '5.5.1' '5.5.2.1' '5.6.0.1' '5.6.0.2' '5.6.1.2' '5.6.2.1' '5.6.3' '5.6.3.1' '5.6.3.2' '5.6.3.3' '5.6.3.4' '5.6.3.5')

echo -n "  >> Site à upgrader ..."
if [ -z $1 ]
then
  echo " ERREUR : veuillez indiquer en paramétre le dossier du site à MAJ"
  exit
else
  echo " $1"
fi

# Lit le site à upgrader et vérifie que le dossier existe
echo -n "  >> Vérifie que le dossier $1 existe ..."
if [ -e $1 ] && [ -d $1 ]
then
  echo " OK"
else
  echo " ERREUR : le répertoire $1 n'existe pas."
  exit
fi

# Vérifie que le site ne fait pas partie des sites à ignorer dans le tableau IGNORE_CLIENTS
###si besoin, autre test de valeur en tableau : http://www.fvue.nl/wiki/Bash:_Check_if_array_element_exists
echo -n "  >> Vérifie que le site $1 ne fait pas partie de ceux à ignorer ..."
if [[ "${IGNORE_CLIENTS[*]}" =~ "$1" ]]
then
    echo " ERREUR : $1 fait partie des sites à ignorer."
    exit
else
  echo " OK"
fi

# Vérifie que le site n'a pas fait l'objet d'un upgrade via le dashboard qui peut poser pb : DIRNAME_APP_UPDATED
echo -n "  >> Vérifie que DIRNAME_APP_UPDATED n'existe pas dans le fichier de config ..."
VALUE=$( grep -c "DIRNAME_APP_UPDATED" "./$1/config/site.php" )
if [ $VALUE -ge 1 ]
then
  echo " ERREUR : $1 contient la directive DIRNAME_APP_UPDATED."
  exit
else
  echo " OK"
fi

# Vérifie et affiche la version en cours
echo -n "  >> Version concrete5 actuelle ... "
VERSION_AVANT_MAJ=`ls -l "./$1/concrete" | cut -d' ' -f10 | sed 's_../../cores/__g' | sed 's_/var/www/concrete5/cores/__g' | sed 's_/__g'`
if [  -z $VERSION_AVANT_MAJ ]
then
  echo " ERREUR : version non lisible."
  exit
else
  echo $VERSION_AVANT_MAJ
fi

# Récupére les accès à la BDD
echo "  >> Lecture des accès BDD ... "
DB_SERVER=$( grep "define('DB_SERVER" "./$1/config/site.php" | sed "s#define('DB_SERVER', '##g;s#');##g" )
DB_USERNAME=$( grep "define('DB_USERNAME" "./$1/config/site.php" | sed "s#define('DB_USERNAME', '##g;s#');##g" )
DB_PASSWORD=$( grep "define('DB_PASSWORD" "./$1/config/site.php" | sed "s#define('DB_PASSWORD', '##g;s#');##g" )
DB_DATABASE=$( grep "define('DB_DATABASE" "./$1/config/site.php" | sed "s#define('DB_DATABASE', '##g;s#');##g" )

if [ -z $DB_SERVER ] || [ -z $DB_USERNAME ] || [ -z $DB_PASSWORD ] || [ -z $DB_DATABASE ]
then
  echo " ERREUR : problème à la lecture des accès BDD."
  exit
else
  echo -n "  >> DB_SERVER ... "
  echo $DB_SERVER
  echo -n "  >> DB_USERNAME ... "
  echo $DB_USERNAME
  echo -n "  >> DB_PASSWORD ... "
  echo $DB_PASSWORD
  echo -n "  >> DB_DATABASE ... "
  echo $DB_DATABASE
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
# ==> à priori pas besoin, pas de modification de fichiers

#Détermine l'URL de base
#BASE_URL=$( grep "BASE_URL" "./$1/config/site.php" | sed "s#define('BASE_URL', '##g;s#');##g" )
while IFS= read -r j
do
  BASE_URL=$( echo "$j" | sed "s#define('BASE_URL', '##g;s#');##g" )
  if [ "${BASE_URL::4}" == 'http' ]; then break; fi
done < <(grep "BASE_URL" "./$1/config/site.php")

#Vérifie que le site est accessible avant MAJ
echo -n "  >> Vérifie que le site $BASE_URL est accessible avant MAJ ... "
if [ `curl -s -o /dev/null -w "%{http_code}" $BASE_URL` == 200 ] || [ `curl -s -o /dev/null -w "%{http_code}" $BASE_URL` == 302 ]
then
  echo "OK"
else
  echo " ERREUR : le site n'est pas accessible."
  exit
fi

# déclaration de la fonction de comparaison de version
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Change le lien symbolique du dossier concrete et lance l'upgrade
for VERSION in ${C5_VERSIONS[*]}
do
  vercomp $VERSION $VERSION_AVANT_MAJ
  case $? in
      0) OP='='
        echo "  >> La version $VERSION ... est celle couramment installée."
        ;;
      1) OP='>'
        echo "  >> Lancement de l'upgrade en version $VERSION ... "
        cd $1
        unlink concrete
        ln -s "../../cores/$VERSION/" concrete
        wget --spider $BASE_URL/tools/required/upgrade?force=1
        wait
        echo " Upgrade OK version $VERSION installée."
        echo -n "  >> Suppression du cache ... "
        rm -rf ./files/tmp/*
        rm -rf ./files/cache/*
        echo " OK"
        cd ..
        ;;
      2) OP='<'
        echo "  >> La version $VERSION ... est plus ancienne que celle installée."
        ;;
  esac
  #echo $VERSION $OP $VERSION_AVANT_MAJ
done

#Vérifie que le site est accessible après MAJ
echo -n "  >> Vérifie que le site $BASE_URL est accessible après la MAJ ... "
if [ `curl -s -o /dev/null -w "%{http_code}" $BASE_URL` == 200 ] || [ `curl -s -o /dev/null -w "%{http_code}" $BASE_URL` == 302 ]
then
  echo "OK"
else
  echo " ERREUR : le site n'est pas accessible."
  exit
fi
