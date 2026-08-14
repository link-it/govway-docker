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
declare -r ENTRYPOINT_D_DEPRECATO='/docker-entrypoint-widlflycli.d/'
declare -r CUSTOM_INIT_FILE="${CATALINA_HOME}/conf/custom_govway_as_init"
declare -r MODULE_INIT_FILE="${CATALINA_HOME}/conf/fix_module_init"
declare -r CONNETTORI_INIT_FILE="${CATALINA_HOME}/conf/fix_connettori_init"
declare -r DATASOURCE_INIT_FILE="${CATALINA_HOME}/conf/fix_datasource_init"
declare -r HTTPS_INIT_FILE="${CATALINA_HOME}/conf/fix_https_init"
declare -r HTTPS_CLI_FILE='/tmp/__fix_https_connettori.cli'

if [[ ! "${GOVWAY_DEFAULT_ENTITY_NAME}" =~ ${GOVWAY_STARTUP_ENTITY_REGEX} ]]
then

    echo "FATAL: Sanity check variabili ... fallito."
    if [ -z "${GOVWAY_DEFAULT_ENTITY_NAME}" ]
    then
        echo "FATAL: La variabile obbligatoria GOVWAY_DEFAULT_ENTITY_NAME non è stata definita"
    else
        echo "FATAL: GOVWAY_DEFAULT_ENTITY_NAME può iniziare solo con un carattere o cifra [0-9A-Za-z] e dev'essere formato solo da caratteri, cifre e '-'"
    fi
    exit 1
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


case "${GOVWAY_DB_TYPE}" in
mysql|mariadb|postgresql|oracle|sqlserver)

    #
    # Sanity check variabili minime attese
    #
    if [ -n "${GOVWAY_DB_SERVER}" -a -n  "${GOVWAY_DB_USER}"  -a -n "${GOVWAY_DB_NAME}" ] 
    then
            [ -n "${GOVWAY_DB_PASSWORD}" ] || echo "WARN: La variabile GOVWAY_DB_PASSWORD non è stata impostata."
            echo "INFO: Sanity check variabili ... ok."
            echo "INFO: Tipo database configurato: ${GOVWAY_DB_TYPE}"
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
        else
            GOVWAY_DS_CONN_PARAM='zeroDateTimeBehavior=convertToNull'
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
        fi
        if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]
        then
            GOVWAY_TRAC_DS_CONN_PARAM="${GOVWAY_TRAC_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
        fi
        if [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ]
        then
            GOVWAY_STAT_DS_CONN_PARAM="${GOVWAY_STAT_DS_CONN_PARAM}&zeroDateTimeBehavior=convertToNull"
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
        else
            GOVWAY_DS_CONN_PARAM="${SQLSERVER_ENCRYPT_PARAMS}"
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
        fi

        export GOVWAY_DS_DRIVER_CLASS='com.microsoft.sqlserver.jdbc.SQLServerDriver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1'
    ;;
    esac

;;
hsql)
    echo "INFO: Tipo database configurato: ${GOVWAY_DB_TYPE}"
    
    # Default basati su tipo archivi
    if [ ${GOVWAY_ARCHIVES_TYPE} == "manager" -o ${GOVWAY_ARCHIVES_TYPE} == "runtime" ]; then
	echo "FATAL: Per il database hsql viene supportata solamente l'immagine standalone; non vengono supportate le immagini '*_run', '*_manager' e '*_batch'"
	exit 1
    fi
    
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
*)
    echo "FATAL: Sanity check variabili ... fallito."
    if [ -z "${GOVWAY_DB_TYPE}" ]
    then
        echo "FATAL: La variabile obbligatoria GOVWAY_DB_TYPE non è stata definita"
    else
        echo "FATAL: Valore non consentito per la variabile GOVWAY_DB_TYPE: [GOVWAY_DB_TYPE=${GOVWAY_DB_TYPE}]."
    fi
    echo "       Valori consentiti: [ hsql, mysql, mariadb, postgresql, oracle, sqlserver ]"
    exit 1
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

# Conversione separatore parametri per SQL Server (usa ; invece di ?)
if [ "${GOVWAY_DB_TYPE}" == 'sqlserver' ]; then
    if [ -n "${GOVWAY_DS_CONN_PARAM}" ]; then export DATASOURCE_CONN_PARAM=";${GOVWAY_DS_CONN_PARAM}"; else export DATASOURCE_CONN_PARAM=""; fi
    if [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ]; then export DATASOURCE_CONF_CONN_PARAM=";${GOVWAY_CONF_DS_CONN_PARAM}"; else export DATASOURCE_CONF_CONN_PARAM="${DATASOURCE_CONN_PARAM}"; fi
    if [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ]; then export DATASOURCE_TRAC_CONN_PARAM=";${GOVWAY_TRAC_DS_CONN_PARAM}"; else export DATASOURCE_TRAC_CONN_PARAM="${DATASOURCE_CONN_PARAM}"; fi
    if [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ]; then export DATASOURCE_STAT_CONN_PARAM=";${GOVWAY_STAT_DS_CONN_PARAM}"; else export DATASOURCE_STAT_CONN_PARAM="${DATASOURCE_CONN_PARAM}"; fi
fi

## Idle timeout (default 5 min)
# [ -n "${GOVWAY_CONF_DS_IDLE_TIMEOUT}" ] || export GOVWAY_CONF_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}" 
# [ -n "${GOVWAY_TRAC_DS_IDLE_TIMEOUT}" ] || export GOVWAY_TRAC_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}" 
# [ -n "${GOVWAY_STAT_DS_IDLE_TIMEOUT}" ] || export GOVWAY_STAT_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}"

## blocking timeout (default 30000 ms)
# [ -n "${GOVWAY_CONF_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_CONF_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}" 
# [ -n "${GOVWAY_TRAC_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_TRAC_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}" 
# [ -n "${GOVWAY_STAT_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_STAT_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}"


## Pooling
export GOVWAY_MAX_POOL=${GOVWAY_MAX_POOL:-10}
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
[ -z ${GOVWAY_SERVICE_PROTOCOL} ] && export GOVWAY_SERVICE_PROTOCOL=http
[ -z ${GOVWAY_SERVICE_HOST} ] && export GOVWAY_SERVICE_HOST=127.0.0.1
[ -z ${GOVWAY_SERVICE_PORT} ] && export GOVWAY_SERVICE_PORT=8082
#
# Startup
#

# Impostazione Dinamica dei limiti di memoria per container

# Backward compatibility: supporto MAX_JVM_PERC deprecato
if [ -n "${MAX_JVM_PERC}" ]; then
    echo "WARN: La variabile MAX_JVM_PERC è deprecata. Usare GOVWAY_JVM_MAX_RAM_PERCENTAGE"
    [ -z "${GOVWAY_JVM_MAX_RAM_PERCENTAGE}" ] && GOVWAY_JVM_MAX_RAM_PERCENTAGE="${MAX_JVM_PERC}"
fi

# Default basati su tipo archivi
if [ ${GOVWAY_ARCHIVES_TYPE} == "manager" -o ${GOVWAY_ARCHIVES_TYPE} == "all" ]; then
    DEFAULT_MAX_RAM_PERCENTAGE=50
else
    DEFAULT_MAX_RAM_PERCENTAGE=80
fi

# Costruzione parametri memoria JVM
JVM_MEMORY_OPTS="-XX:MaxRAMPercentage=${GOVWAY_JVM_MAX_RAM_PERCENTAGE:-${DEFAULT_MAX_RAM_PERCENTAGE}}"
[ -n "${GOVWAY_JVM_INITIAL_RAM_PERCENTAGE}" ] && JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS -XX:InitialRAMPercentage=${GOVWAY_JVM_INITIAL_RAM_PERCENTAGE}"
[ -n "${GOVWAY_JVM_MIN_RAM_PERCENTAGE}" ] && JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS -XX:MinRAMPercentage=${GOVWAY_JVM_MIN_RAM_PERCENTAGE}"
[ -n "${GOVWAY_JVM_MAX_METASPACE_SIZE}" ] && JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS -XX:MaxMetaspaceSize=${GOVWAY_JVM_MAX_METASPACE_SIZE}"
[ -n "${GOVWAY_JVM_MAX_DIRECT_MEMORY_SIZE}" ] && JVM_MEMORY_OPTS="$JVM_MEMORY_OPTS -XX:MaxDirectMemorySize=${GOVWAY_JVM_MAX_DIRECT_MEMORY_SIZE}"

export JAVA_OPTS="$JAVA_OPTS $JVM_MEMORY_OPTS"



# Inizializzazione del database
/usr/local/bin/initsql.sh nohelp || { echo "FATAL: Scripts sql non inizializzati."; exit 1; }
/usr/local/bin/initgovway.sh || { echo "FATAL: Database non inizializzato."; exit 1; }

# Configurazione Datasource a runtime
if [ ! -f "${DATASOURCE_INIT_FILE}" ]
then
    echo "INFO: Configurazione datasource ... in corso"
    /usr/local/bin/config_datasource.sh "/tmp/__datasource_configuration.cli"
    /usr/local/bin/tomcat-cli.sh "/tmp/__datasource_configuration.cli"
    echo "INFO: Configurazione datasource ... completata"
    touch "${DATASOURCE_INIT_FILE}"
fi

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

##########################################################################
# Configurazione HTTPS (erogazioni/fruizioni/gestione)
##########################################################################
if [ ! -f "${HTTPS_INIT_FILE}" ]
then

    govway_https_varname() {
        local base="$1" suffix="$2" suffixed="${1}_${2}"
        if [ -n "${!suffixed}" ]
        then
            echo "${suffixed}"
        else
            echo "${base}"
        fi
    }

    govway_https_emit() {
        printf '%s\n' "$1" >> "${HTTPS_CLI_FILE}"
    }

    govway_https_check_file() {
        # $1 = path da verificare in lettura, $2 = nome variabile per il messaggio di errore
        if [ -n "$1" ] && [ ! -r "$1" ]
        then
            echo "FATAL: Configurazione HTTPS ... il file indicato da $2 non è leggibile dall'utente $(id -u -n): [$1]"
            exit 1
        fi
    }

    govway_https_resolve_password() {
        # $1 = nome della variabile password già risolta per porta.
        # Se è impostata la variabile *_FILE la legge in un blocco senza xtrace e la esporta
        # con lo stesso nome, senza mai stampare il valore.
        local varname="$1" filevar="${1}_FILE"
        if [ -n "${!filevar}" ]
        then
            [ -n "${!varname}" ] && echo "WARN: Configurazione HTTPS ... sono state impostate sia ${varname} che ${filevar}; ha priorità ${filevar}."
            govway_https_check_file "${!filevar}" "${filevar}"
            { set +x; } 2>/dev/null
            local _v
            IFS= read -r _v < "${!filevar}"
            printf -v "${varname}" '%s' "${_v}"
            export "${varname}"
            set -x
        fi
    }

    govway_https_sniff_type() {
        case "${1,,}" in
            *.jks|*.keystore) echo JKS ;;
            *) echo PKCS12 ;;
        esac
    }

    govway_https_selfsigned() {
        # $1 = suffisso porta (EROGAZIONI|FRUIZIONI|GESTIONE), $2 = directory di output
        local suffix="$1" outdir="$2" cnvar sanvar validityvar cn san validity
        cnvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_CN "${suffix}")
        sanvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_SAN "${suffix}")
        validityvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_VALIDITY "${suffix}")
        cn="${!cnvar:-localhost}"
        san="${!sanvar:-DNS:localhost,DNS:$(hostname),IP:127.0.0.1}"
        validity="${!validityvar:-825}"

        mkdir -p "${outdir}"
        if [ ! -f "${outdir}/keystore.p12" ]
        then
            # -legacy: il default di OpenSSL 3.x (PBES2/PBKDF2/AES-256) non viene letto
            # correttamente da alcune combinazioni Tomcat/JSSE (fallisce con
            # "keystore password was incorrect" / BadPaddingException pur essendo il file
            # e la password corretti, verificabile con keytool). RC2/3DES legacy è compatibile.
            openssl req -x509 -newkey rsa:2048 -nodes \
                -keyout "${outdir}/key.pem" -out "${outdir}/cert.pem" \
                -days "${validity}" -subj "/CN=${cn}" \
                -addext "subjectAltName=${san}" \
                -addext "basicConstraints=critical,CA:FALSE" \
                -addext "keyUsage=digitalSignature,keyEncipherment" \
                -addext "extendedKeyUsage=serverAuth" \
            && GOVWAY_HTTPS_TMP_PASS='govway' openssl pkcs12 -export -legacy \
                -in "${outdir}/cert.pem" -inkey "${outdir}/key.pem" \
                -out "${outdir}/keystore.p12.tmp" -name govway \
                -passout env:GOVWAY_HTTPS_TMP_PASS \
            && mv -f "${outdir}/keystore.p12.tmp" "${outdir}/keystore.p12" \
            || { echo "FATAL: Configurazione HTTPS ... generazione del certificato self-signed fallita per ${suffix}."; exit 1; }
            rm -f "${outdir}/key.pem"
            echo "WARN: Configurazione HTTPS ... generato certificato self-signed per ${suffix} - USO ESCLUSIVAMENTE DI TEST: ${outdir}/cert.pem"
        fi
    }

    govway_https_ca_to_truststore() {
        # $1 = path del bundle PEM di CA, $2 = directory di output
        # NOTA: si usa keytool -importcert (un'invocazione per certificato), non
        # "openssl pkcs12 -export -nokeys": quest'ultimo produce un "Certificate bag"
        # che il PKCS12KeyStore di Java non riconosce come trusted-entry (KeyStore.load
        # riesce ma ks.size()==0, e SSLUtilBase.getTrustManagers fallisce poi con
        # "trustAnchors parameter must be non-empty") anche se il file è strutturalmente
        # valido e ispezionabile con openssl. keytool marca correttamente l'entry.
        # -J-Dkeystore.pkcs12.legacy: come per il keystore, il default moderno
        # (PBES2/AES-256) usato da keytool stesso non viene letto correttamente da
        # questa combinazione Tomcat/JDK; forza la cifratura legacy RC2/3DES.
        local cabundle="$1" outdir="$2" tmpdir i=0 certfile
        mkdir -p "${outdir}"
        if [ ! -f "${outdir}/truststore.p12" ]
        then
            tmpdir=$(mktemp -d)
            awk -v dir="${tmpdir}" '
                /-----BEGIN CERTIFICATE-----/ { n++; f = dir "/ca-" n ".pem" }
                f { print > f }
                /-----END CERTIFICATE-----/ { close(f); f = "" }
            ' "${cabundle}"
            GOVWAY_HTTPS_TMP_PASS='govway'
            export GOVWAY_HTTPS_TMP_PASS
            for certfile in "${tmpdir}"/ca-*.pem
            do
                [ -f "${certfile}" ] || continue
                i=$((i + 1))
                "${JAVA_HOME}/bin/keytool" -importcert -noprompt -J-Dkeystore.pkcs12.legacy \
                    -alias "ca-${i}" -file "${certfile}" \
                    -keystore "${outdir}/truststore.p12.tmp" -storetype PKCS12 \
                    -storepass:env GOVWAY_HTTPS_TMP_PASS \
                    > /dev/null \
                || { echo "FATAL: Configurazione HTTPS ... importazione del certificato CA #${i} nel truststore fallita."; rm -rf "${tmpdir}"; exit 1; }
            done
            unset GOVWAY_HTTPS_TMP_PASS
            rm -rf "${tmpdir}"
            if [ "${i}" -eq 0 ]
            then
                echo "FATAL: Configurazione HTTPS ... nessun certificato trovato in ${cabundle}."
                exit 1
            fi
            mv -f "${outdir}/truststore.p12.tmp" "${outdir}/truststore.p12"
        fi
    }

    govway_https_has_material() {
        local s v
        for s in "" _EROGAZIONI _FRUIZIONI _GESTIONE
        do
            v="GOVWAY_AS_HTTPS_CERTIFICATE${s}"; [ -n "${!v}" ] && return 0
            v="GOVWAY_AS_HTTPS_KEYSTORE${s}";    [ -n "${!v}" ] && return 0
        done
        return 1
    }

    # --- Risoluzione modalità di attivazione ---
    HTTPS_ENABLED=false
    HTTPS_ONLY_EROGAZIONI=false
    case "${GOVWAY_AS_HTTPS_LISTENER^^}" in
        FALSE)      HTTPS_ENABLED=false ;;
        TRUE)       HTTPS_ENABLED=true ;;
        HTTPS-8443) HTTPS_ENABLED=true; HTTPS_ONLY_EROGAZIONI=true ;;
        '')
            if govway_https_has_material
            then
                HTTPS_ENABLED=true
                echo "INFO: Configurazione HTTPS ... rilevato materiale crittografico, abilitazione automatica dei listener HTTPS."
            fi
            ;;
        *)
            echo "FATAL: Valore non consentito per la variabile GOVWAY_AS_HTTPS_LISTENER: [GOVWAY_AS_HTTPS_LISTENER=${GOVWAY_AS_HTTPS_LISTENER}]."
            echo "       Valori consentiti: [ true, false, https-8443 ]"
            exit 1
            ;;
    esac

    if [ "${HTTPS_ENABLED}" = true ]
    then
        echo "INFO: Configurazione HTTPS ... in corso"
        declare -A GOVWAY_HTTPS_DEFAULT_PORT=( [EROGAZIONI]=8443 [FRUIZIONI]=8444 [GESTIONE]=8445 )
        declare -A GOVWAY_HTTPS_EXECUTOR=( [EROGAZIONI]=https-in-worker [FRUIZIONI]=https-out-worker [GESTIONE]=https-gest-worker )
        declare -a GOVWAY_HTTPS_USED_PORTS=()

        for suffix in EROGAZIONI FRUIZIONI GESTIONE
        do
            [ "${HTTPS_ONLY_EROGAZIONI}" = true ] && [ "${suffix}" != EROGAZIONI ] && continue

            portvar=$(govway_https_varname GOVWAY_AS_HTTPS_PORT "${suffix}")
            port="${!portvar:-${GOVWAY_HTTPS_DEFAULT_PORT[${suffix}]}}"
            executor="${GOVWAY_HTTPS_EXECUTOR[${suffix}]}"

            case "${port}" in
                8080|8081|8082|8009)
                    echo "FATAL: Configurazione HTTPS ... la porta ${port} configurata per ${suffix} collide con un connettore HTTP/AJP esistente."
                    exit 1
                    ;;
            esac
            case " ${GOVWAY_HTTPS_USED_PORTS[*]} " in
                *" ${port} "*)
                    echo "FATAL: Configurazione HTTPS ... la porta ${port} è già utilizzata da un altro connettore HTTPS."
                    exit 1
                    ;;
            esac
            GOVWAY_HTTPS_USED_PORTS+=("${port}")

            certvar=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE "${suffix}")
            keyvar=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_KEY "${suffix}")
            chainvar=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_CHAIN "${suffix}")
            keypassvar=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_KEY_PASSWORD "${suffix}")
            keypassfilevar=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_KEY_PASSWORD_FILE "${suffix}")
            keystorevar=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE "${suffix}")
            keystoretypevar=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_TYPE "${suffix}")
            keystorealiasvar=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_ALIAS "${suffix}")
            keystorepassvar=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD "${suffix}")
            keystorepassfilevar=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD_FILE "${suffix}")
            keyentrypassvar=$(govway_https_varname GOVWAY_AS_HTTPS_KEY_PASSWORD "${suffix}")
            keyentrypassfilevar=$(govway_https_varname GOVWAY_AS_HTTPS_KEY_PASSWORD_FILE "${suffix}")
            clientauthvar=$(govway_https_varname GOVWAY_AS_HTTPS_CLIENT_AUTH "${suffix}")
            truststorevar=$(govway_https_varname GOVWAY_AS_HTTPS_TRUSTSTORE "${suffix}")
            truststoretypevar=$(govway_https_varname GOVWAY_AS_HTTPS_TRUSTSTORE_TYPE "${suffix}")
            truststorepassvar=$(govway_https_varname GOVWAY_AS_HTTPS_TRUSTSTORE_PASSWORD "${suffix}")
            cacertvar=$(govway_https_varname GOVWAY_AS_HTTPS_CA_CERTIFICATE "${suffix}")
            protocolsvar=$(govway_https_varname GOVWAY_AS_HTTPS_PROTOCOLS "${suffix}")
            ciphersvar=$(govway_https_varname GOVWAY_AS_HTTPS_CIPHERS "${suffix}")
            http2var=$(govway_https_varname GOVWAY_AS_HTTPS_HTTP2 "${suffix}")

            # --- validazione pre-flight ---
            if [ -n "${!certvar}" ] && [ -n "${!keystorevar}" ]
            then
                echo "FATAL: Configurazione HTTPS ... per ${suffix} sono state impostate sia ${certvar} che ${keystorevar}: le modalità PEM e keystore sono mutuamente esclusive."
                exit 1
            fi

            clientauth="${!clientauthvar:-none}"
            case "${clientauth,,}" in
                none|optional|required) : ;;
                *)
                    echo "FATAL: Configurazione HTTPS ... valore non consentito per ${clientauthvar}: [${clientauth}]. Valori consentiti: [ none, optional, required ]"
                    exit 1
                    ;;
            esac
            if [ "${clientauth,,}" != none ] && [ -z "${!truststorevar}" ] && [ -z "${!cacertvar}" ]
            then
                echo "FATAL: Configurazione HTTPS ... ${clientauthvar}=${clientauth} richiede ${truststorevar} oppure ${cacertvar}."
                exit 1
            fi

            govway_https_check_file "${!certvar}" "${certvar}"
            govway_https_check_file "${!keyvar}" "${keyvar}"
            govway_https_check_file "${!chainvar}" "${chainvar}"
            govway_https_check_file "${!keystorevar}" "${keystorevar}"
            govway_https_check_file "${!truststorevar}" "${truststorevar}"
            govway_https_check_file "${!cacertvar}" "${cacertvar}"

            if [ -n "${!keystorevar}" ] && [ -z "${!keystorepassvar}" ] && [ -z "${!keystorepassfilevar}" ]
            then
                echo "FATAL: Configurazione HTTPS ... ${keystorepassvar} (o ${keystorepassfilevar}) è obbligatoria quando è impostata ${keystorevar}."
                exit 1
            fi

            outdir="${CATALINA_HOME}/conf/https/${suffix,,}"

            # --- Connector + SSLHostConfig (comuni a tutte le modalità) ---
            govway_https_emit "# HTTPS ${suffix}: connettore sulla porta ${port}"
            govway_https_emit "/Server/Service/Connector:add port=${port}, protocol=HTTP/1.1, SSLEnabled=true, scheme=https, secure=true, connectionTimeout=20000, executor=${executor}, maxHttpHeaderSize=\${GOVWAY_AS_MAX_HTTP_SIZE:-1048576}, maxPostSize=\${GOVWAY_AS_MAX_POST_SIZE:-10485760}, bindOnInit=false"

            protocols="${!protocolsvar:-TLSv1.2,TLSv1.3}"
            govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:add protocols=${protocols//,/+}"

            if [ -n "${!ciphersvar}" ]
            then
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:write-attribute ciphers=\${${ciphersvar}}"
            fi

            http2val="${!http2var}"
            if [ "${http2val^^}" = TRUE ]
            then
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/UpgradeProtocol:add className=org.apache.coyote.http2.Http2Protocol"
            fi

            # --- materiale crittografico del server (modi a/b/c) ---
            if [ -n "${!certvar}" ]
            then
                # modo (b): PEM, nessuna conversione necessaria su Tomcat (supporto nativo anche con JSSE)
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:add certificateFile=\${${certvar}}"
                keyfile_emit_var="${certvar}"
                [ -n "${!keyvar}" ] && keyfile_emit_var="${keyvar}"
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyFile=\${${keyfile_emit_var}}"
                if [ -n "${!chainvar}" ]
                then
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateChainFile=\${${chainvar}}"
                fi
                if [ -n "${!keypassfilevar}" ]
                then
                    [ -n "${!keypassvar}" ] && echo "WARN: Configurazione HTTPS ... sono state impostate sia ${keypassvar} che ${keypassfilevar}; ha priorità ${keypassfilevar}."
                    govway_https_check_file "${!keypassfilevar}" "${keypassfilevar}"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyPasswordFile=\${${keypassfilevar}}"
                elif [ -n "${!keypassvar}" ]
                then
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyPassword=\${${keypassvar}}"
                fi
            elif [ -n "${!keystorevar}" ]
            then
                # modo (c): keystore PKCS12/JKS montato
                kstype="${!keystoretypevar:-$(govway_https_sniff_type "${!keystorevar}")}"
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:add certificateKeystoreFile=\${${keystorevar}}"
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystoreType=${kstype}"
                [ -n "${!keystorealiasvar}" ] && govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyAlias=\${${keystorealiasvar}}"
                if [ -n "${!keystorepassfilevar}" ]
                then
                    [ -n "${!keystorepassvar}" ] && echo "WARN: Configurazione HTTPS ... sono state impostate sia ${keystorepassvar} che ${keystorepassfilevar}; ha priorità ${keystorepassfilevar}."
                    govway_https_check_file "${!keystorepassfilevar}" "${keystorepassfilevar}"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystorePasswordFile=\${${keystorepassfilevar}}"
                else
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystorePassword=\${${keystorepassvar}}"
                fi
                # certificateKeyPassword: solo se l'alias ha una password diversa da quella del keystore
                # (default Tomcat: se assente, usa certificateKeystorePassword anche per la chiave)
                if [ -n "${!keyentrypassfilevar}" ]
                then
                    [ -n "${!keyentrypassvar}" ] && echo "WARN: Configurazione HTTPS ... sono state impostate sia ${keyentrypassvar} che ${keyentrypassfilevar}; ha priorità ${keyentrypassfilevar}."
                    govway_https_check_file "${!keyentrypassfilevar}" "${keyentrypassfilevar}"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyPasswordFile=\${${keyentrypassfilevar}}"
                elif [ -n "${!keyentrypassvar}" ]
                then
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyPassword=\${${keyentrypassvar}}"
                fi
            else
                # modo (a): self-signed, generato con openssl (MAI con generate-self-signed-certificate-host)
                govway_https_selfsigned "${suffix}" "${outdir}"
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:add certificateKeystoreFile=${outdir}/keystore.p12"
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystoreType=PKCS12"
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystorePassword=govway"
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyAlias=govway"
            fi

            # --- client authentication / mTLS (modo d) ---
            if [ "${clientauth,,}" != none ]
            then
                govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:write-attribute certificateVerification=${clientauth,,}"
                if [ -n "${!cacertvar}" ]
                then
                    govway_https_ca_to_truststore "${!cacertvar}" "${outdir}"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:write-attribute truststoreFile=${outdir}/truststore.p12"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:write-attribute truststoreType=PKCS12"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:write-attribute truststorePassword=govway"
                else
                    tstype="${!truststoretypevar:-$(govway_https_sniff_type "${!truststorevar}")}"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:write-attribute truststoreFile=\${${truststorevar}}"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:write-attribute truststoreType=${tstype}"
                    # NOTA: Tomcat non ha un attributo truststorePasswordFile nativo (limite noto, vedi doc).
                    # La password del truststore viene risolta qui e resta visibile nell'ambiente del processo Tomcat.
                    govway_https_resolve_password "${truststorepassvar}"
                    govway_https_emit "/Server/Service/Connector[@port=\"${port}\"]/SSLHostConfig:write-attribute truststorePassword=\${${truststorepassvar}:-govway}"
                fi
            fi
        done

        # --- reverse proxy / forwarding: opt-in, non tocca il comportamento di default ---
        proxyfwdval="${GOVWAY_AS_HTTPS_PROXY_FORWARDING}"
        if [ "${proxyfwdval^^}" = TRUE ]
        then
            erogport="${GOVWAY_HTTPS_USED_PORTS[0]}"
            govway_https_emit "/Server/Service/Engine/Host/Valve[@className=\"org.apache.catalina.valves.RemoteIpValve\"]:write-attribute httpsServerPort=${erogport}"
        fi

        /usr/local/bin/tomcat-cli.sh "${HTTPS_CLI_FILE}"

        # --- post-verifica: tomcat-cli.sh ignora l'exit status di java, verifico direttamente server.xml ---
        for suffix in EROGAZIONI FRUIZIONI GESTIONE
        do
            [ "${HTTPS_ONLY_EROGAZIONI}" = true ] && [ "${suffix}" != EROGAZIONI ] && continue
            portvar=$(govway_https_varname GOVWAY_AS_HTTPS_PORT "${suffix}")
            port="${!portvar:-${GOVWAY_HTTPS_DEFAULT_PORT[${suffix}]}}"
            check=$(xmlstarlet sel -t -v "count(/Server/Service/Connector[@port='${port}'][@SSLEnabled='true'])" "${CATALINA_HOME}/conf/server.xml" 2>/dev/null)
            if [ "${check}" != "1" ]
            then
                echo "FATAL: Configurazione HTTPS ... il connettore sulla porta ${port} (${suffix}) non risulta creato correttamente in server.xml."
                exit 1
            fi
        done

        echo "INFO: Configurazione HTTPS ... completata"
    fi

    touch "${HTTPS_INIT_FILE}"
fi

if [ -d "${ENTRYPOINT_D}" -o  -d "${ENTRYPOINT_D_DEPRECATO}" ]
then
    if [ ! -f ${CUSTOM_INIT_FILE} ] 
    then
        f=
        for f in ${ENTRYPOINT_D}/* ${ENTRYPOINT_D_DEPRECATO}/*
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
                    /usr/local/bin/tomcat-cli.sh "$f"
                    ;;
                *)  
                    echo "INFO: Customizzazioni ... IGNORO $f"
                    ;;
            esac
            echo
        done
        touch ${CUSTOM_INIT_FILE}
    fi
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

# Impostazione dell'algoritmo per la genrazione degli UUID (default UUIDv1)
GOVWAY_RESOLVED_UUID_ALG="${GOVWAY_UUID_ALG}"
[ "${GOVWAY_UUID_ALG,,}" == 'v1' -o -z "${GOVWAY_UUID_ALG}" ] &&  GOVWAY_RESOLVED_UUID_ALG=UUIDv1
[ "${GOVWAY_UUID_ALG,,}" == 'v4' ] &&  GOVWAY_RESOLVED_UUID_ALG=UUIDv4sec
export GOVWAY_RESOLVED_UUID_ALG

# Mi assicuro che i diritti della directory di log siano sufficienti
/usr/local/bin/change_dir_perms ${GOVWAY_LOGDIR}

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
ulimit -Sn 8192  # Soft limit per nofile
ulimit -Hn 8192  # Hard limit per nofile
ulimit -Su 4096  # Soft limit per nproc
ulimit -Hu 4096  # Hard limit per nproc
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
