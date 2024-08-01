#!/bin/bash

exec 6<> /tmp/entrypoint_debug.log
exec 2>&6
set -x

## Const
GOVWAY_STARTUP_CHECK_SKIP=${GOVWAY_STARTUP_CHECK_SKIP:=FALSE}
GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME=${GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME:=20}
GOVWAY_STARTUP_CHECK_SLEEP_TIME=${GOVWAY_STARTUP_CHECK_SLEEP_TIME:=5}
GOVWAY_STARTUP_CHECK_MAX_RETRY=${GOVWAY_STARTUP_CHECK_MAX_RETRY:=60}
declare -r GOVWAY_STARTUP_CHECK_REGEX='GovWay/?.* \(www.govway.org\) avviata correttamente in .* secondi'
declare -r GOVWAY_STARTUP_ENTITY_REGEX=^[0-9A-Za-z][\-A-Za-z0-9]*$



declare -r JVM_PROPERTIES_FILE='/etc/govway_as_jvm.properties'
declare -r JVM_PROPERTIES_FILE_DEPRECATO='/etc/wildfly/wildfly.properties'
declare -r ENTRYPOINT_D='/docker-entrypoint-govway.d/'
declare -r CUSTOM_INIT_FILE="${CATALINA_HOME}/conf/custom_govway_as_init"
declare -r MODULE_INIT_FILE="${CATALINA_HOME}/conf/fix_module_init"
declare -r CONNETTORI_INIT_FILE="${CATALINA_HOME}/conf/fix_connettori_init"

if [[ ! "${GOVWAY_DEFAULT_ENTITY_NAME}" =~ ${GOVWAY_STARTUP_ENTITY_REGEX} ]]
then
        
    echo "FATAL: Sanity check variabili ... fallito."
    if [ -z "${GOVWAY_DEFAULT_ENTITY_NAME}" ]
    then
        echo "FATAL: La variabile obbligatoria GOVWAY_DEFAULT_ENTITY_NAME non è stata definita"
    else
        echo "FATAL: GOVWAY_DEFAULT_ENTITY_NAME può iniziare solo con un carattere o cifra [0-9A-Za-z] e dev'essere formato solo da caratteri, cifre e '-'"
    fi
    exit 0
fi


#
# Comandi di avvio
#
if [ -n "$1" ]
then
    if [ "$1" = "initsql" ]
    then
        /usr/local/bin/initsql.sh || echo "FATAL: Scripts sql non inizializzati."
        exit $?
    fi
fi


case "${GOVWAY_DB_TYPE:-hsql}" in
mysql|mariadb|postgresql|oracle)

    #
    # Sanity check variabili minime attese
    #
    if [ -n "${GOVWAY_DB_SERVER}" -a -n  "${GOVWAY_DB_USER}"  -a -n "${GOVWAY_DB_NAME}" ] 
    then
            [ -n "${GOVWAY_DB_PASSWORD}" ] || echo "WARN: La variabile GOVWAY_DB_PASSWORD non è stata impostata."
            echo "INFO: Sanity check variabili ... ok."
    else
        echo "FATAL: Sanity check variabili ... fallito."
        echo "FATAL: Devono essere settate almeno le seguenti variabili obbligatorie:
GOVWAY_DB_SERVER: ${GOVWAY_DB_SERVER}
GOVWAY_DB_NAME: ${GOVWAY_DB_NAME}
GOVWAY_DB_USER: ${GOVWAY_DB_USER}
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

    case "${GOVWAY_DB_TYPE:-hsql}" in
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
        else
            GOVWAY_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
        fi
        if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]
        then
            GOVWAY_CONF_DS_CONN_PARAM="${GOVWAY_CONF_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        else
            GOVWAY_CONF_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
        fi
        if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]
        then
            GOVWAY_TRAC_DS_CONN_PARAM="${GOVWAY_TRAC_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        else
            GOVWAY_TRAC_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
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
        else
            GOVWAY_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
        fi
        if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]
        then
            GOVWAY_CONF_DS_CONN_PARAM="${GOVWAY_CONF_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        else
            GOVWAY_CONF_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
        fi
        if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]
        then
            GOVWAY_TRAC_DS_CONN_PARAM="${GOVWAY_TRAC_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        else
            GOVWAY_TRAC_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
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
                #export GOVWAY_DRIVER_JDBC="${GOVWAY_DS_JDBC_LIBS}"
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
            echo "FATAL: Sanity check JDBC ... fallito."
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
    esac

;;
hsql|*)
    #GOVWAY_DRIVER_JDBC="/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar"
    export GOVWAY_DS_JDBC_LIBS="/tmp/hsql-jdbc"
    mkdir /tmp/hsql-jdbc
    /bin/cp -f "/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar" ${GOVWAY_DS_JDBC_LIBS}

    
    export GOVWAY_DS_DRIVER_CLASS='org.hsqldb.jdbc.JDBCDriver'
    export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT * FROM (VALUES(1));'

    export GOVWAY_DB_USER=govway
    export GOVWAY_DB_NAME=govway
    export GOVWAY_DB_PASSWORD=govway
;;
esac


# Setting valori di Default per i datasource GOVWAY
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


[ -n "${GOVWAY_CONF_ORACLE_JDBC_URL_TYPE}" ] || export GOVWAY_CONF_ORACLE_JDBC_URL_TYPE="${GOVWAY_ORACLE_JDBC_URL_TYPE}"
[ -n "${GOVWAY_TRAC_ORACLE_JDBC_URL_TYPE}" ] || export GOVWAY_TRAC_ORACLE_JDBC_URL_TYPE="${GOVWAY_ORACLE_JDBC_URL_TYPE}"
[ -n "${GOVWAY_STAT_ORACLE_JDBC_URL_TYPE}" ] || export GOVWAY_STAT_ORACLE_JDBC_URL_TYPE="${GOVWAY_ORACLE_JDBC_URL_TYPE}"

# Settaggio Valori per i parametri dei datasource GOVWAY
## Prepared statement cache size (default 20)
# [ -n "${GOVWAY_CONF_DS_PSCACHESIZE}" ] || export GOVWAY_CONF_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}" 
# [ -n "${GOVWAY_TRAC_DS_PSCACHESIZE}" ] || export GOVWAY_TRAC_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}" 
# [ -n "${GOVWAY_STAT_DS_PSCACHESIZE}" ] || export GOVWAY_STAT_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}"

## parametri di connessione URL JDBC (default vuoto)
if [ -n "${GOVWAY_DS_CONN_PARAM}" ]; then export DATASOURCE_CONN_PARAM="?${GOVWAY_DS_CONN_PARAM}"; else export DATASOURCE_CONN_PARAM=""; fi
if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]; then export DATASOURCE_CONF_CONN_PARAM="?${GOVWAY_CONF_DS_CONN_PARAM}"; else export DATASOURCE_CONF_CONN_PARAM="${DATASOURCE_CONN_PARAM}"; fi
if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]; then export DATASOURCE_TRAC_CONN_PARAM="?${GOVWAY_TRAC_DS_CONN_PARAM}"; else export DATASOURCE_TRAC_CONN_PARAM="${DATASOURCE_CONN_PARAM}"; fi
if [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ]; then export DATASOURCE_STAT_CONN_PARAM="?${GOVWAY_STAT_DS_CONN_PARAM}"; else export DATASOURCE_STAT_CONN_PARAM="${DATASOURCE_CONN_PARAM}"; fi

## Idle timeout (default 5 min)
# [ -n "${GOVWAY_CONF_DS_IDLE_TIMEOUT}" ] || export GOVWAY_CONF_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}" 
# [ -n "${GOVWAY_TRAC_DS_IDLE_TIMEOUT}" ] || export GOVWAY_TRAC_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}" 
# [ -n "${GOVWAY_STAT_DS_IDLE_TIMEOUT}" ] || export GOVWAY_STAT_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}"

## blocking timeout (default 30000 ms)
# [ -n "${GOVWAY_CONF_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_CONF_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}" 
# [ -n "${GOVWAY_TRAC_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_TRAC_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}" 
# [ -n "${GOVWAY_STAT_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_STAT_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}"


## Pooling
export GOVWAY_MAX_POOL=${GOVWAY_MAX_POOL:-50}
export GOVWAY_MIN_POOL=${GOVWAY_MIN_POOL:-2}
export GOVWAY_INITIALSIZE_POOL=${GOVWAY_INITIALSIZE_POOL:-${GOVWAY_MIN_POOL}}
export GOVWAY_MINIDLE_POOL=${GOVWAY_MINIDLE_POOL:-${GOVWAY_MIN_POOL}}
export GOVWAY_MAXIDLE_POOL=${GOVWAY_MAXIDLE_POOL:-${GOVWAY_MAX_POOL}}

export GOVWAY_CONF_MAX_POOL=${GOVWAY_CONF_MAX_POOL:-10}
export GOVWAY_CONF_MIN_POOL=${GOVWAY_CONF_MIN_POOL:-2}
export GOVWAY_CONF_INITIALSIZE_POOL=${GOVWAY_CONF_INITIALSIZE_POOL:-${GOVWAY_CONF_MIN_POOL}}
export GOVWAY_CONF_MINIDLE_POOL=${GOVWAY_CONF_MINIDLE_POOL:-${GOVWAY_CONF_MIN_POOL}}
export GOVWAY_CONF_MAXIDLE_POOL=${GOVWAY_CONF_MAXIDLE_POOL:-${GOVWAY_CONF_MAX_POOL}}

export GOVWAY_TRAC_MAX_POOL=${GOVWAY_TRAC_MAX_POOL:-50}
export GOVWAY_TRAC_MIN_POOL=${GOVWAY_TRAC_MIN_POOL:-2}
export GOVWAY_TRAC_INITIALSIZE_POOL=${GOVWAY_TRAC_INITIALSIZE_POOL:-${GOVWAY_TRAC_MIN_POOL}}
export GOVWAY_TRAC_MINIDLE_POOL=${GOVWAY_TRAC_MINIDLE_POOL:-${GOVWAY_TRAC_MIN_POOL}}
export GOVWAY_TRAC_MAXIDLE_POOL=${GOVWAY_TRAC_MAXIDLE_POOL:-${GOVWAY_TRAC_MAX_POOL}}

export GOVWAY_STAT_MAX_POOL=${GOVWAY_STAT_MAX_POOL:-5}
export GOVWAY_STAT_MIN_POOL=${GOVWAY_STAT_MIN_POOL:-1}
export GOVWAY_STAT_INITIALSIZE_POOL=${GOVWAY_STAT_INITIALSIZE_POOL:-${GOVWAY_STAT_MIN_POOL}}
export GOVWAY_STAT_MINIDLE_POOL=${GOVWAY_STAT_MINIDLE_POOL:-${GOVWAY_STAT_MIN_POOL}}
export GOVWAY_STAT_MAXIDLE_POOL=${GOVWAY_STAT_MAXIDLE_POOL:-${GOVWAY_STAT_MAX_POOL}}



# Recupero l'indirizzo ip usato dal container (utilizzato dalle funzionalita di clustering / orchestration)
export GW_IPADDRESS=$(grep -E "[[:space:]]${HOSTNAME}[[:space:]]*" /etc/hosts|head -n 1|awk '{print $1}')

#
# Startup
#

# Impostazione Dinamica dei limiti di memoria per container
if [ ${GOVWAY_ARCHIVES_TYPE} == "manager" -o ${GOVWAY_ARCHIVES_TYPE} == "all" ]
then 
    export JAVA_OPTS="$JAVA_OPTS -XX:MaxRAMPercentage=50"
else
    export JAVA_OPTS="$JAVA_OPTS -XX:MaxRAMPercentage=${MAX_JVM_PERC:-80}"
fi


# Inizializzazione del database
/usr/local/bin/initsql.sh || { echo "FATAL: Scripts sql non inizializzati."; exit 1; }
/usr/local/bin/initgovway.sh || { echo "FATAL: Database non inizializzato."; exit 1; }

# Eventuali inizializzazioni custom 
if [ ! -f "${MODULE_INIT_FILE}" ]
then

    if [ -n "${GOVWAY_DS_JDBC_LIBS}" ]
    then

        declare -a lista_jar=( ${GOVWAY_DS_JDBC_LIBS}/*.jar )
        if [ ${#lista_jar[@]} -eq 1 -a "${lista_jar[0]}" == "${GOVWAY_DS_JDBC_LIBS}/*.jar" ]
        then
            echo "FATAL: Sanity check JDBC ... fallito"
            echo "FATAL: Nessuna libreria JDBC è presente in ${GOVWAY_DS_JDBC_LIBS}."
            exit 1
        fi

        /bin/cp -f ${lista_jar[@]} ${CATALINA_HOME}/lib

    fi

    touch "${MODULE_INIT_FILE}"
fi
if [ ! -f "${CONNETTORI_INIT_FILE}" ]
then
    # Riconversione variabili con il carattere '-' nel nome
    for e in $(env | grep 'MAX-' ); do varname="${e%=*}"; varval="${e#*=}"; eval  "export ${varname//-/_}=\"${varval}\""; done

    # Mantenimento delle variabili precedenti per compatibilita
    [ -n "${WILDFLY_AJP_LISTENER^^}" -a -z "${GOVWAY_AS_AJP_LISTENER}" ] && { echo "WARN: LA variabile WILDFLY_AJP_LISTENER è stata deprecata in favore di GOVWAY_AS_AJP_LISTENER."; export GOVWAY_AS_AJP_LISTENER="${WILDFLY_AJP_LISTENER}"; }
    [ -n "${WILDFLY_HTTP_LISTENER^^}" -a -z "${GOVWAY_AS_HTTP_LISTENER}" ] && { echo "WARN: LA variabile WILDFLY_HTTP_LISTENER è stata deprecata in favore di GOVWAY_AS_HTTP_LISTENER."; export GOVWAY_AS_HTTP_LISTENER="${WILDFLY_HTTP_LISTENER}"; }

    [ -n "${WILDFLY_HTTP_IN_WORKER_MAX_THREADS}" -a -z "${GOVWAY_AS_HTTP_IN_WORKER_MAX_THREADS}" ] && { echo "WARN: LA variabile WILDFLY_HTTP_IN_WORKER-MAX-THREADS è stata deprecata in favore di GOVWAY_AS_HTTP_IN_WORKER_MAX_THREADS."; export GOVWAY_AS_HTTP_IN_WORKER_MAX_THREADS="${WILDFLY_HTTP_IN_WORKER_MAX_THREADS}"; }
    [ -n "${WILDFLY_HTTP_OUT_WORKER_MAX_THREADS}" -a -z "${GOVWAY_AS_HTTP_OUT_WORKER_MAX_THREADS}" ] && { echo "WARN: LA variabile WILDFLY_HTTP_OUT_WORKER-MAX-THREADS è stata deprecata in favore di GOVWAY_AS_HTTP_OUT_WORKER_MAX_THREADS."; export GOVWAY_AS_HTTP_OUT_WORKER_MAX_THREADS="${WILDFLY_HTTP_OUT_WORKER_MAX_THREADS}"; }
    [ -n "${WILDFLY_HTTP_GEST_WORKER_MAX_THREADS}" -a -z "${GOVWAY_AS_HTTP_GEST_WORKER_MAX_THREADS}" ] && { echo "WARN: LA variabile WILDFLY_HTTP_GEST_WORKER-MAX-THREADS è stata deprecata in favore di GOVWAY_AS_HTTP_GEST_WORKER_MAX_THREADS."; export GOVWAY_AS_HTTP_GEST_WORKER_MAX_THREADS="${WILDFLY_HTTP_GEST_WORKER_MAX_THREADS}"; }
    [ -n "${WILDFLY_AJP_IN_WORKER_MAX_THREADS}" -a -z "${GOVWAY_AS_AJP_IN_WORKER_MAX_THREADS}" ] && { echo "WARN: LA variabile WILDFLY_AJP_IN_WORKER-MAX-THREADS è stata deprecata in favore di GOVWAY_AS_AJP_IN_WORKER_MAX_THREADS."; export GOVWAY_AS_AJP_IN_WORKER_MAX_THREADS="${WILDFLY_AJP_IN_WORKER_MAX_THREADS}"; }
    [ -n "${WILDFLY_AJP_OUT_WORKER_MAX_THREADS}" -a -z "${GOVWAY_AS_AJP_OUT_WORKER_MAX_THREADS}" ] && { echo "WARN: LA variabile WILDFLY_AJP_OUT_WORKER-MAX-THREADS è stata deprecata in favore di GOVWAY_AS_AJP_OUT_WORKER_MAX_THREADS."; export GOVWAY_AS_AJP_OUT_WORKER_MAX_THREADS="${WILDFLY_AJP_OUT_WORKER_MAX_THREADS}"; }
    [ -n "${WILDFLY_AJP_GEST_WORKER_MAX_THREADS}" -a -z "${GOVWAY_AS_AJP_GEST_WORKER_MAX_THREADS}" ] && { echo "WARN: LA variabile WILDFLY_AJP_GEST_WORKER-MAX-THREADS è stata deprecata in favore di GOVWAY_AS_AJP_GEST_WORKER_MAX_THREADS."; export GOVWAY_AS_AJP_GEST_WORKER_MAX_THREADS="${WILDFLY_AJP_GEST_WORKER_MAXTHREADS}"; }
    [ -n "${WILDFLY_MAX_POST_SIZE}" -a -z "${GOVWAY_AS_MAX_POST_SIZE}" ] && { echo "WARN: LA variabile WILDFLY_MAX-POST-SIZE è stata deprecata in favore di GOVWAY_AS_MAX_POST_SIZE."; export GOVWAY_AS_MAX_POST_SIZE="${WILDFLY_MAX_POST_SIZE}"; }

    [ "${GOVWAY_AS_AJP_LISTENER^^}" == 'FALSE' -a "${GOVWAY_AS_HTTP_LISTENER^^}" == 'FALSE' ] && echo "WARN: Tutti i connettori verranno disabilitati. Non sarà più possibile accedere ai servizi"

    if [ "${GOVWAY_AS_AJP_LISTENER^^}" == 'TRUE' ]
    then
        cat - << EOCLI > /tmp/__fix_connettori.cli
/Server/Executor:add name=ajp-out-worker, namePrefix=ajp-out-worker-, maxThreads=\${GOVWAY_AS_AJP_OUT_WORKER_MAX_THREADS:-100}\n\
/Server/Service/Connector:add port=8009, protocol=AJP/1.3, redirectPort=8443, executor=ajp-out-worker, maxPostSize=\${GOVWAY_AS_MAX_POST_SIZE:-10485760}, secretRequired=\${GOVWAY_AS_AJP_SECRET:-false}\n\
/Server/Executor:add name=ajp-gest-worker, namePrefix=ajp-gest-worker-, maxThreads=\${GOVWAY_AS_AJP_GEST_WORKER_MAX_THREADS:20}\n\
/Server/Service/Connector:add port=8009, protocol=AJP/1.3, redirectPort=8443, executor=ajp-out-worker, maxPostSize=\${GOVWAY_AS_MAX_POST_SIZE:-10485760}, secretRequired=\${GOVWAY_AS_AJP_SECRET:-false}\n\
EOCLI
    elif  [ "${GOVWAY_AS_AJP_LISTENER^^}" == 'FALSE' ]
    then
        # Elimino il connettore AJP solo se esplicitmante richiesto
        # per mantenere la compatibilità con le immagini preesistenti che
        #   lo avevano attivo all'avvio comunque
        cat - << EOCLI > /tmp/__fix_connettori.cli
/Server/Service/Connector[@port="8009"]:delete
/Server/Executor[@name="ajp-worker"]:delete
EOCLI
    elif [ "${GOVWAY_AS_AJP_LISTENER^^}" == 'AJP-8009' ]
    then
        # Si tratta della configurazione standard ed è equivalente a non specificare GOVWAY_AS_AJP_LISTENER
        # non faccio nulla
        true
    fi


    # I connettori HTTP sono abilitati per default a meno che non siano esplicitamente disabilitati
    if [ "${GOVWAY_AS_HTTP_LISTENER^^}" == 'FALSE' ]
    then      
        cat - << EOCLI >> /tmp/__fix_connettori.cli
/Server/Service/Connector[@port="8080"]:delete
/Server/Service/Connector[@port="8081"]:delete
/Server/Service/Connector[@port="8082"]:delete
/Server/Executor[@name="http-in-worker"]:delete
/Server/Executor[@name="http-out-worker"]:delete
/Server/Executor[@name="http-gest-worker"]:delete
EOCLI
    elif [ "${GOVWAY_AS_HTTP_LISTENER^^}" == 'TRUE' ]
    then
        # Si tratta della configurazione standard ed è equivalente a non specificare GOVWAY_AS_HTTP_LISTENER
        # non faccio nulla
        true
    elif [ "${GOVWAY_AS_HTTP_LISTENER^^}" == 'HTTP-8080' ]
    then
        cat - << EOCLI >> /tmp/__fix_connettori.cli
echo "Elimino Worker e Listener http"
/Server/Service/Connector[@port="8081"]:delete
/Server/Service/Connector[@port="8082"]:delete
/Server/Executor[@name="http-out-worker"]:delete
/Server/Executor[@name="http-gest-worker"]:delete
EOCLI

    fi

    [ -f /tmp/__fix_connettori.cli ] && /usr/local/bin/tomcat-cli.sh "/tmp/__fix_connettori.cli"
    touch "${CONNETTORI_INIT_FILE}"
fi

if [ -d "${ENTRYPOINT_D}" -a ! -f ${CUSTOM_INIT_FILE} ]
then
    local f
	for f in ${ENTRYPOINT_D}/*
    do
		case "$f" in
			*.sh)
				if [ -x "$f" ]; then
					echo "INFO: Customizzazioni ... eseguo $f"
					"$f"
				else
					echo "INFO: Customizzazioni ... importo $f"
					. "$f"
				fi
				;;
			*.cli)
				echo "INFO: Customizzazioni ... eseguo $f"; 
			    /usr/localbin/bin/tomcat-cli.sh "$f"
				;;
			*)  
                echo "INFO: Customizzazioni ... IGNORO $f"
                ;;
		esac
		echo
	done
    touch ${CUSTOM_INIT_FILE}
fi

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

# Azzero un'eventuale log di startup precedente (utile in caso di restart)
> ${GOVWAY_LOGDIR}/govway_startup.log
rm -rf ${CATALINA_HOME}/work/Catalina/

# Forzo file di un eventuale file di properties jvm da passare all'avvio
if [ -f "${JVM_PROPERTIES_FILE}" -o -f "${JVM_PROPERTIES_FILE_DEPRECATO}" ]
then
    if ! grep -q "#PROPRIETA CUSTOM GOVWAY#"  "${CATALINA_HOME}/conf/catalina.properties" 
    then 
        GOVWAY_AS_PROP_FILE="${JVM_PROPERTIES_FILE}"
        [ ! -f "${JVM_PROPERTIES_FILE}" -a -f "${JVM_PROPERTIES_FILE_DEPRECATO}" ] && GOVWAY_AS_PROP_FILE="${JVM_PROPERTIES_FILE_DEPRECATO}"
        echo >> "${CATALINA_HOME}/conf/catalina.properties"
        echo "#PROPRIETA CUSTOM GOVWAY#" >> "${CATALINA_HOME}/conf/catalina.properties" 
        cat "${GOVWAY_AS_PROP_FILE}" >> "${CATALINA_HOME}/conf/catalina.properties"
    fi
fi

export UMASK=0022
${CATALINA_HOME}/bin/catalina.sh run &


PID=$!
trap "kill -TERM $PID; export NUM_RETRY=${GOVWAY_STARTUP_CHECK_MAX_RETRY};" TERM INT


if [ "${GOVWAY_STARTUP_CHECK_SKIP^^}" == "FALSE" ]
then

	/bin/rm -f  /tmp/govway_ready
	echo "INFO: Avvio di GovWay ... attendo"
	sleep ${GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME}s
	GOVWAY_READY=1
	NUM_RETRY=0
	while [ ${GOVWAY_READY} -ne 0 -a ${NUM_RETRY} -lt ${GOVWAY_STARTUP_CHECK_MAX_RETRY} ]
	do
        if [ ${GOVWAY_ARCHIVES_TYPE} == 'manager' ]
        then
            [ -e "${CATALINA_HOME}/work/Catalina/localhost/govwayConsole" ]
        else
		    grep -qE "${GOVWAY_STARTUP_CHECK_REGEX}" ${GOVWAY_LOGDIR}/govway_startup.log  2> /dev/null
        fi
		GOVWAY_READY=$?
		NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
		if [  ${GOVWAY_READY} -ne 0 ]
        then
			echo "INFO: Avvio di GovWay ... attendo"
			sleep ${GOVWAY_STARTUP_CHECK_SLEEP_TIME}s
		fi
	done

	if [ ${NUM_RETRY} -eq ${GOVWAY_STARTUP_CHECK_MAX_RETRY} ]
	then
		echo "FATAL: Avvio di GovWay ... NON avviato dopo $((${GOVWAY_STARTUP_CHECK_SLEEP_TIME=} * ${GOVWAY_STARTUP_CHECK_MAX_RETRY})) secondi"
		kill -15 ${PID}
	else
		touch /tmp/govway_ready
		echo "INFO: Avvio di Govway ... GovWay avviato"
	fi
else
		touch /tmp/govway_ready
fi



wait $PID
wait $PID
EXIT_STATUS=$?

echo "INFO: GovWay arrestato"
exec 6>&-

exit $EXIT_STATUS
