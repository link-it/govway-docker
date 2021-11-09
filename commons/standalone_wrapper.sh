#!/bin/bash -x

## Const
GOVWAY_STARTUP_CHECK_SKIP=${GOVWAY_STARTUP_CHECK_SKIP:=FALSE}
GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME=${GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME:=20}
GOVWAY_STARTUP_CHECK_SLEEP_TIME=${GOVWAY_STARTUP_CHECK_SLEEP_TIME:=5}
GOVWAY_STARTUP_CHECK_MAX_RETRY=${GOVWAY_STARTUP_CHECK_MAX_RETRY:=60}
GOVWAY_STARTUP_CHECK_REGEX='GovWay/?.* \(www.govway.org\) avviata correttamente in .* secondi'

declare -r JVM_PROPERTIES_FILE='/etc/wildfly/wildfly.properties'
declare -r ENTRYPOINT_D='/docker-entrypoint-widlflycli.d/'
declare -r CUSTOM_INIT_FILE="${JBOSS_HOME}/standalone/configuration/custom_wildlfy_init"


    
case "${GOVWAY_DB_TYPE:-hsql}" in
postgresql)

    #
    # Sanity check variabili minime attese
    #
    [ -n "${GOVWAY_DB_SERVER}" -a -n  "${GOVWAY_DB_USER}" -a -n "${GOVWAY_DB_PASSWORD}" -a -n "${GOVWAY_DB_NAME}" ] || exit 1

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


    # Valori di default per i parametri opzionali dei datasource GOVWAY
    if [ -n "${GOVWAY_DS_PSCACHESIZE}" ]
    then
        [ -n "${GOVWAY_CONF_DS_PSCACHESIZE}" ] || export GOVWAY_CONF_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}" 
        [ -n "${GOVWAY_TRAC_DS_PSCACHESIZE}" ] || export GOVWAY_TRAC_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}" 
        [ -n "${GOVWAY_STAT_DS_PSCACHESIZE}" ] || export GOVWAY_STAT_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}"
    fi

    if [ -n "${GOVWAY_DS_CONN_PARAM}" ]
    then
        [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ] || export GOVWAY_CONF_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}" 
        [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ] || export GOVWAY_TRAC_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}" 
        [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ] || export GOVWAY_STAT_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}"
    fi

    if [ -n "${GOVWAY_DS_IDLE_TIMEOUT}" ]
    then
        [ -n "${GOVWAY_CONF_DS_IDLE_TIMEOUT}" ] || export GOVWAY_CONF_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}" 
        [ -n "${GOVWAY_TRAC_DS_IDLE_TIMEOUT}" ] || export GOVWAY_TRAC_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}" 
        [ -n "${GOVWAY_STAT_DS_IDLE_TIMEOUT}" ] || export GOVWAY_STAT_DS_IDLE_TIMEOUT="${GOVWAY_DS_IDLE_TIMEOUT}"
    fi

    if [ -n "${GOVWAY_DS_BLOCKING_TIMEOUT}" ]
    then
        [ -n "${GOVWAY_CONF_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_CONF_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}" 
        [ -n "${GOVWAY_TRAC_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_TRAC_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}" 
        [ -n "${GOVWAY_STAT_DS_BLOCKING_TIMEOUT}" ] || export GOVWAY_STAT_DS_BLOCKING_TIMEOUT="${GOVWAY_DS_BLOCKING_TIMEOUT}"
    fi
    export GOVWAY_DRIVER_JDBC="/opt/postgresql-${POSTGRES_JDBC_VERSION}.jar"
    export GOVWAY_DS_DRIVER_CLASS='org.postgresql.Driver'
    export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'
;;
hsql|*)
    export GOVWAY_DRIVER_JDBC="/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar"
    export GOVWAY_DS_DRIVER_CLASS='org.hsqldb.jdbc.JDBCDriver'
    export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1'
;;
esac

# Recupero l'indirizzo ip usato dal container (utilizzato dalle funzionalita di clustering / orchestration)
export GW_IPADDRESS=$(grep -E "[[:space:]]${HOSTNAME}[[:space:]]*$" /etc/hosts|awk '{print $1}')

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
${JBOSS_HOME}/bin/initgovway.sh || { echo "Database non inizializzato;"; exit 1; }

# Eventuali inizializzazioni custom widfly
if [ -d "${ENTRYPOINT_D}" -a ! -f ${CUSTOM_INIT_FILE} ]
then
    local f
	for f in ${ENTRYPOINT_D}/*
    do
		case "$f" in
			*.sh)
				if [ -x "$f" ]; then
					echo "Customizzazioni: eseguo $f"
					"$f"
				else
					echo "Customizzazioni: eseguo $f"
					. "$f"
				fi
				;;
			*.cli)
                echo "Customizzazioni: eseguo $f"; 
                ${JBOSS_HOME}/bin/jboss-cli.sh --file=$f
                ;;
			*) echo "Customizzazioni: ignoro $f" ;;
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
    ${JBOSS_HOME}/bin/standalone.sh ${CMDLINARGS[@]} &
else
    ${JBOSS_HOME}/bin/standalone.sh $@ &
fi

PID=$!
trap "kill -TERM $PID" TERM INT


if [ "${GOVWAY_STARTUP_CHECK_SKIP}" == "FALSE" ]
then

	/bin/rm -f  /tmp/govway_ready
	echo "INFO: Attendo avvio di GovWay ..."
	sleep ${GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME}s
	GOVWAY_READY=1
	NUM_RETRY=0
	while [ ${GOVWAY_READY} -ne 0 -a ${NUM_RETRY} -lt ${GOVWAY_STARTUP_CHECK_MAX_RETRY} ]
	do
		grep -qE "${GOVWAY_STARTUP_CHECK_REGEX}" ${GOVWAY_LOGDIR}/govway_startup.log  2> /dev/null
		GOVWAY_READY=$?
		NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
		if [  ${GOVWAY_READY} -ne 0 ]
                then
			echo "INFO: Attendo avvio di GovWay ..."
			sleep ${GOVWAY_STARTUP_CHECK_SLEEP_TIME}s
		fi
	done

	if [ ${NUM_RETRY} -eq ${GOVWAY_STARTUP_CHECK_MAX_RETRY} ]
	then
		echo "FATAL: GovWay NON avviato dopo $((${GOVWAY_STARTUP_CHECK_SLEEP_TIME=} * ${GOVWAY_STARTUP_CHECK_MAX_RETRY})) secondi ... Uscita"
		kill -15 ${PID}
	else
		touch /tmp/govway_ready
		echo "INFO: GovWay avviato "
	fi
fi



wait $PID
wait $PID
EXIT_STATUS=$?


exit $EXIT_STATUS
