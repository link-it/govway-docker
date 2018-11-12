#!/bin/bash

function printHelp() {
echo "Usage $(basename $0) [ -s | -h | -v <versione> ]"
echo 
echo "Options
-s : Esegue build a partire dai sorgenti presenti nel repository GitHub
-v : Imposta la versione di govway da utilizzare per il build al posto di quella di default (3.0.1.rc1)
-h : Mostra questa pagina di aiuto
"
}

DOCKERBIN="$(which docker)"
if [ -z "${DOCKERBIN}" ]
then
   echo "Impossibile trovare il comando \"docker\""
   exit 2 
fi
DOCKERCOMPOSEBIN="$(which docker-compose)"
if [ -z "${DOCKERCOMPOSEBIN}" ]
then
   echo "Impossibile trovare il comando \"docker-compose\""
   exit 2
fi


DA_SORGENTI=
TAG=
VER=
while getopts "shv:" opt; do
  case $opt in
    s) DA_SORGENTI=TRUE ;;
    t) TAG="$OPTARG" ;;
    v) VER="$OPTARG" ;;
    h) printHelp
       exit 0
       ;;
    \?)
      echo "Opzione non valida: -$opt"
      exit 1
      ;;
  esac
done

if [ -d ./target ]
then
   rm -rf ./target
   mkdir ./target
fi

cp -rp ./commons/resources_compose ./commons/catalina_wrapper.sh ./target
if [ -z "$DA_SORGENTI" ]
then
   cp -rp compose_bin/* ./target/
else
   cp -rp compose_src/* ./target/
fi

cd target 
if [ -n "$VER" ]
then
   sed -e "s#3.0.1.rc1#$VER#" -e "s#301rc1#${VER//.}#" docker-compose.yml > .docker-compose.yml.tmp
   /bin/mv -f .docker-compose.yml.tmp docker-compose.yml
fi
"${DOCKERCOMPOSEBIN}" up
