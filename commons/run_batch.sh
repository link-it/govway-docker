#!/bin/bash
# I file e le directory creati a runtime devono risultare scrivibili dal gruppo:
# negli ambienti che assegnano al container uno UID arbitrario (es. le SCC di
# OpenShift) l'unica appartenenza garantita e' quella al gruppo '0'.
umask 002
exec 6<> /tmp/run_batch.log
exec 2>&6
set -x
#Const


case "$1" in
Orarie|orarie|Oraria|oraria) TIPO='StatisticheOrarie'
    COMANDO=generaStatisticheOrarie.sh
    INTERVALLO_SCHEDULAZIONE=${GOVWAY_BATCH_INTERVALLO_CRON:-5} ;;
Giornaliere|giornaliere|Giornaliera|giornaliera) TIPO='StatisticheGiornaliere'
    COMANDO=generaStatisticheGiornaliere.sh
    INTERVALLO_SCHEDULAZIONE=${GOVWAY_BATCH_INTERVALLO_CRON:-30} ;;
GeneraReportPDND|generareportpdnd|generaReportPDND|GeneraReportPdnd|generaReportPdnd) TIPO='GenerazioneCSVTracingPDND'
    COMANDO=generaReportPDND.sh
    INTERVALLO_SCHEDULAZIONE=${GOVWAY_BATCH_INTERVALLO_CRON:-30} ;;
PubblicaReportPDND|pubblicareportpdnd|pubblicaReportPDND|PubblicaReportPdnd|pubblicaReportPdnd) TIPO='PubblicazioneCSVTracingPDND'
    COMANDO=pubblicaReportPDND.sh
    declare -r GOVWAY_STARTUP_ENTITY_REGEX=^[0-9A-Za-z][\-A-Za-z0-9]*$
    if [[ ! "${GOVWAY_DEFAULT_ENTITY_NAME}" =~ ${GOVWAY_STARTUP_ENTITY_REGEX} ]]
    then

        echo "FATAL: Sanity check variabili ... fallito."
        if [ -z "${GOVWAY_DEFAULT_ENTITY_NAME}" ]
        then
            echo "FATAL: La variabile GOVWAY_DEFAULT_ENTITY_NAME è obbligatoria per l'operaione ${1}"
        else
            echo "FATAL: GOVWAY_DEFAULT_ENTITY_NAME può iniziare solo con un carattere o cifra [0-9A-Za-z] e dev'essere formato solo da caratteri, cifre e '-'"
        fi
        exit 1
    fi

    INTERVALLO_SCHEDULAZIONE=${GOVWAY_BATCH_INTERVALLO_CRON:-30} ;;
*) echo "Tipo di statistiche non supportato: '$1'"
   exit 1
   ;;
esac 
[ ${INTERVALLO_SCHEDULAZIONE} -eq ${INTERVALLO_SCHEDULAZIONE} -a ${INTERVALLO_SCHEDULAZIONE} -gt 0 ] 2> /dev/null \
|| { echo "Non e' possibile schedulare il batch ad intervalli di '${INTERVALLO_SCHEDULAZIONE}' minuti."; exit 2; }


case "${GOVWAY_DB_TYPE}" in
mysql|mariadb|postgresql|oracle|sqlserver)
    #
    # Sanity check variabili minime attese
    #
    if [ -n "${GOVWAY_STAT_DB_SERVER}" -a -n  "${GOVWAY_STAT_DB_USER}" -a -n "${GOVWAY_STAT_DB_NAME}" ] 
    then
            [ -n "${GOVWAY_STAT_DB_PASSWORD}" ] || echo "WARN: La variabile GOVWAY_STAT_DB_PASSWORD non è stata impostata."
            echo "INFO: Sanity check variabili ... ok."
    else
        echo "FATAL: Sanity check variabili ... fallito."
        echo "FATAL: Devono essere settate almeno le seguenti variabili:
GOVWAY_STAT_DB_SERVER: ${GOVWAY_STAT_DB_SERVER}
GOVWAY_STAT_DB_NAME: ${GOVWAY_STAT_DB_NAME}
GOVWAY_STAT_DB_USER: ${GOVWAY_STAT_DB_USER}
"
        exit 1
    fi


    if [ -n "${GOVWAY_DS_JDBC_LIBS}" ] 
    then
        if [ ! -d "${GOVWAY_DS_JDBC_LIBS}" ]
        then
            echo "FATAL: Sanity check JDBC ... fallito."
            echo "FATAL: Il path alla directory che contiene il driver JDBC, non è leggibile o non è una directory: [GOVWAY_DS_JDBC_LIBS=${GOVWAY_DS_JDBC_LIBS}] "
            exit 1
        fi
    fi
    case "${GOVWAY_DB_TYPE}" in
    postgresql)
        if [ -z "${GOVWAY_DS_JDBC_LIBS}" ]
        then           
            echo "WARN: Sanity check JDBC ... in corso."
            echo "WARN: Il path alla directory che contiene il driver JDBC, deve essere indicato tramite la variabile GOVWAY_DS_JDBC_LIBS "
            echo "WARN: Verrà utilizzato il driver PostgreSQL interno. Questo comportamento è DEPRECATO è verra rimosso nelle prossime versioni. "
            echo "WARN: Aggiornate il vostro deploy in modo da eliminare questo warning."

            export GOVWAY_DS_JDBC_LIBS="/tmp/postgresql-jdbc"
            mkdir /tmp/postgresql-jdbc
            /bin/cp -f "/opt/postgresql-${POSTGRES_JDBC_VERSION}.jar" ${GOVWAY_DS_JDBC_LIBS}
        fi
        export GOVWAY_DS_DRIVER_CLASS='org.postgresql.Driver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'
    ;;
    mysql)

        if [ -z "${GOVWAY_DS_JDBC_LIBS}" ]
        then
            echo "FATAL: Sanity check JDBC ... fallito."
            echo "FATAL: Il path alla directory che contiene il driver JDBC, deve essere indicato tramite la variabile GOVWAY_DS_JDBC_LIBS "
            exit 1
        fi

        if [ -n "${GOVWAY_DS_CONN_PARAM}" ]
        then
            GOVWAY_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        fi
        if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]
        then
            GOVWAY_CONF_DS_CONN_PARAM="${GOVWAY_CONF_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        fi
        if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]
        then
            GOVWAY_TRAC_DS_CONN_PARAM="${GOVWAY_TRAC_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        fi
        if [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ]
        then
            GOVWAY_STAT_DS_CONN_PARAM="${GOVWAY_STAT_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        else
            GOVWAY_STAT_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
        fi

        export GOVWAY_DS_DRIVER_CLASS='com.mysql.cj.jdbc.Driver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'
    ;;

    mariadb)

        if [ -z "${GOVWAY_DS_JDBC_LIBS}" ]
        then
            echo "FATAL: Sanity check JDBC ... fallito."
            echo "FATAL: Il path alla directory che contiene il driver JDBC, deve essere indicato tramite la variabile GOVWAY_DS_JDBC_LIBS "
            exit 1
        fi

        if [ -n "${GOVWAY_DS_CONN_PARAM}" ]
        then
            GOVWAY_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        fi
        if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]
        then
            GOVWAY_CONF_DS_CONN_PARAM="${GOVWAY_CONF_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        fi
        if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]
        then
            GOVWAY_TRAC_DS_CONN_PARAM="${GOVWAY_TRAC_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        fi
        if [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ]
        then
            GOVWAY_STAT_DS_CONN_PARAM="${GOVWAY_STAT_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        else
            GOVWAY_STAT_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
        fi

        export GOVWAY_DS_DRIVER_CLASS='org.mariadb.jdbc.Driver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'
    ;;


    oracle)

        # ATTENZIONE la variabile GOVWAY_ORACLE_JDBC_PATH è stata deprecata in favore di GOVWAY_DS_JDBC_LIBS.
        # se solo GOVWAY_ORACLE_JDBC_PATH è valorizzata provo a mantenere la compatibilità usando il nome della directory 
        # se nessuna delle due viene specificata si tratta di un errore per il db oracle
        # se sono valorizzate entrambe viene usata GOVWAY_DS_JDBC_LIBS
        if [ -n "${GOVWAY_ORACLE_JDBC_PATH}" ]
        then
            echo "WARN: Sanity check JDBC ... La variabile GOVWAY_ORACLE_JDBC_PATH è stata deprecata in favore di GOVWAY_DS_JDBC_LIBS."
            if [ -z "${GOVWAY_DS_JDBC_LIBS}" ]
            then
                export GOVWAY_DS_JDBC_LIBS="$(dirname ${GOVWAY_ORACLE_JDBC_PATH})"
            else
                echo "WARN: Recupero librerie per il driver jdbc da [GOVWAY_DS_JDBC_LIBS=${GOVWAY_DS_JDBC_LIBS}]."
            fi
        elif [ -z "${GOVWAY_ORACLE_JDBC_PATH}" -a -z "${GOVWAY_DS_JDBC_LIBS}" ]
        then
            echo "FATAL: Sanity check JDBC ... fallito."
            echo "FATAL: Il path alla directory che contiene il driver JDBC, deve essere indicato tramite la variabile GOVWAY_DS_JDBC_LIBS "
            exit 1
        fi

        if [ "${GOVWAY_ORACLE_JDBC_URL_TYPE^^}" != 'SERVICENAME' -a "${GOVWAY_ORACLE_JDBC_URL_TYPE^^}" != 'SID' ]
        then
            echo "FATAL: Sanity check variabili ... fallito."
            echo "FATAL: Valore non consentito per la variabile GOVWAY_ORACLE_JDBC_URL_TYPE: [GOVWAY_ORACLE_JDBC_URL_TYPE=${GOVWAY_ORACLE_JDBC_URL_TYPE}]."
            echo "       Valori consentiti: [ servicename , sid ]"
            exit 1
        fi

        export GOVWAY_DS_DRIVER_CLASS='oracle.jdbc.OracleDriver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1 FROM DUAL'


        if [ "${GOVWAY_ORACLE_JDBC_URL_TYPE^^}" != 'SID' ]
        then
            export ORACLE_JDBC_SERVER_PREFIX='//'
            export ORACLE_JDBC_DB_SEPARATOR='/'
        else
            export ORACLE_JDBC_SERVER_PREFIX=''
            export ORACLE_JDBC_DB_SEPARATOR=':'
        fi

    ;;
    sqlserver)
        if [ -z "${GOVWAY_DS_JDBC_LIBS}" ]
        then
            echo "FATAL: Sanity check JDBC ... fallito."
            echo "FATAL: Il path alla directory che contiene il driver JDBC, deve essere indicato tramite la variabile GOVWAY_DS_JDBC_LIBS "
            exit 1
        fi

        # Gestione cifratura trasporto SQL Server
        if [ "${GOVWAY_SQLSERVER_ENCRYPT^^}" == 'FALSE' ]; then
            SQLSERVER_ENCRYPT_PARAMS='encrypt=false'
        elif [ -n "${GOVWAY_SQLSERVER_TRUSTSTORE}" ]; then
            SQLSERVER_ENCRYPT_PARAMS="encrypt=true;trustServerCertificate=false;trustStore=${GOVWAY_SQLSERVER_TRUSTSTORE}"
            [ -n "${GOVWAY_SQLSERVER_TRUSTSTORE_PASSWORD}" ] && SQLSERVER_ENCRYPT_PARAMS="${SQLSERVER_ENCRYPT_PARAMS};trustStorePassword=${GOVWAY_SQLSERVER_TRUSTSTORE_PASSWORD}"
        else
            SQLSERVER_ENCRYPT_PARAMS='encrypt=true;trustServerCertificate=true'
        fi

        if [ -n "${GOVWAY_DS_CONN_PARAM}" ]
        then
            GOVWAY_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM};${SQLSERVER_ENCRYPT_PARAMS}"
        fi
        if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]
        then
            GOVWAY_CONF_DS_CONN_PARAM="${GOVWAY_CONF_DS_CONN_PARAM};${SQLSERVER_ENCRYPT_PARAMS}"
        fi
        if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]
        then
            GOVWAY_TRAC_DS_CONN_PARAM="${GOVWAY_TRAC_DS_CONN_PARAM};${SQLSERVER_ENCRYPT_PARAMS}"
        fi
        if [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ]
        then
            GOVWAY_STAT_DS_CONN_PARAM="${GOVWAY_STAT_DS_CONN_PARAM};${SQLSERVER_ENCRYPT_PARAMS}"
        else
            GOVWAY_STAT_DS_CONN_PARAM="${SQLSERVER_ENCRYPT_PARAMS}"
        fi

        export GOVWAY_DS_DRIVER_CLASS='com.microsoft.sqlserver.jdbc.SQLServerDriver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1'
    ;;
    esac

    # Setting valori di Default per i datasource GOVWAY
    [ -n "${GOVWAY_TRAC_DB_SERVER}" ] || export GOVWAY_TRAC_DB_SERVER="${GOVWAY_STAT_DB_SERVER}"
    [ -n "${GOVWAY_CONF_DB_SERVER}" ] || export GOVWAY_CONF_DB_SERVER="${GOVWAY_STAT_DB_SERVER}"


    [ -n "${GOVWAY_TRAC_DB_NAME}" ] || export GOVWAY_TRAC_DB_NAME="${GOVWAY_STAT_DB_NAME}"
    [ -n "${GOVWAY_CONF_DB_NAME}" ] || export GOVWAY_CONF_DB_NAME="${GOVWAY_STAT_DB_NAME}"

    [ -n "${GOVWAY_TRAC_DB_USER}" ] || export GOVWAY_TRAC_DB_USER="${GOVWAY_STAT_DB_USER}"
    [ -n "${GOVWAY_CONF_DB_USER}" ] || export GOVWAY_CONF_DB_USER="${GOVWAY_STAT_DB_USER}"

    [ -n "${GOVWAY_TRAC_DB_PASSWORD}" ] || export GOVWAY_TRAC_DB_PASSWORD="${GOVWAY_STAT_DB_PASSWORD}"
    [ -n "${GOVWAY_CONF_DB_PASSWORD}" ] || export GOVWAY_CONF_DB_PASSWORD="${GOVWAY_STAT_DB_PASSWORD}"


    [ -n "${GOVWAY_TRAC_ORACLE_JDBC_URL_TYPE}" ] || export GOVWAY_TRAC_ORACLE_JDBC_URL_TYPE="${GOVWAY_ORACLE_JDBC_URL_TYPE}"
    [ -n "${GOVWAY_CONF_ORACLE_JDBC_URL_TYPE}" ] || export GOVWAY_CONF_ORACLE_JDBC_URL_TYPE="${GOVWAY_ORACLE_JDBC_URL_TYPE}"

    ## parametri di connessione URL JDBC (default vuoto)
    [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ] &&  export DATASOURCE_STAT_CONN_PARAM="?${GOVWAY_STAT_DS_CONN_PARAM}"
    if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]; then export DATASOURCE_TRAC_CONN_PARAM="?${GOVWAY_TRAC_DS_CONN_PARAM}"; else export DATASOURCE_TRAC_CONN_PARAM="${DATASOURCE_STAT_CONN_PARAM}"; fi
    if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]; then export DATASOURCE_CONF_CONN_PARAM="?${GOVWAY_CONF_DS_CONN_PARAM}"; else export DATASOURCE_CONF_CONN_PARAM="${DATASOURCE_STAT_CONN_PARAM}"; fi

    # Conversione separatore parametri per SQL Server (usa ; invece di ?)
    if [ "${GOVWAY_DB_TYPE}" == 'sqlserver' ]; then
        [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ] && export DATASOURCE_STAT_CONN_PARAM=";${GOVWAY_STAT_DS_CONN_PARAM}"
        if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]; then export DATASOURCE_TRAC_CONN_PARAM=";${GOVWAY_TRAC_DS_CONN_PARAM}"; else export DATASOURCE_TRAC_CONN_PARAM="${DATASOURCE_STAT_CONN_PARAM}"; fi
        if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]; then export DATASOURCE_CONF_CONN_PARAM=";${GOVWAY_CONF_DS_CONN_PARAM}"; else export DATASOURCE_CONF_CONN_PARAM="${DATASOURCE_STAT_CONN_PARAM}"; fi
    fi




    case "${GOVWAY_DB_TYPE}" in
    postgresql)
        # JDBC URLS
        export JDBC_CONF_URL="jdbc:postgresql://${GOVWAY_CONF_DB_SERVER}/${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}"
        export JDBC_TRAC_URL="jdbc:postgresql://${GOVWAY_TRAC_DB_SERVER}/${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}"
        export JDBC_STAT_URL="jdbc:postgresql://${GOVWAY_STAT_DB_SERVER}/${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}"

    ;;
    mysql)
        # JDBC URLS
        export JDBC_CONF_URL="jdbc:mysql://${GOVWAY_CONF_DB_SERVER}/${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}"
        export JDBC_TRAC_URL="jdbc:mysql://${GOVWAY_TRAC_DB_SERVER}/${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}"
        export JDBC_STAT_URL="jdbc:mysql://${GOVWAY_STAT_DB_SERVER}/${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}"

    ;;

    mariadb)
        # JDBC URLS
        export JDBC_CONF_URL="jdbc:mariadb://${GOVWAY_CONF_DB_SERVER}/${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}"
        export JDBC_TRAC_URL="jdbc:mariadb://${GOVWAY_TRAC_DB_SERVER}/${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}"
        export JDBC_STAT_URL="jdbc:mariadb://${GOVWAY_STAT_DB_SERVER}/${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}"

    ;;

    oracle)
        # JDBC URLS
        export JDBC_CONF_URL="jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_CONF_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}"
        export JDBC_TRAC_URL="jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_TRAC_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}"
        export JDBC_STAT_URL="jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_STAT_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}"

    ;;
    sqlserver)
        # JDBC URLS
        export JDBC_CONF_URL="jdbc:sqlserver://${GOVWAY_CONF_DB_SERVER};databaseName=${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}"
        export JDBC_TRAC_URL="jdbc:sqlserver://${GOVWAY_TRAC_DB_SERVER};databaseName=${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}"
        export JDBC_STAT_URL="jdbc:sqlserver://${GOVWAY_STAT_DB_SERVER};databaseName=${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}"

    ;;
    esac


;;
hsql)
#     export GOVWAY_DRIVER_JDBC="/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar"
#     export GOVWAY_DS_DRIVER_CLASS='org.hsqldb.jdbc.JDBCDriver'
#     export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT * FROM (VALUES(1));'
#     # JDBC URLS
#     export JDBC_STAT_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
#     export JDBC_TRAC_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
#     export JDBC_STAT_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
    # Default basati su tipo archivi
    echo "FATAL: Per il database hsql viene supportata solamente l'immagine standalone; non vengono supportate le immagini '*_run', '*_manager' e '*_batch'"
    exit 1
;;
*) 
    echo "FATAL: Sanity check variabili ... fallito."
    echo "FATAL: la variabile GOVWAY_DB_TYPE non è valida: '${GOVWAY_DB_TYPE}'"
    echo ""
    exit 1;
;;
esac



# Configurazione 
export GOVWAY_BATCH_STATISTICHE="${GOVWAY_BATCH_HOME}/generatoreStatistiche"
export BATCH_CLASSPATH="${GOVWAY_BATCH_STATISTICHE}/lib"
export BATCH_CONFIG='/tmp/runtime_properties'
export BATCH_JDBC="${GOVWAY_DS_JDBC_LIBS}"




mkdir -p "${BATCH_CONFIG}"
cp ${GOVWAY_BATCH_STATISTICHE}/properties/* "${BATCH_CONFIG}"


if [ "${GOVWAY_DB_TYPE}" == 'mariadb' ]
then
    DB_TIPODATABASE=mysql
else
    DB_TIPODATABASE="${GOVWAY_DB_TYPE}"
fi

cat - << EOPROP > "${BATCH_CONFIG}/daoFactory.properties"
db.showSql=true
db.secondsToRefreshConnection=300
db.tipo=connection

# DB config
db.tipoDatabase=${DB_TIPODATABASE}				
db.connection.driver=${GOVWAY_DS_DRIVER_CLASS}				
db.connection.url=${JDBC_CONF_URL}				
db.connection.user=${GOVWAY_CONF_DB_USER}			
db.connection.password=${GOVWAY_CONF_DB_PASSWORD}				
# DB tracciamento
factory.transazioni.db.connection.url=${JDBC_TRAC_URL}
factory.transazioni.db.connection.user=${GOVWAY_TRAC_DB_USER}
factory.transazioni.db.connection.password=${GOVWAY_TRAC_DB_PASSWORD}
# DB statistiche
factory.statistiche.db.connection.url=${JDBC_STAT_URL}
factory.statistiche.db.connection.user=${GOVWAY_STAT_DB_USER}
factory.statistiche.db.connection.password=${GOVWAY_STAT_DB_PASSWORD}
EOPROP



### MAIN ####

# Aggiungo un javaagent all'avvio
if [ -f "${GOVWAY_JVM_AGENT_JAR}" ]
then
    echo "INFO: Carico all'avvio l'agent: [${GOVWAY_JVM_AGENT_JAR}]"
    export JAVA_TOOL_OPTIONS="-javaagent:${GOVWAY_JVM_AGENT_JAR}"
elif [ -n "${GOVWAY_JVM_AGENT_JAR}" ]
then
    echo "WARN: Impossibile caricare all'avvio l'agent: [${GOVWAY_JVM_AGENT_JAR}]"
    echo "WARN: Verificare che il path indicato sia corretto e leggibile dall'utente $(id -u -n)"
fi

# Configurazione memoria JVM per batch
DEFAULT_MAX_RAM_PERCENTAGE=80
JVM_MEMORY_OPTS="-XX:MaxRAMPercentage=${GOVWAY_JVM_MAX_RAM_PERCENTAGE:-${DEFAULT_MAX_RAM_PERCENTAGE}}"
[ -n "${GOVWAY_JVM_INITIAL_RAM_PERCENTAGE}" ] && JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS -XX:InitialRAMPercentage=${GOVWAY_JVM_INITIAL_RAM_PERCENTAGE}"
[ -n "${GOVWAY_JVM_MIN_RAM_PERCENTAGE}" ] && JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS -XX:MinRAMPercentage=${GOVWAY_JVM_MIN_RAM_PERCENTAGE}"
[ -n "${GOVWAY_JVM_MAX_METASPACE_SIZE}" ] && JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS -XX:MaxMetaspaceSize=${GOVWAY_JVM_MAX_METASPACE_SIZE}"
[ -n "${GOVWAY_JVM_MAX_DIRECT_MEMORY_SIZE}" ] && JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS -XX:MaxDirectMemorySize=${GOVWAY_JVM_MAX_DIRECT_MEMORY_SIZE}"

export JAVA_OPTS="${JAVA_OPTS:-} $JVM_MEMORY_OPTS"

# Imposto Timezone
[ -z "${TZ}" ] && export TZ="Europe/Rome"

if [ "${GOVWAY_BATCH_USA_CRON,,}" == 'yes' -o "${GOVWAY_BATCH_USA_CRON,,}" == 'si' -o "${GOVWAY_BATCH_USA_CRON,,}" == '1' -o "${GOVWAY_BATCH_USA_CRON,,}" == 'true' ]
then
    # NOTA: la schedulazione non usa più dcron: dcron esegue ogni job con una
    # setuid/initgroups verso l'utente proprietario della crontab, operazione
    # privilegiata che fallisce se il processo non gira come root (anche
    # quando l'utente target coincide con quello già in esecuzione). Dato che
    # qui serve solo rilanciare lo stesso comando ad intervallo fisso, un
    # semplice loop nello stesso processo bash evita del tutto il problema.
    echo "INFO: Schedulo generazione  ${TIPO} ogni ${INTERVALLO_SCHEDULAZIONE} minuti."
    INTERVALLO_SECONDI=$(( INTERVALLO_SCHEDULAZIONE * 60 ))

    # Abilito il job control: ogni comando avviato in background ottiene un
    # proprio process group, cosi' il segnale di stop puo' essere propagato
    # all'intero albero del job (script + java) e non al solo wrapper.
    set -m
    CHILD_PID=""
    termina() {
        echo "INFO: Ricevuto segnale di stop, termino."
        if [ -n "${CHILD_PID}" ]
        then
            kill -TERM -"${CHILD_PID}" 2>/dev/null || kill -TERM "${CHILD_PID}" 2>/dev/null
            wait "${CHILD_PID}" 2>/dev/null
        fi
        exit 0
    }
    trap termina TERM INT

    while true
    do
        ${GOVWAY_BATCH_HOME}/crond/govway_batch.sh ${GOVWAY_BATCH_HOME}/generatoreStatistiche ${COMANDO} false &
        CHILD_PID=$!
        wait "${CHILD_PID}"
        CHILD_PID=""
        # Allineo la prossima esecuzione al prossimo multiplo dell'intervallo
        # dall'epoch (equivalente a "*/N * * * *" di cron), cosi' la
        # schedulazione non deriva nel tempo in base alla durata del job.
        SLEEP_SECONDI=$(( INTERVALLO_SECONDI - ( $(date +%s) % INTERVALLO_SECONDI ) ))
        sleep "${SLEEP_SECONDI}" &
        CHILD_PID=$!
        wait "${CHILD_PID}"
        CHILD_PID=""
    done
else
    echo "INFO: Generazione ${TIPO} avviata..."
    ${GOVWAY_BATCH_HOME}/crond/govway_batch.sh ${GOVWAY_BATCH_HOME}/generatoreStatistiche ${COMANDO} false
    echo "INFO: Generazione ${TIPO} completata."
fi


