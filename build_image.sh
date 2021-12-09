#!/bin/bash

function printHelp() {
echo "Usage $(basename $0) [ -t <repository>:<tagname> | <Installer Sorgente> | <Personalizzazioni> | <Avanzate> | -h ]"
echo 
echo "Options
Options
-t <TAG>       : Imposta il nome del TAG ed il repository locale utilizzati per l'immagine prodotta 
                 NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-h             : Mostra questa pagina di aiuto

Installer Sorgente:
-v <VERSIONE>  : Imposta la versione dell'installer binario da utilizzare per il build (default: 3.3.5)
-l <FILE>      : Usa un'installer binario sul filesystem locale (incompatibile con -j)
-j             : Usa l'installer prodotto dalla pipeline jenkins https://jenkins.link.it/govway/risultati-testsuite/installer/govway-installer-<version>.tgz

Personalizzazioni:
-d <TIPO>      : Prepara l'immagine per essere utilizzata su un particolare database  (valori: [ hsql, postgresql ,oracle] , default: hsql)
-a <TIPO>      : Imposta quali archivi inserire nell'immmagine finale (valori: [runtime , manager, all] , default: all)

Avanzate:
-i <FILE>      : Usa il template ant.installer.properties indicato per la generazione degli archivi dall'installer
-r <DIRECTORY> : Inserisce il contenuto della directory indicata, tra i contenuti custom di runtime
-m <DIRECTORY> : Inserisce il contenuto della directory indicata, tra i contenuti custom di manager
-w <DIRECTORY> : Esegue tutti gli scripts widlfly contenuti nella directory indicata
"
}

DOCKERBIN="$(which docker)"
if [ -z "${DOCKERBIN}" ]
then
   echo "Impossibile trovare il comando \"docker\""
   exit 2 
fi



TAG=
VER=
DB=
LOCALFILE=
TEMPLATE=
ARCHIVI=
CUSTOM_MANAGER=
CUSTOM_MANAGER=
CUSTOM_WIDLFLY_CLI=
while getopts "ht:v:d:jl:i:a:r:m:w:" opt; do
  case $opt in
    t) TAG="$OPTARG"; NO_COLON=${TAG//:/}
      [ ${#TAG} -eq ${#NO_COLON} -o "${TAG:0:1}" == ':' -o "${TAG:(-1):1}" == ':' ] && { echo "Il tag fornito \"$TAG\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    v) VER="$OPTARG"; [ -n "$BRANCH" ] && { echo "Le opzioni -v e -b sono incompatibili. Impostare solo una delle due."; exit 2; } ;;
    d) DB="${OPTARG}"; case "$DB" in hsql);;postgresql);;oracle;;*) echo "Database non supportato: $DB"; exit 2;; esac ;;
    l) LOCALFILE="$OPTARG"
        [ ! -f "${LOCALFILE}" ] && { echo "Il file indicato non esiste o non e' raggiungibile [${LOCALFILE}]."; exit 3; } 
       ;;
    j) JENKINS="true"
        [ -n "${LOCALFILE}" ] && { echo "Le opzioni -j e -l sono incompatibili. Impostare solo una delle due."; exit 2; }
       ;;
    i) TEMPLATE="${OPTARG}"
        [ ! -f "${TEMPLATE}" ] && { echo "Il file indicato non esiste o non e' raggiungibile [${TEMPLATE}]."; exit 3; } 
        ;;
    a) ARCHIVI="${OPTARG}"; case "$ARCHIVI" in runtime);;manager);;all);;*) echo "Tipologia archivi da inserire non riconosciuta: ${ARCHIVI}"; exit 2;; esac ;;
    r) CUSTOM_RUNTIME="${OPTARG}"
        [ ! -d "${CUSTOM_RUNTIME}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${CUSTOM_RUNTIME}]."; exit 3; }
        [ -z "$(ls -A ${CUSTOM_RUNTIME})" ] && { echo "la directory [${CUSTOM_RUNTIME}] e' vuota.";  }
        ;;
    m) CUSTOM_MANAGER="${OPTARG}"
        [ ! -d "${CUSTOM_MANAGER}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${CUSTOM_MANAGER}]."; exit 3; }
        [ -z "$(ls -A ${CUSTOM_MANAGER})" ] && { echo "la directory [${CUSTOM_MANAGER}] e' vuota.";  }
        ;;
    w) CUSTOM_WIDLFLY_CLI="${OPTARG}"
        [ ! -d "${CUSTOM_WIDLFLY_CLI}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${CUSTOM_WIDLFLY_CLI}]."; exit 3; }
        [ -z "$(ls -A ${CUSTOM_WIDLFLY_CLI})" ] && { echo "la directory [${CUSTOM_WIDLFLY_CLI}] e' vuota.";  }
        ;;
    o) CUSTOM_ORACLE_JDBC="${OPTARG}"
        [ ! -d "${CUSTOM_ORACLE_JDBC}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${CUSTOM_ORACLE_JDBC}]."; exit 3; }
        [ -z "$(ls -A ${CUSTOM_ORACLE_JDBC})" ] && { echo "la directory [${CUSTOM_ORACLE_JDBC}] e' vuota.";  }
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


rm -rf buildcontext
mkdir -p buildcontext/
cp -fr commons buildcontext/

DOCKERBUILD_OPT=()
DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_fullversion=${VER:-3.3.5}")
[ -n "${DB}" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_database_vendor=${DB}")
[ -n "${TEMPLATE}" ] &&  cp -f "${TEMPLATE}" buildcontext/commons/
if [ -n "${CUSTOM_RUNTIME}" ]
then
  cp -r ${CUSTOM_RUNTIME}/ buildcontext/runtime
  DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "runtime_custom_archives=runtime")
fi
if [ -n "${CUSTOM_MANAGER}" ]
then
  cp -r ${CUSTOM_MANAGER}/ buildcontext/manager
  DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "manager_custom_archives=manager")
fi

# Build immagine installer
if [ -n "${JENKINS}" ]
then
  INSTALLER_DOCKERFILE="govway/Dockerfile.jenkins"
elif [ -n "${LOCALFILE}" ]
then
  INSTALLER_DOCKERFILE="govway/Dockerfile.daFile"
  cp -f "${LOCALFILE}" buildcontext/
else
  INSTALLER_DOCKERFILE="govway/Dockerfile.github"
fi


"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
  -t linkitaly/govway-installer_${DB:-hsql}:${VER:-3.3.5} \
  -f ${INSTALLER_DOCKERFILE} buildcontext
RET=$?
[ ${RET} -eq  0 ] || exit ${RET}
 
# Build imagine govway

[ -n "${ARCHIVI}" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_archives_type=${ARCHIVI}")
if [ -z "$TAG" ] 
then
  REPO=linkitaly/govway
  TAGNAME=${VER:-3.3.5}
  [ -n "${ARCHIVI}" -a ${ARCHIVI} != 'all' ] && TAGNAME=${VER:-3.3.5}_${ARCHIVI}
  
  # mantengo i nomi dei tag compatibili con quelli usati in precedenza
  if [ ${DB:-hsql} == 'hsql' ]
  then
    TAG="${REPO}:${TAGNAME}"
  elif [ ${DB:-hsql} == 'postgresql' ]
  then
    TAG="${REPO}:${TAGNAME}_postgres"
  fi
fi

if [ -n "${CUSTOM_WIDLFLY_CLI}" ]
then
  cp -r ${CUSTOM_WIDLFLY_CLI}/ buildcontext/custom_widlfly_cli
  DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "wildfly_custom_scripts=custom_widlfly_cli")
fi

if [ -n "${CUSTOM_ORACLE_JDBC}" ]
then
  cp -r ${CUSTOM_ORACLE_JDBC}/ buildcontext/custom_oracle_jdbc
  DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "oracle_custom_jdbc=custom_oracle_jdbc")
fi

"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
  --build-arg source_image=linkitaly/govway-installer_${DB:-hsql} \
  -t "${TAG}" \
  -f govway/Dockerfile.govway buildcontext
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
exit 0
