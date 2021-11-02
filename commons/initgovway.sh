#!/bin/bash -x
DB_CHECK_CONNECT_TIMEOUT=${DB_CHECK_CONNECT_TIMEOUT:=5}
DB_CHECK_FIRST_SLEEP_TIME=${DB_CHECK_FIRST_SLEEP_TIME:=0}
DB_CHECK_SLEEP_TIME=${DB_CHECK_SLEEP_TIME:=2}
DB_CHECK_MAX_RETRY=${DB_CHECK_MAX_RETRY:=30}
SKIP_DB_CHECK=${SKIP_DB_CHECK:=FALSE}


declare -A mappa_suffissi 
mappa_suffissi[RUN]=''
mappa_suffissi[CONF]=Configurazione
mappa_suffissi[TRAC]=Tracciamento
mappa_suffissi[STAT]=Statistiche


declare -A mappa_dbinfo
mappa_dbinfo[RUN]='db_info'
mappa_dbinfo[CONF]='db_info_console'
mappa_dbinfo[TRAC]='db_info'
mappa_dbinfo[STAT]='db_info'

declare -A mappa_dbinfostring
mappa_dbinfostring[RUN]='%Database di GovWay'
mappa_dbinfostring[CONF]='%Database della Console di Gestione di GovWay'
mappa_dbinfostring[TRAC]='%Archivio delle tracce e dei messaggi diagnostici emessi da GovWay'
mappa_dbinfostring[STAT]='%Informazioni Statistiche sulle richieste gestite da GovWay'

# Setting valori di Default per i datasource GOVWAY
if [ "${GOVWAY_DB_TYPE:-hsql}" != 'hsql' ]
then
    #
    # Sanity check variabili minime attese
    #
    [  -n "${GOVWAY_DB_SERVER}" -a -n  "${GOVWAY_DB_USER}" -a -n "${GOVWAY_DB_PASSWORD}" -a -n "${GOVWAY_DB_NAME}" ] || exit 1


    #
    # Sanity check variabile GOVWAY_DB_SERVER per db remoto
    #
    [ -n "${GOVWAY_CONF_DB_SERVER}" ] || export GOVWAY_CONF_DB_SERVER="${GOVWAY_DB_SERVER}"
    [ -n "${GOVWAY_TRAC_DB_SERVER}" ] || export GOVWAY_TRAC_DB_SERVER="${GOVWAY_DB_SERVER}"
    [ -n "${GOVWAY_STAT_DB_SERVER}" ] || export GOVWAY_STAT_DB_SERVER="${GOVWAY_DB_SERVER}"


    [ -n "${GOVWAY_CONF_DB_NAME}" ] || export GOVWAY_CONF_DB_NAME="${GOVWAY_DB_NAME}"
    [ -n "${GOVWAY_TRAC_DB_NAME}" ] || export GOVWAY_TRAC_DB_NAME="${GOVWAY_DB_NAME}"
    [ -n "${GOVWAY_STAT_DB_NAME}" ] || export GOVWAY_STAT_DB_NAME="${GOVWAY_DB_NAME}"

    [ -n "${GOVWAY_CONF_DB_USER}" ] || export GOVWAY_CONF_DB_USER="${GOVWAY_DB_USER}"
    [ -n "${GOVWAY_TRAC_DB_USER}" ] || export GOVWAY_TRAC_DB_USER="${GOVWAY_DB_USER}"
    [ -n "${GOVWAY_STAT_DB_USER}" ] || export GOVWAY_STAT_DB_USER="${GOVWAY_DB_USER}"

    [ -n "${GOVWAY_CONF_DB_PASSWORD}" ] || export GOVWAY_CONF_DB_PASSWORD="${GOVWAY_DB_PASSWORD}"
    [ -n "${GOVWAY_TRAC_DB_PASSWORD}" ] || export GOVWAY_TRAC_DB_PASSWORD="${GOVWAY_DB_PASSWORD}"
    [ -n "${GOVWAY_STAT_DB_PASSWORD}" ] || export GOVWAY_STAT_DB_PASSWORD="${GOVWAY_DB_PASSWORD}"

fi

for DESTINAZIONE in RUN CONF TRAC STAT
do
    if [ "${DESTINAZIONE}" == 'RUN' ]
    then
        SERVER="${GOVWAY_DB_SERVER}"
        DBNAME="${GOVWAY_DB_NAME}"
        DBUSER="${GOVWAY_DB_USER}"    
        DBPASS="${GOVWAY_DB_PASSWORD}"
    else

        eval "SERVER=\${GOVWAY_${DESTINAZIONE}_DB_SERVER}"
        eval "DBNAME=\${GOVWAY_${DESTINAZIONE}_DB_NAME}"
        eval "DBUSER=\${GOVWAY_${DESTINAZIONE}_DB_USER}"    
        eval "DBPASS=\${GOVWAY_${DESTINAZIONE}_DB_PASSWORD}"
    fi
    SERVER_PORT="${SERVER#*:}"
    SERVER_HOST="${SERVER%:*}"
    
    case "${GOVWAY_DB_TYPE:-hsql}" in
    postgresql) 
        [ "${SERVER_PORT}" == "${SERVER_HOST}" ] && SERVER_PORT=5432
        DRIVER_JDBC="/opt/postgresql-${POSTGRES_JDBC_VERSION}.jar"
        DRIVER_JDBC_CLASS='org.postgresql.Driver'
        JDBC_URL="jdbc:postgresql://${SERVER_HOST}:${SERVER_PORT}/${DBNAME}"
    ;;
    hsql|*)
        DRIVER_JDBC_CLASS='org.hsqldb.jdbc.JDBCDriver'
        DBNAME=govway
        DBUSER=govway
        DBPASS=govway
        JDBC_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/${DBNAME};shutdown=true"
    ;;
    esac

    INVOCAZIONE_CLIENT="-Dfile.encoding=UTF-8 -cp ${DRIVER_JDBC}:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/sqltool.jar org.hsqldb.cmdline.SqlTool"
    cat - <<EOSQLTOOL >> $HOME/sqltool.rc

urlid govwayDB${DESTINAZIONE}
url ${JDBC_URL}
username ${DBUSER}
password ${DBPASS}
driver ${DRIVER_JDBC_CLASS}
transiso TRANSACTION_READ_COMMITTED
charset UTF-8
EOSQLTOOL

    # Server liveness
    if [ "${SKIP_DB_CHECK^^}" == "FALSE" -a "${GOVWAY_DB_TYPE:-hsql}" != 'hsql' ]
    then
    	echo "INFO: Attendo avvio della base dati ..."
	    sleep ${DB_CHECK_FIRST_SLEEP_TIME}s
	    DB_READY=1
	    NUM_RETRY=0
	    while [ ${DB_READY} -ne 0 -a ${NUM_RETRY} -lt ${DB_CHECK_MAX_RETRY} ]
	    do
            nc  -w "${DB_CHECK_CONNECT_TIMEOUT}" -z "${SERVER_HOST}" "${SERVER_PORT}"
            DB_READY=$?
            NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
            if [  ${DB_READY} -ne 0 ]
            then
                echo "INFO: Attendo disponibilita' della base dati .."
                sleep ${DB_CHECK_SLEEP_TIME}s
            fi
	    done
       	if [  ${DB_READY} -ne 0 -a ${NUM_RETRY} -eq ${DB_CHECK_MAX_RETRY} ]
	    then
		    echo "FATAL: Base dati NON disponibile dopo $((${DB_CHECK_SLEEP_TIME=} * ${DB_CHECK_MAX_RETRY})) secondi  ... Uscita."
		    exit 1
	    fi
    fi
    # Server Readyness
    ## REINIZIALIZZO VARIABILI DI CONTROLLO
    POP=0
    DB_POP=1


    DBINFO="${mappa_dbinfo[${DESTINAZIONE}]}"
    EXIST_QUERY="SELECT count(table_name) FROM information_schema.tables WHERE LOWER(table_name)='${DBINFO,,}' and LOWER(table_catalog)='${DBNAME,,}';" 
    EXIST=$(java ${INVOCAZIONE_CLIENT} --sql="${EXIST_QUERY}" govwayDB${DESTINAZIONE} 2> /dev/null)
    # in caso di problemi di connessione esco
    [ $? -eq 0 ] || exit 1
    if [ ${EXIST} -eq 1 ]
    then
        #  possibile che il db sia usato per piu' funzioni devo verifcare che non sia gia' stato popolato
        DBINFONOTES="${mappa_dbinfostring[${DESTINAZIONE}]}"
        POP_QUERY="SELECT count(*) FROM ${DBINFO} where notes LIKE '${DBINFONOTES}';"
        POP=$(java ${INVOCAZIONE_CLIENT} --sql="${POP_QUERY}" govwayDB${DESTINAZIONE} 2> /dev/null)
    fi    
    if [ -n "${POP}" -a ${POP} -eq 0 ]
    then
        SUFFISSO="${mappa_suffissi[${DESTINAZIONE}]}"
        mkdir -p /var/tmp/${GOVWAY_DB_TYPE:-hsql}/
        #
        # Ignoro in caso il file SQL non esista
        #
        [ ! -f /tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql ] && continue
        /bin/cp -f /tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}*.sql /var/tmp/${GOVWAY_DB_TYPE:-hsql}/
        #
        # Elimino la creazione di tabelle comuni se il database e' utilizzato per piu funzioni (evita errore tabella gia' esistente)
        #
        if [ "${DESTINAZIONE}" != 'RUN' ]
        then
            if [[ ( "${GOVWAY_DB_TYPE:-hsql}" == 'hsql' && ${DBINFO} == "db_info" ) || ( ${DBINFO} == "db_info" && "${SERVER}" == "${GOVWAY_DB_SERVER}" && "${DBNAME}" == "${GOVWAY_DB_NAME}" ) ]]
            then
                sed  \
                -e '/CREATE TABLE db_info/,/;/d' \
                -e '/CREATE SEQUENCE seq_db_info/d' \
                -e '/CREATE TABLE OP2_SEMAPHORE/,/;/d' \
                -e '/CREATE SEQUENCE seq_OP2_SEMAPHORE/d' \
                -e '/CREATE UNIQUE INDEX idx_semaphore_1/d' \
                /tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql > /var/tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql 
            fi
        fi
        #
        # Inizializzazione database ${DESTINAZIONE}
        # 
        java ${INVOCAZIONE_CLIENT} --continueOnErr=false govwayDB${DESTINAZIONE} << EOSCRIPT
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
\i /var/tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql
\i /var/tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}_init.sql
COMMIT;
EOSCRIPT
        DB_POP=$?
    fi
    [ $POP -eq 1 -o $DB_POP -eq 0 ] || exit $DB_POP
done



exit 0