#!/bin/bash

function printHelp() {
#echo "Usage $(basename $0) [ -s | -h | -t <tagname> | -v <versione> | -d ( hsql* | postgresql ) ]"
echo "Usage $(basename $0) [ -t <repository>:<tagname> | [ -v <versione> | -j | -l <file path> ] | -d <tipo datatbase> | -i <template path> -h ]"
echo 
echo "Options
-t : Imposta il nome del TAG ed il repository locale utilizzati per l'immagine prodotta 
     NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-v : Imposta la versione dell'installer binario di govway da utilizzare per il build (default: 3.3.5)
-d : Prepara l'immagine per essere utilizzata su un particolare database  (default: hsql)
-l : Usa un'installer binario sul filesystem locale (incompatibile con -j)
-i : Usa il template su filesystem per la generazione degli archivi dall'installer
-j : Usa l'installer prodotto dalla pipeline jenkin https://jenkins.link.it/govway/risultati-testsuite/installer/govway-installer-<version>.tgz

-h : Mostra questa pagina di aiuto
"
}

DOCKERBIN="$(which docker)"
if [ -z "${DOCKERBIN}" ]
then
   echo "Impossibile trovare il comando \"docker\""
   exit 2 
fi



TAG=
BRANCH=
VER=
while getopts "ht:v:d:jl:i:" opt; do
  case $opt in
    t) TAG="$OPTARG"; NO_COLON=${TAG//:/}
      [ ${#TAG} -eq ${#NO_COLON} -o "${TAG:0:1}" == ':' -o "${TAG:(-1):1}" == ':' ] && { echo "Il tag fornito \"$TAG\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    v) VER="$OPTARG"; [ -n "$BRANCH" ] && { echo "Le opzioni -v e -b sono incompatibili. Impostare solo una delle due."; exit 2; } ;;
    d) DB="${OPTARG}"; case "$DB" in hsql);;postgresql);;*) echo "Database non supportato: $DB"; exit 2;; esac ;;
    l) LOCALFILE="$OPTARG"
       [ ! -f "${LOCALFILE}" ] && { echo "Il file indicato non esiste o non e' raggiungibile [${LOCALFILE}]."; exit 3; } 
       ;;
    j) JENKINS="true"
        [ -n "${LOCALFILE}" ] && { echo "Le opzioni -j e -l sono incompatibili. Impostare solo una delle due."; exit 2; }
       ;;
    i) TEMPLATE="${OPTARG}"
        [ ! -f "${TEMPLATE}" ] && { echo "Il file indicato non esiste o non e' raggiungibile [${TMPLATE}]."; exit 3; } 
        ;;
    h) printHelp
       exit 0
       ;;
    \?)
      echo "Opzione non valida: -$opt"
      exit 1
      ;;
  esac
done


rm -rf target
mkdir -p target/
cp -fr commons target/

DOCKERBUILD_OPT=()
DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_fullversion=${VER:-3.3.5}")
[ -n "${DB}" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_database_vendor=${DB}")
[ -n "${TEMPLATE}" ] &&  cp -f "${TEMPLATE}" target/commons/


# Build immagine installer
if [ -n "${JENKINS}" ]
then
  INSTALLER_DOCKERFILE="govway/Dockerfile.jenkins"
elif [ -n "${LOCALFILE}" ]
then
  INSTALLER_DOCKERFILE="govway/Dockerfile.daFile"
  cp -f "${LOCALFILE}" target/
else
  INSTALLER_DOCKERFILE="govway/Dockerfile.github"
fi


"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
  -t linkitaly/govway-installer_${DB:-hsql}:${VER:-3.3.5} \
  -f ${INSTALLER_DOCKERFILE} target
RET=$?
[ ${RET} -eq  0 ] || exit ${RET}
 
# Build imagine govway
[ -n "$TAG" ] || TAG="linkitaly/govway_${DB:-hsql}:3.3.5"
DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '-t' "${TAG}")

"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
  --build-arg source_image=linkitaly/govway-installer_${DB:-hsql} \
  --build-arg govway_archives_type=all \
  -f govway/Dockerfile.govway target
RET=$?
[ ${RET} -eq  0 ] || exit ${RET}


if [ ${DB:-hsql} != 'hsql' ]
then
  mkdir -p compose/govway_{conf,log}
  chmod 777 compose/govway_{conf,log}

  SHORT=${TAG#*:}
  cat - << EOYAML > compose/docker-compose.yaml
version: '2'
services:
  govway:
    container_name: govway_${SHORT}
    image: ${TAG}
    ports:
        - 8080:8080
        - 8443:8443
    volumes:
        - ./govway_conf:/etc/govway
        - ./govway_log:/var/log/govway
    depends_on:
        - database
    environment:
        - GOVWAY_DB_SERVER=pg_govway_${SHORT}
        - GOVWAY_DB_PORT=5432
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
  database:
    container_name: pg_govway_${SHORT}
    image: postgres:13
    environment:
        - POSTGRES_DB=govwaydb
        - POSTGRES_USER=govway
        - POSTGRES_PASSWORD=govway
EOYAML

fi
