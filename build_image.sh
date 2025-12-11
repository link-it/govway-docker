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
-j             : Usa l'installer prodotto dalla pipeline jenkins di CI

Personalizzazioni:
-a <TIPO>      : Imposta quali archivi inserire nell'immmagine finale (valori: [runtime , manager, batch, all] , default: all)
-e <PATH>      : Imposta il path interno utilizzato per i file di configurazione di govway
-f <PATH>      : Imposta il path interno utilizzato per i log di govway
-g <TIPO>      : Prepara l'immagine per avere come base un particolare application server  (valori: [tomcat9, tomca10, wildfly25, wildfly35] , default: tomcat9)

Avanzate:
-i <FILE>      : Usa il template ant.installer.properties indicato per la generazione degli archivi dall'installer
-r <DIRECTORY> : Inserisce il contenuto della directory indicata, tra i contenuti custom di runtime
-m <DIRECTORY> : Inserisce il contenuto della directory indicata, tra i contenuti custom di manager
-w <DIRECTORY> : Esegue tutti gli scripts di CLI per la configurazione dell'AS contenuti nella directory indicata
-o <DIRECTORY> : Utilizza il driver JDBC Oracle contenuto dentro la directory per configurare l'immagine (il file viene cancellato al termine)

NOTA: L'immagine prodotta supporta tutti i database (hsql, postgresql, mysql, mariadb, oracle).
      Il tipo di database viene selezionato a runtime tramite la variabile d'ambiente obbligatoria GOVWAY_DB_TYPE.
"
}

# Funzione per confrontare versioni (ritorna 0 se $1 >= $2, 1 altrimenti)
version_ge() {
  local ver1="${1%%-*}"  # rimuove suffissi come -beta, -rc
  local ver2="${2%%-*}"

  # Estrai major.minor
  local major1="${ver1%%.*}"
  local rest1="${ver1#*.}"
  local minor1="${rest1%%.*}"

  local major2="${ver2%%.*}"
  local rest2="${ver2#*.}"
  local minor2="${rest2%%.*}"

  # Confronta major
  if [ "$major1" -gt "$major2" ] 2>/dev/null; then
    return 0
  elif [ "$major1" -lt "$major2" ] 2>/dev/null; then
    return 1
  fi

  # Major uguale, confronta minor
  if [ "$minor1" -ge "$minor2" ] 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

##############
###  MAIN  ###
##############


DOCKERBIN="$(which docker)"
if [ -z "${DOCKERBIN}" ]
then
   echo "Impossibile trovare il comando \"docker\""
   exit 2 
fi


TAG=
VER=
LOCALFILE=
TEMPLATE=
ARCHIVI=
CUSTOM_MANAGER=
CUSTOM_MANAGER=
CUSTOM_GOVWAY_AS_CLI=
REGISTRY_PREFIX=linkitaly
#REGISTRY_PREFIX=localhost

LATEST_LINK="$(curl -qw '%{redirect_url}\n' https://github.com/link-it/govway/releases/latest 2> /dev/null)"
LATEST_GOVWAY_RELEASE="${LATEST_LINK##*/}"

while getopts "ht:v:jl:i:a:r:m:w:o:e:f:g:k:" opt; do
  case $opt in
    t) TAG="$OPTARG"; NO_COLON=${TAG//:/}
      [ ${#TAG} -eq ${#NO_COLON} -o "${TAG:0:1}" == ':' -o "${TAG:(-1):1}" == ':' ] && { echo "Il tag fornito \"$TAG\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    v) VER="$OPTARG"; [ -n "$BRANCH" ] && { echo "Le opzioni -v e -b sono incompatibili. Impostare solo una delle due."; exit 2; } ;;
    g) APPSERV="${OPTARG}"; case "$APPSERV" in tomcat9);;tomcat10);;wildfly25);;wildfly35);;*) echo "Application server non supportato: $APPSERV"; exit 2;; esac ;;
    k) JDKVER="${OPTARG}"; case "$JDKVER" in 11);;21);;*) echo "Versione JDK non supportato: $JDKVER"; exit 2;; esac ;;
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


# Determina la versione effettiva da utilizzare
EFFECTIVE_VERSION="${VER:-${LATEST_GOVWAY_RELEASE}}"

# Per versioni >= 3.4, imposta tomcat10 come default se non specificato
if version_ge "${EFFECTIVE_VERSION}" "3.4" && [ -z "${APPSERV}" ]
then
  APPSERV='tomcat10'
fi

# Per versioni >= 3.4, tomcat9 e wildfly25 non sono supportati
if version_ge "${EFFECTIVE_VERSION}" "3.4"
then
  if [ "${APPSERV}" == 'tomcat9' -o "${APPSERV}" == 'wildfly25' ]
  then
    echo "GovWay ${EFFECTIVE_VERSION} può essere preparato solo per tomcat10 o wildfly35"
    exit 4
  fi
fi

[  "${APPSERV:-tomcat9}" == "tomcat10" -o "${APPSERV:-tomcat9}" == "wildfly35" ] && JDKVER=21

rm -rf buildcontext
mkdir -p buildcontext/
cp -fr "commons/${APPSERV:-tomcat9}" buildcontext/commons
cp -f commons/* buildcontext/commons 2> /dev/null
[ "${ARCHIVI}" == 'runtime' -o "${ARCHIVI}" == 'manager'  ] && cp -f commons/runmanager/ant.install.properties.template buildcontext/commons
[ "${ARCHIVI}" == 'batch'  ] && cp -f commons/batch/ant.install.properties.template buildcontext/commons

#export DOCKER_BUILDKIT=0
DOCKERBUILD_OPTS=('--build-arg' "govway_appserver=${APPSERV:-tomcat9}" '--build-arg' "jdk_version=${JDKVER:-11}")
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

"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
  -t ${REGISTRY_PREFIX}/govway-installer:${VER:-${LATEST_GOVWAY_RELEASE}} \
  -f ${INSTALLER_DOCKERFILE} buildcontext
RET=$?
[ ${RET} -eq  0 ] || exit ${RET}
# Build imagini GovWAY

[ -n "${ARCHIVI}" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_archives_type=${ARCHIVI}")
if [ -z "$TAG" ]
then
  REPO=${REGISTRY_PREFIX}/govway
  TAGNAME=${VER:-${LATEST_GOVWAY_RELEASE}}
  [ -n "${ARCHIVI}" -a "${ARCHIVI}" != 'all' ] && TAGNAME=${VER:-${LATEST_GOVWAY_RELEASE}}_${ARCHIVI}

  TAG="${REPO}:${TAGNAME}"

  # il tag per tomcat9 diventa quello di default. Tutti gli altri hanno l'indicazione dell AS usato (solo per versioni precedenti 3.4.x)
  if ! version_ge "${EFFECTIVE_VERSION}" "3.4" && [ "${APPSERV:-tomcat9}" != "tomcat9" ] && [ "${ARCHIVI}" != 'batch' ]
  then
    TAG="${TAG}_${APPSERV}"
  fi
  # il tag per tomcat10 diventa quello di default. Tutti gli altri hanno l'indicazione dell AS usato (solo per versioni >= 3.4.x)
  if version_ge "${EFFECTIVE_VERSION}" "3.4" && [ "${APPSERV:-tomcat9}" != "tomcat10" ] && [ "${ARCHIVI}" != 'batch' ]
  then
    TAG="${TAG}_${APPSERV}"
  fi

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

DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "source_image=${REGISTRY_PREFIX}/govway-installer:${VER:-${LATEST_GOVWAY_RELEASE}}")


if [ "${ARCHIVI}" == 'batch' ]
then
  DOCKERFILE="govway/Dockerfile.govway_batch"
else
  DOCKERFILE="govway/${APPSERV:-tomcat9}/Dockerfile.govway"
fi

"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
-t "${TAG}" \
-f $DOCKERFILE buildcontext
RET=$?
[ ${RET} -eq  0 ] || exit ${RET}



# Genera docker-compose di esempio per tutti i database supportati
if [ "${ARCHIVI}" != 'batch' ]
then
  SHORT=${TAG#*:}

  # PostgreSQL
  mkdir -p compose/postgresql/govway_{conf,log}
  chmod 777 compose/postgresql/govway_{conf,log}
  cat - << EOYAML > compose/postgresql/docker-compose.yaml
version: '2'
services:
  govway:
    container_name: govway_pg_${SHORT}
    image: ${TAG}
    depends_on:
        - database
    ports:
        - 8080:8080
    volumes:
        - ./govway_conf:${CUSTOM_GOVWAY_HOME:-/etc/govway}
        - ./govway_log:${CUSTOM_GOVWAY_LOG:-/var/log/govway}
        # Il driver deve essere copiato manualmente nella directory corrente
        - ./postgresql-42.7.5.jar:/tmp/postgresql-42.7.5.jar
    environment:
        - GOVWAY_DB_TYPE=postgresql
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
        - GOVWAY_DB_SERVER=pg_govway_${SHORT}
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
        - GOVWAY_DS_JDBC_LIBS=/tmp
        - GOVWAY_POP_DB_SKIP=false
# Decommentare dopo il build dell'immagine batch (usando l'opzione "-a batch")
#  batch_stat_orarie:
#    container_name: govway_batch_${SHORT}
#    image: ${REGISTRY_PREFIX}/govway:${VER:-${LATEST_GOVWAY_RELEASE}}_batch
#    #command: Giornaliere
#    #command: Orarie # << default
#    depends_on:
#        - database
#    volumes:
#        - ./postgresql-42.7.5.jar:/tmp/postgresql-42.7.5.jar
#    environment:
#        - GOVWAY_DB_TYPE=postgresql
#        - GOVWAY_DS_JDBC_LIBS=/tmp
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
  echo "ATTENZIONE: Copiare il driver jdbc PostgreSQL 'postgresql-42.7.5.jar' dentro la directory './compose/postgresql/'" > compose/postgresql/README.first

  # MariaDB
  mkdir -p compose/mariadb/govway_{conf,log}
  chmod 777 compose/mariadb/govway_{conf,log}
  cat - << EOYAML > compose/mariadb/docker-compose.yaml
version: '2'
services:
  govway:
    container_name: govway_maria_${SHORT}
    image: ${TAG}
    depends_on:
        - database
    ports:
        - 8080:8080
    volumes:
        - ./govway_conf:${CUSTOM_GOVWAY_HOME:-/etc/govway}
        - ./govway_log:${CUSTOM_GOVWAY_LOG:-/var/log/govway}
        # Il driver deve essere copiato manualmente nella directory corrente
        - ./mariadb-java-client-3.0.6.jar:/tmp/mariadb-java-client-3.0.6.jar
    environment:
        - GOVWAY_DB_TYPE=mariadb
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
#    image: ${REGISTRY_PREFIX}/govway:${VER:-${LATEST_GOVWAY_RELEASE}}_batch
#    #command: Giornaliere
#    #command: Orarie # << default
#    depends_on:
#        - database
#    volumes:
#        - ./mariadb-java-client-3.0.6.jar:/tmp/mariadb-java-client-3.0.6.jar
#    environment:
#        - GOVWAY_DB_TYPE=mariadb
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
  cat - << EOREADME > compose/mariadb/README.first
ATTENZIONE: Copiare il driver jdbc Mariadb 'mariadb-java-client-3.0.6.jar' dentro la directory './compose/mariadb/'
ATTENZIONE: Verificare il che il parametro innodb_page_size di MariaDB sia impostato 64K per evitare problemi
            Row size too large (> 8126)
EOREADME

  # MySQL
  mkdir -p compose/mysql/govway_{conf,log}
  chmod 777 compose/mysql/govway_{conf,log}
  cat - << EOYAML > compose/mysql/docker-compose.yaml
version: '2'
services:
  govway:
    container_name: govway_mysql_${SHORT}
    image: ${TAG}
    depends_on:
        - database
    ports:
        - 8080:8080
    volumes:
        - ./govway_conf:${CUSTOM_GOVWAY_HOME:-/etc/govway}
        - ./govway_log:${CUSTOM_GOVWAY_LOG:-/var/log/govway}
        # Il driver deve essere copiato manualmente nella directory corrente
        - ./mysql-connector-java-8.0.29.jar:/tmp/mysql-connector-java-8.0.29.jar
    environment:
        - GOVWAY_DB_TYPE=mysql
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
#    image: ${REGISTRY_PREFIX}/govway:${VER:-${LATEST_GOVWAY_RELEASE}}_batch
#    #command: Giornaliere
#    #command: Orarie # << default
#    depends_on:
#        - database
#    volumes:
#        - ./mysql-connector-java-8.0.29.jar:/tmp/mysql-connector-java-8.0.29.jar
#    environment:
#        - GOVWAY_DB_TYPE=mysql
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
  echo "ATTENZIONE: Copiare il driver jdbc Mysql 'mysql-connector-java-8.0.29.jar' dentro la directory './compose/mysql/'" > compose/mysql/README.first

  # Oracle
  mkdir -p compose/oracle/govway_{conf,log}
  mkdir -p compose/oracle/oracle_startup
  mkdir -p compose/oracle/ORADATA
  chmod 777 compose/oracle/govway_{conf,log}
  chmod 777 compose/oracle/ORADATA
  cat - << EOSQL > compose/oracle/oracle_startup/create_db_and_user.sql
alter session set container = GOVWAYPDB;
-- USER GOVWAY
CREATE USER "GOVWAY" IDENTIFIED BY "GOVWAY"
DEFAULT TABLESPACE "USERS"
TEMPORARY TABLESPACE "TEMP";
ALTER USER "GOVWAY" QUOTA UNLIMITED ON "USERS";
GRANT "CONNECT" TO "GOVWAY" ;
GRANT "RESOURCE" TO "GOVWAY" ;
EOSQL

  cat - << EOYAML > compose/oracle/docker-compose.yaml
version: '2'
services:
  govway:
    container_name: govway_ora_${SHORT}
    image: ${TAG}
    depends_on:
        - database
    ports:
        - 8080:8080
    volumes:
        - ./govway_conf:${CUSTOM_GOVWAY_HOME:-/etc/govway}
        - ./govway_log:${CUSTOM_GOVWAY_LOG:-/var/log/govway}
        # Il driver deve essere copiato manualmente nella directory corrente
        - ./ojdbc10.jar:/tmp/ojdbc10.jar
    environment:
        - GOVWAY_DB_TYPE=oracle
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
#    image: ${REGISTRY_PREFIX}/govway:${VER:-${LATEST_GOVWAY_RELEASE}}_batch
#    #command: Giornaliere
#    #command: Orarie # << default
#    depends_on:
#        - database
#    volumes:
#        # Il driver deve essere copiato manualmente nella directory corrente
#        - ./ojdbc10.jar:/tmp/ojdbc10.jar
#    environment:
#        - GOVWAY_DB_TYPE=oracle
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
  echo "ATTENZIONE: Copiare il driver jdbc Oracle 'ojdbc10.jar' dentro la directory './compose/oracle/'" > compose/oracle/README.first

  # HSQL (standalone, senza database esterno)
  mkdir -p compose/hsql/govway_{conf,log}
  chmod 777 compose/hsql/govway_{conf,log}
  cat - << EOYAML > compose/hsql/docker-compose.yaml
version: '2'
services:
  govway:
    container_name: govway_hsql_${SHORT}
    image: ${TAG}
    ports:
        - 8080:8080
    volumes:
        - ./govway_conf:${CUSTOM_GOVWAY_HOME:-/etc/govway}
        - ./govway_log:${CUSTOM_GOVWAY_LOG:-/var/log/govway}
    environment:
        - GOVWAY_DB_TYPE=hsql
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
EOYAML
  echo "Esempio docker-compose per HSQL (database embedded, solo per test/sviluppo)" > compose/hsql/README.first

  echo
  echo "Generati esempi docker-compose nelle directory:"
  echo "  - compose/postgresql/"
  echo "  - compose/mysql/"
  echo "  - compose/mariadb/"
  echo "  - compose/oracle/"
  echo "  - compose/hsql/"
  echo
  echo "NOTA: Impostare GOVWAY_DB_TYPE in base al database scelto."
  echo "      Valori supportati: hsql, postgresql, mysql, mariadb, oracle"
  echo
fi
exit 0
