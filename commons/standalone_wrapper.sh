#!/bin/bash -x

declare -r JVM_PROPERTIES_FILE='/etc/wildfly/wildfly.properties'


if [ "${GOVWAY_DB_TYPE:-hsql}" != 'hsql' ]
then

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



# Valori di default per i datasource IM (corrispondono ai valori determinati per i datasource  GOVWAY)
    [ -n "${IM_DB_SERVER}" ] || export IM_DB_SERVER="${GOVWAY_DB_SERVER}"
    [ -n "${IM_CONF_DB_SERVER}" ] || export IM_CONF_DB_SERVER="${GOVWAY_CONF_DB_SERVER}"
    [ -n "${IM_TRAC_DB_SERVER}" ] || export IM_TRAC_DB_SERVER="${GOVWAY_TRAC_DB_SERVER}"


    [ -n "${IM_DB_NAME}" ] || export IM_DB_NAME="${GOVWAY_DB_NAME}"
    [ -n "${IM_CONF_DB_NAME}" ] || export IM_CONF_DB_NAME="${GOVWAY_CONF_DB_NAME}"
    [ -n "${IM_TRAC_DB_NAME}" ] || export IM_TRAC_DB_NAME="${GOVWAY_TRAC_DB_NAME}"


    [ -n "${IM_DB_USER}" ] || export IM_DB_USER="${GOVWAY_DB_USER}"
    [ -n "${IM_CONF_DB_USER}" ] || export IM_CONF_DB_USER="${GOVWAY_CONF_DB_USER}"
    [ -n "${IM_TRAC_DB_USER}" ] || export IM_TRAC_DB_USER="${GOVWAY_TRAC_DB_USER}"


    [ -n "${IM_DB_PASSWORD}" ] || export IM_DB_PASSWORD="${GOVWAY_DB_PASSWORD}"
    [ -n "${IM_CONF_DB_PASSWORD}" ] || export IM_CONF_DB_PASSWORD="${GOVWAY_CONF_DB_PASSWORD}"
    [ -n "${IM_TRAC_DB_PASSWORD}" ] || export IM_TRAC_DB_PASSWORD="${GOVWAY_TRAC_DB_PASSWORD}"


    # Valori di default per i parametri opzionali dei datasource IM e GOVWAY
    if [ -n "${GOVWAY_DS_PSCACHESIZE}" ]
    then
        [ -n "${GOVWAY_CONF_DS_PSCACHESIZE}" ] || export GOVWAY_CONF_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}" 
        [ -n "${GOVWAY_TRAC_DS_PSCACHESIZE}" ] || export GOVWAY_TRAC_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}" 
        [ -n "${GOVWAY_STAT_DS_PSCACHESIZE}" ] || export GOVWAY_STAT_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}"
        [ -n "${IM_DS_PSCACHESIZE}" ] || export IM_DS_PSCACHESIZE="${GOVWAY_DS_PSCACHESIZE}" 
        [ -n "${IM_TRAC_DS_PSCACHESIZE}" ] || export IM_TRAC_DS_PSCACHESIZE="${IM_DS_PSCACHESIZE}" 
        [ -n "${IM_CONF_DS_PSCACHESIZE}" ] || export IM_CONF_DS_PSCACHESIZE="${IM_DS_PSCACHESIZE}" 
    fi

    if [ -n "${GOVWAY_DS_CONN_PARAM}" ]
    then
        [ -n "${GOVWAY_CONF_DS_CONN_PARAM}" ] || export GOVWAY_CONF_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}" 
        [ -n "${GOVWAY_TRAC_DS_CONN_PARAM}" ] || export GOVWAY_TRAC_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}" 
        [ -n "${GOVWAY_STAT_DS_CONN_PARAM}" ] || export GOVWAY_STAT_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}"
        [ -n "${IM_DS_CONN_PARAM}" ] || export IM_DS_CONN_PARAM="${GOVWAY_DS_CONN_PARAM}" 
        [ -n "${IM_TRAC_DS_CONN_PARAM}" ] || export IM_TRAC_DS_CONN_PARAM="${IM_DS_CONN_PARAM}" 
        [ -n "${IM_CONF_DS_CONN_PARAM}" ] || export IM_CONF_DS_CONN_PARAM="${IM_DS_CONN_PARAM}" 
    fi

fi
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
wait $PID
wait $PID
EXIT_STATUS=$?


exit $EXIT_STATUS
