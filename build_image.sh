#!/bin/bash

function printHelp() {
echo "Usage $(basename $0) [ -t <repository>:<tagname> | <Installer Sorgente> | <Personalizzazioni> | <Avanzate> | -h ]"
echo 
echo "Options
-t <TAG>       : Imposta il nome del TAG ed il repository locale utilizzati per l'immagine prodotta 
                 NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-h             : Mostra questa pagina di aiuto

Installer Sorgente:
-v <VERSIONE>  : Imposta la versione dell'installer binario da utilizzare per il build (default: ${LATEST_GOVWAY_RELEASE})
-l <FILE>      : Usa un'installer binario sul filesystem locale (incompatibile con -j)
-j             : Usa l'installer prodotto dalla pipeline jenkins https://jenkins.link.it/govway-testsuite/installer/govway-installer-<version>.tgz

Personalizzazioni:
-d <TIPO>      : Prepara l'immagine per essere utilizzata su un particolare database  (valori: [hsql, postgresql, mysql, mariadb, oracle] , default: hsql)
-a <TIPO>      : Imposta quali archivi inserire nell'immmagine finale (valori: [runtime , manager, batch, all] , default: all)
-e <PATH>      : Imposta il path interno utilizzato per i file di configurazione di govway 
-f <PATH>      : Imposta il path interno utilizzato per i log di govway
-g <TIPO>      : Prepara l'immagine per avere come base un particolare application server  (valori: [tomcat9, wildfly25] , default: tomcat9)

Avanzate:
-i <FILE>      : Usa il template ant.installer.properties indicato per la generazione degli archivi dall'installer
-r <DIRECTORY> : Inserisce il contenuto della directory indicata, tra i contenuti custom di runtime
-m <DIRECTORY> : Inserisce il contenuto della directory indicata, tra i contenuti custom di manager
-w <DIRECTORY> : Esegue tutti gli scripts di CLI per la configurazione dell'AS contenuti nella directory indicata
-o <DIRECTORY> : Utilizza il driver JDBC Oracle contenuto dentro la directory per configurare l'immagine (il file viene cancellato al termine)
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
CUSTOM_GOVWAY_AS_CLI=

LATEST_LINK="$(curl -qw '%{redirect_url}\n' https://github.com/link-it/govway/releases/latest 2> /dev/null)"
LATEST_GOVWAY_RELEASE="${LATEST_LINK##*/}"

while getopts "ht:v:d:jl:i:a:r:m:w:o:e:f:g:" opt; do
  case $opt in
    t) TAG="$OPTARG"; NO_COLON=${TAG//:/}
      [ ${#TAG} -eq ${#NO_COLON} -o "${TAG:0:1}" == ':' -o "${TAG:(-1):1}" == ':' ] && { echo "Il tag fornito \"$TAG\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    v) VER="$OPTARG"; [ -n "$BRANCH" ] && { echo "Le opzioni -v e -b sono incompatibili. Impostare solo una delle due."; exit 2; } ;;
    d) DB="${OPTARG}"; case "$DB" in hsql);;postgresql);;oracle);;mysql);;mariadb);;*) echo "Database non supportato: $DB"; exit 2;; esac ;;
    g) APPSERV="${OPTARG}"; case "$APPSERV" in tomcat9);;wildfly25);;*) echo "Application server non supportato: $APPSERV"; exit 2;; esac ;;
    l) LOCALFILE="$OPTARG"
        [ ! -f "${LOCALFILE}" ] && { echo "Il file indicato non esiste o non e' raggiungibile [${LOCALFILE}]."; exit 3; } 
       ;;
    j) JENKINS="true"
        [ -n "${LOCALFILE}" ] && { echo "Le opzioni -j e -l sono incompatibili. Impostare solo una delle due."; exit 2; }
       ;;
    i) TEMPLATE="${OPTARG}"
        [ ! -f "${TEMPLATE}" ] && { echo "Il file indicato non esiste o non e' raggiungibile [${TEMPLATE}]."; exit 3; } 
        ;;
    a) ARCHIVI="${OPTARG}"; case "$ARCHIVI" in runtime);;manager);;batch);;all);;*) echo "Tipologia archivi da inserire non riconosciuta: ${ARCHIVI}"; exit 2;; esac ;;
    r) CUSTOM_RUNTIME="${OPTARG}"
        [ ! -d "${CUSTOM_RUNTIME}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${CUSTOM_RUNTIME}]."; exit 3; }
        [ -z "$(ls -A ${CUSTOM_RUNTIME})" ] && { echo "la directory [${CUSTOM_RUNTIME}] e' vuota.";  }
        ;;
    m) CUSTOM_MANAGER="${OPTARG}"
        [ ! -d "${CUSTOM_MANAGER}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${CUSTOM_MANAGER}]."; exit 3; }
        [ -z "$(ls -A ${CUSTOM_MANAGER})" ] && { echo "la directory [${CUSTOM_MANAGER}] e' vuota.";  }
        ;;
    w) CUSTOM_GOVWAY_AS_CLI="${OPTARG}"
        [ ! -d "${CUSTOM_GOVWAY_AS_CLI}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${CUSTOM_GOVWAY_AS_CLI}]."; exit 3; }
        [ -z "$(ls -A ${CUSTOM_GOVWAY_AS_CLI})" ] && { echo "la directory [${CUSTOM_GOVWAY_AS_CLI}] e' vuota.";  }
        ;;
    o) CUSTOM_ORACLE_JDBC="${OPTARG}"
        [ ! -d "${CUSTOM_ORACLE_JDBC}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${CUSTOM_ORACLE_JDBC}]."; exit 3; }
        [ -z "$(ls -A ${CUSTOM_ORACLE_JDBC})" ] && { echo "la directory [${CUSTOM_ORACLE_JDBC}] e' vuota.";  }
        ;;
    e) CUSTOM_GOVWAY_HOME="${OPTARG}" ;;
    f) CUSTOM_GOVWAY_LOG="${OPTARG}" ;;
    h) printHelp
       exit 0
       ;;
    \?)
      echo "Opzione non valida: -$opt"
      exit 1
      ;;
  esac
done
[ "${ARCHIVI}" == 'batch' -a "${DB:-hsql}" == 'hsql' ] && { echo "Il build dell'immagine batch non puo' essere eseguita per il database HSQL"; exit 4; }

rm -rf buildcontext
mkdir -p buildcontext/
cp -fr "commons/${APPSERV:-tomcat9}" buildcontext/commons
cp -f commons/* buildcontext/commons 2> /dev/null

#export DOCKER_BUILDKIT=0
DOCKERBUILD_OPTS=('--build-arg' "govway_appserver=${APPSERV:-tomcat9}")
DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_fullversion=${VER:-${LATEST_GOVWAY_RELEASE}}")
[ -n "${TEMPLATE}" ] &&  cp -f "${TEMPLATE}" buildcontext/commons/
[ -n "${CUSTOM_GOVWAY_HOME}" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_home=${CUSTOM_GOVWAY_HOME}")
[ -n "${CUSTOM_GOVWAY_LOG}" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_log=${CUSTOM_GOVWAY_LOG}")
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

if [ -n "${DB}" ]
then
  if [ "${DB}" == 'mariadb' ]
  then
    DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_database_vendor=mysql")
  else
    DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_database_vendor=${DB}")
  fi
fi

"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
  -t linkitaly/govway-installer_${DB:-hsql}:${VER:-${LATEST_GOVWAY_RELEASE}} \
  -f ${INSTALLER_DOCKERFILE} buildcontext
RET=$?
[ ${RET} -eq  0 ] || exit ${RET}
 
if [ "${DB}" == 'mariadb' ]
then
  c=$(( ${#DOCKERBUILD_OPTS[@]} - 1 ))
  unset  DOCKERBUILD_OPTS[$c]
  DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} "govway_database_vendor=mariadb")
fi
# Build imagini GovWAY

[ -n "${ARCHIVI}" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_archives_type=${ARCHIVI}")
if [ -z "$TAG" ] 
then
  REPO=linkitaly/govway
  TAGNAME=${VER:-${LATEST_GOVWAY_RELEASE}}
  [ -n "${ARCHIVI}" -a "${ARCHIVI}" != 'all' ] && TAGNAME=${VER:-${LATEST_GOVWAY_RELEASE}}_${ARCHIVI}
  
  # mantengo i nomi dei tag compatibili con quelli usati in precedenza
  case "${DB:-hsql}" in
  hsql) TAG="${REPO}:${TAGNAME}" ;;
  postgresql) TAG="${REPO}:${TAGNAME}_postgres" ;;
  *) TAG="${REPO}:${TAGNAME}_${DB}" ;;
  esac

  # il tag per tomcat9 diventa quello di default. Tutti gli altri hanno l'indicazione dell AS usato
  [ "${APPSERV:-tomcat9}" != "tomcat9" -a "${ARCHIVI}" != 'batch'  ] && TAG="${TAG}_${APPSERV}"

fi

if [ -n "${CUSTOM_GOVWAY_AS_CLI}" ]
then
  cp -r ${CUSTOM_GOVWAY_AS_CLI}/ buildcontext/custom_govway_as_cli
  DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_as_custom_scripts=custom_govway_as_cli")
fi

if [ -n "${CUSTOM_ORACLE_JDBC}" ]
then
  cp -r ${CUSTOM_ORACLE_JDBC}/ buildcontext/custom_oracle_jdbc
  DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "oracle_custom_jdbc=custom_oracle_jdbc")
fi



if [ "${ARCHIVI}" == 'batch' ]
then

  "${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
  --build-arg source_image=linkitaly/govway-installer_${DB:-hsql} \
  -t "${TAG}" \
  -f govway/Dockerfile.govway_batch buildcontext
  RET=$?
  [ ${RET} -eq  0 ] || exit ${RET}

else

"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
  --build-arg source_image=linkitaly/govway-installer_${DB:-hsql} \
  -t "${TAG}" \
  -f "govway/${APPSERV:-tomcat9}/Dockerfile.govway" buildcontext
RET=$?
[ ${RET} -eq  0 ] || exit ${RET}


fi




if [ "${DB:-hsql}" != 'hsql' -a "${ARCHIVI}" != 'batch' ]
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
    depends_on:
        - database
    ports:
        - 8080:8080
    volumes:
        - ./govway_conf:${CUSTOM_GOVWAY_HOME:-/etc/govway}
        - ./govway_log:${CUSTOM_GOVWAY_LOG:-/var/log/govway}
EOYAML
  if [ "${DB:-hsql}" == 'postgresql' ]
  then
    cat - << EOYAML >> compose/docker-compose.yaml
    environment:
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
        - GOVWAY_DB_SERVER=pg_govway_${SHORT}
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
        - GOVWAY_POP_DB_SKIP=false
# Decommentare dopo il build dell'immagine batch (usando l'opzione "-a batch")
#  batch_stat_orarie:
#    container_name: govway_batch_${SHORT}
#    image: linkitaly/govway:${VER:-${LATEST_GOVWAY_RELEASE}}_batch_postgres
#    #command: Giornaliere
#    #command: Orarie # << default
#    depends_on:
#        - database
#    environment:
#        - GOVWAY_STAT_DB_SERVER=pg_govway_${SHORT}
#        - GOVWAY_STAT_DB_NAME=govwaydb
#        - GOVWAY_STAT_DB_USER=govway
#        - GOVWAY_STAT_DB_PASSWORD=govway
#        - GOVWAY_BATCH_USA_CRON=yes
  database:
    container_name: pg_govway_${SHORT}
    image: postgres:13
    environment:
        - POSTGRES_DB=govwaydb
        - POSTGRES_USER=govway
        - POSTGRES_PASSWORD=govway
EOYAML
  elif [ "${DB:-hsql}" == 'mariadb' ]
  then
    cat - << EOYAML >> compose/docker-compose.yaml
        # Il driver deve essere compiato manualmente nella directory corrente
        - ./mariadb-java-client-3.0.6.jar:/tmp/mariadb-java-client-3.0.6.jar 
    environment:
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
        - GOVWAY_DB_SERVER=my_govway_${SHORT}
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
        - GOVWAY_DS_JDBC_LIBS=/tmp
        - GOVWAY_POP_DB_SKIP=false
# Decommentare dopo il build dell'immagine batch (usando l'opzione "-a batch")
#  batch_stat_orarie:
#    container_name: govway_batch_${SHORT}
#    image: linkitaly/govway:${VER:-${LATEST_GOVWAY_RELEASE}}_batch_mariadb
#    #command: Giornaliere
#    #command: Orarie # << default
#    depends_on:
#        - database
#    volumes:
#        - ./mariadb-java-client-3.0.6.jar:/tmp/mariadb-java-client-3.0.6.jar 
#    environment:
#        - GOVWAY_DS_JDBC_LIBS=/tmp
#        - GOVWAY_STAT_DB_SERVER=my_govway_${SHORT}
#        - GOVWAY_STAT_DB_NAME=govwaydb
#        - GOVWAY_STAT_DB_USER=govway
#        - GOVWAY_STAT_DB_PASSWORD=govway
#        - GOVWAY_BATCH_USA_CRON=yes
  database:
    container_name: my_govway_${SHORT}
    image: mariadb:10.6
    ## Il pagesize di InnoDB deve essere a 64K per evitare errori di caricamento
    command:
      - "--innodb-page-size=64k"
      - "--innodb-log-buffer-size=32M"
      - "--innodb-buffer-pool-size=512M"    
    environment:
      - MARIADB_DATABASE=govwaydb
      - MARIADB_USER=govway
      - MARIADB_PASSWORD=govway
      - MARIADB_ROOT_PASSWORD=my-secret-pw
    ports:
       - 3306:3306
EOYAML
    echo 
    echo "ATTENZIONE: Copiare il driver jdbc Mariadb 'mariadb-java-client-3.0.6.jar' dentro la directory './compose/'"
    echo "ATTENZIONE: Verificare il che il parametro innodb_page_size di MariaDB sia impostato 64K per evitare problemi"
    echo "            Row size too large (> 8126)"
    echo
    echo "ATTENZIONE: Copiare il driver jdbc Mariadb 'mariadb-java-client-3.0.6.jar' dentro la directory './compose/'" > compose/README.first
    echo "ATTENZIONE: Verificare il che il parametro innodb_page_size di MariaDB sia impostato 64K per evitare problemi" >> compose/README.first
    echo "            Row size too large (> 8126)" >> compose/README.first
  elif [ "${DB:-hsql}" == 'mysql' ]
  then
    cat - << EOYAML >> compose/docker-compose.yaml
        # Il driver deve essere compiato manualmente nella directory corrente
        - ./mysql-connector-java-8.0.29.jar:/tmp/mysql-connector-java-8.0.29.jar 
    environment:
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
        - GOVWAY_DB_SERVER=my_govway_${SHORT}
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
        - GOVWAY_DS_JDBC_LIBS=/tmp
        - GOVWAY_POP_DB_SKIP=false
# Decommentare dopo il build dell'immagine batch (usando l'opzione "-a batch")
#  batch_stat_orarie:
#    container_name: govway_batch_${SHORT}
#    image: linkitaly/govway:${VER:-${LATEST_GOVWAY_RELEASE}}_batch_mysql
#    #command: Giornaliere
#    #command: Orarie # << default
#    depends_on:
#        - database
#    volumes:
#        - ./mysql-connector-java-8.0.29.jar:/tmp/mysql-connector-java-8.0.29.jar 
#    environment:
#        - GOVWAY_DS_JDBC_LIBS=/tmp
#        - GOVWAY_STAT_DB_SERVER=my_govway_${SHORT}
#        - GOVWAY_STAT_DB_NAME=govwaydb
#        - GOVWAY_STAT_DB_USER=govway
#        - GOVWAY_STAT_DB_PASSWORD=govway
#        - GOVWAY_BATCH_USA_CRON=yes
  database:
    container_name: my_govway_${SHORT}
    image: mysql:8.0
    environment:
      - MYSQL_DATABASE=govwaydb
      - MYSQL_USER=govway
      - MYSQL_PASSWORD=govway
      - MYSQL_ROOT_PASSWORD=my-secret-pw
    ports:
       - 3306:3306
EOYAML
    echo 
    echo "ATTENZIONE: Copiare il driver jdbc Mysql 'mysql-connector-java-8.0.29.jar' dentro la directory './compose/'"
    echo
    echo "ATTENZIONE: Copiare il driver jdbc Mysql 'mysql-connector-java-8.0.29.jar' dentro la directory './compose/'" > compose/README.first


  elif [ "${DB:-hsql}" == 'oracle' ]
  then
    mkdir -p compose/oracle_startup
    mkdir -p compose/ORADATA
    chmod 777 compose/ORADATA
    cat - << EOSQL > compose/oracle_startup/create_db_and_user.sql
alter session set container = GOVWAYPDB;
-- USER GOVWAY
CREATE USER "GOVWAY" IDENTIFIED BY "GOVWAY"  
DEFAULT TABLESPACE "USERS"
TEMPORARY TABLESPACE "TEMP";
ALTER USER "GOVWAY" QUOTA UNLIMITED ON "USERS";
GRANT "CONNECT" TO "GOVWAY" ;
GRANT "RESOURCE" TO "GOVWAY" ;
EOSQL

    cat - << EOYAML >> compose/docker-compose.yaml
        # Il driver deve essere compiato manualmente nella directory corrente
        - ./ojdbc10.jar:/tmp/ojdbc10.jar 
    environment:
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
        - GOVWAY_DB_SERVER=or_govway_${SHORT}
        - GOVWAY_DB_NAME=GOVWAYPDB
        - GOVWAY_DB_USER=GOVWAY
        - GOVWAY_DB_PASSWORD=GOVWAY
        - GOVWAY_DS_JDBC_LIBS=/tmp
        - GOVWAY_ORACLE_JDBC_URL_TYPE=servicename
        - GOVWAY_POP_DB_SKIP=false
        # il container oracle puo impiegare anche 20 minuti ad avviarsi
        - GOVWAY_LIVE_DB_CHECK_MAX_RETRY=120
        - GOVWAY_READY_DB_CHECK_MAX_RETRY=600
# Decommentare dopo il build dell'immagine batch (usando l'opzione "-a batch")
#  batch_stat_orarie:
#    container_name: govway_batch_${SHORT}
#    image: linkitaly/govway:${VER:-${LATEST_GOVWAY_RELEASE}}_batch_oracle
#    #command: Giornaliere
#    #command: Orarie # << default
#    depends_on:
#        - database
#    volumes:
#        # Il driver deve essere compiato manualmente nella directory corrente
#        - ./ojdbc10.jar:/tmp/ojdbc10.jar
#    environment:
#        - GOVWAY_STAT_DB_SERVER=or_govway_${SHORT}
#        - GOVWAY_STAT_DB_NAME=GOVWAYPDB
#        - GOVWAY_STAT_DB_USER=GOVWAY
#        - GOVWAY_STAT_DB_PASSWORD=GOVWAY
#        - GOVWAY_DS_JDBC_LIBS=/tmp
#        - GOVWAY_ORACLE_JDBC_URL_TYPE=servicename
#        - GOVWAY_BATCH_USA_CRON=yes
  database:
    container_name: or_govway_${SHORT}
    image: container-registry.oracle.com/database/enterprise:19.3.0.0
    shm_size: 2g
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
    environment:
      - ORACLE_PDB=GOVWAYPDB
      - ORACLE_PWD=GovWay@123
    volumes:
       - ./ORADATA:/opt/oracle/oradata
       - ./oracle_startup:/opt/oracle/scripts/startup
    ports:
       - 1521:1521
EOYAML
  fi
fi
exit 0
