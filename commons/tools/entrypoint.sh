#!/bin/bash
set -e

GOVWAY_TOOLS_HOME="${GOVWAY_TOOLS_HOME:-/opt/govway-tools}"
GOVWAY_HOME="${GOVWAY_HOME:-/etc/govway}"

usage() {
    echo "Usage: <tool> <azione> [args...]"
    echo
    echo "  config-loader create <archivePath>"
    echo "  config-loader createOrUpdate <archivePath>"
    echo "  config-loader delete <archivePath>"
    echo "  template-scan <regex>"
    echo "  vault-cli encrypt [args...]"
    echo "  vault-cli decrypt [args...]"
    echo "  vault-cli update [args...]"
    exit 2
}

[ -n "$1" ] || usage

TOOL="$1"; shift

case "${TOOL}" in
config-loader)
    TOOL_DIR="${GOVWAY_TOOLS_HOME}/govway-config-loader"
    ACTION="$1"; shift || true
    case "${ACTION}" in
    create) SCRIPT="create.sh" ;;
    createOrUpdate) SCRIPT="createOrUpdate.sh" ;;
    delete) SCRIPT="delete.sh" ;;
    *) echo "FATAL: azione non valida per config-loader: '${ACTION}'"; usage ;;
    esac
    JDBC_VAR=BATCH_JDBC
    DB_PROPS_FILE="${GOVWAY_HOME}/config_loader.cli.database.properties"
    ;;
template-scan)
    TOOL_DIR="${GOVWAY_TOOLS_HOME}/govway-template-scan"
    SCRIPT="template_scan.sh"
    JDBC_VAR=TOOL_JDBC
    DB_PROPS_FILE="${GOVWAY_HOME}/template_scan.cli.properties"
    ;;
vault-cli)
    TOOL_DIR="${GOVWAY_TOOLS_HOME}/govway-vault-cli"
    ACTION="$1"; shift || true
    case "${ACTION}" in
    encrypt) SCRIPT="encrypt.sh" ;;
    decrypt) SCRIPT="decrypt.sh" ;;
    update) SCRIPT="update.sh" ;;
    *) echo "FATAL: azione non valida per vault-cli: '${ACTION}'"; usage ;;
    esac
    JDBC_VAR=VAULT_JDBC
    DB_PROPS_FILE="${GOVWAY_HOME}/govway_vault.cli.database.properties"
    ;;
*)
    echo "FATAL: tool non valido: '${TOOL}'"
    usage
    ;;
esac

[ -d "${TOOL_DIR}" ] || { echo "FATAL: directory del tool non trovata: ${TOOL_DIR}"; exit 1; }
[ -x "${TOOL_DIR}/${SCRIPT}" ] || { echo "FATAL: script non trovato o non eseguibile: ${TOOL_DIR}/${SCRIPT}"; exit 1; }

#
# Configurazione DB da variabili d'ambiente (attiva solo se GOVWAY_DB_TYPE è impostata).
# Se non impostata, il tool legge le properties già presenti in ${GOVWAY_HOME} (bind-mount
# dell'utente, o quelle di default copiate nell'immagine in fase di build).
#
if [ -n "${GOVWAY_DB_TYPE}" ]
then
    case "${GOVWAY_DB_TYPE}" in
    mysql|mariadb|postgresql|oracle|sqlserver)

        if [ -n "${GOVWAY_DB_SERVER}" -a -n "${GOVWAY_DB_USER}" -a -n "${GOVWAY_DB_NAME}" ]
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
                mkdir -p "${GOVWAY_DS_JDBC_LIBS}"
                /bin/cp -f "/opt/postgresql-${POSTGRES_JDBC_VERSION}.jar" "${GOVWAY_DS_JDBC_LIBS}"
            fi
            GOVWAY_DS_DRIVER_CLASS='org.postgresql.Driver'
            DB_TIPODATABASE='postgresql'
            JDBC_URL="jdbc:postgresql://${GOVWAY_DB_SERVER}/${GOVWAY_DB_NAME}"
            [ -n "${GOVWAY_DS_CONN_PARAM}" ] && JDBC_URL="${JDBC_URL}?${GOVWAY_DS_CONN_PARAM}"
        ;;
        mysql|mariadb)
            if [ -z "${GOVWAY_DS_JDBC_LIBS}" ]
            then
                echo "FATAL: Sanity check JDBC ... fallito."
                echo "FATAL: Il path alla directory che contiene il driver JDBC, deve essere indicato tramite la variabile GOVWAY_DS_JDBC_LIBS "
                exit 1
            fi
            if [ "${GOVWAY_DB_TYPE}" == 'mysql' ]
            then
                GOVWAY_DS_DRIVER_CLASS='com.mysql.cj.jdbc.Driver'
                JDBC_SCHEME='mysql'
            else
                GOVWAY_DS_DRIVER_CLASS='org.mariadb.jdbc.Driver'
                JDBC_SCHEME='mariadb'
            fi
            # tipoDatabase non distingue mariadb da mysql (stessa convenzione di run_batch.sh)
            DB_TIPODATABASE='mysql'
            CONN_PARAM="${GOVWAY_DS_CONN_PARAM:+${GOVWAY_DS_CONN_PARAM}&}zeroDateTimeBehavior=convertToNull"
            JDBC_URL="jdbc:${JDBC_SCHEME}://${GOVWAY_DB_SERVER}/${GOVWAY_DB_NAME}?${CONN_PARAM}"
        ;;
        oracle)
            if [ -z "${GOVWAY_DS_JDBC_LIBS}" ]
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
            GOVWAY_DS_DRIVER_CLASS='oracle.jdbc.OracleDriver'
            DB_TIPODATABASE='oracle'
            if [ "${GOVWAY_ORACLE_JDBC_URL_TYPE^^}" != 'SID' ]
            then
                JDBC_URL="jdbc:oracle:thin:@//${GOVWAY_DB_SERVER}/${GOVWAY_DB_NAME}"
            else
                JDBC_URL="jdbc:oracle:thin:@${GOVWAY_DB_SERVER}:${GOVWAY_DB_NAME}"
            fi
            [ -n "${GOVWAY_DS_CONN_PARAM}" ] && JDBC_URL="${JDBC_URL}?${GOVWAY_DS_CONN_PARAM}"
        ;;
        sqlserver)
            if [ -z "${GOVWAY_DS_JDBC_LIBS}" ]
            then
                echo "FATAL: Sanity check JDBC ... fallito."
                echo "FATAL: Il path alla directory che contiene il driver JDBC, deve essere indicato tramite la variabile GOVWAY_DS_JDBC_LIBS "
                exit 1
            fi

            if [ "${GOVWAY_SQLSERVER_ENCRYPT^^}" == 'FALSE' ]
            then
                SQLSERVER_ENCRYPT_PARAMS='encrypt=false'
            elif [ -n "${GOVWAY_SQLSERVER_TRUSTSTORE}" ]
            then
                SQLSERVER_ENCRYPT_PARAMS="encrypt=true;trustServerCertificate=false;trustStore=${GOVWAY_SQLSERVER_TRUSTSTORE}"
                [ -n "${GOVWAY_SQLSERVER_TRUSTSTORE_PASSWORD}" ] && SQLSERVER_ENCRYPT_PARAMS="${SQLSERVER_ENCRYPT_PARAMS};trustStorePassword=${GOVWAY_SQLSERVER_TRUSTSTORE_PASSWORD}"
            else
                SQLSERVER_ENCRYPT_PARAMS='encrypt=true;trustServerCertificate=true'
            fi

            GOVWAY_DS_DRIVER_CLASS='com.microsoft.sqlserver.jdbc.SQLServerDriver'
            DB_TIPODATABASE='sqlserver'
            JDBC_URL="jdbc:sqlserver://${GOVWAY_DB_SERVER};databaseName=${GOVWAY_DB_NAME};${SQLSERVER_ENCRYPT_PARAMS}"
            [ -n "${GOVWAY_DS_CONN_PARAM}" ] && JDBC_URL="${JDBC_URL};${GOVWAY_DS_CONN_PARAM}"
        ;;
        esac

        {
            echo ""
            echo "# ----- Generato da entrypoint.sh da variabili d'ambiente -----"
            if [ "${TOOL}" == 'template-scan' ]
            then
                echo "db.type=${DB_TIPODATABASE}"
                echo "db.driver=${GOVWAY_DS_DRIVER_CLASS}"
                echo "db.url=${JDBC_URL}"
                echo "db.user=${GOVWAY_DB_USER}"
                echo "db.password=${GOVWAY_DB_PASSWORD}"
            else
                echo "tipoDatabase=${DB_TIPODATABASE}"
                echo "driver=${GOVWAY_DS_DRIVER_CLASS}"
                echo "connection-url=${JDBC_URL}"
                echo "username=${GOVWAY_DB_USER}"
                echo "password=${GOVWAY_DB_PASSWORD}"
            fi
        } >> "${DB_PROPS_FILE}"

        export "${JDBC_VAR}=${GOVWAY_DS_JDBC_LIBS}"
    ;;
    hsql)
        echo "FATAL: Il database hsql non è supportato da questa immagine: i tool operano su un database esterno già popolato, non su un'istanza file-based locale."
        exit 1
    ;;
    *)
        echo "FATAL: la variabile GOVWAY_DB_TYPE non è valida: '${GOVWAY_DB_TYPE}'"
        exit 1
    ;;
    esac
fi

cd "${TOOL_DIR}"
exec bash "${SCRIPT}" "$@"
