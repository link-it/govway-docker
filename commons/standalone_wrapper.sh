#!/bin/bash

exec 6<> /tmp/standalone_wrapper_debug.log
exec 2>&6
set -x

## Const
GOVWAY_STARTUP_CHECK_SKIP=${GOVWAY_STARTUP_CHECK_SKIP:=FALSE}
GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME=${GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME:=20}
GOVWAY_STARTUP_CHECK_SLEEP_TIME=${GOVWAY_STARTUP_CHECK_SLEEP_TIME:=5}
GOVWAY_STARTUP_CHECK_MAX_RETRY=${GOVWAY_STARTUP_CHECK_MAX_RETRY:=60}
declare -r GOVWAY_STARTUP_CHECK_REGEX='GovWay/?.* \(www.govway.org\) avviata correttamente in .* secondi'
declare -r GOVWAY_STARTUP_ENTITY_REGEX=^[0-9A-Za-z][\-A-Za-z0-9]*$

declare -r JVM_PROPERTIES_FILE='/etc/wildfly/wildfly.properties'
declare -r ENTRYPOINT_D='/docker-entrypoint-widlflycli.d/'
declare -r CUSTOM_INIT_FILE="${JBOSS_HOME}/standalone/configuration/custom_wildlfy_init"

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
        ${JBOSS_HOME}/bin/initsql.sh || echo "FATAL: Scripts sql non inizializzati."
        exit $?
    fi
fi


case "${GOVWAY_DB_TYPE:-hsql}" in
postgresql|oracle)

    #
    # Sanity check variabili minime attese
    #
    if [ -n "${GOVWAY_DB_SERVER}" -a -n  "${GOVWAY_DB_USER}" -a -n "${GOVWAY_DB_PASSWORD}" -a -n "${GOVWAY_DB_NAME}" ] 
    then
            echo "INFO: Sanity check variabili ... ok."
    else
        echo "FATAL: Sanity check variabili ... fallito."
        echo "FATAL: Devono essere settate almeno le seguenti variabili obbligatorie:
GOVWAY_DB_SERVER: ${GOVWAY_DB_SERVER}
GOVWAY_DB_NAME: ${GOVWAY_DB_NAME}
GOVWAY_DB_USER: ${GOVWAY_DB_USER}
GOVWAY_DB_PASSWORD: ${GOVWAY_DB_NAME:+xxxxx}
"
        exit 1
    fi
    if [ "${GOVWAY_DB_TYPE:-hsql}" == 'oracle' ]
    then
        if [ -z "${GOVWAY_ORACLE_JDBC_PATH}" -o ! -f "${GOVWAY_ORACLE_JDBC_PATH}" ]
        then
            echo "FATAL: Sanity check variabili ... fallito."
            echo "FATAL: Il path al driver jdbc oracle, non è stato indicato o non è leggibile: [GOVWAY_ORACLE_JDBC_PATH=${GOVWAY_ORACLE_JDBC_PATH}] "
            exit 1
        fi
        if [ "${GOVWAY_ORACLE_JDBC_URL_TYPE^^}" != 'SERVICENAME' -a "${GOVWAY_ORACLE_JDBC_URL_TYPE^^}" != 'SID' ]
        then
            echo "FATAL: Sanity check variabili ... fallito."
            echo "FATAL: Valore non consentito per la variabile GOVWAY_ORACLE_JDBC_URL_TYPE: [GOVWAY_ORACLE_JDBC_URL_TYPE=${GOVWAY_ORACLE_JDBC_URL_TYPE}]."
            echo "       Valori consentiti: [ servicename , sid ]"
            exit 1
        fi
    fi
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
    [ -n "${GOVWAY_DS_CONN_PARAM}" ] &&  export DATASOURCE_CONN_PARAM="?${GOVWAY_DS_CONN_PARAM}"
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



    case "${GOVWAY_DB_TYPE:-hsql}" in
    postgresql)
        export GOVWAY_DRIVER_JDBC="/opt/postgresql-${POSTGRES_JDBC_VERSION}.jar"
        export GOVWAY_DS_DRIVER_CLASS='org.postgresql.Driver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'
    ;;
    oracle)
        export GOVWAY_DRIVER_JDBC="${JBOSS_HOME}/modules/oracleMod/main/oracle-jdbc.jar"
        export GOVWAY_DS_DRIVER_CLASS='oracle.jdbc.OracleDriver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1 FROM DUAL'
        rm -rf "${GOVWAY_DRIVER_JDBC}"
        cp "${GOVWAY_ORACLE_JDBC_PATH}"  "${GOVWAY_DRIVER_JDBC}"

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
    export GOVWAY_DRIVER_JDBC="/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar"
    export GOVWAY_DS_DRIVER_CLASS='org.hsqldb.jdbc.JDBCDriver'
    export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT * FROM (VALUES(1));'
;;
esac

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
${JBOSS_HOME}/bin/initsql.sh || { echo "FATAL: Scripts sql non inizializzati."; exit 1; }
${JBOSS_HOME}/bin/initgovway.sh || { echo "FATAL: Database non inizializzato."; exit 1; }

# Eventuali inizializzazioni custom widfly
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
					echo "INFO: Customizzazioni ... eseguo $f"
					. "$f"
				fi
				;;
			*.cli)
				echo "INFO: Customizzazioni ... eseguo $f"; 
				if ! grep -q embed-server "$f"
				then
				    # Mi assicuro che sia presente la direttiva embed-server in cima allo script
				    # perche l'application server a questo punto non è ancora attivo
				    echo -e 'embed-server --server-config=standalone.xml --std-out=echo\n' > "/tmp/$(basename $f).fix"
				    cat "$f" >> "/tmp/$(basename $f).fix"
				    echo -e '\nstop-embedded-server\n' >> "/tmp/$(basename $f).fix"
				    ${JBOSS_HOME}/bin/jboss-cli.sh --file="/tmp/$(basename $f).fix"
				else
				    ${JBOSS_HOME}/bin/jboss-cli.sh --file="$f"
				fi
				;;
			*) echo "INFO: Customizzazioni ... ignoro $f" ;;
		esac
		echo
	done
    touch ${CUSTOM_INIT_FILE}
fi

# Azzero un'eventuale log di startup precedente (utile in caso di restart)
> ${GOVWAY_LOGDIR}/govway_startup.log

# Forzo file di un eventuale file di properties jvm da passare all'avvio
if [ -f ${JVM_PROPERTIES_FILE} ]
then
    declare -a CMDLINARGS
    SKIP=0
    FOUND=0
    for prop in $@
    do
        [ $SKIP -eq 1 ] && SKIP=0 && continue
        if [ "$prop" == '-p' ]
        then
            CMDLINARGS+=("-p")
            CMDLINARGS+=("${JVM_PROPERTIES_FILE}")
            SKIP=1
            FOUND=1
        elif [ "${prop%%=*}" == '--properties' ]
        then
            CMDLINARGS+=("--properties=${JVM_PROPERTIES_FILE}")
            FOUND=1
        else
            CMDLINARGS+=($prop)
        fi
    done
    [ $FOUND -eq 0 ] && CMDLINARGS+=("--properties=${JVM_PROPERTIES_FILE}")
    ${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 ${CMDLINARGS[@]} &
else
    ${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 $@ &
fi

PID=$!
trap "kill -TERM $PID; export NUM_RETRY=${GOVWAY_STARTUP_CHECK_MAX_RETRY};" TERM INT


if [ "${GOVWAY_STARTUP_CHECK_SKIP}" == "FALSE" ]
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
            [ -f "${JBOSS_HOME}/standalone/deployments/govwayConsole.war.deployed" ]
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
