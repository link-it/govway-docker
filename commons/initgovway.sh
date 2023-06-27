#!/bin/bash -x
GOVWAY_LIVE_DB_CHECK_CONNECT_TIMEOUT=${GOVWAY_LIVE_DB_CHECK_CONNECT_TIMEOUT:=5}
GOVWAY_LIVE_DB_CHECK_FIRST_SLEEP_TIME=${GOVWAY_LIVE_DB_CHECK_FIRST_SLEEP_TIME:=0}
GOVWAY_LIVE_DB_CHECK_SLEEP_TIME=${GOVWAY_LIVE_DB_CHECK_SLEEP_TIME:=2}
GOVWAY_LIVE_DB_CHECK_MAX_RETRY=${GOVWAY_LIVE_DB_CHECK_MAX_RETRY:=30}
GOVWAY_LIVE_DB_CHECK_SKIP=${GOVWAY_LIVE_DB_CHECK_SKIP:=FALSE}
GOVWAY_READY_DB_CHECK_SKIP_SLEEP_TIME=${GOVWAY_READY_DB_CHECK_SKIP_SLEEP_TIME:=2}
GOVWAY_READY_DB_CHECK_MAX_RETRY=${GOVWAY_READY_DB_CHECK_MAX_RETRY:=5}
GOVWAY_READY_DB_CHECK_SKIP=${GOVWAY_READY_DB_CHECK_SKIP:=FALSE}
GOVWAY_POP_DB_SKIP=${GOVWAY_POP_DB_SKIP:=TRUE}

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

SQLTOOL_RC_FILE=/tmp/sqltool.rc

# Pronto per reinizializzare file di configurazione
> ${SQLTOOL_RC_FILE}

for DESTINAZIONE in RUN CONF TRAC STAT
do
    if [ "${DESTINAZIONE}" == 'RUN' ]
    then
        SERVER="${GOVWAY_DB_SERVER}"
        DBNAME="${GOVWAY_DB_NAME}"
        DBUSER="${GOVWAY_DB_USER}"    
        DBPASS="${GOVWAY_DB_PASSWORD}"
        QUERYSTRING="${DATASOURCE_CONN_PARAM}"
    else

        eval "SERVER=\${GOVWAY_${DESTINAZIONE}_DB_SERVER}"
        eval "DBNAME=\${GOVWAY_${DESTINAZIONE}_DB_NAME}"
        eval "DBUSER=\${GOVWAY_${DESTINAZIONE}_DB_USER}"    
        eval "DBPASS=\${GOVWAY_${DESTINAZIONE}_DB_PASSWORD}"
        eval "QUERYSTRING=\${DATASOURCE_${DESTINAZIONE}_CONN_PARAM}"
    fi
    SERVER_PORT="${SERVER#*:}"
    SERVER_HOST="${SERVER%:*}"
    USE_RUN_DB=FALSE
    [ "${DESTINAZIONE}" != 'RUN' -a "${SERVER}" == "${GOVWAY_DB_SERVER}" -a "${DBNAME}" == "${GOVWAY_DB_NAME}" ] && USE_RUN_DB=TRUE


    case "${GOVWAY_DB_TYPE:-hsql}" in
    oracle)
        [ "${SERVER_PORT}" == "${SERVER_HOST}" ] && SERVER_PORT=1521
        JDBC_URL="jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${SERVER_HOST}:${SERVER_PORT}${ORACLE_JDBC_DB_SEPARATOR}${DBNAME}${QUERYSTRING}"
        START_TRANSACTION=""
    ;;
    postgresql) 
        [ "${SERVER_PORT}" == "${SERVER_HOST}" ] && SERVER_PORT=5432
        JDBC_URL="jdbc:postgresql://${SERVER_HOST}:${SERVER_PORT}/${DBNAME}${QUERYSTRING}"
        START_TRANSACTION="START TRANSACTION;"
    ;;
    hsql|*)
        DBNAME=govway
        DBUSER=govway
        DBPASS=govway
        JDBC_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/${DBNAME};shutdown=true"
        START_TRANSACTION="START TRANSACTION ISOLATION LEVEL SERIALIZABLE;"
    ;;
    esac

    INVOCAZIONE_CLIENT="-Dfile.encoding=UTF-8 -cp ${GOVWAY_DRIVER_JDBC}:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/sqltool.jar org.hsqldb.cmdline.SqlTool --rcFile=${SQLTOOL_RC_FILE} "
    cat - <<EOSQLTOOL >> ${SQLTOOL_RC_FILE}

urlid govwayDB${DESTINAZIONE}
url ${JDBC_URL}
username ${DBUSER}
password ${DBPASS}
driver ${GOVWAY_DS_DRIVER_CLASS}
transiso TRANSACTION_READ_COMMITTED
charset UTF-8
EOSQLTOOL

    # Server liveness
    if [ "${GOVWAY_LIVE_DB_CHECK_SKIP^^}" == "FALSE" -a "${GOVWAY_DB_TYPE:-hsql}" != 'hsql' ]
    then
    	echo "INFO: Liveness base dati ${DESTINAZIONE} ... attendo"
	    sleep ${GOVWAY_LIVE_DB_CHECK_FIRST_SLEEP_TIME}s
	    DB_READY=1
	    NUM_RETRY=0
	    while [ ${DB_READY} -ne 0 -a ${NUM_RETRY} -lt ${GOVWAY_LIVE_DB_CHECK_MAX_RETRY} ]
	    do
            nc  -w "${GOVWAY_LIVE_DB_CHECK_CONNECT_TIMEOUT}" -z "${SERVER_HOST}" "${SERVER_PORT}"
            DB_READY=$?
            NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
            if [  ${DB_READY} -ne 0 ]
            then
                echo "INFO: Liveness base dati ${DESTINAZIONE} ... attendo"
                sleep ${GOVWAY_LIVE_DB_CHECK_SLEEP_TIME}s
            fi
	    done
       	if [  ${DB_READY} -ne 0 -a ${NUM_RETRY} -eq ${GOVWAY_LIVE_DB_CHECK_MAX_RETRY} ]
	    then
		    echo "FATAL: Liveness base dati ${DESTINAZIONE} ... Base dati NON disponibile dopo $((${GOVWAY_LIVE_DB_CHECK_SLEEP_TIME=} * ${GOVWAY_LIVE_DB_CHECK_MAX_RETRY})) secondi"
		    exit 1
        else
            echo "INFO: Liveness base dati ${DESTINAZIONE} ... Base dati disponibile"
	    fi
    fi
    # Server Readyness
    if [ "${GOVWAY_READY_DB_CHECK_SKIP^^}" == "FALSE" ]
    then
        ## REINIZIALIZZO VARIABILI DI CONTROLLO
        POP=0
        DB_POP=1


        DBINFO="${mappa_dbinfo[${DESTINAZIONE}]}"    
        
        case "${GOVWAY_DB_TYPE:-hsql}" in
        oracle)
        EXIST_QUERY="SELECT count(table_name) FROM all_tables WHERE  LOWER(table_name)='${DBINFO,,}' AND LOWER(owner)='${DBUSER,,}';" 
        ;;
        *)         
        EXIST_QUERY="SELECT count(table_name) FROM information_schema.tables WHERE LOWER(table_name)='${DBINFO,,}' and (LOWER(table_catalog)='${DBNAME,,}' or LOWER(table_catalog)='public' );" 
        ;;
        hsql|*)
        ;;
        esac

        DB_READY=1
	    NUM_RETRY=0
        while [ ${DB_READY} -ne 0 -a ${NUM_RETRY} -lt ${GOVWAY_READY_DB_CHECK_MAX_RETRY} ]
	    do
            EXIST=$(java ${INVOCAZIONE_CLIENT} --sql="${EXIST_QUERY}" govwayDB${DESTINAZIONE} 2> /dev/null)
            DB_READY=$?
            NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
            if [  ${DB_READY} -ne 0 ]
            then
                echo "INFO: Readyness base dati ${DESTINAZIONE} ... riprovo"
                sleep ${GOVWAY_READY_DB_CHECK_SKIP_SLEEP_TIME}
            fi
        done
        if [ ${DB_READY} -ne 0 -a ${NUM_RETRY} -lt ${GOVWAY_READY_DB_CHECK_MAX_RETRY}  ]
        then
            echo "FATAL: Readyness base dati ${DESTINAZIONE} ... Base dati NON disponibile dopo $(( ${GOVWAY_READY_DB_CHECK_SKIP_SLEEP_TIME} * ${GOVWAY_READY_DB_CHECK_MAX_RETRY} ))secondi"
		    exit 1
        else
            ##ripulisco gli spazi
            EXIST="${EXIST// /}"
        fi
        if [ ${EXIST} -eq 1 ]
        then
            #  possibile che il db sia usato per piu' funzioni devo verifcare che non sia gia' stato popolato
            #DBINFONOTES="${mappa_dbinfostring[${DESTINAZIONE}]}"
            #POP_QUERY="SELECT count(*) FROM ${DBINFO} where notes LIKE '${DBINFONOTES}';"

            POP_QUERY="SELECT count(*) FROM ${DBINFO};"
            POP=$(java ${INVOCAZIONE_CLIENT} --sql="${POP_QUERY}" govwayDB${DESTINAZIONE} 2> /dev/null)
            ##ripulisco gli spazi
            POP="${POP// /}"

        fi
        # Popolamento automatico del db 
        if [ "${GOVWAY_POP_DB_SKIP^^}" == "FALSE" ]
        then 
            if [ "${USE_RUN_DB^^}" == "TRUE" ]
            then
                MAX_COUNT=3
                [ ${DESTINAZIONE} == 'CONF' ] && MAX_COUNT=1
            else
                MAX_COUNT=1
            fi
            if [ -n "${POP}" -a ${POP} -lt ${MAX_COUNT} ]
            then
                echo "WARN: Readyness base dati ${DESTINAZIONE} ... non inizializzato"
                SUFFISSO="${mappa_suffissi[${DESTINAZIONE}]}"
                mkdir -p /var/tmp/${GOVWAY_DB_TYPE:-hsql}/
                #
                # Ignoro in caso il file SQL non esista
                #
                [ ! -f /opt/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql ] && continue
                /bin/cp -f /opt/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}*.sql /var/tmp/${GOVWAY_DB_TYPE:-hsql}/
                #
                # Elimino la creazione di tabelle comuni se il database e' utilizzato per piu funzioni (evita errore tabella gia' esistente)
                #
                if [ "${DESTINAZIONE}" != 'RUN' ]
                then
                    if [[ ( "${GOVWAY_DB_TYPE:-hsql}" == 'hsql' && ${DBINFO} == "db_info" ) || ( ${DBINFO} == "db_info" && "${USE_RUN_DB}" == "TRUE" ) ]]
                    then
                        sed  \
                        -e '/CREATE TABLE db_info/,/;/d' \
                        -e '/CREATE SEQUENCE seq_db_info/d' \
                        -e '/CREATE TABLE OP2_SEMAPHORE/,/;/d' \
                        -e '/CREATE SEQUENCE seq_OP2_SEMAPHORE/d' \
                        -e '/CREATE TRIGGER trg_OP2_SEMAPHORE/,/\//d' \
                        -e '/CREATE UNIQUE INDEX idx_semaphore_1/d' \
                        -e '/CREATE TRIGGER trg_db_info/,/\//d' \
                        /opt/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql > /var/tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql 
		    elif [[ ( ${DBINFO} == "db_info_console" && "${USE_RUN_DB}" == "TRUE" && "${DESTINAZIONE}" == 'CONF' ) ]]
      		    then
                        sed  \
                        -e '/CREATE TABLE OP2_SEMAPHORE/,/;/d' \
                        -e '/CREATE SEQUENCE seq_OP2_SEMAPHORE/d' \
                        -e '/CREATE TRIGGER trg_OP2_SEMAPHORE/,/\//d' \
                        -e '/CREATE UNIQUE INDEX idx_semaphore_1/d' \
                        /opt/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql > /var/tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql 
                    fi
                fi
                #
                # Aggiusto l'SQL per il database oracle 
                #
                if [ "${GOVWAY_DB_TYPE:-hsql}" == 'oracle' ]
                then
                    # La sintassi dei trigger è problematica
                    # utilizzo la raw mode per evitare errori di sintassi
                    # http://www.hsqldb.org/doc/2.0/util-guide/sqltool-chapt.html#sqltool_raw-sect
                    #
                    sed -i -e '/^CREATE TRIGGER .*$/i \
\\.' -e 's/^\/$/.\n:;/' /var/tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql
                fi
                #
                # Inizializzazione database ${DESTINAZIONE}
                # 
                echo "INFO: Readyness base dati ${DESTINAZIONE} ... inizializzazione avviata."
                java ${INVOCAZIONE_CLIENT} --continueOnErr=false govwayDB${DESTINAZIONE} << EOSCRIPT
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
${START_TRANSACTION}
\i /var/tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql
\i /var/tmp/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}_init.sql
COMMIT;
EOSCRIPT
                DB_POP=$?
            fi
            if [ $POP -ge 1 -o $DB_POP -eq 0 ] 
            then
                #TODO: da valutare come soluzione per il caso delle connessioni in blocking-timeut
                #      quando il db è hsql
                #if  [ "${GOVWAY_DB_TYPE:-hsql}" != 'hsql' ]
                #then
                #    echo
                #    echo "INFO: Readyness base dati ${DESTINAZIONE} ... setto dtatase in modalita MVCC."
                #    java ${INVOCAZIONE_CLIENT} --continueOnErr=false --autoCommit govwayDB${DESTINAZIONE} << EOSCRIPT    
    #SET DATABASE TRANSACTION CONTROL MVCC;
    #EOSCRIPT
                #fi
                echo
                echo "INFO: Readyness base dati ${DESTINAZIONE} ... inizializzazione completata."   
            else
                echo
                echo "INFO: Readyness base dati ${DESTINAZIONE} ... inizializzazione fallita."
                exit $DB_POP
            fi 
        fi
    fi
done



exit 0
