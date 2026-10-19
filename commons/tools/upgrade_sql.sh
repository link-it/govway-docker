#!/bin/bash
set -e

# Genera gli script SQL di aggiornamento della base dati, dalla versione indicata come
# argomento alla versione dell'immagine, eseguendo i target SQL dell'installer GovWay in
# modalita' 'aggiornamento'. Dell'installer l'immagine include solo quanto serve a questi
# target (build ant, sorgenti SQL e le librerie usate dal generatore).

umask 002

GOVWAY_INSTALLER_HOME="${GOVWAY_INSTALLER_HOME:-/opt/govway-installer}"
GOVWAY_SQL_OUTPUT_DIR="${GOVWAY_SQL_OUTPUT_DIR:-/var/govway/sql}"
SETUP_DIR="${GOVWAY_INSTALLER_HOME}/installer/setup"

# Versioni di partenza supportate: le option non commentate della select
# 'antinstaller_versione_precedente' nella configurazione dell'installer
versioni_supportate() {
    awk '{
        line = $0; out = ""
        while (length(line) > 0) {
            if (incomment) {
                i = index(line, "-->"); if (i == 0) { line = "" } else { line = substr(line, i + 3); incomment = 0 }
            } else {
                i = index(line, "<!--"); if (i == 0) { out = out line; line = "" } else { out = out substr(line, 1, i - 1); line = substr(line, i + 4); incomment = 1 }
            }
        }
        print out
    }' "${SETUP_DIR}/antinstall-config.xml" \
    | sed -n '/property="antinstaller_versione_precedente"/,/<\/large-select>/p' \
    | grep -o 'option value="[^"]*"' | cut -d'"' -f2
}

VERSIONI="$(versioni_supportate)"
if [ -z "${VERSIONI}" ]
then
    echo "FATAL: impossibile determinare le versioni di partenza supportate dall'installer (${SETUP_DIR}/antinstall-config.xml)"
    exit 1
fi

VERSIONE_PRECEDENTE="$1"
if [ -z "${VERSIONE_PRECEDENTE}" ]
then
    echo "FATAL: indicare la versione di partenza: upgrade-sql <versione>"
    echo "       Versioni supportate: $(echo ${VERSIONI})"
    exit 2
fi
if ! echo "${VERSIONI}" | grep -qxF "${VERSIONE_PRECEDENTE}"
then
    echo "FATAL: versione di partenza non supportata dall'installer: '${VERSIONE_PRECEDENTE}'"
    echo "       Versioni supportate: $(echo ${VERSIONI})"
    exit 2
fi

# L'installer non distingue mariadb da mysql
case "${GOVWAY_DB_TYPE}" in
postgresql|mysql|oracle|sqlserver|hsql) TIPO_DATABASE="${GOVWAY_DB_TYPE}" ;;
mariadb) TIPO_DATABASE='mysql' ;;
'')
    echo "FATAL: la variabile GOVWAY_DB_TYPE è obbligatoria."
    echo "       Valori consentiti: [ postgresql, mysql, mariadb, oracle, sqlserver, hsql ]"
    exit 1
    ;;
*)
    echo "FATAL: la variabile GOVWAY_DB_TYPE non è valida: '${GOVWAY_DB_TYPE}'"
    echo "       Valori consentiti: [ postgresql, mysql, mariadb, oracle, sqlserver, hsql ]"
    exit 1
    ;;
esac

if [ -n "${GOVWAY_DEFAULT_ENTITY_NAME}" ] && [[ ! "${GOVWAY_DEFAULT_ENTITY_NAME}" =~ ^[0-9A-Za-z][-A-Za-z0-9]*$ ]]
then
    echo "FATAL: il valore della variabile GOVWAY_DEFAULT_ENTITY_NAME non è valido: '${GOVWAY_DEFAULT_ENTITY_NAME}'"
    exit 1
fi

# GOVWAY_DB_MAPPING: le categorie indicate condividono il database con il Runtime
CONFIG_DB=config
LOG_DB=log
STATS_DB=stats
if [ -n "${GOVWAY_DB_MAPPING}" ]
then
    IFS=',' read -ra SHARED_CATEGORIES <<< "${GOVWAY_DB_MAPPING}"
    for CATEGORY in "${SHARED_CATEGORIES[@]}"
    do
        CATEGORY=$(echo "$CATEGORY" | xargs)
        case "${CATEGORY^^}" in
            T) LOG_DB=runtime ;;
            S) STATS_DB=runtime ;;
            C) CONFIG_DB=runtime ;;
            *) echo "WARN: Categoria sconosciuta '${CATEGORY}' in GOVWAY_DB_MAPPING. Categorie valide: T, S, C" ;;
        esac
    done
fi

if ! mkdir -p "${GOVWAY_SQL_OUTPUT_DIR}" 2>/dev/null || [ ! -w "${GOVWAY_SQL_OUTPUT_DIR}" ]
then
    echo "FATAL: la directory di output non è scrivibile: ${GOVWAY_SQL_OUTPUT_DIR}"
    echo "       Montare un volume scrivibile dall'utente del container (UID $(id -u), gruppo 0)."
    exit 1
fi
# Script di una precedente generazione, magari con un mapping diverso, verrebbero confusi con i nuovi
if ls "${GOVWAY_SQL_OUTPUT_DIR}"/GovWay*_upgrade_*.sql >/dev/null 2>&1
then
    echo "FATAL: la directory di output contiene già degli script di aggiornamento: ${GOVWAY_SQL_OUTPUT_DIR}"
    echo "       Svuotarla o indicarne un'altra."
    exit 1
fi

echo "INFO: Generazione script SQL di aggiornamento ${VERSIONE_PRECEDENTE} -> ${GOVWAY_FULLVERSION} per ${GOVWAY_DB_TYPE} (GOVWAY_DB_MAPPING=${GOVWAY_DB_MAPPING})"

WORK_DIR="$(mktemp -d /tmp/govway-upgrade-sql.XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT
PROPS="${WORK_DIR}/ant.install.properties"

# antinstaller_allSql deve essere disattivato: in modalita' aggiornamento l'installer
# genera gli script di tutti i database con il dialetto di antinstaller_tipo_database
sed -e "s/^antinstaller_modalita_installazione=.*/antinstaller_modalita_installazione=aggiornamento/" \
    -e "s/^antinstaller_versione_precedente=.*/antinstaller_versione_precedente=${VERSIONE_PRECEDENTE}/" \
    -e "s/^antinstaller_allSql=.*/antinstaller_allSql=false/" \
    -e "s/^antinstaller_tipo_database=.*/antinstaller_tipo_database=${TIPO_DATABASE}/" \
    -e "s/^antinstaller_config_db=.*/antinstaller_config_db=${CONFIG_DB}/" \
    -e "s/^antinstaller_log_db=.*/antinstaller_log_db=${LOG_DB}/" \
    -e "s/^antinstaller_stats_db=.*/antinstaller_stats_db=${STATS_DB}/" \
    "${SETUP_DIR}/ant.install.properties.template" > "${PROPS}"

ANT_CP="$(ls "${GOVWAY_INSTALLER_HOME}"/installer/lib/antinstaller/ant-[0-9]*.jar "${GOVWAY_INSTALLER_HOME}"/installer/lib/antinstaller/ant-launcher-*.jar | paste -sd:)"

cd "${SETUP_DIR}"
if ! java -cp "${ANT_CP}" org.apache.tools.ant.Main -quiet -buildfile build.xml -propertyfile "${PROPS}" \
    -Dbuild="${WORK_DIR}/build" -Ddist="${WORK_DIR}/dist" \
    -Dparam_db_type="${TIPO_DATABASE}" -Dparam_dist_sql="${WORK_DIR}/dist/sql" \
    init setup_sql _distrib_sql_by_db_type > "${WORK_DIR}/ant.log" 2>&1
then
    cat "${WORK_DIR}/ant.log"
    echo "FATAL: generazione degli script SQL di aggiornamento fallita."
    exit 1
fi

for SQL_FILE in "${WORK_DIR}"/dist/sql/GovWay*_upgrade_*.sql
do
    [ -f "${SQL_FILE}" ] || continue
    # Come initsql, il placeholder del soggetto viene risolto se la variabile è presente
    if [ -n "${GOVWAY_DEFAULT_ENTITY_NAME}" ]
    then
        sed -i -e "s/\${GOVWAY_DEFAULT_ENTITY_NAME}/${GOVWAY_DEFAULT_ENTITY_NAME}/g" "${SQL_FILE}"
    fi
    cp "${SQL_FILE}" "${GOVWAY_SQL_OUTPUT_DIR}/"
    echo "INFO: Generato ${GOVWAY_SQL_OUTPUT_DIR}/$(basename "${SQL_FILE}")"
done
