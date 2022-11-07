#!/bin/bash
exec 6<> /tmp/run_batch.log
exec 2>&6
set -x

case "$1" in
[oO]rari[ea]) TIPO='StatisticheOrarie'
INTERVALLO_SCHEDULAZIONE=${GOVWAY_BATCH_INTERVALLO_CRON:-5} ;;
[gG]iornalier[ea]) TIPO='StatisticheGiornaliere'
INTERVALLO_SCHEDULAZIONE=${GOVWAY_BATCH_INTERVALLO_CRON:-30} ;;
# [sS]ettimanal[ie]) TIPO='StatisticheSettimanali';;
# SCHEDULAZIONE_CRON='';;
# [mM]ensil[ie]) TIPO='StatisticheMensili';;
# SCHEDULAZIONE_CRON='';;
*) echo "Tipo di statistiche non supportato: '$1'"
   exit 1
   ;;
esac 
[ ${INTERVALLO_SCHEDULAZIONE} -eq ${INTERVALLO_SCHEDULAZIONE} -a ${INTERVALLO_SCHEDULAZIONE} -gt 0 ] 2> /dev/null \
|| { echo "Non e' possibile schedulare il batch ad intervalli di '${INTERVALLO_SCHEDULAZIONE}' minuti."; exit 2; }
CRONTAB="*/${INTERVALLO_SCHEDULAZIONE} * * * * root ${GOVWAY_BATCH_HOME}/crond/govway_batch.sh ${GOVWAY_BATCH_HOME}/generatoreStatistiche genera${TIPO}.sh false"


case "${GOVWAY_DB_TYPE}" in
postgresql|oracle)
    #
    # Sanity check variabili minime attese
    #
    if [ -n "${GOVWAY_STAT_DB_SERVER}" -a -n  "${GOVWAY_STAT_DB_USER}" -a -n "${GOVWAY_STAT_DB_PASSWORD}" -a -n "${GOVWAY_STAT_DB_NAME}" ] 
    then
            echo "INFO: Sanity check variabili ... ok."
    else
        echo "FATAL: Sanity check variabili ... fallito."
        echo "FATAL: Devono essere settate almeno le seguenti variabili:
GOVWAY_STAT_DB_SERVER: ${GOVWAY_STAT_DB_SERVER}
GOVWAY_STAT_DB_NAME: ${GOVWAY_STAT_DB_NAME}
GOVWAY_STAT_DB_USER: ${GOVWAY_STAT_DB_USER}
GOVWAY_STAT_DB_PASSWORD: ${GOVWAY_STAT_DB_NAME:+xxxxx}
"
        exit 1
    fi
    if [ "${GOVWAY_DB_TYPE}" == 'oracle' ]
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
    

    case "${GOVWAY_DB_TYPE}" in
    postgresql)
        export GOVWAY_DRIVER_JDBC="/opt/postgresql-${POSTGRES_JDBC_VERSION}.jar"
        export GOVWAY_DS_DRIVER_CLASS='org.postgresql.Driver'
        export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'
        # JDBC URLS
        export JDBC_CONF_URL="jdbc:postgresql://${GOVWAY_CONF_DB_SERVER}/${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}"
        export JDBC_TRAC_URL="jdbc:postgresql://${GOVWAY_TRAC_DB_SERVER}/${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}"
        export JDBC_STAT_URL="jdbc:postgresql://${GOVWAY_STAT_DB_SERVER}/${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}"

    ;;
    oracle)
        export GOVWAY_DRIVER_JDBC="${GOVWAY_ORACLE_JDBC_PATH}"
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
        # JDBC URLS
        export JDBC_CONF_URL="jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_CONF_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}"
        export JDBC_TRAC_URL="jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_TRAC_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}" 
        export JDBC_STAT_URL="jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_STAT_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}"

    ;;
    esac
;;
# Temporanemaente disabilitato
# hsql)
#     export GOVWAY_DRIVER_JDBC="/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar"
#     export GOVWAY_DS_DRIVER_CLASS='org.hsqldb.jdbc.JDBCDriver'
#     export GOVWAY_DS_VALID_CONNECTION_SQL='SELECT * FROM (VALUES(1));'
#     # JDBC URLS
#     export JDBC_STAT_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
#     export JDBC_TRAC_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
#     export JDBC_STAT_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"


# ;;
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
export BATCH_JDBC="$(dirname ${GOVWAY_DRIVER_JDBC})"




mkdir -p "${BATCH_CONFIG}"
cp ${GOVWAY_BATCH_STATISTICHE}/properties/* "${BATCH_CONFIG}"


cat - << EOPROP > "${BATCH_CONFIG}/daoFactory.properties"
db.showSql=true
db.secondsToRefreshConnection=300
db.tipo=connection

# DB config
db.tipoDatabase=${GOVWAY_DB_TYPE}				
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

# Imposto Timezone
[ -z "${TZ}" ] && export TZ="Europe/Rome"
ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime

if [ "${GOVWAY_BATCH_USA_CRON,,}" == 'yes' -o "${GOVWAY_BATCH_USA_CRON,,}" == 'si' -o "${GOVWAY_BATCH_USA_CRON,,}" == '1' -o "${GOVWAY_BATCH_USA_CRON,,}" == 'true' ]
then
    env | sed -r -e 's/([^=]*)=([^=]*)/\1="\2"/' >> ${GOVWAY_BATCH_HOME}/batch_env
    cat - << EOCRONTAB > /etc/crontab
SHELL=/bin/bash
BASH_ENV=${GOVWAY_BATCH_HOME}/batch_env
${CRONTAB} >/proc/1/fd/1 2>&1
EOCRONTAB

    echo "INFO: Schedulo generazione  ${TIPO} ogni ${INTERVALLO_SCHEDULAZIONE} minuti."
    exec crond -n 
else
    "INFO: Generazione ${TIPO} avviata..."
    ${GOVWAY_BATCH_HOME}/crond/govway_batch.sh ${GOVWAY_BATCH_HOME}/generatoreStatistiche genera${TIPO}.sh false
    echo "INFO: Generazione ${TIPO} completata."
fi



